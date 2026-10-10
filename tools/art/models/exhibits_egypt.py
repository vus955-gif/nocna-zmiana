"""Egypt wing exhibits (Floor I), kit convention (origin = centre of the
base, front = Godot -Z, built facing Blender +Y):

  obelisk         6.3 m pink granite obelisk on a two-step base: a column of
                  large signs cut down each face, a gilded pyramidion. 112 px/m.
  amenhotep_head  colossal red granite head of Amenhotep III (2.4 m with the
                  broken crown) on a granite block: almond eyes, the nose
                  chipped, the white crown broken off, the neck sheared.
                  128 px/m.
  canopic_jars    the four canopic jars in calcite on a small board: Imsety
                  (human), Hapy (baboon), Duamutef (jackal), Qebehsenuef
                  (falcon); parts jar_imsety, jar_hapy, jar_duamutef,
                  jar_qebehsenuef (each pivots at its base). 256 px/m.
  shabti_case     a walnut museum vitrine 1.2 x 1.95 x 0.5 m: three glass
                  shelves of blue faience shabtis (24) and a painted shabti
                  box; part shabti_case_glass (panes). 160 px/m.
"""
import math
import random

import numpy as np
from mathutils import Matrix, Vector

from artlib import egypt as E
from artlib import egypt_paint as EP
from artlib import face as F
from artlib import kit as K
from artlib import materials as M
from artlib import sculpt
from artlib.archkit import cull_floor, kit
from artlib.geo import Part
from artlib.materials import P, _dither, _wood_core
from artlib.painter import Surface
from artlib.sculpt import blob, limb


# --------------------------------------------------------------------------
# obelisk
# --------------------------------------------------------------------------

OB_Z0, OB_Z1, OB_TOP = 0.75, 5.8, 6.32


def obelisk():
    p = Part("obelisk")
    p.box((0.0, 0.0, 0.225), (1.5, 1.5, 0.45), "base_black", bevel=0.02)
    p.box((0.0, 0.0, 0.6), (1.18, 1.18, 0.3), "base", bevel=0.015)
    b0, b1 = 0.41, 0.28
    verts = []
    for z, b in ((OB_Z0, b0), (OB_Z1, b1)):
        verts.append([p.bm.verts.new((x, y, z)) for x, y in ((-b, -b), (b, -b), (b, b), (-b, b))])
    for i in range(4):
        i2 = (i + 1) % 4
        f = p._face([verts[0][i], verts[0][i2], verts[1][i2], verts[1][i]], "shaft")
        f.normal_update()
        c = f.calc_center_median()
        if f.normal.x * c.x + f.normal.y * c.y < 0:
            f.normal_flip()
    apex = p.bm.verts.new((0.0, 0.0, OB_TOP))
    for i in range(4):
        f = p._face([verts[1][i], verts[1][(i + 1) % 4], apex], "pyramidion")
        f.normal_update()
        if f.normal.z < 0:
            f.normal_flip()
    cull_floor([p])
    return p


_OB = {}


def shaft_paint(ctx, seed=1501):
    s = E.granite(ctx, "red", seed, polish=0.26, grain=0.7, center=5.4)
    if "c" not in _OB:
        col = EP.text_columns(1, 22, seed, col_w=12, cell=10, gap=1, divider=False, cartouches=0.12)
        _OB["c"] = np.repeat(np.repeat(col, 2, 0), 2, 1)
    col = _OB["c"]
    w = col.shape[1] * ctx.texel
    codes, rims = E.sample(col, ctx.uvm[:, 0], ctx.p[:, 2], ctx.texel, u0=-w / 2, v0=OB_Z1 - 0.15 - col.shape[0] * ctx.texel)
    inks = {k: ("eg_yellow", 4.4, 0.7, 0.0) for k in E.INKS}
    return E.paint_over(ctx, s, codes, rims, seed + 1, flake=0.7, relief=-0.006, inks=inks)


# --------------------------------------------------------------------------
# the colossal head
# --------------------------------------------------------------------------

AH_C = Vector((0.0, 0.0, 1.55))
AH_S = 1.45


def amenhotep():
    base = Part("amenhotep_head")
    base.box((0.0, 0.0, 0.3), (1.6, 1.5, 0.6), "block", bevel=0.02)
    cull_floor([base])
    h = Part("amenhotep_face")
    me = F.head_mesh({"lips": 1.15, "nose": 1.05, "size": (0.42, 0.47, 0.5)})
    me = sculpt.decimate(me, 3600)
    sculpt.into_part(h, me, "stone", transform=Matrix.Translation(AH_C) @ Matrix.Scale(AH_S, 4))
    # neck stump, sheared off flat on the block; ears
    b = limb([(0.0, -0.1, 0.62), (0.0, -0.05, 1.05)], [0.42, 0.4], spacing=0.6)
    for sx in (-1, 1):
        b.append(blob((sx * 0.6, 0.05, 1.58), (0.08, 0.16, 0.24)))
    me = sculpt.metaball_mesh(b, resolution=0.02)
    sculpt.cut(me, [((0, 0, 0.6), (0, 0, -1))])
    me = sculpt.decimate(me, 700)
    sculpt.into_part(h, me, "stone")
    # the white crown, broken off: a bulb rising from the brow, cut aslant
    crown = h.lathe([(0.56, 1.78), (0.57, 1.95), (0.52, 2.15), (0.45, 2.33), (0.4, 2.4)], "crown", segments=24,
                    center=(0.0, -0.06, 0.0), cap_bottom=False, cap_top=False)
    rng = random.Random(4)
    top = [v for v in sorted({v for f in crown for v in f.verts}, key=lambda v: tuple(round(c, 5) for c in v.co))
           if v.co.z > 2.39]
    for v in top:
        v.co.z += 0.12 * math.sin(math.atan2(v.co.y + 0.06, v.co.x) + 0.6) + rng.uniform(-0.05, 0.05)
    ring = sorted(top, key=lambda v: math.atan2(v.co.y + 0.06, v.co.x))
    mid = h.bm.verts.new((0.0, -0.06, 2.3))
    for i in range(len(ring)):
        f = h._face([ring[i], ring[(i + 1) % len(ring)], mid], "broken")
        f.normal_update()
        if f.normal.z < 0:
            f.normal_flip()
    h.lathe([(0.62, 1.74), (0.64, 1.78), (0.6, 1.86)], "crown", segments=24, center=(0.0, -0.04, 0.0),
            cap_bottom=False, cap_top=False)
    hood = h.lathe([(0.0, -0.02), (0.08, -0.015), (0.09, 0.0), (0.08, 0.02), (0.0, 0.025)], "stone", segments=10)
    h.move(hood, Matrix.Translation((0.0, 0.66, 1.92)) @ Matrix.Rotation(math.radians(80), 4, 'X')
           @ K.S(0.7, 1.3, 1.0))
    return [base, h]


def face_stone(ctx, seed=1511):
    """Polished red granite; the nose tip chipped (rough and paler), kohl
    traces round the eyes."""
    s = E.granite(ctx, "red", seed, polish=0.22, grain=0.5)
    s.shade += np.clip(ctx.curv, 0, 1) * 1.4 - np.clip(-ctx.curv, 0, 1) * 1.4
    x, y, z = ctx.p[:, 0], ctx.p[:, 1], ctx.p[:, 2]
    ux, uy, uz = x / AH_S, (y - AH_C.y) / AH_S, (z - AH_C.z) / AH_S
    chip = (np.abs(ux) < 0.05) & (uz < -0.07) & (uz > -0.16) & (uy > 0.5) & (ctx.fbm(20.0, 2, seed) > -0.2)
    r = E.granite_dressed(ctx, "red", seed + 1)
    s.merge(E._select(r, chip), chip)
    s.shade[chip] += 1.0
    codes = np.zeros(ctx.N, np.int16)
    front = np.nonzero(uy > 0.2)[0]
    for i in front:
        if F.in_eye(ux[i], uz[i], 1.25) and not F.in_eye(ux[i], uz[i], 1.0):
            codes[i] = EP.INK["black"]
    return E.paint_over(ctx, s, codes, np.zeros(ctx.N, np.int16), seed + 2, flake=0.5)


# --------------------------------------------------------------------------
# canopic jars
# --------------------------------------------------------------------------

JARS = [("jar_imsety", "human"), ("jar_hapy", "baboon"), ("jar_duamutef", "jackal"), ("jar_qebehsenuef", "falcon")]


def _jar_head(p, kind, x):
    z0 = 0.355
    if kind == "human":
        me = F.head_mesh({"lips": 1.1})
        me = sculpt.decimate(me, 500)
        sculpt.into_part(p, me, "lid", transform=Matrix.Translation((x, 0.0, z0 + 0.07)) @ Matrix.Scale(0.12, 4))
        wig = p.lathe([(0.065, z0 + 0.01), (0.07, z0 + 0.06), (0.065, z0 + 0.115), (0.04, z0 + 0.135), (0.0, z0 + 0.14)],
                      "lid", segments=12, center=(x, -0.012, 0.0), cap_bottom=False)
        K.keep(p, wig, lambda c: c.y < 0.02 or abs(c.x - x) > 0.045)
        return
    b = [blob((x, -0.005, z0 + 0.07), (0.06, 0.065, 0.065))]
    if kind == "baboon":
        b += [blob((x, 0.05, z0 + 0.055), (0.035, 0.045, 0.03)), blob((x, -0.01, z0 + 0.06), (0.075, 0.05, 0.06))]
    elif kind == "jackal":
        b += [blob((x, 0.06, z0 + 0.055), (0.022, 0.06, 0.022))]
        for sx in (-1, 1):
            b.append(blob((x + sx * 0.03, -0.01, z0 + 0.14), (0.014, 0.008, 0.035)))
    else:
        b += [blob((x, 0.05, z0 + 0.07), (0.02, 0.03, 0.02)), blob((x, 0.065, z0 + 0.06), (0.012, 0.02, 0.018))]
    me = sculpt.metaball_mesh(b, resolution=0.004)
    me = sculpt.decimate(me, 420)
    sculpt.into_part(p, me, "lid")


def canopics():
    board = Part("canopic_jars")
    board.box((0.0, 0.0, 0.015), (1.3, 0.34, 0.03), "board", bevel=0.004)
    cull_floor([board])
    parts = [board]
    for k, (name, kind) in enumerate(JARS):
        x = -0.48 + k * 0.32
        p = Part(name, origin=(x, 0.0, 0.03), parent="canopic_jars")
        p.lathe([(0.07, 0.03), (0.095, 0.05), (0.125, 0.14), (0.13, 0.22), (0.115, 0.3), (0.085, 0.34), (0.082, 0.355)],
                "jar", segments=16, center=(x, 0.0, 0.0), cap_bottom=True, cap_top=True)
        _jar_head(p, kind, x)
        parts.append(p)
    return parts


def jar_paint(ctx, seed=1521):
    s = E.calcite(ctx, seed)
    front = ctx.p[:, 1] > 0.04
    xs = np.array([-0.48, -0.16, 0.16, 0.48])
    xi = xs[np.argmin(np.abs(ctx.p[:, 0][:, None] - xs[None]), axis=1)]
    u = ctx.p[:, 0] - xi
    col = EP.text_columns(1, 4, seed, col_w=12, cell=10, gap=1, divider=False)
    codes, _ = E.sample(col, u, ctx.p[:, 2], ctx.texel, u0=-6 * ctx.texel, v0=0.1)
    codes = np.where(front & (codes > 0), EP.INK["black"], 0).astype(np.int16)
    return E.paint_over(ctx, s, codes, np.zeros(ctx.N, np.int16), seed + 1, flake=0.15)


def lid_paint(ctx, seed=1523):
    s = E.calcite(ctx, seed, center=5.0)
    return s


# --------------------------------------------------------------------------
# shabti case
# --------------------------------------------------------------------------

def _shabti(p, x, y, z, h=0.15, rng=None):
    """A mummiform figurine (h tall) standing on (x, y, z): lathe body with
    an oval section, a wig, crossed arms in paint."""
    prof = [(0.019, 0.0), (0.017, 0.05), (0.025, 0.105), (0.02, 0.122), (0.022, 0.135), (0.008, 0.15)]
    f = p.lathe([(r * h / 0.15, zz * h / 0.15) for r, zz in prof], "shabti", segments=6, center=(x, y, z),
                squash=(1.0, 0.75), cap_bottom=True, cap_top=True)
    return f


def shabti_case():
    p = Part("shabti_case")
    W, H, D = 1.2, 1.95, 0.5
    p.box((0.0, 0.0, 0.25), (W, D, 0.5), "walnut", bevel=0.012)                 # cabinet base
    p.box((0.0, 0.0, 0.52), (W + 0.04, D + 0.04, 0.04), "walnut", bevel=0.008)
    for sx in (-1, 1):
        for sy in (-1, 1):
            p.box((sx * (W / 2 - 0.02), sy * (D / 2 - 0.02), 1.22), (0.04, 0.04, 1.36), "walnut", bevel=0.005)
    p.box((0.0, 0.0, H - 0.04), (W + 0.04, D + 0.04, 0.08), "walnut", bevel=0.008)
    p.box((0.0, 0.0, 0.55), (W - 0.06, D - 0.06, 0.02), "felt")
    rng = random.Random(6)
    for k, z in enumerate((0.56, 0.98, 1.4)):
        for row, yr in enumerate((0.07, -0.08)):
            for i in range(9):
                x = -0.5 + i * 0.125 + (0.06 if row else 0.0)
                if row and i == 8:
                    continue
                _shabti(p, x, yr + rng.uniform(-0.02, 0.02), z, h=rng.uniform(0.17, 0.21), rng=rng)
    # the painted shabti box on the floor of the case
    p.box((0.18, 0.02, 0.62), (0.26, 0.2, 0.12), "box", bevel=0.006)
    p.box((0.18, 0.02, 0.695), (0.27, 0.21, 0.03), "box", bevel=0.006)
    g = Part("shabti_case_glass")
    for z in (0.98, 1.4):
        g.box((0.0, 0.0, z - 0.008), (W - 0.08, D - 0.08, 0.012), "glass")
    gz0, gz1 = 0.54, H - 0.08
    for sy in (-1, 1):
        g.poly([(-W / 2, sy * D / 2, gz0), (W / 2, sy * D / 2, gz0), (W / 2, sy * D / 2, gz1), (-W / 2, sy * D / 2, gz1)], "glass")
    for sx in (-1, 1):
        g.poly([(sx * W / 2, -D / 2, gz0), (sx * W / 2, D / 2, gz0), (sx * W / 2, D / 2, gz1), (sx * W / 2, -D / 2, gz1)], "glass")
    for f in g.bm.faces:
        f.normal_update()
        c = f.calc_center_median()
        if abs(f.normal.z) < 0.5 and f.normal.x * c.x + f.normal.y * c.y < 0:
            f.normal_flip()
    cull_floor([p])
    return [p, g]


def shabti_paint(ctx, seed=1531):
    """Blue faience shabtis: black wig stripes, a black face dot pair, crossed
    hands and bands of text across the legs."""
    s = E.faience(ctx, seed, ramp="turquoise", center=5.8)
    z = ctx.p[:, 2]
    zl = np.mod(z - 0.56, 0.42)
    t = zl / 0.19
    band = (t > 0.2) & (t < 0.62) & (np.mod(np.floor(zl / ctx.texel), 4) == 0)
    wig = (t > 0.8) & (ctx.p[:, 1] < 0.0)
    s.use_ramp(P["eg_black"], mask=band | wig, shade=np.full(ctx.N, 1.0))
    return s


def walnut(ctx, seed=1533):
    s = _wood_core(ctx, P["wood_dark"], 4.4, seed)
    s.shade += ctx.edge(1.0) * 1.4
    s.shade -= ctx.cavity(3.0) * 2.0 + (1.0 - ctx.ao) * 3.0
    s.rough = np.full(ctx.N, 0.35)
    return s


def felt(ctx, seed=1535):
    s = Surface(ctx.N)
    s.use_ramp(P["velvet"], shade=3.2 + ctx.fbm(20.0, 2, seed) * 0.5 + _dither(ctx, 0.5, seed + 1) - (1.0 - ctx.ao) * 2.5)
    s.rough = np.full(ctx.N, 0.95)
    return s


def box_paint(ctx, seed=1537):
    s = Surface(ctx.N)
    s.use_ramp(P["eg_yellow"], shade=4.4 + _dither(ctx, 0.5, seed) - (1.0 - ctx.ao) * 2.5)
    s.rough = np.full(ctx.N, 0.5)
    ix, iy = E.px(ctx)
    codes = np.where(np.mod(iy, 8) < 2, EP.INK["red"], np.where(np.mod(ix, 10) < 2, EP.INK["blue"], 0)).astype(np.int16)
    return E.paint_over(ctx, s, codes, np.zeros(ctx.N, np.int16), seed + 1, flake=0.3)


def build():
    out = [kit("obelisk", [obelisk()], {"base_black": lambda c: E.granite(c, "black", 1541, polish=0.3, grain=0.6, center=4.0),
                                        "base": lambda c: E.granite(c, "red", 1543, polish=0.3, grain=0.6),
                                        "shaft": shaft_paint, "pyramidion": lambda c: E.gold_leaf(c, 1545)},
               ppm=112, ao_dist=0.4, built_final=True, preview_extra=[("top", (0.0, 0.0, 5.6), 0.9, 25.0, 10.0)]),
           kit("amenhotep_head", amenhotep(), {"block": lambda c: E.granite(c, "red", 1551, polish=0.4, grain=0.6),
                                               "stone": face_stone,
                                               "crown": lambda c: E.granite(c, "red", 1553, polish=0.24, grain=0.5),
                                               "broken": lambda c: E.granite_dressed(c, "red", 1555)},
               ppm=128, ao_dist=0.4, built_final=True, organic=("amenhotep_face",),
               preview_closeup=((0.0, 0.6, 1.6), 0.8)),
           kit("canopic_jars", canopics(), {"board": lambda c: _wood_core(c, P["wood_dark"], 4.0, 1561),
                                            "jar": jar_paint, "lid": lid_paint},
               ppm=256, ao_dist=0.08, built_final=True, organic=tuple(n for n, _ in JARS)),
           kit("shabti_case", shabti_case(), {"walnut": walnut, "felt": felt, "shabti": shabti_paint, "box": box_paint},
               kinds={"glass": "glass"}, ppm=160, ao_dist=0.15, built_final=True)]
    return out
