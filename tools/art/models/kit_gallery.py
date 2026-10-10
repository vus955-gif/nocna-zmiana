"""Lobby kit: framed paintings for the hall and the wings, in the sizes the
layout hangs (kit id "painting": 3 x 2, 3.5 x 2.2, 2.4 x 1.8 m) plus two
small ones. Gilt ogee frames swept round a pixel-painted canvas in a
limited palette with craquelure.

Origin = centre of the frame's bottom edge; the back sits on the wall plane
0.05 m behind the origin (+Z), as the layout places paintings 5 cm off the
wall. Each size has two or three canvases as texture sets (same mesh):

  frame_3x2         landscape (frame_3x2), frame_3x2_sea
  frame_3_5x2_2     seascape (frame_3_5x2_2), frame_3_5x2_2_land
  frame_2_4x1_8     landscape, frame_2_4x1_8_sea, frame_2_4x1_8_still
  frame_1_2x0_9     still life, frame_1_2x0_9_land
  frame_0_6x0_8     portrait, frame_0_6x0_8_still
"""
import math

import numpy as np

from artlib import materials as M
from artlib import noise
from artlib.archkit import kit
from artlib.geo import Part
from artlib.painter import Surface

WALL = 0.05

PALETTE = M.hexramp(
    "#0d0b0a", "#1a1512", "#2a211a", "#3a2e22", "#4d3d2a", "#1e2522", "#2c3a30", "#3f4f3c",
    "#56613f", "#1a2430", "#2b3a48", "#465666", "#6b7a80", "#8c8a78", "#b39a6a", "#d2ae70",
    "#e8c887", "#f3e0a8", "#7a4a2a", "#a0603a", "#c07a44", "#5a2e20", "#7d2a24", "#a8423a",
    "#c9b89a", "#e6dcc8", "#314a52", "#4e6e74")


def _f(u, v, freq, seed, octs=3):
    n = len(u)
    return noise.fbm(np.stack([u * freq, v * freq, np.zeros(n)], axis=1), octs, seed)


def land(u, v, seed):
    n = len(u)
    col = np.zeros((n, 3))
    t = np.clip((v - 0.4) / 0.6, 0, 1)
    col[:] = np.array([0.84, 0.66, 0.4]) * (1 - t[:, None]) ** 1.2 + np.array([0.14, 0.2, 0.26]) * \
        (1 - (1 - t[:, None]) ** 1.2)
    clouds = np.clip(_f(u, v, 3.0, seed) * 1.6 + 0.1 - np.abs(v - 0.74) * 1.6, 0, 1)
    col = col * (1 - clouds[:, None] * 0.5) + clouds[:, None] * np.array([0.5, 0.38, 0.28]) * 0.6
    h1 = 0.45 + _f(u, v * 0, 2.0, seed + 1) * 0.06
    col[v < h1] = np.array([0.35, 0.4, 0.42])
    h2 = 0.36 + _f(u, v * 0, 3.5, seed + 2) * 0.07 + np.exp(-((u - 0.3) / 0.14) ** 2) * 0.08
    near = v < h2
    shade = np.clip(0.5 + _f(u, v, 8.0, seed + 3) * 0.8, 0, 1)
    col[near] = np.array([0.2, 0.24, 0.14]) * (0.6 + shade[near] * 0.6)[:, None]
    for cx, cv, r in ((0.12, 0.62, 0.12), (0.2, 0.55, 0.08), (0.85, 0.58, 0.1)):
        d = np.sqrt(((u - cx) * 1.5) ** 2 + (v - cv) ** 2) + _f(u, v, 12.0, seed + 4) * 0.03
        col[d < r] = np.array([0.07, 0.09, 0.06])
    lake = (v < 0.22) & (u > 0.45) & (v > 0.08)
    col[lake] = np.array([0.62, 0.52, 0.36]) * (0.7 + 0.3 * (np.sin(v * 200) > 0.5))[lake, None]
    return col


def sea(u, v, seed):
    n = len(u)
    t = np.clip((v - 0.35) / 0.65, 0, 1)
    col = np.array([0.5, 0.52, 0.5]) * (1 - t[:, None]) + np.array([0.12, 0.14, 0.16]) * t[:, None]
    storm = np.clip(_f(u, v, 2.5, seed) + 0.2, 0, 1)
    col = col * (1 - storm[:, None] * 0.5)
    light = np.exp(-(((u - 0.7) / 0.15) ** 2 + ((v - 0.62) / 0.2) ** 2))
    col += light[:, None] * np.array([0.35, 0.3, 0.2])
    horizon = 0.36 + _f(u, v * 0, 6.0, seed + 1) * 0.01
    water = v < horizon
    wave = np.sin(u * 40.0 + _f(u, v, 5.0, seed + 2) * 6.0 + v * 30.0)
    wcol = np.array([0.12, 0.2, 0.2]) + (wave > 0.6)[:, None] * np.array([0.3, 0.32, 0.28]) * (1 - v / horizon)[:, None]
    col = np.where(water[:, None], wcol, col)
    # a brig heeling in the storm
    hull = (np.abs(u - 0.38) < 0.1 - (0.3 - v) * 0.4) & (v > 0.27) & (v < 0.31)
    mast = (np.abs(u - 0.38 - (v - 0.3) * 0.15) < 0.004) & (v > 0.3) & (v < 0.55)
    sails = (np.abs(u - 0.39 - (v - 0.3) * 0.15) < 0.05 * (1 - np.abs(v - 0.42) * 4)) & (v > 0.34) & (v < 0.52)
    col[hull | mast] = np.array([0.08, 0.06, 0.05])
    col[sails] = np.array([0.72, 0.66, 0.54])
    return col


def still(u, v, seed):
    n = len(u)
    col = np.array([0.1, 0.08, 0.06]) + (0.08 * np.clip(1 - np.abs(u - 0.35) * 2, 0, 1))[:, None]
    table = v < 0.3
    col[table] = np.array([0.26, 0.16, 0.09])
    col[np.abs(v - 0.3) < 0.01] = np.array([0.4, 0.26, 0.14])
    bowl = (((u - 0.5) / 0.22) ** 2 + ((v - 0.34) / 0.1) ** 2 < 1) & (v < 0.36)
    col[bowl] = np.array([0.55, 0.5, 0.42])
    for cx, cv, r, c in ((0.42, 0.42, 0.07, (0.7, 0.18, 0.1)), (0.55, 0.43, 0.075, (0.8, 0.6, 0.15)),
                         (0.49, 0.5, 0.06, (0.35, 0.12, 0.25)), (0.63, 0.4, 0.05, (0.55, 0.6, 0.2))):
        d = np.hypot(u - cx, (v - cv) * 1.2)
        m = d < r
        lit = np.clip(1.2 - np.hypot(u - cx + r * 0.4, v - cv - r * 0.4) / r, 0.4, 1.2)
        col[m] = (np.array(c) * lit[:, None])[m]
    jug = (np.abs(u - 0.25) < 0.07 - (v - 0.45) ** 2 * 0.6) & (v > 0.3) & (v < 0.62)
    col[jug] = np.array([0.3, 0.3, 0.28]) + (0.2 * (u < 0.23))[jug, None]
    return col


def portrait(u, v, seed):
    n = len(u)
    col = np.array([0.16, 0.11, 0.07]) + (0.06 * (1 - np.abs(u - 0.4)))[:, None]
    head = ((u - 0.5) / 0.16) ** 2 + ((v - 0.64) / 0.14) ** 2 < 1.0
    body = (v < 0.5 - np.abs(u - 0.5) * 0.35) | ((v < 0.45) & (np.abs(u - 0.5) < 0.42))
    collar = (np.abs(v - 0.49) < 0.03 + 0.01 * np.sin(u * 60)) & (np.abs(u - 0.5) < 0.2)
    col[body] = np.array([0.05, 0.05, 0.06])
    face_l = 0.5 + 0.5 * np.clip((0.55 - u) * 3.0, -1, 1)
    col[head] = (np.array([0.78, 0.58, 0.44]) * (0.55 + 0.45 * face_l[:, None]))[head]
    col[collar] = np.array([0.85, 0.82, 0.74])
    hair = (((u - 0.5) / 0.18) ** 2 + ((v - 0.7) / 0.13) ** 2 < 1.0) & ((v > 0.7) | ~head)
    col[hair] = np.array([0.1, 0.07, 0.05])
    eye = head & (np.abs(v - 0.655) < 0.01) & (np.abs(np.abs(u - 0.5) - 0.055) < 0.018)
    col[eye] = np.array([0.12, 0.08, 0.06])
    return col


def _old_master(cw, ch, cz):
    """The stage 1b landscape (models/painting.py), stretched onto this
    canvas: it paints in its own 1.8 x 1.3 m metre-UV frame."""
    from models import painting

    def fn(ctx):
        x, z = ctx.p[:, 0], ctx.p[:, 2]
        u = -x / cw + 0.5
        v = (z - cz) / ch + 0.5
        ctx.uvm = np.stack([(u - 0.5) * painting.CW, (v - 0.5) * painting.CH], axis=1)
        return painting._canvas(ctx)
    return fn


def _canvas(painter, cw, ch, cz, seed):
    if painter is land:
        return _old_master(cw, ch, cz)

    def fn(ctx):
        x, z = ctx.p[:, 0], ctx.p[:, 2]
        u = -x / cw + 0.5          # after the turn: +u = the viewer's right
        v = (z - cz) / ch + 0.5
        n = ctx.N
        col = painter(u, v, seed)
        vig = np.clip(1.0 - ((u - 0.5) ** 2 + (v - 0.5) ** 2) * 1.0, 0.6, 1.0)
        col = col * vig[:, None] * np.array([1.0, 0.94, 0.8])
        col *= (0.97 + 0.03 * ctx.rand(3))[:, None]
        f1, f2, _ = noise.worley(np.stack([u * cw * 30.0, v * ch * 30.0, np.zeros(n)], axis=1), 41 + seed)
        crack = (f2 - f1) < 0.06
        col[crack] *= 0.72
        d = ((col[:, None, :] - PALETTE[None]) ** 2).sum(-1)
        s = Surface(n)
        s.albedo = PALETTE[np.argmin(d, axis=1)]
        s.rough = np.full(n, 0.35) + crack * 0.3
        s.height = crack * -0.0006
        return s
    return fn


def frame(W, H):
    f = 0.1 if max(W, H) < 1.5 else 0.15
    cw, ch = W - 2 * f, H - 2 * f
    cz = H / 2
    p = Part("frame")
    y = WALL - 0.04
    face = p.poly([(-cw / 2, y, cz - ch / 2), (cw / 2, y, cz - ch / 2), (cw / 2, y, cz + ch / 2),
                   (-cw / 2, y, cz + ch / 2)], "canvas")[0]
    face.normal_update()
    if face.normal.y > 0:
        face.normal_flip()
    path = [(-cw / 2, cz - ch / 2), (-cw / 2, cz + ch / 2), (cw / 2, cz + ch / 2), (cw / 2, cz - ch / 2)]
    k = f / 0.15
    prof = [(0.04, -0.005), (0.065, 0.0), (0.075, 0.03 * k), (0.1, 0.05 * k), (0.1, 0.075 * k), (0.085, 0.1 * k),
            (0.07, 0.115 * k), (0.075, 0.135 * k), (0.05, f), (0.0, f)]
    p.sweep(prof, path, "gold", closed=True, y0=WALL)
    if f > 0.12:
        for sx in (-1, 1):
            for top in (False, True):
                cx = sx * (cw / 2 + f / 2 - 0.01)
                zz = (cz + ch / 2 + f / 2 - 0.01) if top else (cz - ch / 2 - f / 2 + 0.01)
                p.box((cx, WALL - 0.1, zz), (0.1, 0.03, 0.1), "gold", bevel=0.015)
        p.box((0, WALL - 0.1, cz + ch / 2 + f / 2 - 0.01), (0.24, 0.03, 0.09), "gold", bevel=0.015)
    return p, (cw, ch, cz)


SIZES = [
    ("frame_3x2", 3.0, 2.0, [("", land), ("_sea", sea)]),
    ("frame_3_5x2_2", 3.5, 2.2, [("", sea), ("_land", land)]),
    ("frame_2_4x1_8", 2.4, 1.8, [("", land), ("_sea", sea), ("_still", still)]),
    ("frame_1_2x0_9", 1.2, 0.9, [("", still), ("_land", land)]),
    ("frame_0_6x0_8", 0.6, 0.8, [("", portrait), ("_still", still)]),
]


def build():
    out = []
    for i, (name, W, H, canvases) in enumerate(SIZES):
        part, (cw, ch, cz) = frame(W, H)
        fns = {"gold": M.gold, "canvas": _canvas(canvases[0][1], cw, ch, cz, 5 + i)}
        variants = {name + suffix: {"gold": M.gold, "canvas": _canvas(painter, cw, ch, cz, 9 + i + j)}
                    for j, (suffix, painter) in enumerate(canvases[1:])}
        out.append(kit(name, [part], fns, ppm=128, ground=None, planes=(("y", -WALL),), ao_dist=0.15,
                       variants=variants, preview=i in (0, 4)))
    return out
