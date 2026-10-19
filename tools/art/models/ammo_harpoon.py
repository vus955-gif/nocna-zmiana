"""Pickup: two spare harpoons for the harpoon gun, shorter than life
(0.45 m) with oversized two-flued heads so they read across a room,
lashed together with tarred twine and resting on a little salt-greyed
oak chock. A small coil of tarred line, made fast to the front harpoon's
ring, leans behind the bundle. The whalers' ownership marks - two bands
of sea-teal paint round each shank behind the head - and a museum
inventory tag (manila card, brass eyelet, the slot digit "7" in teal
ink) hanging from the front lashing give the bundle the harpoon gun's
colour (_pickup_palette.py: the HUD slot's, the rim's); bands and tag
glow faintly in the dark.

Origin at the centre (the game spins and bobs pickups); faces -Y: the
harpoons lie along X, heads to +X, flues upright so the arrowheads show
their full silhouette from the front. Part: ammo_harpoon.
"""
import math

import numpy as np
from mathutils import Matrix, Vector

from artlib import kit, pixelfont
from artlib import materials as M
from artlib.geo import Part
from artlib.kit import R, T
from artlib.model import Model
from artlib.painter import Surface
from models import _harpoon_parts as H
from models import _pickup_palette as PP

NAME = "ammo_harpoon"
HALF = 0.225                    # harpoon half length (tip at +HALF, tail at -HALF)
HEAD_S = 1.5
SHANK_R = 0.0095
ROPE_R = 0.005
# canonical harpoon space -> lying along +X, flues upright (canonical X -> Z), plates thin in Y
LIE = Matrix(((0, 1, 0, 0), (0, 0, 1, 0), (1, 0, 0, 0), (0, 0, 0, 1)))
BUNDLE = [(-0.0145, 0.0, 0.016), (0.0145, 0.013, -0.016)]       # (y, z, x shift) of the two harpoons
LASHINGS = (-0.105, 0.075)
# the painted marks: two bands round each shank, x ranges
MARKS = ((-0.012, 0.006), (0.02, 0.038))
# the inventory tag hanging from the front lashing
TAG_W, TAG_H, TAG_T = 0.064, 0.046, 0.002
TAG_C = Vector((LASHINGS[1] + 0.004, 0.0, -0.066))
DIGIT = PP.digit(NAME)
MANILA = M.hexramp("#3d3522", "#574c33", "#726446", "#8c7c5a", "#a4936e", "#b9a982", "#cbbd98", "#d9cfae")


def harpoon_iron(ctx):
    """Forged iron with the two painted marks behind the head."""
    s = H.forged(ctx, seed=901, center=4.8, rust=0.9)
    x = ctx.p[:, 0]
    band = np.zeros(ctx.N, dtype=bool)
    for x0, x1 in MARKS:
        band |= (x > x0) & (x < x1)
    band &= np.abs(ctx.n[:, 0]) < 0.8                      # round the shank, not its end faces
    worn = band & (ctx.rand(911) > 0.08) & (ctx.edge_soft(2.0) < 0.9)
    s.use_ramp(M.P["pk_" + NAME], mask=worn, shade=np.full(ctx.N, 5.0) + ctx.fbm(30.0, 2, 913) * 0.8
               + M._dither(ctx, 0.7, 915) - (1.0 - ctx.ao) * 2.0)
    s.rough = np.where(worn, 0.55, s.rough)
    s.metal = np.where(worn, 0.0, s.metal)
    PP.accent(s, worn, NAME)
    return s


def rope(ctx):
    return H.tar_rope(ctx, seed=903, radius=ROPE_R, center=3.6, lay=0.036)


def tag(ctx):
    """Manila card: a teal rule round the edge, the slot digit in teal ink
    on both faces, the paper foxed and bent at the corners."""
    s = Surface(ctx.N)
    shade = 5.0 + ctx.fbm(10.0, 3, 921) * 0.6 + M._dither(ctx, 0.6, 923) + ctx.edge(1.0) * 0.6
    fox = (ctx.fbm(25.0, 2, 925) > 0.45) & (ctx.rand(927) > 0.5)
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
    ink = (rule | digit) & (ctx.rand(929) > 0.04)
    s.use_ramp(M.P["pk_" + NAME], mask=ink, shade=np.full(ctx.N, 3.8) + M._dither(ctx, 0.7, 931))
    s.height = s.height - ink * 0.00005
    PP.white(s, faces & ~ink, 0.12)
    PP.accent(s, ink, NAME, 0.45)
    return s


FNS = {"harpoon": harpoon_iron, "rope": rope, "twine": lambda c: H.twine(c, seed=905, pitch=0.0045),
       "chock": lambda c: H.sea_oak(c, seed=907, center=5.0), "iron": lambda c: H.forged(c, seed=909, center=4.0),
       "tag": tag, "brass": lambda c: M.brass(c, seed=933, tarnish_amount=1.6)}


def _harpoon(p, y, z, dx):
    tip = HALF + dx
    frame = T(tip, y, z) @ LIE
    H.head(p, frame, s=HEAD_S)
    tail = -HALF + dx
    H.shank(p, frame, tail + 0.008 - tip, -0.12, r=SHANK_R)
    kit.seg(p, (tail, y, z), (tail + 0.02, y, z), [(0.007, 0.0), (0.0122, 0.25), (0.0125, 0.6), (0.0098, 1.0)],
            "harpoon", segments=10)                                                     # end button
    ring_c = Vector((tail + 0.036, y, z))
    H.torus(p, ring_c, (1.0, 0.0, -0.25), 0.0175, 0.0034, "harpoon", segments=14, ring=6)
    return ring_c


def _lashing(p, x):
    """Tarred twine wrapped round both shafts."""
    (y0, z0, _), (y1, z1, _) = BUNDLE
    c = Vector((0.0, (y0 + y1) / 2, (z0 + z1) / 2))
    u = Vector((0.0, y1 - y0, z1 - z0))
    half = u.length / 2
    u.normalize()
    v = Vector((0.0, -u.z, u.y))
    a, b = half + SHANK_R + 0.0022, SHANK_R + 0.0022
    rings = []
    for xx, g in ((x - 0.008, 0.0), (x - 0.006, 0.0014), (x + 0.006, 0.0014), (x + 0.008, 0.0)):
        ring = []
        for k in range(12):
            t = -math.pi / 2 + math.tau * k / 12          # seam underneath
            q = c + u * ((a + g) * math.cos(t)) + v * ((b + g) * math.sin(t))
            ring.append(Vector((xx, q.y, q.z)))
        rings.append(ring)
    H.loft(p, rings, "twine")


def _tag(p):
    """The inventory tag: a card hanging on a short twine from the front
    lashing's underside, a brass eyelet at its top, thin in Y so its face
    (the digit) shows from the front and the back as the bundle turns."""
    p.box((TAG_C.x, TAG_C.y, TAG_C.z), (TAG_W, TAG_T, TAG_H), "tag", bevel=0.0006)
    eye = TAG_C + Vector((0.0, 0.0, TAG_H / 2 - 0.005))
    H.torus(p, eye, (0.0, 1.0, 0.0), 0.0032, 0.0011, "brass", segments=10, ring=5)
    knot = Vector((LASHINGS[1], 0.0, -0.008))
    p.tube([knot, knot + Vector((0.002, 0.0, -0.008)), eye + Vector((0.0, 0.0, 0.003))], 0.0012, "twine", sides=4)


def build():
    p = Part(NAME)
    # oak chock under the middle, two iron nails
    p.box((0.0, 0.0, -0.034), (0.08, 0.095, 0.042), "chock", bevel=0.006)
    for x in (-0.024, 0.024):
        kit.seg(p, (x, -0.048, -0.034), (x, -0.051, -0.034), [(0.004, 0.0), (0.004, 0.5), (0.0025, 1.0)], "iron",
                segments=6)
    rings = [_harpoon(p, y, z, dx) for y, z, dx in BUNDLE]
    for x in LASHINGS:
        _lashing(p, x)
    _tag(p)
    # the line: from the front harpoon's ring up into a small coil leaning behind the bundle
    rc = rings[0]
    centre = Vector((-0.085, 0.045, 0.045))
    rad = 0.044
    tilt = Matrix.Rotation(math.radians(-22.0), 3, 'X')
    coil = []
    n = 16
    for i in range(3 * n + 1):
        th = math.tau * i / n - math.pi / 2
        q = Vector((rad * math.cos(th) * (1.0 + 0.04 * math.sin(i * 0.9)), 0.0105 * i / n,
                    rad * math.sin(th) * 1.05))
        coil.append(centre + tilt @ q)
    start = rc + Vector((-0.012, -0.004, -0.013))
    lead = [rc + Vector((-0.004, -0.002, -0.017)), start, start + Vector((0.02, 0.012, -0.012)),
            coil[0] + Vector((-0.012, -0.012, -0.004))]
    tail_end = coil[-1]
    tail = [tail_end + Vector((0.012, 0.004, -0.01)), tail_end + Vector((0.03, 0.006, -0.03)),
            tail_end + Vector((0.042, 0.008, -0.055))]
    pts = lead + coil + tail
    H.rope(p, pts, ROPE_R, "rope", sides=6, chunk=0.2)
    d = (pts[-1] - pts[-2]).normalized()
    kit.seg(p, pts[-1] - d * 0.012, pts[-1] - d * 0.001, [(0.0058, 0.0), (0.0058, 1.0)], "twine", segments=6)
    kit.sphere(p, rc + Vector((-0.002, -0.003, -0.016)), 0.0075, "rope", segments=8, rings=5)
    return Model(NAME, [p], FNS, ppm=320, ground=None, ao_dist=0.05, ao_rays=12, ao_stride=1,
                 preview_elevation=22.0)
