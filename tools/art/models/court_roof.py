"""Floor I, the Great Court: the triangulated steel-and-glass roof.

  court_roof_q        one quarter of the 60 x 60 m roof: the triangle
                      between the two diagonals round the NORTH side
                      (Godot -Z), from the ring on the Reading Room drum
                      (r = 13.0 m, y = 22.4) to the court's north edge
                      (z = -30, y = 19.0). Origin = the court centre on the
                      floor (0, 0, 0): place four copies at rotation.y =
                      0, 90, 180, 270 degrees. Every diagonal seam belongs
                      to exactly one copy (each carries its north-west one).
                      Parts: court_roof_q (steel: members, node bosses,
                      perimeter girder and drum ring, world-mapped field
                      "tile:court_steel", casts the lattice shadow) and
                      court_roof_q_glass (panes, two-sided, material
                      "glass": no shadow, the moon passes).

The grid follows the British Museum's: lines run from equal angles on the
drum ring to equal steps along the straight edge, so cells are small and
tight by the drum and open out toward the walls; rings are spaced to keep
the cells near square; every cell is split by a diagonal mirrored about the
quarter's centre line (chevrons that meet on the axes and on the seams).
The surface rises like a low dome: steeper at the walls, flattening toward
the drum.
"""
import math

from mathutils import Vector

from artlib.archkit import kit
from artlib.geo import Part

N = 24              # divisions along the quarter (outer edge: 2.5 m)
M = 11              # rings from the drum to the wall
R_IN = 13.0         # the ring on the drum's crown (artlib.court.ROOF_RING)
EDGE = 30.0         # the court's half width
Z_IN = 22.4         # glass level on the drum ring
Z_OUT = 19.0        # glass level on the walls
MEMBER_W, MEMBER_D = 0.16, 0.3
STEEL = "steel"
GLASS = "glass"


def _rho(j):
    """Ring parameter 0 (drum) .. 1 (wall), spaced so cells stay near square
    (the spacing grows with the width of the cells)."""
    w0, w1 = 2.0 * math.pi * R_IN / 4.0 / N, 2.0 * EDGE / N
    t = j / M
    return (math.pow(w1 / w0, t) - 1.0) / (w1 / w0 - 1.0)


def _height(s):
    """Glass level at ring parameter s: a low dome, steeper at the walls."""
    return Z_OUT + (Z_IN - Z_OUT) * (1.0 - s) * (1.0 + 0.6 * s)


def node(i, j):
    """Point on the glass plane (Blender: x east, y north, z up)."""
    u = -1.0 + 2.0 * i / N
    a = math.radians(45.0) * u
    inner = Vector((R_IN * math.sin(a), R_IN * math.cos(a)))
    outer = Vector((EDGE * u, EDGE))
    s = _rho(j)
    p = inner.lerp(outer, s)
    return Vector((p.x, p.y, _height(s)))


def beam(p, a, b, w, d, mat, below=0.0):
    """A member from a to b on the glass plane: rectangular section w wide,
    d deep hanging under the plane (shifted ``below`` further down), the
    depth along the surface normal's vertical part. Open ends (they die
    into the nodes)."""
    ax = (b - a).normalized()
    up = Vector((0.0, 0.0, 1.0))
    n = (up - ax * ax.dot(up)).normalized()
    side = ax.cross(n).normalized() * (w * 0.5)
    top = -n * below
    bot = -n * (below + d)
    corners = []
    for q in (a, b):
        corners.append([q + top - side, q + top + side, q + bot + side, q + bot - side])
    va = [p.bm.verts.new(c) for c in corners[0]]
    vb = [p.bm.verts.new(c) for c in corners[1]]
    faces = []
    for k in range(4):
        k2 = (k + 1) % 4
        f = p._face([va[k], va[k2], vb[k2], vb[k]], mat)
        f.normal_update()
        mid = (corners[0][k] + corners[0][k2]) * 0.5
        centre = (a + b) * 0.5 + n * (-(below + d * 0.5))
        if f.normal.dot(mid - ((corners[0][0] + corners[0][2]) * 0.5)) < 0.0:
            f.normal_flip()
        faces.append(f)
    return faces


def boss(p, c, r, d, mat):
    """Node boss: a square plate (turned 45 degrees) under the node, open on
    top (the glass covers it)."""
    pts_top = [c + Vector((r * math.cos(a), r * math.sin(a), 0.02)) for a in
               (math.radians(45 + 90 * k) for k in range(4))]
    pts_bot = [q - Vector((0.0, 0.0, d)) for q in pts_top]
    vt = [p.bm.verts.new(q) for q in pts_top]
    vb = [p.bm.verts.new(q) for q in pts_bot]
    faces = []
    for k in range(4):
        k2 = (k + 1) % 4
        f = p._face([vt[k], vt[k2], vb[k2], vb[k]], mat)
        f.normal_update()
        out = ((pts_top[k] + pts_top[k2]) * 0.5 - c)
        out.z = 0.0
        if f.normal.dot(out) < 0.0:
            f.normal_flip()
        faces.append(f)
    f = p._face(list(reversed(vb)), mat)
    f.normal_update()
    if f.normal.z > 0.0:
        f.normal_flip()
    faces.append(f)
    return faces


def _quad_box(p, corners_top, depth, mat):
    """A box from a top outline (4 points, any order round) pushed down."""
    vt = [p.bm.verts.new(q) for q in corners_top]
    vb = [p.bm.verts.new(q - Vector((0.0, 0.0, depth))) for q in corners_top]
    c = sum(corners_top, Vector()) / 4.0 - Vector((0.0, 0.0, depth * 0.5))
    faces = []
    for ring in ([vt[0], vt[1], vt[2], vt[3]], [vb[3], vb[2], vb[1], vb[0]]):
        faces.append(p._face(ring, mat))
    for k in range(4):
        k2 = (k + 1) % 4
        faces.append(p._face([vt[k], vb[k], vb[k2], vt[k2]], mat))
    for f in faces:
        f.normal_update()
        if f.normal.dot(f.calc_center_median() - c) < 0.0:
            f.normal_flip()
    return faces


def lattice():
    steel = Part("court_roof_q")
    glass = Part("court_roof_q_glass")
    P = [[node(i, j) for j in range(M + 1)] for i in range(N + 1)]
    # the column of the north-west seam (i = 0) belongs to this copy, the
    # north-east one (i = N) to the next copy round
    for i in range(N):
        for j in range(M):
            heavy = j == 0
            beam(steel, P[i][j], P[i][j + 1], MEMBER_W * (1.3 if i == 0 else 1.0), MEMBER_D, STEEL)
    for i in range(N):
        for j in range(1, M):
            beam(steel, P[i][j], P[i + 1][j], MEMBER_W, MEMBER_D, STEEL)
    # diagonals, mirrored about the centre line
    for i in range(N):
        for j in range(M):
            if i < N // 2:
                a, b = P[i][j], P[i + 1][j + 1]
            else:
                a, b = P[i + 1][j], P[i][j + 1]
            beam(steel, a, b, MEMBER_W * 0.8, MEMBER_D * 0.8, STEEL)
    for i in range(N):
        for j in range(1, M):
            boss(steel, P[i][j], 0.17, MEMBER_D + 0.06, STEEL)
    # the ring on the drum: a heavy curved box girder under the first ring
    for i in range(N):
        beam(steel, P[i][0], P[i + 1][0], 0.5, 0.75, STEEL)
    # the perimeter girder on the wall head (a box 0.7 wide, 0.9 deep) and
    # the glazing bar of the last ring above it
    for i in range(N):
        beam(steel, P[i][M], P[i + 1][M], 0.24, 0.35, STEEL)
    x0, x1 = -EDGE, EDGE
    top = Z_OUT - 0.25
    _quad_box(steel, [Vector((x0, EDGE - 0.35, top)), Vector((x1, EDGE - 0.35, top)),
                      Vector((x1, EDGE + 0.35, top)), Vector((x0, EDGE + 0.35, top))], 0.9, STEEL)
    # glass: one pane per triangle, both faces (seen from the court and from
    # the service walks on the roof); 2 cm above the members
    lift = Vector((0.0, 0.0, 0.02))
    for i in range(N):
        for j in range(M):
            a, b, c, d = P[i][j], P[i + 1][j], P[i + 1][j + 1], P[i][j + 1]
            tris = [(a, b, c), (a, c, d)] if i < N // 2 else [(a, b, d), (b, c, d)]
            for t in tris:
                for up in (True, False):
                    f = glass.poly([q + lift for q in t], GLASS)[0]
                    f.normal_update()
                    if (f.normal.z > 0.0) != up:
                        f.normal_flip()
    return [steel, glass]


def build():
    parts = lattice()
    return kit("court_roof_q", parts, {}, kinds={STEEL: "tile:court_steel", GLASS: "glass"}, built_final=True,
               ground=None, preview_elevation=38.0, preview_yaws=(0.0, 45.0, 160.0, 200.0))
