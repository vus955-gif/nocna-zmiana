"""Floor I, Asia wing kit: gates, door frames, lattice and shoji, the
garden wall's tiled coping.

  asia_moon_gate_4m     a moon gate (yuedong men) dressing a 4 x 4 m opening:
                        a round opening 4 m across (cut flat 0.35 m above the
                        floor, so the walkway is 2.26 m wide at the floor),
                        a grey-brick ring round it on a lime-white panel 4.6 x
                        4.35 m on both faces, a moulded stone lip, a stone
                        lining through the wall, a stone plaque above
                        carved 山水 ("mountains and waters", the landscape).
                        One face (ArtKit.passage puts one per room face, as
                        frame_4: openings 4 x 4.5; the 4 x 4 Korea - armour
                        passage takes it by hand). Origin = centre of the
                        floor of the opening on the wall face; the lining runs
                        0.25 m (half a 0.5 m wall) into the wall (+Z). The
                        panel covers the corners of the 4 x 4(.5) rectangle
                        (they need collision boxes if the greybox leaves them
                        open).
  asia_doorframe_2x2_6  a Chinese door frame for a 2 x 2.6 m opening: red
                        lacquer posts and lintel on both faces, a fretwork
                        valance (gualuo) and carved corner brackets under the
                        lintel (2.32 m clear), lacquer lining, a stone sill.
                        One face, lining 0.25 m, as the moon gate (frame_2_6).
  asia_lattice_window   a false window 1.6 x 1.8 m on a wall: a cinnabar frame
                        round a cracked-ice lattice (bingliewen) over paper.
                        Origin = bottom centre on the wall face (hang it at
                        0.9-1.2 m). Texture set asia_lattice_window_lit: the
                        paper glows warm (a lamp behind it).
  asia_shoji_2m         a pair of shoji panels 2 x 2.1 m on a wall (hinoki
                        frame, kumiko grid, washi, a kick board), with the
                        lintel and sill tracks. Origin = bottom centre on
                        the wall face. Texture set asia_shoji_2m_lit.
  asia_wallcap_4m/2m/1m the garden wall's coping: a lean-to of grey roof tiles
                        (rolled rows, end discs on the eave) on a timber
                        plate, projecting 0.55 m. Datum = the top of the
                        earthen wall (3.0 m in the garden style); wall
                        plane z = 0.
"""
import math
import random

import bmesh
import numpy as np
from mathutils import Matrix, Vector

from artlib import asia as A
from artlib import asia_paint as AP
from artlib import egypt as E
from artlib import materials as M
from artlib.archkit import front_prism, kit
from artlib.asia_geo import ccw, cull_back
from artlib.geo import Part
from artlib.kit import R, T
from artlib.materials import P, _dither
from artlib.painter import Surface

I = AP.INK
WALL = 0.5
HALF = WALL / 2      # each room's frame lines half the wall (ArtKit.passage puts one per face)


# --------------------------------------------------------------------------
# moon gate
# --------------------------------------------------------------------------

MG_R, MG_C, MG_CUT = 2.0, 2.0, 0.35
MG_W, MG_TOP = 2.3, 4.35


def moon_contour(n=44):
    xc = math.sqrt(MG_R ** 2 - (MG_C - MG_CUT) ** 2)
    a0 = math.atan2(MG_CUT - MG_C, xc)
    a1 = math.pi - a0
    # uniform samples plus the two angles whose rays meet the panel's top
    # corners exactly (the surround then closes without gaps)
    corner = math.atan2(MG_TOP - MG_C, MG_W)
    angles = sorted(set([a0 + (a1 - a0) * k / n for k in range(n + 1)] + [corner, math.pi - corner]))
    pts = [(xc, 0.0)]
    for a in angles:
        pts.append((MG_R * math.cos(a), MG_C + MG_R * math.sin(a)))
    pts.append((-xc, 0.0))
    return pts


def _outer(x, z):
    if z < MG_C:
        return (math.copysign(MG_W, x if abs(x) > 1e-6 else 1.0), z)
    dx, dz = x, z - MG_C
    ts = []
    if abs(dx) > 1e-6:
        ts.append(MG_W / abs(dx))
    if dz > 1e-6:
        ts.append((MG_TOP - MG_C) / dz)
    t = min(ts)
    return (dx * t, MG_C + dz * t)


def _panel(p, cont, y, facing):
    """The surround panel at depth y, its faces turned to ``facing`` (+-1 in y)."""
    vs_in = [p.bm.verts.new((x, y, z)) for x, z in cont]
    outs = [_outer(x, z) for x, z in cont]
    vs_out = [p.bm.verts.new((x, y, z)) for x, z in outs]
    faces = []
    for i in range(len(cont) - 1):
        f = p._face([vs_in[i], vs_in[i + 1], vs_out[i + 1], vs_out[i]], "panel")
        f.normal_update()
        if f.normal.y * facing < 0:
            f.normal_flip()
        faces.append(f)
    return faces


def moon_gate():
    p = Part("asia_moon_gate_4m")
    cont = moon_contour()
    d = 0.04
    _panel(p, cont, -d, -1)
    # panel edges (the 4 cm thickness round the outside)
    for sx in (-1, 1):
        p.box((sx * MG_W, -d / 2, MG_TOP / 2), (0.002, d, MG_TOP), "panel")
    p.box((0.0, -d / 2, MG_TOP), (2 * MG_W, d, 0.002), "panel")
    # coping on top of the panel: a small stone cornice
    p.box((0.0, -d - 0.03, MG_TOP + 0.05), (2 * MG_W + 0.16, 0.08, 0.1), "stone", bevel=0.015)
    # lining through half the wall
    for i in range(len(cont) - 1):
        (x0, z0), (x1, z1) = cont[i], cont[i + 1]
        if z0 < 1e-6 and z1 < 1e-6:
            continue
        a = p.bm.verts.new((x0, -d, z0))
        b = p.bm.verts.new((x1, -d, z1))
        c = p.bm.verts.new((x1, HALF, z1))
        e = p.bm.verts.new((x0, HALF, z0))
        f = p._face([a, b, c, e], "stone")
        f.normal_update()
        mid = Vector(((x0 + x1) / 2, 0.0, (z0 + z1) / 2))
        inward = Vector((0.0, 0.0, MG_C)) - mid
        if mid.z < MG_CUT + 1e-3:
            inward = Vector((-mid.x, 0.0, 0.0))
        if f.normal.dot(inward) < 0:
            f.normal_flip()
    # the moulded lip round the opening, both faces
    prof = [(0.0, -0.16), (0.035, -0.14), (0.055, -0.09), (0.04, -0.035), (0.0, 0.0)]
    p.sweep(prof, cont, "stone", y0=-d)
    # plaque over the gate (front face only)
    p.box((0.0, -d - 0.04, 3.82), (1.0, 0.08, 0.46), "plaque", bevel=0.02)
    p.box((0.0, -d - 0.02, 3.82), (1.12, 0.04, 0.58), "stone", bevel=0.012)
    return p


_PLAQUE = {}


def _plaque_canvas():
    """山水 carved in a 64 x 29 px plaque (1 x 0.46 m), right to left."""
    if "c" not in _PLAQUE:
        c = AP.blank(64, 29)
        AP.brush(c, AP.CHARACTERS["水"], 6, 3, 23, seed=5, dry=0.2, weight=1.4)
        AP.brush(c, AP.CHARACTERS["山"], 35, 3, 23, seed=6, dry=0.2, weight=1.4)
        _PLAQUE["c"] = c
    return _PLAQUE["c"]


def gate_stone(ctx, seed=1401, center=5.4):
    s = A.garden_stone(ctx, seed, moss=0.0, lichen=0.3, center=center)
    s.rough = np.full(ctx.N, 0.8)
    return s


def plaque_paint(ctx, seed=1403):
    s = gate_stone(ctx, seed, 5.8)
    front = ctx.n[:, 1] > 0.8                        # the turned model's front is +y
    u = -ctx.p[:, 0] + 0.5                            # seen from the front, x runs right to left after the turn
    v = ctx.p[:, 2] - (3.82 - 0.23)
    codes, rims = E.sample(_plaque_canvas(), u, v, ctx.texel)
    ink = front & (codes > 0)
    s = E.carve(ctx, s, ink, depth=0.004, shade=-1.0)
    s.use_ramp(P["pig_green"], mask=ink, shade=np.full(ctx.N, 2.2) + _dither(ctx, 0.5, seed + 1))
    return s


def gate_panel(ctx, seed=1411):
    """Lime-white panel; within 0.32 m of the opening a ring of fine grey
    bricks (qing zhuan) with white joints."""
    s = A.plaster(ctx, seed, center=7.2)
    x, z = ctx.p[:, 0], ctx.p[:, 2]
    r = np.hypot(x, z - MG_C)
    xc = math.sqrt(MG_R ** 2 - (MG_C - MG_CUT) ** 2)
    ring = ((r < MG_R + 0.32) & (z >= MG_CUT)) | ((np.abs(x) < xc + 0.32) & (z < MG_CUT + 0.2))
    a = np.arctan2(z - MG_C, x)
    course = np.floor((r - MG_R) / 0.08)
    brick_len = 0.24 / MG_R
    stagger = np.mod(course, 2) * 0.5
    joint_a = np.abs(np.mod(a / brick_len + stagger, 1.0) - 0.5) > 0.5 - ctx.texel / (0.24) * 1.2
    joint_r = np.mod(r - MG_R, 0.08) < ctx.texel
    tone = np.mod(np.floor(a / brick_len + stagger) * 7 + course * 13, 5) / 5.0 - 0.5
    s.use_ramp(P["roof_tile"], mask=ring, shade=np.full(ctx.N, 5.6) + tone * 1.2 + _dither(ctx, 0.5, seed + 1)
               - (1.0 - ctx.ao) * 2.5)
    joints = ring & (joint_a | joint_r)
    s.use_ramp(P["gravel"], mask=joints, shade=np.full(ctx.N, 4.0))
    s.height = s.height - joints * 0.002
    return s


# --------------------------------------------------------------------------
# door frame
# --------------------------------------------------------------------------

def _fret(p, x0, x1, z0, z1, y, mat, cell=0.12, bar=0.022):
    """Step-by-step brocade fret (bubujin): a grid of short bars, every
    other cell split - read as a lattice valance."""
    nx = max(1, int(round((x1 - x0) / cell)))
    nz = max(1, int(round((z1 - z0) / cell)))
    cw = (x1 - x0) / nx
    ch = (z1 - z0) / nz
    for i in range(nx + 1):
        p.box((x0 + i * cw, y, (z0 + z1) / 2), (bar, 0.03, z1 - z0), mat)
    for j in range(nz + 1):
        p.box(((x0 + x1) / 2, y, z0 + j * ch), (x1 - x0, 0.03, bar), mat)
    for i in range(nx):
        for j in range(nz):
            if (i + j) % 2 == 0:
                p.box((x0 + (i + 0.5) * cw, y, z0 + j * ch + ch * 0.5), (cw * 0.5, 0.025, bar * 0.8), mat)
            else:
                p.box((x0 + i * cw + cw * 0.5, y, z0 + (j + 0.5) * ch), (bar * 0.8, 0.025, ch * 0.5), mat)


def _door_face(p, y, s):
    """Posts, lintel, valance and corner brackets on one face (s = -1 the
    front at y < 0, +1 the back)."""
    OW, OH = 2.0, 2.6
    yy = y + s * 0.05
    for sx in (-1, 1):
        p.box((sx * (OW / 2 + 0.09), yy, OH / 2 + 0.13), (0.18, 0.1, OH + 0.26), "lacquer", bevel=0.012)
        p.box((sx * (OW / 2 + 0.09), yy, 0.12), (0.24, 0.12, 0.24), "stone", bevel=0.015)
    p.box((0.0, yy, OH + 0.14), (OW + 0.54, 0.1, 0.28), "beam", bevel=0.012)
    _fret(p, -OW / 2, OW / 2, OH - 0.26, OH - 0.02, y + s * 0.025, "fret")
    p.box((0.0, y + s * 0.025, OH - 0.28), (OW, 0.04, 0.04), "lacquer", bevel=0.006)
    for sx in (-1, 1):
        f = front_prism(p, ccw([(0.0, 0.0), (0.0, -0.5), (0.04, -0.46), (0.08, -0.3), (0.16, -0.22),
                                (0.24, -0.12), (0.32, -0.06), (0.36, 0.0)]), 0.05, "bracket", y_back=0.0)
        p.move(f, Matrix.Translation((sx * OW / 2, 0.0 if s < 0 else WALL + 0.05, OH - 0.28))
               @ Matrix.Scale(-sx, 4, (1.0, 0.0, 0.0)))
        if sx > 0:
            for ff in f:
                ff.normal_flip()


def doorframe():
    p = Part("asia_doorframe_2x2_6")
    OW, OH = 2.0, 2.6
    _door_face(p, 0.0, -1)
    # lining: jambs and soffit through half the wall
    for sx in (-1, 1):
        p.box((sx * (OW / 2 + 0.015), HALF / 2, OH / 2), (0.03, HALF, OH), "lacquer")
    p.box((0.0, HALF / 2, OH - 0.015), (OW, HALF, 0.03), "lacquer")
    p.box((0.0, (HALF - 0.1) / 2, 0.005), (OW + 0.2, HALF + 0.1, 0.01), "stone")
    return p


# --------------------------------------------------------------------------
# lattice window, shoji
# --------------------------------------------------------------------------

def _cracked_ice(x0, x1, z0, z1, n=20, seed=3):
    """Cracked-ice lattice: a rectangle split again and again by straight
    cuts through the largest piece. Returns the unique inner segments."""
    rng = random.Random(seed)
    polys = [[(x0, z0), (x1, z0), (x1, z1), (x0, z1)]]

    def area(pg):
        return abs(sum(pg[i][0] * pg[(i + 1) % len(pg)][1] - pg[(i + 1) % len(pg)][0] * pg[i][1]
                       for i in range(len(pg)))) / 2

    for _ in range(n):
        polys.sort(key=area)
        pg = polys.pop()
        cx = sum(q[0] for q in pg) / len(pg) + rng.uniform(-0.05, 0.05)
        cz = sum(q[1] for q in pg) / len(pg) + rng.uniform(-0.05, 0.05)
        ang = rng.uniform(0, math.pi)
        nx, nz = math.cos(ang), math.sin(ang)
        a, b = [], []
        for i in range(len(pg)):
            p0, p1 = pg[i], pg[(i + 1) % len(pg)]
            d0 = (p0[0] - cx) * nx + (p0[1] - cz) * nz
            d1 = (p1[0] - cx) * nx + (p1[1] - cz) * nz
            (a if d0 >= 0 else b).append(p0)
            if (d0 >= 0) != (d1 >= 0):
                t = d0 / (d0 - d1)
                q = (p0[0] + (p1[0] - p0[0]) * t, p0[1] + (p1[1] - p0[1]) * t)
                a.append(q)
                b.append(q)
        if len(a) >= 3 and len(b) >= 3:
            polys += [a, b]
        else:
            polys.append(pg)
    segs = {}
    for pg in polys:
        for i in range(len(pg)):
            p0, p1 = pg[i], pg[(i + 1) % len(pg)]
            on_border = (abs(p0[0] - p1[0]) < 1e-6 and abs(p0[0] - x0) < 1e-6 or abs(p0[0] - x1) < 1e-6 and
                         abs(p1[0] - x1) < 1e-6) or (abs(p0[1] - p1[1]) < 1e-6 and (abs(p0[1] - z0) < 1e-6 or
                                                                                     abs(p0[1] - z1) < 1e-6))
            if on_border:
                continue
            key = tuple(sorted([(round(p0[0], 4), round(p0[1], 4)), (round(p1[0], 4), round(p1[1], 4))]))
            segs[key] = (p0, p1)
    return list(segs.values())


def _bar(p, a, b, y, w, d, mat):
    a, b = Vector((a[0], y, a[1])), Vector((b[0], y, b[1]))
    L = (b - a).length
    if L < 1e-4:
        return
    ang = math.atan2(b.z - a.z, b.x - a.x)
    f = p.box((0.0, 0.0, 0.0), (L + w * 0.6, d, w), mat)
    p.move(f, Matrix.Translation((a + b) / 2) @ Matrix.Rotation(-ang, 4, 'Y'))


def lattice_window():
    p = Part("asia_lattice_window")
    W, H = 1.6, 1.8
    fw = 0.1
    for sx in (-1, 1):
        p.box((sx * (W / 2 - fw / 2), -0.045, H / 2), (fw, 0.09, H), "lacquer", bevel=0.01)
    for z in (fw / 2, H - fw / 2):
        p.box((0.0, -0.045, z), (W - 2 * fw + 0.002, 0.09, fw), "lacquer", bevel=0.01)
    p.box((0.0, -0.1, -0.03), (W + 0.12, 0.2, 0.06), "lacquer", bevel=0.012)        # sill
    x0, x1, z0, z1 = -W / 2 + fw, W / 2 - fw, fw, H - fw
    for a, b in _cracked_ice(x0, x1, z0, z1, n=26, seed=11):
        _bar(p, a, b, -0.04, 0.026, 0.05, "lattice")
    p.box((0.0, -0.008, H / 2), (W - 2 * fw + 0.01, 0.016, H - 2 * fw + 0.01), "paper")
    cull_back([p])
    return p


def shoji():
    p = Part("asia_shoji_2m")
    PW, PH = 1.0, 2.0
    for k, xc in enumerate((-0.5, 0.5)):
        y = -0.03 if k == 0 else -0.065                  # the panels run in two tracks
        for sx in (-1, 1):
            p.box((xc + sx * (PW / 2 - 0.02), y, PH / 2), (0.04, 0.03, PH), "wood", bevel=0.004)
        for z in (0.02, 0.31, PH - 0.02):
            p.box((xc, y, z), (PW - 0.06, 0.03, 0.04 if z != 0.31 else 0.025), "wood", bevel=0.004)
        p.box((xc, y + 0.004, 0.165), (PW - 0.06, 0.012, 0.27), "board")
        for i in range(1, 4):
            p.box((xc - PW / 2 + 0.04 + (PW - 0.08) * i / 4, y, (0.32 + PH - 0.04) / 2), (0.014, 0.022, PH - 0.36),
                  "wood")
        for j in range(1, 7):
            p.box((xc, y, 0.32 + (PH - 0.36) * j / 7), (PW - 0.08, 0.022, 0.014), "wood")
        p.box((xc, y + 0.012, (0.32 + PH - 0.04) / 2), (PW - 0.07, 0.004, PH - 0.36), "paper")
    p.box((0.0, -0.06, PH + 0.04), (2.06, 0.12, 0.08), "rail", bevel=0.008)
    p.box((0.0, -0.06, -0.005), (2.06, 0.12, 0.01), "rail")
    cull_back([p])
    return p


# --------------------------------------------------------------------------
# garden wall coping
# --------------------------------------------------------------------------

def wallcap(W):
    p = Part("wallcap")
    # timber plate on the wall top, tile lean-to from the wall to the eave
    p.box((0.0, -0.1, 0.05), (W, 0.2, 0.1), "plate", bevel=0.01)
    D, z_wall, z_eave = 0.55, 0.42, 0.1
    a = p.bm.verts.new((-W / 2, 0.0, z_wall))
    b = p.bm.verts.new((W / 2, 0.0, z_wall))
    c = p.bm.verts.new((W / 2, -D, z_eave))
    d = p.bm.verts.new((-W / 2, -D, z_eave))
    f = p._face([a, d, c, b], "tiles")
    f.normal_update()
    if f.normal.z < 0:
        f.normal_flip()
    # underside and the eave edge
    p.poly([(-W / 2, 0.0, z_wall - 0.06), (-W / 2, -D, z_eave - 0.06), (W / 2, -D, z_eave - 0.06),
            (W / 2, 0.0, z_wall - 0.06)], "plate")
    p.box((0.0, -D + 0.02, z_eave - 0.03), (W, 0.04, 0.06), "plate")
    # rolled cover tiles: half-round tubes down the slope every 0.25 m
    n = int(round(W / 0.25))
    for k in range(n):
        x = -W / 2 + (k + 0.5) * 0.25
        p.tube([(x, -0.05, z_wall + 0.035 - 0.05 * (z_wall - z_eave) / D), (x, -D - 0.02, z_eave + 0.035)], 0.045,
               "tiles", sides=6)
        disc = p.lathe([(0.0, 0.0), (0.06, 0.0), (0.06, 0.02), (0.0, 0.02)], "disc", segments=8)
        p.move(disc, Matrix.Translation((x, -D - 0.02, z_eave + 0.035)) @ R('X', 90))
    # ridge roll against the wall
    p.tube([(-W / 2, -0.07, z_wall + 0.05), (W / 2, -0.07, z_wall + 0.05)], 0.06, "tiles", sides=6, caps=False)
    cull_back([p])
    return p


def tile_disc(ctx, seed=1431):
    """Eave end discs (wadang): a moulded ring with a boss."""
    s = A.roof_tiles(ctx, seed)
    face = np.abs(ctx.n[:, 1]) > 0.8
    s.shade[face] += 1.0
    return s


def build():
    out = []
    out.append(kit("asia_moon_gate_4m", [moon_gate()], {"panel": gate_panel, "stone": gate_stone,
                                                         "plaque": plaque_paint},
                   ppm=64, ao_dist=0.4, preview_elevation=6.0))
    lac = lambda c: A.lacquer(c, 1441, wear=0.4)
    out.append(kit("asia_doorframe_2x2_6", [doorframe()],
                   {"lacquer": lac, "beam": lambda c: A.lacquer(c, 1443, wear=0.4),
                    "fret": lambda c: A.lacquer(c, 1445, ramp="lacquer_black", center=3.0, wear=0.2),
                    "bracket": lambda c: A.painted(c, "pig_green", 3.8, 1447, line="pig_ochre"),
                    "stone": gate_stone},
                   ppm=96, ao_dist=0.25, preview_elevation=6.0))
    paper_dark = lambda c: A.paper(c, 1451, "washi", 5.4)
    paper_lit = lambda c: _lit_paper(c, 1451)
    win_fns = {"lacquer": lac, "lattice": lambda c: A.lacquer(c, 1453, wear=0.3), "paper": paper_dark}
    out.append(kit("asia_lattice_window", [lattice_window()], win_fns, ppm=128, wall=True, ao_dist=0.12,
                   variants={"asia_lattice_window_lit": {**win_fns, "paper": paper_lit}}))
    sho_fns = {"wood": lambda c: A.wood(c, 1461, ramp="hinoki", center=5.4),
               "board": lambda c: A.wood(c, 1463, ramp="hinoki", center=4.6),
               "rail": lambda c: A.wood(c, 1465, ramp="asia_cedar", center=4.4), "paper": paper_dark}
    out.append(kit("asia_shoji_2m", [shoji()], sho_fns, ppm=128, wall=True, ao_dist=0.12,
                   variants={"asia_shoji_2m_lit": {**sho_fns, "paper": paper_lit}}))
    for W, tag in ((4.0, "4m"), (2.0, "2m"), (1.0, "1m")):
        out.append(kit(f"asia_wallcap_{tag}", [wallcap(W)],
                       {"tiles": lambda c: A.roof_tiles(c, 1471), "disc": tile_disc,
                        "plate": lambda c: A.weathered_wood(c, 1473)},
                       ppm=64, wall=True, ground=None, ao_dist=0.25, preview=tag == "4m"))
    return out


def _lit_paper(ctx, seed):
    s = A.paper(ctx, seed, "washi", 6.6, glow=1.0)
    s.emit = s.colors() * np.array([1.0, 0.76, 0.48]) * (0.75 + ctx.fbm(1.2, 2, seed + 9)[:, None] * 0.2)
    return s
