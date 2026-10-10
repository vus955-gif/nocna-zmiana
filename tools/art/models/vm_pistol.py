"""First-person service pistol: an old steel single-action pistol in the
style of the 1935 Browning (blued slide and frame, checkered brown bakelite
grips, exposed hammer), held in the guard's gloved right hand.

Viewmodel conventions as in vm_fists.py (faces +Y, greybox origin, real
scale). Parts:
    pistol  (0, 0, 0)             frame, grip, trigger, hammer, levers
    slide   (0, 0, 0)             slide with sights and barrel end (recoil: move along -Y)
    hand_r  (0, -0.07, -0.088)    gloved hand round the grip + sleeve
Marker: Muzzle (0, 0.12, 0.012), a direct child of the root (greybox had it
at Godot (0, 0.01, -0.12)).

Upgrade parts (hidden until bought, one per upgrade; see _upgrade_bits_a.py):
    upg_mag    (0, -0.082, -0.138)  parent pistol: "pistol_mag" - an extended
                                    magazine below the grip: a blued body with
                                    witness holes (brass showing) and a brass base
                                    plate with a finger rest, clear of the hand
    upg_inlay  (0, 0.016, 0.016)    parent slide (recoils with it): "pistol_damage" -
                                    engraved brass inlay panels on both sides of the
                                    slide (one long panel on the left, two round the
                                    ejection port on the right)
Texture sets: vm_pistol, vm_pistol_master (both upgrades bought: deep polished
bluing with bright edges, scroll engraving and gold lines, figured walnut
grips, gold inlays, polished brass base plate; same mesh and UVs).
"""
import math

import numpy as np
from mathutils import Vector

from artlib import hands, kit
from artlib import materials as M
from artlib.geo import Part
from artlib.kit import R, T
from artlib.model import Model
from models.vm_fists import FNS as HAND_FNS

GRIP_C = Vector((0.0, -0.07, -0.088))
GRIP_AXIS = Vector((0.0, 0.208, 0.978))
CAM = (-0.224, -0.53, 0.16)          # the player's eye relative to the weapon (WeaponHolder.REST, AIM_YAW)
LOOK = (0.0998, 0.995, 0.0)
# upgrades
GRIP_M = T(0, -0.066, -0.075) @ R('X', -12)     # grip frame (z up the grip, origin at the grip core's centre)
GRIP_INV = GRIP_M.inverted()
MAG_Z0, MAG_Z1 = -0.064, -0.0888                # magazine body (grip frame): buried 1 mm in the grip's base
PLATE_Z = -0.0918                               # base plate centre (grip frame)
HOLES = (-0.0705, -0.0765)                      # witness holes (grip frame z), left side
INLAY_Z = (0.0056, 0.0274)                      # inlay panels: bottom and top on the slide's sides
INLAY_LEFT = (-0.06, 0.093)
INLAY_RIGHT = ((-0.06, -0.027), (0.027, 0.093))  # round the ejection port (y -0.022..0.022)
SLIDE_X = 0.014                                 # the slide's side faces


def barrel_y(p, y0, y1, z, r, mat, segments=10, caps=True):
    return kit.seg(p, (0, y0, z), (0, y1, z), [(r, 0.0), (r, 1.0)], mat, segments=segments, caps=caps,
                   smooth=True)


def _serrations(ctx):
    side = np.abs(ctx.n[:, 0]) > 0.7
    return side & (ctx.p[:, 1] < -0.068) & (np.mod(ctx.p[:, 1] / 0.0032, 1.0) < 0.45) & (ctx.p[:, 2] > 0.004)


def slide_steel(ctx):
    s = M.gun_steel(ctx, seed=341)
    serr = _serrations(ctx)
    s.shade[serr] -= 2.2
    s.height = s.height - serr * 0.0004
    return s


def grip(ctx):
    return M.checkering(ctx, M.plastic(ctx, "bakelite", 3.8, seed=343, rough=0.32, scuff=0.5), period=0.0035)


def bore(ctx):
    return M.plastic(ctx, "plastic_black", 0.4, seed=347, rough=0.6, scuff=0.0, speckle=0.1)


def sight_dot(ctx):
    return M.enamel(ctx, "enamel_white", 6.5, seed=349, chip=0.0)


FNS = dict(HAND_FNS, gunmetal=M.gun_steel, slide=slide_steel, grip=grip, bore=bore, dot=sight_dot)


# --- upgrade materials --------------------------------------------------------

def _grip_local(ctx):
    """Texel positions and normals in the grip frame."""
    m = np.array(GRIP_INV)
    p = ctx.p @ m[:3, :3].T + m[:3, 3]
    n = ctx.n @ m[:3, :3].T
    return p, n


def mag_body(ctx, master=False):
    """Blued magazine body; two witness holes on the left show the brass of
    the rounds inside."""
    from models import _upgrade_bits_b as U
    s = U.master_blued(ctx, seed=421, center=5.4, border_gold=False) if master else M.gun_steel(ctx, seed=421)
    p, n = _grip_local(ctx)
    left = n[:, 0] < -0.7
    d = np.full(ctx.N, np.inf)
    for z in HOLES:
        d = np.minimum(d, np.hypot(p[:, 1] + 0.008, p[:, 2] - z))
    brass = left & (d < 0.62 * ctx.texel)
    rim = left & ~brass & (d < 1.25 * ctx.texel)
    s.shade = np.where(rim, 0.4, s.shade)
    s.use_ramp(M.P["brass"], mask=brass, shade=np.full(ctx.N, 7.2 if master else 6.2))
    s.metal = np.where(brass, 1.0, s.metal)
    s.rough = np.where(rim, 0.8, np.where(brass, 0.25, s.rough))
    s.height = s.height - rim * 0.0005
    return s


def mag_plate(ctx, master=False):
    """Brass base plate: a rolled grip line across its front lip."""
    from models import _upgrade_bits_b as U
    s = U.master_brass(ctx, seed=423, engrave_mask=ctx.convex > 3.0 * ctx.texel) if master else \
        M.brass(ctx, seed=423, tarnish_amount=1.4)
    p, n = _grip_local(ctx)
    lines = (n[:, 1] > 0.6) & (np.mod(np.floor(p[:, 2] / ctx.texel), 2) == 0)
    s.shade = np.where(lines, s.shade - 1.6, s.shade)
    s.height = s.height - lines * 0.00015
    return s


def inlay(ctx, master=False):
    """Engraved brass panels: a running vine scroll between two border
    lines (1-texel cuts, also in the height map); at mastery bright gold."""
    from models import _upgrade_bits_a as hb
    side = np.abs(ctx.n[:, 0]) > 0.85
    zc = (INLAY_Z[0] + INLAY_Z[1]) / 2
    vine = hb.scroll(ctx.uvm[:, 0], ctx.uvm[:, 1], ctx.texel, zc, lam=14.0, amp=1.3, rad=2.1, turns=1.1)
    inner = side & (ctx.convex > 2.6 * ctx.texel)
    line = side & (np.abs(ctx.convex - 1.6 * ctx.texel) < 0.5 * ctx.texel)
    cut = (vine & inner) | line
    if master:
        return hb.polished_brass(ctx, 425, ramp="gold", center=6.9, engrave=cut)
    # a calm, softly worn brass ground: the cuts must read at 2 mm a texel
    s = hb.polished_brass(ctx, 425, ramp="brass", center=6.1, engrave=cut)
    s.shade = s.shade - (ctx.fbm(9.0, 2, 426) > 0.25) * 0.8
    s.rough = s.rough + 0.14
    return s


UPG_FNS = {"mag": mag_body, "mag_plate": mag_plate, "inlay": inlay}


# --- mastery finish (vm_pistol_master) ---------------------------------------

GUARD = [(0, 0.046, -0.02), (0, 0.046, -0.042), (0, 0.03, -0.053), (0, 0.0, -0.055), (0, -0.022, -0.05),
         (0, -0.03, -0.036), (0, -0.03, -0.022)]


def _near_guard(ctx):
    """Texels on the trigger guard (a thin flat-shaded rod: all edge)."""
    d = np.full(ctx.N, np.inf)
    P = np.asarray(GUARD)
    for a, b in zip(P[:-1], P[1:]):
        ab = b - a
        t = np.clip(((ctx.p - a) @ ab) / (ab @ ab), 0.0, 1.0)
        d = np.minimum(d, np.linalg.norm(ctx.p - (a + t[:, None] * ab), axis=1))
    return d < 0.0055


def _master_frame(ctx):
    from models import _upgrade_bits_b as U
    side = np.abs(ctx.n[:, 0]) > 0.7
    return U.master_blued(ctx, seed=431, center=5.4, engrave_mask=side & (ctx.convex > 4.5 * ctx.texel),
                          bright_mask=~_near_guard(ctx))


def _master_slide(ctx):
    from models import _upgrade_bits_b as U
    serr = _serrations(ctx)
    eng = (ctx.convex > 4.0 * ctx.texel) & (ctx.p[:, 1] > -0.064)
    s = U.master_blued(ctx, seed=433, center=5.6, engrave_mask=eng)
    s.shade = np.where(serr, s.shade - 2.2, s.shade)
    s.height = s.height - serr * 0.0004
    return s


def _master_grip(ctx):
    from models import _upgrade_bits_b as U
    return U.figured_walnut(ctx, seed=435, center=4.2, checker=ctx.convex > 2.5 * ctx.texel, period=0.0034)


MASTER_FNS = dict(HAND_FNS, gunmetal=_master_frame, slide=_master_slide, grip=_master_grip, bore=bore,
                  dot=sight_dot, mag=lambda c: mag_body(c, master=True), mag_plate=lambda c: mag_plate(c, master=True),
                  inlay=lambda c: inlay(c, master=True))


# --------------------------------------------------------------------------
# geometry
# --------------------------------------------------------------------------

def _frame(p):
    p.box((0, 0.02, -0.011), (0.026, 0.16, 0.022), "gunmetal", bevel=0.0025)
    p.tube([(0, 0.046, -0.02), (0, 0.046, -0.042), (0, 0.03, -0.053), (0, 0.0, -0.055), (0, -0.022, -0.05),
            (0, -0.03, -0.036), (0, -0.03, -0.022)], 0.0035, "gunmetal", sides=5, smooth=False)
    trig = p.box((0, 0, 0), (0.006, 0.006, 0.022), "gunmetal", bevel=0.0015)
    p.move(trig, T(0, 0.006, -0.034) @ R('X', 18))
    core = p.box((0, 0, 0), (0.029, 0.05, 0.118), "gunmetal", bevel=0.004)
    panels = []
    for sx in (-1, 1):
        panels += p.box((sx * 0.0165, 0.0, -0.004), (0.005, 0.043, 0.088), "grip", bevel=0.002)
    base = p.box((0, -0.002, -0.061), (0.031, 0.056, 0.008), "gunmetal", bevel=0.002)
    p.move(core + panels + base, T(0, -0.066, -0.075) @ R('X', -12))
    ham = p.box((0, 0, 0), (0.008, 0.01, 0.02), "gunmetal", bevel=0.002)
    p.move(ham, T(0, -0.106, 0.026) @ R('X', 25))
    p.box((-0.0155, -0.074, 0.003), (0.004, 0.02, 0.006), "gunmetal", bevel=0.0012)     # thumb safety
    p.box((-0.0145, 0.022, -0.005), (0.003, 0.022, 0.006), "gunmetal", bevel=0.001)     # slide stop


def _slide(p):
    p.box((0, 0.004, 0.016), (0.028, 0.208, 0.034), "slide", bevel=0.0028)
    p.box((0, 0.1, 0.037), (0.004, 0.008, 0.008), "slide", bevel=0.001)                  # front sight
    p.box((0, 0.1035, 0.0385), (0.0042, 0.0012, 0.003), "dot")
    for sx in (-1, 1):
        p.box((sx * 0.0065, -0.094, 0.037), (0.006, 0.007, 0.008), "slide", bevel=0.001)   # rear sight
        p.box((sx * 0.0065, -0.0978, 0.0385), (0.003, 0.0012, 0.003), "dot")
    p.box((0.0145, 0.0, 0.021), (0.002, 0.044, 0.014), "bore")                         # ejection port
    barrel_y(p, 0.105, 0.1105, 0.012, 0.0078, "gunmetal", segments=10)
    barrel_y(p, 0.1105, 0.1112, 0.012, 0.0045, "bore", segments=8)


def _magazine(p):
    """Extended magazine (built in the grip frame, then tilted with the grip):
    a narrower blued body out of the grip's base, a brass base plate with a
    finger rest at the front."""
    before = set(p.bm.faces)
    h = MAG_Z0 - MAG_Z1
    p.box((0, -0.003, (MAG_Z0 + MAG_Z1) / 2), (0.0215, 0.041, h), "mag", bevel=0.0016)
    p.box((0, -0.002, PLATE_Z), (0.0262, 0.0475, 0.0064), "mag_plate", bevel=0.0016)
    lip = p.box((0, 0, 0), (0.022, 0.009, 0.0052), "mag_plate", bevel=0.0014)
    p.move(lip, T(0, 0.0232, PLATE_Z - 0.0004) @ R('X', -15))                       # finger rest
    new = [f for f in p.bm.faces if f not in before]
    p.move(new, GRIP_M)


def _inlays(p):
    """Brass panels 0.4 mm proud of the slide's sides (buried 0.2 mm), their
    ends drawn to points."""
    from models import _upgrade_bits_a as hb
    z0, z1 = INLAY_Z
    zm = (z0 + z1) / 2

    def outline(y0, y1, pt=0.008):
        return [(y0 + pt, z0), (y1 - pt, z0), (y1, zm), (y1 - pt, z1), (y0 + pt, z1), (y0, zm)]

    hb.panel(p, outline(*INLAY_LEFT), SLIDE_X - 0.0002, SLIDE_X + 0.0004, "inlay", chamfer=0.0004, side=-1)
    for y0, y1 in INLAY_RIGHT:
        hb.panel(p, outline(y0, y1, pt=0.006), SLIDE_X - 0.0002, SLIDE_X + 0.0004, "inlay", chamfer=0.0004, side=1)


def build():
    from models import _upgrade_bits_a as hb
    gun = Part("pistol")
    _frame(gun)
    slide = Part("slide")
    _slide(slide)
    hand = Part("hand_r", origin=tuple(GRIP_C))
    m = hands.hand_matrix(GRIP_C, GRIP_AXIS, (1.0, -0.25, 0.0), sx=1)
    wrist = hands.add_hand(hand, m, sx=1, tris=1000)
    hands.add_sleeve(hand, wrist, (0.3, -1.0, -0.6), length=0.34, sx=1)
    # upgrades: hidden until bought; the base set ignores them in its AO
    mag = Part("upg_mag", origin=tuple(GRIP_M @ Vector((0.0, -0.002, -0.065))), parent="pistol")
    _magazine(mag)
    inl = Part("upg_inlay", origin=(0.0, 0.016, 0.016), parent="slide")
    _inlays(inl)
    base = {k: hb.ao_without(f, ("upg_",), rays=12, dist=0.03) for k, f in FNS.items()}
    return Model("vm_pistol", [gun, slide, hand, mag, inl], dict(base, **UPG_FNS), ppm=512, organic=("hand_r",),
                 ao_dist=0.03, ao_rays=12, ao_stride=1, front=1, markers=[("Muzzle", (0.0, 0.12, 0.012), None)],
                 variants={"vm_pistol_master": MASTER_FNS},
                 preview_yaws=(-60.0, 40.0, 110.0, 250.0), preview_elevation=12.0,
                 preview_fp=(CAM, LOOK),
                 preview_extra=[("upg_left", (0.0, -0.01, -0.03), 0.085, -75.0, 12.0),
                                ("upg_right", (0.0, 0.03, 0.01), 0.075, 95.0, 15.0),
                                ("upg_mag", (0.0, -0.08, -0.12), 0.06, -60.0, -20.0)])
