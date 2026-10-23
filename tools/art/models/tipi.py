"""Floor I, the North America hall: a Plains tipi (a generic museum
stylisation; no particular family's or nation's painted design copied:
plain geometric bands). A cover of smoked hide on a ring of lodgepoles,
tilted back a little as tipis are (the door side longer), the poles
crossing at the smoke hole and fanning out above it, two smoke flaps held
open by their own poles, wooden lacing pins up the front seam over the oval
door, the door's hide cover rolled half up, pegs round the foot. The paint:
a red earth band round the foot with a row of pale discs, a band of
mountains (triangles) over it, a red disc ringed in yellow on the back, a
dark sky band round the top with pale stars; the hide smoked darker toward
the smoke hole.

Kit convention: origin = the middle of the footprint on the floor, the door
to the front (built +Y in Blender = Godot -Z).
  tipi   4.2 x 5.45 x 4.2 m (Godot x, y, z), the greybox tipi box 4.2 x 5.5
         x 4.2. 128 px/m.
"""
import math

import numpy as np
from mathutils import Vector

from artlib import americas as AM
from artlib import kit as K
from artlib import materials as M
from artlib.archkit import kit
from artlib.geo import Part
from artlib.materials import P, _dither, hexramp, smoothstep

P.update({
    "tipi_hide": hexramp("#2b2219", "#3d3124", "#504130", "#64523d", "#78644b", "#8c775b", "#a08a6c", "#b39d7e",
                         "#c4af91", "#d3c1a4"),
})

R0 = 2.0            # the cover's radius at its foot
R_TOP = 0.24        # ... at the smoke hole
H_TOP = 4.55        # the smoke hole's rim
FOOT = 0.06         # the cover's lower edge over the floor (pegged)
TILT = 0.22         # the smoke hole sits this far back of the foot's middle
TIE = 4.35          # where the poles cross and are tied
POLE_TOP = 5.44
POLES = 11
SEG = 32            # round the cover
ROWS = 9            # up the cover
DOOR = (0.0, 0.7, 0.42, 0.6)    # (angle, middle height, half width, half height) of the oval door


def centre(h):
    return Vector((0.0, -TILT * h / H_TOP))


def radius(h):
    return R0 + (R_TOP - R0) * h / H_TOP


def on_cover(phi, h, lift=0.0):
    """The cover's point at angle phi (0 = the door, +x clockwise seen from
    above) and height h, ``lift`` out of it."""
    c = centre(h)
    r = radius(h) + lift
    return Vector((c.x + r * math.sin(phi), c.y + r * math.cos(phi), h))


def cover(p):
    hs = [FOOT + (H_TOP - FOOT) * j / (ROWS - 1) for j in range(ROWS)]
    verts = [[p.bm.verts.new(tuple(on_cover(2 * math.pi * i / SEG, h))) for i in range(SEG)] for h in hs]
    # unrolled sector UVs (exact for a right cone; the tilt is small), the
    # cover cut in four panels so the islands pack
    apex_h = H_TOP + R_TOP * H_TOP / (R0 - R_TOP)
    slant0 = math.hypot(R0, apex_h)
    for j in range(ROWS - 1):
        for i in range(SEG):
            i2 = (i + 1) % SEG
            quad = [(verts[j][i], j, i), (verts[j][i2], j, i + 1), (verts[j + 1][i2], j + 1, i + 1),
                    (verts[j + 1][i], j + 1, i)]
            f = p._face([q[0] for q in quad], "hide", smooth=True)
            f.normal_update()
            mid = f.calc_center_median()
            c = centre(mid.z)
            if f.normal.dot(Vector((mid.x - c.x, mid.y - c.y, 0.0))) < 0:
                f.normal_flip()
            panel = i // (SEG // 4)
            phi_mid = 2 * math.pi * (panel + 0.5) / 4
            for loop in f.loops:
                q = next(x for x in quad if x[0] == loop.vert)
                h = hs[q[1]]
                phi = 2 * math.pi * q[2] / SEG
                d = math.hypot(radius(h), apex_h - h)
                th = (phi - phi_mid) * R0 / slant0
                loop[p.uv].uv = (d * math.sin(th), -d * math.cos(th))
            f[p.lock] = 1
    # the door: a dark oval just proud of the hide, its cover rolled half up
    a, hm, hw, hh = DOOR
    ring = []
    for k in range(14):
        t = 2 * math.pi * k / 14
        h = hm + hh * math.sin(t)
        phi = a + hw * math.cos(t) / radius(h)
        ring.append(tuple(on_cover(phi, h, 0.012)))
    f = p.poly(ring, "door")[0]
    f.normal_update()
    if f.normal.y < 0:
        f.normal_flip()
    roll = [tuple(on_cover(a + u * 0.5 / radius(hm + hh + 0.06), hm + hh + 0.06, 0.06)) for u in (-1.0, -0.4, 0.4, 1.0)]
    p.tube(roll, 0.06, "hide", sides=8)
    # lacing pins up the front seam, from over the door to the smoke flaps
    for k in range(9):
        h = 1.45 + k * 0.28
        c = on_cover(0.0, h, 0.0)
        out = Vector((c.x - centre(h).x, c.y - centre(h).y, 0.0)).normalized()
        across = Vector((1.0, 0.0, 0.0))
        K.seg(p, tuple(c + out * 0.02 - across * 0.09), tuple(c + out * 0.02 + across * 0.09),
              [(0.011, 0.0), (0.011, 0.9), (0.0, 1.0)], "pin", segments=5)
    # pegs round the foot
    for k in range(14):
        phi = 2 * math.pi * (k + 0.5) / 14
        if abs(math.remainder(phi - a, 2 * math.pi)) < 0.35:
            continue
        foot = on_cover(phi, FOOT + 0.02, 0.05)
        out = Vector((foot.x - centre(0.0).x, foot.y - centre(0.0).y, 0.0)).normalized()
        K.seg(p, (foot.x, foot.y, 0.012), tuple(foot + out * 0.03 + Vector((0, 0, 0.1))),
              [(0.022, 0.0), (0.02, 0.8), (0.026, 1.0)], "pin", segments=5)


def poles(p):
    tie = Vector((centre(TIE).x, centre(TIE).y, TIE))
    for k in range(POLES):
        phi = 2 * math.pi * (k + 0.3) / POLES
        base = on_cover(phi, 0.0, -0.06)
        d = (tie - base).normalized()
        # from inside the cover near its rim, through the tie, fanning out
        a = base + d * ((H_TOP - 0.25) / d.z)
        b = base + d * ((POLE_TOP - 0.02 * (k % 3)) / d.z)
        K.seg(p, tuple(a), tuple(b), [(0.045, 0.0), (0.04, 0.5), (0.028, 1.0)], "pole", segments=6, caps=True)
    # the rope binding at the tie
    band = p.lathe([(0.2, -0.06), (0.22, 0.0), (0.2, 0.06)], "rope", segments=10, cap_bottom=False, cap_top=False)
    p.move(band, K.T(tie.x, tie.y, tie.z))


def flaps(p):
    """Two smoke flaps either side of the front seam, opened out on their
    poles, which run down behind the tipi to the ground."""
    for sx in (-1, 1):
        lo, hi = 3.25, H_TOP + 0.02
        root_lo = on_cover(sx * 0.16, lo, 0.01)
        root_hi = on_cover(sx * 0.22, hi, 0.01)
        out = Vector((sx * 0.75, 0.55, 0.12)).normalized()
        tip_hi = root_hi + out * 0.62 + Vector((0.0, 0.0, 0.18))
        tip_lo = root_lo + out * 0.5
        f = p.poly([tuple(root_lo), tuple(tip_lo), tuple(tip_hi), tuple(root_hi)], "flap")[0]
        f.normal_update()
        if f.normal.y < 0:
            f.normal_flip()
        g = p.poly([tuple(root_lo), tuple(root_hi), tuple(tip_hi), tuple(tip_lo)], "flap_in")[0]
        g.normal_update()
        if g.normal.y > 0:
            g.normal_flip()
        # its pole: from the flap's top corner, behind the cover, to the ground at the back
        foot = on_cover(math.pi - sx * 0.45, 0.035, 0.25)
        top = tip_hi + Vector((0.0, 0.0, 0.12))
        K.seg(p, tuple(foot), tuple(top), [(0.04, 0.0), (0.03, 1.0)], "pole", segments=6)


def tipi():
    p = Part("tipi")
    cover(p)
    poles(p)
    flaps(p)
    return p


# --------------------------------------------------------------------------
# paint
# --------------------------------------------------------------------------

def _polar(ctx):
    x, y, h = ctx.p[:, 0], ctx.p[:, 1], ctx.p[:, 2]
    cy = -TILT * h / H_TOP
    phi = np.arctan2(x, y - cy)
    r = R0 + (R_TOP - R0) * np.clip(h, 0, H_TOP) / H_TOP
    return phi, h, phi * r     # angle, height, arc length round the cover at that height


def hide(ctx):
    """Smoked hide: cream, sewn from skins (faint seams), darker with smoke
    toward the top, the painted bands."""
    phi, h, arc = _polar(ctx)
    s = M.Surface(ctx.N)
    seams = np.abs(np.mod(phi * 5.0 / math.pi + 0.5, 1.0) - 0.5) < 0.015
    shade = 6.6 + ctx.fbm(1.6, 3, 7011) * 1.0 + ctx.fbm(9.0, 2, 7013) * 0.4 + _dither(ctx, 0.5, 7015)
    shade -= smoothstep(2.4, 4.5, h) * 2.6 + seams * 0.8 + (1.0 - ctx.ao) * 3.0
    shade -= smoothstep(0.5, 0.0, h) * 1.0
    s.use_ramp(P["tipi_hide"], shade=shade)
    f = h / H_TOP
    front = np.abs(phi) < 0.42                  # the door and the laced seam: unpainted
    # the earth band round the foot with pale discs
    earth = (f < 0.13) & ~((np.abs(phi) < 0.3) & (h > 0.1))
    s.use_ramp(P["am_red"], mask=earth, shade=np.full(ctx.N, 3.6) + ctx.fbm(6.0, 2, 7017) * 0.6 + _dither(ctx, 0.5, 7019))
    k = np.round(arc / 0.62)
    d = np.hypot(arc - k * 0.62, h - 0.36)
    disc = earth & (d < 0.15)
    s.use_ramp(P["tipi_hide"], mask=disc, shade=np.full(ctx.N, 7.0) + _dither(ctx, 0.5, 7021))
    line = (np.abs(f - 0.145) < 0.008) & ~front
    s.use_ramp(P["am_ochre"], mask=line, shade=np.full(ctx.N, 5.0))
    # mountains: a band of triangles, blue and red in turn
    band = (f > 0.16) & (f < 0.27) & ~front
    tri_w = 0.8
    k = np.floor(arc / tri_w)
    u = arc / tri_w - k
    tri_h = (0.27 - 0.16) * H_TOP * (1.0 - np.abs(u - 0.5) * 2.0)
    peak = band & ((h - 0.16 * H_TOP) < tri_h)
    blue = peak & (np.mod(k, 2) == 0)
    red = peak & ~blue
    s.use_ramp(P["am_blue"], mask=blue, shade=np.full(ctx.N, 3.6) + _dither(ctx, 0.5, 7023))
    s.use_ramp(P["am_red"], mask=red, shade=np.full(ctx.N, 4.4) + _dither(ctx, 0.5, 7025))
    # the disc on the back
    back = np.abs(np.abs(phi) - math.pi) < 0.9
    r = R0 + (R_TOP - R0) * np.clip(h, 0, H_TOP) / H_TOP
    dd = np.hypot((math.pi - np.abs(phi)) * r, h - 2.35)
    ring = back & (dd < 0.55) & (dd > 0.4)
    sun = back & (dd <= 0.4)
    s.use_ramp(P["am_ochre"], mask=ring, shade=np.full(ctx.N, 5.6) + _dither(ctx, 0.5, 7027))
    s.use_ramp(P["am_red"], mask=sun, shade=np.full(ctx.N, 4.8) + _dither(ctx, 0.5, 7029))
    # the sky band round the top with pale stars
    sky = (f > 0.74) & (h < H_TOP)
    s.use_ramp(P["am_obsidian"], mask=sky, shade=np.full(ctx.N, 3.0) + ctx.fbm(5.0, 2, 7031) * 0.6 + _dither(ctx, 0.5, 7033))
    k = np.round(arc / 0.34)
    rnd = np.mod(np.sin(k * 12.9898) * 43758.5453, 1.0)
    star = sky & (np.hypot(arc - k * 0.34, h - (0.8 + 0.12 * rnd) * H_TOP) < 0.045)
    s.use_ramp(P["tipi_hide"], mask=star, shade=np.full(ctx.N, 7.5))
    painted = earth | peak | ring | sun | sky | line
    s.rough = np.where(painted, 0.82, 0.9)
    return s


def flap(ctx):
    s = hide(ctx)
    return s


def flap_in(ctx):
    s = M.Surface(ctx.N)
    s.use_ramp(P["tipi_hide"], shade=np.full(ctx.N, 2.4) + ctx.fbm(4.0, 2, 7041) * 0.8 + _dither(ctx, 0.5, 7043))
    s.rough = np.full(ctx.N, 0.95)
    return s


def door(ctx):
    s = M.Surface(ctx.N)
    s.use_ramp(P["tipi_hide"], shade=np.full(ctx.N, 0.3) + _dither(ctx, 0.4, 7051))
    s.rough = np.full(ctx.N, 1.0)
    return s


FNS = {
    "hide": hide, "flap": flap, "flap_in": flap_in, "door": door,
    "pole": lambda c: AM.carved_wood(c, 7061, "am_wood", 5.6, adze=0.0, oiled=0.0),
    "pin": lambda c: AM.carved_wood(c, 7063, "am_wood", 5.0, adze=0.6),
    "rope": lambda c: M.leather(c, 7065),
}


def build():
    return kit("tipi", [tipi()], FNS, ppm=128, built_final=True, ground=0.0, ao_dist=0.5, ao_rays=10, ao_stride=2)
