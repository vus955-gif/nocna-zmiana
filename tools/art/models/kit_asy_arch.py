"""Assyrian wing: the palace architecture kit (kit convention: origin = the
centre of the base, front = Godot -Z; wall runs on the wall plane z = 0,
x = -W/2 .. W/2).

  asy_frieze_4m/2m/1m  painted plaster frieze over the orthostats (Nimrud
                       wall paintings): red and blue palmettes and lotus buds
                       linked by arcs, a zigzag, a chequer, black rules; 0.62 m,
                       datum = its BOTTOM (lay it on the slab tops at 3.0 m);
                       the pattern repeats every 0.5 m, so runs join.
  asy_beam_4m          cedar ceiling beam 0.36 x 0.44, bronze bands with
                       rosette bosses; origin = top centre on the ceiling plane
                       (hangs down), beams across the room every 4 m.
  asy_corbel           stepped gypsum corbel with a cedar bolster under a beam
                       end (ArtKit "corbel"): origin on the wall at its top.
  asy_parapet_2m       stepped merlons (two per module) on a gypsum coping,
                       sun-dried brick with lime wash; both faces finished;
                       origin = the centre of its base on the wall top.
  asy_portal_4m        frame of a 4 x 4.5 m opening (scale Y for 5-6 m doors):
                       carved alabaster jambs (guilloche and rosettes), a cedar
                       lintel with bronze caps, a band of glazed brick (blue,
                       yellow and white rosettes), a stone cornice; origin = the
                       opening's floor centre on the wall face (one per face).
  asy_doorframe_2x2_6  cedar architrave with bronze rosettes for 2 x 2.6 doors.
  asy_threshold_4m     carved gypsum threshold "carpet" (rosette grid, border of
                       lotus buds and flowers), 4 x 1.2 m, 15 mm proud of the floor;
                       scale Z to the passage depth.
  asy_plinth           display plinth 1.0 x 1.0 x 1.0, alabaster with a band of
                       carved rosettes; asy_plinth_low 2.4 x 0.4 x 1.2.
"""
import math

import numpy as np
from mathutils import Vector

from artlib import asy, asy_mesh as AM, asy_relief as rl
from artlib import materials as M
from artlib.archkit import LENGTHS, kit, moulding
from artlib.asy import P
from artlib.geo import Part
from artlib.materials import Surface, _dither, smoothstep

# --------------------------------------------------------------------------
# painted plaster: the frieze
# --------------------------------------------------------------------------

FRIEZE_H = 0.62


def _paint_frieze(ctx, seed=811):
    """Painted plaster band; u along the run (period 0.5 m), v up from the
    band's bottom. Colour areas are decided per texel, then each paint is a
    ramp with flaking down to the lime-washed plaster."""
    u, v = AM.UV(ctx)
    s = Surface(ctx.N)
    ground = 5.4 + ctx.fbm(3.0, 3, seed) * 0.7 + _dither(ctx, 0.6, seed + 1)
    s.use_ramp(P["asy_alabaster_warm"], shade=ground)
    fu = np.mod(u, 0.5)
    tx = ctx.texel
    paint = np.zeros(ctx.N, np.int64)        # 0 ground, 1 black, 2 red, 3 blue, 4 white
    paint[(v >= 0.04) & (v < 0.07)] = 2
    # zigzag band
    zz = (v >= 0.08) & (v < 0.17)
    tri = np.abs(np.mod(u * 8.0, 2.0) - 1.0) * 0.08 + 0.085
    paint[zz & (v < tri)] = 3
    paint[zz & (np.abs(v - tri) < tx * 0.8)] = 1
    paint[(np.abs(v - 0.075) < tx * 0.7) | (np.abs(v - 0.175) < tx * 0.7)] = 1
    # main register: palmettes at 0.0 and lotus buds at 0.25, linked by arcs
    main = (v >= 0.18) & (v < 0.47)
    cx = np.where(fu < 0.25, 0.125, 0.375)
    dx = fu - cx
    dv = v - 0.24
    is_palm = fu < 0.25
    r = np.hypot(dx, dv)
    ang = np.arctan2(dv, dx)
    fan = is_palm & main & (dv > 0) & (r < 0.17) & (r > 0.035)
    petal = np.floor((ang - 0.15) / ((math.pi - 0.3) / 7.0))
    fan &= (ang > 0.15) & (ang < math.pi - 0.15)
    paint[fan & (np.mod(petal, 2) == 0)] = 3
    paint[fan & (np.mod(petal, 2) == 1)] = 2
    gap = np.abs(np.mod((ang - 0.15) / ((math.pi - 0.3) / 7.0), 1.0)) < 0.12
    paint[fan & gap] = 4
    paint[is_palm & main & (r < 0.04) & (dv > -0.03)] = 2
    paint[is_palm & main & (np.abs(r - 0.17) < tx * 0.8) & (dv > 0)] = 1
    bud = ~is_palm & main & (np.abs(dx) < 0.05 * np.clip(1.0 - (dv - 0.0) / 0.2, 0.0, 1.0) + 0.012) & (dv > -0.02) & (dv < 0.2)
    paint[bud] = 2
    paint[bud & (np.abs(dx) < 0.012)] = 3
    arc = main & (np.abs(np.hypot(fu - np.where(fu < 0.25, 0.25, 0.25), v - 0.2) - 0.125) < tx * 1.0) & (v < 0.24)
    paint[arc] = 1
    paint[main & (np.abs(v - 0.2) < tx * 0.7)] = 1
    # chequer and rules
    chk = (v >= 0.49) & (v < 0.55)
    paint[chk & (np.mod(np.floor(u / 0.0625), 2) == 0)] = 2
    paint[chk & (np.mod(np.floor(u / 0.0625), 2) == 1)] = 4
    paint[(np.abs(v - 0.48) < tx * 0.8) | (np.abs(v - 0.555) < tx * 0.7)] = 1
    paint[(v >= 0.555) & (v < 0.58)] = 3
    flake = ctx.fbm(np.array([14.0, 14.0, 14.0]), 3, seed + 2) + ctx.fbm(2.0, 2, seed + 3) * 0.5
    keep = flake > -0.45
    for pid, ramp, c in ((1, "asy_paint_black", 2.0), (2, "asy_ochre_red", 3.8), (3, "asy_lapis", 4.6),
                         (4, "asy_glaze_white", 3.6)):
        m = (paint == pid) & keep
        s.use_ramp(P[ramp], mask=m, shade=np.full(ctx.N, c) + ctx.fbm(9.0, 2, seed + 4 + pid) * 0.7
                   + _dither(ctx, 0.6, seed + 9 + pid))
    s.shade -= (1.0 - ctx.ao) * 2.5 + ctx.cavity(3.0) * 1.5
    crack = (np.abs(ctx.fbm(2.0, 3, seed + 20)) < 0.012).astype(np.float64)
    s.shade -= crack * 1.5
    s.height = 0.0 - crack * 0.001 + ((paint > 0) & keep) * 0.0003 + ctx.fbm(12.0, 2, seed + 21) * 0.0004
    s.rough = 0.85 + ctx.rand(seed + 22) * 0.06
    return s


def frieze(W):
    p = Part("asy_frieze")
    # pre-turn frame: viewer at -Y; the painted face 0.02 m off the wall
    from artlib.archkit import quad_front
    quad_front(p, -W / 2, W / 2, 0.035, FRIEZE_H - 0.035, "paint", y=-0.02)
    moulding(p, [(0.0, 0.0), (-0.045, 0.0), (-0.045, 0.035), (-0.02, 0.035)], W, "ledge")
    moulding(p, [(-0.02, FRIEZE_H - 0.035), (-0.045, FRIEZE_H - 0.035), (-0.045, FRIEZE_H), (0.0, FRIEZE_H)], W,
             "ledge")
    return p


# --------------------------------------------------------------------------
# beam, parapet
# --------------------------------------------------------------------------

def beam():
    p = Part("asy_beam_4m")
    p.box((0, 0, -0.22), (4.0, 0.36, 0.44), "cedar", bevel=0.03)
    for x in (-1.34, 0.0, 1.34):
        p.box((x, 0, -0.22), (0.1, 0.375, 0.455), "bronze", bevel=0.008)
        for sy in (-1, 1):
            f = p.lathe([(0.0, 0.0), (0.045, 0.0), (0.04, 0.012), (0.018, 0.026), (0.0, 0.03)], "bronze", segments=8)
            p.move(f, AM_MAT(x, sy * 0.188, -0.22, sy))
    return p


def AM_MAT(x, y, z, sy):
    """Places a boss made along +Z at (x, y, z), its axis pointing to sy * Y."""
    from mathutils import Matrix
    return Matrix.Translation((x, y, z)) @ Matrix.Rotation(math.radians(-90 * sy), 4, 'X')


def corbel():
    """Stepped gypsum corbel with a cedar bolster under a beam end (wall
    piece, pre-turn: the wall at y = 0, origin on the wall at the corbel's
    TOP = the beam's underside)."""
    p = Part("asy_corbel")
    for d, z0, z1, w in ((0.2, -0.62, -0.44, 0.38), (0.32, -0.44, -0.27, 0.44), (0.44, -0.27, -0.12, 0.5)):
        p.box((0, -d / 2, (z0 + z1) / 2), (w, d, z1 - z0), "stone", bevel=0.02)
    p.box((0, -0.3, -0.06), (0.4, 0.6, 0.12), "cedar", bevel=0.02)
    for x in (-0.14, 0.14):
        f = p.lathe([(0.0, 0.0), (0.035, 0.0), (0.03, 0.01), (0.014, 0.02), (0.0, 0.024)], "bronze", segments=8)
        p.move(f, AM_MAT(x, -0.601, -0.06, -1))
    return p


def parapet(W=2.0):
    p = Part("asy_parapet_2m")
    D = 0.5
    p.box((0, 0, 0.09), (W, D + 0.08, 0.18), "stone", bevel=0.015)
    n = int(round(W))
    for k in range(n):
        x = -W / 2 + k + 0.5
        z = 0.18
        for w, h in ((0.62, 0.26), (0.46, 0.24), (0.3, 0.2)):
            p.box((x, 0, z + h / 2), (w, D, h), "brick", bevel=0.01)
            z += h
        p.box((x, 0, z + 0.025), (0.34, D + 0.03, 0.05), "stone", bevel=0.01)
    return p


def _brickwash(ctx):
    s = asy.tile_mudbrick(ctx)
    return s


# --------------------------------------------------------------------------
# glazed brick, carved jambs: the portal
# --------------------------------------------------------------------------

def _glazed_band(ctx, seed=831):
    """Glazed bricks (0.33 x 0.11 m courses): lapis ground, rosettes of
    yellow petals with white centres every 0.5 m, a white-and-yellow
    chevron border; glossy, crazed, edges worn to the clay."""
    u, v = AM.UV(ctx)
    tx = ctx.texel
    s = Surface(ctx.N)
    v0 = v - 4.72
    row = np.floor(v0 / 0.11)
    fv = v0 - row * 0.11
    off = np.mod(row, 2) * 0.165
    fu = np.mod(u + off, 0.33)
    joint = (fv < tx) | (fu < tx)
    base = 4.4 + ctx.fbm(5.0, 2, seed) * 0.5 + _dither(ctx, 0.5, seed + 1)
    s.use_ramp(P["asy_lapis"], shade=base)
    # rosettes in the middle course band
    cu = np.mod(u, 0.5) - 0.25
    cv = v0 - 0.33
    r = np.hypot(cu, cv)
    ang = np.arctan2(cv, cu)
    pet = (r < 0.13) & (r > 0.035) & (np.abs(np.mod(ang * 8 / math.tau, 1.0) - 0.5) < 0.3 + 0.0 * r)
    s.use_ramp(P["asy_glaze_yellow"], mask=pet, shade=np.full(ctx.N, 4.6) - (r / 0.13) * 1.2 + _dither(ctx, 0.4, 3))
    ctr = r < 0.035
    s.use_ramp(P["asy_glaze_white"], mask=ctr, shade=np.full(ctx.N, 4.2))
    ring = np.abs(r - 0.145) < tx * 1.0
    s.use_ramp(P["asy_glaze_white"], mask=ring, shade=np.full(ctx.N, 3.5))
    # chevron borders top and bottom
    for b0 in (0.0, 0.55):
        band = (v0 >= b0) & (v0 < b0 + 0.11)
        zz = np.abs(np.mod(u * 9.0, 2.0) - 1.0) * 0.09 + b0 + 0.01
        s.use_ramp(P["asy_glaze_white"], mask=band & (v0 < zz), shade=np.full(ctx.N, 4.0) + _dither(ctx, 0.4, 5))
        s.use_ramp(P["asy_glaze_yellow"], mask=band & (np.abs(v0 - zz) < tx * 1.2), shade=np.full(ctx.N, 3.5))
    wear = (ctx.fbm(16.0, 2, seed + 6) > 0.45) | ((fv < 2 * tx) | (fu < 2 * tx)) & (ctx.fbm(20.0, 2, seed + 7) > 0.1)
    s.use_ramp(P["asy_brick_baked"], mask=wear & ~joint, shade=np.full(ctx.N, 5.0) + _dither(ctx, 0.6, 8))
    s.use_ramp(P["asy_bitumen"], mask=joint, shade=np.full(ctx.N, 3.0))
    s.shade -= (1.0 - ctx.ao) * 2.0
    craze = (np.abs(ctx.fbm(22.0, 2, seed + 9)) < 0.02) & ~wear
    s.shade -= craze * 0.8
    s.rough = np.where(wear | joint, 0.85, 0.2 + craze * 0.25)
    s.height = joint * -0.003 - wear * 0.0006
    return s


def _jamb_relief(H=4.5, seed=841):
    """The carved face of a portal jamb (0.7 m wide): a guilloche down the
    inner edge, a column of rosettes, a palmette at the top."""
    R = rl.Relief(0.7, H, 64, u0=-0.35, v0=0.0, seed=seed)
    R.base[:] = 0.02
    R.base_cut(np.abs(R.X - 0.27), R.px * 1.2, 0.004)
    R.base_cut(np.abs(R.X + 0.33), R.px * 1.2, 0.004)
    # guilloche: two interlaced waves down the strip x 0.27..0.35
    for ph in (0.0, math.pi):
        pts = [(0.31 + 0.028 * math.sin(t * 0.25 * math.tau / 0.25 + ph), t) for t in np.arange(0.3, H - 0.1, 0.02)]
        d = R.polyline(pts)
        R.base = np.where(d < R.px * 1.3, R.base + 0.004, R.base)
    for k in range(int((H - 0.6) / 0.5)):
        c = (-0.04, 0.65 + k * 0.5)
        d = R.circle(c, 0.17)
        R.base = np.where(d < 0, R.base + 0.006, R.base)
        R.base_cut(np.abs(np.hypot(R.X - c[0], R.Y - c[1]) - 0.17), R.px * 1.2, 0.004)
        for j in range(12):
            a = math.tau * j / 12
            R.base_cut(R.seg((c[0] + math.cos(a) * 0.05, c[1] + math.sin(a) * 0.05),
                             (c[0] + math.cos(a) * 0.155, c[1] + math.sin(a) * 0.155)), R.px * 1.0, 0.003)
        R.base = np.where(R.circle(c, 0.045) < 0, R.base + 0.004, R.base)
    return R


def portal():
    p = Part("asy_portal_4m")
    hw, H = 2.0, 4.5
    for sx in (-1, 1):
        cx = sx * (hw + 0.35)
        # carved jamb slab, pre-turn frame: decoration toward -Y
        p.box((cx, -0.05, H / 2), (0.7, 0.1, H), "jamb_side", bevel=0.012)
        p.box((cx, -0.07, 0.15), (0.78, 0.14, 0.3), "stone", bevel=0.015)
        # the carved front face over the slab
        pts = [(cx - 0.35, -0.1005, 0.3), (cx + 0.35, -0.1005, 0.3), (cx + 0.35, -0.1005, H), (cx - 0.35, -0.1005, H)]
        f = p.poly(pts, "jamb_r" if sx > 0 else "jamb_l")[0]
        f.normal_update()
        if f.normal.y > 0:
            f.normal_flip()
    # cedar lintel with bronze caps, the glazed band, a cornice
    p.box((0, -0.09, H + 0.11), (2 * hw + 1.5, 0.18, 0.22), "cedar", bevel=0.02)
    for sx in (-1, 1):
        p.box((sx * (hw + 0.74), -0.09, H + 0.11), (0.06, 0.19, 0.23), "bronze", bevel=0.006)
    p.box((0, -0.05, H + 0.22 + 0.33), (2 * hw + 1.4, 0.1, 0.66), "glaze_side", bevel=0.01)
    pts = [(-hw - 0.7, -0.1005, H + 0.22), (hw + 0.7, -0.1005, H + 0.22), (hw + 0.7, -0.1005, H + 0.88),
           (-hw - 0.7, -0.1005, H + 0.88)]
    f = p.poly(pts, "glaze")[0]
    f.normal_update()
    if f.normal.y > 0:
        f.normal_flip()
    moulding(p, [(0.0, H + 0.88), (-0.14, H + 0.88), (-0.17, H + 0.92), (-0.17, H + 1.0), (-0.12, H + 1.03),
                 (0.0, H + 1.03)], 2 * hw + 1.6, "stone")
    return p


def doorframe_small():
    p = Part("asy_doorframe_2x2_6")
    hw, H = 1.0, 2.6
    path = [(-hw, 0.0), (-hw, H), (hw, H), (hw, 0.0)]
    p.sweep([(0.0, 0.0), (0.03, 0.0), (0.035, 0.012), (0.035, 0.1), (0.05, 0.12), (0.05, 0.15), (0.0, 0.16)], path,
            "cedar")
    for sx in (-1, 1):
        f = p.lathe([(0.0, 0.0), (0.04, 0.0), (0.036, 0.01), (0.016, 0.02), (0.0, 0.024)], "bronze", segments=8)
        p.move(f, AM_MAT(sx * (hw + 0.075), -0.05, H + 0.075, -1))
    return p


# --------------------------------------------------------------------------
# threshold, plinths
# --------------------------------------------------------------------------

def _threshold_relief(W=4.0, D=1.2, seed=851):
    R = rl.Relief(W, D, 96, u0=-W / 2, v0=-D / 2, seed=seed)
    R.base[:] = 0.0
    # border frame and lotus border
    inner = R.box((0, 0), W / 2 - 0.14, D / 2 - 0.14)
    R.base_cut(np.abs(R.box((0, 0), W / 2 - 0.03, D / 2 - 0.03)), R.px * 1.2, 0.003)
    R.base_cut(np.abs(inner), R.px * 1.2, 0.003)
    band = (inner > 0) & (R.box((0, 0), W / 2 - 0.03, D / 2 - 0.03) < 0)
    # buds and flowers alternating every 0.11 m along the long edges
    for k in range(int((W - 0.3) / 0.11)):
        x = -W / 2 + 0.2 + k * 0.11
        for sy in (-1, 1):
            y = sy * (D / 2 - 0.085)
            if k % 2:
                d = R.ellipse((x, y), 0.03, 0.04)
            else:
                d = R.circle((x, y), 0.032)
            R.base = np.where((d < 0) & band, R.base + 0.007, R.base)
            R.base_cut(np.where(band, np.abs(d), np.inf), R.px, 0.002)
    # field: grid of four-petalled rosettes in squares
    cell = 0.23
    fx = np.mod(R.X + W / 2, cell) - cell / 2
    fy = np.mod(R.Y + D / 2 - 0.02, cell) - cell / 2
    inside = inner < 0
    sq = (np.maximum(np.abs(fx), np.abs(fy)) > cell / 2 - R.px * 1.0) & inside
    R.base = np.where(sq, R.base - 0.005, R.base)
    rr = np.hypot(fx, fy)
    ang = np.arctan2(fy, fx)
    petal = (rr < 0.085 * (0.55 + 0.45 * np.abs(np.cos(ang * 2.0)))) & inside
    R.base = np.where(petal, R.base + 0.008, R.base)
    R.base = np.where((rr < 0.022) & inside, R.base + 0.002, R.base)
    R.base_cut(np.where(inside & petal, np.abs(np.mod(ang * 4 / math.tau, 1.0) - 0.5) * rr * 1.5, np.inf), R.px * 0.8,
               0.0015)
    return R


def threshold():
    p = Part("asy_threshold_4m")
    W, D, t = 4.0, 1.2, 0.015
    p.box((0, 0, t / 2), (W, D, t), "edge", bevel=0.004)
    pts = [(-W / 2 + 0.004, -D / 2 + 0.004, t + 0.0002), (W / 2 - 0.004, -D / 2 + 0.004, t + 0.0002),
           (W / 2 - 0.004, D / 2 - 0.004, t + 0.0002), (-W / 2 + 0.004, D / 2 - 0.004, t + 0.0002)]
    p.poly(pts, "carpet")
    return p


def _plinth_relief(W, H0, seed=861):
    R = rl.Relief(W, 0.2, 96, u0=-W / 2, v0=H0, seed=seed)
    R.base[:] = 0.0
    n = max(1, int(round(W / 0.2)))
    for k in range(n):
        c = (-W / 2 + (k + 0.5) * W / n, H0 + 0.1)
        d = R.circle(c, 0.075)
        R.base = np.where(d < 0, R.base + 0.005, R.base)
        R.base_cut(np.abs(np.hypot(R.X - c[0], R.Y - c[1]) - 0.075), R.px, 0.003)
        for j in range(8):
            a = math.tau * j / 8
            R.base_cut(R.seg((c[0] + math.cos(a) * 0.02, c[1] + math.sin(a) * 0.02),
                             (c[0] + math.cos(a) * 0.07, c[1] + math.sin(a) * 0.07)), R.px, 0.0025)
    return R


def plinth(name, W, H, D):
    """Display plinth: a moulded base, the body with a band of carved
    rosettes under the cap (front and back; tall plinths only), a moulded
    cap. Pre-turn frame, front -Y."""
    p = Part(name)
    hb, hc = min(0.12, H * 0.2), min(0.14, H * 0.22)
    p.box((0, 0, hb / 2), (W + 0.1, D + 0.1, hb), "stone", bevel=0.02)
    body_top = H - hc
    p.box((0, 0, (hb + body_top) / 2), (W, D, body_top - hb), "stone", bevel=0.012)
    p.box((0, 0, H - hc / 2), (W + 0.1, D + 0.1, hc), "stone", bevel=0.025)
    if body_top - hb >= 0.4:
        z0, z1 = body_top - 0.24, body_top - 0.04
        y = D / 2 + 0.0015
        for sy in (-1, 1):
            f = p.poly([(-W / 2 + 0.03, sy * y, z0), (W / 2 - 0.03, sy * y, z0), (W / 2 - 0.03, sy * y, z1),
                        (-W / 2 + 0.03, sy * y, z1)], "band")[0]
            f.normal_update()
            if f.normal.y * sy < 0:
                f.normal_flip()
    return p


def build():
    out = []
    for W, tag in LENGTHS[:3]:
        out.append(kit(f"asy_frieze_{tag}", [frieze(W)], {"paint": _paint_frieze,
                                                         "ledge": lambda c: asy.cedar(c, center=3.6)},
                       wall=True, ground=None, ao_dist=0.25, preview=tag == "4m",
                       preview_yaws=(-20.0, 20.0, 50.0, -50.0), preview_elevation=4.0,
                       preview_extra=[("close", (0.0, 0.0, 0.31), 0.45, 0.0, 2.0)] if tag == "4m" else []))
    out.append(kit("asy_beam_4m", [beam()], {"cedar": asy.cedar, "bronze": asy.bronze_aged}, built_final=True,
                   ground=None, ceiling=0.0, ao_dist=0.3))
    out.append(kit("asy_corbel", [corbel()], {"stone": lambda c: asy.alabaster(c, center=8.4), "cedar": asy.cedar,
                                               "bronze": asy.bronze_aged}, wall=True, ground=None, ceiling=0.0,
                   ao_dist=0.3, preview=False))
    out.append(kit("asy_parapet_2m", [parapet()], {"stone": lambda c: asy.alabaster(c, center=8.0),
                                                   "brick": _brickwash}, ao_dist=0.3, wall=False))
    RJ = _jamb_relief()
    jmaps = asy.ReliefMaps(RJ)
    jamb_l = asy.relief_material(jmaps, uv=lambda c: (-(c.p[:, 0] - 2.35), c.p[:, 2]), center=8.6, paint=0.0)
    jamb_r = asy.relief_material(jmaps, uv=lambda c: ((c.p[:, 0] + 2.35), c.p[:, 2]), center=8.6, paint=0.0)
    out.append(kit("asy_portal_4m", [portal()], {"jamb_l": jamb_l, "jamb_r": jamb_r,
                                                  "jamb_side": lambda c: asy.alabaster(c, center=8.4),
                                                  "stone": lambda c: asy.alabaster(c, center=8.0),
                                                  "cedar": asy.cedar, "bronze": asy.bronze_aged,
                                                  "glaze": _glazed_band,
                                                  "glaze_side": lambda c: asy.glaze(c, "lapis", 4.2)},
                   wall=True, ao_dist=0.4, preview_yaws=(-20.0, 25.0, 60.0, -60.0), preview_elevation=8.0,
                   preview_extra=[("lintel", (0.0, -0.1, 5.0), 1.4, 10.0, 6.0)]))
    out.append(kit("asy_doorframe_2x2_6", [doorframe_small()], {"cedar": asy.cedar, "bronze": asy.bronze_aged},
                   ppm=128, wall=True, ao_dist=0.1))
    RT = _threshold_relief()
    tmaps = asy.ReliefMaps(RT)
    out.append(kit("asy_threshold_4m", [threshold()],
                   {"carpet": asy.relief_material(tmaps, uv=lambda c: (c.p[:, 0], c.p[:, 1]), center=8.4, paint=0.0,
                                                  grime=1.6, bevel=0.9),
                    "edge": lambda c: asy.alabaster(c, center=7.6)},
                   ppm=96, built_final=True, ao_rays=0, preview_elevation=55.0))
    for name, W, H, D in (("asy_plinth", 1.0, 1.0, 1.0), ("asy_plinth_low", 2.4, 0.4, 1.2)):
        RB = _plinth_relief(W - 0.06, H - min(0.14, H * 0.22) - 0.24)
        bmaps = asy.ReliefMaps(RB)
        band = asy.relief_material(bmaps, uv=AM.UV, center=8.8, paint=0.0, grime=0.0)
        out.append(kit(name, [plinth(name, W, H, D)], {"stone": lambda c: asy.alabaster(c, center=8.6),
                                                       "band": band}, ppm=96, ao_dist=0.25))
    return out
