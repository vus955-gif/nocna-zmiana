"""Reusable hard-surface pieces built on geo.Part: lathes between two points
(limbs, bones, barrels), spheres, cones, partial shells with thickness
(armour plates), bending (curved shields). Stage 2 models use these."""
import math

import bmesh
from mathutils import Matrix, Vector


def T(x, y=None, z=None):
    if y is None:
        x, y, z = x
    return Matrix.Translation(Vector((x, y, z)))


def R(axis, deg):
    return Matrix.Rotation(math.radians(deg), 4, axis)


def S(sx, sy, sz):
    m = Matrix.Identity(4)
    m[0][0], m[1][1], m[2][2] = sx, sy, sz
    return m


def align(a, b):
    """Matrix taking local +Z (length |b - a|) onto the segment a -> b."""
    a, b = Vector(a), Vector(b)
    q = (b - a).normalized().to_track_quat('Z', 'Y')
    return Matrix.Translation(a) @ q.to_matrix().to_4x4()


def seg(p, a, b, radii, mat, segments=10, squash=(1.0, 1.0), smooth=True, caps=True, phase=0.0, ring_scale=None):
    """Lathe whose axis runs from a to b. radii = [(r, t), ...] with t = 0..1
    along the segment (bottom -> top)."""
    length = (Vector(b) - Vector(a)).length
    prof = [(r, t * length) for r, t in radii]
    faces = p.lathe(prof, mat, segments=segments, cap_bottom=caps, cap_top=caps, smooth=smooth, squash=squash,
                    phase=phase, ring_scale=ring_scale)
    p.move(faces, align(a, b))
    return faces


def sphere(p, c, r, mat, segments=10, rings=6, squash=(1.0, 1.0), zscale=1.0, smooth=True):
    prof = []
    for k in range(rings + 1):
        a = -math.pi / 2 + math.pi * k / rings
        prof.append((r * math.cos(a) if 0 < k < rings else 0.0, r * math.sin(a) * zscale))
    return p.lathe(prof, mat, segments=segments, center=c, squash=squash, smooth=smooth)


def cone(p, base, direction, length, radius, mat, segments=6, tip=0.0, smooth=False):
    f = p.lathe([(radius, 0.0), (radius * 0.8, length * 0.5), (tip, length)], mat, segments=segments, smooth=smooth,
                cap_top=tip > 0)
    d = Vector(direction).normalized()
    p.move(f, Matrix.Translation(Vector(base)) @ d.to_track_quat('Z', 'Y').to_matrix().to_4x4())
    return f


def keep(p, faces, pred):
    """Deletes the faces whose centre fails ``pred(Vector)``; returns the rest."""
    drop = [f for f in faces if not pred(f.calc_center_median())]
    kept = [f for f in faces if f not in set(drop)]
    if drop:
        bmesh.ops.delete(p.bm, geom=drop, context='FACES')
    return kept


def thicken(p, faces, thickness):
    """Gives an open shell real thickness (bmesh solidify). The new faces are
    box-projected later (their UVs are unlocked). Returns all shell faces."""
    before = set(p.bm.faces)
    smooth = any(f.smooth for f in faces)
    bmesh.ops.solidify(p.bm, geom=list(faces), thickness=thickness)
    new = [f for f in p.bm.faces if f not in before]
    out = list(faces) + new
    for f in out:
        f[p.lock] = 0
        # smooth shells stay smooth; the rims meet them at 90 degrees, so
        # Part.finalize marks those edges sharp (and they get painted edges)
        f.smooth = smooth
    return out


def bend(p, faces, radius, axis_y=0.0):
    """Curves geometry around a vertical axis behind it: x runs along an arc
    of ``radius``, the sides fall back toward -Y (a curved shield)."""
    verts = {v for f in faces for v in f.verts}
    for v in verts:
        a = v.co.x / radius
        rr = radius + (v.co.y - axis_y)
        v.co.x = rr * math.sin(a)
        v.co.y = axis_y + rr * math.cos(a) - radius
    return faces


def screen(p, center, width, height, slot, bulge=0.008, nx=6, ny=4, matrix=None):
    """A CRT screen facing -Y: a slightly bulged grid whose UVs span 0..1
    (u left -> right as seen from the front, v bottom -> top) and stay
    locked, so the slot can be exported as its own material and fed a
    texture or a viewport by the game."""
    cx, cy, cz = center
    verts = []
    for j in range(ny + 1):
        row = []
        for i in range(nx + 1):
            u, v = i / nx, j / ny
            x = (u - 0.5) * width
            z = (v - 0.5) * height
            b = bulge * (1 - (2 * u - 1) ** 2) * (1 - (2 * v - 1) ** 2)
            row.append((p.bm.verts.new((cx + x, cy - b, cz + z)), (u, v)))
        verts.append(row)
    faces = []
    for j in range(ny):
        for i in range(nx):
            quad = [verts[j][i], verts[j][i + 1], verts[j + 1][i + 1], verts[j + 1][i]]
            f = p._face([q[0] for q in quad], slot, smooth=True)
            f.normal_update()
            if f.normal.y > 0:
                f.normal_flip()
            for loop in f.loops:
                for vert, uv in quad:
                    if loop.vert == vert:
                        loop[p.uv].uv = uv
            f[p.lock] = 1
            faces.append(f)
    if matrix is not None:
        p.move(faces, matrix)
    return faces


def plate_ring(p, center, profile, mat, segments=16, squash=(1.0, 1.0), keep_pred=None, thickness=0.0,
               smooth=True):
    """A lathe band (armour hoop, helmet part); optionally cut to the faces
    passing ``keep_pred`` and thickened into a solid plate."""
    faces = p.lathe(profile, mat, segments=segments, center=center, cap_bottom=False, cap_top=False, smooth=smooth,
                    squash=squash)
    if keep_pred is not None:
        faces = keep(p, faces, keep_pred)
    if thickness > 0:
        faces = thicken(p, faces, thickness)
    return faces
