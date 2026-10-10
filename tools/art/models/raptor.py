"""Velociraptor museum skeleton ("Velociraptor - stado"): 2.4 m from snout
to tail tip, head held up at 1.1 m, hips at 0.84 m. Same fossil-brown
bone, plaster repairs and iron mounting as the T-Rex (it came off the
same kind of mount): a thin armature bar along the back and the sheared
stub of its support rod under the hips.

What makes it read as a raptor: the long low skull with a huge orbit,
antorbital window and a dished snout full of hooked teeth; the S-neck;
long three-fingered arms folded forward with big hooked claws; bird legs
with the raised second toe carrying the sickle claw; the long straight
tail stiffened by bundles of bony rods.

Faces +Y in Blender = -Z in Godot. Origin on the floor under the hips.
Parts in a joint hierarchy, pivots at the joints (as the T-Rex):
    pelvis                          hips, ilium blades, backward pubis   root
    spine_1 > spine_2               back, hips -> shoulders
    ribs                            ribs, belly ribs, wishbone (child of spine_2)
    neck_1 > neck_2 > skull > jaw   (neck_1 child of spine_2)
    arm_l, arm_r                    whole arms with hands (children of spine_2)
    thigh_l > shin_l > foot_l       (and _r), children of the pelvis; the foot
                                    carries the sickle claw
    tail_1 > ... > tail_6           children chain from the pelvis
Weak point: the skull; marker WeakPoint (child of skull) sits at its centre.
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
AXIS = [(-1.34, 0.92), (-1.1, 0.9), (-0.8, 0.874), (-0.5, 0.852), (-0.25, 0.842), (0.0, 0.84), (0.2, 0.83),
        (0.38, 0.8), (0.5, 0.775), (0.575, 0.795), (0.63, 0.845), (0.67, 0.905), (0.71, 0.955), (0.765, 0.99)]
HIP = (0.08, 0.02, 0.76)
KNEE = (0.1, 0.19, 0.49)
ANKLE = (0.1, -0.05, 0.2)
MTP = (0.1, 0.03, 0.045)
SHOULDER = (0.068, 0.43, 0.69)
SKULL_AT = Vector((0.0, 0.749, 0.962))
SKULL_PITCH = -10.0
SKULL_SCALE = 1.1
JAW_OPEN = -12.0
TAIL_SEGS = 6


# --------------------------------------------------------------------------
# spine curve (arc-length parametrised)
# --------------------------------------------------------------------------

def _catmull(pts, n=20):
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


def arc_of(y):
    return float(np.interp(y, CURVE[:, 0], ARC))


def at_arc(s):
    s = float(np.clip(s, 0.0, ARC[-1]))
    i = int(np.clip(np.searchsorted(ARC, s) - 1, 0, len(ARC) - 2))
    t = (s - ARC[i]) / max(ARC[i + 1] - ARC[i], 1e-9)
    p = CURVE[i] * (1 - t) + CURVE[i + 1] * t
    d = CURVE[i + 1] - CURVE[i]
    d = d / np.linalg.norm(d)
    return Vector((0.0, p[0], p[1])), Vector((0.0, d[0], d[1]))


def point(y):
    return at_arc(arc_of(y))[0]


def frame(s):
    """Matrix at arc length ``s``: local +Y along the spine (toward the
    head), +Z up (square to the spine), +X to the right."""
    p, t = at_arc(s)
    up = Vector((0, 0, 1))
    up = (up - t * up.dot(t)).normalized()
    x = t.cross(up)
    return Matrix(((x.x, t.x, up.x, p.x), (x.y, t.y, up.y, p.y), (x.z, t.z, up.z, p.z), (0, 0, 0, 1)))


# --------------------------------------------------------------------------
# vertebrae, armature
# --------------------------------------------------------------------------

def vertebra(p, s, r, length, spine_h=0.0, spine_tilt=-20.0, transverse=0.0, chevron=0.0, cervical_rib=0.0,
             segments=6, fill=0.8, arch=1.0):
    """One vertebra at arc length ``s`` in the spine frame: spool-shaped
    centrum, neural arch and spine, optional transverse processes, chevron
    and cervical ribs."""
    L = length * fill
    out = p.lathe([(r, -L / 2), (r * 0.76, 0.0), (r, L / 2)], "bone", segments=segments, smooth=True)
    p.move(out, R('X', -90))
    out = list(out)
    out += p.box((0, 0, r * 1.2), (r * 1.4, L * 0.75 * arch, r * 0.7), "bone")
    if spine_h > 0.004:
        sp = p.box((0, 0, 0), (max(r * 0.35, 0.003), L * 0.55, spine_h), "bone")
        p.move(sp, T(0, 0, r * 1.45) @ R('X', spine_tilt) @ T(0, 0, spine_h / 2))
        out += sp
    if transverse > 0.004:
        for sx in (-1, 1):
            tp = p.box((0, 0, 0), (transverse, L * 0.4, r * 0.3), "bone")
            p.move(tp, T(sx * (r * 0.55 + transverse / 2), 0, r * 1.0) @ R('Y', -sx * 15))
            out += tp
    if chevron > 0.004:
        ch = p.box((0, 0, 0), (r * 0.45, L * 0.3, chevron), "bone")
        p.move(ch, T(0, -L * 0.15, -r * 0.9) @ R('X', 40) @ T(0, 0, -chevron / 2))
        out += ch
    if cervical_rib > 0.004:
        for sx in (-1, 1):
            out += p.tube([(sx * r * 1.0, L * 0.3, -r * 0.3), (sx * r * 1.1, -cervical_rib, -r * 0.7)], r * 0.22,
                          "bone", sides=3, smooth=False)
    p.move(out, frame(s))
    return out


def series(p, y0, y1, count, params, bar=None):
    """``count`` vertebrae between y0 and y1 along the curve; params(t) with
    t = 0..1 from y0 to y1 -> vertebra kwargs. ``bar`` = radius hint for an
    iron armature bar over the centra (None: no bar)."""
    a0, a1 = arc_of(y0), arc_of(y1)
    step = (a1 - a0) / count
    for k in range(count):
        t = (k + 0.5) / count
        vertebra(p, a0 + step * (k + 0.5), length=abs(step), **params(t))
    if bar is not None:
        n = max(2, count + 1)
        pts = [tuple(frame(a0 + (a1 - a0) * k / (n - 1)) @ Vector((0, 0, bar))) for k in range(n)]
        p.tube(pts, 0.0055, "iron", sides=4, smooth=False)


def tail_rods(p, y0, y1, r0, r1):
    """The raptor's stiff tail: bundles of long thin bony rods (the
    lengthened zygapophyses above, the chevron rods below) along a stretch."""
    a0, a1 = arc_of(y0), arc_of(y1)
    n = 4
    for side in (-1, 1):
        for up, frac in ((1.5, 0.35), (-1.35, 0.3)):
            pts = []
            for k in range(n):
                s = a0 + (a1 - a0) * k / (n - 1)
                r = r0 + (r1 - r0) * k / (n - 1)
                pts.append(tuple(frame(s) @ Vector((side * r * frac, 0.0, up * r))))
            p.tube(pts, max(r0 * 0.12, 0.0016), "bone", sides=3, smooth=True, caps=True)


def tail_params(t_global):
    def params(t):
        g = t_global[0] + (t_global[1] - t_global[0]) * t          # 0 at the hips, 1 at the tip
        r = 0.022 * (1 - g) + 0.0065 * g
        return dict(r=r, spine_h=max(0.0, 0.03 * (1 - g / 0.35)), spine_tilt=-40.0,
                    transverse=max(0.0, 0.035 * (1 - g / 0.3)), chevron=max(0.0, 0.03 * (1 - g / 0.5)),
                    segments=5 if g < 0.5 else 4)
    return params


def back_params(t):
    return dict(r=0.02, spine_h=0.042 - 0.012 * t, spine_tilt=-12.0, transverse=0.03, segments=6)


def neck_params(t):
    """Long, slender neck vertebrae that nearly touch (not beads on a string)."""
    return dict(r=0.0135 - 0.002 * t, spine_h=0.008, spine_tilt=-30.0, cervical_rib=0.022, segments=6, fill=0.95,
                arch=1.1)


# --------------------------------------------------------------------------
# skull and jaw (skull frame: occiput at y 0, snout tip at y 0.3, jaw joint
# at z 0, x right)
# --------------------------------------------------------------------------

def _w(y):
    return 0.036 - 0.055 * y


def _mirror(fn):
    out = []
    for sx in (-1, 1):
        out += fn(sx)
    return out


def _skull_blobs():
    """Strut skull as in the real one seen from the side: the orbit, the
    antorbital window and the temporal opening are gaps between bars."""
    def side(sx):
        w = _w
        b = []
        b += limb([(sx * w(0.02), 0.02, -0.004), (sx * w(0.08), 0.08, -0.008), (sx * w(0.15), 0.15, -0.005)],
                  [0.0072, 0.0068, 0.0064], squash=0.6)                                  # jugal
        b += limb([(sx * w(0.0), 0.004, -0.008), (sx * w(0.0) * 0.95, 0.008, 0.028), (sx * 0.03, 0.013, 0.052)],
                  [0.0072, 0.0062, 0.0062], squash=0.6)                                  # quadratojugal-squamosal
        b += limb([(sx * w(0.045), 0.044, -0.004), (sx * w(0.045) * 0.95, 0.047, 0.03),
                   (sx * w(0.045) * 0.86, 0.05, 0.058)], [0.006, 0.0055, 0.0062], squash=0.6)  # postorbital
        b += limb([(sx * w(0.11), 0.109, -0.003), (sx * w(0.11) * 0.95, 0.107, 0.03),
                   (sx * w(0.11) * 0.86, 0.101, 0.056)], [0.0068, 0.006, 0.0068], squash=0.6)  # lacrimal
        b += limb([(sx * 0.026, 0.1, 0.057), (sx * 0.028, 0.05, 0.061), (sx * 0.027, 0.012, 0.054)],
                  [0.0062, 0.0062, 0.006], squash=0.7)                                   # orbit roof edge
        b += limb([(sx * w(0.1), 0.1, -0.002), (sx * w(0.2), 0.2, 0.0), (sx * w(0.28), 0.28, 0.004)],
                  [0.0078, 0.0078, 0.0072], squash=0.6)                                  # maxilla (tooth row)
        b += limb([(sx * 0.02, 0.1, 0.056), (sx * 0.0175, 0.2, 0.041), (sx * 0.013, 0.285, 0.031)],
                  [0.0062, 0.0056, 0.0056], squash=0.7)                                  # nasal edge (dished)
        b += limb([(sx * w(0.2), 0.2, 0.004), (sx * 0.0175, 0.206, 0.04)], [0.0062, 0.0052], squash=0.6)  # ascending proc.
        b.append(blob((sx * w(0.245), 0.245, 0.016), (0.004, 0.035, 0.013)))           # maxilla plate in front
        b.append(blob((sx * w(0.0), 0.004, -0.009), (0.008, 0.008, 0.008)))           # quadrate (jaw joint)
        return b
    b = _mirror(side)
    b += [
        blob((0, 0.04, 0.03), (0.021, 0.028, 0.025)),         # braincase
        blob((0, 0.007, 0.036), (0.026, 0.008, 0.02)),        # occiput
        blob((0, 0.058, 0.062), (0.024, 0.048, 0.0065)),      # skull roof
        blob((0, 0.2, -0.004), (0.013, 0.09, 0.004)),         # palate
        blob((0, 0.284, 0.014), (0.013, 0.016, 0.019)),       # premaxillae (snout tip)
    ]
    b += limb([(0, 0.1, 0.058), (0, 0.2, 0.043), (0, 0.28, 0.033)], [0.006, 0.0055, 0.0055])   # nasal ridge
    return b


def _jaw_blobs():
    def side(sx):
        w = _w
        b = limb([(sx * w(0.07) * 0.93, 0.07, -0.02), (sx * w(0.18) * 0.9, 0.18, -0.017),
                  (sx * 0.011, 0.272, -0.013)], [0.0072, 0.0066, 0.0064], squash=0.6)            # dentary
        b.append(blob((sx * w(0.03), 0.035, -0.018), (0.005, 0.042, 0.0125)))                   # surangular
        b.append(blob((sx * w(0.0), 0.003, -0.01), (0.0085, 0.01, 0.0085)))                     # articular
        b.append(blob((sx * w(0.06), 0.068, -0.018), (0.02, 0.014, 0.0045), neg=True, stiff=3.0))  # fenestra
        return b
    b = _mirror(side)
    b.append(blob((0, 0.274, -0.014), (0.014, 0.013, 0.0075)))                                  # chin (symphysis)
    return b


def _teeth(p, upper, rng):
    for sx in (-1, 1):
        n = 9 if upper else 8
        for k in range(n):
            t = k / (n - 1)
            if upper:
                y = 0.15 + t * 0.13
                base = (sx * _w(y) * 0.92, y, -0.006)
                d = (sx * 0.08, -0.3, -1.0)
            else:
                y = 0.1 + t * 0.165
                base = (sx * _w(y) * 0.86, y, -0.011)
                d = (sx * 0.08, -0.25, 1.0)
            ln = 0.012 + 0.005 * math.sin(math.pi * t) + rng.uniform(-0.0015, 0.0015)
            kit.cone(p, base, d, ln, 0.0028, "tooth", segments=3, tip=0.0006)


# --------------------------------------------------------------------------
# pelvis, ribs, limbs
# --------------------------------------------------------------------------

def _pelvis(p):
    outline = []
    for k in range(12):
        a = math.tau * k / 12
        yy = 0.15 * math.cos(a)
        zz = 0.034 * math.sin(a) * (1.0 if math.sin(a) > 0 else 0.7)
        outline.append((yy, zz))
    for sx in (-1, 1):
        f = p.ngon_prism(outline, -0.005, 0.005, "bone")
        p.move(f, T(sx * 0.05, 0.0, 0.8) @ R('Y', 90) @ R('Z', 90))                   # ilium blade
        acet = Vector((sx * HIP[0], HIP[1], HIP[2]))
        kit.sphere(p, acet + Vector((-sx * 0.012, 0, 0.006)), 0.02, "bone", segments=6, rings=4)
        # pubis: long, pointing down and BACK, ending in a small boot
        kit.seg(p, acet + Vector((-sx * 0.01, 0.01, -0.01)), (sx * 0.02, -0.11, 0.53),
                [(0.011, 0), (0.008, 0.5), (0.009, 1.0)], "bone", segments=6)
        kit.seg(p, acet + Vector((-sx * 0.01, -0.02, -0.004)), (sx * 0.025, -0.13, 0.66),
                [(0.01, 0), (0.007, 0.6), (0.006, 1.0)], "bone", segments=5)           # ischium
    kit.sphere(p, (0.0, -0.12, 0.525), 0.02, "bone", segments=6, rings=4, squash=(1.0, 1.8), zscale=0.6)  # boot
    series(p, -0.16, 0.14, 4, lambda t: dict(r=0.022, spine_h=0.04, spine_tilt=-8.0, transverse=0.03, segments=5),
           bar=0.03)
    # sheared-off support rod under the hips, bolted to a strap round the sacrum
    top = point(0.0) + Vector((0, 0, -0.02))
    p.box(top + Vector((0, 0, 0.0)), (0.11, 0.022, 0.012), "iron")
    rng = random.Random(5)
    f = p.lathe([(0.009, -0.22), (0.009, 0.0)], "iron", segments=6, center=tuple(top), cap_bottom=True,
                cap_top=False, smooth=True)
    for v in sorted({v for face in f for v in face.verts}, key=lambda v: tuple(v.co)):
        if v.co.z < top.z - 0.2:
            v.co.z += rng.uniform(-0.025, 0.015)


def _ribs(p):
    ys = [0.08, 0.13, 0.18, 0.23, 0.28, 0.33, 0.38, 0.43]
    for k, y in enumerate(ys):
        t = k / (len(ys) - 1)
        depth = 0.17 + 0.09 * math.sin(math.pi * min(1.0, 0.25 + t * 0.9))
        width = 0.065 + 0.03 * math.sin(math.pi * min(1.0, 0.2 + t))
        base = point(y)
        for sx in (-1, 1):
            pts = []
            for j in range(5):
                a = j / 4
                x = sx * (0.016 + width * math.sin(a * math.pi * 0.62) * 1.05)
                z = -depth * (a ** 1.1)
                yy = -0.05 * a - 0.012 * math.sin(a * math.pi)
                pts.append((x, base.y + yy, base.z + 0.012 + z + 0.025 * math.sin(a * math.pi)))
            p.tube(pts, lambda u: 0.0065 * (1 - u) + 0.0035 * u, "bone", sides=4, smooth=True)
    # gastralia: V-shaped belly ribs
    for k in range(6):
        y = 0.07 + k * 0.064
        zb = 0.56 + 0.02 * k / 5
        w = 0.05 + 0.02 * math.sin(math.pi * k / 5)
        for sx in (-1, 1):
            p.tube([(sx * w, y - 0.02, zb + 0.03), (sx * w * 0.5, y - 0.005, zb + 0.004), (0.0, y + 0.012, zb)],
                   0.0035, "bone", sides=3)
    # wishbone at the front of the chest
    p.tube([(-0.05, 0.47, 0.72), (-0.02, 0.5, 0.66), (0.0, 0.505, 0.645), (0.02, 0.5, 0.66), (0.05, 0.47, 0.72)],
           0.005, "bone", sides=4)


def _arm(p, sx):
    sh = Vector((sx * SHOULDER[0], *SHOULDER[1:]))
    # scapula blade along the ribs, coracoid in front
    kit.seg(p, sh + Vector((0, 0.01, 0.01)), Vector((sx * 0.058, 0.28, 0.79)), [(0.011, 0), (0.007, 0.5), (0.01, 1.0)],
            "bone", segments=5, squash=(0.45, 1.0))
    kit.sphere(p, sh + Vector((-sx * 0.012, 0.025, -0.02)), 0.017, "bone", segments=6, rings=3, squash=(0.5, 1.0))
    elbow = Vector((sx * 0.1, 0.375, 0.54))
    wrist = Vector((sx * 0.112, 0.53, 0.505))
    kit.seg(p, sh, elbow, [(0.012, 0), (0.008, 0.5), (0.011, 1.0)], "bone", segments=6)            # humerus
    kit.seg(p, elbow + Vector((0, 0.004, 0.006)), wrist + Vector((0, 0, 0.006)), [(0.008, 0), (0.0055, 0.5),
                                                                                (0.007, 1.0)], "bone", segments=5)  # ulna
    kit.seg(p, elbow + Vector((sx * 0.008, 0.01, -0.004)), wrist + Vector((sx * 0.006, 0, -0.004)),
            [(0.006, 0), (0.0045, 0.5), (0.0055, 1.0)], "bone", segments=5)                         # radius
    kit.sphere(p, wrist, 0.011, "bone", segments=6, rings=3)                                      # wrist block
    fingers = ((-0.012, 0.04, -0.02, 0.05), (0.0, 0.1, -0.05, 0.1), (0.012, 0.085, -0.048, 0.085))
    for dx, fy, fz, ln in fingers:
        tip = wrist + Vector((sx * dx, fy, fz))
        mid = wrist.lerp(tip, 0.45) + Vector((0, 0, 0.008))
        kit.seg(p, wrist, mid, [(0.0065, 0), (0.005, 1.0)], "bone", segments=4)
        kit.seg(p, mid, tip, [(0.005, 0), (0.0045, 1.0)], "bone", segments=4)
        _claw(p, tip, (tip - wrist).normalized(), 0.028 + ln * 0.08, 0.0055)


def _claw(p, base, direction, length, r0, curl=1.3):
    """A hooked claw: a tapering tube along an arc that curls downward."""
    d = Vector(direction).normalized()
    side = d.cross(Vector((0, 0, 1)))
    if side.length < 0.1:
        side = Vector((1, 0, 0))
    down = side.cross(d).normalized()
    if down.z > 0:
        down = -down
    radius = length / curl
    pts = []
    n = 5 if length > 0.04 else 4
    for k in range(n):
        a = curl * k / (n - 1)
        pts.append(base + d * (radius * math.sin(a)) + down * (radius * (1 - math.cos(a))))
    p.tube(pts, lambda u: r0 * (1 - u) + 0.0009 * u, "claw", sides=4, smooth=True)


def _leg(thigh, shin, foot, sx):
    hip = Vector((sx * HIP[0], *HIP[1:]))
    knee = Vector((sx * KNEE[0], *KNEE[1:]))
    ankle = Vector((sx * ANKLE[0], *ANKLE[1:]))
    mtp = Vector((sx * MTP[0], *MTP[1:]))
    # femur with the head turned in and a trochanter
    kit.seg(thigh, hip + Vector((0, 0.004, 0.012)), knee, [(0.027, 0.0), (0.02, 0.2), (0.017, 0.55), (0.02, 0.85),
                                                          (0.027, 0.96), (0.022, 1.0)], "bone", segments=7)
    kit.sphere(thigh, hip + Vector((-sx * 0.024, 0.0, 0.012)), 0.019, "bone", segments=6, rings=3)
    kit.sphere(thigh, hip + Vector((sx * 0.008, 0.022, 0.024)), 0.014, "bone", segments=6, rings=3)
    # tibia and the thin fibula
    kit.seg(shin, knee + Vector((0, 0.008, 0.004)), ankle, [(0.026, 0.0), (0.019, 0.12), (0.0145, 0.5), (0.015, 0.9),
                                                            (0.021, 1.0)], "bone", segments=7)
    kit.seg(shin, knee + Vector((sx * 0.014, -0.006, -0.01)), ankle + Vector((sx * 0.012, 0.004, 0.02)),
            [(0.006, 0), (0.0035, 0.5), (0.0045, 1.0)], "bone", segments=4)
    # foot: ankle block, three metatarsals, toes III and IV on the floor,
    # toe II raised with the sickle claw, a small first toe behind
    kit.sphere(foot, ankle, 0.02, "bone", segments=6, rings=3, zscale=0.8)
    for dx in (-0.01, 0.0, 0.01):
        kit.seg(foot, ankle + Vector((sx * dx * 0.6, 0.0, -0.01)), mtp + Vector((sx * dx, 0.0, 0.0)),
                [(0.009, 0), (0.0068, 0.5), (0.0088, 1.0)], "bone", segments=5)
    for dx, tip, n in ((0.0, Vector((0.0, 0.13, 0.009)), 2), (0.02, Vector((0.022, 0.11, 0.008)), 2)):
        a = mtp + Vector((sx * dx * 0.4, 0.004, -0.008))
        b = Vector((mtp.x + sx * tip.x, tip.y, tip.z))
        prev = a
        for k in range(n):
            q = a.lerp(b, (k + 1) / n) + Vector((0, 0, 0.006 * math.sin(math.pi * (k + 1) / n)))
            kit.seg(foot, prev, q, [(0.0078, 0.0), (0.006, 0.5), (0.007, 1.0)], "bone", segments=5)
            prev = q
        _claw(foot, prev, (b - a).normalized() + Vector((0, 0, -0.3)), 0.022, 0.0048, curl=1.1)
    # toe II: two phalanges up and forward, then the big sickle claw
    j1 = mtp + Vector((-sx * 0.012, 0.012, 0.004))
    j2 = j1 + Vector((-sx * 0.002, 0.03, 0.028))
    j3 = j2 + Vector((0.0, 0.022, 0.004))
    kit.seg(foot, j1, j2, [(0.0075, 0), (0.006, 0.5), (0.007, 1.0)], "bone", segments=5)
    kit.seg(foot, j2, j3, [(0.007, 0), (0.0058, 0.5), (0.0068, 1.0)], "bone", segments=5)
    kit.sphere(foot, j3, 0.0078, "bone", segments=6, rings=3)
    _claw(foot, j3 + Vector((0, 0.004, 0.002)), (0, 1, 0.55), 0.075, 0.0085, curl=2.2)
    # hallux
    h0 = ankle.lerp(mtp, 0.7) + Vector((-sx * 0.012, -0.006, 0.0))
    kit.seg(foot, h0, h0 + Vector((-sx * 0.006, 0.018, -0.02)), [(0.004, 0), (0.0035, 1.0)], "bone", segments=4)
    _claw(foot, h0 + Vector((-sx * 0.006, 0.018, -0.02)), (0, 0.6, -1), 0.012, 0.003)
    lo = min(v.co.z for v in foot.bm.verts)
    foot.move(list(foot.bm.faces), T(0, 0, -lo))


# --------------------------------------------------------------------------
# paint
# --------------------------------------------------------------------------

def raptor_bone(ctx):
    """The T-Rex's fossil bone (same ramp and centre), a tone per bone."""
    s = M.bone(ctx, center=5.4)
    tone = M.noise.rand_cells(ctx.part, 23) - 0.5
    s.shade += tone * 1.4
    return s


def claw(ctx):
    """Claws and teeth: the T-Rex's dark fossil tooth, a step lighter so the
    small hooks read against the bone."""
    s = M.tooth_fossil(ctx, seed=641)
    s.shade += 1.4
    return s


def build():
    rng = random.Random(7)
    parts = []
    pelvis = Part("pelvis", origin=tuple(point(0.0)))
    _pelvis(pelvis)
    parts.append(pelvis)
    sp1 = Part("spine_1", origin=tuple(point(0.14)), parent="pelvis")
    series(sp1, 0.14, 0.31, 4, back_params, bar=0.03)
    sp2 = Part("spine_2", origin=tuple(point(0.31)), parent="spine_1")
    series(sp2, 0.31, 0.5, 4, back_params, bar=0.03)
    parts += [sp1, sp2]
    ribs = Part("ribs", origin=tuple(point(0.3)), parent="spine_2")
    _ribs(ribs)
    parts.append(ribs)
    split = 0.635
    n1 = Part("neck_1", origin=tuple(point(0.5)), parent="spine_2")
    series(n1, 0.5, split, 4, neck_params)
    n2 = Part("neck_2", origin=tuple(point(split)), parent="neck_1")
    series(n2, split, 0.76, 3, lambda t: neck_params(0.5 + t * 0.5))
    parts += [n1, n2]
    place = T(*SKULL_AT) @ R('X', SKULL_PITCH) @ kit.S(SKULL_SCALE, SKULL_SCALE, SKULL_SCALE)
    skull = Part("skull", origin=tuple(place @ Vector((0, 0.006, 0.03))), parent="neck_2")
    me = sculpt.metaball_mesh(_skull_blobs(), resolution=0.0032)
    me = sculpt.decimate(me, 1000)
    sculpt.into_part(skull, me, "bone", transform=place)
    _teeth(skull, True, rng)
    skull.move([f for f in skull.bm.faces if skull.slots[f.material_index] == "tooth"], place)
    hinge = place @ Vector((0, 0.004, -0.009))
    jaw = Part("jaw", origin=tuple(hinge), parent="skull")
    me = sculpt.metaball_mesh(_jaw_blobs(), resolution=0.0032)
    me = sculpt.decimate(me, 360)
    sculpt.into_part(jaw, me, "bone", transform=place)
    _teeth(jaw, False, rng)
    jaw.move([f for f in jaw.bm.faces if jaw.slots[f.material_index] == "tooth"], place)
    jaw.move(list(jaw.bm.faces), T(*hinge) @ R('X', JAW_OPEN) @ T(*(-hinge)))
    parts += [skull, jaw]
    for name, sx in (("arm_l", -1), ("arm_r", 1)):
        arm = Part(name, origin=(sx * SHOULDER[0], *SHOULDER[1:]), parent="spine_2")
        _arm(arm, sx)
        parts.append(arm)
    for side, sx in (("l", -1), ("r", 1)):
        thigh = Part("thigh_" + side, origin=(sx * HIP[0], *HIP[1:]), parent="pelvis")
        shin = Part("shin_" + side, origin=(sx * KNEE[0], *KNEE[1:]), parent="thigh_" + side)
        foot = Part("foot_" + side, origin=(sx * ANKLE[0], *ANKLE[1:]), parent="shin_" + side)
        _leg(thigh, shin, foot, sx)
        parts += [thigh, shin, foot]
    bounds = list(np.linspace(-0.16, -1.36, TAIL_SEGS + 1))
    counts = [4, 4, 4, 3, 3, 3]
    parent = "pelvis"
    for k in range(TAIL_SEGS):
        name = f"tail_{k + 1}"
        prt = Part(name, origin=tuple(point(bounds[k])), parent=parent)
        g0, g1 = k / TAIL_SEGS, (k + 1) / TAIL_SEGS
        series(prt, bounds[k], bounds[k + 1], counts[k], tail_params((g0, g1)), bar=0.028 if k == 0 else None)
        if k > 0:
            r0 = 0.022 * (1 - g0) + 0.0065 * g0
            r1 = 0.022 * (1 - g1) + 0.0065 * g1
            tail_rods(prt, bounds[k] + 0.01, bounds[k + 1] - 0.01, r0, r1)
        parts.append(prt)
        parent = name
    fns = {"bone": raptor_bone, "tooth": claw, "claw": claw, "iron": M.iron}
    skull_c = place @ Vector((0, 0.14, 0.02))
    return Model("raptor", parts, fns, ppm=256, organic=("skull", "jaw"), ground=0.0, ao_dist=0.12, ao_rays=10,
                 ao_stride=2, front=1, normal_strength=1.6, markers=[("WeakPoint", tuple(skull_c), "skull")],
                 preview_yaws=(-60.0, 30.0, 95.0, 200.0), preview_elevation=10.0,
                 preview_closeup=(tuple(skull_c), 0.2),
                 preview_extra=[("side", (0.0, -0.18, 0.6), 1.3, 90.0, 4.0),
                                ("skull_side", tuple(skull_c), 0.22, 90.0, 6.0),
                                ("foot", (0.1, 0.05, 0.08), 0.14, 60.0, 12.0),
                                ("foot_side", (0.1, 0.05, 0.1), 0.16, 90.0, 5.0)])
