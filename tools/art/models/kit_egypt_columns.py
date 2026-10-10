"""Floor I, Egypt wing kit: papyrus columns, 64 px/m, origin = centre of the
base, 11 m from the floor to the top of the abacus (scale Y for other
ceilings: the Colossus Hall's 14 m).

  egypt_column            papyrus-bundle column with a closed bud capital
                          (the gallery's rhythm): a round base disc, eight
                          convex stems narrowing at the foot under painted
                          sheath leaves, five painted binding bands, the
                          lobed bud with green sepals, a square abacus.
                          Greybox size 2.1 x 11 x 2.1.
  egypt_column_open       campaniform column (Karnak hypostyle) for the
                          Colossus Hall: a smooth drum shaft carved and
                          painted with a king adoring the gods, cartouches
                          and columns of text, five bands, an open papyrus
                          umbel capital 3.1 m across under a small abacus.
                          Greybox size 3.1 x 11 x 3.1.
  *_cracked               texture sets of both (same meshes): the stone split
                          by the colossus's eye beam (first hit).
  egypt_column_stump,     the columns after the second hit: broken off at
  egypt_column_open_stump about 3.6 m with a fresh, jagged break.
  egypt_column_drums      rubble of a fallen column: two drums and three
                          chunks as separate parts (drum_a, drum_b, chunk_a,
                          chunk_b, chunk_c) to scatter or fling as debris.
"""
import math
import random

import numpy as np
from mathutils import Matrix, Vector

from artlib import egypt as E
from artlib import egypt_paint as EP
from artlib.archkit import kit
from artlib.geo import Part
from artlib.materials import P, _dither, smoothstep

TAU = math.tau
SEG = 48
LOBES = 8


def _lobe(i, j, segments=SEG):
    a = TAU * i / segments
    bump = abs(math.cos(LOBES / 2 * a)) ** 0.5
    return 0.9 + 0.1 * bump


def _base(p, r):
    p.lathe([(r - 0.04, 0.0), (r, 0.05), (r, 0.27), (r - 0.07, 0.35)], "sandstone", segments=32, cap_bottom=False)


def bundle_shaft(p, z_top=None):
    """Lobed shaft; ``z_top`` stops it early (the stump)."""
    prof = [(0.6, 0.35), (0.7, 0.55), (0.77, 0.95), (0.79, 1.8), (0.77, 3.5), (0.73, 5.5), (0.69, 6.9),
            (0.66, 7.4)]
    if z_top is not None:
        prof = [q for q in prof if q[1] < z_top] + [(0.765, z_top)]
    p.lathe(prof, "shaft", segments=SEG, cap_bottom=False, cap_top=False, ring_scale=_lobe, smooth=True)
    return prof


def bands(p, z0, r, slot="bands"):
    for k in range(5):
        a = z0 + k * 0.13
        p.lathe([(r, a), (r + 0.035, a + 0.015), (r + 0.035, a + 0.1), (r, a + 0.115)], slot, segments=32,
                cap_bottom=False, cap_top=False, smooth=True)


def column():
    p = Part("egypt_column")
    _base(p, 1.05)
    bundle_shaft(p)
    p.lathe([(0.66, 7.4), (0.66, 8.1)], "shaft", segments=SEG, cap_bottom=False, cap_top=False, ring_scale=_lobe)
    bands(p, 7.42, 0.66)
    p.lathe([(0.66, 8.1), (0.74, 8.45), (0.88, 8.9), (0.95, 9.35), (0.92, 9.8), (0.78, 10.15), (0.6, 10.38),
             (0.5, 10.45)], "capital", segments=SEG, cap_bottom=False, cap_top=True, ring_scale=_lobe)
    p.box((0.0, 0.0, 10.725), (1.25, 1.25, 0.55), "sandstone", bevel=0.02)
    return p


OPEN_R = 0.85
ZONE = (1.2, 6.6)


def open_shaft(p, z_top=None):
    prof = [(0.74, 0.35), (0.84, 0.6), (OPEN_R, 1.2), (OPEN_R, 3.9), (OPEN_R, ZONE[1]), (0.82, 7.4), (0.78, 8.0)]
    if z_top is not None:
        prof = [q for q in prof if q[1] < z_top] + [(OPEN_R, z_top)]
    p.lathe(prof, "drum", segments=SEG, cap_bottom=False, cap_top=False, smooth=True)


def column_open():
    p = Part("egypt_column_open")
    _base(p, 1.18)
    open_shaft(p)
    p.lathe([(0.78, 8.0), (0.78, 8.7)], "drum", segments=SEG, cap_bottom=False, cap_top=False)
    bands(p, 8.02, 0.78)
    p.lathe([(0.78, 8.7), (0.84, 9.0), (0.97, 9.45), (1.16, 9.9), (1.38, 10.25), (1.53, 10.45), (1.56, 10.52),
             (1.5, 10.58), (1.0, 10.62)], "bell", segments=SEG, cap_bottom=False, cap_top=True)
    p.box((0.0, 0.0, 10.81), (1.35, 1.35, 0.38), "sandstone", bevel=0.02)
    return p


def _jagged_top(p, r, z_break, seed, lobed=False):
    """A broken-off top: a ring of uneven heights, the break face falling to
    a hollow in the middle."""
    rng = random.Random(seed)
    n = 24
    lo = []
    hi = []
    for i in range(n):
        a = TAU * i / n
        rr = r * (_lobe(i * 2, 0) if lobed else 1.0)
        dz = 0.38 * math.sin(a + 0.7) + 0.13 * math.sin(3 * a + 2.1) + rng.uniform(-0.06, 0.06)
        lo.append(p.bm.verts.new((rr * math.cos(a), rr * math.sin(a), z_break - 0.7)))
        hi.append(p.bm.verts.new((rr * math.cos(a) * rng.uniform(0.94, 1.0), rr * math.sin(a) * rng.uniform(0.94, 1.0),
                                  z_break + dz)))
    for i in range(n):
        i2 = (i + 1) % n
        f = p._face([lo[i], lo[i2], hi[i2], hi[i]], "shaft" if lobed else "drum", smooth=False)
        f.normal_update()
        c = f.calc_center_median()
        if f.normal.x * c.x + f.normal.y * c.y < 0:
            f.normal_flip()
    mid = p.bm.verts.new((rng.uniform(-0.1, 0.1), rng.uniform(-0.1, 0.1), z_break - 0.25))
    for i in range(n):
        f = p._face([hi[i], hi[(i + 1) % n], mid], "break", smooth=False)
        f.normal_update()
        if f.normal.z < 0:
            f.normal_flip()


def stump(kind):
    if kind == "bundle":
        p = Part("egypt_column_stump")
        _base(p, 1.05)
        bundle_shaft(p, z_top=2.9)
        _jagged_top(p, 0.765, 3.6, 5, lobed=True)
    else:
        p = Part("egypt_column_open_stump")
        _base(p, 1.18)
        open_shaft(p, z_top=2.9)
        _jagged_top(p, OPEN_R, 3.6, 7)
    return p


def _rock(p, center, size, seed, slot="break"):
    """An irregular chunk: a box with its corners jittered."""
    rng = random.Random(seed)
    faces = p.box(center, size, slot, bevel=0.0)
    verts = {v for f in faces for v in f.verts}
    for v in sorted(verts, key=lambda v: tuple(round(c, 5) for c in v.co)):
        v.co += Vector((rng.uniform(-0.2, 0.2) * size[0], rng.uniform(-0.2, 0.2) * size[1],
                        rng.uniform(-0.15, 0.15) * size[2]))
    return faces


def drums():
    parts = []
    for name, c, ln, yaw, seed in (("drum_a", (-0.8, 0.3, OPEN_R), 1.3, 20.0, 3), ("drum_b", (1.1, -0.6, OPEN_R), 0.9, -55.0, 4)):
        d = Part(name, origin=c)
        faces = d.lathe([(OPEN_R, -ln / 2), (OPEN_R, ln / 2)], "drum", segments=SEG, cap_bottom=False, cap_top=False)
        rng = random.Random(seed)
        # broken ends: jittered caps
        for end in (-1, 1):
            ring = [d.bm.verts.new((OPEN_R * math.cos(TAU * i / 16) * 0.98, OPEN_R * math.sin(TAU * i / 16) * 0.98,
                                    end * (ln / 2 + rng.uniform(-0.08, 0.12)))) for i in range(16)]
            mid = d.bm.verts.new((0, 0, end * (ln / 2 - 0.1)))
            for i in range(16):
                f = d._face([ring[i], ring[(i + 1) % 16], mid], "break", smooth=False)
                f.normal_update()
                if f.normal.z * end < 0:
                    f.normal_flip()
        d.move(list(d.bm.faces), Matrix.Translation(Vector(c)) @ Matrix.Rotation(math.radians(yaw), 4, 'Z')
               @ Matrix.Rotation(math.radians(90), 4, 'Y'))
        parts.append(d)
    for name, c, s, seed in (("chunk_a", (0.3, 1.0, 0.25), (0.7, 0.5, 0.5), 11), ("chunk_b", (-1.5, -0.7, 0.18), (0.5, 0.45, 0.36), 12),
                             ("chunk_c", (0.0, -1.3, 0.14), (0.4, 0.3, 0.28), 13)):
        k = Part(name, origin=c)
        _rock(k, c, s, seed)
        parts.append(k)
    return parts


# --------------------------------------------------------------------------
# paint
# --------------------------------------------------------------------------

def _theta(ctx):
    return np.arctan2(ctx.p[:, 1], ctx.p[:, 0])


def shaft_paint(ctx, seed=41):
    """Bundle shaft: bare sandstone with ochre wash traces; painted sheath
    leaves round the foot of each stem."""
    s = E.sandstone(ctx, seed, center=6.1, strata=0.6)
    z = ctx.p[:, 2]
    th = _theta(ctx)
    la = np.mod(th * LOBES / TAU + 0.5, 1.0) - 0.5          # -0.5 .. 0.5 across a stem
    t = np.clip((z - 0.4) / 1.25, 0.0, 1.0)
    leaf = (z > 0.4) & (np.abs(la) < 0.46 * (1.0 - t)) & (z < 1.65)
    rim = leaf & (np.abs(la) > 0.46 * (1.0 - t) - 0.05)
    codes = np.where(leaf, np.where(rim, EP.INK["yellow"], EP.INK["green"]), 0).astype(np.int16)
    codes[(z > 0.35) & (z < 0.42)] = EP.INK["red"]
    rims = np.zeros(ctx.N, np.int16)
    return E.paint_over(ctx, s, codes, rims, seed + 1, flake=0.35)


def band_paint(ctx, seed=43):
    s = E.sandstone(ctx, seed, center=6.0, strata=0.2)
    z = ctx.p[:, 2]
    k = np.floor((z - 7.42 if z.mean() < 7.9 else z - 8.02) / 0.13 + 1e-6).astype(np.int64)
    cyc = np.array([EP.INK["blue"], EP.INK["red"], EP.INK["green"], EP.INK["red"], EP.INK["blue"]], np.int16)
    codes = cyc[np.clip(k, 0, 4)]
    fz = np.mod((z - 7.42), 0.13)
    codes = np.where((fz < ctx.texel) | (fz > 0.13 - ctx.texel), EP.INK["yellow"], codes).astype(np.int16)
    return E.paint_over(ctx, s, codes, np.zeros(ctx.N, np.int16), seed + 1, flake=0.3)


def bud_paint(ctx, seed=47):
    """Closed papyrus bud: green sepals round its base, a dark line up each
    stem, red tips at the crown."""
    s = E.sandstone(ctx, seed, center=6.2, strata=0.3)
    z = ctx.p[:, 2]
    th = _theta(ctx)
    la = np.mod(th * LOBES / TAU + 0.5, 1.0) - 0.5
    t = np.clip((z - 8.1) / 0.9, 0.0, 1.0)
    sepal = (z < 9.0) & (np.abs(la) < 0.48 * (1.0 - t))
    sepal2 = (z < 8.7) & (np.abs(np.mod(la + 1.0, 1.0) - 0.5) < 0.4 * (1.0 - np.clip((z - 8.1) / 0.6, 0, 1)))
    codes = np.zeros(ctx.N, np.int16)
    codes[sepal2] = EP.INK["blue"]
    codes[sepal] = EP.INK["green"]
    line = (z >= 9.0) & (np.abs(la) < 0.045)
    codes[line] = EP.INK["green"]
    codes[(z > 10.2)] = EP.INK["red"]
    return E.paint_over(ctx, s, codes, np.zeros(ctx.N, np.int16), seed + 1, flake=0.35)


_DRUM = {}


def _drum_canvas():
    """The carved register round the campaniform shaft (5.4 m around, 1.2 to
    6.6 m up): two scenes of the king adoring a seated god, columns of text
    between, a band of royal cartouches above."""
    if "c" in _DRUM:
        return _DRUM["c"]
    W = int(round(TAU * OPEN_R * 64))
    H = int(round((ZONE[1] - ZONE[0]) * 64))
    c = np.zeros((H, W), dtype=np.int16)
    bb = EP.block_border(W, 6)
    c[H - 6:H] = bb
    c[H - 120:H - 114] = bb
    c[0:6] = bb
    for k, head in enumerate(("falcon", "jackal")):
        x0 = k * W // 2
        EP.figure(c, x0 + 52, H - 126, 172, pose="adore", sex="m", seed=k, crown="khepresh" if k == 0 else "nemes")
        EP.figure(c, x0 + 128, H - 126, 160, pose="seated", head=head, flip=True, seed=k + 1)
        cols = EP.text_columns(2, 4, 31 + k, col_w=12, cell=10, gap=1)
        c[10:10 + cols.shape[0], x0 + 72:x0 + 72 + cols.shape[1]] = np.where(
            cols > 0, cols, c[10:10 + cols.shape[0], x0 + 72:x0 + 72 + cols.shape[1]])
        cols = EP.text_columns(1, 16, 41 + k, col_w=12, cell=10, gap=1)
        c[10:10 + cols.shape[0], x0 + 153:x0 + 153 + cols.shape[1]] = np.where(
            cols > 0, cols, c[10:10 + cols.shape[0], x0 + 153:x0 + 153 + cols.shape[1]])
    # upper band: cartouches between columns of text
    import random
    rng = random.Random(5)
    x = 4
    while x + 22 < W:
        if (x // 22) % 3 == 1:
            cart = EP.cartouche(rng, 18, 98)
            c[H - 112:H - 112 + 98, x:x + 18] = np.where(cart > 0, cart, c[H - 112:H - 112 + 98, x:x + 18])
        else:
            cols = EP.text_columns(1, 8, 70 + x, col_w=18, cell=10, gap=2, divider=False)
            c[H - 112:H - 112 + cols.shape[0], x:x + 18] = np.where(cols > 0, cols, c[H - 112:H - 112 + cols.shape[0], x:x + 18])
        x += 22
    _DRUM["c"] = c
    return c


def drum_paint(ctx, seed=53):
    s = E.sandstone(ctx, seed, center=6.1, strata=0.6)
    z = ctx.p[:, 2]
    zone = (z > ZONE[0]) & (z < ZONE[1]) & (np.hypot(ctx.p[:, 0], ctx.p[:, 1]) > OPEN_R - 0.02)
    if zone.any():
        codes, rims = E.sample(_drum_canvas(), ctx.uvm[:, 0], z - ZONE[0], ctx.texel, wrap_x=True)
        codes = np.where(zone, codes, -1).astype(np.int16)
        s = E.paint_over(ctx, s, codes, rims, seed + 1, flake=0.45, relief=-0.003)
    foot = (z > 0.35) & (z < 0.6)
    s.shade[foot] -= 0.4
    return s


def bell_paint(ctx, seed=59):
    """Open papyrus umbel: sepals at the foot, then stems fanning up to blue
    and green umbel heads under the rim."""
    s = E.sandstone(ctx, seed, center=6.3, strata=0.3)
    z = ctx.p[:, 2]
    th = _theta(ctx)
    n = 16
    la = np.mod(th * n / TAU + 0.5, 1.0) - 0.5
    cell = np.floor(th * n / TAU + 0.5).astype(np.int64)
    codes = np.zeros(ctx.N, np.int16)
    t = np.clip((z - 8.7) / 0.7, 0.0, 1.0)
    codes[(z < 9.4) & (np.abs(la) < 0.47 * (1.0 - t))] = EP.INK["green"]
    stem = (z >= 9.2) & (z < 10.05) & (np.abs(la) < 0.06)
    codes[stem] = EP.INK["green"]
    head = (z >= 10.0) & (z < 10.5) & (np.abs(la) < 0.12 + (z - 10.0) * 0.7)
    codes[head] = np.where(np.mod(cell, 2) == 0, EP.INK["blue"], EP.INK["green"])[head]
    codes[(z >= 10.44)] = EP.INK["red"]
    return E.paint_over(ctx, s, codes, np.zeros(ctx.N, np.int16), seed + 1, flake=0.35)


def broken(ctx, seed=61):
    """A fresh break: paler, coarser sandstone, no patina."""
    s = E.sandstone(ctx, seed, center=7.2, strata=0.8)
    s.height = s.height + ctx.fbm(8.0, 3, seed + 1) * 0.004
    s.rough = np.full(ctx.N, 0.95)
    return s


def cracked(fn, seed=67):
    """The same paint split by the beam: jagged dark cracks with chipped
    lips, a few spalls of fresh stone."""
    def f(ctx):
        s = fn(ctx)
        q = ctx.p * np.array([1.0, 1.0, 0.45])
        c1 = np.abs(ctx.fbm(0.9, 4, seed, p=q)) < 0.018
        c2 = np.abs(ctx.fbm(2.2, 3, seed + 1, p=q)) < 0.012
        crack = c1 | (c2 & (ctx.fbm(0.8, 2, seed + 2) > 0.0))
        lip = (np.abs(ctx.fbm(0.9, 4, seed, p=q)) < 0.04) & ~crack
        spall = (ctx.fbm(1.6, 3, seed + 3) > 0.42)
        s.shade[lip] -= 1.0
        sub = broken(ctx)
        s.merge(E._select(sub, spall), spall)
        s.shade[crack] = 0.0
        s.height = s.height - crack * 0.006 - spall * 0.003
        return s
    return f


def build():
    sand = lambda c: E.sandstone(c, 71, center=6.0)  # noqa: E731
    fns = {"sandstone": sand, "shaft": shaft_paint, "bands": band_paint, "capital": bud_paint, "break": broken}
    fns_open = {"sandstone": sand, "drum": drum_paint, "bands": band_paint, "bell": bell_paint, "break": broken}
    crk = {k: cracked(v) for k, v in fns.items()}
    crk_open = {k: cracked(v) for k, v in fns_open.items()}
    return [
        kit("egypt_column", [column()], fns, ao_dist=0.6, variants={"egypt_column_cracked": crk},
            preview_extra=[("capital", (0.0, 0.0, 9.4), 1.6, 20.0, 10.0)]),
        kit("egypt_column_open", [column_open()], fns_open, ao_dist=0.6,
            variants={"egypt_column_open_cracked": crk_open},
            preview_extra=[("drum", (0.0, 0.0, 3.9), 2.4, 0.0, 5.0), ("bell", (0.0, 0.0, 9.9), 1.9, 30.0, -8.0)]),
        kit("egypt_column_stump", [stump("bundle")], fns, ao_dist=0.6),
        kit("egypt_column_open_stump", [stump("open")], fns_open, ao_dist=0.6),
        kit("egypt_column_drums", drums(), {"drum": sand, "break": broken}, ao_dist=0.5),
    ]
