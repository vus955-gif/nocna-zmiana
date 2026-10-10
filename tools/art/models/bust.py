"""Roman portrait bust on a turned socle, sculpted from metaball 'clay',
cut flat at the chest and arms, decimated to ~7k triangles (a hero prop).
Faces -Y. Origin at the bottom of the socle (stand it on a pedestal top).
Texture sets: "bust" (white marble, solid 3D veins) and "bust_bronze"
(green patina with polished high points)."""
import random

from artlib import materials as M
from artlib import sculpt
from artlib.geo import Part
from artlib.model import Model
from artlib.sculpt import blob

SOCLE = 0.13     # the bust sits on the socle at this height


def _head_blobs(rng):
    z = SOCLE - 0.02
    b = [
        # skull, face mass, jaw, chin
        blob((0, 0.012, z + 0.385), (0.112, 0.114, 0.112)),
        blob((0, -0.03, z + 0.345), (0.09, 0.076, 0.09)),
        blob((0, -0.038, z + 0.295), (0.076, 0.06, 0.048)),
        blob((0, -0.074, z + 0.28), (0.031, 0.022, 0.024), kind="BALL"),
        # brow ridge, nose, cheeks, lips
        blob((0, -0.088, z + 0.39), (0.074, 0.02, 0.015)),
        blob((0, -0.102, z + 0.352), (0.015, 0.02, 0.027), rot=(-12, 0, 0)),
        blob((0, -0.11, z + 0.338), (0.012, 0.011, 0.01), kind="BALL"),
        blob((0.056, -0.07, z + 0.345), (0.034, 0.03, 0.032)),
        blob((-0.056, -0.07, z + 0.345), (0.034, 0.03, 0.032)),
        blob((0, -0.09, z + 0.31), (0.028, 0.014, 0.009)),
        # eye sockets, carved eyeballs with lids, the line of the mouth,
        # nasolabial folds (negative clay cuts, positive clay details)
        blob((0.035, -0.105, z + 0.372), (0.019, 0.015, 0.012), neg=True, stiff=1.4),
        blob((-0.035, -0.105, z + 0.372), (0.019, 0.015, 0.012), neg=True, stiff=1.4),
        blob((0.034, -0.088, z + 0.37), 0.0125, kind="BALL", stiff=2.4),
        blob((-0.034, -0.088, z + 0.37), 0.0125, kind="BALL", stiff=2.4),
        blob((0.034, -0.094, z + 0.381), (0.016, 0.008, 0.004), stiff=1.6),
        blob((-0.034, -0.094, z + 0.381), (0.016, 0.008, 0.004), stiff=1.6),
        blob((0, -0.102, z + 0.304), (0.024, 0.008, 0.0035), neg=True, stiff=1.2),
        # nostrils' wings and the bridge of the nose
        blob((0.012, -0.105, z + 0.338), 0.009, kind="BALL", stiff=1.8),
        blob((-0.012, -0.105, z + 0.338), 0.009, kind="BALL", stiff=1.8),
        blob((0, -0.1, z + 0.372), (0.009, 0.012, 0.02), stiff=1.8),
        # ears, flat against the head
        blob((0.104, 0.006, z + 0.355), (0.01, 0.022, 0.03)),
        blob((-0.104, 0.006, z + 0.355), (0.01, 0.022, 0.03)),
        # neck, chest, shoulders, pectorals
        blob((0, 0.005, z + 0.235), (0.068, 0.068, 0.07)),
        blob((0, 0.01, z + 0.12), (0.15, 0.09, 0.085)),
        blob((0.12, 0.02, z + 0.155), (0.062, 0.064, 0.052)),
        blob((-0.12, 0.02, z + 0.155), (0.062, 0.064, 0.052)),
        blob((0.052, -0.052, z + 0.14), (0.055, 0.03, 0.042)),
        blob((-0.052, -0.052, z + 0.14), (0.055, 0.03, 0.042)),
        # a round cloak clasp on the right shoulder
        blob((-0.1, -0.05, z + 0.17), (0.026, 0.014, 0.026)),
    ]
    # curls embedded in the skull: a cap over the crown and the back, a fringe
    count = 0
    while count < 105:
        x, y, zz = (rng.uniform(-1, 1) for _ in range(3))
        r2 = x * x + y * y + zz * zz
        if not 0.2 < r2 <= 1.0:
            continue
        n = (x / r2 ** 0.5, y / r2 ** 0.5, zz / r2 ** 0.5)
        if n[2] < 0.1 and n[1] < 0.2:
            continue          # keep the face and the jaw clear
        if n[2] < -0.35:
            continue
        c = (n[0] * 0.106, 0.012 + n[1] * 0.107, z + 0.39 + n[2] * 0.104)
        b.append(blob(c, rng.uniform(0.012, 0.017), kind="BALL", stiff=1.7))
        count += 1
    for i in range(9):
        x = -0.07 + i * 0.0175
        b.append(blob((x, -0.08 + abs(x) * 0.25, z + 0.435 - abs(x) * 0.35), 0.014, kind="BALL", stiff=1.7))
    return b


def build():
    rng = random.Random(4)
    me = sculpt.metaball_mesh(_head_blobs(rng), resolution=0.0045)
    sculpt.cut(me, [((0, 0, SOCLE + 0.035), (0, 0, -1)), ((0.18, 0, 0), (1, 0, 0)), ((-0.18, 0, 0), (-1, 0, 0))])
    me = sculpt.decimate(me, 7000)
    p = Part("bust")
    sculpt.into_part(p, me, "marble")
    # turned socle with a square plinth
    p.box((0, 0, 0.018), (0.2, 0.2, 0.036), "marble", bevel=0.006)
    p.lathe([(0.085, 0.036), (0.09, 0.05), (0.07, 0.065), (0.05, 0.08), (0.045, 0.1), (0.06, 0.12),
             (0.08, SOCLE + 0.02), (0.0, SOCLE + 0.035)], "marble", segments=16, cap_bottom=False)
    white = {"marble": M.marble_statuary}
    m = Model("bust", [p], white, ppm=256, organic=("bust",), ground=0.0, ao_dist=0.12, ao_rays=16, ao_stride=1,
              preview_closeup=((0.0, -0.04, 0.46), 0.14))
    m.variants = {"bust_bronze": {"marble": M.bronze}}
    return m
