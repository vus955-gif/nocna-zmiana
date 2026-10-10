"""Lobby kit: the props the greybox still had - furniture of the staff rooms,
display furniture of the wings and the gallery's statue. All in the kit
convention (origin = centre of the base, front = Godot -Z), fitted by ArtKit
to the greybox sizes.

  crate          1 x 1 x 1 m museum shipping crate: pine boards on oak
                 battens, iron corner plates, rope handles, stencilled
                 "MUZEUM" and an arrow.
  desk           1.6 x 0.78 x 0.8 m oak pedestal desk (security room, the
                 night guard's desk on the balcony): three drawers each side
                 with brass pulls, a pencil drawer, a modesty panel.
  chair          0.6 x 1.0 x 0.6 m oak office chair with a leather seat.
  shelf_unit     1 x 1.8 x 0.5 m archive shelving in olive paint with
                 cardboard boxes and box files; ArtKit repeats it along X.
  armor_stand    1.2 x 2.2 x 0.8 m oak display stand carrying a gothic
                 half-suit (the knight's own cuirass, faulds, tassets,
                 pauldrons and sallet: the same armoury), no arms, no legs:
                 a display, not an enemy. Its helmet is dark inside.
  sculpture      2.2 x 4.5 x 2.2 m the sculpture gallery's centrepiece: a
                 draped marble figure (peplophoros, 3.3 m) on a moulded
                 limestone pedestal with verde bands and a brass plate.
  case_tall      1.2 x 1.8 x 1.2 m tall vitrine (the crystal's case): walnut
                 cabinet, velvet bed at 0.95 m, a glass cube in brass. Part
                 case_tall_glass (the game shatters it).
  case_table     2 x 1.4 x 1.4 m table vitrine module on turned legs with a
                 glass hood (the armory's long case is three of them).
                 Part case_table_glass.
  plaque_brass   0.5 x 0.3 x 0.04 m blank brass label plate with a raised
                 rim and four screws (the game engraves it).
"""
import math
import random

import numpy as np
from mathutils import Matrix

from artlib import arch_materials as A
from artlib import kit as K
from artlib import materials as M
from artlib import sculpt
from artlib.archkit import kit, plan_sweep
from artlib.geo import Part
from artlib.sculpt import blob


# --- crate --------------------------------------------------------------------

def crate():
    p = Part("crate")
    S = 1.0
    h = S / 2
    p.box((0, 0, h), (S - 0.06, S - 0.06, S - 0.02), "pine", bevel=0.01)
    # horizontal boards on the four sides, a hair proud of the core
    for k in range(4):
        z = 0.04 + k * 0.235 + 0.11
        for cx, cy, sx, sy in ((0, -h + 0.02, S - 0.16, 0.02), (0, h - 0.02, S - 0.16, 0.02),
                               (-h + 0.02, 0, 0.02, S - 0.16), (h - 0.02, 0, 0.02, S - 0.16)):
            p.box((cx, cy, z), (sx, sy, 0.215), "pine", bevel=0.006)
    # oak battens: corner posts, rails round the top and the bottom, a cross brace in front
    for sx in (-1, 1):
        for sy in (-1, 1):
            p.box((sx * (h - 0.045), sy * (h - 0.045), h), (0.09, 0.09, S), "oak", bevel=0.012)
    for z in (0.05, S - 0.05):
        p.box((0, -h + 0.015, z), (S - 0.18, 0.035, 0.1), "oak", bevel=0.01)
        p.box((0, h - 0.015, z), (S - 0.18, 0.035, 0.1), "oak", bevel=0.01)
        p.box((-h + 0.015, 0, z), (0.035, S - 0.18, 0.1), "oak", bevel=0.01)
        p.box((h - 0.015, 0, z), (0.035, S - 0.18, 0.1), "oak", bevel=0.01)
    brace = p.box((0, 0, 0), (1.08, 0.03, 0.09), "oak", bevel=0.008)
    p.move(brace, Matrix.Translation((0, h + 0.012, h)) @ Matrix.Rotation(math.radians(40), 4, 'Y'))
    # lid planks
    for k in range(5):
        p.box((-0.36 + k * 0.18, 0, S + 0.01), (0.17, S - 0.02, 0.025), "pine", bevel=0.006)
    # iron corner plates (top corners) and a hasp
    for sx in (-1, 1):
        for sy in (-1, 1):
            p.box((sx * (h - 0.06), sy * (h + 0.001), S - 0.06), (0.12, 0.006, 0.12), "iron", bevel=0.003)
            p.box((sx * (h + 0.001), sy * (h - 0.06), S - 0.06), (0.006, 0.12, 0.12), "iron", bevel=0.003)
    p.box((0, -h - 0.006, S - 0.07), (0.05, 0.012, 0.1), "iron", bevel=0.004)
    # rope handles on the sides
    for sx in (-1, 1):
        pts = [(sx * (h + 0.02), y, 0.62 + 0.06 * math.cos(y * 12.0)) for y in (-0.16, -0.08, 0.0, 0.08, 0.16)]
        p.tube(pts, 0.014, "rope", sides=6)
    return p


def _stencil(ctx):
    """Pine boards with a stencilled MUZEUM and an up arrow on the front."""
    s = M.wood_oak(ctx, seed=401)
    s.shade += 0.9
    u, v = ctx.uvm[:, 0], ctx.uvm[:, 1]
    from artlib import font
    ink = font.text_mask(u, v, "MUZEUM", 0.0, 0.42, 4.0 / 256, align="center")
    arrow = (abs(u) < 0.03) & (v > 0.56) & (v < 0.74) | ((v > 0.70) & (v < 0.80) & (abs(u) < (0.80 - v) * 0.9))
    mask = ink | arrow
    s.use_ramp(A.P["leather"], mask=mask, shade=np.full(ctx.N, 1.2))
    return s


# --- desk and chair -----------------------------------------------------------

def desk():
    p = Part("desk")
    W, H, D = 1.6, 0.78, 0.8
    p.box((0, 0, H - 0.02), (W, D, 0.04), "oak", bevel=0.008)
    p.box((0, 0, H - 0.05), (W - 0.04, D - 0.04, 0.03), "oak", bevel=0.006)
    for sx in (-1, 1):
        x = sx * (W / 2 - 0.24)
        p.box((x, 0.01, 0.05), (0.44, D - 0.08, 0.1), "oak_dark", bevel=0.008)        # toe plinth
        p.box((x, 0.0, 0.42), (0.46, D - 0.04, 0.64), "oak", bevel=0.01)              # pedestal
        for k in range(3):
            z = 0.2 + k * 0.2
            p.box((x, -D / 2 + 0.012, z), (0.4, 0.016, 0.17), "oak", bevel=0.008)     # drawer front
            p.box((x, -D / 2 - 0.006, z + 0.03), (0.12, 0.014, 0.022), "brass", bevel=0.005)
            p.box((x - 0.12, -D / 2 - 0.004, z + 0.04), (0.03, 0.01, 0.035), "brass", bevel=0.004)  # label frame
    p.box((0, -D / 2 + 0.014, H - 0.1), (W - 1.0, 0.016, 0.08), "oak", bevel=0.006)   # pencil drawer
    p.box((0, -D / 2 - 0.004, H - 0.1), (0.1, 0.012, 0.018), "brass", bevel=0.004)
    p.box((0, D / 2 - 0.06, 0.42), (W - 0.96, 0.025, 0.56), "oak_dark", bevel=0.006)   # modesty panel
    # a blotter on the top
    p.box((0.1, -0.02, H + 0.004), (0.6, 0.42, 0.008), "leather", bevel=0.003)
    return p


def chair():
    p = Part("chair")
    seat = 0.46
    for sx in (-1, 1):
        p.box((sx * 0.23, -0.2, seat / 2), (0.045, 0.045, seat), "oak", bevel=0.007)        # front legs
        p.box((sx * 0.23, 0.21, 0.5), (0.045, 0.05, 1.0), "oak", bevel=0.007)              # back legs = posts
        p.box((sx * 0.23, 0.0, 0.16), (0.03, 0.4, 0.03), "oak", bevel=0.005)               # side stretchers
    p.box((0, -0.2, 0.16), (0.42, 0.03, 0.03), "oak", bevel=0.005)
    p.box((0, 0.0, seat - 0.025), (0.52, 0.48, 0.05), "oak", bevel=0.01)                   # seat frame
    p.box((0, -0.01, seat + 0.025), (0.48, 0.44, 0.05), "leather", bevel=0.02)             # pad
    for z, h in ((0.88, 0.16), (0.66, 0.05)):
        p.box((0, 0.22, z), (0.43, 0.03, h), "oak", bevel=0.01)                            # back rails
    for x in (-0.1, 0.0, 0.1):
        p.box((x, 0.22, 0.77), (0.035, 0.022, 0.18), "oak", bevel=0.005)                   # spindles
    return p


# --- archive shelving -----------------------------------------------------------

def shelf_unit():
    p = Part("shelf_unit")
    W, H, D = 1.0, 1.8, 0.5
    rng = random.Random(7)
    for sx in (-1, 1):
        for sy in (-1, 1):
            p.box((sx * (W / 2 - 0.02), sy * (D / 2 - 0.02), H / 2), (0.035, 0.035, H), "paint", bevel=0.004)
        p.box((sx * (W / 2 - 0.02), 0, 0.9), (0.012, D - 0.06, 0.02), "paint", bevel=0.003)  # side brace
    levels = (0.08, 0.5, 0.92, 1.34, 1.76)
    for z in levels:
        p.box((0, 0, z), (W - 0.02, D - 0.02, 0.025), "paint", bevel=0.004)
    for z in levels[:-1]:
        x = -W / 2 + 0.06
        while x < W / 2 - 0.12:
            kind = rng.random()
            if kind < 0.45:
                w, hh, d = rng.uniform(0.26, 0.34), rng.uniform(0.2, 0.3), rng.uniform(0.3, 0.38)
                p.box((x + w / 2, rng.uniform(-0.03, 0.03), z + 0.012 + hh / 2), (w, d, hh), "card", bevel=0.008)
            elif kind < 0.85:
                n = rng.randint(3, 6)
                for k in range(n):
                    tilt = rng.uniform(-4, 4)
                    f = p.box((0, 0, 0), (0.07, 0.3, 0.3), "files", bevel=0.006)
                    p.move(f, Matrix.Translation((x + 0.04 + k * 0.075, 0, z + 0.165)) @ Matrix.Rotation(math.radians(tilt), 4, 'Y'))
                w = n * 0.075
            else:
                w = rng.uniform(0.12, 0.22)    # a gap
            x += w + 0.02
    return p


def _files(ctx):
    """Marbled box files: dark green and oxblood boards, a white label."""
    s = M.leather(ctx, seed=409)
    s.shade += 2.5
    v = ctx.uvm[:, 1]
    lab = (v % 0.3 > 0.18) & (v % 0.3 < 0.24)
    s.use_ramp(M.P["paint_green"], mask=~lab, shade=np.full(ctx.N, 3.4))
    s.use_ramp(M.P["cloth_white"], mask=lab, shade=np.full(ctx.N, 4.5))
    return s


# --- armour on a stand ----------------------------------------------------------

def armor_stand():
    from models import knight as KN
    p = Part("armor_stand")
    KN._torso(p)
    KN._head(p)
    for sx in (-1, 1):
        KN._pauldron(p, sx)
        KN._tasset(p, sx)
    # oak base with a moulded top, a post up into the faulds, a shoulder yoke
    p.box((0, 0, 0.09), (0.9, 0.62, 0.18), "oak", bevel=0.02)
    p.box((0, 0, 0.2), (0.78, 0.5, 0.05), "oak", bevel=0.012)
    p.box((0, 0, 0.58), (0.075, 0.075, 0.76), "oak", bevel=0.01)
    p.box((0, 0, 1.47), (0.56, 0.06, 0.05), "oak", bevel=0.008)
    p.box((0, 0.316, 0.11), (0.26, 0.008, 0.08), "brass", bevel=0.003)   # label on the front (+Y)
    return p


# --- the gallery's statue ---------------------------------------------------------

def _figure_blobs():
    """The upper body of a draped standing woman (peplophoros, 1.68 m in
    all), facing -Y: the hair waved back into a knot, the shoulders under
    the overfold, a mantle slung from the left shoulder, the right arm along
    the body gathering the cloth, the left forearm forward with an offering
    bowl. The skirt below the girdle is a lathed, fluted column (see
    sculpture())."""
    b = []
    # head: skull, face plane, jaw, nose, brow; hair waved back over a fillet
    b += [blob((0, 0.01, 1.575), (0.082, 0.095, 0.1)),
          blob((0, -0.045, 1.545), (0.064, 0.055, 0.075)),
          blob((0, -0.05, 1.49), (0.042, 0.04, 0.03)),
          blob((0, -0.088, 1.553), (0.011, 0.02, 0.03), rot=(-12, 0, 0), stiff=2.4),
          blob((0, -0.08, 1.592), (0.05, 0.016, 0.012), stiff=2.2)]
    for k in range(9):
        a = math.radians(-20 + k * 27.5)            # from the temples round the back
        b.append(blob((math.cos(a) * 0.075, 0.02 + math.sin(a) * 0.075, 1.6 + 0.02 * math.sin(a)),
                      (0.035, 0.035, 0.05), stiff=1.6))
    b += [blob((0, 0.015, 1.65), (0.085, 0.09, 0.05), stiff=1.6),
          blob((0, 0.105, 1.58), (0.05, 0.045, 0.06)),                        # the knot
          blob((0, 0.12, 1.53), (0.03, 0.03, 0.04))]
    # neck, shoulders, the chest, the overfold falling to the hips
    b += [blob((0, 0.0, 1.43), (0.05, 0.05, 0.08)),
          blob((0, 0.0, 1.32), (0.2, 0.11, 0.08)),
          blob((0.075, -0.075, 1.23), (0.065, 0.05, 0.065)), blob((-0.075, -0.075, 1.23), (0.065, 0.05, 0.065)),
          blob((0, 0.0, 1.17), (0.165, 0.11, 0.13)),
          blob((0, 0.0, 1.02), (0.185, 0.13, 0.15))]
    # the mantle's fall down the left side and its roll over the shoulder
    b += [blob((-0.2, 0.0, 1.3), (0.07, 0.08, 0.06), stiff=1.6),
          blob((-0.23, 0.0, 1.05), (0.06, 0.08, 0.22), stiff=1.5)]
    # the right arm hanging, its hand gathering the skirt
    b += sculpt.limb([(0.195, 0.0, 1.31), (0.235, 0.01, 1.07), (0.215, -0.05, 0.86)], [0.056, 0.046, 0.036])
    b.append(blob((0.21, -0.07, 0.82), (0.038, 0.034, 0.055)))
    # the left arm: forearm forward, the bowl in the hand
    b += sculpt.limb([(-0.195, 0.0, 1.31), (-0.235, 0.02, 1.08), (-0.17, -0.2, 1.02)], [0.056, 0.046, 0.036])
    b.append(blob((-0.16, -0.25, 1.02), (0.036, 0.04, 0.026)))
    b.append(blob((-0.16, -0.28, 1.045), (0.078, 0.078, 0.016), stiff=2.6))   # phiale
    return b


def _folds(seed, amp_top, amp_hem, z_top, z_hem):
    """ring_scale of a fluted skirt: irregular vertical folds, deeper toward
    the hem, a free knee pushing the front out at mid height."""
    rng = random.Random(seed)
    phases = [rng.uniform(0, math.tau) for _ in range(4)]

    def scale(i, j, segments=48, rings=None):
        a = math.tau * i / segments
        t = j / max(1, (rings or 1))
        f = (0.55 * math.sin(a * 13 + phases[0]) + 0.3 * math.sin(a * 7 + phases[1])
             + 0.15 * math.sin(a * 23 + phases[2]))
        return 1.0 + f * (amp_top + (amp_hem - amp_top) * t)
    return scale


def sculpture():
    me = sculpt.metaball_mesh(_figure_blobs(), resolution=0.01)
    sculpt.cut(me, [((0, 0, 0.84), (0, 0, -1))])
    me = sculpt.decimate(me, 5200)
    statue = Part("sculpture_figure")
    S = 2.0                                  # 1.68 m modelled, 3.36 m in the hall
    place = Matrix.Translation((0, 0, 1.1)) @ Matrix.Scale(S, 4)
    sculpt.into_part(statue, me, "marble", transform=place)
    # the skirt: a fluted column from the girdle to the hem, the overfold's
    # rippled hem over its top (rings counted from the top down)
    skirt = [(0.25, 0.0), (0.248, 0.05), (0.232, 0.25), (0.214, 0.5), (0.2, 0.7), (0.19, 0.88), (0.16, 0.95)]
    rings = len(skirt) - 1
    fold = _folds(5, 0.05, 0.12, 0.95, 0.0)
    faces = statue.lathe(skirt, "marble", segments=48, squash=(1.0, 0.76), cap_top=False,
                         ring_scale=lambda i, j: fold(i, rings - j, 48, rings))
    statue.move(faces, place)
    hem = [(0.186, 0.85), (0.2, 0.84), (0.205, 0.86), (0.19, 1.0), (0.17, 1.13)]
    ripple = _folds(9, 0.05, 0.1, 1.13, 0.84)
    faces = statue.lathe(hem, "marble", segments=40, squash=(1.0, 0.74), cap_bottom=False, cap_top=False,
                         ring_scale=lambda i, j: ripple(i, 4 - j, 40, 4))
    statue.move(faces, place)
    # the free knee pushing through the cloth, the feet under the hem
    knee = K.sphere(statue, (-0.08, -0.14, 0.5), 0.07, "marble", squash=(1.0, 0.6), zscale=1.5)
    statue.move(knee, place)
    for x, y in ((0.07, -0.19), (-0.09, -0.2)):
        foot = statue.box((x, y, 0.03), (0.08, 0.15, 0.06), "marble", bevel=0.02)
        statue.move(foot, place)
    # the statue's own marble base on the pedestal
    statue.box((0, 0, 1.03), (0.95, 0.8, 0.14), "marble", bevel=0.02)
    base = Part("sculpture")
    X = Y = 2.2
    hx, hy = X / 2 - 0.12, Y / 2 - 0.12
    path = [(-hx, -hy), (-hx, hy), (hx, hy), (hx, -hy)]
    plan_sweep(base, [(0.0, 0.12), (0.12, 0.12), (0.14, 0.1), (0.14, 0.08)], path, "verde")
    plan_sweep(base, [(0.14, 0.08), (0.2, 0.08), (0.22, 0.05), (0.26, 0.03), (0.28, 0.0), (0.82, 0.0),
                      (0.85, 0.03), (0.88, 0.04), (0.9, 0.08), (0.94, 0.1), (0.96, 0.08)], path, "limestone")
    plan_sweep(base, [(0.96, 0.08), (0.96, 0.0)], path, "verde")
    top = base.poly([(-hx - 0.08, -hy - 0.08, 0.96), (hx + 0.08, -hy - 0.08, 0.96), (hx + 0.08, hy + 0.08, 0.96),
                     (-hx - 0.08, hy + 0.08, 0.96)], "verde")[0]
    top.normal_update()
    if top.normal.z < 0:
        top.normal_flip()
    for sy in (-1, 1):
        base.box((0, sy * (hy + 0.012), 0.55), (1.4, 0.03, 0.42), "limestone", bevel=0.02)
    for sx in (-1, 1):
        base.box((sx * (hx + 0.012), 0, 0.55), (0.03, 1.4, 0.42), "limestone", bevel=0.02)
    base.box((0, -hy - 0.034, 0.55), (0.62, 0.012, 0.2), "brass", bevel=0.004)
    return [base, statue]


# --- display cases ----------------------------------------------------------------

def _glass_box(g, x0, x1, y0, y1, z0, z1, top=True):
    from artlib.archkit import facing
    facing(g, [(x0, y0, z0), (x1, y0, z0), (x1, y0, z1), (x0, y0, z1)], "glass", (0, -1, 0))
    facing(g, [(x1, y1, z0), (x0, y1, z0), (x0, y1, z1), (x1, y1, z1)], "glass", (0, 1, 0))
    facing(g, [(x0, y1, z0), (x0, y0, z0), (x0, y0, z1), (x0, y1, z1)], "glass", (-1, 0, 0))
    facing(g, [(x1, y0, z0), (x1, y1, z0), (x1, y1, z1), (x1, y0, z1)], "glass", (1, 0, 0))
    if top:
        facing(g, [(x0, y0, z1), (x1, y0, z1), (x1, y1, z1), (x0, y1, z1)], "glass", (0, 0, 1))


def _brass_frame(p, x0, x1, y0, y1, z0, z1, t=0.03):
    for x in (x0, x1):
        for y in (y0, y1):
            p.box((x, y, (z0 + z1) / 2), (t, t, z1 - z0), "brass", bevel=0.005)
    for z in (z0 + t / 2, z1 - t / 2):
        p.box(((x0 + x1) / 2, y0, z), (x1 - x0, t, t), "brass", bevel=0.005)
        p.box(((x0 + x1) / 2, y1, z), (x1 - x0, t, t), "brass", bevel=0.005)
        p.box((x0, (y0 + y1) / 2, z), (t, y1 - y0, t), "brass", bevel=0.005)
        p.box((x1, (y0 + y1) / 2, z), (t, y1 - y0, t), "brass", bevel=0.005)


def case_tall():
    p = Part("case_tall")
    g = Part("case_tall_glass")
    W = 1.2
    h = W / 2
    TOP = 0.95
    p.box((0, 0, 0.05), (W - 0.1, W - 0.1, 0.1), "walnut", bevel=0.008)
    p.box((0, 0, 0.5), (W - 0.04, W - 0.04, 0.8), "walnut", bevel=0.014)
    p.box((0, 0, TOP - 0.03), (W + 0.04, W + 0.04, 0.06), "walnut", bevel=0.016)
    for a in range(4):
        rot = Matrix.Rotation(math.radians(90 * a), 4, 'Z')
        f = p.box((0, -h + 0.008, 0.48), (W - 0.36, 0.02, 0.56), "walnut", bevel=0.02)       # raised panel
        p.move(f, rot)
        f = p.box((0, -h - 0.004, 0.86), (0.36, 0.01, 0.05), "brass", bevel=0.003)          # label
        p.move(f, rot)
    p.box((0, 0, TOP + 0.015), (W - 0.12, W - 0.12, 0.03), "velvet", bevel=0.008)
    p.box((0, 0, TOP + 0.06), (0.32, 0.32, 0.06), "velvet", bevel=0.012)                    # cushion
    z0, z1 = TOP, 1.76
    _brass_frame(p, -h + 0.04, h - 0.04, -h + 0.04, h - 0.04, z0, z1)
    p.box((0, 0, z1 + 0.02), (W - 0.02, W - 0.02, 0.04), "walnut", bevel=0.01)
    p.box((0, -h + 0.1, z1 - 0.02), (W - 0.26, 0.03, 0.012), "lamp", bevel=0.002)          # lamp strip
    e = 0.006
    _glass_box(g, -h + 0.04 + e, h - 0.04 - e, -h + 0.04 + e, h - 0.04 - e, z0 + 0.03, z1 - 0.03, top=False)
    return [p, g]


def case_table():
    p = Part("case_table")
    g = Part("case_table_glass")
    W, D = 2.0, 1.4
    hw, hd = W / 2, D / 2
    for sx in (-1, 1):
        for sy in (-1, 1):
            p.lathe([(0.04, 0.0), (0.05, 0.03), (0.035, 0.08), (0.03, 0.4), (0.042, 0.62), (0.045, 0.7)],
                    "walnut", segments=10, center=(sx * (hw - 0.1), sy * (hd - 0.1), 0.0))
    for sy in (-1, 1):
        p.box((0, sy * (hd - 0.1), 0.18), (W - 0.24, 0.04, 0.04), "walnut", bevel=0.006)      # stretchers
    p.box((0, 0, 0.18), (0.04, D - 0.24, 0.04), "walnut", bevel=0.006)
    p.box((0, 0, 0.82), (W, D, 0.24), "walnut", bevel=0.014)                             # apron box
    for sy in (-1, 1):
        for x in (-0.5, 0.5):
            p.box((x, sy * (hd + 0.006), 0.82), (0.86, 0.012, 0.15), "walnut", bevel=0.012)
    p.box((0, 0, 0.955), (W + 0.04, D + 0.04, 0.03), "walnut", bevel=0.01)
    p.box((0, 0, 0.985), (W - 0.1, D - 0.1, 0.03), "velvet", bevel=0.008)
    z0, z1 = 0.97, 1.38
    _brass_frame(p, -hw + 0.04, hw - 0.04, -hd + 0.04, hd - 0.04, z0, z1, t=0.025)
    p.box((0, 0, z1 + 0.012), (W - 0.04, D - 0.04, 0.024), "walnut", bevel=0.008)
    e = 0.006
    _glass_box(g, -hw + 0.04 + e, hw - 0.04 - e, -hd + 0.04 + e, hd - 0.04 - e, z0 + 0.025, z1 - 0.02, top=False)
    return [p, g]


# --- a blank plaque ------------------------------------------------------------------

def plaque_brass():
    p = Part("plaque_brass")
    p.box((0, 0, 0.15), (0.5, 0.012, 0.3), "brass", bevel=0.006)
    for sx in (-1, 1):
        p.box((sx * 0.235, -0.008, 0.15), (0.016, 0.006, 0.28), "brass", bevel=0.003)
    for sz in (0.012, 0.288):
        p.box((0, -0.008, sz), (0.48, 0.006, 0.016), "brass", bevel=0.003)
    for sx in (-1, 1):
        for sz in (0.04, 0.26):
            screw = p.lathe([(0.0, 0.0), (0.01, 0.0), (0.01, 0.003), (0.0, 0.005)], "brass", segments=8)
            p.move(screw, Matrix.Translation((sx * 0.215, -0.006, sz)) @ Matrix.Rotation(math.radians(90), 4, 'X'))
    return p


def _plain_brass(ctx):
    s = M.brass(ctx, seed=419)
    s.shade += 0.6
    return s


def build():
    wood = {"pine": _stencil, "oak": M.wood_oak, "iron": M.iron, "rope": lambda c: M.cloth(c, "excelsior", 4.0, 421)}
    furniture = {"oak": M.wood_oak, "oak_dark": M.wood_dark, "brass": M.brass, "leather": M.leather}
    shelving = {"paint": lambda c: M.paint(c, "paint_olive", 4.4, chip=0.6, under="iron"), "card": M.cardboard,
                "files": _files}
    armour = {"steel": lambda c: M.steel(c, seed=313, center=8.0, dent=0.35, rust=0.6, polish=0.34, scratch=0.2),
              "mail": M.mail, "leather": M.leather, "brass": M.brass, "void": M.iron, "oak": M.wood_oak}
    statue = {"marble": M.marble_statuary, "verde": M.marble_dark, "limestone": A.limestone,
              "brass": _plain_brass}
    case = {"walnut": M.wood_dark, "brass": M.brass, "velvet": M.velvet, "lamp": M.lamp_warm}
    return [
        kit("crate", [crate()], wood, ppm=96, ground=0.0, ao_dist=0.3),
        kit("desk", [desk()], furniture, ppm=128, ground=0.0, ao_dist=0.3),
        kit("chair", [chair()], furniture, ppm=128, ground=0.0, ao_dist=0.25),
        kit("shelf_unit", [shelf_unit()], shelving, ppm=96, ground=0.0, ao_dist=0.25),
        kit("armor_stand", [armor_stand()], armour, ppm=192, ground=0.0, ao_dist=0.14, ao_stride=2, built_final=True),
        kit("sculpture", sculpture(), statue, ppm=80, ground=0.0, ao_dist=0.35, organic=("sculpture_figure",)),
        kit("case_tall", case_tall(), case, kinds={"glass": "glass"}, ppm=128, ground=0.0, ao_dist=0.3),
        kit("case_table", case_table(), case, kinds={"glass": "glass"}, ppm=96, ground=0.0, ao_dist=0.3),
        kit("plaque_brass", [plaque_brass()], {"brass": _plain_brass}, ppm=256, ground=None, ao_dist=0.05, wall=True),
    ]
