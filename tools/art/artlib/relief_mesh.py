"""High relief as real geometry: a relief.Relief height field turned into a
displaced grid, decimated to a budget, with front-projected metre UVs (one
atlas island for the whole carved face). The normal map then only needs
the fine detail (maps["detail"]). Needs Blender (bpy)."""
import bmesh
import bpy
import numpy as np

from . import sculpt


def relief_mesh(part, maps, x0, z0, y_face, slot, step=2, target_tris=4000, depth_sign=-1.0, field="smooth",
                facing=-1.0):
    """Adds the carved face to ``part``: the relief rectangle (relief metres
    0..w x 0..h) placed with its bottom-left corner at (x0, z0) in the plane
    y = y_face, raised toward the viewer (``depth_sign`` -1: toward -Y).
    ``facing`` -1: the viewer is at -Y and sees x increasing to the right."""
    h = maps[field]
    H, W = h.shape
    ppm = maps["ppm"]
    rows = list(range(0, H, step)) + ([H - 1] if (H - 1) % step else [])
    cols = list(range(0, W, step)) + ([W - 1] if (W - 1) % step else [])
    me = bpy.data.meshes.new("_relief")
    verts = []
    for r in rows:
        for c in cols:
            u = (c + 0.5) / ppm if 0 < c < W - 1 else (0.0 if c == 0 else maps["w"])
            v = maps["h"] - ((r + 0.5) / ppm if 0 < r < H - 1 else (0.0 if r == 0 else maps["h"]))
            hh = float(h[r, c]) if 0 < r < H - 1 and 0 < c < W - 1 else 0.0
            x = x0 + (u if facing < 0 else -u)
            verts.append((x, y_face + depth_sign * hh, z0 + v))
    nc = len(cols)
    faces = []
    for i in range(len(rows) - 1):
        for j in range(nc - 1):
            a = i * nc + j
            faces.append((a, a + 1, a + nc + 1, a + nc))
    me.from_pydata(verts, [], faces)
    me.update()
    out = sculpt.decimate(me, target_tris)
    bpy.data.meshes.remove(me)
    n0 = len(part.bm.faces)
    sculpt.into_part(part, out, slot, smooth=True)
    bpy.data.meshes.remove(out)
    part.bm.faces.ensure_lookup_table()
    for k in range(n0, len(part.bm.faces)):
        f = part.bm.faces[k]
        f.normal_update()
        if f.normal.y * depth_sign < 0 and abs(f.normal.y) > 0.2:
            pass
        for loop in f.loops:
            co = loop.vert.co
            loop[part.uv].uv = ((co.x - x0) * (-facing), co.z - z0)
        f[part.lock] = 1
    # every face must look at the viewer side
    for k in range(n0, len(part.bm.faces)):
        f = part.bm.faces[k]
        f.normal_update()
    _orient(part.bm, [part.bm.faces[k] for k in range(n0, len(part.bm.faces))], depth_sign)
    return part


def _orient(bm, faces, sign):
    score = sum(f.normal.y * f.calc_area() for f in faces)
    if score * sign < 0:
        for f in faces:
            f.normal_flip()
