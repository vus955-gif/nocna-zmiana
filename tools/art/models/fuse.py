"""Objective item: a big old ceramic cartridge fuse from the museum's switch
room. Cream glazed porcelain body with ribs and a paper rating label,
brass end caps with knife-blade contacts. 0.34 m end to end, lying along
X. Origin at the centre; the label faces -Y."""
import numpy as np

from artlib import kit
from artlib import materials as M
from artlib.geo import Part
from artlib.model import Model

L = 0.2          # porcelain body
R = 0.036


def fuse_label(ctx):
    s = M.label(ctx, seed=401, size=0.005)
    ring = np.abs(np.abs(ctx.p[:, 0]) - 0.03) < 0.004
    s.use_ramp(M.P["cloth_red"], mask=ring, shade=np.full(ctx.N, 5.0))
    return s


FNS = {"porcelain": M.porcelain, "brass": M.brass, "label": fuse_label}


def build():
    p = Part("fuse")
    ribs = lambda i, j: 1.0 + (0.06 if j in (1, 3, 9, 11) else 0.0)
    kit.seg(p, (-L / 2, 0, 0), (L / 2, 0, 0),
            [(R, 0.0), (R, 0.06), (R, 0.1), (R, 0.14), (R, 0.18), (R, 0.26), (R, 0.74), (R, 0.82),
             (R, 0.86), (R, 0.9), (R, 0.94), (R, 1.0)], "porcelain", segments=14, ring_scale=ribs)
    kit.seg(p, (-0.05, 0, 0), (0.05, 0, 0), [(R + 0.0015, 0.0), (R + 0.0015, 1.0)], "label", segments=14,
            caps=False)
    for sx in (-1, 1):
        x0 = sx * L / 2
        kit.seg(p, (x0 - sx * 0.012, 0, 0), (x0 + sx * 0.03, 0, 0),
                [(R + 0.005, 0.0), (R + 0.006, 0.2), (R + 0.006, 0.75), (R - 0.004, 0.9), (0.012, 1.0)], "brass",
                segments=14)
        p.box((x0 + sx * 0.052, 0, 0), (0.05, 0.005, 0.032), "brass", bevel=0.0015)          # knife blade
        kit.seg(p, (x0 + sx * 0.068, -0.006, 0), (x0 + sx * 0.068, 0.006, 0), [(0.006, 0), (0.006, 1)], "brass",
                segments=6)                                                                    # rivet
    return Model("fuse", [p], FNS, ppm=384, ground=None, ao_dist=0.04, ao_rays=12, ao_stride=1,
                 preview_elevation=22.0)
