"""The knight enemy: a suit of German gothic plate from the armoury, walking
on its own. Fluted breastplate, hooped faulds, a sallet with a long tail and
a bevor, a dark eye slit with an ember glow inside (the helmet is empty),
pointed sabatons, a painted heater shield (red with a gold chevron, chipped
and cut), a longsword. Dents, scratches and rust in the joints.

Faces +Y in Blender = -Z in Godot. Origin on the floor between the feet.
Parts (Godot node names), pivots at the joints:
    torso        (0, 0, 1.00)       waist                       root
    head         (0, 0, 1.62)       neck (sallet + bevor)       child of torso
    arm_l, arm_r (-/+0.30, 0, 1.52) shoulders                   children of torso
    shield       (-0.10, 0.38, 1.10) grip behind the shield     child of arm_l
    weapon       (0.38, 0.27, 1.17) sword grip, blade along +Y  child of arm_r
    leg_l, leg_r (-/+0.12, 0, 0.92) hips                        root
Loose plates that the game can knock off (node names start with "plate_"):
    plate_pauldron_l / _r  children of arm_l / arm_r (mail shows beneath)
    plate_tasset_l / _r    children of torso
    plate_poleyn_l / _r    children of leg_l / leg_r
Matches src/enemies/knight.gd: capsule r 0.42 h 2.0, body hurtbox up to
1.575 m, head weak point (sphere r 0.2) centred 1.8 m, shield about
0.66 x 0.94 m in front of the left side, sword held forward at 1.2 m.
"""
import math

import numpy as np
from mathutils import Vector

from artlib import kit
from artlib import materials as M
from artlib.geo import Part
from artlib.kit import R, T
from artlib.model import Model

HELM_C = (0.0, 0.0, 1.8)
SLIT = (1.786, 1.812)
SHOULDER = 0.30
HIP = 0.12
GRIP_R = Vector((0.38, 0.27, 1.17))
GRIP_L = Vector((-0.1, 0.38, 1.1))


def _front(angle_deg):
    """Predicate: face centre within ``angle_deg`` of +Y around the Z axis."""
    c = math.cos(math.radians(angle_deg))
    return lambda v: v.y / max(math.hypot(v.x, v.y), 1e-6) > c


# --------------------------------------------------------------------------
# torso
# --------------------------------------------------------------------------

def _flutes(i, j, segments=24, rings=(2, 3, 4, 5)):
    """ring_scale for the breastplate: a forward 'pigeon breast' and
    vertical flutes on the front half."""
    a = math.tau * i / segments
    front = math.sin(a)                  # +1 at +Y
    s = 1.0
    if j in (2, 3) and front > 0:
        s += 0.07 * front
    if j in rings and front > 0.25 and i % 2 == 0:
        s += 0.022
    return s


def _torso(p):
    sq = (1.0, 0.78)
    # mail skirt under the faulds
    p.lathe([(0.19, 1.0), (0.215, 0.9), (0.235, 0.8)], "mail", segments=16, squash=(1.0, 0.82),
            cap_bottom=False, cap_top=False)
    # breast- and backplate in one shell
    p.lathe([(0.19, 1.0), (0.2, 1.1), (0.235, 1.25), (0.255, 1.36), (0.255, 1.45), (0.238, 1.52), (0.2, 1.565),
             (0.14, 1.595), (0.0, 1.6)], "steel", segments=24, squash=sq, ring_scale=_flutes, smooth=False)
    # hooped faulds, each lame overlapping the next
    for k, (z0, z1, r0, r1) in enumerate(((1.02, 0.96, 0.205, 0.222), (0.975, 0.915, 0.218, 0.236),
                                          (0.93, 0.87, 0.232, 0.25))):
        f = p.lathe([(r0, z0), (r1, z1), (r1 - 0.012, z1 - 0.004)], "steel", segments=24, squash=(1.0, 0.8),
                    cap_bottom=False, cap_top=False, smooth=False)
        kit.thicken(p, f, 0.006)
    # belt with a brass buckle
    p.lathe([(0.197, 1.035), (0.197, 1.075)], "leather", segments=24, squash=sq, cap_bottom=False, cap_top=False)
    p.box((0, 0.158, 1.055), (0.06, 0.012, 0.05), "brass", bevel=0.004)
    # gorget
    p.lathe([(0.15, 1.56), (0.14, 1.6), (0.118, 1.635), (0.112, 1.67), (0.0, 1.672)], "steel", segments=16,
            squash=(1.0, 0.92), smooth=False)
    # brass rivets along the neckline and the waist
    for k in range(9):
        a = math.radians(40 + k * 12.5)
        p.box((0.2 * math.cos(a), 0.2 * 0.78 * math.sin(a) + 0.004, 1.545 - abs(k - 4) * 0.004), (0.014, 0.012, 0.014),
              "brass", bevel=0.004)
    # a raised gothic rib down the middle of the breastplate
    rib = p.box((0, 0, 0), (0.018, 0.02, 0.36), "steel", bevel=0.006)
    p.move(rib, T(0, 0.212, 1.3) @ R('X', -8))


def _tasset(p, sx):
    f = kit.plate_ring(p, (0, 0, 0), [(0.255, 0.9), (0.268, 0.8), (0.275, 0.7)], "steel", segments=28,
                       squash=(1.0, 0.82),
                       keep_pred=lambda v: v.y > 0.05 and sx * v.x > 0.03 and sx * v.x < 0.24 and v.y > 0.1,
                       thickness=0.007)
    for z in (0.83, 0.76):           # lames: raised lines
        g = kit.plate_ring(p, (0, 0, 0), [(0.272, z + 0.006), (0.278, z), (0.272, z - 0.006)], "steel", segments=28,
                           squash=(1.0, 0.82),
                           keep_pred=lambda v: v.y > 0.1 and sx * v.x > 0.03 and sx * v.x < 0.24)
        f += g
    return f


# --------------------------------------------------------------------------
# helmet
# --------------------------------------------------------------------------

def _head(p):
    prof = [(0.166, 1.655), (0.157, 1.7), (0.149, 1.745), (0.151, SLIT[0]), (0.153, SLIT[1]), (0.151, 1.86),
            (0.131, 1.92), (0.09, 1.963), (0.0, 1.984)]
    faces = p.lathe(prof, "steel", segments=24, cap_bottom=False, squash=(0.9, 1.0), smooth=True)
    # the sallet's tail: the back of the brim sweeps down and out
    verts = {v for f in faces for v in f.verts}
    for v in verts:
        back = max(0.0, -v.co.y) / 0.15
        k = M.smoothstep(1.86, 1.66, np.array([v.co.z]))[0]
        v.co.y -= back * k * 0.13
        v.co.z -= back * k * 0.05
        v.co.x *= 1.0 + back * k * 0.12
    # eye slit: cut the band between SLIT[0] and SLIT[1] across the front
    slit = [f for f in faces if SLIT[0] - 0.002 < f.calc_center_median().z < SLIT[1] + 0.002
            and _front(62)(f.calc_center_median())]
    import bmesh
    bmesh.ops.delete(p.bm, geom=slit, context='FACES')
    # the empty helmet glows inside
    kit.sphere(p, HELM_C, 0.118, "void", segments=12, rings=6)
    # a low comb along the skull
    comb = p.box((0, 0, 0), (0.014, 0.2, 0.03), "steel", bevel=0.005)
    p.move(comb, T(0, -0.01, 1.968))
    # bevor: chin and throat plate rising from the gorget, front only
    kit.plate_ring(p, (0, 0.012, 0), [(0.13, 1.6), (0.158, 1.66), (0.165, 1.72), (0.158, 1.765)], "steel",
                   segments=20, squash=(0.95, 1.0), keep_pred=_front(78), thickness=0.008)
    # brass rivets on the brim
    for k in range(7):
        a = math.radians(35 + 110 * k / 6)
        x, y = 0.9 * 0.152 * math.cos(a), 0.152 * math.sin(a)
        if y < 0.02:
            continue
        p.box((x * 1.02, y * 1.02, 1.835), (0.012, 0.012, 0.012), "brass", bevel=0.003)


# --------------------------------------------------------------------------
# arms, shield, sword
# --------------------------------------------------------------------------

def _arm(p, sx, elbow, wrist, grip, grip_axis):
    shoulder = Vector((sx * SHOULDER, 0.0, 1.52))
    elbow, wrist, grip = Vector(elbow), Vector(wrist), Vector(grip)
    kit.sphere(p, shoulder, 0.088, "mail", segments=10, rings=6)
    kit.seg(p, shoulder + Vector((0, 0, -0.04)), elbow, [(0.068, 0.0), (0.064, 0.5), (0.058, 1.0)], "steel",
            segments=10)                                                        # rerebrace
    kit.sphere(p, elbow, 0.062, "steel", segments=10, rings=6, smooth=False)   # couter
    fan = kit.sphere(p, (0, 0, 0), 0.07, "steel", segments=10, rings=4, zscale=0.3, smooth=False)
    p.move(fan, T(*(elbow + Vector((sx * 0.055, -0.01, 0.0)))) @ R('Y', sx * 90))
    kit.seg(p, elbow, wrist, [(0.054, 0.0), (0.05, 0.6), (0.046, 1.0)], "steel", segments=10)   # vambrace
    d = (grip - wrist).normalized()
    kit.seg(p, wrist - d * 0.02, wrist + d * 0.05, [(0.05, 0.0), (0.066, 1.0)], "steel", segments=10,
            caps=False, smooth=False)                                           # gauntlet cuff
    # gauntlet fist: back plate + finger lames around the grip
    ax = Vector(grip_axis).normalized()
    up = d.cross(ax).normalized()
    m = T(*grip) @ kit.Matrix((
        (ax.x, d.x, up.x, 0), (ax.y, d.y, up.y, 0), (ax.z, d.z, up.z, 0), (0, 0, 0, 1)))
    fist = p.box((0, -0.01, 0), (0.1, 0.075, 0.085), "steel", bevel=0.012)
    for k in range(3):
        fist += p.box((0, 0.03, 0.03 - k * 0.028), (0.098, 0.03, 0.026), "steel", bevel=0.006)
    fist += p.box((sx * -0.055, 0.015, 0.02), (0.03, 0.05, 0.03), "steel", bevel=0.008)   # thumb
    p.move(fist, m)


def _pauldron(p, sx):
    shoulder = Vector((sx * SHOULDER, 0.0, 1.52))
    cap = p.lathe([(0.0, 0.075), (0.07, 0.062), (0.118, 0.025), (0.138, -0.03), (0.142, -0.085)], "steel",
                  segments=16, cap_bottom=False, smooth=True)
    lames = []
    for k, (r, z) in enumerate(((0.146, -0.095), (0.15, -0.135))):
        lames += p.lathe([(r - 0.004, z + 0.012), (r + 0.004, z - 0.02), (r, z - 0.03)], "steel", segments=16,
                         cap_bottom=False, cap_top=False, smooth=False)
    faces = kit.thicken(p, cap + lames, 0.007)
    p.move(faces, T(*(shoulder + Vector((sx * 0.02, 0.0, 0.03)))) @ R('Y', sx * 38))
    # keep only the outer/upper part so the arm can still move
    return faces


def _shield(p):
    """Heater shield, 0.66 x 0.94, curved, front at +Y. Built flat in the XZ
    plane around the grip, then bent."""
    n = 14
    outline = []
    for k in range(n + 1):                        # right side, top -> point
        t = k / n
        z = 0.46 - 0.94 * t
        w = 0.33 * (1.0 - t ** 2.4) ** 0.5
        outline.append((w, z))
    for k in range(n - 1, -1, -1):                # left side, point -> top
        t = k / n
        z = 0.46 - 0.94 * t
        w = 0.33 * (1.0 - t ** 2.4) ** 0.5
        outline.append((-w, z))
    # top edge gently arched
    pts = [(x, z + 0.02 * (1 - (x / 0.33) ** 2) if z > 0.45 else z) for x, z in outline]
    pts = list(reversed(pts))                      # counter-clockwise: +Z face = the painted front
    faces = p.ngon_prism(pts, -0.03, 0.0, "shield_face", bevel=0.004)
    p.move(faces, R('X', 90))                      # outline XY -> XZ; the painted face ends up at +Y
    for f in faces:
        f.normal_update()
        if f.normal.y < -0.5:
            f.material_index = p.slot("shield_back")
        elif abs(f.normal.y) <= 0.5:
            f.material_index = p.slot("shield_edge")
    # vertical cuts first: bent flat ngons would sag behind the curve
    import bmesh
    for k in range(1, 14):
        x = -0.33 + 0.66 * k / 14
        geom = p.bm.verts[:] + p.bm.edges[:] + p.bm.faces[:]
        bmesh.ops.bisect_plane(p.bm, geom=geom, plane_co=(x, 0, 0), plane_no=(1, 0, 0))
    faces = list(p.bm.faces)
    kit.bend(p, faces, 0.75)
    # iron rim along the edge
    rim = []
    for k in range(len(pts)):
        x, z = pts[k]
        a = x / 0.75
        rim.append((0.765 * math.sin(a), 0.765 * math.cos(a) - 0.75, z))
    rim.append(rim[0])
    p.tube(rim, 0.011, "steel", sides=5, smooth=False, caps=False)
    # enarmes: two leather straps on the back for the forearm and the hand
    for z, w in ((0.08, 0.3), (-0.08, 0.22)):
        p.box((0, -0.015, z), (w, 0.02, 0.04), "leather", bevel=0.005)
    p.box((0, -0.01, 0.0), (0.2, 0.03, 0.2), "leather", bevel=0.01)            # arm pad
    p.move(list(p.bm.faces), T(*GRIP_L) @ T(0, 0.06, 0))


def _sword(p):
    g = GRIP_R
    kit.seg(p, g + Vector((0, -0.12, 0)), g + Vector((0, 0.07, 0)), [(0.016, 0.0), (0.018, 0.5), (0.016, 1.0)],
            "leather", segments=8)                                             # grip
    wheel = p.lathe([(0.0, -0.013), (0.034, -0.013), (0.038, 0.0), (0.034, 0.013), (0.0, 0.013)], "brass",
                    segments=10, smooth=False)                                  # wheel pommel
    p.move(wheel, T(*(g + Vector((0, -0.14, 0)))) @ R('Y', 90))
    p.box(g + Vector((0, 0.085, 0)), (0.24, 0.028, 0.024), "steel", bevel=0.006)   # cross guard
    for sx in (-1, 1):
        q = p.box((0, 0, 0), (0.05, 0.026, 0.022), "steel", bevel=0.006)
        p.move(q, T(*(g + Vector((sx * 0.13, 0.095, -0.006)))) @ R('Y', sx * 20))
    blade = p.lathe([(0.029, 0.0), (0.027, 0.3), (0.021, 0.6), (0.012, 0.76), (0.0, 0.86)], "blade", segments=4,
                    squash=(1.0, 0.24), smooth=False, cap_bottom=True)
    p.move(blade, T(*(g + Vector((0, 0.1, 0)))) @ R('X', -90))


# --------------------------------------------------------------------------
# legs
# --------------------------------------------------------------------------

def _leg(p, sx):
    x = sx * 0.13
    p.lathe([(0.1, 0.96), (0.095, 0.86), (0.088, 0.74)], "mail", segments=12, center=(sx * HIP, 0, 0),
            cap_bottom=False, cap_top=False)
    p.lathe([(0.104, 0.88), (0.108, 0.8), (0.1, 0.68), (0.084, 0.58)], "steel", segments=14,
            center=(x, 0.008, 0), squash=(1.0, 0.92))                           # cuisse
    p.lathe([(0.074, 0.56), (0.08, 0.46), (0.068, 0.32), (0.052, 0.17), (0.056, 0.12)], "steel", segments=14,
            center=(x, 0.0, 0), squash=(1.0, 0.95))                             # greave
    # sabaton: a pointed foot of overlapping lames, flat sole
    lames = lambda i, j: 1.0 + (0.05 if j in (2, 4, 6) else 0.0)
    foot = p.lathe([(0.052, 0.0), (0.06, 0.05), (0.06, 0.1), (0.052, 0.15), (0.05, 0.19), (0.036, 0.24),
                    (0.032, 0.27), (0.014, 0.31), (0.0, 0.34)], "steel", segments=10, squash=(1.0, 0.62),
                   ring_scale=lames, smooth=False)
    p.move(foot, T(x, -0.07, 0.045) @ R('X', -90))
    for v in {v for f in foot for v in f.verts}:
        v.co.z = max(v.co.z, 0.004)
    p.box((x, -0.08, 0.035), (0.09, 0.07, 0.07), "steel", bevel=0.012)        # heel


def _poleyn(p, sx):
    x = sx * 0.13
    cop = kit.sphere(p, (0, 0, 0), 0.068, "steel", segments=12, rings=6, smooth=False)
    cop = kit.keep(p, cop, lambda v: v.z > -0.02)
    cop = kit.thicken(p, cop, 0.006)
    p.move(cop, T(x, 0.05, 0.52) @ R('X', -80))
    wing = kit.sphere(p, (0, 0, 0), 0.07, "steel", segments=10, rings=4, zscale=0.28, smooth=False)
    p.move(wing, T(x + sx * 0.06, 0.03, 0.52) @ R('Y', sx * 90) @ R('X', 10))
    for z in (0.6, 0.44):
        band = kit.plate_ring(p, (x, 0.0, 0), [(0.078, z + 0.022), (0.083, z), (0.078, z - 0.022)], "steel",
                              segments=14, keep_pred=lambda v, x=x: v.y > -0.01)
        cop += band
    return cop


# --------------------------------------------------------------------------
# paint
# --------------------------------------------------------------------------

def shield_face(ctx):
    """Red field, gold chevron, black edging; crackled, chipped to the wood,
    two sword cuts."""
    lx = ctx.p[:, 0] - GRIP_L.x
    lz = ctx.p[:, 2] - GRIP_L.z
    s = M.paint(ctx, "cloth_red", 4.0, seed=301, chip=1.0, under="wood_oak", crackle=0.6, gloss=0.5)
    chev = (np.abs(lz - (0.02 - np.abs(lx) * 0.95)) < 0.075)
    ochre = M.paint(ctx, "paint_ochre", 5.0, seed=303, chip=0.0, crackle=0.6, gloss=0.45)
    keep_chips = s.ramp_id < 1                     # paint ramp id 0; chipped wood uses later ramps
    sel = chev & keep_chips
    s.merge(M._select(ochre, sel), sel)
    for x0, z0, x1, z1 in ((-0.2, 0.3, 0.05, 0.12), (0.12, -0.05, 0.26, -0.2)):
        d = np.array([x1 - x0, z1 - z0])
        L = np.linalg.norm(d)
        d /= L
        t = (lx - x0) * d[0] + (lz - z0) * d[1]
        off = -(lx - x0) * d[1] + (lz - z0) * d[0]
        cut = (t > 0) & (t < L) & (np.abs(off) < ctx.texel * 1.2)
        lip = (t > 0) & (t < L) & (np.abs(off) < ctx.texel * 2.6) & ~cut
        s.use_ramp(M.P["wood_oak"], mask=cut, shade=np.full(ctx.N, 1.0))
        s.shade[lip] += 1.2
        s.height = s.height - cut * 0.002
    return s


def shield_back(ctx):
    s = M.wood_oak(ctx)
    plank = np.mod((ctx.p[:, 0] - GRIP_L.x + 1.0) / 0.11, 1.0) < 0.06
    s.shade[plank] -= 2.5
    s.height = s.height - plank * 0.001
    return s


def blade(ctx):
    s = M.steel(ctx, seed=307, center=9.0, dent=0.0, rust=0.3, polish=0.16, scratch=0.3)
    # fuller: a darker groove down the middle of the blade's flats
    flat = np.abs(ctx.n[:, 2]) > 0.8
    fuller = flat & (np.abs(ctx.p[:, 0] - GRIP_R.x) < 0.006) & (ctx.p[:, 1] < GRIP_R.y + 0.7)
    s.shade[fuller] -= 2.0
    s.height = s.height - fuller * 0.001
    return s


def void(ctx):
    """Inside the empty helmet: smoky dark with an ember glow and two hot
    points where eyes would be, visible through the slit."""
    s = M.Surface(ctx.N)
    d = ctx.p - np.array(HELM_C)
    fwd = d[:, 1] / 0.118
    s.use_ramp(M.P["ember"], shade=0.8 + np.clip(fwd, 0, 1) * 2.2 + ctx.fbm(30.0, 2, 5) * 0.8)
    eyes = np.zeros(ctx.N, dtype=bool)
    for ex in (-0.042, 0.042):
        e = np.sqrt((d[:, 0] - ex) ** 2 + ((d[:, 2] - 0.0) * 1.4) ** 2)
        eyes |= (e < 0.02) & (fwd > 0.5)
        hot = (e < 0.01) & (fwd > 0.5)
        s.shade[hot] = 7.0
    s.shade[eyes] = np.maximum(s.shade[eyes], 5.2)
    s.rough = np.full(ctx.N, 0.9)
    s.emit = s.colors() * np.where(eyes, 1.0, 0.35)[:, None]
    return s


def armour(ctx):
    return M.steel(ctx, seed=311, center=8.4, dent=0.4, rust=1.0, polish=0.32, scratch=0.25)


def build():
    torso = Part("torso", origin=(0, 0, 1.0))
    _torso(torso)
    head = Part("head", origin=(0, 0, 1.62), parent="torso")
    _head(head)
    arm_l = Part("arm_l", origin=(-SHOULDER, 0, 1.52), parent="torso")
    _arm(arm_l, -1, (-0.35, 0.03, 1.27), (-0.22, 0.27, 1.2), (-0.13, 0.33, 1.14), (0, 0, 1))
    arm_r = Part("arm_r", origin=(SHOULDER, 0, 1.52), parent="torso")
    _arm(arm_r, 1, (0.36, -0.04, 1.26), (0.385, 0.19, 1.18), GRIP_R, (0, 1, 0))
    shield = Part("shield", origin=tuple(GRIP_L), parent="arm_l")
    _shield(shield)
    weapon = Part("weapon", origin=tuple(GRIP_R), parent="arm_r")
    _sword(weapon)
    leg_l = Part("leg_l", origin=(-HIP, 0, 0.92))
    _leg(leg_l, -1)
    leg_r = Part("leg_r", origin=(HIP, 0, 0.92))
    _leg(leg_r, 1)
    pl = Part("plate_pauldron_l", origin=(-SHOULDER - 0.02, 0, 1.58), parent="arm_l")
    _pauldron(pl, -1)
    pr = Part("plate_pauldron_r", origin=(SHOULDER + 0.02, 0, 1.58), parent="arm_r")
    _pauldron(pr, 1)
    tl = Part("plate_tasset_l", origin=(-0.14, 0.2, 0.9), parent="torso")
    _tasset(tl, -1)
    tr = Part("plate_tasset_r", origin=(0.14, 0.2, 0.9), parent="torso")
    _tasset(tr, 1)
    kl = Part("plate_poleyn_l", origin=(-0.13, 0.05, 0.52), parent="leg_l")
    _poleyn(kl, -1)
    kr = Part("plate_poleyn_r", origin=(0.13, 0.05, 0.52), parent="leg_r")
    _poleyn(kr, 1)
    parts = [torso, head, arm_l, arm_r, shield, weapon, leg_l, leg_r, pl, pr, tl, tr, kl, kr]
    fns = {"steel": armour, "mail": M.mail, "leather": M.leather, "brass": M.brass, "void": void,
           "shield_face": shield_face, "shield_back": shield_back, "shield_edge": M.wood_oak, "blade": blade}
    return Model("knight", parts, fns, ppm=256, ground=0.0, ao_dist=0.14, ao_rays=12, ao_stride=2, front=1,
                 normal_strength=2.0, preview_yaws=(-35.0, 35.0, 120.0, 210.0),
                 preview_closeup=((0.0, 0.1, 1.78), 0.2),
                 preview_extra=[("shield", (-0.1, 0.45, 1.1), 0.55, 10.0, 5.0)])
