"""Gallery bench: button-tufted crimson velvet cushion on a walnut frame
with turned legs and a stretcher. 1.6 x 0.5 m, seat at 0.46 m."""
from artlib import materials as M
from artlib.geo import Part
from artlib.model import Model

L, D = 1.6, 0.5


def build():
    p = Part("bench")
    # legs (turned)
    for x in (-L / 2 + 0.07, L / 2 - 0.07):
        for y in (-D / 2 + 0.07, D / 2 - 0.07):
            p.lathe([(0.03, 0.0), (0.038, 0.02), (0.03, 0.05), (0.024, 0.12), (0.034, 0.17), (0.034, 0.2),
                     (0.026, 0.22), (0.03, 0.3), (0.036, 0.33)], "wood_dark", segments=10, center=(x, y, 0))
            p.box((x, y, 0.35), (0.07, 0.07, 0.04), "wood_dark", bevel=0.008)
    # stretcher
    p.box((0, 0, 0.12), (L - 0.14, 0.04, 0.04), "wood_dark", bevel=0.008)
    for x in (-L / 2 + 0.07, L / 2 - 0.07):
        p.box((x, 0, 0.12), (0.04, D - 0.14, 0.04), "wood_dark", bevel=0.008)
    # apron frame
    p.box((0, 0, 0.36), (L, D, 0.08), "wood_dark", bevel=0.012)
    # cushion: chunky bevelled slab + tufting buttons in a diamond grid
    p.box((0, 0, 0.43), (L - 0.02, D - 0.02, 0.07), "velvet", bevel=0.03)
    for i in range(7):
        for j in range(2):
            x = -0.6 + i * 0.2 + (0.1 if j % 2 else 0.0)
            if abs(x) > 0.68:
                continue
            y = -0.08 + j * 0.16
            p.box((x, y, 0.466), (0.024, 0.024, 0.012), "velvet", bevel=0.005)
    return Model("bench", [p], {"wood_dark": M.wood_dark, "velvet": M.velvet}, ppm=128, ground=0.0, ao_dist=0.3)
