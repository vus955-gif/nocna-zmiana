"""The guardian of the Greek wing: the Centaur from the Metope. A centaur
of the Parthenon's south metopes torn out of his slab - one flank still
carries a broken piece of the metope's background (blue-painted, the edges
fresh and sugary), the far side is flat and tooled like the back of a high
relief. Marble with honey patina; through the cracked chest a hot glow
(the weak point); bearded, wild-haired, satyr ears; a panther skin over
his left arm; a javelin cocked over the right shoulder.

Faces +Y in Blender = -Z in Godot. Origin on the floor under the middle of
the horse body. About 2.9 m to the top of the head, 2.6 m long. Parts
(Godot node names) with pivots at the joints:
    barrel        (0, 0, 1.25)         the horse body           root
    leg_fl/_fr    (-/+0.2, 0.62, 1.02) shoulders: forearm        children of barrel
    knee_fl/_fr   (-/+0.2, 0.66, 0.56) knees: cannon             children of leg_f*
    hoof_fl/_fr   (-/+0.2, 0.68, 0.17) fetlocks: pastern, hoof   children of knee_f*
    leg_bl/_br    (-/+0.22, -0.7, 1.05) hips (stifle): gaskin    children of barrel
    knee_bl/_br   (-/+0.22, -0.9, 0.58) hocks: cannon            children of leg_b*
    hoof_bl/_br   (-/+0.22, -0.84, 0.17) fetlocks: pastern, hoof children of knee_b*
    tail_1        (0, -1.08, 1.55)     tail root                 child of barrel
    tail_2        (0, -1.32, 1.2)      tail middle               child of tail_1
    torso         (0, 0.66, 1.62)      the man's waist           child of barrel
    neck          (0, 0.74, 2.42)      neck: head, beard, hair   child of torso
    arm_l, arm_r  (-/+0.34, 0.68, 2.3) shoulders                 children of torso
    forearm_l/_r  elbows                                         children of arm_*
    wrist_l/_r    wrists (the hands)                             children of forearm_*
    javelin       (0.42, 0.78, 2.62)   grip, point along +Y      child of wrist_r
    slab          the metope fragment on the left flank          child of barrel
Markers: chest (weak point, the cracked breast), head (centre of the head),
hand_r (the javelin grip; child of wrist_r). The spare javelin to throw is
the model ``javelin`` (origin at its balance point, point along -Z, marker
``tip``).
"""
import math

import numpy as np
from mathutils import Matrix, Vector

from artlib import greek as GK
from artlib import kit as K
from artlib import materials as M
from artlib.geo import Part
from artlib.kit import R, T
from artlib.model import Model
from artlib.statue import sculpt_into
from models.gr_pediment import Pose

V = Vector
I = Pose(0.0, 0.0, 0.0, k=1.0)          # identity: model space
CHEST = (0.0, 0.92, 2.12)
HEAD = (0.0, 0.8, 2.66)
SH_L, SH_R = V((-0.34, 0.68, 2.3)), V((0.34, 0.68, 2.3))
EL_L, WR_L = V((-0.5, 0.82, 2.0)), V((-0.42, 1.08, 1.86))
EL_R, WR_R = V((0.6, 0.6, 2.48)), V((0.46, 0.74, 2.66))
GRIP = V((0.42, 0.78, 2.62))
JAV_FWD, JAV_BACK = 1.25, 0.95


def _barrel(p):
    b = [I.b((0, -0.1, 1.25), (0.41, 0.78, 0.39)),
         I.b((0, 0.55, 1.28), (0.37, 0.28, 0.43)),             # chest of the horse
         I.b((0, -0.75, 1.36), (0.4, 0.35, 0.38)),             # hindquarters
         I.b((0, -0.2, 1.52), (0.3, 0.6, 0.12)),               # back
         I.b((0, 0.2, 0.98), (0.26, 0.45, 0.12)),              # belly
         I.b((0, 0.62, 1.62), (0.27, 0.22, 0.2))]              # withers rising into the man
    for sx in (-1, 1):
        b.append(I.b((sx * 0.22, 0.5, 1.24), (0.14, 0.2, 0.3), rot=(15, 0, 0)))     # shoulders
        b.append(I.b((sx * 0.24, -0.72, 1.3), (0.15, 0.3, 0.32)))                    # haunches
        b.append(I.b((sx * 0.3, 0.0, 1.22), (0.05, 0.5, 0.2), stiff=1.4))            # ribs swell
    b.append(I.b((0, 0.0, 0.92), (0.2, 0.4, 0.05), neg=True, stiff=1.2))             # belly line
    sculpt_into(p, b, "horse", res=0.018, tris=3000)


def _slab(p):
    """A broken piece of the metope's background still on the left flank:
    flat, its back tooled, its edges fresh fractures."""
    pts = [(-0.85, 0.9), (-0.45, 0.72), (0.05, 0.8), (0.5, 0.66), (0.72, 1.05), (0.62, 1.55), (0.3, 1.95),
           (-0.15, 1.82), (-0.55, 1.98), (-0.9, 1.5)]
    faces = p.ngon_prism([(y, z) for y, z in pts], 0.0, 0.1, "slab", bevel=0.01)
    # the prism stands in the y-z plane on the left side (x = -0.32 .. -0.42)
    p.move(faces, T(-0.32, 0.0, 0.0) @ Matrix(((0, 0, -1, 0), (1, 0, 0, 0), (0, 1, 0, 0), (0, 0, 0, 1))))
    for f in faces:
        f.normal_flip()              # the placement above is a reflection
        f.normal_update()
        if abs(f.normal.x) < 0.5:
            f.material_index = p.slot("break")


def _leg(p, sx, fore, seg):
    """One segment of a leg: seg 0 upper, 1 cannon, 2 pastern and hoof."""
    if fore:
        pts = [V((sx * 0.2, 0.62, 1.02)), V((sx * 0.2, 0.66, 0.56)), V((sx * 0.2, 0.68, 0.17)),
               V((sx * 0.2, 0.75, 0.05))]
        radii = [0.16, 0.08, 0.072, 0.062]
    else:
        pts = [V((sx * 0.22, -0.7, 1.05)), V((sx * 0.22, -0.9, 0.58)), V((sx * 0.22, -0.84, 0.17)),
               V((sx * 0.22, -0.76, 0.05))]
        radii = [0.18, 0.085, 0.072, 0.062]
    a, b = pts[seg], pts[seg + 1]
    blobs = I.limb([tuple(a), tuple(b)], [radii[seg], radii[seg + 1]])
    if seg == 0:
        blobs.append(I.b(tuple(a + V((0, 0.0, 0.1))), (0.13, 0.2, 0.2)))           # muscle mass at the top
    if seg in (0, 1):
        blobs.append(I.b(tuple(b), 0.085 if seg == 0 else 0.08))                   # knee / fetlock knob
    if seg == 2:
        hoof = p.lathe([(0.085, 0.0), (0.085, 0.03), (0.07, 0.1), (0.05, 0.12)], "hoof", segments=10,
                       squash=(0.9, 1.1))
        p.move(hoof, T(b.x, b.y + 0.02, 0.0))
    sculpt_into(p, blobs, "horse", res=0.014, tris=500 if seg else 700)


def _tail(p, seg):
    pts = [V((0, -1.08, 1.55)), V((0, -1.32, 1.2)), V((0, -1.36, 0.7))]
    a, b = pts[seg], pts[seg + 1]
    blobs = I.limb([tuple(a), tuple(b)], [0.09 if seg == 0 else 0.11, 0.11 if seg == 0 else 0.07])
    sculpt_into(p, blobs, "tail", res=0.016, tris=500)


def _torso(p):
    b = [I.b((0, 0.66, 1.7), (0.24, 0.2, 0.16)),                     # hips merging into the withers
         I.b((0, 0.7, 1.9), (0.22, 0.17, 0.16)),                     # abdomen
         I.b((0, 0.72, 2.12), (0.28, 0.2, 0.2))]                     # rib cage
    for sx in (-1, 1):
        b.append(I.b((sx * 0.12, 0.86, 2.17), (0.14, 0.045, 0.075), rot=(0, 0, sx * -8)))   # pectorals (flat)
        b.append(I.b((sx * 0.065, 0.85, 1.93), (0.055, 0.03, 0.11), stiff=1.4))
        b.append(I.b((sx * 0.19, 0.8, 1.86), (0.05, 0.04, 0.1), stiff=1.3))   # obliques
        b.append(I.b((sx * 0.3, 0.68, 2.3), (0.12, 0.11, 0.1)))      # deltoids
        b.append(I.b((sx * 0.18, 0.62, 2.36), (0.12, 0.08, 0.08)))   # trapezius
    b.append(I.b((0, 0.9, 2.0), (0.14, 0.03, 0.03), neg=True, stiff=1.2))     # the abdominal arch
    sculpt_into(p, b, "skin", res=0.014, tris=2400)


def _head(p):
    hc = V(HEAD)
    b = [I.b((0, 0.73, 2.47), (0.1, 0.1, 0.12)),                    # neck
         I.b(tuple(hc), (0.13, 0.14, 0.16)),                        # skull
         I.b(tuple(hc + V((0, 0.08, -0.05))), (0.1, 0.08, 0.11)),   # face
         I.b(tuple(hc + V((0, 0.15, -0.03))), (0.025, 0.04, 0.05), rot=(-15, 0, 0)),   # nose
         I.b(tuple(hc + V((0, 0.12, 0.05))), (0.11, 0.04, 0.03))]   # heavy brow
    for sx in (-1, 1):
        b.append(I.b(tuple(hc + V((sx * 0.05, 0.14, 0.02))), (0.025, 0.015, 0.015), neg=True, stiff=1.5))
        b.append(I.b(tuple(hc + V((sx * 0.14, 0.0, 0.06))), (0.02, 0.05, 0.07), rot=(30, sx * 20, 0)))   # ears
    # beard: a mass of curls from the cheeks to below the chin
    rng = np.random.default_rng(3)
    for k in range(26):
        a = rng.uniform(-1.2, 1.2)
        z = rng.uniform(-0.22, -0.02)
        c = hc + V((math.sin(a) * 0.11, 0.06 + math.cos(a) * 0.07, z - 0.05))
        b.append(I.b(tuple(c), rng.uniform(0.035, 0.05), stiff=1.7))
    # hair: wild curls over the skull and the nape
    for k in range(40):
        u, v = rng.uniform(0, math.tau), rng.uniform(-0.2, 1.0)
        n = V((math.cos(u) * math.sqrt(1 - v * v), math.sin(u) * math.sqrt(1 - v * v), v)).normalized()
        if n.y > 0.55 and n.z < 0.5:
            continue
        b.append(I.b(tuple(hc + V((n.x * 0.14, n.y * 0.14 - 0.01, n.z * 0.15))), rng.uniform(0.04, 0.055), stiff=1.7))
    sculpt_into(p, b, "skin", res=0.011, tris=2600)
    # glowing eyes in deep sockets
    for sx in (-1, 1):
        K.sphere(p, tuple(hc + V((sx * 0.05, 0.135, 0.02))), 0.017, "eye", segments=8, rings=4)


def _arm(p, a, b, ra, rb, extra=()):
    blobs = I.limb([tuple(a), tuple(b)], [ra, rb]) + list(extra)
    sculpt_into(p, blobs, "skin", res=0.012, tris=700)


def _panther(p):
    """The panther skin hanging over the left forearm, paws dangling."""
    sk = [I.b(tuple(EL_L + V((0.0, 0.1, -0.05))), (0.12, 0.14, 0.05), rot=(0, 0, 20)),
          I.b(tuple(EL_L + V((-0.05, 0.12, -0.3))), (0.1, 0.05, 0.25)),
          I.b(tuple(EL_L + V((0.08, 0.2, -0.32))), (0.08, 0.04, 0.22)),
          I.b(tuple(EL_L + V((-0.05, 0.14, -0.6))), (0.035, 0.03, 0.06)),     # paw
          I.b(tuple(EL_L + V((0.1, 0.22, -0.58))), (0.035, 0.03, 0.06))]
    sculpt_into(p, sk, "pelt", res=0.012, tris=900)


def _javelin(p, origin, fwd, back):
    g = V(origin)
    K.seg(p, g + V((0, -back, 0)), g + V((0, fwd, 0)), [(0.018, 0.0), (0.02, 0.5), (0.016, 1.0)], "shaft",
          segments=6)
    blade = p.lathe([(0.0, 0.0), (0.03, 0.06), (0.035, 0.14), (0.022, 0.22), (0.0, 0.3)], "bronze", segments=4,
                    squash=(1.0, 0.3), smooth=False, cap_bottom=False)
    p.move(blade, T(*(g + V((0, fwd - 0.02, 0)))) @ R('X', -90))
    tail = p.lathe([(0.02, 0.0), (0.014, 0.1), (0.005, 0.14)], "bronze", segments=6, smooth=False)
    p.move(tail, T(*(g + V((0, -back + 0.02, 0)))) @ R('X', 90))


# --------------------------------------------------------------------------
# paint
# --------------------------------------------------------------------------

def _tooled(ctx, s, seed):
    """Tooth-chisel strokes on the far (flat) side and the slab's back:
    the high relief was never meant to be seen from behind."""
    far = ctx.n[:, 0] > 0.55
    stroke = np.sin(ctx.p[:, 1] * 140.0 + ctx.p[:, 2] * 60.0 + ctx.fbm(4.0, 2, seed) * 3.0) > 0.4
    s.shade -= (far & stroke) * 0.9
    s.height = s.height + (far & stroke) * -0.0012
    return s


def _horse(ctx):
    s = GK.statuary(ctx, seed=2101, center=7.3, patina=1.3)
    return _tooled(ctx, s, 2103)


def _skin(ctx):
    """The man's marble, cracked across the chest: a hot glow inside the
    cracks (the weak point), weaker in hairline cracks on the belly."""
    s = GK.statuary(ctx, seed=2105, center=7.5, patina=1.1)
    d = ctx.p - np.array(CHEST)
    front = ctx.n[:, 1] > 0.2
    near = (np.linalg.norm(d, axis=1) < 0.32) & front
    a = np.arctan2(d[:, 2], d[:, 0])
    rr = np.linalg.norm(d[:, [0, 2]], axis=1)
    # three bold cracks radiating from the breastbone, a few hairline ones
    ray = np.abs(np.mod(a + 0.4 + ctx.fbm(7.0, 2, 2107) * 0.35, math.tau / 3) - math.tau / 6) < 0.09 + rr * 0.05
    crack = near & ray & (rr > 0.03) & (rr < 0.26)
    crack |= near & (np.abs(ctx.fbm(4.0, 3, 2109)) < 0.008) & (rr < 0.14)
    s.use_ramp(M.P["ember"], mask=crack, shade=np.full(ctx.N, 5.5) + (ctx.rand(2111) > 0.6) * 1.5)
    s.height = s.height - crack * 0.003
    glow = np.zeros((ctx.N, 3))
    glow[crack] = s.colors()[crack]
    s.emit = glow
    s.rough = np.where(crack, 0.9, s.rough)
    return _tooled(ctx, s, 2113)


def _eye(ctx):
    s = M.Surface(ctx.N)
    s.use_ramp(M.P["ember"], shade=np.full(ctx.N, 6.0))
    s.emit = s.colors()
    s.rough = np.full(ctx.N, 0.4)
    return s


def _tail_paint(ctx):
    s = GK.statuary(ctx, seed=2121, center=7.0, patina=1.3)
    k = np.sin(ctx.p[:, 0] * 120.0 + ctx.fbm(6.0, 2, 2123) * 2.0)
    s.shade += k * 0.8
    s.height = s.height + k * 0.002
    return s


def _pelt(ctx):
    s = GK.statuary(ctx, seed=2125, center=7.0, patina=1.2)
    f1, _, cid = ctx.worley(24.0, 2127)
    spot = (f1 < 0.3) & (cid > 0.3)
    GK.paint_traces(ctx, s, "gr_ochre", ~spot, 2129, center=3.8, density=0.55, freq=3.0)
    s.shade -= spot * 1.2
    return s


def _slab_paint(ctx):
    s = GK.pentelic(ctx, seed=2131, center=7.2, veins=0.4, patina=1.0, ao=3.0)
    out = ctx.n[:, 0] < -0.5                   # the old relief background (faces outward, left)
    GK.paint_traces(ctx, s, "gr_blue", out, 2133, center=3.4, density=0.45, freq=2.0)
    return _tooled(ctx, s, 2135)


def _hoof(ctx):
    return GK.statuary(ctx, seed=2141, center=6.4, patina=1.4)


def _shaft(ctx):
    return M.wood_oak(ctx, seed=2143)


def _bronze(ctx):
    return M.bronze(ctx, seed=2145)


FNS = {"horse": _horse, "skin": _skin, "eye": _eye, "tail": _tail_paint, "pelt": _pelt, "slab": _slab_paint,
       "break": GK.fracture, "hoof": _hoof, "shaft": _shaft, "bronze": _bronze}


def centaur():
    parts = []
    barrel = Part("barrel", origin=(0, 0, 1.25))
    _barrel(barrel)
    parts.append(barrel)
    for side, sx in (("l", -1), ("r", 1)):
        for fore, tag, piv in ((True, "f", [(sx * 0.2, 0.62, 1.02), (sx * 0.2, 0.66, 0.56), (sx * 0.2, 0.68, 0.17)]),
                               (False, "b", [(sx * 0.22, -0.7, 1.05), (sx * 0.22, -0.9, 0.58),
                                             (sx * 0.22, -0.84, 0.17)])):
            names = ["leg_" + tag + side, "knee_" + tag + side, "hoof_" + tag + side]
            parents = ["barrel", names[0], names[1]]
            for k in range(3):
                q = Part(names[k], origin=piv[k], parent=parents[k])
                _leg(q, sx, fore, k)
                parts.append(q)
    t1 = Part("tail_1", origin=(0, -1.08, 1.55), parent="barrel")
    _tail(t1, 0)
    t2 = Part("tail_2", origin=(0, -1.32, 1.2), parent="tail_1")
    _tail(t2, 1)
    slab = Part("slab", origin=(-0.37, 0.0, 1.2), parent="barrel")
    _slab(slab)
    torso = Part("torso", origin=(0, 0.66, 1.62), parent="barrel")
    _torso(torso)
    neck = Part("neck", origin=(0, 0.74, 2.42), parent="torso")
    _head(neck)
    arm_l = Part("arm_l", origin=tuple(SH_L), parent="torso")
    _arm(arm_l, SH_L, EL_L, 0.09, 0.07)
    fl = Part("forearm_l", origin=tuple(EL_L), parent="arm_l")
    _arm(fl, EL_L, WR_L, 0.07, 0.05)
    _panther(fl)
    wl = Part("wrist_l", origin=tuple(WR_L), parent="forearm_l")
    _arm(wl, WR_L, WR_L + V((0.02, 0.1, -0.02)), 0.05, 0.045, extra=[I.b(tuple(WR_L + V((0.02, 0.12, -0.03))),
                                                                          (0.055, 0.06, 0.04))])
    arm_r = Part("arm_r", origin=tuple(SH_R), parent="torso")
    _arm(arm_r, SH_R, EL_R, 0.09, 0.07)
    fr = Part("forearm_r", origin=tuple(EL_R), parent="arm_r")
    _arm(fr, EL_R, WR_R, 0.07, 0.05)
    wr = Part("wrist_r", origin=tuple(WR_R), parent="forearm_r")
    _arm(wr, WR_R, GRIP, 0.05, 0.05, extra=[I.b(tuple(GRIP), (0.06, 0.07, 0.06))])
    jav = Part("javelin", origin=tuple(GRIP), parent="wrist_r")
    _javelin(jav, GRIP, JAV_FWD, JAV_BACK)
    parts += [t1, t2, slab, torso, neck, arm_l, fl, wl, arm_r, fr, wr, jav]
    organic = tuple(p.name for p in parts if p.name not in ("javelin", "slab"))
    markers = [("chest", CHEST, "torso"), ("head", HEAD, "neck"), ("hand_r", tuple(GRIP), "wrist_r")]
    return Model("centaur", parts, FNS, ppm=112, ground=0.0, ao_dist=0.25, ao_rays=12, ao_stride=2, front=1,
                 organic=organic, markers=markers, preview_yaws=(-50.0, 40.0, 110.0, 220.0),
                 preview_extra=[("chest", (0.0, 0.85, 2.3), 0.55, -40.0, -5.0),
                                ("side", (0.0, 0.0, 1.5), 1.7, -90.0, 5.0)])


def javelin():
    p = Part("javelin")
    _javelin(p, (0.0, 0.0, 0.0), 1.15, 1.05)
    return Model("javelin", [p], {"shaft": _shaft, "bronze": _bronze}, ppm=192, ground=None, ao_rays=6,
                 ao_dist=0.05, front=1, markers=[("tip", (0.0, 1.45, 0.0), None)])


def build():
    return [centaur(), javelin()]
