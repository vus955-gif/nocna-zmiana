"""Generał samurajów, guardian of the Asia wing: an empty o-yoroi of a
great lord, 2.7 m to the crown of the helmet (2.9 m with the horns): black
lacquered lames under dense crimson lacing, gilt fittings, the stencilled
leather breastplate, great square shoulder guards, four big skirt panels,
blue-and-gold brocade sleeves, a ribbed kabuto with tall gilt kuwagata
horns round a sun disc, a red menpo mask with a white moustache - and
behind the mask only a smoky dark with two ember eyes. A great crimson
agemaki bow on the back. A nodachi (a field sword, 2.15 m) held in both
hands in the middle guard; the empty scabbard at the left hip; a lacquered
bow and a quiver of arrows on the back for the second phase's volleys.

Drawn at the scale of a 1.8 m figure (artlib/samurai.py) and scaled by
SCALE = 1.36. Faces +Y in Blender = -Z in Godot; origin on the floor
between the feet. Parts (Godot names; pivots in Blender (x, y, z) after
scaling; Godot = (x, z, -y)):

    pelvis                    (0, 0, 1.29)     hips, waist sash         root
      kusazuri_f/_b/_l/_r     skirt panels, pivot at their top edge    children of pelvis
      thigh_l / thigh_r       (-/+0.163, 0, 1.25)  hips                children of pelvis
        shin_l / shin_r       (-/+0.177, 0.068, 0.71)  knees
          foot_l / foot_r     (-/+0.177, 0, 0.13)  ankles
      saya                    the empty scabbard at the left hip       child of pelvis
      torso                   (0, 0, 1.43)     waist (cuirass)          child of pelvis
        head                  (0, 0, 2.20)     neck: kabuto, menpo, void
        upperarm_l / _r       (-/+0.408, 0, 2.07)  shoulders
          sode_l / sode_r     shoulder guards, pivot on the shoulder top
          forearm_l / _r      elbows
            hand_l / hand_r   wrists (armoured fists on the grip)
              sword           (child of hand_r) pivot = the right-hand grip
        bow                   the bow slung across the back            child of torso
        quiver                the quiver at the right of the back      child of torso
          arrow               one arrow, to draw and nock              child of quiver
Markers: face (child of head, between the ember eyes: weak point), back
(child of torso, the agemaki knot: weak point), blade_tip and glint
(children of sword: the point; a spot on the edge near the tip for the
glint before the dash-cut), bow_grip (child of bow), arrow_nock (child of
arrow), saya_mouth (child of saya: where the blade goes in for the draw).

Rest pose: standing, the sword in chudan (point at the throat of a man in
front, about 30 degrees above level), both fists on the grip.
"""
import math

import numpy as np
from mathutils import Matrix, Vector

from artlib import asia as A
from artlib import kit as K
from artlib import materials as M
from artlib import samurai as S
from artlib.geo import Part
from artlib.kit import R, T
from artlib.materials import P, _dither
from artlib.model import Model
from artlib.painter import Surface

SCALE = 1.36
HEAD_C = (0.0, 0.015, 1.79)
EYES = [(-0.036, 0.086, 1.774), (0.036, 0.086, 1.774)]
SWORD_D = Vector((0.04, 0.8, 0.6)).normalized()          # pommel -> point
GRIP_R = Vector((0.07, 0.36, 1.13))
GRIP_L = GRIP_R - SWORD_D * 0.2
ELBOW = {1: Vector((0.29, 0.13, 1.25)), -1: Vector((-0.24, 0.06, 1.2))}
SHOULDER = {1: Vector((0.3, 0.0, 1.52)), -1: Vector((-0.3, 0.0, 1.52))}
BLADE_L, GRIP_LEN = 1.12, 0.42
HIP = 0.12
KNEE = 0.52


def _wrist(sx):
    g = GRIP_R if sx > 0 else GRIP_L
    return g - (g - ELBOW[sx]).normalized() * 0.07


# --------------------------------------------------------------------------
# body parts (unscaled)
# --------------------------------------------------------------------------

def pelvis():
    p = Part("pelvis", origin=(0, 0, 0.95))
    p.lathe([(0.2, 0.9), (0.22, 0.95), (0.225, 1.0), (0.21, 1.06)], "cloth", segments=20, squash=(1.0, 0.8),
            cap_bottom=True, cap_top=False)
    # waist sash with a gilt cord
    p.lathe([(0.226, 0.96), (0.232, 0.99), (0.226, 1.02)], "brocade", segments=24, squash=(1.0, 0.82),
            cap_bottom=False, cap_top=False)
    return p


def kusazuri_part(name, ang, w_scale=1.0):
    a = math.radians(ang)
    r = 0.25
    c = (r * math.cos(a), r * math.sin(a), 0.98)
    p = Part(name, origin=c, parent="pelvis")
    S.kusazuri(p, 4, 0.99, 0.36, r, 6, "lame", part_angles=[a], flare=0.07)
    return p


def torso():
    p = Part("torso", origin=(0, 0, 1.05), parent="pelvis")
    S.oyoroi_do(p)
    # the agemaki: a great crimson bow on the back with its two tails
    c = Vector((0.0, -0.245, 1.3))
    for sx in (-1, 1):
        loop = [c + Vector((0, 0, 0)), c + Vector((sx * 0.08, -0.03, 0.05)), c + Vector((sx * 0.16, -0.02, 0.03)),
                c + Vector((sx * 0.15, -0.015, -0.04)), c + Vector((sx * 0.06, -0.02, -0.02)), c]
        p.tube(loop, 0.018, "silk", sides=6)
        p.tube([c, c + Vector((sx * 0.05, -0.02, -0.12)), c + Vector((sx * 0.08, -0.01, -0.26))],
               lambda t: 0.02 * (1.0 - 0.4 * t), "silk", sides=6)
    S.K.sphere(p, c, 0.03, "silk", segments=8, rings=5)
    return p


def head():
    p = Part("head", origin=(0, 0, 1.62), parent="torso")
    S.void_head(p, HEAD_C, 0.105)
    S.kabuto(p, HEAD_C, horns=False)
    _horns(p, HEAD_C)
    S.menpo(p, (HEAD_C[0], HEAD_C[1] + 0.005, HEAD_C[2]))
    # the plume holder on top and a short white plume
    p.lathe([(0.012, 1.97), (0.016, 2.0), (0.01, 2.03)], "gold", segments=6, cap_top=True)
    return p


def _horns(p, c):
    """Kuwagata: two broad flat horns sweeping up and out from a gilt
    holder on the visor, a sun disc between them."""
    cx, cy, cz = c
    holder = p.box((cx, cy + 0.19, cz + 0.02), (0.1, 0.02, 0.07), "gold", bevel=0.006)
    for sx in (-1, 1):
        pts = [(cx + sx * 0.035, cy + 0.2, cz + 0.02), (cx + sx * 0.1, cy + 0.215, cz + 0.11),
               (cx + sx * 0.16, cy + 0.21, cz + 0.22), (cx + sx * 0.18, cy + 0.19, cz + 0.32),
               (cx + sx * 0.15, cy + 0.16, cz + 0.4)]
        f = p.tube(pts, lambda t: 0.034 * (1.0 - 0.75 * t) + 0.006, "gold", sides=4, smooth=False)
        # a broad flat blade: squash the cross-section front to back
        for v in {v for fc in f for v in fc.verts}:
            v.co.y = cy + 0.2 + (v.co.y - (cy + 0.2)) * 0.35
    disc = p.lathe([(0.0, 0.0), (0.055, 0.0), (0.06, 0.008), (0.055, 0.016), (0.0, 0.016)], "gold", segments=16)
    p.move(disc, T(cx, cy + 0.2, cz + 0.08) @ R('X', -90))


def upperarm(sx):
    name = "upperarm_l" if sx < 0 else "upperarm_r"
    sh, el = SHOULDER[sx], ELBOW[sx]
    p = Part(name, origin=tuple(sh), parent="torso")
    S.K.sphere(p, sh, 0.085, "brocade", segments=10, rings=6)
    S.K.seg(p, sh + Vector((0, 0, -0.03)), el, [(0.082, 0.0), (0.075, 0.5), (0.064, 1.0)], "brocade", segments=10)
    return p


def sode_part(sx):
    name = "sode_l" if sx < 0 else "sode_r"
    sh = SHOULDER[sx]
    top = sh + Vector((sx * 0.07, 0.0, 0.09))
    p = Part(name, origin=tuple(top), parent="upperarm_l" if sx < 0 else "upperarm_r")
    S.sode(p, 0.4, 0.5, 7, "lame", bend_r=0.7)
    # hang it on the outside of the arm, facing out and a little forward
    p.move(list(p.bm.faces), T(*(top + Vector((sx * 0.06, 0.0, 0.0)))) @ R('Z', -sx * 75) @ R('X', 8))
    return p


def forearm(sx):
    name = "forearm_l" if sx < 0 else "forearm_r"
    el = ELBOW[sx]
    wr = _wrist(sx)
    p = Part(name, origin=tuple(el), parent="upperarm_l" if sx < 0 else "upperarm_r")
    S.K.sphere(p, el, 0.062, "mail", segments=10, rings=6)
    S.K.seg(p, el, wr, [(0.06, 0.0), (0.054, 0.6), (0.046, 1.0)], "mail", segments=10)
    d = (wr - el).normalized()
    for k in range(3):
        c = el + (wr - el) * (0.2 + 0.3 * k) + Vector((0, 0, 0.048))
        f = p.box((0, 0, 0), (0.055, 0.1, 0.012), "plate", bevel=0.003)
        p.move(f, T(*c) @ d.to_track_quat('Y', 'Z').to_matrix().to_4x4())
    cop = S.K.sphere(p, (0, 0, 0), 0.064, "plate", segments=8, rings=4, zscale=0.35, smooth=False)
    p.move(cop, T(*(el + Vector((0, -0.025, 0.0)))) @ R('X', 90))
    return p


def hand(sx):
    name = "hand_l" if sx < 0 else "hand_r"
    wr = _wrist(sx)
    g = GRIP_R if sx > 0 else GRIP_L
    p = Part(name, origin=tuple(wr), parent="forearm_l" if sx < 0 else "forearm_r")
    dgrip = (g - wr).normalized()
    ax = SWORD_D
    up = dgrip.cross(ax).normalized()
    if up.length < 0.5:
        up = Vector((0, 0, 1))
    m = T(*g) @ Matrix(((ax.x, dgrip.x, up.x, 0), (ax.y, dgrip.y, up.y, 0), (ax.z, dgrip.z, up.z, 0), (0, 0, 0, 1)))
    fist = p.box((0, -0.012, 0), (0.1, 0.075, 0.09), "cloth", bevel=0.014)
    for k in range(3):
        fist += p.box((0, 0.03, 0.03 - k * 0.03), (0.098, 0.03, 0.026), "cloth", bevel=0.007)
    fist += p.box((0, -0.012, 0.04), (0.08, 0.065, 0.012), "plate", bevel=0.004)
    fist += p.box((-sx * 0.055, 0.016, 0.02), (0.03, 0.05, 0.03), "cloth", bevel=0.008)
    p.move(fist, m)
    # the cuff of the sleeve over the wrist
    S.K.seg(p, wr - dgrip * 0.03, wr + dgrip * 0.03, [(0.05, 0.0), (0.056, 1.0)], "plate", segments=8, caps=False)
    return p


def sword():
    """Nodachi: a long grip wrapped in black silk over white rayskin, a
    gilt round guard, a long gently curved blade with a temper line."""
    p = Part("sword", origin=tuple(GRIP_R), parent="hand_r")
    d = SWORD_D
    pommel = GRIP_R - d * 0.3
    guard = GRIP_R + d * (GRIP_LEN - 0.3)
    S.K.seg(p, pommel, guard, [(0.019, 0.0), (0.021, 0.5), (0.019, 1.0)], "tsuka", segments=8)
    S.K.seg(p, pommel - d * 0.03, pommel, [(0.021, 0.0), (0.021, 1.0)], "gold", segments=8)
    tsuba = p.lathe([(0.0, -0.006), (0.065, -0.006), (0.07, 0.0), (0.065, 0.006), (0.0, 0.006)], "gold", segments=12,
                    squash=(1.0, 0.85))
    p.move(tsuba, T(*guard) @ d.to_track_quat('Z', 'Y').to_matrix().to_4x4())
    S.K.seg(p, guard, guard + d * 0.03, [(0.016, 0.0), (0.014, 1.0)], "gold", segments=6)       # habaki
    # the blade: a flat, slightly curved strip, edge down (-z of its frame)
    n = 10
    side = d.cross(Vector((0, 0, 1))).normalized()
    up = side.cross(d).normalized()
    pts_top, pts_edge = [], []
    for k in range(n + 1):
        t = k / n
        s_ = 0.03 + BLADE_L * t
        curve = 0.06 * (t ** 1.6)
        w = 0.036 * (1.0 - 0.35 * t) if t < 0.92 else 0.036 * 0.65 * (1.0 - (t - 0.92) / 0.08 * 0.9)
        base = guard + d * s_ + up * curve
        pts_top.append(base + up * w * 0.15)
        pts_edge.append(base - up * w)
    th = 0.004
    vs = []
    for k in range(n + 1):
        row = [p.bm.verts.new(pts_top[k] + side * th), p.bm.verts.new(pts_edge[k]),
               p.bm.verts.new(pts_top[k] - side * th)]
        vs.append(row)
    for k in range(n):
        for a, b in ((0, 1), (1, 2), (2, 0)):
            f = p._face([vs[k][a], vs[k + 1][a], vs[k + 1][b], vs[k][b]], "blade")
            f.normal_update()
            mid = (pts_top[k] + pts_top[k + 1]) * 0.5
            if f.normal.dot(f.calc_center_median() - mid + up * 0.01) < 0:
                f.normal_flip()
    tip = p.bm.verts.new(pts_top[n] + d * 0.05 - up * 0.015)
    for a, b in ((0, 1), (1, 2), (2, 0)):
        f = p._face([vs[n][a], vs[n][b], tip], "blade")
    return p, guard + d * (0.03 + BLADE_L) + up * 0.06 + d * 0.04, guard + d * (0.03 + BLADE_L * 0.86) + up * 0.02


def saya():
    """The empty scabbard hung tachi-style at the left hip, edge up, the
    mouth forward."""
    hip = Vector((-0.26, 0.05, 1.0))
    d = Vector((0.0, -0.72, -0.4)).normalized()
    p = Part("saya", origin=tuple(hip), parent="pelvis")
    mouth = hip + Vector((0.0, 0.2, 0.08))
    S.K.seg(p, mouth, mouth + d * (BLADE_L + 0.06), [(0.024, 0.0), (0.022, 0.6), (0.016, 1.0)], "saya", segments=8,
            squash=(0.6, 1.0))
    S.K.seg(p, mouth - d * 0.02, mouth + d * 0.02, [(0.027, 0.0), (0.027, 1.0)], "gold", segments=8)
    S.K.seg(p, mouth + d * (BLADE_L + 0.03), mouth + d * (BLADE_L + 0.09), [(0.022, 0.0), (0.016, 1.0)], "gold",
            segments=8)
    for t in (0.15, 0.35):
        c = mouth + d * t
        S.K.seg(p, c, c + d * 0.03, [(0.027, 0.0), (0.027, 1.0)], "gold", segments=8)
        p.tube([c, c + Vector((-0.02, 0.0, 0.1)), hip + Vector((0.0, 0.0, 0.06))], 0.008, "silk", sides=4)
    return p, mouth


def bow():
    """A yumi slung across the back: black-lacquered laminated bamboo bound
    with red rattan, gripped a third of the way up, the string taut."""
    c = Vector((0.0, -0.3, 1.25))
    p = Part("bow", origin=tuple(c), parent="torso")
    a = Vector((0.36, -0.29, 2.15))        # upper tip over the right shoulder
    b = Vector((-0.42, -0.3, 0.55))        # lower tip at the left calf
    axis = (a - b).normalized()
    out = Vector((0.0, -1.0, 0.0))
    pts = []
    for k in range(13):
        t = k / 12
        q = b + (a - b) * t
        bend = 0.09 * math.sin(math.pi * t) + 0.03 * math.sin(2 * math.pi * t)
        pts.append(q + out * bend)
    p.tube(pts, lambda t: 0.014 if 0.28 < t < 0.42 else 0.011, "bowwood", sides=5)
    p.tube([b, a], 0.002, "string", sides=3, caps=False)
    grip = b + (a - b) * 0.35 + out * 0.09
    for k in range(5):
        t = 0.1 + k * 0.18
        q = pts[int(round(t * 12))]
        S.K.seg(p, q - axis * 0.012, q + axis * 0.012, [(0.016, 0.0), (0.016, 1.0)], "silk", segments=5)
    return p, grip


def quiver():
    """An ebira (open frame quiver) on the right of the back, eight arrows
    with white-and-black fletching."""
    base = Vector((0.2, -0.22, 0.98))
    p = Part("quiver", origin=tuple(base), parent="torso")
    p.box(tuple(base), (0.16, 0.07, 0.1), "plate", bevel=0.01)
    up = Vector((0.12, -0.12, 1.0)).normalized()
    for k in range(2):
        q = base + Vector((-0.06 + 0.12 * k, 0.0, 0.0))
        S.K.seg(p, q, q + up * 0.45, [(0.008, 0.0), (0.008, 1.0)], "plate", segments=4)
    arrows = []
    for i in range(8):
        off = Vector(((i % 4) * 0.035 - 0.05, -0.015 + (i // 4) * 0.03, 0.0))
        q0 = base + off + Vector((0, 0, 0.04))
        q1 = q0 + up * 0.85
        S.K.seg(p, q0, q1, [(0.006, 0.0), (0.006, 1.0)], "shaft", segments=4)
        p.box(tuple(q1 - up * 0.08), (0.003, 0.03, 0.12), "fletch")
        p.box(tuple(q1 - up * 0.08), (0.03, 0.003, 0.12), "fletch")
    return p, base, up


def arrow(base, up):
    q0 = base + Vector((0.065, 0.02, 0.06))
    p = Part("arrow", origin=tuple(q0), parent="quiver")
    q1 = q0 + up * 0.92
    S.K.seg(p, q0 - up * 0.07, q1, [(0.0065, 0.0), (0.0065, 1.0)], "shaft", segments=5)
    head = p.lathe([(0.008, 0.0), (0.012, 0.012), (0.002, 0.06)], "blade", segments=4, squash=(1.0, 0.3), cap_top=True)
    p.move(head, T(*(q0 - up * 0.07)) @ (-up).to_track_quat('Z', 'Y').to_matrix().to_4x4())
    p.box(tuple(q1 - up * 0.08), (0.003, 0.034, 0.13), "fletch")
    p.box(tuple(q1 - up * 0.08), (0.034, 0.003, 0.13), "fletch")
    return p, q1


def thigh(sx):
    name = "thigh_l" if sx < 0 else "thigh_r"
    p = Part(name, origin=(sx * HIP, 0, 0.92), parent="pelvis")
    p.lathe([(0.13, 0.98), (0.16, 0.82), (0.17, 0.66), (0.14, KNEE + 0.04)], "cloth", segments=12,
            center=(sx * HIP * 1.05, 0.0, 0.0), cap_bottom=True, cap_top=False)
    S.haidate(p, sx, "lame")
    return p


def shin(sx):
    name = "shin_l" if sx < 0 else "shin_r"
    p = Part(name, origin=(sx * 0.13, 0.05, KNEE), parent="thigh_l" if sx < 0 else "thigh_r")
    p.lathe([(0.12, KNEE + 0.08), (0.09, KNEE - 0.04), (0.07, KNEE - 0.1)], "cloth", segments=12,
            center=(sx * 0.13, 0.0, 0.0), cap_bottom=False, cap_top=False)
    S.suneate(p, sx, z_top=KNEE - 0.02, knee=True)
    return p


def foot_part(sx):
    name = "foot_l" if sx < 0 else "foot_r"
    p = Part(name, origin=(sx * 0.13, 0.0, 0.1), parent="shin_l" if sx < 0 else "shin_r")
    S.foot(p, sx)
    # bear-fur boots (kutsu) of a great lord over the tabi
    p.lathe([(0.065, 0.02), (0.075, 0.08), (0.068, 0.14)], "fur", segments=10, center=(sx * 0.13, -0.01, 0.0),
            cap_bottom=False, cap_top=True)
    return p


# --------------------------------------------------------------------------
# paint
# --------------------------------------------------------------------------

def blade_paint(ctx, seed=1951):
    """Polished steel, a misty white temper line (hamon) along the edge, a
    darker body above it."""
    s = M.steel(ctx, seed=seed, center=9.2, dent=0.0, rust=0.1, polish=0.1, scratch=0.15)
    gu = np.sum((ctx.p - np.array(GRIP_R) * SCALE) * np.array(SWORD_D), axis=1)
    side = np.array(SWORD_D.cross(Vector((0, 0, 1))).normalized())
    up = np.cross(side, np.array(SWORD_D))
    h = np.sum((ctx.p - np.array(GRIP_R) * SCALE) * up, axis=1)
    wave = 0.012 * np.sin(gu * 38.0) * SCALE
    hamon = (h < -0.012 * SCALE + wave) & (np.abs(ctx.n[:, 0] * side[0] + ctx.n[:, 1] * side[1]) > 0.5)
    s.shade[hamon] += 1.6
    s.shade[~hamon] -= 0.6
    return s


def tsuka(ctx, seed=1953):
    """Black silk braid wound in diamonds over white rayskin."""
    s = A.silk(ctx, "pig_black", 2.4, seed, sheen=0.6)
    u, v = ctx.uvm[:, 0], ctx.uvm[:, 1]
    k = 0.04 * SCALE
    du = np.mod(u + v, k) / k
    dv = np.mod(u - v, k) / k
    diamond = (np.abs(du - 0.5) < 0.22) & (np.abs(dv - 0.5) < 0.22)
    s.use_ramp(P["lacing_white"], mask=diamond, shade=np.full(ctx.N, 5.0) + ctx.rand(seed + 1) * 1.2)
    return s


def build():
    pel = pelvis()
    tor = torso()
    hd = head()
    arms = []
    for sx in (-1, 1):
        arms += [upperarm(sx), sode_part(sx), forearm(sx), hand(sx)]
    sw, tip, glint = sword()
    sy, mouth = saya()
    bw, grip = bow()
    qv, qbase, qup = quiver()
    ar, nock = arrow(qbase, qup)
    legs = []
    for sx in (-1, 1):
        trio = [thigh(sx), shin(sx), foot_part(sx)]
        # sturdier legs for the giant: widen them about their own axis
        for prt in trio:
            for v in prt.bm.verts:
                v.co.x = sx * 0.13 + (v.co.x - sx * 0.13) * 1.22
                v.co.y = v.co.y * 1.18
        legs += trio
    ks = [kusazuri_part("kusazuri_f", 90), kusazuri_part("kusazuri_b", 270), kusazuri_part("kusazuri_l", 180),
          kusazuri_part("kusazuri_r", 0)]
    parts = [pel, tor, hd] + arms + [sw, sy, bw, qv, ar] + legs + ks
    # scale everything (geometry and pivots) to the General's size
    sm = Matrix.Scale(SCALE, 4)
    for prt in parts:
        prt.move(list(prt.bm.faces), sm)
        prt.origin = Vector(prt.origin) * SCALE
    sc = lambda v: tuple(Vector(v) * SCALE)
    markers = [("face", sc((0.0, 0.08, 1.775)), "head"), ("back", sc((0.0, -0.28, 1.3)), "torso"),
               ("blade_tip", sc(tip), "sword"), ("glint", sc(glint), "sword"), ("bow_grip", sc(grip), "bow"),
               ("arrow_nock", sc(nock), "arrow"), ("saya_mouth", sc(mouth), "saya")]
    fns = {"lame": S.laced("lacing_red", 4.8), "plate": S.plate, "gold": S.gold, "leather": S.leather,
           "brocade": S.brocade("lacing_blue", gold=True), "mail": S.mail, "cloth": S.cloth, "straw": S.straw,
           "mask": S.mask, "hair": S.hair, "teeth": S.teeth, "void": S.void([sc(e) for e in EYES], sc(HEAD_C),
                                                                            0.105 * SCALE),
           "silk": lambda c: A.silk(c, "lacing_red", 4.6, 1961), "blade": blade_paint, "tsuka": tsuka,
           "saya": lambda c: A.lacquer(c, 1963, ramp="lacquer_black", center=3.2, wear=0.3),
           "bowwood": lambda c: A.lacquer(c, 1965, ramp="lacquer_black", center=3.4, wear=0.2),
           "string": lambda c: A.silk(c, "lacing_white", 4.0, 1967),
           "shaft": lambda c: A.wood(c, 1969, ramp="tatami", center=5.0),
           "fletch": lambda c: S.hair(c, 1971),
           "fur": lambda c: M.fur(c, seed=1973, flow=(0.0, 0.0, -1.0), center=2.4, moth=0.0)}
    face = sc((0.0, 0.1, 1.76))
    return Model("samurai_general", parts, fns, ppm=224, ground=0.0, ao_dist=0.18, ao_rays=12, ao_stride=2, front=1,
                 normal_strength=2.0, markers=markers, preview_yaws=(-30.0, 30.0, 110.0, 200.0),
                 preview_elevation=6.0, preview_closeup=(face, 0.42),
                 preview_extra=[("back", sc((0.0, -0.25, 1.3)), 0.7, 180.0, 5.0),
                                ("sword", sc((0.1, 0.9, 1.45)), 1.0, 60.0, 10.0)])
