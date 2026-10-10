"""Pickup: fire-arrows for the fire-arrow box (vm_hwacha). Six singijeon
in a round sheaf, bound with red silk cord in two places; on the front
binding a red maedeup knot with two silk tassels hanging from it. Each
arrow as in hwacha_rocket (iron point, red paper powder tube with twine
wraps, bamboo shaft, barred vanes, the clay nozzle cold), a little
shorter and fuller so the bundle reads across a room: 0.4 m long.

Origin at the centre of the bundle (the game spins and bobs pickups);
faces -Y: the arrows lie along X, points to +X, the knot and tassels on
the front. Part: ammo_hwacha.
"""
import math

import numpy as np
from mathutils import Vector

from artlib import kit
from artlib import materials as M
from artlib.geo import Part
from artlib.kit import R, T
from artlib.model import Model
from artlib.painter import Surface
from models import _hwacha_parts as HP

L = 0.4
RT, RS = 0.0115, 0.0040
HEAD_LEN, NOSE, TUBE_LEN = 0.034, 0.011, 0.075
FLETCH_LEN, FLETCH_H = 0.068, 0.0125
RING = 0.0245                         # the arrows' distance from the bundle axis at X_RING (powder tubes
X_RING = 0.045                        # touching at their back ends)
TAPER = 0.043                         # the sheaf narrows toward the fletching (radial slope)
BINDS = (0.03, -0.1)                  # x of the two silk bindings
BIND_W = 0.013
KNOT_X = BINDS[0]


def tassel(ctx, seed=741):
    """Silk tassel threads: fine lengthwise lines, a sheen, darker inside."""
    s = Surface(ctx.N)
    i = np.floor(ctx.uvm[:, 0] / ctx.texel + 1e-6)
    thread = np.mod(i, 2) == 0
    shade = 5.2 + thread * 0.9 + ctx.fbm(12.0, 2, seed) * 0.5 + M._dither(ctx, 0.4, seed + 1)
    shade += np.clip(ctx.curv, 0, 1) * 1.0 - (1.0 - ctx.ao) * 3.5
    s.use_ramp(HP.RAMPS["silk"], shade=shade)
    s.rough = 0.42 + (~thread) * 0.12
    s.height = thread * 0.0002
    return s


FNS = dict(HP.ARROW_FNS, nozzle=lambda c: HP.nozzle(c, hot=False), silk=HP.silk, tassel=tassel)


def ring_r(x):
    """Distance of the arrows' axes from the sheaf's axis at x."""
    return RING + TAPER * (x - X_RING)


def arrows(p):
    tilt = math.degrees(math.atan(TAPER))
    for k in range(6):
        th = math.radians(30.0 + 60.0 * k)
        r0 = ring_r(0.0)
        y, z = r0 * math.cos(th), r0 * math.sin(th)
        # along +X, the point end leaning out from the axis (a sheaf that fans out)
        place = T(0.0, y, z) @ R('X', math.degrees(th)) @ R('Z', tilt) @ R('X', -math.degrees(th)) @ R('Z', -90.0)
        HP.arrow_full(p, place, L=L, rt=RT, rs=RS, head_len=HEAD_LEN, nose=NOSE, tube_len=TUBE_LEN, seg=7,
                      fletch_len=FLETCH_LEN, fletch_h=FLETCH_H, nozzle_slot="nozzle",
                      vane_phase=math.degrees(th) - 90.0 + 60.0)


def binding(p, x):
    """Turns of red silk cord round the sheaf: a rounded band, seam underneath."""
    r = ring_r(x) + RS + 0.0018
    prof = [(r - 0.0012, 0.0), (r + 0.0006, 0.15), (r + 0.0012, 0.5), (r + 0.0006, 0.85), (r - 0.0012, 1.0)]
    kit.seg(p, (x - BIND_W / 2, 0, 0), (x + BIND_W / 2, 0, 0), [(rr, t) for rr, t in prof], "silk", segments=10,
            caps=False, phase=-math.pi / 2)


def knot_and_tassels(p):
    """A flat maedeup knot on the front of the front binding (a diamond of
    cord with four loops), two tassels hanging from it on short cords."""
    y_front = -(ring_r(KNOT_X) + RS + 0.003)
    c = Vector((KNOT_X, y_front - 0.003, -0.004))
    body = p.box((0, 0, 0), (0.016, 0.006, 0.016), "silk", bevel=0.002)
    p.move(body, T(*c) @ R('Y', 45.0))
    for a in (0.0, 90.0, 180.0, 270.0):                                  # the knot's four loops
        loop = kit.sphere(p, (0, 0, 0), 0.0042, "silk", segments=6, rings=3, squash=(1.0, 0.6))
        d = Vector((math.cos(math.radians(a)), 0.0, math.sin(math.radians(a)))) * 0.0125
        p.move(loop, T(*(c + d)))
    for dx in (-0.007, 0.007):
        top = c + Vector((dx, -0.001, -0.009))
        hang = top + Vector((dx * 0.6, -0.002, -0.022))
        p.tube([top, top + Vector((dx * 0.3, -0.0015, -0.012)), hang], 0.0016, "silk", sides=5)
        kit.sphere(p, hang + Vector((0, 0, -0.003)), 0.0048, "silk", segments=6, rings=4, zscale=1.2)
        skirt = [(0.0034, 0.0), (0.0052, 0.006), (0.0068, 0.03), (0.0078, 0.05), (0.0072, 0.054)]
        kit.seg(p, hang + Vector((0, 0, -0.007)), hang + Vector((0, 0, -0.061)),
                [(r, t / 0.054) for r, t in skirt], "tassel", segments=8)


def build():
    p = Part("ammo_hwacha")
    arrows(p)
    for x in BINDS:
        binding(p, x)
    knot_and_tassels(p)
    return Model("ammo_hwacha", [p], FNS, ppm=320, ground=None, ao_dist=0.04, ao_rays=12, ao_stride=1,
                 preview_elevation=22.0,
                 preview_extra=[("knot", (KNOT_X, -0.03, -0.03), 0.07, -15.0, 12.0)])
