"""Floor I, Americas wing enemy: the jaguar warrior (Wojownik-jaguar), about
1.8 m - a carved and painted wooden figure come alive: a warrior in a
jaguar suit, the pelt painted ochre with black rosettes over the wood, his
stern carved face looking out of the open maw of the jaguar helmet (fangs
above and below, round ears, turquoise-ringed eyes on the snout), turquoise
ear spools, cuffs and a chest plaque, a red loincloth, jaguar paws with
obsidian claws, a tail; a flat wooden club edged with obsidian teeth in
the right hand (in the manner of the macuahuitl) and a round feather
shield on the left forearm. Stylised, museum-respectful.

Faces +Y in Blender = -Z in Godot. Origin on the floor between the feet.
The game reuses the wolf's pounce logic; this rig gives it a crouching
sprint and a leap. Parts (pivots at the joints, Godot (x, y, z) = Blender
(x, z, -y)):
    pelvis      (0, 0.95, 0)          root (hips, loincloth)
    torso       (0, 1.05, 0)          waist, child of pelvis
    head        (0, 1.48, 0)          neck, child of torso (helmet + face)
    arm_l/_r    (-/+0.24, 1.4, 0)     shoulders, children of torso
    forearm_l/_r (-/+0.28, 1.14, 0)   elbows, children of arm_*
    club        (0.29, 0.86, -0.05)   the grip in the right hand, child of
                                      forearm_r; the blade hangs down
    shield      (-0.34, 1.0, -0.02)   on the left forearm, child of
                                      forearm_l, facing -X
    thigh_l/_r  (-/+0.1, 0.93, 0)     hips, children of pelvis
    shin_l/_r   (-/+0.11, 0.5, -0.02) knees, children of thigh_*
    foot_l/_r   (-/+0.11, 0.09, 0)    ankles, children of shin_*
    tail_1 > tail_2   (0, 0.92, 0.11) > (0, 0.55, 0.3): the suit's tail
Markers: face (child of head) = between the eyes on the face's surface
(hit centre / weak point), club_tip (child of club) = the end of the blade.
Rest pose: standing, club hanging at the right side, shield arm a little
forward. 256 px/m.
"""
import math

import numpy as np
from mathutils import Matrix, Vector

from artlib import clay
from artlib import americas as AM
from artlib import americas_paint as AP
from artlib import kit as K
from artlib import materials as M
from artlib import sculpt
from artlib.geo import Part
from artlib.materials import P, _dither, _select
from artlib.model import Model
from artlib.painter import Surface
from artlib.sculpt import blob, limb

ORDER = ["pelvis", "torso", "head", "arm_l", "arm_r", "forearm_l", "forearm_r", "club", "shield",
         "thigh_l", "thigh_r", "shin_l", "shin_r", "foot_l", "foot_r", "tail_1", "tail_2"]
IDX = {n: i for i, n in enumerate(ORDER)}
FACE = (0.0, 0.142, 1.6)


def _clay(p, blobs, tris, slot, res=0.01, cut=None):
    me = sculpt.metaball_mesh(blobs, resolution=res)
    if cut:
        sculpt.cut(me, cut)
    me = sculpt.decimate(me, tris)
    clay.into_part(p, me, slot)


def pelvis():
    p = Part("pelvis", origin=(0.0, 0.0, 0.95))
    _clay(p, [blob((0.0, 0.0, 0.95), (0.135, 0.095, 0.11)), blob((0.0, -0.03, 0.9), (0.12, 0.085, 0.08)),
              blob((0.0, 0.0, 1.02), (0.14, 0.1, 0.04))], 500, "pelt")
    # loincloth: a front flap and a belt band
    p.box((0.0, 0.1, 0.8), (0.16, 0.025, 0.3), "cloth", bevel=0.01)
    p.box((0.0, -0.1, 0.84), (0.14, 0.02, 0.22), "cloth", bevel=0.01)
    p.lathe([(0.158, 0.0), (0.165, 0.02), (0.165, 0.045), (0.158, 0.065)], "cloth", segments=16,
            center=(0.0, 0.0, 0.98), cap_bottom=False, cap_top=False, squash=(1.0, 0.7))
    return p


def torso():
    p = Part("torso", origin=(0.0, 0.0, 1.05), parent="pelvis")
    b = [blob((0.0, 0.0, 1.13), (0.125, 0.09, 0.1)), blob((0.0, 0.01, 1.29), (0.2, 0.12, 0.14)),
         blob((0.0, -0.015, 1.42), (0.19, 0.085, 0.065)), blob((0.0, -0.05, 1.3), (0.17, 0.08, 0.12))]
    for sx in (-1, 1):
        b.append(blob((sx * 0.09, 0.07, 1.31), (0.09, 0.05, 0.07)))
        b.append(blob((sx * 0.23, 0.0, 1.41), (0.08, 0.075, 0.075)))
        b.append(blob((sx * 0.13, -0.02, 1.47), (0.06, 0.05, 0.04)))     # trapezius
    _clay(p, b, 1000, "pelt")
    # the turquoise chest plaque on a cord
    disc = p.lathe([(0.0, 0.0), (0.05, 0.0), (0.052, 0.01), (0.04, 0.016), (0.0, 0.018)], "mosaic", segments=12)
    p.move(disc, Matrix.Translation(Vector((0.0, 0.125, 1.3))) @ Matrix.Rotation(math.radians(-80.0), 4, 'X'))
    return p


def head():
    p = Part("head", origin=(0.0, 0.0, 1.48), parent="torso")
    helmet = [blob((0.0, -0.01, 1.69), (0.125, 0.14, 0.11)),               # cranium of the helmet
              blob((0.0, 0.1, 1.72), (0.1, 0.1, 0.055)),                    # the jaguar's upper snout
              blob((0.0, 0.19, 1.735), (0.045, 0.03, 0.032)),               # its broad nose
              blob((0.0, 0.07, 1.785), (0.09, 0.06, 0.045)),                # brow over its eyes
              blob((0.0, 0.0, 1.5), (0.065, 0.065, 0.07)),                  # neck
              blob((0.0, 0.1, 1.47), (0.1, 0.075, 0.03)),                   # the jaguar's lower jaw (a collar)
              blob((0.0, -0.06, 1.55), (0.13, 0.1, 0.1))]                   # back of the helmet
    for sx in (-1, 1):
        helmet.append(blob((sx * 0.1, -0.05, 1.8), (0.042, 0.022, 0.042)))         # ears
        helmet.append(blob((sx * 0.115, 0.05, 1.58), (0.04, 0.085, 0.1)))         # the maw's sides
    _clay(p, helmet, 1500, "pelt", res=0.008)
    face = [blob((0.0, 0.08, 1.585), (0.075, 0.06, 0.085)), blob((0.0, 0.135, 1.585), (0.02, 0.022, 0.028)),
            blob((0.0, 0.12, 1.545), (0.035, 0.02, 0.012)), blob((0.0, 0.11, 1.52), (0.03, 0.025, 0.02))]
    for sx in (-1, 1):
        face.append(blob((sx * 0.03, 0.12, 1.625), (0.03, 0.015, 0.01)))          # brows
        face.append(blob((sx * 0.028, 0.125, 1.605), (0.016, 0.012, 0.01), neg=True, stiff=1.5))
    _clay(p, face, 700, "skin", res=0.006)
    for sx in (-1, 1):
        K.sphere(p, (sx * 0.028, 0.124, 1.604), 0.0115, "eye_glow", segments=8, rings=5, squash=(1.0, 0.6))
        # upper fangs from the snout, lower fangs from the jaw
        K.cone(p, (sx * 0.075, 0.16, 1.69), (sx * 0.1, 0.15, -1.0), 0.05, 0.011, "tooth", segments=5, tip=0.003)
        K.cone(p, (sx * 0.07, 0.15, 1.485), (sx * 0.1, 0.15, 1.0), 0.035, 0.01, "tooth", segments=5, tip=0.003)
        # turquoise ear spools on the helmet's cheeks
        sp = p.lathe([(0.0, 0.0), (0.03, 0.0), (0.032, 0.012), (0.018, 0.02), (0.0, 0.02)], "mosaic", segments=12)
        p.move(sp, Matrix.Translation(Vector((sx * 0.15, 0.03, 1.58))) @ Matrix.Rotation(math.radians(sx * 90.0), 4, 'Y'))
        # the jaguar's eyes: turquoise rings on the snout
        # the jaguar's eyes on the front of the helmet: a turquoise ring round an obsidian eye
        d = Vector((sx * 0.35, 1.0, 0.25)).normalized()
        ring = p.lathe([(0.016, 0.0), (0.03, 0.0), (0.031, 0.006), (0.017, 0.009)], "mosaic", segments=12)
        p.move(ring, Matrix.Translation(Vector((sx * 0.062, 0.128, 1.775))) @ d.to_track_quat('Z', 'Y').to_matrix().to_4x4())
        eye = K.sphere(p, (0.0, 0.0, 0.0), 0.018, "obsidian", segments=8, rings=5, squash=(1.0, 1.0), zscale=0.6)
        p.move(eye, Matrix.Translation(Vector((sx * 0.062, 0.128, 1.775))) @ d.to_track_quat('Z', 'Y').to_matrix().to_4x4())
    return p


def arm(sx):
    n = "arm_l" if sx < 0 else "arm_r"
    sh, el = (sx * 0.24, 0.0, 1.4), (sx * 0.28, 0.0, 1.14)
    p = Part(n, origin=sh, parent="torso")
    _clay(p, limb([sh, el], [0.068, 0.05], spacing=0.6) + [blob((sx * 0.24, 0.0, 1.39), (0.075, 0.07, 0.07)),
                                                           blob((sx * 0.25, 0.02, 1.27), (0.055, 0.05, 0.07))],
          450, "pelt", res=0.008)
    return p


def forearm(sx):
    n = "forearm_l" if sx < 0 else "forearm_r"
    el, wr = (sx * 0.28, 0.0, 1.14), (sx * 0.29, 0.04, 0.9)
    p = Part(n, origin=el, parent=n.replace("forearm", "arm"))
    b = limb([el, wr], [0.052, 0.038], spacing=0.6) + [blob((sx * 0.285, 0.015, 1.06), (0.05, 0.05, 0.07))]
    _clay(p, b, 350, "pelt", res=0.008)
    hand = [blob((sx * 0.29, 0.05, 0.855), (0.04, 0.036, 0.055))]
    for k in range(3):
        hand += limb([(sx * 0.29 + (k - 1) * 0.016, 0.08, 0.86), (sx * 0.29 + (k - 1) * 0.016, 0.09, 0.82)],
                     [0.013, 0.011], spacing=0.6)
    _clay(p, hand, 250, "skin", res=0.005)
    cuff = p.lathe([(0.042, 0.0), (0.046, 0.01), (0.046, 0.05), (0.042, 0.06)], "mosaic", segments=12,
                   cap_bottom=False, cap_top=False)
    d = Vector(wr) - Vector(el)
    p.move(cuff, Matrix.Translation(Vector(wr) - d.normalized() * 0.09) @ d.normalized().to_track_quat('Z', 'Y').to_matrix().to_4x4())
    return p


def club():
    p = Part("club", origin=(0.29, 0.05, 0.86), parent="forearm_r")
    x, y = 0.29, 0.05
    p.tube([(x, y, 0.98), (x, y + 0.01, 0.7)], 0.02, "grip", sides=8)
    # the blade: a flat paddle in the y-z plane, its edges front and back
    p.box((x, y + 0.03, 0.4), (0.024, 0.11, 0.62), "club_wood", bevel=0.006)
    p.box((x, y + 0.03, 0.08), (0.024, 0.09, 0.04), "club_wood", bevel=0.008)
    for k in range(8):
        z = 0.66 - k * 0.075
        for sy in (-1, 1):
            K.cone(p, (x, y + 0.03 + sy * 0.05, z), (0.0, sy, 0.0), 0.04, 0.022, "obsidian", segments=3, tip=0.002)
    return p


def shield():
    p = Part("shield", origin=(-0.34, -0.02, 1.0), parent="forearm_l")
    R = 0.24
    disc = p.lathe([(0.0, 0.0), (R, 0.0), (R, 0.02), (R * 0.6, 0.035), (0.0, 0.04)], "shield", segments=20)
    p.move(disc, Matrix.Translation(Vector((-0.34, 0.03, 1.02))) @ Matrix.Rotation(math.radians(-90.0), 4, 'Y'))
    for k in range(9):
        t = (k - 4) / 4.0
        top = Vector((-0.36, 0.03 + t * R * 0.7, 1.02 - R * 0.85 + abs(t) * 0.06))
        p.tube([tuple(top), tuple(top + Vector((-0.01, t * 0.03, -0.18)))], lambda u: 0.02 * (1.0 - 0.6 * u) + 0.004,
               "plume", sides=4)
    return p


def thigh(sx):
    n = "thigh_l" if sx < 0 else "thigh_r"
    hp, kn = (sx * 0.1, 0.0, 0.93), (sx * 0.11, 0.02, 0.5)
    p = Part(n, origin=hp, parent="pelvis")
    _clay(p, limb([hp, kn], [0.096, 0.062], spacing=0.6) + [blob((sx * 0.11, 0.04, 0.78), (0.07, 0.06, 0.12))], 450,
          "pelt", res=0.009)
    return p


def shin(sx):
    n = "shin_l" if sx < 0 else "shin_r"
    kn, an = (sx * 0.11, 0.02, 0.5), (sx * 0.11, 0.0, 0.1)
    p = Part(n, origin=kn, parent=n.replace("shin", "thigh"))
    _clay(p, limb([kn, an], [0.06, 0.042], spacing=0.6) + [blob((sx * 0.11, -0.035, 0.36), (0.058, 0.062, 0.1))],
          400, "pelt", res=0.008)
    return p


def foot(sx):
    n = "foot_l" if sx < 0 else "foot_r"
    p = Part(n, origin=(sx * 0.11, 0.0, 0.09), parent=n.replace("foot", "shin"))
    _clay(p, [blob((sx * 0.11, 0.05, 0.045), (0.05, 0.11, 0.045)), blob((sx * 0.11, 0.0, 0.08), (0.045, 0.05, 0.04))],
          300, "pelt", res=0.007, cut=[((0.0, 0.0, 0.0), (0.0, 0.0, -1.0))])
    for k in range(4):
        x = sx * 0.11 + (k - 1.5) * 0.022
        K.cone(p, (x, 0.15, 0.03), (0.0, 1.0, -0.5), 0.035, 0.009, "obsidian", segments=4, tip=0.002)
    return p


def tail():
    a = Part("tail_1", origin=(0.0, -0.11, 0.92), parent="pelvis")
    pts = [(0.0, -0.11, 0.92), (0.0, -0.22, 0.8), (0.0, -0.29, 0.65), (0.0, -0.3, 0.55)]
    a.tube(pts, lambda t: 0.035 - 0.006 * t, "pelt", sides=8)
    b = Part("tail_2", origin=(0.0, -0.3, 0.55), parent="tail_1")
    pts = [(0.0, -0.3, 0.55), (0.0, -0.31, 0.4), (0.0, -0.36, 0.26), (0.0, -0.44, 0.18)]
    b.tube(pts, lambda t: 0.029 - 0.01 * t, "tail_tip", sides=8)
    return [a, b]


# --------------------------------------------------------------------------
# paint
# --------------------------------------------------------------------------

def pelt(ctx, seed=2201):
    """Jaguar pelt painted over carved wood: ochre with black rosettes (a
    broken ring of dark spots round a slightly deeper centre), pale on the
    belly and inner limbs, the wood showing through where the paint wore
    off on the edges and the high points."""
    s = AM.carved_wood(ctx, seed, ramp="am_wood", center=3.0, adze=0.7, oiled=0.4)
    f1, f2, cid = ctx.worley(14.0, seed + 1, jitter=0.8)
    # angle round the cell centre is unknown: use a second noise to break the ring into spots
    ring = (f1 > 0.22) & (f1 < 0.4) & (ctx.fbm(60.0, 2, seed + 2) > -0.15)
    centre = f1 < 0.2
    small = (ctx.worley(34.0, seed + 3)[0] < 0.18)
    base = Surface(ctx.N)
    shade = 4.8 + ctx.fbm(6.0, 3, seed + 4) * 0.7 + _dither(ctx, 0.5, seed + 5) - centre * 1.0
    shade += np.clip(ctx.curv, 0, 1) * 1.0 - np.clip(-ctx.curv, 0, 1) * 1.2 - (1.0 - ctx.ao) * 3.0
    base.use_ramp(P["am_pelt"], shade=shade)
    spot = ring | (small & ~centre)
    base.use_ramp(P["am_obsidian"], mask=spot, shade=np.full(ctx.N, 1.8) + _dither(ctx, 0.6, seed + 7))
    base.rough = np.full(ctx.N, 0.6)
    worn = (ctx.edge_soft(2.0) + np.clip(ctx.curv, 0, 1) * 0.6 + ctx.fbm(9.0, 2, seed + 8) * 0.6) > 0.72
    # the nose leather, dark
    nose = (ctx.part == IDX["head"]) & (ctx.p[:, 1] > 0.195) & (ctx.p[:, 2] > 1.72) & (np.abs(ctx.p[:, 0]) < 0.035)
    base.use_ramp(P["am_obsidian"], mask=nose, shade=np.full(ctx.N, 3.0) + _dither(ctx, 0.5, seed + 9))
    keep = ~worn
    s.merge(_select(base, keep), keep)
    s.height = s.height + spot * -0.0003
    return s


def skin(ctx, seed=2203):
    """The warrior's carved face and hands: polished dark wood with a red
    band of paint across the eyes."""
    s = AM.carved_wood(ctx, seed, ramp="am_wood", center=4.2, adze=0.3, oiled=0.8)
    band = (ctx.part == IDX["head"]) & (np.abs(ctx.p[:, 2] - 1.607) < 0.014) & (ctx.n[:, 1] > 0.2)
    codes = np.where(band, AP.INK["red"], 0).astype(np.int16)
    return AM.paint_over(ctx, s, codes, seed + 1, flake=0.15)


def cloth(ctx, seed=2205):
    s = M.cloth_red(ctx, seed)
    edge = ctx.edge_soft(3.0) > 0.4
    s.use_ramp(P["am_shell"], mask=edge, shade=np.full(ctx.N, 5.2) + _dither(ctx, 0.6, seed + 1))
    return s


def shield_paint(ctx, seed=2207):
    """Feather mosaic in rings: a yellow field, a turquoise stepped fret
    band, a red rim."""
    r = np.hypot(ctx.p[:, 1] - 0.03, ctx.p[:, 2] - 1.02)
    s = AM.feathers(ctx, "am_feather_yellow", flow=(0.0, 0.0, -1.0), seed=seed, center=4.6)
    red = r > 0.2
    s.merge(_select(AM.feathers(ctx, "am_feather_red", (0.0, 0.0, -1.0), seed + 1, 4.4), red), red)
    a = np.arctan2(ctx.p[:, 1] - 0.03, ctx.p[:, 2] - 1.02)
    band = (r > 0.12) & (r < 0.17) & (np.mod(a * 12 / (2 * np.pi), 1.0) < 0.5)
    s.merge(_select(AM.feathers(ctx, "am_feather_blue", (0.0, 0.0, -1.0), seed + 2, 4.2), band), band)
    return s


def club_wood(ctx, seed=2209):
    s = AM.carved_wood(ctx, seed, ramp="am_wood", center=4.6, adze=0.5)
    stripe = np.mod(ctx.p[:, 2] / 0.15, 1.0) < 0.2
    return AM.paint_over(ctx, s, np.where(stripe, AP.INK["red"], 0).astype(np.int16), seed + 1, flake=0.3)


def eye_glow(ctx, seed=2211):
    return AM.glow(ctx, "am_ember", 5.6, 1.0, seed, flicker=0.4)


def build():
    parts = [pelvis(), torso(), head(), arm(-1), arm(1), forearm(-1), forearm(1), club(), shield(),
             thigh(-1), thigh(1), shin(-1), shin(1), foot(-1), foot(1)] + tail()
    parts = sorted(parts, key=lambda p: IDX[p.name])
    fns = {"pelt": pelt, "skin": skin, "cloth": cloth, "mosaic": lambda c: AM.mosaic(c, 2213, cell=0.02, spread=1.6,
                                                                                       gap_texels=0.6),
           "tooth": lambda c: M.ivory(c, 2215, center=6.0), "eye_glow": eye_glow,
           "grip": lambda c: AM.rope(c, 2217, center=3.6), "club_wood": club_wood,
           "obsidian": lambda c: AM.obsidian(c, 2219), "shield": shield_paint,
           "plume": lambda c: AM.feathers(c, "am_feather_green", (0.0, 0.0, -1.0), 2221, 4.4),
           "tail_tip": lambda c: AM.carved_wood(c, 2223, "am_obsidian", 3.0, adze=0.2)}
    organic = ("pelvis", "torso", "head", "arm_l", "arm_r", "forearm_l", "forearm_r", "thigh_l", "thigh_r",
               "shin_l", "shin_r", "foot_l", "foot_r")
    return Model("jaguar", parts, fns, ppm=256, ground=0.0, ao_dist=0.12, ao_rays=12, front=1, organic=organic,
                 markers=[("face", FACE, "head"), ("club_tip", (0.29, 0.08, 0.06), "club")],
                 preview_yaws=(-35.0, 35.0, 120.0, 210.0), preview_closeup=((0.0, 0.1, 1.64), 0.2),
                 preview_extra=[("club", (0.29, 0.05, 0.5), 0.5, 60.0, 10.0)])
