"""Pies Fu z brązu, the Asia wing's signature enemy: a bronze guardian lion
(shishi) 1.6 m at the shoulder, the male of a temple pair - the right
forepaw on the embroidered ball (the world under his rule), a loose stone
pearl rolling in the open mouth (the weak point; it glows before the
roar). Bulging round eyes, a broad flat nose, fangs, a mane of rows of
spiral curls down to the chest, curly flame tufts at the elbows and hocks,
a collar of bronze with a bell and ribbon tassels, a plume of a tail.
Archaic bronze: green-grey patina, the crust pale in the curls, the bronze
rubbed warm and bright on the head, the paws and the ball (centuries of
hands).

Faces +Y in Blender = -Z in Godot. Origin on the floor under the body.
Parts (Godot names), pivots at the joints (Blender x, y, z):
    body                      (0, 0, 1.10)        root
    head                      (0, 0.85, 1.55)     neck              child of body
    jaw                       (0, 1.12, 1.6)      jaw hinge         child of head
    pearl                     (0, 1.33, 1.57)     the stone pearl in the mouth (glow it)  child of head
    leg_fl / leg_fr           (-/+0.30, 0.6, 1.05)  shoulders        children of body
    shin_fl / shin_fr         elbows                                children of leg_fl / leg_fr
    leg_bl / leg_br           (-/+0.30, -0.85, 1.05)  hips           children of body
    shin_bl / shin_br         hocks                                 children of leg_bl / leg_br
    tail                      (0, -1.05, 1.32)    tail root         child of body
    ball                      the embroidered ball under the right forepaw: a ROOT
                              part (leave it on the plinth when the lion wakes)
Markers: mouth_ball (child of head, the pearl's centre: weak point), roar
(child of head, in front of the open mouth: the roar cone starts here and
opens along the head's forward axis).
Rest pose: standing, head up, the mouth open on the pearl, the right
forepaw raised onto the ball.
"""
import math

import numpy as np
from mathutils import Matrix, Vector

from artlib import asia as A
from artlib import kit as K
from artlib import materials as M
from artlib import sculpt
from artlib.geo import Part
from artlib.kit import R, T
from artlib.materials import P, _dither, smoothstep
from artlib.model import Model
from artlib.painter import Surface
from artlib.sculpt import blob, limb

ORDER = ["body", "head", "jaw", "pearl", "leg_fl", "leg_fr", "shin_fl", "shin_fr", "leg_bl", "leg_br", "shin_bl",
         "shin_br", "tail", "ball"]
IDX = {n: i for i, n in enumerate(ORDER)}
NECK = (0.0, 0.85, 1.55)
HINGE = (0.0, 1.15, 1.6)
PEARL = (0.0, 1.4, 1.57)
SHOULDER = {-1: (-0.3, 0.6, 1.05), 1: (0.3, 0.6, 1.05)}
ELBOW = {-1: (-0.33, 0.66, 0.6), 1: (0.34, 0.86, 0.78)}
FPAW = {-1: (-0.33, 0.74, 0.08), 1: (0.35, 1.05, 0.58)}
HIP = {-1: (-0.3, -0.85, 1.05), 1: (0.3, -0.85, 1.05)}
HOCK = {-1: (-0.33, -1.08, 0.48), 1: (0.33, -1.08, 0.48)}
BPAW = {-1: (-0.33, -0.92, 0.08), 1: (0.33, -0.92, 0.08)}
BALL_C = (0.36, 1.06, 0.29)
BALL_R = 0.29


def _clay(part, blobs, tris, slot="bronze", res=0.03, cut=None):
    me = sculpt.metaball_mesh(blobs, resolution=res)
    if cut:
        sculpt.cut(me, cut)
    me = sculpt.decimate(me, tris)
    sculpt.into_part(part, me, slot)


def _curl(p, c, r, slot="curl", up=(0.0, 0.0, 1.0), seg=6):
    """A spiral curl knob (a squashed dome)."""
    f = p.lathe([(r, 0.0), (r * 0.85, r * 0.32), (r * 0.45, r * 0.52), (r * 0.1, r * 0.58)],
                slot, segments=seg, cap_bottom=False, cap_top=True)
    p.move(f, T(*c) @ Vector(up).normalized().to_track_quat('Z', 'Y').to_matrix().to_4x4())
    return f


def body():
    p = Part("body", origin=(0.0, 0.0, 1.1))
    b = [blob((0.0, 0.5, 1.15), (0.42, 0.42, 0.52)),         # chest
         blob((0.0, 0.15, 1.18), (0.44, 0.52, 0.44)),        # ribs
         blob((0.0, -0.4, 1.14), (0.37, 0.45, 0.36)),        # loin
         blob((0.0, -0.82, 1.16), (0.42, 0.34, 0.42)),       # haunches
         blob((0.0, 0.7, 1.42), (0.34, 0.3, 0.3)),           # neck root
         blob((0.0, 0.55, 0.85), (0.3, 0.25, 0.25))]         # brisket
    for sx in (-1, 1):
        b.append(blob((sx * 0.28, 0.58, 1.08), (0.18, 0.28, 0.32)))   # shoulders
        b.append(blob((sx * 0.28, -0.85, 1.08), (0.2, 0.3, 0.34)))    # thighs
    _clay(p, b, 1600, res=0.035)
    # collar: a bronze band round the neck, a bell at the front, ribbons
    col = p.lathe([(0.37, -0.04), (0.4, 0.0), (0.37, 0.04)], "bronze", segments=20, squash=(1.0, 0.9),
                  cap_bottom=False, cap_top=False)
    p.move(col, T(0.0, 0.78, 1.3) @ R('X', 35))
    bell = p.lathe([(0.0, 0.0), (0.09, 0.01), (0.1, 0.06), (0.07, 0.12), (0.02, 0.14)], "bronze", segments=10,
                   cap_top=True)
    p.move(bell, T(0.0, 1.0, 0.9))
    for sx in (-1, 1):
        p.tube([(sx * 0.12, 0.98, 1.12), (sx * 0.22, 1.0, 0.95), (sx * 0.24, 0.97, 0.75)], lambda t: 0.035 - 0.015 * t,
               "bronze", sides=5)
    # curls of the mane on the chest and the back of the neck
    for k in range(9):
        a = math.radians(-60 + k * 15)
        c = (math.sin(a) * 0.36, 0.86 + math.cos(a) * 0.12, 1.28 + 0.05 * math.cos(a * 2))
        _curl(p, c, 0.075, up=(math.sin(a), 0.8, 0.3))
    for k in range(5):
        _curl(p, (-0.2 + k * 0.1, 0.55, 1.62), 0.07, up=(0.0, -0.4, 1.0))
    return p


def head():
    p = Part("head", origin=NECK, parent="body")
    b = [blob((0.0, 1.1, 1.8), (0.33, 0.3, 0.3)),            # cranium
         blob((0.0, 1.32, 1.76), (0.31, 0.17, 0.25)),        # the broad flat face
         blob((0.0, 1.42, 1.69), (0.24, 0.12, 0.1)),         # upper muzzle
         blob((0.0, 1.53, 1.75), (0.12, 0.07, 0.07)),        # broad nose
         blob((0.0, 0.95, 1.65), (0.3, 0.26, 0.28))]         # back of the head into the neck
    for sx in (-1, 1):
        b.append(blob((sx * 0.15, 1.42, 1.94), (0.12, 0.08, 0.06)))     # heavy brows
        b.append(blob((sx * 0.24, 1.36, 1.68), (0.11, 0.12, 0.12)))     # puffed cheeks
        b.append(blob((sx * 0.05, 1.58, 1.74), (0.025, 0.03, 0.025), neg=True, stiff=1.6))   # nostrils
    b.append(blob((0.0, 1.47, 1.6), (0.2, 0.14, 0.06), neg=True, stiff=1.4))   # the open mouth
    _clay(p, b, 1700, res=0.022)
    for sx in (-1, 1):
        K.sphere(p, (sx * 0.14, 1.47, 1.85), 0.075, "eye", segments=12, rings=7)            # bulging eyes
        f = p.box((0.0, 0.0, 0.0), (0.13, 0.04, 0.11), "bronze", bevel=0.02)                 # folded ears
        p.move(f, T(sx * 0.31, 1.05, 1.95) @ R('Y', sx * 40) @ R('X', -20))
        K.cone(p, (sx * 0.11, 1.5, 1.64), (0.0, 0.15, -1.0), 0.1, 0.026, "tooth", segments=5, tip=0.004)
        for k in range(2):
            K.cone(p, (sx * (0.035 + k * 0.03), 1.53, 1.65), (0.0, 0.05, -1.0), 0.045, 0.014, "tooth", segments=4,
                   tip=0.003)
    # the mane: rows of flat spiral curls round the back and sides of the head
    for row, (rz, n, r) in enumerate(((2.02, 7, 0.3), (1.9, 9, 0.36), (1.76, 11, 0.4), (1.62, 11, 0.4),
                                      (1.48, 9, 0.36))):
        for k in range(n):
            a = math.radians(-118 + 236 * k / (n - 1))
            c = (math.sin(a) * r, 1.02 - math.cos(a) * r * 0.78, rz)
            _curl(p, c, 0.072, up=(math.sin(a), -math.cos(a) * 0.8, 0.35))
    for k in range(4):
        _curl(p, (-0.12 + k * 0.08, 1.3, 2.06), 0.055, up=(0.0, 0.4, 1.0))
    return p


def jaw():
    p = Part("jaw", origin=HINGE, parent="head")
    b = [blob((0.0, 1.38, 1.5), (0.2, 0.15, 0.06)), blob((0.0, 1.24, 1.53), (0.25, 0.1, 0.08)),
         blob((0.0, 1.5, 1.48), (0.15, 0.05, 0.05))]
    _clay(p, b, 500, res=0.02)
    for sx in (-1, 1):
        K.cone(p, (sx * 0.11, 1.48, 1.52), (0.0, 0.1, 1.0), 0.09, 0.024, "tooth", segments=5, tip=0.004)
    for k in range(3):
        _curl(p, (-0.09 + k * 0.09, 1.38, 1.42), 0.06, up=(0.0, 0.4, -1.0))
    return p


def pearl():
    p = Part("pearl", origin=PEARL, parent="head")
    K.sphere(p, PEARL, 0.085, "pearl", segments=12, rings=8)
    return p


def _limb_part(name, origin, parent, pts, radii, tris, extra=()):
    p = Part(name, origin=origin, parent=parent)
    b = limb(pts, radii, spacing=0.7) + list(extra)
    _clay(p, b, tris, res=0.028)
    return p


def legs():
    out = []
    for sx in (-1, 1):
        tag = "l" if sx < 0 else "r"
        sh, el, paw = SHOULDER[sx], ELBOW[sx], FPAW[sx]
        up = _limb_part(f"leg_f{tag}", sh, "body", [sh, el], [0.22, 0.17], 420,
                        [blob((sh[0], sh[1], sh[2] - 0.12), (0.2, 0.26, 0.3))])
        # flame tuft at the elbow
        for k in range(3):
            _curl(up, (el[0] + sx * 0.04, el[1] - 0.12 - k * 0.05, el[2] + 0.06 - k * 0.07), 0.05,
                  up=(sx * 0.6, -1.0, 0.0))
        lo = _limb_part(f"shin_f{tag}", el, f"leg_f{tag}", [el, paw], [0.15, 0.13], 380,
                        [blob((paw[0], paw[1] + 0.07, paw[2] + 0.03), (0.17, 0.22, 0.1))])
        for k in range(4):
            K.cone(lo, (paw[0] - 0.09 + k * 0.06, paw[1] + 0.24, paw[2]), (0.0, 1.0, -0.5), 0.05, 0.02, "tooth",
                   segments=4, tip=0.003)
        out += [up, lo]
    for sx in (-1, 1):
        tag = "l" if sx < 0 else "r"
        hp, hk, paw = HIP[sx], HOCK[sx], BPAW[sx]
        up = _limb_part(f"leg_b{tag}", hp, "body", [hp, (hp[0] * 1.05, hp[1] + 0.12, hp[2] - 0.32), hk],
                        [0.26, 0.22, 0.15], 460)
        for k in range(3):
            _curl(up, (hk[0] + sx * 0.03, hk[1] - 0.08, hk[2] + 0.12 - k * 0.08), 0.05, up=(sx * 0.6, -1.0, 0.2))
        lo = _limb_part(f"shin_b{tag}", hk, f"leg_b{tag}", [hk, paw], [0.14, 0.12], 340,
                        [blob((paw[0], paw[1] + 0.08, paw[2] + 0.03), (0.17, 0.22, 0.1))])
        for k in range(4):
            K.cone(lo, (paw[0] - 0.09 + k * 0.06, paw[1] + 0.25, paw[2]), (0.0, 1.0, -0.5), 0.05, 0.02, "tooth",
                   segments=4, tip=0.003)
        out += [up, lo]
    return out


def tail():
    p = Part("tail", origin=(0.0, -1.05, 1.32), parent="body")
    b = limb([(0.0, -1.05, 1.32), (0.0, -1.2, 1.55), (0.0, -1.2, 1.8)], [0.12, 0.13, 0.15], spacing=0.7)
    _clay(p, b, 300, res=0.03)
    # the plume: a fan of curls rising and curling forward
    for ring, (rr, zz, n) in enumerate(((0.26, 1.85, 11), (0.17, 2.0, 7), (0.08, 2.1, 4))):
        for k in range(n):
            a = math.radians(-100 + k * 200 / max(1, n - 1))
            c = (math.sin(a) * rr, -1.22 + math.cos(a) * 0.08 - ring * 0.04, zz + math.cos(a) * rr * 0.6)
            _curl(p, c, 0.09 - ring * 0.012, up=(math.sin(a), -0.4, math.cos(a)))
    return p


def ball():
    p = Part("ball", origin=BALL_C)
    K.sphere(p, BALL_C, BALL_R, "ball", segments=16, rings=10)
    # ribbons tied round it
    for k in range(3):
        f = p.lathe([(BALL_R + 0.01, -0.025), (BALL_R + 0.025, 0.0), (BALL_R + 0.01, 0.025)], "ball", segments=16,
                    cap_bottom=False, cap_top=False)
        p.move(f, T(*BALL_C) @ R('Z', 60 * k) @ R('X', 90))
    return p


# --------------------------------------------------------------------------
# paint
# --------------------------------------------------------------------------

def _rub(ctx):
    """Where hands have polished the bronze: the top of the head, the brows,
    the nose, the paws, the whole ball."""
    head = ctx.part == IDX["head"]
    up = ctx.n[:, 2]
    r = np.zeros(ctx.N)
    r = np.where(head & (up > 0.8), 0.9, r)
    r = np.where(head & (ctx.p[:, 1] > 1.62) & (ctx.p[:, 2] > 1.75), 0.8, r)
    paws = np.isin(ctx.part, [IDX["shin_fl"], IDX["shin_fr"], IDX["shin_bl"], IDX["shin_br"]]) & (ctx.p[:, 2] < 0.2)
    r = np.where(paws & (up > 0.2), 0.75, r)
    r = np.where(ctx.part == IDX["ball"], 0.85, r)
    return r * (ctx.fbm(6.0, 2, 3) > -0.4)


def bronze(ctx, seed=2001):
    head = ctx.part == IDX["head"]
    rub = np.maximum(_rub(ctx), np.where(head, np.clip(ctx.curv * 1.3, 0, 1) * 0.7, 0.0))
    s = A.bronze_patina(ctx, seed, crust=0.9, polish=0.35, rubbed=rub, dark=-0.05)
    return s


def curl(ctx, seed=2011):
    """Curls: a spiral groove cut in each knob, crust in the groove."""
    s = A.bronze_patina(ctx, seed, crust=1.3, polish=0.6, rubbed=_rub(ctx), dark=0.0)
    a = np.arctan2(ctx.n[:, 1], ctx.n[:, 0])
    spiral = np.sin(a * 2.0 + ctx.n[:, 2] * 14.0) > 0.6
    s.shade[spiral] -= 1.6
    s.height = s.height - spiral * 0.003
    return s


def eye(ctx, seed=2021):
    """Bulging eyes: polished bronze balls with an incised ring and a dark
    pupil drilled in."""
    s = A.bronze_patina(ctx, seed, crust=0.3, polish=1.0, rubbed=np.full(ctx.N, 0.7))
    fwd = ctx.n[:, 1]
    pupil = fwd > 0.86
    ring = (fwd > 0.7) & ~pupil
    s.use_ramp(P["bronze_dark"], mask=pupil, shade=np.full(ctx.N, 0.6))
    s.shade[ring] -= 1.4
    s.height = s.height - pupil * 0.004
    return s


def pearl_paint(ctx, seed=2031):
    """A rolled stone pearl, gold-white, with a faint inner ember (the game
    raises its emission before the roar)."""
    s = Surface(ctx.N)
    s.use_ramp(P["ivory"], shade=5.4 + ctx.fbm(10.0, 2, seed) * 0.8 + ctx.n[:, 2] * 0.8 - (1.0 - ctx.ao) * 2.0)
    s.rough = np.full(ctx.N, 0.3)
    glow = np.clip(ctx.fbm(14.0, 2, seed + 1) + 0.4, 0.0, 1.0)
    s.emit = (np.array(P["ember"][5]) * glow[:, None] * 0.6)
    return s


def ball_paint(ctx, seed=2041):
    """The embroidered ball: a lattice of hexagons in relief, rubbed bright
    where the paw rests."""
    s = A.bronze_patina(ctx, seed, crust=0.6, polish=0.6, rubbed=np.full(ctx.N, 0.6), dark=0.1)
    q = ctx.p - np.array(BALL_C)
    a = np.arctan2(q[:, 1], q[:, 0])
    el = np.arcsin(np.clip(q[:, 2] / max(BALL_R, 1e-6), -1, 1))
    hexes = (np.abs(np.sin(a * 6.0) * np.cos(el * 6.0)) > 0.92) | (np.abs(np.sin(el * 6.0 + a * 3.0)) > 0.95)
    s.shade[hexes] -= 1.5
    s.height = s.height - hexes * 0.002
    return s


HEAD_S = 1.32           # the head is sculpted small, then scaled about the neck


def _hs(v):
    n = Vector(NECK)
    return tuple(n + (Vector(v) - n) * HEAD_S)


def build():
    parts = {p.name: p for p in [body(), head(), jaw(), pearl(), tail(), ball()] + legs()}
    for name in ("head", "jaw", "pearl"):
        prt = parts[name]
        prt.move(list(prt.bm.faces), T(*NECK) @ Matrix.Scale(HEAD_S, 4) @ T(*(-Vector(NECK))))
        prt.origin = Vector(_hs(prt.origin))
    ordered = [parts[n] for n in ORDER]
    fns = {"bronze": bronze, "curl": curl, "eye": eye, "tooth": lambda c: A.bronze_patina(c, 2051, crust=0.2,
                                                                                          polish=1.0),
           "pearl": pearl_paint, "ball": ball_paint}
    organic = ("body", "head", "jaw", "leg_fl", "leg_fr", "shin_fl", "shin_fr", "leg_bl", "leg_br", "shin_bl",
               "shin_br", "tail")
    roar = _hs((0.0, 1.55, 1.6))
    return Model("fu_dog", ordered, fns, ppm=192, organic=organic, ground=0.0, ao_dist=0.25, ao_rays=12,
                 ao_stride=2, front=1, normal_strength=2.0,
                 markers=[("mouth_ball", _hs(PEARL), "head"), ("roar", roar, "head")],
                 preview_yaws=(-40.0, 40.0, 110.0, 210.0), preview_elevation=10.0,
                 preview_closeup=(_hs((0.0, 1.2, 1.72)), 0.7))
