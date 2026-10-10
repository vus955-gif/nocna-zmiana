"""Floor I: the Reading Room drum seen from the Great Court (Portland stone).

  rr_drum_wall    one of the 16 faces of the drum (22.5 degrees), 21.65 m
                  high: granite plinth, banded rustication up to the
                  balcony string course (6.3 - 6.95), an upper storey with
                  half pilasters on the corners (they pair up into bent
                  corner pilasters) and an arched window with a dark,
                  faintly lamp-lit glazing, a full entablature (architrave,
                  frieze with a wreath, dentil cornice), a panelled attic
                  and the crowning cornice the roof's drum ring rests on
                  (top y = 21.65, out to r = 13.3).
  rr_drum_door    the same face with a portal: opening 3 x 4.5 m through the
                  whole wall (reveals, soffit, threshold), architrave,
                  consoles, cornice and pediment, a gilded "CZYTELNIA"
                  tablet above, two bronze lanterns (markers Light_L,
                  Light_R). Leaves: door_grand_leaf_l / _r scaled to
                  1.5 x 4.5 (Door frame at (0, 0, -11.73) facing out).

Both: origin = drum centre on the floor, the face looks NORTH (Godot -Z) at
z = -12.26 (outer apothem; corners at r = 12.5); inner face at 11.2 (tile
field "tile:plaster", hidden by the bookcases). Place 16 copies at
rotation.y = k * 22.5 degrees (doors at k = 0, 4, 8, 12). Collision per
segment: box (4.88, 21.65, 1.06) centred (0, 10.83, -11.73); a door segment:
two jamb boxes x 0.94..2.44 / -2.44..-0.94 ... see the catalogue.
"""
import math

import numpy as np
from mathutils import Matrix

from artlib import court as C
from artlib import court_materials as CM
from artlib import font, noise
from artlib import materials as M
from artlib.archkit import front_prism, kit
from artlib.geo import Part
from artlib.painter import Surface

H = C.HALF
HP = H - 0.45            # inner edge of the corner half pilasters
OW, OH = 3.0, 4.5        # portal opening
NW, SILL, NSPRING = 1.7, 8.3, 12.55   # window (niche) width, sill, springing

CM.P.setdefault("night_glass", CM.hexramp("#04060b", "#070b14", "#0b111e", "#101828", "#162135", "#1e2b44",
                                           "#283856"))


def _ext(p, prof, x0, x1, mat, caps=False):
    return p.extrude(prof, x0, x1, mat, caps=caps)


def plinth(p, spans):
    prof = [(-0.3, 0.0), (-0.3, 0.72), (-0.26, 0.78), (-0.2, 0.84), (-0.2, 0.9), (0.0, 0.92)]
    for x0, x1, caps in spans:
        _ext(p, prof, x0, x1, "plinth", caps=caps)


def string_course(p):
    prof = [(0.0, C.STRING), (-0.12, C.STRING), (-0.12, C.STRING + 0.12), (-0.2, C.STRING + 0.18),
            (-0.3, C.STRING + 0.3), (-0.3, C.STRING + 0.5), (-0.22, C.STRING + 0.55), (-0.2, C.STRING + 0.65),
            (0.0, C.STRING + 0.65)]
    _ext(p, prof, -H, H, "portland")
    # pedestal course of the upper storey
    _ext(p, [(0.0, 6.95), (-0.1, 6.95), (-0.1, 7.3), (-0.06, 7.34), (-0.06, 7.4), (0.0, 7.4)], -H, H, "portland")


def pilasters(p, z0, z1, depth=0.16, cap=True):
    for sx in (-1, 1):
        a, b = (HP, H) if sx > 0 else (-H, -HP)
        cx = (a + b) / 2
        p.box((cx, -depth / 2, (z0 + z1) / 2), (b - a, depth, z1 - z0), "ashlar", bevel=0.012)
        # base and capital: mouldings returned round the inner side
        base = [(0.0, z0), (-depth - 0.08, z0), (-depth - 0.08, z0 + 0.12), (-depth - 0.04, z0 + 0.2),
                (-depth, z0 + 0.25), (0.0, z0 + 0.25)]
        lo, hi = (a - 0.06, b) if sx > 0 else (a, b + 0.06)
        _cap_run(p, base, lo, hi, sx)
        lo, hi = (a - 0.1, b) if sx > 0 else (a, b + 0.1)
        if cap:
            capp = [(0.0, C.CAP), (-depth - 0.02, C.CAP), (-depth - 0.02, C.CAP + 0.08), (-depth - 0.06, C.CAP + 0.12),
                    (-depth - 0.06, C.CAP + 0.4), (-depth - 0.14, C.CAP + 0.5), (-depth - 0.14, C.CAP + 0.7),
                    (0.0, C.CAP + 0.7)]
            _cap_run(p, capp, lo, hi, sx)


def _cap_run(p, prof, lo, hi, sx):
    """A moulding run on a corner pilaster: open at the joint end (x = +-H),
    capped at the inner end."""
    faces = p.extrude(prof, lo, hi, "portland", caps=True)
    return faces


def face_ground(p, door):
    if not door:
        C.front(p, -H, H, 0.9, C.STRING, "rustic")
        return
    hw = OW / 2
    C.front(p, -H, -hw, 0.9, C.STRING, "rustic")
    C.front(p, hw, H, 0.9, C.STRING, "rustic")
    C.front(p, -hw, hw, OH, C.STRING, "rustic")


def window(p):
    """The upper storey's arched window, recessed 0.3 m, with architrave,
    keystone and sill."""
    hw = NW / 2
    R = hw
    arc = C.arch_pts(0.0, NSPRING, R, 12)              # right springing -> left springing
    # face round the opening
    C.front(p, -HP, -hw, 7.4, C.CAP, "ashlar")
    C.front(p, hw, HP, 7.4, C.CAP, "ashlar")
    C.front(p, -hw, hw, 7.4, SILL, "ashlar")
    head = [(hw, NSPRING)] + arc[1:-1] + [(-hw, NSPRING), (-hw, C.CAP), (hw, C.CAP)]
    C.quad(p, [(x, 0.0, z) for x, z in head], "ashlar", (0, -1, 0))
    # reveals: jambs, sill, the arch soffit (depth 0.3)
    D = 0.3
    for sx in (-1, 1):
        C.quad(p, [(sx * hw, 0.0, SILL), (sx * hw, D, SILL), (sx * hw, D, NSPRING), (sx * hw, 0.0, NSPRING)],
               "portland", (-sx, 0, 0))
    C.quad(p, [(-hw, 0.0, SILL), (hw, 0.0, SILL), (hw, D, SILL), (-hw, D, SILL)], "portland", (0, 0, 1))
    for i in range(len(arc) - 1):
        (xa, za), (xb, zb) = arc[i], arc[i + 1]
        C.quad(p, [(xa, 0.0, za), (xb, 0.0, zb), (xb, D, zb), (xa, D, za)], "portland", (-(xa + xb), 0, -(za + zb - 2 * NSPRING)))
    # the glazing
    back = [(-hw, SILL), (hw, SILL)] + arc[:]
    C.quad(p, [(x, D, z) for x, z in back[:2] + back[2:]], "window", (0, -1, 0))
    # architrave round the opening and the sill
    path = [(-hw, SILL)] + list(reversed(arc)) + [(hw, SILL)]
    prof = [(0.0, 0.0), (0.06, 0.0), (0.06, 0.04), (0.09, 0.07), (0.09, 0.18), (0.05, 0.22), (0.0, 0.22)]
    p.sweep(prof, path, "portland")
    p.box((0.0, -0.08, SILL - 0.08), (NW + 0.7, 0.2, 0.16), "portland", bevel=0.02)
    for sx in (-1, 1):
        p.box((sx * 0.5, -0.05, SILL - 0.26), (0.18, 0.1, 0.22), "portland", bevel=0.015)
    # keystone
    key = [(-0.14, NSPRING + R - 0.05), (0.14, NSPRING + R - 0.05), (0.2, NSPRING + R + 0.4), (-0.2, NSPRING + R + 0.4)]
    front_prism(p, key, 0.16, "portland", bevel=0.015)


def apron(p, door):
    if door:
        # gilded "CZYTELNIA" tablet
        p.box((0.0, -0.05, 7.82), (2.9, 0.1, 0.66), "portland", bevel=0.025)
        p.box((0.0, -0.105, 7.82), (2.7, 0.012, 0.5), "tablet")
    else:
        p.box((0.0, -0.04, 7.85), (1.5, 0.08, 0.5), "portland", bevel=0.02)
        p.box((0.0, -0.085, 7.85), (1.24, 0.012, 0.3), "sunk")


def entablature(p):
    z = C.ENT
    prof = [(0.0, z), (-0.1, z), (-0.1, z + 0.2), (-0.13, z + 0.22), (-0.13, z + 0.42), (-0.18, z + 0.46),
            (-0.18, z + 0.5), (-0.06, z + 0.5), (-0.06, z + 1.0), (-0.12, z + 1.04), (-0.2, z + 1.1),
            (-0.2, z + 1.22), (-0.5, z + 1.24), (-0.6, z + 1.28), (-0.6, z + 1.44), (-0.66, z + 1.48),
            (-0.72, z + 1.55), (-0.72, z + 1.6), (-0.1, z + 1.62), (0.0, z + 1.62)]
    _ext(p, prof, -H, H, "portland")
    # dentils under the corona
    n = int(round(2 * H / 0.25))
    for k in range(n):
        x = -H + (k + 0.5) * 2 * H / n
        p.box((x, -0.26, z + 1.165), (0.12, 0.12, 0.11), "portland")
    # a wreath on the frieze
    ring = [(0.24 * math.cos(a), -0.06, z + 0.75 + 0.24 * math.sin(a)) for a in np.linspace(0, math.tau, 17)]
    p.tube(ring, 0.05, "portland", sides=6, caps=False)
    for sx in (-1, 1):
        rib = p.box((sx * 0.34, -0.09, z + 0.62), (0.16, 0.05, 0.05), "portland", bevel=0.01)
        p.move(rib, Matrix.Translation((sx * 0.34, -0.09, z + 0.62)) @ Matrix.Rotation(math.radians(-25 * sx), 4, 'Y')
               @ Matrix.Translation((-sx * 0.34, 0.09, -(z + 0.62))))


def attic(p):
    z0 = C.ATTIC + 0.02
    _ext(p, [(-0.1, z0), (-0.14, z0 + 0.06), (-0.14, z0 + 0.22), (-0.1, z0 + 0.28), (-0.08, z0 + 0.36),
             (0.0, z0 + 0.38)], -H, H, "portland")
    zf = z0 + 0.38
    C.front(p, -HP, HP, zf, C.COPING, "ashlar")
    # attic piers continuing the pilasters
    for sx in (-1, 1):
        a, b = (HP, H) if sx > 0 else (-H, -HP)
        p.box(((a + b) / 2, -0.06, (zf + C.COPING) / 2), (b - a, 0.12, C.COPING - zf), "ashlar", bevel=0.012)
    # sunk panel
    x0, x1, pz0, pz1 = -1.45, 1.45, zf + 0.55, C.COPING - 0.5
    path = [(x0, pz0), (x0, pz1), (x1, pz1), (x1, pz0)]
    p.sweep([(0.0, 0.0), (0.04, 0.0), (0.04, 0.05), (0.0, 0.12)], path, "portland", closed=True)
    C.front(p, x0 + 0.12, x1 - 0.12, pz0 + 0.12, pz1 - 0.12, "sunk", y=-0.001)


def coping(p):
    z = C.COPING
    prof = [(0.0, z), (-0.12, z), (-0.12, z + 0.08), (-0.24, z + 0.14), (-0.42, z + 0.24), (-0.62, z + 0.3),
            (-0.62, z + 0.36), (-0.95, z + 0.4), (-1.05, z + 0.44), (-1.05, C.TOP - 0.02), (-1.03, C.TOP),
            (C.THICK, C.TOP)]
    _ext(p, prof, -H, H, "portland")
    # small modillions under the overhang
    n = int(round(2 * H / 0.6))
    for k in range(n):
        x = -H + (k + 0.5) * 2 * H / n
        p.box((x, -0.42, z + 0.2), (0.14, 0.5, 0.16), "portland", bevel=0.015)


def inner_face(p, door):
    y = C.THICK
    if not door:
        C.quad(p, [(-H, y, 0.0), (H, y, 0.0), (H, y, C.TOP), (-H, y, C.TOP)], "inner", (0, 1, 0))
        return
    hw = OW / 2
    for a, b, z0, z1 in ((-H, -hw, 0.0, C.TOP), (hw, H, 0.0, C.TOP), (-hw, hw, OH, C.TOP)):
        C.quad(p, [(a, y, z0), (b, y, z0), (b, y, z1), (a, y, z1)], "inner", (0, 1, 0))


def portal(p):
    hw = OW / 2
    D = C.THICK
    # reveals through the wall and the soffit
    for sx in (-1, 1):
        C.quad(p, [(sx * hw, 0.0, 0.0), (sx * hw, D, 0.0), (sx * hw, D, OH), (sx * hw, 0.0, OH)], "reveal", (-sx, 0, 0))
    C.quad(p, [(-hw, 0.0, OH), (hw, 0.0, OH), (hw, D, OH), (-hw, D, OH)], "reveal", (0, 0, -1))
    p.box((0.0, D / 2, 0.01), (OW, D, 0.02), "plinth")
    # architrave: base blocks, three fasciae round the opening
    W = 0.34
    for sx in (-1, 1):
        p.box((sx * (hw + W / 2), -0.08, 0.5), (W + 0.06, 0.16, 1.0), "portland", bevel=0.02)
    path = [(-hw, 1.0), (-hw, OH), (hw, OH), (hw, 1.0)]
    prof = [(0.0, 0.0), (0.08, 0.0), (0.08, 0.1), (0.1, 0.12), (0.1, 0.22), (0.13, 0.25), (0.13, W - 0.04),
            (0.09, W), (0.0, W)]
    p.sweep(prof, path, "portland")
    # frieze and consoles
    fz0, fz1 = OH + W, OH + W + 0.42
    p.box((0.0, -0.06, (fz0 + fz1) / 2), (OW + 2 * W, 0.12, fz1 - fz0), "portland", bevel=0.01)
    for sx in (-1, 1):
        x = sx * (hw + W + 0.12)
        p.box((x, -0.14, fz0 - 0.15), (0.2, 0.28, 0.9), "portland", bevel=0.03)
        p.lathe([(0.0, -0.09), (0.09, -0.09), (0.11, 0.0), (0.09, 0.09), (0.0, 0.09)], "portland", segments=8,
                center=(x, -0.28, fz0 + 0.18))
        # pediment ends meet the consoles
    # cornice
    cz = fz1
    cw = OW + 2 * W + 0.7
    p.extrude([(0.0, cz), (-0.16, cz), (-0.2, cz + 0.05), (-0.36, cz + 0.12), (-0.36, cz + 0.24), (-0.4, cz + 0.28),
               (0.0, cz + 0.3)], -cw / 2, cw / 2, "portland", caps=True)
    # pediment: tympanum and raking cornices
    pz = cz + 0.3
    rise = 0.68
    tri = [(-cw / 2 + 0.15, pz), (cw / 2 - 0.15, pz), (0.0, pz + rise - 0.12)]
    front_prism(p, tri, 0.1, "portland")
    slope = math.atan2(rise, cw / 2)
    L = math.hypot(cw / 2, rise)
    for sx in (-1, 1):
        b = p.box((0.0, 0.0, 0.0), (L + 0.1, 0.42, 0.2), "portland", bevel=0.03)
        p.move(b, Matrix.Translation((sx * cw / 4, -0.2, pz + rise / 2 + 0.02)) @ Matrix.Rotation(sx * slope, 4, 'Y'))
    # acroterion
    p.box((0.0, -0.18, pz + rise + 0.14), (0.3, 0.3, 0.32), "portland", bevel=0.04)


def lantern(p, x, z):
    """Bronze wall lantern on a scroll bracket, glass panes lit warm."""
    # bracket back to the wall
    p.box((x, -0.04, z + 0.25), (0.16, 0.08, 0.4), "bronze", bevel=0.01)
    pts = [(x, -0.06, z + 0.4), (x, -0.25, z + 0.48), (x, -0.42, z + 0.45), (x, -0.5, z + 0.36)]
    p.tube(pts, 0.025, "bronze", sides=6)
    cy = -0.5
    # body: tapered square lantern
    p.box((x, cy, z + 0.33), (0.3, 0.3, 0.05), "bronze", bevel=0.01)
    glass = p.lathe([(0.11, z - 0.12), (0.15, z + 0.3)], "lamp", segments=4, center=(x, cy, 0.0), cap_bottom=False,
                    cap_top=False, phase=math.pi / 4, smooth=False)
    for k in range(4):
        a = math.pi / 4 + k * math.pi / 2
        p.tube([(x + 0.155 * math.cos(a), cy + 0.155 * math.sin(a), z - 0.12),
                (x + 0.205 * math.cos(a), cy + 0.205 * math.sin(a), z + 0.31)], 0.018, "bronze", sides=4)
    p.lathe([(0.0, z - 0.2), (0.07, z - 0.19), (0.13, z - 0.14), (0.14, z - 0.12), (0.0, z - 0.11)], "bronze",
            segments=8, center=(x, cy, 0.0))
    p.lathe([(0.24, z + 0.33), (0.18, z + 0.42), (0.06, z + 0.5), (0.03, z + 0.58), (0.05, z + 0.62), (0.0, z + 0.66)],
            "bronze", segments=8, center=(x, cy, 0.0), phase=math.pi / 4, cap_bottom=True)
    return (x, cy, z + 0.1)


def segment(door):
    p = Part("rr_drum_door" if door else "rr_drum_wall")
    hw = OW / 2
    if door:
        plinth(p, [(-H, -hw - 0.4, True), (hw + 0.4, H, True)])
    else:
        plinth(p, [(-H, H, False)])
    face_ground(p, door)
    string_course(p)
    pilasters(p, 7.4, C.CAP)
    window(p)
    apron(p, door)
    entablature(p)
    attic(p)
    coping(p)
    inner_face(p, door)
    markers = []
    if door:
        portal(p)
        for name, sx in (("Light_L", -1), ("Light_R", 1)):
            markers.append((name, lantern(p, sx * 2.08, 3.3)))
    C.drop_end_faces(p)
    C.wedge(p)
    # marker positions go through the same mapping (flat x, y -> drum frame)
    out = []
    for name, (x, y, z) in markers:
        d = -y
        out.append((name, (-x * (C.A_OUT + d) / C.A_OUT, C.A_OUT + d, z), None))
    return p, out


# --- materials ------------------------------------------------------------------------

def _plinth(ctx):
    s = M.stone(ctx)
    s.shade -= 0.6
    return s


def _sunk(ctx):
    s = CM.portland(ctx)
    s.shade -= 0.9
    return s


def _window(ctx):
    """Dark glazing in iron bars; the lower panes glow faintly with the
    lamps inside the Reading Room."""
    u, v = ctx.uvm[:, 0], ctx.uvm[:, 1]
    tx = ctx.texel
    s = Surface(ctx.N)
    sky = np.clip((v - SILL) / (NSPRING + NW / 2 - SILL), 0, 1)
    s.use_ramp(CM.P["night_glass"], shade=2.0 + sky * 2.5 + ctx.fbm(2.0, 2, 3) * 0.8 + (ctx.rand(4) - 0.5) * 0.6)
    bars = (np.abs(np.mod(u + 0.2125, 0.425) - 0.2125) < tx) | (np.abs(np.mod(v - SILL, 0.6)) < tx)
    r = np.hypot(u, v - NSPRING)
    bars |= (v > NSPRING) & ((np.abs(r - NW / 2 * 0.55) < tx) | (np.abs(np.mod(np.arctan2(v - NSPRING, u), math.pi / 4)) < 0.02))
    # a few panes lit warm from the lamps inside (whole panes, by cell)
    cell = np.floor((u + 0.2125) / 0.425).astype(np.int64) * 31 + np.floor((v - SILL) / 0.6).astype(np.int64)
    lit = noise.rand_cells(cell, 17) > 0.55
    warm = (v < SILL + 2.4) & lit & ~bars
    s.use_ramp(CM.P["lamp_warm"], mask=warm, shade=np.full(ctx.N, 0.6) + ctx.fbm(3.0, 2, 10) * 0.6)
    s.use_ramp(CM.P["cast_iron"], mask=bars, shade=np.full(ctx.N, 3.0))
    s.rough = np.where(bars, 0.5, 0.08)
    s.metal = np.where(bars, 0.4, 0.0)
    emit = np.zeros((ctx.N, 3))
    emit[warm] = s.colors()[warm] * 0.25
    s.emit = emit
    return s


def _tablet(ctx):
    u, v = ctx.uvm[:, 0], ctx.uvm[:, 1]
    s = CM.portland(ctx)
    s.shade -= 0.4
    px = 3 * ctx.texel
    ink = font.text_mask(u, v, "CZYTELNIA", 0.0, 7.82 - 3.5 * px, px, align="center")
    s.use_ramp(CM.P["gold"], mask=ink, shade=np.full(ctx.N, 6.6) + (ctx.rand(7) - 0.5) * 1.2)
    s.metal = np.where(ink, 1.0, 0.0)
    s.rough = np.where(ink, 0.3, s.rough)
    return s


def _lamp(ctx):
    return M.glow(ctx, "lamp_warm", 4.2, strength=1.0, rough=0.2)


FNS = {"plinth": _plinth, "rustic": CM.rusticated_face, "ashlar": CM.ashlar_face, "portland": CM.portland,
       "window": _window, "sunk": _sunk, "reveal": CM.ashlar_face, "tablet": _tablet, "bronze": M.bronze,
       "lamp": _lamp}


def build():
    out = []
    for door in (False, True):
        part, markers = segment(door)
        name = part.name
        out.append(kit(name, [part], FNS, kinds={"inner": "tile:plaster"}, built_final=True, ppm=64, ground=0.0,
                       ao_dist=0.6, markers=markers, preview_yaws=(-20.0, 20.0, 160.0, 200.0),
                       preview_elevation=10.0,
                       preview_extra=[("portal", (0.0, 12.6, 4.0), 4.2, 15.0, 8.0)] if door else
                       [("top", (0.0, 12.6, 16.5), 4.0, 25.0, 10.0)]))
    return out
