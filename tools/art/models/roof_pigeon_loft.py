"""Floor I's roof, the pigeon fanciers' loft (a secret behind the rope
hatch): the nest boxes along its walls (two of one model).

  roof_pigeon_loft  a long cabinet of eighteen nest boxes (six across,
                    three high) on two bearers: limewashed battens framing
                    the pigeonholes, raw boards inside, a landing board
                    under each row, a door of welded wire in a wooden frame
                    on each box (three gone: the box open, straw and a clay
                    nest bowl in it), turn-buttons and strap hinges; straw,
                    feathers and droppings on the shelves. 4.2 x 1.8 x 0.6 m
                    (Godot x, y, z) = its greybox box (the box is its
                    collision), the wire on its front (-Z). 128 px/m; the
                    doors show a small texture set of their own
                    (pigeon_door, alpha-cut: ArtLibrary.EXTRAS).

Kit convention: origin = the middle of the footprint on the floor; built
front +Y in Blender (= Godot -Z).
"""
import numpy as np
from mathutils import Vector

from artlib import arch_materials as AM
from artlib import asy
from artlib import materials as M
from artlib import roof_materials as RM
from artlib.archkit import kit
from artlib.geo import Part
from artlib.materials import P, _dither, hexramp, smoothstep
from artlib.painter import Surface, paint_tile

P.update({
    "limewash": hexramp("#3d3a33", "#55514a", "#6e6a61", "#88837a", "#a19c92", "#b8b3a8", "#cbc6bb", "#dad6cc",
                        "#e6e3da"),
    "straw": hexramp("#2c2410", "#3e3317", "#51431f", "#655428", "#7a6632", "#8f793d", "#a38c4a", "#b69f59"),
})

W = 4.2
H = 1.8
D = 0.54                 # the cabinet's depth (the landing boards stand proud of it)
COLS, ROWS = 6, 3
FLOOR = 0.11             # the bottom board's top
TOP = 1.77               # the top board's underside
FRONT = D / 2            # the battens' front
DOOR = (0.6, 0.5)        # a door card (w, h)
MISSING = {(1, 0), (4, 1), (2, 2)}      # (column, row) of the boxes without their doors
BOWLS = {(1, 0), (4, 1), (2, 2), (0, 1), (5, 0), (3, 2), (5, 2)}


def _card(p, centre, w, h, slot):
    """A door card facing +Y (front), UVs 0..1 over it (the whole set)."""
    cx, cy, cz = centre
    corners = [(cx - w / 2, cy, cz - h / 2), (cx + w / 2, cy, cz - h / 2), (cx + w / 2, cy, cz + h / 2),
               (cx - w / 2, cy, cz + h / 2)]
    # seen from the front (+Y) the card's u runs toward -x (Godot +X is on the viewer's left)
    uvs = [(1.0, 0.0), (0.0, 0.0), (0.0, 1.0), (1.0, 1.0)]
    f = p._face([p.bm.verts.new(c) for c in corners], slot)
    f.normal_update()
    flip = f.normal.dot(Vector((0.0, 1.0, 0.0))) < 0
    if flip:
        f.normal_flip()
    by = {f.loops[i].vert: uv for i, uv in enumerate(uvs if not flip else list(reversed(uvs)))}
    for loop in f.loops:
        loop[p.uv].uv = by[loop.vert]
    f[p.lock] = 1
    return f


def cells():
    """The pigeonholes' centres: (column, row) -> (x, z) and their size."""
    cw = (W - 0.06) / COLS
    ch = (TOP - FLOOR) / ROWS
    out = {}
    for c in range(COLS):
        for r in range(ROWS):
            out[(c, r)] = (-W / 2 + 0.03 + cw * (c + 0.5), FLOOR + ch * (r + 0.5))
    return out, cw, ch


def cabinet(p):
    cw = (W - 0.06) / COLS
    ch = (TOP - FLOOR) / ROWS
    # bearers, the bottom board, the back, the ends, the top
    for sy in (-1, 1):
        p.box((0.0, sy * 0.18, 0.04), (W - 0.1, 0.08, 0.08), "bearer")
    p.box((0.0, 0.0, FLOOR - 0.015), (W, D, 0.03), "shelf")
    p.box((0.0, -D / 2 + 0.01, (FLOOR + TOP) / 2), (W - 0.04, 0.02, TOP - FLOOR), "back")
    for sx in (-1, 1):
        p.box((sx * (W / 2 - 0.015), 0.0, (FLOOR - 0.03 + TOP + 0.03) / 2), (0.03, D, TOP - FLOOR + 0.06), "batten")
    p.box((0.0, 0.01, TOP + 0.015), (W, D + 0.04, 0.03), "batten")
    # the shelves and the dividers (raw boards), the battens framing the holes
    for r in range(1, ROWS):
        z = FLOOR + ch * r
        p.box((0.0, -0.01, z - 0.012), (W - 0.06, D - 0.04, 0.024), "shelf")
    for c in range(1, COLS):
        x = -W / 2 + 0.03 + cw * c
        p.box((x, -0.01, (FLOOR + TOP) / 2), (0.018, D - 0.04, TOP - FLOOR), "back")
    for r in range(ROWS + 1):
        z = FLOOR + ch * r
        p.box((0.0, FRONT - 0.02, z), (W - 0.04, 0.04, 0.05), "batten")
    for c in range(1, COLS):
        x = -W / 2 + 0.03 + cw * c
        p.box((x, FRONT - 0.02, (FLOOR + TOP) / 2), (0.05, 0.04, TOP - FLOOR), "batten")
    # a landing board under each row of doors
    for r in range(ROWS):
        z = FLOOR + ch * r + 0.03
        p.box((0.0, FRONT + 0.012, z), (W - 0.08, 0.024, 0.016), "batten")


def doors(p):
    """A wire door on every pigeonhole but the three in MISSING (those keep
    their strap hinges, the door gone)."""
    spots, cw, ch = cells()
    for key, (x, z) in sorted(spots.items()):
        if key in MISSING:
            for dz in (-1, 1):
                p.box((x - cw / 2 + 0.05, FRONT + 0.004, z + dz * 0.15), (0.08, 0.006, 0.025), "iron")
            continue
        _card(p, (x, FRONT + 0.006 + 0.002 * (key[0] % 2), z + 0.012), DOOR[0], DOOR[1], "door")


def nests(p):
    """Clay nest bowls with their straw in some of the boxes."""
    spots, cw, ch = cells()
    for key in sorted(BOWLS):
        x, z = spots[key]
        zf = z - ch / 2 + 0.012
        y = -0.02 + 0.05 * ((key[0] + key[1]) % 2)
        dx = 0.08 * (1 if key[0] % 2 else -1)
        p.lathe([(0.08, 0.0), (0.11, 0.025), (0.125, 0.06), (0.115, 0.065), (0.095, 0.03), (0.0, 0.03)], "bowl",
                segments=8, center=(x + dx, y, zf), cap_bottom=False, cap_top=False, smooth=False)
        p.lathe([(0.1, 0.045), (0.06, 0.07), (0.0, 0.075)], "straw", segments=8, center=(x + dx, y, zf),
                cap_bottom=False, cap_top=False)


def build_loft():
    p = Part("roof_pigeon_loft")
    cabinet(p)
    doors(p)
    nests(p)
    return p


# --------------------------------------------------------------------------
# paint
# --------------------------------------------------------------------------

def batten(ctx):
    """Limewash over pine: chalky, worn through to the wood on the arrises,
    droppings streaked down the fronts under the landing boards."""
    s = M.paint(ctx, "limewash", 6.0, seed=1111, chip=0.7, under="wood_oak", gloss=0.85)
    RM.droppings(ctx, s, amount=1.4, seed=1113)
    z = ctx.p[:, 2]
    front = ctx.n[:, 1] > 0.6
    streak = front & (ctx.fbm(np.array([30.0, 30.0, 2.0]), 2, 1115) > 0.35)
    s.use_ramp(P["dropping"], mask=streak, shade=np.full(ctx.N, 3.0) + _dither(ctx, 1.0, 1117))
    s.shade = np.where(z < 0.2, s.shade - 1.0, s.shade)
    return s


def inside(ctx):
    """Raw boards inside the boxes, darker deep in them."""
    s = AM.boards(ctx, 1121)
    s.shade -= 1.2 + (1.0 - ctx.ao) * 2.0
    return s


def shelf(ctx):
    """The boxes' floors: boards under straw, feathers and droppings."""
    s = AM.boards(ctx, 1131)
    s.shade -= 0.8
    up = ctx.n[:, 2] > 0.6
    straw = up & (ctx.fbm(np.array([40.0, 4.0, 40.0]), 2, 1133) + ctx.fbm(3.0, 2, 1134) * 0.8 > 0.1)
    s.use_ramp(P["straw"], mask=straw, shade=np.full(ctx.N, 3.4) + ctx.fbm(60.0, 1, 1135) * 2.0 + _dither(ctx, 0.8, 1136)
               - (1.0 - ctx.ao) * 3.0)
    RM.droppings(ctx, s, amount=2.6, seed=1137)
    feather = up & (ctx.rand(1138) > 0.996)
    s.use_ramp(P["limewash"], mask=feather, shade=np.full(ctx.N, 5.5))
    s.rough = np.full(ctx.N, 0.9)
    return s


def bowl(ctx):
    s = asy.clay(ctx, 1141, center=5.4, writing=False)
    RM.droppings(ctx, s, amount=1.0, seed=1143)
    return s


def straw(ctx):
    s = Surface(ctx.N)
    s.use_ramp(P["straw"], shade=3.6 + ctx.fbm(np.array([50.0, 50.0, 6.0]), 2, 1151) * 2.0 + _dither(ctx, 1.0, 1152)
               - (1.0 - ctx.ao) * 2.0)
    s.rough = np.full(ctx.N, 0.95)
    s.height = ctx.fbm(60.0, 1, 1153) * 0.0008
    return s


def door_set(ctx):
    """A pigeonhole's door (the whole card, 0.6 x 0.5 m seen from the front):
    a limewashed frame, welded wire 25 mm square inside (the rest cut away),
    two strap hinges on the left, a turn-button on the right."""
    s = Surface(ctx.N)
    x, z = ctx.p[:, 0], ctx.p[:, 2]
    tx = ctx.texel
    w, h = DOOR
    fr = 0.035
    frame = (x < fr) | (x > w - fr) | (z < fr) | (z > h - fr)
    wire = ((np.abs(np.mod(x - fr, 0.025)) < tx * 1.1) | (np.abs(np.mod(z - fr, 0.025)) < tx * 1.1)) & ~frame
    hinge = (x < 0.11) & ((np.abs(z - 0.1) < 0.012) | (np.abs(z - h + 0.1) < 0.012))
    button = (np.abs(x - (w - fr * 0.5)) < 0.012) & (np.abs(z - h / 2) < 0.04)
    grain = ctx.fbm(np.array([4.0, 4.0, 40.0]), 2, 1161)
    s.use_ramp(P["limewash"], shade=5.6 + grain * 0.8 + _dither(ctx, 0.6, 1162))
    worn = frame & (ctx.fbm(9.0, 2, 1163) > 0.35)
    s.use_ramp(P["wood_oak"], mask=worn, shade=np.full(ctx.N, 3.0) + grain)
    s.use_ramp(P["zinc"], mask=wire, shade=np.full(ctx.N, 4.6) + _dither(ctx, 1.4, 1164))
    s.use_ramp(P["iron"], mask=hinge | button, shade=np.full(ctx.N, 3.0) + _dither(ctx, 0.8, 1165))
    s.metal = np.where(wire | hinge | button, 0.6, 0.0)
    s.rough = np.where(wire, 0.5, 0.85)
    s.height = np.where(hinge | button, 0.001, 0.0) - (frame & (np.minimum(np.minimum(x, w - x), np.minimum(z, h - z))
                                                                  > fr - tx * 1.5)) * 0.001
    s.alpha = np.where(frame | wire | hinge | button, 1.0, 0.0)
    return s


LOFT_FNS = {
    "batten": batten, "back": inside, "shelf": shelf, "bearer": lambda c: AM.boards(c, 1171),
    "iron": lambda c: M.iron(c, 1173), "bowl": bowl, "straw": straw,
}


def build():
    return [kit("roof_pigeon_loft", [build_loft()], LOFT_FNS, kinds={"door": "pigeon_door"},
                textures={"pigeon_door": paint_tile(door_set, DOOR[0], DOOR[1], 256)}, ppm=128, built_final=True,
                ground=0.0, ao_dist=0.3, ao_rays=10, ao_stride=2, preview_yaws=(-35.0, 35.0, 145.0, 215.0),
                preview_elevation=14.0)]
