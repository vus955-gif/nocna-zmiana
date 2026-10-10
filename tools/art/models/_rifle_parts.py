"""Shared pieces for the expedition hunting rifle (vm_rifle_hunt) and its
pickup (ammo_rifle_hunt): geometry helpers that artlib has no direct
equivalent for (a stock loft with superelliptic sections, arc shells,
rectangular straps), the 9,3 x 62 cartridge and its stripper clip, and
the painted marks of the rifle (diamond checkering on the texel grid,
engraved scrollwork, engine turning, gold inlay)."""
import math

import numpy as np
from mathutils import Vector

from artlib import kit
from artlib import materials as M
from artlib import noise
from artlib.painter import Surface

TAU = math.tau


# --------------------------------------------------------------------------
# geometry
# --------------------------------------------------------------------------

def _orient_out(p, faces, axis_pt):
    """Flips ``faces`` if their normals point toward the axis (inward)."""
    side = 0.0
    for f in faces:
        f.normal_update()
        c = f.calc_center_median()
        a = axis_pt(c)
        side += f.normal.dot(c - a)
    if side < 0.0:
        for f in faces:
            f.normal_flip()


def loft(p, stations, mat, segs=16, smooth=True, caps=(True, True)):
    """A stock-like body along Y through superelliptic sections.

    stations = [(y, zc, hw, hh, n), ...]: centre height, half width, half
    height and exponent (2 = ellipse, higher = boxier) of each section.
    Vertex 0 of every ring sits at the bottom, where the UV seam goes. UVs
    are one island: u = arc length round each ring (centred on the top),
    v = length along the centre line, both in metres."""
    rings, pts_all = [], []
    for (y, zc, hw, hh, n) in stations:
        ring, pts = [], []
        for i in range(segs):
            a = -math.pi / 2 + TAU * i / segs
            c, s = math.cos(a), math.sin(a)
            x = hw * math.copysign(abs(c) ** (2.0 / n), c)
            z = zc + hh * math.copysign(abs(s) ** (2.0 / n), s)
            pts.append(Vector((x, y, z)))
            ring.append(p.bm.verts.new((x, y, z)))
        rings.append(ring)
        pts_all.append(pts)
    us = []
    for pts in pts_all:
        cum = [0.0]
        for i in range(segs):
            cum.append(cum[-1] + (pts[(i + 1) % segs] - pts[i]).length)
        half = cum[-1] * 0.5
        us.append([c - half for c in cum])
    vs = [0.0]
    for j in range(1, len(stations)):
        a, b = stations[j - 1], stations[j]
        vs.append(vs[-1] + math.hypot(b[0] - a[0], b[1] - a[1]))
    faces = []
    for j in range(len(stations) - 1):
        for i in range(segs):
            i2 = (i + 1) % segs
            corners = [(rings[j][i], (us[j][i], vs[j])), (rings[j][i2], (us[j][i + 1], vs[j])),
                       (rings[j + 1][i2], (us[j + 1][i + 1], vs[j + 1])), (rings[j + 1][i], (us[j + 1][i], vs[j + 1]))]
            f = p._face([c[0] for c in corners], mat, smooth)
            for loop, (_, uv) in zip(f.loops, corners):
                loop[p.uv].uv = uv
            f[p.lock] = 1
            faces.append(f)
    yz = [(s[0], s[1]) for s in stations]

    def axis_pt(c):
        # nearest station centre along y (good enough for the sign test)
        k = min(range(len(yz)), key=lambda q: abs(yz[q][0] - c.y))
        return Vector((0.0, c.y, yz[k][1]))

    _orient_out(p, faces, axis_pt)
    if caps[0]:
        f = p._face(list(rings[0]), mat, False)
        f.normal_update()
        d = stations[0][0] - stations[1][0]
        if f.normal.y * d < 0:
            f.normal_flip()
        faces.append(f)
    if caps[1]:
        f = p._face(list(rings[-1]), mat, False)
        f.normal_update()
        d = stations[-1][0] - stations[-2][0]
        if f.normal.y * d < 0:
            f.normal_flip()
        faces.append(f)
    return faces


def arc_shell(p, y0, y1, r_in, r_out, a0, a1, mat, segs=10, smooth=True, xc=0.0, zc=0.0):
    """A solid arc of a tube along Y (receiver walls, curved plates):
    angles in degrees in the XZ plane (0 = +X, 90 = +Z), a0 < a1. The
    outer face is one unrolled UV island (u = arc length, v = y)."""
    def ring(r, y):
        out = []
        for k in range(segs + 1):
            a = math.radians(a0 + (a1 - a0) * k / segs)
            out.append(p.bm.verts.new((xc + r * math.cos(a), y, zc + r * math.sin(a))))
        return out
    o0, o1, i0, i1 = ring(r_out, y0), ring(r_out, y1), ring(r_in, y0), ring(r_in, y1)
    faces = []
    arc = math.radians(a1 - a0) * r_out / segs
    for k in range(segs):
        f = p._face([o0[k], o0[k + 1], o1[k + 1], o1[k]], mat, smooth)
        uvs = [(arc * k, y0), (arc * (k + 1), y0), (arc * (k + 1), y1), (arc * k, y1)]
        for loop, uv in zip(f.loops, uvs):
            loop[p.uv].uv = uv
        f[p.lock] = 1
        faces.append(f)
    _orient_out(p, faces, lambda c: Vector((xc, c.y, zc)))
    inner = [p._face([i0[k], i0[k + 1], i1[k + 1], i1[k]], mat, smooth) for k in range(segs)]
    _orient_out(p, inner, lambda c: Vector((xc, c.y, zc)))
    for f in inner:
        f.normal_flip()
    faces += inner
    # ends (annular sectors at y0, y1) and the two long edges
    for (o, i, sgn) in ((o0, i0, -1 if y0 < y1 else 1), (o1, i1, 1 if y0 < y1 else -1)):
        for k in range(segs):
            f = p._face([o[k], o[k + 1], i[k + 1], i[k]], mat, False)
            f.normal_update()
            if f.normal.y * sgn < 0:
                f.normal_flip()
            faces.append(f)
    for (k, sgn) in ((0, -1), (segs, 1)):
        f = p._face([o0[k], o1[k], i1[k], i0[k]], mat, False)
        f.normal_update()
        a = math.radians(a0 + (a1 - a0) * k / segs)
        tang = Vector((-math.sin(a), 0.0, math.cos(a))) * sgn
        if f.normal.dot(tang) < 0:
            f.normal_flip()
        faces.append(f)
    return faces


def strap(p, path, width, thick, mat, x=0.0):
    """A flat strap (trigger guard bow, tangs) swept along a path in the
    YZ plane: ``width`` along X, ``thick`` across the path."""
    pts = [Vector((x, y, z)) for y, z in path]
    n = len(pts)
    rings = []
    for i in range(n):
        if i == 0:
            t = pts[1] - pts[0]
        elif i == n - 1:
            t = pts[-1] - pts[-2]
        else:
            t = (pts[i + 1] - pts[i]).normalized() + (pts[i] - pts[i - 1]).normalized()
        t.normalize()
        nn = Vector((0.0, -t.z, t.y))           # in-plane normal
        hw, ht = width / 2, thick / 2
        X = Vector((1.0, 0.0, 0.0))
        rings.append([p.bm.verts.new(pts[i] + X * sx * hw + nn * sz * ht)
                      for sx, sz in ((-1, -1), (1, -1), (1, 1), (-1, 1))])
    faces = []
    for i in range(n - 1):
        for k in range(4):
            k2 = (k + 1) % 4
            faces.append(p._face([rings[i][k], rings[i][k2], rings[i + 1][k2], rings[i + 1][k]], mat, False))
    mid = [sum((v.co for v in r), Vector()) / 4 for r in rings]
    for f in faces:
        f.normal_update()
        c = f.calc_center_median()
        j = min(range(n), key=lambda q: (mid[q] - c).length)
        if f.normal.dot(c - mid[j]) < 0:
            f.normal_flip()
    for r, sgn in ((rings[0], -1), (rings[-1], 1)):
        f = p._face(list(r), mat, False)
        f.normal_update()
        t = (pts[-1] - pts[-2]) if sgn > 0 else (pts[0] - pts[1])
        if f.normal.dot(t) < 0:
            f.normal_flip()
        faces.append(f)
    return faces


def prism_yz(p, outline, x0, x1, mat, bevel=0.0):
    """A plate whose side profile ``outline`` [(y, z), ...] (counter-
    clockwise seen from +X) is extruded across X from x0 to x1."""
    faces = p.ngon_prism(outline, x0, x1, mat, bevel=bevel)
    # ngon_prism builds in (x, y) extruded along z: map (x, y, z) -> (z, x, y)
    verts = {v for f in faces for v in f.verts}
    for v in verts:
        a, b, c = v.co
        v.co = Vector((c, a, b))
    return faces


# --------------------------------------------------------------------------
# 9,3 x 62 cartridge and its stripper clip
# --------------------------------------------------------------------------

RIM_R = 0.006            # 11.95 mm rim
CASE_L = 0.062
OAL = 0.083
CLIP_PITCH = 0.0122      # cartridge spacing in the clip


def cartridge(p, base, direction, s=1.0, segs=8, full=True, mats=("cart", "bullet", "lead"), up=None):
    """A rimless big-game cartridge from its head along ``direction``:
    brass case (rim, body, shoulder, neck), round-nose soft-point bullet
    (copper jacket, a lead tip). ``s`` scales it (pickups are x1.3).
    ``full=False`` builds only the part above 60 % of the case."""
    d = Vector(direction).normalized()
    b = Vector(base)
    case = [(0.0060, 0.0), (0.0060, 0.0014), (0.0054, 0.0022), (0.0059, 0.0032), (0.00575, 0.047),
            (0.0050, 0.0505), (0.00495, CASE_L)]
    if not full:
        cut = CASE_L * 0.6
        case = [(0.00573, cut)] + [c for c in case if c[1] > cut]
    t0 = case[0][1]
    L = (CASE_L - t0) * s
    kit.seg(p, b + d * (t0 * s), b + d * (CASE_L * s), [(r * s, (t - t0) / (CASE_L - t0)) for r, t in case],
            mats[0], segments=segs)
    bl = [(0.00468, 0.0), (0.00468, 0.35), (0.0041, 0.62), (0.0030, 0.84), (0.0021, 1.0)]
    tip0 = CASE_L + 0.018
    kit.seg(p, b + d * (CASE_L * s), b + d * (tip0 * s), [(r * s, t) for r, t in bl], mats[1], segments=segs,
            caps=False)
    kit.seg(p, b + d * (tip0 * s), b + d * (OAL * s), [(0.0021 * s, 0.0), (0.0016 * s, 0.6), (0.0009 * s, 1.0)],
            mats[2], segments=segs)
    return L


def stripper_clip(p, bottom, up, fwd, n=5, s=1.0, segs=8, mat="clip", mats=("cart", "bullet", "lead")):
    """A steel stripper clip with ``n`` cartridges. ``bottom`` = centre of
    the clip's lower end, ``up`` = along the clip (the cartridges stack
    this way), ``fwd`` = where the bullets point. The clip is a channel
    gripping the rims: back strip, side walls, folded lips, end stops."""
    up = Vector(up).normalized()
    fwd = Vector(fwd).normalized()
    side = fwd.cross(up).normalized()          # right-handed (side, fwd, up)
    b = Vector(bottom)
    length = (n * CLIP_PITCH + 0.0026) * s
    w = (2 * RIM_R + 0.0026) * s
    depth = 0.0042 * s
    t = 0.0008 * s
    # columns of the basis matrix: side (x), fwd (y), up (z)
    from mathutils import Matrix
    basis = Matrix((side, fwd, up)).transposed().to_4x4()
    place = kit.T(b) @ basis
    pieces = []
    pieces += p.box((0, -t / 2, length / 2), (w, t, length), mat, bevel=0.0003)                 # back strip
    for sx in (-1, 1):
        pieces += p.box((sx * (w / 2 - t / 2), depth / 2 - t, length / 2), (t, depth, length), mat)  # walls
        pieces += p.box((sx * (w / 2 - 0.0016 * s), depth - t * 1.5, length / 2), (0.0024 * s, t, length - 0.002 * s),
                        mat)                                                                    # lips
    for z in (t / 2, length - t / 2):
        pieces += p.box((0, depth / 2 - t, z), (w, depth, t), mat)                              # end stops
    p.move(pieces, place)
    for k in range(n):
        c = b + up * ((0.0013 + RIM_R + k * CLIP_PITCH) * s) + fwd * (0.0002 * s)
        cartridge(p, c, fwd, s=s, segs=segs, mats=mats)
    return length


# --------------------------------------------------------------------------
# painted marks
# --------------------------------------------------------------------------

def hexramp(*h):
    return M.hexramp(*h)


RAMPS = {
    # deep, polished charcoal-blue of a best-quality rust-blued rifle
    "blue_deep": hexramp("#04050a", "#080b14", "#0d121f", "#13192b", "#1a2339", "#232f4a", "#2e3c5c",
                         "#3b4b70", "#4d5f86", "#6a7da3"),
    # black buffalo horn / ebony
    "horn": hexramp("#050304", "#0a0607", "#110b0b", "#19110f", "#231814", "#2f2019", "#3c2a1f"),
    # deep chocolate-red exhibition walnut (master finish), golden highlights
    "walnut_fine": hexramp("#0f0806", "#1a0e09", "#26150d", "#331d11", "#412516", "#502e1b", "#603820",
                           "#714327", "#83502f", "#975f39", "#ab7046"),
    "walnut_streak": hexramp("#070403", "#0e0806", "#160c09", "#1f120d"),
    # bright steel in the white (bolt, fittings): cooler, cleaner than armour steel
    "steel_white": hexramp("#1c1f24", "#2a2e35", "#3a3f48", "#4c525c", "#5f6671", "#747b86", "#8a919b",
                           "#a0a7b0", "#b6bcc4", "#cbd0d6", "#dee2e7", "#eef1f4"),
}


def tex_ij(ctx):
    """Integer texel indices of each texel in the island's metre-UV plane."""
    i = np.floor(ctx.uvm[:, 0] / ctx.texel + 1e-6).astype(np.int64)
    j = np.floor(ctx.uvm[:, 1] / ctx.texel + 1e-6).astype(np.int64)
    return i, j


def diamond_lines(ctx, period=3):
    """Crisp 1-texel diagonal lines on the texel grid: hand-cut checkering."""
    i, j = tex_ij(ctx)
    return (np.mod(i + j, period) == 0) | (np.mod(i - j, period) == 0)


def checker_panel(ctx, s, inside, border, period=3, depth=0.0005):
    """Cuts checkering into ``s`` where ``inside`` (bool), with a 1-texel
    border line ``border`` (bool) and a clean margin between them."""
    g = diamond_lines(ctx, period) & inside
    s.shade[g] -= 1.8
    s.shade[inside & ~g] += 0.6                      # the raised diamonds catch light
    s.height = s.height - g * depth
    s.rough = np.where(g, np.minimum(s.rough + 0.25, 1.0), s.rough)
    s.shade[border] -= 2.2
    s.height = s.height - border * depth
    return s


def running_scroll(a, c, texel, L=16.0, H=11.0, A=2.3, Rc=2.4, w=0.5, curls=True):
    """English running scroll as 1-texel lines: a sine vine along ``a``
    with a C-curl in every bay (under each crest, over each trough), rows
    repeating every ``H`` texels across ``c`` (row 0 centred on c = 0,
    rows offset by half a wave). ``curls=False`` puts a single berry in
    each bay instead (narrow bands). ``a``, ``c`` in metres; sizes in
    texels."""
    x = a / texel
    y = c / texel
    row = np.floor(y / H + 0.5)
    yy = y - row * H
    xx = x + row * (L * 0.5)
    k = TAU / L
    f = A * np.sin(k * xx)
    fp = A * k * np.cos(k * xx)
    out = np.abs(yy - f) / np.sqrt(1.0 + fp * fp) < w
    ph = np.mod(xx, L)
    cy = A - Rc - 1.25 if curls else A - 2.6
    for cx, cyy, gap in ((L * 0.25, cy, 0.25 * np.pi), (L * 0.75, -cy, 1.25 * np.pi)):
        dx, dy = ph - cx, yy - cyy
        r = np.hypot(dx, dy)
        if curls:
            opening = np.cos(np.arctan2(dy, dx) - gap) > 0.64
            out |= ((np.abs(r - Rc) < w) & ~opening) | (r < 0.75)
        else:
            out |= np.maximum(np.abs(dx), np.abs(dy)) < 0.75
    return out


def engrave_scroll(ctx, s, a, c, zone, depth=0.0003, shade=3.0, light=0.0, **kw):
    """Cuts a running scroll into ``s`` inside ``zone``: dark 1-texel cut
    lines (optionally with a lit lip one texel off) and the cut in the
    height map, so the normal map shows the relief."""
    t = ctx.texel
    cut = running_scroll(a, c, t, **kw) & zone
    s.shade[cut] -= shade
    if light > 0:
        lip = running_scroll(a + 0.8 * t, c - 0.8 * t, t, **kw) & zone & ~cut
        s.shade[lip] += light
    s.height = s.height - cut * depth
    s.rough = np.where(cut, np.minimum(s.rough + 0.25, 1.0), s.rough)
    return s


def cyl_coords(ctx, theta_c, radius, axis_x=0.0, axis_z=0.0):
    """(along, across) metres on a cylinder round a Y-parallel axis: along
    = y, across = arc length from the angle ``theta_c`` (radians, per
    texel or scalar; 0 = +X, pi/2 = +Z)."""
    th = np.arctan2(ctx.p[:, 2] - axis_z, ctx.p[:, 0] - axis_x)
    d = np.mod(th - theta_c + np.pi, TAU) - np.pi
    return ctx.p[:, 1], d * radius


def edge_band(ctx, lo, hi):
    """Texels between ``lo`` and ``hi`` texels from a convex sharp edge
    (an engraved border line follows the outline of a plate)."""
    d = ctx.convex / ctx.texel
    return (d >= lo) & (d < hi)


def engrave(s, mask, depth=0.0003, shade=3.0):
    s.shade[mask] -= shade
    s.height = s.height - mask * depth
    s.rough = np.where(mask, np.minimum(s.rough + 0.25, 1.0), s.rough)
    return s


def inlay(ctx, s, mask, ramp="gold", center=7.2):
    """Gold wire inlay: a ramp swap on ``mask``, slightly proud."""
    s.use_ramp(M.P[ramp], mask=mask, shade=np.full(ctx.N, center) + M._dither(ctx, 0.8, 977)
               + ctx.edge(1.0) * 1.2)
    s.metal = np.where(mask, 1.0, s.metal)
    s.rough = np.where(mask, 0.18, s.rough)
    s.height = s.height + mask * 0.0001
    return s


def polished(ctx, ramp, center, seed, polish=0.1, cloud=0.6, edge=2.2, ao=3.0, cavity=2.0, dither=0.35):
    """Mirror-polished metal: faint cloud, bright rolled edges, clean."""
    s = Surface(ctx.N)
    c = ctx.fbm(3.0, 3, seed)
    shade = center + c * cloud + M._dither(ctx, dither, seed + 1)
    shade += ctx.edge(1.0) * edge + ctx.edge(2.0) * edge * 0.35
    shade -= ctx.cavity(3.0) * cavity + (1.0 - ctx.ao) * ao
    s.use_ramp(ramp, shade=shade)
    s.metal = np.full(ctx.N, 1.0)
    s.rough = polish + np.clip(c, 0, 1) * 0.05 + ctx.rand(seed + 2) * 0.02
    return s


def engine_turned(ctx, s, cell=0.0075):
    """Jewelling: overlapping polished discs in offset rows, each with a
    bright crescent and a dark rim (in the metre-UV plane)."""
    u = ctx.uvm[:, 0] / cell
    v = ctx.uvm[:, 1] / cell
    row = np.floor(v)
    uu = u + np.mod(row, 2) * 0.5
    fu, fv = uu - np.floor(uu) - 0.5, v - row - 0.5
    r = np.hypot(fu, fv * 1.15)
    ang = np.arctan2(fv, fu)
    crescent = (r > 0.18) & (r < 0.42) & (np.cos(ang - 0.8) > 0.2)
    rim = (r >= 0.42)
    s.shade += crescent * 1.6 - rim * 1.4
    s.height = s.height - rim * 0.00008
    s.rough = np.where(crescent, s.rough * 0.7, s.rough)
    return s
