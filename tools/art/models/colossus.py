"""Kolos Ramzesa, guardian of the Egypt wing: a seated colossus of Ramesses
about 9 m tall (crown top), red Aswan granite with traces of paint: the
nemes headcloth striped gold and blue, the double crown (red deshret over
white hedjet), a gold uraeus, a plaited beard, a broad collar of faience,
gold and carnelian, a pleated royal kilt and a gold belt, inlaid eyes that
wake as two suns. Massive canonical forms: broad shoulders, arms close to
the body, the left hand flat on the knee, the right fist round a mekes case.

Two models, both with the origin on the floor under the hip joints, front
= +Y in Blender = -Z in Godot (the guardian's forward); place them with the
same transform:

  colossus_throne  (static, 72 px/m) the block throne carved on both sides
                   with the Union of the Two Lands, a low backrest, the back
                   pillar with a column of text, the plinth with the king's
                   cartouches. Markers swarm_l / swarm_r: holes low in the
                   throne's sides where scarab swarms pour out.
  colossus         (the guardian, 112 px/m) a chain of jointed parts:

    pelvis                      (0, 0, 3.30)          body root: hips, belt
      thigh_l / thigh_r         (-/+0.45, 0, 3.30)    hips (kilt on the thighs)
        shin_l / shin_r         (-/+0.48, 2.30, 3.32) knees
          foot_l / foot_r       (-/+0.50, 2.45, 1.00) ankles
      torso                     (0, -0.05, 4.10)      waist: chest, collar
        head                    (0, -0.10, 6.08)      neck: face, nemes,
                                                      double crown, beard
          eyes                  the two eye inlays (glow them on their own)
          uraeus                the cobra on the brow, origin = its hood
                                centre: the weak point
        upperarm_l / _r         (-/+1.05, -0.12, 5.72) shoulders
          forearm_l / _r        (-/+1.02, 0.20, 4.32)  elbows
            palm_l / palm_r     (-/+0.72, 1.42, 3.98)  wrists
        chest_plate_1..3        granite slabs over the cracks (knock off)
        crack_1..3              glowing fissures under them; origin = the
                                crack's centre on the chest surface
    Markers: eye_l / eye_r (children of head, on the pupils: beam origins),
    hand_l / hand_r (children of palm_l / palm_r, under the palms: slam
    contact). Blender (x, y, z) = Godot (x, z, -y); its left is -X.
"""
import math
import random

import numpy as np
from mathutils import Matrix, Vector

from artlib import egypt as E
from artlib import egypt_paint as EP
from artlib import face as F
from artlib import kit as K
from artlib import sculpt
from artlib.archkit import cull_floor
from artlib.geo import Part
from artlib.kit import R, T
from artlib.materials import P
from artlib.model import Model
from artlib.painter import Surface
from artlib.sculpt import blob, limb

HIP = (0.45, 0.0, 3.30)
KNEE = (0.48, 2.30, 3.32)
ANKLE = (0.50, 2.45, 1.00)
WAIST = (0.0, -0.05, 4.10)
SHOULDER = (1.05, -0.12, 5.72)
ELBOW = (1.02, 0.20, 4.32)
WRIST = (0.72, 1.42, 3.98)
NECK = (0.0, -0.10, 6.08)
PLINTH_TOP = 0.6
SEAT = 2.85
HC = Vector((0.0, 0.05, 6.75))     # the head is sculpted, then scaled about HC
HS = 1.1
# chest cracks: (x, z, half-width, half-height) on the front of the torso
CRACKS = [(-0.46, 5.02, 0.27, 0.25), (0.05, 4.68, 0.24, 0.27), (0.44, 4.36, 0.25, 0.21)]

ORDER = ["pelvis", "thigh_l", "thigh_r", "shin_l", "shin_r", "foot_l", "foot_r", "torso", "head", "eyes", "uraeus",
         "upperarm_l", "upperarm_r", "forearm_l", "forearm_r", "palm_l", "palm_r",
         "chest_plate_1", "chest_plate_2", "chest_plate_3", "crack_1", "crack_2", "crack_3"]
IDX = {n: i for i, n in enumerate(ORDER)}


def hs(p):
    """Sculpt-space head point -> model space."""
    return tuple(HC + (Vector(p) - HC) * HS)


FACE_C = Vector((0.0, 0.0, 6.80))  # the unit face (artlib/face.py) sits here, scaled FACE_S
FACE_S = 1.17
FACE_M = Matrix.Translation(FACE_C) @ Matrix.Scale(FACE_S, 4)
EYE = hs((F.EYES[1][0] * FACE_S, 0.56, FACE_C.z + F.EYES[1][1] * FACE_S))
URAEUS = hs((0.0, 0.6, 7.14))


def to_unit(co):
    """Model-space point -> unit head coordinates (inverse of hs, FACE_M)."""
    q = HC + (Vector(co) - HC) / HS
    q = (q - FACE_C) / FACE_S
    return q.x, q.y, q.z
GRAIN = 0.4


def _sx(p, sx):
    return (sx * p[0], p[1], p[2])


def _clay(part, blobs, tris, slot="granite", res=0.03, cut=None):
    me = sculpt.metaball_mesh(blobs, resolution=res)
    if cut:
        sculpt.cut(me, cut)
    me = sculpt.decimate(me, tris)
    sculpt.into_part(part, me, slot)


def _box_between(p, a, b, w, t, slot):
    """A flat bar from a to b: width w, thickness t."""
    a, b = Vector(a), Vector(b)
    d = b - a
    q = d.normalized().to_track_quat('Z', 'Y')
    faces = p.box((0.0, 0.0, d.length / 2), (w, t, d.length), slot, bevel=0.01)
    p.move(faces, Matrix.Translation(a) @ q.to_matrix().to_4x4())
    return faces


# --------------------------------------------------------------------------
# throne (its own model)
# --------------------------------------------------------------------------

def throne():
    p = Part("colossus_throne")
    p.box((0.0, 1.1, PLINTH_TOP / 2), (3.9, 5.6, PLINTH_TOP), "plinth", bevel=0.03)
    p.box((0.0, 0.18, (PLINTH_TOP + SEAT) / 2), (3.2, 2.9, SEAT - PLINTH_TOP), "throne", bevel=0.03)
    p.box((0.0, 0.18, SEAT + 0.04), (3.26, 2.96, 0.08), "throne", bevel=0.02)
    p.box((0.0, -1.05, SEAT + 0.7), (3.2, 0.44, 1.4), "throne", bevel=0.03)
    p.box((0.0, -1.0, (SEAT + 5.95) / 2), (1.2, 0.5, 5.95 - SEAT), "pillar", bevel=0.03)
    cull_floor([p])
    return p


# --------------------------------------------------------------------------
# body
# --------------------------------------------------------------------------

def pelvis():
    p = Part("pelvis", origin=(0.0, 0.0, 3.30))
    b = [blob((0.0, -0.15, 3.28), (0.94, 0.62, 0.46)),
         blob((0.0, 0.25, 3.55), (0.85, 0.45, 0.42)),
         blob((0.0, -0.05, 3.86), (0.86, 0.58, 0.32))]
    for sx in (-1, 1):
        b.append(blob((sx * 0.5, 0.05, 3.3), 0.5))
    _clay(p, b, 1300, "kilt", res=0.04, cut=[((0, 0, SEAT + 0.005), (0, 0, -1))])
    p.lathe([(0.9, 3.84), (0.93, 3.88), (0.93, 4.05), (0.9, 4.09)], "belt", segments=28, center=(0.0, -0.05, 0.0),
            squash=(1.0, 0.7), cap_bottom=False, cap_top=False, smooth=False)
    return p


def thigh(sx):
    name = "thigh_l" if sx < 0 else "thigh_r"
    hip, knee = _sx(HIP, sx), _sx(KNEE, sx)
    p = Part(name, origin=hip, parent="pelvis")
    b = limb([hip, (sx * 0.47, 1.2, 3.32), knee], [0.54, 0.48, 0.38], spacing=0.7)
    b.append(blob((sx * 0.48, 2.25, 3.34), (0.36, 0.3, 0.34)))
    _clay(p, b, 1100, "granite", res=0.035, cut=[((0, 0, SEAT + 0.005), (0, 0, -1))])
    faces = K.seg(p, (sx * 0.4, 0.05, 3.32), (sx * 0.45, 1.85, 3.33), [(0.6, 0.0), (0.55, 0.6), (0.5, 1.0)], "kilt",
                  segments=20, smooth=True, caps=False)
    faces = K.keep(p, faces, lambda c: c.z > 3.32 - 0.1)
    K.thicken(p, faces, 0.03)
    return p


def shin(sx):
    name = "shin_l" if sx < 0 else "shin_r"
    knee, ankle = _sx(KNEE, sx), _sx(ANKLE, sx)
    p = Part(name, origin=knee, parent=name.replace("shin", "thigh"))
    b = limb([knee, (sx * 0.49, 2.4, 2.2), ankle], [0.42, 0.36, 0.27], spacing=0.7)
    b.append(blob((sx * 0.49, 2.2, 2.45), (0.38, 0.34, 0.62)))
    b.append(blob((sx * 0.49, 2.6, 3.15), (0.24, 0.14, 0.24)))
    _clay(p, b, 900, "granite", res=0.035)
    return p


def foot(sx):
    name = "foot_l" if sx < 0 else "foot_r"
    p = Part(name, origin=_sx(ANKLE, sx), parent=name.replace("foot", "shin"))
    x = sx * 0.5
    b = [blob((x, 2.45, 0.92), (0.22, 0.24, 0.26)),
         blob((x, 2.22, 0.78), (0.2, 0.22, 0.18)),
         blob((x + sx * 0.02, 2.95, 0.75), (0.28, 0.5, 0.16)),
         blob((x + sx * 0.04, 3.3, 0.68), (0.3, 0.22, 0.1))]
    for k, tx in enumerate((-0.2, -0.1, 0.0, 0.1, 0.19)):
        ln = (0.13, 0.14, 0.15, 0.17, 0.22)[k if sx > 0 else 4 - k]
        b.append(blob((x + tx, 3.46 + ln * 0.5, 0.665), (0.05, ln * 0.5, 0.065)))
    _clay(p, b, 650, "granite", res=0.025, cut=[((0, 0, PLINTH_TOP + 0.002), (0, 0, -1))])
    return p


def torso():
    p = Part("torso", origin=WAIST, parent="pelvis")
    b = [blob((0.0, 0.05, 4.4), (0.82, 0.55, 0.52)),
         blob((0.0, 0.0, 5.05), (1.0, 0.62, 0.68)),
         blob((0.0, -0.42, 5.1), (0.92, 0.34, 0.75)),
         blob((0.0, -0.15, 5.95), (0.68, 0.38, 0.28)),
         blob((0.0, -0.08, 6.12), (0.34, 0.34, 0.22)),
         blob((0.0, 0.58, 4.42), (0.05, 0.05, 0.05), neg=True, stiff=1.6)]
    for sx in (-1, 1):
        b += [blob((sx * 0.45, 0.42, 5.3), (0.46, 0.22, 0.32)),
              blob((sx * 1.04, -0.1, 5.68), (0.42, 0.42, 0.4)),
              blob((sx * 0.68, 0.1, 4.55), (0.24, 0.34, 0.42))]
    _clay(p, b, 3600, "granite", res=0.032, cut=[((0, 0, 3.86), (0, 0, -1))])
    faces = p.lathe([(1.12, 5.32), (0.95, 5.58), (0.72, 5.84), (0.45, 6.04)], "collar", segments=28,
                    center=(0.0, -0.06, 0.0), squash=(0.95, 0.66), cap_bottom=False, cap_top=False, smooth=True)
    faces = K.keep(p, faces, lambda c: c.y > -0.12)
    K.thicken(p, faces, 0.035)
    return p


def _select_region(part, cx, cz, rx, rz):
    bm = part.bm
    bm.normal_update()
    out = []
    for f in bm.faces:
        if part.slots[f.material_index] != "granite":
            continue
        c = f.calc_center_median()
        if c.y > 0.15 and f.normal.y > 0.2 and ((c.x - cx) / rx) ** 2 + ((c.z - cz) / rz) ** 2 < 1.0:
            out.append(f)
    return out


def cracks(torso_part):
    """Lifts three plates off the chest (exact copies of its surface,
    thickened) and sinks the surface under them into a recess with a
    glowing fissure at the bottom."""
    plates, glows = [], []
    rng = random.Random(3)
    for k, (cx, cz, rx, rz) in enumerate(CRACKS):
        sel = _select_region(torso_part, cx, cz, rx, rz)
        verts = sorted({v for f in sel for v in f.verts}, key=lambda v: (round(v.co.x, 5), round(v.co.y, 5), round(v.co.z, 5)))
        ymean = sum(v.co.y for v in verts) / max(1, len(verts))
        centre = Vector((cx, ymean, cz))
        plate = Part(f"chest_plate_{k + 1}", origin=tuple(centre), parent="torso")
        vmap = {v: plate.bm.verts.new(v.co + v.normal * 0.012) for v in verts}
        new = [plate._face([vmap[v] for v in f.verts], "granite", smooth=True) for f in sel]
        K.thicken(plate, new, 0.09)
        plates.append(plate)
        sel_set = set(sel)
        for v in verts:
            if all(f in sel_set for f in v.link_faces):
                v.co -= v.normal * 0.2
        g = Part(f"crack_{k + 1}", origin=tuple(centre), parent="torso")
        n = 9
        ring = []
        for i in range(n * 2):
            a = math.tau * i / (n * 2) + rng.uniform(-0.1, 0.1)
            r = rng.uniform(0.75, 1.0) if i % 2 == 0 else rng.uniform(0.2, 0.35)
            ring.append(g.bm.verts.new((cx + math.cos(a) * rx * r, ymean - 0.17, cz + math.sin(a) * rz * r)))
        mid = g.bm.verts.new((cx, ymean - 0.19, cz))
        for i in range(n * 2):
            f = g._face([ring[i], ring[(i + 1) % (n * 2)], mid], "crackglow", smooth=False)
            f.normal_update()
            if f.normal.y < 0:
                f.normal_flip()
        glows.append(g)
    return plates, glows


def _head_scale(p):
    p.move(list(p.bm.faces), Matrix.Translation(HC) @ Matrix.Scale(HS, 4) @ Matrix.Translation(-HC))


def head():
    """The head with its face (artlib/face.py), the nemes, the double crown
    and the beard; returns (part, the eye-lens mesh for eyes())."""
    p = Part("head", origin=NECK, parent="torso")
    b = limb([(0.0, -0.08, 5.98), (0.0, -0.04, 6.45)], [0.36, 0.34], spacing=0.7)
    b.append(blob((0.0, -0.08, 6.95), (0.42, 0.42, 0.42)))
    _clay(p, b, 500, "granite", res=0.03)
    me = F.head_mesh({"lips": 1.1})
    lens = F.eye_lens_mesh(me)
    me = sculpt.decimate(me, 3000)
    sculpt.into_part(p, me, "granite", transform=FACE_M)
    # nemes: a hood flaring from the brow to the shoulders, open round the face
    hood = p.lathe([(0.53, 7.08), (0.55, 6.95), (0.57, 6.76), (0.64, 6.52), (0.82, 6.27), (1.0, 6.1), (1.05, 6.02)],
                   "nemes", segments=28, center=(0.0, -0.04, 0.0), squash=(1.0, 1.12), cap_bottom=False, cap_top=False,
                   smooth=True)
    hood = K.keep(p, hood, lambda c: not (c.y > 0.05 and abs(c.x) < 0.47 and c.z > 6.18))
    for v in sorted({v for f in hood for v in f.verts}, key=lambda v: tuple(round(c, 5) for c in v.co)):
        k = min(1.0, max(0.0, (7.0 - v.co.z) / 0.85))
        v.co.y = -0.04 + (v.co.y + 0.04) * (1.0 - 0.62 * k)
    K.thicken(p, hood, 0.04)
    band = p.lathe([(0.5, 6.96), (0.535, 6.99), (0.535, 7.09), (0.5, 7.12)], "nemes", segments=24,
                   center=(0.0, 0.02, 0.0), squash=(1.0, 1.05), cap_bottom=False, cap_top=False, smooth=False)
    K.keep(p, band, lambda c: c.y > 0.0)
    for sx in (-1, 1):
        _box_between(p, (sx * 0.54, 0.26, 6.48), (sx * 0.64, 0.6, 5.48), 0.34, 0.08, "nemes")
    # double crown: red deshret round the head, white hedjet rising from it
    p.lathe([(0.53, 7.03), (0.56, 7.08), (0.55, 7.47), (0.53, 7.52), (0.38, 7.52)], "crown_red", segments=24,
            cap_bottom=False, cap_top=False)
    _box_between(p, (0.0, -0.48, 7.42), (0.0, -0.45, 8.15), 0.46, 0.08, "crown_red")
    p.tube([(0.0, 0.4, 7.5), (0.0, 0.47, 7.6), (0.0, 0.54, 7.7), (0.0, 0.58, 7.79), (0.0, 0.55, 7.85),
            (0.0, 0.5, 7.83), (0.0, 0.51, 7.78)], lambda t: 0.035 * (1.0 - 0.4 * t), "crown_red", sides=6)
    p.lathe([(0.4, 7.38), (0.43, 7.62), (0.4, 7.95), (0.32, 8.25), (0.22, 8.48), (0.16, 8.58), (0.16, 8.62),
             (0.2, 8.68), (0.12, 8.74), (0.03, 8.76)], "crown_white", segments=20, center=(0.0, -0.02, 0.0),
            cap_bottom=False)
    K.seg(p, (0.0, 0.47, 6.33), (0.0, 0.6, 5.82), [(0.09, 0.0), (0.1, 0.5), (0.095, 1.0)], "beard", segments=8,
          squash=(1.0, 0.65), smooth=False)
    _head_scale(p)
    return p, lens


def eyes(lens):
    p = Part("eyes", origin=hs((0.0, 0.56, FACE_C.z + F.EYES[1][1] * FACE_S)), parent="head")
    sculpt.into_part(p, lens, "eyes", transform=FACE_M)
    _head_scale(p)
    return p


def uraeus():
    p = Part("uraeus", origin=URAEUS, parent="head")
    hood = p.lathe([(0.0, -0.025), (0.13, -0.02), (0.14, 0.0), (0.13, 0.02), (0.0, 0.03)], "gold", segments=12)
    p.move(hood, T(0.0, 0.6, 7.12) @ R('X', 80) @ K.S(0.62, 1.1, 1.0))
    K.sphere(p, (0.0, 0.63, 7.24), 0.05, "gold", segments=8, rings=5, squash=(1.0, 1.5))
    p.tube([(0.0, 0.58, 6.98), (0.0, 0.62, 7.06), (0.0, 0.6, 7.25), (0.0, 0.62, 7.31)], 0.035, "gold", sides=6)
    p.tube([(0.0, 0.55, 7.22), (0.0, 0.5, 7.38), (0.0, 0.42, 7.48), (0.0, 0.3, 7.53)], lambda t: 0.04 * (1.0 - 0.5 * t),
           "gold", sides=6)
    _head_scale(p)
    return p


def upperarm(sx):
    name = "upperarm_l" if sx < 0 else "upperarm_r"
    sh, el = _sx(SHOULDER, sx), _sx(ELBOW, sx)
    p = Part(name, origin=sh, parent="torso")
    b = limb([sh, (sx * 1.06, 0.02, 5.0), el], [0.4, 0.36, 0.3], spacing=0.7)
    b.append(blob((sx * 1.1, -0.04, 5.42), (0.36, 0.36, 0.42)))
    b.append(blob((sx * 1.04, 0.14, 4.9), (0.3, 0.32, 0.38)))
    _clay(p, b, 750, "granite", res=0.03)
    K.seg(p, (sx * 1.07, 0.0, 5.18), (sx * 1.06, 0.03, 5.0), [(0.37, 0.0), (0.37, 1.0)], "gold", segments=16, caps=False)
    return p


def forearm(sx):
    name = "forearm_l" if sx < 0 else "forearm_r"
    el, wr = _sx(ELBOW, sx), _sx(WRIST, sx)
    p = Part(name, origin=el, parent=name.replace("forearm", "upperarm"))
    b = limb([el, (sx * 0.9, 0.8, 4.18), wr], [0.3, 0.29, 0.22], spacing=0.7)
    _clay(p, b, 600, "granite", res=0.03)
    K.seg(p, (sx * 0.75, 1.26, 4.0), (sx * 0.72, 1.4, 3.985), [(0.24, 0.0), (0.24, 1.0)], "gold", segments=14,
          caps=False)
    return p


def palm(sx):
    name = "palm_l" if sx < 0 else "palm_r"
    p = Part(name, origin=_sx(WRIST, sx), parent=name.replace("palm", "forearm"))
    x = sx * 0.66
    if sx < 0:
        b = [blob((x, 1.62, 3.92), (0.24, 0.3, 0.1)), blob((x, 1.9, 3.88), (0.25, 0.2, 0.09))]
        for k, dx in enumerate((-0.18, -0.06, 0.06, 0.18)):
            ln = (0.32, 0.38, 0.36, 0.28)[k]
            b += limb([(x + dx, 2.04, 3.86), (x + dx, 2.04 + ln, 3.82)], [0.06, 0.05], spacing=0.6)
        b += limb([(x + 0.2, 1.55, 3.92), (x + 0.33, 1.84, 3.87)], [0.07, 0.055], spacing=0.6)
        _clay(p, b, 700, "granite", res=0.018, cut=[((0, 0, 3.78), (0, 0, -1))])
    else:
        b = [blob((x, 1.68, 4.02), (0.23, 0.28, 0.24)), blob((x, 1.9, 4.0), (0.22, 0.17, 0.24))]
        for k in range(4):
            b.append(blob((x + 0.03, 2.04, 3.9 + k * 0.095), (0.14, 0.08, 0.055)))
        b += limb([(x - 0.15, 1.72, 4.2), (x - 0.07, 1.96, 4.22)], [0.07, 0.06], spacing=0.6)
        _clay(p, b, 700, "granite", res=0.018, cut=[((0, 0, 3.79), (0, 0, -1))])
        K.seg(p, (x - 0.36, 1.92, 4.04), (x + 0.36, 1.92, 4.04), [(0.08, 0.0), (0.08, 1.0)], "gold", segments=10)
    return p


# --------------------------------------------------------------------------
# paint
# --------------------------------------------------------------------------

def _part(ctx, *names):
    return np.isin(ctx.part, [IDX[n] for n in names])


def _stone(ctx, seed, polish=0.22):
    s = E.granite(ctx, "red", seed, polish=polish, grain=GRAIN)
    s.shade += np.clip(ctx.curv, 0, 1) * 1.2 - np.clip(-ctx.curv, 0, 1) * 1.4
    return s


def skin(ctx, seed=701):
    """Polished red granite; the face painted: black kohl round the almond
    eyes with the long cosmetic line, painted brows, a dark mouth line."""
    s = _stone(ctx, seed)
    head = np.nonzero(_part(ctx, "head"))[0]
    codes = np.zeros(ctx.N, np.int16)
    for i in head:
        ux, uy, uz = to_unit(ctx.p[i])
        if uy < 0.15:
            continue
        ring = F.in_eye(ux, uz, 1.3) and not F.in_eye(ux, uz, 1.0)
        ax = abs(ux)
        line = 0.2 < ax < 0.3 and abs(uz - (0.058 + (ax - 0.2) * 0.12)) < 0.008
        brow = abs(ux) < 0.24 and abs(ax - 0.15) < 0.09 and abs(uz - (0.115 - (ax - 0.15) ** 2 * 2.0)) < 0.009
        mouth = ax < 0.075 and abs(uz - (-0.232 + 0.012 * (ux / 0.08) ** 2)) < 0.005
        if ring or line or brow:
            codes[i] = EP.INK["black"]
        elif mouth:
            codes[i] = EP.INK["outline"]
    return E.paint_over(ctx, s, codes, np.zeros(ctx.N, np.int16), seed + 1, flake=0.2, wear=0.2)


def collar(ctx, seed=703):
    """Broad collar: rows of faience, gold, carnelian and lapis beads from the
    neck out, a fringe of teardrop pendants at the rim (laid out from the 3D
    position: the part is re-unwrapped)."""
    s = _stone(ctx, seed, 0.25)
    x, y = ctx.p[:, 0], ctx.p[:, 1] + 0.06
    r = np.sqrt((x / 0.95) ** 2 + (y / 0.66) ** 2)
    t = np.clip((r - 0.45) / (1.12 - 0.45), 0.0, 1.0)
    th = np.arctan2(y / 0.66, x / 0.95)
    ix = np.floor(th * 0.85 / ctx.texel).astype(np.int64)
    rows = np.floor(t * 9).astype(np.int64)
    cycle = np.array([EP.INK["gold"], EP.INK["blue"], EP.INK["red"], EP.INK["green"], EP.INK["gold"], EP.INK["blue"],
                      EP.INK["green"], EP.INK["red"], EP.INK["gold"]], np.int16)
    codes = cycle[np.clip(rows, 0, 8)]
    sep = np.mod(np.floor(t * 9 * 8), 8) == 0
    codes = np.where(sep, EP.INK["yellow"], codes).astype(np.int16)
    drop = t > 0.88
    lx = np.mod(ix, 7)
    tear = drop & (np.abs(lx - 3) <= np.floor((1.0 - t) / 0.12 * 3.5))
    codes = np.where(drop, np.where(tear, EP.INK["green"], EP.INK["gold"]), codes).astype(np.int16)
    rims = np.where((np.mod(ix, 3) == 0) & ~drop, -1, 0).astype(np.int16)
    return E.paint_over(ctx, s, codes, rims, seed + 1, flake=0.3, relief=-0.004)


def nemes(ctx, seed=707):
    """Nemes headcloth: stripes of gold and blue fanning down from the brow
    (the gold flaking to granite), a gold brow band."""
    s = _stone(ctx, seed, 0.2)
    z = ctx.p[:, 2]
    st = np.floor(z / 0.085).astype(np.int64)
    codes = np.where(np.mod(st, 2) == 0, EP.INK["gold"], EP.INK["blue"]).astype(np.int16)
    band = z > hs((0, 0, 6.96))[2]
    codes[band] = EP.INK["gold"]
    edge = np.mod(z, 0.085) < ctx.texel
    codes[edge & ~band] = EP.INK["outline"]
    return E.paint_over(ctx, s, codes, np.zeros(ctx.N, np.int16), seed + 1, flake=0.35)


def crown_red(ctx, seed=709):
    s = _stone(ctx, seed)
    return E.paint_over(ctx, s, np.full(ctx.N, EP.INK["red"], np.int16), np.zeros(ctx.N, np.int16), seed + 1,
                        flake=0.4)


def crown_white(ctx, seed=711):
    s = _stone(ctx, seed)
    return E.paint_over(ctx, s, np.full(ctx.N, EP.INK["white"], np.int16), np.zeros(ctx.N, np.int16), seed + 1,
                        flake=0.45)


def kilt(ctx, seed=713):
    """Pleated royal kilt: a groove every 6 cm along the pleats, traces of
    gold on the ridges, a gold hem."""
    s = _stone(ctx, seed, 0.24)
    thighs = _part(ctx, "thigh_l", "thigh_r")
    x = ctx.p[:, 0]
    groove = thighs & (np.mod(x + 0.03, 0.06) < 0.012)
    s.shade[groove] -= 1.6
    s.height = s.height - groove * 0.006
    codes = np.zeros(ctx.N, np.int16)
    codes[thighs & (ctx.p[:, 1] > 1.72)] = EP.INK["gold"]
    codes[thighs & ~groove & (ctx.fbm(3.0, 3, seed) > 0.25)] = EP.INK["yellow"]
    return E.paint_over(ctx, s, codes, np.zeros(ctx.N, np.int16), seed + 1, flake=0.35)


def belt(ctx, seed=717):
    s = E.gold_leaf(ctx, seed)
    th = np.arctan2((ctx.p[:, 1] + 0.05) / 0.7, ctx.p[:, 0])
    ix = np.floor(th * 0.9 / ctx.texel).astype(np.int64)
    iy = np.floor(ctx.p[:, 2] / ctx.texel).astype(np.int64)
    chev = np.abs(np.mod(ix, 12) - 6) == np.mod(iy, 6)
    s.use_ramp(P["eg_blue"], mask=chev, shade=np.full(ctx.N, 3.4))
    s.metal = np.where(chev, 0.0, s.metal)
    return s


def beard(ctx, seed=719):
    s = _stone(ctx, seed, 0.24)
    plait = np.mod(ctx.p[:, 2], 0.065) < 0.016
    s.shade[plait] -= 1.5
    s.height = s.height - plait * 0.004
    return s


def eye_paint(ctx, seed=721):
    """Inlaid eyes: pale gold-white with a darker heart, faintly self-lit (at
    rest a glint; the attack telegraph turns them into suns)."""
    s = Surface(ctx.N)
    x, z = ctx.p[:, 0], ctx.p[:, 2]
    d = np.sqrt((np.abs(x) - EYE[0]) ** 2 + (z - EYE[2]) ** 2)
    s.use_ramp(P["sun_glow"], shade=np.full(ctx.N, 6.2) - d * 8.0)
    s.rough = np.full(ctx.N, 0.15)
    s.emit = s.colors() * 0.55
    return s


def crack_glow(ctx, seed=723):
    return E.glow(ctx, "sun_glow", 4.6, strength=1.2, seed=seed, flicker=0.9)


_THRONE = {}


def _throne_side(w, h):
    key = (w, h)
    if key not in _THRONE:
        c = np.zeros((h, w), dtype=np.int16)
        bb = EP.block_border(w, 5, 5)
        c[0:5] = bb
        c[h - 5:h] = bb
        c[:, 0:4] = EP.INK["blue"]
        c[:, w - 4:w] = EP.INK["blue"]
        st = EP.sema_tawy(w - 16, h - 12, seed=3)
        c[7:7 + st.shape[0], 8:8 + st.shape[1]] = np.where(st > 0, st, c[7:7 + st.shape[0], 8:8 + st.shape[1]])
        _THRONE[key] = c
    return _THRONE[key]


def _plinth_band(w, h, seed):
    key = ("plinth", w, h, seed)
    if key not in _THRONE:
        rng = random.Random(seed)
        c = np.zeros((h, w), dtype=np.int16)
        line = EP.text_line(w, seed)
        big = np.repeat(np.repeat(line, 2, 0), 2, 1)[:, :w]
        big = big[:min(big.shape[0], h)]
        y = (h - big.shape[0]) // 2
        c[y:y + big.shape[0], :big.shape[1]] = big
        for cx in (w // 2 - 50, w // 2 + 26):
            cart = EP.cartouche(rng, 12, h // 2)
            cart = np.repeat(np.repeat(cart, 2, 0), 2, 1)[:h]
            cy = (h - cart.shape[0]) // 2
            c[cy:cy + cart.shape[0], cx:cx + cart.shape[1]] = cart
        _THRONE[key] = c
    return _THRONE[key]


def throne_paint(ctx, seed=731):
    """Throne block: polished red granite; both sides carved in raised relief
    with the Union of the Two Lands in a border; dark holes low on the sides
    where the swarms come out."""
    s = E.granite(ctx, "red", seed, polish=0.22, grain=0.6)
    y, z = ctx.p[:, 1], ctx.p[:, 2]
    tx = ctx.texel
    codes = np.full(ctx.N, -1, np.int16)
    rims = np.zeros(ctx.N, np.int16)
    canvas = _throne_side(int(round(2.7 / tx)), int(round(2.05 / tx)))
    for sgn, u0 in ((1, -1.1), (-1, -1.6)):
        m = (ctx.n[:, 0] * sgn > 0.9) & (z > PLINTH_TOP + 0.08) & (z < SEAT - 0.08)
        if m.any():
            c, r = E.sample(canvas, ctx.uvm[m, 0], z[m], tx, u0=u0, v0=PLINTH_TOP + 0.1)
            codes[m] = c
            rims[m] = r
    s = E.paint_over(ctx, s, codes, rims, seed + 1, flake=0.35, relief=0.005)
    for sx in (-1, 1):
        d = np.sqrt((y - 0.9) ** 2 + ((z - 1.0) * 1.3) ** 2)
        hole = (ctx.n[:, 0] * sx > 0.9) & (d < 0.24 + ctx.fbm(9.0, 2, seed + 3) * 0.08)
        s.use_ramp(P["eg_black"], mask=hole, shade=np.full(ctx.N, 0.6))
        s.height = s.height - hole * 0.02
    return s


def plinth_paint(ctx, seed=737):
    """Plinth: dressed granite with a line of large signs and the king's two
    cartouches round its faces."""
    s = E.granite(ctx, "red", seed, polish=0.3, grain=0.6)
    z = ctx.p[:, 2]
    tx = ctx.texel
    m = (np.abs(ctx.n[:, 2]) < 0.5) & (z > 0.05) & (z < PLINTH_TOP - 0.05)
    if m.any():
        band = _plinth_band(int(round(6.0 / tx)), int(round((PLINTH_TOP - 0.1) / tx)), seed)
        c, r = E.sample(band, ctx.uvm[m, 0] + 3.0, z[m], tx, v0=0.05, wrap_x=True)
        codes = np.full(ctx.N, -1, np.int16)
        rims = np.zeros(ctx.N, np.int16)
        codes[m] = c
        rims[m] = r
        s = E.paint_over(ctx, s, codes, rims, seed + 1, flake=0.4, relief=-0.004)
    return s


def pillar_paint(ctx, seed=741):
    """Back pillar: one column of large signs down its back."""
    s = E.granite(ctx, "red", seed, polish=0.25, grain=0.6)
    back = ctx.n[:, 1] < -0.9
    if back.any():
        col = np.repeat(np.repeat(EP.text_columns(1, 10, seed, col_w=14, cell=10, gap=1, divider=False,
                                                  cartouches=0.1), 2, 0), 2, 1)
        c, r = E.sample(col, ctx.uvm[back, 0], ctx.p[back, 2], ctx.texel, u0=-0.19, v0=SEAT + 0.2)
        codes = np.full(ctx.N, -1, np.int16)
        rims = np.zeros(ctx.N, np.int16)
        codes[back] = c
        rims[back] = r
        s = E.paint_over(ctx, s, codes, rims, seed + 1, flake=0.4, relief=-0.004)
    return s


def build():
    pel = pelvis()
    legs = []
    for sx in (-1, 1):
        legs += [thigh(sx), shin(sx), foot(sx)]
    tor = torso()
    arms = []
    for sx in (-1, 1):
        arms += [upperarm(sx), forearm(sx), palm(sx)]
    plates, glows = cracks(tor)
    hd, lens = head()
    by = {p.name: p for p in [pel, tor, hd, eyes(lens), uraeus()] + legs + arms + plates + glows}
    parts = [by[n] for n in ORDER]
    fns = {"granite": skin, "collar": collar, "nemes": nemes, "crown_red": crown_red, "crown_white": crown_white,
           "kilt": kilt, "belt": belt, "beard": beard, "eyes": eye_paint, "crackglow": crack_glow,
           "gold": lambda c: E.gold_leaf(c, 751)}
    ey = (EYE[0], EYE[1] + 0.014, EYE[2])
    markers = [("eye_l", (-ey[0], ey[1], ey[2]), "head"), ("eye_r", ey, "head"),
               ("hand_l", (-0.66, 2.0, 3.78), "palm_l"), ("hand_r", (0.66, 1.85, 3.79), "palm_r")]
    face = hs((0.0, 0.45, 6.78))
    body = Model("colossus", parts, fns, ppm=112, organic=tuple(n for n in ORDER if not n.startswith("crack_")),
                 ground=PLINTH_TOP, ao_dist=0.6, ao_rays=10, ao_stride=2, front=1, normal_strength=1.6,
                 markers=markers, preview_yaws=(-30.0, 30.0, 90.0, 200.0), preview_elevation=8.0,
                 preview_closeup=(face, 1.1),
                 preview_extra=[("chest", (0.0, 0.6, 4.95), 1.4, 15.0, 5.0), ("hands", (0.0, 1.9, 3.9), 1.7, 0.0, 30.0),
                                ("crown", (0.0, 0.3, 7.7), 1.5, 35.0, 10.0)])
    seat = Model("colossus_throne", [throne()], {"throne": throne_paint, "plinth": plinth_paint,
                                                  "pillar": pillar_paint},
                 ppm=72, ground=0.0, ao_dist=0.5, ao_rays=10, ao_stride=2, front=1,
                 markers=[("swarm_l", (-1.62, 0.9, 1.0), None), ("swarm_r", (1.62, 0.9, 1.0), None)],
                 preview_extra=[("side", (1.6, 0.2, 1.75), 2.0, 90.0, 5.0)])
    return [body, seat]
