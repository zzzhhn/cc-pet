#!/usr/bin/env python3
"""Step 1 of the art pipeline: turn ONE reference photo into a base chibi sprite.

Usage:  python3 gen_base_sprite.py <photo.png> [out.png]

The base sprite is the identity anchor every animation row is grounded on. Output
defaults to $CCPET_WORKDIR/base.png (CCPET_WORKDIR defaults to ./out).
Provider is pluggable — see providers.py (default: fal.ai gpt-image-2/edit, key FAL_KEY).
"""
import os, sys, pathlib
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from providers import edit_image

WORKDIR = pathlib.Path(os.environ.get("CCPET_WORKDIR", "out"))

# The MapleStory-style pixel recipe this project converged on (tune to taste).
PROMPT = (
    "You are a professional pixel art director who converts characters into MapleStory-style "
    "player sprites. Convert the person in the reference photo into a single full-body "
    "MapleStory-style pixel art sprite. High-resolution detailed pixel art: crisp visible pixels, "
    "clean hard edges, limited palette of about 24 colors, dithered shading, sharp 1px outlines, "
    "super-deformed chibi proportions (about 2.5 heads tall, large head, short stubby limbs of "
    "equal scale). NOT smooth vector art, NOT anti-aliased. Faithfully preserve the person's hair, "
    "face and outfit as pixel art. Friendly neutral idle pose facing the viewer, full body head to "
    "feet, centered with margin, nothing cropped, both hands relaxed. Flat pure white background, "
    "no shadow, no text, no border, single character only."
)

def main() -> int:
    if len(sys.argv) < 2:
        raise SystemExit("usage: gen_base_sprite.py <photo.png> [out.png]")
    photo = sys.argv[1]
    if not pathlib.Path(photo).exists():
        raise FileNotFoundError(f"reference photo not found: {photo}")
    out = sys.argv[2] if len(sys.argv) > 2 else str(WORKDIR / "base.png")
    print(f"[1/1] {photo} -> base sprite via provider={os.environ.get('CCPET_PROVIDER','fal')}", flush=True)
    edit_image(PROMPT, [photo], size="square_hd", out_path=out)
    print(f"DONE: {out}", flush=True)
    return 0

if __name__ == "__main__":
    sys.exit(main())
