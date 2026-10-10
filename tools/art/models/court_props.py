"""Floor I: the Great Court's furniture (kit convention: origin = centre of
the base, front = Godot -Z; modelled facing the viewer at -Y and turned).

  court_bench       3 m double-sided bench: two Portland pedestals, oak
                    slats (no back), brass end caps.
  court_info_desk   round information desk (r 2.0, counter 1.05 high, a
                    staff gap at the back), oak and Portland, white marble
                    top, leaflet racks, a bell, and a lit sign box on a pole
                    "INFORMACJA" with a blue "i" on all four faces (marker
                    Light at the sign).
  cafe_counter      the café: a 4 m counter with a glass cake case
                    (cafe_counter_glass), an espresso machine, a till, cups,
                    and behind it a back bar with a chalkboard menu and the
                    "KAWIARNIA" board (4 x 2.9 x 2.1 m in all).
  cafe_table        round bistro table, marble top on a cast-iron foot.
  cafe_chair        bentwood café chair (faces -Z).
  shop_front        the museum shop, closed for the night: an 8 m stone
                    shopfront on the wall plane (z = 0, it projects 0.35 to
                    -Z), "SKLEP MUZEALNY" in gilt on green, the roller box
                    and the roll-down grille (part grille, origin at the
                    roller: lift it or squash it in Y to open), a
                    "ZAMKNIĘTE" plate hanging on it. Opening 7 x 3.4 m.
  court_plinth      exhibit plinth 1.2 x 1.0 x 1.2: Portland, verde top,
                    brass label plate on the front.
  court_lamp_post   4.6 m cast-iron lamp standard with three opal globes
                    (markers Light, Light_L, Light_R).
"""
import math

import numpy as np
from mathutils import Matrix, Vector

from artlib import court as C
from artlib import court_materials as CM
from artlib import arch_materials as A
from artlib import font
from artlib import materials as M
from artlib.archkit import cull_floor, kit
from artlib.geo import Part
from artlib.painter import Surface

CM.P.update({
    "shop_green": CM.hexramp("#03100a", "#061a10", "#0a2417", "#0f301f", "#153d28", "#1c4b32"),
    "chalk": CM.hexramp("#0b0f0d", "#121815", "#19211d", "#212b26", "#2a3530"),
    "info_blue": CM.hexramp("#04122e", "#071a42", "#0b2459", "#103071", "#173e8a", "#204ea3", "#2c5fba"),
})


def _lettered(base_fn, lines, ink_ramp, ink_shade, metal=0.0, glow=0.0, mirror_back=False):
    """``lines`` = [(text, baseline_v, px_texels, anchor_u)] written in the
    face's metre UVs over a base material."""
    def fn(ctx):
        s = base_fn(ctx)
        u, v = ctx.uvm[:, 0], ctx.uvm[:, 1]
        ink = np.zeros(ctx.N, dtype=bool)
        for text, base_v, px, cu in lines:
            ink |= font.text_mask(u, v, text, cu, base_v, px * ctx.texel)
        s.use_ramp(CM.P[ink_ramp], mask=ink, shade=np.full(ctx.N, ink_shade) + (ctx.rand(9) - 0.5) * 0.6)
        s.metal = np.where(ink, metal, s.metal)
        s.rough = np.where(ink, 0.3, s.rough)
        if glow > 0.0:
            emit = s.colors() * glow * 0.15
            emit[ink] = s.colors()[ink] * glow
            s.emit = emit
        return s
    return fn


# --------------------------------------------------------------------------

def bench():
    p = Part("court_bench")
    for sx in (-1, 1):
        p.box((sx * 1.05, 0, 0.19), (0.5, 0.5, 0.38), "portland", bevel=0.025)
        p.box((sx * 1.05, 0, 0.395), (0.56, 0.56, 0.03), "portland", bevel=0.01)
    for k in range(6):
        y = -0.25 + (k + 0.5) * 0.5 / 6
        p.box((0, y, 0.44), (3.0, 0.07, 0.05), "oak", bevel=0.008)
    for sx in (-1, 1):
        p.box((sx * 1.05, 0, 0.412), (0.5, 0.52, 0.006), "brass")
        p.box((sx * 1.49, 0, 0.44), (0.02, 0.5, 0.06), "brass", bevel=0.004)
    return p


# --------------------------------------------------------------------------

def info_desk():
    p = Part("court_info_desk")
    gap = math.radians(32.0)
    th0, th1 = math.pi + gap / 2, math.pi * 3 - gap / 2          # gap at the back (+Y before the turn)
    # (the front, after the kit turn, faces Godot -Z: the gap ends up behind)
    th0, th1 = gap / 2, math.tau - gap / 2
    R0, R1, H = 1.45, 2.0, 1.05
    secs = [([(R1 + 0.05, 0.0), (R1 + 0.05, 0.14), (R1, 0.14)], "portland"),
            ([(R1, 0.14), (R1, 0.9)], "oak_panel"),
            ([(R1, 0.9), (R1 + 0.04, 0.92), (R1 + 0.08, 0.98), (R1 + 0.08, H)], "oak"),
            ([(R1 + 0.08, H), (R1 + 0.08, H + 0.04), (R0 - 0.05, H + 0.04), (R0 - 0.05, H)], "marble"),
            ([(R0 - 0.05, H), (R0, H - 0.05), (R0, 0.0)], "oak_dark")]
    # theta measured from the north axis: the gap straddles theta = 0
    # (Blender +Y, the back after the turn)
    for prof, mat in secs:
        faces, _ = C.rev_strip(p, prof, th0, th1, 28, mat)
        C.orient_section(faces, (R0 + R1) / 2, 0.5)
    cap = [(R1 + 0.05, 0.0), (R1 + 0.05, 0.14), (R1 + 0.08, H + 0.04), (R0 - 0.05, H + 0.04), (R0, 0.0)]
    for th, sgn in ((th0, -1.0), (th1, 1.0)):
        f = p.poly([(r * math.sin(th), r * math.cos(th), z) for r, z in cap], "oak_dark")[0]
        f.normal_update()
        t = Vector((math.cos(th), -math.sin(th), 0.0)) * sgn
        if f.normal.dot(t) < 0:
            f.normal_flip()
    # leaflet racks on the counter (front half), a bell, a lamp
    for a in (-0.5, 0.0, 0.5):
        th = math.pi + a
        cx, cy = 1.72 * math.sin(th), 1.72 * math.cos(th)
        rack = p.box((0, 0, 0), (0.45, 0.16, 0.3), "rack", bevel=0.008)
        p.move(rack, Matrix.Translation((cx, cy, H + 0.19)) @ Matrix.Rotation(-th, 4, 'Z'))
    p.lathe([(0.0, H + 0.04), (0.05, H + 0.04), (0.05, H + 0.06), (0.04, H + 0.1), (0.015, H + 0.12), (0.0, H + 0.13)],
            "brass", segments=10, center=(0.6, -1.6, 0.0))
    # central pole and the lit sign box
    p.lathe([(0.25, 0.0), (0.25, 0.1), (0.08, 0.16), (0.06, 0.3), (0.06, 2.55)], "iron", segments=10, cap_bottom=False)
    sz = 2.95
    p.box((0, 0, sz), (1.1, 1.1, 0.66), "sign", bevel=0.02)
    p.box((0, 0, sz + 0.36), (1.18, 1.18, 0.06), "iron", bevel=0.01)
    p.box((0, 0, sz - 0.36), (1.18, 1.18, 0.06), "iron", bevel=0.01)
    return p, [("Light", (0.0, 0.0, sz), None)]


def _info_sign(ctx):
    """Four faces: blue disc with a white "i", the word INFORMACJA."""
    u, v = ctx.uvm[:, 0], ctx.uvm[:, 1]
    tx = ctx.texel
    s = Surface(ctx.N)
    side = np.maximum(np.abs(ctx.n[:, 0]), np.abs(ctx.n[:, 1])) > 0.9
    s.use_ramp(CM.P["enamel_cream"], shade=np.full(ctx.N, 6.8) + (ctx.rand(3) - 0.5) * 0.4)
    # along each face, centred: right = up x normal
    cu = ctx.p[:, 0] * (-ctx.n[:, 1]) + ctx.p[:, 1] * ctx.n[:, 0]
    vz = ctx.p[:, 2] - 2.95
    disc = (np.hypot(cu, vz - 0.1) < 0.14) & side
    ii = disc & (((np.abs(cu) < 0.022) & (vz > 0.0) & (vz < 0.15)) | (np.hypot(cu, vz - 0.19) < 0.025))
    s.use_ramp(CM.P["info_blue"], mask=disc & ~ii, shade=np.full(ctx.N, 4.5))
    word = font.text_mask(cu, vz, "INFORMACJA", 0.0, -0.21, 2 * tx) & side
    s.use_ramp(CM.P["info_blue"], mask=word, shade=np.full(ctx.N, 3.5))
    s.rough = np.full(ctx.N, 0.3)
    s.emit = s.colors() * np.where(side, 0.9, 0.0)[:, None]
    return s


def _oak_panel(ctx):
    """Oak panelling: a stile every 0.6 m (dark joint, lit arris)."""
    s = M.wood_oak(ctx)
    u = ctx.uvm[:, 0]
    d = np.mod(u, 0.6)
    s.shade = np.where(d < ctx.texel * 1.5, s.shade - 2.2, np.where(d < ctx.texel * 3.0, s.shade + 0.8, s.shade))
    return s


def _rack(ctx):
    s = M.brass(ctx)
    front = np.abs(ctx.n[:, 2]) < 0.6
    u, v = ctx.uvm[:, 0], ctx.uvm[:, 1]
    leaflet = front & (np.mod(u, 0.15) > 0.02) & (np.mod(v, 0.3) > 0.06)
    tone = np.floor(np.mod(u, 0.45) / 0.15).astype(np.int64)
    for k, ramp in enumerate(("enamel_cream", "info_blue", "cloth_red")):
        m = leaflet & (tone == k)
        s.use_ramp(CM.P[ramp], mask=m, shade=np.full(ctx.N, 5.0 if k == 0 else 4.0))
    s.metal = np.where(leaflet, 0.0, s.metal)
    return s


INFO_FNS = {"portland": CM.portland, "oak_panel": _oak_panel, "oak": M.wood_oak, "oak_dark": M.wood_dark,
            "marble": M.marble_white, "rack": _rack, "brass": M.brass, "iron": CM.cast_iron, "sign": _info_sign}


# --------------------------------------------------------------------------

def cafe_counter():
    p = Part("cafe_counter")
    g = Part("cafe_counter_glass")
    W, D, H = 4.0, 0.75, 1.0
    # front counter (front face at y = -0.4)
    p.box((0, 0, 0.06), (W, D - 0.06, 0.12), "marble_dark", bevel=0.01)
    p.box((0, 0, 0.55), (W - 0.04, D - 0.08, 0.86), "oak_panel", bevel=0.012)
    p.box((0, -0.02, H - 0.02), (W + 0.06, D + 0.04, 0.05), "marble", bevel=0.012)
    # the cake case: brass frame, glass, cakes on two shelves
    cx0, cx1 = -1.75, -0.35
    p.box(((cx0 + cx1) / 2, -0.05, H + 0.02), (cx1 - cx0, 0.5, 0.02), "brass")
    p.box(((cx0 + cx1) / 2, -0.05, H + 0.48), (cx1 - cx0, 0.5, 0.02), "brass")
    for x in (cx0, cx1):
        for y in (-0.29, 0.19):
            p.box((x, y, H + 0.25), (0.025, 0.025, 0.46), "brass")
    p.box(((cx0 + cx1) / 2, -0.05, H + 0.26), (cx1 - cx0 - 0.05, 0.45, 0.01), "glass_shelf")
    for k in range(4):
        x = cx0 + 0.22 + k * 0.33
        cake = p.lathe([(0.0, 0.0), (0.13, 0.0), (0.13, 0.09), (0.11, 0.1), (0.0, 0.1)], "cake", segments=10,
                       center=(x, -0.05, H + 0.035))
        tart = p.lathe([(0.0, 0.0), (0.1, 0.0), (0.1, 0.04), (0.0, 0.04)], "tart", segments=10,
                       center=(x + 0.05, -0.05, H + 0.275))
    for poly in ([(cx0, -0.3, H + 0.03), (cx1, -0.3, H + 0.03), (cx1, -0.3, H + 0.47), (cx0, -0.3, H + 0.47)],
                 [(cx0, -0.3, H + 0.47), (cx1, -0.3, H + 0.47), (cx1, 0.2, H + 0.47), (cx0, 0.2, H + 0.47)],
                 [(cx0, -0.3, H + 0.03), (cx0, 0.2, H + 0.03), (cx0, 0.2, H + 0.47), (cx0, -0.3, H + 0.47)],
                 [(cx1, -0.3, H + 0.03), (cx1, 0.2, H + 0.03), (cx1, 0.2, H + 0.47), (cx1, -0.3, H + 0.47)]):
        c = sum((Vector(q) for q in poly), Vector()) / 4
        for out in (True, False):
            f = g.poly(poly, "glass")[0]
            f.normal_update()
            mid = Vector(((cx0 + cx1) / 2, -0.05, H + 0.25))
            if (f.normal.dot(c - mid) > 0) != out:
                f.normal_flip()
    # espresso machine: a domed brass boiler with an eagle finial
    ex, ey = 0.65, 0.05
    p.box((ex, ey, H + 0.03), (0.6, 0.45, 0.05), "steel", bevel=0.01)
    p.lathe([(0.0, 0.0), (0.2, 0.0), (0.2, 0.42), (0.17, 0.5), (0.1, 0.56), (0.03, 0.6), (0.04, 0.66), (0.0, 0.7)],
            "brass", segments=14, center=(ex, ey + 0.05, H + 0.05))
    for x in (ex - 0.14, ex + 0.14):
        p.box((x, ey - 0.2, H + 0.3), (0.06, 0.12, 0.06), "steel", bevel=0.01)
        p.box((x, ey - 0.3, H + 0.27), (0.03, 0.18, 0.03), "leather", bevel=0.005)
    for k in range(5):
        p.lathe([(0.0, 0.0), (0.035, 0.0), (0.045, 0.06), (0.0, 0.06)], "porcelain", segments=8,
                center=(ex - 0.18 + k * 0.09, ey + 0.05, H + 0.73))
    # till
    p.box((1.55, 0.0, H + 0.13), (0.4, 0.35, 0.22), "brass", bevel=0.02)
    p.box((1.55, -0.08, H + 0.33), (0.3, 0.12, 0.18), "brass_dark", bevel=0.015)
    # back bar: shelves of cups and jars, the chalkboard menu, the name board
    by = 1.6
    p.box((0, by, 0.45), (W, 0.5, 0.9), "oak_panel", bevel=0.012)
    p.box((0, by - 0.02, 0.92), (W + 0.04, 0.56, 0.04), "marble", bevel=0.01)
    p.box((0, by + 0.22, 1.85), (W, 0.06, 1.85), "oak_dark", bevel=0.01)
    for z in (1.3, 1.62):
        p.box((-1.2, by + 0.08, z), (1.4, 0.24, 0.03), "oak", bevel=0.006)
        for k in range(7):
            p.lathe([(0.0, 0.0), (0.04, 0.0), (0.05, 0.1), (0.05, 0.16), (0.03, 0.18), (0.0, 0.18)], "jar",
                    segments=8, center=(-1.8 + k * 0.2, by + 0.08, z + 0.015))
    p.box((0.8, by + 0.17, 1.75), (2.1, 0.04, 1.3), "menu", bevel=0.02)
    p.box((0, by + 0.15, 2.72), (W, 0.12, 0.36), "name", bevel=0.02)
    return [p, g]


MENU = [("MENU", 2.25, 3), ("KAWA  12 ZŁ", 2.0, 2), ("HERBATA  9 ZŁ", 1.82, 2), ("CZEKOLADA  14 ZŁ", 1.64, 2),
        ("CIASTO DNIA  16 ZŁ", 1.46, 2), ("ZAMKNIĘTE DO 9:00", 1.2, 2)]


def _menu(ctx):
    u, v = ctx.uvm[:, 0], ctx.uvm[:, 1]
    s = Surface(ctx.N)
    s.use_ramp(CM.P["chalk"], shade=2.0 + ctx.fbm(4.0, 3, 3) * 1.2 + (ctx.rand(4) - 0.5) * 0.6)
    front = ctx.n[:, 1] > 0.5           # after the kit turn the board faces +Y (Godot -Z)
    ink = np.zeros(ctx.N, dtype=bool)
    for text, base_v, px in MENU:
        ink |= font.text_mask(u, v, text, 0.8, base_v, px * ctx.texel)
    smudge = (ctx.fbm(3.0, 2, 7) > 0.55) & front & (ctx.rand(8) > 0.5)
    s.use_ramp(CM.P["enamel_cream"], mask=(ink & front) | smudge, shade=np.where(ink, 6.0, 1.5) + (ctx.rand(5) - 0.5))
    frame = ctx.edge_soft(4.0) > 0.2
    s.use_ramp(CM.P["wood_oak"], mask=frame, shade=np.full(ctx.N, 5.0))
    s.rough = np.full(ctx.N, 0.9)
    return s


def _name_board(ctx):
    base = lambda c: A.paint(c, "shop_green", 3.8, rough=0.3) if False else _green(c)
    return _lettered(base, [("KAWIARNIA", 2.72 - 0.09, 4, 0.0)], "gold", 6.5, metal=1.0)(ctx)


def _green(ctx):
    s = Surface(ctx.N)
    s.use_ramp(CM.P["shop_green"], shade=3.6 + ctx.fbm(3.0, 2, 3) * 0.6 + (ctx.rand(4) - 0.5) * 0.5
               + ctx.edge(1.0) * 1.5)
    s.rough = np.full(ctx.N, 0.35)
    return s


def _cake(ctx):
    s = Surface(ctx.N)
    top = ctx.n[:, 2] > 0.7
    s.use_ramp(CM.P["wax"], shade=7.0 + (ctx.rand(3) - 0.5) * 1.0)
    s.use_ramp(CM.P["wood_oak"], mask=~top & (np.mod(ctx.p[:, 2] * 40.0, 1.0) > 0.5), shade=np.full(ctx.N, 3.5))
    cherry = top & (ctx.rand(5) > 0.93)
    s.use_ramp(CM.P["cloth_red"], mask=cherry, shade=np.full(ctx.N, 5.0))
    s.rough = np.full(ctx.N, 0.5)
    return s


def _tart(ctx):
    s = Surface(ctx.N)
    top = ctx.n[:, 2] > 0.7
    s.use_ramp(CM.P["paint_ochre"], shade=5.0 + (ctx.rand(3) - 0.5))
    berry = top & (ctx.rand(6) > 0.6)
    s.use_ramp(CM.P["book_red"] if "book_red" in CM.P else CM.P["cloth_red"], mask=berry, shade=np.full(ctx.N, 4.0))
    s.rough = np.full(ctx.N, 0.4)
    return s


def _jar(ctx):
    s = Surface(ctx.N)
    s.use_ramp(CM.P["glass"], shade=1.5 + (ctx.rand(3) - 0.5))
    beans = ctx.p[:, 2] % 0.32 < 0.12
    s.use_ramp(CM.P["hide"], mask=beans, shade=np.full(ctx.N, 2.0) + (ctx.rand(4) - 0.5) * 2.0)
    s.rough = np.full(ctx.N, 0.15)
    return s


def _glass_shelf(ctx):
    s = Surface(ctx.N)
    s.use_ramp(CM.P["glass"], shade=np.full(ctx.N, 2.0))
    s.rough = np.full(ctx.N, 0.05)
    return s


def _brass_dark(ctx):
    s = M.brass(ctx)
    s.shade -= 1.5
    return s


CAFE_FNS = {"marble_dark": M.marble_dark, "oak_panel": _oak_panel, "marble": M.marble_white, "brass": M.brass,
            "steel": M.steel, "leather": M.leather, "porcelain": M.porcelain, "brass_dark": _brass_dark,
            "oak": M.wood_oak, "oak_dark": M.wood_dark, "jar": _jar, "menu": _menu, "name": _name_board,
            "cake": _cake, "tart": _tart, "glass_shelf": _glass_shelf}


def cafe_table():
    p = Part("cafe_table")
    p.lathe([(0.0, 0.0), (0.28, 0.0), (0.28, 0.03), (0.12, 0.06), (0.06, 0.12), (0.035, 0.2), (0.03, 0.66),
             (0.06, 0.7), (0.06, 0.72), (0.0, 0.72)], "iron", segments=12)
    p.lathe([(0.0, 0.72), (0.36, 0.72), (0.37, 0.735), (0.36, 0.75), (0.0, 0.75)], "marble", segments=20)
    return p


def cafe_chair():
    p = Part("cafe_chair")
    p.lathe([(0.0, 0.44), (0.21, 0.44), (0.22, 0.46), (0.21, 0.48), (0.0, 0.48)], "seat", segments=14)
    p.tube([(0.2 * math.cos(a), 0.2 * math.sin(a), 0.42) for a in np.linspace(0, math.tau, 15)], 0.015, "wood",
           sides=5, caps=False)
    for k in range(4):
        a = math.radians(45 + 90 * k)
        top = (0.17 * math.cos(a), 0.17 * math.sin(a), 0.44)
        foot = (0.24 * math.cos(a), 0.24 * math.sin(a), 0.0)
        p.tube([foot, ((top[0] + foot[0]) / 2 * 0.98, (top[1] + foot[1]) / 2 * 0.98, 0.22), top], 0.016, "wood",
               sides=5)
    # bentwood back: a hoop from the rear legs
    back = []
    for t in np.linspace(0, 1, 11):
        a = math.radians(45 + 90 * t)
        back.append((0.19 * math.cos(a), 0.19 * math.sin(a) + 0.02, 0.46 + 0.45 * math.sin(t * math.pi)))
    p.tube(back, 0.016, "wood", sides=5)
    inner = []
    for t in np.linspace(0.2, 0.8, 7):
        a = math.radians(45 + 90 * t)
        inner.append((0.17 * math.cos(a), 0.17 * math.sin(a) + 0.02, 0.5 + 0.28 * math.sin((t - 0.2) / 0.6 * math.pi)))
    p.tube(inner, 0.012, "wood", sides=4)
    return p


def _bentwood(ctx):
    s = M.wood_dark(ctx)
    s.shade += 0.8
    return s


# --------------------------------------------------------------------------

SHOP_W, SHOP_OH, SHOP_OW = 8.0, 3.4, 7.0


def shop_front():
    p = Part("shop_front")
    gr = Part("grille", origin=(0.0, -0.18, SHOP_OH + 0.25))
    hw, ow = SHOP_W / 2, SHOP_OW / 2
    # stone surround: pilasters, fascia with the sign, cornice
    for sx in (-1, 1):
        x = sx * (ow + (hw - ow) / 2)
        p.box((x, -0.15, (SHOP_OH + 0.9) / 2), (hw - ow, 0.3, SHOP_OH + 0.9), "portland", bevel=0.02)
        p.box((x, -0.17, 0.2), (hw - ow + 0.06, 0.34, 0.4), "plinth", bevel=0.015)
        p.box((x, -0.2, SHOP_OH + 0.05), (hw - ow + 0.08, 0.4, 0.14), "portland", bevel=0.02)
    p.box((0, -0.12, SHOP_OH + 0.6), (SHOP_W, 0.24, 0.9), "portland", bevel=0.02)
    p.box((0, -0.25, SHOP_OH + 0.62), (SHOP_W - 1.4, 0.04, 0.62), "fascia", bevel=0.01)
    p.extrude([(0.0, SHOP_OH + 1.05), (-0.3, SHOP_OH + 1.05), (-0.36, SHOP_OH + 1.1), (-0.4, SHOP_OH + 1.18),
               (-0.4, SHOP_OH + 1.24), (0.0, SHOP_OH + 1.26)], -hw - 0.1, hw + 0.1, "portland", caps=True)
    # roller box under the fascia and the guide channels
    p.box((0, -0.2, SHOP_OH + 0.2), (SHOP_OW + 0.2, 0.36, 0.3), "steel_grey", bevel=0.02)
    for sx in (-1, 1):
        p.box((sx * (ow + 0.03), -0.17, SHOP_OH / 2), (0.08, 0.1, SHOP_OH), "steel_grey", bevel=0.01)
    # the grille: slatted curtain, bottom bar with a lock, the hanging plate
    C.front(gr, -SHOP_OW / 2, SHOP_OW / 2, 0.1, SHOP_OH, "curtain", y=-0.18)
    gr.box((0, -0.18, 0.06), (SHOP_OW, 0.08, 0.1), "steel_grey", bevel=0.015)
    for sx in (-1, 1):
        gr.box((sx * 1.2, -0.23, 0.12), (0.12, 0.04, 0.16), "steel_grey", bevel=0.01)
    gr.box((0.0, -0.215, 1.55), (0.6, 0.012, 0.22), "plate", bevel=0.004)
    for sx in (-1, 1):
        gr.tube([(sx * 0.2, -0.21, 1.66), (0.0, -0.2, 1.85), ], 0.006, "steel_grey", sides=4)
    for part in (p, gr):
        C.drop_back_faces(part)
    return [p, gr]


def _curtain(ctx):
    """Galvanised roller slats (0.1 m) with rows of slots, a little rust."""
    u, v = ctx.uvm[:, 0], ctx.uvm[:, 1]
    tx = ctx.texel
    s = Surface(ctx.N)
    dv = np.mod(v, 0.1)
    s.use_ramp(CM.P["steel"], shade=6.2 + np.where(dv < 0.05, 0.6, -0.4) + ctx.fbm(1.0, 3, 3) * 0.8
               + (ctx.rand(4) - 0.5) * 0.6)
    joint = dv < tx
    slot = (np.abs(dv - 0.06) < 1.5 * tx) & (np.mod(u, 0.2) < 0.14)
    s.use_ramp(CM.P["iron"], mask=joint | slot, shade=np.where(slot, 0.5, 2.0))
    rust = (ctx.fbm(3.0, 3, 6) > 0.45) & (v < 0.8)
    s.use_ramp(CM.P["rust"], mask=rust & ~slot, shade=np.full(ctx.N, 1.5) + (ctx.rand(7) - 0.5))
    s.metal = np.where(rust | slot, 0.0, 0.8)
    s.rough = np.where(rust, 0.85, 0.35)
    s.height = np.where(dv < 0.05, 0.002, 0.0) - slot * 0.003
    return s


def _shop_fascia(ctx):
    return _lettered(_green, [("SKLEP MUZEALNY", SHOP_OH + 0.62 - 0.1, 4, 0.0)], "gold", 6.8, metal=1.0)(ctx)


def _closed_plate(ctx):
    return _lettered(lambda c: CM.cast_iron(c, center=1.5) if False else _enamel(c),
                     [("ZAMKNIĘTE", 1.55 - 0.05, 3, 0.0)], "cloth_red", 5.0)(ctx)


def _enamel(ctx):
    s = Surface(ctx.N)
    s.use_ramp(CM.P["enamel_white"], shade=6.2 + (ctx.rand(3) - 0.5) * 0.5)
    s.rough = np.full(ctx.N, 0.25)
    return s


def _steel_grey(ctx):
    return CM.court_steel(ctx, center=5.0)


SHOP_FNS = {"portland": CM.portland, "plinth": M.marble_dark, "fascia": _shop_fascia, "steel_grey": _steel_grey,
            "curtain": _curtain, "plate": _closed_plate}


# --------------------------------------------------------------------------

def plinth():
    p = Part("court_plinth")
    p.box((0, 0, 0.06), (1.24, 1.24, 0.12), "marble_dark", bevel=0.012)
    p.box((0, 0, 0.5), (1.1, 1.1, 0.8), "portland", bevel=0.02)
    p.box((0, 0, 0.93), (1.2, 1.2, 0.06), "portland", bevel=0.015)
    p.box((0, 0, 0.98), (1.14, 1.14, 0.04), "marble_dark", bevel=0.01)
    p.box((0, -0.556, 0.62), (0.4, 0.012, 0.16), "brass_plate", bevel=0.003)
    return p


def _plinth_plate(ctx):
    s = M.brass(ctx)
    s.shade += 0.6
    return s


# --------------------------------------------------------------------------

def lamp_post():
    p = Part("court_lamp_post")
    # base, fluted column, collar, cross-arm, globes
    p.lathe([(0.0, 0.0), (0.34, 0.0), (0.34, 0.1), (0.28, 0.16), (0.28, 0.5), (0.22, 0.58), (0.16, 0.66),
             (0.12, 0.8)], "iron", segments=12, cap_top=False)
    p.lathe([(0.12, 0.8), (0.095, 3.2)], "iron", segments=16, cap_bottom=False, cap_top=False, smooth=False,
            ring_scale=lambda i, j: 1.0 if i % 2 == 0 else 0.85)
    p.lathe([(0.095, 3.2), (0.14, 3.28), (0.14, 3.36), (0.08, 3.44), (0.07, 3.7)], "iron", segments=12,
            cap_bottom=False, cap_top=False)
    markers = []
    for sx, name in ((-1, "Light_L"), (1, "Light_R")):
        arm = [(0.0, 0.0, 3.5), (sx * 0.3, 0.0, 3.62), (sx * 0.55, 0.0, 3.58), (sx * 0.62, 0.0, 3.5)]
        p.tube(arm, 0.03, "iron", sides=6)
        p.tube([(sx * 0.1, 0.0, 3.3), (sx * 0.3, 0.0, 3.4), (sx * 0.45, 0.0, 3.52)], 0.018, "iron", sides=5)
        cx = sx * 0.62
        p.lathe([(0.0, 3.44), (0.07, 3.44), (0.09, 3.5), (0.05, 3.52)], "iron", segments=10, center=(cx, 0, 0),
                cap_top=False)
        p.lathe([(0.05, 3.52), (0.12, 3.58), (0.17, 3.7), (0.17, 3.8), (0.12, 3.92), (0.05, 3.96), (0.0, 3.97)],
                "globe", segments=14, center=(cx, 0, 0), cap_bottom=False)
        markers.append((name, (cx, 0.0, 3.74), None))
    p.lathe([(0.07, 3.7), (0.1, 3.9), (0.08, 4.0)], "iron", segments=10, cap_bottom=False, cap_top=False)
    p.lathe([(0.08, 4.0), (0.16, 4.08), (0.21, 4.22), (0.21, 4.34), (0.15, 4.48), (0.06, 4.53), (0.0, 4.54)], "globe",
            segments=16, cap_bottom=False)
    p.lathe([(0.0, 4.53), (0.05, 4.53), (0.03, 4.6), (0.0, 4.62)], "iron", segments=8)
    markers.append(("Light", (0.0, 0.0, 4.28), None))
    return p, markers


def _globe(ctx):
    return M.glow(ctx, "lamp_warm", 4.6, strength=1.0, rough=0.15)


def build():
    desk_part, desk_markers = info_desk()
    lamp, lamp_markers = lamp_post()
    counter = cafe_counter()
    cull_floor([desk_part, lamp] + counter)
    return [
        kit("court_bench", [bench()], {"portland": CM.portland, "oak": M.wood_oak, "brass": M.brass}, ppm=128,
            ao_dist=0.25),
        kit("court_info_desk", [desk_part], INFO_FNS, ppm=128, ao_dist=0.3, markers=desk_markers,
            preview_extra=[("sign", (0.0, 0.0, 2.9), 0.9, 20.0, 10.0)]),
        kit("cafe_counter", counter, CAFE_FNS, kinds={"glass": "glass"}, ppm=96, ao_dist=0.3,
            preview_extra=[("bar", (0.0, 0.5, 1.4), 1.8, 15.0, 12.0)]),
        kit("cafe_table", [cafe_table()], {"iron": CM.cast_iron, "marble": M.marble_white}, ppm=160, ao_dist=0.2,
            preview=False),
        kit("cafe_chair", [cafe_chair()], {"seat": M.wood_dark, "wood": _bentwood}, ppm=160, ao_dist=0.15),
        kit("shop_front", shop_front(), SHOP_FNS, ppm=96, ao_dist=0.3, wall=True,
            preview_extra=[("sign", (0.0, 0.0, 3.9), 2.0, 10.0, 8.0)]),
        kit("court_plinth", [plinth()], {"marble_dark": M.marble_dark, "portland": CM.portland,
                                         "brass_plate": _plinth_plate}, ppm=128, ao_dist=0.25, preview=False),
        kit("court_lamp_post", [lamp], {"iron": CM.cast_iron, "globe": _globe}, ppm=160, ao_dist=0.2,
            markers=lamp_markers),
    ]
