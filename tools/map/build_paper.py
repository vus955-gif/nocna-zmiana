"""The paper of the museum map (W6): a folded visitor leaflet.

Run from the repo root with any Python 3 that has numpy and Pillow:
    python tools/map/build_paper.py

Writes (deterministic: same code -> same pixels):
  assets/ui/map/leaflet_paper.jpg  the bare sheet: cream paper, mottling,
                                   fibres, fine grain (under the print)
  assets/ui/map/leaflet_wear.png   what lies over the print (RGBA, mostly
                                   clear): the panels' light, the fold
                                   creases with their shading, ink worn off
                                   along the folds, rubbed crossings,
                                   yellowed edges and nicks, a faint coffee
                                   ring, specks of dirt
  assets/ui/map/graphite_grain.png the paper tooth the pencil catches on
                                   (tileable, 256 x 256, grey)
and a contact sheet tests/_out/map/paper_sheet.png.

The sheet is 2400 x 1700 px (MapStyle.SHEET): folded in three across
(creases at x 800 and 1600) and once along (y 850), like a leaflet carried
in a pocket for a few nights.
"""
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets" / "ui" / "map"
SHEET_OUT = ROOT / "tests" / "_out" / "map" / "paper_sheet.png"

W, H = 2400, 1700
FOLDS_X = (800, 1600)
FOLD_Y = 850
# valley (+1) or mountain (-1) for each crease: across x 800, x 1600, along y 850
FOLD_KIND = {"x800": 1, "x1600": -1, "y850": -1}
PAPER = np.array([238.0, 233.0, 219.0]) / 255.0
SEED = 1987


def value_noise(rng, period, w=W, h=H):
    """Smooth noise in -1..1 with features about `period` px wide."""
    gw = max(2, int(np.ceil(w / period)) + 3)
    gh = max(2, int(np.ceil(h / period)) + 3)
    grid = rng.random((gh, gw)).astype(np.float32)
    img = Image.fromarray(grid).resize((gw * period, gh * period), Image.BICUBIC)
    arr = np.asarray(img, dtype=np.float32)[period:period + h, period:period + w]
    return (arr - 0.5) * 2.0


def fbm(rng, periods_amps):
    total = np.zeros((H, W), np.float32)
    for period, amp in periods_amps:
        total += value_noise(rng, period) * amp
    return total


def blur(arr, sigma):
    """Separable Gaussian blur (wrapping at the edges; fine for noise)."""
    reach = max(1, int(np.ceil(sigma * 3.0)))
    offsets = np.arange(-reach, reach + 1)
    weights = np.exp(-0.5 * (offsets / sigma) ** 2)
    weights /= weights.sum()
    out = arr.astype(np.float32)
    for axis in (0, 1):
        acc = np.zeros_like(out)
        for k, w in zip(offsets, weights):
            acc += np.roll(out, int(k), axis=axis) * np.float32(w)
        out = acc
    return out


def fibres(rng, count, w=W, h=H):
    """Short curved strokes: +1 lighter, -1 darker (float layer, -1..1)."""
    layer = Image.new("F", (w, h), 0.0)
    draw = ImageDraw.Draw(layer)
    for _ in range(count):
        x, y = rng.random() * w, rng.random() * h
        length = 5 + rng.random() ** 2 * 32
        angle = rng.random() * np.pi
        bend = (rng.random() - 0.5) * 0.08
        sign = 1.0 if rng.random() < 0.55 else -1.0
        value = sign * (0.4 + rng.random() * 0.6)
        step = length / 7.0
        points = [(x, y)]
        for i in range(7):
            a = angle + bend * i * step
            x += np.cos(a) * step
            y += np.sin(a) * step
            points.append((x, y))
        draw.line(points, fill=float(value), width=1)
    return blur(np.asarray(layer, dtype=np.float32), 0.45)


def base_paper(rng):
    """The bare sheet (RGB 0..1)."""
    mottle = fbm(rng, [(520, 0.024), (260, 0.017), (90, 0.01), (34, 0.006)])
    grain = blur(rng.normal(0.0, 1.0, (H, W)).astype(np.float32), 0.6) * 0.011
    tooth = value_noise(rng, 3) * 0.006
    fib = fibres(rng, 5200) * 0.03
    light = 1.0 + mottle + grain + tooth + fib
    rgb = PAPER[None, None, :] * light[:, :, None]
    # a warmer, slightly yellowed cast in the large mottling
    warm = fbm(rng, [(700, 1.0)])
    rgb[:, :, 2] -= np.clip(warm, 0, 1)[:, :] * 0.018
    return np.clip(rgb, 0.0, 1.0)


def crease_profile(dist, kind, rng_line):
    """Shading across a crease: (light, dark) amounts at signed distance."""
    d = np.abs(dist)
    soft = np.exp(-d / 26.0)
    wide = np.exp(-d / 90.0)
    if kind > 0:   # valley: both sides dip towards the crease
        dark = soft * 0.10 + wide * 0.035
        light = np.zeros_like(d)
    else:          # mountain: lit on one side, shaded on the other
        lit = dist < 0
        dark = np.where(lit, 0.0, soft * 0.085 + wide * 0.03)
        light = np.where(lit, soft * 0.07 + wide * 0.02, 0.0)
    return light * rng_line, dark * rng_line


def wear_overlay(rng):
    """RGBA 0..1 over the print: light (white) and shade (black) as alpha,
    worn ink (paper colour), dirt (warm grey), the coffee ring (brown)."""
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    light = np.zeros((H, W), np.float32)
    dark = np.zeros((H, W), np.float32)

    # each of the six panels sits at its own slight angle to the lamp
    xs = [0, FOLDS_X[0], FOLDS_X[1], W]
    ys = [0, FOLD_Y, H]
    for i in range(3):
        for j in range(2):
            x0, x1, y0, y1 = xs[i], xs[i + 1], ys[j], ys[j + 1]
            gx = (rng.random() - 0.5) * 0.09
            gy = (rng.random() - 0.5) * 0.06
            base = (rng.random() - 0.5) * 0.035
            u = (xx[y0:y1, x0:x1] - x0) / (x1 - x0) - 0.5
            v = (yy[y0:y1, x0:x1] - y0) / (y1 - y0) - 0.5
            tilt = base + gx * u + gy * v
            light[y0:y1, x0:x1] += np.clip(tilt, 0, None)
            dark[y0:y1, x0:x1] += np.clip(-tilt, 0, None)

    # the creases: soft shading, then the sharp line itself
    along_x = value_noise(rng, 60, W, 1)[0] * 0.35 + 0.85
    along_y = value_noise(rng, 60, H, 1)[0] * 0.35 + 0.85
    for x in FOLDS_X:
        kind = FOLD_KIND["x%d" % x]
        dist = xx - x
        l, d = crease_profile(dist, kind, along_y[:, None])
        light += l
        dark += d
    dist = yy - FOLD_Y
    l, d = crease_profile(dist, FOLD_KIND["y850"], along_x[None, :])
    light += l
    dark += d

    worn = np.zeros((H, W), np.float32)    # ink rubbed off: paper shows
    dirt = np.zeros((H, W), np.float32)
    line_noise = value_noise(rng, 7, W, 1)[0] * 0.5 + value_noise(rng, 31, W, 1)[0] * 0.5
    col_noise = value_noise(rng, 7, H, 1)[0] * 0.5 + value_noise(rng, 31, H, 1)[0] * 0.5
    specks = rng.random((H, W)).astype(np.float32)
    def ridge(dist, kind, noise):
        """The crease itself: a soft ridge, lit on one side, shaded on the
        other, a faint broken core, ink rubbed off along it."""
        nonlocal light, dark, worn, dirt
        side = 1.0 if kind > 0 else -1.0
        strength = np.clip(0.75 + noise * 0.45, 0.25, 1.2)
        dark += np.exp(-(dist / 1.25) ** 2) * 0.12 * strength
        dark += np.exp(-((dist - side * 3.0) / 3.2) ** 2) * 0.07 * strength
        light += np.exp(-((dist + side * 2.2) / 1.7) ** 2) * 0.2 * strength
        band = np.exp(-(dist / 3.6) ** 2)
        worn += band * np.clip(specks - 0.5, 0, 1) * 1.3 * np.clip(0.5 + noise, 0, 1)
        dirt += np.exp(-(dist / 9.0) ** 2) * 0.045 * strength

    for x in FOLDS_X:
        ridge(xx - x, FOLD_KIND["x%d" % x], col_noise[:, None])
    ridge(yy - FOLD_Y, FOLD_KIND["y850"], line_noise[None, :])

    # the crossings, rubbed nearly through
    for x in FOLDS_X:
        r = np.hypot(xx - x, yy - FOLD_Y)
        rag = 3.5 + value_noise(rng, 4) * 2.2
        worn += np.clip((rag - r) / 2.5, 0, 1) * 0.55
        dirt += np.exp(-((r - rag - 1.0) / 1.8) ** 2) * 0.14 + np.exp(-r / 26.0) * 0.08

    # edges: yellowed, darker, a few nicks, the corners rubbed round
    edge = np.minimum(np.minimum(xx, W - 1 - xx), np.minimum(yy, H - 1 - yy))
    rough = value_noise(rng, 40) * 6.0 + value_noise(rng, 9) * 2.0
    dirt += np.exp(-np.clip(edge + rough, 0, None) / 18.0) * 0.16
    dark += np.exp(-np.clip(edge + rough, 0, None) / 5.0) * 0.12
    for cx, cy in ((0, 0), (W, 0), (0, H), (W, H)):
        r = np.hypot(xx - cx, yy - cy)
        dirt += np.exp(-r / 60.0) * 0.12
        worn += np.exp(-r / 26.0) * 0.35 * np.clip(specks - 0.3, 0, 1)
    for _ in range(14):
        side = rng.integers(4)
        t = rng.random()
        if side == 0:
            cx, cy = t * W, 0.0
        elif side == 1:
            cx, cy = t * W, H - 1.0
        elif side == 2:
            cx, cy = 0.0, t * H
        else:
            cx, cy = W - 1.0, t * H
        r = np.hypot(xx - cx, yy - cy)
        size = 2.0 + rng.random() * 4.0
        dark += np.clip((size - r) / 1.5, 0, 1) * 0.25

    # specks of dirt and a faint coffee ring (the night shift's mug)
    for _ in range(45):
        cx, cy = rng.random() * W, rng.random() * H
        r = np.hypot(xx - cx, yy - cy)
        size = 0.4 + rng.random() ** 4 * 1.4
        dirt += np.clip((size - r) / 0.8, 0, 1) * (0.15 + rng.random() * 0.3)
    stain = np.zeros((H, W), np.float32)
    cx, cy, radius = 1990.0, 1530.0, 104.0
    r = np.hypot(xx - cx, yy - cy)
    wobble = value_noise(rng, 40) * 5.0 + value_noise(rng, 11) * 1.5
    ring = np.exp(-((r - radius + wobble) / 2.8) ** 2) + np.exp(-((r - radius + wobble + 5.0) / 6.0) ** 2) * 0.35
    ring *= np.clip(0.45 + value_noise(rng, 90) * 1.1, 0, 1)
    stain += ring * 0.1 + np.clip((radius - r + wobble) / 4.0, 0, 1) * 0.018
    r2 = np.hypot(xx - cx - 34.0, yy - cy + 18.0)
    stain += np.exp(-((r2 - radius * 0.97) / 2.6) ** 2) * np.clip(value_noise(rng, 120), 0, 1) * 0.07

    worn = np.clip(worn, 0, 0.75)
    # composite: start from shade/light, then dirt, stain and worn ink on top
    rgb = np.zeros((H, W, 3), np.float32)
    alpha = np.zeros((H, W), np.float32)

    def over(colour, a):
        nonlocal rgb, alpha
        a = np.clip(a, 0, 1)
        out_a = a + alpha * (1 - a)
        safe = np.maximum(out_a, 1e-6)
        rgb = (np.asarray(colour, np.float32)[None, None, :] * a[:, :, None] + rgb * (alpha * (1 - a))[:, :, None]) / safe[:, :, None]
        alpha = out_a

    over((1.0, 1.0, 0.97), light)
    over((0.0, 0.0, 0.02), dark)
    over((0.45, 0.38, 0.27), dirt)
    over((0.42, 0.25, 0.1), stain)
    over(PAPER * 1.02, worn)
    return np.concatenate([np.clip(rgb, 0, 1), np.clip(alpha, 0, 1)[:, :, None]], axis=2)


def graphite_grain(rng, size=256):
    """Tileable paper tooth (0..1): where graphite catches and where not."""
    white = rng.normal(0.0, 1.0, (size, size))
    freq_y = np.fft.fftfreq(size)[:, None]
    freq_x = np.fft.fftfreq(size)[None, :]
    def filtered(sigma, stretch=1.0):
        kernel = np.exp(-2 * (np.pi * sigma) ** 2 * (freq_x ** 2 * stretch + freq_y ** 2 / stretch))
        return np.real(np.fft.ifft2(np.fft.fft2(white) * kernel))
    fine = filtered(0.7)
    mid = filtered(2.2, 1.8)
    tooth = fine / fine.std() * 0.65 + mid / mid.std() * 0.35
    tooth = (tooth - tooth.min()) / (tooth.max() - tooth.min())
    return np.clip(tooth ** 0.8, 0, 1)


def to8(arr):
    return (np.clip(arr, 0, 1) * 255.0 + 0.5).astype(np.uint8)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    rng = np.random.default_rng(SEED)
    paper = base_paper(rng)
    Image.fromarray(to8(paper)).save(OUT / "leaflet_paper.jpg", quality=92, subsampling=0, optimize=True)
    wear = wear_overlay(rng)
    Image.fromarray(to8(wear)).save(OUT / "leaflet_wear.png", optimize=True)
    grain = graphite_grain(rng)
    Image.fromarray(to8(grain)).save(OUT / "graphite_grain.png", optimize=True)
    # contact sheet: the paper with its wear, at half size
    SHEET_OUT.parent.mkdir(parents=True, exist_ok=True)
    a = wear[:, :, 3:4]
    combined = paper * (1 - a) + wear[:, :, :3] * a
    Image.fromarray(to8(combined)).resize((W // 2, H // 2), Image.LANCZOS).save(SHEET_OUT)
    for name in ("leaflet_paper.jpg", "leaflet_wear.png", "graphite_grain.png"):
        print("%-20s %7.0f KB" % (name, (OUT / name).stat().st_size / 1024.0))


if __name__ == "__main__":
    main()
