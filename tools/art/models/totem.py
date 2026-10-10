"""Floor I, Americas wing enemy: the Totem - a carved and painted cedar
pole of five stacked faces, each a turret that spits a splinter (its eyes
light up before it fires) and a weak point; the faces are shot off from
the top and the pole shortens. Stylised in the manner of Northwest Coast
carving but unlike the court's Haida pole: no wings, no rings, a brighter
painted palette (white, black, red, green and yellow) on warm red cedar.

From the foot: Bear (a broad snout, round ears, a tongue between bared
teeth), Frog (bulging eyes on top, a wide mouth), Wolf (a long snout with
an open jaw and pointed ears), the Ancestor (a human face, heavy brows, an
open mouth), Eagle (a great hooked beak); a woven cedar hat on top.

Godot axes, front -Z, origin = centre of the foot on the floor. 192 px/m.
Parts and pivots (each pivot at the BOTTOM centre of its part):
  totem        the stump with its stone collar, 0.35 m. Root.
  block_1..5   the carved faces, 0.85 m each: block_1 at y 0.35, block_k
               at 0.35 + 0.85 (k - 1); a chain - block_k is the child of
               block_k-1 (block_1 of totem), so hiding a block hides
               every block above it, and a block can be dropped onto the
               one below by moving its child down 0.85.
  eyes_1..5    the inlaid eyes of each face (child of block_k): drive the
               telegraph on this part only (glow), they are lit from
               the atlas's emission.
  cap          the woven hat, 0.5 m, child of totem with its pivot at the
               top of face_5 (y 4.6): set cap.position.y = 0.35 + 0.85 * n
               when n faces remain (or let it fall with the top face).
Markers (children of block_k): face_k = the centre of the face on its
surface (hit centre, about its eyes), mouth_k = just in front of the
mouth (projectile origin, aim along -Z of the face).
"""
import math

import numpy as np
from mathutils import Matrix, Vector

from artlib import clay
from artlib import americas as AM
from artlib import americas_paint as AP
from artlib import kit as K
from artlib import materials as M
from artlib import sculpt
from artlib.geo import Part
from artlib.materials import P, _dither, _select
from artlib.model import Model
from artlib.painter import Surface
from artlib.sculpt import blob, limb

R = 0.42
BASE = 0.35
H = 0.85
NAMES = ["bear", "frog", "wolf", "ancestor", "eagle"]
# (eye centre (x, z local), eye radius, mouth (y, z local)) per face
EYES = {"bear": (0.15, 0.56, 0.07), "frog": (0.17, 0.63, 0.075), "wolf": (0.14, 0.58, 0.065),
        "ancestor": (0.13, 0.55, 0.065), "eagle": (0.17, 0.6, 0.07)}
MOUTH = {"bear": (R + 0.16, 0.2), "frog": (R + 0.1, 0.3), "wolf": (R + 0.28, 0.3), "ancestor": (R + 0.12, 0.24),
         "eagle": (R + 0.26, 0.24)}


def z0(k):
    return BASE + H * (k - 1)


def pole_segment(p, k):
    """The pole's own surface for face k: a slight bulge with a waist groove
    where it meets the next face."""
    zb = z0(k)
    prof = [(R - 0.03, 0.0), (R - 0.01, 0.04), (R, 0.12), (R + 0.01, 0.45), (R, 0.75), (R - 0.02, 0.82),
            (R - 0.04, H)]
    p.lathe([(r, zb + z) for r, z in prof], "pole", segments=20, cap_bottom=False, cap_top=False)


def features(name, zb):
    b = []
    if name == "bear":
        b += [blob((0.0, R + 0.04, zb + 0.4), (0.2, 0.14, 0.14)), blob((0.0, R + 0.17, zb + 0.44), (0.09, 0.05, 0.05)),
              blob((0.0, R + 0.03, zb + 0.2), (0.25, 0.08, 0.06)),
              blob((0.0, R + 0.09, zb + 0.2), (0.18, 0.06, 0.028), neg=True, stiff=1.4),
              blob((0.0, R + 0.11, zb + 0.175), (0.08, 0.05, 0.02))]
        for sx in (-1, 1):
            b += limb([(sx * 0.32, R - 0.03, zb + 0.66), (sx * 0.06, R + 0.04, zb + 0.7)], [0.05, 0.045], spacing=0.6)
            b.append(blob((sx * 0.3, R - 0.18, zb + 0.78), (0.11, 0.06, 0.1)))
    elif name == "frog":
        b += [blob((0.0, R + 0.02, zb + 0.3), (0.34, 0.06, 0.05)),
              blob((0.0, R + 0.06, zb + 0.3), (0.28, 0.04, 0.012), neg=True, stiff=1.4),
              blob((0.0, R + 0.03, zb + 0.44), (0.16, 0.05, 0.07))]
        for sx in (-1, 1):
            b.append(blob((sx * 0.17, R - 0.03, zb + 0.62), (0.13, 0.1, 0.12)))
            b.append(blob((sx * 0.06, R + 0.07, zb + 0.45), (0.025, 0.02, 0.02), neg=True, stiff=1.5))
    elif name == "wolf":
        b += limb([(0.0, R - 0.06, zb + 0.44), (0.0, R + 0.16, zb + 0.4), (0.0, R + 0.3, zb + 0.37)],
                  [0.13, 0.1, 0.07], spacing=0.6)
        b.append(blob((0.0, R + 0.33, zb + 0.4), (0.05, 0.04, 0.04)))
        b += limb([(0.0, R - 0.05, zb + 0.3), (0.0, R + 0.15, zb + 0.26), (0.0, R + 0.25, zb + 0.24)],
                  [0.09, 0.07, 0.05], spacing=0.6)
        for sx in (-1, 1):
            b += limb([(sx * 0.2, R - 0.14, zb + 0.66), (sx * 0.23, R - 0.12, zb + 0.82)], [0.08, 0.025], spacing=0.6)
            b += limb([(sx * 0.27, R - 0.02, zb + 0.6), (sx * 0.05, R + 0.05, zb + 0.66)], [0.04, 0.035], spacing=0.6)
    elif name == "ancestor":
        b += [blob((0.0, R + 0.07, zb + 0.43), (0.06, 0.08, 0.12)), blob((0.0, R + 0.04, zb + 0.24), (0.15, 0.05, 0.05)),
              blob((0.0, R + 0.08, zb + 0.24), (0.1, 0.04, 0.02), neg=True, stiff=1.4),
              blob((0.0, R + 0.02, zb + 0.12), (0.1, 0.04, 0.05))]
        for sx in (-1, 1):
            b += limb([(sx * 0.27, R - 0.03, zb + 0.64), (sx * 0.05, R + 0.04, zb + 0.66)], [0.045, 0.04], spacing=0.6)
            b.append(blob((sx * 0.2, R + 0.0, zb + 0.36), (0.09, 0.05, 0.08)))
            b.append(blob((sx * 0.4, R - 0.2, zb + 0.5), (0.05, 0.06, 0.1)))
    elif name == "eagle":
        b += limb([(0.0, R - 0.03, zb + 0.52), (0.0, R + 0.22, zb + 0.5), (0.0, R + 0.34, zb + 0.4),
                   (0.0, R + 0.31, zb + 0.29)], [0.13, 0.09, 0.05, 0.022], spacing=0.6, squash=0.85)
        b.append(blob((0.0, R + 0.06, zb + 0.32), (0.12, 0.06, 0.05)))
        for sx in (-1, 1):
            b += limb([(sx * 0.32, R - 0.05, zb + 0.68), (sx * 0.06, R + 0.04, zb + 0.72)], [0.055, 0.045], spacing=0.6)
    return b


def face(k):
    name = NAMES[k - 1]
    zb = z0(k)
    parent = "totem" if k == 1 else f"block_{k - 1}"
    p = Part(f"block_{k}", origin=(0.0, 0.0, zb), parent=parent)
    pole_segment(p, k)
    me = sculpt.metaball_mesh(features(name, zb), resolution=0.016)
    sculpt.cut(me, [((0.0, 0.0, zb + 0.005), (0.0, 0.0, -1.0)), ((0.0, 0.0, zb + H - 0.005), (0.0, 0.0, 1.0))])
    me = sculpt.decimate(me, 700)
    clay.into_part(p, me, "carve")
    # teeth in the open mouths
    if name in ("bear", "wolf"):
        y, z = MOUTH[name]
        n = 6 if name == "bear" else 4
        for i in range(n):
            x = (i - (n - 1) / 2) * (0.05 if name == "bear" else 0.04)
            yy = R + 0.07 if name == "bear" else R + 0.18
            K.cone(p, (x, yy, zb + z + 0.03), (0.0, 0.2, -1.0), 0.05, 0.016, "tooth", segments=5, tip=0.004)
    e = Part(f"eyes_{k}", origin=(0.0, R, zb + EYES[name][1]), parent=f"block_{k}")
    ex, ez, er = EYES[name]
    for sx in (-1, 1):
        yfront = R + (0.08 if name == "frog" else 0.0)
        f = K.sphere(e, (0.0, 0.0, 0.0), er, "eye_glow", segments=12, rings=6, squash=(1.0, 0.45), zscale=0.72)
        e.move(f, Matrix.Translation(Vector((sx * ex, yfront, zb + ez))))
    return p, e


def stump():
    p = Part("totem")
    p.lathe([(R + 0.02, 0.0), (R + 0.01, 0.2), (R - 0.03, BASE)], "pole", segments=20, cap_bottom=False, cap_top=False)
    p.lathe([(0.0, 0.0), (0.66, 0.0), (0.66, 0.14), (0.58, 0.2), (R + 0.03, 0.22)], "stone", segments=20,
            cap_bottom=False, cap_top=False)
    return p


def cap():
    top = z0(5) + H
    p = Part("cap", origin=(0.0, 0.0, top), parent="totem")
    prof = [(R - 0.02, 0.0), (0.58, 0.04), (0.6, 0.08), (0.5, 0.1), (0.4, 0.22), (0.3, 0.36), (0.18, 0.44),
            (0.12, 0.46), (0.1, 0.52), (0.04, 0.54)]
    p.lathe([(r, top + z) for r, z in prof], "hat", segments=20, cap_bottom=True, cap_top=True)
    return p


# --------------------------------------------------------------------------
# paint: face space s = arc length round the pole from the front, z = height
# --------------------------------------------------------------------------

def _fs(ctx):
    x, y = ctx.p[:, 0], ctx.p[:, 1]
    a = np.arctan2(x, y)
    return a * R, ctx.p[:, 2], a


def _ov(s, z, cs, cz, w, h, k=2.4):
    return (np.abs(s - cs) / w) ** k + (np.abs(z - cz) / h) ** k < 1.0


def pole_paint(ctx):
    """Warm red cedar; on the front of each face painted formline-like
    fields: black brows, green eye sockets, red nostrils and lips, white
    and yellow accents; split U-forms on the cheeks; the back bare."""
    s_, z, a = _fs(ctx)
    s = AM.carved_wood(ctx, 2101, ramp="am_wood", center=4.4, adze=0.6, oiled=0.2)
    n = ctx.N
    front = np.abs(a) < 1.9
    codes = np.zeros(n, np.int16)
    for k, name in enumerate(NAMES, start=1):
        zb = z0(k)
        lz = z - zb
        on = (lz >= 0) & (lz < H) & front
        ex, ez, er = EYES[name]
        for sx in (-1, 1):
            sock = _ov(s_, lz, sx * ex, ez, er * 2.2, er * 1.6) & on
            codes[sock] = AP.INK["green"]
            cheek = _ov(s_, lz, sx * 0.26, 0.32, 0.1, 0.12) & ~_ov(s_, lz, sx * 0.26, 0.34, 0.06, 0.08) & on
            codes[cheek] = AP.INK["red"] if k % 2 else AP.INK["white"]
            # on the sides: a formline ovoid (black ring, red eye) over two
            # split U-forms, the flank of the creature
            side = _ov(s_, lz, sx * 0.62, 0.55, 0.16, 0.13, 2.8) & ~_ov(s_, lz, sx * 0.62, 0.55, 0.11, 0.085, 2.8) & on
            codes[side] = AP.INK["black"]
            sideo = _ov(s_, lz, sx * 0.62, 0.55, 0.075, 0.045) & on
            codes[sideo] = AP.INK["red"]
            for du in (-0.09, 0.09):
                uf = _ov(s_, lz, sx * 0.62 + du, 0.28, 0.07, 0.12, 3.0) & ~_ov(s_, lz, sx * 0.62 + du, 0.3, 0.04, 0.1, 3.0) & on
                codes[uf] = AP.INK["black"]
        band = (np.abs(lz - 0.06) < 0.025) & front & (lz >= 0)
        codes[band] = AP.INK["black"]
    s = AM.paint_over(ctx, s, codes, 2103, flake=0.2, wear=0.6)
    return s


def carve_paint(ctx):
    """The carved features: black brows (the arcs above the eyes), red
    lips, nostrils, tongue; white teeth; the snouts and beak painted by
    height in each face."""
    s_, z, a = _fs(ctx)
    s = AM.carved_wood(ctx, 2105, ramp="am_wood", center=4.6, adze=0.8, oiled=0.3)
    codes = np.zeros(ctx.N, np.int16)
    for k, name in enumerate(NAMES, start=1):
        zb = z0(k)
        lz = z - zb
        on = (lz >= 0) & (lz < H)
        ex, ez, er = EYES[name]
        brow = on & (lz > ez + er * 0.8) & (lz < ez + 0.2) & (np.abs(s_) < 0.36)
        codes[brow] = AP.INK["black"]
        my, mz = MOUTH[name]
        lips = on & (np.abs(lz - mz) < 0.07) & (np.abs(s_) < 0.3)
        codes[lips] = AP.INK["red"]
        if name == "eagle":
            beak = on & (ctx.p[:, 1] > R + 0.1)
            codes[beak] = AP.INK["ochre"]
        if name == "wolf":
            snout = on & (ctx.p[:, 1] > R + 0.12) & (lz > mz + 0.05)
            codes[snout] = AP.INK["black"]
        if name == "frog":
            dome = on & (lz > 0.5)
            codes[dome] = AP.INK["green"]
    return AM.paint_over(ctx, s, codes, 2107, flake=0.18, wear=0.7)


def eye_paint(ctx):
    """Glass-like inlaid eyes: amber with a dark slit pupil; emissive so the
    exhibit shader's glow (telegraph) lights them up."""
    s = Surface(ctx.N)
    s.use_ramp(P["eye_amber"], shade=np.full(ctx.N, 5.2) + ctx.fbm(40.0, 2, 2109) * 0.6 + _dither(ctx, 0.5, 2110))
    x = ctx.p[:, 0]
    # a vertical slit pupil per eye: closest to each eye's centre line
    sx = np.sign(x)
    pupil = np.zeros(ctx.N, bool)
    for k, name in enumerate(NAMES, start=1):
        ex, ez, er = EYES[name]
        lz = ctx.p[:, 2] - z0(k)
        on = (lz > ez - er) & (lz < ez + er)
        pupil |= on & (np.abs(np.abs(x) - ex) < er * 0.18)
    s.use_ramp(P["am_obsidian"], mask=pupil, shade=np.full(ctx.N, 1.5))
    s.rough = np.full(ctx.N, 0.12)
    s.emit = s.colors() * np.where(pupil, 0.1, 0.55)[:, None]
    return s


def hat_paint(ctx):
    """Woven cedar-bark hat: a twill of strips round the crown, painted with
    a black and red band and an eye motif on the front."""
    s = AM.am_woven_mat(ctx, 2111, strip=4)
    s_, z, a = _fs(ctx)
    top = z0(5) + H
    lz = z - top
    codes = np.zeros(ctx.N, np.int16)
    codes[(lz > 0.12) & (lz < 0.17)] = AP.INK["black"]
    codes[(lz > 0.17) & (lz < 0.21)] = AP.INK["red"]
    eye = (np.abs(a) < 0.6) & _ov(a * 0.5, lz, 0.0, 0.29, 0.14, 0.06) & ~_ov(a * 0.5, lz, 0.0, 0.29, 0.07, 0.03)
    codes[eye] = AP.INK["black"]
    return AM.paint_over(ctx, s, codes, 2113, flake=0.2)


def build():
    parts = [stump()]
    for k in range(1, 6):
        f, e = face(k)
        parts += [f, e]
    parts.append(cap())
    markers = []
    for k, name in enumerate(NAMES, start=1):
        ex, ez, er = EYES[name]
        markers.append((f"face_{k}", (0.0, R + 0.06, z0(k) + ez - 0.04), f"block_{k}"))
        my, mz = MOUTH[name]
        markers.append((f"mouth_{k}", (0.0, my + 0.04, z0(k) + mz), f"block_{k}"))
    fns = {"pole": pole_paint, "carve": carve_paint, "tooth": lambda c: M.ivory(c, 2115, center=5.6),
           "eye_glow": eye_paint, "stone": lambda c: AM.volcanic(c, 2117, center=4.2), "hat": hat_paint}
    organic = tuple(f"block_{k}" for k in range(1, 6))
    return Model("totem", parts, fns, ppm=192, ground=0.0, ao_dist=0.25, front=1, organic=organic,
                 markers=markers, preview_yaws=(-30.0, 20.0, 60.0, 180.0), preview_elevation=6.0,
                 preview_extra=[("top", (0.0, 0.4, z0(4) + 0.5), 1.0, 20.0, 5.0),
                                ("bottom", (0.0, 0.4, z0(1) + 0.6), 1.0, -20.0, 5.0)])
