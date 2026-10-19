"""Pickup: fire-arrows for the fire-arrow box (vm_hwacha). Six singijeon
in a round sheaf standing on end, points up and fletching down (the one
tall pickup: it reads apart from the lying harpoons and the boxes), bound
with silk cord in two places; on the front of the upper binding a flat
maedeup knot with two silk tassels hanging from it, from the lower binding
a museum inventory tag (manila card, the slot digit "8"). Paper powder
tubes, silk and tassels are dyed violet - the fire-arrow box's colour in
the HUD and on the floor (_pickup_palette.py) - and glow faintly in the
dark. Each arrow as in hwacha_rocket (iron point, paper powder tube with
twine wraps, bamboo shaft, barred vanes, the clay nozzle cold), a little
shorter and fuller so the bundle reads across a room: 0.4 m tall.

Origin at the centre of the bundle (the game spins and bobs pickups);
faces -Y: the arrows stand along Z, points to +Z, the knot, tassels and
tag on the front. Part: ammo_hwacha.
"""
import math

import numpy as np
from mathutils import Vector

from artlib import kit, pixelfont
from artlib import materials as M
from artlib.geo import Part
from artlib.kit import R, T
from artlib.model import Model
from artlib.painter import Surface
from models import _harpoon_parts as H
from models import _hwacha_parts as HP
from models import _pickup_palette as PP

NAME = "ammo_hwacha"
L = 0.4
RT, RS = 0.0115, 0.0040
HEAD_LEN, NOSE, TUBE_LEN = 0.034, 0.011, 0.075
FLETCH_LEN, FLETCH_H = 0.068, 0.0125
RING = 0.0245                         # the arrows' distance from the bundle axis at Z_RING (powder tubes
Z_RING = 0.045                        # touching at their back ends)
TAPER = 0.043                         # the sheaf narrows toward the fletching (radial slope)
BINDS = (0.03, -0.1)                  # z of the two silk bindings
BIND_W = 0.013
KNOT_Z = BINDS[0]
UP = R('Y', -90.0)                    # the lying sheaf (along +X) stood on end (+X -> +Z)
# the inventory tag: hanging on the front from the lower binding, clear of the vanes
TAG_W, TAG_H, TAG_T = 0.05, 0.036, 0.002
TAG_C = Vector((0.0, -0.044, -0.146))
DIGIT = PP.digit(NAME)
PAPER = PP.ramp(NAME, steps=9, lo=0.1, hi=0.8, lift=0.1)         # dyed paper: the colour, darkened
SILK = PP.ramp(NAME, steps=9, lo=0.18, hi=1.0, lift=0.3)         # the silk, brighter with a sheen
MANILA = M.hexramp("#3d3522", "#574c33", "#726446", "#8c7c5a", "#a4936e", "#b9a982", "#cbbd98", "#d9cfae")


def paper(ctx, seed=701, center=5.2):
    """Violet-dyed mulberry paper wound round the powder tube (as
    _hwacha_parts.paper, in the pickup's colour), glowing faintly."""
    s = Surface(ctx.N)
    along, across = M._grain_frame(ctx)
    q = np.stack([np.sum(ctx.p * along, 1), np.sum(ctx.p * across, 1), np.sum(ctx.p * ctx.n, 1)], axis=1)
    fib = ctx.fbm(np.array([30.0, 220.0, 220.0]), 2, seed, p=q)
    blot = ctx.fbm(6.0, 3, seed + 1)
    shade = center + fib * 0.7 + blot * 0.6 + M._dither(ctx, 0.6, seed + 2)
    seam = np.abs(np.mod(ctx.uvm[:, 0] / 0.031 + ctx.uvm[:, 1] / 0.024, 1.0) - 0.5) < 0.06
    shade -= seam * 1.3
    flecks = ctx.rand(seed + 3) > 0.985
    shade += flecks * 2.0
    shade += ctx.edge(1.0) * 1.0 - ctx.cavity(3.0) * 1.6 - (1.0 - ctx.ao) * 3.0
    s.use_ramp(PAPER, shade=shade)
    s.rough = 0.72 + ctx.rand(seed + 4) * 0.08
    s.height = fib * 0.00012 - seam * 0.0002
    PP.glow(s, np.ones(ctx.N, dtype=bool))
    return s


def silk(ctx, seed=717):
    """Violet silk cord: twisted, with a soft sheen, glowing faintly."""
    s = Surface(ctx.N)
    k = np.mod(ctx.uvm[:, 0] / 0.006 + ctx.uvm[:, 1] / 0.008, 1.0)
    ply = np.abs(np.mod(k * 2.0, 1.0) - 0.5) * 2.0
    shade = 5.6 + (0.55 - ply) * 2.6 + ctx.fbm(8.0, 2, seed) * 0.5 + M._dither(ctx, 0.5, seed + 1)
    shade += np.clip(ctx.curv, 0, 1) * 1.2 - (1.0 - ctx.ao) * 3.5
    s.use_ramp(SILK, shade=shade)
    s.rough = 0.42 + ply * 0.15
    s.height = (0.55 - ply) * 0.0003
    PP.glow(s, np.ones(ctx.N, dtype=bool), 0.35)
    return s


def tassel(ctx, seed=741):
    """Silk tassel threads: fine lengthwise lines, a sheen, darker inside."""
    s = Surface(ctx.N)
    i = np.floor(ctx.uvm[:, 0] / ctx.texel + 1e-6)
    thread = np.mod(i, 2) == 0
    shade = 5.8 + thread * 0.9 + ctx.fbm(12.0, 2, seed) * 0.5 + M._dither(ctx, 0.4, seed + 1)
    shade += np.clip(ctx.curv, 0, 1) * 1.0 - (1.0 - ctx.ao) * 3.5
    s.use_ramp(SILK, shade=shade)
    s.rough = 0.42 + (~thread) * 0.12
    s.height = thread * 0.0002
    PP.glow(s, np.ones(ctx.N, dtype=bool))
    return s


def tag(ctx):
    """Manila card with the slot digit in violet ink on both faces."""
    s = Surface(ctx.N)
    shade = 5.0 + ctx.fbm(10.0, 3, 751) * 0.6 + M._dither(ctx, 0.6, 753) + ctx.edge(1.0) * 0.6
    fox = (ctx.fbm(25.0, 2, 755) > 0.45) & (ctx.rand(757) > 0.5)
    shade -= fox * 1.0 + (1.0 - ctx.ao) * 2.0
    s.use_ramp(MANILA, shade=shade)
    s.rough = np.full(ctx.N, 0.88)
    faces = np.abs(ctx.n[:, 1]) > 0.7
    u, v = ctx.uvm[:, 0], ctx.uvm[:, 1]
    cu = np.where(ctx.n[:, 1] < 0.0, TAG_C.x, -TAG_C.x)
    du, dv = u - cu, v - TAG_C.z
    t = ctx.texel
    rule = faces & (((np.abs(np.abs(du) - (TAG_W / 2 - 2.5 * t)) < 0.5 * t) & (np.abs(dv) < TAG_H / 2 - 2.0 * t))
                    | ((np.abs(np.abs(dv) - (TAG_H / 2 - 2.5 * t)) < 0.5 * t) & (np.abs(du) < TAG_W / 2 - 2.0 * t)))
    digit = faces & pixelfont.stamp(ctx, DIGIT, 0.0, 0.0, scale=2, u=du, v=dv)
    ink = (rule | digit) & (ctx.rand(759) > 0.04)
    s.use_ramp(SILK, mask=ink, shade=np.full(ctx.N, 4.0) + M._dither(ctx, 0.7, 761))
    s.height = s.height - ink * 0.00005
    PP.white(s, faces & ~ink, 0.12)
    PP.accent(s, ink, NAME, 0.45)
    return s


FNS = dict(HP.ARROW_FNS, paper=paper, nozzle=lambda c: HP.nozzle(c, hot=False), silk=silk, tassel=tassel, tag=tag,
           brass=lambda c: M.brass(c, seed=763, tarnish_amount=1.6))


def ring_r(z):
    """Distance of the arrows' axes from the sheaf's axis at height z."""
    return RING + TAPER * (z - Z_RING)


def arrows(p):
    tilt = math.degrees(math.atan(TAPER))
    for k in range(6):
        th = math.radians(30.0 + 60.0 * k)
        r0 = ring_r(0.0)
        y, z = r0 * math.cos(th), r0 * math.sin(th)
        # built lying along +X (the point end leaning out from the axis, a
        # sheaf that fans out), then stood on end by UP
        place = UP @ T(0.0, y, z) @ R('X', math.degrees(th)) @ R('Z', tilt) @ R('X', -math.degrees(th)) @ R('Z', -90.0)
        HP.arrow_full(p, place, L=L, rt=RT, rs=RS, head_len=HEAD_LEN, nose=NOSE, tube_len=TUBE_LEN, seg=7,
                      fletch_len=FLETCH_LEN, fletch_h=FLETCH_H, nozzle_slot="nozzle",
                      vane_phase=math.degrees(th) - 90.0 + 60.0)


def binding(p, z):
    """Turns of silk cord round the standing sheaf: a rounded band, seam at the back."""
    r = ring_r(z) + RS + 0.0018
    prof = [(r - 0.0012, 0.0), (r + 0.0006, 0.15), (r + 0.0012, 0.5), (r + 0.0006, 0.85), (r - 0.0012, 1.0)]
    kit.seg(p, (0, 0, z - BIND_W / 2), (0, 0, z + BIND_W / 2), [(rr, t) for rr, t in prof], "silk", segments=10,
            caps=False, phase=math.pi / 2)


def knot_and_tassels(p):
    """A flat maedeup knot on the front of the upper binding (a diamond of
    cord with four loops), two tassels hanging from it on short cords."""
    y_front = -(ring_r(KNOT_Z) + RS + 0.003)
    c = Vector((0.0, y_front - 0.003, KNOT_Z - 0.004))
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


def inventory_tag(p):
    """The card on a twine from the lower binding's front, hanging out past
    the vanes, a brass eyelet at its top."""
    p.box((TAG_C.x, TAG_C.y, TAG_C.z), (TAG_W, TAG_T, TAG_H), "tag", bevel=0.0006)
    eye = TAG_C + Vector((0.0, 0.0, TAG_H / 2 - 0.004))
    H.torus(p, eye, (0.0, 1.0, 0.0), 0.0028, 0.001, "brass", segments=10, ring=5)
    z0 = BINDS[1]
    knot = Vector((0.0, -(ring_r(z0) + RS + 0.002), z0 - BIND_W / 2 + 0.002))
    p.tube([knot, knot + Vector((0.0, -0.012, -0.012)), eye + Vector((0.0, 0.0, 0.0025))], 0.0012, "twine", sides=4)


def build():
    p = Part(NAME)
    arrows(p)
    for z in BINDS:
        binding(p, z)
    knot_and_tassels(p)
    inventory_tag(p)
    return Model(NAME, [p], FNS, ppm=320, ground=None, ao_dist=0.04, ao_rays=12, ao_stride=1,
                 preview_elevation=22.0,
                 preview_extra=[("knot", (0.0, -0.03, KNOT_Z - 0.03), 0.07, -15.0, 12.0)])
