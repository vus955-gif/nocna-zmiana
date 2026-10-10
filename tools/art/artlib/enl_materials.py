"""Materials of the Enlightenment wing (King's Library, cabinets of
curiosities, the Great Orrery, the flying books).

Same rules as materials.py: every colour comes from a hand-picked ramp
(dark -> light), shading = steps along a ramp. The ramps are registered in
the shared dict P under an "enl_" prefix so they never collide with the
other wings' ramps (several wings are built in one Blender process).

Palette of the wing: dark oak and mahogany, brass, green shades and green
baize; book leathers (calf, red / green / blue morocco, vellum) and cloths;
the orrery's deep blue enamel.
"""
import numpy as np

from . import noise
from .materials import (P, _age, _dither, _grain_frame, _wood_core, brass, gold, hexramp, scratches, smoothstep)
from .painter import Surface

P.update({
    "enl_mahogany": hexramp("#0e0605", "#170908", "#210d0a", "#2c120d", "#381710", "#451d13", "#532417",
                            "#622c1c", "#733522", "#863f28"),
    "enl_oak_dark": hexramp("#140d07", "#1d140b", "#271b0f", "#322314", "#3e2c19", "#4b351f", "#584026",
                            "#664b2e", "#755737"),
    "enl_calf": hexramp("#1a0e07", "#26150a", "#341d0e", "#432613", "#533018", "#643b1e", "#764725", "#88542d",
                        "#9a6237", "#ab7243"),
    "enl_morocco_red": hexramp("#1c0505", "#2b0808", "#3d0c0b", "#50110f", "#641714", "#781e19", "#8c271f",
                               "#9f3227", "#b13f31"),
    "enl_morocco_green": hexramp("#06120c", "#0a1b12", "#0f2519", "#143020", "#1a3c28", "#214831", "#29553a",
                                 "#326244", "#3c704f"),
    "enl_morocco_blue": hexramp("#070b18", "#0b1222", "#10192e", "#15213b", "#1b2a49", "#223458", "#2a3f67",
                                "#334a76"),
    "enl_black": hexramp("#070707", "#0e0d0d", "#161414", "#1f1c1b", "#292523", "#342f2c", "#403936"),
    "enl_vellum": hexramp("#4a3f2c", "#5f533c", "#75694d", "#8b7f60", "#a09474", "#b4a988", "#c6bc9c", "#d6cdb0"),
    "enl_cloth_maroon": hexramp("#1b0709", "#2a0b0f", "#3a1015", "#4a161b", "#5b1c22", "#6c2329", "#7c2b30",
                                "#8c3438"),
    "enl_cloth_olive": hexramp("#13140a", "#1c1d0f", "#262714", "#31321a", "#3d3d20", "#494927", "#56552e",
                               "#636236"),
    "enl_cloth_slate": hexramp("#0f1216", "#161a20", "#1e232a", "#272d35", "#303741", "#3a424d", "#454e5a",
                               "#515b68"),
    "enl_paper": hexramp("#3e3627", "#544a37", "#6b6048", "#82775b", "#998e6f", "#afa483", "#c4ba98", "#d6cdad",
                         "#e4dcc0"),
    "enl_ink": hexramp("#0d0a08", "#1a1410", "#2a2119", "#3b2f24"),
    "enl_baize": hexramp("#04100a", "#08180f", "#0d2115", "#122b1b", "#183622", "#1f422a", "#274f33", "#305c3c"),
    "enl_silk_green": hexramp("#071009", "#0b180e", "#102114", "#162b1a", "#1d3621", "#254128", "#2e4d30"),
    "enl_shade_green": hexramp("#031a0d", "#062614", "#0a331b", "#0f4224", "#16532e", "#1f6539", "#2a7946",
                               "#3a8e56", "#55a76c"),
    "enl_enamel_blue": hexramp("#030616", "#060b22", "#0a1230", "#0f1a40", "#152351", "#1c2e63", "#253a76",
                               "#304889", "#3d589c"),
    "enl_parchment": hexramp("#3b3220", "#51462d", "#675a3b", "#7e6f4a", "#95855b", "#ab9a6d", "#beae80",
                             "#cfc093", "#ddd0a6"),
    "enl_wash_pink": hexramp("#4a2621", "#62332c", "#7b4339", "#935548", "#a96959", "#bc7e6c"),
    "enl_wash_green": hexramp("#2c3320", "#3b4429", "#4b5634", "#5c6840", "#6e7a4d", "#808b5b"),
    "enl_wash_ochre": hexramp("#4d3a17", "#654d1f", "#7e6229", "#977735", "#ae8c43", "#c2a054"),
    "enl_plaster_cool": hexramp("#3f4142", "#505354", "#636667", "#76797a", "#8a8c8c", "#9d9f9e", "#b0b1af",
                                "#c2c2bf", "#d2d1cd"),
    "enl_frieze": hexramp("#07100c", "#0b1712", "#101f18", "#15271e", "#1b3025", "#22392c"),
    "enl_steel_dark": hexramp("#0a0b0d", "#121418", "#1b1e23", "#25292f", "#30353c", "#3c424a", "#4a5059",
                              "#5a616b"),
})

# book covering materials: ramp key, centre shade, roughness, kind
LEATHERS = ("enl_calf", "enl_morocco_red", "enl_morocco_green", "enl_morocco_blue", "enl_black")
CLOTHS = ("enl_cloth_maroon", "enl_cloth_olive", "enl_cloth_slate")
VELLUM = ("enl_vellum",)


# --------------------------------------------------------------------------
# woods
# --------------------------------------------------------------------------

def mahogany(ctx, seed=503, center=4.6):
    """French-polished mahogany: deep red-brown, ribbon figure, glossy,
    bright worn arrises, dark grime in the mouldings."""
    s = _wood_core(ctx, P["enl_mahogany"], center, seed, ring_freq=12.0, contrast=0.9)
    along, across = _grain_frame(ctx)
    c = np.sum(ctx.p * across, axis=1)
    ribbon = np.sin(c * 55.0 + ctx.fbm(1.5, 2, seed + 3) * 4.0) * 0.45
    s.shade += ribbon
    _age(ctx, s, cavity=2.0, ao=3.4, edge=1.7)
    s.rough = 0.26 + np.clip(ctx.fbm(3.0, 3, seed + 5), 0, 1) * 0.2 + ctx.cavity(3.0) * 0.35
    return s


def oak_dark(ctx, seed=509, center=4.4):
    """Dark-stained library oak (floors of the walkway, stairs, the ladder)."""
    s = _wood_core(ctx, P["enl_oak_dark"], center, seed, ring_freq=8.0, contrast=1.1)
    _age(ctx, s, cavity=1.8, ao=3.0, edge=1.5)
    s.rough = 0.4 + np.clip(ctx.fbm(3.0, 3, seed + 5), 0, 1) * 0.22
    return s


def worn_brass(ctx, seed=521):
    """Handled brass: brighter, less tarnish (rails, knobs, nosings)."""
    s = brass(ctx, seed, tarnish_amount=1.2)
    s.shade += 0.5
    return s


def dark_brass(ctx, seed=523):
    """Old lacquered brass gone dark (fittings high up, the orrery's frames)."""
    s = brass(ctx, seed, tarnish_amount=3.0)
    s.shade -= 0.6
    return s


def iron_black(ctx, seed=527):
    """Cast iron painted black, worn to grey metal on the high points."""
    s = Surface(ctx.N)
    base = 2.6 + ctx.fbm(3.0, 3, seed) * 0.6 + _dither(ctx, 0.6, seed + 1)
    s.use_ramp(P["enl_steel_dark"], shade=base)
    s.shade += ctx.edge(1.0) * 2.4 + ctx.edge(2.0) * 0.8
    s.shade -= ctx.cavity(3.0) * 1.5 + (1.0 - ctx.ao) * 2.5
    s.metal = 0.35 + ctx.edge(1.0) * 0.5
    s.rough = 0.45 - ctx.edge(1.0) * 0.15 + ctx.rand(seed + 2) * 0.05
    return s


# --------------------------------------------------------------------------
# soft furnishings, glass, paint
# --------------------------------------------------------------------------

def baize(ctx, seed=531, gilt_border=0.0):
    """Green leather / baize desk tops with an optional gilt tooled border
    ``gilt_border`` metres in from the face's edge."""
    s = Surface(ctx.N)
    shade = 3.6 + ctx.fbm(5.0, 3, seed) * 0.6 + _dither(ctx, 0.6, seed + 1)
    shade += ctx.edge_soft(2.0) * 1.2
    shade -= ctx.cavity(3.0) * 1.5 + (1.0 - ctx.ao) * 3.0
    s.use_ramp(P["enl_baize"], shade=shade)
    s.rough = 0.62 + ctx.rand(seed + 2) * 0.08
    if gilt_border > 0.0:
        d = ctx.convex
        line = (d > gilt_border) & (d < gilt_border + ctx.texel * 1.01)
        line |= (d > gilt_border + ctx.texel * 2.5) & (d < gilt_border + ctx.texel * 3.51)
        s.use_ramp(P["gold"], mask=line, shade=np.full(ctx.N, 6.0) + _dither(ctx, 1.2, seed + 3))
        s.metal = np.where(line, 1.0, 0.0)
        s.rough = np.where(line, 0.3, s.rough)
    return s


def silk_lattice(ctx, seed=541, cell=0.075):
    """Library press doors: a diagonal brass wire lattice with a rosette at
    every crossing over pleated green silk (the face's metre UVs)."""
    s = Surface(ctx.N)
    u, v = ctx.uvm[:, 0], ctx.uvm[:, 1]
    pleat = np.sin(u / ctx.texel * np.pi / 3.0) * 0.6
    shade = 3.2 + pleat + ctx.fbm(4.0, 2, seed) * 0.5 + _dither(ctx, 0.5, seed + 1)
    shade -= (1.0 - ctx.ao) * 3.0 + ctx.cavity(4.0) * 1.5
    s.use_ramp(P["enl_silk_green"], shade=shade)
    a = (u + v) / cell
    b = (u - v) / cell
    da = np.abs(a - np.round(a)) * cell
    db = np.abs(b - np.round(b)) * cell
    wire = (da < ctx.texel * 0.75) | (db < ctx.texel * 0.75)
    ros = (da < ctx.texel * 1.6) & (db < ctx.texel * 1.6)
    metal = wire | ros
    sh = np.full(ctx.N, 6.4) + ros * 1.2 + _dither(ctx, 1.0, seed + 2) - (1.0 - ctx.ao) * 3.0
    s.use_ramp(P["brass"], mask=metal, shade=sh)
    shadow = ~metal & ((np.abs(a - np.round(a) - 0.06) * cell < ctx.texel * 0.75) |
                       (np.abs(b - np.round(b) - 0.06) * cell < ctx.texel * 0.75))
    s.shade[shadow] -= 1.2
    s.metal = np.where(metal, 1.0, 0.0)
    s.rough = np.where(metal, 0.3, 0.8)
    s.height = metal * 0.002 + ros * 0.0015
    return s


def fringe(bottoms, height, seed=547, ramp="enl_morocco_red"):
    """Leather dust fringe hanging from shelf fronts: a gold-tooled dot row
    along the top, the scalloped hem painted as dark notches. ``bottoms`` =
    the z of each fringe's lower edge, ``height`` its height (metres)."""
    bottoms = np.sort(np.asarray(bottoms, dtype=np.float64))

    def fn(ctx):
        s = Surface(ctx.N)
        x = ctx.p[:, 0]
        z = ctx.p[:, 2]
        k = np.clip(np.searchsorted(bottoms, z + 1e-4) - 1, 0, len(bottoms) - 1)
        dz = z - bottoms[k]                       # height above the hem
        shade = 3.4 + ctx.fbm(8.0, 2, seed) * 0.5 + _dither(ctx, 0.6, seed + 1)
        shade += ctx.edge(1.0) * 1.4 - (1.0 - ctx.ao) * 2.0
        s.use_ramp(P[ramp], shade=shade)
        ph = np.mod(x, 0.05) / 0.05 - 0.5
        notch = dz < 0.014 * (1.0 - (2.0 * ph) ** 2) ** 0.5
        front = np.abs(ctx.n[:, 1]) > 0.5
        s.shade[notch & front] = 0.4
        tx = ctx.texel
        row = front & (dz > height - tx * 3.2) & (dz < height - tx * 1.8)
        dots = row & (np.mod(np.floor(x / tx), 3) == 0)
        hem = front & (dz > 0.014) & (dz < 0.014 + tx)
        gilt_m = dots | hem
        s.use_ramp(P["gold"], mask=gilt_m, shade=np.full(ctx.N, 6.0) + _dither(ctx, 1.0, seed + 2))
        s.metal = np.where(gilt_m, 1.0, 0.0)
        s.rough = np.where(gilt_m, 0.35, 0.5)
        return s
    return fn


def shade_green(ctx, seed=553, glow=0.25):
    """Green cased-glass lamp shade: glossy deep green outside, a faint
    green glow (the bulb shining through the glass)."""
    s = Surface(ctx.N)
    shade = 4.6 + ctx.fbm(6.0, 2, seed) * 0.4 + _dither(ctx, 0.4, seed + 1)
    shade += ctx.edge(1.0) * 2.0 + np.clip(ctx.curv, 0, 1) * 1.5
    shade -= (1.0 - ctx.ao) * 1.5
    s.use_ramp(P["enl_shade_green"], shade=shade)
    s.rough = np.full(ctx.N, 0.08)
    s.emit = s.colors() * glow
    return s


def enamel_blue(ctx, seed=557, center=4.8, stars=0.0):
    """The orrery's deep blue vitreous enamel, optional gold star dots."""
    s = Surface(ctx.N)
    shade = center + ctx.fbm(3.0, 3, seed) * 0.6 + _dither(ctx, 0.5, seed + 1)
    shade += ctx.edge(1.0) * 1.6 - ctx.cavity(3.0) * 1.8 - (1.0 - ctx.ao) * 3.0
    s.use_ramp(P["enl_enamel_blue"], shade=shade)
    s.rough = 0.12 + ctx.rand(seed + 2) * 0.04
    if stars > 0.0:
        cell = np.floor(ctx.uvm / (ctx.texel * 4.0)).astype(np.int64)
        h = noise.hash_float(cell[:, 0], cell[:, 1], ctx.part, seed + 3)
        local = np.mod(ctx.uvm / ctx.texel, 4.0)
        star = (h < stars) & (np.abs(local[:, 0] - 2.0) < 0.6) & (np.abs(local[:, 1] - 2.0) < 0.6)
        s.use_ramp(P["gold"], mask=star, shade=np.full(ctx.N, 7.5))
        s.metal = np.where(star, 1.0, 0.0)
    return s


def plaster_cool(ctx, seed=563, center=5.6):
    """Ceiling plaster of the library: cool grey-cream, faint cracks."""
    s = Surface(ctx.N)
    base = center + ctx.fbm(2.5, 4, seed) * 0.8 + _dither(ctx, 0.7, seed + 1)
    crack = (np.abs(ctx.fbm(1.3, 4, seed + 2)) < 0.012) & (ctx.fbm(0.7, 2, seed + 6) > 0.3)
    base -= crack * 1.4
    s.use_ramp(P["enl_plaster_cool"], shade=base)
    _age(ctx, s, cavity=2.2, ao=3.5, edge=1.0)
    s.height = ctx.fbm(8.0, 3, seed + 4) * 0.0012 - crack * 0.001
    s.rough = 0.86 + ctx.rand(seed + 5) * 0.08
    return s


def paper(ctx, seed=569, center=6.0, ramp="enl_paper"):
    """Page edges and loose paper: fine lines across, yellowed and dusty."""
    s = Surface(ctx.N)
    shade = center + ctx.fbm(6.0, 2, seed) * 0.6 + _dither(ctx, 0.6, seed + 1)
    shade -= (1.0 - ctx.ao) * 3.0 + ctx.cavity(3.0) * 1.2
    s.use_ramp(P[ramp], shade=shade)
    s.rough = np.full(ctx.N, 0.9)
    return s


def printed(ctx, seed=571, center=6.6, glyph=0.004, margin=0.02, columns=1):
    """A printed page: off-white paper, pseudo-text lines, a margin."""
    s = paper(ctx, seed, center)
    from .materials import text_marks
    ink = text_marks(ctx, glyph, seed + 1, density=0.6)
    s.use_ramp(P["enl_ink"], mask=ink, shade=np.full(ctx.N, 1.5) + _dither(ctx, 0.8, seed + 2))
    return s


def gilt(ctx, seed=577):
    """Gilding on carved wood (capitals, beads, cartouches)."""
    return gold(ctx, seed)


def glass_tint(ctx, ramp="enl_shade_green", center=5.0, glow=0.0, seed=581):
    """Opaque glossy glass (bottles, specimen jars seen from afar)."""
    s = Surface(ctx.N)
    shade = center + ctx.fbm(5.0, 2, seed) * 0.5 + _dither(ctx, 0.4, seed + 1)
    shade += ctx.edge(1.0) * 2.5 + np.clip(ctx.curv, 0, 1) * 2.0 - (1.0 - ctx.ao) * 2.0
    s.use_ramp(P[ramp], shade=shade)
    s.rough = np.full(ctx.N, 0.06)
    if glow > 0.0:
        s.emit = s.colors() * glow
    return s


def wear_marks(ctx, s, seed=587, amount=1.0):
    """Light scratches on a finished surface (desk tops, rails)."""
    sc = scratches(ctx, seed, density=0.25 * amount, length=0.05) > 0
    s.shade[sc] += 1.0
    return s


def smooth_mask(x, a, b):
    return smoothstep(a, b, x)


# --------------------------------------------------------------------------
# tileable fields (64 px/m, ArtLibrary.arch_tile / "tile:<name>" materials)
# --------------------------------------------------------------------------

def parquet_chevron(ctx, seed=593, strip=0.5, pitch=0.125):
    """Point de Hongrie oak parquet: strips 0.5 m wide running up the image
    (= north, the gallery's long axis on a floor), planks at +/-45 degrees
    meeting in chevrons at the strip seams, a plank every ``pitch`` metres
    up the strip (8 texels at 64 px/m)."""
    x = ctx.p[:, 0]
    z = ctx.p[:, 2]
    j = np.floor(x / strip + 1e-9).astype(np.int64)
    c = x - j * strip
    odd = (j % 2) == 1
    cc = np.where(odd, strip - c, c)
    q = z + cc
    k = np.floor(q / pitch + 1e-9).astype(np.int64)
    pid = (np.mod(j, 16) * 64 + np.mod(k, 64))
    tone = noise.rand_cells(pid, seed) - 0.5
    off = noise.rand_cells(pid, seed + 1) * 40.0
    r2 = 1.0 / np.sqrt(2.0)
    sgn = np.where(odd, -1.0, 1.0)
    t = np.stack([sgn * r2, np.zeros(ctx.N), r2 * np.ones(ctx.N)], axis=1)
    b = np.stack([-r2 * np.ones(ctx.N), np.zeros(ctx.N), sgn * r2], axis=1)
    plain = type(ctx)(ctx.p + off[:, None], ctx.n, t, b, ctx.texel, ctx.seed, None)
    s = _wood_core(plain, P["wood_oak"], 3.5, seed + 2, ring_freq=10.0, contrast=0.8)
    s.shade += tone * 1.8
    mq = np.mod(q, pitch)
    edge = (mq < ctx.texel * 0.999) | (c < ctx.texel * 0.999)
    lip = ~edge & (mq < ctx.texel * 1.999)
    s.shade[lip] += 0.7
    s.shade[edge] = 1.0
    s.height = s.height + np.where(edge, -0.002, 0.0)
    s.rough = 0.36 + tone * 0.1 + np.clip(ctx.fbm(1.5, 3, seed + 3), 0, 1) * 0.25
    s.rough[edge] = 0.9
    return s


def bookside(ctx, seed=599):
    """The boards of the books seen edge-on between runs of different
    heights (world-mapped tile): mottled dark leathers and cloths in
    vertical bands of 2-6 cm, the colours of a shelf in shadow."""
    s = Surface(ctx.N)
    x = ctx.p[:, 0]
    band = np.floor(x / 0.04 + ctx.fbm(np.array([0.5, 0.0, 3.0]), 2, seed) * 0.8).astype(np.int64)
    pick = noise.rand_cells(band, seed + 1)
    mott = ctx.fbm(9.0, 3, seed + 2) * 0.8 + _dither(ctx, 0.7, seed + 3)
    ramps = ("enl_calf", "enl_morocco_red", "enl_morocco_green", "enl_cloth_maroon", "enl_calf", "enl_black")
    cuts = np.linspace(0.0, 1.0, len(ramps) + 1)
    for k, r in enumerate(ramps):
        m = (pick >= cuts[k]) & (pick < cuts[k + 1])
        s.use_ramp(P[r], mask=m, shade=2.4 + mott)
    s.rough = 0.6 + ctx.rand(seed + 4) * 0.1
    s.height = mott * 0.0003
    return s


def oak_boards(ctx, seed=601):
    """Polished dark oak boards 12.5 cm wide in staggered lengths, tight
    joints (the walkway floor, the treads of the stairs). Tile 2 x 2 m."""
    from .arch_materials import _uv, blocks, course_layout
    u, v = _uv(ctx)
    tx = ctx.texel
    Wb = 0.125
    courses = course_layout(2.0, [Wb] * 16, [0.75, 1.0, 1.25, 2.0], seed, step=0.25)
    course, bid, dl, dr, db, dt = blocks(u, v, 2.0, 2.0, courses)
    t = np.tile([1.0, 0.0, 0.0], (ctx.N, 1))
    b = np.tile([0.0, 0.0, 1.0], (ctx.N, 1))
    off = noise.rand_cells(bid, seed)[:, None] * 40.0
    plain = type(ctx)(ctx.p + off, ctx.n, t, b, ctx.texel, ctx.seed, None)
    s = _wood_core(plain, P["enl_oak_dark"], 4.6, seed + 1, ring_freq=10.0, contrast=0.9)
    s.shade += (noise.rand_cells(bid, seed + 2) - 0.5) * 1.6
    gap = (db < tx) | (dl < tx)
    s.shade = np.where(gap, 0.4, s.shade)
    s.height = s.height - gap * 0.002
    s.rough = 0.38 + ctx.rand(seed + 3) * 0.06 + gap * 0.3
    return s


TILES = {"enl_mahogany": mahogany, "parquet_chevron": parquet_chevron, "enl_bookside": bookside,
         "enl_oak_boards": oak_boards}


# --------------------------------------------------------------------------
# ornament masks
# --------------------------------------------------------------------------

KEY = ("........",
       "######..",
       "#....#..",
       "#.##.#..",
       "#.#..#..",
       "#.####..",
       "########")
_KEY_BITS = np.array([[c == "#" for c in row] for row in KEY], dtype=bool)


def greek_key(ctx, u, v, v0, scale=1):
    """Bool mask of a running Greek key (meander) along u (metres), its
    bottom row at v0, one key pixel = ``scale`` texels; snapped to texels."""
    tx = ctx.texel * scale
    col = np.mod(np.floor(u / tx + 1e-6).astype(np.int64), _KEY_BITS.shape[1])
    row = (_KEY_BITS.shape[0] - 1) - np.floor((v - v0) / tx + 1e-6).astype(np.int64)
    ok = (row >= 0) & (row < _KEY_BITS.shape[0])
    out = np.zeros(ctx.N, dtype=bool)
    out[ok] = _KEY_BITS[row[ok], col[ok]]
    return out


def key_frieze(ctx, seed=611, ground="enl_frieze", scale=2):
    """Lacquered dark green band with a gilt Greek key, in the face's metre
    UVs (u along the run, v up the profile)."""
    s = Surface(ctx.N)
    u, v = ctx.uvm[:, 0], ctx.uvm[:, 1]
    shade = 3.0 + ctx.fbm(5.0, 2, seed) * 0.5 + _dither(ctx, 0.5, seed + 1)
    shade -= (1.0 - ctx.ao) * 2.5 + ctx.cavity(3.0) * 1.0
    s.use_ramp(P[ground], shade=shade)
    vmin = np.min(v) if ctx.N else 0.0
    vmax = np.max(v) if ctx.N else 0.0
    band = 7 * ctx.texel * scale
    k = greek_key(ctx, u, v, vmin + (vmax - vmin - band) * 0.5, scale)
    s.use_ramp(P["gold"], mask=k, shade=np.full(ctx.N, 6.6) + _dither(ctx, 1.2, seed + 2) - (1.0 - ctx.ao) * 2.0)
    s.metal = np.where(k, 0.85, 0.0)
    s.rough = np.where(k, 0.32, 0.28)
    s.height = k * 0.0006
    return s
