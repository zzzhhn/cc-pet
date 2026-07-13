#!/usr/bin/env python3
"""Content-aware re-slicing of ClawPet raw grids (calibrated to official hatch-pet).

Root cause of drift/teleport + neighbor bleed: rigid 192px slicing assumes the model
placed each character on an exact grid. It doesn't. Official hatch-pet instead segments
the character blob per cell (connected components) and RE-ANCHORS it centered in a clean
cell (fit_to_cell). This re-implements that with numpy (no scipy), re-slicing existing
_raw_<state>.png grids into consistently-anchored rows. No regeneration.
"""
import sys
import math
import pathlib
import numpy as np
from PIL import Image

CELL_W, CELL_H, COLS_ATLAS = 192, 208, 8
CHROMA = np.array([0, 255, 0])
CHROMA_THRESH = 140.0     # color distance to treat a pixel as background
NOISE_AREA = 40           # drop components smaller than this (px)


def grid_shape(frames: int):
    rows = 1 if frames <= 3 else 2
    return math.ceil(frames / rows), rows


def alpha_mask(rgb: np.ndarray) -> np.ndarray:
    """True where pixel is foreground (far from chroma green)."""
    dist = np.sqrt(((rgb.astype(np.int32) - CHROMA) ** 2).sum(axis=2))
    return dist > CHROMA_THRESH


def label_components(mask: np.ndarray):
    """4-connected labeling via BFS on a small region. Returns list of (area, (minx,miny,maxx,maxy), cx)."""
    h, w = mask.shape
    seen = np.zeros((h, w), dtype=bool)
    comps = []
    stack = []
    for sy in range(h):
        for sx in range(w):
            if not mask[sy, sx] or seen[sy, sx]:
                continue
            stack.append((sy, sx)); seen[sy, sx] = True
            minx = maxx = sx; miny = maxy = sy; area = 0; sumx = 0
            while stack:
                y, x = stack.pop()
                area += 1; sumx += x
                if x < minx: minx = x
                if x > maxx: maxx = x
                if y < miny: miny = y
                if y > maxy: maxy = y
                if y > 0 and mask[y-1, x] and not seen[y-1, x]: seen[y-1, x] = True; stack.append((y-1, x))
                if y < h-1 and mask[y+1, x] and not seen[y+1, x]: seen[y+1, x] = True; stack.append((y+1, x))
                if x > 0 and mask[y, x-1] and not seen[y, x-1]: seen[y, x-1] = True; stack.append((y, x-1))
                if x < w-1 and mask[y, x+1] and not seen[y, x+1]: seen[y, x+1] = True; stack.append((y, x+1))
            comps.append((area, (minx, miny, maxx + 1, maxy + 1), sumx / area))
    return comps


TARGET_H = int(CELL_H * 0.90)   # every frame normalized to this character height -> no scale drift

def fit_to_cell(sprite: Image.Image) -> Image.Image:
    """Crop to bbox, NORMALIZE height to TARGET_H (fixes row-to-row scale drift), center both axes."""
    target = Image.new("RGBA", (CELL_W, CELL_H), (0, 0, 0, 0))
    bbox = sprite.getbbox()
    if bbox is None:
        return target
    sp = sprite.crop(bbox)
    scale = TARGET_H / sp.height
    if sp.width * scale > CELL_W - 4:      # if wings make it too wide, cap by width instead
        scale = (CELL_W - 4) / sp.width
    sp = sp.resize((max(1, round(sp.width * scale)), max(1, round(sp.height * scale))), Image.NEAREST)
    target.alpha_composite(sp, ((CELL_W - sp.width) // 2, (CELL_H - sp.height) // 2))
    return target


def _order_row_major(seeds, rows):
    """Order character seeds the way the grid was filled: left-to-right, top-to-bottom.
    Split into `rows` horizontal bands by the largest vertical gaps, then sort each band by x."""
    withpos = [(c, c[2], c[3]) for c in seeds]   # (comp, cx, cy)
    if rows == 1:
        return [c for c, _, _ in sorted(withpos, key=lambda t: t[1])]
    by_y = sorted(withpos, key=lambda t: t[2])
    gaps = sorted(range(1, len(by_y)), key=lambda k: by_y[k][2] - by_y[k - 1][2], reverse=True)
    cuts = sorted(gaps[:rows - 1])
    bands, prev = [], 0
    for cut in cuts + [len(by_y)]:
        bands.append(by_y[prev:cut]); prev = cut
    ordered = []
    for band in bands:
        ordered += [c for c, _, _ in sorted(band, key=lambda t: t[1])]
    return ordered


def resegment(raw_path, frames, out):
    """Segment characters by connected components over the WHOLE grid (grid-alignment-agnostic),
    take the `frames` largest as character seeds, order them row-major, attach each smaller blob
    to its nearest seed, then crop each character's FULL extent and center it in a clean cell.
    This does NOT assume the model placed characters on grid cell centers (it doesn't)."""
    cols, rows = grid_shape(frames)
    raw = Image.open(raw_path).convert("RGB")
    rgb = np.asarray(raw)
    mask = alpha_mask(rgb)
    rgba_full = np.dstack([rgb, (mask * 255).astype(np.uint8)])

    comps = [c for c in label_components(mask) if c[0] >= NOISE_AREA]
    # comp = (area, (mnx,mny,mxx,mxy), cx). add cy for convenience -> (area,bbox,cx,cy)
    comps = [(a, b, (b[0] + b[2]) / 2, (b[1] + b[3]) / 2) for (a, b, _cx) in comps]
    if len(comps) < frames:
        raise RuntimeError(f"{raw_path.name}: found {len(comps)} blobs, need >= {frames} characters")
    seeds = sorted(comps, key=lambda c: c[0], reverse=True)[:frames]
    ordered = _order_row_major(seeds, rows)
    seed_ids = {id(sd) for sd in seeds}

    # assign each non-seed blob to the nearest seed (by centroid distance)
    groups = {id(sd): [sd] for sd in seeds}
    for c in comps:
        if id(c) in seed_ids:
            continue
        nearest = min(seeds, key=lambda sd: (sd[2] - c[2]) ** 2 + (sd[3] - c[3]) ** 2)
        groups[id(nearest)].append(c)

    row_img = Image.new("RGBA", (COLS_ATLAS * CELL_W, CELL_H), (0, 0, 0, 0))
    M = 14
    for i, seed in enumerate(ordered):
        members = groups[id(seed)]
        sb = seed[1]
        def adjoins(b):
            return not (b[0] > sb[2] + M or b[2] < sb[0] - M or b[1] > sb[3] + M or b[3] < sb[1] - M)
        body = [m for m in members if m is seed or adjoins(m[1])]      # seed + wings
        keep = body + [m for m in members if m not in body]           # + satellites
        bmnx = min(m[1][0] for m in body); bmxx = max(m[1][2] for m in body)
        bmny = min(m[1][1] for m in body); bmxy = max(m[1][3] for m in body)
        umnx = min(m[1][0] for m in keep); umxx = max(m[1][2] for m in keep)
        umny = min(m[1][1] for m in keep); umxy = max(m[1][3] for m in keep)
        body_w, body_h = bmxx - bmnx, bmxy - bmny
        crop = Image.fromarray(rgba_full[umny:umxy, umnx:umxx], "RGBA")
        scale = TARGET_H / body_h
        if body_w * scale > CELL_W - 8:
            scale = (CELL_W - 8) / body_w
        crop = crop.resize((max(1, round(crop.width * scale)), max(1, round(crop.height * scale))), Image.NEAREST)
        bcx = (bmnx + bmxx) / 2 - umnx
        bcy = (bmny + bmxy) / 2 - umny
        cell = Image.new("RGBA", (CELL_W, CELL_H), (0, 0, 0, 0))
        cell.alpha_composite(crop, (round(CELL_W / 2 - bcx * scale), round(CELL_H / 2 - bcy * scale)))
        row_img.paste(cell, (i * CELL_W, 0))

    out.parent.mkdir(parents=True, exist_ok=True)
    row_img.save(out)
    print(f"resliced {raw_path.name}: {frames}f, {len(comps)} blobs, {rows}-row seed order -> {out.name}")


def load_frames(pet_json: pathlib.Path) -> dict:
    """Frame counts come from pet.json (single source of truth) to avoid hardcode drift."""
    import json
    return {st["name"]: st["frames"] for st in json.loads(pet_json.read_text())["states"]}

if __name__ == "__main__":
    rows_dir = pathlib.Path(sys.argv[1])
    pet_json = pathlib.Path(sys.argv[2]) if len(sys.argv) > 2 else (
        pathlib.Path(__file__).resolve().parent.parent / "pets" / "placeholder" / "pet.json")
    frames = load_frames(pet_json)
    only = sys.argv[3:] if len(sys.argv) > 3 else list(frames)
    for state in only:
        raw = rows_dir / f"_raw_{state}.png"
        if raw.exists():
            resegment(raw, frames[state], rows_dir / f"{state}.png")
        else:
            print(f"skip {state}: no {raw.name}")
