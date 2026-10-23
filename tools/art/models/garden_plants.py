"""Floor I, the Asia wing's Japanese garden: the plants that grow behind the
garden's tsuiji wall and lean out over its coping (nothing of them comes
down below the coping: out of every guard's reach, no collision).

  garden_pine    a Japanese black pine pruned into clouds (niwaki): a dark,
                 plated trunk rising behind the coping in a slow S out over
                 the gravel, branches out to six flat pads of needles with
                 bristly fringes (alpha-cut needle cards round their rims).
                 Origin = the trunk's foot behind the coping; the tree leans
                 out to the front (built +Y in Blender = Godot -Z: over the
                 garden). 4.1 x 4.6 x 4.4 m (Godot x, y, z). 96 px/m.
  garden_bamboo  a 1.5 m stretch of a bamboo grove: eleven culms rising
                 from the foot line behind the coping, leaning out and
                 arching over the gravel (4.4-7.4 m), ringed at their nodes
                 (painted),
                 twigs with sprays of narrow leaves (alpha-cut leaf cards)
                 on their upper halves. Origin = the middle of the grove's
                 foot line; repeat it along a wall (mirrored, stretched a
                 little). 96 px/m.

The needle and leaf cards show small texture sets of their own (pine_fringe,
bamboo_leaves: painted once, every card the whole set) with alpha;
ArtLibrary.EXTRAS gives them an alpha scissor (and no back-face culling:
the cards are seen from both sides).
"""
import math
import random

import numpy as np
from mathutils import Matrix, Vector

from artlib import kit as K
from artlib import materials as M
from artlib import sculpt
from artlib.archkit import kit
from artlib.geo import Part
from artlib.kit import R, T
from artlib.materials import P, _dither, hexramp, smoothstep, strokes
from artlib.painter import Surface, paint_tile
from artlib.sculpt import blob

P.update({
    "pine_bark": hexramp("#0d0b0a", "#161311", "#201b18", "#2a2420", "#352e28", "#413830", "#4d433a", "#5a4f45"),
    "pine_needles": hexramp("#050a07", "#09120c", "#0d1a11", "#122316", "#182d1c", "#1f3822", "#274428", "#30502f",
                            "#3a5d36"),
    "bamboo_culm": hexramp("#141a0a", "#1f280f", "#2b3614", "#38451a", "#465520", "#556527", "#65752f", "#768538",
                           "#889442"),
    "bamboo_leaf": hexramp("#0c1406", "#132009", "#1a2c0c", "#223910", "#2b4714", "#355518", "#40631d", "#4c7123"),
})


def _card(p, centre, normal, up, w, h, slot):
    """A quad card ``w`` x ``h`` centred at ``centre`` facing ``normal`` with
    its v axis along ``up``; UVs locked to 0..1 over the card: every card
    shows the whole of its own texture set (``slot`` is exported as that
    set's material, not baked into the atlas)."""
    n = Vector(normal).normalized()
    u = Vector(up)
    u = (u - n * u.dot(n)).normalized()
    s = u.cross(n).normalized()
    c = Vector(centre)
    corners = [c - s * w / 2 - u * h / 2, c + s * w / 2 - u * h / 2, c + s * w / 2 + u * h / 2, c - s * w / 2 + u * h / 2]
    uvs = [(0.0, 0.0), (1.0, 0.0), (1.0, 1.0), (0.0, 1.0)]
    f = p._face([p.bm.verts.new(tuple(v)) for v in corners], slot)
    f.normal_update()
    flip = f.normal.dot(n) < 0
    if flip:
        f.normal_flip()
    by = {f.loops[i].vert: uv for i, uv in enumerate(uvs if not flip else list(reversed(uvs)))}
    for loop in f.loops:
        loop[p.uv].uv = by[loop.vert]
    f[p.lock] = 1
    return f


# --------------------------------------------------------------------------
# the pine (Blender: x along the wall, y out over the garden, z up)
# --------------------------------------------------------------------------

# (the trunk's foot a hand clear of the wall face, y 0: it rises from behind the coping's tiles)
TRUNK = [(0.0, 0.24, 0.0), (0.0, 0.27, 0.3), (0.05, 0.42, 0.7), (0.24, 0.85, 1.15), (0.42, 1.45, 1.6),
         (0.32, 2.02, 2.12), (0.04, 2.42, 2.72), (-0.22, 2.6, 3.28), (-0.3, 2.57, 3.78)]
FRINGE = (0.4, 0.3)    # the needle cards round the pads (w, h)
# pads: [trunk point the branch leaves from, the pad's middle, half sizes]
PADS = [
    (3, (-1.05, 1.2, 1.5), (0.62, 0.52, 0.2)),
    (4, (1.3, 1.9, 1.95), (0.66, 0.55, 0.21)),
    (5, (-0.95, 2.68, 2.45), (0.56, 0.47, 0.19)),
    (6, (0.95, 3.05, 2.95), (0.54, 0.45, 0.18)),
    (8, (-0.32, 2.77, 3.95), (0.52, 0.48, 0.21)),
    (2, (0.6, 1.0, 0.95), (0.4, 0.34, 0.15)),
]


def pine():
    rng = random.Random(4421)
    p = Part("garden_pine")
    p.tube([Vector(q) for q in TRUNK], lambda t: 0.2 * (1.0 - t) + 0.07, "bark", sides=9)
    # a few stubs of old cut branches on the trunk (the gardener's work)
    for k in (3, 5, 6):
        a = Vector(TRUNK[k])
        d = Vector((rng.uniform(-1, 1), rng.uniform(-0.3, 0.6), rng.uniform(-0.1, 0.4))).normalized()
        K.seg(p, tuple(a), tuple(a + d * 0.22), [(0.05, 0.0), (0.04, 1.0)], "bark", segments=6)
    for k, mid, half in PADS:
        a = Vector(TRUNK[k])
        m = Vector(mid)
        under = m - Vector((0.0, 0.0, half[2] * 0.6))
        elbow = a + (under - a) * 0.55 + Vector((0.0, 0.0, 0.18))
        p.tube([a, elbow, under], lambda t: 0.075 - 0.04 * t, "bark", sides=6)
        # the pad: lumps on a flat dome, then a fringe of needle cards
        lobes = [(m + Vector((0.0, 0.0, half[2] * 0.25)), (half[0] * 0.62, half[1] * 0.62, half[2] * 0.9))]
        for j in range(7):
            ang = 2 * math.pi * j / 7 + rng.uniform(-0.3, 0.3)
            off = Vector((math.cos(ang) * half[0] * 0.55, math.sin(ang) * half[1] * 0.55, rng.uniform(-0.04, 0.05)))
            r = rng.uniform(0.32, 0.42)
            lobes.append((m + off, (half[0] * r, half[1] * r, half[2] * 0.75)))
        me = sculpt.metaball_mesh([blob(tuple(c), sz, stiff=1.3) for c, sz in lobes], resolution=0.06)
        me = sculpt.decimate(me, 150)
        sculpt.into_part(p, me, "pad")
        for j in range(11):
            ang = 2 * math.pi * j / 11 + rng.uniform(-0.2, 0.2)
            rim = m + Vector((math.cos(ang) * half[0] * 0.92, math.sin(ang) * half[1] * 0.92, rng.uniform(-0.08, 0.02)))
            out = Vector((math.cos(ang), math.sin(ang), rng.uniform(-0.6, -0.1)))
            _card(p, tuple(rim), (out.x, out.y, 0.0), (0.0, 0.0, 1.0), FRINGE[0], FRINGE[1], "fringe")
        for j in range(3):
            ang = rng.uniform(0, 2 * math.pi)
            c = m + Vector((math.cos(ang) * half[0] * 0.3, math.sin(ang) * half[1] * 0.3, half[2] * 0.75))
            _card(p, tuple(c), (0.0, 0.0, 1.0), (math.cos(ang), math.sin(ang), 0.0), FRINGE[0], FRINGE[1], "fringe")
    return p


def pine_bark(ctx):
    """Black pine bark: dark grey-brown plates split by deep fissures."""
    s = Surface(ctx.N)
    f1, f2, cid = ctx.worley(np.array([9.0, 9.0, 3.5]), 4431)
    fissure = (f2 - f1) < 0.08
    shade = 4.2 + (cid - 0.5) * 1.6 + ctx.fbm(14.0, 2, 4433) * 0.6 + _dither(ctx, 0.5, 4435)
    shade -= fissure * 2.6 + (1.0 - ctx.ao) * 3.0
    shade += np.clip(ctx.curv, 0, 1) * 1.0
    s.use_ramp(P["pine_bark"], shade=shade)
    s.rough = np.full(ctx.N, 0.9)
    s.height = -fissure.astype(np.float64) * 0.003 + (cid - 0.5) * 0.001
    return s


def _needle_flow(ctx):
    """Needles splay out from the pads' middles and a little up."""
    c = np.array([q[1] for q in PADS])
    d = np.linalg.norm(ctx.p[:, None, :] - c[None, :, :], axis=2)
    near = c[np.argmin(d, axis=1)]
    out = ctx.p - near
    out[:, 2] = np.abs(out[:, 2]) * 0.3 + 0.15
    return out


def pad(ctx):
    """A pad of needles: dense dark tufts in 1-texel strokes, the tops
    catching the light, the undersides almost black."""
    s = Surface(ctx.N)
    flow = _needle_flow(ctx)
    st = strokes(ctx, flow, la=0.05, lc=0.012, seed=4441, fill=0.85)
    tufts = ctx.worley(14.0, 4443)[0]
    up = ctx.n[:, 2]
    shade = 4.4 + st * 1.4 + (0.5 - tufts) * 2.0 + up * 1.4 + _dither(ctx, 0.5, 4445)
    shade -= (1.0 - ctx.ao) * 3.5 + smoothstep(0.0, -0.8, up) * 1.6
    s.use_ramp(P["pine_needles"], shade=shade)
    s.rough = np.full(ctx.N, 0.8)
    s.height = st * 0.0008 - tufts * 0.002
    return s


def fringe(ctx):
    """Needle cards: bristly tufts fanning from the card's lower middle,
    cut out by alpha between the needles."""
    s = Surface(ctx.N)
    u, v = ctx.uvm[:, 0], ctx.uvm[:, 1]
    cx = FRINGE[0] * 0.5
    du, dv = u - cx, v + 0.02
    ang = np.arctan2(du, np.maximum(dv, 1e-4))
    r = np.hypot(du, dv)
    k = np.floor((ang + 1.6) / 0.045)
    jitter = np.mod(np.sin(k * 91.7) * 4375.85, 1.0)
    length = 0.18 + jitter * 0.12
    needle = (np.abs(np.mod((ang + 1.6) / 0.045, 1.0) - 0.5) < 0.22) & (r < length) & (np.abs(ang) < 1.25)
    shade = 3.6 + jitter * 1.6 + (r / 0.3) * 1.2 + _dither(ctx, 0.5, 4451)
    s.use_ramp(P["pine_needles"], shade=shade)
    s.rough = np.full(ctx.N, 0.8)
    s.alpha = np.where(needle, 1.0, 0.0)
    return s


# --------------------------------------------------------------------------
# the bamboo (Blender: x along the wall, y out over the garden, z up)
# --------------------------------------------------------------------------

GROVE = 1.5
LEAF_CARD = (0.56, 0.48)
NODE = 0.36            # between the culms' nodes


def bamboo():
    rng = random.Random(9173)
    p = Part("garden_bamboo")
    n = 11
    for i in range(n):
        x = (i + rng.uniform(0.15, 0.85)) / n * GROVE - GROVE / 2
        base = Vector((x, rng.uniform(0.06, 0.12), 0.0))
        height = rng.uniform(4.4, 7.4)
        out = math.radians(rng.uniform(13.0, 21.0))
        side = math.radians(-x / (GROVE * 0.5) * 3.0 + rng.uniform(-2.0, 2.0))   # the edges lean in
        radius = rng.uniform(0.03, 0.045)
        d = Vector((math.sin(side), math.sin(out), math.cos(out))).normalized()
        pts = [base]
        for k in range(4):
            bend = math.radians(5.0 * k)
            dk = Vector((d.x, d.y + math.sin(bend), d.z * math.cos(bend))).normalized()
            pts.append(pts[-1] + dk * height / 4)
        p.tube(pts, lambda t, r=radius: r * (1.0 - 0.5 * t), "culm", sides=6, caps=False)
        # the nodes (painted rings, every NODE m up the culm: culm()); from
        # the upper ones twigs with sprays of leaves (cards) over the garden
        walked = NODE
        total = height
        while walked < total - 0.2:
            t = walked / total
            seg = min(int(t * 4), 3)
            a, b = pts[seg], pts[seg + 1]
            q = a + (b - a) * (t * 4 - seg)
            if t > 0.3 and rng.random() < 0.8:
                yaw = rng.uniform(-0.8, 0.8)
                tw = Vector((math.sin(yaw), abs(math.cos(yaw)) + 0.25, rng.uniform(0.0, 0.4))).normalized()
                tip = q + tw * rng.uniform(0.25, 0.5)
                K.seg(p, tuple(q), tuple(tip), [(0.008, 0.0), (0.005, 1.0)], "culm", segments=4, caps=False)
                for c in range(3):
                    nrm = Vector((rng.uniform(-1, 1), rng.uniform(-0.3, 1.0), rng.uniform(-0.2, 0.6)))
                    centre = tip + Vector((rng.uniform(-0.08, 0.08), rng.uniform(0.0, 0.1), -0.12))
                    _card(p, tuple(centre), tuple(nrm), (tw.x, tw.y, 0.6), LEAF_CARD[0], LEAF_CARD[1], "leaves")
            walked += NODE
        # a tuft of leaves at the top
        top = pts[-1]
        for c in range(4):
            nrm = Vector((rng.uniform(-1, 1), rng.uniform(-0.2, 1.0), rng.uniform(-0.2, 0.6)))
            _card(p, tuple(top + Vector((0.0, 0.08, -0.15))), tuple(nrm), (d.x, d.y, 0.4), LEAF_CARD[0], LEAF_CARD[1],
                  "leaves")
    return p


def culm(ctx):
    """Green culms, a waxy bloom paling them, darker toward the foot, dry
    yellowish streaks; the nodes every NODE m (v runs up the tube in
    metres): a dark ring with a pale sheath scar over it."""
    s = Surface(ctx.N)
    z = ctx.p[:, 2]
    v = ctx.uvm[:, 1]
    k = np.mod(v + NODE * 0.5, NODE) - NODE * 0.5
    ring = np.abs(k) < 0.012
    scar = (k > 0.012) & (k < 0.03)
    streak = ctx.fbm(np.array([40.0, 40.0, 2.0]), 2, 9181) > 0.35
    shade = 4.8 + ctx.fbm(np.array([12.0, 12.0, 1.0]), 2, 9183) * 0.8 + _dither(ctx, 0.5, 9185)
    shade += streak * 1.4 + smoothstep(0.0, 3.0, z) * 0.8 - (1.0 - ctx.ao) * 3.0
    shade += ctx.edge_soft(2.0) * 0.4 - ring * 2.4 + scar * 1.6
    s.use_ramp(P["bamboo_culm"], shade=shade)
    s.rough = np.full(ctx.N, 0.45)
    s.height = ring * 0.0015
    return s


def leaves(ctx):
    """Leaf sprays on a card: five to seven narrow lanceolate leaves fanning
    down and out from the card's upper middle (the twig), cut out by alpha;
    the light side, a darker midrib, yellowing tips here and there."""
    s = Surface(ctx.N)
    u, v = ctx.uvm[:, 0], ctx.uvm[:, 1]
    origin = np.array([LEAF_CARD[0] * 0.5, LEAF_CARD[1] - 0.02])
    du, dv = u - origin[0], origin[1] - v          # dv: down the card from the twig
    inside = np.zeros(ctx.N, dtype=bool)
    rib = np.zeros(ctx.N, dtype=bool)
    tipcol = np.zeros(ctx.N)
    for k, (ang, ln) in enumerate(((-1.15, 0.36), (-0.62, 0.42), (-0.15, 0.45), (0.32, 0.41), (0.8, 0.38), (1.2, 0.3))):
        ca, sa = math.cos(ang), math.sin(ang)
        along = du * sa + dv * ca
        across = du * ca - dv * sa
        t = along / ln
        width = 0.034 * np.sin(np.clip(t, 0, 1) * math.pi) ** 0.8 * (1.0 - 0.3 * t)
        leaf = (t > 0.0) & (t < 1.0) & (np.abs(across) < width + 0.002)
        inside |= leaf
        rib |= leaf & (np.abs(across) < 0.004)
        tipcol = np.where(leaf & (t > 0.8) & (k % 3 == 1), 1.0, tipcol)
    shade = 4.6 + ctx.fbm(20.0, 2, 9191) * 0.8 + _dither(ctx, 0.5, 9193) - rib * 1.2 + ctx.n[:, 2] * 0.6
    s.use_ramp(P["bamboo_leaf"], shade=shade)
    s.use_ramp(P["bamboo_culm"], mask=tipcol > 0.5, shade=np.full(ctx.N, 6.6) + _dither(ctx, 0.5, 9195))
    s.rough = np.full(ctx.N, 0.6)
    s.alpha = np.where(inside, 1.0, 0.0)
    return s


CARD_PPM = 128


def build():
    return [
        kit("garden_pine", [pine()], {"bark": pine_bark, "pad": pad}, kinds={"fringe": "pine_fringe"},
            textures={"pine_fringe": paint_tile(fringe, FRINGE[0], FRINGE[1], CARD_PPM)}, ppm=96, built_final=True,
            ground=None, ao_dist=0.5, ao_rays=8, ao_stride=2),
        kit("garden_bamboo", [bamboo()], {"culm": culm}, kinds={"leaves": "bamboo_leaves"},
            textures={"bamboo_leaves": paint_tile(leaves, LEAF_CARD[0], LEAF_CARD[1], CARD_PPM)}, ppm=96,
            built_final=True, ground=None, ao_dist=0.3, ao_rays=6, ao_stride=2),
    ]
