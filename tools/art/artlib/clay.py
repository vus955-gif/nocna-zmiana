"""Metaball clay with true rounded boxes (the Americas wing's sculpts).

sculpt.metaball_mesh treats every element by its visible semi-axes, which
suits balls and ellipsoids; Blender's CUBE element instead grows its
rounding radius *around* a core box, so a box needs its own rule. Here a
``box(co, half, round_r)`` element is a CUBE whose core is ``half - round``
and whose surface lies ``round`` outside it: a crisp-ish block with rounded
edges (carved stone, mosaic-covered jaws). Other blobs pass through as in
sculpt.metaball_mesh.
"""
import math

import bpy
from mathutils import Euler

from .sculpt import _SURFACE


def box(co, half, round_r=0.03, rot=(0.0, 0.0, 0.0), neg=False, stiff=2.0):
    return {"co": co, "half": half, "round": round_r, "kind": "BOX", "rot": rot, "neg": neg, "stiff": stiff}


def clay_mesh(blobs, resolution=0.01, threshold=0.6, name="clay"):
    mb = bpy.data.metaballs.new(name)
    mb.resolution = resolution
    mb.render_resolution = resolution
    mb.threshold = threshold
    obj = bpy.data.objects.new(name, mb)
    bpy.context.scene.collection.objects.link(obj)
    for b in blobs:
        if b["kind"] == "BOX":
            el = mb.elements.new(type="CUBE")
            r = b["round"]
            el.radius = r / _SURFACE
            el.size_x = max(1e-3, b["half"][0] - r)
            el.size_y = max(1e-3, b["half"][1] - r)
            el.size_z = max(1e-3, b["half"][2] - r)
        else:
            el = mb.elements.new(type=b["kind"])
            big = max(b["semi"])
            el.radius = big / _SURFACE
            if b["kind"] in ("ELLIPSOID", "CAPSULE", "PLANE"):
                el.size_x = b["semi"][0] / big
                el.size_y = b["semi"][1] / big
                el.size_z = b["semi"][2] / big
        el.co = b["co"]
        el.stiffness = b["stiff"]
        el.use_negative = b["neg"]
        el.rotation = Euler([math.radians(a) for a in b["rot"]]).to_quaternion()
    bpy.context.view_layer.update()
    dg = bpy.context.evaluated_depsgraph_get()
    me = bpy.data.meshes.new_from_object(obj.evaluated_get(dg))
    bpy.data.objects.remove(obj)
    bpy.data.metaballs.remove(mb)
    return me


def into_part(part, me, slot, smooth=True, transform=None):
    """sculpt.into_part, but safe after operators that delete faces (a
    bevelled box): bmesh reuses freed slots, so the new faces are not
    always the last ones - mark them by set difference instead."""
    import bmesh
    tmp = bmesh.new()
    tmp.from_mesh(me)
    if transform is not None:
        bmesh.ops.transform(tmp, matrix=transform, verts=tmp.verts)
    me2 = bpy.data.meshes.new("_tmp")
    tmp.to_mesh(me2)
    tmp.free()
    before = set(part.bm.faces)
    part.bm.from_mesh(me2)
    bpy.data.meshes.remove(me2)
    part.uv = part.bm.loops.layers.uv["UVMap"]
    part.lock = part.bm.faces.layers.int["uvlock"]
    idx = part.slot(slot)
    for f in part.bm.faces:
        if f not in before:
            f.material_index = idx
            f.smooth = smooth
    return part
