"""Floor I, the Pacific gallery and the Moai room: the whaling display (the
HARPOON's place), bark-cloth hangings, carved figures in a case.

  whaling_rack     wall rack 3.0 x 2.0 x 0.32 m for the whaling display: a
                   dark teak board in a frame, three toggle harpoons and a
                   lance on pegs, a cutting spade, a coil of manila line on
                   a peg, a brass label "WIELORYBNICTWO / XIX WIEK", and in
                   the middle an empty felt-lined cradle: marker
                   weapon_spot (0, 0.62, -0.17) = where the harpoon gun
                   lies (its bore along X). Wall piece: origin on the wall
                   plane at the middle of the bottom edge, the rack toward
                   -Z. 128 px/m.
  harpoon_stand    the display stand for the harpoon gun in the room: a
                   teak post on a stepped base, a padded fork on top, a
                   brass label "HARPUNNIK / 1890"; marker weapon_spot
                   (0, 1.06, 0) on the fork, the gun along X. 0.7 x 1.0 x
                   0.5 m. 160 px/m.
  tapa_hanging     a bark-cloth hanging 2.0 x 3.0 m on a carved pole hung
                   from two cords; the cloth falls in soft folds. Texture
                   sets tapa_hanging_b, tapa_hanging_c (other prints).
                   Origin = the pole's middle on the wall plane (it hangs
                   down from there), the cloth toward -Z. 128 px/m.
  pacific_figures  a tall case 1.0 x 1.8 x 1.0 m with two carved wooden
                   figures on black stands: a slender ancestor figure with
                   ribs, a hooked nose and shell eyes, and a squat figure
                   with a great head; part pacific_figures_glass. 256 px/m
                   for the figures (the case 160).
"""
import math

import numpy as np
from mathutils import Matrix, Vector

from artlib import clay
from artlib import americas as AM
from artlib import americas_paint as AP
from artlib import kit as K
from artlib import materials as M
from artlib import pixelfont
from artlib import sculpt
from artlib.archkit import cull_floor, kit
from artlib.geo import Part
from artlib.materials import P, _dither, _select
from artlib.sculpt import blob, limb

_TXT = {}


def plaque(lines, seed=2401):
    def fn(ctx):
        s = M.brass(ctx, seed)
        front = ctx.n[:, 1] > 0.5
        key = tuple(lines)
        if key not in _TXT:
            _TXT[key] = pixelfont.trim(pixelfont.render(list(lines), line_gap=2))
        if front.any():
            u, v = ctx.uvm[:, 0], ctx.uvm[:, 1]
            ink = pixelfont.stamp(ctx, _TXT[key], np.median(u[front]), np.median(v[front]), scale=1) & front
            s.use_ramp(P["am_obsidian"], mask=ink, shade=np.full(ctx.N, 1.0))
            s.metal = np.where(ink, 0.0, s.metal)
        return s
    return fn


# --------------------------------------------------------------------------
# whaling display
# --------------------------------------------------------------------------

def harpoon(p, y, z, x0, x1, kind="toggle"):
    """A whaling iron lying along X at height z, depth y (toward -Y)."""
    p.tube([(x0, y, z), (x1 - 0.5, y, z)], 0.03, "shaft", sides=8)
    p.tube([(x1 - 0.52, y, z), (x1 - 0.1, y, z)], 0.014, "iron", sides=6)
    if kind == "toggle":
        p.box((x1 - 0.05, y, z), (0.16, 0.022, 0.045), "iron", bevel=0.005)
        K.cone(p, (x1 + 0.03, y, z), (1.0, 0.0, 0.0), 0.09, 0.024, "iron", segments=4, tip=0.002)
    elif kind == "lance":
        lead = p.lathe([(0.0, 0.0), (0.03, 0.03), (0.024, 0.13), (0.0, 0.17)], "iron", segments=4, squash=(1.0, 0.3))
        p.move(lead, Matrix.Translation(Vector((x1 - 0.1, y, z))) @ Matrix.Rotation(math.radians(-90), 4, 'Y'))
    else:   # cutting spade
        p.box((x1 - 0.02, y, z), (0.14, 0.012, 0.11), "iron", bevel=0.004)
    p.box((x0 + 0.25, y, z), (0.06, 0.03, 0.03), "rope", bevel=0.006)


def whaling_rack():
    p = Part("whaling_rack")
    # built facing -Y (kit() turns it), wall plane y = 0, bottom edge z = 0
    p.box((0.0, -0.02, 1.0), (3.0, 0.04, 2.0), "board", bevel=0.01)
    for z in (0.04, 1.96):
        p.box((0.0, -0.05, z), (3.04, 0.06, 0.08), "frame", bevel=0.012)
    for x in (-1.48, 1.48):
        p.box((x, -0.05, 1.0), (0.08, 0.06, 2.0), "frame", bevel=0.012)
    # pegs in pairs for the irons
    rows = [(1.7, "toggle"), (1.48, "toggle"), (1.26, "lance"), (0.3, "spade")]
    for z, kind in rows:
        for x in (-1.0, 0.9):
            p.tube([(x, -0.04, z - 0.03), (x, -0.13, z - 0.03)], 0.016, "frame", sides=6)
        harpoon(p, -0.1, z, -1.3, 1.35, kind)
    # the empty cradle for the harpoon gun (two forked rests, felt lined)
    for x in (-0.38, 0.38):
        p.box((x, -0.1, 0.56), (0.07, 0.14, 0.05), "frame", bevel=0.008)
        for dy in (-0.05, 0.05):
            p.box((x, -0.1 + dy, 0.61), (0.06, 0.02, 0.07), "frame", bevel=0.006)
        p.box((x, -0.1, 0.59), (0.06, 0.08, 0.012), "felt")
    # the coil of line on its peg (right) and a lantern hook (left)
    p.tube([(1.15, -0.04, 0.95), (1.15, -0.2, 0.95)], 0.02, "frame", sides=6)
    for k in range(5):
        r = 0.2 - k * 0.012
        pts = [(1.15 + r * math.sin(a), -0.12 - 0.012 * k, 0.8 + r * math.cos(a)) for a in np.linspace(0, 2 * math.pi, 13)]
        p.tube(pts, 0.016, "rope", sides=6, caps=False)
    p.box((0.0, -0.045, 0.98), (0.6, 0.012, 0.14), "plaque", bevel=0.003)
    return p


def harpoon_stand():
    p = Part("harpoon_stand")
    p.box((0.0, 0.0, 0.05), (0.7, 0.5, 0.1), "base", bevel=0.012)
    p.box((0.0, 0.0, 0.13), (0.56, 0.38, 0.06), "base", bevel=0.01)
    p.lathe([(0.07, 0.16), (0.06, 0.25), (0.055, 0.8), (0.065, 0.9), (0.05, 0.95)], "post", segments=10,
            cap_bottom=False, cap_top=True)
    # the padded fork: two arms holding the gun along X
    for sx in (-1, 1):
        p.tube([(0.0, 0.0, 0.93), (sx * 0.16, 0.0, 0.98), (sx * 0.2, 0.0, 1.05)], 0.022, "post", sides=8)
        p.box((sx * 0.2, 0.0, 1.03), (0.05, 0.09, 0.03), "felt", bevel=0.006)
    p.box((0.0, -0.195, 0.13), (0.3, 0.012, 0.05), "plaque", bevel=0.002)
    cull_floor([p])
    return p


# --------------------------------------------------------------------------
# bark cloth
# --------------------------------------------------------------------------

def tapa_hanging():
    p = Part("tapa_hanging")
    W, H = 2.0, 3.0
    # the cloth, built facing -Y: a grid with soft vertical folds
    nx, nz = 24, 30
    verts = []
    for j in range(nz + 1):
        z = -0.08 - H * j / nz
        row = []
        for i in range(nx + 1):
            x = -W / 2 + W * i / nx
            fold = 0.04 * math.sin(i / nx * math.pi * 5.0) * (0.4 + 0.6 * j / nz)
            row.append(p.bm.verts.new((x, -0.12 - fold, z)))
        verts.append(row)
    front = []
    for j in range(nz):
        for i in range(nx):
            f = p._face([verts[j][i], verts[j][i + 1], verts[j + 1][i + 1], verts[j + 1][i]], "cloth", smooth=True)
            f.normal_update()
            if f.normal.y > 0:
                f.normal_flip()
            for loop in f.loops:
                vx = loop.vert.co
                loop[p.uv].uv = (vx.x + W / 2, vx.z + H + 0.08)
            f[p.lock] = 1
            front.append(f)
    # the carved pole and its cords
    p.tube([(-W / 2 - 0.12, -0.12, -0.05), (W / 2 + 0.12, -0.12, -0.05)], 0.035, "pole", sides=8)
    for sx in (-1, 1):
        p.lathe([(0.0, 0.0), (0.05, 0.0), (0.05, 0.04), (0.0, 0.09)], "pole", segments=8,
                center=(sx * (W / 2 + 0.15), -0.12, -0.05))
        p.tube([(sx * (W / 2 - 0.1), -0.12, -0.05), (sx * 0.3, -0.04, 0.6), (0.0, -0.01, 0.75)], 0.008, "cord",
               sides=5)
    return p


def tapa_paint(variant):
    def fn(ctx):
        return AM.tapa(ctx, 2411 + variant * 7, variant=variant, scale=1)
    return fn


# --------------------------------------------------------------------------
# carved figures in a case
# --------------------------------------------------------------------------

def slender_figure(c):
    """A slender ancestor figure about 0.62 m: big head with a hooked nose,
    a goatee, prominent ribs, arms at the sides, bent knees."""
    x, y, z = c
    b = [blob((x, y, z + 0.53), (0.055, 0.06, 0.07)),            # head
         blob((x, y + 0.055, z + 0.52), (0.014, 0.03, 0.03)),     # hooked nose
         blob((x, y + 0.05, z + 0.48), (0.02, 0.015, 0.025)),     # goatee
         blob((x, y, z + 0.46), (0.025, 0.025, 0.03)),            # neck
         blob((x, y, z + 0.38), (0.045, 0.035, 0.065)),           # rib cage
         blob((x, y + 0.012, z + 0.3), (0.03, 0.025, 0.04)),      # sunken belly
         blob((x, y, z + 0.25), (0.04, 0.03, 0.03))]              # hips
    for k in range(4):
        b.append(blob((x, y + 0.03, z + 0.35 + k * 0.022), (0.045, 0.012, 0.006)))   # ribs
    for sx in (-1, 1):
        b.append(blob((x + sx * 0.05, y, z + 0.55), (0.012, 0.02, 0.035)))           # ears
        b += limb([(x + sx * 0.05, y, z + 0.43), (x + sx * 0.06, y + 0.01, z + 0.33), (x + sx * 0.05, y + 0.02, z + 0.24)],
                  [0.014, 0.012, 0.013], spacing=0.6)
        b += limb([(x + sx * 0.025, y, z + 0.24), (x + sx * 0.03, y + 0.03, z + 0.13), (x + sx * 0.028, y, z + 0.02)],
                  [0.018, 0.014, 0.014], spacing=0.6)
    return b


def squat_figure(c):
    """A squat figure with a great head, arms on the belly, short legs."""
    x, y, z = c
    b = [blob((x, y, z + 0.3), (0.085, 0.07, 0.09)),             # head
         blob((x, y + 0.06, z + 0.29), (0.025, 0.025, 0.035)),    # nose
         blob((x, y + 0.05, z + 0.24), (0.05, 0.02, 0.015)),      # lips
         blob((x, y, z + 0.15), (0.07, 0.055, 0.08))]             # body
    for sx in (-1, 1):
        b += limb([(x + sx * 0.07, y, z + 0.2), (x + sx * 0.08, y + 0.03, z + 0.13), (x + sx * 0.02, y + 0.06, z + 0.12)],
                  [0.02, 0.018, 0.018], spacing=0.6)
        b += limb([(x + sx * 0.04, y, z + 0.08), (x + sx * 0.06, y + 0.03, z + 0.04), (x + sx * 0.045, y + 0.02, z)],
                  [0.026, 0.024, 0.022], spacing=0.6)
    return b


def build_figures():
    from models.americas_exhibits import vitrine, CASE_FNS
    parts = vitrine("pacific_figures", 1.0, 1.0, 0.85, 1.8)
    case = parts[0]
    fig = Part("pacific_figures_pieces")
    for blobs, at, tris in ((slender_figure((0.0, 0.0, 0.0)), (-0.2, 0.05, 0.92), 1600),
                            (squat_figure((0.0, 0.0, 0.0)), (0.22, -0.05, 0.92), 900)):
        me = sculpt.metaball_mesh(blobs, resolution=0.004)
        zmin = min(v.co.z for v in me.vertices)
        sculpt.cut(me, [((0.0, 0.0, zmin + 0.006), (0.0, 0.0, -1.0))])
        me = sculpt.decimate(me, tris)
        # turned to face the room (-Y before kit() turns the case)
        m = Matrix.Translation(Vector((at[0], at[1], at[2] - zmin - 0.006))) @ Matrix.Rotation(math.pi, 4, 'Z')
        clay.into_part(fig, me, "figure", transform=m)
    # shell eyes
    for (x, y, z), r in (((-0.2 - 0.022, 0.05 - 0.05, 0.92 + 0.535), 0.011), ((-0.2 + 0.022, 0.05 - 0.05, 0.92 + 0.535), 0.011),
                         ((0.22 - 0.035, -0.05 - 0.062, 0.92 + 0.31), 0.016), ((0.22 + 0.035, -0.05 - 0.062, 0.92 + 0.31), 0.016)):
        K.sphere(fig, (x, y + r * 0.3, z), r, "eye", segments=10, rings=5, squash=(1.0, 0.3), zscale=0.8)
        K.sphere(fig, (x, y + r * 0.05, z), r * 0.72, "pupil", segments=10, rings=4, squash=(1.0, 0.3), zscale=0.8)
    for x in (-0.2, 0.22):
        case.box((x, 0.0, 0.88), (0.18, 0.18, 0.06), "stand", bevel=0.006)
    fns = {**CASE_FNS, "plaque": plaque(["RZEŹBY PRZODKÓW", "OCEANIA"]), "stand": CASE_FNS["cabinet"],
           "figure": lambda c: AM.carved_wood(c, 2421, "am_wood_dark", 4.8, adze=0.9, oiled=0.6),
           "eye": lambda c: AM.shell(c, 2423), "pupil": lambda c: AM.obsidian(c, 2425)}
    return kit("pacific_figures", parts + [fig], fns, kinds={"glass": "glass"}, ppm=160, ground=0.0, ao_dist=0.12,
               organic=("pacific_figures_pieces",), preview_extra=[("figures", (0.0, 0.0, 1.2), 0.45, 0.0, 6.0)])


def build():
    out = []
    out.append(kit("whaling_rack", [whaling_rack()],
                   {"board": lambda c: AM.carved_wood(c, 2431, "am_wood_dark", 3.6, adze=0.2, oiled=0.6),
                    "frame": lambda c: AM.carved_wood(c, 2433, "am_wood", 4.2, adze=0.3, oiled=0.6),
                    "shaft": lambda c: AM.carved_wood(c, 2435, "am_wood", 5.0, adze=0.1),
                    "iron": lambda c: AM.iron_old(c, 2437), "rope": lambda c: AM.rope(c, 2439, center=5.4),
                    "felt": lambda c: M.velvet(c, 2441), "plaque": plaque(["WIELORYBNICTWO", "XIX WIEK"])},
                   ppm=128, wall=True, ground=None, ao_dist=0.2,
                   markers=[("weapon_spot", (0.0, -0.17, 0.62), None)],
                   preview_yaws=(-20.0, 0.0, 20.0, 50.0), preview_elevation=4.0))
    out.append(kit("harpoon_stand", [harpoon_stand()],
                   {"base": lambda c: AM.carved_wood(c, 2443, "am_wood_dark", 3.4, adze=0.1, oiled=0.7),
                    "post": lambda c: AM.carved_wood(c, 2445, "am_wood", 4.4, adze=0.1, oiled=0.7),
                    "felt": lambda c: M.velvet(c, 2447), "plaque": plaque(["HARPUNNIK", "1890"])},
                   ppm=160, ground=0.0, ao_dist=0.15, markers=[("weapon_spot", (0.0, 0.0, 1.06), None)]))
    tp = kit("tapa_hanging", [tapa_hanging()],
             {"cloth": tapa_paint(0), "pole": lambda c: AM.carved_wood(c, 2451, "am_wood_dark", 4.4),
              "cord": lambda c: AM.rope(c, 2453)},
             ppm=128, wall=True, ground=None, ao_dist=0.2, preview_yaws=(-20.0, 0.0, 20.0, 160.0), preview_elevation=4.0)
    tp.variants = {"tapa_hanging_b": {**tp.fns, "cloth": tapa_paint(1)},
                   "tapa_hanging_c": {**tp.fns, "cloth": tapa_paint(2)}}
    out.append(tp)
    out.append(build_figures())
    return out
