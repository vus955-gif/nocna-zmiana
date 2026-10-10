"""Enlightenment wing: the Natural History cabinet (gabinet historii
naturalnej) - where the stuffed wolves stand, the fossil raptors wake and
the collector's expedition rifle waits.

Kit convention: origin = centre of the base on the floor (wall pieces: on
the wall plane), front = Godot -Z.

  lib_nh_shelf_a   glazed mahogany specimen cabinet 2.0 x 2.6 x 0.55 m:
                   twenty shallow specimen drawers with brass label frames
                   below, three shelves behind glazing bars above: fossils
                   (ammonites, a trilobite, a fossil fish slab, an ox skull),
                   minerals and specimen jars in spirit. Glass = part
                   lib_nh_shelf_a_glass (shatters).
  lib_nh_shelf_b   the same cabinet with skulls (ox, ape, a big cat), a row
                   of specimen jars, a bird under a bell jar, ammonites.
  lib_antlers      a stag's skull and antlers on an oak shield, 0.9 m
                   wide; origin on the wall plane at the shield's centre.
  lib_diorama_base low plinth 3.2 x 1.8 m: a mahogany skirt, rolling ground
                   (0.33 m, a knoll to 0.45) with moss, rocks, a log and
                   tussocks of dry grass, a brass plate; flat ground at the
                   markers animal_spot_1 (the wolf) and animal_spot_2 (the
                   raptor), both at y 0.33.
  lib_rifle_rack   the collector's gun cabinet 1.7 x 2.4 x 0.5 m: a green
                   baize back with two old long guns on brass hooks above
                   and below, an empty pair of brass cradles in the middle
                   with marker "weapon_spot" (the expedition rifle pickup
                   lies there, barrel toward +X), a brass plate SZTUCER
                   EKSPEDYCYJNY and a picture lamp hanging out over the
                   opening (marker "Light", Godot (0, 2.14, -0.43): aim a
                   warm spot back and down into the cabinet; emission in
                   the bulb).
"""
import math
import os
import random

import numpy as np
from mathutils import Matrix

from artlib import arch_materials  # noqa: F401  (registers the "straw" ramp)
from artlib import enl_materials as E
from artlib import font
from artlib import kit as K
from artlib import materials as M
from artlib.archkit import facing, front_prism, kit
from artlib.enl_materials import P
from artlib.geo import Part
from artlib.materials import _dither, hexramp
from artlib.painter import Surface
from models import lib_cases as C

P.update({
    "enl_jar": hexramp("#2a1e06", "#45330b", "#634b12", "#83651c", "#a2802a", "#bd9a3c", "#d4b456"),
    "enl_horn": hexramp("#120c08", "#211710", "#33241a", "#463426", "#5b4635", "#715a46", "#887059"),
    "enl_feather": hexramp("#1a120c", "#2b1e14", "#3e2c1d", "#523c28", "#684e35", "#7f6344", "#977a56"),
})


def _lay(p, faces, x, y, z, rz=0.0, rx=0.0, ry=0.0):
    p.move(faces, Matrix.Translation((x, y, z)) @ Matrix.Rotation(math.radians(rz), 4, 'Z')
           @ Matrix.Rotation(math.radians(ry), 4, 'Y') @ Matrix.Rotation(math.radians(rx), 4, 'X'))
    return faces


# --- the cabinet --------------------------------------------------------------------------

CW, CH, CD = 2.0, 2.6, 0.55
SHELVES = (0.98, 1.48, 1.98)


def cabinet(name):
    """Built facing -Y (turned by kit())."""
    p = Part(name)
    g = Part(name + "_glass")
    hw, hd = CW / 2, CD / 2
    p.box((0, 0, 0.05), (CW, CD - 0.04, 0.1), "mahogany_dark", bevel=0.008)
    p.box((0, 0, 0.47), (CW, CD, 0.74), "mahogany", bevel=0.012)
    # specimen drawers: 4 x 5 with paper labels in brass frames and pulls
    for i in range(4):
        for j in range(5):
            x = -hw + 0.06 + (CW - 0.12) * (i + 0.5) / 4
            z = 0.14 + 0.66 * (j + 0.5) / 5
            p.box((x, -hd - 0.006, z), ((CW - 0.12) / 4 - 0.025, 0.012, 0.66 / 5 - 0.02), "mahogany")
            p.box((x, -hd - 0.014, z + 0.025), (0.07, 0.006, 0.035), "label_frame")
            p.box((x, -hd - 0.016, z - 0.025), (0.05, 0.01, 0.014), "brass")
    p.box((0, -0.01, 0.865), (CW + 0.04, CD + 0.06, 0.05), "mahogany", bevel=0.014)
    # the glazed upper case
    top = 2.45
    p.box((0, 0.24, (0.89 + top) / 2), (CW - 0.04, 0.03, top - 0.89), "back")
    for sx in (-1, 1):
        p.box((sx * (hw - 0.03), 0.0, (0.89 + top) / 2), (0.06, CD - 0.04, top - 0.89), "mahogany", bevel=0.008)
    for z in SHELVES[1:]:
        p.box((0, 0.02, z - 0.012), (CW - 0.1, CD - 0.1, 0.024), "mahogany", bevel=0.004)
    # two glazed doors with bars
    for sx in (-1, 1):
        cx = sx * hw / 2
        for xx in (cx - hw / 2 + 0.035, cx + hw / 2 - 0.035):
            p.box((xx, -hd + 0.01, (0.89 + top) / 2), (0.05, 0.03, top - 0.89), "mahogany", bevel=0.006)
        for zz in (0.915, top - 0.025):
            p.box((cx, -hd + 0.01, zz), (hw - 0.02, 0.03, 0.05), "mahogany", bevel=0.006)
        for zz in (1.4, 1.9):
            p.box((cx, -hd + 0.01, zz), (hw - 0.1, 0.018, 0.022), "mahogany")
        p.box((cx, -hd + 0.01, (0.89 + top) / 2), (0.02, 0.018, top - 0.89 - 0.06), "mahogany")
        p.box((cx - sx * (hw / 2 - 0.06), -hd - 0.012, 1.65), (0.02, 0.012, 0.07), "brass", bevel=0.003)
        facing(g, [(cx - hw / 2 + 0.06, -hd + 0.012, 0.94), (cx + hw / 2 - 0.06, -hd + 0.012, 0.94),
                   (cx + hw / 2 - 0.06, -hd + 0.012, top - 0.05), (cx - hw / 2 + 0.06, -hd + 0.012, top - 0.05)],
               "glass", (0, -1, 0))
    for sx in (-1, 1):
        facing(g, [(sx * (hw - 0.061), -hd + 0.04, 0.94), (sx * (hw - 0.061), hd - 0.06, 0.94),
                   (sx * (hw - 0.061), hd - 0.06, top - 0.05), (sx * (hw - 0.061), -hd + 0.04, top - 0.05)],
               "glass", (-sx, 0, 0))
    # cornice with a painted name board
    p.box((0, -0.005, top + 0.04), (CW + 0.02, CD + 0.03, 0.08), "mahogany", bevel=0.01)
    p.extrude([(0.0, top + 0.08), (-0.31, top + 0.08), (-0.31, top + 0.1), (-0.33, top + 0.12), (-0.34, top + 0.15),
               (-0.32, top + 0.15), (0.0, top + 0.15)], -hw - 0.03, hw + 0.03, "mahogany", caps=True)
    p.box((0, -hd - 0.025, top + 0.04), (CW * 0.5, 0.01, 0.07), "board_label", bevel=0.003)
    # a lamp strip under the top rail lights the shelves (emission + marker "Light")
    p.box((0, -hd + 0.07, top - 0.035), (CW - 0.2, 0.03, 0.012), "lamp")
    return p, g


def ammonite(p, c, r, rot=0.0):
    f = K.sphere(p, (0, 0, 0), r, "ammonite", segments=14, rings=8, squash=(1.0, 0.35))
    return _lay(p, f, c[0], c[1], c[2], rz=rot)


def ox_skull(p, c, s=1.0, rot=0.0):
    faces = []
    faces += K.sphere(p, (0, 0.02 * s, 0.03 * s), 0.11 * s, "skull", segments=12, rings=8, squash=(1.1, 0.95),
                      zscale=0.8)
    faces += K.seg(p, (0, -0.02 * s, 0.0), (0, -0.3 * s, -0.08 * s),
                   [(0.07 * s, 0.0), (0.06 * s, 0.6), (0.04 * s, 1.0)], "skull", segments=8, squash=(1.0, 0.8))
    for sx in (-1, 1):
        pts = [(sx * 0.09 * s, 0.03 * s, 0.08 * s), (sx * 0.2 * s, 0.03 * s, 0.1 * s),
               (sx * 0.29 * s, -0.02 * s, 0.17 * s), (sx * 0.31 * s, -0.06 * s, 0.25 * s)]
        faces += p.tube(pts, lambda t: (0.035 - 0.028 * t) * s, "horn", sides=6)
    return _lay(p, faces, c[0], c[1], c[2], rz=rot)


def ape_skull(p, c, s=1.0, rot=0.0):
    faces = []
    faces += K.sphere(p, (0, 0.02 * s, 0.05 * s), 0.075 * s, "skull", segments=12, rings=8, squash=(0.9, 1.05))
    faces += p.box((0, -0.06 * s, 0.0), (0.09 * s, 0.07 * s, 0.07 * s), "skull", bevel=0.015 * s)
    faces += p.box((0, -0.06 * s, -0.05 * s), (0.08 * s, 0.06 * s, 0.03 * s), "skull", bevel=0.01 * s)
    return _lay(p, faces, c[0], c[1], c[2], rz=rot)


def cat_skull(p, c, s=1.0, rot=0.0):
    faces = []
    faces += K.sphere(p, (0, 0.03 * s, 0.03 * s), 0.07 * s, "skull", segments=12, rings=8, squash=(1.0, 1.3),
                      zscale=0.75)
    faces += K.seg(p, (0, -0.02 * s, 0.0), (0, -0.12 * s, -0.01 * s), [(0.055 * s, 0.0), (0.045 * s, 1.0)], "skull",
                   segments=8, squash=(1.0, 0.8))
    for sx in (-1, 1):
        faces += K.cone(p, (sx * 0.025 * s, -0.11 * s, -0.025 * s), (0, -0.1, -1.0), 0.08 * s, 0.011 * s, "ivory",
                        segments=5)
    return _lay(p, faces, c[0], c[1], c[2], rz=rot)


def jar(p, c, h, r):
    p.lathe([(r * 0.9, 0.0), (r, 0.01), (r, h * 0.8), (r * 0.82, h * 0.86), (r * 0.82, h * 0.9)], "jar", segments=10,
            center=c, cap_top=False)
    p.lathe([(r * 0.86, h * 0.88), (r * 0.9, h * 0.9), (r * 0.9, h * 0.96), (0.0, h * 0.97)], "lid", segments=10,
            center=c, cap_bottom=False)
    p.lathe([(r + 0.002, h * 0.3), (r + 0.002, h * 0.5)], "label", segments=10, center=c, cap_bottom=False,
            cap_top=False)


def fish_slab(p, c, rot=0.0):
    f = p.box((0, 0, 0), (0.34, 0.02, 0.22), "slab", bevel=0.006)
    _lay(p, f, c[0], c[1], c[2], rz=rot, rx=-12)
    stand = p.box((0, 0, 0), (0.1, 0.08, 0.02), "mahogany")
    return _lay(p, stand, c[0], c[1] + 0.05, c[2] - 0.1, rz=rot)


def trilobite(p, c, rot=0.0):
    f = K.sphere(p, (0, 0, 0), 0.06, "trilobite", segments=10, rings=6, squash=(0.65, 1.0), zscale=0.35)
    return _lay(p, f, c[0], c[1], c[2], rz=rot)


def bird_dome(p, g, c):
    x, y, z = c
    p.lathe([(0.0, 0.0), (0.12, 0.0), (0.12, 0.03), (0.1, 0.04), (0.0, 0.04)], "mahogany", segments=12, center=c)
    p.tube([(x - 0.06, y, z + 0.04), (x - 0.02, y, z + 0.12), (x + 0.05, y, z + 0.16)], 0.008, "horn", sides=5)
    body = K.sphere(p, (0, 0, 0), 0.04, "feather", segments=10, rings=6, squash=(0.8, 1.3))
    _lay(p, body, x + 0.01, y, z + 0.2, rx=20)
    K.sphere(p, (x + 0.01, y - 0.045, z + 0.235), 0.022, "feather", segments=8, rings=5)
    K.cone(p, (x + 0.01, y - 0.065, z + 0.235), (0, -1, -0.2), 0.025, 0.006, "horn", segments=4)
    p.tube([(x + 0.01, y + 0.04, z + 0.19), (x + 0.01, y + 0.1, z + 0.14)], lambda t: 0.012 * (1 - t * 0.6), "feather",
           sides=4)
    g.lathe([(0.11, 0.04), (0.11, 0.26), (0.09, 0.31), (0.05, 0.335), (0.0, 0.34)], "glass", segments=12, center=c,
            cap_bottom=False, smooth=True)


def fill_a(p, rng):
    z0, z1, z2 = SHELVES
    y = -0.02
    for k, x in enumerate((-0.75, -0.55, -0.32)):
        r = 0.08 - 0.012 * k
        ammonite(p, (x, y + 0.04, z0 + r + 0.012), r, rot=rng.uniform(-10, 10))
        p.box((x, y + 0.04, z0 + 0.006), (0.07, 0.05, 0.012), "mahogany")
    trilobite(p, (-0.05, y - 0.05, z0 + 0.025), rot=12)
    fish_slab(p, (0.3, y + 0.05, z0 + 0.13), rot=-6)
    for k in range(4):
        C.crystal(p, (0.62 + k * 0.035, y - 0.02 + (k % 2) * 0.04, z0), (rng.uniform(-0.3, 0.3), 0.0, 1.0),
                  rng.uniform(0.07, 0.13), 0.018, "quartz")
    ox_skull(p, (-0.5, y + 0.02, z1 + 0.14), 1.0, rot=25)
    jar(p, (0.1, y, z1), 0.3, 0.08)
    jar(p, (0.33, y + 0.05, z1), 0.22, 0.06)
    K.sphere(p, (0.66, y, z1 + 0.05), 0.09, "rock", segments=10, rings=6, squash=(1.2, 0.9), zscale=0.5)
    for k in range(7):
        a = rng.uniform(0, math.tau)
        rr = rng.uniform(0.0, 0.06)
        C.crystal(p, (0.66 + rr * math.cos(a), y + rr * math.sin(a), z1 + 0.07),
                  (math.cos(a) * rr * 5, math.sin(a) * rr * 5, 1.0), rng.uniform(0.05, 0.1), rng.uniform(0.012, 0.02),
                  "amethyst")
    for k, x in enumerate((-0.7, -0.35, 0.05, 0.45, 0.75)):
        if k % 2 == 0:
            ammonite(p, (x, y + 0.06, z2 + 0.072), 0.06, rot=rng.uniform(-20, 20))
            p.box((x, y + 0.06, z2 + 0.006), (0.06, 0.04, 0.012), "mahogany")
        else:
            jar(p, (x, y, z2), 0.24, 0.065)


def fill_b(p, g, rng):
    z0, z1, z2 = SHELVES
    y = -0.02
    ox_skull(p, (-0.5, y + 0.02, z0 + 0.13), 1.1, rot=-6)
    ape_skull(p, (0.05, y - 0.02, z0 + 0.08), 1.0, rot=10)
    cat_skull(p, (0.5, y - 0.02, z0 + 0.06), 1.1, rot=-15)
    for k, x in enumerate((-0.78, -0.56, -0.36, -0.16, 0.04)):
        jar(p, (x, y + (k % 2) * 0.05, z1), 0.2 + 0.05 * (k % 3), 0.06 + 0.01 * (k % 2))
    bird_dome(p, g, (0.45, y, z1))
    for k, x in enumerate((-0.7, -0.4, -0.12)):
        ammonite(p, (x, y + 0.06, z2 + 0.087), 0.075, rot=rng.uniform(-20, 20))
        p.box((x, y + 0.06, z2 + 0.006), (0.07, 0.05, 0.012), "mahogany")
    trilobite(p, (0.25, y - 0.04, z2 + 0.022), rot=-20)
    trilobite(p, (0.42, y - 0.02, z2 + 0.022), rot=30)
    fish_slab(p, (0.7, y + 0.06, z2 + 0.13), rot=8)


# --- painters -----------------------------------------------------------------------------

def _island_centres(ctx, cell=0.25):
    """A cheap per-object centre: the mean of the texels in each 25 cm cell."""
    c3 = np.floor(ctx.p / cell).astype(np.int64)
    key = c3[:, 0] * 7919 + c3[:, 1] * 104729 + c3[:, 2] * 1299709
    centre = np.zeros_like(ctx.p)
    for k in np.unique(key):
        m = key == k
        centre[m] = ctx.p[m].mean(axis=0)
    return centre


def _ammonite(ctx):
    """Ribbed spiral shell standing on edge: whorl lines on a logarithmic spiral
    round each shell's centre, radial ribs, pale stone."""
    s = Surface(ctx.N)
    d = ctx.p - _island_centres(ctx)
    a = np.arctan2(d[:, 2], d[:, 0])
    r = np.hypot(d[:, 0], d[:, 2]) + 1e-4
    spiral = np.mod(np.log(r) / 0.7 - a / math.tau, 1.0)
    whorl = spiral < 0.12
    rib = np.sin(a * 22.0 + np.log(r) * 6.0) > 0.55
    shade = 4.8 + rib * 0.9 - whorl * 2.4 + ctx.fbm(12.0, 2, 891) * 0.6 + _dither(ctx, 0.5, 892)
    shade -= (1.0 - ctx.ao) * 3.0
    s.use_ramp(P["enl_shell"], shade=shade)
    s.rough = np.full(ctx.N, 0.5)
    s.height = rib * 0.0008 - whorl * 0.0012
    return s


def _trilobite(ctx):
    s = M.stone(ctx, seed=893)
    d = ctx.p - _island_centres(ctx)
    seg = np.sin(d[:, 1] * 260.0) > 0.4
    lobe = np.abs(np.abs(d[:, 0]) - 0.012) < ctx.texel
    s.shade += seg * 1.2 - lobe * 1.5 - 1.0
    return s


def _slab(ctx):
    """A slab of limestone with a fossil fish: spine, ribs and a tail."""
    s = M.stone(ctx, seed=894)
    u, v = ctx.uvm[:, 0], ctx.uvm[:, 1]
    front = ctx.n[:, 1] > 0.5                  # the face toward the room (kit frame, after the turn)
    cu = np.mean(u[front]) if front.any() else 0.0
    cv = np.mean(v[front]) if front.any() else 0.0
    du, dv = u - cu, v - cv
    body = (np.abs(dv) < 0.05 * np.clip(1 - (du / 0.13) ** 2, 0, 1) ** 0.5) & (np.abs(du) < 0.13)
    spine = np.abs(dv) < ctx.texel * 0.9
    ribs = (np.abs(np.mod(du, 0.012) - 0.006) < ctx.texel * 0.6) & body
    tail = (du < -0.12) & (du > -0.17) & (np.abs(dv) < (-0.12 - du) * 0.9)
    fossil = front & ((body & (spine | ribs)) | tail)
    s.use_ramp(P["bone"], mask=fossil, shade=np.full(ctx.N, 4.0) + _dither(ctx, 0.8, 895))
    s.shade[front & body & ~fossil] -= 0.6
    return s


def _jar(ctx):
    """Opaque spirit jar: yellowed alcohol, a dark curled specimen inside."""
    s = Surface(ctx.N)
    blob = ctx.fbm(9.0, 3, 896) > 0.05
    shade = 4.0 + ctx.fbm(5.0, 2, 897) * 0.5 - blob * 2.6 + ctx.edge(1.0) * 2.0
    shade += np.clip(ctx.n[:, 2], 0, 1) * 1.5 - (1.0 - ctx.ao) * 1.5
    s.use_ramp(P["enl_jar"], shade=shade)
    s.rough = np.full(ctx.N, 0.05)
    s.emit = s.colors() * 0.06
    return s


def _feather(ctx):
    s = Surface(ctx.N)
    streak = ctx.fbm(np.array([40.0, 40.0, 8.0]), 2, 898)
    s.use_ramp(P["enl_feather"], shade=4.0 + streak * 1.5 + _dither(ctx, 0.6, 899) - (1.0 - ctx.ao) * 2.5)
    s.rough = np.full(ctx.N, 0.8)
    return s


def plate_text(text, ground="brass"):
    """Engraved brass (or painted) plate: dark capitals centred on the face
    that looks out (|normal.y| large), sized to fit."""
    def fn(ctx):
        if ground == "brass":
            s = M.brass(ctx, seed=901, tarnish_amount=1.0)
            s.shade += 0.8
        else:
            s = E.baize(ctx, seed=902)
        u, v = ctx.uvm[:, 0], ctx.uvm[:, 1]
        front = ctx.n[:, 1] > 0.5                  # the face toward the room (kit frame, after the turn)
        if front.any():
            cu = (u[front].min() + u[front].max()) / 2
            cv = (v[front].min() + v[front].max()) / 2
            wid = u[front].max() - u[front].min()
            px = font.fit_px(text, wid * 0.86, ctx.texel, max_px=ctx.texel * 2)
            ink = front & font.text_mask(u, v, text, cu, cv - 3.5 * px, px)
            ink_ramp = "enl_ink" if ground == "brass" else "gold"
            s.use_ramp(P[ink_ramp], mask=ink, shade=np.full(ctx.N, 1.5 if ground == "brass" else 6.5))
            s.metal = np.where(ink, 0.0 if ground == "brass" else 0.9, s.metal)
        return s
    return fn


# --- antlers ---------------------------------------------------------------------------------

def antlers():
    """Built facing -Y on the wall plane y = 0 (centre of the shield at 0)."""
    p = Part("lib_antlers")
    outline = [(-0.22, 0.32), (-0.22, 0.02)]
    for a in range(195, 346, 15):
        outline.append((0.22 * math.cos(math.radians(a)), -0.02 + 0.28 * math.sin(math.radians(a)) + 0.04))
    outline += [(0.22, 0.02), (0.22, 0.32), (0.0, 0.38)]
    front_prism(p, outline, 0.04, "oak", bevel=0.008)
    K.seg(p, (0, -0.07, 0.1), (0, -0.2, -0.16), [(0.075, 0.0), (0.06, 0.55), (0.035, 1.0)], "skull",
          segments=8, squash=(1.0, 0.75))
    K.sphere(p, (0, -0.09, 0.13), 0.085, "skull", segments=10, rings=7, squash=(1.0, 0.8))
    for sx in (-1, 1):
        beam = [(sx * 0.05, -0.1, 0.18), (sx * 0.16, -0.14, 0.3), (sx * 0.3, -0.16, 0.46), (sx * 0.4, -0.15, 0.64),
                (sx * 0.42, -0.12, 0.8)]
        p.tube(beam, lambda t: 0.024 - 0.012 * t, "horn", sides=6)
        for (i, dx, dy, dz, L) in ((1, 0.06, -0.14, 0.06, 0.2), (2, -0.03, -0.18, 0.1, 0.22),
                                   (3, 0.09, -0.05, 0.12, 0.2), (3, -0.07, -0.1, 0.1, 0.17),
                                   (4, 0.06, -0.02, 0.08, 0.14)):
            a = beam[i]
            tip = (a[0] + sx * dx * L / 0.2, a[1] + dy * L / 0.2, a[2] + dz * L / 0.2 + 0.05)
            mid = ((a[0] + tip[0]) / 2, (a[1] + tip[1]) / 2 - 0.02, (a[2] + tip[2]) / 2 + 0.02)
            p.tube([a, mid, tip], lambda t: 0.014 - 0.009 * t, "horn", sides=5)
    p.box((0, -0.045, -0.2), (0.16, 0.008, 0.035), "plate", bevel=0.003)
    return p


# --- diorama base ------------------------------------------------------------------------

def diorama_base():
    p = Part("lib_diorama_base")
    W, D, H = 3.2, 1.8, 0.45
    p.box((0, 0, 0.04), (W, D, 0.08), "mahogany_dark", bevel=0.01)
    p.box((0, 0, 0.2), (W - 0.04, D - 0.04, 0.26), "mahogany", bevel=0.014)
    rng = random.Random(53)
    spots = ((-0.9, 0.2), (0.5, -0.1))

    def height(x, y):
        h = 0.05 * math.sin(x * 2.1 + 0.7) * math.cos(y * 2.7) + 0.035 * math.sin(x * 4.3 + y * 3.1)
        h += 0.08 * math.exp(-((x - 1.25) ** 2 + (y - 0.5) ** 2) / 0.12)      # a knoll at the back corner
        for sx, sy in spots:                                                      # flat where the animals stand
            h *= 1.0 - math.exp(-((x - sx) ** 2 / 0.35 + (y - sy) ** 2 / 0.12))
        return max(0.0, h + 0.03)

    nx, ny = 16, 9
    x0, x1, y0, y1 = -W / 2 + 0.06, W / 2 - 0.06, -D / 2 + 0.06, D / 2 - 0.06
    vs = [[p.bm.verts.new((x0 + (x1 - x0) * i / nx, y0 + (y1 - y0) * j / ny,
                           0.33 + (height(x0 + (x1 - x0) * i / nx, y0 + (y1 - y0) * j / ny)
                                   if 0 < i < nx and 0 < j < ny else 0.0)))
           for i in range(nx + 1)] for j in range(ny + 1)]
    for j in range(ny):
        for i in range(nx):
            f = p._face([vs[j][i], vs[j][i + 1], vs[j + 1][i + 1], vs[j + 1][i]], "ground", smooth=True)
            f.normal_update()
            if f.normal.z < 0:
                f.normal_flip()
    for k in range(18):
        x = rng.uniform(-1.45, 1.45)
        y = rng.uniform(-0.75, 0.75)
        if any(abs(x - sx) < 0.75 and abs(y - sy) < 0.45 for sx, sy in spots):
            continue
        r = rng.uniform(0.07, 0.24)
        K.sphere(p, (x, y, 0.33 + height(x, y) + r * 0.25), r, "rock", segments=8, rings=5,
                 squash=(rng.uniform(1.0, 1.5), 1.0), zscale=rng.uniform(0.6, 0.9))
    # a weathered log along the front edge
    p.tube([(-0.2, -0.62, 0.38), (0.3, -0.6, 0.39), (0.85, -0.66, 0.37)], 0.06, "log", sides=7)
    p.tube([(0.3, -0.6, 0.4), (0.42, -0.5, 0.52)], 0.022, "log", sides=5)
    # tussocks of dry grass, clustered
    for c in range(16):
        cx, cy = rng.uniform(-1.45, 1.45), rng.uniform(-0.78, 0.78)
        if any(abs(cx - sx) < 0.45 and abs(cy - sy) < 0.3 for sx, sy in spots):
            continue
        for k in range(7):
            x, y = cx + rng.uniform(-0.07, 0.07), cy + rng.uniform(-0.07, 0.07)
            z = 0.33 + height(x, y)
            hgt = rng.uniform(0.1, 0.24)
            lx, ly = (x - cx) * 1.5, (y - cy) * 1.5
            p.tube([(x, y, z - 0.01), (x + lx * 0.4, y + ly * 0.4, z + hgt * 0.6), (x + lx, y + ly, z + hgt)],
                   lambda t: 0.012 * (1 - t * 0.9), "grass", sides=3, caps=False)
    p.box((0, -D / 2 - 0.004, 0.2), (0.6, 0.008, 0.11), "plate", bevel=0.004)
    return p


def _ground(ctx):
    """Diorama ground: dry ochre earth with patches of moss and dark soil."""
    s = Surface(ctx.N)
    n1 = ctx.fbm(3.0, 4, 921)
    n2 = ctx.fbm(14.0, 2, 922)
    s.use_ramp(P["enl_wash_ochre"], shade=2.6 + n1 * 1.2 + n2 * 0.6 + _dither(ctx, 0.7, 923) - (1.0 - ctx.ao) * 2.5)
    moss = n1 > 0.22
    s.use_ramp(P["flock"], mask=moss, shade=np.full(ctx.N, 3.0) + n2 * 1.2 + _dither(ctx, 0.8, 924))
    soil = n1 < -0.3
    s.use_ramp(P["enl_rock"], mask=soil, shade=np.full(ctx.N, 1.6) + n2 * 0.8)
    s.rough = np.full(ctx.N, 0.95)
    return s


# --- rifle rack ---------------------------------------------------------------------------------

def long_gun(p, length, x0, z, stock="walnut", musket=True):
    """A gun lying along +X (muzzle at +X), side view toward -Y."""
    bl = length * 0.66
    K.seg(p, (x0 + length - bl, -0.05, z), (x0 + length, -0.05, z), [(0.012, 0.0), (0.01, 1.0)], "gunmetal",
          segments=8)
    prof = [(0.0, -0.06), (0.06, -0.075), (0.2, -0.05), (length - bl + 0.04, -0.012), (length * 0.9, -0.012),
            (length * 0.9, 0.006), (length - bl, 0.012), (0.24, 0.02), (0.06, 0.04), (0.0, 0.05)]
    st = front_prism(p, [(x, zz) for x, zz in prof], 0.04, stock, bevel=0.004)
    p.move(st, Matrix.Translation((x0, -0.03, z)))
    p.box((x0 + length - bl + 0.02, -0.07, z + 0.01), (0.12, 0.02, 0.04), "brass" if musket else "gunmetal",
          bevel=0.004)
    p.box((x0 + length - bl - 0.06, -0.07, z - 0.04), (0.08, 0.012, 0.02), "brass", bevel=0.003)
    for t in (0.35, 0.6, 0.85):
        K.seg(p, (x0 + length * t, -0.05, z - 0.016), (x0 + length * t + 0.012, -0.05, z - 0.016),
              [(0.016, 0.0), (0.016, 1.0)], "brass", segments=6)


def rifle_rack():
    p = Part("lib_rifle_rack")
    W, D = 1.7, 0.5
    hw, hd = W / 2, D / 2
    p.box((0, 0, 0.05), (W, D - 0.04, 0.1), "mahogany_dark", bevel=0.008)
    p.box((0, 0, 0.45), (W, D, 0.7), "mahogany", bevel=0.012)
    for sx in (-1, 1):
        p.box((sx * hw / 2, -hd - 0.006, 0.45), (hw - 0.08, 0.012, 0.56), "panel", bevel=0.01)
        p.box((sx * 0.06, -hd - 0.016, 0.62), (0.02, 0.012, 0.06), "brass", bevel=0.003)
    p.box((0, -0.01, 0.82), (W + 0.04, D + 0.04, 0.04), "mahogany", bevel=0.012)
    p.box((0, 0.2, 1.52), (W - 0.08, 0.04, 1.4), "baize")
    for sx in (-1, 1):
        p.box((sx * (hw - 0.035), 0.0, 1.52), (0.07, D - 0.04, 1.4), "mahogany", bevel=0.008)
    p.box((0, 0.0, 2.25), (W, D, 0.1), "mahogany", bevel=0.012)
    p.extrude([(0.0, 2.3), (-0.27, 2.3), (-0.29, 2.32), (-0.3, 2.35), (0.0, 2.35)], -hw - 0.02, hw + 0.02,
              "mahogany", caps=True)
    # brass hooks: a musket above, a fowling piece below; the middle cradles wait for the rifle
    for z in (2.0, 1.1, 1.55):
        for x in (-0.45, 0.45):
            p.box((x, 0.12, z - 0.035), (0.03, 0.12, 0.025), "brass", bevel=0.004)
            p.box((x, 0.065, z - 0.015), (0.03, 0.012, 0.045), "brass", bevel=0.003)
    long_gun(p, 1.5, -0.75, 2.02)
    long_gun(p, 1.42, -0.71, 1.12, musket=False)
    p.box((0, -hd - 0.02, 0.94), (0.84, 0.012, 0.09), "plate_rifle", bevel=0.004)
    # the picture lamp: an arm from the cornice reaching out over the opening, the hood
    # hanging in front of it so its light falls back into the cabinet
    p.box((0, -0.27, 2.33), (0.06, 0.04, 0.05), "brass", bevel=0.008)
    p.tube([(0, -0.27, 2.34), (0, -0.36, 2.38), (0, -0.43, 2.3), (0, -0.44, 2.22)], 0.011, "brass", sides=6)
    hood = p.lathe([(0.0, -0.22), (0.04, -0.21), (0.05, -0.15), (0.05, 0.15), (0.04, 0.21), (0.0, 0.22)], "shade",
                   segments=10, squash=(1.0, 0.7))
    p.move(hood, Matrix.Translation((0, -0.44, 2.19)) @ Matrix.Rotation(math.radians(90), 4, 'Y'))
    bulb = p.lathe([(0.0, -0.18), (0.012, -0.18), (0.012, 0.18), (0.0, 0.18)], "bulb", segments=6)
    p.move(bulb, Matrix.Translation((0, -0.43, 2.16)) @ Matrix.Rotation(math.radians(90), 4, 'Y'))
    return p


def build():
    only = os.environ.get("ENL_ONLY", "").split(",")

    def want(n):
        return only == [""] or n in only

    base = {"mahogany": E.mahogany, "mahogany_dark": lambda c: E.mahogany(c, seed=905, center=3.0),
            "back": lambda c: E.plaster_cool(c, seed=906, center=4.6), "brass": E.worn_brass,
            "lamp": M.lamp_warm,
            "label_frame": C._flat("enl_paper", 6.2, 0.8), "board_label": plate_text("HISTORIA NATURALNA", "baize"),
            "ammonite": _ammonite, "trilobite": _trilobite, "slab": _slab, "jar": _jar,
            "lid": lambda c: M.brass(c, seed=907, tarnish_amount=2.5), "label": C._label,
            "skull": lambda c: M.ivory(c, seed=908, center=4.6), "horn": C._flat("enl_horn", 3.5, 0.5),
            "ivory": M.ivory, "rock": C._flat("enl_rock", 3.2, 0.85), "quartz": C._crystal_mat("enl_quartz", 3.5),
            "amethyst": C._crystal_mat("enl_amethyst", 4.0), "feather": _feather}
    out = []
    rng = random.Random(61)
    view = dict(preview_yaws=(-20.0, 20.0, 160.0, 60.0), preview_elevation=6.0)
    if want("lib_nh_shelf_a"):
        p, g = cabinet("lib_nh_shelf_a")
        fill_a(p, rng)
        out.append(kit("lib_nh_shelf_a", [p, g], base, kinds={"glass": "glass"}, ppm=160, ground=0.0, ao_dist=0.25,
                       markers=[("Light", (0.0, 0.0, 2.38), None)],
                       preview_extra=[("shelves", (0.0, 0.0, 1.5), 0.75, -10.0, 4.0)], **view))
    if want("lib_nh_shelf_b"):
        p, g = cabinet("lib_nh_shelf_b")
        fill_b(p, g, rng)
        out.append(kit("lib_nh_shelf_b", [p, g], base, kinds={"glass": "glass"}, ppm=160, ground=0.0, ao_dist=0.25,
                       markers=[("Light", (0.0, 0.0, 2.38), None)], preview=False))
    if want("lib_antlers"):
        out.append(kit("lib_antlers", [antlers()], dict(base, oak=E.oak_dark, plate=plate_text("CERVUS ELAPHUS")),
                       ppm=192, ground=None, wall=True, ao_dist=0.15, preview_yaws=(-30.0, 0.0, 30.0, 60.0)))
    if want("lib_diorama_base"):
        out.append(kit("lib_diorama_base", [diorama_base()],
                       dict(base, ground=_ground, grass=C._flat("straw", 3.0, 0.9), log=M.wood_oak,
                            plate=plate_text("FAUNA EUROPY")),
                       ppm=96, ground=0.0, ao_dist=0.3, preview_elevation=25.0,
                       markers=[("animal_spot_1", (-0.9, 0.2, 0.33), None), ("animal_spot_2", (0.5, -0.1, 0.33), None)]))
    if want("lib_rifle_rack"):
        out.append(kit("lib_rifle_rack", [rifle_rack()],
                       dict(base, baize=lambda c: E.baize(c, seed=909), panel=E.mahogany, walnut=M.walnut_stock,
                            gunmetal=M.gun_steel, plate_rifle=plate_text("SZTUCER EKSPEDYCYJNY"),
                            shade=lambda c: E.shade_green(c, seed=910), bulb=M.lamp_warm),
                       ppm=160, ground=0.0, ao_dist=0.25,
                       markers=[("weapon_spot", (0.0, 0.06, 1.55), None), ("Light", (0.0, -0.43, 2.14), None)],
                       preview_extra=[("guns", (0.0, 0.0, 1.55), 0.75, -10.0, 5.0)], **view))
    return out
