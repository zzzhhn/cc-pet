#!/usr/bin/env python3
"""Stack per-state row strips into the final ClawPet atlas, ordered by pet.json state rows.

Usage: compose_atlas.py <rows_dir> <pet_dir>
Reads <pet_dir>/pet.json for the ordered state list; each <rows_dir>/<state>.png is a
1536x208 atlas row. Output: <pet_dir>/spritesheet.png (1536 x rows*208).
"""
import json, sys, pathlib
from PIL import Image

CELL_W, CELL_H, COLS = 192, 208, 8
rows_dir = pathlib.Path(sys.argv[1])
pet_dir = pathlib.Path(sys.argv[2])
states = json.loads((pet_dir / "pet.json").read_text())["states"]
atlas = Image.new("RGBA", (COLS * CELL_W, len(states) * CELL_H), (0, 0, 0, 0))
for st in states:
    strip = Image.open(rows_dir / f'{st["name"]}.png').convert("RGBA")
    if strip.size != (COLS * CELL_W, CELL_H):
        strip = strip.resize((COLS * CELL_W, CELL_H), Image.NEAREST)
    atlas.paste(strip, (0, st["row"] * CELL_H), strip)
atlas.save(pet_dir / "spritesheet.png")
print(f'composed {atlas.width}x{atlas.height} ({len(states)} states) -> {pet_dir}/spritesheet.png')
