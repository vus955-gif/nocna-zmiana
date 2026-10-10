"""Velvet rope barrier: two brass stanchions 2 m apart (x = -1 and +1) with a
sagging crimson rope hooked between them. Origin on the floor at the centre.
Also exported alone as "stanchion_post" for arbitrary layouts."""
import math

from artlib import materials as M
from artlib.geo import Part
from artlib.model import Model

TOP = 0.95


def _post(p, x):
    # weighted round base, pole, collar and ball finial
    p.lathe([(0.0, 0.0), (0.17, 0.0), (0.17, 0.02), (0.15, 0.045), (0.07, 0.07), (0.035, 0.09),
             (0.022, 0.1), (0.022, 0.86), (0.03, 0.87), (0.03, 0.9), (0.02, 0.91), (0.02, 0.915)],
            "brass", segments=14, center=(x, 0, 0), cap_bottom=False)
    p.lathe([(0.0, 0.915), (0.03, 0.918), (0.042, 0.935), (0.042, 0.95), (0.03, 0.967), (0.0, 0.972)],
            "brass", segments=12, center=(x, 0, 0), cap_bottom=False, cap_top=False)
    # hook ring toward the rope
    side = 1 if x < 0 else -1
    p.box((x + side * 0.04, 0, 0.885), (0.04, 0.012, 0.012), "brass", bevel=0.003)


def _rope(p, x0, x1, sag=0.22, z=0.885):
    pts = []
    n = 20
    for i in range(n + 1):
        t = i / n
        x = x0 + (x1 - x0) * t
        dz = -sag * (1.0 - (2.0 * t - 1.0) ** 2)
        pts.append((x, 0.0, z + dz))
    p.tube(pts, 0.022, "velvet", sides=8)
    # brass end caps (snap hooks)
    for x, s in ((x0, 1), (x1, -1)):
        p.lathe([(0.0, -0.035), (0.026, -0.03), (0.028, 0.0), (0.026, 0.03), (0.0, 0.035)], "brass",
                segments=8, center=(x + s * 0.035, 0, z), cap_bottom=False, cap_top=False)


def build():
    pair = Part("stanchion")
    _post(pair, -1.0)
    _post(pair, 1.0)
    _rope(pair, -0.92, 0.92)
    single = Part("stanchion_post")
    _post(single, 0.0)
    fns = {"brass": M.brass, "velvet": M.velvet}
    return [Model("stanchion", [pair], fns, ppm=160, ground=0.0, ao_dist=0.2),
            Model("stanchion_post", [single], fns, ppm=160, ground=0.0, ao_dist=0.2)]
