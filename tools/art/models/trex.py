"""The T-Rex skeleton boss: the lobby's museum mount come to life. About
11 m from snout to tail tip, the top of the hips about 5 m up. Fossil-brown
bone with pale plaster repairs, an iron armature bar along the spine with
strap clamps, rods and clamps on the legs, and the sheared-off stubs of the
two support posts it tore free from its plinth.

Faces +Y in Blender = -Z in Godot. Origin on the floor under the hip joints.
Parts (Godot node names) in a joint hierarchy, each pivot at its joint:
    pelvis                         hips, sacrum, pubic "boot"        root
    spine_1 > spine_2 > spine_3    back (dorsal vertebrae), hips -> shoulders
    ribs                           rib cage + belly ribs (child of spine_2);
                                   marker CrystalSocket sits in the wide gap
                                   between the 5th and 6th ribs
    neck_1 > neck_2 > neck_3 > skull > jaw
    arm_l, arm_r                   the little arms (children of spine_3)
    thigh_l > shin_l > foot_l      (and _r), children of pelvis
    tail_1 > ... > tail_8          children chain from the pelvis
Every chain part's pivot is on the spine curve at the joint nearer the hips.
"""
import math
import random

import numpy as np
from mathutils import Matrix, Vector

from artlib import kit
from artlib import materials as M
from artlib import sculpt
from artlib.geo import Part
from artlib.kit import R, T
from artlib.model import Model
from artlib.sculpt import blob, limb

# spine centre line (y forward, z up), tail tip -> base of the skull
AXIS = [(-5.3, 3.0), (-4.6, 3.3), (-3.7, 3.68), (-2.8, 4.0), (-1.9, 4.24), (-1.1, 4.38), (-0.55, 4.44),
        (0.0, 4.47), (0.55, 4.45), (1.45, 4.37), (2.3, 4.21), (3.15, 4.02), (3.55, 4.03), (3.9, 4.16),
        (4.15, 4.3)]
HIP = (0.36, 0.0, 4.1)
KNEE = (0.47, 0.5, 2.62)
ANKLE = (0.47, -0.22, 1.05)
SHOULDER = (0.42, 2.85, 3.52)
SOCKET = (0.0, 1.86, 3.25)
SKULL_BASE = Vector((0.0, 4.13, 4.24))
SKULL_PITCH = -8.0
TAIL_SEGS = 8
BONE_TRIS = {}


# --------------------------------------------------------------------------
# spine curve
# --------------------------------------------------------------------------

def _catmull(pts, n=24):
    out = []
    P = [pts[0]] + pts + [pts[-1]]
    for i in range(1, len(P) - 2):
        p0, p1, p2, p3 = (np.array(P[k]) for k in (i - 1, i, i + 1, i + 2))
        for k in range(n):
            t = k / n
            out.append(0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t * t
                              + (-p0 + 3 * p1 - 3 * p2 + p3) * t ** 3))
    out.append(np.array(pts[-1]))
    return np.array(out)


CURVE = _catmull(AXIS)
ARC = np.concatenate([[0.0], np.cumsum(np.linalg.norm(np.diff(CURVE, axis=0), axis=1))])


def at_y(y):
    """Point (Vector) and unit tangent (toward the head) on the spine at ``y``."""
    ys = CURVE[:, 0]
    i = int(np.clip(np.searchsorted(ys, y) - 1, 0, len(ys) - 2))
    t = (y - ys[i]) / max(ys[i + 1] - ys[i], 1e-9)
    p = CURVE[i] * (1 - t) + CURVE[i + 1] * t
    d = CURVE[i + 1] - CURVE[i]
    d = d / np.linalg.norm(d)
    return Vector((0.0, p[0], p[1])), Vector((0.0, d[0], d[1]))


def arc_of(y):
    ys = CURVE[:, 0]
    return float(np.interp(y, ys, ARC))


def y_of(arc):
    return float(np.interp(arc, ARC, CURVE[:, 0]))


def frame(y):
    """Matrix: local +Y along the spine (toward the head), +Z up, at ``y``."""
    p, t = at_y(y)
    up = Vector((0, 0, 1))
    up = (up - t * up.dot(t)).normalized()
    x = t.cross(up)
    m = Matrix(((x.x, t.x, up.x, p.x), (x.y, t.y, up.y, p.y), (x.z, t.z, up.z, p.z), (0, 0, 0, 1)))
    return m


# --------------------------------------------------------------------------
# vertebrae
# --------------------------------------------------------------------------

def vertebra(p, y, r, spine_h, spine_tilt=-15.0, spine_w=None, chevron=0.0, transverse=0.0, length=0.2,
             cervical_rib=0.0, bar=True):
    """One vertebra at spine position ``y``: spool-shaped centrum, neural
    arch with a spine, optional transverse processes, chevron (haemal arch
    under the tail) and cervical ribs. Built in the spine frame."""
    f = []
    L = length * 0.82
    f += p.lathe([(r * 0.95, -L / 2), (r, -L / 2 + L * 0.12), (r * 0.8, 0.0), (r, L / 2 - L * 0.12),
                  (r * 0.95, L / 2)], "bone", segments=8, center=(0, 0, 0), smooth=True)
    for face in f:
        pass
    centrum = f
    p.move(centrum, R('X', -90))                    # lathe axis Z -> spine +Y
    out = list(centrum)
    # neural arch and spine
    w = spine_w if spine_w is not None else max(r * 0.55, 0.02)
    out += p.box((0, 0, r * 1.25), (r * 1.3, L * 0.8, r * 0.7), "bone")
    if spine_h > 0.02:
        sp = p.box((0, 0, 0), (w * 0.6, L * 0.5, spine_h), "bone", bevel=min(0.012, w * 0.15))
        p.move(sp, T(0, 0, r * 1.5) @ R('X', spine_tilt) @ T(0, 0, spine_h / 2))
        out += sp
    if transverse > 0.02:
        for sx in (-1, 1):
            tp = p.box((0, 0, 0), (transverse, L * 0.45, r * 0.3), "bone")
            p.move(tp, T(sx * (r * 0.6 + transverse / 2), 0, r * 1.05) @ R('Y', -sx * 12))
            out += tp
    if chevron > 0.02:
        ch = p.box((0, 0, 0), (r * 0.5, L * 0.35, chevron), "bone")
        p.move(ch, T(0, -L * 0.2, -r * 0.9) @ R('X', 35) @ T(0, 0, -chevron / 2))
        out += ch
    if cervical_rib > 0.02:
        for sx in (-1, 1):
            out += p.tube([(sx * r * 1.1, 0.0, -r * 0.2), (sx * r * 1.4, -cervical_rib * 0.5, -r * 0.6),
                           (sx * r * 1.3, -cervical_rib, -r * 0.8)], r * 0.18, "bone", sides=4, smooth=False)
    p.move(out, frame(y))
    return out


def armature(p, y0, y1, r_hint, clamps=()):
    """Square iron bar along the spine between y0 and y1, just above the
    centra (through the neural arches), with strap clamps."""
    n = max(2, int(abs(y1 - y0) / 0.15) + 1)
    ys = np.linspace(y0, y1, n)
    pts = []
    for y in ys:
        m = frame(y)
        pts.append(tuple(m @ Vector((0, 0, r_hint * 1.25))))
    p.tube(pts, 0.022, "iron", sides=4, smooth=False, caps=True)
    for y in clamps:
        c = p.box((0, 0, r_hint * 0.45), (r_hint * 2.4, 0.05, r_hint * 2.3), "iron")
        bolts = [p.box((sx * r_hint * 1.25, 0, r_hint * 1.3), (0.03, 0.03, 0.03), "iron") for sx in (-1, 1)]
        faces = c + bolts[0] + bolts[1]
        p.move(faces, frame(y))


def _series(p, y0, y1, spacing, params, clamps=()):
    """Vertebrae from y0 toward y1 (either direction) every ``spacing``
    metres along the curve; ``params(y)`` -> vertebra kwargs."""
    a0, a1 = arc_of(y0), arc_of(y1)
    n = max(1, int(round(abs(a1 - a0) / spacing)))
    step = (a1 - a0) / n
    rs = []
    for k in range(n):
        y = y_of(a0 + step * (k + 0.5))
        kw = params(y)
        vertebra(p, y, length=abs(step), **kw)
        rs.append(kw["r"])
    armature(p, y0, y1, float(np.mean(rs)), clamps=[y_of(a0 + step * (k + 0.5)) for k in clamps])


def tail_params(y):
    t = np.clip((-0.55 - y) / (5.3 - 0.55), 0.0, 1.0)          # 0 at the hips, 1 at the tip
    return dict(r=0.11 * (1 - t) + 0.028 * t, spine_h=max(0.0, 0.34 * (1 - t / 0.5)),
                chevron=max(0.0, 0.34 * (1 - t / 0.8)), transverse=max(0.0, 0.26 * (1 - t / 0.35)),
                spine_tilt=-35.0)


def back_params(y):
    return dict(r=0.12, spine_h=0.5 - 0.1 * max(0.0, (y - 2.3) / 0.85), spine_tilt=-10.0, transverse=0.22,
                spine_w=0.12)


def neck_params(y):
    return dict(r=0.15, spine_h=0.16, spine_tilt=-25.0, transverse=0.14, cervical_rib=0.3, spine_w=0.14)


# --------------------------------------------------------------------------
# skull
# --------------------------------------------------------------------------

def _mirror(fn):
    out = []
    for sx in (-1, 1):
        out += fn(sx)
    return out


def _skull_blobs():
    """Strut-built skull, like the real one seen from the side: the openings
    (antorbital fenestra, orbit, laterotemporal fenestra) are the gaps
    between bone bars. Skull frame: occiput at y 0, snout tip at y ~1.45,
    jaw joint at z 0, x = right."""
    def side(sx):
        b = []
        b += limb([(sx * 0.27, 0.04, -0.07), (sx * 0.27, 0.12, 0.13), (sx * 0.23, 0.08, 0.4)], [0.07, 0.06, 0.055], squash=0.6)  # quadratojugal -> squamosal
        b += limb([(sx * 0.28, 0.08, -0.02), (sx * 0.26, 0.3, 0.02), (sx * 0.22, 0.6, 0.0)], [0.075, 0.07, 0.07], squash=0.6)    # jugal
        b += limb([(sx * 0.25, 0.38, 0.04), (sx * 0.23, 0.39, 0.25), (sx * 0.21, 0.37, 0.43)], [0.06, 0.055, 0.065], squash=0.6)  # postorbital
        b += limb([(sx * 0.2, 0.6, 0.02), (sx * 0.19, 0.58, 0.28), (sx * 0.16, 0.56, 0.47)], [0.06, 0.055, 0.06], squash=0.6)     # lacrimal
        b += limb([(sx * 0.21, 0.37, 0.43), (sx * 0.2, 0.1, 0.42)], [0.06, 0.055], squash=0.6)                                   # skull roof edge
        b.append(blob((sx * 0.175, 0.56, 0.49), (0.07, 0.09, 0.06)))                   # lacrimal horn
        b.append(blob((sx * 0.215, 0.37, 0.44), (0.06, 0.06, 0.055)))                  # postorbital boss
        b.append(blob((sx * 0.17, 0.96, 0.02), (0.04, 0.44, 0.15), rot=(0, 0, sx * 5)))  # maxilla plate
        b += limb([(sx * 0.16, 1.02, 0.02), (sx * 0.1, 1.1, 0.2), (sx * 0.06, 1.12, 0.28)], [0.05, 0.045, 0.045], squash=0.6)  # ascending process
        b += limb([(sx * 0.2, 0.6, -0.02), (sx * 0.17, 0.75, -0.03)], [0.07, 0.07], squash=0.6)
        b.append(blob((sx * 0.27, 0.06, -0.08), (0.06, 0.06, 0.05)))                   # jaw joint
        return b
    b = _mirror(side)
    b += limb([(0, 0.5, 0.49), (0, 0.8, 0.41), (0, 1.1, 0.29), (0, 1.38, 0.16)], [0.075, 0.07, 0.065, 0.06])  # nasals
    b += [
        blob((0, 0.46, 0.47), (0.2, 0.1, 0.05)),              # skull roof between the eyes
        blob((0, 0.22, 0.26), (0.13, 0.18, 0.19)),            # braincase
        blob((0, 0.06, 0.37), (0.22, 0.06, 0.12)),            # occiput / nuchal crest
        blob((0, 0.2, 0.47), (0.03, 0.2, 0.05)),              # sagittal crest
        blob((0, 0.95, -0.03), (0.13, 0.42, 0.04)),           # palate
        blob((0, 1.37, 0.05), (0.12, 0.09, 0.15)),            # premaxillae (snout front)
    ]
    return b


def _jaw_blobs():
    def side(sx):
        return [
            blob((sx * 0.165, 0.85, -0.19), (0.04, 0.52, 0.1), rot=(0, 0, sx * 6)),   # dentary
            blob((sx * 0.25, 0.25, -0.17), (0.045, 0.26, 0.12)),                      # surangular
            blob((sx * 0.25, 0.3, -0.18), (0.25, 0.09, 0.045), neg=True, stiff=3.0),  # mandibular fenestra
            blob((sx * 0.27, 0.05, -0.12), (0.06, 0.07, 0.06)),                       # articular
        ]
    b = _mirror(side)
    b.append(blob((0, 1.32, -0.19), (0.1, 0.07, 0.075)))                                # chin
    return b


def _teeth(p, upper, rng):
    """Banana teeth along the tooth rows (skull-local frame)."""
    rows = []
    for sx in (-1, 1):
        for k in range(11):
            t = k / 10
            y = 0.62 + t * 0.7
            x = sx * (0.18 - t * 0.075)
            ln = 0.085 + 0.06 * math.sin(math.pi * min(1.0, t * 1.4)) + rng.uniform(-0.012, 0.012)
            if upper:
                rows.append(((x, y, -0.1), (sx * 0.1, 0.15, -1), ln, 0.025))
            else:
                rows.append(((x * 0.95, y - 0.03, -0.1), (sx * 0.1, 0.12, 1), ln * 0.85, 0.022))
    if upper:
        for k, x in enumerate((-0.055, -0.018, 0.018, 0.055)):
            rows.append(((x, 1.41, -0.06), (0, 0.25, -1), 0.07, 0.018))
    for base, d, ln, r in rows:
        kit.cone(p, base, d, ln, r, "tooth", segments=5, tip=0.0)


# --------------------------------------------------------------------------
# pelvis, limbs
# --------------------------------------------------------------------------

def _pelvis(p):
    # iliac blades: long vertical plates either side of the sacrum
    outline = []
    for k in range(20):
        a = math.tau * k / 20
        yy = 0.78 * math.cos(a)
        zz = 0.26 * math.sin(a) * (1.0 if math.sin(a) > 0 else 0.7)
        if math.sin(a) > 0:
            zz += 0.06 * math.cos(a)                    # the front lobe rises a little
        outline.append((yy, zz))
    for sx in (-1, 1):
        f = p.ngon_prism(outline, -0.035, 0.035, "bone", bevel=0.012)
        p.move(f, T(sx * 0.27, 0.0, 4.5) @ R('Y', 90) @ R('Z', 90))
    # acetabulum rim and the heavy pubis with its boot, ischium behind
    for sx in (-1, 1):
        kit.seg(p, (sx * 0.3, 0.2, 4.1), (sx * 0.13, 0.72, 2.8), [(0.09, 0), (0.07, 0.5), (0.08, 1.0)], "bone",
                segments=8)
        kit.seg(p, (sx * 0.3, -0.25, 4.1), (sx * 0.12, -0.72, 3.2), [(0.08, 0), (0.055, 0.6), (0.06, 1.0)],
                "bone", segments=8)
        kit.sphere(p, (sx * 0.31, 0.0, 4.12), 0.14, "bone", segments=8, rings=4)
    kit.sphere(p, (0.0, 0.78, 2.66), 0.2, "bone", segments=10, rings=5, squash=(0.9, 2.3), zscale=0.55)   # boot
    # sacrum: fused vertebrae with one spine plate
    _series(p, -0.55, 0.55, 0.22, lambda y: dict(r=0.13, spine_h=0.5, spine_tilt=-5.0, spine_w=0.12,
                                                  transverse=0.22), clamps=(1, 3))
    # broken support post under the hips
    _post(p, (0.0, -0.1, 3.95), 0.75)


def _post(p, top, length):
    """Sheared-off iron support post with a flange and a jagged end."""
    x, y, z = top
    rng = random.Random(int(abs(y) * 100) + 3)
    f = p.lathe([(0.055, -length), (0.05, -length * 0.5), (0.05, 0.0)], "iron", segments=8, center=(x, y, z),
                cap_bottom=True, cap_top=False, smooth=True)
    for v in sorted({v for face in f for v in face.verts}, key=lambda v: tuple(v.co)):   # fixed order for the RNG
        if v.co.z < z - length + 0.01:
            v.co.z += rng.uniform(-0.06, 0.05)
    p.lathe([(0.13, -0.02), (0.13, 0.02), (0.06, 0.03)], "iron", segments=8, center=(x, y, z), smooth=False)


def _leg(thigh, shin, foot, sx):
    hip, knee, ankle = Vector((sx * HIP[0], HIP[1], HIP[2])), Vector((sx * KNEE[0], *KNEE[1:])), \
        Vector((sx * ANKLE[0], *ANKLE[1:]))
    # femur with its head turned in, a trochanter, knobbly condyles
    kit.seg(thigh, hip + Vector((0, 0.02, 0.05)), knee, [(0.17, 0.0), (0.13, 0.2), (0.11, 0.55), (0.13, 0.85),
                                                         (0.19, 0.97), (0.15, 1.0)], "bone", segments=10)
    kit.sphere(thigh, hip + Vector((-sx * 0.1, 0.0, 0.05)), 0.14, "bone", segments=8, rings=4)
    kit.sphere(thigh, hip + Vector((sx * 0.05, 0.12, 0.12)), 0.11, "bone", segments=8, rings=4)
    rod = [hip + Vector((sx * 0.02, -0.16, 0.0)), (hip + knee) * 0.5 + Vector((sx * 0.02, -0.17, 0)),
           knee + Vector((sx * 0.02, -0.18, 0.15))]
    thigh.tube(rod, 0.02, "iron", sides=6)
    for k in (0.3, 0.7):
        c = hip.lerp(knee, k)
        cl = thigh.box((0, 0, 0), (0.22, 0.24, 0.05), "iron")
        thigh.move(cl, kit.align(c, c + (knee - hip).normalized()) @ T(0, -0.06, 0) @ R('X', 90))
    # tibia with the cnemial crest, fibula alongside, iron rod behind
    kit.seg(shin, knee + Vector((0, 0.05, 0.02)), ankle, [(0.18, 0.0), (0.13, 0.12), (0.1, 0.5), (0.105, 0.9),
                                                         (0.14, 1.0)], "bone", segments=10)
    kit.seg(shin, knee + Vector((sx * 0.11, -0.02, -0.05)), ankle + Vector((sx * 0.09, 0.02, 0.08)),
            [(0.045, 0), (0.03, 0.5), (0.04, 1.0)], "bone", segments=6)
    rod = [knee + Vector((sx * 0.02, -0.18, 0.15)), (knee + ankle) * 0.5 + Vector((0, -0.14, 0)),
           ankle + Vector((0, -0.12, 0.05))]
    shin.tube(rod, 0.02, "iron", sides=6)
    c = knee.lerp(ankle, 0.55)
    cl = shin.box((0, 0, 0), (0.2, 0.2, 0.05), "iron")
    shin.move(cl, kit.align(c, c + (ankle - knee).normalized()) @ T(0, -0.05, 0) @ R('X', 90))
    # foot: ankle block, three metatarsals, three toes with claws, dewclaw
    kit.sphere(foot, ankle, 0.14, "bone", segments=8, rings=4, zscale=0.7)
    toes = ((-0.13, -16.0, 0.42), (0.0, 0.0, 0.55), (0.13, 18.0, 0.46))
    for dx, ang, tl in toes:
        base = ankle + Vector((sx * dx * 0.5, -0.02, -0.05))
        end = Vector((ankle.x + sx * dx * 1.2, 0.22, 0.2))
        kit.seg(foot, base, end, [(0.06, 0.0), (0.045, 0.5), (0.06, 1.0)], "bone", segments=7)
        d = Vector((math.sin(math.radians(sx * ang)), math.cos(math.radians(sx * ang)), 0.0))
        pts = [end, end + d * tl * 0.35 + Vector((0, 0, -0.08)), end + d * tl * 0.7 + Vector((0, 0, -0.12)),
               end + d * tl + Vector((0, 0, -0.13))]
        radii = (0.055, 0.045, 0.038, 0.03)
        for k in range(3):
            kit.seg(foot, pts[k], pts[k + 1], [(radii[k], 0.0), (radii[k] * 0.8, 0.5), (radii[k + 1], 1.0)],
                    "bone", segments=6)
        kit.cone(foot, pts[3], d + Vector((0, 0, -0.5)), 0.13, 0.034, "tooth", segments=5)
    kit.seg(foot, ankle + Vector((-sx * 0.08, -0.05, -0.2)), ankle + Vector((-sx * 0.12, 0.05, -0.55)),
            [(0.035, 0), (0.025, 1.0)], "bone", segments=5)
    # the lowest point sits on the floor
    lo = min(v.co.z for v in foot.bm.verts)
    foot.move(list(foot.bm.faces), T(0, 0, -lo))


def _arm(p, sx):
    sh = Vector((sx * SHOULDER[0], *SHOULDER[1:]))
    elbow = sh + Vector((sx * 0.04, 0.16, -0.36))
    wrist = elbow + Vector((-sx * 0.02, 0.2, -0.12))
    kit.seg(p, sh, elbow, [(0.065, 0), (0.045, 0.5), (0.06, 1.0)], "bone", segments=7)
    kit.seg(p, elbow, wrist, [(0.045, 0), (0.035, 0.5), (0.04, 1.0)], "bone", segments=6)
    for dx in (-0.025, 0.025):
        tip = wrist + Vector((sx * dx, 0.1, -0.06))
        kit.seg(p, wrist, tip, [(0.025, 0), (0.02, 1.0)], "bone", segments=5)
        kit.cone(p, tip, (0, 0.6, -1), 0.07, 0.018, "tooth", segments=4)


def _shoulder_girdle(p, sx):
    top = Vector((sx * 0.3, 2.55, 4.15))
    low = Vector((sx * 0.44, 2.88, 3.5))
    kit.seg(p, top, low, [(0.07, 0), (0.05, 0.5), (0.1, 1.0)], "bone", segments=6, squash=(0.5, 1.0))
    kit.sphere(p, low + Vector((sx * -0.05, 0.08, -0.08)), 0.12, "bone", segments=8, rings=4, squash=(0.45, 1.0))


# --------------------------------------------------------------------------
# ribs
# --------------------------------------------------------------------------

RIB_YS = [0.72, 0.92, 1.13, 1.34, 1.55, 2.14, 2.35, 2.56, 2.77, 2.98]   # wide gap 1.55 -> 2.14 (the socket)


def _rib_shape(y):
    """(depth, half width) of the rib hanging at ``y``: longest mid-chest."""
    t = (y - 0.72) / (2.98 - 0.72)
    depth = 1.35 + 0.8 * math.sin(math.pi * min(1.0, max(0.0, 0.25 + t * 0.9)))
    width = 0.66 + 0.28 * math.sin(math.pi * min(1.0, max(0.0, 0.2 + t)))
    return depth, width


def _ribs(p):
    for k, y in enumerate(RIB_YS):
        depth, width = _rib_shape(y)
        m = frame(y)
        base = m @ Vector((0, 0, 0.1))
        for sx in (-1, 1):
            pts = []
            for j in range(9):
                a = j / 8
                x = sx * (0.16 + width * math.sin(a * math.pi * 0.62) * 1.05)
                z = -depth * (a ** 1.15)
                yy = -0.22 * a - 0.05 * math.sin(a * math.pi)
                pts.append(tuple(Vector((x, base.y + yy, base.z + z)) + Vector((0, 0, 0.12 * math.sin(a * math.pi)))))
            p.tube(pts, lambda u: 0.05 * (1 - u) + 0.026 * u, "bone", sides=6, smooth=True)
    # gastralia: V-shaped belly ribs, open under the socket
    for k in range(12):
        y = 0.62 + k * 0.2
        if 1.6 < y < 2.14:
            continue
        depth, width = _rib_shape(y)
        zb = frame(y + 0.2).translation.z + 0.1 - depth + 0.08
        for sx in (-1, 1):
            p.tube([(sx * width * 0.75, y - 0.1, zb + 0.14), (sx * width * 0.4, y - 0.02, zb + 0.02),
                    (0.0, y + 0.06, zb - 0.03)], 0.024, "bone", sides=5)
    # broken support post under the chest, bolted to a cross strap
    p.box((0, 1.95, 2.52), (1.0, 0.08, 0.04), "iron")
    _post(p, (0.0, 1.95, 2.5), 0.5)


# --------------------------------------------------------------------------
# paint
# --------------------------------------------------------------------------

def trex_bone(ctx):
    s = M.bone(ctx, center=5.4)
    # each bone got a slightly different tone (different finds, different casts)
    tone = M.noise.rand_cells(ctx.part, 17) - 0.5
    s.shade += tone * 1.4
    return s


def build():
    rng = random.Random(11)
    parts = []
    pelvis = Part("pelvis", origin=(0, 0, 4.2))
    _pelvis(pelvis)
    parts.append(pelvis)
    # back
    back = [("spine_1", 0.55, 1.45, "pelvis"), ("spine_2", 1.45, 2.3, "spine_1"), ("spine_3", 2.3, 3.15, "spine_2")]
    for name, y0, y1, parent in back:
        prt = Part(name, origin=tuple(at_y(y0)[0]), parent=parent)
        _series(prt, y0, y1, 0.22, back_params, clamps=(1,))
        parts.append(prt)
    spine_3 = parts[-1]
    for sx in (-1, 1):
        _shoulder_girdle(spine_3, sx)
    ribs = Part("ribs", origin=tuple(at_y(1.86)[0]), parent="spine_2")
    _ribs(ribs)
    parts.append(ribs)
    # neck
    neck = [("neck_1", 3.15, 3.5, "spine_3"), ("neck_2", 3.5, 3.85, "neck_1"), ("neck_3", 3.85, 4.15, "neck_2")]
    for name, y0, y1, parent in neck:
        prt = Part(name, origin=tuple(at_y(y0)[0]), parent=parent)
        _series(prt, y0, y1, 0.14, neck_params)
        parts.append(prt)
    # skull and jaw, sculpted in a skull frame (occiput at y 0, jaw joint at z 0)
    place = T(*SKULL_BASE) @ R('X', SKULL_PITCH) @ kit.S(1.12, 1.12, 1.12)
    skull = Part("skull", origin=tuple(place @ Vector((0, 0.02, 0.12))), parent="neck_3")
    me = sculpt.metaball_mesh(_skull_blobs(), resolution=0.014)
    sculpt.cut(me, [((0, 0, -0.1), (0, 0, -1))])
    me = sculpt.decimate(me, 4200)
    sculpt.into_part(skull, me, "bone", transform=place)
    tf = []
    _teeth(skull, True, rng)
    skull.move([f for f in skull.bm.faces if skull.slots[f.material_index] == "tooth"], place)
    jaw = Part("jaw", origin=tuple(place @ Vector((0, 0.08, -0.12))), parent="skull")
    me = sculpt.metaball_mesh(_jaw_blobs(), resolution=0.014)
    me = sculpt.decimate(me, 1500)
    sculpt.into_part(jaw, me, "bone", transform=place)
    _teeth(jaw, False, rng)
    jaw.move([f for f in jaw.bm.faces if jaw.slots[f.material_index] == "tooth"], place)
    hinge = place @ Vector((0, 0.08, -0.12))
    jaw.move(list(jaw.bm.faces), T(*hinge) @ R('X', -7) @ T(*(-hinge)))           # mouth a little open
    parts += [skull, jaw]
    # arms
    for name, sx in (("arm_l", -1), ("arm_r", 1)):
        arm = Part(name, origin=(sx * SHOULDER[0], *SHOULDER[1:]), parent="spine_3")
        _arm(arm, sx)
        parts.append(arm)
    # legs
    for side, sx in (("l", -1), ("r", 1)):
        thigh = Part("thigh_" + side, origin=(sx * HIP[0], *HIP[1:]), parent="pelvis")
        shin = Part("shin_" + side, origin=(sx * KNEE[0], *KNEE[1:]), parent="thigh_" + side)
        foot = Part("foot_" + side, origin=(sx * ANKLE[0], *ANKLE[1:]), parent="shin_" + side)
        _leg(thigh, shin, foot, sx)
        parts += [thigh, shin, foot]
    # tail
    a0, a1 = arc_of(-0.55), arc_of(-5.3)
    bounds = [y_of(a0 + (a1 - a0) * k / TAIL_SEGS) for k in range(TAIL_SEGS + 1)]
    parent = "pelvis"
    for k in range(TAIL_SEGS):
        name = f"tail_{k + 1}"
        prt = Part(name, origin=tuple(at_y(bounds[k])[0]), parent=parent)
        _series(prt, bounds[k], bounds[k + 1], 0.2 if k < 3 else 0.16, tail_params, clamps=(0,))
        parts.append(prt)
        parent = name
    fns = {"bone": trex_bone, "tooth": M.tooth_fossil, "iron": M.iron}
    skull_c = place @ Vector((0, 0.6, 0.1))
    return Model("trex", parts, fns, ppm=112, ground=0.0, ao_dist=0.45, ao_rays=10, ao_stride=2, front=1,
                 normal_strength=1.6, markers=[("CrystalSocket", SOCKET, "ribs")],
                 preview_yaws=(-60.0, 30.0, 95.0, 200.0), preview_elevation=10.0,
                 preview_closeup=(tuple(skull_c), 0.9),
                 preview_extra=[("ribs", (0.0, 1.8, 3.3), 1.6, 80.0, 8.0),
                                ("skull_side", tuple(skull_c), 0.95, 88.0, 6.0)])
