"""Plinth for busts and small sculptures: dark marble base and cap, limestone
shaft with a sunk panel on each face. 0.5 x 0.5 m footprint, 1.1 m tall
(the top surface is at Z = 1.1)."""
from artlib import materials as M
from artlib.geo import Part
from artlib.model import Model

HEIGHT = 1.1


def build():
    p = Part("pedestal")
    # base: plinth block + chamfered step
    p.box((0, 0, 0.06), (0.54, 0.54, 0.12), "marble_dark", bevel=0.012)
    p.box((0, 0, 0.15), (0.46, 0.46, 0.06), "marble_dark", bevel=0.012)
    # shaft
    p.box((0, 0, 0.6), (0.38, 0.38, 0.84), "stone", bevel=0.01)
    # sunk panels: thin frames standing proud of the shaft faces
    for ax in range(4):
        for side in (-1, 1):
            if ax == 0:
                p.box((side * 0.195, 0, 0.6), (0.012, 0.28, 0.64), "stone", bevel=0.004)
            elif ax == 1:
                p.box((0, side * 0.195, 0.6), (0.28, 0.012, 0.64), "stone", bevel=0.004)
    # cap: moulded two-step overhang
    p.box((0, 0, 1.035), (0.44, 0.44, 0.03), "marble_dark", bevel=0.008)
    p.box((0, 0, 1.075), (0.52, 0.52, 0.05), "marble_dark", bevel=0.012)
    return Model("pedestal", [p], {"marble_dark": M.marble_dark, "stone": M.stone}, ppm=128, ground=0.0)
