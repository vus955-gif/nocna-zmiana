"""Material library: hand-picked colour ramps + procedural per-texel functions.

Every function takes a painter.Ctx and returns a painter.Surface. The same
functions paint tileable textures (flat plane, periodic noise) and baked model
atlases (texel positions on the mesh, edge distances, ambient occlusion), so a
material looks the same everywhere in the game.

Palette rule: each material owns 1-3 ramps of 6-10 colours, ordered dark ->
light. Shading happens by moving along a ramp (index steps), never by
free-form colour maths, which keeps the pixel-art palette limited and rich.
"""
import numpy as np

from . import noise
from .painter import Surface, combine


def hexramp(*hexes):
    return np.array([[int(h[i:i + 2], 16) / 255.0 for i in (1, 3, 5)] for h in hexes])


def smoothstep(a, b, x):
    t = np.clip((x - a) / (b - a), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


# --------------------------------------------------------------------------
# palettes (sRGB, dark -> light)
# --------------------------------------------------------------------------
P = {
    "marble_white": hexramp("#3f434d", "#565a65", "#6f737d", "#898c95", "#a2a5ac", "#babcc1",
                            "#cfd0d3", "#dfdfdf", "#ecebe7", "#f6f4ef"),
    "marble_white_vein": hexramp("#2f333e", "#434855", "#5a606d", "#737987", "#8c919d"),
    "marble_dark": hexramp("#080b0b", "#0d1312", "#121b19", "#172320", "#1d2c28", "#243631",
                           "#2d423c", "#385047"),
    "marble_dark_vein": hexramp("#415a50", "#5b766a", "#7c978a", "#a3b8ad", "#c9d6cf"),
    "marble_red": hexramp("#1e0707", "#2e0c0b", "#411310", "#561b16", "#6c251d", "#823126",
                          "#983f31", "#ad513f"),
    "marble_red_vein": hexramp("#5a2c24", "#6f3d33", "#855045", "#9b665a", "#b0806f"),
    "grout": hexramp("#101012", "#19191c", "#232327", "#2e2e33"),
    "wood_dark": hexramp("#110a08", "#1a0f0b", "#24150f", "#2f1b13", "#3b2218", "#482a1d",
                         "#563322", "#653c28", "#77482f", "#8a5637"),
    "wood_oak": hexramp("#261709", "#35200e", "#462b13", "#583718", "#6b431e", "#7e5025",
                        "#915e2d", "#a46d37", "#b67d42"),
    "brass": hexramp("#241a0a", "#3a2a0f", "#523b14", "#6d4f1a", "#886521", "#a37c2b",
                     "#bb9338", "#d0ab4c", "#e2c46c", "#f1dd98", "#fbf1cd"),
    "brass_tarnish": hexramp("#1b1a10", "#2a2915", "#3a3a1d", "#4b4b26"),
    "gold": hexramp("#26170a", "#3f260d", "#5d3810", "#7e4c14", "#a0621a", "#bd7b24",
                    "#d49632", "#e5b24a", "#f1cd70", "#f9e6a8"),
    "bole": hexramp("#3a1209", "#58200f", "#732f17"),
    "velvet": hexramp("#140205", "#210408", "#30060c", "#410a11", "#530e17", "#67131d",
                      "#7c1924", "#92212c", "#a82b34"),
    "stone": hexramp("#2e2b27", "#3d3934", "#4d4842", "#5e5850", "#70695f", "#827a6f",
                     "#948c80", "#a69e91", "#b8b0a3"),
    "plaster": hexramp("#4f4b44", "#625d55", "#767067", "#8a847a", "#9e978c", "#b1ab9f",
                       "#c3bdb1", "#d3cdc1", "#e0dbcf"),
    "wallpaper": hexramp("#0a1512", "#0f1c18", "#13231e", "#182a24", "#1d312b", "#233932",
                         "#2a423a"),
    "wallpaper_motif": hexramp("#2b3a2c", "#3b4a33", "#4f5c3b", "#667045", "#7f8552", "#999a62"),
    "iron": hexramp("#0b0c0e", "#121417", "#191c20", "#21252a", "#2b3036", "#363c43",
                    "#434a52", "#535b64"),
    "rust": hexramp("#2a120a", "#40200f", "#573016"),
    "glass": hexramp("#b8c7c4", "#cbd8d5", "#dde8e6", "#eef5f4"),
    "wax": hexramp("#4b2f25", "#633d2f", "#7c4f3b", "#956249", "#ad7759", "#c38d6b",
                   "#d5a47f", "#e3bb97", "#eed0b1", "#f6e2ca", "#fbf0e1"),
    "wax_blush": hexramp("#7a3c33", "#944c40", "#ad5e4f", "#c37362", "#d38b78", "#e1a490"),
    "wax_lip": hexramp("#5b2322", "#76302c", "#8f3f37", "#a85246"),
    "hair": hexramp("#0e0908", "#17100d", "#211712", "#2c1f18", "#39291f", "#473428"),
    "eye": hexramp("#0a0a0c", "#1d2530", "#34485a", "#e8e4da"),
    "coat": hexramp("#05060f", "#090c19", "#0e1224", "#131931", "#1a2240", "#222c51",
                    "#2c3863", "#384676"),
    "cloth_white": hexramp("#46443f", "#5d5a54", "#76726a", "#8f8a81", "#a7a298", "#bdb8ad",
                           "#d0cbc0", "#e0dcd2", "#ece9e0"),
    "cloth_red": hexramp("#220506", "#35080a", "#4b0c0f", "#621115", "#7a171b", "#931f22",
                         "#aa2b2b", "#bf3a36"),
    "leather": hexramp("#060607", "#0c0c0e", "#131316", "#1b1b1f", "#24242a", "#2f2f37",
                       "#3c3c46", "#4b4b57"),
    "crystal": hexramp("#1c0405", "#2d0708", "#410c0d", "#571213", "#6e1a1a", "#862422",
                       "#9e302c", "#b73f38", "#cf5548"),
    "lamp_warm": hexramp("#6e4a2a", "#9a6c3e", "#c49257", "#e2b879", "#f3d6a2", "#fcecd0"),
    "lamp_red": hexramp("#3a0303", "#5c0606", "#850b0a", "#b01410", "#d8261b", "#f24a35"),
    "canvas_back": hexramp("#3a3228", "#4e4436", "#625745"),
    "bronze": hexramp("#0f130f", "#172019", "#1f2c23", "#28392e", "#324839", "#3e5846",
                      "#4c6a55", "#5e7f67", "#76977e"),
    "bronze_metal": hexramp("#3a2411", "#56361a", "#744b23", "#93622f", "#b07b3e"),
    # --- stage 2: creatures, armour, fossils, weapons, props ---------------
    "fur": hexramp("#1b1917", "#2a2724", "#3b3632", "#4d4640", "#60574e", "#74695d", "#897c6c",
                   "#9e907e", "#b3a592", "#c7bba8"),
    "fur_pale": hexramp("#4b453c", "#635c50", "#7c7465", "#958d7b", "#aea591", "#c4bca8", "#d7d0be"),
    "hide": hexramp("#2e1f17", "#45301f", "#5c4029", "#735236", "#8a6545", "#a07a58"),
    "excelsior": hexramp("#3d2d12", "#5a441b", "#795d26", "#977733", "#b39245", "#cbab5c"),
    "eye_amber": hexramp("#140a02", "#3d1f05", "#6e3a0a", "#a35b12", "#d0861f", "#efb13f", "#ffe08a"),
    "ivory": hexramp("#3a3024", "#574a37", "#74664d", "#928365", "#afa07f", "#c9bb99", "#dfd3b3",
                     "#efe7cf"),
    "gum": hexramp("#1a0606", "#2e0b0b", "#451312", "#5d1c19", "#772822", "#92372e"),
    "steel": hexramp("#0f1114", "#1a1d22", "#262a31", "#333842", "#424854", "#535a67", "#666e7b",
                     "#7b8390", "#929aa6", "#aab1bb", "#c4cad2", "#dfe3e8"),
    "steel_blued": hexramp("#07080c", "#0c0f16", "#121722", "#19202e", "#212a3b", "#2b3649", "#364357",
                           "#445266", "#566476"),
    "paint_ochre": hexramp("#2e1e06", "#4a310a", "#694610", "#8a5d17", "#a9761f", "#c69029", "#dcab3c",
                           "#ecc65a"),
    "ember": hexramp("#1a0302", "#3d0703", "#6b1004", "#9c1e06", "#cc360b", "#f05a1a", "#ff8a3a",
                     "#ffc27a"),
    "bone": hexramp("#120b06", "#1f140c", "#2d1d11", "#3c2817", "#4d341e", "#5f4126", "#724f2f",
                    "#865e39", "#9a6f45", "#ad8153", "#bf9464"),
    "tooth_fossil": hexramp("#0b0806", "#16100b", "#221a12", "#30251a", "#3f3223", "#50412d"),
    "walnut_stock": hexramp("#1a0e08", "#29160c", "#3a1f10", "#4b2915", "#5d331b", "#6f3e21", "#814928",
                            "#935530", "#a4623a"),
    "bakelite": hexramp("#120806", "#1e0d09", "#2b130d", "#3a1a11", "#4a2216", "#5b2b1c", "#6d3524"),
    "plastic_yellow": hexramp("#3a2a02", "#5c4304", "#806008", "#a67e0d", "#c99b14", "#e3b521",
                              "#f4cd3a", "#fde170"),
    "plastic_black": hexramp("#08080a", "#0f0f12", "#16161a", "#1e1e23", "#27272d", "#313138", "#3c3c44"),
    "uniform": hexramp("#07090d", "#0c1016", "#121820", "#19202b", "#212a37", "#2a3544", "#344152",
                       "#3f4d60"),
    "cardboard": hexramp("#2b1d0f", "#3f2c17", "#54391f", "#6a4a29", "#805c34", "#966f41", "#aa824f",
                         "#bc955f"),
    "enamel_white": hexramp("#4a4a46", "#62625d", "#7c7c76", "#96968f", "#b0afa8", "#c8c7bf", "#dcdbd3",
                            "#eceae3"),
    "porcelain": hexramp("#3f3a31", "#5a5446", "#78715f", "#978f7a", "#b3ab94", "#cbc4ad", "#dfd9c4",
                         "#eeead9"),
    "paint_green": hexramp("#06100b", "#0b1a12", "#11251a", "#183123", "#203e2d", "#294c38", "#335b44",
                           "#3f6b51"),
    "paint_olive": hexramp("#151812", "#1f231b", "#2a2f25", "#353b2f", "#41483a", "#4e5646", "#5c6553",
                           "#6b7461", "#7b8470"),
    "plastic_beige": hexramp("#3b352b", "#534b3e", "#6b6252", "#847a67", "#9c927c", "#b3a990", "#c7bea5",
                             "#d8d0b8"),
    "crt_glass": hexramp("#050706", "#0a0e0c", "#111714", "#1a211d", "#252e29"),
    "led_green": hexramp("#0a2a0a", "#145214", "#1f7a1f", "#36a336", "#62cc55", "#a6f08c"),
    "phosphor": hexramp("#020803", "#051a08", "#0a300f", "#124a18", "#1e6a26", "#2f8c38", "#4bb050",
                        "#7fd67a", "#c2f5b5"),
    "crt_grey": hexramp("#05070a", "#0c1016", "#151b23", "#202833", "#2d3744", "#3e4957", "#525e6d",
                        "#6a7686", "#8894a2", "#a9b3bf"),
    "dust": hexramp("#3a2408", "#6b4410", "#a0691c", "#d09a33", "#f2c65a", "#fde79a", "#fffbe0"),
    # --- stage 3: gatling, flare gun, raptor, portraits --------------------
    "plastic_orange": hexramp("#2a0f02", "#4a1a03", "#6e2705", "#933507", "#b8450a", "#d9570e", "#f06d1a",
                              "#fb8a36", "#ffab62", "#ffcb96"),
    "paint_red": hexramp("#1e0403", "#360806", "#520c09", "#6e110c", "#8c1810", "#aa2116", "#c42d1e", "#d9412c",
                         "#e85d45"),
    "flare": hexramp("#3a0508", "#7a0a10", "#b8141a", "#e8322a", "#ff6a4a", "#ff9d7d", "#ffd0c0", "#fff2ec"),
    "webbing": hexramp("#1f1c10", "#2f2a18", "#3f3921", "#50492b", "#625a36", "#756c43", "#887f51", "#9b9261"),
    "copper": hexramp("#2a0f06", "#46190a", "#65250f", "#853415", "#a3461d", "#bd5b28", "#d27437", "#e3924f",
                      "#f0b27a"),
}


def _dither(ctx, amount=0.8, seed=0):
    return (ctx.rand(seed) - 0.5) * amount


def _age(ctx, s, cavity=2.0, ao=3.0, edge=1.5, edge_w=1.0):
    """Common hand-painted finishing: bright chipped edges, dark cavities and AO."""
    s.shade += ctx.edge(edge_w) * edge + ctx.edge(edge_w + 1.0) * edge * 0.35
    s.shade -= ctx.cavity(3.0) * cavity
    s.shade -= (1.0 - ctx.ao) * ao


def _grain_frame(ctx):
    """Axis along the island's long side (wood grain / brushing direction)."""
    lu = ctx.long_u[:, None]
    along = np.where(lu, ctx.t, ctx.b)
    across = np.where(lu, ctx.b, ctx.t)
    return along, across


# --------------------------------------------------------------------------
# stone-like
# --------------------------------------------------------------------------

def _marble_core(ctx, base, vein, center, light_veins, seed, polish=0.14, vein_scale=1.0, space="uv", grain=1.0):
    """space "uv": veins drawn in the surface's own metre-UV plane (crisp, even
    width on hard surfaces); "3d": solid texture (continuous over organic
    shapes, but veins widen where the surface runs along a vein sheet).
    grain scales the cloudiness and per-texel dither (lower = calmer stone,
    for statues seen up close)."""
    s = Surface(ctx.N)
    if space == "uv" and not ctx.tile:
        q = np.stack([ctx.uvm[:, 0], np.zeros(ctx.N), ctx.uvm[:, 1]], axis=1) + ctx.part[:, None] * 13.7
    else:
        q = ctx.p
    warp = np.stack([ctx.fbm(0.7, 3, seed + 1, p=q), ctx.fbm(0.7, 3, seed + 2, p=q),
                     ctx.fbm(0.7, 3, seed + 3, p=q)], axis=1)
    cloud = ctx.fbm(1.2, 4, seed + 4, p=q)
    # veins are the zero-contours of domain-warped noise: thin, meandering, closed
    f1 = np.abs(ctx.fbm(0.8 * vein_scale, 4, seed + 5, p=q + warp * 0.7))
    f2 = np.abs(ctx.fbm(2.1 * vein_scale, 3, seed + 6, p=q + warp * 0.35))
    k = ctx.texel * 64.0          # vein width stays constant in texels at any density
    v1 = 1.0 - smoothstep(0.0, 0.05 * k, f1)
    halo = 1.0 - smoothstep(0.0, 0.2 * k, f1)
    v2 = (1.0 - smoothstep(0.0, 0.022 * k, f2)) * (ctx.fbm(1.5, 2, seed + 7) > -0.1)
    shade = center + cloud * 1.3 * grain + _dither(ctx, 0.9 * grain, seed)
    if light_veins:
        s.use_ramp(base, shade=shade + halo * 0.5 + v2 * 1.6)
        vein_mask = v1 > 0.7
        s.use_ramp(vein, mask=vein_mask, shade=0.6 + v1 * 1.6 + cloud * 0.8 + _dither(ctx, 0.8, seed + 8))
    else:
        s.use_ramp(base, shade=shade - halo * 0.7 - v1 * 1.9 - v2 * 1.0)
        deep = v1 > 0.92
        s.use_ramp(vein, mask=deep, shade=np.full(ctx.N, 2.2) + cloud * 1.0 + _dither(ctx, 0.8, seed + 8))
    s.rough = polish + np.clip(ctx.fbm(3.0, 3, seed + 8), 0, 1) * 0.12 + ctx.rand(seed + 9) * 0.03
    return s


def marble_white(ctx, seed=11, space="uv"):
    s = _marble_core(ctx, P["marble_white"], P["marble_white_vein"], 6.3, False, seed, polish=0.18, space=space)
    _age(ctx, s, cavity=2.5, ao=4.0, edge=1.2)
    return s


def marble_statuary(ctx, seed=17):
    """Fine white statuary marble for carved figures: calm, few veins, the
    form is modelled by AO and curvature (polished highs, grimy crevices)."""
    s = _marble_core(ctx, P["marble_white"], P["marble_white_vein"], 6.9, False, seed, polish=0.22,
                     space="3d", grain=0.4, vein_scale=0.7)
    s.shade += np.clip(ctx.curv, 0, 1) * 1.2 - np.clip(-ctx.curv, 0, 1) * 1.8
    s.shade -= ctx.cavity(3.0) * 2.0 + (1.0 - ctx.ao) * 4.5
    return s


def marble_dark(ctx, seed=23, space="uv"):
    s = _marble_core(ctx, P["marble_dark"], P["marble_dark_vein"], 3.3, True, seed, polish=0.12, space=space)
    _age(ctx, s, cavity=1.5, ao=2.5, edge=1.5)
    return s


def marble_red(ctx, seed=37, space="uv"):
    s = _marble_core(ctx, P["marble_red"], P["marble_red_vein"], 4.0, False, seed, polish=0.16, space=space)
    _age(ctx, s, cavity=1.5, ao=2.5, edge=1.2)
    return s


def marble_floor(ctx, seed=5, tile=1.0):
    """Checkerboard of polished white and dark-green marble slabs, 1 m, grouted."""
    x = ctx.p[:, 0]
    z = ctx.p[:, 2]
    ix = np.floor(x / tile + 1e-9).astype(np.int64)
    iz = np.floor(z / tile + 1e-9).astype(np.int64)
    fx = x - ix * tile
    fz = z - iz * tile
    dark = ((ix + iz) % 2) == 1
    tid = np.mod(ix, 64) * 64 + np.mod(iz, 64)
    off = np.stack([noise.rand_cells(tid, seed + k) * 97.0 for k in range(3)], axis=1)
    tone = noise.rand_cells(tid, seed + 7) - 0.5
    sub_p = ctx.p + off
    # evaluate the marble in per-slab offset space, without tiling (slab edges hide seams)
    plain = type(ctx)(sub_p, ctx.n, ctx.t, ctx.b, ctx.texel, ctx.seed, None)
    white = _marble_core(plain, P["marble_white"], P["marble_white_vein"], 5.9, False, seed + 100, polish=0.07)
    darks = _marble_core(plain, P["marble_dark"], P["marble_dark_vein"], 3.4, True, seed + 200, polish=0.05)
    s = Surface(ctx.N)
    s.merge(_select(white, ~dark), ~dark)
    s.merge(_select(darks, dark), dark)
    s.shade += tone * 1.2
    # grout lines (1 texel) with a soft bevel into the slab
    edge_d = np.minimum(np.minimum(fx, tile - fx), np.minimum(fz, tile - fz))
    grout = (fx < ctx.texel) | (fz < ctx.texel)
    near = (edge_d < 2.0 * ctx.texel) & ~grout
    s.shade[near & ~dark] -= 0.8
    s.shade[near & dark] += 0.6
    gid = s.use_ramp(P["grout"], mask=grout, shade=np.full(ctx.N, 1.5) + _dither(ctx, 1.0, 3))
    s.height = np.where(grout, -0.003, 0.0) + np.where(near, -0.0008, 0.0)
    scuff = smoothstep(0.15, 0.7, ctx.fbm(2.2, 4, seed + 9))
    s.rough = np.where(grout, 0.85, s.rough + scuff * 0.22)
    s.metal[:] = 0.0
    return s


def _select(s, mask):
    """Restricts a full-size Surface to mask (for merging)."""
    out = Surface(int(mask.sum()))
    out.ramps = s.ramps
    out.ramp_id = s.ramp_id[mask]
    out.shade = s.shade[mask]
    out.rough = s.rough[mask]
    out.metal = s.metal[mask]
    out.height = s.height[mask]
    return out


def stone(ctx, seed=41):
    s = Surface(ctx.N)
    base = 4.6 + ctx.fbm(1.8, 4, seed) * 1.5 + ctx.fbm(7.0, 2, seed + 1) * 0.5 + _dither(ctx, 0.55, seed)
    f1, f2, cid = ctx.worley(9.0, seed + 2)
    pits = ((f1 < 0.09) & (cid > 0.55)).astype(np.float64)
    base -= pits * 1.4
    s.use_ramp(P["stone"], shade=base)
    chip = ctx.edge_soft(3.0) * (ctx.fbm(9.0, 2, seed + 3) > 0.22)
    s.shade -= chip * 1.6
    s.shade += ctx.edge(1.0) * 1.2 * (1 - chip)
    s.shade -= ctx.cavity(3.0) * 2.0 + (1.0 - ctx.ao) * 3.0
    s.height = -pits * 0.0015 - chip * 0.003 + ctx.fbm(6.0, 3, seed + 4) * 0.0008
    s.rough = 0.78 + ctx.rand(seed + 5) * 0.1
    return s


def plaster(ctx, seed=53):
    s = Surface(ctx.N)
    base = 5.4 + ctx.fbm(2.5, 4, seed) * 0.9 + ctx.fbm(12.0, 2, seed + 1) * 0.5 + _dither(ctx, 0.8, seed)
    crack = (np.abs(ctx.fbm(1.3, 4, seed + 2)) < 0.012) & (ctx.fbm(0.7, 2, seed + 6) > 0.25)
    base -= crack * 1.6
    s.use_ramp(P["plaster"], shade=base)
    _age(ctx, s, cavity=2.2, ao=3.5, edge=1.0)
    if not ctx.tile:
        z = ctx.up()
        s.shade -= smoothstep(0.35, 0.0, z) * 1.2 * (0.6 + ctx.rand(seed + 3) * 0.6)
    s.height = ctx.fbm(8.0, 3, seed + 4) * 0.0012 - crack * 0.001
    s.rough = 0.86 + ctx.rand(seed + 5) * 0.08
    return s


# --------------------------------------------------------------------------
# wood
# --------------------------------------------------------------------------

def _wood_core(ctx, ramp, center, seed, ring_freq=9.0, contrast=1.0):
    s = Surface(ctx.N)
    along, across = _grain_frame(ctx)
    a = np.sum(ctx.p * along, axis=1)
    c = np.sum(ctx.p * across, axis=1)
    d = np.sum(ctx.p * ctx.n, axis=1)
    # (a, d, c) keeps x/z order for tileable contexts (grain along x there)
    q = np.stack([a, d, c], axis=1)
    fib = ctx.fbm(np.array([1.5, 30.0, 30.0]), 3, seed, p=q)
    wob = ctx.fbm(np.array([0.7, 2.0, 2.0]), 3, seed + 1, p=q)
    band = np.mod(c * ring_freq + d * ring_freq + wob * 1.8, 1.0)
    ring = smoothstep(0.72, 0.93, band)
    shade = center + fib * 1.4 * contrast - ring * 1.4 * contrast + _dither(ctx, 0.7, seed + 2)
    s.use_ramp(ramp, shade=shade)
    s.height = ring * -0.0006 + fib * 0.0004
    return s


def wood_dark(ctx, seed=61):
    """Varnished walnut: wainscoting, case bases, frames of benches."""
    s = _wood_core(ctx, P["wood_dark"], 4.6, seed)
    _age(ctx, s, cavity=2.0, ao=3.0, edge=1.6)
    s.rough = 0.34 + np.clip(ctx.fbm(3.0, 3, seed + 5), 0, 1) * 0.25 + ctx.cavity(3.0) * 0.3
    return s


def wood_oak(ctx, seed=67):
    s = _wood_core(ctx, P["wood_oak"], 4.5, seed, ring_freq=7.0)
    _age(ctx, s, cavity=1.8, ao=3.0, edge=1.4)
    s.rough = 0.45 + np.clip(ctx.fbm(3.0, 3, seed + 5), 0, 1) * 0.2
    return s


def parquet(ctx, seed=71, block=0.5, planks=4):
    """Basket-weave oak parquet: 0.5 m squares of 4 planks, alternating direction."""
    x = ctx.p[:, 0]
    z = ctx.p[:, 2]
    bx = np.floor(x / block + 1e-9).astype(np.int64)
    bz = np.floor(z / block + 1e-9).astype(np.int64)
    fx = x - bx * block
    fz = z - bz * block
    horiz = ((bx + bz) % 2) == 0
    w = block / planks
    across = np.where(horiz, fz, fx)
    along = np.where(horiz, fx, fz)
    pk = np.floor(across / w + 1e-9).astype(np.int64)
    pid = (np.mod(bx, 32) * 32 + np.mod(bz, 32)) * 8 + pk
    tone = noise.rand_cells(pid, seed) - 0.5
    off = noise.rand_cells(pid, seed + 1) * 50.0
    # grain frame per plank
    t = np.where(horiz[:, None], np.array([1.0, 0, 0]), np.array([0, 0, 1.0]))
    b = np.where(horiz[:, None], np.array([0, 0, 1.0]), np.array([1.0, 0, 0]))
    plain = type(ctx)(ctx.p + off[:, None], ctx.n, t, b, ctx.texel, ctx.seed, None)
    s = _wood_core(plain, P["wood_oak"], 4.4, seed + 2, ring_freq=11.0, contrast=0.8)
    s.shade += tone * 2.0
    gap = (np.mod(across, w) < ctx.texel) | (along < ctx.texel)
    s.shade[gap] = 0.6
    s.height = s.height + np.where(gap, -0.002, 0.0)
    s.rough = 0.42 + tone * 0.1 + np.clip(ctx.fbm(2.0, 3, seed + 3), 0, 1) * 0.25
    s.rough[gap] = 0.9
    return s


# --------------------------------------------------------------------------
# metals
# --------------------------------------------------------------------------

def brass(ctx, seed=79, ramp="brass", tarnish_amount=2.2, grain=0.8):
    s = Surface(ctx.N)
    along, across = _grain_frame(ctx)
    a = np.sum(ctx.p * along, axis=1)
    c = np.sum(ctx.p * across, axis=1)
    d = np.sum(ctx.p * ctx.n, axis=1)
    q = np.stack([a, d, c], axis=1)
    brushed = ctx.fbm(np.array([2.0, 60.0, 60.0]), 2, seed, p=q)
    tarnish = smoothstep(0.05, 0.6, ctx.fbm(2.5, 4, seed + 1))
    shade = 6.0 + brushed * 0.9 - tarnish * tarnish_amount + _dither(ctx, grain, seed + 2)
    shade += ctx.edge(1.0) * 3.0 + ctx.edge(2.0) * 1.0
    shade -= ctx.cavity(3.0) * 3.5 + (1.0 - ctx.ao) * 4.0
    s.use_ramp(P[ramp], shade=shade)
    dark = (ctx.cavity(2.0) > 0.5) & (ctx.rand(seed + 3) > 0.4)
    s.use_ramp(P["brass_tarnish"], mask=dark, shade=np.full(ctx.N, 2.0))
    s.metal = np.where(dark, 0.4, 1.0)
    s.rough = 0.24 + tarnish * 0.25 - ctx.edge(1.0) * 0.1 + ctx.rand(seed + 4) * 0.04
    s.rough = np.where(dark, 0.7, s.rough)
    s.height = brushed * 0.0002
    return s


def gold(ctx, seed=83):
    """Gilded frames: gold leaf, worn through to red bole on some edges."""
    s = brass(ctx, seed, ramp="gold", tarnish_amount=1.0, grain=0.5)
    s.shade += 0.6
    worn = (ctx.edge_soft(2.5) > 0.3) & (ctx.fbm(14.0, 2, seed + 5) > 0.3)
    s.use_ramp(P["bole"], mask=worn, shade=np.full(ctx.N, 1.0) + _dither(ctx, 1.5, seed + 6))
    s.metal = np.where(worn, 0.0, s.metal)
    s.rough = np.where(worn, 0.6, s.rough)
    return s


def iron(ctx, seed=89):
    s = Surface(ctx.N)
    base = 3.2 + ctx.fbm(3.0, 3, seed) * 0.9 + _dither(ctx, 0.8, seed)
    s.use_ramp(P["iron"], shade=base)
    _age(ctx, s, cavity=1.5, ao=2.5, edge=2.0)
    rust = (ctx.cavity(3.0) > 0.2) & (ctx.fbm(6.0, 3, seed + 1) > 0.15)
    s.use_ramp(P["rust"], mask=rust, shade=np.full(ctx.N, 1.0) + _dither(ctx, 1.5, seed + 2))
    s.metal = np.where(rust, 0.0, 0.55)
    s.rough = np.where(rust, 0.85, 0.5 + ctx.rand(seed + 3) * 0.1)
    return s


# --------------------------------------------------------------------------
# fabrics
# --------------------------------------------------------------------------

def velvet(ctx, seed=97):
    s = Surface(ctx.N)
    pile = ctx.fbm(40.0, 2, seed) * 0.7 + ctx.fbm(4.0, 3, seed + 1) * 0.9
    shade = 4.2 + pile + _dither(ctx, 0.9, seed + 2)
    shade += ctx.edge_soft(3.0) * 2.0 + np.clip(ctx.curv, 0, 1) * 2.0
    shade -= ctx.cavity(4.0) * 2.5 + (1.0 - ctx.ao) * 4.0 + np.clip(-ctx.curv, 0, 1) * 2.0
    s.use_ramp(P["velvet"], shade=shade)
    s.rough = 0.92 + ctx.rand(seed + 3) * 0.06
    s.height = pile * 0.0003
    return s


def cloth(ctx, ramp, center, seed, weave=0.3, rough=0.85):
    """Wool/linen: faint 2-texel twill weave, creases from curvature and AO."""
    s = Surface(ctx.N)
    u = ctx.uvm[:, 0] / ctx.texel
    v = ctx.uvm[:, 1] / ctx.texel
    tw = ((np.floor(u) + np.floor(v)) % 4 < 2) * weave
    shade = center + ctx.fbm(6.0, 3, seed) * 0.9 + tw + _dither(ctx, 0.5, seed + 1)
    shade += np.clip(ctx.curv, 0, 1) * 1.6 + ctx.edge_soft(2.0) * 1.2
    shade -= np.clip(-ctx.curv, 0, 1) * 2.0 + ctx.cavity(3.0) * 2.0 + (1.0 - ctx.ao) * 3.5
    s.use_ramp(P[ramp], shade=shade)
    s.rough = rough + ctx.rand(seed + 2) * 0.08
    s.height = tw * 0.0003
    return s


def coat(ctx, seed=101):
    return cloth(ctx, "coat", 4.4, seed)


def cloth_white(ctx, seed=103):
    return cloth(ctx, "cloth_white", 6.0, seed, weave=0.0, rough=0.8)


def cloth_red(ctx, seed=107):
    return cloth(ctx, "cloth_red", 3.8, seed)


def leather(ctx, seed=109):
    s = Surface(ctx.N)
    shade = 3.0 + ctx.fbm(5.0, 3, seed) * 0.8 + _dither(ctx, 0.7, seed)
    shade += ctx.edge_soft(2.0) * 2.2 + np.clip(ctx.curv, 0, 1) * 2.0
    shade -= ctx.cavity(3.0) * 1.5 + (1.0 - ctx.ao) * 2.5
    s.use_ramp(P["leather"], shade=shade)
    s.rough = 0.35 + np.clip(ctx.fbm(4.0, 3, seed + 1), 0, 1) * 0.3
    return s


def hair(ctx, seed=113):
    s = Surface(ctx.N)
    along, across = _grain_frame(ctx)
    c = np.sum(ctx.p * across, axis=1)
    strands = np.sin(c / ctx.texel * 1.3 + ctx.fbm(8.0, 2, seed) * 4.0)
    shade = 2.6 + strands * 0.8 + ctx.fbm(4.0, 3, seed + 1) * 0.8 + _dither(ctx, 0.6, seed + 2)
    shade += np.clip(ctx.curv, 0, 1) * 1.5 - (1.0 - ctx.ao) * 2.5
    s.use_ramp(P["hair"], shade=shade)
    s.rough = 0.55
    return s


# --------------------------------------------------------------------------
# wall coverings
# --------------------------------------------------------------------------

def _damask(u, v, cw=0.5, ch=0.75, seed=77):
    """Mirror-symmetric ornament in a half-drop repeat. Returns (mask, strength)."""
    col = np.floor(u / cw + 1e-9)
    vv = v + np.mod(col, 2) * ch * 0.5
    row = np.floor(vv / ch + 1e-9)
    cx = u / cw - col - 0.5
    cy = vv / ch - row - 0.5
    mx = np.abs(cx)
    # ogee (onion) lattice framing each medallion
    width = 0.44 * np.power(np.clip(0.5 + 0.5 * np.cos(2.0 * np.pi * cy), 0.0, 1.0), 0.8)
    frame = np.abs(mx - width) < 0.05
    # palmette: five-lobed flower above a stem, two leaves below
    fy = cy + 0.06
    r = np.sqrt((mx * 1.1) ** 2 + fy ** 2)
    th = np.arctan2(fy, mx * 1.1)
    petals = r < 0.28 * (0.55 + 0.45 * np.abs(np.cos(2.5 * (th - np.pi / 2))))
    heart = r < 0.065
    stem = (mx < 0.045) & (cy > 0.05) & (cy < 0.36)
    lx = mx - 0.15
    ly = cy - 0.22
    ca, sa = np.cos(0.6), np.sin(0.6)
    leaf = ((lx * ca + ly * sa) / 0.16) ** 2 + ((-lx * sa + ly * ca) / 0.065) ** 2 < 1.0
    bud = ((mx / 0.07) ** 2 + ((cy + 0.37) / 0.08) ** 2) < 1.0
    mask = frame | (petals & ~heart) | stem | leaf | bud
    strength = np.clip(1.0 - r * 3.0, 0.0, 1.0) + leaf * 0.4
    return mask, strength


def wallpaper(ctx, seed=131):
    """Dark green silk damask: tone-on-tone motif with a satin sheen."""
    s = Surface(ctx.N)
    u = ctx.uvm[:, 0]
    v = ctx.uvm[:, 1]
    tx = ctx.texel
    m0, strength = _damask(u, v)
    mr, _ = _damask(u + tx, v)
    ml, _ = _damask(u - tx, v)
    mu, _ = _damask(u, v + tx)
    md, _ = _damask(u, v - tx)
    outline = ~m0 & (mr | ml | mu | md)
    inner = m0
    stripe = (np.mod(np.floor(u / tx), 8) == 0)
    base = 3.2 + ctx.fbm(1.5, 3, seed) * 0.8 + stripe * 0.35 + _dither(ctx, 0.6, seed + 1)
    stain = smoothstep(0.25, 0.7, ctx.fbm(0.9, 3, seed + 2))
    base -= stain * 1.0
    s.use_ramp(P["wallpaper"], shade=base)
    s.shade[outline] = base[outline] - 1.4
    motif = 1.6 + strength * 2.0 - stain * 1.2 + _dither(ctx, 0.8, seed + 3)
    s.use_ramp(P["wallpaper_motif"], mask=inner, shade=motif)
    s.rough = np.where(inner, 0.4, 0.72) + ctx.rand(seed + 4) * 0.05 + stain * 0.1
    s.height = np.where(m0, 0.0012, 0.0)
    _age(ctx, s, cavity=2.0, ao=3.0, edge=0.8)
    return s


def wall_gallery(ctx, seed=137):
    """Tileable 4 m x 6 m gallery wall for greybox boxes: painted wainscot,
    chair rail, damask, frieze and a painted cornice band."""
    z = ctx.p[:, 2]
    x = ctx.p[:, 0]
    tx = ctx.texel
    skirting = z < 0.22
    wains = (z >= 0.22) & (z < 1.18)
    rail = (z >= 1.18) & (z < 1.3)
    paper = (z >= 1.3) & (z < 5.2)
    frieze = (z >= 5.2) & (z < 5.45)
    cornice = z >= 5.45
    s = combine(ctx, [
        (skirting | wains | rail, wood_dark),
        (paper, wallpaper),
        (frieze | cornice, plaster),
    ])
    # painted mouldings: panel frames in the wainscot band
    pw = 1.0
    px = np.mod(x, pw)
    in_panel = wains & (px > 0.12) & (px < pw - 0.02) & (z > 0.34) & (z < 1.06)
    frame_edge = wains & ~in_panel & (
        (np.abs(px - 0.12) < tx) | (np.abs(px - (pw - 0.02)) < tx) | (np.abs(z - 0.34) < tx) | (np.abs(z - 1.06) < tx))
    s.shade[frame_edge] += 2.0
    top_lit = wains & in_panel & ((np.abs(z - 1.06) < 2 * tx) | (np.abs(px - 0.12) < 2 * tx))
    s.shade[top_lit] -= 1.5
    for zz, d in ((0.22, -2.0), (1.18, 2.0), (1.3, -2.5), (5.2, -2.0), (5.45, 2.0), (5.8, -2.0)):
        band = np.abs(z - zz) < tx
        s.shade[band] += d
    s.height = s.height + np.where(in_panel, 0.004, 0.0) + np.where(rail, 0.006, 0.0)
    return s


# --------------------------------------------------------------------------
# glass, lamps, wax, crystal
# --------------------------------------------------------------------------

def glass(ctx, seed=149):
    """Nearly clear; albedo alpha carries dust/smudges, roughness the fingerprints."""
    s = Surface(ctx.N)
    smudge = smoothstep(0.1, 0.7, ctx.fbm(3.0, 4, seed))
    dust = smoothstep(0.2, 0.9, ctx.fbm(9.0, 2, seed + 1)) * 0.5 + ctx.rand(seed + 2) * 0.15
    s.use_ramp(P["glass"], shade=2.0 + ctx.fbm(1.0, 2, seed + 3) + _dither(ctx, 0.5, seed + 4))
    s.alpha = np.clip(0.06 + smudge * 0.08 + dust * 0.1 + ctx.edge_soft(3.0) * 0.3, 0.0, 1.0)
    s.rough = 0.03 + smudge * 0.2
    return s


def lamp_warm(ctx, seed=151):
    s = Surface(ctx.N)
    shade = 4.0 + ctx.fbm(10.0, 2, seed) * 0.6 + _dither(ctx, 0.5, seed)
    shade -= (1.0 - ctx.ao) * 3.0
    s.use_ramp(P["lamp_warm"], shade=shade)
    s.rough = 0.35
    s.emit = s.colors() * 1.0
    return s


def lamp_red(ctx, seed=157):
    s = Surface(ctx.N)
    shade = 4.0 + ctx.fbm(10.0, 2, seed) * 0.6 + _dither(ctx, 0.5, seed)
    s.use_ramp(P["lamp_red"], shade=shade)
    s.rough = 0.3
    s.emit = s.colors() * 1.0
    return s


def wax(ctx, seed=163):
    """Wax skin: soft, slightly translucent, glossy drips, curvature-driven shading."""
    s = Surface(ctx.N)
    mottle = ctx.fbm(9.0, 3, seed) * 0.35 + ctx.fbm(2.0, 3, seed + 1) * 0.45
    shade = 6.8 + mottle + _dither(ctx, 0.4, seed + 2)
    shade += np.clip(ctx.curv, 0, 1) * 2.0 + ctx.edge_soft(2.0) * 1.0
    shade -= np.clip(-ctx.curv, 0, 1) * 2.4 + ctx.cavity(3.0) * 2.0 + (1.0 - ctx.ao) * 4.5
    s.use_ramp(P["wax"], shade=shade)
    # drips: vertical glossy runs, lighter
    u = ctx.p[:, 0] + ctx.p[:, 1] * 0.7
    run = ctx.fbm(np.array([22.0, 22.0, 1.2]), 3, seed + 3, p=np.stack([u, u * 0.5, ctx.p[:, 2]], axis=1))
    drip = run > 0.38
    s.shade[drip] += 1.0
    s.rough = np.where(drip, 0.18, 0.42) + ctx.rand(seed + 4) * 0.05
    s.sss = np.full(ctx.N, 0.8)
    s.height = drip * 0.0008 + mottle * 0.0003
    return s


def crystal(ctx, seed=167):
    s = Surface(ctx.N)
    shade = 3.2 + ctx.fbm(12.0, 2, seed) * 1.0 + _dither(ctx, 0.9, seed + 1)
    shade += ctx.edge(1.0) * 3.5 + ctx.edge(2.0) * 1.0 - (1.0 - ctx.ao) * 2.0
    s.use_ramp(P["crystal"], shade=shade)
    s.rough = 0.12 + ctx.rand(seed + 2) * 0.06
    s.emit = s.colors() * 0.18
    return s


def bronze(ctx, seed=173):
    """Green patina with bare bronze on high points."""
    s = Surface(ctx.N)
    shade = 4.0 + ctx.fbm(4.0, 4, seed) * 1.3 + _dither(ctx, 0.8, seed + 1)
    shade -= ctx.cavity(3.0) * 2.0 + (1.0 - ctx.ao) * 4.0 + np.clip(-ctx.curv, 0, 1) * 2.0
    s.use_ramp(P["bronze"], shade=shade)
    bare = (np.clip(ctx.curv, 0, 1) + ctx.edge_soft(2.0)) > 0.45
    s.use_ramp(P["bronze_metal"], mask=bare, shade=np.full(ctx.N, 2.5) + _dither(ctx, 1.5, seed + 2))
    s.metal = np.where(bare, 0.9, 0.2)
    s.rough = np.where(bare, 0.3, 0.7)
    return s


# --------------------------------------------------------------------------
# stage 2: shared marks (scratches, dents, stitches)
# --------------------------------------------------------------------------

def scratches(ctx, seed=0, density=0.5, length=0.04, width=0.6):
    """Thin straight scratches in the surface's own metre-UV plane (1 = on a
    scratch). One random stroke per cell of ``length`` metres."""
    u = ctx.uvm[:, 0] + ctx.part * 7.31
    v = ctx.uvm[:, 1] + ctx.part * 3.17
    cs = length * 1.3
    out = np.zeros(ctx.N, dtype=bool)

    def h(cx, cy, k):
        return noise.hash_float(cx, cy, np.full_like(cx, k), ctx.seed + seed)

    for ox, oy in ((0.0, 0.0), (0.5, 0.5)):
        cx = np.floor(u / cs + ox).astype(np.int64)
        cy = np.floor(v / cs + oy).astype(np.int64)
        has = h(cx, cy, 11) < density
        ang = h(cx, cy, 12) * np.pi
        lx = u / cs + ox - cx - 0.5 - (h(cx, cy, 13) - 0.5) * 0.3
        ly = v / cs + oy - cy - 0.5 - (h(cx, cy, 14) - 0.5) * 0.3
        along = lx * np.cos(ang) + ly * np.sin(ang)
        across = -lx * np.sin(ang) + ly * np.cos(ang)
        half = 0.25 + h(cx, cy, 15) * 0.2
        out |= has & (np.abs(across) * cs < width * ctx.texel) & (np.abs(along) < half)
    return out.astype(np.float64)


def dents(ctx, seed=0, freq=9.0, amount=0.35, radius=0.35):
    """Round dents (0..1 depth) from cellular noise in 3D: some cells hold a
    shallow bowl. The normal map turns the depth into a lit dent."""
    f1, _, cid = ctx.worley(freq, seed)
    return np.where(cid < amount, np.clip((radius - f1) / radius, 0.0, 1.0), 0.0)


def tangent_flow(ctx, flow):
    """A direction field (N,3 or 3,) projected onto the surface."""
    f = np.broadcast_to(np.asarray(flow, dtype=np.float64), ctx.p.shape)
    f = f - ctx.n * np.sum(f * ctx.n, axis=1, keepdims=True)
    ln = np.linalg.norm(f, axis=1, keepdims=True)
    fallback = np.where(np.abs(ctx.n[:, 2:3]) < 0.9, np.array([0.0, 0.0, -1.0]), np.array([0.0, -1.0, 0.0]))
    return np.where(ln > 1e-6, f / np.maximum(ln, 1e-9), fallback)


def _streaks(ctx, flow, along_freq, across_freq, octaves, seed):
    """Noise stretched along a per-texel flow direction (fur, grain, fibres)."""
    f = tangent_flow(ctx, flow)
    side = np.cross(ctx.n, f)
    q = np.stack([np.sum(ctx.p * f, 1), np.sum(ctx.p * side, 1), np.sum(ctx.p * ctx.n, 1)], axis=1)
    return ctx.fbm(np.array([along_freq, across_freq, across_freq]), octaves, seed, p=q)


def strokes(ctx, flow, la=0.028, lc=0.0075, seed=0, fill=0.75):
    """Short 1-texel strokes along a flow field, one per cell (``la`` long,
    ``lc`` wide): +1 light strand, -1 dark strand, 0 between. Reads as
    hand-placed hair strokes in pixel art."""
    f = tangent_flow(ctx, flow)
    side = np.cross(ctx.n, f)
    a = np.sum(ctx.p * f, 1)
    c = np.sum(ctx.p * side, 1)
    col = np.floor(c / lc).astype(np.int64)
    zero = np.zeros_like(col)
    aa = a / la + noise.hash_float(col, zero, zero, ctx.seed + seed) * 7.0
    row = np.floor(aa).astype(np.int64)
    fa = aa - row
    fc = c / lc - col
    r1 = noise.hash_float(col, row, zero + 1, ctx.seed + seed)
    r2 = noise.hash_float(col, row, zero + 2, ctx.seed + seed)
    on = (np.abs(fc - (0.25 + 0.5 * r1)) * lc < 0.6 * ctx.texel) & (fa < fill)
    return np.where(on, np.where(r2 > 0.45, 1.0, -1.0), 0.0)


# --------------------------------------------------------------------------
# stage 2: taxidermy
# --------------------------------------------------------------------------

def fur(ctx, seed=191, flow=(0.0, -1.0, -0.25), center=5.0, ramp="fur", moth=1.0):
    """Stuffed-animal pelt: strands along ``flow`` (N,3 or 3,), clumps,
    moth-eaten bald patches showing dried hide, a few holes showing the
    wood-wool stuffing."""
    s = Surface(ctx.N)
    strands = _streaks(ctx, flow, 11.0, 48.0, 3, seed)
    clumps = _streaks(ctx, flow, 4.0, 16.0, 3, seed + 1)
    st = strokes(ctx, flow, seed=seed + 11)
    tips = ctx.fbm(9.0, 2, seed + 10) * 0.7
    shade = center + strands * 1.2 + clumps * 1.6 + tips + st * 1.4 + _dither(ctx, 0.35, seed + 2)
    shade += np.clip(ctx.curv, 0, 1) * 1.5 + ctx.edge_soft(2.0) * 0.8
    shade -= np.clip(-ctx.curv, 0, 1) * 2.2 + ctx.cavity(3.0) * 2.0 + (1.0 - ctx.ao) * 4.5
    s.use_ramp(P[ramp], shade=shade)
    s.height = strands * 0.0006 + clumps * 0.0007 + st * 0.0004
    s.rough = 0.88 + ctx.rand(seed + 3) * 0.08
    if moth > 0:
        m = ctx.fbm(3.2, 4, seed + 4) + ctx.fbm(11.0, 2, seed + 5) * 0.25
        thr = 0.5 - 0.08 * moth
        patch = m > thr
        rim = (m > thr - 0.06) & ~patch
        s.shade[rim] -= 1.5                      # matted, thinning fur round the bald spot
        s.use_ramp(P["hide"], mask=patch, shade=2.6 + ctx.fbm(30.0, 2, seed + 6) * 1.2
                   + _dither(ctx, 0.9, seed + 7) - (1.0 - ctx.ao) * 2.0)
        hole = patch & (m > thr + 0.12)
        straw = _streaks(ctx, (0.3, 0.2, 1.0), 20.0, 60.0, 2, seed + 8)
        s.use_ramp(P["excelsior"], mask=hole, shade=2.5 + straw * 2.5 + _dither(ctx, 1.0, seed + 9))
        s.rough = np.where(patch, 0.62, s.rough)
        s.height = np.where(patch, -0.0012, s.height) - hole * 0.001
    return s


def stitches(ctx, s, dist, along, width=0.006, pitch=0.014, seed=0):
    """Paints a sewn seam onto ``s``: ``dist`` = metres from the seam line,
    ``along`` = metres along it. A dark creased line plus cross threads."""
    seam = np.abs(dist) < ctx.texel * 0.7
    k = np.mod(along / pitch, 1.0)
    thread = (np.abs(dist) < width) & (k < 0.32)
    near = (np.abs(dist) < width * 1.6) & ~seam
    s.shade[near] -= 0.8
    s.shade[seam] -= 2.2
    s.use_ramp(P["hair"], mask=thread, shade=2.2 + _dither(ctx, 1.0, seed) + (k < 0.12) * 1.5)
    s.height = s.height - seam * 0.0015 + thread * 0.0008 - near * 0.0006
    s.rough = np.where(thread, 0.5, s.rough)
    return s


def ivory(ctx, seed=199, center=5.2):
    """Teeth and claws: yellowed, darker toward the root, glossy."""
    s = Surface(ctx.N)
    shade = center + ctx.fbm(20.0, 2, seed) * 0.8 + _dither(ctx, 0.6, seed + 1)
    shade += ctx.edge(1.0) * 1.5 + np.clip(ctx.curv, 0, 1) - (1.0 - ctx.ao) * 4.0
    s.use_ramp(P["ivory"], shade=shade)
    s.rough = 0.3 + ctx.rand(seed + 2) * 0.05
    return s


def gum(ctx, seed=211):
    s = Surface(ctx.N)
    shade = 3.0 + ctx.fbm(25.0, 2, seed) * 0.8 + _dither(ctx, 0.7, seed + 1) - (1.0 - ctx.ao) * 3.0
    s.use_ramp(P["gum"], shade=shade)
    s.rough = np.full(ctx.N, 0.35)
    return s


def glass_eye(ctx, center, forward, iris=0.011, pupil=0.0045, ramp="eye_amber", glow=0.35):
    """Taxidermy glass eye on a small sphere: coloured iris and a round black
    pupil facing ``forward`` from ``center``, a painted glint, very glossy,
    faintly emissive so it catches any light (and glints in the dark)."""
    s = Surface(ctx.N)
    fwd = np.asarray(forward, dtype=np.float64)
    fwd = fwd / np.linalg.norm(fwd)
    d = ctx.p - np.asarray(center)
    along = d @ fwd
    lateral = np.linalg.norm(d - along[:, None] * fwd, axis=1)
    front = along > 0
    ring = np.clip(1.0 - lateral / iris, 0, 1)
    shade = 1.0 + ring * 4.5 + ctx.fbm(400.0, 2, 3) * 0.7 + _dither(ctx, 0.6, 5)
    s.use_ramp(P[ramp], shade=np.where(front & (lateral < iris), shade, 0.3))
    pup = front & (lateral < pupil)
    s.use_ramp(P["eye"], mask=pup, shade=np.full(ctx.N, 0.0))
    up = np.array([0.0, 0.0, 1.0])
    side = np.cross(fwd, up)
    gl = front & (np.abs(d @ side + pupil * 0.9) < ctx.texel * 1.0) & (np.abs(d @ up - pupil * 1.1) < ctx.texel * 1.0)
    s.use_ramp(P["eye"], mask=gl, shade=np.full(ctx.N, 3.0))
    s.rough = np.full(ctx.N, 0.03)
    col = s.colors()
    s.emit = np.where((front & (lateral < iris) & ~pup)[:, None], col * glow, 0.0)
    return s


# --------------------------------------------------------------------------
# stage 2: armour and weapons
# --------------------------------------------------------------------------

def steel(ctx, seed=181, ramp="steel", center=6.4, dent=0.35, rust=1.0, polish=0.26, scratch=0.22):
    """Polished plate: brushed along the island, cloudy wear, round dents,
    bright scratches, bright rolled edges, rust and grime in the joints."""
    s = Surface(ctx.N)
    along, across = _grain_frame(ctx)
    q = np.stack([np.sum(ctx.p * along, 1), np.sum(ctx.p * ctx.n, 1), np.sum(ctx.p * across, 1)], axis=1)
    brushed = ctx.fbm(np.array([3.0, 90.0, 90.0]), 2, seed, p=q)
    cloud = ctx.fbm(2.2, 3, seed + 1)
    dp = dents(ctx, seed + 2, freq=9.0, amount=dent) if dent > 0 else np.zeros(ctx.N)
    sc = scratches(ctx, seed + 3, density=scratch, length=0.05) if scratch > 0 else np.zeros(ctx.N)
    shade = center + brushed * 0.8 + cloud * 1.3 + _dither(ctx, 0.7, seed + 4)
    shade -= dp * 1.2
    shade += sc * 2.5 + ctx.edge(1.0) * 2.6 + ctx.edge(2.0) * 1.0
    shade -= ctx.cavity(3.0) * 3.0 + (1.0 - ctx.ao) * 5.0
    s.use_ramp(P[ramp], shade=shade)
    grime = (ctx.cavity(3.0) > 0.25) | ((1.0 - ctx.ao) > 0.3)
    rust_m = grime & (ctx.fbm(7.0, 3, seed + 5) > 0.25 - 0.35 * rust)
    s.use_ramp(P["rust"], mask=rust_m, shade=1.0 + ctx.fbm(24.0, 2, seed + 6) * 1.2 + _dither(ctx, 1.0, seed + 7))
    s.metal = np.where(rust_m, 0.1, 1.0)
    s.rough = np.clip(polish + np.clip(cloud, 0, 1) * 0.2 + dp * 0.1 - sc * 0.08 + ctx.rand(seed + 8) * 0.04, 0.05, 1)
    s.rough = np.where(rust_m, 0.85, s.rough)
    s.height = -dp * dp * 0.0035 + brushed * 0.0002 - sc * 0.0004
    return s


def mail(ctx, seed=223):
    """Riveted mail under the plates: rows of rings, dark and oily."""
    s = Surface(ctx.N)
    u = ctx.uvm[:, 0] / 0.016
    v = ctx.uvm[:, 1] / 0.012
    row = np.floor(v)
    uu = u + np.mod(row, 2) * 0.5
    fu = uu - np.floor(uu) - 0.5
    fv = v - row - 0.5
    r = np.sqrt(fu * fu + fv * fv * 1.6)
    ring = (r > 0.22) & (r < 0.48)
    shade = 2.2 + ring * 2.2 + ctx.fbm(6.0, 3, seed) * 0.8 + _dither(ctx, 0.8, seed + 1)
    shade -= (1.0 - ctx.ao) * 3.0 + ctx.cavity(3.0) * 1.5
    s.use_ramp(P["steel"], shade=shade)
    s.metal = np.full(ctx.N, 0.9)
    s.rough = np.where(ring, 0.35, 0.7)
    s.height = ring * 0.0012
    return s


def paint(ctx, ramp, center, seed=227, chip=1.0, under="wood_dark", gloss=0.55, crackle=0.0):
    """Hand-painted surface (shields, enamel signs): brush streaks, chips at
    the edges down to ``under`` (another material), optional crackle."""
    s = Surface(ctx.N)
    strokes = _streaks(ctx, (0.0, 0.0, 1.0), 12.0, 50.0, 2, seed)
    shade = center + strokes * 0.6 + ctx.fbm(2.0, 3, seed + 1) * 0.9 + _dither(ctx, 0.5, seed + 2)
    shade += ctx.edge(1.0) * 1.0
    shade -= ctx.cavity(3.0) * 2.0 + (1.0 - ctx.ao) * 3.5
    s.use_ramp(P[ramp], shade=shade)
    s.rough = gloss + ctx.rand(seed + 3) * 0.05
    s.height = strokes * 0.0003
    if crackle > 0:
        f1, f2, _ = ctx.worley(40.0, seed + 4)
        crack = (f2 - f1) < 0.06 * crackle
        s.shade[crack] -= 1.6
        s.height = s.height - crack * 0.0004
    if chip > 0:
        wear = ctx.edge_soft(4.0) * 0.8 + np.clip(ctx.fbm(9.0, 3, seed + 5), 0, 1) * 0.7
        chipped = wear > 1.05 - 0.25 * chip
        sub = MATERIALS[under](ctx)
        s.merge(_select(sub, chipped), chipped)
        rim = (wear > 0.95 - 0.25 * chip) & ~chipped
        s.shade[rim] -= 1.2
        s.height = np.where(chipped, -0.0006, s.height)
    return s


def gun_steel(ctx, seed=233, ramp="steel_blued", center=6.0, wear=1.0):
    """Blued gun steel: fine brushing, bluing worn to bright steel on edges
    and high spots (holster wear), a few scratches."""
    s = Surface(ctx.N)
    along, across = _grain_frame(ctx)
    q = np.stack([np.sum(ctx.p * along, 1), np.sum(ctx.p * ctx.n, 1), np.sum(ctx.p * across, 1)], axis=1)
    brushed = ctx.fbm(np.array([4.0, 160.0, 160.0]), 2, seed, p=q)
    shade = center + brushed * 0.7 + ctx.fbm(6.0, 3, seed + 1) * 0.8 + _dither(ctx, 0.6, seed + 2)
    shade -= ctx.cavity(3.0) * 2.5 + (1.0 - ctx.ao) * 3.5
    s.use_ramp(P[ramp], shade=shade)
    worn = (ctx.edge_soft(3.0) * (0.6 + ctx.fbm(20.0, 2, seed + 3) * 0.8)) > 0.55 / max(wear, 0.1)
    sc = scratches(ctx, seed + 4, density=0.1, length=0.025) > 0
    bare = worn | sc
    s.use_ramp(P["steel"], mask=bare, shade=8.2 + ctx.edge(1.0) * 1.8 + _dither(ctx, 1.0, seed + 5))
    s.metal = np.where(bare, 1.0, 0.85)
    s.rough = np.where(bare, 0.22, 0.3 + ctx.rand(seed + 6) * 0.05)
    s.height = brushed * 0.0001 - sc * 0.0002
    return s


def checkering(ctx, s, period=0.0045, depth=0.0005):
    """Cuts diamond checkering (grips, stocks) into an existing surface."""
    u = ctx.uvm[:, 0] / period
    v = ctx.uvm[:, 1] / period
    g = (np.mod(u + v, 1.0) < 0.34) | (np.mod(u - v, 1.0) < 0.34)
    s.shade[g] -= 1.8
    s.height = s.height - g * depth
    s.rough = np.where(g, np.minimum(s.rough + 0.2, 1.0), s.rough)
    return s


def walnut_stock(ctx, seed=239):
    s = _wood_core(ctx, P["walnut_stock"], 4.8, seed, ring_freq=16.0, contrast=1.1)
    _age(ctx, s, cavity=2.0, ao=3.5, edge=1.8)
    s.rough = 0.3 + np.clip(ctx.fbm(3.0, 3, seed + 5), 0, 1) * 0.2 + ctx.cavity(3.0) * 0.3
    return s


def plastic(ctx, ramp, center, seed=241, rough=0.45, scuff=1.0, speckle=0.35):
    """Moulded plastic: faint speckle, worn lighter on edges, scuffs."""
    s = Surface(ctx.N)
    shade = center + ctx.fbm(5.0, 3, seed) * 0.6 + _dither(ctx, speckle * 2.0, seed + 1)
    sc = scratches(ctx, seed + 2, density=0.08 * scuff, length=0.03) if scuff > 0 else np.zeros(ctx.N)
    shade += ctx.edge(1.0) * 1.6 + ctx.edge(2.0) * 0.5 + sc * 1.3
    shade -= ctx.cavity(3.0) * 2.2 + (1.0 - ctx.ao) * 4.0
    s.use_ramp(P[ramp], shade=shade)
    s.rough = rough + ctx.rand(seed + 3) * 0.05 + sc * 0.15
    s.height = ctx.fbm(60.0, 2, seed + 4) * 0.00015 - sc * 0.0002
    return s


def rubber(ctx, seed=251):
    """Stippled black rubber / polymer grip."""
    s = plastic(ctx, "plastic_black", 2.6, seed, rough=0.78, scuff=0.4, speckle=0.6)
    st = ctx.rand(seed + 9) > 0.55
    s.shade[st] += 0.8
    s.height = s.height + st * 0.0003
    return s


def uniform(ctx, seed=257):
    """Security guard's uniform: dark navy-grey twill."""
    return cloth(ctx, "uniform", 4.3, seed, weave=0.35, rough=0.9)


# --------------------------------------------------------------------------
# stage 2: fossils
# --------------------------------------------------------------------------

def bone(ctx, seed=263, center=5.6, repairs=1.0):
    """Mounted fossil bone: fibrous streaks along the bone, mottled
    mineral staining, pores, hairline cracks, and pale plaster repairs with
    a dark joint line where missing bone was filled in."""
    s = Surface(ctx.N)
    along, across = _grain_frame(ctx)
    q = np.stack([np.sum(ctx.p * along, 1), np.sum(ctx.p * ctx.n, 1), np.sum(ctx.p * across, 1)], axis=1)
    fib = ctx.fbm(np.array([1.6, 22.0, 22.0]), 3, seed, p=q)
    mott = ctx.fbm(1.6, 4, seed + 1)
    f1, _, cid = ctx.worley(34.0, seed + 2)
    pore = (f1 < 0.2) & (cid > 0.45)
    crack = (np.abs(ctx.fbm(1.8, 4, seed + 3)) < 0.014) & (ctx.fbm(0.9, 2, seed + 4) > -0.1)
    shade = center + fib * 1.3 + mott * 2.0 + _dither(ctx, 0.8, seed + 5) - pore * 1.6 - crack * 2.8
    shade += ctx.edge(1.0) * 1.4 + np.clip(ctx.curv, 0, 1) * 1.6
    shade -= np.clip(-ctx.curv, 0, 1) * 1.8 + ctx.cavity(3.0) * 2.2 + (1.0 - ctx.ao) * 4.5
    s.use_ramp(P["bone"], shade=shade)
    s.rough = 0.62 + np.clip(mott, 0, 1) * 0.15 + ctx.rand(seed + 6) * 0.05
    s.height = fib * 0.0008 - pore * 0.0015 - crack * 0.002
    if repairs > 0:
        rp = ctx.fbm(1.1, 3, seed + 7) + ctx.fbm(6.0, 2, seed + 8) * 0.12
        thr = 0.46 - 0.08 * repairs
        patch = rp > thr
        joint = (rp > thr - 0.035) & ~patch
        s.shade[joint] -= 2.4
        s.use_ramp(P["plaster"], mask=patch, shade=4.6 + ctx.fbm(9.0, 2, seed + 9) * 0.6
                   + _dither(ctx, 0.5, seed + 10) + ctx.edge(1.0) * 1.0 - (1.0 - ctx.ao) * 3.5)
        s.rough = np.where(patch, 0.9, s.rough)
        s.height = np.where(patch, 0.0006 + ctx.fbm(9.0, 2, seed + 9) * 0.0003, s.height) - joint * 0.001
    return s


def tooth_fossil(ctx, seed=269):
    s = Surface(ctx.N)
    shade = 3.2 + ctx.fbm(12.0, 3, seed) * 1.0 + _dither(ctx, 0.7, seed + 1)
    shade += ctx.edge(1.0) * 1.5 + np.clip(ctx.curv, 0, 1) * 1.2 - (1.0 - ctx.ao) * 3.0
    s.use_ramp(P["tooth_fossil"], shade=shade)
    s.rough = 0.28 + ctx.rand(seed + 2) * 0.05
    return s


# --------------------------------------------------------------------------
# stage 2: props
# --------------------------------------------------------------------------

def cardboard(ctx, seed=271, center=4.6, ramp="cardboard"):
    s = Surface(ctx.N)
    shade = center + ctx.fbm(8.0, 3, seed) * 0.7 + _dither(ctx, 1.0, seed + 1)
    fuzz = ctx.edge_soft(3.0) * (ctx.rand(seed + 2) > 0.4)
    shade += fuzz * 1.4
    shade -= ctx.cavity(3.0) * 2.0 + (1.0 - ctx.ao) * 3.5
    s.use_ramp(P[ramp], shade=shade)
    s.rough = np.full(ctx.N, 0.92)
    s.height = ctx.fbm(40.0, 2, seed + 3) * 0.0002
    return s


def enamel(ctx, ramp, center, seed=277, chip=1.0, gloss=0.28, under="iron"):
    """Stove enamel / painted sheet steel: glossy, faint orange peel, chips
    at edges down to dark iron (with a rust rim), grime in the corners."""
    s = paint(ctx, ramp, center, seed, chip=chip, under=under, gloss=gloss)
    peel = ctx.fbm(70.0, 2, seed + 11)
    s.height = s.height + peel * 0.00012
    sc = scratches(ctx, seed + 12, density=0.12, length=0.04) > 0
    s.shade[sc] -= 1.0
    return s


def porcelain(ctx, seed=281, center=5.8, craze=1.0):
    """Glazed ceramic: glossy, fine crazing, grime settled in the crackle."""
    s = Surface(ctx.N)
    shade = center + ctx.fbm(4.0, 3, seed) * 0.5 + _dither(ctx, 0.4, seed + 1)
    f1, f2, _ = ctx.worley(22.0, seed + 2)
    crack = ((f2 - f1) < 0.035 * craze) & (ctx.fbm(3.0, 2, seed + 3) > -0.2)
    shade -= crack * 1.6
    shade += ctx.edge(1.0) * 1.2 + np.clip(ctx.curv, 0, 1) * 0.8
    shade -= ctx.cavity(3.0) * 2.4 + (1.0 - ctx.ao) * 4.0
    s.use_ramp(P["porcelain"], shade=shade)
    s.rough = np.where(crack, 0.4, 0.1 + ctx.rand(seed + 4) * 0.03)
    s.height = crack * -0.0002
    return s


def text_marks(ctx, size=0.004, seed=0, density=0.55, u=None, v=None):
    """Pseudo-print: blocky 3x5 glyphs in lines, in the surface's metre-UV
    plane (or the given u, v). ``size`` = glyph advance in metres."""
    u = ctx.uvm[:, 0] if u is None else u
    v = ctx.uvm[:, 1] if v is None else v
    size = max(size, ctx.texel * 4.0)          # a glyph needs at least 3 x 5 texels
    gu, gv = u / (size / 4.0), v / (size * 1.75 / 7.0)
    cx, cy = np.floor(gu / 4.0).astype(np.int64), np.floor(gv / 7.0).astype(np.int64)
    sx = np.floor(gu).astype(np.int64) - cx * 4
    sy = np.floor(gv).astype(np.int64) - cy * 7
    word = noise.hash_float(cx // 5, cy, np.full_like(cx, 7), ctx.seed + seed) > 0.18    # spaces between words
    on = noise.hash_float(cx * 8 + sx, cy * 8 + sy, np.full_like(cx, 3), ctx.seed + seed) < density
    return (sx < 3) & (sy >= 1) & (sy < 6) & on & word


def label(ctx, seed=367, ramp="cloth_white", center=6.3, size=0.004):
    """Printed paper label: off-white with rows of dark pseudo-text."""
    s = Surface(ctx.N)
    shade = center + ctx.fbm(12.0, 2, seed) * 0.5 + _dither(ctx, 0.5, seed + 1)
    shade -= ctx.cavity(3.0) * 1.5 + (1.0 - ctx.ao) * 3.0
    s.use_ramp(P[ramp], shade=shade)
    ink = text_marks(ctx, size, seed + 2)
    s.use_ramp(P["hair"], mask=ink, shade=np.full(ctx.N, 1.0))
    s.rough = np.full(ctx.N, 0.85)
    return s


def glow(ctx, ramp, center, strength=1.0, seed=283, rough=0.3):
    """Self-lit surface (LEDs, lenses, embers): ramp colour emitted."""
    s = Surface(ctx.N)
    shade = center + ctx.fbm(12.0, 2, seed) * 0.5 + _dither(ctx, 0.5, seed + 1)
    s.use_ramp(P[ramp], shade=shade)
    s.rough = np.full(ctx.N, rough)
    s.emit = s.colors() * strength
    return s


def crt_glass(ctx, seed=293):
    s = Surface(ctx.N)
    s.use_ramp(P["crt_glass"], shade=1.5 + ctx.fbm(3.0, 2, seed) * 0.6 + _dither(ctx, 0.4, seed + 1)
               + ctx.edge(1.0) * 1.5)
    s.rough = np.full(ctx.N, 0.06)
    return s


MATERIALS = {
    "marble_white": marble_white,
    "marble_statuary": marble_statuary,
    "marble_dark": marble_dark,
    "marble_red": marble_red,
    "marble_floor": marble_floor,
    "stone": stone,
    "plaster": plaster,
    "wood_dark": wood_dark,
    "wood_oak": wood_oak,
    "parquet": parquet,
    "brass": brass,
    "gold": gold,
    "iron": iron,
    "velvet": velvet,
    "coat": coat,
    "cloth_white": cloth_white,
    "cloth_red": cloth_red,
    "leather": leather,
    "hair": hair,
    "wallpaper": wallpaper,
    "wall_gallery": wall_gallery,
    "glass": glass,
    "lamp_warm": lamp_warm,
    "lamp_red": lamp_red,
    "wax": wax,
    "crystal": crystal,
    "bronze": bronze,
    "fur": fur,
    "ivory": ivory,
    "gum": gum,
    "steel": steel,
    "mail": mail,
    "gun_steel": gun_steel,
    "walnut_stock": walnut_stock,
    "rubber": rubber,
    "uniform": uniform,
    "bone": bone,
    "tooth_fossil": tooth_fossil,
    "cardboard": cardboard,
    "porcelain": porcelain,
    "crt_glass": crt_glass,
}
