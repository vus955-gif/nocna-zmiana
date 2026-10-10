"""A 5 x 7 pixel font with Polish letters, for real, readable words painted
into atlases (stencils, engraved plaques, box prints) instead of the
pseudo-text of materials.text_marks.

Every glyph is 5 columns wide. Rows of one text line (11 in all):
    0-1   accents above capitals (Ż Ć Ś Ź Ó Ń) and the i/j dots
    2-8   the 7-row body: capitals, digits, ascenders; lowercase x-height
          is rows 4-8
    9-10  descenders (g j p q y ,) and ogonki (Ą Ę ą ę)
Glyphs advance 6 pixels (1 blank column); a space is 4 pixels.

    bits = render(["W RAZIE POŻARU", "ZBIĆ SZYBKĘ"])      # bool (rows, cols)
    on = stamp(ctx, bits, center_u, center_v, scale=1)     # bool per texel

``stamp`` places the bitmap in the surface's metre-UV plane (ctx.uvm) on
whole texels (one font pixel = ``scale`` texels), so the letters stay
crisp: the atlas packer snaps islands to the texel grid, texel centres sit
at (i + 0.5) / ppm in metre UVs. Box faces are projected readable from
outside (u to the right, v up), see geo.box_project.
"""
import numpy as np

ROWS = 11
ADVANCE = 6
SPACE = 4

_BODY = {
    "A": ".###.|#...#|#...#|#####|#...#|#...#|#...#",
    "B": "####.|#...#|#...#|####.|#...#|#...#|####.",
    "C": ".###.|#...#|#....|#....|#....|#...#|.###.",
    "D": "####.|#...#|#...#|#...#|#...#|#...#|####.",
    "E": "#####|#....|#....|####.|#....|#....|#####",
    "F": "#####|#....|#....|####.|#....|#....|#....",
    "G": ".###.|#...#|#....|#.###|#...#|#...#|.####",
    "H": "#...#|#...#|#...#|#####|#...#|#...#|#...#",
    "I": ".###.|..#..|..#..|..#..|..#..|..#..|.###.",
    "J": "..###|...#.|...#.|...#.|...#.|#..#.|.##..",
    "K": "#...#|#..#.|#.#..|##...|#.#..|#..#.|#...#",
    "L": "#....|#....|#....|#....|#....|#....|#####",
    "Ł": "#....|#....|#.#..|##...|#....|#....|#####",
    "M": "#...#|##.##|#.#.#|#.#.#|#...#|#...#|#...#",
    "N": "#...#|#...#|##..#|#.#.#|#..##|#...#|#...#",
    "O": ".###.|#...#|#...#|#...#|#...#|#...#|.###.",
    "P": "####.|#...#|#...#|####.|#....|#....|#....",
    "Q": ".###.|#...#|#...#|#...#|#.#.#|#..#.|.##.#",
    "R": "####.|#...#|#...#|####.|#.#..|#..#.|#...#",
    "S": ".####|#....|#....|.###.|....#|....#|####.",
    "T": "#####|..#..|..#..|..#..|..#..|..#..|..#..",
    "U": "#...#|#...#|#...#|#...#|#...#|#...#|.###.",
    "V": "#...#|#...#|#...#|#...#|#...#|.#.#.|..#..",
    "W": "#...#|#...#|#...#|#.#.#|#.#.#|#.#.#|.#.#.",
    "X": "#...#|#...#|.#.#.|..#..|.#.#.|#...#|#...#",
    "Y": "#...#|#...#|.#.#.|..#..|..#..|..#..|..#..",
    "Z": "#####|....#|...#.|..#..|.#...|#....|#####",
    "0": ".###.|#...#|#..##|#.#.#|##..#|#...#|.###.",
    "1": "..#..|.##..|..#..|..#..|..#..|..#..|.###.",
    "2": ".###.|#...#|....#|...#.|..#..|.#...|#####",
    "3": "####.|....#|....#|.###.|....#|....#|####.",
    "4": "...#.|..##.|.#.#.|#..#.|#####|...#.|...#.",
    "5": "#####|#....|####.|....#|....#|#...#|.###.",
    "6": "..##.|.#...|#....|####.|#...#|#...#|.###.",
    "7": "#####|....#|...#.|..#..|.#...|.#...|.#...",
    "8": ".###.|#...#|#...#|.###.|#...#|#...#|.###.",
    "9": ".###.|#...#|#...#|.####|....#|...#.|.##..",
    "a": ".....|.....|.###.|....#|.####|#...#|.####",
    "b": "#....|#....|####.|#...#|#...#|#...#|####.",
    "c": ".....|.....|.###.|#....|#....|#....|.###.",
    "d": "....#|....#|.####|#...#|#...#|#...#|.####",
    "e": ".....|.....|.###.|#...#|#####|#....|.###.",
    "f": "..##.|.#...|####.|.#...|.#...|.#...|.#...",
    "g": ".....|.....|.####|#...#|#...#|.####|....#",
    "h": "#....|#....|####.|#...#|#...#|#...#|#...#",
    "i": ".....|.....|.##..|..#..|..#..|..#..|.###.",
    "j": ".....|.....|..##.|...#.|...#.|...#.|...#.",
    "k": "#....|#....|#..#.|#.#..|##...|#.#..|#..#.",
    "l": ".##..|..#..|..#..|..#..|..#..|..#..|.###.",
    "ł": ".##..|..#..|..##.|.##..|..#..|..#..|.###.",
    "m": ".....|.....|##.#.|#.#.#|#.#.#|#.#.#|#...#",
    "n": ".....|.....|####.|#...#|#...#|#...#|#...#",
    "o": ".....|.....|.###.|#...#|#...#|#...#|.###.",
    "p": ".....|.....|####.|#...#|#...#|####.|#....",
    "q": ".....|.....|.####|#...#|#...#|.####|....#",
    "r": ".....|.....|#.##.|##..#|#....|#....|#....",
    "s": ".....|.....|.####|#....|.###.|....#|####.",
    "t": ".#...|.#...|####.|.#...|.#...|.#..#|..##.",
    "u": ".....|.....|#...#|#...#|#...#|#..##|.##.#",
    "v": ".....|.....|#...#|#...#|#...#|.#.#.|..#..",
    "w": ".....|.....|#...#|#...#|#.#.#|#.#.#|.#.#.",
    "x": ".....|.....|#...#|.#.#.|..#..|.#.#.|#...#",
    "y": ".....|.....|#...#|#...#|#...#|.####|....#",
    "z": ".....|.....|#####|...#.|..#..|.#...|#####",
    ".": ".....|.....|.....|.....|.....|.....|..#..",
    ",": ".....|.....|.....|.....|.....|.....|..#..",
    ":": ".....|..#..|.....|.....|.....|..#..|.....",
    "-": ".....|.....|.....|.###.|.....|.....|.....",
    "!": "..#..|..#..|..#..|..#..|..#..|.....|..#..",
    "'": "..#..|..#..|.....|.....|.....|.....|.....",
    "/": "....#|...#.|...#.|..#..|.#...|.#...|#....",
    "(": "...#.|..#..|.#...|.#...|.#...|..#..|...#.",
    ")": ".#...|..#..|...#.|...#.|...#.|..#..|.#...",
    "+": ".....|..#..|..#..|#####|..#..|..#..|.....",
    "*": ".....|#.#.#|.###.|#####|.###.|#.#.#|.....",
    "=": ".....|.....|#####|.....|#####|.....|.....",
    "№": "#..#.|##.#.|#.##.|#..#.|#..#.|...##|...##",
}
# rows above (accent) and below (descender / ogonek)
_ABOVE = {
    "dot": ["..#..", "....."],
    "acute": ["...#.", "..#.."],
    "idot": [".....", "..#.."],       # the i / j dot sits in body row 1 (drawn via _BODY override)
}
_BELOW = {
    "g": [".###.", "....."],
    "j": ["#..#.", ".##.."],
    "p": ["#....", "....."],
    "q": ["....#", "....."],
    "y": [".###.", "....."],
    ",": [".#...", "....."],
    "ogonek": ["...#.", "...##"],
}
# letter -> (base glyph, accent above, below)
_COMPOSED = {
    "Ą": ("A", None, "ogonek"), "Ć": ("C", "acute", None), "Ę": ("E", None, "ogonek"),
    "Ń": ("N", "acute", None), "Ó": ("O", "acute", None), "Ś": ("S", "acute", None),
    "Ź": ("Z", "acute", None), "Ż": ("Z", "dot", None),
    "ą": ("a", None, "ogonek"), "ć": ("c", "acute-low", None), "ę": ("e", None, "ogonek"),
    "ń": ("n", "acute-low", None), "ó": ("o", "acute-low", None), "ś": ("s", "acute-low", None),
    "ź": ("z", "acute-low", None), "ż": ("z", "dot-low", None),
}


def _rows(s):
    return [list(r) for r in s.split("|")]


def glyph(ch):
    """(11, 5) bool array for one character; unknown characters are blank."""
    g = np.zeros((ROWS, 5), dtype=bool)
    base, above, below = _COMPOSED.get(ch, (ch, None, None))
    if base in _BODY:
        body = np.array(_rows(_BODY[base])) == "#"
        g[2:9] = body
    if base in ("i", "j"):
        g[2, 2 if base == "i" else 3] = True            # the dot, a blank row above the x-height
    if base in _BELOW:
        g[9:11] = np.array([list(r) for r in _BELOW[base]]) == "#"
    if below is not None:
        og = np.array([list(r) for r in _BELOW[below]]) == "#"
        g[9:11] |= og
    if above in ("acute", "dot"):
        g[0:2] = np.array([list(r) for r in _ABOVE[above]]) == "#"
    elif above == "acute-low":                          # lowercase: accent in the free body rows
        g[1, 3] = True
        g[2, 2] = True
    elif above == "dot-low":
        g[2, 2] = True
    return g


def text_width(line, bold=False):
    w = 0
    for ch in line:
        w += SPACE + bold if ch == " " else ADVANCE + bold
    return max(0, w - 1)


def render(lines, line_gap=1, align="center", bold=False):
    """Bitmap (bool, rows x cols) of one or more lines of text. ``bold``
    doubles every vertical stroke (6-pixel glyphs, 7-pixel advance): reads
    from further away, for stencils and box prints."""
    if isinstance(lines, str):
        lines = [lines]
    width = max(text_width(l, bold) for l in lines)
    height = len(lines) * ROWS + (len(lines) - 1) * line_gap
    out = np.zeros((height, width), dtype=bool)
    gw = 6 if bold else 5
    for k, line in enumerate(lines):
        w = text_width(line, bold)
        x = {"center": (width - w) // 2, "left": 0, "right": width - w}[align]
        y = k * (ROWS + line_gap)
        for ch in line:
            if ch == " ":
                x += SPACE + bold
                continue
            g = glyph(ch)
            if bold:
                g = np.concatenate([g, np.zeros((ROWS, 1), dtype=bool)], axis=1)
                g[:, 1:] |= g[:, :-1].copy()
            out[y:y + ROWS, x:x + gw] |= g
            x += ADVANCE + bold
    return out


def trim(bits):
    """Crops empty border rows/columns (e.g. unused accent rows)."""
    rows = np.flatnonzero(bits.any(axis=1))
    cols = np.flatnonzero(bits.any(axis=0))
    if len(rows) == 0:
        return bits[:0, :0]
    return bits[rows[0]:rows[-1] + 1, cols[0]:cols[-1] + 1]


def stamp(ctx, bits, center_u, center_v, scale=1, u=None, v=None):
    """Bool per texel: True where the text ``bits`` covers the texel. The
    bitmap is centred on (center_u, center_v) in the surface's metre-UV plane
    (or the given ``u``, ``v`` per texel, in metres) and snapped to whole
    texels; one font pixel covers ``scale`` x ``scale`` texels."""
    u = ctx.uvm[:, 0] if u is None else u
    v = ctx.uvm[:, 1] if v is None else v
    ix = np.floor(u / ctx.texel).astype(np.int64)
    iy = np.floor(v / ctx.texel).astype(np.int64)
    h, w = bits.shape
    x0 = int(np.floor(center_u / ctx.texel)) - (w * scale) // 2
    y_top = int(np.floor(center_v / ctx.texel)) + (h * scale) // 2
    col = (ix - x0) // scale
    row = (y_top - iy) // scale
    inside = (col >= 0) & (col < w) & (row >= 0) & (row < h) & (ix >= x0) & (iy <= y_top)
    out = np.zeros(ctx.N, dtype=bool)
    out[inside] = bits[row[inside], col[inside]]
    return out


def stamp_image(img_shape, bits, cx, cy, scale=1):
    """Bool mask (H, W) for a flat image: text centred on pixel (cx, cy)
    (x right, y down)."""
    H, W = img_shape
    h, w = bits.shape
    big = np.repeat(np.repeat(bits, scale, axis=0), scale, axis=1)
    out = np.zeros((H, W), dtype=bool)
    x0 = int(cx) - big.shape[1] // 2
    y0 = int(cy) - big.shape[0] // 2
    xs0, ys0 = max(0, x0), max(0, y0)
    xs1, ys1 = min(W, x0 + big.shape[1]), min(H, y0 + big.shape[0])
    if xs1 > xs0 and ys1 > ys0:
        out[ys0:ys1, xs0:xs1] = big[ys0 - y0:ys1 - y0, xs0 - x0:xs1 - x0]
    return out
