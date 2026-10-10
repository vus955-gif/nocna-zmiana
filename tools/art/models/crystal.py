"""The dormant red crystal ("Mineral of unknown origin"): a cluster of
hexagonal points growing from a lump of grey rock, on a small brass ring
stand with a label card. About 0.22 m tall; origin at the bottom centre."""
import math

from mathutils import Matrix

from artlib import materials as M
from artlib.geo import Part
from artlib.model import Model

POINTS = [  # (tilt deg, heading deg, length, radius)
    (0.0, 0.0, 0.16, 0.022),
    (28.0, 20.0, 0.11, 0.017),
    (32.0, 150.0, 0.1, 0.016),
    (40.0, 260.0, 0.08, 0.013),
    (18.0, 300.0, 0.12, 0.015),
]


def build():
    p = Part("crystal")
    # ring stand
    p.lathe([(0.0, 0.0), (0.07, 0.0), (0.07, 0.008), (0.06, 0.014), (0.05, 0.03), (0.042, 0.03),
             (0.05, 0.016), (0.0, 0.016)], "brass", segments=16, cap_bottom=False)
    # rock lump
    p.lathe([(0.0, 0.02), (0.045, 0.024), (0.055, 0.045), (0.045, 0.07), (0.02, 0.08), (0.0, 0.082)],
            "stone", segments=7, smooth=False, phase=0.3)
    # crystal points: hexagonal prisms with pyramid tips
    for tilt, heading, length, r in POINTS:
        faces = p.lathe([(r * 0.7, 0.0), (r, 0.01), (r, length * 0.75), (0.0, length)], "crystal",
                        segments=6, smooth=False, cap_bottom=True)
        m = (Matrix.Translation((0, 0, 0.055)) @ Matrix.Rotation(math.radians(heading), 4, 'Z')
             @ Matrix.Rotation(math.radians(tilt), 4, 'X'))
        p.move(faces, m)
    # label card leaning on the stand
    card = p.box((0, 0, 0), (0.07, 0.004, 0.04), "canvas_card", bevel=0.001)
    p.move(card, Matrix.Translation((0.0, -0.11, 0.02)) @ Matrix.Rotation(math.radians(-25), 4, 'X'))
    return Model("crystal", [p], {"brass": M.brass, "stone": M.stone, "crystal": M.crystal, "canvas_card": M.cloth_white},
                 ppm=400, ground=0.0, ao_dist=0.08)
