"""Floor I, the North America hall: a plains bison bull, an old museum
mount (taxidermy) standing on its basalt plinth. The heavy, shaggy
forequarters and the hump, the head carried low under a thick bonnet of
hair with a long beard, short black horns curving up and in, the "chaps"
of long hair on the forelegs; the hindquarters lean and short-coated, a
thin tail with a tuft; dark glass eyes, a wet-black nose; black hooves.
The pelt is a museum's: dusty, a little moth-eaten here and there.

Kit convention (built front +Y in Blender = Godot -Z): origin = the middle
of its footprint on the plinth top, the head forward (-Z). One part:
  bison   the whole mount (fur, horns, eyes, hooves). 0.98 x 1.88 x 2.94 m
          (Godot x, y, z), inside the greybox bison box 1.5 x 1.9 x 3.0.
256 px/m (the halls' hero exhibits: the jaguar, the wolf).
"""
import math
import random

import bmesh
import bpy
import numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree

from artlib import kit as K
from artlib import materials as M
from artlib import sculpt
from artlib.archkit import kit
from artlib.geo import Part
from artlib.materials import P, _dither, hexramp, smoothstep
from artlib.sculpt import blob, limb

P.update({
    # the long winter shag of the forequarters, the head and the beard
    "bison_shag": hexramp("#0b0705", "#130c08", "#1c120b", "#26180f", "#311f13", "#3d2717", "#4a301c",
                          "#583a22", "#674529"),
    # the shorter, lighter coat of the back half (sun-faded on the ridge)
    "bison_coat": hexramp("#1a100a", "#26180e", "#332013", "#422a18", "#52351e", "#634125", "#744e2d",
                          "#865c36", "#986b40"),
    "bison_horn": hexramp("#050505", "#0b0a09", "#121110", "#1b1917", "#25221f", "#302c28", "#3d3833",
                          "#4d4740"),
    "bison_eye": hexramp("#060403", "#140b06", "#24130a", "#36200f", "#4a2d15", "#5e3b1c"),
})

# --- the mount's skeleton (Blender: x across, y forward, z up) ---------------
FRONT_Y = 0.5          # front legs
HIND_Y = -0.92         # hind legs
EYES = [(-0.17, 1.23, 0.84), (0.17, 1.23, 0.84)]
NOSE = (0.0, 1.46, 0.5)
HOOF_H = 0.11
FEET = {(-1, "f"): (-0.2, FRONT_Y + 0.06), (1, "f"): (0.2, FRONT_Y + 0.06),
        (-1, "h"): (-0.19, HIND_Y + 0.02), (1, "h"): (0.19, HIND_Y + 0.02)}


def _body_blobs():
    b = [
        blob((0.0, -0.15, 1.06), (0.39, 0.72, 0.39)),        # barrel
        blob((0.0, 0.4, 1.07), (0.43, 0.46, 0.5)),           # chest and shoulders
        blob((0.0, 0.3, 1.46), (0.3, 0.52, 0.36)),           # the hump
        blob((0.0, 0.55, 1.42), (0.27, 0.32, 0.32)),         # the hump's front rise
        blob((0.0, -0.32, 1.3), (0.27, 0.45, 0.2)),          # the back sloping down
        blob((0.0, 0.74, 1.18), (0.33, 0.3, 0.4)),           # withers into the neck
        blob((0.0, -0.84, 1.09), (0.33, 0.38, 0.31)),        # hindquarters
        blob((0.0, -1.06, 1.13), (0.27, 0.25, 0.24)),        # rump
        blob((0.0, -0.18, 0.82), (0.33, 0.56, 0.22)),        # belly
        blob((0.0, 0.62, 0.8), (0.27, 0.24, 0.26)),          # brisket
        blob((0.0, 0.9, 0.98), (0.3, 0.25, 0.38)),           # neck
    ]
    for sx in (-1, 1):
        b.append(blob((sx * 0.2, -0.86, 0.86), (0.16, 0.28, 0.3)))    # thighs
        b.append(blob((sx * 0.24, 0.44, 0.96), (0.2, 0.3, 0.35)))     # shoulders
    return b


def _head_blobs():
    b = [
        blob((0.0, 1.08, 0.92), (0.26, 0.24, 0.3)),           # the massive head under its bonnet
        blob((0.0, 1.06, 1.14), (0.25, 0.19, 0.15)),          # the crown's mop of hair
        blob((0.0, 1.24, 0.72), (0.18, 0.2, 0.24)),           # the face, long and low
        blob((0.0, 1.35, 0.55), (0.15, 0.14, 0.15)),          # the muzzle
        blob((0.0, 1.42, 0.5), (0.12, 0.08, 0.1)),            # the nose pad
        blob((0.0, 1.12, 0.48), (0.12, 0.15, 0.27)),          # the beard
        blob((0.0, 1.02, 0.58), (0.15, 0.14, 0.22)),          # the throat's fringe
    ]
    for sx in (-1, 1):
        b.append(blob((sx * 0.16, 1.16, 0.78), (0.1, 0.14, 0.15)))     # cheeks
        b.append(blob((sx * 0.26, 1.0, 0.98), (0.07, 0.06, 0.05)))     # ears in the hair
    return b


def _leg_blobs():
    b = []
    for sx in (-1, 1):
        fx, fy = FEET[(sx, "f")]
        b += limb([(sx * 0.24, FRONT_Y, 0.92), (sx * 0.23, FRONT_Y - 0.02, 0.62), (sx * 0.21, fy, 0.36),
                   (fx, fy, HOOF_H + 0.02)], [0.18, 0.135, 0.095, 0.074], spacing=0.6)
        b.append(blob((sx * 0.25, FRONT_Y - 0.02, 0.64), (0.16, 0.18, 0.22)))   # the chaps of long hair
        b.append(blob((sx * 0.24, FRONT_Y - 0.03, 0.46), (0.13, 0.14, 0.15)))
        hx, hy = FEET[(sx, "h")]
        b += limb([(sx * 0.21, HIND_Y + 0.04, 0.95), (sx * 0.23, HIND_Y + 0.2, 0.64), (sx * 0.19, HIND_Y - 0.1, 0.42),
                   (hx, hy, HOOF_H + 0.02)], [0.21, 0.145, 0.082, 0.068], spacing=0.6)
    b += limb([(0.0, -1.27, 1.2), (0.0, -1.36, 1.0), (0.0, -1.39, 0.74)], [0.05, 0.035, 0.03], spacing=0.6)
    b.append(blob((0.0, -1.4, 0.63), (0.055, 0.05, 0.12)))          # the tail's tuft
    return b


def _shag_blobs(seed=4207):
    """The long hair as locks hanging off the cape: a ragged hem round the
    forequarters at the elbows and down the brisket, locks over the hump's
    flanks and the neck, the bonnet's fringe over the face; long and
    pointing down (hair falls), so the decimated clay keeps a shaggy
    outline without turning into bubbles."""
    rnd = random.Random(seed)
    out = []

    def lock(c, r, length, lean=(0.0, 0.0)):
        out.append(blob(c, (r, r * rnd.uniform(0.9, 1.2), length), rot=(lean[0], lean[1], 0.0), stiff=1.4))

    # the hem of the cape: round the chest from shoulder to shoulder, low
    for k in range(22):
        t = k / 21.0
        a = math.pi * (0.12 + 0.76 * t)              # from one side round the front to the other
        x = math.cos(a) * 0.43
        y = 0.38 + math.sin(a) * 0.36
        lock((x * rnd.uniform(0.92, 1.0), y, 0.66 + rnd.uniform(-0.04, 0.05)), rnd.uniform(0.06, 0.085),
             rnd.uniform(0.13, 0.2), (rnd.uniform(-8, 8), math.degrees(-x) * 0.3))
    # the sides of the cape behind the shoulders (the hair line, ragged)
    for sx in (-1, 1):
        for k in range(7):
            y = 0.08 + k * 0.07 + rnd.uniform(-0.02, 0.02)
            z = 0.78 + rnd.uniform(0.0, 0.5)
            lock((sx * (0.39 + rnd.uniform(-0.02, 0.02)), y, z), rnd.uniform(0.06, 0.08), rnd.uniform(0.12, 0.18),
                 (rnd.uniform(-10, 10), sx * 6.0))
    # the hump's flanks and the neck: flatter locks lying on the hair
    for k in range(26):
        a = rnd.uniform(-1.2, 1.2)
        y = rnd.uniform(0.1, 0.95)
        z = 1.2 + 0.5 * math.cos(a) * (1.0 - abs(y - 0.4) * 0.6)
        x = math.sin(a) * (0.3 + 0.08 * (1.0 - abs(a)))
        lock((x, y, z - 0.05), rnd.uniform(0.07, 0.1), rnd.uniform(0.1, 0.15), (rnd.uniform(-15, 15), math.degrees(a) * 0.5))
    # the bonnet's fringe falling over the brow and the beard's locks
    for k in range(9):
        x = -0.2 + 0.4 * k / 8.0
        lock((x, 1.2 + rnd.uniform(-0.02, 0.03), 0.98 + rnd.uniform(-0.03, 0.03)), rnd.uniform(0.05, 0.07),
             rnd.uniform(0.08, 0.12), (-20.0, 0.0))
    for k in range(7):
        lock((rnd.uniform(-0.09, 0.09), 1.12 + rnd.uniform(-0.06, 0.06), 0.36 + rnd.uniform(0.0, 0.08)),
             rnd.uniform(0.04, 0.06), rnd.uniform(0.1, 0.16))
    return out


def _surface(me, origin, direction):
    """The first point of mesh ``me`` met by a ray (None if it misses)."""
    bm = bmesh.new()
    bm.from_mesh(me)
    tree = BVHTree.FromBMesh(bm)
    hit = tree.ray_cast(Vector(origin), Vector(direction).normalized())
    bm.free()
    return hit[0]


def mount():
    p = Part("bison")
    blobs = _body_blobs() + _head_blobs() + _leg_blobs() + _shag_blobs()
    me = sculpt.metaball_mesh(blobs, resolution=0.022)
    # the hooves stand on the plinth: the clay stops at their tops
    sculpt.cut(me, [((0.0, 0.0, HOOF_H + 0.005), (0.0, 0.0, -1.0))])
    me = sculpt.decimate(me, 4300)
    sculpt.into_part(p, me, "fur")
    # glass eyes set into the face (found on the clay, a hair under it)
    for (ex, ey, ez), sx in zip(EYES, (-1, 1)):
        hit = _surface(me, (sx * 0.6, ey + 0.05, ez), (-sx, -0.1, 0.0))
        c = (hit - Vector((sx * 0.006, 0.0, 0.0))) if hit is not None else Vector((ex, ey, ez))
        EYES[0 if sx < 0 else 1] = tuple(c)
        K.sphere(p, tuple(c), 0.022, "eye", segments=10, rings=6)
    # horns: from inside the bonnet out to the side, up and curling in
    for sx in (-1, 1):
        pts = [(sx * 0.17, 1.08, 1.0), (sx * 0.3, 1.08, 1.02), (sx * 0.39, 1.1, 1.08), (sx * 0.43, 1.12, 1.17),
               (sx * 0.41, 1.13, 1.26), (sx * 0.35, 1.12, 1.32)]
        p.tube(pts, lambda t: 0.06 * (1.0 - t) + 0.011, "horn", sides=8)
    # hooves: cloven, a little splayed
    for (sx, end), (x, y) in FEET.items():
        for half in (-1, 1):
            p.lathe([(0.042, 0.0), (0.04, 0.05), (0.032, HOOF_H)], "hoof", segments=7,
                    center=(x + half * 0.03, y + 0.01, 0.0), squash=(0.85, 1.25), cap_bottom=False)
    return p


# --------------------------------------------------------------------------
# paint
# --------------------------------------------------------------------------

def _shag_mask(ctx):
    """Where the long dark winter hair grows: the forequarters and the hump
    (a ragged line behind the shoulders), the head, the beard, the chaps."""
    x, y, z = ctx.p[:, 0], ctx.p[:, 1], ctx.p[:, 2]
    wob = ctx.fbm(5.0, 3, 4211) * 0.16 + ctx.fbm(16.0, 2, 4213) * 0.06
    line = 0.0 - 0.18 * smoothstep(0.9, 1.5, z) + wob      # the hump's hair reaches a little further back
    shag = y > line
    shag &= ~((z < 0.42) & (np.abs(y - FRONT_Y) < 0.25))   # the lower forelegs are short-haired
    return shag


def fur(ctx):
    x, y, z = ctx.p[:, 0], ctx.p[:, 1], ctx.p[:, 2]
    flow = np.tile([0.0, -1.0, -0.45], (ctx.N, 1))
    head = y > 0.98
    flow[head] = (0.0, 0.35, -1.0)
    legs = z < 0.7
    flow[legs & ~head] = (0.0, -0.1, -1.0)
    tail = y < -1.25
    flow[tail] = (0.0, -0.2, -1.0)
    shag = _shag_mask(ctx)
    coat = M.fur(ctx, seed=4221, flow=flow, center=4.5, ramp="bison_coat", moth=0.35)
    # sun-faded along the ridge of the back, darker underneath and down the legs
    up = ctx.n[:, 2]
    coat.shade += smoothstep(0.3, 0.9, up) * 0.9 - smoothstep(0.0, -0.8, up) * 0.8 - (z < 0.55) * 1.2
    long = M.fur(ctx.subset(shag), seed=4231, flow=flow[shag], center=4.6, ramp="bison_shag", moth=0.0)
    # clumped: deeper hollows between the locks
    long.shade += M._streaks(ctx.subset(shag), flow[shag], 3.0, 9.0, 2, 4233) * 1.4
    coat.merge(long, shag)
    # the wet black nose and lips
    d = np.linalg.norm(ctx.p - np.array(NOSE), axis=1)
    nose = (d < 0.1) & (y > 1.38)
    coat.use_ramp(P["bison_horn"], mask=nose, shade=2.2 + ctx.fbm(60.0, 2, 4241) * 1.2
                  + np.clip(ctx.curv, 0, 1) * 2.0 + _dither(ctx, 0.5, 4243))
    coat.rough = np.where(nose, 0.3, coat.rough)
    # dark rings round the eyes
    for ex, ey, ez in EYES:
        de = np.sqrt((x - ex) ** 2 + (y - ey) ** 2 + (z - ez) ** 2)
        coat.shade[(de > 0.02) & (de < 0.04)] -= 1.6
    return coat


def horn(ctx):
    s = M.Surface(ctx.N)
    t = np.clip((np.abs(ctx.p[:, 0]) - 0.2) / 0.2, 0, 1)
    rings = np.sin(t * 40.0 + ctx.fbm(20.0, 2, 4251) * 2.0) > 0.7
    shade = 2.4 + t * 1.6 + ctx.fbm(14.0, 2, 4253) * 0.6 - rings.astype(np.float64) * (1.0 - t) * 1.0 + ctx.edge_soft(2.0) * 0.6
    shade -= (1.0 - ctx.ao) * 2.0
    s.use_ramp(P["bison_horn"], shade=shade)
    s.rough = 0.42 - t * 0.12
    s.height = -rings.astype(np.float64) * (1.0 - t) * 0.0006
    return s


def hoof(ctx):
    s = M.Surface(ctx.N)
    shade = 1.8 + ctx.fbm(30.0, 2, 4261) * 0.7 + (ctx.p[:, 2] > HOOF_H - 0.03) * 0.6 + _dither(ctx, 0.5, 4263)
    s.use_ramp(P["bison_horn"], shade=shade - (1.0 - ctx.ao) * 1.5)
    s.rough = np.full(ctx.N, 0.55)
    return s


def eye(ctx):
    left = (ctx.p[:, 0] < 0)[:, None]
    a = M.glass_eye(ctx, EYES[0], (-0.75, 0.6, 0.05), iris=0.017, pupil=0.008, ramp="bison_eye", glow=0.2)
    b = M.glass_eye(ctx, EYES[1], (0.75, 0.6, 0.05), iris=0.017, pupil=0.008, ramp="bison_eye", glow=0.2)
    s = M.Surface(ctx.N)
    s.albedo = np.where(left, a.colors(), b.colors())
    s.rough = a.rough
    s.emit = np.where(left, a.emit, b.emit)
    return s


def build():
    return kit("bison", [mount()], {"fur": fur, "horn": horn, "hoof": hoof, "eye": eye},
               ppm=256, built_final=True, ground=0.0, organic=("bison",), ao_dist=0.25, ao_rays=10, ao_stride=2,
               preview_yaws=(-50.0, 30.0, 120.0, 210.0), preview_elevation=8.0)
