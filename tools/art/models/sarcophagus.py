"""A granite sarcophagus (Late Period): a rectangular chest 2.6 x 1.25 m on
a moulded plinth, carved and pigment-filled - a line of large signs under
the rim, a procession of gods (Anubis, Horus, the sons of Horus) on both
long sides, Isis and Nephthys on the ends - and a vaulted lid with raised
end boards and a column of text along its crown. Hollow: the lid slides off
(mummies burst out) onto a dark interior.

Kit convention: origin = centre of the base, front = Godot -Z (Blender +Y,
built final), long axis along X, 128 px/m, 2.66 x 1.52 x 1.31 m.
Parts: sarcophagus (the chest, root) and lid (child; pivot at the centre of
the lid's underside, 1.05 m up: slide it along X, tip it about Z).
Marker MummySpawn: on the floor of the hollow. Texture sets: sarcophagus
(black granodiorite, yellow-filled signs), sarcophagus_red (red granite,
white-filled signs).
"""
import math

import numpy as np
from mathutils import Matrix

from artlib import egypt as E
from artlib import egypt_paint as EP
from artlib.archkit import cull_floor, front_prism, kit
from artlib.geo import Part

L, W, H = 2.6, 1.25, 1.05
T = 0.16
LID_Z = H


def chest():
    p = Part("sarcophagus")
    p.box((0.0, 0.0, 0.06), (L + 0.12, W + 0.12, 0.12), "plinth", bevel=0.02)
    p.box((0.0, 0.0, 0.14), (L + 0.04, W + 0.04, 0.04), "plinth", bevel=0.01)
    p.box((0.0, 0.0, 0.16 + 0.06), (L - 2 * T, W - 2 * T, 0.12), "inside")              # floor of the hollow
    for sy in (-1, 1):
        p.box((0.0, sy * (W / 2 - T / 2), (0.12 + H) / 2), (L, T, H - 0.12), "chest", bevel=0.015)
    for sx in (-1, 1):
        p.box((sx * (L / 2 - T / 2), 0.0, (0.12 + H) / 2), (T, W - 2 * T + 0.002, H - 0.12), "chest", bevel=0.015)
    cull_floor([p])
    return p


def lid():
    p = Part("lid", origin=(0.0, 0.0, LID_Z), parent="sarcophagus")
    p.box((0.0, 0.0, LID_Z + 0.08), (L + 0.06, W + 0.06, 0.16), "lid", bevel=0.015)
    arc = []
    for i in range(11):
        a = math.pi * i / 10
        arc.append(((W / 2 - 0.02) * math.cos(a), LID_Z + 0.16 + 0.24 * math.sin(a)))
    p.extrude(arc, -L / 2 + 0.12, L / 2 - 0.12, "vault", caps=True)
    for sx in (-1, 1):
        x = sx * (L / 2 - 0.06)
        prof = [(-(W / 2 + 0.03), LID_Z + 0.16), ((W / 2 + 0.03), LID_Z + 0.16), ((W / 2 + 0.03), LID_Z + 0.3),
                (0.25, LID_Z + 0.46), (0.0, LID_Z + 0.47), (-0.25, LID_Z + 0.46), (-(W / 2 + 0.03), LID_Z + 0.3)]
        f = p.ngon_prism(prof, -0.06, 0.06, "lid", bevel=0.012)
        # prism (px, py, pz) -> (x = pz, y = px, z = py): the outline stands across the lid
        p.move(f, Matrix(((0.0, 0.0, 1.0, x), (1.0, 0.0, 0.0, 0.0), (0.0, 1.0, 0.0, 0.0), (0.0, 0.0, 0.0, 1.0))))
    return p


# --------------------------------------------------------------------------

_C = {}


def _side_canvas(w, h, seed, gods):
    key = ("side", w, h, seed)
    if key not in _C:
        c = np.zeros((h, w), np.int16)
        bb = EP.block_border(w, 4, 5)
        c[0:4] = bb
        line = np.repeat(np.repeat(EP.text_line(w // 2, seed), 2, 0), 2, 1)[:, :w]
        c[6:26, :line.shape[1]] = line
        c[28:32] = bb
        n = len(gods)
        for k, (head, pose) in enumerate(gods):
            x = int((k + 0.5) * w / n)
            EP.figure(c, x, h - 6, h - 46, pose=pose, head=head, sex="m", flip=False, offering="lotus", seed=seed + k,
                      crown="nemes" if head == "human" else None)
        c[h - 4:h] = bb
        _C[key] = c
    return _C[key]


def _end_canvas(w, h, seed):
    key = ("end", w, h, seed)
    if key not in _C:
        c = np.zeros((h, w), np.int16)
        bb = EP.block_border(w, 4, 5)
        c[0:4] = bb
        c[h - 4:h] = bb
        EP.figure(c, w // 2, h - 8, h - 22, pose="adore", sex="f", seed=seed)
        _C[key] = c
    return _C[key]


def _lid_line(w, seed):
    key = ("lid", w, seed)
    if key not in _C:
        c = np.zeros((24, w), np.int16)
        c[0:2] = EP.INK["divider"]
        line = np.repeat(np.repeat(EP.text_line(w // 2, seed), 2, 0), 2, 1)[:, :w]
        c[2:22, :line.shape[1]] = line
        c[22:24] = EP.INK["divider"]
        _C[key] = c
    return _C[key]


def _filled(fill):
    """All carved codes take the one pigment of the fill."""
    inks = {}
    for code in list(E.INKS):
        inks[code] = fill
    return inks


GODS_FRONT = [("jackal", "bearer"), ("falcon", "bearer"), ("human", "adore"), ("jackal", "bearer"), ("falcon", "bearer"),
              ("human", "adore")]
GODS_BACK = [("falcon", "bearer"), ("human", "adore"), ("jackal", "bearer"), ("falcon", "bearer"), ("human", "adore"),
             ("jackal", "bearer")]


def stone_paint(kind, fill):
    inks = _filled(fill)

    def chest_paint(ctx, seed=1001):
        s = E.granite(ctx, kind, seed, polish=0.16, grain=0.6)
        tx = ctx.texel
        u = ctx.uvm[:, 0]
        z = ctx.p[:, 2]
        codes = np.full(ctx.N, -1, np.int16)
        rims = np.zeros(ctx.N, np.int16)
        hpx = int(round((H - 0.16) / tx))
        for mask, canvas, u0 in (
                (ctx.n[:, 1] > 0.9, _side_canvas(int(round(L / tx)), hpx, 3, GODS_FRONT), -L / 2),
                (ctx.n[:, 1] < -0.9, _side_canvas(int(round(L / tx)), hpx, 9, GODS_BACK), -L / 2),
                (np.abs(ctx.n[:, 0]) > 0.9, _end_canvas(int(round(W / tx)), hpx, 5), -W / 2)):
            m = mask & (z > 0.14) & (z < H - 0.01) & (np.abs(ctx.p[:, 0]) <= L / 2 + 0.001) & (np.abs(ctx.p[:, 1]) <= W / 2 + 0.001)
            outer = m & ((np.abs(ctx.p[:, 1]) > W / 2 - 0.01) | (np.abs(ctx.p[:, 0]) > L / 2 - 0.01))
            if outer.any():
                c, r = E.sample(canvas, u[outer], z[outer], tx, u0=u0, v0=0.15)
                codes[outer] = c
                rims[outer] = r
        return E.paint_over(ctx, s, codes, rims, seed + 1, flake=0.45, relief=-0.004, inks=inks)

    def lid_paint(ctx, seed=1003):
        s = E.granite(ctx, kind, seed, polish=0.18, grain=0.6)
        top = (ctx.n[:, 2] > 0.2) & (np.abs(ctx.p[:, 0]) < L / 2 - 0.12)
        if top.any():
            canvas = _lid_line(int(round(L / ctx.texel)), 13)
            # across the vault: the arc length from its crown (y = 0)
            arc = np.arcsin(np.clip(ctx.p[:, 1] / (W / 2 - 0.02), -1, 1)) * (W / 2 - 0.02)
            c, r = E.sample(canvas, ctx.p[top, 0], arc[top], ctx.texel, u0=-L / 2, v0=-12 * ctx.texel)
            codes = np.full(ctx.N, -1, np.int16)
            rims = np.zeros(ctx.N, np.int16)
            codes[top] = c
            rims[top] = r
            s = E.paint_over(ctx, s, codes, rims, seed + 1, flake=0.45, relief=-0.004, inks=inks)
        return s

    return chest_paint, lid_paint


def inside(ctx, seed=1005):
    s = E.granite_dressed(ctx, "black", seed)
    s.shade -= 1.5
    return s


def fns_for(kind, fill):
    chest_paint, lid_paint = stone_paint(kind, fill)
    return {"chest": chest_paint, "lid": lid_paint, "vault": lid_paint, "inside": inside,
            "plinth": lambda c: E.granite(c, kind, 1007, polish=0.3, grain=0.6)}


def build():
    return kit("sarcophagus", [chest(), lid()], fns_for("black", ("eg_yellow", 5.2, 0.7, 0.0)), ppm=128,
               built_final=True, ao_dist=0.35, markers=[("MummySpawn", (0.0, 0.0, 0.28), "sarcophagus")],
               variants={"sarcophagus_red": fns_for("red", ("eg_white", 4.8, 0.75, 0.0))},
               preview_extra=[("side", (0.0, 0.62, 0.6), 1.0, 0.0, 5.0)])
