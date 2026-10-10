"""Lobby kit: the armory's timber ceiling and its props.

  timber_beam_4m   smoked-oak ceiling beam, 0.3 x 0.4 m, 4 m along X,
                   chamfered, with iron straps; origin = top centre on the
                   ceiling plane (hangs down). Tile along a span, beams
                   every 4 m.
  timber_corbel    stepped stone corbel with an oak bolster that carries a
                   beam end at the wall; wall piece, origin on the wall face
                   at the corbel's TOP (= the beam's underside, ceiling -
                   0.4 m).
  weapon_rack      oak wall rack (2 x 2.2 m): three pole arms (halberd,
                   bill, partisan) on pegs, two swords crossed on a round
                   targe. Wall piece, origin on the floor at the wall.
  banner           heraldic banner, 1.2 x 2.6 m with a swallowtail, hung
                   from an iron bracket 0.35 m out from the wall. Wall
                   piece, origin on the wall at the bracket (hang it at
                   4.5-6 m). Texture sets: banner (white crowned eagle on
                   red), banner_lion (gold lion on azure), banner_chevron
                   (red and white chevrons, a black border).
"""
import math

import numpy as np
from mathutils import Matrix

from artlib import arch_materials as A
from artlib import materials as M
from artlib.archkit import kit
from artlib.geo import Part
from artlib.painter import Surface


def beam():
    p = Part("timber_beam_4m")
    p.box((0, 0, -0.2), (4.0, 0.3, 0.4), "timber", bevel=0.035)
    for x in (-1.2, 1.2):
        p.box((x, 0, -0.2), (0.08, 0.32, 0.42), "iron", bevel=0.006)
        for z in (-0.1, -0.3):
            for sy in (-1, 1):
                p.box((x, sy * 0.165, z), (0.03, 0.012, 0.03), "iron", bevel=0.006)
    return p


def corbel():
    p = Part("timber_corbel")
    # steps widen upward, built facing -Y on the wall plane y = 0
    for d, z0, z1, w in ((0.18, -0.6, -0.42, 0.36), (0.3, -0.42, -0.26, 0.42), (0.42, -0.26, -0.12, 0.48)):
        p.box((0, -d / 2, (z0 + z1) / 2), (w, d, z1 - z0), "stone", bevel=0.02)
    p.box((0, -0.3, -0.06), (0.36, 0.6, 0.12), "timber", bevel=0.02)
    return p


def _pole(p, x, top, head):
    p.lathe([(0.022, 0.12), (0.022, top - 0.1)], "shaft", segments=6, cap_bottom=True, cap_top=True,
            center=(x, -0.18, 0.0))
    y = -0.18
    if head == "halberd":
        p.box((x, y, top + 0.05), (0.03, 0.02, 0.35), "steel", bevel=0.004)          # spike
        axe = [(0.0, top - 0.15), (0.22, top - 0.2), (0.26, top - 0.05), (0.22, top + 0.1), (0.0, top + 0.04)]
        f = p.ngon_prism([(x + a, z) for a, z in axe], -0.006, 0.006, "steel")
        p.move(f, Matrix.Translation((0.0, y, 0.0)) @ Matrix.Rotation(math.radians(90), 4, 'X'))
        fluke = [(0.0, top - 0.1), (-0.02, top + 0.0), (-0.12, top - 0.04)]
        f = p.ngon_prism([(x + a, z) for a, z in fluke], -0.005, 0.005, "steel")
        p.move(f, Matrix.Translation((0.0, y, 0.0)) @ Matrix.Rotation(math.radians(90), 4, 'X'))
    elif head == "partisan":
        blade = [(-0.02, top - 0.05), (0.02, top - 0.05), (0.03, top + 0.3), (0.0, top + 0.42), (-0.03, top + 0.3)]
        f = p.ngon_prism([(x + a, z) for a, z in blade], -0.008, 0.008, "steel")
        p.move(f, Matrix.Translation((0.0, y, 0.0)) @ Matrix.Rotation(math.radians(90), 4, 'X'))
        wing = [(-0.16, top - 0.02), (0.16, top - 0.02), (0.02, top + 0.06), (-0.02, top + 0.06)]
        f = p.ngon_prism([(x + a, z) for a, z in wing], -0.006, 0.006, "steel")
        p.move(f, Matrix.Translation((0.0, y, 0.0)) @ Matrix.Rotation(math.radians(90), 4, 'X'))
    else:  # bill: a hooked blade
        blade = [(0.0, top - 0.2), (0.12, top - 0.15), (0.14, top + 0.1), (0.05, top + 0.25), (0.0, top + 0.15)]
        f = p.ngon_prism([(x + a, z) for a, z in blade], -0.007, 0.007, "steel")
        p.move(f, Matrix.Translation((0.0, y, 0.0)) @ Matrix.Rotation(math.radians(90), 4, 'X'))
    p.lathe([(0.03, top - 0.2), (0.03, top - 0.08)], "steel", segments=6, center=(x, y, 0.0))


def rack():
    p = Part("weapon_rack")
    p.box((0, -0.02, 1.2), (2.0, 0.04, 1.9), "oak", bevel=0.012)                 # backboard
    p.box((0, -0.05, 2.18), (2.1, 0.1, 0.08), "oak", bevel=0.015)                # cap rail
    p.box((0, -0.06, 0.22), (2.0, 0.12, 0.08), "oak", bevel=0.015)               # butt rail
    for x in (-0.95, 0.95):
        p.box((x, -0.06, 1.1), (0.1, 0.12, 2.2), "oak", bevel=0.015)             # uprights
    for x, head, top in ((-0.65, "halberd", 2.35), (0.0, "partisan", 2.2), (0.65, "bill", 2.3)):
        _pole(p, x, top, head)
        p.box((x, -0.14, 1.7), (0.1, 0.14, 0.05), "oak", bevel=0.01)             # peg arm
    # a targe with two crossed swords behind it
    targe = p.lathe([(0.0, 0.0), (0.3, 0.0), (0.3, 0.03), (0.2, 0.06), (0.06, 0.08), (0.0, 0.09)], "targe",
                    segments=20)
    p.move(targe, Matrix.Translation((0.0, -0.05, 1.05)) @ Matrix.Rotation(math.radians(90), 4, 'X'))
    boss = p.lathe([(0.0, 0.0), (0.07, 0.0), (0.06, 0.04), (0.0, 0.06)], "steel", segments=10)
    p.move(boss, Matrix.Translation((0.0, -0.13, 1.05)) @ Matrix.Rotation(math.radians(90), 4, 'X'))
    for a in (40.0, -40.0):
        blade = p.box((0, 0, 0), (0.05, 0.012, 0.95), "steel", bevel=0.004)
        guard = p.box((0, 0, -0.5), (0.26, 0.03, 0.03), "steel", bevel=0.006)
        grip = p.box((0, 0, -0.62), (0.03, 0.03, 0.22), "leather", bevel=0.006)
        pommel = p.box((0, 0, -0.75), (0.05, 0.05, 0.05), "steel", bevel=0.012)
        p.move(blade + guard + grip + pommel, Matrix.Translation((0.0, -0.03, 1.05))
               @ Matrix.Rotation(math.radians(a), 4, 'Y') @ Matrix.Translation((0.0, 0.0, 0.1)))
    return p


EAGLE = [
    "..........##..........",
    ".........####.........",
    "........#.##.#........",
    ".........####.........",
    "..........##..#.......",
    "#........####.##.....#",
    "##......######......##",
    "###....########....###",
    "####..##########..####",
    "#######.######.#######",
    ".######.######.######.",
    "..#####.######.#####..",
    "...####.######.####...",
    "....##..######..##....",
    ".......########.......",
    "......###.##.###......",
    ".....##...##...##.....",
    "....##....##....##....",
    "...#.#...####...#.#...",
    "........##..##........",
]
LION = [
    ".....###..............",
    "....#####.............",
    "...###.##.............",
    "...#######............",
    "....#####.....##......",
    "...######....##.......",
    "..########..##........",
    "..#########.#.........",
    "...##########.........",
    "....##########........",
    "....###########.......",
    "....##..######........",
    "...##...##..###.......",
    "..##....##....##......",
    ".##....##......##.....",
    "......##.......#......",
]


def _charge(u, v, sprite, cx, cz, px):
    bmp = np.array([[c == "#" for c in r] for r in sprite], dtype=bool)
    h, w = bmp.shape
    col = np.floor((u - (cx - w * px / 2)) / px).astype(np.int64)
    row = np.floor(((cz + h * px / 2) - v) / px).astype(np.int64)
    ok = (col >= 0) & (col < w) & (row >= 0) & (row < h)
    out = np.zeros(len(u), dtype=bool)
    out[ok] = bmp[row[ok], col[ok]]
    return out


def _banner_fn(kind):
    def fn(ctx):
        u, v = ctx.uvm[:, 0], ctx.uvm[:, 1]
        s = A.paint(ctx, "cloth_red" if kind != "lion" else "azure", 4.2, rough=0.85, chip=0.0,
                    under="cloth_white")
        s.use_ramp(A.P["cloth_red" if kind != "lion" else "azure"],
                   shade=4.0 + ctx.fbm(np.array([2.0, 12.0, 12.0]), 2, 3) * 0.6 + (ctx.rand(4) - 0.5) * 0.6)
        tx = ctx.texel
        border = (np.abs(u) > 0.54) | (v > 2.5)
        if kind == "eagle":
            m = _charge(u, v, EAGLE, 0.0, 1.55, 0.04)
            s.use_ramp(A.P["cloth_white"], mask=m, shade=np.full(ctx.N, 6.5) + (ctx.rand(5) - 0.5))
            crown = m & (v > 1.55 + 0.04 * 6.5)
            s.use_ramp(A.P["gold"], mask=crown, shade=np.full(ctx.N, 7.0))
            s.use_ramp(A.P["gold"], mask=border, shade=np.full(ctx.N, 6.5) + (ctx.rand(6) - 0.5))
        elif kind == "lion":
            m = _charge(u, v, LION, 0.05, 1.55, 0.045)
            s.use_ramp(A.P["gold"], mask=m, shade=np.full(ctx.N, 6.8) + (ctx.rand(5) - 0.5))
            s.use_ramp(A.P["cloth_white"], mask=border, shade=np.full(ctx.N, 6.0))
        else:
            chev = (np.mod(v + np.abs(u) * 0.9, 0.5) < 0.25)
            s.use_ramp(A.P["cloth_white"], mask=chev & ~border, shade=np.full(ctx.N, 6.2) + (ctx.rand(5) - 0.5))
            s.use_ramp(A.P["leather"], mask=border, shade=np.full(ctx.N, 1.5))
        s.shade -= (1.0 - ctx.ao) * 2.0
        s.metal[:] = 0.0
        return s
    return fn


def banner():
    p = Part("banner")
    # bracket: wall plate, arm out 0.35 m, crossbar with finials
    p.box((0, -0.01, 0.0), (0.12, 0.02, 0.22), "iron", bevel=0.005)
    p.box((0, -0.18, 0.0), (0.04, 0.34, 0.04), "iron", bevel=0.008)
    p.tube([(-0.7, -0.35, 0.0), (0.7, -0.35, 0.0)], 0.02, "iron", sides=6)
    for sx in (-1, 1):
        p.lathe([(0.0, -0.03), (0.035, 0.0), (0.0, 0.05)], "gold", segments=8, center=(sx * 0.72, -0.35, -0.01))
    # the cloth: a grid with soft vertical folds and a swallowtail
    W, H = 1.2, 2.6
    nx, nz = 12, 16
    verts = []
    for j in range(nz + 1):
        row = []
        for i in range(nx + 1):
            x = -W / 2 + W * i / nx
            z = -0.06 - H * j / nz
            tail = 0.35 * (1.0 - abs(x) / (W / 2))
            if j == nz:
                z = -0.06 - H + tail
            y = -0.35 + 0.035 * math.sin(i / nx * math.pi * 4.0) * (0.3 + 0.7 * j / nz)
            row.append(p.bm.verts.new((x, y, z)))
        verts.append(row)
    for j in range(nz):
        for i in range(nx):
            quad = [verts[j][i], verts[j][i + 1], verts[j + 1][i + 1], verts[j + 1][i]]
            f = p._face(quad, "cloth", smooth=True)
            f.normal_update()
            if f.normal.y > 0:
                f.normal_flip()
            # UVs: flat metres (u across, v up from the tail tip region)
            for loop in f.loops:
                co = loop.vert.co
                loop[p.uv].uv = (co.x, co.z + H + 0.06)
            f[p.lock] = 1
    # back side of the cloth (its own vertices 3 mm behind, facing the wall)
    back = [[p.bm.verts.new((v.co.x, v.co.y + 0.003, v.co.z)) for v in row] for row in verts]
    for j in range(nz):
        for i in range(nx):
            quad = [back[j][i], back[j + 1][i], back[j + 1][i + 1], back[j][i + 1]]
            f = p._face(quad, "cloth_back", smooth=True)
            f.normal_update()
            if f.normal.y < 0:
                f.normal_flip()
    return p


def build():
    stone = lambda c: A.limestone(c, center=5.4)
    out = [kit("timber_beam_4m", [beam()], {"timber": A.timber, "iron": M.iron}, built_final=True, ground=None,
               ceiling=0.0, ao_dist=0.3),
           kit("timber_corbel", [corbel()], {"stone": stone, "timber": A.timber}, wall=True, ground=None,
               ceiling=0.0, ao_dist=0.3, preview=False),
           kit("weapon_rack", [rack()], {"oak": A.timber, "shaft": M.wood_oak, "steel": M.steel,
                                         "leather": M.leather,
                                         "targe": lambda c: M.paint(c, "cloth_red", 4.0)},
               ppm=128, wall=True, ao_dist=0.2)]
    cloth_back = lambda c: A.paint(c, "cloth_white", 3.5, rough=0.9, chip=0.0, under="cloth_white")
    out.append(kit("banner", [banner()], {"iron": M.iron, "gold": M.gold, "cloth": _banner_fn("eagle"),
                                          "cloth_back": cloth_back},
                   ppm=64, wall=True, ground=None, ao_dist=0.3,
                   variants={"banner_lion": {"iron": M.iron, "gold": M.gold, "cloth": _banner_fn("lion"),
                                             "cloth_back": cloth_back},
                             "banner_chevron": {"iron": M.iron, "gold": M.gold, "cloth": _banner_fn("chevron"),
                                                "cloth_back": cloth_back}}))
    return out
