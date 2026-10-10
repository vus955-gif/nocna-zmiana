"""Sculpted heads for statues: a dense sphere pushed into an idealised
Egyptian royal face by smooth fields (no metaball lumps): a cranium and a
tapering jaw, a flat face plane, a brow ridge, almond eyes under heavy upper
lids, a straight nose with flared wings, full lips with a faint smile, a
rounded chin, cheekbones. Units: the head is 1.0 from chin to crown, centred
on the origin, facing +Y. ``head_mesh`` returns a Blender mesh for
sculpt.into_part; ``EYES`` and ``in_eye`` locate the inlaid eyes so a model
can lift them into their own part (flush with the face).

The same face, with other proportions (``style``), serves the colossus, the
striding kings, the colossal head of Amenhotep and the coffin mask.
"""
import math

import bmesh
import bpy
import numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree

EYES = ((-0.15, 0.05), (0.15, 0.05))      # (x, z) of the eye centres, unit head


def _g(x, z, cx, cz, sx, sz):
    return math.exp(-(((x - cx) / sx) ** 2 + ((z - cz) / sz) ** 2))


def in_eye(x, z, shrink=1.0):
    """True inside an almond eye opening (unit head coordinates); shrink > 1
    gives the outline of the kohl round it."""
    for ex, ez in EYES:
        dx = (x - ex) / (0.072 * shrink)
        if abs(dx) < 1.0:
            # the upper lid arches more than the lower one; the outer corner
            # sits a little higher (the Egyptian almond)
            top = 0.028 * shrink * (1.0 - dx * dx) ** 0.8 + 0.006 * dx * (1 if ex > 0 else -1)
            bot = -0.018 * shrink * (1.0 - dx * dx) ** 0.9 + 0.004 * dx * (1 if ex > 0 else -1)
            dz = z - ez
            if bot < dz < top:
                return True
    return False


def _shape(x, y, z, style):
    """Displaced position of a point of the unit sphere-ish base."""
    jaw = style.get("jaw", 1.0)
    # jaw taper: narrower toward the chin, a fuller cranium
    taper = 0.84 + 0.16 * (1.0 / (1.0 + math.exp(-(z + 0.2) * 8.0)))
    taper = 1.0 - (1.0 - taper) * jaw
    x *= taper
    # the face plane: the front flattened at the sides
    if y > 0:
        y *= 1.0 - 0.1 * min(1.0, (x / 0.34) ** 2)
    out = Vector((x, y, z))
    n = out.normalized()
    d = 0.0
    if y > 0.05:
        f = min(1.0, (y - 0.05) / 0.15)
        nose = style.get("nose", 1.0)
        d += 0.035 * _g(x, z, 0.0, 0.12, 0.26, 0.035) * f                      # brow ridge
        for ex, ez in EYES:
            sgn = 1 if ex > 0 else -1
            d -= 0.045 * _g(x, z, ex, ez, 0.08, 0.055) * f                      # sockets
            d += 0.032 * _g(x, z, ex, ez - 0.002, 0.06, 0.03) * f               # the eyeball under the lids
            d += 0.016 * _g(x, z, ex, ez + 0.032, 0.07, 0.013) * f              # heavy upper lid
            d += 0.026 * _g(x, z, sgn * 0.22, -0.04, 0.07, 0.06) * f            # cheekbones
            d += 0.03 * nose * _g(x, z, sgn * 0.04, -0.125, 0.025, 0.02) * f    # nose wings
        t = min(1.0, max(0.0, (0.1 - z) / 0.24))                                # 0 at the bridge, 1 at the tip
        bridge = 1.0 / (1.0 + math.exp((z - 0.1) * 60.0)) * 1.0 / (1.0 + math.exp(-(z + 0.15) * 60.0))
        d += nose * (0.018 + 0.075 * t) * math.exp(-(x / (0.034 + 0.026 * t)) ** 2) * bridge * f
        d -= 0.018 * _g(x, z, 0.0, -0.17, 0.02, 0.018) * f                      # philtrum
        lips = style.get("lips", 1.0)
        d += 0.05 * lips * _g(x, z, 0.0, -0.205, 0.085, 0.024) * f              # upper lip
        d += 0.048 * lips * _g(x, z, 0.0, -0.258, 0.072, 0.024) * f             # lower lip
        smile = 0.012 * (x / 0.08) ** 2
        d -= 0.04 * _g(x, z, 0.0, -0.232 + smile, 0.088, 0.007) * f             # the mouth line
        for sgn in (-1, 1):
            d -= 0.012 * _g(x, z, sgn * 0.09, -0.225, 0.015, 0.015) * f         # mouth corners
        d += 0.05 * _g(x, z, 0.0, -0.37, 0.075, 0.05) * f                       # chin
        d -= 0.02 * _g(x, z, 0.0, -0.31, 0.06, 0.015) * f                       # under the lower lip
    return out + n * d


def head_mesh(style=None, rings=44, segs=64, name="head"):
    """A dense head mesh (Blender) in unit head coordinates."""
    style = style or {}
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=segs, v_segments=rings, radius=1.0)
    sx, sy, sz = style.get("size", (0.41, 0.47, 0.5))
    cy = style.get("depth_shift", -0.03)
    for v in bm.verts:
        x, y, z = v.co.x * sx, v.co.y * sy + cy, v.co.z * sz + 0.03
        # chin lower and more forward than the back of the skull
        if z < -0.25:
            y += (-0.25 - z) * 0.25 * max(0.0, v.co.y)
        v.co = _shape(x, y, z, style)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    return me


def split_eyes(src, dst, slot, to_unit):
    """Moves the faces of Part ``src`` inside the eye openings into Part
    ``dst`` (slot ``slot``): the inlays stay flush with the face.
    ``to_unit(co)`` maps a model-space point back to unit head coordinates
    (x, z, and y for the front test)."""
    bm = src.bm
    bm.faces.ensure_lookup_table()
    move = []
    for f in bm.faces:
        c = f.calc_center_median()
        ux, uy, uz = to_unit(c)
        if uy > 0.1 and in_eye(ux, uz):
            move.append(f)
    vmap = {}
    for f in move:
        vs = []
        for v in f.verts:
            if v not in vmap:
                vmap[v] = dst.bm.verts.new(v.co.copy())
            vs.append(vmap[v])
        nf = dst._face(vs, slot, smooth=True)
    bmesh.ops.delete(bm, geom=move, context='FACES')
    return len(move)


def _lids(dx, sgn, shrink=1.0):
    top = 0.028 * shrink * max(0.0, 1.0 - dx * dx) ** 0.8 + 0.006 * dx * sgn
    bot = -0.018 * shrink * max(0.0, 1.0 - dx * dx) ** 0.9 + 0.004 * dx * sgn
    return top, bot


def eye_lens_mesh(head, name="eyes", lift=0.003, n=12):
    """Two almond lenses laid on the face of ``head`` (a unit-space mesh from
    head_mesh, before any decimation is fine too): their outline follows the
    eye openings exactly and they hug the surface (ray cast from the front),
    ``lift`` in front of it. Returns a Blender mesh in unit coordinates."""
    bm = bmesh.new()
    bm.from_mesh(head)
    bvh = BVHTree.FromBMesh(bm)
    out = bmesh.new()
    for ex, ez in EYES:
        sgn = 1 if ex > 0 else -1
        pts = []
        for i in range(n + 1):
            dx = -1.0 + 2.0 * i / n
            pts.append((dx, _lids(dx, sgn)[0]))
        for i in range(n - 1, 0, -1):
            dx = -1.0 + 2.0 * i / n
            pts.append((dx, _lids(dx, sgn)[1]))
        ring = []
        for dx, dz in pts:
            x, z = ex + dx * 0.072, ez + dz
            hit = bvh.ray_cast(Vector((x, 2.0, z)), Vector((0.0, -1.0, 0.0)))
            loc, nrm = (hit[0], hit[1]) if hit[0] is not None else (Vector((x, 0.4, z)), Vector((0, 1, 0)))
            ring.append(out.verts.new(loc + nrm * lift))
        hit = bvh.ray_cast(Vector((ex, 2.0, ez)), Vector((0.0, -1.0, 0.0)))
        c = out.verts.new((hit[0] + hit[1] * lift) if hit[0] is not None else Vector((ex, 0.4, ez)))
        for i in range(len(ring)):
            f = out.faces.new((ring[i], ring[(i + 1) % len(ring)], c))
            f.normal_update()
            if f.normal.y < 0:
                f.normal_flip()
    bm.free()
    me = bpy.data.meshes.new(name)
    out.to_mesh(me)
    out.free()
    return me
