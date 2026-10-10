"""Quick look at material functions as flat swatches (no Blender needed):
    "D:/Program Files/Blender Foundation/Blender 5.1/5.1/python/bin/python.exe" tools/art/material_sheet.py [names...]
Writes tests/_out/art/material_sheet.png: albedo | normal | roughness per
swatch, 3x upscaled with nearest filtering. A swatch is 0.5 x 0.5 m at
256 px/m on a flat plane, so edge/AO/curvature effects do not show; it is
for judging colours, patterns and scale before baking a model.
"""
import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
from artlib import imageio, materials as M, painter  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "tests" / "_out" / "art" / "material_sheet.png"

SWATCHES = {
    "fur": lambda c: M.fur(c, flow=(1.0, 0.0, -0.3)),
    "steel": M.steel,
    "mail": M.mail,
    "shield_paint": lambda c: M.paint(c, "cloth_red", 4.2, chip=1.0, crackle=1.0),
    "gun_steel": M.gun_steel,
    "walnut_stock": M.walnut_stock,
    "grip": lambda c: M.checkering(c, M.plastic(c, "bakelite", 3.6, rough=0.35)),
    "plastic_yellow": lambda c: M.plastic(c, "plastic_yellow", 4.6),
    "rubber": M.rubber,
    "uniform": M.uniform,
    "bone": M.bone,
    "cardboard": M.cardboard,
    "enamel_white": lambda c: M.enamel(c, "enamel_white", 5.6),
    "paint_olive": lambda c: M.enamel(c, "paint_olive", 4.6, gloss=0.5, under="steel"),
    "porcelain": M.porcelain,
    "beige": lambda c: M.plastic(c, "plastic_beige", 4.8, rough=0.55),
}


def main(names):
    rows = []
    for name, fn in SWATCHES.items():
        if names and name not in names:
            continue
        imgs = painter.paint_tile(fn, 0.5, 0.5, 256, normal_strength=2.0)
        a = imgs["albedo"][..., :3]
        n = imgs["normal"]
        r = np.repeat(imgs["orm"][..., 1:2], 3, axis=-1)
        gap = np.zeros((a.shape[0], 4, 3))
        rows.append(np.concatenate([a, gap, n, gap, r], axis=1))
        print("swatch", name)
    cols = [rows[i:i + 4] for i in range(0, len(rows), 4)]
    blocks = []
    for c in cols:
        while len(c) < 4:
            c.append(np.zeros_like(rows[0]))
        blocks.append(np.concatenate([np.pad(r, ((4, 4), (4, 4), (0, 0))) for r in c], axis=0))
    sheet = np.concatenate(blocks, axis=1)
    sheet = np.repeat(np.repeat(sheet, 2, 0), 2, 1)
    imageio.save_png(OUT, np.clip(sheet, 0, 1))
    print("wrote", OUT)


if __name__ == "__main__":
    main(sys.argv[1:])
