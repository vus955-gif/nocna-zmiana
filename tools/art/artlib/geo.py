"""Chunky procedural modelling on top of bmesh, with texel-density UVs.

A `Part` wraps one bmesh (one exported mesh object). Builder methods add
geometry and return the new faces. UVs are kept in METRES while modelling
(box projection for hard surfaces, unrolled strips for lathes/profiles/tubes);
bake.py later packs every island into an atlas at a fixed pixels-per-metre, so
texel density is identical on every surface of a model.

Blender axes: Z up. Props face -Y (Godot +Z); the wax figure faces +Y (Godot -Z,
the enemy forward direction).
"""
import math

import bmesh
from mathutils import Matrix, Vector

TAU = math.tau


class Part:
    def __init__(self, name, origin=(0.0, 0.0, 0.0), parent=None):
        self.name = name
        self.origin = Vector(origin)       # object origin (pivot) in model space
        self.parent = parent               # name of the parent part (joint chains) or None
        self.bm = bmesh.new()
        self.uv = self.bm.loops.layers.uv.new("UVMap")
        self.lock = self.bm.faces.layers.int.new("uvlock")
        self.bm.faces.layers.int.new("longu")   # set by the packer (grain direction)
        self.slots = []                     # material names, index = material_index
        self.smooth_angle = math.radians(38.0)

    # --- bookkeeping -----------------------------------------------------
    def slot(self, mat):
        if mat not in self.slots:
            self.slots.append(mat)
        return self.slots.index(mat)

    def _face(self, verts, mat, smooth=False):
        f = self.bm.faces.new(verts)
        f.material_index = self.slot(mat)
        f.smooth = smooth
        return f

    def move(self, faces, matrix):
        verts = {v for f in faces for v in f.verts}
        bmesh.ops.transform(self.bm, matrix=matrix, verts=list(verts))
        return faces

    # --- primitives --------------------------------------------------------
    def box(self, center, size, mat, bevel=0.0, rot=None):
        """Axis-aligned box (optionally rotated about its centre) with a chunky
        one-segment chamfer of ``bevel`` metres on every edge."""
        cx, cy, cz = center
        before = set(self.bm.faces)
        res = bmesh.ops.create_cube(self.bm, size=1.0)
        verts = res["verts"]
        bmesh.ops.scale(self.bm, vec=Vector(tuple(size)), verts=verts)
        if bevel > 0.0:
            # a set iterates in memory-address order: sort, or the bevel (and
            # everything baked from it) changes from run to run
            self.bm.edges.index_update()
            edges = sorted({e for v in verts for e in v.link_edges}, key=lambda e: e.index)
            bmesh.ops.bevel(self.bm, geom=edges + list(verts), offset=bevel, offset_type='OFFSET',
                            segments=1, profile=0.5, affect='EDGES', clamp_overlap=True)
        faces = [f for f in self.bm.faces if f not in before]
        idx = self.slot(mat)
        for f in faces:
            f.material_index = idx
            f.smooth = False
        m = Matrix.Translation(Vector((cx, cy, cz)))
        if rot is not None:
            m = m @ rot.to_4x4()
        self.move(faces, m)
        return faces

    def poly(self, points, mat, smooth=False):
        verts = [self.bm.verts.new(Vector(p)) for p in points]
        return [self._face(verts, mat, smooth)]

    def lathe(self, profile, mat, segments=12, center=(0.0, 0.0, 0.0), cap_bottom=True, cap_top=True,
              smooth=True, phase=0.0, ring_scale=None, squash=(1.0, 1.0)):
        """Surface of revolution around Z. profile = [(radius, z), ...] bottom -> top.
        ``ring_scale(i, j)`` optionally scales the radius of vertex i on ring j
        (flutes); ``squash`` scales x/y (oval sections).
        UVs: u = arc length around (per ring), v = length along the profile."""
        cx, cy, cz = center
        rings = []
        for j, (r, z) in enumerate(profile):
            if r < 1e-6:
                apex = self.bm.verts.new((cx, cy, cz + z))
                rings.append([apex] * segments)
                continue
            ring = []
            for i in range(segments):
                a = phase + TAU * i / segments
                rr = r * (ring_scale(i, j) if ring_scale else 1.0)
                ring.append(self.bm.verts.new((cx + rr * math.cos(a) * squash[0], cy + rr * math.sin(a) * squash[1], cz + z)))
            rings.append(ring)
        # cumulative profile length
        acc = [0.0]
        for i in range(1, len(profile)):
            dr = profile[i][0] - profile[i - 1][0]
            dz = profile[i][1] - profile[i - 1][1]
            acc.append(acc[-1] + math.hypot(dr, dz))
        faces = []
        for j in range(len(profile) - 1):
            r0, r1 = profile[j][0], profile[j + 1][0]
            if r0 < 1e-6 and r1 < 1e-6:
                continue
            # the unrolled strip uses the mean circumference so u stays continuous
            rm = (r0 + r1) * 0.5
            for i in range(segments):
                i2 = (i + 1) % segments
                u0 = TAU * rm * i / segments
                u1 = TAU * rm * (i + 1) / segments
                if r0 < 1e-6:
                    corners = [(rings[j][i], ((u0 + u1) * 0.5, acc[j])),
                               (rings[j + 1][i2], (u1, acc[j + 1])), (rings[j + 1][i], (u0, acc[j + 1]))]
                elif r1 < 1e-6:
                    corners = [(rings[j][i], (u0, acc[j])), (rings[j][i2], (u1, acc[j])),
                               (rings[j + 1][i], ((u0 + u1) * 0.5, acc[j + 1]))]
                else:
                    corners = [(rings[j][i], (u0, acc[j])), (rings[j][i2], (u1, acc[j])),
                               (rings[j + 1][i2], (u1, acc[j + 1])), (rings[j + 1][i], (u0, acc[j + 1]))]
                f = self._face([c[0] for c in corners], mat, smooth)
                faces.append(f)
                for loop, (_, uv) in zip(f.loops, corners):
                    loop[self.uv].uv = uv
                f[self.lock] = 1
        # a profile traced downwards winds the faces inwards: flip them out
        side = 0.0
        for f in faces:
            f.normal_update()
            c = f.calc_center_median()
            side += f.normal.x * (c.x - cx) + f.normal.y * (c.y - cy)
        if side < 0.0:
            for f in faces:
                f.normal_flip()
        down = profile[-1][1] < profile[0][1]
        if cap_bottom and profile[0][0] > 1e-6:
            f = self._face(list(reversed(rings[0])) if not down else rings[0], mat, False)
            faces.append(f)
        if cap_top and profile[-1][0] > 1e-6:
            f = self._face(rings[-1] if not down else list(reversed(rings[-1])), mat, False)
            faces.append(f)
        return faces

    def extrude(self, profile, x0, x1, mat, caps=True, smooth=False):
        """Moulding along X: profile = [(y, z), ...] (y = depth, negative toward
        the viewer at -Y). UVs: u = x, v = length along the profile."""
        a = [self.bm.verts.new((x0, y, z)) for y, z in profile]
        b = [self.bm.verts.new((x1, y, z)) for y, z in profile]
        acc = [0.0]
        for i in range(1, len(profile)):
            acc.append(acc[-1] + math.hypot(profile[i][0] - profile[i - 1][0], profile[i][1] - profile[i - 1][1]))
        faces = []
        for i in range(len(profile) - 1):
            f = self._face([a[i], a[i + 1], b[i + 1], b[i]], mat, smooth)
            uvs = {a[i]: (x0, acc[i]), a[i + 1]: (x0, acc[i + 1]), b[i + 1]: (x1, acc[i + 1]), b[i]: (x1, acc[i])}
            for loop in f.loops:
                loop[self.uv].uv = uvs[loop.vert]
            f[self.lock] = 1
            faces.append(f)
        # make the outside face the viewer (-Y); flip if the winding came out inward
        test = faces[len(faces) // 2]
        test.normal_update()
        if test.normal.y > 0.01 or (abs(test.normal.y) <= 0.01 and test.normal.z < -0.01):
            for f in faces:
                f.normal_flip()
        if caps and len(profile) > 2:
            faces.append(self._face(list(reversed(a)), mat, False))
            faces.append(self._face(b, mat, False))
            for f in faces[-2:]:
                f.normal_update()
                if (f.normal.x > 0) == (f is faces[-2]):
                    f.normal_flip()
        return faces

    def sweep(self, profile, path, mat, smooth=False, y0=0.0, closed=False, uv_break=1.2):
        """Moulding swept along a path in the wall plane (x right, z up, wall at
        y = y0, viewer at -Y). profile = [(depth toward viewer, offset along the
        path's left normal), ...]; for a clockwise path around an opening the
        left normal points away from the opening. UVs: u = path length, v =
        profile length. Corners are mitred; ``closed`` joins the last point
        back to the first."""
        pts = [Vector((p[0], p[1])) for p in path]
        n = len(pts)
        normals = []
        for i in range(n):
            if not closed and i == 0:
                t = (pts[1] - pts[0]).normalized()
                scale = 1.0
            elif not closed and i == n - 1:
                t = (pts[-1] - pts[-2]).normalized()
                scale = 1.0
            else:
                t0 = (pts[i] - pts[i - 1]).normalized()
                t1 = (pts[(i + 1) % n] - pts[i]).normalized()
                t = (t0 + t1).normalized()
                scale = 1.0 / max(0.3, t0.dot(t))
            normals.append(Vector((-t.y, t.x)) * scale)
        if closed:
            pts.append(pts[0])
            normals.append(normals[0])
            n += 1
        grid = []
        for i in range(n):
            if closed and i == n - 1:
                grid.append(grid[0])
                continue
            row = []
            for d, o in profile:
                q = pts[i] + normals[i] * o
                row.append(self.bm.verts.new((q.x, y0 - d, q.y)))
            grid.append(row)
        along = [0.0]
        for i in range(1, n):
            along.append(along[-1] + (pts[i] - pts[i - 1]).length)
        across = [0.0]
        for j in range(1, len(profile)):
            across.append(across[-1] + math.hypot(profile[j][0] - profile[j - 1][0], profile[j][1] - profile[j - 1][1]))
        faces = []
        for i in range(n - 1):
            # restart u every ~uv_break metres so long mouldings pack into
            # short atlas islands
            base = math.floor(along[i] / uv_break + 1e-6) * uv_break
            a0, a1 = along[i] - base, along[i + 1] - base
            for j in range(len(profile) - 1):
                vs = [grid[i][j], grid[i + 1][j], grid[i + 1][j + 1], grid[i][j + 1]]
                uvs = [(a0, across[j]), (a1, across[j]), (a1, across[j + 1]), (a0, across[j + 1])]
                f = self._face(vs, mat, smooth)
                for loop, uv in zip(f.loops, uvs):
                    loop[self.uv].uv = uv
                f[self.lock] = 1
                faces.append(f)
        # orient: the face with the largest depth should look at the viewer
        probe = max(range(len(profile) - 1), key=lambda j: profile[j][0] + profile[j + 1][0])
        f = faces[probe]
        f.normal_update()
        if f.normal.y > 0.0:
            for f in faces:
                f.normal_flip()
        return faces

    def tube(self, points, radius, mat, sides=8, smooth=True, caps=True):
        """Tube along a polyline (ropes, rails). UVs: u around, v along."""
        pts = [Vector(p) for p in points]
        rings = []
        prev_n = None
        for i, p in enumerate(pts):
            if i == 0:
                t = (pts[1] - pts[0]).normalized()
            elif i == len(pts) - 1:
                t = (pts[-1] - pts[-2]).normalized()
            else:
                t = ((pts[i + 1] - pts[i]).normalized() + (pts[i] - pts[i - 1]).normalized()).normalized()
            ref = Vector((0, 0, 1)) if abs(t.z) < 0.9 else Vector((1, 0, 0))
            n = prev_n if prev_n is not None else t.cross(ref).normalized()
            n = (n - t * n.dot(t)).normalized()
            prev_n = n
            b = t.cross(n)
            r = radius(i / (len(pts) - 1)) if callable(radius) else radius
            rings.append([self.bm.verts.new(p + (n * math.cos(TAU * k / sides) + b * math.sin(TAU * k / sides)) * r)
                          for k in range(sides)])
        acc = [0.0]
        for i in range(1, len(pts)):
            acc.append(acc[-1] + (pts[i] - pts[i - 1]).length)
        circ = TAU * (radius(0.5) if callable(radius) else radius)
        faces = []
        for j in range(len(pts) - 1):
            for k in range(sides):
                k2 = (k + 1) % sides
                vs = [rings[j][k], rings[j][k2], rings[j + 1][k2], rings[j + 1][k]]
                f = self._face(vs, mat, smooth)
                uvs = [(circ * k / sides, acc[j]), (circ * (k + 1) / sides, acc[j]),
                       (circ * (k + 1) / sides, acc[j + 1]), (circ * k / sides, acc[j + 1])]
                for loop, uv in zip(f.loops, uvs):
                    loop[self.uv].uv = uv
                f[self.lock] = 1
                faces.append(f)
        if caps:
            faces.append(self._face(list(reversed(rings[0])), mat))
            faces.append(self._face(rings[-1], mat))
        return faces

    def ngon_prism(self, points2d, z0, z1, mat, bevel=0.0):
        """Vertical prism from a 2D outline (x, y), counter-clockwise from above."""
        before = set(self.bm.faces)
        bot = [self.bm.verts.new((x, y, z0)) for x, y in points2d]
        top = [self.bm.verts.new((x, y, z1)) for x, y in points2d]
        faces = [self._face(list(reversed(bot)), mat), self._face(top, mat)]
        n = len(points2d)
        for i in range(n):
            i2 = (i + 1) % n
            faces.append(self._face([bot[i], bot[i2], top[i2], top[i]], mat))
        if bevel > 0.0:
            self.bm.edges.index_update()
            self.bm.verts.index_update()
            edges = sorted({e for f in faces for e in f.edges}, key=lambda e: e.index)
            verts = sorted({v for f in faces for v in f.verts}, key=lambda v: v.index)
            bmesh.ops.bevel(self.bm, geom=edges + verts, offset=bevel, offset_type='OFFSET', segments=1,
                            profile=0.5, affect='EDGES', clamp_overlap=True)
            faces = [f for f in self.bm.faces if f not in before]
            for f in faces:
                f.material_index = self.slot(mat)
                f.smooth = False
        return faces

    # --- finishing ---------------------------------------------------------
    def finalize(self):
        """Box-projects every face that has no UVs yet, marks sharp edges, and
        stores a copy of the metre UVs as 'UVM' (pattern space for painting)."""
        bm = self.bm
        bm.normal_update()
        canonical_order(bm)
        for f in bm.faces:
            if f[self.lock]:
                continue
            box_project(f, self.uv)
        for e in bm.edges:
            if len(e.link_faces) == 2:
                f1, f2 = e.link_faces
                if not (f1.smooth and f2.smooth) or e.calc_face_angle(0.0) > self.smooth_angle:
                    e.smooth = False
        uvm = bm.loops.layers.uv.new("UVM")
        for f in bm.faces:
            for loop in f.loops:
                loop[uvm].uv = loop[self.uv].uv.copy()


def canonical_order(bm):
    """Sorts faces, vertices and edges by geometry. Some bmesh operators
    (solidify, bisect, hole filling) create elements in an order that
    depends on memory addresses, which leaked into atlas packing (ties
    between equal islands), rasterisation and the exported buffers; a
    geometric order makes every build bit-identical again."""
    def r(v, k=5):
        return (round(v.x, k), round(v.y, k), round(v.z, k))

    def by(seq, key):
        # BMElemSeq.sort wants a number: rank the elements by a tuple key first
        rank = {e: i for i, e in enumerate(sorted(seq, key=key))}
        seq.sort(key=lambda e: rank[e])
        seq.index_update()

    by(bm.faces, lambda f: (f.material_index, r(f.calc_center_median()), r(f.normal, 3), len(f.verts)))
    by(bm.verts, lambda v: r(v.co))
    by(bm.edges, lambda e: tuple(sorted((e.verts[0].index, e.verts[1].index))))


def box_project(face, uv_layer):
    """Non-mirrored planar projection along the dominant normal axis (metres)."""
    n = face.normal
    ax, ay, az = abs(n.x), abs(n.y), abs(n.z)
    for loop in face.loops:
        x, y, z = loop.vert.co
        if az >= ax and az >= ay:
            u, v = (x, y) if n.z >= 0 else (-x, y)
        elif ax >= ay:
            u, v = (y, z) if n.x >= 0 else (-y, z)
        else:
            u, v = (-x, z) if n.y >= 0 else (x, z)
        loop[uv_layer].uv = (u, v)


def rot_z(deg):
    return Matrix.Rotation(math.radians(deg), 4, 'Z')


def rot_x(deg):
    return Matrix.Rotation(math.radians(deg), 4, 'X')


def rot_y(deg):
    return Matrix.Rotation(math.radians(deg), 4, 'Y')


def translate(x, y, z):
    return Matrix.Translation(Vector((x, y, z)))
