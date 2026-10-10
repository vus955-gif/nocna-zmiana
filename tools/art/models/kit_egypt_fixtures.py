"""Floor I, Egypt wing kit: windows, plinths and light fittings.

  egypt_clerestory_3m  high clerestory window for a 3 x 2 m opening: a
                       painted torus roll round it on the wall face, a stone
                       grille of four upright slabs (moonlight comes through
                       in five shafts), a sandstone lining of the reveal 0.6 m
                       deep (scale Z to the wall), iron glazing bars and the
                       pane (part egypt_clerestory_3m_glass, glass, no shadow)
                       at the back. Origin = bottom centre of the opening on
                       the wall face; the reveal runs into the wall (+Z).
  egypt_plinth         statue plinth 1 x 0.6 x 1 m (scale to size): black
                       granite toe, polished red granite die, a torus roll
                       and a capping slab. Origin = centre of the base.
  egypt_torch_lamp     wall lamp in the form of a torch: a bronze lotus plate
                       on the wall, a curved arm, a papyrus-umbel cup holding
                       a flame-shaped frosted bulb (emissive). Fixture
                       convention: origin = the light (the flame's heart, put
                       the Light3D there), the mount runs back 0.32 m along
                       +Z to the wall. Marker Light at the origin.
  egypt_spotlight      a museum spotlight (black Fresnel lantern in a yoke,
                       a clamp above for a beam or a bar): origin = the lens
                       centre, the beam leaves along -Z (turn the model to
                       aim it), the clamp 0.45 m up. Marker Light.
"""
import math

import numpy as np
from mathutils import Matrix

from artlib import arch_materials as A
from artlib import egypt as E
from artlib import materials as M
from artlib.archkit import front_prism, kit, plan_sweep
from artlib.geo import Part
from artlib.materials import P, _dither
from artlib.painter import Surface


def clerestory():
    OW, OH, D = 3.0, 2.0, 0.6
    p = Part("egypt_clerestory_3m")
    # reveal lining (inside the opening, from the wall face back into the wall)
    p.box((0.0, D / 2, 0.04), (OW, D, 0.08), "sandstone", bevel=0.01)
    p.box((0.0, D / 2, OH - 0.04), (OW, D, 0.08), "sandstone", bevel=0.01)
    for sx in (-1, 1):
        p.box((sx * (OW / 2 - 0.04), D / 2, OH / 2), (0.08, D, OH), "sandstone", bevel=0.01)
    # a sloped sill nose on the room side
    p.box((0.0, -0.06, -0.05), (OW + 0.3, 0.14, 0.1), "sandstone", bevel=0.015)
    # the grille: four slabs
    step = (OW - 0.16) / 5
    for k in range(1, 5):
        x = -OW / 2 + 0.08 + step * k
        p.box((x, 0.2, OH / 2), (0.14, 0.32, OH - 0.16), "grille", bevel=0.012)
    # torus roll round the opening on the wall face
    path = [(-OW / 2 - 0.02, -0.02), (-OW / 2 - 0.02, OH + 0.02), (OW / 2 + 0.02, OH + 0.02), (OW / 2 + 0.02, -0.02)]
    p.sweep([(0.0, 0.0), (0.05, 0.02), (0.07, 0.07), (0.05, 0.12), (0.0, 0.14)], path, "torus", closed=True)
    # iron glazing bars at the back
    yb = D - 0.1
    for k in range(1, 5):
        x = -OW / 2 + OW * k / 5
        p.box((x, yb, OH / 2), (0.03, 0.04, OH - 0.1), "iron")
    p.box((0.0, yb, OH / 2), (OW - 0.1, 0.04, 0.03), "iron")
    g = Part("egypt_clerestory_3m_glass")
    g.poly([(-OW / 2 + 0.06, yb + 0.02, 0.06), (OW / 2 - 0.06, yb + 0.02, 0.06), (OW / 2 - 0.06, yb + 0.02, OH - 0.06),
            (-OW / 2 + 0.06, yb + 0.02, OH - 0.06)], "glass")
    return [p, g]


def plinth():
    p = Part("egypt_plinth")
    hx = hy = 0.5 - 0.03
    path = [(-hx, -hy), (-hx, hy), (hx, hy), (hx, -hy)]
    plan_sweep(p, [(0.0, 0.03), (0.08, 0.03), (0.09, 0.015), (0.1, 0.0)], path, "granite_black")
    plan_sweep(p, [(0.1, 0.0), (0.48, 0.0)], path, "granite_red")
    roll = [(0.48, 0.0)]
    for i in range(1, 8):
        a = -math.pi / 2 + math.pi * i / 8
        roll.append((0.51 + 0.03 * math.sin(a), 0.025 * math.cos(a)))
    roll.append((0.54, 0.0))
    plan_sweep(p, roll, path, "torus")
    plan_sweep(p, [(0.54, 0.0), (0.545, 0.02), (0.6, 0.02)], path, "granite_red")
    top = p.poly([(-hx - 0.02, -hy - 0.02, 0.6), (hx + 0.02, -hy - 0.02, 0.6), (hx + 0.02, hy + 0.02, 0.6),
                  (-hx - 0.02, hy + 0.02, 0.6)], "granite_red")[0]
    top.normal_update()
    if top.normal.z < 0:
        top.normal_flip()
    return p


def torch_lamp():
    p = Part("egypt_torch_lamp")
    # back plate on the wall (pre-turn: the wall is at +Y): a tall shield
    # with a lotus flower in relief
    plate = [(-0.09, -0.62), (0.09, -0.62), (0.1, -0.2), (0.07, -0.13), (0.0, -0.1), (-0.07, -0.13), (-0.1, -0.2)]
    front_prism(p, plate, 0.025, "bronze", y_back=0.335)
    for k, (ang, ln) in enumerate(((-38, 0.11), (-18, 0.13), (0, 0.15), (18, 0.13), (38, 0.11))):
        a_ = math.radians(ang)
        cx, cz = math.sin(a_) * ln * 0.5, -0.45 + math.cos(a_) * ln * 0.5
        petal = [(0.0, -ln / 2), (0.022, -ln / 4), (0.018, ln / 4), (0.0, ln / 2), (-0.018, ln / 4), (-0.022, -ln / 4)]
        rot = [(cx + x * math.cos(a_) + z * math.sin(a_), cz - x * math.sin(a_) + z * math.cos(a_)) for x, z in petal]
        front_prism(p, rot, 0.012, "gilt", y_back=0.312)
    # arm: a curved rod from the plate to the cup
    arm = [(0.0, 0.31, -0.42), (0.0, 0.22, -0.4), (0.0, 0.12, -0.34), (0.0, 0.04, -0.26), (0.0, 0.0, -0.2)]
    p.tube(arm, 0.022, "bronze", sides=6)
    # papyrus-umbel cup
    p.lathe([(0.02, -0.26), (0.03, -0.2), (0.06, -0.15), (0.095, -0.11), (0.1, -0.1), (0.085, -0.095)], "bronze",
            segments=12, cap_bottom=True, cap_top=False)
    # the flame bulb: frosted glass teardrop
    p.lathe([(0.07, -0.1), (0.075, -0.05), (0.07, 0.0), (0.055, 0.06), (0.035, 0.11), (0.015, 0.15), (0.004, 0.17)],
            "flame", segments=12, cap_bottom=True, cap_top=True)
    return p


def spotlight():
    p = Part("egypt_spotlight")
    # can along +Y (pre-turn: the lens at y = 0 faces -Y)
    can = p.lathe([(0.13, 0.0), (0.14, 0.02), (0.14, 0.36), (0.1, 0.4), (0.04, 0.42), (0.0, 0.42)], "iron",
                  segments=14, cap_bottom=False)
    p.move(can, Matrix.Rotation(math.radians(-90), 4, 'X'))
    for k in range(4):
        fin = p.lathe([(0.145, 0.0), (0.155, 0.0), (0.155, 0.012), (0.145, 0.012)], "iron", segments=14,
                      cap_bottom=False, cap_top=False)
        p.move(fin, Matrix.Translation((0.0, 0.12 + k * 0.05, 0.0)) @ Matrix.Rotation(math.radians(-90), 4, 'X'))
    lens = p.lathe([(0.115, 0.0), (0.1, 0.01), (0.06, 0.018), (0.0, 0.02)], "lens", segments=14, cap_bottom=True)
    p.move(lens, Matrix.Translation((0.0, 0.004, 0.0)) @ Matrix.Rotation(math.radians(90), 4, 'X'))
    # barn doors
    for sz in (-1, 1):
        p.box((0.0, -0.06, sz * 0.15), (0.26, 0.12, 0.008), "iron")
    # yoke and clamp
    for sx in (-1, 1):
        p.box((sx * 0.175, 0.18, 0.08), (0.014, 0.04, 0.3), "iron", bevel=0.003)
        p.box((sx * 0.165, 0.18, 0.0), (0.03, 0.06, 0.06), "iron", bevel=0.005)
    p.box((0.0, 0.18, 0.23), (0.37, 0.04, 0.014), "iron", bevel=0.003)
    p.tube([(0.0, 0.18, 0.23), (0.0, 0.18, 0.38)], 0.015, "iron", sides=6)
    p.box((0.0, 0.18, 0.42), (0.08, 0.1, 0.07), "iron", bevel=0.006)
    return p


def lamp_glass(ctx, seed=7):
    """Frosted flame-shaped bulb: warm, brightest in the heart."""
    s = Surface(ctx.N)
    z = ctx.p[:, 2]
    shade = 4.8 + np.clip(0.06 - np.abs(z), 0, 0.06) * 20.0 + ctx.fbm(30.0, 2, seed) * 0.4 + _dither(ctx, 0.4, seed + 1)
    s.use_ramp(P["flame"], shade=shade)
    s.rough = np.full(ctx.N, 0.35)
    s.emit = s.colors() * 1.0
    return s


def black_paint(ctx, seed=11):
    return A.paint(ctx, "paint_grey", 1.6, seed, rough=0.5, chip=0.5)


def build():
    return [
        kit("egypt_clerestory_3m", clerestory(), {"sandstone": lambda c: E.sandstone(c, 3, center=6.0),
                                                   "grille": lambda c: E.sandstone(c, 5, center=5.6),
                                                   "torus": E.binding, "iron": M.iron},
            kinds={"glass": "glass"}, ground=None, ao_dist=0.4, preview_elevation=-8.0),
        kit("egypt_plinth", [plinth()], {"granite_black": lambda c: E.granite(c, "black", 13, polish=0.2),
                                         "granite_red": lambda c: E.granite(c, "red", 17, polish=0.16),
                                         "torus": lambda c: E.granite(c, "red", 19, polish=0.16)},
            ppm=96, ao_dist=0.3),
        kit("egypt_torch_lamp", [torch_lamp()], {"bronze": lambda c: M.brass(c, 21, tarnish_amount=1.6),
                                                  "gilt": lambda c: E.gold_leaf(c, 23), "flame": lamp_glass}, ppm=192, ground=None,
            ao_dist=0.08, markers=[("Light", (0.0, 0.0, 0.0), None)]),
        kit("egypt_spotlight", [spotlight()], {"iron": black_paint, "lens": lambda c: M.glow(c, "lamp_warm", 4.5, 1.0)},
            ppm=192, ground=None, ao_dist=0.08, markers=[("Light", (0.0, 0.0, 0.0), None)]),
    ]
