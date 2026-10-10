"""Inspection helper: tiles a texture 2x2 (to reveal seams) and upscales it with
nearest filtering. Usage: python tools/art/view_texture.py <name> [scale]
Writes tests/_out/art/view_<name>.png (albedo 2x2 | normal | roughness)."""
import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
from artlib import imageio  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]


def main(name, scale=3):
    tex = ROOT / "assets" / "textures"
    a = imageio.load_png(tex / f"{name}_albedo.png")[..., :3]
    n = imageio.load_png(tex / f"{name}_normal.png")[..., :3]
    r = imageio.load_png(tex / f"{name}_orm.png")[..., 1:2].repeat(3, axis=-1)
    tiled = np.concatenate([np.concatenate([a, a], 1), np.concatenate([a, a], 1)], 0)
    side = np.concatenate([n, r], 0)
    gap = np.full((tiled.shape[0], 4, 3), 0.1)
    img = np.concatenate([tiled, gap, side], 1)
    img = np.repeat(np.repeat(img, scale, 0), scale, 1)
    out = ROOT / "tests" / "_out" / "art" / f"view_{name}.png"
    imageio.save_png(out, img)
    print(out)


if __name__ == "__main__":
    main(sys.argv[1], int(sys.argv[2]) if len(sys.argv) > 2 else 3)
