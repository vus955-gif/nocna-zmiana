"""Enlightenment wing: the librarian's office (a haven: warm, cluttered,
safe). Kit convention: origin = centre of the base on the floor, front =
Godot -Z.

  lib_office_desk     partner's desk 1.7 x 0.78 x 0.95 m in mahogany: green
                      leather top with a gilt tooled border, two pedestals
                      of drawers with brass handles, a stack of ledgers, an
                      inkstand with a quill, a blotter, loose index cards.
                      Marker "terminal_spot" on the free end of the top,
                      Godot (0.55, 0.76, 0.0) (where the haven's terminal
                      goes: the stage-2 terminal's PC without its own
                      table, or any screen; it faces -Z like the desk).
  lib_office_chair    oak swivel desk chair with a buttoned green leather
                      seat and a curved spindle back, on four castors.
  lib_card_catalogue  oak card catalogue 1.2 x 1.45 x 0.5 m: 48 small drawers
                      (6 x 8) with brass label frames and pulls, on a stand
                      with turned legs; a drawer pulled out with cards.
  lib_filing_cabinet  oak four-drawer filing cabinet 0.5 x 1.32 x 0.65 m with
                      brass label holders and cup handles, a paper tray on
                      top.
"""
import math
import os
import random

import numpy as np
from mathutils import Matrix

from artlib import enl_books as B
from artlib import enl_materials as E
from artlib import kit as K
from artlib import materials as M
from artlib.archkit import kit
from artlib.enl_materials import P
from artlib.geo import Part
from artlib.materials import _dither
from models.lib_natural import plate_text


def handle(p, x, y, z, w=0.09):
    p.box((x, y - 0.006, z), (w, 0.012, 0.02), "brass", bevel=0.004)
    p.box((x, y - 0.016, z - 0.006), (w * 0.8, 0.012, 0.01), "brass", bevel=0.003)


def desk():
    p = Part("lib_office_desk")
    W, D, H = 1.7, 0.78, 0.76
    hw, hd = W / 2, D / 2
    for sx in (-1, 1):
        x = sx * (hw - 0.26)
        p.box((x, 0, 0.05), (0.5, D - 0.06, 0.1), "mahogany_dark", bevel=0.01)
        p.box((x, 0, 0.4), (0.5, D - 0.04, 0.6), "mahogany", bevel=0.012)
        for k in range(3):
            z = 0.2 + k * 0.18
            p.box((x, -hd + 0.016, z), (0.44, 0.012, 0.16), "mahogany", bevel=0.008)
            handle(p, x, -hd + 0.01, z + 0.02)
    p.box((0, 0, H - 0.04), (W, D, 0.06), "mahogany", bevel=0.014)
    p.box((0, -hd + 0.02, H - 0.1), (W - 1.1, 0.012, 0.08), "mahogany", bevel=0.006)
    handle(p, 0.0, -hd + 0.014, H - 0.1, 0.07)
    p.box((0, 0.0, H - 0.005), (W - 0.12, D - 0.12, 0.01), "leather_top")
    # the clutter: ledgers, inkstand, blotter, cards
    rng = random.Random(71)
    z = H
    for k in range(4):
        w, d, t = 0.3 - k * 0.02, 0.4 - k * 0.025, rng.uniform(0.035, 0.055)
        f = p.box((0, 0, 0), (w, d, t), "ledger", bevel=0.004)
        p.move(f, Matrix.Translation((0.55, 0.12, z + t / 2)) @ Matrix.Rotation(math.radians(rng.uniform(-8, 8)), 4, 'Z'))
        z += t
    p.box((0.05, 0.02, H + 0.004), (0.5, 0.36, 0.008), "blotter", bevel=0.002)
    p.box((0.05, 0.02, H + 0.009), (0.44, 0.3, 0.002), "paper")
    p.box((-0.15, 0.25, H + 0.02), (0.3, 0.14, 0.04), "mahogany", bevel=0.006)
    for x in (-0.22, -0.08):
        p.lathe([(0.0, 0.0), (0.03, 0.0), (0.035, 0.03), (0.02, 0.05), (0.022, 0.06), (0.0, 0.06)], "ink_glass",
                segments=8, center=(x, 0.25, H + 0.04))
    p.tube([(-0.08, 0.25, H + 0.09), (-0.05, 0.2, H + 0.22), (-0.02, 0.17, H + 0.3)], lambda t: 0.003 + 0.01 * t,
           "quill", sides=4)
    for k in range(6):
        f = p.box((0, 0, 0), (0.125, 0.075, 0.002), "card")
        p.move(f, Matrix.Translation((0.3 + rng.uniform(-0.05, 0.05), -0.2 + rng.uniform(-0.04, 0.04),
                                      H + 0.003 + k * 0.002)) @ Matrix.Rotation(math.radians(rng.uniform(-30, 30)), 4, 'Z'))
    return p


def chair():
    p = Part("lib_office_chair")
    for k in range(4):
        a = math.tau * k / 4 + math.pi / 4
        p.tube([(0, 0, 0.12), (0.28 * math.cos(a), 0.28 * math.sin(a), 0.06)], 0.022, "oak", sides=6)
        K.sphere(p, (0.3 * math.cos(a), 0.3 * math.sin(a), 0.03), 0.03, "brass", segments=8, rings=5)
    p.lathe([(0.06, 0.08), (0.05, 0.14), (0.03, 0.18), (0.03, 0.38), (0.06, 0.42)], "iron", segments=10)
    p.lathe([(0.0, 0.42), (0.26, 0.42), (0.27, 0.46), (0.0, 0.46)], "oak", segments=16, squash=(1.0, 0.92))
    p.lathe([(0.0, 0.46), (0.24, 0.46), (0.23, 0.5), (0.15, 0.52), (0.0, 0.525)], "leather_seat", segments=16,
            squash=(1.0, 0.92))
    # curved back rail on spindles
    pts = [(0.27 * math.cos(math.radians(a)), 0.25 * math.sin(math.radians(a)), 0.78) for a in range(20, 161, 20)]
    p.tube(pts, 0.03, "oak", sides=6)
    for a in range(20, 161, 28):
        x, y = 0.25 * math.cos(math.radians(a)), 0.23 * math.sin(math.radians(a))
        p.tube([(x, y, 0.5), (x * 1.04, y * 1.04, 0.77)], 0.012, "oak", sides=5)
    return p


def card_catalogue():
    p = Part("lib_card_catalogue")
    W, D = 1.2, 0.5
    hw, hd = W / 2, D / 2
    for sx in (-1, 1):
        for sy in (-1, 1):
            p.lathe([(0.025, 0.0), (0.03, 0.03), (0.02, 0.1), (0.028, 0.32), (0.03, 0.38)], "oak", segments=8,
                    center=(sx * (hw - 0.06), sy * (hd - 0.06), 0.0))
    p.box((0, 0, 0.41), (W, D, 0.06), "oak", bevel=0.01)
    body_z0, body_z1 = 0.44, 1.4
    p.box((0, 0, (body_z0 + body_z1) / 2), (W - 0.04, D - 0.04, body_z1 - body_z0), "oak", bevel=0.01)
    cols, rows = 6, 8
    cw = (W - 0.1) / cols
    rh = (body_z1 - body_z0 - 0.06) / rows
    for i in range(cols):
        for j in range(rows):
            x = -hw + 0.05 + cw * (i + 0.5)
            z = body_z0 + 0.03 + rh * (j + 0.5)
            out = 0.18 if (i, j) == (2, 4) else 0.0
            p.box((x, -hd + 0.008 - out, z), (cw - 0.014, 0.016, rh - 0.014), "oak")
            p.box((x, -hd - 0.002 - out, z + rh * 0.18), (0.06, 0.006, 0.03), "label_frame")
            p.box((x, -hd - 0.006 - out, z - rh * 0.2), (0.03, 0.012, 0.014), "brass")
            if out:
                p.box((x, -hd + 0.008 - out / 2, z - rh / 2 + 0.01), (cw - 0.03, out, 0.006), "oak")
                for c in range(14):
                    p.box((x, -hd + 0.03 - out + c * 0.011, z - rh / 2 + 0.05), (cw - 0.05, 0.002, 0.075), "card")
    p.box((0, 0, body_z1 + 0.03), (W + 0.04, D + 0.04, 0.06), "oak", bevel=0.012)
    p.box((0, -hd - 0.015, body_z1 + 0.03), (0.4, 0.008, 0.045), "plate", bevel=0.003)
    return p


def filing_cabinet():
    p = Part("lib_filing_cabinet")
    W, D, H = 0.5, 0.65, 1.32
    p.box((0, 0, 0.04), (W, D - 0.04, 0.08), "oak_dark", bevel=0.008)
    p.box((0, 0, H / 2 + 0.04), (W, D, H - 0.08), "oak", bevel=0.012)
    for k in range(4):
        z = 0.12 + k * 0.295 + 0.14
        p.box((0, -D / 2 - 0.006, z), (W - 0.05, 0.012, 0.27), "oak", bevel=0.01)
        p.box((0, -D / 2 - 0.015, z + 0.07), (0.1, 0.006, 0.045), "label_frame")
        K.sphere(p, (0, -D / 2 - 0.02, z - 0.02), 0.03, "brass", segments=10, rings=6, squash=(1.0, 0.4))
    p.box((0, 0, H + 0.01), (W + 0.02, D + 0.02, 0.03), "oak", bevel=0.008)
    p.box((0, 0.02, H + 0.04), (0.36, 0.3, 0.03), "brass", bevel=0.005)
    p.box((0, 0.02, H + 0.05), (0.32, 0.26, 0.012), "paper")
    return p


def _ledger(ctx):
    s = E.mahogany(ctx, seed=1201, center=3.4)
    side = np.abs(ctx.n[:, 2]) < 0.5
    pages = side & (np.abs(ctx.n[:, 1]) > 0.5)
    s.use_ramp(P["enl_paper"], mask=pages, shade=np.full(ctx.N, 6.0) - (np.mod(np.floor(ctx.p[:, 2] / ctx.texel), 2)))
    leather = ~pages
    s.use_ramp(P["enl_morocco_green"], mask=leather & (ctx.p[:, 2] % 0.1 > 0.05), shade=np.full(ctx.N, 3.5))
    return s


def _card(ctx):
    s = E.paper(ctx, seed=1202, center=7.2)
    v = ctx.uvm[:, 1]
    rule = np.mod(np.floor(v / ctx.texel), 3) == 0
    s.use_ramp(P["enl_morocco_blue"], mask=rule, shade=np.full(ctx.N, 5.5))
    return s


def build():
    only = os.environ.get("ENL_ONLY", "").split(",")

    def want(n):
        return only == [""] or n in only

    fns = {"mahogany": E.mahogany, "mahogany_dark": lambda c: E.mahogany(c, seed=1203, center=3.0),
           "brass": E.worn_brass, "leather_top": lambda c: E.baize(c, seed=1204, gilt_border=0.035),
           "ledger": _ledger, "blotter": lambda c: E.baize(c, seed=1205), "paper": lambda c: E.printed(c, seed=1206),
           "ink_glass": lambda c: E.glass_tint(c, ramp="enl_ink", center=2.5),
           "quill": lambda c: E.paper(c, seed=1207, center=7.5), "card": _card, "oak": E.oak_dark,
           "oak_dark": lambda c: E.oak_dark(c, seed=1208, center=3.0), "iron": E.iron_black,
           "leather_seat": lambda c: E.baize(c, seed=1209),
           "label_frame": lambda c: E.paper(c, seed=1210, center=7.0), "plate": plate_text("KATALOG")}
    out = []
    if want("lib_office_desk"):
        out.append(kit("lib_office_desk", [desk()], fns, ppm=160, ground=0.0, ao_dist=0.2,
                       markers=[("terminal_spot", (-0.55, 0.0, 0.76), None)],
                       preview_yaws=(-30.0, 10.0, 150.0, 60.0), preview_elevation=25.0))
    if want("lib_office_chair"):
        out.append(kit("lib_office_chair", [chair()], fns, ppm=160, ground=0.0, ao_dist=0.15, preview=False))
    if want("lib_card_catalogue"):
        out.append(kit("lib_card_catalogue", [card_catalogue()], fns, ppm=160, ground=0.0, ao_dist=0.15,
                       preview_yaws=(-30.0, 10.0, 150.0, 60.0), preview_elevation=12.0))
    if want("lib_filing_cabinet"):
        out.append(kit("lib_filing_cabinet", [filing_cabinet()], fns, ppm=160, ground=0.0, ao_dist=0.15,
                       preview=False))
    return out
