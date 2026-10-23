"""Floor I, the Assyrian wing's Lion Hunt hall: the props down in the
hunting pit, after the Nineveh lion-hunt reliefs (a generic stylisation,
no particular slab copied).

  asy_chariot  the king's hunting chariot as the museum shows it (no yoke,
               no team): a cedar cab rounded at the front, a narrow step-in
               between two boards at the back, its panels painted red with
               a band of white rosettes on lapis and a chequer at the foot,
               a bronze rail; two quivers crossed on its right side; the
               axle at the back of the cab between two great eight-spoked
               wheels with bronze-studded tyres; the pole rising forward to
               its bronze finial, resting on a little cedar trestle. 1.74 x
               1.55 x 3.08 m (Godot x, y, z) in the greybox box 1.8 x 1.6 x
               3.2; the pole points -Z. Its collision is drawn from it in
               three columns (Floor1Art.FIT_COLUMNS): the wheels apart from
               the cab and the pole. 256 px/m.
  asy_cage     the lions' cage of the hunt: a heavy cedar frame bound with
               iron, round wooden bars, a sliding gate on its front (-Z)
               raised a hand in its grooves, the keeper's little hutch of
               bars on its roof, a plank floor. 1.72 x 1.79 x 1.77 m in the
               greybox box 1.8^3. 128 px/m.

Kit convention: origin = the middle of the footprint on the floor; built
front +Y in Blender (= Godot -Z).
"""
import math

import numpy as np
from mathutils import Vector

from artlib import asy
from artlib import kit as K
from artlib import materials as M
from artlib.archkit import kit
from artlib.geo import Part
from artlib.materials import P, _dither, smoothstep

# --------------------------------------------------------------------------
# the chariot (Blender: x across, y forward along the pole, z up)
# --------------------------------------------------------------------------

WHEEL_R = 0.6
TYRE_IN = 0.53
TYRE_W = 0.09
AXLE_Z = 0.625
AXLE_Y = -0.92
WHEEL_X = 0.76
CAB_BACK = -1.13        # the open back of the cab
CAB_ARC_Y = -0.36       # where the straight sides meet the rounded front
CAB_HALF = 0.48         # half width of the cab (the front's radius)
CAB_FLOOR = 0.66
CAB_TOP = 1.42
WALL = 0.036
SPOKES = 8
STEP_IN = 0.2           # half width of the gap at the back of the cab


def _quad(p, verts, uvs, mat, out, smooth=True):
    """A quad of four bmesh verts with UVs in metres, wound to face ``out``."""
    f = p._face(list(verts), mat, smooth)
    f.normal_update()
    flip = f.normal.dot(Vector(out)) < 0
    if flip:
        f.normal_flip()
    by_vert = dict(zip(verts, uvs))
    for loop in f.loops:
        loop[p.uv].uv = by_vert[loop.vert]
    f[p.lock] = 1
    return f


def cab_outline(n_arc=12):
    """The cab wall's middle line seen from above, from the back of the left
    side round the front to the back of the right side: [(x, y), ...] and
    the arc length at each point (s)."""
    pts = [(-CAB_HALF, CAB_BACK), (-CAB_HALF, CAB_ARC_Y)]
    for k in range(1, n_arc):
        a = math.pi - math.pi * k / n_arc
        pts.append((CAB_HALF * math.cos(a), CAB_ARC_Y + CAB_HALF * math.sin(a)))
    pts += [(CAB_HALF, CAB_ARC_Y), (CAB_HALF, CAB_BACK)]
    s = [0.0]
    for (x0, y0), (x1, y1) in zip(pts[:-1], pts[1:]):
        s.append(s[-1] + math.hypot(x1 - x0, y1 - y0))
    return pts, s


def _normals(pts):
    """Outward plan normals at each outline point (away from the cab's middle)."""
    out = []
    c = Vector((0.0, (CAB_BACK + CAB_ARC_Y) * 0.5))
    for i, (x, y) in enumerate(pts):
        a = Vector(pts[max(0, i - 1)])
        b = Vector(pts[min(len(pts) - 1, i + 1)])
        t = (b - a).normalized()
        n = Vector((t.y, -t.x))
        if n.dot(Vector((x, y)) - c) < 0:
            n = -n
        out.append(n)
    return out


def cab(p):
    pts, s = cab_outline()
    ns = _normals(pts)
    h = WALL * 0.5
    z0, z1 = CAB_FLOOR, CAB_TOP
    outer, inner = [], []
    for (x, y), n in zip(pts, ns):
        o = Vector((x, y)) + n * h
        q = Vector((x, y)) - n * h
        outer.append((p.bm.verts.new((o.x, o.y, z0)), p.bm.verts.new((o.x, o.y, z1))))
        inner.append((p.bm.verts.new((q.x, q.y, z0)), p.bm.verts.new((q.x, q.y, z1))))
    for i in range(len(pts) - 1):
        out = ((ns[i] + ns[i + 1]) * 0.5).to_3d()
        uv = [(s[i], z0), (s[i + 1], z0), (s[i + 1], z1), (s[i], z1)]
        _quad(p, [outer[i][0], outer[i + 1][0], outer[i + 1][1], outer[i][1]], uv, "panel", out)
        _quad(p, [inner[i][0], inner[i + 1][0], inner[i + 1][1], inner[i][1]], uv, "cedar", -out)
        _quad(p, [outer[i][1], outer[i + 1][1], inner[i + 1][1], inner[i][1]],
              [(s[i], 0.0), (s[i + 1], 0.0), (s[i + 1], WALL), (s[i], WALL)], "cedar", (0.0, 0.0, 1.0), smooth=False)
    # two boards closing the back either side of a narrow step-in
    for sx in (-1, 1):
        x0, x1 = sx * (CAB_HALF - h), sx * STEP_IN
        p.box(((x0 + x1) * 0.5, CAB_BACK, (z0 + z1 - 0.06) * 0.5), (abs(x1 - x0), WALL, z1 - 0.06 - z0), "panel",
              bevel=0.006)
    # the back edges of the sides
    for i in (0, len(pts) - 1):
        f = p._face([outer[i][0], inner[i][0], inner[i][1], outer[i][1]], "cedar")
        f.normal_update()
        if f.normal.y > 0:
            f.normal_flip()
    # the floor (a hair inside the walls) and the bronze rail along the top
    floor = [(x, y) for x, y in pts]
    p.ngon_prism([(x * 0.97, y if y < CAB_BACK + 0.01 else y - 0.01) for x, y in floor][::-1], CAB_FLOOR - 0.06,
                 CAB_FLOOR + 0.005, "cedar")
    rail = [(x, y, CAB_TOP + 0.012) for x, y in pts]
    p.tube(rail, 0.024, "bronze", sides=6)
    # bronze corner guards at the back, a grab handle on each back post
    for sx in (-1, 1):
        p.box((sx * CAB_HALF, CAB_BACK + 0.03, (z0 + z1) * 0.5), (0.06, 0.07, z1 - z0 + 0.02), "bronze", bevel=0.008)
        p.tube([(sx * (CAB_HALF - 0.02), CAB_BACK + 0.04, z1 + 0.01), (sx * (CAB_HALF - 0.04), CAB_BACK + 0.02, z1 + 0.1),
                (sx * (CAB_HALF - 0.12), CAB_BACK + 0.02, z1 + 0.12), (sx * (CAB_HALF - 0.2), CAB_BACK + 0.04, z1 + 0.012)],
               0.016, "bronze", sides=6)
    # the floor's beams down to the axle
    for sx in (-1, 1):
        p.box((sx * 0.3, AXLE_Y + 0.12, AXLE_Z + 0.02), (0.07, 0.62, 0.06), "cedar", bevel=0.008)


def _ring(p, cx, r_in, r_out, half_w, mat, seg=28):
    """A tyre: a ring about the x axis through (cx, AXLE_Y, AXLE_Z)."""
    rings = []
    for x, r in ((cx - half_w, r_in), (cx - half_w, r_out), (cx + half_w, r_out), (cx + half_w, r_in)):
        rings.append([p.bm.verts.new((x, AXLE_Y + r * math.cos(2 * math.pi * k / seg),
                                      AXLE_Z + r * math.sin(2 * math.pi * k / seg))) for k in range(seg)])
    faces = []
    for j in range(4):
        r0, r1 = rings[j], rings[(j + 1) % 4]
        for k in range(seg):
            k2 = (k + 1) % seg
            f = p._face([r0[k], r0[k2], r1[k2], r1[k]], mat)
            f.normal_update()
            c = f.calc_center_median()
            # the section's middle: on the circle of radius (r_in + r_out) / 2 in this face's plane of angle
            radial = Vector((0.0, c.y - AXLE_Y, c.z - AXLE_Z)).normalized()
            mid = Vector((cx, AXLE_Y, AXLE_Z)) + radial * (r_in + r_out) * 0.5
            if f.normal.dot(c - mid) < 0:
                f.normal_flip()
            faces.append(f)
    return faces


def wheel(p, sx):
    cx = sx * WHEEL_X
    _ring(p, cx, TYRE_IN, WHEEL_R, TYRE_W * 0.5, "tyre")
    # the felloe inside the tyre (wood) and the studs round the tread
    _ring(p, cx, TYRE_IN - 0.05, TYRE_IN, TYRE_W * 0.4, "cedar", seg=24)
    for k in range(18):
        a = 2 * math.pi * (k + 0.5) / 18
        c = (cx, AXLE_Y + (WHEEL_R + 0.008) * math.cos(a), AXLE_Z + (WHEEL_R + 0.008) * math.sin(a))
        f = p.box(c, (TYRE_W * 0.7, 0.03, 0.03), "stud", bevel=0.006)
        p.move(f, K.T(*c) @ K.R('X', math.degrees(a)) @ K.T(*(-v for v in c)))
    for k in range(SPOKES):
        a = 2 * math.pi * k / SPOKES + math.pi / SPOKES
        tip = (cx, AXLE_Y + (TYRE_IN - 0.04) * math.cos(a), AXLE_Z + (TYRE_IN - 0.04) * math.sin(a))
        root = (cx, AXLE_Y + 0.07 * math.cos(a), AXLE_Z + 0.07 * math.sin(a))
        K.seg(p, root, tip, [(0.026, 0.0), (0.02, 0.6), (0.017, 1.0)], "cedar", segments=6, caps=False)
    # the hub: a long bronze-capped nave, the linchpin through its outer end
    K.seg(p, (cx - sx * 0.13, AXLE_Y, AXLE_Z), (cx + sx * 0.11, AXLE_Y, AXLE_Z),
          [(0.06, 0.0), (0.085, 0.3), (0.085, 0.7), (0.06, 1.0)], "bronze", segments=10)
    p.box((cx + sx * 0.095, AXLE_Y, AXLE_Z + 0.06), (0.02, 0.02, 0.07), "bronze", bevel=0.004)


def chariot():
    p = Part("asy_chariot")
    cab(p)
    for sx in (-1, 1):
        wheel(p, sx)
    K.seg(p, (-0.86, AXLE_Y, AXLE_Z), (0.86, AXLE_Y, AXLE_Z), [(0.04, 0.0), (0.04, 1.0)], "cedar", segments=8)
    # the pole from under the cab, rising forward; a bronze finial
    pole = [(0.0, AXLE_Y + 0.2, AXLE_Z + 0.02), (0.0, -0.1, AXLE_Z + 0.03), (0.0, 0.55, 0.72), (0.0, 1.05, 0.92),
            (0.0, 1.42, 1.1)]
    p.tube(pole, lambda t: 0.05 - 0.012 * t, "cedar", sides=8)
    K.seg(p, (0.0, 1.4, 1.09), (0.0, 1.55, 1.16), [(0.04, 0.0), (0.055, 0.35), (0.03, 0.8), (0.0, 1.0)], "bronze",
          segments=8)
    # the museum's trestle under the pole's end (the yoke is not shown)
    y = 1.22
    z_pole = 1.0
    for sx in (-1, 1):
        p.tube([(sx * 0.2, y, 0.0), (sx * 0.05, y, z_pole - 0.07)], 0.025, "cedar", sides=6)
        p.box((sx * 0.2, y, 0.02), (0.08, 0.16, 0.04), "cedar", bevel=0.006)
    p.box((0.0, y, z_pole - 0.07), (0.16, 0.1, 0.06), "cedar", bevel=0.008)
    p.box((0.0, y, 0.34), (0.32, 0.05, 0.05), "cedar", bevel=0.006)
    # a strap from the cab's front rail down to the pole
    p.tube([(0.0, CAB_ARC_Y + CAB_HALF + 0.02, CAB_TOP - 0.02), (0.0, 0.5, 1.0), (0.0, 0.95, 0.94)], 0.016, "strap",
           sides=5)
    # two quivers crossed on the right side of the cab
    for lean in (-24.0, 28.0):
        a = math.radians(lean)
        c = Vector((CAB_HALF + 0.075, -0.62, 1.05))
        d = Vector((0.0, math.sin(a), math.cos(a)))
        lo, hi = c - d * 0.42, c + d * 0.42
        K.seg(p, tuple(lo), tuple(hi), [(0.05, 0.0), (0.06, 0.15), (0.06, 0.85), (0.068, 0.9), (0.068, 1.0)], "quiver",
              segments=8)
        for k in range(4):
            off = Vector(((k % 2 - 0.5) * 0.04, (k // 2 - 0.5) * 0.04, 0.0))
            K.seg(p, tuple(hi + off), tuple(hi + off + d * 0.13), [(0.012, 0.0), (0.02, 0.4), (0.0, 1.0)], "fletch",
                  segments=4)
    return p


# --------------------------------------------------------------------------
# paint
# --------------------------------------------------------------------------

def _rosettes(s_coord, t, period=0.17, radius=0.055, petals=8):
    """A row of rosettes along s (centres every ``period``), t across the
    band (0 = its middle): masks (petal, eye)."""
    k = np.round(s_coord / period)
    du = s_coord - k * period
    r = np.hypot(du, t)
    a = np.arctan2(t, du)
    petal = (r < radius) & (np.cos(a * petals) > 0.1 - 0.9 * (1.0 - r / radius))
    eye = r < radius * 0.28
    return petal & ~eye, eye


def panel(ctx):
    """The cab's outer face: red paint on cedar, worn to the wood on the
    arrises and low down, a band of white rosettes on lapis under the rail,
    a lapis and yellow chequer at its foot."""
    s = asy.cedar(ctx, 6011, center=4.4)
    z = ctx.p[:, 2]
    u = ctx.uvm[:, 0]
    wear = (ctx.fbm(9.0, 3, 6013) + ctx.edge_soft(3.0) * 0.8 + smoothstep(0.85, 0.66, z) * 0.6) > 0.55
    red = ~wear
    s.use_ramp(P["asy_ochre_red"], mask=red, shade=4.0 + ctx.fbm(6.0, 2, 6015) * 0.8 + _dither(ctx, 0.5, 6017)
               - (1.0 - ctx.ao) * 3.0)
    band_mid = CAB_TOP - 0.11
    band = np.abs(z - band_mid) < 0.075
    s.use_ramp(P["asy_lapis"], mask=band, shade=3.6 + ctx.fbm(10.0, 2, 6019) * 0.7 + _dither(ctx, 0.5, 6021)
               - (1.0 - ctx.ao) * 2.5)
    pet, eye = _rosettes(u, z - band_mid)
    pet &= band
    eye &= band
    s.use_ramp(P["asy_glaze_white"], mask=pet, shade=4.2 + _dither(ctx, 0.6, 6023) + ctx.edge_soft(2.0))
    s.use_ramp(P["asy_glaze_yellow"], mask=eye, shade=np.full(ctx.N, 4.5))
    for edge in (band_mid - 0.085, band_mid + 0.085):
        line = np.abs(z - edge) < 0.008
        s.use_ramp(P["asy_glaze_yellow"], mask=line, shade=np.full(ctx.N, 3.8))
    foot = (z > CAB_FLOOR + 0.02) & (z < CAB_FLOOR + 0.1)
    cell = (np.floor(u / 0.04) + np.floor((z - CAB_FLOOR) / 0.04)) % 2 == 0
    s.use_ramp(P["asy_lapis"], mask=foot & cell, shade=np.full(ctx.N, 4.2) + _dither(ctx, 0.5, 6025))
    s.use_ramp(P["asy_glaze_yellow"], mask=foot & ~cell, shade=np.full(ctx.N, 3.6) + _dither(ctx, 0.5, 6027))
    paint = red | band | foot
    s.rough = np.where(paint, 0.7, s.rough)
    s.height = s.height + np.where(pet | eye, 0.0008, 0.0)
    return s


def quiver(ctx):
    """Leather quivers with bronze bands and a painted lapis panel."""
    s = M.leather(ctx, 6031)
    s.shade += 1.2
    z = ctx.p[:, 2]
    bands = (np.abs(np.mod(z, 0.2) - 0.1) < 0.012)
    b = asy.bronze_aged(ctx.subset(bands), 6033) if bands.any() else None
    if b is not None:
        s.merge(b, bands)
    return s


def fletch(ctx):
    s = M.Surface(ctx.N)
    s.use_ramp(P["asy_ochre_red"], shade=3.0 + ctx.fbm(40.0, 2, 6041) * 1.2 + _dither(ctx, 0.6, 6043))
    s.rough = np.full(ctx.N, 0.85)
    return s


def tyre(ctx):
    s = M.iron(ctx, 6051)
    return s


CHARIOT_FNS = {
    "panel": panel, "cedar": lambda c: asy.cedar(c, 6061, center=4.6),
    "bronze": lambda c: asy.bronze_aged(c, 6063, center=5.6, green=0.7),
    "stud": lambda c: asy.bronze_aged(c, 6065, center=6.4, green=0.4),
    "tyre": tyre, "strap": lambda c: M.leather(c, 6067), "quiver": quiver, "fletch": fletch,
}


# --------------------------------------------------------------------------
# the cage (Blender: front +Y = the gate)
# --------------------------------------------------------------------------

CAGE = 1.72          # outer size
POST = 0.12          # the frame's square posts
BAR_R = 0.032
BAR_STEP = 0.19


def cage():
    p = Part("asy_cage")
    h = CAGE * 0.5
    top = CAGE - 0.3          # the cage's roof (the keeper's hutch above)
    inset = h - POST * 0.5
    # the plank floor and the sill beams
    p.box((0.0, 0.0, 0.05), (CAGE - 0.04, CAGE - 0.04, 0.1), "planks", bevel=0.01)
    # posts at the corners, beams round the top and the foot
    for sx in (-1, 1):
        for sy in (-1, 1):
            p.box((sx * inset, sy * inset, top * 0.5), (POST, POST, top), "frame", bevel=0.012)
    for z in (0.16, top - POST * 0.5):
        for sy in (-1, 1):
            p.box((0.0, sy * inset, z), (CAGE - 0.02, POST, POST * 0.9), "frame", bevel=0.012)
        for sx in (-1, 1):
            p.box((sx * inset, 0.0, z), (POST, CAGE - 0.02, POST * 0.9), "frame", bevel=0.012)
    # the roof of planks, a hair over the beams
    p.box((0.0, 0.0, top + 0.03), (CAGE - 0.02, CAGE - 0.02, 0.06), "planks", bevel=0.01)
    # iron straps round the frame's corners
    for sx in (-1, 1):
        for sy in (-1, 1):
            for z in (0.16, top - 0.06):
                p.box((sx * inset, sy * inset, z), (POST + 0.016, POST + 0.016, 0.05), "iron", bevel=0.005)
    # round wooden bars on the sides and the back (the gate's side has its own)
    span = CAGE - 2 * POST
    n = max(2, int(round(span / BAR_STEP)))
    for k in range(1, n):
        t = -span * 0.5 + span * k / n
        for sx in (-1, 1):
            K.seg(p, (sx * inset, t, 0.2), (sx * inset, t, top - POST), [(BAR_R, 0.0), (BAR_R, 1.0)], "bars",
                  segments=6, caps=False)
        K.seg(p, (t, -inset, 0.2), (t, -inset, top - POST), [(BAR_R, 0.0), (BAR_R, 1.0)], "bars", segments=6,
              caps=False)
    # the sliding gate on the front: a grid of bars in a frame, raised a hand
    lift = 0.12
    gy = inset + 0.05
    for sx in (-1, 1):
        p.box((sx * (h - 0.04), gy + 0.01, top * 0.5 + 0.05), (0.06, 0.05, top + 0.1), "frame", bevel=0.008)  # grooves
    p.box((0.0, gy, 0.22 + lift), (span + 0.08, 0.07, 0.08), "frame", bevel=0.008)
    p.box((0.0, gy, top - 0.08 + lift * 0.5), (span + 0.08, 0.07, 0.08), "frame", bevel=0.008)
    p.box((0.0, gy, (0.22 + top) * 0.5 + lift * 0.6), (span + 0.08, 0.06, 0.06), "iron", bevel=0.006)
    for k in range(1, n):
        t = -span * 0.5 + span * k / n
        K.seg(p, (t, gy, 0.22 + lift), (t, gy, top - 0.08 + lift * 0.5), [(BAR_R * 0.9, 0.0), (BAR_R * 0.9, 1.0)], "bars",
              segments=6, caps=False)
    # the ring the keeper pulls the gate up by
    ring = p.lathe([(0.05, -0.01), (0.062, 0.0), (0.05, 0.01)], "iron", segments=10, cap_bottom=False, cap_top=False)
    p.move(ring, K.T(0.0, gy + 0.05, top - 0.02) @ K.R('X', 90))
    # the keeper's hutch on the roof: a small cage of bars at the back corner
    kx, ky, ks = -h + 0.36, -h + 0.36, 0.56
    for sx in (-1, 1):
        for sy in (-1, 1):
            p.box((kx + sx * ks * 0.5, ky + sy * ks * 0.5, top + 0.06 + 0.11), (0.06, 0.06, 0.22), "frame", bevel=0.008)
    p.box((kx, ky, top + 0.06 + 0.23), (ks + 0.08, ks + 0.08, 0.04), "planks", bevel=0.006)
    for k in range(1, 4):
        t = -ks * 0.5 + ks * k / 4
        for sy in (-1, 1):
            K.seg(p, (kx + t, ky + sy * ks * 0.5, top + 0.06), (kx + t, ky + sy * ks * 0.5, top + 0.27),
                  [(0.016, 0.0), (0.016, 1.0)], "bars", segments=5, caps=False)
            K.seg(p, (kx + sy * ks * 0.5, ky + t, top + 0.06), (kx + sy * ks * 0.5, ky + t, top + 0.27),
                  [(0.016, 0.0), (0.016, 1.0)], "bars", segments=5, caps=False)
    return p


def frame(ctx):
    s = asy.cedar(ctx, 6111, center=3.8)
    s.shade -= 0.4
    return s


def bars(ctx):
    """Round bars, rubbed pale in the middle where the lions gnawed and
    paws gripped, dark at the ends."""
    s = asy.cedar(ctx, 6121, center=4.2)
    z = ctx.p[:, 2]
    s.shade += smoothstep(0.4, 0.9, z) * smoothstep(1.4, 0.9, z) * 0.9
    claw = (ctx.fbm(np.array([2.0, 2.0, 30.0]), 2, 6123) > 0.45) & (z > 0.4) & (z < 1.2)
    s.shade[claw] += 1.4
    s.height = s.height - claw * 0.0008
    return s


CAGE_FNS = {
    "planks": lambda c: asy.cedar(c, 6131, center=3.6), "frame": frame, "bars": bars,
    "iron": lambda c: M.iron(c, 6133),
}


def build():
    return [
        kit("asy_chariot", [chariot()], CHARIOT_FNS, ppm=256, built_final=True, ground=0.0, ao_dist=0.25,
            ao_rays=10, ao_stride=2, preview_yaws=(-40.0, 40.0, 140.0, 220.0), preview_elevation=12.0),
        kit("asy_cage", [cage()], CAGE_FNS, ppm=128, built_final=True, ground=0.0, ao_dist=0.25, ao_rays=10,
            ao_stride=2, preview_yaws=(-30.0, 30.0, 150.0, 210.0), preview_elevation=14.0),
    ]
