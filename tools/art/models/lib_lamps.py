"""Enlightenment wing: the green-shaded lamps (fixtures).

Fixture convention of the lobby kit: the origin is where the light shines
(put the Light3D there; every model also carries a "Light" marker at the
origin), the holder runs toward the wall (+Z in Godot) or up. Lit parts
(the bulbs, the inside of the shades, a faint glow in the green glass) are
in the emission map, so a power cut must zero the material's emission like
the lobby's fixtures.

  lib_lamp_reading   banker's lamp, 0.42 m: stepped brass base, a stem, a
                     tilted green cased-glass hood over a warm bulb. On
                     desks, display cases, the reading tables. Origin at the
                     bulb, the base 0.31 m below it.
  lib_lamp_wall      pilaster bracket lamp: a brass back plate, a swan-neck
                     arm 0.45 m and a green cone shade with a gilt rim
                     tilted down toward the shelves. Back plate on the
                     plane z = +0.45 (Godot) from the bulb.
  lib_lamp_pendant   hanging lamp: green glass dome with a brass gallery and
                     a finial, a 1 m brass rod to a ceiling rose. Origin at
                     the bulb, the rose's top 1.25 m above it. Longer drops:
                     stack lib_lamp_rod_1m (origin at its bottom) under the
                     ceiling and lower the lamp.
  lib_lamp_rod_1m    1 m brass suspension rod with a collar.
  lib_lamp_standard  floor lamp 1.62 m: weighted base, fluted brass column,
                     a wide green bell shade. Origin at the bulb (1.45 m up).
"""
import math
import os

import numpy as np
from mathutils import Matrix

from artlib import enl_materials as E
from artlib import kit as K
from artlib import materials as M
from artlib.archkit import kit
from artlib.geo import Part


def _shade_inside(ctx):
    """The lit inside of a shade: warm, emissive."""
    s = M.lamp_warm(ctx)
    s.emit = s.colors() * 0.8
    return s


def reading():
    p = Part("lib_lamp_reading")
    zb = -0.31
    p.box((0, 0.03, zb + 0.012), (0.24, 0.17, 0.024), "brass", bevel=0.008)
    p.box((0, 0.03, zb + 0.032), (0.2, 0.13, 0.016), "brass", bevel=0.006)
    p.box((0, 0.03, zb + 0.046), (0.15, 0.09, 0.012), "brass", bevel=0.004)
    p.lathe([(0.012, 0.0), (0.012, 0.2), (0.018, 0.21), (0.018, 0.23), (0.01, 0.24)], "brass", segments=8,
            center=(0.0, 0.07, zb + 0.05), cap_bottom=False)
    # the yoke over the hood and the pull chain
    p.tube([(0.0, 0.07, zb + 0.28), (0.0, 0.05, zb + 0.31), (0.0, 0.02, zb + 0.33)], 0.007, "brass", sides=6)
    chain = p.tube([(0.03, -0.06, -0.0), (0.032, -0.062, -0.05), (0.033, -0.062, -0.1)], 0.0025, "brass", sides=4)
    chain += K.sphere(p, (0.033, -0.062, -0.105), 0.008, "brass", segments=6, rings=4)
    # the hood: a half cylinder along x, open below, tilted toward the reader
    outer = p.lathe([(0.075, -0.13), (0.075, 0.13)], "shade", segments=16, cap_bottom=False, cap_top=False)
    p.move(outer, Matrix.Rotation(math.radians(90), 4, 'Y'))
    outer = K.keep(p, outer, lambda c: c.z > -0.002)
    inner = p.lathe([(0.068, -0.125), (0.068, 0.125)], "inside", segments=16, cap_bottom=False, cap_top=False)
    p.move(inner, Matrix.Rotation(math.radians(90), 4, 'Y'))
    inner = K.keep(p, inner, lambda c: c.z > -0.002)
    for f in inner:
        f.normal_flip()
    ends = []
    for sx in (-1, 1):
        cap = p.lathe([(0.0, 0.0), (0.075, 0.0)], "shade", segments=16, cap_bottom=False, cap_top=False)
        p.move(cap, Matrix.Translation((sx * 0.13, 0, 0)) @ Matrix.Rotation(math.radians(90 * sx), 4, 'Y'))
        ends += K.keep(p, cap, lambda c: c.z > -0.002)
    rim = []
    for sy in (-1, 1):
        rim += p.box((0, sy * 0.072, 0.0), (0.27, 0.008, 0.008), "brass")
    p.move(outer + inner + ends + rim + chain, Matrix.Translation((0, 0.0, 0.02)) @ Matrix.Rotation(math.radians(-15), 4, 'X'))
    K.sphere(p, (0.0, 0.0, 0.0), 0.022, "bulb", segments=8, rings=5)
    return p


def wall():
    """Built facing -Y (wall at y = +0.45 behind the bulb), turned by kit()."""
    p = Part("lib_lamp_wall")
    yw = 0.45
    p.box((0, yw - 0.012, 0.12), (0.11, 0.024, 0.2), "brass", bevel=0.01)
    p.lathe([(0.0, 0.0), (0.03, 0.0), (0.04, 0.02), (0.0, 0.035)], "brass", segments=8,
            center=(0.0, yw - 0.03, 0.12))
    pts = [(0.0, yw - 0.03, 0.12)]
    for i in range(1, 9):
        t = i / 8
        pts.append((0.0, yw - 0.03 - 0.4 * t, 0.12 + 0.2 * math.sin(math.pi * t * 0.9) - 0.06 * t))
    p.tube(pts, 0.011, "brass", sides=6)
    p.lathe([(0.016, 0.0), (0.02, 0.03), (0.02, 0.06), (0.016, 0.07)], "brass", segments=8,
            center=(0.0, 0.0, 0.03))
    shade = p.lathe([(0.03, 0.06), (0.06, 0.04), (0.1, 0.0), (0.13, -0.05), (0.135, -0.06)], "shade", segments=16,
                    cap_bottom=False, cap_top=False)
    inner = p.lathe([(0.026, 0.055), (0.055, 0.036), (0.095, -0.002), (0.125, -0.052)], "inside", segments=16,
                    cap_bottom=False, cap_top=False)
    for f in inner:
        f.normal_flip()
    rim = p.lathe([(0.135, -0.06), (0.138, -0.068), (0.128, -0.068)], "brass", segments=16, cap_bottom=False,
                  cap_top=False)
    # tilted toward the wall: the cone throws its light onto the shelves
    p.move(shade + inner + rim, Matrix.Rotation(math.radians(35), 4, 'X'))
    K.sphere(p, (0.0, 0.0, 0.0), 0.025, "bulb", segments=8, rings=5)
    return p


def pendant():
    p = Part("lib_lamp_pendant")
    dome = p.lathe([(0.04, 0.12), (0.09, 0.11), (0.16, 0.07), (0.21, 0.02), (0.23, -0.03), (0.235, -0.05)], "shade",
                   segments=20, cap_bottom=False, cap_top=False)
    inner = p.lathe([(0.035, 0.115), (0.085, 0.105), (0.155, 0.066), (0.2, 0.018), (0.222, -0.03)], "inside",
                    segments=20, cap_bottom=False, cap_top=False)
    for f in inner:
        f.normal_flip()
    p.lathe([(0.235, -0.05), (0.24, -0.06), (0.226, -0.062)], "brass", segments=20, cap_bottom=False, cap_top=False)
    p.lathe([(0.0, 0.11), (0.06, 0.11), (0.07, 0.13), (0.05, 0.16), (0.03, 0.18), (0.018, 0.2)], "brass", segments=12,
            cap_bottom=False)
    p.lathe([(0.008, 0.2), (0.008, 1.12)], "brass", segments=6, cap_bottom=False, cap_top=False)
    for z in (0.45, 0.8):
        p.lathe([(0.0, z - 0.02), (0.018, z - 0.01), (0.018, z + 0.01), (0.0, z + 0.02)], "brass", segments=8)
    p.lathe([(0.0, 1.1), (0.04, 1.1), (0.09, 1.16), (0.11, 1.22), (0.11, 1.25), (0.0, 1.25)], "brass", segments=14)
    K.sphere(p, (0.0, 0.0, 0.0), 0.03, "bulb", segments=8, rings=5)
    return p


def rod():
    p = Part("lib_lamp_rod_1m")
    p.lathe([(0.008, 0.0), (0.008, 1.0)], "brass", segments=6, cap_bottom=False, cap_top=False)
    p.lathe([(0.0, 0.48), (0.018, 0.49), (0.018, 0.51), (0.0, 0.52)], "brass", segments=8)
    return p


def standard():
    p = Part("lib_lamp_standard")
    zb = -1.45
    p.lathe([(0.0, 0.0), (0.2, 0.0), (0.2, 0.03), (0.17, 0.05), (0.12, 0.07), (0.07, 0.1), (0.05, 0.14)], "brass",
            segments=16, center=(0, 0, zb))
    flute = lambda i, j: 1.0 + (0.15 if i % 2 else 0.0)
    p.lathe([(0.025, 0.14), (0.022, 0.8), (0.02, 1.32)], "brass", segments=12, center=(0, 0, zb), cap_bottom=False,
            cap_top=False, smooth=False, ring_scale=flute)
    p.lathe([(0.02, 1.32), (0.04, 1.34), (0.04, 1.37), (0.02, 1.4), (0.02, 1.44)], "brass", segments=10,
            center=(0, 0, zb), cap_bottom=False)
    shade = p.lathe([(0.05, 0.13), (0.1, 0.12), (0.17, 0.08), (0.22, 0.02), (0.25, -0.05), (0.26, -0.07)], "shade",
                    segments=20, cap_bottom=False, cap_top=False)
    inner = p.lathe([(0.045, 0.125), (0.095, 0.115), (0.165, 0.076), (0.212, 0.018), (0.242, -0.05)], "inside",
                    segments=20, cap_bottom=False, cap_top=False)
    for f in inner:
        f.normal_flip()
    p.lathe([(0.26, -0.07), (0.265, -0.08), (0.25, -0.082)], "brass", segments=20, cap_bottom=False, cap_top=False)
    p.lathe([(0.0, 0.12), (0.05, 0.12), (0.04, 0.15), (0.02, 0.17), (0.0, 0.18)], "brass", segments=10)
    del shade
    K.sphere(p, (0.0, 0.0, 0.0), 0.03, "bulb", segments=8, rings=5)
    return p


def build():
    only = os.environ.get("ENL_ONLY", "").split(",")

    def want(n):
        return only == [""] or n in only

    fns = {"brass": E.worn_brass, "shade": lambda c: E.shade_green(c, glow=0.35), "inside": _shade_inside,
           "bulb": lambda c: M.glow(c, "lamp_warm", 5.0, strength=1.0)}
    light = [("Light", (0.0, 0.0, 0.0), None)]
    out = []
    if want("lib_lamp_reading"):
        out.append(kit("lib_lamp_reading", [reading()], fns, ppm=384, ground=-0.31, ao_dist=0.06, markers=light,
                       preview_yaws=(-30.0, 30.0, 150.0, 90.0), preview_elevation=20.0))
    if want("lib_lamp_wall"):
        out.append(kit("lib_lamp_wall", [wall()], fns, ppm=256, ground=None, ao_dist=0.06, markers=light,
                       planes=(("y", -0.45),), preview=False))
    if want("lib_lamp_pendant"):
        out.append(kit("lib_lamp_pendant", [pendant()], fns, ppm=256, ground=None, ao_dist=0.08, markers=light,
                       preview=False))
    if want("lib_lamp_rod_1m"):
        out.append(kit("lib_lamp_rod_1m", [rod()], fns, ppm=256, ground=None, ao_rays=0, preview=False))
    if want("lib_lamp_standard"):
        out.append(kit("lib_lamp_standard", [standard()], fns, ppm=256, ground=-1.45, ao_dist=0.1, markers=light,
                       preview_yaws=(-30.0, 30.0, 150.0, 90.0), preview_elevation=12.0))
    return out
