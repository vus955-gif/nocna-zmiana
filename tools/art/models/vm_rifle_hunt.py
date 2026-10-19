"""First-person expedition hunting rifle (sztucer ekspedycyjny, weapon id
rifle_hunt): a ~1907 bolt-action safari rifle on a Mauser-type action,
9,3 x 62. Blued round barrel with a stepped shank, express rear sight
(standing leaf with a V notch and an inlaid white line, two folding
leaves), banded ramp front sight with an ivory bead; receiver ring,
receiver walls and rear bridge with charger guides for a stripper clip;
bolt in the white with a long claw extractor, bent handle and pear
knob; walnut half-stock with a pistol grip, steel grip cap, checkered
grip and fore-end, black horn fore-end tip, checkered steel buttplate,
barrel-band and butt sling swivels, floorplate and trigger guard, and an
oval brass plaque "1907" on the left side of the butt (an exhibit's
inventory plate, on the side the player sees). Right hand on the pistol grip, left hand under the
fore-end (like vm_shotgun).

Viewmodel conventions as in vm_fists.py (faces +Y in Blender = -Z in
Godot, real scale; Godot coordinates = (x, z, -y) of Blender). Origin on
the bore axis at the rear face of the receiver ring. Parts (Blender
model space -> Godot, both relative to the model origin):

    part           parent  pivot Blender (x, y, z)      pivot Godot (x, y, z)
    rifle          -       (0, 0, 0)                    (0, 0, 0)
    bolt           rifle   (0, -0.118, 0)               (0, 0, 0.118)
    bolt_knob      bolt    KNOB_C (0.0503, -0.1360, -0.0308)  (0.0503, -0.0308, 0.1360)
    upg_bolt_ball  bolt    (0, -0.118, 0) (= bolt pivot) (0, 0, 0.118)
    upg_fittings   rifle   (0, 0, 0)                    (0, 0, 0)
    clip           rifle   (0, -0.0925, 0.0165)         (0, 0.0165, 0.0925)
    hand_r         rifle   (0, -0.186, -0.070)          (0, -0.070, 0.186)
    hand_l         rifle   (0, 0.205, -0.038)           (0, -0.038, -0.205)
    sleeve_r/_l    rifle   the wrist of its hand (the game turns it toward the elbow)
    marker Muzzle  root    (0, 0.622, 0)                (0, 0, -0.622)
    marker BoltKnob bolt   KNOB_C                       (0.0503, -0.0308, 0.1360)
    markers Wrist_r/_l, Grip_r/_l (children of the hands, with a basis) and
    Elbow_r/_l (children of rifle): the arm rig, see artlib/hands.py arm().

bolt: pivot ON THE BORE AXIS at the rear face of the receiver bridge.
  Lift the handle: rotate about the bore axis = Blender local Y = Godot
  local Z. In Godot a POSITIVE bolt.rotation.z lifts the handle (it swings
  from the right side, +X, up toward +Y); in Blender that is a NEGATIVE
  rotation about +Y. Fully lifted: +65 deg (1.13 rad); the knob then sits
  above the right edge of the receiver.
  Pull it back: translate along Blender -Y = Godot +Z (toward the eye)
  by BOLT_TRAVEL = 0.09 m; then the bolt face (at rest 10 mm inside the
  receiver ring) clears the charger guide at the bridge front and the
  open action shows. 0.07 m also looks right: nothing intersects the
  clip, the bolt head just stays a little further forward.
  The bolt shroud and cocking piece are round, so they can turn with the
  bolt. bolt_knob and upg_bolt_ball (and the BoltKnob marker) are children
  of bolt and follow both motions.
bolt_knob / upg_bolt_ball: the plain pear knob and the upgrade ("lighter
  bolt": a slimmer polished checkered ball knob in the same spot plus a
  jewelled sleeve over the bolt body). Show one knob or the other; the
  sleeve is part of upg_bolt_ball.
upg_fittings: upgrade "expanding bullet": engraved bright-steel fittings
  sitting 0.8-1 mm proud of the base surfaces: grip cap, fore-end tip cap
  (over the horn tip), receiver side plates on both sides (ring, walls,
  bridge; the player sees the left side and the top at REST), trigger
  guard bow overlay. The base rifle is complete without it.
clip: steel stripper clip with five 9,3 x 62 cartridges standing in the
  charger guides at the bridge front, bullets forward over the open
  action; pivot = the clip's bottom centre. Hidden by default; during the
  reload show it (bolt open), push it straight down (Godot -Y) by up to
  0.02 m (the cartridges then sit in the magazine), then hide it.
hand_r: right hand round the pistol grip (pivot on the grip axis);
  BoltKnob is where it reaches while cycling.
hand_l: left hand under the fore-end, with the wristwatch on sleeve_l. In
  the reload the game moves it (by its Grip_l marker) down out of the frame,
  up to the open action with the clip hanging from the fist (bullets
  forward), presses the clip in, flicks it away and brings the hand back.
Texture sets: vm_rifle_hunt (field finish) and vm_rifle_hunt_master (the
mastery finish: polished deep bluing with bright edges, fine scrollwork
on the receiver, bridge, shroud, floorplate and guard, gold inlay bands,
exhibition walnut with a high gloss, polished ebony tip). Same mesh and
UVs, so the game swaps the material's textures.
"""
import math

import numpy as np
from mathutils import Vector

from artlib import hands, kit, pixelfont
from artlib import materials as M
from artlib.geo import Part
from artlib.kit import R, T
from artlib.model import Model
from artlib.painter import Surface
from models import _rifle_parts as RP
from models.vm_fists import FNS as HAND_FNS
from models.vm_pistol import CAM, LOOK, bore

TAU = math.tau

# --- receiver (bore axis = Y, x = 0, z = 0) --------------------------------
Y_RF, Y_RR = 0.035, 0.0          # receiver ring front / rear
Y_BF, Y_BR = -0.088, -0.118      # rear bridge front / rear
R_RING, R_BRIDGE, R_WALL, R_WALL_IN = 0.0178, 0.0175, 0.0170, 0.0105
BOLT_R = 0.0088
BOLT_FACE_Y = 0.010
BOLT_PIVOT = Vector((0.0, Y_BR, 0.0))
BOLT_TRAVEL = 0.09
MUZZLE_Y = 0.62
CLIP_BOTTOM = Vector((0.0, -0.0925, 0.0165))

# bolt handle: stem from the root collar out to the right and down
STEM = [(0.006, -0.127, 0.0), (0.020, -0.1275, 0.0002), (0.031, -0.1285, -0.0035), (0.0395, -0.1305, -0.0115),
        (0.0445, -0.133, -0.0205)]
STEM_END = Vector(STEM[-1])
KNOB_D = (STEM_END - Vector(STEM[-2])).normalized()
KNOB_C = STEM_END + KNOB_D * 0.012

# --- stock: (y, top z, bottom z, half width, superellipse exponent) --------
STOCK = [
    (0.270, -0.0040, -0.0320, 0.0170, 2.6),
    (0.240, -0.0032, -0.0360, 0.0186, 2.6),
    (0.180, -0.0028, -0.0390, 0.0196, 2.6),
    (0.110, -0.0025, -0.0420, 0.0202, 2.7),
    (0.060, -0.0018, -0.0470, 0.0206, 2.8),
    (0.035, -0.0010, -0.0530, 0.0210, 3.0),
    (0.010, 0.0000, -0.0580, 0.0215, 3.2),
    (-0.090, 0.0000, -0.0580, 0.0215, 3.2),
    (-0.118, -0.0040, -0.0570, 0.0210, 3.0),
    (-0.132, -0.0110, -0.0545, 0.0190, 2.6),
    (-0.155, -0.0150, -0.0520, 0.0168, 2.3),
    (-0.185, -0.0180, -0.0540, 0.0160, 2.2),
    (-0.215, -0.0185, -0.0620, 0.0168, 2.3),
    (-0.250, -0.0180, -0.0760, 0.0185, 2.4),
    (-0.300, -0.0210, -0.0960, 0.0198, 2.5),
    (-0.360, -0.0260, -0.1200, 0.0205, 2.5),
    (-0.420, -0.0330, -0.1450, 0.0210, 2.5),
    (-0.460, -0.0380, -0.1620, 0.0212, 2.5),
]
HORN = [(0.270, -0.0040, -0.0320, 0.0170, 2.6), (0.290, -0.0048, -0.0302, 0.0162, 2.6),
        (0.300, -0.0058, -0.0287, 0.0154, 2.6)]
BUTT_Y = -0.460
# pistol grip: wood from the wrist down to the cap
G0 = Vector((0.0, -0.160, -0.040))
G1 = Vector((0.0, -0.212, -0.100))
GRIP_AX = (G1 - G0).normalized()
GRIP_SQUASH = (0.92, 1.12)
GRIP_C = Vector((0.0, -0.186, -0.070))
FORE_C = Vector((0.0, 0.205, -0.0195))
HAND_L_PIVOT = Vector((0.0, 0.205, -0.038))
REAR_SIGHT_Y = 0.120                 # standing leaf; the base runs forward from it
PLAQUE_C = (-0.360, -0.073)          # (y, z) on the left side of the butt
DATE = pixelfont.trim(pixelfont.render("1907"))

GUARD = [(-0.084, -0.058), (-0.087, -0.068), (-0.094, -0.077), (-0.106, -0.0825), (-0.121, -0.0825),
         (-0.134, -0.077), (-0.142, -0.068), (-0.1465, -0.058), (-0.150, -0.053)]
TRIGGER = [(-0.1035, -0.0575), (-0.1045, -0.0665), (-0.1025, -0.0735), (-0.0985, -0.0785)]
BARREL = [(0.035, 0.0152), (0.058, 0.0152), (0.0615, 0.0137), (0.10, 0.0133), (0.25, 0.0118), (0.42, 0.0104),
          (0.55, 0.0094), (0.612, 0.0090), (0.62, 0.0085)]


def section(y):
    """Stock section (zc, hw, hh, n) interpolated at y."""
    ys = [s[0] for s in STOCK][::-1]
    cols = np.array(STOCK)[::-1]
    top = np.interp(y, ys, cols[:, 1])
    bot = np.interp(y, ys, cols[:, 2])
    hw = np.interp(y, ys, cols[:, 3])
    n = np.interp(y, ys, cols[:, 4])
    return (top + bot) / 2, hw, (top - bot) / 2, n


def stock_top(y):
    zc, hw, hh, n = section(y)
    return zc + hh


def barrel_r(y):
    return float(np.interp(y, [b[0] for b in BARREL], [b[1] for b in BARREL]))


def _st(rows, grow=0.0):
    """(y, top, bot, hw, n) rows -> loft stations, optionally inflated."""
    return [(y, (t + b) / 2, hw + grow, (t - b) / 2 + grow, n) for y, t, b, hw, n in rows]


# --------------------------------------------------------------------------
# materials: field finish
# --------------------------------------------------------------------------

def blued(ctx):
    return M.gun_steel(ctx, seed=701, center=5.9, wear=0.85)


def buttplate(ctx):
    s = M.gun_steel(ctx, seed=703, center=5.6, wear=0.7)
    rear = ctx.n[:, 1] < -0.7
    RP.checker_panel(ctx, s, rear & (ctx.convex > 3.0 * ctx.texel), rear & RP.edge_band(ctx, 1.0, 2.0))
    return s


def bright(ctx):
    """The bolt in the white: bright, oily, a few scratches."""
    s = M.steel(ctx, seed=705, ramp="steel", center=7.6, dent=0.0, rust=0.15, polish=0.2, scratch=0.2)
    return s


def knob(ctx):
    return M.gun_steel(ctx, seed=707, center=5.6, wear=1.6)


def _wood_panels(ctx):
    """(inside, border) masks of the checkering panels: both sides of the
    pistol grip and wrist, both sides of the fore-end."""
    y, z = ctx.p[:, 1], ctx.p[:, 2]
    side = np.abs(ctx.n[:, 0]) > 0.3
    # grip: an ellipse in the side view along the grip axis
    c = np.array([-0.180, -0.060])
    ax = np.array([GRIP_AX.y, GRIP_AX.z])
    dy, dz = y - c[0], z - c[1]
    a = dy * ax[0] + dz * ax[1]
    b = -dy * ax[1] + dz * ax[0]
    A, B = 0.046, 0.019
    dist_g = (1.0 - np.sqrt((a / A) ** 2 + (b / B) ** 2)) * B
    # fore-end: long panel with slanted ends, below the barrel channel
    d1 = 0.074 - np.abs(y - 0.148) - np.clip(z + 0.036, 0, None) * 0.9
    d2 = -0.011 - z
    dist_f = np.minimum(d1, d2)
    t = ctx.texel
    inside = side & (((dist_g > 2.5 * t) & (y < -0.12)) | ((dist_f > 2.5 * t) & (y > 0.05)))
    border = side & ((((dist_g > 0) & (dist_g <= 1.05 * t)) & (y < -0.12)) | (((dist_f > 0) & (dist_f <= 1.05 * t)) & (y > 0.05)))
    return inside, border


def _walnut(ctx, ramp, center, seed, figure=1.0, fiddle=0.0):
    """Walnut stock wood: long fibres and colour streaks along the stock,
    soft growth rings, little per-texel dither (reads as wood, not noise)."""
    s = Surface(ctx.N)
    along, across = M._grain_frame(ctx)
    a = np.sum(ctx.p * along, 1)
    c = np.sum(ctx.p * across, 1)
    d = np.sum(ctx.p * ctx.n, 1)
    q = np.stack([a, d, c], axis=1)
    fib = ctx.fbm(np.array([1.2, 26.0, 26.0]), 3, seed, p=q)
    streak = ctx.fbm(np.array([0.5, 8.0, 8.0]), 3, seed + 7, p=q)
    wob = ctx.fbm(np.array([0.6, 2.0, 2.0]), 3, seed + 1, p=q)
    band = np.mod(c * 11.0 + d * 11.0 + wob * 1.8 * figure, 1.0)
    ring = M.smoothstep(0.74, 0.94, band)
    shade = center + fib * 0.9 + streak * 1.4 * figure - ring * 1.2 + M._dither(ctx, 0.3, seed + 2)
    if fiddle > 0:
        shade += np.sin(a * TAU / 0.011 + wob * 2.0) * fiddle * (ctx.fbm(2.5, 2, seed + 3) > 0.05)
    s.use_ramp(ramp, shade=shade)
    s.height = -ring * 0.0004 + fib * 0.0003
    M._age(ctx, s, cavity=2.0, ao=3.5, edge=1.3)
    return s


def walnut_field(ctx, seed=709):
    """Oiled field-grade walnut, satin."""
    s = _walnut(ctx, M.P["walnut_stock"], 4.1, seed)
    s.rough = 0.4 + np.clip(ctx.fbm(3.0, 3, seed + 5), 0, 1) * 0.18 + ctx.cavity(3.0) * 0.3
    return s


def wood(ctx):
    s = walnut_field(ctx)
    inside, border = _wood_panels(ctx)
    return RP.checker_panel(ctx, s, inside, border)


def horn(ctx, polish=0.32, center=3.0, seed=711):
    """Black buffalo-horn fore-end tip: faint streaks along the rifle."""
    s = Surface(ctx.N)
    q = ctx.p[:, [1, 0, 2]]
    st = ctx.fbm(np.array([12.0, 90.0, 90.0]), 3, seed, p=q)
    shade = center + st * 1.4 + M._dither(ctx, 0.5, seed + 1)
    shade += ctx.edge(1.0) * 1.6 + ctx.edge(2.0) * 0.5
    shade -= ctx.cavity(3.0) * 1.5 + (1.0 - ctx.ao) * 2.5
    s.use_ramp(RP.RAMPS["horn"], shade=shade)
    s.rough = polish + ctx.rand(seed + 2) * 0.04
    s.height = st * 0.0002
    return s


def _plaque_text(ctx, s):
    face = ctx.n[:, 0] < -0.7                 # left face: box UVs u = -y, v = z
    txt = face & pixelfont.stamp(ctx, DATE, -PLAQUE_C[0], PLAQUE_C[1])
    s.use_ramp(M.P["brass_tarnish"], mask=txt, shade=np.full(ctx.N, 0.8))
    s.height = s.height - txt * 0.0004
    s.rough = np.where(txt, 0.7, s.rough)
    ring = face & RP.edge_band(ctx, 1.0, 2.0)
    s.shade[ring] -= 3.0
    s.height = s.height - ring * 0.0003
    return s


def plaque(ctx):
    return _plaque_text(ctx, M.brass(ctx, seed=713, tarnish_amount=1.5))


def dot(ctx):
    return M.ivory(ctx, seed=715, center=6.4)


SMALL = dict(L=14.0, A=1.6, curls=False)       # narrow bands: vine with berries
BIG = dict(L=16.0, A=2.3, curls=True)          # plates: vine with C-curls


def _scroll_coords(ctx):
    """(along, across) metres for the running scroll on each fitting:
    cylinders round the bore (receiver, shroud, barrel shank), the bow of
    the trigger guard, polar round the grip cap, the bottom plates."""
    x, y, z = ctx.p[:, 0], ctx.p[:, 1], ctx.p[:, 2]
    side_c = np.where(x < 0, np.pi * 0.95, np.pi * 0.05)
    a, c = RP.cyl_coords(ctx, side_c, 0.018)
    # fore-end tip: round the section centre, rows centred on each side
    zc_tip = section(0.285)[0]
    a2, c2 = RP.cyl_coords(ctx, np.where(x < 0, np.pi, 0.0), 0.016, axis_z=zc_tip)
    tip = y > 0.25
    a, c = np.where(tip, a2, a), np.where(tip, c2, c)
    front = tip & (ctx.n[:, 1] > 0.7)
    a, c = np.where(front, x, a), np.where(front, z - zc_tip, c)
    # trigger guard bow: along the bow, across its width
    bow = (y < -0.08) & (y > -0.156) & (z < -0.05) & (np.abs(x) < 0.008)
    a = np.where(bow, 0.0225 * np.arctan2(z + 0.060, y + 0.116), a)
    c = np.where(bow, x, c)
    # bottom plates (floorplate): along y, across x
    flat = (ctx.n[:, 2] < -0.8) & ~bow
    a, c = np.where(flat, y, a), np.where(flat, x, c)
    # grip cap: polar round its centre
    v = ctx.p - np.array(G1)
    e2 = np.cross(np.array(GRIP_AX), [1.0, 0.0, 0.0])
    q1, q2 = v[:, 0] / GRIP_SQUASH[0], (v @ e2) / GRIP_SQUASH[1]
    cap = (np.abs(v @ np.array(GRIP_AX)) < 0.008) & (np.linalg.norm(v, axis=1) < 0.03)
    a = np.where(cap, 0.0095 * np.arctan2(q2, q1), a)
    c = np.where(cap, np.hypot(q1, q2) - 0.0095, c)
    return a, c


def silver(ctx, gold=False):
    """Engraved bright steel fittings: running scroll and a border line."""
    s = RP.polished(ctx, RP.RAMPS["steel_white"], 8.0, seed=717, polish=0.16, cloud=0.8)
    a, c = _scroll_coords(ctx)
    zone = ctx.convex > 2.5 * ctx.texel
    RP.engrave_scroll(ctx, s, a, c, zone, shade=3.4, **SMALL)
    border = RP.edge_band(ctx, 1.0, 2.0)
    if gold:
        RP.inlay(ctx, s, border)
    else:
        RP.engrave(s, border, shade=3.6)
    return s


def ball(ctx, polish=0.14):
    s = RP.polished(ctx, RP.RAMPS["steel_white"], 8.4, seed=721, polish=polish, cloud=0.7)
    g = RP.diamond_lines(ctx, 3)
    s.shade[g] -= 2.4
    s.height = s.height - g * 0.0003
    s.rough = np.where(g, 0.45, s.rough)
    return s


def jewel(ctx, polish=0.14):
    s = RP.polished(ctx, RP.RAMPS["steel_white"], 7.8, seed=723, polish=polish, cloud=0.5)
    return RP.engine_turned(ctx, s, cell=0.0105)


def clip_steel(ctx):
    return M.gun_steel(ctx, seed=725, center=6.6, wear=1.2)


def lead(ctx):
    s = Surface(ctx.N)
    shade = 5.6 + ctx.fbm(30.0, 2, 727) * 0.6 + M._dither(ctx, 0.6, 728) + ctx.edge(1.0) * 1.0 \
        - (1.0 - ctx.ao) * 3.0
    s.use_ramp(M.P["steel"], shade=shade)
    s.rough = np.full(ctx.N, 0.6)
    s.metal = np.full(ctx.N, 0.4)
    return s


GUN_FNS = {
    "blued": blued, "butt": buttplate, "bright": bright, "knob": knob, "wood": wood, "horn": horn,
    "plaque": plaque, "bore": bore, "dot": dot, "silver": silver, "ball": ball, "jewel": jewel,
    "clip": clip_steel, "cart": lambda c: M.brass(c, seed=729, tarnish_amount=0.9),
    "bullet": lambda c: M.brass(c, seed=731, ramp="copper", tarnish_amount=1.0), "lead": lead,
}
FNS = dict(HAND_FNS, **GUN_FNS)


# --------------------------------------------------------------------------
# materials: mastery finish
# --------------------------------------------------------------------------

def _blue_deep(ctx, seed, center=6.2):
    """Polished rust bluing: deep blue-black, clean, bright polished edges."""
    s = RP.polished(ctx, RP.RAMPS["blue_deep"], center, seed, polish=0.12, cloud=0.9, edge=1.4, ao=3.0)
    lit = ctx.edge(1.0) > 0
    s.use_ramp(RP.RAMPS["steel_white"], mask=lit, shade=np.full(ctx.N, 9.0) + M._dither(ctx, 1.0, seed + 5))
    s.rough = np.where(lit, 0.1, s.rough)
    return s


def blued_m(ctx):
    s = _blue_deep(ctx, 801)
    x, y, z = ctx.p[:, 0], ctx.p[:, 1], ctx.p[:, 2]
    rxz = np.hypot(x, z)
    t = ctx.texel
    receiver = (rxz < 0.0195) & (y > Y_BR - 0.001) & (y < Y_RF + 0.0005) & (z > -0.03)         & (np.abs(x) > 0.55 * rxz)
    shank = (rxz < 0.0160) & (y > Y_RF + 0.002) & (y < 0.0575)
    shroud = (rxz < 0.0105) & (y < -0.132) & (y > -0.185)
    floor = (z < -0.0565) & (y > -0.09) & (y < 0.016) & (ctx.n[:, 2] < -0.7)
    guard = (z < -0.05) & (y < -0.08) & (y > -0.156) & (np.abs(x) < 0.008)
    v = ctx.p - np.array(G1)
    cap = (np.abs(v @ np.array(GRIP_AX)) < 0.008) & (np.linalg.norm(v, axis=1) < 0.03)
    zone = (receiver | shank | shroud | guard | cap) & (ctx.convex > 2.0 * t)
    a, c = _scroll_coords(ctx)
    RP.engrave_scroll(ctx, s, a, c, zone, shade=3.2, **SMALL)
    RP.engrave_scroll(ctx, s, a, c, floor & (ctx.convex > 2.5 * t), shade=3.2, **BIG)
    border = (floor | cap) & RP.edge_band(ctx, 1.0, 2.0)
    RP.inlay(ctx, s, border)
    # gold wire bands: barrel breech and muzzle, ring edges, bridge, shroud
    bands = np.zeros(ctx.N, dtype=bool)
    for yb, rmax in ((0.0605, 0.016), (0.0595, 0.016), (0.606, 0.011), (0.0035, 0.019), (0.0315, 0.019),
                     (-0.0915, 0.019), (-0.1145, 0.019), (-0.137, 0.0105)):
        bands |= (np.abs(y - yb) < 0.55 * t) & (rxz < rmax) & (np.abs(ctx.n[:, 1]) < 0.5)
    RP.inlay(ctx, s, bands)
    return s


def buttplate_m(ctx):
    s = _blue_deep(ctx, 805, center=5.8)
    rear = ctx.n[:, 1] < -0.7
    RP.checker_panel(ctx, s, rear & (ctx.convex > 4.0 * ctx.texel), rear & RP.edge_band(ctx, 2.0, 3.0))
    return s


def bright_m(ctx):
    return RP.polished(ctx, RP.RAMPS["steel_white"], 8.6, seed=807, polish=0.07, cloud=0.6, edge=1.8)


def knob_m(ctx):
    return _blue_deep(ctx, 809, center=6.6)


def walnut_fine(ctx, seed=811):
    """Exhibition walnut: deep chocolate-red with dark streaks of figure, a
    soft fiddleback ripple, golden highlights, high gloss."""
    s = _walnut(ctx, RP.RAMPS["walnut_fine"], 5.2, seed, figure=1.4, fiddle=0.45)
    q_streak = ctx.fbm(np.array([0.7, 6.0, 6.0]), 3, seed + 9)
    dark = q_streak > 0.32
    s.use_ramp(RP.RAMPS["walnut_streak"], mask=dark, shade=np.full(ctx.N, 2.4) + M._dither(ctx, 0.3, seed + 4)
               - (1.0 - ctx.ao) * 2.0)
    s.rough = 0.13 + np.clip(ctx.fbm(4.0, 2, seed + 4), 0, 1) * 0.06 + ctx.cavity(3.0) * 0.25
    return s


def wood_m(ctx):
    s = walnut_fine(ctx)
    inside, border = _wood_panels(ctx)
    return RP.checker_panel(ctx, s, inside, border)


def plaque_m(ctx):
    return _plaque_text(ctx, M.brass(ctx, seed=813, tarnish_amount=0.25, grain=0.5))


MASTER_FNS = dict(FNS, blued=blued_m, butt=buttplate_m, bright=bright_m, knob=knob_m, wood=wood_m,
                  horn=lambda c: horn(c, polish=0.12, center=3.4, seed=815), plaque=plaque_m,
                  silver=lambda c: silver(c, gold=True), ball=lambda c: ball(c, polish=0.08),
                  jewel=lambda c: jewel(c, polish=0.08))


# --------------------------------------------------------------------------
# geometry
# --------------------------------------------------------------------------

def _y(p, y0, y1, radii, mat, segments=16, caps=True, x=0.0, z=0.0, squash=(1.0, 1.0)):
    return kit.seg(p, (x, y0, z), (x, y1, z), radii, mat, segments=segments, caps=caps, squash=squash)


def build_stock(p):
    RP.loft(p, _st(STOCK), "wood", segs=18)
    RP.loft(p, _st(HORN), "horn", segs=18)
    # pistol grip and its cap
    kit.seg(p, G0, G1, [(0.0160, 0.0), (0.0166, 0.5), (0.0175, 1.0)], "wood", segments=14, squash=GRIP_SQUASH)
    kit.seg(p, G1 - GRIP_AX * 0.0005, G1 + GRIP_AX * 0.004, [(0.0172, 0.0), (0.0175, 0.4), (0.0167, 1.0)],
            "blued", segments=14, squash=GRIP_SQUASH)
    # steel buttplate over the butt end
    zc, hw, hh, n = section(BUTT_Y)
    RP.loft(p, [(BUTT_Y + 0.0002, zc, hw + 0.0003, hh + 0.0003, n), (BUTT_Y - 0.0055, zc, hw + 0.0003, hh + 0.0003, n),
                (BUTT_Y - 0.0065, zc, hw - 0.0005, hh - 0.0005, n)], "butt", segs=18)
    # brass plaque, inlet into the right side of the butt
    zc, hw, hh, n = section(PLAQUE_C[0])
    oval = [(PLAQUE_C[0] + 0.029 * math.cos(a), PLAQUE_C[1] + 0.0135 * math.sin(a))
            for a in np.linspace(0, 2 * math.pi, 18, endpoint=False)]
    RP.prism_yz(p, oval, -hw - 0.0008, -hw + 0.0008, "plaque")
    # sling swivel under the butt
    yb = -0.390
    zb = section(yb)[0] - section(yb)[2]
    p.box((0, yb, zb - 0.0005), (0.0062, 0.010, 0.006), "blued", bevel=0.001)
    _swivel(p, yb, zb - 0.0035)


def _swivel(p, y, ztop):
    pts = [(0.0125 * math.cos(a), y, ztop - 0.0075 + 0.0072 * math.sin(a))
           for a in np.linspace(math.pi / 2, math.pi / 2 + 2 * math.pi, 13)]
    p.tube(pts, 0.0016, "blued", sides=5, caps=False)


def build_action(p):
    # receiver ring, walls (top cut away: ejection port right, thumb cut left), bridge
    _y(p, Y_RR, Y_RF, [(R_RING * 0.965, 0.0), (R_RING, 0.06), (R_RING, 0.94), (R_RING * 0.965, 1.0)], "blued",
       segments=20)
    RP.arc_shell(p, Y_BF - 0.002, Y_RR + 0.002, R_WALL_IN, R_WALL, 140.0, 368.0, "blued", segs=16)
    _y(p, Y_BR, Y_BF, [(R_BRIDGE * 0.96, 0.0), (R_BRIDGE, 0.1), (R_BRIDGE, 0.9), (R_BRIDGE * 0.97, 1.0)], "blued",
       segments=20)
    for sx in (-1, 1):                                                                   # charger guides
        p.box((sx * 0.0098, -0.0915, 0.0185), (0.0036, 0.007, 0.006), "blued", bevel=0.0008)
    p.box((-0.0168, -0.110, 0.003), (0.004, 0.012, 0.007), "blued", bevel=0.001)        # bolt stop
    # rear tang along the top of the wrist, a tang screw
    ys = [Y_BR + 0.004, -0.130, -0.145, -0.160, -0.172]
    RP.strap(p, [(y, stock_top(y) - 0.0006) for y in ys], 0.0125, 0.003, "blued")
    # bottom metal: floorplate, guard bow, guard tang on the grip, trigger, floorplate catch
    p.box((0, -0.037, -0.0592), (0.020, 0.100, 0.0028), "blued", bevel=0.0009)
    RP.strap(p, GUARD, 0.0105, 0.0034, "blued")
    front = Vector((0.0, -GRIP_AX.z, GRIP_AX.y))                                      # grip front normal
    g_top = G0 + front * 0.0185
    RP.strap(p, [(g_top.y + GRIP_AX.y * 0.006, g_top.z + GRIP_AX.z * 0.006),
                 (g_top.y + GRIP_AX.y * 0.03, g_top.z + GRIP_AX.z * 0.03)], 0.0095, 0.0026, "blued")
    RP.strap(p, TRIGGER, 0.0055, 0.0028, "blued")
    p.box((0, -0.0858, -0.0628), (0.0045, 0.0032, 0.004), "blued", bevel=0.0008)


def build_barrel(p):
    L = MUZZLE_Y - Y_RF
    _y(p, Y_RF, MUZZLE_Y, [(r, (y - Y_RF) / L) for y, r in BARREL], "blued", segments=16)
    _y(p, MUZZLE_Y, MUZZLE_Y + 0.0006, [(0.00465, 0.0), (0.00465, 1.0)], "bore", segments=12)
    # rear sight: base, standing leaf with a V notch and white line, two folded leaves
    y0 = REAR_SIGHT_Y
    rb = barrel_r(y0 + 0.016)
    zb = rb + 0.0038
    p.box((0, y0 + 0.016, rb + 0.0012), (0.011, 0.034, 0.0052), "blued", bevel=0.0008)
    for piece in ([(-0.010, zb), (0.0, zb), (0.0, 0.0222), (-0.0032, 0.0255), (-0.010, 0.0255)],
                  [(0.0, zb), (0.010, zb), (0.010, 0.0255), (0.0032, 0.0255), (0.0, 0.0222)]):
        f = p.ngon_prism(piece, -(y0 + 0.0019), -(y0 + 0.0001), "blued")
        verts = {v for fc in f for v in fc.verts}
        for v in verts:
            a, b, c = v.co
            v.co = Vector((a, -c, b))
    p.box((0, y0 - 0.0001, 0.5 * (zb + 0.0222)), (0.0011, 0.0004, 0.0222 - zb - 0.001), "dot")
    p.box((0, y0 + 0.010, zb + 0.0006), (0.017, 0.016, 0.0012), "blued", bevel=0.0003)
    p.box((0, y0 + 0.0095, zb + 0.0018), (0.015, 0.014, 0.0012), "blued", bevel=0.0003)
    # front sight: band, ramp, blade, ivory bead
    _y(p, 0.560, 0.594, [(barrel_r(0.56) + 0.0012, 0.0), (barrel_r(0.594) + 0.0012, 1.0)], "blued", segments=16)
    ramp = [(0.548, 0.006), (0.596, 0.006), (0.596, 0.0150), (0.590, 0.0152), (0.572, 0.0128),
            (0.548, barrel_r(0.548) + 0.0003)]
    RP.prism_yz(p, ramp, -0.0032, 0.0032, "blued")
    p.box((0, 0.5935, 0.0178), (0.0024, 0.005, 0.0056), "blued", bevel=0.0003)
    _y(p, 0.5912, 0.5932, [(0.0017, 0.0), (0.0017, 1.0)], "dot", segments=10, z=0.0199)
    # barrel band with the front sling swivel
    rbb = barrel_r(0.36)
    _y(p, 0.354, 0.366, [(rbb + 0.0012, 0.0), (rbb + 0.0016, 0.2), (rbb + 0.0016, 0.8), (rbb + 0.0012, 1.0)],
       "blued", segments=16)
    p.box((0, 0.360, -rbb - 0.0025), (0.0058, 0.008, 0.0055), "blued", bevel=0.001)
    _swivel(p, 0.360, -rbb - 0.0050)


def build_bolt(p):
    _y(p, BOLT_FACE_Y, Y_BR - 0.003, [(BOLT_R * 0.94, 0.0), (BOLT_R, 0.03), (BOLT_R, 1.0)], "bright", segments=14)
    for sz in (-1, 1):                                                                   # locking lugs
        p.box((0, 0.0045, sz * 0.0093), (0.0062, 0.010, 0.0034), "bright", bevel=0.0006)
    a = 25.0
    ex = (0.0094 * math.cos(math.radians(a)), -0.030, 0.0094 * math.sin(math.radians(a)))
    p.box(ex, (0.0018, 0.078, 0.0046), "bright", bevel=0.0004, rot=R('Y', -a))       # claw extractor
    p.box((ex[0] - 0.0012, 0.0085, ex[2] - 0.0006), (0.0016, 0.004, 0.0040), "bright", rot=R('Y', -a))  # claw
    _y(p, -0.068, -0.074, [(0.0094, 0.0), (0.0094, 1.0)], "bright", segments=14)      # extractor collar
    _y(p, Y_BR - 0.0025, Y_BR - 0.0155, [(0.0098, 0.0), (0.0101, 0.25), (0.0101, 0.75), (0.0098, 1.0)], "bright",
       segments=14)                                                                      # handle root
    radii = lambda t: 0.0042 - 0.0011 * t
    p.tube(STEM, radii, "bright", sides=8)
    # shroud and cocking piece (round, so they may turn with the bolt)
    _y(p, Y_BR - 0.0155, -0.168, [(0.0097, 0.0), (0.0099, 0.15), (0.0096, 0.7), (0.0088, 0.9), (0.0080, 1.0)],
       "blued", segments=14)
    _y(p, -0.168, -0.180, [(0.0058, 0.0), (0.0066, 0.35), (0.0062, 0.8), (0.0050, 1.0)], "blued", segments=12)


def build_knob(p):
    kit.seg(p, STEM_END - KNOB_D * 0.002, STEM_END + KNOB_D * 0.023,
            [(0.0034, 0.0), (0.0040, 0.12), (0.0062, 0.35), (0.0084, 0.62), (0.0086, 0.75), (0.0076, 0.9),
             (0.0050, 0.98), (0.0030, 1.0)], "knob", segments=12)


def build_ball(p):
    c = STEM_END + KNOB_D * 0.0063
    r = 0.0079
    prof = [(math.cos(a) * r, (math.sin(a) + 1.0) / 2.0) for a in np.linspace(-1.2, 1.25, 9)]
    kit.seg(p, c - KNOB_D * r, c + KNOB_D * r, prof, "ball", segments=14)
    _y(p, -0.004, Y_BR - 0.0015, [(0.0091, 0.0), (0.0091, 1.0)], "jewel", segments=16)   # jewelled sleeve


def build_fittings(p):
    # grip cap
    kit.seg(p, G1 - GRIP_AX * 0.0015, G1 + GRIP_AX * 0.0052, [(0.0181, 0.0), (0.0184, 0.35), (0.0176, 1.0)],
            "silver", segments=14, squash=GRIP_SQUASH)
    # fore-end tip cap over the horn
    g = 0.0008
    zc, hw, hh, n = section(0.2665)
    RP.loft(p, [(0.2665, zc, hw + g, hh + g, n)] + [(y, zc2, hw2 + g, hh2 + g, n2) for y, zc2, hw2, hh2, n2 in
                                                   _st(HORN)[1:]] +
            [(0.3013, _st(HORN)[-1][1], _st(HORN)[-1][2] * 0.93 + g, _st(HORN)[-1][3] * 0.93 + g, 2.6)],
            "silver", segs=18)
    # receiver side plates, both sides: ring, walls, bridge
    for a0, a1, b0, b1 in ((-16.0, 40.0, -16.0, 5.0), (140.0, 196.0, 145.0, 196.0)):
        RP.arc_shell(p, Y_RR + 0.0035, Y_RF - 0.0035, R_RING - 0.0004, R_RING + 0.0008, a0, a1, "silver", segs=6)
        RP.arc_shell(p, Y_BF + 0.0006, Y_RR - 0.0006, R_WALL - 0.0004, R_WALL + 0.0008, b0, b1, "silver", segs=6)
        if a0 < 90.0:                    # right side only: the bolt stop sits on the left of the bridge
            RP.arc_shell(p, Y_BR + 0.0035, Y_BF - 0.0045, R_BRIDGE - 0.0004, R_BRIDGE + 0.0008, a0, a1 - 10.0,
                         "silver", segs=6)
    # engraved overlay on the trigger guard bow (path nudged past the base ends)
    path = [Vector((0, y, z)) for y, z in GUARD]
    path[0] = path[0] + (path[0] - path[1]).normalized() * 0.0006
    path[-1] = path[-1] + (path[-1] - path[-2]).normalized() * 0.0006
    RP.strap(p, [(v.y, v.z) for v in path], 0.0105 + 0.0016, 0.0034 + 0.0016, "silver")


def build():
    gun = Part("rifle")
    build_stock(gun)
    build_action(gun)
    build_barrel(gun)
    bolt = Part("bolt", origin=tuple(BOLT_PIVOT), parent="rifle")
    build_bolt(bolt)
    kn = Part("bolt_knob", origin=tuple(KNOB_C), parent="bolt")
    build_knob(kn)
    bb = Part("upg_bolt_ball", origin=tuple(BOLT_PIVOT), parent="bolt")
    build_ball(bb)
    fit = Part("upg_fittings", origin=(0.0, 0.0, 0.0), parent="rifle")
    build_fittings(fit)
    clip = Part("clip", origin=tuple(CLIP_BOTTOM), parent="rifle")
    RP.stripper_clip(clip, CLIP_BOTTOM, (0, 0, 1), (0, 1, 0), n=5, s=1.0, segs=8)
    # right hand on the raked pistol grip (held diagonally: cant 45), its
    # sleeve back toward the eye and down; it sits just under the frame
    right = Part("hand_r", origin=tuple(GRIP_C), parent="rifle")
    m = hands.hand_matrix(GRIP_C, -GRIP_AX, (1.0, 0.0, 0.25), sx=1)
    sleeve_r, markers_r = hands.arm("r", right, m, 1, math.radians(45.0), (0.25, -0.9, -0.36), 0.26, parent="rifle")
    # left hand under the fore-end (cant 35), the forearm down and left to an
    # elbow under the rifle, a little back toward the eye
    left = Part("hand_l", origin=tuple(HAND_L_PIVOT), parent="rifle")
    m = hands.hand_matrix(FORE_C, (0, 1, 0), (0.55, 0.0, -0.85), sx=-1)
    sleeve_l, markers_l = hands.arm("l", left, m, -1, math.radians(35.0), (-0.50, -0.62, -0.60), 0.36, watch=True,
                                    parent="rifle")
    parts = [gun, bolt, kn, bb, fit, clip, right, left, sleeve_r, sleeve_l]
    return Model("vm_rifle_hunt", parts, FNS, ppm=512, organic=("hand_r", "hand_l", "sleeve_r", "sleeve_l"),
                 ao_dist=0.03, ao_rays=12, ao_stride=1, front=1, variants={"vm_rifle_hunt_master": MASTER_FNS},
                 markers=[("Muzzle", (0.0, MUZZLE_Y + 0.002, 0.0), None), ("BoltKnob", tuple(KNOB_C), "bolt")]
                 + markers_r + markers_l,
                 preview_yaws=(-60.0, 40.0, 110.0, 250.0), preview_elevation=16.0, preview_fp=(CAM, LOOK),
                 preview_extra=[("action", (0.012, -0.06, 0.0), 0.10, 62.0, 22.0),
                                ("action_l", (-0.01, -0.05, 0.0), 0.10, -55.0, 25.0),
                                ("butt", (-0.02, -0.36, -0.075), 0.08, -90.0, 4.0),
                                ("muzzle", (0.0, 0.57, 0.012), 0.06, 200.0, 12.0)])
