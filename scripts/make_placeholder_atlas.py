#!/usr/bin/env python3
"""Generate a 1536x2704 placeholder atlas + pet.json for ClawPet (13 rows)."""
import json, pathlib
from PIL import Image, ImageDraw

CELL_W, CELL_H, COLS = 192, 208, 8
STATES = [  # (name, frames, per-frame ms, loop)
    ("greet",4,[140,140,140,280],False),("hover",6,[280,140,140,180,180,320],True),
    ("working",6,[130,130,130,130,130,240],True),("typing",6,[110,110,110,110,110,200],True),
    ("waiting",6,[150,150,150,150,150,260],True),("cheer",5,[140,140,140,140,280],False),
    ("droop",5,[160,160,160,160,300],False),("singing",8,[150,150,150,150,150,150,150,300],False),
    ("fly-left",6,[120,120,120,120,120,120],True),("fly-right",6,[120,120,120,120,120,120],True),
    ("wave",4,[140,140,140,280],False),("twirl",6,[120,120,120,120,120,240],False),
    ("hearts",5,[140,140,140,140,260],False),
]
ROWS = len(STATES)
COLORS = ["#7bd3ea","#a1e3d8","#f6c6ea","#c9b6f2","#ffd6a5","#b5ead7","#ffb3b3",
          "#f9f871","#8ecae6","#90dbf4","#ffc8dd","#cdb4db","#ffafcc"]

img = Image.new("RGBA", (COLS*CELL_W, ROWS*CELL_H), (0,0,0,0))
d = ImageDraw.Draw(img)
for r,(name,frames,_,_) in enumerate(STATES):
    for c in range(frames):
        x0,y0 = c*CELL_W, r*CELL_H
        d.rounded_rectangle([x0+16,y0+16,x0+CELL_W-16,y0+CELL_H-16], radius=18,
                            fill=COLORS[r], outline="#333333", width=3)
        d.text((x0+24,y0+24), f"{name}\n#{c}", fill="#222222")
out = pathlib.Path(__file__).resolve().parent.parent / "pets" / "placeholder"
out.mkdir(parents=True, exist_ok=True)
img.save(out/"spritesheet.png")
manifest = {"id":"placeholder","displayName":"Placeholder","spritesheetPath":"spritesheet.png",
            "cell":{"w":CELL_W,"h":CELL_H},
            "states":[{"name":n,"row":i,"frames":f,"durations":dur,"loop":lp}
                      for i,(n,f,dur,lp) in enumerate(STATES)]}
(out/"pet.json").write_text(json.dumps(manifest, indent=2, ensure_ascii=False))
print(f"wrote {out}/spritesheet.png ({img.width}x{img.height}) + pet.json")
