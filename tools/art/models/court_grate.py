"""Floor I: the grate in the north hall over the stairs down to the crypt
(opening 8 x 5 m, x -4 .. 4), adapted from the lobby's kit_grate.

  grate_leaf_4m   one iron leaf 4 x 5 m in Door's leaf frame (origin =
                  centre of the leaf's base): 22 square bars set
                  diagonally, 0.18 m apart (0.13 m clear: give each bar its
                  own collider so bullets pass), riveted flat bars at
                  0.35 / 2.5 / 4.65 m, heavy stiles, spiked feet, and a
                  padlocked chain box at the meeting stile. Bar centres:
                  x = -1.89 + 0.18 k, k = 0..21. Two leaves at x = -2 and +2
                  fill the opening.
  grate_frame_8m  riveted guide channels, the lintel girder with winch
                  drums and an enamel plate "ZEJŚCIE DO PODZIEMI - WSTĘP
                  WZBRONIONY" on the hall face; origin = the opening's floor
                  centre on the wall face (front -Z).
"""
import math

import numpy as np
from mathutils import Matrix

from artlib import arch_materials as A
from artlib import court_materials as CM
from artlib import font
from artlib import materials as M
from artlib.archkit import kit
from artlib.geo import Part
from artlib.painter import Surface

BARS = [-1.89 + 0.18 * k for k in range(22)]


def leaf():
    p = Part("grate_leaf_4m")
    H = 5.0
    for x in BARS:
        b = p.box((0, 0, 0), (0.035, 0.035, H - 0.3), "iron", bevel=0.004)
        p.move(b, Matrix.Translation((x, 0.0, 0.15 + (H - 0.3) / 2)) @ Matrix.Rotation(math.radians(45), 4, 'Z'))
        spike = p.lathe([(0.0, 0.0), (0.03, 0.12), (0.0, 0.14)], "iron", segments=4, cap_bottom=False)
        p.move(spike, Matrix.Translation((x, 0.0, 0.0)))
    for x in (-1.96, 1.96):
        p.box((x, 0, H / 2), (0.08, 0.08, H), "iron", bevel=0.008)
    for z in (0.35, 2.5, 4.65):
        for sy in (-1, 1):
            p.box((0, sy * 0.028, z), (3.98, 0.018, 0.08), "iron", bevel=0.004)
            for x in BARS:
                p.box((x, sy * 0.04, z), (0.022, 0.012, 0.022), "iron")
    p.box((0, 0, H - 0.06), (3.98, 0.07, 0.12), "iron", bevel=0.01)
    # chain and padlock at the meeting stile (+X side)
    for k in range(6):
        z = 1.2 + k * 0.07
        p.box((1.93, (-0.05 if k % 2 else 0.05), z), (0.05 if k % 2 else 0.012, 0.012 if k % 2 else 0.05, 0.075),
              "chain", bevel=0.004)
    p.box((1.93, -0.07, 1.08), (0.09, 0.04, 0.11), "brass", bevel=0.01)
    return p


def frame():
    p = Part("grate_frame_8m")
    hw, H = 4.0, 5.0
    for sx in (-1, 1):
        x = sx * (hw + 0.14)
        p.box((x, -0.12, H / 2 + 0.2), (0.28, 0.24, H + 0.4), "iron", bevel=0.012)
        p.box((x - sx * 0.1, -0.2, H / 2), (0.06, 0.1, H), "iron", bevel=0.008)
        for z in np.linspace(0.3, H, 11):
            p.box((x + sx * 0.05, -0.245, z), (0.03, 0.012, 0.03), "iron", bevel=0.006)
    p.box((0, -0.14, H + 0.3), (2 * hw + 0.8, 0.28, 0.5), "iron", bevel=0.015)
    p.box((0, -0.29, H + 0.3), (2 * hw + 0.6, 0.03, 0.36), "iron", bevel=0.006)
    for x in np.linspace(-hw, hw, 23):
        for z in (H + 0.16, H + 0.44):
            p.box((x, -0.31, z), (0.03, 0.012, 0.03), "iron", bevel=0.006)
    for sx in (-1, 1):
        drum = p.lathe([(0.0, -0.2), (0.22, -0.2), (0.22, 0.2), (0.0, 0.2)], "iron", segments=12)
        p.move(drum, Matrix.Translation((sx * (hw + 0.2), -0.3, H + 0.3)) @ Matrix.Rotation(math.radians(90), 4, 'Y'))
    # the warning plate on the girder
    p.box((0, -0.32, H + 0.3), (2.6, 0.012, 0.3), "plate", bevel=0.004)
    return p


def _plate(ctx):
    u, v = ctx.uvm[:, 0], ctx.uvm[:, 1]
    s = Surface(ctx.N)
    s.use_ramp(CM.P["enamel_white"], shade=np.full(ctx.N, 6.2) + (ctx.rand(3) - 0.5) * 0.5)
    tx = ctx.texel
    ink = font.text_mask(u, v, "ZEJŚCIE DO PODZIEMI", 0.0, 5.3 + 0.02, tx)
    ink |= font.text_mask(u, v, "WSTĘP WZBRONIONY", 0.0, 5.3 - 0.1, tx)
    border = ((np.abs(np.abs(u) - 1.26) < tx) & (np.abs(v - 5.3) < 0.13)) | \
             ((np.abs(np.abs(v - 5.3) - 0.13) < tx) & (np.abs(u) < 1.26))
    s.use_ramp(CM.P["formline_red"], mask=ink | border, shade=np.full(ctx.N, 4.6))
    chip = (ctx.edge_soft(2.0) > 0.3) & (ctx.fbm(20.0, 2, 7) > 0.35)
    s.use_ramp(CM.P["iron"], mask=chip, shade=np.full(ctx.N, 2.0))
    s.rough = np.full(ctx.N, 0.25)
    return s


def build():
    return [kit("grate_leaf_4m", [leaf()], {"iron": M.iron, "chain": M.steel, "brass": M.brass}, built_final=True,
                ppm=128, ao_dist=0.2),
            kit("grate_frame_8m", [frame()], {"iron": M.iron, "plate": _plate}, wall=True, ppm=64, ao_dist=0.3)]
