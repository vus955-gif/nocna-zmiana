"""Lobby kit: wall bands of the other rooms, 4 / 2 / 1 / 0.5 m run modules in
the kit wall convention (x = -W/2 .. W/2, wall plane z = 0, decoration on the
room side, Godot -Z). The field between bands is the shell wall with the
room's tile material (see ArtKit.ROOMS).

  gallery_base_*   marble skirting, walnut wainscot with a stile every metre
                   and raised panels, chair rail: 0-1.21 m (datum = floor).
  gallery_top_*    picture rail, plaster frieze, cornice with dentils:
                   0.94 m hanging from the ceiling (origin at its TOP).
  armory_top_*     heavy smoked-oak wall plate under the ceiling, 0.3 m
                   (origin at its TOP). The armory base is hall_plinth_*
                   with the texture set armory_plinth_*.
  diorama_base_*   dark umber painted plinth with a moulded cap, 0.45 m.
  diorama_top_*    painted valance hiding the backdrop's top edge, 0.7 m
                   (origin at its TOP).
  skirting_*       0.15 m skirting board. Texture sets: skirting (dark
                   brown gloss, corridors), skirting_black (security, staff),
                   skirting_pine (closet, secret rooms).
  security_rail_*  bump rail over the two-tone paint line, origin at its
                   centre (datum = 1.2 m).
  corridor_pipes_* three painted service pipes (fire main, water, cable
                   conduit) on brackets every metre, hanging from the
                   ceiling (origin at the TOP, the pipes 0.15-0.45 m down).
"""
import math

from artlib import arch_materials as A
from artlib import materials as M
from artlib.archkit import LENGTHS, kit, moulding, quad_front
from artlib.geo import Part


def gallery_base(W):
    p = Part("gallery_base")
    x0 = -W / 2
    p.box((0, -0.018, 0.1), (W, 0.036, 0.2), "marble_dark", bevel=0.006)
    moulding(p, [(-0.048, 0.2), (-0.048, 0.215), (-0.034, 0.24), (0.0, 0.24)], W, "marble_dark")
    p.box((0, -0.01, 0.68), (W, 0.02, 0.88), "wood_dark")
    p.box((0, -0.029, 0.285), (W, 0.018, 0.09), "wood_dark", bevel=0.005)
    p.box((0, -0.029, 1.07), (W, 0.018, 0.1), "wood_dark", bevel=0.005)
    n = max(1, int(W + 1e-6))
    for k in range(n + 1):
        a = max(x0, x0 + k - 0.06)
        b = min(x0 + W, x0 + k + 0.06)
        if b - a > 1e-3:
            p.box(((a + b) / 2, -0.029, 0.675), (b - a, 0.018, 0.69), "wood_dark", bevel=0.004)
    if W >= 1.0:
        for k in range(n):
            p.box((x0 + k + 0.5, -0.03, 0.675), (0.78, 0.024, 0.6), "wood_dark", bevel=0.02)
    moulding(p, [(0.0, 1.12), (-0.05, 1.12), (-0.062, 1.14), (-0.062, 1.17), (-0.046, 1.195), (-0.02, 1.21),
                 (0.0, 1.21)], W, "wood_dark")
    return p


def gallery_top(W):
    p = Part("gallery_top")
    H = 6.0      # the stage 1 wall's profile heights, hung from the top
    moulding(p, [(0.0, 5.06 - H), (-0.03, 5.06 - H), (-0.042, 5.08 - H), (-0.03, 5.11 - H), (0.0, 5.11 - H)], W,
             "wood_dark")
    quad_front(p, -W / 2, W / 2, 5.11 - H, 5.4 - H, "plaster", y=-0.004)
    prof = [(-0.004, 5.40), (-0.035, 5.40), (-0.035, 5.46), (-0.075, 5.48), (-0.075, 5.53), (-0.115, 5.55),
            (-0.115, 5.63), (-0.14, 5.645), (-0.2, 5.7), (-0.26, 5.77), (-0.31, 5.86), (-0.35, 5.89),
            (-0.35, 5.95), (-0.385, 5.965), (-0.385, 6.0), (0.0, 6.0)]
    moulding(p, [(y, z - H) for y, z in prof], W, "plaster")
    x = -W / 2 + 0.05
    while x < W / 2 - 0.02:
        p.box((x, -0.135, 5.59 - H), (0.05, 0.04, 0.07), "plaster", bevel=0.006)
        x += 0.1
    return p


def armory_top(W):
    p = Part("armory_top")
    moulding(p, [(0.0, -0.32), (-0.2, -0.32), (-0.25, -0.28), (-0.25, -0.04), (-0.22, 0.0), (0.0, 0.0)], W, "timber")
    n = max(1, int(round(W)))
    for k in range(n):
        x = -W / 2 + (k + 0.5) * W / n
        p.box((x, -0.26, -0.16), (0.06, 0.02, 0.22), "iron", bevel=0.006)
        for z in (-0.24, -0.08):
            p.lathe([(0.0, 0.0), (0.018, 0.0), (0.018, 0.01), (0.0, 0.016)], "iron", segments=6,
                    center=(x, -0.27, z))
    return p


def diorama_base(W):
    p = Part("diorama_base")
    moulding(p, [(-0.06, 0.0), (-0.06, 0.36), (-0.075, 0.38), (-0.075, 0.41), (-0.05, 0.44), (-0.03, 0.45),
                 (0.0, 0.45)], W, "paint")
    return p


def diorama_top(W):
    p = Part("diorama_top")
    moulding(p, [(0.0, -0.7), (-0.12, -0.7), (-0.14, -0.68), (-0.14, -0.62), (-0.12, -0.6), (-0.12, -0.18),
                 (-0.16, -0.14), (-0.2, -0.08), (-0.2, 0.0), (0.0, 0.0)], W, "paint")
    return p


def skirting(W):
    p = Part("skirting")
    moulding(p, [(-0.022, 0.0), (-0.022, 0.12), (-0.016, 0.135), (-0.01, 0.145), (-0.004, 0.15), (0.0, 0.15)], W,
             "board")
    return p


def security_rail(W):
    p = Part("security_rail")
    moulding(p, [(0.0, -0.05), (-0.02, -0.05), (-0.035, -0.035), (-0.04, 0.0), (-0.035, 0.035), (-0.02, 0.05),
                 (0.0, 0.05)], W, "rail")
    return p


PIPES = (("pipe_red", 0.2, 0.06), ("pipe_grey", 0.32, 0.045), ("pipe_cream", 0.42, 0.03))


def pipes(W):
    p = Part("corridor_pipes")
    for mat, drop, r in PIPES:
        off = 0.08 + r + 0.02 * PIPES.index((mat, drop, r))
        path = [(-W / 2, -off, -drop), (W / 2, -off, -drop)]
        p.tube(path, r, mat, sides=10, caps=False)
    n = max(1, int(round(W)))
    for k in range(n):
        x = -W / 2 + (k + 0.5) * W / n
        p.box((x, -0.02, -0.3), (0.04, 0.04, 0.6), "iron", bevel=0.006)               # wall strap
        for mat, drop, r in PIPES:
            off = 0.08 + r + 0.02 * PIPES.index((mat, drop, r))
            p.box((x, -off / 2, -drop - r - 0.015), (0.03, off, 0.02), "iron", bevel=0.004)   # arm under the pipe
            ring = [(x, -off + r * 1.15 * math.cos(a), -drop + r * 1.15 * math.sin(a))
                    for a in [i * math.tau / 12 for i in range(13)]]
            p.tube(ring, 0.008, "iron", sides=4, caps=False)
    return p


def _pipe(ramp, center):
    return lambda c: A.paint(c, ramp, center, rough=0.4, chip=0.5)


def build():
    out = []
    gal = {"marble_dark": M.marble_dark, "wood_dark": M.wood_dark, "plaster": M.plaster}
    for W, tag in LENGTHS:
        show = tag == "4m"
        out.append(kit(f"gallery_base_{tag}", [gallery_base(W)], gal, wall=True, preview=show))
        out.append(kit(f"gallery_top_{tag}", [gallery_top(W)], gal, wall=True, ground=None, ceiling=0.0,
                       preview=show))
        out.append(kit(f"skirting_{tag}", [skirting(W)], {"board": lambda c: A.paint(c, "wood_dark", 3.0, rough=0.25,
                                                                                    chip=0.4, under="wood_oak")},
                       wall=True, preview=False, ao_dist=0.1,
                       variants={f"skirting_black_{tag}": {"board": lambda c: A.paint(c, "plastic_black", 3.0,
                                                                                     rough=0.3, chip=0.2)},
                                 f"skirting_pine_{tag}": {"board": M.wood_oak}}))
        out.append(kit(f"diorama_base_{tag}", [diorama_base(W)], {"paint": lambda c: A.paint(c, "hide", 1.6,
                                                                                            rough=0.6)},
                       wall=True, preview=False))
        if tag != "05m":
            out.append(kit(f"armory_top_{tag}", [armory_top(W)], {"timber": A.timber, "iron": M.iron}, wall=True,
                           ground=None, ceiling=0.0, preview=show))
            out.append(kit(f"diorama_top_{tag}", [diorama_top(W)], {"paint": lambda c: A.paint(c, "hide", 1.4,
                                                                                              rough=0.6)},
                           wall=True, ground=None, ceiling=0.0, preview=False))
            out.append(kit(f"security_rail_{tag}", [security_rail(W)], {"rail": lambda c: A.paint(
                c, "wood_dark", 4.0, rough=0.3, chip=0.3, under="wood_oak")}, wall=True, ground=None,
                preview=False, ao_dist=0.1))
            out.append(kit(f"corridor_pipes_{tag}", [pipes(W)], {"pipe_red": _pipe("enamel_red", 4.5),
                                                                  "pipe_grey": _pipe("paint_grey", 5.5),
                                                                  "pipe_cream": _pipe("paint_cream", 5.0),
                                                                  "iron": M.iron},
                           ppm=128, wall=True, ground=None, ceiling=0.0, ao_dist=0.15, preview=show))
    return out
