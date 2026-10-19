"""Pickup: a red cardboard box of shotgun shells, lid open, fifteen brass
heads showing, two loose shells lying across the top. Wide and low (0.26 x
0.16 x 0.09 m) against the pistol's brick. Red is the shotgun's colour in
the HUD and on the floor (_pickup_palette.py): the print glows faintly in
the dark, the slot digit "3" in cream on both ends and on the open lid a
little more. Origin at the box centre; faces -Y."""
import numpy as np
from mathutils import Vector

from artlib import kit, pixelfont
from artlib import materials as M
from artlib.geo import Part
from artlib.kit import R, T
from artlib.model import Model
from models import _pickup_palette as PP

NAME = "ammo_shells"
W, D, H = 0.26, 0.16, 0.09
LID_T = 0.006
LID_M = T(0, D / 2 + 0.01, H / 2 + D / 2 - 0.01) @ R('X', -15)
LID_N = np.array((LID_M.to_3x3() @ Vector((0, 1, 0))).normalized())
LID_C = PP.face_uv(LID_M @ Vector((0, LID_T / 2, 0)), LID_N)
DIGIT = PP.digit(NAME)


def box_print(ctx):
    s = M.cardboard(ctx, seed=381, center=4.6)
    side = (np.abs(ctx.n[:, 1]) > 0.6) | (np.abs(ctx.n[:, 0]) > 0.6)
    s.use_ramp(M.P["pk_" + NAME], mask=side, shade=np.full(ctx.N, 4.2) + ctx.fbm(20.0, 2, 3) * 0.6
               + M._dither(ctx, 0.8, 4) + ctx.edge_soft(3.0) * 1.4 - (1.0 - ctx.ao) * 2.0)
    x, z = ctx.p[:, 0], ctx.p[:, 2]
    lab = (np.abs(ctx.n[:, 1]) > 0.6) & (z < H / 2) & (np.abs(x) < 0.09) & (np.abs(z - 0.005) < 0.022)
    s.use_ramp(M.P["cloth_white"], mask=lab, shade=np.full(ctx.N, 6.0) + M._dither(ctx, 0.6, 5))
    ink = lab & M.text_marks(ctx, 0.006, 8)
    s.use_ramp(M.P["hair"], mask=ink, shade=np.full(ctx.N, 1.0))
    ends = (np.abs(ctx.n[:, 0]) > 0.7) & pixelfont.stamp(ctx, DIGIT, 0.0, 0.0, scale=2)
    lid = (ctx.n @ LID_N > 0.9) & (z > H / 2 + 0.004) & pixelfont.stamp(ctx, DIGIT, LID_C[0], LID_C[1], scale=2)
    digits = (ends | lid) & (ctx.rand(9) > 0.04)
    s.use_ramp(M.P["cloth_white"], mask=digits, shade=np.full(ctx.N, 6.4) + M._dither(ctx, 0.5, 10))
    s.rough = np.full(ctx.N, 0.88)
    PP.glow(s, side & ~lab & ~digits)
    PP.white(s, lab, 0.2)
    PP.white(s, digits)
    return s


def hull(ctx):
    s = M.plastic(ctx, "pk_" + NAME, 4.4, seed=383, rough=0.4, scuff=1.0)
    ribs = np.mod(ctx.uvm[:, 0] / 0.006, 1.0) < 0.3
    s.shade[ribs] -= 1.0
    PP.glow(s, np.ones(ctx.N, dtype=bool), 0.2)
    return s


FNS = {"box": box_print, "inside": M.cardboard, "brass": M.brass, "hull": hull}


def _shell(p, a, b):
    """Loose shell lying from a (brass head) to b (crimped end)."""
    kit.seg(p, a, a + (b - a) * 0.25, [(0.0125, 0.0), (0.0125, 0.9), (0.0112, 1.0)], "brass", segments=10)
    kit.seg(p, a + (b - a) * 0.25, b, [(0.0112, 0.0), (0.0112, 0.93), (0.006, 1.0)], "hull", segments=10)


def build():
    p = Part(NAME)
    p.box((0, 0, 0), (W, D, H), "box", bevel=0.004)
    p.box((0, 0, H / 2 - 0.004), (W - 0.016, D - 0.016, 0.01), "inside", bevel=0.001)
    for i in range(5):
        for j in range(3):
            x = -W / 2 + 0.03 + i * (W - 0.06) / 4
            y = -D / 2 + 0.035 + j * (D - 0.07) / 2
            p.lathe([(0.0135, H / 2 - 0.004), (0.0135, H / 2 + 0.006), (0.0145, H / 2 + 0.007),
                     (0.0145, H / 2 + 0.01), (0.004, H / 2 + 0.0105), (0.004, H / 2 + 0.012), (0.0, H / 2 + 0.012)],
                    "brass", segments=10, center=(x, y, 0), cap_bottom=False)
    lid = p.box((0, 0, 0), (W, LID_T, D), "box", bevel=0.002)
    p.move(lid, LID_M)
    _shell(p, Vector((-0.1, -0.05, H / 2 + 0.024)), Vector((0.02, -0.07, H / 2 + 0.024)))
    _shell(p, Vector((0.11, -0.02, H / 2 + 0.024)), Vector((0.0, -0.035, H / 2 + 0.03)))
    return Model(NAME, [p], FNS, ppm=256, ground=None, ao_dist=0.05, ao_rays=12, ao_stride=1,
                 preview_elevation=28.0)
