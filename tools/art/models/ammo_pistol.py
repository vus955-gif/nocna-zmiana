"""Pickup: a cardboard box of pistol cartridges, lid flipped open, rows of
brass cases with copper bullets showing. Green-and-cream pre-war print
with a red band. Pickup scale (bigger than life, reads from across a
room): 0.26 x 0.16 m, 0.2 m to the top of the open lid. Origin at the
centre of the box (the pickup spins and bobs around it); faces -Y."""
import numpy as np

from artlib import kit
from artlib import materials as M
from artlib.geo import Part
from artlib.kit import R, T
from artlib.model import Model

W, D, H = 0.26, 0.16, 0.08


def box_print(ctx):
    """Cardboard printed green, a cream label with pseudo-text and a red
    band on the long sides and the lid."""
    s = M.cardboard(ctx, seed=371, center=4.6)
    x, z = ctx.p[:, 0], ctx.p[:, 2]
    side = np.abs(ctx.n[:, 1]) > 0.6
    green = side | (np.abs(ctx.n[:, 0]) > 0.6)
    s.use_ramp(M.P["paint_green"], mask=green, shade=s.shade[:] * 0.0 + 4.8 + ctx.fbm(20.0, 2, 3) * 0.6
               + M._dither(ctx, 0.8, 4) + ctx.edge_soft(3.0) * 1.2)
    lab = side & (np.abs(x) < 0.08) & (np.abs(z) < 0.024)
    s.use_ramp(M.P["cloth_white"], mask=lab, shade=np.full(ctx.N, 6.2) + M._dither(ctx, 0.6, 5))
    ink = lab & M.text_marks(ctx, 0.005, 6)
    s.use_ramp(M.P["hair"], mask=ink, shade=np.full(ctx.N, 1.0))
    band = side & (np.abs(z + 0.03) < 0.005)
    s.use_ramp(M.P["cloth_red"], mask=band, shade=np.full(ctx.N, 5.0) + M._dither(ctx, 0.6, 7))
    s.rough = np.full(ctx.N, 0.9)
    return s


def lid_print(ctx):
    s = box_print(ctx)
    return s


def copper(ctx):
    return M.brass(ctx, seed=373, ramp="bronze_metal", tarnish_amount=1.0)


FNS = {"box": box_print, "lid": M.cardboard, "brass": M.brass, "copper": copper}


def build():
    p = Part("ammo_pistol")
    p.box((0, 0, 0), (W, D, H), "box", bevel=0.004)
    # the open top: a darker recess the cartridges stand in
    p.box((0, 0, H / 2 - 0.004), (W - 0.016, D - 0.016, 0.01), "lid", bevel=0.001)
    for i in range(6):
        for j in range(4):
            x = -W / 2 + 0.025 + i * (W - 0.05) / 5
            y = -D / 2 + 0.026 + j * (D - 0.052) / 3
            p.lathe([(0.0105, H / 2 - 0.004), (0.0105, H / 2 + 0.014), (0.0095, H / 2 + 0.016)], "brass",
                    segments=8, center=(x, y, 0), cap_bottom=False, cap_top=False)
            p.lathe([(0.0095, H / 2 + 0.016), (0.009, H / 2 + 0.024), (0.006, H / 2 + 0.031), (0.0, H / 2 + 0.034)],
                    "copper", segments=8, center=(x, y, 0), cap_bottom=False)
    # lid, hinged at the back top edge, standing open and leaning back
    lid = p.box((0, 0, 0), (W, 0.006, D), "box", bevel=0.002)
    p.move(lid, T(0, D / 2 + 0.01, H / 2 + D / 2 - 0.01) @ R('X', -12))
    return Model("ammo_pistol", [p], FNS, ppm=256, ground=None, ao_dist=0.05, ao_rays=12, ao_stride=1,
                 preview_elevation=28.0)
