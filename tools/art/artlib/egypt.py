"""Materials of the Egypt wing (Floor I): sandstone and granites, Egyptian
paint on stone, plaster and gesso (sampled from the pixel canvases of
egypt_paint.py, one art pixel = one texel), gold, faience, calcite, the
mummy's linen and resin, the expedition's canvas, the scarab's shell, and
the wing's tileable fields (64 px/m).

Same rules as materials.py: every colour is a step on a hand-picked ramp in
P (dark -> light); shading moves along the ramp.
"""
import numpy as np

from . import arch_materials as A
from . import egypt_paint as EP
from . import noise
from .materials import P, _age, _dither, _grain_frame, _select, _wood_core, hexramp, smoothstep
from .materials import MATERIALS as BASE
from .painter import Surface

P.update({
    "sandstone": hexramp("#2a1f15", "#3e2e1f", "#534029", "#6a5234", "#81653f", "#97784c", "#ab8b5b",
                         "#bd9d6c", "#cdaf80", "#dbc196", "#e8d3ad"),
    "granite_red": hexramp("#1e0e0b", "#2f1611", "#422018", "#562b20", "#6b3729", "#7f4433", "#93523e",
                           "#a5614b", "#b67259", "#c58468"),
    "granite_pink": hexramp("#4a2a25", "#62382f", "#7b4a3d", "#945d4c", "#ab715d", "#c08670", "#d39d86"),
    "granite_black": hexramp("#08090a", "#0e1012", "#15181b", "#1c2024", "#24292e", "#2d3339", "#383f46",
                             "#454c54", "#535b63"),
    "granite_grey": hexramp("#121315", "#1a1c1f", "#23262a", "#2d3035", "#383c41", "#44484e", "#51565c",
                            "#5f646a", "#6e7379", "#7e8389"),
    "eg_blue": hexramp("#0b1830", "#122446", "#1a335e", "#234476", "#2e568d", "#3c69a2", "#4d7db4"),
    "eg_green": hexramp("#0d1f17", "#143023", "#1c4231", "#25553f", "#30694e", "#3d7d5e", "#4c916f"),
    "eg_red": hexramp("#2a0c07", "#41140b", "#5a1d10", "#742815", "#8e341b", "#a64323", "#bb552e"),
    "eg_yellow": hexramp("#3b2a0c", "#574011", "#745818", "#917120", "#ad8a2b", "#c6a23a", "#dab84d",
                         "#e8cc66"),
    "eg_white": hexramp("#6f6a5c", "#8a8473", "#a49d8a", "#bdb6a1", "#d2cbb5", "#e3ddc8", "#efeadb"),
    "eg_black": hexramp("#0a0806", "#14100c", "#1f1913", "#2a221b"),
    "eg_ground": hexramp("#5e5139", "#776849", "#90805b", "#a8986d", "#bdad80", "#cfc093", "#ddd0a6"),
    "eg_skin": hexramp("#4a1d0f", "#652a16", "#80381d", "#9a4826", "#b05a32", "#c26e42"),
    "turquoise": hexramp("#06201f", "#0b302e", "#11433f", "#185852", "#206e66", "#2b857a", "#399c8e",
                         "#4cb3a1", "#66c8b4"),
    "lapis": hexramp("#04081a", "#070d26", "#0b1433", "#101c42", "#162552", "#1e3064", "#283c77"),
    "calcite": hexramp("#4a4234", "#615847", "#7a705c", "#938972", "#aca189", "#c3b99f", "#d6cdb4",
                       "#e5ddc7"),
    "linen": hexramp("#24201a", "#342e25", "#453d31", "#574d3e", "#6a5f4c", "#7d715b", "#90836b", "#a3967c",
                     "#b4a88e"),
    "resin": hexramp("#070504", "#0f0a07", "#18100a", "#22170e", "#2d1e12", "#3a2716"),
    "skin_dry": hexramp("#1a110b", "#2a1b11", "#3b2717", "#4d341e", "#604226"),
    "canvas": hexramp("#3a3324", "#4f4631", "#655a40", "#7b6f51", "#918563", "#a69a76", "#b9ae8a",
                      "#cbc19d", "#d9d0b0"),
    "paper": hexramp("#5a4e38", "#74674b", "#8e815f", "#a79a74", "#bdb28a", "#d0c69f", "#e0d8b4"),
    "scarab": hexramp("#04100c", "#08201a", "#0c3027", "#0f4236", "#135546", "#1a6a57", "#2a7f5e",
                      "#4a8f4f", "#7a9a3c", "#b0a030", "#d8b23a"),
    "sun_glow": hexramp("#5a2a06", "#8a4a0c", "#b86c14", "#e0961f", "#f6c04a", "#ffe08a", "#fff4cc"),
    "flame": hexramp("#4a1a04", "#7a2e06", "#b04a0a", "#e07418", "#f9a53a", "#ffd27a", "#fff1c8"),
})

# canvas code -> (ramp, centre shade, roughness, metalness)
INKS = {
    EP.INK["outline"]: ("eg_red", 1.0, 0.7, 0.0),
    EP.INK["blue"]: ("eg_blue", 3.6, 0.75, 0.0),
    EP.INK["green"]: ("eg_green", 3.6, 0.75, 0.0),
    EP.INK["red"]: ("eg_red", 4.2, 0.72, 0.0),
    EP.INK["yellow"]: ("eg_yellow", 5.0, 0.7, 0.0),
    EP.INK["black"]: ("eg_black", 1.6, 0.6, 0.0),
    EP.INK["white"]: ("eg_white", 4.6, 0.75, 0.0),
    EP.INK["gold"]: ("gold", 6.4, 0.3, 1.0),
    EP.INK["skin_m"]: ("eg_skin", 3.4, 0.7, 0.0),
    EP.INK["skin_f"]: ("eg_yellow", 5.6, 0.7, 0.0),
    EP.INK["divider"]: ("eg_yellow", 2.2, 0.8, 0.0),
}


# --------------------------------------------------------------------------
# canvas sampling
# --------------------------------------------------------------------------

def rim_of(codes):
    """Per-pixel shading of painted shapes: +1 on the top-left rim (lit),
    -1 on the bottom-right rim, 0 inside."""
    c = codes
    H, W = c.shape
    r = np.zeros((H, W), dtype=np.int16)
    up = np.vstack([np.full((1, W), -1, np.int16), c[:-1]])
    left = np.hstack([np.full((H, 1), -1, np.int16), c[:, :-1]])
    down = np.vstack([c[1:], np.full((1, W), -1, np.int16)])
    right = np.hstack([c[:, 1:], np.full((H, 1), -1, np.int16)])
    painted = c > 0
    r[painted & ((up != c) | (left != c))] = 1
    r[painted & ((down != c) | (right != c))] = -1
    return r


def sample(canvas, u, v, texel, u0=0.0, v0=0.0, wrap_x=False, wrap_y=False, scale=1):
    """Codes under texels at metre coordinates (u, v): the canvas sits with
    its bottom-left corner at (u0, v0), one art pixel = ``scale`` texels;
    -1 outside. Returns (codes, rim)."""
    ix = np.floor((u - u0) / texel + 1e-6).astype(np.int64) // scale
    iy = np.floor((v - v0) / texel + 1e-6).astype(np.int64) // scale
    H, W = canvas.shape
    if wrap_x:
        ix = np.mod(ix, W)
    if wrap_y:
        iy = np.mod(iy, H)
    inside = (ix >= 0) & (ix < W) & (iy >= 0) & (iy < H)
    codes = np.full(len(u), -1, np.int16)
    rims = np.zeros(len(u), np.int16)
    rows = H - 1 - iy[inside]
    codes[inside] = canvas[rows, ix[inside]]
    rims[inside] = rim_of(canvas)[rows, ix[inside]]
    return codes, rims


def paint_over(ctx, s, codes, rims, seed=0, flake=0.35, relief=0.0, wear=1.0, inks=None):
    """Lays Egyptian paint (canvas codes) over the surface ``s``: each code on
    its ramp, the rims of shapes shaded, flakes of lost paint showing the
    ground with a dark lip, faded where the surface is worn (edges, AO).
    ``relief`` < 0 sinks the painted shapes (sunk relief), > 0 raises them."""
    inks = INKS if inks is None else inks
    painted = codes > 0
    if not painted.any():
        return s
    fl = ctx.fbm(9.0, 3, seed + 1) + ctx.fbm(34.0, 2, seed + 2) * 0.35 + ctx.edge_soft(3.0) * 0.6 * wear
    thr = 0.62 - 0.45 * flake
    lost = painted & (fl > thr)
    lip = painted & ~lost & (fl > thr - 0.07)
    keep = painted & ~lost
    fade = ctx.fbm(2.2, 3, seed + 3) * 0.6 + _dither(ctx, 0.6, seed + 4)
    for code in np.unique(codes[keep]):
        if code not in inks:
            continue
        ramp, center, rough, metal = inks[int(code)]
        m = keep & (codes == code)
        sh = center + rims * 0.8 + fade - (1.0 - ctx.ao) * 2.5 - ctx.cavity(3.0) * 1.5
        s.use_ramp(P[ramp], mask=m, shade=sh)
        s.rough[m] = rough + ctx.rand(seed + 5)[m] * 0.05
        s.metal[m] = metal
    s.shade[lip] -= 1.2
    if relief != 0.0:
        s.height = s.height + np.where(painted, relief, 0.0)
        s.shade[painted & ~keep] -= 0.6 if relief < 0 else 0.0
    return s


def carve(ctx, s, mask, depth=0.0025, shade=-1.6, rim=None):
    """Sunk relief: the masked texels are cut ``depth`` into the surface and
    darkened (no paint)."""
    s.height = s.height - mask * depth
    s.shade[mask] += shade
    if rim is not None:
        s.shade[mask & (rim > 0)] -= 0.8
        s.shade[mask & (rim < 0)] += 0.9
    return s


# --------------------------------------------------------------------------
# stone
# --------------------------------------------------------------------------

def sandstone(ctx, seed=503, center=5.8, strata=1.0):
    """Nubian sandstone: warm buff with thin bedding laminae (wavy horizontal
    lines), iron-stained clouds, pits; bright arrises, dark hollows."""
    s = Surface(ctx.N)
    z = ctx.p[:, 2]
    wav = ctx.fbm(np.array([0.8, 0.8, 0.8]), 2, seed + 7) * 0.06
    lam = np.sin((z + wav) * 2.0 * np.pi * 6.0 + ctx.fbm(np.array([0.4, 0.4, 2.0]), 2, seed) * 3.0)
    show = smoothstep(0.05, 0.4, ctx.fbm(0.9, 3, seed + 9))
    bed = (smoothstep(0.85, 0.98, lam) * 0.5 - smoothstep(0.88, 0.99, -lam) * 0.45) * strata * show
    bed += ctx.fbm(np.array([0.7, 0.7, 4.0]), 3, seed + 8) * 0.45 * strata
    stain = smoothstep(0.15, 0.65, ctx.fbm(1.1, 4, seed + 1))
    base = (center + ctx.fbm(1.2, 4, seed + 2) * 0.8 + ctx.fbm(7.0, 2, seed + 10) * 0.35 + bed
            + _dither(ctx, 0.6, seed + 3) - stain * 1.1)
    f1, _, cid = ctx.worley(18.0, seed + 4)
    pits = (f1 < 0.1) & (cid > 0.7)
    base -= pits * 1.4
    s.use_ramp(P["sandstone"], shade=base)
    _age(ctx, s, cavity=2.4, ao=4.0, edge=1.3)
    s.height = ctx.fbm(12.0, 3, seed + 5) * 0.0008 - pits * 0.0015 + bed * 0.0003
    s.rough = 0.84 + ctx.rand(seed + 6) * 0.08
    return s


def sandstone_ashlar(ctx, seed=509):
    """Temple ashlar for the gallery walls: 0.75 m courses of big blocks
    (1-2.25 m) in a broken bond, tight joints (a texel, a shade darker) with
    a lit arris over them, each block a slightly different tone, the bedding
    laminae running through, a few chipped corners and rain-like grime under
    the arrises. Tile 6 x 3 m (courses every 0.75 m from y = 0)."""
    W, H = 6.0, 3.0
    courses = A.course_layout(W, [0.75] * 4, [1.0, 1.25, 1.5, 1.75, 2.0, 2.25], seed, step=0.25)
    u = ctx.uvm[:, 0]
    v = ctx.uvm[:, 1]
    course, bid, dl, dr, db, dt = A.blocks(u, v, W, H, courses)
    tone = noise.rand_cells(bid, seed + 1) - 0.5
    s = sandstone(ctx, seed + 2, center=6.0, strata=0.9)
    s.shade += tone * 0.9
    tx = ctx.texel
    joint = (dl < tx) | (db < tx)
    near = ~joint & ((dl < 2.0 * tx) | (db < 1.5 * tx))
    arris = ~joint & ((dt < 1.0 * tx) | (dr < 1.0 * tx))
    s.shade[joint] -= 2.4
    s.shade[near] -= 0.7
    s.shade[arris] += 0.9
    corner = (np.minimum(dl, dr) < 0.05) & (np.minimum(db, dt) < 0.05) & (noise.rand_cells(bid, seed + 4) > 0.7)
    s.shade[corner] -= 1.2
    streak = smoothstep(0.25, 0.8, ctx.fbm(np.array([6.0, 6.0, 0.5]), 3, seed + 5)) * smoothstep(0.6, 0.0, dt)
    s.shade -= streak * 0.8
    s.height = s.height - joint * 0.003 - near * 0.0008 - corner * 0.003
    s.rough = np.where(joint, 0.95, s.rough)
    return s


def granite(ctx, kind="red", seed=521, polish=0.18, center=None, grain=1.0):
    """Granite and granodiorite: a mosaic of crystals a few texels across -
    pink (red granite) or white feldspar, black biotite and hornblende in
    clumps, glassy grey quartz - over a faint cloudy tone; polished (low
    roughness: the moon in it) or dressed. ``grain`` < 1 calms the mosaic
    (big sculpture seen from afar: the form must read, not the crystals)."""
    mix = {  # (feldspar, quartz, dark) shares; the rest is the matrix tone
        "red": (0.42, 0.16, 0.2), "black": (0.16, 0.06, 0.52), "grey": (0.3, 0.22, 0.26)}[kind]
    ramp = {"red": "granite_red", "black": "granite_black", "grey": "granite_grey"}[kind]
    c0 = {"red": 4.8, "black": 3.2, "grey": 4.0}[kind] if center is None else center
    s = Surface(ctx.N)
    cloud = ctx.fbm(1.3, 4, seed) * 0.9
    # crystals stay ~2-3 texels at 64 px/m and shrink toward their real
    # size (~1 cm) on denser atlases
    k = min(3.0, max(1.0, (1.0 / 64.0) / ctx.texel * 0.8))
    f1, f2, cid = ctx.worley(26.0 * k, seed + 1)
    g1, _, gid = ctx.worley(55.0 * k, seed + 2)
    clump = ctx.fbm(6.0, 2, seed + 3) * 0.25
    r = np.mod(cid + clump, 1.0)
    feld = r < mix[0]
    quartz = (r >= mix[0]) & (r < mix[0] + mix[1])
    dark = (r >= mix[0] + mix[1]) & (r < mix[0] + mix[1] + mix[2])
    dark |= (gid < 0.18) & (g1 < 0.35)
    cell = noise.rand_cells(np.floor(cid * 9973).astype(np.int64), seed + 4) - 0.5
    g = grain
    if g < 1.0:
        # calm sculpture stone: one ramp, crystals as gentle steps on it and
        # only a sprinkling of dark ones
        keep = noise.rand_cells(np.floor(cid * 7919).astype(np.int64), seed + 11) < g * 0.45
        shade = c0 + cloud + cell * 0.7 * g + _dither(ctx, 0.3, seed + 5)
        shade += feld * 1.1 * g + quartz * 0.5 * g
        s.use_ramp(P[ramp], shade=shade)
        s.use_ramp(P["granite_black"], mask=dark & keep, shade=np.full(ctx.N, 2.4) + _dither(ctx, 0.6, seed + 7))
    else:
        shade = c0 + cloud + cell * 1.4 + _dither(ctx, 0.5, seed + 5)
        s.use_ramp(P[ramp], shade=shade)
        if kind == "red":
            s.use_ramp(P["granite_pink"], mask=feld & ~dark, shade=3.6 + cloud + cell * 1.6 + _dither(ctx, 0.6, seed + 6))
        else:
            s.use_ramp(P["granite_grey"], mask=feld & ~dark, shade=(7.4 if kind == "grey" else 6.0) + cell * 1.4
                       + _dither(ctx, 0.6, seed + 6))
        s.use_ramp(P["granite_black"], mask=dark, shade=np.full(ctx.N, 1.4) + cell * 1.0 + _dither(ctx, 0.6, seed + 7))
        s.use_ramp(P["granite_grey"], mask=quartz & ~dark, shade=np.full(ctx.N, 5.0) + cell * 1.2)
    s.shade += ctx.edge(1.0) * 1.3
    s.shade -= ctx.cavity(3.0) * 2.0 + (1.0 - ctx.ao) * 3.5
    s.rough = polish + np.clip(ctx.fbm(2.5, 3, seed + 8), 0, 1) * 0.18 + ctx.rand(seed + 9) * 0.03
    s.rough = np.where(quartz, s.rough * 0.7, s.rough)
    s.height = (feld * 0.0002 - dark * 0.0002) + ctx.fbm(20.0, 2, seed + 10) * 0.0002
    return s


def granite_dressed(ctx, kind="red", seed=531):
    """Weathered, pick-dressed granite (backs, undersides, broken faces)."""
    s = granite(ctx, kind, seed, polish=0.62)
    pock = ctx.worley(26.0, seed + 11)[0] < 0.18
    s.shade[pock] -= 1.0
    s.height = s.height - pock * 0.0012 + ctx.fbm(9.0, 3, seed + 12) * 0.0012
    return s


def granite_floor(ctx, seed=541):
    """Gallery floor: polished dark granite slabs 2 x 1 m in running bond
    (rows shifted 1 m), one tone per slab, a texel of grout, worn paths a
    little duller, here and there a hairline crack. Tile 4 x 4 m."""
    u = ctx.uvm[:, 0]
    v = ctx.uvm[:, 1]
    row = np.floor(v / 1.0 + 1e-9).astype(np.int64)
    shift = np.mod(row, 2) * 1.0
    col = np.floor((u + shift) / 2.0 + 1e-9).astype(np.int64)
    fx = (u + shift) - col * 2.0
    fz = v - row * 1.0
    sid = np.mod(row, 4) * 16 + np.mod(col, 2)
    tone = noise.rand_cells(sid, seed) - 0.5
    s = granite(ctx, "grey", seed + 1, polish=0.1, center=3.6)
    s.shade += tone * 1.4
    tx = ctx.texel
    grout = (fx < tx) | (fz < tx)
    near = ~grout & ((fx < 2 * tx) | (fz < 2 * tx) | (fx > 2.0 - tx) | (fz > 1.0 - tx))
    s.shade[near] += 0.7
    crack = (np.abs(ctx.fbm(1.7, 4, seed + 2)) < 0.01) & (noise.rand_cells(sid, seed + 3) > 0.7)
    s.shade[crack] -= 2.0
    s.use_ramp(P["grout"], mask=grout, shade=np.full(ctx.N, 1.6) + _dither(ctx, 0.8, seed + 4))
    path = smoothstep(0.15, 0.7, ctx.fbm(np.array([0.7, 1.0, 0.25]), 3, seed + 5))
    s.rough = np.where(grout, 0.9, s.rough + path * 0.22)
    s.height = np.where(grout, -0.003, 0.0) - crack * 0.0008 + near * 0.0003
    return s


def granite_red_field(ctx, seed=547):
    """Polished red granite as a field (dado panels, plinth faces). Tile 2 x 2."""
    return granite(ctx, "red", seed, polish=0.16)


# --------------------------------------------------------------------------
# painted fields
# --------------------------------------------------------------------------

def star_ceiling(ctx, seed=553):
    """The night sky of a tomb ceiling: lapis-blue paint in brushy strokes,
    yellow five-pointed stars in staggered rows every 0.25 m (a few with a red
    heart), paint flaking to the white plaster, soot near the walls. Tile 4 x
    4 m."""
    u = ctx.uvm[:, 0]
    v = ctx.uvm[:, 1]
    tx = ctx.texel
    s = Surface(ctx.N)
    stroke = ctx.fbm(np.array([4.0, 1.0, 40.0]), 2, seed) * 0.6
    s.use_ramp(P["lapis"], shade=3.6 + stroke + ctx.fbm(1.5, 3, seed + 1) * 0.8 + _dither(ctx, 0.6, seed + 2))
    pitch = 0.25
    rowi = np.floor(v / pitch + 1e-9).astype(np.int64)
    off = np.mod(rowi, 2) * pitch * 0.5
    coli = np.floor((u + off) / pitch + 1e-9).astype(np.int64)
    lu = np.floor(((u + off) - coli * pitch) / tx + 1e-6).astype(np.int64)
    lv = np.floor((v - rowi * pitch) / tx + 1e-6).astype(np.int64)
    sm = EP.star_mask()
    k = sm.shape[0]
    c0 = int(round(pitch / tx)) // 2 - k // 2
    ii = lu - c0
    jj = lv - c0
    inside = (ii >= 0) & (ii < k) & (jj >= 0) & (jj < k)
    star = np.zeros(ctx.N, dtype=bool)
    star[inside] = sm[k - 1 - jj[inside], ii[inside]]
    heart = inside & (ii == k // 2) & (jj == k // 2 - 1 + 1) & (noise.hash_float(coli, rowi, rowi * 0, seed) > 0.7)
    s.use_ramp(P["eg_yellow"], mask=star, shade=np.full(ctx.N, 5.6) + _dither(ctx, 0.8, seed + 3))
    s.use_ramp(P["eg_red"], mask=heart, shade=np.full(ctx.N, 4.0))
    fl = ctx.fbm(1.6, 4, seed + 4) + ctx.fbm(12.0, 2, seed + 5) * 0.18
    lost = fl > 0.5
    lip = (fl > 0.46) & ~lost
    s.use_ramp(P["eg_white"], mask=lost, shade=np.full(ctx.N, 3.4) + ctx.fbm(9.0, 2, seed + 6) * 0.8
               + _dither(ctx, 0.7, seed + 7))
    s.shade[lip] -= 1.0
    s.rough = np.where(lost, 0.92, 0.8) + ctx.rand(seed + 8) * 0.05
    s.height = np.where(lost, -0.0008, 0.0) + stroke * 0.0002
    return s


_FRIEZE = {}


def _frieze_canvas(seed=17):
    """512 x 64 px (8 x 1 m): block borders, two lines of large signs (each
    art pixel 2 x 2 texels) and a pair of royal cartouches every 8 m."""
    if seed in _FRIEZE:
        return _FRIEZE[seed]
    W, H = 512, 64
    c = np.zeros((H, W), dtype=np.int16)
    bb = EP.block_border(W, 6)
    c[0:6] = bb
    c[6, :] = EP.INK["black"]
    c[57, :] = EP.INK["black"]
    c[58:64] = bb
    import random
    rng = random.Random(seed)
    x = 4
    k = 0
    while x + 20 <= W - 4:
        if k in (6, 15):
            cart = EP.cartouche(rng, 10, 22)
            big = np.repeat(np.repeat(cart, 2, 0), 2, 1)
            c[9:9 + big.shape[0], x:x + big.shape[1]] = np.where(big > 0, big, c[9:9 + big.shape[0], x:x + big.shape[1]])
            x += 24
            k += 1
            continue
        for line, y0 in ((0, 10), (1, 33)):
            q = EP.quadrat(rng, 10)
            big = np.repeat(np.repeat(q, 2, 0), 2, 1)
            reg = c[y0:y0 + 20, x:x + 20]
            c[y0:y0 + 20, x:x + 20] = np.where(big > 0, big, reg)
        x += 24
        k += 1
    _FRIEZE[seed] = c
    return c


def hieroglyph_band(ctx, seed=557):
    """The gallery frieze: block borders and two lines of large painted
    hieroglyphs with royal cartouches, sunk into dressed sandstone, the paint
    flaking. Tile 8 x 1 m (one band per metre of height)."""
    s = sandstone(ctx, seed, center=6.2, strata=0.4)
    codes, rims = sample(_frieze_canvas(), ctx.uvm[:, 0], ctx.uvm[:, 1], ctx.texel, wrap_x=True, wrap_y=True)
    big_rims = rims
    s = paint_over(ctx, s, codes, big_rims, seed + 1, flake=0.35, relief=-0.002)
    return s


_TOMB = {}


def _tomb_canvas(seed=29):
    """512 x 256 px (8 x 4 m) tomb wall: kheker frieze, an upper register of
    seated gods receiving offerings with columns of text, a procession of
    offering bearers under a line of text, a dark dado."""
    if seed in _TOMB:
        return _TOMB[seed]
    import random
    rng = random.Random(seed)
    W, H = 512, 256
    c = np.zeros((H, W), dtype=np.int16)
    c[0:36] = EP.kheker(W, 36, 8)
    bb = EP.block_border(W, 6)
    c[36:42] = bb
    # upper register (rows 42-121): two scenes of a god before an offering table
    for unit, (head, sex) in enumerate((("jackal", "m"), ("human", "f"))):
        x0 = unit * 256
        EP.figure(c, x0 + 200, 119, 74, pose="seated", head=head, flip=True, seed=unit + 1)
        EP.offering_table(c, x0 + 160, 119, 62)
        EP.figure(c, x0 + 118, 119, 72, pose="adore", sex="m", seed=unit)
        EP.figure(c, x0 + 76, 119, 72, pose="bearer", sex=sex, offering="lotus", seed=unit + 2)
        cols = EP.text_columns(4, 6, seed + unit, col_w=12, cell=10, gap=1, cartouches=0.0)
        c[44:44 + cols.shape[0], x0 + 2:x0 + 2 + cols.shape[1]] = np.where(
            cols > 0, cols, c[44:44 + cols.shape[0], x0 + 2:x0 + 2 + cols.shape[1]])
        cols = EP.text_columns(3, 2, seed + 7 + unit, col_w=12, cell=10, gap=1)
        c[44:44 + cols.shape[0], x0 + 218:x0 + 218 + cols.shape[1]] = np.where(
            cols > 0, cols, c[44:44 + cols.shape[0], x0 + 218:x0 + 218 + cols.shape[1]])
    c[122:128] = bb
    # lower register (rows 128-211): a procession walking right under a text line
    line = EP.text_line(W, seed + 3)
    c[130:140] = np.where(line > 0, line, c[130:140])
    offers = ["jar", "tray", "bird", "lotus"]
    for k in range(7):
        x = 22 + k * 73
        sex = "f" if k % 3 == 1 else "m"
        EP.figure(c, x, 209, 66, pose="bearer", sex=sex, offering=offers[(k + rng.randrange(4)) % 4], seed=k + 5)
    c[212:218] = bb
    # dado: dark red with a black band
    c[218:221] = EP.INK["black"]
    c[221:256] = EP.INK["red"]
    _TOMB[seed] = c
    return c


def tomb_wall(ctx, seed=563):
    """A painted tomb chapel wall on a warm ochre plaster ground (kheker
    frieze, gods and offerings, a procession of bearers, a red dado), the
    paint flaking, soot over the lower half. Tile 8 x 4 m."""
    s = Surface(ctx.N)
    s.use_ramp(P["eg_ground"], shade=4.6 + ctx.fbm(2.0, 3, seed) * 0.7 + ctx.fbm(11.0, 2, seed + 1) * 0.3
               + _dither(ctx, 0.6, seed + 2))
    s.rough = np.full(ctx.N, 0.88)
    s.height = ctx.fbm(14.0, 3, seed + 3) * 0.0006
    codes, rims = sample(_tomb_canvas(), ctx.uvm[:, 0], ctx.uvm[:, 1], ctx.texel, wrap_x=True, wrap_y=True)
    s = paint_over(ctx, s, codes, rims, seed + 4, flake=0.25, relief=0.0, wear=0.0)
    dado = (codes == EP.INK["red"]) & (ctx.uvm[:, 1] % 4.0 < 0.6)
    s.shade[dado] += ctx.fbm(30.0, 2, seed + 5)[dado] * 0.8 - 0.6
    soot = smoothstep(0.1, 0.6, ctx.fbm(np.array([1.2, 1.0, 0.5]), 3, seed + 6)) * 1.0
    s.shade -= soot
    return s


# --------------------------------------------------------------------------
# other materials
# --------------------------------------------------------------------------

def plaster_white(ctx, seed=571):
    s = Surface(ctx.N)
    s.use_ramp(P["eg_white"], shade=4.4 + ctx.fbm(3.0, 3, seed) * 0.7 + _dither(ctx, 0.6, seed + 1))
    _age(ctx, s, cavity=2.0, ao=3.5, edge=0.8)
    s.rough = np.full(ctx.N, 0.9)
    return s


def gold_leaf(ctx, seed=577, worn=0.6):
    """Burnished gold leaf on gesso, rubbed through to the red bole on the
    high points and arrises."""
    s = BASE["gold"](ctx, seed)
    s.shade += 0.4
    return s


def faience(ctx, seed=583, ramp="turquoise", center=5.2):
    """Egyptian faience: glossy turquoise glaze, pooling darker in the
    hollows and thin (paler) on the edges, fine crazing, black details."""
    s = Surface(ctx.N)
    shade = center + ctx.fbm(5.0, 3, seed) * 0.6 + _dither(ctx, 0.5, seed + 1)
    shade += ctx.edge(1.0) * 1.4 + np.clip(ctx.curv, 0, 1) * 1.2
    shade -= ctx.cavity(3.0) * 2.4 + (1.0 - ctx.ao) * 3.5 + np.clip(-ctx.curv, 0, 1) * 1.5
    f1, f2, _ = ctx.worley(30.0, seed + 2)
    craze = (f2 - f1) < 0.04
    shade -= craze * 0.9
    s.use_ramp(P[ramp], shade=shade)
    s.rough = np.where(craze, 0.35, 0.14) + ctx.rand(seed + 3) * 0.03
    s.height = craze * -0.0002
    return s


def calcite(ctx, seed=587, center=5.2):
    """Egyptian alabaster (calcite): creamy, softly banded in wavy layers,
    waxy polish."""
    s = Surface(ctx.N)
    q = ctx.p + np.stack([ctx.fbm(1.5, 2, seed + 1), ctx.fbm(1.5, 2, seed + 2), ctx.fbm(1.5, 2, seed + 3)], 1) * 0.06
    band = np.sin(q[:, 2] * 70.0 + q[:, 0] * 9.0) * 0.5 + ctx.fbm(np.array([2.0, 2.0, 14.0]), 3, seed + 4) * 0.8
    shade = center + band * 1.0 + _dither(ctx, 0.5, seed + 5)
    shade += np.clip(ctx.curv, 0, 1) * 1.0 + ctx.edge(1.0) * 0.8
    shade -= ctx.cavity(3.0) * 2.0 + (1.0 - ctx.ao) * 3.5 + np.clip(-ctx.curv, 0, 1) * 1.2
    s.use_ramp(P["calcite"], shade=shade)
    s.rough = 0.28 + ctx.rand(seed + 6) * 0.05
    s.sss = np.full(ctx.N, 0.4)
    return s


def canvas_cloth(ctx, seed=593, center=5.4, stains=1.0):
    """Expedition canvas: plain weave, sun-bleached, rain and tea stains,
    darker where it folds."""
    s = Surface(ctx.N)
    u = ctx.uvm[:, 0] / ctx.texel
    v = ctx.uvm[:, 1] / ctx.texel
    weave = ((np.floor(u) + np.floor(v)) % 2) * 0.35
    st = smoothstep(0.25, 0.7, ctx.fbm(1.8, 4, seed)) * stains
    ring = (np.abs(ctx.fbm(2.5, 3, seed + 1)) < 0.03) & (ctx.fbm(1.0, 2, seed + 2) > 0.2)
    shade = center + weave + ctx.fbm(4.0, 3, seed + 3) * 0.6 + _dither(ctx, 0.5, seed + 4) - st * 1.6 - ring * 1.2
    shade += np.clip(ctx.curv, 0, 1) * 1.2 + ctx.edge_soft(2.0) * 0.8
    shade -= np.clip(-ctx.curv, 0, 1) * 1.8 + ctx.cavity(3.0) * 2.0 + (1.0 - ctx.ao) * 3.5
    s.use_ramp(P["canvas"], shade=shade)
    s.rough = np.full(ctx.N, 0.93)
    s.height = weave * 0.0002
    return s


def paper(ctx, seed=599, center=4.6):
    s = Surface(ctx.N)
    shade = center + ctx.fbm(6.0, 3, seed) * 0.6 + _dither(ctx, 0.5, seed + 1)
    shade -= smoothstep(0.3, 0.8, ctx.fbm(2.0, 3, seed + 2)) * 1.2 + (1.0 - ctx.ao) * 3.0
    s.use_ramp(P["paper"], shade=shade)
    s.rough = np.full(ctx.N, 0.88)
    return s


def resin(ctx, seed=601):
    """Embalming resin / bitumen: near-black brown, glossy, lumpy."""
    s = Surface(ctx.N)
    lump = ctx.fbm(16.0, 3, seed)
    s.use_ramp(P["resin"], shade=2.6 + lump * 1.2 + _dither(ctx, 0.6, seed + 1) + ctx.edge(1.0) * 1.0
               - (1.0 - ctx.ao) * 2.0)
    s.rough = 0.22 + np.clip(lump, 0, 1) * 0.2
    s.height = lump * 0.0012
    return s


def scarab_shell(ctx, seed=607):
    """Iridescent beetle shell: deep green in the middle of each convex plate
    shifting through teal and olive to gold at the rims (fake structural
    colour from the surface tilt), lacquer-glossy, metallic."""
    s = Surface(ctx.N)
    tilt = 1.0 - np.clip(ctx.n[:, 2], 0.0, 1.0)
    shade = 3.2 + tilt * 6.0 + ctx.fbm(60.0, 2, seed) * 0.6 + _dither(ctx, 0.6, seed + 1)
    shade += ctx.edge(1.0) * 1.5 - ctx.cavity(2.0) * 2.0 - (1.0 - ctx.ao) * 2.5
    s.use_ramp(P["scarab"], shade=shade)
    s.metal = np.full(ctx.N, 0.75)
    s.rough = 0.18 + ctx.rand(seed + 2) * 0.05
    return s


def glow(ctx, ramp="sun_glow", center=4.5, strength=1.0, seed=613, flicker=0.6):
    """Self-lit core (the colossus's cracks, its eyes, a lamp flame)."""
    s = Surface(ctx.N)
    shade = center + ctx.fbm(20.0, 2, seed) * flicker + _dither(ctx, 0.5, seed + 1)
    s.use_ramp(P[ramp], shade=shade)
    s.rough = np.full(ctx.N, 0.4)
    s.emit = s.colors() * strength
    return s


# --------------------------------------------------------------------------
# painted mouldings (kit atlases)
# --------------------------------------------------------------------------

def px(ctx):
    """Whole-texel coordinates (u, v) of the surface's metre UVs."""
    u = ctx.uvm[:, 0]
    v = ctx.uvm[:, 1]
    return (np.floor(u / ctx.texel + 1e-6).astype(np.int64), np.floor(v / ctx.texel + 1e-6).astype(np.int64))


def binding(ctx, seed=11):
    """Painted torus roll: the binding of a reed bundle - slanting bands of
    red and blue/green separated by thin white lines, over sandstone."""
    s = sandstone(ctx, seed, center=6.0, strata=0.2)
    ix, iy = px(ctx)
    k = np.mod(ix + iy, 16)
    codes = np.zeros(ctx.N, np.int16)
    codes[k < 5] = EP.INK["red"]
    codes[(k >= 6) & (k < 7)] = EP.INK["white"]
    codes[(k >= 7) & (k < 14)] = np.where(np.mod((ix + iy) // 16, 2) == 0, EP.INK["blue"], EP.INK["green"])[(k >= 7) & (k < 14)]
    codes[(k >= 14) & (k < 15)] = EP.INK["white"]
    rims = np.zeros(ctx.N, np.int16)
    return paint_over(ctx, s, codes, rims, seed + 1, flake=0.3)


def leaves(ctx, seed=13, cove_len=None):
    """The cavetto's palm leaves: 8-texel cells (0.125 m), a leaf 6 texels
    wide with a darker midrib and a rounded tip, colours in a 4-cell cycle;
    the ground is pale ochre."""
    s = sandstone(ctx, seed, center=6.6, strata=0.2)
    ix, iy = px(ctx)
    cell = np.floor_divide(ix, 8)
    lx = ix - cell * 8
    top = int(round((cove_len or 0.8) / ctx.texel)) - 5
    body = (lx >= 1) & (lx <= 6) & (iy < top)
    tip = (lx >= 2) & (lx <= 5) & (iy >= top) & (iy < top + 2)
    tip |= (lx >= 3) & (lx <= 4) & (iy >= top + 2) & (iy < top + 3)
    leaf = body | tip
    colour = np.array((EP.INK["blue"], EP.INK["green"], EP.INK["red"], EP.INK["green"]), np.int16)[np.mod(cell, 4)]
    codes = np.where(leaf, colour, 0).astype(np.int16)
    rib = leaf & ((lx == 3) | (lx == 4)) & (iy < top)
    rims = np.where(rib, -1, np.where(leaf & ((lx == 1) | (lx == 6)), 1, 0)).astype(np.int16)
    # a red band at the foot of the cove
    codes[iy < 3] = EP.INK["red"]
    return paint_over(ctx, s, codes, rims, seed + 1, flake=0.3)



MATERIALS = {
    "sandstone": sandstone,
    "sandstone_ashlar": sandstone_ashlar,
    "granite_floor": granite_floor,
    "granite_red": granite_red_field,
    "star_ceiling": star_ceiling,
    "hieroglyph_band": hieroglyph_band,
    "tomb_wall": tomb_wall,
}
