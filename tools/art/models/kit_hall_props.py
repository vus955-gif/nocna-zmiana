"""Lobby kit, main hall: furniture and fittings with real Polish lettering.

All in the kit convention (origin = centre of the base, front = Godot -Z).

  trex_pedestal   the T-Rex plinth (kit id "pedestal" in the hall, 12 x 1.2 x
                  6 m): verde toe, moulded limestone base, panelled dado,
                  cap moulding, polished verde top the skeleton stands on.
  plaque_trex     brass plaque "Tyrannosaurus rex / późna kreda · 68–66 mln
                  lat temu", 1.6 x 0.42 m; origin = back centre on the face
                  it is screwed to. Two go on the pedestal (front and back).
  ticket_booth    walnut and glass kiosk (4.5 x 2.8 x 3.5) with a "KASA"
                  sign in gold on black glass, counter slab, speaking grille,
                  cash slot, a desk, till and lamp inside. Parts: body,
                  ticket_booth_glass, drawer (slides out along -Z; the
                  "ticket_drawer" marker sits on it). Marker "Light" = lamp.
  info_desk       stadium-shaped reception island (8 x 1.1 x 3): walnut
                  panelled front, verde plinth, white marble top, a double
                  sign "INFORMACJA" on a brass post, a bell and a lamp.
  bench_hall      3 m oak bench with a buttoned black leather top.
  fuse_box        wall cabinet (0.7 x 0.9 x 0.3) with a wired window onto
                  two porcelain fuse sockets (markers Fuse_A / Fuse_B), a
                  warning triangle, a "BEZPIECZNIKI" plate and a big knife-
                  switch lever on the right side. Parts: fuse_box, lever
                  (pivot on its axle, turns about X: +45 deg up = on),
                  lamp_red, lamp_green (show one).
"""
import math

import numpy as np
from mathutils import Matrix

from artlib import arch_materials as A
from artlib import font
from artlib import materials as M
from artlib.archkit import cull_floor, front_prism, kit, plan_sweep
from artlib.geo import Part


def _lettered(base_fn, lines, ink_ramp="leather", ink_shade=1.0, metal_ink=0.0, rough_ink=0.6, glow=0.0):
    """Wraps a material: ``lines`` = [(text, baseline_v, px, anchor_u, align)]
    written in the face's metre UVs in the ink ramp."""
    def fn(ctx):
        s = base_fn(ctx)
        u, v = ctx.uvm[:, 0], ctx.uvm[:, 1]
        ink = np.zeros(ctx.N, dtype=bool)
        for text, base_v, px, cu, align in lines:
            ink |= font.text_mask(u, v, text, cu, base_v, px, align=align)
        s.use_ramp(A.P[ink_ramp], mask=ink, shade=np.full(ctx.N, ink_shade))
        s.metal = np.where(ink, metal_ink, s.metal)
        s.rough = np.where(ink, rough_ink, s.rough)
        if glow > 0.0:
            emit = np.zeros((ctx.N, 3))
            emit[ink] = s.colors()[ink] * glow
            s.emit = emit
        return s
    return fn


# --- T-Rex pedestal ---------------------------------------------------------

def pedestal():
    p = Part("trex_pedestal")
    X, Y = 12.0, 6.0
    hx, hy = X / 2, Y / 2
    path = [(-hx, -hy), (-hx, hy), (hx, hy), (hx, -hy)]
    # verde toe, limestone base mouldings, dado, cap (height, outward offset)
    plan_sweep(p, [(0.0, 0.12), (0.14, 0.12), (0.16, 0.1), (0.16, 0.08)], path, "marble_dark")
    plan_sweep(p, [(0.16, 0.08), (0.22, 0.08), (0.24, 0.06), (0.3, 0.05), (0.32, 0.02), (0.34, 0.0),
                   (0.94, 0.0), (0.97, 0.02), (1.0, 0.03), (1.03, 0.07), (1.08, 0.08), (1.12, 0.08),
                   (1.14, 0.06)], path, "limestone")
    plan_sweep(p, [(1.14, 0.06), (1.2, 0.0)], path, "marble_dark")
    top = p.poly([(-hx, -hy, 1.2), (hx, -hy, 1.2), (hx, hy, 1.2), (-hx, hy, 1.2)], "marble_dark")[0]
    top.normal_update()
    if top.normal.z < 0:
        top.normal_flip()
    # raised panels: three on each long face, one on each end
    for sy in (-1, 1):
        for x in (-3.9, 0.0, 3.9):
            p.box((x, sy * (hy + 0.01), 0.64), (3.5, 0.04, 0.42), "panel", bevel=0.02)
    for sx in (-1, 1):
        p.box((sx * (hx + 0.01), 0, 0.64), (0.04, 5.4, 0.42), "panel", bevel=0.02)
    # mounting plates under the skeleton's feet and supports
    for x, y in ((0.3, -0.9), (0.3, 0.9), (-2.0, 0.0), (1.8, 0.0)):
        p.box((x, y, 1.205), (0.5, 0.4, 0.01), "brass", bevel=0.003)
    return p


def plaque():
    p = Part("plaque_trex")
    p.box((0, -0.008, 0), (1.6, 0.016, 0.42), "plaque", bevel=0.004)
    for sx in (-1, 1):
        for sz in (-1, 1):
            screw = p.lathe([(0.0, 0.0), (0.012, 0.0), (0.012, 0.003), (0.0, 0.005)], "brass", segments=8)
            # built along +Z: stand it out of the plate toward the viewer (-Y)
            p.move(screw, Matrix.Translation((sx * 0.75, -0.016, sz * 0.17)) @ Matrix.Rotation(math.radians(90), 4, 'X'))
    return p


def _plaque_face(ctx):
    s = M.brass(ctx)
    s.shade += 0.8
    return s


PLAQUE_LINES = [("Tyrannosaurus rex", 0.0, 3.0 / 256, 0.0, "center"),
                ("późna kreda · 68–66 mln lat temu", -0.13, 2.0 / 256, 0.0, "center")]


# --- ticket booth -------------------------------------------------------------

BW, BD, BH = 4.5, 3.5, 2.8


def booth():
    p = Part("ticket_booth")
    g = Part("ticket_booth_glass")
    hw, hd = BW / 2, BD / 2
    fw, fd = hw - 0.1, hd - 0.2          # body faces (front at -fd, counter in front of it)
    p.box((0, 0.1, 0.06), (BW - 0.16, BD - 0.36, 0.12), "marble_dark", bevel=0.012)
    p.box((0, 0.1, 0.58), (2 * fw, 2 * fd, 0.92), "wood", bevel=0.015)
    # raised panels: front 3, back 2 + door, sides 2
    for x in (-1.35, 0.0, 1.35):
        p.box((x, -fd - 0.012 + 0.1, 0.56), (1.1, 0.024, 0.62), "wood", bevel=0.022)
    for y in (-0.55, 0.75):
        for sx in (-1, 1):
            p.box((sx * (fw + 0.012), y, 0.56), (0.024, 1.1, 0.62), "wood", bevel=0.022)
    # counter slab across the front (inside the kit box) and its brackets
    p.box((0, -hd + 0.2, 1.06), (BW - 0.3, 0.44, 0.06), "marble", bevel=0.012)
    for x in (-1.6, -0.55, 0.55, 1.6):
        p.box((x, -hd + 0.14, 0.97), (0.05, 0.2, 0.12), "brass", bevel=0.006)
    # glazed upper: corner posts, mullions, transom, sill
    z0, z1 = 1.1, 2.4
    for sx in (-1, 1):
        for sy in (-1, 1):
            p.box((sx * (fw - 0.05), 0.1 + sy * (fd - 0.05), (z0 + z1) / 2), (0.12, 0.12, z1 - z0), "wood",
                  bevel=0.012)
    front_y = 0.1 - fd + 0.04
    back_y = 0.1 + fd - 0.04
    for x in (-1.05, 0.0, 1.05):
        p.box((x, front_y, (z0 + z1) / 2), (0.07, 0.08, z1 - z0), "wood", bevel=0.01)
    for y in (-0.55, 0.55):
        for sx in (-1, 1):
            p.box((sx * (fw - 0.04), 0.1 + y, (z0 + z1) / 2), (0.08, 0.07, z1 - z0), "wood", bevel=0.01)
    for x in (-0.7, 0.7):
        p.box((x, back_y, (z0 + z1) / 2), (0.07, 0.08, z1 - z0), "wood", bevel=0.01)
    for sy, y in ((-1, front_y), (1, back_y)):
        p.box((0, y, 2.1), (2 * fw, 0.08, 0.06), "wood", bevel=0.01)
        p.box((0, y, z0 + 0.03), (2 * fw, 0.1, 0.06), "wood", bevel=0.01)
    for sx in (-1, 1):
        p.box((sx * (fw - 0.04), 0.1, 2.1), (0.08, 2 * fd, 0.06), "wood", bevel=0.01)
        p.box((sx * (fw - 0.04), 0.1, z0 + 0.03), (0.1, 2 * fd, 0.06), "wood", bevel=0.01)
    # speaking grille and cash slot in the front middle bay
    grille = p.lathe([(0.0, 0.0), (0.09, 0.0), (0.1, 0.008), (0.09, 0.016), (0.0, 0.018)], "brass", segments=12)
    p.move(grille, Matrix.Translation((0.52, front_y - 0.01, 1.62)) @ Matrix.Rotation(math.radians(90), 4, 'X'))
    p.box((0.0, front_y - 0.01, 1.2), (0.55, 0.03, 0.03), "brass", bevel=0.005)
    # frieze all round with the KASA sign in front, cornice and roof
    p.box((0, 0.1, 2.51), (2 * fw + 0.02, 2 * fd + 0.02, 0.22), "wood", bevel=0.012)
    p.box((0, 0.1 - fd - 0.02, 2.51), (1.2, 0.03, 0.2), "sign", bevel=0.006)
    p.box((0, 0.1, 2.66), (2 * fw + 0.16, 2 * fd + 0.16, 0.08), "wood", bevel=0.02)
    p.box((0, 0.1, 2.74), (BW - 0.02, BD - 0.02 - 0.2, 0.08), "wood", bevel=0.025)
    p.box((0, 0.1, 2.785), (BW - 0.5, BD - 0.7, 0.03), "wood", bevel=0.01)
    # inside: back desk, till, stool, lamp
    p.box((0, back_y - 0.35, 0.8), (2.4, 0.5, 0.05), "wood", bevel=0.01)
    p.box((-0.6, back_y - 0.35, 0.95), (0.35, 0.3, 0.25), "brass", bevel=0.02)
    p.box((0.6, back_y - 0.35, 0.88), (0.3, 0.22, 0.12), "wood", bevel=0.01)
    p.lathe([(0.0, 0.0), (0.18, 0.0), (0.18, 0.05), (0.03, 0.06), (0.03, 0.62), (0.2, 0.64), (0.2, 0.68),
             (0.0, 0.69)], "wood", segments=10, center=(0.3, 0.2, 0.0))
    p.lathe([(0.0, 0.0), (0.06, 0.0), (0.02, 0.03), (0.02, 0.3), (0.12, 0.34), (0.14, 0.42), (0.0, 0.43)],
            "lamp_warm", segments=10, center=(0.9, back_y - 0.35, 0.825))
    # door at the back (left bay), with a knob
    p.box((-1.4, back_y + 0.01, 1.3), (0.8, 0.04, 2.1), "wood", bevel=0.02)
    p.box((-1.08, back_y + 0.05, 1.1), (0.05, 0.05, 0.05), "brass", bevel=0.01)
    # glass panes: front 4 bays, back 3, sides 2 x 2
    e = 0.01
    zz0, zz1 = z0 + 0.06, 2.07

    def pane(x0, x1, y0, y1, want):
        pts = [(x0, y0, zz0), (x1, y1, zz0), (x1, y1, zz1), (x0, y0, zz1)]
        f = g.poly(pts, "glass")[0]
        f.normal_update()
        if f.normal.dot(want) < 0:
            f.normal_flip()

    xs = [-fw + 0.11, -1.05, 0.0, 1.05, fw - 0.11]
    for a, b in zip(xs[:-1], xs[1:]):
        pane(a + e, b - e, front_y, front_y, (0, -1, 0))
    xb = [-fw + 0.11, -0.7, 0.7, fw - 0.11]
    for a, b in zip(xb[1:-1], xb[2:]):
        pane(a + e, b - e, back_y, back_y, (0, 1, 0))
    ys = [0.1 - fd + 0.11, 0.1 - 0.55, 0.1 + 0.55, 0.1 + fd - 0.11]
    for sx in (-1, 1):
        for a, b in zip(ys[:-1], ys[1:]):
            pane(sx * (fw - 0.04), sx * (fw - 0.04), a + e, b - e, (sx, 0, 0))
    # the ticket drawer under the counter (own part: it slides out)
    d = Part("drawer", origin=(0.0, -fd + 0.1, 0.9))
    d.box((0.0, -fd + 0.1 - 0.012, 0.9), (0.62, 0.024, 0.16), "wood", bevel=0.01)
    d.box((0.0, -fd + 0.1 - 0.035, 0.9), (0.12, 0.025, 0.025), "brass", bevel=0.006)
    d.box((0.0, -fd + 0.1 + 0.2, 0.86), (0.56, 0.4, 0.1), "wood", bevel=0.005)
    return [p, g, d]


def _kasa(ctx):
    s = A.Surface(ctx.N)
    s.use_ramp(A.P["leather"], shade=1.0 + ctx.fbm(10.0, 2, 3) * 0.3)
    s.rough = np.full(ctx.N, 0.12)
    return s


# --- information desk ---------------------------------------------------------

def _stadium(half, r, n=12, grow=0.0):
    pts = []
    for i in range(n + 1):
        a = -math.pi / 2 + math.pi * i / n
        pts.append((half + (r + grow) * math.cos(a), (r + grow) * math.sin(a)))
    for i in range(n + 1):
        a = math.pi / 2 + math.pi * i / n
        pts.append((-half + (r + grow) * math.cos(a), (r + grow) * math.sin(a)))
    return pts


def info_desk():
    p = Part("info_desk")
    half, r = 2.5, 1.42
    # mouldings swept round the stadium outline (clockwise from above), so
    # no hidden prism tops and bottoms fill the atlas
    path = list(reversed(_stadium(half, r)))
    plan_sweep(p, [(0.0, -0.04), (0.11, -0.04), (0.12, -0.03), (0.12, 0.0)], path, "marble_dark")
    plan_sweep(p, [(0.12, 0.0), (0.94, 0.0), (0.955, 0.02), (0.97, 0.03), (1.0, 0.03)], path, "wood")
    plan_sweep(p, [(1.0, 0.03), (1.0, 0.06), (1.02, 0.08), (1.08, 0.08), (1.1, 0.06), (1.1, 0.0)], path, "marble")
    top = p.poly([(x, y, 1.1) for x, y in _stadium(half, r)], "marble")[0]
    top.normal_update()
    if top.normal.z < 0:
        top.normal_flip()
    # pilaster strips around the front
    for x in np.linspace(-half, half, 7):
        for sy in (-1, 1):
            p.box((x, sy * (r + 0.012), 0.54), (0.1, 0.024, 0.8), "wood", bevel=0.01)
    for sx in (-1, 1):
        for a in np.linspace(-60, 60, 5):
            ang = math.radians(a)
            b = p.box((0, 0, 0), (0.024, 0.1, 0.8), "wood", bevel=0.01)
            p.move(b, Matrix.Translation((sx * (half + (r + 0.012) * math.cos(ang)), (r + 0.012) * math.sin(ang),
                                          0.54)) @ Matrix.Rotation(ang if sx > 0 else -ang, 4, 'Z'))
    # sign on a brass post in the middle, bell, lamp
    p.lathe([(0.0, 0.0), (0.12, 0.0), (0.12, 0.03), (0.03, 0.05), (0.025, 0.55), (0.0, 0.56)], "brass",
            segments=10, center=(0.0, 0.0, 1.1))
    p.box((0.0, 0.0, 1.78), (1.08, 0.04, 0.26), "sign", bevel=0.008)
    p.box((0.0, 0.0, 1.78), (1.12, 0.03, 0.3), "brass", bevel=0.008)
    p.lathe([(0.0, 0.0), (0.06, 0.0), (0.065, 0.01), (0.05, 0.05), (0.03, 0.07), (0.0, 0.075)], "brass",
            segments=10, center=(1.4, -0.6, 1.1))
    p.lathe([(0.0, 0.0), (0.08, 0.0), (0.02, 0.03), (0.015, 0.34), (0.0, 0.35)], "brass", segments=8,
            center=(-1.6, 0.5, 1.1))
    p.lathe([(0.0, 0.3), (0.1, 0.3), (0.16, 0.36), (0.17, 0.4), (0.0, 0.42)], "shade", segments=10,
            center=(-1.6, 0.5, 1.1))
    return p


def _green_shade(ctx):
    return A.paint(ctx, "enamel_green", 4.5, rough=0.25)


# --- bench ------------------------------------------------------------------------

def bench():
    p = Part("bench_hall")
    L, D = 3.0, 0.7
    for x in (-1.3, 0.0, 1.3):
        for sy in (-1, 1):
            p.lathe([(0.0, 0.0), (0.04, 0.0), (0.035, 0.03), (0.03, 0.1), (0.04, 0.2), (0.032, 0.3),
                     (0.035, 0.36), (0.04, 0.37), (0.0, 0.37)], "oak", segments=8,
                    center=(x, sy * (D / 2 - 0.07), 0.0))
        p.box((x, 0, 0.12), (0.05, D - 0.14, 0.05), "oak", bevel=0.008)
    p.box((0, 0, 0.12), (L - 0.3, 0.05, 0.05), "oak", bevel=0.008)
    p.box((0, 0, 0.395), (L, D, 0.05), "oak", bevel=0.012)
    top = p.box((0, 0, 0.46), (L - 0.08, D - 0.08, 0.08), "leather", bevel=0.03)
    # buttons: a grid of tiny bosses on the cushion
    for x in np.linspace(-1.3, 1.3, 9):
        for y in (-0.15, 0.15):
            p.box((x, y, 0.502), (0.02, 0.02, 0.006), "leather", bevel=0.003)
    return p


def _button_leather(ctx):
    s = M.leather(ctx)
    x = ctx.p[:, 0]
    y = ctx.p[:, 1]
    gx = np.mod(x + 1.3 + 0.1625, 0.325) - 0.1625
    gy = np.minimum(np.abs(y - 0.15), np.abs(y + 0.15))
    pit = np.hypot(gx, gy)
    s.shade -= np.clip(1.0 - pit / 0.06, 0.0, 1.0) * 1.5
    return s


# --- fuse box -----------------------------------------------------------------

def fuse_box():
    body = Part("fuse_box")
    W, H, D = 0.7, 0.9, 0.3
    body.box((0, 0, H / 2), (W, D, H), "paint", bevel=0.015)
    body.box((0, -D / 2 - 0.01, H / 2), (W - 0.06, 0.02, H - 0.06), "paint", bevel=0.008)   # door
    for z in (0.18, H - 0.18):
        body.box((-W / 2 + 0.025, -D / 2 - 0.015, z), (0.03, 0.03, 0.09), "iron", bevel=0.006)   # hinges
    body.box((W / 2 - 0.08, -D / 2 - 0.03, H / 2 - 0.08), (0.04, 0.03, 0.1), "iron", bevel=0.006)  # latch
    # wired window with two porcelain sockets behind it
    body.box((0.0, -D / 2 - 0.022, 0.55), (0.36, 0.006, 0.22), "window", bevel=0.002)
    for x in (-0.09, 0.09):
        body.box((x, -D / 2 - 0.017, 0.55), (0.1, 0.012, 0.16), "porcelain", bevel=0.004)
    body.box((0.0, -D / 2 - 0.028, 0.55), (0.4, 0.012, 0.26), "iron", bevel=0.004)
    body.box((0.0, -D / 2 - 0.022, 0.29), (0.34, 0.006, 0.08), "plate", bevel=0.002)
    body.box((0.0, -D / 2 - 0.022, 0.78), (0.12, 0.006, 0.1), "warning", bevel=0.002)
    # side switch housing on the right, conduit up to the ceiling
    body.box((W / 2 + 0.05, 0, 0.45), (0.1, 0.2, 0.3), "paint", bevel=0.012)
    body.lathe([(0.03, 0.0), (0.03, 0.5)], "iron", segments=8, cap_bottom=False, cap_top=True,
               center=(-0.2, 0.08, H))
    lever = Part("lever", origin=(W / 2 + 0.1, 0.0, 0.45), parent="fuse_box")
    lever.lathe([(0.03, -0.02), (0.035, 0.0), (0.035, 0.04), (0.03, 0.06)], "iron", segments=10,
                center=(W / 2 + 0.1, 0.0, 0.45))
    hub = [f for f in lever.bm.faces]
    lever.move(hub, Matrix.Translation((W / 2 + 0.1, 0.0, 0.45)) @ Matrix.Rotation(math.radians(90), 4, 'Y')
               @ Matrix.Translation((-(W / 2 + 0.1), 0.0, -0.45)))
    lever.box((W / 2 + 0.13, -0.16, 0.45), (0.03, 0.32, 0.035), "iron", bevel=0.006)
    lever.box((W / 2 + 0.13, -0.34, 0.45), (0.045, 0.1, 0.05), "grip", bevel=0.015)
    red = Part("lamp_red", parent="fuse_box", origin=(W / 2 - 0.1, -D / 2 - 0.02, H - 0.1))
    red.lathe([(0.0, 0.0), (0.028, 0.0), (0.028, 0.012), (0.018, 0.024), (0.0, 0.028)], "lamp_red", segments=10,
              center=(0.0, 0.0, 0.0))
    red.move(list(red.bm.faces), Matrix.Translation((W / 2 - 0.1, -D / 2 - 0.02, H - 0.1))
             @ Matrix.Rotation(math.radians(90), 4, 'X'))
    green = Part("lamp_green", parent="fuse_box", origin=(W / 2 - 0.18, -D / 2 - 0.02, H - 0.1))
    green.lathe([(0.0, 0.0), (0.028, 0.0), (0.028, 0.012), (0.018, 0.024), (0.0, 0.028)], "lamp_green",
                segments=10, center=(0.0, 0.0, 0.0))
    green.move(list(green.bm.faces), Matrix.Translation((W / 2 - 0.18, -D / 2 - 0.02, H - 0.1))
               @ Matrix.Rotation(math.radians(90), 4, 'X'))
    return [body, lever, red, green]


def _fuse_paint(ctx):
    return A.paint(ctx, "paint_grey", 4.6, rough=0.5, chip=0.8)


def _window(ctx):
    s = A.Surface(ctx.N)
    u, v = ctx.uvm[:, 0], ctx.uvm[:, 1]
    wire = (np.mod(u + v, 0.03) < ctx.texel) | (np.mod(u - v, 0.03) < ctx.texel)
    s.use_ramp(A.P["crt_glass"], shade=2.5 + ctx.fbm(8.0, 2, 3) * 0.5)
    s.use_ramp(A.P["iron"], mask=wire, shade=np.full(ctx.N, 5.0))
    s.rough = np.where(wire, 0.5, 0.08)
    return s


def _warning(ctx):
    s = A.Surface(ctx.N)
    u, v = ctx.uvm[:, 0], ctx.uvm[:, 1]
    x, z = u - 0.0, v - 0.78
    tri = (z > -0.045) & (z < 0.045 - 1.6 * np.abs(x) * 1.0) & (np.abs(x) < 0.056)
    inner = (z > -0.033) & (z < 0.03 - 1.6 * np.abs(x)) & (np.abs(x) < 0.045)
    bolt = (np.abs(x - (z * -0.35)) < 0.006) & (z > -0.025) & (z < 0.022)
    s.use_ramp(A.P["paint_grey"], shade=np.full(ctx.N, 4.0))
    s.use_ramp(A.P["leather"], mask=tri, shade=np.full(ctx.N, 1.0))
    s.use_ramp(A.P["paint_ochre"], mask=inner, shade=np.full(ctx.N, 6.2))
    s.use_ramp(A.P["leather"], mask=inner & bolt, shade=np.full(ctx.N, 1.0))
    s.rough = np.full(ctx.N, 0.4)
    return s


def build():
    wood_fns = {"wood": M.wood_dark, "brass": M.brass, "marble": M.marble_white, "marble_dark": M.marble_dark,
                "lamp_warm": M.lamp_warm}
    booth_fns = dict(wood_fns)
    booth_fns["sign"] = _lettered(_kasa, [("KASA", 2.455, 2.0 / 128, 0.0, "center")], ink_ramp="gold",
                                  ink_shade=7.5, metal_ink=1.0, rough_ink=0.25)
    desk_fns = dict(wood_fns)
    desk_fns["sign"] = _lettered(_kasa, [("INFORMACJA", 1.73, 2.0 / 128, 0.0, "center")], ink_ramp="gold",
                                 ink_shade=7.5, metal_ink=1.0, rough_ink=0.25)
    desk_fns["shade"] = _green_shade
    fuse_fns = {"paint": _fuse_paint, "iron": M.iron, "porcelain": M.porcelain, "window": _window,
                "plate": _lettered(M.brass, [("BEZPIECZNIKI", 0.275, 1.0 / 256, 0.0, "center")]),
                "warning": _warning, "grip": M.rubber,
                "lamp_red": M.lamp_red,
                "lamp_green": lambda ctx: M.glow(ctx, "led_green", 4.5, strength=1.0)}
    return [
        kit("trex_pedestal", [pedestal()], {"limestone": A.limestone, "marble_dark": M.marble_dark, "brass": M.brass,
                                            "panel": lambda c: _panel_stone(c)}, ao_dist=0.6),
        kit("plaque_trex", [plaque()], {"plaque": _lettered(_plaque_face, PLAQUE_LINES), "brass": M.brass},
            ppm=256, ground=None, wall=True, ao_dist=0.05, preview_elevation=5.0),
        kit("ticket_booth", _culled(booth()), booth_fns, kinds={"glass": "glass"}, ppm=96, ao_dist=0.35,
            markers=[("Light", (0.9, 1.26, 1.2), None)]),
        kit("info_desk", _culled([info_desk()]), desk_fns, ppm=96, ao_dist=0.3),
        kit("bench_hall", [bench()], {"oak": M.wood_oak, "leather": _button_leather}, ppm=128, ao_dist=0.25),
        kit("fuse_box", fuse_box(), fuse_fns, ppm=256, ground=None, planes=(("y", -0.15),), ao_dist=0.12,
            markers=[("Fuse_A", (-0.09, -0.15, 0.55), None), ("Fuse_B", (0.09, -0.15, 0.55), None)]),
    ]


def _culled(parts):
    cull_floor(parts)
    return parts


def _panel_stone(ctx):
    s = A.limestone(ctx)
    s.shade -= 0.6
    return s
