"""Floor I, Americas wing guardian: the Two-headed Serpent (Dwugłowy Wąż) of
the Temple of the Serpent - a 14 m serpent of turquoise mosaic on a
carved wooden core, a head at each end: head A spits turquoise shards,
head B lunges and bites. Stylised in the manner of Mexica turquoise
mosaics (the double-headed serpent of the British Museum is its seed, not
its model): turquoise tesserae with a dorsal chain of shell-white diamonds
outlined in obsidian, red shell zigzags down the flanks, rows of gold
beads, gold bands between the segments, a shell-white belly; the heads
with open jaws, red shell mouths, white shell fangs, obsidian eyes in gold
rings and a ruff of plumes - green and gold behind A, red and black
behind B.

Godot axes; origin = the middle of the body on the floor; head A looks -Z
(the front), head B looks +Z. Rest pose: straight and level, the belly on
the floor. 112 px/m.

Parts (pivots in Godot (x, y, z)):
  segment_1 .. segment_14  the body in 0.75 m segments, numbered from head
              A: segment_k spans z = -5.25 + 0.75 (k - 1) .. + 0.75, its
              pivot at its A-side joint on the body axis; a chain -
              segment_1 is the root, segment_k the child of segment_k-1.
              Each is the carved wooden core (cracks glowing in the
              resin: the weak point once exposed) with a shell-white
              belly and a gold band at its joint.
  tiles_1 .. tiles_14      the mosaic plating of each segment (child of
              segment_k, same pivot): hide it (or fling it off as debris)
              when the plating is shot away.
  skull_a     head A: child of segment_1, pivot at the neck (0, 0.66,
              -5.25) - the neck rises from the body into the raised head;
              jaw_a (child) hinged at (0, 0.56, -5.45): rotation.x < 0
              opens it further (rest: open 14 degrees).
  skull_b     head B: child of segment_14, pivot at the neck (0, 0.66,
              5.25), looking +Z; jaw_b (child) hinged at (0, 0.56, 5.45):
              rotation.x > 0 opens it further.
Markers: seg_1 .. seg_14 (children of segment_k: the middle of each
segment on the axis = hit centres), head_a / head_b (inside the skulls,
the heads' weak points), mouth_a / mouth_b (just in front of the open
mouths: projectile origin, the lunge's bite point).
"""
import math

import bmesh
import numpy as np
from mathutils import Matrix, Vector

from artlib import americas as AM
from artlib import americas_paint as AP
from artlib import clay
from artlib import kit as K
from artlib import materials as M
from artlib import sculpt
from artlib import serpent_head as SH
from artlib.geo import Part
from artlib.materials import P, _dither, _select
from artlib.model import Model
from artlib.painter import Surface

N = 14
SEG = 0.75
HALF = N * SEG / 2           # 5.25: the necks
L = 1.9                      # head length (neck to snout tip)
OPEN = 14.0                  # rest opening of the jaws, degrees
PLATE = 0.035                # thickness of the mosaic plating
NECK_Z = 0.78                # the heads ride raised on their necks


def radius(t):
    """Body radius at t = 0 (head A's neck) .. 1 (head B's neck)."""
    return 0.4 + 0.12 * math.sin(math.pi * t) ** 0.7


def axis_z(t):
    return radius(t)


def y_of(k):
    """Blender y of segment k's A-side joint (head A at +Y)."""
    return HALF - SEG * (k - 1)


def ring(p, y, r, zc, slot, n=16, phase=0.0, keep=None):
    return [p.bm.verts.new((r * math.sin(phase + 2 * math.pi * i / n), y, zc + r * math.cos(phase + 2 * math.pi * i / n)))
            for i in range(n)]


def tube_between(p, y0, y1, r0, r1, z0, z1, slot, n=16, steps=3, arc=None, outward=True):
    """A tube (or an arc of one: ``arc`` = (a0, a1) radians from the top,
    clockwise seen from +Y) from y0 to y1; returns its faces."""
    faces = []
    rows = []
    for s in range(steps + 1):
        t = s / steps
        y = y0 + (y1 - y0) * t
        r = r0 + (r1 - r0) * t
        zc = z0 + (z1 - z0) * t
        if arc is None:
            angs = [2 * math.pi * i / n for i in range(n)]
        else:
            angs = [arc[0] + (arc[1] - arc[0]) * i / n for i in range(n + 1)]
        rows.append([p.bm.verts.new((r * math.sin(a), y, zc + r * math.cos(a))) for a in angs])
    m = len(rows[0])
    for s in range(steps):
        for i in range(m if arc is None else m - 1):
            i2 = (i + 1) % m
            f = p._face([rows[s][i], rows[s][i2], rows[s + 1][i2], rows[s + 1][i]], slot, smooth=True)
            f.normal_update()
            c = f.calc_center_median()
            zc = z0 + (z1 - z0) * ((c.y - y0) / (y1 - y0) if y1 != y0 else 0.0)
            radial = Vector((c.x, 0.0, c.z - zc))
            if (f.normal.dot(radial) < 0) == outward:
                f.normal_flip()
            faces.append(f)
    return faces, rows


def segment(k):
    t0 = (k - 1) / N
    t1 = k / N
    y0, y1 = y_of(k), y_of(k) - SEG
    r0, r1 = radius(t0) - PLATE, radius(t1) - PLATE
    z0, z1 = axis_z(t0), axis_z(t1)
    parent = None if k == 1 else f"segment_{k - 1}"
    p = Part(f"segment_{k}", origin=(0.0, y0, z0), parent=parent)
    # the core: carved wood on top and sides, a shell-white belly underneath
    tube_between(p, y0, y1, r0, r1, z0, z1, "core", n=14, steps=2, arc=(-2.2, 2.2))
    tube_between(p, y0, y1, r0 + 0.004, r1 + 0.004, z0, z1, "belly", n=8, steps=2, arc=(2.2, 2 * math.pi - 2.2))
    # gold band at the A-side joint (hides the seam when the chain bends)
    band = p.lathe([(r0 + 0.01, 0.0), (r0 + PLATE + 0.012, 0.012), (r0 + PLATE + 0.012, 0.06), (r0 + 0.01, 0.075)],
                   "band", segments=16, cap_bottom=False, cap_top=False, smooth=True)
    p.move(band, Matrix.Translation(Vector((0.0, y0 + 0.035, z0))) @ Matrix.Rotation(math.radians(90.0), 4, 'X'))
    # the plating: a shell over the top and the flanks
    sh = Part(f"tiles_{k}", origin=(0.0, y0, z0), parent=f"segment_{k}")
    ra0, ra1 = radius(t0), radius(t1)
    outer, orow = tube_between(sh, y0 - 0.02, y1 - 0.01, ra0, ra1, z0, z1, "tiles", n=14, steps=3, arc=(-2.3, 2.3))
    inner, irow = tube_between(sh, y0 - 0.02, y1 - 0.01, ra0 - PLATE, ra1 - PLATE, z0, z1, "tile_back", n=7, steps=1,
                               arc=(-2.3, 2.3), outward=False)
    # rims along the plating's lower edges and at its ends
    _rims(sh, y0 - 0.02, y1 - 0.01, ra0, ra1, z0, z1)
    return p, sh


def _rims(p, y0, y1, r0, r1, z0, z1):
    """Closes the plating: the two lower edges and the two end arcs."""
    for a in (-2.3, 2.3):
        quad = []
        for y, r, zc in ((y0, r0, z0), (y1, r1, z1)):
            quad.append((r * math.sin(a), y, zc + r * math.cos(a)))
            quad.append(((r - PLATE) * math.sin(a), y, zc + (r - PLATE) * math.cos(a)))
        vs = [p.bm.verts.new(quad[i]) for i in (0, 2, 3, 1)]
        f = p._face(vs, "tile_back")
        f.normal_update()
        tang = Vector((math.cos(a), 0.0, -math.sin(a))) * (1 if a > 0 else -1)
        if f.normal.dot(tang) < 0:
            f.normal_flip()
    for y, r, zc, sgn in ((y0, r0, z0, 1), (y1, r1, z1, -1)):
        n = 10
        outer = [(r * math.sin(-2.3 + 4.6 * i / n), y, zc + r * math.cos(-2.3 + 4.6 * i / n)) for i in range(n + 1)]
        inner = [((r - PLATE) * math.sin(-2.3 + 4.6 * i / n), y, zc + (r - PLATE) * math.cos(-2.3 + 4.6 * i / n))
                 for i in range(n + 1)]
        for i in range(n):
            vs = [p.bm.verts.new(c) for c in (outer[i], outer[i + 1], inner[i + 1], inner[i])]
            f = p._face(vs, "tile_back")
            f.normal_update()
            if f.normal.y * sgn < 0:
                f.normal_flip()


def head(which):
    """Head A at +Y looking +Y, head B at -Y turned to look -Y; returns
    (head part, jaw part)."""
    sgn = 1 if which == "a" else -1
    yn = sgn * HALF
    zn = NECK_Z
    name = f"skull_{which}"
    place = Matrix.Translation(Vector((0.0, yn, zn))) @ (Matrix.Identity(4) if sgn > 0 else Matrix.Rotation(math.pi, 4, 'Z'))
    p = Part(name, origin=(0.0, yn, zn), parent="segment_1" if which == "a" else f"segment_{N}")
    # the neck rises from the body's end joint into the raised head
    from artlib.sculpt import limb
    neck = limb([(0.0, 0.12, 0.0), (0.0, -0.08, -0.16), (0.0, -0.22, -(NECK_Z - axis_z(0.0)))],
                [0.19 * L, 0.2, radius(0.0) * 0.95], spacing=0.6)
    me = clay.clay_mesh(SH.upper(L) + neck, resolution=0.03)
    me = sculpt.decimate(me, 2600)
    clay.into_part(p, me, "head_tess", transform=place)
    me = sculpt.metaball_mesh(SH.ruff(L, petals=13), resolution=0.03)
    me = sculpt.decimate(me, 1300)
    clay.into_part(p, me, f"ruff_{which}", transform=place)
    (e1, e2), er, dirs = SH.eyes(L)
    for e, d in zip((e1, e2), dirs):
        f = K.sphere(p, e, er, "eye", segments=12, rings=6)
        p.move(f, place)
        rg = p.lathe([(er * 1.0, -0.02), (er * 1.35, -0.01), (er * 1.38, 0.02), (er * 1.08, 0.035)], "gold", segments=14)
        p.move(rg, place @ Matrix.Translation(Vector(e)) @ Vector(d).normalized().to_track_quat('Z', 'Y').to_matrix().to_4x4())
    big = 1.0 if which == "a" else 1.35
    for root, d, ln in SH.fangs(L, 0.0)[:2]:
        f = K.cone(p, root, d, ln * big, 0.05 * big, "fang", segments=6, tip=0.008)
        p.move(f, place)
    for root, d in SH.teeth(L, 5, 0.0)[:10]:
        f = K.cone(p, root, d, 0.07, 0.022, "fang", segments=5, tip=0.005)
        p.move(f, place)
    hinge = place @ Vector(tuple(c * L for c in SH.JAW_HINGE))
    j = Part(f"jaw_{which}", origin=tuple(hinge), parent=name)
    me = clay.clay_mesh(SH.jaw(L, OPEN), resolution=0.03)
    me = sculpt.decimate(me, 900)
    clay.into_part(j, me, "head_tess", transform=place)
    for root, d, ln in SH.fangs(L, OPEN)[2:]:
        f = K.cone(j, root, d, ln * big, 0.04 * big, "fang", segments=6, tip=0.006)
        j.move(f, place)
    for root, d in SH.teeth(L, 5, OPEN)[10:]:
        f = K.cone(j, root, d, 0.06, 0.02, "fang", segments=5, tip=0.005)
        j.move(f, place)
    pts, tips = SH.tongue(L, OPEN)
    tf = j.tube(pts, 0.045, "tongue", sides=6)
    j.move(tf, place)
    for a, b in tips:
        tf = j.tube([a, b], lambda u: 0.04 * (1 - 0.7 * u), "tongue", sides=5)
        j.move(tf, place)
    return p, j


# --------------------------------------------------------------------------
# paint
# --------------------------------------------------------------------------

def _local(ctx):
    """(theta from the top round the body axis, metres along the body from
    head A's neck) for body texels."""
    y = ctx.p[:, 1]
    t = np.clip((HALF - y) / (2 * HALF), 0.0, 1.0)
    zc = np.array([axis_z(v) for v in np.linspace(0, 1, 64)])[np.clip((t * 63).astype(int), 0, 63)]
    th = np.arctan2(ctx.p[:, 0], ctx.p[:, 2] - zc)
    return th, HALF - y


def tiles_paint(ctx, seed=2301):
    """Turquoise mosaic plating: a dorsal chain of shell-white diamonds
    outlined in obsidian, red shell zigzags on the flanks, a row of gold
    beads either side."""
    th, along = _local(ctx)
    r = np.array([radius(v) for v in np.linspace(0, 1, 64)])[np.clip((along / (2 * HALF) * 63).astype(int), 0, 63)]
    across = th * r                                   # metres round from the top
    s = AM.mosaic(ctx, seed, "am_turq", cell=0.045, center=5.6, mix=0.2, spread=1.8, gap_texels=0.6)
    # dorsal diamonds every 0.375 m
    ph = np.mod(along / 0.375, 1.0) - 0.5
    dia = np.abs(ph) * 0.375 + np.abs(across)
    white = dia < 0.11
    outline = (dia >= 0.11) & (dia < 0.15)
    s.merge(_select(AM.mosaic(ctx, seed + 1, "am_shell", cell=0.045, center=6.0, mix=0.0, spread=1.2, gap_texels=0.6),
                    white), white)
    s.merge(_select(AM.obsidian(ctx, seed + 2, center=2.4), outline), outline)
    # red zigzags down the flanks
    zz = np.abs(np.mod(along / 0.25, 1.0) - 0.5) * 0.12
    flank = np.abs(np.abs(across) - (0.48 + zz)) < 0.035
    s.merge(_select(AM.mosaic(ctx, seed + 3, "am_spondylus", cell=0.04, center=5.0, mix=0.0, spread=1.2, gap_texels=0.6),
                    flank), flank)
    # gold beads
    bead = (np.abs(np.abs(across) - 0.3) < 0.03) & (np.abs(np.mod(along / 0.125, 1.0) - 0.5) < 0.22)
    s.merge(_select(M.gold(ctx, seed + 4), bead), bead)
    return s


def core_paint(ctx, seed=2311):
    """The carved wooden core under the plating: dark cedar smeared with
    black resin (the old adhesive), a few tesserae still stuck, and cracks
    glowing from within - the serpent's life showing through."""
    s = AM.carved_wood(ctx, seed, ramp="am_wood_dark", center=3.4, adze=1.0)
    resin = ctx.fbm(5.0, 3, seed + 1) > -0.05
    s.use_ramp(P["am_resin"], mask=resin, shade=np.full(ctx.N, 2.4) + ctx.fbm(20.0, 2, seed + 2) * 1.0)
    s.rough = np.where(resin, 0.35, s.rough)
    left = (ctx.worley(22.0, seed + 3)[2] > 0.93) & resin
    s.use_ramp(P["am_turq"], mask=left, shade=np.full(ctx.N, 4.6))
    crack = np.abs(ctx.fbm(np.array([1.5, 4.0, 1.5]), 4, seed + 4)) < 0.035
    s.use_ramp(P["am_ember"], mask=crack, shade=np.full(ctx.N, 5.0) + _dither(ctx, 0.8, seed + 5))
    s.emit = np.zeros((ctx.N, 3))
    s.emit[crack] = s.colors()[crack] * 1.0
    s.height = s.height - crack * 0.004
    return s


def head_paint(which):
    def fn(ctx, seed=2321):
        s = AM.mosaic(ctx, seed, "am_turq", cell=0.04, center=5.8, mix=0.2, spread=1.8, gap_texels=0.6)
        mouth = ctx.n[:, 2] < -0.35
        red = AM.mosaic(ctx, seed + 1, "am_spondylus", cell=0.035, center=5.0, mix=0.0, spread=1.2, gap_texels=0.6)
        s.merge(_select(red, mouth), mouth)
        # gold on the nose scroll and a shell-white lip line
        sgn = 1 if which == "a" else -1
        local_y = (ctx.p[:, 1] - sgn * HALF) * sgn
        z = ctx.p[:, 2] - NECK_Z
        scroll = (local_y > 0.82 * L) & (z > 0.12 * L) & (np.abs(ctx.p[:, 0]) < 0.08 * L)
        s.merge(_select(M.gold(ctx, seed + 2), scroll), scroll)
        lip = (np.abs(z + 0.02 * L) < 0.025) & (ctx.n[:, 2] > -0.3) & (local_y > 0.4 * L)
        s.merge(_select(AM.shell(ctx, seed + 3), lip), lip)
        return s
    return fn


def ruff_paint(which):
    def fn(ctx, seed=2331):
        if which == "a":
            s = AM.feathers(ctx, "am_feather_green", (0.0, 0.0, 1.0), seed, 4.4)
            tip = ctx.fbm(3.0, 2, seed + 1) > 0.25
            s.merge(_select(M.gold(ctx, seed + 2), tip), tip)
        else:
            s = AM.feathers(ctx, "am_feather_red", (0.0, 0.0, 1.0), seed, 4.4)
            tip = ctx.fbm(3.0, 2, seed + 1) > 0.25
            s.merge(_select(AM.obsidian(ctx, seed + 2, 2.6), tip), tip)
        return s
    return fn


def build():
    parts = []
    for k in range(1, N + 1):
        seg, sh = segment(k)
        parts += [seg, sh]
    ha, ja = head("a")
    hb, jb = head("b")
    parts += [ha, ja, hb, jb]
    fns = {"core": core_paint, "belly": lambda c: AM.mosaic(c, 2341, "am_shell", cell=0.05, center=5.6, mix=0.0,
                                                             spread=1.2, gap_texels=0.6),
           "band": lambda c: M.gold(c, 2343), "tiles": tiles_paint,
           "tile_back": lambda c: AM.carved_wood(c, 2345, "am_wood_dark", 2.6),
           "head_tess": None, "ruff_a": ruff_paint("a"), "ruff_b": ruff_paint("b"),
           "eye": lambda c: AM.obsidian(c, 2347, 3.0), "gold": lambda c: M.gold(c, 2349),
           "fang": lambda c: AM.shell(c, 2351, 6.6), "tongue": lambda c: AM.mosaic(c, 2353, "am_spondylus", cell=0.03,
                                                                                    center=4.6, mix=0.0)}

    def head_tess(ctx):
        out = Surface(ctx.N)
        for which, names in (("a", ("skull_a", "jaw_a")), ("b", ("skull_b", "jaw_b"))):
            m = np.zeros(ctx.N, bool)
            for nm in names:
                m |= ctx.part == [p.name for p in parts].index(nm)
            if m.any():
                out.merge(head_paint(which)(ctx.subset(m)), m)
        return out
    fns["head_tess"] = head_tess
    markers = []
    for k in range(1, N + 1):
        t = (k - 0.5) / N
        markers.append((f"seg_{k}", (0.0, y_of(k) - SEG / 2, axis_z(t)), f"segment_{k}"))
    zn = NECK_Z
    for which, sgn in (("a", 1), ("b", -1)):
        markers.append((f"head_{which}", (0.0, sgn * (HALF + 0.45 * L), zn + 0.08 * L), f"skull_{which}"))
        markers.append((f"mouth_{which}", (0.0, sgn * (HALF + 1.02 * L), zn - 0.1 * L), f"skull_{which}"))
    organic = ("skull_a", "skull_b", "jaw_a", "jaw_b")
    return Model("serpent", parts, fns, ppm=112, ground=0.0, ao_dist=0.3, front=1, organic=organic, markers=markers,
                 preview_yaws=(-60.0, 20.0, 100.0, 200.0), preview_elevation=25.0,
                 preview_extra=[("head_a", (0.0, HALF + 0.9, 0.7), 1.4, 30.0, 10.0),
                                ("head_b", (0.0, -HALF - 0.9, 0.7), 1.4, 210.0, 10.0),
                                ("body", (0.0, 0.0, 0.4), 1.6, 70.0, 25.0)])
