"""Swatch strips of the weapon palettes (plan 2026-10-21-dostepnosc, section 4): every
palette on the HUD's enamel, as seen normally and in each simulated colour-vision mode
(Machado et al. 2009, cvd.py), with the white medkit at the end of each strip and the
smallest pair distance of that view written beside it. No window: a PNG to look at.

    python swatches.py out.png [palettes.json]

palettes.json: {"name": {"mode": "deut"|"prot"|"trit"|"norm", "colors": {weapon: "#rrggbb"}}};
without it the standard palette alone (cvd.ORIG)."""
import itertools, json, sys
import numpy as np
from PIL import Image, ImageDraw
from cvd import ORIG, MEDKIT, ENAMEL, sim, de

VIEWS = ("norm", "deut", "prot", "trit")
CELL, GAP, LABEL_W, HEAD = 64, 8, 170, 26


def hex_rgb(text):
    text = text.lstrip("#")
    return tuple(int(text[i:i + 2], 16) / 255 for i in (0, 2, 4))


def to8(c):
    return tuple(int(round(float(x) * 255)) for x in np.clip(c, 0, 1))


def min_pair(colors, view):
    best, pair = 1e9, None
    for (ka, a), (kb, b) in itertools.combinations(colors.items(), 2):
        d = de(a, b, view)
        if d < best:
            best, pair = d, (ka, kb)
    return best, pair


def render(palettes, out):
    names = list(ORIG.keys()) + ["medkit"]
    width = LABEL_W + len(names) * (CELL + GAP) + 250
    row_h = CELL + GAP
    height = sum(HEAD + len(VIEWS) * row_h + GAP * 2 for _ in palettes) + GAP
    img = Image.new("RGB", (width, height), to8(ENAMEL))
    draw = ImageDraw.Draw(img)
    y = GAP
    for title, spec in palettes.items():
        colors = {k: hex_rgb(spec["colors"][k]) if isinstance(spec["colors"][k], str) else spec["colors"][k] for k in ORIG}
        colors["medkit"] = MEDKIT
        draw.text((GAP, y + 6), "%s (palette for: %s)" % (title, spec["mode"]), fill=(235, 228, 214))
        x0 = LABEL_W
        for i, n in enumerate(names):
            draw.text((x0 + i * (CELL + GAP), y + 6), n[:9], fill=(180, 172, 160))
        y += HEAD
        for view in VIEWS:
            mark = " <-" if view == spec["mode"] else ""
            draw.text((GAP, y + CELL // 2 - 6), "seen: %s%s" % (view, mark), fill=(235, 228, 214))
            for i, n in enumerate(names):
                x = x0 + i * (CELL + GAP)
                draw.rectangle([x, y, x + CELL - 1, y + CELL - 1], fill=to8(sim(colors[n], view)))
            d, pair = min_pair(colors, view)
            draw.text((x0 + len(names) * (CELL + GAP) + 6, y + CELL // 2 - 6),
                      "min dE %.1f %s/%s" % (d, pair[0], pair[1]), fill=(235, 228, 214))
            y += row_h
        y += GAP * 2
    img.save(out)


if __name__ == "__main__":
    out = sys.argv[1]
    palettes = {"standard": {"mode": "norm", "colors": ORIG}}
    if len(sys.argv) > 2:
        with open(sys.argv[2], encoding="utf-8") as f:
            palettes.update(json.load(f))
    render(palettes, out)
