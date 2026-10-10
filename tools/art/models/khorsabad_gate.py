"""Brama Chorsabadu: the Khorsabad Gate on the Assyrian side of the passage
from Egypt (junction j_egypt_assyria: a 6 x 8 m opening). Two lamassu of
Sargon's palace, 4.5 m, flank the passage with their bodies along it, their
faces turned to whoever comes through from Egypt; each has FIVE legs, as
the originals: seen from the front it stands, seen from the passage it
walks. Behind them carved backing blocks with the Standard Inscription
between the legs, towers carried on their crowns, an archivolt of glazed
brick over the inner end, stepped merlons; optional stone seal doors.

Kit frame (one piece, placed like a door frame): origin = the floor centre
of the opening on the Assyrian face of the wall, the gate stands in the
room (Godot -Z), the statues look back through the opening (Godot +Z).
The statues stand inside the width of the opening (centres x -+2.25), so
from Egypt both faces frame a 3.1 m passage between their flanks.
Footprint x -3.5 .. 3.5, depth 0 .. 4.6, height 9.4. Parts:
    khorsabad_gate   towers, plinths, inscriptions, archivolt, merlons
                     (fields world-mapped: tile:asy_alabaster)
    lamassu_l, lamassu_r   the statues (static): legs, wings, crown; their
                     carved bodies and heads lamassu_l_body / lamassu_r_body
    door_l, door_r   stone leaves under the arch, hinged at x -+1.5
                     (Door leaf frame: origin at the hinge foot); each
                     carries half of the sun-disc socket. Egypt's
                     egypt_seal_door_* already shut the junction: hide these
                     two then, or use them instead (and theirs open).
Markers: seal_socket / SealSocket (the sun disc between the leaves,
toward the approach), Light_l, Light_r (torch lamps on the inner faces of
the towers, asy_torch fits there).
"""
import math

import bmesh
import numpy as np
from mathutils import Matrix, Vector

from artlib import asy, asy_mesh as AM, lamassu as L, asy_relief as rl
from artlib import asy_panels as PN
from artlib.archkit import kit
from artlib.asy import P
from artlib.geo import Part
from artlib.materials import Surface, _dither

S = 1.125                  # statue scale (guardian 4.0 m -> 4.5 m)
PLINTH = 0.25
CX, CY = 2.25, 2.25        # statue centres (x mirrored), along the passage
TOWER_IN, TOWER_OUT = 1.5, 3.5
BACK = 2.95                # inner face of the backing block
DEPTH = 4.6
TOP = 8.6
ARCH_C, ARCH_R0, ARCH_R1 = 5.2, 1.5, 1.95
ARCH_Y0, ARCH_Y1 = 4.25, 4.6
DOOR_Y0, DOOR_Y1 = 3.98, 4.22
DOOR_H = 5.2
SOCKET_Z, SOCKET_R = 1.6, 0.3
PPM = 80
FIFTH = [(-0.41, 0.5, 1.55), (-0.41, 0.36, 0.72), (-0.41, 0.24, 0.24), (-0.41, 0.3, 0.0)]


def _box(p, x0, x1, y0, y1, z0, z1, slot, skip=()):
    """An axis box from its faces (no bevel), skipping faces named in
    ``skip`` ("x0", "x1", "y0", "y1", "z0", "z1")."""
    faces = {
        "x0": ([(x0, y0, z0), (x0, y0, z1), (x0, y1, z1), (x0, y1, z0)], (-1, 0, 0)),
        "x1": ([(x1, y0, z0), (x1, y1, z0), (x1, y1, z1), (x1, y0, z1)], (1, 0, 0)),
        "y0": ([(x0, y0, z0), (x1, y0, z0), (x1, y0, z1), (x0, y0, z1)], (0, -1, 0)),
        "y1": ([(x0, y1, z0), (x0, y1, z1), (x1, y1, z1), (x1, y1, z0)], (0, 1, 0)),
        "z0": ([(x0, y0, z0), (x0, y1, z0), (x1, y1, z0), (x1, y0, z0)], (0, 0, -1)),
        "z1": ([(x0, y0, z1), (x1, y0, z1), (x1, y1, z1), (x0, y1, z1)], (0, 0, 1)),
    }
    for k, (pts, want) in faces.items():
        if k in skip:
            continue
        f = p.poly(pts, slot)[0]
        f.normal_update()
        if f.normal.dot(Vector(want)) < 0:
            f.normal_flip()


def statue(name, mirror):
    """One five-legged lamassu built in the guardian frame, then turned to
    face the passage mouth (Blender -Y) at its place; ``mirror`` = the
    right-hand one (x mirrored). Returns (hard part, clay part, wing relief):
    legs, wings and crown keep their own UVs, the clay body and head are
    unwrapped as organic shapes."""
    cx = CX if mirror else -CX
    p = Part(name, origin=(cx, CY, PLINTH))
    c = Part(name + "_body", origin=(cx, CY, PLINTH + 1.9 * S), parent=name)
    L._clay(c, L.body_clay(S), 3600, "stone", 0.05)
    L.head_parts(c, p, S)
    R = L.wing_relief(PPM)
    for sx in (-1, 1):
        L.wing_parts(p, p, sx, S, R)
    L.tail(c, S)
    for k, pts in L.LEGS.items():
        L.leg(p, pts, S, k[0] == "f")
    L.leg(p, FIFTH, S, True)
    M = Matrix.Translation((-CX, CY, PLINTH)) @ Matrix.Rotation(math.pi, 4, 'Z')
    if mirror:
        M = Matrix.Scale(-1.0, 4, Vector((1, 0, 0))) @ M
    for part in (p, c):
        part.move(list(part.bm.faces), M)
        if mirror:
            bmesh.ops.reverse_faces(part.bm, faces=list(part.bm.faces))
    return p, c, R


def to_local_factory(index_l, index_r):
    """World (gate) -> guardian-frame positions for the statues' texels."""
    def to_local(ctx):
        q = ctx.p.copy()
        out = np.empty_like(q)
        right = np.isin(ctx.part, index_r)
        x, y, z = q[:, 0], q[:, 1], q[:, 2]
        out[:, 0] = np.where(right, (x - CX) / S, -(x + CX) / S)
        out[:, 1] = -(y - CY) / S
        out[:, 2] = (z - PLINTH) / S
        return out
    return to_local


# --------------------------------------------------------------------------
# masonry
# --------------------------------------------------------------------------

def merlon(p, x, y, slot, along_x=True):
    z = TOP
    for w, h in ((0.62, 0.26), (0.46, 0.24), (0.3, 0.2)):
        sx, sy = (w, 0.5) if along_x else (0.5, w)
        p.box((x, y, z + h / 2), (sx, sy, h), slot, bevel=0.01)
        z += h


def masonry():
    p = Part("khorsabad_gate")
    for sx in (-1, 1):
        a, b = sorted((sx * BACK, sx * TOWER_OUT))
        _box(p, a, b, 0.0, DEPTH, 0.0, TOP, "masonry", skip=("z0",))
        a, b = sorted((sx * TOWER_IN, sx * BACK))
        _box(p, a, b, 0.0, DEPTH, 4.75, TOP, "masonry", skip=("x0" if sx < 0 else "x1",))
        a, b = sorted((sx * (CX - 0.7), sx * (CX + 0.7)))
        _box(p, a, b, 0.12, DEPTH - 0.2, 0.0, PLINTH, "stone", skip=("z0",))
        # the inscription between the legs, on the backing block
        x = sx * (BACK - 0.003)
        pts = [(x, 0.55, PLINTH + 0.1), (x, 3.95, PLINTH + 0.1), (x, 3.95, PLINTH + 1.25), (x, 0.55, PLINTH + 1.25)]
        f = p.poly(pts, "text_l" if sx < 0 else "text_r")[0]
        f.normal_update()
        if f.normal.x * sx > 0:
            f.normal_flip()
        for mx in (1.95, 3.0):
            merlon(p, sx * mx, 0.3, "stone")
            merlon(p, sx * mx, DEPTH - 0.3, "stone")
        for my in (1.5, 3.0):
            merlon(p, sx * (TOWER_OUT - 0.25), my, "stone", along_x=False)
    # archivolt of glazed brick over the inner end, the spandrels above it
    n = 24
    for y, want in ((ARCH_Y0, -1), (ARCH_Y1, 1)):
        for i in range(n):
            a0, a1 = math.pi * i / n, math.pi * (i + 1) / n
            pts = [(math.cos(a0) * ARCH_R0, y, ARCH_C + math.sin(a0) * ARCH_R0),
                   (math.cos(a0) * ARCH_R1, y, ARCH_C + math.sin(a0) * ARCH_R1),
                   (math.cos(a1) * ARCH_R1, y, ARCH_C + math.sin(a1) * ARCH_R1),
                   (math.cos(a1) * ARCH_R0, y, ARCH_C + math.sin(a1) * ARCH_R0)]
            f = p.poly(pts, "glaze")[0]
            f.normal_update()
            if f.normal.y * want < 0:
                f.normal_flip()
    soffit = p.lathe([(ARCH_R0, ARCH_Y0), (ARCH_R0, ARCH_Y1)], "glaze_soffit", segments=48, cap_bottom=False,
                     cap_top=False, smooth=False)
    p.move(soffit, Matrix.Translation((0, 0, ARCH_C)) @ Matrix.Rotation(-math.pi / 2, 4, 'X'))
    from artlib.kit import keep
    keep(p, soffit, lambda c: c.z > ARCH_C + 0.01)
    t0 = math.acos(TOWER_IN / ARCH_R1)
    arc = [(math.cos(t0 + (math.pi - 2 * t0) * k / 12) * ARCH_R1, ARCH_C + math.sin(t0 + (math.pi - 2 * t0) * k / 12) * ARCH_R1)
           for k in range(13)]
    spand = [(TOWER_IN, TOP), (-TOWER_IN, TOP), (-TOWER_IN, arc[-1][1])] + arc[::-1][1:-1] + [(TOWER_IN, arc[0][1])]
    for y, want in ((ARCH_Y0, -1), (ARCH_Y1, 1)):
        AMcap(p, spand, y, "masonry", want)
    _box(p, -TOWER_IN, TOWER_IN, ARCH_Y0, ARCH_Y1, TOP - 0.001, TOP, "masonry", skip=("z0", "x0", "x1", "y0", "y1"))
    for x in (-0.95, 0.0, 0.95):
        merlon(p, x, (ARCH_Y0 + ARCH_Y1) / 2, "stone")
    return p


def AMcap(p, pts2, y, slot, want):
    """A flat face in the plane y from (x, z) points (any simple polygon)."""
    from mathutils.geometry import tessellate_polygon
    pts3 = [(x, y, z) for x, z in pts2]
    tris = tessellate_polygon([pts3])
    vs = [p.bm.verts.new(v) for v in pts3]
    for a, b, c in tris:
        if len({a, b, c}) < 3:
            continue
        f = p._face([vs[a], vs[b], vs[c]], slot)
        f.normal_update()
        if f.normal.y * want < 0:
            f.normal_flip()


# --------------------------------------------------------------------------
# doors with the sun-disc socket
# --------------------------------------------------------------------------

W_LEAF = TOWER_IN


def door_relief(seed=1401):
    """One leaf's carved face, u from the meeting edge (0) to the hinge
    (W_LEAF), v up: a border, a grid of rosettes in squares (the carpet
    patterns of palace thresholds), the half sun disc with rays."""
    R = rl.Relief(W_LEAF, DOOR_H, PPM, u0=0.0, v0=0.0, seed=seed)
    R.base[:] = 0.0
    border = R.box((W_LEAF / 2, DOOR_H / 2), W_LEAF / 2 - 0.12, DOOR_H / 2 - 0.12)
    R.base_cut(np.abs(border), R.px * 1.3, 0.005)
    R.base_cut(np.abs(R.box((W_LEAF / 2, DOOR_H / 2), W_LEAF / 2 - 0.05, DOOR_H / 2 - 0.05)), R.px * 1.3, 0.005)
    inside = border < 0
    cell = 0.36
    fx = np.mod(R.X - 0.12, cell) - cell / 2
    fy = np.mod(R.Y - 0.12, cell) - cell / 2
    rr = np.hypot(fx, fy)
    ang = np.arctan2(fy, fx)
    sun = np.hypot(R.X, R.Y - SOCKET_Z) < SOCKET_R + 0.32
    sq = inside & ~sun & (np.maximum(np.abs(fx), np.abs(fy)) > cell / 2 - R.px * 1.2)
    R.base = np.where(sq, R.base - 0.004, R.base)
    petal = inside & ~sun & (rr < 0.17 * (0.6 + 0.4 * np.abs(np.cos(ang * 4.0))))
    R.base = np.where(petal, R.base + 0.008, R.base)
    R.base = np.where(inside & ~sun & (rr < 0.04), R.base + 0.004, R.base)
    # sun: rays round the socket
    d = np.hypot(R.X, R.Y - SOCKET_Z)
    a = np.arctan2(R.Y - SOCKET_Z, R.X)
    rays = (d > SOCKET_R + 0.04) & (d < SOCKET_R + 0.26) & (np.abs(np.mod(a * 16 / math.tau, 1.0) - 0.5) < 0.22)
    R.base = np.where(rays, R.base + 0.01 * (1.0 - (d - SOCKET_R) / 0.3), R.base)
    R.base_cut(np.abs(d - SOCKET_R - 0.02), R.px * 1.5, 0.006)
    return R


def door(name, side):
    """side -1: door_l (hinge at x = -W_LEAF), +1: door_r. Pivot at the hinge."""
    hx = side * W_LEAF
    p = Part(name, origin=(hx, (DOOR_Y0 + DOOR_Y1) / 2, 0.0))
    a, b = sorted((0.0, hx))
    _box(p, a, b, DOOR_Y0, DOOR_Y1, 0.0, DOOR_H, "door_edge", skip=("y0",))
    f = p.poly([(a, DOOR_Y0, 0.0), (b, DOOR_Y0, 0.0), (b, DOOR_Y0, DOOR_H), (a, DOOR_Y0, DOOR_H)], "door")[0]
    f.normal_update()
    if f.normal.y > 0:
        f.normal_flip()
    # half a bronze ring round the socket, the recess dark
    ring = p.lathe([(0.0, 0.0), (SOCKET_R + 0.05, 0.0), (SOCKET_R + 0.05, 0.03), (SOCKET_R, 0.045),
                    (SOCKET_R - 0.03, 0.02), (0.0, 0.02)], "socket", segments=24, phase=math.pi / 24)
    p.move(ring, Matrix.Translation((0.0, DOOR_Y0 - 0.001, SOCKET_Z)) @ Matrix.Rotation(math.pi / 2, 4, 'X'))
    from artlib.kit import keep
    keep(p, ring, lambda c: c.x * side > 1e-4)
    return p


def _socket(ctx):
    s = asy.bronze_aged(ctx, center=5.8, green=0.5)
    r = np.hypot(ctx.p[:, 0], ctx.p[:, 2] - SOCKET_Z)
    rec = r < SOCKET_R - 0.03
    s.use_ramp(P["asy_bitumen"], mask=rec, shade=np.full(ctx.N, 2.0))
    s.metal = np.where(rec, 0.0, s.metal)
    return s


def _glaze_ring(ctx, seed=1411):
    """The archivolt: lapis glazed bricks in radial courses, yellow and
    white rosettes every 0.6 m of arc, white edging."""
    x, y, z = ctx.p[:, 0], ctx.p[:, 1], ctx.p[:, 2]
    r = np.hypot(x, z - ARCH_C)
    ang = np.arctan2(z - ARCH_C, x)
    arc = ang * (ARCH_R0 + ARCH_R1) / 2
    rad = r - ARCH_R0
    soffit = np.abs(r - ARCH_R0) < 0.01
    u = np.where(soffit, arc, arc)
    v = np.where(soffit, y - ARCH_Y0, rad)
    s = Surface(ctx.N)
    tx = ctx.texel
    brick_u = np.mod(u, 0.33)
    course = np.floor(v / 0.11)
    joint = (np.mod(v, 0.11) < tx) | (np.mod(u + course * 0.165, 0.33) < tx)
    s.use_ramp(P["asy_lapis"], shade=4.6 + ctx.fbm(5.0, 2, seed) * 0.5 + _dither(ctx, 0.5, seed + 1))
    cu = np.mod(u, 0.6) - 0.3
    cv = v - 0.25
    rr = np.hypot(cu, cv)
    pa = np.arctan2(cv, cu)
    pet = (rr < 0.16) & (rr > 0.04) & (np.abs(np.mod(pa * 8 / math.tau, 1.0) - 0.5) < 0.3)
    s.use_ramp(P["asy_glaze_yellow"], mask=pet & ~soffit, shade=np.full(ctx.N, 4.8) - (rr / 0.16) * 1.4)
    s.use_ramp(P["asy_glaze_white"], mask=(rr < 0.04) & ~soffit, shade=np.full(ctx.N, 4.2))
    edge = (v < 0.05) | (v > 0.45)
    s.use_ramp(P["asy_glaze_white"], mask=edge & ~soffit, shade=np.full(ctx.N, 3.8) + _dither(ctx, 0.5, seed + 2))
    wear = ctx.fbm(14.0, 2, seed + 3) > 0.5
    s.use_ramp(P["asy_brick_baked"], mask=wear & ~joint, shade=np.full(ctx.N, 5.0))
    s.use_ramp(P["asy_bitumen"], mask=joint, shade=np.full(ctx.N, 3.0))
    s.shade -= (1.0 - ctx.ao) * 2.5
    s.rough = np.where(joint | wear, 0.85, 0.22)
    s.height = joint * -0.003
    return s


def build():
    gate = masonry()
    sl, cl, R = statue("lamassu_l", False)
    sr, cr, _ = statue("lamassu_r", True)
    dl = door("door_l", -1)
    dr = door("door_r", 1)
    parts = [gate, sl, cl, sr, cr, dl, dr]
    to_local = to_local_factory((1, 2), (3, 4))
    fns = dict(L.materials(to_local, S, R))
    # inscriptions between the legs (u along the passage, v up)
    RT = rl.Relief(3.4, 1.15, PPM, u0=0.55, v0=PLINTH + 0.1, seed=1421)  # u = y along the passage
    RT.base[:] = 0.0
    rl.cuneiform(RT, 0.62, PLINTH + 0.14, 3.88, PLINTH + 1.21, 0.075, seed=1422, depth=0.005)
    tmaps = asy.ReliefMaps(RT)
    fns["text_l"] = asy.relief_material(tmaps, uv=lambda c: (c.p[:, 1], c.p[:, 2]), center=8.4, paint=0.0)
    fns["text_r"] = asy.relief_material(tmaps, uv=lambda c: (4.5 - c.p[:, 1], c.p[:, 2]), center=8.4, paint=0.0)
    fns["stone"] = _stone_switch(fns["stone"])
    fns["glaze"] = _glaze_ring
    fns["glaze_soffit"] = _glaze_ring
    RD = door_relief()
    dmaps = asy.ReliefMaps(RD)
    fns["door"] = asy.relief_material(dmaps, uv=lambda c: (np.abs(c.p[:, 0]), c.p[:, 2]), center=8.2, paint=0.0)
    fns["door_edge"] = lambda c: asy.alabaster(c, center=8.0)
    fns["socket"] = _socket
    markers = [("seal_socket", (0.0, DOOR_Y0 - 0.06, SOCKET_Z), None),
               ("SealSocket", (0.0, DOOR_Y0 - 0.06, SOCKET_Z), None),
               ("Light_l", (-3.2, DEPTH + 0.35, 3.8), None),
               ("Light_r", (3.2, DEPTH + 0.35, 3.8), None)]
    return kit("khorsabad_gate", parts, fns, kinds={"masonry": "tile:asy_alabaster"}, ppm=PPM, built_final=True,
               organic=("lamassu_l_body", "lamassu_r_body"), ground=0.0, ao_rays=6, ao_dist=0.4, ao_stride=3, pad=2,
               markers=markers, preview_yaws=(200.0, 160.0, 235.0, 125.0), preview_elevation=10.0,
               preview_extra=[("face", (-CX, 0.6, 3.6), 1.3, 200.0, 4.0),
                              ("passage", (0.0, 2.0, 2.4), 3.2, 180.0, 6.0),
                              ("approach", (0.0, 1.0, 2.6), 2.9, 180.0, 2.0)])


def _stone_switch(statue_stone):
    """The statues' stone material, or plain dressed alabaster on the
    masonry (plinths, merlons: object index 0)."""
    def fn(ctx):
        s = statue_stone(ctx)
        m = ctx.part == 0
        if m.any():
            plain = asy.alabaster(ctx.subset(m), center=8.2)
            s.merge(plain, m)
        return s
    return fn
