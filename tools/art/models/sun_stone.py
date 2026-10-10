"""Floor I, Mexico gallery: a great carved stone disc in the manner of the
Mexica calendar stones - a stylisation, NOT a copy of the Sun Stone: a calm
sun face at the centre, four rounded panels with spirals round it, a ring
of twenty cartouches with abstract signs, a ring of beads, eight great and
eight small rays, and two serpents whose segmented bodies run round the rim
to meet head to head at the bottom (their tails meet under a square
cartouche at the top). Dark basalt with worn traces of ochre, turquoise,
red and white paint.

  sun_stone  disc 3.6 m across, 0.5 m thick, stood upright in a stepped
             basalt cradle 2.6 x 0.5 x 1.1 m with a brass label "DYSK
             SŁONECZNY / MEKSYK"; 4.05 m tall in all. Kit convention
             (origin = centre of the base, front = Godot -Z). 128 px/m.
"""
import math

import numpy as np
from mathutils import Matrix, Vector

from artlib import americas as AM
from artlib import americas_paint as AP
from artlib import materials as M
from artlib import pixelfont
from artlib.archkit import cull_floor, kit
from artlib.geo import Part
from artlib.materials import P, _select

R = 1.8
CZ = 2.25          # centre of the disc above the floor
PPM = 128
# the face profile: (radius, forward height), outside -> centre
PROFILE = [(1.8, 0.0), (1.8, 0.38), (1.78, 0.42), (1.47, 0.44), (1.45, 0.4), (1.43, 0.4), (1.42, 0.43),
           (1.06, 0.43), (1.05, 0.45), (0.95, 0.45), (0.94, 0.41), (0.61, 0.41), (0.6, 0.45), (0.33, 0.46),
           (0.31, 0.5), (0.2, 0.55), (0.04, 0.568)]


def disc():
    p = Part("sun_stone_disc")
    prof = [(r, h) for r, h in PROFILE]
    f = p.lathe(prof, "face", segments=64, cap_bottom=False, cap_top=True, smooth=False)
    p.lathe([(1.8, 0.0), (0.0, -0.02)], "back", segments=64, cap_bottom=False, cap_top=False)
    p.move(list(p.bm.faces), Matrix.Translation(Vector((0.0, -0.35, CZ))) @ Matrix.Rotation(math.radians(-90), 4, 'X'))
    return p


def cradle():
    p = Part("sun_stone")
    p.box((0.0, 0.0, 0.08), (2.6, 1.1, 0.16), "base", bevel=0.015)
    p.box((0.0, 0.05, 0.36), (2.3, 0.9, 0.4), "base", bevel=0.015)
    for sx in (-1, 1):
        # two chocks holding the disc's foot
        p.box((sx * 0.75, 0.2, 0.7), (0.4, 0.62, 0.36), "base", bevel=0.02)
    p.box((0.0, -0.4 - 0.006, 0.36), (0.6, 0.012, 0.16), "plaque", bevel=0.003)
    cull_floor([p])
    return p


# --------------------------------------------------------------------------
# the carving, painted on a square canvas (128 px/m, 461 px across)
# --------------------------------------------------------------------------

_C = {}


def rotate_paste(lv, pt, mask, cx, cy, ang, level, code):
    """Pastes ``mask`` turned by ``ang`` (radians, about its centre) at canvas
    centre (cx, cy), nearest-pixel sampling."""
    h, w = mask.shape
    r = int(math.ceil(math.hypot(h, w) / 2)) + 1
    ys, xs = np.mgrid[-r:r + 1, -r:r + 1]
    ca, sa = math.cos(-ang), math.sin(-ang)
    mx = xs * ca - ys * sa + (w - 1) / 2
    my = xs * sa + ys * ca + (h - 1) / 2
    ix = np.round(mx).astype(int)
    iy = np.round(my).astype(int)
    ok = (ix >= 0) & (ix < w) & (iy >= 0) & (iy < h)
    hit = np.zeros(ok.shape, dtype=bool)
    hit[ok] = mask[iy[ok], ix[ok]]
    X = int(round(cx)) + xs
    Y = int(round(cy)) + ys
    inside = hit & (X >= 0) & (X < lv.shape[1]) & (Y >= 0) & (Y < lv.shape[0])
    lv[Y[inside], X[inside]] = level
    if code is not None:
        pt[Y[inside], X[inside]] = code


def canvas():
    if "c" in _C:
        return _C["c"]
    N = int(round(2 * R * PPM)) | 1
    c0 = (N - 1) / 2.0
    yy, xx = np.mgrid[0:N, 0:N]
    dx = (xx - c0) / PPM
    dy = (c0 - yy) / PPM                    # up
    r = np.hypot(dx, dy)
    th = np.mod(np.arctan2(dx, dy), 2 * np.pi)   # 0 at the top, clockwise
    lv = np.zeros((N, N), np.int16)
    pt = np.zeros((N, N), np.int16)
    # --- outer serpents (1.45 - 1.78) ----------------------------------
    band = (r > 1.47) & (r < 1.77)
    seg = np.mod(th * 40 / (2 * np.pi), 1.0)
    lv[band] = 2
    pt[band] = AP.INK["turq"]
    tabs = band & (seg < 0.18)
    lv[tabs] = 1
    pt[tabs] = AP.INK["red"]
    mid = band & (np.abs(r - 1.62) < 0.018)
    lv[mid] = 1
    pt[mid] = AP.INK["white"]
    # flame tabs on the outer edge
    flames = (r > 1.72) & (r < 1.78) & (np.mod(th * 80 / (2 * np.pi), 1.0) < 0.5)
    lv[flames] = 3
    pt[flames] = AP.INK["red"]
    # the two heads at the bottom (around th = pi), facing each other
    for side in (-1, 1):
        hc = math.pi + side * 0.2
        hx = c0 + math.sin(hc) * 1.6 * PPM
        hy = c0 - math.cos(hc) * 1.6 * PPM
        head = (np.hypot(xx - hx, yy - hy) < 0.2 * PPM)
        lv[head] = 3
        pt[head] = AP.INK["turq"]
        eye = np.hypot(xx - (hx + side * -6), yy - (hy - 8)) < 7
        lv[eye] = 2
        pt[eye] = AP.INK["white"]
        pupil = np.hypot(xx - (hx + side * -6), yy - (hy - 8)) < 3
        lv[pupil] = 1
        pt[pupil] = AP.INK["black"]
        jaw = head & (np.abs((yy - hy) - (xx - hx) * side * 0.4 - 10) < 3)
        lv[jaw] = 1
        pt[jaw] = AP.INK["red"]
        for k in range(4):
            tooth = (np.abs(xx - (hx - side * (8 - k * 5))) < 1.5) & (np.abs(yy - (hy + 6)) < 3) & head
            lv[tooth] = 3
            pt[tooth] = AP.INK["white"]
    # the square cartouche where the tails meet, at the top
    tq = (np.abs(dx) < 0.17) & (np.abs(dy - 1.6) < 0.17)
    lv[tq] = 3
    pt[tq] = AP.INK["ochre"]
    fr, gm = AP.cartouche("bars3", 36)
    AP.paste(lv, fr, int(c0 - 18), int(c0 - 1.6 * PPM - 18), 2)
    AP.paste(pt, fr, int(c0 - 18), int(c0 - 1.6 * PPM - 18), AP.INK["turq"])
    AP.paste(lv, gm, int(c0 - 18), int(c0 - 1.6 * PPM - 18), 2)
    AP.paste(pt, gm, int(c0 - 18), int(c0 - 1.6 * PPM - 18), AP.INK["black"])
    # --- rays (1.05 - 1.43) ---------------------------------------------
    ring = (r > 1.06) & (r < 1.42)
    lv[ring] = 1
    pt[ring] = AP.INK["red"]
    for k in range(16):
        big = k % 2 == 0
        a0 = k * 2 * math.pi / 16
        half = (0.17 if big else 0.08)
        da = np.angle(np.exp(1j * (th - a0)))
        t = (r - 1.06) / (1.4 - 1.06)
        tri = ring & (np.abs(da) < half * (1.0 - t)) & (t < (1.0 if big else 0.7))
        lv[tri] = 2
        pt[tri] = AP.INK["ochre"]
        rim = ring & (np.abs(np.abs(da) - half * (1.0 - t)) < 0.012) & (t < (1.0 if big else 0.7))
        lv[rim] = 3
        pt[rim] = AP.INK["ochre"]
    # small feather marks between the rays
    feath = ring & (np.mod(th * 64 / (2 * np.pi), 1.0) < 0.25) & (r > 1.36)
    lv[feath] = 2
    pt[feath] = AP.INK["white"]
    # --- bead ring (0.95 - 1.05) ------------------------------------------
    br = (r > 0.95) & (r < 1.05)
    lv[br] = 1
    pt[br] = AP.INK["red"]
    for k in range(48):
        a = k * 2 * math.pi / 48
        bx = c0 + math.sin(a) * 1.0 * PPM
        by = c0 - math.cos(a) * 1.0 * PPM
        d = np.hypot(xx - bx, yy - by)
        bead = d < 4.5
        lv[bead] = 2
        pt[bead] = AP.INK["white"]
        lv[d < 1.5] = 1
    # --- twenty cartouches (0.6 - 0.95) ----------------------------------
    cr = (r > 0.61) & (r < 0.94)
    lv[cr] = 1
    pt[cr] = AP.INK["red"]
    names = list(AP.SIGNS)
    for k in range(20):
        a = (k + 0.5) * 2 * math.pi / 20
        cx = c0 + math.sin(a) * 0.775 * PPM
        cy = c0 - math.cos(a) * 0.775 * PPM
        fr, gm = AP.cartouche(names[k % len(names)], 26)
        rotate_paste(lv, pt, fr, cx, cy, a, 2, AP.INK["turq"])
        rotate_paste(lv, pt, gm, cx, cy, a, 3, AP.INK["white"])
    # --- four panels with spirals (0.33 - 0.6) ----------------------------
    inner = (r > 0.33) & (r < 0.6)
    lv[inner] = 1
    pt[inner] = AP.INK["red"]
    for k in range(4):
        a = math.pi / 4 + k * math.pi / 2
        px = c0 + math.sin(a) * 0.46 * PPM
        py = c0 - math.cos(a) * 0.46 * PPM
        panel = (np.abs((xx - px) * math.cos(a) + (yy - py) * math.sin(a)) < 16) & \
                (np.abs(-(xx - px) * math.sin(a) + (yy - py) * math.cos(a)) < 16)
        lv[panel & inner] = 2
        pt[panel & inner] = AP.INK["turq"]
        sp = AP.scale_up(AP.sign("spiral"), 2)
        rotate_paste(lv, pt, sp, px, py, a, 3, AP.INK["white"])
    for k in range(4):
        a = k * math.pi / 2
        dx_ = c0 + math.sin(a) * 0.47 * PPM
        dy_ = c0 - math.cos(a) * 0.47 * PPM
        dot = np.hypot(xx - dx_, yy - dy_) < 7
        lv[dot] = 2
        pt[dot] = AP.INK["ochre"]
    # --- the sun face (r < 0.33) ------------------------------------------
    face = r < 0.32
    lv[face] = 2
    pt[face] = AP.INK["ochre"]
    for sx in (-1, 1):
        ex, ey = c0 + sx * 0.1 * PPM, c0 - 0.05 * PPM
        d = np.hypot(xx - ex, yy - ey)
        lv[d < 7] = 3
        pt[d < 7] = AP.INK["white"]
        lv[d < 3] = 1
        pt[d < 3] = AP.INK["black"]
        brow = (np.abs(yy - (ey - 11)) < 2) & (np.abs(xx - ex) < 10)
        lv[brow] = 3
        ear = np.hypot(xx - (c0 + sx * 0.27 * PPM), yy - c0) < 8
        lv[ear] = 3
        pt[ear] = AP.INK["turq"]
    nose = (np.abs(xx - c0) < (4 + (yy - (c0 - 6)) * 0.4)) & (yy > c0 - 6) & (yy < c0 + 8)
    lv[nose] = 3
    mouth = (np.abs(xx - c0) < 12) & (np.abs(yy - (c0 + 0.13 * PPM)) < 2.5)
    lv[mouth] = 1
    pt[mouth] = AP.INK["red"]
    band_ = face & (np.abs(r - 0.26) < 0.025) & (dy > 0.1)
    lv[band_] = 3
    pt[band_] = AP.INK["turq"]
    _C["c"] = (lv, pt, AP.relief_shade(lv))
    return _C["c"]


def face_paint(ctx):
    lv, pt, sh = canvas()
    x = ctx.p[:, 0] + R
    z = ctx.p[:, 2] - CZ + R
    front = ctx.n[:, 1] > 0.3
    idx = AM.canvas_index(lv.shape, x, z, ctx.texel)
    rows, cols, inside = idx
    idx = (rows, cols, inside & front)
    s = AM.basalt(ctx, 1801, center=4.6, polish=0.1, vesicles=0.5)
    s = AM.relief(ctx, s, lv, sh, idx, depth=0.006, light=1.2)
    codes = AM.take(pt, idx)
    lvl = AM.take(lv, idx)
    # only traces of the paint survive: little on the raised carving, more
    # in the sunk fields
    rub = ctx.fbm(3.5, 3, 1804) + ctx.fbm(14.0, 2, 1806) * 0.3
    codes = np.where((lvl >= 2) & (rub > -0.05), 0, codes)
    codes = np.where((lvl < 2) & (rub > 0.05), 0, codes)
    s = AM.paint_over(ctx, s, codes, 1803, flake=0.7, wear=0.4, fade=1.2)
    # an old break across the lower right rim: rougher, darker, unpainted
    rr = np.hypot(ctx.p[:, 0], ctx.p[:, 2] - CZ)
    brk = (ctx.p[:, 0] > 0.9) & (ctx.p[:, 2] < CZ - 0.9) & (rr > 1.25) & (ctx.fbm(3.0, 3, 1805) > -0.15)
    s.use_ramp(P["am_basalt"], mask=brk, shade=np.full(ctx.N, 3.4) + ctx.fbm(20.0, 2, 1807) * 1.2)
    s.height = np.where(brk, ctx.fbm(14.0, 3, 1809) * 0.004, s.height)
    return s


_TX = {}


def plaque(ctx):
    s = M.brass(ctx, 1811)
    front = ctx.n[:, 1] > 0.5
    if "t" not in _TX:
        _TX["t"] = pixelfont.trim(pixelfont.render(["DYSK SŁONECZNY", "MEKSYK"], line_gap=2))
    if front.any():
        u, v = ctx.uvm[:, 0], ctx.uvm[:, 1]
        ink = pixelfont.stamp(ctx, _TX["t"], np.median(u[front]), np.median(v[front]), scale=1) & front
        s.use_ramp(P["am_obsidian"], mask=ink, shade=np.full(ctx.N, 1.0))
        s.metal = np.where(ink, 0.0, s.metal)
    return s


def build():
    parts = [cradle(), disc()]
    # the cradle is built facing -Y, the disc facing +Y: turn the cradle only
    import bmesh
    rot = Matrix.Rotation(math.pi, 4, 'Z')
    bmesh.ops.transform(parts[0].bm, matrix=rot, verts=parts[0].bm.verts[:])
    return kit("sun_stone", parts, {"face": face_paint, "back": lambda c: AM.basalt(c, 1813, center=3.6),
                                    "base": lambda c: AM.basalt(c, 1815, center=3.0, polish=0.3, vesicles=0.3),
                                    "plaque": plaque},
               ppm=PPM, built_final=True, ground=0.0, ao_dist=0.3,
               preview_yaws=(-30.0, 0.0, 30.0, 150.0), preview_elevation=6.0,
               preview_extra=[("centre", (0.0, 0.4, CZ), 0.9, 0.0, 0.0), ("rim", (1.0, 0.4, CZ - 1.2), 0.8, 20.0, 5.0)])
