"""The mummy (Egypt wing enemy), about 1.8 m: a gaunt, slightly hunched
body wound in dusty linen - helical wraps on every limb, dark resin
soaking through in patches, rents showing dried skin, a slit in the head
wrappings where two embers glow, a torn mouth with teeth - with loose
strips trailing from the head, an arm, the waist and a knee, and a long
bandage hanging from the right wrist: the whip of its lash attack.

Faces +Y in Blender = -Z in Godot. Origin on the floor between the feet.
Parts (Godot node names), pivots at the joints (Blender x, y, z):
    torso        (0, 0, 1.00)          waist                    root
    head         (0, 0.02, 1.52)       neck                     child of torso
    arm_l, arm_r (-/+0.20, 0, 1.43)    shoulders                children of torso
    forearm_l/_r (-/+0.22, 0.02, 1.13) elbows                   children of arm_*
    leg_l, leg_r (-/+0.10, 0, 0.92)    hips                     root
    whip_1 > whip_2 > whip_3 > whip_4  the lash bandage: whip_1 hangs from the
                 right wrist (0.21, 0.05, 0.86), child of forearm_r; four
                 segments of 0.2 m straight down, each pivoting at its top
                 (rotate whip_1 forward and stretch the segments along their
                 length for the lash)
    strip_1 (head), strip_2 (arm_l), strip_3 (torso), strip_4 (leg_l):
                 loose trailing strips to sway
Markers: EyeGlow (child of head, between the eyes, inside the slit),
WeakPoint (child of head, the head's centre (0, 0.03, 1.63)).
Rest pose: standing, hunched a little forward, arms hanging slightly bent.
mummy_debris: bandage scraps scrap_1..3 and bones bone_1 (femur), bone_2
(ribs) for the break-up (each part pivots at its centre).
"""
import math

import numpy as np
from mathutils import Matrix, Vector

from artlib import egypt as E
from artlib import kit as K
from artlib import materials as M
from artlib import sculpt
from artlib.geo import Part
from artlib.materials import P, _dither, smoothstep
from artlib.model import Model
from artlib.painter import Surface
from artlib.sculpt import blob, limb

ORDER = ["torso", "head", "arm_l", "arm_r", "forearm_l", "forearm_r", "leg_l", "leg_r", "whip_1", "whip_2",
         "whip_3", "whip_4", "strip_1", "strip_2", "strip_3", "strip_4"]
IDX = {n: i for i, n in enumerate(ORDER)}
WRIST_R = (0.21, 0.05, 0.86)
HEAD_C = (0.0, 0.03, 1.63)
# wrap axes per part: (point, direction) of the limb the bandage winds round
AXES = {
    "torso": ((0.0, 0.0, 0.9), (0.0, 0.0, 1.0)),
    "head": ((0.0, 0.03, 1.5), (0.0, 0.15, 1.0)),
    "arm_l": ((-0.2, 0.0, 1.43), (-0.02, 0.02, -0.3)),
    "arm_r": ((0.2, 0.0, 1.43), (0.02, 0.02, -0.3)),
    "forearm_l": ((-0.22, 0.02, 1.13), (0.01, 0.03, -0.25)),
    "forearm_r": ((0.22, 0.02, 1.13), (-0.01, 0.03, -0.25)),
    "leg_l": ((-0.1, 0.0, 0.92), (0.0, 0.0, -1.0)),
    "leg_r": ((0.1, 0.0, 0.92), (0.0, 0.0, -1.0)),
}


def _sx(p, sx):
    return (sx * p[0], p[1], p[2])


def _clay(part, blobs, tris, slot="linen", res=0.008, cut=None):
    me = sculpt.metaball_mesh(blobs, resolution=res)
    if cut:
        sculpt.cut(me, cut)
    me = sculpt.decimate(me, tris)
    sculpt.into_part(part, me, slot)


def ribbon(p, pts, width, slot, thick=0.006, twist=0.0):
    """A strip of cloth along a polyline: width across (perpendicular to the
    path and to +X-ish), a little thickness, ``twist`` radians along it."""
    pts = [Vector(q) for q in pts]
    n = len(pts)
    rings = []
    for i, q in enumerate(pts):
        t = (pts[min(i + 1, n - 1)] - pts[max(i - 1, 0)]).normalized()
        ref = Vector((1.0, 0.0, 0.0)) if abs(t.x) < 0.9 else Vector((0.0, 1.0, 0.0))
        side = t.cross(ref).normalized()
        side = Matrix.Rotation(twist * i / max(1, n - 1), 3, t) @ side
        up = t.cross(side).normalized()
        w = width * (1.0 - 0.25 * i / max(1, n - 1))
        corners = [q + side * w / 2 + up * thick / 2, q - side * w / 2 + up * thick / 2,
                   q - side * w / 2 - up * thick / 2, q + side * w / 2 - up * thick / 2]
        rings.append([p.bm.verts.new(c) for c in corners])
    faces = []
    for j in range(n - 1):
        for k in range(4):
            k2 = (k + 1) % 4
            f = p._face([rings[j][k], rings[j][k2], rings[j + 1][k2], rings[j + 1][k]], slot, smooth=False)
            f.normal_update()
            c = f.calc_center_median()
            mid = (pts[j] + pts[j + 1]) * 0.5
            if f.normal.dot(c - mid) < 0:
                f.normal_flip()
            faces.append(f)
    for ring, sign in ((rings[0], -1), (rings[-1], 1)):
        f = p._face(ring, slot)
        faces.append(f)
    return faces


# --------------------------------------------------------------------------
# body
# --------------------------------------------------------------------------

def torso():
    p = Part("torso", origin=(0.0, 0.0, 1.0))
    b = [blob((0.0, 0.0, 1.3), (0.165, 0.11, 0.14)),
         blob((0.0, 0.0, 1.1), (0.15, 0.1, 0.11)),
         blob((0.0, 0.0, 0.95), (0.165, 0.11, 0.1)),
         blob((0.0, -0.06, 1.37), (0.15, 0.08, 0.1)),
         blob((0.0, 0.015, 1.49), (0.05, 0.05, 0.05)),
         blob((0.0, 0.085, 1.22), (0.09, 0.03, 0.03), neg=True, stiff=1.5)]   # sunken belly under the ribs
    for sx in (-1, 1):
        b.append(blob((sx * 0.18, -0.01, 1.42), (0.06, 0.06, 0.055)))
        b.append(blob((sx * 0.085, 0.05, 1.31), (0.085, 0.03, 0.075)))
    _clay(p, b, 1500, res=0.009)
    return p


def head():
    p = Part("head", origin=(0.0, 0.02, 1.52), parent="torso")
    b = limb([(0.0, 0.0, 1.47), (0.0, 0.03, 1.58)], [0.047, 0.045], spacing=0.7)
    b += [blob((0.0, 0.03, 1.645), (0.085, 0.095, 0.1)),
          blob((0.0, 0.075, 1.575), (0.058, 0.06, 0.04)),
          blob((0.0, 0.112, 1.646), (0.07, 0.04, 0.013), neg=True, stiff=1.4),       # the eye slit
          blob((0.018, 0.118, 1.566), (0.032, 0.03, 0.012), neg=True, stiff=1.4)]    # torn mouth
    _clay(p, b, 1100, res=0.006)
    for sx in (-1, 1):
        K.sphere(p, (sx * 0.03, 0.084, 1.646), 0.009, "eyes", segments=8, rings=5)
    for k in range(6):
        x = -0.004 + k * 0.009
        K.cone(p, (x, 0.098, 1.575 - (0.0 if k % 2 else 0.002)), (0.0, 0.2, 1.0 if k % 2 else -1.0), 0.012, 0.004,
               "tooth", segments=4)
    return p


def arm(sx):
    name = "arm_l" if sx < 0 else "arm_r"
    sh, el = (sx * 0.2, 0.0, 1.43), (sx * 0.22, 0.02, 1.13)
    p = Part(name, origin=sh, parent="torso")
    b = limb([sh, el], [0.058, 0.048], spacing=0.6)
    b.append(blob((sx * 0.205, 0.0, 1.4), (0.05, 0.05, 0.05)))
    _clay(p, b, 350, res=0.006)
    return p


def forearm(sx):
    name = "forearm_l" if sx < 0 else "forearm_r"
    el, wr = (sx * 0.22, 0.02, 1.13), _sx(WRIST_R, sx)
    p = Part(name, origin=el, parent=name.replace("forearm", "arm"))
    b = limb([el, wr], [0.047, 0.037], spacing=0.6)
    b.append(blob((sx * 0.21, 0.065, 0.81), (0.028, 0.045, 0.055)))                    # hand
    for k, dx in enumerate((-0.016, 0.0, 0.016)):
        b += limb([(sx * 0.21 + dx, 0.08, 0.78), (sx * 0.21 + dx, 0.1 + 0.01 * (k == 1), 0.72)], [0.011, 0.009],
                  spacing=0.6)
    _clay(p, b, 450, res=0.0045)
    return p


def leg(sx):
    name = "leg_l" if sx < 0 else "leg_r"
    hip, knee, ankle = (sx * 0.1, 0.0, 0.92), (sx * 0.105, 0.025, 0.5), (sx * 0.105, 0.0, 0.08)
    p = Part(name, origin=hip)
    b = limb([hip, knee], [0.082, 0.06], spacing=0.6) + limb([knee, ankle], [0.06, 0.042], spacing=0.6)
    b.append(blob((sx * 0.105, 0.045, 0.5), (0.04, 0.03, 0.045)))
    b.append(blob((sx * 0.105, 0.06, 0.035), (0.04, 0.1, 0.035)))
    _clay(p, b, 650, res=0.006, cut=[((0, 0, 0.0), (0, 0, -1))])
    return p


def whips():
    out = []
    top = Vector(WRIST_R) + Vector((0.0, 0.0, -0.02))
    parent = "forearm_r"
    for k in range(4):
        a = top + Vector((0.0, 0.0, -0.2 * k))
        b = a + Vector((0.0, 0.0, -0.2))
        p = Part(f"whip_{k + 1}", origin=tuple(a), parent=parent)
        wob = [(a.x + 0.006 * math.sin(i * 1.7 + k), a.y + 0.005 * math.cos(i * 2.3 + k), a.z - 0.2 * i / 4)
               for i in range(5)]
        ribbon(p, wob, 0.05 - 0.006 * k, "strip", twist=0.6)
        out.append(p)
        parent = p.name
    return out


def strips():
    data = [("strip_1", "head", [(0.04, -0.06, 1.62), (0.07, -0.13, 1.55), (0.09, -0.17, 1.44), (0.1, -0.19, 1.33)], 0.04),
            ("strip_2", "arm_l", [(-0.24, 0.0, 1.32), (-0.27, 0.02, 1.2), (-0.28, 0.03, 1.08), (-0.27, 0.05, 0.98)], 0.035),
            ("strip_3", "torso", [(0.12, 0.05, 0.95), (0.15, 0.06, 0.82), (0.16, 0.08, 0.7), (0.15, 0.07, 0.6)], 0.045),
            ("strip_4", "leg_l", [(-0.15, 0.03, 0.5), (-0.17, 0.0, 0.38), (-0.18, -0.02, 0.27), (-0.17, -0.05, 0.18)], 0.035)]
    out = []
    for name, parent, pts, w in data:
        p = Part(name, origin=pts[0], parent=parent)
        ribbon(p, pts, w, "strip", twist=0.8)
        out.append(p)
    return out


# --------------------------------------------------------------------------
# paint
# --------------------------------------------------------------------------

def linen(ctx, seed=1201):
    """Bandaged body: helical wraps (a dark shadow line under each lapped
    edge, the next band catching the light above it), dust caught in the
    hollows, resin soaking through in dark glossy patches, rents showing
    dried skin."""
    s = Surface(ctx.N)
    band = np.zeros(ctx.N)
    for name, (a, d) in AXES.items():
        m = ctx.part == IDX[name]
        if not m.any():
            continue
        a, d = np.array(a), np.array(d) / np.linalg.norm(d)
        q = ctx.p[m] - a
        along = q @ d
        ref = np.array([1.0, 0.0, 0.0]) if abs(d[0]) < 0.9 else np.array([0.0, 1.0, 0.0])
        e1 = np.cross(d, ref)
        e1 /= np.linalg.norm(e1)
        e2 = np.cross(d, e1)
        th = np.arctan2(q @ e2, q @ e1)
        tilt = 0.6 if name != "head" else 0.25
        width = 0.045 * (1.0 + 0.25 * ctx.fbm(np.array([0.5, 0.5, 6.0]), 2, seed + 9)[m])
        band[m] = along / width + th / (2 * np.pi) * tilt * (1 if IDX[name] % 2 else -1)
    fr = np.mod(band, 1.0)
    lap = fr < 0.14
    lit = (fr > 0.14) & (fr < 0.3)
    shade = 5.0 + ctx.fbm(14.0, 2, seed) * 0.6 + _dither(ctx, 0.6, seed + 1) - lap * 1.8 + lit * 0.7
    shade += np.clip(ctx.curv, 0, 1) * 0.8 - np.clip(-ctx.curv, 0, 1) * 1.2
    dust = ctx.cavity(3.0) * 0.8 + (1.0 - ctx.ao) * 0.8
    shade -= (1.0 - ctx.ao) * 2.4
    s.use_ramp(P["linen"], shade=shade + dust * 0.6)
    s.rough = np.full(ctx.N, 0.95)
    s.height = lap * -0.0012 + ctx.fbm(60.0, 2, seed + 2) * 0.0003
    resin = (ctx.fbm(3.5, 4, seed + 3) > 0.42) | ((ctx.p[:, 2] < 0.05) & (ctx.fbm(6.0, 2, seed + 4) > 0.2))
    rs = E.resin(ctx, seed + 5)
    rs.rough = rs.rough + 0.25
    rs.shade = rs.shade + 0.8
    s.merge(E._select(rs, resin), resin)
    rent = (ctx.fbm(5.0, 3, seed + 6) > 0.5) & ~resin
    s.use_ramp(P["skin_dry"], mask=rent, shade=np.full(ctx.N, 2.4) + _dither(ctx, 0.8, seed + 7))
    s.height = np.where(rent, -0.003, s.height)
    # the face: darker wraps round the eye slit
    head = ctx.part == IDX["head"]
    d = np.abs(ctx.p[:, 2] - 1.646)
    s.shade[head & (d < 0.03) & (ctx.p[:, 1] > 0.08)] -= 1.0
    return s


def strip_paint(ctx, seed=1203):
    """Loose bandage: frayed edges, weave, dust and resin stains."""
    s = Surface(ctx.N)
    ix, iy = E.px(ctx)
    weave = ((ix + iy) % 2) * 0.4
    shade = 5.2 + weave + ctx.fbm(10.0, 3, seed) * 0.7 + _dither(ctx, 0.5, seed + 1)
    shade -= ctx.edge_soft(2.0) * 1.0 + (1.0 - ctx.ao) * 2.0
    s.use_ramp(P["linen"], shade=shade)
    stain = ctx.fbm(4.0, 3, seed + 2) > 0.3
    s.use_ramp(P["resin"], mask=stain, shade=np.full(ctx.N, 3.4) + _dither(ctx, 0.6, seed + 3))
    s.rough = np.where(stain, 0.4, 0.95)
    return s


def eyes(ctx, seed=1205):
    return M.glow(ctx, "ember", 5.5, 1.0, seed)


def tooth(ctx, seed=1207):
    return M.ivory(ctx, seed, center=3.6)


def debris():
    parts = []
    for k, (c, pts, w) in enumerate((((0.0, 0.0, 0.03), [(-0.18, 0.0, 0.02), (-0.06, 0.04, 0.05), (0.06, 0.0, 0.03), (0.17, 0.05, 0.02)], 0.05),
                                     ((0.3, 0.2, 0.03), [(0.2, 0.1, 0.02), (0.28, 0.2, 0.06), (0.36, 0.26, 0.03), (0.42, 0.34, 0.02)], 0.04),
                                     ((-0.3, 0.25, 0.04), [(-0.4, 0.2, 0.02), (-0.33, 0.24, 0.07), (-0.27, 0.3, 0.05), (-0.2, 0.28, 0.02)], 0.045))):
        p = Part(f"scrap_{k + 1}", origin=c)
        ribbon(p, pts, w, "strip", twist=1.2)
        parts.append(p)
    bone = Part("bone_1", origin=(0.05, -0.25, 0.03))
    K.seg(bone, (-0.15, -0.25, 0.03), (0.25, -0.22, 0.03), [(0.025, 0.0), (0.016, 0.2), (0.015, 0.8), (0.024, 1.0)],
          "bone", segments=8)
    for e in ((-0.15, -0.25, 0.03), (0.25, -0.22, 0.03)):
        K.sphere(bone, e, 0.03, "bone", segments=8, rings=4)
    parts.append(bone)
    rib = Part("bone_2", origin=(-0.1, -0.45, 0.02))
    for k in range(3):
        arc = [(-0.2 + 0.03 * k + 0.16 * math.sin(a), -0.45 + 0.1 * math.cos(a) + 0.05 * k, 0.015)
               for a in np.linspace(-1.2, 1.2, 6)]
        rib.tube(arc, 0.008, "bone", sides=5)
    parts.append(rib)
    return parts


def build():
    by = {p.name: p for p in [torso(), head()] + [arm(s) for s in (-1, 1)] + [forearm(s) for s in (-1, 1)]
          + [leg(s) for s in (-1, 1)] + whips() + strips()}
    parts = [by[n] for n in ORDER]
    fns = {"linen": linen, "strip": strip_paint, "eyes": eyes, "tooth": tooth}
    body = Model("mummy", parts, fns, ppm=256, organic=tuple(n for n in ORDER if not n.startswith(("whip", "strip"))),
                 ground=0.0, ao_dist=0.12, ao_rays=12, ao_stride=2, front=1,
                 markers=[("EyeGlow", (0.0, 0.09, 1.646), "head"), ("WeakPoint", HEAD_C, "head")],
                 preview_yaws=(-35.0, 35.0, 120.0, 210.0), preview_closeup=((0.0, 0.08, 1.62), 0.17))
    deb = Model("mummy_debris", debris(), {"strip": strip_paint, "bone": lambda c: M.bone(c, 1209, repairs=0.0)},
                ppm=256, ground=0.0, ao_dist=0.05, front=1)
    return [body, deb]
