"""Floor I, the Assyrian wing's Nimrud gallery: the conservators' scaffold
at the far end (the second fuse waits on their trolley beside it).

  asy_scaffold  a two-bay tube-and-fitting scaffold along the end wall:
                six galvanised standards on base plates and timber sole
                boards, ledgers and transoms in right-angle couplers,
                facade braces on both long faces and the ends, a half-
                boarded storage lift at 1 m (sacks of plaster, archive
                boxes), the working deck at 2 m of banded scaffold boards
                with toe boards and two guard rails; an aluminium ladder up
                the room side, a dust sheet thrown over the top rail, the
                conservators' bucket, toolbox and a work lamp on a tripod
                aimed at the wall, a sign on the rail (KONSERWACJA / NIE
                WCHODZIC). 1.2 x 3.2 x 4.0 m (Godot x, y, z) in the greybox
                box; its collision is drawn from it (Floor1Art.FIT_COLLISION).
                96 px/m.

Kit convention: origin = the middle of the footprint on the floor; built
front +Y in Blender (= Godot -Z); the room is on its +X side (the wall on -X).
"""
import math

import numpy as np
from mathutils import Matrix

from artlib import arch_materials as AM
from artlib import kit as K
from artlib import materials as M
from artlib import pixelfont as PF
from artlib import roof_materials as RM
from artlib.archkit import kit
from artlib.geo import Part
from artlib.materials import P, _dither, _wood_core, smoothstep

TUBE = 0.024
SX = 0.5                     # the standards stand at x = +-SX
SY = (-1.85, 0.0, 1.85)      # ... and along y
LIFT = 1.0                   # the storage lift
DECK = 2.0                   # the working deck (the boards' top)
RAIL_MID, RAIL_TOP = 2.5, 3.05
TOP = 3.2
SIGN = (SX + 0.085, -0.92, RAIL_MID - 0.18)   # the sign's middle (in front of the braces)


def _tube(p, a, b, r=TUBE, mat="tube"):
    K.seg(p, a, b, [(r, 0.0), (r, 1.0)], mat, segments=6, caps=False)


def _coupler(p, x, y, z, along="y"):
    size = (0.07, 0.06, 0.06) if along == "x" else (0.06, 0.07, 0.06)
    p.box((x, y, z), size, "coupler")


def frame(p):
    for x in (-SX, SX):
        for y in SY:
            _tube(p, (x, y, 0.012), (x, y, TOP))
            p.box((x, y, 0.045), (0.15, 0.15, 0.006), "coupler")
            K.seg(p, (x, y, 0.045), (x, y, 0.11), [(TUBE + 0.006, 0.0), (TUBE + 0.006, 1.0)], "coupler", segments=6)
    for y in SY:
        p.box((0.0, y, 0.021), (1.18, 0.22, 0.042), "sole")
    # ledgers along both faces: the kicker, the lift, the deck, the guard rails
    y0, y1 = SY[0] - 0.1, SY[-1] + 0.1
    for x in (-SX, SX):
        dx = 0.03 if x > 0 else -0.03
        for z in (0.2, LIFT - 0.06, DECK - 0.1, RAIL_MID, RAIL_TOP):
            if x < 0 and z in (RAIL_MID, RAIL_TOP):
                z -= 0.05          # (the wall side's rails a hand lower: one tube length off the other)
            _tube(p, (x + dx, y0, z), (x + dx, y1, z))
            for y in SY:
                _coupler(p, x + dx * 0.5, y, z)
    # transoms across under the boards, guard rails across the ends
    for y in SY:
        for z in (LIFT - 0.06 + 0.05, DECK - 0.1 + 0.05):
            _tube(p, (-SX - 0.07, y + 0.035, z), (SX + 0.07, y + 0.035, z))
    for y in (SY[0], SY[-1]):
        for z in (RAIL_MID - 0.02, RAIL_TOP - 0.02) if y > 0 else (RAIL_TOP - 0.02,):   # (the ladder's end: one rail)
            _tube(p, (-SX - 0.05, y - 0.04 * np.sign(y), z), (SX + 0.05, y - 0.04 * np.sign(y), z))
    # facade braces, one each bay, both faces (the room side's crossing the wall side's)
    for x, flip in ((SX + 0.055, False), (-SX - 0.055, True)):
        for k in range(2):
            ya, yb = SY[k] + 0.05, SY[k + 1] - 0.05
            if (k % 2 == 1) != flip:
                ya, yb = yb, ya
            _tube(p, (x, ya, 0.15), (x, yb, DECK - 0.2))
            _tube(p, (x, yb, DECK - 0.15), (x, ya, RAIL_TOP - 0.2), r=TUBE * 0.9)
    # end braces (ledger bracing across each end)
    for y in (SY[0] + 0.055, SY[-1] + 0.055):
        _tube(p, (-SX + 0.05, y, 0.25), (SX - 0.05, y, LIFT + 0.3))


def boards(p):
    """Scaffold boards: three on the lift, five on the deck, toe boards round
    the deck's room side and ends."""
    bw, bt = 0.225, 0.038
    L = SY[-1] - SY[0] + 0.16
    for k in range(3):
        x = -SX + 0.05 + bw * (k + 0.5) + 0.005 * k
        p.box((x, 0.0, LIFT - 0.06 + 0.075 + bt / 2), (bw - 0.006, L, bt), "board")
    for k in range(5):
        x = -SX - 0.04 + bw * (k + 0.5) + 0.004 * k
        dy = 0.025 * ((k % 3) - 1)
        p.box((x, dy, DECK - bt / 2), (bw - 0.006, L, bt), "board")
    p.box((SX + 0.07, 0.0, DECK + 0.075), (0.032, L, 0.15), "board")
    p.box((0.0, SY[-1] + 0.1, DECK + 0.075), (2 * SX + 0.1, 0.032, 0.15), "board")


def ladder(p):
    """An aluminium ladder up the open end of the first bay (Godot +Z), its
    head past the top rail, lashed to the deck's end transom."""
    yb, yt, zt = SY[0] - 0.135, SY[0] - 0.085, RAIL_TOP + 0.08
    tilt = Matrix.Rotation(-math.atan2(yt - yb, zt), 3, 'X')
    for x in (-0.2, 0.2):
        p.box((x, (yb + yt) / 2, zt / 2), (0.06, 0.025, zt), "alu", rot=tilt)
    z = 0.28
    while z < zt - 0.1:
        y = yb + (yt - yb) * z / zt
        K.seg(p, (-0.2, y, z), (0.2, y, z), [(0.014, 0.0), (0.014, 1.0)], "alu", segments=6, caps=False)
        z += 0.28
    # the rope lashing at the deck
    yd = yb + (yt - yb) * DECK / zt
    p.tube([(-0.23, yd, DECK + 0.03), (-0.1, SY[0] + 0.02, DECK - 0.08), (0.1, SY[0] + 0.02, DECK - 0.08),
            (0.23, yd, DECK + 0.03)], 0.008, "rope", sides=4)


def dust_sheet(p):
    """A canvas dust sheet thrown over the top rail on the room side of the
    second bay, hanging in folds down to the deck."""
    x = SX + 0.03
    ya, yb = 0.25, SY[-1] - 0.15
    nu, nv = 7, 4
    rows = []
    for j in range(nv + 1):
        t = j / nv
        row = []
        for i in range(nu + 1):
            s = i / nu
            y = ya + (yb - ya) * s
            fold = math.sin(s * math.pi * 3.0 + 0.4) * 0.035 * t
            z = RAIL_TOP + 0.03 - t * (RAIL_TOP - DECK - 0.35) - math.sin(s * math.pi) * 0.12 * t
            # over the rail: the top row lies a little behind it
            xx = x - 0.02 + (0.05 + fold) * min(1.0, t * 3.0) if j else x - 0.03
            row.append(p.bm.verts.new((xx, y, z)))
        rows.append(row)
    for j in range(nv):
        for i in range(nu):
            f = p._face([rows[j][i], rows[j][i + 1], rows[j + 1][i + 1], rows[j + 1][i]], "sheet", smooth=True)
            f.normal_update()
            if f.normal.x < 0:
                f.normal_flip()
    # the part lying back over the rail (seen from the deck)
    back = [p.bm.verts.new((x - 0.09, ya + (yb - ya) * i / nu, RAIL_TOP - 0.18)) for i in range(nu + 1)]
    for i in range(nu):
        f = p._face([back[i], back[i + 1], rows[0][i + 1], rows[0][i]], "sheet", smooth=True)
        f.normal_update()
        if f.normal.z < 0:
            f.normal_flip()


def kit_on_deck(p):
    """The conservators' things: a bucket, a toolbox, a work lamp on its
    tripod aimed at the wall; on the lift sacks of plaster and archive boxes."""
    # bucket
    p.lathe([(0.12, 0.0), (0.15, 0.27), (0.155, 0.28), (0.14, 0.28), (0.11, 0.02), (0.0, 0.02)], "bucket",
            segments=10, center=(0.18, -1.2, DECK), cap_bottom=False, cap_top=False)
    p.tube([(0.18 - 0.15, -1.2, DECK + 0.27), (0.18, -1.2, DECK + 0.4), (0.18 + 0.15, -1.2, DECK + 0.27)], 0.005,
           "coupler", sides=4, caps=False)
    # toolbox
    p.box((-0.15, -0.55, DECK + 0.1), (0.25, 0.5, 0.2), "toolbox", bevel=0.01)
    p.box((-0.15, -0.55, DECK + 0.23), (0.04, 0.3, 0.025), "coupler")
    # the work lamp: a tripod, a mast, a head aimed down at the wall
    cx, cy = 0.05, 0.95
    for k in range(3):
        a = math.tau * k / 3 + 0.4
        _tube(p, (cx + math.cos(a) * 0.32, cy + math.sin(a) * 0.32, DECK), (cx, cy, DECK + 0.55), r=0.011,
              mat="lamp")
    _tube(p, (cx, cy, DECK + 0.5), (cx, cy, DECK + 0.95), r=0.014, mat="lamp")
    head = p.lathe([(0.04, 0.0), (0.06, 0.04), (0.11, 0.12), (0.11, 0.16), (0.0, 0.16)], "lamp", segments=10,
                   cap_bottom=True, cap_top=False)
    lens = p.lathe([(0.105, 0.161), (0.0, 0.161)], "lens", segments=10, cap_bottom=False, cap_top=False)
    p.move(head + lens, Matrix.Translation((cx, cy, DECK + 0.97)) @ Matrix.Rotation(math.radians(-115), 4, 'Y'))
    p.tube([(cx, cy, DECK + 0.6), (cx - 0.1, cy - 0.3, DECK + 0.04), (cx - 0.2, cy - 0.9, DECK + 0.03)], 0.006,
           "rope", sides=4)
    # sacks and boxes on the lift
    zl = LIFT - 0.06 + 0.075 + 0.038
    for k, (y, h) in enumerate(((-1.4, 0.26), (-0.95, 0.24), (0.5, 0.25))):
        p.box((-SX + 0.25, y, zl + h / 2), (0.34, 0.42, h), "sack", bevel=0.06)
    for k, y in enumerate((1.05, 1.45)):
        p.box((-SX + 0.22, y, zl + 0.13 + k * 0.0), (0.3, 0.38, 0.26), "box")
    p.box((-SX + 0.22, 1.25, zl + 0.39), (0.3, 0.38, 0.26), "box")


def sign(p):
    """A sign wired to the room side's mid rail."""
    p.box((SIGN[0], SIGN[1], SIGN[2]), (0.012, 0.9, 0.34), "sign")
    for dy in (-0.36, 0.36):
        p.box((SIGN[0] - 0.004, SIGN[1] + dy, RAIL_MID - 0.005), (0.01, 0.01, 0.03), "coupler")


def build_scaffold():
    p = Part("asy_scaffold")
    frame(p)
    boards(p)
    ladder(p)
    dust_sheet(p)
    kit_on_deck(p)
    sign(p)
    return p


# --------------------------------------------------------------------------
# paint
# --------------------------------------------------------------------------

def tube(ctx):
    """Galvanised tube, plaster dust and paint flecks from the gallery."""
    s = RM.galvanised(ctx, 1211, center=5.0)
    fleck = ctx.rand(1213) > 0.992
    s.use_ramp(P["plaster"], mask=fleck, shade=np.full(ctx.N, 6.0))
    return s


def board(ctx):
    """Scaffold boards: pale spruce gone grey, plaster splashes, steel bands
    at the ends."""
    s = _wood_core(ctx, P["pine_worn"], 5.0, 1221, ring_freq=8.0, contrast=0.8)
    y = ctx.p[:, 1]
    L = SY[-1] - SY[0] + 0.3
    band = np.abs(np.abs(y) - (L / 2 - 0.06)) < 0.025
    s.use_ramp(P["zinc"], mask=band, shade=np.full(ctx.N, 3.8) + _dither(ctx, 0.8, 1223))
    splash = (ctx.fbm(5.0, 3, 1225) > 0.42) & ~band
    s.use_ramp(P["plaster"], mask=splash, shade=np.full(ctx.N, 6.4) + _dither(ctx, 1.0, 1227))
    s.metal = np.where(band, 0.6, 0.0)
    s.rough = np.where(band, 0.5, 0.85)
    return s


def sheet(ctx):
    """Canvas dust sheet: off-white, soft grey stains washed into it, shadow
    in the folds, specks of plaster."""
    s = M.Surface(ctx.N)
    stain = smoothstep(0.1, 0.6, ctx.fbm(1.6, 3, 1233))
    shade = 5.8 + ctx.fbm(4.0, 2, 1232) * 0.5 + _dither(ctx, 0.5, 1234) - stain * 1.4 - (1.0 - ctx.ao) * 0.6
    s.use_ramp(P["cloth_white"], shade=shade)
    speck = ctx.rand(1235) > 0.985
    s.use_ramp(P["plaster"], mask=speck, shade=np.full(ctx.N, 7.0))
    s.rough = np.full(ctx.N, 0.92)
    return s


def sign_paint(ctx):
    """White board, red border, black lettering."""
    s = M.Surface(ctx.N)
    s.use_ramp(P["cloth_white"], shade=7.2 + _dither(ctx, 0.5, 1241) - (1.0 - ctx.ao) * 2.0)
    face = ctx.n[:, 0] > 0.6
    y, z = ctx.p[:, 1], ctx.p[:, 2]
    cy, cz = SIGN[1], SIGN[2]
    border = face & ((np.abs(y - cy) > 0.42) | (np.abs(z - cz) > 0.145))
    s.use_ramp(P["formline_red"], mask=border, shade=np.full(ctx.N, 4.2))
    bits = PF.render(["KONSERWACJA", "NIE WCHODZIĆ"], bold=False)
    # (a +X face's metre UVs: u = y, v = z)
    text = face & PF.stamp(ctx, PF.trim(bits), cy, cz, scale=1)
    s.use_ramp(P["formline_black"], mask=text, shade=np.full(ctx.N, 1.0))
    s.rough = np.full(ctx.N, 0.6)
    return s


def sack(ctx):
    s = M.cloth(ctx, "webbing", 5.6, 1251, weave=0.5, rough=0.95)
    s.shade -= (1.0 - ctx.ao) * 2.0
    return s


def archive_box(ctx):
    s = M.cardboard(ctx, 1261, center=5.0)
    return s


SCAFFOLD_FNS = {
    "tube": tube, "coupler": lambda c: RM.galvanised(c, 1271, center=3.4), "sole": lambda c: AM.boards(c, 1273),
    "board": board, "alu": lambda c: RM.galvanised(c, 1275, center=6.4), "rope": lambda c: M.cloth(c, "webbing", 4.2, 1277),
    "sheet": sheet, "bucket": lambda c: RM.galvanised(c, 1279, center=4.4), "toolbox": lambda c: RM.painted_plate(
        c, ramp="formline_red", center=3.6, seed=1281, rust=0.6, fade=0.2),
    "lamp": lambda c: RM.painted_plate(c, ramp="wing_egypt", center=5.4, seed=1283, rust=0.4, fade=0.2),
    "lens": lambda c: M.glass(c, 1285), "sign": sign_paint, "sack": sack, "box": archive_box,
}


def build():
    return [kit("asy_scaffold", [build_scaffold()], SCAFFOLD_FNS, ppm=96, built_final=True, ground=0.0, ao_dist=0.3,
                ao_rays=10, ao_stride=2, preview_yaws=(55.0, 125.0, -55.0, 0.0), preview_elevation=14.0)]
