"""Shared tools for the upgrade parts and mastery finishes of the first-person
fists, taser and pistol (vm_fists, vm_taser, vm_pistol).

The game shows a part named ``upg_*`` once its upgrade level is bought and
swaps the whole model to the ``<model>_master`` texture set when every
upgrade of the weapon is maxed. So one base texture set has to look right
both with and without the upgrade parts:

* ``ao_without`` re-traces ambient occlusion for the texels of a slot near
  parts that may be hidden, ignoring them (no dark "ghost" of a magazine or
  a coil on the bare model). The mastery set keeps the full AO: at mastery
  every upgrade is on.
* ``shell`` copies a region of the glove surface (between cutting planes),
  pushes it out along the normals and gives it a rim down into the glove:
  cloth wrapped tight over the hand, with crisp planar edges.
* ``panel`` extrudes a flat outline into a thin plate with a chamfered face
  (inlays, name plates); ``oval_tube`` sweeps a flattened tube along a path.
* ``scroll`` and ``pinstripe`` paint engraving and coach lines in texels.
"""
import math

import bmesh
import numpy as np
from mathutils import Matrix, Vector

from artlib import bake
from artlib import materials as M
from artlib import sculpt
from artlib.geo import canonical_order
from artlib.painter import Surface


# --------------------------------------------------------------------------
# ambient occlusion without the parts that may be hidden
# --------------------------------------------------------------------------

def ao_without(fn, hidden=("upg_",), rays=12, dist=0.03):
    """Wraps a material function: texels within reach of a mesh whose name
    starts with one of ``hidden`` get their AO traced again without those
    meshes (same rays and reach as the model's bake)."""
    hidden = tuple(hidden)

    def wrapped(ctx):
        _retrace(ctx, hidden, rays, dist)
        return fn(ctx)
    return wrapped


def _retrace(ctx, hidden, rays, dist):
    if ctx.N == 0 or np.all(ctx.ao >= 1.0):
        return                      # --fast (no AO) or nothing occluded at all
    import bpy
    from mathutils.bvhtree import BVHTree
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH" and not o.name.startswith("_")]
    gone = [o for o in meshes if o.name.startswith(hidden)]
    if not gone:
        return
    kept = [o for o in meshes if o not in gone]
    verts, polys = [], []
    for o in gone:
        mw = o.matrix_world
        base = len(verts)
        verts.extend(tuple(mw @ v.co) for v in o.data.vertices)
        polys.extend(tuple(base + i for i in p.vertices) for p in o.data.polygons)
    near = BVHTree.FromPolygons(verts, polys, epsilon=0.0)
    reach = dist + 0.004            # rays start 3 mm off the surface
    sel = np.array([near.find_nearest(Vector(p), reach)[0] is not None for p in ctx.p], dtype=bool)
    if not sel.any():
        return
    ctx.ao = ctx.ao.copy()
    ctx.ao[sel] = bake.ambient_occlusion(kept, ctx.p[sel], ctx.n[sel], rays, dist)


# --------------------------------------------------------------------------
# geometry
# --------------------------------------------------------------------------

def placed(p, matrix, fn, mirror=False):
    """Runs builder ``fn(p)`` and moves only the new faces by ``matrix``;
    ``mirror``: the matrix flips handedness, so the faces are turned back out."""
    before = set(p.bm.faces)
    fn(p)
    new = [f for f in p.bm.faces if f not in before]
    p.move(new, matrix)
    if mirror:
        bmesh.ops.reverse_faces(p.bm, faces=new, flip_multires=False)
    return new


def shell(part, src, slot, planes, offset, lip=0.0007, keep=None, ratio=None):
    """Adds to ``part`` (slot ``slot``) a copy of the ``"glove"`` faces of Part
    ``src`` that lie on the inner side of every cutting plane (point, normal:
    the side the normal points to is cut away), pushed out by ``offset`` along
    the vertex normals, with a rim from the edge back into the surface below.
    ``keep(centre)`` may drop stray faces; ``ratio`` collapse-decimates the
    copied surface first (its flat facets sag less than the offset). The
    faces get no UVs (list the part as organic: Smart UV Project)."""
    bm = src.bm.copy()
    gi = src.slots.index("glove")
    bmesh.ops.delete(bm, geom=[f for f in bm.faces if f.material_index != gi], context="FACES")
    for co, no in planes:
        geom = bm.verts[:] + bm.edges[:] + bm.faces[:]
        bmesh.ops.bisect_plane(bm, geom=geom, plane_co=Vector(co), plane_no=Vector(no), clear_outer=True)
    if keep is not None:
        drop = [f for f in bm.faces if not keep(f.calc_center_median())]
        if drop:
            bmesh.ops.delete(bm, geom=drop, context="FACES")
    loose = [v for v in bm.verts if not v.link_faces]
    if loose:
        bmesh.ops.delete(bm, geom=loose, context="VERTS")
    canonical_order(bm)
    if ratio is not None:
        import bpy
        src_me = bpy.data.meshes.new("_shell_src")
        bm.to_mesh(src_me)
        bm.free()
        src_me.calc_loop_triangles()
        low = sculpt.decimate(src_me, max(8, int(len(src_me.loop_triangles) * ratio)))
        bpy.data.meshes.remove(src_me)
        bm = bmesh.new()
        bm.from_mesh(low)
        bpy.data.meshes.remove(low)
        canonical_order(bm)
    bm.normal_update()
    face_n = [f.normal.copy() for f in bm.faces]
    vn = {v: v.normal.copy() for v in bm.verts}
    edges = [e for e in bm.edges if e.is_boundary]
    ret = bmesh.ops.extrude_edge_only(bm, edges=edges)
    rim = [g for g in ret["geom"] if isinstance(g, bmesh.types.BMVert)]
    # each rim vertex sits on a boundary vertex: find it through the new side edge
    src_of = {}
    for v in rim:
        for e in v.link_edges:
            o = e.other_vert(v)
            if o in vn and (o.co - v.co).length < 1e-9:
                src_of[v] = o
                break
    for v, n in vn.items():
        v.co = v.co + n * offset
    for v in rim:
        o = src_of.get(v)
        if o is not None:
            v.co = v.co - vn[o] * lip
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    bm.normal_update()
    bm.faces.ensure_lookup_table()
    first = [bm.faces[i] for i in range(len(face_n))]
    if sum(f.normal.dot(n) for f, n in zip(first, face_n)) < 0.0:
        bmesh.ops.reverse_faces(bm, faces=bm.faces[:])
    canonical_order(bm)
    import bpy
    me = bpy.data.meshes.new("_shell")
    bm.to_mesh(me)
    bm.free()
    sculpt.into_part(part, me, slot, smooth=True)
    bpy.data.meshes.remove(me)


def _inset(poly, d):
    """Mitred inward offset of a closed 2D polygon (counter-clockwise)."""
    out = []
    n = len(poly)
    for i in range(n):
        a, b, c = Vector(poly[i - 1]), Vector(poly[i]), Vector(poly[(i + 1) % n])
        e0 = (b - a).normalized()
        e1 = (c - b).normalized()
        n0 = Vector((-e0.y, e0.x))
        n1 = Vector((-e1.y, e1.x))
        m = (n0 + n1).normalized()
        out.append(b + m * (d / max(0.3, m.dot(n0))))
    return out


def panel(p, outline, back, front, mat, chamfer=0.0004, side=1):
    """A thin plate on a face that looks along +X (side=1) or -X (side=-1):
    ``outline`` = [(y, z), ...] counter-clockwise seen from +X; the plate
    runs from x = side*back (buried in the surface) to x = side*front, its
    face chamfered by ``chamfer``. Returns the faces (box-projected later)."""
    outer = [Vector(q) for q in outline]
    inner = _inset(outline, chamfer)
    x0, x1, x2 = side * back, side * (front - chamfer), side * front
    rb = [p.bm.verts.new((x0, q.x, q.y)) for q in outer]
    rw = [p.bm.verts.new((x1, q.x, q.y)) for q in outer]
    rf = [p.bm.verts.new((x2, q.x, q.y)) for q in inner]
    faces = [p._face(rb[::-1], mat), p._face(rf, mat)]
    n = len(outer)
    for i in range(n):
        j = (i + 1) % n
        faces.append(p._face([rb[i], rb[j], rw[j], rw[i]], mat))
        faces.append(p._face([rw[i], rw[j], rf[j], rf[i]], mat))
    bmesh.ops.recalc_face_normals(p.bm, faces=faces)
    p.bm.normal_update()
    # recalc picks the outside of the closed plate; make sure the face looks out
    if faces[1].normal.x * side < 0:
        bmesh.ops.reverse_faces(p.bm, faces=faces)
    return faces


def oval_tube(p, points, half_w, half_t, thick_dir, mat, sides=8, caps=True):
    """Tube along a polyline with an oval section: ``half_t`` along the fixed
    direction ``thick_dir`` (perpendicular to the path), ``half_w`` across.
    UVs: u around, v along (locked)."""
    pts = [Vector(q) for q in points]
    td = Vector(thick_dir).normalized()
    rings = []
    for i, q in enumerate(pts):
        if i == 0:
            t = pts[1] - pts[0]
        elif i == len(pts) - 1:
            t = pts[-1] - pts[-2]
        else:
            t = (pts[i + 1] - pts[i]).normalized() + (pts[i] - pts[i - 1]).normalized()
        t.normalize()
        w = t.cross(td).normalized()
        rings.append([p.bm.verts.new(q + td * (half_t * math.cos(math.tau * k / sides))
                                     + w * (half_w * math.sin(math.tau * k / sides))) for k in range(sides)])
    acc = [0.0]
    for i in range(1, len(pts)):
        acc.append(acc[-1] + (pts[i] - pts[i - 1]).length)
    circ = math.pi * (half_w + half_t)
    faces = []
    for j in range(len(pts) - 1):
        for k in range(sides):
            k2 = (k + 1) % sides
            f = p._face([rings[j][k], rings[j][k2], rings[j + 1][k2], rings[j + 1][k]], mat, smooth=True)
            uvs = [(circ * k / sides, acc[j]), (circ * (k + 1) / sides, acc[j]),
                   (circ * (k + 1) / sides, acc[j + 1]), (circ * k / sides, acc[j + 1])]
            for loop, uv in zip(f.loops, uvs):
                loop[p.uv].uv = uv
            f[p.lock] = 1
            faces.append(f)
    if caps:
        faces.append(p._face(list(reversed(rings[0])), mat))
        faces.append(p._face(rings[-1], mat))
    # outward: the first face should look away from the path
    f = faces[0]
    f.normal_update()
    mid = (pts[0] + pts[1]) * 0.5
    if f.normal.dot(f.calc_center_median() - mid) < 0:
        bmesh.ops.reverse_faces(p.bm, faces=faces)
    return faces


def ring(p, center, axis, ref, r_in, r_out, width, mat, segments=10, squash=1.0, chamfer=0.0007):
    """A washer (closed profile lathe) round ``axis``: radius ``r_in`` ->
    ``r_out`` along ``ref``, scaled by ``squash`` across, ``width`` along the
    axis, chamfered outer edges."""
    w, c = width * 0.5, chamfer
    if c > 0.0:
        prof = [(r_in, -w), (r_out - c, -w), (r_out, -w + c), (r_out, w - c), (r_out - c, w), (r_in, w), (r_in, -w)]
    else:
        prof = [(r_in, -w), (r_out, -w), (r_out, w), (r_in, w), (r_in, -w)]
    faces = p.lathe(prof, mat, segments=segments, cap_bottom=False, cap_top=False, smooth=True,
                    squash=(1.0, squash))
    z = Vector(axis).normalized()
    x = Vector(ref)
    x = (x - z * x.dot(z)).normalized()
    y = z.cross(x)
    m = Matrix(((x.x, y.x, z.x, 0), (x.y, y.y, z.y, 0), (x.z, y.z, z.z, 0), (0, 0, 0, 1)))
    p.move(faces, Matrix.Translation(Vector(center)) @ m)
    return faces


# --------------------------------------------------------------------------
# painting
# --------------------------------------------------------------------------

def scroll(u, v, texel, vc, lam=15.0, amp=1.5, rad=2.4, turns=1.2, width=0.55):
    """Running vine scroll (engraving) in texel units along ``u``, centred on
    ``v = vc``: a wavy stem with a curl in the hollow of every bend.
    Returns a bool mask of 1-texel lines."""
    x = u / texel
    y = (v - vc) / texel
    ph = math.tau * x / lam
    slope = amp * math.tau / lam * np.cos(ph)
    stem = np.abs(y - amp * np.sin(ph)) / np.sqrt(1.0 + slope * slope) < width
    k = np.floor((x - lam / 4.0) / (lam / 2.0) + 0.5)
    xk = lam / 4.0 + k * lam / 2.0
    sk = np.where(np.mod(k, 2.0) == 0.0, 1.0, -1.0)           # +1 under a top crest
    cx, cy = xk + sk * lam * 0.06, -sk * (rad * 0.55)
    dx, dy = x - cx, y - cy
    r = np.hypot(dx, dy)
    th = np.arctan2(dy, dx) * sk
    curl = np.zeros(len(x), dtype=bool)
    for n in range(3):
        phi = np.mod(th + math.pi / 2.0, math.tau) + math.tau * n
        ok = (phi <= math.tau * turns) & (phi > 1.2)
        curl |= ok & (np.abs(r - rad * phi / (math.tau * turns)) < width)
    return stem | curl


def pinstripe(ctx, near=2.0, far=3.0):
    """Coach line ``near``..``far`` texels in from every sharp convex edge."""
    d = ctx.convex / ctx.texel
    return (d >= near) & (d < far)


def merge_ramp(s, ramp, mask, shade, metal=None, rough=None, height=None):
    """Paints ``mask`` with another ramp (and its own metal/rough/height)."""
    if not mask.any():
        return s
    s.use_ramp(ramp, mask=mask, shade=np.broadcast_to(shade, (s.n,)).astype(np.float64))
    if metal is not None:
        s.metal = np.where(mask, metal, s.metal)
    if rough is not None:
        s.rough = np.where(mask, rough, s.rough)
    if height is not None:
        s.height = np.where(mask, s.height + height, s.height)
    return s


def polished_brass(ctx, seed, ramp="brass", center=6.6, engrave=None):
    """Bright polished brass/gold, no tarnish; ``engrave`` = bool mask of cut
    lines (filled dark)."""
    s = Surface(ctx.N)
    along, across = M._grain_frame(ctx)
    q = np.stack([np.sum(ctx.p * along, 1), np.sum(ctx.p * ctx.n, 1), np.sum(ctx.p * across, 1)], axis=1)
    brushed = ctx.fbm(np.array([2.0, 60.0, 60.0]), 2, seed, p=q)
    shade = center + brushed * 0.5 + ctx.fbm(3.0, 3, seed + 1) * 0.5 + M._dither(ctx, 0.5, seed + 2)
    shade += ctx.edge(1.0) * 2.5 + np.clip(ctx.curv, 0, 1) * 1.5
    shade -= ctx.cavity(3.0) * 2.5 + (1.0 - ctx.ao) * 3.5
    s.use_ramp(M.P[ramp], shade=shade)
    s.metal = np.ones(ctx.N)
    s.rough = 0.13 + ctx.rand(seed + 3) * 0.03
    s.height = brushed * 0.0001
    if engrave is not None and engrave.any():
        s.shade[engrave] -= 4.5
        s.rough = np.where(engrave, 0.5, s.rough)
        s.height = s.height - engrave * 0.00025
    return s
