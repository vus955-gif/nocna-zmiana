"""The Rosetta Stone in its case (the vestibule at the south end of the
Egypt wing).

  rosetta_stone  0.76 x 1.12 x 0.28 m dark granodiorite slab, its top broken
                 away, a pink vein across the upper left; the polished face
                 carries the decree three times - hieroglyphs (top, broken),
                 demotic (middle), Greek capitals (bottom: the decree's real
                 opening words) - incised and pale; back and edges rough.
                 384 px/m. Origin = centre of its base, face toward Godot -Z.
  rosetta_case   the display: a black stone plinth 1.1 x 0.75 x 0.62 m with
                 a brass plaque "KAMIEŃ Z ROSETTY / 196 P.N.E.", a bronze
                 cradle on top and a glass box with bronze edges (part
                 rosetta_case_glass: the game shatters it). Marker StoneSpot
                 = where the stone's origin goes (on the plinth top, in the
                 cradle). 128 px/m. Origin = centre of the base, front -Z.
"""
import math
import random

import numpy as np
from mathutils import Vector

from artlib import egypt as E
from artlib import egypt_paint as EP
from artlib import materials as M
from artlib import pixelfont
from artlib.archkit import cull_floor, front_prism, kit
from artlib.geo import Part
from artlib.materials import P, _dither
from artlib.painter import Surface

W, H, D = 0.76, 1.12, 0.28
OUTLINE = [(-0.38, 0.0), (0.38, 0.0), (0.385, 0.35), (0.38, 0.64), (0.36, 0.78), (0.33, 0.9), (0.27, 0.97),
           (0.2, 1.03), (0.1, 1.08), (0.02, 1.12), (-0.07, 1.08), (-0.16, 1.03), (-0.24, 0.96), (-0.3, 0.88),
           (-0.36, 0.8), (-0.385, 0.62), (-0.38, 0.3)]
GREEK = ("ΒΑΣΙΛΕΥΟΝΤΟΣΤΟΥΝΕΟΥΚΑΙΠΑΡΑΛΑΒΟΝΤΟΣΤΗΝΒΑΣΙΛΕΙΑΝΠΑΡΑΤΟΥΠΑΤΡΟΣΚΥΡΙΟΥΒΑΣΙΛΕΙΩΝΜΕΓΑΛΟΔΟΞΟΥΤΟΥ"
         "ΤΗΝΑΙΓΥΠΤΟΝΚΑΤΑΣΤΗΣΑΜΕΝΟΥΚΑΙΤΑΠΡΟΣΤΟΥΣΘΕΟΥΣΕΥΣΕΒΟΥΣΑΝΤΙΠΑΛΩΝΥΠΕΡΤΕΡΟΥΤΟΥΤΟΝΒΙΟΝΤΩΝΑΝΘΡΩΠΩΝ"
         "ΕΠΑΝΟΡΘΩΣΑΝΤΟΣΚΥΡΙΟΥΤΡΙΑΚΟΝΤΑΕΤΗΡΙΔΩΝΚΑΘΑΠΕΡΟΗΦΑΙΣΤΟΣΟΜΕΓΑΣΒΑΣΙΛΕΩΣΚΑΘΑΠΕΡΟΗΛΙΟΣ")
# 3 x 5 capitals (Greek and the Latin look-alikes): enough at 384 px/m
_G = {
    "Α": ".#.|#.#|###|#.#|#.#", "Β": "##.|#.#|##.|#.#|##.", "Γ": "###|#..|#..|#..|#..", "Δ": ".#.|#.#|#.#|#.#|###",
    "Ε": "###|#..|##.|#..|###", "Ζ": "###|..#|.#.|#..|###", "Η": "#.#|#.#|###|#.#|#.#", "Θ": "###|#.#|###|#.#|###",
    "Ι": "###|.#.|.#.|.#.|###", "Κ": "#.#|##.|#..|##.|#.#", "Λ": ".#.|.#.|#.#|#.#|#.#", "Μ": "#.#|###|###|#.#|#.#",
    "Ν": "#.#|###|###|###|#.#", "Ξ": "###|...|.#.|...|###", "Ο": "###|#.#|#.#|#.#|###", "Π": "###|#.#|#.#|#.#|#.#",
    "Ρ": "##.|#.#|##.|#..|#..", "Σ": "###|#..|.#.|#..|###", "Τ": "###|.#.|.#.|.#.|.#.", "Υ": "#.#|#.#|.#.|.#.|.#.",
    "Φ": ".#.|###|#.#|###|.#.", "Χ": "#.#|#.#|.#.|#.#|#.#", "Ψ": "#.#|#.#|###|.#.|.#.", "Ω": "###|#.#|#.#|.#.|#.#",
}


def _greek_lines(w, n, step=4):
    """Greek text in rows of 3 x 5 capitals (1 px apart), 7 px a row."""
    out = np.zeros((n * 7, w), np.int16)
    text = GREEK * 4
    k = 0
    for row in range(n):
        x = 1
        while x + 3 < w and k < len(text):
            g = _G.get(text[k])
            k += 1
            if g is None:
                continue
            bm = np.array([[c == "#" for c in r] for r in g.split("|")])
            out[row * 7 + 1:row * 7 + 6, x:x + 3][bm] = 1
            x += step
    return out


def _demotic_lines(w, n, seed=5):
    """Demotic: dense cursive strokes, ligatured, in rows of 8 px."""
    rng = random.Random(seed)
    out = np.zeros((n * 9, w), np.int16)
    for row in range(n):
        y0 = row * 9 + 4
        x = w - 2
        while x > 3:
            ln = rng.randint(2, 6)
            y = y0 + rng.randint(-2, 2)
            for i in range(ln):
                if x <= 1:
                    break
                out[np.clip(y, row * 9 + 1, row * 9 + 7), x] = 1
                if rng.random() < 0.45:
                    out[np.clip(y + rng.choice((-1, 1, 2)), row * 9 + 1, row * 9 + 7), x] = 1
                y += rng.choice((-1, 0, 0, 1))
                x -= 1
            x -= rng.choice((1, 1, 2))
    return out


_CANVAS = {}


def _face_canvas(tx):
    if "c" in _CANVAS:
        return _CANVAS["c"]
    w = int(round(W / tx))
    h = int(round(H / tx))
    c = np.zeros((h, w), np.int16)
    # hieroglyphs: the broken top third, lines of signs
    lines = []
    y = h - int(round(1.1 / tx))
    for k in range(10):
        line = EP.text_line(w - 8, 40 + k)
        top = int(round((1.1 - 0.012) / tx)) - k * 12
        row = h - top
        if row < 0 or row + 10 > h:
            continue
        c[row:row + 10, 4:4 + line.shape[1]] = np.where(line > 0, 1, c[row:row + 10, 4:4 + line.shape[1]])
    # demotic: the middle band
    dem = _demotic_lines(w - 8, 14)
    row = h - int(round(0.76 / tx))
    c[row:row + dem.shape[0], 4:4 + dem.shape[1]] = np.maximum(c[row:row + dem.shape[0], 4:4 + dem.shape[1]], dem)
    # Greek: the bottom band
    gr = _greek_lines(w - 8, 20)
    row = h - int(round(0.4 / tx))
    gr = gr[:max(0, min(gr.shape[0], h - row - 6))]
    c[row:row + gr.shape[0], 4:4 + gr.shape[1]] = np.maximum(c[row:row + gr.shape[0], 4:4 + gr.shape[1]], gr)
    _CANVAS["c"] = c
    return c


def stone():
    p = Part("rosetta_stone")
    rng = random.Random(3)
    pts = [(x + rng.uniform(-0.006, 0.006), z + (rng.uniform(-0.008, 0.008) if z > 0.01 else 0.0)) for x, z in OUTLINE]
    front_prism(p, pts, D, "stone", bevel=0.008, y_back=D / 2)
    cull_floor([p])
    return p


def stone_paint(ctx, seed=1401):
    """Polished front with the three scripts incised and pale; a pink vein;
    rough back and broken edges."""
    front = ctx.n[:, 1] > 0.9
    s = E.granite(ctx, "black", seed, polish=0.3, grain=0.6, center=3.6)
    rough = ~front
    if rough.any():
        r = E.granite_dressed(ctx, "black", seed + 1)
        s.merge(E._select(r, rough), rough)
    u = ctx.uvm[:, 0]
    z = ctx.p[:, 2]
    vein = front & (np.abs(-u * 0.55 + z - 0.93 + ctx.fbm(3.0, 2, seed + 2) * 0.02) < 0.035)
    s.use_ramp(P["granite_pink"], mask=vein, shade=np.full(ctx.N, 4.0) + _dither(ctx, 0.8, seed + 3))
    if front.any():
        codes, _ = E.sample(_face_canvas(ctx.texel), u[front], z[front], ctx.texel, u0=-W / 2, v0=0.0)
        cut = np.zeros(ctx.N, bool)
        cut[front] = codes > 0
        s.use_ramp(P["granite_grey"], mask=cut, shade=np.full(ctx.N, 6.6) + _dither(ctx, 0.8, seed + 4))
        s.height = s.height - cut * 0.0008
        s.rough = np.where(cut, 0.7, s.rough)
    return s


def case():
    p = Part("rosetta_case")
    p.box((0.0, 0.0, 0.03), (1.16, 0.81, 0.06), "plinth", bevel=0.01)
    p.box((0.0, 0.0, 0.33), (1.1, 0.75, 0.56), "plinth", bevel=0.012)
    p.box((0.0, 0.0, 0.62 - 0.02), (1.14, 0.79, 0.04), "plinth", bevel=0.008)
    p.box((0.0, -0.376, 0.36), (0.5, 0.012, 0.13), "plaque", bevel=0.003)
    # bronze cradle: two clamps gripping the stone's foot
    for sx in (-1, 1):
        p.box((sx * 0.4, 0.0, 0.66), (0.05, 0.36, 0.08), "bronze", bevel=0.006)
        p.box((sx * 0.4, 0.0, 0.75), (0.02, 0.3, 0.14), "bronze", bevel=0.004)
    # glass box with bronze edges
    gx, gy, g0, g1 = 0.56, 0.38, 0.62, 1.95
    for x in (-gx, gx):
        for y in (-gy, gy):
            p.box((x, y, (g0 + g1) / 2), (0.022, 0.022, g1 - g0), "bronze", bevel=0.003)
    for z in (g0 + 0.011, g1 - 0.011):
        for y in (-gy, gy):
            p.box((0.0, y, z), (2 * gx, 0.022, 0.022), "bronze", bevel=0.003)
        for x in (-gx, gx):
            p.box((x, 0.0, z), (0.022, 2 * gy, 0.022), "bronze", bevel=0.003)
    cull_floor([p])
    g = Part("rosetta_case_glass")
    e = 0.005
    for sy in (-1, 1):
        g.poly([(-gx, sy * (gy - e), g0), (gx, sy * (gy - e), g0), (gx, sy * (gy - e), g1), (-gx, sy * (gy - e), g1)], "glass")
    for sx in (-1, 1):
        g.poly([(sx * (gx - e), -gy, g0), (sx * (gx - e), gy, g0), (sx * (gx - e), gy, g1), (sx * (gx - e), -gy, g1)], "glass")
    g.poly([(-gx, -gy, g1 - e), (gx, -gy, g1 - e), (gx, gy, g1 - e), (-gx, gy, g1 - e)], "glass")
    for f in g.bm.faces:
        f.normal_update()
        c = f.calc_center_median()
        if f.normal.dot(c - Vector((0.0, 0.0, (g0 + g1) / 2))) < 0:
            f.normal_flip()
    return [p, g]


_PL = {}


def plaque(ctx, seed=1403):
    s = M.brass(ctx, seed)
    front = ctx.n[:, 1] > 0.5
    if "t" not in _PL:
        _PL["t"] = pixelfont.trim(pixelfont.render(["KAMIEŃ Z ROSETTY", "196 P.N.E."], line_gap=2))
    u, v = ctx.uvm[:, 0], ctx.uvm[:, 1]
    if front.any():
        cu, cv = np.median(u[front]), np.median(v[front])
        ink = pixelfont.stamp(ctx, _PL["t"], cu, cv, scale=1) & front
        s.use_ramp(P["eg_black"], mask=ink, shade=np.full(ctx.N, 1.0))
        s.metal = np.where(ink, 0.0, s.metal)
    return s


def build():
    st = kit("rosetta_stone", [stone()], {"stone": stone_paint}, ppm=384, ground=0.0, ao_dist=0.08,
             preview_closeup=((0.0, -0.15, 0.6), 0.45))
    cs = kit("rosetta_case", case(), {"plinth": lambda c: E.granite(c, "black", 1405, polish=0.12, grain=0.5, center=2.6),
                                      "plaque": plaque, "bronze": lambda c: M.brass(c, 1407, tarnish_amount=2.6)},
             kinds={"glass": "glass"}, ppm=128, ground=0.0, ao_dist=0.2,
             markers=[("StoneSpot", (0.0, 0.0, 0.62), None)])
    return [st, cs]
