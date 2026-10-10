"""Lobby kit: the north grate to the undercroft (opening 6 x 5 m, GATE door).

  grate_leaf_3m   one of the two iron leaves, 3 x 5 m, in Door's leaf frame
                  (origin = centre of the leaf's base): 16 square bars set
                  diagonally, 0.18 m apart (0.13 m clear between them, so
                  hitscan can pass once each bar gets its own collider),
                  riveted flat bars at 0.35 / 2.5 / 4.65 m, heavy stiles,
                  spiked feet. Bar centres: x = -1.35 + 0.18 k, k = 0..15.
                  Two leaves side by side (x = -1.5 and +1.5) fill the
                  opening; they can slide apart sideways or lift together.
  grate_frame_6m  riveted iron guide channels and a lintel girder round the
                  opening on the hall face; origin = the opening's floor
                  centre on the wall face.
"""
import math

import numpy as np
from mathutils import Matrix

from artlib import materials as M
from artlib.archkit import kit
from artlib.geo import Part

BARS = [-1.35 + 0.18 * k for k in range(16)]


def leaf():
    p = Part("grate_leaf_3m")
    H = 5.0
    for x in BARS:
        b = p.box((0, 0, 0), (0.035, 0.035, H - 0.3), "iron", bevel=0.004)
        p.move(b, Matrix.Translation((x, 0.0, 0.15 + (H - 0.3) / 2)) @ Matrix.Rotation(math.radians(45), 4, 'Z'))
        spike = p.lathe([(0.0, 0.0), (0.03, 0.12), (0.0, 0.14)], "iron", segments=4, cap_bottom=False)
        p.move(spike, Matrix.Translation((x, 0.0, 0.0)))
    for x in (-1.46, 1.46):
        p.box((x, 0, H / 2), (0.08, 0.08, H), "iron", bevel=0.008)
    for z in (0.35, 2.5, 4.65):
        for sy in (-1, 1):
            p.box((0, sy * 0.028, z), (2.98, 0.018, 0.08), "iron", bevel=0.004)
            for x in BARS:
                p.box((x, sy * 0.04, z), (0.022, 0.012, 0.022), "iron", bevel=0.005)
    p.box((0, 0, H - 0.06), (2.98, 0.07, 0.12), "iron", bevel=0.01)
    return p


def frame():
    p = Part("grate_frame_6m")
    hw, H = 3.0, 5.0
    for sx in (-1, 1):
        x = sx * (hw + 0.14)
        p.box((x, -0.12, H / 2 + 0.2), (0.28, 0.24, H + 0.4), "iron", bevel=0.012)
        p.box((x - sx * 0.1, -0.2, H / 2), (0.06, 0.1, H), "iron", bevel=0.008)
        for z in np.linspace(0.3, H, 11):
            p.box((x + sx * 0.05, -0.245, z), (0.03, 0.012, 0.03), "iron", bevel=0.006)
    p.box((0, -0.14, H + 0.3), (2 * hw + 0.8, 0.28, 0.5), "iron", bevel=0.015)
    p.box((0, -0.29, H + 0.3), (2 * hw + 0.6, 0.03, 0.36), "iron", bevel=0.006)
    for x in np.linspace(-hw, hw, 17):
        for z in (H + 0.16, H + 0.44):
            p.box((x, -0.31, z), (0.03, 0.012, 0.03), "iron", bevel=0.006)
    # winch drum boxes at the lintel ends
    for sx in (-1, 1):
        drum = p.lathe([(0.0, -0.2), (0.22, -0.2), (0.22, 0.2), (0.0, 0.2)], "iron", segments=12)
        p.move(drum, Matrix.Translation((sx * (hw + 0.2), -0.3, H + 0.3)) @ Matrix.Rotation(math.radians(90), 4, 'Y'))
    return p


def build():
    rusty = lambda c: M.iron(c)
    return [kit("grate_leaf_3m", [leaf()], {"iron": rusty}, built_final=True, ppm=128, ao_dist=0.2),
            kit("grate_frame_6m", [frame()], {"iron": rusty}, wall=True, ppm=64, ao_dist=0.3)]
