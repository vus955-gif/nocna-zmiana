"""The floating bust enemy: the gallery's Roman portrait bust, torn off its
socle. The marble is cracked through the chest, neck and one side of the
face, and the cracks glow from inside (an emissive mask: faint at rest, the
game raises the emission for the attack telegraph). A broken chunk of the
turned socle hovers under the chest.

Faces +Y in Blender = -Z in Godot. Origin at the centre of the flat chest
cut (hover height is up to the game: the design floats it 1.6 m up).
Parts (Godot node names):
    bust    (0, 0, 0)      head and chest, one piece       root
    plinth  (0, 0, -0.10)  the hovering socle fragment      root
Head centre (face weak point) at about (0, 0, 0.33); face front at y 0.11.
"""
import math
import random

import numpy as np
from mathutils import Matrix, Vector

from artlib import materials as M
from artlib import sculpt
from artlib.geo import Part
from artlib.model import Model
from models import bust as base

CUT = base.SOCLE + 0.035        # the original bust's chest cut height
HEAD_C = (0.0, 0.0, 0.33)
CRACK_SEED = 3


# crack polylines in (angle round the vertical axis in degrees, height m):
# 0 deg = the front (+Y), negative = the bust's left (-X)
CRACKS = [
    [(10, 0.0), (6, 0.07), (-7, 0.13), (-3, 0.19), (-16, 0.25), (-22, 0.3), (-17, 0.365), (-9, 0.42)],
    [(10, 0.0), (32, 0.06), (58, 0.1), (84, 0.075), (110, 0.1)],
    [(6, 0.07), (-28, 0.05), (-58, 0.035), (-80, 0.07)],
    [(-7, 0.13), (-34, 0.16), (-48, 0.21)],
    [(-22, 0.3), (-40, 0.28)],
    [(165, 0.0), (175, 0.09), (168, 0.16), (182, 0.22)],
    [(20, -0.07), (45, -0.1), (70, -0.12)],
    [(200, -0.07), (230, -0.11)],
]


def _jagged(line, rng, depth=3):
    pts = [(math.radians(a), z) for a, z in line]
    for _ in range(depth):
        out = [pts[0]]
        for (a0, z0), (a1, z1) in zip(pts, pts[1:]):
            L = math.hypot((a1 - a0) * 0.12, z1 - z0)
            out.append(((a0 + a1) / 2 + rng.uniform(-1, 1) * L * 1.8, (z0 + z1) / 2 + rng.uniform(-1, 1) * L * 0.2))
            out.append((a1, z1))
        pts = out
    return pts


def _cracks(ctx):
    """Distance of each texel to the crack polylines, measured on the
    surface (angle x radius, height). Returns (core, halo) masks."""
    rng = random.Random(CRACK_SEED)
    x, y, z = ctx.p[:, 0], ctx.p[:, 1], ctx.p[:, 2]
    theta = np.arctan2(x, y)
    rho = np.maximum(np.hypot(x, y), 0.03)
    best = np.full(ctx.N, np.inf)
    for line in CRACKS:
        pts = _jagged(line, rng)
        for (a0, z0), (a1, z1) in zip(pts, pts[1:]):
            da = np.angle(np.exp(1j * (theta - a0)))           # wrapped angle difference
            px, pz = da * rho, z - z0
            sx, sz = (a1 - a0) * rho, np.full(ctx.N, z1 - z0)
            L2 = np.maximum(sx * sx + sz * sz, 1e-9)
            t = np.clip((px * sx + pz * sz) / L2, 0.0, 1.0)
            d = np.hypot(px - t * sx, pz - t * sz)
            best = np.minimum(best, d)
    flat = np.abs(ctx.n[:, 2]) < 0.97                       # not on the flat cut faces
    core = (best < ctx.texel * 0.9) & flat
    halo = (best < ctx.texel * 2.6) & ~core & flat
    return core, halo


def marble_cracked(ctx):
    s = M.marble_statuary(ctx)
    core, halo = _cracks(ctx)
    s.use_ramp(M.P["ember"], mask=core, shade=4.2 + ctx.fbm(40.0, 2, 7) * 1.2 + M._dither(ctx, 1.0, 8))
    s.shade[halo] -= 2.0
    s.rough = np.where(core, 0.6, s.rough)
    s.height = s.height - core * 0.0018 - halo * 0.0006
    emit = np.zeros((ctx.N, 3))
    emit[core] = s.colors()[core] * 0.8
    emit[halo] = M.P["ember"][3] * 0.35
    s.emit = emit
    return s


def _plinth(p):
    rng = random.Random(7)
    faces = p.lathe([(0.05, -0.13), (0.052, -0.11), (0.07, -0.09), (0.082, -0.075), (0.078, -0.068),
                     (0.0, -0.066)], "marble", segments=16, cap_bottom=True, smooth=False)
    # broken bottom: jitter the lowest ring and tilt the break
    # sorted: a set of BMVerts iterates in memory order, and each vertex draws from the RNG
    for v in sorted({v for f in faces for v in f.verts}, key=lambda v: tuple(v.co)):
        if v.co.z < -0.12:
            v.co.z += rng.uniform(-0.012, 0.016) + v.co.x * 0.2
    return faces


def build():
    rng = random.Random(4)
    me = sculpt.metaball_mesh(base._head_blobs(rng), resolution=0.0045)
    sculpt.cut(me, [((0, 0, CUT), (0, 0, -1)), ((0.18, 0, 0), (1, 0, 0)), ((-0.18, 0, 0), (-1, 0, 0))])
    me = sculpt.decimate(me, 7000)
    p = Part("bust")
    # the prop faces -Y: turn it to face +Y (enemy forward) and drop the cut to z = 0
    sculpt.into_part(p, me, "marble", transform=Matrix.Rotation(math.pi, 4, 'Z') @ Matrix.Translation((0, 0, -CUT)))
    plinth = Part("plinth", origin=(0, 0, -0.1))
    _plinth(plinth)
    fns = {"marble": marble_cracked}
    m = Model("bust_enemy", [p, plinth], fns, ppm=256, organic=("bust",), ao_dist=0.12, ao_rays=16, ao_stride=1,
              front=1, preview_closeup=((0.0, 0.06, 0.3), 0.15), preview_elevation=8.0)
    return m
