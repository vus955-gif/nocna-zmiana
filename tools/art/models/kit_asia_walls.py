"""Floor I, Asia wing kit: wall runs, the bracket cornice, beams and posts.

  asia_dado_4m/2m/1m/05m    lacquered wainscot 1.1 m: a black-lacquer
                            plinth, a cinnabar frame with a stile every
                            0.5 m, sunk black panels each with a gilt cloud
                            medallion, gilt-bronze corner plates, a capping
                            rail. Datum = the floor; wall plane z = 0.
  asia_frieze_4m/2m/1m/05m  the painted frieze: a 1 m face mapped with the
                            world field tile:asia_band between two lacquer
                            rails. Datum = the face's bottom edge, on a
                            whole metre (the tile is one band per metre).
  asia_eaves_4m/2m/1m       the bracket cornice under the ceiling (dougong):
                            a painted architrave on the wall, a bracket set
                            every 1 m (big block, crossed arms, small blocks,
                            a second tier, the sloping lever arm, the beam
                            head), red panels between the sets, the painted
                            eave plate under the ceiling. Datum = the
                            ceiling (hangs 1.05 m), projects 0.66 m.
  asia_beam_4m              painted ceiling beam 0.32 x 0.42 m along x
                            (hoop bands and whirl rosettes every 1 m, so
                            beams of any length tile); origin = top centre
                            on the ceiling plane (hangs down). ArtKit lays
                            them across a room every 4 m.
  asia_corbel               a carved cloud bracket (queti) under a beam end:
                            wall piece, origin on the wall at its TOP (= the
                            beam's underside, ceiling - 0.42 m).
  asia_post_base            stone base of a timber post: a granite plinth
                            and a lotus drum; origin = centre of the floor;
                            the post stands on it at y = 0.4.
  asia_post_shaft           the post, 1 m of round cinnabar lacquer
                            (world field tile:asia_lacquer): scale Y to the
                            height between the base and the capital.
  asia_post_capital         the post head: a painted band on the shaft and a
                            four-way bracket set; origin = the ceiling,
                            hangs 1.2 m (the shaft ends at ceiling - 1.2).
Front = -Z (Godot) like every kit piece.
"""
import math

import numpy as np
from mathutils import Matrix, Vector

from artlib import asia as A
from artlib import asia_paint as AP
from artlib import egypt as E
from artlib import materials as M
from artlib.archkit import LENGTHS, front_prism, kit, plan_sweep
from artlib.asia_geo import arm_outline, ccw, cull_back, cull_top, dou, side_prism
from artlib.geo import Part
from artlib.materials import P, _dither
from artlib.painter import Surface

I = AP.INK


# --------------------------------------------------------------------------
# dado
# --------------------------------------------------------------------------

DADO_H = 1.1


def dado(W):
    p = Part("dado")
    D = 0.07
    # black plinth
    p.box((0.0, -0.05, 0.08), (W, 0.1, 0.16), "base", bevel=0.01)
    # frame: rails
    p.box((0.0, -D / 2, 0.21), (W, D, 0.1), "frame", bevel=0.008)
    p.box((0.0, -D / 2, 0.98), (W, D, 0.12), "frame", bevel=0.008)
    # capping rail
    p.box((0.0, -0.045, 1.07), (W, 0.09, 0.06), "frame", bevel=0.012)
    # stiles every 0.5 m (half stiles at the module ends: runs make full ones)
    n = int(round(W / 0.5))
    for k in range(n + 1):
        x = -W / 2 + k * 0.5
        w = 0.08
        x0, x1 = max(-W / 2, x - w / 2), min(W / 2, x + w / 2)
        p.box(((x0 + x1) / 2, -D / 2, 0.6), (x1 - x0, D, 0.66), "frame", bevel=0.006)
    # sunk panels and their gilt corner plates
    for k in range(n):
        xc = -W / 2 + (k + 0.5) * 0.5
        p.box((xc, -0.015, 0.595), (0.42, 0.03, 0.66), "panel")
        for sx in (-1, 1):
            for sz in (-1, 1):
                p.box((xc + sx * 0.185, -0.032, 0.595 + sz * 0.3), (0.05, 0.006, 0.05), "fitting", bevel=0.002)
    cull_back([p])
    return p


_MEDALLION = {}


def _medallion():
    if "c" in _MEDALLION:
        return _MEDALLION["c"]
    c = AP.blank(32, 48)
    AP.ring(c, 16, 24, 9, 10.5, I["gold"])
    m = AP.ruyi(c, 16, 23, 9, I["gold"])
    c[AP.ellipse_mask(c.shape, 16, 22, 2.5, 2.5)] = I["red"]
    _MEDALLION["c"] = c
    return c


def dado_panel(W, seed=1201):
    """Sunk black panels, a gilt cloud medallion centred on each (panel
    centres at x = 0.25 mod 0.5, or 0 on the half-metre module)."""
    off = 0.25 if W >= 1.0 else 0.0

    def fn(ctx):
        s = A.lacquer(ctx, seed, ramp="lacquer_black", center=3.0, under="lacquer_red", wear=0.3, crackle=0.5)
        front = ctx.n[:, 1] > 0.7
        lu = np.mod(-ctx.p[:, 0] - off + 0.25, 0.5) - 0.25
        codes, rims = E.sample(_medallion(), lu, ctx.p[:, 2] - 0.595, ctx.texel, u0=-16 * ctx.texel,
                               v0=-24 * ctx.texel)
        codes = np.where(front, codes, 0).astype(np.int16)
        return E.paint_over(ctx, s, codes, rims, seed + 1, flake=0.2, inks=A.INKS)
    return fn


# --------------------------------------------------------------------------
# frieze
# --------------------------------------------------------------------------

def frieze(W):
    p = Part("frieze")
    p.box((0.0, -0.02, 0.5), (W, 0.04, 1.0), "band")
    cull_back([p])
    for z in (-0.03, 1.03):
        p.extrude([(0.0, z - 0.035), (-0.05, z - 0.03), (-0.065, z), (-0.05, z + 0.03), (0.0, z + 0.035)],
                  -W / 2, W / 2, "rail", caps=False)
    return p


# --------------------------------------------------------------------------
# bracket cornice (dougong)
# --------------------------------------------------------------------------

def bracket_set(p, xc, mats=("blue", "green")):
    """One bracket set centred on x = xc, built on the wall plane (y = 0,
    projecting to -y), between the architrave top (z = -0.8) and the eave
    plate (z = -0.22)."""
    a, b = mats
    T = 0.16                                   # arm thickness
    yc = -0.15                                 # the line of the arms along the wall
    dou(p, xc, yc, -0.8, 0.32, 0.18, b, d=0.3)
    # tier 1: arm along the wall and the projecting arm
    f = front_prism(p, arm_outline(0.8, 0.14), T, a, bevel=0.008, y_back=yc + T / 2)
    p.move(f, Matrix.Translation((xc, 0.0, -0.62)))
    side_prism(p, [(0.0, -0.62), (0.0, -0.48), (0.5, -0.48), (0.5, -0.53), (0.45, -0.58), (0.38, -0.62)],
               T, a, x=xc, bevel=0.008)
    for (x, y) in ((xc - 0.31, yc), (xc + 0.31, yc), (xc, -0.43)):
        dou(p, x, y, -0.48, 0.17, 0.1, b)
    # tier 2: the long arm along the wall
    f = front_prism(p, arm_outline(0.96, 0.14), T, a, bevel=0.008, y_back=yc + T / 2)
    p.move(f, Matrix.Translation((xc, 0.0, -0.38)))
    # the sloping lever arm (ang): from the wall down to a beaked tip
    side_prism(p, [(0.0, -0.22), (0.0, -0.37), (0.56, -0.6), (0.72, -0.65), (0.68, -0.55), (0.44, -0.42),
                   (0.14, -0.22)], T * 1.05, b, x=xc, bevel=0.008)
    # the beam head (shuatou) under the eave plate: a cloud-cut end
    side_prism(p, [(0.0, -0.32), (0.0, -0.22), (0.62, -0.22), (0.65, -0.25), (0.6, -0.27), (0.65, -0.3),
                   (0.6, -0.32)], T * 0.9, a, x=xc, bevel=0.006)


def eaves(W):
    p = Part("eaves")
    # eave plate under the ceiling, architrave at the wall
    p.box((0.0, -0.21, -0.11), (W, 0.42, 0.22), "plate", bevel=0.01)
    p.box((0.0, -0.09, -0.925), (W, 0.18, 0.25), "plate", bevel=0.01)
    # panels between the sets (gongyan bi), a little behind the arms
    p.box((0.0, -0.015, -0.515), (W, 0.03, 0.57), "panel")
    for k in range(int(round(W))):
        xc = -W / 2 + k + 0.5
        bracket_set(p, xc, ("blue", "green") if k % 2 == 0 else ("green", "blue"))
    cull_back([p])
    cull_top([p], 0.0)
    return p


_PLATE = {}


def _plate_canvas(h_px):
    """1 m of a painted member, 64 px wide: hoop bands at the cell edges
    (blue / green / white lines), a whirl rosette (xuanzi) in the middle."""
    if h_px in _PLATE:
        return _PLATE[h_px]
    c = AP.blank(64, h_px, I["green"])
    for x0, x1, code in ((0, 2, I["blue"]), (2, 3, I["white"]), (3, 6, I["green"]), (6, 7, I["white"]),
                         (7, 10, I["blue"])):
        c[:, x0:x1] = code
        c[:, 64 - x1:64 - x0] = code
    c[:, 10:54] = I["blue"]
    cy = h_px / 2
    r = h_px * 0.42
    AP.ring(c, 32, cy, r * 0.82, r, I["white"])
    for k in range(6):
        a = k * math.pi / 3 + 0.3
        AP.ellipse(c, 32 + math.cos(a) * r * 0.55, cy + math.sin(a) * r * 0.55, r * 0.26, r * 0.18, I["lt_blue"], a + 0.9)
    c[AP.ellipse_mask(c.shape, 32, cy, r * 0.22, r * 0.22)] = I["gold"]
    for cx in (21, 43):
        AP.ring(c, cx, cy, r * 0.5, r * 0.62, I["white"])
        c[AP.ellipse_mask(c.shape, cx, cy, r * 0.3, r * 0.3)] = I["green"]
    c[0, :] = I["black"]
    c[-1, :] = I["black"]
    _PLATE[h_px] = c
    return c


def plate_paint(member_h, z_bottom, seed=1211, round_=False):
    """A painted member whose faces toward +-y carry the 1 m pattern (u
    measured along x so modules join), other faces plain green outlined;
    ``round_``: a lathe (the post head), the pattern runs round it."""
    def fn(ctx):
        s = A.painted(ctx, "pig_green", 3.8, seed, flake=0.25)
        face = np.abs(ctx.n[:, 1]) > 0.7 if not round_ else np.abs(ctx.n[:, 2]) < 0.5
        h_px = int(round(member_h / ctx.texel))
        u = np.where(ctx.n[:, 1] > 0, -ctx.p[:, 0], ctx.p[:, 0]) + 50.0
        if round_:
            u = ctx.uvm[:, 0] / (2.0 * math.pi * 0.255) * 2.0 + 50.0
        codes, rims = E.sample(_plate_canvas(h_px), u, ctx.p[:, 2], ctx.texel, v0=z_bottom, wrap_x=True)
        codes = np.where(face, codes, 0).astype(np.int16)
        return E.paint_over(ctx, s, codes, np.zeros_like(rims), seed + 1, flake=0.2, inks=A.INKS)
    return fn


def eaves_plate(ctx, seed=1215):
    """Both painted members of the cornice: which one by height."""
    z = ctx.p[:, 2]
    top = z > -0.5
    s = Surface(ctx.N)
    if top.any():
        s.merge(plate_paint(0.22, -0.22, seed)(ctx.subset(top)), top)
    if (~top).any():
        s.merge(plate_paint(0.25, -1.05, seed + 3)(ctx.subset(~top)), ~top)
    return s


def gongyan(ctx, seed=1221):
    s = A.plaster(ctx, seed, center=3.2, ramp="pig_red")
    return s


# --------------------------------------------------------------------------
# beam, corbel, posts
# --------------------------------------------------------------------------

def beam():
    p = Part("asia_beam_4m")
    p.box((0.0, 0.0, -0.21), (4.0, 0.32, 0.42), "beam", bevel=0.02)
    cull_top([p], 0.0)
    return p


def corbel():
    p = Part("asia_corbel")
    out = [(0.0, 0.0), (0.92, 0.0), (0.92, -0.06)]
    # scalloped cloud underside from the tip back to the wall
    for k in range(1, 9):
        t = k / 8
        y = 0.92 * (1 - t)
        z = -0.06 - 0.42 * t ** 1.3 + 0.035 * math.sin(t * math.pi * 6)
        out.append((y, z))
    out.append((0.0, -0.5))
    side_prism(p, ccw(out), 0.16, "queti", bevel=0.008)
    cull_back([p])
    return p


_QUETI = {}


def queti_paint(ctx, seed=1231):
    """The carved bracket: a red board with a gold-outlined cloud and a
    green scroll painted on its sides."""
    s = A.painted(ctx, "pig_red", 4.0, seed, line="pig_ochre", flake=0.25)
    side = np.abs(ctx.n[:, 0]) > 0.7
    yy = ctx.p[:, 1]                     # out of the wall (the turned model's front is +y)
    zz = ctx.p[:, 2]
    if "c" not in _QUETI:
        c = AP.blank(64, 36)
        m = AP.ruyi(c, 22, 14, 13, I["green"])
        AP.outline(c, m, I["gold"])
        m2 = AP.ruyi(c, 46, 10, 8, I["blue"], flip=True)
        AP.outline(c, m2, I["gold"])
        _QUETI["c"] = c
    codes, rims = E.sample(_QUETI["c"], yy, zz, ctx.texel, u0=0.0, v0=-0.56)
    codes = np.where(side, codes, 0).astype(np.int16)
    return E.paint_over(ctx, s, codes, rims, seed + 1, flake=0.15, inks=A.INKS)


def post_base():
    p = Part("asia_post_base")
    hx = 0.45
    path = [(-hx, -hx), (-hx, hx), (hx, hx), (hx, -hx)]
    plan_sweep(p, [(0.0, 0.0), (0.15, 0.0), (0.16, -0.02)], path, "granite")
    p.box((0.0, 0.0, 0.155), (0.86, 0.86, 0.01), "granite")
    # lotus drum: two rows of petals (ring_scale makes the scallops)
    p.lathe([(0.37, 0.16), (0.39, 0.2), (0.37, 0.26), (0.32, 0.3), (0.3, 0.33)], "lotus", segments=32,
            ring_scale=lambda i, j: 1.0 + (0.08 if (i % 2 == 0 and j in (1, 2)) else 0.0), cap_bottom=False)
    p.lathe([(0.3, 0.33), (0.29, 0.38), (0.27, 0.4), (0.0, 0.4)], "lotus", segments=32, cap_bottom=False)
    return p


def post_shaft():
    p = Part("asia_post_shaft")
    p.lathe([(0.25, 0.0), (0.25, 1.0)], "shaft", segments=20, cap_bottom=False, cap_top=False)
    return p


def post_capital():
    p = Part("asia_post_capital")
    # painted band at the top of the shaft
    p.lathe([(0.255, -1.2), (0.255, -0.75)], "band", segments=20, cap_bottom=False, cap_top=False, smooth=True)
    # the post-head tie beams entering both ways (stubs) under the block
    for rot in (0.0, 90.0):
        f = p.box((0.0, 0.0, -0.66), (1.3, 0.2, 0.18), "plate2", bevel=0.01)
        p.move(f, Matrix.Rotation(math.radians(rot), 4, 'Z'))
    dou(p, 0.0, 0.0, -0.57, 0.38, 0.2, "green")
    # crossed arms in two tiers, small blocks between them
    for rot, mat, other in ((0.0, "blue", "green"), (90.0, "green", "blue")):
        q = Matrix.Rotation(math.radians(rot), 4, 'Z')
        f = front_prism(p, arm_outline(0.9, 0.13), 0.14, mat, bevel=0.006, y_back=0.07)
        p.move(f, q @ Matrix.Translation((0.0, 0.0, -0.37)))
        f = front_prism(p, arm_outline(1.2, 0.13), 0.14, mat, bevel=0.006, y_back=0.07)
        p.move(f, q @ Matrix.Translation((0.0, 0.0, -0.15)))
        for sgn in (-1, 1):
            v = q @ Vector((sgn * 0.36, 0.0, 0.0))
            dou(p, v.x, v.y, -0.24, 0.15, 0.09, other)
    return p


def build():
    out = []
    lac = A.lacquer_red
    gilt = lambda c: A.gilt(c, 1241, worn=0.6, under="lacquer_black")
    for W, tag in LENGTHS:
        show = tag == "4m"
        out.append(kit(f"asia_dado_{tag}", [dado(W)], {"frame": lac, "panel": dado_panel(W), "fitting": gilt,
                                                        "base": A.lacquer_black},
                       wall=True, preview=show, preview_elevation=8.0))
        out.append(kit(f"asia_frieze_{tag}", [frieze(W)], {"rail": lac}, wall=True, ground=None,
                       kinds={"band": "tile:asia_band"}, preview=show))
        if W >= 1.0:
            out.append(kit(f"asia_eaves_{tag}", [eaves(W)],
                           {"plate": eaves_plate, "panel": gongyan,
                            "blue": lambda c: A.painted(c, "pig_blue", 3.8, 1251),
                            "green": lambda c: A.painted(c, "pig_green", 3.8, 1253)},
                           ppm=96, wall=True, ground=None, ceiling=0.0, ao_dist=0.35, preview=show,
                           preview_elevation=-20.0))
    out.append(kit("asia_beam_4m", [beam()], {"beam": plate_paint(0.42, -0.42, 1261)}, built_final=True,
                   ground=None, ceiling=0.0, ao_dist=0.3, preview_elevation=-15.0))
    out.append(kit("asia_corbel", [corbel()], {"queti": queti_paint, "dou": lambda c: A.painted(c, "pig_green", 3.8, 1271)},
                   wall=True, ground=None, ceiling=0.0, ao_dist=0.25, preview_elevation=-10.0))
    out.append(kit("asia_post_base", [post_base()], {"granite": lambda c: A.garden_stone(c, 1281, moss=0.0, lichen=0.0),
                                                     "lotus": lambda c: A.garden_stone(c, 1283, moss=0.0, lichen=0.0,
                                                                                       center=5.6)},
                   ppm=96, ao_dist=0.25))
    out.append(kit("asia_post_shaft", [post_shaft()], {}, kinds={"shaft": "tile:asia_lacquer"}, ground=None,
                   preview=False))
    out.append(kit("asia_post_capital", [post_capital()],
                   {"band": plate_paint(0.45, -1.2, 1291, round_=True), "plate2": plate_paint(0.18, -0.75, 1293),
                    "blue": lambda c: A.painted(c, "pig_blue", 3.8, 1295),
                    "green": lambda c: A.painted(c, "pig_green", 3.8, 1297)},
                   ground=None, ceiling=0.0, ao_dist=0.3, preview_elevation=-20.0))
    return out
