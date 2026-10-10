"""Pixel painting for the Asia wing (Floor I): a small raster painter on
integer canvases of palette codes (polygons, thick polylines, ellipses,
rings, outlines), the motifs of the wing - ruyi cloud scrolls, lotus
roundels and lotus scrolls, a dragon chasing a pearl, cranes among clouds
(Korean sanggam inlay), the taotie mask over a ground of thunder spirals
(leiwen) - and a calligraphy brush that draws real characters (山 mountain,
水 water, 月 moon) and the Zen circle (ensō) stroke by stroke, with a
slanted brush tip, pooled ink where the brush presses and dry streaks
(feibai) where it runs out, plus red seals.

Pure numpy; material functions (asia.py) sample the canvases texel by
texel (egypt.sample), so one art pixel = one texel. Row 0 of a canvas is
its TOP; x runs right. Codes are listed in ``INK``.
"""
import math
import random

import numpy as np

INK = {"ground": 0, "outline": 1, "red": 2, "green": 3, "blue": 4, "white": 5, "black": 6, "gold": 7,
       "ochre": 8, "lt_green": 9, "lt_blue": 10, "pink": 11, "orange": 12, "ink": 13, "ink_dark": 14,
       "ink_dry": 15, "seal": 16, "cobalt": 17, "cobalt_dark": 18, "cobalt_wash": 19, "inlay_white": 20,
       "inlay_black": 21, "dk_green": 22, "dk_red": 23, "raised": 24, "sunk": 25}


def blank(w, h, fill=0):
    return np.full((h, w), fill, dtype=np.int16)


def _grid(c):
    h, w = c.shape
    ys, xs = np.mgrid[0:h, 0:w]
    return xs + 0.5, ys + 0.5


# --------------------------------------------------------------------------
# raster primitives (pixel coordinates: x right, y down)
# --------------------------------------------------------------------------

def poly_mask(shape, pts):
    """Even-odd fill of a polygon (list of (x, y))."""
    h, w = shape
    ys, xs = np.mgrid[0:h, 0:w]
    xs = xs + 0.5
    ys = ys + 0.5
    inside = np.zeros(shape, dtype=bool)
    n = len(pts)
    for i in range(n):
        x0, y0 = pts[i]
        x1, y1 = pts[(i + 1) % n]
        if y0 == y1:
            continue
        cond = (ys >= min(y0, y1)) & (ys < max(y0, y1))
        xc = x0 + (ys - y0) * (x1 - x0) / (y1 - y0)
        inside ^= cond & (xs < xc)
    return inside


def fill(c, pts, code):
    c[poly_mask(c.shape, pts)] = code
    return c


def seg_dist(xs, ys, a, b):
    ax, ay = a
    bx, by = b
    dx, dy = bx - ax, by - ay
    L2 = dx * dx + dy * dy
    if L2 < 1e-12:
        return np.hypot(xs - ax, ys - ay), np.zeros_like(xs)
    t = np.clip(((xs - ax) * dx + (ys - ay) * dy) / L2, 0.0, 1.0)
    return np.hypot(xs - (ax + t * dx), ys - (ay + t * dy)), t


def line_mask(shape, pts, width):
    """Thick polyline; ``width`` a number or one per point (tapering)."""
    h, w = shape
    ys, xs = np.mgrid[0:h, 0:w]
    xs = xs + 0.5
    ys = ys + 0.5
    out = np.zeros(shape, dtype=bool)
    ws = width if isinstance(width, (list, tuple, np.ndarray)) else [width] * len(pts)
    for i in range(len(pts) - 1):
        a, b = pts[i], pts[i + 1]
        r = max(ws[i], ws[i + 1]) / 2 + 1
        x0 = max(int(min(a[0], b[0]) - r), 0)
        x1 = min(int(max(a[0], b[0]) + r) + 1, w)
        y0 = max(int(min(a[1], b[1]) - r), 0)
        y1 = min(int(max(a[1], b[1]) + r) + 1, h)
        if x1 <= x0 or y1 <= y0:
            continue
        d, t = seg_dist(xs[y0:y1, x0:x1], ys[y0:y1, x0:x1], a, b)
        rad = (ws[i] + (ws[i + 1] - ws[i]) * t) / 2
        out[y0:y1, x0:x1] |= d <= rad
    return out


def line(c, pts, width, code):
    c[line_mask(c.shape, pts, width)] = code
    return c


def ellipse_mask(shape, cx, cy, rx, ry, rot=0.0):
    xs, ys = _grid(np.zeros(shape))
    dx, dy = xs - cx, ys - cy
    ca, sa = math.cos(rot), math.sin(rot)
    u = dx * ca + dy * sa
    v = -dx * sa + dy * ca
    return (u / max(rx, 1e-6)) ** 2 + (v / max(ry, 1e-6)) ** 2 <= 1.0


def ellipse(c, cx, cy, rx, ry, code, rot=0.0):
    c[ellipse_mask(c.shape, cx, cy, rx, ry, rot)] = code
    return c


def ring(c, cx, cy, r0, r1, code):
    xs, ys = _grid(c)
    d = np.hypot(xs - cx, ys - cy)
    c[(d >= r0) & (d <= r1)] = code
    return c


def outline(c, mask, code, only_empty=False):
    """Paints a 1-pixel outline outside ``mask``."""
    m = mask
    grown = m.copy()
    grown[1:] |= m[:-1]
    grown[:-1] |= m[1:]
    grown[:, 1:] |= m[:, :-1]
    grown[:, :-1] |= m[:, 1:]
    edge = grown & ~m
    if only_empty:
        edge &= c == 0
    c[edge] = code
    return c


def spline(pts, n=12):
    """Catmull-Rom through the points (each (x, y[, extra...])); extras are
    interpolated linearly. Returns an array (k, dims)."""
    P = np.asarray(pts, dtype=np.float64)
    if len(P) < 3:
        t = np.linspace(0.0, 1.0, n * max(1, len(P) - 1) + 1)[:, None]
        return P[0] + (P[-1] - P[0]) * t
    ext = np.vstack([P[0] * 2 - P[1], P, P[-1] * 2 - P[-2]])
    out = []
    for i in range(1, len(ext) - 2):
        p0, p1, p2, p3 = ext[i - 1], ext[i], ext[i + 1], ext[i + 2]
        for k in range(n):
            t = k / n
            t2, t3 = t * t, t * t * t
            out.append(0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2
                              + (-p0 + 3 * p1 - 3 * p2 + p3) * t3))
    out.append(P[-1])
    return np.array(out)


def wrap_x(mask_fn, w):
    """Draws a motif three times shifted by -w, 0, +w (for canvases that
    wrap round a vase): mask_fn(dx) -> mask."""
    return mask_fn(-w) | mask_fn(0.0) | mask_fn(w)


# --------------------------------------------------------------------------
# motifs
# --------------------------------------------------------------------------

def ruyi(c, cx, cy, s, code, flip=False):
    """A ruyi cloud head: a heart of three lobes over a curling tail (s =
    size in pixels, about the lobe width)."""
    m = np.zeros(c.shape, dtype=bool)
    sx = -1 if flip else 1
    m |= ellipse_mask(c.shape, cx, cy - s * 0.15, s * 0.42, s * 0.36)
    m |= ellipse_mask(c.shape, cx - s * 0.42, cy + s * 0.12, s * 0.34, s * 0.3)
    m |= ellipse_mask(c.shape, cx + s * 0.42, cy + s * 0.12, s * 0.34, s * 0.3)
    tail = spline([(cx, cy + s * 0.3), (cx + sx * s * 0.2, cy + s * 0.7), (cx + sx * s * 0.75, cy + s * 0.8),
                   (cx + sx * s * 1.2, cy + s * 0.55)], 6)
    m |= line_mask(c.shape, [tuple(p) for p in tail], list(np.linspace(s * 0.26, s * 0.06, len(tail))))
    c[m] = code
    return m


def cloud_band(w, h, seed=3, ground=0, cloud=INK["white"], line_code=INK["blue"]):
    """A frieze of linked ruyi clouds (tileable along x)."""
    c = blank(w, h, ground)
    rng = random.Random(seed)
    step = h * 1.6
    k = 0
    x = step * 0.5
    while x < w + step:
        flip = k % 2 == 1
        y = h * (0.45 if k % 2 == 0 else 0.55)
        for dx in (-w, 0, w):
            mm = ruyi(c, x + dx, y, h * 0.5, cloud, flip)
            outline(c, mm, line_code)
        x += step
        k += 1
    return c


def lotus_roundel(c, cx, cy, r, petal=INK["red"], petal2=INK["pink"], heart=INK["gold"], line_code=INK["outline"],
                  n=8):
    """A frontal lotus: n outer petals, n inner petals, a gold seed pod."""
    xs, ys = _grid(c)
    dx, dy = xs - cx, ys - cy
    d = np.hypot(dx, dy) / max(r, 1e-6)
    a = np.arctan2(dy, dx)
    outer = d < 0.62 + 0.38 * np.abs(np.cos(a * n / 2)) ** 0.6
    inner = d < (0.34 + 0.32 * np.abs(np.cos(a * n / 2 + math.pi / 2)) ** 0.6) * 0.85
    pod = d < 0.26
    c[outer] = petal
    c[inner] = petal2
    c[pod] = heart
    seeds = pod & (np.mod(np.floor(dx / max(r * 0.12, 1)) + np.floor(dy / max(r * 0.12, 1)), 2) == 0) & (d < 0.2)
    c[seeds] = INK["ochre"]
    outline(c, outer, line_code)
    edge_inner = inner & ~ellipse_mask(c.shape, cx, cy, r * 0.3, r * 0.3)
    ring_px = edge_inner & ~np.roll(edge_inner, 1, 0) | edge_inner & ~np.roll(edge_inner, -1, 1)
    c[ring_px] = petal
    return outer


def lotus_scroll(w, h, seed=5, stem=INK["green"], flower=INK["cobalt"], ground=0, leaf=None):
    """Lotus scroll band (tileable along x): a wavy stem with leaves and a
    flower head in every bay."""
    c = blank(w, h, ground)
    leaf = stem if leaf is None else leaf
    bay = max(8, int(round(h * 1.8)))
    n = max(1, int(round(w / bay)))
    bay = w / n
    pts = [(x, h * 0.5 + h * 0.28 * math.sin(2 * math.pi * x / bay)) for x in np.linspace(-bay, w + bay, 6 * (n + 2))]
    c[line_mask(c.shape, pts, max(1.0, h * 0.07))] = stem
    for k in range(-1, n + 1):
        x = (k + 0.5) * bay
        up = h * 0.5 + h * 0.28 * math.sin(2 * math.pi * (x + bay * 0.25) / bay)
        fx, fy = x + bay * 0.25, up
        # flower: a fan of petals, heart
        m = ellipse_mask(c.shape, fx, fy, h * 0.2, h * 0.17)
        m |= ellipse_mask(c.shape, fx - h * 0.15, fy - h * 0.04, h * 0.1, h * 0.14, 0.4)
        m |= ellipse_mask(c.shape, fx + h * 0.15, fy - h * 0.04, h * 0.1, h * 0.14, -0.4)
        c[m] = flower
        c[ellipse_mask(c.shape, fx, fy + h * 0.02, h * 0.06, h * 0.05)] = ground
        # leaves on the opposite side of the stem
        lx = x - bay * 0.15
        ly = h * 0.5 + h * 0.28 * math.sin(2 * math.pi * lx / bay)
        c[ellipse_mask(c.shape, lx, ly + h * 0.16, h * 0.18, h * 0.07, 0.5)] = leaf
        c[ellipse_mask(c.shape, lx + h * 0.1, ly - h * 0.18, h * 0.15, h * 0.06, -0.6)] = leaf
    return c


def leiwen(w, h, cell=8, code=INK["raised"]):
    """Thunder pattern: square spirals in a grid of ``cell`` pixels
    (raised lines one pixel wide on a sunk ground)."""
    c = blank(w, h)
    ys, xs = np.mgrid[0:h, 0:w]
    lx = np.mod(xs, cell)
    ly = np.mod(ys, cell)
    flip = (np.floor_divide(xs, cell) + np.floor_divide(ys, cell)) % 2 == 1
    lx = np.where(flip, cell - 1 - lx, lx)
    # a square spiral: rings 0, 2, 4.. from the outside, open on one side
    ring_i = np.minimum(np.minimum(lx, ly), np.minimum(cell - 1 - lx, cell - 1 - ly))
    on = (ring_i % 2 == 0) & (ring_i < cell // 2)
    gap = (ly == ring_i + 1) & (lx == ring_i) & (ring_i > 0)
    on &= ~((lx == ring_i) & (ly <= ring_i + 1) & (ring_i > 0)) | gap
    c[on] = code
    return c


def taotie(w, h, raised=INK["raised"], eye=INK["gold"]):
    """The taotie mask (symmetric about the centre line): two big eyes with
    round pupils, brows curling into horns, the jaw curls, a nose ridge,
    over a leiwen ground. The mask is raised (relief), the spirals are low."""
    c = leiwen(w, h, cell=max(6, h // 6), code=INK["sunk"])
    xs, ys = _grid(c)
    cx = w * 0.5
    m = np.zeros(c.shape, dtype=bool)
    for sx in (-1, 1):
        ex, ey = cx + sx * w * 0.2, h * 0.48
        eye_m = ellipse_mask(c.shape, ex, ey, w * 0.09, h * 0.2)
        m |= eye_m
        # brow curling up into a horn
        horn = spline([(cx + sx * w * 0.06, h * 0.22), (cx + sx * w * 0.2, h * 0.1), (cx + sx * w * 0.36, h * 0.12),
                       (cx + sx * w * 0.44, h * 0.3), (cx + sx * w * 0.38, h * 0.42)], 6)
        m |= line_mask(c.shape, [tuple(p) for p in horn], h * 0.12)
        # ear / body curl outward
        body = spline([(cx + sx * w * 0.3, h * 0.62), (cx + sx * w * 0.42, h * 0.75), (cx + sx * w * 0.48, h * 0.6),
                       (cx + sx * w * 0.46, h * 0.45)], 6)
        m |= line_mask(c.shape, [tuple(p) for p in body], h * 0.1)
        # jaw curl
        jaw = spline([(cx + sx * w * 0.05, h * 0.78), (cx + sx * w * 0.16, h * 0.9), (cx + sx * w * 0.26, h * 0.82),
                      (cx + sx * w * 0.22, h * 0.72)], 6)
        m |= line_mask(c.shape, [tuple(p) for p in jaw], h * 0.09)
    m |= (np.abs(xs - cx) < w * 0.035) & (ys > h * 0.1) & (ys < h * 0.85)   # nose ridge / flange
    c[m] = raised
    for sx in (-1, 1):
        c[ellipse_mask(c.shape, cx + sx * w * 0.2, h * 0.48, w * 0.04, h * 0.09)] = eye
    return c


def dragon(w, h, seed=7, body=INK["cobalt"], dark=INK["cobalt_dark"], wash=INK["cobalt_wash"], wrap=True):
    """A five-clawed dragon chasing a flaming pearl among clouds, drawn for
    a vase's unrolled surface (``w`` wide = one turn, tileable when
    ``wrap``): a sinuous scaled body with a dorsal crest, a horned head with
    whiskers, four legs with claws, the pearl and ruyi clouds round it."""
    c = blank(w, h)
    rng = random.Random(seed)
    xs, ys = _grid(c)
    # centre line of the body: one and a half waves across the surface
    n = 40
    t = np.linspace(0.0, 1.0, n)
    bx = w * (0.08 + 0.78 * t)
    by = h * (0.5 + 0.26 * np.sin(t * math.pi * 2.6 + 0.3)) + h * 0.05 * np.sin(t * 11.0)
    width = h * (0.07 + 0.075 * np.sin(np.clip(t * 1.25, 0, 1) * math.pi) ** 0.6)
    width[-6:] *= np.linspace(1.0, 0.25, 6)            # the tail thins out

    shifts = (-w, 0, w) if wrap else (0,)

    def body_mask(dx):
        return line_mask(c.shape, [(x + dx, y) for x, y in zip(bx, by)], list(width * 2))

    def normal(i):
        j0, j1 = max(0, i - 1), min(n - 1, i + 1)
        dxv, dyv = bx[j1] - bx[j0], by[j1] - by[j0]
        L = math.hypot(dxv, dyv) or 1.0
        return dxv / L, dyv / L, dyv / L, -dxv / L          # tangent, normal (to the left of travel)

    # legs first (the body overlaps the shoulders): out from the body,
    # bent back at the elbow, a fan of four hooked claws
    for k, tt in enumerate((0.2, 0.34, 0.62, 0.76)):
        i = int(tt * (n - 1))
        x, y, wd = bx[i], by[i], width[i]
        tx, ty, nx, ny = normal(i)
        side = 1 if k % 2 == 0 else -1
        elbow = (x + nx * side * wd * 2.2 - tx * wd * 0.8, y + ny * side * wd * 2.2 - ty * wd * 0.8)
        paw = (elbow[0] + tx * wd * 1.6 + nx * side * wd * 0.5, elbow[1] + ty * wd * 1.6 + ny * side * wd * 0.5)
        for dx in shifts:
            c[line_mask(c.shape, [(x + dx, y), (elbow[0] + dx, elbow[1]), (paw[0] + dx, paw[1])],
                        [wd * 1.1, wd * 0.75, wd * 0.55])] = body
            c[ellipse_mask(c.shape, elbow[0] + dx, elbow[1], wd * 0.5, wd * 0.5)] = dark      # elbow tuft
            for a in (-1.0, -0.35, 0.35, 1.0):
                ca, sa = math.cos(a), math.sin(a)
                dxc = tx * ca - (nx * side) * sa
                dyc = ty * ca - (ny * side) * sa
                tip = (paw[0] + dxc * wd * 0.9, paw[1] + dyc * wd * 0.9)
                hook = (tip[0] + nx * side * wd * 0.35, tip[1] + ny * side * wd * 0.35)
                c[line_mask(c.shape, [(paw[0] + dx, paw[1]), (tip[0] + dx, tip[1]), (hook[0] + dx, hook[1])],
                            [max(1.2, wd * 0.32), max(1.0, wd * 0.22), 1.0])] = dark
    bm = np.zeros(c.shape, dtype=bool)
    for dx in shifts:
        bm |= body_mask(dx)
    c[bm] = body
    # scales: offset rows of small arcs
    scale_px = max(3, int(h * 0.035))
    sc = (np.mod(xs + (np.floor_divide(ys, scale_px) % 2) * scale_px * 0.5, scale_px) < 1.0) |          (np.mod(ys, scale_px) < 1.0)
    c[bm & sc] = dark

    def belly(dx):
        return line_mask(c.shape, [(x + dx, y + wd * 0.5) for x, y, wd in zip(bx, by, width)],
                         list(np.maximum(width * 0.55, 1.0)))
    bel = np.zeros(c.shape, dtype=bool)
    for dx in shifts:
        bel |= belly(dx)
    c[bel & bm] = wash
    # dorsal crest: flame spikes swept back along the upper side
    for i in range(3, n - 5, 2):
        x, y, wd = bx[i], by[i], width[i]
        tx, ty, nx, ny = normal(i)
        if ny > 0:
            nx, ny = -nx, -ny
        base0 = (x - tx * wd * 0.6 + nx * wd * 0.8, y - ty * wd * 0.6 + ny * wd * 0.8)
        base1 = (x + tx * wd * 0.6 + nx * wd * 0.8, y + ty * wd * 0.6 + ny * wd * 0.8)
        tip = (x + nx * wd * 1.9 + tx * wd * 0.9, y + ny * wd * 1.9 + ty * wd * 0.9)
        for dx in shifts:
            fill(c, [(base0[0] + dx, base0[1]), (tip[0] + dx, tip[1]), (base1[0] + dx, base1[1])], dark)
    outline(c, bm, dark, only_empty=True)
    # head at the start of the body, looking back along -x at the pearl:
    # a long snout, open jaws, a brow over a round eye, antlers and a mane
    hx, hy = bx[0], by[0]
    hw = width[3] * 1.2
    for dx in shifts:
        X = hx + dx
        hm = ellipse_mask(c.shape, X, hy, hw * 1.25, hw * 1.0)
        hm |= poly_mask(c.shape, [(X - hw * 0.4, hy - hw * 0.8), (X - hw * 2.4, hy - hw * 0.35),
                                  (X - hw * 2.5, hy + hw * 0.05), (X - hw * 0.3, hy + hw * 0.1)])   # upper jaw
        hm |= poly_mask(c.shape, [(X - hw * 0.3, hy + hw * 0.45), (X - hw * 2.0, hy + hw * 0.6),
                                  (X - hw * 2.0, hy + hw * 0.85), (X - hw * 0.1, hy + hw * 0.95)])  # lower jaw
        c[hm] = body
        outline(c, hm, dark, only_empty=True)
        c[poly_mask(c.shape, [(X - hw * 2.3, hy + hw * 0.08), (X - hw * 0.4, hy + hw * 0.12),
                              (X - hw * 0.4, hy + hw * 0.42), (X - hw * 1.9, hy + hw * 0.58)])] = 0    # open mouth
        c[line_mask(c.shape, [(X - hw * 2.2, hy + hw * 0.1), (X - hw * 0.6, hy + hw * 0.14)], 1.0)] = dark  # teeth
        c[ellipse_mask(c.shape, X - hw * 0.45, hy - hw * 0.35, hw * 0.3, hw * 0.26)] = 0                  # eye
        c[ellipse_mask(c.shape, X - hw * 0.5, hy - hw * 0.35, hw * 0.14, hw * 0.16)] = dark
        c[line_mask(c.shape, [(X - hw * 0.95, hy - hw * 0.7), (X - hw * 0.1, hy - hw * 0.75)],
                    max(1.0, hw * 0.2))] = dark                                                        # brow
        for k, (ax_, ay_) in enumerate(((1.6, -1.9), (2.1, -1.2))):                                   # antlers
            c[line_mask(c.shape, [(X + hw * 0.2, hy - hw * 0.7), (X + hw * ax_, hy + hw * ay_)],
                        [max(1.5, hw * 0.3), max(1.0, hw * 0.14)])] = dark
            c[line_mask(c.shape, [(X + hw * ax_ * 0.6, hy + hw * ay_ * 0.6),
                                  (X + hw * ax_ * 0.6 - hw * 0.1, hy + hw * ay_ * 0.6 - hw * 0.6)],
                        max(1.0, hw * 0.12))] = dark
        for k in range(4):                                                                             # mane
            a = 0.35 + k * 0.32
            c[line_mask(c.shape, [(X + hw * 0.6, hy - hw * 0.2 + k * hw * 0.3),
                                  (X + hw * (1.6 + 0.3 * k), hy - hw * 0.6 + k * hw * 0.7 + hw * math.sin(a))],
                        [max(1.5, hw * 0.28), 1.0])] = wash
        c[line_mask(c.shape, [(X - hw * 2.4, hy - hw * 0.2), (X - hw * 3.2, hy - hw * 0.9),
                              (X - hw * 3.4, hy - hw * 1.7)], [max(1.0, hw * 0.14), 1.0, 1.0])] = body   # whiskers
        c[line_mask(c.shape, [(X - hw * 1.9, hy + hw * 0.9), (X - hw * 2.6, hy + hw * 1.6),
                              (X - hw * 2.7, hy + hw * 2.3)], [max(1.0, hw * 0.14), 1.0, 1.0])] = body
    # the flaming pearl ahead of the head
    px_, py_ = hx - hw * 4.4, hy - h * 0.14
    for dx in shifts:
        c[ellipse_mask(c.shape, px_ + dx, py_, h * 0.06, h * 0.06)] = wash
        ring_m = ellipse_mask(c.shape, px_ + dx, py_, h * 0.06, h * 0.06) & ~ellipse_mask(c.shape, px_ + dx, py_,
                                                                                          h * 0.045, h * 0.045)
        c[ring_m] = dark
        for k in range(5):
            a = -math.pi / 2 + (k - 2) * 0.5
            c[line_mask(c.shape, [(px_ + dx + math.cos(a) * h * 0.07, py_ + math.sin(a) * h * 0.07),
                                  (px_ + dx + math.cos(a) * h * 0.13, py_ + math.sin(a) * h * 0.15)],
                        max(1.0, h * 0.02))] = body
    # clouds in the free space
    for k in range(7):
        cx, cy = rng.uniform(0, w), rng.uniform(h * 0.12, h * 0.88)
        if bm[int(min(h - 1, cy)), int(min(w - 1, cx))]:
            continue
        for dx in shifts:
            tmp = blank(w, h)
            mm = ruyi(tmp, cx + dx, cy, h * 0.07, 1, flip=k % 2 == 0)
            mm &= c == 0
            c[mm] = wash
            outline(c, mm, body, only_empty=True)
    return c


def crane(c, cx, cy, s, flip=False, white=INK["inlay_white"], black=INK["inlay_black"]):
    """A flying crane (s = wingspan in pixels): white body and wings with
    black flight-feather tips, a long neck forward, legs trailing."""
    sx = -1 if flip else 1

    def P(x, y):
        return (cx + sx * s * x, cy + s * y)

    # legs first (under everything), trailing behind
    c[line_mask(c.shape, [P(-0.14, 0.03), P(-0.5, 0.12)], max(1.0, s * 0.022))] = black
    c[line_mask(c.shape, [P(-0.14, 0.05), P(-0.48, 0.17)], max(1.0, s * 0.022))] = black
    # far wing, foreshortened, swept down and back
    far = poly_mask(c.shape, [P(0.06, 0.02), P(-0.08, 0.03), P(-0.34, 0.3), P(-0.14, 0.34), P(0.02, 0.12)])
    c[far] = white
    c[far & ~ellipse_mask(c.shape, *P(0.0, 0.03), s * 0.24, s * 0.24)] = black
    m = ellipse_mask(c.shape, cx, cy, s * 0.21, s * 0.075, -0.12 * sx)
    c[m] = white
    # near wing raised up and back, black flight feathers at the tip
    near = poly_mask(c.shape, [P(0.1, -0.03), P(-0.06, -0.04), P(-0.4, -0.44), P(-0.22, -0.5), P(-0.02, -0.34),
                               P(0.12, -0.14)])
    c[near] = white
    c[near & ~ellipse_mask(c.shape, *P(0.02, -0.06), s * 0.33, s * 0.33)] = black
    # long neck forward and up, small black head, beak
    c[line_mask(c.shape, [P(0.17, -0.03), P(0.32, -0.08), P(0.45, -0.12)], max(1.0, s * 0.04))] = white
    c[line_mask(c.shape, [P(0.33, -0.085), P(0.43, -0.115)], max(1.0, s * 0.045))] = black       # black neck
    c[ellipse_mask(c.shape, *P(0.47, -0.125), s * 0.035, s * 0.028)] = white
    c[line_mask(c.shape, [P(0.49, -0.125), P(0.6, -0.11)], max(1.0, s * 0.018))] = black            # beak
    return m | near | far


def crane_roundel(c, cx, cy, r, flip=False):
    """Double ring of inlay (white outside, black inside) with a crane in
    it (the sanggam 'cloud and crane' medallion)."""
    ring(c, cx, cy, r * 0.9, r, INK["inlay_white"])
    ring(c, cx, cy, r * 0.82, r * 0.88, INK["inlay_black"])
    crane(c, cx, cy, r * 1.5, flip)


# --------------------------------------------------------------------------
# calligraphy
# --------------------------------------------------------------------------

# Characters as strokes in the classical order, on a unit box (x right, y
# down); each stroke a list of (x, y, brush width) control points. The
# width swells where the brush presses (dun) and thins on the flicks.
CHARACTERS = {
    "山": [
        [(0.50, 0.06, 0.10), (0.51, 0.40, 0.09), (0.50, 0.80, 0.09), (0.50, 0.86, 0.08)],
        [(0.16, 0.34, 0.10), (0.17, 0.60, 0.085), (0.18, 0.84, 0.09), (0.40, 0.85, 0.075), (0.70, 0.84, 0.075),
         (0.86, 0.84, 0.09)],
        [(0.84, 0.28, 0.10), (0.84, 0.56, 0.085), (0.85, 0.92, 0.07)],
    ],
    "水": [
        [(0.50, 0.04, 0.10), (0.51, 0.40, 0.09), (0.50, 0.82, 0.09), (0.49, 0.90, 0.10), (0.40, 0.82, 0.05)],
        [(0.10, 0.34, 0.09), (0.36, 0.33, 0.08), (0.37, 0.36, 0.09), (0.26, 0.58, 0.07), (0.10, 0.76, 0.03)],
        [(0.82, 0.20, 0.09), (0.70, 0.34, 0.07), (0.58, 0.44, 0.04)],
        [(0.57, 0.42, 0.05), (0.68, 0.60, 0.08), (0.82, 0.78, 0.11), (0.93, 0.86, 0.06)],
    ],
    "月": [
        [(0.28, 0.08, 0.09), (0.28, 0.40, 0.085), (0.26, 0.66, 0.08), (0.18, 0.84, 0.06), (0.10, 0.94, 0.03)],
        [(0.28, 0.08, 0.08), (0.56, 0.08, 0.075), (0.74, 0.07, 0.10), (0.74, 0.45, 0.085), (0.74, 0.86, 0.085),
         (0.72, 0.93, 0.09), (0.60, 0.86, 0.04)],
        [(0.31, 0.37, 0.07), (0.52, 0.37, 0.065), (0.71, 0.36, 0.075)],
        [(0.31, 0.62, 0.07), (0.52, 0.62, 0.065), (0.71, 0.61, 0.075)],
    ],
}


def _ensō():
    """One brush stroke round a circle, about 330 degrees, thick where it
    starts (lower left), thinning and drying out toward the open end."""
    pts = []
    n = 26
    for k in range(n + 1):
        a = math.radians(205 - 335 * k / n)
        r = 0.4 + 0.015 * math.sin(k * 0.9)
        w = 0.16 - 0.09 * (k / n) ** 1.4
        pts.append((0.5 + r * math.cos(a), 0.52 - r * math.sin(a), w))
    return [pts]


CHARACTERS["ensō"] = _ensō()


def brush(c, strokes, x0, y0, size, seed=11, dry=0.55, weight=1.0):
    """Draws ``strokes`` (unit box) into canvas ``c`` at (x0, y0), ``size``
    pixels: a slanted round brush (ellipse at 45 degrees) stamped along a
    Catmull-Rom path, pooled dark ink at the start and the turns, dry
    streaks (feibai) that grow toward each stroke's end."""
    rng = np.random.default_rng(seed)
    h, w = c.shape
    xs, ys = _grid(c)
    for si, st in enumerate(strokes):
        path = spline(st, 10)
        n = len(path)
        drymask = np.zeros(c.shape, dtype=bool)
        cover = np.zeros(c.shape, dtype=bool)
        pool = np.zeros(c.shape, dtype=bool)
        lanes = rng.random(64)
        for i in range(n):
            px_ = x0 + path[i, 0] * size
            py_ = y0 + path[i, 1] * size
            r = max(0.8, path[i, 2] * size * 0.5 * weight)
            j0, j1 = max(0, i - 1), min(n - 1, i + 1)
            dx = (path[j1, 0] - path[j0, 0]) * size
            dy = (path[j1, 1] - path[j0, 1]) * size
            L = math.hypot(dx, dy) or 1.0
            nx, ny = -dy / L, dx / L
            bx0, bx1 = max(0, int(px_ - r - 2)), min(w, int(px_ + r + 3))
            by0, by1 = max(0, int(py_ - r - 2)), min(h, int(py_ + r + 3))
            if bx1 <= bx0 or by1 <= by0:
                continue
            X = xs[by0:by1, bx0:bx1] - px_
            Y = ys[by0:by1, bx0:bx1] - py_
            # the slanted tip: an ellipse at 45 degrees
            u = (X + Y) * 0.7071
            v = (-X + Y) * 0.7071
            disk = (u / r) ** 2 + (v / (r * 0.78)) ** 2 <= 1.0
            t = i / max(1, n - 1)
            lat = (X * nx + Y * ny) / r
            lane = lanes[np.clip(((lat + 1.0) * 0.5 * 63).astype(np.int64), 0, 63)]
            dry_here = disk & (lane < max(0.0, (t - 0.55) / 0.45) * dry)
            cover[by0:by1, bx0:bx1] |= disk
            drymask[by0:by1, bx0:bx1] |= dry_here
            if t < 0.12 or path[i, 2] >= np.max(path[:, 2]) * 0.98:
                pool[by0:by1, bx0:bx1] |= disk & ((u / r) ** 2 + (v / (r * 0.78)) ** 2 <= 0.5)
        ink = cover & ~drymask
        c[ink] = INK["ink"]
        c[pool & ink] = INK["ink_dark"]
        c[cover & drymask] = np.where(rng.random(int((cover & drymask).sum())) < 0.35, INK["ink_dry"], 0)
    return c


def seal(c, x0, y0, size, seed=1, kind="square"):
    """A red seal (size in pixels): a frame round a few seal-script bars."""
    rng = random.Random(seed)
    if kind == "round":
        c[ellipse_mask(c.shape, x0 + size / 2, y0 + size / 2, size / 2, size / 2)] = INK["seal"]
    else:
        c[int(y0):int(y0 + size), int(x0):int(x0 + size)] = INK["seal"]
    inner = max(2, int(size) - 4)
    sub = np.zeros((inner, inner), dtype=bool)
    k = max(1, inner // 4)
    for _ in range(5):
        if rng.random() < 0.5:
            yy = rng.randrange(0, inner)
            sub[yy, rng.randrange(0, k):inner - rng.randrange(0, k)] = True
        else:
            xx = rng.randrange(0, inner)
            sub[rng.randrange(0, k):inner - rng.randrange(0, k), xx] = True
    ys_, xs_ = np.nonzero(sub)
    for yy, xx in zip(ys_, xs_):
        Y, X = int(y0) + 2 + yy, int(x0) + 2 + xx
        if 0 <= Y < c.shape[0] and 0 <= X < c.shape[1]:
            c[Y, X] = 0
    return c


def calligraphy(w, h, char, seed=3, seals=2):
    """A hanging-scroll sheet ``w`` x ``h`` pixels: the character (or the
    ensō) large in the upper two thirds, seals below and to the left."""
    c = blank(w, h)
    size = min(w * 0.9, h * 0.56)
    x0 = (w - size) / 2
    y0 = h * 0.12
    enso = char == "ensō"
    brush(c, CHARACTERS[char], x0, y0, size, seed=seed, dry=0.8 if enso else 0.45, weight=1.0 if enso else 1.5)
    s = max(5, int(w * 0.13))
    sy = y0 + size + h * 0.07
    seal(c, w * 0.72 - s, sy, s, seed + 1)
    if seals > 1:
        seal(c, w * 0.72 - s, sy + s * 1.35, s * 0.8, seed + 2, kind="round")
    return c
