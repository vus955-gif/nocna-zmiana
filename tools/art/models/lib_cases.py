"""Enlightenment wing: glass-topped display cases with curiosities.

One mahogany table vitrine (1.8 x 0.8 m, 0.98 m high) on turned legs, a
baize-lined tray under a flat glass lid in a brass frame (glass = part
<id>_glass: the game may shatter it), four sets of contents with little
paper labels. Origin = centre of the base on the floor, front = Godot -Z.
Light: a lib_lamp_reading on a neighbouring table, or a spot from above.

  lib_case_shells       conchs, a nautilus, scallops, cowries, a starfish,
                        a branch of red coral.
  lib_case_minerals     an amethyst cluster on its matrix, quartz points,
                        pyrite cubes, a malachite nodule, a split geode, all
                        on card trays.
  lib_case_coins        three velvet trays of gold, silver and copper coins
                        and two medals on ribbons.
  lib_case_instruments  a sextant, an astrolabe, a pocket compass, a brass
                        telescope, dividers and a magnifying glass.
"""
import math
import os
import random

import numpy as np
from mathutils import Matrix

from artlib import enl_materials as E
from artlib import kit as K
from artlib import materials as M
from artlib.archkit import kit
from artlib.enl_materials import P
from artlib.geo import Part
from artlib.materials import _dither, hexramp
from artlib.painter import Surface

W, D = 1.8, 0.8
BED = 0.83          # top of the baize bed
LID = 0.98

P.update({
    "enl_shell": hexramp("#4a3a2c", "#66513e", "#836a52", "#a08568", "#bba183", "#d2bb9f", "#e4d3bb", "#f1e6d4"),
    "enl_shell_dark": hexramp("#1e100a", "#331b10", "#4a2817", "#62371f", "#7b4829"),
    "enl_coral": hexramp("#3a0a08", "#5c120e", "#811c16", "#a52a20", "#c43d2e", "#db5a46"),
    "enl_amethyst": hexramp("#1b0a24", "#2c1139", "#401a52", "#56246c", "#6e3187", "#8a45a2", "#a965bd", "#caa0d6"),
    "enl_quartz": hexramp("#6f7478", "#8b9095", "#a8adb1", "#c3c7ca", "#dcdfe0", "#eff1f1"),
    "enl_malachite": hexramp("#04140c", "#072415", "#0b3720", "#11502d", "#1a6b3c", "#268a4f", "#3aa866"),
    "enl_rock": hexramp("#1e1c1a", "#2b2825", "#3a3632", "#4a4540", "#5b5550", "#6d6660"),
    "enl_silver": hexramp("#2a2c30", "#3f4247", "#575b61", "#71767c", "#8d9298", "#a9aeb3", "#c5c9cd", "#e0e3e6"),
})


def case_body(name):
    p = Part(name)
    g = Part(name + "_glass")
    hw, hd = W / 2, D / 2
    for sx in (-1, 1):
        for sy in (-1, 1):
            p.lathe([(0.03, 0.0), (0.038, 0.025), (0.026, 0.06), (0.022, 0.3), (0.034, 0.45), (0.03, 0.55),
                     (0.038, 0.6), (0.038, 0.64)], "mahogany", segments=10, center=(sx * (hw - 0.07), sy * (hd - 0.07), 0.0))
    p.box((0, 0, 0.16), (W - 0.2, 0.035, 0.035), "mahogany", bevel=0.006)
    for sx in (-1, 1):
        p.box((sx * (hw - 0.07), 0, 0.16), (0.035, D - 0.16, 0.035), "mahogany", bevel=0.006)
    p.box((0, 0, 0.73), (W, D, 0.18), "mahogany", bevel=0.012)
    for sy in (-1, 1):
        p.box((0, sy * (hd + 0.004), 0.73), (W - 0.12, 0.008, 0.12), "mahogany_dark", bevel=0.006)
    p.box((0, -hd - 0.012, 0.73), (0.22, 0.006, 0.06), "brass", bevel=0.003)
    # the rim round the tray (the bed lies inside it, open under the glass)
    for sy in (-1, 1):
        p.box((0, sy * (hd - 0.01), 0.835), (W + 0.03, 0.05, 0.03), "mahogany", bevel=0.008)
    for sx in (-1, 1):
        p.box((sx * (hw - 0.01), 0, 0.835), (0.05, D - 0.04, 0.03), "mahogany", bevel=0.008)
    p.box((0, 0, BED - 0.005), (W - 0.06, D - 0.06, 0.01), "bed")
    # brass frame of the glass lid
    z0, z1 = 0.845, LID
    t = 0.022
    for sx in (-1, 1):
        for sy in (-1, 1):
            p.box((sx * (hw - 0.03), sy * (hd - 0.03), (z0 + z1) / 2), (t, t, z1 - z0), "brass")
    for z in (z0 + t / 2, z1 - t / 2):
        for sy in (-1, 1):
            p.box((0, sy * (hd - 0.03), z), (W - 0.06, t, t), "brass")
        for sx in (-1, 1):
            p.box((sx * (hw - 0.03), 0, z), (t, D - 0.06, t), "brass")
    e = 0.004
    from models.kit_room_props import _glass_box
    _glass_box(g, -hw + 0.03 + e, hw - 0.03 - e, -hd + 0.03 + e, hd - 0.03 - e, z0, z1 - 0.012)
    return p, g


def label(p, x, y, rot=0.0):
    f = p.box((0, 0, 0), (0.05, 0.026, 0.002), "label")
    p.move(f, Matrix.Translation((x, y, BED + 0.001)) @ Matrix.Rotation(math.radians(rot), 4, 'Z'))


def _lay(p, faces, x, y, z, rz=0.0, rx=0.0, ry=0.0):
    p.move(faces, Matrix.Translation((x, y, z)) @ Matrix.Rotation(math.radians(rz), 4, 'Z')
           @ Matrix.Rotation(math.radians(ry), 4, 'Y') @ Matrix.Rotation(math.radians(rx), 4, 'X'))
    return faces


# --- shells ------------------------------------------------------------------------

def conch(p, length, r):
    twist = lambda i, j: 1.0 + 0.14 * math.sin(math.tau * i / 12 + j * 1.9)
    prof = [(0.0, 0.0), (r * 0.35, length * 0.06), (r * 0.9, length * 0.25), (r, length * 0.42), (r * 0.75, length * 0.6),
            (r * 0.45, length * 0.78), (r * 0.18, length * 0.92), (r * 0.05, length)]
    return p.lathe(prof, "shell", segments=12, ring_scale=twist, cap_top=True)


def scallop(p, r):
    ribs = lambda i, j: 1.0 + (0.06 if i % 2 else 0.0)
    f = p.lathe([(0.0, 0.025), (r * 0.5, 0.018), (r, 0.0), (r, -0.004)], "shell", segments=24, ring_scale=ribs,
                cap_bottom=True)
    return K.keep(p, f, lambda c: c.y > -r * 0.25 and abs(math.atan2(c.x, c.y)) < math.radians(62))


def shells(p):
    rng = random.Random(41)
    spots = [(-0.6, 0.12), (-0.32, -0.12), (-0.05, 0.14), (0.25, -0.1), (0.55, 0.1), (0.7, -0.18), (-0.72, -0.2)]
    for k, (x, y) in enumerate(spots[:3]):
        L = rng.uniform(0.15, 0.22)
        f = conch(p, L, L * 0.33)
        _lay(p, f, x, y, BED + L * 0.3, rz=rng.uniform(0, 360), ry=85)
        label(p, x, y - 0.13, rng.uniform(-8, 8))
    # nautilus: a flattened sphere with a painted spiral, standing on its edge
    f = K.sphere(p, (0, 0, 0), 0.09, "nautilus", segments=16, rings=10, squash=(1.0, 0.55))
    _lay(p, f, 0.28, -0.08, BED + 0.085, rz=10, rx=90)
    label(p, 0.28, -0.24, 4)
    for k in range(3):
        f = scallop(p, rng.uniform(0.05, 0.07))
        _lay(p, f, 0.5 + k * 0.1, 0.18 - k * 0.05, BED + 0.002, rz=rng.uniform(-30, 30))
    for k in range(5):
        f = K.sphere(p, (0, 0, 0), 0.022, "cowrie", segments=8, rings=5, squash=(0.65, 1.0), zscale=0.6)
        _lay(p, f, -0.15 + k * 0.05, -0.27 + (k % 2) * 0.02, BED + 0.012, rz=rng.uniform(0, 40))
    star = []
    for i in range(10):
        a = math.tau * i / 10
        r = 0.075 if i % 2 == 0 else 0.026
        star.append((r * math.cos(a), r * math.sin(a)))
    f = p.ngon_prism(star, 0.0, 0.012, "starfish")
    _lay(p, f, 0.72, -0.16, BED, rz=17)
    # a branch of coral on a little black stand
    p.box((-0.7, -0.15, BED + 0.015), (0.08, 0.06, 0.03), "ebony", bevel=0.005)
    pts = [(-0.7, -0.15, BED + 0.03), (-0.71, -0.15, BED + 0.12), (-0.73, -0.15, BED + 0.2)]
    p.tube(pts, 0.009, "coral", sides=5)
    for (dx, dz, ex, ez) in ((0.0, 0.08, 0.05, 0.16), (-0.02, 0.12, -0.07, 0.2), (0.0, 0.15, 0.04, 0.23)):
        p.tube([(-0.71 + dx, -0.15, BED + dz), (-0.71 + ex, -0.15, BED + ez)], 0.006, "coral", sides=5)


def _shell(ctx):
    s = Surface(ctx.N)
    band = np.sin((ctx.p[:, 0] + ctx.p[:, 1]) * 160.0 + ctx.fbm(6.0, 2, 711) * 4.0)
    spots = ctx.fbm(30.0, 2, 712) > 0.45
    s.use_ramp(P["enl_shell"], shade=5.0 + band * 0.8 + ctx.fbm(9.0, 2, 713) * 0.6 - (1.0 - ctx.ao) * 3.0
               + ctx.edge(1.0) * 1.0)
    dark = spots | (band > 0.88)
    s.use_ramp(P["enl_shell_dark"], mask=dark, shade=np.full(ctx.N, 2.5) + _dither(ctx, 1.0, 714))
    s.rough = np.full(ctx.N, 0.35)
    return s


def _nautilus(ctx):
    s = Surface(ctx.N)
    a = np.arctan2(ctx.p[:, 2] - np.mean(ctx.p[:, 2]), ctx.p[:, 0] - np.mean(ctx.p[:, 0]))
    stripe = np.sin(a * 9.0 + ctx.p[:, 0] * 30.0) > 0.35
    s.use_ramp(P["enl_shell"], shade=6.2 + ctx.fbm(6.0, 2, 715) * 0.4 - (1.0 - ctx.ao) * 3.0)
    s.use_ramp(P["enl_shell_dark"], mask=stripe, shade=np.full(ctx.N, 3.0) + _dither(ctx, 0.8, 716))
    s.rough = np.full(ctx.N, 0.25)
    return s


# --- minerals ------------------------------------------------------------------------

def crystal(p, base, direction, length, r, mat):
    a = np.array(base)
    d = np.array(direction) / np.linalg.norm(direction)
    b = tuple(a + d * length)
    f = K.seg(p, tuple(a), b, [(r, 0.0), (r, 0.75), (r * 0.15, 1.0)], mat, segments=6, smooth=False)
    return f


def minerals(p):
    rng = random.Random(43)
    for x, y, w, d in ((-0.6, 0.05, 0.3, 0.26), (-0.18, -0.05, 0.22, 0.2), (0.2, 0.08, 0.24, 0.22), (0.6, -0.04, 0.26, 0.24)):
        p.box((x, y, BED + 0.008), (w, d, 0.016), "card", bevel=0.003)
        label(p, x, y - d / 2 - 0.035, rng.uniform(-5, 5))
    # amethyst cluster on a rock matrix
    K.sphere(p, (-0.6, 0.05, BED + 0.04), 0.1, "rock", segments=10, rings=6, squash=(1.2, 0.9), zscale=0.45)
    for k in range(9):
        a = rng.uniform(0, math.tau)
        rr = rng.uniform(0.0, 0.07)
        base = (-0.6 + rr * math.cos(a), 0.05 + rr * math.sin(a), BED + 0.06)
        tilt = (math.cos(a) * rr * 4, math.sin(a) * rr * 4, 1.0)
        crystal(p, base, tilt, rng.uniform(0.05, 0.11), rng.uniform(0.012, 0.022), "amethyst")
    # quartz points
    for k in range(4):
        crystal(p, (-0.2 + k * 0.03 - 0.04, -0.05 + (k % 2) * 0.03, BED + 0.016),
                (rng.uniform(-0.4, 0.4), rng.uniform(-0.3, 0.3), 1.0), rng.uniform(0.06, 0.12), 0.016, "quartz")
    # pyrite cubes
    for k in range(5):
        s = rng.uniform(0.02, 0.035)
        f = p.box((0, 0, 0), (s, s, s), "pyrite")
        _lay(p, f, 0.16 + rng.uniform(-0.06, 0.06), 0.08 + rng.uniform(-0.05, 0.05), BED + 0.016 + s / 2 + (k % 2) * 0.01,
             rz=rng.uniform(0, 90), rx=rng.uniform(0, 30))
    # malachite nodule and a split geode
    K.sphere(p, (0.52, -0.02, BED + 0.05), 0.065, "malachite", segments=12, rings=7, squash=(1.3, 1.0), zscale=0.6)
    gf = K.sphere(p, (0.7, -0.06, BED + 0.016), 0.06, "rock", segments=12, rings=8)
    K.keep(p, gf, lambda c: c.z < BED + 0.017)
    for k in range(6):
        a = math.tau * k / 6
        crystal(p, (0.7 + 0.03 * math.cos(a), -0.06 + 0.03 * math.sin(a), BED + 0.016),
                (-math.cos(a), -math.sin(a), 0.6), 0.03, 0.008, "amethyst")


def _crystal_mat(ramp, center, glow=0.0):
    def fn(ctx):
        s = Surface(ctx.N)
        shade = center + ctx.fbm(20.0, 2, 721) * 0.6 + _dither(ctx, 0.6, 722)
        shade += ctx.edge(1.0) * 2.5 + ctx.edge(2.0) * 0.8 - (1.0 - ctx.ao) * 2.0
        s.use_ramp(P[ramp], shade=shade)
        s.rough = np.full(ctx.N, 0.12)
        if glow:
            s.emit = s.colors() * glow
        return s
    return fn


def _malachite(ctx):
    s = Surface(ctx.N)
    r = np.linalg.norm(ctx.p - ctx.p.mean(axis=0), axis=1) + ctx.fbm(10.0, 2, 723) * 0.01
    band = np.sin(r * 400.0)
    s.use_ramp(P["enl_malachite"], shade=3.5 + band * 1.8 + _dither(ctx, 0.5, 724) - (1.0 - ctx.ao) * 2.0)
    s.rough = np.full(ctx.N, 0.2)
    return s


# --- coins ------------------------------------------------------------------------------

def coins(p):
    rng = random.Random(47)
    for k, (mat, bed) in enumerate((("coin_gold", "velvet"), ("coin_silver", "velvet"), ("coin_copper", "velvet"))):
        x = -0.55 + k * 0.55
        p.box((x, 0.0, BED + 0.012), (0.48, 0.56, 0.024), "tray", bevel=0.006)
        p.box((x, 0.0, BED + 0.025), (0.44, 0.52, 0.004), bed)
        for i in range(4):
            for j in range(4):
                if rng.random() < 0.12:
                    continue
                r = rng.uniform(0.014, 0.022) if mat != "coin_copper" else rng.uniform(0.016, 0.026)
                cx = x - 0.15 + i * 0.1
                cy = -0.18 + j * 0.11
                p.lathe([(r, 0.0), (r, 0.003), (r * 0.85, 0.004), (0.0, 0.004)], mat, segments=8,
                        center=(cx, cy, BED + 0.027), cap_bottom=False)
        label(p, x, -0.31, 0.0)
    # two medals on ribbons
    for k, x in enumerate((0.85 - 0.1, 0.85 - 0.02)):
        y = 0.12 - k * 0.2
        rib = p.box((0, 0, 0), (0.035, 0.09, 0.003), "ribbon" + str(k))
        _lay(p, rib, x, y + 0.06, BED + 0.002)
        p.lathe([(0.0, 0.0), (0.03, 0.0), (0.03, 0.004), (0.026, 0.005), (0.0, 0.005)], "coin_gold" if k else "coin_silver",
                segments=12, center=(x, y, BED + 0.002))


def _coin(ramp, center):
    def fn(ctx):
        s = Surface(ctx.N)
        top = ctx.n[:, 2] > 0.5
        rr = ctx.p[:, :2] - np.round(ctx.p[:, :2] / 0.01) * 0.01
        head = top & (ctx.fbm(60.0, 2, 731) > 0.15)
        shade = center + _dither(ctx, 0.8, 732) + ctx.edge(1.0) * 2.0 - (1.0 - ctx.ao) * 2.5 + head * 1.4
        s.use_ramp(P[ramp], shade=shade)
        s.metal = np.full(ctx.N, 0.85)
        s.rough = 0.28 + ctx.rand(733) * 0.1
        del rr
        return s
    return fn


# --- instruments ---------------------------------------------------------------------------

def instruments(p):
    # sextant: a 60-degree arc, two radii, the index arm, a little telescope
    cx, cy = -0.55, 0.0
    R = 0.24
    arc = [(cx + R * math.sin(math.radians(a)), cy - R * math.cos(math.radians(a)) + 0.12, BED + 0.012)
           for a in np.linspace(-30, 30, 9)]
    p.tube(arc, 0.008, "brass", sides=4)
    apex = (cx, cy + 0.12 + 0.0, BED + 0.012)
    for a in (-30, 30, 8):
        end = (cx + R * math.sin(math.radians(a)), cy - R * math.cos(math.radians(a)) + 0.12, BED + 0.012)
        p.tube([apex, end], 0.006, "brass", sides=4)
    tele = p.lathe([(0.011, 0.0), (0.011, 0.12), (0.014, 0.13), (0.014, 0.15)], "brass", segments=8,
                   center=(0, 0, 0))
    _lay(p, tele, cx - 0.08, cy + 0.02, BED + 0.03, rx=90, rz=-80)
    p.box((cx, cy + 0.08, BED + 0.03), (0.03, 0.006, 0.04), "mirror")
    label(p, cx, cy - 0.2, 3)
    # astrolabe: a disc with a ring and a throne
    f = p.lathe([(0.0, 0.0), (0.11, 0.0), (0.11, 0.008), (0.1, 0.01), (0.0, 0.01)], "astrolabe", segments=20)
    _lay(p, f, -0.12, 0.05, BED, rx=0.0)
    ring = [(-0.12 + 0.025 * math.cos(a), 0.05 + 0.13 + 0.025 * math.sin(a), BED + 0.006) for a in np.linspace(0, math.tau, 9)]
    p.tube(ring, 0.004, "brass", sides=4, caps=False)
    label(p, -0.12, -0.12, -4)
    # pocket compass
    p.lathe([(0.0, 0.0), (0.045, 0.0), (0.045, 0.018), (0.04, 0.022), (0.0, 0.022)], "compass", segments=16,
            center=(0.18, 0.14, BED))
    label(p, 0.18, 0.06, 6)
    # telescope lying across the tray (three draws)
    tf = p.lathe([(0.024, 0.0), (0.024, 0.2), (0.02, 0.2), (0.02, 0.33), (0.016, 0.33), (0.016, 0.43), (0.012, 0.44),
                  (0.012, 0.46)], "brass", segments=10)
    _lay(p, tf, 0.25, -0.18, BED + 0.025, ry=90, rz=8)
    # dividers and a magnifying glass
    for s in (-1, 1):
        p.tube([(0.62, 0.15, BED + 0.006), (0.62 + s * 0.03, 0.0, BED + 0.004)], 0.004, "steel", sides=4)
    p.lathe([(0.042, 0.0), (0.042, 0.008), (0.036, 0.008), (0.036, 0.0)], "brass", segments=14, cap_bottom=False,
            cap_top=False, center=(0.7, -0.12, BED + 0.002))
    p.lathe([(0.0, 0.0), (0.037, 0.0), (0.0, 0.004)], "lens", segments=14, center=(0.7, -0.12, BED + 0.004))
    p.tube([(0.7, -0.165, BED + 0.006), (0.7, -0.27, BED + 0.008)], 0.008, "ebony", sides=6)


def _astrolabe(ctx):
    s = E.dark_brass(ctx, seed=741)
    top = ctx.n[:, 2] > 0.5
    c = ctx.p[:, :2] - np.array([-0.12, 0.05])
    r = np.hypot(c[:, 0], c[:, 1])
    a = np.arctan2(c[:, 1], c[:, 0])
    rings = top & ((np.abs(r - 0.09) < ctx.texel) | (np.abs(r - 0.06) < ctx.texel) |
                   ((np.abs(np.mod(a, math.tau / 24)) < 0.02) & (r > 0.09)))
    s.shade[rings] -= 2.5
    rete = top & (np.abs(np.hypot(c[:, 0] - 0.02, c[:, 1] + 0.01) - 0.05) < ctx.texel)
    s.shade[rete] += 2.0
    return s


def _compass(ctx):
    s = Surface(ctx.N)
    top = ctx.n[:, 2] > 0.5
    c = ctx.p[:, :2] - np.array([0.18, 0.14])
    r = np.hypot(c[:, 0], c[:, 1])
    a = np.arctan2(c[:, 1], c[:, 0])
    face = top & (r < 0.038)
    s.use_ramp(P["brass"], shade=6.0 + _dither(ctx, 0.8, 751) + ctx.edge(1.0) * 2.0 - (1.0 - ctx.ao) * 2.5)
    s.use_ramp(P["enl_paper"], mask=face, shade=np.full(ctx.N, 6.5))
    needle = face & (np.abs(c[:, 0]) < ctx.texel * (1.0 + 2.5 * (1 - np.abs(c[:, 1]) / 0.03))) & (np.abs(c[:, 1]) < 0.03)
    rose = face & (np.abs(np.mod(a, math.pi / 4) - math.pi / 8) > math.pi / 8 - 0.06) & (r > 0.02) & (r < 0.034)
    s.use_ramp(P["enl_ink"], mask=rose, shade=np.full(ctx.N, 1.5))
    s.use_ramp(P["enl_morocco_red"], mask=needle & (c[:, 1] > 0), shade=np.full(ctx.N, 6.0))
    s.use_ramp(P["enl_ink"], mask=needle & (c[:, 1] <= 0), shade=np.full(ctx.N, 2.0))
    s.metal = np.where(face, 0.0, 1.0)
    s.rough = np.where(face, 0.15, 0.3)
    return s


def _label(ctx):
    return M.label(ctx, seed=761, ramp="enl_paper", center=7.0, size=0.0035)


def _flat(ramp, center, rough=0.6, metal=0.0):
    def fn(ctx):
        s = Surface(ctx.N)
        s.use_ramp(P[ramp], shade=center + ctx.fbm(9.0, 2, 771) * 0.5 + _dither(ctx, 0.6, 772)
                   + ctx.edge(1.0) * 1.2 - (1.0 - ctx.ao) * 3.0)
        s.rough = np.full(ctx.N, rough)
        s.metal = np.full(ctx.N, metal)
        return s
    return fn


def build():
    only = os.environ.get("ENL_ONLY", "").split(",")

    def want(n):
        return only == [""] or n in only

    base = {"mahogany": E.mahogany, "mahogany_dark": lambda c: E.mahogany(c, seed=781, center=3.0),
            "brass": E.worn_brass, "bed": lambda c: E.baize(c, seed=782), "label": _label,
            "ebony": _flat("enl_black", 3.0, 0.3)}
    sets = {
        "lib_case_shells": (shells, {"shell": _shell, "nautilus": _nautilus, "cowrie": _shell,
                                      "starfish": _flat("enl_wash_ochre", 3.5, 0.8),
                                      "coral": _flat("enl_coral", 3.5, 0.7)}),
        "lib_case_minerals": (minerals, {"card": M.cardboard, "rock": _flat("enl_rock", 3.0, 0.85),
                                          "amethyst": _crystal_mat("enl_amethyst", 4.0),
                                          "quartz": _crystal_mat("enl_quartz", 3.5),
                                          "pyrite": lambda c: M.brass(c, seed=783, tarnish_amount=0.6),
                                          "malachite": _malachite}),
        "lib_case_coins": (coins, {"tray": E.mahogany, "velvet": M.velvet,
                                   "coin_gold": _coin("gold", 6.5), "coin_silver": _coin("enl_silver", 5.0),
                                   "coin_copper": _coin("copper", 4.5),
                                   "ribbon0": _flat("enl_morocco_red", 5.0, 0.8),
                                   "ribbon1": _flat("enl_morocco_blue", 5.0, 0.8)}),
        "lib_case_instruments": (instruments, {"astrolabe": _astrolabe, "compass": _compass, "mirror":
                                               _flat("enl_quartz", 4.0, 0.05, 1.0),
                                               "steel": lambda c: M.steel(c, seed=784),
                                               "lens": _crystal_mat("enl_quartz", 4.5)}),
    }
    out = []
    for name, (fill, extra) in sets.items():
        if not want(name):
            continue
        p, g = case_body(name)
        fill(p)
        out.append(kit(name, [p, g], dict(base, **extra), kinds={"glass": "glass"}, ppm=192, ground=0.0,
                       ao_dist=0.2, preview_yaws=(-25.0, 25.0, 160.0, 90.0), preview_elevation=30.0,
                       preview_extra=[("top", (0.0, 0.0, BED + 0.05), 0.95, 0.0, 70.0)]))
    return out
