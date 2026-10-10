"""Floor I, Americas and Oceania wing: fire fixtures and the portal.

  americas_brazier     fire bowl 0.8 x 1.45 x 0.8 (the greybox "brazier"
                       0.8 x 1.0 x 0.8 plus its flames): a stepped stone
                       pedestal, a flared clay brazier ringed with knobs and
                       painted bands, a bed of embers; part "flame" = the
                       flame tongues (emission; flicker it by scaling, hide
                       it when the fire is out). Origin = centre of the base;
                       marker "Light" at (0, 1.3, 0) where the greybox puts
                       the fire's OmniLight.
  americas_torch_lamp  wall fire: a small clay bowl on an iron bracket with
                       its flame; fixture convention: origin = the light
                       (marker "Light" there), the bracket runs back 0.34 m
                       along +Z to the wall. Part "flame".
  americas_portal_4m   portal of a 4 x 4.5 m opening: carved jambs with
                       stacked cartouches, a lintel with a serpent and
                       frets, a crest of stepped merlons; stucco reveals
                       0.5 deep (scale Z to the wall). Origin = middle of
                       the opening's floor on the wall face, decoration
                       toward the room (-Z).
"""
import math

import numpy as np
from mathutils import Matrix, Vector

from artlib import americas as AM
from artlib import americas_paint as AP
from artlib import kit as K
from artlib.archkit import front_prism, kit, moulding
from artlib.geo import Part
from artlib.model import Model


def flame_tongue(p, base, height, radius, lean=(0.0, 0.0), twist=0.0, slot="flame"):
    """A teardrop flame: a lathe swelling low and drawn to a tip, leaning."""
    prof = [(radius * 0.55, 0.0), (radius, height * 0.18), (radius * 0.9, height * 0.4), (radius * 0.55, height * 0.65),
            (radius * 0.22, height * 0.88), (radius * 0.06, height)]
    f = p.lathe(prof, slot, segments=7, cap_bottom=False, cap_top=True, smooth=True, phase=twist)
    # lean: shear the tongue with height
    for v in {v for face in f for v in face.verts}:
        t = v.co.z / height
        v.co.x += lean[0] * t * t
        v.co.y += lean[1] * t * t
    p.move(f, Matrix.Translation(Vector(base)))
    return f


def fire(p, centre, scale=1.0, seed=0):
    rng = np.random.default_rng(seed)
    cx, cy, cz = centre
    spec = [((0.0, 0.0), 0.55, 0.11), ((0.08, 0.04), 0.4, 0.08), ((-0.07, 0.05), 0.42, 0.08),
            ((0.03, -0.08), 0.36, 0.07), ((-0.05, -0.05), 0.3, 0.06)]
    for k, ((dx, dy), h, r) in enumerate(spec):
        lean = tuple(rng.uniform(-0.06, 0.06, 2) * scale)
        flame_tongue(p, (cx + dx * scale, cy + dy * scale, cz), h * scale, r * scale, lean, twist=k * 0.7)


def brazier():
    p = Part("americas_brazier")
    p.box((0.0, 0.0, 0.06), (0.8, 0.8, 0.12), "stone", bevel=0.015)
    p.box((0.0, 0.0, 0.31), (0.64, 0.64, 0.38), "stone_carved", bevel=0.015)
    p.box((0.0, 0.0, 0.54), (0.74, 0.74, 0.08), "stone", bevel=0.015)
    bowl = [(0.2, 0.58), (0.24, 0.62), (0.3, 0.72), (0.36, 0.84), (0.4, 0.95), (0.41, 0.98), (0.37, 0.99),
            (0.33, 0.9), (0.27, 0.8), (0.0, 0.78)]
    p.lathe([(r, z) for r, z in bowl], "clay", segments=16, cap_bottom=False, cap_top=False)
    # knobs (spikes) round the bowl's belly, two rows
    for row, (z, r) in enumerate(((0.8, 0.335), (0.9, 0.385))):
        for k in range(10):
            a = 2 * math.pi * (k + 0.5 * row) / 10
            d = (math.cos(a), math.sin(a), 0.25)
            K.cone(p, (r * math.cos(a), r * math.sin(a), z), d, 0.07, 0.03, "clay", segments=5, tip=0.006)
    p.lathe([(0.0, 0.0), (0.355, 0.0), (0.33, 0.04), (0.2, 0.07), (0.0, 0.08)], "embers", segments=16,
            center=(0.0, 0.0, 0.88), cap_bottom=False, cap_top=False)
    f = Part("flame", origin=(0.0, 0.0, 0.92), parent="americas_brazier")
    fire(f, (0.0, 0.0, 0.92), 1.0, seed=3)
    return [p, f]


def torch_lamp():
    p = Part("americas_torch_lamp")
    # built final: Godot +Z (to the wall) = Blender -Y
    p.box((0.0, -0.34, -0.1), (0.2, 0.03, 0.42), "iron", bevel=0.006)          # wall plate
    p.tube([(0.0, -0.33, -0.22), (0.0, -0.2, -0.24), (0.0, -0.06, -0.2)], 0.018, "iron", sides=6)
    p.tube([(0.0, -0.33, 0.05), (0.0, -0.2, -0.05), (0.0, -0.1, -0.15)], 0.014, "iron", sides=6)
    bowl = [(0.06, -0.2), (0.1, -0.19), (0.15, -0.12), (0.17, -0.07), (0.15, -0.065), (0.12, -0.1),
            (0.0, -0.11)]
    p.lathe([(r, z) for r, z in bowl], "clay", segments=12, cap_bottom=True, cap_top=False)
    p.lathe([(0.0, 0.0), (0.135, 0.0), (0.08, 0.02), (0.0, 0.025)], "embers", segments=12,
            center=(0.0, 0.0, -0.095), cap_bottom=False, cap_top=False)
    f = Part("flame", origin=(0.0, 0.0, -0.09), parent="americas_torch_lamp")
    fire(f, (0.0, 0.0, -0.09), 0.55, seed=5)
    return [p, f]


# --------------------------------------------------------------------------
# the portal
# --------------------------------------------------------------------------

_P = {}


def jamb_canvas():
    """0.7 x 4.5 m at 64 px/m (45 x 288 px): five cartouches stacked between
    bead columns, red field."""
    if "jamb" in _P:
        return _P["jamb"]
    W, H = 45, 288
    lv = np.zeros((H, W), np.int16)
    pt = np.full((H, W), AP.INK["red"], np.int16)
    names = ["flame", "eye", "spiral", "water", "petals"]
    for k, name in enumerate(names):
        fr, gm = AP.cartouche(name, 34)
        y = 12 + k * 54
        AP.paste(lv, fr, 5, y, 2)
        AP.paste(lv, gm, 5, y, 3)
        AP.paste(pt, fr, 5, y, AP.INK["turq"])
        AP.paste(pt, gm, 5, y, AP.INK["black"])
        b = AP.bead(8)
        AP.paste(lv, b, 18, y + 39, 2)
        AP.paste(pt, b, 18, y + 39, AP.INK["white"])
    lv[:, 0:2] = 1
    lv[:, W - 2:] = 1
    _P["jamb"] = (lv, pt, AP.relief_wrap_shade(lv))
    return _P["jamb"]


def portal():
    p = Part("americas_portal_4m")
    ow, oh = 4.0, 4.5
    jw, jd = 0.7, 0.28
    for sx in (-1, 1):
        x = sx * (ow / 2 + jw / 2)
        p.box((x, -jd / 2, oh / 2), (jw, jd, oh), "jamb", bevel=0.02)
        p.box((x, -jd / 2 - 0.02, 0.15), (jw + 0.08, jd + 0.04, 0.3), "stone", bevel=0.02)   # jamb base
    # lintel with a carved band (the frieze tile in the atlas) and a drip
    lw = ow + 2 * jw + 0.3
    p.box((0.0, -0.17, oh + 0.5), (lw, 0.34, 1.0), "lintel", bevel=0.02)
    p.box((0.0, -0.2, oh + 1.06), (lw + 0.12, 0.4, 0.12), "stone", bevel=0.02)
    # crest: stepped merlons above
    merlon = [(-0.22, 0.0), (0.22, 0.0), (0.22, 0.2), (0.15, 0.2), (0.15, 0.4), (0.08, 0.4), (0.08, 0.6),
              (-0.08, 0.6), (-0.08, 0.4), (-0.15, 0.4), (-0.15, 0.2), (-0.22, 0.2)]
    for k in range(7):
        x = -2.55 + k * 0.85
        front_prism(p, [(x + a, oh + 1.12 + b) for a, b in merlon], 0.14, "merlon", y_back=-0.05)
    # reveals: stucco lining of the opening, 0.5 into the wall (+Y pre-turn)
    for sx in (-1, 1):
        p.box((sx * (ow / 2 + 0.02), 0.25, oh / 2), (0.04, 0.5, oh), "reveal")
    p.box((0.0, 0.25, oh + 0.02), (ow, 0.5, 0.04), "reveal")
    return p


def jamb_paint(ctx):
    lv, pt, sh = jamb_canvas()
    # (painted after kit() turned the piece: the decorated front faces +Y)
    u = np.abs(ctx.p[:, 0]) - 2.0
    front = ctx.n[:, 1] > 0.5
    idx = AM.canvas_index(lv.shape, u, ctx.p[:, 2], ctx.texel)
    rows, cols, inside = idx
    idx = (rows, cols, inside & front)
    s = AM.volcanic(ctx, 201, center=4.8, vesicles=0.5)
    s = AM.relief(ctx, s, lv, sh, idx, depth=0.005, light=1.0)
    return AM.paint_over(ctx, s, AM.take(pt, idx), 203, flake=0.4, wear=0.8)


def lintel_paint(ctx):
    """The lintel's face carries the frieze canvas (1 m tall)."""
    lv, pt = AP.frieze_canvas()
    sh = AP.relief_wrap_shade(lv)
    front = ctx.n[:, 1] > 0.5
    idx = AM.canvas_index(lv.shape, 3.0 - ctx.p[:, 0], ctx.p[:, 2] - 4.5, ctx.texel, wrap_x=True)
    rows, cols, inside = idx
    idx = (rows, cols, inside & front)
    s = AM.volcanic(ctx, 205, center=4.8, vesicles=0.5)
    s = AM.relief(ctx, s, lv, sh, idx, depth=0.004, light=1.0)
    codes = AM.take(pt, idx)
    return AM.paint_over(ctx, s, codes, 207, flake=0.4, wear=0.0)


def build():
    out = []
    parts = brazier()
    out.append(Model("americas_brazier", parts,
                     {"stone": lambda c: AM.volcanic(c, 211, center=4.4), "stone_carved": lambda c: AM.am_stone_blocks(c, 213),
                      "clay": lambda c: AM.clay(c, 215, center=4.2), "embers": lambda c: AM.embers(c, 217, 1.0),
                      "flame": lambda c: AM.flame(c, 219, 1.0)},
                     ppm=128, ground=0.0, ao_dist=0.2, front=-1, markers=[("Light", (0.0, 0.0, 1.3), None)]))
    parts = torch_lamp()
    out.append(Model("americas_torch_lamp", parts,
                     {"iron": lambda c: AM.iron_old(c, 221), "clay": lambda c: AM.clay(c, 223, center=5.2),
                      "embers": lambda c: AM.embers(c, 225, 1.0), "flame": lambda c: AM.flame(c, 227, 1.0)},
                     ppm=192, ground=None, ao_dist=0.08, front=1, markers=[("Light", (0.0, 0.0, 0.0), None)],
                     ao_planes=(("y", -0.355),)))
    out.append(kit("americas_portal_4m", [portal()],
                   {"jamb": jamb_paint, "lintel": lintel_paint, "stone": lambda c: AM.volcanic(c, 229, center=4.4),
                    "merlon": lambda c: AM.paint_over(c, AM.stucco(c, 231, center=5.2),
                                                      np.full(c.N, AP.INK["white"], np.int16), 233, flake=0.3),
                    "reveal": lambda c: AM.stucco(c, 235, center=4.4)},
                   ppm=64, wall=True, ao_dist=0.5, preview_yaws=(-25.0, 0.0, 25.0, 60.0), preview_elevation=6.0))
    return out
