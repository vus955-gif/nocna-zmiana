"""Enlightenment wing kit: doorways, portals and room signs.

Frames are single-face wall pieces like doorframe_4x4_5: origin = the
opening's floor centre on the wall face, trim on the room side (-Z); put
one on each face of a passage.

  lib_portal_4x4_5      the wing's grand portal for a 4 x 4.5 m opening:
                        mahogany architrave with a gilt bead, fluted
                        pilasters with gilt capitals, a frieze (gilt Greek
                        key), dentilled cornice and a broken segmental
                        pediment round a gilt cartouche with an armillary
                        sphere. 6.3 m tall in all, 6.2 m wide. Texture set
                        lib_portal_4x4_5_titled: BIBLIOTEKA KRÓLEWSKA in
                        gilt capitals on the frieze (the entrance from the
                        Great Court). The walkway (y = 4) must stop at
                        either side of it (lib_walkway_fascia_end).
  lib_doorframe_2x2_8   the cabinets' doors (2 x 2.8 m, fits under the
                        walkway): moulded mahogany architrave, plinth
                        blocks, a frieze with two gilt paterae and a small
                        triangular pediment; top at 3.45 m.
  lib_sign              green enamel plaque with gilt capitals in a brass
                        frame, 1.5 x 0.34 m, origin on the wall plane at its
                        centre. Text sets: lib_sign (BIBLIOTEKA KRÓLEWSKA),
                        lib_sign_natural (GABINET HISTORII NATURALNEJ),
                        lib_sign_collectors (GALERIA KOLEKCJONERÓW),
                        lib_sign_clocks (ZEGARY I AUTOMATY),
                        lib_sign_orrery (ROTUNDA PLANETARIUM),
                        lib_sign_librarian (GABINET BIBLIOTEKARZA).
"""
import math
import os

import numpy as np
from mathutils import Matrix

from artlib import enl_materials as E
from artlib import font
from artlib.archkit import arc, front_prism, kit
from artlib.enl_materials import P
from artlib.geo import Part
from artlib.materials import _dither
from artlib.painter import Surface

ARCHITRAVE = [(0.0, 0.0), (0.04, 0.0), (0.04, 0.05), (0.06, 0.07), (0.06, 0.15), (0.08, 0.17), (0.08, 0.22),
              (0.05, 0.25), (0.0, 0.25)]


def portal():
    p = Part("lib_portal")
    hw, H = 2.0, 4.5
    p.sweep(ARCHITRAVE, [(-hw, 0.35), (-hw, H), (hw, H), (hw, 0.35)], "mahogany")
    p.sweep([(0.085, 0.13), (0.085, 0.145)], [(-hw, 0.35), (-hw, H), (hw, H), (hw, 0.35)], "gilt")
    for sx in (-1, 1):
        x = sx * (hw + 0.55)
        # plinth, base, fluted shaft, gilt capital
        p.box((x, -0.09, 0.2), (0.62, 0.18, 0.4), "mahogany_dark", bevel=0.02)
        p.box((x, -0.11, 0.45), (0.56, 0.2, 0.1), "mahogany", bevel=0.02)
        p.box((x, -0.07, 2.65), (0.46, 0.14, 4.3), "mahogany", bevel=0.012)
        for k in range(5):
            fx = x - 0.18 + k * 0.09
            p.box((fx, -0.145, 2.65), (0.04, 0.012, 3.9), "mahogany", bevel=0.006)
        p.box((x, -0.11, 4.86), (0.54, 0.2, 0.12), "gilt", bevel=0.02)
        for vx in (-1, 1):
            vol = p.lathe([(0.0, -0.05), (0.07, -0.05), (0.07, 0.05), (0.0, 0.05)], "gilt", segments=10)
            p.move(vol, Matrix.Translation((x + vx * 0.24, -0.16, 4.86)) @ Matrix.Rotation(math.radians(90), 4, 'X'))
    # entablature: frieze, dentils, cornice
    W = 2 * (hw + 0.95)
    p.box((0, -0.09, 5.1), (W - 0.1, 0.18, 0.36), "frieze", bevel=0.01)
    p.box((0, -0.11, 4.93), (W, 0.22, 0.06), "mahogany", bevel=0.012)
    n = int(W / 0.12)
    for k in range(n):
        p.box((-W / 2 + 0.06 + k * W / n, -0.2, 5.33), (0.05, 0.05, 0.07), "mahogany")
    p.extrude([(0.0, 5.28), (-0.22, 5.28), (-0.22, 5.38), (-0.3, 5.42), (-0.34, 5.47), (-0.34, 5.52), (0.0, 5.52)],
              -W / 2 - 0.1, W / 2 + 0.1, "mahogany", caps=True)
    # broken segmental pediment: two arcs rising toward a gap round the cartouche
    R = 4.4
    cz = 5.52 - math.sqrt(R * R - (W / 2) ** 2)
    for sx in (-1, 1):
        a_end = math.asin((W / 2) / R)
        a_gap = math.asin(0.55 / R)
        pts_o = [(sx * R * math.sin(a), cz + R * math.cos(a)) for a in np.linspace(a_end, a_gap, 8)]
        pts_i = [(sx * (R - 0.28) * math.sin(a), cz + (R - 0.28) * math.cos(a)) for a in np.linspace(a_gap, a_end, 8)]
        outline = pts_o + pts_i
        if sx > 0:
            outline = outline[::-1]
        f = front_prism(p, outline, 0.3, "mahogany", y_back=0.0)
        p.move(f, Matrix.Translation((0, -0.0, 0.0)))
        tymp = [(sx * 0.6, 5.52), (sx * (W / 2 - 0.1), 5.52)] + \
            [(sx * (R - 0.3) * math.sin(a), cz + (R - 0.3) * math.cos(a)) for a in np.linspace(a_end * 0.97, a_gap, 6)]
        if sx < 0:
            tymp = tymp[::-1]
        front_prism(p, tymp, 0.1, "mahogany_dark", y_back=0.0)
    # the cartouche: a gilt oval frame round a green enamel disc with the armillary sphere
    car = p.lathe([(0.0, 0.0), (0.42, 0.0), (0.42, 0.06), (0.36, 0.1), (0.33, 0.1), (0.33, 0.06)], "gilt",
                  segments=20, squash=(0.85, 1.0), cap_bottom=False, cap_top=False)
    p.move(car, Matrix.Translation((0, -0.12, 5.95)) @ Matrix.Rotation(math.radians(-90), 4, 'X'))
    disc = p.lathe([(0.0, 0.0), (0.335, 0.0)], "emblem", segments=20, squash=(0.85, 1.0), cap_bottom=False,
                   cap_top=False)
    p.move(disc, Matrix.Translation((0, -0.15, 5.95)) @ Matrix.Rotation(math.radians(-90), 4, 'X'))
    p.box((0, -0.06, 5.85), (0.7, 0.12, 0.66), "mahogany_dark", bevel=0.02)
    for sx in (-1, 1):
        sc = p.lathe([(0.0, -0.04), (0.06, -0.04), (0.06, 0.04), (0.0, 0.04)], "gilt", segments=8)
        p.move(sc, Matrix.Translation((sx * 0.4, -0.14, 5.6)) @ Matrix.Rotation(math.radians(90), 4, 'Y'))
    p.lathe([(0.0, 0.0), (0.05, 0.0), (0.07, 0.05), (0.05, 0.1), (0.07, 0.14), (0.0, 0.2)], "gilt", segments=10,
            center=(0, -0.12, 6.33))
    return p


def _emblem(ctx):
    """An armillary sphere in gold on dark green enamel, on the disc in the
    model's x-z plane (centre (0, 5.95)): outer ring, equator and tilted
    ecliptic as flat ellipses, the meridian, the axis and a small stand."""
    s = Surface(ctx.N)
    x, z = ctx.p[:, 0] / 0.85, ctx.p[:, 2] - 5.95
    s.use_ramp(P["enl_baize"], shade=3.0 + ctx.fbm(9.0, 2, 681) * 0.5 + _dither(ctx, 0.4, 682))
    tx = ctx.texel * 1.3

    def ellipse(a, b, rot):
        c, sn = math.cos(rot), math.sin(rot)
        xr, zr = x * c + z * sn, -x * sn + z * c
        return np.abs(np.hypot(xr / a, zr / b) - 1.0) * min(a, b) < tx

    ring = ellipse(0.2, 0.2, 0.0)
    equator = ellipse(0.2, 0.05, 0.0)
    ecliptic = ellipse(0.2, 0.06, math.radians(23.0))
    meridian = ellipse(0.07, 0.2, 0.0)
    axis = (np.abs(x * math.cos(0.4) - z * math.sin(0.4)) < tx * 0.8) & (np.hypot(x, z) < 0.25)
    globe = np.hypot(x, z) < 0.035
    stand = ((np.abs(x) < tx) & (z < -0.2) & (z > -0.27)) | ((np.abs(z + 0.27) < tx) & (np.abs(x) < 0.07))
    gold = ring | equator | ecliptic | meridian | axis | globe | stand
    s.use_ramp(P["gold"], mask=gold, shade=np.full(ctx.N, 6.8) + _dither(ctx, 1.0, 683))
    s.metal = np.where(gold, 0.9, 0.0)
    s.rough = np.where(gold, 0.3, 0.2)
    return s


def _frieze(title=None):
    def fn(ctx):
        s = Surface(ctx.N)
        u, v = ctx.uvm[:, 0], ctx.uvm[:, 1]
        s.use_ramp(P["enl_frieze"], shade=3.0 + ctx.fbm(5.0, 2, 687) * 0.5 + _dither(ctx, 0.5, 688)
                   - (1.0 - ctx.ao) * 2.5)
        front = ctx.n[:, 1] > 0.9           # after the turn the frieze faces +Y (not its bevels)
        vc = (np.min(v[front]) + np.max(v[front])) / 2 if front.any() else 0.0
        px = ctx.texel * 2
        if title is None:
            ink = front & E.greek_key(ctx, u, v, vc - 3.5 * px, 2)
        else:
            ink = front & font.text_mask(u, v, title, 0.0, vc - 3.5 * px, px)
        s.use_ramp(P["gold"], mask=ink, shade=np.full(ctx.N, 7.0) + _dither(ctx, 1.0, 689))
        s.metal = np.where(ink, 0.9, 0.0)
        s.rough = np.where(ink, 0.3, 0.28)
        return s
    return fn


def doorframe():
    p = Part("lib_doorframe")
    hw, H = 1.0, 2.8
    path = [(-hw, 0.22), (-hw, H), (hw, H), (hw, 0.22)]
    p.sweep([(0.0, 0.0), (0.03, 0.0), (0.03, 0.04), (0.05, 0.06), (0.05, 0.12), (0.035, 0.15), (0.035, 0.17),
             (0.0, 0.18)], path, "mahogany")
    for sx in (-1, 1):
        p.box((sx * (hw + 0.1), -0.035, 0.11), (0.24, 0.07, 0.22), "mahogany_dark", bevel=0.012)
    top = H + 0.18
    p.box((0, -0.04, top + 0.13), (2 * hw + 0.36, 0.08, 0.26), "mahogany", bevel=0.012)
    for sx in (-1, 1):
        pat = p.lathe([(0.0, 0.0), (0.07, 0.0), (0.07, 0.02), (0.04, 0.04), (0.0, 0.045)], "gilt", segments=10)
        p.move(pat, Matrix.Translation((sx * 0.75, -0.08, top + 0.13)) @ Matrix.Rotation(math.radians(-90), 4, 'X'))
    p.extrude([(0.0, top + 0.26), (-0.1, top + 0.26), (-0.1, top + 0.3), (-0.14, top + 0.33), (-0.14, top + 0.36),
               (0.0, top + 0.36)], -hw - 0.24, hw + 0.24, "mahogany", caps=True)
    tri = [(-hw - 0.2, top + 0.36), (hw + 0.2, top + 0.36), (0.0, top + 0.47)]
    front_prism(p, tri, 0.1, "mahogany", y_back=0.0)
    return p


SIGNS = {
    "lib_sign": ["BIBLIOTEKA", "KRÓLEWSKA"],
    "lib_sign_natural": ["GABINET HISTORII", "NATURALNEJ"],
    "lib_sign_collectors": ["GALERIA", "KOLEKCJONERÓW"],
    "lib_sign_clocks": ["ZEGARY", "I AUTOMATY"],
    "lib_sign_orrery": ["ROTUNDA", "PLANETARIUM"],
    "lib_sign_librarian": ["GABINET", "BIBLIOTEKARZA"],
}


def sign():
    p = Part("lib_sign")
    p.box((0, -0.02, 0), (1.5, 0.04, 0.34), "brass", bevel=0.012)
    p.box((0, -0.041, 0), (1.42, 0.004, 0.27), "field")
    for sx in (-1, 1):
        for sz in (-1, 1):
            p.lathe([(0.0, 0.0), (0.012, 0.0), (0.012, 0.004), (0.0, 0.007)], "brass", segments=6,
                    center=(sx * 0.68, -0.045, sz * 0.12))
    return p


def _sign_field(lines):
    def fn(ctx):
        u, v = ctx.uvm[:, 0], ctx.uvm[:, 1]
        s = Surface(ctx.N)
        s.use_ramp(P["enl_frieze"], shade=4.0 + ctx.fbm(8.0, 2, 691) * 0.4 + _dither(ctx, 0.4, 692))
        px = 2 * ctx.texel
        ink = np.zeros(ctx.N, dtype=bool)
        bases = [-0.036] if len(lines) == 1 else [0.025, -0.085]
        for line, base in zip(lines, bases):
            ink |= font.text_mask(u, v, line, 0.0, base, px)
        tx = ctx.texel
        frame = ((np.abs(np.abs(u) - 0.67) < tx * 0.6) & (np.abs(v) < 0.115)) | \
                ((np.abs(np.abs(v) - 0.115) < tx * 0.6) & (np.abs(u) < 0.67))
        g = ink | frame
        s.use_ramp(P["gold"], mask=g, shade=np.full(ctx.N, 7.2) + _dither(ctx, 0.8, 693))
        s.metal = np.where(g, 1.0, 0.0)
        s.rough = np.where(g, 0.25, 0.12)
        return s
    return fn


def build():
    only = os.environ.get("ENL_ONLY", "").split(",")

    def want(n):
        return only == [""] or n in only

    base = {"mahogany": E.mahogany, "mahogany_dark": lambda c: E.mahogany(c, seed=693, center=3.0),
            "gilt": E.gilt, "brass": E.worn_brass, "emblem": _emblem}
    out = []
    if want("lib_portal_4x4_5"):
        fns = dict(base, frieze=_frieze())
        out.append(kit("lib_portal_4x4_5", [portal()], fns, ppm=96, wall=True, ao_dist=0.35,
                       variants={"lib_portal_4x4_5_titled": dict(base, frieze=_frieze("BIBLIOTEKA KRÓLEWSKA"))},
                       preview_yaws=(-30.0, 0.0, 30.0, 60.0), preview_elevation=6.0,
                       preview_extra=[("crown", (0.0, 0.2, 5.6), 1.4, -15.0, 8.0)]))
    if want("lib_doorframe_2x2_8"):
        out.append(kit("lib_doorframe_2x2_8", [doorframe()], base, ppm=128, wall=True, ao_dist=0.2,
                       preview=False))
    if want("lib_sign"):
        out.append(kit("lib_sign", [sign()], {"brass": E.worn_brass, "field": _sign_field(SIGNS["lib_sign"])},
                       ppm=192, ground=None, wall=True, ao_dist=0.05,
                       variants={k: {"brass": E.worn_brass, "field": _sign_field(v)} for k, v in SIGNS.items()
                                 if k != "lib_sign"}, preview_yaws=(-20.0, 0.0, 20.0, 40.0), preview_elevation=4.0))
    return out
