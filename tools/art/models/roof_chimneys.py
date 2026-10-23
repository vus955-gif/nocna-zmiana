"""Floor I's roof: the chimney stacks (the plant deck's boiler flue and the
catwalks' corner stacks).

  roof_chimney_tall   the boiler flue on the plant deck: a brick stack on a
                      plinth with a stone weathering, an oversailing
                      corbelled cap, a stone coping, cement flaunching and
                      two tall buff pots blackened by smoke; a lead apron
                      at its foot, the lightning conductor's copper tape
                      down its north face with its clips, an iron strap
                      round the shaft. 1.2 x 4.5 x 1.2 m (Godot x, y, z).
  roof_chimney_short  a squat corner stack of the old fireplaces: the same
                      courses, four pots in a row-of-two square, one of them
                      broken and one capped with a cowl. 1.5 x 3 x 1.5 m.

Both stand in their greybox boxes (the box is their collision). Brick from
the kit's English bond (arch_materials.brick) with soot and lime bloom over
it, 96 px/m. Kit convention: origin = the middle of the footprint on the
deck; built front +Y in Blender (= Godot -Z).
"""
import math

import numpy as np
from mathutils import Matrix

from artlib import arch_materials as AM
from artlib import asy
from artlib import court_materials as CM
from artlib import kit as K
from artlib import materials as M
from artlib import roof_materials as RM
from artlib.archkit import kit
from artlib.geo import Part
from artlib.materials import P, _dither, smoothstep

SQ = math.sqrt(2.0)


def _square(p, prof, mat, cap_top=False):
    """A square stack (axis-aligned) from a profile of (half side, z)."""
    return p.lathe([(h * SQ, z) for h, z in prof], mat, segments=4, phase=math.pi / 4, smooth=False,
                   cap_bottom=False, cap_top=cap_top)


def stack(p, half, height, cap_z):
    """Plinth, weathering, shaft, three oversailing courses, coping slab:
    ``half`` = half the footprint (the lead apron's), the coping's top at
    ``cap_z``. Returns the shaft's and the plinth's half sides."""
    plinth = half - 0.02
    shaft = half - 0.075
    course = 0.075
    top = cap_z - 0.09 - 3 * course
    prof = [(plinth, 0.0), (plinth, 0.32), (shaft + 0.01, 0.4), (shaft, 0.41), (shaft, top)]
    for k in range(3):
        h = shaft + 0.018 * (k + 1)
        prof += [(h, top + course * k), (h, top + course * (k + 1))]
    prof += [(shaft + 0.03, top + 3 * course)]
    _square(p, prof, "brick")
    # the coping: a stone slab weathered to the edges
    _square(p, [(half - 0.03, cap_z - 0.09), (half - 0.01, cap_z - 0.09), (half - 0.01, cap_z - 0.04),
                (half - 0.06, cap_z), (0.0, cap_z)], "coping")
    # the lead apron at the foot (the roof's flashing turned up)
    _square(p, [(half, 0.0), (half, 0.16), (plinth + 0.002, 0.17)], "lead")
    return shaft, plinth, top


def pot(p, x, y, z, height=0.62, r=0.13, broken=False, cowl=False):
    """A buff clay chimney pot standing in the flaunching: a flared foot,
    a tapering body, a rolled rim, black inside."""
    prof = [(r + 0.035, 0.0), (r + 0.01, 0.06), (r, 0.12), (r - 0.03, height - 0.08)]
    if broken:
        prof += [(r - 0.032, height - 0.2)]
    else:
        prof += [(r - 0.015, height - 0.05), (r - 0.005, height - 0.02), (r - 0.02, height)]
    f = p.lathe(prof, "pot", segments=10, cap_bottom=False, cap_top=False, center=(x, y, z))
    top = prof[-1]
    # its mouth: a dark throat a little way down
    throat = p.lathe([(top[0] - 0.012, top[1] - 0.005), (top[0] - 0.025, top[1] - 0.12), (0.0, top[1] - 0.12)], "soot",
                     segments=10, cap_bottom=False, cap_top=False, center=(x, y, z))
    for face in throat:   # seen from inside
        face.normal_flip()
    if cowl:
        zc = z + top[1]
        K.seg(p, (x, y, zc - 0.02), (x, y, zc + 0.1), [(top[0] - 0.01, 0.0), (top[0] - 0.01, 1.0)], "cowl", segments=10,
              caps=False)
        p.lathe([(top[0] + 0.04, zc + 0.12), (top[0] + 0.04, zc + 0.15), (0.06, zc + 0.24), (0.0, zc + 0.26)], "cowl",
                segments=10, center=(x, y, 0.0), cap_bottom=True)
        for k in range(3):
            a = math.tau * k / 3
            p.box((x + math.cos(a) * (top[0] + 0.01), y + math.sin(a) * (top[0] + 0.01), zc + 0.12), (0.02, 0.02, 0.06),
                  "cowl")
    return f


def flaunching(p, cx, cy, w, d, z):
    """Cement bedding round the pots: a low hipped mound on the coping."""
    pts = [(cx - w / 2, cy - d / 2), (cx + w / 2, cy - d / 2), (cx + w / 2, cy + d / 2), (cx - w / 2, cy + d / 2)]
    k = 0.12
    inner = [(cx - w / 2 + k, cy - d / 2 + k), (cx + w / 2 - k, cy - d / 2 + k), (cx + w / 2 - k, cy + d / 2 - k),
             (cx - w / 2 + k, cy + d / 2 - k)]
    lo = [p.bm.verts.new((x, y, z)) for x, y in pts]
    hi = [p.bm.verts.new((x, y, z + 0.09)) for x, y in inner]
    for i in range(4):
        j = (i + 1) % 4
        f = p._face([lo[i], lo[j], hi[j], hi[i]], "flaunch")
        f.normal_update()
        if f.normal.z < 0:
            f.normal_flip()
    f = p._face(hi, "flaunch")
    f.normal_update()
    if f.normal.z < 0:
        f.normal_flip()


def conductor(p, half, height, cap_z, shaft, plinth, top):
    """The copper tape down the front face (+Y), clipped every metre, over
    the corbels and the coping to its air rod, down the plinth to the lead."""
    x = half * 0.45
    y = shaft + 0.003
    p.box((x, y, (0.4 + top) / 2), (0.026, 0.006, top - 0.4), "copper")
    z = 0.8
    while z < top - 0.3:
        p.box((x, y + 0.004, z), (0.05, 0.008, 0.02), "copper")
        z += 1.0
    yc = shaft + 0.054 + 0.004
    p.box((x, yc, (top + cap_z) / 2), (0.026, 0.006, cap_z - top + 0.04), "copper")
    K.seg(p, (x, half - 0.06, cap_z - 0.02), (x, half - 0.06, height - 0.02), [(0.008, 0.0), (0.008, 0.85), (0.0, 1.0)],
          "copper", segments=5)
    p.box((x, plinth + 0.003, 0.28), (0.026, 0.006, 0.24), "copper")
    p.box((x, (shaft + plinth) / 2 + 0.005, 0.405), (0.026, plinth - shaft, 0.006), "copper")


def tall():
    p = Part("roof_chimney_tall")
    half, H = 0.6, 4.5
    cap = TALL_CAP
    shaft, plinth, top = stack(p, half, H, cap)
    # an iron strap round the shaft (the stack once cracked) with its bolt plates
    _square(p, [(shaft + 0.012, 2.2), (shaft + 0.012, 2.27)], "iron")
    for sx in (-1, 1):
        p.box((sx * (shaft + 0.02), 0.0, 2.235), (0.025, 0.12, 0.12), "iron")
    flaunching(p, 0.0, 0.0, 0.94, 0.62, cap)
    for x in (-0.22, 0.22):
        pot(p, x, 0.0, cap + 0.04, height=H - cap - 0.04 - 0.0, r=0.14)
    conductor(p, half, H, cap, shaft, plinth, top)
    return p


def short():
    p = Part("roof_chimney_short")
    half, H = 0.75, 3.0
    cap = SHORT_CAP
    shaft, plinth, top = stack(p, half, H, cap)
    flaunching(p, 0.0, 0.0, 1.12, 1.12, cap)
    spots = [(-0.26, -0.26), (0.26, -0.26), (-0.26, 0.26), (0.26, 0.26)]
    for k, (x, y) in enumerate(spots):
        hpot = H - cap - 0.04 - (0.27 if k == 3 else 0.0)
        pot(p, x, y, cap + 0.04, height=hpot if k != 1 else hpot - 0.12, r=0.13, broken=k == 1, cowl=k == 3)
    conductor(p, half, H - 0.08, cap, shaft, plinth, top)
    return p


# --------------------------------------------------------------------------
# paint
# --------------------------------------------------------------------------

def brick(ctx, top):
    """Stock brick in English bond (the kit's bond, without its plaster
    patches), blackened toward the top where the smoke rolls over the cap
    and streaked down from it, spalled bricks, lime bloom washed out of the
    joints."""
    from artlib import noise
    u, v = ctx.uvm[:, 0], ctx.uvm[:, 1]
    tx = ctx.texel
    ch = 1.0 / 13.0
    row = np.floor(np.mod(v, 2.0) / ch + 1e-9).astype(np.int64)
    header = (row % 2) == 1
    blen = np.where(header, 0.11, 0.225)
    shift = np.where(header, 0.055, 0.0) + np.where((row % 4) == 2, 0.11, 0.0)
    xu = np.mod(u + shift, 3.6)
    col = np.floor(xu / blen + 1e-9).astype(np.int64)
    fx = xu - col * blen
    fz = np.mod(v, 2.0) - row * ch
    bid = row * 64 + col + np.floor(v / 2.0).astype(np.int64) * 4096
    mortar = (fx < tx * 1.2) | (fz < tx * 1.2)
    s = M.Surface(ctx.N)
    tone = noise.rand_cells(bid, 1011) - 0.5
    burnt = noise.rand_cells(bid, 1012) > 0.85
    spall = (noise.rand_cells(bid, 1013) > 0.93) & ~mortar
    z = ctx.p[:, 2]
    streak = ctx.fbm(np.array([7.0, 7.0, 0.8]), 2, 1014) * 0.5 + 0.5
    soot = smoothstep(top - 1.7, top - 0.1, z + streak * 0.7) * 3.4
    shade = 4.4 + tone * 2.2 + ctx.fbm(3.0, 3, 1015) * 0.7 + _dither(ctx, 0.9, 1016) - burnt * 2.0 - spall * 1.4
    shade -= soot + (1.0 - ctx.ao) * 2.5
    s.use_ramp(P["brick"], shade=shade)
    s.use_ramp(P["mortar"], mask=mortar, shade=np.full(ctx.N, 3.4) - soot * 0.8 + _dither(ctx, 1.0, 1017))
    bloom = (ctx.fbm(np.array([5.0, 5.0, 1.2]), 3, 1018) > 0.42) & (z < top - 0.3) & (np.abs(ctx.n[:, 2]) < 0.5)         & (ctx.rand(1019) > 0.4)
    s.use_ramp(P["plaster"], mask=bloom, shade=np.full(ctx.N, 2.6) + _dither(ctx, 1.2, 1020))
    s.height = np.where(mortar, -0.004, 0.0) - spall * 0.004 + ctx.fbm(20.0, 2, 1021) * 0.0006
    s.rough = np.where(bloom, 0.92, 0.86) + ctx.rand(1022) * 0.05
    return s


def coping(ctx):
    s = CM.portland(ctx, 1021, center=5.0)
    s.shade -= smoothstep(0.2, 0.7, ctx.fbm(3.0, 3, 1023)) * 1.8 + 0.6
    return s


def pot_paint(ctx, base, height):
    """Buff fireclay, its upper half blackened, soot running down it (the
    pots stand on ``base``, ``height`` tall)."""
    s = asy.clay(ctx, 1031, center=6.4, writing=False)
    z = ctx.p[:, 2]
    t = (z - base) / height
    runs = ctx.fbm(np.array([24.0, 24.0, 1.5]), 2, 1033) * 0.5 + 0.5
    black = t + runs * 0.45 > 0.95
    s.use_ramp(P["iron"], mask=black, shade=np.full(ctx.N, 1.6) + ctx.fbm(9.0, 2, 1035) * 1.0 + _dither(ctx, 0.8, 1037))
    s.shade = np.where(black, s.shade, s.shade - smoothstep(0.3, 0.95, t + runs * 0.45) * 1.6)
    return s


def soot(ctx):
    s = M.Surface(ctx.N)
    s.use_ramp(P["iron"], shade=np.full(ctx.N, 0.6) + _dither(ctx, 0.8, 1041))
    s.rough = np.full(ctx.N, 0.95)
    return s


def flaunch(ctx):
    s = M.Surface(ctx.N)
    s.use_ramp(P["mortar"], shade=3.2 + ctx.fbm(8.0, 3, 1051) * 0.9 + _dither(ctx, 0.8, 1053) - (1.0 - ctx.ao) * 3.0)
    crack = np.abs(ctx.fbm(6.0, 2, 1055)) < 0.03
    s.shade -= crack * 2.0
    s.rough = np.full(ctx.N, 0.93)
    RM.droppings(ctx, s, amount=1.2, seed=1057)
    return s


def copper(ctx):
    """Copper tape weathered dark brown, green bloom in streaks."""
    s = M.Surface(ctx.N)
    s.use_ramp(P["copper"], shade=1.2 + ctx.fbm(6.0, 2, 1061) * 0.8 + _dither(ctx, 0.6, 1062) + ctx.edge(1.0) * 1.0)
    green = ctx.fbm(np.array([8.0, 8.0, 2.0]), 2, 1063) > 0.1
    s.use_ramp(P["formline_teal"], mask=green, shade=np.full(ctx.N, 2.2) + _dither(ctx, 0.8, 1065))
    s.metal = np.where(green, 0.0, 0.6)
    s.rough = np.full(ctx.N, 0.6)
    return s


def fns(cap):
    """The chimney's paints for a coping at ``cap`` (the soot is laid from
    the top of the brick, the pots' from their foot on the flaunching)."""
    return {
        "brick": lambda c: brick(c, cap - 0.09), "coping": coping, "lead": lambda c: CM.lead(c, 1071),
        "pot": lambda c: pot_paint(c, cap + 0.04, 0.6), "soot": soot, "flaunch": flaunch, "copper": copper,
        "iron": lambda c: M.iron(c, 1073), "cowl": lambda c: CM.cast_iron(c, 1075, center=3.2),
    }


TALL_CAP = 3.84
SHORT_CAP = 2.36


def build():
    kw = dict(ppm=96, built_final=True, ground=0.0, ao_dist=0.3, ao_rays=10, ao_stride=2,
              preview_yaws=(-35.0, 35.0, 145.0, 215.0), preview_elevation=14.0)
    return [kit("roof_chimney_tall", [tall()], fns(TALL_CAP), **kw),
            kit("roof_chimney_short", [short()], fns(SHORT_CAP), **kw)]
