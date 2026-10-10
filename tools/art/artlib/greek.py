"""Materials of the Greek wing (Parthenon galleries, Nereid Monument): ramps
and per-texel functions in the style of materials.py (shading = steps along
a hand-picked ramp), plus the painter of relief sculpture (relief.py maps ->
marble with weathering and traces of the original paint).

Look: Pentelic marble is never flat white. It has a cool body with grey-blue
veils and veins, a honey patina where it weathered (warm ramp, dithered
patches and streaks from upper surfaces), darker grime in the hollows,
sugary bright fractures where it broke, and here and there the paint the
Greeks put on it: Egyptian blue in the backgrounds of friezes and coffers,
red on cloaks and crests, ochre on hair and harness.
"""
import math

import numpy as np

from . import noise
from .arch_materials import blocks, course_layout
from .materials import P, _dither, _marble_core, _select, hexramp, smoothstep
from .painter import Surface
from . import relief as RL

P.update({
    # cool Pentelic body (dark -> light) and its warm, weathered twin
    "gr_marble": hexramp("#3a3b42", "#4c4d53", "#606066", "#75747a", "#8a898c", "#9f9d9e", "#b3b1b0",
                         "#c6c3c0", "#d6d3ce", "#e4e1db", "#efede7", "#f8f6f1"),
    "gr_marble_warm": hexramp("#3e3a37", "#504b47", "#645e58", "#79726a", "#8e867b", "#a39a8d", "#b6ad9f",
                              "#c8beaf", "#d7cebf", "#e4dccd", "#eee8db", "#f7f2e8"),
    "gr_vein": hexramp("#3e434e", "#535a66", "#6a717e", "#838a96", "#9ca2ac"),
    "gr_grey": hexramp("#1f2125", "#2a2d32", "#363940", "#43464e", "#51555d", "#60646c", "#70747c",
                       "#80848c", "#90949b"),
    "gr_grey_vein": hexramp("#6f747c", "#878c94", "#a0a4ab", "#b8bcc1"),
    "gr_grime": hexramp("#1e1a15", "#2b251e", "#3a3228", "#4a4134", "#5b5141"),
    "gr_break": hexramp("#7e7b76", "#96938d", "#aeaba4", "#c5c2bb", "#d9d6cf", "#e9e7e1", "#f6f5f0"),
    # the original paint (faded, flaking)
    "gr_blue": hexramp("#0d1630", "#132144", "#1a2d59", "#233a6f", "#2e4a86", "#3d5c9a", "#5373ae", "#6e8dc0"),
    "gr_red": hexramp("#2c0b08", "#43120c", "#5b1a11", "#742418", "#8c3020", "#a3402b", "#b55439"),
    "gr_ochre": hexramp("#3b2709", "#57390e", "#734d15", "#8f621e", "#a97929", "#c09036", "#d3a84a"),
    "gr_gold": hexramp("#3a2608", "#5c3d0c", "#805612", "#a5711b", "#c58e2a", "#ddab43", "#efc96a", "#f9e3a0"),
    # plaster casts, whitewash, painted walls
    "gr_plaster": hexramp("#5b5850", "#6e6b62", "#827e74", "#969287", "#aaa59a", "#bdb8ad", "#cfcabf",
                          "#ddd9cf", "#e9e6dd", "#f3f1ea"),
    "gr_wall_ochre": hexramp("#2a1210", "#371814", "#451e18", "#53251d", "#612c22", "#6f3428", "#7c3c2f",
                             "#894536"),
    # pottery
    "gr_clay": hexramp("#3a1a0d", "#552612", "#6f3218", "#893f1e", "#a04d25", "#b45c2e", "#c56c39", "#d47e48",
                       "#e0925c"),
    "gr_gloss": hexramp("#060508", "#0c0a0e", "#131016", "#1b171e", "#251f28", "#312a34", "#3e3742"),
    "gr_white_slip": hexramp("#8f8778", "#aaa290", "#c3bba8", "#d8d0bd", "#e8e1cf"),
    "gr_miltos": hexramp("#3e0f0a", "#58170f", "#722014", "#8c2a1a"),
})

GREEK_BLUE_RAMP = "gr_blue"


# --------------------------------------------------------------------------
# marble
# --------------------------------------------------------------------------

def _warm_patches(ctx, seed, amount=1.0, q=None, scale=1.0):
    """Mask of honey-coloured weathering: soft blotches, dithered at the
    edges by texel noise, more on surfaces facing up."""
    p = ctx.p if q is None else q
    blot = ctx.fbm(1.1 * scale, 4, seed, p=p) + ctx.fbm(5.0 * scale, 2, seed + 1, p=p) * 0.35
    up = np.clip(ctx.n[:, 2], 0.0, 1.0) * 0.25 if not ctx.tile else 0.0
    thr = 0.24 - 0.3 * (amount - 1.0) - up
    return (blot + (ctx.rand(seed + 2) - 0.5) * 0.18) > thr


def marble_body(ctx, seed, center=7.2, vein=1.0, cloud=1.0, warm=1.0, space="uv", polish=0.3, grain=0.4,
                ramp="gr_marble", vein_ramp="gr_vein", light_veins=False):
    """The stone itself: cool body ramp with cloudy veils, thin meandering
    grey-blue veins (zero contours of warped noise, ``vein`` = strength),
    honey patches on the warm twin ramp."""
    s = Surface(ctx.N)
    if space == "uv" and not ctx.tile:
        q = np.stack([ctx.uvm[:, 0], np.zeros(ctx.N), ctx.uvm[:, 1]], axis=1) + ctx.part[:, None] * 13.7
    else:
        q = ctx.p
    w = np.stack([ctx.fbm(0.6, 3, seed + 1, p=q), ctx.fbm(0.6, 3, seed + 2, p=q), ctx.fbm(0.6, 3, seed + 3, p=q)], 1)
    clouds = ctx.fbm(1.3, 4, seed + 4, p=q)
    f1 = np.abs(ctx.fbm(0.7, 4, seed + 5, p=q + w * 0.8))
    f2 = np.abs(ctx.fbm(1.9, 3, seed + 6, p=q + w * 0.4))
    k = ctx.texel * 64.0
    v1 = 1.0 - smoothstep(0.0, 0.035 * k, f1)
    v2 = (1.0 - smoothstep(0.0, 0.018 * k, f2)) * (ctx.fbm(1.2, 2, seed + 7, p=q) > 0.15)
    shade = center + clouds * 1.1 * cloud + _dither(ctx, 0.8 * grain, seed + 8)
    shade += (v1 * 1.0 + v2 * 0.6) * vein if light_veins else -(v1 * 1.4 + v2 * 0.7) * vein
    s.use_ramp(P[ramp], shade=shade)
    deep = (v1 > 0.9) & (vein > 0.6)
    vshade = (1.2 if light_veins else 3.2)
    s.use_ramp(P[vein_ramp], mask=deep, shade=np.full(ctx.N, vshade) + clouds + _dither(ctx, 0.8, seed + 9))
    if warm > 0:
        wm = _warm_patches(ctx, seed + 50, warm, q=q) & (s.ramp_id == 0)
        s.ramp_id[wm] = s.use_ramp(P["gr_marble_warm"], mask=np.zeros(ctx.N, bool))
    s.rough = polish + np.clip(ctx.fbm(3.0, 3, seed + 10, p=q), 0, 1) * 0.15 + ctx.rand(seed + 11) * 0.04
    return s


def pentelic(ctx, seed=401, center=7.2, veins=1.0, patina=1.0, space="uv", grain=0.45, polish=0.3, age=True,
             cavity=2.4, ao=4.5, edge=1.4, grime=True):
    """White Pentelic marble: cool body, faint blue-grey veils and veins,
    honey patina in patches, grime in the hollows, bright worn arrises."""
    s = marble_body(ctx, seed, center, vein=veins, warm=patina, space=space, polish=polish, grain=grain)
    if age:
        s.shade += ctx.edge(1.0) * edge + ctx.edge(2.0) * edge * 0.3
        s.shade -= ctx.cavity(3.0) * cavity
        s.shade -= (1.0 - ctx.ao) * ao
        if grime:
            dirt = (ctx.cavity(2.0) > 0.5) | (ctx.ao < 0.42)
            dirt &= (ctx.fbm(9.0, 2, seed + 62) > -0.15) & (ctx.rand(seed + 60) > 0.2)
            s.use_ramp(P["gr_grime"], mask=dirt, shade=np.full(ctx.N, 3.0) + _dither(ctx, 1.2, seed + 61))
    return s


def grey_marble(ctx, seed=431, center=4.6, polish=0.22, space="uv"):
    """Blue-grey Hymettian marble (plinths, floor bands, the cast store
    bases): darker, with light veins."""
    s = marble_body(ctx, seed, center=center, vein=0.7, cloud=1.0, warm=0.0, space=space, polish=polish, grain=0.4,
                    ramp="gr_grey", vein_ramp="gr_grey_vein", light_veins=True)
    s.shade += ctx.edge(1.0) * 1.6 - ctx.cavity(3.0) * 1.6 - (1.0 - ctx.ao) * 3.0
    return s


def paint_traces(ctx, s, ramp, mask, seed, center=3.2, density=0.3, freq=6.0):
    """Overlays faded paint on ``mask``: islands from noise with ragged
    one-texel edges (``density`` 0..1 = how much of the mask keeps its
    paint), shaded with the surface."""
    isl = ctx.fbm(freq, 3, seed) + ctx.fbm(freq * 3.0, 2, seed + 3) * 0.3 + (ctx.rand(seed + 1) - 0.5) * 0.12
    keep = mask & (isl > 0.45 - density * 0.8)
    if not keep.any():
        return keep
    shade = center + (s.shade - 7.0) * 0.4 + _dither(ctx, 0.6, seed + 2)
    s.use_ramp(P[ramp], mask=keep, shade=shade)
    s.rough = np.where(keep, 0.75, s.rough)
    return keep


# --------------------------------------------------------------------------
# relief painter
# --------------------------------------------------------------------------

def sample_maps(maps, u, v):
    """Nearest texel of the relief maps at (u right, v up) metres."""
    ppm = maps["ppm"]
    H, W = maps["height"].shape
    col = np.clip(np.floor(u * ppm).astype(np.int64), 0, W - 1)
    row = np.clip(np.floor((maps["h"] - v) * ppm).astype(np.int64), 0, H - 1)
    return {k: (a[row, col] if isinstance(a, np.ndarray) and a.ndim == 2 else a) for k, a in maps.items()}


def relief_surface(ctx, maps, u, v, seed=503, blue=0.6, paint=1.0, material="marble", depth_scale=1.0,
                   height="height", shading=1.0, front=None):
    """Paints relief texels: marble (or plaster) modelled by the relief's AO,
    curvature, rims and cavities, the background with traces of Egyptian
    blue, the figures with sparse red / ochre, fractures sugary bright."""
    m = sample_maps(maps, u, v)
    tag = m["tag"]
    if material == "plaster":
        s = plaster_cast(ctx, seed=seed, age=False)
    else:
        s = marble_body(ctx, seed, center=7.4, vein=0.45, cloud=0.8, warm=0.8, space="uv", polish=0.32, grain=0.5)
    fig = tag != RL.BG
    k = np.full(ctx.N, float(shading))
    if front is not None:
        # displaced geometry: walls of the figures are seen from the side;
        # their texels are stretched, so they get the stone and the baked AO
        k = k * np.clip((front - 0.35) / 0.4, 0.0, 1.0)
        s.shade -= (1.0 - ctx.ao) * 4.0
    s.shade += (np.clip(m["curv"], 0, 1) * 1.1 - np.clip(-m["curv"], 0, 1) * 1.4) * k
    s.shade += (m["edge"] * 1.3 - m["cavity"] * 1.8) * k
    s.shade -= (1.0 - m["ao"]) * 5.6 * k
    s.shade += m["key"] * 0.9 * k
    s.shade += np.where(fig, 0.35, -0.5)
    s.height = m[height] * depth_scale
    # fractures: brighter, sugary, rough
    brk = tag == RL.BREAK
    if brk.any():
        s.use_ramp(P["gr_break"], mask=brk, shade=4.0 + _dither(ctx, 2.2, seed + 7) - (1 - m["ao"]) * 5.0)
        s.rough = np.where(brk, 0.9, s.rough)
    if material == "marble" and paint > 0:
        bg = (tag == RL.BG) & (m["height"] > -0.002)
        near = m["ao"] < 0.985
        paint_traces(ctx, s, "gr_blue", bg & (near | (ctx.fbm(1.5, 2, seed + 8) > 0.2)), seed + 9,
                     center=3.4, density=blue * paint * 0.7, freq=2.6)
        paint_traces(ctx, s, "gr_red", np.isin(tag, [RL.CLOTH, RL.SHIELD]) & (m["cavity"] + (1 - m["ao"]) > 0.2),
                     seed + 11, center=3.6, density=0.06 * paint, freq=7.0)
        paint_traces(ctx, s, "gr_ochre", np.isin(tag, [RL.HAIR, RL.TACK, RL.METAL]), seed + 13, center=3.4,
                     density=0.18 * paint, freq=9.0)
    # grime settles in the deepest hollows
    grime = (m["ao"] < 0.52) & (ctx.rand(seed + 15) > 0.35) & ~brk & (k > 0.5)
    s.use_ramp(P["gr_grime"], mask=grime, shade=np.full(ctx.N, 2.6) + _dither(ctx, 1.0, seed + 16))
    s.rough = np.where(fig & ~brk, np.clip(s.rough - 0.08, 0.2, 1.0), s.rough)
    return s


def plaster_cast(ctx, seed=541, center=7.0, age=True):
    """Plaster of Paris (the cast store): chalky, even, a few air bubbles,
    mould seams are drawn by the caller; dust settles on top."""
    s = Surface(ctx.N)
    base = center + ctx.fbm(2.0, 3, seed) * 0.5 + _dither(ctx, 0.5, seed + 1)
    f1, _, cid = ctx.worley(40.0, seed + 2)
    bubble = (f1 < 0.09) & (cid > 0.9)
    base -= bubble * 1.6
    s.use_ramp(P["gr_plaster"], shade=base)
    if age:
        s.shade += ctx.edge(1.0) * 0.6 - ctx.cavity(3.0) * 2.0 - (1.0 - ctx.ao) * 4.0
        if not ctx.tile:
            dust = np.clip(ctx.n[:, 2], 0, 1) > 0.7
            s.shade[dust] += 0.4
    s.height = -bubble.astype(float) * 0.001 + ctx.fbm(14.0, 2, seed + 3) * 0.0003
    s.rough = 0.92 + ctx.rand(seed + 4) * 0.05
    return s


# --------------------------------------------------------------------------
# tiles (64 px/m, world-mapped in the game)
# --------------------------------------------------------------------------

def _tile_uv(ctx):
    return ctx.uvm[:, 0], ctx.uvm[:, 1]


def gr_ashlar(ctx, seed=601):
    """Isodomic marble walling: 0.5 m courses of long blocks (1-2 m), each
    with a smooth drafted margin and a finely pick-dressed panel, one-texel
    joints, blocks varying between cool white and honey. Tile 6 x 3 m."""
    u, v = _tile_uv(ctx)
    W, H = 6.0, 3.0
    courses = course_layout(W, [0.5] * 6, [1.0, 1.25, 1.5, 2.0], seed, step=0.25)
    course, bid, dl, dr, db, dt = blocks(u, v, W, H, courses)
    tx = ctx.texel
    tone = noise.rand_cells(bid, seed) - 0.5
    warmth = noise.rand_cells(bid, seed + 5)
    s = marble_body(ctx, seed + 7, center=7.9, vein=0.35, cloud=0.8, warm=0.0, space="uv", polish=0.4, grain=0.6)
    warm = ((warmth > 0.6) & (ctx.rand(seed + 9) > 0.25)) | ((ctx.fbm(1.2, 3, seed + 8) > 0.3) & (ctx.rand(seed + 13) > 0.5))
    s.ramp_id[warm & (s.ramp_id == 0)] = s.use_ramp(P["gr_marble_warm"], mask=np.zeros(ctx.N, bool))
    s.shade += tone * 0.9
    edge_d = np.minimum(np.minimum(dl, dr), np.minimum(db, dt))
    margin = edge_d < 3.5 * tx
    stipple = ~margin & (ctx.rand(seed + 10) > 0.72)
    s.shade -= stipple * 0.7
    s.shade += margin * 0.35
    joint = (db < tx) | (dl < tx)
    s.shade = np.where(joint, 1.6 + _dither(ctx, 0.6, seed + 11), s.shade)
    s.shade = np.where((dt < tx) & ~joint, s.shade + 0.8, s.shade)
    s.shade = np.where((db >= tx) & (db < 2 * tx), s.shade - 0.9, s.shade)
    s.height = -joint.astype(float) * 0.004 - stipple * 0.0004 + margin * 0.0004
    s.rough = np.clip(np.where(margin, 0.38, 0.62) + ctx.rand(seed + 12) * 0.06, 0.2, 0.95)
    s.rough = np.where(joint, 0.9, s.rough)
    return s


def gr_floor(ctx, seed=613):
    """Gallery floor: 2 x 1 m slabs of cream marble in stretcher bond, with
    blue-grey slabs scattered, polished and scuffed; one-texel joints.
    Tile 8 x 8 m (32 slabs: the scatter does not repeat in a room)."""
    u, v = _tile_uv(ctx)
    W, H = 8.0, 8.0
    courses = course_layout(W, [1.0] * 8, [2.0], seed, step=1.0)
    course, bid, dl, dr, db, dt = blocks(u, v, W, H, courses)
    tx = ctx.texel
    grey = noise.rand_cells(bid, seed + 1) > 0.84
    tone = noise.rand_cells(bid, seed + 2) - 0.5
    # each slab's stone is drawn in its own local frame (continuous across the
    # tile's wrap, which a slab may straddle)
    off = np.stack([noise.rand_cells(bid, seed + k) * 50.0 for k in (3, 4, 5)], axis=1)
    local = np.stack([dl, np.zeros(ctx.N), db], axis=1) + off
    plain = type(ctx)(local, ctx.n, ctx.t, ctx.b, ctx.texel, ctx.seed, None)
    plain.uvm = local[:, [0, 2]]
    cream = marble_body(plain, seed + 6, center=7.6, vein=0.4, cloud=0.9, warm=0.6, space="uv", polish=0.12,
                        grain=0.6)
    darks = _marble_core(plain, P["gr_grey"], P["gr_grey_vein"], 6.2, True, seed + 7, polish=0.1, space="uv",
                         vein_scale=1.6)
    s = Surface(ctx.N)
    s.merge(_select(cream, ~grey), ~grey)
    s.merge(_select(darks, grey), grey)
    s.shade += tone * 1.0
    joint = (db < tx) | (dl < tx)
    near = (np.minimum(np.minimum(dl, dr), np.minimum(db, dt)) < 2 * tx) & ~joint
    s.shade[near & ~grey] -= 0.6
    gid = s.use_ramp(P["grout"], mask=joint, shade=np.full(ctx.N, 2.0) + _dither(ctx, 1.0, seed + 8))
    scuff = smoothstep(0.2, 0.75, ctx.fbm(1.8, 4, seed + 9))
    s.rough = np.where(joint, 0.85, np.clip(s.rough + scuff * 0.25, 0.08, 0.7))
    s.height = np.where(joint, -0.003, 0.0) + near * -0.0006
    s.metal[:] = 0.0
    return s


def gr_marble_plain(ctx, seed=619):
    """Plain dressed marble (reveals, soffits, plinth bodies). Tile 2 x 2 m."""
    s = marble_body(ctx, seed, center=7.3, vein=0.4, cloud=0.9, warm=0.6, space="uv", polish=0.32, grain=0.6)
    s.height = ctx.fbm(8.0, 2, seed + 4) * 0.0004
    return s


def gr_plaster_tile(ctx, seed=631):
    """Warm lime plaster for the upper walls and ceilings of the wing:
    trowel arcs, faint hairline cracks. Tile 2 x 2 m."""
    s = Surface(ctx.N)
    base = 6.9 + ctx.fbm(1.6, 4, seed) * 0.6 + ctx.fbm(9.0, 2, seed + 1) * 0.3 + _dither(ctx, 0.45, seed + 2)
    crack = (np.abs(ctx.fbm(1.1, 4, seed + 3)) < 0.01) & (ctx.fbm(0.6, 2, seed + 4) > 0.3)
    base -= crack * 1.4
    s.use_ramp(P["gr_plaster"], shade=base - 0.4)
    s.height = ctx.fbm(6.0, 3, seed + 5) * 0.0008 - crack * 0.0008
    s.rough = 0.88 + ctx.rand(seed + 6) * 0.06
    return s


def gr_limewash(ctx, seed=641):
    """Whitewashed brick of the cast store: English bond under several
    coats of lime, the wash thin on the arrises and pooled in the joints,
    flaking in places to the red brick. Tile 4 x 2 m."""
    u, v = _tile_uv(ctx)
    W, H = 4.0, 2.0
    ch = 0.075
    rows = int(round(H / ch))
    row = np.floor(np.mod(v, H) / ch).astype(np.int64)
    header = row % 2 == 1
    bl = np.where(header, 0.1125, 0.225)
    shift = np.where(header, 0.05625, 0.0)
    x = np.mod(u + shift, W)
    k = np.floor(x / bl).astype(np.int64)
    fx = x - k * bl
    fz = np.mod(v, H) - row * ch
    bid = row * 97 + k
    tx = ctx.texel
    joint = (fx < tx) | (fz < tx)
    s = Surface(ctx.N)
    tone = noise.rand_cells(bid, seed) - 0.5
    base = 7.0 + tone * 0.6 + ctx.fbm(2.5, 3, seed + 1) * 0.6 + _dither(ctx, 0.6, seed + 2)
    base = np.where(joint, base - 1.6, base)
    s.use_ramp(P["gr_plaster"], shade=base)
    flake = (ctx.fbm(1.4, 4, seed + 3) + ctx.fbm(9.0, 2, seed + 6) * 0.25 > 0.4) & ~joint
    s.use_ramp(P["brick"], mask=flake, shade=np.full(ctx.N, 4.5) + tone * 2 + _dither(ctx, 1.0, seed + 4))
    s.height = -joint.astype(float) * 0.003 - flake * 0.0015
    s.rough = 0.93 + ctx.rand(seed + 5) * 0.05
    return s


def gr_wall_paint(ctx, seed=653):
    """Museum wall paint of the Vase Room: Pompeian red distemper over
    plaster (black and red pots read best on it), slightly mottled.
    Tile 2 x 2 m."""
    s = Surface(ctx.N)
    base = 5.0 + ctx.fbm(1.2, 4, seed) * 0.7 + ctx.fbm(7.0, 2, seed + 1) * 0.3 + _dither(ctx, 0.6, seed + 2)
    s.use_ramp(P["gr_wall_ochre"], shade=base)
    s.height = ctx.fbm(6.0, 3, seed + 3) * 0.0006
    s.rough = 0.9 + ctx.rand(seed + 4) * 0.05
    return s


MATERIALS = {
    "gr_ashlar": gr_ashlar,
    "marble_greek": gr_floor,
    "gr_marble": gr_marble_plain,
    "gr_plaster": gr_plaster_tile,
    "gr_limewash": gr_limewash,
    "gr_wall_paint": gr_wall_paint,
}


# --------------------------------------------------------------------------
# sculpture in the round
# --------------------------------------------------------------------------

def statuary(ctx, seed=1201, center=7.6, patina=1.1, vein=0.35, ao=4.5, curv=1.0):
    """Carved figures: calm statuary marble (solid 3D veins), modelled by
    curvature and AO (polished highs, dirt in the deep folds), honey patina
    where dust settled on top."""
    s = marble_body(ctx, seed, center=center, vein=vein, cloud=0.7, warm=patina, space="3d", polish=0.26, grain=0.3)
    s.shade += np.clip(ctx.curv, 0, 1) * 1.3 * curv - np.clip(-ctx.curv, 0, 1) * 2.0 * curv
    s.shade -= ctx.cavity(3.0) * 1.6 + (1.0 - ctx.ao) * ao
    s.shade += ctx.edge(1.0) * 0.8
    dirt = (ctx.ao < 0.45) & (ctx.fbm(7.0, 2, seed + 3) > -0.2) & (ctx.rand(seed + 4) > 0.3)
    s.use_ramp(P["gr_grime"], mask=dirt, shade=np.full(ctx.N, 3.4) + _dither(ctx, 1.0, seed + 5))
    s.height = ctx.fbm(30.0, 2, seed + 6) * 0.0006
    return s


def fracture(ctx, seed=1211):
    """Fresh fracture of marble: sugary, bright, rough, a little uneven."""
    s = Surface(ctx.N)
    s.use_ramp(P["gr_break"], shade=3.6 + (ctx.rand(seed) - 0.5) * 2.0 + ctx.fbm(12.0, 2, seed + 1) * 1.0
               - (1.0 - ctx.ao) * 4.0)
    s.rough = np.full(ctx.N, 0.92)
    s.height = ctx.fbm(20.0, 3, seed + 2) * 0.004
    return s


def rock(ctx, seed=1221):
    """The rough-picked rock seats of the pediment figures."""
    s = marble_body(ctx, seed, center=6.6, vein=0.2, cloud=1.0, warm=1.4, space="3d", polish=0.5, grain=0.6)
    pick = ctx.rand(seed + 1) > 0.6
    s.shade -= pick * 0.9 + (1.0 - ctx.ao) * 4.0
    s.height = ctx.fbm(24.0, 3, seed + 2) * 0.004 - pick * 0.001
    s.rough = np.clip(s.rough + 0.3, 0, 0.95)
    return s
