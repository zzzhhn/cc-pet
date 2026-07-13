#!/usr/bin/env python3
"""Flag any sprite frame whose content touches the cell edge (potential clip).
Beats eyeballing 76 frames. Usage: check_clipping.py <rows_dir> <pet.json>"""
import sys, json, pathlib
import numpy as np
from PIL import Image

CW, CH, EDGE = 192, 208, 2
rows_dir = pathlib.Path(sys.argv[1])
pet = json.loads(pathlib.Path(sys.argv[2]).read_text())
flagged = []
for st in pet["states"]:
    a = np.asarray(Image.open(rows_dir / f'{st["name"]}.png').convert("RGBA"))[:, :, 3]
    for i in range(st["frames"]):
        cell = a[:, i * CW:(i + 1) * CW]
        ys, xs = np.where(cell > 16)
        if len(xs) == 0:
            continue
        t = ("L" if xs.min() <= EDGE else "") + ("R" if xs.max() >= CW - 1 - EDGE else "") \
            + ("T" if ys.min() <= EDGE else "") + ("B" if ys.max() >= CH - 1 - EDGE else "")
        if t:
            flagged.append(f'{st["name"]} frame{i}: edge={t} (x{xs.min()}-{xs.max()} y{ys.min()}-{ys.max()})')
if flagged:
    print("POTENTIAL CLIPS:")
    for f in flagged:
        print("  " + f)
    sys.exit(1)
print(f"No clipping: all frames clear of the cell edge ({sum(s['frames'] for s in pet['states'])} frames).")
