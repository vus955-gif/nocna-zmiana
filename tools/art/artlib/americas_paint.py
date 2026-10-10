"""Pixel motifs of the Americas and Oceania wing (Floor I): canvases of
integer codes that the material functions (americas.py) sample texel by
texel, so one art pixel is exactly one texel and every line stays crisp.

The motifs are invented in the manner of the cultures shown, not copied
from any object: stepped frets (xicalcoliuhqui), rows of beads, square
cartouches holding abstract signs (rings, bars and dots, spirals, eyes,
water, flames), feathered borders, a plumed serpent band, quincunxes; for
the Pacific: the triangles, zigzags, ladders and stars of printed bark
cloth and the twill of plaited mats.

Two kinds of canvas:
  relief canvases - int levels: 0 = sunk field, 1 = low band, 2 = raised
                    motif, 3 = high relief (carved stone friezes, the
                    disc, altars); ``relief_shade`` turns them into
                    per-pixel lighting (lit top-left rims, cast shadows)
  paint canvases  - INK codes (0 = unpainted)
Row 0 of every canvas is its TOP; x runs right.
"""
import math
import random

import numpy as np

INK = {"ground": 0, "line": 1, "turq": 2, "red": 3, "white": 4, "black": 5, "gold": 6, "ochre": 7,
       "green": 8, "blue": 9, "brown": 11, "dark": 12}


# --------------------------------------------------------------------------
# small helpers
# --------------------------------------------------------------------------

def disc(size, r, cx=None, cy=None):
    """Bool mask of a filled circle (pixel centres) in a size x size box."""
    cx = (size - 1) / 2.0 if cx is None else cx
    cy = (size - 1) / 2.0 if cy is None else cy
    yy, xx = np.mgrid[0:size, 0:size]
    return (xx - cx) ** 2 + (yy - cy) ** 2 <= r * r + 0.25


def ring(size, r_out, r_in):
    return disc(size, r_out) & ~disc(size, r_in)


def paste(canvas, mask, x, y, code):
    """ORs ``mask`` (bool) into ``canvas`` at top-left (x, y) with ``code``
    (clipped at the borders)."""
    H, W = canvas.shape
    h, w = mask.shape
    x0, y0 = max(0, x), max(0, y)
    x1, y1 = min(W, x + w), min(H, y + h)
    if x1 <= x0 or y1 <= y0:
        return
    sub = mask[y0 - y:y1 - y, x0 - x:x1 - x]
    reg = canvas[y0:y1, x0:x1]
    reg[sub] = code


def paste_wrap(canvas, mask, x, y, code):
    """Like paste, but wraps around the canvas horizontally (tiles)."""
    W = canvas.shape[1]
    for dx in (-W, 0, W):
        paste(canvas, mask, x + dx, y, code)


def bitmap(rows):
    return np.array([[c == "#" for c in r] for r in rows], dtype=bool)


def scale_up(mask, k):
    return np.repeat(np.repeat(mask, k, axis=0), k, axis=1)


# --------------------------------------------------------------------------
# stepped fret (xicalcoliuhqui)
# --------------------------------------------------------------------------

# one rising fret on an 8 x 8 grid of cells (y down): a staircase climbing
# from the bottom left to a squared spiral hooked at the top right
_FRET_CELLS = [(0, 7), (1, 7), (1, 6), (2, 6), (2, 5), (3, 5), (3, 4), (3, 3), (3, 2), (3, 1), (3, 0),
               (4, 0), (5, 0), (6, 0), (7, 0), (7, 1), (7, 2), (7, 3), (6, 3), (5, 3), (5, 2)]


def fret_unit(t=4, flip_v=False, flip_h=False):
    """Bool mask (8t x 8t) of one stepped fret, stroke ``t`` px."""
    m = np.zeros((8, 8), dtype=bool)
    for x, y in _FRET_CELLS:
        m[y, x] = True
    if flip_v:
        m = m[::-1]
    if flip_h:
        m = m[:, ::-1]
    return scale_up(m, t)


def fret_band(width, height, t=4, gap=0):
    """A running band of stepped frets, alternately rising and hanging (the
    hanging ones mirrored top-down), each 8t wide; ``height`` >= 8t, the
    frets centred vertically. Periodic in 16t (+ gaps)."""
    out = np.zeros((height, width), dtype=bool)
    unit = 8 * t
    y = (height - unit) // 2
    k = 0
    x = 0
    while x < width + unit:
        paste(out, fret_unit(t, flip_v=bool(k % 2)), x, y, True)
        x += unit + gap
        k += 1
    return out


# --------------------------------------------------------------------------
# beads, feathers, chevrons
# --------------------------------------------------------------------------

def bead(d):
    """A jade bead seen from the front: a ring with a centre dot (d px)."""
    r = d / 2.0
    m = disc(d, r - 0.2) & ~disc(d, max(0.6, r - 1.6))
    m |= disc(d, max(0.5, r * 0.28))
    return m


def bead_row(width, height, pitch=8, d=6):
    out = np.zeros((height, width), dtype=bool)
    y = (height - d) // 2
    for x in range(0, width, pitch):
        paste(out, bead(d), x + (pitch - d) // 2, y, True)
    return out


def feather_row(width, height, pitch=6):
    """A row of hanging plume tips: rounded U-shapes with a dark quill line."""
    out = np.zeros((height, width), dtype=np.int16)
    for x in range(0, width, pitch):
        for j in range(height):
            t = j / max(1, height - 1)
            half = (pitch - 1) / 2.0 * math.sqrt(max(0.0, 1.0 - max(0.0, t - 0.55) ** 2 / 0.2025))
            c = x + (pitch - 1) / 2.0
            for i in range(int(math.floor(c - half)), int(math.ceil(c + half)) + 1):
                if 0 <= i < width and abs(i - c) <= half:
                    out[j, i] = 1
        qx = x + pitch // 2
        if qx < width:
            out[: height * 2 // 3, qx] = 2
    return out


def chevrons(width, height, pitch=8):
    """Downward chevrons (zigzag rows) as a bool mask."""
    out = np.zeros((height, width), dtype=bool)
    for j in range(height):
        for i in range(width):
            k = (i % pitch)
            k = min(k, pitch - 1 - k)
            if (j - k) % (pitch // 2) == 0:
                out[j, i] = True
    return out


# --------------------------------------------------------------------------
# signs in cartouches (abstract, invented)
# --------------------------------------------------------------------------

SIGNS = {
    "ring": ["....####....", "..##....##..", ".#........#.", ".#...##...#.", "#...####...#", "#...####...#",
             "#...####...#", "#...####...#", ".#...##...#.", ".#........#.", "..##....##..", "....####...."],
    "spiral": ["############", "#..........#", "#.########.#", "#.#......#.#", "#.#.####.#.#", "#.#.#..#.#.#",
               "#.#.#.##.#.#", "#.#.#....#.#", "#.#.######.#", "#.#........#", "#.##########", "#..........."],
    "bars3": ["............", "..##....##..", "..##....##..", "............", "############",
              "############", "............", "############", "############", "............",
              "############", "############"],
    "dots4": ["............", ".##.##.##.##", ".##.##.##.##", "............", "............",
              "############", "############", "............", "............", "############",
              "############", "............"],
    "eye": ["............", "............", "...######...", ".##......##.", "#....##....#", "#...####...#",
            "#...####...#", "#....##....#", ".##......##.", "...######...", "............", "............"],
    "water": ["............", "..##....##..", ".#..#..#..#.", "#....##....#", "............", "..##....##..",
              ".#..#..#..#.", "#....##....#", "............", "..##....##..", ".#..#..#..#.", "#....##....#"],
    "flame": ["....#.......", "...##....#..", "...##...##..", "..###...##..", "..###..###.#", ".####..###.#",
              ".####.####.#", "############", "############", ".##########.", "..########..", "...######..."],
    "petals": ["....####....", "....#..#....", "....#..#....", "....####....", "####.##.####", "#..##..##..#",
               "#..##..##..#", "####.##.####", "....####....", "....#..#....", "....#..#....", "....####...."],
    "mountain": [".....##.....", "....####....", "....####....", "...######...", "...######...", "..########..",
                 "..########..", ".##########.", ".##########.", "############", "............", "#.#.#..#.#.#"],
    "steps": ["######......", "#....#......", "#....####...", "#.......#...", "####....####", "...#.......#",
              "...####....#", "......#....#", "......######", "............", "#.#.#.#.#.#.", "............"],
    "shell": ["..########..", ".#........#.", "#..######..#", "#.#......#.#", "#.#.####.#.#", "#.#.#..#.#.#",
              "#.#.#.##.#.#", "#.#.#....#.#", "#.#.######.#", "#.#........#", "#.##########", "............"],
    "star": [".....##.....", ".....##.....", ".....##.....", "....####....", "..########..", "############",
             "############", "..########..", "....####....", ".....##.....", ".....##.....", ".....##....."],
}


def sign(name):
    return bitmap(SIGNS[name])


def cartouche(name, size=20, frame=2, dots=True):
    """A rounded square cartouche (``size`` px) holding sign ``name`` scaled
    to fit; returns (frame mask, sign mask)."""
    yy, xx = np.mgrid[0:size, 0:size]
    c = (size - 1) / 2.0
    k = 3.5
    d = (np.abs(xx - c) / (size / 2.0)) ** k + (np.abs(yy - c) / (size / 2.0)) ** k
    outer = d <= 1.0
    inner_size = size / 2.0 - frame
    d2 = (np.abs(xx - c) / inner_size) ** k + (np.abs(yy - c) / inner_size) ** k
    inner = d2 <= 1.0
    fr = outer & ~inner
    if dots and size >= 20:
        # a dotted inner border: every other pixel of the next ring in
        ring2 = inner & ~((np.abs(xx - c) / (inner_size - 1.2)) ** k + (np.abs(yy - c) / (inner_size - 1.2)) ** k <= 1.0)
        fr |= ring2 & ((xx + yy) % 3 == 0)
    g = sign(name)
    s = g.shape[0]
    box = int(round(size - 2 * frame - 4))
    if box >= 2 * s:
        g = scale_up(g, box // s)
    gm = np.zeros((size, size), dtype=bool)
    o = (size - g.shape[0]) // 2
    paste(gm, g, o, o, True)
    return fr, gm & inner


# --------------------------------------------------------------------------
# quincunx, serpent band
# --------------------------------------------------------------------------

def quincunx(size=16):
    """Four dots round a centre dot inside a ring (the four quarters)."""
    m = ring(size, size / 2.0 - 0.2, size / 2.0 - 2.0)
    r = size / 9.0
    for dx, dy in ((0, 0), (-1, -1), (1, -1), (-1, 1), (1, 1)):
        m |= disc(size, r, (size - 1) / 2.0 + dx * size * 0.22, (size - 1) / 2.0 + dy * size * 0.22)
    return m


def serpent_band(width, height, seed=3, waves=2):
    """A plumed serpent undulating along a band: (body, scales, plumes)
    bool masks. The body is a sine of ``waves`` periods over ``width``
    (periodic), plume tufts rise from the crests."""
    body = np.zeros((height, width), dtype=bool)
    scales = np.zeros((height, width), dtype=bool)
    plumes = np.zeros((height, width), dtype=bool)
    amp = height * 0.22
    thick = max(3.0, height * 0.17)
    cy = height / 2.0
    xs = np.arange(width)
    yc = cy + amp * np.sin(xs / width * waves * 2.0 * math.pi)
    yy = np.arange(height)[:, None]
    d = np.abs(yy - yc[None, :])
    body = d <= thick
    edge = body & (d > thick - 1.0)
    # belly scales: a dotted line inside the body
    scales = (d <= 1.0) & ((xs[None, :] % 4) < 2)
    # plume tufts: three feathers rising from every crest and trough
    for k in range(waves * 2):
        x0 = int(round((k + 0.5) / (waves * 2) * width))
        up = k % 2 == 1
        y0 = yc[x0 % width] + (-thick if up else thick)
        for j, ang in enumerate((-0.5, 0.0, 0.5)):
            for s in range(int(height * 0.28)):
                x = int(round(x0 + math.sin(ang) * s * 1.1)) % width
                y = int(round(y0 + (-s if up else s) * math.cos(ang)))
                if 0 <= y < height:
                    plumes[y, x] = True
                    if s > height * 0.18 and 0 <= x + 1 < width:
                        plumes[y, (x + 1) % width] = True
    return body & ~edge, edge, scales, plumes


# --------------------------------------------------------------------------
# relief lighting
# --------------------------------------------------------------------------

def relief_shade(levels):
    """Per-pixel shading of a relief canvas lit from the top left: +1 on
    the lit rim of a raised step, -0.7 on its far rim, -1.2 in the cast
    shadow just below/right of a higher neighbour (float array)."""
    L = levels.astype(np.int16)
    H, W = L.shape
    up = np.vstack([L[:1], L[:-1]])
    left = np.hstack([L[:, :1], L[:, :-1]])
    down = np.vstack([L[1:], L[-1:]])
    right = np.hstack([L[:, 1:], L[:, -1:]])
    upleft = np.vstack([left[:1], left[:-1]])
    out = np.zeros((H, W))
    out[(L > up) | (L > left)] += 1.0
    out[(L > down) | (L > right)] -= 0.7
    shadow = (up > L) | (left > L) | (upleft > L)
    out[shadow] -= 1.2
    return out


def relief_wrap_shade(levels):
    """relief_shade for a canvas that tiles horizontally and vertically."""
    big = np.tile(levels, (3, 3))
    H, W = levels.shape
    return relief_shade(big)[H:2 * H, W:2 * W]


# --------------------------------------------------------------------------
# the frieze (8 x 1 m at 64 px/m)
# --------------------------------------------------------------------------

_CACHE = {}


def frieze_canvas(seed=21):
    """512 x 64 px: a band of beads on top, a main register of panels
    (stepped frets, a pair of cartouches, a plumed serpent, a quincunx
    pair) between incised lines, and a feathered border below.
    Returns (levels, paint). Periodic horizontally."""
    key = ("frieze", seed)
    if key in _CACHE:
        return _CACHE[key]
    W, H = 512, 64
    lv = np.zeros((H, W), dtype=np.int16)
    pt = np.zeros((H, W), dtype=np.int16)
    rng = random.Random(seed)
    # top: a low band carrying raised beads
    lv[0:8] = 1
    br = bead_row(W, 8, pitch=8, d=6)
    lv[0:8][br] = 2
    pt[0:8][br] = INK["turq"]
    lv[8, :] = 0
    # bottom: a low band of hanging plumes
    lv[56:64] = 1
    fr = feather_row(W, 8, pitch=8)
    lv[56:64][fr > 0] = 2
    pt[56:64][fr == 1] = INK["green"]
    pt[56:64][fr == 2] = INK["line"]
    lv[55, :] = 0
    # main register rows 10..53 (44 px): panels with raised frames
    y0, y1 = 10, 54
    lv[9, :] = 1
    lv[54, :] = 1
    panels = [("fret", 160), ("cart", 64), ("serpent", 160), ("cart", 64), ("quin", 64)]
    x = 0
    names = list(SIGNS)
    for kind, w in panels:
        lv[y0 - 1:y1 + 1, x:x + 2] = 1          # panel divider
        inner = (x + 3, y0, w - 4, y1 - y0)
        ix, iy, iw, ih = inner
        if kind == "fret":
            m = fret_band(iw, ih, t=5)
            sub = lv[iy:iy + ih, ix:ix + iw]
            sub[m] = 2
            ps = pt[iy:iy + ih, ix:ix + iw]
            ps[m] = INK["white"]
            ps[~m] = INK["red"]
        elif kind == "cart":
            for k in range(2):
                fr_, gm = cartouche(names[rng.randrange(len(names))], 20)
                cx = ix + (iw - 2 * 20 - 6) // 2 + k * 26
                cy = iy + (ih - 20) // 2
                paste(lv, fr_, cx, cy, 2)
                paste(lv, gm, cx, cy, 3)
                paste(pt, fr_, cx, cy, INK["turq"])
                paste(pt, gm, cx, cy, INK["black"])
            sub = pt[iy:iy + ih, ix:ix + iw]
            sub[sub == 0] = INK["red"]
        elif kind == "serpent":
            body, edge, sc, pl = serpent_band(iw, ih, seed + 1, waves=2)
            sub = lv[iy:iy + ih, ix:ix + iw]
            sub[body | edge] = 2
            sub[pl] = 2
            sub[sc & body] = 3
            ps = pt[iy:iy + ih, ix:ix + iw]
            ps[body] = INK["turq"]
            ps[edge] = INK["line"]
            ps[pl] = INK["green"]
            ps[sc & body] = INK["white"]
            ps[ps == 0] = INK["red"]
        elif kind == "quin":
            q = quincunx(18)
            for k in range(2):
                qx = ix + 4 + k * 30
                qy = iy + (ih - 18) // 2
                paste(lv, q, qx, qy, 2)
                paste(pt, q, qx, qy, INK["ochre"])
            sub = pt[iy:iy + ih, ix:ix + iw]
            sub[sub == 0] = INK["red"]
        x += w
    _CACHE[key] = (lv, pt)
    return lv, pt


# --------------------------------------------------------------------------
# a running fret strip (dado, cornice, altars)
# --------------------------------------------------------------------------

def fret_strip(width, height, t=3):
    """(levels, paint) of a narrow inlaid fret strip: turquoise frets on an
    obsidian-black ground between thin shell-white lines."""
    lv = np.zeros((height, width), dtype=np.int16)
    pt = np.full((height, width), INK["black"], dtype=np.int16)
    m = fret_band(width, height - 4, t=t)
    lv[2:height - 2][m] = 1
    pt[2:height - 2][m] = INK["turq"]
    pt[0, :] = INK["white"]
    pt[height - 1, :] = INK["white"]
    lv[0, :] = 1
    lv[height - 1, :] = 1
    return lv, pt


# --------------------------------------------------------------------------
# Pacific bark cloth (tapa)
# --------------------------------------------------------------------------

def tapa_canvas(width, height, variant=0, seed=5):
    """Printed bark cloth: a grid of panels outlined in dark brown, filled
    with triangles, zigzags, ladders, crosshatch, stars and leaf rows in
    two browns and black on the pale cloth. ``variant`` 0..2 changes the
    layout and fills. Returns a paint canvas (INK codes, 0 = bare cloth)."""
    rng = random.Random(seed * 31 + variant)
    c = np.zeros((height, width), dtype=np.int16)
    cell = 32
    border = 2
    yy, xx = np.mgrid[0:cell, 0:cell]
    fills = []
    # triangles in rows
    tri = (yy >= (cell - 1) - 2 * np.abs(xx % 8 - 3.5) * (cell / 16.0)) & (yy % 8 < 6)
    fills.append(("tri", (yy % 8) >= np.abs((xx % 8) - 3.5) * 1.6))
    fills.append(("zig", ((yy + np.abs((xx % 8) - 4)) % 6) < 2))
    fills.append(("ladder", ((xx % 6) < 2) | (yy % 5 == 0)))
    fills.append(("hatch", ((xx + yy) % 5 == 0) | ((xx - yy) % 5 == 0)))
    star = np.zeros((cell, cell), dtype=bool)
    cc = (cell - 1) / 2.0
    star |= (np.abs(xx - cc) < 1.5) & (np.abs(yy - cc) < cell * 0.4)
    star |= (np.abs(yy - cc) < 1.5) & (np.abs(xx - cc) < cell * 0.4)
    star |= (np.abs(np.abs(xx - cc) - np.abs(yy - cc)) < 1.0) & (np.abs(xx - cc) < cell * 0.28)
    fills.append(("star", star))
    leaf = (((xx % 8) - 3.5) ** 2 / 9.0 + ((yy % 10) - 4.5) ** 2 / 20.0) < 1.0
    fills.append(("leaf", leaf & ~((xx % 8) == 4)))
    tri_mask = tri
    del tri_mask
    ny = height // cell
    nx = width // cell
    for j in range(ny):
        for i in range(nx):
            name, mask = fills[(i * 2 + j * (1 + variant) + variant) % len(fills)]
            code = (INK["brown"], INK["dark"], INK["black"])[(i + j * 2 + rng.randrange(2)) % 3]
            if (i + j + variant) % 4 == 3:
                code = 0          # a plain panel now and then
            sub = c[j * cell:(j + 1) * cell, i * cell:(i + 1) * cell]
            sub[mask[: sub.shape[0], : sub.shape[1]]] = code
    # panel grid lines (double lines every cell)
    for j in range(ny + 1):
        y = j * cell
        for b in range(border):
            if 0 <= y + b < height:
                c[(y + b) % height, :] = INK["dark"]
    for i in range(nx + 1):
        x = i * cell
        for b in range(border):
            c[:, (x + b) % width] = INK["dark"]
    return c


# --------------------------------------------------------------------------
# woven mats
# --------------------------------------------------------------------------

def mat_pattern(width, height, strip=3, seed=7):
    """Plaited mat (2/2 twill of ``strip``-px strips): returns (dir, edge,
    dyed) int/bool canvases - dir 0 = warp strip on top, 1 = weft on top;
    edge = the 1-px gap between strips; dyed = strips dyed dark in a band of
    stepped diamonds every so often."""
    yy, xx = np.mgrid[0:height, 0:width]
    i = xx // strip
    j = yy // strip
    over = ((i + j) // 2) % 2
    edge = np.where(over == 0, (xx % strip) == 0, (yy % strip) == 0)
    # dyed strands: stepped diamond outlines (two cells thick) in a band of
    # 9 strip-rows every 16, a diamond every 16 strips
    im = np.mod(i, 16)
    jm = np.mod(j, 16)
    d = np.abs(im - 8) + np.abs(jm - 4)
    dyed = (jm < 9) & ((d == 4) | (d == 5) | (d == 0))
    return over, edge, dyed
