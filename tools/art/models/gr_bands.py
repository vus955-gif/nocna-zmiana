"""Greek kit: wall bands (runs of 4 / 2 / 1 / 0.5 m modules, 64 px/m).

  gr_base_4m/2m/1m/05m       floor band 0.6 m: blue-grey Hymettian marble
                             plinth (block joints every metre), torus,
                             scotia and an astragal with bead-and-reel in
                             white marble. Datum: the floor.
  gr_cornice_4m/2m/1m/05m    Ionic crown 1.2 m hanging from the ceiling:
                             three-fascia architrave, a frieze painted with
                             an anthemion (palmettes and lotus in faded blue,
                             red and ochre), dentils (every 0.125 m), an
                             egg-and-dart ovolo, the corona with its drip
                             and a cyma recta. Datum: the ceiling (hangs).
  gr_cornice_doric_4m/2m/1m  Doric entablature 1.6 m hanging from the
                             ceiling: architrave, taenia with regulae and
                             guttae, triglyphs every metre (centred on the
                             half metres, so modules keep the rhythm; traces
                             of their dark-blue paint) and plain metopes,
                             the geison with mutules. Datum: the ceiling.

Run convention as the lobby kit: x = -W/2 .. W/2, wall plane z = 0, room
side -Z, ends open (runs butt together; inner corners by interpenetration).
"""
import math

import numpy as np

from artlib import greek as GK
from artlib import greek_ornament as O
from artlib.archkit import LENGTHS, facing, kit
from artlib.geo import Part
from artlib.materials import P, _dither

BASE_H = 0.6
CORNICE_H = 1.2
DORIC_H = 1.6


def _strip(p, prof, W, slot):
    return p.extrude(prof, -W / 2, W / 2, slot, caps=False)


# --------------------------------------------------------------------------
# geometry
# --------------------------------------------------------------------------

def base(W, name):
    p = Part(name)
    _strip(p, [(-0.092, 0.0), (-0.1, 0.012), (-0.1, 0.42)], W, "grey")
    _strip(p, [(-0.1, 0.42), (-0.112, 0.424), (-0.122, 0.438), (-0.126, 0.456), (-0.121, 0.474), (-0.11, 0.486),
               (-0.098, 0.49), (-0.086, 0.495), (-0.081, 0.512), (-0.082, 0.53), (-0.088, 0.545), (-0.09, 0.556)],
           W, "marble")
    _strip(p, [(-0.09, 0.556), (-0.096, 0.566), (-0.097, 0.578), (-0.09, 0.588)], W, "bead")
    _strip(p, [(-0.09, 0.588), (-0.072, 0.592), (-0.068, 0.6), (0.0, 0.6)], W, "marble")
    return p


def cornice(W, name):
    p = Part(name)
    z0 = -CORNICE_H

    def prof(pts):
        return [(y, z + z0) for y, z in pts]
    # architrave: three fascias and a crowning cyma
    _strip(p, prof([(0.0, 0.0), (-0.05, 0.0), (-0.05, 0.14), (-0.065, 0.145), (-0.065, 0.28), (-0.08, 0.285),
                    (-0.08, 0.41), (-0.09, 0.42), (-0.1, 0.44), (-0.1, 0.455), (-0.08, 0.47)]), W, "marble")
    _strip(p, prof([(-0.08, 0.47), (-0.08, 0.78)]), W, "anthemion")
    _strip(p, prof([(-0.08, 0.78), (-0.088, 0.785), (-0.09, 0.795), (-0.09, 0.92)]), W, "marble")
    # dentils
    n = int(round(W / 0.125))
    for k in range(n):
        x0 = -W / 2 + k * 0.125 + 0.025
        x1 = x0 + 0.075
        y0, y1 = -0.15, -0.09
        za, zb = z0 + 0.8, z0 + 0.92
        facing(p, [(x0, y0, za), (x1, y0, za), (x1, y0, zb), (x0, y0, zb)], "dentil", (0, -1, 0))
        facing(p, [(x0, y0, za), (x1, y0, za), (x1, y1, za), (x0, y1, za)], "dentil", (0, 0, -1))
        facing(p, [(x0, y0, za), (x0, y1, za), (x0, y1, zb), (x0, y0, zb)], "dentil", (-1, 0, 0))
        facing(p, [(x1, y0, za), (x1, y1, za), (x1, y1, zb), (x1, y0, zb)], "dentil", (1, 0, 0))
    # ovolo with eggs and darts, corona with a drip, cyma recta
    _strip(p, prof([(-0.09, 0.92), (-0.15, 0.92)]), W, "dentil")
    _strip(p, prof([(-0.15, 0.92), (-0.16, 0.94), (-0.175, 0.965), (-0.19, 0.995), (-0.198, 1.02)]), W, "eggdart")
    _strip(p, prof([(-0.198, 1.02), (-0.33, 1.02), (-0.33, 1.005), (-0.345, 1.005), (-0.345, 1.1),
                    (-0.36, 1.105)]), W, "marble")
    _strip(p, prof([(-0.36, 1.105), (-0.37, 1.12), (-0.385, 1.15), (-0.4, 1.17), (-0.405, 1.185), (-0.405, 1.2),
                    (0.0, 1.2)]), W, "sima")
    return p


def cornice_doric(W, name):
    p = Part(name)
    z0 = -DORIC_H

    def prof(pts):
        return [(y, z + z0) for y, z in pts]
    _strip(p, prof([(0.0, 0.0), (-0.06, 0.0), (-0.06, 0.56)]), W, "marble")
    _strip(p, prof([(-0.06, 0.56), (-0.085, 0.56), (-0.085, 0.62), (-0.06, 0.62), (-0.06, 1.33)]), W, "metope")
    # triglyphs on the half metres, regulae and guttae under the taenia
    n = int(round(W))
    for k in range(n):
        cx = -W / 2 + 0.5 + k
        x0, x1 = cx - 0.18, cx + 0.18
        y0, y1 = -0.1, -0.06
        za, zb = z0 + 0.62, z0 + 1.33
        facing(p, [(x0, y0, za), (x1, y0, za), (x1, y0, zb), (x0, y0, zb)], "triglyph", (0, -1, 0))
        facing(p, [(x0, y0, za), (x0, y1, za), (x0, y1, zb), (x0, y0, zb)], "triglyph", (-1, 0, 0))
        facing(p, [(x1, y0, za), (x1, y1, za), (x1, y1, zb), (x1, y0, zb)], "triglyph", (1, 0, 0))
        facing(p, [(x0, y0, za), (x1, y0, za), (x1, y1, za), (x0, y1, za)], "triglyph", (0, 0, -1))
        p.box((cx, -0.072, z0 + 0.545), (0.36, 0.025, 0.03), "marble")
        for g in range(6):
            gx = x0 + 0.03 + g * 0.06
            p.box((gx, -0.075, z0 + 0.518), (0.03, 0.022, 0.026), "marble")
    # geison: inclined soffit with mutules, corona, cymatium
    _strip(p, prof([(-0.06, 1.33), (-0.1, 1.33), (-0.1, 1.36), (-0.44, 1.38), (-0.44, 1.37), (-0.455, 1.37),
                    (-0.455, 1.5)]), W, "marble")
    for k in range(int(round(W / 0.5))):
        cx = -W / 2 + 0.25 + k * 0.5
        p.box((cx, -0.27, z0 + 1.355), (0.3, 0.3, 0.025), "mutule")
    _strip(p, prof([(-0.455, 1.5), (-0.47, 1.52), (-0.485, 1.55), (-0.49, 1.58), (-0.49, 1.6), (0.0, 1.6)]), W,
           "marble")
    return p


# --------------------------------------------------------------------------
# paint
# --------------------------------------------------------------------------

def _u(ctx):
    """Distance along the run as the viewer reads it (models are turned)."""
    return ctx.uvm[:, 0]


def _grey(ctx):
    s = GK.grey_marble(ctx, seed=701, center=4.4)
    x = -ctx.p[:, 0]
    joint = np.abs(x - np.round(x)) < ctx.texel * 0.6
    s.shade = np.where(joint & (np.abs(ctx.n[:, 1]) > 0.5), 1.2, s.shade)
    s.height = np.where(joint, -0.002, 0.0)
    return s


def _marble(ctx):
    return GK.pentelic(ctx, seed=703, center=7.7, veins=0.5, patina=0.8, ao=3.0)


def _bead(ctx):
    v = ctx.uvm[:, 1]
    L = 0.03
    h, bead, reel = O.bead_reel(_u(ctx), v, L, period=0.0625, depth=0.005)
    return O.carved_marble(ctx, h, 705, center=7.6)


def _eggdart(ctx):
    v = ctx.uvm[:, 1]
    L = float(np.max(v)) if ctx.N else 0.1
    h, egg, shell, dart = O.egg_dart(_u(ctx), v, max(L, 0.05), period=0.125)
    s = O.carved_marble(ctx, h, 707, center=7.8)
    s.shade += egg * 1.0 - shell * 1.5
    GK.paint_traces(ctx, s, "gr_blue", shell | dart, 709, center=2.6, density=0.8, freq=2.0)
    return s


def _anthemion(ctx):
    v = ctx.uvm[:, 1]
    u = _u(ctx)
    s = GK.marble_body(ctx, 711, center=7.4, vein=0.35, warm=0.8, polish=0.35, grain=0.6)
    palm, lotus, scroll = O.anthemion(u, v, 0.31, period=0.5)
    GK.paint_traces(ctx, s, "gr_blue", ~(palm | lotus | scroll), 713, center=3.4, density=0.7, freq=1.5)
    GK.paint_traces(ctx, s, "gr_red", palm, 715, center=4.2, density=0.9, freq=1.5)
    GK.paint_traces(ctx, s, "gr_ochre", lotus | scroll, 717, center=4.6, density=0.9, freq=1.5)
    # the ornament was also incised: a faint line around it
    s.height = (palm | lotus | scroll) * 0.0008
    s.shade -= (1.0 - ctx.ao) * 4.0
    return s


def _dentil(ctx):
    s = GK.pentelic(ctx, seed=719, center=7.4, veins=0.4, patina=0.8)
    return s


def _sima(ctx):
    s = GK.pentelic(ctx, seed=721, center=7.7, veins=0.4, patina=0.8, ao=3.0)
    v = ctx.uvm[:, 1]
    # the painted lotus-and-palmette of the sima, mostly gone
    palm, lotus, scroll = O.anthemion(_u(ctx), np.clip(v, 0, None), 0.09, period=0.25)
    GK.paint_traces(ctx, s, "gr_red", palm & (v < 0.09), 723, center=3.6, density=0.5, freq=3.0)
    return s


def _triglyph(ctx, W):
    s = GK.pentelic(ctx, seed=731, center=7.2, veins=0.4, patina=0.8)
    x = -ctx.p[:, 0]
    loc = np.mod(x - (-W / 2 + 0.5) + 0.5, 1.0) - 0.5          # metres from the triglyph centre
    front = ctx.n[:, 1] > 0.5
    glyph = front & ((np.abs(np.abs(loc) - 0.06) < 0.025) | (np.abs(np.abs(loc) - 0.18) < 0.015))
    s.shade -= glyph * 2.4
    s.height = -glyph.astype(float) * 0.01
    GK.paint_traces(ctx, s, "gr_blue", ~glyph, 733, center=2.4, density=0.85, freq=1.5)
    return s


def _metope(ctx):
    s = GK.pentelic(ctx, seed=741, center=7.4, veins=0.5, patina=1.0)
    z = ctx.p[:, 2]
    taenia = z < -DORIC_H + 0.63
    GK.paint_traces(ctx, s, "gr_red", ~taenia & (ctx.n[:, 1] > 0.5), 743, center=3.6, density=0.3, freq=1.2)
    return s


def _mutule(ctx):
    s = GK.pentelic(ctx, seed=751, center=7.0, veins=0.4, patina=0.6)
    u, v = ctx.uvm[:, 0], ctx.uvm[:, 1]
    gutta = (np.mod(u, 0.05) < 0.02) & (np.mod(v, 0.05) < 0.02) & (ctx.n[:, 2] < -0.5)
    s.shade -= gutta * 1.5
    GK.paint_traces(ctx, s, "gr_blue", ctx.n[:, 2] < -0.5, 753, center=2.6, density=0.7, freq=1.5)
    return s


FNS = {"grey": _grey, "marble": _marble, "bead": _bead, "eggdart": _eggdart, "anthemion": _anthemion,
       "dentil": _dentil, "sima": _sima, "metope": _metope, "mutule": _mutule}


def build():
    out = []
    for W, tag in LENGTHS:
        out.append(kit("gr_base_" + tag, [base(W, "gr_base_" + tag)], FNS, wall=True, ground=0.0, ao_dist=0.3,
                       preview=(tag == "4m")))
    for W, tag in LENGTHS:
        out.append(kit("gr_cornice_" + tag, [cornice(W, "gr_cornice_" + tag)], FNS, wall=True, ground=None,
                       ceiling=0.0, ao_dist=0.35, preview=(tag == "4m"), preview_elevation=-14.0,
                       preview_extra=[("detail", (0.0, 0.2, -0.6), 0.9, 20.0, -12.0)] if tag == "4m" else []))
    for W, tag in LENGTHS[:3]:
        fns = dict(FNS, triglyph=lambda ctx, W=W: _triglyph(ctx, W))
        out.append(kit("gr_cornice_doric_" + tag, [cornice_doric(W, "gr_cornice_doric_" + tag)], fns, wall=True,
                       ground=None, ceiling=0.0, ao_dist=0.4, preview=(tag == "4m"), preview_elevation=-12.0,
                       preview_extra=[("detail", (0.0, 0.3, -0.8), 1.2, 20.0, -12.0)] if tag == "4m" else []))
    return out
