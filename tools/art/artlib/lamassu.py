"""The lamassu: a human-headed winged bull of Sargon's palace at Khorsabad,
built once and used twice (models/lamassu.py: the rigged guardian;
models/khorsabad_gate.py: the pair of gate statues, five-legged).

Shapes (guardian scale: 4.0 m to the top of the crown, facing +Y, origin on
the floor under the body):
  * body: metaball clay of a bull (barrel, deep chest, hump, haunches) with
    a thick neck rising to the head;
  * head: the sculpted face of artlib.face with Assyrian proportions, bull
    ears with bronze earrings, a long squared beard in tiers of curls, hair
    falling in curls behind, a tall cylindrical crown (feather crest, band
    of rosettes, three pairs of horns wrapping round it);
  * wings: carved plates (artlib.asy_relief: rows of covert scales, long flight
    feathers), each in an inner part and a tip part, folded along the back,
    the tips curling up over the rump;
  * legs: columnar with tendon grooves, knees and fetlocks, cloven hooves;
  * tail: hanging, ending in a tuft of curls.
Materials sample positions in the statue's own frame (``to_local``), so the
mirrored right-hand gate statue paints like the left one.

``build(P, s, ...)`` takes a part resolver P(name) -> geo.Part, so the
guardian gets one part per joint and a gate statue one part for everything.
"""
import math

import bmesh
import numpy as np
from mathutils import Matrix, Vector
from mathutils.geometry import tessellate_polygon

from . import asy, asy_relief as rl, face as FACE, sculpt
from . import asy_figures as F
from . import kit as K
from .asy import P as PAL
from .materials import Surface, _dither, smoothstep
from .sculpt import blob, limb

# --- key points (guardian scale 1.0, Blender, facing +Y) -------------------
HEAD_C = Vector((0.0, 1.5, 3.04))          # centre of the unit face (chin to crown = FACE_S)
FACE_S = 0.62
NECK = (0.0, 1.22, 2.6)                    # head pivot
CROWN_BASE = 3.22
CROWN_TOP = 3.98
BODY = (0.0, 0.0, 1.9)
LEGS = {
    # shoulder / hip, knee / hock, fetlock, hoof ground point
    "fl": [(-0.41, 0.8, 1.55), (-0.41, 0.86, 0.72), (-0.41, 0.9, 0.24), (-0.41, 0.98, 0.0)],
    "fr": [(0.41, 0.8, 1.55), (0.41, 0.86, 0.72), (0.41, 0.9, 0.24), (0.41, 0.98, 0.0)],
    "bl": [(-0.41, -0.98, 1.65), (-0.41, -1.2, 0.7), (-0.41, -1.1, 0.24), (-0.41, -1.03, 0.0)],
    "br": [(0.41, -0.98, 1.65), (0.41, -1.2, 0.7), (0.41, -1.1, 0.24), (0.41, -1.03, 0.0)],
}
WING_ROOT = (0.54, 0.68, 2.18)             # x mirrored per side
WING_TILT = 22.0                           # the plane leans in over the back (degrees)
WING_SPLIT = 1.15                          # inner part | tip part along the wing
WING_JOINT_B = 0.62                        # height of the wing joint on the plate
TAIL_ROOT = (0.0, -1.46, 2.0)


def _sv(p, s):
    return Vector(p) * s


# --------------------------------------------------------------------------
# the wing drawing (a along the wing from the root, b up)
# --------------------------------------------------------------------------

WING_OUTLINE = [(0.0, 0.0), (0.1, 0.3), (0.4, 0.5), (0.85, 0.6), (1.35, 0.66), (1.8, 0.76), (2.12, 0.92),
                (2.34, 1.12), (2.46, 1.32), (2.4, 1.38), (2.26, 1.2), (2.14, 1.0), (2.0, 0.8), (1.86, 0.58),
                (1.72, 0.36), (1.56, 0.16), (1.38, 0.0), (1.18, -0.14), (0.96, -0.25), (0.72, -0.33),
                (0.48, -0.36), (0.26, -0.32), (0.08, -0.2)]


def wing_relief(ppm, seed=1201):
    """The carved wing (both parts on one canvas): coverts as rows of scales
    near the shoulder, then long flight feathers sweeping back and up."""
    R = rl.Relief(2.7, 1.95, ppm, u0=-0.1, v0=-0.45, seed=seed)
    pen = F.Pen(R, rl.Xf(0.0, 0.0, 1.0, 1), default="wing", depth=1.6)
    F.wing(pen, WING_OUTLINE, (0.0, 0.05), (2.42, 1.25), "wing", 0.02, covert=0.34, feather=0.075, scale=0.07)
    # feather tips: notches along the lower edge
    for k in range(12):
        a = 0.6 + k * 0.15
        R.cut(R.seg((a, -0.42), (a + 0.14, 0.04)), R.px * 1.2, 0.004, "wing")
    return R


def wing_frame(sx, s, tilt=WING_TILT):
    """(origin, A along, B up, N outward) of a wing plane, side sx = -1
    (left, -X) or +1."""
    o = Vector((sx * WING_ROOT[0], WING_ROOT[1], WING_ROOT[2])) * s
    A = Vector((0.0, -1.0, 0.0))
    t = math.radians(tilt)
    B = Vector((-sx * math.sin(t), 0.0, math.cos(t)))
    N = A.cross(B).normalized()
    if N.x * sx < 0:
        N = -N
    return o, A, B, N


def plane_prism(p, loop, o, A, B, N, th, front, back, side, s=1.0):
    """A plate cut along the 2D loop (a, b) on the plane o + a A + b B,
    thickness th centred on the plane: cap +N (front), cap -N (back), walls."""
    def at(q, d):
        return o + A * (q[0] * s) + B * (q[1] * s) + N * d
    out = []
    for d, slot, sign in ((th / 2, front, 1), (-th / 2, back, -1)):
        pts = [tuple(at(q, d)) for q in loop]
        tris = tessellate_polygon([pts])
        vs = [p.bm.verts.new(v) for v in pts]
        for a_, b_, c_ in tris:
            if len({a_, b_, c_}) < 3:
                continue
            try:
                f = p._face([vs[a_], vs[b_], vs[c_]], slot)
            except ValueError:
                continue
            f.normal_update()
            if f.normal.dot(N) * sign < 0:
                f.normal_flip()
            out.append(f)
    n = len(loop)
    cx = sum(q[0] for q in loop) / n
    cy = sum(q[1] for q in loop) / n
    c3 = at((cx, cy), 0.0)
    for i in range(n):
        a, b = loop[i], loop[(i + 1) % n]
        f = p.poly([tuple(at(a, -th / 2)), tuple(at(b, -th / 2)), tuple(at(b, th / 2)), tuple(at(a, th / 2))], side)[0]
        f.normal_update()
        if f.normal.dot(f.calc_center_median() - c3) < 0:
            f.normal_flip()
        out.append(f)
    return out


# --------------------------------------------------------------------------
# geometry
# --------------------------------------------------------------------------

def body_clay(s):
    b = [
        blob((0, 0.0, 1.78), (0.64, 1.1, 0.6)),              # barrel
        blob((0, 0.85, 1.72), (0.66, 0.48, 0.66)),           # chest
        blob((0, 1.12, 1.3), (0.34, 0.28, 0.34)),            # dewlap
        blob((0, 0.62, 2.18), (0.48, 0.5, 0.3)),             # hump
        blob((0.5, 0.72, 1.6), (0.26, 0.42, 0.55)),          # shoulders
        blob((-0.5, 0.72, 1.6), (0.26, 0.42, 0.55)),
        blob((0, -0.6, 2.0), (0.55, 0.6, 0.42)),             # loins
        blob((0.47, -1.0, 1.72), (0.26, 0.5, 0.58)),         # haunches
        blob((-0.47, -1.0, 1.72), (0.26, 0.5, 0.58)),
        blob((0, -1.2, 1.95), (0.48, 0.32, 0.42)),           # rump
        blob((0, 0.1, 1.36), (0.52, 0.85, 0.32)),            # belly
    ]
    b += limb([(0, 0.85, 2.1), (0, 1.15, 2.45), (0, 1.32, 2.72)], [0.5, 0.45, 0.36])        # neck
    return [blob(tuple(Vector(x["co"]) * s), tuple(v * s for v in x["semi"]), x["kind"], x["stiff"], x["neg"],
                 x["rot"]) for x in b]


def _clay(part, blobs, tris, slot, res):
    me = sculpt.metaball_mesh(blobs, resolution=res)
    me = sculpt.decimate(me, tris)
    sculpt.into_part(part, me, slot)


def leg(p, pts, s, front, slot="stone", parts=None):
    """A leg through its joints; ``parts`` = (thigh, shin, hoof) Parts or
    None for all in p. Columnar, a little flattened, knee and fetlock
    knobs, a cloven hoof."""
    a, b, c, g = [Vector(q) * s for q in pts]
    pt, ps, ph = parts if parts else (p, p, p)
    top = a + Vector((0, 0, 0.2 * s))
    if front:
        K.seg(pt, top, b, [(0.27 * s, 0.0), (0.27 * s, 0.3), (0.21 * s, 0.75), (0.17 * s, 1.0)], slot, segments=12,
              squash=(0.84, 1.0))
    else:
        K.seg(pt, top, b, [(0.32 * s, 0.0), (0.3 * s, 0.35), (0.2 * s, 0.8), (0.16 * s, 1.0)], slot, segments=12,
              squash=(0.8, 1.0))
    K.sphere(ps, b, 0.175 * s, slot, segments=10, rings=6, squash=(0.84, 1.0))
    K.seg(ps, b, c, [(0.16 * s, 0.0), (0.135 * s, 0.4), (0.13 * s, 1.0)], slot, segments=10, squash=(0.82, 1.0))
    K.sphere(ph, c, 0.15 * s, slot, segments=10, rings=6, squash=(0.88, 1.0))
    hoof_top = Vector((g.x, g.y - 0.02 * s, 0.2 * s))
    K.seg(ph, c, hoof_top, [(0.14 * s, 0.0), (0.15 * s, 1.0)], slot, segments=10, squash=(0.88, 1.0))
    ph.lathe([(0.2 * s, 0.0), (0.195 * s, 0.06 * s), (0.16 * s, 0.2 * s), (0.12 * s, 0.21 * s)], "hoof",
             segments=12, center=(g.x, g.y + 0.03 * s, 0.0), squash=(0.88, 1.05), smooth=False)


def head_parts(ph, pc, s, slot_face="face", hair_part=None):
    """Face, ears, earrings, beard and hair into ``ph``; crown and horns
    into ``pc``."""
    hc = HEAD_C * s
    fs = FACE_S * s
    me = FACE.head_mesh({"nose": 1.25, "lips": 0.7, "size": (0.43, 0.47, 0.5)})
    me = sculpt.decimate(me, 1400)
    sculpt.into_part(ph, me, slot_face, transform=Matrix.Translation(hc) @ Matrix.Scale(fs, 4))
    # bull ears with bronze earrings
    for sx in (-1, 1):
        e = hc + Vector((sx * 0.29, -0.06, 0.08)) * s
        K.cone(ph, e, (sx * 1.0, -0.9, -0.15), 0.22 * s, 0.075 * s, slot_face, segments=6, tip=0.012 * s)
        K.sphere(ph, hc + Vector((sx * 0.27, 0.0, -0.1)) * s, 0.045 * s, "bronze", segments=8, rings=4)
        K.sphere(ph, hc + Vector((sx * 0.27, 0.0, -0.18)) * s, 0.035 * s, "bronze", segments=8, rings=4,
                 squash=(1.0, 1.0))
    # the beard: a squared block from the lower lip to the chest, slightly bowed
    bl = []
    for k in range(6):
        t = k / 5
        c = hc + Vector((0.0, 0.22 + 0.1 * t, -0.24 - 0.56 * t)) * s
        w = (0.2 - 0.025 * t) * s
        bl.append(blob(tuple(c), (w, 0.12 * s, 0.09 * s)))
    for sx in (-1, 1):
        bl.append(blob(tuple(hc + Vector((sx * 0.1, 0.33, -0.8)) * s), (0.1 * s, 0.11 * s, 0.07 * s)))
    me = sculpt.metaball_mesh(bl, resolution=0.025 * s)
    me = sculpt.cut(me, [(tuple(hc + Vector((0, 0, -0.84)) * s), (0, 0, -1))])
    me = sculpt.decimate(me, 700)
    sculpt.into_part(ph, me, "beard")
    # cheek beard from below the ears to the beard, a mass of curls
    cheek = []
    for sx in (-1, 1):
        cheek += limb([tuple(hc + Vector((sx * 0.24, -0.04, -0.08)) * s), tuple(hc + Vector((sx * 0.22, 0.08, -0.22)) * s),
                       tuple(hc + Vector((sx * 0.17, 0.2, -0.3)) * s)], [0.085 * s, 0.1 * s, 0.1 * s], spacing=0.6)
    cheek.append(blob(tuple(hc + Vector((0.0, 0.08, -0.3)) * s), (0.22 * s, 0.16 * s, 0.1 * s)))
    me = sculpt.metaball_mesh(cheek, resolution=0.025 * s)
    me = sculpt.decimate(me, 500)
    sculpt.into_part(ph, me, "beard")
    # moustache
    K.seg(ph, hc + Vector((-0.17, 0.4, -0.2)) * s, hc + Vector((0.17, 0.4, -0.2)) * s,
          [(0.035 * s, 0.0), (0.05 * s, 0.5), (0.035 * s, 1.0)], "beard", segments=6, squash=(0.7, 1.0))
    # hair falling behind the head to the shoulders
    hp = hair_part or ph
    K.seg(hp, hc + Vector((0.0, -0.12, 0.1)) * s, hc + Vector((0.0, -0.2, -0.62)) * s,
          [(0.3 * s, 0.0), (0.32 * s, 0.6), (0.3 * s, 1.0)], "hair", segments=12, squash=(1.1, 0.7))
    # crown: cylinder, band of rosettes, feather crest, horns
    z0, z1 = CROWN_BASE * s, CROWN_TOP * s
    cc = (hc.x, hc.y - 0.02 * s, 0.0)
    pc.lathe([(0.3 * s, z0 - 0.02 * s), (0.31 * s, z0 + 0.1 * s), (0.325 * s, z1 - 0.2 * s), (0.34 * s, z1 - 0.16 * s)],
             "crown", segments=20, center=cc, cap_bottom=False, cap_top=False)
    pc.lathe([(0.34 * s, z1 - 0.16 * s), (0.36 * s, z1 - 0.14 * s), (0.37 * s, z1 - 0.01 * s), (0.3 * s, z1),
              (0.0, z1 - 0.02 * s)], "crest", segments=32, center=cc, cap_bottom=False,
             ring_scale=lambda i, j: 1.0 + (0.035 if (i % 2 and j in (1, 2)) else 0.0))
    for k in range(10):
        a = math.tau * k / 10
        K.sphere(pc, (cc[0] + math.cos(a) * 0.335 * s, cc[1] + math.sin(a) * 0.335 * s, z1 - 0.26 * s), 0.035 * s,
                 "bronze", segments=8, rings=4, squash=(1.0, 1.0))
    for h in range(3):
        zh = z0 + (0.1 + h * 0.15) * s
        for sx in (-1, 1):
            pts = []
            for i in range(9):
                t = i / 8
                ang = -math.pi / 2 + sx * math.pi * (0.06 + 0.88 * t)
                r = (0.33 + 0.012 * math.sin(t * math.pi)) * s
                z = zh + (0.02 * t + 0.08 * max(0.0, t - 0.75) / 0.25) * s
                pts.append((cc[0] + math.cos(ang) * r, cc[1] + math.sin(ang) * r, z))
            pc.tube(pts, lambda t: (0.062 - 0.042 * t) * s, "horn", sides=6)
    return hc


def wing_parts(pw, pt, sx, s, R, tilt=WING_TILT, th=0.12):
    """The two plates of one wing into ``pw`` (inner) and ``pt`` (tip)."""
    o, A, B, N = wing_frame(sx, s, tilt)
    L = R.layers["wing"]
    inner = L.mask & (R.X < WING_SPLIT)
    tip = L.mask & (R.X >= WING_SPLIT)
    for part, mask, t in ((pw, inner, th), (pt, tip, th * 0.8)):
        for loop in rl.outlines(R, mask, tol=0.012):
            plane_prism(part, loop, o, A, B, N, t * s, "wing", "wing", "wing_edge", s=s)
    return o, A, B, N


def tail(p, s):
    pts = [Vector(TAIL_ROOT) * s, Vector((0.0, -1.56, 1.7)) * s, Vector((0.0, -1.6, 1.3)) * s,
           Vector((0.0, -1.58, 1.04)) * s]
    p.tube([tuple(q) for q in pts], lambda t: (0.065 - 0.025 * t) * s, "stone", sides=8)
    me = sculpt.metaball_mesh([blob(tuple(Vector((0.0, -1.58, 0.88)) * s), (0.12 * s, 0.11 * s, 0.22 * s)),
                               blob(tuple(Vector((0.0, -1.58, 0.72)) * s), (0.09 * s, 0.09 * s, 0.1 * s))],
                              resolution=0.02 * s)
    me = sculpt.decimate(me, 160)
    sculpt.into_part(p, me, "tuft")


# --------------------------------------------------------------------------
# materials (positions in the statue's own frame through to_local)
# --------------------------------------------------------------------------

def _curls(q, spacing, seed=0):
    """Staggered snail curls on a surface parameterised by q (N x 2):
    returns (bump 0..1, dark mask: the drilled centre and the gaps)."""
    row = np.floor(q[:, 1] / (spacing * 0.86))
    off = np.mod(row, 2) * 0.5
    fx = q[:, 0] / spacing + off
    cx = np.floor(fx) + 0.5
    dx = (fx - cx) * spacing
    dy = q[:, 1] - (row + 0.5) * spacing * 0.86
    r = np.hypot(dx, dy) / (spacing * 0.48)
    bump = np.sqrt(np.clip(1.0 - r * r, 0.0, 1.0))
    return bump, (r < 0.22) | (r > 0.98)


def _locks(q, pitch):
    """Vertical wavy locks: groove mask."""
    w = q[:, 0] + 0.012 * np.sin(q[:, 1] * 40.0)
    return np.abs(np.mod(w / pitch, 1.0) - 0.5) < 0.12


def materials(to_local, s, R_wing, cracked=False, seed=1301):
    """Material functions for every slot of a lamassu. ``to_local(ctx)`` ->
    (N, 3) positions in the guardian frame (scale 1)."""
    def side_param(ctx, q):
        # a 2D surface parameter for carved patterns: across the face (x or y) and up (z)
        use_x = np.abs(ctx.n[:, 1]) > np.abs(ctx.n[:, 0])
        return np.stack([np.where(use_x, q[:, 0], q[:, 1]), q[:, 2]], axis=1)

    def crack_overlay(ctx, s_):
        if not cracked:
            return s_
        q = to_local(ctx)
        n1 = np.abs(ctx.fbm(1.2, 4, 77, p=q * 1.0))
        n2 = np.abs(ctx.fbm(2.6, 3, 78, p=q * 1.0))
        crack = (n1 < 0.022) | ((n2 < 0.016) & (ctx.fbm(0.8, 2, 79, p=q) > 0.0))
        glow = crack & (ctx.fbm(0.9, 2, 80, p=q) > -0.2)
        s_.shade = np.where(crack, s_.shade - 3.0, s_.shade)
        if glow.any():
            s_.use_ramp(PAL["asy_flame"], mask=glow, shade=np.full(ctx.N, 4.5) + ctx.fbm(6.0, 2, 81, p=q) * 1.5)
            em = np.zeros((ctx.N, 3))
            em[glow] = s_.colors()[glow]
            s_.emit = em
        s_.height = s_.height - crack * 0.006
        return s_

    def stone(ctx):
        q = to_local(ctx)
        sp = side_param(ctx, q)
        st = asy.alabaster(ctx, seed=seed, center=8.8)
        x, y, z = q[:, 0], q[:, 1], q[:, 2]
        nz = ctx.n[:, 2]
        # belly fringe: locks hanging along the lower flank, ending in curls
        fringe = (z > 1.18) & (z < 1.62) & (y > -0.75) & (y < 0.95) & (nz < 0.5)
        lk = _locks(sp, 0.045)
        bump, dark = _curls(sp, 0.09, seed)
        curl_row = fringe & (z < 1.32)
        st.shade = np.where(fringe & ~curl_row & lk, st.shade - 2.0, st.shade)
        st.shade = np.where(curl_row, st.shade + bump * 1.6 - dark * 2.2, st.shade)
        # curls patches on the shoulder and haunch, like the stone originals
        patch = ((np.hypot(y - 0.72, z - 1.95) < 0.22) | (np.hypot(y + 0.95, z - 2.05) < 0.24)) & (np.abs(x) > 0.3)
        b2, d2 = _curls(sp, 0.085, seed + 1)
        st.shade = np.where(patch, st.shade + b2 * 1.4 - d2 * 2.0, st.shade)
        # tendons down the legs
        legs = z < 1.2
        tend = legs & (np.abs(np.mod(np.arctan2(ctx.n[:, 1], ctx.n[:, 0]) * 3.0 / math.pi, 1.0) - 0.5) < 0.05)
        st.shade = np.where(tend, st.shade - 1.6, st.shade)
        st.height = (st.height + np.where(curl_row, bump * 0.006, 0.0) + np.where(patch, b2 * 0.005, 0.0)
                     - (fringe & ~curl_row & lk) * 0.003 - tend * 0.003)
        return crack_overlay(ctx, st)

    def face_fn(ctx):
        q = to_local(ctx)
        st = asy.alabaster(ctx, seed=seed + 2, center=9.2)
        st.shade += np.clip(ctx.curv, 0, 1) * 1.2 - np.clip(-ctx.curv, 0, 1) * 1.8
        u = (q - np.array(HEAD_C)) / FACE_S
        ux, uy, uz = u[:, 0], u[:, 1], u[:, 2]
        eye = np.zeros(ctx.N, bool)
        rim = np.zeros(ctx.N, bool)
        pupil = np.zeros(ctx.N, bool)
        for ex, ez in FACE.EYES:
            dx = (ux - ex) / 0.072
            ok = (np.abs(dx) < 1.0) & (uy > 0.1)
            sgn = 1 if ex > 0 else -1
            top = 0.028 * np.clip(1 - dx * dx, 0, 1) ** 0.8 + 0.006 * dx * sgn
            bot = -0.018 * np.clip(1 - dx * dx, 0, 1) ** 0.9 + 0.004 * dx * sgn
            dz = uz - ez
            inside = ok & (dz > bot) & (dz < top)
            eye |= inside
            rim |= ok & (dz > bot - 0.008) & (dz < top + 0.008) & ~inside
            pupil |= inside & (np.hypot((ux - ex) / 0.022, dz / 0.022) < 1.0)
        st.use_ramp(PAL["asy_glaze_white"], mask=eye, shade=np.full(ctx.N, 4.0) - (1.0 - ctx.ao) * 2.0)
        st.use_ramp(PAL["asy_paint_black"], mask=pupil | rim, shade=np.full(ctx.N, 1.2))
        brows = (uy > 0.05) & (np.abs(uz - 0.11) < 0.02) & (np.abs(ux) < 0.24) & (np.abs(ux) > 0.03)
        st.use_ramp(PAL["asy_paint_black"], mask=brows, shade=np.full(ctx.N, 2.4) + _dither(ctx, 0.6, 3))
        return crack_overlay(ctx, st)

    def hairy(ctx, curl_tiers):
        q = to_local(ctx)
        sp = side_param(ctx, q)
        st = asy.alabaster(ctx, seed=seed + 3, center=8.6)
        z = q[:, 2]
        bump, dark = _curls(sp, 0.095, seed + 4)
        lk = _locks(sp, 0.055)
        tier = np.zeros(ctx.N, bool)
        for z0, z1 in curl_tiers:
            tier |= (z > z0) & (z < z1)
        shade = np.where(tier, bump * 2.4 - dark * 2.6, lk * -2.4)
        st.shade = st.shade + shade
        centre = tier & (bump > 0.97)
        paint = (centre | (lk & ~tier)) & (ctx.fbm(5.0, 2, seed + 5, p=q) > -0.3)
        st.use_ramp(PAL["asy_paint_black"], mask=paint, shade=np.full(ctx.N, 2.2))
        st.height = np.where(tier, bump * 0.008, lk * -0.004)
        st.rough = np.where(paint, 0.85, st.rough)
        return crack_overlay(ctx, st)

    hz = HEAD_C[2]
    beard = lambda ctx: hairy(ctx, [(hz - 0.4, hz - 0.12), (hz - 0.92, hz - 0.72)])
    hair = lambda ctx: hairy(ctx, [(hz - 0.75, hz - 0.5)])
    tuft = lambda ctx: hairy(ctx, [(0.0, 5.0)])

    def crown(ctx):
        q = to_local(ctx)
        st = asy.alabaster(ctx, seed=seed + 6, center=8.6)
        z = q[:, 2]
        ang = np.arctan2(q[:, 1] - HEAD_C[1], q[:, 0] - HEAD_C[0])
        band = (z > CROWN_TOP - 0.36) & (z < CROWN_TOP - 0.16)
        st.use_ramp(PAL["asy_ochre_red"], mask=band & (ctx.fbm(14.0, 2, seed + 7, p=q) > 0.3),
                    shade=np.full(ctx.N, 3.4) + _dither(ctx, 0.6, seed + 8))
        flutes = np.abs(np.mod(ang * 40.0 / math.tau, 1.0) - 0.5) < 0.15
        lower = (z < CROWN_TOP - 0.36)
        st.shade = np.where(lower & flutes, st.shade - 0.8, st.shade)
        st.height = st.height - (lower & flutes) * 0.002
        return crack_overlay(ctx, st)

    def crest(ctx):
        q = to_local(ctx)
        st = asy.alabaster(ctx, seed=seed + 9, center=8.0)
        ang = np.arctan2(q[:, 1] - HEAD_C[1], q[:, 0] - HEAD_C[0])
        fe = np.abs(np.mod(ang * 32.0 / math.tau, 1.0) - 0.5) < 0.18
        st.shade = np.where(fe, st.shade - 1.8, st.shade + 0.6)
        st.height = st.height - fe * 0.004
        return crack_overlay(ctx, st)

    def horn(ctx):
        st = asy.alabaster(ctx, seed=seed + 10, center=8.2)
        ring = np.abs(np.mod(ctx.uvm[:, 1] * 22.0, 1.0) - 0.5) < 0.15
        st.shade = np.where(ring, st.shade - 1.6, st.shade)
        st.height = st.height - ring * 0.003
        return crack_overlay(ctx, st)

    wmaps = asy.ReliefMaps(R_wing, base=False)

    def wing_uv_factory():
        def uv(ctx):
            q = to_local(ctx)
            sx = np.where(q[:, 0] < 0, -1.0, 1.0)
            out_a = np.zeros(ctx.N)
            out_b = np.zeros(ctx.N)
            for side in (-1.0, 1.0):
                o, A, B, N = wing_frame(side, 1.0)
                m = sx == side
                d = q[m] - np.array(o)
                out_a[m] = d @ np.array(A)
                out_b[m] = d @ np.array(B)
            return out_a, out_b
        return uv

    wing_rel = asy.relief_material(wmaps, uv=wing_uv_factory(), center=8.6, paint=0.0, grime=0.0, bevel=0.4)

    def wing(ctx):
        return crack_overlay(ctx, wing_rel(ctx))

    def wing_edge(ctx):
        return crack_overlay(ctx, asy.alabaster(ctx, seed=seed + 11, center=8.0))

    def hoof(ctx):
        st = asy.alabaster(ctx, seed=seed + 12, center=7.0)
        groove = np.abs(to_local(ctx)[:, 0] - np.round(to_local(ctx)[:, 0] / 0.3) * 0.3) < 0.008
        st.shade = np.where(groove, st.shade - 3.0, st.shade)
        return crack_overlay(ctx, st)

    return {"stone": stone, "face": face_fn, "beard": beard, "hair": hair, "tuft": tuft, "crown": crown,
            "crest": crest, "horn": horn, "wing": wing, "wing_edge": wing_edge, "hoof": hoof,
            "bronze": lambda c: asy.bronze_aged(c, center=5.4, green=0.6)}


def unwrap(part, angle=80.0):
    """Smart-unwraps a clay part with a wide angle limit (fewer, larger
    islands than the pipeline's default: the gate pair would otherwise need
    a huge atlas). Its UVs are then locked; do not list it as organic."""
    from . import scene
    scene.smart_unwrap(part, angle=angle)
