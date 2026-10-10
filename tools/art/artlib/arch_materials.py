"""Materials of the lobby architecture kit: per-room tileable textures (64 px/m,
mapped world-triplanar in the game) and the stone / timber / paint functions
the kit models bake into their atlases.

Same rules as materials.py: every colour comes from a hand-picked ramp in P
(registered here, dark -> light), shading = steps along a ramp. Block and
course layouts are periodic in the tile, so a texture tiles seamlessly and
its joints line up with the world grid (courses every 0.5 m from y = 0).

Rooms: hall = limestone (rusticated below the balcony, ashlar above) and a
cream / grey marble floor with red diamonds; armory = coursed rubble and
flagstones; diorama = painted panorama backdrop and flocked grass; security
= two-tone institutional paint, linoleum, acoustic tiles; corridors =
plaster and concrete; closet / secret rooms = brick with plaster patches and
floorboards; terrazzo for the diorama walkway.
"""
import numpy as np

from . import font, noise
from .materials import (P, _age, _dither, _grain_frame, _marble_core, _select, _wood_core, hexramp, smoothstep)
from .painter import Surface, combine

P.update({
    "limestone": hexramp("#3a3631", "#4c4740", "#5f5950", "#736c62", "#878075", "#9b9488", "#afa89b",
                         "#c1baad", "#d1cbbf", "#dfdacf", "#ebe7de"),
    "marble_cream": hexramp("#4a4238", "#5e5548", "#72685a", "#877c6c", "#9c907e", "#b0a390", "#c3b6a2",
                            "#d3c7b3", "#e1d6c3", "#ece3d2"),
    "marble_cream_vein": hexramp("#5a4a3a", "#6f5c48", "#857058", "#9a846a"),
    "marble_grey": hexramp("#1c1f24", "#262a31", "#31363e", "#3d434c", "#4a515b", "#58606b", "#676f7b",
                           "#767e8a"),
    "marble_grey_vein": hexramp("#8a929d", "#a2a9b2", "#bcc1c7", "#d4d7db"),
    "terrazzo": hexramp("#35332f", "#44423d", "#54514b", "#65625a", "#77736a", "#89857b", "#9c978c",
                        "#aea99d", "#bdb6a9"),
    "concrete": hexramp("#252524", "#31312f", "#3e3d3b", "#4c4b48", "#5b5a56", "#6b6965", "#7b7974",
                        "#8c8a84", "#9d9b95"),
    "lino_red": hexramp("#220b09", "#2f100c", "#3d1510", "#4b1b14", "#5a2219", "#6a2a1f", "#7b3326"),
    "lino_cream": hexramp("#4d4637", "#615844", "#766c53", "#8b8063", "#a09474", "#b4a886", "#c6bb99",
                          "#d5cbab"),
    "acoustic": hexramp("#5b5850", "#6d6a61", "#807c72", "#938f84", "#a6a296", "#b8b4a8", "#c9c5b9",
                        "#d7d3c7", "#e3dfd4"),
    "stain": hexramp("#4a3c26", "#5e4d31", "#73603d", "#88744b"),
    "paint_institution": hexramp("#3b433e", "#4b544e", "#5c665f", "#6e7870", "#808b82", "#939d94", "#a5afa5",
                                 "#b7c0b5", "#c6cec3"),
    "paint_institution_dark": hexramp("#0b1510", "#102019", "#162a21", "#1d352a", "#244134", "#2c4e3f",
                                      "#355b4a", "#3f6956"),
    "rubble": hexramp("#1e1b18", "#29251f", "#353028", "#433c32", "#51493d", "#605749", "#706656",
                      "#817665", "#928775"),
    "rubble_warm": hexramp("#241e19", "#302821", "#3d332a", "#4b3f34", "#5a4c3f", "#6a5a4b", "#7a6957"),
    "mortar": hexramp("#2b2925", "#39362f", "#48443b", "#575248", "#676156", "#787165"),
    "flag": hexramp("#1d1c1a", "#272523", "#32302d", "#3e3b37", "#4a4742", "#57534d", "#65605a",
                    "#736e67", "#827c74"),
    "brick": hexramp("#240c08", "#35130c", "#471a10", "#5a2216", "#6c2b1c", "#7e3524", "#8f412d",
                     "#9f4e37", "#ad5c43"),
    "pine_worn": hexramp("#1d1610", "#281e15", "#34281c", "#413224", "#4f3d2c", "#5e4935", "#6d563f",
                         "#7d644a", "#8d7356"),
    "timber": hexramp("#120c07", "#1b120b", "#25190f", "#302014", "#3c2819", "#48301e", "#553924",
                      "#63432a"),
    "flock": hexramp("#0b1609", "#11200d", "#172b12", "#1e3616", "#26421b", "#2f4f21", "#395d27",
                     "#446b2e", "#507a36"),
    "straw": hexramp("#3f3215", "#57461e", "#6f5a29", "#887036", "#a08745", "#b69d57"),
    "enamel_green": hexramp("#04140a", "#082212", "#0d321b", "#134426", "#1b5a33", "#257242", "#328c55",
                            "#45a86b"),
    "enamel_red": hexramp("#1f0304", "#340507", "#4c080a", "#660c0e", "#821214", "#9e1b1b", "#b82a26",
                          "#cc3d35"),
    "paint_grey": hexramp("#15171a", "#1e2125", "#282c31", "#33373d", "#3f444b", "#4c525a", "#5a606a",
                          "#69707a", "#79808b"),
    "paint_cream": hexramp("#403b30", "#554f41", "#6b6453", "#817a66", "#978f79", "#aca48d", "#c0b8a1",
                           "#d1c9b3"),
    "azure": hexramp("#050a1c", "#08112b", "#0c193c", "#11224e", "#172d62", "#1f3a77", "#29488b",
                     "#36589e"),
    "sign_green": hexramp("#021a0a", "#043012", "#07481c", "#0b6428", "#128236", "#1ea046", "#35bf5c",
                          "#5ada7c"),
    "sign_white": hexramp("#7d8a82", "#a5b3aa", "#cad6ce", "#e6efe9", "#f7fbf8"),
})


# --------------------------------------------------------------------------
# periodic block layouts
# --------------------------------------------------------------------------

def course_layout(W, heights, choices, seed, step=0.25):
    """Courses for a tile W metres wide: [(z0, z1, phase, cum)], ``cum`` =
    block ends from 0 (the last one = W), lengths drawn from ``choices``;
    each course is shifted by a random ``phase`` (a multiple of ``step``)."""
    rng = np.random.default_rng(seed)
    out = []
    z = 0.0
    for k, h in enumerate(heights):
        lengths = []
        total = 0.0
        while total < W - 1e-6:
            left = W - total
            pick = float(rng.choice(choices))
            if pick > left - min(choices) + 1e-6:
                pick = left
            lengths.append(pick)
            total += pick
        cum = np.cumsum(lengths)
        phase = step * int(rng.integers(0, max(1, int(round(W / step)))))
        out.append((z, z + h, phase, cum))
        z += h
    return out


def blocks(u, v, W, H, courses):
    """Per-point block info for a periodic course layout: course index, block
    id, and the distances (metres) to the block's left, right, bottom and top
    joints. u, v in metres (wrapped into the W x H tile)."""
    x = np.mod(u, W)
    z = np.mod(v, H)
    n = len(u)
    course = np.zeros(n, np.int64)
    bid = np.zeros(n, np.int64)
    dl = np.zeros(n)
    dr = np.zeros(n)
    db = np.zeros(n)
    dt = np.zeros(n)
    for k, (z0, z1, phase, cum) in enumerate(courses):
        m = (z >= z0) & (z < z1)
        if not m.any():
            continue
        xr = np.mod(x[m] - phase, W)
        idx = np.searchsorted(cum, xr, side="right")
        idx = np.minimum(idx, len(cum) - 1)
        start = np.where(idx > 0, cum[np.maximum(idx - 1, 0)], 0.0)
        course[m] = k
        bid[m] = k * 64 + idx
        dl[m] = xr - start
        dr[m] = cum[idx] - xr
        db[m] = z[m] - z0
        dt[m] = z1 - z[m]
    return course, bid, dl, dr, db, dt


def _uv(ctx):
    return ctx.uvm[:, 0], ctx.uvm[:, 1]


# --------------------------------------------------------------------------
# hall: limestone and marble
# --------------------------------------------------------------------------

def limestone(ctx, seed=301, center=6.4):
    """Plain dressed limestone for mouldings, plinths and carved pieces:
    fine tooling, shell specks, bright arrises, grime in the hollows."""
    s = Surface(ctx.N)
    base = center + ctx.fbm(1.6, 4, seed) * 1.0 + ctx.fbm(9.0, 2, seed + 1) * 0.45 + _dither(ctx, 0.6, seed + 2)
    f1, f2, cid = ctx.worley(22.0, seed + 3)
    shell = (f1 < 0.12) & (cid > 0.8)
    base += np.where(shell, np.where(cid > 0.9, 1.2, -1.2), 0.0)
    s.use_ramp(P["limestone"], shade=base)
    _age(ctx, s, cavity=2.4, ao=4.0, edge=1.3)
    s.height = ctx.fbm(10.0, 3, seed + 4) * 0.0008
    s.rough = 0.78 + ctx.rand(seed + 5) * 0.08
    return s


def limestone_rustic(ctx, seed=307):
    """Banded rustication for the hall's ground storey: 0.5 m courses with a
    deep V-channel along every bed joint, fine vertical joints, blocks
    1-2 m long in a shifting bond. Tile 6 x 3 m."""
    u, v = _uv(ctx)
    W, H = 6.0, 3.0
    courses = course_layout(W, [0.5] * 6, [1.0, 1.25, 1.5, 1.75, 2.0], seed)
    course, bid, dl, dr, db, dt = blocks(u, v, W, H, courses)
    tx = ctx.texel
    s = Surface(ctx.N)
    tone = noise.rand_cells(bid, seed) - 0.5
    base = 6.3 + tone * 1.3 + ctx.fbm(1.4, 4, seed + 1) * 0.9 + ctx.fbm(11.0, 2, seed + 2) * 0.4
    base += _dither(ctx, 0.6, seed + 3)
    f1, _, cid = ctx.worley(20.0, seed + 4)
    base += np.where((f1 < 0.12) & (cid > 0.82), -1.1, 0.0)
    # V-channel on the bed joints: 2 texels of chamfer above and below the line
    ch = 2.5 * tx
    below = db < ch                      # lower chamfer of this block: faces down, in shade
    above = dt < ch                      # upper chamfer: faces up, catches light
    line = (db < tx) | (dt < tx)
    base = np.where(below, base - 2.4, base)
    base = np.where(above & ~below, base + 1.0, base)
    base = np.where(line, base - 3.2, base)
    # head joints: one dark texel, a lit texel beside it
    head = dl < tx
    base = np.where(head & ~line, base - 2.2, base)
    base = np.where((dl >= tx) & (dl < 2 * tx) & ~below & ~above, base + 0.6, base)
    # weathering: edges of blocks slightly chipped
    chip = (np.minimum(np.minimum(dl, dr), np.minimum(db, dt)) < 4 * tx) & (ctx.fbm(14.0, 2, seed + 5) > 0.35)
    base = np.where(chip & ~line & ~head, base - 1.0, base)
    s.use_ramp(P["limestone"], shade=base)
    depth = np.clip(1.0 - np.minimum(db, dt) / ch, 0.0, 1.0)
    s.height = -depth * 0.018 - head * 0.004 - chip * 0.0015 + ctx.fbm(9.0, 3, seed + 6) * 0.0007
    s.rough = 0.8 + ctx.rand(seed + 7) * 0.08 + line * 0.1
    return s


def limestone_ashlar(ctx, seed=311):
    """Smooth ashlar for the hall above the balcony: 0.5 m courses, blocks
    0.75-1.5 m, one-texel joints with a lit arris above. Tile 4 x 2 m."""
    u, v = _uv(ctx)
    W, H = 4.0, 2.0
    courses = course_layout(W, [0.5] * 4, [0.75, 1.0, 1.25, 1.5], seed)
    course, bid, dl, dr, db, dt = blocks(u, v, W, H, courses)
    tx = ctx.texel
    s = Surface(ctx.N)
    tone = noise.rand_cells(bid, seed) - 0.5
    base = 6.8 + tone * 0.9 + ctx.fbm(1.3, 4, seed + 1) * 0.8 + ctx.fbm(12.0, 2, seed + 2) * 0.35
    base += _dither(ctx, 0.55, seed + 3)
    f1, _, cid = ctx.worley(24.0, seed + 4)
    base += np.where((f1 < 0.1) & (cid > 0.85), -0.9, 0.0)
    joint = (db < tx) | (dl < tx)
    arris = (dt < tx) & ~joint
    base = np.where(joint, base - 2.6, base)
    base = np.where(arris, base + 0.7, base)
    base = np.where((db >= tx) & (db < 2 * tx), base - 0.7, base)
    s.use_ramp(P["limestone"], shade=base)
    s.height = joint * -0.003 + ctx.fbm(9.0, 3, seed + 6) * 0.0006
    s.rough = 0.74 + ctx.rand(seed + 7) * 0.08
    return s


def _checker_marble(ctx, ramps, centers, lights, polish, seed, cell_id, p_off, vein_scales=None):
    """Evaluates several marbles on disjoint masks with per-cell offsets."""
    s = Surface(ctx.N)
    for k, (base, vein) in enumerate(ramps):
        m = cell_id == k
        if not m.any():
            continue
        plain = type(ctx)(ctx.p + p_off, ctx.n, ctx.t, ctx.b, ctx.texel, ctx.seed, None)
        plain.uvm = ctx.uvm
        plain.tile = True
        vs = 1.0 if vein_scales is None else vein_scales[k]
        sub = _marble_core(plain, base, vein, centers[k], lights[k], seed + 100 * k, polish=polish[k], vein_scale=vs)
        s.merge(_select(sub, m), m)
    return s


def marble_hall(ctx, seed=317):
    """Grand hall floor: 2 m squares of cream botticino and blue-grey
    bardiglio in a checker, a red marble diamond on every corner, one-texel
    grout. Tile 4 x 4 m (place it 1 m off the grid so a square sits on the
    hall's centre)."""
    u, v = _uv(ctx)
    tx = ctx.texel
    S = 2.0
    ix = np.floor(u / S + 1e-9).astype(np.int64)
    iz = np.floor(v / S + 1e-9).astype(np.int64)
    fx = u - ix * S
    fz = v - iz * S
    grey = ((ix + iz) % 2) == 1
    sq = np.mod(ix, 2) * 2 + np.mod(iz, 2)
    off = np.stack([noise.rand_cells(sq, seed + k) * 97.0 for k in range(3)], axis=1)
    cx = np.round(u / S) * S
    cz = np.round(v / S) * S
    d = np.abs(u - cx) + np.abs(v - cz)
    R = 0.3
    diamond = d < R - tx * 0.5
    ring = (d >= R - tx * 0.5) & (d < R + tx * 0.5)
    kind = np.where(diamond, 2, np.where(grey, 1, 0))
    s = _checker_marble(ctx, [(P["marble_cream"], P["marble_cream_vein"]), (P["marble_grey"], P["marble_grey_vein"]),
                              (P["marble_red"], P["marble_red_vein"])], [6.2, 3.6, 4.2], [False, True, False],
                        [0.07, 0.06, 0.08], seed, kind, off, vein_scales=[1.5, 2.1, 1.2])
    tone = noise.rand_cells(sq, seed + 9) - 0.5
    s.shade += np.where(diamond, 0.0, tone * 0.9)
    grout = ((fx < tx) | (fz < tx)) & ~diamond
    edge_d = np.minimum(np.minimum(fx, S - fx), np.minimum(fz, S - fz))
    near = (edge_d < 2 * tx) & ~grout & ~diamond & ~ring
    s.shade[near & ~grey] -= 0.7
    s.shade[near & grey] += 0.5
    line = grout | ring
    s.use_ramp(P["grout"], mask=line, shade=np.full(ctx.N, 1.4) + _dither(ctx, 1.0, seed + 3))
    s.height = np.where(line, -0.003, 0.0) + np.where(near, -0.0006, 0.0)
    scuff = smoothstep(0.15, 0.75, ctx.fbm(1.8, 4, seed + 4))
    s.rough = np.where(line, 0.85, s.rough + scuff * 0.2)
    s.metal[:] = 0.0
    return s


# --------------------------------------------------------------------------
# floors and ceilings of the other rooms
# --------------------------------------------------------------------------

def terrazzo(ctx, seed=331):
    """Polished terrazzo: marble chips of four colours in a warm grey
    cement, brass divider strips on a 1 m grid. Tile 2 x 2 m."""
    u, v = _uv(ctx)
    tx = ctx.texel
    s = Surface(ctx.N)
    base = 5.0 + ctx.fbm(2.0, 3, seed) * 0.8 + _dither(ctx, 1.0, seed + 1)
    s.use_ramp(P["terrazzo"], shade=base)
    for k, (freq, size) in enumerate(((26.0, 0.23), (42.0, 0.2), (64.0, 0.16))):
        f1, _, cid = ctx.worley(freq, seed + 10 + k)
        chip = f1 < size + ctx.fbm(freq * 0.9, 1, seed + 20 + k) * 0.08
        kind = np.floor(cid * 5).astype(np.int64)
        for ramp, sh, kk in (("marble_white", 7.0, 0), ("marble_dark", 2.5, 1), ("marble_red", 5.0, 2),
                             ("marble_cream", 7.2, 3), ("marble_grey", 4.0, 4)):
            m = chip & (kind == kk)
            if m.any():
                s.use_ramp(P[ramp], mask=m, shade=np.full(ctx.N, sh) + _dither(ctx, 1.2, seed + 30 + kk))
    strip = (np.mod(u, 1.0) < tx) | (np.mod(v, 1.0) < tx)
    s.use_ramp(P["brass"], mask=strip, shade=np.full(ctx.N, 6.0) + _dither(ctx, 1.0, seed + 5))
    s.metal = np.where(strip, 1.0, 0.0)
    scuff = smoothstep(0.2, 0.8, ctx.fbm(1.5, 4, seed + 6))
    s.rough = np.where(strip, 0.35, 0.16 + scuff * 0.2 + ctx.rand(seed + 7) * 0.04)
    s.height = ctx.fbm(20.0, 2, seed + 8) * 0.0003
    return s


def concrete(ctx, seed=337):
    """Service-corridor screed: trowel swirls, oil stains, pitting and saw
    cuts every 2 m. Tile 4 x 4 m."""
    u, v = _uv(ctx)
    tx = ctx.texel
    s = Surface(ctx.N)
    base = 4.8 + ctx.fbm(0.9, 3, seed) * 0.55 + ctx.fbm(6.0, 3, seed + 1) * 0.35 + _dither(ctx, 0.9, seed + 2)
    swirl = ctx.ridged(2.5, 3, seed + 3)
    base += smoothstep(0.95, 0.995, swirl) * 0.35
    stain = smoothstep(0.35, 0.8, ctx.fbm(0.7, 4, seed + 4))
    base -= stain * 1.1
    f1, _, cid = ctx.worley(40.0, seed + 5)
    pit = (f1 < 0.12) & (cid > 0.6)
    base -= pit * 1.5
    cut = (np.mod(u, 2.0) < tx) | (np.mod(v, 2.0) < tx)
    base = np.where(cut, 0.8, base)
    s.use_ramp(P["concrete"], shade=base)
    s.height = cut * -0.003 - pit * 0.001 + ctx.fbm(12.0, 2, seed + 6) * 0.0005
    s.rough = 0.82 - stain * 0.25 + ctx.rand(seed + 7) * 0.06
    return s


def linoleum(ctx, seed=347):
    """Marbled linoleum tiles, 0.5 m, oxblood and cream in a checker, waxed,
    scuffed along the walking lines. Tile 2 x 2 m."""
    u, v = _uv(ctx)
    tx = ctx.texel
    S = 0.5
    ix = np.floor(u / S + 1e-9).astype(np.int64)
    iz = np.floor(v / S + 1e-9).astype(np.int64)
    red = ((ix + iz) % 2) == 0
    tid = np.mod(ix, 4) * 4 + np.mod(iz, 4)
    along_x = noise.rand_cells(tid, seed) > 0.5
    q = np.where(along_x[:, None], ctx.p * np.array([0.25, 1.0, 1.0]), ctx.p * np.array([1.0, 1.0, 0.25]))
    streak = noise.fbm(q * 6.0 + noise.rand_cells(tid, seed + 1)[:, None] * 31.0, 4, seed + 2)
    s = Surface(ctx.N)
    shade_r = 3.2 + streak * 2.2 + _dither(ctx, 0.7, seed + 3)
    shade_c = 4.6 + streak * 2.4 + _dither(ctx, 0.7, seed + 4)
    s.use_ramp(P["lino_cream"], shade=shade_c)
    s.use_ramp(P["lino_red"], mask=red, shade=shade_r)
    fx = u - ix * S
    fz = v - iz * S
    seam = (fx < tx) | (fz < tx)
    s.shade = np.where(seam, s.shade - 2.0, s.shade)
    scuff = smoothstep(0.3, 0.8, ctx.fbm(1.2, 4, seed + 5))
    s.shade -= scuff * 0.8
    s.rough = 0.3 + scuff * 0.3 + ctx.rand(seed + 6) * 0.05 + seam * 0.3
    s.height = seam * -0.001
    return s


def ceiling_tiles(ctx, seed=353):
    """Suspended acoustic ceiling: 0.5 m fissured mineral tiles in a light
    T-bar grid, a few water stains. Tile 2 x 2 m."""
    u, v = _uv(ctx)
    tx = ctx.texel
    S = 0.5
    ix = np.floor(u / S + 1e-9).astype(np.int64)
    iz = np.floor(v / S + 1e-9).astype(np.int64)
    fx = u - ix * S
    fz = v - iz * S
    tid = np.mod(ix, 8) * 8 + np.mod(iz, 8)
    s = Surface(ctx.N)
    base = 6.2 + (noise.rand_cells(tid, seed) - 0.5) * 0.9 + ctx.fbm(3.0, 2, seed + 1) * 0.4
    base += _dither(ctx, 0.8, seed + 2)
    fiss = smoothstep(0.9, 0.97, ctx.ridged(28.0, 2, seed + 3))
    base -= fiss * 2.0
    s.use_ramp(P["acoustic"], shade=base)
    # water stain rings on two tiles
    stained = noise.rand_cells(tid, seed + 4) > 0.95
    rr = np.hypot(fx - 0.25 - (noise.rand_cells(tid, seed + 5) - 0.5) * 0.15, fz - 0.25)
    wob = ctx.fbm(6.0, 3, seed + 6) * 0.08
    blot = stained & (rr < 0.16 + wob)
    rim = blot & (rr > 0.135 + wob)
    s.use_ramp(P["acoustic"], mask=blot, shade=np.where(rim, 2.2, base - 1.2) + _dither(ctx, 0.8, seed + 7))
    bar = (fx < 1.5 * tx) | (fz < 1.5 * tx)
    shadow = ((fx >= 1.5 * tx) & (fx < 2.5 * tx)) | ((fz >= 1.5 * tx) & (fz < 2.5 * tx))
    s.use_ramp(P["acoustic"], mask=bar, shade=np.full(ctx.N, 7.6))
    s.shade = np.where(shadow & ~bar, s.shade - 1.8, s.shade)
    s.metal = np.where(bar, 0.3, 0.0)
    s.rough = np.where(bar, 0.45, 0.93)
    s.height = np.where(bar, 0.004, 0.0) - fiss * 0.0008
    return s


def paint_wall(ctx, seed=359):
    """Institutional two-tone paint (security room, staff corridor): gloss
    dark-green dado to 1.2 m, a dark line, pale grey-green eggshell above;
    scuffs at kick height, chips. Tile 2 x 3 m (the room height)."""
    u, v = _uv(ctx)
    tx = ctx.texel
    z = np.mod(v, 3.0)
    dado = z < 1.2
    line = (z >= 1.2) & (z < 1.2 + 2 * tx)
    s = Surface(ctx.N)
    peel = ctx.fbm(40.0, 2, seed) * 0.35
    s.use_ramp(P["paint_institution"], shade=6.3 + ctx.fbm(1.5, 3, seed + 1) * 0.6 + peel + _dither(ctx, 0.5, seed + 2))
    s.use_ramp(P["paint_institution_dark"], mask=dado,
               shade=4.4 + ctx.fbm(1.5, 3, seed + 3) * 0.6 + peel + _dither(ctx, 0.5, seed + 4))
    s.use_ramp(P["leather"], mask=line, shade=np.full(ctx.N, 2.0))
    scuff = dado & (z < 0.35) & (ctx.fbm(np.array([6.0, 1.0, 16.0]), 2, seed + 5) > 0.3)
    s.shade -= scuff * 1.4
    chip = (ctx.fbm(22.0, 2, seed + 6) > 0.62) & (ctx.rand(seed + 7) > 0.2)
    s.use_ramp(P["plaster"], mask=chip & dado, shade=np.full(ctx.N, 5.0))
    s.rough = np.where(dado, 0.34, 0.62) + ctx.rand(seed + 8) * 0.04
    s.height = peel * 0.0004 - chip * 0.0006
    return s


def stone_rubble(ctx, seed=367):
    """Armory walls: squared rubble - roughly dressed blocks 0.4-1.1 m long in
    uneven courses, rounded knocked-off arrises, deep mortar joints, a few
    warmer stones, soot toward the top. Tile 4 x 2 m."""
    u, v = _uv(ctx)
    W, H = 4.0, 2.0
    courses = course_layout(W, [0.35, 0.3, 0.45, 0.4, 0.5], [0.4, 0.5, 0.6, 0.75, 0.9, 1.1], seed, step=0.05)
    q = np.stack([u, np.zeros(ctx.N), v], axis=1)
    wob_u = ctx.fbm(6.0, 2, seed + 1, p=q) * 0.035
    wob_v = ctx.fbm(6.0, 2, seed + 2, p=q) * 0.03
    course, bid, dl, dr, db, dt = blocks(u + wob_u, v + wob_v, W, H, courses)
    tx = ctx.texel
    mortar_w = 0.025 + ctx.fbm(11.0, 2, seed + 3) * 0.01
    edge = np.minimum(np.minimum(dl, dr), np.minimum(db, dt))
    stone_m = edge > mortar_w
    inner = np.clip((edge - mortar_w) / 0.09, 0.0, 1.0)
    dome = np.sqrt(inner)
    s = Surface(ctx.N)
    tone = noise.rand_cells(bid, seed) - 0.5
    warm = noise.rand_cells(bid, seed + 4) > 0.85
    shade = 5.0 + tone * 2.6 + ctx.fbm(2.5, 4, seed + 5) * 0.9 + ctx.fbm(16.0, 2, seed + 6) * 0.7
    shade += _dither(ctx, 0.8, seed + 7)
    # rough tooling: pitted faces
    f1, _, cid = ctx.worley(14.0, seed + 8)
    shade -= ((f1 < 0.18) & (cid > 0.55)) * 1.0
    # light from above: upper arris lit, lower one in shade, rounded edges darker
    near_top = (dt - mortar_w < 0.05) & stone_m
    near_bottom = (db - mortar_w < 0.045) & stone_m
    shade = shade + near_top * 1.3 - near_bottom * 1.7 - (1.0 - dome) * 1.4
    s.use_ramp(P["mortar"], shade=2.8 + ctx.fbm(12.0, 2, seed + 9) * 0.8 + _dither(ctx, 1.0, seed + 10))
    s.use_ramp(P["rubble"], mask=stone_m & ~warm, shade=shade)
    s.use_ramp(P["rubble_warm"], mask=stone_m & warm, shade=shade - 1.0)
    s.height = np.where(stone_m, 0.016 * dome + ctx.fbm(12.0, 3, seed + 11) * 0.0025, -0.01)
    s.rough = np.where(stone_m, 0.84, 0.95) + ctx.rand(seed + 12) * 0.05
    return s


def flagstone(ctx, seed=373):
    """Worn flagstone floor: rows of rectangular flags, chipped arrises,
    dark joints, the middles polished by feet. Tile 4 x 4 m."""
    u, v = _uv(ctx)
    W, H = 4.0, 4.0
    courses = course_layout(W, [0.6, 0.8, 0.5, 0.9, 0.7, 0.5], [0.5, 0.6, 0.75, 0.8, 1.0, 1.2], seed, step=0.1)
    course, bid, dl, dr, db, dt = blocks(u, v, W, H, courses)
    tx = ctx.texel
    edge = np.minimum(np.minimum(dl, dr), np.minimum(db, dt)) + ctx.fbm(12.0, 2, seed + 8) * 0.012
    chip = (edge < 3 * tx) & (ctx.fbm(16.0, 2, seed + 1) > 0.15)
    joint = edge < 1.2 * tx
    s = Surface(ctx.N)
    tone = noise.rand_cells(bid, seed) - 0.5
    shade = 5.0 + tone * 2.8 + ctx.fbm(2.5, 4, seed + 2) * 1.3 + ctx.fbm(20.0, 2, seed + 3) * 0.6
    crack = (np.abs(ctx.fbm(3.0, 3, seed + 9)) < 0.012) & (noise.rand_cells(bid, seed + 10) > 0.6)
    shade -= crack * 2.5
    shade += _dither(ctx, 0.8, seed + 4)
    shade -= chip * 1.4
    shade += np.where((edge >= 1.2 * tx) & (edge < 2.2 * tx) & ~chip, 0.8, 0.0)
    s.use_ramp(P["flag"], shade=shade)
    s.use_ramp(P["grout"], mask=joint, shade=np.full(ctx.N, 1.0) + _dither(ctx, 1.0, seed + 5))
    wear = np.clip(edge / 0.25, 0.0, 1.0)
    s.rough = np.where(joint, 0.95, 0.85 - wear * 0.3) + ctx.rand(seed + 6) * 0.05
    s.height = joint * -0.006 - chip * 0.002 - crack * 0.002 + ctx.fbm(10.0, 3, seed + 7) * 0.0012
    return s


def brick(ctx, seed=379):
    """Old brick in English bond (a course of stretchers, a course of
    headers), soot-dark and burnt bricks, patches of broken plaster.
    Tile 4 x 2 m, 32 courses."""
    u, v = _uv(ctx)
    tx = ctx.texel
    ch = 1.0 / 16.0
    row = np.floor(np.mod(v, 2.0) / ch + 1e-9).astype(np.int64)
    header = (row % 2) == 1
    blen = np.where(header, 0.125, 0.25)
    shift = np.where(header, 0.0625, 0.0) + np.where((row % 4) == 2, 0.125, 0.0)
    xu = np.mod(u + shift, 4.0)
    col = np.floor(xu / blen + 1e-9).astype(np.int64)
    fx = xu - col * blen
    fz = np.mod(v, 2.0) - row * ch
    bid = row * 64 + col
    mortar = (fx < tx) | (fz < tx)
    s = Surface(ctx.N)
    tone = noise.rand_cells(bid, seed) - 0.5
    burnt = noise.rand_cells(bid, seed + 1) > 0.86
    shade = 4.6 + tone * 2.4 + ctx.fbm(3.0, 3, seed + 2) * 0.8 + _dither(ctx, 0.9, seed + 3) - burnt * 2.2
    shade -= smoothstep(0.2, 0.7, ctx.fbm(1.2, 3, seed + 4)) * 1.2       # soot
    s.use_ramp(P["brick"], shade=shade)
    s.use_ramp(P["mortar"], mask=mortar, shade=np.full(ctx.N, 3.0) + _dither(ctx, 1.0, seed + 5))
    patch_f = ctx.fbm(0.5, 4, seed + 6)
    patch = patch_f > 0.12
    rim = patch & (patch_f < 0.16)
    s.use_ramp(P["plaster"], mask=patch, shade=4.6 + ctx.fbm(6.0, 2, seed + 7) * 0.8 - rim * 2.5
               + _dither(ctx, 0.7, seed + 8))
    s.height = np.where(patch, 0.006, np.where(mortar, -0.004, 0.0)) + ctx.fbm(20.0, 2, seed + 9) * 0.0006
    s.rough = np.where(patch, 0.9, 0.86) + ctx.rand(seed + 10) * 0.05
    return s


def boards(ctx, seed=383):
    """Worn pine floorboards, 12.5 cm wide, butt joints and nail heads.
    Tile 2 x 2 m."""
    u, v = _uv(ctx)
    tx = ctx.texel
    Wb = 0.125
    rows = int(round(2.0 / Wb))
    courses = course_layout(2.0, [Wb] * rows, [0.75, 1.0, 1.25, 2.0], seed, step=0.25)
    course, bid, dl, dr, db, dt = blocks(u, v, 2.0, 2.0, courses)
    t = np.tile([1.0, 0.0, 0.0], (ctx.N, 1))
    b = np.tile([0.0, 0.0, 1.0], (ctx.N, 1))
    off = noise.rand_cells(bid, seed)[:, None] * 40.0
    plain = type(ctx)(ctx.p + off, ctx.n, t, b, ctx.texel, ctx.seed, None)
    s = _wood_core(plain, P["pine_worn"], 4.6, seed + 1, ring_freq=10.0, contrast=0.9)
    s.shade += (noise.rand_cells(bid, seed + 2) - 0.5) * 2.0
    gap = (db < tx) | (dl < tx)
    s.shade = np.where(gap, 0.3, s.shade)
    nail = ((np.abs(dl - 0.03) < tx * 0.5) | (np.abs(dr - 0.03) < tx * 0.5)) & (np.abs(db - Wb * 0.5) < tx * 0.5)
    s.use_ramp(P["iron"], mask=nail, shade=np.full(ctx.N, 2.0))
    s.height = s.height - gap * 0.003
    s.rough = 0.7 + ctx.rand(seed + 3) * 0.08 + gap * 0.2
    return s


# --------------------------------------------------------------------------
# diorama
# --------------------------------------------------------------------------

def grass_fake(ctx, seed=389):
    """Flocked diorama grass: clumps, straw, dead leaves and pebbles.
    Tile 2 x 2 m."""
    s = Surface(ctx.N)
    f1, f2, cid = ctx.worley(14.0, seed)
    clump = np.clip(1.0 - f1 * 1.8, 0.0, 1.0)
    shade = 3.2 + clump * 2.6 + ctx.fbm(3.0, 3, seed + 1) * 1.0 + (cid - 0.5) * 1.2
    shade += _dither(ctx, 1.4, seed + 2)
    shade -= smoothstep(0.0, 0.08, 0.1 - (f2 - f1)) * 1.8
    s.use_ramp(P["flock"], shade=shade)
    straw = (ctx.rand(seed + 3) > 0.93) & (ctx.fbm(5.0, 2, seed + 4) > 0.0)
    s.use_ramp(P["straw"], mask=straw, shade=np.full(ctx.N, 2.5) + _dither(ctx, 2.0, seed + 5))
    g1, _, gid = ctx.worley(9.0, seed + 6)
    leaf = (g1 < 0.13) & (gid > 0.8)
    s.use_ramp(P["hide"], mask=leaf, shade=np.full(ctx.N, 2.5) + _dither(ctx, 1.5, seed + 7))
    pebble = (g1 < 0.1) & (gid < 0.06)
    s.use_ramp(P["stone"], mask=pebble, shade=5.0 + (0.1 - g1) * 30.0)
    s.height = clump * 0.01 + pebble * 0.006
    s.rough = np.full(ctx.N, 0.96)
    return s


BACKDROP_PALETTE = hexramp(
    "#1b2a2e", "#24363a", "#2f4448", "#3c5356", "#4a6466", "#5d7777", "#768c8a", "#94a5a0",
    "#b4bfb4", "#d6d6c2", "#e8dfbd", "#e2c48f", "#c9a26b", "#a6824f",
    "#1a2615", "#223219", "#2c401e", "#384e23", "#465e29", "#566f31", "#6a803b", "#839447",
    "#9da859", "#101a12", "#17231a", "#6c7c86", "#8796a0", "#a3b0b8", "#c3ccd0", "#e4e8e6",
    "#5a4a38", "#7a6448", "#3a3026")


def backdrop(ctx, seed=397):
    """Painted diorama backdrop: a hand-painted panorama that runs round the
    room (periodic every 16 m): afternoon sky with cumulus, a snow-capped
    far range and a nearer blue-green range (flanks lit from the left), two
    rows of spruce with ragged crowns, deciduous clumps, a meadow that
    darkens toward the viewer and a stream bank. Painterly: brush dabs, then
    snapped to a 33-colour palette. Tile 16 x 8 m (the diorama's wall
    height), horizon at 2.6 m."""
    u, v = _uv(ctx)
    n = ctx.N
    per_x = 16.0

    def f1d(freq, octs, sd, amp=1.0, shift=0.0):
        q = np.stack([u + shift, np.zeros(n), np.zeros(n)], axis=1)
        return ctx.fbm(np.array([freq, 1.0, 1.0]), octs, sd, p=q) * amp

    def f2d(freq, octs, sd):
        return ctx.fbm(freq, octs, sd)

    def ridge(shift, base, sd, amp):
        return (base + f1d(0.3, 3, sd, amp * 0.7, shift)
                + (1.0 - np.abs(f1d(0.55, 4, sd + 1, 1.0, shift))) * amp - amp * 0.5)

    horizon = 2.6
    # sky: warm haze at the horizon, teal-blue zenith
    t = np.clip((v - horizon) / (8.0 - horizon), 0.0, 1.0)
    low = np.array([0.87, 0.84, 0.72])
    mid = np.array([0.6, 0.72, 0.74])
    top = np.array([0.26, 0.43, 0.52])
    col = np.where((t < 0.3)[:, None], low + (mid - low) * (t / 0.3)[:, None],
                   mid + (top - mid) * ((t - 0.3) / 0.7)[:, None])
    # cumulus bank: puffy masses, lit tops, grey bellies
    cz = 5.0 + f1d(0.25, 2, seed + 1, 0.5)
    puff = f2d(np.array([0.6, 1.0, 1.0]), 4, seed + 2) + 0.5 - np.abs(v - cz) * 0.62
    cloud = puff > 0.22
    lit = np.clip((puff - 0.22) * 2.4 + (v - cz) * 0.45, 0.0, 1.0)
    ccol = np.array([0.6, 0.64, 0.68])[None] * (1 - lit[:, None]) + np.array([0.97, 0.95, 0.88])[None] * lit[:, None]
    col = np.where(cloud[:, None], ccol, col)
    wisp = (f2d(np.array([0.5, 1.0, 2.5]), 2, seed + 4) > 0.3) & (v > 6.3) & ~cloud
    col = np.where(wisp[:, None], col * 0.7 + np.array([0.92, 0.92, 0.86]) * 0.3, col)
    # far range with snow on the peaks, flanks lit from the left
    d = 0.06
    far_h = ridge(0.0, horizon + 1.35, seed + 5, 1.4)
    far_slope = (ridge(d, horizon + 1.35, seed + 5, 1.4) - ridge(-d, horizon + 1.35, seed + 5, 1.4)) / (2 * d)
    far = v < far_h
    haze = np.clip((v - horizon) / 2.5, 0.0, 1.0)
    far_col = np.array([0.62, 0.68, 0.72]) * (1 - haze[:, None]) + np.array([0.46, 0.55, 0.62]) * haze[:, None]
    # gullies: a 2D ridged field stretched downhill, lit on its left flanks
    qg = np.stack([u * 1.0, np.zeros(n), v * 0.45], axis=1)
    warp = ctx.fbm(0.6, 2, seed + 30, p=qg) * 0.4
    qg = qg + np.stack([warp, np.zeros(n), np.zeros(n)], axis=1)
    g0 = ctx.ridged(np.array([1.6, 1.0, 1.0]), 3, seed + 31, p=qg - np.array([0.03, 0.0, 0.0]))
    g1 = ctx.ridged(np.array([1.6, 1.0, 1.0]), 3, seed + 31, p=qg + np.array([0.03, 0.0, 0.0]))
    flank = np.clip((g1 - g0) * 6.0 + far_slope * 0.6, -1.0, 1.0)
    far_col = far_col + flank[:, None] * 0.06
    col = np.where(far[:, None], far_col, col)
    snow_depth = 0.12 + np.clip(g0 - 0.7, 0.0, 1.0) * 1.1
    snow = far & (v > far_h - snow_depth) & (far_h > horizon + 1.45)
    snow_col = np.where((flank > -0.1)[:, None], np.array([0.95, 0.94, 0.9]), np.array([0.74, 0.79, 0.84]))
    col = np.where(snow[:, None], snow_col, col)
    # near range: blue-green, darker, lit flanks
    near_h = ridge(3.7, horizon + 0.55, seed + 9, 0.7)
    near_slope = (ridge(3.7 + d, horizon + 0.55, seed + 9, 0.7) - ridge(3.7 - d, horizon + 0.55, seed + 9, 0.7)) / (2 * d)
    near = v < near_h
    near_col = np.array([0.27, 0.37, 0.37]) + (np.clip((g1 - g0) * 5.0 + near_slope * 0.4, -1, 1) * 0.04)[:, None]
    near_col = near_col + f2d(2.0, 2, seed + 11)[:, None] * 0.03
    col = np.where(near[:, None], near_col, col)

    def spruce_row(cell, h0, h1, base, colour, lit_col, sd, gaps):
        ci = np.floor(u / cell)
        ci_w = np.mod(ci, int(round(per_x / cell))).astype(np.int64)
        z0 = np.zeros(n, np.int64)
        jit = (noise.hash_float(ci_w, z0, z0 + 1, sd) - 0.5) * 0.5
        fx = u / cell - ci - 0.5 - jit
        h = h0 + noise.hash_float(ci_w, z0, z0, sd) * (h1 - h0)
        keep = noise.hash_float(ci_w, z0, z0 + 2, sd) > gaps
        y = v - base
        rag = 0.85 + 0.3 * np.mod(y * 11.0 + noise.hash_float(ci_w, z0, z0 + 3, sd), 1.0)
        half = (1.0 - y / h) * 0.55 * rag
        crown = keep & (y > -0.2) & (y < h) & (np.abs(fx) < half)
        tree_col = np.where((fx < -half * 0.35)[:, None], lit_col, colour)
        return crown, tree_col

    base_back = horizon - 0.35 + f1d(0.7, 2, seed + 12, 0.15)
    crown_b, col_b = spruce_row(0.21, 0.35, 0.7, base_back, np.array([0.14, 0.22, 0.2]),
                                np.array([0.2, 0.3, 0.25]), seed + 13, 0.05)
    col = np.where(crown_b[:, None], col_b, col)
    wood = v < base_back + 0.05
    col = np.where((wood & (v > horizon - 1.2))[:, None], np.array([0.12, 0.19, 0.16]), col)
    base_front = horizon - 0.75 + f1d(0.6, 2, seed + 14, 0.2)
    crown_f, col_f = spruce_row(0.37, 0.7, 1.45, base_front, np.array([0.08, 0.13, 0.1]),
                                np.array([0.16, 0.24, 0.14]), seed + 15, 0.2)
    col = np.where(crown_f[:, None], col_f, col)
    # deciduous clumps between the spruces
    bush = (f2d(np.array([1.1, 1.0, 3.0]), 3, seed + 16) + 0.3 - np.abs(v - (base_front + 0.1)) * 2.2) > 0.3
    bush &= ~crown_f & (v < base_front + 0.45)
    blit = f2d(np.array([4.0, 1.0, 8.0]), 2, seed + 17) > 0.15
    col = np.where(bush[:, None], np.where(blit[:, None], np.array([0.3, 0.4, 0.17]), np.array([0.17, 0.25, 0.12])), col)
    # meadow: painted greens in horizontal dabs, darker toward the viewer
    meadow = (v < base_front - 0.02) & ~crown_f
    dab = f2d(np.array([2.2, 1.0, 9.0]), 3, seed + 18)
    depth = np.clip(v / (horizon - 0.8), 0.0, 1.0)
    mcol = np.array([0.18, 0.27, 0.11]) + depth[:, None] * np.array([0.16, 0.18, 0.07])
    mcol = mcol + dab[:, None] * np.array([0.07, 0.09, 0.03])
    col = np.where(meadow[:, None], mcol, col)
    ground = meadow & (v < 0.3 + f1d(1.1, 3, seed + 21, 0.12))
    col = np.where(ground[:, None], np.array([0.3, 0.25, 0.18]) + dab[:, None] * 0.05, col)
    flowers = meadow & ~ground & (ctx.rand(seed + 22) > 0.988)
    col = np.where(flowers[:, None], np.array([0.9, 0.86, 0.6]), col)
    # brush dabs everywhere, then the limited palette
    col = col * (0.95 + 0.1 * f2d(np.array([6.0, 1.0, 14.0]), 2, seed + 23))[:, None]
    col = col + (ctx.rand(seed + 24) - 0.5)[:, None] * 0.03
    dist = ((col[:, None, :] - BACKDROP_PALETTE[None]) ** 2).sum(-1)
    s = Surface(n)
    s.albedo = BACKDROP_PALETTE[np.argmin(dist, axis=1)]
    s.rough = np.full(n, 0.9)
    s.height = f2d(np.array([8.0, 1.0, 20.0]), 2, seed + 25) * 0.0006
    return s


# --------------------------------------------------------------------------
# model materials (baked into atlases)
# --------------------------------------------------------------------------

def timber(ctx, seed=401):
    """Smoked oak beams: coarse grain, adze facets, drying checks along the
    grain, dark arrises."""
    s = _wood_core(ctx, P["timber"], 4.4, seed, ring_freq=5.0, contrast=1.3)
    along, across = _grain_frame(ctx)
    a = np.sum(ctx.p * along, axis=1)
    c = np.sum(ctx.p * across, axis=1)
    check = np.abs(noise.fbm(np.stack([a * 0.3, c * 14.0, np.zeros(ctx.N)], axis=1), 2, seed + 1)) < 0.03
    s.shade -= check * 2.5
    adze = ctx.fbm(np.array([6.0, 6.0, 6.0]), 2, seed + 2)
    s.shade += adze * 0.6
    _age(ctx, s, cavity=1.8, ao=3.2, edge=1.2)
    s.height = s.height + adze * 0.0015 - check * 0.002
    s.rough = 0.7 + ctx.rand(seed + 3) * 0.08
    return s


def paint(ctx, ramp, center, seed=409, rough=0.45, chip=0.6, under="iron"):
    """Brushed paint on wood or metal: faint streaks, worn arrises, chips to
    the material underneath."""
    s = Surface(ctx.N)
    along, _ = _grain_frame(ctx)
    a = np.sum(ctx.p * along, axis=1)
    streak = ctx.fbm(np.array([1.0, 1.0, 1.0]), 2, seed, p=np.stack([a * 2.0, ctx.p[:, 2] * 30.0, ctx.p[:, 1] * 30.0], axis=1))
    shade = center + ctx.fbm(2.0, 3, seed + 1) * 0.5 + streak * 0.35 + _dither(ctx, 0.5, seed + 2)
    s.use_ramp(P[ramp], shade=shade)
    _age(ctx, s, cavity=1.8, ao=3.0, edge=1.0)
    chips = (ctx.edge_soft(2.5) > 0.3) & (ctx.fbm(18.0, 2, seed + 3) > 0.45 - chip * 0.2)
    if under == "iron":
        s.use_ramp(P["iron"], mask=chips, shade=np.full(ctx.N, 3.5))
    else:
        s.use_ramp(P[under], mask=chips, shade=np.full(ctx.N, 4.0))
    s.rough = rough + ctx.rand(seed + 4) * 0.05 + chips * 0.2
    s.height = streak * 0.0002 - chips * 0.0004
    return s


def sign_text(ctx, lines, ground="enamel_red", ground_center=4.5, ink="sign_white", ink_center=3.5,
              px=None, glow=0.0, border=True, seed=419, u0=None, u1=None, v0=None, v1=None, align="center"):
    """An enamel / lit sign: ``lines`` = [(text, baseline_v, px, anchor_u)] drawn in
    the face's metre UVs, a 1-texel border inset. ``glow`` > 0 makes the whole
    face emissive (exit signs)."""
    u, v = _uv(ctx)
    s = Surface(ctx.N)
    shade = ground_center + ctx.fbm(10.0, 2, seed) * 0.35 + _dither(ctx, 0.4, seed + 1)
    s.use_ramp(P[ground], shade=shade)
    ink_m = np.zeros(ctx.N, dtype=bool)
    for text, base_v, size, cu in lines:
        ink_m |= font.text_mask(u, v, text, cu, base_v, size, align=align)
    if border and u0 is not None:
        tx = ctx.texel
        inset = 2 * tx
        bd = ((np.abs(u - (u0 + inset)) < tx * 0.5) | (np.abs(u - (u1 - inset)) < tx * 0.5)) & (v > v0 + inset - tx) & (v < v1 - inset + tx)
        bd |= ((np.abs(v - (v0 + inset)) < tx * 0.5) | (np.abs(v - (v1 - inset)) < tx * 0.5)) & (u > u0 + inset - tx) & (u < u1 - inset + tx)
        ink_m |= bd
    s.use_ramp(P[ink], mask=ink_m, shade=np.full(ctx.N, ink_center) + _dither(ctx, 0.3, seed + 2))
    s.rough = np.full(ctx.N, 0.3)
    if glow > 0.0:
        s.emit = s.colors() * glow
    return s


MATERIALS = {
    "limestone": limestone,
    "limestone_rustic": limestone_rustic,
    "limestone_ashlar": limestone_ashlar,
    "marble_hall": marble_hall,
    "terrazzo": terrazzo,
    "concrete": concrete,
    "linoleum": linoleum,
    "ceiling_tiles": ceiling_tiles,
    "paint_wall": paint_wall,
    "stone_rubble": stone_rubble,
    "flagstone": flagstone,
    "brick": brick,
    "boards": boards,
    "grass_fake": grass_fake,
    "backdrop": backdrop,
    "timber": timber,
}
