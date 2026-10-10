"""Geometry helpers shared by the Asia wing models (tools/art/models/
kit_asia_*.py, the exhibits, the garden): side-profile prisms, bracket arms
with rounded ends (juansha), bearing blocks (dou), outline orientation,
and the culling of faces nobody sees (the back of wall pieces).
"""
import math

import bmesh
from mathutils import Matrix

from .archkit import front_prism


def ccw(pts):
    """The 2D outline counter-clockwise (positive area)."""
    area = sum(pts[i][0] * pts[(i + 1) % len(pts)][1] - pts[(i + 1) % len(pts)][0] * pts[i][1] for i in range(len(pts)))
    return list(pts) if area > 0 else list(reversed(pts))


def side_prism(p, outline_yz, thick, mat, x=0.0, bevel=0.0):
    """A block whose side outline is given in (depth out of the wall, i.e.
    toward -y, z) and that is ``thick`` wide in x, centred on ``x``
    (projecting bracket arms, carved brackets, beam heads)."""
    faces = front_prism(p, ccw(outline_yz), thick, mat, bevel=bevel, y_back=thick / 2)
    p.move(faces, Matrix.Translation((x, 0.0, 0.0)) @ Matrix.Rotation(math.radians(-90), 4, 'Z'))
    return faces


def arm_outline(L, h, n=3):
    """A bracket arm (gong) seen from the side, bottom at z = 0: flat top,
    the ends cut down to half height, then rounded under in ``n`` facets."""
    r = min(h * 1.2, L * 0.3)
    e = 0.5 * h
    pts = [(-L / 2, h), (-L / 2, e)]
    for k in range(1, n + 1):
        a = math.pi / 2 * k / n
        pts.append((-L / 2 + r * (1 - math.cos(a)), e - e * math.sin(a)))
    for k in range(n, 0, -1):
        a = math.pi / 2 * k / n
        pts.append((L / 2 - r * (1 - math.cos(a)), e - e * math.sin(a)))
    pts += [(L / 2, e), (L / 2, h)]
    return ccw(pts)


def dou(p, x, y, z0, w, h, mat, d=None):
    """A bearing block: a square top and a waisted, tapering bottom."""
    d = w if d is None else d
    p.box((x, y, z0 + h * 0.75), (w, d, h * 0.5), mat, bevel=0.008)
    f = p.box((x, y, z0 + h * 0.25), (w, d, h * 0.5), mat, bevel=0.0)
    for v in {v for fc in f for v in fc.verts}:
        if v.co.z < z0 + h * 0.25:
            v.co.x = x + (v.co.x - x) * 0.72
            v.co.y = y + (v.co.y - y) * 0.72


def cull_back(parts, eps=0.012):
    """Deletes faces lying on the wall plane (y > -eps) and facing the wall
    (+y) in pieces modelled before the kit turn: they are never seen and
    waste atlas space."""
    for part in parts:
        bm = part.bm
        bm.normal_update()
        drop = [f for f in bm.faces if f.normal.y > 0.9 and min(v.co.y for v in f.verts) > -eps]
        if drop:
            bmesh.ops.delete(bm, geom=drop, context='FACES')


def cull_top(parts, z, eps=0.012):
    """Deletes faces lying on the ceiling plane ``z`` and facing up."""
    for part in parts:
        bm = part.bm
        bm.normal_update()
        drop = [f for f in bm.faces if f.normal.z > 0.9 and min(v.co.z for v in f.verts) > z - eps]
        if drop:
            bmesh.ops.delete(bm, geom=drop, context='FACES')
