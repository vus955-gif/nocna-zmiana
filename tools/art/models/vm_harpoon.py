"""First-person whaling harpoon gun (harpunnik, weapon id harpoon): a
19th-century shoulder gun in the Greener manner. A short, thick-walled
ship's-iron barrel (38 mm bore, octagonal breech, turned ring, muzzle
swell) bedded in a stout salt-weathered oak stock held by forged iron
bands; a percussion side lock on the right (hammer resting on a copper
cap), brass trigger guard and side plate, a whale-ivory inlay on the left
of the butt. A forged two-flued harpoon stands ~29 cm out of the muzzle,
rammed home on tarred oakum; its sliding line ring sits just ahead of the
muzzle. The tarred hemp line runs back along the left of the barrel
through a brass fairlead on the rear band and drops to a loose coil hung
on an iron hook on the left of the stock. Right hand on the stock wrist,
left hand under the fore-stock between the bands.

Viewmodel conventions as in vm_fists.py (faces +Y in Blender = -Z in
Godot, real scale, origin near the lock like vm_shotgun, so the gun drops
into WeaponHolder.REST without an offset). Godot = (x, z, -y) of Blender.

Part / marker   Blender pivot (x, y, z)    Godot pivot (x, y, z)     parent      use
harpoon         (0, 0, 0)                  (0, 0, 0)                 -           stock, barrel, lock, hammer,
                                                                                 trigger, guard, bands, fairlead
head            (0, 0.43, 0)               (0, 0, -0.43)             harpoon     loaded harpoon (shank, head,
                                                                                 line ring, oakum wad); hide after
                                                                                 the shot, slide in along local Y
                                                                                 (Godot -Z) to reload
upg_barbs       (0, 0.63, 0)               (0, 0, -0.63)             head        upgrade "Zadziory": second pair of
                                                                                 flues at right angles + shank spurs
rope            (-0.055, 0.134, 0)         (-0.055, 0, -0.134)       harpoon     line: ring -> fairlead -> coil (static)
upg_reel        (0.083, 0.0, -0.024)       (0.083, -0.024, 0)        harpoon     upgrade "Kołowrotek": brass-and-iron
                                                                                 reel with line, right side of stock
reel_crank      (0.1195, 0.0, -0.024)      (0.1195, -0.024, 0)       upg_reel    crank arm + knob; pivot on the reel
                                                                                 axle; axle axis = Blender X = Godot X
                                                                                 (spin: rotate about local X)
hand_r          (0, -0.262, -0.046)        (0, -0.046, 0.262)        harpoon     right hand on the stock wrist
hand_l          (0, 0.19, -0.04)           (0, -0.04, -0.19)         harpoon     left hand under the fore-stock
sleeve_r/_l     the wrist of its hand                                harpoon     the sleeves (the game turns them toward
                                                                                 the elbows; markers Wrist_*, Grip_*,
                                                                                 Elbow_*: artlib/hands.py arm())
Muzzle          (0, 0.432, 0)              (0, 0, -0.432)            root        barrel mouth on the bore axis
LineAnchor      (-0.0144, 0.4654, 0)       (-0.0144, 0, -0.4654)     root        where the flying line leaves the gun
                                                                                 (the loaded line ring)

Mastery finish: texture set vm_harpoon_master (same mesh and UVs):
polished steel with gold inlay lines and engraved scrollwork, bright
brass, warm high-gloss oak, and a scrimshaw sperm whale on the ivory inlay.
"""
import math

import numpy as np
from mathutils import Vector

from artlib import hands, kit, pixelfont
from artlib import materials as M
from artlib.geo import Part
from artlib.kit import R, T
from artlib.model import Model
from models import _harpoon_parts as H
from models.vm_fists import FNS as HAND_FNS
from models.vm_pistol import CAM, LOOK, bore

BREECH_Y = -0.085
OCT_APO = 0.040
OCT_R = OCT_APO / math.cos(math.pi / 8)
OCT_Y1 = 0.090
RING_Y1 = 0.106
MUZZLE_Y = 0.43
R_BORE = 0.019
HEAD_LEN = 0.29                     # harpoon tip ahead of the muzzle
HEAD_ROLL = -40.0                   # flues rolled toward the player's eye (up-left)
HEAD_S = 1.3                        # head scale (flues 9 cm across)
RING_C = Vector((0.0, MUZZLE_Y + 0.042, 0.0))
RING_N = Vector((-0.45, 0.89, 0.0)).normalized()
RING_R = 0.016
GUIDE_C = Vector((-0.055, 0.134, 0.0))
HOOK = Vector((-0.054, -0.125, -0.046))
COIL_X = -0.052
REEL_C = Vector((0.083, 0.0, -0.024))
CRANK_X = 0.1195
STAMP = pixelfont.trim(pixelfont.render("NEW BEDFORD"))

# stock cross-sections (y, zc, half width, half height, corner radius), muzzle -> butt
STOCK = [
    (0.316, -0.024, 0.0332, 0.024, 0.012),
    (0.300, -0.0265, 0.0347, 0.0265, 0.013),
    (0.268, -0.028, 0.0356, 0.028, 0.014),
    (0.200, -0.0295, 0.0372, 0.0295, 0.015),
    (0.134, -0.031, 0.0386, 0.031, 0.015),
    (0.106, -0.032, 0.0400, 0.032, 0.015),
    (0.085, -0.033, 0.0420, 0.033, 0.015),
    (-0.083, -0.035, 0.0420, 0.035, 0.015),
    (-0.087, -0.029, 0.0420, 0.041, 0.015),
    (-0.170, -0.030, 0.0390, 0.039, 0.015),
    (-0.205, -0.036, 0.0230, 0.029, 0.017),
    (-0.240, -0.042, 0.0200, 0.026, 0.016),
    (-0.290, -0.052, 0.0210, 0.027, 0.016),
    (-0.330, -0.066, 0.0250, 0.043, 0.017),
    (-0.400, -0.083, 0.0280, 0.058, 0.018),
    (-0.500, -0.098, 0.0300, 0.068, 0.018),
]


def barrel_r(y):
    return float(np.interp(y, [0.104, 0.385, 0.392, 0.405, 0.424, 0.43],
                           [0.0368, 0.0312, 0.0312, 0.0355, 0.0368, 0.0368]))


# --------------------------------------------------------------------------
# materials
# --------------------------------------------------------------------------

def barrel_iron(ctx):
    """Ship's iron with "NEW BEDFORD" struck into the upper-left breech flat."""
    s = H.sea_iron(ctx, seed=701, center=5.0)
    flat = (ctx.n[:, 0] < -0.55) & (ctx.n[:, 2] > 0.55) & (ctx.p[:, 1] < OCT_Y1 - 0.004)         & (ctx.p[:, 1] > BREECH_Y + 0.006)
    if flat.sum() > 50:
        # the flat's UVs: v runs along the barrel (+y), u around it; read the
        # text from the left (muzzle on the left): u_text = -v, v_text = up the flat
        across = (ctx.p[:, 0] + ctx.p[:, 2]) / math.sqrt(2.0)
        uu, vv = ctx.uvm[:, 0], ctx.uvm[:, 1]
        sign = 1.0 if np.cov(uu[flat], across[flat])[0, 1] > 0 else -1.0
        ut, vt = -vv, sign * uu
        mid = flat & (np.abs(ctx.p[:, 1] - 0.012) < 0.004)
        cu = float(np.median(ut[mid])) if mid.any() else float(np.median(ut[flat]))
        cv = float(np.median(vt[flat]))
        txt = flat & pixelfont.stamp(ctx, STAMP, cu, cv, u=ut, v=vt)
        s.use_ramp(M.P["steel"], mask=txt, shade=np.full(ctx.N, 1.6) + M._dither(ctx, 0.6, 709))
        s.height = s.height - txt * 0.0003
        s.rough = np.where(txt, 0.75, s.rough)
    return s


def reel_flange(ctx, s):
    """Paints the reel's flange faces: five lightening holes, an engraved
    ring and rivets round the hub."""
    d = ctx.p - np.array(REEL_C)
    r = np.hypot(d[:, 1], d[:, 2])
    fl = (np.abs(ctx.n[:, 0]) > 0.8) & (ctx.p[:, 0] > 0.055) & (r < 0.05) & (np.abs(d[:, 1]) < 0.05)
    if not fl.any():
        return s
    a = np.arctan2(d[:, 2], d[:, 1])
    step = math.tau / 5
    ak = np.round((a - step / 2) / step) * step + step / 2
    dist = np.hypot(d[:, 1] - 0.026 * np.cos(ak), d[:, 2] - 0.026 * np.sin(ak))
    hole = fl & (dist < 0.0068)
    rim = fl & (dist >= 0.0068) & (dist < 0.0068 + ctx.texel * 1.2)
    s.use_ramp(H.VERDIGRIS, mask=hole, shade=np.full(ctx.N, 0.6) + M._dither(ctx, 0.8, 761) + (dist / 0.0068) * 1.2)
    s.shade[rim] += 2.0
    ring = fl & ((np.abs(r - 0.0405) < ctx.texel * 0.6) | (np.abs(r - 0.0148) < ctx.texel * 0.6))
    s.shade[ring] -= 2.5
    riv_a = np.round(a / step) * step
    riv = fl & (np.hypot(d[:, 1] - 0.0115 * np.cos(riv_a), d[:, 2] - 0.0115 * np.sin(riv_a)) < 0.0022)
    s.shade[riv] += 1.6
    s.height = s.height - hole * 0.0012 + riv * 0.0004 - ring * 0.0002
    s.metal = np.where(hole, 0.0, s.metal)
    s.rough = np.where(hole, 0.9, s.rough)
    return s


def brass(ctx):
    return reel_flange(ctx, H.sea_brass(ctx, seed=755))


def strap_iron(ctx):
    return H.forged(ctx, seed=711, center=4.2, rust=1.3)


def harpoon_iron(ctx):
    return H.forged(ctx, seed=721, center=4.6, rust=0.8)


def copper(ctx):
    return M.brass(ctx, seed=731, ramp="copper", tarnish_amount=1.6)


def reel_line(ctx):
    """Line wound on the reel drum: turns across the drum, strands hatched."""
    s = H.twine(ctx, seed=741, pitch=0.009)
    hatch = np.mod(ctx.uvm[:, 0] / 0.006 + ctx.uvm[:, 1] / 0.006, 1.0) < 0.22
    s.shade[hatch] -= 0.8
    return s


def rope(ctx):
    return H.tar_rope(ctx, seed=751, radius=0.0045)


FNS = dict(HAND_FNS, barrel=barrel_iron, iron=strap_iron, brass=brass, wood=lambda c: H.sea_oak(c, center=4.7),
           bore=bore,
           harpoon=harpoon_iron, wad=H.wad, rope=rope, twine=H.twine, reel_line=reel_line,
           plaque=H.ivory_plaque, copper=copper)


def master_barrel(ctx):
    s = H.polished_steel(ctx, seed=801, center=7.4)
    ring = np.zeros(ctx.N, dtype=bool)
    for y in (BREECH_Y + 0.006, OCT_Y1 - 0.006, 0.12, 0.25, 0.375, 0.412):
        ring |= np.abs(ctx.p[:, 1] - y) < ctx.texel * 0.55
    ring &= ctx.convex > ctx.texel * 1.5
    s.use_ramp(H.GOLD_INLAY, mask=ring, shade=np.full(ctx.N, 7.0) + M._dither(ctx, 0.6, 803))
    s.metal = np.where(ring, 1.0, s.metal)
    s.rough = np.where(ring, 0.12, s.rough)
    return s


def master_wood(ctx):
    s = H.polished_wood(ctx, seed=811)
    wrist = (ctx.p[:, 1] < -0.215) & (ctx.p[:, 1] > -0.305) & (ctx.p[:, 2] < 0.0)
    sub = M.checkering(ctx, H.polished_wood(ctx, seed=811), period=0.0045)
    s.merge(M._select(sub, wrist), wrist)
    return s


MASTER = dict(FNS, barrel=master_barrel, iron=lambda c: H.polished_steel(c, seed=821, center=7.0),
              harpoon=lambda c: H.polished_steel(c, seed=831, center=7.8, engrave=False),
              brass=lambda c: reel_flange(c, H.polished_brass(c)), wood=master_wood, plaque=H.scrimshaw,
              copper=lambda c: M.brass(c, seed=841, ramp="copper", tarnish_amount=0.2))


# --------------------------------------------------------------------------
# geometry
# --------------------------------------------------------------------------

def _barrel(p):
    kit.seg(p, (0, BREECH_Y, 0), (0, OCT_Y1, 0), [(OCT_R * 0.94, 0.0), (OCT_R, 0.025), (OCT_R, 1.0)], "barrel",
            segments=8, smooth=False, phase=math.pi / 8)
    kit.seg(p, (0, OCT_Y1 - 0.002, 0), (0, RING_Y1, 0),
            [(0.0400, 0.0), (0.0436, 0.18), (0.0436, 0.45), (0.0398, 0.62), (0.0392, 0.8), (0.0372, 1.0)],
            "barrel", segments=16, smooth=True, phase=math.pi / 16)
    y0, y1 = RING_Y1 - 0.004, MUZZLE_Y
    ys = [y0, 0.104, 0.2, 0.3, 0.385, 0.392, 0.405, 0.424]
    prof = [(barrel_r(y), y) for y in ys] + [(0.0352, MUZZLE_Y), (0.0214, MUZZLE_Y), (R_BORE, MUZZLE_Y - 0.0035),
                                               (R_BORE, MUZZLE_Y - 0.06)]
    L = y1 - y0
    faces = kit.seg(p, (0, y0, 0), (0, y1, 0), [(r, (y - y0) / L) for r, y in prof], "barrel", segments=18,
                    caps=True, phase=math.pi / 18)
    bore_i = p.slot("bore")
    for f in faces:
        c = f.calc_center_median()
        if math.hypot(c.x, c.z) < R_BORE + 0.0008 and c.y < MUZZLE_Y - 0.003:
            f.material_index = bore_i
    # sights: blade on the muzzle swell, block on the breech flat
    p.box((0, MUZZLE_Y - 0.013, 0.0368 + 0.0032), (0.0032, 0.014, 0.0075), "iron", bevel=0.001)
    for sx in (-1, 1):
        p.box((sx * 0.0045, -0.062, OCT_APO + 0.0035), (0.004, 0.009, 0.008), "iron", bevel=0.001)
    # nipple bolster on the right of the breech, nipple and copper cap
    p.box((0.027, -0.072, 0.026), (0.016, 0.024, 0.017), "iron", bevel=0.003)
    kit.seg(p, (0.030, -0.0715, 0.031), (0.0335, -0.0745, 0.043), [(0.0034, 0.0), (0.0029, 0.6), (0.0022, 1.0)],
            "iron", segments=6)
    kit.seg(p, (0.0328, -0.0738, 0.0405), (0.0348, -0.0758, 0.0478), [(0.0042, 0.0), (0.0042, 0.75),
                                                                     (0.0034, 1.0)], "copper", segments=8)


def _stock(p):
    H.loft(p, H.section_rings(STOCK), "wood")
    # butt plate, wrist and butt bands, tang over the comb
    front = H.interp_section(STOCK, -0.497)
    back = (-0.507,) + H.interp_section(STOCK, -0.5)[1:]
    H.loft(p, H.section_rings([front], 0.0012) + H.section_rings([back], 0.0018), "iron")
    for y0 in (-0.318, -0.447):
        secs = []
        for dy, g in ((0.0, 0.0006), (0.002, 0.0019), (0.010, 0.0019), (0.012, 0.0006)):
            s = H.interp_section(STOCK, y0 - dy)
            secs.append(H.section_rings([s], g)[0])
        H.loft(p, secs, "iron")
    tang = [(-0.080, 0.0135, 0.0085, 0.0026, 0.0018), (-0.170, 0.0103, 0.0075, 0.0026, 0.0018),
            (-0.214, -0.0080, 0.0058, 0.0026, 0.0018)]
    H.loft(p, H.section_rings(tang, n=2), "iron", smooth=False)
    for y, z in ((-0.11, 0.0138), (-0.19, 0.0025)):
        kit.seg(p, (0, y, z - 0.001), (0, y, z + 0.0028), [(0.0035, 0.0), (0.0035, 0.5), (0.0022, 1.0)], "iron",
                segments=6)
    # whale-ivory inlay on the left of the butt (scrimshaw in the master finish)
    hw = H.interp_section(STOCK, -0.41)[2]
    pl = p.box((0, 0, 0), (0.004, 0.1, 0.038), "plaque", bevel=0.0012)
    p.move(pl, T(-hw - 0.0004, -0.41, -0.092) @ R('Z', -1.66))


def _band_ring(y, rad, sec, t, n_arc=9):
    """Iron band round barrel and fore-stock: arc over the barrel, down the
    stock sides, rounded under the stock. First point underneath (UV seam)."""
    _, zc, hw, hh, rc = sec
    zb = zc - hh
    w = hw + t
    pts = [Vector((0.0, y, zb - t))]
    for i in range(4):
        a = math.radians(-90.0 + 30.0 * i)
        pts.append(Vector((hw - rc + (rc + t) * math.cos(a), y, zb + rc + (rc + t) * math.sin(a))))
    pts.append(Vector((w, y, -0.003)))
    for i in range(n_arc):
        a = math.pi * i / (n_arc - 1)
        pts.append(Vector(((rad + t) * math.cos(a), y, (rad + t) * math.sin(a))))
    pts.append(Vector((-w, y, -0.003)))
    for i in range(4):
        a = math.radians(180.0 + 30.0 * i)
        pts.append(Vector((-hw + rc + (rc + t) * math.cos(a), y, zb + rc + (rc + t) * math.sin(a))))
    return pts


def _bands(p):
    for y0, y1 in ((0.125, 0.143), (0.262, 0.278)):
        rings = []
        for y, t in ((y0, 0.0015), (y0 + 0.002, 0.0038), (y1 - 0.002, 0.0038), (y1, 0.0015)):
            rings.append(_band_ring(y, barrel_r(y), H.interp_section(STOCK, y), t))
        H.loft(p, rings, "iron", smooth=True)
        # rivet on each side
        for sx in (-1, 1):
            s = H.interp_section(STOCK, (y0 + y1) / 2)
            x = sx * (s[2] + 0.0038)
            kit.seg(p, (x - sx * 0.001, (y0 + y1) / 2, -0.022), (x + sx * 0.0022, (y0 + y1) / 2, -0.022),
                    [(0.0034, 0.0), (0.0034, 0.4), (0.002, 1.0)], "iron", segments=6)
    # brass fairlead (line guide) on the left of the rear band
    p.box((-0.0445, GUIDE_C.y, 0.0), (0.011, 0.012, 0.008), "brass", bevel=0.0018)
    H.torus(p, GUIDE_C, (0, 1, 0), 0.0074, 0.0023, "brass", segments=12, ring=6)


def _lock(p):
    """Percussion side lock (right), brass side plate (left), guard, trigger."""
    p.box((0.0405, -0.118, -0.025), (0.0045, 0.104, 0.029), "iron", bevel=0.0016)
    for y in (-0.085, -0.155):
        kit.seg(p, (0.042, y, -0.02), (0.0448, y, -0.02), [(0.0032, 0.0), (0.0032, 0.5), (0.002, 1.0)], "iron",
                segments=6)
    kit.seg(p, (0.042, -0.13, -0.024), (0.0475, -0.13, -0.024), [(0.0068, 0.0), (0.0068, 0.6), (0.0055, 1.0)],
            "iron", segments=8)                                                       # tumbler / hammer screw
    # hammer resting on the cap: neck from the tumbler up to the head, spur back
    p.tube([(0.046, -0.13, -0.024), (0.0465, -0.124, -0.004), (0.044, -0.112, 0.021), (0.0395, -0.097, 0.04),
            (0.0365, -0.085, 0.0505)], 0.0045, "iron", sides=4, smooth=False)
    hd = p.box((0, 0, 0), (0.012, 0.017, 0.012), "iron", bevel=0.002)
    p.move(hd, T(0.035, -0.0785, 0.0535) @ R('X', -12))
    p.tube([(0.036, -0.088, 0.055), (0.037, -0.103, 0.064), (0.0375, -0.118, 0.067)], 0.0034, "iron", sides=4,
           smooth=False)
    sp = p.box((0, 0, 0), (0.010, 0.013, 0.0045), "iron", bevel=0.0012)
    p.move(sp, T(0.0378, -0.124, 0.0675) @ R('X', 8))
    # brass side plate (left), two lock bolts
    p.box((-0.0402, -0.12, -0.025), (0.003, 0.088, 0.022), "brass", bevel=0.0012)
    for y in (-0.095, -0.145):
        kit.seg(p, (-0.0412, y, -0.025), (-0.0432, y, -0.025), [(0.0034, 0.0), (0.0034, 0.5), (0.002, 1.0)],
                "brass", segments=6)
    # trigger plate, trigger, brass guard
    p.box((0, -0.14, -0.0703), (0.012, 0.1, 0.004), "iron", bevel=0.0012)
    tr = p.box((0, 0, 0), (0.0055, 0.007, 0.026), "iron", bevel=0.0018)
    p.move(tr, T(0, -0.15, -0.083) @ R('X', 16))
    p.tube([(0, -0.098, -0.07), (0, -0.108, -0.091), (0, -0.13, -0.104), (0, -0.162, -0.104), (0, -0.188, -0.092),
            (0, -0.206, -0.068)], 0.0036, "brass", sides=6, smooth=True)
    p.box((0, -0.099, -0.0705), (0.009, 0.02, 0.0035), "brass", bevel=0.001)
    p.box((0, -0.204, -0.0655), (0.009, 0.022, 0.0035), "brass", bevel=0.001)
    # iron hook for the coil, left of the stock under the side plate
    p.tube([(-0.036, HOOK.y, HOOK.z), (-0.06, HOOK.y, HOOK.z - 0.0015), (-0.078, HOOK.y, HOOK.z + 0.001),
            (-0.083, HOOK.y, HOOK.z + 0.008), (-0.0835, HOOK.y + 0.001, HOOK.z + 0.016)], 0.0026, "iron", sides=5)


def _head(p):
    """The loaded harpoon (part head): shank in the oakum wad, line ring,
    stop collar, two-flued head; built in model space."""
    tip = MUZZLE_Y + HEAD_LEN
    frame = T(0, tip, 0) @ R('Y', HEAD_ROLL)
    H.head(p, frame, s=HEAD_S)
    H.shank(p, frame, -(HEAD_LEN + 0.035), -0.104)
    kit.seg(p, (0, MUZZLE_Y + 0.072, 0), (0, MUZZLE_Y + 0.084, 0),
            [(0.0086, 0.0), (0.0114, 0.3), (0.0114, 0.7), (0.0086, 1.0)], "harpoon", segments=10)  # stop collar
    H.torus(p, RING_C, RING_N, RING_R, 0.0031, "harpoon", segments=14, ring=6)
    wadf = p.lathe([(0.0183, -0.036), (0.0183, -0.009), (0.0168, -0.0064), (0.0125, -0.0052), (0.0086, -0.005)],
                   "wad", segments=14, cap_bottom=False, cap_top=False, smooth=True)
    p.move(wadf, T(0, MUZZLE_Y, 0) @ R('X', -90))


def _barbs(p):
    H.barbs(p, T(0, MUZZLE_Y + HEAD_LEN, 0) @ R('Y', HEAD_ROLL), s=HEAD_S, spurs=(-0.152, -0.188))


def ring_tie():
    side = RING_N.cross(Vector((0, 0, 1))).normalized()
    if side.x > 0:
        side = -side
    return RING_C + side * RING_R


def _rope(p):
    tie = ring_tie()
    run = [tie, tie + Vector((-0.010, -0.012, -0.002)), Vector((-0.04, MUZZLE_Y + 0.004, -0.007)),
           Vector((-0.0455, MUZZLE_Y - 0.02, -0.010)), Vector((-0.047, 0.36, -0.012)), Vector((-0.048, 0.30, -0.013)),
           Vector((-0.050, 0.24, -0.011)), Vector((-0.052, 0.19, -0.007)), Vector((-0.054, 0.155, -0.002)),
           GUIDE_C, Vector((-0.0565, 0.114, -0.004)), Vector((-0.0575, 0.09, -0.013)),
           Vector((-0.0575, 0.06, -0.029)), Vector((-0.057, 0.03, -0.045)), Vector((-0.0565, 0.0, -0.057)),
           Vector((-0.056, -0.03, -0.064)), Vector((-0.0555, -0.06, -0.065)), Vector((-0.0555, -0.088, -0.06)),
           Vector((-0.0545, -0.106, -0.05)), Vector((COIL_X, -0.118, -0.0415))]
    pts = list(run)
    # the coil: three loose loops hung over the hook, fanned and spreading outward
    loops = [(0.047, -0.004, 8.0), (0.051, 0.004, -6.0), (0.044, 0.0, 14.0)]
    top = Vector((COIL_X, HOOK.y - 0.002, HOOK.z + 0.0071))
    n = 18
    for k, (rad, dy, fan) in enumerate(loops):
        a = math.radians(fan)
        e1 = Vector((math.sin(a) * 0.25, -math.cos(a), 0.0)).normalized()
        start = top + Vector((-0.0075 * k, 0.0, 0.0))
        end = top + Vector((-0.0075 * (k + 1), 0.0, 0.0))
        for i in range(1, n + 1):
            th = math.tau * i / n
            base = start.lerp(end, i / n)
            spread = (1 - math.cos(th)) * 0.5
            q = base + e1 * (math.sin(th) * rad) + Vector((-0.010 * spread * (k + 1) * 0.6, dy * spread,
                                                           -(1 - math.cos(th)) * rad * 1.12))
            pts.append(q)
    # the tail end drops down the front of the coil
    last = pts[-1]
    for i, (dx, dy, dz) in enumerate(((-0.004, 0.012, -0.012), (-0.006, 0.02, -0.04), (-0.007, 0.022, -0.075),
                                      (-0.007, 0.02, -0.105))):
        pts.append(last + Vector((dx, dy, dz)))
    faces, length = H.rope(p, pts, 0.0045, "rope", sides=6, chunk=0.2)
    # knot at the ring and whipping on the tail end
    kit.sphere(p, tie + Vector((-0.002, -0.004, 0.0)), 0.0068, "rope", segments=8, rings=5, squash=(1.0, 1.3))
    end = pts[-1]
    d = (pts[-1] - pts[-2]).normalized()
    kit.seg(p, end - d * 0.014, end - d * 0.002, [(0.0051, 0.0), (0.0051, 1.0)], "twine", segments=6)


def _reel(p):
    c = REEL_C
    x0, x1 = 0.062, 0.104                      # flange outer faces
    # iron bracket plate on the stock side, boss to the inner flange, yoke round under the reel
    p.box((0.0435, c.y, -0.037), (0.004, 0.074, 0.032), "iron", bevel=0.0015)
    for dy in (-0.026, 0.026):
        kit.seg(p, (0.0452, c.y + dy, -0.044), (0.048, c.y + dy, -0.044), [(0.0033, 0.0), (0.0033, 0.5),
                                                                           (0.002, 1.0)], "iron", segments=6)
    kit.seg(p, (0.045, c.y, c.z), (x0, c.y, c.z), [(0.0105, 0.0), (0.0085, 0.4), (0.008, 1.0)], "iron", segments=10)
    p.tube([(0.046, c.y, -0.052), (0.062, c.y, -0.079), (0.085, c.y, -0.083), (0.106, c.y, -0.077),
            (0.1115, c.y, -0.055), (0.1115, c.y, c.z)], 0.0038, "iron", sides=4, smooth=False)
    # brass flanges with rolled rims, line wound on the drum, iron axle
    for xa, xb in ((x0, x0 + 0.0045), (x1 - 0.0045, x1)):
        kit.seg(p, (xa, c.y, c.z), (xb, c.y, c.z), [(0.0445, 0.0), (0.0482, 0.25), (0.0482, 0.75), (0.0445, 1.0)],
                "brass", segments=22, smooth=True)
    kit.seg(p, (x0 + 0.0045, c.y, c.z), (x1 - 0.0045, c.y, c.z),
            [(0.0362, 0.0), (0.0378, 0.12), (0.0372, 0.5), (0.0378, 0.88), (0.0362, 1.0)], "reel_line", segments=22,
            caps=False)
    kit.seg(p, (x0 - 0.004, c.y, c.z), (0.116, c.y, c.z), [(0.0052, 0.0), (0.0052, 1.0)], "iron", segments=8)
    # a turn of line coming off the drum, tied to the front of the bracket
    pts = [Vector((0.07, c.y + 0.006, c.z + 0.0378)), Vector((0.068, c.y + 0.03, c.z + 0.027)),
           Vector((0.06, c.y + 0.042, c.z + 0.002)), Vector((0.05, c.y + 0.037, -0.034))]
    H.rope(p, pts, 0.0035, "rope", sides=5)


def _crank(p):
    c = Vector((CRANK_X, REEL_C.y, REEL_C.z))
    kit.seg(p, (CRANK_X - 0.004, c.y, c.z), (CRANK_X + 0.005, c.y, c.z), [(0.0078, 0.0), (0.0078, 0.6),
                                                                          (0.0062, 1.0)], "iron", segments=10)
    arm_len = 0.042
    ang = 30.0                                  # arm up and a little back at rest
    arm = p.box((0, 0, 0), (0.005, 0.011, arm_len + 0.012), "iron", bevel=0.0016)
    p.move(arm, T(CRANK_X + 0.002, c.y, c.z) @ R('X', ang) @ T(0, 0, arm_len / 2))
    knob_c = T(0, c.y, c.z) @ R('X', ang) @ Vector((0, 0, arm_len))
    kit.seg(p, (CRANK_X + 0.003, knob_c.y, knob_c.z), (CRANK_X + 0.036, knob_c.y, knob_c.z),
            [(0.0045, 0.0), (0.0045, 0.12), (0.0085, 0.22), (0.0098, 0.5), (0.0092, 0.8), (0.0062, 1.0)], "brass",
            segments=10)


def build():
    gun = Part("harpoon")
    _barrel(gun)
    _stock(gun)
    _bands(gun)
    _lock(gun)
    head = Part("head", origin=(0, MUZZLE_Y, 0), parent="harpoon")
    _head(head)
    barbs = Part("upg_barbs", origin=(0, MUZZLE_Y + 0.2, 0), parent="head")
    _barbs(barbs)
    rope = Part("rope", origin=tuple(GUIDE_C), parent="harpoon")
    _rope(rope)
    reel = Part("upg_reel", origin=tuple(REEL_C), parent="harpoon")
    _reel(reel)
    crank = Part("reel_crank", origin=(CRANK_X, REEL_C.y, REEL_C.z), parent="upg_reel")
    _crank(crank)
    # right hand on the stock wrist
    rc = Vector((0.0, -0.262, -0.046))
    # the forearm continues the straight stock wrist's line (cant 70), the
    # sleeve back along it and a little down; it sits below the frame
    right = Part("hand_r", origin=tuple(rc), parent="harpoon")
    m = hands.hand_matrix(rc, (0, 0.95, 0.3), (1.0, 0.0, 0.6), sx=1)
    sleeve_r, markers_r = hands.arm("r", right, m, 1, math.radians(70.0), (0.0, -0.95, -0.3), 0.22,
                                    parent="harpoon")
    # left hand under the fore-stock, between the bands (cant 35); the
    # forearm down and left to an elbow under the gun
    lc = Vector((0.0, 0.19, -0.04))
    left = Part("hand_l", origin=tuple(lc), parent="harpoon")
    m = hands.hand_matrix(lc, (0, 1, 0), (0.7, 0.0, -0.7), sx=-1)
    sleeve_l, markers_l = hands.arm("l", left, m, -1, math.radians(35.0), (-0.50, -0.62, -0.60), 0.36, watch=True,
                                    parent="harpoon")
    anchor = ring_tie()
    return Model("vm_harpoon", [gun, head, barbs, rope, reel, crank, right, left, sleeve_r, sleeve_l], FNS, ppm=512,
                 organic=("hand_r", "hand_l", "sleeve_r", "sleeve_l"), ao_dist=0.03, ao_rays=12, ao_stride=1, front=1,
                 markers=[("Muzzle", (0.0, MUZZLE_Y + 0.002, 0.0), None),
                          ("LineAnchor", (round(anchor.x, 4), round(anchor.y, 4), 0.0), None)]
                 + markers_r + markers_l,
                 variants={"vm_harpoon_master": MASTER},
                 preview_yaws=(-60.0, 40.0, 110.0, 250.0), preview_elevation=16.0,
                 preview_fp=(CAM, LOOK),
                 preview_extra=[("head", (0.0, MUZZLE_Y + 0.17, 0.0), 0.16, -40.0, 30.0),
                                ("reel", (0.08, -0.02, -0.02), 0.11, 70.0, 20.0),
                                ("left", (-0.04, -0.05, -0.06), 0.2, -80.0, 10.0)])
