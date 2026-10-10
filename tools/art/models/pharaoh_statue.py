"""The avenue of colossi in the Great Gallery: a striding king, 6.9 m from
the floor to the top of the nemes, in black granodiorite polished to a
shine, left foot forward, fists at the sides holding mekes cases, a
pleated kilt with a gold-traced apron, a broad collar, the nemes striped in
gold and blue, a uraeus and a plaited beard; stone left between the legs
and a back pillar with a column of text, as on the real statues; a granite
base with an inscribed band. Readable as one dark silhouette against the
moonlit sandstone; the warm spotlights find the gold.

Kit convention: origin = centre of the base, front = Godot -Z (Blender +Y,
built final). Parts: pharaoh_statue (base, 1.7 x 0.5 x 2.6 m) and
pharaoh_figure (the king on it). 112 px/m. A 1.8 m guard comes up to his
knee.
"""
import math

import numpy as np
from mathutils import Matrix, Vector

from artlib import egypt as E
from artlib import egypt_paint as EP
from artlib import face as F
from artlib import kit as K
from artlib import sculpt
from artlib.archkit import cull_floor, kit
from artlib.geo import Part
from artlib.sculpt import blob, limb

S = 3.5          # human units (a 1.8 m man) -> metres
BASE = 0.5


FACE_C = Vector((0.0, 0.0, 1.669))       # unit face (artlib/face.py) placement, human units
FACE_S = 0.221


def to_m(p):
    return (p[0] * S, p[1] * S, p[2] * S + BASE)


def to_unit(co):
    q = Vector(((co[0]) / S, co[1] / S, (co[2] - BASE) / S))
    q = (q - FACE_C) / FACE_S
    return q.x, q.y, q.z


def _blobs():
    b = []
    for sx, fy, ky, ay in ((-1, 0.0, 0.11, 0.2), (1, 0.0, -0.06, -0.12)):
        hip = (sx * 0.09, 0.0, 0.92)
        knee = (sx * 0.095, ky, 0.5)
        ankle = (sx * 0.1, ay, 0.085)
        b += limb([hip, ((hip[0] + knee[0]) / 2, ky * 0.5, 0.72), knee], [0.1, 0.083, 0.064], spacing=0.7)
        b += limb([knee, (sx * 0.1, (ky + ay) / 2 - 0.015, 0.3), ankle], [0.064, 0.068, 0.042], spacing=0.7)
        b.append(blob((sx * 0.1, ky + 0.02, 0.5), (0.04, 0.03, 0.045)))                    # kneecap
        b.append(blob((sx * 0.1, ay + 0.06, 0.035), (0.04, 0.12, 0.035)))                  # foot
        for k, tx in enumerate((-0.025, -0.008, 0.008, 0.025)):
            b.append(blob((sx * 0.1 + tx, ay + 0.19, 0.018), (0.009, 0.025, 0.014)))
    b += [blob((0.0, 0.0, 0.95), (0.17, 0.11, 0.1)),                                        # pelvis
          blob((0.0, 0.01, 1.12), (0.14, 0.1, 0.1)),                                        # abdomen
          blob((0.0, 0.0, 1.3), (0.19, 0.12, 0.14)),                                        # ribcage
          blob((0.0, -0.07, 1.3), (0.16, 0.06, 0.15)),                                      # back
          blob((0.0, -0.02, 1.46), (0.11, 0.07, 0.05))]                                     # trapezius
    for sx in (-1, 1):
        b.append(blob((sx * 0.08, 0.08, 1.35), (0.08, 0.04, 0.06)))
        b.append(blob((sx * 0.19, -0.01, 1.44), (0.085, 0.08, 0.08)))
        b += limb([(sx * 0.19, 0.0, 1.45), (sx * 0.21, 0.0, 1.13), (sx * 0.2, 0.03, 0.87)], [0.072, 0.056, 0.043],
                  spacing=0.7)
        b.append(blob((sx * 0.2, 0.04, 0.82), (0.036, 0.045, 0.05)))                       # fist
    b += limb([(0.0, -0.01, 1.44), (0.0, 0.0, 1.6)], [0.055, 0.052], spacing=0.7)          # neck
    b.append(blob((0.0, -0.01, 1.68), (0.075, 0.08, 0.085)))                                 # skull filler
    return b


def figure():
    p = Part("pharaoh_figure")
    me = sculpt.metaball_mesh(_blobs(), resolution=0.0065)
    sculpt.cut(me, [((0, 0, 0.0), (0, 0, -1))])
    me = sculpt.decimate(me, 4200)
    sculpt.into_part(p, me, "skin")
    head = F.head_mesh({"lips": 1.05})
    head = sculpt.decimate(head, 1800)
    sculpt.into_part(p, head, "skin", transform=Matrix.Translation(FACE_C) @ Matrix.Scale(FACE_S, 4))
    # kilt: a pleated wrap from the belt to above the knees, the apron in front
    rings = 4
    p.lathe([(0.205, 0.64), (0.19, 0.78), (0.17, 0.92), (0.158, 1.0), (0.155, 1.04)], "kilt", segments=32,
            center=(0.0, 0.0, 0.0), squash=(1.0, 0.72), cap_bottom=False, cap_top=False, smooth=False,
            ring_scale=lambda i, j: 1.0 + (0.025 if i % 2 == 0 else 0.0))
    p.box((0.0, 0.15, 0.82), (0.11, 0.02, 0.36), "apron", bevel=0.004)
    p.lathe([(0.158, 1.0), (0.162, 1.01), (0.162, 1.05), (0.155, 1.06)], "belt", segments=32, squash=(1.0, 0.72),
            cap_bottom=False, cap_top=False)
    # stone left between the legs and behind them (to the back pillar)
    p.box((0.0, -0.02, 0.32), (0.07, 0.3, 0.64), "skin", bevel=0.004)
    p.box((0.0, -0.13, 0.8), (0.24, 0.08, 1.6), "pillar", bevel=0.005)
    # mekes cases in the fists
    for sx in (-1, 1):
        K.seg(p, (sx * 0.2, 0.0, 0.8), (sx * 0.2, 0.1, 0.8), [(0.016, 0.0), (0.016, 1.0)], "gold", segments=8)
    # broad collar
    faces = p.lathe([(0.2, 1.38), (0.16, 1.44), (0.11, 1.49), (0.065, 1.53)], "collar", segments=24,
                    center=(0.0, -0.01, 0.0), squash=(0.95, 0.62), cap_bottom=False, cap_top=False)
    K.keep(p, faces, lambda c: c.y > -0.03)
    # nemes: cap, brow band, wings, lappets
    p.lathe([(0.101, 1.69), (0.1, 1.73), (0.088, 1.775), (0.055, 1.805), (0.02, 1.815)], "nemes", segments=20,
            center=(0.0, -0.005, 0.0), squash=(1.0, 1.08), cap_bottom=False)
    for sx in (-1, 1):
        tf, tb = Vector((sx * 0.092, 0.06, 1.71)), Vector((sx * 0.092, -0.08, 1.71))
        bf, bb = Vector((sx * 0.2, 0.03, 1.47)), Vector((sx * 0.18, -0.1, 1.49))
        out = Vector((sx * 0.012, 0.0, 0.0))
        vs = [p.bm.verts.new(c) for c in (tf, tb, bb, bf)]
        vo = [p.bm.verts.new(c + out) for c in (tf, tb, bb, bf)]
        centre = (tf + bb) * 0.5 + out * 0.5
        for q in ((vo[0], vo[1], vo[2], vo[3]), (vs[3], vs[2], vs[1], vs[0]), (vs[0], vs[3], vo[3], vo[0]),
                  (vs[1], vs[0], vo[0], vo[1]), (vs[2], vs[1], vo[1], vo[2]), (vs[3], vs[2], vo[2], vo[3])):
            f = p._face(list(q), "nemes", smooth=False)
            f.normal_update()
            if f.normal.dot(f.calc_center_median() - centre) < 0:
                f.normal_flip()
        a, b2 = Vector((sx * 0.1, 0.045, 1.63)), Vector((sx * 0.125, 0.11, 1.38))
        d = b2 - a
        q = d.normalized().to_track_quat('Z', 'Y')
        lap = p.box((0.0, 0.0, d.length / 2), (0.06, 0.014, d.length), "nemes", bevel=0.002)
        p.move(lap, Matrix.Translation(a) @ q.to_matrix().to_4x4())
    # uraeus and beard
    cob = p.lathe([(0.0, -0.004), (0.022, -0.003), (0.024, 0.0), (0.022, 0.004), (0.0, 0.005)], "gold", segments=10)
    p.move(cob, Matrix.Translation((0.0, 0.108, 1.735)) @ Matrix.Rotation(math.radians(80), 4, 'X'))
    K.seg(p, (0.0, 0.088, 1.575), (0.0, 0.1, 1.49), [(0.017, 0.0), (0.019, 0.5), (0.018, 1.0)], "beard",
          segments=6, squash=(1.0, 0.65), smooth=False)
    p.move(list(p.bm.faces), Matrix.Translation((0.0, 0.0, BASE)) @ Matrix.Scale(S, 4))
    return p


def base():
    p = Part("pharaoh_statue")
    p.box((0.0, 0.08, BASE / 2), (1.7, 2.6, BASE), "base", bevel=0.03)
    cull_floor([p])
    return p


# --------------------------------------------------------------------------

def skin(ctx, seed=801):
    """Black granodiorite, polished; the eyes painted in (white, a black
    iris, kohl and the cosmetic line), the brows carved and darkened."""
    s = E.granite(ctx, "black", seed, polish=0.2, grain=0.5, center=4.3)
    s.shade += np.clip(ctx.curv, 0, 1) * 1.4 - np.clip(-ctx.curv, 0, 1) * 1.2
    codes = np.zeros(ctx.N, np.int16)
    near = np.nonzero((ctx.p[:, 2] > to_m((0, 0, 1.6))[2]) & (ctx.p[:, 2] < to_m((0, 0, 1.75))[2])
                      & (ctx.p[:, 1] > 0.15))[0]
    for i in near:
        ux, uy, uz = to_unit(ctx.p[i])
        if uy < 0.15:
            continue
        ax = abs(ux)
        if F.in_eye(ux, uz, 1.0):
            codes[i] = EP.INK["black"] if (ax - 0.15) ** 2 + ((uz - 0.05) * 1.6) ** 2 < 0.03 ** 2 else EP.INK["white"]
        elif F.in_eye(ux, uz, 1.3) or (0.2 < ax < 0.3 and abs(uz - (0.058 + (ax - 0.2) * 0.12)) < 0.008):
            codes[i] = EP.INK["black"]
    return E.paint_over(ctx, s, codes, np.zeros(ctx.N, np.int16), seed + 1, flake=0.15, wear=0.2)


def kilt(ctx, seed=803):
    s = E.granite(ctx, "black", seed, polish=0.2, grain=0.5, center=4.3)
    th = np.arctan2(ctx.p[:, 1] / 0.72, ctx.p[:, 0])
    groove = np.mod(th * 32 / math.tau, 1.0) < 0.22
    s.shade[groove] -= 1.4
    s.height = s.height - groove * 0.004
    codes = np.where(~groove & (ctx.fbm(4.0, 3, seed) > 0.2), EP.INK["gold"], 0).astype(np.int16)
    return E.paint_over(ctx, s, codes, np.zeros(ctx.N, np.int16), seed + 1, flake=0.45)


def apron(ctx, seed=805):
    s = E.granite(ctx, "black", seed, polish=0.2, grain=0.5, center=4.3)
    ix = np.floor(ctx.p[:, 0] / ctx.texel).astype(np.int64)
    iy = np.floor(ctx.p[:, 2] / ctx.texel).astype(np.int64)
    codes = np.where(np.mod(iy, 6) < 3, EP.INK["gold"], EP.INK["blue"]).astype(np.int16)
    codes[np.mod(ix, 9) == 0] = EP.INK["red"]
    return E.paint_over(ctx, s, codes, np.zeros(ctx.N, np.int16), seed + 1, flake=0.3)


def belt(ctx, seed=807):
    s = E.gold_leaf(ctx, seed)
    iy = np.floor(ctx.p[:, 2] / ctx.texel).astype(np.int64)
    th = np.arctan2(ctx.p[:, 1] / 0.72, ctx.p[:, 0])
    ix = np.floor(th * 0.55 / ctx.texel).astype(np.int64)
    zig = np.abs(np.mod(ix, 8) - 4) == np.mod(iy, 4)
    from artlib.materials import P
    s.use_ramp(P["eg_blue"], mask=zig, shade=np.full(ctx.N, 3.4))
    s.metal = np.where(zig, 0.0, s.metal)
    return s


def collar(ctx, seed=809):
    s = E.granite(ctx, "black", seed, polish=0.2, grain=0.5, center=4.3)
    x, y = ctx.p[:, 0], ctx.p[:, 1] + 0.035
    r = np.sqrt((x / 0.95) ** 2 + (y / 0.62) ** 2)
    t = np.clip((r - 0.065 * S) / ((0.2 - 0.065) * S), 0.0, 1.0)
    rows = np.floor(t * 6).astype(np.int64)
    cyc = np.array([EP.INK["gold"], EP.INK["green"], EP.INK["red"], EP.INK["blue"], EP.INK["gold"], EP.INK["green"]],
                   np.int16)
    codes = cyc[np.clip(rows, 0, 5)]
    return E.paint_over(ctx, s, codes, np.zeros(ctx.N, np.int16), seed + 1, flake=0.4, relief=-0.003)


def nemes(ctx, seed=811):
    s = E.granite(ctx, "black", seed, polish=0.2, grain=0.5, center=4.3)
    z = ctx.p[:, 2]
    st = np.floor(z / 0.06).astype(np.int64)
    codes = np.where(np.mod(st, 2) == 0, EP.INK["gold"], EP.INK["blue"]).astype(np.int16)
    return E.paint_over(ctx, s, codes, np.zeros(ctx.N, np.int16), seed + 1, flake=0.45)


def beard(ctx, seed=813):
    s = E.granite(ctx, "black", seed, polish=0.2, grain=0.5, center=4.3)
    plait = np.mod(ctx.p[:, 2], 0.045) < 0.012
    s.shade[plait] -= 1.4
    s.height = s.height - plait * 0.003
    return s


def pillar(ctx, seed=815):
    s = E.granite(ctx, "black", seed, polish=0.25, grain=0.5, center=4.3)
    back = ctx.n[:, 1] < -0.9
    if back.any():
        col = EP.text_columns(1, 20, seed, col_w=14, cell=10, gap=1, divider=False, cartouches=0.12)
        col = np.repeat(np.repeat(col, 3, 0), 3, 1)
        c, r = E.sample(col, ctx.p[back, 0], ctx.p[back, 2], ctx.texel, u0=-0.24, v0=BASE + 0.3)
        codes = np.full(ctx.N, -1, np.int16)
        rims = np.zeros(ctx.N, np.int16)
        codes[back] = c
        rims[back] = r
        s = E.paint_over(ctx, s, codes, rims, seed + 1, flake=0.35, relief=-0.004)
    return s


_BAND = {}


def base_paint(ctx, seed=817):
    """Base: dressed red granite, a line of large signs round its sides with
    the king's cartouches in front."""
    s = E.granite(ctx, "red", seed, polish=0.35)
    z = ctx.p[:, 2]
    vertical = np.abs(ctx.n[:, 2]) < 0.5
    m = vertical & (z > 0.08) & (z < BASE - 0.08)
    if m.any():
        if "b" not in _BAND:
            import random
            rng = random.Random(seed)
            w = int(round(8.6 / ctx.texel))
            h = int(round((BASE - 0.16) / ctx.texel))
            c = np.zeros((h, w), np.int16)
            line = np.repeat(np.repeat(EP.text_line(w // 2, seed), 2, 0), 2, 1)[:, :w]
            c[(h - 20) // 2:(h - 20) // 2 + 20, :line.shape[1]] = line
            for cx in (w // 2 - 60, w // 2 + 30):
                cart = np.repeat(np.repeat(EP.cartouche(rng, 12, h // 2), 2, 0), 2, 1)[:h]
                y0 = (h - cart.shape[0]) // 2
                c[y0:y0 + cart.shape[0], cx:cx + cart.shape[1]] = cart
            _BAND["b"] = c
        cc, rr = E.sample(_BAND["b"], ctx.uvm[m, 0] + 4.3, z[m], ctx.texel, v0=0.08, wrap_x=True)
        codes = np.full(ctx.N, -1, np.int16)
        rims = np.zeros(ctx.N, np.int16)
        codes[m] = cc
        rims[m] = rr
        s = E.paint_over(ctx, s, codes, rims, seed + 1, flake=0.35, relief=-0.004)
    return s


def build():
    fns = {"skin": skin, "kilt": kilt, "apron": apron, "belt": belt, "collar": collar, "nemes": nemes,
           "beard": beard, "pillar": pillar, "gold": lambda c: E.gold_leaf(c, 819), "base": base_paint}
    face = to_m((0.0, 0.08, 1.65))
    return kit("pharaoh_statue", [base(), figure()], fns, ppm=112, organic=("pharaoh_figure",), built_final=True,
               ao_dist=0.45, ao_stride=2, preview_closeup=(face, 0.55),
               preview_extra=[("torso", to_m((0.0, 0.05, 1.2)), 1.6, 25.0, 5.0)])
