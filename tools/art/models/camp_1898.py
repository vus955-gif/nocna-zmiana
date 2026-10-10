"""The 1898 expedition camp in the middle of the Great Gallery (the shotgun
waits here, lit and visible from the entrance). Kit convention: origin =
centre of the base on the floor, front = Godot -Z (Blender +Y, built final).

  camp_tent        ridge tent 3.2 x 2.4 x 2.6 m of sun-bleached canvas, the
                   front flaps tied back, poles, guy ropes to pegs; a camp
                   bed inside. Marker LampHook (under the ridge, front: hang
                   a camp_lamp there). 96 px/m.
  camp_crate       pine crate 0.9 x 0.6 x 0.6 m, rope handles, stencils
                   "EKSPEDYCJA 1898 / TEBY" and an arrow "GÓRA"; texture
                   set camp_crate_b: "OSTROŻNIE / NIE RZUCAĆ" and "MUZEUM".
  camp_crate_long  long tool crate 1.6 x 0.45 x 0.5 m, "NARZĘDZIA".
  camp_crate_open  an unpacked crate: the lid leaning on it, straw spilling,
                   a small statuette of Bastet looking out.
  camp_lamp        hurricane oil lamp 0.37 m: tank, glass globe (part
                   camp_lamp_glass), wire guards, bail; the flame emissive.
                   Marker Light at the flame. 256 px/m.
  camp_table       folding field table 1.4 x 0.76 x 0.8 m: an open map of the
                   Theban bank (TEBY, KARNAK, LUKSOR), rolled maps, a pith
                   helmet, a notebook, a brass compass, a tin mug. 128 px/m.
  camp_rifle_rack  A-frame gun rack 1.5 x 1.35 x 0.7 m with two old rifles and
                   an empty middle cradle - marker weapon_spot (the shotgun
                   pickup's place, on the cradle) - and a cartridge box
                   "NABOJE" at its foot. 128 px/m.
  camp_chair       folding campaign chair, canvas sling. 128 px/m.
"""
import math
import random

import numpy as np
from mathutils import Matrix, Vector

from artlib import egypt as E
from artlib import egypt_paint as EP
from artlib import kit as K
from artlib import materials as M
from artlib import pixelfont
from artlib.archkit import cull_floor, kit
from artlib.geo import Part
from artlib.materials import P, _dither, _wood_core, smoothstep
from artlib.painter import Surface


# --------------------------------------------------------------------------
# shared materials
# --------------------------------------------------------------------------

def pine(ctx, seed=1601, center=5.6):
    s = _wood_core(ctx, P["pine_worn"], center, seed, ring_freq=9.0)
    s.shade += ctx.edge(1.0) * 1.2
    s.shade -= ctx.cavity(3.0) * 1.6 + (1.0 - ctx.ao) * 3.0
    s.rough = np.full(ctx.N, 0.85)
    return s


def oak(ctx, seed=1603):
    s = _wood_core(ctx, P["wood_oak"], 4.4, seed, ring_freq=8.0)
    s.shade += ctx.edge(1.0) * 1.2
    s.shade -= ctx.cavity(3.0) * 1.6 + (1.0 - ctx.ao) * 3.0
    s.rough = np.full(ctx.N, 0.55)
    return s


def rope(ctx, seed=1605):
    s = Surface(ctx.N)
    ix, iy = E.px(ctx)
    twist = np.mod(ix + iy, 4) < 2
    s.use_ramp(P["straw"], shade=3.2 + twist * 1.0 + _dither(ctx, 0.6, seed) - (1.0 - ctx.ao) * 2.0)
    s.rough = np.full(ctx.N, 0.95)
    return s


_TXT = {}


def _text(lines, bold=True):
    key = (tuple(lines), bold)
    if key not in _TXT:
        _TXT[key] = pixelfont.trim(pixelfont.render(lines, line_gap=2, bold=bold))
    return _TXT[key]


def stencil(front_lines, side_lines, ink="eg_black", scale=2):
    """Pine boards with stencilled words on the front (+Y) and the sides."""
    def fn(ctx, seed=1607):
        s = pine(ctx, seed)
        u, v = ctx.uvm[:, 0], ctx.uvm[:, 1]
        for mask, lines in ((ctx.n[:, 1] > 0.9, front_lines), (np.abs(ctx.n[:, 0]) > 0.9, side_lines)):
            if not lines or not mask.any():
                continue
            cu, cv = np.median(u[mask]), np.median(v[mask])
            ink_m = pixelfont.stamp(ctx, _text(lines), cu, cv, scale=scale) & mask
            worn = ctx.fbm(14.0, 2, seed + 3) > 0.35
            s.use_ramp(P[ink], mask=ink_m & ~worn, shade=np.full(ctx.N, 1.4) + _dither(ctx, 0.6, seed + 4))
        return s
    return fn


# --------------------------------------------------------------------------
# crates
# --------------------------------------------------------------------------

def crate(name, L, Wd, H, open_=False):
    p = Part(name)
    t = 0.02
    if open_:
        p.box((0.0, 0.0, 0.02), (L, Wd, 0.04), "boards", bevel=0.005)
        for sy in (-1, 1):
            p.box((0.0, sy * (Wd / 2 - t / 2), H / 2), (L, t, H), "boards", bevel=0.004)
        for sx in (-1, 1):
            p.box((sx * (L / 2 - t / 2), 0.0, H / 2), (t, Wd - 2 * t, H), "boards", bevel=0.004)
    else:
        p.box((0.0, 0.0, H / 2), (L, Wd, H), "boards", bevel=0.006)
    # battens round the edges
    for sy in (-1, 1):
        for z in (0.04, H - 0.04):
            p.box((0.0, sy * (Wd / 2 + 0.008), z), (L, 0.016, 0.07), "batten", bevel=0.003)
        for sx in (-1, 1):
            p.box((sx * (L / 2 - 0.035), sy * (Wd / 2 + 0.008), H / 2), (0.07, 0.016, H - 0.15), "batten", bevel=0.003)
    for sx in (-1, 1):
        p.tube([(sx * (L / 2 + 0.01), -0.1, H * 0.62), (sx * (L / 2 + 0.05), -0.06, H * 0.55),
                (sx * (L / 2 + 0.05), 0.06, H * 0.55), (sx * (L / 2 + 0.01), 0.1, H * 0.62)], 0.012, "rope", sides=5)
    cull_floor([p])
    return p


def crate_open():
    p = crate("camp_crate_open", 0.9, 0.6, 0.6, open_=True)
    # straw heaped inside and spilling over one side
    rng = random.Random(4)
    for k in range(9):
        x, y = rng.uniform(-0.35, 0.35), rng.uniform(-0.22, 0.22)
        K.sphere(p, (x, y, 0.5 + rng.uniform(-0.04, 0.04)), rng.uniform(0.09, 0.14), "straw", segments=7, rings=4,
                 squash=(1.3, 1.0), zscale=0.45)
    for k in range(4):
        K.sphere(p, (rng.uniform(-0.3, 0.3), 0.36 + rng.uniform(0.0, 0.1), 0.03), rng.uniform(0.07, 0.11), "straw",
                 segments=6, rings=3, squash=(1.4, 1.0), zscale=0.35)
    # a seated cat (Bastet) in bronze looking out of the straw
    K.sphere(p, (0.1, 0.0, 0.62), 0.07, "bronze", segments=8, rings=5, squash=(0.8, 1.0), zscale=1.4)
    K.sphere(p, (0.1, 0.03, 0.74), 0.045, "bronze", segments=8, rings=5)
    for sx in (-1, 1):
        K.cone(p, (0.1 + sx * 0.022, 0.03, 0.77), (sx * 0.2, 0.0, 1.0), 0.035, 0.014, "bronze", segments=4)
    # the lid leaning on the front
    lid = p.box((0.0, 0.0, 0.0), (0.92, 0.02, 0.62), "lid", bevel=0.004)
    p.move(lid, Matrix.Translation((0.0, 0.42, 0.3)) @ Matrix.Rotation(math.radians(-14), 4, 'X'))
    return p


# --------------------------------------------------------------------------
# tent
# --------------------------------------------------------------------------

TL, TW, TH, WALL = 3.2, 2.4, 2.6, 0.7


def _sheet(p, corners, nu, nv, slot, sag=0.0, both=True, sag_dir=None, inside=(0.0, 0.0, 1.0)):
    """A canvas panel: grid between four corners (a, b, c, d), sagging along
    ``sag_dir`` in the middle; two-sided (inner faces in slot + '_in')."""
    a, b, c, d = (Vector(q) for q in corners)
    grid = []
    for j in range(nv + 1):
        row = []
        for i in range(nu + 1):
            u, v = i / nu, j / nv
            q = a.lerp(b, u).lerp(d.lerp(c, u), v)
            if sag:
                q = q + Vector(sag_dir) * sag * math.sin(math.pi * u) * math.sin(math.pi * v)
            row.append(q)
        grid.append(row)
    inner = Vector(inside)
    for layer, s_name in ((0, slot), (1, slot + "_in")):
        if layer == 1 and not both:
            continue
        if layer == 0:
            vs = [[p.bm.verts.new(q) for q in row] for row in grid]
        else:
            vs = [[p.bm.verts.new(q + (inner - q).normalized() * 0.012) for q in row] for row in grid]
        for j in range(nv):
            for i in range(nu):
                quad = [vs[j][i], vs[j][i + 1], vs[j + 1][i + 1], vs[j + 1][i]]
                f = p._face(quad, s_name, smooth=True)
                f.normal_update()
                out = f.calc_center_median() - inner
                if (f.normal.dot(out) < 0) != (layer == 1):
                    f.normal_flip()
    return grid


def tent():
    p = Part("camp_tent")
    hx, hy = TL / 2, TW / 2
    # roof: two slopes from the eaves (WALL) to the ridge, sagging between the poles
    for sy in (-1, 1):
        _sheet(p, [(-hx, sy * hy, WALL), (hx, sy * hy, WALL), (hx, 0.0, TH), (-hx, 0.0, TH)], 6, 4, "canvas",
               sag=0.08, sag_dir=(0.0, -sy * 0.3, -1.0))
        # side walls
        _sheet(p, [(-hx, sy * hy, 0.0), (hx, sy * hy, 0.0), (hx, sy * hy, WALL), (-hx, sy * hy, WALL)], 6, 1, "canvas",
               sag=0.03, sag_dir=(0.0, -sy, 0.0))
    # back wall: a gable
    back = [(-hx, -hy, 0.0), (-hx, hy, 0.0), (-hx, hy, WALL), (-hx, 0.0, TH), (-hx, -hy, WALL)]
    for layer, slot in ((0, "canvas"), (1, "canvas_in")):
        vs = [p.bm.verts.new((q[0] + 0.012 * layer, q[1], q[2])) for q in back]
        f = p._face(vs if layer == 0 else list(reversed(vs)), slot)
        f.normal_update()
        if (f.normal.x > 0) != (layer == 1):
            f.normal_flip()
    # front: the flaps tied back to the sides, a strip of gable over the door
    for sy in (-1, 1):
        _sheet(p, [(hx, sy * hy, 0.0), (hx + 0.25, sy * (hy + 0.15), 0.0), (hx + 0.12, sy * 0.55, TH * 0.72),
                   (hx, sy * 0.25, TH * 0.85)], 2, 3, "canvas", sag=0.05, sag_dir=(0.3, 0.0, 0.0))
        p.tube([(hx + 0.2, sy * (hy + 0.05), 0.9), (hx + 0.24, sy * (hy + 0.1), 1.0)], 0.03, "canvas", sides=6)
    # poles, ridge
    for x in (-hx + 0.05, hx - 0.05):
        p.tube([(x, 0.0, 0.0), (x, 0.0, TH + 0.12)], 0.035, "pole", sides=6)
    p.tube([(-hx - 0.12, 0.0, TH + 0.02), (hx + 0.12, 0.0, TH + 0.02)], 0.03, "pole", sides=6)
    # guy ropes and pegs
    for x in (-hx + 0.3, 0.0, hx - 0.3):
        for sy in (-1, 1):
            a = (x, sy * hy, WALL + 0.02)
            b = (x, sy * (hy + 0.9), 0.04)
            p.tube([a, b], 0.008, "rope", sides=4, smooth=False)
            p.box((x, sy * (hy + 0.92), 0.06), (0.04, 0.03, 0.14), "pole", bevel=0.005)
    # a camp bed inside, along the back
    p.box((-0.6, 0.0, 0.42), (1.0, 1.9, 0.08), "canvas", bevel=0.01)
    for sx in (-1, 1):
        for sy in (-1, 1):
            p.tube([(-0.6 + sx * 0.4, sy * 0.85, 0.0), (-0.6 + sx * 0.4, sy * 0.85, 0.4)], 0.02, "pole", sides=5)
    p.box((-0.6, -0.45, 0.5), (0.9, 0.6, 0.08), "blanket", bevel=0.02)
    # the tent is long along X: turn it so the door looks at the visitor (+Y)
    p.move(list(p.bm.faces), Matrix.Rotation(math.radians(90), 4, 'Z'))
    return p


def canvas_in(ctx, seed=1611):
    s = E.canvas_cloth(ctx, seed, center=4.0)
    return s


def blanket(ctx, seed=1613):
    s = Surface(ctx.N)
    ix, iy = E.px(ctx)
    stripe = np.mod(iy, 16) < 3
    s.use_ramp(P["cloth_red"], shade=3.4 + stripe * 2.0 + _dither(ctx, 0.5, seed) - (1.0 - ctx.ao) * 2.5)
    s.rough = np.full(ctx.N, 0.95)
    return s


# --------------------------------------------------------------------------
# lamp
# --------------------------------------------------------------------------

def lamp():
    p = Part("camp_lamp")
    p.lathe([(0.075, 0.0), (0.085, 0.01), (0.085, 0.06), (0.07, 0.085), (0.04, 0.095), (0.035, 0.105)], "tin",
            segments=14, cap_bottom=True, cap_top=True)
    p.lathe([(0.03, 0.105), (0.03, 0.12), (0.045, 0.125)], "brass", segments=10, cap_bottom=False, cap_top=False)
    # wire guards round the globe
    for k in range(4):
        a = math.tau * k / 4 + 0.4
        pts = [(math.cos(a) * r, math.sin(a) * r, z) for r, z in ((0.05, 0.12), (0.072, 0.17), (0.072, 0.25), (0.05, 0.29))]
        p.tube(pts, 0.004, "tin", sides=4, smooth=False)
    p.lathe([(0.052, 0.29), (0.06, 0.3), (0.05, 0.32), (0.025, 0.335), (0.02, 0.345)], "tin", segments=12,
            cap_bottom=True, cap_top=True)
    # bail handle
    pts = [(0.075 * math.cos(a), 0.0, 0.3 + 0.07 * math.sin(a)) for a in np.linspace(0.0, math.pi, 9)]
    p.tube(pts, 0.004, "tin", sides=4, smooth=False)
    # the flame
    f = p.lathe([(0.0, 0.14), (0.012, 0.15), (0.014, 0.165), (0.008, 0.185), (0.0, 0.2)], "flame", segments=8)
    g = Part("camp_lamp_glass")
    g.lathe([(0.04, 0.125), (0.062, 0.16), (0.066, 0.21), (0.055, 0.27), (0.045, 0.29)], "glass", segments=14,
            cap_bottom=False, cap_top=False)
    return [p, g]


# --------------------------------------------------------------------------
# table
# --------------------------------------------------------------------------

def table():
    p = Part("camp_table")
    TLn, TWd, H = 1.4, 0.8, 0.76
    for k in range(5):
        y = -TWd / 2 + (k + 0.5) * TWd / 5
        p.box((0.0, y, H - 0.015), (TLn, TWd / 5 - 0.006, 0.03), "oak", bevel=0.004)
    p.box((0.0, 0.0, H - 0.05), (TLn - 0.1, TWd - 0.1, 0.04), "oak", bevel=0.003)
    for sx in (-1, 1):
        x = sx * (TLn / 2 - 0.15)
        for sy in (-1, 1):
            p.tube([(x, sy * 0.33, 0.0), (x, -sy * 0.33, H - 0.07)], 0.02, "oak", sides=6, smooth=False)
        p.tube([(x, 0.0, 0.0 + 0.36), (x, 0.0, 0.36)], 0.01, "brass", sides=5)
    # the open map, two rolled maps, a notebook, the compass, a mug, a pith helmet
    p.box((-0.12, 0.02, H + 0.002), (0.72, 0.52, 0.004), "map")
    for k, (x, ln) in enumerate(((0.45, 0.6), (0.38, 0.5))):
        K.seg(p, (x - 0.06 * k, -0.25 - ln / 2 * 0 + 0.0, H + 0.035), (x - 0.06 * k + 0.05, 0.3 - 0.1 * k, H + 0.035),
              [(0.032, 0.0), (0.032, 1.0)], "paper", segments=10)
    p.box((0.42, 0.25, H + 0.012), (0.18, 0.24, 0.024), "book", bevel=0.003)
    K.seg(p, (0.25, -0.28, H), (0.25, -0.28, H + 0.018), [(0.04, 0.0), (0.04, 1.0)], "brass", segments=12)
    K.seg(p, (-0.58, -0.3, H), (-0.58, -0.3, H + 0.09), [(0.04, 0.0), (0.042, 1.0)], "tin", segments=12)
    helmet = p.lathe([(0.17, 0.0), (0.16, 0.01), (0.115, 0.02), (0.11, 0.08), (0.09, 0.13), (0.05, 0.16),
                      (0.015, 0.17), (0.0, 0.172)], "helmet", segments=16, squash=(1.0, 1.15), cap_bottom=True)
    p.move(helmet, Matrix.Translation((-0.5, 0.18, H + 0.005)))
    return p


_MAP = {}


def map_paint(ctx, seed=1621):
    """A hand-drawn survey map: paper, the Nile in blue with its green banks,
    the temple sites in red, names in ink."""
    s = E.paper(ctx, seed, center=5.0)
    top = ctx.n[:, 2] > 0.9
    x, y = ctx.p[:, 0], ctx.p[:, 1]
    river = top & (np.abs(x + 0.12 - 0.12 * np.sin(y * 7.0) - 0.04) < 0.035)
    bank = top & (np.abs(x + 0.12 - 0.12 * np.sin(y * 7.0) - 0.04) < 0.07) & ~river
    s.use_ramp(P["eg_blue"], mask=river, shade=np.full(ctx.N, 4.2))
    s.use_ramp(P["eg_green"], mask=bank, shade=np.full(ctx.N, 4.0) + _dither(ctx, 0.6, seed + 1))
    for cx, cy in ((-0.3, 0.12), (-0.28, -0.1), (0.1, 0.05)):
        site = top & (np.abs(x - cx) < 0.015) & (np.abs(y - cy) < 0.015)
        s.use_ramp(P["eg_red"], mask=site, shade=np.full(ctx.N, 4.0))
    u, v = ctx.uvm[:, 0], ctx.uvm[:, 1]
    for word, cx, cy in (("TEBY", -0.3, 0.17), ("KARNAK", -0.28, -0.05), ("LUKSOR", 0.12, 0.1)):
        if word not in _MAP:
            _MAP[word] = pixelfont.trim(pixelfont.render(word))
        ink = pixelfont.stamp(ctx, _MAP[word], -cx, -cy, scale=1, u=-x, v=-y) & top
        s.use_ramp(P["eg_black"], mask=ink, shade=np.full(ctx.N, 1.2))
    grid = top & ((np.mod(np.floor(x / ctx.texel), 13) == 0) | (np.mod(np.floor(y / ctx.texel), 13) == 0))
    s.shade[grid] -= 0.5
    return s


def book(ctx, seed=1623):
    s = M.leather(ctx, seed)
    side = np.abs(ctx.n[:, 2]) < 0.5
    s.use_ramp(P["paper"], mask=side & (ctx.p[:, 1] > 0.24), shade=np.full(ctx.N, 4.6))
    return s


def helmet(ctx, seed=1625):
    s = E.canvas_cloth(ctx, seed, center=6.6, stains=0.6)
    band = (ctx.p[:, 2] > 0.76 + 0.075) & (ctx.p[:, 2] < 0.76 + 0.095)
    s.use_ramp(P["leather"], mask=band, shade=np.full(ctx.N, 3.5))
    return s


# --------------------------------------------------------------------------
# rifle rack
# --------------------------------------------------------------------------

def _rifle(p, x, lean=8.0):
    """An old single-shot rifle standing butt-down, leaning back."""
    m = Matrix.Translation((x, 0.0, 0.12)) @ Matrix.Rotation(math.radians(-lean), 4, 'X')
    f = []
    f += p.box((0.0, 0.0, 0.18), (0.045, 0.11, 0.36), "stock", bevel=0.01)
    f += p.box((0.0, 0.02, 0.55), (0.04, 0.05, 0.4), "stock", bevel=0.008)
    f += K.seg(p, (0.0, 0.03, 0.72), (0.0, 0.03, 1.18), [(0.012, 0.0), (0.01, 1.0)], "barrel", segments=6)
    f += p.box((0.0, 0.035, 0.42), (0.03, 0.06, 0.08), "barrel", bevel=0.004)
    p.move(f, m)


def rack():
    p = Part("camp_rifle_rack")
    W = 1.5
    # base board and the A-frame with a notched top rail
    p.box((0.0, 0.0, 0.03), (W, 0.6, 0.06), "oak", bevel=0.006)
    for sx in (-1, 1):
        for sy in (-1, 1):
            p.tube([(sx * (W / 2 - 0.05), sy * 0.26, 0.06), (sx * (W / 2 - 0.05), 0.0, 1.3)], 0.025, "oak", sides=6,
                   smooth=False)
    p.box((0.0, -0.03, 1.12), (W, 0.07, 0.07), "oak", bevel=0.008)
    p.box((0.0, 0.1, 0.16), (W - 0.1, 0.08, 0.06), "oak", bevel=0.006)
    for x in (-0.45, 0.0, 0.45):
        p.box((x, 0.03, 1.16), (0.12, 0.03, 0.04), "felt", bevel=0.004)
    _rifle(p, -0.45)
    _rifle(p, 0.45, lean=9.0)
    # the empty middle cradle: a felt-lined fork on a post
    p.tube([(0.0, 0.22, 0.06), (0.0, 0.22, 0.86)], 0.02, "oak", sides=6)
    p.box((0.0, 0.22, 0.88), (0.24, 0.06, 0.04), "felt", bevel=0.004)
    for sx in (-1, 1):
        p.box((sx * 0.11, 0.22, 0.93), (0.025, 0.06, 0.1), "oak", bevel=0.004)
    # cartridge box at the foot
    p.box((0.42, 0.42, 0.11), (0.3, 0.2, 0.22), "ammo", bevel=0.008)
    cull_floor([p])
    return p


def chair():
    p = Part("camp_chair")
    for sx in (-1, 1):
        p.tube([(sx * 0.26, -0.25, 0.0), (sx * 0.26, 0.22, 0.45)], 0.018, "oak", sides=6, smooth=False)
        p.tube([(sx * 0.26, 0.25, 0.0), (sx * 0.26, -0.25, 0.85)], 0.018, "oak", sides=6, smooth=False)
        p.tube([(sx * 0.26, 0.22, 0.45), (sx * 0.26, -0.05, 0.62)], 0.016, "oak", sides=6, smooth=False)
    for y, z in ((0.22, 0.45), (-0.25, 0.85)):
        p.tube([(-0.27, y, z), (0.27, y, z)], 0.016, "oak", sides=6)
    _sheet(p, [(-0.24, 0.2, 0.44), (0.24, 0.2, 0.44), (0.24, -0.2, 0.8), (-0.24, -0.2, 0.8)], 3, 4, "canvas", sag=0.07,
           sag_dir=(0.0, 0.5, -1.0), inside=(0.0, 0.6, 1.4))
    return p


def ammo(ctx, seed=1631):
    s = M.paint(ctx, "paint_olive", 4.6, seed, under="wood_dark")
    front = ctx.n[:, 1] > 0.9
    if front.any():
        cu, cv = np.median(ctx.uvm[front, 0]), np.median(ctx.uvm[front, 1])
        ink = pixelfont.stamp(ctx, _text(["NABOJE"]), cu, cv, scale=1) & front
        s.use_ramp(P["paint_cream"], mask=ink, shade=np.full(ctx.N, 5.0))
    return s


def build():
    crate_fns = {"boards": stencil(["EKSPEDYCJA 1898", "TEBY"], ["GÓRA"]), "batten": lambda c: pine(c, 1641, 4.6),
                 "rope": rope}
    crate_b = {"boards": stencil(["OSTROŻNIE", "NIE RZUCAĆ"], ["MUZEUM"], ink="enamel_red"),
               "batten": lambda c: pine(c, 1641, 4.6), "rope": rope}
    long_fns = {"boards": stencil(["NARZĘDZIA"], ["EKSP. 1898"]), "batten": lambda c: pine(c, 1643, 4.6), "rope": rope}
    open_fns = {"boards": lambda c: pine(c, 1645), "batten": lambda c: pine(c, 1647, 4.6), "rope": rope,
                "straw": lambda c: _straw(c), "bronze": M.bronze,
                "lid": stencil(["EKSPEDYCJA 1898"], [])}
    lamp_fns = {"tin": lambda c: M.paint(c, "paint_red", 3.6, 1651, under="iron", chip=1.4), "brass": M.brass,
                "flame": lambda c: E.glow(c, "flame", 5.0, 1.2, 1653)}
    return [
        kit("camp_tent", [tent()], {"canvas": E.canvas_cloth, "canvas_in": canvas_in, "pole": oak, "rope": rope,
                                    "blanket": blanket},
            ppm=96, built_final=True, ao_dist=0.4, markers=[("LampHook", (0.0, 1.45, 2.45), None)]),
        kit("camp_crate", [crate("camp_crate", 0.9, 0.6, 0.6)], crate_fns, ppm=128, built_final=True, ao_dist=0.2,
            variants={"camp_crate_b": crate_b}),
        kit("camp_crate_long", [crate("camp_crate_long", 1.6, 0.45, 0.5)], long_fns, ppm=128, built_final=True,
            ao_dist=0.2),
        kit("camp_crate_open", [crate_open()], open_fns, ppm=128, built_final=True, ao_dist=0.2),
        kit("camp_lamp", lamp(), lamp_fns, kinds={"glass": "glass"}, ppm=256, built_final=True, ao_dist=0.05,
            markers=[("Light", (0.0, 0.0, 0.17), None)]),
        kit("camp_table", [table()], {"oak": oak, "brass": M.brass, "map": map_paint, "paper": lambda c: E.paper(c, 1661, 5.4),
                                      "book": book, "tin": lambda c: M.enamel(c, "enamel_white", 5.4, 1663),
                                      "helmet": helmet}, ppm=128, built_final=True, ao_dist=0.15),
        kit("camp_rifle_rack", [rack()], {"oak": oak, "felt": lambda c: M.velvet(c, 1671), "stock": M.walnut_stock,
                                          "barrel": M.gun_steel, "ammo": ammo},
            ppm=128, built_final=True, ao_dist=0.2, markers=[("weapon_spot", (0.0, 0.22, 0.92), None)]),
        kit("camp_chair", [chair()], {"oak": oak, "canvas": E.canvas_cloth, "canvas_in": canvas_in}, ppm=128,
            built_final=True, ao_dist=0.15),
    ]


def _straw(ctx, seed=1681):
    s = Surface(ctx.N)
    strand = ctx.fbm(np.array([40.0, 40.0, 8.0]), 2, seed)
    s.use_ramp(P["excelsior"], shade=3.6 + strand * 1.6 + _dither(ctx, 1.0, seed + 1) - (1.0 - ctx.ao) * 3.0)
    s.rough = np.full(ctx.N, 0.95)
    s.height = strand * 0.002
    return s
