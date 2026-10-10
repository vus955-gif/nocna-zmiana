"""Geometry for the Assyrian wing: flat slabs cut along relief outlines (the
relief enemies, the figures of the awakening slabs), caps with holes
(a slab face with a figure-shaped pocket), lofted bodies (lamassu).

Relief coordinates (u right, v up, metres) map onto Blender x = -u, z = v
by default: a model that faces +Y (an enemy facing the player, or a kit
piece after archkit.turn) then shows the drawing the right way round, the
figure looking to the viewer's right as on the slabs. Materials read the
drawing back with ``UV`` (u = -x, v = z of the texel)."""
import math

from mathutils import Vector
from mathutils.geometry import tessellate_polygon


def UV(ctx):
    """(u, v) relief coordinates of baked texels for geometry made here."""
    return -ctx.p[:, 0], ctx.p[:, 2]


def _xz(pt, mirror=True):
    u, v = pt
    return (-u if mirror else u), v


def cap(p, loops, y, slot, normal_y, mirror=True):
    """A flat cap in the plane y from closed loops (first = outline, others
    = holes), triangulated; faces point along +Y (normal_y > 0) or -Y."""
    pts3 = [[(x, y, z) for x, z in (_xz(q, mirror) for q in loop)] for loop in loops]
    tris = tessellate_polygon(pts3)
    flat = [v for loop in pts3 for v in loop]
    verts = [p.bm.verts.new(v) for v in flat]
    faces = []
    for a, b, c in tris:
        if a == b or b == c or a == c:
            continue
        try:
            f = p._face([verts[a], verts[b], verts[c]], slot)
        except ValueError:
            continue
        f.normal_update()
        if f.normal.y * normal_y < 0:
            f.normal_flip()
        faces.append(f)
    return faces


def walls(p, loop, y0, y1, slot, outward=True, mirror=True):
    """Side walls of a prism along a closed loop between y0 and y1, facing
    away from the loop's inside (``outward``) or into it (a pocket)."""
    n = len(loop)
    cx = sum(q[0] for q in loop) / n
    cz = sum(q[1] for q in loop) / n
    area = 0.0
    for (a, b) in zip(loop, loop[1:] + loop[:1]):
        area += a[0] * b[1] - b[0] * a[1]
    ccw = area > 0
    faces = []
    for i in range(n):
        a = loop[i]
        b = loop[(i + 1) % n]
        ax, az = _xz(a, mirror)
        bx, bz = _xz(b, mirror)
        f = p.poly([(ax, y0, az), (bx, y0, bz), (bx, y1, bz), (ax, y1, az)], slot)[0]
        f.normal_update()
        # the outward normal of edge a -> b in (u, v): (dv, -du) for a CCW loop
        du, dv = b[0] - a[0], b[1] - a[1]
        nu, nv = (dv, -du) if ccw else (-dv, du)
        nx = -nu if mirror else nu
        want = Vector((nx, 0.0, nv)) * (1 if outward else -1)
        if f.normal.dot(want) < 0:
            f.normal_flip()
        faces.append(f)
    return faces


def prism(p, loop, y0, y1, front, side, back=None, mirror=True):
    """A slab cut along ``loop`` (relief coordinates) from y0 (back) to y1
    (front): front cap slot ``front``, walls ``side``, back cap ``back``
    (None = open)."""
    out = cap(p, [loop], y1, front, +1, mirror)
    out += walls(p, loop, y0, y1, side, True, mirror)
    if back is not None:
        out += cap(p, [loop], y0, back, -1, mirror)
    return out


def loft(p, rings, slot, closed_start=True, closed_end=True, smooth=True):
    """Surface through rings of equal vertex count (lists of (x, y, z)),
    quads between consecutive rings; UVs in metres (u around by arc length,
    v along by the mean ring spacing), locked. Ends capped with n-gons."""
    vs = [[p.bm.verts.new(v) for v in ring] for ring in rings]
    n = len(rings[0])
    acc = [0.0]
    for j in range(1, len(rings)):
        d = 0.0
        for k in range(n):
            d += (Vector(rings[j][k]) - Vector(rings[j - 1][k])).length
        acc.append(acc[-1] + d / n)
    faces = []
    for j in range(len(rings) - 1):
        circ = [0.0]
        for k in range(n):
            circ.append(circ[-1] + (Vector(rings[j][(k + 1) % n]) - Vector(rings[j][k])).length)
        for k in range(n):
            k2 = (k + 1) % n
            f = p._face([vs[j][k], vs[j][k2], vs[j + 1][k2], vs[j + 1][k]], slot, smooth)
            uvs = [(circ[k], acc[j]), (circ[k + 1], acc[j]), (circ[k + 1], acc[j + 1]), (circ[k], acc[j + 1])]
            for loop, uv in zip(f.loops, uvs):
                loop[p.uv].uv = uv
            f[p.lock] = 1
            faces.append(f)
    # orient outward from the axis through the ring centres
    score = 0.0
    for j, f in enumerate(faces):
        f.normal_update()
        ring = rings[j // n]
        c = Vector([sum(v[i] for v in ring) / n for i in range(3)])
        score += f.normal.dot(f.calc_center_median() - c)
    if score < 0:
        for f in faces:
            f.normal_flip()
    if closed_start:
        f = p._face(list(reversed(vs[0])), slot)
        faces.append(f)
    if closed_end:
        f = p._face(vs[-1], slot)
        faces.append(f)
    for f in faces[-2:]:
        f.normal_update()
    return faces


def superellipse(cx, cz, y, w, h, n=12, e=2.6, phase=0.0, axis="y"):
    """A ring (cross-section) of a lofted body: superellipse of half-width w
    (x) and half-height h (z) at position y along the body (axis "y")."""
    out = []
    for k in range(n):
        a = math.tau * k / n + phase
        c, s = math.cos(a), math.sin(a)
        x = w * math.copysign(abs(c) ** (2.0 / e), c)
        z = h * math.copysign(abs(s) ** (2.0 / e), s)
        out.append((cx + x, y, cz + z))
    return out
