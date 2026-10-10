"""Shared pieces of the fire-arrow box models (vm_hwacha, hwacha_rocket,
ammo_hwacha): colour ramps, the singijeon fire-arrow (geometry and its
materials), and the gold-leaf dragon / cloud-scroll motif painted on the
lacquered box (faded in the museum piece, crisp in the master finish).

Not a model itself (no build()); the leading underscore keeps it out of
the model list.
"""
import math

import numpy as np

from artlib import kit
from artlib import materials as M
from artlib.kit import R, T
from artlib.painter import Surface

hexramp = M.hexramp

RAMPS = {
    # cinnabar lacquer (ju-chil), aged: dull, slightly brown
    "lacquer": hexramp("#160303", "#260605", "#3a0a07", "#520f0a", "#6b150d", "#841c11", "#9d2616", "#b5321c",
                       "#c94226", "#da5734"),
    # the same lacquer freshly polished: deeper, more saturated
    "lacquer_deep": hexramp("#1c0204", "#300408", "#4a060b", "#66090f", "#840d13", "#a01418", "#b91d1d",
                            "#cf2c25", "#e2432f", "#f0623f"),
    "lacquer_black": hexramp("#050405", "#0b090a", "#121011", "#1b1819", "#252122", "#312c2c", "#3e3838"),
    # hanji paper dyed red (the powder tubes)
    "paper": hexramp("#2e0907", "#4b100b", "#6a1810", "#882215", "#a42d1a", "#bb3b22", "#cf4e2e", "#de6740",
                     "#ea8358"),
    "twine": hexramp("#241a0e", "#3a2c17", "#524021", "#6b552d", "#846b3b", "#9c824b", "#b3995e", "#c8b073"),
    "bamboo": hexramp("#2f220f", "#4a3618", "#654b22", "#80612e", "#9b783b", "#b38f4c", "#c9a661", "#dbbd7a"),
    # pheasant tail feathers: barred buff and umber
    "feather": hexramp("#1d1915", "#332c25", "#4d4338", "#6b5e4f", "#8b7c68", "#ab9c86", "#c9bca5", "#e2d8c3"),
    # slow match: saltpetre-soaked hemp, greyer than twine
    "cord": hexramp("#17130e", "#241e16", "#342c20", "#463c2b", "#594d38", "#6d6146", "#827556"),
    "ash": hexramp("#0a0908", "#151312", "#22201e", "#33302d", "#4a4642", "#6b6660", "#8f8a83"),
    "silk": hexramp("#2a0406", "#45070b", "#640c12", "#851219", "#a51b22", "#c1272c", "#d83a3a", "#ea5b52",
                    "#f6846f"),
    "enamel_blue": hexramp("#050a1a", "#0a1430", "#112050", "#1a2f70", "#26418f", "#3a58ab", "#5676c4"),
    "clay": hexramp("#1a1612", "#2a241d", "#3b332a", "#4e4538", "#625747"),
}


def smoothstep(a, b, x):
    return M.smoothstep(a, b, x)


# --------------------------------------------------------------------------
# materials of the fire-arrow and the slow match
# --------------------------------------------------------------------------

def paper(ctx, seed=701, center=4.6):
    """Red-dyed mulberry paper wound round the powder tube: long fibres,
    a spiral seam of the wrapping, soft rubbed highlights."""
    s = Surface(ctx.N)
    along, across = M._grain_frame(ctx)
    q = np.stack([np.sum(ctx.p * along, 1), np.sum(ctx.p * across, 1), np.sum(ctx.p * ctx.n, 1)], axis=1)
    fib = ctx.fbm(np.array([30.0, 220.0, 220.0]), 2, seed, p=q)
    blot = ctx.fbm(6.0, 3, seed + 1)
    shade = center + fib * 0.7 + blot * 0.6 + M._dither(ctx, 0.6, seed + 2)
    seam = np.abs(np.mod(ctx.uvm[:, 0] / 0.031 + ctx.uvm[:, 1] / 0.024, 1.0) - 0.5) < 0.06
    shade -= seam * 1.3
    flecks = ctx.rand(seed + 3) > 0.985
    shade += flecks * 2.0
    shade += ctx.edge(1.0) * 1.0 - ctx.cavity(3.0) * 1.6 - (1.0 - ctx.ao) * 3.0
    s.use_ramp(RAMPS["paper"], shade=shade)
    s.rough = 0.72 + ctx.rand(seed + 4) * 0.08
    s.height = fib * 0.00012 - seam * 0.0002
    return s


def twine(ctx, seed=703):
    """Hemp twine lashing: diagonal twisted strands."""
    s = Surface(ctx.N)
    k = np.mod(ctx.uvm[:, 0] / 0.0035 + ctx.uvm[:, 1] / 0.0021, 1.0)
    strand = np.abs(k - 0.5) * 2.0
    shade = 4.4 + (0.6 - strand) * 2.2 + ctx.fbm(20.0, 2, seed) * 0.6 + M._dither(ctx, 0.6, seed + 1)
    shade -= (1.0 - ctx.ao) * 3.0
    s.use_ramp(RAMPS["twine"], shade=shade)
    s.rough = np.full(ctx.N, 0.88)
    s.height = (0.6 - strand) * 0.0003
    return s


def bamboo(ctx, seed=705):
    """Split-bamboo shaft: fine fibres, varnished, a node ring every 11 cm."""
    s = Surface(ctx.N)
    along, across = M._grain_frame(ctx)
    a = np.sum(ctx.p * along, 1)
    q = np.stack([a, np.sum(ctx.p * across, 1), np.sum(ctx.p * ctx.n, 1)], axis=1)
    fib = ctx.fbm(np.array([4.0, 300.0, 300.0]), 2, seed, p=q)
    node = np.abs(np.mod(a / 0.11 + 0.37, 1.0) - 0.5) * 0.11 < 0.0022
    shade = 5.0 + fib * 0.9 + ctx.fbm(5.0, 2, seed + 1) * 0.5 + M._dither(ctx, 0.5, seed + 2) - node * 2.0
    shade += ctx.edge(1.0) * 0.8 - (1.0 - ctx.ao) * 3.0
    s.use_ramp(RAMPS["bamboo"], shade=shade)
    s.rough = 0.45 + ctx.rand(seed + 3) * 0.05
    s.height = fib * 0.0001 + node * 0.0003
    return s


def arrowhead(ctx, seed=707, polish=False):
    """Forged iron point: dark, rust in the hollows, bright filed edges."""
    if polish:
        return M.steel(ctx, seed=seed, ramp="steel", center=8.0, dent=0.0, rust=0.0, polish=0.12, scratch=0.05)
    s = M.steel(ctx, seed=seed, ramp="steel", center=4.6, dent=0.2, rust=1.6, polish=0.4, scratch=0.15)
    s.shade += ctx.edge(1.0) * 1.5
    return s


def feather(ctx, seed=709):
    """Barred pheasant feather vanes, darker toward the trimmed edge."""
    s = Surface(ctx.N)
    along, across = M._grain_frame(ctx)
    a = np.sum(ctx.p * along, 1)
    c = np.sum(ctx.p * across, 1)
    barbs = ctx.fbm(np.array([200.0, 200.0, 200.0]), 1, seed, p=np.stack([a * 0.15 + c, a * 0.15 - c, a], 1))
    bar = np.mod(a / 0.013 + ctx.fbm(30.0, 2, seed + 1) * 0.25, 1.0) < 0.38
    shade = 5.6 + barbs * 0.8 + M._dither(ctx, 0.6, seed + 2) - bar * 3.0
    shade -= ctx.edge_soft(3.0) * 1.2 + (1.0 - ctx.ao) * 2.5
    s.use_ramp(RAMPS["feather"], shade=shade)
    s.rough = np.full(ctx.N, 0.8)
    s.height = barbs * 0.0002
    return s


def cord(ctx, seed=711):
    """Slow match: a loosely twisted three-strand hemp cord."""
    s = Surface(ctx.N)
    k = np.mod(ctx.uvm[:, 0] / 0.0068 + ctx.uvm[:, 1] / 0.0105, 1.0)
    ply = np.abs(np.mod(k * 3.0, 1.0) - 0.5) * 2.0
    fuzz = ctx.rand(seed) > 0.9
    shade = 3.6 + (0.55 - ply) * 2.4 + ctx.fbm(9.0, 2, seed + 1) * 0.7 + fuzz * 0.8 + M._dither(ctx, 0.5, seed + 2)
    shade += np.clip(ctx.curv, 0, 1) * 1.0 - (1.0 - ctx.ao) * 3.0
    s.use_ramp(RAMPS["cord"], shade=shade)
    s.rough = np.full(ctx.N, 0.92)
    s.height = (0.55 - ply) * 0.0004
    return s


def char(ctx, seed=713, tip=None):
    """Burnt end of the slow match: grey ash with a few live sparks."""
    s = Surface(ctx.N)
    shade = 2.4 + ctx.fbm(60.0, 2, seed) * 1.4 + M._dither(ctx, 1.0, seed + 1)
    s.use_ramp(RAMPS["ash"], shade=shade)
    s.rough = np.full(ctx.N, 0.95)
    spark = ctx.rand(seed + 2) > 0.93
    if tip is not None:
        near = np.linalg.norm(ctx.p - np.asarray(tip), axis=1) < 0.009
        spark |= near & (ctx.fbm(80.0, 2, seed + 3) > 0.1)
    s.use_ramp(M.P["ember"], mask=spark, shade=np.full(ctx.N, 3.5) + M._dither(ctx, 1.5, seed + 4))
    s.emit = np.where(spark[:, None], s.colors() * 0.7, 0.0)
    return s


def ember(ctx, seed=715):
    """The glowing tip of the slow match: orange-hot with dark cracks."""
    s = M.glow(ctx, "ember", 5.6, strength=1.0, rough=0.9, seed=seed)
    f1, f2, _ = ctx.worley(140.0, seed + 1)
    crack = (f2 - f1) < 0.12
    s.shade[crack] -= 2.4
    s.emit = s.colors() * 1.0
    return s


def silk(ctx, seed=717):
    """Red silk cord: twisted, with a soft sheen."""
    s = Surface(ctx.N)
    k = np.mod(ctx.uvm[:, 0] / 0.006 + ctx.uvm[:, 1] / 0.008, 1.0)
    ply = np.abs(np.mod(k * 2.0, 1.0) - 0.5) * 2.0
    shade = 5.0 + (0.55 - ply) * 2.6 + ctx.fbm(8.0, 2, seed) * 0.5 + M._dither(ctx, 0.5, seed + 1)
    shade += np.clip(ctx.curv, 0, 1) * 1.2 - (1.0 - ctx.ao) * 3.5
    s.use_ramp(RAMPS["silk"], shade=shade)
    s.rough = 0.42 + ply * 0.15
    s.height = (0.55 - ply) * 0.0003
    return s


def nozzle(ctx, seed=719, hot=True):
    """Clay plug at the back of the powder tube; glowing when it burns."""
    if hot:
        s = M.glow(ctx, "ember", 6.2, strength=1.0, rough=0.9, seed=seed)
        r = np.linalg.norm(ctx.p[:, [0, 2]], axis=1)
        s.shade -= np.clip(r / 0.012, 0, 1) * 2.5
        s.emit = s.colors() * 1.0
        return s
    s = Surface(ctx.N)
    s.use_ramp(RAMPS["clay"], shade=2.5 + ctx.fbm(40.0, 2, seed) + M._dither(ctx, 0.8, seed + 1))
    s.rough = np.full(ctx.N, 0.9)
    return s


ARROW_FNS = {"paper": paper, "twine": twine, "shaft": bamboo, "head": arrowhead, "fletch": feather}


# --------------------------------------------------------------------------
# the fire-arrow (singijeon), built along local +Y and placed by a matrix
# --------------------------------------------------------------------------

def arrow_front(p, place, F, tube_len, rt=0.0098, rs=0.0034, head_len=0.031, nose=0.010, seg=10, wraps=True):
    """The front of a fire-arrow along local +Y: the red paper powder tube
    (cylinder ending at y = F, tapering to a twine-bound nose), a short bit
    of bamboo shaft, the iron socket and a flat leaf-shaped point. Returns
    the new faces (already moved by ``place``) and the tip's local y."""
    fs = []
    y0 = F - tube_len
    tot = tube_len + nose
    fs += kit.seg(p, (0, y0, 0), (0, F + nose, 0),
                  [(rt, 0.0), (rt, tube_len / tot), (rt * 0.94, (tube_len + 0.3 * nose) / tot),
                   (rt * 0.66, (tube_len + 0.75 * nose) / tot), (rt * 0.48, 1.0)], "paper", segments=seg)
    if wraps:
        for yy, rr, w in ((F - 0.009, rt + 0.0007, 0.0045), (F + 0.0028, rt * 0.93 + 0.0006, 0.0034)):
            fs += kit.seg(p, (0, yy - w / 2, 0), (0, yy + w / 2, 0), [(rr, 0), (rr, 1)], "twine", segments=seg,
                          caps=False)
    fs += kit.seg(p, (0, F + nose - 0.002, 0), (0, F + nose + 0.008, 0), [(rs, 0), (rs, 1)], "shaft", segments=6)
    ys = F + nose + 0.006
    fs += kit.seg(p, (0, ys, 0), (0, ys + 0.007, 0), [(rs * 1.28, 0), (rs * 1.12, 1)], "head", segments=6)
    tip = ys + 0.007 + head_len
    fs += kit.seg(p, (0, ys + 0.007, 0), (0, tip, 0),
                  [(rs * 1.12, 0.0), (rs * 2.15, 0.28), (rs * 1.75, 0.62), (0.0009, 1.0)], "head", segments=4,
                  squash=(1.0, 0.36), smooth=False)
    p.move(fs, place)
    return fs, tip


def vane(p, y0, y1, r0, h, thick=0.0012, mat="fletch"):
    """One feather vane in the local YZ plane (along +Y, rising to +Z from
    radius r0): low at the front, tallest near the back, cut square."""
    L = y1 - y0
    outline = [(y0, r0), (y1, r0), (y1 - L * 0.18, r0 + h * 0.42), (y0 + L * 0.3, r0 + h * 0.95),
               (y0 + L * 0.06, r0 + h), (y0, r0 + h * 0.86)]
    faces = p.ngon_prism(outline, -thick / 2, thick / 2, mat)
    # prism built in (a, b, c) = (y, z, x): permute onto the world axes
    perm = kit.T(0, 0, 0)
    perm[0][0], perm[0][1], perm[0][2] = 0.0, 0.0, 1.0
    perm[1][0], perm[1][1], perm[1][2] = 1.0, 0.0, 0.0
    perm[2][0], perm[2][1], perm[2][2] = 0.0, 1.0, 0.0
    p.move(faces, perm)
    return faces


def arrow_full(p, place, L=0.5, rt=0.012, rs=0.0042, head_len=0.036, nose=0.012, tube_len=0.095, seg=10,
               fletch_len=0.085, fletch_h=0.013, nozzle_slot="nozzle", hidden_back=False, vane_phase=0.0,
               shaft_gap=None):
    """A whole fire-arrow along local +Y, centred on the shaft (y from -L/2
    to +L/2). ``hidden_back``: the powder tube's back end is hidden (inside
    a launcher), so it gets no nozzle plug and no lashing. ``shaft_gap``
    (y0, y1): leave the shaft out between these local y (the stretch that
    never shows inside a launcher; saves atlas space). Returns (faces, y of
    the powder tube's back end)."""
    tip = L / 2
    F = tip - head_len - 0.013 - nose
    fs, _ = arrow_front(p, kit.T(0, 0, 0), F, tube_len, rt, rs, head_len, nose, seg)
    yb = F - tube_len
    if not hidden_back:
        # clay nozzle plug at the back of the powder tube (the flame comes out here)
        fs += kit.seg(p, (0, yb - 0.0018, 0), (0, yb + 0.0004, 0), [(rt * 0.78, 0), (rt * 0.7, 1)], nozzle_slot,
                      segments=seg)
    # shaft from the swollen nock into the powder tube
    y_nock = -L / 2
    if shaft_gap is None:
        fs += kit.seg(p, (0, y_nock, 0), (0, yb + 0.002, 0),
                      [(rs * 1.12, 0.0), (rs, 0.016 / L), (rs, 1.0)], "shaft", segments=6)
    else:
        g0, g1 = shaft_gap
        n = g0 - y_nock
        back = p.lathe([(rs * 1.12, 0.0), (rs, 0.016), (rs, n)], "shaft", segments=6, cap_top=False)
        p.move(back, kit.align((0, y_nock, 0), (0, g0, 0)))
        fs += back
        fs += kit.seg(p, (0, g1, 0), (0, yb + 0.002, 0), [(rs, 0.0), (rs, 1.0)], "shaft", segments=6, caps=False)
    # lashing at both ends of the fletching (and round the powder tube's back end)
    yf0, yf1 = y_nock + 0.014, y_nock + 0.014 + fletch_len
    wraps = [(yf0 - 0.002, rs + 0.0007, 0.005), (yf1 + 0.003, rs + 0.0007, 0.006)]
    if not hidden_back:
        wraps.append((yb + 0.006, rt + 0.0007, 0.0045))
    for yy, rr, w in wraps:
        fs += kit.seg(p, (0, yy - w / 2, 0), (0, yy + w / 2, 0), [(rr, 0), (rr, 1)], "twine", segments=6, caps=False)
    for k in range(3):
        v = vane(p, yf0, yf1, rs * 0.8, fletch_h)
        p.move(v, R('Y', 120.0 * k + vane_phase))
        fs += v
    p.move(fs, place)
    return fs, yb


# --------------------------------------------------------------------------
# gold-leaf motif: dragon among cloud scrolls (panel coordinates in metres)
# --------------------------------------------------------------------------

def _seg_d(px, py, a, b):
    ax, ay = a
    bx, by = b
    dx, dy = bx - ax, by - ay
    l2 = max(dx * dx + dy * dy, 1e-12)
    t = np.clip(((px - ax) * dx + (py - ay) * dy) / l2, 0.0, 1.0)
    return np.hypot(px - ax - t * dx, py - ay - t * dy)


def _poly_d(px, py, pts):
    d = np.full(np.shape(px), np.inf)
    for a, b in zip(pts[:-1], pts[1:]):
        d = np.minimum(d, _seg_d(px, py, a, b))
    return d


def _spiral_d(px, py, cx, cy, r, turns=1.3, cw=1.0):
    """Distance to an Archimedean spiral of ``turns`` turns growing from the
    centre to radius r (cw = +1 / -1 for the turning sense)."""
    dx, dy = px - cx, py - cy
    rho = np.hypot(dx, dy)
    th = np.mod(np.arctan2(dy, dx) * cw, 2 * np.pi)
    total = 2 * np.pi * turns
    best = np.full(np.shape(px), np.inf)
    for k in range(int(math.ceil(turns)) + 1):
        ang = th + 2 * np.pi * k
        rk = r * ang / total
        best = np.where(ang <= total, np.minimum(best, np.abs(rho - rk)), best)
    return best


def cloud(px, py, cx, cy, r, sx=1.0):
    """Distance field of a Korean cloud scroll (unmun): a big curl, a small
    counter-curl beside it, an arc over both and a trailing wisp."""
    x = (px - cx) * sx
    y = py - cy
    d = _spiral_d(x, y, 0.0, 0.0, r, 1.25, 1.0)
    d = np.minimum(d, _spiral_d(x, y, 1.75 * r, 0.12 * r, 0.72 * r, 1.1, -1.0))
    d = np.minimum(d, _poly_d(x, y, [(-r, 0.0), (-0.75 * r, 0.75 * r), (0.15 * r, 1.12 * r), (1.0 * r, 1.0 * r),
                                     (1.6 * r, 0.85 * r), (2.3 * r, 0.5 * r)]))
    d = np.minimum(d, _poly_d(x, y, [(0.05 * r, -r), (1.0 * r, -1.08 * r), (2.0 * r, -0.95 * r), (2.9 * r, -1.05 * r),
                                     (3.7 * r, -0.8 * r)]))
    return d


def dragon(s, t, L, H, texel, head_dir=1.0):
    """Masks of a sinuous dragon chasing a flaming pearl in a panel of
    length L (s = 0..L, tail at 0, pearl at L) and height H (t = -H/2..H/2,
    +t = spine side). Returns (fill, line, dark) boolean arrays: gold
    fill, gold fine lines, and lacquer showing through (eye, mouth,
    scales)."""
    W = 0.085 * H                       # body half-width at its fullest
    amp = 0.2 * H
    hs = L - 4.0 * W                    # head centre
    neck = hs - 0.9 * W
    sn = np.clip(s / neck, 0.0, 1.0)

    def center(u):
        ph = 2 * np.pi * 1.15 * u + 0.5
        return amp * np.sin(ph) * (0.55 + 0.45 * u)

    yc = center(sn)
    eps = 1e-3
    dyc = (center(np.clip(sn + eps, 0, 1)) - center(np.clip(sn - eps, 0, 1))) / (2 * eps * neck)
    d = (t - yc) / np.sqrt(1.0 + dyc * dyc)
    w = W * (0.18 + 0.82 * smoothstep(0.0, 0.3, sn)) * (1.0 - 0.32 * smoothstep(0.78, 1.0, sn))
    zone = (s > 0.02 * neck) & (s < neck + 0.4 * W)
    body = zone & (np.abs(d) < w)
    edge = body & (np.abs(d) > w - 1.05 * texel)
    chev = np.mod(s / (0.55 * W) + np.abs(d) / W * 0.7, 1.0) < 0.22
    scales = body & ~edge & chev & (np.abs(d) < w - 1.7 * texel) & (d > -0.45 * w)
    belly = body & ~edge & (d < -0.5 * w) & (np.mod(s / (0.42 * W), 1.0) < 0.22)
    fin_h = 0.55 * W * (1.0 - np.abs(2.0 * np.mod(s / (0.7 * W), 1.0) - 1.0))
    fins = (sn > 0.06) & (sn < 0.92) & (d >= w - texel) & (d < w + fin_h)
    fill = body | fins
    line = np.zeros(np.shape(s), dtype=bool)
    dark = scales | belly
    # four legs with three-toed claws, front pair reaching forward
    for u0, fwd in ((0.24, -1.0), (0.34, -1.0), (0.6, 1.0), (0.7, 1.0)):
        sl = u0 * neck
        tl = float(center(u0))
        knee = (sl + fwd * 0.55 * W, tl - 1.35 * W)
        foot = (sl + fwd * 0.15 * W, tl - 2.05 * W)
        leg = _poly_d(s, t, [(sl, tl - 0.4 * W), knee, foot])
        fill |= leg < 0.27 * W
        for a in (200.0, 245.0, 290.0):
            ar = math.radians(a + fwd * 15.0)
            tipc = (foot[0] + 0.48 * W * math.cos(ar), foot[1] + 0.48 * W * math.sin(ar))
            line |= _seg_d(s, t, foot, tipc) < 0.6 * texel + 0.03 * W
    # head: skull, long snout, open jaw, eye, two horns, whiskers
    th = float(center(1.0)) + 0.25 * W
    head = ((s - hs) / (1.25 * W)) ** 2 + ((t - th) / (0.78 * W)) ** 2 < 1.0
    snout = ((s - hs - 1.15 * W) / (0.95 * W)) ** 2 + ((t - th - 0.05 * W) / (0.42 * W)) ** 2 < 1.0
    jaw = ((s - hs - 0.95 * W) / (0.9 * W)) ** 2 + ((t - th + 0.55 * W) / (0.24 * W)) ** 2 < 1.0
    fill |= head | snout | jaw
    mouth = (s > hs + 0.35 * W) & (np.abs(t - th + 0.33 * W) < (s - hs - 0.35 * W) * 0.32) & (head | snout | jaw)
    eye_d = np.hypot(s - hs - 0.2 * W, t - th - 0.3 * W)
    dark |= mouth | (eye_d < max(0.16 * W, 0.9 * texel))
    for off in (0.0, 0.3):
        horn = _poly_d(s, t, [(hs - 0.25 * W + off * W, th + 0.55 * W), (hs - 1.1 * W + off * W, th + 1.25 * W),
                              (hs - 2.0 * W + off * W, th + 1.35 * W)])
        fill |= horn < 0.17 * W + 0.5 * texel
    for sgn in (1.0, -1.0):
        pts = [(hs + 1.95 * W - k * 0.45 * W, th + sgn * (0.25 * W + 0.35 * W * k ** 0.8)
                + 0.3 * W * math.sin(k * 1.4)) for k in range(7)]
        line |= _poly_d(s, t, pts) < 0.6 * texel
    # the flaming pearl ahead of the snout
    pc = (L - 0.85 * W, th + 0.35 * W)
    pd = np.hypot(s - pc[0], t - pc[1])
    pearl = pd < 0.52 * W
    fill |= pearl
    dark |= pearl & (_spiral_d(s, t, pc[0], pc[1], 0.42 * W, 1.2, 1.0) < 0.6 * texel)
    for a in (60.0, 95.0, 130.0):
        ar = math.radians(a)
        b0 = (pc[0] + 0.5 * W * math.cos(ar), pc[1] + 0.5 * W * math.sin(ar))
        b1 = (pc[0] + 1.05 * W * math.cos(ar + 0.35), pc[1] + 1.05 * W * math.sin(ar + 0.35))
        line |= _seg_d(s, t, b0, b1) < 0.6 * texel + 0.04 * W
    # cloud scrolls in the spaces the body leaves
    r = 0.11 * H
    cl = np.full(np.shape(s), np.inf)
    for u0 in (0.1, 0.32, 0.55, 0.8):
        side = -np.sign(center(u0)) if abs(center(u0)) > 1e-4 else 1.0
        cy = side * (H * 0.5 - 1.25 * r)
        cl = np.minimum(cl, cloud(s, t, u0 * neck - 1.2 * r, cy, r, 1.0 if side > 0 else -1.0))
    cl_line = (cl < 0.6 * texel) & ~fill
    line |= cl_line
    return fill, line, dark


def cloud_frieze(s, t, L, H, texel):
    """A row of alternating cloud scrolls along a narrow panel."""
    r = 0.26 * H
    d = np.full(np.shape(s), np.inf)
    n = max(1, int(L / (4.6 * r)))
    for k in range(n):
        cx = (k + 0.5) * L / n - 1.3 * r
        sx = 1.0 if k % 2 == 0 else -1.0
        cx = cx if sx > 0 else cx + 2.6 * r
        d = np.minimum(d, cloud(s, t, cx, 0.05 * H * sx, r, sx))
    return d < 0.6 * texel
