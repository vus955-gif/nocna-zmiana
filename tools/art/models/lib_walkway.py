"""King's Library kit: the gallery walkway at y = 4 and what hangs on the
bookcases (Enlightenment wing).

  lib_walkway_fascia_{4m,2m,1m}  the walkway slab's edge toward the gallery:
                        mahogany fascia 0.45 m with a lacquered green frieze
                        and a gilt Greek key, cornice nosing, a 0.12 m beam
                        returning under the slab. Origin at its TOP on the
                        slab edge (datum = the walkway floor, y = 4); the
                        face on -Z (the gallery), like balcony_fascia.
  lib_walkway_fascia_end  0.25 m of the same with closed ends.
  lib_railing_{2m,1m}   Regency railing 1.0 m: mahogany curb and handrail on a
                        brass bar, black cast-iron rods every 0.125 m and a
                        lyre with a brass rosette in every 0.5 m bay.
                        Symmetric; origin = centre of the base on the
                        railing's centre line.
  lib_railing_post      newel post 1.15 m with a brass ball (run ends, every
                        4 m, stair heads).
  lib_walkway_bracket   cast-iron scroll console under the slab, 0.85 m
                        deep, 0.75 m tall: origin at its TOP BACK corner (on
                        the face it is fixed to, under the slab), it reaches
                        toward -Z. One under every pilaster.
  lib_ladder_rail_2m    brass rail of the library ladder on two brackets:
                        same frame as a lower bookcase module (origin on the
                        floor on the wall plane): rod at y 3.25, z -0.62.
  lib_ladder            rolling library ladder, oak with brass hooks and
                        wheels: origin on the floor under its hooks, i.e.
                        put it at (x, 0, -0.62) in a lower bookcase's frame;
                        the foot stands 0.85 m further out (-Z).
  lib_bust_bracket      carved mahogany console with a gilt acanthus for a
                        bust (bust / bust_bronze): origin on the wall plane
                        at the shelf's top centre; marker "bust_spot".
"""
import math
import os

import numpy as np
from mathutils import Matrix

from artlib import enl_materials as E
from artlib import materials as M
from artlib.archkit import kit, moulding
from artlib.geo import Part

# fascia profile: (depth toward the gallery = negative y, z) from under the slab to its top
FASCIA_LOW = [(0.12, -0.42), (-0.02, -0.42), (-0.02, -0.4), (-0.04, -0.38), (-0.04, -0.3)]
FASCIA_BAND = [(-0.04, -0.3), (-0.04, -0.17)]
FASCIA_TOP = [(-0.04, -0.17), (-0.06, -0.155), (-0.09, -0.13), (-0.12, -0.09), (-0.125, -0.05), (-0.12, -0.03),
              (-0.1, -0.015), (-0.09, 0.0), (0.0, 0.0)]


def fascia(W, caps=False):
    p = Part("lib_walkway_fascia")
    for prof, mat in ((FASCIA_LOW, "mahogany"), (FASCIA_BAND, "key"), (FASCIA_TOP, "mahogany")):
        if caps:
            p.extrude(prof, -W / 2, W / 2, mat, caps=len(prof) > 2)
        else:
            moulding(p, prof, W, mat)
    # gilt bead under the frieze
    p.box((0, -0.045, -0.305), (W, 0.012, 0.012), "gilt", bevel=0.004)
    if caps:
        # close the ends of the frieze band and the lower fascia
        for sx in (-1, 1):
            p.box((sx * (W / 2 - 0.004), 0.04, -0.235), (0.008, 0.16, 0.13), "mahogany")
    return p


def _lyre(p, xc, z0, z1, mat):
    """Two mirrored S-arms of a lyre between z0 and z1, a brass rosette."""
    for sx in (-1, 1):
        pts = []
        n = 6
        for i in range(n + 1):
            t = i / n
            z = z0 + (z1 - z0) * t
            x = 0.012 + 0.07 * math.sin(math.pi * t) * (1.0 - 0.25 * t)
            pts.append((xc + sx * x, 0.0, z))
        # curl at the top
        pts.append((xc + sx * 0.03, 0.0, z1 + 0.035))
        pts.append((xc + sx * 0.055, 0.0, z1 + 0.02))
        p.tube(pts, 0.0075, mat, sides=5)
    ros = p.lathe([(0.0, -0.012), (0.03, -0.012), (0.03, -0.004), (0.018, 0.006), (0.0, 0.01)], "brass",
                  segments=8)
    p.move(ros, Matrix.Translation((xc, 0.0, (z0 + z1) / 2)) @ Matrix.Rotation(math.radians(90), 4, 'X'))
    p.box((xc, 0.0, z0 - 0.01), (0.05, 0.022, 0.03), "brass")


def railing(W):
    p = Part("lib_railing")
    p.box((0, 0, 0.04), (W, 0.12, 0.08), "mahogany", bevel=0.012)
    p.box((0, 0, 0.095), (W, 0.035, 0.03), "iron", bevel=0.006)
    p.box((0, 0, 0.912), (W, 0.035, 0.024), "brass", bevel=0.005)
    p.box((0, 0, 0.955), (W, 0.08, 0.065), "mahogany", bevel=0.022)
    n = int(round(W / 0.125))
    for k in range(n):
        x = -W / 2 + (k + 0.5) * W / n
        if k % 4 in (1, 2):
            continue
        p.lathe([(0.009, 0.0), (0.009, 0.79)], "iron", segments=6, center=(x, 0.0, 0.11), cap_bottom=False,
                cap_top=False)
        p.box((x, 0.0, 0.5), (0.026, 0.026, 0.03), "brass")
    for b in range(int(round(W / 0.5))):
        xc = -W / 2 + 0.25 + b * 0.5
        _lyre(p, xc, 0.2, 0.78, "iron")
        p.lathe([(0.009, 0.0), (0.009, 0.09)], "iron", segments=6, center=(xc, 0.0, 0.11), cap_bottom=False,
                cap_top=False)
        p.lathe([(0.009, 0.0), (0.009, 0.08)], "iron", segments=6, center=(xc, 0.0, 0.82), cap_bottom=False,
                cap_top=False)
    return p


def post():
    p = Part("lib_railing_post")
    p.box((0, 0, 0.06), (0.2, 0.2, 0.12), "mahogany", bevel=0.015)
    p.box((0, 0, 0.55), (0.15, 0.15, 0.86), "mahogany", bevel=0.012)
    for a in range(4):
        f = p.box((0, -0.077, 0.55), (0.09, 0.008, 0.66), "panel", bevel=0.004)
        p.move(f, Matrix.Rotation(math.radians(90 * a), 4, 'Z'))
    p.box((0, 0, 0.995), (0.19, 0.19, 0.05), "mahogany", bevel=0.015)
    p.box((0, 0, 1.03), (0.15, 0.15, 0.03), "brass", bevel=0.008)
    p.lathe([(0.0, 1.045), (0.03, 1.045), (0.02, 1.06), (0.045, 1.09), (0.052, 1.11), (0.045, 1.13),
             (0.025, 1.145), (0.0, 1.15)], "brass", segments=12, cap_bottom=False)
    return p


def bracket():
    """Built facing -Y: fixed to the plane y = 0, top at z = 0."""
    p = Part("lib_walkway_bracket")
    p.box((0, -0.43, -0.03), (0.05, 0.86, 0.05), "iron", bevel=0.008)
    p.box((0, -0.012, -0.38), (0.11, 0.024, 0.76), "iron", bevel=0.008)

    def arc(cy, cz, ry, rz, a0, a1, n):
        return [(0.0, cy + ry * math.cos(math.radians(a0 + (a1 - a0) * i / n)),
                 cz + rz * math.sin(math.radians(a0 + (a1 - a0) * i / n))) for i in range(n + 1)]

    def volute(cy, cz, r0, a0, sweep, n=10):
        return [(0.0, cy + r0 * (1 - 0.6 * i / n) * math.cos(math.radians(a0 + sweep * i / n)),
                 cz + r0 * (1 - 0.6 * i / n) * math.sin(math.radians(a0 + sweep * i / n))) for i in range(n + 1)]

    # the main brace: a quarter ellipse from low at the back to the front of the bar,
    # rolled into a volute at each end
    main = list(reversed(volute(-0.075, -0.7, 0.045, 0.0, -330.0)))[:-1] + arc(-0.83, -0.7, 0.8, 0.64, 0, 90, 10)
    main = main[:-1] + volute(-0.83, -0.1, 0.04, 90.0, 330.0)
    p.tube(main, 0.016, "iron", sides=6)
    inner = arc(-0.5, -0.4, 0.45, 0.32, 10, 85, 7)
    inner = inner[:-1] + volute(-0.5 + 0.45 * math.cos(math.radians(85)), -0.4 + 0.32 * math.sin(math.radians(85))
                                - 0.03, 0.03, 90.0, 300.0, 7)
    p.tube(inner, 0.011, "iron", sides=5)
    for y, z in ((-0.42, -0.07), (-0.06, -0.42)):
        ros = p.lathe([(0.0, -0.02), (0.035, -0.02), (0.035, -0.008), (0.02, 0.008), (0.0, 0.014)], "brass",
                      segments=8)
        p.move(ros, Matrix.Translation((0.0, y, z)) @ Matrix.Rotation(math.radians(90), 4, 'Y'))
    # acorn drop under the front end of the bar
    p.lathe([(0.0, -0.21), (0.016, -0.205), (0.03, -0.18), (0.033, -0.15), (0.026, -0.125), (0.032, -0.115),
             (0.03, -0.1), (0.012, -0.085), (0.012, -0.055)], "brass", segments=8, center=(0.0, -0.83, 0.0))
    return p


RAIL_Z, RAIL_Y = 3.25, -0.62


def ladder_rail(W=2.0):
    p = Part("lib_ladder_rail")
    p.lathe([(0.016, 0.0), (0.016, W)], "brass", segments=8, cap_bottom=False, cap_top=False)
    p.move(list(p.bm.faces), Matrix.Translation((-W / 2, RAIL_Y, RAIL_Z)) @ Matrix.Rotation(math.radians(90), 4, 'Y'))
    for x in (-W / 2 + 0.3, W / 2 - 0.3):
        p.box((x, (RAIL_Y - 0.51) / 2, RAIL_Z), (0.024, 0.11, 0.024), "brass", bevel=0.005)
        p.box((x, -0.515, RAIL_Z), (0.07, 0.01, 0.09), "brass", bevel=0.004)
        p.lathe([(0.0, 0.0), (0.024, 0.0), (0.024, 0.02), (0.0, 0.03)], "brass", segments=8,
                center=(x, RAIL_Y, RAIL_Z - 0.02))
    return p


def ladder():
    """Built in its own frame (origin under the hooks), facing -Y."""
    p = Part("lib_ladder")
    foot_y, top_z = -0.85, RAIL_Z - 0.05
    L = math.hypot(foot_y + 0.05, top_z)
    tilt = math.atan2(-(foot_y + 0.05), top_z)          # lean back toward the rail
    hw = 0.24
    parts = []
    for sx in (-1, 1):
        parts += p.box((sx * hw, 0, L / 2), (0.045, 0.075, L), "oak", bevel=0.008)
    n = 11
    for k in range(n):
        z = 0.3 + k * (L - 0.45) / (n - 1)
        # treads stay level when the ladder leans: counter-rotated about their own axis
        level = Matrix.Translation((0, -0.01, z)) @ Matrix.Rotation(tilt, 4, 'X')
        tread = p.box((0, 0, 0), (2 * hw - 0.04, 0.13, 0.028), "oak", bevel=0.006)
        nose = p.box((0, -0.066, 0.012), (2 * hw - 0.06, 0.006, 0.006), "brass")
        p.move(tread + nose, level)
        parts += tread + nose
    for sx in (-1, 1):
        # wheels at the foot
        w = p.lathe([(0.0, -0.012), (0.04, -0.012), (0.045, 0.0), (0.04, 0.012), (0.0, 0.012)], "brass",
                    segments=10)
        p.move(w, Matrix.Translation((sx * (hw + 0.035), 0, 0.045)) @ Matrix.Rotation(math.radians(90), 4, 'Y'))
        parts += w
        parts += p.box((sx * (hw + 0.015), 0, 0.06), (0.012, 0.05, 0.08), "brass", bevel=0.003)
        # hooks over the rail
        hook = [(sx * hw, 0.0, L - 0.04), (sx * hw, 0.03, L + 0.02), (sx * hw, 0.075, L + 0.035),
                (sx * hw, 0.11, L + 0.0), (sx * hw, 0.1, L - 0.04)]
        parts += p.tube(hook, 0.012, "brass", sides=6)
    p.move(parts, Matrix.Translation((0, foot_y, 0)) @ Matrix.Rotation(-tilt, 4, 'X'))
    return p


def bust_bracket():
    """Built facing -Y, wall at y = 0, the top of the shelf at z = 0."""
    p = Part("lib_bust_bracket")
    p.box((0, -0.24, -0.03), (0.56, 0.48, 0.06), "mahogany", bevel=0.015)
    p.box((0, -0.25, -0.075), (0.5, 0.44, 0.03), "mahogany", bevel=0.01)
    p.box((0, -0.255, -0.095), (0.5, 0.45, 0.012), "gilt", bevel=0.004)
    # the console's scroll body: stacked tapering blocks + a carved front
    for k, (d, z, h) in enumerate(((0.38, -0.16, 0.1), (0.3, -0.27, 0.12), (0.2, -0.38, 0.1), (0.12, -0.46, 0.08))):
        p.box((0, -d / 2, z), (0.3 - k * 0.04, d, h), "mahogany", bevel=0.012)
    leaf = p.box((0, -0.0, 0.0), (0.16, 0.05, 0.36), "acanthus", bevel=0.015)
    p.move(leaf, Matrix.Translation((0, -0.3, -0.27)) @ Matrix.Rotation(math.radians(-38), 4, 'X'))
    p.lathe([(0.0, -0.6), (0.03, -0.58), (0.045, -0.54), (0.03, -0.5), (0.02, -0.5)], "gilt", segments=8,
            center=(0, -0.06, 0.0))
    p.box((0, -0.012, -0.3), (0.34, 0.024, 0.62), "mahogany", bevel=0.01)
    return p


def _acanthus(ctx):
    s = M.gold(ctx, seed=631)
    v = ctx.uvm[:, 1]
    u = ctx.uvm[:, 0]
    rib = np.abs(np.sin(v * 70.0 + np.abs(u) * 30.0))
    s.shade += rib * 1.2 - 0.5
    return s


def _panel(ctx):
    s = E.mahogany(ctx, seed=637, center=3.2)
    return s


def build():
    only = os.environ.get("ENL_ONLY", "").split(",")

    def want(n):
        return only == [""] or n in only

    fns = {"mahogany": E.mahogany, "key": E.key_frieze, "gilt": E.gilt, "iron": E.iron_black, "brass": E.worn_brass,
           "panel": _panel, "oak": E.oak_dark, "acanthus": _acanthus}
    out = []
    for W, tag in ((4.0, "4m"), (2.0, "2m"), (1.0, "1m")):
        if want(f"lib_walkway_fascia_{tag}"):
            out.append(kit(f"lib_walkway_fascia_{tag}", [fascia(W)], fns, ppm=96, ground=None, wall=True,
                           ao_dist=0.25, preview=tag == "2m", preview_elevation=-10.0))
    if want("lib_walkway_fascia_end"):
        out.append(kit("lib_walkway_fascia_end", [fascia(0.25, caps=True)], fns, ppm=96, ground=None, wall=True,
                       preview=False))
    for W, tag in ((2.0, "2m"), (1.0, "1m")):
        if want(f"lib_railing_{tag}"):
            out.append(kit(f"lib_railing_{tag}", [railing(W)], fns, ppm=128, ao_dist=0.15, preview=tag == "2m",
                           preview_yaws=(-20.0, 20.0, 160.0, 200.0), preview_elevation=10.0))
    if want("lib_railing_post"):
        out.append(kit("lib_railing_post", [post()], fns, ppm=160, ao_dist=0.12, preview=False))
    if want("lib_walkway_bracket"):
        out.append(kit("lib_walkway_bracket", [bracket()], fns, ppm=128, ground=None, wall=True, ao_dist=0.12,
                       planes=(("z", 0.0),), preview_yaws=(-60.0, -90.0, 60.0, 30.0)))
    if want("lib_ladder_rail_2m"):
        out.append(kit("lib_ladder_rail_2m", [ladder_rail()], fns, ppm=160, ground=None, ao_dist=0.08,
                       preview=False))
    if want("lib_ladder"):
        out.append(kit("lib_ladder", [ladder()], fns, ppm=128, ground=0.0, ao_dist=0.15,
                       preview_yaws=(-50.0, 0.0, 50.0, 100.0)))
    if want("lib_bust_bracket"):
        out.append(kit("lib_bust_bracket", [bust_bracket()], fns, ppm=160, ground=None, wall=True, ao_dist=0.12,
                       markers=[("bust_spot", (0.0, -0.24, 0.0), None)]))
    return out
