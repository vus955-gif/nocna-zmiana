"""Assyrian wing: fittings, gates and props (kit convention unless noted).

  asy_torch           torch lamp: bronze wall plate with a lion mask, a curved
                      arm, a bronze cup and a flame of glowing glass. Fixture:
                      origin = the light (the flame), the mount runs 0.35 m in
                      Godot +Z to the wall; marker Light. Hang at ~3.4 m.
  asy_brazier         bronze tripod on lion paws with a bowl of embers and a
                      flame, 1.35 m; origin on the floor, marker Light (flame).
  asy_balawat_leaf_l  a leaf of the Balawat gates (Shalmaneser III), 2 x 5 m:
  asy_balawat_leaf_r  cedar boards on a round pivot post, seven bronze bands
                      beaten in two registers each (soldiers marching, chariots,
                      archers, lions) with rosette-headed nails; the gate of
                      the Wing Seal: a bronze half-disc socket with spread
                      wings on each leaf's meeting stile, marker SealSocket
                      (also seal_socket) on _l. Door leaf frame: origin = centre
                      of the leaf's base, decorated face +Z (room A, Assyria),
                      _l hinged at -X (post), _r the mirror.
  asy_tablet_shelf    museum storeroom shelving 2 x 2.2 x 0.5 m crammed with
                      clay tablets, trays and paper tags.
  asy_tablet_crate    an open packing crate of tablets in straw ("NINIWA").
  asy_prism           Sennacherib's hexagonal clay prism (0.38 m) on a wooden
                      stand with a brass label; a lore find for the tablet store.
"""
import math

import numpy as np
from mathutils import Matrix, Vector

from artlib import arch_materials as A
from artlib import asy, asy_mesh as AM, asy_relief as rl
from artlib import asy_figures as F
from artlib import materials as M
from artlib.archkit import kit
from artlib.asy import P
from artlib.geo import Part
from artlib.kit import keep
from artlib.materials import Surface, _dither


def _rot_x(deg):
    return Matrix.Rotation(math.radians(deg), 4, 'X')


# --------------------------------------------------------------------------
# lights
# --------------------------------------------------------------------------

def torch():
    """Built in the final frame: Blender -Y = Godot +Z (to the wall)."""
    p = Part("asy_torch")
    wall = -0.35
    p.box((0, wall + 0.012, -0.24), (0.15, 0.024, 0.32), "bronze", bevel=0.008)
    lion = p.lathe([(0.0, 0.0), (0.055, 0.0), (0.05, 0.02), (0.03, 0.04), (0.0, 0.045)], "bronze", segments=10)
    p.move(lion, Matrix.Translation((0, wall + 0.024, -0.2)) @ _rot_x(90))
    p.tube([(0, wall + 0.03, -0.3), (0, -0.22, -0.31), (0, -0.08, -0.29), (0, 0.0, -0.24)], 0.016, "bronze",
           sides=6)
    p.lathe([(0.015, -0.27), (0.04, -0.245), (0.075, -0.19), (0.095, -0.12), (0.1, -0.1), (0.085, -0.095)],
            "bronze", segments=12, center=(0, 0, 0))
    for k in range(8):
        a = math.tau * k / 8
        p.box((math.cos(a) * 0.098, math.sin(a) * 0.098, -0.13), (0.012, 0.012, 0.05), "bronze")
    tongue = p.lathe([(0.075, -0.1), (0.084, -0.05), (0.07, 0.02), (0.05, 0.08), (0.042, 0.12), (0.026, 0.18),
                      (0.012, 0.25), (0.004, 0.29)], "flame", segments=8, center=(0, 0, 0),
                     ring_scale=lambda i, j: 1.0 + 0.22 * math.sin(i * 2.4 + j * 1.3))
    for v in {v for f in tongue for v in f.verts}:
        v.co.x += 0.02 * math.sin(v.co.z * 14.0) * max(v.co.z, 0.0) * 4.0
    return p


def brazier():
    p = Part("asy_brazier")
    for k in range(3):
        a = math.tau * k / 3 + math.pi / 2
        top = (math.cos(a) * 0.14, math.sin(a) * 0.14, 1.02)
        mid = (math.cos(a) * 0.24, math.sin(a) * 0.24, 0.5)
        foot = (math.cos(a) * 0.3, math.sin(a) * 0.3, 0.07)
        p.tube([top, mid, foot], 0.022, "bronze", sides=6)
        paw = p.lathe([(0.0, 0.0), (0.05, 0.0), (0.05, 0.03), (0.03, 0.06), (0.0, 0.065)], "bronze", segments=8,
                      center=(foot[0] * 1.08, foot[1] * 1.08, 0.0))
        p.box((foot[0] * 1.16, foot[1] * 1.16, 0.02), (0.05, 0.05, 0.04), "bronze", bevel=0.01)
    p.lathe([(0.17, 0.48), (0.2, 0.5), (0.17, 0.52)], "bronze", segments=12, cap_bottom=False, cap_top=False)
    p.lathe([(0.04, 0.98), (0.12, 1.02), (0.24, 1.1), (0.3, 1.2), (0.31, 1.24), (0.27, 1.22)], "bronze", segments=14)
    p.lathe([(0.27, 1.2), (0.2, 1.23), (0.0, 1.24)], "embers", segments=14, cap_bottom=False)
    for k, (x, y, s_) in enumerate(((0.0, 0.0, 1.0), (0.09, 0.05, 0.6), (-0.07, -0.06, 0.7))):
        p.lathe([(0.11 * s_, 1.22), (0.1 * s_, 1.3), (0.06 * s_, 1.42 + 0.06 * s_), (0.02 * s_, 1.5 + 0.08 * s_),
                 (0.006, 1.53 + 0.1 * s_)], "flame", segments=8, center=(x, y, 0.0))
    return p


def _embers(ctx):
    s = Surface(ctx.N)
    f1, _, cid = ctx.worley(40.0, 5)
    hot = np.clip(1.0 - f1 * 3.0, 0.0, 1.0)
    s.use_ramp(P["asy_flame"], shade=1.0 + hot * 4.5 + _dither(ctx, 0.8, 6))
    s.emit = s.colors() * hot[:, None]
    s.rough = np.full(ctx.N, 0.8)
    return s


# --------------------------------------------------------------------------
# the Balawat gate leaves
# --------------------------------------------------------------------------

LEAF_W, LEAF_H, LEAF_T = 2.0, 5.0, 0.2
BANDS = [0.45 + k * 0.68 for k in range(7)]       # band centres (z)
BAND_H = 0.27
SOCKET_Z, SOCKET_R = 1.47, 0.18
# the seal's spread wing (leaf coordinates u, v of the _l leaf; u = +1 is the meeting edge)
WING = [(0.98, SOCKET_Z + 0.05), (0.8, SOCKET_Z + 0.14), (0.6, SOCKET_Z + 0.2), (0.42, SOCKET_Z + 0.22),
        (0.38, SOCKET_Z + 0.16), (0.44, SOCKET_Z + 0.1), (0.4, SOCKET_Z + 0.05), (0.48, SOCKET_Z),
        (0.46, SOCKET_Z - 0.05), (0.56, SOCKET_Z - 0.08), (0.7, SOCKET_Z - 0.1), (0.86, SOCKET_Z - 0.08),
        (0.98, SOCKET_Z - 0.04)]


def _strip(R, v0, h):
    """A thin canvas over rows of R (same columns): small figures are drawn
    there, much faster than over the whole leaf, then pasted (_paste)."""
    v0 = math.floor(v0 * R.ppm) / R.ppm
    return rl.Relief(R.w_m, math.ceil(h * R.ppm) / R.ppm, R.ppm, u0=R.u0, v0=v0, seed=R.seed)


def _paste(R, S):
    h, mat, cov = S.compose(base=False)
    r0 = int(round((R.v0 + R.h_m - (S.v0 + S.h_m)) * R.ppm))
    r1 = min(R.H, r0 + S.H)
    R.base[r0:r1] = np.where(cov[:r1 - r0], np.maximum(R.base[r0:r1], h[:r1 - r0]), R.base[r0:r1])


def balawat_relief(seed=901):
    """The seven bronze bands of a leaf, drawn in leaf coordinates (u
    across the face, v up): each band two registers of tiny figures
    between rows of rosette-headed nails, and the spread wings of the seal
    socket."""
    R = rl.Relief(LEAF_W + 0.36, LEAF_H, 160, u0=-LEAF_W / 2 - 0.2, v0=0.0, seed=seed)
    kinds = ["army", "chariots", "archers", "lions", "army", "chariots", "army"]
    for k, zc in enumerate(BANDS):
        b0, b1 = zc - BAND_H / 2, zc + BAND_H / 2
        # raised fillets between and around the registers, rows of nails
        for v in (b0 + 0.014, zc, b1 - 0.014):
            R.base_put(R.box((0.0, v), 2.0, 0.006), 0.004)
        for v in (b0 + 0.014, b1 - 0.014):
            for i in range(26):
                u = -LEAF_W / 2 - 0.12 + i * (LEAF_W + 0.24) / 25
                d = R.circle((u, v), 0.012)
                R.base = np.where(d < 0, R.base + 0.004 * np.sqrt(np.clip(1 - (np.hypot(R.X - u, R.Y - v) / 0.012) ** 2, 0, 1)), R.base)
        for reg, (v0, kind) in enumerate(((b0 + 0.024, kinds[k]), (zc + 0.008, kinds[(k + 3) % 7]))):
            facing = 1 if (k + reg) % 2 == 0 else -1
            S = _strip(R, v0 - 0.012, 0.13)
            if kind == "army":
                for i in range(15):
                    F.warrior(F.Pen(S, rl.Xf(-1.08 + i * 0.155, v0, 0.05, facing), depth=0.3), stride=1.0)
            elif kind == "archers":
                for i in range(12):
                    F.archer(F.Pen(S, rl.Xf(-1.04 + i * 0.19, v0, 0.05, facing), depth=0.3))
            elif kind == "chariots":
                for i in range(6):
                    F.chariot(F.Pen(S, rl.Xf(-0.86 + i * 0.4 + 0.12 * facing, v0 + 0.004, 0.032, facing), depth=0.3))
            else:
                for i in range(7):
                    F.lion(F.Pen(S, rl.Xf(-0.95 + i * 0.32, v0, 0.09, facing), depth=0.3),
                           pose="leap" if i % 2 else "walk")
            _paste(R, S)
    # the Wing Seal: spread wings on the meeting stile (u = +1 is the meeting edge of _l)
    wing = list(reversed(WING))
    S = _strip(R, SOCKET_Z - 0.16, 0.42)
    pen = F.Pen(S, rl.Xf(0.0, 0.0, 1.0, 1), default="wing", depth=0.5)
    F.wing(pen, wing, (0.98, SOCKET_Z), (0.42, SOCKET_Z + 0.18), "wing", 0.008, covert=0.42, feather=0.035,
           scale=0.03)
    _paste(R, S)
    return R, wing


def _cedar_boards(ctx, seed=911):
    s = asy.cedar(ctx, seed=seed, center=4.4)
    u = ctx.p[:, 0]
    vertical = np.abs(ctx.n[:, 2]) < 0.5
    gap = (np.mod(u + 1.0, 0.25) < ctx.texel) & vertical & (np.abs(ctx.n[:, 0]) < 0.5)
    s.shade = np.where(gap, 0.5, s.shade)
    s.height = s.height - gap * 0.002
    return s


def balawat_leaf(name, side):
    """side -1: _l (post at -X), +1: _r (post at +X). Final frame: the
    decorated face toward Blender -Y (Godot +Z)."""
    p = Part(name)
    sx = side
    # the leaf: its decorated face in the atlas, back, edges, battens and post
    # in object-mapped cedar planks (tilelocal: the pattern swings with it)
    x0, x1, y0, y1 = -LEAF_W / 2, LEAF_W / 2, -LEAF_T / 2, LEAF_T / 2
    for pts, want, slot in (
            ([(x0, y0, 0), (x1, y0, 0), (x1, y0, LEAF_H), (x0, y0, LEAF_H)], (0, -1, 0), "cedar"),
            ([(x0, y1, 0), (x1, y1, 0), (x1, y1, LEAF_H), (x0, y1, LEAF_H)], (0, 1, 0), "cedar_back"),
            ([(x0, y0, 0), (x0, y1, 0), (x0, y1, LEAF_H), (x0, y0, LEAF_H)], (-1, 0, 0), "cedar_back"),
            ([(x1, y0, 0), (x1, y1, 0), (x1, y1, LEAF_H), (x1, y0, LEAF_H)], (1, 0, 0), "cedar_back"),
            ([(x0, y0, LEAF_H), (x1, y0, LEAF_H), (x1, y1, LEAF_H), (x0, y1, LEAF_H)], (0, 0, 1), "cedar_back"),
            ([(x0, y0, 0), (x1, y0, 0), (x1, y1, 0), (x0, y1, 0)], (0, 0, -1), "cedar_back")):
        f = p.poly(pts, slot)[0]
        f.normal_update()
        if f.normal.dot(Vector(want)) < 0:
            f.normal_flip()
    # back battens (Godot -Z side)
    for z in (0.6, 2.5, 4.4):
        p.box((0, LEAF_T / 2 + 0.03, z), (LEAF_W - 0.1, 0.06, 0.22), "cedar_back", bevel=0.01)
    # the pivot post
    post_x = sx * LEAF_W / 2
    p.lathe([(0.13, -0.06), (0.13, LEAF_H + 0.12), (0.1, LEAF_H + 0.16), (0.0, LEAF_H + 0.17)], "cedar_back",
            segments=12, center=(post_x, 0.0, 0.0))
    p.lathe([(0.15, -0.06), (0.15, 0.06), (0.13, 0.08)], "bronze", segments=12, center=(post_x, 0.0, 0.0),
            cap_bottom=False)
    # bronze bands across the face, wrapping round the post
    y_f = -LEAF_T / 2
    for zc in BANDS:
        z0, z1 = zc - BAND_H / 2, zc + BAND_H / 2
        x0, x1 = -LEAF_W / 2, LEAF_W / 2
        p.box((0, y_f - 0.004, zc), (LEAF_W, 0.008, BAND_H), "band_edge")
        f = p.poly([(x0, y_f - 0.0082, z0), (x1, y_f - 0.0082, z0), (x1, y_f - 0.0082, z1), (x0, y_f - 0.0082, z1)],
                   "band")[0]
        f.normal_update()
        if f.normal.y > 0:
            f.normal_flip()
        ring = p.lathe([(0.138, z0), (0.138, z1)], "band_edge", segments=12, center=(post_x, 0.0, 0.0),
                       cap_bottom=False, cap_top=False)
    # the seal: half a bronze disc with a recess on the meeting stile, wings
    mx = -sx * LEAF_W / 2
    disc = p.lathe([(0.0, 0.0), (SOCKET_R, 0.0), (SOCKET_R, 0.022), (SOCKET_R - 0.03, 0.038), (0.1, 0.038),
                    (0.085, 0.02), (0.0, 0.02)], "socket", segments=16, phase=math.pi / 16)
    p.move(disc, Matrix.Translation((mx, y_f - 0.002, SOCKET_Z)) @ _rot_x(90))
    keep(p, disc, lambda c: (c.x - mx) * side > -1e-4)
    # the spread wings of the seal, a bronze plate on the face
    AM.cap(p, [WING], y_f - 0.006, "band", -1, mirror=side > 0)
    AM.walls(p, WING, y_f, y_f - 0.006, "band_edge", outward=True, mirror=side > 0)
    return p


# --------------------------------------------------------------------------
# the tablet store
# --------------------------------------------------------------------------

def tablet_shelf(seed=921):
    """Pre-turn frame (front -Y). Uprights, five shelves, tablets in rows."""
    p = Part("asy_tablet_shelf")
    W, H, D = 2.0, 2.2, 0.5
    for x in (-W / 2 + 0.03, 0.0, W / 2 - 0.03):
        p.box((x, 0, H / 2), (0.05, D, H), "wood", bevel=0.006)
    shelves = [0.08, 0.5, 0.92, 1.34, 1.76, 2.17]
    for z in shelves:
        p.box((0, 0, z), (W, D, 0.03), "wood")
    p.box((0, D / 2 - 0.01, H / 2), (W, 0.02, H), "back")
    rng = np.random.default_rng(seed)
    for si, z in enumerate(shelves[:-1]):
        for bay in (-1, 1):
            x = bay * 0.5 - 0.44 + 0.02
            end = bay * 0.5 + 0.44
            mode = rng.integers(3)
            count = 0
            while x < end - 0.06 and count < 5:
                count += 1
                w = 0.05 + rng.random() * 0.1
                if mode == 0:        # standing on edge in a row
                    h = 0.08 + rng.random() * 0.1
                    p.box((x + 0.012, -0.05 + rng.random() * 0.06, z + 0.015 + h / 2), (0.024 + rng.random() * 0.01, w + 0.03, h),
                          "clay", rot=Matrix.Rotation(rng.random() * 0.2 - 0.1, 3, 'Y'))
                    x += 0.07 + rng.random() * 0.04
                elif mode == 1:      # lying flat in stacks
                    stack = 1 + rng.integers(2)
                    for k in range(stack):
                        p.box((x + w / 2, -0.06 + rng.random() * 0.04, z + 0.015 + 0.012 + k * 0.025),
                              (w, 0.08 + rng.random() * 0.06, 0.024), "clay",
                              rot=Matrix.Rotation(rng.random() * 0.3 - 0.15, 3, 'Z'))
                    x += w + 0.02
                else:                # a card tray with fragments
                    tw = min(0.3, end - x - 0.02)
                    if tw < 0.12:
                        break
                    p.box((x + tw / 2, -0.04, z + 0.035), (tw, 0.24, 0.04), "card")
                    for k in range(min(4, int(tw / 0.06))):
                        p.box((x + 0.04 + k * 0.055, -0.04 + (rng.random() - 0.5) * 0.1, z + 0.06),
                              (0.045, 0.05, 0.016), "clay", rot=Matrix.Rotation(rng.random(), 3, 'Z'))
                    x += tw + 0.03
            # a paper tag on the shelf edge
            tx_ = bay * 0.5 + (rng.random() - 0.5) * 0.4
            f = p.poly([(tx_ - 0.04, -D / 2 - 0.002, z - 0.016), (tx_ + 0.04, -D / 2 - 0.002, z - 0.016),
                        (tx_ + 0.04, -D / 2 - 0.002, z + 0.009), (tx_ - 0.04, -D / 2 - 0.002, z + 0.009)], "tag")[0]
            f.normal_update()
            if f.normal.y > 0:
                f.normal_flip()
    return p


def _tag(ctx):
    s = M.label(ctx, center=6.6, size=0.003)
    s.rough[:] = 0.9
    return s


def tablet_crate(seed=931):
    p = Part("asy_tablet_crate")
    W, H, D = 0.9, 0.48, 0.6
    t = 0.02
    p.box((0, 0, 0.02), (W, D, 0.04), "wood", bevel=0.004)
    for sx in (-1, 1):
        p.box((sx * (W / 2 - t / 2), 0, H / 2), (t, D, H), "wood", bevel=0.004)
    for sy in (-1, 1):
        p.box((0, sy * (D / 2 - t / 2), H / 2), (W, t, H), "crate_side" if sy < 0 else "wood", bevel=0.004)
    p.box((0, 0, H - 0.12), (W - 2 * t, D - 2 * t, 0.02), "straw")
    rng = np.random.default_rng(seed)
    for k in range(9):
        x = -0.32 + (k % 3) * 0.28 + (rng.random() - 0.5) * 0.06
        y = -0.18 + (k // 3) * 0.18 + (rng.random() - 0.5) * 0.04
        p.box((x, y, H - 0.1), (0.14, 0.1, 0.03), "clay",
              rot=Matrix.Rotation(rng.random() * 0.6 - 0.3, 3, 'Z') @ Matrix.Rotation(rng.random() * 0.4 - 0.2, 3, 'X'))
    return p


def _crate_side(ctx):
    s = A.sign_text(ctx, [("NINIWA", 0.24, 0.006, 0.0), ("BRIT.MUS. 1850", 0.13, 0.0045, 0.0)],
                    ground="cardboard", ground_center=4.0, ink="asy_paint_black", ink_center=1.5, border=False)
    w = M.wood_oak(ctx, seed=83)
    ink = s.ramp_id != s.ramp_id.min()
    w.use_ramp(P["asy_paint_black"], mask=ink, shade=np.full(ctx.N, 1.6))
    return w


def _straw(ctx):
    s = Surface(ctx.N)
    along = ctx.fbm(np.array([2.0, 40.0, 40.0]), 2, 3)
    s.use_ramp(A.P["straw"], shade=3.0 + along * 2.0 + _dither(ctx, 1.2, 4))
    s.rough = np.full(ctx.N, 0.9)
    return s


def prism():
    """Final frame (front = Blender +Y = Godot -Z). Origin on the floor."""
    p = Part("asy_prism")
    p.box((0, 0, 0.03), (0.5, 0.34, 0.06), "wood", bevel=0.01)
    p.box((0, 0.13, 0.085), (0.36, 0.08, 0.05), "wood", bevel=0.006, rot=Matrix.Rotation(math.radians(-30), 3, 'X'))
    f = p.poly([(-0.16, 0.172, 0.072), (0.16, 0.172, 0.072), (0.16, 0.148, 0.114), (-0.16, 0.148, 0.114)],
               "label")[0]
    f.normal_update()
    if f.normal.y < 0:
        f.normal_flip()
    p.lathe([(0.075, 0.06), (0.085, 0.08), (0.088, 0.4), (0.078, 0.425), (0.0, 0.43)], "clay", segments=6,
            smooth=False, phase=math.pi / 6)
    return p


def _label(ctx):
    s = A.sign_text(ctx, [("691 P.N.E.", 0.083, 1.0 / 256.0, 0.0)], ground="brass", ground_center=6.5,
                    ink="asy_paint_black", ink_center=1.5, border=False)
    s.metal[:] = 0.9
    s.rough[:] = 0.35
    return s


def build():
    out = []
    out.append(kit("asy_torch", [torch()], {"bronze": asy.bronze_aged, "flame": lambda c: asy.flame(c, strength=1.0)},
                   ppm=192, built_final=True, ground=None, ao_dist=0.08, markers=[("Light", (0.0, 0.0, 0.03), None)],
                   preview_closeup=((0.0, -0.1, -0.05), 0.3)))
    out.append(kit("asy_brazier", [brazier()], {"bronze": asy.bronze_aged, "embers": _embers,
                                                 "flame": lambda c: asy.flame(c, strength=1.0)},
                   ppm=160, built_final=True, ao_dist=0.15, markers=[("Light", (0.0, 0.0, 1.38), None)]))
    R, _wing = balawat_relief()
    maps = asy.ReliefMaps(R)
    for name, side in (("asy_balawat_leaf_l", -1), ("asy_balawat_leaf_r", 1)):
        uv = (lambda c: (c.p[:, 0], c.p[:, 2])) if side < 0 else (lambda c: (-c.p[:, 0], c.p[:, 2]))
        fns = {"cedar": _cedar_boards, "band": asy.relief_bronze(maps, uv=uv),
               "band_edge": lambda c: asy.bronze_aged(c, center=4.6), "bronze": asy.bronze_aged,
               "socket": lambda c: asy.bronze_aged(c, center=6.0, green=0.4)}
        markers = []
        if side < 0:
            markers = [("SealSocket", (LEAF_W / 2, -LEAF_T / 2 - 0.045, SOCKET_Z), None),
                       ("seal_socket", (LEAF_W / 2, -LEAF_T / 2 - 0.045, SOCKET_Z), None)]
        out.append(kit(name, [balawat_leaf(name, side)], fns, kinds={"cedar_back": "tilelocal:asy_cedar"}, ppm=160,
                       built_final=True, ao_dist=0.2, ao_rays=8,
                       markers=markers, preview=side < 0, preview_yaws=(180.0 - 25.0, 180.0 + 25.0, 90.0, 0.0),
                       preview_extra=[("bands", (0.0, -0.1, 1.5), 0.6, 180.0, 4.0)] if side < 0 else []))
    out.append(kit("asy_tablet_shelf", [tablet_shelf()],
                   {"wood": lambda c: M.wood_oak(c), "back": lambda c: M.wood_oak(c, seed=71), "clay": asy.clay,
                    "card": lambda c: M.cardboard(c, center=5.4), "tag": _tag}, ppm=128, ao_dist=0.2, ao_rays=8))
    out.append(kit("asy_tablet_crate", [tablet_crate()],
                   {"wood": lambda c: M.wood_oak(c, seed=83), "crate_side": _crate_side, "straw": _straw,
                    "clay": asy.clay}, ppm=128, ao_dist=0.15))
    out.append(kit("asy_prism", [prism()], {"wood": M.wood_dark, "label": _label,
                                            "clay": lambda c: asy.clay(c, line=0.011)},
                   ppm=256, built_final=True, ao_dist=0.08, preview_closeup=((0.0, 0.0, 0.25), 0.16)))
    return out
