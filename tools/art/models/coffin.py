"""A painted anthropoid coffin (21st Dynasty "yellow coffin"), standing
upright on a black museum stand: the lid is the mummy's image - a gilded
face framed by a striped blue wig, a broad collar of many rows, the sky
goddess Nut spreading her wings across the body, a column of prayers down
the legs between panels of gods, the feet painted on the footboard; the
case behind is painted outside and dark inside. The lid tips forward on its
bottom front edge when a mummy bursts out.

Kit convention: origin = centre of the stand's base, front = Godot -Z
(Blender +Y, built final), 192 px/m. 0.86 x 2.05 x 0.76 m in all.
Parts: coffin (case and stand, root) and lid (child; pivot on the lid's
bottom front edge, (0, 0.22, 0.12) Blender = Godot (0, 0.12, -0.22): rotate
about X to tip it out). Marker MummySpawn inside the case, where the
sleeping mummy's origin (its feet) stands. Texture sets: coffin (yellow
ground), coffin_black (black ground with gilded figures).

Sized to the sleeper (tests/integration/test_mummy_tomb_fit.gd measures the
mummy's crossed-arms rest pose, loose bandages and all, against the shell):
the case is wide across the elbows, deep behind the shoulders, the lid deep
over the forearms; everything of the mummy lies inside the cavity with
2 cm to spare.
"""
import math

import numpy as np
from mathutils import Matrix, Vector

from artlib import egypt as E
from artlib import egypt_paint as EP
from artlib import kit as K
from artlib import sculpt
from artlib.archkit import cull_floor, kit
from artlib.geo import Part
from artlib.materials import P, _dither, _wood_core
from artlib.painter import Surface
from artlib.sculpt import blob

Z0 = 0.12          # the coffin stands on the stand at this height
LEN = 1.9
# (z along the coffin, half width, front depth (lid), back depth (case)).
# From the feet up: the legs, a flare over the hips to the elbows of the
# crossed arms (widest), the shoulders, the head.
SECTIONS = [(0.0, 0.16, 0.16, 0.14), (0.1, 0.222, 0.25, 0.15), (0.3, 0.228, 0.205, 0.15), (0.7, 0.252, 0.175, 0.152),
            (0.95, 0.306, 0.175, 0.158), (1.1, 0.355, 0.2, 0.17), (1.22, 0.376, 0.238, 0.188),
            (1.35, 0.362, 0.25, 0.207), (1.47, 0.325, 0.216, 0.195), (1.56, 0.25, 0.2, 0.16),
            (1.68, 0.225, 0.215, 0.15), (1.79, 0.2, 0.19, 0.14), (1.86, 0.15, 0.13, 0.11), (1.9, 0.07, 0.06, 0.05)]
# the sections before this change (the hands were laid on that skin)
OLD_SECTIONS = [(0.0, 0.16, 0.16, 0.14), (0.1, 0.175, 0.19, 0.15), (0.3, 0.165, 0.15, 0.14), (0.7, 0.2, 0.15, 0.15),
                (1.05, 0.235, 0.165, 0.16), (1.32, 0.27, 0.175, 0.17), (1.47, 0.295, 0.17, 0.17),
                (1.56, 0.25, 0.2, 0.16), (1.68, 0.225, 0.215, 0.15), (1.79, 0.2, 0.19, 0.14),
                (1.86, 0.15, 0.13, 0.11), (1.9, 0.07, 0.06, 0.05)]
N = 20
# width of the lid's painted front (m): the broadest section, with a margin
LID_W = 0.8


def _at(sections, z):
    """(half width, front depth, back depth) of the sections at [param z] along the coffin."""
    if z <= sections[0][0]:
        return sections[0][1:]
    for a, b in zip(sections, sections[1:]):
        if z <= b[0]:
            t = (z - a[0]) / (b[0] - a[0])
            return tuple(a[k] * (1.0 - t) + b[k] * t for k in (1, 2, 3))
    return sections[-1][1:]


def _skin(sections, x, z):
    """Height of the lid's front skin (Blender y) at [param x] across and [param z] up the coffin."""
    w, df, _ = _at(sections, z)
    return df * math.sqrt(max(0.0, 1.0 - (x / w) ** 2))


def _on_skin(x, y, z):
    """The point (x, y, z) laid on the lid as it is now, at the same height over the skin as it was over the old one."""
    return (x, _skin(SECTIONS, x, z - Z0) + y - _skin(OLD_SECTIONS, x, z - Z0), z)


def _ring(z, w, d, half, inset=0.0):
    """Points of half a section: front (half = +1, angles 0..pi) or back."""
    pts = []
    for i in range(N // 2 + 1):
        a = math.pi * i / (N // 2)
        x = (w - inset) * math.cos(a)
        y = half * (d - inset) * math.sin(a)
        pts.append((x, y, Z0 + z))
    return pts


def _shell(p, half, slot, inset=0.0, flip=False):
    rings = []
    for z, w, df, db in SECTIONS:
        d = df if half > 0 else db
        rings.append([p.bm.verts.new(c) for c in _ring(z, w, d, half, inset)])
    faces = []
    for j in range(len(rings) - 1):
        for i in range(N // 2):
            q = [rings[j][i], rings[j][i + 1], rings[j + 1][i + 1], rings[j + 1][i]]
            f = p._face(q, slot, smooth=True)
            f.normal_update()
            c = f.calc_center_median()
            out = Vector((c.x, c.y, 0.0))
            if (f.normal.dot(out) < 0) != flip:
                f.normal_flip()
            faces.append(f)
    # bottom (footboard) cap
    bot = rings[0]
    f = p._face(bot, slot)
    f.normal_update()
    if (f.normal.z > 0) != flip:
        f.normal_flip()
    return rings, faces


def case():
    p = Part("coffin")
    outer, _ = _shell(p, -1, "case")
    inner, _ = _shell(p, -1, "inside", inset=0.035, flip=True)
    # rim at y = 0 joining outer and inner halves
    for j in range(len(SECTIONS) - 1):
        for i in (0, N // 2):
            q = [outer[j][i], outer[j + 1][i], inner[j + 1][i], inner[j][i]]
            f = p._face(q, "case", smooth=False)
            f.normal_update()
            if f.normal.y < 0:
                f.normal_flip()
    top = [outer[-1][i] for i in range(N // 2 + 1)] + [inner[-1][i] for i in range(N // 2, -1, -1)]
    f = p._face(top, "case")
    f.normal_update()
    if f.normal.z < 0:
        f.normal_flip()
    # the stand: a black plinth and a post with a bracket at the back
    p.box((0.0, 0.0, Z0 / 2), (0.86, 0.76, Z0), "stand", bevel=0.012)
    p.box((0.0, -0.30, 0.75), (0.08, 0.06, 1.3), "stand", bevel=0.008)
    p.box((0.0, -0.23, 1.35), (0.3, 0.11, 0.05), "stand", bevel=0.008)
    cull_floor([p])
    return p


def lid():
    p = Part("lid", origin=(0.0, 0.22, Z0), parent="coffin")
    rings, faces = _shell(p, 1, "lid")
    back = []
    for ring in rings:
        back.append(ring)
    # flat back of the lid (the seam plane y = 0): a strip of quads
    for j in range(len(rings) - 1):
        a0, a1 = rings[j][0], rings[j][N // 2]
        b0, b1 = rings[j + 1][0], rings[j + 1][N // 2]
        f = p._face([a0, b0, b1, a1], "lid_back")
        f.normal_update()
        if f.normal.y > 0:
            f.normal_flip()
    top = rings[-1]
    f = p._face(top, "lid")
    f.normal_update()
    if f.normal.z < 0:
        f.normal_flip()
    # the face: a carved and gilded mask standing out of the lid
    face_z = Z0 + 1.69
    b = [blob((0.0, 0.205, face_z), (0.11, 0.05, 0.13)),
         blob((0.0, 0.245, face_z - 0.005), (0.016, 0.025, 0.035)),
         blob((0.0, 0.232, face_z - 0.065), (0.04, 0.014, 0.011)),
         blob((0.0, 0.215, face_z - 0.105), (0.045, 0.02, 0.025))]
    for sx in (-1, 1):
        b += [blob((sx * 0.045, 0.235, face_z + 0.03), (0.026, 0.012, 0.012), neg=True, stiff=1.5),
              blob((sx * 0.1, 0.17, face_z - 0.01), (0.03, 0.035, 0.05))]
    me = sculpt.metaball_mesh(b, resolution=0.004)
    sculpt.cut(me, [((0, 0.17, 0), (0, -1, 0))])
    me = sculpt.decimate(me, 700)
    sculpt.into_part(p, me, "face")
    # crossed hands on the chest, carved in the round
    for sx in (-1, 1):
        K.seg(p, _on_skin(sx * 0.14, 0.19, Z0 + 1.2), _on_skin(-sx * 0.05, 0.215, Z0 + 1.28),
              [(0.03, 0.0), (0.028, 1.0)], "lid", segments=8)
        K.sphere(p, _on_skin(-sx * 0.07, 0.218, Z0 + 1.285), 0.038, "face", segments=8, rings=5, squash=(1.0, 0.6))
    return p


# --------------------------------------------------------------------------
# paint
# --------------------------------------------------------------------------

_C = {}


def _lid_canvas(w, h, seed=31):
    """The front of the lid, LID_W x 1.9 m at 192 px/m (x across from the
    viewer's left, rows from the head down)."""
    if (w, h) in _C:
        return _C[(w, h)]
    import random
    rng = random.Random(seed)
    c = np.zeros((h, w), np.int16)
    px = lambda m: int(round(m * 192))  # noqa: E731
    cx = w // 2
    # wig: blue with black stripes framing the face (head end = top rows):
    # over the brow, and the two lappets down to the collar
    fy, fh, fw = px(0.215), px(0.17), px(0.125)
    for y in range(0, px(0.44)):
        for x in range(w):
            dx = (x - cx) / fw
            dy = (y - fy) / fh
            if dx * dx + dy * dy > 1.0 and (abs(x - cx) < px(0.27)):
                c[y, x] = EP.INK["blue"] if (y // 4) % 2 == 0 else EP.INK["black"]
    # the face's yellow ground (the gilded mask stands on it)
    for y in range(0, px(0.44)):
        for x in range(w):
            if ((x - cx) / fw) ** 2 + ((y - fy) / fh) ** 2 <= 1.0:
                c[y, x] = EP.INK["yellow"]
    # broad collar rows (y from 0.36 to 0.6 below the top)
    cyc = [EP.INK["red"], EP.INK["green"], EP.INK["blue"], EP.INK["yellow"], EP.INK["green"], EP.INK["red"],
           EP.INK["blue"], EP.INK["green"]]
    for k in range(8):
        y0 = px(0.44) + k * 6
        c[y0:y0 + 5, :] = cyc[k]
        c[y0 + 5:y0 + 6, :] = EP.INK["outline"]
    # Nut with spread wings across the belly
    yn = px(0.8)
    for x in range(w):
        d = abs(x - cx) / (w / 2)
        top = yn - int(18 * (1 - d * d))
        for y in range(top, yn + 22):
            band = (y - top) // 6
            c[y, x] = [EP.INK["red"], EP.INK["blue"], EP.INK["green"], EP.INK["blue"]][min(band, 3)]
            if (x % 5 == 0) and band >= 2:
                c[y, x] = EP.INK["outline"]
    EP.figure(c, cx, yn + 10, 46, pose="adore", sex="f", seed=2)
    # the legs: a yellow-ground column of text in the middle, panels of gods
    # either side, block borders between registers
    y = yn + 30
    col_w = 26
    text = EP.text_columns(1, (h - y - px(0.18)) // 11, seed, col_w=col_w, cell=10, gap=1, divider=False)
    c[y:y + text.shape[0], cx - col_w // 2:cx - col_w // 2 + col_w] = np.where(
        text > 0, text, EP.INK["white"])
    c[y:y + text.shape[0], cx - col_w // 2 - 2:cx - col_w // 2] = EP.INK["red"]
    c[y:y + text.shape[0], cx + col_w // 2:cx + col_w // 2 + 2] = EP.INK["red"]
    reg = 70
    heads = ["jackal", "falcon", "human", "jackal", "falcon"]
    k = 0
    while y + reg < h - px(0.2):
        bb = EP.block_border(w, 4, 5)
        c[y:y + 4] = np.where(np.abs(np.arange(w) - cx) > col_w // 2 + 2, bb, c[y:y + 4])
        for side in (-1, 1):
            fx = cx + side * (col_w // 2 + 22)
            EP.figure(c, fx, y + reg - 2, reg - 12, pose="bearer", head=heads[k % 5], flip=side > 0,
                      offering="lotus", seed=k + side, crown="nemes" if heads[k % 5] == "human" else None)
        y += reg
        k += 1
    # the footboard: a red band and the feet's yellow ground
    yf = h - px(0.16)
    c[yf:h, :] = EP.INK["yellow"]
    c[yf:yf + 4, :] = EP.INK["red"]
    _C[(w, h)] = c
    return c


def lid_paint(ground):
    def fn(ctx, seed=1101):
        s = Surface(ctx.N)
        ramp, center = ("eg_yellow", 4.6) if ground == "yellow" else ("eg_black", 1.6)
        s.use_ramp(P[ramp], shade=center + ctx.fbm(4.0, 3, seed) * 0.5 + _dither(ctx, 0.5, seed + 1))
        s.rough = np.full(ctx.N, 0.45)                     # varnished
        tx = ctx.texel
        w = int(round(LID_W / tx))
        h = int(round(LEN / tx))
        canvas = _lid_canvas(w, h)
        front = ctx.n[:, 1] > 0.15
        u = -ctx.p[:, 0]
        c, r = E.sample(canvas, u[front], ctx.p[front, 2], tx, u0=-LID_W / 2, v0=Z0)
        codes = np.full(ctx.N, -1, np.int16)
        rims = np.zeros(ctx.N, np.int16)
        codes[front] = c
        rims[front] = r
        inks = dict(E.INKS)
        if ground != "yellow":
            for k in (EP.INK["yellow"], EP.INK["white"]):
                inks[k] = ("gold", 6.0, 0.3, 1.0)
        s = E.paint_over(ctx, s, codes, rims, seed + 2, flake=0.2, wear=0.4, inks=inks)
        s.shade -= (1.0 - ctx.ao) * 2.5
        return s
    return fn


def face_paint(ground):
    def fn(ctx, seed=1103):
        s = E.gold_leaf(ctx, seed)
        x, z = ctx.p[:, 0], ctx.p[:, 2]
        fz = Z0 + 1.69
        for sx in (-1, 1):
            d = np.sqrt(((x - sx * 0.045) / 1.4) ** 2 + ((z - (fz + 0.03)) / 0.6) ** 2)
            eye = d < 0.022
            s.use_ramp(P["eg_white"], mask=eye, shade=np.full(ctx.N, 5.5))
            s.use_ramp(P["eg_black"], mask=(d < 0.009) | ((d > 0.022) & (d < 0.028)), shade=np.full(ctx.N, 0.8))
            s.metal = np.where(eye, 0.0, s.metal)
        return s
    return fn


def case_paint(ground):
    def fn(ctx, seed=1105):
        s = Surface(ctx.N)
        ramp, center = ("eg_yellow", 4.4) if ground == "yellow" else ("eg_black", 1.5)
        s.use_ramp(P[ramp], shade=center + ctx.fbm(4.0, 3, seed) * 0.5 + _dither(ctx, 0.5, seed + 1))
        s.rough = np.full(ctx.N, 0.5)
        ix = np.floor(ctx.p[:, 0] / ctx.texel).astype(np.int64)
        iz = np.floor(ctx.p[:, 2] / ctx.texel).astype(np.int64)
        band = np.mod(iz, 96) < 16
        codes = np.where(band, np.where(np.mod(iz, 96) < 2, EP.INK["red"], EP.INK["blue"]), 0).astype(np.int16)
        bars = band & (np.mod(ix, 12) < 2) & (np.mod(iz, 96) >= 2)
        codes[bars] = EP.INK["yellow"]
        s = E.paint_over(ctx, s, codes, np.zeros(ctx.N, np.int16), seed + 2, flake=0.25)
        s.shade -= (1.0 - ctx.ao) * 3.0
        return s
    return fn


def inside_paint(ctx, seed=1107):
    s = Surface(ctx.N)
    s.use_ramp(P["resin"], shade=2.2 + ctx.fbm(6.0, 3, seed) * 0.8 + _dither(ctx, 0.5, seed + 1) - (1.0 - ctx.ao) * 2.0)
    s.rough = np.full(ctx.N, 0.7)
    return s


def wood_back(ctx, seed=1109):
    s = _wood_core(ctx, P["timber"], 4.2, seed, ring_freq=7.0)
    s.shade -= (1.0 - ctx.ao) * 2.5
    s.rough = np.full(ctx.N, 0.8)
    return s


def stand(ctx, seed=1111):
    from artlib import arch_materials as A
    return A.paint(ctx, "paint_grey", 1.4, seed, rough=0.4, chip=0.3)


def fns_for(ground):
    return {"lid": lid_paint(ground), "face": face_paint(ground), "case": case_paint(ground), "inside": inside_paint,
            "lid_back": wood_back, "stand": stand}


def build():
    return kit("coffin", [case(), lid()], fns_for("yellow"), ppm=192, built_final=True, ao_dist=0.18,
               organic=(), markers=[("MummySpawn", (0.0, 0.0, Z0 + 0.95), "coffin")],
               variants={"coffin_black": fns_for("black")},
               preview_closeup=((0.0, 0.2, Z0 + 1.55), 0.45))
