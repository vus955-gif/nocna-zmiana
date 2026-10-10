"""The Great Orrery ("Wielkie Planetarium"), guardian of the Enlightenment
wing (spec 7.4): a brass and blue-enamel orrery 10 m across that fills the
rotunda. It does not walk: its arms sweep the arena at three heights, its
six planets come off and roll or orbit as projectiles, and when all six are
gone the sun opens and shows its glowing core.

Origin on the floor on the central axis; Blender +Y = Godot -Z (the rig is
radially symmetric, "front" only matters for the planets' order below).
Parts (Godot node names) and pivots in Godot axes (x, y, z):

  planetarium   (0, 0, 0)       root: stepped enamel platform r 2.1 m with
                                a gilt zodiac, the gear train, the column
                                and the cradle under the sun. Static.
  tier_low      (0, 0.45, 0)    hub + two arms to r 5.0 m, beam 0.30-0.55 m
                                above the floor: JUMP over it (the guard's
                                jump apex is 0.83 m). Rods carry planet_1
                                (Mercury, r 2.2 on -X) and planet_2 (Venus,
                                r 4.7 on +X) at ~1.2 m.
  tier_mid      (0, 1.6, 0)     hub + two SHORT arms to r 3.6 m, beam
                                1.45-1.75 m: cannot be jumped or ducked -
                                keep out of r < 3.7 when it comes round.
                                planet_3 (Earth with its Moon, r 3.3 on +X)
                                and planet_4 (Mars, r 3.0 on -X) at ~2.3 m.
  tier_high     (0, 2.8, 0)     hub + two arms to r 5.0 m, beam 2.65-2.95 m
                                (1.8 m guard passes under it) with moons
                                hanging on rods down to ~1.0 m at r 1.0-3.5
                                and r 5.0: the GAP between r 3.8 and 4.7 is
                                the place to stand while it passes over.
                                planet_5 (Jupiter, r 4.6 on +X) and planet_6
                                (Saturn with rings, r 4.6 on -X) ride above
                                the arm at ~3.5 m.
  planet_1..6   planet centres  each a child of its tier: hide / detach and
                                throw it (the moon of Earth and the rings of
                                Saturn come with their planet). Markers
                                socket_1..6 (children of the tiers) keep the
                                place on the arm.
  sun_shell_1..6                the six petals of the sun's upper shell
                                (sun centre 4.6 m, r 0.85), children of the
                                root, pivots on their hinges at the shell's
                                lower rim (r 0.74, y 4.175). Opening: rotate
                                petal k by +1.6 rad about its hinge axis
                                (-sin a_k, 0, -cos a_k), a_k = 30 + 60 k
                                degrees (k = 0..5 for sun_shell_1..6).
  sun_glow      (0, 4.6, 0)     the glowing core (emission map): the weak
                                point once the petals are open. Marker
                                sun_core at its centre.

Spin: tier_*.rotation.y (Godot), in either direction; the planets turn with
their tier. 96 px/m (the sun's core and the petals' insides at half
that: seen only when it opens); emission map on the core.
"""
import math
import os
import random

import numpy as np
from mathutils import Matrix, Vector

from artlib import enl_materials as E
from artlib import kit as K
from artlib import materials as M
from artlib.enl_materials import P
from artlib.geo import Part
from artlib.materials import _dither, hexramp
from artlib.model import Model
from artlib.painter import Surface

P.update({
    "enl_mercury": hexramp("#1d1b1a", "#2f2c29", "#45403b", "#5c5650", "#756e66", "#8f877d", "#aaa196"),
    "enl_venus": hexramp("#4a3a1c", "#6a5428", "#8c7036", "#ad8d48", "#c9a95e", "#dfc47c", "#efdc9f"),
    "enl_ocean": hexramp("#04102a", "#08193d", "#0d2452", "#143268", "#1d427f", "#2a5596", "#3a6aac"),
    "enl_land": hexramp("#1c2410", "#2b3618", "#3c4a21", "#4f5f2c", "#647638", "#7b8c45"),
    "enl_mars": hexramp("#2a0c06", "#45150a", "#62200f", "#802d15", "#9c3c1d", "#b65029", "#cc6a3b"),
    "enl_jupiter": hexramp("#3a2414", "#58371f", "#77502e", "#946b43", "#ae875c", "#c6a37b", "#dbbf9c",
                           "#ead6ba"),
    "enl_saturn": hexramp("#4a3c22", "#66542f", "#837040", "#a08c54", "#baa76b", "#d1c085", "#e3d6a2"),
    "enl_sun": hexramp("#3a0a02", "#6e1a03", "#a33305", "#d0560a", "#ef8114", "#fbad2d", "#ffd668", "#fff0b0"),
})

SUN_Z, SUN_R = 5.0, 1.1
RIM_LAT = math.radians(-30.0)
HUB = 0.45
COL_R = 0.28
# rest pose: the tiers' arms are staggered (the game spins them freely)
TIER_ANGLE = {"tier_low": 0.0, "tier_mid": math.radians(60.0), "tier_high": math.radians(120.0)}


def gear(p, c, r, z0, h, teeth, mat="brass"):
    seg = teeth * 2
    f = p.lathe([(r, 0.0), (r, h)], mat, segments=seg, center=(c[0], c[1], z0),
                ring_scale=lambda i, j: 1.0 if i % 2 else 0.9, smooth=False)
    p.lathe([(r * 0.35, h), (r * 0.35, h + 0.02), (0.0, h + 0.02)], mat, segments=10, center=(c[0], c[1], z0),
            cap_bottom=False)
    return f


def girder(p, r0, r1, z0, z1, angle, mat="brass"):
    """A heavy arm along ``angle`` from radius r0 to r1 between heights z0
    and z1: a blue enamel web with gilt stars, brass flanges top and bottom,
    brass straps every 0.6 m and a bearing block at the tip."""
    rot = Matrix.Rotation(angle, 4, 'Z')
    faces = []
    L = r1 - r0
    h = z1 - z0
    web = p.box((r0 + L / 2, 0.0, z0 + h / 2), (L, 0.12, h - 0.1), "arm_enamel")
    # its top and bottom lie under the flanges: drop them (atlas space)
    hidden = [f for f in web if abs(f.normal.z) > 0.9]
    import bmesh
    bmesh.ops.delete(p.bm, geom=hidden, context='FACES')
    faces += [f for f in web if f.is_valid]
    for z in (z0 + 0.04, z1 - 0.04):
        faces += p.box((r0 + L / 2, 0.0, z), (L, 0.2, 0.08), mat, bevel=0.02)
    n = max(2, int(L / 0.6))
    for k in range(1, n):
        x = r0 + L * k / n
        faces += p.box((x, 0.0, z0 + h / 2), (0.05, 0.16, h - 0.12), "dark_brass")
    faces += p.box((r1, 0.0, z0 + h / 2), (0.2, 0.26, h + 0.08), mat, bevel=0.03)
    # metre UVs fixed before the turn: projected after it, a girder at 60
    # degrees would be a diagonal island with a huge bounding box
    from artlib.geo import box_project
    for f in faces:
        f.normal_update()
        if not f[p.lock]:
            box_project(f, p.uv)
            f[p.lock] = 1
    p.move(faces, rot)
    return faces


def hub(p, z0, z1, r=HUB):
    """The tier's sleeve on the column: a brass drum with a toothed crown
    (it meshes with the gear train)."""
    p.lathe([(COL_R + 0.02, z0), (r, z0), (r + 0.06, z0 + 0.04), (r + 0.06, z1 - 0.04), (r, z1), (COL_R + 0.02, z1)],
            "brass", segments=20, cap_bottom=False, cap_top=False)
    gear(p, (0.0, 0.0), r + 0.2, z1 - 0.07, 0.06, 26, "dark_brass")


def rod(p, x, y, z0, z1, radius=0.035):
    f = K.seg(p, (x, y, z0), (x, y, z1), [(radius, 0.0), (radius, 1.0)], "brass", segments=8)
    p.lathe([(0.0, -0.03), (radius * 2.6, 0.0), (radius * 2.6, 0.04), (radius * 1.2, 0.07)], "dark_brass",
            segments=8, center=(x, y, z1))
    return f


def band(p, profile, mat, segments=48, pieces=4):
    """A lathe ring split into ``pieces`` arcs: each arc is its own atlas
    island (u = arc length at the mean radius, v = along the profile), so a
    17 m skirt does not become one 17 m strip in the atlas."""
    faces = []
    acc = [0.0]
    for i in range(1, len(profile)):
        acc.append(acc[-1] + math.hypot(profile[i][0] - profile[i - 1][0], profile[i][1] - profile[i - 1][1]))
    per = segments // pieces
    for q in range(pieces):
        rings = []
        for j, (r, z) in enumerate(profile):
            rings.append([p.bm.verts.new((r * math.cos(math.tau * (q * per + i) / segments),
                                          r * math.sin(math.tau * (q * per + i) / segments), z))
                          for i in range(per + 1)])
        for j in range(len(profile) - 1):
            rm = (profile[j][0] + profile[j + 1][0]) * 0.5
            for i in range(per):
                u0, u1 = math.tau * rm * i / segments, math.tau * rm * (i + 1) / segments
                quad = [(rings[j][i], (u0, acc[j])), (rings[j][i + 1], (u1, acc[j])),
                        (rings[j + 1][i + 1], (u1, acc[j + 1])), (rings[j + 1][i], (u0, acc[j + 1]))]
                f = p._face([v for v, _ in quad], mat)
                for loop, (_, uv) in zip(f.loops, quad):
                    loop[p.uv].uv = uv
                f[p.lock] = 1
                f.normal_update()
                c = f.calc_center_median()
                want = Vector((c.x, c.y, 0.0)).normalized() if abs(f.normal.z) < 0.7 else Vector((0, 0, 1))
                if f.normal.dot(want) < 0:
                    f.normal_flip()
                faces.append(f)
    return faces


def disc(p, r, z, mat, segments=32):
    """A flat round top (box-projected: one compact square island)."""
    f = p.poly([(r * math.cos(math.tau * i / segments), r * math.sin(math.tau * i / segments), z)
                for i in range(segments)], mat)[0]
    f.normal_update()
    if f.normal.z < 0:
        f.normal_flip()
    return [f]


def platform(p):
    # a stepped drum: brass skirt, gilt zodiac ring on blue enamel, an enamel dais
    band(p, [(2.7, 0.0), (2.7, 0.06), (2.64, 0.1), (2.2, 0.1)], "brass", segments=48, pieces=6)
    band(p, [(2.2, 0.1), (2.2, 0.18), (1.45, 0.18)], "zodiac", segments=48, pieces=6)
    band(p, [(1.45, 0.18), (1.45, 0.22), (1.4, 0.24)], "enamel", segments=36, pieces=3)
    disc(p, 1.4, 0.24, "enamel", segments=36)
    for k in range(12):
        a = math.tau * k / 12
        p.box((2.45 * math.cos(a), 2.45 * math.sin(a), 0.13), (0.1, 0.1, 0.06), "dark_brass", bevel=0.02)
    # the gear train round the column (kept under the low arm's beam at 0.3 m)
    rng = random.Random(7)
    for k in range(8):
        a = math.tau * k / 8 + 0.2
        rr = rng.uniform(0.75, 1.15)
        gr = rng.uniform(0.18, 0.3)
        gear(p, (rr * math.cos(a), rr * math.sin(a)), gr, 0.24, 0.04, int(gr * 70),
             "brass" if k % 2 else "dark_brass")
    gear(p, (0.0, 0.0), 0.62, 0.24, 0.05, 44, "dark_brass")
    # the column with collars, the cradle cup under the sun
    p.lathe([(COL_R, 0.24), (COL_R, SUN_Z - SUN_R * 0.8)], "brass", segments=14, cap_bottom=False, cap_top=False)
    for z in (1.05, 2.25, 3.45, 4.1):
        p.lathe([(COL_R, z), (COL_R + 0.06, z + 0.03), (COL_R + 0.06, z + 0.08), (COL_R, z + 0.11)], "dark_brass",
                segments=14, cap_bottom=False, cap_top=False)
    cup = []
    for k in range(7):
        lat = math.radians(-90 + 60 * k / 6)
        cup.append((max(COL_R, SUN_R * 1.02 * math.cos(lat)), SUN_Z + SUN_R * 1.02 * math.sin(lat)))
    p.lathe([(COL_R, SUN_Z - SUN_R * 1.2)] + cup, "brass", segments=24, cap_bottom=False, cap_top=False)
    # a gilt meridian ring round the sun on two posts, and the tilted ecliptic band
    R = SUN_R + 0.65
    ring = [(R * math.cos(a), 0.0, SUN_Z + R * math.sin(a)) for a in np.linspace(-0.55, math.pi + 0.55, 19)]
    for k in range(0, len(ring) - 1, 6):
        p.tube(ring[k:k + 7], 0.04, "gilt", sides=6, caps=k == 0 or k + 7 >= len(ring))
    for sx in (-1, 1):
        p.tube([(sx * R * math.cos(-0.55), 0.0, SUN_Z + R * math.sin(-0.55)), (sx * 0.5, 0.0, SUN_Z - SUN_R - 0.3)],
               0.035, "dark_brass", sides=6)
    ecl = [(R * 0.92 * math.cos(a), R * 0.92 * math.sin(a), 0.0) for a in np.linspace(0.0, math.tau, 33)]
    eb = []
    for k in range(0, len(ecl) - 1, 8):
        eb += p.tube(ecl[k:k + 9], 0.05, "zodiac_band", sides=4, caps=False)
    p.move(eb, Matrix.Translation((0.0, 0.0, SUN_Z)) @ Matrix.Rotation(math.radians(23.4), 4, 'X'))


def sun_petals():
    parts = []
    lat0 = RIM_LAT
    for k in range(6):
        az = math.radians(30 + 60 * k)
        hinge = (SUN_R * math.cos(lat0) * math.cos(az), SUN_R * math.cos(lat0) * math.sin(az),
                 SUN_Z + SUN_R * math.sin(lat0))
        p = Part(f"sun_shell_{k + 1}", origin=hinge, parent="planetarium")
        a0, a1 = az - math.radians(29.5), az + math.radians(29.5)
        nlat, naz = 7, 5
        for i in range(nlat):
            la0 = lat0 + (math.pi / 2 - lat0) * i / nlat
            la1 = lat0 + (math.pi / 2 - lat0) * (i + 1) / nlat
            for j in range(naz):
                b0 = a0 + (a1 - a0) * j / naz
                b1 = a0 + (a1 - a0) * (j + 1) / naz
                pts = []
                for la, b in ((la0, b0), (la0, b1), (la1, b1), (la1, b0)):
                    pts.append((SUN_R * math.cos(la) * math.cos(b), SUN_R * math.cos(la) * math.sin(b),
                                SUN_Z + SUN_R * math.sin(la)))
                if i == nlat - 1:
                    pts = pts[:3]
                f = p.poly(pts, "petal", smooth=True)[0]
                f.normal_update()
                c = f.calc_center_median()
                if f.normal.dot(c - Vector((0, 0, SUN_Z))) < 0:
                    f.normal_flip()
        # inner skin a little inside, dark
        for i in range(nlat):
            la0 = lat0 + (math.pi / 2 - lat0) * i / nlat
            la1 = lat0 + (math.pi / 2 - lat0) * (i + 1) / nlat
            rr = SUN_R - 0.04
            pts = [(rr * math.cos(la0) * math.cos(a0), rr * math.cos(la0) * math.sin(a0), SUN_Z + rr * math.sin(la0)),
                   (rr * math.cos(la0) * math.cos(a1), rr * math.cos(la0) * math.sin(a1), SUN_Z + rr * math.sin(la0)),
                   (rr * math.cos(la1) * math.cos(a1), rr * math.cos(la1) * math.sin(a1), SUN_Z + rr * math.sin(la1)),
                   (rr * math.cos(la1) * math.cos(a0), rr * math.cos(la1) * math.sin(a0), SUN_Z + rr * math.sin(la1))]
            if i == nlat - 1:
                pts = pts[:3]
            f = p.poly(pts, "petal_in")[0]
            f.normal_update()
            c = f.calc_center_median()
            if f.normal.dot(c - Vector((0, 0, SUN_Z))) > 0:
                f.normal_flip()
        # sun rays: gilt spikes radiating from the petal
        for la, db in ((0.1, 0.0), (0.55, -0.32), (0.55, 0.32), (1.0, 0.0)):
            b = az + db
            d = Vector((math.cos(la) * math.cos(b), math.cos(la) * math.sin(b), math.sin(la)))
            base = Vector((0, 0, SUN_Z)) + d * (SUN_R - 0.02)
            K.cone(p, tuple(base), tuple(d), 0.6 if db == 0.0 else 0.42, 0.09, "ray", segments=4, tip=0.01)
        parts.append(p)
    return parts


def planet_mesh(p, c, r, mat, segs=16, rings=10):
    return K.sphere(p, c, r, mat, segments=segs, rings=rings)


def uv_density(part, slots, k):
    """Scales the metre UVs of the faces in ``slots`` by ``k`` (k < 1 =
    fewer texels): for surfaces seen only when the sun opens (the core
    glows, the petals' dark insides)."""
    from artlib.geo import box_project
    part.bm.normal_update()
    ids = {part.slots.index(sl) for sl in slots if sl in part.slots}
    for f in part.bm.faces:
        if f.material_index not in ids:
            continue
        if not f[part.lock]:
            box_project(f, part.uv)
            f[part.lock] = 1
        for loop in f.loops:
            loop[part.uv].uv = loop[part.uv].uv * k


def build_rig():
    root = Part("planetarium")
    platform(root)
    tiers = []
    planets = []
    markers = [("sun_core", (0.0, 0.0, SUN_Z), "sun_glow")]
    specs = [
        # tier, pivot z, beam z0-z1, reach, planets [(index, angle, radius, centre z, size, material)]
        ("tier_low", 0.45, 0.3, 0.55, 5.0,
         [(1, math.pi, 2.4, 1.2, 0.25, "mercury"), (2, 0.0, 4.75, 1.3, 0.35, "venus")]),
        ("tier_mid", 1.6, 1.45, 1.75, 3.6,
         [(3, 0.0, 3.3, 2.45, 0.4, "earth"), (4, math.pi, 3.0, 2.35, 0.32, "mars")]),
        ("tier_high", 2.8, 2.65, 2.95, 5.0,
         [(5, 0.0, 4.5, 3.75, 0.65, "jupiter"), (6, math.pi, 4.5, 3.65, 0.5, "saturn")]),
    ]
    for name, zp, z0, z1, reach, pls in specs:
        base = TIER_ANGLE[name]
        t = Part(name, origin=(0.0, 0.0, zp), parent="planetarium")
        hub(t, z0 - 0.1, z1 + 0.1)
        for ang in (0.0, math.pi):
            girder(t, HUB + 0.05, reach, z0, z1, base + ang)
        for (idx, ang, rad, cz, size, mat) in pls:
            a = base + ang
            x, y = rad * math.cos(a), rad * math.sin(a)
            rod(t, x, y, z1, cz - size - 0.02)
            c = (x, y, cz)
            pl = Part(f"planet_{idx}", origin=c, parent=name)
            planet_mesh(pl, c, size, mat, segs=20 if size > 0.45 else 16, rings=12 if size > 0.45 else 10)
            if mat == "earth":
                # the Moon on a little crank arm, tangential to the orbit
                tx, ty = -math.sin(a), math.cos(a)
                mc = (x + tx * 0.7, y + ty * 0.7, cz + 0.12)
                pl.tube([(x, y, cz - size * 0.3), (x + tx * 0.35, y + ty * 0.35, cz - 0.08), mc], 0.016, "brass",
                        sides=5)
                planet_mesh(pl, mc, 0.14, "moon", segs=12, rings=8)
            if mat == "saturn":
                ring = pl.lathe([(0.66, 0.0), (1.05, 0.0)], "rings", segments=32, cap_bottom=False, cap_top=False)
                ring_b = pl.lathe([(1.05, -0.003), (0.66, -0.003)], "rings", segments=32, cap_bottom=False,
                                  cap_top=False)
                pl.move(ring + ring_b, Matrix.Translation(c) @ Matrix.Rotation(a, 4, 'Z')
                        @ Matrix.Rotation(math.radians(18), 4, 'Y'))
            planets.append(pl)
            markers.append((f"socket_{idx}", c, name))
        if name == "tier_high":
            # moons hanging on rods down to ~0.95 m; nothing between r 3.7 and 4.6: stand there
            for ang in (0.0, math.pi):
                a = base + ang
                for rad in (1.2, 1.9, 2.6, 3.3, 5.0):
                    x, y = rad * math.cos(a), rad * math.sin(a)
                    drop = 1.1 + (0.2 if rad in (1.9, 3.3) else 0.0)
                    K.seg(t, (x, y, z0), (x, y, drop + 0.12), [(0.018, 0.0), (0.018, 1.0)], "brass", segments=6)
                    planet_mesh(t, (x, y, drop), 0.15, "moon", segs=12, rings=8)
        tiers.append(t)
    petals = sun_petals()
    glow = Part("sun_glow", origin=(0.0, 0.0, SUN_Z), parent="planetarium")
    planet_mesh(glow, (0.0, 0.0, SUN_Z), SUN_R * 0.68, "core", segs=18, rings=12)
    uv_density(glow, ("core",), 0.5)
    for pt in petals:
        uv_density(pt, ("petal_in",), 0.5)
    return [root] + tiers + planets + petals + [glow], markers


# --- materials ------------------------------------------------------------------------

def _zodiac(ctx):
    """Blue enamel ring with a gilt band and twelve zodiac stations."""
    s = E.enamel_blue(ctx, seed=801, center=4.4, stars=0.05)
    r = np.hypot(ctx.p[:, 0], ctx.p[:, 1])
    a = np.arctan2(ctx.p[:, 1], ctx.p[:, 0])
    band = (np.abs(r - 1.75) < 0.012) | (np.abs(r - 1.45) < 0.012)
    station = (r > 1.45) & (r < 1.75) & (np.abs(np.mod(a, math.tau / 12) - math.tau / 24) < 0.006 / np.maximum(r, 0.1) * 6)
    sign = (r > 1.52) & (r < 1.68) & (np.abs(np.mod(a + math.tau / 24, math.tau / 12) - math.tau / 24) < 0.045) & \
        (ctx.fbm(40.0, 1, 802) > 0.0)
    g = band | station | sign
    s.use_ramp(P["gold"], mask=g, shade=np.full(ctx.N, 6.8) + _dither(ctx, 1.0, 803))
    s.metal = np.where(g, 0.9, s.metal)
    s.rough = np.where(g, 0.3, s.rough)
    return s


def _planet(kind):
    def fn(ctx):
        s = Surface(ctx.N)
        c = ctx.p - ctx.p.mean(axis=0)
        n = c / np.maximum(np.linalg.norm(c, axis=1, keepdims=True), 1e-6)
        lat = np.arcsin(np.clip(n[:, 2], -1, 1))
        lon = np.arctan2(n[:, 1], n[:, 0])
        shade_ao = (1.0 - ctx.ao) * 2.0
        if kind == "earth":
            land = ctx.fbm(3.0, 4, 811, p=n * 1.0) > 0.12
            ice = np.abs(lat) > 1.25
            s.use_ramp(P["enl_ocean"], shade=4.0 + ctx.fbm(9.0, 2, 812) * 0.6 - shade_ao)
            s.use_ramp(P["enl_land"], mask=land, shade=np.full(ctx.N, 3.5) + ctx.fbm(12.0, 2, 813) * 1.2 - shade_ao)
            s.use_ramp(P["enl_paper"], mask=ice, shade=np.full(ctx.N, 7.0))
            s.rough = np.where(land, 0.6, 0.25)
        elif kind in ("jupiter", "saturn"):
            ramp = "enl_jupiter" if kind == "jupiter" else "enl_saturn"
            wav = ctx.fbm(np.array([2.0, 2.0, 0.5]), 3, 814, p=np.stack([lon, lon * 0.0, lat * 6.0], axis=1)) * 0.35
            band = np.sin((lat + wav * 0.2) * (14.0 if kind == "jupiter" else 10.0))
            s.use_ramp(P[ramp], shade=4.0 + band * 1.8 + ctx.fbm(14.0, 2, 815) * 0.5 - shade_ao)
            if kind == "jupiter":
                spot = np.hypot((lon - 0.8) * 2.2, (lat + 0.32) * 5.0) < 0.35
                s.use_ramp(P["enl_mars"], mask=spot, shade=np.full(ctx.N, 4.5) + _dither(ctx, 0.6, 816))
            s.rough = np.full(ctx.N, 0.45)
        else:
            ramp = {"mercury": "enl_mercury", "venus": "enl_venus", "mars": "enl_mars", "moon": "enl_mercury"}[kind]
            f1, f2, _ = ctx.worley(18.0, 817, p=n)
            crater = (f1 < 0.18) if kind in ("mercury", "moon") else np.zeros(ctx.N, dtype=bool)
            s.use_ramp(P[ramp], shade=3.6 + ctx.fbm(6.0, 3, 818, p=n * 1.5) * 1.4 - crater * 1.2 - shade_ao
                       + (np.abs(lat) > 1.3) * (1.5 if kind == "mars" else 0.0))
            s.rough = np.full(ctx.N, 0.7)
        return s
    return fn


def _rings(ctx):
    s = Surface(ctx.N)
    r = np.linalg.norm(ctx.p - ctx.p.mean(axis=0), axis=1)
    band = np.sin(r * 90.0) + (np.abs(r - 0.7) < 0.02) * -3.0
    s.use_ramp(P["enl_saturn"], shade=4.0 + band * 1.2 + _dither(ctx, 0.6, 821) - (1.0 - ctx.ao) * 2.0)
    s.rough = np.full(ctx.N, 0.5)
    return s


def _core(ctx):
    s = Surface(ctx.N)
    sh = 5.0 + ctx.fbm(6.0, 4, 831) * 1.8 + ctx.ridged(4.0, 3, 832) * 0.8 + _dither(ctx, 0.5, 833)
    s.use_ramp(P["enl_sun"], shade=sh)
    s.rough = np.full(ctx.N, 0.3)
    s.emit = s.colors() * 1.0
    return s


def _petal(ctx):
    """Gilt shell of the sun: engraved meridians every 10 degrees, and a band
    of blue enamel with gilt stars round its shoulders."""
    s = E.gilt(ctx, seed=841)
    d = ctx.p - np.array([0.0, 0.0, SUN_Z])
    r = np.maximum(np.linalg.norm(d, axis=1), 1e-6)
    lat = np.arcsin(np.clip(d[:, 2] / r, -1, 1))
    lon = np.arctan2(d[:, 1], d[:, 0])
    step = math.radians(10.0)
    w = ctx.texel / np.maximum(r * np.cos(lat), 0.05)
    line = np.abs(np.mod(lon + step / 2, step) - step / 2) < w * 0.75
    s.shade[line & (lat < 1.3)] -= 2.2
    bandm = np.abs(lat - math.radians(18.0)) < math.radians(7.0)
    edge = np.abs(np.abs(lat - math.radians(18.0)) - math.radians(7.0)) < ctx.texel / r
    s.use_ramp(P["enl_enamel_blue"], mask=bandm & ~edge, shade=np.full(ctx.N, 4.6) + _dither(ctx, 0.6, 842))
    star = bandm & ~edge & (ctx.rand(843) > 0.93)
    s.use_ramp(P["gold"], mask=star, shade=np.full(ctx.N, 7.5))
    s.metal = np.where(bandm & ~edge & ~star, 0.0, s.metal)
    s.rough = np.where(bandm & ~edge & ~star, 0.12, s.rough)
    return s


def _arm_enamel(ctx):
    return E.enamel_blue(ctx, seed=851, center=4.0, stars=0.08)


def build():
    parts, markers = build_rig()
    fns = {"brass": E.worn_brass, "dark_brass": E.dark_brass, "gilt": E.gilt, "zodiac": _zodiac,
           "enamel": lambda c: E.enamel_blue(c, seed=861, center=4.8, stars=0.04), "arm_enamel": _arm_enamel,
           "mercury": _planet("mercury"), "venus": _planet("venus"), "earth": _planet("earth"),
           "mars": _planet("mars"), "jupiter": _planet("jupiter"), "saturn": _planet("saturn"),
           "moon": _planet("moon"), "rings": _rings, "core": _core, "petal": _petal,
           "petal_in": lambda c: E.dark_brass(c, seed=871), "ray": E.gilt,
           "zodiac_band": lambda c: E.enamel_blue(c, seed=881, center=4.2, stars=0.25)}
    return Model("planetarium", parts, fns, ppm=96, ground=0.0, ao_dist=0.5, ao_rays=10, ao_stride=2, front=1,
                 markers=markers, preview_yaws=(-30.0, 30.0, 120.0, 210.0), preview_elevation=22.0,
                 preview_extra=[("sun", (0.0, 0.0, SUN_Z), 2.0, -20.0, 10.0),
                                ("planets", (3.0, 0.0, 2.4), 2.6, 70.0, 12.0)])
