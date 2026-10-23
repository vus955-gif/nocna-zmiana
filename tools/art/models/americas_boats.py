"""Floor I, the Americas and Oceania wing: the boats on display (generic
stylisations, no particular vessel copied).

  kayak        an Arctic skin kayak: a long low hull of sewn sealskin over
               the frame, a sharp up-turned bow and stern, the deck crowned
               a little, a round wooden coaming at the cockpit, thongs
               across the deck with bone toggles, a narrow double-bladed
               paddle laid along the deck under them. 0.62 x 0.4 x 5.0 m
               (Godot x, y, z) in the greybox kayak box 0.7 x 0.4 x 5.0;
               its keel's lowest point on the floor (the stand's cradles
               under it). 256 px/m.
  kayak_stand  its museum stand: a low basalt plinth 1.0 x 0.25 x 5.4 with
               two driftwood cradles hollowed to the keel and padded with
               felt, a brass label "KAJAK / ARKTYKA" on the side to the hall
               (-x). 1.0 x 0.93 x 5.4 m: built for the greybox pedestal 1.0 x
               0.9 x 5.4 (its pads meet the kayak's keel a hair over the
               pedestal's top, where the kayak's box starts). 128 px/m.
  whaleboat    a New England whaleboat on two trestles: double-ended,
               lapstrake planking painted white under a dark sheer strake,
               a natural grey-green inside with ribs, five thwarts, the
               loggerhead post in the stern, two line tubs of coiled
               manila, four oars and the long steering oar laid along the
               thwarts, two irons in the bow's crotch. 1.7 x 1.3 x 6.9 m in
               the greybox box 1.8 x 1.3 x 7.0. 128 px/m.

Kit convention: origin = the middle of the footprint on the floor, built
front +Y in Blender (= Godot -Z: the bow).
"""
import math

import numpy as np
from mathutils import Vector

from artlib import americas as AM
from artlib import kit as K
from artlib import materials as M
from artlib import pixelfont
from artlib.archkit import kit
from artlib.geo import Part
from artlib.materials import P, _dither, hexramp, smoothstep

P.update({
    # sealskin: oiled, translucent tan with darker seams and stains
    "kayak_skin": hexramp("#24170c", "#352312", "#473018", "#5a3e1f", "#6e4d27", "#835d31", "#966d3c", "#a87e49",
                          "#b88f58"),
    # the whaleboat's paint: white lead gone ivory, the black sheer strake
    "boat_white": hexramp("#3c3a33", "#56534a", "#716d62", "#8b877b", "#a4a093", "#bcb8aa", "#d1cdbf", "#e2ded1"),
    "boat_inside": hexramp("#1e221c", "#2a3027", "#363e33", "#434c3f", "#515b4c", "#5f6a59", "#6e7967", "#7d8875"),
})

# --------------------------------------------------------------------------
# the kayak (Blender: y along the hull, the bow +Y)
# --------------------------------------------------------------------------

K_LEN = 5.0
K_BEAM = 0.62
K_GUNWALE = 0.26        # the deck's edge over the keel amidships
K_CROWN = 0.05          # the deck's crown over its edge
K_STATIONS = 30
K_AROUND = 16
COCKPIT = (0.0, -0.25)   # (x, y) of the cockpit's middle (a little aft)
COAMING = (0.24, 0.3)    # half width, half length of the coaming's ring


def k_half(t):
    """Half beam at t (-1 stern .. 1 bow); widest a little aft of the middle,
    both ends sharp."""
    u = (t + 0.08) / 1.08 if t > -0.08 else (t + 0.08) / 0.92
    return K_BEAM * 0.5 * max(0.0, 1.0 - abs(u) ** 2.4) ** 0.62


def k_keel(t):
    """The keel line, sweeping up into the sharp ends."""
    return 0.3 * abs(t) ** 5


def k_edge(t):
    """The deck's edge (sheer) rising to the up-turned ends."""
    return K_GUNWALE + 0.085 * abs(t) ** 4.5


def kayak_ring(t):
    """A closed section at t: from the starboard deck edge over the deck to
    port, then down the hull through the keel and back."""
    b = max(k_half(t), 0.006)
    zk, ze = k_keel(t), k_edge(t)
    crown = K_CROWN * (b / (K_BEAM * 0.5))
    pts = []
    for k in range(K_AROUND):
        a = 2 * math.pi * k / K_AROUND
        c, s = math.cos(a), math.sin(a)
        x = b * math.copysign(abs(c) ** 0.75, c)
        if s >= 0:
            z = ze + crown * s ** 1.5
        else:
            # a soft V: the chines lower down, the keel line
            z = ze + (ze - zk) * -(abs(s) ** 0.7)
        pts.append((x, z))
    return pts


def _strip_uvs(p, f, cells, us, vs):
    """Locks face ``f``'s UVs (metres): ``cells`` = its verts in loop order
    with their (station, index) grid places, us / vs = u per station, v per
    (station, index)."""
    by = {v: c for v, c in cells}
    for loop in f.loops:
        j, k = by[loop.vert]
        loop[p.uv].uv = (us[j], vs[j][k])
    f[p.lock] = 1


def _arc(points):
    """Cumulative length along a polyline of (x, z) points."""
    out = [0.0]
    for (x0, z0), (x1, z1) in zip(points[:-1], points[1:]):
        out.append(out[-1] + math.hypot(x1 - x0, z1 - z0))
    return out


def kayak_hull(p):
    rows = []
    rings = []
    ts = [-1.0 + 2.0 * i / K_STATIONS for i in range(K_STATIONS + 1)]
    for t in ts:
        y = t * K_LEN * 0.5
        ring = kayak_ring(t)
        rings.append(_arc(ring + [ring[0]]))
        rows.append([p.bm.verts.new((x, y, z)) for x, z in ring])
    # UVs: u along the hull, restarting every BREAK stations (short islands
    # pack tight), v round the section from the starboard deck edge
    brk = 6
    for j in range(len(rows) - 1):
        base = (j // brk) * brk * K_LEN / K_STATIONS
        us = {j: j * K_LEN / K_STATIONS - base, j + 1: (j + 1) * K_LEN / K_STATIONS - base}
        vs = {j: rings[j], j + 1: rings[j + 1]}
        for k in range(K_AROUND):
            k2 = (k + 1) % K_AROUND
            a = 2 * math.pi * (k + 0.5) / K_AROUND
            slot = "deck" if math.sin(a) > 0 else "skin"
            quad = [(rows[j][k], (j, k)), (rows[j][k2], (j, k + 1)), (rows[j + 1][k2], (j + 1, k + 1)),
                    (rows[j + 1][k], (j + 1, k))]
            f = p._face([q[0] for q in quad], slot, smooth=True)
            f.normal_update()
            c = f.calc_center_median()
            mid = Vector((0.0, c.y, (k_keel(c.y / (K_LEN * 0.5)) + k_edge(c.y / (K_LEN * 0.5))) * 0.5))
            if f.normal.dot(c - mid) < 0:
                f.normal_flip()
            _strip_uvs(p, f, quad, us, vs)
    # the ends: the up-turned stem and stern closed by a sliver face
    for row, sign in ((rows[0], -1.0), (rows[-1], 1.0)):
        f = p._face(list(row), "skin")
        f.normal_update()
        if f.normal.y * sign < 0:
            f.normal_flip()


def deck_z(x, y):
    """The deck's height at (x, y) (its crown)."""
    t = y / (K_LEN * 0.5)
    b = max(k_half(t), 0.006)
    crown = K_CROWN * (b / (K_BEAM * 0.5))
    u = min(1.0, abs(x) / b)
    # (the ring's top: x = b c^0.75, z = ze + crown s^1.5 with s = sqrt(1 - c^2))
    c = u ** (1 / 0.75)
    s = math.sqrt(max(0.0, 1.0 - c * c))
    return k_edge(t) + crown * s ** 1.5


def kayak_top(p):
    cx, cy = COCKPIT
    hw, hl = COAMING
    z0 = deck_z(0.0, cy)
    # the cockpit's dark opening and the coaming round it (steam-bent wood)
    ring_in, ring_out = [], []
    n = 20
    for k in range(n):
        a = 2 * math.pi * k / n
        x, y = cx + math.cos(a) * hw, cy + math.sin(a) * hl
        zd = deck_z(x, y)
        ring_in.append((x * 0.9, cy + (y - cy) * 0.93, zd))
        ring_out.append((x, y, zd))
    top = max(z for _, _, z in ring_in) + 0.004
    hole = p._face([p.bm.verts.new((x, y, top)) for x, y, _ in ring_in], "hole")
    hole.normal_update()
    if hole.normal.z < 0:
        hole.normal_flip()
    pts = [(x, y, z + 0.03) for x, y, z in ring_out] + [(ring_out[0][0], ring_out[0][1], ring_out[0][2] + 0.03)]
    p.tube(pts, 0.022, "coaming", sides=6, caps=False)
    # thongs across the deck with bone toggles, fore and aft of the cockpit
    for y in (0.55, 0.85, 1.15, 1.45, -0.75, -1.05, -1.35):
        t = y / (K_LEN * 0.5)
        b = k_half(t)
        path = [(u * b * 0.98, y, deck_z(u * b * 0.98, y) + 0.008) for u in (-1.0, -0.6, -0.2, 0.2, 0.6, 1.0)]
        p.tube(path, 0.007, "thong", sides=4, caps=False)
        p.box((b * 0.45, y, deck_z(b * 0.45, y) + 0.016), (0.05, 0.016, 0.014), "bone", bevel=0.004)
    # the double-bladed paddle along the fore deck, under the thongs
    x0, x1 = 0.06, -0.03
    y0, y1 = 0.16, 2.2
    def at(f):
        x, y = x0 + (x1 - x0) * f, y0 + (y1 - y0) * f
        return (x, y, deck_z(x, y) + 0.03)
    shaft = [at(f) for f in (0.28, 0.5, 0.72)]
    p.tube(shaft, 0.017, "paddle", sides=6)
    for f0, f1 in ((0.0, 0.3), (0.7, 1.0)):
        a, b = Vector(at(f0)), Vector(at(f1))
        mid = (a + b) * 0.5
        d = (b - a)
        ln = d.length
        f = p.box(tuple(mid), (0.075, ln, 0.012), "paddle", bevel=0.004)
        ang = math.atan2(d.x, d.y)
        p.move(f, K.T(*mid) @ K.R('Z', -math.degrees(ang)) @ K.R('X', math.degrees(math.atan2(d.z, ln))) @ K.T(*(-mid)))


def kayak():
    p = Part("kayak")
    kayak_hull(p)
    kayak_top(p)
    return p


CRADLE_Y = 1.3           # the stand's cradles, either side of the middle
STAND_TOP = 0.9          # the greybox pedestal's top: the kayak's box starts here


def stand():
    p = Part("kayak_stand")
    base = 0.25
    L = 5.4
    p.box((0.0, 0.0, base * 0.5), (1.0, L, base), "basalt", bevel=0.012)
    p.box((-0.5 - 0.004, 0.0, base * 0.55), (0.012, 0.36, 0.11), "plaque", bevel=0.003)   # to the hall (-x)
    for y in (-CRADLE_Y, CRADLE_Y):
        t = y / (K_LEN * 0.5)
        # the hull's underside across the cradle (from the kayak's own section)
        lower = sorted((rx, rz) for rx, rz in kayak_ring(t) if rz <= k_edge(t) + 1e-6)
        xs = np.linspace(-0.12, 0.12, 7)
        zs = STAND_TOP + np.interp(xs, [q[0] for q in lower], [q[1] for q in lower])
        keel = float(zs.min())
        # two splayed legs and a cross beam under the cradle board
        for sx in (-1, 1):
            p.tube([(sx * 0.34, y, base), (sx * 0.1, y, keel - 0.09)], 0.03, "wood", sides=6)
        p.box((0.0, y, base + 0.18), (0.6, 0.06, 0.06), "wood", bevel=0.008)
        # the cradle board, hollowed a little to the keel, a felt pad on it
        for xa, za, xb, zb in zip(xs[:-1], zs[:-1], xs[1:], zs[1:]):
            mid = ((xa + xb) * 0.5, y, (za + zb) * 0.5 - 0.035)
            ln = math.hypot(xb - xa, zb - za)
            rot = K.T(*mid) @ K.R('Y', -math.degrees(math.atan2(zb - za, xb - xa))) @ K.T(*(-v for v in mid))
            p.move(p.box(mid, (ln + 0.004, 0.09, 0.05), "wood", bevel=0.004), rot)
            p.move(p.box((mid[0], y, mid[2] + 0.029), (ln + 0.004, 0.1, 0.008), "felt"), rot)
    return p


# --------------------------------------------------------------------------
# kayak paint
# --------------------------------------------------------------------------

def skin(ctx):
    """Oiled sealskin stretched over the frame: tan, translucent, the ribs
    and stringers showing as faint lines, sewn seams, darker stains."""
    s = M.Surface(ctx.N)
    x, y, z = ctx.p[:, 0], ctx.p[:, 1], ctx.p[:, 2]
    # the frame faintly through the skin: ribs across, a chine stringer low
    # on each side; the skins sewn end to end and along the keel
    ribs = np.abs(np.mod(y / 0.11, 1.0) - 0.5) < 0.06
    up = ctx.n[:, 2]
    chine = (np.abs(up + 0.35) < 0.08) & (up < 0.0)
    seam = (np.abs(np.mod(y / 1.15 + 0.3, 1.0) - 0.5) < 0.012) | ((np.abs(x) < 0.006) & (up < 0.0))
    shade = 5.0 + ctx.fbm(3.0, 3, 6211) * 1.3 + ctx.fbm(14.0, 2, 6213) * 0.6 + _dither(ctx, 0.5, 6215)
    shade -= ribs * 0.4 + chine * 0.6 + seam * 1.8 + (1.0 - ctx.ao) * 3.0
    shade -= smoothstep(0.1, 0.0, z) * 0.8
    s.use_ramp(P["kayak_skin"], shade=shade)
    s.rough = 0.45 + ctx.rand(6217) * 0.06
    s.height = -seam.astype(np.float64) * 0.0006 + ribs * 0.0002 + chine * 0.0003
    return s


def deck(ctx):
    s = skin(ctx)
    s.shade -= 0.5
    return s


def hole(ctx):
    s = M.Surface(ctx.N)
    s.use_ramp(P["kayak_skin"], shade=np.full(ctx.N, 0.2) + _dither(ctx, 0.4, 6221))
    s.rough = np.full(ctx.N, 0.9)
    return s


_LABEL = {}


def stand_plaque(ctx):
    s = M.brass(ctx, 6231)
    front = ctx.n[:, 0] < -0.5
    if "t" not in _LABEL:
        _LABEL["t"] = pixelfont.trim(pixelfont.render(["KAJAK", "ARKTYKA"], line_gap=2))
    if front.any():
        u, v = ctx.uvm[:, 0], ctx.uvm[:, 1]
        ink = pixelfont.stamp(ctx, _LABEL["t"], np.median(u[front]), np.median(v[front]), scale=1) & front
        s.use_ramp(P["am_obsidian"], mask=ink, shade=np.full(ctx.N, 1.0))
        s.metal = np.where(ink, 0.0, s.metal)
    return s


KAYAK_FNS = {
    "skin": skin, "deck": deck, "hole": hole, "coaming": lambda c: AM.carved_wood(c, 6241, "am_wood", 5.2, adze=0.0),
    "thong": lambda c: M.leather(c, 6243), "bone": lambda c: M.ivory(c, 6245, center=5.8),
    "paddle": lambda c: AM.carved_wood(c, 6247, "am_wood", 5.6, adze=0.2),
}
STAND_FNS = {
    "basalt": lambda c: AM.basalt(c, 6251, center=3.6, polish=0.3, vesicles=0.2), "plaque": stand_plaque,
    "wood": lambda c: AM.carved_wood(c, 6253, "am_wood_dark", 4.6, adze=0.4),
    "felt": lambda c: M.cloth(c, "cloth_red", 2.6, 6255),
}


# --------------------------------------------------------------------------
# the whaleboat (Blender: y along the hull, the bow +Y)
# --------------------------------------------------------------------------

W_LEN = 6.9
W_BEAM = 1.7
TRESTLE = 0.4           # the keel's lowest point over the floor
W_DEPTH = 0.84          # keel to gunwale amidships
W_THICK = 0.035
W_STATIONS = 32
W_AROUND = 14


def w_half(t):
    return W_BEAM * 0.5 * max(0.0, 1.0 - abs(t) ** 2.1) ** 0.55


def w_keel(t):
    return TRESTLE + 0.17 * abs(t) ** 4


def w_sheer(t):
    return TRESTLE + W_DEPTH + 0.04 * abs(t) ** 3


def w_section(t, inset=0.0):
    """The open U from the port gunwale through the keel to starboard."""
    b = max(w_half(t) - inset, 0.004)
    zk = w_keel(t) + inset
    zs = w_sheer(t)
    pts = []
    for i in range(W_AROUND + 1):
        phi = -math.pi / 2 + math.pi * i / W_AROUND
        s = math.sin(phi)
        x = b * math.copysign(abs(s) ** 0.85, s)
        z = zk + (zs - zk) * (1.0 - abs(math.cos(phi)) ** 0.55)
        pts.append((x, z))
    return pts


def whale_hull(p):
    ts = [-1.0 + 2.0 * i / W_STATIONS for i in range(W_STATIONS + 1)]
    outer = [[p.bm.verts.new((x, t * W_LEN * 0.5, z)) for x, z in w_section(t)] for t in ts]
    inner = [[p.bm.verts.new((x, t * W_LEN * 0.5, z)) for x, z in w_section(t, W_THICK)] for t in ts]
    arcs = {"hull": [_arc(w_section(t)) for t in ts], "inside": [_arc(w_section(t, W_THICK)) for t in ts]}
    m = W_AROUND + 1
    brk = 8
    for j in range(len(ts) - 1):
        base = (j // brk) * brk * W_LEN / W_STATIONS
        us = {j: j * W_LEN / W_STATIONS - base, j + 1: (j + 1) * W_LEN / W_STATIONS - base}
        for i in range(m - 1):
            for rows, slot, sign in ((outer, "hull", 1.0), (inner, "inside", -1.0)):
                quad = [(rows[j][i], (j, i)), (rows[j + 1][i], (j + 1, i)), (rows[j + 1][i + 1], (j + 1, i + 1)),
                        (rows[j][i + 1], (j, i + 1))]
                f = p._face([q[0] for q in quad], slot, smooth=True)
                f.normal_update()
                c = f.calc_center_median()
                mid = Vector((0.0, c.y, w_keel(c.y / (W_LEN * 0.5)) + 0.45))
                if f.normal.dot(c - mid) * sign < 0:
                    f.normal_flip()
                _strip_uvs(p, f, quad, us, {j: arcs[slot][j], j + 1: arcs[slot][j + 1]})
        for i in (0, m - 1):
            f = p._face([outer[j][i], inner[j][i], inner[j + 1][i], outer[j + 1][i]], "gunwale")
            f.normal_update()
            if f.normal.z < 0:
                f.normal_flip()
    # the stem and the sternpost closing the ends
    for sign in (-1.0, 1.0):
        y = sign * (W_LEN * 0.5 - 0.02)
        p.box((0.0, y, (w_keel(sign) + w_sheer(sign)) * 0.5), (0.07, 0.1, w_sheer(sign) - w_keel(sign) + 0.04),
              "gunwale", bevel=0.01)
    # a rubbing strake (the gunwale's wale) outside the sheer
    for sx in (-1, 1):
        path = []
        for i in range(W_STATIONS + 1):
            t = -0.97 + 1.94 * i / W_STATIONS
            path.append((sx * (w_half(t) + 0.012), t * W_LEN * 0.5, w_sheer(t) - 0.03))
        p.tube(path, 0.025, "gunwale", sides=5)


def whale_fittings(p):
    # ribs inside (frames), every 0.35 m, following the inner section
    for k in range(-8, 9):
        t = k * 0.35 / (W_LEN * 0.5)
        pts = [(x * 0.985, t * W_LEN * 0.5, z + 0.008) for x, z in w_section(t, W_THICK)]
        p.tube(pts[1:-1], 0.014, "rib", sides=4, caps=False)
    # five thwarts across, a hand under the gunwale
    for t in (-0.55, -0.27, 0.0, 0.27, 0.52):
        b = w_half(t) - W_THICK - 0.01
        y = t * W_LEN * 0.5
        z = w_sheer(t) - 0.24
        p.box((0.0, y, z), (2 * b, 0.22, 0.035), "thwart", bevel=0.006)
    # the loggerhead post in the stern sheets
    y = -0.78 * W_LEN * 0.5
    K.seg(p, (0.0, y, w_keel(-0.78) + 0.1), (0.0, y, w_sheer(-0.78) + 0.03), [(0.06, 0.0), (0.06, 0.85), (0.075, 0.9),
                                                                             (0.05, 1.0)], "thwart", segments=8)
    # two line tubs of coiled manila between the thwarts
    for t, r in ((-0.4, 0.26), (0.13, 0.22)):
        y = t * W_LEN * 0.5
        z0 = w_keel(t) + 0.1
        p.lathe([(r * 0.92, 0.0), (r, 0.36), (r * 0.98, 0.37), (r * 0.9, 0.37), (r * 0.9, 0.33)], "tub", segments=14,
                center=(0.0, y, z0), cap_bottom=True, cap_top=False)
        p.lathe([(0.0, 0.0), (r * 0.9, 0.0)], "line", segments=14, center=(0.0, y, z0 + 0.33), cap_bottom=False,
                cap_top=False)
    # oars along the thwarts: four pulling oars, the steering oar to the stern
    for sx, dy in ((-0.34, 0.0), (-0.18, 0.12), (0.18, -0.08), (0.34, 0.05)):
        y0, y1 = -2.6 + dy, 2.55 + dy
        z = w_sheer(0.0) - 0.2
        p.tube([(sx, y0, z), (sx * 0.95, y1 - 0.75, z)], 0.024, "oar", sides=6)
        p.box((sx * 0.95, y1 - 0.38, z + 0.004), (0.12, 0.75, 0.016), "oar", bevel=0.005)
    ys = -W_LEN * 0.5 + 0.1
    p.tube([(0.05, ys + 0.1, w_sheer(-1.0) - 0.04), (0.1, 1.5, w_sheer(0.4) - 0.18)], 0.03, "oar", sides=6)
    p.box((0.05, ys + 0.5, w_sheer(-1.0) - 0.05), (0.16, 0.9, 0.02), "oar", bevel=0.006)
    # two irons resting in the crotch at the bow
    yb = 0.82 * W_LEN * 0.5
    zc = w_sheer(0.82) - 0.03
    for sx in (-1, 1):
        p.box((sx * (w_half(0.82) - 0.08), yb, zc - 0.05), (0.04, 0.05, 0.14), "iron", bevel=0.006)
    for dx in (-0.04, 0.04):
        p.tube([(dx, yb - 1.3, zc + 0.03), (dx, yb + 0.25, zc + 0.03)], 0.02, "oar", sides=6)
        p.tube([(dx, yb + 0.25, zc + 0.03), (dx, yb + 0.5, zc + 0.03)], 0.009, "iron", sides=5)
        K.cone(p, (dx, yb + 0.5, zc + 0.03), (0.0, 1.0, 0.0), 0.09, 0.03, "iron", segments=4, tip=0.002)
    p.box((0.0, yb, zc + 0.0), (2 * (w_half(0.82) - 0.06), 0.06, 0.03), "iron", bevel=0.005)


def trestles(p):
    for y in (-2.05, 2.05):
        t = y / (W_LEN * 0.5)
        sec = w_section(t)
        lower = sorted((x, z) for x, z in sec if z < w_keel(t) + 0.45)
        # the cradle board notched to the hull
        xs = np.linspace(-0.5, 0.5, 9)
        zs = np.interp(xs, [q[0] for q in lower], [q[1] for q in lower])
        for xa, za, xb, zb in zip(xs[:-1], zs[:-1], xs[1:], zs[1:]):
            mid = ((xa + xb) * 0.5, y, (za + zb) * 0.5 - 0.05)
            ln = math.hypot(xb - xa, zb - za)
            f = p.box(mid, (ln + 0.006, 0.12, 0.08), "trestle", bevel=0.006)
            p.move(f, K.T(*mid) @ K.R('Y', -math.degrees(math.atan2(zb - za, xb - xa))) @ K.T(*(-v for v in mid)))
        for sx in (-1, 1):
            p.tube([(sx * 0.62, y, 0.04), (sx * 0.4, y, zs[0 if sx < 0 else -1] - 0.05)], 0.04, "trestle", sides=6)
            p.box((sx * 0.62, y, 0.03), (0.16, 0.18, 0.06), "trestle", bevel=0.008)
        p.box((0.0, y, 0.2), (1.1, 0.08, 0.08), "trestle", bevel=0.008)


def whaleboat():
    p = Part("whaleboat")
    whale_hull(p)
    whale_fittings(p)
    trestles(p)
    return p


def hull_paint(ctx):
    """Lapstrake planking painted white, a black sheer strake, the lands of
    the strakes shadowed, worn to the wood at the keel and the ends."""
    z = ctx.p[:, 2]
    y = ctx.p[:, 1]
    s = M.Surface(ctx.N)
    t = np.clip(np.abs(y) / (W_LEN * 0.5), 0, 1)
    keel = TRESTLE + 0.17 * t ** 4
    sheer = TRESTLE + W_DEPTH + 0.04 * t ** 3
    f = np.clip((z - keel) / np.maximum(sheer - keel, 1e-3), 0, 1)
    strake = np.floor(f * 9.0)
    land = np.mod(f * 9.0, 1.0) < 0.08
    shade = 5.6 + (np.mod(strake * 0.37, 1.0) - 0.5) * 0.6 + ctx.fbm(4.0, 3, 6311) * 0.6 + _dither(ctx, 0.5, 6313)
    shade -= land * 2.2 + (1.0 - ctx.ao) * 3.0
    s.use_ramp(P["boat_white"], shade=shade)
    black = f > 0.86
    s.use_ramp(P["leather"], mask=black, shade=3.0 + ctx.fbm(9.0, 2, 6315) * 0.8 + _dither(ctx, 0.5, 6317) - land * 1.0)
    worn = (ctx.fbm(5.0, 3, 6319) + (f < 0.08) * 0.6 + ctx.edge_soft(3.0) * 0.4) > 0.75
    wood = AM.carved_wood(ctx.subset(worn), 6321, "am_wood", 4.2, adze=0.0) if worn.any() else None
    if wood is not None:
        s.merge(wood, worn)
    s.rough = np.where(black, 0.5, 0.62)
    s.height = -land.astype(np.float64) * 0.0012
    return s


def inside_paint(ctx):
    s = M.Surface(ctx.N)
    z = ctx.p[:, 2]
    shade = 4.6 + ctx.fbm(3.0, 3, 6331) * 0.9 + ctx.fbm(20.0, 2, 6333) * 0.4 + _dither(ctx, 0.5, 6335)
    shade -= (1.0 - ctx.ao) * 3.5 + smoothstep(0.9, 0.45, z) * 0.8
    s.use_ramp(P["boat_inside"], shade=shade)
    s.rough = np.full(ctx.N, 0.72)
    return s


def tub(ctx):
    s = AM.carved_wood(ctx, 6341, "am_wood", 4.4, adze=0.0)
    hoops = np.abs(np.mod(ctx.p[:, 2] / 0.12, 1.0) - 0.5) < 0.08
    s.use_ramp(P["iron"], mask=hoops, shade=np.full(ctx.N, 3.0) + _dither(ctx, 0.5, 6343))
    return s


WHALE_FNS = {
    "hull": hull_paint, "inside": inside_paint,
    "gunwale": lambda c: AM.carved_wood(c, 6361, "am_wood_dark", 4.0, adze=0.0),
    "rib": lambda c: AM.carved_wood(c, 6363, "am_wood", 4.0, adze=0.0),
    "thwart": lambda c: AM.carved_wood(c, 6365, "am_wood", 5.0, adze=0.0),
    "tub": tub, "line": lambda c: AM.rope(c, 6367, center=5.4), "oar": lambda c: AM.carved_wood(c, 6369, "am_wood", 5.6, adze=0.0),
    "iron": lambda c: AM.iron_old(c, 6371), "trestle": lambda c: AM.carved_wood(c, 6373, "am_wood_dark", 4.4, adze=0.5),
}


def build():
    return [
        kit("kayak", [kayak()], KAYAK_FNS, ppm=256, built_final=True, ground=None, ao_dist=0.15, ao_rays=10,
            ao_stride=2),
        kit("kayak_stand", [stand()], STAND_FNS, ppm=128, built_final=True, ground=0.0, ao_dist=0.2, ao_rays=8),
        kit("whaleboat", [whaleboat()], WHALE_FNS, ppm=128, built_final=True, ground=0.0, ao_dist=0.3, ao_rays=10,
            ao_stride=2),
    ]
