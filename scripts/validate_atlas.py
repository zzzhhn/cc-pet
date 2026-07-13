#!/usr/bin/env python3
"""Validate a ClawPet atlas: dims = 1536 x (rows*208), width multiple of 192."""
import sys, json, pathlib
from PIL import Image
d = pathlib.Path(sys.argv[1])
m = json.loads((d/"pet.json").read_text())
rows = len(m["states"])
im = Image.open(d/"spritesheet.png")
assert im.width == 1536, f"width {im.width} != 1536"
assert im.height == rows*208, f"height {im.height} != {rows*208}"
assert im.mode == "RGBA", f"mode {im.mode} != RGBA"
print(f"OK {im.width}x{im.height}, {rows} states, 0 errors")
