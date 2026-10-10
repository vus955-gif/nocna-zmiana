"""Enlightenment wing: the Clocks and Automata room (ticking, pendulums).

  lib_clock_longcase  mahogany longcase clock 2.3 m: plinth, trunk with a
                      glazed window on the pendulum, hood with an arched
                      brass dial (silvered chapter ring, Roman numerals,
                      gilt spandrels, a moon-phase arch), three brass
                      finials. Kit convention (origin = centre of the base,
                      front -Z). Parts: hand_hour, hand_minute (pivot at the
                      dial centre, Godot (0, 1.95, -0.145)), pendulum (pivot
                      at the suspension, Godot (0, 1.82, -0.04); bob at
                      y 0.95, seen through the trunk window). Glass =
                      lib_clock_longcase_glass.
  lib_clock_wall      a wall of seven clocks on a 3.2 x 2.6 m area of wall
                      (from 0.9 to 3.3 m up): a station clock, a Vienna
                      regulator, a gilt sunburst, an octagonal school clock,
                      a ship's clock, a rococo cartel clock and a banjo
                      clock, every one stopped at another hour. Wall-run
                      frame like the bookcases: origin on the floor on the
                      wall plane, clocks on -Z. Parts hour_1..7 and
                      minute_1..7 (pivots at their dial centres) and
                      pendulum_1 (the regulator), pendulum_2 (the banjo).

Hands and pendulums turn about Godot Z (the axis through the dial):
rotation.z increasing turns a hand clockwise as the guard sees it; a
pendulum swings with rotation.z = +/-0.12 rad.
"""
import math
import os

import numpy as np
from mathutils import Matrix

from artlib import enl_materials as E
from artlib import font
from artlib import kit as K
from artlib import materials as M
from artlib.archkit import facing, kit
from artlib.enl_materials import P
from artlib.geo import Part
from artlib.materials import _dither
from artlib.painter import Surface
from models import lib_cases  # noqa: F401  (registers the enl_silver ramp)

ROMAN = ("XII", "I", "II", "III", "IIII", "V", "VI", "VII", "VIII", "IX", "X", "XI")
ARABIC = ("12", "1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11")


def disc(p, c, r, mat, segments=24, y=None):
    """A flat round face toward the viewer (-Y) at depth ``c[1]``."""
    x, yy, z = c
    f = p.poly([(x + r * math.cos(math.tau * i / segments), yy, z + r * math.sin(math.tau * i / segments))
                for i in range(segments)], mat)[0]
    f.normal_update()
    if f.normal.y > 0:
        f.normal_flip()
    return [f]


def bezel(p, c, r, w, d, mat, segments=24):
    """A round frame of width w and depth d round a dial (lathe about Y)."""
    x, y, z = c
    f = p.lathe([(r, 0.0), (r + w, 0.0), (r + w, d), (r + w * 0.5, d + 0.008), (r, d)], mat, segments=segments,
                cap_bottom=False, cap_top=False)
    p.move(f, Matrix.Translation((x, y, z)) @ Matrix.Rotation(math.radians(90), 4, 'X'))
    return f


def hand(p, c, length, width, angle_deg, mat, tail=0.25, spade=True):
    """A flat clock hand on the dial plane (y = c[1] - offset), pointing at
    ``angle_deg`` clockwise from 12 o'clock as seen from the front (-Y)."""
    x, y, z = c
    pts = [(-width * 0.5, -length * tail), (width * 0.5, -length * tail), (width * 0.35, length * 0.75)]
    if spade:
        pts += [(width * 1.3, length * 0.8), (0.0, length), (-width * 1.3, length * 0.8)]
    else:
        pts += [(0.0, length)]
    pts += [(-width * 0.35, length * 0.75)]
    f = p.poly([(x + px, y, z + pz) for px, pz in pts], mat)[0]
    f.normal_update()
    if f.normal.y > 0:
        f.normal_flip()
    # seen from -Y the x axis points right: clockwise = rotation about +Y by +angle
    p.move([f], Matrix.Translation((x, 0, z)) @ Matrix.Rotation(math.radians(angle_deg), 4, 'Y')
           @ Matrix.Translation((-x, 0, -z)))
    back = p.poly([(x + px, y + 0.0015, z + pz) for px, pz in pts], mat)[0]
    back.normal_update()
    if back.normal.y < 0:
        back.normal_flip()
    p.move([back], Matrix.Translation((x, 0, z)) @ Matrix.Rotation(math.radians(angle_deg), 4, 'Y')
           @ Matrix.Translation((-x, 0, -z)))
    return [f, back]


# --- dial painter -------------------------------------------------------------------------

def dial_painter(dials):
    """``dials``: list of dicts {c: (x_pre, z), r, ground, ring, numerals, ink, style} in the model's
    pre-turn frame; the painter un-turns the texels (x_final = -x_pre)."""
    def fn(ctx):
        s = Surface(ctx.N)
        x = -ctx.p[:, 0]
        z = ctx.p[:, 2]
        best = np.full(ctx.N, 1e9)
        idx = np.zeros(ctx.N, dtype=np.int64)
        for k, d in enumerate(dials):
            dist = np.hypot(x - d["c"][0], z - d["c"][1])
            m = dist < best
            best[m] = dist[m]
            idx[m] = k
        s.use_ramp(P["enamel_white"], shade=np.full(ctx.N, 6.0))
        for k, d in enumerate(dials):
            m = idx == k
            if not m.any():
                continue
            u = x - d["c"][0]
            v = z - d["c"][1]
            r = np.hypot(u, v)
            R = d["r"]
            ground = d.get("ground", "enamel_white")
            gsh = d.get("ground_center", 6.4)
            s.use_ramp(P[ground], mask=m, shade=gsh + ctx.fbm(6.0, 2, 1001 + k) * 0.4 + _dither(ctx, 0.4, 1002)
                       - (1.0 - ctx.ao) * 2.0)
            ink = np.zeros(ctx.N, dtype=bool)
            tx = ctx.texel
            # chapter ring rules and minute ticks
            ring_in, ring_out = R * 0.72, R * 0.93
            ink |= m & ((np.abs(r - ring_out) < tx * 0.6) | (np.abs(r - ring_in) < tx * 0.6))
            ang = np.degrees(np.arctan2(u, v)) % 360.0
            minute = (np.abs(((ang + 3.0) % 6.0) - 3.0) < np.degrees(tx * 0.5 / np.maximum(r, 1e-3))) & \
                (r > R * 0.86) & (r < ring_out)
            hour = (np.abs(((ang + 15.0) % 30.0) - 15.0) < np.degrees(tx * 0.8 / np.maximum(r, 1e-3))) & \
                (r > R * 0.78) & (r < ring_out)
            ink |= m & (minute | hour)
            if d.get("ring"):
                band = m & (r > ring_in) & (r < ring_out)
                s.use_ramp(P[d["ring"]], mask=band & ~ink, shade=np.full(ctx.N, 5.6) + _dither(ctx, 0.4, 1003))
            nums = d.get("numerals", ROMAN)
            px = tx
            if R >= 0.2 and nums is not None:
                # numerals only where a 5 x 7 pixel figure fits (the big station clock)
                rn = R * 0.6
                for h, text in enumerate(nums):
                    a = math.radians(30 * h)
                    cu, cv = rn * math.sin(a), rn * math.cos(a)
                    ink |= m & font.text_mask(u, v, text, cu, cv - 3.5 * px, px)
            else:
                # baton hour marks inside the chapter ring, a double baton at twelve
                bat = (np.abs(((ang + 15.0) % 30.0) - 15.0) < np.degrees(tx * 0.9 / np.maximum(r, 1e-3))) &                     (r > R * 0.5) & (r < ring_in - tx)
                twelve = (np.abs(u) < tx * 1.6) & (v > R * 0.5) & (v < ring_in - tx) & (np.abs(u) > tx * 0.4)
                quarter = bat & (np.abs(((ang + 45.0) % 90.0) - 45.0) < 1e-3 + np.degrees(tx * 1.8 / np.maximum(r, 1e-3)))
                ink |= m & (bat | twelve | quarter)
            inkramp = d.get("ink", "enl_ink")
            s.use_ramp(P[inkramp], mask=ink, shade=np.full(ctx.N, 1.5 if inkramp == "enl_ink" else 6.5))
            if d.get("moon"):
                mu, mv = u, v - R * 1.25
                arch = m & (v > R * 0.95)
                sky = arch & (np.hypot(mu, mv) < R * 0.6)
                s.use_ramp(P["enl_morocco_blue"], mask=sky, shade=np.full(ctx.N, 5.0) + _dither(ctx, 0.5, 1004))
                moon = sky & (np.hypot(mu - R * 0.2, mv) < R * 0.2)
                s.use_ramp(P["enl_paper"], mask=moon, shade=np.full(ctx.N, 8.0))
                star = sky & ~moon & (ctx.rand(1005) > 0.95)
                s.use_ramp(P["gold"], mask=star, shade=np.full(ctx.N, 7.5))
            if d.get("spandrels"):
                corner = m & (np.abs(u) > R * 0.85) & (np.abs(v) > R * 0.85) & (np.abs(v) < R * 1.05)
                s.use_ramp(P["gold"], mask=corner & (ctx.fbm(60.0, 1, 1006) > -0.1), shade=np.full(ctx.N, 6.8))
        s.rough = np.full(ctx.N, 0.35)
        return s
    return fn


# --- the longcase -----------------------------------------------------------------------------

DIAL_C = (0.0, 1.95)
DIAL_R = 0.15


def longcase():
    """Built facing -Y (kit turns it)."""
    p = Part("lib_clock_longcase")
    g = Part("lib_clock_longcase_glass")
    p.box((0, 0, 0.06), (0.58, 0.32, 0.12), "mahogany_dark", bevel=0.01)
    p.box((0, 0, 0.32), (0.54, 0.29, 0.42), "mahogany", bevel=0.012)
    p.box((0, -0.15, 0.32), (0.4, 0.012, 0.3), "panel", bevel=0.015)
    p.box((0, 0, 0.56), (0.5, 0.27, 0.06), "mahogany", bevel=0.012)
    p.box((0, 0, 1.1), (0.42, 0.24, 1.02), "mahogany", bevel=0.01)
    # trunk door with a glazed lenticle on the pendulum
    p.box((0, -0.125, 1.1), (0.32, 0.012, 0.9), "panel", bevel=0.01)
    p.box((0, -0.128, 0.98), (0.17, 0.012, 0.36), "back")
    bezel(p, (0, -0.135, 0.98), 0.085, 0.02, 0.012, "brass", segments=16)
    facing(g, [(-0.085, -0.142, 0.8), (0.085, -0.142, 0.8), (0.085, -0.142, 1.16), (-0.085, -0.142, 1.16)], "glass",
           (0, -1, 0))
    p.box((0, -0.14, 1.36), (0.03, 0.012, 0.08), "brass", bevel=0.003)
    # hood: base moulding, dial, glazed door, columns, broken pediment, finials
    p.box((0, -0.01, 1.64), (0.5, 0.3, 0.06), "mahogany", bevel=0.012)
    p.box((0, 0.0, 1.98), (0.44, 0.26, 0.62), "mahogany", bevel=0.01)
    p.box((0, -0.136, DIAL_C[1] - 0.02), (0.34, 0.012, 0.34), "dial")
    arch = disc(p, (0, -0.1425, DIAL_C[1] + 0.15), 0.17, "dial", segments=20)
    K.keep(p, arch, lambda c: c.z > DIAL_C[1] + 0.148)
    for sx in (-1, 1):
        K.seg(p, (sx * 0.2, -0.15, 1.68), (sx * 0.2, -0.15, 2.28), [(0.022, 0.0), (0.02, 1.0)], "brass_col", segments=8)
    facing(g, [(-0.18, -0.165, 1.78), (0.18, -0.165, 1.78), (0.18, -0.165, 2.3), (-0.18, -0.165, 2.3)], "glass",
           (0, -1, 0))
    p.box((0, -0.01, 2.32), (0.5, 0.3, 0.06), "mahogany", bevel=0.012)
    for sx in (-1, 1):
        ped = p.box((0, 0, 0), (0.24, 0.26, 0.05), "mahogany", bevel=0.01)
        p.move(ped, Matrix.Translation((sx * 0.14, -0.01, 2.4)) @ Matrix.Rotation(math.radians(-sx * 25), 4, 'Y'))
    for x in (-0.22, 0.0, 0.22):
        z0 = 2.35 if x else 2.36
        p.lathe([(0.025, 0.0), (0.03, 0.02), (0.02, 0.05), (0.035, 0.09), (0.012, 0.15), (0.0, 0.17)], "brass",
                segments=8, center=(x, -0.01, z0 + (0.06 if x == 0 else 0.0)))
    hh = Part("hand_hour", origin=(0, -0.145, DIAL_C[1]), parent="lib_clock_longcase")
    hand(hh, (0, -0.146, DIAL_C[1]), 0.08, 0.012, 300.0, "hand")
    hm = Part("hand_minute", origin=(0, -0.145, DIAL_C[1]), parent="lib_clock_longcase")
    hand(hm, (0, -0.15, DIAL_C[1]), 0.12, 0.008, 60.0, "hand", spade=False)
    pend = Part("pendulum", origin=(0, 0.04, 1.82), parent="lib_clock_longcase")
    K.seg(pend, (0, 0.04, 1.82), (0, 0.04, 0.98), [(0.005, 0.0), (0.005, 1.0)], "brass", segments=6)
    bob = K.sphere(pend, (0, 0.04, 0.95), 0.07, "bob", segments=14, rings=7, squash=(1.0, 0.25))
    del bob
    return [p, g, hh, hm, pend]


# --- the wall of clocks -------------------------------------------------------------------------

WALL_DIALS = [
    # name, centre (x, z), dial r, case style, hour, minute, numerals
    (1, (-1.15, 2.85), 0.22, "station", 7.0, 40.0, ARABIC),
    (2, (-0.38, 2.75), 0.11, "regulator", 3.0, 0.0, ROMAN),
    (3, (0.42, 2.9), 0.11, "sunburst", 11.0, 55.0, None),
    (4, (1.15, 2.6), 0.15, "octagon", 2.0, 20.0, ARABIC),
    (5, (0.42, 2.12), 0.1, "ship", 5.0, 30.0, ARABIC),
    (6, (1.12, 1.62), 0.09, "cartel", 9.0, 45.0, ROMAN),
    (7, (-1.12, 2.05), 0.13, "banjo", 12.0, 5.0, ROMAN),
]


def wall_of_clocks():
    """Built facing -Y on the wall plane y = 0 (the kit turns it)."""
    root = Part("lib_clock_wall")
    parts = [root]
    dials = []
    for k, (x, z), r, style, hh, mm, nums in WALL_DIALS:
        dy = -0.06
        if style == "station":
            bezel(root, (x, -0.02, z), r, 0.04, 0.05, "mahogany", segments=28)
            disc(root, (x, -0.055, z), r + 0.002, "dial", segments=28)
            dy = -0.07
        elif style == "regulator":
            root.box((x, -0.07, z - 0.4), (0.36, 0.14, 1.12), "walnut", bevel=0.012)
            root.box((x, -0.141, z - 0.45), (0.26, 0.004, 0.75), "back")
            for zz in (z + 0.2, z - 0.96):
                root.box((x, -0.075, zz), (0.42, 0.15, 0.06), "walnut", bevel=0.01)
            root.lathe([(0.0, 0.0), (0.03, 0.02), (0.012, 0.1), (0.0, 0.12)], "brass", segments=8,
                       center=(x, -0.075, z + 0.23))
            disc(root, (x, -0.143, z), r + 0.01, "dial", segments=24)
            bezel(root, (x, -0.143, z), r + 0.005, 0.015, 0.008, "brass", segments=24)
            dy = -0.15
            pend = Part("pendulum_1", origin=(x, -0.12, z - 0.12), parent="lib_clock_wall")
            K.seg(pend, (x, -0.12, z - 0.12), (x, -0.12, z - 0.7), [(0.004, 0.0), (0.004, 1.0)], "brass", segments=6)
            K.sphere(pend, (x, -0.12, z - 0.72), 0.06, "bob", segments=12, rings=6, squash=(1.0, 0.25))
            parts.append(pend)
        elif style == "sunburst":
            for i in range(16):
                a = math.tau * i / 16
                L = 0.32 if i % 2 == 0 else 0.22
                K.cone(root, (x + (r + 0.02) * math.sin(a), -0.03, z + (r + 0.02) * math.cos(a)),
                       (math.sin(a), 0.0, math.cos(a)), L - r, 0.02, "gilt", segments=4, tip=0.004)
            bezel(root, (x, -0.02, z), r, 0.03, 0.04, "gilt", segments=24)
            disc(root, (x, -0.05, z), r + 0.002, "dial", segments=24)
            dy = -0.065
        elif style == "octagon":
            oct_ = [(x + (r + 0.07) * math.cos(math.tau * i / 8 + math.pi / 8), z + (r + 0.07) * math.sin(math.tau * i / 8 + math.pi / 8))
                    for i in range(8)]
            from artlib.archkit import front_prism
            front_prism(root, oct_, 0.05, "oak")
            root.box((x, -0.03, z - r - 0.22), (0.2, 0.06, 0.26), "oak", bevel=0.012)
            disc(root, (x, -0.052, z), r + 0.003, "dial", segments=24)
            bezel(root, (x, -0.052, z), r, 0.012, 0.012, "brass", segments=24)
            dy = -0.07
        elif style == "ship":
            bezel(root, (x, -0.02, z), r, 0.025, 0.06, "brass", segments=24)
            disc(root, (x, -0.06, z), r + 0.002, "dial", segments=24)
            dy = -0.075
        elif style == "cartel":
            for i in range(10):
                a = math.tau * i / 10
                K.sphere(root, (x + 0.15 * math.sin(a), -0.04, z + 0.02 + 0.2 * math.cos(a)), 0.05, "gilt",
                         segments=8, rings=5, squash=(1.0, 0.6))
            root.lathe([(0.0, 0.0), (0.04, 0.03), (0.02, 0.12), (0.0, 0.14)], "gilt", segments=8,
                       center=(x, -0.05, z + 0.2))
            bezel(root, (x, -0.06, z), r, 0.02, 0.02, "gilt", segments=24)
            disc(root, (x, -0.075, z), r + 0.002, "dial", segments=24)
            dy = -0.09
        elif style == "banjo":
            bezel(root, (x, -0.02, z), r, 0.03, 0.05, "brass", segments=24)
            disc(root, (x, -0.06, z), r + 0.002, "dial", segments=24)
            root.box((x, -0.035, z - 0.42), (0.14, 0.07, 0.56), "mahogany", bevel=0.01)
            root.box((x, -0.035, z - 0.85), (0.26, 0.08, 0.3), "mahogany", bevel=0.012)
            root.box((x, -0.076, z - 0.85), (0.18, 0.004, 0.2), "back")
            root.box((x, -0.072, z - 0.42), (0.09, 0.004, 0.42), "glass_paint")
            dy = -0.075
            pend = Part("pendulum_2", origin=(x, -0.06, z - 0.2), parent="lib_clock_wall")
            K.seg(pend, (x, -0.06, z - 0.2), (x, -0.06, z - 0.82), [(0.003, 0.0), (0.003, 1.0)], "brass", segments=6)
            K.sphere(pend, (x, -0.06, z - 0.85), 0.045, "bob", segments=12, rings=6, squash=(1.0, 0.25))
            parts.append(pend)
        ph = Part(f"hour_{k}", origin=(x, dy, z), parent="lib_clock_wall")
        hand(ph, (x, dy - 0.002, z), r * 0.55, r * 0.07, hh * 30.0 + mm * 0.5, "hand")
        pm = Part(f"minute_{k}", origin=(x, dy, z), parent="lib_clock_wall")
        hand(pm, (x, dy - 0.005, z), r * 0.82, r * 0.045, mm * 6.0, "hand", spade=False)
        parts += [ph, pm]
        dials.append(dict(c=(x, z), r=r, numerals=nums or ROMAN,
                          ground={"ship": "enl_paper", "cartel": "enamel_white"}.get(style, "enamel_white"),
                          ground_center={"ship": 7.2}.get(style, 6.4),
                          ink="enl_ink"))
        if style == "sunburst":
            dials[-1].update(ground="gold", ground_center=6.0, ink="enl_ink")
    return parts, dials


def build():
    only = os.environ.get("ENL_ONLY", "").split(",")

    def want(n):
        return only == [""] or n in only

    base = {"mahogany": E.mahogany, "mahogany_dark": lambda c: E.mahogany(c, seed=1011, center=3.0),
            "panel": lambda c: E.mahogany(c, seed=1012, center=5.4), "back": lambda c: E.mahogany(c, 1013, 1.4),
            "brass": E.worn_brass, "brass_col": E.worn_brass, "gilt": E.gilt, "walnut": M.wood_dark,
            "oak": E.oak_dark, "hand": lambda c: M.gun_steel(c, seed=1014), "bob": E.worn_brass,
            "glass_paint": lambda c: E.glass_tint(c, ramp="enl_morocco_blue", center=4.0)}
    out = []
    if want("lib_clock_longcase"):
        parts = longcase()
        fns = dict(base, dial=dial_painter([dict(c=DIAL_C, r=DIAL_R, ground="brass", ground_center=6.0,
                                                 ring="enl_silver", numerals=ROMAN, moon=True, spandrels=True)]))
        out.append(kit("lib_clock_longcase", parts, fns, kinds={"glass": "glass"}, ppm=192, ground=0.0, ao_dist=0.15,
                       preview_yaws=(-25.0, 0.0, 30.0, 150.0), preview_elevation=8.0,
                       preview_extra=[("dial", (0.0, 0.14, DIAL_C[1] + 0.05), 0.26, 0.0, 0.0)]))
    if want("lib_clock_wall"):
        parts, dials = wall_of_clocks()
        fns = dict(base, dial=dial_painter(dials))
        out.append(kit("lib_clock_wall", parts, fns, ppm=192, ground=None, wall=True, ao_dist=0.12,
                       preview_yaws=(-25.0, 0.0, 25.0, 50.0), preview_elevation=4.0,
                       preview_extra=[("dials", (0.0, 0.1, 2.3), 1.0, 0.0, 0.0)]))
    return out
