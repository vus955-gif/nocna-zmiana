"""Freestanding Tuscan column, floor to ceiling (6 m): square white-marble
plinth and torus base, fluted red-marble shaft with a slight entasis,
necking, echinus and a square abacus touching the ceiling. Origin at the
centre of the plinth's underside."""
from artlib import materials as M
from artlib.geo import Part
from artlib.model import Model

H = 6.0
FLUTES = 16


def _flutes(i, j, last):
    # alternate ridge / channel vertices, not on the first and last ring
    if j == 0 or j == last:
        return 1.0
    return 1.0 if i % 2 == 0 else 0.93


def build():
    p = Part("column")
    # base: plinth, torus, fillet
    p.box((0, 0, 0.11), (0.72, 0.72, 0.22), "marble_white", bevel=0.02)
    p.lathe([(0.33, 0.22), (0.35, 0.25), (0.35, 0.3), (0.32, 0.34), (0.3, 0.35), (0.29, 0.38)],
            "marble_white", segments=24, cap_bottom=False)
    # shaft with entasis and flutes (ridges on even vertices)
    z0, z1 = 0.38, 5.22
    rings = 9
    prof = []
    for k in range(rings):
        t = k / (rings - 1)
        r = 0.27 - 0.045 * t * t
        prof.append((r, z0 + (z1 - z0) * t))
    last = len(prof) - 1
    p.lathe(prof, "marble_red", segments=FLUTES * 2, cap_bottom=False, cap_top=False, smooth=False,
            ring_scale=lambda i, j: _flutes(i, j, last))
    # capital: astragal, necking, echinus, abacus
    p.lathe([(0.225, 5.22), (0.25, 5.24), (0.25, 5.29), (0.228, 5.31), (0.228, 5.46), (0.25, 5.48),
             (0.3, 5.56), (0.36, 5.66), (0.38, 5.72)], "marble_white", segments=24, cap_bottom=False)
    p.box((0, 0, 5.74 + 0.13), (0.8, 0.8, 0.26), "marble_white", bevel=0.02)
    return Model("column", [p], {"marble_white": M.marble_white, "marble_red": M.marble_red},
                 ppm=64, ground=0.0, ao_dist=0.4)
