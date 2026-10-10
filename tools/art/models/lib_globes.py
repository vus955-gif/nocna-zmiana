"""Enlightenment wing: the two great library globes (a pair, as in every
gentleman's library).

  lib_globe_terrestrial  0.84 m globe on a mahogany tripod stand, 1.45 m:
                         an old map in watercolour washes on varnished
                         paper (continents traced from a real outline,
                         artlib/enl_geo.py), inked coasts with wave
                         hatching, graticule, a cartouche and a compass rose;
                         brass meridian ring, a paper horizon ring with the
                         zodiac and the calendar, a compass in the stretcher.
  lib_globe_celestial    the same stand ebonised with gilt rims, the globe
                         deep blue with gilt stars and real constellations
                         (Orion, the Plough, Cassiopeia, Cygnus, Scorpius,
                         Leo, the Southern Cross), the ecliptic and the
                         equator.

Origin = centre of the base on the floor (round: no front). Parts: the
stand (root, named after the model) and "globe" (child), its pivot at the
globe's centre (0, 1.0, 0). The globe's axis is tilted 23.4 degrees in the
meridian ring: spin it with globe.rotate(AXIS, angle), AXIS = Godot
(0.397, 0.918, 0.0) (it turns about its own axis, not the vertical).
"""
import math
import os

import numpy as np
from mathutils import Matrix, Vector

from artlib import enl_geo as G
from artlib import enl_materials as E
from artlib import kit as K
from artlib import noise
from artlib.archkit import kit
from artlib.enl_materials import P
from artlib.geo import Part, box_project
from artlib.materials import _dither
from artlib.painter import Surface

R = 0.42
CZ = 1.0
TILT = math.radians(23.4)
TILT_M = Matrix.Translation((0, 0, CZ)) @ Matrix.Rotation(TILT, 4, 'Y') @ Matrix.Translation((0, 0, -CZ))


def ring_pieces(p, r0, r1, z, mat, segments=48, pieces=6, thick=0.0):
    """A flat annulus (top face, optional rim faces) in arcs with unrolled
    metre UVs: compact atlas islands."""
    per = segments // pieces
    for q in range(pieces):
        outer = []
        inner = []
        for i in range(per + 1):
            a = math.tau * (q * per + i) / segments
            outer.append(p.bm.verts.new((r1 * math.cos(a), r1 * math.sin(a), z)))
            inner.append(p.bm.verts.new((r0 * math.cos(a), r0 * math.sin(a), z)))
        rm = (r0 + r1) / 2
        for i in range(per):
            u0, u1 = math.tau * rm * i / segments, math.tau * rm * (i + 1) / segments
            quad = [(inner[i], (u0, 0.0)), (inner[i + 1], (u1, 0.0)), (outer[i + 1], (u1, r1 - r0)),
                    (outer[i], (u0, r1 - r0))]
            f = p._face([v for v, _ in quad], mat)
            for loop, (_, uv) in zip(f.loops, quad):
                loop[p.uv].uv = uv
            f[p.lock] = 1
            f.normal_update()
            if f.normal.z < 0:
                f.normal_flip()
    if thick > 0:
        p.lathe([(r1, z - thick), (r1, z)], mat, segments=segments, cap_bottom=False, cap_top=False, smooth=True)
        p.lathe([(r0, z), (r0, z - thick)], mat, segments=segments, cap_bottom=False, cap_top=False, smooth=True)


def stand(name, wood="mahogany", trim="brass"):
    p = Part(name)
    for k in range(3):
        a = math.tau * k / 3 + math.pi / 6
        ca, sa = math.cos(a), math.sin(a)
        pts = [(0.42 * ca, 0.42 * sa, 0.05), (0.46 * ca, 0.46 * sa, 0.35), (0.5 * ca, 0.5 * sa, 0.7),
               (0.52 * ca, 0.52 * sa, CZ - 0.02)]
        p.tube(pts, lambda t: 0.035 - 0.012 * math.sin(t * math.pi), wood, sides=8)
        K.sphere(p, (0.42 * ca, 0.42 * sa, 0.035), 0.035, trim, segments=8, rings=5)
        K.seg(p, (0.43 * ca, 0.43 * sa, 0.25), (0.05 * ca, 0.05 * sa, 0.25), [(0.018, 0.0), (0.018, 1.0)], wood,
              segments=6)
    # the stretcher hub with a compass, a column up to the meridian cradle
    p.lathe([(0.0, 0.2), (0.09, 0.2), (0.09, 0.29), (0.0, 0.29)], wood, segments=12)
    disc = p.poly([(0.07 * math.cos(math.tau * i / 16), 0.07 * math.sin(math.tau * i / 16), 0.292) for i in range(16)],
                  "compass")[0]
    disc.normal_update()
    if disc.normal.z < 0:
        disc.normal_flip()
    p.lathe([(0.04, 0.29), (0.035, 0.4), (0.03, CZ - R - 0.06), (0.05, CZ - R - 0.04)], wood, segments=10,
            cap_bottom=False)
    # horizon ring: paper top in a moulded frame
    ring_pieces(p, R + 0.035, R + 0.15, CZ + 0.005, "horizon", thick=0.03)
    ring_pieces(p, R + 0.15, R + 0.17, CZ + 0.008, trim, segments=48, pieces=6, thick=0.04)
    # brass meridian ring in the x-z plane round the tilted globe, an hour circle at the pole
    pts = []
    for i in range(0, 41):
        a = math.tau * i / 40
        pts.append((math.sin(a) * (R + 0.018), 0.0, CZ + math.cos(a) * (R + 0.018)))
    for k in range(0, 40, 8):
        seg = [Vector(c) for c in pts[k:k + 9]]
        p.tube([tuple(TILT_M @ v) for v in seg], 0.012, "meridian", sides=4, caps=False)
    pole = TILT_M @ Vector((0.0, 0.0, CZ + R + 0.035))
    hc = p.lathe([(0.0, -0.004), (0.06, -0.004), (0.06, 0.004), (0.0, 0.004)], "meridian", segments=12)
    p.move(hc, Matrix.Translation(pole) @ Matrix.Rotation(TILT, 4, 'Y'))
    return p


def globe(parent):
    g = Part("globe", origin=(0.0, 0.0, CZ), parent=parent)
    f = K.sphere(g, (0.0, 0.0, CZ), R, "map", segments=32, rings=18)
    for z in (-1, 1):
        cap = g.lathe([(0.0, 0.0), (0.02, 0.0), (0.012, 0.015), (0.0, 0.02)], "pin", segments=8)
        g.move(cap, Matrix.Translation((0, 0, CZ + z * R)) @ Matrix.Rotation(0.0 if z > 0 else math.pi, 4, 'X'))
        f += cap
    g.move(f, TILT_M)
    return g


# --- painters ------------------------------------------------------------------------------

def _latlon(ctx):
    d = ctx.p - np.array([0.0, 0.0, CZ])
    # undo the tilt (rotation by TILT about Y)
    c, s = math.cos(-TILT), math.sin(-TILT)
    x = c * d[:, 0] + s * d[:, 2]
    z = -s * d[:, 0] + c * d[:, 2]
    y = d[:, 1]
    r = np.maximum(np.sqrt(x * x + y * y + z * z), 1e-6)
    lat = np.degrees(np.arcsin(np.clip(z / r, -1, 1)))
    lon = np.degrees(np.arctan2(y, x))
    return lon, lat, np.stack([x, y, z], axis=1) / r[:, None]


def earth_map(ctx):
    s = Surface(ctx.N)
    lon, lat, _ = _latlon(ctx)
    deg = np.degrees(ctx.texel / R)                      # degrees per texel at the equator
    j = ctx.fbm(9.0, 2, 951) * 0.9
    lon2, lat2 = lon + j, lat + ctx.fbm(9.0, 2, 952) * 0.9
    land = G.land_index(lon2, lat2)
    step = deg * 1.2 / np.maximum(np.cos(np.radians(lat)), 0.2)
    coast = (land != G.land_index(lon2 + step, lat2)) | (land != G.land_index(lon2, lat2 + deg * 1.2))
    near1 = (land < 0) & ((G.land_index(lon2 + 1.6, lat2) >= 0) | (G.land_index(lon2 - 1.6, lat2) >= 0) |
                          (G.land_index(lon2, lat2 + 1.6) >= 0) | (G.land_index(lon2, lat2 - 1.6) >= 0))
    near2 = (land < 0) & ~near1 & ((G.land_index(lon2 + 3.2, lat2) >= 0) | (G.land_index(lon2 - 3.2, lat2) >= 0) |
                                   (G.land_index(lon2, lat2 + 3.2) >= 0) | (G.land_index(lon2, lat2 - 3.2) >= 0))
    varnish = ctx.fbm(2.0, 3, 953) * 0.8 - np.clip(np.abs(lat) - 60, 0, 30) / 30.0 * 0.8
    sea = land < 0
    sea_sh = 5.4 + varnish + _dither(ctx, 0.6, 954)
    s.use_ramp(P["enl_parchment"], shade=sea_sh - (1.0 - ctx.ao) * 2.0)
    wave = (near1 & (np.mod(np.floor((lon2 + lat2) / deg), 3) == 0)) | (near2 & (np.mod(np.floor(lon2 / deg), 5) == 0))
    s.shade[wave] -= 1.4
    for cls, ramp in ((0, "enl_wash_pink"), (1, "enl_wash_green"), (2, "enl_wash_ochre"), (3, "enl_parchment")):
        m = land == cls
        if m.any():
            base = (3.6 if cls < 3 else 7.0) + varnish + _dither(ctx, 0.6, 955 + cls)
            s.use_ramp(P[ramp], mask=m, shade=base)
    # graticule every 30 degrees, the equator and tropics dashed, the ecliptic
    g_lon = np.abs(np.mod(lon + 15.0, 30.0) - 15.0) < deg * 0.6 / np.maximum(np.cos(np.radians(lat)), 0.05)
    g_lat = np.abs(np.mod(lat + 15.0, 30.0) - 15.0) < deg * 0.6
    eq = (np.abs(lat) < deg * 1.1) | ((np.abs(np.abs(lat) - 23.4) < deg * 0.6) & (np.mod(np.floor(lon / 3.0), 2) == 0))
    ecl = np.abs(lat - 23.4 * np.sin(np.radians(lon))) < deg * 0.6
    ink = coast | ((g_lon | g_lat) & sea) | eq
    s.use_ramp(P["enl_ink"], mask=ink, shade=np.full(ctx.N, 2.2))
    s.use_ramp(P["enl_morocco_red"], mask=ecl & ~coast, shade=np.full(ctx.N, 5.5))
    # a cartouche in the Pacific and a compass rose in the Atlantic
    cu, cv = (lon + 150.0) / 16.0, (lat + 18.0) / 9.0
    cart = (np.abs(cu) < 1) & (np.abs(cv) < 1)
    frame = cart & ((np.abs(np.abs(cu) - 0.95) < 0.05) | (np.abs(np.abs(cv) - 0.92) < 0.08))
    lines = cart & ~frame & (np.abs(cu) < 0.8) & (np.mod(np.floor(lat / deg), 3) == 0) & (np.abs(cv) < 0.7) & \
        (noise.hash_float(np.floor(lon / deg).astype(np.int64), np.floor(lat / deg).astype(np.int64),
                          np.zeros(ctx.N, dtype=np.int64), 956) > 0.3)
    s.use_ramp(P["enl_parchment"], mask=cart & ~frame & ~lines, shade=np.full(ctx.N, 7.5))
    s.use_ramp(P["enl_ink"], mask=frame | lines, shade=np.full(ctx.N, 1.8))
    du, dv = lon + 38.0, lat - 28.0
    rr = np.hypot(du, dv)
    ang = np.arctan2(dv, du)
    star = rr < 6.0 * (0.25 + 0.75 * np.abs(np.cos(ang * 4.0)) ** 6)
    s.use_ramp(P["enl_morocco_red"], mask=star & (np.cos(ang * 8.0) > 0), shade=np.full(ctx.N, 5.0))
    s.use_ramp(P["enl_ink"], mask=star & (np.cos(ang * 8.0) <= 0), shade=np.full(ctx.N, 2.0))
    s.rough = np.full(ctx.N, 0.3)
    s.height = coast * -0.0003
    return s


def sky_map(ctx):
    s = Surface(ctx.N)
    lon, lat, d = _latlon(ctx)
    deg = np.degrees(ctx.texel / R)
    s.use_ramp(P["enl_enamel_blue"], shade=3.6 + ctx.fbm(2.5, 3, 961) * 0.7 + _dither(ctx, 0.5, 962)
               - (1.0 - ctx.ao) * 2.0)
    # faint stars: one per random cell
    cell = np.floor(np.stack([lon / 3.0, lat / 3.0], axis=1)).astype(np.int64)
    h = noise.hash_float(cell[:, 0], cell[:, 1], np.zeros(ctx.N, dtype=np.int64), 963)
    hx = noise.hash_float(cell[:, 0], cell[:, 1], np.ones(ctx.N, dtype=np.int64), 964)
    hy = noise.hash_float(cell[:, 0], cell[:, 1], np.full(ctx.N, 2, dtype=np.int64), 965)
    sx = (cell[:, 0] + hx) * 3.0
    sy = (cell[:, 1] + hy) * 3.0
    faint = (h < 0.55) & (np.abs(lon - sx) * np.cos(np.radians(lat)) < deg * 0.6) & (np.abs(lat - sy) < deg * 0.6)
    gold = faint.copy()
    # constellation lines and the bright stars
    vec = []
    for ra, dec, _ in G.STARS:
        a, b = math.radians(ra), math.radians(dec)
        vec.append(np.array([math.cos(b) * math.cos(a), math.cos(b) * math.sin(a), math.sin(b)]))
    w = ctx.texel / R * 0.7
    lines = np.zeros(ctx.N, dtype=bool)
    for i, j in G.LINES:
        a, b = vec[i], vec[j]
        n = np.cross(a, b)
        n /= np.linalg.norm(n)
        off = np.abs(d @ n)
        within = (np.cross(a, d) @ n >= 0) & (np.cross(d, b) @ n >= 0)
        lines |= (off < w) & within
    big = np.zeros(ctx.N, dtype=bool)
    for (ra, dec, cls), v in zip(G.STARS, vec):
        ang = np.arccos(np.clip(d @ v, -1, 1))
        big |= ang < ctx.texel / R * (2.6 if cls == 1 else (1.8 if cls == 2 else 1.2))
    ecl = np.abs(lat - 23.4 * np.sin(np.radians(lon))) < deg * 0.7
    eq = np.abs(lat) < deg * 0.6
    grat = (np.abs(np.mod(lon + 15.0, 30.0) - 15.0) < deg * 0.5 / np.maximum(np.cos(np.radians(lat)), 0.05)) & \
        (np.mod(np.floor(lat / deg), 2) == 0)
    s.use_ramp(P["enl_morocco_blue"], mask=grat & ~big, shade=np.full(ctx.N, 6.0))
    gold |= lines | big | ecl | eq
    s.use_ramp(P["gold"], mask=gold, shade=np.full(ctx.N, 6.6) + big * 1.5 - lines * 0.8 + _dither(ctx, 0.8, 966))
    s.metal = np.where(gold, 0.85, 0.0)
    s.rough = np.where(gold, 0.3, 0.14)
    emit = np.zeros((ctx.N, 3))
    emit[big] = s.colors()[big] * 0.5
    s.emit = emit
    return s


def horizon(ctx):
    """The paper horizon ring: zodiac and calendar scales in ink, red rules."""
    s = E.paper(ctx, seed=971, center=6.8)
    a = np.degrees(np.arctan2(ctx.p[:, 1], ctx.p[:, 0]))
    r = np.hypot(ctx.p[:, 0], ctx.p[:, 1])
    deg = np.degrees(ctx.texel / r)
    rules = np.zeros(ctx.N, dtype=bool)
    for rr in (R + 0.045, R + 0.08, R + 0.11, R + 0.14):
        rules |= np.abs(r - rr) < ctx.texel * 0.6
    ticks = (r > R + 0.045) & (r < R + 0.08) & (np.abs(np.mod(a, 5.0) - 2.5) > 2.5 - deg * 0.6)
    signs = (r > R + 0.08) & (r < R + 0.11) & (np.abs(np.mod(a, 30.0) - 15.0) > 15.0 - deg * 0.6)
    glyph = (r > R + 0.085) & (r < R + 0.105) & (np.abs(np.mod(a, 30.0) - 15.0) < 4.0) & (ctx.rand(972) > 0.55)
    month = (r > R + 0.11) & (r < R + 0.14) & (np.abs(np.mod(a + 7.0, 30.4) - 15.2) < 6.0) & \
        (np.mod(np.floor(r / ctx.texel), 2) == 0) & (ctx.rand(973) > 0.4)
    s.use_ramp(P["enl_ink"], mask=ticks | signs | glyph | month, shade=np.full(ctx.N, 1.8))
    s.use_ramp(P["enl_morocco_red"], mask=rules, shade=np.full(ctx.N, 5.0))
    return s


def compass(ctx):
    s = E.paper(ctx, seed=974, center=6.6)
    a = np.arctan2(ctx.p[:, 1], ctx.p[:, 0])
    r = np.hypot(ctx.p[:, 0], ctx.p[:, 1])
    star = r < 0.06 * (0.2 + 0.8 * np.abs(np.cos(a * 2.0)) ** 8)
    needle = (np.abs(ctx.p[:, 0]) < 0.004) & (r < 0.058)
    s.use_ramp(P["enl_ink"], mask=star, shade=np.full(ctx.N, 2.0))
    s.use_ramp(P["enl_steel_dark"], mask=needle, shade=np.full(ctx.N, 3.0))
    s.use_ramp(P["enl_morocco_red"], mask=needle & (ctx.p[:, 1] > 0), shade=np.full(ctx.N, 5.0))
    return s


def build():
    only = os.environ.get("ENL_ONLY", "").split(",")

    def want(n):
        return only == [""] or n in only

    out = []
    for name, mapfn, wood, trim in (("lib_globe_terrestrial", earth_map, "mahogany", "brass"),
                                    ("lib_globe_celestial", sky_map, "ebony", "gilt")):
        if not want(name):
            continue
        st = stand(name, wood, trim)
        gl = globe(name)
        fns = {"mahogany": E.mahogany, "ebony": lambda c: E.mahogany(c, seed=981, center=1.6), "brass": E.worn_brass,
               "gilt": E.gilt, "meridian": E.worn_brass, "horizon": horizon, "compass": compass, "map": mapfn,
               "pin": E.worn_brass}
        out.append(kit(name, [st, gl], fns, ppm=192, ground=0.0, ao_dist=0.2, built_final=True,
                       preview_yaws=(-30.0, 30.0, 120.0, 210.0), preview_elevation=12.0,
                       preview_extra=[("globe", (0.0, 0.0, CZ), 0.5, -20.0, 10.0)]))
    return out
