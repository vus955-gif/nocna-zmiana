"""The pistol locker in the guards' room: a wall-mounted steel cabinet in
institutional grey-green enamel, chipped to bare steel, stencilled label
and a brass lock on the door, piano hinge on the left, a felt-lined shelf
inside where the pistol lies. 0.52 x 0.24 x 0.42 m.

Origin on the wall plane (y = 0) at the bottom centre of the cabinet; it
sticks out toward -Y. Parts:
    locker  (0, 0, 0)                 open box, shelf, felt
    door    (-0.26, -0.24, 0.21)      pivot on the hinge line; opens by turning about Z
                                      (negative angle swings it out toward -Y)
Marker: Pistol (0, -0.12, 0.075), where the pistol lies on the felt."""
import numpy as np

from artlib import kit
from artlib import materials as M
from artlib.geo import Part
from artlib.kit import R, T
from artlib.model import Model

W, D, H, TH = 0.52, 0.24, 0.42, 0.012


def olive(ctx):
    return M.enamel(ctx, "paint_olive", 5.0, seed=421, chip=1.0, gloss=0.45, under="steel")


def door_paint(ctx):
    s = olive(ctx)
    front = ctx.n[:, 1] < -0.7
    x, z = ctx.p[:, 0], ctx.p[:, 2]
    plate = front & (np.abs(x + 0.02) < 0.11) & (np.abs(z - 0.31) < 0.03)
    stencil = plate & M.text_marks(ctx, 0.016, 431, density=0.6, u=x * 1.0, v=z * 1.0)
    s.use_ramp(M.P["cloth_white"], mask=stencil & (s.ramp_id == 0), shade=np.full(ctx.N, 5.6) + M._dither(ctx, 1.2, 3))
    return s


FNS = {"olive": olive, "door": door_paint, "inside": lambda c: M.enamel(c, "paint_olive", 3.2, seed=423, chip=0.3,
                                                                          gloss=0.6, under="steel"),
       "felt": M.velvet, "brass": M.brass, "steel": lambda c: M.steel(c, seed=425, center=7.5, dent=0.1)}


def build():
    body = Part("locker")
    body.box((0, -TH / 2, H / 2), (W, TH, H), "inside")                                 # back
    for sx in (-1, 1):
        body.box((sx * (W / 2 - TH / 2), -D / 2, H / 2), (TH, D, H), "olive", bevel=0.003)   # sides
    body.box((0, -D / 2, TH / 2), (W, D, TH), "olive", bevel=0.003)                     # bottom
    body.box((0, -D / 2, H - TH / 2), (W, D, TH), "olive", bevel=0.003)                 # top
    body.box((0, -D / 2, 0.055), (W - 2 * TH, D - 0.02, 0.008), "inside")               # shelf
    body.box((0, -D / 2 - 0.005, 0.064), (W - 0.06, D - 0.05, 0.01), "felt", bevel=0.003)
    # the four corners inside the door frame get a lip
    for z in (TH + 0.002, H - TH - 0.002):
        body.box((0, -D + 0.004, z), (W - 2 * TH, 0.008, 0.006), "olive")
    door = Part("door", origin=(-W / 2, -D, H / 2))
    door.box((0, -D - 0.008, H / 2), (W, 0.016, H), "door", bevel=0.004)
    door.box((0, -D - 0.017, H / 2), (W - 0.06, 0.004, H - 0.06), "door", bevel=0.002)   # pressed panel
    door.box((0.2, -D - 0.021, 0.2), (0.034, 0.006, 0.05), "brass", bevel=0.002)        # lock escutcheon
    kit.seg(door, (0.2, -D - 0.025, 0.2), (0.2, -D - 0.021, 0.2), [(0.006, 0), (0.006, 1)], "steel", segments=8)
    door.box((0.2, -D - 0.026, 0.2), (0.002, 0.001, 0.009), "felt")                     # keyhole
    for z in (0.08, 0.34):
        kit.seg(door, (-W / 2 - 0.004, -D - 0.006, z - 0.035), (-W / 2 - 0.004, -D - 0.006, z + 0.035),
                [(0.007, 0), (0.007, 1)], "steel", segments=8)                          # hinges
    return Model("pistol_locker", [body, door], FNS, ppm=256, ground=None, ao_dist=0.08, ao_rays=12, ao_stride=1,
                 markers=[("Pistol", (0.0, -0.12, 0.075), "locker")], preview_elevation=12.0)
