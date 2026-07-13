#!/usr/bin/env python3
"""Layout-guide generation + grid slicing for ClawPet animation rows.

Adapts the official hatch-pet technique (layout guide + chroma key + fixed cell
geometry) to fal's 3:1 max canvas aspect: frames are generated as a 2-row x N-col
GRID (e.g. 3x2 for 6 frames) instead of one ultra-wide 8:1 strip, then sliced and
re-flowed into a single horizontal row.

Cells are 192x208 (the atlas contract). Chroma key is #00FF00 — the character wears
white trousers/sneakers, so a white background would be indistinguishable from the
outfit when keyed out.
"""
import math
import pathlib
import sys

from PIL import Image, ImageDraw

CELL_W, CELL_H = 192, 208
CHROMA = (0, 255, 0)          # #00FF00 — never appears in the character's palette
SAFE_MARGIN_X, SAFE_MARGIN_Y = 14, 12


def grid_shape(frames: int) -> tuple[int, int]:
    """(cols, rows) for a frame count, keeping the canvas within fal's 3:1 aspect cap."""
    rows = 1 if frames <= 3 else 2
    cols = math.ceil(frames / rows)
    return cols, rows


def make_layout_guide(frames: int, out: pathlib.Path) -> tuple[int, int]:
    """Draw a visual grid the model can copy: numbered equal cells + safe margins.

    The model is told to use this ONLY for slot count/spacing/centering, never to draw it.
    """
    cols, rows = grid_shape(frames)
    w, h = cols * CELL_W, rows * CELL_H
    img = Image.new("RGB", (w, h), CHROMA)
    d = ImageDraw.Draw(img)
    for i in range(frames):
        r, c = divmod(i, cols)
        x0, y0 = c * CELL_W, r * CELL_H
        d.rectangle((x0, y0, x0 + CELL_W - 1, y0 + CELL_H - 1), outline="#111111", width=2)
        d.rectangle(
            (x0 + SAFE_MARGIN_X, y0 + SAFE_MARGIN_Y,
             x0 + CELL_W - 1 - SAFE_MARGIN_X, y0 + CELL_H - 1 - SAFE_MARGIN_Y),
            outline="#888888", width=1,
        )
        d.text((x0 + 8, y0 + 6), str(i + 1), fill="#111111")
    img.save(out)
    return w, h


def key_out(img: Image.Image, threshold: float = 110.0) -> Image.Image:
    """Chroma-key the green background to transparency, normalizing transparent RGB."""
    img = img.convert("RGBA")
    px = img.load()
    for y in range(img.height):
        for x in range(img.width):
            r, g, b, a = px[x, y]
            dist = math.sqrt((r - CHROMA[0]) ** 2 + (g - CHROMA[1]) ** 2 + (b - CHROMA[2]) ** 2)
            if dist < threshold:
                px[x, y] = (0, 0, 0, 0)      # no hidden RGB residue
    return img


def slice_grid_to_row(src: pathlib.Path, frames: int, out: pathlib.Path) -> None:
    """Slice a 2xN generated grid into cells and re-flow them into ONE horizontal row."""
    cols, rows = grid_shape(frames)
    img = Image.open(src).convert("RGBA")
    img = img.resize((cols * CELL_W, rows * CELL_H), Image.NEAREST)   # NEAREST preserves pixel art
    img = key_out(img)

    row = Image.new("RGBA", (8 * CELL_W, CELL_H), (0, 0, 0, 0))       # 8-col atlas row, unused cells transparent
    for i in range(frames):
        r, c = divmod(i, cols)
        cell = img.crop((c * CELL_W, r * CELL_H, (c + 1) * CELL_W, (r + 1) * CELL_H))
        row.paste(cell, (i * CELL_W, 0))
    row.save(out)
    print(f"sliced {frames} frames ({cols}x{rows} grid) -> {out} ({row.width}x{row.height})")


if __name__ == "__main__":
    cmd = sys.argv[1]
    if cmd == "guide":
        frames, out = int(sys.argv[2]), pathlib.Path(sys.argv[3])
        w, h = make_layout_guide(frames, out)
        cols, rows = grid_shape(frames)
        print(f"guide {cols}x{rows} = {w}x{h} (aspect {w/h:.2f}:1) -> {out}")
    elif cmd == "slice":
        slice_grid_to_row(pathlib.Path(sys.argv[2]), int(sys.argv[3]), pathlib.Path(sys.argv[4]))
    else:
        raise SystemExit("usage: grid_tools.py guide <frames> <out> | slice <src> <frames> <out>")
