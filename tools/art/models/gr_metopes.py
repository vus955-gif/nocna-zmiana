"""Greek kit: the south metopes of the Parthenon - Lapiths fighting
centaurs - as wall-mounted slabs in high relief (real geometry from the
relief height field, the fine carving in the normal map, 128 px/m).

  gr_metope_a   a centaur rears; a Lapith seizes him from behind, his cloak
                hanging down the background (after south metope XXVII)
  gr_metope_b   the centaur triumphs over a fallen Lapith, a panther skin
                flying from his arm (XXVIII)
  gr_metope_c   wrestlers: the centaur grips the Lapith's throat, the
                Lapith drives a knee into the horse body (XXXI)
  gr_metope_d   a centaur swings a wine jar over a Lapith crouching behind
                his shield (XXX)

Each slab: 1.25 x 1.32 m (relief 1.25 x 1.2 under a projecting taenia),
0.32 m deep at the most raised point; the back sits on the wall plane.
Origin = bottom centre on the wall plane (z = 0), relief toward -Z; hang it
with its bottom at about 1.6 m (Metopes room) or set it in a Doric frieze.
Damage as on the originals: Lapith heads lost, arms broken off, chipped
arrises; Egyptian-blue traces in the background, red on cloaks.
"""
import math

import numpy as np

from artlib import greek as GK
from artlib import greek_figures as G
from artlib import relief as RL
from artlib.archkit import facing, kit
from artlib.geo import Part
from artlib.relief import Frame
from artlib.relief_mesh import relief_mesh

PPM = 128
W = 1.25
RH = 1.2            # relief height
D = 0.1             # slab background in front of the wall
S = 1.04            # figure scale (frieze figures are 0.9 m tall at 1.0)
Z = 0.15            # relief depth of the nearest planes (x S)


def _lapith(R, x, pose, face=1, rot=0.0, pivot=(0.0, 0.0), z=Z, dress="chlamys", headless=False, shield=None,
            extra=None):
    F = Frame(x, 0.04, S, face=face, rot=rot, pivot=pivot)
    lids, j = G.human(R, F, pose, z=z, dress=dress, headless=headless, extra=extra)
    if shield:
        G.round_shield(R, F, shield, r=0.15, z=z * 1.12)
    return lids, j, F


def metope_a():
    R = RL.Relief(W, RH, PPM, seed=31)
    # Lapith's cloak hangs from his shoulders down the background
    G.centaur(R, Frame(0.5, 0.05, S, face=-1), z=Z * 0.85, pose="rear", arm_up=True,
              arm_kw=dict(sh_n=115, el_n=150, sh_f=100, el_f=60))
    pose = G.walk(1.4, root=(0.0, 0.47), lean=18, sh_n=70, el_n=110, sh_f=95, el_f=120, hip_n=40, knee_n=-5,
                  hip_f=-35, knee_f=-40, cloak=(-0.25, 0.45))
    lids, j, F = _lapith(R, 0.66, pose, face=1, z=Z * 1.05)
    hx, hy = F.p(*j["head"])
    R.break_off(R.ell((hx, hy + 0.01), 0.07, 0.08), seed=1, frac=0.25)       # the Lapith's head
    ex, ey = F.p(*j["wr_n"])
    R.break_off(R.ell((ex, ey), 0.06, 0.05, 20), seed=2, frac=0.2)           # his hand
    R.chips(12, seed=31, y_band=(0.05, 1.15), size=(0.015, 0.04))
    return R.finish(ao_reach=0.12)


def metope_b():
    R = RL.Relief(W, RH, PPM, seed=32)
    # the fallen Lapith lies across the ground
    fallen = G.walk(0.2, root=(0.0, 0.46), lean=-10, sh_n=150, el_n=170, sh_f=-30, el_f=-10, hip_n=60, knee_n=10,
                    hip_f=20, knee_f=-30)
    _lapith(R, 0.12, fallen, face=1, rot=-78, pivot=(0.0, 0.05), z=Z * 0.75, dress="chlamys")
    G.centaur(R, Frame(0.5, 0.05, S, face=1), z=Z * 0.95, pose="walk", arm_up=True,
              arm_kw=dict(sh_n=125, el_n=150, sh_f=95, el_f=50))
    # the panther skin flying from his far arm
    f = G.Fig(R, Frame(0.0, 0.0, 1.0), Z)
    skin = R.poly([(0.84, 0.95), (0.98, 1.06), (1.18, 1.02), (1.15, 0.86), (1.06, 0.8), (1.02, 0.89), (0.9, 0.84)])
    lid = f.layer(skin, 0.7, RL.CLOTH, bulge=0.3, bulge_w=0.05)
    R.texture([lid], 0.004, 30.0, seed=7, kind="curls")
    R.break_off(R.ell((0.2, 0.16), 0.07, 0.06), seed=3, frac=0.3)
    R.chips(12, seed=32, y_band=(0.05, 1.15), size=(0.015, 0.04))
    return R.finish(ao_reach=0.12)


def metope_c():
    R = RL.Relief(W, RH, PPM, seed=33)
    G.centaur(R, Frame(0.85, 0.05, S, face=-1), z=Z * 0.9, pose="rear", arm_up=False,
              arm_kw=dict(sh_n=80, el_n=95, sh_f=60, el_f=90, lean=-2))
    pose = G.walk(1.0, root=(0.0, 0.5), lean=-12, sh_n=120, el_n=100, sh_f=60, el_f=40, hip_n=95, knee_n=10,
                  hip_f=-20, knee_f=-15)
    lids, j, F = _lapith(R, 0.3, pose, face=1, z=Z * 1.1, dress="nude")
    hx, hy = F.p(*j["head"])
    R.break_off(R.ell((hx, hy + 0.01), 0.07, 0.08), seed=4, frac=0.3)
    R.chips(12, seed=33, y_band=(0.05, 1.15), size=(0.015, 0.04))
    return R.finish(ao_reach=0.12)


def metope_d():
    R = RL.Relief(W, RH, PPM, seed=34)
    pose = G.walk(0.6, root=(0.0, 0.38), lean=25, sh_n=40, el_n=90, sh_f=80, el_f=120, hip_n=80, knee_n=-20,
                  hip_f=10, knee_f=-60)
    lids, j, F = _lapith(R, 0.95, pose, face=-1, z=Z * 0.85, dress="chlamys", shield=(0.06, 0.6))
    B, jc, lc = G.centaur(R, Frame(0.33, 0.05, S, face=1), z=Z, pose="rear", arm_up=True,
                          arm_kw=dict(sh_n=95, el_n=135, sh_f=85, el_f=120))
    # the wine jar raised over his head
    f = G.Fig(R, B, Z)
    jar = G.vase_shape(f, (jc["hand_n"][0] - 0.06, jc["hand_n"][1] - 0.1), h=0.3, w=0.2, tilt=-30)
    f.layer(jar, 1.08, RL.TACK, bulge=0.35, bulge_w=0.05)
    hx, hy = F.p(*j["head"])
    R.break_off(R.ell((hx, hy + 0.01), 0.07, 0.08), seed=5, frac=0.25)
    R.chips(12, seed=34, y_band=(0.05, 1.15), size=(0.015, 0.04))
    return R.finish(ao_reach=0.12)


SETS = {"gr_metope_a": metope_a, "gr_metope_b": metope_b, "gr_metope_c": metope_c, "gr_metope_d": metope_d}


def slab(name, maps):
    p = Part(name)
    hw = W / 2
    # frame: the slab's edges round the carved face, the taenia on top
    facing(p, [(-hw, -D, 0.0), (-hw, 0.0, 0.0), (-hw, 0.0, RH), (-hw, -D, RH)], "marble", (-1, 0, 0))
    facing(p, [(hw, 0.0, 0.0), (hw, -D, 0.0), (hw, -D, RH), (hw, 0.0, RH)], "marble", (1, 0, 0))
    facing(p, [(-hw, -D, 0.0), (hw, -D, 0.0), (hw, 0.0, 0.0), (-hw, 0.0, 0.0)], "marble", (0, 0, -1))
    p.extrude([(-D, RH), (-D - 0.24, RH), (-D - 0.24, RH + 0.12), (0.0, RH + 0.12)], -hw - 0.02, hw + 0.02,
              "marble", caps=True)
    relief_mesh(p, maps, -hw, 0.0, -D, "relief", step=2, target_tris=4200)
    return p


def _relief_fn(maps, seed):
    def fn(ctx):
        u = -ctx.p[:, 0] + W / 2
        v = ctx.p[:, 2]
        return GK.relief_surface(ctx, maps, u, v, seed=seed, height="detail", blue=0.45, shading=0.6,
                                 front=ctx.n[:, 1])
    return fn


def _marble(ctx):
    return GK.pentelic(ctx, seed=1011, center=7.6, veins=0.5, patina=1.0, ao=3.5)


def build():
    out = []
    for k, (name, fn) in enumerate(SETS.items()):
        maps = fn()
        out.append(kit(name, [slab(name, maps)], {"marble": _marble, "relief": _relief_fn(maps, 1013 + k)},
                       ppm=PPM, wall=True, ground=None, ao_dist=0.3, normal_strength=1.4,
                       preview_extra=[("front", (0.0, 0.1, 0.62), 0.75, 12.0, 6.0)]))
    return out
