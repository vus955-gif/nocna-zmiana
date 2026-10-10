"""First-person flare pistol (rakietnica sygnałowa): a signal-orange
moulded break-action pistol with a fat 26.5 mm barrel, black steel hinge
pin, hammer, trigger and barrel latch, a lanyard ring under the grip and
"26,5mm" moulded on the barrel's left side, where the player sees it.
A flare cartridge sits in the chamber (brass rim at the breech).

Viewmodel conventions as in vm_fists.py (faces +Y = Godot -Z, real scale,
origin like vm_pistol so it drops into WeaponHolder.REST). Parts:
    flare    (0, 0, 0)               frame, grip, trigger guard, hammer, latch
    barrel   (0, 0.004, -0.018)      barrel + chambered flare; pivot = hinge pin
                                     (break open: rotate about X, negative angle
                                     tips the muzzle down, ~-35 deg fully open)
    hand_r   (0, -0.075, -0.085)     gloved hand round the grip + sleeve
Marker: Muzzle (0, 0.152, 0.014), direct child of the root (Godot
(0, 0.014, -0.152)); it does not follow the barrel when it is broken open.
The same frame and barrel (without the hand) hang in emergency_cabinet.

Upgrade parts (viewmodel only, never in build_frame / build_barrel, which
emergency_cabinet shares; hidden until bought, see _upgrade_bits_b.py):
    upg_shroud   (0, 0.046, 0.014)   parent barrel: "flare_burn" - a perforated
                                     copper heat shroud over the top and right of
                                     the barrel, open on the left so the "26,5mm"
                                     stays readable, held by two silvery magnesium
                                     bands round the barrel and a strap across it
    upg_barrel2  (0.049, 0.048, 0.014)  parent barrel: "flare_twin" - a second
                                     barrel side by side on the right, joined to
                                     the first by two webs underneath, with its own
                                     chambered flare (brass rim, red primer); it
                                     breaks open with the first
Texture sets: vm_flare, vm_flare_master (both upgrades bought: glossy
deep-orange enamel with gold pinstripes, gold lettering, polished brass,
fire-blued steel, polished copper and bright magnesium; same mesh and UVs).
"""
import math

import numpy as np
from mathutils import Vector

from artlib import hands, kit, pixelfont
from artlib import materials as M
from artlib.geo import Part
from artlib.kit import R, T
from artlib.model import Model
from models.vm_fists import FNS as HAND_FNS
from models.vm_pistol import CAM, LOOK, bore

GRIP_C = Vector((0.0, -0.075, -0.085))
GRIP_AXIS = Vector((0.0, 0.225, 0.974))
BORE_Z = 0.014
HINGE = Vector((0.0, 0.004, -0.018))
BREECH_Y = -0.032
MUZZLE_Y = 0.128
R_OUT = 0.021
R_BORE = 0.0136
LABEL = pixelfont.trim(pixelfont.render("26,5mm"))
LABEL_C = (0.046, BORE_Z)     # label centre (y, z) on the barrel's left side
# upgrades
SH_R0, SH_R1 = 0.0238, 0.0252                 # shroud sheet (clears the rib, r 0.023)
SH_A0, SH_A1 = math.radians(-30.0), math.radians(148.0)   # lower right, over the top, to the upper left
SH_Y0, SH_Y1 = 0.004, 0.09
BAND_R0, BAND_R1, BAND_W = 0.0200, 0.0268, 0.006
BANDS = (0.0, 0.086)                          # band starts (y); the label runs 0.008..0.084
STRAP_Y = 0.0445
X2 = 0.049                                    # second barrel's axis
R2 = 0.0205


def orange(ctx):
    return M.plastic(ctx, "plastic_orange", 5.4, seed=501, rough=0.36, scuff=0.9, speckle=0.1)


def grip(ctx):
    return M.checkering(ctx, M.plastic(ctx, "plastic_orange", 5.0, seed=503, rough=0.55, scuff=0.5, speckle=0.1),
                        period=0.004, depth=0.0004)


def _lettering(ctx):
    # the -X face is box-projected with u = -y, v = z (readable from the left)
    return pixelfont.stamp(ctx, LABEL, -LABEL_C[0], LABEL_C[1]) & (ctx.n[:, 0] < -0.7)


def label(ctx):
    """Raised panel on the barrel's left side with moulded white lettering."""
    s = M.plastic(ctx, "plastic_orange", 5.6, seed=505, rough=0.4, scuff=0.4, speckle=0.1)
    txt = _lettering(ctx)
    s.use_ramp(M.P["enamel_white"], mask=txt, shade=np.full(ctx.N, 6.4) + M._dither(ctx, 0.8, 7))
    s.height = s.height + txt * 0.0003
    return s


def black(ctx):
    return M.gun_steel(ctx, seed=507, center=3.4, wear=0.7)


def brass(ctx):
    return M.brass(ctx, seed=509)


def primer(ctx):
    return M.plastic(ctx, "paint_red", 5.0, seed=511, rough=0.35, scuff=0.2)


FNS = dict(HAND_FNS, orange=orange, grip=grip, label=label, black=black, brass=brass, primer=primer, bore=bore)


# --- upgrade materials --------------------------------------------------------

def _shroud_open(ctx):
    """Texels of the shroud sheet where the perforations go: away from its
    cut edges and from the bands and the strap."""
    y = ctx.p[:, 1]
    a = np.arctan2(ctx.p[:, 2] - BORE_Z, ctx.p[:, 0])
    wall = np.abs(ctx.n[:, 1]) < 0.5
    tx = ctx.texel
    ok = wall & (a > SH_A0 + 1.6 * tx / SH_R1) & (a < SH_A1 - 1.6 * tx / SH_R1)
    ok &= (y > BANDS[0] + BAND_W + 0.8 * tx) & (y < BANDS[1] - 0.8 * tx)
    ok &= np.abs(y - (STRAP_Y + 0.0015)) > 0.0015 + 1.2 * tx
    return ok


def shroud(ctx, master=False):
    """Perforated copper sheet, heat-browned toward the muzzle (base);
    polished copper at mastery."""
    from models import _upgrade_bits_b as U
    s = U.master_brass(ctx, seed=521, ramp="copper", center=7.4 if master else 6.3)
    if not master:
        # oxidised by the heat toward the muzzle: duller, less metallic
        heat = np.clip((ctx.p[:, 1] - 0.03) / 0.06, 0.0, 1.0) * (0.6 + 0.4 * ctx.fbm(20.0, 2, 522))
        s.shade = s.shade - heat * 1.2
        s.rough = 0.36 + heat * 0.15
        s.metal = 0.85 - heat * 0.2
    return U.perforated(ctx, s, _shroud_open(ctx), pitch=4, seed=523)


def magnesium(ctx, master=False):
    """Silvery magnesium bands: satin (base), polished bright (mastery)."""
    from artlib.painter import Surface
    from models import _upgrade_bits_b as U
    s = Surface(ctx.N)
    shade = (7.6 if master else 6.8) + ctx.fbm(np.array([3.0, 40.0, 3.0]), 2, 531) * 0.5 + M._dither(ctx, 0.4, 532)
    shade += ctx.edge(1.0) * 2.0 + np.clip(ctx.curv, 0, 1) * 0.6
    shade -= ctx.cavity(3.0) * 2.0 + (1.0 - ctx.ao) * 3.5
    s.use_ramp(U.BRIGHT, shade=shade)
    s.metal = np.full(ctx.N, 0.9)
    s.rough = (0.16 if master else 0.4) + ctx.rand(533) * 0.04
    return s


UPG_FNS = {"shroud": shroud, "mg_band": magnesium,
           "orange2": orange, "brass2": brass, "primer2": primer, "bore2": bore}


# --- mastery finish (vm_flare_master) -----------------------------------------

def _barrel_rings(ctx, axis_x, ys):
    """1-texel gold rings round a barrel (axis at x = axis_x) at ``ys``."""
    from models import _upgrade_bits_b as U
    on = (np.abs(ctx.n[:, 1]) < 0.5) & (np.hypot(ctx.p[:, 0] - axis_x, ctx.p[:, 2] - BORE_Z) < 0.0262)
    on &= ctx.p[:, 1] > BREECH_Y + 0.001
    return on & U.rings_at(ctx, ctx.p[:, 1], ys)


def _master_orange(ctx, axis_x=0.0):
    """Glossy deep-orange coach enamel, a gold pinstripe inside every edge of
    the frame and three rings round the barrel."""
    from models import _upgrade_bits_a as hb
    from models import _upgrade_bits_b as U
    s = U.enamel_gloss(ctx, "plastic_orange", 4.7, seed=541)
    gold = hb.pinstripe(ctx, 2.0, 3.0) | _barrel_rings(ctx, axis_x, (-0.0075, -0.0045, 0.0955))
    return U.inlay_gold(ctx, s, gold, seed=542, center=7.0, metal=0.5, rough=0.3)


def _master_grip(ctx):
    from models import _upgrade_bits_b as U
    s = U.enamel_gloss(ctx, "plastic_orange", 4.4, seed=543)
    s.rough = s.rough + 0.1
    return M.checkering(ctx, s, period=0.004, depth=0.0004)


def _master_label(ctx):
    """A deep burnt-orange plate (so the gold reads) with gold lettering
    and a gold border."""
    from models import _upgrade_bits_b as U
    s = U.enamel_gloss(ctx, "plastic_orange", 2.6, seed=545)
    gold = _lettering(ctx) | (U.border(ctx, 1.5) & (np.abs(ctx.n[:, 0]) > 0.7))
    s = U.inlay_gold(ctx, s, gold, seed=546, center=8.0, metal=0.35, rough=0.3)
    s.height = s.height + _lettering(ctx) * 0.0003
    return s


def _master_black(ctx):
    from models import _upgrade_bits_b as U
    return U.master_blued(ctx, seed=547, center=4.8, border_gold=False)


def _master_brass(ctx):
    from models import _upgrade_bits_b as U
    return U.master_brass(ctx, seed=549)


def _master_primer(ctx):
    from models import _upgrade_bits_b as U
    return U.enamel_gloss(ctx, "paint_red", 5.0, seed=551)


MASTER_FNS = dict(HAND_FNS, orange=_master_orange, grip=_master_grip, label=_master_label, black=_master_black,
                  brass=_master_brass, primer=_master_primer, bore=bore,
                  shroud=lambda c: shroud(c, master=True), mg_band=lambda c: magnesium(c, master=True),
                  orange2=lambda c: _master_orange(c, axis_x=X2), brass2=_master_brass, primer2=_master_primer,
                  bore2=bore)


# --------------------------------------------------------------------------
# geometry
# --------------------------------------------------------------------------

def build_frame(p):
    """Frame, grip, guard, trigger, hammer, latch, hinge pin (model space)."""
    p.box((0, -0.07, 0.01), (0.038, 0.078, 0.054), "orange", bevel=0.007)              # receiver / standing breech
    p.box((0, -0.074, 0.038), (0.022, 0.062, 0.008), "orange", bevel=0.003)             # top strap
    for sx in (-1, 1):
        p.box((sx * 0.019, -0.058, 0.004), (0.004, 0.036, 0.03), "orange", bevel=0.0015)  # raised side panels
    p.box((0, -0.004, -0.024), (0.028, 0.066, 0.014), "orange", bevel=0.004)           # tongue under the barrel
    kit.seg(p, (-0.016, HINGE.y, HINGE.z), (0.016, HINGE.y, HINGE.z), [(0.0045, 0), (0.0045, 1)], "black",
            segments=8)                                                                  # hinge pin
    p.tube([(0, 0.026, -0.03), (0, 0.026, -0.05), (0, 0.012, -0.062), (0, -0.018, -0.064), (0, -0.036, -0.056),
            (0, -0.04, -0.04)], 0.0042, "orange", sides=6, smooth=False)               # trigger guard
    t = p.box((0, 0, 0), (0.007, 0.008, 0.026), "black", bevel=0.002)
    p.move(t, T(0, 0.0, -0.04) @ R('X', 16))                                             # trigger
    h = p.box((0, 0, 0), (0.01, 0.014, 0.03), "black", bevel=0.002)
    spur = p.box((0, 0, 0), (0.012, 0.016, 0.006), "black", bevel=0.0015)
    p.move(spur, T(0, -0.008, 0.015) @ R('X', 30))
    p.move(h + spur, T(0, -0.104, 0.03) @ R('X', 28))                                   # hammer
    lat = p.box((0, 0, 0), (0.005, 0.03, 0.009), "black", bevel=0.0015)
    p.move(lat, T(-0.0195, -0.05, 0.004) @ R('X', -10))                                 # barrel latch (left side)
    g = p.box((0, 0, 0), (0.032, 0.052, 0.112), "grip", bevel=0.009)
    cap = p.box((0, 0, 0), (0.034, 0.054, 0.012), "orange", bevel=0.004)
    p.move(cap, T(0, 0, -0.058))
    p.move(g + cap, T(*GRIP_C) @ R('X', -13))
    ring_c = T(*GRIP_C) @ R('X', -13) @ Vector((0, -0.012, -0.072))
    pts = [(0, ring_c.y + 0.011 * np.cos(a), ring_c.z - 0.006 + 0.011 * np.sin(a)) for a in np.linspace(0, 2 * np.pi, 9)]
    p.tube(pts[:-1] + [pts[0]], 0.0022, "black", sides=4, caps=False)                   # lanyard ring


def build_barrel(p):
    kit.seg(p, (0, BREECH_Y, BORE_Z), (0, MUZZLE_Y, BORE_Z),
            [(R_OUT * 1.1, 0.0), (R_OUT * 1.1, 0.14), (R_OUT, 0.2), (R_OUT * 0.97, 0.82), (R_OUT * 1.16, 0.87),
             (R_OUT * 1.2, 0.93), (R_OUT * 1.2, 1.0)], "orange", segments=16)
    kit.seg(p, (0, MUZZLE_Y, BORE_Z), (0, MUZZLE_Y + 0.0006, BORE_Z), [(R_BORE, 0.0), (R_BORE, 1.0)], "bore",
            segments=14)
    p.box((0, (BREECH_Y + MUZZLE_Y) / 2 - 0.004, BORE_Z + R_OUT), (0.006, 0.13, 0.004), "orange", bevel=0.0012)  # rib
    p.box((0, 0.0, BORE_Z - R_OUT - 0.002), (0.02, 0.036, 0.018), "orange", bevel=0.003)                        # hinge lug
    p.box((-R_OUT + 0.0022, LABEL_C[0], LABEL_C[1]), (0.008, 0.076, 0.021), "label", bevel=0.001)                # moulded label
    # the chambered flare's brass rim and red primer cap at the breech face
    kit.seg(p, (0, BREECH_Y - 0.0016, BORE_Z), (0, BREECH_Y + 0.0004, BORE_Z), [(R_BORE + 0.0022, 0), (R_BORE + 0.0022, 1)],
            "brass", segments=14)
    kit.seg(p, (0, BREECH_Y - 0.0022, BORE_Z), (0, BREECH_Y - 0.0015, BORE_Z), [(0.0035, 0), (0.0035, 1)], "primer",
            segments=8)


def build_shroud(p):
    """Heat shroud: a perforated copper sheet (arc) 3 mm off the barrel over
    its top and right, open on the left (label) and underneath (hinge lug,
    frame tongue when broken open); magnesium bands at both ends round the
    whole barrel and a strap over the sheet in the middle."""
    from models import _upgrade_bits_b as U
    U.arc_band(p, 0.0, BORE_Z, SH_R0, SH_R1, SH_Y0, SH_Y1, SH_A0, SH_A1, "shroud", 18)
    for y in BANDS:
        U.ring(p, (0.0, y, BORE_Z), (0, 1, 0), BAND_R0, BAND_R1, 0.0, BAND_W, "mg_band", segments=18,
               phase=math.pi / 18, inner=False)
    da = math.radians(5.0)
    U.arc_band(p, 0.0, BORE_Z, SH_R1 - 0.0003, SH_R1 + 0.0011, STRAP_Y, STRAP_Y + 0.003, SH_A0 - da, SH_A1 + da,
               "mg_band", 18)


def build_barrel2(p):
    """The second barrel on the right: the first one's profile a touch slimmer
    (its muzzle flares less, clear of the shroud), rib, chambered flare, two
    webs underneath into the first barrel."""
    z = BORE_Z
    r = R2
    kit.seg(p, (X2, BREECH_Y, z), (X2, MUZZLE_Y, z),
            [(r * 1.1, 0.0), (r * 1.1, 0.14), (r, 0.2), (r * 0.97, 0.82), (r * 1.06, 0.87), (r * 1.1, 0.93),
             (r * 1.1, 1.0)], "orange2", segments=16)
    kit.seg(p, (X2, MUZZLE_Y, z), (X2, MUZZLE_Y + 0.0006, z), [(R_BORE * 0.96, 0.0), (R_BORE * 0.96, 1.0)], "bore2",
            segments=14)
    p.box((X2, (BREECH_Y + MUZZLE_Y) / 2 - 0.004, z + r), (0.005, 0.13, 0.004), "orange2", bevel=0.0012)   # rib
    for y0, y1 in ((-0.03, -0.004), (0.008, 0.083)):                                                     # webs
        p.box((0.0255, (y0 + y1) / 2, z - 0.0175), (0.023, y1 - y0, 0.005), "orange2", bevel=0.0012)
    kit.seg(p, (X2, BREECH_Y - 0.0016, z), (X2, BREECH_Y + 0.0004, z),
            [(R_BORE * 0.96 + 0.0022, 0), (R_BORE * 0.96 + 0.0022, 1)], "brass2", segments=14)
    kit.seg(p, (X2, BREECH_Y - 0.0022, z), (X2, BREECH_Y - 0.0015, z), [(0.0035, 0), (0.0035, 1)], "primer2",
            segments=8)


def build():
    from models import _upgrade_bits_a as hb
    gun = Part("flare")
    build_frame(gun)
    barrel = Part("barrel", origin=tuple(HINGE))
    build_barrel(barrel)
    hand = Part("hand_r", origin=tuple(GRIP_C))
    m = hands.hand_matrix(GRIP_C, GRIP_AXIS, (1.0, -0.25, 0.0), sx=1)
    wrist = hands.add_hand(hand, m, sx=1, tris=1000)
    hands.add_sleeve(hand, wrist, (0.3, -1.0, -0.6), length=0.34, sx=1)
    # upgrades: viewmodel only, hidden until bought; the base set ignores them in its AO
    sh = Part("upg_shroud", origin=(0.0, (SH_Y0 + SH_Y1) / 2, BORE_Z), parent="barrel")
    build_shroud(sh)
    b2 = Part("upg_barrel2", origin=(X2, (BREECH_Y + MUZZLE_Y) / 2, BORE_Z), parent="barrel")
    build_barrel2(b2)
    base = {k: hb.ao_without(f, ("upg_",), rays=12, dist=0.03) for k, f in FNS.items()}
    return Model("vm_flare", [gun, barrel, hand, sh, b2], dict(base, **UPG_FNS), ppm=512, organic=("hand_r",),
                 ao_dist=0.03, ao_rays=12, ao_stride=1, front=1,
                 markers=[("Muzzle", (0.0, MUZZLE_Y + 0.002, BORE_Z), None)],
                 variants={"vm_flare_master": MASTER_FNS},
                 preview_yaws=(-60.0, 40.0, 110.0, 250.0), preview_elevation=14.0,
                 preview_fp=(CAM, LOOK),
                 preview_extra=[("upg_left", (0.01, 0.045, 0.012), 0.085, -60.0, 25.0),
                                ("upg_right", (0.03, 0.045, 0.012), 0.085, 70.0, 20.0),
                                ("upg_breech", (0.025, -0.03, 0.014), 0.06, 200.0, 25.0)])
