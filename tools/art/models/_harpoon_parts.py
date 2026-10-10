"""Shared pieces of the whaling harpoon (vm_harpoon, harpoon_bolt,
ammo_harpoon): the forged harpoon itself (shank, socket, two-flued head),
the upgraded barbs, forged rings, tarred hemp line as a tube with
continuous twisted strands, chamfered lofts (gun stocks, iron bands) and
their materials.

Canonical harpoon space (``frame`` maps it into the model): the harpoon
points along +Y with its tip at y = 0, the flues spread in +-X, the flue
plates are thin in Z.
"""
import math

import numpy as np
from mathutils import Matrix, Vector

from artlib import kit, noise
from artlib import materials as M
from artlib.painter import Surface

TAU = math.tau

# --------------------------------------------------------------------------
# palettes (dark -> light), same rule as artlib/materials.P
# --------------------------------------------------------------------------
TAR = M.hexramp("#0b0806", "#130e0a", "#1c150e", "#261d13", "#312619", "#3e3020", "#4c3b28", "#5c4831",
                "#6e573c")
HEMP = M.hexramp("#4a3a24", "#5f4b2f", "#76603c", "#8d754b", "#a48b5c")
OAK_SEA = M.hexramp("#141210", "#1d1a16", "#27231d", "#322c25", "#3e372d", "#4b4236", "#594e40", "#685c4b",
                    "#786b58", "#8a7c67", "#9c8e78")
VERDIGRIS = M.hexramp("#13201b", "#1b2e27", "#243d33", "#2f4e41", "#3c6151", "#4c7663", "#618d78")
GOLD_INLAY = M.P["gold"]

# --------------------------------------------------------------------------
# geometry helpers
# --------------------------------------------------------------------------


def torus(p, center, normal, R, r, mat, segments=14, ring=6, phase=0.0):
    """Forged ring: wire radius r, ring radius R, around ``normal``."""
    prof = [(R + r * math.cos(a), r * math.sin(a))
            for a in np.linspace(-math.pi / 2, 1.5 * math.pi, ring + 1)]
    f = p.lathe(prof, mat, segments=segments, cap_bottom=False, cap_top=False, smooth=True, phase=phase)
    c = Vector(center)
    p.move(f, kit.align(c, c + Vector(normal).normalized()))
    return f


def frames_along(pts):
    """Tangents and parallel-transported normals along a polyline."""
    n = len(pts)
    tan = []
    for i in range(n):
        if i == 0:
            t = pts[1] - pts[0]
        elif i == n - 1:
            t = pts[-1] - pts[-2]
        else:
            t = (pts[i + 1] - pts[i]).normalized() + (pts[i] - pts[i - 1]).normalized()
        tan.append(t.normalized())
    ref = Vector((0, 0, 1)) if abs(tan[0].z) < 0.9 else Vector((1, 0, 0))
    nrm = [tan[0].cross(ref).normalized()]
    for i in range(1, n):
        q = nrm[-1] - tan[i] * nrm[-1].dot(tan[i])
        nrm.append(q.normalized())
    return tan, nrm


def rope(p, points, radius, mat, sides=6, chunk=0.2, caps=True, v0=0.0):
    """Rope tube along ``points`` with continuous strands: one mesh (smooth
    shading runs through), but the UVs are cut into ~``chunk`` m islands by
    shifting u by whole circumferences, which the 3-strand pattern of
    ``tar_rope`` ignores (it repeats 3x per circumference)."""
    pts = [Vector(q) for q in points]
    tan, nrm = frames_along(pts)
    rings = []
    for i, c in enumerate(pts):
        b = tan[i].cross(nrm[i])
        rings.append([p.bm.verts.new(c + (nrm[i] * math.cos(TAU * k / sides) + b * math.sin(TAU * k / sides))
                                     * radius) for k in range(sides)])
    acc = [v0]
    for i in range(1, len(pts)):
        acc.append(acc[-1] + (pts[i] - pts[i - 1]).length)
    circ = TAU * radius
    faces = []
    for j in range(len(pts) - 1):
        off = math.floor((acc[j] - v0) / chunk + 1e-6) * circ
        for k in range(sides):
            k2 = (k + 1) % sides
            f = p._face([rings[j][k], rings[j][k2], rings[j + 1][k2], rings[j + 1][k]], mat, True)
            uvs = [(off + circ * k / sides, acc[j]), (off + circ * (k + 1) / sides, acc[j]),
                   (off + circ * (k + 1) / sides, acc[j + 1]), (off + circ * k / sides, acc[j + 1])]
            for loop, uv in zip(f.loops, uvs):
                loop[p.uv].uv = uv
            f[p.lock] = 1
            faces.append(f)
    if caps:
        faces.append(p._face(list(reversed(rings[0])), mat))
        faces.append(p._face(rings[-1], mat))
    return faces, acc[-1]


def round_section(hw, hh, rc, n=4):
    """Rounded rectangle (x, z): starts at the bottom centre and runs
    counter-clockwise seen from -Y; ``n`` points per 90-degree corner."""
    rc = min(rc, hw * 0.999, hh * 0.999)
    pts = [(0.0, -hh)]
    for cx, cz, a0 in ((hw - rc, -hh + rc, -90.0), (hw - rc, hh - rc, 0.0), (-hw + rc, hh - rc, 90.0),
                       (-hw + rc, -hh + rc, 180.0)):
        for i in range(n):
            a = math.radians(a0 + 90.0 * i / (n - 1))
            pts.append((cx + rc * math.cos(a), cz + rc * math.sin(a)))
    return pts


def loft(p, rings, mat, caps=(True, True), smooth=True):
    """Skin through rings of points (lists of Vectors with equal counts; the
    first point of each ring is the UV seam, put it underneath). One UV
    island: u = perimeter position centred on the top, v = distance along
    the loft, so wood grain and brushing run lengthwise."""
    nk = len(rings[0])
    vs = [[p.bm.verts.new(c) for c in ring] for ring in rings]
    us = []
    for ring in rings:
        acc = [0.0]
        for k in range(1, nk + 1):
            acc.append(acc[-1] + (ring[k % nk] - ring[k - 1]).length)
        us.append([a - acc[-1] / 2 for a in acc])
    cent = [sum(r, Vector()) / nk for r in rings]
    vv = [0.0]
    for j in range(1, len(rings)):
        vv.append(vv[-1] + (cent[j] - cent[j - 1]).length)
    faces = []
    for j in range(len(rings) - 1):
        for k in range(nk):
            k2 = (k + 1) % nk
            f = p._face([vs[j][k], vs[j][k2], vs[j + 1][k2], vs[j + 1][k]], mat, smooth)
            uvs = [(us[j][k], vv[j]), (us[j][k + 1], vv[j]), (us[j + 1][k + 1], vv[j + 1]), (us[j + 1][k], vv[j + 1])]
            for loop, uv in zip(f.loops, uvs):
                loop[p.uv].uv = uv
            f[p.lock] = 1
            faces.append(f)
    score = 0.0
    for idx, f in enumerate(faces):
        f.normal_update()
        score += f.normal.dot(f.calc_center_median() - cent[idx // nk])
    if score < 0:
        for f in faces:
            f.normal_flip()
    for end in (0, 1):
        if not caps[end]:
            continue
        ring_v = vs[0] if end == 0 else vs[-1]
        f = p._face(list(ring_v), mat, False)
        f.normal_update()
        out = (cent[0] - cent[1]) if end == 0 else (cent[-1] - cent[-2])
        if f.normal.dot(out) < 0:
            f.normal_flip()
        faces.append(f)
    return faces


def section_rings(secs, grow=0.0, n=4):
    """[(y, zc, hw, hh, rc)] -> rings of rounded rectangles (optionally grown)."""
    out = []
    for y, zc, hw, hh, rc in secs:
        out.append([Vector((x, y, zc + z)) for x, z in round_section(hw + grow, hh + grow, rc + grow, n)])
    return out


def interp_section(secs, y):
    """Linear interpolation of a section list (sorted by descending y)."""
    for a, b in zip(secs[:-1], secs[1:]):
        if b[0] <= y <= a[0]:
            t = (a[0] - y) / (a[0] - b[0]) if a[0] != b[0] else 0.0
            return tuple(a[i] + (b[i] - a[i]) * t for i in range(5))
    return secs[0] if y > secs[0][0] else secs[-1]


def prism(p, outline, thick, mat, frame, bevel=0.0):
    """Flat plate from a convex 2D outline (x, y) in the canonical XY plane,
    ``thick`` in Z, moved by ``frame``."""
    pts = list(outline)
    area = sum(pts[i][0] * pts[(i + 1) % len(pts)][1] - pts[(i + 1) % len(pts)][0] * pts[i][1]
               for i in range(len(pts)))
    if area < 0:
        pts.reverse()
    f = p.ngon_prism(pts, -thick / 2, thick / 2, mat, bevel=bevel)
    p.move(f, frame)
    return f


# --------------------------------------------------------------------------
# the harpoon
# --------------------------------------------------------------------------

def flue_outline(s=1.0):
    """Left flue (x < 0): tip, shoulder, barb point, barb root. Convex."""
    return [(0.0, 0.0), (-0.026 * s, -0.05 * s), (-0.034 * s, -0.09 * s), (-0.0095 * s, -0.068 * s)]


def head(p, frame, s=1.0, mat="harpoon"):
    """Two-flued forged head (flues in the canonical XY plane) + socket."""
    faces = []
    for sx in (-1, 1):
        out = [(sx * -x, y) for x, y in flue_outline(s)] if sx > 0 else flue_outline(s)
        faces += prism(p, out, 0.0075 * s, mat, frame, bevel=0.0026 * s)
    f = kit.seg(p, (0, -0.108 * s, 0), (0, -0.04 * s, 0),
                [(0.0086 * s, 0.0), (0.0108 * s, 0.22), (0.0104 * s, 0.5), (0.0065 * s, 0.84), (0.0035 * s, 1.0)],
                mat, segments=8, phase=math.pi / 8)
    p.move(f, frame)
    return faces + f


def shank(p, frame, y0, y1, r=0.0085, mat="harpoon", segments=10):
    """Shank from canonical y0 (back) to y1, slightly uneven like forged bar."""
    f = kit.seg(p, (0, y0, 0), (0, y1, 0), [(r * 1.03, 0.0), (r * 0.98, 0.3), (r, 0.62), (r * 0.97, 0.85),
                                            (r * 1.0, 1.0)], mat, segments=segments)
    p.move(f, frame)
    return f


def barbs(p, frame, s=1.0, mat="harpoon", spurs=(-0.155, -0.19), spur_s=1.0):
    """Upgrade: a second, smaller pair of flues at right angles (a four-flued
    head) and two pairs of forged spurs on the shank behind it (at canonical
    y = ``spurs``, independent of the head scale)."""
    faces = []
    rot = Matrix.Rotation(math.radians(90.0), 4, 'Y')
    back = Matrix.Translation((0, -0.024 * s, 0))
    for sx in (-1, 1):
        out = [(sx * -x * 0.82, y * 0.82) for x, y in flue_outline(s)] if sx > 0 else \
            [(x * 0.82, y * 0.82) for x, y in flue_outline(s)]
        faces += prism(p, out, 0.0065 * s, mat, frame @ back @ rot, bevel=0.0022 * s)
    k = spur_s
    spur = [(0.0055 * k, 0.0), (0.0225 * k, -0.036 * k), (0.0055 * k, -0.017 * k)]
    for y, ang in zip(spurs, (0.0, 90.0)):
        for sx in (-1, 1):
            out = [(sx * x, yy) for x, yy in spur]
            faces += prism(p, out, 0.0044 * k, mat, frame @ Matrix.Translation((0, y, 0))
                           @ Matrix.Rotation(math.radians(ang), 4, 'Y'), bevel=0.0014 * k)
    return faces


# --------------------------------------------------------------------------
# materials
# --------------------------------------------------------------------------

def forged(ctx, seed=721, center=4.6, rust=1.0, ramp="steel"):
    """Hand-forged iron: hammer facets, dark scale, bright worn edges,
    rust blooming in the corners."""
    s = M.steel(ctx, seed=seed, ramp=ramp, center=center, dent=0.0, rust=rust, polish=0.42, scratch=0.12)
    hm = M.dents(ctx, seed + 1, freq=70.0, amount=0.55, radius=0.5)
    scale = ctx.fbm(14.0, 3, seed + 2)
    s.shade -= hm * 1.0 + np.clip(scale, 0, 1) * 1.4
    s.height = s.height - hm * hm * 0.0010
    s.rough = np.clip(s.rough + np.clip(scale, 0, 1) * 0.25, 0, 1)
    return s


def sea_iron(ctx, seed=701, center=4.8):
    """Weathered ship's iron (the barrel): pitted, salt-dulled, rust in the
    pits and corners, edges rubbed bright."""
    s = M.steel(ctx, seed=seed, ramp="steel", center=center, dent=0.45, rust=1.5, polish=0.45, scratch=0.14)
    f1, _, cid = ctx.worley(120.0, seed + 1)
    pits = (f1 < 0.3) & (cid > 0.35) & (ctx.fbm(9.0, 3, seed + 7) > 0.12)
    s.shade[pits] -= 1.8
    s.height = s.height - pits * 0.0004
    pit_rust = pits & (ctx.rand(seed + 2) > 0.45)
    s.use_ramp(M.P["rust"], mask=pit_rust, shade=np.full(ctx.N, 1.2) + M._dither(ctx, 1.2, seed + 3))
    bloom = (ctx.fbm(5.0, 3, seed + 4) > 0.38) & (ctx.rand(seed + 5) > 0.35)
    s.use_ramp(M.P["rust"], mask=bloom, shade=np.full(ctx.N, 1.6) + ctx.fbm(30.0, 2, seed + 6) * 0.9)
    s.metal = np.where(pit_rust | bloom, 0.1, s.metal)
    s.rough = np.where(pit_rust | bloom, 0.85, s.rough)
    return s


def sea_brass(ctx, seed=751):
    """Ship's brass: tarnished, verdigris in the corners and recesses."""
    s = M.brass(ctx, seed=seed, tarnish_amount=2.6)
    v = ((ctx.cavity(4.0) > 0.3) | ((1.0 - ctx.ao) > 0.32)) & (ctx.fbm(14.0, 2, seed + 1) > -0.15)
    s.use_ramp(VERDIGRIS, mask=v, shade=np.full(ctx.N, 2.6) + ctx.fbm(30.0, 2, seed + 2) * 1.2
               + M._dither(ctx, 1.0, seed + 3))
    s.metal = np.where(v, 0.0, s.metal)
    s.rough = np.where(v, 0.85, s.rough)
    return s


def strand_phase(ctx, radius, lay=0.032):
    """Phase of the three twisted strands on a rope tube (0..1 per strand)."""
    circ = TAU * radius
    return np.mod(3.0 * (ctx.uvm[:, 0] / circ - ctx.uvm[:, 1] / lay), 1.0)


def tar_rope(ctx, seed=731, radius=0.0045, center=3.4, lay=0.032):
    """Tarred hemp line: three twisted strands, glossy tar on the crowns,
    pale hemp fibres poking out."""
    s = Surface(ctx.N)
    ph = strand_phase(ctx, radius, lay)
    crown = np.sin(np.pi * ph)
    groove = (ph < 0.14) | (ph > 0.94)
    fib = M._streaks(ctx, (0.0, 0.0, 1.0), 60.0, 300.0, 2, seed)
    shade = center + crown * 2.4 + fib * 0.7 + ctx.fbm(9.0, 3, seed + 1) * 0.8 + M._dither(ctx, 0.6, seed + 2)
    shade -= groove * 1.8 + (1.0 - ctx.ao) * 3.0
    s.use_ramp(TAR, shade=shade)
    fuzz = (ctx.rand(seed + 3) > 0.93) & (crown > 0.5)
    s.use_ramp(HEMP, mask=fuzz, shade=np.full(ctx.N, 1.5) + M._dither(ctx, 2.0, seed + 4))
    s.rough = np.clip(0.42 + (1 - crown) * 0.35 + ctx.rand(seed + 5) * 0.06, 0, 1)
    s.rough = np.where(fuzz, 0.95, s.rough)
    s.height = crown * 0.0007 - groove * 0.0004
    return s


def twine(ctx, seed=737, pitch=0.004):
    """Tarred twine whipping / lashing: tight turns across the wrap."""
    s = Surface(ctx.N)
    ph = np.mod(ctx.uvm[:, 1] / pitch + ctx.uvm[:, 0] * 2.0, 1.0)
    crown = np.sin(np.pi * ph)
    shade = 3.0 + crown * 2.2 + M._dither(ctx, 0.7, seed) + ctx.fbm(20.0, 2, seed + 1) * 0.6
    shade -= (ph < 0.15) * 1.6 + (1.0 - ctx.ao) * 3.0 + ctx.cavity(3.0) * 1.5
    s.use_ramp(TAR, shade=shade)
    s.rough = 0.5 + (1 - crown) * 0.3
    s.height = crown * 0.0005
    return s


def wad(ctx, seed=741):
    """Tarred oakum wadding rammed round the shank in the muzzle."""
    s = Surface(ctx.N)
    sw = M._streaks(ctx, (1.0, 0.0, 0.3), 30.0, 140.0, 3, seed)
    shade = 3.0 + sw * 1.8 + ctx.fbm(40.0, 2, seed + 1) * 0.8 + M._dither(ctx, 0.9, seed + 2)
    shade -= (1.0 - ctx.ao) * 3.0
    s.use_ramp(TAR, shade=shade)
    hemp = (sw > 0.35) & (ctx.rand(seed + 3) > 0.55)
    s.use_ramp(HEMP, mask=hemp, shade=np.full(ctx.N, 1.0) + M._dither(ctx, 1.5, seed + 4))
    s.rough = np.full(ctx.N, 0.9)
    s.height = sw * 0.0005
    return s


def sea_oak(ctx, seed=761, center=5.4):
    """Weathered oak stock: open grain bleached silver-brown by salt, dark
    tar and grime in the grain and corners, dings and rubbed edges."""
    s = M._wood_core(ctx, OAK_SEA, center, seed, ring_freq=7.0, contrast=1.35)
    along, across = M._grain_frame(ctx)
    q = np.stack([np.sum(ctx.p * along, 1), np.sum(ctx.p * ctx.n, 1), np.sum(ctx.p * across, 1)], axis=1)
    open_grain = ctx.fbm(np.array([2.0, 180.0, 180.0]), 2, seed + 7, p=q) > 0.42
    s.shade[open_grain] -= 1.6
    s.height = s.height - open_grain * 0.0004
    dings = M.scratches(ctx, seed + 8, density=0.35, length=0.03, width=0.7) > 0
    s.shade[dings] -= 1.5
    s.height = s.height - dings * 0.0003
    bleach = np.clip(ctx.n[:, 2], 0, 1) * 0.5 + np.clip(ctx.fbm(3.0, 3, seed + 9), 0, 1) * 0.7
    s.shade += bleach
    M._age(ctx, s, cavity=2.6, ao=4.0, edge=1.4)
    s.rough = np.clip(0.66 + np.clip(ctx.fbm(3.0, 3, seed + 5), 0, 1) * 0.2 - ctx.edge_soft(3.0) * 0.2, 0, 1)
    return s


def ivory_plaque(ctx, seed=771):
    """Yellowed whale-ivory inlay, crazed and worn."""
    s = M.ivory(ctx, seed=seed, center=5.0)
    f1, f2, _ = ctx.worley(160.0, seed + 1)
    craze = (f2 - f1) < 0.06
    s.shade[craze] -= 1.2
    s.shade -= ctx.fbm(6.0, 2, seed + 2).clip(0, 1) * 1.2
    s.rough = np.full(ctx.N, 0.42)
    return s


# --------------------------------------------------------------------------
# mastery finish (vm_harpoon_master)
# --------------------------------------------------------------------------

def scroll_lines(ctx, cell=0.022, seed=781):
    """Engraved scrollwork in the metre-UV plane: curled C-scrolls, one per
    cell, alternating hand, joined by flowing stems along the cell rows.
    Returns a bool mask of the 1-texel cut lines."""
    u = ctx.uvm[:, 0] / cell + ctx.part * 0.37
    v = ctx.uvm[:, 1] / cell
    cu, cv = np.floor(u), np.floor(v)
    fu, fv = u - cu - 0.5, v - cv - 0.5
    r = np.hypot(fu, fv)
    a = np.arctan2(fv, fu)
    turn = noise.rand_cells((cu * 31 + cv * 7).astype(np.int64), seed) > 0.5
    k = r * 3.2 - np.where(turn, a, -a) / TAU
    w = ctx.texel / cell * 0.55 * 3.2
    spiral = (np.abs(np.mod(k, 1.0) - 0.5) > 0.5 - w) & (r < 0.44) & (r > 0.07)
    stem = np.abs(fv - 0.42 * np.sin(u * math.pi)) < ctx.texel / cell * 0.55
    stem &= r > 0.43
    return spiral | stem


def inlay_edges(ctx, inset=2.0):
    """1-texel line ``inset`` texels in from every sharp convex edge."""
    d = ctx.convex / ctx.texel
    return (d > inset - 0.5) & (d < inset + 0.5)


def polished_steel(ctx, seed=791, center=7.6, engrave=True, inlay=True):
    """Master finish: mirror-polished steel, bright polished edges, no rust,
    fine engraved scrollwork, gold inlay lines along the edges."""
    s = Surface(ctx.N)
    along, across = M._grain_frame(ctx)
    q = np.stack([np.sum(ctx.p * along, 1), np.sum(ctx.p * ctx.n, 1), np.sum(ctx.p * across, 1)], axis=1)
    brushed = ctx.fbm(np.array([3.0, 90.0, 90.0]), 2, seed, p=q)
    cloud = ctx.fbm(2.2, 3, seed + 1)
    shade = center + brushed * 0.5 + cloud * 0.7 + M._dither(ctx, 0.5, seed + 4)
    shade += ctx.edge(1.0) * 2.8 + ctx.edge(2.0) * 1.0
    shade -= ctx.cavity(3.0) * 2.5 + (1.0 - ctx.ao) * 4.0
    s.use_ramp(M.P["steel"], shade=shade)
    s.metal = np.full(ctx.N, 1.0)
    s.rough = np.clip(0.08 + np.clip(cloud, 0, 1) * 0.06 + ctx.rand(seed + 5) * 0.03, 0.04, 1)
    s.height = brushed * 0.0001
    if engrave:
        cut = scroll_lines(ctx, seed=seed + 2) & (ctx.convex > ctx.texel * 3.0)
        s.shade[cut] -= 4.0
        s.height = s.height - cut * 0.00025
        s.rough = np.where(cut, 0.45, s.rough)
    if inlay:
        gold = inlay_edges(ctx, 2.0)
        s.use_ramp(GOLD_INLAY, mask=gold, shade=np.full(ctx.N, 7.2) + M._dither(ctx, 0.6, seed + 3))
        s.metal = np.where(gold, 1.0, s.metal)
        s.rough = np.where(gold, 0.12, s.rough)
        s.height = s.height + gold * 0.0001
    return s


def polished_brass(ctx, seed=795):
    s = M.brass(ctx, seed=seed, tarnish_amount=0.3, grain=0.5)
    s.shade += 0.8
    cut = scroll_lines(ctx, cell=0.02, seed=seed + 1) & (ctx.convex > ctx.texel * 2.5)
    s.shade[cut] -= 3.5
    s.height = s.height - cut * 0.0002
    s.rough = np.where(cut, 0.4, np.clip(s.rough - 0.08, 0.06, 1))
    return s


def polished_wood(ctx, seed=799):
    """Warm, oiled and polished: rich honey-brown, high gloss."""
    s = M._wood_core(ctx, M.P["wood_oak"], 4.4, seed, ring_freq=7.0, contrast=1.15)
    M._age(ctx, s, cavity=1.6, ao=3.0, edge=1.2)
    s.rough = np.clip(0.14 + np.clip(ctx.fbm(3.0, 3, seed + 5), 0, 1) * 0.08, 0, 1)
    return s


def whale_mask(a, b):
    """Sperm whale in plaque units (a: -1..1 along, head at +a; b: -1..1 up)."""
    body_h = np.interp(a, [-0.62, -0.45, -0.1, 0.12, 0.66, 0.74],
                       [0.06, 0.12, 0.30, 0.38, 0.38, 0.26])
    body_c = np.interp(a, [-0.62, -0.1, 0.2, 0.74], [0.18, 0.05, 0.0, 0.02])
    body = (a > -0.62) & (a < 0.74) & (np.abs(b - body_c) < body_h)
    nose = (a >= 0.6) & (a < 0.8) & (np.abs(b - 0.06) < 0.3 * np.clip((0.8 - a) / 0.2, 0, 1) ** 0.5)
    hump = (np.abs(a + 0.25) < 0.08) & (b > 0.1) & (b < 0.36)
    # flukes, raised: two lobes spreading up and back from the tail stock
    t = (-0.62 - a) / 0.2
    fl_u = (t > 0) & (t < 1) & (np.abs(b - (0.22 + t * 0.55)) < 0.08 + t * 0.06)
    fl_d = (t > 0) & (t < 1) & (np.abs(b - (0.2 + t * 0.1)) < 0.06 + t * 0.03) & (t < 0.8)
    return body | nose | hump | fl_u | fl_d


def scrimshaw(ctx, seed=801, center_y=-0.41, center_z=-0.092, half_len=0.05, half_h=0.019):
    """Polished ivory with a scrimshaw engraving in black ink: a sperm
    whale over three rows of waves, a double ruled border."""
    s = M.ivory(ctx, seed=seed, center=5.8)
    s.rough = np.full(ctx.N, 0.22)
    side = ctx.n[:, 0] < -0.7
    a = (ctx.p[:, 1] - center_y) / half_len          # +a toward the muzzle (the viewer's left)
    b = (ctx.p[:, 2] - center_z) / half_h
    tx_a = ctx.texel / half_len
    tx_b = ctx.texel / half_h
    w = whale_mask(a * 1.18 - 0.02, (b - 0.12) * 1.25)
    edge = w & ~(whale_mask((a + tx_a) * 1.18 - 0.02, (b - 0.12) * 1.25)
                 & whale_mask((a - tx_a) * 1.18 - 0.02, (b - 0.12) * 1.25)
                 & whale_mask(a * 1.18 - 0.02, (b + tx_b - 0.12) * 1.25)
                 & whale_mask(a * 1.18 - 0.02, (b - tx_b - 0.12) * 1.25))
    hatch = w & (np.mod(np.floor(ctx.uvm[:, 0] / ctx.texel) + np.floor(ctx.uvm[:, 1] / ctx.texel), 3) == 0) \
        & (b < 0.05)
    eye = (np.abs(a - 0.52) < tx_a * 0.9) & (np.abs(b - 0.06) < tx_b * 0.9)
    waves = np.zeros(ctx.N, dtype=bool)
    for k, bb in enumerate((-0.55, -0.72, -0.88)):
        wave = bb + 0.07 * np.sin((a * 9.0 + k * 1.3) * math.pi)
        waves |= np.abs(b - wave) < tx_b * 0.55
    spout = np.zeros(ctx.N, dtype=bool)
    for da, db in ((0.62, 0.62), (0.58, 0.72), (0.66, 0.74), (0.55, 0.82), (0.69, 0.84)):
        spout |= (np.abs(a - da) < tx_a * 0.6) & (np.abs(b - db) < tx_b * 0.6)
    border = (np.abs(np.abs(a) - 0.94) < tx_a * 0.55) & (np.abs(b) < 0.94 + tx_b) \
        | (np.abs(np.abs(b) - 0.92) < tx_b * 0.55) & (np.abs(a) < 0.94 + tx_a)
    ink = side & (edge | hatch | eye | waves | spout | border) & (np.abs(a) < 1.0)
    s.use_ramp(M.P["hair"], mask=ink, shade=np.full(ctx.N, 0.6) + M._dither(ctx, 0.5, seed + 1))
    s.height = s.height - ink * 0.00015
    s.rough = np.where(ink, 0.4, s.rough)
    return s
