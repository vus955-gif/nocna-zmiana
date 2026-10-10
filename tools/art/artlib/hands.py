"""The guard's gloved hands for the first-person viewmodels: one clenched
fist sculpted from metaball clay (fingers curled round a grip axis, thumb
over them), placed onto a grip, plus the uniform sleeve with its cuff.

Hand frame (right hand; the left one is mirrored in x):
  local Z  = the axis the fingers curl round (a pistol grip, a stock wrist,
             a fore-end; for a punch: vertical, thumb on top)
  local +Y = where the knuckles point
  local +X = the back of the hand (sx * X for the left hand)
The grip axis passes through local (GRIP_X * sx, 0, z)."""
import math

import numpy as np
from mathutils import Matrix, Vector

from . import kit, sculpt
from .sculpt import blob, limb

GRIP_X = -0.006


def fist_blobs(sx=1):
    b = [
        blob((sx * 0.012, -0.036, 0.0), (0.023, 0.046, 0.043)),        # palm
        blob((sx * 0.004, -0.083, 0.0), (0.026, 0.028, 0.034)),        # wrist
        blob((sx * -0.004, -0.03, -0.03), (0.02, 0.03, 0.02)),         # heel of the hand
    ]
    for k, z in enumerate((0.03, 0.01, -0.01, -0.029)):
        r = 0.0098 if k < 3 else 0.0085
        long = 1.0 if k in (1, 2) else 0.93
        pts = [(sx * 0.012, 0.004, z), (sx * 0.004, 0.028 * long, z), (sx * -0.026, 0.024 * long, z),
               (sx * -0.036, 0.002, z * 0.95)]
        b += limb(pts, [r * 1.05, r, r * 0.95, r * 0.9], spacing=0.9)
        b.append(blob((sx * 0.017, 0.01, z), r * 1.05))                  # knuckle
    # thumb: along the side of the curled fingers, tip over the middle finger
    b += limb([(sx * -0.004, -0.045, 0.034), (sx * -0.018, -0.012, 0.04), (sx * -0.03, 0.012, 0.036),
               (sx * -0.034, 0.03, 0.022)], [0.014, 0.012, 0.011, 0.0105], spacing=0.9)
    return b


def fist_mesh(sx=1, tris=900):
    me = sculpt.metaball_mesh(fist_blobs(sx), resolution=0.0022)
    return sculpt.decimate(me, tris)


def hand_matrix(grip_center, grip_axis, back_dir, sx=1):
    """World matrix of the hand frame: grip axis through ``grip_center``,
    back of the hand toward ``back_dir``."""
    z = Vector(grip_axis).normalized()
    b = Vector(back_dir)
    x = (b - z * b.dot(z)).normalized() * sx
    y = z.cross(x)
    m = Matrix(((x.x, y.x, z.x, 0), (x.y, y.y, z.y, 0), (x.z, y.z, z.z, 0), (0, 0, 0, 1)))
    return Matrix.Translation(Vector(grip_center)) @ m @ Matrix.Translation((-GRIP_X * sx, 0, 0))


def add_hand(part, matrix, sx=1, tris=900, slot="glove"):
    sculpt.into_part(part, fist_mesh(sx, tris), slot, transform=matrix)
    return matrix @ Vector((sx * 0.004, -0.09, 0.0))          # the wrist, for the sleeve


def add_sleeve(part, wrist, direction, length=0.34, watch=False, sx=1):
    """Glove cuff, uniform sleeve with a buttoned cuff; optional wristwatch
    (left arm). ``direction`` points from the wrist up the forearm."""
    d = Vector(direction).normalized()
    a = Vector(wrist) - d * 0.012
    kit.seg(part, a, a + d * 0.035, [(0.033, 0.0), (0.036, 0.6), (0.034, 1.0)], "glove", segments=10,
            caps=False)                                                    # glove gauntlet cuff
    s0 = a + d * 0.03
    folds = lambda i, j: 1.0 + (0.045 * math.sin(i * 2.1 + j * 1.7) if j >= 4 else 0.0)
    kit.seg(part, s0, s0 + d * length, [(0.038, 0.0), (0.041, 0.08), (0.042, 0.14), (0.04, 0.16),
                                        (0.044, 0.3), (0.047, 0.42), (0.045, 0.52), (0.049, 0.66),
                                        (0.05, 0.82), (0.052, 1.0)], "sleeve", segments=12, ring_scale=folds)
    # cuff button on the outer side
    side = d.cross(Vector((0, 0, 1)))
    if side.length < 0.1:
        side = d.cross(Vector((1, 0, 0)))
    side = side.normalized() * sx
    btn = kit.sphere(part, (0, 0, 0), 0.006, "button", segments=6, rings=3, zscale=0.5)
    part.move(btn, kit.align(s0 + d * 0.07 + side * 0.041, s0 + d * 0.07 + side * 0.06))
    if watch:
        up = d.cross(side).normalized()
        c = a + d * 0.02 + up * 0.035
        kit.seg(part, a + d * 0.005, a + d * 0.035, [(0.037, 0.0), (0.037, 1.0)], "watch_band", segments=10,
                caps=False)
        case = part.lathe([(0.0, -0.004), (0.015, -0.004), (0.016, 0.0), (0.014, 0.004), (0.0, 0.004)], "watch",
                          segments=10, smooth=False)
        part.move(case, kit.align(c, c + up))
    return s0 + d * length
