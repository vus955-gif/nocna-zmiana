"""Materials of the Asia wing (Floor I: China, Korea, Japan): cinnabar and
black lacquer (worn through to the undercoat on the arrises, negoro style),
gold leaf on lacquer, archaic bronze under green patina (malachite crust,
azurite, cuprite; rubbed bright where hands touch), glazed porcelain with
underglaze cobalt, celadon with crazing and inlay, the milky white of a
moon jar, lime plaster, painted decoration (cinnabar, malachite, azurite,
ochre, gold), washi and hanji paper (lit from behind for shoji and
lanterns), silk, natural timber (hinoki, cedar), tatami, garden granite
with moss and lichen, raked gravel, cherry bark and blossom, pond water,
sumi ink. And the wing's tileable fields (64 px/m).

Same rules as materials.py: every colour is a step on a hand-picked ramp in
P (dark -> light); shading moves along the ramp. Canvases from
asia_paint.py are sampled one art pixel per texel (egypt.sample) and laid
on with egypt.paint_over and this module's INKS.
"""
import numpy as np

from . import asia_paint as AP
from . import egypt as E
from . import noise
from .materials import P, _age, _dither, _grain_frame, _select, _wood_core, hexramp, smoothstep
from .materials import MATERIALS as BASE
from .painter import Surface, combine

P.update({
    # cinnabar lacquer (zhu qi): deep warm red, aged a little brown
    "lacquer_red": hexramp("#150303", "#240504", "#380806", "#4f0c08", "#68120b", "#82190e", "#9b2213", "#b22d18",
                           "#c63c21", "#d6512e", "#e26a40"),
    "lacquer_black": hexramp("#040304", "#080707", "#0e0c0c", "#151213", "#1d191a", "#272223", "#332d2d",
                             "#413a39", "#524948"),
    # archaic bronze: patina crust, its blue and red minerals, the metal
    "patina": hexramp("#0c1712", "#13241b", "#1a3324", "#22432d", "#2c5537", "#386843", "#467b51", "#588f62",
                      "#6fa476", "#8bb98e", "#a9cca8"),
    "azurite": hexramp("#0d1a2b", "#14283f", "#1d3a57", "#284e70", "#376489", "#4b7ca0"),
    "cuprite": hexramp("#1e0b07", "#30130b", "#441d10", "#5a2915", "#71371c", "#8a4724"),
    "bronze_dark": hexramp("#0e0b08", "#18120c", "#231a10", "#2f2314", "#3c2d19", "#4a381f", "#5a4426"),
    "bronze_bright": hexramp("#3a2410", "#583718", "#764c20", "#93642b", "#ae7e39", "#c69a4d", "#dbb766",
                             "#ebd08a", "#f6e6b4"),
    # porcelain body / glaze white (Jingdezhen: cool, faintly blue)
    "porcelain_white": hexramp("#4b525a", "#626a72", "#7b838b", "#959ca3", "#aeb4ba", "#c5cacf", "#d8dce0",
                               "#e7eaec", "#f2f4f5", "#fafbfb"),
    "cobalt": hexramp("#070c2a", "#0c1640", "#122158", "#1a2e72", "#243d8c", "#304fa4", "#4263b9", "#5b7bc8",
                      "#7a95d4", "#9db2e0"),
    # Goryeo celadon: grey-green 'kingfisher' glaze
    "celadon": hexramp("#26332c", "#304037", "#3b4e43", "#475d50", "#546d5e", "#627d6c", "#728e7b", "#849f8c",
                       "#97b09e", "#adc2b1", "#c3d4c4"),
    # Joseon moon jar: warm milky white, a little uneven
    "moon_white": hexramp("#3e3a31", "#555046", "#6d675b", "#857f71", "#9d9787", "#b4ae9d", "#c9c3b2",
                          "#dad5c5", "#e8e4d6", "#f3f0e5"),
    "plaster_asia": hexramp("#4a4337", "#5e5647", "#736a59", "#887e6b", "#9d937e", "#b1a891", "#c3bba4",
                            "#d3cbb6", "#e0d9c6", "#ebe5d4"),
    # painted decoration (mineral pigments)
    "pig_red": hexramp("#2c0605", "#450a07", "#610f0a", "#7e160d", "#9a2012", "#b42c18", "#c93d22", "#da5431"),
    "pig_green": hexramp("#071a12", "#0c2a1c", "#123c28", "#1a5035", "#246444", "#307955", "#3f8e67", "#54a37b"),
    "pig_blue": hexramp("#071226", "#0c1d3b", "#132b53", "#1c3b6c", "#274e85", "#34629d", "#4777b2", "#5e8dc4"),
    "pig_ochre": hexramp("#33230a", "#4d3510", "#694a17", "#86601f", "#a2782a", "#ba8f38", "#cfa84c", "#e0bf65"),
    "pig_white": hexramp("#6b6658", "#86806f", "#a19a87", "#b9b29e", "#cec7b3", "#dfd9c6", "#ece7d7"),
    "pig_black": hexramp("#070707", "#0e0d0d", "#161414", "#1f1c1c", "#292525"),
    "pig_pink": hexramp("#4a1f25", "#6a2d35", "#8b3e47", "#aa525b", "#c46b72", "#d88c8f", "#e6acab"),
    "pig_ltgreen": hexramp("#1e3a26", "#2b5134", "#3a6943", "#4c8255", "#629b69", "#7cb381", "#99c99a"),
    "pig_ltblue": hexramp("#1e3550", "#2a4767", "#385b7f", "#4a7096", "#6087ac", "#7a9fc0", "#98b7d2"),
    "pig_orange": hexramp("#3a1404", "#5a2007", "#7c2e0b", "#9c3f11", "#b95318", "#d06a22", "#e2852f"),
    # sumi ink and seal paste
    "sumi": hexramp("#060607", "#0b0b0d", "#121214", "#1a1a1d", "#242428", "#303035", "#3e3e44", "#55555c",
                    "#6f6f75"),
    "seal_red": hexramp("#3a0707", "#5a0c0a", "#7c120d", "#9c1a12", "#b82518", "#cc3420"),
    # papers and textiles
    "washi": hexramp("#4f4838", "#655d4a", "#7c735d", "#938a71", "#aaa186", "#c0b89c", "#d3ccb2", "#e2dcc5",
                     "#eeead8", "#f6f3e8"),
    "silk_mount": hexramp("#1a1f17", "#252b20", "#31392a", "#3e4735", "#4c5641", "#5b664e", "#6b765c"),
    "brocade": hexramp("#200406", "#36080b", "#4e0d11", "#671318", "#801a1f", "#992327", "#b12f30"),
    "silk_red": hexramp("#2a0406", "#45070b", "#640c12", "#851219", "#a51b22", "#c1272c", "#d83a3a", "#ea5b52",
                        "#f6846f"),
    "lacing_red": hexramp("#1f0304", "#340607", "#4d0a0b", "#681010", "#841716", "#9e211d", "#b62e25", "#ca4030",
                          "#da563f"),
    "lacing_blue": hexramp("#04060f", "#080c1b", "#0d1329", "#141c39", "#1d284c", "#283560", "#354574",
                           "#465788"),
    "lacing_white": hexramp("#4d4a42", "#666256", "#807b6d", "#9a9585", "#b3ae9d", "#cac5b4", "#ddd9c9"),
    "lacing_green": hexramp("#081108", "#0e1c0e", "#152816", "#1e3620", "#29452b", "#365538", "#456646"),
    # timber
    "hinoki": hexramp("#3a2a1b", "#4f3a26", "#664c32", "#7d5f3f", "#94734e", "#aa8860", "#bf9d73", "#d1b287",
                      "#e0c69c"),
    "asia_cedar": hexramp("#1b0d07", "#2a150b", "#3b1e10", "#4d2915", "#60341b", "#734022", "#874d2a", "#9a5b34"),
    "tatami": hexramp("#2c2a14", "#3e3b1d", "#524e27", "#676232", "#7c763e", "#918a4b", "#a59d5a", "#b8b06b",
                      "#c9c27e"),
    "thatch": hexramp("#1b1309", "#2a1f0f", "#3a2b15", "#4b381c", "#5d4624", "#70552d", "#836537", "#957543"),
    # garden
    "garden_stone": hexramp("#17181a", "#202124", "#2a2b2e", "#35363a", "#414246", "#4e4f52", "#5c5d5f",
                            "#6b6b6c", "#7b7a79", "#8c8a87", "#9e9b96"),
    "moss": hexramp("#0b1408", "#111e0c", "#182a10", "#203614", "#2a4419", "#35521e", "#416124", "#4f702b",
                    "#5f8033"),
    "lichen": hexramp("#3c4034", "#4f5444", "#636a55", "#788066", "#8d9579", "#a3aa8e"),
    "gravel": hexramp("#3d3c39", "#4e4d49", "#605e5a", "#72706b", "#84827c", "#96938d", "#a8a59e", "#b9b6ae",
                      "#cac7bf", "#d9d6cf"),
    "bark": hexramp("#0f0909", "#170e0d", "#201413", "#2b1b19", "#37231f", "#432c26", "#50362e", "#5e4137"),
    "blossom": hexramp("#4a1e2c", "#6a2c3f", "#8a3d53", "#a85068", "#c2687f", "#d78598", "#e6a4b3", "#f1c3cd",
                       "#f8dde3", "#fdf0f2"),
    "leaf_young": hexramp("#1e2a0e", "#2c3c14", "#3c4f1b", "#4e6323", "#61782d", "#768d38"),
    "water": hexramp("#020506", "#04090b", "#060e10", "#091416", "#0d1b1d", "#122426", "#182e30", "#20393a"),
    "koi": hexramp("#3a1004", "#5c1a06", "#80270a", "#a3370f", "#c24c16", "#dc6620", "#ee8634", "#f7a95a"),
    "roof_tile": hexramp("#0f1011", "#16171a", "#1e2023", "#27292d", "#313438", "#3c3f44", "#484c51", "#555a60"),
    "earth_wall": hexramp("#3a2c1c", "#4d3b26", "#614b31", "#755c3d", "#896d4a", "#9c7f59", "#ae9169", "#bfa37c",
                          "#cdb48f"),
    "wood_grey": hexramp("#1d1c19", "#282622", "#33302b", "#3f3b35", "#4b4740", "#58534b", "#665f56", "#746c62"),
    "iron_kettle": hexramp("#0a0a0b", "#111112", "#18181a", "#212123", "#2b2a2c", "#363436"),
    "slate": hexramp("#0d100f", "#131816", "#1a201e", "#222927", "#2b3330", "#353e3a", "#404a45", "#4c5651",
                     "#5a645e"),
    "fur_dark": hexramp("#0b0907", "#14100c", "#1d1711", "#271f17", "#32281e", "#3e3226"),
})

# canvas code -> (ramp, centre shade, roughness, metalness)
INKS = {
    AP.INK["outline"]: ("pig_black", 1.6, 0.6, 0.0),
    AP.INK["red"]: ("pig_red", 4.2, 0.55, 0.0),
    AP.INK["green"]: ("pig_green", 3.8, 0.6, 0.0),
    AP.INK["blue"]: ("pig_blue", 3.8, 0.6, 0.0),
    AP.INK["white"]: ("pig_white", 4.4, 0.6, 0.0),
    AP.INK["black"]: ("pig_black", 2.0, 0.5, 0.0),
    AP.INK["gold"]: ("gold", 6.2, 0.28, 1.0),
    AP.INK["ochre"]: ("pig_ochre", 4.4, 0.6, 0.0),
    AP.INK["lt_green"]: ("pig_ltgreen", 3.8, 0.6, 0.0),
    AP.INK["lt_blue"]: ("pig_ltblue", 3.8, 0.6, 0.0),
    AP.INK["pink"]: ("pig_pink", 4.0, 0.6, 0.0),
    AP.INK["orange"]: ("pig_orange", 4.2, 0.6, 0.0),
    AP.INK["ink"]: ("sumi", 1.6, 0.55, 0.0),
    AP.INK["ink_dark"]: ("sumi", 0.6, 0.45, 0.0),
    AP.INK["ink_dry"]: ("sumi", 4.6, 0.7, 0.0),
    AP.INK["seal"]: ("seal_red", 3.6, 0.6, 0.0),
    AP.INK["cobalt"]: ("cobalt", 4.2, 0.1, 0.0),
    AP.INK["cobalt_dark"]: ("cobalt", 1.8, 0.1, 0.0),
    AP.INK["cobalt_wash"]: ("cobalt", 6.6, 0.1, 0.0),
    AP.INK["inlay_white"]: ("pig_white", 5.4, 0.12, 0.0),
    AP.INK["inlay_black"]: ("pig_black", 1.4, 0.12, 0.0),
    AP.INK["dk_green"]: ("pig_green", 1.6, 0.6, 0.0),
    AP.INK["dk_red"]: ("pig_red", 1.8, 0.55, 0.0),
}


def inks_glazed(base):
    """The same inks seen through a glossy glaze (porcelain): low roughness."""
    return {k: (r, c, min(rough, 0.12), m) for k, (r, c, rough, m) in base.items()}


def paint(ctx, s, canvas, u=None, v=None, u0=0.0, v0=0.0, wrap_x=True, wrap_y=True, flake=0.3, relief=0.0,
          wear=1.0, inks=None, scale=1, seed=0):
    """Samples ``canvas`` at the texels' metre UVs and paints it over ``s``."""
    u = ctx.uvm[:, 0] if u is None else u
    v = ctx.uvm[:, 1] if v is None else v
    codes, rims = E.sample(canvas, u, v, ctx.texel, u0=u0, v0=v0, wrap_x=wrap_x, wrap_y=wrap_y, scale=scale)
    return E.paint_over(ctx, s, codes, rims, seed, flake=flake, relief=relief, wear=wear,
                        inks=INKS if inks is None else inks), codes


# --------------------------------------------------------------------------
# lacquer, gilding, timber
# --------------------------------------------------------------------------

def lacquer(ctx, seed=801, ramp="lacquer_red", center=5.0, wear=1.0, under="lacquer_black", crackle=0.6,
            gloss=0.26):
    """Lacquer on wood: a deep glossy coat with long soft brush ripples, a
    fine web of crackle, the top coat rubbed through to the undercoat on
    the arrises and high spots (red over black: negoro), dust in the
    hollows."""
    s = Surface(ctx.N)
    along, across = _grain_frame(ctx)
    a = np.sum(ctx.p * along, axis=1)
    c = np.sum(ctx.p * across, axis=1)
    q = np.stack([a, np.sum(ctx.p * ctx.n, axis=1), c], axis=1)
    ripple = ctx.fbm(np.array([1.2, 8.0, 8.0]), 2, seed, p=q) * 0.6
    shade = center + ripple + ctx.fbm(2.0, 3, seed + 1) * 0.5 + _dither(ctx, 0.5, seed + 2)
    shade += ctx.edge(1.0) * 1.6 + ctx.edge(2.0) * 0.5 + np.clip(ctx.curv, 0, 1) * 1.0
    shade -= ctx.cavity(3.0) * 2.0 + (1.0 - ctx.ao) * 3.6 + np.clip(-ctx.curv, 0, 1) * 1.2
    f1, f2, _ = ctx.worley(22.0, seed + 3)
    crack = ((f2 - f1) < 0.035) & (ctx.fbm(1.2, 2, seed + 4) > 0.15 - 0.3 * crackle)
    shade -= crack * 1.4 * crackle
    s.use_ramp(P[ramp], shade=shade)
    rub = ctx.edge_soft(2.0) * 0.8 + np.clip(ctx.curv, 0, 1) * 0.7 + ctx.fbm(7.0, 3, seed + 5) * 0.5
    worn = (rub > 0.8) & (ctx.fbm(2.5, 3, seed + 12) > 0.45 - 0.6 * wear) & (wear > 0)
    if under:
        s.use_ramp(P[under], mask=worn, shade=np.full(ctx.N, 3.2) + ctx.fbm(20.0, 2, seed + 6) * 1.0
                   + _dither(ctx, 0.6, seed + 7))
    s.rough = gloss + ripple * 0.05 + crack * 0.3 + ctx.rand(seed + 8) * 0.03 + (1.0 - ctx.ao) * 0.2
    s.rough = np.where(worn, 0.42, s.rough)
    s.height = ripple * 0.0002 - crack * 0.0002 * crackle - worn * 0.0003
    return s


def lacquer_red(ctx, seed=801):
    return lacquer(ctx, seed)


def lacquer_black(ctx, seed=811):
    return lacquer(ctx, seed, ramp="lacquer_black", center=3.2, under="lacquer_red", wear=0.55, crackle=0.4)


def gilt(ctx, seed=821, worn=1.0, under="lacquer_red", rough=0.4, grime=1.0):
    """Gold leaf laid on lacquer: an old, soft gold (not a mirror), bright
    on the highs, gone dark brown with dust and old varnish in the hollows
    (the form reads under any light), rubbed through to the red (or black)
    lacquer on the arrises; leaf seams faintly visible."""
    s = BASE["brass"](ctx, seed, ramp="gold", tarnish_amount=0.8, grain=0.4)
    s.shade += 0.4 + np.clip(ctx.curv, 0, 1) * 1.0 - np.clip(-ctx.curv, 0, 1) * 1.4
    seam = ((np.mod(ctx.uvm[:, 0], 0.09) < ctx.texel) | (np.mod(ctx.uvm[:, 1], 0.09) < ctx.texel)) & \
        (ctx.fbm(4.0, 2, seed + 12) > 0.1)
    s.shade -= seam * 0.3
    grime = ((1.0 - ctx.ao) * 2.4 + ctx.cavity(4.0) * 0.9 + np.clip(-ctx.curv, 0, 1) * 1.4
             + ctx.fbm(6.0, 3, seed + 8) * 0.35) * grime > 0.62
    s.use_ramp(P["bronze_dark"], mask=grime, shade=np.full(ctx.N, 3.6) + ctx.fbm(14.0, 2, seed + 9) * 1.2
               + ctx.ao * 1.6 + _dither(ctx, 0.6, seed + 10))
    rub = ctx.edge_soft(2.5) * 0.8 + np.clip(ctx.curv, 0, 1) * 0.6 + ctx.fbm(12.0, 2, seed + 5) * 0.6
    lost = (rub > 0.95 - 0.25 * worn) & (ctx.fbm(5.0, 2, seed + 6) > 0.0) & (worn > 0)
    s.use_ramp(P[under], mask=lost, shade=np.full(ctx.N, 3.6) + _dither(ctx, 0.8, seed + 7))
    s.metal = np.where(lost, 0.0, np.where(grime, 0.35, 0.85))
    s.rough = np.where(lost, 0.45, np.where(grime, 0.7, rough + ctx.fbm(3.0, 2, seed + 11) * 0.1))
    return s


def wood(ctx, seed=831, ramp="hinoki", center=5.0, rough=0.62, contrast=0.8, ring_freq=10.0):
    """Unpainted, oiled timber (hinoki, cedar): straight grain, soft rings."""
    s = _wood_core(ctx, P[ramp], center, seed, ring_freq=ring_freq, contrast=contrast)
    _age(ctx, s, cavity=1.8, ao=3.0, edge=1.0)
    s.rough = rough + np.clip(ctx.fbm(3.0, 3, seed + 5), 0, 1) * 0.15
    return s


def weathered_wood(ctx, seed=837):
    """Silver-grey sun-bleached boards (garden bridge planks, engawa)."""
    s = _wood_core(ctx, P["wood_grey"], 4.6, seed, ring_freq=12.0, contrast=1.3)
    _age(ctx, s, cavity=2.0, ao=3.4, edge=1.4)
    s.rough = np.full(ctx.N, 0.82)
    s.height = s.height * 2.0
    return s


def painted(ctx, ramp="pig_green", center=4.0, seed=1101, line="pig_white", outline=True, flake=0.35,
            ground="hinoki"):
    """A painted timber member in the manner of Chinese caihua and Korean
    dancheong: one mineral pigment, a black hairline on every arris with a
    white (or ``line``) stripe just inside it - the members read outlined
    from far away - soot in the hollows, paint flaking to the bare wood."""
    s = Surface(ctx.N)
    shade = center + ctx.fbm(3.0, 3, seed) * 0.5 + _dither(ctx, 0.4, seed + 1)
    shade -= (1.0 - ctx.ao) * 2.6 + ctx.cavity(3.0) * 1.5
    s.use_ramp(P[ramp], shade=shade)
    tx = ctx.texel
    if outline:
        e = ctx.convex
        dark = e < tx * 1.0
        light = (e >= tx * 1.0) & (e < tx * 2.0)
        s.use_ramp(P["pig_black"], mask=dark, shade=np.full(ctx.N, 2.4))
        s.use_ramp(P[line], mask=light, shade=np.full(ctx.N, 4.8) + _dither(ctx, 0.5, seed + 2)
                   - (1.0 - ctx.ao) * 2.0)
    fl = ctx.fbm(8.0, 3, seed + 3) + ctx.fbm(30.0, 2, seed + 4) * 0.3 + ctx.edge_soft(3.0) * 0.4
    lost = fl > 0.68 - 0.4 * flake
    s.use_ramp(P[ground], mask=lost, shade=np.full(ctx.N, 2.6) + ctx.fbm(20.0, 2, seed + 5) * 0.8)
    s.rough = np.where(lost, 0.85, 0.72) + ctx.rand(seed + 6) * 0.04
    s.height = np.where(lost, -0.0006, 0.0)
    return s


# --------------------------------------------------------------------------
# bronze
# --------------------------------------------------------------------------

def bronze_patina(ctx, seed=841, crust=1.0, polish=0.0, rubbed=None, dark=0.0):
    """Archaic bronze after three thousand years: a continuous grey-green
    patina (smooth and darker on the open faces, a pale powdery crust of
    malachite in the hollows), islands of dark 'water patina' where the
    metal shows almost black, specks of blue azurite and red cuprite; warm
    brown bronze where it is polished (``polish`` on edges and highs,
    ``rubbed`` a 0..1 mask of places worn by hands)."""
    s = Surface(ctx.N)
    cloud = ctx.fbm(2.6, 4, seed) + ctx.fbm(11.0, 2, seed + 1) * 0.35
    cav = np.clip(ctx.cavity(4.0) + (1.0 - ctx.ao) * 1.6 + np.clip(-ctx.curv, 0, 1), 0.0, 1.5)
    f1, _, cid = ctx.worley(60.0, seed + 4)
    gran = (f1 < 0.4).astype(np.float64)
    shade = 4.2 + cloud * 1.6 + cav * 1.2 * crust + gran * 0.5 * crust + _dither(ctx, 0.6, seed + 5)
    shade -= np.clip(ctx.curv, 0, 1) * 0.8 + (1.0 - ctx.ao) * 1.4
    s.use_ramp(P["patina"], shade=shade)
    darkm = (ctx.fbm(1.8, 3, seed + 2) < -0.32 + dark) & (cav < 0.4 + dark)
    s.use_ramp(P["bronze_dark"], mask=darkm, shade=np.full(ctx.N, 3.4) + cloud * 1.2 + ctx.edge(1.0) * 1.2
               + _dither(ctx, 0.6, seed + 3))
    azu = ~darkm & (ctx.fbm(9.0, 2, seed + 6) > 0.5) & (cid > 0.7)
    s.use_ramp(P["azurite"], mask=azu, shade=np.full(ctx.N, 3.0) + gran * 1.2 + _dither(ctx, 0.6, seed + 7))
    cup = ~darkm & ~azu & (ctx.fbm(6.0, 2, seed + 8) > 0.48) & (cid < 0.25)
    s.use_ramp(P["cuprite"], mask=cup, shade=np.full(ctx.N, 2.6) + ctx.fbm(20.0, 2, seed + 9) * 1.2)
    bright = np.zeros(ctx.N)
    if polish > 0:
        bright = (ctx.edge_soft(2.5) * 0.8 + np.clip(ctx.curv, 0, 1) * 0.8) * polish
    if rubbed is not None:
        bright = np.maximum(bright, rubbed)
    shine = bright > 0.5
    s.use_ramp(P["bronze_bright"], mask=shine, shade=np.full(ctx.N, 2.4) + bright * 1.6 + _dither(ctx, 0.8, seed + 10)
               - (1.0 - ctx.ao) * 2.0)
    s.metal = np.where(shine, 0.9, np.where(darkm, 0.5, 0.0))
    s.rough = np.where(shine, 0.35, np.where(darkm, 0.5, 0.8 + cav * 0.1)) + ctx.rand(seed + 11) * 0.04
    s.height = (cav * 0.0006 + gran * 0.0003) * crust + ctx.fbm(30.0, 2, seed + 12) * 0.0002
    return s


# --------------------------------------------------------------------------
# ceramics
# --------------------------------------------------------------------------

def glaze(ctx, seed=851, ramp="porcelain_white", center=7.4, craze=0.0, pool=1.0, pinholes=0.5):
    """A glossy glaze: smooth, faint undulation, glaze pooling darker in the
    hollows and thinning on the rims, optional crackle (crazing)."""
    s = Surface(ctx.N)
    und = ctx.fbm(4.0, 3, seed) * 0.5
    shade = center + und + _dither(ctx, 0.35, seed + 1) + ctx.edge(1.0) * 0.8 + np.clip(ctx.curv, 0, 1) * 0.6
    shade -= (ctx.cavity(3.0) * 1.6 + (1.0 - ctx.ao) * 3.0 + np.clip(-ctx.curv, 0, 1) * 1.6) * pool
    if craze > 0:
        f1, f2, _ = ctx.worley(40.0, seed + 2)
        g1, g2, _ = ctx.worley(14.0, seed + 3)
        cr = (((f2 - f1) < 0.03) & (ctx.fbm(2.0, 2, seed + 4) > 0.0)) | ((g2 - g1) < 0.02)
        shade -= cr * 1.6 * craze
    else:
        cr = np.zeros(ctx.N, dtype=bool)
    pin = (ctx.rand(seed + 5) > 1.0 - 0.004 * pinholes)
    shade -= pin * 1.5
    s.use_ramp(P[ramp], shade=shade)
    s.rough = 0.07 + und * 0.03 + cr * 0.2 + ctx.rand(seed + 6) * 0.02
    s.height = und * 0.0001 - cr * 0.0001
    return s


def porcelain_blue(canvas, center=7.6, seed=861):
    """Blue-and-white: underglaze cobalt (heaped and piled specks of darker
    blue in the strokes) under a cool clear glaze."""
    def fn(ctx):
        s = glaze(ctx, seed, "porcelain_white", center)
        codes, rims = E.sample(canvas, ctx.uvm[:, 0], ctx.uvm[:, 1], ctx.texel, wrap_x=True)
        blue = codes > 0
        s = E.paint_over(ctx, s, codes, np.zeros_like(rims), seed + 1, flake=0.0, relief=0.0, wear=0.0,
                         inks=inks_glazed(INKS))
        heap = blue & (ctx.rand(seed + 2) > 0.86)
        s.shade[heap] -= 2.0
        s.shade[blue] -= (1.0 - ctx.ao[blue]) * 2.0
        s.rough[blue] = 0.08
        return s
    return fn


# --------------------------------------------------------------------------
# plaster, paper, textiles
# --------------------------------------------------------------------------

def plaster(ctx, seed=871, center=6.0, ramp="plaster_asia"):
    """Lime plaster in warm ivory: trowel clouds, hairline cracks, soot."""
    s = Surface(ctx.N)
    base = center + ctx.fbm(2.0, 4, seed) * 0.8 + ctx.fbm(10.0, 2, seed + 1) * 0.35 + _dither(ctx, 0.6, seed)
    crack = (np.abs(ctx.fbm(1.1, 4, seed + 2)) < 0.01) & (ctx.fbm(0.6, 2, seed + 6) > 0.3)
    base -= crack * 1.5
    s.use_ramp(P[ramp], shade=base)
    _age(ctx, s, cavity=2.2, ao=3.4, edge=0.8)
    s.height = ctx.fbm(9.0, 3, seed + 4) * 0.0009 - crack * 0.001
    s.rough = 0.86 + ctx.rand(seed + 5) * 0.06
    return s


def paper(ctx, seed=881, ramp="washi", center=6.6, glow=0.0, fibres=1.0):
    """Washi / hanji: long fibres, slight cockling; ``glow`` > 0 makes it
    lit from behind (shoji at night, lantern paper)."""
    s = Surface(ctx.N)
    fib = ctx.fbm(np.array([40.0, 40.0, 4.0]), 2, seed) * 0.35 * fibres + ctx.fbm(60.0, 2, seed + 1) * 0.25 * fibres
    shade = center + fib + ctx.fbm(3.0, 3, seed + 2) * 0.4 + _dither(ctx, 0.4, seed + 3) - (1.0 - ctx.ao) * 2.4
    s.use_ramp(P[ramp], shade=shade)
    s.rough = np.full(ctx.N, 0.9)
    s.height = fib * 0.0002
    if glow > 0:
        s.emit = s.colors() * glow
    return s


def silk(ctx, ramp="silk_red", center=4.6, seed=891, sheen=1.0):
    """Woven silk: fine weave, a satin sheen on the folds."""
    s = Surface(ctx.N)
    u = ctx.uvm[:, 0] / ctx.texel
    v = ctx.uvm[:, 1] / ctx.texel
    weave = ((np.floor(u) + np.floor(v)) % 2) * 0.3
    shade = center + weave + ctx.fbm(5.0, 3, seed) * 0.5 + _dither(ctx, 0.4, seed + 1)
    shade += (np.clip(ctx.curv, 0, 1) * 1.6 + ctx.edge_soft(2.0) * 0.8) * sheen
    shade -= np.clip(-ctx.curv, 0, 1) * 1.8 + ctx.cavity(3.0) * 1.8 + (1.0 - ctx.ao) * 3.2
    s.use_ramp(P[ramp], shade=shade)
    s.rough = 0.45 + ctx.rand(seed + 2) * 0.05
    s.height = weave * 0.0002
    return s


def braid(ctx, ramp="lacing_red", center=4.6, seed=895, axis=None):
    """Silk lacing braid (odoshi-ito): diagonal twill ridges along the cord."""
    s = Surface(ctx.N)
    u = ctx.uvm[:, 0] / ctx.texel
    v = ctx.uvm[:, 1] / ctx.texel
    tw = np.mod(np.floor(u + v), 3) == 0
    shade = center + tw * -0.9 + ctx.fbm(8.0, 2, seed) * 0.5 + _dither(ctx, 0.4, seed + 1)
    shade += np.clip(ctx.curv, 0, 1) * 1.2 + ctx.edge_soft(2.0) * 0.6
    shade -= ctx.cavity(3.0) * 2.0 + (1.0 - ctx.ao) * 3.4
    s.use_ramp(P[ramp], shade=shade)
    s.rough = np.full(ctx.N, 0.55)
    s.height = tw * -0.0002
    return s


# --------------------------------------------------------------------------
# garden
# --------------------------------------------------------------------------

def garden_stone(ctx, seed=901, moss=1.0, center=5.0, lichen=1.0):
    """Weathered granite boulders: grainy grey with dark mica specks, pale
    crystal glints, rain streaks; moss on the tops and in the hollows,
    lichen rosettes on the sides."""
    s = Surface(ctx.N)
    k = min(3.0, max(1.0, (1.0 / 64.0) / ctx.texel * 0.8))
    f1, _, cid = ctx.worley(30.0 * k, seed)
    cloud = ctx.fbm(1.6, 4, seed + 1) * 1.0
    shade = center + cloud + (cid - 0.5) * 1.4 + _dither(ctx, 0.6, seed + 2)
    shade += ctx.edge(1.0) * 1.0 + np.clip(ctx.curv, 0, 1) * 1.6
    shade -= ctx.cavity(4.0) * 2.0 + (1.0 - ctx.ao) * 3.6 + np.clip(-ctx.curv, 0, 1) * 1.8
    streak = smoothstep(0.2, 0.8, ctx.fbm(np.array([7.0, 7.0, 0.6]), 3, seed + 3))
    shade -= streak * 0.8 * (ctx.n[:, 2] < 0.6)
    s.use_ramp(P["garden_stone"], shade=shade)
    dark = (cid < 0.12) & (f1 < 0.4)
    s.shade[dark] -= 2.0
    up = ctx.n[:, 2]
    mn = ctx.fbm(3.5, 4, seed + 4) + ctx.fbm(18.0, 2, seed + 5) * 0.3
    mossy = ((up > 0.45 - 0.25 * mn) & (mn + up * 0.6 > 0.55 - 0.35 * moss)) | \
            ((1.0 - ctx.ao) * 1.2 + mn * 0.5 > 1.25 - 0.4 * moss)
    mossy &= moss > 0
    msh = 3.6 + mn * 2.0 + ctx.fbm(40.0, 2, seed + 6) * 0.8 + _dither(ctx, 0.8, seed + 7) - (1.0 - ctx.ao) * 2.5
    s.use_ramp(P["moss"], mask=mossy, shade=msh)
    if lichen > 0:
        g1, _, gid = ctx.worley(9.0, seed + 8)
        lic = ~mossy & (g1 < 0.28) & (gid > 0.75) & (np.abs(up) < 0.8)
        s.use_ramp(P["lichen"], mask=lic, shade=np.full(ctx.N, 3.2) + g1 * 4.0 + _dither(ctx, 0.6, seed + 9))
    s.rough = np.where(mossy, 0.95, 0.78) + ctx.rand(seed + 10) * 0.05
    s.height = ctx.fbm(16.0, 3, seed + 11) * 0.0012 + mossy * 0.002 + mn * 0.0004
    return s


def gravel(ctx, seed=911, rake=None, pitch=0.125):
    """Pale granite gravel: pebbles a texel or two across, sun-bleached
    tops, shadowed gaps. ``rake`` = per-texel distance across the furrows
    (metres) or None for plain gravel; furrows every ``pitch`` metres
    (lit ridge, shadowed trough)."""
    s = Surface(ctx.N)
    f1, f2, cid = ctx.worley(140.0, seed)
    peb = (cid - 0.5) * 1.6 - smoothstep(0.25, 0.5, f1) * 1.2
    shade = 5.4 + peb + ctx.fbm(1.5, 3, seed + 1) * 0.6 + _dither(ctx, 0.6, seed + 2)
    h = -smoothstep(0.3, 0.55, f1) * 0.002
    if rake is not None:
        ph = np.mod(rake / pitch, 1.0)
        prof = np.cos(ph * 2.0 * np.pi)
        lit = np.sin(ph * 2.0 * np.pi)
        shade += lit * 1.4 + prof * 0.4
        h = h + prof * 0.008
    s.use_ramp(P["gravel"], shade=shade - (1.0 - ctx.ao) * 3.0)
    s.rough = np.full(ctx.N, 0.92)
    s.height = h
    return s


def gravel_raked(ctx, seed=917):
    """Field: furrows along x (the length of the garden), 12.5 cm pitch."""
    return gravel(ctx, seed, rake=ctx.uvm[:, 1])


def gravel_plain(ctx, seed=919):
    return gravel(ctx, seed)


def bark(ctx, seed=921, flow=(0.0, 0.0, 1.0)):
    """Cherry bark: dark red-brown, glossy horizontal bands of lenticels
    (the cherry's signature), rough cracks lower down, moss at the foot."""
    s = Surface(ctx.N)
    z = ctx.p[:, 2]
    cr = ctx.fbm(np.array([22.0, 22.0, 3.0]), 3, seed)
    shade = 3.6 + cr * 1.2 + ctx.fbm(2.0, 3, seed + 1) * 0.6 + _dither(ctx, 0.6, seed + 2)
    lent = (np.mod(z * 28.0 + ctx.fbm(3.0, 2, seed + 3) * 1.4, 1.0) < 0.12) & (ctx.fbm(12.0, 2, seed + 4) > -0.1)
    shade += lent * 1.6
    shade += np.clip(ctx.curv, 0, 1) * 1.4 - np.clip(-ctx.curv, 0, 1) * 1.8 - (1.0 - ctx.ao) * 3.0
    s.use_ramp(P["bark"], shade=shade)
    mossy = (z < 0.6 + ctx.fbm(3.0, 2, seed + 5) * 0.3) & (ctx.fbm(4.0, 3, seed + 6) > 0.0)
    s.use_ramp(P["moss"], mask=mossy, shade=np.full(ctx.N, 3.4) + ctx.fbm(30.0, 2, seed + 7) * 1.2)
    s.rough = np.where(lent, 0.45, 0.85)
    s.height = cr * 0.003 + lent * 0.0008
    return s


def blossom(ctx, seed=931, density=1.0, alpha=True):
    """Clusters of cherry blossom (somei-yoshino: nearly white, blushed
    pink, deeper pink hearts, a few young bronze-green leaves): five-petal
    flowers a few texels across; with ``alpha`` the gaps between flowers are
    cut out (the cards' lace)."""
    s = Surface(ctx.N)
    f1, f2, cid = ctx.worley(30.0, seed)
    flower = f1 < 0.45
    heart = f1 < 0.1
    shade = 7.2 + (cid - 0.5) * 1.8 + (0.45 - f1) * 2.0 + _dither(ctx, 0.5, seed + 1)
    if not ctx.tile:
        shade += np.clip(ctx.curv, 0, 1) * 0.8 + ctx.n[:, 2] * 0.6
        shade -= (1.0 - ctx.ao) * 2.6 + np.clip(-ctx.curv, 0, 1) * 1.0
    s.use_ramp(P["blossom"], shade=shade)
    s.shade[heart] -= 2.2
    leaf = ~flower & (ctx.fbm(9.0, 2, seed + 2) > 0.45)
    s.use_ramp(P["leaf_young"], mask=leaf, shade=np.full(ctx.N, 3.0) - (1.0 - ctx.ao) * 1.5)
    gap = ~flower & ~leaf
    s.use_ramp(P["blossom"], mask=gap, shade=np.full(ctx.N, 4.2) + ctx.fbm(20.0, 2, seed + 4) * 0.8
               - (1.0 - ctx.ao) * 1.5)
    s.rough = np.full(ctx.N, 0.75)
    s.sss = np.where(flower, 0.5, 0.1)
    if alpha:
        edge_cut = (ctx.fbm(14.0, 2, seed + 3) > 0.25 * density) & gap
        s.alpha = np.where(edge_cut, 0.0, 1.0)
    s.height = flower * 0.001 + heart * -0.0005
    return s


def cherry_blossom(ctx, seed=937):
    """Field: blossom for the cloud clusters of the cherry tree. Tile 2 x 2 m."""
    return blossom(ctx, seed, alpha=False)


def water(ctx, seed=941, koi=0):
    """Still pond water: near-black teal, mirror-smooth (the moon in it),
    faint ripples, a few koi under the surface."""
    s = Surface(ctx.N)
    rip = ctx.fbm(np.array([6.0, 6.0, 6.0]), 2, seed) * 0.4
    shade = 3.0 + rip + ctx.fbm(1.0, 3, seed + 1) * 0.8 + _dither(ctx, 0.3, seed + 2)
    s.use_ramp(P["water"], shade=shade)
    s.rough = 0.03 + np.abs(rip) * 0.03
    s.height = rip * 0.0004
    return s


def tatami(ctx, seed=951, along_u=True):
    """Tatami: woven igusa rush (fine ridges across the mat), a black cloth
    border (heri) handled by the caller, faded yellow-green."""
    s = Surface(ctx.N)
    u = ctx.uvm[:, 0] if along_u else ctx.uvm[:, 1]
    ridge = np.mod(np.floor(u / ctx.texel), 2) == 0
    shade = 5.0 + ridge * 0.7 + ctx.fbm(np.array([0.8, 0.8, 0.8]), 3, seed) * 0.8 + ctx.fbm(30.0, 2, seed + 1) * 0.3
    shade += _dither(ctx, 0.4, seed + 2) - (1.0 - ctx.ao) * 2.6
    s.use_ramp(P["tatami"], shade=shade)
    s.rough = np.full(ctx.N, 0.75)
    s.height = ridge * 0.0003
    return s


def thatch(ctx, seed=961):
    """Thick reed / cedar-bark thatch: coarse strands running down the
    slope, darker in the gaps, mossy patches."""
    s = Surface(ctx.N)
    along, across = _grain_frame(ctx)
    c = np.sum(ctx.p * across, axis=1)
    a = np.sum(ctx.p * along, axis=1)
    strand = np.sin(c / ctx.texel * 1.7 + ctx.fbm(6.0, 2, seed) * 5.0) * 0.5 + 0.5
    shade = 4.0 + strand * 1.8 + ctx.fbm(2.0, 3, seed + 1) * 0.8 + _dither(ctx, 0.6, seed + 2)
    shade -= (1.0 - ctx.ao) * 3.4 + ctx.cavity(3.0) * 1.6
    s.use_ramp(P["thatch"], shade=shade)
    mossy = ctx.fbm(1.5, 3, seed + 3) > 0.48
    s.use_ramp(P["moss"], mask=mossy, shade=np.full(ctx.N, 3.0) + strand * 1.2 - (1.0 - ctx.ao) * 2.0)
    s.rough = np.full(ctx.N, 0.95)
    s.height = strand * 0.004
    return s


def roof_tiles(ctx, seed=971, pitch=0.25):
    """Grey fired-clay roof tiles (hongwa / kawara): rolled rows along the
    slope (v), a dark gap between them, lighter rounded crowns."""
    s = Surface(ctx.N)
    u, v = ctx.uvm[:, 0], ctx.uvm[:, 1]
    ph = np.mod(u / pitch, 1.0)
    crown = np.cos((ph - 0.5) * np.pi) ** 2
    row = np.mod(v / 0.3, 1.0)
    lip = row < 0.08
    shade = 2.6 + crown * 3.2 - lip * 1.6 + ctx.fbm(3.0, 3, seed) * 0.6 + _dither(ctx, 0.5, seed + 1)
    shade -= (1.0 - ctx.ao) * 2.4
    s.use_ramp(P["roof_tile"], shade=shade)
    lich = ctx.fbm(4.0, 3, seed + 2) > 0.45
    s.use_ramp(P["lichen"], mask=lich & (crown > 0.4), shade=np.full(ctx.N, 1.6) + crown * 1.2)
    s.rough = np.full(ctx.N, 0.7)
    s.height = crown * 0.012 - lip * 0.006
    return s


# --------------------------------------------------------------------------
# tileable fields (64 px/m)
# --------------------------------------------------------------------------

def asia_plaster(ctx, seed=1001):
    """Field: warm ivory lime plaster (the hall walls above the dado)."""
    return plaster(ctx, seed, center=6.2)


def asia_plaster_dark(ctx, seed=1003):
    """Field: deep charcoal plaster of the armour hall (a dark stage for
    the lacquer and the gold)."""
    s = plaster(ctx, seed, center=1.8, ramp="pig_black")
    return s


_BAND = {}


def _band_canvas():
    """The painted frieze, 256 x 64 px (4 x 1 m): gold and coloured border
    lines, then lotus roundels alternating with pairs of ruyi clouds on a
    deep malachite ground."""
    if "c" in _BAND:
        return _BAND["c"]
    W, H = 256, 64
    c = AP.blank(W, H, AP.INK["dk_green"])
    I = AP.INK
    for y0, y1, code in ((0, 3, I["red"]), (3, 4, I["gold"]), (4, 7, I["blue"]), (7, 8, I["white"]),
                         (56, 57, I["white"]), (57, 60, I["blue"]), (60, 61, I["gold"]), (61, 64, I["red"])):
        c[y0:y1] = code
    for k in range(4):
        cx = 32 + 64 * k
        AP.lotus_roundel(c, cx, 32, 20, petal=I["red"] if k % 2 == 0 else I["blue"],
                         petal2=I["pink"] if k % 2 == 0 else I["lt_blue"])
        AP.ring(c, cx, 32, 21.5, 23, I["gold"])
        for sx in (-1, 1):
            m = AP.ruyi(c, cx + 32 + sx * 11, 32, 11, I["white"], flip=sx > 0)
            AP.outline(c, m, I["lt_green"], only_empty=False)
    _BAND["c"] = c
    return c


def asia_band(ctx, seed=1011):
    """Field: the painted frieze over plaster (a band 1 m high on a whole
    metre, like the Egypt frieze). Tile 4 x 1 m."""
    s = plaster(ctx, seed, center=5.6)
    s, _ = paint(ctx, s, _band_canvas(), flake=0.18, seed=seed + 1)
    return s


def tiles_golden(ctx, seed=1021):
    """Field: square fired-clay floor tiles, 0.5 m, dark grey and polished
    (the Forbidden City's 'golden bricks'), laid in running bond, each tile
    a little different, oiled sheen, a texel of lime grout, chipped
    corners. Tile 4 x 4 m."""
    u, v = ctx.uvm[:, 0], ctx.uvm[:, 1]
    tsz = 0.5
    row = np.floor(v / tsz + 1e-9).astype(np.int64)
    shift = np.mod(row, 2) * tsz * 0.5
    col = np.floor((u + shift) / tsz + 1e-9).astype(np.int64)
    fx = (u + shift) - col * tsz
    fz = v - row * tsz
    tid = np.mod(row, 8) * 16 + np.mod(col, 8)
    tone = noise.rand_cells(tid, seed) - 0.5
    s = Surface(ctx.N)
    shade = 3.4 + tone * 1.4 + ctx.fbm(3.0, 3, seed + 1) * 0.6 + ctx.fbm(24.0, 2, seed + 2) * 0.25
    shade += _dither(ctx, 0.5, seed + 3)
    s.use_ramp(P["roof_tile"], shade=shade)
    tx = ctx.texel
    grout = (fx < tx) | (fz < tx)
    near = ~grout & ((fx < 2 * tx) | (fz < 2 * tx))
    rim = ~grout & ((fx > tsz - tx) | (fz > tsz - tx))
    s.shade[near] -= 0.8
    s.shade[rim] += 0.8
    corner = (np.minimum(fx, tsz - fx) < 0.04) & (np.minimum(fz, tsz - fz) < 0.04) & \
             (noise.rand_cells(tid, seed + 4) > 0.75)
    s.shade[corner] -= 1.2
    s.use_ramp(P["grout"], mask=grout, shade=np.full(ctx.N, 2.0) + _dither(ctx, 0.8, seed + 5))
    path = smoothstep(0.2, 0.7, ctx.fbm(np.array([0.6, 1.0, 0.3]), 3, seed + 6))
    s.rough = np.where(grout, 0.9, 0.18 + path * 0.25 + ctx.rand(seed + 7) * 0.03)
    s.height = np.where(grout, -0.003, 0.0) - corner * 0.002 + rim * 0.0003
    return s


def stone_slate(ctx, seed=1031):
    """Field: polished dark green-grey slate in 1 x 0.5 m slabs, broken
    bond, faint bedding veins. Tile 4 x 4 m."""
    u, v = ctx.uvm[:, 0], ctx.uvm[:, 1]
    row = np.floor(v / 0.5 + 1e-9).astype(np.int64)
    shift = noise.rand_cells(np.mod(row, 8), seed) * 0.75
    shift = np.floor(shift / 0.25) * 0.25
    col = np.floor((u + shift) / 1.0 + 1e-9).astype(np.int64)
    fx = (u + shift) - col
    fz = v - row * 0.5
    sid = np.mod(row, 8) * 8 + np.mod(col, 4)
    tone = noise.rand_cells(sid, seed + 1) - 0.5
    s = Surface(ctx.N)
    vein = np.abs(ctx.fbm(np.array([1.2, 1.2, 5.0]), 3, seed + 2)) < 0.02
    shade = 3.2 + tone * 1.2 + ctx.fbm(2.0, 3, seed + 3) * 0.7 + _dither(ctx, 0.4, seed + 4) + vein * 1.2
    s.use_ramp(P["slate"], shade=shade)
    tx = ctx.texel
    grout = (fx < tx) | (fz < tx)
    s.use_ramp(P["grout"], mask=grout, shade=np.full(ctx.N, 1.6))
    s.rough = np.where(grout, 0.9, 0.12 + smoothstep(0.2, 0.7, ctx.fbm(0.8, 3, seed + 7)) * 0.2)
    s.height = np.where(grout, -0.003, 0.0)
    return s


_COFFER = {}


def _coffer_canvas():
    """Painted coffered ceiling, 64 x 64 px (1 x 1 m): green ribs with a
    gold bead, red-orange corner clouds, a deep blue field with a gold
    lotus roundel."""
    if "c" in _COFFER:
        return _COFFER["c"]
    I = AP.INK
    c = AP.blank(64, 64, I["blue"])
    c[0:7, :] = I["green"]
    c[57:64, :] = I["green"]
    c[:, 0:7] = I["green"]
    c[:, 57:64] = I["green"]
    c[3, :] = I["gold"]
    c[60, :] = I["gold"]
    c[:, 3] = I["gold"]
    c[:, 60] = I["gold"]
    for cx, cy in ((0, 0), (64, 0), (0, 64), (64, 64)):
        AP.ellipse(c, cx, cy, 6, 6, I["gold"])                       # nail heads at the crossings
    c[7:9, 7:57] = I["white"]
    c[55:57, 7:57] = I["white"]
    c[7:57, 7:9] = I["white"]
    c[7:57, 55:57] = I["white"]
    for cx, cy, fl in ((14, 14, False), (50, 14, True), (14, 50, False), (50, 50, True)):
        m = AP.ruyi(c, cx, cy, 8, I["orange"], flip=fl)
        AP.outline(c, m, I["red"], only_empty=False)
    AP.ring(c, 32, 32, 15, 17, I["gold"])
    AP.lotus_roundel(c, 32, 32, 13, petal=I["gold"], petal2=I["ochre"], heart=I["red"], line_code=I["dk_red"])
    _COFFER["c"] = c
    return c


def asia_coffers(ctx, seed=1041):
    """Field: the painted coffered ceiling (tianhua), 1 m panels. Tile 4 x 4 m."""
    s = Surface(ctx.N)
    s.use_ramp(P["hinoki"], shade=4.0 + ctx.fbm(3.0, 3, seed) * 0.6)
    s.rough = np.full(ctx.N, 0.8)
    s, codes = paint(ctx, s, _coffer_canvas(), flake=0.15, relief=0.0, seed=seed + 1)
    rib = codes == AP.INK["green"]
    s.height = s.height + rib * 0.006
    s.shade -= (ctx.fbm(1.0, 3, seed + 2) > 0.3) * 0.6      # soot from centuries of incense
    return s


def asia_lacquer(ctx, seed=1051):
    """Field: cinnabar lacquer (column shafts, reveals). Tile 2 x 2 m."""
    return lacquer(ctx, seed, wear=0.3)


def asia_lacquer_black(ctx, seed=1053):
    """Field: black lacquer. Tile 2 x 2 m."""
    return lacquer(ctx, seed, ramp="lacquer_black", center=3.0, under="lacquer_red", wear=0.15, crackle=0.4)


def boards_dark(ctx, seed=1061):
    """Field: a dark polished board floor (the armour hall, the Korean
    room): 0.2 m boards along x, staggered butt joints. Tile 2 x 2 m."""
    u, v = ctx.uvm[:, 0], ctx.uvm[:, 1]
    bw = 0.2
    row = np.floor(v / bw + 1e-9).astype(np.int64)
    L = 2.0
    off = noise.rand_cells(np.mod(row, 10), seed) * L
    off = np.floor(off / 0.25) * 0.25
    fx = np.mod(u + off, L)
    fz = v - row * bw
    tone = noise.rand_cells(np.mod(row, 10), seed + 1) - 0.5
    r1 = noise.rand_cells(np.mod(row, 10), seed + 2) * 30.0
    q = np.stack([fx + r1, np.zeros(ctx.N), fz + r1 * 0.37], axis=1)
    plain = type(ctx)(q, ctx.n, np.tile([1.0, 0.0, 0.0], (ctx.N, 1)), np.tile([0.0, 0.0, 1.0], (ctx.N, 1)),
                      ctx.texel, ctx.seed, None)
    s = _wood_core(plain, P["asia_cedar"], 4.4, seed + 3, ring_freq=12.0, contrast=0.8)
    s.shade += tone * 1.6
    tx = ctx.texel
    gap = (fz < tx) | (fx < tx)
    s.shade[gap] = 0.4
    s.rough = np.where(gap, 0.9, 0.28 + smoothstep(0.2, 0.7, ctx.fbm(np.array([0.5, 1.0, 0.3]), 3, seed + 4)) * 0.3)
    s.height = s.height - gap * 0.002
    return s


def garden_wall(ctx, seed=1071):
    """Field: the garden's earthen wall (tsuiji): ochre clay plaster with
    straw flecks, rammed courses showing faintly, rain streaks from the
    coping, a darker splash zone at the foot. Tile 4 x 3 m."""
    s = Surface(ctx.N)
    v = ctx.uvm[:, 1]
    course = np.abs(np.mod(v, 0.15) - 0.075) < 0.006
    straw = (ctx.rand(seed + 1) > 0.985) & (ctx.fbm(3.0, 2, seed) > -0.2)
    shade = 5.0 + ctx.fbm(1.5, 4, seed + 2) * 0.6 + ctx.fbm(9.0, 2, seed + 3) * 0.3 + _dither(ctx, 0.25, seed + 4)
    shade -= course * 0.5 * (ctx.fbm(2.0, 2, seed + 5) > 0.0)
    shade += straw * 1.6
    streak = smoothstep(0.25, 0.8, ctx.fbm(np.array([5.0, 5.0, 0.4]), 3, seed + 6))
    shade -= streak * 0.9
    shade -= smoothstep(0.5, 0.0, np.mod(v, 3.0)) * 1.4
    s.use_ramp(P["earth_wall"], shade=shade)
    s.rough = np.full(ctx.N, 0.93)
    s.height = ctx.fbm(10.0, 3, seed + 7) * 0.0015 + straw * 0.0003
    return s


def tatami_field(ctx, seed=1081):
    """Field: tatami 2 x 1 m mats in a basket bond with black borders: tile
    4 x 2 m (two mats lying along x on the left half, two standing along
    y on the right half)."""
    u, v = ctx.uvm[:, 0], ctx.uvm[:, 1]
    uu = np.mod(u, 4.0)
    vv = np.mod(v, 2.0)
    left = uu < 2.0
    # local coordinates in the mat: a = along its length, b = across
    a = np.where(left, uu, vv)
    b = np.where(left, np.mod(vv, 1.0), np.mod(uu - 2.0, 1.0))
    along_u = left
    s = tatami(ctx, seed, along_u=True)
    s2 = tatami(ctx, seed + 7, along_u=False)
    s.merge(_select(s2, ~left), ~left)
    tx = ctx.texel
    border = (b < 0.05) | (b > 1.0 - 0.05)
    s.use_ramp(P["pig_black"], mask=border, shade=np.full(ctx.N, 2.6) + ((np.floor(a / tx) % 4) == 0) * 0.8)
    seam = (a < tx) | (b < tx)
    s.shade[seam] = 0.2
    s.height = s.height + border * 0.001 - seam * 0.003
    s.rough = np.where(border, 0.6, s.rough)
    return s


MATERIALS = {
    "asia_plaster": asia_plaster,
    "asia_plaster_dark": asia_plaster_dark,
    "asia_band": asia_band,
    "tiles_golden": tiles_golden,
    "stone_slate": stone_slate,
    "asia_coffers": asia_coffers,
    "asia_lacquer": asia_lacquer,
    "asia_lacquer_black": asia_lacquer_black,
    "boards_dark": boards_dark,
    "gravel_raked": gravel_raked,
    "gravel_plain": gravel_plain,
    "garden_wall": garden_wall,
    "tatami": tatami_field,
    "cherry_blossom": cherry_blossom,
    "thatch": thatch,
}
