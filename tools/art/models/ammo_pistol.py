"""Pickup: a cardboard box of pistol cartridges, lid flipped open, rows of
brass cases with copper bullets showing. Steel-blue pre-war print (the
pistol's colour in the HUD and on the floor, _pickup_palette.py) with a
cream label on the front and the slot digit "2" in cream on both ends and
on the open lid. A brick rather than a tray, so it reads apart from the
flat box of shells: 0.20 x 0.15 m, 0.11 m to the rim, bigger than life so
it reads across a room. The blue print glows faintly in the dark (emission
map), the digits a little more. Origin at the centre of the box (the
pickup spins and bobs around it); faces -Y."""
import numpy as np
from mathutils import Vector

from artlib import kit, pixelfont
from artlib import materials as M
from artlib.geo import Part
from artlib.kit import R, T
from artlib.model import Model
from models import _pickup_palette as PP

NAME = "ammo_pistol"
W, D, H = 0.2, 0.15, 0.11
LID_T = 0.006
LID_M = T(0, D / 2 + 0.01, H / 2 + D / 2 - 0.01) @ R('X', -12)
LID_N = np.array((LID_M.to_3x3() @ Vector((0, 1, 0))).normalized())      # the lid's printed outside
LID_C = PP.face_uv(LID_M @ Vector((0, LID_T / 2, 0)), LID_N)
DIGIT = PP.digit(NAME)


def box_print(ctx):
    """Cardboard printed steel blue, a cream label with pseudo-text on the
    front, the slot digit on both ends and on the lid's outside."""
    s = M.cardboard(ctx, seed=371, center=4.6)
    x, z = ctx.p[:, 0], ctx.p[:, 2]
    side = np.abs(ctx.n[:, 1]) > 0.6
    printed = side | (np.abs(ctx.n[:, 0]) > 0.6)
    s.use_ramp(M.P["pk_" + NAME], mask=printed, shade=np.full(ctx.N, 4.4) + ctx.fbm(20.0, 2, 3) * 0.6
               + M._dither(ctx, 0.8, 4) + ctx.edge_soft(3.0) * 1.2 - (1.0 - ctx.ao) * 2.0)
    front = ctx.n[:, 1] < -0.7
    lab = front & (np.abs(x) < 0.07) & (np.abs(z + 0.005) < 0.028)
    s.use_ramp(M.P["cloth_white"], mask=lab, shade=np.full(ctx.N, 6.2) + M._dither(ctx, 0.6, 5))
    ink = lab & M.text_marks(ctx, 0.005, 6)
    s.use_ramp(M.P["hair"], mask=ink, shade=np.full(ctx.N, 1.0))
    band = side & (np.abs(z + 0.042) < 0.004)
    s.use_ramp(M.P["cloth_white"], mask=band, shade=np.full(ctx.N, 5.6) + M._dither(ctx, 0.6, 7))
    ends = (np.abs(ctx.n[:, 0]) > 0.7) & pixelfont.stamp(ctx, DIGIT, 0.0, 0.0, scale=2)
    lid = (ctx.n @ LID_N > 0.9) & (z > H / 2 + 0.004) & pixelfont.stamp(ctx, DIGIT, LID_C[0], LID_C[1], scale=2)
    digits = (ends | lid) & (ctx.rand(9) > 0.04)
    s.use_ramp(M.P["cloth_white"], mask=digits, shade=np.full(ctx.N, 6.4) + M._dither(ctx, 0.5, 8))
    s.rough = np.full(ctx.N, 0.9)
    PP.glow(s, printed & ~lab & ~digits)
    PP.white(s, lab | band, 0.2)
    PP.white(s, digits)
    return s


def copper(ctx):
    return M.brass(ctx, seed=373, ramp="bronze_metal", tarnish_amount=1.0)


FNS = {"box": box_print, "lid": M.cardboard, "brass": M.brass, "copper": copper}


def build():
    p = Part(NAME)
    p.box((0, 0, 0), (W, D, H), "box", bevel=0.004)
    # the open top: a darker recess the cartridges stand in
    p.box((0, 0, H / 2 - 0.004), (W - 0.016, D - 0.016, 0.01), "lid", bevel=0.001)
    for i in range(5):
        for j in range(3):
            x = -W / 2 + 0.03 + i * (W - 0.06) / 4
            y = -D / 2 + 0.03 + j * (D - 0.06) / 2
            p.lathe([(0.0105, H / 2 - 0.004), (0.0105, H / 2 + 0.014), (0.0095, H / 2 + 0.016)], "brass",
                    segments=8, center=(x, y, 0), cap_bottom=False, cap_top=False)
            p.lathe([(0.0095, H / 2 + 0.016), (0.009, H / 2 + 0.024), (0.006, H / 2 + 0.031), (0.0, H / 2 + 0.034)],
                    "copper", segments=8, center=(x, y, 0), cap_bottom=False)
    # lid, hinged at the back top edge, standing open and leaning back
    lid = p.box((0, 0, 0), (W, LID_T, D), "box", bevel=0.002)
    p.move(lid, LID_M)
    return Model(NAME, [p], FNS, ppm=256, ground=None, ao_dist=0.05, ao_rays=12, ao_stride=1,
                 preview_elevation=28.0)
