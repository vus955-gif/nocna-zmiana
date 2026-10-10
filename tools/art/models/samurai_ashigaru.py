"""The armour hall's walking armours ("ashigaru"): an empty foot soldier's
armour of the late sixteenth century - a riveted okegawa-do in black
lacquer with a gilt mitsudomoe crest, a skirt of navy-laced lames, mail
sleeves over indigo cloth with lacquered splints, a lamellar thigh apron,
shin guards and knee plates, tabi in straw sandals, an iron jingasa over a
cloth hood and a chin mask - and nothing inside: a smoky dark with two
ember eyes under the hat. A su-yari (straight spear, 2.4 m) in the right
hand; on the leading left arm an oversized lamellar shoulder guard (sode)
held up as a guard: the knight's shield rule plays as its guard stance.

Faces +Y in Blender = -Z in Godot. Origin on the floor between the feet.
The rig is the knight's (src/enemies/visuals/knight_rig.gd drives it
unchanged): parts, pivots (Blender x, y, z):
    torso        (0, 0, 1.00)        waist                     root
    head         (0, 0, 1.62)        neck (hat, hood, mask, void) child of torso
    arm_l, arm_r (-/+0.30, 0, 1.52)  shoulders                  children of torso
    shield       (-0.36, 0.02, 1.6)  the big sode, hung from the left shoulder
                                     (the guard)               child of arm_l
    weapon       (0.38, 0.27, 1.17)  yari grip, shaft along +Y  child of arm_r
    leg_l, leg_r (-/+0.12, 0, 0.92)  hips                       root
Knock-off plates (KnightRig.shed_plate names):
    plate_pauldron_r  the small right sode            child of arm_r
    plate_tasset_l/_r the side panels of the skirt    children of torso
    plate_poleyn_l/_r the knee plates                 children of leg_l / leg_r
Markers: face (child of head: between the ember eyes, the weak point),
spear_tip (child of weapon, the point of the blade).
"""
import math

import numpy as np
from mathutils import Matrix, Vector

from artlib import kit as K
from artlib import samurai as S
from artlib.geo import Part
from artlib.kit import R, T
from artlib.model import Model

HEAD_C = (0.0, 0.01, 1.78)
EYES = [(-0.034, 0.088, 1.785), (0.034, 0.088, 1.785)]
GRIP_R = Vector((0.38, 0.27, 1.17))
SPEAR_DIR = Vector((0.0, math.cos(math.radians(8)), math.sin(math.radians(8))))
SPEAR_FRONT = 1.6        # grip -> blade base along the shaft
BLADE = 0.24


def torso():
    p = Part("torso", origin=(0, 0, 1.0))
    S.okegawa_do(p)
    # the skirt: front, front-sides and back panels (the two side panels
    # are their own parts, to be knocked off)
    S.kusazuri(p, 7, 0.97, 0.3, 0.23, 5, "lame",
               part_angles=[math.radians(a) for a in (90, 48, 132, 270, 228, 312)])
    return p


def tasset(sx):
    name = "plate_tasset_l" if sx < 0 else "plate_tasset_r"
    a = math.radians(180 if sx < 0 else 0)
    p = Part(name, origin=(sx * 0.24, 0.0, 0.95), parent="torso")
    S.kusazuri(p, 7, 0.97, 0.3, 0.235, 5, "lame", part_angles=[a])
    return p


def head():
    p = Part("head", origin=(0, 0, 1.62), parent="torso")
    S.void_head(p, HEAD_C, 0.105)
    S.jingasa(p, HEAD_C)
    return p


def arm_l():
    p = Part("arm_l", origin=(-0.3, 0, 1.52), parent="torso")
    S.arm(p, -1, (-0.3, 0.0, 1.52), (-0.37, 0.1, 1.27), (-0.2, 0.3, 1.24), (-0.13, 0.34, 1.24), (0, 0, 1))
    return p


def shield():
    """The big sode as the guard: 0.46 x 0.56, hung from the left shoulder and
    swung forward so it covers the left of the chest."""
    p = Part("shield", origin=(-0.36, 0.02, 1.6), parent="arm_l")
    S.sode(p, 0.46, 0.56, 8, "lame", bend_r=0.55)
    p.move(list(p.bm.faces), T(-0.33, 0.14, 1.63) @ R('Z', 68) @ R('X', 6))
    return p


def arm_r():
    p = Part("arm_r", origin=(0.3, 0, 1.52), parent="torso")
    S.arm(p, 1, (0.3, 0.0, 1.52), (0.36, -0.04, 1.26), (0.385, 0.19, 1.18), tuple(GRIP_R), tuple(SPEAR_DIR))
    return p


def pauldron_r():
    p = Part("plate_pauldron_r", origin=(0.36, 0.0, 1.6), parent="arm_r")
    S.sode(p, 0.24, 0.26, 5, "lame", bend_r=0.4)
    p.move(list(p.bm.faces), T(0.38, 0.0, 1.62) @ R('Z', -90) @ R('X', 4))
    return p


def weapon():
    p = Part("weapon", origin=tuple(GRIP_R), parent="arm_r")
    d = SPEAR_DIR
    butt = GRIP_R - d * 0.8
    base = GRIP_R + d * SPEAR_FRONT
    K.seg(p, butt, base, [(0.017, 0.0), (0.017, 0.5), (0.016, 1.0)], "shaft", segments=8)
    K.seg(p, butt - d * 0.06, butt, [(0.02, 0.0), (0.019, 1.0)], "iron", segments=8)                 # butt cap
    K.seg(p, base - d * 0.1, base + d * 0.02, [(0.021, 0.0), (0.022, 0.5), (0.02, 1.0)], "brass", segments=8)  # collar
    blade = p.lathe([(0.022, 0.0), (0.026, 0.04), (0.02, 0.14), (0.009, 0.21), (0.002, BLADE)], "blade",
                    segments=4, squash=(1.0, 0.3), smooth=False, cap_top=True)
    p.move(blade, T(*(base + d * 0.02)) @ d.to_track_quat('Z', 'Y').to_matrix().to_4x4())
    # a red horsehair tuft under the collar
    p.lathe([(0.02, 0.0), (0.05, -0.03), (0.04, -0.09), (0.015, -0.1)], "tuft", segments=8, cap_bottom=False,
            cap_top=True, center=(0.0, 0.0, 0.0))
    tuft = [f for f in p.bm.faces if p.slots[f.material_index] == "tuft"]
    p.move(tuft, T(*(base - d * 0.1)) @ d.to_track_quat('Z', 'Y').to_matrix().to_4x4() @ R('X', 180))
    return p


def leg(sx):
    name = "leg_l" if sx < 0 else "leg_r"
    p = Part(name, origin=(sx * 0.12, 0, 0.92))
    S.hakama_leg(p, sx)
    S.haidate(p, sx, "lame")
    S.suneate(p, sx, z_top=0.5, knee=False)
    S.foot(p, sx)
    return p


def poleyn(sx):
    name = "plate_poleyn_l" if sx < 0 else "plate_poleyn_r"
    p = Part(name, origin=(sx * 0.13, 0.05, 0.52), parent="leg_l" if sx < 0 else "leg_r")
    knee = K.sphere(p, (0, 0, 0), 0.075, "plate", segments=10, rings=6, smooth=False)
    knee = K.keep(p, knee, lambda c: c.z > -0.02)
    knee = K.thicken(p, knee, 0.006)
    p.move(knee, T(sx * 0.13, 0.06, 0.53) @ R('X', -78))
    return p


def build():
    parts = [torso(), head(), arm_l(), arm_r(), shield(), weapon(), leg(-1), leg(1), pauldron_r(), tasset(-1),
             tasset(1), poleyn(-1), poleyn(1)]
    fns = {"lame": S.laced("lacing_blue", 5.2), "plate": S.plate_mon((0.0, 0.25, 1.2), 0.16, rim="none"),
           "gold": S.gold, "brocade": S.brocade("lacing_blue", gold=False), "mail": S.mail, "cloth": S.cloth,
           "straw": S.straw, "void": S.void(EYES, HEAD_C, 0.105),
           "shaft": lambda c: S.A.lacquer(c, 1901, ramp="lacquer_red", center=4.2, wear=0.4),
           "iron": S.M.iron, "brass": lambda c: S.M.brass(c, 1903),
           "blade": lambda c: S.M.steel(c, seed=1905, center=9.0, dent=0.0, rust=0.4, polish=0.15, scratch=0.3),
           "tuft": lambda c: S.A.silk(c, "lacing_red", 4.2, 1907)}
    tip = GRIP_R + SPEAR_DIR * (SPEAR_FRONT + 0.02 + BLADE)
    face = (0.0, 0.085, 1.78)
    return Model("samurai_ashigaru", parts, fns, ppm=256, ground=0.0, ao_dist=0.14, ao_rays=12, ao_stride=2, front=1,
                 normal_strength=2.0, markers=[("face", face, "head"), ("spear_tip", tuple(tip), "weapon")],
                 preview_yaws=(-35.0, 35.0, 120.0, 210.0), preview_closeup=((0.0, 0.1, 1.72), 0.3),
                 preview_extra=[("guard", (-0.3, 0.3, 1.35), 0.6, -20.0, 5.0)])
