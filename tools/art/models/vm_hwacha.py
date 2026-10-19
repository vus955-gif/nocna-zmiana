"""First-person fire-arrow box (ognista skrzynia, hwacha): a handheld
Joseon singijeon launcher from the Korean room. A red-lacquered hardwood
"hive" with six iron launch tubes (2 rows x 3), black iron bands, brass
corner caps and a brass taegeuk medallion on each side, carried by two
D-handles bolted to the bands: the left one forward (front band), the
right one back (rear band) with the iron firing lever under the thumb;
each a cord-wrapped grip between iron bosses, a turned wooden knob on top.
Six fire-arrows pass through the tubes: the iron points and red paper
powder tubes stand 17 cm out of the mouths, the fletched shafts come out
of the back of the box. A slow-match cord hangs coiled on a peg on the
left side, its burning end held up behind the box. The lacquer still
shows the ghost of a gilded dragon chasing a pearl among clouds; the
master finish (texture set vm_hwacha_master) restores it in fresh gold
leaf on deep red and black lacquer, with engraved polished brass, bright
iron and red silk on the grips.

Viewmodel conventions as in vm_fists.py (faces +Y = Godot -Z, real
scale). The model is the box space below moved by VM_SHIFT = (0.03, 0.16,
-0.18): carried low and a little right, so at WeaponHolder.REST the player
looks down onto the lid from behind and left; the box sits in the lower
right, its front (the points peeking over the lid) toward the screen
centre, the left hand on its handle left of the box, the right fist and
sleeve in the bottom right corner. No framing offset needed in Godot.

Tubes are numbered left to right as the player sees them, bottom row
first: 1-3 bottom, 4-6 middle, 7-9 top (the "bigger volley" row).

Parts (pivots in model space; Blender (x, y, z) -> Godot (x, z, -y)):
    part        Blender pivot              Godot pivot                parent
    hwacha      (0, 0, 0)                  (0, 0, 0)                  -        box, tubes 1-6, bands, corners,
                                                                               medallions, handles, lever, peg
    rocket_1    (-0.02, 0.35, -0.1525)     (-0.02, -0.1525, -0.35)    hwacha   fire-arrow in tube 1
    rocket_2    ( 0.03, 0.35, -0.1525)     ( 0.03, -0.1525, -0.35)    hwacha
    rocket_3    ( 0.08, 0.35, -0.1525)     ( 0.08, -0.1525, -0.35)    hwacha
    rocket_4    (-0.02, 0.35, -0.1025)     (-0.02, -0.1025, -0.35)    hwacha
    rocket_5    ( 0.03, 0.35, -0.1025)     ( 0.03, -0.1025, -0.35)    hwacha
    rocket_6    ( 0.08, 0.35, -0.1025)     ( 0.08, -0.1025, -0.35)    hwacha
    upg_box9    (0.03, 0.35, -0.05)        (0.03, -0.05, -0.35)       hwacha   "bigger volley": third row of 3
                                                                               tubes on the lid, extra bands
    rocket_7    (-0.02, 0.35, -0.05)       (-0.02, -0.05, -0.35)      upg_box9
    rocket_8    ( 0.03, 0.35, -0.05)       ( 0.03, -0.05, -0.35)      upg_box9
    rocket_9    ( 0.08, 0.35, -0.05)       ( 0.08, -0.05, -0.35)      upg_box9
    upg_fuses   (0.03, 0.01, -0.1275)      (0.03, -0.1275, -0.01)     hwacha   "quick fuse": brass igniter rail
                                                                               and caps on the back of all 9 tubes
    sleeve_r/_l the wrist of its hand                                 hwacha   the sleeves (the game turns them
                                                                               toward the elbows; markers Wrist_*,
                                                                               Grip_*, Elbow_*: artlib/hands.py arm())
    fuse        (-0.0775, 0.11, -0.1115)   (-0.0775, -0.1115, -0.11)  hwacha   slow-match coil on its peg,
                                                                               glowing ember at the end
    hand_r      (0.175, 0.064, -0.1275)    (0.175, -0.1275, -0.064)   hwacha   right fist on the rear right
                                                                               handle (pivot on the grip axis)
    hand_l      (-0.115, 0.264, -0.1275)   (-0.115, -0.1275, -0.264)  hwacha   left fist on the front left handle
Each rocket's pivot is its tube's mouth centre: slide it back along
local -Y (Godot +Z) up to 0.06 m (ROCKET_SINK) and it sinks into the tube;
hide it when fired. The shaft stretch that can never show (inside the
box, even sunk 0.06 m) is left out of the mesh.

Markers (empties):
    Muzzle      (0.03, 0.35, -0.1275)      Godot (0.03, -0.1275, -0.35)  root  centre of the base tube face
    Tube_1..6   = the rocket_1..6 pivots                                 root  tube mouths
    Tube_7..9   = the rocket_7..9 pivots                                 upg_box9
    Ember       (-0.082, 0.0, -0.051)      Godot (-0.082, -0.051, 0.0)   fuse  the glowing match tip
The base box looks complete without the two upgrades; upg_fuses' top
three caps rest on saddles on the lid behind the top-row box, so they
read as an igniter rack even before the bigger volley is bought.
"""
import math
import os

import bmesh
import numpy as np
from mathutils import Matrix, Vector

from artlib import hands, kit
from artlib import materials as M
from artlib.geo import Part
from artlib.kit import R, T
from artlib.model import Model
from artlib.painter import Surface
from models import _hwacha_parts as HP
from models.vm_fists import FNS as HAND_FNS
from models.vm_pistol import CAM, LOOK, bore

VM_SHIFT = Vector((0.03, 0.16, -0.18))      # box space -> viewmodel space (carried low, right)

BX = 0.095                                  # half width of the box
Y0, Y1 = -0.15, 0.16                        # back / front of the base box
Z1, Z2 = 0.105, 0.155                       # top of the base box / of the top-row box
Y9 = -0.115                                 # back of the top-row box (its igniter caps sit behind it)
XC = (-0.05, 0.0, 0.05)                     # tube columns, left to right
ZR = (0.0275, 0.0775, 0.13)                 # tube rows, bottom to top
YM = Y1 + 0.03                              # tube mouths
RF, RT, RL, RB = 0.0192, 0.0168, 0.0186, 0.0136   # tube flange, body, lip, bore radii
BEV = 0.006
BAND_Y = (-0.10, 0.0, 0.10)
BAND_PROF = [(0.0, 0.0), (0.0, 0.003), (0.018, 0.003), (0.018, 0.0)]
MEDAL_Y, MEDAL_Z, MEDAL_R = 0.062, Z1 / 2, 0.019
CAP_S, CAP_O = 0.028, 0.0025                # brass corner caps: size, how far they stand proud
# side handles (D-handles on the iron bands): left on the front band, right on the rear one
HANDLE_Y = {-1: BAND_Y[2], 1: BAND_Y[0]}     # side -> band centre y
HANDLE_OUT = 0.05                            # grip axis this far out from the box side
ARM_Z = (0.0135, 0.0915)                     # bottom / top arm heights
GRIP_Z = (0.019, 0.086)                      # cord-wrapped grip between the arms
GRIP_LEAN = 0.008                            # the grip's top leans forward this much
COIL_C = Vector((-BX - 0.0036, -0.05, 0.047))
COIL_R, CORD_R, COIL_TURNS = 0.028, 0.0032, 2.6
PEG = Vector((-BX + 0.0005, -0.05, 0.0685))
TUBES = [(XC[c], ZR[r]) for r in range(3) for c in range(3)]     # tube k+1 = TUBES[k]
FUSE_END = [Vector(v) for v in ((-0.1045, -0.094, 0.077), (-0.1055, -0.113, 0.084), (-0.106, -0.128, 0.09),
                                (-0.107, -0.143, 0.1), (-0.1085, -0.152, 0.112))]
CHAR_END = Vector((-0.1105, -0.1575, 0.1225))
EMBER_TIP = Vector((-0.1118, -0.1602, 0.1288))
ARROW_L = 0.58                              # the fire-arrows pass through the box: point and powder
#                                             tube in front, fletching out of the back
ARROW_TIP = 0.17                            # how far the point stands out of the tube mouth: the
#                                             red powder tube sits wholly in front of it
PREVIEW = os.environ.get("HWACHA_VIEW", "")       # "base": leave the upgrades out (iteration only)


def _corners():
    """(corner, inward signs, inside test) of every brass corner cap."""
    def in_base(q):
        return abs(q.x) < BX - 1e-4 and Y0 + 1e-4 < q.y < Y1 - 1e-4 and 1e-4 < q.z < Z1 - 1e-4

    def in_top(q):
        return abs(q.x) < BX - 1e-4 and Y9 + 1e-4 < q.y < Y1 - 1e-4 and Z1 + 1e-4 < q.z < Z2 - 1e-4

    base = [((sx * BX, y, z), (-sx, -1 if y > 0 else 1, -1 if z > 0 else 1), in_base)
            for sx in (-1, 1) for y in (Y0, Y1) for z in (0.0, Z1)]
    top = [((sx * BX, Y1, Z2), (-sx, -1, -1), in_top) for sx in (-1, 1)]
    return base, top


BASE_CORNERS, TOP_CORNERS = _corners()
CORNER_PTS = np.array([c for c, _, _ in BASE_CORNERS + TOP_CORNERS])


# --------------------------------------------------------------------------
# materials
# --------------------------------------------------------------------------

def _g(ctx):
    """Texel positions in box space (the model minus VM_SHIFT)."""
    return ctx.p - np.asarray(VM_SHIFT)


def _motif(ctx):
    """Gold-leaf design of the lacquer: (fill, line, dark) per texel."""
    g = _g(ctx)
    n = ctx.n
    tx = ctx.texel
    N = ctx.N
    fill = np.zeros(N, dtype=bool)
    line = np.zeros(N, dtype=bool)
    dark = np.zeros(N, dtype=bool)
    m0 = 0.017                                   # stays inside the black border of the master finish
    head_end = BAND_Y[2] - 0.012                 # the pearl ends before the front band

    def put(m, res):
        f, l_, d = res
        fill[m] |= f
        line[m] |= l_
        dark[m] |= d

    top = n[:, 2] > 0.9
    for zt, ys, flip in ((Z1, Y0, 1.0), (Z2, BAND_Y[0] + 0.012, -1.0)):
        m = top & (np.abs(g[:, 2] - zt) < 0.003)
        if m.any():
            put(m, HP.dragon(g[m, 1] - ys - m0, flip * g[m, 0], head_end - ys - m0, 2 * BX - 2 * m0, tx))
            fr = m & (g[:, 1] > BAND_Y[2] + 0.009)
            if fr.any():
                y_mid = (BAND_Y[2] + 0.009 + Y1 - m0) / 2
                line[fr] |= HP.cloud_frieze(g[fr, 0] + BX - m0, g[fr, 1] - y_mid, 2 * BX - 2 * m0,
                                            Y1 - m0 - BAND_Y[2] - 0.009, tx)
    side = np.abs(n[:, 0]) > 0.9
    m = side & (g[:, 2] < Z1)
    if m.any():
        H = Z1 - 2 * m0
        W = 0.085 * H
        hc = MEDAL_Y - MEDAL_R - 2.2 * W              # the dragon reaches for the taegeuk medallion
        put(m, HP.dragon(g[m, 1] - Y0 - m0, g[m, 2] - Z1 / 2, hc + 4.0 * W - Y0 - m0, H, tx))
    back = n[:, 1] < -0.9
    if back.any():
        d = np.full(N, np.inf)
        for x, z in TUBES:
            d = np.minimum(d, np.hypot(g[:, 0] - x, g[:, 2] - z))
        line |= back & (np.abs(d - 0.0118) < 0.6 * tx)
    front = n[:, 1] > 0.9
    if front.any():
        d = np.full(N, np.inf)
        for x, z in TUBES:
            d = np.minimum(d, np.hypot(g[:, 0] - x, g[:, 2] - z))
        line |= front & (np.abs(d - RF - 0.0035) < 0.6 * tx)
    return fill, line, dark


def lacquer(ctx, seed=741):
    """The museum piece: old cinnabar lacquer, crazed, rubbed through to
    the black undercoat on the edges and chipped to the wood on corners;
    the gilding is only a faded ghost."""
    s = Surface(ctx.N)
    shade = 4.5 + ctx.fbm(2.5, 3, seed) * 0.8 + ctx.fbm(14.0, 2, seed + 1) * 0.35 + M._dither(ctx, 0.6, seed + 2)
    f1, f2, _ = ctx.worley(70.0, seed + 3)
    crack = ((f2 - f1) < 0.05) & (ctx.fbm(4.0, 2, seed + 4) > -0.2)
    shade -= crack * 1.1
    shade += ctx.edge(1.0) * 1.0
    shade -= ctx.cavity(3.0) * 2.0 + (1.0 - ctx.ao) * 3.5
    s.use_ramp(HP.RAMPS["lacquer"], shade=shade)
    fill, line, dark = _motif(ctx)
    ghost = (fill | line) & ~dark & (ctx.fbm(14.0, 3, seed + 5) > -0.08) & (ctx.rand(seed + 6) > 0.18)
    s.use_ramp(M.P["paint_ochre"], mask=ghost, shade=2.9 + ctx.fbm(9.0, 2, seed + 7) * 0.9
               + M._dither(ctx, 0.9, seed + 8) - (1.0 - ctx.ao) * 2.0 - crack * 1.0)
    rub = ctx.edge_soft(4.0) * 0.9 + np.clip(ctx.fbm(6.0, 3, seed + 9), 0, 1) * 0.75
    under = rub > 0.82
    s.use_ramp(HP.RAMPS["lacquer_black"], mask=under, shade=np.full(ctx.N, 2.6) + M._dither(ctx, 1.0, seed + 10)
               + ctx.edge(1.0) * 1.2)
    chip = (rub > 1.02) & (ctx.fbm(26.0, 2, seed + 11) > 0.05)
    wood = M.wood_dark(ctx, seed=seed + 12)
    s.rough = 0.34 + np.clip(ctx.fbm(3.0, 3, seed + 13), 0, 1) * 0.22 + crack * 0.2
    s.rough = np.where(ghost, 0.55, s.rough)
    s.rough = np.where(under, 0.42, s.rough)
    s.metal = np.where(ghost, 0.15, 0.0)
    s.height = ctx.fbm(40.0, 2, seed + 14) * 0.00004 - crack * 0.00015
    s.merge(M._select(wood, chip), chip)
    s.height = np.where(chip, -0.0005, s.height)
    return s


def lacquer_master(ctx, seed=751):
    """Master finish: deep glossy red lacquer in black lacquer borders, a
    gold pinstripe, and the dragon, pearl and clouds in fresh gold leaf."""
    s = Surface(ctx.N)
    tx = ctx.texel
    shade = 5.4 + ctx.fbm(3.0, 2, seed) * 0.35 + M._dither(ctx, 0.45, seed + 1) + ctx.edge(1.0) * 1.4
    shade -= ctx.cavity(3.0) * 1.2 + (1.0 - ctx.ao) * 2.2
    s.use_ramp(HP.RAMPS["lacquer_deep"], shade=shade)
    border = ctx.convex < 5.5 * tx
    s.use_ramp(HP.RAMPS["lacquer_black"], mask=border, shade=np.full(ctx.N, 3.3) + ctx.edge(1.0) * 2.4
               + M._dither(ctx, 0.5, seed + 2) - (1.0 - ctx.ao) * 1.5)
    pin = (ctx.convex >= 6.5 * tx) & (ctx.convex < 7.5 * tx)
    fill, line, dark = _motif(ctx)
    inner = ctx.convex > 8.5 * tx
    gold = pin | ((fill | line) & ~dark & inner)
    s.use_ramp(M.P["gold"], mask=gold, shade=6.6 + ctx.fbm(10.0, 2, seed + 3) * 0.7 + M._dither(ctx, 0.9, seed + 4)
               + ctx.edge(1.0) * 1.0 - (1.0 - ctx.ao) * 2.4)
    deep = fill & dark & inner
    s.shade[deep] -= 1.2
    s.rough = np.where(gold, 0.22, np.where(border, 0.1, 0.12)) + ctx.rand(seed + 5) * 0.03
    s.metal = np.where(gold, 1.0, 0.0)
    s.height = gold * 0.00008 + ctx.fbm(30.0, 2, seed + 6) * 0.00002
    return s


def _corner_marks(ctx, g):
    """Engraved border line and a domed nail on each face of the corner caps."""
    tx = ctx.texel
    d = np.linalg.norm(g[:, None, :] - CORNER_PTS[None], axis=2)
    k = np.argmin(d, axis=1)
    near = np.all(np.abs(g - CORNER_PTS[k]) < CAP_S + 0.0005, axis=1)
    flat = np.max(np.abs(ctx.n), axis=1) > 0.95
    border = near & flat & (ctx.convex >= 2.0 * tx) & (ctx.convex < 3.0 * tx)
    off = np.abs(g - CORNER_PTS[k])
    ax = np.argmax(np.abs(ctx.n), axis=1)
    inplane = np.where((np.arange(3)[None] == ax[:, None]), np.inf, off)
    srt = np.sort(inplane, axis=1)[:, :2]
    nail_r = np.hypot(srt[:, 0] - 0.0135, srt[:, 1] - 0.0135)
    nail = near & flat & (nail_r < 0.0028)
    return border, nail, nail_r


def _medallion(ctx, g):
    """Taegeuk medallion on the box sides: (mask, ring, s_line, red half)."""
    tx = ctx.texel
    m = (np.abs(g[:, 0]) > BX + 0.0012) & (np.abs(ctx.n[:, 0]) > 0.9)
    u = (g[:, 1] - MEDAL_Y) * -np.sign(g[:, 0])
    v = g[:, 2] - MEDAL_Z
    r = np.hypot(u, v)
    m &= r < MEDAL_R
    Rr = 0.0128
    ring = m & (np.abs(r - 0.0152) < 0.6 * tx)
    in_a = np.hypot(u + Rr / 2, v) < Rr / 2
    in_b = np.hypot(u - Rr / 2, v) < Rr / 2
    da = np.where(v <= 0, np.abs(np.hypot(u + Rr / 2, v) - Rr / 2), np.inf)
    db = np.where(v >= 0, np.abs(np.hypot(u - Rr / 2, v) - Rr / 2), np.inf)
    sline = m & (np.minimum(da, db) < 0.6 * tx) & (r < Rr)
    rim = m & (np.abs(r - Rr) < 0.6 * tx)
    red = m & (r < Rr) & (((v > 0) & ~in_b) | ((v <= 0) & in_a))
    return m, ring | rim, sline, red, r < Rr


def brass_hw(ctx, seed=761):
    """Old museum brass: tarnished, engraved borders on the corner caps,
    nails, the taegeuk medallion with a little enamel left in it."""
    s = M.brass(ctx, seed=seed, tarnish_amount=2.3)
    g = _g(ctx)
    border, nail, nail_r = _corner_marks(ctx, g)
    s.shade[border] -= 2.6
    s.shade[nail] += 1.5 - nail_r[nail] / 0.0028 * 2.0
    s.height = s.height - border * 0.0002 + nail * (0.0028 - nail_r) * 0.25
    m, ring, sline, red, disc = _medallion(ctx, g)
    s.shade[ring | sline] -= 3.0
    s.height = s.height - (ring | sline) * 0.0002
    left = disc & ~ring & ~sline & (ctx.fbm(22.0, 2, seed + 1) > 0.15)
    s.use_ramp(HP.RAMPS["lacquer"], mask=left & red, shade=np.full(ctx.N, 3.4) + M._dither(ctx, 1.0, seed + 2))
    s.use_ramp(HP.RAMPS["enamel_blue"], mask=left & ~red, shade=np.full(ctx.N, 2.4) + M._dither(ctx, 1.0, seed + 3))
    s.metal = np.where(left, 0.0, s.metal)
    s.rough = np.where(left, 0.6, s.rough)
    return s


def brass_master(ctx, seed=771):
    """Polished brass with scroll engraving; cloisonne taegeuk."""
    s = M.brass(ctx, seed=seed, tarnish_amount=0.25, grain=0.5)
    s.shade += 0.8
    g = _g(ctx)
    u, v = ctx.uvm[:, 0] / 0.011, ctx.uvm[:, 1] / 0.011
    cu, cv = np.floor(u), np.floor(v)
    fu, fv = u - cu - 0.5, v - cv - 0.5
    r = np.hypot(fu, fv)
    a = np.arctan2(fv, fu)
    turn = M.noise.rand_cells((cu * 31 + cv).astype(np.int64), 5) > 0.5
    spiral = np.abs(np.mod(r * 8.0 - np.where(turn, a, -a) / np.pi * 1.5, 1.0) - 0.5) < 0.13
    flat = np.max(np.abs(ctx.n), axis=1) > 0.95
    border, nail, nail_r = _corner_marks(ctx, g)
    m, ring, sline, red, disc = _medallion(ctx, g)
    eng = (spiral & (r < 0.47) & flat & ~m) | border
    s.shade[eng] -= 2.6
    s.shade[nail] += 2.0 - nail_r[nail] / 0.0028 * 2.0
    s.height = s.height - eng * 0.00018 + nail * (0.0028 - nail_r) * 0.25
    s.rough = np.clip(s.rough - 0.08, 0.08, 1.0)
    cell = disc & ~ring & ~sline
    s.use_ramp(HP.RAMPS["lacquer_deep"], mask=cell & red, shade=np.full(ctx.N, 6.0) + M._dither(ctx, 0.6, seed + 1))
    s.use_ramp(HP.RAMPS["enamel_blue"], mask=cell & ~red, shade=np.full(ctx.N, 4.2) + M._dither(ctx, 0.6, seed + 2))
    s.shade[(ring | sline)] += 1.0
    s.metal = np.where(cell, 0.0, 1.0)
    s.rough = np.where(cell, 0.08, s.rough)
    return s


def iron_hw(ctx, seed=781):
    """Blackened wrought iron: hammer marks, bright worn edges, rust."""
    s = M.iron(ctx, seed=seed)
    dp = M.dents(ctx, seed + 1, freq=60.0, amount=0.4, radius=0.4)
    s.shade += 0.7 - dp * 0.8 + ctx.edge(1.0) * 1.0
    s.height = -dp * 0.0004
    s.rough = np.clip(s.rough - 0.05 + dp * 0.05, 0, 1)
    return s


def iron_master(ctx, seed=783):
    return M.steel(ctx, seed=seed, ramp="steel", center=8.4, dent=0.0, rust=0.0, polish=0.13, scratch=0.04)


def _rivets(ctx, s):
    """Round rivet heads every 35 mm along the bands' outer face."""
    du = (np.mod(ctx.uvm[:, 0] / 0.035 + 0.5, 1.0) - 0.5) * 0.035
    dv = ctx.uvm[:, 1] - 0.012
    rr = np.hypot(du, dv)
    riv = rr < 0.0027
    s.shade[riv] += 1.6 + (dv[riv] > 0) * 0.8 - rr[riv] / 0.0027 * 1.2
    s.height = s.height + np.where(riv, (0.0027 - rr) * 0.3, 0.0)
    rim = (rr >= 0.0027) & (rr < 0.0027 + ctx.texel)
    s.shade[rim] -= 1.0
    return s


def band(ctx):
    return _rivets(ctx, iron_hw(ctx, seed=785))


def band_master(ctx):
    return _rivets(ctx, iron_master(ctx, seed=787))


def wood(ctx, seed=791):
    """Stock: dark jujube-red hardwood, oiled, handled."""
    s = M._wood_core(ctx, M.P["walnut_stock"], 4.1, seed, ring_freq=14.0, contrast=1.0)
    M._age(ctx, s, cavity=2.0, ao=3.5, edge=1.6)
    s.rough = 0.4 + np.clip(ctx.fbm(3.0, 3, seed + 5), 0, 1) * 0.2 + ctx.cavity(3.0) * 0.3
    return s


def wood_master(ctx, seed=793):
    """Master finish of the stock: black lacquer with a gold pinstripe."""
    s = Surface(ctx.N)
    tx = ctx.texel
    shade = 3.2 + ctx.fbm(3.0, 2, seed) * 0.3 + M._dither(ctx, 0.4, seed + 1) + ctx.edge(1.0) * 2.4
    shade -= ctx.cavity(3.0) * 1.0 + (1.0 - ctx.ao) * 1.6
    s.use_ramp(HP.RAMPS["lacquer_black"], shade=shade)
    pin = (ctx.convex >= 4.0 * tx) & (ctx.convex < 5.0 * tx)
    s.use_ramp(M.P["gold"], mask=pin, shade=np.full(ctx.N, 6.6) + M._dither(ctx, 0.8, seed + 2))
    s.rough = np.where(pin, 0.22, 0.1)
    s.metal = np.where(pin, 1.0, 0.0)
    return s


def _wrap(ctx, s, ramp, center, seed):
    """Diagonal cord wrapping round a grip."""
    k = np.mod(ctx.uvm[:, 0] / 0.012 + ctx.uvm[:, 1] / 0.009, 1.0)
    band_ = np.abs(k - 0.5) * 2.0
    gap = band_ > 0.86
    shade = center + (0.6 - band_) * 1.6 + ctx.fbm(20.0, 2, seed) * 0.5 + M._dither(ctx, 0.5, seed + 1)
    shade -= gap * 2.2 + (1.0 - ctx.ao) * 3.0
    s.use_ramp(ramp, shade=shade)
    s.height = (0.6 - band_) * 0.0005 - gap * 0.0004
    return s


def grip(ctx, seed=795):
    s = _wrap(ctx, Surface(ctx.N), HP.RAMPS["cord"], 3.4, seed)
    s.rough = np.full(ctx.N, 0.85)
    return s


def grip_master(ctx, seed=797):
    s = _wrap(ctx, Surface(ctx.N), HP.RAMPS["silk"], 4.6, seed)
    s.rough = np.full(ctx.N, 0.45)
    return s


def ember_tipped_char(ctx):
    return HP.char(ctx, tip=tuple(EMBER_TIP + VM_SHIFT))


FNS = dict(HAND_FNS, lacquer=lacquer, band=band, iron=iron_hw, brass=brass_hw, bore=bore, wood=wood, grip=grip,
           cord=HP.cord, char=ember_tipped_char, ember=HP.ember, nozzle=lambda c: HP.nozzle(c, hot=False),
           **HP.ARROW_FNS)
MASTER = dict(FNS, lacquer=lacquer_master, band=band_master, iron=iron_master, brass=brass_master,
              wood=wood_master, grip=grip_master, head=lambda c: HP.arrowhead(c, polish=True))


# --------------------------------------------------------------------------
# geometry (box space: box bottom at z = 0, tube face at y = Y1)
# --------------------------------------------------------------------------

PERM = Matrix(((0.0, 0.0, 1.0, 0.0), (1.0, 0.0, 0.0, 0.0), (0.0, 1.0, 0.0, 0.0), (0.0, 0.0, 0.0, 1.0)))


def _prism_x(p, outline, half, mat, bevel=0.0):
    """Prism from a side outline [(y, z), ...] (counter-clockwise), x = -half..half."""
    faces = p.ngon_prism(outline, -half, half, mat, bevel=bevel)
    p.move(faces, PERM)
    return faces


def _disc(p, centre, direction, r, thick, mat, segments=16, inset=0.0006):
    """A flat plate (washer, medallion) standing on a surface, facing ``direction``."""
    faces = p.lathe([(r, 0.0), (r, thick * 0.55), (r * 0.88, thick)], mat, segments=segments, cap_bottom=False,
                    cap_top=True, smooth=True, phase=math.pi / segments)
    d = Vector(direction).normalized()
    a = Vector(centre) - d * inset
    p.move(faces, kit.align(a, a + d))
    return faces


def _octagon(x0, x1, z0, z1, c):
    """Chamfered rectangle (the box section), clockwise seen from -Y."""
    return [(x0 + c, z1), (x1 - c, z1), (x1, z1 - c), (x1, z0 + c), (x1 - c, z0), (x0 + c, z0), (x0, z0 + c),
            (x0, z1 - c)]


def tube(p, x, z):
    """Iron launch tube standing out of the face: flange, body, lip, and a
    dark bore 24 mm deep (ending in front of the box face)."""
    yb = Y1 - 0.004
    L = YM - yb
    prof = [(RF, 0.0), (RF, 0.011), (RT, 0.0155), (RT, L - 0.0075), (RL, L - 0.0055), (RL, L), (RB, L),
            (RB, L - 0.024)]
    faces = p.lathe(prof, "iron", segments=8, cap_bottom=False, cap_top=True, smooth=True, phase=math.pi / 8)
    dark = p.slot("bore")
    for f in faces[48:]:
        f.material_index = dark
    p.move(faces, kit.align((x, yb, z), (x, YM, z)))
    return faces


def corner_cap(p, corner, inward, inside):
    """Brass cap over a box corner: a bevelled cube cut by the three box
    planes, the part buried in the wood removed."""
    before = set(p.bm.faces)
    c = Vector(corner) + Vector(inward) * ((CAP_S - CAP_O) / 2)
    p.box(tuple(c), (CAP_S + CAP_O,) * 3, "brass")
    for axis in range(3):
        new = [f for f in p.bm.faces if f not in before]
        geom = list({e for f in new for e in f.edges}) + list({v for f in new for v in f.verts}) + new
        no = Vector((0.0, 0.0, 0.0))
        no[axis] = 1.0
        bmesh.ops.bisect_plane(p.bm, geom=geom, dist=1e-7, plane_co=Vector(corner), plane_no=no)
    new = [f for f in p.bm.faces if f not in before]
    kit.keep(p, new, lambda q: not inside(q))


def hole(p, x, y, z):
    """Iron grommet round the back opening of a tube (the arrow's shaft
    comes out through it): a ring with a dark, shallow bore."""
    prof = [(0.0088, 0.0), (0.0088, 0.0014), (0.0076, 0.0024), (0.0058, 0.0024), (0.0058, 0.0012)]
    segs = 6
    faces = p.lathe(prof, "iron", segments=segs, cap_bottom=False, cap_top=True, smooth=True, phase=math.pi / segs)
    dark = p.slot("bore")
    for f in faces[3 * segs:]:
        f.material_index = dark
    a = Vector((x, y + 0.0005, z))
    p.move(faces, kit.align(a, a + Vector((0, -1, 0))))


def hive(p):
    p.box((0, (Y0 + Y1) / 2, Z1 / 2), (2 * BX, Y1 - Y0, Z1), "lacquer", bevel=BEV)
    for k in range(6):
        tube(p, *TUBES[k])
        hole(p, TUBES[k][0], Y0, TUBES[k][1])
    for y in BAND_Y:
        p.sweep(BAND_PROF, _octagon(-BX, BX, 0.0, Z1, BEV), "band", y0=y + 0.009, closed=True)
    for corner, inward, inside in BASE_CORNERS:
        corner_cap(p, corner, inward, inside)
    for sx in (-1, 1):
        _disc(p, (sx * BX, MEDAL_Y, MEDAL_Z), (sx, 0, 0), MEDAL_R, 0.003, "brass", segments=12)


def grip_axis(sx):
    """(bottom, top) of the cord-wrapped grip of the side handle on side sx."""
    x = sx * (BX + HANDLE_OUT)
    y = HANDLE_Y[sx]
    return Vector((x, y, GRIP_Z[0])), Vector((x, y + GRIP_LEAN, GRIP_Z[1]))


def handles(p):
    """A D-handle on each side, bolted to an iron band: two forged arms
    and a vertical cord-wrapped grip between iron ferrules, a turned
    wooden knob on top. The right one carries the firing lever under the
    thumb. Left handle forward (front band), right handle back (rear band)."""
    for sx in (-1, 1):
        g0, g1 = grip_axis(sx)
        y = HANDLE_Y[sx]
        for z, top in zip(ARM_Z, (False, True)):
            yy = y + (GRIP_LEAN if top else 0.0) * 0.5
            p.box((sx * (BX + HANDLE_OUT / 2 + 0.002), yy, z), (HANDLE_OUT + 0.004, 0.013, 0.0075), "iron",
                  bevel=0.0018)
            kit.seg(p, (sx * (BX + 0.013), yy, z + 0.0034), (sx * (BX + 0.013), yy, z + 0.0056),
                    [(0.0029, 0.0), (0.0018, 1.0)], "iron", segments=6)     # rivet through the band
            # boss round the grip end
            c = g1 if top else g0
            kit.seg(p, c - Vector((0, 0, 0.0055)), c + Vector((0, 0, 0.0055)), [(0.0126, 0.0), (0.0126, 1.0)],
                    "iron", segments=8)
        kit.seg(p, g0, g1, [(0.0132, 0.0), (0.0156, 0.1), (0.0160, 0.5), (0.0156, 0.9), (0.0132, 1.0)], "grip",
                segments=10)
        d = (g1 - g0).normalized()
        kit.seg(p, g1 + d * 0.005, g1 + d * 0.016, [(0.0088, 0.0), (0.0098, 0.45), (0.0045, 1.0)], "wood",
                segments=8)                                                 # turned knob
    # firing lever on the right handle's top arm, its tail under the thumb
    g0, g1 = grip_axis(1)
    piv = Vector((BX + 0.02, HANDLE_Y[1], ARM_Z[1] + 0.0055))
    kit.seg(p, piv - Vector((0.0045, 0, 0)), piv + Vector((0.0045, 0, 0)), [(0.0036, 0), (0.0036, 1)], "iron",
            segments=6)
    lever = p.box((0, 0, 0), (0.0055, 0.034, 0.0042), "iron", bevel=0.0012)
    p.move(lever, T(*piv) @ R('X', -22.0) @ T(0, -0.015, 0.002))
    # peg for the slow-match coil (left side)
    kit.seg(p, PEG, PEG + Vector((-0.027, 0, 0.002)), [(0.0034, 0), (0.0034, 0.85), (0.005, 0.9), (0.0045, 1.0)],
            "iron", segments=8)


def rocket(p, x, z, k):
    """A whole fire-arrow in its tube: point and paper powder tube out of the
    mouth, the bamboo shaft and fletching out of the back of the box."""
    yc = YM + ARROW_TIP - ARROW_L / 2                 # the arrow's centre (box space)
    # the shaft inside the box never shows, even sunk ROCKET_SINK (0.06 m) back into its tube
    back = Y0 if k < 6 else Y9
    gap = (back + 0.068 - yc, YM - 0.006 - yc)
    HP.arrow_full(p, T(x, yc, z), L=ARROW_L, rt=0.0098, rs=0.0034, head_len=0.031,
                  nose=0.010, tube_len=0.06, seg=6, fletch_len=0.055, fletch_h=0.012, hidden_back=False,
                  vane_phase=(k * 37.0) % 120.0, shaft_gap=gap)


def box9(p):
    """The bigger volley: a third row of three tubes on the lid."""
    faces = p.box((0, (Y9 + Y1) / 2, (Z1 + Z2) / 2), (2 * BX, Y1 - Y9, Z2 - Z1), "lacquer", bevel=BEV)
    kit.keep(p, faces, lambda q: q.z > Z1 + 0.0004)          # drop the hidden bottom
    for k in range(6, 9):
        tube(p, *TUBES[k])
        hole(p, TUBES[k][0], Y9, TUBES[k][1])
    u_path = [(-(BX - BEV) + 0.003, Z1 - 0.003), (-BX, Z1 + BEV), (-BX, Z2 - BEV), (-(BX - BEV), Z2),
              (BX - BEV, Z2), (BX, Z2 - BEV), (BX, Z1 + BEV), (BX - BEV - 0.003, Z1 - 0.003)]
    for y in BAND_Y:
        p.sweep(BAND_PROF, u_path, "band", y0=y + 0.009, closed=False)
    for corner, inward, inside in TOP_CORNERS:
        corner_cap(p, corner, inward, inside)


def igniter(p, x, yb, z):
    """Brass collar round a tube's back opening (the shaft passes through
    it) with a domed igniter cap standing on top."""
    prof = [(0.0064, 0.0), (0.0064, 0.0085), (0.0106, 0.0094), (0.0113, 0.0)]
    faces = p.lathe(prof, "brass", segments=6, cap_bottom=False, cap_top=False, smooth=False, phase=math.pi / 6)
    a = Vector((x, yb + 0.0005, z))
    p.move(faces, kit.align(a, a + Vector((0, -1, 0))))
    kit.seg(p, (x, yb - 0.004, z + 0.0095), (x, yb - 0.0085, z + 0.0158),
            [(0.0027, 0.0), (0.0033, 0.6), (0.0018, 1.0)], "brass", segments=6)


def fuses(p):
    """The quick fuse: brass igniters on the back of all nine tubes, joined
    row by row by a brass flash tube; saddles carry the top row's igniters
    on the lid behind the top-row box."""
    for k in range(9):
        x, z = TUBES[k]
        igniter(p, x, Y0 if k < 6 else Y9, z)
    for r in range(3):
        yb = Y0 if r < 2 else Y9
        zr = ZR[r] + 0.0158
        yr = yb - 0.0085
        p.tube([(-0.072, yr, zr), (0.072, yr, zr)], 0.0019, "brass", sides=6, smooth=True)
        for sx in (-1, 1):
            if r == 2:
                p.box((sx * 0.072, yb - 0.006, (Z1 + zr) / 2), (0.006, 0.006, zr - Z1), "brass")
            else:
                p.box((sx * 0.072, yb - 0.0045, zr), (0.005, 0.009, 0.005), "brass")
    # flash tube up the right-hand side to the top row, over the lid
    p.tube([(0.072, Y0 - 0.0085, ZR[0] + 0.0158), (0.072, Y0 - 0.0085, ZR[1] + 0.0158), (0.072, Y0 - 0.0085, 0.113),
            (0.072, Y0 + 0.004, 0.127), (0.072, Y9 - 0.0085, ZR[2] + 0.0158)], 0.0019, "brass", sides=6, smooth=True)
    for x in XC:
        top = ZR[2] - 0.0108
        p.box((x, Y9 - 0.0055, (Z1 + top) / 2), (0.011, 0.008, top - Z1), "brass")
    p.box((0, Y9 - 0.0055, Z1 + 0.0015), (0.15, 0.011, 0.003), "brass")


def coil_points():
    """Slow-match coil hanging on the peg: turns side by side along -X."""
    a_end = 0.55 * math.pi
    a0 = a_end - 2 * math.pi * COIL_TURNS
    n = 34
    pts = []
    for i in range(n + 1):
        u = i / n
        a = a0 + 2 * math.pi * COIL_TURNS * u
        rad = COIL_R + 0.0016 * math.sin(3.1 * a + 0.7)
        x = COIL_C.x - (2 * CORD_R + 0.0004) * COIL_TURNS * u
        y = COIL_C.y + rad * math.cos(a)
        z = COIL_C.z + rad * math.sin(a) - 0.0015 * (1.0 - math.sin(a))
        pts.append(Vector((x, y, z)))
    return pts


def fuse(p):
    pts = coil_points() + FUSE_END
    p.tube(pts, CORD_R, "cord", sides=6, smooth=True)
    kit.seg(p, FUSE_END[-1], CHAR_END, [(CORD_R, 0), (CORD_R * 0.96, 1)], "char", segments=6)
    kit.seg(p, CHAR_END, EMBER_TIP, [(CORD_R * 0.96, 0.0), (CORD_R * 1.02, 0.35), (CORD_R * 0.78, 0.8),
                                     (CORD_R * 0.38, 1.0)], "ember", segments=6)
    # iron clip on the back corner holding the burning end up
    clip = FUSE_END[2]
    d = (FUSE_END[3] - FUSE_END[1]).normalized()
    kit.seg(p, clip - d * 0.003, clip + d * 0.003, [(CORD_R + 0.0014, 0), (CORD_R + 0.0014, 1)], "iron", segments=8,
            caps=False)
    p.box((-BX - 0.0045, clip.y, clip.z), (0.0055, 0.004, 0.004), "iron", bevel=0.0008)


def _shift(p):
    p.move(list(p.bm.faces), T(*VM_SHIFT))


def build():
    s = VM_SHIFT
    gun = Part("hwacha")
    hive(gun)
    handles(gun)
    parts = [gun]
    for k in range(6):
        x, z = TUBES[k]
        r = Part(f"rocket_{k + 1}", origin=tuple(Vector((x, YM, z)) + s), parent="hwacha")
        rocket(r, x, z, k)
        parts.append(r)
    upg = PREVIEW != "base"
    if upg:
        b9 = Part("upg_box9", origin=tuple(Vector((0.0, YM, ZR[2])) + s), parent="hwacha")
        box9(b9)
        parts.append(b9)
        for k in range(6, 9):
            x, z = TUBES[k]
            r = Part(f"rocket_{k + 1}", origin=tuple(Vector((x, YM, z)) + s), parent="upg_box9")
            rocket(r, x, z, k)
            parts.append(r)
        fz = Part("upg_fuses", origin=tuple(Vector((0.0, Y0, (ZR[0] + ZR[1]) / 2)) + s), parent="hwacha")
        fuses(fz)
        parts.append(fz)
    fu = Part("fuse", origin=tuple(PEG + Vector((-0.013, 0, 0)) + s), parent="hwacha")
    fuse(fu)
    parts.append(fu)
    # both hands on the vertical side handles (cant 35), the forearms back
    # toward the eye and down; built in gun space like everything else and
    # shifted after (the markers get the shift by hand)
    g0, g1 = grip_axis(1)
    gc = g0.lerp(g1, 0.5)
    right = Part("hand_r", origin=tuple(gc + s), parent="hwacha")
    m = hands.hand_matrix(gc, (g1 - g0).normalized(), (1.0, -0.2, 0.0), sx=1)
    sleeve_r, markers_r = hands.arm("r", right, m, 1, math.radians(35.0), (0.1, -0.85, -0.5), 0.34, tris=900,
                                    parent="hwacha")
    g0, g1 = grip_axis(-1)
    gc = g0.lerp(g1, 0.5)
    left = Part("hand_l", origin=tuple(gc + s), parent="hwacha")
    m = hands.hand_matrix(gc, (g1 - g0).normalized(), (-1.0, -0.2, 0.0), sx=-1)
    sleeve_l, markers_l = hands.arm("l", left, m, -1, math.radians(35.0), (-0.08, -0.85, -0.5), 0.36, watch=True,
                                    tris=900, parent="hwacha")
    for sleeve in (sleeve_r, sleeve_l):
        sleeve.origin = sleeve.origin + s
    parts += [right, left, sleeve_r, sleeve_l]
    for p in parts:
        _shift(p)
    markers = [("Muzzle", tuple(Vector((0.0, YM, (ZR[0] + ZR[1]) / 2)) + s), None)]
    markers += [(name, tuple(Vector(co) + s), *rest) for name, co, *rest in markers_r + markers_l]
    markers += [(f"Tube_{k + 1}", tuple(Vector((TUBES[k][0], YM, TUBES[k][1])) + s), None) for k in range(6)]
    if upg:
        markers += [(f"Tube_{k + 1}", tuple(Vector((TUBES[k][0], YM, TUBES[k][1])) + s), "upg_box9")
                    for k in range(6, 9)]
    tip = EMBER_TIP + (EMBER_TIP - CHAR_END).normalized() * 0.0015
    markers.append(("Ember", tuple(tip + s), "fuse"))
    back = tuple(Vector((-0.04, Y0, 0.07)) + s)
    face = tuple(Vector((0.0, YM + 0.06, 0.07)) + s)
    side = tuple(Vector((-BX - 0.04, 0.03, 0.05)) + s)
    return Model("vm_hwacha", parts, FNS, ppm=512, organic=("hand_r", "hand_l", "sleeve_r", "sleeve_l"), ao_dist=0.04,
                 ao_rays=12,
                 ao_stride=1, front=1, markers=markers, variants={"vm_hwacha_master": MASTER},
                 preview_yaws=(-60.0, 40.0, 110.0, 250.0), preview_elevation=16.0,
                 preview_extra=[("back", back, 0.13, 205.0, 24.0), ("face", face, 0.17, -24.0, 10.0),
                                ("side", side, 0.14, -80.0, 14.0)],
                 preview_fp=(CAM, LOOK))
