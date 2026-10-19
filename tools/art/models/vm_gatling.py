"""First-person hand-cranked Gatling (kartaczownica, 1871 pattern): six
blued barrels round a central shaft, held by three bands, a polished
brass breech casing with a cascabel knob and "1871" engraved on the
cascabel plate, a brass feed hopper on top, a steel frame rail running
forward to a front bearing ring with a walnut foregrip, and the side
crank on the right. A khaki canvas belt of brass cartridges comes up the
left side into the hopper.

Viewmodel conventions as in vm_fists.py (faces +Y = Godot -Z, real scale).
The model is the gun space below moved by VM_SHIFT = (0, 0.16, -0.06):
carried low at the hip, so at WeaponHolder.REST the player looks down onto
the barrels, which point at the centre of the screen from the lower right,
and the brass casing sits in the corner without filling it. Parts (model
space, Blender axes):
    gatling   (0, 0, 0)                casing, hopper, frame rail, front bearing,
                                       foregrip, sights
    barrels   (0, 0.16, -0.06)         barrel cluster; pivot on the spin axis
                                       (spin: rotate about local Y = Godot Z)
    crank     (0.1, 0.03, -0.06)       crank arm + walnut knob; pivot on the crank
                                       shaft (turn: rotate about X)
    belt      (-0.035, 0.05, 0.029)    cartridge belt from the hopper mouth down the
                                       left side (jiggle it, or scroll it while firing)
    hand_r    (0.145, 0.03, -0.155)    right hand on the crank knob, pivot = knob
    hand_l    (0, 0.515, -0.2)         left hand on the foregrip
    sleeve_r, sleeve_l                 the sleeves, pivot = the wrist of each hand
Markers: Muzzle (0, 0.788, -0.028) at the end of the top barrel (the firing
position; direct child of the root, it does not spin), CrankKnob (child of
crank, at the knob): to crank by hand, move hand_r with the knob every
frame (hand_r.position = its rest position + knob offset from its rest
position), without rotating it; the arm markers Wrist_*/Grip_* (on the
hands) and Elbow_* (artlib/hands.py arm(): the game turns each sleeve from
the wrist toward the elbow, so the cranking hand keeps its forearm).
gatling_display.py puts the same gun (build_gun) on a museum tripod.

Upgrade parts (viewmodel only, never in build_gun: the display gun stays
as it is; hidden until bought, see _upgrade_bits_b.py):
    upg_crank  (0.1, 0.03, -0.06)      parent crank (turns with it): "gatling_spin" -
                                       a polished steel sleeve with a brass grease cup on
                                       the crank arm and a brass shell over the walnut
                                       knob (the knob, CrankKnob and the hand stay put)
    upg_drum   (-0.072, 0.054, 0.006)  parent gatling: "gatling_belt" - a brass belt drum
                                       on the hopper's left side, round the belt's top
                                       turn: the belt comes out of a slot in its wall, the
                                       rear face shows the coiled belt (cartridge heads in
                                       a spiral) to the player
Texture sets: vm_gatling, vm_gatling_master (all upgrades maxed: polished
engraved brass, fire-blued barrels and frame with gold lines, exhibition
walnut; same mesh and UVs).
"""
import math

import numpy as np
from mathutils import Matrix, Vector

from artlib import hands, kit, pixelfont
from artlib import materials as M
from artlib.geo import Part
from artlib.kit import R, T
from artlib.model import Model
from artlib.painter import Surface
from models import _upgrade_bits_b as U
from models.vm_fists import FNS as HAND_FNS
from models.vm_pistol import CAM, LOOK, bore

N_BARRELS = 6
RC = 0.032                   # barrel centres from the spin axis
RB = 0.0118                  # barrel radius
MUZZLE_Y = 0.625
CASE_Y0, CASE_Y1, CASE_R = -0.235, -0.02, 0.066
CRANK_C = Vector((0.1, -0.13, 0.0))
CRANK_ARM = 0.095
KNOB_C = Vector((0.145, -0.13, -CRANK_ARM))
GRIP_C = Vector((0.0, 0.355, -0.14))
HOPPER_MOUTH = Vector((-0.035, -0.11, 0.089))
VM_SHIFT = Vector((0.0, 0.16, -0.06))         # gun space -> viewmodel space (carried low, at the hip)
DATE = pixelfont.trim(pixelfont.render("1871"))
# upgrades (gun space)
DRUM_C = Vector((-0.072, 0.0, 0.066))         # drum axis (x, z); it runs along Y
DRUM_Y0, DRUM_Y1, DRUM_R = -0.158, -0.054, 0.046
COIL_R0, COIL_PITCH, COIL_STEP, COIL_RMAX = 0.0105, 0.0155, 0.017, 0.032


def casing_brass(ctx):
    """Polished museum brass; "1871" engraved into the cascabel plate."""
    s = M.brass(ctx, seed=601, tarnish_amount=1.6)
    back = ctx.n[:, 1] < -0.8
    txt = back & pixelfont.stamp(ctx, DATE, 0.0, 0.034)
    s.use_ramp(M.P["brass_tarnish"], mask=txt, shade=np.full(ctx.N, 0.6))
    s.height = s.height - txt * 0.0004
    s.rough = np.where(txt, 0.7, s.rough)
    ring = back & (np.abs(np.hypot(ctx.p[:, 0], ctx.p[:, 2]) - 0.062) < ctx.texel * 0.8)
    s.shade[ring] -= 3.0
    return s


def blued(ctx):
    return M.gun_steel(ctx, seed=603, center=5.6, wear=1.2)


def frame_steel(ctx):
    return M.gun_steel(ctx, seed=605, ramp="steel", center=3.6, wear=0.8)


def walnut(ctx):
    return M.checkering(ctx, M.walnut_stock(ctx, seed=607), period=0.0045)


def webbing(ctx):
    return M.cloth(ctx, "webbing", 4.0, seed=609, weave=0.45, rough=0.92)


def _coil_frame():
    """Cartridge-head centres of the coiled belt seen on the drum's rear
    face, (x, z) in viewmodel space, along an Archimedean spiral."""
    b = COIL_PITCH / (2 * math.pi)
    phimax = (COIL_RMAX - COIL_R0) / b
    out = []
    s = 0.0
    while True:
        phi = (-COIL_R0 + math.sqrt(COIL_R0 ** 2 + 2 * b * s)) / b
        if phi > phimax:
            break
        r = COIL_R0 + b * phi
        out.append((DRUM_C.x + VM_SHIFT.x + r * math.cos(phi), DRUM_C.z + VM_SHIFT.z + r * math.sin(phi)))
        s += COIL_STEP
    return np.array(out), b, phimax


COIL_HEADS, COIL_B, COIL_PHIMAX = _coil_frame()
GUN_FNS = {"brass": casing_brass, "blued": blued, "frame": frame_steel, "wood": walnut, "bore": bore,
           "webbing": webbing, "cart": lambda c: M.brass(c, seed=611, tarnish_amount=1.0),
           "copper": lambda c: M.brass(c, seed=613, ramp="copper", tarnish_amount=1.2)}
FNS = dict(HAND_FNS, **GUN_FNS)


# --- upgrade materials --------------------------------------------------------

def sleeve(ctx):
    """Polished, greased steel: bright and calm, oil darkening the joints."""
    s = U.polished_steel(ctx, seed=651, center=8.2, polish=0.16)
    s.shade = s.shade - ctx.cavity(2.0) * 1.5
    return s


def knob_brass(ctx, polished=False):
    """Turned brass: two cut rings round the knob shell."""
    s = U.master_brass(ctx, seed=653) if polished else M.brass(ctx, seed=653, tarnish_amount=0.5)
    turned = (np.abs(ctx.n[:, 0]) < 0.6) & U.rings_at(ctx, ctx.p[:, 0], (0.137, 0.162))
    s.shade = np.where(turned, s.shade - 2.6, s.shade)
    s.height = s.height - turned * 0.0002
    return s


def _drum_rivets(ctx):
    """Rivet heads: a ring on both end rims and a row along the wall's lap
    seam on top. Returns (head, shadow) masks."""
    c = DRUM_C + VM_SHIFT
    dx, dz = ctx.p[:, 0] - c.x, ctx.p[:, 2] - c.z
    r = np.hypot(dx, dz)
    a = np.arctan2(dz, dx)
    ends = np.abs(ctx.n[:, 1]) > 0.8
    k = np.round(a / (math.pi / 8)) * (math.pi / 8)
    rc = DRUM_R - 0.0012
    d_end = np.hypot(dx - rc * np.cos(k), dz - rc * np.sin(k))
    wall = (np.abs(ctx.n[:, 1]) < 0.4) & (r > DRUM_R - 0.001)
    yy = ctx.p[:, 1] - VM_SHIFT.y
    ky = np.clip(np.round((yy - DRUM_Y0) / 0.013), 1, 7) * 0.013 + DRUM_Y0
    seam_a = math.radians(100.0)
    d_wall = np.hypot((a - seam_a) * DRUM_R, yy - ky)
    head = (ends & (d_end < 0.0017)) | (wall & (d_wall < 0.0017))
    seam = wall & (np.abs(a - seam_a) * DRUM_R < 0.5 * ctx.texel) & ~head
    return head, seam


def drum(ctx, polished=False):
    """Brass belt drum: rolled sheet with a riveted lap seam, riveted rims."""
    if polished:
        c = DRUM_C + VM_SHIFT
        wall = np.abs(ctx.n[:, 1]) < 0.4
        s = U.master_brass(ctx, seed=655, engrave_mask=wall & (np.abs(ctx.p[:, 1] - (c.y + (DRUM_Y0 + DRUM_Y1) / 2))
                                                                  < 0.038))
    else:
        s = M.brass(ctx, seed=655, tarnish_amount=1.3)
    head, seam = _drum_rivets(ctx)
    s.shade = np.where(head, s.shade + 1.6, s.shade)
    s.shade = np.where(seam, s.shade - 2.4, s.shade)
    s.height = s.height + head * 0.0005 - seam * 0.0002
    return s


def coil(ctx, polished=False):
    """The coiled belt seen end-on through the drum's rear face: a spiral
    of cartridge heads (brass, rim line, primer) threaded on the khaki
    webbing, dark gaps between the turns."""
    s = Surface(ctx.N)
    c = DRUM_C + VM_SHIFT
    dx, dz = ctx.p[:, 0] - c.x, ctx.p[:, 2] - c.z
    r = np.hypot(dx, dz)
    a = np.mod(np.arctan2(dz, dx), 2 * math.pi)
    k = np.round(((r - COIL_R0) / COIL_B - a) / (2 * math.pi))
    phi = a + 2 * math.pi * k
    on_belt = (phi > -0.3) & (phi < COIL_PHIMAX + 0.3) & (np.abs(r - (COIL_R0 + COIL_B * phi)) < 0.0072)
    # nearest cartridge head
    hx, hz = COIL_HEADS[:, 0], COIL_HEADS[:, 1]
    d2 = (ctx.p[:, 0:1] - hx[None]) ** 2 + (ctx.p[:, 2:3] - hz[None]) ** 2
    near = np.argmin(d2, axis=1)
    d = np.sqrt(d2[np.arange(ctx.N), near])
    ox, oz = (ctx.p[:, 0] - hx[near]) / 0.0072, (ctx.p[:, 2] - hz[near]) / 0.0072
    headm = d < 0.0072
    s.use_ramp(P_DARK, shade=np.full(ctx.N, 1.0) + M._dither(ctx, 0.6, 661) - (1.0 - ctx.ao) * 2.0)
    web = on_belt & ~headm
    s.use_ramp(M.P["webbing"], mask=web, shade=np.full(ctx.N, 3.2) + M._dither(ctx, 0.8, 662) - (1.0 - ctx.ao) * 3.0)
    lit = (-ox + oz) * 0.9                       # light from the upper left
    shade = (6.6 if polished else 5.8) + lit + M._dither(ctx, 0.5, 663) - (1.0 - ctx.ao) * 3.0
    rim = headm & (d > 0.0072 - 1.1 * ctx.texel)
    primer = headm & (d < 0.0024)
    shade = np.where(rim, shade - 2.0, shade)
    s.use_ramp(M.P["brass"], mask=headm, shade=shade)
    s.use_ramp(M.P["copper"], mask=primer, shade=np.full(ctx.N, 5.0) + lit * 0.5)
    s.metal = np.where(headm, 1.0, 0.0)
    s.rough = np.where(headm, 0.2 if polished else 0.32, 0.85)
    s.height = np.where(headm, 0.0006 - rim * 0.0003, np.where(web, 0.0, -0.001))
    return s


P_DARK = M.hexramp("#060606", "#0c0b09", "#14120e", "#1d1a14")
UPG_FNS = {"crank_sleeve": sleeve, "knob_brass": knob_brass, "drum": drum, "coil": coil, "drum_key": frame_steel}


# --- mastery finish (vm_gatling_master) ---------------------------------------

def _master_casing(ctx):
    """Polished brass engraved with scrollwork; the date stays on the plate."""
    y = ctx.p[:, 1] - VM_SHIFT.y
    body = (np.abs(ctx.n[:, 1]) < 0.5) & (y > CASE_Y0 + 0.03) & (y < CASE_Y1 - 0.03)
    s = U.master_brass(ctx, seed=671, center=7.2, engrave_mask=body)
    back = ctx.n[:, 1] < -0.8
    txt = back & pixelfont.stamp(ctx, DATE, 0.0, 0.034)
    s.use_ramp(M.P["brass_tarnish"], mask=txt, shade=np.full(ctx.N, 0.6))
    s.height = s.height - txt * 0.0004
    s.rough = np.where(txt, 0.7, s.rough)
    ring = back & (np.abs(np.hypot(ctx.p[:, 0], ctx.p[:, 2]) - 0.062) < ctx.texel * 0.8)
    s.shade[ring] -= 3.0
    return s


def _master_barrels(ctx):
    y = ctx.p[:, 1]
    lathe = np.abs(ctx.n[:, 1]) < 0.5
    gold = lathe & U.rings_at(ctx, y, (VM_SHIFT.y + 0.03, VM_SHIFT.y + 0.034, VM_SHIFT.y + MUZZLE_Y - 0.07))
    return U.master_blued(ctx, seed=673, center=5.2, gold_mask=gold)


def _master_frame(ctx):
    return U.master_blued(ctx, seed=675, center=5.6, engrave_mask=ctx.convex > 4.5 * ctx.texel)


def _master_wood(ctx):
    z = ctx.p[:, 2]
    grip = (z < -0.165) & (z > -0.245)
    return U.figured_walnut(ctx, seed=677, checker=grip, period=0.0038)


MASTER_FNS = dict(HAND_FNS, brass=_master_casing, blued=_master_barrels, frame=_master_frame, wood=_master_wood,
                  bore=bore, webbing=webbing, cart=lambda c: U.master_brass(c, seed=679),
                  copper=lambda c: U.master_brass(c, seed=681, ramp="copper", center=6.4),
                  crank_sleeve=lambda c: U.master_silver(c, seed=683),
                  knob_brass=lambda c: knob_brass(c, polished=True),
                  drum=lambda c: drum(c, polished=True), coil=lambda c: coil(c, polished=True),
                  drum_key=lambda c: U.master_blued(c, seed=685, center=5.6, border_gold=False))


# --------------------------------------------------------------------------
# the gun, in gun space (origin on the spin axis at the casing front)
# --------------------------------------------------------------------------

def _y(p, y0, y1, radii, mat, segments=12, caps=True, x=0.0, z=0.0, phase=0.0):
    return kit.seg(p, (x, y0, z), (x, y1, z), radii, mat, segments=segments, caps=caps, phase=phase)


def barrels(p):
    for k in range(N_BARRELS):
        a = math.tau * k / N_BARRELS + math.pi / 2          # barrel 0 at the top (firing position)
        x, z = RC * math.cos(a), RC * math.sin(a)
        _y(p, 0.0, MUZZLE_Y, [(RB * 1.1, 0.0), (RB * 1.05, 0.08), (RB, 0.2), (RB * 0.94, 0.96), (RB * 1.02, 1.0)],
           "blued", segments=8, x=x, z=z)
        _y(p, MUZZLE_Y, MUZZLE_Y + 0.0006, [(RB * 0.62, 0.0), (RB * 0.62, 1.0)], "bore", segments=7, x=x, z=z)
    _y(p, -0.005, MUZZLE_Y - 0.01, [(0.012, 0.0), (0.012, 1.0)], "frame", segments=8)        # centre shaft
    # bands: rear breech plate, middle band, muzzle band (steel discs the barrels pass through)
    for y, t, r in ((0.012, 0.022, 0.052), (0.3, 0.018, 0.049), (MUZZLE_Y - 0.045, 0.02, 0.049)):
        _y(p, y - t / 2, y + t / 2, [(r, 0.0), (r * 1.03, 0.25), (r * 1.03, 0.75), (r, 1.0)], "frame",
           segments=18, phase=math.pi / 18)
    _y(p, MUZZLE_Y - 0.008, MUZZLE_Y - 0.004, [(0.018, 0.0), (0.018, 1.0)], "brass", segments=10)   # shaft nut


def body(p):
    # breech casing: rear flange, body, front flange; cascabel plate and knob
    _y(p, CASE_Y0, CASE_Y1, [(CASE_R * 1.07, 0.0), (CASE_R * 1.07, 0.06), (CASE_R, 0.1), (CASE_R * 0.98, 0.5),
                              (CASE_R, 0.88), (CASE_R * 1.07, 0.92), (CASE_R * 1.07, 1.0)], "brass", segments=20,
       phase=math.pi / 20)
    _y(p, CASE_Y0 - 0.014, CASE_Y0, [(CASE_R * 0.98, 0.0), (CASE_R * 1.06, 1.0)], "brass", segments=20,
       phase=math.pi / 20)
    _y(p, CASE_Y0 - 0.05, CASE_Y0 - 0.014, [(0.012, 0.0), (0.011, 0.4), (0.022, 0.62), (0.024, 0.8), (0.016, 0.95),
                                            (0.008, 1.0)], "brass", segments=10)           # cascabel knob
    # screw heads round the rear plate
    for k in range(8):
        a = math.tau * (k + 0.5) / 8
        _y(p, CASE_Y0 - 0.017, CASE_Y0 - 0.013, [(0.0045, 0), (0.0045, 1)], "frame", segments=6,
           x=0.066 * math.cos(a), z=0.066 * math.sin(a))
    # feed hopper on top, its mouth open to the left for the belt
    p.box((0.0, -0.11, 0.078), (0.056, 0.08, 0.04), "brass", bevel=0.004)
    p.box((0.0, -0.11, 0.1), (0.064, 0.088, 0.008), "brass", bevel=0.003)
    p.box((-0.03, -0.11, 0.086), (0.006, 0.058, 0.02), "bore")                           # mouth
    # gear housing on the right for the crank shaft
    kit.seg(p, (CASE_R * 0.9, CRANK_C.y, 0.0), (CRANK_C.x - 0.004, CRANK_C.y, 0.0),
            [(0.034, 0.0), (0.036, 0.3), (0.03, 1.0)], "brass", segments=14)
    # frame rail under the barrels to the front bearing ring, foregrip under it
    p.box((0.0, 0.19, -0.069), (0.03, 0.44, 0.016), "frame", bevel=0.003)
    p.box((0.0, 0.0, -0.06), (0.05, 0.05, 0.03), "frame", bevel=0.004)                  # rail foot on the casing
    # (a closed profile: the lathe keeps the whole torus facing out)
    ring = p.lathe([(0.055, -0.012), (0.066, -0.01), (0.068, 0.0), (0.066, 0.01), (0.055, 0.012), (0.054, 0.0),
                    (0.055, -0.012)], "frame", segments=18, cap_bottom=False, cap_top=False, smooth=True,
                   phase=math.pi / 18)
    p.move(ring, T(0, 0.405, 0) @ R('X', -90))
    p.box((0.0, 0.405, -0.064), (0.024, 0.024, 0.02), "frame", bevel=0.003)              # ring to rail web
    p.box((0.0, GRIP_C.y, -0.083), (0.036, 0.05, 0.016), "frame", bevel=0.003)          # grip bracket
    kit.seg(p, (0, GRIP_C.y + 0.004, -0.088), (0, GRIP_C.y - 0.01, -0.205),
            [(0.017, 0.0), (0.019, 0.25), (0.018, 0.7), (0.02, 0.92), (0.014, 1.0)], "wood", segments=10)
    # sights: blade on the bearing ring, notch on the hopper
    p.box((0.0, 0.405, 0.074), (0.004, 0.012, 0.014), "frame", bevel=0.001)
    for sx in (-1, 1):
        p.box((sx * 0.006, -0.064, 0.112), (0.005, 0.008, 0.012), "frame", bevel=0.001)


def crank(p):
    c = CRANK_C
    kit.seg(p, (c.x - 0.006, c.y, c.z), (c.x + 0.014, c.y, c.z), [(0.01, 0), (0.01, 1)], "frame", segments=10)
    arm = p.box((0, 0, 0), (0.012, 0.024, CRANK_ARM + 0.03), "frame", bevel=0.004)
    p.move(arm, T(c.x + 0.012, c.y, c.z - CRANK_ARM / 2))
    kit.seg(p, (c.x + 0.012, c.y, c.z), (c.x + 0.022, c.y, c.z), [(0.016, 0), (0.014, 1)], "brass", segments=10)
    kit.seg(p, (c.x + 0.016, KNOB_C.y, KNOB_C.z), (KNOB_C.x + 0.036, KNOB_C.y, KNOB_C.z),
            [(0.0065, 0.0), (0.0065, 0.14), (0.013, 0.2), (0.0155, 0.45), (0.0145, 0.85), (0.009, 1.0)], "wood",
            segments=10)


def cartridge(p, base, d, segments=6):
    """Brass rifle cartridge lying in the belt: base -> bullet along ``d``."""
    d = Vector(d).normalized()
    b = Vector(base)
    L, r = 0.05, 0.0068
    kit.seg(p, b, b + d * L, [(r * 1.12, 0.0), (r * 1.12, 0.05), (r, 0.08), (r * 0.94, 0.7), (r * 0.62, 0.82),
                              (r * 0.6, 1.0)], "cart", segments=segments)
    kit.seg(p, b + d * L, b + d * (L + 0.022), [(r * 0.6, 0.0), (r * 0.58, 0.5), (r * 0.3, 1.0)], "copper",
            segments=segments)


BELT_PATH = [(-0.035, 0.089), (-0.058, 0.092), (-0.082, 0.072), (-0.096, 0.036), (-0.1, -0.005), (-0.096, -0.05),
             (-0.086, -0.095), (-0.074, -0.14), (-0.064, -0.19), (-0.06, -0.235)]   # (x, z) at y = -0.11


def belt(p):
    """Canvas belt with cartridges across it, bullets forward (+Y)."""
    y = HOPPER_MOUTH.y
    pts = [Vector((x, y, z)) for x, z in BELT_PATH]
    for a, b in zip(pts[:-1], pts[1:]):
        d = b - a
        mid = (a + b) * 0.5
        strip = p.box((0, 0, 0), (d.length + 0.003, 0.054, 0.004), "webbing", bevel=0.0008)
        p.move(strip, T(*mid) @ R('Y', -math.degrees(math.atan2(d.z, d.x))))
    # cartridges every 17 mm along the path, lying on the outside of the belt
    acc = [0.0]
    for a, b in zip(pts[:-1], pts[1:]):
        acc.append(acc[-1] + (b - a).length)
    s = 0.012
    k = 0
    while s < acc[-1] - 0.006:
        i = int(np.searchsorted(acc, s) - 1)
        t = (s - acc[i]) / (acc[i + 1] - acc[i])
        c = pts[i].lerp(pts[i + 1], t)
        d = (pts[i + 1] - pts[i]).normalized()
        cartridge(p, c + Vector((0, -0.03, 0)), (0, 1, 0))      # the webbing passes through its middle
        s += 0.017
        k += 1


def crank_upgrade(p):
    """Greased crank: a polished steel sleeve with end collars on the arm
    (clear of the hand round the knob), a brass grease cup on it and a
    turned brass shell over the walnut knob, 1 mm proud of it."""
    c = CRANK_C
    x = c.x + 0.012
    p.box((x, c.y, c.z - 0.035), (0.0158, 0.0276, 0.034), "crank_sleeve", bevel=0.0025)
    for z in (c.z - 0.052, c.z - 0.018):
        p.box((x, c.y, z), (0.0174, 0.0292, 0.004), "crank_sleeve", bevel=0.0012)
    kit.seg(p, (x + 0.0077, c.y, c.z - 0.035), (x + 0.0167, c.y, c.z - 0.035),
            [(0.0036, 0.0), (0.0036, 0.45), (0.0047, 0.5), (0.0047, 0.8), (0.003, 1.0)], "knob_brass", segments=8)
    x0, x1 = 0.1268, 0.182
    L = x1 - x0
    kit.seg(p, (x0, KNOB_C.y, KNOB_C.z), (x1, KNOB_C.y, KNOB_C.z),
            [(0.0108, 0.0), (0.0142, (0.129 - x0) / L), (0.0165, (0.14525 - x0) / L), (0.0155, (0.17125 - x0) / L),
             (0.0100, (0.181 - x0) / L), (0.0098, 1.0)], "knob_brass", segments=10)


def belt_drum(p):
    """Brass belt drum round the belt's top turn, against the hopper's left
    side and down onto the casing's shoulder (the wall stops inside the
    casing). The belt leaves through a slot in the lower left of the wall;
    the rear face is open behind a riveted rim and shows the coil."""
    cx, cz, rd = DRUM_C.x, DRUM_C.z, DRUM_R
    y0, y1 = DRUM_Y0, DRUM_Y1
    rad = math.radians
    U.arc_band(p, cx, cz, rd - 0.002, rd, y0, y1, rad(-12.0), rad(210.0), "drum", 20)
    for ya, yb in ((y0, y0 + 0.008), (y1 - 0.008, y1)):                      # over and under the belt slot
        U.arc_band(p, cx, cz, rd - 0.002, rd, ya, yb, rad(210.0), rad(262.0), "drum", 5)
    U.arc_band(p, cx, cz, rd - 0.002, rd, y0, y1, rad(262.0), rad(290.0), "drum", 3)
    U.ring(p, (cx, y0, cz), (0, 1, 0), rd - 0.006, rd + 0.003, -0.002, 0.003, "drum", segments=28)  # rear rim
    kit.seg(p, (cx, y0 + 0.0026, cz), (cx, y0 + 0.002, cz), [(rd - 0.0055, 0.0), (rd - 0.0055, 1.0)], "coil",
            segments=28)                                                                        # the coil, end-on
    kit.seg(p, (cx, y0 + 0.002, cz), (cx, y0 - 0.006, cz), [(0.0085, 0.0), (0.0085, 0.55), (0.0058, 0.62),
                                                            (0.0058, 1.0)], "drum", segments=10)  # winding hub
    p.box((cx, y0 - 0.0052, cz), (0.026, 0.0028, 0.006), "drum_key", bevel=0.0009, rot=R('Y', 32.0))  # wing key
    kit.seg(p, (cx, y1 - 0.002, cz), (cx, y1 + 0.003, cz), [(rd + 0.003, 0.0), (rd + 0.003, 1.0)], "drum",
            segments=28)                                                                        # front plate


def _placed(p, place, fn):
    """Runs builder ``fn`` on part ``p`` and moves only the new faces by ``place``."""
    before = set(p.bm.faces)
    fn(p)
    new = [f for f in p.bm.faces if f not in before]
    if place is not None:
        p.move(new, place)
    return new


def build_gun(parts, place=None):
    """Adds the gun to parts {"body", "barrels", "crank", "belt"} (the same
    Part may be given for several), moved by the matrix ``place``."""
    _placed(parts["body"], place, body)
    _placed(parts["barrels"], place, barrels)
    _placed(parts["crank"], place, crank)
    _placed(parts["belt"], place, belt)


def build():
    s = VM_SHIFT
    gun = Part("gatling")
    bar = Part("barrels", origin=tuple(s))
    crk = Part("crank", origin=tuple(CRANK_C + s))
    blt = Part("belt", origin=tuple(HOPPER_MOUTH + s))
    build_gun({"body": gun, "barrels": bar, "crank": crk, "belt": blt}, place=T(*s))
    knob = KNOB_C + s
    # right hand over the crank knob (cant 35), the sleeve back, right and
    # down; it rides the knob, so the game keeps its sleeve on the elbow
    right = Part("hand_r", origin=tuple(knob))
    m = hands.hand_matrix(knob + Vector((0.012, 0, 0)), (-1, 0, 0), (0.0, -0.3, 1.0), sx=1)
    sleeve_r, markers_r = hands.arm("r", right, m, 1, math.radians(35.0), (0.45, -0.75, -0.45), 0.3)
    grip = GRIP_C + s
    # left hand on the foregrip (cant 35), the forearm back toward the eye and down
    left = Part("hand_l", origin=tuple(grip))
    m = hands.hand_matrix(grip, (0, 0.12, 1.0), (-1.0, -0.2, 0.0), sx=-1)
    sleeve_l, markers_l = hands.arm("l", left, m, -1, math.radians(35.0), (-0.2, -0.85, -0.5), 0.36, watch=True)
    top = (0.0, MUZZLE_Y + 0.003 + s.y, RC + s.z)
    KNOB = tuple(knob)
    # upgrades: viewmodel only (build_gun, shared with gatling_display, stays untouched)
    ucr = Part("upg_crank", origin=tuple(CRANK_C + s), parent="crank")
    _placed(ucr, T(*s), crank_upgrade)
    udr = Part("upg_drum", origin=tuple(Vector((DRUM_C.x, DRUM_Y0, DRUM_C.z)) + s), parent="gatling")
    _placed(udr, T(*s), belt_drum)
    # the base set ignores the upgrade parts in its AO (the walnut knob under
    # the brass shell, the casing under the drum); at mastery all are on
    from models import _upgrade_bits_a as hb
    base = {k: hb.ao_without(f, ("upg_",), rays=12, dist=0.04) for k, f in FNS.items()}
    fns = dict(base, **UPG_FNS)
    return Model("vm_gatling", [gun, bar, crk, blt, right, left, sleeve_r, sleeve_l, ucr, udr], fns, ppm=384,
                 organic=("hand_r", "hand_l", "sleeve_r", "sleeve_l"), ao_dist=0.04, ao_rays=12, ao_stride=1, front=1,
                 markers=[("Muzzle", top, None), ("CrankKnob", KNOB, "crank")] + markers_r + markers_l,
                 variants={"vm_gatling_master": MASTER_FNS},
                 preview_yaws=(-60.0, 40.0, 110.0, 250.0), preview_elevation=16.0,
                 preview_fp=(CAM, LOOK),
                 preview_extra=[("upg_drum", tuple(DRUM_C + s + Vector((0.0, -0.1, 0.0))), 0.09, -40.0, 28.0),
                                ("upg_crank", tuple(CRANK_C + s + Vector((0.03, 0.0, -0.05))), 0.085, 100.0, 15.0)])
