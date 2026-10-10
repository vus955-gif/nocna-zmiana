"""Shared bits for the upgrade parts and the mastery finish of vm_shotgun,
vm_gatling and vm_flare (not a model: build_models never lists it).

Upgrade parts are named ``upg_*``; the game shows one per upgrade level
bought and swaps the whole model to the ``<model>_master`` texture set when
every upgrade of the weapon is maxed. The master set uses the same mesh and
UVs, only other material functions: deep polished bluing with bright edges
and no wear, fine engraved scrollwork (1-texel cut + lit bevel, also in the
height channel) with gold inlay lines, figured glossy walnut, polished brass.

Everything here is drawn in texel space (metre UVs / texel), so lines stay
one texel wide and crisp at any px/m.
"""
import math

import numpy as np
from mathutils import Vector

from artlib import materials as M
from artlib import noise
from artlib.painter import Surface

P = M.P

# fire-blued steel for the mastery finish: deeper and bluer than steel_blued,
# light enough at the top that a metallic surface never goes black
DEEP_BLUE = M.hexramp("#04050a", "#080b16", "#0d1323", "#131b32", "#1a2543", "#223155", "#2c3f69", "#384e7d",
                      "#475f91", "#5a74a6", "#7590bd", "#9fb4d6")
# bright polished nickel / magnesium silver
BRIGHT = M.hexramp("#1d2026", "#2c3038", "#3e434c", "#535963", "#6a717b", "#838a94", "#9ca3ac", "#b5bbc3",
                   "#cdd2d8", "#e2e6ea", "#f3f5f7")
# tan saddle leather (the gloves are black: the holder must not read as glove)
SADDLE = M.hexramp("#1c0f07", "#2b170b", "#3c2110", "#4e2c16", "#61381c", "#744524", "#88532d", "#9b6238",
                   "#ad7346")


# --------------------------------------------------------------------------
# geometry
# --------------------------------------------------------------------------

def arc_band(p, cx, cz, r_in, r_out, y0, y1, a0, a1, mat, n, ends=True):
    """Partial thick tube round an axis parallel to Y through (cx, *, cz):
    angles a0 -> a1 (radians, atan2(z - cz, x - cx)), from y0 to y1. The
    outer and inner walls keep unrolled UVs (u = arc length, v = y), so
    patterns drawn in texel space wrap without seams; the rims are
    box-projected. ``ends`` closes the two cut ends of the arc."""
    def ring(r, y):
        out = []
        for i in range(n + 1):
            a = a0 + (a1 - a0) * i / n
            out.append(p.bm.verts.new((cx + r * math.cos(a), y, cz + r * math.sin(a))))
        return out

    o0, o1, i0, i1 = ring(r_out, y0), ring(r_out, y1), ring(r_in, y0), ring(r_in, y1)
    faces = []

    def quad(vs, uvs, want, smooth, lock=True):
        f = p._face(vs, mat, smooth)
        f.normal_update()
        if f.normal.dot(want) < 0:
            f.normal_flip()
            # flipping reverses the loops: re-apply the UVs by vertex
        if uvs is not None:
            by_vert = dict(zip(vs, uvs))
            for loop in f.loops:
                loop[p.uv].uv = by_vert[loop.vert]
            f[p.lock] = 1
        faces.append(f)
        return f

    for i in range(n):
        am = a0 + (a1 - a0) * (i + 0.5) / n
        radial = Vector((math.cos(am), 0.0, math.sin(am)))
        ua, ub = r_out * (a0 + (a1 - a0) * i / n), r_out * (a0 + (a1 - a0) * (i + 1) / n)
        quad([o0[i], o0[i + 1], o1[i + 1], o1[i]], [(ua, y0), (ub, y0), (ub, y1), (ua, y1)], radial, True)
        ua, ub = r_in * (a0 + (a1 - a0) * i / n), r_in * (a0 + (a1 - a0) * (i + 1) / n)
        quad([i0[i], i0[i + 1], i1[i + 1], i1[i]], [(ua, y0), (ub, y0), (ub, y1), (ua, y1)], -radial, True)
        quad([o0[i], o0[i + 1], i0[i + 1], i0[i]], None, Vector((0, -1, 0)), False)
        quad([o1[i], o1[i + 1], i1[i + 1], i1[i]], None, Vector((0, 1, 0)), False)
    if ends:
        for k, sgn in ((0, -1.0), (n, 1.0)):
            a = a0 + (a1 - a0) * k / n
            tang = Vector((-math.sin(a), 0.0, math.cos(a))) * sgn * (1.0 if a1 > a0 else -1.0)
            quad([o0[k], o1[k], i1[k], i0[k]], None, tang, False)
    return faces


def ring(p, center, axis, r_in, r_out, t0, t1, mat, segments=12, phase=0.0, inner=True):
    """Solid collar (closed lathe profile) round ``axis`` through ``center``
    from t0 to t1 along the axis: outer and inner walls plus both faces
    (``inner=False``: no inner wall, for a band hugging something solid)."""
    from artlib import kit
    prof = [(r_in, t0), (r_out, t0), (r_out, t1), (r_in, t1)] + ([(r_in, t0)] if inner else [])
    f = p.lathe(prof, mat, segments=segments, cap_bottom=False, cap_top=False, smooth=True, phase=phase)
    a = Vector(center)
    d = Vector(axis).normalized()
    p.move(f, kit.align(a, a + d))
    return f


# --------------------------------------------------------------------------
# texel-space marks
# --------------------------------------------------------------------------

def texel_uv(ctx):
    """Metre UVs in texel units (texel centres at x.5)."""
    return ctx.uvm[:, 0] / ctx.texel, ctx.uvm[:, 1] / ctx.texel


def knurl(ctx):
    """Diamond knurling in texel space: grooves along both diagonals every
    4 texels, each diamond a little pyramid lit from the upper left.
    Returns a per-texel shade offset and the groove mask."""
    u, v = texel_uv(ctx)
    iu = np.floor(u).astype(np.int64)
    iv = np.floor(v).astype(np.int64)
    a = np.mod(iu + iv, 4)
    b = np.mod(iu - iv, 4)
    groove = (a == 0) | (b == 0)
    apex = (a == 2) & (b == 2)
    # the four facets round the apex: (a, b) = (1, 1) left, (3, 3) right,
    # (3, 1) upper, (1, 3) lower
    lit = ((a == 1) & (b == 1)) | ((a == 3) & (b == 1))
    shadow = ((a == 3) & (b == 3)) | ((a == 1) & (b == 3))
    off = np.where(groove, -2.6, 0.0) + apex * 1.8 + lit * 0.9 - shadow * 0.7
    return off, groove


def _spiral_cut(u, v, cell, pitch, turns, seed, wobble):
    """1-texel spiral per cell (half-drop rows, random turn and chirality)."""
    row = np.floor(v / cell)
    uu = u + np.mod(row, 2) * cell * 0.5
    col = np.floor(uu / cell)
    cid = (col.astype(np.int64) * 7919 + row.astype(np.int64) * 104729)
    jx = (noise.rand_cells(cid, seed + 2) - 0.5) * wobble
    jy = (noise.rand_cells(cid, seed + 3) - 0.5) * wobble
    lu = uu - (col + 0.5) * cell - jx
    lv = v - (row + 0.5) * cell - jy
    rot = noise.rand_cells(cid, seed) * math.tau
    chir = np.where(noise.rand_cells(cid, seed + 1) > 0.5, 1.0, -1.0)
    r = np.hypot(lu, lv)
    a = np.mod(np.arctan2(lv, lu) * chir + rot, math.tau)
    b = pitch / math.tau
    k = np.round((r / b - a) / math.tau)
    phi = a + math.tau * k
    d = np.abs(r - b * phi)
    end = turns * math.tau
    on = (d < 0.5) & (phi > 1.2) & (phi < end)
    # the outer arm runs on and opens out (a leaf stem reaching toward the
    # next scroll) instead of stopping dead
    kt = np.ceil((end - a) / math.tau)
    pt = a + math.tau * kt
    dt = pt - end
    rt = b * pt + 0.2 * dt * dt
    tail = (dt < 0.8 * math.pi) & (np.abs(r - rt) < 0.5) & (rt < cell * 0.62)
    return on | tail


def scroll(ctx, cell=13.0, pitch=2.6, turns=2.1, seed=0, wobble=1.5):
    """Engraved scrollwork in texel space. Returns (cut, lit): the 1-texel
    groove and the texel just above it, which catches the light (pixel-art
    engraving: a dark line with a bright bevel reads on any metal)."""
    u, v = texel_uv(ctx)
    off = ctx.part * 17.0
    cut = _spiral_cut(u + off, v + off * 0.5, cell, pitch, turns, seed, wobble)
    above = _spiral_cut(u + off, v - 1.0 + off * 0.5, cell, pitch, turns, seed, wobble)
    return cut, above & ~cut


def border(ctx, inset=2.5):
    """1-texel line ``inset`` texels inside every sharp convex edge of a face
    (the inlaid border of a panel). Narrow faces (bevels, rods) get none."""
    return np.abs(ctx.convex - inset * ctx.texel) < 0.5 * ctx.texel


def rings_at(ctx, axis_pos, positions, half=0.5):
    """1-texel bands round a lathe (faces whose normal is across ``axis``):
    True where the coordinate ``axis_pos`` (per texel) is within ``half``
    texels of one of ``positions`` (metres)."""
    out = np.zeros(ctx.N, dtype=bool)
    for y in positions:
        out |= np.abs(axis_pos - y) < half * ctx.texel
    return out


# --------------------------------------------------------------------------
# finishing helpers (operate on a Surface)
# --------------------------------------------------------------------------

def engrave(ctx, s, cut, lit, depth=0.00025, dark=3.0, light=2.0):
    s.shade = np.where(cut, s.shade - dark, s.shade)
    s.shade = np.where(lit, s.shade + light, s.shade)
    s.height = s.height - cut * depth
    s.rough = np.where(cut, np.maximum(s.rough, 0.42), s.rough)
    return s


def inlay_gold(ctx, s, mask, seed=0, center=7.2, metal=1.0, rough=0.22):
    """Gold wire flush in the surface (polished, metallic, a hair proud).
    Thin coach lines on paint read better half metallic (``metal`` < 1):
    a fully metallic 1-texel line mirrors the dark room and goes black."""
    if not mask.any():
        return s
    shade = np.full(ctx.N, center) + M._dither(ctx, 0.7, seed) + ctx.edge(1.0) * 1.0
    s.use_ramp(P["gold"], mask=mask, shade=shade)
    s.metal = np.where(mask, metal, s.metal)
    s.rough = np.where(mask, rough, s.rough)
    s.height = s.height + mask * 0.00004
    return s


# --------------------------------------------------------------------------
# upgrade materials (base look)
# --------------------------------------------------------------------------

def polished_steel(ctx, seed=701, center=8.0, polish=0.14):
    """Bright polished steel (chokes, crank sleeve): calm, no rust, bright edges."""
    return M.steel(ctx, seed=seed, ramp="steel", center=center, dent=0.0, rust=-3.0, polish=polish, scratch=0.06)


def knurled(ctx, s, mask, center=None):
    """Cuts knurling into ``s`` on ``mask``. The band is repainted from a
    calm base (``center``, default: the surface's own mean there) so the
    diamonds read cleanly instead of fighting the metal's noise."""
    if not mask.any():
        return s
    off, g = knurl(ctx)
    base = np.mean(s.shade[mask]) if center is None else center
    calm = base - (1.0 - ctx.ao) * 3.0 + off
    s.shade = np.where(mask, calm, s.shade)
    g &= mask
    s.height = np.where(mask, (off > 1.0) * 0.0001 - g * 0.0003, s.height)
    s.rough = np.where(g, np.minimum(s.rough + 0.25, 1.0), s.rough)
    return s


def saddle_leather(ctx, seed=711, gloss=0.42, stitch=True):
    """Tan saddle leather: pebbled grain, darker oiled edges, a stitched
    seam two texels in from every edge."""
    s = Surface(ctx.N)
    grain = ctx.fbm(180.0, 2, seed) * 0.6
    shade = 4.6 + ctx.fbm(14.0, 3, seed + 1) * 0.8 + grain + M._dither(ctx, 0.6, seed + 2)
    shade -= ctx.edge_soft(2.0) * 1.2 + ctx.cavity(3.0) * 1.6 + (1.0 - ctx.ao) * 3.0
    shade += np.clip(ctx.curv, 0, 1) * 1.0
    s.use_ramp(SADDLE, shade=shade)
    s.rough = gloss + np.clip(ctx.fbm(9.0, 2, seed + 3), 0, 1) * 0.2
    s.height = grain * 0.0002
    if stitch:
        u, v = texel_uv(ctx)
        seam = np.abs(ctx.convex - 2.0 * ctx.texel) < 0.5 * ctx.texel
        thread = seam & (np.mod(np.floor(u) + np.floor(v), 3) != 0)
        s.shade = np.where(seam & ~thread, s.shade - 1.5, s.shade)
        s.use_ramp(P["cloth_white"], mask=thread, shade=np.full(ctx.N, 4.6) + M._dither(ctx, 0.8, seed + 4))
        s.rough = np.where(thread, 0.8, s.rough)
        s.height = s.height + thread * 0.0002 - (seam & ~thread) * 0.0002
    return s


def shell_head_marks(ctx, s, centers, top_z, r_rim, r_primer, seed=0):
    """Paints rim line and primer cup on the top (n.z > 0) of shell heads
    standing at ``centers`` [(x, y)] with the head face at ``top_z``."""
    top = (ctx.n[:, 2] > 0.8) & (np.abs(ctx.p[:, 2] - top_z) < 0.002)
    if not top.any():
        return s
    d = np.full(ctx.N, np.inf)
    for x, y in centers:
        d = np.minimum(d, np.hypot(ctx.p[:, 0] - x, ctx.p[:, 1] - y))
    rim = top & (np.abs(d - (r_rim - 0.6 * ctx.texel)) < 0.5 * ctx.texel)
    cup = top & (d < r_primer + 0.5 * ctx.texel)
    pr = top & (d < r_primer - 0.3 * ctx.texel)
    s.shade = np.where(rim, s.shade - 2.2, s.shade)
    s.shade = np.where(cup & ~pr, s.shade - 2.6, s.shade)
    s.use_ramp(P["copper"], mask=pr, shade=np.full(ctx.N, 6.2) + M._dither(ctx, 0.8, seed))
    s.height = s.height - rim * 0.0002 - (cup & ~pr) * 0.0002
    return s


def perforated(ctx, s, mask, pitch=4, hole=0.5, seed=0):
    """Round perforations on a sheet (u around, v along, staggered rows):
    each hole 2x2 texels, dark (the shadowed gap under the sheet), with a
    bright texel on its lower lip and a dark one on the upper."""
    u, v = texel_uv(ctx)
    row = np.floor(v / pitch)
    uu = u + np.mod(row, 2) * pitch * 0.5
    fu = uu - np.floor(uu / pitch) * pitch
    fv = v - row * pitch
    c = pitch * 0.5
    du, dv = fu - c, fv - c
    inside = mask & (np.abs(du) <= hole) & (np.abs(dv) <= hole)
    lower = mask & ~inside & (np.abs(du) <= hole) & (dv < -hole) & (dv > -hole - 1)
    upper = mask & ~inside & (np.abs(du) <= hole) & (dv > hole) & (dv < hole + 1)
    s.shade = np.where(inside, 0.6 + M._dither(ctx, 0.6, seed), s.shade)
    s.shade = np.where(lower, s.shade + 1.1, s.shade)
    s.shade = np.where(upper, s.shade - 1.2, s.shade)
    s.height = s.height - inside * 0.0012
    s.rough = np.where(inside, 0.9, s.rough)
    s.metal = np.where(inside, 0.2, s.metal)
    return s


# --------------------------------------------------------------------------
# mastery finish
# --------------------------------------------------------------------------

def master_blued(ctx, seed=801, center=5.4, engrave_mask=None, gold_mask=None, scroll_seed=None,
                 border_gold=True, bright_mask=None):
    """Deep polished fire bluing: barely any brushing, no wear, crisp bright
    edges (only inside ``bright_mask`` when given: thin flat-shaded rods are
    all edge and would turn white); optional scrollwork (on
    ``engrave_mask``) and gold inlay lines (panel borders and ``gold_mask``)."""
    s = Surface(ctx.N)
    along, across = M._grain_frame(ctx)
    q = np.stack([np.sum(ctx.p * along, 1), np.sum(ctx.p * ctx.n, 1), np.sum(ctx.p * across, 1)], axis=1)
    polish = ctx.fbm(np.array([3.0, 220.0, 220.0]), 2, seed, p=q)
    sheen = ctx.fbm(2.0, 2, seed + 1)
    shade = center + polish * 0.3 + sheen * 0.5 + M._dither(ctx, 0.35, seed + 2)
    shade += ctx.edge(2.0) * 1.0
    shade -= ctx.cavity(3.0) * 1.8 + (1.0 - ctx.ao) * 3.0
    s.use_ramp(DEEP_BLUE, shade=shade)
    # every sharp edge polished through the bluing to a crisp line of white steel
    edge = ctx.edge(1.0) > 0
    if bright_mask is not None:
        edge &= bright_mask
    s.use_ramp(BRIGHT, mask=edge, shade=np.full(ctx.N, 7.2) + M._dither(ctx, 0.6, seed + 4) - (1.0 - ctx.ao) * 3.0)
    s.metal = np.full(ctx.N, 0.92)
    s.rough = 0.2 + np.clip(sheen, 0, 1) * 0.05 + ctx.rand(seed + 3) * 0.02
    s.height = polish * 0.00004
    if engrave_mask is not None and engrave_mask.any():
        cut, lit = scroll(ctx, seed=seed + 5 if scroll_seed is None else scroll_seed)
        engrave(ctx, s, cut & engrave_mask, lit & engrave_mask, dark=2.4, light=2.4)
    g = border(ctx) if border_gold else np.zeros(ctx.N, dtype=bool)
    if gold_mask is not None:
        g = g | gold_mask
    inlay_gold(ctx, s, g, seed + 7)
    return s


def master_silver(ctx, seed=811, center=8.4, engrave_mask=None, gold_mask=None, border_gold=True):
    """Polished coin-silver action with English scroll and gold borders."""
    s = M.steel(ctx, seed=seed, ramp="steel", center=center, dent=0.0, rust=-3.0, polish=0.2, scratch=0.0)
    s.shade = s.shade + ctx.edge(1.0) * 0.6
    em = np.ones(ctx.N, dtype=bool) if engrave_mask is None else engrave_mask
    em = em & (ctx.convex > 4.0 * ctx.texel)
    cut, lit = scroll(ctx, cell=12.0, pitch=2.5, turns=2.0, seed=seed + 5)
    engrave(ctx, s, cut & em, lit & em, dark=3.6, light=1.2)
    g = border(ctx) if border_gold else np.zeros(ctx.N, dtype=bool)
    if gold_mask is not None:
        g = g | gold_mask
    inlay_gold(ctx, s, g, seed + 7)
    return s


def master_brass(ctx, seed=821, center=7.0, engrave_mask=None, ramp="brass"):
    """Polished bright brass: no tarnish, mirror-ish, crisp edges; optional
    scrollwork (dark cuts with a bright bevel)."""
    s = Surface(ctx.N)
    along, across = M._grain_frame(ctx)
    q = np.stack([np.sum(ctx.p * along, 1), np.sum(ctx.p * ctx.n, 1), np.sum(ctx.p * across, 1)], axis=1)
    polish = ctx.fbm(np.array([2.0, 120.0, 120.0]), 2, seed, p=q)
    shade = center + polish * 0.4 + ctx.fbm(2.0, 2, seed + 1) * 0.5 + M._dither(ctx, 0.35, seed + 2)
    shade += ctx.edge(1.0) * 2.4 + ctx.edge(2.0) * 0.8
    shade -= ctx.cavity(3.0) * 2.5 + (1.0 - ctx.ao) * 3.5
    s.use_ramp(P[ramp], shade=shade)
    s.metal = np.full(ctx.N, 1.0)
    s.rough = 0.18 + ctx.rand(seed + 3) * 0.03
    s.height = polish * 0.00005
    if engrave_mask is not None and engrave_mask.any():
        cut, lit = scroll(ctx, seed=seed + 5)
        engrave(ctx, s, cut & engrave_mask, lit & engrave_mask, dark=3.4, light=1.4)
    return s


def figured_walnut(ctx, seed=831, center=5.0, checker=None, period=0.0042):
    """Exhibition-grade walnut: fiddleback figure across the grain, dark
    mineral streaks, deep glossy oil finish; optional checkering mask."""
    s = M._wood_core(ctx, P["walnut_stock"], center, seed, ring_freq=13.0, contrast=1.3)
    along, across = M._grain_frame(ctx)
    a = np.sum(ctx.p * along, 1)
    c = np.sum(ctx.p * across, 1)
    d = np.sum(ctx.p * ctx.n, 1)
    q = np.stack([a, d, c], axis=1)
    warp = ctx.fbm(np.array([6.0, 6.0, 30.0]), 2, seed + 11, p=q)
    fiddle = np.sin(a * (math.tau / 0.0075) + warp * 2.2 + c * 40.0)
    s.shade = s.shade + fiddle * 0.75
    streak = np.abs(ctx.fbm(np.array([2.0, 9.0, 9.0]), 3, seed + 12, p=q + warp[:, None] * 0.02)) < 0.035
    s.shade = np.where(streak, s.shade - 1.6, s.shade)
    s.shade = s.shade + ctx.edge(1.0) * 1.2 - ctx.cavity(3.0) * 1.6 - (1.0 - ctx.ao) * 2.8
    s.rough = 0.14 + np.clip(ctx.fbm(3.0, 2, seed + 13), 0, 1) * 0.06 + ctx.cavity(3.0) * 0.2
    s.height = s.height + fiddle * 0.00006
    if checker is not None and checker.any():
        sub = M.checkering(ctx, M._wood_core(ctx, P["walnut_stock"], center - 0.2, seed + 20, ring_freq=13.0),
                           period=period)
        sub.rough = np.full(ctx.N, 0.4)
        s.merge(M._select(sub, checker), checker)
    return s


def enamel_gloss(ctx, ramp, center, seed=841):
    """Deep glossy coach enamel: smooth, no chips, a fine orange-peel
    highlight, bright edges."""
    s = Surface(ctx.N)
    peel = ctx.fbm(90.0, 2, seed)
    shade = center + ctx.fbm(3.0, 2, seed + 1) * 0.35 + peel * 0.25 + M._dither(ctx, 0.3, seed + 2)
    shade += ctx.edge(1.0) * 1.8 + ctx.edge(2.0) * 0.5
    shade -= ctx.cavity(3.0) * 1.8 + (1.0 - ctx.ao) * 3.2
    s.use_ramp(P[ramp], shade=shade)
    s.rough = 0.09 + ctx.rand(seed + 3) * 0.02
    s.metal = np.zeros(ctx.N)
    s.height = peel * 0.00008
    return s
