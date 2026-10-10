"""The Assyrian wing (palaces of Nineveh and Nimrud): palette, materials and
tile textures, and the material that bakes a carved relief (artlib.asy_relief)
onto a model face.

Palette (spec 10.1): grey-blue gypsum alabaster ("Mosul marble"), bronze,
cedar; black paint traces on hair and beards, red ochre, faint blue,
glazed brick (lapis blue, yellow, white), mud brick, baked brick with
bitumen joints, clay tablets; torch flame for the red, low, harsh lamps.
Shading = steps along the ramps, as everywhere in the project.

Tile textures (64 px/m, world-mapped by ArtLibrary.arch_tile, all on the
0.5 m grid): asy_alabaster (orthostat slabs 4 x 3 m), asy_plaster (upper
walls), asy_mudbrick, flagstone_asy (gypsum paving), tiles_asy_brick (courtyard
bricks with stamps), asy_cedar (plank ceiling).
"""
import math

import numpy as np

from . import asy_relief as relief, noise
from .arch_materials import blocks, course_layout
from .materials import P, Surface, _age, _dither, _grain_frame, _wood_core, hexramp, smoothstep

P.update({
    # grey-blue gypsum alabaster, dark -> light
    "asy_alabaster": hexramp("#16181b", "#1f2124", "#282a2e", "#323539", "#3d4044", "#494d51", "#565a5e",
                         "#64686c", "#73777b", "#828689", "#929597", "#a3a5a7", "#b3b6b7", "#c4c6c6"),
    "asy_alabaster_warm": hexramp("#2a2620", "#3a342b", "#4b4437", "#5d5545", "#6f6654", "#827864", "#958b75",
                              "#a89e87"),
    "asy_paint_black": hexramp("#07080a", "#0d0f12", "#14171b", "#1c2025", "#252a30", "#30353c"),
    "asy_ochre_red": hexramp("#2a0c07", "#3f130a", "#56190d", "#6e2011", "#862a17", "#9c3820", "#b0492b"),
    "asy_lapis": hexramp("#050c18", "#09142a", "#0e1e3f", "#142955", "#1b356c", "#244383", "#2f5398",
                     "#3d64ab", "#5079bd", "#6990cc"),
    "asy_glaze_yellow": hexramp("#3a2a08", "#5c440f", "#7f5f17", "#a37b22", "#c49830", "#dfb546", "#f0cf6a"),
    "asy_glaze_white": hexramp("#4b4a43", "#68665d", "#868377", "#a4a093", "#c0bcae", "#d9d4c4"),
    "asy_cedar": hexramp("#120706", "#1c0c08", "#27110b", "#33160e", "#401c11", "#4e2315", "#5c2a19",
                     "#6b321e", "#7b3b24", "#8b452b"),
    "asy_mudbrick": hexramp("#241c14", "#32271b", "#413323", "#51402c", "#614d36", "#725b41", "#83694c",
                        "#937858", "#a38865"),
    "asy_brick_baked": hexramp("#2a2015", "#3b2e1e", "#4d3c27", "#5f4b31", "#715a3b", "#836a47", "#957a54",
                           "#a68a61", "#b69a70"),
    "asy_bitumen": hexramp("#050505", "#0b0a09", "#12100e", "#1b1815", "#25211d"),
    "asy_clay": hexramp("#24170e", "#342215", "#452e1d", "#573b25", "#6a492e", "#7c5838", "#8f6843",
                    "#a07850", "#b0895e", "#bf9a6e"),
    "asy_flame": hexramp("#3a0a02", "#6e1804", "#a32a06", "#d1440a", "#ef6a14", "#fb9431", "#ffbd5c", "#ffe09a"),
    "asy_gypsum_break": hexramp("#2c3036", "#3a3f46", "#4a5057", "#5b6168", "#6d737a", "#80868c", "#93989d",
                                "#a6abaf", "#b9bdc0", "#cbced0"),
})


# --------------------------------------------------------------------------
# stone
# --------------------------------------------------------------------------

def _veins(ctx, q, seed, scale=1.0):
    """Gypsum clouding: soft wavy translucent bands and a few dark veins
    (alabaster is banded, not marbled). Returns (cloud, vein) ~ -1..1, 0..1."""
    warp = ctx.fbm(0.6 * scale, 3, seed + 1, p=q) * 0.9
    band = np.sin((q[:, 2] * 2.3 + q[:, 0] * 0.6 + warp * 2.2) * math.pi * scale)
    cloud = band * 0.45 + ctx.fbm(1.4 * scale, 4, seed + 2, p=q) * 0.8
    f = np.abs(ctx.fbm(0.9 * scale, 4, seed + 3, p=q + warp[:, None] * 0.4))
    k = ctx.texel * 64.0
    vein = (1.0 - smoothstep(0.0, 0.035 * k, f)) * (ctx.fbm(0.8, 2, seed + 4, p=q) > 0.05)
    return cloud, vein


def alabaster(ctx, seed=503, center=7.2, tooled=0.0):
    """Plain dressed gypsum alabaster (slab edges, plinths, carved blocks):
    banded cloud, rare dark veins, soft pits, bright arrises, grime in the
    hollows. ``tooled`` adds fine parallel claw-chisel marks."""
    s = Surface(ctx.N)
    q = ctx.p if ctx.tile else np.stack([ctx.uvm[:, 0], np.zeros(ctx.N), ctx.uvm[:, 1]], axis=1) + ctx.part[:, None] * 7.3
    cloud, vein = _veins(ctx, q, seed)
    vein = vein * 0.6
    base = center + cloud * 1.1 + _dither(ctx, 0.7, seed + 5)
    f1, _, cid = ctx.worley(26.0, seed + 6)
    pit = (f1 < 0.1) & (cid > 0.82)
    base -= pit * 1.2 + vein * 2.2
    if tooled:
        along = q[:, 0] * 0.7 + q[:, 2] * 0.71
        tool = (np.mod(along * 160.0 + ctx.fbm(3.0, 2, seed + 7, p=q) * 3.0, 1.0) < 0.22)
        base -= tool * tooled
    s.use_ramp(P["asy_alabaster"], shade=base)
    _age(ctx, s, cavity=2.4, ao=4.0, edge=1.4)
    s.height = ctx.fbm(9.0, 3, seed + 8, p=q) * 0.0006 - pit * 0.0012
    s.rough = 0.62 + ctx.rand(seed + 9) * 0.06 + vein * 0.1
    return s


def gypsum_break(ctx, seed=509):
    """A fresh break through gypsum (the torn-off back of a relief enemy,
    the walls of an empty pocket, chips): small crystalline facets catching
    the light at random, a few deeper conchoidal scoops, paler than the
    weathered carved face, grime only in the deepest hollows."""
    s = Surface(ctx.N)
    f1, f2, cid = ctx.worley(34.0, seed)
    facet = noise.rand_cells(np.floor(cid * 9973).astype(np.int64), seed + 1) - 0.5
    g1, g2, gid = ctx.worley(9.0, seed + 7)
    scoop = noise.rand_cells(np.floor(gid * 7919).astype(np.int64), seed + 8) - 0.5
    ridge = np.clip(1.0 - (f2 - f1) / 0.05, 0.0, 1.0) * 0.6
    base = 6.0 + facet * 1.5 + scoop * 1.4 + ctx.fbm(6.0, 3, seed + 2) * 0.7 + _dither(ctx, 0.7, seed + 3) - ridge
    sparkle = ctx.rand(seed + 4) > 0.975
    base += sparkle * 1.6
    s.use_ramp(P["asy_gypsum_break"], shade=base)
    s.shade -= ctx.cavity(3.0) * 2.0 + (1.0 - ctx.ao) * 3.5
    s.height = facet * 0.0015 + scoop * 0.004 - ridge * 0.001 + ctx.fbm(14.0, 2, seed + 5) * 0.0008
    s.rough = 0.72 + ctx.rand(seed + 6) * 0.1 - sparkle * 0.3
    return s


# --------------------------------------------------------------------------
# wood, metal, clay, glaze, fire
# --------------------------------------------------------------------------

def cedar(ctx, seed=521, center=4.6):
    """Old cedar: tight reddish grain, oiled and darkened by soot, checks
    along the grain, bright worn arrises."""
    s = _wood_core(ctx, P["asy_cedar"], center, seed, ring_freq=12.0, contrast=1.1)
    along, across = _grain_frame(ctx)
    a = np.sum(ctx.p * along, axis=1)
    c = np.sum(ctx.p * across, axis=1)
    check = np.abs(noise.fbm(np.stack([a * 0.4, c * 18.0, np.zeros(ctx.N)], axis=1), 2, seed + 1)) < 0.025
    s.shade -= check * 2.2
    _age(ctx, s, cavity=1.8, ao=3.0, edge=1.3)
    s.height = s.height - check * 0.0015
    s.rough = 0.55 + ctx.rand(seed + 2) * 0.08 + np.clip(ctx.fbm(2.0, 3, seed + 3), 0, 1) * 0.15
    return s


def clay(ctx, seed=541, center=5.0, writing=True, line=0.012):
    """Baked clay of tablets: warm ochre, mottled firing clouds, darker
    edges; ``writing`` presses rows of tiny wedges into faces (metre UVs)."""
    s = Surface(ctx.N)
    base = center + ctx.fbm(6.0, 3, seed) * 1.2 + ctx.fbm(22.0, 2, seed + 1) * 0.5 + _dither(ctx, 0.6, seed + 2)
    fire = smoothstep(0.2, 0.8, ctx.fbm(3.0, 3, seed + 3))
    base -= fire * 1.8
    h = ctx.fbm(30.0, 2, seed + 4) * 0.0003
    if writing:
        u, v = ctx.uvm[:, 0], ctx.uvm[:, 1]
        row = np.floor(v / line)
        fv = v / line - row
        rule = fv < 0.12
        cell = np.floor(u / (line * 0.55)) + row * 131.0
        r = noise.rand_cells(cell.astype(np.int64), seed + 5)
        fu = np.mod(u / (line * 0.55), 1.0)
        wedge = (r > 0.25) & (fu < 0.45) & (fv > 0.3) & (fv < 0.85)
        head = wedge & (fu < 0.25)
        base -= wedge * 1.6 + head * 0.8 + rule * 0.6
        h = h - wedge * 0.0006 - head * 0.0004
    s.use_ramp(P["asy_clay"], shade=base)
    _age(ctx, s, cavity=2.0, ao=3.0, edge=1.0)
    s.height = h
    s.rough = 0.78 + ctx.rand(seed + 6) * 0.08
    return s


def glaze(ctx, ramp, center, seed=547, crackle=1.0):
    """Glazed brick: glossy, fine crackle, worn bright arrises."""
    s = Surface(ctx.N)
    base = center + ctx.fbm(4.0, 3, seed) * 0.6 + _dither(ctx, 0.5, seed + 1)
    craze = (np.abs(ctx.fbm(14.0, 3, seed + 2)) < 0.02) * crackle
    base -= craze * 1.2
    s.use_ramp(P["asy_" + ramp], shade=base)
    _age(ctx, s, cavity=1.6, ao=2.5, edge=1.0)
    s.rough = 0.22 + craze * 0.3 + ctx.rand(seed + 3) * 0.05
    s.height = 0.0 - craze * 0.0004
    return s


def flame(ctx, seed=557, strength=1.0):
    """The glowing glass flame of a torch lamp (emissive)."""
    s = Surface(ctx.N)
    z = ctx.p[:, 2]
    z0, z1 = z.min(), z.max()
    t = (z - z0) / max(z1 - z0, 1e-6)
    lick = ctx.fbm(np.array([9.0, 9.0, 3.0]), 3, seed)
    shade = 5.6 - t * 3.2 + lick * 1.4 + _dither(ctx, 0.7, seed + 1)
    s.use_ramp(P["asy_flame"], shade=shade)
    s.emit = s.colors() * strength
    s.rough = np.full(ctx.N, 0.3)
    return s


def bronze_aged(ctx, seed=563, center=5.0, green=1.0):
    """Cast / beaten bronze, darkened, verdigris in the hollows, polished
    highs (Balawat bands, gate fittings, lamassu accents)."""
    s = Surface(ctx.N)
    along, across = _grain_frame(ctx)
    a = np.sum(ctx.p * along, axis=1)
    hammer = ctx.worley(40.0, seed)[0]
    shade = center + ctx.fbm(3.0, 3, seed + 1) * 1.0 + (hammer - 0.4) * 1.4 + _dither(ctx, 0.6, seed + 2)
    shade += ctx.edge(1.0) * 2.4 + ctx.edge(2.0) * 0.8
    shade -= ctx.cavity(3.0) * 2.4 + (1.0 - ctx.ao) * 3.0
    s.use_ramp(P["bronze_metal"], shade=shade * 0.55)
    patina = (smoothstep(0.1, 0.6, ctx.fbm(2.5, 4, seed + 3)) * green + ctx.cavity(3.0) * 0.8
              + (1.0 - ctx.ao) * 0.8) > 0.55
    s.use_ramp(P["bronze"], mask=patina, shade=np.full(ctx.N, 4.5) + ctx.fbm(9.0, 2, seed + 4) * 1.5)
    s.metal = np.where(patina, 0.2, 0.95)
    s.rough = np.where(patina, 0.75, 0.32 + ctx.rand(seed + 5) * 0.06)
    s.height = (hammer - 0.4) * 0.0006
    return s


# --------------------------------------------------------------------------
# tile textures (64 px/m, periodic)
# --------------------------------------------------------------------------

def _uv(ctx):
    return ctx.uvm[:, 0], ctx.uvm[:, 1]


def tile_alabaster(ctx, seed=601):
    """Orthostat facing without carving: gypsum slabs 1-2 m wide and 3 m
    tall standing on the floor (one course per tile height), fine joints,
    a slightly damaged arris, faint tooling. Tile 4 x 3 m."""
    u, v = _uv(ctx)
    W, H = 4.0, 3.0
    courses = course_layout(W, [3.0], [1.0, 1.5, 2.0], seed)
    course, bid, dl, dr, db, dt = blocks(u, v, W, H, courses)
    tx = ctx.texel
    tone = noise.rand_cells(bid, seed) - 0.5
    plain = type(ctx)(ctx.p + tone[:, None] * 37.0, ctx.n, ctx.t, ctx.b, ctx.texel, ctx.seed, None)
    plain.uvm = ctx.uvm
    plain.tile = True
    s = alabaster(plain, seed + 1, center=7.0 + tone * 1.0, tooled=0.5)
    joint = (dl < tx) | (db < tx)
    near = ((dl < 2 * tx) | (dr < 2 * tx) | (db < 2 * tx) | (dt < 2 * tx)) & ~joint
    chip = near & (ctx.fbm(16.0, 2, seed + 2) > 0.3)
    s.shade = np.where(joint, 1.2, s.shade - near * 0.9 - chip * 1.2)
    # foot of the slab: a darker band of floor grime
    s.shade -= smoothstep(0.25, 0.0, np.mod(v, H)) * 1.4
    s.height = s.height - joint * 0.004 - chip * 0.0015
    s.rough = np.where(joint, 0.9, s.rough)
    return s


def tile_plaster(ctx, seed=607):
    """Upper walls: mud plaster with a lime wash, trowel sweeps, hairline
    cracks, soot drifting up in streaks. Tile 4 x 2 m."""
    s = Surface(ctx.N)
    u, v = _uv(ctx)
    sweep = ctx.fbm(np.array([0.8, 1.0, 2.5]), 3, seed)
    base = 5.6 + sweep * 0.7 + ctx.fbm(9.0, 2, seed + 1) * 0.4 + _dither(ctx, 0.6, seed + 2)
    crack = (np.abs(ctx.fbm(1.1, 4, seed + 3)) < 0.01) & (ctx.fbm(0.6, 2, seed + 4) > 0.2)
    soot = smoothstep(0.1, 0.7, ctx.fbm(np.array([2.0, 1.0, 0.35]), 3, seed + 5))
    base -= crack * 2.0 + soot * 1.2
    s.use_ramp(P["asy_alabaster_warm"], shade=base)
    s.height = sweep * 0.0012 - crack * 0.0015 + ctx.fbm(14.0, 2, seed + 6) * 0.0004
    s.rough = 0.88 + ctx.rand(seed + 7) * 0.06
    return s


def tile_mudbrick(ctx, seed=613):
    """Sun-dried mud brick (0.4 x 0.12 m faces) in mud mortar, crumbling
    arrises, straw specks, patches of the plaster skin left on. 4 x 2 m."""
    u, v = _uv(ctx)
    W, H = 4.0, 2.0
    heights = [2.0 / 14.0] * 14
    courses = course_layout(W, heights, [0.4], seed, step=0.2)
    course, bid, dl, dr, db, dt = blocks(u, v, W, H, courses)
    tx = ctx.texel
    s = Surface(ctx.N)
    tone = noise.rand_cells(bid, seed) - 0.5
    base = 4.8 + tone * 1.6 + ctx.fbm(5.0, 3, seed + 1) * 0.9 + _dither(ctx, 0.8, seed + 2)
    straw = (ctx.rand(seed + 3) > 0.94)
    base += straw * 1.4
    joint = (db < 1.5 * tx) | (dl < 1.2 * tx)
    erode = (np.minimum(np.minimum(dl, dr), np.minimum(db, dt)) < 3 * tx) & (ctx.fbm(12.0, 2, seed + 4) > 0.1)
    base = np.where(joint, 2.0 + ctx.rand(seed + 5), base - erode * 1.0)
    s.use_ramp(P["asy_mudbrick"], shade=base)
    skin = smoothstep(0.25, 0.45, ctx.fbm(0.9, 4, seed + 6))
    s.use_ramp(P["asy_alabaster_warm"], mask=skin > 0.5, shade=np.full(ctx.N, 4.6) + ctx.fbm(8.0, 2, seed + 7) * 0.8)
    s.height = 0.0 - joint * 0.006 - erode * 0.002 + skin * 0.002 + ctx.fbm(10.0, 2, seed + 8) * 0.001
    s.rough = 0.92 + ctx.rand(seed + 9) * 0.05
    return s


def tile_floor_gypsum(ctx, seed=619):
    """Gallery paving: gypsum slabs 1 x 1 and 2 x 1 m in running courses,
    worn smooth along the walking lines, bitumen-dark joints. 4 x 4 m."""
    u, v = _uv(ctx)
    W, H = 4.0, 4.0
    courses = course_layout(W, [1.0] * 4, [1.0, 2.0], seed, step=0.5)
    course, bid, dl, dr, db, dt = blocks(u, v, W, H, courses)
    tx = ctx.texel
    tone = noise.rand_cells(bid, seed) - 0.5
    plain = type(ctx)(ctx.p + tone[:, None] * 41.0, ctx.n, ctx.t, ctx.b, ctx.texel, ctx.seed, None)
    plain.uvm = ctx.uvm
    plain.tile = True
    s = alabaster(plain, seed + 1, center=6.0 + tone * 1.3)
    joint = (dl < tx) | (db < tx)
    near = ((dl < 2 * tx) | (db < 2 * tx) | (dr < 2 * tx) | (dt < 2 * tx)) & ~joint
    s.use_ramp(P["asy_bitumen"], mask=joint, shade=np.full(ctx.N, 2.0) + ctx.rand(seed + 2))
    s.shade = np.where(near, s.shade - 1.0, s.shade)
    wear = smoothstep(0.0, 0.6, ctx.fbm(0.7, 3, seed + 3))
    s.rough = np.where(joint, 0.9, 0.5 - wear * 0.18 + ctx.rand(seed + 4) * 0.05)
    s.height = s.height - joint * 0.004 - near * 0.001
    return s


def tile_floor_brick(ctx, seed=631):
    """Courtyard pavement: square baked bricks (1/3 m) in bitumen, a few
    stamped with a framed royal inscription, chipped corners, moss-dark
    joints. Tile 2 x 2 m (6 x 6 bricks)."""
    u, v = _uv(ctx)
    b = 2.0 / 6.0
    ix = np.floor(np.mod(u, 2.0) / b + 1e-9).astype(np.int64)
    iy = np.floor(np.mod(v, 2.0) / b + 1e-9).astype(np.int64)
    fx = np.mod(u, 2.0) - ix * b
    fy = np.mod(v, 2.0) - iy * b
    tx = ctx.texel
    bid = ix * 7 + iy
    tone = noise.rand_cells(bid, seed) - 0.5
    s = Surface(ctx.N)
    base = 5.0 + tone * 1.6 + ctx.fbm(4.0, 3, seed + 1) * 0.8 + _dither(ctx, 0.7, seed + 2)
    joint = (fx < 1.5 * tx) | (fy < 1.5 * tx)
    edge_d = np.minimum(np.minimum(fx, b - fx), np.minimum(fy, b - fy))
    chip = (edge_d < 3 * tx) & (ctx.fbm(14.0, 2, seed + 3) > 0.2)
    base -= chip * 1.2
    # stamps: a framed panel of wedge rows on every 5th brick
    stamped = noise.rand_cells(bid, seed + 4) > 0.8
    cx, cy = fx - b / 2, fy - b / 2
    frame = stamped & (np.abs(cx) < 0.1) & (np.abs(cy) < 0.07)
    rim = frame & ((np.abs(cx) > 0.1 - 1.2 * tx) | (np.abs(cy) > 0.07 - 1.2 * tx))
    rows = frame & ~rim & (np.mod(cy + 0.07, 0.035) < 0.012) & (noise.rand_cells(
        (np.floor((cx + 0.1) / 0.012) + bid * 31).astype(np.int64), seed + 5) > 0.3)
    base -= rim * 1.6 + rows * 1.4
    base = np.where(joint, 1.5, base)
    s.use_ramp(P["asy_brick_baked"], shade=base)
    s.use_ramp(P["asy_bitumen"], mask=joint, shade=np.full(ctx.N, 2.5) + ctx.rand(seed + 6))
    s.height = 0.0 - joint * 0.005 - chip * 0.002 - rim * 0.0015 - rows * 0.001 + ctx.fbm(9.0, 2, seed + 7) * 0.0008
    s.rough = np.where(joint, 0.85, 0.82 + ctx.rand(seed + 8) * 0.06)
    return s


def tile_cedar(ctx, seed=641):
    """Ceiling of cedar boards (0.25 m) between the beams, soot-dark toward
    the middle. Tile 2 x 2 m, boards along u."""
    u, v = _uv(ctx)
    w = 0.25
    k = np.floor(np.mod(v, 2.0) / w + 1e-9).astype(np.int64)
    fv = np.mod(v, 2.0) - k * w
    seg_len = 2.0
    off = noise.rand_cells(k, seed) * 50.0
    plain = type(ctx)(ctx.p + off[:, None], ctx.n, np.tile([1.0, 0, 0], (ctx.N, 1)),
                      np.tile([0, 0, 1.0], (ctx.N, 1)), ctx.texel, ctx.seed, None)
    plain.long_u = np.ones(ctx.N, bool)
    s = _wood_core(plain, P["asy_cedar"], 4.2 + (noise.rand_cells(k, seed + 1) - 0.5) * 1.6, seed + 2,
                   ring_freq=10.0, contrast=1.0)
    gap = fv < ctx.texel * 1.2
    s.shade = np.where(gap, 0.5, s.shade)
    s.shade -= smoothstep(0.0, 0.6, ctx.fbm(0.6, 3, seed + 3)) * 1.2
    s.height = s.height - gap * 0.003
    s.rough = 0.62 + ctx.rand(seed + 4) * 0.08
    return s


MATERIALS = {
    "asy_alabaster": tile_alabaster,
    "asy_plaster": tile_plaster,
    "asy_mudbrick": tile_mudbrick,
    "flagstone_asy": tile_floor_gypsum,
    "tiles_asy_brick": tile_floor_brick,
    "asy_cedar": tile_cedar,
}

# name, material, width m, height m, px per metre, normal strength (build_textures.TILES rows)
TILES = [
    ("asy_alabaster", "asy_alabaster", 4.0, 3.0, 64, 2.0),
    ("asy_plaster", "asy_plaster", 4.0, 2.0, 64, 1.5),
    ("asy_mudbrick", "asy_mudbrick", 4.0, 2.0, 64, 2.5),
    ("flagstone_asy", "flagstone_asy", 4.0, 4.0, 64, 2.0),
    ("tiles_asy_brick", "tiles_asy_brick", 2.0, 2.0, 64, 2.0),
    ("asy_cedar", "asy_cedar", 2.0, 2.0, 64, 2.0),
]


# --------------------------------------------------------------------------
# a carved relief baked onto a face
# --------------------------------------------------------------------------

class ReliefMaps:
    """The composed maps of a Relief (or of some of its parts) with the
    shading terms precomputed, sampled per texel by metre UV."""

    def __init__(self, R, parts=None, base=True, own=None):
        self.R = R
        if own is not None:
            h, mat, cov = R.own(own)
            self.h, self.mat, self.cov = h, mat, cov
        else:
            self.h, self.mat, self.cov = R.compose(parts, base)
        self.cav, self.rim, self.gx, self.gy = relief.relief_terms(self.h, R.px)
        self.emit = R.emit

    def sample(self, u, v):
        row, col = self.R.index(u, v)
        return row, col


def relief_material(maps, seed=701, center=9.0, uv=None, paint=1.0, bevel=0.6, grime=1.0, emit_color=None,
                    plain=None):
    """Material function: the relief ``maps`` (ReliefMaps) on the faces that
    carry it. ``uv(ctx)`` -> (u, v) metres in relief space (default: the
    face's metre UVs). Gypsum shaded by the carving (crevices -2.5 steps,
    raised rims +1.5, a faint upper-left bevel), black paint left in the
    hair and beards, flaking red ochre, white eyes; height = the carving."""
    def fn(ctx):
        u, v = uv(ctx) if uv is not None else (ctx.uvm[:, 0], ctx.uvm[:, 1])
        row, col = maps.sample(u, v)
        h = maps.h[row, col]
        mat = maps.mat[row, col]
        cav = maps.cav[row, col]
        rim = maps.rim[row, col]
        gx, gy = maps.gx[row, col], maps.gy[row, col]
        s = Surface(ctx.N)
        q = np.stack([u, np.zeros(ctx.N), v], axis=1) + 3.1
        cloud, vein = _veins(ctx, q, seed)
        carved = mat != relief.BG
        base = center + cloud * 0.9 + _dither(ctx, 0.6, seed + 1) - vein * 1.6
        base += carved * 0.5                      # smoothed carved surfaces read a touch lighter
        # flat background: faint claw-chisel tooling
        tool = (np.mod((u * 0.5 + v * 0.86) * 150.0 + ctx.fbm(3.0, 2, seed + 2, p=q) * 3.0, 1.0) < 0.2) & ~carved
        base -= tool * 0.6
        base -= cav * 2.6 * grime
        base += rim * 1.4
        # a faint key light from the upper left keeps the forms readable in flat light
        lit = np.clip((-gx * 0.7 + gy * 0.7) * 0.5, -1.0, 1.0)
        base += lit * bevel * 2.0
        # grime and dust settle toward the foot of the slab
        base -= smoothstep(0.35, 0.0, v - maps.R.v0) * 1.0 * grime
        s.use_ramp(P["asy_alabaster"], shade=base)
        # paint traces, flaking: stone shows through where the noise says so
        flake = ctx.fbm(np.array([40.0, 40.0, 40.0]), 2, seed + 3, p=q) + ctx.fbm(7.0, 2, seed + 4, p=q) * 0.6
        # black paint survives in the hollows of hair and beards and in patches
        is_hair = mat == relief.HAIR
        hair = is_hair & ((cav > 0.2) | (flake > 0.1 + (1.0 - paint) * 0.9))
        s.shade = np.where(is_hair & ~hair, s.shade - 2.2, s.shade)
        s.use_ramp(P["asy_paint_black"], mask=hair, shade=2.6 + cloud * 0.5 + rim * 1.8 - cav * 1.2
                   + lit * bevel * 1.4 + _dither(ctx, 0.6, seed + 5))
        red = (mat == relief.RED) & (flake > -0.25 + (1.0 - paint) * 0.9)
        s.use_ramp(P["asy_ochre_red"], mask=red, shade=3.2 + cloud * 0.6 + rim - cav + _dither(ctx, 0.6, seed + 6))
        blue = (mat == relief.BLUE) & (flake > -0.1)
        s.use_ramp(P["asy_lapis"], mask=blue, shade=3.4 + cloud * 0.6 + rim - cav + _dither(ctx, 0.6, seed + 7))
        eye = mat == relief.EYE
        s.use_ramp(P["asy_glaze_white"], mask=eye, shade=np.full(ctx.N, 3.6) + rim - cav * 0.8)
        pupil = mat == relief.PUPIL
        s.use_ramp(P["asy_paint_black"], mask=pupil, shade=np.full(ctx.N, 1.0))
        if plain is not None:
            # faces outside the relief rectangle: plain stone
            out = (u < maps.R.u0) | (u > maps.R.u0 + maps.R.w_m) | (v < maps.R.v0) | (v > maps.R.v0 + maps.R.h_m)
            if out.any():
                p2 = plain(ctx.subset(out))
                s.merge(p2, out)
        s.shade -= (1.0 - ctx.ao) * 2.5
        s.height = h + ctx.fbm(14.0, 2, seed + 8, p=q) * 0.0004 - tool * 0.0004
        s.rough = np.where(hair | red, 0.82, 0.6 + ctx.rand(seed + 9) * 0.06 - carved * 0.05)
        if maps.emit is not None and maps.emit.any() and emit_color is not None:
            e = maps.emit[row, col]
            glow = e > 0.02
            if glow.any():
                s.use_ramp(P["asy_flame"], mask=glow, shade=3.0 + e * 4.5)
                col3 = np.array(emit_color, dtype=np.float64)
                s.emit = np.zeros((ctx.N, 3))
                s.emit[glow] = s.colors()[glow] * np.clip(e[glow], 0.0, 1.0)[:, None]
        return s
    return fn


def flat_ctx(R):
    """A painter context covering the relief rectangle (u right, v up), for
    previews and flat texture sets: one texel per relief texel."""
    from .painter import Ctx
    N = R.W * R.H
    p = np.stack([R.X.ravel(), np.zeros(N), R.Y.ravel()], axis=1)
    n = np.tile([0.0, -1.0, 0.0], (N, 1))
    t = np.tile([1.0, 0.0, 0.0], (N, 1))
    b = np.tile([0.0, 0.0, 1.0], (N, 1))
    ctx = Ctx(p, n, t, b, R.px, R.seed, None)
    ctx.uvm = np.stack([R.X.ravel(), R.Y.ravel()], axis=1)
    return ctx


def preview_png(R, fn, path, light=(-0.75, 0.45, 0.48), scale=2, maps=None):
    """Renders ``fn`` (a relief material) over the relief rectangle lit by a
    low raking light, with cast shadows from the carving: a 2D check of a
    design in seconds."""
    from . import imageio
    ctx = flat_ctx(R)
    s = fn(ctx)
    alb = s.colors().reshape(R.H, R.W, 3)
    h = s.height.reshape(R.H, R.W)
    img = relief.preview(h, alb, R.px, light=light)
    if s.emit is not None:
        img = np.clip(img + s.emit.reshape(R.H, R.W, 3) * 1.5, 0, 1)
    img = np.repeat(np.repeat(img, scale, axis=0), scale, axis=1)
    imageio.save_png(path, img)
    return img


def relief_bronze(maps, seed=721, uv=None, center=5.0):
    """Material function: a relief (ReliefMaps) beaten in bronze (the
    repousse bands of the Balawat gates): the raised figures polished to a
    warm gold, the sunk ground dark bronze with green-black patina packed
    against the figures, so tiny figures still read as bright silhouettes."""
    def fn(ctx):
        u, v = uv(ctx) if uv is not None else (ctx.uvm[:, 0], ctx.uvm[:, 1])
        row, col = maps.sample(u, v)
        h = maps.h[row, col]
        cav = maps.cav[row, col]
        rim = maps.rim[row, col]
        raised = h > 0.0018
        s = Surface(ctx.N)
        shade = center + ctx.fbm(4.0, 3, seed) * 0.6 + _dither(ctx, 0.6, seed + 1)
        shade = np.where(raised, shade + 2.6 + rim * 1.5, shade - 1.0 - cav * 2.2)
        shade += ctx.edge(1.0) * 1.8 - (1.0 - ctx.ao) * 2.5
        s.use_ramp(P["bronze_metal"], shade=shade * 0.62)
        patina = ~raised & ((cav > 0.08) | (ctx.fbm(3.0, 3, seed + 2) > -0.35))
        s.use_ramp(P["bronze"], mask=patina, shade=np.full(ctx.N, 2.6) + ctx.fbm(11.0, 2, seed + 3) * 1.2 - cav * 1.5)
        s.metal = np.where(patina, 0.1, 0.75)
        s.rough = np.where(patina, 0.82, np.where(raised, 0.42, 0.5) + ctx.rand(seed + 4) * 0.05)
        s.height = h + ctx.fbm(30.0, 2, seed + 5) * 0.0003
        return s
    return fn
