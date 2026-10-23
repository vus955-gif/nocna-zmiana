"""Materials of Floor I's roof props (the plant deck's tank, air handlers and
chimneys, the pigeon loft; tools/art/models/roof_*.py). Same rules as
materials.py / court_materials.py: colours from hand-picked ramps (dark ->
light) registered in the shared P, shading = steps along a ramp, patterns
in the surface's metre UVs or model space (Blender: z up).

  painted_plate   weathered painted steel plate: roller marks, chalky
                  fading on the upward faces, rust where the paint broke
                  (edges, joints), rust runs down from ``runs`` heights
  rivet_rows      rivet heads (a dot row with height) painted over a Surface
  droppings       pigeon droppings on the upward faces (the loft is next door)
  galvanised      dull spangled zinc of ladders, cowls, fan guards
  roof_steel      the railings' dark painted steel (Floor1ArtRoof.STEEL)
"""
import numpy as np

from . import court_materials  # noqa: F401  (registers steel_paint)
from .materials import P, _age, _dither, hexramp, smoothstep
from .painter import Surface

P.update({
    # the tank's grey-green lead paint, chalky where the sun and rain took it
    "tank_paint": hexramp("#121613", "#1a1f1b", "#232a25", "#2d352f", "#38413a", "#444e46", "#515b52",
                          "#5f695f", "#6e786d", "#7e877c"),
    # rust from bloom to streak (orange-brown on grey, dark in the pits)
    "rust_run": hexramp("#1e0e07", "#2c150a", "#3b1d0e", "#4c2612", "#5d3017", "#6e3a1d", "#804624",
                        "#92532d"),
    "zinc": hexramp("#1d1f21", "#272a2d", "#323639", "#3e4246", "#4b4f53", "#585d61", "#666b6f", "#757a7d",
                    "#858a8c"),
    "dropping": hexramp("#6e6c64", "#8a877e", "#a6a399", "#c1beb3", "#d8d5cb"),
    "air_blue": hexramp("#0f1519", "#151d23", "#1c262e", "#24313a", "#2d3c46", "#374853", "#435561",
                        "#506370", "#5e727f"),
})


def painted_plate(ctx, ramp="tank_paint", center=5.2, seed=801, rust=1.0, runs=(), run_len=0.45, fade=1.0):
    """Weathered painted plate. ``runs``: heights (model z) of joints that
    weep rust: streaks run down from each for about ``run_len`` m."""
    s = Surface(ctx.N)
    z = ctx.p[:, 2]
    up = np.clip(ctx.n[:, 2], 0.0, 1.0)
    roller = ctx.fbm(np.array([2.0, 2.0, 9.0]), 2, seed) * 0.4
    shade = center + ctx.fbm(1.2, 3, seed + 1) * 0.9 + roller + _dither(ctx, 0.6, seed + 2)
    shade += up * 1.2 * fade + smoothstep(0.1, 0.6, ctx.fbm(2.5, 3, seed + 3)) * 0.8 * fade   # chalky
    s.use_ramp(P[ramp], shade=shade)
    _age(ctx, s, cavity=1.8, ao=3.2, edge=1.0)
    broke = (ctx.edge_soft(3.0) * 0.7 + ctx.cavity(3.0) * 0.6 + np.clip(ctx.fbm(7.0, 3, seed + 4), 0, 1) * 0.8) > 1.0 - 0.25 * rust
    streak = np.zeros(ctx.N, dtype=bool)
    if runs:
        # down the side faces (not the tops): a comb of thin runs, fading as they go
        side = np.abs(ctx.n[:, 2]) < 0.6
        comb = ctx.fbm(np.array([38.0, 38.0, 1.3]), 2, seed + 5)
        # weeping in patches (where the paint failed at the joint), not all along it
        weep = np.clip(ctx.fbm(np.array([1.6, 1.6, 0.4]), 2, seed + 12) * 1.4 + 0.25, 0.0, 1.0)
        for h in runs:
            below = (z < h) & (z > h - run_len * 1.6)
            fall = 1.0 - np.clip((h - z) / (run_len * (0.5 + weep)), 0.0, 1.0)
            streak |= side & below & (comb * 0.5 + 0.5 > 1.0 - 0.6 * fall * weep * rust)
    s.use_ramp(P["rust_run"], mask=streak & ~broke, shade=np.full(ctx.N, 2.6) + ctx.fbm(20.0, 2, seed + 6) * 1.0
               + _dither(ctx, 0.8, seed + 7))
    s.use_ramp(P["rust_run"], mask=broke, shade=np.full(ctx.N, 2.2) + ctx.fbm(16.0, 2, seed + 8) * 1.4
               + _dither(ctx, 1.0, seed + 9))
    s.metal = np.where(broke, 0.0, 0.15)
    s.rough = np.where(broke, 0.88, 0.62 + ctx.rand(seed + 10) * 0.06 + up * 0.1)
    s.height = ctx.fbm(14.0, 2, seed + 11) * 0.0002 - broke * 0.0004
    return s


def rivet_rows(ctx, s, mask, ramp="tank_paint", shade=6.2, seed=811):
    """Rivet heads where ``mask`` holds (the caller lays the rows out): a
    bright crown, a dark ring under it, a little height."""
    if not mask.any():
        return s
    s.use_ramp(P[ramp], mask=mask, shade=np.full(ctx.N, shade) + _dither(ctx, 0.8, seed))
    s.height = np.where(mask, s.height + 0.0012, s.height)
    return s


def dots(a, b, pitch, radius, a0=0.0):
    """A row of dots along coordinate ``a`` (pitch apart, phase a0) on the
    line b = 0: mask (head) and ring (just round it)."""
    k = np.round((a - a0) / pitch)
    d = np.hypot(a - a0 - k * pitch, b)
    return d < radius, (d >= radius) & (d < radius * 1.6)


def droppings(ctx, s, amount=1.0, seed=821):
    """White pigeon droppings on the upward faces, thicker near the rims."""
    up = ctx.n[:, 2] > 0.35
    spot = (ctx.rand(seed) > 1.0 - 0.012 * amount) | ((ctx.worley(26.0, seed + 1)[0] < 0.09)
                                                       & (ctx.fbm(1.5, 2, seed + 2) > 0.35 - 0.2 * amount))
    mask = up & spot
    s.use_ramp(P["dropping"], mask=mask, shade=np.full(ctx.N, 2.6) + _dither(ctx, 1.6, seed + 3))
    s.rough = np.where(mask, 0.95, s.rough)
    s.metal = np.where(mask, 0.0, s.metal)
    s.height = np.where(mask, s.height + 0.0006, s.height)
    return s


def galvanised(ctx, seed=831, center=4.6):
    """Dull zinc: spangle (big soft cells), white rust in hollows."""
    s = Surface(ctx.N)
    f1, f2, _ = ctx.worley(9.0, seed)
    spangle = ctx.fbm(9.0, 2, seed + 1)
    shade = center + spangle * 0.9 + ctx.fbm(2.0, 3, seed + 2) * 0.6 + _dither(ctx, 0.6, seed + 3)
    s.use_ramp(P["zinc"], shade=shade)
    _age(ctx, s, cavity=2.0, ao=3.0, edge=1.4)
    white = (ctx.cavity(3.0) > 0.3) & (ctx.fbm(8.0, 2, seed + 4) > 0.2)
    s.use_ramp(P["dropping"], mask=white, shade=np.full(ctx.N, 1.2) + _dither(ctx, 1.0, seed + 5))
    s.metal = np.where(white, 0.0, 0.7)
    s.rough = np.where(white, 0.9, 0.5 + ctx.rand(seed + 6) * 0.08)
    s.height = (f2 - f1) * 0.0001
    return s


def roof_steel(ctx, seed=841, center=2.8, rust=0.6):
    """The roof's dark painted steel (railings, stands, frames)."""
    s = Surface(ctx.N)
    shade = center + ctx.fbm(3.0, 3, seed) * 0.6 + _dither(ctx, 0.5, seed + 1)
    s.use_ramp(P["steel_paint"], shade=shade)
    _age(ctx, s, cavity=1.0, ao=1.6, edge=1.6)
    broke = (ctx.edge_soft(2.0) * 0.6 + ctx.cavity(3.0) * 0.6 + np.clip(ctx.fbm(9.0, 3, seed + 2), 0, 1) * 0.7) > 1.05 - 0.25 * rust
    s.use_ramp(P["rust_run"], mask=broke, shade=np.full(ctx.N, 2.4) + ctx.fbm(16.0, 2, seed + 3) * 1.2
               + _dither(ctx, 1.0, seed + 4))
    s.metal = np.where(broke, 0.0, 0.45)
    s.rough = np.where(broke, 0.85, 0.5 + ctx.rand(seed + 5) * 0.06)
    return s
