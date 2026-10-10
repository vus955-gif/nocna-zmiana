"""Gypsum chips: debris of the relief enemies and of an awakening slab
(eight pieces 3-14 cm, each its own part with its origin at its centre, to
throw as physical debris). Fresh crystalline breaks, one weathered carved
face on the bigger ones."""
import numpy as np
import bmesh
from mathutils import Vector

from artlib import asy
from artlib.geo import Part
from artlib.model import Model


def chip(name, size, seed, at):
    rng = np.random.default_rng(seed)
    p = Part(name, origin=at)
    pts = []
    for k in range(9):
        v = rng.normal(size=3)
        v /= np.linalg.norm(v)
        v *= np.array([1.0, 0.75, 0.55]) * size * (0.7 + 0.3 * rng.random())
        pts.append(p.bm.verts.new(Vector(at) + Vector(v)))
    res = bmesh.ops.convex_hull(p.bm, input=pts)
    faces = [f for f in res["geom"] if isinstance(f, bmesh.types.BMFace)]
    bmesh.ops.delete(p.bm, geom=[v for v in res.get("geom_interior", []) if isinstance(v, bmesh.types.BMVert)],
                     context='VERTS')
    top = max(faces, key=lambda f: f.calc_area() * (f.normal.z + 1.2))
    for f in faces:
        f.material_index = p.slot("face" if (f is top and size > 0.06) else "break")
        f.smooth = False
    return p


def build():
    parts = []
    sizes = [0.14, 0.11, 0.09, 0.08, 0.06, 0.05, 0.04, 0.03]
    for k, sz in enumerate(sizes):
        parts.append(chip("chip_%d" % (k + 1), sz, 1500 + k, ((k % 4) * 0.3 - 0.45, (k // 4) * 0.3, sz)))
    fns = {"break": lambda c: asy.gypsum_break(c, seed=517), "face": lambda c: asy.alabaster(c, center=8.4)}
    return Model("asy_gypsum_chips", parts, fns, ppm=256, ground=0.0, ao_rays=6, ao_dist=0.05, front=1)
