"""The guard's gloved hands for the first-person viewmodels: one clenched
fist sculpted from metaball clay (fingers curled round a grip axis, thumb
over them), placed onto a grip, plus the uniform sleeve with its cuff.

Hand frame (right hand; the left one is mirrored in x):
  local Z  = the axis the fingers curl round (a pistol grip, a stock wrist,
             a fore-end; for a punch: vertical, thumb on top)
  local +Y = where the knuckles point
  local +X = the back of the hand (sx * X for the left hand)
The grip axis passes through local (GRIP_X * sx, 0, z).

Cant (the diagonal grip): a real hand does not hold a stick square across
the palm but diagonally, from the heel of the hand to the base of the index
finger, so the stick meets the forearm at 90 + cant degrees (hammer, fore-
end, pistol grip: 30-45 degrees). ``cant`` moves the wrist blob and the
sleeve root to that line, toward the little-finger side; the fist on the
weapon is unchanged. The neutral forearm in hand coordinates then runs
along (0, -cos cant, -sin cant); a sleeve within ~25 degrees of it reads
as a straight wrist (a sleeve square to the grip axis reads as broken).

Arm markers for the game (ViewmodelRig aims the sleeve, which is its own
part pivoted at the wrist, at an elbow every frame): see arm()."""
import math

import numpy as np
from mathutils import Matrix, Vector

from . import kit, sculpt
from .geo import Part
from .sculpt import blob, limb

GRIP_X = -0.006
PALM_C = Vector((0.012, -0.036, 0.0))       # x times sx
WRIST_C = Vector((0.004, -0.083, 0.0))      # the wrist blob, x times sx
SLEEVE_ROOT = Vector((0.004, -0.09, 0.0))   # where the sleeve starts, x times sx
## Along the canted neutral forearm: where the elbow marker sits (m).
FOREARM = 0.30


def _cant(sx, cant, p):
    """Point p of the uncanted hand (x already mirrored) moved with the
    wrist to the diagonal-grip line: turned about the palm centre, about X,
    toward the little-finger side."""
    palm = Vector((PALM_C.x * sx, PALM_C.y, PALM_C.z))
    return palm + Matrix.Rotation(cant, 3, 'X') @ (Vector(p) - palm)


def sleeve_root(sx=1, cant=0.0):
    """The sleeve root (the wrist) in hand coordinates."""
    return _cant(sx, cant, Vector((SLEEVE_ROOT.x * sx, SLEEVE_ROOT.y, SLEEVE_ROOT.z)))


def neutral_forearm(cant=0.0):
    """Unit direction of the straight-wrist forearm in hand coordinates."""
    return Vector((0.0, -math.cos(cant), -math.sin(cant)))


def fist_blobs(sx=1, cant=0.0):
    wrist = _cant(sx, cant, Vector((WRIST_C.x * sx, WRIST_C.y, WRIST_C.z)))
    b = [
        blob((sx * 0.012, -0.036, 0.0), (0.023, 0.046, 0.043)),        # palm
        blob(tuple(wrist), (0.026, 0.028, 0.034), rot=(math.degrees(cant), 0.0, 0.0)),   # wrist
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


def fist_mesh(sx=1, tris=900, cant=0.0):
    me = sculpt.metaball_mesh(fist_blobs(sx, cant), resolution=0.0022)
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


def add_hand(part, matrix, sx=1, tris=900, slot="glove", cant=0.0):
    sculpt.into_part(part, fist_mesh(sx, tris, cant), slot, transform=matrix)
    return matrix @ sleeve_root(sx, cant)                      # the wrist, for the sleeve


def wrist_angles(matrix, sx, cant, sleeve_dir):
    """(flexion, radial deviation) in degrees of a sleeve running up
    ``sleeve_dir`` (world) from the hand placed by ``matrix``: flexion
    positive toward the back of the hand, deviation positive toward the
    thumb. The game's test measures the same thing off the markers."""
    r = matrix.to_3x3()
    d = (r.inverted() @ Vector(sleeve_dir)).normalized()
    n = neutral_forearm(cant)
    t = Vector((0.0, n.z, -n.y))                    # radial (toward the thumb), in the hand's YZ plane
    along = d.dot(n)
    return (math.degrees(math.atan2(sx * d.x, along)), math.degrees(math.atan2(d.dot(t), along)))


def arm_markers(side, matrix, sx, cant, sleeve_dir, hand_part, parent=None, fore=FOREARM):
    """The markers ViewmodelRig reads (Blender model space; the exporter
    turns Blender (x, y, z) into Godot (x, z, -y), and a basis column-wise
    into (x, z, -y) too, so a Blender basis (a, b, c) reaches Godot as
    (a, c, -b)):
      Wrist_<side>  child of the hand part, at the sleeve root; Godot basis
                    X = back of the hand, Y = distal (the straight-wrist
                    forearm runs along -Y), Z = X x Y (the thumb side is
                    sx * Z);
      Grip_<side>   child of the hand part, at the fist's grip point; Godot
                    basis = the hand frame (X = sx * back, Y = knuckles,
                    Z = the grip axis, thumb at +Z);
      Elbow_<side>  child of ``parent``: the rest elbow, ``fore`` up the sleeve.
    ``sleeve_dir`` is where the sleeve goes (the forearm); keep it within
    ~25 degrees of the neutral (wrist_angles())."""
    r = matrix.to_3x3()
    wrist = matrix @ sleeve_root(sx, cant)
    back = (r @ Vector((sx, 0.0, 0.0))).normalized()
    distal = (r @ (-neutral_forearm(cant))).normalized()
    wrist_basis = Matrix((back, distal.cross(back), distal)).transposed()
    grip = matrix @ Vector((GRIP_X * sx, 0.0, 0.0))
    grip_basis = Matrix((r.col[0], -r.col[2], r.col[1])).transposed()
    elbow = wrist + Vector(sleeve_dir).normalized() * fore
    return [(f"Wrist_{side}", tuple(wrist), hand_part, wrist_basis),
            (f"Grip_{side}", tuple(grip), hand_part, grip_basis),
            (f"Elbow_{side}", tuple(elbow), parent)]


def arm(side, hand, matrix, sx, cant, sleeve_dir, length, watch=False, tris=1000, parent=None, fore=FOREARM):
    """One whole arm: the canted fist into Part ``hand`` (placed by
    ``matrix``), the sleeve into a new Part sleeve_<side> pivoted at the
    wrist (the game turns it toward the elbow), and the rig's markers.
    Returns (sleeve part, markers). Prints the wrist angles so a pose that
    reads as broken shows up in the build log."""
    wrist = add_hand(hand, matrix, sx=sx, tris=tris, cant=cant)
    sleeve = Part(f"sleeve_{side}", origin=tuple(wrist), parent=parent)
    add_sleeve(sleeve, wrist, sleeve_dir, length=length, watch=watch, sx=sx)
    flex, dev = wrist_angles(matrix, sx, cant, sleeve_dir)
    print(f"  wrist {hand.name}: flexion {flex:+.0f} deg, deviation {dev:+.0f} deg (cant {math.degrees(cant):.0f})")
    return sleeve, arm_markers(side, matrix, sx, cant, sleeve_dir, hand.name, parent, fore)


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
