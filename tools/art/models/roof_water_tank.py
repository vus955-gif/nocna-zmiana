"""Floor I's roof, the plant deck: the museum's water tank.

  roof_water_tank  a riveted steel tank of three plate courses on a steel
                   trestle: four angle-iron legs on bolted base plates,
                   braced on every side, two rolled joists under the tank;
                   lap seams with rivet rows (rust weeping down from them),
                   two hoops at the seams, a shallow conical lid with an
                   access hatch and a mushroom vent, pigeon droppings; the
                   ladder up its front (-Z) hooked over the curb; the
                   overflow down its east side (+X), the float gauge's
                   board on its west side, the feed pipe and its red gate
                   valve under it. 2.9 x 3.5 x 2.9 m (Godot x, y, z) in
                   the greybox box 3 x 3.5 x 3; its collision is drawn
                   from it (Floor1Art.FIT_COLLISION). 128 px/m.

Kit convention: origin = the middle of the footprint on the deck; built
front +Y in Blender (= Godot -Z).
"""
import math

import numpy as np
from mathutils import Matrix

from artlib import court_materials as CM
from artlib import kit as K
from artlib import roof_materials as RM
from artlib.archkit import kit
from artlib.geo import Part
from artlib.materials import P, _dither

R = 1.3                  # the tank's radius
BOTTOM = 0.86            # its floor (on the joists)
COURSES = (0.86, 1.54, 2.22, 2.88)   # plate courses (seams between)
CURB = 2.92              # the top curb angle
LID_TOP = 3.24
VENT_TOP = 3.5
LEG = 1.12               # the legs stand at (+-LEG, +-LEG)
JOIST_Y = 0.72
LADDER_Y = R + 0.15
LADDER_X = 0.21
SEG = 28


def _angle_leg(p, sx, sy, z0, z1, a=0.1, t=0.012):
    """An angle-iron leg at the corner (sx, sy), its flanges inward."""
    cx, cy = sx * LEG, sy * LEG
    pts = [(cx, cy), (cx - sx * a, cy), (cx - sx * a, cy - sy * t), (cx - sx * t, cy - sy * t),
           (cx - sx * t, cy - sy * a), (cx, cy - sy * a)]
    area = sum(x0 * y1 - x1 * y0 for (x0, y0), (x1, y1) in zip(pts, pts[1:] + pts[:1]))
    if area < 0:
        pts.reverse()
    p.ngon_prism(pts, z0, z1, "stand")


def _flat_bar(p, a, b, w=0.055, t=0.01, mat="stand"):
    """A flat bar from a to b, its thickness across the vertical side it
    lies on (local x of the segment's frame is horizontal: the side's normal)."""
    a, b = np.array(a, float), np.array(b, float)
    f = p.box((0.0, 0.0, 0.0), (t, w, float(np.linalg.norm(b - a))), mat)
    rot = K.align((0, 0, 0), tuple(b - a)).to_3x3()
    p.move(f, Matrix.Translation(tuple((a + b) * 0.5)) @ rot.to_4x4())
    return f


def stand(p):
    top = BOTTOM - 0.07
    for sx in (-1, 1):
        for sy in (-1, 1):
            _angle_leg(p, sx, sy, 0.02, top - 0.14)
            p.box((sx * (LEG - 0.06), sy * (LEG - 0.06), 0.01), (0.26, 0.26, 0.02), "stand")
            for k in range(2):
                bx = sx * (LEG - 0.06) + (k - 0.5) * 0.16 * sx
                p.box((bx, sy * (LEG - 0.13), 0.03), (0.035, 0.035, 0.025), "bolt")
    # braces on every side: an X of flat bars, a tie along the foot
    lo, hi = 0.14, top - 0.2
    for s in (-1, 1):
        _flat_bar(p, (-LEG + 0.05, s * (LEG - 0.006), lo), (LEG - 0.05, s * (LEG - 0.006), hi))
        _flat_bar(p, (-LEG + 0.05, s * (LEG - 0.006), hi), (LEG - 0.05, s * (LEG - 0.006), lo))
        _flat_bar(p, (s * (LEG - 0.006), -LEG + 0.05, lo), (s * (LEG - 0.006), LEG - 0.05, hi))
        _flat_bar(p, (s * (LEG - 0.006), -LEG + 0.05, hi), (s * (LEG - 0.006), LEG - 0.05, lo))
        p.box((0.0, s * (LEG - 0.02), lo - 0.04), (2 * LEG - 0.1, 0.06, 0.012), "stand")
        p.box((s * (LEG - 0.02), 0.0, lo - 0.04), (0.012, 2 * LEG - 0.1, 0.06), "stand")
    # the cap beams round the legs' tops, two rolled joists across (I sections)
    zc = top - 0.14
    for s in (-1, 1):
        p.box((0.0, s * (LEG - 0.05), zc - 0.05), (2 * LEG + 0.04, 0.1, 0.1), "stand")
        p.box((s * (LEG - 0.05), 0.0, zc - 0.05), (0.1, 2 * LEG + 0.04, 0.1), "stand")
    for s in (-1, 1):
        y = s * JOIST_Y
        p.box((0.0, y, zc + 0.005), (2.24, 0.14, 0.012), "stand")
        p.box((0.0, y, top - 0.006), (2.24, 0.14, 0.012), "stand")
        p.box((0.0, y, (zc + top) * 0.5), (2.24, 0.014, top - zc - 0.02), "stand")
    # timber bearers between the joists and the tank's floor
    for x in (-0.75, 0.0, 0.75):
        p.box((x, 0.0, top + 0.035), (0.12, 2.1, 0.07), "bearer")


def tank(p):
    """The shell (a lathe of courses lapped in and out, hoops at the seams,
    the bottom flange and the curb) and the lid with its hatch and vent."""
    prof = [(0.0, BOTTOM), (R + 0.05, BOTTOM), (R + 0.05, BOTTOM + 0.06), (R + 0.008, BOTTOM + 0.06)]
    for i in range(3):
        z0, z1 = COURSES[i], COURSES[i + 1]
        r = R + (0.008 if i % 2 == 0 else 0.0)
        if i > 0:
            # the hoop on the seam (a flat band riveted round)
            prof += [(r, z0 + 0.012), (R + 0.035, z0 + 0.012), (R + 0.035, z0 + 0.075), (r, z0 + 0.075)]
        prof.append((r, z1 - (0.0 if i == 2 else 0.012)))
    prof += [(R + 0.05, COURSES[-1]), (R + 0.05, CURB), (R + 0.01, CURB)]
    p.lathe(prof, "tank", segments=SEG, cap_bottom=False, cap_top=False)
    lid = [(R - 0.02, CURB - 0.005), (R + 0.075, CURB - 0.005), (R + 0.075, CURB + 0.04), (0.3, LID_TOP - 0.02),
           (0.09, LID_TOP)]
    p.lathe(lid, "lid", segments=SEG, cap_bottom=False, cap_top=False)
    # the vent: a pipe through the lid's crown under a mushroom cowl
    K.seg(p, (0.0, 0.0, LID_TOP - 0.06), (0.0, 0.0, VENT_TOP - 0.1), [(0.075, 0.0), (0.075, 1.0)], "zinc",
          segments=10, caps=False)
    p.lathe([(0.075, VENT_TOP - 0.11), (0.23, VENT_TOP - 0.07), (0.23, VENT_TOP - 0.035), (0.12, VENT_TOP - 0.005),
             (0.0, VENT_TOP)], "zinc", segments=12, cap_bottom=True)
    # the hatch on the lid's front slope, its lid hinged at the top, a handle
    slope = math.atan2(LID_TOP - 0.02 - (CURB + 0.04), (R + 0.075) - 0.3)
    r_h = 0.82
    z_h = CURB + 0.04 + ((R + 0.075) - r_h) * math.tan(slope)
    turn = Matrix.Translation((0.0, r_h, z_h)) @ Matrix.Rotation(-slope, 4, 'X')
    f = p.box((0.0, 0.0, 0.03), (0.56, 0.5, 0.1), "lid")
    f += p.box((0.0, 0.0, 0.095), (0.62, 0.56, 0.03), "lid", bevel=0.008)
    f += p.tube([(-0.12, 0.2, 0.11), (-0.1, 0.2, 0.17), (0.1, 0.2, 0.17), (0.12, 0.2, 0.11)], 0.012, "bolt", sides=5)
    for sx in (-1, 1):
        f += p.box((sx * 0.18, -0.29, 0.1), (0.1, 0.05, 0.05), "bolt")
    p.move(f, turn)


def ladder(p):
    top = CURB + 0.26
    for sx in (-1, 1):
        x = sx * LADDER_X
        p.tube([(x, LADDER_Y, 0.0), (x, LADDER_Y, CURB + 0.1), (x, LADDER_Y - 0.06, top), (x, R + 0.06, top),
                (x, R - 0.06, CURB + 0.1)], 0.02, "ladder", sides=6)
        # stand-offs to the shell and a foot plate
        for z in (1.25, 2.55):
            p.box((x, (R + LADDER_Y) * 0.5 + 0.01, z), (0.03, LADDER_Y - R + 0.02, 0.05), "ladder")
        p.box((x, LADDER_Y, 0.008), (0.09, 0.09, 0.016), "ladder")
    z = 0.3
    while z < CURB:
        K.seg(p, (-LADDER_X, LADDER_Y, z), (LADDER_X, LADDER_Y, z), [(0.014, 0.0), (0.014, 1.0)], "ladder",
              segments=6, caps=False)
        z += 0.3


def pipes(p):
    # the overflow from under the curb down the east side, in under the tank
    # and down past the trestle's braces to the deck
    x = R + 0.11
    xl = LEG + 0.07
    pts = [(R - 0.02, 0.35, 2.74), (x - 0.03, 0.35, 2.74), (x, 0.35, 2.7), (x, 0.35, 0.86), (x - 0.04, 0.35, 0.79),
           (xl + 0.03, 0.35, 0.76), (xl, 0.35, 0.71), (xl, 0.35, 0.2), (xl, 0.42, 0.1), (xl, 0.6, 0.06)]
    p.tube(pts, 0.048, "pipe", sides=8)
    for z in (2.74, 1.9, 1.15):
        if z < 1.0:
            p.box((x, 0.35, z), (0.11, 0.11, 0.05), "pipe")
        else:
            p.box((x - 0.06, 0.35, z), (0.12, 0.05, 0.04), "pipe")
            K.seg(p, (x, 0.35, z - 0.025), (x, 0.35, z + 0.025), [(0.062, 0.0), (0.062, 1.0)], "pipe", segments=8)
    # the feed under the tank: down from its floor, out to the back past the legs
    fx, fy = 0.32, -0.3
    p.tube([(fx, fy, BOTTOM), (fx, fy, 0.3), (fx, fy - 0.08, 0.2), (fx, -1.05, 0.2), (fx, -1.25, 0.2),
            (fx, -1.3, 0.12), (fx, -1.3, 0.0)], 0.055, "pipe", sides=8)
    K.seg(p, (fx, fy, BOTTOM - 0.06), (fx, fy, BOTTOM - 0.01), [(0.1, 0.0), (0.1, 1.0)], "pipe", segments=10)
    # the gate valve on the feed, its red hand wheel
    vy = -0.62
    p.box((fx, vy, 0.2), (0.16, 0.16, 0.16), "pipe", bevel=0.015)
    K.seg(p, (fx, vy, 0.28), (fx, vy, 0.42), [(0.022, 0.0), (0.022, 1.0)], "pipe", segments=6)
    wheel = p.lathe([(0.1, -0.012), (0.115, 0.0), (0.1, 0.012), (0.085, 0.0)], "valve", segments=14,
                    cap_bottom=False, cap_top=False)
    p.move(wheel, Matrix.Translation((fx, vy, 0.42)))
    for a in (0.0, math.pi / 2):
        p.box((fx, vy, 0.42), (0.19 * abs(math.cos(a)) + 0.02, 0.19 * abs(math.sin(a)) + 0.02, 0.016), "valve")


def gauge(p):
    """The float gauge on the west side: a white board with its scale, the
    pointer on its cord over a little pulley at the top."""
    x = -(R + 0.1)
    y = -0.2
    p.box((x, y, 1.95), (0.025, 0.16, 1.72), "gauge")
    for z in (1.25, 2.6):
        p.box(((x - R) * 0.5 - 0.01, y, z), (abs(x + R) + 0.02, 0.03, 0.04), "pipe")
    p.box((x - 0.03, y, 2.32), (0.03, 0.2, 0.035), "valve")
    pulley = p.lathe([(0.04, -0.012), (0.05, 0.0), (0.04, 0.012)], "pipe", segments=10)
    p.move(pulley, Matrix.Translation((x + 0.02, y, CURB + 0.12)) @ Matrix.Rotation(math.pi / 2, 4, 'X'))
    K.seg(p, (x - 0.03, y, 2.34), (x - 0.03, y, CURB + 0.12), [(0.004, 0.0), (0.004, 1.0)], "pipe", segments=4,
          caps=False)


def build_tank():
    p = Part("roof_water_tank")
    stand(p)
    tank(p)
    ladder(p)
    pipes(p)
    gauge(p)
    return p


# --------------------------------------------------------------------------
# paint
# --------------------------------------------------------------------------

def _seam_rivets(ctx):
    """Rivet rows of the shell: round each seam and the curb, up the plates'
    vertical laps (six plates a course, staggered course to course)."""
    x, y, z = ctx.p[:, 0], ctx.p[:, 1], ctx.p[:, 2]
    a = np.arctan2(y, x)
    arc = a * R
    head = np.zeros(ctx.N, dtype=bool)
    for h in (BOTTOM + 0.03, COURSES[1] + 0.045, COURSES[2] + 0.045, CURB - 0.02):
        m, _ = RM.dots(arc, z - h, 0.075, 0.011)
        head |= m
    for i in range(3):
        z0, z1 = COURSES[i], COURSES[i + 1]
        within = (z > z0 + 0.08) & (z < z1 - 0.02)
        for k in range(6):
            a0 = (k + 0.5 * i) * math.tau / 6.0
            d = np.angle(np.exp(1j * (a - a0))) * R
            m, _ = RM.dots(z, d, 0.075, 0.011, a0=z0)
            head |= within & m
    return head & (np.abs(ctx.n[:, 2]) < 0.5)


def shell(ctx):
    s = RM.painted_plate(ctx, center=5.0, seed=851, rust=1.0, runs=(COURSES[1] + 0.012, COURSES[2] + 0.012, CURB - 0.02,
                                                                      BOTTOM + 0.06), run_len=0.5)
    RM.rivet_rows(ctx, s, _seam_rivets(ctx), shade=6.6)
    # a stencilled tank number on the front course, faded
    x, y, z = ctx.p[:, 0], ctx.p[:, 1], ctx.p[:, 2]
    arc = np.arctan2(x, y) * R          # round from the front (the ladder's middle)
    front = (np.hypot(x, y) > R - 0.02) & (np.abs(ctx.n[:, 2]) < 0.3) & (arc > 0.45) & (arc < 1.09) & (z > 1.72)         & (z < 2.06)
    if front.any():
        # (seen from the front Godot +X is on the left: u runs against the arc)
        u = (1.09 - arc) / 0.64
        v = (z - 1.72) / 0.34
        two = (u > 0.2) & (u < 0.8) & (
            ((v > 0.84) & (np.abs(u - 0.5) < 0.26)) |
            ((u > 0.64) & (v > 0.52) & (v < 0.92)) |
            ((np.abs(v - 0.5) < 0.08) & (np.abs(u - 0.5) < 0.26)) |
            ((u < 0.36) & (v < 0.52) & (v > 0.1)) |
            ((v < 0.16) & (np.abs(u - 0.5) < 0.3)))
        ink = front & two & (ctx.fbm(30.0, 2, 861) > -0.35)
        s.use_ramp(P["dropping"], mask=ink, shade=np.full(ctx.N, 2.4) + _dither(ctx, 0.8, 862))
    return s


def lid(ctx):
    s = RM.painted_plate(ctx, center=4.6, seed=871, rust=1.3, runs=(CURB + 0.03,), run_len=0.2, fade=1.4)
    x, y, z = ctx.p[:, 0], ctx.p[:, 1], ctx.p[:, 2]
    r = np.hypot(x, y)
    # rivets round the lid's rim and up its radial laps
    m, _ = RM.dots(np.arctan2(y, x) * (R + 0.04), z - (CURB + 0.02), 0.075, 0.011)
    RM.rivet_rows(ctx, s, m & (r > R), shade=6.2)
    RM.droppings(ctx, s, amount=1.6, seed=873)
    return s


def gauge_board(ctx):
    """White paint on wood, a black scale every 0.1 m, FULL and EMPTY bands."""
    s = CM.portland(ctx, 881, center=8.4)
    z = ctx.p[:, 2]
    face = ctx.n[:, 0] < -0.5
    tick = face & (np.abs(np.mod(z - 1.15, 0.1) - 0.05) > 0.042) & (np.abs(ctx.p[:, 1] + 0.2) < 0.045)
    big = face & (np.abs(np.mod(z - 1.15, 0.5) - 0.25) > 0.238)
    s.use_ramp(P["cast_iron"], mask=tick | big, shade=np.full(ctx.N, 1.0))
    full = face & (z > 2.62) & (z < 2.76)
    s.use_ramp(P["formline_red"], mask=full, shade=np.full(ctx.N, 3.6) + _dither(ctx, 0.6, 883))
    return s


def valve(ctx):
    s = RM.painted_plate(ctx, ramp="formline_red", center=3.6, seed=891, rust=0.8, fade=0.3)
    return s


TANK_FNS = {
    "tank": shell, "lid": lid, "stand": lambda c: RM.roof_steel(c, 895, center=3.0),
    "bolt": lambda c: RM.roof_steel(c, 896, center=2.2, rust=1.2), "bearer": lambda c: CM.cedar(c, 897, center=3.6, grey=0.5),
    "ladder": lambda c: RM.galvanised(c, 898, center=4.0), "zinc": lambda c: RM.galvanised(c, 899, center=4.8),
    "pipe": lambda c: CM.cast_iron(c, 900, center=3.6), "valve": valve, "gauge": gauge_board,
}


def build():
    return [kit("roof_water_tank", [build_tank()], TANK_FNS, ppm=128, built_final=True, ground=0.0, ao_dist=0.35,
                ao_rays=10, ao_stride=2, preview_yaws=(-35.0, 35.0, 145.0, 215.0), preview_elevation=14.0)]
