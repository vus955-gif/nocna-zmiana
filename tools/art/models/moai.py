"""Floor I, the Moai room: a moai of dark vesicular basalt, 2.45 m from
its base to the flat crown, on a bronze turntable on a museum plinth. A
generic stylisation of the Rapa Nui form (not any particular statue, and
nothing of the carvings some statues bear on their backs): a long head on
a short torso, a heavy brow over deep empty sockets, a long nose with
flared nostrils, the pursed thin lips and jutting chin, long ears with
drawn-out lobes, the arms carved in low relief down the sides and the long
fingers meeting over the belly.

Parts (Godot axes; kit convention: origin = centre of the plinth's base,
front -Z):
  moai_plinth  the plinth 2.4 x 1.2 x 2.4 m: dark stone ashlar, a moulded
               cap, a brass label "MOAI / RAPA NUI" on the front. Root.
  moai         the statue with its bronze turntable (0.08 m) and, at the
               back of the turntable, an iron bracket with a ring: pivot =
               the turntable's centre on the plinth top (0, 1.2, 0), child
               of moai_plinth. Turning moai.rotation.y turns the head on
               its plinth (the secret: the harpoon hooks the ring, pulls,
               the moai swings round).
Markers: hook_ring (child of moai) = the centre of the iron ring at the
back, (0, 1.33, 0.9); face (child of moai) = between the eye sockets,
for the light from below to aim at.
128 px/m.
"""
import math

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector

from artlib import clay
from artlib import americas as AM
from artlib import materials as M
from artlib import pixelfont
from artlib import sculpt
from artlib.archkit import cull_floor, kit
from artlib.geo import Part
from artlib.materials import P

TOP = 1.2           # plinth top
TT = 0.08           # turntable thickness
Z0 = TOP + TT       # moai base

# cross-sections up the statue: (z above its base, half width, half depth, y offset, superellipse n)
SECTIONS = [(0.0, 0.5, 0.35, 0.0, 3.2), (0.25, 0.52, 0.37, 0.0, 3.2), (0.6, 0.52, 0.37, 0.01, 3.0),
            (0.85, 0.5, 0.35, 0.0, 3.0), (1.0, 0.45, 0.32, 0.0, 2.8), (1.08, 0.41, 0.31, 0.02, 2.6),
            (1.2, 0.39, 0.33, 0.04, 2.6), (1.45, 0.4, 0.35, 0.04, 2.7), (1.75, 0.41, 0.36, 0.03, 2.8),
            (2.0, 0.405, 0.37, 0.02, 2.8), (2.2, 0.385, 0.35, 0.0, 2.8), (2.36, 0.35, 0.31, -0.02, 2.8),
            (2.43, 0.3, 0.26, -0.03, 2.4), (2.45, 0.22, 0.18, -0.03, 2.2)]


def _interp(z):
    zs = [s[0] for s in SECTIONS]
    return [float(np.interp(z, zs, [s[i] for s in SECTIONS])) for i in range(1, 5)]


def _g(a, b):
    return np.exp(-(a * a + b * b))


def displacement(x, y, z, front, side):
    """Outward relief (metres) at body points; ``front`` / ``side`` weight
    the front and side regions."""
    d = np.zeros_like(x)
    # brow ridge
    d += 0.08 * np.exp(-(x / 0.26) ** 4) * np.exp(-((z - 2.0) / 0.06) ** 2) * front
    d += 0.025 * np.exp(-(x / 0.28) ** 4) * np.exp(-((z - 2.09) / 0.08) ** 2) * front
    d -= 0.035 * np.exp(-((z - 2.28) / 0.12) ** 2) * front            # the forehead leans back
    # deep eye sockets under the brow
    for sx in (-1, 1):
        d -= 0.08 * _g((x - sx * 0.17) / 0.1, (z - 1.86) / 0.075) * front
    # the long nose: grows from the brow down to flared nostrils
    t = np.clip((1.99 - z) / 0.5, 0.0, 1.0)
    on = (z > 1.43) & (z < 2.0)
    w = 0.055 + 0.07 * t
    d += np.where(on, (0.04 + 0.13 * t) * np.exp(-(x / w) ** 4), 0.0) * front
    for sx in (-1, 1):
        d += 0.06 * _g((x - sx * 0.1) / 0.06, (z - 1.5) / 0.05) * front              # nostril wings
        d -= 0.03 * _g((x - sx * 0.055) / 0.025, (z - 1.465) / 0.02) * front          # nostrils
    d += 0.02 * np.exp(-(x / 0.13) ** 4) * np.exp(-((z - 1.44) / 0.02) ** 2) * front   # nose base
    # pursed lips and the mouth line
    d += 0.07 * np.exp(-(x / 0.21) ** 6) * np.exp(-((z - 1.31) / 0.04) ** 2) * front
    d -= 0.03 * np.exp(-(x / 0.2) ** 6) * np.exp(-((z - 1.285) / 0.008) ** 2) * front
    # jutting chin and the jaw line
    d += 0.1 * np.exp(-(x / 0.3) ** 4) * np.exp(-((z - 1.17) / 0.07) ** 2) * front
    # ears: long slabs on the sides with an inner groove and drawn-out lobes
    ey = y
    ear = np.exp(-((ey + 0.02) / 0.1) ** 4) * np.exp(-((z - 1.68) / 0.3) ** 6) * side
    groove = np.exp(-((ey + 0.0) / 0.04) ** 2) * np.exp(-((z - 1.72) / 0.2) ** 6) * side
    d += 0.07 * ear - 0.03 * groove
    d += 0.05 * np.exp(-((ey + 0.03) / 0.06) ** 2) * np.exp(-((z - 1.3) / 0.08) ** 2) * side   # lobe
    return d


def arm_relief(px, py, pz):
    """Low relief of the arms and the long fingers, by distance to their
    centre lines drawn on the body surface (metres)."""
    d = np.zeros_like(px)
    for sx in (-1, 1):
        # down the side from the shoulder, then forward round the hip
        line = [(sx * 0.5, 0.05, 0.95), (sx * 0.52, 0.1, 0.62), (sx * 0.47, 0.25, 0.42), (sx * 0.33, 0.37, 0.4)]
        for a, b in zip(line[:-1], line[1:]):
            a, b = np.array(a), np.array(b)
            ab = b - a
            t = np.clip(((np.stack([px, py, pz], 1) - a) @ ab) / (ab @ ab), 0.0, 1.0)
            q = a + t[:, None] * ab
            dist = np.linalg.norm(np.stack([px, py, pz], 1) - q, axis=1)
            d = np.maximum(d, 0.035 * np.clip(1.0 - (dist / 0.075) ** 4, 0.0, 1.0))
        # four fingers over the belly toward the navel
        for k in range(4):
            zf = 0.37 + k * 0.035
            a = np.array([sx * 0.33, 0.37, zf])
            b = np.array([sx * 0.07, 0.38, zf + 0.02])
            ab = b - a
            t = np.clip(((np.stack([px, py, pz], 1) - a) @ ab) / (ab @ ab), 0.0, 1.0)
            q = a + t[:, None] * ab
            dist = np.linalg.norm(np.stack([px, py, pz], 1) - q, axis=1)
            d = np.maximum(d, 0.025 * np.clip(1.0 - (dist / 0.016) ** 2, 0.0, 1.0))
    # navel
    d += 0.02 * _g(px / 0.04, (pz - 0.5) / 0.04) * (py > 0)
    return d


def statue_mesh(rings=90, segs=72):
    bm = bmesh.new()
    zs = list(np.linspace(0.0, 2.45, rings))
    ring_verts = []
    for z in zs:
        hw, hd, yo, n = _interp(z)
        row = []
        for i in range(segs):
            a = 2 * math.pi * i / segs
            ca, sa = math.cos(a), math.sin(a)
            x = hw * math.copysign(abs(sa) ** (2.0 / n), sa)
            y = yo + hd * math.copysign(abs(ca) ** (2.0 / n), ca)
            row.append(bm.verts.new((x, y, z)))
        ring_verts.append(row)
    for j in range(rings - 1):
        for i in range(segs):
            i2 = (i + 1) % segs
            bm.faces.new((ring_verts[j][i], ring_verts[j][i2], ring_verts[j + 1][i2], ring_verts[j + 1][i]))
    bm.faces.new(list(reversed(ring_verts[0])))
    bm.faces.new(ring_verts[-1])
    bm.normal_update()
    # relief: push vertices along their horizontal outward direction
    co = np.array([v.co[:] for v in bm.verts])
    x, y, z = co[:, 0], co[:, 1], co[:, 2]
    yo = np.array([_interp(zz)[2] for zz in z])
    a = np.arctan2(x, y - yo)
    front = np.clip((np.cos(a) - 0.35) / 0.4, 0.0, 1.0)
    side = np.clip((np.abs(np.sin(a)) - 0.75) / 0.2, 0.0, 1.0)
    d = displacement(x, y - yo, z, front, side) + arm_relief(x, y, z)
    nrm = np.stack([np.sin(a), np.cos(a), np.zeros_like(a)], 1)
    co = co + nrm * d[:, None]
    for v, c in zip(bm.verts, co):
        v.co = c
    me = bpy.data.meshes.new("moai")
    bm.to_mesh(me)
    bm.free()
    return me


def statue():
    p = Part("moai", origin=(0.0, 0.0, TOP), parent="moai_plinth")
    me = statue_mesh()
    me = sculpt.decimate(me, 5200)
    clay.into_part(p, me, "basalt", smooth=True, transform=Matrix.Translation(Vector((0.0, 0.0, Z0))))
    # bronze turntable
    p.lathe([(0.0, TOP), (0.78, TOP), (0.78, TOP + 0.05), (0.75, TOP + TT), (0.0, TOP + TT)], "bronze",
            segments=32, cap_bottom=False, cap_top=False)
    # the iron bracket and ring at the back (-Y in Blender = +Z in Godot)
    p.box((0.0, -0.79, TOP + 0.045), (0.16, 0.1, 0.07), "iron", bevel=0.008)
    p.box((0.0, -0.85, TOP + 0.09), (0.05, 0.05, 0.14), "iron", bevel=0.006)
    tor = []
    for k in range(9):
        a = 2 * math.pi * k / 8
        tor.append((0.085 + 0.018 * math.cos(a), 0.018 * math.sin(a)))
    ring = p.lathe(tor, "iron", segments=16, cap_bottom=False, cap_top=False, smooth=True)
    p.move(ring, Matrix.Translation(Vector((0.0, -0.9, TOP + 0.13 + 0.085))) @ Matrix.Rotation(math.radians(90), 4, 'X'))
    return p


def plinth():
    p = Part("moai_plinth")
    p.box((0.0, 0.0, 0.06), (2.46, 2.46, 0.12), "plinth", bevel=0.012)
    p.box((0.0, 0.0, 0.62), (2.36, 2.36, 1.0), "ashlar", bevel=0.012)
    p.box((0.0, 0.0, 1.16), (2.44, 2.44, 0.08), "plinth", bevel=0.012)
    p.box((0.0, 1.186, 0.68), (0.62, 0.012, 0.18), "plaque", bevel=0.003)
    cull_floor([p])
    return p


def ashlar(ctx):
    """The plinth: dark stone ashlar in 0.5 m courses."""
    from artlib import arch_materials as A
    u, v = ctx.uvm[:, 0], ctx.uvm[:, 1]
    courses = A.course_layout(4.8, [0.5] * 4, [0.6, 0.8, 1.0, 1.2], 7, step=0.2)
    course, bid, dl, dr, db, dt = A.blocks(u + 2.4, v - 0.12, 4.8, 2.0, courses)
    s = AM.basalt(ctx, 1901, center=4.0, polish=0.2, vesicles=0.2)
    s.shade += (np.mod(bid * 0.618, 1.0) - 0.5) * 0.8
    joint = (dl < ctx.texel) | (db < ctx.texel)
    s.shade[joint] -= 1.8
    s.height = s.height - joint * 0.002
    return s


def moai_basalt(ctx):
    """Weathered basalt: lighter, rain-worn on the upward planes (brow,
    nose ridge, shoulders, crown), dark in the sockets and under the brow,
    a faint ochre-red stain round the crown."""
    s = AM.basalt(ctx, 1903, center=6.2, polish=0.05, vesicles=1.0)
    up = np.clip(ctx.n[:, 2], 0.0, 1.0)
    s.shade += up * 1.4 + np.clip(ctx.curv, 0, 1) * 1.2 - np.clip(-ctx.curv, 0, 1) * 1.6
    # paler weathered skin on the old exposed planes, in soft patches
    pale = (ctx.fbm(1.8, 4, 1905) > 0.15) & (ctx.ao > 0.6)
    s.shade[pale] += 1.0
    return s


_T = {}


def plaque(ctx):
    s = M.brass(ctx, 1909)
    front = ctx.n[:, 1] > 0.5
    if "t" not in _T:
        _T["t"] = pixelfont.trim(pixelfont.render(["MOAI", "RAPA NUI"], line_gap=2))
    if front.any():
        u, v = ctx.uvm[:, 0], ctx.uvm[:, 1]
        ink = pixelfont.stamp(ctx, _T["t"], np.median(u[front]), np.median(v[front]), scale=1) & front
        s.use_ramp(P["am_obsidian"], mask=ink, shade=np.full(ctx.N, 1.0))
        s.metal = np.where(ink, 0.0, s.metal)
    return s


def build():
    return kit("moai", [plinth(), statue()],
               {"plinth": lambda c: AM.basalt(c, 1911, center=3.6, polish=0.3, vesicles=0.2), "ashlar": ashlar,
                "plaque": plaque, "basalt": moai_basalt, "bronze": lambda c: M.brass(c, 1913, tarnish_amount=2.4),
                "iron": lambda c: AM.iron_old(c, 1915)},
               ppm=128, built_final=True, ground=0.0, ao_dist=0.35, organic=("moai",),
               markers=[("hook_ring", (0.0, -0.9, TOP + 0.215), "moai"), ("face", (0.0, 0.3, Z0 + 1.86), "moai")],
               preview_yaws=(-30.0, 25.0, 90.0, 180.0), preview_elevation=8.0,
               preview_closeup=((0.0, 0.3, Z0 + 1.7), 0.55),
               preview_extra=[("ring", (0.0, -0.9, TOP + 0.2), 0.35, 180.0, 15.0),
                              ("below", (0.0, 0.3, Z0 + 1.6), 1.4, 0.0, -18.0)])
