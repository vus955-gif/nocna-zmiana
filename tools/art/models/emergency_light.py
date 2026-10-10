"""Red emergency lamp: painted steel box on a wall bracket with a ribbed red
lens (emissive) and a small cage. Origin on the wall plane at the bracket's
centre; the lens faces the room (-Y)."""
from artlib import materials as M
from artlib.geo import Part
from artlib.model import Model


def build():
    p = Part("emergency_light")
    p.box((0, -0.01, 0), (0.12, 0.02, 0.2), "iron", bevel=0.005)          # wall plate
    p.box((0, -0.07, 0), (0.3, 0.1, 0.14), "iron", bevel=0.012)           # housing
    p.box((0, -0.125, 0), (0.24, 0.02, 0.09), "lamp_red", bevel=0.006)    # lens
    for x in (-0.08, -0.04, 0.0, 0.04, 0.08):                              # lens ribs
        p.box((x, -0.137, 0), (0.008, 0.008, 0.09), "lamp_red", bevel=0.002)
    for z in (-0.05, 0.05):                                                # wire guard
        p.box((0, -0.15, z), (0.27, 0.008, 0.008), "iron", bevel=0.002)
    for x in (-0.13, 0.13):
        p.box((x, -0.14, 0), (0.008, 0.02, 0.11), "iron", bevel=0.002)
    return Model("emergency_light", [p], {"iron": M.iron, "lamp_red": M.lamp_red}, ppm=256, ground=None, ao_dist=0.1)
