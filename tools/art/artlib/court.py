"""Shared numbers and helpers of Floor I's Great Court kit (the Reading Room
drum, its interior, the roof ring, the balcony and stairs round it).

Drum pieces have their origin at the drum centre on the floor and are built
round the north axis (Blender +Y = Godot -Z): segment k of 16 is placed by
turning a copy k * 22.5 degrees about the vertical (k = 0 north, 4 west,
8 south, 12 east in Godot's rotation.y sense).

``wedge`` lets a segment be modelled like a flat wall (wall plane y = 0,
decoration toward the viewer at -Y, x from -HALF to HALF) and then maps it
into the 16-gon: x scales with the distance from the centre, so every
moulding meets its neighbour exactly on the radial joint plane (a perfect
mitre) and the wall thickness narrows toward the inner face.
"""
import math

import bmesh
from mathutils import Matrix, Vector

SIDES = 16
ALPHA = math.pi / SIDES                       # half the segment angle (11.25 deg)
R_OUT = 12.5                                  # circumradius of the outer face
A_OUT = R_OUT * math.cos(ALPHA)               # apothem of the outer face (12.26)
HALF = A_OUT * math.tan(ALPHA)                # half width of an outer face (2.44)
A_IN = 11.2                                   # apothem of the inner face
HALF_IN = A_IN * math.tan(ALPHA)              # half width of an inner face (2.23)
THICK = A_OUT - A_IN                          # wall (1.06)

# exterior heights
PLINTH = 0.9
STRING = 6.3                                  # balcony string course 6.3 .. 6.95
BALCONY = 7.0
CAP = 14.3                                    # pilaster capitals 14.3 .. 15.0
ENT = 15.0                                    # entablature 15.0 .. 16.6
ATTIC = 16.6
COPING = 20.9                                 # crowning cornice 20.9 .. TOP
TOP = 21.65                                   # where the roof's drum ring sits
ROOF_RING = 13.0                              # radius of the roof's inner ring

# interior heights
GALLERY = 4.8                                 # gallery walk 4.8 .. 5.0 (over the 4.5 m doors)
SHELF_TOP = 9.4                               # bookcase cornice 9.4 .. 9.8
CORNICE = 9.8                                 # interior cornice 9.8 .. 10.8
SPRING = 10.8                                 # lunette band 10.8 .. 13.2
BAND_A = 10.69                                # apothem of the lunette band
LUNETTE_TOP = 13.2
DOME_BASE_R = 10.9                            # the dome springs from this circle at LUNETTE_TOP
OCULUS_R = 1.8
DOME_R = 12.14                                # sphere of the dome
DOME_ZC = 7.86                                # its centre height (top would be 20.0)
WELL_TOP = 23.6                               # the splayed oculus well ends under the lantern
WELL_TOP_R = 3.0


def dome_point(theta, phi, r=DOME_R):
    """Point on the dome sphere: theta from the north axis (Blender +Y),
    phi from the vertical; r > DOME_R lies further out (a coffer recess)."""
    return Vector((r * math.sin(phi) * math.sin(theta), r * math.sin(phi) * math.cos(theta),
                   DOME_ZC + r * math.cos(phi)))


def wedge(part, apothem=A_OUT, d_of=lambda v: -v.co.y):
    """Maps a flat-built segment into the 16-gon wedge and turns it to face
    north: x *= (A + d) / A, then (x, y) -> (-x, A + d) (a 180 degree turn,
    so lettering still reads from outside)."""
    for v in part.bm.verts:
        d = d_of(v)
        x = v.co.x * (apothem + d) / apothem
        v.co.x = -x
        v.co.y = apothem + d
    part.bm.normal_update()
    # the turn is a rotation (x -> -x, y -> -y) composed with a translation,
    # so face windings stay right
    return part


def wedge_in(part, apothem=A_IN):
    """Interior pieces: modelled flat (wall plane y = 0, decoration toward
    the viewer at -Y = the drum centre), mapped into the wedge without a
    turn: x *= (A + y) / A, y += A (they face south, toward the centre)."""
    for v in part.bm.verts:
        v.co.x = v.co.x * (apothem + v.co.y) / apothem
        v.co.y = apothem + v.co.y
    part.bm.normal_update()
    return part


def drop_end_faces(part, half=HALF, eps=0.004):
    """Deletes faces lying in the segment's end planes (x = +-half, flat
    frame): they are buried in the joint with the neighbouring segment."""
    bm = part.bm
    drop = [f for f in bm.faces
            if all(abs(v.co.x - half) < eps for v in f.verts) or all(abs(v.co.x + half) < eps for v in f.verts)]
    if drop:
        bmesh.ops.delete(bm, geom=drop, context='FACES')


def drop_back_faces(part, y=0.0, eps=0.004):
    """Deletes faces on the wall plane (flat frame y = 0) facing into the
    wall: the backs of boxes standing against it."""
    bm = part.bm
    bm.normal_update()
    drop = [f for f in bm.faces if f.normal.y > 0.9 and all(abs(v.co.y - y) < eps for v in f.verts)]
    if drop:
        bmesh.ops.delete(bm, geom=drop, context='FACES')


def quad(p, pts, mat, want):
    f = p.poly(pts, mat)[0]
    f.normal_update()
    if f.normal.dot(Vector(want)) < 0:
        f.normal_flip()
    return f


def front(p, x0, x1, z0, z1, mat, y=0.0):
    """Rectangle in the wall plane facing the viewer (-Y)."""
    return quad(p, [(x0, y, z0), (x1, y, z0), (x1, y, z1), (x0, y, z1)], mat, (0, -1, 0))


def arch_pts(cx, z_spring, r, n, a0=0.0, a1=math.pi):
    """Points on a semicircular arch (x, z), from the right springing round
    to the left one when a0 = 0, a1 = pi."""
    return [(cx + r * math.cos(a0 + (a1 - a0) * i / n), z_spring + r * math.sin(a0 + (a1 - a0) * i / n))
            for i in range(n + 1)]


def turn_z(deg):
    return Matrix.Rotation(math.radians(deg), 4, 'Z')


def prism_z(p, section, z0, z1, mat, inside=None):
    """Vertical strip of quads along an open plan polyline ``section``
    [(x, y), ...] from z0 to z1, unwrapped as one UV island (u along the
    polyline, v up). ``inside``: a plan point the faces turn away from."""
    acc = [0.0]
    for i in range(1, len(section)):
        acc.append(acc[-1] + math.hypot(section[i][0] - section[i - 1][0], section[i][1] - section[i - 1][1]))
    lo = [p.bm.verts.new((x, y, z0)) for x, y in section]
    hi = [p.bm.verts.new((x, y, z1)) for x, y in section]
    if inside is None:
        inside = (sum(x for x, _ in section) / len(section), sum(y for _, y in section) / len(section))
    faces = []
    for i in range(len(section) - 1):
        f = p._face([lo[i], lo[i + 1], hi[i + 1], hi[i]], mat)
        for loop, uv in zip(f.loops, ((acc[i], z0), (acc[i + 1], z0), (acc[i + 1], z1), (acc[i], z1))):
            loop[p.uv].uv = uv
        f[p.lock] = 1
        f.normal_update()
        c = f.calc_center_median()
        if f.normal.x * (c.x - inside[0]) + f.normal.y * (c.y - inside[1]) < 0:
            f.normal_flip()
        faces.append(f)
    return faces


def rev_strip(p, profile, th0, th1, n, mat, smooth=False, uv_break=2.4):
    """Surface of revolution about the drum axis over theta th0..th1 (from
    the north axis), profile [(r, z), ...]. UVs unrolled in metres (u round,
    restarting every ~uv_break m so islands stay short; v along the
    profile). Callers orient the faces."""
    rows = []
    for r, z in profile:
        rows.append([p.bm.verts.new((r * math.sin(th0 + (th1 - th0) * i / n), r * math.cos(th0 + (th1 - th0) * i / n), z))
                     for i in range(n + 1)])
    acc = [0.0]
    for j in range(1, len(profile)):
        acc.append(acc[-1] + math.hypot(profile[j][0] - profile[j - 1][0], profile[j][1] - profile[j - 1][1]))
    faces = []
    dth = (th1 - th0) / n
    for j in range(len(profile) - 1):
        rm = (profile[j][0] + profile[j + 1][0]) * 0.5
        step = max(1, int(uv_break / max(rm * abs(dth), 1e-6)))
        for i in range(n):
            f = p._face([rows[j][i], rows[j][i + 1], rows[j + 1][i + 1], rows[j + 1][i]], mat, smooth)
            i0 = i - (i // step) * step
            u0, u1 = rm * abs(dth) * i0, rm * abs(dth) * (i0 + 1)
            for loop, uv in zip(f.loops, ((u0, acc[j]), (u1, acc[j]), (u1, acc[j + 1]), (u0, acc[j + 1]))):
                loop[p.uv].uv = uv
            f[p.lock] = 1
            faces.append(f)
    return faces, rows


def orient_section(faces, r0, z0):
    """Turns faces of a revolved closed section away from its centre point
    (r0, z0) in the radial plane."""
    for f in faces:
        f.normal_update()
        c = f.calc_center_median()
        rc = math.hypot(c.x, c.y)
        radial = Vector((c.x / max(rc, 1e-6), c.y / max(rc, 1e-6), 0.0))
        out = radial * (rc - r0) + Vector((0.0, 0.0, c.z - z0))
        if f.normal.dot(out) < 0:
            f.normal_flip()
    return faces
