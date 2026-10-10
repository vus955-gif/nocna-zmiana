"""The stuffed wolf enemy: a grey timber wolf from the natural-history hall,
old taxidermy. Moth-eaten pelt with bald patches of dried hide (and a few
holes showing the wood-wool stuffing), a sewn belly seam, a neck seam and a
repaired patch on the right flank, amber glass eyes that catch the light, a
black leather nose, bared ivory teeth. No display base: it runs.

Faces +Y in Blender = -Z in Godot (the Enemy forward direction). Origin on
the floor under the body centre. Eight parts in a joint hierarchy (Godot
node names = object names), pivots at the joints:
    body   (0, 0, 0.60)                          root
    head   (0, 0.50, 0.78)   neck joint          child of body
    jaw    (0, 0.63, 0.776)  jaw hinge           child of head
    leg_fl / leg_fr  (-/+0.09, 0.28, 0.62)       shoulders, children of body
    leg_bl / leg_br  (-/+0.085, -0.33, 0.62)     hips, children of body
    tail   (0, -0.46, 0.71)  tail root           child of body
Matches src/enemies/wolf.gd: collider capsule r 0.35 h 0.9; body hurtbox
0.44 x 0.48 x 1.0 centred 0.6 high; head weak point (sphere r 0.2) at
Godot (0, 0.82, -0.62) = Blender (0, 0.62, 0.82).
"""
import math

import numpy as np
from mathutils import Matrix, Vector

from artlib import materials as M
from artlib import sculpt
from artlib.geo import Part
from artlib.model import Model
from artlib.sculpt import blob, limb

HEAD_C = (0.0, 0.62, 0.82)
HEAD_SCALE = 1.13                     # the head is sculpted small, then scaled about HEAD_C
EYES_L = [(-0.044, 0.688, 0.846), (0.044, 0.688, 0.846)]
NOSE_L = (0.0, 0.834, 0.812)
HINGE_L = (0.0, 0.63, 0.776)


def hs(p):
    """Sculpt-space head point -> model space (after the head scale)."""
    return tuple(c + (v - c) * HEAD_SCALE for v, c in zip(p, HEAD_C))


EYES = [hs(e) for e in EYES_L]
NOSE = hs(NOSE_L)
HINGE = hs(HINGE_L)
PARTS = ["body", "head", "jaw", "leg_fl", "leg_fr", "leg_bl", "leg_br", "tail"]


def T(x, y, z):
    return Matrix.Translation(Vector((x, y, z)))


def R(axis, deg):
    return Matrix.Rotation(math.radians(deg), 4, axis)


# --------------------------------------------------------------------------
# clay
# --------------------------------------------------------------------------

def _body_blobs():
    b = [
        blob((0, 0.19, 0.595), (0.15, 0.21, 0.19)),          # rib cage
        blob((0, 0.33, 0.56), (0.11, 0.1, 0.14)),            # brisket
        blob((0, 0.25, 0.73), (0.1, 0.15, 0.08)),            # withers
        blob((0.085, 0.27, 0.64), (0.06, 0.11, 0.12), rot=(-20, 0, 0)),   # shoulder blades
        blob((-0.085, 0.27, 0.64), (0.06, 0.11, 0.12), rot=(-20, 0, 0)),
        blob((0, 0.39, 0.72), (0.13, 0.12, 0.145), rot=(-30, 0, 0)),     # neck ruff
        blob((0, 0.47, 0.765), (0.1, 0.08, 0.1)),            # neck into the head
        blob((0, -0.05, 0.625), (0.12, 0.2, 0.14)),          # belly / waist (tucked up)
        blob((0, -0.15, 0.7), (0.1, 0.17, 0.09)),            # loin
        blob((0, -0.31, 0.665), (0.12, 0.13, 0.13)),         # hips
        blob((0, -0.39, 0.7), (0.095, 0.1, 0.095)),          # rump
        blob((0.07, -0.32, 0.6), (0.065, 0.13, 0.11)),       # haunches (hide the thigh tops)
        blob((-0.07, -0.32, 0.6), (0.065, 0.13, 0.11)),
        blob((0, -0.46, 0.705), (0.045, 0.05, 0.045)),       # tail root
    ]
    return b


def _leg_blobs(sx, front):
    x = sx * 0.092
    if front:
        b = [blob((x, 0.26, 0.54), (0.058, 0.085, 0.13), rot=(12, 0, 0))]     # upper arm
        b.append(blob((x, 0.205, 0.44), (0.042, 0.04, 0.045)))                # elbow
        b += limb([(x, 0.22, 0.44), (x * 1.03, 0.235, 0.26), (x * 1.03, 0.25, 0.12), (x * 1.03, 0.275, 0.05)],
                  [0.047, 0.037, 0.03, 0.03])
        paw_y = 0.3
    else:
        b = [blob((x * 0.85, -0.3, 0.56), (0.062, 0.135, 0.16), rot=(18, 0, 0))]  # thigh
        b.append(blob((x * 0.95, -0.35, 0.45), (0.05, 0.07, 0.08)))            # fur "trousers"
        b += limb([(x, -0.23, 0.41), (x * 1.03, -0.31, 0.28), (x * 1.03, -0.39, 0.165)],
                  [0.052, 0.038, 0.027])                                        # gaskin -> hock
        b.append(blob((x * 1.03, -0.405, 0.17), (0.025, 0.028, 0.028)))       # point of hock
        b += limb([(x * 1.03, -0.39, 0.165), (x * 1.03, -0.36, 0.05)], [0.027, 0.028])
        paw_y = -0.33
    b.append(blob((x * 1.03, paw_y, 0.032), (0.04, 0.055, 0.03)))              # paw
    for k, tx in enumerate((-0.026, -0.009, 0.009, 0.026)):                    # toes
        long = 0.008 if k in (1, 2) else 0.0
        b.append(blob((x * 1.03 + tx, paw_y + 0.045 + long, 0.02), (0.014, 0.018, 0.016)))
    return b


def _head_blobs():
    return [
        blob((0, 0.59, 0.84), (0.07, 0.085, 0.068)),         # cranium
        blob((0.057, 0.63, 0.812), (0.045, 0.05, 0.043)),    # cheeks
        blob((-0.057, 0.63, 0.812), (0.045, 0.05, 0.043)),
        blob((0.068, 0.565, 0.8), (0.035, 0.05, 0.06)),      # ruff behind the cheeks
        blob((-0.068, 0.565, 0.8), (0.035, 0.05, 0.06)),
        blob((0, 0.66, 0.852), (0.044, 0.04, 0.03)),         # stop / forehead
        blob((0, 0.72, 0.815), (0.04, 0.07, 0.03)),          # muzzle
        blob((0, 0.785, 0.807), (0.029, 0.045, 0.025)),
        blob((0.0, 0.832, 0.812), 0.0135, kind="BALL"),      # nose pad
        blob((0.043, 0.692, 0.846), 0.013, kind="BALL", neg=True, stiff=1.6),   # eye sockets
        blob((-0.043, 0.692, 0.846), 0.013, kind="BALL", neg=True, stiff=1.6),
        blob((0, 0.75, 0.778), (0.028, 0.08, 0.008), neg=True, stiff=1.4),       # mouth line
        blob((0, 0.52, 0.79), (0.06, 0.05, 0.07)),           # back of the skull into the neck
    ]


def _jaw_blobs():
    return [
        blob((0, 0.7, 0.768), (0.036, 0.075, 0.018)),
        blob((0, 0.775, 0.762), (0.026, 0.04, 0.016)),
        blob((0, 0.645, 0.775), (0.045, 0.03, 0.028)),       # hinge / cheek muscle
    ]


def _tail_blobs():
    return limb([(0, -0.45, 0.71), (0, -0.58, 0.65), (0, -0.7, 0.55), (0, -0.79, 0.45), (0, -0.83, 0.4)],
                [0.035, 0.052, 0.055, 0.042, 0.02])


def _clay(part, blobs, tris, slot="fur", res=0.006, cut=None):
    me = sculpt.metaball_mesh(blobs, resolution=res)
    if cut:
        sculpt.cut(me, cut)
    me = sculpt.decimate(me, tris)
    sculpt.into_part(part, me, slot)


# --------------------------------------------------------------------------
# hard bits: ears, eyes, teeth, claws
# --------------------------------------------------------------------------

def _ear(p, sx):
    w, h, t = 0.031, 0.08, 0.015
    bl, br = Vector((-w, 0, 0)), Vector((w, 0, 0))
    tip = Vector((0.004 * sx, -0.004, h))
    cup = Vector((0, -t * 0.35, h * 0.35))
    back = Vector((0, -t * 1.7, h * 0.22))
    m = T(sx * 0.049, 0.578, 0.868) @ R('Y', sx * 16) @ R('Z', -sx * 12) @ R('X', -6)
    vs = {k: p.bm.verts.new(m @ v) for k, v in (("bl", bl), ("br", br), ("tip", tip), ("cup", cup), ("back", back))}
    faces = []
    for tri, slot, want in ((("bl", "br", "cup"), "ear_inner", 1), (("br", "tip", "cup"), "ear_inner", 1),
                            (("tip", "bl", "cup"), "ear_inner", 1), (("br", "bl", "back"), "fur", -1),
                            (("bl", "tip", "back"), "fur", -1), (("tip", "br", "back"), "fur", -1)):
        f = p._face([vs[k] for k in tri], slot, smooth=False)
        f.normal_update()
        fwd = (m.to_3x3() @ Vector((0, 1, 0)))
        if (f.normal.dot(fwd) > 0) != (want > 0):
            f.normal_flip()
        faces.append(f)
    return faces


def _sphere(p, c, r, slot, seg=10):
    prof = [(0.0, -r), (r * 0.5, -r * 0.87), (r * 0.87, -r * 0.5), (r, 0.0), (r * 0.87, r * 0.5), (r * 0.5, r * 0.87),
            (0.0, r)]
    return p.lathe(prof, slot, segments=seg, center=c)


def _cone(p, base, direction, length, radius, slot, seg=5):
    f = p.lathe([(radius, 0.0), (radius * 0.75, length * 0.45), (0.0, length)], slot, segments=seg, smooth=False)
    d = Vector(direction).normalized()
    p.move(f, T(*base) @ d.to_track_quat('Z', 'Y').to_matrix().to_4x4())
    return f


def _teeth_upper(p):
    for sx in (-1, 1):
        _cone(p, (sx * 0.023, 0.8, 0.792), (sx * 0.1, 0.15, -1), 0.03, 0.0062, "tooth")    # canines
        for k in range(3):
            _cone(p, (sx * 0.028, 0.765 - k * 0.022, 0.792), (0, 0.1, -1), 0.012, 0.0045, "tooth")
        _cone(p, (sx * 0.009, 0.818, 0.795), (0, 0.2, -1), 0.012, 0.004, "tooth")          # incisors


def _teeth_lower(p):
    for sx in (-1, 1):
        _cone(p, (sx * 0.02, 0.785, 0.77), (sx * 0.1, 0.25, 1), 0.024, 0.0055, "tooth")
        for k in range(2):
            _cone(p, (sx * 0.025, 0.75 - k * 0.025, 0.772), (0, 0, 1), 0.01, 0.004, "tooth")
        _cone(p, (sx * 0.008, 0.8, 0.772), (0, 0.2, 1), 0.01, 0.0035, "tooth")


def _claws(p, sx, front):
    x = sx * 0.092 * 1.03
    paw_y = 0.3 if front else -0.33
    for k, tx in enumerate((-0.026, -0.009, 0.009, 0.026)):
        long = 0.008 if k in (1, 2) else 0.0
        _cone(p, (x + tx, paw_y + 0.06 + long, 0.016), (0, 1, -0.9), 0.02, 0.005, "claw", seg=4)


# --------------------------------------------------------------------------
# paint
# --------------------------------------------------------------------------

def wolf_fur(ctx):
    """Grey wolf pelt: agouti fur flowing back and down, dark saddle, pale
    cream belly, throat, cheeks and lower legs, black nose and lips, dark
    eye rims, a black tail tip; seams sewn by the taxidermist."""
    part = ctx.part
    x, y, z = ctx.p[:, 0], ctx.p[:, 1], ctx.p[:, 2]
    nz = ctx.n[:, 2]
    legs = np.isin(part, [3, 4, 5, 6])
    flow = np.tile([0.0, -1.0, -0.3], (ctx.N, 1))
    flow[legs] = (0.0, -0.2, -1.0)
    flow[part == 7] = (0.0, -0.7, -0.7)
    s = M.fur(ctx, flow=flow, center=5.3, moth=1.0)
    furry = s.ramp_id == 0
    # dark saddle along the back, the top of the head and the tail
    s.shade -= np.isin(part, [0, 1, 7]) * M.smoothstep(0.15, 0.85, nz) * 1.7
    # pale underparts
    wob = ctx.fbm(14.0, 2, 21) * 0.25
    pale = (part == 0) & ((nz < -0.35 + wob) | ((y > 0.33 + wob * 0.2) & (z < 0.6 + wob * 0.1)))
    pale |= (part == 1) & ((nz < -0.25 + wob) | ((np.abs(x) > 0.05 + wob * 0.05) & (y > 0.62) & (z < 0.82)))
    pale |= part == 2
    pale |= legs & ((z < 0.16 + wob * 0.2) | (ctx.n[:, 0] * np.sign(x + 1e-9) < -0.55 + wob))
    pale &= furry
    s.use_ramp(M.P["fur_pale"], mask=pale, shade=s.shade - 0.6)
    # tail tip and ear rims: black
    s.shade[(part == 7) & (y < -0.74)] -= 2.6
    s.shade[(part == 1) & (z > 0.93)] -= 2.2
    head = part == 1
    # nose leather, lips, eye rims
    nd = np.linalg.norm(ctx.p - np.array(NOSE), axis=1)
    nose = head & (nd < 0.026) & (y > 0.815)
    s.use_ramp(M.P["leather"], mask=nose, shade=2.0 + ctx.fbm(90.0, 2, 3) * 1.0 + np.clip(ctx.curv, 0, 1) * 2.0)
    s.rough = np.where(nose, 0.32, s.rough)
    lips = (head & (z < 0.797) & (y > 0.66) & (nz > -0.6)) | ((part == 2) & (z > 0.772) & (y > 0.66) & (nz < 0.4))
    s.use_ramp(M.P["hair"], mask=lips & ~nose, shade=np.full(ctx.N, 0.8) + ctx.rand(4) * 0.8)
    mouth = (head & (nz < -0.55) & (y > 0.66) & (z < 0.8)) | ((part == 2) & (nz > 0.45) & (y > 0.67))
    g = M.gum(ctx)
    s.merge(M._select(g, mouth), mouth)
    for ex, ey, ez in EYES:
        d = np.sqrt((x - ex) ** 2 + (y - ey) ** 2 + (z - ez) ** 2)
        rim = head & (d > 0.011) & (d < 0.02)
        s.use_ramp(M.P["hair"], mask=rim, shade=np.full(ctx.N, 0.6))
    # seams: belly, neck, and a sewn-in repair patch on the right flank
    dist = np.full(ctx.N, np.inf)
    along = np.zeros(ctx.N)
    belly = (part == 0) & (nz < -0.5) & (y > -0.25) & (y < 0.4)
    dist[belly] = x[belly]
    along[belly] = y[belly]
    neck_plane = y - 0.462 - 0.3 * (z - 0.78)
    neck = np.isin(part, [0, 1]) & (np.abs(neck_plane) < 0.02)
    dist[neck] = neck_plane[neck]
    along[neck] = np.arctan2(z[neck] - 0.77, x[neck]) * 0.1
    ang = np.arctan2(z - 0.64, y - 0.03)
    rad = np.sqrt((y - 0.03) ** 2 + (z - 0.64) ** 2) * (1.0 + 0.18 * np.sin(ang * 3.0 + 0.7)
                                                        + 0.08 * np.sin(ang * 5.0 + 2.0))
    flank = (part == 0) & (x > 0.06) & (np.abs(rad - 0.07) < 0.02)
    dist[flank] = rad[flank] - 0.07
    along[flank] = ang[flank] * 0.07
    inside = (part == 0) & (x > 0.06) & (rad < 0.07) & furry
    s.shade[inside] += 0.8
    M.stitches(ctx, s, dist, along, width=0.0055, pitch=0.013, seed=5)
    return s


def ear_inner(ctx):
    s = M.fur(ctx, flow=(0.0, 0.0, 1.0), ramp="hide", center=3.4, moth=0.0)
    s.shade -= (1.0 - ctx.ao) * 2.0
    return s


def wolf_eye(ctx):
    left = (ctx.p[:, 0] < 0)[:, None]
    a = M.glass_eye(ctx, EYES[0], (-0.42, 0.88, 0.1), iris=0.0105, pupil=0.0042)
    b = M.glass_eye(ctx, EYES[1], (0.42, 0.88, 0.1), iris=0.0105, pupil=0.0042)
    s = M.Surface(ctx.N)
    s.albedo = np.where(left, a.colors(), b.colors())
    s.rough = a.rough
    s.emit = np.where(left, a.emit, b.emit)
    return s


def claw(ctx):
    return M.ivory(ctx, center=2.6)


# --------------------------------------------------------------------------

def build():
    body = Part("body", origin=(0, 0, 0.6))
    _clay(body, _body_blobs(), 2600, res=0.007)
    grow = T(*HEAD_C) @ Matrix.Scale(HEAD_SCALE, 4) @ T(*(-c for c in HEAD_C))
    head = Part("head", origin=hs((0, 0.5, 0.78)), parent="body")
    _clay(head, _head_blobs(), 1900, res=0.0045)
    for sx in (-1, 1):
        _ear(head, sx)
        _sphere(head, EYES_L[0 if sx < 0 else 1], 0.0125, "eye")
    _teeth_upper(head)
    head.move(list(head.bm.faces), grow)
    jaw = Part("jaw", origin=HINGE, parent="head")
    _clay(jaw, _jaw_blobs(), 420, res=0.004)
    _teeth_lower(jaw)
    jaw.move(list(jaw.bm.faces), grow @ T(*HINGE_L) @ R('X', -9) @ T(*(-c for c in HINGE_L)))
    legs = []
    for name, sx, front in (("leg_fl", -1, True), ("leg_fr", 1, True), ("leg_bl", -1, False), ("leg_br", 1, False)):
        origin = (sx * 0.09, 0.28, 0.62) if front else (sx * 0.085, -0.33, 0.62)
        leg = Part(name, origin=origin, parent="body")
        _clay(leg, _leg_blobs(sx, front), 520, res=0.005)
        _claws(leg, sx, front)
        legs.append(leg)
    tail = Part("tail", origin=(0, -0.46, 0.71), parent="body")
    _clay(tail, _tail_blobs(), 420, res=0.006)
    parts = [body, head, jaw] + legs + [tail]
    fns = {"fur": wolf_fur, "ear_inner": ear_inner, "eye": wolf_eye, "tooth": M.ivory, "claw": claw}
    return Model("wolf", parts, fns, ppm=256, organic=tuple(PARTS), ground=0.0, ao_dist=0.12, ao_rays=12,
                 ao_stride=1, front=1, preview_yaws=(-60.0, 30.0, 90.0, 200.0), preview_elevation=12.0,
                 preview_closeup=((0.0, 0.7, 0.82), 0.16))
