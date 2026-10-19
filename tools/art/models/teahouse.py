"""The tea house in the corner of the Japanese garden (the haven): a rustic
sukiya pavilion dressed onto the greybox room asia_teahouse (6 x 8 m inside,
3.5 m to the ceiling, walls 0.5 m) - from the garden, two facades of
natural cedar posts, clay walls and shoji under a deep thatched hip roof,
a veranda (engawa) along both, stepping stones and a stone water basin
with a bamboo spout by the door; inside, tatami, clay walls ringed by a
cedar rail, an alcove (tokonoma) with the ensō scroll and a flower, a
sunken hearth with an iron kettle on its chain, a paper ceiling lamp.

Frame (both models): origin = centre of the room's floor; Blender +Y =
Godot -Z = north. The garden lies east (+X) and south (-Y here, Godot +Z);
the west and north walls are the museum's. The door is the greybox's 2 m
opening in the east wall, centred on the room: Blender y -1..1 (Godot z
-1..1 from the centre), 2.6 m high once the model is sunk 0.4 m to put its
veranda flush with the garden's gravel. The doorway is clear: cedar jamb
posts stand just outside the 2 m, a lintel (kamoi) over it above 2.6 m (3.0
here), no sill, no post, no leaf between them; the two shoji leaves slid
open stand in their tracks on the facade beside it (the game's own door
leaf, a swinging shoji, closes the hole).

  teahouse           the outside: facades on the garden faces of the east
                     (x = 3.5) and south (y = -4.5) walls, the veranda
                     (deck 0.42 m high, 1 m deep: a step, give it a
                     collision box), the roof over the whole house (eaves
                     at 3.6 m, ridge 7.0 m along y; the thatch is the
                     world-mapped field tile:thatch), the stepping stones.
                     Parts: basin (a child: the tsukubai stone basin and
                     its bamboo spout, pivot on the ground under its middle,
                     so the game can lower, hide or fence it on its own).
                     Markers: roof_perch (on the ridge, over the middle:
                     the General's place for the arrow volleys of phase 2),
                     roof_perch_eave (on the east slope above the door),
                     basin_water (on the basin: the water surface, a drip
                     sound).
  teahouse_interior  the inside dressing (tatami and clay come from the
                     ArtKit style asia_teahouse; this adds the rail, the
                     corner posts, the alcove, the hearth and kettle, the
                     shoji on the east wall, the lamp). Markers:
                     terminal_spot (-2.6, 0, 0) facing +X (= Godot (-2.6, 0,
                     0) turned -90 degrees: the haven terminal of
                     asia.gd stands there), Light (the paper lamp, 3.0 m).
"""
import math

import numpy as np
from mathutils import Matrix, Vector

from artlib import asia as A
from artlib import kit as K
from artlib import materials as M
from artlib.archkit import kit
from artlib.geo import Part
from artlib.kit import R, T
from artlib.materials import P, _dither
from artlib.painter import Surface

HX, HY = 3.0, 4.0           # inner half sizes
WALL = 0.5
EX, SY = HX + WALL, -(HY + WALL)    # garden faces: east x, south y
DECK_Z = 0.42
EAVE_Z, RIDGE_Z = 3.6, 7.0
DOOR = (-1.0, 1.0)           # door span in y on the east wall: the greybox's 2 m hole, centred
JAMB = 0.12                  # the jamb posts' axes stand this far outside the hole (their inner faces 4 cm)
LINTEL = (3.01, 3.19)        # the door's lintel (kamoi): its underside is 2.6 over the gravel once sunk
LEAF_W, LEAF_BOT, LEAF_TOP = 0.98, DECK_Z + 0.08, 2.95   # a slid shoji leaf


# --------------------------------------------------------------------------
# outside
# --------------------------------------------------------------------------

def _facade(p, axis, fixed, a0, a1, door=None):
    """A facade on a garden face: posts, sill and head beams, panels of
    clay with a low board skirting, shoji windows; ``axis`` 'y' = the east
    face (x fixed, running along y), 'x' = the south face (y fixed). With a
    ``door`` span the doorway is left clear (jamb posts just outside it, a
    lintel over it, no sill and no head beam across), and the door's two
    shoji leaves stand slid open in their tracks over the bay beside it."""
    def at(a, out, z):
        return (fixed + out, a, z) if axis == "y" else (a, fixed - out, z)

    def box(a, out, z, la, lo, lz, slot, bevel=0.01):
        size = (lo, la, lz) if axis == "y" else (la, lo, lz)
        return p.box(at(a, out, z), size, slot, bevel=bevel)

    if door is None:
        n = int(round((a1 - a0) / 1.8))
        step = (a1 - a0) / n
        posts = [a0 + step * k for k in range(n + 1)]
        runs = [(a0, a1)]
        door_bay = None
    else:
        # posts evenly either side of the doorway, its jambs on the 2 m
        d0, d1 = door[0] - JAMB, door[1] + JAMB
        nl = max(1, int(round((d0 - a0) / 1.7)))
        nr = max(1, int(round((a1 - d1) / 1.7)))
        posts = [a0 + (d0 - a0) * k / nl for k in range(nl + 1)] + [d1 + (a1 - d1) * k / nr for k in range(nr + 1)]
        runs = [(a0, d0), (d1, a1)]
        door_bay = nl
    for a in posts:
        box(a, 0.08, (DECK_Z + 3.3) / 2, 0.16, 0.16, 3.3 - DECK_Z, "asia_cedar", 0.015)
    for r0, r1 in runs:
        box((r0 + r1) / 2, 0.06, DECK_Z + 0.06, r1 - r0, 0.12, 0.12, "asia_cedar")               # sill
        box((r0 + r1) / 2, 0.06, 2.35, r1 - r0, 0.12, 0.14, "asia_cedar")                       # head beam (nageshi)
    box((a0 + a1) / 2, 0.06, 3.28, a1 - a0, 0.14, 0.16, "asia_cedar")                       # wall plate
    for k in range(len(posts) - 1):
        b0, b1 = posts[k] + 0.08, posts[k + 1] - 0.08
        mid = (b0 + b1) / 2
        if k == door_bay:
            # the doorway: nothing in it, a lintel over it
            box(mid, 0.06, (LINTEL[0] + LINTEL[1]) / 2, b1 - b0, 0.12, LINTEL[1] - LINTEL[0], "asia_cedar")
            continue
        # beside the door the fixed panels are shoji (the slid leaves stand
        # over them), farther out clay; the south facade alternates
        if door is None:
            clay_bay = k % 2 == 0
        else:
            from_door = (door_bay - 1 - k) if k < door_bay else (k - door_bay - 1)
            clay_bay = from_door % 2 == 1
        box(mid, 0.03, DECK_Z + 0.35, b1 - b0, 0.04, 0.46, "board", 0.006)            # board skirting
        if clay_bay:
            box(mid, 0.03, 1.55, b1 - b0, 0.04, 1.4, "clay", 0.0)                     # clay wall
            box(mid, 0.05, 1.55, (b1 - b0) * 0.5, 0.04, 0.7, "shoji_frame", 0.004)    # a small window
        else:
            box(mid, 0.05, 1.55, b1 - b0, 0.04, 1.4, "shoji", 0.004)                  # tall shoji
        box(mid, 0.03, 2.82, b1 - b0, 0.04, 0.8, "clay", 0.0)                         # clay above the beam
    if door is not None:
        # the door's two leaves slid fully open to the first bay (one in each
        # track, in front of the posts), their rails below and above
        left0, left1 = posts[door_bay - 1] + 0.08, posts[door_bay] - 0.08
        for z in (LEAF_BOT - 0.04, LEAF_TOP + 0.045):
            box((left0 + left1) / 2, 0.215, z, left1 - left0, 0.12, 0.05, "asia_cedar")
        for out, shift in ((0.245, 0.0), (0.195, 0.5)):
            far = left1 - 0.05 - shift
            box(far - LEAF_W / 2, out, (LEAF_BOT + LEAF_TOP) / 2, LEAF_W, 0.03, LEAF_TOP - LEAF_BOT, "shoji_frame", 0.004)


def _thatch_roof(p):
    """A deep hipped thatch: a thick fringe at the eaves, the ridge capped
    with cedar boards and a row of crossed ridge logs."""
    ox, oy = 1.3, 1.3
    x0, x1 = -HX - WALL - 0.2, EX + ox
    y0, y1 = SY - oy, HY + WALL + 0.2
    rl = 1.6                                   # half length of the ridge
    cy = (y0 + y1) / 2
    eave = [(x0, y0), (x1, y0), (x1, y1), (x0, y1)]
    rx = (x0 + x1) / 2
    r0, r1 = (rx, cy - rl, RIDGE_Z), (rx, cy + rl, RIDGE_Z)
    E = [(x, y, EAVE_Z) for x, y in eave]
    thick = 0.55

    def face(pts, slot="thatch"):
        vs = [p.bm.verts.new(q) for q in pts]
        f = p._face(vs, slot)
        f.normal_update()
        if f.normal.z < 0:
            f.normal_flip()
        return f
    face([E[0], E[1], r0])                      # south hip
    face([E[2], E[3], r1])                      # north hip
    face([E[1], E[2], r1, r0])                  # east slope
    face([E[3], E[0], r0, r1])                  # west slope
    # the thick eave fringe all round, cut square
    for k in range(4):
        a, b = E[k], E[(k + 1) % 4]
        q = [a, b, (b[0], b[1], b[2] - thick), (a[0], a[1], a[2] - thick)]
        f = face(q)
        f.normal_update()
        mid = Vector(((a[0] + b[0]) / 2 - rx, (a[1] + b[1]) / 2 - cy, 0.0))
        if f.normal.dot(mid) < 0:
            f.normal_flip()
    under = [p.bm.verts.new((x, y, EAVE_Z - thick)) for x, y in eave]
    f = p._face(under, "soffit")
    f.normal_update()
    if f.normal.z > 0:
        f.normal_flip()
    # ridge: cedar cap and crossed logs
    p.box((rx, cy, RIDGE_Z + 0.08), (0.5, 2 * rl + 0.6, 0.22), "asia_cedar", bevel=0.03)
    for k in range(5):
        y = cy - rl + k * (2 * rl / 4)
        for s in (-1, 1):
            f = p.box((0.0, 0.0, 0.0), (0.13, 0.13, 1.05), "cedar_dark", bevel=0.015)
            p.move(f, T(rx, y, RIDGE_Z + 0.32) @ R('Y', s * 35))
    return (rx, cy, RIDGE_Z + 0.2), (x1 - 1.4, (DOOR[0] + DOOR[1]) / 2, EAVE_Z + (RIDGE_Z - EAVE_Z) * 0.25)


def veranda(p):
    # east deck and south deck on short posts
    for (x0, x1, y0, y1) in ((EX, EX + 1.0, SY, HY + WALL), (-HX - WALL, EX + 1.0, SY - 1.0, SY)):
        p.box(((x0 + x1) / 2, (y0 + y1) / 2, DECK_Z - 0.03), (x1 - x0, y1 - y0, 0.06), "deck", bevel=0.008)
        p.box(((x0 + x1) / 2, (y0 + y1) / 2, DECK_Z - 0.12), (x1 - x0 - 0.1, y1 - y0 - 0.1, 0.12), "cedar_dark",
              bevel=0.01)
    for x, y in ((EX + 0.9, SY - 0.9), (EX + 0.9, 1.0), (EX + 0.9, HY), (-2.0, SY - 0.9), (0.5, SY - 0.9)):
        p.box((x, y, (DECK_Z - 0.18) / 2), (0.12, 0.12, DECK_Z - 0.18), "cedar_dark", bevel=0.01)
        p.box((x, y, 0.04), (0.26, 0.26, 0.08), "stone", bevel=0.02)
    # stepping stones to the door and the shoe stone
    for k, (x, y, r) in enumerate(((EX + 1.35, 0.15, 0.36), (EX + 2.1, -0.3, 0.3), (EX + 2.8, 0.2, 0.32),
                                   (EX + 3.5, -0.25, 0.3))):
        p.lathe([(r, 0.0), (r * 0.96, 0.08 if k else 0.22), (r * 0.8, 0.1 if k else 0.26)], "stone", segments=9,
                center=(x, y, 0.0), cap_bottom=False, squash=(1.0, 0.8))


def basin_part():
    """The tsukubai: a low stone basin with a bamboo spout, a part of its own
    (a child of the house, its pivot on the ground under its middle) so the
    game can sink, hide or fence it without touching the house."""
    bx, by = EX + 2.2, -1.6
    p = Part("basin", origin=(bx, by, 0.0), parent="teahouse")
    p.lathe([(0.34, 0.0), (0.36, 0.22), (0.3, 0.38), (0.24, 0.38), (0.22, 0.3)], "stone", segments=12,
            center=(bx, by, 0.0), cap_bottom=False, cap_top=False)
    p.lathe([(0.22, 0.3), (0.0, 0.3)], "water", segments=12, center=(bx, by, 0.0), cap_bottom=False, cap_top=False)
    K.seg(p, (bx + 0.75, by, 0.0), (bx + 0.75, by, 0.62), [(0.04, 0.0), (0.04, 1.0)], "bamboo", segments=6)
    K.seg(p, (bx + 0.75, by, 0.58), (bx + 0.12, by, 0.48), [(0.022, 0.0), (0.022, 1.0)], "bamboo", segments=6)
    return p, (bx, by, 0.3)


def outside():
    p = Part("teahouse")
    _facade(p, "y", EX, SY + 0.0, HY + WALL, door=DOOR)
    _facade(p, "x", SY, -HX - WALL, EX)
    perch, eave = _thatch_roof(p)
    veranda(p)
    basin, water = basin_part()
    return p, perch, eave, basin, water


# --------------------------------------------------------------------------
# inside
# --------------------------------------------------------------------------

def inside():
    p = Part("teahouse_interior")
    # cedar posts in the corners and by the door; a rail (nageshi) all round
    for x, y in ((-HX + 0.08, -HY + 0.08), (HX - 0.08, -HY + 0.08), (HX - 0.08, HY - 0.08), (-HX + 0.08, HY - 0.08),
                 (HX - 0.08, DOOR[0] - 0.08), (HX - 0.08, DOOR[1] + 0.08)):
        p.box((x, y, 1.75), (0.15, 0.15, 3.5), "asia_cedar", bevel=0.015)
    for (cx, cy, lx, ly) in ((0.0, -HY + 0.05, 2 * HX, 0.1), (0.0, HY - 0.05, 2 * HX, 0.1),
                             (-HX + 0.05, 0.0, 0.1, 2 * HY)):
        p.box((cx, cy, 2.15), (lx, ly, 0.12), "asia_cedar", bevel=0.01)
    # (the east wall's rail stops at the door's jambs: the doorway is clear)
    for y0, y1 in ((-HY, DOOR[0] - 0.08), (DOOR[1] + 0.08, HY)):
        p.box((HX - 0.05, (y0 + y1) / 2, 2.15), (0.1, y1 - y0, 0.12), "asia_cedar", bevel=0.01)
    # the alcove on the north wall: raised floor, a natural log post, a
    # lintel, the scroll hangs there (scroll_hanging_enso), a flower in a vase
    p.box((1.2, HY - 0.4, 0.09), (1.9, 0.8, 0.18), "cedar_dark", bevel=0.01)
    p.box((1.2, HY - 0.4, 0.185), (1.86, 0.76, 0.01), "tatami_toko")
    K.seg(p, (0.22, HY - 0.75, 0.0), (0.25, HY - 0.76, 3.5), [(0.07, 0.0), (0.065, 0.5), (0.068, 1.0)], "log",
          segments=8)
    p.box((1.2, HY - 0.75, 2.0), (1.95, 0.08, 0.1), "asia_cedar", bevel=0.01)
    vase = p.lathe([(0.05, 0.19), (0.07, 0.24), (0.05, 0.36), (0.035, 0.42), (0.04, 0.45)], "vase", segments=10,
                   center=(1.6, HY - 0.4, 0.0), cap_top=False)
    p.tube([(1.6, HY - 0.4, 0.42), (1.62, HY - 0.42, 0.62), (1.55, HY - 0.45, 0.78)], 0.006, "stem", sides=4)
    K.sphere(p, (1.55, HY - 0.45, 0.8), 0.04, "camellia", segments=8, rings=5)
    # the sunken hearth: a lacquered frame flush with the mats, ash, kettle
    hx, hy = 0.4, -0.6
    for k in range(4):
        f = p.box((0.0, 0.0, 0.0), (0.56, 0.06, 0.06), "frame", bevel=0.006)
        p.move(f, T(hx, hy, 0.03) @ R('Z', 90 * k) @ T(0.0, -0.25, 0.0))
    p.box((hx, hy, 0.005), (0.44, 0.44, 0.01), "ash")
    kettle = p.lathe([(0.0, 0.08), (0.13, 0.1), (0.17, 0.18), (0.16, 0.26), (0.11, 0.31), (0.06, 0.32),
                      (0.065, 0.35), (0.04, 0.36)], "kettle", segments=14, center=(hx, hy, 0.0), cap_top=True)
    p.tube([(hx - 0.12, hy, 0.3), (hx - 0.1, hy, 0.42), (hx + 0.1, hy, 0.42), (hx + 0.12, hy, 0.3)], 0.008, "kettle",
           sides=4, caps=False)
    p.tube([(hx, hy, 0.42), (hx, hy, 3.48)], 0.01, "kettle", sides=4)                # the chain (jizai)
    # shoji on the inside of the east wall either side of the door
    for y0, y1 in ((-HY + 0.2, DOOR[0] - 0.2), (DOOR[1] + 0.2, HY - 0.2)):
        if y1 - y0 < 0.5:
            continue
        p.box((HX - 0.03, (y0 + y1) / 2, 1.2), (0.04, y1 - y0, 1.5), "shoji", bevel=0.004)
    # paper ceiling lamp
    p.lathe([(0.0, 2.6), (0.18, 2.62), (0.22, 2.8), (0.2, 2.98), (0.0, 3.0)], "lamp", segments=12,
            center=(0.0, 0.0, 0.0))
    p.tube([(0.0, 0.0, 3.0), (0.0, 0.0, 3.5)], 0.006, "kettle", sides=4)
    # a low table for the terminal
    p.box((-2.2, 0.0, 0.32), (0.8, 1.2, 0.05), "cedar_dark", bevel=0.01)
    for sx in (-1, 1):
        for sy in (-1, 1):
            p.box((-2.2 + sx * 0.32, sy * 0.52, 0.15), (0.06, 0.06, 0.3), "cedar_dark", bevel=0.008)
    return p


# --------------------------------------------------------------------------
# paint
# --------------------------------------------------------------------------

def shoji_paint(ctx, seed=2301):
    """Shoji seen from either side: washi in a grid of kumiko bars, warm
    light glowing through from inside."""
    s = A.paper(ctx, seed, "washi", 6.4, glow=0.8)
    u, v = ctx.uvm[:, 0], ctx.uvm[:, 1]
    bar = (np.mod(u, 0.3) < 0.025) | (np.mod(v, 0.28) < 0.025)
    w = A.wood(ctx, seed + 1, ramp="hinoki", center=5.0)
    s.merge(A._select(w, bar), bar)
    s.emit = np.where(bar[:, None], 0.0, s.emit if s.emit is not None else 0.0) * np.array([1.0, 0.75, 0.45])
    return s


def clay(ctx, seed=2311):
    return A.garden_wall(ctx, seed)


def build():
    p, perch, eave, basin, water = outside()
    fns = {"asia_cedar": lambda c: A.wood(c, 2321, ramp="asia_cedar", center=5.0),
           "cedar_dark": lambda c: A.wood(c, 2323, ramp="asia_cedar", center=3.4),
           "board": lambda c: A.wood(c, 2325, ramp="asia_cedar", center=4.2), "clay": clay, "shoji": shoji_paint,
           "shoji_frame": shoji_paint,
           "deck": A.weathered_wood, "stone": lambda c: A.garden_stone(c, 2329, moss=0.8),
           "water": lambda c: A.water(c, 2331), "bamboo": lambda c: A.wood(c, 2333, ramp="leaf_young", center=3.6)}
    out = [kit("teahouse", [p, basin], fns, kinds={"thatch": "tile:thatch", "soffit": "tile:boards_dark"}, ppm=64, ao_dist=0.5, ao_rays=8,
               built_final=True,
               markers=[("roof_perch", perch, None), ("roof_perch_eave", eave, None), ("basin_water", water, "basin")],
               preview_yaws=(-130.0, -160.0, 160.0, 120.0), preview_elevation=15.0)]
    q = inside()
    ifns = {"asia_cedar": lambda c: A.wood(c, 2341, ramp="asia_cedar", center=5.0),
            "cedar_dark": lambda c: A.wood(c, 2343, ramp="asia_cedar", center=3.4),
            "log": lambda c: A.wood(c, 2345, ramp="hinoki", center=4.6, contrast=1.2),
            "tatami_toko": lambda c: A.tatami(c, 2347),
            "vase": lambda c: A.glaze(c, 2349, "earth_wall", 3.6, craze=0.4),
            "stem": lambda c: A.wood(c, 2351, ramp="leaf_young", center=2.6),
            "camellia": lambda c: A.silk(c, "silk_red", 4.0, 2353),
            "frame": lambda c: A.lacquer(c, 2355, ramp="lacquer_black", center=3.0, wear=0.3),
            "ash": lambda c: A.gravel(c, 2357), "kettle": lambda c: M.iron(c, 2359),
            "shoji": shoji_paint, "lamp": lambda c: _lamp(c)}
    out.append(kit("teahouse_interior", [q], ifns, ppm=96, ao_dist=0.3, ao_rays=8, built_final=True,
                   markers=[("terminal_spot", (-2.6, 0.0, 0.0), None), ("Light", (0.0, 0.0, 2.8), None)],
                   preview_elevation=35.0))
    return out


def _lamp(ctx):
    s = A.paper(ctx, 2361, "washi", 6.6, glow=1.0)
    s.emit = s.colors() * np.array([1.0, 0.78, 0.5])
    return s
