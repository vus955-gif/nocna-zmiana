"""The red crystal off its stand: the same cluster of hexagonal points on
its lump of grey rock as in crystal.py, without the brass ring and the
label card. This is the piece that flies through the museum and lodges
between the T-Rex's ribs (at the trex model's CrystalSocket marker).
Origin at the centre of the rock lump."""
import math

from mathutils import Matrix

from artlib import materials as M
from artlib.geo import Part
from artlib.model import Model
from models.crystal import POINTS


def build():
    p = Part("crystal_loose")
    p.lathe([(0.0, -0.035), (0.045, -0.031), (0.055, -0.01), (0.045, 0.015), (0.02, 0.025), (0.0, 0.027)],
            "stone", segments=7, smooth=False, phase=0.3)
    for tilt, heading, length, r in POINTS:
        faces = p.lathe([(r * 0.7, 0.0), (r, 0.01), (r, length * 0.75), (0.0, length)], "crystal",
                        segments=6, smooth=False, cap_bottom=True)
        m = Matrix.Rotation(math.radians(heading), 4, 'Z') @ Matrix.Rotation(math.radians(tilt), 4, 'X')
        p.move(faces, m)
    return Model("crystal_loose", [p], {"stone": M.stone, "crystal": M.crystal}, ppm=400, ground=None,
                 ao_dist=0.06)
