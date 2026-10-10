"""First-person taser: a chunky yellow electroshock pistol with a black
rubber grip, a black cartridge with hazard stripes and two steel prongs,
and a battery indicator of three green LEDs on the back where the player
sees it. Held in the gloved right hand.

Viewmodel conventions as in vm_fists.py. Parts:
    taser        (0, 0, 0)            body, grip, guard, cartridge, prongs
    led_1..led_3 (0, y, 0.043)        battery LEDs, back to front (hide them as the charge drops)
    hand_r       (0, -0.057, -0.083)  gloved hand + sleeve
Marker: Muzzle (0, 0.13, 0.012), between the prongs (greybox: Godot
(0, 0.01, -0.13)).

Upgrade parts (hidden until bought, one per upgrade; see _upgrade_bits_a.py):
    upg_coil    (0.007, -0.024, 0.0555)  parent taser: "taser_charge" - a glass
                                         capacitor with an amber glowing core (baked
                                         into vm_taser_emit) lying on the top rail,
                                         right of centre, in two black cradles, a
                                         copper coil wound round its middle and led
                                         down into the rail; nickel end caps with
                                         terminal posts and leads
    upg_prongs  (0, 0.107, 0.012)        parent taser: "taser_chain" - a second pair
                                         of electrodes beside the first (inboard of
                                         them), on white porcelain insulators, joined
                                         by a copper bus bar across the cartridge face
Texture sets: vm_taser, vm_taser_master (both upgrades bought: glossy
enamel with gold pinstripes, gold chevrons on the cartridge, polished
copper and nickel, brighter core; same mesh and UVs).
"""
import math

import numpy as np
from mathutils import Vector

from artlib import hands, kit
from artlib import materials as M
from artlib.geo import Part
from artlib.kit import R, T
from artlib.model import Model
from artlib.painter import Surface
from models.vm_fists import FNS as HAND_FNS
from models.vm_pistol import CAM, LOOK

GRIP_C = Vector((0.0, -0.057, -0.083))
GRIP_AXIS = Vector((0.0, 0.139, 0.99))
LEDS = [-0.084, -0.074, -0.064]
# upgrades
RAIL_TOP, HOUSING_TOP = 0.046, 0.042
CAP_X, CAP_Z, CAP_R = 0.007, 0.0555, 0.0062     # capacitor axis (along Y) and glass radius
CAP_Y0, CAP_Y1 = -0.053, 0.005                   # glass envelope
END_L, END_R = 0.006, 0.0069                     # nickel end caps
COIL_Y0, COIL_Y1, COIL_TURNS, WIRE_R = -0.0345, -0.0125, 6, 0.00115
PRONG2_X, PRONG_Z, FACE_Y = 0.0085, 0.012, 0.106


def yellow(ctx):
    return M.plastic(ctx, "plastic_yellow", 5.0, seed=351, rough=0.42, scuff=1.2)


def _stripes(ctx):
    side = np.abs(ctx.n[:, 1]) < 0.5
    stripe = side & (np.mod((ctx.p[:, 1] + ctx.p[:, 2] + np.abs(ctx.p[:, 0])) / 0.012, 1.0) < 0.5)
    return stripe & (ctx.p[:, 1] > 0.068)


def cartridge(ctx):
    """Black cartridge, yellow hazard stripes on its sides and top."""
    s = M.plastic(ctx, "plastic_black", 2.6, seed=353, rough=0.5, scuff=0.8)
    stripe = _stripes(ctx)
    y = M.plastic(ctx, "plastic_yellow", 5.2, seed=355, rough=0.45, scuff=0.5)
    s.merge(M._select(y, stripe), stripe)
    return s


def led(ctx):
    return M.glow(ctx, "led_green", 4.6, strength=1.0, rough=0.2)


def panel(ctx):
    return M.crt_glass(ctx)


def prong(ctx):
    return M.steel(ctx, seed=357, center=9.0, dent=0.0, rust=0.0, polish=0.2, scratch=0.0)


def label(ctx):
    return M.enamel(ctx, "enamel_white", 5.8, seed=359, chip=0.3)


FNS = dict(HAND_FNS, yellow=yellow, black=M.rubber, cartridge=cartridge, led=led, panel=panel, prong=prong,
           label=label)


# --- upgrade materials --------------------------------------------------------

def _around(ctx):
    """Angle round the capacitor axis (0 = +X, pi/2 = up) per texel."""
    return np.arctan2(ctx.p[:, 2] - CAP_Z, ctx.p[:, 0] - CAP_X)


def core(ctx, master=False):
    """The capacitor seen through its glass: an amber core glowing brightest
    in the middle, dark electrode discs near both ends, a 1-texel reflection
    line along the upper left of the glass (not lit). Emissive."""
    s = Surface(ctx.N)
    y = ctx.p[:, 1]
    t = np.clip((y - CAP_Y0) / (CAP_Y1 - CAP_Y0), 0.0, 1.0)
    glow = 1.0 - np.abs(t - 0.5) * 2.0
    a = _around(ctx)
    up = ctx.n[:, 2]
    shade = (2.6 if not master else 3.0) + glow * 1.9 + up * 0.4 + ctx.fbm(300.0, 2, 361) * 0.35 \
        + M._dither(ctx, 0.5, 362)
    disc = (np.abs(y - (CAP_Y0 + 0.0042)) < 0.55 * ctx.texel) | (np.abs(y - (CAP_Y1 - 0.0042)) < 0.55 * ctx.texel)
    shade = np.where(disc, shade - 2.6, shade)
    s.use_ramp(M.P["eye_amber"], shade=shade)
    gap = np.angle(np.exp(1j * (a - math.radians(118.0)))) * CAP_R
    hl = (np.abs(gap) < 0.55 * ctx.texel) & (np.abs(ctx.n[:, 1]) < 0.5)
    s.use_ramp(M.P["glass"], mask=hl, shade=np.full(ctx.N, 3.0))
    s.rough = np.where(hl, 0.03, 0.06)
    col = s.colors()
    s.emit = np.where(hl[:, None], 0.0, col * ((0.4 if master else 0.32) + 0.25 * glow)[:, None])
    s.height = disc * -0.0002
    return s


def coil(ctx, master=False):
    """Copper wire: every turn lit along its top, dark between the turns."""
    from models import _upgrade_bits_b as U
    if master:
        s = U.master_brass(ctx, seed=363, ramp="copper", center=6.4)
    else:
        s = M.brass(ctx, seed=363, ramp="copper", tarnish_amount=1.0)
    s.shade = s.shade + ctx.n[:, 2] * 1.4 - (1.0 - ctx.ao) * 1.0
    return s


def cradle(ctx, master=False):
    from models import _upgrade_bits_b as U
    if master:
        s = U.enamel_gloss(ctx, "plastic_black", 3.2, seed=365)
        return U.inlay_gold(ctx, s, U.border(ctx, 1.5), seed=366, metal=0.6, rough=0.3)
    return M.plastic(ctx, "plastic_black", 3.0, seed=365, rough=0.4, scuff=0.6)


def nickel(ctx, master=False):
    from models import _upgrade_bits_b as U
    return U.polished_steel(ctx, seed=367, center=8.8 if master else 8.0, polish=0.1 if master else 0.18)


def insulator(ctx):
    return M.porcelain(ctx, seed=369, center=6.0, craze=0.6)


def busbar(ctx, master=False):
    from models import _upgrade_bits_b as U
    if master:
        return U.master_brass(ctx, seed=371, ramp="copper", center=6.6)
    return M.brass(ctx, seed=371, ramp="copper", tarnish_amount=1.4)


UPG_FNS = {"core": core, "coil": coil, "cradle": cradle, "nickel": nickel, "insulator": insulator,
           "busbar": busbar}


# --- mastery finish (vm_taser_master) ---------------------------------------

def _master_yellow(ctx):
    """Glossy yellow coach enamel with a gold pinstripe inside every edge."""
    from models import _upgrade_bits_a as hb
    from models import _upgrade_bits_b as U
    s = U.enamel_gloss(ctx, "plastic_yellow", 5.4, seed=381)
    return U.inlay_gold(ctx, s, hb.pinstripe(ctx, 2.0, 3.0), seed=382, center=7.0, metal=0.5, rough=0.3)


def _master_black(ctx):
    """Polished black hard rubber: fine checkering inside a plain border."""
    from models import _upgrade_bits_b as U
    s = U.enamel_gloss(ctx, "plastic_black", 3.3, seed=383)
    s.rough = s.rough + 0.08
    u, v = ctx.uvm[:, 0] / 0.0036, ctx.uvm[:, 1] / 0.0036
    g = (ctx.convex > 3.0 * ctx.texel) & ((np.mod(u + v, 1.0) < 0.34) | (np.mod(u - v, 1.0) < 0.34))
    s.shade = np.where(g, s.shade - 1.8, s.shade)
    s.height = s.height - g * 0.0003
    s.rough = np.where(g, np.minimum(s.rough + 0.2, 1.0), s.rough)
    return s


def _master_cartridge(ctx):
    """Glossy black enamel with gold chevrons where the hazard stripes were."""
    from models import _upgrade_bits_b as U
    s = U.enamel_gloss(ctx, "plastic_black", 3.0, seed=385)
    return U.inlay_gold(ctx, s, _stripes(ctx), seed=386, center=6.6, metal=0.6, rough=0.3)


def _master_label(ctx):
    from models import _upgrade_bits_b as U
    s = U.enamel_gloss(ctx, "enamel_white", 6.0, seed=387)
    return U.inlay_gold(ctx, s, U.border(ctx, 1.5), seed=388, metal=0.6, rough=0.3)


MASTER_FNS = dict(HAND_FNS, yellow=_master_yellow, black=_master_black, cartridge=_master_cartridge, led=led,
                  panel=panel, prong=lambda c: nickel(c, master=True), label=_master_label,
                  core=lambda c: core(c, master=True), coil=lambda c: coil(c, master=True),
                  cradle=lambda c: cradle(c, master=True), nickel=lambda c: nickel(c, master=True),
                  insulator=insulator, busbar=lambda c: busbar(c, master=True))


# --------------------------------------------------------------------------
# geometry
# --------------------------------------------------------------------------

def _body(p):
    p.box((0, -0.015, 0.011), (0.042, 0.15, 0.062), "yellow", bevel=0.006)             # housing
    p.box((0, -0.03, 0.043), (0.03, 0.09, 0.006), "yellow", bevel=0.002)                # top rail
    p.box((0, -0.074, 0.0405), (0.022, 0.034, 0.004), "panel", bevel=0.001)             # LED window
    p.box((0, -0.093, 0.03), (0.02, 0.006, 0.01), "black", bevel=0.002)                 # arc switch
    for sx in (-1, 1):
        p.box((sx * 0.0215, 0.0, 0.018), (0.0012, 0.05, 0.016), "label")               # warning label
    # cartridge and prongs
    p.box((0, 0.083, 0.011), (0.048, 0.046, 0.066), "cartridge", bevel=0.004)
    for sx in (-1, 1):
        kit.seg(p, (sx * 0.017, 0.105, 0.012), (sx * 0.017, 0.126, 0.012), [(0.0032, 0.0), (0.0028, 1.0)],
                "prong", segments=6)
        kit.cone(p, (sx * 0.017, 0.126, 0.012), (0, 1, 0), 0.006, 0.0036, "prong", segments=6)
    p.box((0, 0.1065, -0.012), (0.014, 0.002, 0.008), "panel")                          # laser window
    # grip, guard, trigger
    g = p.box((0, 0, 0), (0.036, 0.052, 0.112), "black", bevel=0.007)
    p.move(g, T(*GRIP_C) @ R('X', -8))
    p.tube([(0, 0.05, -0.018), (0, 0.05, -0.04), (0, 0.035, -0.054), (0, 0.0, -0.056), (0, -0.025, -0.05),
            (0, -0.03, -0.032)], 0.0045, "yellow", sides=5, smooth=False)
    t = p.box((0, 0, 0), (0.008, 0.008, 0.024), "black", bevel=0.002)
    p.move(t, T(0, 0.01, -0.032) @ R('X', 15))


def _y(p, y0, y1, radii, mat, x=CAP_X, z=CAP_Z, segments=12, caps=True):
    return kit.seg(p, (x, y0, z), (x, y1, z), radii, mat, segments=segments, caps=caps)


def _coil(p):
    """Capacitor, cradles, end caps with terminal posts, the coil and its
    leads (model space)."""
    from models import _upgrade_bits_b as U
    _y(p, CAP_Y0, CAP_Y1, [(CAP_R, 0.0), (CAP_R, 1.0)], "core", segments=12)
    for y_in, d in ((CAP_Y0, -1.0), (CAP_Y1, 1.0)):
        y_out = y_in + d * END_L
        _y(p, y_in - d * 0.0008, y_out, [(END_R, 0.0), (END_R, 0.75), (END_R - 0.0012, 1.0)], "nickel",
           segments=12)
        _y(p, y_out, y_out + d * 0.0034, [(0.0019, 0.0), (0.0019, 1.0)], "nickel", segments=6)       # post
        _y(p, y_out + d * 0.0012, y_out + d * 0.0026, [(0.0032, 0.0), (0.0032, 1.0)], "nickel", segments=6)  # nut
        # cradle: a pedestal on the rail and a collar round the end cap
        ym = y_in + d * END_L * 0.45
        h = CAP_Z - RAIL_TOP + 0.001
        p.box((CAP_X, ym, RAIL_TOP - 0.001 + h / 2 - 0.002), (0.0118, 0.0042, h - 0.004), "cradle", bevel=0.0012)
        U.ring(p, (CAP_X, ym - 0.0021, CAP_Z), (0, 1, 0), END_R - 0.0004, END_R + 0.0017, 0.0, 0.0042, "cradle",
               segments=10, inner=False)
        # lead from the terminal post down into the rail (the front one past
        # the rail's end, into the housing top)
        yl = y_out + d * 0.0022
        z_in = (RAIL_TOP if yl + d * 0.0036 < 0.0125 else HOUSING_TOP) - 0.0015
        p.tube([(CAP_X, yl, CAP_Z), (CAP_X, yl + d * 0.0026, CAP_Z - 0.0022), (CAP_X, yl + d * 0.0036, CAP_Z - 0.006),
                (CAP_X, yl + d * 0.0036, z_in)], 0.0009, "coil", sides=4)
    # the coil: from the rail, round the glass, back into the rail
    rc = CAP_R + WIRE_R * 0.92
    pts = [Vector((CAP_X - 0.0035, COIL_Y0 - 0.002, RAIL_TOP - 0.0015))]
    n = COIL_TURNS * 8
    for i in range(n + 1):
        t = i / n
        a = -math.pi / 2 + math.tau * COIL_TURNS * t
        pts.append(Vector((CAP_X + rc * math.cos(a), COIL_Y0 + (COIL_Y1 - COIL_Y0) * t, CAP_Z + rc * math.sin(a))))
    pts.append(Vector((CAP_X + 0.0035, COIL_Y1 + 0.002, RAIL_TOP - 0.0015)))
    p.tube(pts, WIRE_R, "coil", sides=5)


def _prongs(p):
    """Second pair of electrodes inboard of the first: porcelain insulators,
    steel prongs with points, a copper bus bar between them."""
    p.box((0, FACE_Y + 0.0006, PRONG_Z - 0.0045), (2 * PRONG2_X + 0.006, 0.0016, 0.0034), "busbar",
          bevel=0.0005)
    for sx in (-1, 1):
        x = sx * PRONG2_X
        kit.seg(p, (x, FACE_Y - 0.0005, PRONG_Z), (x, FACE_Y + 0.0062, PRONG_Z),
                [(0.0042, 0.0), (0.0042, 0.35), (0.0034, 0.5), (0.0034, 0.75), (0.0026, 1.0)], "insulator",
                segments=8)
        kit.seg(p, (x, FACE_Y + 0.006, PRONG_Z), (x, 0.1255, PRONG_Z), [(0.0026, 0.0), (0.0022, 1.0)], "prong",
                segments=6)
        kit.cone(p, (x, 0.1255, PRONG_Z), (0, 1, 0), 0.0055, 0.003, "prong", segments=6, tip=0.0007)
        p.box((x, FACE_Y + 0.0012, PRONG_Z - 0.0045), (0.0036, 0.0016, 0.0036), "busbar", bevel=0.0005)  # lug


def build():
    from models import _upgrade_bits_a as hb
    body = Part("taser")
    _body(body)
    leds = []
    for k, y in enumerate(LEDS):
        led_p = Part(f"led_{k + 1}", origin=(0, y, 0.043))
        led_p.box((0, y, 0.043), (0.007, 0.006, 0.003), "led", bevel=0.0008)
        leds.append(led_p)
    hand = Part("hand_r", origin=tuple(GRIP_C))
    m = hands.hand_matrix(GRIP_C, GRIP_AXIS, (1.0, -0.25, 0.0), sx=1)
    wrist = hands.add_hand(hand, m, sx=1, tris=1000)
    hands.add_sleeve(hand, wrist, (0.3, -1.0, -0.6), length=0.34, sx=1)
    # upgrades: hidden until bought; the base set ignores them in its AO
    cl = Part("upg_coil", origin=(CAP_X, (CAP_Y0 + CAP_Y1) / 2, CAP_Z), parent="taser")
    _coil(cl)
    pr = Part("upg_prongs", origin=(0.0, FACE_Y + 0.001, PRONG_Z), parent="taser")
    _prongs(pr)
    base = {k: hb.ao_without(f, ("upg_",), rays=12, dist=0.03) for k, f in FNS.items()}
    return Model("vm_taser", [body] + leds + [hand, cl, pr], dict(base, **UPG_FNS), ppm=512, organic=("hand_r",),
                 ao_dist=0.03, ao_rays=12, ao_stride=1, front=1, markers=[("Muzzle", (0.0, 0.13, 0.012), None)],
                 variants={"vm_taser_master": MASTER_FNS},
                 preview_yaws=(-60.0, 40.0, 110.0, 250.0), preview_elevation=16.0,
                 preview_fp=(CAM, LOOK),
                 preview_extra=[("upg_coil", (CAP_X, -0.024, CAP_Z - 0.004), 0.05, -50.0, 35.0),
                                ("upg_prongs", (0.0, 0.112, 0.012), 0.045, -30.0, 25.0)])
