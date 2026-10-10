"""King's Library kit: the coffered plaster ceiling (10 m), its skylight
wells and the cornice under it (Enlightenment wing).

  lib_coffer_2m         plaster coffer 2 x 2 m, 0.25 m deep: stepped frame,
                        a gilt bead, a duck-egg field with a painted
                        egg-and-dart border and a gilt rosette. Origin = the
                        centre of the ceiling plane, hangs down (-Y). Light
                        (~200 triangles): the gallery holds ~200 of them.
  lib_skylight_well_4m  a 4 x 4 m light well, 1.3 m deep: moulded plaster rim
                        on the ceiling plane, panelled reveals, a cast-iron
                        lay-light grid (4 x 4 panes) at the top, the glass
                        as part lib_skylight_well_4m_glass (no shadow: the
                        moon comes through). Origin = the opening's centre
                        on the ceiling plane; the well rises +Y.
  lib_cornice_{4m,2m,1m} the gallery's ceiling cornice, 1.2 m: architrave,
                        a lacquered green frieze with a gilt Greek key,
                        dentils, modillions and the corona. Wall-run
                        convention, origin on the ceiling at the wall plane
                        (hangs from its datum). Texture set
                        lib_cornice_4m_motto: the frieze carries the
                        Enlightenment's motto SAPERE AUDE in gilt capitals
                        (put one in the middle of each long wall).
"""
import math
import os

import numpy as np
from mathutils import Matrix

from artlib import enl_materials as E
from artlib import font
from artlib.archkit import kit, moulding
from artlib.enl_materials import P
from artlib.geo import Part
from artlib.materials import _dither


def coffer():
    p = Part("lib_coffer")
    lo, hi = -0.88, 0.88
    path = [(lo, lo), (lo, hi), (hi, hi), (hi, lo)]
    p.sweep([(0.02, 0.0), (0.07, 0.0), (0.07, 0.02), (0.13, 0.02)], path, "plaster", closed=True)
    p.sweep([(0.13, 0.02), (0.155, 0.035), (0.155, 0.05), (0.13, 0.06)], path, "gilt", closed=True)
    p.sweep([(0.13, 0.06), (0.21, 0.06), (0.21, 0.08), (0.25, 0.1), (0.25, 0.22)], path, "plaster", closed=True)
    f = p.poly([(lo, -0.02, lo), (hi, -0.02, lo), (hi, -0.02, hi), (lo, -0.02, hi)], "field")[0]
    f.normal_update()
    if f.normal.y > 0:
        f.normal_flip()
    ros = p.lathe([(0.0, 0.0), (0.24, 0.0), (0.24, 0.02), (0.17, 0.045), (0.11, 0.075), (0.05, 0.1), (0.0, 0.11)],
                  "rosette", segments=12, cap_bottom=False)
    p.move(ros, Matrix.Translation((0.0, -0.02, 0.0)) @ Matrix.Rotation(math.radians(90), 4, 'X'))
    p.move(list(p.bm.faces), Matrix.Rotation(math.radians(90), 4, 'X'))
    return p


def _field(ctx):
    """Duck-egg field with a painted egg-and-dart border near its edge."""
    s = E.plaster_cool(ctx, seed=651, center=6.2)
    x, y = ctx.p[:, 0], ctx.p[:, 1]
    d = np.minimum(0.86 - np.abs(x), 0.86 - np.abs(y))          # distance in from the field's edge
    along = np.where(np.abs(x) > np.abs(y), y, x)
    band = (d > 0.03) & (d < 0.09)
    egg = band & (np.abs(np.mod(along, 0.08) - 0.04) < 0.022) & (d > 0.04) & (d < 0.08)
    s.use_ramp(P["enl_frieze"], mask=band & ~egg, shade=np.full(ctx.N, 4.0) + _dither(ctx, 0.4, 652))
    s.use_ramp(P["gold"], mask=egg, shade=np.full(ctx.N, 6.0) + _dither(ctx, 1.0, 653))
    s.metal = np.where(egg, 0.8, 0.0)
    return s


def _rosette(ctx):
    s = E.gilt(ctx, seed=655)
    a = np.arctan2(ctx.p[:, 0], ctx.p[:, 1])
    r = np.hypot(ctx.p[:, 0], ctx.p[:, 1])
    petal = np.abs(np.cos(a * 4.0)) ** 2
    s.shade += petal * 1.6 - (r < 0.05) * 1.2 - np.clip(0.3 - petal, 0, 1) * 2.2
    return s


def skylight_well(S=4.0, depth=1.3):
    p = Part("lib_skylight_well")
    g = Part("lib_skylight_well_glass")
    h = S / 2
    # the rim on the ceiling plane: a stepped frame round the opening, hanging down
    for a in range(4):
        rot = Matrix.Rotation(math.radians(90 * a), 4, 'Z')
        f = p.box((0.0, -h - 0.16, -0.05), (S + 0.64, 0.32, 0.1), "plaster", bevel=0.02)
        f += p.box((0.0, -h - 0.05, -0.12), (S + 0.2, 0.1, 0.06), "gilt", bevel=0.012)
        p.move(f, rot)
    # reveals: four panelled walls rising from the ceiling to the lay-light
    for a in range(4):
        rot = Matrix.Rotation(math.radians(90 * a), 4, 'Z')
        wall = p.poly([(-h, -h, 0.0), (h, -h, 0.0), (h, -h, depth), (-h, -h, depth)], "reveal")[0]
        wall.normal_update()
        if wall.normal.y < 0:
            wall.normal_flip()
        p.move([wall], rot)
        for k in range(3):
            panel = p.box((-h + S * (k + 0.5) / 3, -h + 0.012, depth * 0.5), (S / 3 - 0.18, 0.024, depth - 0.36),
                          "panel", bevel=0.012)
            p.move(panel, rot)
        band = p.box((0.0, -h + 0.03, depth - 0.06), (S, 0.06, 0.12), "plaster", bevel=0.015)
        p.move(band, rot)
    # cast-iron lay-light: a frame and a 4 x 4 grid of glazing bars, a boss at each crossing
    z = depth - 0.02
    for k in range(5):
        t = -h + S * k / 4
        heavy = k in (0, 4)
        w = 0.12 if heavy else 0.05
        p.box((t, 0.0, z), (w, S, 0.07), "iron")
        p.box((0.0, t, z), (S, w, 0.07), "iron")
    for i in range(1, 4):
        for j in range(1, 4):
            boss = p.lathe([(0.0, -0.06), (0.05, -0.05), (0.06, -0.02), (0.05, 0.0)], "brass", segments=8,
                           center=(-h + S * i / 4, -h + S * j / 4, z - 0.035))
            del boss
    f = g.poly([(-h, -h, z + 0.04), (h, -h, z + 0.04), (h, h, z + 0.04), (-h, h, z + 0.04)], "glass")[0]
    f.normal_update()
    if f.normal.z > 0:
        f.normal_flip()
    return [p, g]


CORNICE_LOW = [(0.0, -1.2), (-0.05, -1.2), (-0.05, -1.12), (-0.07, -1.1), (-0.07, -1.03), (-0.09, -1.01),
               (-0.09, -0.99)]
CORNICE_FRIEZE = [(-0.09, -0.99), (-0.09, -0.55)]
CORNICE_TOP = [(-0.09, -0.55), (-0.12, -0.53), (-0.12, -0.46), (-0.17, -0.45), (-0.2, -0.43), (-0.2, -0.42),
               (-0.5, -0.42), (-0.53, -0.39), (-0.53, -0.24), (-0.57, -0.2), (-0.63, -0.12), (-0.67, -0.06),
               (-0.67, 0.0), (0.0, 0.0)]


def cornice(W):
    p = Part("lib_cornice")
    moulding(p, CORNICE_LOW, W, "plaster")
    moulding(p, CORNICE_FRIEZE, W, "frieze")
    moulding(p, CORNICE_TOP, W, "plaster")
    p.box((0, -0.095, -0.565), (W, 0.012, 0.016), "gilt")
    p.box((0, -0.095, -0.985), (W, 0.012, 0.016), "gilt")
    n = int(round(W / 0.125))
    for k in range(n):
        x = -W / 2 + (k + 0.5) * W / n
        p.box((x, -0.15, -0.495), (0.06, 0.06, 0.08), "plaster")
    m = int(round(W / 0.5))
    for k in range(m):
        x = -W / 2 + (k + 0.5) * W / m
        p.box((x, -0.36, -0.465), (0.12, 0.32, 0.09), "plaster", bevel=0.012)
        p.box((x, -0.47, -0.52), (0.12, 0.1, 0.12), "gilt_leaf", bevel=0.02)
    return p


def _frieze(motto=None):
    def fn(ctx):
        s = E.key_frieze(ctx, seed=661, scale=3)
        if motto is None:
            return s
        u, v = ctx.uvm[:, 0], ctx.uvm[:, 1]
        vmin, vmax = (np.min(v), np.max(v)) if ctx.N else (0.0, 0.0)
        px = ctx.texel * 3
        h = 7 * px
        ink = font.text_mask(u, v, motto, 0.0, (vmin + vmax) / 2 - h / 2, px)
        # the key stays at both ends of the module, the motto takes the middle
        w = (font.width_px(motto) + 6) * px / 2
        mid = np.abs(u) < w
        s.use_ramp(P["enl_frieze"], mask=mid, shade=np.full(ctx.N, 3.0) + _dither(ctx, 0.5, 662)
                   - (1.0 - ctx.ao) * 2.5)
        s.use_ramp(P["gold"], mask=mid & ink, shade=np.full(ctx.N, 6.8) + _dither(ctx, 1.0, 663))
        s.metal = np.where(mid, np.where(ink, 0.85, 0.0), s.metal)
        s.rough = np.where(mid & ink, 0.3, s.rough)
        s.height = np.where(mid, ink * 0.001, s.height)
        return s
    return fn


def _leaf(ctx):
    s = E.gilt(ctx, seed=667)
    s.shade += np.sin(ctx.uvm[:, 1] * 120.0) * 0.8 - 0.3
    return s


def build():
    only = os.environ.get("ENL_ONLY", "").split(",")

    def want(n):
        return only == [""] or n in only

    out = []
    plaster = lambda c: E.plaster_cool(c, seed=671, center=5.8)
    if want("lib_coffer_2m"):
        out.append(kit("lib_coffer_2m", [coffer()], {"plaster": plaster, "gilt": E.gilt, "field": _field,
                                                      "rosette": _rosette}, ppm=64, ground=None, ceiling=0.0,
                       ao_dist=0.4, preview_elevation=-35.0))
    if want("lib_skylight_well_4m"):
        out.append(kit("lib_skylight_well_4m", skylight_well(), {"plaster": plaster, "reveal": plaster,
                                                                  "panel": lambda c: E.plaster_cool(c, 673, 5.0),
                                                                  "iron": E.iron_black, "brass": E.dark_brass},
                       kinds={"glass": "glass"}, ppm=64, ground=None, ao_dist=0.6, built_final=True,
                       preview_elevation=-40.0))
    for W, tag in ((4.0, "4m"), (2.0, "2m"), (1.0, "1m")):
        name = f"lib_cornice_{tag}"
        if not want(name):
            continue
        fns = {"plaster": plaster, "frieze": _frieze(), "gilt": E.gilt, "gilt_leaf": _leaf}
        variants = {}
        if tag == "4m":
            variants = {"lib_cornice_4m_motto": dict(fns, frieze=_frieze("SAPERE AUDE"))}
        out.append(kit(name, [cornice(W)], fns, ppm=64, wall=True, ground=None, ceiling=0.0, ao_dist=0.5,
                       variants=variants, preview=tag == "4m", preview_elevation=-12.0))
    return out
