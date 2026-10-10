"""Brass wall sconce with a frosted-glass tulip shade (emissive). Origin at
the centre of the wall plate on the wall plane; the shade's centre sits
0.28 m out and 0.2 m up (put the game light there)."""
import math

from mathutils import Matrix

from artlib import materials as M
from artlib.geo import Part
from artlib.model import Model


def build():
    p = Part("sconce")
    # oval back plate + boss
    plate = p.lathe([(0.0, -0.005), (0.07, -0.005), (0.075, 0.005), (0.06, 0.02), (0.0, 0.022)], "brass",
                    segments=12)
    p.move(plate, Matrix.Rotation(math.radians(90), 4, 'X'))
    for v in {v for f in plate for v in f.verts}:
        v.co.z *= 1.7
    # S-arm: three chunky segments out and up
    p.box((0, -0.07, 0.0), (0.026, 0.12, 0.026), "brass", bevel=0.006)
    p.box((0, -0.15, 0.05), (0.026, 0.06, 0.12), "brass", bevel=0.006)
    arm = p.box((0, -0.0, 0.0), (0.026, 0.13, 0.026), "brass", bevel=0.006)
    p.move(arm, Matrix.Translation((0, -0.22, 0.1)) @ Matrix.Rotation(math.radians(-35), 4, 'X'))
    # cup, bulb holder and tulip shade (opening upward)
    p.lathe([(0.0, 0.0), (0.03, 0.0), (0.045, 0.02), (0.04, 0.05), (0.022, 0.06)], "brass", segments=12,
            center=(0, -0.28, 0.1), cap_top=True)
    p.lathe([(0.03, 0.06), (0.05, 0.08), (0.075, 0.13), (0.09, 0.2), (0.1, 0.25), (0.085, 0.26)], "lamp_warm",
            segments=12, center=(0, -0.28, 0.1), cap_bottom=False, cap_top=False)
    p.lathe([(0.085, 0.255), (0.1, 0.25), (0.105, 0.26), (0.09, 0.27)], "brass", segments=12,
            center=(0, -0.28, 0.1), cap_bottom=False, cap_top=False)
    return Model("sconce", [p], {"brass": M.brass, "lamp_warm": M.lamp_warm}, ppm=256, ground=None, ao_dist=0.1)
