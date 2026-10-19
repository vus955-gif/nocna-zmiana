"""First-person double-barrel shotgun: a side-by-side hammer gun, blued
barrels with a flat rib, an engraved silver action with two hammers,
walnut fore-end and stock with checkering. Right hand on the stock wrist,
left hand under the fore-end.

Viewmodel conventions as in vm_fists.py. Parts:
    shotgun              (0, 0, 0)           action, triggers, stock
    barrels              (0, -0.105, -0.03)  barrels, rib, fore-end; pivot = hinge pin
                                             (break open: rotate about X, muzzle down)
    hammer_l, hammer_r   (-/+0.018, -0.19, 0.0)  hammers, pivot at their axle
    hand_r               (0, -0.262, -0.04)  on the stock wrist
    hand_l               (0, 0.06, -0.034)   under the fore-end (goes with the barrels)
    sleeve_r, sleeve_l   at the wrist of each hand (the game turns them toward the elbows)
Marker: Muzzle (0, 0.48, 0) between the muzzles (greybox: Godot (0, 0, -0.48));
the arm markers Wrist_*/Grip_* (on the hands) and Elbow_* (artlib/hands.py arm()).

Upgrade parts (hidden until bought, one per upgrade level; see
_upgrade_bits_b.py):
    upg_choke         (0, 0.466, 0)       parent barrels (breaks open with them):
                                          "shotgun_spread" - knurled extended choke
                                          collars on both muzzles
    upg_slug_holder   (-0.027, -0.155, -0.012)  parent shotgun: "shotgun_slug" - a
                                          brass-and-leather side saddle with four slugs
                                          (brass heads up, red hulls) on the left side
                                          plate of the action, the side the player sees
                                          (the stock never shows in first person)
Texture sets: vm_shotgun, vm_shotgun_master (all upgrades maxed: deep fire
bluing with gold lines, engraved and gold-bordered silver action, exhibition
walnut; same mesh and UVs).
"""
import math

import numpy as np
from mathutils import Vector

from artlib import hands, kit
from artlib import materials as M
from artlib.geo import Part
from artlib.kit import R, T
from artlib.model import Model
from models import _upgrade_bits_b as U
from models.vm_fists import FNS as HAND_FNS
from models.vm_pistol import CAM, LOOK, bore

HINGE = Vector((0.0, -0.105, -0.03))
BARREL_X = 0.0205
BARREL_R = 0.0195
MUZZLE_Y = 0.47
# upgrades
CHOKE_Y0, CHOKE_L = 0.448, 0.036          # extended chokes: 22 mm over the barrel, 14 mm past the muzzle
KNURL_Y = (CHOKE_Y0 + 0.0106, CHOKE_Y0 + 0.0278)
SADDLE_X = -0.0285                        # outer face of the saddle's back plate (action side at -0.025)
SLUG_R, SLUG_RIM = 0.0093, 0.0103
SLUG_X = SADDLE_X - SLUG_R - 0.0002
SLUG_YS = [-0.155 + (k - 1.5) * 0.0215 for k in range(4)]
SLUG_TOP, SLUG_LEN, SLUG_HEAD = 0.011, 0.06, 0.013


def engraved(ctx):
    """Silver action with scroll engraving (curled lines in the metre-UV plane)."""
    s = M.steel(ctx, seed=361, center=8.6, dent=0.0, rust=0.4, polish=0.28, scratch=0.15)
    u, v = ctx.uvm[:, 0] / 0.012, ctx.uvm[:, 1] / 0.012
    cu, cv = np.floor(u), np.floor(v)
    fu, fv = u - cu - 0.5, v - cv - 0.5
    r = np.hypot(fu, fv)
    a = np.arctan2(fv, fu)
    turn = M.noise.rand_cells((cu * 31 + cv).astype(np.int64), 3) > 0.5
    spiral = np.abs(np.mod(r * 9.0 - np.where(turn, a, -a) / np.pi * 1.5, 1.0) - 0.5) < 0.12
    lines = spiral & (r < 0.48) & (np.abs(ctx.n[:, 0]) > 0.6)       # scrolls on the side plates
    s.shade[lines] -= 3.0
    s.height = s.height - lines * 0.0002
    return s


def stock(ctx):
    s = M.walnut_stock(ctx)
    wrist = (ctx.p[:, 1] < -0.215) & (ctx.p[:, 1] > -0.3)
    fore = (ctx.p[:, 1] > -0.05) & (ctx.p[:, 1] < 0.12)
    sub = M.checkering(ctx, M.walnut_stock(ctx), period=0.004)
    sel = wrist | fore
    s.merge(M._select(sub, sel), sel)
    return s


FNS = dict(HAND_FNS, blued=M.gun_steel, action=engraved, wood=stock, bore=bore)


# --- upgrade materials ------------------------------------------------------

def _on_knurl(ctx):
    return (ctx.p[:, 1] > KNURL_Y[0]) & (ctx.p[:, 1] < KNURL_Y[1]) & (np.abs(ctx.n[:, 1]) < 0.5)


def choke(ctx):
    """Bright polished choke tubes, a diamond-knurled grip band in the middle."""
    s = U.polished_steel(ctx, seed=371, center=7.8)
    return U.knurled(ctx, s, _on_knurl(ctx))


def slug_brass(ctx, polished=False):
    s = U.master_brass(ctx, seed=375) if polished else M.brass(ctx, seed=375, tarnish_amount=0.7)
    return U.shell_head_marks(ctx, s, [(SLUG_X, y) for y in SLUG_YS], SLUG_TOP, SLUG_RIM, 0.0026, seed=376)


def slug_hull(ctx, gloss=False):
    """Red plastic hull with fine moulded ribs along it."""
    s = M.plastic(ctx, "paint_red", 5.4, seed=377, rough=0.3 if gloss else 0.5, scuff=0.0 if gloss else 0.3,
                  speckle=0.12)
    u = np.floor(ctx.uvm[:, 0] / ctx.texel)
    rib = (np.mod(u, 3) == 0) & (np.abs(ctx.n[:, 2]) < 0.5)
    s.shade = s.shade - rib * 0.9
    s.height = s.height - rib * 0.00015
    return s


UPG_FNS = {"choke": choke, "slug_brass": slug_brass, "slug_hull": slug_hull,
           "saddle": lambda c: U.saddle_leather(c, seed=379, stitch=False),
           "saddle_plate": lambda c: U.saddle_leather(c, seed=381),
           "saddle_brass": lambda c: M.brass(c, seed=383, tarnish_amount=1.2)}


# --- mastery finish (vm_shotgun_master) ------------------------------------

def _master_blued(ctx):
    # gold rings round both barrels ahead of the breech and at the muzzles,
    # scrollwork on the breech ends of the barrels (seen over the action)
    y = ctx.p[:, 1]
    lathe = np.abs(ctx.n[:, 1]) < 0.5
    gold = lathe & U.rings_at(ctx, y, (-0.064, -0.059, 0.452, 0.457))
    eng = lathe & (y > -0.098) & (y < -0.068)
    return U.master_blued(ctx, seed=391, engrave_mask=eng, gold_mask=gold)


def _master_action(ctx):
    return U.master_silver(ctx, seed=393)


def _master_wood(ctx):
    wrist = (ctx.p[:, 1] < -0.215) & (ctx.p[:, 1] > -0.3)
    fore = (ctx.p[:, 1] > -0.05) & (ctx.p[:, 1] < 0.12)
    return U.figured_walnut(ctx, seed=395, checker=wrist | fore, period=0.0036)


def _master_choke(ctx):
    y = ctx.p[:, 1]
    lathe = np.abs(ctx.n[:, 1]) < 0.5
    gold = lathe & U.rings_at(ctx, y, (KNURL_Y[0] - 0.003, KNURL_Y[1] + 0.003))
    s = U.master_blued(ctx, seed=397, gold_mask=gold, border_gold=False)
    return U.knurled(ctx, s, _on_knurl(ctx))


MASTER_FNS = dict(HAND_FNS, blued=_master_blued, action=_master_action, wood=_master_wood, bore=bore,
                  choke=_master_choke, slug_brass=lambda c: slug_brass(c, polished=True),
                  slug_hull=lambda c: slug_hull(c, gloss=True),
                  saddle=lambda c: U.saddle_leather(c, seed=399, gloss=0.24, stitch=False),
                  saddle_plate=lambda c: U.saddle_leather(c, seed=401, gloss=0.24),
                  saddle_brass=lambda c: U.master_brass(c, seed=403))


def _barrels(p):
    for sx in (-1, 1):
        kit.seg(p, (sx * BARREL_X, -0.1, 0.0), (sx * BARREL_X, MUZZLE_Y, 0.0),
                [(BARREL_R * 1.12, 0.0), (BARREL_R * 1.05, 0.25), (BARREL_R, 0.5), (BARREL_R, 0.99),
                 (BARREL_R * 1.04, 1.0)], "blued", segments=12)
        kit.seg(p, (sx * BARREL_X, MUZZLE_Y, 0.0), (sx * BARREL_X, MUZZLE_Y + 0.0006, 0.0),
                [(BARREL_R * 0.72, 0.0), (BARREL_R * 0.72, 1.0)], "bore", segments=10)
    p.box((0, (MUZZLE_Y - 0.1) / 2, 0.019), (0.012, MUZZLE_Y + 0.1, 0.006), "blued", bevel=0.0015)  # top rib
    p.box((0, 0.46, 0.024), (0.004, 0.004, 0.004), "action")                                     # bead
    p.box((0, (MUZZLE_Y - 0.1) / 2, -0.017), (0.01, MUZZLE_Y + 0.1, 0.006), "blued")            # bottom rib
    p.box((0, -0.085, -0.028), (0.03, 0.05, 0.02), "blued", bevel=0.003)                          # lumps
    fe = kit.seg(p, (0, -0.07, -0.036), (0, 0.15, -0.034), [(0.022, 0.0), (0.027, 0.15), (0.026, 0.8),
                                                            (0.018, 1.0)], "wood", segments=12,
                 squash=(1.15, 0.85))
    p.box((0, -0.075, -0.05), (0.016, 0.03, 0.008), "action", bevel=0.002)                       # fore-end latch


def _action(p):
    p.box((0, -0.155, -0.012), (0.05, 0.09, 0.058), "action", bevel=0.005)                        # body
    lever = p.box((0, 0, 0), (0.012, 0.05, 0.008), "action", bevel=0.002)
    p.move(lever, T(0.006, -0.19, 0.02) @ R('Z', 18))                                            # top lever
    p.tube([(0, -0.13, -0.042), (0, -0.13, -0.066), (0, -0.16, -0.075), (0, -0.2, -0.07), (0, -0.215, -0.052)],
           0.004, "blued", sides=5, smooth=False)                                                # trigger guard
    for k, y in enumerate((-0.155, -0.172)):
        t = p.box((0, 0, 0), (0.006, 0.006, 0.024), "blued", bevel=0.0015)
        p.move(t, T(0, y, -0.052) @ R('X', 20))
    # stock: wrist and butt, tall and narrow
    kit.seg(p, (0, -0.195, -0.012), (0, -0.3, -0.052), [(0.021, 0.0), (0.018, 0.5), (0.02, 1.0)], "wood",
            segments=12, squash=(0.85, 1.1))
    kit.seg(p, (0, -0.3, -0.052), (0, -0.46, -0.095), [(0.02, 0.0), (0.034, 0.6), (0.045, 1.0)], "wood",
            segments=12, squash=(0.62, 1.3))


def _hammer(p, sx):
    y0 = -0.19
    body = p.box((0, 0, 0), (0.008, 0.016, 0.03), "action", bevel=0.002)
    spur = p.box((0, 0, 0), (0.012, 0.018, 0.006), "action", bevel=0.0015)
    p.move(spur, T(0, -0.012, 0.016) @ R('X', 25))
    p.move(body + spur, T(sx * 0.018, y0, 0.012) @ R('X', -20))


def _lathe_y(p, x, z, y0, prof, mat, segments=12, ring_scale=None, caps=(True, True)):
    """Lathe round an axis parallel to +Y through (x, *, z), profile
    [(r, distance from y0)]; local angle a lands at world (x + r cos a, z - r sin a)."""
    f = p.lathe(prof, mat, segments=segments, cap_bottom=caps[0], cap_top=caps[1], ring_scale=ring_scale)
    p.move(f, T(x, y0, z) @ R('X', -90))
    return f


def _chokes(p):
    """Extended chokes: knurled collars over both muzzles, 14 mm proud of
    them, flattened where the two barrels meet so the pair stays apart."""
    L = CHOKE_L
    prof = [(0.0203, 0.0), (0.0216, 0.0018), (0.0216, 0.009), (0.0222, 0.0106), (0.0222, 0.0278),
            (0.0216, 0.0294), (0.0216, 0.0342), (0.0206, L), (0.0145, L), (0.0145, L - 0.004)]
    segs = 12
    for sx in (-1, 1):
        def flat(i, j, sx=sx):
            a = 2 * math.pi * i / segs
            w = prof[j][0] * math.cos(a) * -sx           # how far the vertex reaches toward the other barrel
            lim = BARREL_X - 0.0004
            return lim / w if w > lim else 1.0
        _lathe_y(p, sx * BARREL_X, 0.0, CHOKE_Y0, prof, "choke", segments=segs, ring_scale=flat, caps=(True, False))
        _lathe_y(p, sx * BARREL_X, 0.0, CHOKE_Y0 + L - 0.0046, [(0.0145, 0.0), (0.0145, 0.0006)], "bore",
                 segments=12)


def _slug_holder(p):
    """Side saddle on the left side plate of the action: a leather-faced
    brass back plate with end flanges, two leather loops round each slug,
    a brass rivet on every loop, four slugs standing brass heads up."""
    y0, y1 = SLUG_YS[0] - SLUG_R - 0.0026, SLUG_YS[-1] + SLUG_R + 0.0026
    yc = (y0 + y1) / 2
    p.box((SADDLE_X + 0.00185, yc, -0.014), (0.0037, y1 - y0, 0.044), "saddle_brass", bevel=0.0012)
    p.box((SADDLE_X - 0.0006, yc, -0.014), (0.0012, y1 - y0 - 0.006, 0.038), "saddle_plate", bevel=0.0004)
    for y in (y0 - 0.0012, y1 + 0.0012):                                    # end flanges
        p.box((SLUG_X - 0.0005, y, -0.017), (2 * SLUG_R + 0.0062, 0.0024, 0.04), "saddle_brass", bevel=0.0008)
    for y in SLUG_YS:
        zb = SLUG_TOP - SLUG_LEN
        zh = SLUG_TOP - SLUG_HEAD
        p.lathe([(0.0081, zb), (SLUG_R, zb + 0.0024), (SLUG_R, zh)], "slug_hull", segments=10,
                center=(SLUG_X, y, 0.0))
        p.lathe([(0.0096, zh), (0.0096, SLUG_TOP - 0.0017), (SLUG_RIM, SLUG_TOP - 0.0014), (SLUG_RIM, SLUG_TOP)],
                "slug_brass", segments=10, center=(SLUG_X, y, 0.0))
        for z0, z1 in ((-0.0125, -0.0045), (-0.0365, -0.0285)):              # leather loops
            U.ring(p, (SLUG_X, y, 0.0), (0, 0, 1), SLUG_R - 0.0003, SLUG_R + 0.0016, z0, z1, "saddle", segments=10,
                   inner=False)
            kit.seg(p, (SLUG_X - SLUG_R - 0.0012, y, (z0 + z1) / 2), (SLUG_X - SLUG_R - 0.0026, y, (z0 + z1) / 2),
                    [(0.0017, 0.0), (0.0009, 1.0)], "saddle_brass", segments=6)


def build():
    gun = Part("shotgun")
    _action(gun)
    barrels = Part("barrels", origin=tuple(HINGE))
    _barrels(barrels)
    hl = Part("hammer_l", origin=(-0.018, -0.19, 0.0))
    _hammer(hl, -1)
    hr = Part("hammer_r", origin=(0.018, -0.19, 0.0))
    _hammer(hr, 1)
    # right hand on the straight stock wrist: the forearm continues the
    # stock's line (cant 70), the sleeve back along it and a little down; it
    # sits below the frame
    right = Part("hand_r", origin=(0, -0.262, -0.04))
    m = hands.hand_matrix((0, -0.262, -0.036), (0, 0.9, 0.44), (1.0, 0.0, 0.6), sx=1)
    sleeve_r, markers_r = hands.arm("r", right, m, 1, math.radians(70.0), (0.05, -0.95, -0.3), 0.22)
    left = Part("hand_l", origin=(0, 0.06, -0.034))
    # palm under the fore-end, knuckles on its right, fingers over the top
    # (cant 35); the forearm down and left to an elbow under the gun
    m = hands.hand_matrix((0, 0.06, -0.034), (0, 1, 0), (0.7, 0.0, -0.7), sx=-1)
    sleeve_l, markers_l = hands.arm("l", left, m, -1, math.radians(35.0), (-0.50, -0.62, -0.60), 0.36, watch=True)
    # upgrades: only on the viewmodel (nothing else builds from this file)
    chk = Part("upg_choke", origin=(0.0, MUZZLE_Y - 0.004, 0.0), parent="barrels")
    _chokes(chk)
    sad = Part("upg_slug_holder", origin=(SADDLE_X + 0.0015, -0.155, -0.012), parent="shotgun")
    _slug_holder(sad)
    # the base set ignores the upgrade parts in its AO (no dark ghost of a
    # choke or a side saddle while they are hidden); at mastery all are on
    from models import _upgrade_bits_a as hb
    base = {k: hb.ao_without(f, ("upg_",), rays=12, dist=0.03) for k, f in FNS.items()}
    fns = dict(base, **UPG_FNS)
    return Model("vm_shotgun", [gun, barrels, hl, hr, right, left, sleeve_r, sleeve_l, chk, sad], fns, ppm=384,
                 organic=("hand_r", "hand_l", "sleeve_r", "sleeve_l"), ao_dist=0.03, ao_rays=12, ao_stride=1, front=1,
                 markers=[("Muzzle", (0.0, 0.48, 0.0), None)] + markers_r + markers_l,
                 variants={"vm_shotgun_master": MASTER_FNS},
                 preview_yaws=(-60.0, 40.0, 110.0, 250.0), preview_elevation=16.0,
                 preview_fp=(CAM, LOOK),
                 preview_extra=[("upg_choke", (0.0, 0.455, 0.0), 0.06, -35.0, 25.0),
                                ("upg_slug", (-0.035, -0.155, -0.015), 0.07, -70.0, 22.0)])
