"""Pickup: a box of belted rifle cartridges for the Gatling. An olive-
painted wooden ammunition box with black iron corners and rope handles,
"NABOJE" stencilled on the front (real letters, artlib/pixelfont.py) and
the slot digit "4" on both ends and on the lid, all in the gatling's lit
olive yellow-green (_pickup_palette.py: the HUD slot's colour, the rim's),
the stencils glowing faintly in the dark; lid open behind. Inside, the top
fold of a khaki canvas belt with two rows of brass cartridges standing
tips-up; the belt's end spills over the left end of the box and hangs down
it with cartridges across it. Larger than life (cartridges x1.3) so it
reads across a room: box 0.26 x 0.15 x 0.12 m, the biggest ammo pickup.

Origin at the box centre (the game spins and bobs pickups); faces -Y.
Part: ammo_rifle.
"""
import numpy as np
from mathutils import Vector

from artlib import kit, pixelfont
from artlib import materials as M
from artlib.geo import Part
from artlib.kit import R, T
from artlib.model import Model
from models import _pickup_palette as PP

NAME = "ammo_rifle"
W, D, H = 0.26, 0.15, 0.12
CASE_R, CASE_L = 0.0078, 0.056
STENCIL = pixelfont.trim(pixelfont.render("NABOJE", bold=True))
DIGIT = PP.digit(NAME)
LID_T = 0.014
LID_M = T(0, D / 2, H / 2) @ R('X', -18) @ T(0, 0.007, D / 2)
LID_N = np.array((LID_M.to_3x3() @ Vector((0, 1, 0))).normalized())
LID_C = PP.face_uv(LID_M @ Vector((0, LID_T / 2, 0)), LID_N)


def wood(ctx):
    s = M.paint(ctx, "paint_olive", 4.4, seed=561, chip=1.0, under="wood_oak", gloss=0.7)
    z = ctx.p[:, 2]
    front = ctx.n[:, 1] < -0.7
    txt = front & pixelfont.stamp(ctx, STENCIL, 0.0, 0.004)
    # the digit on both ends, under the rope handle and between the corner
    # brackets, and on the lid's outside
    ends = (np.abs(ctx.n[:, 0]) > 0.7) & (z < H / 2) & pixelfont.stamp(ctx, DIGIT, 0.0, -0.022, scale=2)
    lid = (ctx.n @ LID_N > 0.9) & (z > H / 2 + 0.004) & pixelfont.stamp(ctx, DIGIT, LID_C[0], LID_C[1], scale=2)
    marks = (txt | ends | lid) & (ctx.rand(563) > 0.06) & (s.ramp_id == 0)
    s.use_ramp(M.P["pk_" + NAME], mask=marks,
               shade=np.full(ctx.N, 5.4) + ctx.fbm(25.0, 2, 565) * 0.8 + M._dither(ctx, 0.8, 567))
    PP.accent(s, marks, NAME)
    return s


def webbing(ctx):
    s = M.cloth(ctx, "webbing", 4.2, seed=569, weave=0.45, rough=0.92)
    return s


FNS = {"wood": wood, "inside": lambda c: M.wood_oak(c, seed=571), "iron": M.iron, "brass": M.brass,
       "copper": lambda c: M.brass(c, seed=573, ramp="copper", tarnish_amount=1.4), "webbing": webbing,
       "rope": lambda c: M.cloth(c, "webbing", 5.0, seed=575, weave=0.8, rough=0.95)}


def cartridge(p, base, direction, full=True, segments=7):
    """A rifle cartridge from its base along ``direction``: rimmed brass
    case with a shoulder and neck, copper bullet with a round nose. With
    ``full=False`` only the part above the belt (shoulder, neck, bullet)."""
    d = Vector(direction).normalized()
    b = Vector(base)
    L = CASE_L
    prof = [(CASE_R * 1.12, 0.0), (CASE_R * 1.12, 0.05), (CASE_R, 0.07), (CASE_R * 0.93, 0.72), (CASE_R * 0.62, 0.82),
            (CASE_R * 0.6, 1.0)]
    if not full:
        prof = [(r, t) for r, t in prof if t >= 0.6]
        prof[0] = (CASE_R * 0.95, 0.6)
    t0 = prof[0][1]
    kit.seg(p, b + d * (L * t0), b + d * L, [(r, (t - t0) / (1 - t0)) for r, t in prof], "brass",
            segments=segments, caps=full)
    tip = b + d * (L + 0.026)
    kit.seg(p, b + d * L, tip, [(CASE_R * 0.6, 0.0), (CASE_R * 0.6, 0.45), (CASE_R * 0.45, 0.8), (CASE_R * 0.2, 1.0)],
            "copper", segments=segments)


def build():
    p = Part(NAME)
    p.box((0, 0, 0), (W, D, H), "wood", bevel=0.005)
    p.box((0, 0, H / 2 - 0.004), (W - 0.02, D - 0.02, 0.01), "inside", bevel=0.001)
    # iron corner brackets
    for sx in (-1, 1):
        for sy in (-1, 1):
            for sz in (-1, 1):
                p.box((sx * (W / 2 - 0.012), sy * (D / 2 - 0.012), sz * (H / 2 - 0.012)), (0.028, 0.028, 0.028),
                      "iron", bevel=0.004)
    # rope handles on both ends
    for sx in (-1, 1):
        pts = [(sx * (W / 2 + 0.002), -0.035, 0.02)]
        for k in range(1, 8):
            a = np.pi * k / 8
            pts.append((sx * (W / 2 + 0.002 + 0.028 * np.sin(a)), -0.035 * np.cos(a), 0.02 - 0.012 * np.sin(a)))
        pts.append((sx * (W / 2 + 0.002), 0.035, 0.02))
        p.tube(pts, 0.0055, "rope", sides=6)
    # the top fold of the belt inside: a webbing strip, two rows of tips
    top = H / 2 + 0.002
    for row, y in enumerate((-0.03, 0.028)):
        p.box((0.0, y, top), (W - 0.03, 0.03, 0.006), "webbing", bevel=0.001)
        n = 10
        for k in range(n):
            x = -W / 2 + 0.025 + k * (W - 0.05) / (n - 1)
            tilt = (k % 3 - 1) * 3.0
            base = Vector((x, y, top - CASE_L * 0.55))
            cartridge(p, base, (0, np.sin(np.radians(tilt)), np.cos(np.radians(tilt))), full=False, segments=6)
    # the belt's end over the left end of the box: webbing down the side,
    # cartridges lying across it (along Y)
    x_side = -W / 2 - 0.012
    path = [Vector((-W / 2 + 0.04, 0.0, top + 0.004)), Vector((-W / 2 - 0.004, 0.0, top + 0.01)),
            Vector((x_side, 0.0, top - 0.02)), Vector((x_side - 0.003, 0.0, -H / 2 + 0.03))]
    for a, b in zip(path[:-1], path[1:]):
        mid = (a + b) * 0.5
        d = (b - a)
        strip = p.box((0, 0, 0), (0.006, 0.034, d.length + 0.004), "webbing", bevel=0.001)
        ang = np.degrees(np.arctan2(d.x, d.z))
        p.move(strip, T(*mid) @ R('Y', ang))
    for k in range(5):
        z = top - 0.028 - k * 0.022
        x = x_side - 0.011
        cartridge(p, (x, -CASE_L * 0.55, z), (0, 1, 0), full=True, segments=7)
    # lid, hinged along the back top edge, open past vertical
    lid = p.box((0, 0, 0), (W, LID_T, D), "wood", bevel=0.004)
    p.move(lid, LID_M)
    return Model(NAME, [p], FNS, ppm=256, ground=None, ao_dist=0.05, ao_rays=12, ao_stride=1,
                 preview_elevation=22.0)
