"""Materials of the Americas and Oceania wing (Floor I): deep red lime
plaster, the grey volcanic stone of carved friezes and terraces (relief and
traces of paint sampled from the pixel canvases of americas_paint.py, one
art pixel = one texel), vesicular basalt, turquoise and shell mosaic,
obsidian, burnished clay, carved and painted wood, feathers, plaited mats,
bark cloth, rope, embers and flame; and the wing's tileable fields
(64 px/m).

Same rules as materials.py: every colour is a step on a hand-picked ramp in
P (dark -> light, keys prefixed "am_"); shading moves along the ramp.
"""
import numpy as np

from . import americas_paint as AP
from . import noise
from .materials import P, _age, _dither, _grain_frame, _wood_core, hexramp, smoothstep
from .painter import Surface

P.update({
    "am_red": hexramp("#1a0504", "#2a0806", "#3b0c08", "#4e110b", "#62170e", "#771e12", "#8c2717", "#a0321d",
                      "#b34027"),
    "am_basalt": hexramp("#0d0d0d", "#151514", "#1d1d1b", "#262623", "#30302c", "#3b3a35", "#47463f", "#54524a",
                         "#615f56", "#706d63"),
    "am_andesite": hexramp("#26221f", "#34302b", "#433d37", "#534c45", "#645c54", "#766d64", "#887e74", "#9a9085",
                           "#aca195", "#bcb1a4"),
    "am_stucco": hexramp("#4a4237", "#5f5547", "#766a59", "#8d806c", "#a39680", "#b8ab94", "#cbbfa8", "#dbd0ba"),
    "am_turq": hexramp("#062223", "#0a3434", "#0f4746", "#155b58", "#1d706b", "#26857e", "#329a91", "#42aea2",
                       "#58c1b2", "#76d2c3"),
    "am_turq_green": hexramp("#0b2418", "#123522", "#1a472d", "#235a39", "#2d6d45", "#3a8052", "#4a9360"),
    "am_shell": hexramp("#4a4438", "#625b4c", "#7b7462", "#958d79", "#afa791", "#c7bfa9", "#dcd5c0", "#ece6d4",
                        "#f6f2e6"),
    "am_spondylus": hexramp("#2c0905", "#440f08", "#5e160b", "#7a1f0f", "#952a14", "#ad381b", "#c44a25",
                            "#d85f33"),
    "am_obsidian": hexramp("#040506", "#08090b", "#0d0f11", "#131619", "#1b1f23", "#252a2f", "#323940", "#465058",
                           "#62707a"),
    "am_jade": hexramp("#06160f", "#0b2318", "#113222", "#18432e", "#20553b", "#2a6849", "#367b58", "#448f68"),
    "am_ochre": hexramp("#2e1d06", "#47300b", "#634412", "#7f5a1a", "#9b7124", "#b58930", "#cca13f", "#e0b852",
                        "#eecd6c"),
    "am_blue": hexramp("#0b2028", "#123140", "#1a4459", "#245872", "#306d89", "#3f829e", "#5196b0"),
    "am_clay": hexramp("#200b05", "#341208", "#4a1b0c", "#612510", "#792f15", "#913b1c", "#a74925", "#ba5a31",
                       "#cb6d40"),
    "am_clay_buff": hexramp("#3a2a1a", "#523d27", "#6b5135", "#846645", "#9d7b56", "#b49068", "#c8a47b"),
    "am_fiber": hexramp("#2a1f0e", "#3d2e15", "#52401d", "#685226", "#7f6530", "#97793c", "#ad8d4a", "#c2a15b",
                        "#d4b46d"),
    "am_fiber_dye": hexramp("#120a06", "#1d120b", "#2a1a10", "#382316", "#472d1c"),
    "am_bark": hexramp("#4a3a26", "#615034", "#796644", "#917c55", "#a89167", "#bda67a", "#cfb98e", "#ddc9a1"),
    "am_tapa_ink": hexramp("#140a05", "#22120a", "#331b0f", "#452616", "#58321e", "#6c3f27"),
    "am_wood_dark": hexramp("#0e0805", "#170d08", "#21130b", "#2c190f", "#382113", "#452918", "#53321e",
                            "#623c24", "#72462b"),
    "am_wood": hexramp("#1c0f07", "#2a170b", "#3a2010", "#4b2a15", "#5d351b", "#704121", "#834e29", "#975c32",
                       "#aa6b3c"),
    "am_feather_red": hexramp("#2a0405", "#450709", "#620b0d", "#801012", "#9e1818", "#bb2620", "#d33a2a"),
    "am_feather_yellow": hexramp("#3a2a05", "#5e4508", "#86650c", "#ad8612", "#d0a81e", "#ebc735", "#f8df5c"),
    "am_feather_green": hexramp("#04150c", "#072414", "#0b351d", "#114827", "#185c31", "#21713b", "#2c8746"),
    "am_feather_blue": hexramp("#04142a", "#08213f", "#0d3056", "#13406d", "#1b5285", "#26659c", "#347ab2"),
    "am_pelt": hexramp("#2a1a0c", "#3f2812", "#56381a", "#6d4923", "#835a2d", "#986c39", "#ab7e47", "#bb9056",
                       "#c9a265"),
    "am_rope": hexramp("#211709", "#33240f", "#473315", "#5c441c", "#725624", "#88692e", "#9d7c39", "#b18f46"),
    "am_resin": hexramp("#060403", "#0d0806", "#150c08", "#1e120b", "#28180e"),
    "am_flame": hexramp("#4a1404", "#7a2406", "#b03c0a", "#e06014", "#f99030", "#ffc35e", "#ffe7a6", "#fff8e0"),
    "am_ember": hexramp("#1c0402", "#3a0904", "#661305", "#962208", "#c43a0e", "#e8601c", "#ff8e3a"),
})

# paint codes -> (ramp, centre shade, roughness, metalness)
INKS = {
    AP.INK["line"]: ("am_obsidian", 1.5, 0.6, 0.0),
    AP.INK["turq"]: ("am_turq", 5.4, 0.55, 0.0),
    AP.INK["red"]: ("am_red", 5.0, 0.8, 0.0),
    AP.INK["white"]: ("am_stucco", 6.0, 0.85, 0.0),
    AP.INK["black"]: ("am_obsidian", 2.0, 0.5, 0.0),
    AP.INK["gold"]: ("gold", 6.2, 0.3, 1.0),
    AP.INK["ochre"]: ("am_ochre", 5.6, 0.75, 0.0),
    AP.INK["green"]: ("am_jade", 4.6, 0.7, 0.0),
    AP.INK["blue"]: ("am_blue", 4.4, 0.75, 0.0),
    AP.INK["brown"]: ("am_tapa_ink", 4.0, 0.85, 0.0),
    AP.INK["dark"]: ("am_tapa_ink", 1.4, 0.85, 0.0),
}


# --------------------------------------------------------------------------
# canvas sampling
# --------------------------------------------------------------------------

def canvas_index(shape, u, v, texel, u0=0.0, v0=0.0, wrap_x=False, wrap_y=False, scale=1):
    """(rows, cols, inside) of a canvas (row 0 = top) under texels at metre
    coordinates (u, v); the canvas's bottom-left corner sits at (u0, v0), one
    art pixel = ``scale`` texels."""
    H, W = shape
    ix = np.floor((u - u0) / texel + 1e-6).astype(np.int64) // scale
    iy = np.floor((v - v0) / texel + 1e-6).astype(np.int64) // scale
    if wrap_x:
        ix = np.mod(ix, W)
    if wrap_y:
        iy = np.mod(iy, H)
    inside = (ix >= 0) & (ix < W) & (iy >= 0) & (iy < H)
    rows = np.where(inside, H - 1 - iy, 0)
    cols = np.where(inside, ix, 0)
    return rows, cols, inside


def take(canvas, idx, fill=0):
    rows, cols, inside = idx
    return np.where(inside, canvas[rows, cols], fill)


def paint_over(ctx, s, codes, seed=0, flake=0.35, wear=1.0, fade=1.0, inks=None):
    """Lays paint (canvas codes) over ``s``: each code on its ramp, flaking
    to the surface below with a dark lip, faded where worn."""
    inks = INKS if inks is None else inks
    painted = codes > 0
    if not painted.any():
        return s
    fl = ctx.fbm(9.0, 3, seed + 1) + ctx.fbm(34.0, 2, seed + 2) * 0.35 + ctx.edge_soft(3.0) * 0.6 * wear
    thr = 0.62 - 0.45 * flake
    lost = painted & (fl > thr)
    lip = painted & ~lost & (fl > thr - 0.07)
    keep = painted & ~lost
    fd = (ctx.fbm(2.2, 3, seed + 3) * 0.6 + _dither(ctx, 0.6, seed + 4)) * fade
    for code in np.unique(codes[keep]):
        code = int(code)
        if code not in inks:
            continue
        ramp, center, rough, metal = inks[code]
        m = keep & (codes == code)
        sh = center + fd - (1.0 - ctx.ao) * 2.5 - ctx.cavity(3.0) * 1.5
        s.use_ramp(P[ramp], mask=m, shade=sh)
        s.rough[m] = rough + ctx.rand(seed + 5)[m] * 0.05
        s.metal[m] = metal
    s.shade[lip] -= 1.2
    return s


def relief(ctx, s, levels, shade_map, idx, depth=0.004, light=0.9):
    """Carves a relief canvas into ``s``: height steps of ``depth`` per
    level, the pixel lighting of ``relief_shade`` on the ramp."""
    lv = take(levels, idx)
    sh = take(shade_map, idx, 0.0)
    s.height = s.height + lv * depth
    s.shade = s.shade + sh * light + lv * 0.35
    return s


# --------------------------------------------------------------------------
# stone and plaster
# --------------------------------------------------------------------------

def volcanic(ctx, seed=701, ramp="am_andesite", center=5.0, vesicles=0.6, tool=0.6):
    """Fine volcanic stone (andesite, basalt): soft clouds, dark crystals,
    gas vesicles (small round pits), faint pick marks of the carver."""
    s = Surface(ctx.N)
    cloud = ctx.fbm(1.4, 4, seed) * 0.9
    speck = (ctx.rand(seed + 1) > 0.93) * -1.0 + (ctx.rand(seed + 2) > 0.97) * 1.0
    f1, _, cid = ctx.worley(40.0, seed + 3)
    pit = (f1 < 0.22) & (cid < 0.35 * vesicles)
    pick = ctx.fbm(np.array([22.0, 22.0, 22.0]), 2, seed + 4) * tool
    shade = center + cloud + speck * 0.7 + pick * 0.6 + _dither(ctx, 0.5, seed + 5) - pit * 1.8
    s.use_ramp(P[ramp], shade=shade)
    _age(ctx, s, cavity=2.2, ao=3.5, edge=1.2)
    s.height = ctx.fbm(14.0, 3, seed + 6) * 0.0008 - pit * 0.0018 + pick * 0.0004
    s.rough = 0.82 + ctx.rand(seed + 7) * 0.08
    return s


def basalt(ctx, seed=711, center=4.2, polish=0.0, vesicles=1.0):
    """Dark grey vesicular basalt (moai, the carved disc): bigger pits,
    greenish olivine glints, a dull sheen where it has been touched."""
    s = volcanic(ctx, seed, "am_basalt", center, vesicles=vesicles, tool=0.4)
    f1, _, cid = ctx.worley(14.0, seed + 8)
    big = (f1 < 0.18) & (cid < 0.18 * vesicles)
    s.shade[big] -= 2.0
    s.height = s.height - big * 0.004
    glint = ctx.rand(seed + 9) > 0.985
    s.use_ramp(P["am_jade"], mask=glint, shade=np.full(ctx.N, 3.0))
    s.rough = np.clip(s.rough - polish, 0.25, 1.0)
    return s


def stucco(ctx, seed=721, center=5.0):
    """Lime stucco over stone: chalky cream, trowel waves, hairline crazing."""
    s = Surface(ctx.N)
    trowel = ctx.fbm(np.array([3.0, 3.0, 9.0]), 2, seed) * 0.6
    f1, f2, _ = ctx.worley(9.0, seed + 1)
    craze = (f2 - f1) < 0.03
    s.use_ramp(P["am_stucco"], shade=center + trowel + ctx.fbm(2.0, 3, seed + 2) * 0.6 + _dither(ctx, 0.5, seed + 3)
               - craze * 1.0)
    _age(ctx, s, cavity=2.0, ao=3.5, edge=1.0)
    s.height = trowel * 0.0006 - craze * 0.0004
    s.rough = np.full(ctx.N, 0.9)
    return s


def red_plaster(ctx, seed=731, center=4.2, polish=0.5):
    """Burnished red lime plaster (the wing's walls): deep oxblood, soft
    cloudy mottling where the pigment pooled, curved trowel sweeps that catch
    a lamp (glossier), a darker smoke tide toward the floor, the odd
    hairline crack."""
    s = Surface(ctx.N)
    mott = ctx.fbm(0.9, 4, seed) * 0.9 + ctx.fbm(4.0, 2, seed + 1) * 0.35
    sweep = ctx.fbm(np.array([2.5, 2.5, 6.0]), 3, seed + 2)
    sheen = smoothstep(0.1, 0.5, sweep)
    crack = (np.abs(ctx.fbm(1.2, 4, seed + 3)) < 0.008) & (ctx.fbm(0.6, 2, seed + 4) > 0.25)
    shade = center + mott + sheen * 0.5 + _dither(ctx, 0.55, seed + 5) - crack * 1.6
    s.use_ramp(P["am_red"], shade=shade)
    _age(ctx, s, cavity=2.0, ao=3.0, edge=0.8)
    s.rough = 0.62 - sheen * polish * 0.35 + ctx.rand(seed + 6) * 0.04
    s.height = sweep * 0.0003 - crack * 0.0008
    return s


# --------------------------------------------------------------------------
# mosaic and stones
# --------------------------------------------------------------------------

def mosaic(ctx, seed=741, ramp="am_turq", cell=0.012, center=5.6, spread=2.4, mix=0.18, mix_ramp="am_turq_green",
           gap_texels=0.9, dome=0.0006, plane=None):
    """Tesserae of cut stone or shell set in dark resin: one tone per
    tessera (cells of 3D Voronoi on the surface), a few of another stone
    (``mix`` share of ``mix_ramp``), a lit upper edge and darker lower edge
    on each little dome, black resin in the joints; glossy."""
    s = Surface(ctx.N)
    cell = max(cell, 4.5 * ctx.texel)          # a tessera never under ~4 texels
    # plane "xz" / "xy" / "yz": cells cut in a projection (clean polygons on
    # a face seen from the front) instead of 3D cells sliced by the surface
    q = None
    if plane is not None:
        keep = {"xz": (0, 2), "xy": (0, 1), "yz": (1, 2)}[plane]
        q = np.zeros_like(ctx.p)
        q[:, 0] = ctx.p[:, keep[0]]
        q[:, 2] = ctx.p[:, keep[1]]
    f1, f2, cid = ctx.worley(1.0 / cell, seed, p=q)
    joint = (f2 - f1) * cell < ctx.texel * gap_texels
    tone = (noise.rand_cells(np.floor(cid * 99991).astype(np.int64), seed + 1) - 0.5) * spread
    other = (cid > 1.0 - mix)
    shade = center + tone + _dither(ctx, 0.4, seed + 2)
    shade += np.clip(ctx.curv, 0, 1) * 1.0 + ctx.edge(1.0) * 0.8
    shade -= (1.0 - ctx.ao) * 3.5 + ctx.cavity(3.0) * 1.5 + np.clip(-ctx.curv, 0, 1) * 1.2
    # a faint lit rim on the upper side of each tessera
    lit = (f1 > 0.35) & ((f2 - f1) * cell < ctx.texel * (gap_texels + 1.2))
    shade += lit * 0.4
    s.use_ramp(P[ramp], shade=shade)
    if mix > 0 and mix_ramp:
        s.use_ramp(P[mix_ramp], mask=other & ~joint, shade=shade - 1.0)
    s.use_ramp(P["am_resin"], mask=joint, shade=np.full(ctx.N, 2.0) + _dither(ctx, 0.8, seed + 3))
    s.rough = np.where(joint, 0.85, 0.22 + ctx.rand(seed + 4) * 0.06)
    s.height = np.where(joint, -0.0012, dome * (1.0 - np.clip(f1, 0, 1)))
    return s


def shell(ctx, seed=751, center=6.4, ramp="am_shell"):
    """Polished shell inlay (eyes, teeth): pearly, faint growth lines."""
    s = Surface(ctx.N)
    lines = np.sin(ctx.p[:, 2] * 900.0 + ctx.fbm(6.0, 2, seed) * 6.0) * 0.4
    shade = center + lines + ctx.fbm(10.0, 2, seed + 1) * 0.5 + _dither(ctx, 0.4, seed + 2)
    shade += ctx.edge(1.0) * 1.0 - (1.0 - ctx.ao) * 3.0 - ctx.cavity(2.0) * 1.5
    s.use_ramp(P[ramp], shade=shade)
    s.rough = 0.25 + ctx.rand(seed + 3) * 0.05
    return s


def obsidian(ctx, seed=761, center=2.6):
    """Volcanic glass: near-black, mirror-glossy, a grey-green sheen on the
    convex faces and conchoidal ripples near the edges."""
    s = Surface(ctx.N)
    near = ctx.convex < 0.03
    ripple = np.where(near, np.sin(np.where(near, ctx.convex, 0.0) / ctx.texel * 1.6 + ctx.fbm(20.0, 2, seed) * 3.0) * 0.5, 0.0)
    shade = center + ripple + np.clip(ctx.curv, 0, 1) * 2.0 + ctx.edge(1.0) * 2.4 + _dither(ctx, 0.4, seed + 1)
    shade -= (1.0 - ctx.ao) * 2.0
    s.use_ramp(P["am_obsidian"], shade=shade)
    s.rough = 0.06 + ctx.rand(seed + 2) * 0.03
    s.metal = np.full(ctx.N, 0.15)
    return s


def jade(ctx, seed=765, center=4.6):
    s = Surface(ctx.N)
    vein = ctx.fbm(np.array([3.0, 3.0, 9.0]), 4, seed) * 1.2
    shade = center + vein + _dither(ctx, 0.4, seed + 1) + ctx.edge(1.0) * 1.2 + np.clip(ctx.curv, 0, 1) * 1.2
    shade -= (1.0 - ctx.ao) * 3.0 + ctx.cavity(2.0) * 1.5
    s.use_ramp(P["am_jade"], shade=shade)
    s.rough = 0.2 + ctx.rand(seed + 2) * 0.05
    return s


# --------------------------------------------------------------------------
# clay, wood, fibre
# --------------------------------------------------------------------------

def clay(ctx, seed=771, ramp="am_clay", center=5.4, burnish=1.0, clouds=1.0):
    """Fired clay: burnished red-brown (or buff) with soft fire clouds
    (dark blotches where the fuel touched), polish highlights on the
    swellings, chalky in the hollows, small chips showing paler body."""
    s = Surface(ctx.N)
    cl = smoothstep(0.2, 0.6, ctx.fbm(2.5, 4, seed)) * clouds
    shade = center + ctx.fbm(6.0, 3, seed + 1) * 0.5 + _dither(ctx, 0.45, seed + 2) - cl * 2.2
    shade += np.clip(ctx.curv, 0, 1) * 1.6 * burnish + ctx.edge_soft(2.0) * 0.8
    shade -= np.clip(-ctx.curv, 0, 1) * 1.8 + ctx.cavity(3.0) * 2.0 + (1.0 - ctx.ao) * 3.8
    s.use_ramp(P[ramp], shade=shade)
    chip = (ctx.fbm(16.0, 2, seed + 3) > 0.55) & (ctx.edge_soft(3.0) > 0.2)
    s.use_ramp(P["am_clay_buff"], mask=chip, shade=np.full(ctx.N, 4.2) + _dither(ctx, 0.8, seed + 4))
    s.rough = np.where(chip, 0.85, 0.5 - np.clip(ctx.curv, 0, 1) * 0.2 * burnish + ctx.rand(seed + 5) * 0.05)
    s.height = ctx.fbm(30.0, 2, seed + 6) * 0.0003 - chip * 0.0008
    return s


def carved_wood(ctx, seed=781, ramp="am_wood", center=4.8, adze=1.0, oiled=0.5):
    """Hand-carved hardwood: grain along the island, the facets of an adze
    (cells of slightly different tone with a crisp lit edge), darkened by
    handling and smoke in the hollows, an oiled sheen on the high points."""
    s = _wood_core(ctx, P[ramp], center, seed, ring_freq=8.0, contrast=0.9)
    f1, f2, cid = ctx.worley(np.array([16.0, 16.0, 16.0]), seed + 1)
    facet = (noise.rand_cells(np.floor(cid * 7919).astype(np.int64), seed + 2) - 0.5) * 1.2 * adze
    ridge = ((f2 - f1) < 0.06) * adze
    s.shade += facet + ridge * 0.6
    _age(ctx, s, cavity=2.4, ao=4.0, edge=1.2)
    s.shade += np.clip(ctx.curv, 0, 1) * 1.0 - np.clip(-ctx.curv, 0, 1) * 1.2
    s.rough = 0.62 - oiled * 0.25 * np.clip(ctx.curv + ctx.edge_soft(2.0), 0, 1) + ctx.rand(seed + 3) * 0.05
    s.height = s.height + facet * 0.0005 + ridge * 0.0004
    return s


def feathers(ctx, ramp="am_feather_green", flow=(0.0, 0.0, -1.0), seed=791, center=4.0, barbs=1.0):
    """Feathers lying along ``flow``: vanes of fine barbs (1-texel strokes),
    a darker quill line in each, glossy sheen bands."""
    s = Surface(ctx.N)
    from .materials import strokes, tangent_flow
    st = strokes(ctx, flow, la=0.02, lc=0.006, seed=seed)
    f = tangent_flow(ctx, flow)
    side = np.cross(ctx.n, f)
    c = np.sum(ctx.p * side, 1)
    a = np.sum(ctx.p * f, 1)
    quill = np.abs(np.mod(c / 0.03, 1.0) - 0.5) < 0.06
    tipcut = np.mod(a / 0.05 + np.floor(c / 0.03) * 0.37, 1.0)
    shade = center + st * 1.2 * barbs + ctx.fbm(12.0, 2, seed + 1) * 0.6 + tipcut * 0.8 - quill * 1.4
    shade += np.clip(ctx.curv, 0, 1) * 1.0 + ctx.edge_soft(2.0) * 0.6 - (1.0 - ctx.ao) * 3.5
    s.use_ramp(P[ramp], shade=shade)
    s.rough = 0.55 + ctx.rand(seed + 2) * 0.1
    s.height = st * 0.0004 - quill * 0.0004
    return s


def rope(ctx, seed=801, center=4.8):
    """Twisted rope / coir sennit: diagonal plies along the island."""
    s = Surface(ctx.N)
    along, across = _grain_frame(ctx)
    a = np.sum(ctx.p * along, 1)
    c = np.sum(ctx.p * across, 1)
    ply = np.mod((a + c * 0.9) / 0.018, 1.0)
    shade = center + (ply < 0.5) * 0.8 - (ply < 0.12) * 1.6 + ctx.fbm(20.0, 2, seed) * 0.6 + _dither(ctx, 0.5, seed + 1)
    shade -= (1.0 - ctx.ao) * 3.0
    s.use_ramp(P["am_rope"], shade=shade)
    s.rough = np.full(ctx.N, 0.92)
    s.height = (ply < 0.12) * -0.0008
    return s


def iron_old(ctx, seed=811):
    """Wrought iron (rings, staples): black, hammer dents, rust in hollows."""
    s = Surface(ctx.N)
    dent = ctx.worley(30.0, seed)[0]
    shade = 3.4 + ctx.fbm(8.0, 3, seed + 1) * 0.6 + (dent < 0.3) * -0.6 + ctx.edge(1.0) * 2.0 + _dither(ctx, 0.5, seed + 2)
    shade -= (1.0 - ctx.ao) * 2.5
    s.use_ramp(P["iron"], shade=shade)
    rust = (ctx.fbm(5.0, 3, seed + 3) > 0.35) & (ctx.cavity(4.0) + (1.0 - ctx.ao) > 0.3)
    s.use_ramp(P["rust"], mask=rust, shade=np.full(ctx.N, 1.2) + _dither(ctx, 1.0, seed + 4))
    s.metal = np.where(rust, 0.0, 0.7)
    s.rough = np.where(rust, 0.85, 0.5)
    return s


def glow(ctx, ramp="am_flame", center=4.5, strength=1.0, seed=821, flicker=0.6):
    """Self-lit: embers, flame, glowing eyes."""
    s = Surface(ctx.N)
    shade = center + ctx.fbm(20.0, 2, seed) * flicker + _dither(ctx, 0.5, seed + 1)
    s.use_ramp(P[ramp], shade=shade)
    s.rough = np.full(ctx.N, 0.4)
    s.emit = s.colors() * strength
    return s


def flame(ctx, seed=825, strength=1.0):
    """A flame tongue: white-yellow core at the bottom, orange to red tips
    (shade by height within the tongue), emitted."""
    s = Surface(ctx.N)
    z = ctx.p[:, 2]
    lo, hi = np.percentile(z, 2), np.percentile(z, 98)
    t = np.clip((z - lo) / max(1e-6, hi - lo), 0, 1)
    shade = 5.6 - t * 4.6 + ctx.fbm(np.array([12.0, 12.0, 4.0]), 2, seed) * 0.9 + _dither(ctx, 0.6, seed + 1)
    s.use_ramp(P["am_flame"], shade=shade)
    s.rough = np.full(ctx.N, 0.5)
    s.emit = s.colors() * strength
    return s


def embers(ctx, seed=829, strength=1.0):
    """A bed of glowing charcoal: dark crust cells, bright cracks between."""
    s = Surface(ctx.N)
    f1, f2, cid = ctx.worley(26.0, seed)
    crack = (f2 - f1) < 0.12
    shade = np.where(crack, 5.6, 1.4 + cid * 1.6) + _dither(ctx, 0.7, seed + 1)
    s.use_ramp(P["am_ember"], shade=shade)
    s.rough = np.full(ctx.N, 0.9)
    s.emit = s.colors() * strength * np.where(crack, 1.0, 0.35)[:, None]
    s.height = np.where(crack, -0.002, 0.0)
    return s


# --------------------------------------------------------------------------
# fields (tile textures, 64 px/m)
# --------------------------------------------------------------------------

def am_red_wall(ctx, seed=901):
    """Tile 4 x 3 m: the wing's burnished deep red plaster."""
    return red_plaster(ctx, seed)


def am_frieze(ctx, seed=905):
    """Tile 8 x 1 m: a carved stone band - beads on top, stepped frets,
    cartouches with abstract signs, a plumed serpent and quincunxes in the
    main register, hanging plumes below - in grey andesite with traces of
    red, turquoise, white and ochre paint."""
    lv, pt = AP.frieze_canvas()
    sh = AP.relief_wrap_shade(lv)
    idx = canvas_index(lv.shape, ctx.uvm[:, 0], ctx.uvm[:, 1], ctx.texel, wrap_x=True, wrap_y=True)
    s = volcanic(ctx, seed, center=5.0, vesicles=0.5)
    s = relief(ctx, s, lv, sh, idx, depth=0.004, light=1.0)
    codes = take(pt, idx)
    # field paint survives in the hollows, the raised tops are rubbed bare
    lvl = take(lv, idx)
    codes = np.where((lvl >= 2) & (ctx.fbm(5.0, 2, seed + 1) > 0.15), 0, codes)
    s = paint_over(ctx, s, codes, seed + 2, flake=0.45, wear=0.0)
    s.shade += take(sh, idx, 0.0) * 0.6
    return s


def am_stone_blocks(ctx, seed=911):
    """Tile 4 x 3 m: dressed andesite blocks of the temple terraces (0.5 m
    courses, 0.5-1.25 m long), lime mortar joints, patches of the old lime
    stucco clinging to them, red paint in some of the stucco."""
    from . import arch_materials as A
    W, H = 4.0, 3.0
    courses = A.course_layout(W, [0.5] * 6, [0.5, 0.75, 1.0, 1.25], seed, step=0.25)
    u, v = ctx.uvm[:, 0], ctx.uvm[:, 1]
    course, bid, dl, dr, db, dt = A.blocks(u, v, W, H, courses)
    tone = noise.rand_cells(bid, seed + 1) - 0.5
    s = volcanic(ctx, seed + 2, center=5.4, vesicles=0.7)
    s.shade += tone * 1.6
    tx = ctx.texel
    joint = (dl < tx) | (db < tx)
    near = ~joint & ((dl < 2 * tx) | (db < 2 * tx))
    arris = ~joint & ((dt < tx) | (dr < tx))
    s.shade[near] -= 0.9
    s.shade[arris] += 1.0
    s.use_ramp(P["am_stucco"], mask=joint, shade=np.full(ctx.N, 3.0) + _dither(ctx, 0.8, seed + 3))
    # ragged areas where the old lime stucco still clings
    pn = ctx.fbm(0.8, 4, seed + 4) + ctx.fbm(6.0, 2, seed + 9) * 0.2
    patch = pn > 0.3
    st = stucco(ctx, seed + 5, center=4.4)
    s.use_ramp(P["am_stucco"], mask=patch, shade=st.shade)
    edge = patch & (pn < 0.34)
    s.shade[edge] -= 1.2
    s.height = s.height - joint * 0.004 - near * 0.001 + patch * 0.0015
    s.rough = np.where(joint, 0.95, np.where(patch, 0.9, s.rough))
    return s


def am_basalt_floor(ctx, seed=921):
    """Tile 4 x 4 m: polished dark basalt flags (1 x 1 and 2 x 1 m in a
    stepped bond), a texel of pale grout, a duller worn path."""
    u, v = ctx.uvm[:, 0], ctx.uvm[:, 1]
    row = np.floor(v + 1e-9).astype(np.int64)
    shift = np.mod(row, 2) * 1.0
    long_ = np.mod(row, 4) < 2
    w = np.where(long_, 2.0, 1.0)
    col = np.floor((u + shift) / w + 1e-9).astype(np.int64)
    fx = (u + shift) - col * w
    fz = v - row
    sid = np.mod(row, 4) * 16 + np.mod(col, 4)
    tone = noise.rand_cells(sid, seed) - 0.5
    s = basalt(ctx, seed + 1, center=3.4, polish=0.55, vesicles=0.5)
    s.shade += tone * 1.4
    tx = ctx.texel
    grout = (fx < tx) | (fz < tx)
    near = ~grout & ((fx < 2 * tx) | (fz < 2 * tx))
    s.shade[near] += 0.7
    s.use_ramp(P["am_stucco"], mask=grout, shade=np.full(ctx.N, 1.4) + _dither(ctx, 0.8, seed + 2))
    path = smoothstep(0.15, 0.7, ctx.fbm(np.array([0.7, 1.0, 0.25]), 3, seed + 3))
    s.rough = np.where(grout, 0.9, 0.22 + path * 0.25 + ctx.rand(seed + 4) * 0.04)
    s.height = np.where(grout, -0.003, s.height)
    return s


def am_woven_mat(ctx, seed=931, strip=4):
    """Tile 2 x 2 m: a plaited pandanus mat - 2/2 twill of ~5 cm strips,
    warp and weft catching the light differently, a dark gap at each strip
    edge, bands of stepped diamonds in dark-dyed strips."""
    W = int(round(2.0 / ctx.texel))
    over, edge, dyed = AP.mat_pattern(W, W, strip, seed)
    idx = canvas_index(over.shape, ctx.uvm[:, 0], ctx.uvm[:, 1], ctx.texel, wrap_x=True, wrap_y=True)
    ov = take(over, idx)
    ed = take(edge, idx).astype(bool)
    dy = take(dyed, idx).astype(bool)
    s = Surface(ctx.N)
    fib = ctx.fbm(np.array([40.0, 40.0, 40.0]), 2, seed) * 0.6
    shade = 5.6 + ov * -0.9 + fib + _dither(ctx, 0.6, seed + 1) - ed * 2.2
    shade += (noise.rand_cells(np.floor(ctx.uvm[:, 0] / (strip * ctx.texel)).astype(np.int64)
                               * (1 - ov) + np.floor(ctx.uvm[:, 1] / (strip * ctx.texel)).astype(np.int64) * ov * 31,
                               seed + 2) - 0.5) * 1.2
    shade -= smoothstep(0.2, 0.7, ctx.fbm(1.5, 3, seed + 3)) * 1.2
    shade -= (1.0 - ctx.ao) * 3.0
    s.use_ramp(P["am_fiber"], shade=shade)
    s.use_ramp(P["am_fiber_dye"], mask=dy & ~ed, shade=np.full(ctx.N, 2.4) + fib + _dither(ctx, 0.5, seed + 4))
    s.rough = np.full(ctx.N, 0.88)
    s.height = ed * -0.0012 + ov * 0.0004
    return s


def am_pacific_boards(ctx, seed=941):
    """Tile 2 x 2 m: dark hardwood floor boards 0.25 m wide (dark gap,
    staggered ends, wooden pegs), oiled and worn."""
    u, v = ctx.uvm[:, 0], ctx.uvm[:, 1]
    board = np.floor(v / 0.25 + 1e-9).astype(np.int64)
    off = noise.rand_cells(np.mod(board, 8), seed) * 2.0
    seg = np.floor((u + off) / 1.0 + 1e-9).astype(np.int64)
    fx = (u + off) - seg
    fz = v / 0.25 - board
    s = _wood_core(ctx, P["am_wood_dark"], 4.8, seed + 1, ring_freq=6.0)
    s.shade += (noise.rand_cells(np.mod(board, 8) * 8 + np.mod(seg, 2), seed + 2) - 0.5) * 1.4
    tx = ctx.texel
    gap = (fz * 0.25 < tx) | (fx < tx)
    peg = ((fx - 0.06) ** 2 + (fz * 0.25 - 0.125) ** 2) < (1.6 * tx) ** 2
    s.shade[gap] -= 3.0
    s.use_ramp(P["am_wood"], mask=peg, shade=np.full(ctx.N, 3.0))
    s.rough = np.where(gap, 0.95, 0.45 + ctx.fbm(1.0, 3, seed + 3) * 0.15)
    s.height = s.height - gap * 0.003
    return s


def tapa(ctx, seed=951, variant=0, scale=1, ppm=None):
    """Bark cloth: pale beaten fibre (streaks along one axis, faint beater
    lines), printed panels of brown and black geometric fills."""
    u, v = ctx.uvm[:, 0], ctx.uvm[:, 1]
    tex = AP.tapa_canvas(256, 256, variant, seed)
    idx = canvas_index(tex.shape, u, v, ctx.texel, wrap_x=True, wrap_y=True, scale=scale)
    codes = take(tex, idx)
    s = Surface(ctx.N)
    fib = ctx.fbm(np.array([2.0, 60.0, 60.0]), 3, seed, p=np.stack([u, v * 0.2, np.zeros(ctx.N)], 1))
    beater = np.mod(u / 0.012, 1.0) < 0.15
    shade = 5.0 + fib * 0.9 + _dither(ctx, 0.5, seed + 1) - beater * 0.4
    shade += np.clip(ctx.curv, 0, 1) * 1.0 - np.clip(-ctx.curv, 0, 1) * 1.4 - (1.0 - ctx.ao) * 3.2
    s.use_ramp(P["am_bark"], shade=shade)
    s.rough = np.full(ctx.N, 0.92)
    s = paint_over(ctx, s, codes, seed + 2, flake=0.08, wear=0.0, fade=0.6)
    s.height = fib * 0.0003
    return s


def am_tapa(ctx, seed=955):
    """Tile 4 x 4 m of bark cloth (two print layouts, 2 art pixels per
    texel at 64 px/m) for the Pacific gallery's ceiling and wall panels."""
    return tapa(ctx, seed, variant=0, scale=1)


def am_ceiling(ctx, seed=961):
    """Tile 4 x 2 m: a dark ceiling of smoke-blackened boards between
    round poles every metre (the beams of a great house)."""
    u, v = ctx.uvm[:, 0], ctx.uvm[:, 1]
    pole = np.abs(np.mod(u, 1.0) - 0.5) > 0.42
    board = np.floor(v / 0.2 + 1e-9).astype(np.int64)
    s = _wood_core(ctx, P["am_wood_dark"], 3.2, seed, ring_freq=5.0)
    s.shade += (noise.rand_cells(np.mod(board, 10), seed + 1) - 0.5) * 1.0
    gap = np.mod(v / 0.2, 1.0) < 0.06
    s.shade[gap & ~pole] -= 2.0
    across = np.abs(np.mod(u, 1.0) - 0.5) - 0.42
    s.use_ramp(P["am_wood"], mask=pole, shade=np.full(ctx.N, 3.6) - across * 30.0 + _dither(ctx, 0.5, seed + 2))
    soot = smoothstep(0.0, 0.6, ctx.fbm(0.8, 3, seed + 3))
    s.shade -= soot * 0.8
    s.rough = np.full(ctx.N, 0.85)
    s.height = np.where(pole, 0.004 - np.abs(across) * 0.05, 0.0) - gap * 0.002
    return s


MATERIALS = {
    "am_red_wall": am_red_wall,
    "am_frieze": am_frieze,
    "am_stone_blocks": am_stone_blocks,
    "basalt_americas": am_basalt_floor,
    "am_woven_mat": am_woven_mat,
    "boards_pacific": am_pacific_boards,
    "am_tapa": am_tapa,
    "am_ceiling": am_ceiling,
}
