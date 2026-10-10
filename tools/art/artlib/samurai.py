"""Japanese armour pieces shared by the samurai armour models (Floor I,
Asia wing): the ashigaru enemy (an empty okegawa-do armour with a jingasa
and a yari), the armours on stands in the armour hall, and the Generał
(an o-yoroi with a horned kabuto, a menpo and a nodachi).

Everything is drawn at the scale of a 1.8 m figure with the knight's joint
heights (waist 1.0, neck 1.62, shoulders +-0.30 / 1.52, hips +-0.12 / 0.92;
Blender axes, the figure faces +Y); a model may scale the finished parts
(the General is 1.44x). Each function adds geometry to a Part.

Material slots (paint functions below, ``FNS``):
    lame      black-lacquered lames under dense silk lacing (kebiki odoshi):
              rows from the metre-UV v, cords from u; the lacing colour is
              the model's (``laced(ramp)``)
    plate     solid black lacquer plates with a gilt rim
    gold      gilt copper fittings (kanamono), the horns, the crest
    leather   the stencilled deerskin of the breastplate (tsurubashiri)
    brocade   silk brocade of the sleeves and the thigh apron
    mail      fine black chain mail (kusari) on cloth
    cloth     dark hemp (hakama, the tabi)
    straw     straw sandals
    mask      red-lacquered iron of the menpo
    hair      white horsehair (moustache, plume)
    teeth     gilt teeth of the mask
    void      the darkness inside: an ember glow and two hot eyes
"""
import math

import bmesh
import numpy as np
from mathutils import Matrix, Vector

from . import asia as A
from . import asia_paint as AP
from . import egypt as E
from . import kit as K
from . import materials as M
from .geo import Part
from .kit import R, T
from .materials import P, _dither, smoothstep
from .painter import Surface

I = AP.INK
WAIST, NECK = 1.0, 1.62
SHOULDER = 0.30
HIP = 0.12


def _front(angle_deg):
    c = math.cos(math.radians(angle_deg))
    return lambda v: v.y / max(math.hypot(v.x, v.y), 1e-6) > c


# --------------------------------------------------------------------------
# cuirass
# --------------------------------------------------------------------------

def do_bands(p, z0, z1, rows, r0, r1, slot, squash=(1.0, 0.8), segments=24, step=0.006, center=(0, 0, 0)):
    """The cuirass as overlapping horizontal bands from z0 up to z1, the
    radius going from r0 to r1 (each band's lower edge steps out over the
    next one, as lames do)."""
    h = (z1 - z0) / rows
    faces = []
    for k in range(rows):
        za, zb = z0 + k * h, z0 + (k + 1) * h
        ra = r0 + (r1 - r0) * k / rows
        rb = r0 + (r1 - r0) * (k + 1) / rows
        f = p.lathe([(ra + step, za - 0.006), (ra + step * 0.6, za + h * 0.3), (rb, zb)], slot, segments=segments,
                    squash=squash, cap_bottom=False, cap_top=False, smooth=True, center=center)
        faces += f
    return faces


def okegawa_do(p):
    """Ashigaru cuirass: riveted horizontal plates, black lacquer, a chest
    plate and shoulder straps; lacing only at the waist."""
    do_bands(p, 0.98, 1.36, 7, 0.205, 0.245, "plate")
    p.lathe([(0.245, 1.36), (0.25, 1.4), (0.24, 1.46), (0.2, 1.52)], "plate", segments=24, squash=(1.0, 0.8),
            cap_bottom=False, cap_top=False, smooth=True)
    # neck opening plate (muna-ita) and the straps over the shoulders
    mi = K.plate_ring(p, (0, 0, 0), [(0.2, 1.5), (0.17, 1.56), (0.13, 1.58)], "plate", segments=20,
                      squash=(1.0, 0.85), keep_pred=_front(70), thickness=0.008)
    for sx in (-1, 1):
        p.tube([(sx * 0.1, 0.13, 1.56), (sx * 0.16, 0.05, 1.62), (sx * 0.17, -0.08, 1.6), (sx * 0.12, -0.16, 1.54)],
               0.022, "plate", sides=6)
    # a gilt rivet head on every plate front
    for k in range(7):
        z = 0.98 + (k + 0.5) * (0.38 / 7)
        for a in (55, 90, 125):
            r = 0.21 + 0.04 * k / 7
            x, y = r * math.cos(math.radians(a)), r * 0.8 * math.sin(math.radians(a))
            p.box((x, y + 0.006, z), (0.012, 0.012, 0.012), "gold", bevel=0.003)
    # waist sash
    p.lathe([(0.212, 0.95), (0.215, 0.99), (0.212, 1.03)], "cloth", segments=24, squash=(1.0, 0.8), cap_bottom=False,
            cap_top=False)


def oyoroi_do(p):
    """The General's cuirass: laced lames all round, the stencilled leather
    over the front, a lacquered chest plate with gilt rim, the two armpit
    plates (sendan-no-ita right, kyubi-no-ita left)."""
    do_bands(p, 0.98, 1.4, 8, 0.215, 0.255, "lame", squash=(1.0, 0.82))
    p.lathe([(0.255, 1.4), (0.258, 1.44), (0.24, 1.5), (0.2, 1.54)], "lame", segments=24, squash=(1.0, 0.82),
            cap_bottom=False, cap_top=False, smooth=True)
    # tsurubashiri: a leather panel over the front lames
    lp = K.plate_ring(p, (0, 0, 0), [(0.262, 1.02), (0.27, 1.2), (0.268, 1.38), (0.25, 1.44)], "leather", segments=28,
                      squash=(1.0, 0.82), keep_pred=_front(50), thickness=0.006)
    # chest plate (muna-ita) with gilt rim
    K.plate_ring(p, (0, 0, 0), [(0.248, 1.44), (0.21, 1.53), (0.15, 1.57)], "plate", segments=24,
                 squash=(1.0, 0.86), keep_pred=_front(62), thickness=0.012)
    for sx in (-1, 1):
        p.tube([(sx * 0.11, 0.14, 1.57), (sx * 0.17, 0.06, 1.64), (sx * 0.18, -0.08, 1.62), (sx * 0.13, -0.18, 1.55)],
               0.026, "plate", sides=6)
    # armpit plates hanging in front of the shoulder joints
    for sx, slot in ((1, "lame"), (-1, "plate")):
        f = p.box((0.0, 0.0, 0.0), (0.09, 0.012, 0.2), slot, bevel=0.004)
        p.move(f, T(sx * 0.21, 0.19, 1.42) @ R('Z', sx * 25))
    # the gilt agemaki ring at the back, behind the knot (a lathe is made at
    # the part's origin: moved up to the back, its axis through the cuirass -
    # left where it was it hung at the floor between the legs)
    ring = p.lathe([(0.03, -0.01), (0.04, 0.0), (0.03, 0.01)], "gold", segments=8)
    p.move(ring, T(0.0, -0.262, 1.3) @ R('X', 90))


# --------------------------------------------------------------------------
# skirt, shoulder guards, thighs, shins, feet
# --------------------------------------------------------------------------

def plate_panel(p, w, h, rows, slot, bend_r=None, thickness=0.008, flare=0.0):
    """A lamellar panel (sode, kusazuri panel) drawn in the XZ plane facing
    +Y: top edge at z = 0 hanging down to -h, ``rows`` overlapping lames
    (the lower ones standing a little further out, ``flare`` more at the
    bottom), bent round a vertical axis behind it (radius bend_r) so it is
    convex toward +Y. Returns its faces."""
    faces = []
    lh = h / rows
    for k in range(rows):
        z1 = -k * lh
        z0 = z1 - lh * 1.08
        out = 0.004 * k + flare * (k / max(1, rows - 1))
        nx = 6
        verts = []
        for j, z in enumerate((z0, z1)):
            row = []
            for i in range(nx + 1):
                x = -w / 2 + w * i / nx
                row.append(p.bm.verts.new((x, out + (0.006 if j == 0 else 0.0), z)))
            verts.append(row)
        for i in range(nx):
            f = p._face([verts[0][i], verts[0][i + 1], verts[1][i + 1], verts[1][i]], slot, smooth=True)
            f.normal_update()
            if f.normal.y < 0:
                f.normal_flip()
            for loop in f.loops:
                loop[p.uv].uv = (loop.vert.co.x + w / 2, loop.vert.co.z + h)
            f[p.lock] = 1
            faces.append(f)
    if thickness > 0:
        faces = K.thicken(p, faces, thickness)
    if bend_r:
        K.bend(p, faces, bend_r)
    return faces


def kusazuri(p, n, z_top, length, r, rows, slot, part_angles=None, flare=0.06):
    """The skirt: ``n`` panels round the waist (or only those whose centre
    angles are listed), hanging from z_top, curved to the hips."""
    out = []
    angles = part_angles if part_angles is not None else [math.tau * (k + 0.5) / n + math.pi / 2 for k in range(n)]
    w = 2 * math.pi * r / n * 1.05
    for a in angles:
        f = plate_panel(p, w, length, rows, slot, bend_r=r, flare=flare)
        p.move(f, T(0.0, 0.0, z_top) @ R('Z', math.degrees(a) - 90) @ T(0.0, r, 0.0))
        out += f
    return out


def sode(p, w, h, rows, slot="lame", bend_r=0.6):
    """A shoulder guard: a big lamellar plate with a lacquered top plate
    (kanmuri-ita) and gilt studs; drawn hanging from (0, 0, 0)."""
    f = plate_panel(p, w, h, rows, slot, bend_r=bend_r, flare=0.03)
    top = p.box((0.0, -0.004, 0.012), (w + 0.01, 0.018, 0.05), "plate", bevel=0.005)
    K.bend(p, top, bend_r)
    studs = []
    for sx in (-1, 1):
        stud = p.lathe([(0.012, 0.0), (0.012, 0.006), (0.006, 0.01)], "gold", segments=6, cap_top=True)
        p.move(stud, T(sx * w * 0.3, 0.006, 0.012) @ R('X', -90))
        studs += stud
    return f + top + studs


def haidate(p, sx, slot="brocade"):
    """Thigh apron: a curved panel of small plates in front of the thigh."""
    f = plate_panel(p, 0.2, 0.3, 5, slot, bend_r=0.16, thickness=0.005)
    p.move(f, T(sx * 0.13, 0.11, 0.86) @ R('X', 8))
    return f


def hakama_leg(p, sx, z_top=0.95, z_knee=0.5):
    """Wide trouser leg from the hip to below the knee (dark hemp)."""
    return p.lathe([(0.12, z_top), (0.15, 0.8), (0.16, 0.64), (0.13, z_knee + 0.04), (0.075, z_knee - 0.05)], "cloth",
                   segments=12, center=(sx * HIP * 1.05, 0.0, 0.0), squash=(1.0, 1.0), cap_bottom=False,
                   cap_top=False)


def suneate(p, sx, z_top=0.52, knee=True):
    """Shin guard: three lacquered splints joined by mail, a knee plate."""
    x = sx * 0.13
    p.lathe([(0.062, z_top), (0.066, 0.42), (0.056, 0.26), (0.05, 0.12)], "mail", segments=12, center=(x, 0.0, 0.0),
            cap_bottom=False, cap_top=False)
    out = []
    for k, a in enumerate((60, 90, 120)):
        f = p.box((0.0, 0.0, 0.0), (0.034, 0.012, 0.36), "plate", bevel=0.004)
        rr = 0.064
        p.move(f, T(x + rr * math.cos(math.radians(a)), rr * math.sin(math.radians(a)), 0.31) @ R('Z', a - 90)
               @ R('X', -4))
        out += f
    if not knee:
        return out
    kf = K.sphere(p, (0, 0, 0), 0.07, "plate", segments=10, rings=6, smooth=False)
    kf = K.keep(p, kf, lambda c: c.z > -0.02)
    kf = K.thicken(p, kf, 0.006)
    p.move(kf, T(x, 0.05, z_top + 0.02) @ R('X', -78))
    return out + kf


def foot(p, sx):
    """Tabi in a straw sandal."""
    x = sx * 0.13
    f = p.lathe([(0.05, 0.0), (0.055, 0.04), (0.05, 0.1), (0.045, 0.16), (0.035, 0.2), (0.02, 0.22)], "cloth",
                segments=10, squash=(1.0, 0.7), cap_top=True)
    p.move(f, T(x, -0.04, 0.04) @ R('X', -90))
    for v in {v for fc in f for v in fc.verts}:
        v.co.z = max(v.co.z, 0.012)
    p.box((x, 0.05, 0.006), (0.1, 0.26, 0.012), "straw", bevel=0.003)


# --------------------------------------------------------------------------
# arms
# --------------------------------------------------------------------------

def arm(p, sx, shoulder, elbow, wrist, grip, grip_axis, plates=True):
    """A sleeve of brocade with mail and lacquered splints (kote), an
    armoured fist round a grip. Points in model space."""
    shoulder, elbow, wrist, grip = Vector(shoulder), Vector(elbow), Vector(wrist), Vector(grip)
    K.sphere(p, shoulder, 0.08, "brocade", segments=10, rings=6)
    K.seg(p, shoulder + Vector((0, 0, -0.03)), elbow, [(0.078, 0.0), (0.072, 0.5), (0.06, 1.0)], "brocade", segments=10)
    K.sphere(p, elbow, 0.058, "mail", segments=10, rings=6)
    K.seg(p, elbow, wrist, [(0.056, 0.0), (0.05, 0.6), (0.044, 1.0)], "mail", segments=10)
    if plates:
        d = (wrist - elbow).normalized()
        side = d.cross(Vector((0, 0, 1))).normalized() * sx * -1.0
        for k in range(3):
            t = 0.2 + 0.3 * k
            c = elbow + (wrist - elbow) * t + side * 0.0 + Vector((0, 0, 0.045))
            f = p.box((0, 0, 0), (0.05, 0.11, 0.012), "plate", bevel=0.003)
            q = d.to_track_quat('Y', 'Z').to_matrix().to_4x4()
            p.move(f, T(*c) @ q)
        cop = K.sphere(p, (0, 0, 0), 0.06, "plate", segments=8, rings=4, zscale=0.35, smooth=False)
        p.move(cop, T(*(elbow + Vector((0, -0.02, 0.0)))) @ R('X', 90))
    # armoured fist (tekko over a dark glove)
    dgrip = (grip - wrist).normalized()
    ax = Vector(grip_axis).normalized()
    up = dgrip.cross(ax).normalized()
    m = T(*grip) @ Matrix(((ax.x, dgrip.x, up.x, 0), (ax.y, dgrip.y, up.y, 0), (ax.z, dgrip.z, up.z, 0), (0, 0, 0, 1)))
    fist = p.box((0, -0.01, 0), (0.09, 0.07, 0.08), "cloth", bevel=0.012)
    for k in range(3):
        fist += p.box((0, 0.028, 0.026 - k * 0.026), (0.088, 0.028, 0.024), "cloth", bevel=0.006)
    fist += p.box((0, -0.01, 0.035), (0.07, 0.06, 0.012), "plate", bevel=0.004)          # tekko plate
    fist += p.box((sx * -0.05, 0.014, 0.018), (0.028, 0.045, 0.028), "cloth", bevel=0.007)  # thumb
    p.move(fist, m)


# --------------------------------------------------------------------------
# heads
# --------------------------------------------------------------------------

def void_head(p, c, r=0.105):
    """The darkness inside: a sphere painted ember dark with two hot eyes."""
    K.sphere(p, c, r, "void", segments=12, rings=7)


def jingasa(p, c):
    """The ashigaru's iron hat: a wide shallow cone, black lacquer, a gilt
    crest on the front; a cloth hood falling to the shoulders under it."""
    cx, cy, cz = c
    p.lathe([(0.34, cz + 0.035), (0.3, cz + 0.07), (0.2, cz + 0.13), (0.1, cz + 0.17), (0.03, cz + 0.185),
             (0.0, cz + 0.19)], "plate", segments=24, center=(cx, cy, 0.0), cap_bottom=False, smooth=True)
    p.lathe([(0.32, cz + 0.032), (0.34, cz + 0.035)], "plate", segments=24, center=(cx, cy, 0.0),
            cap_bottom=False, cap_top=False)
    p.lathe([(0.0, cz + 0.02), (0.31, cz + 0.03)], "plate", segments=24, center=(cx, cy, 0.0), cap_bottom=False,
            cap_top=False)
    # cloth hood (shikoro of cloth) round the back and sides
    hood = p.lathe([(0.12, cz + 0.04), (0.14, cz - 0.05), (0.17, cz - 0.15), (0.2, cz - 0.21)], "cloth",
                   segments=16, center=(cx, cy, 0.0), cap_bottom=False, cap_top=False)
    K.keep(p, hood, lambda v: not _front(55)(Vector((v.x - cx, v.y - cy, 0.0))))
    # half mask (hoate) over the chin
    m = K.plate_ring(p, (cx, cy, 0.0), [(0.085, cz - 0.11), (0.1, cz - 0.07), (0.1, cz - 0.04)], "plate",
                     segments=16, keep_pred=lambda v: _front(70)(Vector((v.x - cx, v.y - cy, 0.0))), thickness=0.006)


def kabuto(p, c, horns=True, scale=1.0):
    """A ribbed helmet bowl (suji-bachi) with gilt rivet lines, a flaring
    laced neck guard (shikoro) with turned-back wings (fukigaeshi), a visor
    and, with ``horns``, tall gilt kuwagata horns round a sun disc."""
    cx, cy, cz = c
    ribs = lambda i, j: 1.0 + (0.03 if i % 2 == 0 and j > 0 else 0.0)
    p.lathe([(0.15, cz - 0.02), (0.155, cz + 0.04), (0.145, cz + 0.1), (0.11, cz + 0.155), (0.05, cz + 0.18),
             (0.03, cz + 0.182)], "plate", segments=32, center=(cx, cy, 0.0), ring_scale=ribs, cap_bottom=False,
            cap_top=True, smooth=False)
    # the top opening ring (tehen) in gilt
    p.lathe([(0.03, cz + 0.182), (0.036, cz + 0.188), (0.03, cz + 0.194)], "gold", segments=10, center=(cx, cy, 0.0),
            cap_bottom=False, cap_top=False)
    # shikoro: five flaring laced bands, open at the face
    for k in range(5):
        z0 = cz - 0.02 - k * 0.045
        r0 = 0.16 + k * 0.03
        band = p.lathe([(r0, z0), (r0 + 0.03, z0 - 0.05)], "lame", segments=24, center=(cx, cy, 0.0),
                       cap_bottom=False, cap_top=False)
        K.keep(p, band, lambda v: not _front(52 - k * 3)(Vector((v.x - cx, v.y - cy, 0.0))))
    # fukigaeshi: the top band turned back at the front on both sides
    for sx in (-1, 1):
        f = p.box((0.0, 0.0, 0.0), (0.012, 0.1, 0.09), "plate", bevel=0.004)
        p.move(f, T(cx + sx * 0.18, cy + 0.1, cz - 0.04) @ R('Z', sx * -35))
    # visor
    vis = K.plate_ring(p, (cx, cy, 0.0), [(0.152, cz + 0.008), (0.19, cz - 0.006)], "plate", segments=24,
                       keep_pred=lambda v: _front(60)(Vector((v.x - cx, v.y - cy, 0.0))), thickness=0.006)
    if horns:
        # kuwagata: two flat horns sweeping up and out from the visor
        for sx in (-1, 1):
            pts = [(cx + sx * 0.04, cy + 0.17, cz + 0.0), (cx + sx * 0.1, cy + 0.2, cz + 0.12),
                   (cx + sx * 0.17, cy + 0.2, cz + 0.27), (cx + sx * 0.2, cy + 0.17, cz + 0.42),
                   (cx + sx * 0.17, cy + 0.14, cz + 0.52)]
            p.tube(pts, lambda t: 0.028 * (1.0 - 0.7 * t) + 0.006, "gold", sides=4, smooth=False)
        disc = p.lathe([(0.0, 0.0), (0.05, 0.0), (0.055, 0.006), (0.05, 0.012), (0.0, 0.012)], "gold", segments=16)
        p.move(disc, T(cx, cy + 0.19, cz + 0.05) @ R('X', -90))


def menpo(p, c):
    """The red-lacquered mask over the lower face: cheeks, a hooked nose, a
    snarling mouth with gilt teeth, a white horsehair moustache, and the
    three-lame throat guard."""
    cx, cy, cz = c
    shell = K.plate_ring(p, (cx, cy, 0.0), [(0.085, cz - 0.15), (0.11, cz - 0.1), (0.115, cz - 0.06), (0.105, cz - 0.035)],
                         "mask", segments=20, squash=(1.0, 0.95),
                         keep_pred=lambda v: _front(72)(Vector((v.x - cx, v.y - cy, 0.0))), thickness=0.008)
    nose = p.lathe([(0.022, 0.0), (0.026, 0.03), (0.016, 0.055), (0.006, 0.062)], "mask", segments=6,
                   squash=(0.9, 1.0), cap_top=True)
    p.move(nose, T(cx, cy + 0.11, cz - 0.03) @ R('X', 160))
    mouth = p.box((cx, cy + 0.108, cz - 0.1), (0.07, 0.01, 0.02), "teeth", bevel=0.003)
    for sx in (-1, 1):
        p.tube([(cx + sx * 0.02, cy + 0.12, cz - 0.075), (cx + sx * 0.06, cy + 0.11, cz - 0.09),
                (cx + sx * 0.085, cy + 0.08, cz - 0.13)], lambda t: 0.012 * (1.0 - 0.6 * t), "hair", sides=5)
    for k in range(3):
        z = cz - 0.16 - k * 0.04
        band = p.lathe([(0.09 + k * 0.02, z), (0.11 + k * 0.02, z - 0.045)], "lame", segments=16,
                       center=(cx, cy - 0.01, 0.0), cap_bottom=False, cap_top=False)
        K.keep(p, band, lambda v: _front(80)(Vector((v.x - cx, v.y - cy, 0.0))))


# --------------------------------------------------------------------------
# paint
# --------------------------------------------------------------------------

def laced(ramp="lacing_red", center=4.6, lame_h=0.045, seed=1801):
    """Kebiki odoshi: black lacquered lames almost hidden under close
    vertical silk cords; a lacquer line and the cross lacing at each lame
    edge, gilt studs here and there."""
    def fn(ctx):
        u, v = ctx.uvm[:, 0], ctx.uvm[:, 1]
        s = A.lacquer(ctx, seed, ramp="lacquer_black", center=3.0, under="lacquer_red", wear=0.15, crackle=0.2)
        pitch = 0.014
        cu = np.mod(u, pitch) / pitch
        row = np.mod(v, lame_h) / lame_h
        cord = (cu > 0.18) & (cu < 0.82) & (row > 0.12) & (row < 0.95)
        cross = (row < 0.1) & (np.mod(np.floor(u / pitch), 2) == 0)
        silk = cord | cross
        sh = center + np.sin(cu * np.pi) * 1.2 + np.where(cross, -0.6, 0.0) + _dither(ctx, 0.4, seed + 1)
        sh += np.clip(ctx.curv, 0, 1) * 0.8 - ctx.cavity(3.0) * 1.6 - (1.0 - ctx.ao) * 3.2
        s.use_ramp(P[ramp], mask=silk, shade=sh)
        s.rough = np.where(silk, 0.6, s.rough)
        s.metal = np.where(silk, 0.0, s.metal)
        s.height = s.height + silk * 0.0008 - (row > 0.95) * 0.001
        return s
    return fn


def plate(ctx, seed=1811, rim="gold"):
    """Black lacquer plates with a gilt rim (fukurin) on the edges."""
    s = A.lacquer(ctx, seed, ramp="lacquer_black", center=3.2, under="lacquer_red", wear=0.25, crackle=0.12)
    edge = ctx.convex < ctx.texel * 2.5
    if rim == "gold":
        g = A.gilt(ctx, seed + 1, worn=0.3, under="lacquer_black")
        s.merge(A._select(g, edge), edge)
    return s


_MON = {}


def mon_canvas(px):
    """Mitsudomoe: three comma-shaped swirls in a ring, gilt."""
    if px in _MON:
        return _MON[px]
    c = AP.blank(px, px)
    r = px / 2
    AP.ring(c, r, r, r * 0.86, r * 0.98, I["gold"])
    xs, ys = np.mgrid[0:px, 0:px][1] + 0.5, np.mgrid[0:px, 0:px][0] + 0.5
    for k in range(3):
        a = k * math.tau / 3
        hx, hy = r + math.cos(a) * r * 0.36, r + math.sin(a) * r * 0.36
        head = np.hypot(xs - hx, ys - hy) < r * 0.24
        tail = []
        for t in np.linspace(0, 1, 10):
            aa = a + t * 1.9
            rr = r * (0.36 + 0.34 * t)
            tail.append((r + math.cos(aa) * rr, r + math.sin(aa) * rr))
        tm = AP.line_mask(c.shape, tail, list(np.linspace(r * 0.4, 1.0, len(tail))))
        c[(head | tm) & (np.hypot(xs - r, ys - r) < r * 0.82)] = I["gold"]
    _MON[px] = c
    return c


def plate_mon(center, size, seed=1815, rim="gold"):
    """Plates with a gilt mon (mitsudomoe) on the chest at ``center``."""
    def fn(ctx):
        s = plate(ctx, seed, rim=rim)
        px = int(round(size / ctx.texel))
        c = mon_canvas(px)
        u = ctx.p[:, 0] - center[0] + size / 2
        v = ctx.p[:, 2] - center[2] + size / 2
        codes, rims = E.sample(c, u, v, ctx.texel)
        front = ctx.n[:, 1] > 0.5
        codes = np.where(front, codes, 0).astype(np.int16)
        return E.paint_over(ctx, s, codes, rims, seed + 2, flake=0.25, wear=0.4, inks=A.INKS)
    return fn


def leather(ctx, seed=1821):
    """Stencilled deerskin (e-gawa): indigo ground with a grid of white
    cherry-blossom stencils, a red border."""
    s = Surface(ctx.N)
    u, v = ctx.uvm[:, 0], ctx.uvm[:, 1]
    s.use_ramp(P["lacing_blue"], shade=4.2 + ctx.fbm(6.0, 3, seed) * 0.6 + _dither(ctx, 0.5, seed + 1)
               - (1.0 - ctx.ao) * 2.5)
    cell = 0.05
    gu = np.mod(u + np.mod(np.floor(v / cell), 2) * cell / 2, cell) - cell / 2
    gv = np.mod(v, cell) - cell / 2
    r = np.hypot(gu, gv)
    a = np.arctan2(gv, gu)
    petal = r < 0.016 * (0.6 + 0.4 * np.abs(np.cos(a * 2.5)))
    s.use_ramp(P["lacing_white"], mask=petal, shade=np.full(ctx.N, 4.6) + _dither(ctx, 0.5, seed + 2))
    s.shade[petal & (r < 0.004)] -= 3.0
    border = ctx.convex < ctx.texel * 4
    s.use_ramp(P["lacing_red"], mask=border, shade=np.full(ctx.N, 4.0))
    s.rough = np.full(ctx.N, 0.7)
    return s


def brocade(ramp="lacing_blue", gold=True, seed=1831):
    """Silk brocade of the sleeves: a small woven lattice of gold on a
    coloured ground."""
    def fn(ctx):
        s = A.silk(ctx, ramp, 3.6, seed, sheen=0.8)
        if gold:
            u = np.floor(ctx.uvm[:, 0] / ctx.texel)
            v = np.floor(ctx.uvm[:, 1] / ctx.texel)
            pat = (np.mod(u + v, 6) == 0) | (np.mod(u - v, 6) == 0)
            s.use_ramp(P["pig_ochre"], mask=pat, shade=np.full(ctx.N, 4.6) - (1.0 - ctx.ao) * 2.0)
        return s
    return fn


def mail(ctx, seed=1841):
    s = M.mail(ctx, seed)
    s.shade -= 2.0
    return s


def cloth(ctx, seed=1851, ramp="fur_dark", center=3.4):
    return M.cloth(ctx, ramp, center, seed, weave=0.3, rough=0.9)


def straw(ctx, seed=1861):
    s = A.thatch(ctx, seed)
    s.shade += 1.5
    return s


def mask(ctx, seed=1871):
    """Red lacquered iron with black lines in the wrinkles."""
    s = A.lacquer(ctx, seed, ramp="lacquer_red", center=4.6, under="lacquer_black", wear=0.5, crackle=0.3)
    s.shade -= ctx.cavity(3.0) * 2.5
    return s


def hair(ctx, seed=1881):
    s = Surface(ctx.N)
    strands = np.sin(ctx.uvm[:, 0] / ctx.texel * 2.1 + ctx.fbm(10.0, 2, seed) * 3.0) * 0.5 + 0.5
    s.use_ramp(P["lacing_white"], shade=4.6 + strands * 1.6 + _dither(ctx, 0.5, seed + 1) - (1.0 - ctx.ao) * 2.5)
    s.rough = np.full(ctx.N, 0.7)
    return s


def void(eyes, center, r):
    """The darkness under the helmet: smoky ember fading out from the front,
    two hot coals for eyes. ``eyes`` = [(x, y, z), ...] in model space."""
    def fn(ctx):
        s = Surface(ctx.N)
        d = ctx.p - np.array(center)
        fwd = d[:, 1] / r
        s.use_ramp(P["ember"], shade=0.2 + np.clip(fwd, 0, 1) * 1.2 + ctx.fbm(30.0, 2, 5) * 0.8)
        hot = np.zeros(ctx.N, dtype=bool)
        core = np.zeros(ctx.N, dtype=bool)
        for e in eyes:
            de = np.linalg.norm(ctx.p - np.array(e), axis=1)
            hot |= de < r * 0.22
            core |= de < r * 0.1
        s.shade[hot] = np.maximum(s.shade[hot], 5.2)
        s.shade[core] = 7.0
        s.rough = np.full(ctx.N, 0.9)
        s.emit = s.colors() * np.where(hot, 1.0, 0.12)[:, None]
        return s
    return fn


def gold(ctx, seed=1891):
    return A.gilt(ctx, seed, worn=0.35, under="lacquer_black")


def teeth(ctx, seed=1895):
    return A.gilt(ctx, seed, worn=0.1, under="lacquer_black")
