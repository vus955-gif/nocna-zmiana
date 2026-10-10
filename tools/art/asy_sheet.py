"""Tiles PNGs side by side (nearest scaling) into one review sheet:
    python tools/art/asy_sheet.py out.png scale cols in1.png in2.png ..."""
import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
from artlib import imageio  # noqa: E402


def main(argv):
    out, scale, cols = argv[0], float(argv[1]), int(argv[2])
    imgs = [imageio.load_png(p)[..., :3] for p in argv[3:]]
    if scale != 1.0:
        out_imgs = []
        for im in imgs:
            h, w = im.shape[:2]
            ys = (np.arange(int(h * scale)) / scale).astype(int)
            xs = (np.arange(int(w * scale)) / scale).astype(int)
            out_imgs.append(im[ys][:, xs])
        imgs = out_imgs
    rows = [imgs[i:i + cols] for i in range(0, len(imgs), cols)]
    H = sum(max(i.shape[0] for i in r) for r in rows) + 6 * len(rows)
    W = max(sum(i.shape[1] for i in r) + 6 * len(r) for r in rows)
    sheet = np.full((H, W, 3), 0.08)
    y = 0
    for r in rows:
        x = 0
        for im in r:
            sheet[y:y + im.shape[0], x:x + im.shape[1]] = im
            x += im.shape[1] + 6
        y += max(i.shape[0] for i in r) + 6
    imageio.save_png(out, sheet)


if __name__ == "__main__":
    main(sys.argv[1:])
