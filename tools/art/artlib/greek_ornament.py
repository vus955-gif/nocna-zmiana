"""Carved and painted Greek ornament as per-texel patterns (u along the
moulding, v across it, metres): egg-and-dart, bead-and-reel, the painted
anthemion (palmette and lotus with scrolls), the meander, Doric glyphs,
gold stars on blue coffers. Each returns height (metres) and masks the
material functions use to shade the marble or lay the paint."""
import math

import numpy as np

from .materials import P, _dither, smoothstep
from .greek import marble_body, paint_traces


def egg_dart(u, v, L, period=0.125, depth=0.008):
    """Ovolo of eggs in shells with darts between. ``v`` 0..L across the
    moulding (0 = bottom edge). Returns (height, egg, shell, dart)."""
    x = np.mod(u, period) - period / 2
    vc = L * 0.5
    ey = (v - vc) / (L * 0.42)
    ex = x / (period * 0.33)
    r2 = ex * ex + ey * ey
    egg = r2 < 1.0
    shell_r = np.sqrt((x / (period * 0.42)) ** 2 + ((v - vc + L * 0.06) / (L * 0.52)) ** 2)
    shell = (shell_r < 1.0) & ~egg
    dx = np.abs(np.abs(x) - period / 2)
    dart = (dx < period * 0.06 + (v - L * 0.15) / L * period * 0.08) & (v > L * 0.15) & (v < L * 0.9)
    h = np.where(egg, depth * np.sqrt(np.clip(1 - r2, 0, 1)), 0.0)
    h -= np.where(shell, depth * 0.35, 0.0)
    h += np.where(dart, depth * 0.3, 0.0)
    return h, egg, shell, dart


def bead_reel(u, v, L, period=0.08, depth=0.006):
    x = np.mod(u, period)
    vy = (v - L / 2) / (L / 2)
    bead = ((x - period * 0.32) / (period * 0.3)) ** 2 + vy ** 2 < 1.0
    reel = (np.abs(x - period * 0.8) < period * 0.08) & (np.abs(vy) < 0.7)
    h = np.where(bead, depth * np.sqrt(np.clip(1 - ((x - period * 0.32) / (period * 0.3)) ** 2 - vy ** 2, 0, 1)), 0.0)
    h += np.where(reel, depth * 0.5, 0.0)
    return h, bead, reel


def anthemion(u, v, L, period=0.5):
    """Palmette and lotus alternating, joined by S-scrolls: masks of the
    ornament (painted, not carved). v 0..L."""
    x = np.mod(u, period)
    cx = period * 0.25
    lx = period * 0.75
    base = L * 0.15
    # palmette: a fan of leaves from a heart at (cx, base)
    dxp = x - cx
    dyp = v - base
    r = np.hypot(dxp, dyp)
    ang = np.degrees(np.arctan2(dxp, np.maximum(dyp, 1e-6)))
    leaf = (np.abs(np.mod(ang + 18.0, 36.0) - 18.0) < 9.5) & (r < L * 0.8 * (1 - np.abs(ang) / 260))         & (r > L * 0.12) & (np.abs(ang) < 82)
    heart = r < L * 0.13
    # lotus: a pointed calyx with two outer petals
    dxl = x - lx
    dyl = v - base
    lotus = (np.abs(dxl) < (L * 0.75 - dyl) * 0.25) & (dyl > 0) & (dyl < L * 0.75)
    side = (np.abs(np.abs(dxl) - L * 0.18 - dyl * 0.2) < L * 0.05) & (dyl > 0) & (dyl < L * 0.55)
    # S-scrolls along the bottom joining them
    sx = np.mod(x, period / 2) - period / 4
    scroll = (np.abs(np.hypot(sx, v - L * 0.12) - L * 0.1) < L * 0.035) & (v < L * 0.3)
    return leaf | heart, lotus | side, scroll


def meander(u, v, L, period=None):
    """Greek key (one strand, square spiral) across a band of height L.
    Returns the mask of the key line."""
    period = period or L
    cell = L / 5.0
    x = np.floor(np.mod(u, period) / cell).astype(int)
    y = np.clip(np.floor(v / cell).astype(int), 0, 4)
    # a 5 x 5 key pattern (1 = line)
    key = np.array([
        [1, 1, 1, 1, 1],
        [0, 0, 0, 0, 1],
        [1, 1, 1, 0, 1],
        [1, 0, 0, 0, 1],
        [1, 0, 1, 1, 1],
    ])
    xi = np.clip(x, 0, 4)
    return key[4 - y, xi] == 1


def star(u, v, cx, cy, r, points=8):
    """A painted star (the gold stars of blue coffers)."""
    dx, dy = u - cx, v - cy
    a = np.arctan2(dy, dx)
    rr = np.hypot(dx, dy)
    lim = r * (0.42 + 0.58 * np.abs(np.cos(a * points / 2)) ** 3)
    return rr < lim


def carved_marble(ctx, h, seed, extra_dark=None, center=7.4, vein=0.4):
    """Marble whose shading follows a carved height pattern ``h`` (flat
    geometry: the light-side slope brightens, the dark side and the sunk
    parts darken, like a hand-painted relief)."""
    s = marble_body(ctx, seed, center=center, vein=vein, warm=0.7, polish=0.32, grain=0.6)
    hmax = max(float(np.max(np.abs(h))), 1e-6)
    s.shade += np.clip(h / hmax, -1, 1) * 1.4
    s.shade -= (h < -1e-5) * 1.8
    if extra_dark is not None:
        s.shade -= extra_dark * 2.0
    s.shade += ctx.edge(1.0) * 1.2 - ctx.cavity(3.0) * 2.0 - (1.0 - ctx.ao) * 4.0
    s.height = h
    return s
