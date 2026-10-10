"""Old-master landscape in a gilded frame, with a brass picture light.
Canvas 1.8 x 1.3 m (pixel-painted: evening sky, hills, a ruined temple, a
lake, craquelure and yellowed varnish, limited palette). Origin at the canvas
centre on the wall plane; hang it by its centre."""
import math

import numpy as np
from mathutils import Matrix

from artlib import materials as M
from artlib import noise
from artlib.geo import Part
from artlib.model import Model
from artlib.painter import Surface

CW, CH = 1.8, 1.3
FRAME = 0.15

PALETTE = M.hexramp(
    "#0d0b0a", "#1a1512", "#2a211a", "#3a2e22", "#4d3d2a", "#1e2522", "#2c3a30", "#3f4f3c",
    "#56613f", "#1a2430", "#2b3a48", "#465666", "#6b7a80", "#8c8a78", "#b39a6a", "#d2ae70",
    "#e8c887", "#f3e0a8", "#7a4a2a", "#a0603a", "#c07a44", "#5a2e20")


def _canvas(ctx):
    x = ctx.uvm[:, 0]
    z = ctx.uvm[:, 1]
    u = (x + CW / 2) / CW
    v = (z + CH / 2) / CH
    n = len(u)
    q = np.stack([u * 6.0, v * 6.0, np.zeros(n)], axis=1)

    def f(freq, seed, octs=4):
        return noise.fbm(np.stack([u * freq, v * freq, np.zeros(n)], axis=1), octs, seed)

    col = np.zeros((n, 3))
    # sky: dark teal zenith -> amber horizon, sun glow at right, cloud banks
    t = np.clip((v - 0.38) / 0.62, 0, 1)
    zen = np.array([0.10, 0.15, 0.2])
    hor = np.array([0.82, 0.6, 0.34])
    sky = hor[None] * (1 - t[:, None]) ** 1.3 + zen[None] * (1 - (1 - t[:, None]) ** 1.3)
    sun = np.exp(-(((u - 0.76) / 0.12) ** 2 + ((v - 0.45) / 0.08) ** 2))
    sky += sun[:, None] * np.array([0.35, 0.25, 0.1])
    clouds = np.clip(f(3.0, 5) * 1.6 + 0.1 - np.abs(v - 0.72) * 1.5, 0, 1)
    sky = sky * (1 - clouds[:, None] * 0.55) + clouds[:, None] * np.array([0.45, 0.33, 0.25]) * 0.6
    col[:] = sky
    # far hills (hazy blue) and near hills (olive/brown)
    h1 = 0.44 + f(2.0, 11, 3) * 0.06 - np.abs(u - 0.6) * 0.03
    far = v < h1
    col[far] = np.array([0.36, 0.42, 0.45]) * 0.9 + sky[far] * 0.25
    h2 = 0.36 + f(3.5, 13, 3) * 0.07 + np.exp(-((u - 0.34) / 0.12) ** 2) * 0.09
    near = v < h2
    shade = np.clip(0.5 + f(8.0, 17, 3) * 0.8, 0, 1)
    col[near] = (np.array([0.22, 0.25, 0.16]) * (0.6 + shade[near] * 0.6)[:, None])
    # ruined temple on the hill: columns + broken entablature
    for k, cx in enumerate(np.linspace(0.27, 0.41, 5)):
        broken = [0.0, 0.03, 0.0, 0.05, 0.015][k]
        colm = (np.abs(u - cx) < 0.009) & (v > h2 - 0.02) & (v < 0.5 - broken)
        col[colm] = np.array([0.82, 0.74, 0.58]) * (0.7 + 0.3 * (u[colm] < cx))[:, None]
    ent = (u > 0.26) & (u < 0.36) & (v > 0.5) & (v < 0.52)
    col[ent] = np.array([0.72, 0.64, 0.5])
    # a dark tree at the left edge: trunk + three canopy masses, lit rim toward the sun
    trunk = (np.abs(u - 0.12 - (v - 0.3) * 0.08) < 0.013) & (v > 0.2) & (v < 0.62)
    canopy = np.zeros(n, dtype=bool)
    rim = np.zeros(n, dtype=bool)
    edge = f(12.0, 21, 3) * 0.03
    for cu, cv, r in ((0.11, 0.74, 0.11), (0.19, 0.64, 0.08), (0.04, 0.6, 0.09), (0.15, 0.84, 0.07)):
        d = np.sqrt(((u - cu) * CW / CH) ** 2 + (v - cv) ** 2) + edge
        canopy |= d < r
        rim |= (d < r) & (d > r - 0.018) & (u > cu)
    tree = trunk | canopy
    col[tree] = np.array([0.07, 0.09, 0.06]) + np.clip(f(14.0, 23, 2), 0, 1)[tree, None] * np.array([0.08, 0.1, 0.05])
    col[rim & canopy] = np.array([0.36, 0.34, 0.18])
    # lake bottom-right reflecting the sky, foreground bank
    lake = (v < 0.22) & (u > 0.4) & (v > 0.07 + f(4.0, 27, 2) * 0.03)
    refl = hor * 0.75 + np.array([0.0, 0.02, 0.05])
    ripple = (np.sin(v * 220.0 + f(20.0, 29, 2) * 6.0) > 0.6)
    col[lake] = refl * (0.75 + 0.2 * ripple[lake])[:, None] * (0.6 + 0.4 * sun[lake] * 2.0)[:, None]
    bank = (v < 0.12 + f(5.0, 31, 3) * 0.05) & ~lake
    col[bank] = np.array([0.14, 0.11, 0.08]) * (0.7 + 0.5 * np.clip(f(12.0, 33, 2), 0, 1))[bank, None]
    # varnish + vignette
    vig = np.clip(1.0 - ((u - 0.5) ** 2 + (v - 0.5) ** 2) * 1.1, 0.6, 1.0)
    col = col * vig[:, None] * np.array([1.0, 0.94, 0.8])
    # brush texture + craquelure
    col *= (0.97 + 0.03 * ctx.rand(3))[:, None]
    f1, f2, _ = noise.worley(np.stack([u * 40.0, v * 28.0, np.zeros(n)], axis=1), 41)
    crack = (f2 - f1) < 0.06
    col[crack] *= 0.72
    # limited palette: snap to the nearest swatch
    d = ((col[:, None, :] - PALETTE[None]) ** 2).sum(-1)
    s = Surface(n)
    s.albedo = PALETTE[np.argmin(d, axis=1)]
    s.rough = np.full(n, 0.35) + crack * 0.3
    s.height = crack * -0.0006
    return s


def build():
    p = Part("painting")
    # canvas face 4 cm proud of the wall
    f = p.poly([(-CW / 2, -0.04, -CH / 2), (CW / 2, -0.04, -CH / 2), (CW / 2, -0.04, CH / 2), (-CW / 2, -0.04, CH / 2)],
               "canvas")[0]
    f.normal_update()
    if f.normal.y > 0:
        f.normal_flip()
    # gilded frame: stepped ogee swept round the canvas (clockwise from the viewer)
    x0, x1, z0, z1 = -CW / 2, CW / 2, -CH / 2, CH / 2
    path = [(x0, z0), (x0, z1), (x1, z1), (x1, z0)]
    prof = [(0.04, -0.005), (0.065, 0.0), (0.075, 0.03), (0.1, 0.05), (0.1, 0.075), (0.085, 0.1),
            (0.07, 0.115), (0.075, 0.135), (0.05, FRAME), (0.0, FRAME)]
    p.sweep(prof, path, "gold", closed=True)
    # corner cartouches and a crest
    for cx in (x0 - FRAME / 2 + 0.01, x1 + FRAME / 2 - 0.01):
        for cz in (z0 - FRAME / 2 + 0.01, z1 + FRAME / 2 - 0.01):
            p.box((cx, -0.1, cz), (0.1, 0.03, 0.1), "gold", bevel=0.015)
    p.box((0, -0.1, z1 + FRAME / 2 - 0.01), (0.2, 0.03, 0.08), "gold", bevel=0.015)
    # title plaque
    p.box((0, -0.03, z0 - FRAME - 0.1), (0.24, 0.01, 0.07), "brass", bevel=0.004)
    # picture light: wall block, arm, horizontal hood with a lamp slit underneath
    top = z1 + FRAME
    p.box((0, -0.02, top + 0.1), (0.1, 0.04, 0.06), "brass", bevel=0.006)
    p.box((0, -0.13, top + 0.12), (0.025, 0.2, 0.025), "brass", bevel=0.005)
    hood = p.lathe([(0.0, -0.56), (0.035, -0.55), (0.045, -0.5), (0.045, 0.5), (0.035, 0.55), (0.0, 0.56)],
                   "brass", segments=10)
    p.move(hood, Matrix.Translation((0, -0.24, top + 0.12)) @ Matrix.Rotation(math.radians(90), 4, 'Y'))
    p.box((0, -0.24, top + 0.077), (0.96, 0.028, 0.01), "lamp_warm")
    return Model("painting", [p], {"canvas": _canvas, "gold": M.gold, "brass": M.brass, "lamp_warm": M.lamp_warm},
                 ppm=128, ground=None, ao_dist=0.2)
