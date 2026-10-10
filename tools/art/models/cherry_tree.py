"""The flowering cherry of the Japanese garden (somei-yoshino in full
bloom): an old gnarled trunk leaning a little, splitting low into four
great limbs that spread wide and drop again, glossy banded bark, and
clouds of white-pink blossom on every limb end - solid clusters with a
lacy fringe of alpha-cut blossom cards round them. 6.3 m high, about 8 m
across.

  cherry_tree           parts: cherry_tree (trunk and limbs), cherry_blossom
                        (the clusters - world-mapped tile field
                        tile:cherry_blossom, 2 x 2 m - and the fringe cards
                        in the atlas, alpha-cut: ArtLibrary.EXTRAS gives the
                        atlas its alpha scissor). Markers Petals_1..Petals_10 under
                        the clusters, where petal particle emitters belong
                        (petals fall a few metres and drift).
  cherry_petals_ground  fallen petals: four 2 x 2 m alpha-cut sheets lying on
                        the gravel (+0.006 m); scatter round the tree.
Origin = the foot of the trunk on the floor.
"""
import math
import random

import numpy as np
from mathutils import Matrix, Vector

from artlib import asia as A
from artlib import kit as K
from artlib import sculpt
from artlib.archkit import kit
from artlib.geo import Part
from artlib.kit import R, T
from artlib.materials import P, _dither
from artlib.painter import Surface
from artlib.sculpt import blob


def _branch(rng, start, direction, length, radius, depth, out_tips, segs):
    """A crooked limb as a polyline; recurses into two or three children."""
    pts = [Vector(start)]
    d = Vector(direction).normalized()
    n = 4
    for k in range(n):
        d = (d + Vector((rng.uniform(-0.35, 0.35), rng.uniform(-0.35, 0.35), rng.uniform(-0.15, 0.25)))).normalized()
        if depth >= 2:
            d.z -= 0.08 * k                       # outer limbs droop
            d.normalize()
        pts.append(pts[-1] + d * (length / n))
    r0, r1 = radius, radius * 0.55
    segs.append((pts, r0, r1))
    if depth >= 3 or radius < 0.05:
        out_tips.append((pts[-1], d))
        return
    for c in range(2 if depth > 0 else 3):
        side = Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(0.0, 0.6))).normalized()
        nd = (d * 0.6 + side * 0.7).normalized()
        k = rng.randint(2, n)
        _branch(rng, pts[k], nd, length * rng.uniform(0.55, 0.75), r1 * rng.uniform(0.75, 0.9), depth + 1, out_tips,
                segs)
    if depth >= 1:
        out_tips.append((pts[-1], d))


def tree():
    rng = random.Random(11)
    trunk = Part("cherry_tree")
    bloom = Part("cherry_blossom", parent="cherry_tree")
    segs, tips = [], []
    # the trunk: a short leaning bole
    base = [Vector((0.0, 0.0, -0.05)), Vector((0.05, 0.02, 0.6)), Vector((0.18, -0.05, 1.3)), Vector((0.25, 0.0, 1.8))]
    trunk.tube(base, lambda t: 0.34 - 0.12 * t, "bark", sides=10)
    # flared root buttresses
    for k in range(5):
        a = math.tau * k / 5 + 0.3
        trunk.tube([(math.cos(a) * 0.15, math.sin(a) * 0.15, 0.45), (math.cos(a) * 0.35, math.sin(a) * 0.35, 0.12),
                    (math.cos(a) * 0.6, math.sin(a) * 0.6, -0.02)], lambda t: 0.14 - 0.1 * t, "bark", sides=6)
    for k, a in enumerate((20, 110, 200, 290)):
        d = Vector((math.cos(math.radians(a)), math.sin(math.radians(a)), 0.9 + rng.uniform(-0.2, 0.2)))
        _branch(rng, base[-1], d, 2.6 + rng.uniform(-0.3, 0.4), 0.2, 0, tips, segs)
    for pts, r0, r1 in segs:
        trunk.tube(pts, lambda t, r0=r0, r1=r1: r0 + (r1 - r0) * t, "bark", sides=7 if r0 > 0.1 else 5)
    # blossom clusters on the tips (merged where they crowd)
    centres = []
    for pt, d in tips:
        c = pt + d * 0.3 + Vector((0, 0, 0.15))
        if all((c - o).length > 0.9 for o in centres):
            centres.append(c)
    for c in centres:
        s = rng.uniform(0.8, 1.1)
        # a spray of small lobes on a flattened, drooping dome (soft
        # metaballs that touch without melting into one ball)
        lobes = []
        for k in range(7):
            a = math.tau * k / 7 + rng.uniform(-0.3, 0.3)
            rr = s * rng.uniform(0.45, 0.85)
            off = Vector((math.cos(a) * rr, math.sin(a) * rr, -0.25 * rr + rng.uniform(-0.1, 0.15) * s))
            lobes.append((c + off, s * rng.uniform(0.3, 0.42)))
        lobes.append((c + Vector((0.0, 0.0, 0.18 * s)), s * 0.42))
        b = [blob(tuple(q), (r, r * 0.95, r * 0.75), stiff=1.2) for q, r in lobes]
        me = sculpt.metaball_mesh(b, resolution=0.06)
        me = sculpt.decimate(me, 170)
        sculpt.into_part(bloom, me, "cluster")
        # petal cards: crossed alpha-cut quads poking out of every lobe and
        # hanging under the spray (the edge goes lacy, sprigs droop)
        for q, r in lobes:
            for k in range(2):
                a = rng.uniform(0, math.tau)
                el = rng.uniform(-0.7, 0.6)
                dirv = Vector((math.cos(a) * math.cos(el), math.sin(a) * math.cos(el), math.sin(el)))
                pos = q + dirv * r * rng.uniform(0.7, 1.0)
                w = r * rng.uniform(0.8, 1.15)
                m = T(*pos) @ dirv.to_track_quat('Z', 'Y').to_matrix().to_4x4() @ R('Z', rng.uniform(0, 180))
                for rot in (0, 90):
                    f = bloom.poly([(-w / 2, 0.0, -w / 2), (w / 2, 0.0, -w / 2), (w / 2, 0.0, w / 2),
                                    (-w / 2, 0.0, w / 2)], "card")
                    bloom.move(f, m @ R('Z', rot) @ R('X', 90))
    return [trunk, bloom], centres


def ground():
    p = Part("cherry_petals_ground")
    rng = random.Random(4)
    for k in range(4):
        cx, cy = rng.uniform(-2.5, 2.5), rng.uniform(-2.5, 2.5)
        a = rng.uniform(0, 90)
        f = p.poly([(-1.0, -1.0, 0.006), (1.0, -1.0, 0.006), (1.0, 1.0, 0.006), (-1.0, 1.0, 0.006)], "petals")
        p.move(f, T(cx, cy, 0.0) @ R('Z', a))
    return p


def cluster_paint(ctx, seed=2201):
    s = A.blossom(ctx, seed, alpha=False)
    return s


def card_paint(ctx, seed=2203):
    """Blossom cards: flowers in the middle thinning to nothing at the edge
    (alpha cut), so the clouds end in a lace of single flowers."""
    s = A.blossom(ctx, seed, density=1.0, alpha=True)
    flower = s.alpha > 0.5
    s.alpha = np.where(flower & (ctx.rand(seed + 2) > 0.15), 1.0, 0.0)
    return s


def petals_paint(ctx, seed=2211):
    """Fallen petals on gravel: single petals and small drifts; everything
    else cut away by alpha."""
    s = Surface(ctx.N)
    f1, _, cid = ctx.worley(90.0, seed)
    drift = ctx.fbm(1.5, 3, seed + 1) > 0.1
    petal = (f1 < 0.18) & ((cid > 0.65) | drift)
    s.use_ramp(P["blossom"], shade=6.5 + (cid - 0.5) * 2.0 + _dither(ctx, 0.5, seed + 2))
    s.rough = np.full(ctx.N, 0.7)
    s.alpha = np.where(petal, 1.0, 0.0)
    return s


def build():
    parts, centres = tree()
    markers = []
    picks = [max(centres, key=lambda v: v.z)]
    while len(picks) < min(10, len(centres)):
        picks.append(max(centres, key=lambda v: min((v - q).length for q in picks)))
    for k, c in enumerate(picks):
        markers.append((f"Petals_{k + 1}", (c.x, c.y, c.z - 0.5), None))
    out = [kit("cherry_tree", parts, {"bark": A.bark, "card": card_paint}, kinds={"cluster": "tile:cherry_blossom"},
               preview_kinds={}, ppm=80,
               ao_dist=0.6, ao_rays=8, built_final=True, organic=("cherry_blossom",), markers=markers,
               preview_elevation=12.0)]
    out.append(kit("cherry_petals_ground", [ground()], {"petals": petals_paint}, ppm=96, ao_rays=0, ground=None,
                   built_final=True, preview_elevation=40.0))
    return out
