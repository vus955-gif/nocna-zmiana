"""Floor I: the entrance hall (32 x 22 m, ceiling 12 m), Greek Revival.

  entrance_column      Greek Doric column floor to ceiling (12 m, kit id
                       "column" in the entrance): low plinth, 20 sharp
                       flutes with entasis (1.3 m at the foot), three
                       annulets, the echinus and abacus, an architrave
                       block to the ceiling. Origin = centre of the base.
  entrance_coffer_3m   3 x 3 m deep coffer (0.5 m) for the ceiling: two
                       stepped frames, a painted Greek key on the first
                       ledge, a blue field with a gilded anthemion rosette.
                       Origin = module centre on the ceiling plane; hangs
                       down. Tiles edge to edge like hall_coffer_2m.
  entrance_door_l / _r the bronze main doors (one leaf 2.2 x 5.0 x 0.14 m,
                       Door's leaf frame: origin = centre of the leaf base,
                       both faces finished): six raised panels, studs, a
                       lion-head knocker with its ring, a heavy pull and a
                       keyhole escutcheon at the meeting stile (_l: hinged
                       at -X, meeting stile at +X; _r the mirror).
  entrance_door_sign   the night notice "WYJŚCIE / OTWARTE OD 6:00" on a
                       brass-framed enamel plate (0.82 x 0.42 m): origin =
                       back centre on the face it hangs on, faces -Z.
  cloakroom_counter    "SZATNIA": an 6 m oak counter with a lifting flap,
                       brass number tokens on a board, two coat rails with
                       hangers and a few coats left behind, an umbrella
                       stand; 6.0 x 3.1 x 2.6 m, front -Z.
  entrance_mosaic      8 x 6 m floor mosaic 4 mm proud of the floor: a black
                       and white meander border, a red and ochre guilloche,
                       a field of scattered tesserae and a central roundel
                       "MVSEVM / MDCCLIII". Origin = centre, on the floor.
"""
import math

import numpy as np
from mathutils import Matrix, Vector

from artlib import arch_materials as A
from artlib import court as C
from artlib import court_materials as CM
from artlib import font
from artlib import materials as M
from artlib.archkit import cull_floor, kit
from artlib.geo import Part
from artlib.painter import Surface

CM.P.update({
    "tess_red": CM.hexramp("#2e0b07", "#4a130b", "#661c10", "#842816", "#a1361e"),
    "tess_ochre": CM.hexramp("#3a2a0e", "#5a4216", "#7c5c20", "#9e782c", "#bf9439"),
    "tess_black": CM.hexramp("#0b0b0c", "#151517", "#202023", "#2b2b2f"),
    "tess_white": CM.hexramp("#8e8a80", "#aaa69b", "#c4c0b4", "#dad6ca", "#ebe8de"),
    "coat_grey": CM.hexramp("#141517", "#1e2023", "#292c30", "#35393e", "#42474d"),
    "coat_camel": CM.hexramp("#2b1c0c", "#423014", "#5c451e", "#765b2a", "#907237"),
})


# --------------------------------------------------------------------------
# Doric column
# --------------------------------------------------------------------------

def column():
    p = Part("entrance_column")
    p.box((0, 0, 0.075), (1.62, 1.62, 0.15), "marble_dark", bevel=0.015)
    z0, z1 = 0.15, 10.55
    rings = 12
    prof = []
    for k in range(rings):
        t = k / (rings - 1)
        r = 0.65 - 0.13 * t * t + 0.02 * math.sin(t * math.pi)
        prof.append((r, z0 + (z1 - z0) * t))
    last = len(prof) - 1
    p.lathe(prof, "shaft", segments=40, cap_bottom=False, cap_top=False, smooth=False,
            ring_scale=lambda i, j: 1.0 if (i % 2 == 0 or j in (0, last)) else 0.94)
    # annulets, echinus, abacus
    p.lathe([(0.52, 10.55), (0.53, 10.57), (0.53, 10.6), (0.52, 10.62), (0.53, 10.64), (0.53, 10.67),
             (0.52, 10.69), (0.53, 10.71), (0.53, 10.74), (0.52, 10.76), (0.56, 10.8), (0.66, 10.9), (0.76, 11.0),
             (0.82, 11.08), (0.83, 11.12), (0.6, 11.12)], "stone", segments=32, cap_bottom=False, cap_top=False)
    p.box((0, 0, 11.27), (1.72, 1.72, 0.3), "stone", bevel=0.02)
    # architrave block to the ceiling with a fillet
    p.box((0, 0, 11.68), (1.5, 1.5, 0.52), "stone", bevel=0.02)
    p.box((0, 0, 11.95), (1.62, 1.62, 0.1), "stone", bevel=0.015)
    return p


def _shaft(ctx):
    s = CM.portland(ctx, center=6.9)
    return s


# --------------------------------------------------------------------------
# coffer
# --------------------------------------------------------------------------

def coffer():
    p = Part("entrance_coffer")
    lo, hi = -0.9, 0.9
    path = [(lo, lo), (lo, hi), (hi, hi), (hi, lo)]
    # (depth hanging down, offset out from the panel edge): risers, the
    # painted key ledge, a second step, the beam soffit to the module edge
    p.sweep([(0.02, 0.0), (0.12, 0.0)], path, "frame", closed=True)
    p.sweep([(0.12, 0.0), (0.12, 0.2)], path, "key", closed=True)
    p.sweep([(0.12, 0.2), (0.14, 0.22), (0.3, 0.22), (0.3, 0.4), (0.32, 0.42), (0.5, 0.42), (0.5, 0.6)], path,
            "frame", closed=True)
    f = p.poly([(lo, -0.02, lo), (hi, -0.02, lo), (hi, -0.02, hi), (lo, -0.02, hi)], "field")[0]
    f.normal_update()
    if f.normal.y > 0:
        f.normal_flip()
    ros = p.lathe([(0.0, 0.0), (0.26, 0.0), (0.26, 0.03), (0.2, 0.06), (0.12, 0.09), (0.06, 0.11), (0.0, 0.12)],
                  "rosette", segments=16, cap_bottom=False)
    p.move(ros, Matrix.Translation((0.0, -0.02, 0.0)) @ Matrix.Rotation(math.radians(90), 4, 'X'))
    # wall frame -> ceiling: the viewer side (-Y) turns to face down
    p.move(list(p.bm.faces), Matrix.Rotation(math.radians(90), 4, 'X'))
    return p


# Greek key, one period of 0.3 m in 6 cells of 0.05 m, on a 0.05 m tall strip
KEY = [((0, 0), (6, 0)), ((0, 0), (0, 5)), ((0, 5), (4, 5)), ((4, 5), (4, 2)), ((4, 2), (2, 2)), ((2, 2), (2, 3))]


def _key(ctx):
    """Painted meander on the ledge strip (u along, v up the strip)."""
    u, v = ctx.uvm[:, 0], ctx.uvm[:, 1]
    s = Surface(ctx.N)
    s.use_ramp(CM.P["dome_cream"], shade=np.full(ctx.N, 6.5) + ctx.fbm(6.0, 2, 3) * 0.4 + (ctx.rand(4) - 0.5) * 0.5)
    cell = 0.03
    cx = np.floor(np.mod(u, 0.18) / cell + 1e-6).astype(np.int64)
    cy = np.floor((v - 0.11) / cell + 1e-6).astype(np.int64)
    m = np.zeros(ctx.N, dtype=bool)
    for (x0, y0), (x1, y1) in KEY:
        m |= (cx >= min(x0, x1)) & (cx <= max(x0, x1)) & (cy >= min(y0, y1)) & (cy <= max(y0, y1))
    m &= (cy >= 0) & (cy <= 5)
    s.use_ramp(CM.P["wing_greece"], mask=m, shade=np.full(ctx.N, 4.0))
    s.rough = np.full(ctx.N, 0.8)
    return s


def _field(ctx):
    s = CM.dome_blue(ctx, center=6.0)
    x, z = ctx.p[:, 0], ctx.p[:, 1]
    r = np.hypot(x, z)
    a = np.arctan2(z, x)
    petal = (r < 0.55) & (r > 0.36) & (np.abs(np.cos(a * 8.0)) > 0.55)
    s.use_ramp(CM.P["gold"], mask=petal, shade=np.full(ctx.N, 6.0))
    s.metal = np.where(petal, 1.0, 0.0)
    return s


def _rosette(ctx):
    s = M.gold(ctx)
    a = np.arctan2(ctx.p[:, 1], ctx.p[:, 0])
    s.shade += np.abs(np.cos(a * 6.0)) ** 2 * 1.5 - 0.7
    return s


# --------------------------------------------------------------------------
# bronze doors
# --------------------------------------------------------------------------

LEAF_T = 0.14


def door(side):
    name = "entrance_door_l" if side > 0 else "entrance_door_r"
    p = Part(name)
    W, H = 2.2, 5.0
    hw = W / 2
    p.box((0, 0, H / 2), (W, LEAF_T * 0.7, H), "bronze", bevel=0.01)
    st = 0.2
    for sy in (-1, 1):
        y = sy * LEAF_T * 0.4
        for x in (-hw + st / 2, hw - st / 2):
            p.box((x, y, H / 2), (st, LEAF_T * 0.2, H), "bronze", bevel=0.01)
        for z0, z1 in ((0.0, 0.3), (1.6, 1.8), (3.3, 3.5), (4.75, 5.0)):
            p.box((0, y, (z0 + z1) / 2), (W - 2 * st, LEAF_T * 0.2, z1 - z0), "bronze", bevel=0.01)
        p.box((0, y, 2.55), (0.12, LEAF_T * 0.2, 4.45), "bronze", bevel=0.01)
        # raised panels (2 x 3)
        for cx in (-hw / 2 - 0.0 + 0.04, hw / 2 - 0.04):
            for z0, z1 in ((0.3, 1.6), (1.8, 3.3), (3.5, 4.75)):
                p.box((cx, y + sy * 0.01, (z0 + z1) / 2), (hw - st - 0.12, LEAF_T * 0.15, z1 - z0 - 0.12),
                      "panel", bevel=0.04)
        # studs on the rails
        for z in (0.15, 1.7, 3.4, 4.87):
            for k in range(6):
                x = -hw + st + 0.15 + k * (W - 2 * st - 0.3) / 5
                stud = p.lathe([(0.0, 0.0), (0.025, 0.0), (0.02, 0.015), (0.0, 0.022)], "stud", segments=6)
                p.move(stud, Matrix.Translation((x, y + sy * LEAF_T * 0.1, z))
                       @ Matrix.Rotation(math.radians(-90 * sy), 4, 'X'))
        # lion-head knocker with its ring, a heavy pull and the escutcheon
        lx = side * (hw - 0.55)
        head = p.lathe([(0.0, 0.0), (0.12, 0.0), (0.12, 0.03), (0.09, 0.07), (0.05, 0.09), (0.0, 0.1)], "knocker",
                       segments=10)
        p.move(head, Matrix.Translation((lx, y + sy * LEAF_T * 0.1, 2.3)) @ Matrix.Rotation(math.radians(-90 * sy), 4, 'X'))
        ring = [(lx + 0.11 * math.cos(a), y + sy * (LEAF_T * 0.1 + 0.08), 2.12 + 0.11 * math.sin(a))
                for a in np.linspace(0, math.tau, 13)]
        p.tube(ring, 0.018, "knocker", sides=5, caps=False)
        px = side * (hw - 0.14)
        p.tube([(px, y + sy * LEAF_T * 0.1, 1.05), (px, y + sy * (LEAF_T * 0.1 + 0.1), 1.1),
                (px, y + sy * (LEAF_T * 0.1 + 0.1), 1.5), (px, y + sy * LEAF_T * 0.1, 1.55)], 0.022, "knocker",
               sides=6)
        p.box((px, y + sy * LEAF_T * 0.1, 0.95), (0.07, 0.01, 0.16), "knocker", bevel=0.004)
    return p


def _bronze(ctx):
    s = Surface(ctx.N)
    shade = 4.6 + ctx.fbm(3.0, 3, 5) * 0.8 + (ctx.rand(6) - 0.5) * 0.6 + ctx.edge(1.0) * 2.5
    shade -= ctx.cavity(3.0) * 2.0 + (1.0 - ctx.ao) * 3.0
    s.use_ramp(CM.P["bronze_door"], shade=shade)
    patina = (ctx.cavity(3.0) > 0.3) & (ctx.fbm(8.0, 2, 7) > 0.0)
    s.use_ramp(CM.P["bronze"], mask=patina, shade=np.full(ctx.N, 4.5) + (ctx.rand(8) - 0.5))
    s.metal = np.where(patina, 0.3, 0.9)
    s.rough = np.where(patina, 0.7, 0.35)
    return s


def _panel(ctx):
    s = _bronze(ctx)
    s.shade -= 0.6
    return s


def _knocker(ctx):
    s = M.brass(ctx, ramp="bronze_metal" if "bronze_metal" in CM.P else "brass")
    s.shade += 0.8
    return s


def door_sign():
    p = Part("entrance_door_sign")
    p.box((0, -0.008, 0), (0.82, 0.016, 0.42), "brass", bevel=0.004)
    p.box((0, -0.017, 0), (0.76, 0.004, 0.36), "notice")
    return p


def _notice(ctx):
    u, v = ctx.uvm[:, 0], ctx.uvm[:, 1]
    s = Surface(ctx.N)
    s.use_ramp(CM.P["enamel_white"], shade=np.full(ctx.N, 6.3) + (ctx.rand(3) - 0.5) * 0.4)
    px = 3.0 / 256
    ink = font.text_mask(u, v, "WYJŚCIE", 0.0, 0.06, px)
    ink |= font.text_mask(u, v, "OTWARTE OD 6:00", 0.0, -0.08, 2.0 / 256)
    tx = ctx.texel
    rule = (np.abs(v - 0.02) < tx) & (np.abs(u) < 0.3)
    border = ((np.abs(np.abs(u) - 0.35) < tx) & (np.abs(v) < 0.16)) | ((np.abs(np.abs(v) - 0.16) < tx) & (np.abs(u) < 0.35))
    s.use_ramp(CM.P["formline_red"], mask=ink | rule | border, shade=np.full(ctx.N, 4.6))
    s.rough = np.full(ctx.N, 0.2)
    return s


# --------------------------------------------------------------------------
# cloakroom
# --------------------------------------------------------------------------

def cloakroom():
    p = Part("cloakroom_counter")
    W = 6.0
    # counter (front face at y = -0.45), a lifting flap at +X
    p.box((-0.4, 0, 0.06), (W - 0.8, 0.84, 0.12), "marble_dark", bevel=0.01)
    p.box((-0.4, 0, 0.55), (W - 0.84, 0.8, 0.86), "oak_panel", bevel=0.012)
    p.box((-0.4, -0.02, 1.0), (W - 0.74, 0.92, 0.05), "oak", bevel=0.012)
    p.box((W / 2 - 0.4, -0.02, 1.0), (0.78, 0.92, 0.05), "oak", bevel=0.012)
    p.box((W / 2 - 0.4, 0.0, 0.55), (0.04, 0.7, 0.86), "oak_dark", bevel=0.008)
    # token board on the counter end, little brass bell
    p.box((-W / 2 + 0.5, 0.2, 1.3), (0.7, 0.05, 0.5), "tokens", bevel=0.01)
    p.box((-W / 2 + 0.5, 0.24, 1.04), (0.06, 0.06, 0.04), "oak_dark")
    p.lathe([(0.0, 1.025), (0.05, 1.025), (0.05, 1.04), (0.04, 1.08), (0.015, 1.1), (0.0, 1.11)], "brass",
            segments=10, center=(0.4, -0.2, 0.0))
    # back wall panel with the sign, two coat rails with hangers, coats
    by = 2.6
    p.box((0, by + 0.2, 1.3), (W, 0.1, 2.6), "oak_dark", bevel=0.01)
    p.box((0, by + 0.1, 2.45), (2.6, 0.06, 0.4), "sign", bevel=0.01)
    for ry in (1.3, 2.1):
        for sx in (-1, 1):
            p.box((sx * (W / 2 - 0.4), ry, 0.95), (0.06, 0.06, 1.9), "iron", bevel=0.01)
        p.tube([(-W / 2 + 0.4, ry, 1.8), (W / 2 - 0.4, ry, 1.8)], 0.02, "brass", sides=6, caps=False)
        for k in range(18):
            x = -W / 2 + 0.6 + k * (W - 1.2) / 17
            p.tube([(x, ry, 1.8), (x, ry, 1.72), (x - 0.2, ry, 1.6), (x + 0.2, ry, 1.6), (x, ry, 1.72)], 0.006,
                   "brass", sides=3, caps=False)
            seed = (k * 7 + int(ry * 10)) % 11
            if seed in (2, 5, 9):
                ramp = "coat" if seed == 2 else ("coat_grey" if seed == 5 else "coat_camel")
                coat = p.lathe([(0.0, 0.62), (0.2, 0.66), (0.25, 0.9), (0.23, 1.4), (0.2, 1.56), (0.06, 1.62),
                                (0.0, 1.63)], ramp, segments=8, squash=(1.0, 0.45), center=(x, ry, 0.0))
    # umbrella stand with two umbrellas
    p.lathe([(0.0, 0.0), (0.18, 0.0), (0.18, 0.6), (0.16, 0.62), (0.16, 0.05), (0.0, 0.05)], "brass", segments=12,
            center=(-W / 2 + 0.3, -0.9, 0.0))
    for k, (dx, dy) in enumerate(((0.05, 0.03), (-0.04, -0.05))):
        u0 = (-W / 2 + 0.3 + dx, -0.9 + dy, 0.1)
        p.tube([u0, (u0[0] + dx * 2, u0[1] + dy * 2, 0.9)], 0.04, "coat", sides=6)
        p.tube([(u0[0] + dx * 2, u0[1] + dy * 2, 0.9), (u0[0] + dx * 2.2, u0[1] + dy * 2.2, 1.0),
                (u0[0] + dx * 2.2 + 0.05, u0[1] + dy * 2.2, 1.02)], 0.012, "oak_dark", sides=4)
    return p


def _tokens(ctx):
    """A board of brass number tokens on hooks (1 - 40)."""
    u, v = ctx.uvm[:, 0], ctx.uvm[:, 1]
    s = M.wood_dark(ctx)
    front = np.abs(ctx.n[:, 1]) > 0.9
    cu = np.mod(u + 0.35, 0.0875)
    cv = np.mod(v - 1.05, 0.1)
    disc = front & (np.hypot(cu - 0.044, cv - 0.045) < 0.028)
    s.use_ramp(CM.P["brass"], mask=disc, shade=np.full(ctx.N, 6.5) + (ctx.rand(3) - 0.5))
    hole = disc & (np.hypot(cu - 0.044, cv - 0.045) < 0.009)
    s.use_ramp(CM.P["formline_black"], mask=hole, shade=np.full(ctx.N, 1.0))
    s.metal = np.where(disc & ~hole, 1.0, 0.0)
    return s


def _cloak_sign(ctx):
    u, v = ctx.uvm[:, 0], ctx.uvm[:, 1]
    s = Surface(ctx.N)
    s.use_ramp(CM.P["formline_black"], shade=np.full(ctx.N, 2.5) + (ctx.rand(3) - 0.5) * 0.4 + ctx.edge(1.0) * 2.0)
    ink = font.text_mask(u, v, "SZATNIA", 0.0, 2.45 - 0.11, 4.0 / 128)
    s.use_ramp(CM.P["gold"], mask=ink, shade=np.full(ctx.N, 7.0))
    s.metal = np.where(ink, 1.0, 0.0)
    s.rough = np.full(ctx.N, 0.3)
    return s


def _oak_panel(ctx):
    s = M.wood_oak(ctx)
    d = np.mod(ctx.uvm[:, 0], 0.6)
    s.shade = np.where(d < ctx.texel * 1.5, s.shade - 2.2, np.where(d < ctx.texel * 3.0, s.shade + 0.8, s.shade))
    return s


def _coat(ramp):
    def fn(ctx):
        s = Surface(ctx.N)
        s.use_ramp(CM.P[ramp], shade=np.full(ctx.N, 2.6) + ctx.fbm(9.0, 2, 3) * 0.6 + (ctx.rand(4) - 0.5) * 0.5
                   - (1.0 - ctx.ao) * 2.0 + np.clip(ctx.curv, 0, 1))
        s.rough = np.full(ctx.N, 0.9)
        return s
    return fn


# --------------------------------------------------------------------------
# floor mosaic
# --------------------------------------------------------------------------

MW, MH = 8.0, 6.0


def mosaic():
    p = Part("entrance_mosaic")
    C.quad(p, [(-MW / 2, -MH / 2, 0.004), (MW / 2, -MH / 2, 0.004), (MW / 2, MH / 2, 0.004), (-MW / 2, MH / 2, 0.004)],
           "mosaic", (0, 0, 1))
    return p


def _mosaic(ctx):
    x, y = ctx.p[:, 0], ctx.p[:, 1]
    tx = ctx.texel
    n = ctx.N
    s = Surface(n)
    top = ctx.n[:, 2] > 0.9
    # tesserae: a 2-texel grid with one-texel dark joints, each stone its own tone
    g = 2 * tx
    ix = np.floor(x / g).astype(np.int64)
    iy = np.floor(y / g).astype(np.int64)
    joint = (np.mod(x, g) < tx * 0.5) | (np.mod(y, g) < tx * 0.5)
    tone = (np.mod(ix * 73 + iy * 151, 97) / 97.0 - 0.5)
    kind = np.zeros(n, np.int64)            # 0 white field, 1 black, 2 red, 3 ochre
    ex = MW / 2 - np.abs(x)
    ey = MH / 2 - np.abs(y)
    edge = np.minimum(ex, ey)
    # outer black band, meander border, guilloche
    kind[edge < 0.08] = 1
    band = (edge >= 0.12) & (edge < 0.5)
    along = np.where(ex < ey, y, x)
    depth = edge - 0.12
    cell = 0.38 / 8
    cx = np.floor(np.mod(along + 10.0, cell * 8) / cell).astype(np.int64)
    cy = np.floor(depth / cell).astype(np.int64)
    key = np.zeros(n, dtype=bool)
    for (x0, y0), (x1, y1) in (((0, 0), (8, 0)), ((1, 0), (1, 6)), ((1, 6), (7, 6)), ((7, 6), (7, 2)),
                               ((7, 2), (3, 2)), ((3, 2), (3, 4)), ((3, 4), (5, 4))):
        key |= (cx >= min(x0, x1)) & (cx <= max(x0, x1)) & (cy >= min(y0, y1)) & (cy <= max(y0, y1))
    kind[band & key] = 1
    gband = (edge >= 0.6) & (edge < 0.9)
    gd = edge - 0.75
    ga = np.mod(along + 10.0, 0.3) - 0.15
    strand1 = np.abs(gd - 0.1 * np.sin(ga / 0.15 * math.pi)) < 0.035
    strand2 = np.abs(gd + 0.1 * np.sin(ga / 0.15 * math.pi)) < 0.035
    kind[gband & strand1] = 2
    kind[gband & strand2 & ~strand1] = 3
    kind[gband & ((np.abs(gd) > 0.13))] = 1
    # central roundel
    r = np.hypot(x, y)
    kind[(r < 1.65) & (r > 1.55)] = 1
    kind[(r < 1.5) & (r > 1.42)] = 3
    rays = (r < 1.35) & (r > 1.0) & (np.abs(np.cos(np.arctan2(y, x) * 8.0)) > 0.82)
    kind[rays] = 2
    ink = font.text_mask(x, y, "MVSEVM", 0.0, 0.05, 4 * tx) | font.text_mask(x, y, "MDCCLIII", 0.0, -0.32, 3 * tx)
    kind[ink & (r < 1.0)] = 1
    # scattered dark tesserae in the field (opus tessellatum life)
    speck = (kind == 0) & (np.mod(ix * 37 + iy * 91, 53) == 0)
    kind[speck] = 3
    ramps = ["tess_white", "tess_black", "tess_red", "tess_ochre"]
    centers = [3.0, 2.0, 2.6, 2.6]
    for k, ramp in enumerate(ramps):
        m = kind == k
        if m.any():
            s.use_ramp(CM.P[ramp], mask=m, shade=np.full(n, centers[k]) + tone * 1.6)
    s.use_ramp(CM.P["grout"], mask=joint & top, shade=np.full(n, 2.0))
    s.rough = np.where(joint, 0.85, 0.3 + (ctx.rand(5) * 0.1))
    s.height = np.where(joint, -0.0015, 0.0)
    return s


def build():
    cloak = cloakroom()
    cull_floor([cloak])
    return [
        kit("entrance_column", [column()], {"marble_dark": M.marble_dark, "shaft": _shaft, "stone": CM.portland},
            ppm=64, ao_dist=0.5, preview_extra=[("capital", (0.0, 0.0, 11.0), 1.4, 20.0, 10.0)]),
        kit("entrance_coffer_3m", [coffer()], {"frame": CM.dome_cream, "key": _key, "field": _field,
                                               "rosette": _rosette}, built_final=True, ground=None, ceiling=0.0,
            ppm=64, ao_dist=0.5, preview_elevation=-50.0),
        kit("entrance_door_l", [door(1)], {"bronze": _bronze, "panel": _panel, "stud": _knocker, "knocker": _knocker},
            built_final=True, ppm=96, ao_dist=0.2),
        kit("entrance_door_r", [door(-1)], {"bronze": _bronze, "panel": _panel, "stud": _knocker,
                                            "knocker": _knocker}, built_final=True, ppm=96, ao_dist=0.2,
            preview=False),
        kit("entrance_door_sign", [door_sign()], {"brass": M.brass, "notice": _notice}, ppm=256, ground=None,
            wall=True, ao_dist=0.03),
        kit("cloakroom_counter", [cloak], {"marble_dark": M.marble_dark, "oak_panel": _oak_panel, "oak": M.wood_oak,
                                           "oak_dark": M.wood_dark, "tokens": _tokens, "brass": M.brass,
                                           "sign": _cloak_sign, "iron": CM.cast_iron, "coat": _coat("coat"),
                                           "coat_grey": _coat("coat_grey"), "coat_camel": _coat("coat_camel")},
            ppm=96, ao_dist=0.3),
        kit("entrance_mosaic", [mosaic()], {"mosaic": _mosaic}, built_final=True, ground=None, ao_rays=0, ppm=96,
            preview_elevation=70.0),
    ]
