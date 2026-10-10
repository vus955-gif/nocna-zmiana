"""Floor I, the Temple of the Serpent (the Mexico gallery's arena): a
modular stepped platform in the manner of a Mesoamerican temple base -
sloping talud below, a framed tablero panel above (carved stepped frets and
bead columns, red field, turquoise relief), a coping on top - plus the
stair with serpent balustrades, the altar house on the upper terrace and
the low altars. 96 px/m.

  temple_tier_4m/2m/1m  face of a 1.5 m terrace (the greybox tier boxes):
                        wall-run frame - origin on the floor at the tier's
                        edge (the box face, z = 0), x = -W/2 .. W/2, the
                        face reaching 0.5 m out toward -Z, its coping flush
                        with the terrace top at y 1.5. The tablero pattern
                        has a 1 m cycle from the module's end: whole-metre
                        runs join seamlessly. Leave 0.5 m free at each
                        corner of a tier for temple_tier_corner.
  temple_tier_corner    outer corner: origin at the box corner on the floor,
                        two 0.5 m mitred arms along -X (the face looking -Z)
                        and along +Z (the face looking +X); turn it by
                        90 degree steps for the other corners.
  temple_stair          one flight 3 m wide, 1.5 m up over 4 m (10 steps of
                        0.15 x 0.40) in the frame of StairsSpec.frame()
                        (origin = middle of the bottom edge of the first
                        riser, -Z up the flight), with sloping balustrades
                        (alfardas) 0.45 m wide outside both sides carved
                        as the serpent's scaled body, crowned at the top;
                        part "serpent_heads" = the two open-jawed heads at
                        the foot (hide it for the upper flights).
  temple_shrine         the altar house on the upper terrace, 2.4 x 2.5 x
                        2.4 m: base, red stucco walls, a door 0.9 x 1.3 on
                        the front (-Z) with a carved lintel, a flat roof
                        crowned by stepped merlons; inside an ember bed:
                        marker "Light" (0, 0.6, 0.25) for the warm glow
                        spilling out of the door.
  temple_altar          low carved altar 1.6 x 1.2 x 1.6 with an ash basin
                        (cover on the side walks).
"""
import math

import numpy as np
from mathutils import Matrix, Vector

from artlib import americas as AM
from artlib import americas_paint as AP
from artlib import clay
from artlib import kit as K
from artlib import sculpt
from artlib import serpent_head as SH
from artlib.archkit import front_prism, kit, moulding
from artlib.geo import Part
from artlib.materials import P, _dither, _select

PPM = 96
TIER = 1.5
# terrace face profile: (depth out from the box face, height), bottom -> top
PROFILE = [(0.5, 0.0), (0.5, 0.06), (0.47, 0.08), (0.3, 0.72), (0.3, 0.76), (0.38, 0.76), (0.38, 0.86),
           (0.3, 0.86), (0.3, 1.26), (0.38, 1.26), (0.38, 1.38), (0.42, 1.4), (0.42, 1.5), (0.0, 1.5)]
# which slot each profile segment takes
SEG_SLOTS = ["stone", "stone", "talud", "stone", "frame", "frame", "frame", "panel", "frame", "frame", "frame",
             "cap", "cap"]
PANEL_Z = (0.86, 1.26)


# --------------------------------------------------------------------------
# paint
# --------------------------------------------------------------------------

_CANVAS = {}


def tablero_canvas():
    """96 x 38 px (1 m x 0.4 m): a rising and a hanging stepped fret, then a
    column of two beads; red field, turquoise relief, shell-white beads."""
    if "tab" in _CANVAS:
        return _CANVAS["tab"]
    W, H = 96, 38
    lv = np.zeros((H, W), np.int16)
    pt = np.full((H, W), AP.INK["red"], np.int16)
    for k, x in enumerate((4, 44)):
        m = AP.fret_unit(4, flip_v=bool(k % 2))
        y = (H - m.shape[0]) // 2
        AP.paste(lv, m, x, y, 2)
        AP.paste(pt, m, x, y, AP.INK["turq"])
    for k in range(2):
        b = AP.bead(10)
        AP.paste(lv, b, 83, 6 + k * 16, 2)
        AP.paste(pt, b, 83, 6 + k * 16, AP.INK["white"])
    lv[:, 80:82] = 1
    lv[:, 94:96] = 1
    _CANVAS["tab"] = (lv, pt, AP.relief_wrap_shade(lv))
    return _CANVAS["tab"]


def panel_paint(W):
    def fn(ctx):
        lv, pt, sh = tablero_canvas()
        u = ctx.uvm[:, 0] + W / 2.0
        v = ctx.p[:, 2] - PANEL_Z[0]
        idx = AM.canvas_index(lv.shape, u, v, ctx.texel, wrap_x=True)
        s = AM.stucco(ctx, 131, center=4.6)
        s = AM.relief(ctx, s, lv, sh, idx, depth=0.006, light=1.0)
        s = AM.paint_over(ctx, s, AM.take(pt, idx), 133, flake=0.3, wear=0.6)
        s.shade += AM.take(sh, idx, 0.0) * 0.8
        return s
    return fn


def frame_paint(ctx):
    s = AM.stucco(ctx, 135, center=4.8)
    return AM.paint_over(ctx, s, np.full(ctx.N, AP.INK["red"], np.int16), 137, flake=0.28, wear=1.2)


def talud_paint(ctx):
    """The sloping talud: dressed blocks with stucco and red wash."""
    return AM.am_stone_blocks(ctx, 139)


def stone_paint(seed=141, center=4.8):
    return lambda c: AM.volcanic(c, seed, center=center, vesicles=0.6)


def scales_paint(ctx):
    """The balustrade as the serpent's body: rows of overlapping scales on
    the sloping top and the outer face (u along the slope), turquoise on
    the stucco with red between, worn."""
    s = AM.stucco(ctx, 143, center=4.6)
    a = ctx.p[:, 1] * 0.94 + ctx.p[:, 2] * 0.35          # along the slope
    c = np.where(np.abs(ctx.n[:, 0]) > 0.5, ctx.p[:, 2], ctx.p[:, 0] * 2.0)
    size = 0.3
    row = np.floor(a / size).astype(np.int64)
    off = np.mod(row, 2) * size * 0.5
    col = np.floor((c + off) / size).astype(np.int64)
    fa = a / size - row
    fc = (c + off) / size - col
    rr = (fc - 0.5) ** 2 + (fa - 0.2) ** 2 * 0.7
    scale = rr < 0.2
    rim = (rr > 0.16) & scale
    codes = np.where(scale & ~rim, AP.INK["turq"], np.where(rim, AP.INK["red"], 0)).astype(np.int16)
    s = AM.paint_over(ctx, s, codes, 145, flake=0.55, wear=0.8)
    s.shade[rim] -= 0.8
    s.height = s.height + scale * 0.003 - rim * 0.002
    return s


def head_paint(ctx):
    """Carved stone heads with traces of paint: turquoise on the crown and
    ruff, red in the mouth, white fangs (shell slot apart)."""
    s = AM.volcanic(ctx, 147, center=5.2, vesicles=0.4)
    down = ctx.n[:, 2] < -0.3
    codes = np.where(down, AP.INK["red"], np.where(ctx.n[:, 2] > 0.4, AP.INK["turq"], 0)).astype(np.int16)
    return AM.paint_over(ctx, s, codes, 149, flake=0.55, wear=0.8)


def ruff_paint(ctx):
    s = AM.volcanic(ctx, 151, center=4.8, vesicles=0.3)
    return AM.paint_over(ctx, s, np.full(ctx.N, AP.INK["green"], np.int16), 153, flake=0.4, wear=1.0)


def face_uv(ctx):
    """(u, v) metres on vertical faces of an axis-aligned block (u along
    the face, left to right seen from outside; v = height)."""
    nx, ny = ctx.n[:, 0], ctx.n[:, 1]
    x, y = ctx.p[:, 0], ctx.p[:, 1]
    u = np.where(np.abs(nx) > np.abs(ny), np.where(nx > 0, y, -y), np.where(ny > 0, -x, x))
    return u, ctx.p[:, 2]


_ALT = {}


def altar_canvas():
    """128 x 77 px (1.33 x 0.8 m at 96 px/m): two cartouches with signs and
    a quincunx between, bead borders."""
    if "alt" in _ALT:
        return _ALT["alt"]
    W, H = 128, 77
    lv = np.zeros((H, W), np.int16)
    pt = np.full((H, W), AP.INK["red"], np.int16)
    br = AP.bead_row(W, 8, pitch=8, d=6)
    for y in (2, H - 10):
        lv[y:y + 8][br] = 2
        pt[y:y + 8][br] = AP.INK["white"]
    for k, name in enumerate(("flame", "water")):
        fr, gm = AP.cartouche(name, 34)
        x = 8 + k * 80
        AP.paste(lv, fr, x, 21, 2)
        AP.paste(lv, gm, x, 21, 3)
        AP.paste(pt, fr, x, 21, AP.INK["turq"])
        AP.paste(pt, gm, x, 21, AP.INK["black"])
    q = AP.quincunx(26)
    AP.paste(lv, q, 51, 25, 2)
    AP.paste(pt, q, 51, 25, AP.INK["ochre"])
    _ALT["alt"] = (lv, pt, AP.relief_wrap_shade(lv))
    return _ALT["alt"]


def altar_paint(half, z0):
    def fn(ctx):
        lv, pt, sh = altar_canvas()
        u, v = face_uv(ctx)
        idx = AM.canvas_index(lv.shape, u + half - 0.0, v - z0, ctx.texel)
        vertical = np.abs(ctx.n[:, 2]) < 0.5
        s = AM.volcanic(ctx, 155, center=4.8, vesicles=0.5)
        rows, cols, inside = idx
        idx = (rows, cols, inside & vertical)
        s = AM.relief(ctx, s, lv, sh, idx, depth=0.006, light=1.0)
        s = AM.paint_over(ctx, s, AM.take(pt, idx), 157, flake=0.45, wear=0.6)
        return s
    return fn


# --------------------------------------------------------------------------
# terraces
# --------------------------------------------------------------------------

def tier(W):
    p = Part("temple_tier")
    faces = moulding(p, [(-d, z) for d, z in PROFILE], W, "stone")
    for f, slot in zip(faces, SEG_SLOTS):
        f.material_index = p.slot(slot)
    return p


def tier_corner():
    p = Part("temple_tier_corner")
    path = [(-0.5, 0.0), (0.0, 0.0), (0.0, -0.5)]
    faces = p.sweep([(z, d) for d, z in PROFILE], path, "stone")
    n = len(PROFILE) - 1
    for k, f in enumerate(faces):
        f.material_index = p.slot(SEG_SLOTS[k % n])
    p.move(faces, Matrix.Rotation(math.radians(-90), 4, 'X'))
    return p


# --------------------------------------------------------------------------
# the stair
# --------------------------------------------------------------------------

STEPS, RISE, RUN = 10, 0.15, 0.4


def stair():
    p = Part("temple_stair")
    prof = [(0.0, 0.0)]
    for k in range(STEPS):
        prof += [(RUN * k, RISE * (k + 1)), (RUN * (k + 1), RISE * (k + 1))]
    moulding_y = [(y, z) for y, z in prof]
    p.extrude(moulding_y, -1.5, 1.5, "step", caps=False)
    for sx in (-1, 1):
        x = sx * (1.5 + 0.225)
        # the balustrade: a sloping slab outlined in (y, z), 0.45 thick
        outline = [(-0.2, 0.0), (4.0, 0.0), (4.0, 1.8), (3.55, 1.8), (-0.2, 0.42)]
        vs_a = [p.bm.verts.new((x - 0.225, y, z)) for y, z in outline]
        vs_b = [p.bm.verts.new((x + 0.225, y, z)) for y, z in outline]
        n = len(outline)
        faces = [p._face(vs_a, "scales"), p._face(list(reversed(vs_b)), "scales")]
        for i in range(n):
            j = (i + 1) % n
            slot = "scales" if (i == 3) else "stone"
            faces.append(p._face([vs_a[i], vs_a[j], vs_b[j], vs_b[i]], slot))
        centre = Vector((x, 1.9, 0.6))
        for f in faces:
            f.normal_update()
            if f.normal.dot(f.calc_center_median() - centre) < 0:
                f.normal_flip()
        # the crowning block at the top of the balustrade
        p.box((x, 3.775, 1.95), (0.5, 0.5, 0.3), "crown", bevel=0.02)
        p.box((x, 3.775, 2.13), (0.4, 0.4, 0.06), "crown", bevel=0.012)
    return p


def stair_heads():
    p = Part("serpent_heads")
    L = 1.0
    op = 22.0
    for sx in (-1, 1):
        x = sx * (1.5 + 0.225)
        m = Matrix.Translation(Vector((x, 0.35, 0.46))) @ Matrix.Rotation(math.pi, 4, 'Z')
        me = clay.clay_mesh(SH.upper(L) + SH.jaw(L, op), resolution=0.02)
        me = sculpt.decimate(me, 1300)
        clay.into_part(p, me, "head", transform=m)
        me = sculpt.metaball_mesh(SH.ruff(L, petals=11, skip_bottom=True), resolution=0.018)
        me = sculpt.decimate(me, 500)
        clay.into_part(p, me, "ruff", transform=m)
        (e1, e2), er, dirs = SH.eyes(L)
        for e, d in zip((e1, e2), dirs):
            f = K.sphere(p, e, er * 0.9, "eye", segments=10, rings=5)
            p.move(f, m)
        for root, d, ln in SH.fangs(L, op):
            f = K.cone(p, root, d, ln, 0.03, "fang", segments=6, tip=0.005)
            p.move(f, m)
    return p


# --------------------------------------------------------------------------
# the altar house and the altars
# --------------------------------------------------------------------------

def shrine():
    p = Part("temple_shrine")
    # built facing -Y (turned by kit()): the door on the -Y side
    p.box((0.0, 0.0, 0.15), (2.4, 2.4, 0.3), "stone", bevel=0.02)
    wt = 0.25
    zb, zt = 0.3, 1.9
    hw = 1.1
    p.box((0.0, hw - wt / 2, (zb + zt) / 2), (2.2, wt, zt - zb), "wall", bevel=0.015)
    for sx in (-1, 1):
        p.box((sx * (hw - wt / 2), 0.0, (zb + zt) / 2), (wt, 2.2 - 2 * wt, zt - zb), "wall", bevel=0.015)
    # the front with the door 0.9 x 1.3
    dw, dh = 0.9, 1.3
    jw = (2.2 - dw) / 2
    for sx in (-1, 1):
        p.box((sx * (dw / 2 + jw / 2), -hw + wt / 2, (zb + zt) / 2), (jw, wt, zt - zb), "wall", bevel=0.015)
    p.box((0.0, -hw + wt / 2 - 0.02, zb + dh + (zt - zb - dh) / 2), (dw + 0.3, wt + 0.06, zt - zb - dh), "lintel",
          bevel=0.012)
    # floor inside, the ember bed on a low hearth
    p.box((0.0, 0.25, 0.42), (0.7, 0.6, 0.24), "stone", bevel=0.02)
    p.box((0.0, 0.25, 0.545), (0.56, 0.46, 0.02), "embers")
    # roof slab and cornice
    p.box((0.0, 0.0, 1.98), (2.4, 2.4, 0.16), "roof", bevel=0.02)
    p.box((0.0, 0.0, 2.08), (2.2, 2.2, 0.05), "roof", bevel=0.01)
    # stepped merlons round the roof edge
    merlon = [(-0.13, 0.0), (0.13, 0.0), (0.13, 0.14), (0.09, 0.14), (0.09, 0.26), (0.05, 0.26), (0.05, 0.38),
              (-0.05, 0.38), (-0.05, 0.26), (-0.09, 0.26), (-0.09, 0.14), (-0.13, 0.14)]
    n = 4
    for side in range(4):
        rot = Matrix.Rotation(math.radians(90 * side), 4, 'Z')
        for k in range(n):
            x = -0.6 + k * 0.4
            f = front_prism(p, [(x + a, 2.105 + b) for a, b in merlon], 0.08, "merlon", y_back=-1.02)
            p.move(f, rot)
    return p


def altar():
    p = Part("temple_altar")
    p.box((0.0, 0.0, 0.075), (1.6, 1.6, 0.15), "stone", bevel=0.02)
    p.box((0.0, 0.0, 0.15 + 0.4), (1.36, 1.36, 0.8), "relief", bevel=0.015)
    p.box((0.0, 0.0, 1.025), (1.5, 1.5, 0.15), "stone", bevel=0.02)
    bowl = p.lathe([(0.42, 0.0), (0.45, 0.05), (0.46, 0.12), (0.4, 0.14), (0.36, 0.06), (0.0, 0.05)], "stone",
                   segments=16, center=(0.0, 0.0, 1.1), cap_bottom=False, cap_top=False)
    p.lathe([(0.0, 0.0), (0.36, 0.0)], "ash", segments=16, center=(0.0, 0.0, 1.16), cap_bottom=False, cap_top=False)
    return p


def ash(ctx, seed=161):
    s = AM.volcanic(ctx, seed, ramp="am_stucco", center=2.2, vesicles=0.0, tool=0.0)
    s.rough[:] = 0.95
    return s


def build():
    out = []
    tier_fns = {"stone": stone_paint(), "talud": talud_paint, "frame": frame_paint, "cap": stone_paint(163, 5.2)}
    for W, tag in ((4.0, "4m"), (2.0, "2m"), (1.0, "1m")):
        out.append(kit(f"temple_tier_{tag}", [tier(W)], {**tier_fns, "panel": panel_paint(W)}, ppm=PPM, wall=True,
                       preview=tag == "4m"))
    out.append(kit("temple_tier_corner", [tier_corner()], {**tier_fns, "panel": panel_paint(0.0)}, ppm=PPM,
                   built_final=True, preview_yaws=(-135.0, -90.0, 0.0, 45.0)))
    out.append(kit("temple_stair", [stair(), stair_heads()],
                   {"step": stone_paint(165, 5.0), "stone": stone_paint(167, 4.6), "scales": scales_paint,
                    "crown": lambda c: AM.paint_over(c, AM.stucco(c, 169), np.full(c.N, AP.INK["turq"], np.int16), 171,
                                                     flake=0.4),
                    "head": head_paint, "ruff": ruff_paint, "eye": lambda c: AM.obsidian(c, 173),
                    "fang": lambda c: AM.shell(c, 175)},
                   ppm=PPM, built_final=True, organic=("serpent_heads",), ao_dist=0.4,
                   preview_yaws=(150.0, 200.0, 225.0, 120.0), preview_elevation=18.0,
                   preview_extra=[("head", (1.72, -0.2, 0.35), 0.75, 200.0, 10.0)]))
    out.append(kit("temple_shrine", [shrine()],
                   {"stone": stone_paint(177, 4.6), "wall": lambda c: AM.red_plaster(c, 179, center=4.6),
                    "lintel": altar_paint(0.6, 1.6), "roof": stone_paint(181, 4.2),
                    "merlon": lambda c: AM.paint_over(c, AM.stucco(c, 183, center=5.4),
                                                      np.full(c.N, AP.INK["white"], np.int16), 185, flake=0.3),
                    "embers": lambda c: AM.embers(c, 187, 1.0)},
                   ppm=PPM, ao_dist=0.5, markers=[("Light", (0.0, 0.25, 0.6), None)],
                   preview_yaws=(-30.0, 30.0, 150.0, 210.0)))
    out.append(kit("temple_altar", [altar()], {"stone": stone_paint(189, 4.6), "relief": altar_paint(0.68, 0.15),
                                               "ash": ash}, ppm=PPM, ao_dist=0.4))
    return out
