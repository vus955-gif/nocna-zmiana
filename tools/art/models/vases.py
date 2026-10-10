"""Greek painted vases of the Vase Room (256 px/m; painted pixel by pixel
on the unrolled surface, artlib/vase_paint.py) and their cases (128 px/m).

  vase_amphora_bf   black-figure belly amphora (0.6 m): black body with two
                    reserved panels - two hoplites clash over a fallen
                    comrade / a horseman - rays at the foot, tongues on the
                    shoulder, palmettes on the neck
  vase_amphora_rf   red-figure neck amphora (0.62 m): a kithara player and a
                    youth in a continuous scene, meander below, palmettes
  vase_krater       red-figure calyx krater (0.48 m, open mouth 0.5 m): a
                    revel of youths in mantles round the bowl, a laurel
                    wreath under the rim, glossed inside
  vase_volute       black-figure volute krater (0.78 m): a cavalcade round
                    the shoulder, a chariot frieze, rays, scroll handles
                    rising above the rim
  vase_hydria       red-figure hydria (0.44 m): women fetching water at a
                    fountain on the shoulder and body; three handles
  vase_kylix        black-figure eye cup (0.12 m tall, 0.4 across the
                    handles): big apotropaic eyes outside, a running warrior
                    in the tondo
  vase_lekythos     white-ground lekythos (0.36 m): a mourning woman seated
                    at a grave stele drawn in thin lines on white
  vase_case_tall    single-vase vitrine 0.8 x 1.95 x 0.8 m: walnut plinth
                    (vase top at 0.95 m), a glass box on a brass frame, a
                    label; part vase_case_tall_glass; marker VaseSpot
  vase_case_wall_2m wall case 2.0 x 2.3 x 0.6 m: walnut base, two glass
                    shelves (markers Shelf_0 at 0.9 m, Shelf_1 at 1.45 m,
                    Shelf_2 at 1.95 m: the vases stand on them), glazed front;
                    part vase_case_wall_2m_glass. Against a wall (back z = 0)

Vases: origin = centre of the foot on the shelf, the painted front toward
Godot -Z. Cases: origin = centre of the base on the floor, front -Z.
"""
import math

import numpy as np
from mathutils import Matrix

from artlib import greek as GK
from artlib import greek_figures as G
from artlib import materials as M
from artlib import relief as RL
from artlib import vase_paint as VP
from artlib.archkit import facing, kit
from artlib.geo import Part
from artlib.relief import Frame

PPM = 256


# --------------------------------------------------------------------------
# shapes
# --------------------------------------------------------------------------

def _vessel(p, outer, inner=None, segs=24, handles=()):
    p.lathe(outer, "pot", segments=segs, cap_bottom=True, cap_top=inner is None, smooth=True)
    if inner:
        fs = p.lathe(inner, "inner", segments=segs, cap_bottom=False, cap_top=True, smooth=True)
        for f in fs:
            f.normal_flip()
    for path, r in handles:
        p.tube(path, r, "gloss", sides=6, smooth=True)


def _loop(x0, z0, x1, z1, out, sx, n=7):
    """A handle arc from (x0, z0) to (x1, z1) bulging out to ``out`` (in the
    x-z plane, side ``sx``)."""
    pts = []
    for i in range(n + 1):
        t = i / n
        x = x0 + (x1 - x0) * t + out * math.sin(math.pi * t)
        z = z0 + (z1 - z0) * t + 0.03 * math.sin(math.pi * t)
        pts.append((sx * x, 0.0, z))
    return pts


def amphora_bf():
    p = Part("vase_amphora_bf")
    outer = [(0.0, 0.0), (0.085, 0.0), (0.09, 0.012), (0.08, 0.03), (0.058, 0.05), (0.062, 0.08), (0.11, 0.14),
             (0.15, 0.22), (0.17, 0.3), (0.168, 0.36), (0.15, 0.42), (0.11, 0.47), (0.085, 0.5), (0.083, 0.55),
             (0.092, 0.575), (0.1, 0.59), (0.097, 0.6)]
    inner = [(0.088, 0.6), (0.075, 0.57), (0.072, 0.53)]
    hs = [(_loop(0.09, 0.56, 0.135, 0.45, 0.06, sx), 0.013) for sx in (-1, 1)]
    _vessel(p, outer, inner, handles=hs)
    return p


def amphora_rf():
    p = Part("vase_amphora_rf")
    outer = [(0.0, 0.0), (0.08, 0.0), (0.084, 0.014), (0.07, 0.03), (0.05, 0.05), (0.055, 0.08), (0.1, 0.14),
             (0.14, 0.22), (0.158, 0.3), (0.155, 0.38), (0.13, 0.44), (0.085, 0.48), (0.065, 0.5), (0.062, 0.57),
             (0.07, 0.6), (0.085, 0.615), (0.082, 0.62)]
    inner = [(0.074, 0.62), (0.058, 0.6), (0.055, 0.55)]
    hs = [(_loop(0.065, 0.585, 0.12, 0.455, 0.05, sx), 0.012) for sx in (-1, 1)]
    _vessel(p, outer, inner, handles=hs)
    return p


def krater():
    p = Part("vase_krater")
    outer = [(0.0, 0.0), (0.11, 0.0), (0.115, 0.015), (0.1, 0.03), (0.06, 0.055), (0.064, 0.09), (0.12, 0.12),
             (0.165, 0.16), (0.19, 0.24), (0.215, 0.33), (0.24, 0.42), (0.255, 0.465), (0.252, 0.48)]
    inner = [(0.24, 0.48), (0.22, 0.4), (0.18, 0.27), (0.11, 0.17), (0.0, 0.15)]
    hs = []
    for sx in (-1, 1):
        hs.append(([(sx * 0.16, -0.05, 0.17), (sx * 0.22, -0.04, 0.2), (sx * 0.23, 0.0, 0.21), (sx * 0.22, 0.04, 0.2),
                    (sx * 0.16, 0.05, 0.17)], 0.012))
    _vessel(p, outer, inner, segs=28, handles=hs)
    return p


def volute():
    p = Part("vase_volute")
    outer = [(0.0, 0.0), (0.1, 0.0), (0.105, 0.015), (0.09, 0.03), (0.06, 0.06), (0.065, 0.1), (0.13, 0.16),
             (0.18, 0.25), (0.2, 0.36), (0.19, 0.46), (0.15, 0.52), (0.13, 0.55), (0.135, 0.65), (0.16, 0.72),
             (0.18, 0.75), (0.178, 0.76)]
    inner = [(0.165, 0.76), (0.13, 0.7), (0.115, 0.6)]
    hs = []
    for sx in (-1, 1):
        hs.append(([(sx * 0.16, 0.0, 0.5), (sx * 0.2, 0.0, 0.6), (sx * 0.21, 0.0, 0.72), (sx * 0.2, 0.0, 0.8)], 0.016))
    _vessel(p, outer, inner, segs=28, handles=hs)
    for sx in (-1, 1):
        for sy in (-1, 1):
            d = p.lathe([(0.0, -0.012), (0.06, -0.012), (0.06, 0.012), (0.0, 0.012)], "gloss", segments=12)
            p.move(d, Matrix.Translation((sx * 0.2, sy * 0.03, 0.82)) @ Matrix.Rotation(math.radians(90), 4, 'X'))
    return p


def hydria():
    p = Part("vase_hydria")
    outer = [(0.0, 0.0), (0.075, 0.0), (0.08, 0.012), (0.065, 0.028), (0.06, 0.05), (0.1, 0.1), (0.15, 0.18),
             (0.165, 0.25), (0.16, 0.3), (0.14, 0.34), (0.09, 0.37), (0.055, 0.39), (0.05, 0.42), (0.07, 0.435),
             (0.068, 0.44)]
    inner = [(0.06, 0.44), (0.045, 0.42), (0.042, 0.39)]
    hs = [(_loop(0.15, 0.27, 0.155, 0.2, 0.04, sx), 0.011) for sx in (-1, 1)]
    hs.append(([(0.0, 0.055, 0.41), (0.0, 0.12, 0.42), (0.0, 0.16, 0.37), (0.0, 0.16, 0.32)], 0.013))
    _vessel(p, outer, inner, handles=hs)
    return p


def kylix():
    p = Part("vase_kylix")
    outer = [(0.0, 0.0), (0.06, 0.0), (0.062, 0.008), (0.03, 0.02), (0.02, 0.04), (0.03, 0.055), (0.1, 0.07),
             (0.15, 0.095), (0.16, 0.11), (0.158, 0.118)]
    inner = [(0.15, 0.118), (0.14, 0.1), (0.09, 0.08), (0.0, 0.072)]
    hs = []
    for sx in (-1, 1):
        hs.append(([(sx * 0.15, -0.035, 0.1), (sx * 0.2, -0.03, 0.11), (sx * 0.21, 0.0, 0.112), (sx * 0.2, 0.03, 0.11),
                    (sx * 0.15, 0.035, 0.1)], 0.009))
    _vessel(p, outer, inner, segs=28, handles=hs)
    return p


def lekythos():
    p = Part("vase_lekythos")
    outer = [(0.0, 0.0), (0.045, 0.0), (0.047, 0.01), (0.04, 0.02), (0.05, 0.03), (0.062, 0.05), (0.066, 0.22),
             (0.06, 0.245), (0.03, 0.26), (0.018, 0.27), (0.016, 0.31), (0.03, 0.335), (0.032, 0.355),
             (0.028, 0.36)]
    inner = [(0.022, 0.36), (0.015, 0.34)]
    hs = [([(0.0, 0.017, 0.3), (0.0, 0.045, 0.3), (0.0, 0.05, 0.27), (0.0, 0.03, 0.255)], 0.007)]
    _vessel(p, outer, inner, segs=20, handles=hs)
    return p


# --------------------------------------------------------------------------
# decoration
# --------------------------------------------------------------------------

def _duel(R):
    s = R.h / 1.0
    for face, x in ((1, 0.27), (-1, 0.73)):
        F = Frame(R.w * x, 0.02 * R.h, s, face=face)
        lids, j = G.human(R, F, G.walk(1.4, lean=12, sh_n=150, el_n=120, sh_f=80, el_f=110), z=0.05,
                          dress="chiton", helmet="crest")
        G.round_shield(R, F, (j["el_f"][0] + 0.03, j["el_f"][1] + 0.02), r=0.15, z=0.06)
        G.spear(R, F, (j["hand_n"][0] - 0.2, j["hand_n"][1] - 0.1), (j["hand_n"][0] + 0.25, j["hand_n"][1] + 0.05),
                z=0.06, r=0.012)


def _horseman(R):
    s = R.h / 1.0
    G.horse(R, Frame(R.w * 0.45, 0.02 * R.h, s * 1.05), gait="canter", z=0.05,
            rider=G.rider(z=0.06, dress="chlamys", hat=True))


def _kitharist(R):
    s = R.h / 1.0
    G.human(R, Frame(R.w * 0.3, 0.02 * R.h, s), G.walk(0.4, sh_n=10, el_n=60, sh_f=40, el_f=110), z=0.05,
            dress="long", extra=G.kithara)
    G.human(R, Frame(R.w * 0.7, 0.02 * R.h, s, face=-1), G.walk(0.3, sh_n=60, el_n=100), z=0.05,
            dress="himation", beard=True, extra=G.staff)


def _revel(R):
    s = R.h / 1.0
    n = 5
    for k in range(n):
        x = R.w * (k + 0.5) / n
        pose = G.walk(1.0 + 0.3 * (k % 2), lean=8 * ((-1) ** k), sh_n=60 + 30 * (k % 3), el_n=90 + 20 * (k % 2))
        G.human(R, Frame(x, 0.02 * R.h, s, face=1 if k % 2 == 0 else -1), pose, z=0.05,
                dress="himation" if k % 2 else "chlamys", beard=(k % 3 == 0),
                extra=G.hold_phiale if k % 2 else None)


def _cavalcade(R):
    s = R.h / 1.0
    n = max(2, int(R.w / (0.85 * s)))
    for k in range(n):
        G.horse(R, Frame((k + 0.4) * R.w / n, 0.02 * R.h, s * 0.95), gait="canter" if k % 2 else "gallop", z=0.05,
                rider=G.rider(z=0.06))


def _chariots(R):
    s = R.h / 1.0
    n = max(1, int(R.w / (1.6 * s)))
    for k in range(n):
        G.chariot(R, Frame((k + 0.15) * R.w / n, 0.02 * R.h, s), z=0.05)


def _water(R):
    s = R.h / 1.0
    for k, x in enumerate((0.15, 0.38, 0.62, 0.85)):
        G.human(R, Frame(R.w * x, 0.02 * R.h, s, face=1 if k < 2 else -1),
                G.walk(0.5, sh_n=165, el_n=230), z=0.05, dress="peplos", female=True, extra=G.carry_vase)


def _runner(R):
    s = R.h / 1.0
    F = Frame(R.w * 0.45, 0.06 * R.h, s * 0.95)
    lids, j = G.human(R, F, G.walk(1.6, lean=20, sh_n=40, el_n=20, sh_f=110, el_f=130, hip_n=70, knee_n=-30,
                                   hip_f=-60, knee_f=-80), z=0.05, dress="chiton", helmet="crest")
    G.round_shield(R, F, (j["el_f"][0] + 0.03, j["el_f"][1] + 0.02), r=0.16, z=0.06)


def _mourner(R):
    s = R.h / 1.0
    f = G.Fig(R, Frame(0, 0, 1.0), 0.04)
    f.layer(R.poly([(R.w * 0.62, 0.0), (R.w * 0.82, 0.0), (R.w * 0.8, R.h * 0.86), (R.w * 0.64, R.h * 0.86)]), 0.6,
            RL.WOOD)                                                         # the grave stele
    G.human(R, Frame(R.w * 0.3, 0.02 * R.h, s * 0.95), dict(G.STAND, root=(0.0, 0.42), hip_n=95, knee_n=5, hip_f=90,
                                                           knee_f=0, sh_n=40, el_n=150, sh_f=10, el_f=60, head=20),
            z=0.05, dress="long", female=True)


def _canvas_amphora_bf(r0):
    c = VP.Canvas(r0, 0.6)
    c.band(0.0, 0.6, VP.GLOSS)
    c.band(0.04, 0.12, VP.CLAY)
    c.rays(0.05, 0.12, 30)
    c.line(0.13, code=VP.CLAY)
    # two reserved panels: front and back
    pw = c.circ * 0.3
    for cx, scene in ((c.circ * 0.5, _duel), (0.0, _horseman)):
        x0 = cx - pw / 2
        mask = c.rows(0.19, 0.43) & (np.mod(c.X - x0, c.circ) < pw)
        c.code[mask] = VP.CLAY
        c.scene(x0 + 0.01, 0.2, pw - 0.02, 0.2, scene, style="bf", seed=int(cx * 100))
        top = c.rows(0.395, 0.43) & (np.mod(c.X - x0, c.circ) < pw)
        t = np.mod((c.X - x0) / pw * 9, 1.0)
        c.code[top] = np.where(np.abs(t[top] - 0.5) < 0.35, VP.GLOSS, VP.CLAY)
    c.band(0.47, 0.56, VP.CLAY)
    c.palmettes(0.48, 0.555, 9, VP.GLOSS)
    c.band(0.56, 0.6, VP.GLOSS)
    return c


def _canvas_amphora_rf(r0):
    c = VP.Canvas(r0, 0.62)
    c.band(0.0, 0.62, VP.GLOSS)
    c.band(0.16, 0.2, VP.CLAY)
    c.meander(0.165, 0.195)
    c.scene(c.circ * 0.32, 0.2, c.circ * 0.36, 0.22, _kitharist, style="rf", seed=3)
    c.scene(c.circ * 0.82, 0.21, c.circ * 0.3, 0.2, _horseman, style="rf", seed=4)
    c.band(0.5, 0.56, VP.CLAY)
    c.palmettes(0.505, 0.555, 8, VP.GLOSS)
    return c


def _canvas_krater(r0):
    c = VP.Canvas(r0, 0.48)
    c.band(0.0, 0.48, VP.GLOSS)
    c.band(0.17, 0.2, VP.CLAY)
    c.meander(0.172, 0.198)
    c.scene(0.0, 0.2, c.circ, 0.2, _revel, style="rf", seed=5)
    c.ivy(0.42, 0.465, 30, VP.CLAY)
    return c


def _canvas_volute(r0):
    c = VP.Canvas(r0, 0.78)
    c.band(0.0, 0.78, VP.CLAY)
    c.band(0.0, 0.04, VP.GLOSS)
    c.rays(0.06, 0.16, 36)
    c.band(0.17, 0.18, VP.GLOSS)
    c.scene(0.0, 0.19, c.circ, 0.17, _cavalcade, style="bf", seed=6)
    c.band(0.365, 0.375, VP.GLOSS)
    c.scene(0.0, 0.38, c.circ, 0.13, _chariots, style="bf", seed=7)
    c.band(0.52, 0.56, VP.GLOSS)
    c.tongues(0.56, 0.6, 40)
    c.ivy(0.62, 0.7, 26, VP.GLOSS)
    c.band(0.72, 0.78, VP.GLOSS)
    return c


def _canvas_hydria(r0):
    c = VP.Canvas(r0, 0.44)
    c.band(0.0, 0.44, VP.GLOSS)
    c.band(0.08, 0.11, VP.CLAY)
    c.meander(0.083, 0.107)
    c.scene(c.circ * 0.18, 0.11, c.circ * 0.64, 0.2, _water, style="rf", seed=8)
    c.ivy(0.33, 0.36, 20, VP.CLAY)
    return c


def _canvas_kylix(r0):
    c = VP.Canvas(r0, 0.12)
    c.band(0.0, 0.12, VP.GLOSS)
    c.band(0.0, 0.01, VP.CLAY)
    # two pairs of great eyes (front and back), a nose between each pair
    for cx in (c.circ * 0.5, c.circ * 0.999):
        for dx in (-0.06, 0.06):
            ex, ey = cx + dx, 0.085
            d = np.hypot(c.X - ex, (c.Y - ey) * 1.4)
            c.code[(d < 0.028)] = VP.WHITE
            c.code[(d < 0.02)] = VP.GLOSS
            c.code[(d < 0.015)] = VP.RED
            c.code[(d < 0.007)] = VP.GLOSS
        nose = (np.abs(c.X - cx) < 0.008) & (c.Y > 0.07) & (c.Y < 0.1)
        c.code[nose] = VP.CLAY
    c.band(0.11, 0.12, VP.CLAY)
    return c


def _canvas_lekythos(r0):
    c = VP.Canvas(r0, 0.36)
    c.band(0.0, 0.36, VP.GLOSS)
    c.band(0.05, 0.225, VP.WHITE)
    c.meander(0.2, 0.222, VP.GLOSS)
    c.palmettes(0.23, 0.255, 6, VP.GLOSS, fill=VP.CLAY)
    R = RL.Relief(c.circ * 0.5, 0.14, 256, seed=9)
    _mourner(R)
    maps = R.finish(ao_reach=0.01)
    fig = maps["tag"] != RL.BG
    outline = VP._border(fig)
    H, W = fig.shape
    c0 = int(round(c.circ * 0.25 * c.ppm))
    r0_ = int(round((c.h - 0.195) * c.ppm))
    rows = np.clip(np.arange(H) + r0_, 0, c.H - 1)
    cols = (np.arange(W) + c0) % c.W
    out = c.code[np.ix_(rows, cols)]
    out = np.where(outline, VP.DILUTE, out)
    out = np.where(fig & (maps["tag"] == RL.CLOTH) & ~outline & (np.indices(fig.shape)[1] % 3 == 0), VP.RED, out)
    c.code[np.ix_(rows, cols)] = out
    return c


def _tondo_runner():
    """The kylix's inside: a running warrior in a black-figure tondo."""
    c = VP.Canvas(0.25, 0.3)
    c.band(0.0, 0.3, VP.CLAY)
    c.scene(0.0, 0.0, 0.3, 0.3, _runner, style="bf", seed=11)
    return c


def _inner_fn(tondo=None, r_tondo=0.07):
    def fn(ctx):
        s = M.Surface(ctx.N)
        s.use_ramp(GK.P["gr_gloss"], shade=np.full(ctx.N, 2.6) - (1.0 - ctx.ao) * 2.0 + (ctx.rand(1801) - 0.5) * 0.6)
        s.rough = np.full(ctx.N, 0.2)
        if tondo is not None:
            x, y = ctx.p[:, 0], ctx.p[:, 1]
            r = np.hypot(x, y)
            inside = r < r_tondo
            col = np.clip(((x / r_tondo * 0.5 + 0.5) * 0.3 * tondo.ppm).astype(int), 0, tondo.W - 1)
            row = np.clip(((0.5 - y / r_tondo * 0.5) * 0.3 * tondo.ppm).astype(int), 0, tondo.H - 1)
            code = tondo.code[row, col]
            clay = inside & (code == VP.CLAY)
            s.use_ramp(GK.P["gr_clay"], mask=clay, shade=np.full(ctx.N, 5.0))
            s.use_ramp(GK.P["gr_miltos"], mask=inside & (code == VP.RED), shade=np.full(ctx.N, 2.5))
            ring = np.abs(r - r_tondo) < 0.004
            s.use_ramp(GK.P["gr_clay"], mask=ring, shade=np.full(ctx.N, 4.0))
            s.rough = np.where(clay, 0.7, s.rough)
        return s
    return fn


def _gloss(ctx):
    s = M.Surface(ctx.N)
    s.use_ramp(GK.P["gr_gloss"], shade=np.full(ctx.N, 3.0) + ctx.edge(1.0) * 2.0 - (1.0 - ctx.ao) * 2.0)
    s.rough = 0.2 + ctx.edge(2.0) * 0.3
    return s


# --------------------------------------------------------------------------
# cases
# --------------------------------------------------------------------------

def _frame(p, x0, x1, y0, y1, z0, z1, t=0.025):
    for x in (x0, x1):
        for y in (y0, y1):
            p.box((x, y, (z0 + z1) / 2), (t, t, z1 - z0), "brass", bevel=0.004)
    for z in (z0 + t / 2, z1 - t / 2):
        p.box(((x0 + x1) / 2, y0, z), (x1 - x0, t, t), "brass", bevel=0.004)
        p.box(((x0 + x1) / 2, y1, z), (x1 - x0, t, t), "brass", bevel=0.004)
        p.box((x0, (y0 + y1) / 2, z), (t, y1 - y0, t), "brass", bevel=0.004)
        p.box((x1, (y0 + y1) / 2, z), (t, y1 - y0, t), "brass", bevel=0.004)


def _glass_box(g, x0, x1, y0, y1, z0, z1, top=True, back=True):
    facing(g, [(x0, y0, z0), (x1, y0, z0), (x1, y0, z1), (x0, y0, z1)], "glass", (0, -1, 0))
    if back:
        facing(g, [(x1, y1, z0), (x0, y1, z0), (x0, y1, z1), (x1, y1, z1)], "glass", (0, 1, 0))
    facing(g, [(x0, y1, z0), (x0, y0, z0), (x0, y0, z1), (x0, y1, z1)], "glass", (-1, 0, 0))
    facing(g, [(x1, y0, z0), (x1, y1, z0), (x1, y1, z1), (x1, y0, z1)], "glass", (1, 0, 0))
    if top:
        facing(g, [(x0, y0, z1), (x1, y0, z1), (x1, y1, z1), (x0, y1, z1)], "glass", (0, 0, 1))


def case_tall():
    p = Part("vase_case_tall")
    g = Part("vase_case_tall_glass")
    w = 0.8
    h = w / 2
    p.box((0, 0, 0.05), (w - 0.06, w - 0.06, 0.1), "walnut", bevel=0.008)
    p.box((0, 0, 0.5), (w - 0.04, w - 0.04, 0.8), "walnut", bevel=0.012)
    p.box((0, 0, 0.93), (w + 0.02, w + 0.02, 0.04), "walnut", bevel=0.012)
    p.box((0, -h + 0.005, 0.72), (0.3, 0.012, 0.09), "label", bevel=0.003)
    p.box((0, 0, 0.95 + 0.005), (w - 0.1, w - 0.1, 0.01), "felt")
    _frame(p, -h + 0.02, h - 0.02, -h + 0.02, h - 0.02, 0.95, 1.92)
    p.box((0, 0, 1.935), (w - 0.01, w - 0.01, 0.03), "walnut", bevel=0.008)
    e = 0.006
    _glass_box(g, -h + 0.02 + e, h - 0.02 - e, -h + 0.02 + e, h - 0.02 - e, 0.95, 1.915, top=True)
    return [p, g]


def case_wall():
    p = Part("vase_case_wall_2m")
    g = Part("vase_case_wall_2m_glass")
    W, D = 2.0, 0.6
    hw = W / 2
    y0, y1 = -D, 0.0                         # back on the wall plane (y = 0, built facing -Y)
    p.box((0, y0 / 2, 0.42), (W, D, 0.84), "walnut", bevel=0.012)
    for x in (-0.5, 0.5):
        p.box((x, y0 - 0.006, 0.42), (0.86, 0.012, 0.6), "walnut", bevel=0.015)
    p.box((0, y0 / 2, 0.87), (W + 0.02, D + 0.02, 0.06), "walnut", bevel=0.012)
    p.box((0, y0 / 2, 0.905), (W - 0.06, D - 0.06, 0.01), "felt")
    # back panel (fabric) and the cornice
    facing(p, [(-hw, -0.02, 0.9), (hw, -0.02, 0.9), (hw, -0.02, 2.22), (-hw, -0.02, 2.22)], "felt", (0, -1, 0))
    _frame(p, -hw + 0.015, hw - 0.015, y0 + 0.015, -0.02, 0.9, 2.22)
    p.box((0, y0 / 2, 2.26), (W + 0.04, D + 0.04, 0.08), "walnut", bevel=0.01)
    p.box((0, y0 + 0.08, 2.205), (W - 0.2, 0.03, 0.012), "lamp", bevel=0.002)
    p.box((0, y0 - 0.01, 0.75), (0.5, 0.012, 0.1), "label", bevel=0.003)
    # glass: front and ends, two shelves
    e = 0.006
    _glass_box(g, -hw + 0.015 + e, hw - 0.015 - e, y0 + 0.015 + e, -0.025, 0.9, 2.21, top=False, back=False)
    for z in (1.45, 1.95):
        g.box((0, y0 / 2 - 0.01, z - 0.006), (W - 0.06, D - 0.08, 0.012), "glass")
    return [p, g]


def _walnut(ctx):
    return M.wood_dark(ctx, seed=1811)


def _felt(ctx):
    s = M.Surface(ctx.N)
    s.use_ramp(GK.P["gr_wall_ochre"], shade=np.full(ctx.N, 2.0) + ctx.fbm(30.0, 2, 1815) * 0.6
               - (1.0 - ctx.ao) * 3.0)
    s.rough = np.full(ctx.N, 0.95)
    return s


def _label(ctx):
    s = M.Surface(ctx.N)
    s.use_ramp(GK.P["gr_white_slip"], shade=np.full(ctx.N, 3.5) + (ctx.rand(1817) > 0.8) * -1.5)
    s.rough = np.full(ctx.N, 0.8)
    return s


VASES = {
    "vase_amphora_bf": (amphora_bf, _canvas_amphora_bf, 0.17, None),
    "vase_amphora_rf": (amphora_rf, _canvas_amphora_rf, 0.158, None),
    "vase_krater": (krater, _canvas_krater, 0.24, None),
    "vase_volute": (volute, _canvas_volute, 0.2, None),
    "vase_hydria": (hydria, _canvas_hydria, 0.165, None),
    "vase_kylix": (kylix, _canvas_kylix, 0.16, "tondo"),
    "vase_lekythos": (lekythos, _canvas_lekythos, 0.066, None),
}


def build():
    out = []
    for name, (shape, canvas, r0, tondo) in VASES.items():
        c = canvas(r0)
        white = name == "vase_lekythos"
        fns = {"pot": (lambda ctx, c=c, white=white: VP.surface(ctx, c, white_ground=False)), "gloss": _gloss,
               "inner": _inner_fn(_tondo_runner() if tondo else None)}
        out.append(kit(name, [shape()], fns, ppm=PPM, ground=0.0, ao_dist=0.08, ao_rays=12, ao_stride=1,
                       normal_strength=1.0, preview_extra=[("front", (0.0, 0.0, 0.25 if name != "vase_kylix" else 0.06),
                                                            0.32 if name != "vase_kylix" else 0.22, 0.0, 8.0)]))
    case_fns = {"walnut": _walnut, "brass": M.brass, "felt": _felt, "label": _label, "lamp": M.lamp_warm}
    out.append(kit("vase_case_tall", case_tall(), case_fns, kinds={"glass": "glass"}, ppm=128, ground=0.0,
                   ao_dist=0.25, markers=[("VaseSpot", (0.0, 0.0, 0.96), None)]))
    out.append(kit("vase_case_wall_2m", case_wall(), case_fns, kinds={"glass": "glass"}, ppm=128, ground=0.0,
                   ao_dist=0.25, wall=True,
                   markers=[("Shelf_0", (0.0, -0.3, 0.91), None), ("Shelf_1", (0.0, -0.3, 1.45), None),
                            ("Shelf_2", (0.0, -0.3, 1.95), None)]))
    return out
