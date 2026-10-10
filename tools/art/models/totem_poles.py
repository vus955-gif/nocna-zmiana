"""Floor I, the totem hall: decor poles in the manner of the Northwest
Coast, each with its own silhouette so the hall never repeats the court's
Haida pole (no spread wings, no rings) nor the Totem enemy: a memorial
pole, a house-frontal pole with an oval doorway, a welcome figure, and the
unfinished pole of the carvers' workshop. Respectful stylisations, not
copies of any pole. Red cedar, painted black, red, blue-green, white.

  totem_pole_memorial  8.6 m: a tall plain shaft dressed with spiral adze
                       flutes, an eagle perched on top with its wings
                       folded, a hooked yellow beak, talons over the rim.
                       2.0 x 8.6 x 1.6 m. 96 px/m.
  totem_pole_house     9.0 m house-frontal pole 1.6 m wide: Bear at the
                       foot (its arms frame an oval doorway 0.8 x 1.5 m
                       through its belly - walkable), Beaver with its
                       incisors and a stick, and the Moon's round face at
                       the top. Flat back. 96 px/m.
  totem_pole_welcome   4.4 m welcome figure: a man carved from one log
                       with a cedar hat, arms raised wide in greeting, on a
                       stump. 96 px/m.
  totem_log            the carvers' unfinished pole: a 6 m log on two
                       trestles, the first figure roughed out with chalk
                       lines, chips on the floor, an adze on top. Lies
                       along X. 6.6 x 1.6 x 1.3 m. 96 px/m.
All: kit convention (origin = centre of the base, front -Z).
"""
import math

import bmesh
import numpy as np
from mathutils import Matrix, Vector

from artlib import americas as AM
from artlib import americas_paint as AP
from artlib import clay
from artlib import court_materials as CM
from artlib import kit as K
from artlib import materials as M
from artlib import sculpt
from artlib.archkit import kit
from artlib.geo import Part
from artlib.materials import P, _dither, _select
from artlib.painter import Surface
from artlib.sculpt import blob, limb


def clay_into(p, blobs, tris, slot, res=0.03, cut=None):
    me = sculpt.metaball_mesh(blobs, resolution=res)
    if cut:
        sculpt.cut(me, cut)
    me = sculpt.decimate(me, tris)
    clay.into_part(p, me, slot)


# --------------------------------------------------------------------------
# paint
# --------------------------------------------------------------------------

def cedar(center=5.0, seed=2501):
    return lambda c: CM.cedar_pole(c, seed, center=center, grey=0.15)


def painted(code, seed=2503, flake=0.25, center=5.0):
    def fn(ctx):
        s = CM.cedar_pole(ctx, seed, center=center, grey=0.1)
        return AM.paint_over(ctx, s, np.full(ctx.N, code, np.int16), seed + 1, flake=flake, wear=0.8)
    return fn


def _ov(a, b, ca, cb, w, h, k=2.6):
    return (np.abs(a - ca) / w) ** k + (np.abs(b - cb) / h) ** k < 1.0


def formline_codes(u, z, on, cw=0.56, ch=0.46, z0=0.0):
    """Paint codes of a formline band: in each cell a black ovoid ring with
    a red core, flanked by black split U-forms with blue-green fills;
    ``u`` = metres across, ``z`` = height, ``on`` = where to paint."""
    codes = np.zeros(len(u), np.int16)
    cu = np.floor(u / cw + 0.5)
    cz = np.floor((z - z0) / ch)
    lu = u - cu * cw
    lz = (z - z0) - (cz + 0.5) * ch
    ring = _ov(lu, lz, 0.0, 0.03, cw * 0.3, ch * 0.28) & ~_ov(lu, lz, 0.0, 0.03, cw * 0.2, ch * 0.18)
    core = _ov(lu, lz, 0.0, 0.03, cw * 0.1, ch * 0.09)
    uf = np.zeros(len(u), bool)
    fill = np.zeros(len(u), bool)
    for s in (-1, 1):
        o = _ov(lu, lz, s * cw * 0.42, -ch * 0.1, cw * 0.1, ch * 0.32, 3.0) & (lz < ch * 0.15)
        i = _ov(lu, lz, s * cw * 0.42, -ch * 0.05, cw * 0.06, ch * 0.24, 3.0)
        uf |= o & ~i
        fill |= i & (lz < ch * 0.1)
    codes[on & fill] = AP.INK["turq"]
    codes[on & uf] = AP.INK["black"]
    codes[on & ring] = AP.INK["black"]
    codes[on & core] = AP.INK["red"]
    return codes


def figure_paint(seed=2581, center=5.0):
    """Carved features painted by height bands of the faces: black brows,
    red lips and nostrils; the rest bare cedar."""
    def fn(ctx):
        s = CM.cedar_pole(ctx, seed, center=center, grey=0.1)
        front = (ctx.n[:, 1] > 0.3) & (np.abs(ctx.p[:, 0]) < 0.36)
        up = ctx.n[:, 2]
        codes = np.zeros(ctx.N, np.int16)
        codes[front & (up > 0.45)] = AP.INK["black"]            # the tops of brows, snouts and arms
        codes[front & (up < -0.45)] = AP.INK["red"]             # under the lips and noses
        return AM.paint_over(ctx, s, codes, seed + 1, flake=0.2, wear=0.6)
    return fn


def wing_paint(ctx, seed=2511):
    """Folded wings: black formline feathers (U-forms in rows) on cedar
    with blue-green fills and a red joint ovoid."""
    s = CM.cedar_pole(ctx, seed, center=4.8, grey=0.1)
    z = ctx.p[:, 2]
    y = ctx.p[:, 1]
    row = np.floor(z / 0.18).astype(np.int64)
    fz = z / 0.18 - row
    fy = np.mod(y / 0.2 + row * 0.5, 1.0)
    u = (np.abs(fy - 0.5) < 0.38) & (fz > 0.15) & ~((np.abs(fy - 0.5) < 0.24) & (fz > 0.35))
    fill = (np.abs(fy - 0.5) < 0.2) & (fz > 0.4) & (fz < 0.85)
    codes = np.where(u, AP.INK["black"], np.where(fill, AP.INK["turq"], 0)).astype(np.int16)
    return AM.paint_over(ctx, s, codes, seed + 1, flake=0.2, wear=0.6)


# --------------------------------------------------------------------------
# memorial pole with an eagle
# --------------------------------------------------------------------------

def memorial():
    p = Part("totem_pole_memorial")
    H = 7.2
    flute = lambda i, j: 1.0 - 0.04 * (math.cos(i * 2 * math.pi / 3 + j * 0.9) > 0.6)
    prof = [(0.36, 0.0), (0.34, 0.3), (0.33, 1.5), (0.31, 4.0), (0.29, 6.5), (0.3, H - 0.05), (0.34, H)]
    p.lathe(prof, "pole", segments=24, cap_bottom=False, cap_top=True, ring_scale=flute)
    p.lathe([(0.0, 0.0), (0.6, 0.0), (0.6, 0.12), (0.5, 0.18), (0.38, 0.2)], "stone", segments=20, cap_bottom=False,
            cap_top=False)
    # the eagle (built facing +Y; kit() turns it to face -Z after)
    z0 = H
    body = [blob((0.0, 0.0, z0 + 0.55), (0.42, 0.36, 0.55)), blob((0.0, 0.12, z0 + 0.95), (0.3, 0.26, 0.28)),
            blob((0.0, -0.2, z0 + 0.25), (0.3, 0.3, 0.28))]
    clay_into(p, body, 1400, "breast")
    head = [blob((0.0, 0.18, z0 + 1.3), (0.24, 0.26, 0.24)), blob((0.0, 0.05, z0 + 1.18), (0.22, 0.2, 0.18))]
    clay_into(p, head, 900, "head")
    beak = limb([(0.0, 0.36, z0 + 1.32), (0.0, 0.6, z0 + 1.3), (0.0, 0.74, z0 + 1.18), (0.0, 0.7, z0 + 1.06)],
                [0.11, 0.08, 0.045, 0.02], spacing=0.6, squash=0.8)
    clay_into(p, beak, 500, "beak")
    for sx in (-1, 1):
        wing = [blob((sx * 0.4, -0.05, z0 + 0.7), (0.12, 0.42, 0.55), rot=(-12.0, 0.0, sx * 6.0)),
                blob((sx * 0.36, -0.35, z0 + 0.25), (0.1, 0.3, 0.35), rot=(25.0, 0.0, 0.0))]
        clay_into(p, wing, 700, "wing")
        talon = limb([(sx * 0.16, 0.18, z0 + 0.12), (sx * 0.18, 0.36, z0 + 0.02), (sx * 0.18, 0.4, z0 - 0.14)],
                     [0.07, 0.05, 0.03], spacing=0.6)
        clay_into(p, talon, 250, "beak")
        K.sphere(p, (sx * 0.17, 0.36, z0 + 1.37), 0.06, "eye", segments=10, rings=5, squash=(0.5, 1.0))
    return p


# --------------------------------------------------------------------------
# house-frontal pole with an oval doorway
# --------------------------------------------------------------------------

def slab_with_door(p, W, H, D, dw, dh, dz, slot, n=28):
    """A slab W x H x D (front at -Y... built facing +Y here: front +Y)
    with an oval doorway dw x dh whose bottom is at dz: front and back
    annuli, the outer sides, the doorway's tunnel."""
    cx, cz = 0.0, dz + dh / 2
    inner = [(cx + dw / 2 * math.cos(a), cz + dh / 2 * math.sin(a)) for a in np.linspace(0, 2 * math.pi, n, endpoint=False)]
    outer = []
    for a in np.linspace(0, 2 * math.pi, n, endpoint=False):
        dx, dzz = math.cos(a), math.sin(a)
        # where the ray from the door centre meets the slab outline
        tx = (W / 2) / abs(dx) if abs(dx) > 1e-6 else 1e9
        tz = ((H - cz) if dzz > 0 else cz) / abs(dzz) if abs(dzz) > 1e-6 else 1e9
        t = min(tx, tz)
        outer.append((cx + dx * t, cz + dzz * t))
    for y, sgn in ((D / 2, 1), (-D / 2, -1)):
        vo = [p.bm.verts.new((x, y, z)) for x, z in outer]
        vi = [p.bm.verts.new((x, y, z)) for x, z in inner]
        for i in range(n):
            i2 = (i + 1) % n
            f = p._face([vo[i], vo[i2], vi[i2], vi[i]], slot)
            f.normal_update()
            if f.normal.y * sgn < 0:
                f.normal_flip()
    # outer sides as a box shell (without front/back), and the tunnel
    for x0, x1, z0, z1, nrm in ((-W / 2, -W / 2, 0, H, (-1, 0, 0)), (W / 2, W / 2, 0, H, (1, 0, 0))):
        f = p.poly([(x0, -D / 2, z0), (x0, D / 2, z0), (x0, D / 2, z1), (x0, -D / 2, z1)], slot)[0]
        f.normal_update()
        if f.normal.dot(Vector(nrm)) < 0:
            f.normal_flip()
    f = p.poly([(-W / 2, -D / 2, H), (W / 2, -D / 2, H), (W / 2, D / 2, H), (-W / 2, D / 2, H)], slot)[0]
    f.normal_update()
    if f.normal.z < 0:
        f.normal_flip()
    for i in range(n):
        i2 = (i + 1) % n
        a = [p.bm.verts.new((inner[i][0], y, inner[i][1])) for y in (-D / 2, D / 2)]
        b = [p.bm.verts.new((inner[i2][0], y, inner[i2][1])) for y in (-D / 2, D / 2)]
        f = p._face([a[0], b[0], b[1], a[1]], "door")
        f.normal_update()
        c = f.calc_center_median()
        if f.normal.dot(Vector((cx - c.x, 0.0, cz - c.z))) < 0:
            f.normal_flip()


def house():
    p = Part("totem_pole_house")
    W, D = 1.6, 0.6
    slab_with_door(p, W, 3.0, D, 0.8, 1.5, 0.12, "pole")
    p.box((0.0, 0.0, 6.0), (W, D, 6.0), "pole", bevel=0.04)
    yf = D / 2
    # Bear: head over the door, arms round it, feet at its sides
    clay_into(p, [blob((0.0, yf + 0.05, 2.35), (0.52, 0.22, 0.42)), blob((0.0, yf + 0.25, 2.2), (0.24, 0.18, 0.16)),
                  blob((0.0, yf + 0.4, 2.25), (0.11, 0.06, 0.07)),
                  blob((0.0, yf + 0.3, 2.04), (0.26, 0.08, 0.05)),
                  blob((0.0, yf + 0.34, 2.04), (0.18, 0.06, 0.02), neg=True, stiff=1.4)]
              + [blob((sx * 0.48, yf - 0.05, 2.75), (0.14, 0.08, 0.13)) for sx in (-1, 1)], 1500, "figure")
    for sx in (-1, 1):
        clay_into(p, limb([(sx * 0.62, yf, 1.95), (sx * 0.62, yf + 0.12, 1.3), (sx * 0.5, yf + 0.14, 0.8)],
                          [0.16, 0.13, 0.12], spacing=0.6), 500, "figure")
        clay_into(p, [blob((sx * 0.55, yf + 0.12, 0.25), (0.2, 0.16, 0.14))], 200, "figure")
        K.sphere(p, (sx * 0.2, yf + 0.18, 2.48), 0.07, "eye", segments=10, rings=5, squash=(1.0, 0.5))
    # Beaver: head, incisors, a stick held across
    clay_into(p, [blob((0.0, yf + 0.04, 4.6), (0.48, 0.18, 0.4)), blob((0.0, yf + 0.2, 4.45), (0.26, 0.14, 0.15)),
                  blob((0.0, yf + 0.32, 4.5), (0.08, 0.05, 0.05))]
              + [blob((sx * 0.4, yf - 0.05, 4.98), (0.11, 0.07, 0.1)) for sx in (-1, 1)], 1200, "figure")
    for sx in (-1, 1):
        p.box((sx * 0.045, yf + 0.33, 4.25), (0.08, 0.05, 0.16), "tooth", bevel=0.01)
        K.sphere(p, (sx * 0.2, yf + 0.16, 4.75), 0.065, "eye", segments=10, rings=5, squash=(1.0, 0.5))
        clay_into(p, limb([(sx * 0.62, yf, 4.15), (sx * 0.5, yf + 0.15, 3.8), (sx * 0.2, yf + 0.25, 3.75)],
                          [0.13, 0.11, 0.1], spacing=0.6), 400, "figure")
    p.tube([(-0.7, yf + 0.33, 3.72), (0.7, yf + 0.36, 3.86)], 0.06, "stick", sides=8)
    # the Moon at the top: a round face in a raised ring
    moon = p.lathe([(0.0, 0.0), (0.66, 0.0), (0.7, 0.06), (0.62, 0.12), (0.52, 0.12), (0.5, 0.16), (0.0, 0.2)],
                   "moon", segments=28)
    p.move(moon, Matrix.Translation(Vector((0.0, yf, 7.7))) @ Matrix.Rotation(math.radians(-90), 4, 'X'))
    clay_into(p, [blob((0.0, yf + 0.25, 7.65), (0.07, 0.07, 0.14)), blob((0.0, yf + 0.22, 7.38), (0.16, 0.05, 0.05)),
                  blob((0.0, yf + 0.25, 7.38), (0.1, 0.04, 0.015), neg=True, stiff=1.4)]
              + [blob((sx * 0.24, yf + 0.18, 7.86), (0.16, 0.05, 0.04)) for sx in (-1, 1)], 600, "moonface")
    for sx in (-1, 1):
        K.sphere(p, (sx * 0.2, yf + 0.2, 7.74), 0.06, "eye", segments=10, rings=5, squash=(1.0, 0.5))
    p.box((0.0, 0.0, 9.02), (W + 0.1, D + 0.1, 0.06), "pole", bevel=0.01)
    return p


def house_paint(ctx, seed=2521):
    """The slab: cedar with the Beaver's cross-hatched tail painted below it,
    the Bear's claws, formline frames on the sides."""
    s = CM.cedar_pole(ctx, seed, center=5.0, grey=0.15)
    x, z = ctx.p[:, 0], ctx.p[:, 2]
    front = ctx.n[:, 1] > 0.5           # the carved face looks +Y (Godot -Z)
    codes = np.zeros(ctx.N, np.int16)
    side = front & (np.abs(x) > 0.5)
    codes = formline_codes(x, z, side & (z > 0.1), cw=0.3, ch=0.42, z0=0.1)
    upper = front & (z > 5.2) & (z < 6.9)
    codes = np.where(upper, formline_codes(x, z, upper, cw=0.52, ch=0.56, z0=5.2), codes)
    tail = front & (np.abs(x) < 0.45) & (z > 3.2) & (z < 3.65)
    hatch = tail & ((np.mod((x + z) / 0.08, 1.0) < 0.2) | (np.mod((x - z) / 0.08, 1.0) < 0.2))
    codes[tail] = AP.INK["turq"]
    codes[hatch] = AP.INK["black"]
    frame = front & ((np.abs(np.abs(x) - 0.74) < 0.03) & (z > 3.0))
    codes[frame] = AP.INK["red"]
    band = front & (np.abs(z - 6.2) < 0.06)
    codes[band] = AP.INK["black"]
    return AM.paint_over(ctx, s, codes, seed + 1, flake=0.2, wear=0.6)


# --------------------------------------------------------------------------
# welcome figure
# --------------------------------------------------------------------------

def welcome():
    p = Part("totem_pole_welcome")
    prof = [(0.38, 0.0), (0.4, 0.4), (0.36, 0.9), (0.34, 1.4), (0.36, 2.0), (0.38, 2.6), (0.34, 2.95), (0.3, 3.1)]
    p.lathe(prof, "pole", segments=20, cap_bottom=False, cap_top=False)
    p.lathe([(0.0, 0.0), (0.55, 0.0), (0.55, 0.2), (0.4, 0.26)], "stone", segments=20, cap_bottom=False, cap_top=False)
    clay_into(p, [blob((0.0, 0.0, 3.4), (0.33, 0.3, 0.4)), blob((0.0, 0.28, 3.38), (0.07, 0.1, 0.14)),
                  blob((0.0, 0.26, 3.12), (0.16, 0.07, 0.055)),
                  blob((0.0, 0.31, 3.12), (0.11, 0.05, 0.018), neg=True, stiff=1.4),
                  blob((0.0, 0.2, 2.98), (0.14, 0.08, 0.07))]
              + [blob((sx * 0.14, 0.25, 3.56), (0.13, 0.06, 0.04)) for sx in (-1, 1)]
              + [blob((sx * 0.31, 0.02, 3.4), (0.06, 0.08, 0.12)) for sx in (-1, 1)]
              + [blob((sx * 0.2, 0.24, 3.24), (0.09, 0.06, 0.08)) for sx in (-1, 1)], 1400, "face")
    # cedar hat
    p.lathe([(0.0, 0.0), (0.56, 0.0), (0.56, 0.05), (0.32, 0.18), (0.2, 0.34), (0.1, 0.4), (0.0, 0.42)], "hat",
            segments=20, center=(0.0, 0.0, 3.68))
    for sx in (-1, 1):
        K.sphere(p, (sx * 0.12, 0.27, 3.45), 0.05, "eye", segments=10, rings=5, squash=(1.0, 0.5))
        # arms raised wide, palms up
        clay_into(p, limb([(sx * 0.3, 0.0, 2.85), (sx * 0.72, 0.12, 3.02), (sx * 1.02, 0.22, 3.42)], [0.17, 0.14, 0.12],
                          spacing=0.6), 600, "face")
        clay_into(p, [blob((sx * 1.1, 0.28, 3.55), (0.1, 0.1, 0.16), rot=(0.0, sx * -25.0, 0.0))], 200, "face")
        # feet carved at the foot of the log
        clay_into(p, [blob((sx * 0.16, 0.36, 0.32), (0.11, 0.15, 0.08))], 150, "pole")
    return p


# --------------------------------------------------------------------------
# the unfinished log
# --------------------------------------------------------------------------

def log():
    p = Part("totem_log")
    # the log along X, its axis 0.95 m up
    zc = 0.95
    faces = p.lathe([(0.42, -3.0), (0.44, -1.0), (0.42, 1.2), (0.4, 3.0)], "log", segments=16, cap_bottom=True,
                    cap_top=True)
    p.move(faces, Matrix.Translation(Vector((0.0, 0.0, zc))) @ Matrix.Rotation(math.radians(90), 4, 'Y'))
    # roughed-out face at the +X end
    clay_into(p, [blob((2.2, 0.0, zc + 0.36), (0.42, 0.3, 0.12)), blob((2.3, 0.0, zc + 0.44), (0.1, 0.08, 0.1)),
                  blob((2.05, 0.0, zc + 0.36), (0.15, 0.22, 0.08), neg=True, stiff=1.4)]
              + [blob((2.5, sx * 0.14, zc + 0.36), (0.1, 0.07, 0.06), neg=True, stiff=1.4) for sx in (-1, 1)], 800, "log",
              res=0.025)
    # two trestles
    for x in (-1.8, 1.2):
        for sy in (-1, 1):
            p.tube([(x - 0.3, sy * 0.5, 0.0), (x, sy * 0.1, 0.58)], 0.05, "trestle", sides=6)
            p.tube([(x + 0.3, sy * 0.5, 0.0), (x, sy * 0.1, 0.58)], 0.05, "trestle", sides=6)
        p.box((x, 0.0, 0.56), (0.16, 0.8, 0.12), "trestle", bevel=0.01)
    # chips on the floor
    rng = np.random.default_rng(7)
    for k in range(26):
        x, y = rng.uniform(-2.4, 2.8), rng.uniform(-0.7, 0.7)
        if abs(y) < 0.2 and abs(x) < 2.5:
            y += 0.4 * np.sign(y + 1e-3)
        p.box((x, y, 0.01), (rng.uniform(0.06, 0.14), rng.uniform(0.03, 0.06), 0.02), "chip", bevel=0.004,
              rot=Matrix.Rotation(rng.uniform(0, math.pi), 3, 'Z'))
    # an adze on the log
    p.tube([(0.4, -0.1, zc + 0.43), (0.9, 0.05, zc + 0.43)], 0.022, "trestle", sides=6)
    p.box((0.92, 0.07, zc + 0.43), (0.06, 0.05, 0.14), "iron", bevel=0.006)
    return p


def welcome_paint(ctx, seed=2587):
    """The welcome figure's body: bare cedar arms, a painted blanket over
    the chest and down the body - formline cells in a border."""
    s = CM.cedar_pole(ctx, seed, center=5.0, grey=0.1)
    x, y, z = ctx.p[:, 0], ctx.p[:, 1], ctx.p[:, 2]
    a = np.arctan2(x, y)
    u = a * 0.36
    body = (np.abs(a) < 1.3) & (z > 0.5) & (z < 2.75) & (np.hypot(x, y) < 0.45)
    codes = formline_codes(u, z, body & (z > 1.1) & (z < 2.5), cw=0.34, ch=0.4, z0=1.1)
    border = body & ((np.abs(z - 2.6) < 0.06) | (np.abs(z - 1.0) < 0.06) | (np.abs(np.abs(a) - 1.2) < 0.06))
    codes[border] = AP.INK["red"]
    return AM.paint_over(ctx, s, codes, seed + 1, flake=0.2, wear=0.6)


def log_paint(ctx, seed=2531):
    """Fresh-cut cedar (pale, the bark stripped in strips), chalk lines on
    the roughed-out face."""
    s = CM.cedar(ctx, seed, center=6.0, grey=0.0)
    x = ctx.p[:, 0]
    bark = (x < 1.6) & (ctx.fbm(np.array([0.4, 3.0, 3.0]), 3, seed + 1) > 0.25)
    s.use_ramp(CM.P["cedar"], mask=bark, shade=np.full(ctx.N, 2.4) + ctx.fbm(20.0, 2, seed + 2) * 1.0)
    chalk = (x > 1.7) & (np.abs(np.mod((x - 1.7) / 0.35, 1.0) - 0.5) < 0.04)
    s.use_ramp(P["am_shell"], mask=chalk, shade=np.full(ctx.N, 6.0))
    return s


def build():
    out = []
    out.append(kit("totem_pole_memorial", [memorial()],
                   {"pole": cedar(5.2), "stone": lambda c: AM.volcanic(c, 2541, center=4.2),
                    "breast": painted(AP.INK["black"], 2543, 0.3, 4.8), "head": painted(AP.INK["white"], 2545, 0.25),
                    "beak": painted(AP.INK["ochre"], 2547, 0.2), "wing": wing_paint,
                    "eye": lambda c: AM.obsidian(c, 2549)},
                   ppm=96, built_final=True, ground=0.0, ao_dist=0.4,
                   preview_yaws=(-30.0, 20.0, 90.0, 180.0), preview_elevation=6.0,
                   preview_extra=[("eagle", (0.0, 0.0, 8.0), 1.4, 20.0, 8.0)]))
    out.append(kit("totem_pole_house", [house()],
                   {"pole": house_paint, "door": cedar(3.6), "figure": figure_paint(2583),
                    "tooth": painted(AP.INK["white"], 2551, 0.1), "stick": cedar(4.2),
                    "eye": lambda c: AM.obsidian(c, 2553), "moon": painted(AP.INK["turq"], 2555, 0.25),
                    "moonface": painted(AP.INK["white"], 2557, 0.2)},
                   ppm=96, built_final=True, ground=0.0, ao_dist=0.4,
                   preview_yaws=(-30.0, 0.0, 30.0, 150.0), preview_elevation=6.0,
                   preview_extra=[("door", (0.0, 0.3, 1.6), 1.6, 15.0, 5.0)]))
    out.append(kit("totem_pole_welcome", [welcome()],
                   {"pole": welcome_paint, "stone": lambda c: AM.volcanic(c, 2561, center=4.2),
                    "face": figure_paint(2585, 5.4),
                    "hat": lambda c: AM.paint_over(c, AM.am_woven_mat(c, 2563), np.where(np.mod(c.p[:, 2], 0.2) < 0.06,
                                                   AP.INK["black"], 0).astype(np.int16), 2565, flake=0.2),
                    "eye": lambda c: AM.obsidian(c, 2567)},
                   ppm=96, built_final=True, ground=0.0, ao_dist=0.4, preview_yaws=(-30.0, 0.0, 30.0, 150.0),
                   preview_elevation=8.0))
    out.append(kit("totem_log", [log()],
                   {"log": log_paint, "trestle": lambda c: AM.carved_wood(c, 2571, "am_wood", 4.6, adze=0.2),
                    "chip": lambda c: CM.cedar(c, 2573, center=6.4), "iron": lambda c: AM.iron_old(c, 2575)},
                   ppm=96, built_final=True, ground=0.0, ao_dist=0.3, preview_yaws=(-40.0, 30.0, 140.0, 220.0),
                   preview_elevation=22.0))
    return out
