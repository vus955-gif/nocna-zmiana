"""Floor I, Asia wing kit: lanterns, display cases and the stand.

  asia_lantern_red    Chinese palace lantern: a ribbed globe of red silk
                      (lit from inside: emissive), black-lacquer caps with
                      gilt rims and gilt cloud bands, a red cord up to a
                      gilt hook 1.0 m above, a gilt bead and a red silk
                      tassel below. Fixture convention: origin = the light
                      (the centre of the globe); marker Light there.
  asia_lantern_floor  Japanese floor lantern (andon): a square frame of
                      dark wood with paper sides glowing, a handle on top,
                      on four short legs. Origin = centre of the floor;
                      marker Light at the flame (0.42 m up).
  asia_case_tall      a tall display case: black-lacquer cabinet with
                      gilt-bronze mounts and a brocade deck, a glass hood
                      in a slim bronze frame (part asia_case_tall_glass);
                      marker ItemSpot on the deck (0.86 m). 0.9 x 1.9 x 0.7.
  asia_case_low       a table case 1.6 x 0.95 x 0.8 with a glass box on top
                      (part asia_case_low_glass); markers ItemSpot_1..3.
  asia_plinth         a hardwood stand (rosewood, waisted apron, cabriole
                      legs on cloud feet, a base stretcher), 0.7 x 0.9 x
                      0.7: marker ItemSpot on the top (0.9 m).
Front = -Z (Godot); origin centre of the base unless noted.
"""
import math

import numpy as np
from mathutils import Matrix

from artlib import asia as A
from artlib import asia_paint as AP
from artlib import egypt as E
from artlib import materials as M
from artlib.archkit import front_prism, kit, plan_sweep
from artlib.asia_geo import ccw, side_prism
from artlib.geo import Part
from artlib.kit import R, T
from artlib.materials import P, _dither
from artlib.painter import Surface

I = AP.INK


# --------------------------------------------------------------------------
# lanterns
# --------------------------------------------------------------------------

def lantern_red():
    p = Part("asia_lantern_red")
    ribs = lambda i, j: 1.0 + (0.035 if i % 2 == 0 and 0 < j < 6 else 0.0)
    prof = [(0.17, -0.25), (0.24, -0.2), (0.285, -0.11), (0.3, 0.0), (0.285, 0.11), (0.24, 0.2), (0.17, 0.25)]
    p.lathe(prof, "silk", segments=24, ring_scale=ribs, cap_bottom=False, cap_top=False)
    for z, s in ((0.25, 1), (-0.25, -1)):
        p.lathe([(0.19, z), (0.2, z + 0.02 * s), (0.2, z + 0.055 * s), (0.16, z + 0.075 * s), (0.06, z + 0.08 * s)],
                "cap", segments=16, cap_bottom=False, cap_top=True)
        p.lathe([(0.205, z + 0.012 * s), (0.212, z + 0.028 * s), (0.205, z + 0.044 * s)], "gilt", segments=16,
                cap_bottom=False, cap_top=False)
    # cord and hook
    p.lathe([(0.03, 0.33), (0.045, 0.36), (0.03, 0.39)], "gilt", segments=8)
    p.tube([(0.0, 0.0, 0.39), (0.0, 0.0, 0.95)], 0.008, "cord", sides=5)
    p.tube([(0.0, 0.0, 0.95), (0.0, 0.0, 1.0), (0.03, 0.0, 1.02), (0.05, 0.0, 0.99)], 0.008, "gilt", sides=5,
           caps=False)
    # bead and tassel
    p.lathe([(0.02, -0.34), (0.045, -0.37), (0.045, -0.4), (0.02, -0.43)], "gilt", segments=10)
    p.lathe([(0.03, -0.43), (0.045, -0.47), (0.07, -0.68), (0.06, -0.72), (0.03, -0.72)], "tassel", segments=10,
            cap_top=False)
    p.tube([(0.0, 0.0, -0.33), (0.0, 0.0, -0.36)], 0.008, "cord", sides=5)
    return p


def lantern_silk(ctx, seed=1301):
    """Red silk lit from inside: hottest in the middle of each panel,
    dark at the ribs; gilt cloud bands painted near the caps."""
    s = A.silk(ctx, "silk_red", 4.4, seed, sheen=0.3)
    z = ctx.p[:, 2]
    a = np.arctan2(ctx.p[:, 1], ctx.p[:, 0])
    rib = np.abs(np.cos(a * 12.0)) > 0.94
    s.shade += 1.4 - np.abs(z) * 6.0 - rib * 2.2
    band = (np.abs(np.abs(z) - 0.175) < 0.035)
    u = ctx.uvm[:, 0]
    cloud = AP.cloud_band(64, 6, seed=3, ground=0, cloud=I["gold"], line_code=I["gold"])
    codes, rims = E.sample(cloud, u, np.abs(z) - 0.14, ctx.texel, wrap_x=True, wrap_y=False)
    codes = np.where(band, codes, 0).astype(np.int16)
    s = E.paint_over(ctx, s, codes, rims, seed + 1, flake=0.0, wear=0.0, inks=A.INKS)
    glow = np.clip(1.0 - np.abs(z) * 2.6, 0.25, 1.0) * np.where(rib, 0.4, 1.0) * np.where(codes > 0, 0.3, 1.0)
    s.emit = s.colors() * glow[:, None] * 1.3
    return s


def tassel(ctx, seed=1303):
    s = Surface(ctx.N)
    a = np.arctan2(ctx.p[:, 1], ctx.p[:, 0])
    strand = np.sin(a * 40.0 + ctx.fbm(20.0, 2, seed) * 2.0) > 0.2
    s.use_ramp(P["silk_red"], shade=3.6 + strand * 1.4 + _dither(ctx, 0.5, seed) - (1.0 - ctx.ao) * 2.0)
    s.rough = np.full(ctx.N, 0.6)
    return s


def lantern_floor():
    p = Part("asia_lantern_floor")
    W, H0, H1 = 0.32, 0.12, 0.84
    for sx in (-1, 1):
        for sy in (-1, 1):
            p.box((sx * (W / 2 - 0.015), sy * (W / 2 - 0.015), (H1 + 0.0) / 2), (0.03, 0.03, H1), "frame",
                  bevel=0.004)
            p.box((sx * (W / 2 + 0.01), sy * (W / 2 + 0.01), 0.04), (0.04, 0.04, 0.08), "frame", bevel=0.005)
    for z in (H0, 0.48, H1 - 0.015):
        for k in range(4):
            f = p.box((0.0, -(W / 2 - 0.015), z), (W, 0.03, 0.03), "frame", bevel=0.004)
            p.move(f, R('Z', 90 * k))
    for k in range(4):
        f = p.box((0.0, -(W / 2 - 0.02), (H0 + H1) / 2 + 0.01), (W - 0.05, 0.004, H1 - H0 - 0.04), "paper")
        p.move(f, R('Z', 90 * k))
    p.box((0.0, 0.0, H0 - 0.01), (W - 0.03, W - 0.03, 0.02), "frame")
    # handle
    p.tube([(-0.1, 0.0, H1), (-0.1, 0.0, H1 + 0.12), (0.1, 0.0, H1 + 0.12), (0.1, 0.0, H1)], 0.012, "frame",
           sides=5)
    # the oil dish inside
    p.lathe([(0.0, 0.4), (0.06, 0.41), (0.065, 0.43)], "iron", segments=10, cap_bottom=False)
    return p


def andon_paper(ctx, seed=1311):
    s = A.paper(ctx, seed, "washi", 6.6, glow=1.0)
    z = ctx.p[:, 2]
    hot = np.clip(1.0 - np.abs(z - 0.45) * 2.2, 0.35, 1.0)
    s.emit = s.colors() * hot[:, None] * np.array([1.0, 0.78, 0.5])
    return s


# --------------------------------------------------------------------------
# cases and stand
# --------------------------------------------------------------------------

def _mount(p, x, y, z, sx, sy, mat="gilt"):
    """A gilt-bronze corner mount (an L plate with a cloud-cut tip)."""
    p.box((x, y - sy * 0.002, z), (0.07, 0.006, 0.07), mat, bevel=0.002)
    p.box((x - sx * 0.002, y, z), (0.006, 0.07, 0.07), mat, bevel=0.002)


def case_tall():
    p = Part("asia_case_tall")
    g = Part("asia_case_tall_glass")
    W, D, B, H = 0.9, 0.7, 0.85, 1.9
    p.box((0.0, 0.0, 0.04), (W + 0.04, D + 0.04, 0.08), "lacquer", bevel=0.012)
    p.box((0.0, 0.0, (0.08 + B) / 2), (W, D, B - 0.08), "lacquer", bevel=0.01)
    p.box((0.0, 0.0, B + 0.015), (W + 0.04, D + 0.04, 0.03), "lacquer", bevel=0.008)
    p.box((0.0, 0.0, B + 0.035), (W - 0.06, D - 0.06, 0.01), "brocade")
    for sx in (-1, 1):
        for sy in (-1, 1):
            for z in (0.15, B - 0.08):
                _mount(p, sx * W / 2, sy * D / 2, z, sx, sy)
    # brass plaque on the front of the cabinet
    p.box((0.0, -D / 2 - 0.004, B - 0.25), (0.26, 0.008, 0.1), "plaque", bevel=0.002)
    # bronze frame of the hood: corner posts, top frame, cornice
    top = H - 0.06
    for sx in (-1, 1):
        for sy in (-1, 1):
            p.box((sx * (W / 2 - 0.012), sy * (D / 2 - 0.012), (B + top) / 2 + 0.015), (0.024, 0.024, top - B),
                  "bronze", bevel=0.003)
    for sy in (-1, 1):
        p.box((0.0, sy * (D / 2 - 0.012), top), (W, 0.024, 0.024), "bronze", bevel=0.003)
    for sx in (-1, 1):
        p.box((sx * (W / 2 - 0.012), 0.0, top), (0.024, D, 0.024), "bronze", bevel=0.003)
    p.box((0.0, 0.0, H - 0.03), (W + 0.03, D + 0.03, 0.05), "lacquer", bevel=0.01)
    gw, gd = W - 0.03, D - 0.03
    z0, z1 = B + 0.03, top - 0.012
    for sy in (-1, 1):
        g.poly([(-gw / 2, sy * gd / 2, z0), (gw / 2, sy * gd / 2, z0), (gw / 2, sy * gd / 2, z1), (-gw / 2, sy * gd / 2, z1)],
               "glass")
    for sx in (-1, 1):
        g.poly([(sx * gw / 2, -gd / 2, z0), (sx * gw / 2, gd / 2, z0), (sx * gw / 2, gd / 2, z1), (sx * gw / 2, -gd / 2, z1)],
               "glass")
    g.poly([(-gw / 2, -gd / 2, z1), (gw / 2, -gd / 2, z1), (gw / 2, gd / 2, z1), (-gw / 2, gd / 2, z1)], "glass")
    return [p, g], B + 0.04


def case_low():
    p = Part("asia_case_low")
    g = Part("asia_case_low_glass")
    W, D, B, Hg = 1.6, 0.8, 0.55, 0.4
    # a table on four legs with an apron, glass box on top
    for sx in (-1, 1):
        for sy in (-1, 1):
            p.box((sx * (W / 2 - 0.05), sy * (D / 2 - 0.05), B / 2), (0.07, 0.07, B), "lacquer", bevel=0.01)
            _mount(p, sx * (W / 2 - 0.015), sy * (D / 2 - 0.015), 0.05, sx, sy)
    p.box((0.0, 0.0, B - 0.07), (W - 0.04, D - 0.04, 0.12), "lacquer", bevel=0.01)
    p.box((0.0, 0.0, B + 0.015), (W + 0.02, D + 0.02, 0.03), "lacquer", bevel=0.008)
    p.box((0.0, 0.0, B + 0.035), (W - 0.06, D - 0.06, 0.01), "brocade")
    p.box((0.0, -D / 2 - 0.004, B - 0.07), (0.3, 0.008, 0.08), "plaque", bevel=0.002)
    top = B + 0.03 + Hg
    for sx in (-1, 1):
        for sy in (-1, 1):
            p.box((sx * (W / 2 - 0.01), sy * (D / 2 - 0.01), (B + 0.03 + top) / 2), (0.02, 0.02, Hg), "bronze",
                  bevel=0.003)
    for sy in (-1, 1):
        p.box((0.0, sy * (D / 2 - 0.01), top), (W, 0.02, 0.02), "bronze", bevel=0.003)
    for sx in (-1, 1):
        p.box((sx * (W / 2 - 0.01), 0.0, top), (0.02, D, 0.02), "bronze", bevel=0.003)
    gw, gd = W - 0.03, D - 0.03
    z0, z1 = B + 0.03, top - 0.01
    for sy in (-1, 1):
        g.poly([(-gw / 2, sy * gd / 2, z0), (gw / 2, sy * gd / 2, z0), (gw / 2, sy * gd / 2, z1), (-gw / 2, sy * gd / 2, z1)],
               "glass")
    for sx in (-1, 1):
        g.poly([(sx * gw / 2, -gd / 2, z0), (sx * gw / 2, gd / 2, z0), (sx * gw / 2, gd / 2, z1), (sx * gw / 2, -gd / 2, z1)],
               "glass")
    g.poly([(-gw / 2, -gd / 2, z1), (gw / 2, -gd / 2, z1), (gw / 2, gd / 2, z1), (-gw / 2, gd / 2, z1)], "glass")
    return [p, g], B + 0.04


def plinth():
    p = Part("asia_plinth")
    W, H = 0.7, 0.9
    # top slab with a moulded edge
    p.box((0.0, 0.0, H - 0.03), (W, W, 0.06), "wood", bevel=0.012)
    # waist and apron
    p.box((0.0, 0.0, H - 0.08), (W - 0.08, W - 0.08, 0.04), "wood", bevel=0.006)
    half = [(0.0, H - 0.17), (0.05, H - 0.15), (0.11, H - 0.18), (0.17, H - 0.15), (0.24, H - 0.17),
            (0.29, H - 0.13), (0.3, H - 0.1)]
    outline = [(-x, z) for x, z in reversed(half[1:])] + half + [(-0.3, H - 0.1)]
    outline = [(x, z) for x, z in outline]
    for k in range(4):
        f = front_prism(p, ccw(outline[:-1]), 0.025, "wood", y_back=-(W / 2 - 0.07))
        p.move(f, R('Z', 90 * k))
    # cabriole legs: a tube bowing out and back to a cloud foot
    for sx in (-1, 1):
        for sy in (-1, 1):
            c = np.array([sx * (W / 2 - 0.06), sy * (W / 2 - 0.06)])
            out = np.array([sx, sy]) / math.sqrt(2)
            pts = []
            for k in range(7):
                t = k / 6
                bow = 0.05 * math.sin(t * math.pi) - 0.03 * t
                xy = c + out * bow
                pts.append((xy[0], xy[1], H - 0.12 - (H - 0.2) * t))
            p.tube(pts, lambda t: 0.032 - 0.012 * t, "wood", sides=6)
            foot = c + out * 0.0
            p.lathe([(0.04, 0.04), (0.05, 0.06), (0.03, 0.09)], "wood", segments=8, center=(foot[0], foot[1], 0.0))
    # base stretcher frame
    for k in range(4):
        f = p.box((0.0, -(W / 2 - 0.06), 0.03), (W - 0.06, 0.05, 0.06), "wood", bevel=0.01)
        p.move(f, R('Z', 90 * k))
    return p


def rosewood(ctx, seed=1321):
    s = A.wood(ctx, seed, ramp="asia_cedar", center=3.4, rough=0.3, contrast=1.0)
    return s


def plaque(ctx, seed=1331):
    s = M.brass(ctx, seed, tarnish_amount=1.4)
    front = np.abs(ctx.n[:, 1]) > 0.8
    lines = front & (np.mod(np.floor(ctx.p[:, 2] / ctx.texel), 3) == 0) & \
        (np.abs(ctx.p[:, 0]) < 0.1) & (ctx.rand(seed + 1) > 0.25)
    s.shade[lines] -= 3.0
    return s


def brocade(ctx, seed=1341):
    """Red silk brocade with a small gold lattice of flowers."""
    s = A.silk(ctx, "brocade", 4.0, seed, sheen=0.6)
    u = np.floor(ctx.uvm[:, 0] / ctx.texel)
    v = np.floor(ctx.uvm[:, 1] / ctx.texel)
    dia = (np.mod(u + v, 8) == 0) | (np.mod(u - v, 8) == 0)
    dot = (np.mod(u, 8) == 4) & (np.mod(v, 8) == 0)
    gold = dia | dot
    s.use_ramp(P["gold"], mask=gold, shade=np.full(ctx.N, 5.0) + _dither(ctx, 0.6, seed + 1) - (1.0 - ctx.ao) * 2.0)
    s.metal = np.where(gold, 0.8, 0.0)
    return s


def build():
    out = []
    gilt = lambda c: A.gilt(c, 1351, worn=0.4, under="lacquer_black")
    out.append(kit("asia_lantern_red", [lantern_red()],
                   {"silk": lantern_silk, "cap": A.lacquer_black, "gilt": gilt, "tassel": tassel,
                    "cord": lambda c: A.silk(c, "silk_red", 3.6, 1361)},
                   ppm=160, ground=None, ao_dist=0.08, markers=[("Light", (0.0, 0.0, 0.0), None)]))
    out.append(kit("asia_lantern_floor", [lantern_floor()],
                   {"frame": lambda c: A.lacquer(c, 1371, ramp="lacquer_black", center=3.4, wear=0.2),
                    "paper": andon_paper, "iron": M.iron},
                   ppm=192, ao_dist=0.08, markers=[("Light", (0.0, 0.0, 0.42), None)]))
    bronze = lambda c: A.bronze_patina(c, 1381, crust=0.3, polish=0.9)
    lac = lambda c: A.lacquer(c, 1391, ramp="lacquer_black", center=3.2, wear=0.25)
    parts, deck = case_tall()
    out.append(kit("asia_case_tall", parts, {"lacquer": lac, "gilt": gilt, "bronze": bronze, "brocade": brocade,
                                             "plaque": plaque},
                   kinds={"glass": "glass"}, ppm=128, ao_dist=0.2, markers=[("ItemSpot", (0.0, 0.0, deck), None)]))
    parts, deck = case_low()
    out.append(kit("asia_case_low", parts, {"lacquer": lac, "gilt": gilt, "bronze": bronze, "brocade": brocade,
                                            "plaque": plaque},
                   kinds={"glass": "glass"}, ppm=128, ao_dist=0.2,
                   markers=[(f"ItemSpot_{k + 1}", (x, 0.0, deck), None) for k, x in enumerate((0.5, 0.0, -0.5))]))
    out.append(kit("asia_plinth", [plinth()], {"wood": rosewood}, ppm=128, ao_dist=0.15,
                   markers=[("ItemSpot", (0.0, 0.0, 0.9), None)]))
    return out
