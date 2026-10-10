"""Lobby kit, main hall: the orders.

  hall_column          the four grand columns (kit id "column" in the hall,
                       1.6 x 14 x 1.6): square verde plinth, white marble
                       torus base, fluted rosso shaft with entasis, angular
                       Ionic capital (four diagonal volutes, egg-and-dart
                       echinus, concave abacus) touching the 14 m ceiling.
                       Origin = centre of the base. Variant texture set
                       hall_column_grey (bardiglio shaft).
  hall_pilaster_base   wall pilaster of the balcony storey, 0.9 m wide,
  hall_pilaster_shaft  stacked from three pieces (origin on the wall plane
  hall_pilaster_capital at the bottom centre of each): base 0.45 m, fluted
                       shaft 1 m (scale Y to fill), Ionic capital 0.6 m.
"""
import math

from mathutils import Matrix

from artlib import arch_materials as A
from artlib import materials as M
from artlib.archkit import kit
from artlib.geo import Part

FLUTES = 24


def _volute(p, center, axis_yaw, r0=0.2, turns=2.2, tube=0.045, mat="marble_white", pts=26):
    """A scroll: a tube along a shrinking spiral in a vertical plane, turned
    to face ``axis_yaw`` (degrees) about Z, spiral centre at ``center``."""
    path = []
    for i in range(pts + 1):
        t = i / pts
        a = -math.pi / 2 + t * turns * math.tau
        r = r0 * (1.0 - 0.72 * t)
        path.append((r * math.cos(a), 0.0, r * math.sin(a)))
    faces = p.tube(path, lambda t: tube * (1.0 - 0.45 * t), mat, sides=6)
    disc = p.lathe([(0.0, -0.02), (r0 * 0.9, -0.02), (r0 * 0.9, 0.02), (0.0, 0.02)], mat, segments=12)
    p.move(disc, Matrix.Rotation(math.radians(90), 4, 'X'))
    faces = faces + disc
    p.move(faces, Matrix.Translation(center) @ Matrix.Rotation(math.radians(axis_yaw), 4, 'Z'))
    return faces


def column():
    p = Part("hall_column")
    H = 14.0
    # plinth: verde block with a marble cap
    p.box((0, 0, 0.2), (2.0, 2.0, 0.4), "marble_dark", bevel=0.02)
    p.box((0, 0, 0.44), (1.92, 1.92, 0.08), "marble_white", bevel=0.015)
    # Attic base: torus, scotia, torus
    p.lathe([(0.9, 0.48), (0.93, 0.52), (0.93, 0.62), (0.88, 0.68), (0.8, 0.7), (0.78, 0.74), (0.74, 0.8),
             (0.76, 0.84), (0.78, 0.88), (0.76, 0.93), (0.72, 0.96), (0.7, 1.0)], "marble_white", segments=32,
            cap_bottom=False, cap_top=False)
    # fluted shaft with entasis
    z0, z1 = 1.0, 12.55
    rings = 12
    prof = []
    for k in range(rings):
        t = k / (rings - 1)
        r = 0.7 - 0.1 * t * t + 0.015 * math.sin(t * math.pi)
        prof.append((r, z0 + (z1 - z0) * t))
    last = len(prof) - 1

    def flute(i, j):
        if j == 0 or j == last:
            return 1.0
        return 1.0 if i % 2 == 0 else 0.955

    p.lathe(prof, "shaft", segments=FLUTES * 2, cap_bottom=False, cap_top=False, smooth=False,
            ring_scale=flute)
    # capital: astragal, necking, egg-and-dart echinus
    p.lathe([(0.6, 12.55), (0.64, 12.58), (0.64, 12.65), (0.6, 12.68), (0.6, 12.8), (0.66, 12.84),
             (0.72, 12.92), (0.8, 13.02), (0.86, 13.14), (0.86, 13.2), (0.8, 13.24)], "marble_white", segments=32,
            cap_bottom=False, cap_top=True)
    for k in range(16):
        a = math.tau * (k + 0.5) / 16
        egg = p.lathe([(0.0, -0.07), (0.04, -0.06), (0.055, 0.0), (0.04, 0.05), (0.0, 0.06)], "marble_white",
                      segments=8)
        p.move(egg, Matrix.Translation((0.84 * math.cos(a), 0.84 * math.sin(a), 13.07))
               @ Matrix.Rotation(a, 4, 'Z') @ Matrix.Rotation(math.radians(90), 4, 'Y'))
    # cushion under the abacus, diagonal volutes
    p.box((0, 0, 13.36), (1.5, 1.5, 0.24), "marble_white", bevel=0.05)
    for k in range(4):
        yaw = 45.0 + 90.0 * k
        a = math.radians(yaw)
        c = (0.86 * math.cos(a), 0.86 * math.sin(a), 13.3)
        _volute(p, c, yaw + 90.0, r0=0.24, tube=0.05)
    # abacus with concave sides: a square slab plus four corner horns
    p.box((0, 0, 13.55), (1.62, 1.62, 0.1), "marble_white", bevel=0.02)
    p.box((0, 0, 13.75), (1.72, 1.72, 0.3), "marble_white", bevel=0.03)
    p.box((0, 0, 13.95), (1.78, 1.78, 0.1), "marble_white", bevel=0.02)
    return p


def pilaster_base():
    p = Part("hall_pilaster_base")
    p.box((0, -0.11, 0.1), (1.1, 0.22, 0.2), "marble_dark", bevel=0.015)
    p.extrude([(-0.2, 0.2), (-0.21, 0.24), (-0.21, 0.28), (-0.19, 0.31), (-0.17, 0.32), (-0.17, 0.36),
               (-0.19, 0.39), (-0.18, 0.42), (-0.16, 0.45), (0.0, 0.45)], -0.52, 0.52, "limestone", caps=True)
    return p


def pilaster_shaft():
    p = Part("hall_pilaster_shaft")
    W, D = 0.9, 0.16
    # recessed face = five flute channels; fillets and margins stand proud
    inner = D - 0.025
    p.box((0, -inner / 2, 0.5), (W - 0.02, inner, 1.0), "flute")
    margin = 0.08
    p.box((-W / 2 + margin / 2, -D / 2, 0.5), (margin, D, 1.0), "limestone", bevel=0.008)
    p.box((W / 2 - margin / 2, -D / 2, 0.5), (margin, D, 1.0), "limestone", bevel=0.008)
    step = (W - 2 * margin) / 5
    for k in range(1, 5):
        cx = -W / 2 + margin + step * k
        p.box((cx, -D / 2, 0.5), (0.03, D, 1.0), "limestone", bevel=0.006)
    return p


def pilaster_capital():
    p = Part("hall_pilaster_capital")
    p.extrude([(-0.16, 0.0), (-0.19, 0.03), (-0.19, 0.07), (-0.17, 0.09), (-0.17, 0.14), (-0.2, 0.18),
               (-0.26, 0.26), (-0.28, 0.3), (-0.2, 0.34), (0.0, 0.34)], -0.5, 0.5, "limestone", caps=True)
    for sx in (-1, 1):
        _volute(p, (sx * 0.4, -0.3, 0.3), 0.0, r0=0.13, tube=0.03, mat="limestone")
    p.box((0, -0.18, 0.43), (1.12, 0.36, 0.18), "limestone", bevel=0.02)
    p.box((0, -0.2, 0.55), (1.2, 0.4, 0.07), "limestone", bevel=0.015)
    return p


def _flute(ctx):
    s = A.limestone(ctx)
    s.shade -= 1.2
    return s


def build():
    col = kit("hall_column", [column()], {"marble_dark": M.marble_dark, "marble_white": M.marble_white,
                                           "shaft": M.marble_red}, ppm=64, ao_dist=0.5,
              variants={"hall_column_grey": {"marble_dark": M.marble_dark, "marble_white": M.marble_white,
                                              "shaft": lambda ctx: M._marble_core(ctx, A.P["marble_grey"],
                                                                                  A.P["marble_grey_vein"], 3.8,
                                                                                  True, 29, polish=0.1,
                                                                                  vein_scale=1.8)}})
    fns = {"limestone": A.limestone, "marble_dark": M.marble_dark, "flute": _flute}
    return [col,
            kit("hall_pilaster_base", [pilaster_base()], fns, wall=True),
            kit("hall_pilaster_shaft", [pilaster_shaft()], fns, wall=True, ground=None, preview=False),
            kit("hall_pilaster_capital", [pilaster_capital()], fns, wall=True, ground=None)]
