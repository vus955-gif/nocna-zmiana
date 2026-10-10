"""Lobby kit: the nature diorama's set dressing (in front of the painted
backdrop, on the flocked grass).

  rock_a, rock_b  chunky faceted boulders (about 2.4 x 1.6 x 2 m and 2.2 x
                  1.3 x 2 m), grey stone with moss on the upward faces, flat
                  bottoms. Origin = centre of the base; scale freely to the
                  kit "rock" size (they are lumps).
  dead_tree       a bare, storm-broken tree 5.5 m tall with five limbs and
                  root flares; origin = centre of the trunk's base.
  grass_tuft      three crossed quads 0.6 x 0.45 m with alpha-cut blades
                  (ArtLibrary gives it alpha scissor, two-sided); scatter
                  them over the grass patches, 1-2 per square metre.
  fence_rail_2m / _1m  rustic split-log railing 0.7 m tall: a post at -X,
                  two rails; tile along X and close the run with fence_post.
  fence_post      the post alone.
"""
import math

import numpy as np
from mathutils import Matrix

from artlib import arch_materials as A
from artlib import materials as M
from artlib import sculpt
from artlib.archkit import kit
from artlib.geo import Part
from artlib.painter import Surface


def _rock(name, seed, size):
    rng = np.random.default_rng(seed)
    sx, sy, sz = size
    blobs = [sculpt.blob((0.0, 0.0, sz * 0.35), (sx * 0.5, sy * 0.5, sz * 0.55), kind="ELLIPSOID", stiff=2.0)]
    for _ in range(7):
        c = (rng.uniform(-0.35, 0.35) * sx, rng.uniform(-0.35, 0.35) * sy, rng.uniform(0.2, 0.75) * sz)
        s = (rng.uniform(0.2, 0.36) * sx, rng.uniform(0.2, 0.36) * sy, rng.uniform(0.18, 0.3) * sz)
        blobs.append(sculpt.blob(c, s, kind="CUBE", stiff=1.5, rot=tuple(rng.uniform(-30, 30, 3))))
    me = sculpt.metaball_mesh(blobs, resolution=0.06)
    sculpt.cut(me, [((0, 0, 0.0), (0, 0, -1))])
    me = sculpt.decimate(me, 520)
    p = Part(name)
    sculpt.into_part(p, me, "rock", smooth=False)
    return p


def _rock_mat(ctx):
    s = M.stone(ctx)
    s.shade -= 0.6
    up = ctx.n[:, 2]
    moss = (up > 0.55) & (ctx.fbm(3.0, 3, 11) + up * 0.6 > 0.55)
    s.use_ramp(A.P["flock"], mask=moss, shade=3.5 + ctx.fbm(9.0, 2, 12) * 1.5 + (ctx.rand(13) - 0.5) * 1.2)
    s.rough = np.where(moss, 0.95, s.rough)
    return s


def dead_tree():
    p = Part("dead_tree")
    rng = np.random.default_rng(7)
    trunk = [(0.0, 0.0, -0.05), (0.03, 0.02, 1.2), (-0.05, 0.05, 2.5), (0.05, -0.02, 3.6), (0.12, 0.0, 4.6),
             (0.2, 0.05, 5.5)]
    p.tube(trunk, lambda t: 0.26 * (1.0 - 0.8 * t) + 0.02, "bark", sides=9)
    limbs = [((0.0, 0.0, 2.2), (1.4, 0.3, 3.4), 0.1), ((0.0, 0.0, 3.0), (-1.3, -0.2, 4.2), 0.09),
             ((0.05, 0.0, 3.8), (0.9, -0.6, 4.9), 0.07), ((0.1, 0.0, 4.3), (-0.6, 0.5, 5.3), 0.06),
             ((0.0, 0.0, 1.6), (-0.9, 0.7, 2.2), 0.07)]
    for a, b, r in limbs:
        mid = tuple((np.array(a) + np.array(b)) / 2 + np.array([0.0, 0.0, 0.25]))
        p.tube([a, mid, b], lambda t, r=r: r * (1.0 - 0.75 * t) + 0.01, "bark", sides=6)
        tip = np.array(b)
        for k in range(2):
            d = rng.uniform(-0.5, 0.5, 3)
            d[2] = abs(d[2]) + 0.2
            p.tube([tuple(tip), tuple(tip + d * 0.8)], lambda t: 0.025 * (1 - 0.8 * t) + 0.004, "bark", sides=4)
    for k in range(5):
        a = math.tau * k / 5 + 0.3
        p.tube([(0.0, 0.0, 0.35), (0.35 * math.cos(a), 0.35 * math.sin(a), 0.08),
                (0.65 * math.cos(a), 0.65 * math.sin(a), -0.05)], lambda t: 0.12 * (1 - 0.8 * t), "bark", sides=6)
    return p


def _bark(ctx):
    s = A.timber(ctx)
    s.use_ramp(A.P["rubble"], shade=s.shade + 1.2)
    ridge = ctx.fbm(np.array([22.0, 22.0, 3.0]), 3, 5)
    s.shade += ridge * 1.4
    s.height = s.height + ridge * 0.004
    return s


def grass_tuft():
    p = Part("grass_tuft")
    W, H = 0.6, 0.45
    for k in range(3):
        a = math.radians(k * 60.0)
        c, s_ = math.cos(a), math.sin(a)
        pts = [(-W / 2 * c, -W / 2 * s_, 0.0), (W / 2 * c, W / 2 * s_, 0.0), (W / 2 * c, W / 2 * s_, H),
               (-W / 2 * c, -W / 2 * s_, H)]
        verts = [p.bm.verts.new(v) for v in pts]
        f = p._face(verts, "blades")
        for loop, uv in zip(f.loops, ((0.0, 0.0), (W, 0.0), (W, H), (0.0, H))):
            loop[p.uv].uv = (uv[0] + k * 0.7, uv[1])
        f[p.lock] = 1
    return p


def _blades(ctx):
    u, v = ctx.uvm[:, 0], ctx.uvm[:, 1]
    n = ctx.N
    rng = np.random.default_rng(3)
    mask = np.zeros(n, dtype=bool)
    tip = np.zeros(n)
    straw = np.zeros(n, dtype=bool)
    for panel in range(3):
        off = panel * 0.7
        for _ in range(26):
            x0 = off + rng.uniform(0.05, 0.55)
            h = rng.uniform(0.2, 0.44)
            lean = rng.uniform(-0.35, 0.35)
            w0 = rng.uniform(0.012, 0.024)
            dry = rng.random() < 0.18
            t = np.clip(v / h, 0.0, 1.0)
            cx = x0 + lean * v * (0.4 + 0.6 * t)
            m = (np.abs(u - cx) < w0 * (1.0 - t) * 0.5 + ctx.texel * 0.5) & (v < h) & (u > off - 0.01) & \
                (u < off + 0.61)
            mask |= m
            tip = np.where(m, t, tip)
            straw |= m & dry
    s = Surface(n)
    s.use_ramp(A.P["flock"], shade=2.2 + tip * 5.0 + (ctx.rand(4) - 0.5) * 1.0)
    s.use_ramp(A.P["straw"], mask=straw, shade=1.2 + tip * 3.5)
    s.alpha = mask.astype(np.float64)
    s.rough = np.full(n, 0.9)
    return s


def fence(W, rails=True):
    p = Part("fence_rail" if rails else "fence_post")
    x0 = -W / 2
    p.box((x0, 0.0, 0.4), (0.12, 0.12, 0.8), "log", bevel=0.025)
    p.box((x0, 0.0, 0.81), (0.14, 0.14, 0.03), "log", bevel=0.01)
    if rails:
        for z in (0.35, 0.64):
            r = p.box((0.0, 0.0, z), (W, 0.07, 0.1), "log", bevel=0.02)
            for v in {v for f in r for v in f.verts}:
                v.co.z += 0.012 * math.sin(v.co.x * 2.1 + z * 5.0)
    return p


def build():
    return [
        kit("rock_a", [_rock("rock_a", 11, (2.4, 2.0, 1.6))], {"rock": _rock_mat}, built_final=True,
            organic=("rock_a",), ao_dist=0.5),
        kit("rock_b", [_rock("rock_b", 23, (2.2, 2.0, 1.3))], {"rock": _rock_mat}, built_final=True,
            organic=("rock_b",), ao_dist=0.5, preview=False),
        kit("dead_tree", [dead_tree()], {"bark": _bark}, built_final=True, ao_dist=0.4),
        kit("grass_tuft", [grass_tuft()], {"blades": _blades}, built_final=True, ppm=256, ao_rays=0, pad=2),
        kit("fence_rail_2m", [fence(2.0)], {"log": M.wood_oak}, built_final=True, ppm=128, ao_dist=0.2),
        kit("fence_rail_1m", [fence(1.0)], {"log": M.wood_oak}, built_final=True, ppm=128, ao_dist=0.2,
            preview=False),
        kit("fence_post", [fence(0.0, rails=False)], {"log": M.wood_oak}, built_final=True, ppm=128, ao_dist=0.2,
            preview=False),
    ]
