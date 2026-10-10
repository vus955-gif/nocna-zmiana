"""Assyrian wing: carved gypsum orthostats, the relief slabs that line the
palace rooms from the floor to 3 m. Wall pieces in the kit convention:
origin on the floor at the wall plane, x = -W/2 .. W/2, the slab stands
0.12 m proud of the wall on the room side (Godot -Z), its face carved.

  asy_relief_2m        2 x 3 m slab, the default set: a winged genie with cone
                       and bucket, the Standard Inscription across him (Nimrud)
  asy_relief_1m        1 x 3 m slab, the default set: a life-size spearman under
                       a band of text
                       Themes (texture sets asy_relief_<theme>_2m / _1m on the same
                       meshes, for ArtKit bands with "set": "asy_relief_<theme>_"):
                       genie_l  the genie facing left (diadem) / text
                       army     spearmen marching over archers / spearman
                       chariot  the king's chariot over spearmen / spearman
                       hunt     lion leaping at a spearman, dying lioness / text
                       lions    great walking lion, leaping lion / text
                       text     the Standard Inscription / text
                       plain    dressed slab with a rosette band / plain
  asy_relief_wake      the 1 m spearman slab whose warrior is about to step
                       out: part "figure" (the carved man, a separate slab in a
                       figure-shaped pocket of the face) and glowing cracks
                       round him in the emission map (EXTRAS emission 0 = at
                       rest; raise it on own_materials to telegraph, hide
                       "figure" when the relief warrior steps out: the empty
                       pocket stays, the enemy spawns on the same spot).
  asy_relief_wake_lion the same for the Lion Room's 2 m slab and its lion.

Reliefs are drawn in 2D (artlib.asy_panels, artlib.asy_figures) and baked
at 128 px/m: albedo with the carving's crevices, rims and paint traces,
normal map from the carved height, roughness.
"""
import math

import numpy as np
from mathutils import Vector

from artlib import asy, asy_mesh as AM, asy_relief as rl
from artlib import asy_figures as F
from artlib import asy_panels as PN
from artlib.archkit import kit
from artlib.geo import Part

T = 0.12          # slab thickness (proud of the wall)
C = 0.014         # chamfer of the exposed arrises
PPM = PN.PPM
POCKET = -0.012   # floor of a figure pocket, just in front of the wall plane


def _quad(p, pts, slot, want):
    f = p.poly(pts, slot)[0]
    f.normal_update()
    if f.normal.dot(Vector(want)) < 0:
        f.normal_flip()
    return f


def slab(name, W, H, front=True):
    """The slab, built facing the viewer at -Y (kit() turns it): the front
    face carries slot "relief" (``front`` False: the caller makes it),
    chamfers, sides and top slot "stone"."""
    p = Part(name)
    x0, x1 = -W / 2, W / 2
    yf, yc = -T, -T + C            # front plane, where the chamfers meet the sides
    zt = H
    fx0, fx1, fz1 = x0 + C, x1 - C, zt - C
    if front:
        _quad(p, [(fx0, yf, 0.0), (fx1, yf, 0.0), (fx1, yf, fz1), (fx0, yf, fz1)], "relief", (0, -1, 0))
    _quad(p, [(x0, yc, 0.0), (fx0, yf, 0.0), (fx0, yf, fz1), (x0, yc, fz1)], "stone", (-1, -1, 0))
    _quad(p, [(fx1, yf, 0.0), (x1, yc, 0.0), (x1, yc, fz1), (fx1, yf, fz1)], "stone", (1, -1, 0))
    _quad(p, [(fx0, yf, fz1), (fx1, yf, fz1), (fx1, yc, zt), (fx0, yc, zt)], "stone", (0, -1, 1))
    _quad(p, [(x0, yc, fz1), (fx0, yf, fz1), (fx0, yc, zt)], "stone", (-1, -1, 1))
    _quad(p, [(fx1, yf, fz1), (x1, yc, fz1), (fx1, yc, zt)], "stone", (1, -1, 1))
    _quad(p, [(x0, 0.0, 0.0), (x0, yc, 0.0), (x0, yc, fz1), (x0, 0.0, fz1)], "stone", (-1, 0, 0))
    _quad(p, [(x0, 0.0, fz1), (x0, yc, fz1), (fx0, yc, zt), (fx0, 0.0, zt)], "stone", (-1, 0, 1))
    _quad(p, [(x1, yc, 0.0), (x1, 0.0, 0.0), (x1, 0.0, fz1), (x1, yc, fz1)], "stone", (1, 0, 0))
    _quad(p, [(x1, yc, fz1), (x1, 0.0, fz1), (fx1, 0.0, zt), (fx1, yc, zt)], "stone", (1, 0, 1))
    _quad(p, [(fx0, yc, zt), (fx1, yc, zt), (fx1, 0.0, zt), (fx0, 0.0, zt)], "stone", (0, 0, 1))
    return p


def _stone(c):
    return asy.alabaster(c, center=9.4)


def _fns(R):
    return {"relief": asy.relief_material(asy.ReliefMaps(R), uv=AM.UV), "stone": _stone}


# --------------------------------------------------------------------------
# awakening slabs: the figure in a pocket, cracks round it
# --------------------------------------------------------------------------

def cracks(R, loop, seed, n=16, reach=(0.12, 0.42)):
    """Cracks running out from a figure's outline into the slab face, cut
    into the base, glowing (R.emit) brightest at the seam."""
    rng = np.random.default_rng(seed)
    pts = np.array(loop)
    seam = R.polyline([tuple(q) for q in loop] + [tuple(loop[0])])
    glow = np.clip(1.0 - seam / (2.2 * R.px), 0.0, 1.0)
    R.base_cut(seam, R.px * 1.4, 0.004)
    cx, cy = pts[:, 0].mean(), pts[:, 1].mean()
    lens = np.hypot(np.diff(pts[:, 0], append=pts[0, 0]), np.diff(pts[:, 1], append=pts[0, 1]))
    acc = np.cumsum(lens)
    for k in range(n):
        t = (k + rng.random() * 0.6) / n * acc[-1]
        i = int(np.searchsorted(acc, t))
        x, y = pts[min(i, len(pts) - 1)]
        dx, dy = x - cx, y - cy
        L = math.hypot(dx, dy) or 1.0
        ang = math.atan2(dy / L, dx / L) + (rng.random() - 0.5) * 0.9
        length = reach[0] + rng.random() * (reach[1] - reach[0])
        path = [(x, y)]
        steps = 7
        for s_ in range(steps):
            ang += (rng.random() - 0.5) * 0.9
            x += math.cos(ang) * length / steps
            y += math.sin(ang) * length / steps
            path.append((x, y))
        d = R.polyline(path)
        R.base_cut(d, R.px * 1.0, 0.003)
        # brightness fades along the crack
        along = np.clip(np.hypot(R.X - path[0][0], R.Y - path[0][1]) / length, 0.0, 1.0)
        glow = np.maximum(glow, np.clip(1.0 - d / (1.2 * R.px), 0.0, 1.0) * (1.0 - along * 0.75))
        if rng.random() < 0.5:
            j = 2 + int(rng.integers(3))
            bx, by = path[j]
            b2 = [(bx, by)]
            a2 = ang + (0.8 if rng.random() < 0.5 else -0.8)
            for s_ in range(3):
                bx += math.cos(a2) * length / steps
                by += math.sin(a2) * length / steps
                b2.append((bx, by))
            d2 = R.polyline(b2)
            R.base_cut(d2, R.px * 0.9, 0.0025)
            glow = np.maximum(glow, np.clip(1.0 - d2 / (1.1 * R.px), 0.0, 1.0) * 0.45)
    R.emit = np.maximum(R.emit, glow)


def wake(name, W, panel_fn, figure_fn, fig_origin, seed):
    """An awakening slab: ``panel_fn()`` -> the slab relief without the
    figure; ``figure_fn(R)`` draws the figure (all into part "fig") at its
    place. Returns the kit Model."""
    H = 3.0
    R = panel_fn()
    RF = rl.Relief(W, H, PPM, u0=-W / 2, v0=0.0, seed=seed)
    figure_fn(RF)
    loops = rl.outlines(RF, RF.layers["fig"].mask, tol=0.0075)
    loop = loops[0]
    cracks(R, loop, seed)
    p = slab(name, W, H, front=False)
    # the face with the figure-shaped hole (pre-turn frame: front at -T, toward -Y)
    x0, x1, fz1 = -W / 2 + C, W / 2 - C, H - C
    outer = [(x0, 0.0), (x1, 0.0), (x1, fz1), (x0, fz1)]
    AM.cap(p, [outer, loop], -T, "relief", -1, mirror=False)
    AM.walls(p, loop, -T, POCKET, "break", outward=False, mirror=False)
    us = [q[0] for q in loop]
    vs = [q[1] for q in loop]
    _quad(p, [(min(us) - 0.01, POCKET, min(vs) - 0.01), (max(us) + 0.01, POCKET, min(vs) - 0.01),
              (max(us) + 0.01, POCKET, max(vs) + 0.01), (min(us) - 0.01, POCKET, max(vs) + 0.01)], "break",
          (0, -1, 0))
    fig = Part("figure", origin=(fig_origin[0], (POCKET - T) * 0.5, fig_origin[1]))
    AM.cap(fig, [loop], -T - 0.006, "fig", -1, mirror=False)
    AM.walls(fig, loop, POCKET, -T - 0.006, "break", outward=True, mirror=False)
    fig_maps = asy.ReliefMaps(RF, parts=["fig"], base=False)
    fns = {"relief": asy.relief_material(asy.ReliefMaps(R), uv=AM.UV, emit_color=(1.0, 0.45, 0.15)),
           "fig": asy.relief_material(fig_maps, uv=AM.UV), "stone": _stone,
           "break": lambda c: asy.gypsum_break(c, seed=seed)}
    return kit(name, [p, fig], fns, ppm=PPM, wall=True, ao_rays=8, ao_dist=0.25, normal_strength=2.0,
               preview_yaws=(-25.0, 30.0, 60.0, -60.0), preview_elevation=6.0,
               preview_extra=[("close", (0.0, 0.0, 1.5), 1.0 if W < 1.5 else 1.2, 20.0, 4.0)])


def _warrior_fig(RF):
    PN.warrior_on(RF, part="fig")


def _lion_fig(RF):
    F.lion(F.Pen(RF, rl.Xf(PN.WAKE_LION_AT[0], PN.WAKE_LION_AT[1], 1.0, 1), default="fig", depth=1.0), pose="walk")


def _lions_without_lion():
    R = PN.slab(2.0, 3.0, PPM, 27)
    PN.field(R, PN.PLINTH, 1.36)
    PN.field(R, 1.8, 2.94)
    PN.text_band(R, 1.39, 1.77, seed=27)
    F.lion(PN._pen(R, 0.0, 1.84, 0.82), pose="leap")
    return R


def build():
    out = []
    # texture sets named <prefix><theme>_<module>: an ArtKit band {"prefix": "asy_relief_",
    # "set": "asy_relief_<theme>_"} dresses a whole wall in one theme
    sets2 = {"asy_relief_genie_l_2m": PN.DESIGNS["genie_l"], "asy_relief_army_2m": PN.warriors,
             "asy_relief_chariot_2m": PN.chariot, "asy_relief_hunt_2m": PN.lionhunt,
             "asy_relief_lions_2m": PN.lions, "asy_relief_text_2m": PN.inscription, "asy_relief_plain_2m": PN.plain}
    out.append(kit("asy_relief_2m", [slab("asy_relief_2m", 2.0, 3.0)], _fns(PN.genie()), ppm=PPM, wall=True,
                   ao_rays=6, ao_dist=0.3, normal_strength=2.0,
                   variants={name: _fns(fn()) for name, fn in sets2.items()},
                   preview_yaws=(-20.0, 25.0, 60.0, -60.0), preview_elevation=6.0,
                   preview_extra=[("close", (0.0, 0.0, 1.9), 0.75, 0.0, 4.0),
                                  ("rake", (0.0, 0.0, 1.5), 1.6, -70.0, 10.0)]))
    sets1 = {"asy_relief_genie_l_1m": lambda: PN.inscription(seed=51, W=1.0),
             "asy_relief_army_1m": lambda: PN.spearman_1m(seed=52),
             "asy_relief_chariot_1m": lambda: PN.spearman_1m(seed=53),
             "asy_relief_hunt_1m": lambda: PN.inscription(seed=54, W=1.0),
             "asy_relief_lions_1m": lambda: PN.inscription(seed=55, W=1.0),
             "asy_relief_text_1m": PN.DESIGNS["text_1m"],
             "asy_relief_plain_1m": lambda: PN.plain(seed=45, W=1.0)}
    out.append(kit("asy_relief_1m", [slab("asy_relief_1m", 1.0, 3.0)], _fns(PN.spearman_1m()), ppm=PPM, wall=True,
                   ao_rays=6, ao_dist=0.3, normal_strength=2.0,
                   variants={name: _fns(fn()) for name, fn in sets1.items()},
                   preview_yaws=(-20.0, 25.0, 60.0, -60.0), preview_elevation=6.0))
    out.append(wake("asy_relief_wake", 1.0, lambda: PN.spearman_1m(figure=False), _warrior_fig,
                    (PN.WAKE_WARRIOR_AT[0], PN.WAKE_WARRIOR_AT[1]), 47))
    out.append(wake("asy_relief_wake_lion", 2.0, _lions_without_lion, _lion_fig,
                    (PN.WAKE_LION_AT[0], PN.WAKE_LION_AT[1]), 49))
    return out
