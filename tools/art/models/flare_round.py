"""Projectile: the burning signal flare in flight (and stuck in a wall or
an exhibit). A 26.5 mm cartridge a little larger than life so it reads in
flight: brass base with a rim, red paper hull with a crimp ring, and the
magnesium star burning white-pink at the tip (emissive). 0.105 m long.

Faces +Y (Godot -Z, the flight direction), origin at its middle, so the
game can spin it and stick it in by the tip. Emission map: the star and a
scorched collar just behind it (ArtLibrary EXTRAS: strong); put the
OmniLight3D on the tip, 0.05 m ahead of the origin (marker "Light").
Part: flare_round (0, 0, 0).
"""
import numpy as np

from artlib import kit
from artlib import materials as M
from artlib.geo import Part
from artlib.model import Model

L = 0.105
R = 0.0155


def hull(ctx):
    s = M.plastic(ctx, "paint_red", 4.6, seed=521, rough=0.7, scuff=0.8, speckle=0.5)
    ring = (ctx.p[:, 1] > -L / 2 + 0.02) & (ctx.p[:, 1] < -L / 2 + 0.0235)     # crimp groove
    s.shade[ring] -= 1.8
    s.height = s.height - ring * 0.0004
    return s


def star(ctx):
    """Burning magnesium: white-hot centre, pink-red rim, blotchy flicker."""
    s = M.glow(ctx, "flare", 6.2, strength=1.0, rough=0.9)
    rim = ctx.p[:, 1] < L / 2 - 0.004
    s.shade[rim] -= 2.2
    s.emit = s.colors() * 1.0
    return s


def scorch(ctx):
    s = M.plastic(ctx, "paint_red", 1.4, seed=523, rough=0.9, scuff=0.0, speckle=0.8)
    glow = ctx.p[:, 1] > L / 2 - 0.016
    s.emit = np.zeros((ctx.N, 3))
    s.emit[glow] = M.P["flare"][2] * 0.6
    return s


FNS = {"hull": hull, "brass": M.brass, "star": star, "scorch": scorch}


def build():
    p = Part("flare_round")
    y0 = -L / 2
    kit.seg(p, (0, y0, 0), (0, y0 + 0.012, 0), [(R + 0.002, 0.0), (R + 0.002, 0.3), (R * 0.98, 0.4), (R * 0.98, 1.0)],
            "brass", segments=12)
    kit.seg(p, (0, y0 + 0.012, 0), (0, L / 2 - 0.022, 0), [(R, 0.0), (R, 1.0)], "hull", segments=12, caps=False)
    kit.seg(p, (0, L / 2 - 0.022, 0), (0, L / 2 - 0.01, 0), [(R, 0.0), (R * 0.96, 0.5), (R * 0.85, 1.0)], "scorch",
            segments=12, caps=False)
    # (a lathe that ends in a point makes one tiny UV island per apex
    # triangle, too small to get a texel: end on a small flat cap instead)
    kit.seg(p, (0, L / 2 - 0.01, 0), (0, L / 2, 0), [(R * 0.85, 0.0), (R * 0.75, 0.5), (R * 0.45, 0.9), (R * 0.22, 1.0)],
            "star", segments=12)
    return Model("flare_round", [p], FNS, ppm=512, ground=None, ao_dist=0.02, ao_rays=8, ao_stride=1, front=1,
                 markers=[("Light", (0.0, L / 2 + 0.005, 0.0), None)], preview_elevation=20.0)
