"""Floor I, Egypt wing kit: the horizontal bands of the gallery walls and the
painted ceiling beams, in 4 / 2 / 1 / 0.5 m run modules (x = -W/2 .. W/2,
wall plane z = 0, mouldings on the room side = Godot -Z), 64 px/m. The flat
wall between the bands is the shell with the tile field "sandstone_ashlar";
the ceiling between the beams is the field "star_ceiling".

  egypt_dado_*     red granite dado 0-1.2 m: black granite toe, polished red
                   panels jointed every metre, a painted torus roll and a
                   fillet on top. Datum = floor (origin on the floor).
  egypt_frieze_*   hieroglyph frieze: a 1 m face mapped with the world tile
                   "hieroglyph_band" (continuous along the wall, one band
                   per metre of height) between two painted torus rolls.
                   Datum = the bottom edge of the face, which must sit on a
                   whole metre (e.g. 7.0) so the band lines up with the tile;
                   the rolls overhang 0.07 m below and above.
  egypt_cornice_*  Egyptian cavetto cornice ("gorge"): a torus roll, the
                   flaring cove painted with upright palm leaves (blue,
                   green, red, green every 0.125 m: modules join seamlessly)
                   and a flat crowning fascia. 1.0 m tall, 0.72 m deep.
                   Datum = ceiling (origin at its TOP).
  egypt_beam_*     painted architrave beam 0.6 wide x 0.7 deep running along
                   X (4 / 2 / 1 m): block borders on the sides around a line
                   of blue hieroglyphs on yellow, a column of yellow stars
                   on the blue soffit. Datum = ceiling (origin at its TOP
                   centre); lay them across the room every 4 m.
"""
import math

import numpy as np

from artlib import egypt as E
from artlib import egypt_paint as EP
from artlib.archkit import LENGTHS, kit, moulding
from artlib.geo import Part
from artlib.materials import P, _dither, smoothstep

def granite_jointed(pitch=1.0, kind="red"):
    def fn(ctx):
        s = E.granite(ctx, kind, 61, polish=0.14)
        u = ctx.uvm[:, 0]
        vertical = np.abs(ctx.n[:, 2]) < 0.5
        m = ((u + 1e-4) % pitch < ctx.texel) & vertical
        s.shade[m] -= 2.6
        s.height = s.height - m * 0.002
        return s
    return fn


def dado(W):
    p = Part("egypt_dado")
    moulding(p, [(-0.15, 0.0), (-0.15, 0.13), (-0.14, 0.145), (-0.12, 0.15)], W, "granite_black")
    moulding(p, [(-0.12, 0.15), (-0.12, 1.02)], W, "granite_red")
    # torus roll: a half round of 0.06 on a fillet
    roll = [(-0.12, 1.02)]
    for i in range(1, 8):
        a = -math.pi / 2 + math.pi * i / 8
        roll.append((-0.12 - 0.055 * math.cos(a), 1.08 + 0.06 * math.sin(a)))
    roll.append((-0.12, 1.14))
    moulding(p, roll, W, "torus")
    moulding(p, [(-0.12, 1.14), (-0.09, 1.15), (-0.09, 1.2), (0.0, 1.2)], W, "sandstone")
    return p


def frieze(W):
    p = Part("egypt_frieze")
    for zc in (0.0, 1.0):
        roll = [(0.0, zc - 0.07)]
        for i in range(0, 9):
            a = -math.pi / 2 + math.pi * i / 8
            roll.append((-0.03 - 0.065 * math.cos(a), zc + 0.07 * math.sin(a)))
        roll.append((0.0, zc + 0.07))
        moulding(p, roll, W, "torus")
    # the inscribed face, 1 m tall, 3 cm in front of the wall
    moulding(p, [(-0.03, 0.06), (-0.03, 0.94)], W, "band")
    # thin margins of plain stone between the rolls and the face (the tile's
    # own block borders read as the band's edge)
    moulding(p, [(-0.03, 0.0), (-0.03, 0.06)], W, "band")
    moulding(p, [(-0.03, 0.94), (-0.03, 1.0)], W, "band")
    return p


def _cove_profile(z0):
    pts = []
    n = 9
    for i in range(n + 1):
        a = math.pi / 2 * i / n
        pts.append((-0.06 - 0.62 * (1.0 - math.cos(a)), z0 + 0.14 + 0.72 * math.sin(a) ** 1.15))
    return pts


COVE = sum(math.hypot(b[0] - a[0], b[1] - a[1]) for a, b in zip(_cove_profile(0.0), _cove_profile(0.0)[1:]))


def cornice(W):
    p = Part("egypt_cornice")
    H = 1.0
    z0 = -H
    roll = [(0.0, z0)]
    for i in range(0, 9):
        a = -math.pi / 2 + math.pi * i / 8
        roll.append((-0.06 - 0.07 * math.cos(a), z0 + 0.07 + 0.07 * math.sin(a)))
    roll.append((-0.06, z0 + 0.14))
    moulding(p, roll, W, "torus")
    # the gorge: a concave quarter-ellipse flaring out to the crown
    cove = _cove_profile(z0)
    moulding(p, cove, W, "cove")
    moulding(p, [cove[-1], (-0.72, z0 + 0.88), (-0.72, 0.0), (0.0, 0.0)], W, "sandstone")
    return p


def beam(W):
    p = Part("egypt_beam")
    p.box((0.0, 0.0, -0.35), (W, 0.6, 0.7), "beam", bevel=0.015)
    return p


_BEAM_TEXT = {}


def beam_paint(ctx, seed=17):
    """Beam: sides = block border, a line of blue signs on a yellow band,
    block border; soffit = a column of yellow stars on blue between red
    borders; top unpainted."""
    s = E.sandstone(ctx, seed, center=5.8, strata=0.3)
    nz = ctx.n[:, 2]
    side = np.abs(nz) < 0.5
    soffit = nz < -0.5
    ix, iy = E.px(ctx)
    codes = np.zeros(ctx.N, np.int16)
    # sides: v runs up the side from -0.7 (box projection: v = z)
    z = ctx.p[:, 2]
    row = np.floor((z + 0.7) / ctx.texel + 1e-6).astype(np.int64)    # 0 .. 44 from the bottom
    if "line" not in _BEAM_TEXT:
        _BEAM_TEXT["line"] = EP.text_line(256, seed)
        _BEAM_TEXT["bb"] = EP.block_border(256, 6)
    line = _BEAM_TEXT["line"]
    bb = _BEAM_TEXT["bb"]
    col = np.mod(ix, 256)
    m = side & (row >= 2) & (row < 8)
    codes[m] = bb[np.clip(7 - row[m], 0, 5), col[m]]
    m = side & (row >= 36) & (row < 42)
    codes[m] = bb[np.clip(41 - row[m], 0, 5), col[m]]
    band = side & (row >= 9) & (row < 35)
    codes[band] = EP.INK["yellow"]
    tl = side & (row >= 17) & (row < 27)
    g = line[np.clip(26 - row[tl], 0, 9), col[tl]]
    codes[tl] = np.where(g > 0, np.where(g == EP.INK["yellow"], EP.INK["blue"], g), EP.INK["yellow"])
    # soffit: across = y
    yy = np.floor((ctx.p[:, 1] + 0.3) / ctx.texel + 1e-6).astype(np.int64)    # 0 .. 38
    codes[soffit] = EP.INK["blue"]
    edge = soffit & ((yy < 4) | (yy > 34))
    codes[edge] = EP.INK["red"]
    sm = EP.star_mask()
    lx = np.mod(ix, 16) - 4
    ly = yy - 15
    inside = soffit & (lx >= 0) & (lx < 7) & (ly >= 0) & (ly < 7)
    st = np.zeros(ctx.N, bool)
    st[inside] = sm[6 - ly[inside], lx[inside]]
    codes[st] = EP.INK["yellow"]
    rims = np.zeros(ctx.N, np.int16)
    return E.paint_over(ctx, s, codes, rims, seed + 1, flake=0.28)


def build():
    out = []
    fns_sand = {"sandstone": lambda c: E.sandstone(c, 23, center=6.0), "torus": E.binding}
    for W, tag in LENGTHS:
        show = tag == "4m"
        out.append(kit(f"egypt_dado_{tag}", [dado(W)],
                       {"granite_black": lambda c: E.granite(c, "black", 31, polish=0.2),
                        "granite_red": granite_jointed(), **fns_sand}, wall=True, preview=show))
        out.append(kit(f"egypt_frieze_{tag}", [frieze(W)], {"torus": E.binding}, wall=True, ground=None,
                       kinds={"band": "tile:hieroglyph_band"}, preview=show))
        out.append(kit(f"egypt_cornice_{tag}", [cornice(W)],
                       {"cove": lambda c: E.leaves(c, cove_len=COVE), **fns_sand},
                       wall=True, ground=None, ceiling=0.0, ao_dist=0.5, preview=show))
        if W >= 1.0:
            out.append(kit(f"egypt_beam_{tag}", [beam(W)], {"beam": beam_paint}, ground=None, ceiling=0.0,
                           ao_dist=0.4, preview=show))
    return out
