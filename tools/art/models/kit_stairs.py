"""Lobby kit, main hall: the grand stairs (0.15 m risers, 0.40 m treads:
40 steps from the hall floor to the balcony at 6 m, see LobbyLayout).

All pieces share the stairs frame of StairsSpec.frame(): origin in the
middle of the bottom front edge of the flight, -Z (Godot) = up the flight,
X across. They are modelled directly in that frame (Blender +Y = up the
flight), not turned.

  stair_step_4m / _1m  one marble step: riser, bullnose nosing, tread.
                       Origin = bottom of the riser, centre; step i goes at
                       (0, i * rise, -i * tread). Other rises / treads:
                       scale Y and Z (the nosing stays).
  stair_wedge          unit wedge 1 x 1 x 1 under the steps (tile material
                       "tile:limestone": no atlas). Scale to (width, total
                       rise, run): its slope then runs through the inner
                       corners of the steps, so it never shows above them.
  stair_stringer_4m    moulded stringer along an open side, 4 m of run and
                       1.5 m of rise (10 steps). Symmetric: centre it
                       0.07 m outside the flight's side plane, one module
                       per 10 steps at (x, 1.5 k, -4 k).
  stair_balustrade_4m  raked balustrade on the stringer: a baluster per
                       tread, sloped base rail and handrail. Same frame and
                       placement as the stringer.
  stair_newel          the newel at the foot of an open side: stone pier
                       with a brass lamp standard and an opal globe (marker
                       "Light" = where a warm omni light goes).
"""
import math

from mathutils import Matrix

from artlib import arch_materials as A
from artlib import materials as M
from artlib.archkit import kit, orient_out
from artlib.geo import Part

RISE, TREAD = 0.15, 0.40
SLOPE = RISE / TREAD
TOP = 0.27      # stringer top above the pitch line's foot (the pitch line: z = SLOPE * y + RISE)
BOTTOM = -0.2


def step(W):
    p = Part("stair_step")
    prof = [(0.0, 0.0), (0.0, 0.118), (-0.012, 0.122), (-0.028, 0.13), (-0.035, 0.14), (-0.03, 0.147),
            (-0.018, 0.15), (TREAD, 0.15)]
    p.extrude(prof, -W / 2, W / 2, "marble", caps=True)
    return p


def wedge():
    p = Part("stair_wedge")
    a, b = -0.5, 0.5
    pts = {  # x, y (up the flight), z
        "f0": (a, 0.0, 0.0), "f1": (b, 0.0, 0.0),
        "b0": (a, 1.0, 0.0), "b1": (b, 1.0, 0.0),
        "t0": (a, 1.0, 1.0), "t1": (b, 1.0, 1.0),
    }
    faces = [
        (["f0", "f1", "t1", "t0"], (0, -0.7, 0.7)),     # slope
        (["b0", "t0", "t1", "b1"], (0, 1, 0)),          # back
        (["f0", "t0", "b0"], (-1, 0, 0)),               # sides (the spandrels)
        (["f1", "b1", "t1"], (1, 0, 0)),
    ]
    for keys, want in faces:
        f = p.poly([pts[k] for k in keys], "field")[0]
        f.normal_update()
        if f.normal.dot(want) < 0:
            f.normal_flip()
    return p


def _sheared(faces, p):
    """Raises every vertex of ``faces`` by SLOPE * y (makes a flat run raked)."""
    for v in {v for f in faces for v in f.verts}:
        v.co.z += SLOPE * v.co.y


def stringer(L=4.0):
    p = Part("stair_stringer")
    prof = [(-0.07, BOTTOM), (-0.07, TOP - 0.1), (-0.09, TOP - 0.08), (-0.09, TOP - 0.04), (-0.06, TOP),
            (0.06, TOP), (0.09, TOP - 0.04), (0.09, TOP - 0.08), (0.07, TOP - 0.1), (0.07, BOTTOM),
            (-0.07, BOTTOM)]
    faces = p.extrude(prof, 0.0, L, "limestone", caps=False)
    orient_out(faces, (L / 2, 0.0, (TOP + BOTTOM) / 2))
    # extrusion ran along +X with the profile across Y: turn it to run up +Y
    p.move(faces, Matrix.Rotation(math.radians(90), 4, 'Z'))
    _sheared(faces, p)
    # a sunk panel line on both faces (painted in the atlas: see _stringer)
    return p


def balustrade(L=4.0):
    p = Part("stair_balustrade")
    rail0 = TOP
    base = p.box((0.0, L / 2, rail0 + 0.04), (0.18, L, 0.08), "limestone", bevel=0.015)
    _sheared(base, p)
    hand_z = rail0 + 0.86
    hand = p.box((0.0, L / 2, hand_z), (0.2, L, 0.1), "limestone", bevel=0.03)
    _sheared(hand, p)
    sub = p.box((0.0, L / 2, hand_z - 0.07), (0.15, L, 0.04), "limestone", bevel=0.01)
    _sheared(sub, p)
    n = int(round(L / TREAD))
    prof = [(0.0, 0.0), (0.05, 0.0), (0.05, 0.03), (0.038, 0.05), (0.042, 0.09), (0.058, 0.2), (0.06, 0.28),
            (0.05, 0.38), (0.035, 0.48), (0.03, 0.55), (0.036, 0.59), (0.046, 0.62), (0.046, 0.66),
            (0.05, 0.68), (0.05, 0.72), (0.0, 0.72)]
    for k in range(n):
        y = (k + 0.5) * TREAD
        z0 = rail0 + 0.08 + SLOPE * y - 0.03
        p.lathe(prof, "limestone", segments=8, center=(0.0, y, z0), cap_bottom=False)
    return p


def newel():
    p = Part("stair_newel")
    p.box((0, 0, 0.1), (0.86, 0.86, 0.2), "marble_dark", bevel=0.015)
    p.box((0, 0, 0.3), (0.78, 0.78, 0.2), "limestone", bevel=0.02)
    p.box((0, 0, 0.8), (0.68, 0.68, 0.8), "limestone", bevel=0.02)
    for sx, sy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        w = (0.03 if sx else 0.48, 0.03 if sy else 0.48, 0.6)
        p.box((sx * 0.34, sy * 0.34, 0.8), w, "panel", bevel=0.008)
    p.box((0, 0, 1.25), (0.8, 0.8, 0.1), "limestone", bevel=0.03)
    p.box((0, 0, 1.33), (0.7, 0.7, 0.06), "limestone", bevel=0.015)
    # lamp standard: fluted brass post, collar, opal globe
    p.lathe([(0.0, 1.36), (0.16, 1.36), (0.16, 1.4), (0.1, 1.46), (0.06, 1.52), (0.05, 1.6), (0.045, 2.2),
             (0.06, 2.24), (0.06, 2.28), (0.09, 2.32), (0.1, 2.36), (0.07, 2.38)], "brass", segments=12,
            cap_bottom=False)
    p.lathe([(0.06, 2.37), (0.13, 2.4), (0.18, 2.48), (0.19, 2.56), (0.17, 2.66), (0.11, 2.73), (0.04, 2.76),
             (0.0, 2.765)], "lamp_warm", segments=16, cap_bottom=False)
    return p


def _panel(ctx):
    s = A.limestone(ctx)
    s.shade -= 0.7
    return s


def build():
    fns = {"limestone": A.limestone, "marble_dark": M.marble_dark, "panel": _panel, "brass": M.brass,
           "lamp_warm": M.lamp_warm}
    return [
        kit("stair_step_4m", [step(4.0)], {"marble": M.marble_white}, built_final=True, ao_dist=0.25),
        kit("stair_step_1m", [step(1.0)], {"marble": M.marble_white}, built_final=True, ao_dist=0.25, preview=False),
        kit("stair_wedge", [wedge()], {}, kinds={"field": "tile:limestone"}, built_final=True, preview=False),
        kit("stair_stringer_4m", [stringer()], {"limestone": A.limestone}, built_final=True, ground=None),
        kit("stair_balustrade_4m", [balustrade()], {"limestone": A.limestone}, built_final=True, ground=None,
            ao_dist=0.3),
        kit("stair_newel", [newel()], fns, built_final=True, ppm=128, ao_dist=0.3,
            markers=[("Light", (0.0, 0.0, 2.56), None)]),
    ]
