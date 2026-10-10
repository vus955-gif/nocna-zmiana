"""The hoplite enemy: a marble statue of a Greek heavy infantryman come
down from his base - Corinthian helmet with a tall crest, a muscle cuirass
over a pleated skirt of pteruges, greaves, a round aspis on the left arm and
a long spear. Traces of paint: red on the crest, ochre on the cuirass rim,
a blue-and-red blazon on the shield. Inside the helmet the dark shows two
pale embers (the weak point is the face).

Faces +Y in Blender = -Z in Godot. Origin on the floor between the feet.
About 2.0 m to the top of the crest. Parts (Godot node names) with pivots
at the joints, built like the knight (KnightRig drives the same names):
    torso        (0, 0, 1.00)          waist                    root
    head         (0, 0, 1.56)          neck (helmet)            child of torso
    plate_crest  (0, -0.02, 1.84)      crest stilt              child of head
    arm_l        (-0.23, 0.0, 1.46)    left shoulder            child of torso
    forearm_l    (-0.29, 0.06, 1.2)    left elbow               child of arm_l
    shield       (-0.12, 0.42, 1.18)   grip (porpax)            child of forearm_l
    arm_r        (0.23, 0.0, 1.46)     right shoulder           child of torso
    forearm_r    (0.31, 0.04, 1.2)     right elbow              child of arm_r
    spear        (0.33, 0.3, 1.08)     grip, shaft along +Y     child of forearm_r
    leg_l, leg_r (-/+0.11, 0, 0.92)    hips                     root
    shin_l, shin_r (-/+0.12, 0.03, 0.5) knees                   children of leg_*
    plate_greave_l / _r                greaves (knock-off)      children of shin_*
Markers: face (centre of the helmet's eye openings, the weak point),
spear_tip (point of the blade), child of spear.
marble_chips: six chunks of marble (chip_1 .. chip_6, pivots at their
centres) for hits and the breakup.
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
from artlib.sculpt import blob
from artlib.statue import sculpt_into
from models.gr_pediment import Pose

V = Vector
HELM_C = (0.0, 0.01, 1.71)
FACE = (0.0, 0.11, 1.715)
SH_L, SH_R = V((-0.23, 0.0, 1.46)), V((0.23, 0.0, 1.46))
EL_L, EL_R = V((-0.29, 0.06, 1.2)), V((0.31, 0.04, 1.2))
GRIP_L = V((-0.12, 0.42, 1.18))       # the shield's porpax (forearm band) centre
WR_L = V((-0.16, 0.3, 1.2))
GRIP_R = V((0.33, 0.3, 1.08))
HIP = 0.11
SPEAR_LEN_FWD, SPEAR_LEN_BACK = 1.45, 0.95


def _torso(p):
    Tb = Pose(0, 0, 0, k=1.0)
    b = [Tb.b((0, 0.0, 1.06), (0.17, 0.13, 0.1)), Tb.b((0, 0.0, 1.22), (0.17, 0.13, 0.12)),
         Tb.b((0, 0.0, 1.38), (0.2, 0.14, 0.13))]
    for sx in (-1, 1):
        b.append(Tb.b((sx * 0.085, 0.11, 1.38), (0.085, 0.045, 0.065)))          # cuirass pectorals
        b.append(Tb.b((sx * 0.05, 0.11, 1.2), (0.045, 0.03, 0.045), stiff=1.6))   # abdominal plates
        b.append(Tb.b((sx * 0.05, 0.12, 1.1), (0.04, 0.025, 0.035), stiff=1.6))
        b.append(Tb.b((sx * 0.2, 0.0, 1.46), (0.085, 0.08, 0.06)))               # shoulders
    b.append(Tb.b((0, 0.0, 1.52), (0.065, 0.06, 0.07)))                          # neck
    sculpt_into(p, b, "cuirass", res=0.01, tris=2400)
    # the cuirass's flared lower rim and the pteruges below it
    rim = p.lathe([(0.185, 1.02), (0.2, 1.0), (0.19, 0.985)], "rim", segments=24, squash=(1.0, 0.8),
                  cap_bottom=False, cap_top=False, smooth=False)
    K.thicken(p, rim, 0.01)
    strips = lambda i, j: 1.0 if i % 2 == 0 else 0.94
    for row, (z0, z1, r0, r1) in enumerate(((0.99, 0.86, 0.19, 0.215), (0.92, 0.78, 0.2, 0.225))):
        f = p.lathe([(r0, z0), (r1, z1)], "pteruges", segments=28, squash=(1.0, 0.82), cap_bottom=False,
                    cap_top=False, smooth=False, ring_scale=strips, phase=row * math.pi / 28)
        K.thicken(p, f, 0.008)


def _head(p):
    """Corinthian helmet: one shell from the crown down to the chin, the
    cheek pieces part of it; almond eye holes joined by the T of the nose
    guard and the slit between the cheek pieces; a flared neck guard."""
    prof = [(0.122, 1.545), (0.135, 1.56), (0.13, 1.585), (0.128, 1.62), (0.13, 1.66), (0.134, 1.7),
            (0.137, 1.74), (0.13, 1.785), (0.11, 1.822), (0.06, 1.848), (0.0, 1.855)]
    faces = p.lathe(prof, "helmet", segments=28, cap_bottom=False, squash=(0.9, 1.06), smooth=True)
    import bmesh
    hole = []
    for f in faces:
        c = f.calc_center_median()
        front = c.y / max(math.hypot(c.x, c.y), 1e-6)
        if front > 0.93 and c.z < 1.67 and abs(c.x) < 0.03:                         # the slit
            hole.append(f)
        elif front > 0.55 and 1.685 < c.z < 1.74 and 0.022 < abs(c.x) < 0.095:      # eye holes
            hole.append(f)
    bmesh.ops.delete(p.bm, geom=hole, context='FACES')
    K.sphere(p, (0.0, 0.0, 1.7), 0.112, "void", segments=12, rings=6)
    p.box((0.0, 0.14, 1.695), (0.026, 0.02, 0.07), "helmet", bevel=0.006)              # nose guard
    p.box((0.0, -0.02, 1.86), (0.025, 0.14, 0.03), "helmet", bevel=0.006)              # crest holder


def _crest_simple(p):
    """Crest as stacked boxes along an arc (robust and chunky)."""
    out = []
    n = 9
    for i in range(n):
        a0 = math.radians(-55 + 150 * i / n)
        a1 = math.radians(-55 + 150 * (i + 1) / n)
        am = (a0 + a1) / 2
        r = 0.15
        y = 0.0 + r * math.sin(am) * -1.0
        z = 1.85 + r * math.cos(am) * 0.62
        h = 0.07 + 0.05 * math.sin(math.pi * i / (n - 1))
        f = p.box((0.0, 0.0, 0.0), (0.07, 0.07, h), "crest", bevel=0.014)
        p.move(f, T(0.0, y - 0.02, z) @ R('X', math.degrees(am)))
        out += f
    return out


def _arm(p, sh, el, wr, fist, sx, upper=True):
    Tb = Pose(0, 0, 0, k=1.0)
    if upper:
        b = Tb.limb([tuple(sh), tuple(el)], [0.07, 0.055])
        b.append(Tb.b(tuple(sh + V((sx * 0.02, 0, 0))), (0.08, 0.075, 0.07)))
        sculpt_into(p, b, "skin", res=0.009, tris=700)
    else:
        b = Tb.limb([tuple(el), tuple(wr)], [0.052, 0.04])
        b.append(Tb.b(tuple(fist), (0.045, 0.05, 0.05)))
        sculpt_into(p, b, "skin", res=0.008, tris=650)


def _shield(p):
    """Aspis: 0.9 m, dished, a rolled rim; the porpax band and the handle
    (antilabe) on the back. Built facing +Y around the grip."""
    r = 0.45
    face = p.lathe([(0.0, 0.07), (0.15, 0.065), (0.3, 0.045), (0.41, 0.015), (r, 0.0)], "shield_face",
                   segments=28, cap_bottom=False, smooth=True)
    rim = p.lathe([(r, 0.0), (r + 0.02, 0.005), (r + 0.025, -0.015), (r + 0.01, -0.03), (r - 0.03, -0.025)],
                  "shield_rim", segments=28, cap_bottom=False, cap_top=False, smooth=True)
    back = p.lathe([(r - 0.03, -0.025), (0.3, 0.01), (0.0, 0.03)], "shield_back", segments=28, cap_bottom=False,
                   smooth=True)
    allf = face + rim + back
    p.move(allf, Matrix.Rotation(math.radians(-90), 4, 'X'))           # axis along +Y: the face looks forward
    p.box((0.0, -0.06, 0.0), (0.06, 0.05, 0.22), "shield_back", bevel=0.01)             # porpax
    p.box((0.3, -0.05, 0.0), (0.04, 0.04, 0.1), "shield_back", bevel=0.01)              # antilabe
    p.move(list(p.bm.faces), T(*GRIP_L) @ T(0.0, 0.06, 0.0))


def _spear(p):
    g = GRIP_R
    K.seg(p, g + V((0, -SPEAR_LEN_BACK, 0)), g + V((0, SPEAR_LEN_FWD, 0)), [(0.017, 0.0), (0.019, 0.5), (0.016, 1.0)],
          "shaft", segments=6)
    blade = p.lathe([(0.0, 0.0), (0.035, 0.08), (0.04, 0.16), (0.028, 0.24), (0.0, 0.32)], "bronze", segments=4,
                    squash=(1.0, 0.25), smooth=False, cap_bottom=False)
    p.move(blade, T(*(g + V((0, SPEAR_LEN_FWD - 0.02, 0)))) @ R('X', -90))
    butt = p.lathe([(0.022, 0.0), (0.02, 0.14), (0.006, 0.2)], "bronze", segments=6, smooth=False)
    p.move(butt, T(*(g + V((0, -SPEAR_LEN_BACK + 0.02, 0)))) @ R('X', 90))
    p.box(tuple(g), (0.05, 0.12, 0.05), "shaft", bevel=0.012)          # the grip binding


def _leg(p, sx):
    Tb = Pose(0, 0, 0, k=1.0)
    hip, knee = V((sx * HIP, 0.0, 0.92)), V((sx * 0.12, 0.03, 0.5))
    b = Tb.limb([tuple(hip), tuple(knee)], [0.09, 0.065])
    b.append(Tb.b(tuple(knee), 0.065))
    sculpt_into(p, b, "skin", res=0.01, tris=700)


def _shin(p, sx):
    Tb = Pose(0, 0, 0, k=1.0)
    knee, ankle, toe = V((sx * 0.12, 0.03, 0.5)), V((sx * 0.125, 0.0, 0.08)), V((sx * 0.13, 0.17, 0.03))
    b = Tb.limb([tuple(knee), tuple(ankle)], [0.058, 0.04])
    b += Tb.limb([tuple(ankle), tuple(toe)], [0.042, 0.03])
    b.append(Tb.b((sx * 0.125, -0.03, 0.05), (0.04, 0.05, 0.04)))      # heel
    sculpt_into(p, b, "skin", res=0.009, tris=700)
    # sandal sole
    p.box((sx * 0.128, 0.07, 0.008), (0.09, 0.26, 0.016), "leather", bevel=0.004)


def _greave(p, sx):
    """A bronze greave: a shell over the shin, open at the back."""
    x = sx * 0.123
    f = K.plate_ring(p, (x, 0.012, 0.0), [(0.05, 0.12), (0.064, 0.22), (0.07, 0.32), (0.066, 0.42), (0.058, 0.5)],
                     "greave", segments=16, squash=(1.0, 0.95), keep_pred=lambda v, x=x: v.y > -0.01,
                     thickness=0.008)
    return f


# --------------------------------------------------------------------------
# paint
# --------------------------------------------------------------------------

def _marble(ctx):
    return GK.statuary(ctx, seed=2001, center=7.6, patina=0.9)


def _cuirass(ctx):
    s = GK.statuary(ctx, seed=2003, center=7.5, patina=0.9)
    z = ctx.p[:, 2]
    GK.paint_traces(ctx, s, "gr_ochre", (z > 1.42) & (ctx.n[:, 2] > 0.3), 2005, center=3.8, density=0.2, freq=4.0)
    return s


def _rim(ctx):
    s = GK.statuary(ctx, seed=2007, center=7.2, patina=1.0)
    GK.paint_traces(ctx, s, "gr_ochre", np.ones(ctx.N, bool), 2009, center=3.8, density=0.6, freq=3.0)
    return s


def _pteruges(ctx):
    s = GK.statuary(ctx, seed=2011, center=7.0, patina=1.0)
    GK.paint_traces(ctx, s, "gr_red", np.ones(ctx.N, bool), 2013, center=3.4, density=0.35, freq=3.0)
    return s


def _helmet(ctx):
    s = GK.statuary(ctx, seed=2015, center=7.6, patina=0.8, curv=0.6)
    # the incised brow line and a fine edging
    z = ctx.p[:, 2]
    brow = (np.abs(z - 1.76) < 0.004) & (ctx.p[:, 1] > 0.05)
    s.shade -= brow * 2.0
    s.height = s.height - brow * 0.0015
    return s


def _void(ctx):
    """The dark inside the helmet, two pale embers for eyes."""
    s = M.Surface(ctx.N)
    d = ctx.p - np.array((0.0, 0.0, 1.7))
    fwd = d[:, 1] / 0.11
    s.use_ramp(M.P["ember"], shade=0.4 + np.clip(fwd, 0, 1) * 1.6 + ctx.fbm(30.0, 2, 2017) * 0.6)
    eyes = np.zeros(ctx.N, bool)
    for ex in (-0.035, 0.035):
        e = np.sqrt((d[:, 0] - ex) ** 2 + ((d[:, 2] - 0.015) * 1.4) ** 2)
        eyes |= (e < 0.016) & (fwd > 0.6)
        s.shade[(e < 0.008) & (fwd > 0.6)] = 7.0
    s.shade[eyes] = np.maximum(s.shade[eyes], 5.5)
    s.rough = np.full(ctx.N, 0.9)
    s.emit = s.colors() * np.where(eyes, 1.0, 0.25)[:, None]
    return s


def _crest_paint(ctx):
    s = GK.statuary(ctx, seed=2019, center=7.0, patina=1.0)
    # combed horsehair: grooves along the crest, red paint in them
    k = np.sin(ctx.p[:, 0] * 260.0)
    s.shade += k * 0.8
    s.height = s.height + k * 0.0015
    GK.paint_traces(ctx, s, "gr_red", np.ones(ctx.N, bool), 2021, center=3.6, density=0.75, freq=3.0)
    return s


def _shield_face(ctx):
    """Marble aspis with the ghost of its painted blazon: a black-and-white
    Pegasus on red, a blue meander band round the rim."""
    s = GK.statuary(ctx, seed=2023, center=7.4, patina=1.0, curv=0.4)
    x = ctx.p[:, 0] - GRIP_L.x
    z = ctx.p[:, 2] - GRIP_L.z
    r = np.hypot(x, z)
    band = (r > 0.36) & (r < 0.41)
    GK.paint_traces(ctx, s, "gr_blue", band, 2025, center=3.2, density=0.7, freq=3.0)
    field = r < 0.34
    GK.paint_traces(ctx, s, "gr_red", field, 2027, center=3.4, density=0.55, freq=2.0)
    # Pegasus: body, neck, wings, legs, in the middle
    peg = ((x / 0.13) ** 2 + ((z + 0.02) / 0.06) ** 2 < 1)
    peg |= (np.abs(x - 0.12 - (z - 0.04) * 0.4) < 0.03) & (z > 0.0) & (z < 0.14)
    peg |= (np.abs(z - 0.05 - np.abs(x + 0.02) * 0.6) < 0.025) & (x > -0.16) & (x < 0.08) & (z > 0.02)
    for lx in (-0.09, -0.05, 0.06, 0.1):
        peg |= (np.abs(x - lx) < 0.012) & (z < -0.04) & (z > -0.17)
    GK.paint_traces(ctx, s, "gr_gloss", peg & field, 2029, center=2.0, density=0.85, freq=2.0)
    return s


def _shield_rim(ctx):
    s = GK.statuary(ctx, seed=2031, center=7.6, patina=0.8)
    GK.paint_traces(ctx, s, "gr_ochre", np.ones(ctx.N, bool), 2033, center=3.8, density=0.5, freq=3.0)
    return s


def _shield_back(ctx):
    return GK.statuary(ctx, seed=2035, center=6.6, patina=1.2)


def _shaft(ctx):
    s = M.wood_oak(ctx, seed=2037)
    return s


def _bronze(ctx):
    return M.bronze(ctx, seed=2039)


def _greave_paint(ctx):
    s = GK.statuary(ctx, seed=2041, center=7.6, patina=0.8)
    GK.paint_traces(ctx, s, "gr_ochre", np.ones(ctx.N, bool), 2043, center=3.8, density=0.35, freq=3.0)
    return s


def _leather(ctx):
    return M.leather(ctx, seed=2045)


def hoplite():
    torso = Part("torso", origin=(0, 0, 1.0))
    _torso(torso)
    head = Part("head", origin=(0, 0, 1.56), parent="torso")
    _head(head)
    crest = Part("plate_crest", origin=(0, -0.02, 1.84), parent="head")
    _crest_simple(crest)
    arm_l = Part("arm_l", origin=tuple(SH_L), parent="torso")
    _arm(arm_l, SH_L, EL_L, WR_L, WR_L, -1, upper=True)
    fore_l = Part("forearm_l", origin=tuple(EL_L), parent="arm_l")
    _arm(fore_l, SH_L, EL_L, WR_L, WR_L + V((0.02, 0.04, -0.01)), -1, upper=False)
    shield = Part("shield", origin=tuple(GRIP_L), parent="forearm_l")
    _shield(shield)
    arm_r = Part("arm_r", origin=tuple(SH_R), parent="torso")
    _arm(arm_r, SH_R, EL_R, GRIP_R, GRIP_R, 1, upper=True)
    fore_r = Part("forearm_r", origin=tuple(EL_R), parent="arm_r")
    _arm(fore_r, SH_R, EL_R, GRIP_R + V((0.0, -0.04, 0.0)), GRIP_R, 1, upper=False)
    spear = Part("spear", origin=tuple(GRIP_R), parent="forearm_r")
    _spear(spear)
    legs = []
    for sx, side in ((-1, "l"), (1, "r")):
        leg = Part("leg_" + side, origin=(sx * HIP, 0, 0.92))
        _leg(leg, sx)
        shin = Part("shin_" + side, origin=(sx * 0.12, 0.03, 0.5), parent="leg_" + side)
        _shin(shin, sx)
        gr = Part("plate_greave_" + side, origin=(sx * 0.123, 0.06, 0.32), parent="shin_" + side)
        _greave(gr, sx)
        legs += [leg, shin, gr]
    parts = [torso, head, crest, arm_l, fore_l, shield, arm_r, fore_r, spear] + legs
    fns = {"cuirass": _cuirass, "rim": _rim, "pteruges": _pteruges, "helmet": _helmet, "void": _void,
           "crest": _crest_paint, "skin": _marble, "shield_face": _shield_face, "shield_rim": _shield_rim,
           "shield_back": _shield_back, "shaft": _shaft, "bronze": _bronze, "greave": _greave_paint,
           "leather": _leather}
    tip = GRIP_R + V((0.0, SPEAR_LEN_FWD + 0.3, 0.0))
    organic = ("torso", "arm_l", "forearm_l", "arm_r", "forearm_r", "leg_l", "leg_r", "shin_l", "shin_r")
    return Model("hoplite", parts, fns, ppm=256, ground=0.0, ao_dist=0.14, ao_rays=12, ao_stride=2, front=1,
                 organic=organic, markers=[("face", FACE, "head"), ("spear_tip", tuple(tip), "spear")],
                 preview_yaws=(-35.0, 35.0, 120.0, 210.0), preview_closeup=((0.0, 0.1, 1.72), 0.2),
                 preview_extra=[("shield", (-0.12, 0.5, 1.18), 0.6, 10.0, 5.0)])


def chips():
    parts = []
    rng = np.random.default_rng(7)
    for k in range(6):
        c = V((-0.25 + 0.1 * k, 0.0, 0.08))
        p = Part("chip_%d" % (k + 1), origin=tuple(c))
        size = rng.uniform(0.05, 0.14)
        pts = []
        n = 6
        for i in range(n):
            a = math.tau * i / n + rng.uniform(-0.3, 0.3)
            r = size * rng.uniform(0.6, 1.0)
            pts.append((r * math.cos(a), r * math.sin(a)))
        f = p.ngon_prism(pts, -size * 0.35, size * 0.35, "chip", bevel=0.004)
        p.move(f, T(*c) @ R('X', rng.uniform(0, 90)) @ R('Y', rng.uniform(0, 90)))
        parts.append(p)
    fns = {"chip": lambda ctx: _chip(ctx)}
    return Model("marble_chips", parts, fns, ppm=256, ground=None, ao_rays=6, ao_dist=0.05, front=1)


def _chip(ctx):
    s = GK.statuary(ctx, seed=2051, center=7.4, patina=0.7)
    br = GK.fracture(ctx)
    m = (ctx.fbm(8.0, 2, 2055) > 0.0)
    s.merge(GK._select(br, m), m)
    return s


def build():
    return [hoplite(), chips()]
