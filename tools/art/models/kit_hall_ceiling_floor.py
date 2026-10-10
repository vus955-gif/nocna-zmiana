"""Lobby kit, main hall: ceiling, skylights and the marble floor inlays.

  hall_coffer_2m       2 x 2 m plaster coffer with gilded bead and rosette,
                       0.32 m deep. Origin = module centre on the ceiling
                       plane; hangs down. Each module carries half a beam, so
                       modules tile edge to edge (stretch X/Z by up to
                       +-25 % to fill a ceiling box; also under the balcony).
  skylight_bay_3m      3 x 3 m bay of an iron-and-glass lantern roof: curb
                       beams, rafters every 0.5 m, ridge, an arched iron rib
                       across the middle, pitched glass (separate object
                       skylight_bay_3m_glass, no shadow). Origin = bay centre
                       at the curb's underside (the kit "skylight" piece's
                       base); ridge along Z (Godot), rises 0.95 m.
  skylight_gable_3m    glazed triangular end of a lantern run: origin at
                       the run's end on the centre line at the curb's
                       underside, glass in the plane z = 0 facing -Z (the
                       kit front): turn it so -Z points out of the lantern.
  floor_border_*       1 m wide inlaid border along the walls (4/2/1/0.5 m):
                       verde bands, white fillets, a white Greek key on
                       verde every 0.5 m. 4 mm proud of the floor. Origin =
                       on the floor at the wall line, module centre; the
                       strip runs along X and extends 1 m toward -Z.
  floor_border_corner  1 x 1 m corner square with an eight-point star;
                       origin at the room corner, the square covers
                       x 0..1, z -1..0 (turn it into each corner).
  floor_medallion      6 m compass rose of cream, grey and red marble with
                       brass rings, 4 mm proud; origin = centre.
"""
import math

import numpy as np
from mathutils import Matrix

from artlib import arch_materials as A
from artlib import materials as M
from artlib.archkit import LENGTHS, kit
from artlib.geo import Part
from artlib.painter import Surface

FLOOR_T = 0.004


def coffer():
    p = Part("hall_coffer")
    lo, hi = -0.8, 0.8
    path = [(lo, lo), (lo, hi), (hi, hi), (hi, lo)]
    p.sweep([(0.02, 0.0), (0.06, 0.0), (0.06, 0.015), (0.12, 0.015)], path, "plaster", closed=True)
    p.sweep([(0.12, 0.015), (0.145, 0.03), (0.145, 0.045), (0.12, 0.05)], path, "gold", closed=True)
    p.sweep([(0.12, 0.05), (0.2, 0.05), (0.2, 0.065), (0.28, 0.075), (0.32, 0.09), (0.32, 0.2)], path, "plaster",
            closed=True)
    f = p.poly([(lo, -0.02, lo), (hi, -0.02, lo), (hi, -0.02, hi), (lo, -0.02, hi)], "field")[0]
    f.normal_update()
    if f.normal.y > 0:
        f.normal_flip()
    # rosette: a stepped boss; its petals are painted (the coffer repeats
    # hundreds of times, so it stays light: ~120 triangles)
    ros = p.lathe([(0.0, 0.0), (0.3, 0.0), (0.3, 0.02), (0.22, 0.04), (0.15, 0.07), (0.08, 0.1), (0.0, 0.11)],
                  "rosette", segments=12, cap_bottom=False)
    p.move(ros, Matrix.Translation((0.0, -0.02, 0.0)) @ Matrix.Rotation(math.radians(90), 4, 'X'))
    # wall frame -> ceiling: the viewer side (-Y) turns to face down
    p.move(list(p.bm.faces), Matrix.Rotation(math.radians(90), 4, 'X'))
    return p


def _rosette(ctx):
    """Gold boss with eight painted petals (by angle round the axis)."""
    s = M.gold(ctx)
    a = np.arctan2(ctx.p[:, 0], ctx.p[:, 1])
    r = np.hypot(ctx.p[:, 0], ctx.p[:, 1])
    petal = np.abs(np.cos(a * 4.0)) ** 2
    s.shade += petal * 1.5 - (r < 0.06) * 1.0 - np.clip(0.3 - petal, 0, 1) * 2.0
    return s


def _field(ctx):
    s = M.plaster(ctx)
    s.shade += 0.4
    return s


PITCH = math.atan2(0.95, 1.45)


def _sloped_bar(p, y, side, mat, width=0.05, depth=0.08):
    L = math.hypot(1.45, 0.95)
    b = p.box((0.0, 0.0, 0.0), (L, width, depth), mat, bevel=0.008)
    p.move(b, Matrix.Translation((side * 0.725, y, 0.3 + 0.475)) @ Matrix.Rotation(side * PITCH, 4, 'Y'))
    return b


def skylight_bay():
    iron = Part("skylight_bay_3m")
    glass = Part("skylight_bay_3m_glass")
    for sx in (-1, 1):
        iron.box((sx * 1.47, 0.0, 0.15), (0.12, 3.0, 0.3), "iron", bevel=0.012)
        iron.box((sx * 1.47, 0.0, 0.31), (0.18, 3.0, 0.04), "iron", bevel=0.008)
    iron.box((0.0, 0.0, 1.25), (0.1, 3.0, 0.1), "iron", bevel=0.012)
    for k in range(6):
        y = -1.25 + 0.5 * k
        heavy = k in (0, 3)
        for sx in (-1, 1):
            _sloped_bar(iron, y, sx, "iron", width=0.07 if heavy else 0.035, depth=0.1 if heavy else 0.06)
    # purlins halfway up each slope
    for sx in (-1, 1):
        pur = iron.box((0.0, 0.0, 0.0), (0.05, 3.0, 0.07), "iron", bevel=0.008)
        iron.move(pur, Matrix.Translation((sx * 0.725, 0.0, 0.8)) @ Matrix.Rotation(sx * PITCH, 4, 'Y'))
    # arched rib across the middle, with a ring ornament at the crown
    pts = [(1.45 * math.cos(a), 0.0, 0.3 + 0.62 * math.sin(a)) for a in np.linspace(0.0, math.pi, 17)]
    iron.tube(pts, 0.03, "iron", sides=6)
    ring = [(0.12 * math.cos(a), 0.0, 0.62 + 0.12 * math.sin(a)) for a in np.linspace(0.0, math.tau, 13)]
    iron.tube(ring, 0.018, "iron", sides=5, caps=False)
    for x in (-0.7, 0.7):
        iron.box((x, 0.0, 0.8), (0.025, 0.025, 0.36), "iron")
    # glass: two sloped panes just above the bars
    for sx in (-1, 1):
        x0, z0 = sx * 1.47, 0.35
        x1, z1 = 0.0, 1.3
        pts = [(x0, -1.5, z0 + 0.06), (x0, 1.5, z0 + 0.06), (x1, 1.5, z1 + 0.06), (x1, -1.5, z1 + 0.06)]
        # the pane faces down: it is seen from the hall below
        f = glass.poly(pts, "glass")[0]
        f.normal_update()
        if f.normal.z > 0:
            f.normal_flip()
    return [iron, glass]


def skylight_gable():
    iron = Part("skylight_gable_3m")
    glass = Part("skylight_gable_3m_glass")
    # in the plane y = 0 (Blender), the sky side is +Y
    tri = [(-1.47, 0.35), (1.47, 0.35), (0.0, 1.3)]
    for (xa, za), (xb, zb) in ((tri[0], tri[2]), (tri[1], tri[2])):
        L = math.hypot(xb - xa, zb - za)
        b = iron.box((0.0, 0.0, 0.0), (L, 0.07, 0.07), "iron", bevel=0.008)
        a = math.atan2(zb - za, xb - xa)
        iron.move(b, Matrix.Translation(((xa + xb) / 2, -0.04, (za + zb) / 2)) @ Matrix.Rotation(-a, 4, 'Y'))
    iron.box((0.0, -0.04, 0.33), (3.0, 0.08, 0.06), "iron", bevel=0.008)
    for x in (-0.95, -0.48, 0.0, 0.48, 0.95):
        top = 1.3 - abs(x) * (0.95 / 1.47)
        iron.box((x, -0.03, (0.35 + top) / 2), (0.035, 0.05, top - 0.35), "iron", bevel=0.006)
    # seen from inside the lantern
    f = glass.poly([(p[0], 0.0, p[1]) for p in tri], "glass")[0]
    f.normal_update()
    if f.normal.y > 0:
        f.normal_flip()
    return [iron, glass]


# --- floor inlays -----------------------------------------------------------

# one period (0.5 m = 8 cells of 1/16 m) of a Greek key rising from a baseline
KEY = [((0, 0), (8, 0)), ((1, 0), (1, 6)), ((1, 6), (7, 6)), ((7, 6), (7, 2)), ((7, 2), (3, 2)),
       ((3, 2), (3, 4)), ((3, 4), (5, 4))]


def _key_mask(x, y, cell=1.0 / 16.0):
    cx = np.floor(np.mod(x, 0.5) / cell + 1e-6).astype(np.int64)
    cy = np.floor(y / cell + 1e-6).astype(np.int64)
    m = np.zeros(len(x), dtype=bool)
    for (x0, y0), (x1, y1) in KEY:
        lx0, lx1 = min(x0, x1), max(x0, x1)
        ly0, ly1 = min(y0, y1), max(y0, y1)
        m |= (cx >= lx0) & (cx <= lx1) & (cy >= ly0) & (cy <= ly1)
    return m & (cy >= 0) & (cy <= 7)


def _border(ctx):
    """Top face (x along the wall, y = distance from the wall, metres)."""
    x = ctx.p[:, 0]
    y = ctx.p[:, 1]
    tx = ctx.texel
    white = ((y > 0.1) & (y < 0.13)) | ((y > 0.87) & (y < 0.9))
    key = _key_mask(x + 0.25, y - 0.23)
    s = M.marble_dark(ctx)
    wm = white | key
    sw = M.marble_white(ctx.subset(wm))
    s.merge(sw, wm)
    s.shade[wm] = np.clip(s.shade[wm], 6.0, 9.0)
    s.rough = np.where(wm, 0.1, 0.08) + ctx.rand(3) * 0.03
    edge = ((np.abs(y - 0.1) < tx) | (np.abs(y - 0.13) < tx) | (np.abs(y - 0.87) < tx) | (np.abs(y - 0.9) < tx))
    s.shade[edge] -= 1.0
    return s


def _corner(ctx):
    x = ctx.p[:, 0] - 0.5
    y = ctx.p[:, 1] - 0.5
    r = np.hypot(x, y)
    a = np.arctan2(y, x)
    star = r < 0.36 * (0.45 + 0.55 * np.abs(np.cos(4 * a)) ** 3)
    ring = (r > 0.4) & (r < 0.43)
    red = r < 0.08
    s = M.marble_dark(ctx)
    wm = (star | ring) & ~red
    s.merge(M.marble_white(ctx.subset(wm)), wm)
    s.merge(M.marble_red(ctx.subset(red)), red)
    s.rough = np.full(ctx.N, 0.09)
    return s


def _medallion(ctx):
    x = ctx.p[:, 0]
    y = ctx.p[:, 1]
    r = np.hypot(x, y)
    a = np.mod(np.arctan2(y, x), math.tau)
    n = ctx.N
    kind = np.zeros(n, np.int64)          # 0 cream, 1 grey, 2 red, 3 brass, 4 verde
    kind[(r > 2.7)] = 4
    kind[(r > 2.62) & (r <= 2.7)] = 3
    kind[(r > 2.84) & (r <= 2.9)] = 3
    # sixteen-point star: long rays on the cardinal points, then 45, then 22.5
    seg = math.tau / 16
    k = np.floor(a / seg + 0.5).astype(np.int64) % 16
    da = np.abs(np.mod(a - k * seg + math.pi, math.tau) - math.pi)
    length = np.where(k % 4 == 0, 2.55, np.where(k % 2 == 0, 1.9, 1.35))
    ray = (r < length) & (da < (1.0 - r / length) * seg * 0.62)
    lit_half = np.sin(a - k * seg) > 0
    in_ring = r <= 2.62
    kind[in_ring & ~ray] = 1
    kind[in_ring & ray & lit_half] = 0
    kind[in_ring & ray & ~lit_half] = np.where(k[in_ring & ray & ~lit_half] % 4 == 0, 2, 4)
    kind[(r < 0.42) & (r > 0.36)] = 3
    kind[r <= 0.36] = 2
    s = Surface(n)
    for kk, fn in ((0, lambda c: A._marble_core(c, A.P["marble_cream"], A.P["marble_cream_vein"], 6.2, False, 5,
                                                 polish=0.07, vein_scale=1.5)),
                   (1, lambda c: A._marble_core(c, A.P["marble_grey"], A.P["marble_grey_vein"], 3.8, True, 7,
                                                 polish=0.06, vein_scale=2.0)),
                   (2, M.marble_red), (3, M.brass), (4, M.marble_dark)):
        m = kind == kk
        if m.any():
            s.merge(fn(ctx.subset(m)), m)
    tx = ctx.texel
    grout = np.zeros(n, dtype=bool)
    for rr in (0.36, 0.42, 2.62, 2.7, 2.84, 2.9):
        grout |= np.abs(r - rr) < tx * 0.5
    s.use_ramp(A.P["grout"], mask=grout, shade=np.full(n, 1.5))
    return s


def strip(W, depth=1.0):
    p = Part("floor_border")
    p.box((0.0, depth / 2, FLOOR_T / 2), (W, depth, FLOOR_T), "border", bevel=0.0015)
    return p


def corner():
    p = Part("floor_border_corner")
    p.box((0.5, 0.5, FLOOR_T / 2), (1.0, 1.0, FLOOR_T), "corner", bevel=0.0015)
    return p


def medallion():
    p = Part("floor_medallion")
    R = 2.9
    n = 64
    top = [(R * math.cos(math.tau * i / n), R * math.sin(math.tau * i / n), FLOOR_T) for i in range(n)]
    f = p.poly(top, "medallion")[0]
    f.normal_update()
    if f.normal.z < 0:
        f.normal_flip()
    return p


def build():
    out = [kit("hall_coffer_2m", [coffer()], {"plaster": M.plaster, "gold": M.gold, "field": _field,
                                              "rosette": _rosette},
               built_final=True, ground=None, ceiling=0.0, ao_dist=0.5, preview_elevation=-40.0),
           kit("skylight_bay_3m", skylight_bay(), {"iron": M.iron}, kinds={"glass": "glass"}, built_final=True,
               ground=None, ppm=64, ao_dist=0.3),
           kit("skylight_gable_3m", skylight_gable(), {"iron": M.iron}, kinds={"glass": "glass"}, built_final=True,
               ground=None, ppm=64, preview=False)]
    for W, tag in LENGTHS:
        out.append(kit(f"floor_border_{tag}", [strip(W)], {"border": _border}, built_final=True, ground=None,
                       ao_rays=0, preview=tag == "4m", preview_elevation=60.0))
    out.append(kit("floor_border_corner", [corner()], {"corner": _corner}, built_final=True, ground=None, ao_rays=0,
                   preview=False))
    out.append(kit("floor_medallion", [medallion()], {"medallion": _medallion}, built_final=True, ground=None,
                   ao_rays=0, preview_elevation=70.0))
    return out
