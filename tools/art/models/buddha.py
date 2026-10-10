"""The great seated Buddha of the China hall: Shakyamuni at the moment of
enlightenment, in the earth-touching gesture (bhumisparsha mudra): the
right hand over the right knee, fingers down to the lotus, the left hand
in the lap palm up; legs crossed in the lotus posture under the robe, the
right sole turned up. Gilt lacquer over wood in the Ming manner: burnished
gold on the flesh, the robe gold with a red-and-green painted hem border,
the snail-shell curls and the cranial mound blue (azurite), a red jewel on
the mound, the urna between the brows; heavy-lidded downcast eyes with a
painted line, a calm small smile. The gold is rubbed through to the red
lacquer on the knees, the fingers and the edges.

Behind: a flaming mandorla (body halo and head halo, a lotus ring round
the head, bands of scrolling vines, a border of gilt flames tipped red).
Under: a double lotus throne (petals up and down round a drum) on an
octagonal sumeru plinth with red lacquer panels and gilt mouldings.

About 5.5 m to the jewel (throne top 1.4 m), the mandorla to 7.6 m: for the
9 m China hall. Front = +Y in Blender = -Z in Godot; origin = centre of the
plinth on the floor.

Parts (Godot names):
    buddha_seated    the plinth and the lotus throne (static)
    buddha_mandorla  the flaming halo behind (stands on the throne)
    buddha_figure    the body (crossed legs, robe, arms, hands)
    buddha_head      the head, the curls, the mound and jewel, the ears;
                     pivot at the neck (0, 3.85, -0.05) (Godot), child of
                     buddha_figure (a slow nod is possible, never needed)
Markers: Halo (the centre of the head halo, a soft light can sit there),
Offering (Godot (0, 0.4, -1.95)): the front step of the throne, where an
incense burner (bronze_ding) can stand.
"""
import math

import numpy as np
import bmesh
import bpy
from mathutils import Matrix, Vector

from artlib import asia as A
from artlib import asia_paint as AP
from artlib import egypt as E
from artlib import kit as K
from artlib import sculpt
from artlib.archkit import cull_floor, front_prism, plan_sweep
from artlib.geo import Part
from artlib.kit import R, T
from artlib.materials import P, _dither, smoothstep
from artlib.model import Model
from artlib.painter import Surface
from artlib.sculpt import blob, limb

I = AP.INK
SEAT = 1.4                         # top of the lotus cushion
FIG_S = 1.08                       # the figure is sculpted, then scaled about the seat centre
HEAD_C = Vector((0.0, 0.1 * FIG_S, 1.4 + (4.47 - 1.4) * FIG_S))   # centre of the unit head
HEAD_S = 1.08                      # metres per unit of the head (chin to crown)
NECK = (0.0, 0.05 * FIG_S, 1.4 + (3.85 - 1.4) * FIG_S)
ORDER = ["buddha_seated", "buddha_mandorla", "buddha_figure", "buddha_head"]


# --------------------------------------------------------------------------
# the head (a field-sculpted sphere, as artlib/face.py, Buddha features)
# --------------------------------------------------------------------------

def _g(x, z, cx, cz, sx, sz):
    return math.exp(-(((x - cx) / sx) ** 2 + ((z - cz) / sz) ** 2))


def _slit(dx):
    """Height of the eye slit (the lower edge of the heavy upper lid)."""
    return 0.012 - 0.016 * (1.0 - dx * dx)


def _bshape(x, y, z):
    # a full, round jaw (little taper) and a rounder skull than the kings'
    taper = 0.9 + 0.1 * (1.0 / (1.0 + math.exp(-(z + 0.22) * 9.0)))
    x *= taper
    if y > 0:
        y *= 1.0 - 0.08 * min(1.0, (x / 0.34) ** 2)
    out = Vector((x, y, z))
    n = out.normalized()
    d = 0.0
    if y > 0.04:
        f = min(1.0, (y - 0.04) / 0.14)
        ax = abs(x)
        # long arched brows flowing into the nose ridge
        zb = 0.13 - 0.75 * (ax - 0.13) ** 2
        if 0.02 < ax < 0.32:
            d += 0.022 * math.exp(-((z - zb) / 0.018) ** 2) * f
        for ex in (-0.145, 0.145):
            dx = (x - ex) / 0.095
            d -= 0.03 * _g(x, z, ex, 0.07, 0.085, 0.05) * f                   # the socket under the brow
            d += 0.04 * _g(x, z, ex, 0.035, 0.08, 0.04) * f                    # the heavy upper lid
            if abs(dx) < 1.0:
                zs = _slit(dx)
                d -= 0.012 * math.exp(-((z - zs) / 0.0065) ** 2) * (1.0 - dx * dx) ** 0.5 * f
            d += 0.012 * _g(x, z, ex, -0.025, 0.07, 0.02) * f                 # lower lid
            d += 0.034 * _g(x, z, math.copysign(0.21, ex), -0.1, 0.08, 0.08) * f   # full cheeks
            d += 0.026 * _g(x, z, math.copysign(0.04, ex), -0.13, 0.026, 0.02) * f  # nose wings
        t = min(1.0, max(0.0, (0.1 - z) / 0.23))
        bridge = 1.0 / (1.0 + math.exp((z - 0.12) * 60.0)) * 1.0 / (1.0 + math.exp(-(z + 0.14) * 60.0))
        d += (0.02 + 0.07 * t) * math.exp(-(x / (0.03 + 0.024 * t)) ** 2) * bridge * f
        d -= 0.016 * _g(x, z, 0.0, -0.18, 0.018, 0.016) * f                   # philtrum
        d += 0.042 * _g(x, z, 0.0, -0.205, 0.075, 0.02) * f                   # upper lip
        d += 0.046 * _g(x, z, 0.0, -0.255, 0.06, 0.022) * f                   # lower lip
        smile = -0.014 * (x / 0.07) ** 2
        d -= 0.034 * _g(x, z, 0.0, -0.23 - smile, 0.08, 0.006) * f            # the mouth line, corners up
        d += 0.048 * _g(x, z, 0.0, -0.37, 0.08, 0.05) * f                     # chin
        d -= 0.016 * _g(x, z, 0.0, -0.305, 0.05, 0.014) * f
        d += 0.012 * _g(x, z, 0.0, 0.15, 0.016, 0.016) * f                   # urna
    return out + n * d


def head_unit_mesh(rings=48, segs=64):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=segs, v_segments=rings, radius=1.0)
    sx, sy, sz = 0.4, 0.46, 0.5
    for v in bm.verts:
        x, y, z = v.co.x * sx, v.co.y * sy - 0.02, v.co.z * sz + 0.02
        if z < -0.25:
            y += (-0.25 - z) * 0.22 * max(0.0, v.co.y)
        v.co = _bshape(x, y, z)
    me = bpy.data.meshes.new("buddha_head")
    bm.to_mesh(me)
    bm.free()
    return me


def hairline(x, y):
    """Height (unit head) under which there is skin: low and straight on
    the forehead, down past the temples, low at the nape."""
    a = math.atan2(x, y)                      # 0 = front
    k = abs(a) / math.pi                     # 0 front .. 1 back
    return 0.25 - 0.2 * smoothstep(0.15, 0.45, np.array([k]))[0] - 0.12 * smoothstep(0.5, 1.0, np.array([k]))[0]


def head():
    p = Part("buddha_head", origin=NECK, parent="buddha_figure")
    me = head_unit_mesh()
    me = sculpt.decimate(me, 3600)
    sculpt.into_part(p, me, "skin")
    hair = p.slot("hair")
    bm = p.bm
    bm.normal_update()
    lift = {}
    for f in bm.faces:
        c = f.calc_center_median()
        if c.z > hairline(c.x, c.y) and not (c.y > 0.3 and c.z < 0.2):
            f.material_index = hair
            for v in f.verts:
                lift[v] = True
    for v in lift:
        v.co += v.normal * 0.018
    # cranial mound (ushnisha) and the jewel on it
    p.lathe([(0.22, 0.4), (0.25, 0.46), (0.25, 0.53), (0.21, 0.6), (0.13, 0.65), (0.05, 0.662)], "hair",
            segments=20, center=(0.0, -0.03, 0.0), cap_bottom=False, cap_top=True)
    p.lathe([(0.04, 0.65), (0.07, 0.68), (0.065, 0.72), (0.035, 0.77), (0.014, 0.8)], "jewel",
            segments=10, center=(0.0, -0.03, 0.0), cap_bottom=True, cap_top=True)
    # ears: long lobes hanging nearly to the jaw
    for sx in (-1, 1):
        eb = [blob((sx * 0.4, -0.02, 0.06), (0.035, 0.09, 0.12)),
              blob((sx * 0.41, -0.01, -0.12), (0.035, 0.07, 0.1)),
              blob((sx * 0.41, 0.0, -0.27), (0.04, 0.06, 0.09)),
              blob((sx * 0.43, -0.01, -0.2), (0.012, 0.025, 0.06), neg=True, stiff=1.6)]
        em = sculpt.metaball_mesh(eb, resolution=0.012)
        em = sculpt.decimate(em, 260)
        sculpt.into_part(p, em, "skin")
    # unit head -> model: HEAD_S metres tall, centred on HEAD_C
    p.move(list(p.bm.faces), Matrix.Translation(HEAD_C) @ Matrix.Scale(HEAD_S, 4))
    return p


# --------------------------------------------------------------------------
# the body
# --------------------------------------------------------------------------

def _hand_lap(b):
    """The left hand in the lap, palm up, fingers toward the right, a
    little cupped."""
    c = Vector((-0.24, 0.55, 2.22))
    b.append(blob(tuple(c), (0.2, 0.16, 0.07)))
    for k in range(4):
        y = c.y + 0.1 - k * 0.062
        b += limb([(c.x + 0.14, y, c.z + 0.015), (c.x + 0.32, y + 0.01, c.z + 0.03), (c.x + 0.4, y, c.z + 0.06)],
                  [0.045, 0.04, 0.035], spacing=0.55)
    b += limb([(c.x + 0.06, c.y + 0.15, c.z + 0.03), (c.x + 0.2, c.y + 0.2, c.z + 0.06)], [0.05, 0.04], spacing=0.55)


def _hand_earth(b):
    """The right hand over the knee, palm against the shin, fingers reaching
    down to the lotus in front of the right knee."""
    w = Vector((1.06, 0.86, 2.0))                    # wrist on the knee
    b.append(blob(tuple(w + Vector((0.0, 0.1, -0.14))), (0.11, 0.19, 0.2), rot=(-30, 0, 0)))
    for k in range(4):
        x = w.x - 0.11 + k * 0.073
        ln = (0.0, 0.03, 0.02, -0.02)[k]
        b += limb([(x, w.y + 0.19, w.z - 0.24), (x, w.y + 0.27, w.z - 0.44 - ln),
                   (x + 0.004, w.y + 0.29, w.z - 0.6 - ln)], [0.046, 0.04, 0.034], spacing=0.55)
    b += limb([(w.x - 0.16, w.y + 0.08, w.z - 0.1), (w.x - 0.22, w.y + 0.2, w.z - 0.24)], [0.05, 0.04], spacing=0.55)


def figure():
    p = Part("buddha_figure", origin=(0.0, 0.0, SEAT))
    b = []
    # crossed legs under the robe: one broad lap mass, knees, the right sole up
    b.append(blob((0.0, 0.3, SEAT + 0.32), (1.35, 0.68, 0.32)))
    for sx in (-1, 1):
        b.append(blob((sx * 1.25, 0.48, SEAT + 0.3), (0.4, 0.5, 0.3)))           # knees
        b += limb([(sx * 0.35, 0.0, SEAT + 0.42), (sx * 1.18, 0.42, SEAT + 0.32)], [0.44, 0.36], spacing=0.7)
    b.append(blob((-0.5, 0.66, SEAT + 0.6), (0.44, 0.22, 0.13), rot=(0, 8, -10)))     # right foot on the left thigh
    b.append(blob((-0.68, 0.7, SEAT + 0.64), (0.2, 0.15, 0.11)))                       # heel
    # torso: broad shoulders, a full chest, a round belly
    b += [blob((0.0, 0.1, 2.4), (0.84, 0.6, 0.48)),           # belly
          blob((0.0, 0.03, 3.0), (0.94, 0.56, 0.6)),          # chest
          blob((0.0, -0.18, 3.05), (0.86, 0.42, 0.66)),       # back
          blob((0.0, 0.0, 3.55), (0.74, 0.4, 0.24)),          # shoulder girdle
          blob((0.0, 0.03, 3.8), (0.25, 0.25, 0.22))]         # neck
    for sx in (-1, 1):
        b.append(blob((sx * 0.34, 0.36, 3.14), (0.36, 0.13, 0.2)))                    # pectorals
        b.append(blob((sx * 0.86, -0.04, 3.44), (0.32, 0.34, 0.3)))                   # shoulders
    # arms close to the body: the left down to the lap, the right down to the knee
    b += limb([(-0.9, -0.02, 3.36), (-1.06, 0.14, 2.74), (-0.7, 0.46, 2.32), (-0.42, 0.55, 2.24)],
              [0.25, 0.21, 0.17, 0.13], spacing=0.7)
    b += limb([(0.9, -0.02, 3.36), (1.08, 0.16, 2.72), (1.08, 0.62, 2.22), (1.06, 0.86, 2.02)],
              [0.25, 0.21, 0.17, 0.13], spacing=0.7)
    me = sculpt.metaball_mesh(b, resolution=0.026)
    sculpt.cut(me, [((0.0, 0.0, SEAT + 0.01), (0.0, 0.0, -1.0))])
    me = sculpt.decimate(me, 7200)
    sculpt.into_part(p, me, "skin")
    # the hands at a finer resolution (the fingers stay apart)
    for fn in (_hand_lap, _hand_earth):
        hb = []
        fn(hb)
        hm = sculpt.metaball_mesh(hb, resolution=0.011)
        hm = sculpt.decimate(hm, 900)
        sculpt.into_part(p, hm, "skin")
    # robe / skin by region: the robe covers the left shoulder and arm, the
    # torso below the chest line and the legs; flesh is the right shoulder
    # and arm, the chest above the line, the hands and the sole
    bm = p.bm
    robe = p.slot("robe")
    for f in bm.faces:
        c = f.calc_center_median()
        if not _is_flesh(c):
            f.material_index = robe
    centre = Vector((0.0, 0.0, SEAT))
    p.move(list(bm.faces), Matrix.Translation(centre) @ Matrix.Scale(FIG_S, 4) @ Matrix.Translation(-centre))
    return p


def _chest_line(x):
    """z of the robe's diagonal edge across the chest (from the right ribs
    up to the left shoulder)."""
    return 2.55 + (0.62 - x) * 0.85


def _is_flesh(c):
    x, y, z = c.x, c.y, c.z
    if z < SEAT + 0.75 and y > 0.45 and -0.85 < x < -0.1:       # the upturned right sole
        return True
    if z < 2.38 and y > 0.4 and -0.5 < x < 0.22:               # the left hand in the lap
        return True
    if x > 0.8 and z < 2.12 and y > 0.7:                         # the right hand
        return True
    if x > 0.55 and z > 2.2 and z < 3.62:                        # the right arm, bare
        return True
    if z > _chest_line(x) and x > -0.45 and z > 2.6:             # chest above the robe line, right shoulder
        return True
    if z > 3.68:                                                 # the neck
        return True
    return False


# --------------------------------------------------------------------------
# throne and mandorla
# --------------------------------------------------------------------------

def _octagon(r):
    pts = []
    for k in range(8):
        a = math.radians(22.5 + 45 * k)
        pts.append((r * math.cos(a), r * math.sin(a)))
    return list(reversed(pts))          # clockwise from above


def _petal(p, ang, r0, z0, length, width, tilt, mat, down=False, n_u=4, n_v=4):
    """One lotus petal: a pointed, bulging plate rising (or hanging) from
    radius r0 at height z0, turned to angle ``ang`` round the throne."""
    verts = []
    for j in range(n_v + 1):
        v = j / n_v
        w = width * math.sin(math.pi * (0.12 + 0.88 * v)) ** 0.7 * (1.0 - 0.15 * v)
        row = []
        for i in range(n_u + 1):
            u = -1.0 + 2.0 * i / n_u
            bulge = 0.06 * width * (1.0 - u * u) * math.sin(math.pi * v)
            s = length * v
            # local frame: out = radial, up = z (or down)
            out = s * math.sin(math.radians(tilt)) + bulge
            up = s * math.cos(math.radians(tilt))
            if down:
                up = -up
            row.append((u * w * 0.5, out, up))
        verts.append(row)
    m = Matrix.Translation((0.0, 0.0, z0)) @ R('Z', math.degrees(ang) - 90.0) @ Matrix.Translation((0.0, r0, 0.0))
    vs = [[p.bm.verts.new(m @ Vector(q)) for q in row] for row in verts]
    faces = []
    for j in range(n_v):
        for i in range(n_u):
            f = p._face([vs[j][i], vs[j][i + 1], vs[j + 1][i + 1], vs[j + 1][i]], mat, smooth=True)
            f.normal_update()
            centre = f.calc_center_median()
            radial = Vector((centre.x, centre.y, 0.0))
            if f.normal.dot(radial) < 0:
                f.normal_flip()
            faces.append(f)
    return faces


def throne():
    p = Part("buddha_seated")
    # octagonal sumeru plinth
    plan_sweep(p, [(0.0, 0.12), (0.14, 0.12), (0.18, 0.04), (0.22, 0.0), (0.6, 0.0), (0.64, 0.05), (0.7, 0.1),
                   (0.76, 0.1), (0.78, 0.0)], _octagon(1.85), "plinth")
    p.ngon_prism([(x, y) for x, y in reversed(_octagon(1.85))], 0.775, 0.8, "plinth")
    # the front step for offerings
    p.box((0.0, 1.95, 0.2), (1.6, 0.6, 0.4), "plinth", bevel=0.02)
    # the lotus: a drum, petals hanging down below, petals rising above, a cushion
    p.lathe([(1.45, 0.8), (1.4, 0.95), (1.32, 1.1), (1.38, 1.2), (1.5, 1.3), (1.55, 1.38), (1.4, SEAT)],
            "lotus", segments=32, cap_bottom=False, cap_top=True)
    for k in range(18):
        a = math.tau * (k + 0.5) / 18
        _petal(p, a, 1.36, 1.12, 0.36, 0.5, 105.0, "petal", down=True)
    for row, (r0, z0, L, w, tilt, n) in enumerate(((1.3, 1.08, 0.5, 0.52, 34.0, 18), (1.15, 1.2, 0.42, 0.44, 22.0, 18))):
        for k in range(n):
            a = math.tau * (k + 0.5 * row) / n
            _petal(p, a, r0, z0, L, w, tilt, "petal")
    cull_floor([p])
    return p


def mandorla_outline(n=120):
    """A pointed oval with flame tongues round its edge (x, z)."""
    pts = []
    cx, cz = 0.0, 4.6
    for k in range(n):
        t = math.tau * k / n
        x = math.sin(t)
        z = -math.cos(t)
        rx, rz = 1.55, 2.9
        # pointed top (the ogee of a flame mandorla)
        if z > 0:
            x *= 1.0 - 0.32 * z ** 2
        flame = 1.0 + 0.055 * abs(math.sin(t * 13.0)) ** 0.5 * (0.5 + 0.5 * max(0.0, z))
        px, pz = cx + x * rx * flame, cz + z * rz * flame
        if pz < SEAT + 0.6:
            pz = SEAT + 0.6
        pts.append((px, pz))
    return pts


def mandorla():
    p = Part("buddha_mandorla")
    out = mandorla_outline()
    f = front_prism(p, out, 0.12, "mandorla", y_back=-0.72)
    # the head halo, a raised disc
    halo = p.lathe([(0.0, 0.0), (0.82, 0.0), (0.86, 0.04), (0.82, 0.08), (0.0, 0.08)], "halo", segments=32)
    p.move(halo, Matrix.Translation((HEAD_C.x, -0.72, HEAD_C.z + 0.1)) @ R('X', -90))
    return p


# --------------------------------------------------------------------------
# paint
# --------------------------------------------------------------------------

def _gold(ctx, seed, worn=0.6, center=0.0, under="lacquer_red"):
    s = A.gilt(ctx, seed, worn=worn, under=under)
    s.shade += center + np.clip(ctx.curv, 0, 1) * 1.0 - np.clip(-ctx.curv, 0, 1) * 1.6
    return s


def skin(ctx, seed=1501):
    """Burnished flesh gold, a little paler and smoother than the robe; the
    face painted: black eye slits and brows, red lips, the urna."""
    s = _gold(ctx, seed, worn=0.35, center=0.4)
    s.rough = s.rough * 0.8
    head = ctx.part == ORDER.index("buddha_head")
    if head.any():
        # the face keeps its gold: no rubbing through, lighter grime
        hs = A.gilt(ctx, seed + 5, worn=0.0, grime=0.75)
        hs.shade += 0.4 + np.clip(ctx.curv, 0, 1) * 1.0 - np.clip(-ctx.curv, 0, 1) * 1.6
        s.merge(A._select(hs, head), head)
        q = (ctx.p - np.array(HEAD_C)) / HEAD_S
        x, y, z = q[:, 0], q[:, 1], q[:, 2]
        front = head & (y > 0.2)
        codes = np.zeros(ctx.N, np.int16)
        for ex in (-0.145, 0.145):
            dx = (x - ex) / 0.095
            ins = np.abs(dx) < 1.0
            zs = 0.012 - 0.016 * (1.0 - dx * dx)
            codes[front & ins & (np.abs(z - zs) < 0.007)] = I["black"]
        ax = np.abs(x)
        zb = 0.13 - 0.75 * (ax - 0.13) ** 2
        codes[front & (ax > 0.03) & (ax < 0.3) & (np.abs(z - zb - 0.004) < 0.006)] = I["black"]
        lips = front & (ax < 0.065 - np.abs(z + 0.232) * 0.6) & (np.abs(z + 0.232) < 0.03) & (y > 0.38)
        codes[lips] = I["dk_red"]
        codes[front & (np.hypot(x, z - 0.15) < 0.016)] = I["white"]
        s = E.paint_over(ctx, s, codes, np.zeros(ctx.N, np.int16), seed + 1, flake=0.0, wear=0.0, inks=A.INKS)
    return s


def robe(ctx, seed=1511):
    """Robe gold with long incised fold lines, a painted border (red ground,
    green leaf scroll, gold beads) along the hems and the chest line."""
    s = _gold(ctx, seed, worn=0.55, center=-0.2)
    # back to the sculpting frame (the figure was scaled about the seat)
    x, y, z = ctx.p[:, 0] / FIG_S, ctx.p[:, 1] / FIG_S, SEAT + (ctx.p[:, 2] - SEAT) / FIG_S
    folds = np.sin((x * 1.3 + z * 2.2 + ctx.fbm(1.0, 2, seed) * 1.2) * 9.0) > 0.93
    s.shade[folds] -= 1.4
    s.height = s.height - folds * 0.004
    # the border: near the chest line and along the lap's front edge
    border = (np.abs(z - _chest_line_np(x)) < 0.07) & (z > 2.4) & (y > -0.1)
    border |= (z < SEAT + 0.42) & (y > 0.7)
    lx = np.floor((x + y) / ctx.texel)
    bead = border & (np.mod(lx, 6) == 0)
    leaf = border & ~bead & (np.mod(lx, 6) < 3)
    codes = np.zeros(ctx.N, np.int16)
    codes[border] = I["red"]
    codes[leaf] = I["green"]
    codes[bead] = I["gold"]
    return E.paint_over(ctx, s, codes, np.zeros(ctx.N, np.int16), seed + 1, flake=0.35, wear=0.6, inks=A.INKS)


def _chest_line_np(x):
    return 2.55 + (0.62 - x) * 0.85


def hair(ctx, seed=1521):
    """Snail-shell curls in azurite blue: a cell per curl, each a little
    dome with a spiral groove, the paint worn to the gold under it."""
    s = Surface(ctx.N)
    f1, f2, cid = ctx.worley(13.0, seed)
    dome = np.clip(1.0 - f1 / 0.55, 0.0, 1.0)
    q = ctx.p - np.array(HEAD_C)
    ang = np.arctan2(q[:, 2], q[:, 0]) + cid * 6.28
    spiral = np.sin(ang * 1.0 + f1 * 16.0) > 0.55
    shade = 3.2 + dome * 2.6 - spiral * 1.2 + _dither(ctx, 0.5, seed + 1) - (1.0 - ctx.ao) * 2.5
    shade -= (f1 > 0.45) * 1.6
    s.use_ramp(P["pig_blue"], shade=shade)
    worn = (dome > 0.7) & (ctx.fbm(9.0, 2, seed + 2) > 0.3)
    s.use_ramp(P["gold"], mask=worn, shade=np.full(ctx.N, 5.0) + _dither(ctx, 0.6, seed + 3))
    s.metal = np.where(worn, 0.9, 0.0)
    s.rough = np.where(worn, 0.3, 0.75)
    s.height = dome * 0.006 - spiral * 0.0015
    return s


def jewel(ctx, seed=1531):
    s = Surface(ctx.N)
    s.use_ramp(P["pig_red"], shade=4.6 + np.clip(ctx.curv, 0, 1) * 2.0 + ctx.edge(1.0) * 1.5 - (1.0 - ctx.ao) * 2.0)
    s.rough = np.full(ctx.N, 0.2)
    return s


_MAND = {}


def _mandorla_canvas(ppm):
    """The mandorla's face as seen from the front: a flame border, a band of
    vine scroll, the body halo's ground with radiating rays; the head halo
    is its own disc (see halo_paint). 3.3 x 6.4 m."""
    if ppm in _MAND:
        return _MAND[ppm]
    W, H = int(3.4 * ppm), int(6.4 * ppm)
    c = AP.blank(W, H, I["gold"])
    xs, ys = np.mgrid[0:H, 0:W][1] + 0.5, np.mgrid[0:H, 0:W][0] + 0.5
    X = (xs - W / 2) / ppm
    Z = (H - ys) / ppm + 1.6                  # world z of each pixel
    # normalised distance in the oval (1 = the flame border's inner edge)
    zz = (Z - 4.6) / 2.9
    shrink = np.where(zz > 0, 1.0 - 0.32 * np.clip(zz, 0, 1) ** 2, 1.0)
    rr = np.sqrt((X / (1.55 * np.maximum(shrink, 0.2))) ** 2 + zz ** 2)
    flames = rr > 0.86
    ang = np.arctan2(X, -zz)
    # flame tongues: teardrops licking outward and upward, gold-edged
    step = math.tau / 30.0
    k = np.round(ang / step)
    da = ang - k * step
    t = np.clip((rr - 0.86) / 0.16, 0.0, 1.0)
    lean = 0.35 * np.sign(X) * t * step
    half = step * 0.5 * (1.0 - t) ** 0.8
    off = np.abs(da - lean)
    tongue = flames & (off < half)
    c[flames] = I["dk_red"]
    c[tongue] = I["red"]
    c[tongue & (off < half * 0.45) & (t < 0.7)] = I["orange"]
    c[tongue & (off > half - 1.5 / (ppm * np.maximum(rr, 0.3) * 2.0))] = I["gold"]
    c[(rr > 0.84) & (rr <= 0.86)] = I["gold"]
    vine = (rr > 0.7) & (rr <= 0.84)
    c[vine] = I["dk_green"]
    wave = np.abs(np.sin(ang * 16.0) * 0.045 - (rr - 0.77)) < 0.012
    c[vine & wave] = I["gold"]
    leaf = vine & (np.abs(np.sin(ang * 32.0 + 1.0)) > 0.92) & (np.abs(rr - 0.77) < 0.04)
    c[leaf] = I["green"]
    c[(rr > 0.68) & (rr <= 0.7)] = I["gold"]
    rays = (rr <= 0.68) & (np.mod(np.floor(ang / 0.06), 2) == 0)
    c[rays] = I["ochre"]
    _MAND[ppm] = c
    return c


def mandorla_paint(ctx, seed=1541):
    s = _gold(ctx, seed, worn=0.4)
    front = ctx.n[:, 1] > 0.7
    x, z = ctx.p[:, 0], ctx.p[:, 2]
    ppm = int(round(1.0 / ctx.texel))
    codes, rims = E.sample(_mandorla_canvas(ppm), x + 1.7, z - 1.6, ctx.texel)
    codes = np.where(front, codes, 0).astype(np.int16)
    s = E.paint_over(ctx, s, codes, rims, seed + 1, flake=0.25, relief=0.0, wear=0.5, inks=A.INKS)
    raised = (codes == I["gold"]) | (codes == I["green"])
    s.height = s.height + raised * 0.004
    return s


def halo_paint(ctx, seed=1551):
    """The head halo: a ring of lotus petals round a plain gold centre."""
    s = _gold(ctx, seed, worn=0.3)
    q = ctx.p - np.array((HEAD_C.x, 0.0, HEAD_C.z + 0.1))
    r = np.hypot(q[:, 0], q[:, 2])
    a = np.arctan2(q[:, 2], q[:, 0])
    front = ctx.n[:, 1] > 0.7
    ring = front & (r > 0.52) & (r < 0.8)
    petal = ring & ((r - 0.52) / 0.28 < 0.95 - 0.8 * np.abs(np.mod(a * 24 / math.tau, 1.0) - 0.5))
    codes = np.zeros(ctx.N, np.int16)
    codes[ring] = I["red"]
    codes[petal] = I["gold"]
    codes[front & (np.abs(r - 0.5) < 0.012)] = I["green"]
    s = E.paint_over(ctx, s, codes, np.zeros(ctx.N, np.int16), seed + 1, flake=0.2, wear=0.4, inks=A.INKS)
    s.height = s.height + petal * 0.004
    return s


def petal_paint(ctx, seed=1561):
    """Lotus petals: gilt with a red tip and a green heart line."""
    s = _gold(ctx, seed, worn=0.5)
    return s


def plinth_paint(ctx, seed=1571):
    """The sumeru plinth: red lacquer panels between gilt mouldings."""
    z = ctx.p[:, 2]
    panel = (z > 0.2) & (z < 0.62)
    s = A.lacquer(ctx, seed, wear=0.5)
    g = _gold(ctx, seed + 1, worn=0.7)
    s.merge(A._select(g, ~panel), ~panel)
    # a gilt cloud in the middle of each face of the waist
    return s


def build():
    parts = [throne(), mandorla(), figure(), head()]
    fns = {"plinth": plinth_paint, "lotus": lambda c: _gold(c, 1581, worn=0.6), "petal": petal_paint,
           "mandorla": mandorla_paint, "halo": halo_paint, "skin": skin, "robe": robe, "hair": hair,
           "jewel": jewel}
    face = (HEAD_C.x, HEAD_C.y + 0.4, HEAD_C.z)
    return Model("buddha_seated", parts, fns, ppm=112, organic=("buddha_figure", "buddha_head"), ground=0.0,
                 ao_dist=0.5, ao_rays=10, ao_stride=2, front=1, normal_strength=1.6,
                 markers=[("Halo", (HEAD_C.x, -0.7, HEAD_C.z + 0.1), "buddha_mandorla"),
                          ("Offering", (0.0, 1.95, 0.4), "buddha_seated")],
                 preview_yaws=(-25.0, 25.0, 70.0, 180.0), preview_elevation=8.0,
                 preview_closeup=(face, 0.75),
                 preview_extra=[("hands", (0.4, 0.8, 2.0), 1.4, 20.0, 15.0)])
