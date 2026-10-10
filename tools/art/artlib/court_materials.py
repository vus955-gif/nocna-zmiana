"""Materials of Floor I's Great Court, Reading Room and entrance hall.

Same rules as materials.py / arch_materials.py: every colour comes from a
hand-picked ramp (registered in the shared P, dark -> light), shading =
steps along a ramp, patterns in the surface's metre UVs so a function paints
a tile (64 px/m, world-mapped in the game) and a model atlas alike.

  limestone_court       pale limestone slabs of the court (6 x 6 m tile)
  portland_ashlar   Portland-stone ashlar, 0.75 m courses (4.5 x 3 m tile)
  court_steel       pale grey painted steel of the roof lattice (2 x 2 m)
  carpet_reading         the Reading Room's navy carpet with a gold lattice (2 x 2 m)
  portland          dressed Portland stone for carved pieces (atlas)
  ashlar_face       Portland ashlar joints painted in a model atlas
  rusticated_face   banded rustication of the drum's ground storey (atlas)
  dome_coffer / dome_rib / lead / cedar / formline paints: hero pieces
"""
import numpy as np

from . import noise
from .arch_materials import blocks, course_layout
from .materials import P, _age, _dither, _grain_frame, _wood_core, hexramp, smoothstep
from .painter import Surface

P.update({
    # Portland stone: cooler and paler than the lobby's limestone
    "portland": hexramp("#38372f", "#4a4840", "#5d5b52", "#717067", "#86847a", "#9a988e", "#adaba1",
                        "#bebcb2", "#cdccc3", "#dad9d1", "#e6e5de"),
    # the court floor: warm pale French limestone
    "lime_floor": hexramp("#3c3830", "#4f4a40", "#635d51", "#777064", "#8b8476", "#9e9788", "#b0a999",
                          "#c0b9a9", "#cdc7b8", "#d9d3c5", "#e3decf"),
    "lime_fossil": hexramp("#6e6656", "#857c6a", "#9b9280"),
    # light grey painted structural steel (the roof): bright, so the
    # lattice reads against the night sky and catches the uplights
    "steel_paint": hexramp("#202326", "#2d3135", "#3c4045", "#4d5257", "#60656a", "#757a7f", "#8b9095",
                           "#a1a6aa", "#b6babd", "#c8cbcd", "#d7d9da"),
    "carpet_blue": hexramp("#04060f", "#070b19", "#0a1024", "#0e1630", "#131d3d", "#19254b", "#202e59",
                           "#283868"),
    # the Reading Room dome: pale azure fields, cream ribs, gilding
    "dome_blue": hexramp("#101a28", "#172437", "#1f3047", "#283d58", "#334b69", "#405b7b", "#4f6c8d",
                         "#607e9e", "#7391ae", "#88a5bf", "#9fbace"),
    "dome_cream": hexramp("#423d33", "#575145", "#6d6658", "#847c6c", "#9b9381", "#b1a996", "#c5bea9",
                          "#d6d0bc", "#e4dfcd"),
    "lead": hexramp("#15171a", "#1d2023", "#262a2e", "#30353a", "#3b4147", "#474e55", "#545c63", "#626a72"),
    # weathered western red cedar and the formline paints of the totem
    "cedar": hexramp("#1d120c", "#2a1b12", "#382419", "#472e20", "#573928", "#684531", "#7a523b", "#8c6147",
                     "#9d7157", "#ad836a"),
    "cedar_grey": hexramp("#2c2824", "#3b3631", "#4b453f", "#5c554e", "#6e665e", "#80786f", "#928a80"),
    "formline_red": hexramp("#2a0706", "#420b08", "#5c110c", "#771810", "#922116", "#aa2c1e", "#c03a28"),
    "formline_black": hexramp("#060607", "#0c0c0e", "#131315", "#1b1b1e", "#242428", "#2e2e33"),
    "formline_teal": hexramp("#04201d", "#07302b", "#0b403a", "#11524a", "#18665b", "#217a6d", "#2c8e7f",
                             "#3aa291"),
    # wing colours (wayfinding)
    "wing_egypt": hexramp("#2e220f", "#463418", "#5f4822", "#7a5e2e", "#96773d", "#b0904f", "#c8a964",
                          "#dcc07c", "#ead396"),
    "wing_assyria": hexramp("#0d121c", "#151d2b", "#1e293b", "#28364c", "#33445e", "#405470", "#4f6583",
                            "#617896", "#768ca9"),
    "wing_greece": hexramp("#05112e", "#081944", "#0c225a", "#112c70", "#173886", "#20469a", "#2c56ad"),
    "wing_enlight": hexramp("#04140a", "#082012", "#0d2d1a", "#123a22", "#18482b", "#1f5735", "#286740",
                            "#32784c"),
    "wing_asia": hexramp("#1c0403", "#2e0705", "#430b07", "#590f0a", "#70150d", "#881c11", "#a02516", "#b8301c"),
    "wing_americas": hexramp("#032422", "#063432", "#0a4643", "#105955", "#176d68", "#20827b", "#2b968e",
                             "#39aaa1", "#4bbdb3"),
    "enamel_cream": hexramp("#3d382c", "#544d3e", "#6c6452", "#857c67", "#9d947d", "#b5ac94", "#cbc3aa",
                            "#ddd6bf", "#ebe6d2"),
    "green_glass": hexramp("#021208", "#05200f", "#093018", "#0e4222", "#14552d", "#1c6a3a", "#258048"),
    "cast_iron": hexramp("#0c0d0e", "#131416", "#1a1c1f", "#222528", "#2b2f33", "#353a3f", "#40464c"),
    "bronze_door": hexramp("#120c06", "#1e140a", "#2b1d0e", "#3a2813", "#4a3318", "#5b3f1e", "#6d4c25",
                           "#80592c", "#946835", "#a8783f"),
})


def _uv(ctx):
    return ctx.uvm[:, 0], ctx.uvm[:, 1]


# --------------------------------------------------------------------------
# stone
# --------------------------------------------------------------------------

def _stone_body(ctx, ramp, center, seed, fossils=True, grain=1.0):
    """Shared texture of a fine oolitic limestone: soft clouds, specks,
    shell fragments (Portland is full of them)."""
    base = center + ctx.fbm(1.2, 4, seed) * 0.9 * grain + ctx.fbm(8.0, 2, seed + 1) * 0.45 * grain
    base += _dither(ctx, 0.6, seed + 2)
    if fossils:
        f1, _, cid = ctx.worley(18.0, seed + 3)
        shell = (f1 < 0.1) & (cid > 0.78)
        base += np.where(shell, np.where(cid > 0.9, 0.9, -1.1), 0.0)
    return base


def portland(ctx, seed=501, center=6.6):
    """Dressed Portland stone for carved and moulded pieces (atlas)."""
    s = Surface(ctx.N)
    s.use_ramp(P["portland"], shade=_stone_body(ctx, P["portland"], center, seed))
    _age(ctx, s, cavity=2.4, ao=4.0, edge=1.3)
    # rain-streak grime under projections (vertical faces only, darker low)
    if not ctx.tile:
        vert = np.abs(ctx.n[:, 2]) < 0.3
        streak = ctx.fbm(np.array([9.0, 9.0, 0.6]), 2, seed + 6) > 0.35
        s.shade -= (vert & streak) * 0.35
    s.height = ctx.fbm(10.0, 3, seed + 4) * 0.0008
    s.rough = 0.8 + ctx.rand(seed + 5) * 0.08
    return s


def ashlar(ctx, W, H, course, choices, seed, ramp="portland", center=6.7, rustic=False):
    """Coursed ashlar in the face's metre UVs: ``course`` m high beds, block
    lengths from ``choices``; rustic = deep V-channel on the bed joints."""
    u, v = _uv(ctx)
    courses = course_layout(W, [course] * int(round(H / course)), choices, seed)
    _, bid, dl, dr, db, dt = blocks(u, v, W, H, courses)
    tx = ctx.texel
    s = Surface(ctx.N)
    tone = noise.rand_cells(bid, seed) - 0.5
    base = _stone_body(ctx, P[ramp], center, seed + 1) + tone * 0.9
    if rustic:
        ch = 2.5 * tx
        below = db < ch
        above = dt < ch
        line = (db < tx) | (dt < tx)
        base = np.where(below, base - 2.4, base)
        base = np.where(above & ~below, base + 1.0, base)
        base = np.where(line, base - 3.0, base)
        head = dl < tx
        base = np.where(head & ~line, base - 2.0, base)
        depth = np.clip(1.0 - np.minimum(db, dt) / ch, 0.0, 1.0)
        height = -depth * 0.018 - head * 0.004
    else:
        joint = (db < tx) | (dl < tx)
        arris = ((dt < tx) | (dr < tx)) & ~joint
        base = np.where(joint, base - 2.4, base)
        base = np.where(arris, base + 0.6, base)
        height = joint * -0.003
    chip = (np.minimum(np.minimum(dl, dr), np.minimum(db, dt)) < 3 * tx) & (ctx.fbm(14.0, 2, seed + 5) > 0.4)
    base = np.where(chip, base - 0.8, base)
    s.use_ramp(P[ramp], shade=base)
    if not ctx.tile:
        _age(ctx, s, cavity=2.0, ao=3.5, edge=1.0)
    s.height = height + ctx.fbm(9.0, 3, seed + 6) * 0.0007 - chip * 0.001
    s.rough = 0.78 + ctx.rand(seed + 7) * 0.08
    return s


def portland_ashlar(ctx, seed=503):
    """Tile 4.5 x 3 m: Portland ashlar in 0.75 m courses, blocks 1-2.25 m."""
    return ashlar(ctx, 4.5, 3.0, 0.75, [1.0, 1.25, 1.5, 1.75, 2.25], seed)


def ashlar_face(ctx, seed=505):
    """Atlas version: the same bond in the face's own metre UVs."""
    return ashlar(ctx, 4.5, 3.0, 0.75, [1.0, 1.25, 1.5, 1.75, 2.25], seed, center=6.5)


def rusticated_face(ctx, seed=507):
    """Banded rustication (0.5 m courses with V-channels) in Portland."""
    return ashlar(ctx, 6.0, 3.0, 0.5, [1.0, 1.25, 1.5, 1.75, 2.0], seed, center=6.3, rustic=True)


def limestone_court(ctx, seed=511):
    """Tile 6 x 6 m: the court's pale limestone floor, 1 m courses of 1, 1.5
    and 2 m slabs in a shifting bond, hairline joints with a lit arris,
    per-slab tone, shell specks and faint bedding streaks, worn polish."""
    u, v = _uv(ctx)
    W, H = 6.0, 6.0
    courses = course_layout(W, [1.0] * 6, [1.0, 1.5, 1.5, 2.0], seed, step=0.5)
    _, bid, dl, dr, db, dt = blocks(u, v, W, H, courses)
    tx = ctx.texel
    s = Surface(ctx.N)
    tone = noise.rand_cells(bid, seed) - 0.5
    lean = noise.rand_cells(bid, seed + 11)
    # bedding: soft streaks along each slab's length, phase per slab
    streak = ctx.fbm(np.array([0.8, 1.0, 6.0]), 2, seed + 12,
                     p=np.stack([u + lean * 7.0, lean * 3.0, v + lean * 5.0], axis=1))
    base = 7.2 + tone * 0.9 + ctx.fbm(0.9, 4, seed + 1) * 0.6 + ctx.fbm(7.0, 2, seed + 2) * 0.3
    base += streak * 0.5 + _dither(ctx, 0.5, seed + 3)
    f1, _, cid = ctx.worley(16.0, seed + 4)
    fossil = (f1 < 0.12) & (cid > 0.84)
    joint = (db < tx) | (dl < tx)
    arris = ((dt < tx) | (dr < tx)) & ~joint
    base = np.where(arris, base + 0.6, base)
    base = np.where(joint, 3.4 + _dither(ctx, 0.8, seed + 6), base)
    s.use_ramp(P["lime_floor"], shade=base)
    s.use_ramp(P["lime_fossil"], mask=fossil & ~joint, shade=np.full(ctx.N, 1.2) + _dither(ctx, 1.4, seed + 5))
    wear = smoothstep(0.1, 0.7, ctx.fbm(0.6, 3, seed + 7))
    s.rough = np.where(joint, 0.8, 0.3 + (1.0 - wear) * 0.28 + ctx.rand(seed + 8) * 0.04)
    s.height = joint * -0.0015 + ctx.fbm(10.0, 2, seed + 9) * 0.0003
    return s


# --------------------------------------------------------------------------
# metal, fabric
# --------------------------------------------------------------------------

def court_steel(ctx, seed=521, center=7.6):
    """Pale grey painted steel: faint roller texture, darker grime in
    hollows, a few rust blooms at the joints."""
    s = Surface(ctx.N)
    base = center + ctx.fbm(1.5, 3, seed) * 0.6 + ctx.fbm(12.0, 2, seed + 1) * 0.3 + _dither(ctx, 0.5, seed + 2)
    s.use_ramp(P["steel_paint"], shade=base)
    if not ctx.tile:
        _age(ctx, s, cavity=1.8, ao=3.0, edge=1.2)
    bloom = (ctx.fbm(5.0, 3, seed + 3) > 0.5) & (ctx.rand(seed + 4) > 0.4)
    s.use_ramp(P["rust"], mask=bloom, shade=np.full(ctx.N, 1.6) + _dither(ctx, 1.0, seed + 5))
    s.metal = np.where(bloom, 0.0, 0.25)
    s.rough = np.where(bloom, 0.8, 0.42 + ctx.rand(seed + 6) * 0.06)
    s.height = ctx.fbm(14.0, 2, seed + 7) * 0.0002
    return s


def carpet_reading(ctx, seed=531):
    """Tile 2 x 2 m: navy wool carpet, a gold diamond trellis every 0.5 m
    with a small four-petal flower at each crossing."""
    u, v = _uv(ctx)
    tx = ctx.texel
    s = Surface(ctx.N)
    pile = ctx.fbm(np.array([40.0, 40.0, 40.0]), 2, seed) * 0.5
    base = 4.0 + pile + ctx.fbm(1.0, 3, seed + 1) * 0.5 + _dither(ctx, 0.9, seed + 2)
    s.use_ramp(P["carpet_blue"], shade=base)
    # diamond trellis: lines of |du| + |dv| on a 0.5 m lattice
    a = np.mod(u + v, 0.5)
    b = np.mod(u - v, 0.5)
    line = (np.abs(a - 0.25) < tx * 0.75) | (np.abs(b - 0.25) < tx * 0.75)
    cu = np.mod(u, 0.5) - 0.25
    cv = np.mod(v, 0.5) - 0.25
    r = np.hypot(cu, cv)
    ang = np.arctan2(cv, cu)
    flower = r < 0.045 * (0.55 + 0.45 * np.abs(np.cos(2.0 * ang)))
    ink = line | flower
    s.use_ramp(P["gold"], mask=ink, shade=np.full(ctx.N, 4.6) + _dither(ctx, 1.2, seed + 3))
    s.use_ramp(P["cloth_red"], mask=r < 0.012, shade=np.full(ctx.N, 4.0))
    s.rough = np.full(ctx.N, 0.95)
    s.height = pile * 0.0006
    return s


def cast_iron(ctx, seed=541, center=4.2):
    """Black-painted cast iron (railings, brackets, lamp standards)."""
    s = Surface(ctx.N)
    base = center + ctx.fbm(4.0, 3, seed) * 0.6 + _dither(ctx, 0.6, seed + 1)
    s.use_ramp(P["cast_iron"], shade=base)
    _age(ctx, s, cavity=1.2, ao=2.0, edge=2.0)
    s.metal = np.full(ctx.N, 0.35)
    s.rough = 0.45 + ctx.rand(seed + 2) * 0.08
    return s


def lead(ctx, seed=543):
    """Lead roofing: dull grey, faint white oxide bloom, darker seams."""
    s = Surface(ctx.N)
    base = 4.4 + ctx.fbm(2.0, 3, seed) * 0.8 + _dither(ctx, 0.6, seed + 1)
    bloom = smoothstep(0.3, 0.8, ctx.fbm(3.0, 3, seed + 2))
    base += bloom * 1.5
    s.use_ramp(P["lead"], shade=base)
    _age(ctx, s, cavity=1.6, ao=2.5, edge=1.5)
    s.metal = np.full(ctx.N, 0.4)
    s.rough = 0.62 + bloom * 0.15
    return s


# --------------------------------------------------------------------------
# the Reading Room dome
# --------------------------------------------------------------------------

def dome_cream(ctx, seed=551, center=6.6):
    """Painted plaster of the dome's ribs and mouldings (warm cream)."""
    s = Surface(ctx.N)
    base = center + ctx.fbm(2.5, 3, seed) * 0.6 + _dither(ctx, 0.6, seed + 1)
    s.use_ramp(P["dome_cream"], shade=base)
    _age(ctx, s, cavity=2.2, ao=3.5, edge=1.2)
    s.rough = 0.8 + ctx.rand(seed + 2) * 0.06
    return s


def dome_blue(ctx, seed=553, center=7.8):
    """Azure distemper of the coffer fields: soft, slightly mottled."""
    s = Surface(ctx.N)
    base = center + ctx.fbm(1.8, 3, seed) * 0.7 + ctx.fbm(10.0, 2, seed + 1) * 0.3 + _dither(ctx, 0.6, seed + 2)
    s.use_ramp(P["dome_blue"], shade=base)
    _age(ctx, s, cavity=2.0, ao=4.0, edge=0.8)
    s.rough = 0.85 + ctx.rand(seed + 3) * 0.05
    return s


# --------------------------------------------------------------------------
# wood
# --------------------------------------------------------------------------

def cedar(ctx, seed=561, center=5.2, grey=0.0):
    """Weathered western red cedar: open grain, checks, silvering on the
    upward faces (``grey`` 0..1 = how much has turned silver)."""
    s = _wood_core(ctx, P["cedar"], center, seed, ring_freq=6.0, contrast=1.2)
    along, across = _grain_frame(ctx)
    a = np.sum(ctx.p * along, axis=1)
    c = np.sum(ctx.p * across, axis=1)
    check = np.abs(noise.fbm(np.stack([a * 0.4, c * 18.0, np.zeros(ctx.N)], axis=1), 2, seed + 1)) < 0.025
    s.shade -= check * 2.2
    if grey > 0.0:
        silver = (ctx.fbm(1.5, 3, seed + 2) * 0.5 + 0.5) * grey + np.clip(ctx.n[:, 2], 0, 1) * 0.3 > 0.55
        s.use_ramp(P["cedar_grey"], mask=silver, shade=np.full(ctx.N, 3.6) + ctx.fbm(6.0, 2, seed + 3) * 1.2
                   + _dither(ctx, 0.8, seed + 4))
    _age(ctx, s, cavity=2.0, ao=3.5, edge=1.0)
    s.height = s.height - check * 0.003
    s.rough = 0.82 + ctx.rand(seed + 5) * 0.08
    return s


def cast_iron_tile(ctx, seed=545):
    """Tile 2 x 2 m of black-painted cast iron for thin parts mapped in
    world space (railings, consoles, bars)."""
    s = Surface(ctx.N)
    s.use_ramp(P["cast_iron"], shade=4.0 + ctx.fbm(3.0, 3, seed) * 0.8 + _dither(ctx, 0.8, seed + 1))
    rust = ctx.fbm(6.0, 3, seed + 2) > 0.55
    s.use_ramp(P["rust"], mask=rust, shade=np.full(ctx.N, 1.0) + _dither(ctx, 1.0, seed + 3))
    s.metal = np.where(rust, 0.0, 0.4)
    s.rough = np.where(rust, 0.8, 0.45 + ctx.rand(seed + 4) * 0.08)
    return s


def cedar_pole(ctx, seed=563, center=5.6, grey=0.45):
    """Cedar of a carved pole: the grain runs up the pole whatever the UV
    island (cylindrical frame round the vertical axis), long drying checks,
    silvered streaks where rain runs down."""
    x, y, z = ctx.p[:, 0], ctx.p[:, 1], ctx.p[:, 2]
    ang = np.arctan2(x, y)
    r = np.hypot(x, y)
    c = ang * 0.55
    s = Surface(ctx.N)
    fib = ctx.fbm(np.array([1.0, 1.0, 1.0]), 3, seed, p=np.stack([c * 26.0, r * 26.0, z * 0.8], axis=1))
    streak = ctx.fbm(np.array([1.0, 1.0, 1.0]), 2, seed + 1, p=np.stack([c * 5.0, r * 5.0, z * 0.22], axis=1))
    shade = center + fib * 1.2 + streak * 0.9 + _dither(ctx, 0.6, seed + 2)
    check = np.abs(ctx.fbm(np.array([1.0, 1.0, 1.0]), 2, seed + 3, p=np.stack([c * 14.0, r * 14.0, z * 0.18], axis=1))) < 0.02
    shade -= check * 2.4
    s.use_ramp(P["cedar"], shade=shade)
    if grey > 0.0:
        silver = (streak * 0.5 + 0.5) * grey + np.clip(ctx.n[:, 2], 0, 1) * 0.35 > 0.5
        s.use_ramp(P["cedar_grey"], mask=silver & ~check, shade=np.full(ctx.N, 3.8) + fib * 1.0 + _dither(ctx, 0.7, seed + 4))
    _age(ctx, s, cavity=2.2, ao=3.5, edge=1.0)
    s.height = fib * 0.0006 - check * 0.003
    s.rough = 0.84 + ctx.rand(seed + 5) * 0.06
    return s


MATERIALS = {
    "cast_iron": cast_iron_tile,
    "limestone_court": limestone_court,
    "portland_ashlar": portland_ashlar,
    "court_steel": court_steel,
    "carpet_reading": carpet_reading,
}
