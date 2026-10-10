"""The Nereid Monument (Xanthos, c. 390 BC), rebuilt full size in its room:
a little Ionic temple on a high podium girdled by two sculptured friezes.
Two models stacked (the temple's origin = the podium's top centre):

  nereid_podium   7.2 x 4.4 x 4.0 m (W x H x D): a base step, ashlar walls
                  (world-mapped field "tile:gr_ashlar"), the broad battle
                  frieze (0.9 m: Greek hoplites against Lycians, horsemen,
                  the fallen) round the front and both sides, a plain
                  course, the narrow frieze (0.55 m: a column of soldiers
                  marching to the siege), a crown moulding. 128 px/m.
                  Origin = centre of the base on the floor; front -Z; the
                  back stands against the room's wall.
  nereid_temple   the temple on top: stylobate, four Ionic columns across
                  the front (parts nereid_column_1..4; the gaps between
                  them take the Nereid statues, nereid_a..d, at x =
                  -2.07, 0, +2.07 and one on the side), a corner column on
                  each side (nereid_column_5/6), the cella wall with a
                  bronze door, the architrave (three fasciae), a frieze of
                  a banquet, dentils, the cornice, the pediment with a
                  relief of a seated ruler and his court, akroteria.
                  7.6 x 6.8 x 4.0 m. 96 px/m. Origin = centre of the
                  stylobate's underside: place it at y = 4.4 on the podium.

Total height 11.2 m to the top of the central akroterion (10.3 m to the
pediment's apex): the room wants 12.5 m and a moon shaft on the pediment.
Statues stand on the stylobate (y 4.4 + 0.3 = 4.7).
"""
import math

import numpy as np
from mathutils import Matrix

from artlib import greek as GK
from artlib import greek_figures as G
from artlib import greek_ornament as O
from artlib import materials as M
from artlib import relief as RL
from artlib.archkit import facing, kit
from artlib.geo import Part
from artlib.relief import Frame
from models import gr_orders

W, D = 7.2, 4.0
H_POD = 4.4
F1 = (1.8, 2.7)          # broad frieze: z range on the podium
F2 = (3.45, 4.0)         # narrow frieze
COL_H = 3.3
STYLO = 0.3


# --------------------------------------------------------------------------
# reliefs
# --------------------------------------------------------------------------

def battle(length, seed, h=0.9, s=0.95, z=0.06):
    """A crowded battle: hoplites with crested helmets and round shields
    against Lycians in cloaks, a horseman here and there, the fallen."""
    R = RL.Relief(length, h, 128, seed=seed)
    rng = np.random.default_rng(seed)
    x = 0.3
    k = 0
    while x < length - 0.3:
        kind = rng.choice(["duel", "duel", "horse", "fallen"]) if k % 3 else "duel"
        if kind == "horse" and x < length - 0.8:
            G.horse(R, Frame(x + 0.3, 0.03, s * 0.95, face=int(rng.choice([-1, 1]))), gait="rear", pitch=20,
                    z=z * 0.8, rider=G.rider(z=z, dress="chlamys", arm_up=True))
            x += 0.9
        elif kind == "fallen":
            F = Frame(x + 0.2, 0.03, s, face=int(rng.choice([-1, 1])), rot=-80, pivot=(0.0, 0.05))
            G.human(R, F, G.walk(0.5, sh_n=140, el_n=160), z=z * 0.7, dress="chlamys")
            x += 0.45
        else:
            for face, dx in ((1, 0.0), (-1, 0.42)):
                pose = G.walk(1.4, lean=15, sh_n=int(rng.integers(40, 130)), el_n=int(rng.integers(40, 160)),
                              sh_f=85, el_f=115, hip_n=45, hip_f=-40, knee_f=-35)
                F = Frame(x + dx, 0.03, s, face=face)
                greek = face == 1
                lids, j = G.human(R, F, pose, z=z, dress="chiton" if greek else "chlamys",
                                  helmet="crest" if greek else None)
                G.round_shield(R, F, (j["el_f"][0] + 0.03, j["el_f"][1] + 0.02), r=0.14, z=z * 1.15)
            x += 0.95
        k += 1
    R.chips(int(length * 4), seed=seed, y_band=(0.05, h - 0.05), size=(0.015, 0.04))
    R.joints([j for j in np.arange(1.2, length, 1.3)], seed=seed)
    return R.finish()


def march(length, seed, h=0.55, s=0.58, z=0.045):
    """Soldiers marching in file to the siege, shields on their arms."""
    R = RL.Relief(length, h, 128, seed=seed)
    x = 0.25
    while x < length - 0.2:
        F = Frame(x, 0.025, s)
        lids, j = G.human(R, F, G.walk(0.9, sh_n=20, el_n=110), z=z, dress="chiton", helmet="crest")
        G.round_shield(R, F, (j["el_f"][0] + 0.04, j["el_f"][1]), r=0.13, z=z * 1.15)
        G.spear(R, F, (j["hand_n"][0] - 0.1, j["hand_n"][1] - 0.3), (j["hand_n"][0] + 0.15, j["hand_n"][1] + 0.55),
                z=z * 1.2)
        x += 0.42
    R.chips(int(length * 3), seed=seed, y_band=(0.05, h - 0.05), size=(0.012, 0.03))
    return R.finish()


def banquet(length, seed, h=0.4, s=0.42, z=0.03):
    """The temple frieze: banqueters reclining on couches, servants."""
    R = RL.Relief(length, h, 128, seed=seed)
    x = 0.3
    k = 0
    while x < length - 0.3:
        if k % 3 == 2:
            G.human(R, Frame(x, 0.02, s * 0.9), G.walk(0.3, sh_n=40, el_n=100), z=z, dress="chiton",
                    extra=G.hold_jug)
            x += 0.3
        else:
            F = Frame(x, 0.02, s)
            f = G.Fig(R, F, z)
            f.layer(f.poly([(-0.3, 0.0), (0.35, 0.0), (0.38, 0.35), (-0.32, 0.35)]), 0.6, RL.WOOD, bulge=0.1)
            G.human(R, Frame(x - 0.05, 0.02 + 0.35 * s, s, rot=-70, pivot=(0.0, 0.3)), G.walk(0.2, sh_n=60, el_n=80),
                    z=z * 1.1, dress="himation", beard=True, extra=G.hold_phiale)
            x += 0.85
        k += 1
    return R.finish()


def tympanum(width, height, seed, s=0.8, z=0.05):
    """The pediment: the ruler enthroned in the middle, his court standing,
    figures kneeling and reclining toward the corners."""
    R = RL.Relief(width, height, 128, seed=seed)
    cx = width / 2
    f = G.Fig(R, Frame(0, 0, 1.0), z)
    f.layer(R.poly([(cx - 0.25, 0.04), (cx + 0.2, 0.04), (cx + 0.18, 0.42), (cx - 0.25, 0.42)]), 0.6, RL.WOOD,
            bulge=0.1)                                                               # the throne
    G.human(R, Frame(cx, 0.04, s), dict(G.STAND, root=(0.0, 0.42), hip_n=95, knee_n=5, hip_f=90, knee_f=0,
                                        sh_n=30, el_n=80, sh_f=10, el_f=70), z=z * 1.1, dress="himation", beard=True)
    for side in (-1, 1):
        for k, (dx, sc) in enumerate(((0.75, 0.82), (1.35, 0.65), (1.9, 0.5))):
            x = cx + side * dx
            G.human(R, Frame(x, 0.04, s * sc, face=-side), G.walk(0.3, sh_n=40, el_n=90), z=z * 0.9,
                    dress="himation" if k % 2 else "chlamys")
        F = Frame(cx + side * 2.6, 0.04, s * 0.42, face=-side, rot=-82, pivot=(0.0, 0.05))
        G.human(R, F, G.walk(0.4, sh_n=120, el_n=140), z=z * 0.8, dress="chlamys")
    R.chips(10, seed=seed, y_band=(0.05, height * 0.8), size=(0.015, 0.03))
    return R.finish()


# --------------------------------------------------------------------------
# podium
# --------------------------------------------------------------------------

def _box_faces(p, x0, x1, y0, y1, z0, z1, slots):
    """Front (y0, viewer side), left, right and top faces of a box with
    their own slots: slots = dict(front=, side=, top=)."""
    facing(p, [(x0, y0, z0), (x1, y0, z0), (x1, y0, z1), (x0, y0, z1)], slots["front"], (0, -1, 0))
    facing(p, [(x0, y1, z0), (x0, y0, z0), (x0, y0, z1), (x0, y1, z1)], slots.get("left", slots.get("side")), (-1, 0, 0))
    facing(p, [(x1, y0, z0), (x1, y1, z0), (x1, y1, z1), (x1, y0, z1)], slots.get("right", slots.get("side")), (1, 0, 0))
    if slots.get("top"):
        facing(p, [(x0, y0, z1), (x1, y0, z1), (x1, y1, z1), (x0, y1, z1)], slots["top"], (0, 0, 1))


def podium():
    p = Part("nereid_podium")
    hw = W / 2
    # the podium's back is at y = D (the room's wall); front at y = 0; the
    # model is built facing -Y and turned by the kit
    y0 = -D / 2

    def box(z0, z1, slots, inset=0.0):
        _box_faces(p, -hw + inset, hw - inset, y0 + inset, D / 2, z0, z1, slots)
    box(0.0, 0.35, {"front": "plain", "side": "plain", "top": "plain"}, inset=-0.12)     # base step
    box(0.35, F1[0] - 0.12, {"front": "field", "side": "field"})
    box(F1[0] - 0.12, F1[0], {"front": "marble", "side": "marble", "top": "marble"}, inset=-0.05)
    box(F1[0], F1[1], {"front": "frieze_front", "left": "frieze_left", "right": "frieze_right"}, inset=-0.03)
    box(F1[1], F1[1] + 0.1, {"front": "marble", "side": "marble", "top": "marble"}, inset=-0.07)
    box(F1[1] + 0.1, F2[0] - 0.08, {"front": "field", "side": "field"})
    box(F2[0] - 0.08, F2[0], {"front": "marble", "side": "marble", "top": "marble"}, inset=-0.04)
    box(F2[0], F2[1], {"front": "frieze2_front", "left": "frieze2_side", "right": "frieze2_side"}, inset=-0.02)
    box(F2[1], H_POD - 0.18, {"front": "plain", "side": "plain"}, inset=-0.06)
    box(H_POD - 0.18, H_POD, {"front": "marble", "side": "marble", "top": "plain"}, inset=-0.16)
    return p


# --------------------------------------------------------------------------
# temple
# --------------------------------------------------------------------------

COLS_X = (-3.1, -1.03, 1.03, 3.1)


def temple():
    hw = W / 2
    y0 = -D / 2
    parts = []
    t = Part("nereid_temple")
    # stylobate
    _box_faces(t, -hw + 0.1, hw - 0.1, y0 + 0.1, D / 2, 0.0, STYLO, {"front": "plain", "side": "plain",
                                                                    "top": "plain"})
    # cella: front wall 1.6 m behind the colonnade, with a door; side walls
    cy = y0 + 1.7
    zc0, zc1 = STYLO, STYLO + COL_H
    door_w, door_h = 1.3, 2.4
    for xa, xb in ((-hw + 0.5, -door_w / 2), (door_w / 2, hw - 0.5)):
        facing(t, [(xa, cy, zc0), (xb, cy, zc0), (xb, cy, zc1), (xa, cy, zc1)], "field", (0, -1, 0))
    facing(t, [(-door_w / 2, cy, zc0 + door_h), (door_w / 2, cy, zc0 + door_h), (door_w / 2, cy, zc1),
               (-door_w / 2, cy, zc1)], "field", (0, -1, 0))
    # door frame (Ionic architrave round the opening) and the bronze leaves
    t.sweep([(0.0, 0.0), (0.05, 0.0), (0.05, 0.08), (0.07, 0.1), (0.07, 0.18), (0.0, 0.2)],
            [(-door_w / 2, zc0), (-door_w / 2, zc0 + door_h), (door_w / 2, zc0 + door_h), (door_w / 2, zc0)],
            "marble", y0=cy)
    t.box((0, cy + 0.04, zc0 + door_h / 2), (door_w, 0.06, door_h), "door", bevel=0.01)
    # side walls of the porch (antae)
    for sx in (-1, 1):
        x = sx * (hw - 0.5)
        facing(t, [(x, cy, zc0), (x, D / 2, zc0), (x, D / 2, zc1), (x, cy, zc1)], "field", (-sx, 0, 0))
        t.box((x + sx * 0.15, cy - 0.15, (zc0 + zc1) / 2), (0.3, 0.3, COL_H), "marble", bevel=0.02)   # anta
    # entablature over the colonnade: architrave, frieze, dentils, cornice
    za = STYLO + COL_H
    t.extrude([(0.0, za), (-0.05, za), (-0.05, za + 0.18), (-0.07, za + 0.19), (-0.07, za + 0.36),
               (-0.09, za + 0.37), (-0.09, za + 0.52), (-0.11, za + 0.56), (-0.07, za + 0.58)],
              -hw - 0.05, hw + 0.05, "marble", caps=True)
    t.box((0, -0.04, za + 0.79), (W + 0.1, 0.08, 0.42), "banquet")
    t.extrude([(0.0, za + 1.0), (-0.12, za + 1.0), (-0.12, za + 1.1), (-0.14, za + 1.1), (-0.17, za + 1.14),
               (-0.35, za + 1.14), (-0.35, za + 1.12), (-0.37, za + 1.12), (-0.37, za + 1.26), (0.0, za + 1.26)],
              -hw - 0.2, hw + 0.2, "marble", caps=True)
    n = int((W + 0.1) / 0.14)
    for k in range(n):
        x = -hw - 0.05 + (k + 0.5) * (W + 0.1) / n
        t.box((x, -0.1, za + 1.05), (0.08, 0.06, 0.1), "marble")
    # move the whole entablature front to the colonnade line (y0 + 0.35)
    # (built at y = 0: shift it)
    ent = [f for f in t.bm.faces if f.calc_center_median().z >= za - 0.001 and f.calc_center_median().y < 0.3]
    t.move(ent, Matrix.Translation((0.0, y0 + 0.35, 0.0)))
    # the soffit over the porch and the entablature's returns along the sides
    facing(t, [(-hw, y0 + 0.35, za), (hw, y0 + 0.35, za), (hw, D / 2, za), (-hw, D / 2, za)], "plain", (0, 0, -1))
    for sx in (-1, 1):
        x = sx * (hw + 0.05)
        facing(t, [(x, y0 + 0.3, za), (x, D / 2, za), (x, D / 2, za + 1.26), (x, y0 + 0.3, za + 1.26)], "plain",
               (sx, 0, 0))
    # pediment: the tympanum (relief), raking cornices, akroteria
    zp = za + 1.26
    ph = 1.05
    tri = [(-hw + 0.1, zp), (hw - 0.1, zp), (0.0, zp + ph)]
    f = t.poly([(x, y0 + 0.4, z) for x, z in tri], "tympanum")[0]
    f.normal_update()
    if f.normal.y > 0:
        f.normal_flip()
    for sx in (-1, 1):
        a = (sx * (hw + 0.2), zp)
        b = (0.0, zp + ph + 0.18)
        L = math.hypot(b[0] - a[0], b[1] - a[1])
        theta = math.degrees(math.atan2(b[1] - a[1], abs(b[0] - a[0])))
        rk = t.box((0.0, 0.0, 0.0), (L, 0.5, 0.22), "marble", bevel=0.02)
        t.move(rk, Matrix.Translation(((a[0] + b[0]) / 2, y0 + 0.3 + 0.25, (a[1] + b[1]) / 2 + 0.05))
               @ Matrix.Rotation(math.radians(sx * theta), 4, 'Y'))
        roof = t.box((0.0, 0.0, 0.0), (L, D - 0.8, 0.1), "plain")
        t.move(roof, Matrix.Translation(((a[0] + b[0]) / 2, y0 + 0.8 + (D - 0.8) / 2, (a[1] + b[1]) / 2 + 0.02))
               @ Matrix.Rotation(math.radians(sx * theta), 4, 'Y'))
        # corner akroterion: a palmette slab
        ak = t.box((0, 0, 0), (0.5, 0.08, 0.55), "akroterion")
        t.move(ak, Matrix.Translation((sx * (hw + 0.05), y0 + 0.35, zp + 0.42)))
    ak = t.box((0, 0, 0), (0.6, 0.08, 0.7), "akroterion")
    t.move(ak, Matrix.Translation((0.0, y0 + 0.4, zp + ph + 0.55)))
    parts.append(t)
    # columns: the Ionic order at 3.3 m
    for k, x in enumerate(list(COLS_X) + [-3.1, 3.1]):
        y = y0 + 0.35 if k < 4 else y0 + 1.25
        c = gr_orders.ionic(light=True)
        c.name = "nereid_column_%d" % (k + 1)
        sc = COL_H / 7.0
        c.move(list(c.bm.faces), Matrix.Translation((x, y, STYLO)) @ Matrix.Scale(sc, 4))
        c.origin = (x, y, STYLO)
        c.parent = None
        parts.append(c)
    return parts


# --------------------------------------------------------------------------
# paint
# --------------------------------------------------------------------------

def _relief_on(maps, axis, x0, z0, flip=False, seed=1401, blue=0.5):
    """Material function reading relief maps on a face: ``axis`` the
    horizontal world axis of the face ("x" or "y", after the kit turn),
    x0 its start, z0 the bottom of the relief."""
    def fn(ctx):
        a = ctx.p[:, 0] if axis == "x" else ctx.p[:, 1]
        u = (-(a) + x0) if not flip else (a - x0)
        v = ctx.p[:, 2] - z0
        return GK.relief_surface(ctx, maps, u, v, seed=seed, blue=blue)
    return fn


def _marble(ctx):
    return GK.pentelic(ctx, seed=1411, center=7.6, veins=0.5, patina=1.1, ao=3.5, grime=False)


def _floor(ctx):
    return GK.pentelic(ctx, seed=1413, center=7.0, veins=0.4, patina=1.2, ao=4.0)


def _door(ctx):
    s = M.bronze(ctx)
    u, v = ctx.uvm[:, 0], ctx.uvm[:, 1]
    stud = (np.mod(u, 0.22) < 0.04) & (np.mod(v, 0.3) < 0.04)
    s.shade += stud * 2.0
    panel = (np.abs(np.mod(u, 0.65) - 0.325) > 0.28) | (np.abs(np.mod(v, 0.8) - 0.4) > 0.34)
    s.shade -= panel * 0.8
    s.height = stud * 0.004
    return s


def _akroterion(ctx):
    s = GK.pentelic(ctx, seed=1421, center=7.6, veins=0.3, patina=1.0, ao=3.0, grime=False)
    u, v = ctx.uvm[:, 0], ctx.uvm[:, 1]
    palm, lotus, scroll = O.anthemion(np.mod(u, 0.6), v, 0.5, period=0.6)
    s.shade += palm * 1.0 - (~palm) * 0.5
    GK.paint_traces(ctx, s, "gr_red", palm, 1423, center=4.0, density=0.5, freq=3.0)
    s.height = palm * 0.004
    return s


def _banquet_fn(maps, hw):
    def fn(ctx):
        u = -ctx.p[:, 0] + hw + 0.05
        v = ctx.p[:, 2] - (STYLO + COL_H + 0.58)
        front = np.abs(ctx.n[:, 1]) > 0.5
        s = GK.relief_surface(ctx, maps, u, v, seed=1431, blue=0.7)
        return s
    return fn


def _tympanum_fn(maps, hw):
    def fn(ctx):
        u = -ctx.p[:, 0] + hw - 0.1
        v = ctx.p[:, 2] - (STYLO + COL_H + 1.26)
        return GK.relief_surface(ctx, maps, u, v, seed=1433, blue=0.9)
    return fn


def build():
    hw = W / 2
    maps_front = battle(W + 0.06, 1501)
    maps_side = battle(D + 0.03, 1502)
    maps_side2 = battle(D + 0.03, 1503)
    maps_m = march(W + 0.04, 1504)
    maps_ms = march(D + 0.02, 1505)
    # after the kit turn the podium's front faces +Y; viewer's right = -x; the
    # side faces: left face (now at +x) read with u along -y ... front to back
    pod_fns = {"marble": _marble,
               "frieze_front": _relief_on(maps_front, "x", hw + 0.03, F1[0]),
               "frieze_left": _relief_on(maps_side, "y", -D / 2, F1[0], flip=True),
               "frieze_right": _relief_on(maps_side2, "y", D / 2 + 0.03, F1[0], flip=False),
               "frieze2_front": _relief_on(maps_m, "x", hw + 0.02, F2[0]),
               "frieze2_side": _relief_on(maps_ms, "y", -D / 2, F2[0], flip=True)}
    pod = kit("nereid_podium", [podium()], pod_fns, kinds={"field": "tile:gr_ashlar", "plain": "tile:gr_marble"},
              ppm=128, ground=0.0,
              planes=(("y", -D / 2),), ao_dist=0.3, normal_strength=1.4,
              preview_extra=[("frieze", (0.0, -1.0, 2.3), 1.6, 15.0, 5.0)])
    maps_b = banquet(W + 0.1, 1506)
    maps_t = tympanum(W - 0.2, 1.05, 1507)

    def _tymp(ctx):
        s = _tympanum_fn(maps_t, hw)(ctx)
        return s
    tem_fns = {"marble": _marble, "floor": _floor, "door": _door, "akroterion": _akroterion,
               "banquet": _banquet_fn(maps_b, hw), "tympanum": _tymp,
               "shaft": gr_orders._shaft, "echinus": gr_orders._echinus, "volute": gr_orders._volute_paint,
               "volute_disc": gr_orders._volute_disc, "grey": _marble}
    tem = kit("nereid_temple", temple(), tem_fns, kinds={"field": "tile:gr_ashlar", "plain": "tile:gr_marble"},
              ppm=96, ground=0.0,
              planes=(("y", -D / 2),), ao_dist=0.35, normal_strength=1.4,
              preview_extra=[("pediment", (0.0, -1.2, 4.6), 2.2, 12.0, 6.0)])
    return [pod, tem]
