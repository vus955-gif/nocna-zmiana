"""Floor I, Asia wing exhibits: ritual bronzes, porcelain, scrolls, the bell.

  bronze_ding        a Shang-style round tripod cauldron (0.78 m): a deep
                     bowl on three columnar legs, two upright loop handles
                     on the rim, a band of taotie masks in relief between
                     notched flanges, masks on the tops of the legs; green
                     malachite crust over dark bronze, the relief rubbed.
                     Also the incense burner on the Buddha's step.
  bronze_gu          a gu wine beaker (0.32 m): trumpet mouth, a slim neck
                     with rising blades, a bulging middle with taotie and
                     four notched flanges, a flared foot.
  vase_blue_white    a Ming meiping (0.42 m): ruyi collar on the shoulder,
                     a five-clawed dragon chasing the pearl among clouds
                     round the body, a band of lotus panels at the foot;
                     underglaze cobalt under a cool clear glaze.
  vase_celadon       a Goryeo maebyeong (0.4 m) in grey-green celadon with
                     inlaid (sanggam) cranes in double roundels and flying
                     between them among clouds, a chrysanthemum band on the
                     shoulder, crazing in the glaze.
  moon_jar           a Joseon moon jar (dalhangari, 0.44 m): a near-sphere
                     thrown in two halves (a faint belt where they meet,
                     a little lopsided), milky glaze with warm stains.
  scroll_hanging     a hanging scroll 0.62 x 2.0 m: silk mounting with gold
                     brocade bands, the calligraphy sheet, a wooden roller
                     with knobs, a top stave with its cord. Wall piece:
                     origin at the hook on the wall (it hangs 2.05 m down
                     along the wall plane, z = 0). Texture sets:
                     scroll_hanging (山 mountain), scroll_hanging_water (水),
                     scroll_hanging_moon (月), scroll_hanging_enso (the Zen
                     circle, for the tea house alcove).
  temple_bell        a Korean temple bell (beomjong, 1.5 m) in a painted
                     timber frame: the dragon hook and the sound tube on
                     top, four panels of nine nipples, a pair of flying
                     celestials and two lotus striking bosses in relief,
                     scroll bands; a striking log on ropes. Parts: the frame
                     (temple_bell), bell (pivot on the hook pin: swing it
                     about X), striker (pivot between its ropes: draw it
                     back about X and let it go).
Front = -Z (Godot) = +Y here; origin centre of the base unless noted.
"""
import math
import random

import bmesh
import numpy as np
from mathutils import Matrix, Vector

from artlib import asia as A
from artlib import asia_paint as AP
from artlib import egypt as E
from artlib import kit as K
from artlib import materials as M
from artlib.archkit import front_prism, kit
from artlib.asia_geo import ccw, dou
from artlib.geo import Part
from artlib.kit import R, T
from artlib.materials import P, _dither, smoothstep
from artlib.painter import Surface

I = AP.INK


def _ang(ctx, cx=0.0, cy=0.0):
    """Angle round the vertical axis, 0..1 (front = +Y at 0.25)."""
    return np.mod(np.arctan2(ctx.p[:, 1] - cy, ctx.p[:, 0] - cx) / (2 * np.pi), 1.0)


def band_sample(ctx, canvas, z0, z1, seed=0, cx=0.0, cy=0.0):
    """Codes of a canvas wrapped once round a lathe between heights z0 and
    z1 (u = angle, v = height): no seam at any radius."""
    H, W = canvas.shape
    z = ctx.p[:, 2]
    inside = (z >= z0) & (z < z1)
    ix = np.clip((_ang(ctx, cx, cy) * W).astype(np.int64), 0, W - 1)
    iy = np.clip(((z1 - z) / max(z1 - z0, 1e-6) * H).astype(np.int64), 0, H - 1)
    codes = np.where(inside, canvas[iy, ix], 0).astype(np.int16)
    return codes


# --------------------------------------------------------------------------
# bronzes
# --------------------------------------------------------------------------

def _flange(p, a, r, z0, z1, depth, mat, notches=5):
    """A notched vertical flange standing out from radius r at angle a."""
    pts = [(0.0, z0)]
    h = (z1 - z0) / notches
    for k in range(notches):
        zb = z0 + k * h
        pts += [(depth, zb + h * 0.1), (depth, zb + h * 0.6), (depth * 0.55, zb + h * 0.7), (depth * 0.55, zb + h)]
    pts += [(0.0, z1)]
    f = front_prism(p, ccw(pts), 0.012, mat, y_back=0.006)
    p.move(f, R('Z', math.degrees(a)) @ T(r, 0.0, 0.0) @ R('Z', 90))
    return f


def ding():
    p = Part("bronze_ding")
    # bowl: thick rim, deep rounded body
    p.lathe([(0.0, 0.3), (0.16, 0.3), (0.25, 0.34), (0.29, 0.42), (0.3, 0.55), (0.3, 0.66), (0.31, 0.68),
             (0.31, 0.7), (0.285, 0.7), (0.28, 0.6), (0.26, 0.42)], "bronze", segments=32, cap_bottom=False,
            cap_top=False)
    # relief band below the rim with three flanges per mask pair
    p.lathe([(0.302, 0.55), (0.307, 0.56), (0.307, 0.65), (0.302, 0.66)], "relief", segments=32, cap_bottom=False,
            cap_top=False)
    for k in range(6):
        _flange(p, math.tau * k / 6 + math.pi / 6, 0.305, 0.55, 0.66, 0.03, "bronze", notches=3)
    # three legs
    for k in range(3):
        a = math.tau * k / 3 + math.pi / 2
        x, y = 0.2 * math.cos(a), 0.2 * math.sin(a)
        K.seg(p, (x, y, 0.0), (x * 1.05, y * 1.05, 0.36), [(0.05, 0.0), (0.042, 0.4), (0.048, 0.8), (0.06, 1.0)],
              "bronze", segments=10)
        f = p.box((0.0, 0.0, 0.0), (0.12, 0.03, 0.1), "relief", bevel=0.008)
        p.move(f, T(x * 1.2, y * 1.2, 0.3) @ R('Z', math.degrees(a) + 90))
    # two upright loop handles on the rim
    for sx in (-1, 1):
        pts = [(sx * 0.265, -0.11, 0.7), (sx * 0.265, -0.11, 0.86), (sx * 0.265, 0.11, 0.86), (sx * 0.265, 0.11, 0.7)]
        f = p.tube(pts, 0.022, "bronze", sides=6)
    return p


def gu():
    p = Part("bronze_gu")
    prof = [(0.055, 0.0), (0.06, 0.012), (0.045, 0.04), (0.03, 0.08), (0.034, 0.1), (0.038, 0.125),
            (0.038, 0.155), (0.028, 0.17), (0.022, 0.2), (0.03, 0.25), (0.05, 0.29), (0.085, 0.32), (0.08, 0.32),
            (0.045, 0.28), (0.02, 0.21)]
    p.lathe(prof, "bronze", segments=24, cap_bottom=True, cap_top=False)
    p.lathe([(0.039, 0.1), (0.041, 0.105), (0.041, 0.15), (0.039, 0.155)], "relief", segments=24, cap_bottom=False,
            cap_top=False)
    for k in range(4):
        _flange(p, math.tau * k / 4, 0.038, 0.09, 0.16, 0.016, "bronze", notches=3)
        _flange(p, math.tau * k / 4, 0.03, 0.02, 0.07, 0.014, "bronze", notches=2)
    return p


_TAOTIE = {}


def _taotie_band(w, h):
    if (w, h) not in _TAOTIE:
        unit = AP.taotie(max(8, w // 3), h)
        _TAOTIE[(w, h)] = np.concatenate([unit] * 3, axis=1)[:, :w] if unit.shape[1] * 3 >= w else \
            np.tile(unit, (1, w // unit.shape[1] + 1))[:, :w]
    return _TAOTIE[(w, h)]


def bronze_fn(seed, crust, z0, z1, r):
    """Patinated bronze; the band between z0 and z1 (radius r) carries the
    taotie relief: the mask raised and rubbed brighter, the spirals low and
    full of crust."""
    def fn(ctx):
        circ = 2 * math.pi * r
        w = int(round(circ / ctx.texel))
        h = max(8, int(round((z1 - z0) / ctx.texel)))
        codes = band_sample(ctx, _taotie_band(w, h), z0, z1)
        raised = codes == I["raised"]
        eyes = codes == I["gold"]
        sunk = codes == I["sunk"]
        rubbed = (raised | eyes) * 0.7
        s = A.bronze_patina(ctx, seed, crust=crust, polish=0.5, rubbed=rubbed, dark=0.15)
        s.height = s.height + raised * 0.0015 + eyes * 0.002 - sunk * 0.0005
        s.shade[sunk] -= 0.8
        return s
    return fn


# --------------------------------------------------------------------------
# porcelain
# --------------------------------------------------------------------------

MEIPING = [(0.06, 0.0), (0.075, 0.008), (0.08, 0.03), (0.085, 0.1), (0.1, 0.18), (0.12, 0.26), (0.13, 0.31),
           (0.125, 0.345), (0.1, 0.375), (0.06, 0.395), (0.035, 0.402), (0.03, 0.41), (0.034, 0.42),
           (0.034, 0.428), (0.024, 0.428), (0.022, 0.41)]
MAEBYEONG = [(0.065, 0.0), (0.075, 0.01), (0.07, 0.04), (0.068, 0.08), (0.08, 0.15), (0.11, 0.24),
             (0.13, 0.3), (0.132, 0.33), (0.12, 0.36), (0.085, 0.38), (0.045, 0.388), (0.035, 0.395),
             (0.04, 0.4), (0.03, 0.405), (0.02, 0.4)]


def vase(name, prof, slot):
    p = Part(name)
    p.lathe(prof, slot, segments=28, cap_bottom=True, cap_top=False)
    return p


def moon_jar():
    p = Part("moon_jar")
    rng = random.Random(5)
    lump = [1.0 + rng.uniform(-0.018, 0.018) for _ in range(28)]
    prof = [(0.11, 0.0), (0.12, 0.008), (0.115, 0.02), (0.16, 0.05), (0.2, 0.1), (0.222, 0.16), (0.226, 0.215),
            (0.229, 0.222), (0.226, 0.23), (0.222, 0.29), (0.2, 0.35), (0.16, 0.395), (0.12, 0.42),
            (0.11, 0.435), (0.115, 0.445), (0.1, 0.445), (0.098, 0.43)]
    # thrown in two halves: the upper one a little turned and off-centre
    p.lathe(prof, "moon", segments=28, cap_bottom=True, cap_top=False,
            ring_scale=lambda i, j: lump[(i + (3 if j > 7 else 0)) % 28] * (1.0 + (0.012 if j > 7 and i in (5, 6, 7) else 0)))
    return p


_CANV = {}


def _meiping_canvases(ppm):
    if ppm in _CANV:
        return _CANV[ppm]
    out = {}
    # body band (r ~ 0.12): the dragon
    wb = int(round(2 * math.pi * 0.115 * ppm))
    out["body"] = AP.dragon(wb, int(round(0.15 * ppm)), seed=7)
    # shoulder: ruyi collar points hanging down
    ws = int(round(2 * math.pi * 0.11 * ppm))
    hs = int(round(0.06 * ppm))
    c = AP.blank(ws, hs)
    n = 8
    for k in range(n):
        cx = (k + 0.5) * ws / n
        m = AP.ruyi(c, cx, hs * 0.45, hs * 0.55, I["cobalt"])
        AP.outline(c, m, I["cobalt_dark"])
        c[AP.ellipse_mask(c.shape, cx, hs * 0.45, hs * 0.14, hs * 0.14)] = I["cobalt_wash"]
    c[0:2, :] = I["cobalt_dark"]
    out["shoulder"] = c
    # foot: lotus panels
    wf = int(round(2 * math.pi * 0.09 * ppm))
    hf = int(round(0.07 * ppm))
    c = AP.blank(wf, hf)
    n = 10
    for k in range(n):
        x0 = k * wf / n
        pts = [(x0 + 2, hf - 1), (x0 + wf / n - 2, hf - 1), (x0 + wf / n - 2, hf * 0.45), (x0 + wf / n / 2, 1),
               (x0 + 2, hf * 0.45)]
        m = AP.poly_mask(c.shape, pts)
        AP.outline(c, m, I["cobalt_dark"])
        inner = AP.poly_mask(c.shape, [(x0 + 5, hf - 3), (x0 + wf / n - 5, hf - 3), (x0 + wf / n - 5, hf * 0.55),
                                       (x0 + wf / n / 2, hf * 0.25), (x0 + 5, hf * 0.55)])
        c[inner] = I["cobalt_wash"]
    c[-2:, :] = I["cobalt_dark"]
    out["foot"] = c
    _CANV[ppm] = out
    return out


def meiping_paint(ctx, seed=1601):
    s = A.glaze(ctx, seed, "porcelain_white", 7.6)
    ppm = int(round(1.0 / ctx.texel))
    cv = _meiping_canvases(ppm)
    codes = band_sample(ctx, cv["body"], 0.15, 0.3)
    codes = np.maximum(codes, band_sample(ctx, cv["shoulder"], 0.31, 0.37))
    codes = np.maximum(codes, band_sample(ctx, cv["foot"], 0.04, 0.11))
    z = ctx.p[:, 2]
    for zl in (0.115, 0.145, 0.305, 0.375):
        codes[np.abs(z - zl) < ctx.texel * 0.9] = I["cobalt"]
    out = ctx.n[:, 2] < 0.95
    codes = np.where(out, codes, 0).astype(np.int16)
    s = E.paint_over(ctx, s, codes, np.zeros(ctx.N, np.int16), seed + 1, flake=0.0, wear=0.0,
                     inks=A.inks_glazed(A.INKS))
    blue = codes > 0
    heap = blue & (ctx.rand(seed + 2) > 0.85)
    s.shade[heap] -= 1.8
    inside = ctx.n[:, 2] < -0.5
    s.shade[inside] -= 2.0
    return s


_CEL = {}


def _celadon_canvas(ppm):
    if ppm in _CEL:
        return _CEL[ppm]
    w = int(round(2 * math.pi * 0.115 * ppm))
    h = int(round(0.2 * ppm))
    c = AP.blank(w, h)
    rows = ((0.3, 0), (0.75, 1))
    rad = h * 0.17
    for ry, off in rows:
        n = 4
        for k in range(n):
            cx = (k + 0.5 * off + 0.25) * w / n
            for dx in (-w, 0, w):
                AP.crane_roundel(c, cx + dx, h * ry, rad, flip=(k + off) % 2 == 1)
    rng = random.Random(9)
    for k in range(10):
        cx, cy = rng.uniform(0, w), rng.uniform(h * 0.08, h * 0.95)
        m = AP.ellipse_mask(c.shape, cx, cy, rad * 1.2, rad * 1.2)
        if (c[m] != 0).any():
            continue
        if k % 2 == 0:
            AP.crane(c, cx, cy, rad * 1.3, flip=k % 4 == 0)
        else:
            mm = AP.ruyi(c, cx, cy, rad * 0.45, I["inlay_white"], flip=k % 3 == 0)
    _CEL[ppm] = c
    return c


def celadon_paint(ctx, seed=1611):
    s = A.glaze(ctx, seed, "celadon", 6.0, craze=0.3)
    ppm = int(round(1.0 / ctx.texel))
    codes = band_sample(ctx, _celadon_canvas(ppm), 0.1, 0.3)
    z = ctx.p[:, 2]
    # shoulder band of chrysanthemums: white dots in black rings
    a = _ang(ctx)
    shoulder = (z > 0.315) & (z < 0.355)
    ring_i = np.floor(a * 24)
    fa = (a * 24 - ring_i - 0.5) * 2 * math.pi * 0.12 / 24
    fz = z - 0.335
    d = np.hypot(fa, fz)
    codes[shoulder & (d < 0.009)] = I["inlay_white"]
    codes[shoulder & (d >= 0.009) & (d < 0.012)] = I["inlay_black"]
    for zl in (0.1, 0.305, 0.36):
        codes[np.abs(z - zl) < ctx.texel] = I["inlay_black"]
    out = ctx.n[:, 2] < 0.95
    codes = np.where(out, codes, 0).astype(np.int16)
    s = E.paint_over(ctx, s, codes, np.zeros(ctx.N, np.int16), seed + 1, flake=0.0, wear=0.0,
                     inks=A.inks_glazed(A.INKS))
    inlay = codes > 0
    s.shade[inlay] -= 0.4                 # seen through the green glaze
    s.shade[ctx.n[:, 2] < -0.5] -= 2.0
    return s


def moon_paint(ctx, seed=1621):
    s = A.glaze(ctx, seed, "moon_white", 7.0, pinholes=2.0)
    stain = smoothstep(0.35, 0.8, ctx.fbm(2.5, 4, seed + 1))
    s.shade -= stain * 1.4
    z = ctx.p[:, 2]
    belt = np.abs(z - 0.222) < ctx.texel * 1.5
    s.shade[belt] -= 0.6
    drip = (ctx.fbm(np.array([30.0, 30.0, 2.0]), 2, seed + 2) > 0.45) & (z < 0.12)
    s.shade[drip] -= 0.8
    foot = z < 0.02
    s.use_ramp(P["earth_wall"], mask=foot, shade=np.full(ctx.N, 5.4) + _dither(ctx, 0.6, seed + 3))
    s.rough = np.where(foot, 0.85, s.rough)
    s.shade[ctx.n[:, 2] < -0.5] -= 2.0
    return s


# --------------------------------------------------------------------------
# hanging scroll
# --------------------------------------------------------------------------

SW, SH = 0.62, 2.0
PAPER = (0.42, 1.06, 0.62)                 # width, height, bottom of the sheet (z below the hook: -SH..0)


def scroll():
    p = Part("scroll_hanging")
    # the mounting: silk panel (wall plane y=0, the scroll hangs toward -y a few mm)
    p.box((0.0, -0.004, -SH / 2 - 0.02), (SW, 0.004, SH - 0.04), "mount")
    # stave at the top, roller at the bottom with knobs
    p.box((0.0, -0.012, -0.06), (SW + 0.01, 0.016, 0.022), "stave", bevel=0.003)
    roller = K.seg(p, (-SW / 2 - 0.02, -0.02, -SH + 0.0), (SW / 2 + 0.02, -0.02, -SH + 0.0),
                   [(0.016, 0.0), (0.016, 1.0)], "stave", segments=8)
    for sx in (-1, 1):
        K.seg(p, (sx * (SW / 2 + 0.02), -0.02, -SH), (sx * (SW / 2 + 0.065), -0.02, -SH),
              [(0.022, 0.0), (0.026, 0.4), (0.024, 1.0)], "knob", segments=8)
    # cord to the hook
    p.tube([(-0.12, -0.012, -0.05), (0.0, -0.008, 0.0), (0.12, -0.012, -0.05)], 0.004, "cord", sides=4)
    p.lathe([(0.0, 0.0), (0.008, 0.0), (0.008, 0.012), (0.0, 0.012)], "stave", segments=6, center=(0.0, -0.004, 0.0))
    return p


def scroll_paint(char):
    """Mounting (pale green silk, gold brocade bands round the sheet and
    across the top), the sheet with the character (or the ensō)."""
    def fn(ctx):
        x, z = ctx.p[:, 0], ctx.p[:, 2]
        pw, ph, pb = PAPER
        pz0 = -SH + pb
        sheet = (np.abs(x) < pw / 2) & (z > pz0) & (z < pz0 + ph)
        band = ((np.abs(x) < pw / 2 + 0.025) & (z > pz0 - 0.025) & (z < pz0 + ph + 0.025)) & ~sheet
        band |= (np.abs(z - (-0.22)) < 0.02) | (np.abs(z - (-0.3)) < 0.012)
        s = A.silk(ctx, "silk_mount", 4.2, 1631, sheen=0.4)
        g = A.silk(ctx, "pig_ochre", 5.0, 1633, sheen=1.0)
        s.merge(A._select(g, band), band)
        pp = A.paper(ctx, 1635, "washi", 6.8)
        s.merge(A._select(pp, sheet), sheet)
        ppm = int(round(1.0 / ctx.texel))
        key = (char, ppm)
        if key not in _CAL:
            _CAL[key] = AP.calligraphy(int(round(pw * ppm)), int(round(ph * ppm)), char, seed=3)
        codes, rims = E.sample(_CAL[key], -x + pw / 2 if False else x + pw / 2, z - pz0, ctx.texel)
        codes = np.where(sheet & (ctx.n[:, 1] < -0.5), codes, 0).astype(np.int16)
        s = E.paint_over(ctx, s, codes, rims, 1637, flake=0.0, wear=0.0, inks=A.INKS)
        return s
    return fn


_CAL = {}


# --------------------------------------------------------------------------
# the bell
# --------------------------------------------------------------------------

BELL_TOP = 3.0                      # hook pin height
BS = 1.2                            # the bell is drawn at 1.5 m, then scaled
BELL_H = 1.5 * BS
FY = 1.6                            # front / back posts of the pavilion


def bell_part():
    p = Part("bell", origin=(0.0, 0.0, BELL_TOP), parent="temple_bell")
    # drawn with its crown at z = 0, scaled by BS, then hung under the pin
    z1, z0 = 0.0, -1.5
    prof = [(0.47, z0), (0.5, z0 + 0.04), (0.49, z0 + 0.2), (0.45, z0 + 0.6), (0.41, z0 + 1.0), (0.38, z0 + 1.3),
            (0.33, z0 + 1.45), (0.2, z1 - 0.01), (0.04, z1)]
    p.lathe(prof, "bell", segments=32, cap_bottom=False, cap_top=True)
    p.lathe([(0.44, z0 + 0.06), (0.4, z0 + 0.06)], "bell", segments=32, cap_bottom=False, cap_top=False)
    for zb, rb in ((z0 + 0.06, 0.505), (z1 - 0.25, 0.37)):
        p.lathe([(rb - 0.01, zb), (rb + 0.01, zb + 0.01), (rb + 0.01, zb + 0.13), (rb - 0.01, zb + 0.14)],
                "relief", segments=32, cap_bottom=False, cap_top=False)
    for k in range(4):
        a = math.tau * k / 4 + math.pi / 4
        for i in range(3):
            for j in range(3):
                aa = a + (i - 1) * 0.12
                zz = z1 - 0.38 - j * 0.1
                rr = 0.36 + (z1 - zz) * 0.05
                c = (rr * math.cos(aa), rr * math.sin(aa), zz)
                f = p.lathe([(0.042, 0.0), (0.045, 0.018), (0.03, 0.045), (0.01, 0.058)], "relief", segments=8,
                            cap_bottom=False, cap_top=True)
                p.move(f, T(*c) @ R('Z', math.degrees(aa) - 90) @ R('X', -90))
    for a in (math.pi / 2, -math.pi / 2):
        f = p.lathe([(0.12, 0.0), (0.13, 0.015), (0.09, 0.03), (0.04, 0.035)], "relief", segments=16,
                    cap_bottom=False, cap_top=True)
        p.move(f, T(0.47 * math.cos(a), 0.47 * math.sin(a), z0 + 0.42) @ R('Z', math.degrees(a) - 90) @ R('X', -90))
    p.tube([(-0.12, 0.0, z1 - 0.02), (-0.14, 0.0, z1 + 0.1), (-0.06, 0.0, z1 + 0.2), (0.06, 0.0, z1 + 0.19),
            (0.1, 0.0, z1 + 0.1), (0.13, 0.0, z1 + 0.02)], lambda t: 0.05 - 0.015 * abs(t - 0.5), "relief", sides=8)
    p.lathe([(0.05, z1), (0.045, z1 + 0.2), (0.06, z1 + 0.26), (0.04, z1 + 0.28)], "relief", segments=10,
            center=(-0.2, 0.0, 0.0), cap_bottom=False, cap_top=True)
    p.move(list(p.bm.faces), T(0.0, 0.0, BELL_TOP - 0.18 * BS) @ Matrix.Scale(BS, 4))
    K.seg(p, (0.0, -0.14, BELL_TOP), (0.0, 0.14, BELL_TOP), [(0.03, 0.0), (0.03, 1.0)], "iron", segments=8)
    return p


def striker():
    zz = BELL_TOP - 0.18 * BS - BELL_H + 0.42 * BS
    p = Part("striker", origin=(0.0, 1.2, BELL_TOP + 0.05), parent="temple_bell")
    K.seg(p, (0.0, 0.8, zz), (0.0, 2.25, zz), [(0.11, 0.0), (0.12, 0.1), (0.12, 0.9), (0.11, 1.0)], "log", segments=10)
    for y in (0.95, 1.5):
        p.tube([(0.0, y, zz + 0.1), (0.0, y, (zz + BELL_TOP) / 2), (0.0, y, BELL_TOP + 0.36)], 0.02, "rope", sides=5)
    return p


def bell_frame():
    """A four-post pavilion frame: red posts on stone bases, green beams with
    carved brackets, the hanger beam across the middle, the striker's beam
    running from it to the front."""
    p = Part("temple_bell")
    W = 2.8
    for sx in (-1, 1):
        for sy in (-1, 1):
            x, y = sx * W / 2, sy * FY
            p.box((x, y, 1.85), (0.24, 0.24, 3.7), "post", bevel=0.02)
            p.box((x, y, 0.15), (0.44, 0.44, 0.3), "stone", bevel=0.03)
            p.box((x, y, 0.32), (0.3, 0.3, 0.06), "stone", bevel=0.01)
            dou(p, x, y, 3.55, 0.3, 0.15, "beam")
    for sy in (-1, 1):
        p.box((0.0, sy * FY, 3.42), (W + 0.6, 0.26, 0.28), "beam", bevel=0.02)
        for sx in (-1, 1):
            f = front_prism(p, ccw([(0.0, 0.0), (0.0, -0.5), (0.06, -0.44), (0.14, -0.28), (0.26, -0.16),
                                    (0.4, -0.05), (0.45, 0.0)]), 0.12, "bracket", y_back=0.06)
            p.move(f, T(sx * (W / 2 - 0.12), sy * FY, 3.28) @ Matrix.Scale(-sx, 4, (1.0, 0.0, 0.0)))
            if sx > 0:
                for ff in f:
                    ff.normal_flip()
    for sx in (-1, 1):
        p.box((sx * W / 2, 0.0, 3.7), (0.26, 2 * FY + 0.6, 0.3), "beam", bevel=0.02)
    p.box((0.0, 0.0, 3.7), (W + 0.3, 0.32, 0.32), "beam", bevel=0.02)                 # hanger beam
    p.box((0.0, 0.0, BELL_TOP + 0.3), (0.34, 0.34, 0.48), "beam", bevel=0.02)          # the hanger block
    p.box((0.0, FY / 2 + 0.25, 3.46), (0.2, FY + 0.1, 0.18), "beam", bevel=0.02)      # striker beam
    _roof(p, W / 2 + 0.75, FY + 0.75, 3.86, 5.05, 0.9)
    return p


def _roof(p, hx, hy, z0, z1, ridge):
    """A hipped roof of grey tiles: front and back trapezoids up to a ridge
    of half-length ``ridge``, triangles at the ends, the eave corners
    turned up; metre UVs laid along each slope (tile rows run downhill)."""
    up = 0.18
    c = {(-1, -1): (-hx, -hy, z0 + up), (1, -1): (hx, -hy, z0 + up), (1, 1): (hx, hy, z0 + up),
         (-1, 1): (-hx, hy, z0 + up)}
    r0, r1 = (-ridge, 0.0, z1), (ridge, 0.0, z1)
    slope_y = math.hypot(hy, z1 - z0)
    slope_x = math.hypot(hx - ridge, z1 - z0)

    def face(pts, uvs, mat="tiles"):
        vs = [p.bm.verts.new(q) for q in pts]
        f = p._face(vs, mat)
        f.normal_update()
        if f.normal.z < 0:
            f.normal_flip()
            uvs = list(reversed(uvs))
            vs = list(reversed(vs))
        for loop in f.loops:
            loop[p.uv].uv = uvs[vs.index(loop.vert)]
        f[p.lock] = 1
        return f

    face([c[(-1, 1)], c[(1, 1)], r1, r0], [(0.0, 0.0), (2 * hx, 0.0), (hx + ridge, slope_y), (hx - ridge, slope_y)])
    face([c[(1, -1)], c[(-1, -1)], r0, r1], [(0.0, 0.0), (2 * hx, 0.0), (hx + ridge, slope_y), (hx - ridge, slope_y)])
    face([c[(1, 1)], c[(1, -1)], r1], [(0.0, 0.0), (2 * hy, 0.0), (hy, slope_x)])
    face([c[(-1, -1)], c[(-1, 1)], r0], [(0.0, 0.0), (2 * hy, 0.0), (hy, slope_x)])
    # soffit under the eaves (a flat ceiling of boards), ridge and hip rolls
    p.poly([c[(-1, -1)], c[(1, -1)], c[(1, 1)], c[(-1, 1)]], "soffit")
    p.tube([r0, r1], 0.09, "tiles", sides=6)
    for k in c:
        p.tube([c[k], r0 if k[0] < 0 else r1], 0.07, "tiles", sides=6, caps=False)


def bell_paint(ctx, seed=1641):
    """Dark bronze, thin green patina, the relief (bands, bosses, dragon,
    the flying celestials round the waist) rubbed warm."""
    z = ctx.p[:, 2]
    z0 = BELL_TOP - 0.18 * BS - BELL_H
    a = _ang(ctx)
    # flying celestials (bicheon): two figures painted as raised relief
    fig = np.zeros(ctx.N, bool)
    for a0 in (0.0, 0.5):
        da = np.mod(a - a0 + 0.5, 1.0) - 0.5
        u = da * 2 * math.pi * 0.5 / BS
        v = (z - (z0 + 0.85 * BS)) / BS
        body = (u / 0.07) ** 2 + (v / 0.18) ** 2 < 1.0
        scarf = (np.abs(v - 0.14 * np.sin(u * 12.0)) < 0.02) & (np.abs(u) < 0.26)
        head = np.hypot(u - 0.0, v - 0.2) < 0.045
        fig |= body | scarf | head
    rubbed = fig * 0.8
    s = A.bronze_patina(ctx, seed, crust=0.35, polish=0.4, rubbed=rubbed, dark=0.9)
    s.height = s.height + fig * 0.003
    return s


def build():
    out = []
    out.append(kit("bronze_ding", [ding()], {"bronze": bronze_fn(1651, 1.0, 0.55, 0.66, 0.3),
                                             "relief": bronze_fn(1653, 0.7, 0.55, 0.66, 0.307)},
                   ppm=256, ao_dist=0.12, built_final=True))
    out.append(kit("bronze_gu", [gu()], {"bronze": bronze_fn(1661, 1.0, 0.1, 0.155, 0.04),
                                         "relief": bronze_fn(1663, 0.7, 0.1, 0.155, 0.041)},
                   ppm=320, ao_dist=0.05, built_final=True))
    out.append(kit("vase_blue_white", [vase("vase_blue_white", MEIPING, "porcelain")], {"porcelain": meiping_paint},
                   ppm=320, ao_dist=0.06, built_final=True))
    out.append(kit("vase_celadon", [vase("vase_celadon", MAEBYEONG, "celadon")], {"celadon": celadon_paint},
                   ppm=320, ao_dist=0.06, built_final=True))
    out.append(kit("moon_jar", [moon_jar()], {"moon": moon_paint}, ppm=256, ao_dist=0.08, built_final=True))
    base = {"stave": lambda c: A.lacquer(c, 1671, ramp="lacquer_black", center=3.0, wear=0.2),
            "knob": lambda c: M.ivory(c, 1673), "cord": lambda c: A.silk(c, "pig_ochre", 4.0, 1675)}
    variants = {f"scroll_hanging_{tag}": {**base, "mount": scroll_paint(ch)}
                for tag, ch in (("water", "水"), ("moon", "月"), ("enso", "ensō"))}
    out.append(kit("scroll_hanging", [scroll()], {**base, "mount": scroll_paint("山")}, ppm=256, ground=None,
                   ao_dist=0.05, built_final=True, planes=(("y", 0.0),), variants=variants,
                   preview_elevation=4.0))
    frame_fns = {"post": lambda c: A.painted(c, "pig_red", 4.0, 1681, line="pig_ochre", flake=0.3),
                 "bracket": lambda c: A.painted(c, "pig_blue", 3.8, 1682, flake=0.3),
                 "beam": lambda c: A.painted(c, "pig_green", 3.8, 1683, flake=0.3),
                 "stone": lambda c: A.garden_stone(c, 1685, moss=0.2),
                 "bell": bell_paint, "relief": lambda c: A.bronze_patina(c, 1687, crust=0.3, polish=1.0, dark=0.3),
                 "tiles": lambda c: A.roof_tiles(c, 1692), "soffit": lambda c: A.painted(c, "pig_green", 3.0, 1693),
                 "iron": M.iron, "log": lambda c: A.wood(c, 1689, ramp="hinoki", center=4.4),
                 "rope": lambda c: A.braid(c, "pig_ochre", 4.0, 1691)}
    out.append(kit("temple_bell", [bell_frame(), bell_part(), striker()], frame_fns, ppm=96, ao_dist=0.3,
                   built_final=True, preview_closeup=((0.0, 0.6, 1.9), 1.1)))
    return out
