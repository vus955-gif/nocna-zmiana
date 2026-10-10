"""Organic shapes for busts and figures: metaball 'clay' blobs polygonised by
Blender, cut flat with planes, then decimated to a chunky low-poly budget."""
import math

import bmesh
import bpy
from mathutils import Euler, Vector

# a lone metaball element of radius r and stiffness 2 has its surface at
# about 0.67 r (threshold 0.6); blobs are specified by their visible size
_SURFACE = 0.67


def blob(co, semi, kind="ELLIPSOID", stiff=2.0, neg=False, rot=(0.0, 0.0, 0.0)):
    """co: centre; semi: visible semi-axes (x, y, z) in metres (a float for balls);
    rot: XYZ Euler degrees."""
    if not isinstance(semi, (tuple, list)):
        semi = (semi, semi, semi)
    return {"co": co, "semi": semi, "kind": kind, "stiff": stiff, "neg": neg, "rot": rot}


def metaball_mesh(blobs, resolution=0.006, threshold=0.6, name="clay"):
    mb = bpy.data.metaballs.new(name)
    mb.resolution = resolution
    mb.render_resolution = resolution
    mb.threshold = threshold
    obj = bpy.data.objects.new(name, mb)
    bpy.context.scene.collection.objects.link(obj)
    for b in blobs:
        el = mb.elements.new(type=b["kind"])
        el.co = b["co"]
        big = max(b["semi"])
        el.radius = big / _SURFACE
        if b["kind"] in ("ELLIPSOID", "CAPSULE", "CUBE", "PLANE"):
            el.size_x = b["semi"][0] / big
            el.size_y = b["semi"][1] / big
            el.size_z = b["semi"][2] / big
        el.stiffness = b["stiff"]
        el.use_negative = b["neg"]
        el.rotation = Euler([math.radians(a) for a in b["rot"]]).to_quaternion()
    bpy.context.view_layer.update()
    dg = bpy.context.evaluated_depsgraph_get()
    me = bpy.data.meshes.new_from_object(obj.evaluated_get(dg))
    bpy.data.objects.remove(obj)
    bpy.data.metaballs.remove(mb)
    return me


def cut(me, planes):
    """Removes everything on the positive side of each (point, normal) plane
    and caps the holes with flat faces."""
    bm = bmesh.new()
    bm.from_mesh(me)
    for co, no in planes:
        geom = bm.verts[:] + bm.edges[:] + bm.faces[:]
        bmesh.ops.bisect_plane(bm, geom=geom, plane_co=Vector(co), plane_no=Vector(no), clear_outer=True)
    edges = [e for e in bm.edges if e.is_boundary]
    bmesh.ops.holes_fill(bm, edges=edges, sides=0)
    bm.to_mesh(me)
    bm.free()
    return me


def decimate(me, target_tris):
    """Collapse-decimates a mesh to about ``target_tris`` triangles."""
    obj = bpy.data.objects.new("_dec", me)
    bpy.context.scene.collection.objects.link(obj)
    me.calc_loop_triangles()
    tris = max(len(me.loop_triangles), 1)
    mod = obj.modifiers.new("dec", "DECIMATE")
    mod.ratio = min(1.0, target_tris / tris)
    mod.use_collapse_triangulate = True
    bpy.context.view_layer.update()
    dg = bpy.context.evaluated_depsgraph_get()
    out = bpy.data.meshes.new_from_object(obj.evaluated_get(dg))
    bpy.data.objects.remove(obj)
    return out


def into_part(part, me, slot, smooth=True, transform=None):
    """Appends a mesh to a Part's bmesh with one material slot."""
    tmp = bmesh.new()
    tmp.from_mesh(me)
    if transform is not None:
        bmesh.ops.transform(tmp, matrix=transform, verts=tmp.verts)
    idx = part.slot(slot)
    # copy geometry through a temporary mesh (keeps the Part's layers)
    me2 = bpy.data.meshes.new("_tmp")
    tmp.to_mesh(me2)
    tmp.free()
    n0 = len(part.bm.faces)
    part.bm.from_mesh(me2)
    bpy.data.meshes.remove(me2)
    part.bm.faces.ensure_lookup_table()
    part.uv = part.bm.loops.layers.uv["UVMap"]
    part.lock = part.bm.faces.layers.int["uvlock"]
    for i in range(n0, len(part.bm.faces)):
        f = part.bm.faces[i]
        f.material_index = idx
        f.smooth = smooth
    return part


def limb(points, radii, spacing=0.8, stiff=2.0, squash=1.0):
    """Blobs along a polyline: a tapered limb (legs, tails, necks). points =
    [(x, y, z), ...], radii = one radius per point (linearly tapered between
    them). Ellipsoids sit about ``spacing`` radii apart along the line;
    ``squash`` flattens them sideways (x of the local frame)."""
    out = []
    for i in range(len(points) - 1):
        a, b = Vector(points[i]), Vector(points[i + 1])
        r0, r1 = radii[i], radii[i + 1]
        d = b - a
        length = d.length
        if length < 1e-6:
            continue
        rot = tuple(math.degrees(x) for x in d.normalized().to_track_quat('Z', 'Y').to_euler('XYZ'))
        n = max(1, int(math.ceil(length / (min(r0, r1) * spacing))))
        last = i == len(points) - 2
        for k in range(n + (1 if last else 0)):
            t = k / n
            r = r0 + (r1 - r0) * t
            c = a + d * t
            out.append(blob(tuple(c), (r * squash, r, r * 1.25), stiff=stiff, rot=rot))
    return out
