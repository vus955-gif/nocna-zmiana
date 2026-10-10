"""The Japanese garden (Floor I, Asia wing): rocks in raked gravel, stone
lanterns, the arched bridge and the pond.

  garden_rock_a..d   four rock settings: a tall standing stone (1.7 m), a
                     long reclining stone, a mossy rounded boulder, a group
                     of three; each sits in a disc of gravel raked in rings
                     round it (the disc fades into the gravel field: lay
                     them on gravel_raked). Origin = the centre of the
                     setting on the floor.
  toro_kasuga        a hexagonal kasuga lantern (2.1 m): base, round post,
                     the platform, the fire box with a deer and a moon cut
                     through its sides (a warm glow inside), the roof with
                     curled corners, the jewel. Marker Light in the fire box.
  toro_yukimi        a snow-viewing lantern (1.15 m) on three curved legs
                     under a broad round roof. Marker Light.
  garden_bridge      an arched drum bridge (taikobashi) 4.4 m long, 1.5 m
                     wide, the deck rising 0.85 m: weathered planks on the
                     arch, cinnabar rails on posts with bronze onion caps
                     (giboshi). Origin = centre of the span on the floor;
                     the span runs along X. (Walkable as a ramp: the deck's
                     top is a smooth arc z(x) = 0.85 cos(pi x / 4.4) +
                     0.1, |x| < 2.2.)
  garden_pond        a pond 5.6 x 3.8 m: dark still water a little above the
                     floor (+0.03 m) with koi under the surface, ringed by
                     rounded edge stones and moss. Part garden_pond_water
                     (the water, its own material). Give the water a
                     collision box (or a kill-free shallow slow zone).
Front = -Z (Godot) where it matters.
"""
import math
import random

import numpy as np
from mathutils import Matrix, Vector

from artlib import asia as A
from artlib import asia_paint as AP
from artlib import egypt as E
from artlib import kit as K
from artlib import materials as M
from artlib import sculpt
from artlib.archkit import kit
from artlib.geo import Part
from artlib.kit import R, T
from artlib.materials import P, _dither, smoothstep
from artlib.model import Model
from artlib.painter import Surface
from artlib.sculpt import blob

I = AP.INK


# --------------------------------------------------------------------------
# rocks
# --------------------------------------------------------------------------

def _stone(p, blobs, tris, seed):
    me = sculpt.metaball_mesh(blobs, resolution=0.05)
    sculpt.cut(me, [((0.0, 0.0, 0.0), (0.0, 0.0, -1.0))])
    me = sculpt.decimate(me, tris)
    sculpt.into_part(p, me, "rock", smooth=False)


def _apron(p, r_in, r_out, n=28, cx=0.0, cy=0.0, sx=1.0, sy=1.0):
    """A disc of raked gravel round a rock (rings follow its outline: an
    ellipse sx x sy), from r_in under the stone to r_out."""
    verts_in, verts_out = [], []
    for k in range(n):
        a = math.tau * k / n
        verts_in.append(p.bm.verts.new((cx + math.cos(a) * r_in * sx, cy + math.sin(a) * r_in * sy, 0.004)))
        verts_out.append(p.bm.verts.new((cx + math.cos(a) * r_out * sx, cy + math.sin(a) * r_out * sy, 0.004)))
    for k in range(n):
        k2 = (k + 1) % n
        f = p._face([verts_in[k], verts_out[k], verts_out[k2], verts_in[k2]], "apron")
        f.normal_update()
        if f.normal.z < 0:
            f.normal_flip()


def rock(name, kind):
    p = Part(name)
    rng = random.Random(hash(name) % 1000)
    if kind == "a":                                   # tall standing stone, leaning a little
        b = [blob((0.0, 0.0, 0.5), (0.45, 0.35, 0.55)), blob((0.05, 0.02, 1.1), (0.32, 0.27, 0.5), rot=(0, 8, 0)),
             blob((0.1, 0.0, 1.5), (0.2, 0.18, 0.25), rot=(0, 12, 0)), blob((-0.3, 0.1, 0.25), (0.3, 0.3, 0.25))]
        _stone(p, b, 380, 1)
        _apron(p, 0.4, 1.3, sx=1.1, sy=0.9)
    elif kind == "b":                                 # long reclining stone
        b = [blob((-0.5, 0.0, 0.25), (0.6, 0.4, 0.32)), blob((0.4, 0.05, 0.22), (0.6, 0.35, 0.26)),
             blob((0.0, -0.05, 0.38), (0.5, 0.3, 0.2))]
        _stone(p, b, 320, 2)
        _apron(p, 0.5, 1.5, sx=1.4, sy=0.8)
    elif kind == "c":                                 # rounded mossy boulder
        b = [blob((0.0, 0.0, 0.35), (0.6, 0.55, 0.45)), blob((0.2, 0.15, 0.55), (0.35, 0.3, 0.3))]
        _stone(p, b, 300, 3)
        _apron(p, 0.45, 1.3)
    else:                                             # a group of three
        b = [blob((-0.45, 0.1, 0.4), (0.3, 0.28, 0.5)), blob((0.25, -0.15, 0.25), (0.35, 0.3, 0.28)),
             blob((0.55, 0.35, 0.15), (0.2, 0.2, 0.16))]
        _stone(p, b, 380, 4)
        _apron(p, 0.5, 1.5, sx=1.2, sy=1.0)
    return p


def apron_paint(ctx, seed=2101):
    """Gravel raked in rings round the stone, fading out at the rim."""
    x, y = ctx.p[:, 0], ctx.p[:, 1]
    r = np.hypot(x, y)
    s = A.gravel(ctx, seed, rake=r)
    s.rough = np.full(ctx.N, 0.92)
    return s


# --------------------------------------------------------------------------
# lanterns
# --------------------------------------------------------------------------

def _hex(r, z0, z1, p, slot, rot=30.0, bevel=0.0):
    pts = [(r * math.cos(math.radians(rot + 60 * k)), r * math.sin(math.radians(rot + 60 * k))) for k in range(6)]
    return p.ngon_prism(pts, z0, z1, slot, bevel=bevel)


def _hex_roof(p, r_eave, r_top, z0, z1, curl, slot="stone"):
    """A hexagonal stone roof: six sloping faces, the eave corners curling
    up (warabite), a thick eave edge."""
    out = []
    corners = []
    for k in range(6):
        a = math.radians(30 + 60 * k)
        corners.append((math.cos(a), math.sin(a)))
    top = [p.bm.verts.new((r_top * c[0], r_top * c[1], z1)) for c in corners]
    eave_hi = [p.bm.verts.new((r_eave * c[0], r_eave * c[1], z0 + 0.06 + curl)) for c in corners]
    eave_lo = [p.bm.verts.new((r_eave * c[0], r_eave * c[1], z0 + curl * 0.6)) for c in corners]
    mid_hi, mid_lo = [], []
    for k in range(6):
        c0, c1 = corners[k], corners[(k + 1) % 6]
        m = ((c0[0] + c1[0]) / 2 * 0.95, (c0[1] + c1[1]) / 2 * 0.95)
        mid_hi.append(p.bm.verts.new((r_eave * m[0], r_eave * m[1], z0 + 0.06)))
        mid_lo.append(p.bm.verts.new((r_eave * m[0], r_eave * m[1], z0)))
    for k in range(6):
        k2 = (k + 1) % 6
        for quad in ([top[k], eave_hi[k], mid_hi[k]], [top[k], mid_hi[k], eave_hi[k2], top[k2]],
                     [eave_lo[k], mid_lo[k], mid_hi[k], eave_hi[k]], [mid_lo[k], eave_lo[k2], eave_hi[k2], mid_hi[k]]):
            f = p._face(quad, slot)
            f.normal_update()
            c = f.calc_center_median()
            if f.normal.dot(Vector((c.x, c.y, c.z - (z0 - 0.3)))) < 0:
                f.normal_flip()
            out.append(f)
    under = p._face(list(reversed(eave_lo[:1] + mid_lo[:1] + eave_lo[1:2] + mid_lo[1:2] + eave_lo[2:3] + mid_lo[2:3] +
                                  eave_lo[3:4] + mid_lo[3:4] + eave_lo[4:5] + mid_lo[4:5] + eave_lo[5:6] +
                                  mid_lo[5:6])), slot)
    under.normal_update()
    if under.normal.z > 0:
        under.normal_flip()
    cap = p._face(top, slot)
    cap.normal_update()
    if cap.normal.z < 0:
        cap.normal_flip()
    return out


def toro_kasuga():
    p = Part("toro_kasuga")
    _hex(0.36, 0.0, 0.16, p, "stone", bevel=0.02)                      # base
    p.lathe([(0.3, 0.16), (0.24, 0.22), (0.18, 0.26)], "stone", segments=12, cap_bottom=False, cap_top=False)
    p.lathe([(0.12, 0.26), (0.115, 0.6), (0.12, 0.9), (0.13, 0.95)], "stone", segments=12, cap_bottom=False,
            cap_top=False)                                                                 # post
    for z in (0.5, 0.56):
        p.lathe([(0.128, z), (0.14, z + 0.015), (0.128, z + 0.03)], "stone", segments=12, cap_bottom=False,
                cap_top=False)
    p.lathe([(0.13, 0.95), (0.22, 1.0), (0.3, 1.04)], "stone", segments=12, cap_bottom=False, cap_top=False)
    _hex(0.33, 1.04, 1.16, p, "stone", bevel=0.015)                    # platform (chudai)
    # fire box: six posts, the sides closed with carved panels (deer, moon),
    # the two front and back panels open (light through)
    rf = 0.24
    for k in range(6):
        a = math.radians(30 + 60 * k)
        p.box((rf * math.cos(a), rf * math.sin(a), 1.36), (0.06, 0.06, 0.4), "stone", bevel=0.01)
    for k in range(6):
        a = math.radians(60 * k)
        if k in (1, 4):                                                          # open front/back windows
            continue
        f = p.box((0.0, 0.0, 0.0), (0.2, 0.03, 0.34), "panel", bevel=0.006)
        p.move(f, T(rf * 0.9 * math.cos(a), rf * 0.9 * math.sin(a), 1.36) @ R('Z', math.degrees(a) + 90))
    p.lathe([(0.0, 1.17), (0.07, 1.17), (0.075, 1.24), (0.0, 1.24)], "flame", segments=8)  # the flame dish glow
    p.lathe([(0.17, 1.17), (0.17, 1.55)], "glow", segments=6, cap_bottom=False, cap_top=False)   # inner paper
    _hex(0.3, 1.55, 1.6, p, "stone")
    _hex_roof(p, 0.52, 0.12, 1.6, 1.84, 0.09)
    p.lathe([(0.1, 1.84), (0.12, 1.88), (0.1, 1.92)], "stone", segments=10, cap_bottom=False, cap_top=False)
    p.lathe([(0.1, 1.92), (0.13, 1.97), (0.11, 2.03), (0.06, 2.08), (0.012, 2.11)], "stone", segments=10,
            cap_bottom=False, cap_top=True)                                              # jewel (hoju)
    return p


def toro_yukimi():
    p = Part("toro_yukimi")
    for k in range(3):
        a = math.radians(90 + 120 * k)
        pts = [(math.cos(a) * 0.42, math.sin(a) * 0.42, 0.0), (math.cos(a) * 0.38, math.sin(a) * 0.38, 0.2),
               (math.cos(a) * 0.28, math.sin(a) * 0.28, 0.42), (math.cos(a) * 0.2, math.sin(a) * 0.2, 0.52)]
        p.tube(pts, lambda t: 0.06 - 0.015 * t, "stone", sides=6)
    _hex(0.27, 0.5, 0.58, p, "stone", bevel=0.01)
    rf = 0.18
    for k in range(6):
        a = math.radians(30 + 60 * k)
        p.box((rf * math.cos(a), rf * math.sin(a), 0.72), (0.05, 0.05, 0.28), "stone", bevel=0.008)
    for k in (0, 2, 3, 5):
        a = math.radians(60 * k)
        f = p.box((0.0, 0.0, 0.0), (0.16, 0.025, 0.24), "panel", bevel=0.005)
        p.move(f, T(rf * 0.9 * math.cos(a), rf * 0.9 * math.sin(a), 0.72) @ R('Z', math.degrees(a) + 90))
    p.lathe([(0.0, 0.58), (0.06, 0.58), (0.06, 0.63), (0.0, 0.63)], "flame", segments=8)
    p.lathe([(0.13, 0.58), (0.13, 0.86)], "glow", segments=6, cap_bottom=False, cap_top=False)
    _hex(0.22, 0.86, 0.9, p, "stone")
    _hex_roof(p, 0.62, 0.1, 0.9, 1.06, 0.05)
    p.lathe([(0.08, 1.06), (0.1, 1.1), (0.07, 1.14), (0.02, 1.16)], "stone", segments=8, cap_bottom=False,
            cap_top=True)
    return p


_DEER = {}


def panel_paint(ctx, seed=2111):
    """Fire-box panels: weathered granite with a deer and a moon cut
    through as dark silhouettes (the glow shows through them at night)."""
    s = A.garden_stone(ctx, seed, moss=0.3, lichen=0.6, center=5.0)
    if "c" not in _DEER:
        c = AP.blank(26, 44)
        AP.ring(c, 13, 10, 0, 6, AP.INK["black"])                              # full moon
        deer = [(5, 30), (7, 26), (16, 26), (19, 23), (21, 20), (20, 24), (19, 27), (17, 30), (17, 38), (16, 38),
                (15, 31), (9, 31), (8, 38), (7, 38)]
        AP.fill(c, deer, AP.INK["black"])
        c[AP.line_mask(c.shape, [(20, 20), (22, 16), (24, 15)], 1.0)] = AP.INK["black"]
        _DEER["c"] = c
    lx = ctx.uvm[:, 0]
    lz = ctx.uvm[:, 1]
    # each panel's own metre UVs: centre the drawing on its face
    u0 = np.floor(lx / 0.25) * 0.25
    codes, rims = E.sample(_DEER["c"], np.mod(lx, 0.25) + 0.0, np.mod(lz, 0.4) + 0.0, ctx.texel * 1.0)
    side = np.abs(ctx.n[:, 2]) < 0.5
    cut = side & (codes > 0)
    s.use_ramp(P["pig_black"], mask=cut, shade=np.full(ctx.N, 0.6))
    s.height = s.height - cut * 0.004
    s.emit = np.where(cut[:, None], np.array(P["lamp_warm"][2]) * 0.6, 0.0)
    return s


def flame_glow(ctx, seed=2121):
    return M.glow(ctx, "lamp_warm", 4.6, 1.0, seed)


def paper_glow(ctx, seed=2123):
    s = A.paper(ctx, seed, "washi", 6.4, glow=1.0)
    s.emit = s.colors() * np.array([1.0, 0.72, 0.45]) * 0.9
    return s


# --------------------------------------------------------------------------
# bridge and pond
# --------------------------------------------------------------------------

BR_L, BR_W, BR_H = 4.4, 1.5, 0.85


def _deck_z(x):
    return BR_H * math.cos(math.pi * x / BR_L) + 0.1


def bridge():
    p = Part("garden_bridge")
    n = 16
    # deck planks across the arch
    for k in range(n):
        x0 = -BR_L / 2 + BR_L * k / n
        x1 = x0 + BR_L / n
        xm = (x0 + x1) / 2
        z = _deck_z(xm)
        slope = math.degrees(math.atan(-BR_H * math.pi / BR_L * math.sin(math.pi * xm / BR_L)))
        f = p.box((0.0, 0.0, 0.0), (BR_L / n + 0.02, BR_W, 0.06), "deck", bevel=0.008)
        p.move(f, T(xm, 0.0, z - 0.03) @ R('Y', -slope))
    # the arch beams under the deck, both sides
    for sy in (-1, 1):
        pts = [(x, sy * (BR_W / 2 - 0.08), _deck_z(x) - 0.12) for x in np.linspace(-BR_L / 2 - 0.1, BR_L / 2 + 0.1, 12)]
        p.tube(pts, 0.09, "lacquer", sides=6)
    # rails: posts with bronze caps, a top rail and a mid rail following the arch
    xs = np.linspace(-BR_L / 2 + 0.05, BR_L / 2 - 0.05, 6)
    for sy in (-1, 1):
        y = sy * (BR_W / 2 - 0.05)
        for x in xs:
            z = _deck_z(x)
            p.box((x, y, z + 0.4), (0.09, 0.09, 0.8), "lacquer", bevel=0.01)
            cap = p.lathe([(0.055, 0.0), (0.06, 0.03), (0.07, 0.07), (0.045, 0.12), (0.012, 0.17)], "bronze",
                          segments=8, cap_top=True)
            p.move(cap, T(x, y, z + 0.8))
        for dz, r in ((0.72, 0.035), (0.38, 0.025)):
            pts = [(x, y, _deck_z(x) + dz) for x in np.linspace(xs[0], xs[-1], 12)]
            p.tube(pts, r, "lacquer", sides=6)
    # stone footings at both ends
    for sx in (-1, 1):
        p.box((sx * (BR_L / 2 + 0.05), 0.0, 0.08), (0.4, BR_W + 0.3, 0.16), "stone", bevel=0.03)
    return p


def pond():
    p = Part("garden_pond")
    w = Part("garden_pond_water")
    rng = random.Random(7)
    n = 36
    pts = []
    for k in range(n):
        a = math.tau * k / n
        r = 1.0 + 0.12 * math.sin(a * 2 + 0.6) + 0.08 * math.sin(a * 3 + 1.7)
        pts.append((math.cos(a) * 2.8 * r, math.sin(a) * 1.9 * r))
    # water: a fan of triangles at +0.03
    c = w.bm.verts.new((0.0, 0.0, 0.03))
    ring = [w.bm.verts.new((x, y, 0.03)) for x, y in pts]
    for k in range(n):
        f = w._face([c, ring[k], ring[(k + 1) % n]], "water")
        f.normal_update()
        if f.normal.z < 0:
            f.normal_flip()
    # edge stones and moss
    for k in range(0, n, 1):
        x, y = pts[k]
        d = Vector((x, y, 0.0)).normalized()
        sc = rng.uniform(0.18, 0.32)
        cpos = (x + d.x * sc * 0.4, y + d.y * sc * 0.4, sc * 0.35)
        b = [blob(cpos, (sc, sc * 0.8, sc * 0.55), rot=(0, 0, rng.uniform(0, 90)))]
        me = sculpt.metaball_mesh(b, resolution=0.05)
        sculpt.cut(me, [((0.0, 0.0, 0.0), (0.0, 0.0, -1.0))])
        me = sculpt.decimate(me, 40)
        sculpt.into_part(p, me, "rock", smooth=False)
    return [p, w]


def water_paint(ctx, seed=2131):
    """Dark still water with koi under it: orange-and-white fish shapes
    seen through the dark (no transparency: painted in)."""
    s = A.water(ctx, seed)
    x, y = ctx.p[:, 0], ctx.p[:, 1]
    rng = np.random.default_rng(3)
    for k in range(6):
        cx, cy = rng.uniform(-1.8, 1.8), rng.uniform(-1.1, 1.1)
        a = rng.uniform(0, math.tau)
        u = (x - cx) * math.cos(a) + (y - cy) * math.sin(a)
        v = -(x - cx) * math.sin(a) + (y - cy) * math.cos(a)
        bend = 0.04 * np.sin(u * 6.0 + k)
        vv = v - bend
        body = (u / 0.34) ** 2 + (vv / (0.1 * (1.0 + np.clip(u / 0.34, -1, 1) * 0.35))) ** 2 < 1.0
        tail = (u < -0.28) & (u > -0.46) & (np.abs(vv) < (-0.26 - u) * 0.8)
        fins = (np.abs(u - 0.12) < 0.05) & (np.abs(vv) < 0.17) & (np.abs(vv) > 0.06)
        fish = body | tail | fins
        patch = ctx.fbm(9.0, 2, seed + 10 + k) > (0.05 if k % 2 else -0.2)
        white = fish & patch
        s.use_ramp(P["koi"], mask=fish & ~white, shade=np.full(ctx.N, 2.0 + (k % 3) * 0.5) + ctx.rand(seed) * 0.6)
        s.use_ramp(P["moon_white"], mask=white, shade=np.full(ctx.N, 2.2) + ctx.rand(seed + 1) * 0.6)
    s.rough = np.full(ctx.N, 0.03)
    return s


def build():
    out = []
    stone = lambda c: A.garden_stone(c, 2141, moss=1.0)
    for tag in "abcd":
        out.append(kit(f"garden_rock_{tag}", [rock(f"garden_rock_{tag}", tag)], {"rock": stone, "apron": apron_paint},
                       ppm=96, ao_dist=0.4, built_final=True, organic=(f"garden_rock_{tag}",), preview=tag in "ac"))
    lantern = {"stone": lambda c: A.garden_stone(c, 2151, moss=0.8, lichen=1.0, center=5.4),
               "panel": panel_paint, "flame": flame_glow, "glow": paper_glow}
    out.append(kit("toro_kasuga", [toro_kasuga()], lantern, ppm=128, ao_dist=0.25, built_final=True,
                   markers=[("Light", (0.0, 0.0, 1.36), None)]))
    out.append(kit("toro_yukimi", [toro_yukimi()], lantern, ppm=128, ao_dist=0.25, built_final=True,
                   markers=[("Light", (0.0, 0.0, 0.72), None)]))
    out.append(kit("garden_bridge", [bridge()], {"deck": A.weathered_wood, "lacquer": lambda c: A.lacquer(c, 2161, wear=0.6),
                                                 "bronze": lambda c: A.bronze_patina(c, 2163, crust=0.6, polish=0.6),
                                                 "stone": lambda c: A.garden_stone(c, 2165, moss=0.6)},
                   ppm=96, ao_dist=0.3, built_final=True))
    out.append(kit("garden_pond", pond(), {"rock": lambda c: A.garden_stone(c, 2171, moss=1.2), "water": water_paint},
                   ppm=64, ao_dist=0.3, built_final=True, organic=("garden_pond",), preview_elevation=35.0))
    return out
