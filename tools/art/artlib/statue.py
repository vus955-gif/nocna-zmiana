"""Marble figures in the round from metaball clay: a body from joint
positions (3D, Blender axes, z up), drapery as folds and sheets of clay,
cuts for broken heads and limbs (the fractures get their own material
slot), decimation to a budget. Used by the pediment sculptures, the
Nereids, the plaster casts, the hoplite and the centaur."""
import math

import bmesh
import bpy
from mathutils import Vector

from . import sculpt
from .sculpt import blob, limb

V = Vector


def mid(a, b, t=0.5):
    a, b = V(a), V(b)
    return a + (b - a) * t


def body(j, muscle=1.0, female=False, head=True, scale=1.0, neck=True):
    """Clay of a human body from joints: pelvis, chest (centre of the rib
    cage), neck (base), head (centre), sh_l/sh_r, el_*, wr_*, hand_*,
    hip_*, kn_*, an_*, toe_*. Radii are for a 1.8 m figure x ``scale``."""
    s = scale
    b = []
    P, C = V(j["pelvis"]), V(j["chest"])
    up = (C - P).normalized()
    side = (V(j["sh_r"]) - V(j["sh_l"])).normalized()
    fwd = up.cross(side).normalized()           # the body's front
    rot_trunk = tuple(math.degrees(x) for x in (C - P).to_track_quat('Z', 'X').to_euler('XYZ'))
    # rib cage, abdomen, pelvis, buttocks
    b.append(blob(tuple(C), (0.165 * s * (0.92 if female else 1.0), 0.12 * s, 0.17 * s), rot=rot_trunk))
    b.append(blob(mid(P, C, 0.45), (0.13 * s, 0.1 * s, 0.13 * s), rot=rot_trunk))
    b.append(blob(tuple(P), (0.16 * s * (1.1 if female else 1.0), 0.11 * s, 0.11 * s), rot=rot_trunk))
    b.append(blob(tuple(P - fwd * 0.06 * s - up * 0.03 * s), (0.15 * s, 0.09 * s, 0.1 * s), rot=rot_trunk))
    if muscle > 0 and not female:
        for sx in (-1, 1):                      # pectorals
            b.append(blob(tuple(C + fwd * 0.07 * s + side * sx * 0.075 * s + up * 0.04 * s),
                          (0.075 * s, 0.035 * s, 0.055 * s), rot=rot_trunk))
        b.append(blob(tuple(mid(P, C, 0.55) + fwd * 0.06 * s), (0.07 * s, 0.03 * s, 0.1 * s), rot=rot_trunk,
                      stiff=1.6))                 # abdominal plate
        b.append(blob(tuple(P + fwd * 0.05 * s + up * 0.08 * s), (0.11 * s, 0.03 * s, 0.03 * s), neg=True,
                      stiff=1.2, rot=rot_trunk))   # the iliac crease
    if female:
        for sx in (-1, 1):
            b.append(blob(tuple(C + fwd * 0.08 * s + side * sx * 0.07 * s), (0.06 * s, 0.05 * s, 0.055 * s)))
    # shoulders
    for side_k in ("l", "r"):
        b.append(blob(j["sh_" + side_k], 0.075 * s))
    if neck:
        b += limb([j["neck"], j["head"]] if head else [j["neck"], mid(j["neck"], j["head"], 0.6)],
                  [0.06 * s, 0.055 * s])
    if head:
        h = V(j["head"])
        b.append(blob(tuple(h), (0.09 * s, 0.1 * s, 0.11 * s)))
        b.append(blob(tuple(h + fwd * 0.05 * s - up * 0.04 * s), (0.065 * s, 0.06 * s, 0.07 * s)))
    # limbs
    for k in ("l", "r"):
        b += limb([j["sh_" + k], j["el_" + k], j["wr_" + k]], [0.055 * s, 0.045 * s, 0.035 * s])
        if "hand_" + k in j:
            b.append(blob(j["hand_" + k], (0.04 * s, 0.05 * s, 0.03 * s)))
        b += limb([j["hip_" + k], j["kn_" + k], j["an_" + k]], [0.09 * s, 0.06 * s, 0.045 * s])
        b.append(blob(j["kn_" + k], 0.058 * s))
        if "toe_" + k in j:
            b += limb([j["an_" + k], j["toe_" + k]], [0.042 * s, 0.032 * s])
    return b


def fold(a, b, r, n=None, stiff=2.0, flat=1.0, neg=False):
    """A ridge of cloth from a to b (a fold): flattened ellipsoids along the line."""
    a, bb = V(a), V(b)
    d = bb - a
    L = d.length
    n = n or max(2, int(L / (r * 1.2)))
    rot = tuple(math.degrees(x) for x in d.normalized().to_track_quat('Z', 'Y').to_euler('XYZ'))
    out = []
    for i in range(n + 1):
        t = i / n
        out.append(blob(tuple(a + d * t), (r, r * flat, r * 1.4), rot=rot, stiff=stiff, neg=neg))
    return out


def sheet(points, thick, width, stiff=1.8, normal=(0, -1, 0)):
    """A sheet of cloth along a polyline: wide flat ellipsoids (a mantle,
    a skirt panel), ``width`` across, ``thick`` through."""
    out = []
    pts = [V(p) for p in points]
    nrm = V(normal).normalized()
    for i in range(len(pts) - 1):
        a, b = pts[i], pts[i + 1]
        d = b - a
        L = d.length
        steps = max(1, int(L / (width * 0.6)))
        dn = d.normalized()
        nrm = (nrm - dn * nrm.dot(dn)).normalized()
        side = dn.cross(nrm).normalized()
        m = [[side.x, nrm.x, d.normalized().x], [side.y, nrm.y, d.normalized().y],
             [side.z, nrm.z, d.normalized().z]]
        from mathutils import Matrix
        rot = tuple(math.degrees(x) for x in Matrix(m).to_euler('XYZ'))
        for k in range(steps + 1):
            c = a + d * (k / steps)
            out.append(blob(tuple(c), (width * 0.5, thick, max(L / steps, thick) * 0.8), rot=rot, stiff=stiff))
    return out


def cut_local(me, cuts, radius=0.35):
    """Like sculpt.cut, but each plane only cuts the clay within ``radius``
    of its point (several figures in one clay: a broken arm must not slice
    a neighbour). cuts = [(point, normal) or (point, normal, radius)]."""
    bm = bmesh.new()
    bm.from_mesh(me)
    for c in cuts:
        co, no = V(c[0]), V(c[1]).normalized()
        r = c[2] if len(c) > 2 else radius
        verts = {v for v in bm.verts if (v.co - co).length < r}
        faces = [f for f in bm.faces if all(v in verts for v in f.verts)]
        edges = list({e for f in faces for e in f.edges})
        if not faces:
            continue
        bmesh.ops.bisect_plane(bm, geom=list(verts) + edges + faces, plane_co=co, plane_no=no, clear_outer=True)
    edges = [e for e in bm.edges if e.is_boundary]
    bmesh.ops.holes_fill(bm, edges=edges, sides=0)
    bm.to_mesh(me)
    bm.free()
    return me


def sculpt_into(part, blobs, slot, res=0.012, cuts=(), tris=6000, break_slot=None, smooth=True, transform=None):
    """Polygonises ``blobs``, cuts it with planes [(point, normal), ...]
    (the caps become ``break_slot`` faces: fresh fractures), decimates it to
    ``tris`` and appends it to ``part``."""
    me = sculpt.metaball_mesh(blobs, resolution=res)
    if cuts:
        cut_local(me, cuts)
    me2 = sculpt.decimate(me, tris)
    bpy.data.meshes.remove(me)
    n0 = len(part.bm.faces)
    sculpt.into_part(part, me2, slot, smooth=smooth, transform=transform)
    bpy.data.meshes.remove(me2)
    part.bm.faces.ensure_lookup_table()
    new = [part.bm.faces[k] for k in range(n0, len(part.bm.faces))]
    if break_slot and cuts:
        idx = part.slot(break_slot)
        for f in new:
            f.normal_update()
            c = f.calc_center_median()
            for cut in cuts:
                co, no = V(cut[0]), V(cut[1]).normalized()
                if transform is not None:
                    co = transform @ co
                    no = (transform.to_3x3() @ no).normalized()
                if abs((c - co).dot(no)) < 0.012 and f.normal.dot(no) > 0.8:
                    f.material_index = idx
                    f.smooth = False
                    break
    return new
