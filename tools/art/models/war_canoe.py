"""Floor I, the Pacific gallery: the great war canoe hanging over the
collapsed floor - when the harpoon hooks its ring it swings round and drops
across the gap as a bridge. A generic stylisation of a Pacific outrigger
war canoe (no particular vessel or carving tradition copied): a 12 m dugout
hull with lashed washstrakes painted in red, black and white triangles, a
plank fighting deck down the middle, a carved prow figure with shell eyes
and a breakwater board, a tall sternpost hung with feather streamers, an
outrigger float on three booms with paddles lashed to them, iron rings at
bow and stern, and the museum's hanging rig: four slings to a spreader
beam and one rope up to the ceiling.

Godot axes, origin = the keel's underside amidships; the bow points -Z.
  war_canoe   hull, deck, outrigger (+X side), prow board, sternpost,
              paddles: one mesh, root. 12.6 x 3.1 m footprint, sternpost
              top 3.1 m. The walking deck: top at y 0.5, 0.8 m wide, from
              z -4.6 to 4.6 (marker deck).
  prow        the carved prow figure (child of war_canoe).
  sling       the spreader beam (y 2.6, 7.4 m long along Z) and the four
              slings down to the gunwales; pivot = the beam centre
              (0, 2.6, 0), child of war_canoe (hide it once the canoe lies
              as a bridge, or let it go slack).
  rope_main   the single rope up from the beam centre, 2 m long, pivot =
              its BOTTOM (0, 2.6, 0), child of sling: set scale.y =
              (ceiling - its world y) / 2 every frame so it always reaches
              the ceiling hook as the canoe moves. Marker rope_top (child)
              at its upper end.
Markers: hook_ring (iron ring at the bow, (0, 0.72, -6.25)), hook_ring_stern
((0, 0.8, 6.1)), deck ((0, 0.5, 0)), bridge_bow / bridge_stern (under the
deck ends: where the canoe rests on the rims, (0, 0, -/+4.6)).
Rest pose: hanging level, along the gap. Suggested bridge move (all on the
root): yaw 90 degrees about Y (the bow swings toward the harpoon) while
dropping to the rims, with a little roll wobble; a short pendulum swing
first (rotation.z +-8 degrees) sells the pull. 96 px/m.
"""
import math

import bmesh
import numpy as np
from mathutils import Matrix, Vector

from artlib import clay
from artlib import americas as AM
from artlib import americas_paint as AP
from artlib import kit as K
from artlib import sculpt
from artlib.archkit import kit
from artlib.geo import Part
from artlib.materials import P, _dither, _select
from artlib.sculpt import blob, limb

HALF = 6.0          # hull from y -6 (stern) to +6 (bow) in Blender
THICK = 0.06


def half_width(y):
    t = abs(y) / HALF
    return 0.12 + 0.46 * math.cos(min(1.0, t) * math.pi / 2) ** 0.7


def keel(y):
    return 0.22 * (abs(y) / HALF) ** 3


def sheer(y):
    return 0.92 + 0.38 * (abs(y) / HALF) ** 2.5


def inner_width(y, z):
    """Half width of the hull's inside at height z (from the section)."""
    pts = section(y, THICK, 40)
    best = 0.0
    for (x0, z0), (x1, z1) in zip(pts[:-1], pts[1:]):
        if (z0 - z) * (z1 - z) <= 0 and z0 != z1:
            x = x0 + (x1 - x0) * (z - z0) / (z1 - z0)
            best = max(best, abs(x))
    return best


def section(y, inset=0.0, n=14):
    """Points of the U section (x, z), port gunwale -> keel -> starboard."""
    w = half_width(y) - inset
    zb = keel(y) + inset
    zt = sheer(y)
    D = zt - zb
    pts = []
    for i in range(n + 1):
        phi = -math.pi / 2 + math.pi * i / n
        s = math.sin(phi)
        x = w * math.copysign(abs(s) ** 0.8, s)
        z = zb + D * (1.0 - abs(math.cos(phi)) ** 0.45)
        pts.append((x, z))
    return pts


def hull():
    p = Part("war_canoe")
    ys = list(np.linspace(-HALF, HALF, 27))
    outer = [[p.bm.verts.new((x, y, z)) for x, z in section(y)] for y in ys]
    inner = [[p.bm.verts.new((x, y, z)) for x, z in section(y, THICK)] for y in ys]
    m = len(outer[0])
    faces_out, faces_in, faces_top = [], [], []
    for j in range(len(ys) - 1):
        for i in range(m - 1):
            faces_out.append(p._face([outer[j][i], outer[j + 1][i], outer[j + 1][i + 1], outer[j][i + 1]], "hull"))
            faces_in.append(p._face([inner[j][i], inner[j][i + 1], inner[j + 1][i + 1], inner[j + 1][i]], "inside"))
        for i in (0, m - 1):
            faces_top.append(p._face([outer[j][i], inner[j][i], inner[j + 1][i], outer[j + 1][i]], "gunwale"))
    # end caps (the ends are closed by the prow and stern blocks)
    for j in (0, len(ys) - 1):
        for i in range(m - 1):
            faces_top.append(p._face([outer[j][i], outer[j][i + 1], inner[j][i + 1], inner[j][i]], "hull"))
    centre_line = lambda f: Vector((0.0, f.calc_center_median().y, 0.55))
    for f in faces_out:
        f.normal_update()
        if f.normal.dot(f.calc_center_median() - centre_line(f)) < 0:
            f.normal_flip()
    for f in faces_in:
        f.normal_update()
        if f.normal.dot(f.calc_center_median() - centre_line(f)) > 0:
            f.normal_flip()
    for f in faces_top:
        f.normal_update()
        c = f.calc_center_median()
        want = Vector((0.0, 0.0, 1.0)) if abs(c.y) < HALF - 0.01 else Vector((0.0, math.copysign(1.0, c.y), 0.0))
        if f.normal.dot(want) < 0:
            f.normal_flip()
    # solid end blocks: bow and stern beaks
    for sy in (-1, 1):
        y0 = sy * HALF
        p.box((0.0, y0 + sy * 0.25, 0.62), (0.26, 0.5, 0.8), "hull", bevel=0.03)
    # the fighting deck: planks on cross bearers, narrowing with the hull
    for k in range(9):
        y = -4.4 + k * 1.1
        p.box((0.0, y, 0.38), (inner_width(y, 0.38) * 2 - 0.06, 0.1, 0.08), "deck", bevel=0.01)
    for k in range(10):
        y0, y1 = -4.6 + k * 0.92, -4.6 + (k + 1) * 0.92
        w = min(0.8, min(inner_width(y0, 0.46), inner_width(y1, 0.46)) * 2 - 0.04)
        p.box((0.0, (y0 + y1) / 2, 0.46), (w, 0.92, 0.08), "deck", bevel=0.012)
    # breakwater board across the bow, carved with triangles
    p.box((0.0, 4.7, 1.05), (0.7, 0.06, 0.32), "board", bevel=0.01)
    return p


def outrigger(p):
    # the float: a slim log, its ends drawn up
    ax = 2.55
    pts = [(ax, y, 0.32 + 0.08 * (abs(y) / 3.5) ** 3) for y in np.linspace(-3.5, 3.5, 9)]
    p.tube(pts, lambda t: 0.14 * (0.35 + 0.65 * math.sin(math.pi * t) ** 0.4), "float", sides=10)
    # three booms from the hull's gunwales across to the float
    for y in (-2.2, 0.0, 2.2):
        p.tube([(-0.62, y, 1.02), (0.0, y, 1.08), (ax, y, 0.92)], 0.055, "boom", sides=8)
        # forked connectors down to the float
        for dy in (-0.12, 0.12):
            p.tube([(ax, y + dy, 0.9), (ax, y + dy * 0.4, 0.42)], 0.03, "boom", sides=6)
        p.box((ax, y, 0.95), (0.16, 0.16, 0.08), "lash", bevel=0.01)
        p.box((0.56, y, 1.02), (0.14, 0.14, 0.14), "lash", bevel=0.01)
        p.box((-0.56, y, 1.02), (0.14, 0.14, 0.14), "lash", bevel=0.01)
    # paddles lashed along the booms
    for k, y in enumerate((-2.2, 2.2)):
        for side in (-1, 1):
            yy = y + side * 0.18
            p.tube([(0.7, yy, 1.12), (1.9, yy, 1.04)], 0.022, "paddle", sides=6)
            blade = p.lathe([(0.0, 0.0), (0.09, 0.05), (0.1, 0.3), (0.07, 0.52), (0.0, 0.6)], "paddle",
                            segments=8, squash=(1.0, 0.18))
            p.move(blade, Matrix.Translation(Vector((1.9, yy, 1.04))) @ Matrix.Rotation(math.radians(94), 4, 'Y'))


def sternpost(p):
    # a tall post rising and curving back over the stern
    pts = [(0.0, -HALF - 0.35, 0.7), (0.0, -HALF - 0.42, 1.5), (0.0, -HALF - 0.55, 2.3), (0.0, -HALF - 0.78, 2.9),
           (0.0, -HALF - 1.0, 3.1)]
    p.tube(pts, lambda t: 0.13 - 0.07 * t, "post", sides=8)
    # notched collars up the post
    for z in (1.2, 1.7, 2.2):
        p.lathe([(0.0, 0.0), (0.13, 0.0), (0.15, 0.04), (0.13, 0.08), (0.0, 0.08)], "post_band", segments=8,
                center=(0.0, -HALF - 0.43 - (z - 1.2) * 0.12, z))
    # feather streamers hanging from the tip
    for k in range(5):
        a = (k - 2) * 0.12
        top = Vector((a * 0.4, -HALF - 1.0, 3.05))
        p.tube([tuple(top), tuple(top + Vector((a, -0.05, -0.5))), tuple(top + Vector((a * 1.5, 0.05, -1.0)))],
               lambda t: 0.035 * (1.0 - 0.5 * t) + 0.01, "streamer", sides=4)
    # the stern ring
    ring_at(p, (0.0, HALF * -1 - 0.52, 0.8), (0.0, -1.0, 0.0))


def ring_at(p, c, facing):
    tor = []
    for k in range(9):
        a = 2 * math.pi * k / 8
        tor.append((0.075 + 0.016 * math.cos(a), 0.016 * math.sin(a)))
    ring = p.lathe(tor, "iron", segments=14, cap_bottom=False, cap_top=False)
    d = Vector(facing)
    p.move(ring, Matrix.Translation(Vector(c)) @ d.to_track_quat('Z', 'Y').to_matrix().to_4x4())
    p.box((c[0], c[1] - d.y * 0.05, c[2] + 0.07), (0.05, 0.12, 0.05), "iron", bevel=0.006)


def prow():
    """The prow: a tall post rising from the bow and curving forward into a
    stylised bird's head - a hooked beak, shell-inlaid eyes, a crest of
    plumes thrown back - with notches and shell diamonds down its front."""
    p = Part("prow", origin=(0.0, HALF + 0.3, 1.0), parent="war_canoe")
    y0 = HALF + 0.3
    post = [(0.0, y0, 0.85), (0.0, y0 + 0.1, 1.5), (0.0, y0 + 0.2, 2.0), (0.0, y0 + 0.4, 2.32)]
    b = limb(post, [0.13, 0.105, 0.09, 0.1], spacing=0.6, squash=0.8)
    b.append(blob((0.0, y0 + 0.47, 2.36), (0.1, 0.17, 0.12)))                       # head
    b += limb([(0.0, y0 + 0.6, 2.36), (0.0, y0 + 0.85, 2.3), (0.0, y0 + 0.97, 2.17), (0.0, y0 + 0.95, 2.09)],
              [0.065, 0.045, 0.025, 0.012], spacing=0.6, squash=0.85)                # hooked beak
    for k, (dy, dz) in enumerate(((-0.25, 0.25), (-0.32, 0.12), (-0.3, 0.38))):
        b += limb([(0.0, y0 + 0.35, 2.4), (0.0, y0 + 0.35 + dy, 2.4 + dz)], [0.05, 0.015], spacing=0.6, squash=0.4)
    me = sculpt.metaball_mesh(b, resolution=0.016)
    me = sculpt.decimate(me, 1400)
    clay.into_part(p, me, "figure")
    for sx in (-1, 1):
        disc = p.lathe([(0.0, 0.0), (0.04, 0.0), (0.045, 0.01), (0.03, 0.02), (0.0, 0.022)], "eye", segments=12,
                       cap_bottom=False, cap_top=False)
        p.move(disc, Matrix.Translation(Vector((sx * 0.085, y0 + 0.52, 2.39))) @
               Matrix.Rotation(math.radians(sx * 90.0), 4, 'Y'))
        K.sphere(p, (sx * 0.1, y0 + 0.52, 2.39), 0.013, "pupil", segments=8, rings=4, squash=(0.5, 1.0))
    # notches and shell diamonds down the front of the post
    for k in range(6):
        z = 1.95 - k * 0.17
        y = y0 + 0.07 + (z - 0.85) * 0.12
        p.box((0.0, y + 0.08, z), (0.12, 0.06, 0.06), "figure", bevel=0.012, rot=Matrix.Rotation(math.radians(45), 3, 'X'))
        if k % 2 == 0:
            p.box((0.0, y + 0.11, z - 0.085), (0.05, 0.02, 0.05), "eye", bevel=0.006,
                  rot=Matrix.Rotation(math.radians(45), 3, 'Y'))
    return p


def sling():
    p = Part("sling", origin=(0.0, 0.0, 2.6), parent="war_canoe")
    p.box((0.0, 0.0, 2.6), (0.16, 7.4, 0.18), "beam", bevel=0.02)
    for sy in (-1, 1):
        y = sy * 3.5
        for sx in (-1, 1):
            p.tube([(0.0, y, 2.52), (sx * half_width(y) * 0.95, y, sheer(y) + 0.02)], 0.022, "rope", sides=6)
        # the sling passes under the hull: a band round the gunwales
        p.box((0.0, y, 2.6), (0.26, 0.14, 0.26), "rope", bevel=0.02)
    p.box((0.0, 0.0, 2.73), (0.2, 0.2, 0.1), "iron", bevel=0.01)
    r = Part("rope_main", origin=(0.0, 0.0, 2.6), parent="sling")
    r.tube([(0.0, 0.0, 2.7), (0.0, 0.0, 3.65), (0.0, 0.0, 4.6)], 0.035, "rope", sides=8)
    return [p, r]


# --------------------------------------------------------------------------
# paint
# --------------------------------------------------------------------------

def hull_paint(ctx):
    """Dark hardwood, a tarred bottom, the washstrake band (the top 0.3 m)
    painted with red, black and white triangles between lines, a seam with
    lashing stitches under it."""
    s = AM.carved_wood(ctx, 2001, ramp="am_wood_dark", center=4.0, adze=0.7, oiled=0.3)
    z = ctx.p[:, 2]
    y = ctx.p[:, 1]
    zt = 0.92 + 0.38 * (np.abs(y) / HALF) ** 2.5
    below = zt - z
    tar = below > 0.62
    s.use_ramp(P["am_resin"], mask=tar, shade=np.full(ctx.N, 3.0) + ctx.fbm(6.0, 2, 2003) * 1.0 + _dither(ctx, 0.6, 2004))
    s.rough = np.where(tar, 0.5, s.rough)
    codes = np.zeros(ctx.N, np.int16)
    band = (below > 0.04) & (below < 0.3)
    cell = 0.2
    k = np.floor(y / cell).astype(np.int64)
    fy = y / cell - k
    vv = (below - 0.04) / 0.26
    tri = np.where(np.mod(k, 2) == 0, vv > np.abs(fy - 0.5) * 2.0, vv < 1.0 - np.abs(fy - 0.5) * 2.0)
    codes[band & tri] = AP.INK["red"]
    codes[band & ~tri] = AP.INK["black"]
    lines = (np.abs(below - 0.04) < 0.012) | (np.abs(below - 0.3) < 0.012)
    codes[lines] = AP.INK["white"]
    s = AM.paint_over(ctx, s, codes, 2005, flake=0.25, wear=0.6)
    seam = np.abs(below - 0.34) < 0.01
    stitch = (np.abs(below - 0.34) < 0.03) & (np.mod(y / 0.06, 1.0) < 0.3)
    s.shade[seam] -= 2.0
    s.use_ramp(P["am_rope"], mask=stitch, shade=np.full(ctx.N, 4.0))
    return s


def inside_paint(ctx):
    s = AM.carved_wood(ctx, 2007, ramp="am_wood_dark", center=3.4, adze=1.0, oiled=0.0)
    return s


def board_paint(ctx):
    s = AM.carved_wood(ctx, 2009, ramp="am_wood_dark", center=4.0, adze=0.4)
    x = ctx.p[:, 0]
    z = ctx.p[:, 2]
    cell = 0.1
    k = np.floor((x + 1.0) / cell).astype(np.int64)
    fx = (x + 1.0) / cell - k
    vv = (z - 0.89) / 0.32
    tri = vv > np.abs(fx - 0.5) * 2.0
    codes = np.where(tri, AP.INK["white"], AP.INK["red"]).astype(np.int16)
    return AM.paint_over(ctx, s, codes, 2011, flake=0.3)


def paua(ctx, seed=2045):
    s = AM.mosaic(ctx, seed, "am_turq_green", cell=0.02, center=4.6, mix=0.5, mix_ramp="am_blue", gap_texels=0.3)
    tilt = 1.0 - np.abs(ctx.n[:, 0])
    s.shade += np.sin(ctx.p[:, 2] * 160.0 + tilt * 6.0) * 0.9 + tilt * 1.2
    s.rough[:] = 0.15
    return s


def build():
    h = hull()
    outrigger(h)
    sternpost(h)
    ring_at(h, (0.0, HALF + 0.52, 0.72), (0.0, 1.0, 0.0))
    parts = [h, prow()] + sling()
    fns = {"hull": hull_paint, "inside": inside_paint, "gunwale": lambda c: AM.carved_wood(c, 2013, "am_wood", 3.8),
           "deck": lambda c: AM.carved_wood(c, 2015, "am_wood", 4.6, adze=0.3),
           "board": board_paint, "float": lambda c: AM.carved_wood(c, 2017, "am_wood_dark", 4.2),
           "boom": lambda c: AM.carved_wood(c, 2019, "am_wood", 4.4, adze=0.3),
           "lash": lambda c: AM.rope(c, 2021), "rope": lambda c: AM.rope(c, 2023, center=5.2),
           "paddle": lambda c: AM.carved_wood(c, 2025, "am_wood", 5.0, adze=0.2),
           "post": lambda c: AM.carved_wood(c, 2027, "am_wood_dark", 4.2, adze=0.8),
           "post_band": lambda c: AM.paint_over(c, AM.carved_wood(c, 2029, "am_wood_dark", 4.0),
                                                np.full(c.N, AP.INK["red"], np.int16), 2031, flake=0.3),
           "streamer": lambda c: AM.feathers(c, "am_feather_red", flow=(0.0, 0.0, -1.0), seed=2033, center=3.6),
           "iron": lambda c: AM.iron_old(c, 2035), "figure": lambda c: AM.carved_wood(c, 2037, "am_wood_dark", 4.6, adze=0.9),
           "eye": paua, "pupil": lambda c: AM.obsidian(c, 2041),
           "beam": lambda c: AM.carved_wood(c, 2043, "am_wood", 3.6, adze=0.2)}
    markers = [("hook_ring", (0.0, HALF + 0.52 + 0.02, 0.72), "war_canoe"),
               ("hook_ring_stern", (0.0, -HALF - 0.52, 0.8), "war_canoe"),
               ("deck", (0.0, 0.0, 0.5), "war_canoe"),
               ("bridge_bow", (0.0, 4.6, 0.0), "war_canoe"), ("bridge_stern", (0.0, -4.6, 0.0), "war_canoe"),
               ("rope_top", (0.0, 0.0, 4.6), "rope_main")]
    return kit("war_canoe", parts, fns, ppm=96, built_final=True, ground=None, ao_dist=0.35, organic=("prow",),
               markers=markers, preview_yaws=(-60.0, 30.0, 120.0, 210.0), preview_elevation=22.0,
               preview_extra=[("prow", (0.0, HALF + 0.5, 1.8), 1.0, 60.0, 8.0),
                              ("inside", (0.0, 0.0, 0.6), 2.5, 160.0, 35.0)])
