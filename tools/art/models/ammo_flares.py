"""Pickup: a box of four signal flares. Orange-printed cardboard box with a
dark band and white lettering "RACE" / "SYGNAŁOWE" on the front (real
letters, artlib/pixelfont.py), lid folded open behind, four flare
cartridges standing in a row with their domed red caps up. Signal orange
is the flare gun's colour in the HUD and on the floor (_pickup_palette.py);
the flares' hulls are orange with two white bands (the signal pattern that
tells them from the red shells and the violet fire-arrows), the slot digit
"5" in white on both ends and on the lid; print, bands and digits glow
faintly in the dark. A bit larger than life so it reads across a room:
0.19 x 0.06 x 0.09 m box, flares 0.13 m.

Origin at the box centre (the game spins and bobs pickups); faces -Y.
Part: ammo_flares.
"""
import numpy as np
from mathutils import Vector

from artlib import kit, pixelfont
from artlib import materials as M
from artlib.geo import Part
from artlib.kit import R, T
from artlib.model import Model
from models import _pickup_palette as PP

NAME = "ammo_flares"
W, D, H = 0.19, 0.062, 0.09
FR = 0.0165                     # flare radius
TITLE = pixelfont.trim(pixelfont.render("RACE", bold=True))
SUB = pixelfont.trim(pixelfont.render("SYGNAŁOWE"))
DIGIT = PP.digit(NAME)
LID_T = 0.004
LID_M = T(0, D / 2, H / 2) @ R('X', -20) @ T(0, 0.0, D / 2)
LID_N = np.array((LID_M.to_3x3() @ Vector((0, 1, 0))).normalized())
LID_C = PP.face_uv(LID_M @ Vector((0, LID_T / 2, 0)), LID_N)
BANDS = (H / 2 + 0.022, H / 2 + 0.046)      # z of the two white bands round the hulls


def box_print(ctx):
    s = M.cardboard(ctx, seed=551, center=4.8)
    z = ctx.p[:, 2]
    printed = np.abs(ctx.n[:, 2]) < 0.6
    s.use_ramp(M.P["plastic_orange"], mask=printed, shade=np.full(ctx.N, 5.6) + ctx.fbm(18.0, 2, 3) * 0.5
               + M._dither(ctx, 0.7, 4) + ctx.edge_soft(3.0) * 1.2 - (1.0 - ctx.ao) * 2.5 - ctx.cavity(3.0) * 1.5)
    front = ctx.n[:, 1] < -0.7
    band = front & (np.abs(z - 0.004) < 0.03)
    s.use_ramp(M.P["plastic_black"], mask=band, shade=np.full(ctx.N, 2.4) + M._dither(ctx, 0.8, 5))
    t1 = front & pixelfont.stamp(ctx, TITLE, 0.0, 0.013)
    t2 = front & pixelfont.stamp(ctx, SUB, 0.0, -0.012)
    ends = (np.abs(ctx.n[:, 0]) > 0.7) & (z < H / 2) & pixelfont.stamp(ctx, DIGIT, 0.0, 0.0, scale=2)
    lid = (ctx.n @ LID_N > 0.9) & (z > H / 2 + 0.003) & pixelfont.stamp(ctx, DIGIT, LID_C[0], LID_C[1], scale=2)
    ink = (t1 | t2 | ends | lid) & (ctx.rand(7) > 0.03)
    s.use_ramp(M.P["enamel_white"], mask=ink, shade=np.full(ctx.N, 6.2) + M._dither(ctx, 0.6, 6))
    s.rough = np.full(ctx.N, 0.85)
    PP.glow(s, printed & ~band & ~ink)
    PP.white(s, ink)
    return s


def cap(ctx):
    """Domed red cap with the eight folds of a crimped star closure on top."""
    s = M.plastic(ctx, "paint_red", 5.2, seed=553, rough=0.38, scuff=0.8)
    pitch = (W - 0.02) / 4
    i = np.clip(np.floor((ctx.p[:, 0] + W / 2 - 0.01) / pitch), 0, 3)
    cx = -W / 2 + 0.01 + pitch * (i + 0.5)
    ang = np.arctan2(ctx.p[:, 1], ctx.p[:, 0] - cx)
    fold = (ctx.n[:, 2] > 0.55) & (np.mod(ang / (2 * np.pi) * 8.0, 1.0) < 0.2)
    s.shade[fold] -= 1.4
    s.height = s.height - fold * 0.0003
    return s


def hull(ctx):
    """Signal-orange hull, two white bands."""
    s = M.plastic(ctx, "pk_" + NAME, 4.6, seed=555, rough=0.7, scuff=0.6, speckle=0.5)
    z = ctx.p[:, 2]
    bands = np.zeros(ctx.N, dtype=bool)
    for zb in BANDS:
        bands |= np.abs(z - zb) < 0.0045
    s.use_ramp(M.P["enamel_white"], mask=bands, shade=np.full(ctx.N, 5.8) + M._dither(ctx, 0.6, 9))
    PP.glow(s, ~bands)
    PP.white(s, bands, 0.4)
    return s


FNS = {"box": box_print, "inside": lambda c: M.cardboard(c, seed=557, center=3.6), "cap": cap, "hull": hull}


def build():
    p = Part(NAME)
    p.box((0, 0, 0), (W, D, H), "box", bevel=0.003)
    p.box((0, 0, H / 2 - 0.003), (W - 0.012, D - 0.012, 0.008), "inside", bevel=0.001)
    pitch = (W - 0.02) / 4
    for i in range(4):
        x = -W / 2 + 0.01 + pitch * (i + 0.5)
        z0 = H / 2 - 0.004
        lean = (i - 1.5) * 1.2
        f = kit.seg(p, (0, 0, 0), (0, 0, 0.062), [(FR, 0.0), (FR, 1.0)], "hull", segments=12, caps=False)
        f += kit.seg(p, (0, 0, 0.062), (0, 0, 0.078), [(FR * 1.05, 0.0), (FR * 1.05, 0.3), (FR * 0.95, 0.7),
                                                       (FR * 0.6, 1.0)], "cap", segments=12)
        p.move(f, T(x, 0.003 * (i % 2), z0) @ R('Y', lean))
    # lid: hinged at the back edge, folded open and back
    lid = p.box((0, 0, 0), (W, LID_T, D), "box", bevel=0.0015)
    p.move(lid, LID_M)
    flap = p.box((0, 0, 0), (W - 0.01, 0.003, 0.018), "box", bevel=0.001)
    p.move(flap, T(0, D / 2, H / 2) @ R('X', -20) @ T(0, 0.0, D) @ R('X', -70) @ T(0, 0, 0.009))
    return Model(NAME, [p], FNS, ppm=320, ground=None, ao_dist=0.05, ao_rays=12, ao_stride=1,
                 preview_elevation=22.0)
