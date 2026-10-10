"""Floor I, Americas and Oceania wing kit: the horizontal bands of the
walls in 4 / 2 / 1 / 0.5 m run modules (x = -W/2 .. W/2, wall plane z = 0,
mouldings on the room side = Godot -Z). The flat wall between the bands is
the shell with the tile field "am_red_wall" (Mexico, North America, the
totems) or "am_woven_mat" / "boards_pacific" (Pacific).

  americas_dado_*    1.28 m dado of polished black basalt (jointed every
                     metre) on a basalt toe, a shell-white fillet, a 0.31 m
                     strip of turquoise stepped frets inlaid in obsidian
                     black (0.5 m cycle: modules join seamlessly) and a
                     basalt cap. 96 px/m. Datum = floor.
  americas_frieze_*  carved stone frieze: a 1 m face mapped with the world
                     tile "am_frieze" between a stepped ledge below and a
                     stepped drip moulding above (they overhang 0.08 m).
                     Datum = the bottom edge of the face, on a whole metre
                     (e.g. 5.0) so the band lines up with the tile.
  americas_cornice_* stepped cornice 0.9 m tall, 0.5 m deep: a red-painted
                     talud, a row of carved stepped blocks every 0.25 m, a
                     turquoise-painted fascia and a basalt crown. Datum =
                     ceiling (origin at its TOP).
  pacific_dado_*     1.4 m dado of the Pacific gallery: plaited pandanus
                     panels framed by carved dark-wood rails and posts
                     every 0.5 m, a lashed top rail. 96 px/m. Datum = floor.
  pacific_beam_*     painted rafter 0.32 x 0.42 m (4 / 2 / 1 m): red,
                     black and white triangles and chevrons on dark wood,
                     coir lashing at both ends. Datum = ceiling (origin at
                     its top centre); lay them across the gallery every 2 m.
  pacific_post       carved wall post 0.7 x 4.0 x 0.32: notched zigzag
                     bands, a squat ancestor figure in relief with shell
                     eyes, flat back on the wall plane. Scale Y to the room.
"""
import math

import numpy as np

from artlib import clay
from artlib import americas as AM
from artlib import americas_paint as AP
from artlib.archkit import LENGTHS, kit, moulding
from artlib import kit as K
from artlib.geo import Part
from artlib.materials import P, _dither, smoothstep

PPM_DADO = 96


# --------------------------------------------------------------------------
# paint
# --------------------------------------------------------------------------

def basalt_jointed(W, pitch=1.0, polish=0.55, center=3.0):
    def fn(ctx):
        s = AM.basalt(ctx, 61, center=center, polish=polish, vesicles=0.35)
        u = ctx.uvm[:, 0] + W / 2.0
        vertical = np.abs(ctx.n[:, 2]) < 0.5
        m = (np.mod(u + 1e-4, pitch) < ctx.texel) & vertical
        s.shade[m] -= 2.4
        s.height = s.height - m * 0.002
        return s
    return fn


_FRET = {}


def fret_inlay(W, ppm=PPM_DADO):
    """Turquoise stepped frets on obsidian black (canvas period 0.5 m),
    sampled from the module's left end so every module joins its neighbour."""
    def fn(ctx):
        key = ppm
        if key not in _FRET:
            h = int(round(0.3125 * ppm))
            _FRET[key] = AP.fret_strip(int(round(0.5 * ppm)), h, t=3)
        lv, pt = _FRET[key]
        idx = AM.canvas_index(lv.shape, ctx.uvm[:, 0] + W / 2.0, ctx.uvm[:, 1], ctx.texel, wrap_x=True)
        codes = AM.take(pt, idx, AP.INK["black"])
        lvl = AM.take(lv, idx)
        turq = codes == AP.INK["turq"]
        s = AM.obsidian(ctx, 71, center=1.6)
        rim = AM.take(AP.relief_wrap_shade(lv), idx, 0.0)
        s.use_ramp(P["am_turq"], mask=turq, shade=np.full(ctx.N, 6.2) + rim * 1.2 + _dither(ctx, 0.9, 72)
                   - (1.0 - ctx.ao) * 3.0)
        s.rough[turq] = 0.28
        s.metal[turq] = 0.0
        white = codes == AP.INK["white"]
        sh = AM.shell(ctx, 75, center=5.6)
        s.merge(_select(sh, white), white)
        s.height = s.height + lvl * 0.0015
        return s
    return fn


def _select(s, mask):
    from artlib.materials import _select as sel
    return sel(s, mask)


def stone(seed=81, center=5.0):
    return lambda c: AM.volcanic(c, seed, center=center, vesicles=0.5)


def painted_stone(code, seed=83, flake=0.45):
    """Andesite with a worn coat of one paint (red, turquoise, ochre)."""
    def fn(ctx):
        s = AM.volcanic(ctx, seed, center=4.8, vesicles=0.4)
        codes = np.full(ctx.N, code, np.int16)
        return AM.paint_over(ctx, s, codes, seed + 1, flake=flake, wear=1.2)
    return fn


# --------------------------------------------------------------------------
# Mexico: dado, frieze, cornice
# --------------------------------------------------------------------------

def dado(W):
    p = Part("americas_dado")
    moulding(p, [(-0.16, 0.0), (-0.16, 0.14), (-0.145, 0.16), (-0.13, 0.16)], W, "toe")
    moulding(p, [(-0.13, 0.16), (-0.13, 0.86)], W, "panel")
    fil = [(-0.13, 0.86)]
    for i in range(1, 6):
        a = -math.pi / 2 + math.pi * i / 6
        fil.append((-0.13 - 0.022 * math.cos(a), 0.88 + 0.02 * math.sin(a)))
    fil.append((-0.13, 0.9))
    moulding(p, fil, W, "fillet")
    moulding(p, [(-0.13, 0.9), (-0.13, 1.2125)], W, "fret")
    moulding(p, [(-0.13, 1.2125), (-0.165, 1.2125), (-0.17, 1.22), (-0.17, 1.27), (-0.16, 1.28), (0.0, 1.28)], W,
             "toe")
    return p


def frieze(W):
    p = Part("americas_frieze")
    # stepped ledge under the face
    moulding(p, [(0.0, -0.16), (-0.06, -0.16), (-0.06, -0.08), (-0.1, -0.08), (-0.1, -0.015), (-0.09, 0.0),
                 (-0.04, 0.0)], W, "ledge")
    moulding(p, [(-0.04, 0.0), (-0.04, 1.0)], W, "band")
    # stepped drip moulding over it
    moulding(p, [(-0.04, 1.0), (-0.09, 1.0), (-0.1, 1.015), (-0.1, 1.08), (-0.06, 1.08), (-0.06, 1.16),
                 (0.0, 1.16)], W, "ledge")
    return p


def cornice(W):
    p = Part("americas_cornice")
    H = 0.9
    z0 = -H
    # talud (sloping) painted red, then a flat band, the block row, fascia, crown
    moulding(p, [(0.0, z0), (-0.06, z0), (-0.16, z0 + 0.22)], W, "talud")
    moulding(p, [(-0.16, z0 + 0.22), (-0.16, z0 + 0.34)], W, "band_red")
    moulding(p, [(-0.16, z0 + 0.34), (-0.2, z0 + 0.34), (-0.2, z0 + 0.58)], W, "fascia")
    moulding(p, [(-0.2, z0 + 0.58), (-0.32, z0 + 0.6), (-0.42, z0 + 0.66), (-0.42, z0 + 0.82), (-0.46, z0 + 0.84),
                 (-0.46, 0.0), (0.0, 0.0)], W, "crown")
    # carved stepped blocks (merlon-like, hanging) every 0.25 m on the band
    n = int(round(W / 0.25))
    for k in range(n):
        x = -W / 2 + 0.125 + k * 0.25
        p.box((x, -0.2, z0 + 0.3), (0.16, 0.08, 0.1), "block", bevel=0.01)
        p.box((x, -0.21, z0 + 0.22), (0.1, 0.1, 0.08), "block", bevel=0.01)
    return p


# --------------------------------------------------------------------------
# Pacific: dado, beams, post
# --------------------------------------------------------------------------

def pacific_dado(W):
    p = Part("pacific_dado")
    moulding(p, [(-0.1, 0.0), (-0.1, 0.18), (-0.085, 0.2), (-0.04, 0.2)], W, "rail")
    moulding(p, [(-0.04, 0.2), (-0.04, 1.2)], W, "mat")
    moulding(p, [(-0.04, 1.2), (-0.11, 1.2), (-0.12, 1.215), (-0.12, 1.385), (-0.11, 1.4), (0.0, 1.4)], W, "rail")
    # posts every 0.5 m between the panels (at the module ends and between)
    n = int(round(W / 0.5))
    for k in range(n + 1):
        x = -W / 2 + k * 0.5
        w = 0.06 if k in (0, n) else 0.1
        cx = x + (w / 2 if k == 0 else (-w / 2 if k == n else 0.0))
        p.box((cx, -0.065, 0.7), (w, 0.05, 1.0), "post", bevel=0.008)
    # lashing bands round the top rail at each post
    for k in range(n + 1):
        x = -W / 2 + k * 0.5
        if k in (0, n):
            continue
        p.box((x, -0.115, 1.3), (0.06, 0.03, 0.2), "lash", bevel=0.006)
    return p


def mat_panel(ctx):
    return AM.am_woven_mat(ctx, 931)


def pacific_wood(seed=91, center=4.4):
    return lambda c: AM.carved_wood(c, seed, ramp="am_wood_dark", center=center, adze=0.6)


def beam(W):
    p = Part("pacific_beam")
    p.box((0.0, 0.0, -0.21), (W, 0.32, 0.42), "beam", bevel=0.02)
    if W >= 1.0:
        for sx in (-1, 1):
            x = sx * (W / 2 - 0.22)
            p.box((x, 0.0, -0.21), (0.14, 0.35, 0.45), "lash", bevel=0.015)
    return p


def beam_paint(W):
    """Rafter painting: along each side a band of alternating red and black
    triangles between white lines, the soffit a chevron run; the wood
    shows at the edges."""
    def fn(ctx):
        s = AM.carved_wood(ctx, 93, ramp="am_wood_dark", center=4.0, adze=0.4)
        x = ctx.p[:, 0] + W / 2.0
        y = ctx.p[:, 1]
        z = ctx.p[:, 2]
        nz = ctx.n[:, 2]
        side = np.abs(nz) < 0.5
        soffit = nz < -0.5
        tx = ctx.texel
        codes = np.zeros(ctx.N, np.int16)
        v = (z + 0.42) / 0.42                      # 0 bottom .. 1 top of the side
        band = side & (v > 0.18) & (v < 0.82)
        cell = 0.12
        k = np.floor(x / cell).astype(np.int64)
        fx = x / cell - k
        vv = (v - 0.18) / 0.64
        up = (np.mod(k, 2) == 0)
        tri = np.where(up, vv < 1.0 - np.abs(fx - 0.5) * 2.0, vv > np.abs(fx - 0.5) * 2.0)
        codes[band & tri] = AP.INK["red"]
        codes[band & ~tri] = AP.INK["black"]
        line = side & ((np.abs(v - 0.18) < tx / 0.42 * 1.0) | (np.abs(v - 0.82) < tx / 0.42 * 1.0))
        codes[line] = AP.INK["white"]
        # soffit: chevrons pointing along the beam
        a = np.mod(x / 0.16 + np.abs(y) / 0.16, 1.0)
        codes[soffit & (a < 0.35) & (np.abs(y) < 0.12)] = AP.INK["white"]
        codes[soffit & (a >= 0.35) & (a < 0.6) & (np.abs(y) < 0.12)] = AP.INK["red"]
        return AM.paint_over(ctx, s, codes, 95, flake=0.2, wear=0.8)
    return fn


def post():
    p = Part("pacific_post")
    H = 4.0
    # the plank: flat back on the wall (y = 0), front rounded a little
    prof = []
    for i in range(7):
        a = math.pi * i / 6
        prof.append((0.35 * math.cos(a), -0.24 - 0.06 * math.sin(a)))
    pts = list(reversed([(0.35, 0.0)] + prof + [(-0.35, 0.0)]))      # counter-clockwise from above
    p.ngon_prism([(x, y) for x, y in pts], 0.0, H, "post", bevel=0.01)
    # notched zigzag bands: rows of small wedges standing out
    for zb in (0.35, 3.0, 3.65):
        for k in range(7):
            x = -0.3 + k * 0.1
            p.box((x, -0.31, zb), (0.07, 0.04, 0.12), "notch", bevel=0.01, rot=_rot_y(45.0))
    return p


def post_figure():
    """A squat ancestor figure carved in high relief on the post: a great
    head with round shell eyes and an open mouth, arms bent to the belly,
    short bent legs; sculpted in clay and cut flat behind (the plank)."""
    from artlib import sculpt
    from artlib.sculpt import blob, limb
    p = Part("pacific_post_figure")
    y0 = -0.26
    b = [blob((0.0, y0, 2.18), (0.25, 0.12, 0.22)),                 # head
         blob((0.0, y0 - 0.06, 2.27), (0.24, 0.07, 0.045)),         # brow ridge
         blob((0.0, y0 - 0.09, 2.16), (0.05, 0.06, 0.08)),          # nose
         blob((0.0, y0 - 0.05, 2.02), (0.13, 0.05, 0.05)),          # lips
         blob((0.0, y0 - 0.085, 2.02), (0.09, 0.04, 0.025), neg=True, stiff=1.4),   # the open mouth
         blob((0.0, y0, 1.95), (0.1, 0.06, 0.06)),                  # chin
         blob((0.0, y0 + 0.01, 1.87), (0.12, 0.07, 0.1)),           # neck
         blob((0.0, y0, 1.55), (0.21, 0.1, 0.3)),                   # body
         blob((0.0, y0 - 0.05, 1.4), (0.13, 0.07, 0.12))]           # belly
    for sx in (-1, 1):
        b.append(blob((sx * 0.1, y0 - 0.07, 2.17), (0.075, 0.04, 0.06), neg=True, stiff=1.5))   # eye sockets
        b.append(blob((sx * 0.235, y0, 2.15), (0.04, 0.05, 0.08)))                            # ears
        b += limb([(sx * 0.2, y0, 1.72), (sx * 0.27, y0 - 0.03, 1.5), (sx * 0.1, y0 - 0.08, 1.4)],
                  [0.06, 0.055, 0.05], spacing=0.6)
        b.append(blob((sx * 0.06, y0 - 0.1, 1.42), (0.06, 0.04, 0.04)))                       # hands
        b += limb([(sx * 0.1, y0, 1.25), (sx * 0.22, y0 - 0.05, 1.05), (sx * 0.13, y0 - 0.03, 0.82)],
                  [0.07, 0.065, 0.055], spacing=0.6)
        b.append(blob((sx * 0.15, y0 - 0.06, 0.78), (0.08, 0.06, 0.035)))                     # feet
    me = sculpt.metaball_mesh(b, resolution=0.012)
    sculpt.cut(me, [((0.0, -0.25, 0.0), (0.0, 1.0, 0.0))])
    me = sculpt.decimate(me, 1500)
    clay.into_part(p, me, "figure")
    for sx in (-1, 1):
        K.sphere(p, (sx * 0.1, y0 - 0.045, 2.17), 0.065, "eye", segments=12, rings=5, squash=(1.0, 0.35),
                 zscale=0.75)
        K.sphere(p, (sx * 0.1, y0 - 0.068, 2.17), 0.022, "pupil", segments=10, rings=4, squash=(1.0, 0.3))
    return p


def paua(ctx, seed=125):
    """Iridescent abalone shell inlay: blue-green shifting with the tilt,
    pearly bands."""
    s = AM.mosaic(ctx, seed, "am_turq_green", cell=0.02, center=4.6, mix=0.5, mix_ramp="am_blue", gap_texels=0.3)
    tilt = 1.0 - np.abs(ctx.n[:, 1])
    s.shade += np.sin(ctx.p[:, 2] * 180.0 + tilt * 6.0) * 0.9 + tilt * 1.5
    s.rough[:] = 0.15
    return s


def _rot_y(deg):
    from mathutils import Matrix
    return Matrix.Rotation(math.radians(deg), 3, 'Y')


def build():
    out = []
    for W, tag in LENGTHS:
        show = tag == "4m"
        out.append(kit(f"americas_dado_{tag}", [dado(W)],
                       {"toe": stone(85, 3.4), "panel": basalt_jointed(W), "fillet": lambda c: AM.shell(c, 87),
                        "fret": fret_inlay(W)}, ppm=PPM_DADO, wall=True, preview=show))
        out.append(kit(f"americas_frieze_{tag}", [frieze(W)], {"ledge": stone(89, 4.8)}, wall=True, ground=None,
                       kinds={"band": "tile:am_frieze"}, preview=show))
        out.append(kit(f"americas_cornice_{tag}", [cornice(W)],
                       {"talud": painted_stone(AP.INK["red"], 97, 0.22), "band_red": painted_stone(AP.INK["red"], 99, 0.15),
                        "fascia": painted_stone(AP.INK["turq"], 101, 0.25), "crown": stone(103, 3.6),
                        "block": painted_stone(AP.INK["white"], 105, 0.35)},
                       wall=True, ground=None, ceiling=0.0, ao_dist=0.4, preview=show))
        out.append(kit(f"pacific_dado_{tag}", [pacific_dado(W)],
                       {"rail": pacific_wood(107, 4.6), "mat": mat_panel, "post": pacific_wood(109, 3.8),
                        "lash": lambda c: AM.rope(c, 111)}, ppm=PPM_DADO, wall=True, preview=show))
        if W >= 1.0:
            out.append(kit(f"pacific_beam_{tag}", [beam(W)], {"beam": beam_paint(W), "lash": lambda c: AM.rope(c, 113)},
                           ground=None, ceiling=0.0, ao_dist=0.3, preview=show))
    out.append(kit("pacific_post", [post(), post_figure()],
                   {"post": pacific_wood(115, 4.4), "notch": pacific_wood(117, 5.0),
                    "figure": lambda c: AM.carved_wood(c, 119, ramp="am_wood_dark", center=5.0, adze=0.8),
                    "eye": paua, "pupil": lambda c: AM.obsidian(c, 123)},
                   ppm=96, wall=True, organic=("pacific_post_figure",), preview_yaws=(-30.0, 30.0, 0.0, 90.0),
                   preview_elevation=8.0, preview_extra=[("figure", (0.0, 0.3, 1.7), 0.75, 20.0, 5.0)]))
    return out
