"""An o-yoroi on its display stand (the armour hall, decor): the same armour
as the General's at a man's size (1.8 m), arms hanging, on a black-lacquer
platform with gilt corners and a brass plaque ("ZBROJA SAMURAJA / JAPONIA,
XVI W."). One mesh (a static exhibit); dark inside the mask (no glow).
Texture sets: samurai_armor_stand (crimson lacing), samurai_armor_stand_blue
(navy lacing, the lord's household guard), samurai_armor_stand_white
(white lacing on black: a funeral or a parade set).
Origin = centre of the platform on the floor; front = -Z (Godot).
"""
import math

import numpy as np
from mathutils import Matrix, Vector

from artlib import asia as A
from artlib import kit as K
from artlib import materials as M
from artlib import pixelfont
from artlib import samurai as S
from artlib.geo import Part
from artlib.kit import R, T
from artlib.materials import P
from artlib.model import Model
from models import samurai_general as G

BASE_H = 0.24


def merge(dst, src):
    """Copies the geometry of Part ``src`` (its slots, UVs and locks) into
    Part ``dst``."""
    vmap = {}
    for v in src.bm.verts:
        vmap[v] = dst.bm.verts.new(v.co.copy())
    for f in src.bm.faces:
        nf = dst.bm.faces.new([vmap[v] for v in f.verts])
        nf.material_index = dst.slot(src.slots[f.material_index])
        nf.smooth = f.smooth
        nf[dst.lock] = f[src.lock]
        for la, lb in zip(f.loops, nf.loops):
            lb[dst.uv].uv = la[src.uv].uv.copy()


def armour():
    p = Part("samurai_armor_stand")
    parts = [G.pelvis(), G.torso(), G.head()]
    for sx in (-1, 1):
        parts += [G.upperarm(sx), G.sode_part(sx)]
        arm = Part(f"arm_{sx}")
        sh = G.SHOULDER[sx]
        S.arm(arm, sx, tuple(sh), (sx * 0.36, -0.02, 1.25), (sx * 0.38, 0.02, 1.0), (sx * 0.38, 0.05, 0.94),
              (0, 1, 0))
        parts.append(arm)
        for prt in (G.thigh(sx), G.shin(sx), G.foot_part(sx)):
            parts.append(prt)
    for name, ang in (("kf", 90), ("kb", 270), ("kl", 180), ("kr", 0)):
        parts.append(G.kusazuri_part(name, ang))
    for prt in parts:
        merge(p, prt)
        prt.bm.free()
    # stand on the platform
    p.move(list(p.bm.faces), T(0.0, 0.0, BASE_H))
    # the support pole up through the armour (seen between the legs)
    K.seg(p, (0.0, -0.05, BASE_H), (0.0, -0.05, BASE_H + 0.95), [(0.03, 0.0), (0.03, 1.0)], "pole", segments=6)
    # platform
    p.box((0.0, 0.0, BASE_H / 2), (1.0, 0.8, BASE_H), "base", bevel=0.015)
    for sx in (-1, 1):
        for sy in (-1, 1):
            p.box((sx * 0.48, sy * 0.38, BASE_H / 2), (0.06, 0.06, BASE_H + 0.004), "gilt", bevel=0.004)
    p.box((0.0, 0.405, BASE_H / 2), (0.5, 0.012, 0.13), "plaque", bevel=0.003)
    return p


_TXT = {}


def plaque(ctx, seed=2401):
    s = M.brass(ctx, seed, tarnish_amount=1.2)
    if "t" not in _TXT:
        _TXT["t"] = pixelfont.trim(pixelfont.render(["ZBROJA SAMURAJA", "JAPONIA, XVI W."], line_gap=2))
    front = ctx.n[:, 1] > 0.8
    txt = pixelfont.stamp(ctx, _TXT["t"], 0.0, 0.0, u=-ctx.p[:, 0], v=ctx.p[:, 2] - BASE_H / 2)
    m = front & txt
    s.use_ramp(P["brass_tarnish"], mask=m, shade=np.full(ctx.N, 1.0))
    return s


def dark(ctx):
    """Inside the mask: plain dark (no glow on the stand)."""
    s = S.Surface(ctx.N)
    s.use_ramp(P["pig_black"], shade=np.full(ctx.N, 0.6))
    s.rough = np.full(ctx.N, 0.9)
    return s


def fns(lacing, plate_rim="gold"):
    return {"lame": S.laced(lacing, 4.8 if lacing != "lacing_white" else 5.0), "plate": S.plate, "gold": S.gold,
            "leather": S.leather, "brocade": S.brocade("lacing_blue" if lacing == "lacing_red" else "brocade", gold=True),
            "mail": S.mail, "cloth": S.cloth, "straw": S.straw, "mask": S.mask, "hair": S.hair, "teeth": S.teeth,
            "void": dark, "silk": lambda c: A.silk(c, lacing, 4.6, 2411),
            "fur": lambda c: M.fur(c, seed=2413, flow=(0.0, 0.0, -1.0), center=2.4, moth=0.0),
            "pole": lambda c: A.lacquer(c, 2415, ramp="lacquer_black", center=3.0, wear=0.2),
            "base": lambda c: A.lacquer(c, 2417, ramp="lacquer_black", center=3.0, wear=0.3),
            "gilt": lambda c: A.gilt(c, 2419, worn=0.3, under="lacquer_black"), "plaque": plaque}


def build():
    p = armour()
    return Model("samurai_armor_stand", [p], fns("lacing_red"), ppm=192, ground=0.0, ao_dist=0.15, ao_rays=10,
                 ao_stride=2, front=1, normal_strength=2.0,
                 variants={"samurai_armor_stand_blue": fns("lacing_blue"),
                           "samurai_armor_stand_white": fns("lacing_white")},
                 preview_yaws=(-30.0, 30.0, 140.0, 210.0), preview_closeup=((0.0, 0.1, 1.95), 0.35))
