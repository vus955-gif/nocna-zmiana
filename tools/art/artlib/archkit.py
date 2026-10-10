"""Shared helpers for the modular architecture kit (tools/art/models/kit_*.py).

Kit convention (the same as src/level/level_kit.gd, so a greybox piece can be
swapped for its model without any extra turn): origin = centre of the base,
+Y up, the FRONT faces Godot -Z (Blender +Y). Wall-mounted runs (skirting,
wainscot, cornices, pipes) have the wall plane at Blender y = 0 (Godot z = 0),
the decoration on the room side (Godot -Z) and span x = -W/2 .. W/2.

Pieces are modelled like the stage 1 walls (viewer at -Y, the direction the
Part helpers extrude and sweep towards) and turned 180 degrees about Z at the
end by ``kit()``: a rotation, not a mirror, so text stays readable.
"""
import math
import zlib

import bmesh
from mathutils import Matrix, Vector

from .model import Model

# module lengths of the wall runs and their name suffixes
LENGTHS = ((4.0, "4m"), (2.0, "2m"), (1.0, "1m"), (0.5, "05m"))


def seed_of(name):
    """Deterministic per-model seed (zlib.crc32; Python's hash() is salted)."""
    return zlib.crc32(name.encode()) % 997


def facing(p, pts, mat, want):
    """Polygon whose normal is flipped to point along ``want`` (x, y, z)."""
    f = p.poly(pts, mat)[0]
    f.normal_update()
    if f.normal.dot(Vector(want)) < 0:
        f.normal_flip()
    return f


def quad_front(p, x0, x1, z0, z1, mat, y=0.0):
    """Flat rectangle in the plane y, facing the viewer (-Y)."""
    return facing(p, [(x0, y, z0), (x1, y, z0), (x1, y, z1), (x0, y, z1)], mat, (0, -1, 0))


def moulding(p, prof, W, mat, x0=None):
    """Profile [(depth toward the viewer (negative y), z), ...] extruded along
    x from -W/2 to W/2 (or x0 .. x0 + W), open ends (runs butt together)."""
    a = -W / 2 if x0 is None else x0
    return p.extrude(prof, a, a + W, mat, caps=False)


def turn(model):
    """Turns a model built facing -Y into the kit convention (front +Y in
    Blender = -Z in Godot): 180 degrees about the vertical axis through the
    origin. Part pivots and markers turn with it."""
    rot = Matrix.Rotation(math.pi, 4, 'Z')
    for part in model.parts:
        bmesh.ops.transform(part.bm, matrix=rot, verts=part.bm.verts[:])
        part.origin = (rot @ Vector(part.origin).to_4d()).to_3d()
    model.markers = [(n, tuple((rot @ Vector(c).to_4d()).to_3d()), par) for n, c, par in model.markers]
    model.front = 1
    return model


def kit(name, parts, fns, ppm=64, wall=False, ground=0.0, ceiling=None, planes=(), built_final=False, **kw):
    """Model in the kit convention. ``wall`` adds an implied wall plane at
    y = 0 (behind the piece) for ambient occlusion, ``ceiling`` one at that Z,
    ``planes`` any others as (axis, value) in the final (turned) frame.
    ``built_final``: the parts are already modelled front +Y (no turn)."""
    planes = list(planes)
    if wall:
        planes.append(("y", 0.0))
    if ceiling is not None:
        planes.append(("z", ceiling))
    kw.setdefault("seed", seed_of(name))
    kw.setdefault("ao_dist", 0.4)
    # the AO rays are cast one by one in Python: big architecture pieces sample
    # every third texel (blocky AO suits the pixel style anyway)
    kw.setdefault("ao_stride", 3)
    kw.setdefault("ao_rays", 10)
    m = Model(name, parts, fns, ppm=ppm, ground=ground, ao_planes=tuple(planes), **kw)
    if built_final:
        m.front = 1
        return m
    return turn(m)


def front_prism(p, outline_xz, depth, mat, bevel=0.0, y_back=0.0):
    """A block whose front outline (x, z points, counter-clockwise as seen
    from the viewer at -Y) is pushed ``depth`` toward the viewer from the
    plane y = y_back (voussoirs, gables, shaped panels)."""
    faces = p.ngon_prism([(x, z) for x, z in outline_xz], 0.0, depth, mat, bevel=bevel)
    # (x, y, z) -> (x, -z, y): the outline's y becomes height, the prism's z depth
    p.move(faces, Matrix.Translation((0.0, y_back, 0.0)) @ Matrix.Rotation(math.radians(90), 4, 'X'))
    return faces


def plan_sweep(p, profile, path_xy, mat):
    """Moulding swept round a closed plan outline (plinths, pedestals):
    ``profile`` = [(height, outward offset), ...] from the bottom up,
    ``path_xy`` = the outline, clockwise seen from above. Corners are
    mitred; UVs stay in metres (u along the outline, v up the profile)."""
    faces = p.sweep(profile, path_xy, mat, closed=True)
    # wall-plane sweep: (x, depth, z) -> plan (x, z) and height = depth
    p.move(faces, Matrix.Rotation(math.radians(-90), 4, 'X'))
    return faces


def cull_floor(parts, eps=0.02):
    """Deletes faces lying on the floor (z < eps) and facing down: nobody
    ever sees them, and big ones waste atlas space."""
    for part in parts:
        bm = part.bm
        bm.normal_update()
        drop = [f for f in bm.faces if f.normal.z < -0.9 and max(v.co.z for v in f.verts) < eps]
        if drop:
            bmesh.ops.delete(bm, geom=drop, context='FACES')


def orient_out(faces, center):
    """Flips a closed shell (e.g. a looped extrude profile) so its faces point
    away from ``center`` (the Part helpers orient toward a viewer at -Y)."""
    c = Vector(center)
    score = 0.0
    for f in faces:
        f.normal_update()
        score += f.normal.dot(f.calc_center_median() - c)
    if score < 0.0:
        for f in faces:
            f.normal_flip()
    return faces


def arc(cx, cz, r, a0, a1, n):
    """Points on a circle in the x-z plane from angle a0 to a1 (radians)."""
    return [(cx + r * math.cos(a0 + (a1 - a0) * i / n), cz + r * math.sin(a0 + (a1 - a0) * i / n))
            for i in range(n + 1)]
