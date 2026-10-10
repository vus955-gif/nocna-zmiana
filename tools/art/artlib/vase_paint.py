"""Greek painted pottery as pixel art: the decoration of a vase is laid
out on its unrolled surface (x = angle x reference radius, y = height,
metres) as a code per texel - clay, black gloss, added white, added red,
dilute glaze - and the figure scenes are drawn with the relief engine
(relief.py + greek_figures.py): in black-figure the silhouettes are gloss
with the incised lines scratched back to the clay, in red-figure the
background is gloss and the figures stay clay with gloss contour lines and
golden dilute details. ``surface()`` paints the baked vase atlas by
sampling the canvas at each texel's angle and height."""
import math

import numpy as np

from . import relief as RL
from .materials import P, _dither
from .painter import Surface

CLAY, GLOSS, WHITE, RED, DILUTE, LINE = range(6)


class Canvas:
    def __init__(self, r0, height, ppm=256):
        self.r0, self.h, self.ppm = r0, height, ppm
        self.W = int(round(math.tau * r0 * ppm))
        self.H = int(round(height * ppm))
        self.code = np.full((self.H, self.W), CLAY, np.int8)
        xs = (np.arange(self.W) + 0.5) / ppm
        ys = height - (np.arange(self.H) + 0.5) / ppm
        self.X, self.Y = np.meshgrid(xs, ys)

    @property
    def circ(self):
        return math.tau * self.r0

    def rows(self, z0, z1):
        return (self.Y >= z0) & (self.Y < z1)

    def band(self, z0, z1, code=GLOSS):
        self.code[self.rows(z0, z1)] = code

    def line(self, z, w=1.0 / 256, code=GLOSS):
        self.code[np.abs(self.Y - z) < w * 0.6] = code

    def rays(self, z0, z1, n, code=GLOSS):
        """Rays rising from the foot: black triangles."""
        m = self.rows(z0, z1)
        t = np.mod(self.X / self.circ * n, 1.0)
        hgt = (self.Y - z0) / (z1 - z0)
        self.code[m & (np.abs(t - 0.5) < 0.42 * (1 - hgt))] = code

    def tongues(self, z0, z1, n, colors=(GLOSS, RED)):
        m = self.rows(z0, z1)
        t = np.mod(self.X / self.circ * n, 1.0)
        k = np.floor(self.X / self.circ * n).astype(int) % 2
        hgt = (z1 - self.Y) / (z1 - z0)
        tongue = np.abs(t - 0.5) < 0.42 * np.sqrt(np.clip(1 - hgt ** 2, 0, 1))
        for i, c in enumerate(colors):
            self.code[m & tongue & (k == i)] = c

    def meander(self, z0, z1, code=GLOSS):
        cell = (z1 - z0) / 7.0
        key = np.array([[1, 1, 1, 1, 1, 1, 1, 1], [1, 0, 0, 0, 0, 0, 0, 0], [1, 0, 1, 1, 1, 1, 0, 0],
                        [1, 0, 1, 0, 0, 1, 0, 0], [1, 0, 1, 1, 0, 1, 0, 0], [1, 0, 0, 0, 0, 1, 0, 0],
                        [1, 1, 1, 1, 1, 1, 0, 0]])
        m = self.rows(z0, z1)
        n = max(1, int(round(self.circ / (cell * 8))))
        cw = self.circ / (n * 8)
        cx = np.floor(self.X / cw).astype(int) % 8
        cy = np.clip(np.floor((self.Y - z0) / cell).astype(int), 0, 6)
        self.code[m & (key[cy, cx] == 1)] = code

    def ivy(self, z0, z1, n=24, code=GLOSS):
        """An ivy (or laurel) wreath: a wavy stem with heart-shaped leaves."""
        m = self.rows(z0, z1)
        zc = (z0 + z1) / 2
        amp = (z1 - z0) * 0.2
        ph = self.X / self.circ * n * math.tau
        stem = np.abs(self.Y - (zc + amp * np.sin(ph))) < (z1 - z0) * 0.06
        t = np.mod(self.X / self.circ * n * 2, 1.0)
        side = np.where(np.floor(self.X / self.circ * n * 2).astype(int) % 2 == 0, 1, -1)
        leaf_c = zc + amp * np.sin(ph) + side * (z1 - z0) * 0.26
        leaf = ((t - 0.5) / 0.32) ** 2 + ((self.Y - leaf_c) / ((z1 - z0) * 0.2)) ** 2 < 1
        self.code[m & (stem | leaf)] = code

    def palmettes(self, z0, z1, n=10, code=GLOSS, fill=None):
        m = self.rows(z0, z1)
        cell = self.circ / n
        x = np.mod(self.X, cell) - cell / 2
        y = self.Y - z0
        r = np.hypot(x, y)
        ang = np.degrees(np.arctan2(x, np.maximum(y, 1e-6)))
        h = z1 - z0
        leaf = (np.abs(np.mod(ang + 15, 30) - 15) < 8) & (r < h * 0.92) & (r > h * 0.15) & (np.abs(ang) < 80)
        heart = r < h * 0.17
        self.code[m & (leaf | heart)] = code
        if fill is not None:
            self.code[m & ~(leaf | heart)] = fill

    def scene(self, x0, z0, w, h, draw, style="bf", ppm=None, seed=0):
        """Draws a figure scene into the panel (x0 .. x0 + w, z0 .. z0 + h)
        with the relief engine: ``draw(R)`` adds figures to a Relief of w x h
        metres. Black-figure: silhouettes in gloss, incisions in clay, a few
        details in added red and white. Red-figure: gloss ground, clay
        figures with gloss contours, dilute inner lines."""
        R = RL.Relief(w, h, int(ppm or self.ppm), ss=2, seed=seed)
        draw(R)
        maps = R.finish(ao_reach=0.01)
        fig = maps["tag"] != RL.BG
        lid = maps["lid"]
        seam = np.zeros_like(fig)                      # where one layer meets another
        seam[1:, :] |= lid[1:, :] != lid[:-1, :]
        seam[:, 1:] |= lid[:, 1:] != lid[:, :-1]
        groove = maps["cavity"] > 0.6
        H, W = fig.shape
        c0 = int(round(x0 * self.ppm)) % self.W
        r0 = int(round((self.h - (z0 + h)) * self.ppm))
        rows = np.clip(np.arange(H) + r0, 0, self.H - 1)
        cols = (np.arange(W) + c0) % self.W
        out = self.code[np.ix_(rows, cols)]
        tag = maps["tag"]
        edge = _border(fig)
        if style == "bf":
            out = np.where(fig, GLOSS, out)
            inc = fig & (seam | groove) & ~edge
            out = np.where(inc, CLAY, out)                             # incised lines
            out = np.where(fig & (tag == RL.HAIR) & ~inc, RED, out)    # added red: crests, manes, beards
        else:
            out = np.where(fig, CLAY, GLOSS)
            out = np.where(edge | (fig & seam), GLOSS, out)
            out = np.where(fig & groove & ~seam, DILUTE, out)
        self.code[np.ix_(rows, cols)] = out


def _border(mask):
    m = mask
    e = np.zeros_like(m)
    e[1:, :] |= m[1:, :] & ~m[:-1, :]
    e[:-1, :] |= m[:-1, :] & ~m[1:, :]
    e[:, 1:] |= m[:, 1:] & ~m[:, :-1]
    e[:, :-1] |= m[:, :-1] & ~m[:, 1:]
    return e


def surface(ctx, canvas, front=(0.0, 1.0), seed=1701, white_ground=False):
    """Paints the vase texels from the canvas: angle round the vertical axis
    (0 = ``front`` direction) and height."""
    x, y, z = ctx.p[:, 0], ctx.p[:, 1], ctx.p[:, 2]
    ang = np.arctan2(x * front[1] - y * front[0], x * front[0] + y * front[1])     # 0 at front
    u = np.mod(-ang + math.pi, math.tau) / math.tau * canvas.circ      # front at the canvas's middle
    col = np.clip((u * canvas.ppm).astype(int), 0, canvas.W - 1)
    row = np.clip(((canvas.h - z) * canvas.ppm).astype(int), 0, canvas.H - 1)
    code = canvas.code[row, col]
    s = Surface(ctx.N)
    shade_ao = -(1.0 - ctx.ao) * 4.0 - ctx.cavity(3.0) * 1.5 + ctx.edge(1.0) * 1.0
    clay = P["gr_white_slip"] if white_ground else P["gr_clay"]
    s.use_ramp(clay, shade=(3.0 if white_ground else 5.4) + shade_ao * 0.8 + ctx.fbm(6.0, 2, seed) * 0.5
               + _dither(ctx, 0.5, seed + 1))
    g = code == GLOSS
    s.use_ramp(P["gr_gloss"], mask=g, shade=3.0 + shade_ao * 0.5 + _dither(ctx, 0.6, seed + 2))
    s.use_ramp(P["gr_white_slip"], mask=code == WHITE, shade=np.full(ctx.N, 3.0) + shade_ao * 0.5)
    s.use_ramp(P["gr_miltos"], mask=code == RED, shade=np.full(ctx.N, 2.4) + shade_ao * 0.4)
    s.use_ramp(P["gr_clay"], mask=code == DILUTE, shade=np.full(ctx.N, 2.6) + shade_ao * 0.4)
    # gloss is glossy; the clay matte; worn rims and handles lose some gloss
    worn = ctx.edge(2.0) * (ctx.fbm(9.0, 2, seed + 3) > 0.2)
    s.rough = np.where(g, 0.18 + worn * 0.3, 0.72) + ctx.rand(seed + 4) * 0.04
    # chips knocked off the gloss back to the clay
    chip = g & (ctx.fbm(14.0, 3, seed + 5) > 0.55)
    s.use_ramp(clay, mask=chip, shade=np.full(ctx.N, 3.6))
    s.height = chip * -0.0006 + (code == WHITE) * 0.0003
    return s
