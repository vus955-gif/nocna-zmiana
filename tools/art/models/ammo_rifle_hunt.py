"""Pickup: rounds for the expedition rifle (vm_rifle_hunt). An old box of
9,3 x 62 big-game cartridges: faded green cardboard, rubbed pale on the
edges, a cream paper label "9,3 x 62" on the front and on the lid (real
letters, artlib/pixelfont.py). The lid is folded open behind, its tuck
flap bent forward. Inside, a cardboard partition holds two rows of
cartridges standing bullets up (copper jackets, lead soft points); the
three empty holes at the right end are where the clip was filled. In
front of the box lies one loaded steel stripper clip of five. Larger than
life (cartridges x1.3, the rifle's own 9,3 x 62 from _rifle_parts.py), so
it reads across a room: box 0.18 x 0.056 x 0.07 m, about 0.23 m in all.

Origin at the box centre (the game spins and bobs pickups); faces -Y.
Part: ammo_rifle_hunt.
"""
import math

import numpy as np
from mathutils import Vector

from artlib import kit, pixelfont
from artlib import materials as M
from artlib.geo import Part
from artlib.kit import R, T
from artlib.model import Model
from artlib.painter import Surface
from models import _rifle_parts as RP

S = 1.3                                   # cartridges larger than life
W, D, H = 0.18, 0.056, 0.07               # box outside
WALL = 0.003                              # cardboard wall
TRAY = H / 2 - 0.011                      # top of the partition inside
PITCH = 0.0205                            # cartridge spacing in the partition
COLS, ROWS = 8, 2
EMPTY = {(0, 6), (0, 7), (1, 7)}          # (row, column) holes without a cartridge (row 0 = front)
TIP_UP = 0.046                            # how far the bullet tips stand over the rim
LID_OPEN = 104.0                          # degrees from closed (past vertical, leaning back)
FLAP = 0.016
LABEL_W, LABEL_H = 0.166, 0.046
LABEL_Z = -0.003                          # label centre on the front
CLIP_C = Vector((0.004, -0.104, 0.0))     # centre of the lying clip (x, y)
CLIP_TURN = 28.0                          # degrees about Z


def _join(words, gaps):
    """Bold words side by side with a narrower gap than the font's space
    (the calibre has to fit the box front at the pickups' texel density);
    the words keep their common baseline."""
    cols = []
    for k, w in enumerate(words):
        b = pixelfont.render(w, bold=True)
        used = np.flatnonzero(b.any(axis=0))
        cols.append(b[:, used[0]:used[-1] + 1])
        if k < len(words) - 1:
            cols.append(np.zeros((b.shape[0], gaps[k]), dtype=bool))
    return pixelfont.trim(np.hstack(cols))


CALIBRE = _join(["9,", "3", "x", "62"], (1, 3, 3))    # 43 x 8 px: 0.134 m at 320 px/m
WORD = pixelfont.trim(pixelfont.render("NABOJE", bold=True))


def hole_xy(row, col):
    return (col - (COLS - 1) / 2) * PITCH, (row - (ROWS - 1) / 2) * PITCH


def _lid_matrix():
    """Closed lid -> open: hinge along the back top edge (y = D/2, z = H/2)."""
    return T(0, D / 2, H / 2) @ R('X', -LID_OPEN)


# --------------------------------------------------------------------------
# materials
# --------------------------------------------------------------------------

RAMPS = {
    # faded green card of an old ammunition box
    "card_green": M.hexramp("#10150f", "#182016", "#212c1e", "#2b3927", "#364631", "#42543b", "#4f6246",
                            "#5d7152", "#6c8160", "#7d916f"),
    # the label: yellowed cream paper, dark green ink
    "label": M.hexramp("#4d4433", "#655b47", "#7e735c", "#978c72", "#aea389", "#c2b89d", "#d3cab0"),
    "ink": M.hexramp("#0b0f0b", "#131a13", "#1c261b", "#263425"),
    "card_raw": M.hexramp("#2b241b", "#3a3125", "#4a3f30", "#5b4e3c", "#6c5e49", "#7d6e57", "#8e7f66"),
}


def _card(ctx, ramp, center, seed):
    s = Surface(ctx.N)
    shade = center + ctx.fbm(6.0, 3, seed) * 0.6 + M._dither(ctx, 0.45, seed + 1)
    fuzz = ctx.edge_soft(3.0) * (ctx.rand(seed + 2) > 0.4)
    shade += fuzz * 1.4
    shade -= ctx.cavity(3.0) * 2.0 + (1.0 - ctx.ao) * 3.5
    s.use_ramp(ramp, shade=shade)
    s.rough = np.full(ctx.N, 0.9)
    s.height = ctx.fbm(40.0, 2, seed + 3) * 0.0002
    return s


def _inward(ctx):
    """Texels on the inside faces of the box walls (normal toward the box)."""
    x, y = ctx.p[:, 0], ctx.p[:, 1]
    inside = (np.abs(x) < W / 2 - 0.0008) & (np.abs(y) < D / 2 - 0.0008) & (ctx.p[:, 2] > TRAY - 0.001)
    toward = (ctx.n[:, 0] * -x + ctx.n[:, 1] * -y) > 0.0
    return inside & toward & (np.abs(ctx.n[:, 2]) < 0.5)


def card(ctx, seed=611):
    """The box: green card, the edges rubbed through to the pale core, the
    inner faces of the walls raw grey-brown card."""
    s = _card(ctx, RAMPS["card_green"], 4.6, seed)
    rub = ctx.edge_soft(3.0) * 0.9 + np.clip(ctx.fbm(10.0, 3, seed + 5), 0, 1) * 0.6
    worn = (rub > 0.95) & (ctx.rand(seed + 6) > 0.25)
    s.use_ramp(RAMPS["card_raw"], mask=worn, shade=np.full(ctx.N, 4.6) + M._dither(ctx, 0.8, seed + 7))
    raw = _inward(ctx)
    sub = _card(ctx, RAMPS["card_raw"], 3.8, seed + 9)
    s.merge(M._select(sub, raw), raw)
    return s


def lid(ctx, seed=613):
    """Lid: green outside with the label printed on it, raw card inside."""
    s = _card(ctx, RAMPS["card_green"], 4.7, seed)
    rub = ctx.edge_soft(3.0) * 0.9 + np.clip(ctx.fbm(10.0, 3, seed + 5), 0, 1) * 0.6
    worn = (rub > 0.95) & (ctx.rand(seed + 6) > 0.25)
    s.use_ramp(RAMPS["card_raw"], mask=worn, shade=np.full(ctx.N, 4.6) + M._dither(ctx, 0.8, seed + 7))
    m = _lid_matrix()
    out_n = np.array((m.to_3x3() @ Vector((0, 0, 1))).normalized())
    outside = ctx.n @ out_n > 0.7
    inside = ctx.n @ out_n < -0.7
    sub = _card(ctx, RAMPS["card_raw"], 3.9, seed + 9)
    s.merge(M._select(sub, inside), inside)
    # printed label on the outside (its box-projected UVs are u = -x, v = z:
    # readable from behind, the top toward the lid's free edge)
    c = m @ Vector((0.0, -D / 2, 0.0))
    _print_label(ctx, s, outside, ctx.uvm[:, 0], ctx.uvm[:, 1], 0.0, c.z, seed + 11, printed=True, text=WORD)
    return s


def _print_label(ctx, s, face, u, v, cu, cv, seed, printed=False, text=None):
    """A cream label (LABEL_W x LABEL_H) centred on (cu, cv) of ``face``:
    a ruled border round ``text`` (bold "9,3 x 62" by default)."""
    du, dv = u - cu, v - cv
    t = ctx.texel
    area = face & (np.abs(du) < LABEL_W / 2) & (np.abs(dv) < LABEL_H / 2)
    if printed:
        # printed straight onto the lid: a cream panel
        s.use_ramp(RAMPS["label"], mask=area, shade=np.full(ctx.N, 4.6) + ctx.fbm(12.0, 2, seed) * 0.5
                   + M._dither(ctx, 0.6, seed + 1) - (1.0 - ctx.ao) * 2.5)
        s.rough = np.where(area, 0.85, s.rough)
    rule = area & ((np.abs(np.abs(du) - (LABEL_W / 2 - 2.5 * t)) < 0.5 * t) & (np.abs(dv) < LABEL_H / 2 - 2.0 * t)
                   | (np.abs(np.abs(dv) - (LABEL_H / 2 - 2.5 * t)) < 0.5 * t) & (np.abs(du) < LABEL_W / 2 - 2.0 * t))
    big = area & pixelfont.stamp(ctx, CALIBRE if text is None else text, cu, cv, u=u, v=v)
    ink = (rule | big) & (ctx.rand(seed + 2) > 0.04)
    s.use_ramp(RAMPS["ink"], mask=ink, shade=np.full(ctx.N, 1.6) + M._dither(ctx, 0.8, seed + 3))
    s.height = s.height - ink * 0.00005
    return s


def label(ctx, seed=617):
    """The paper label glued on the front: yellowed, foxed, a torn corner."""
    s = Surface(ctx.N)
    shade = 4.8 + ctx.fbm(10.0, 3, seed) * 0.6 + M._dither(ctx, 0.6, seed + 1) + ctx.edge(1.0) * 0.8
    fox = (ctx.fbm(25.0, 2, seed + 4) > 0.42) & (ctx.rand(seed + 5) > 0.5)
    shade -= fox * 1.2 + (1.0 - ctx.ao) * 2.5
    s.use_ramp(RAMPS["label"], shade=shade)
    s.rough = np.full(ctx.N, 0.85)
    s.height = ctx.fbm(50.0, 2, seed + 6) * 0.00008
    front = ctx.n[:, 1] < -0.7
    _print_label(ctx, s, front, ctx.uvm[:, 0], ctx.uvm[:, 1], 0.0, LABEL_Z, seed + 7)
    return s


def tray(ctx, seed=619):
    """The cardboard partition: raw card, a dark hole where a cartridge is gone."""
    s = _card(ctx, RAMPS["card_raw"], 3.6, seed)
    r_hole = 0.00575 * S
    for row, col in EMPTY:
        x, y = hole_xy(row, col)
        d = np.hypot(ctx.p[:, 0] - x, ctx.p[:, 1] - y)
        hole = (d < r_hole) & (ctx.n[:, 2] > 0.7)
        s.use_ramp(RAMPS["ink"], mask=hole, shade=np.full(ctx.N, 0.4) + d / r_hole * 0.8)
        lip = (d >= r_hole) & (d < r_hole + ctx.texel) & (ctx.n[:, 2] > 0.7)
        s.shade[lip] += 1.4
        s.height = s.height - hole * 0.002
    return s


def lead(ctx):
    s = Surface(ctx.N)
    shade = 5.4 + ctx.fbm(30.0, 2, 627) * 0.6 + M._dither(ctx, 0.6, 628) + ctx.edge(1.0) * 1.0 \
        - (1.0 - ctx.ao) * 3.0
    s.use_ramp(M.P["steel"], shade=shade)
    s.rough = np.full(ctx.N, 0.6)
    s.metal = np.full(ctx.N, 0.4)
    return s


FNS = {"card": card, "lid": lid, "label": label, "tray": tray,
       "cart": lambda c: M.brass(c, seed=621, tarnish_amount=1.0),
       "bullet": lambda c: M.brass(c, seed=623, ramp="copper", tarnish_amount=1.1), "lead": lead,
       "clip": lambda c: M.gun_steel(c, seed=625, center=6.4, wear=1.3)}


# --------------------------------------------------------------------------
# geometry
# --------------------------------------------------------------------------

def standing_round(p, x, y, z_base, lean):
    """The top of a cartridge standing in the partition (low-poly: neck,
    shoulder, round-nose bullet, lead point); the rest is under the tray."""
    d = Vector((math.sin(math.radians(lean[0])), math.sin(math.radians(lean[1])), 1.0)).normalized()
    b = Vector((x, y, z_base))
    cut = 0.6 * RP.CASE_L
    case = [(0.00573, cut), (0.00575, 0.047), (0.0050, 0.0505), (0.00495, RP.CASE_L)]
    L = RP.CASE_L - cut
    kit.seg(p, b + d * (cut * S), b + d * (RP.CASE_L * S), [(r * S, (t - cut) / L) for r, t in case], "cart",
            segments=6, caps=False)
    y0 = RP.CASE_L
    bl = [(0.00468, 0.0), (0.0041, 0.0105), (0.0021, 0.018)]
    kit.seg(p, b + d * (y0 * S), b + d * ((y0 + 0.018) * S), [(r * S, t / 0.018) for r, t in bl], "bullet",
            segments=6, caps=False)
    tip = p.lathe([(0.0021 * S, 0.0), (0.0015 * S, 0.003 * S), (0.0008 * S, 0.005 * S)], "lead", segments=6,
                  cap_bottom=False)
    p.move(tip, kit.align(b + d * ((y0 + 0.018) * S), b + d * (RP.OAL * S)))


def box(p):
    # bottom and the four walls (an open tray), the partition inside
    p.box((0, 0, -H / 2 + 0.0015), (W, D, 0.003), "card", bevel=0.001)
    for sy in (-1, 1):
        p.box((0, sy * (D / 2 - WALL / 2), 0), (W, WALL, H), "card", bevel=0.0012)
    for sx in (-1, 1):
        p.box((sx * (W / 2 - WALL / 2), 0, 0), (WALL, D - 2 * WALL + 0.0004, H - 0.0004), "card", bevel=0.0008)
    p.box((0, 0, TRAY - 0.002), (W - 2 * WALL - 0.0004, D - 2 * WALL - 0.0004, 0.004), "tray")
    # the label on the front
    p.box((0, -D / 2 - 0.0004, LABEL_Z), (LABEL_W, 0.0008, LABEL_H), "label")
    # lid: hinged on the back top edge, folded open; tuck flap bent forward
    m = _lid_matrix()
    lid_f = p.box((0, 0, 0), (W - 0.001, D, 0.0025), "lid", bevel=0.0009)
    p.move(lid_f, m @ T(0, -D / 2, 0.00125))
    flap = p.box((0, 0, 0), (W - 0.008, FLAP, 0.0022), "lid", bevel=0.0007)
    p.move(flap, m @ T(0, -D, 0.0011) @ R('X', 62.0) @ T(0, -FLAP / 2, 0))
    # the cartridges standing in the partition
    rng = np.random.default_rng(7)
    z_base = H / 2 + TIP_UP - RP.OAL * S
    for row in range(ROWS):
        for col in range(COLS):
            if (row, col) in EMPTY:
                continue
            x, y = hole_xy(row, col)
            standing_round(p, x, y, z_base, rng.uniform(-2.5, 2.5, 2))


def clip(p):
    """A loaded stripper clip lying in front of the box, bullets toward
    the viewer and a little right."""
    a = math.radians(CLIP_TURN)
    fwd = Vector((math.sin(a), -math.cos(a), 0.0))
    up = Vector((math.cos(a), math.sin(a), 0.0))
    length = (5 * RP.CLIP_PITCH + 0.0026) * S
    half_w = (2 * RP.RIM_R + 0.0026) * S / 2
    c = Vector((CLIP_C.x, CLIP_C.y, -H / 2 + half_w))
    bottom = c - up * (length / 2) - fwd * (RP.OAL * S / 2)
    RP.stripper_clip(p, bottom, up, fwd, n=5, s=S, segs=6)


def build():
    p = Part("ammo_rifle_hunt")
    box(p)
    clip(p)
    return Model("ammo_rifle_hunt", [p], FNS, ppm=320, ground=None, ao_dist=0.05, ao_rays=12, ao_stride=1,
                 preview_elevation=22.0,
                 preview_extra=[("label", (0.0, -0.05, 0.0), 0.11, -20.0, 18.0)])
