"""The guard's dropped lamp (DroppedLantern): a boxy old hand lantern of
green-enamelled steel, a chrome reflector bezel with a warm glowing lens
on the front, a steel carrying bail on top, a switch knob. 0.14 x 0.11 m,
0.26 m to the top of the bail. Origin on the floor under its centre; the
lens faces -Y. Marker "Light" sits just in front of the lens: put the warm
OmniLight3D there (the lens texture is emissive)."""
import math

from artlib import kit
from artlib import materials as M
from artlib.geo import Part
from artlib.kit import R, T
from artlib.model import Model

LENS_C = (0.0, -0.068, 0.095)


FNS = {
    "body": lambda c: M.enamel(c, "paint_green", 5.0, seed=411, chip=1.2, gloss=0.3),
    "chrome": lambda c: M.steel(c, seed=413, center=9.4, dent=0.15, rust=0.5, polish=0.14, scratch=0.25),
    "lens": lambda c: M.glow(c, "lamp_warm", 4.6, strength=1.0, rough=0.1),
    "black": M.rubber,
}


def build():
    p = Part("lantern")
    p.box((0, 0, 0.085), (0.14, 0.11, 0.15), "body", bevel=0.014)                       # battery box
    p.box((0, 0, 0.162), (0.12, 0.09, 0.012), "body", bevel=0.005)                      # lid
    for sx in (-1, 1):
        for sy in (-1, 1):
            p.box((sx * 0.055, sy * 0.04, 0.004), (0.02, 0.02, 0.008), "black", bevel=0.003)   # feet
    # reflector head: chrome bezel ring and the lens
    head = p.lathe([(0.052, 0.0), (0.06, 0.004), (0.062, 0.016), (0.058, 0.024), (0.05, 0.026)], "chrome",
                   segments=16, cap_bottom=False, cap_top=False, smooth=True)
    lens = p.lathe([(0.05, 0.022), (0.03, 0.026), (0.0, 0.027)], "lens", segments=16, cap_bottom=False)
    p.move(head + lens, T(*LENS_C) @ T(0, 0.02, 0) @ R('X', 90))
    # bail handle: pivots on the sides, wire loop over the top
    pts = []
    for k in range(9):
        a = math.pi * k / 8
        pts.append((0.078 * math.cos(a), 0.0, 0.17 + 0.08 * math.sin(a)))
    p.tube(pts, 0.0045, "chrome", sides=6)
    for sx in (-1, 1):
        kit.seg(p, (sx * 0.07, 0, 0.15), (sx * 0.082, 0, 0.15), [(0.008, 0), (0.008, 1)], "chrome", segments=8)
    kit.seg(p, (0.035, 0.02, 0.168), (0.035, 0.02, 0.19), [(0.01, 0), (0.009, 0.7), (0.007, 1)], "black",
            segments=8)                                                                        # switch knob
    return Model("lantern", [p], FNS, ppm=384, ground=0.0, ao_dist=0.05, ao_rays=12, ao_stride=1,
                 markers=[("Light", (LENS_C[0], LENS_C[1] - 0.05, LENS_C[2]), None)], preview_elevation=16.0)
