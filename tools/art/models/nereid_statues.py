"""The Nereids of the Nereid Monument: sea nymphs running over the waves,
their thin chitons pressed against the body by the wind and streaming out
behind, mantles billowing over their backs like sails. Headless and
armless as they came to the museum. Each stands on a sea creature on a
plinth of carved waves; they go between the columns of nereid_temple
(stylobate at y = 4.7 on the stacked monument) or on gr_plinth_block in the
room. Statuary marble, 128 px/m.

  nereid_a   striding to her right over a leaping dolphin, mantle arched
             from the right shoulder to the left hip
  nereid_b   stepping out over a crab, weight on the back foot, the skirt
             flying back between the legs
  nereid_c   running, leaning hard into the wind, a diving seabird under the
             front foot
  nereid_d   turning on her toes above a fish and a curling wave, the mantle
             wrapped round her waist and flying up behind

Each about 0.95 x 2.0 x 0.8 m (the mantle rises above the neck). Origin =
centre of the plinth's underside, front = Godot -Z.
"""
import math

import bmesh
from mathutils import Matrix, Vector

from artlib import greek as GK
from artlib import kit as K
from artlib.archkit import kit
from artlib.geo import Part
from artlib.sculpt import blob
from artlib.statue import fold, sculpt_into
from models.gr_pediment import Pose

PPM = 128
BASE = 0.32           # top of the wave plinth: the creature and the feet
V = Vector


def sail(p, a, top, b, width, slot, thick=0.03, n=12, m=4, ripple=0.03, seed=0, bulge=(0.0, 0.18, 0.0)):
    """A billowing mantle: a surface swept along the arc a -> top -> b
    (quadratic Bezier), ``width`` across it (vertical-ish band that narrows
    at the ends), rippled with folds, bulged toward ``bulge``, thickened."""
    A, T, B = V(a), V(top), V(b)
    bul = V(bulge)
    rows = []
    for i in range(n + 1):
        t = i / n
        c = A * (1 - t) ** 2 + T * 2 * t * (1 - t) + B * t * t
        tan = (2 * (1 - t) * (T - A) + 2 * t * (B - T)).normalized()
        side = tan.cross(V((0.0, 1.0, 0.0))).normalized()
        if side.length < 0.5:
            side = V((0.0, 0.0, 1.0))
        w = width * (0.35 + 0.65 * math.sin(math.pi * t))
        row = []
        for j in range(m + 1):
            s = j / m - 0.5
            q = c + side * (w * s) + bul * math.sin(math.pi * t) * (1 - (2 * s) ** 2)
            q += V((0.0, ripple * math.sin(j * 2.1 + i * 1.3 + seed), 0.0)) * math.sin(math.pi * t)
            row.append(p.bm.verts.new(q))
        rows.append(row)
    faces = []
    for i in range(n):
        for j in range(m):
            f = p._face([rows[i][j], rows[i + 1][j], rows[i + 1][j + 1], rows[i][j + 1]], slot, smooth=True)
            faces.append(f)
    for f in faces:
        f.normal_update()
    out = K.thicken(p, faces, thick)
    for f in out:
        f.smooth = True
    return out


def nereid_body(T, stride=1.0, back_lift=0.15, skirt_back=0.55):
    """Blobs of a striding, headless, armless woman in a clinging chiton
    (local: faces -Y, feet at z 0, about 1.48 m to the neck). The folds are
    grooves cut into the cloth (negative clay), not ridges stuck on."""
    b = []
    hl, hr = (0.09, 0.0, 0.9), (-0.09, 0.03, 0.92)
    kl, al, tl = (0.1, -0.26 * stride, 0.52), (0.1, -0.34 * stride, 0.08), (0.11, -0.46 * stride, 0.03)
    kr, ar, tr = (-0.1, 0.2 * stride, 0.5), (-0.1, 0.4 * stride, 0.08 + back_lift), (-0.1, 0.5 * stride, 0.03)
    for h, k, a, t in ((hl, kl, al, tl), (hr, kr, ar, tr)):
        b += T.limb([h, k, a], [0.125, 0.085, 0.058])
        b.append(T.b(k, 0.08))
        b += T.limb([a, t], [0.05, 0.036])
    b.append(T.b((0, 0.01, 0.94), (0.2, 0.16, 0.14)))
    b.append(T.b((0, -0.02, 1.12), (0.15, 0.12, 0.14), rot=(-8, 0, 0)))
    b.append(T.b((0, -0.05, 1.3), (0.17, 0.125, 0.15), rot=(-10, 0, 0)))
    for sx in (-1, 1):
        b.append(T.b((sx * 0.07, -0.15, 1.3), (0.068, 0.055, 0.062)))
        b.append(T.b((sx * 0.18, -0.04, 1.42), (0.078, 0.072, 0.062)))
        b += T.limb([(sx * 0.19, -0.04, 1.41), (sx * 0.25, -0.02, 1.27)], [0.07, 0.062])
    b.append(T.b((0, -0.06, 1.48), (0.058, 0.058, 0.07)))
    # overfold round the waist, with grooves
    b.append(T.b((0, -0.03, 1.07), (0.21, 0.16, 0.065)))
    for k in range(6):
        a = math.tau * (k + 0.5) / 12 - math.pi / 2 - math.pi / 2
        x, y = 0.21 * math.cos(a), -0.03 + 0.16 * math.sin(a)
        b += T.fold((x, y, 1.12), (x * 1.05, y * 1.05, 1.02), 0.012, neg=True, stiff=1.6)
    # the skirt streaming back from the hips past the back foot: one mass
    path = [V((0, 0.08, 0.84)), V((0, 0.22, 0.66)), V((0, skirt_back * 0.75, 0.42)), V((0, skirt_back, 0.18))]
    for i in range(len(path) - 1):
        a, c = path[i], path[i + 1]
        for k in range(3):
            t = k / 3
            q = a + (c - a) * t
            w = 0.17 + 0.05 * (i + t)
            b.append(T.b(tuple(q), (w, 0.075 + 0.01 * i, 0.13)))
    b.append(T.b(tuple(path[-1] + V((0, 0.03, -0.05))), (0.26, 0.08, 0.07)))
    # the long chiton between the legs: a curtain of cloth from the waist to
    # the ankles, spanning the stride (the legs press through it)
    for k in range(15):
        z = 0.9 - 0.055 * k
        t = (0.9 - z) / 0.82
        yf = -0.34 * stride * t                 # forward leg at this height
        yb = 0.4 * stride * t                   # back leg
        yc = (yf + yb) / 2
        b.append(T.b((0.0, yc, z), (0.16 + 0.03 * t, max(0.08, (yb - yf) * 0.5), 0.09), stiff=1.6))
    # the hem swirling round the forward ankle
    b.append(T.b((0.0, -0.33 * stride, 0.12), (0.18, 0.09, 0.07)))
    cuts = [(T(0, -0.06, 1.5), (0.0, -0.1, 1.0), 0.15 * T.k)]
    for sx in (-1, 1):
        cuts.append((T(sx * 0.245, -0.02, 1.29), (sx * 0.4, 0.0, -1.0), 0.09 * T.k))
    return b, cuts


def _plinth(p, rx=0.42, ry=0.34):
    p.lathe([(rx, 0.0), (rx, 0.08), (rx - 0.02, 0.1), (0.0, 0.1)], "slab", segments=20, squash=(1.0, ry / rx))


def _waves(T, n=7, r=0.38, seed=0):
    out = [T.b((0, 0, 0.16), (r, r * 0.8, 0.07))]
    for k in range(n):
        a = math.tau * k / n + seed
        out.append(T.b((r * 0.75 * math.cos(a), r * 0.6 * math.sin(a), 0.2 + 0.04 * (k % 2)),
                       (0.12, 0.08, 0.06), rot=(0, 0, math.degrees(a))))
        out.append(T.b((r * 0.8 * math.cos(a + 0.3), r * 0.65 * math.sin(a + 0.3), 0.25), (0.05, 0.04, 0.04)))
    return out


def dolphin(T):
    b = [T.b((0.0, -0.02, 0.27), (0.14, 0.32, 0.1), rot=(-12, 0, 0)),
         T.b((0.0, -0.3, 0.22), (0.08, 0.12, 0.07), rot=(25, 0, 0)),     # head and beak
         T.b((0.0, -0.42, 0.16), (0.035, 0.08, 0.03), rot=(30, 0, 0)),
         T.b((0.0, 0.3, 0.33), (0.07, 0.14, 0.06), rot=(-30, 0, 0)),      # tail stock
         T.b((0.0, 0.42, 0.42), (0.16, 0.05, 0.025), rot=(-30, 0, 0)),    # flukes
         T.b((0.0, 0.0, 0.38), (0.025, 0.08, 0.06), rot=(-20, 0, 0))]     # dorsal fin
    for sx in (-1, 1):
        b.append(T.b((sx * 0.13, -0.12, 0.22), (0.07, 0.04, 0.02), rot=(0, sx * 30, 0)))
        b.append(T.b((sx * 0.07, -0.26, 0.26), 0.022, neg=True, stiff=1.5))
    return b


def crab(T):
    b = [T.b((0.05, -0.05, 0.24), (0.17, 0.14, 0.06))]
    for sx in (-1, 1):
        for k in range(3):
            b += T.limb([(0.05 + sx * 0.14, -0.08 + 0.07 * k, 0.24), (0.05 + sx * 0.26, -0.1 + 0.09 * k, 0.24),
                         (0.05 + sx * 0.3, -0.1 + 0.1 * k, 0.17)], [0.025, 0.02, 0.012])
        b.append(T.b((0.05 + sx * 0.17, -0.24, 0.26), (0.07, 0.05, 0.035), rot=(0, 0, sx * 20)))   # claws
        b.append(T.b((0.05 + sx * 0.04, -0.17, 0.3), 0.015))
    return b


def bird(T):
    b = [T.b((0.0, -0.1, 0.3), (0.07, 0.17, 0.07), rot=(-35, 0, 0)),
         T.b((0.0, -0.26, 0.2), (0.045, 0.05, 0.045)),
         T.b((0.0, -0.33, 0.15), (0.015, 0.06, 0.012), rot=(40, 0, 0))]
    for sx in (-1, 1):
        b.append(T.b((sx * 0.17, -0.05, 0.34), (0.16, 0.08, 0.018), rot=(-20, sx * 25, 0)))
    b.append(T.b((0.0, 0.08, 0.38), (0.06, 0.08, 0.015), rot=(-30, 0, 0)))
    return b


def fish(T):
    b = [T.b((0.0, -0.04, 0.24), (0.06, 0.25, 0.08), rot=(10, 0, 20)),
         T.b((0.0, 0.25, 0.28), (0.02, 0.09, 0.08), rot=(10, 0, 20)),
         T.b((0.0, -0.28, 0.24), 0.015, neg=True)]
    b += [T.b((0.18, 0.15, 0.3), (0.05, 0.14, 0.12), rot=(0, 0, 40)),     # the curling wave
          T.b((0.24, 0.02, 0.4), (0.05, 0.06, 0.08), rot=(0, 30, 40))]
    return b


VARIANTS = {
    "nereid_a": dict(turn=-14, stride=1.0, lean=(-10.0, 0.0), creature=dolphin, back_lift=0.18, skirt=0.6,
                     sail=((-0.2, 0.05, 1.4), (0.05, 0.4, 1.78), (0.32, 0.2, 0.98)), seed=1),
    "nereid_b": dict(turn=18, stride=0.85, lean=(-4.0, 6.0), creature=crab, back_lift=0.08, skirt=0.55,
                     sail=((0.22, 0.05, 1.38), (0.0, 0.36, 1.72), (-0.3, 0.22, 1.02)), seed=2),
    "nereid_c": dict(turn=-4, stride=1.15, lean=(-18.0, 0.0), creature=bird, back_lift=0.22, skirt=0.7,
                     sail=((-0.18, 0.08, 1.38), (0.02, 0.48, 1.7), (0.25, 0.4, 1.05)), seed=3),
    "nereid_d": dict(turn=30, stride=0.7, lean=(-6.0, -8.0), creature=fish, back_lift=0.2, skirt=0.45,
                     sail=((0.25, 0.0, 1.05), (0.1, 0.38, 1.66), (-0.25, 0.25, 1.3)), seed=4),
}


def nereid(name, v):
    p = Part(name)
    _plinth(p)
    Tb = Pose(0.0, 0.0, 0.1, turn=v["turn"] * 0.5, k=1.0)
    sculpt_into(p, _waves(Tb, seed=v["seed"]) + v["creature"](Tb), "sea", res=0.012, tris=1800)
    T = Pose(0.0, 0.0, BASE, turn=v["turn"], k=1.05, lean=v["lean"], pivot_z=0.95)
    b, cuts = nereid_body(T, stride=v["stride"], back_lift=v["back_lift"], skirt_back=v["skirt"])
    sculpt_into(p, b, "marble", res=0.011, cuts=cuts, tris=6200, break_slot="break")
    a, top, e = (T(*q) for q in v["sail"])
    sail(p, a, top, e, 0.3, "mantle", thick=0.026, seed=v["seed"],
         bulge=tuple(T.turn @ V((0.0, 0.16, 0.05))))
    # the mantle's fold lines: shallow ridges along it, part of the same slot
    return p


def _marble(ctx):
    return GK.statuary(ctx, seed=1601, center=7.6, patina=1.0)


def _mantle(ctx):
    s = GK.statuary(ctx, seed=1603, center=7.4, patina=1.0, curv=0.6)
    u = ctx.uvm[:, 0] if ctx.N else ctx.uvm
    # radiating folds painted into the sail's normal map
    import numpy as np
    k = np.sin(ctx.p[:, 0] * 38.0 + ctx.p[:, 2] * 22.0 + ctx.fbm(3.0, 2, 1605) * 4.0)
    s.height = s.height + k * 0.004
    s.shade += k * 0.7
    return s


def _sea(ctx):
    s = GK.statuary(ctx, seed=1611, center=7.0, patina=1.2)
    GK.paint_traces(ctx, s, "gr_blue", ctx.ao < 0.8, 1613, center=3.2, density=0.4, freq=3.0)
    return s


def _slab(ctx):
    return GK.grey_marble(ctx, seed=1615, center=4.8)


def build():
    fns = {"marble": _marble, "mantle": _mantle, "sea": _sea, "slab": _slab, "break": GK.fracture}
    return [kit(n, [nereid(n, v)], fns, organic=(n,), ppm=PPM, ground=0.0, ao_dist=0.25, ao_rays=12,
                preview_closeup=None) for n, v in VARIANTS.items()]
