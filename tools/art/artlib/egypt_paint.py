"""Egyptian pixel painting for the Egypt wing (Floor I): hieroglyphs drawn as
pixel bitmaps, composed into quadrats, columns and lines of text; a small 2D
raster painter (polygons, ellipses, outlines) and the canonical Egyptian
figure (offering bearers, seated gods with human, jackal or falcon heads);
borders (block border, kheker frieze), stars.

Everything here is pure numpy on integer canvases of palette codes; the
material functions (egypt.py) sample the canvases texel by texel, so one
art pixel is exactly one texel and the glyphs stay crisp at any density.

Canvas codes (``INK``): 0 = ground (left unpainted), 1 = outline / dark
detail, 2 = blue, 3 = green, 4 = red, 5 = yellow, 6 = black, 7 = white,
8 = gold, 9 = skin of men (red-brown), 10 = skin of women (yellow),
11 = divider line (dark ochre). Row 0 of a canvas is its TOP.
"""
import math
import random

import numpy as np

INK = {"ground": 0, "outline": 1, "blue": 2, "green": 3, "red": 4, "yellow": 5, "black": 6, "white": 7,
       "gold": 8, "skin_m": 9, "skin_f": 10, "divider": 11}
_CODE = {"b": 2, "g": 3, "r": 4, "y": 5, "k": 6, "w": 7, "G": 8}

# --------------------------------------------------------------------------
# hieroglyphs: '#' = the sign's colour, 'o' = dark detail, '.' = empty.
# kind: "full" (up to 10 x 10), "tall" (narrow, 10 high), "flat" (10 wide,
# low), "small" (about 5 x 5). Colour after the classic conventions.
# --------------------------------------------------------------------------

GLYPHS = {
    "ankh": ("tall", "b", [".####.", "##..##", "##..##", ".####.", "######", "######", "..##..", "..##..",
                          "..##..", "..##.."]),
    "djed": ("tall", "b", ["#####", ".###.", "#####", ".###.", "#####", ".###.", ".###.", ".###.", ".###.",
                          "#####"]),
    "was": ("tall", "b", ["##...", ".##..", "..#..", "..#..", "..#..", "..#..", "..#..", "..#..", "..#..",
                         ".#.#."]),
    "reed": ("tall", "g", ["..#.", ".##.", "###.", "###.", ".##.", ".##.", ".##.", ".##.", ".#..", ".#.."]),
    "feather": ("tall", "g", ["##..", "###.", ".##.", ".###", ".##.", ".##.", ".##.", ".##.", ".##.", "..#."]),
    "nefer": ("tall", "r", [".#.", "###", ".#.", ".#.", ".#.", "###", "###", "###", "###", ".#."]),
    "foot": ("tall", "r", ["..##..", "..##..", "..##..", "..##..", "..##..", "..##..", "..##..", "..###.",
                          "..####", ".#####"]),
    "lotus": ("tall", "b", ["#.##.#", "#.##.#", "######", ".####.", "..##..", "..##..", "..##..", "..##..",
                           "..##..", "..##.."]),
    "papyrus": ("tall", "g", ["#####", ".###.", ".###.", "..#..", "..#..", "..#..", "..#..", "..#..", "..#..",
                             "..#.."]),
    "sedge": ("tall", "g", ["..#..", "..#.#", "#.#.#", "#.##.", ".##..", "..#..", "..#..", "..#..", "..#..",
                           ".###."]),
    "cobra": ("tall", "g", ["..##.", ".####", ".###.", "..##.", "..##.", ".##..", "##...", ".##..", "..##.",
                           "#####"]),
    "cloth": ("tall", "r", ["###", "###", ".##", ".##", ".##", ".##", ".##", "##."]),
    "man": ("full", "r", ["...##...", "..####..", "..###...", "...#....", "..###...", ".#####..", "..###...",
                         "..####..", "..######", ".##...##"]),
    "falcon": ("full", "g", ["....##..", "...####.", "...#####", "...###..", "..####..", ".#####..",
                            "######..", "#####...", "..#.#...", ".##.##.."]),
    "vulture": ("full", "b", ["......##..", ".....####.", "......#...", ".....##...", "...#####..",
                             ".#######..", "#########.", "#########.", "...#..#...", "..##..##.."]),
    "quail": ("full", "y", ["....##..", "...####.", "...###..", "..####..", ".######.", ".######.",
                           "..#####.", "...###..", "...#.#..", "..##.##."]),
    "owl": ("full", "g", ["..#..#..", "..####..", "..#oo#..", "..####..", ".######.", ".######.",
                         "..#####.", "..####..", "..#..#..", ".##..##."]),
    "scarab": ("full", "b", ["#..##..#", ".#.##.#.", "..####..", ".######.", "#.####.#", ".##..##.",
                            ".######.", "#.####.#", "..####..", ".#....#."]),
    "seated_god": ("full", "y", ["...##...", "..####..", "..##....", "...#....", "..###...", ".####...",
                                "..###...", "..#####.", "..##..#.", ".###.##."]),
    "water": ("flat", "b", ["#...#...#.", ".#.#.#.#.#", "..#...#..."]),
    "mouth": ("flat", "r", [".########.", "##########", ".########."]),
    "viper": ("flat", "y", [".......#.#", ".....#####", ".#######..", "######...."]),
    "lion": ("flat", "y", [".........#", "#.......##", ".########.", ".########.", ".##....##.",
                          ".#.#...#.#"]),
    "hand": ("flat", "r", ["..#######.", "##########", "#.#.#....."]),
    "house": ("flat", "b", ["##########", "#........#", "#........#", "#........#", "####..####"]),
    "basket": ("flat", "g", ["########", ".######.", "..####.#", "......##"]),
    "eye": ("flat", "b", ["##########", "..........", "..######..", ".##oo####.", "..######..",
                         "...#...#.#"]),
    "canal": ("flat", "b", ["##########", "#oooooooo#", "##########"]),
    "sky": ("flat", "b", ["##########", "##########", "#........#"]),
    "bolt": ("flat", "r", ["########", "#.#..#.#", "########"]),
    "loaf": ("small", "b", ["..##..", ".####.", "######"]),
    "sun": ("small", "r", [".###.", "#...#", "#.#.#", "#...#", ".###."]),
    "star": ("small", "y", ["..#..", "#####", ".###.", ".#.#.", "#...#"]),
    "vase": ("small", "r", [".###.", "#####", "#####", ".###.", "#####"]),
    "stroke": ("small", "k", ["#", "#", "#", "#"]),
}

_BITMAPS = {}


def glyph(name):
    """(mask, detail, colour code) of a hieroglyph: two bool arrays (rows from
    the top) and the INK code of its paint."""
    if name not in _BITMAPS:
        kind, col, rows = GLYPHS[name]
        mask = np.array([[c in "#o" for c in r] for r in rows], dtype=bool)
        detail = np.array([[c == "o" for c in r] for r in rows], dtype=bool)
        _BITMAPS[name] = (mask, detail, _CODE[col])
    return _BITMAPS[name]


def _by_kind(kind):
    return sorted(n for n, g in GLYPHS.items() if g[0] == kind and n != "stroke")


def _paste(canvas, name, x, y, painted=True, colour=None):
    """Draws a glyph with its top-left at (x, y); painted glyphs get their
    colour, a darker rim (code + 16 = the shade below) is left to the
    material via ``rim`` detection; 'o' pixels become outline."""
    mask, detail, code = glyph(name)
    h, w = mask.shape
    H, W = canvas.shape
    for j in range(h):
        yy = y + j
        if yy < 0 or yy >= H:
            continue
        for i in range(w):
            xx = x + i
            if xx < 0 or xx >= W or not mask[j, i]:
                continue
            canvas[yy, xx] = INK["outline"] if detail[j, i] else (colour or code if painted else 6)


def quadrat(rng, size=10):
    """A square group of signs (the Egyptian writing unit) as a canvas of
    size x size codes: one full sign, two tall signs side by side, two flat
    signs stacked, or a flat sign over small ones."""
    q = np.zeros((size, size), dtype=np.int16)
    r = rng.random()
    if r < 0.3:
        name = rng.choice(_by_kind("full"))
        m = glyph(name)[0]
        _paste(q, name, (size - m.shape[1]) // 2, size - m.shape[0])
    elif r < 0.55:
        a, b = rng.choice(_by_kind("tall")), rng.choice(_by_kind("tall"))
        ma, mb = glyph(a)[0], glyph(b)[0]
        gap = max(0, size - ma.shape[1] - mb.shape[1])
        _paste(q, a, gap // 3, size - ma.shape[0])
        _paste(q, b, size - mb.shape[1] - gap // 3, size - mb.shape[0])
    elif r < 0.8:
        flats = _by_kind("flat")
        a, b = rng.choice(flats), rng.choice(flats)
        ma, mb = glyph(a)[0], glyph(b)[0]
        if ma.shape[0] + mb.shape[0] + 1 > size:
            b = rng.choice(["water", "mouth", "hand", "canal", "sky", "bolt"])
            mb = glyph(b)[0]
        _paste(q, a, (size - ma.shape[1]) // 2, 0)
        _paste(q, b, (size - mb.shape[1]) // 2, size - mb.shape[0])
    else:
        a = rng.choice(["water", "mouth", "hand", "canal", "sky", "viper"])
        ma = glyph(a)[0]
        _paste(q, a, (size - ma.shape[1]) // 2, 0)
        smalls = _by_kind("small")
        s1, s2 = rng.choice(smalls), rng.choice(smalls)
        m1, m2 = glyph(s1)[0], glyph(s2)[0]
        _paste(q, s1, 0, size - m1.shape[0])
        _paste(q, s2, size - m2.shape[1], size - m2.shape[0])
    return q


def cartouche(rng, width, height, glyph_size=10):
    """A royal name: signs stacked inside an oval ring with a bar at the
    bottom (outline code), on a yellow ground."""
    c = np.zeros((height, width), dtype=np.int16)
    yy, xx = np.mgrid[0:height, 0:width]
    cx, cy = (width - 1) / 2, (height - 3) / 2
    rx, ry = width / 2 - 0.5, (height - 2) / 2 - 0.5
    d = ((xx - cx) / rx) ** 2 + ((yy - cy) / ry) ** 2
    inside = d <= 1.0
    ring = inside & (((xx - cx) / max(rx - 1.2, 0.5)) ** 2 + ((yy - cy) / max(ry - 1.2, 0.5)) ** 2 > 1.0)
    c[inside] = INK["yellow"]
    c[ring] = INK["outline"]
    c[height - 2:height, 1:width - 1] = INK["outline"]
    y = 3
    while y + glyph_size <= height - 4:
        name = rng.choice(_by_kind("small") + _by_kind("tall") + ["sun", "vulture", "quail", "scarab"])
        m = glyph(name)[0]
        if m.shape[0] > height - 4 - y:
            break
        _paste(c, name, (width - m.shape[1]) // 2, y)
        y += m.shape[0] + 1
    return c


def text_columns(cols, rows, seed, col_w=12, cell=10, gap=1, divider=True, cartouches=0.0):
    """Columns of hieroglyphs read top to bottom: ``cols`` columns of
    ``col_w`` pixels, each ``rows`` quadrats of ``cell`` px with ``gap`` px
    between; a 1 px divider line on the left of every column; now and then a
    cartouche spanning three quadrats (probability ``cartouches``)."""
    rng = random.Random(seed)
    step = cell + gap
    H = rows * step
    W = cols * col_w
    out = np.zeros((H, W), dtype=np.int16)
    for c in range(cols):
        x0 = c * col_w
        if divider:
            out[:, x0] = INK["divider"]
        y = 0
        while y + cell <= H:
            if cartouches > 0 and rng.random() < cartouches and y + 3 * step <= H:
                cart = cartouche(rng, col_w - 2, 3 * step - gap)
                out[y:y + cart.shape[0], x0 + 1:x0 + 1 + cart.shape[1]] = np.where(cart > 0, cart,
                                                                              out[y:y + cart.shape[0],
                                                                                  x0 + 1:x0 + 1 + cart.shape[1]])
                y += 3 * step
                continue
            q = quadrat(rng, cell)
            xo = x0 + (col_w - cell + (1 if divider else 0)) // 2
            region = out[y:y + cell, xo:xo + cell]
            out[y:y + cell, xo:xo + cell] = np.where(q > 0, q, region)
            y += step
    return out


def text_line(length, seed, cell=10, gap=1):
    """One horizontal line of quadrats (read right to left, as on friezes)."""
    rng = random.Random(seed)
    n = max(1, length // (cell + gap))
    out = np.zeros((cell, length), dtype=np.int16)
    for k in range(n):
        q = quadrat(rng, cell)
        x = k * (cell + gap)
        out[:, x:x + cell] = np.where(q > 0, q, out[:, x:x + cell])
    return out


# --------------------------------------------------------------------------
# 2D raster painter (x right, y DOWN; row 0 at the top)
# --------------------------------------------------------------------------

def poly(canvas, pts, code, ox=0.0, oy=0.0, scale=1.0, flip=False):
    """Fills a polygon (pixel centres inside, even-odd rule). ``pts`` in
    figure units (x right, y UP from the baseline); placed with its origin
    at canvas pixel (ox, oy) (oy = the baseline row), ``scale`` px per unit,
    ``flip`` mirrors x (a figure facing left)."""
    H, W = canvas.shape
    sx = -1.0 if flip else 1.0
    P = [(ox + sx * x * scale, oy - y * scale) for x, y in pts]
    xs = [p[0] for p in P]
    ys = [p[1] for p in P]
    x0, x1 = max(0, int(math.floor(min(xs)))), min(W - 1, int(math.ceil(max(xs))))
    y0, y1 = max(0, int(math.floor(min(ys)))), min(H - 1, int(math.ceil(max(ys))))
    if x1 < x0 or y1 < y0:
        return np.zeros_like(canvas, dtype=bool)
    yy, xx = np.mgrid[y0:y1 + 1, x0:x1 + 1]
    px = xx + 0.5
    py = yy + 0.5
    inside = np.zeros(px.shape, dtype=bool)
    n = len(P)
    for i in range(n):
        ax, ay = P[i]
        bx, by = P[(i + 1) % n]
        cond = (ay > py) != (by > py)
        with np.errstate(divide="ignore", invalid="ignore"):
            xint = ax + (py - ay) * (bx - ax) / (by - ay)
        inside ^= cond & (px < xint)
    full = np.zeros(canvas.shape, dtype=bool)
    full[y0:y1 + 1, x0:x1 + 1] = inside
    canvas[full] = code
    return full


def ellipse(canvas, cx, cy, rx, ry, code, ox=0.0, oy=0.0, scale=1.0, flip=False):
    """Filled ellipse in figure units (see poly)."""
    H, W = canvas.shape
    sx = -1.0 if flip else 1.0
    X = ox + sx * cx * scale
    Y = oy - cy * scale
    RX, RY = max(rx * scale, 0.5), max(ry * scale, 0.5)
    yy, xx = np.mgrid[0:H, 0:W]
    m = ((xx + 0.5 - X) / RX) ** 2 + ((yy + 0.5 - Y) / RY) ** 2 <= 1.0
    canvas[m] = code
    return m


def outline(canvas, shape_mask, code=1):
    """Paints the border pixels of a shape (4-neighbours outside it)."""
    m = shape_mask
    inner = m.copy()
    inner[1:, :] &= m[:-1, :]
    inner[:-1, :] &= m[1:, :]
    inner[:, 1:] &= m[:, :-1]
    inner[:, :-1] &= m[:, 1:]
    canvas[m & ~inner] = code


# --------------------------------------------------------------------------
# the canonical figure (units: 19 to the top of the head; faces +x)
# --------------------------------------------------------------------------

def _limb(a, b, wa, wb):
    """Quad along a -> b with half-widths wa, wb (figure units)."""
    ax, ay = a
    bx, by = b
    dx, dy = bx - ax, by - ay
    ln = math.hypot(dx, dy) or 1.0
    nx, ny = -dy / ln, dx / ln
    return [(ax + nx * wa, ay + ny * wa), (bx + nx * wb, by + ny * wb), (bx - nx * wb, by - ny * wb),
            (ax - nx * wa, ay - ny * wa)]


def _head(c, kind, ox, oy, s, flip, skin, wig_code, dy=0.0):
    """Head in profile (facing +x) on a neck at (0, 16 + dy)."""
    m = np.zeros(c.shape, dtype=bool)
    oy = oy - dy * s
    if kind == "human":
        m |= poly(c, [(-1.0, 16.0), (0.9, 16.0), (0.9, 16.9), (-0.8, 16.9)], skin, ox, oy, s, flip)
        m |= poly(c, [(-0.9, 16.6), (1.0, 16.4), (1.55, 16.7), (1.5, 17.2), (1.95, 17.65), (1.6, 18.0),
                      (1.55, 18.7), (0.6, 19.1), (-1.0, 18.8)], skin, ox, oy, s, flip)
        m |= poly(c, [(-1.6, 16.3), (-1.7, 18.6), (-1.0, 19.35), (0.6, 19.4), (1.45, 18.75), (0.9, 18.6),
                      (0.55, 17.4), (-0.1, 16.3)], wig_code, ox, oy, s, flip)
        ellipse(c, 0.95, 17.95, 0.28, 0.16, INK["white"], ox, oy, s, flip)
        ellipse(c, 1.05, 17.95, 0.12, 0.12, INK["outline"], ox, oy, s, flip)
    elif kind == "jackal":
        m |= poly(c, [(-1.0, 16.0), (0.8, 16.0), (0.9, 17.0), (-0.8, 17.0)], INK["black"], ox, oy, s, flip)
        m |= poly(c, [(-1.1, 16.8), (0.8, 16.9), (3.1, 17.2), (3.2, 17.7), (1.2, 18.4), (0.2, 19.0),
                      (-1.2, 18.6)], INK["black"], ox, oy, s, flip)
        m |= poly(c, [(-0.6, 18.4), (-0.3, 21.0), (0.4, 18.6)], INK["black"], ox, oy, s, flip)
        m |= poly(c, [(-1.5, 16.4), (-1.6, 18.5), (-0.6, 18.9), (-0.2, 16.4)], wig_code, ox, oy, s, flip)
        ellipse(c, 0.85, 18.1, 0.2, 0.12, INK["gold"], ox, oy, s, flip)
    elif kind == "falcon":
        m |= poly(c, [(-1.0, 16.0), (0.8, 16.0), (0.9, 17.0), (-0.8, 17.0)], INK["green"], ox, oy, s, flip)
        m |= poly(c, [(-1.2, 16.7), (0.9, 16.8), (1.7, 17.3), (2.0, 17.9), (1.5, 18.6), (0.4, 19.1),
                      (-1.2, 18.6)], INK["green"], ox, oy, s, flip)
        m |= poly(c, [(1.6, 17.6), (2.25, 17.75), (1.95, 17.15)], INK["yellow"], ox, oy, s, flip)
        m |= poly(c, [(-1.6, 16.3), (-1.7, 18.5), (-0.7, 18.95), (-0.1, 16.3)], wig_code, ox, oy, s, flip)
        ellipse(c, 0.95, 18.15, 0.2, 0.2, INK["outline"], ox, oy, s, flip)
        m |= ellipse(c, 0.0, 20.6, 1.4, 1.4, INK["red"], ox, oy, s, flip)
    return m


def figure(c, ox, oy, height, pose="bearer", sex="m", head="human", flip=False, offering="jar", seed=0,
           crown=None):
    """Paints one figure standing on canvas row ``oy`` (its baseline) at
    column ``ox``, ``height`` px to the top of the head, facing right (or
    left with ``flip``). Poses: "bearer" (striding, one arm forward with an
    offering, one hanging), "adore" (both arms raised in adoration),
    "seated" (a god on a block throne holding a was sceptre). Outlines in
    dark red-brown; returns the shape mask."""
    s = height / 19.0
    skin = INK["skin_f"] if sex == "f" else INK["skin_m"]
    if head != "human":
        skin = INK["skin_m"]
    wig = INK["black"] if head == "human" else INK["blue"]
    m = np.zeros(c.shape, dtype=bool)
    if pose == "seated":
        # block throne with a low back, a cushion line
        m |= poly(c, [(-2.6, 0.0), (1.4, 0.0), (1.4, 6.6), (-2.0, 6.6), (-2.0, 9.5), (-2.6, 9.5)],
                  INK["red"] if seed % 2 else INK["blue"], ox, oy, s, flip)
        poly(c, [(-2.3, 0.6), (1.1, 0.6), (1.1, 1.0), (-2.3, 1.0)], INK["gold"], ox, oy, s, flip)
        # legs: thigh forward, shin down
        m |= poly(c, _limb((-0.6, 7.6), (3.2, 7.4), 1.0, 0.8), skin, ox, oy, s, flip)
        m |= poly(c, _limb((3.0, 7.2), (3.2, 1.0), 0.7, 0.5), skin, ox, oy, s, flip)
        m |= poly(c, [(2.6, 0.0), (5.0, 0.0), (4.6, 0.8), (2.7, 1.2)], skin, ox, oy, s, flip)
        # mummiform white wrap over the legs for gods
        m |= poly(c, [(-1.3, 6.8), (3.6, 6.6), (3.7, 1.2), (2.4, 1.0), (2.4, 6.0), (-1.3, 6.4)],
                  INK["white"], ox, oy, s, flip)
        # torso and arm with the sceptre (a seated body: shoulders 2.6 units lower)
        d = -2.6
        m |= poly(c, [(-1.2, 7.4), (1.1, 7.4), (2.4, 15.6 + d), (2.1, 16.2 + d), (-2.4, 16.2 + d), (-2.6, 15.4 + d),
                      (-1.6, 10.0)], skin, ox, oy, s, flip)
        m |= poly(c, _limb((1.6, 15.0 + d), (2.8, 11.2 + d), 0.55, 0.45), skin, ox, oy, s, flip)
        m |= poly(c, _limb((2.8, 11.2 + d), (4.1, 11.8 + d), 0.45, 0.4), skin, ox, oy, s, flip)
        m |= poly(c, _limb((4.3, 0.3), (4.3, 15.0 + d), 0.22, 0.22), INK["gold"], ox, oy, s, flip)
        m |= poly(c, [(4.0, 14.8 + d), (5.2, 15.6 + d), (4.7, 16.0 + d), (4.0, 15.4 + d)], INK["gold"], ox, oy, s, flip)
        m |= _collar(c, ox, oy, s, flip, d)
        m |= _head(c, head, ox, oy, s, flip, skin, wig, d)
        if head == "human":
            # Osiris-like white crown
            m |= poly(c, [(-1.0, 19.2 + d), (0.9, 19.2 + d), (0.6, 21.8 + d), (0.0, 22.6 + d), (-0.6, 21.8 + d)],
                      INK["white"], ox, oy, s, flip)
        outline(c, m, INK["outline"])
        return m
    long_dress = sex == "f"
    stride = 0.6 if long_dress else 1.0
    # legs (back leg first)
    m |= poly(c, _limb((-0.5, 9.5), (-1.6 * stride, 1.0), 0.95, 0.5), skin, ox, oy, s, flip)
    m |= poly(c, [(-2.9 * stride, 0.0), (-0.5 * stride, 0.0), (-0.8 * stride, 1.1), (-2.2 * stride, 1.0)],
              skin, ox, oy, s, flip)
    m |= poly(c, _limb((0.6, 9.5), (2.3 * stride, 1.0), 0.95, 0.5), skin, ox, oy, s, flip)
    m |= poly(c, [(1.6 * stride, 0.0), (4.4 * stride, 0.0), (4.1 * stride, 0.7), (2.6 * stride, 1.2)], skin,
              ox, oy, s, flip)
    # torso: frontal shoulders on a profile waist
    m |= poly(c, [(-1.2, 10.4), (1.3, 10.4), (1.9, 13.5), (2.8, 15.6), (2.4, 16.2), (-2.6, 16.2),
                  (-2.9, 15.6), (-1.7, 13.0)], skin, ox, oy, s, flip)
    if long_dress:
        m |= poly(c, [(-1.4, 14.0), (1.6, 14.0), (1.7, 11.0), (2.6 * stride + 0.4, 1.0), (-1.9 * stride - 0.4, 1.0),
                      (-1.6, 11.0)], INK["white"], ox, oy, s, flip)
    else:
        m |= poly(c, [(-1.4, 11.0), (1.6, 11.0), (2.9, 7.0), (-2.0, 6.8)], INK["white"], ox, oy, s, flip)
        poly(c, [(0.6, 10.6), (1.6, 10.6), (2.9, 7.0), (2.0, 7.0)], INK["yellow"], ox, oy, s, flip)
        poly(c, [(-1.4, 10.4), (1.4, 10.4), (1.5, 11.1), (-1.5, 11.1)], INK["red"], ox, oy, s, flip)
    # arms
    if pose == "adore":
        for sh, el, hd in (((2.2, 15.4), (3.6, 15.8), (4.0, 18.6)), ((-1.8, 15.4), (2.6, 15.0), (3.2, 17.6))):
            m |= poly(c, _limb(sh, el, 0.6, 0.45), skin, ox, oy, s, flip)
            m |= poly(c, _limb(el, hd, 0.45, 0.4), skin, ox, oy, s, flip)
    else:
        m |= poly(c, _limb((-2.2, 15.4), (-2.6, 12.0), 0.6, 0.45), skin, ox, oy, s, flip)
        m |= poly(c, _limb((-2.6, 12.0), (-2.4, 9.4), 0.45, 0.4), skin, ox, oy, s, flip)
        m |= poly(c, _limb((2.1, 15.3), (3.0, 12.6), 0.6, 0.45), skin, ox, oy, s, flip)
        m |= poly(c, _limb((3.0, 12.6), (5.0, 13.4), 0.45, 0.4), skin, ox, oy, s, flip)
        m |= _offering(c, offering, ox, oy, s, flip, seed)
        # the hanging hand carries a lotus or a duck by the legs
        if seed % 3 == 0:
            m |= poly(c, _limb((-2.4, 9.4), (-2.4, 6.4), 0.12, 0.12), INK["green"], ox, oy, s, flip)
            m |= poly(c, [(-3.0, 6.6), (-1.8, 6.6), (-2.1, 5.3), (-2.7, 5.3)], INK["blue"], ox, oy, s, flip)
    m |= _collar(c, ox, oy, s, flip)
    m |= _head(c, head, ox, oy, s, flip, skin, wig)
    if crown == "khepresh":
        # the king's blue war crown with a gold uraeus
        m |= poly(c, [(-1.8, 16.6), (-1.9, 18.4), (-1.2, 20.6), (0.2, 21.0), (1.3, 19.8), (1.5, 18.4), (0.7, 18.3),
                      (0.4, 17.2), (-0.6, 16.4)], INK["blue"], ox, oy, s, flip)
        poly(c, [(1.3, 18.3), (1.8, 18.6), (1.6, 19.2), (1.2, 18.9)], INK["gold"], ox, oy, s, flip)
    elif crown == "nemes":
        m |= poly(c, [(-1.9, 15.4), (-1.9, 18.6), (-1.0, 19.6), (0.7, 19.6), (1.45, 18.7), (0.7, 18.5), (0.5, 17.0),
                      (0.1, 15.2)], INK["yellow"], ox, oy, s, flip)
        poly(c, [(1.3, 18.6), (1.8, 18.9), (1.6, 19.4), (1.2, 19.1)], INK["gold"], ox, oy, s, flip)
    if long_dress:
        m |= poly(c, [(-1.7, 19.3), (0.8, 19.4), (0.6, 16.6), (-0.4, 15.0), (-1.9, 15.2)], wig, ox, oy, s, flip)
        poly(c, [(-1.0, 19.35), (0.5, 19.4), (0.5, 19.0), (-1.0, 19.0)], INK["red"], ox, oy, s, flip)
    outline(c, m, INK["outline"])
    return m


def _collar(c, ox, oy, s, flip, dy=0.0):
    m = np.zeros(c.shape, dtype=bool)
    oy = oy - dy * s
    for k, code in enumerate((INK["blue"], INK["red"], INK["green"])):
        r0 = 0.45 + 0.42 * k
        r1 = r0 + 0.42
        pts = []
        for i in range(9):
            a = math.pi * (0.08 + 0.84 * i / 8)
            pts.append((0.0 - math.cos(a) * (2.0 + r0 * 0.9), 16.3 - math.sin(a) * r0 * 1.5))
        for i in range(8, -1, -1):
            a = math.pi * (0.08 + 0.84 * i / 8)
            pts.append((0.0 - math.cos(a) * (2.0 + r1 * 0.9), 16.3 - math.sin(a) * r1 * 1.5))
        m |= poly(c, pts, code, ox, oy, s, flip)
    return m


def _offering(c, kind, ox, oy, s, flip, seed):
    m = np.zeros(c.shape, dtype=bool)
    hx, hy = 5.2, 13.5
    if kind == "jar":
        m |= ellipse(c, hx, hy + 1.5, 0.9, 1.2, INK["red"] if seed % 2 else INK["blue"], ox, oy, s, flip)
        m |= poly(c, [(hx - 0.35, hy + 2.4), (hx + 0.35, hy + 2.4), (hx + 0.45, hy + 3.0), (hx - 0.45, hy + 3.0)],
                  INK["yellow"], ox, oy, s, flip)
    elif kind == "tray":
        m |= poly(c, [(hx - 1.4, hy + 0.3), (hx + 1.4, hy + 0.3), (hx + 1.2, hy + 0.7), (hx - 1.2, hy + 0.7)],
                  INK["yellow"], ox, oy, s, flip)
        for k in range(3):
            m |= poly(c, [(hx - 1.0 + k * 0.9, hy + 0.7), (hx - 0.4 + k * 0.9, hy + 0.7), (hx - 0.7 + k * 0.9, hy + 2.3)],
                      INK["yellow"] if k % 2 else INK["white"], ox, oy, s, flip)
        m |= ellipse(c, hx, hy + 2.8, 0.6, 0.45, INK["green"], ox, oy, s, flip)
    elif kind == "bird":
        m |= ellipse(c, hx + 0.3, hy + 1.2, 1.3, 0.75, INK["white"], ox, oy, s, flip)
        m |= ellipse(c, hx + 1.5, hy + 1.9, 0.45, 0.4, INK["green"], ox, oy, s, flip)
        m |= poly(c, [(hx - 1.0, hy + 1.0), (hx - 1.9, hy + 1.6), (hx - 1.0, hy + 1.5)], INK["blue"], ox, oy, s, flip)
    elif kind == "lotus":
        m |= poly(c, _limb((hx, hy), (hx + 0.4, hy + 4.0), 0.12, 0.12), INK["green"], ox, oy, s, flip)
        m |= poly(c, [(hx - 0.5, hy + 4.0), (hx + 1.3, hy + 4.0), (hx + 1.0, hy + 5.4), (hx + 0.4, hy + 4.7),
                      (hx - 0.2, hy + 5.4)], INK["blue"], ox, oy, s, flip)
    return m


def offering_table(c, ox, oy, height):
    """A stand heaped with loaves, a joint, lotus and jars (units as figure)."""
    s = height / 19.0
    m = np.zeros(c.shape, dtype=bool)
    m |= poly(c, [(-0.6, 0.0), (0.6, 0.0), (0.4, 7.0), (-0.4, 7.0)], INK["yellow"], ox, oy, s)
    m |= poly(c, [(-3.0, 7.0), (3.0, 7.0), (3.0, 7.6), (-3.0, 7.6)], INK["yellow"], ox, oy, s)
    rng = random.Random(int(ox * 7 + oy))
    for k in range(5):
        x = -2.4 + k * 1.2
        code = rng.choice([INK["yellow"], INK["white"], INK["red"]])
        m |= poly(c, [(x - 0.5, 7.6), (x + 0.5, 7.6), (x, 9.6 + rng.random())], code, ox, oy, s)
    m |= ellipse(c, -0.6, 10.6, 1.2, 0.7, INK["red"], ox, oy, s)
    m |= ellipse(c, 1.0, 10.9, 0.9, 0.6, INK["green"], ox, oy, s)
    for x in (-1.6, 0.2, 1.8):
        m |= poly(c, _limb((x, 9.6), (x + 0.3, 13.0), 0.1, 0.1), INK["green"], ox, oy, s)
        m |= poly(c, [(x - 0.4, 13.0), (x + 1.0, 13.0), (x + 0.8, 14.2), (x + 0.3, 13.6), (x - 0.2, 14.2)],
                  INK["blue"], ox, oy, s)
    outline(c, m, INK["outline"])
    return m


# --------------------------------------------------------------------------
# borders, friezes, stars
# --------------------------------------------------------------------------

def block_border(width, height=6, block=6):
    """The 'block border' of Egyptian painting: coloured rectangles (blue,
    red, green, ...) separated by a black-and-white pair of lines; periodic in
    3 * (block + 2) px."""
    out = np.zeros((height, width), dtype=np.int16)
    cycle = (INK["blue"], INK["red"], INK["green"])
    x = 0
    k = 0
    while x < width:
        out[:, x:x + block] = cycle[k % 3]
        out[:, x + block:x + block + 1] = INK["black"]
        out[:, x + block + 1:x + block + 2] = INK["white"]
        x += block + 2
        k += 1
    out[0, :] = INK["outline"]
    out[-1, :] = INK["outline"]
    return out


def kheker(width, height=40, pitch=8):
    """Kheker frieze: a row of stylised bundles of reeds knotted under a
    rounded head, in alternating colours (tomb walls, under ceilings)."""
    out = np.zeros((height, width), dtype=np.int16)
    cycle = (INK["green"], INK["red"], INK["blue"])
    for k, x in enumerate(range(0, width, pitch)):
        code = cycle[k % 3]
        w = pitch - 2
        out[height // 3:height, x + 1:x + 1 + w] = code
        out[height // 3 - w // 2:height // 3, x + 2:x + w] = code
        out[height // 3 + 3:height // 3 + 5, x + 1:x + 1 + w] = INK["yellow"]
        out[height // 2 + 4:height, x + 1 + w // 2 - 1:x + 1 + w // 2] = INK["outline"]
        out[:, x] = INK["ground"]
    out[-2:, :] = INK["outline"]
    return out


STAR = ["...#...", "...#...", "#######", ".#####.", "..###..", ".##.##.", "##...##"]


def star_mask():
    return np.array([[c == "#" for c in r] for r in STAR], dtype=bool)


def sema_tawy(width, height, seed=1):
    """The 'Union of the Two Lands' relief of a royal throne's side: the
    windpipe-and-lungs sign in the middle, two Nile gods (Hapy) tying the
    lily and the papyrus round it. Returns a canvas of codes."""
    c = np.zeros((height, width), dtype=np.int16)
    cx = width // 2
    base = height - 3
    s = height / 19.0
    # the sema sign: lungs (a rounded blob) on a windpipe
    m = poly(c, _limb((0.0, 1.5), (0.0, 13.0), 0.45, 0.45), INK["green"], cx, base, s)
    m |= ellipse(c, 0.0, 7.0, 1.6, 3.2, INK["red"], cx, base, s)
    # plant stems tied round it
    for side in (-1, 1):
        for k in range(3):
            a0 = (0.2 * side, 9.0 + k * 0.6)
            a1 = (side * (2.6 + k * 1.2), 15.5 + k * 0.6)
            m |= poly(c, _limb(a0, a1, 0.16, 0.16), INK["green"], cx, base, s)
            hx, hy = a1
            if side < 0:
                m |= poly(c, [(hx - 0.6, hy), (hx + 0.6, hy), (hx + 0.9, hy + 1.6), (hx, hy + 0.9), (hx - 0.9, hy + 1.6)],
                          INK["blue"], cx, base, s)
            else:
                m |= poly(c, [(hx - 0.2, hy), (hx + 0.2, hy), (hx + 1.0, hy + 1.6), (hx - 1.0, hy + 1.6)],
                          INK["green"], cx, base, s)
    outline(c, m, INK["outline"])
    # the two Nile gods pulling, facing the middle
    gh = int(height * 0.92)
    figure(c, cx - int(5.5 * s), base, gh, pose="bearer", sex="m", flip=False, offering="lotus", seed=seed)
    figure(c, cx + int(5.5 * s), base, gh, pose="bearer", sex="m", flip=True, offering="lotus", seed=seed + 1)
    return c
