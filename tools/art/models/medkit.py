"""Pickup: the museum's old first-aid tin. White stove-enamel box with a red
cross front and back, chipped to rusty steel at the edges, black carrying
handle, two steel latches, hinges on the back. 0.30 x 0.11 x 0.22 m.
Origin at the box centre; faces -Y."""
import numpy as np

from artlib import kit
from artlib import materials as M
from artlib.geo import Part
from artlib.kit import R, T
from artlib.model import Model

W, D, H = 0.3, 0.11, 0.22


def tin(ctx):
    s = M.enamel(ctx, "enamel_white", 5.6, seed=391, chip=1.0, gloss=0.3)
    x, z = ctx.p[:, 0], ctx.p[:, 2] - 0.005
    face = np.abs(ctx.n[:, 1]) > 0.7
    arm, half = 0.026, 0.075
    cross = face & (((np.abs(x) < arm) & (np.abs(z) < half)) | ((np.abs(z) < arm) & (np.abs(x) < half)))
    painted = cross & (s.ramp_id == 0)
    s.use_ramp(M.P["cloth_red"], mask=painted, shade=np.full(ctx.N, 5.0) + ctx.fbm(10.0, 2, 3) * 0.6
               + M._dither(ctx, 0.6, 4))
    # the lid seam: a dark line round the box two-thirds up
    seam = (np.abs(ctx.p[:, 2] - 0.055) < ctx.texel * 0.8) & ~face | \
           (face & (np.abs(ctx.p[:, 2] - 0.055) < ctx.texel * 0.8) & ~cross)
    s.shade[seam] -= 3.0
    return s


FNS = {"tin": tin, "handle": M.rubber, "steel": lambda c: M.steel(c, seed=393, center=8.0, dent=0.2)}


def build():
    p = Part("medkit")
    p.box((0, 0, 0), (W, D, H), "tin", bevel=0.014)
    # lid rim
    p.box((0, 0, 0.055), (W + 0.004, D + 0.004, 0.008), "tin", bevel=0.003)
    # handle: two posts and a grip
    for sx in (-1, 1):
        p.box((sx * 0.06, 0, H / 2 + 0.008), (0.014, 0.022, 0.018), "steel", bevel=0.003)
    p.tube([(-0.06, 0, H / 2 + 0.014), (-0.055, 0, H / 2 + 0.04), (-0.03, 0, H / 2 + 0.05), (0.03, 0, H / 2 + 0.05),
            (0.055, 0, H / 2 + 0.04), (0.06, 0, H / 2 + 0.014)], 0.009, "handle", sides=8)
    # latches on the front, hinges on the back
    for sx in (-1, 1):
        p.box((sx * 0.1, -D / 2 - 0.004, 0.055), (0.024, 0.008, 0.04), "steel", bevel=0.003)
        kit.seg(p, (sx * 0.1 - 0.02, D / 2 + 0.004, 0.06), (sx * 0.1 + 0.02, D / 2 + 0.004, 0.06),
                [(0.006, 0), (0.006, 1)], "steel", segments=6)
    return Model("medkit", [p], FNS, ppm=256, ground=None, ao_dist=0.05, ao_rays=12, ao_stride=1,
                 preview_elevation=18.0)
