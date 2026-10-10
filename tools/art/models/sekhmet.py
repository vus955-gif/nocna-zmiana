"""Sekhmet, the lion-headed goddess: a seated black granodiorite statue (as
the long rows from the temple of Mut that line the British Museum's
gallery), 2.1 m tall with her sun disc. A woman's body in a sheath dress,
hands on the knees, an ankh in the left; a lioness head in a heavy striated
mane, a sun disc with a uraeus on a low modius. Block throne with a column
of text down each side of its front, on a low base.

Kit convention: origin = centre of the base, front = Godot -Z (Blender +Y,
built final), 160 px/m. Parts: sekhmet (base, throne, body) and head
(pivot at the neck, (0, 0, 1.50) Blender = Godot (0, 1.50, 0)): turn it so
a row of them can all look at the guard. Meant to repeat in a row of 6-8.
"""
import math

import numpy as np
from mathutils import Matrix, Vector

from artlib import egypt as E
from artlib import egypt_paint as EP
from artlib import kit as K
from artlib import sculpt
from artlib.archkit import cull_floor, kit
from artlib.geo import Part
from artlib.materials import P
from artlib.sculpt import blob, limb

S = 1.2
BASE = 0.1
NECK = (0.0, 0.0, 1.17)


def to_m(p):
    return (p[0] * S, p[1] * S, p[2] * S + BASE)


def _body_blobs():
    b = []
    for sx in (-1, 1):
        hip, knee, ankle = (sx * 0.085, 0.0, 0.6), (sx * 0.09, 0.42, 0.6), (sx * 0.085, 0.45, 0.0)
        b += limb([hip, (sx * 0.088, 0.2, 0.6), knee], [0.095, 0.085, 0.07], spacing=0.7)
        b += limb([knee, (sx * 0.087, 0.44, 0.3), ankle], [0.07, 0.065, 0.05], spacing=0.7)
        b.append(blob((sx * 0.085, 0.55, 0.018), (0.04, 0.1, 0.03)))                      # feet
        b += limb([(sx * 0.17, -0.01, 1.08), (sx * 0.19, 0.03, 0.82), (sx * 0.15, 0.3, 0.66)], [0.058, 0.047, 0.038],
                  spacing=0.7)
        b.append(blob((sx * 0.13, 0.4, 0.645), (0.032, 0.07, 0.018)))                      # hands on the knees
        b.append(blob((sx * 0.07, 0.07, 0.93), (0.055, 0.035, 0.045)))                     # breasts
        b.append(blob((sx * 0.17, -0.01, 1.08), (0.05, 0.05, 0.045)))                      # shoulders
    b += [blob((0.0, -0.03, 0.6), (0.17, 0.13, 0.08)),                                      # seat of the hips
          blob((0.0, 0.0, 0.76), (0.12, 0.08, 0.1)),                                        # waist
          blob((0.0, 0.0, 0.95), (0.15, 0.09, 0.12)),                                       # chest
          blob((0.0, -0.01, 1.1), (0.08, 0.06, 0.06))]                                      # neck base
    # the sheath dress hangs between the shins
    b.append(blob((0.0, 0.43, 0.32), (0.11, 0.04, 0.28)))
    return b


def _head_blobs():
    b = [blob((0.0, 0.0, 1.32), (0.085, 0.09, 0.08)),
         blob((0.0, 0.1, 1.27), (0.055, 0.06, 0.045)),
         blob((0.0, 0.15, 1.285), (0.025, 0.02, 0.018)),
         blob((0.0, 0.09, 1.23), (0.04, 0.05, 0.025)),
         blob((0.0, 0.075, 1.335), (0.06, 0.03, 0.02)),
         blob((0.0, -0.03, 1.27), (0.12, 0.11, 0.14), stiff=1.8),                          # mane
         blob((0.0, 0.0, 1.17), (0.06, 0.06, 0.06))]                                        # neck
    for sx in (-1, 1):
        b += [blob((sx * 0.06, 0.06, 1.27), (0.05, 0.05, 0.05)),
              blob((sx * 0.033, 0.11, 1.31), (0.016, 0.012, 0.01), neg=True, stiff=1.5),
              blob((sx * 0.06, -0.01, 1.4), (0.025, 0.014, 0.03)),
              blob((sx * 0.095, 0.03, 1.1), (0.05, 0.035, 0.1))]                           # mane lappets
    return b


def body():
    p = Part("sekhmet")
    me = sculpt.metaball_mesh(_body_blobs(), resolution=0.0055)
    sculpt.cut(me, [((0, 0, 0.0), (0, 0, -1))])
    me = sculpt.decimate(me, 2400)
    sculpt.into_part(p, me, "stone", transform=Matrix.Translation((0, 0, BASE)) @ Matrix.Scale(S, 4))
    # throne: block seat with a low back, on the base
    p.box((0.0, -0.06 * S, BASE + 0.26 * S), (0.42 * S, 0.5 * S, 0.52 * S), "throne", bevel=0.01)
    p.box((0.0, -0.27 * S, BASE + 0.72 * S), (0.42 * S, 0.08 * S, 0.4 * S), "throne", bevel=0.01)
    # the ankh in the left hand, upright on the knee
    a = to_m((-0.13, 0.43, 0.66))
    K.seg(p, a, (a[0], a[1], a[2] + 0.1), [(0.012, 0.0), (0.012, 1.0)], "stone", segments=6)
    p.box((a[0], a[1], a[2] + 0.1), (0.07, 0.016, 0.016), "stone", bevel=0.003)
    loop = p.lathe([(0.026, -0.006), (0.034, 0.0), (0.026, 0.006)], "stone", segments=10, cap_bottom=False, cap_top=False)
    p.move(loop, Matrix.Translation((a[0], a[1], a[2] + 0.145)) @ Matrix.Rotation(math.radians(90), 4, 'X'))
    p.box((0.0, 0.05, BASE / 2), (0.62, 1.05, BASE), "base", bevel=0.01)
    cull_floor([p])
    return p


def head():
    p = Part("head", origin=to_m(NECK), parent="sekhmet")
    me = sculpt.metaball_mesh(_head_blobs(), resolution=0.0045)
    sculpt.cut(me, [(( 0, 0, 1.12), (0, 0, -1))])
    me = sculpt.decimate(me, 1600)
    sculpt.into_part(p, me, "mane", transform=Matrix.Translation((0, 0, BASE)) @ Matrix.Scale(S, 4))
    # modius, sun disc and uraeus
    m = Matrix.Translation((0, 0, BASE)) @ Matrix.Scale(S, 4)
    f = p.lathe([(0.055, 1.395), (0.06, 1.43), (0.05, 1.44)], "disc", segments=12, center=(0.0, -0.01, 0.0))
    p.move(f, m)
    disc = p.lathe([(0.0, -0.014), (0.13, -0.012), (0.135, 0.0), (0.13, 0.012), (0.0, 0.014)], "disc", segments=18)
    p.move(disc, m @ Matrix.Translation((0.0, -0.02, 1.565)) @ Matrix.Rotation(math.radians(90), 4, 'X'))
    cob = p.lathe([(0.0, -0.004), (0.022, -0.003), (0.025, 0.0), (0.022, 0.004), (0.0, 0.005)], "disc", segments=8)
    p.move(cob, m @ Matrix.Translation((0.0, 0.005, 1.47)) @ Matrix.Rotation(math.radians(85), 4, 'X'))
    return p


# --------------------------------------------------------------------------

def stone(ctx, seed=901):
    s = E.granite(ctx, "black", seed, polish=0.2, grain=0.45, center=4.3)
    s.shade += np.clip(ctx.curv, 0, 1) * 1.5 - np.clip(-ctx.curv, 0, 1) * 1.3
    return s


def mane(ctx, seed=903):
    """Granodiorite lioness head: the mane carved in fine wavy striations,
    the face smooth, amber traces in the eyes."""
    s = stone(ctx, seed)
    x, y, z = ctx.p[:, 0], ctx.p[:, 1], ctx.p[:, 2]
    c = np.array(to_m((0.0, 0.02, 1.28)))
    d = np.sqrt((x - c[0]) ** 2 + (z - c[2]) ** 2)
    face = (y > c[1] + 0.06) & (d < 0.1)
    strand = ~face & (np.mod(np.arctan2(z - c[2], x - c[0]) * 26 + ctx.fbm(6.0, 2, seed) * 2.0, 2.0) < 0.6)
    s.shade[strand] -= 1.2
    s.height = s.height - strand * 0.0015
    for sx in (-1, 1):
        e = np.array(to_m((sx * 0.033, 0.11, 1.31)))
        eye = np.sqrt((x - e[0]) ** 2 + (z - e[2]) ** 2) < 0.012
        s.use_ramp(P["eg_yellow"], mask=eye & (y > e[1] - 0.04), shade=np.full(ctx.N, 3.0))
    return s


def disc_paint(ctx, seed=905):
    s = stone(ctx, seed)
    codes = np.full(ctx.N, EP.INK["red"], np.int16)
    return E.paint_over(ctx, s, codes, np.zeros(ctx.N, np.int16), seed + 1, flake=0.6)


def throne_paint(ctx, seed=907):
    """Throne: polished granodiorite, a column of signs down each side of its
    front edge (the goddess's titles)."""
    s = stone(ctx, seed)
    side = np.abs(ctx.n[:, 0]) > 0.9
    if side.any():
        col = EP.text_columns(1, 6, seed, col_w=12, cell=10, gap=1, divider=False)
        # laid out from 3D (the part is re-unwrapped): u runs toward the
        # viewer's right on each side, the column near the front edge
        u = ctx.p[:, 1] * np.sign(ctx.n[:, 0])
        u0 = np.where(ctx.n[:, 0] > 0, 0.14, -0.215)
        c, r = E.sample(col, u[side] - u0[side], ctx.p[side, 2], ctx.texel, v0=BASE + 0.1)
        codes = np.full(ctx.N, -1, np.int16)
        rims = np.zeros(ctx.N, np.int16)
        codes[side] = c
        rims[side] = r
        codes = np.where(codes > 0, EP.INK["yellow"], codes).astype(np.int16)
        s = E.paint_over(ctx, s, codes, rims, seed + 1, flake=0.6, relief=-0.002)
    return s


def build():
    fns = {"stone": stone, "mane": mane, "disc": disc_paint, "throne": throne_paint,
           "base": lambda c: E.granite(c, "black", 909, polish=0.4, grain=0.6, center=4.0)}
    face = to_m((0.0, 0.1, 1.29))
    return kit("sekhmet", [body(), head()], fns, ppm=160, organic=("sekhmet", "head"), built_final=True,
               ao_dist=0.25, ao_stride=2, preview_closeup=(face, 0.32))
