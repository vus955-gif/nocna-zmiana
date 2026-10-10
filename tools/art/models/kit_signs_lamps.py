"""Lobby kit: signage with real Polish words, and the light fixtures.

Fixtures follow LevelKit's light convention: the origin is where the light
itself sits (put the Light3D there), the mount runs back along +Z (toward
the wall) or up. Everything else: origin = back centre on the wall plane.

  exit_sign       lit green "WYJŚCIE" box with a running man, a red
                  emergency lamp under it, bracket back 0.12 m to the wall
                  (kit id exit_sign; LevelLighting hangs it 0.12 m out).
  emergency_lamp  red emergency lamp on a 0.2 m bracket (kit id).
  sign_room       black glass plaque in a brass frame, gold letters, 2.0 x
                  0.32 m: texture sets sign_room (GALERIA RZEŹBY),
                  sign_room_zbrojownia (ZBROJOWNIA), sign_room_diorama
                  (DIORAMA PRZYRODY), sign_room_hol (HOL GŁÓWNY),
                  sign_room_personel (TYLKO DLA PERSONELU).
  sign_staff      small white enamel plate "TYLKO DLA PERSONELU" in red for
                  staff doors, 0.5 x 0.12 m.
  column_lamp     opal globe on a curved brass bracket, 0.62 m back to the
                  column face (the hall's column lamps).
  ceiling_lamp    pendant: opal bowl in a brass gallery on a 0.9 m stem.
  chandelier      two-tier brass chandelier, 16 candle bulbs, glass drops,
                  1.9 m across, chain 2 m up to a ceiling rose.
  tube_lamp       fluorescent batten 1.3 m, two tubes behind an opal
                  diffuser, hung 0.2 m under the ceiling.
  bulb            bare bulb in a porcelain batten holder on a 0.3 m flex.
  desk_lamp       green-glass banker's lamp (light inside the shade; base
                  0.37 m below).
"""
import math

import numpy as np
from mathutils import Matrix

from artlib import arch_materials as A
from artlib import font
from artlib import materials as M
from artlib.archkit import kit
from artlib.geo import Part
from artlib.painter import Surface

A.P.setdefault("lamp_cool", A.hexramp("#44524e", "#6a7c77", "#93a8a2", "#bdd0ca", "#dcebe6", "#f2fbf8"))

# running man pictogram, 12 x 15 px ('#' = white), facing left toward the text
MAN = [
    "......##....",
    ".....###....",
    ".....##.....",
    "...#####....",
    "..###.###...",
    ".##.#####.#.",
    "##..####.##.",
    "....###.....",
    "...#####....",
    "..##...##...",
    ".##.....##..",
    ".#.......##.",
    "##........#.",
    "#.........##",
    "............",
]


def _man_mask(u, v, left, top, px):
    bmp = np.array([[c == "#" for c in r] for r in MAN], dtype=bool)[:, ::-1]
    col = np.floor((u - left) / px + 1e-6).astype(np.int64)
    row = np.floor((top - v) / px + 1e-6).astype(np.int64)
    ok = (col >= 0) & (col < bmp.shape[1]) & (row >= 0) & (row < bmp.shape[0])
    out = np.zeros(len(u), dtype=bool)
    out[ok] = bmp[row[ok], col[ok]]
    return out


def _exit_face(ctx):
    u, v = ctx.uvm[:, 0], ctx.uvm[:, 1]
    tx = ctx.texel
    s = Surface(ctx.N)
    s.use_ramp(A.P["sign_green"], shade=4.6 + ctx.fbm(12.0, 2, 3) * 0.3 + (ctx.rand(4) - 0.5) * 0.4)
    px = 3 * tx
    ink = font.text_mask(u, v, "WYJŚCIE", 0.045, 0.08, px, align="center")
    ink |= _man_mask(u, v, -0.2, 0.145, px)
    # white border line inset from the edge
    frame = ((np.abs(np.abs(u) - 0.205) < tx) & (np.abs(v - 0.1) < 0.085)) | \
            ((np.abs(np.abs(v - 0.1) - 0.085) < tx) & (np.abs(u) < 0.205))
    ink |= frame
    s.use_ramp(A.P["sign_white"], mask=ink, shade=np.full(ctx.N, 3.6))
    s.rough = np.full(ctx.N, 0.25)
    s.emit = s.colors() * 1.0
    return s


def exit_sign():
    p = Part("exit_sign")
    # light box (face at y = -0.04), bracket back to the wall at y = +0.12
    p.box((0, 0.0, 0.1), (0.44, 0.08, 0.2), "housing", bevel=0.008)
    p.box((0, -0.041, 0.1), (0.42, 0.004, 0.18), "face")
    p.box((0, 0.08, 0.1), (0.3, 0.08, 0.04), "housing", bevel=0.006)
    p.box((0, 0.117, 0.1), (0.34, 0.006, 0.24), "housing", bevel=0.003)
    # red emergency lamp below it
    p.box((0, 0.02, -0.06), (0.16, 0.1, 0.08), "housing", bevel=0.01)
    p.box((0, -0.035, -0.06), (0.13, 0.012, 0.055), "lamp_red", bevel=0.004)
    return p


def emergency_lamp():
    p = Part("emergency_lamp")
    p.box((0, 0.195, 0), (0.12, 0.01, 0.2), "iron", bevel=0.004)          # wall plate at +0.2
    p.box((0, 0.13, 0), (0.05, 0.12, 0.05), "iron", bevel=0.008)          # bracket
    p.box((0, 0.03, 0), (0.3, 0.1, 0.14), "iron", bevel=0.012)            # housing
    p.box((0, -0.025, 0), (0.24, 0.02, 0.09), "lamp_red", bevel=0.006)    # lens
    for x in (-0.08, -0.04, 0.0, 0.04, 0.08):
        p.box((x, -0.037, 0), (0.008, 0.008, 0.09), "lamp_red", bevel=0.002)
    for z in (-0.05, 0.05):
        p.box((0, -0.05, z), (0.27, 0.008, 0.008), "iron", bevel=0.002)
    return p


SIGNS = {
    "sign_room": "GALERIA RZEŹBY",
    "sign_room_zbrojownia": "ZBROJOWNIA",
    "sign_room_diorama": "DIORAMA PRZYRODY",
    "sign_room_hol": "HOL GŁÓWNY",
    "sign_room_personel": "TYLKO DLA PERSONELU",
}


def _room_sign(text):
    def fn(ctx):
        u, v = ctx.uvm[:, 0], ctx.uvm[:, 1]
        s = Surface(ctx.N)
        s.use_ramp(A.P["leather"], shade=1.0 + ctx.fbm(8.0, 2, 5) * 0.3)
        px = 2 * ctx.texel
        ink = font.text_mask(u, v, text, 0.0, -0.055, px, align="center")
        s.use_ramp(A.P["gold"], mask=ink, shade=np.full(ctx.N, 7.2) + (ctx.rand(6) - 0.5) * 0.8)
        s.metal = np.where(ink, 1.0, 0.0)
        s.rough = np.where(ink, 0.25, 0.1)
        return s
    return fn


def sign_room():
    p = Part("sign_room")
    p.box((0, -0.015, 0), (2.0, 0.03, 0.32), "brass", bevel=0.01)
    p.box((0, -0.031, 0), (1.92, 0.004, 0.25), "field")
    return p


def _staff_plate(ctx, v0=0.0):
    """White enamel plate centred at (0, v0) in the face's metre UVs."""
    u, v = ctx.uvm[:, 0], ctx.uvm[:, 1] - v0
    s = Surface(ctx.N)
    s.use_ramp(A.P["enamel_white"], shade=6.4 + ctx.fbm(10.0, 2, 3) * 0.3)
    px = 2 * ctx.texel
    ink = font.text_mask(u, v, "TYLKO DLA PERSONELU", 0.0, -0.013, px, align="center")
    tx = ctx.texel
    frame = ((np.abs(np.abs(u) - 0.235) < tx) & (np.abs(v) < 0.05)) | ((np.abs(np.abs(v) - 0.05) < tx) & (np.abs(u) < 0.235))
    s.use_ramp(A.P["enamel_red"], mask=ink | frame, shade=np.full(ctx.N, 5.0))
    chip = (ctx.edge_soft(2.0) > 0.3) & (ctx.fbm(20.0, 2, 7) > 0.4)
    s.use_ramp(A.P["iron"], mask=chip, shade=np.full(ctx.N, 2.0))
    s.rough = np.full(ctx.N, 0.2)
    return s


def sign_staff():
    p = Part("sign_staff")
    p.box((0, -0.003, 0), (0.5, 0.006, 0.12), "plate", bevel=0.003)
    return p


# --- lamps -------------------------------------------------------------------------

def _column_lamp_rose(p):
    faces = p.lathe([(0.0, 0.0), (0.12, 0.0), (0.12, 0.02), (0.08, 0.035), (0.03, 0.05), (0.0, 0.05)], "brass",
                    segments=12)
    # wall rose against the column face (+Y before the turn), facing the lamp
    p.move(faces, Matrix.Translation((0.0, 0.62, -0.08)) @ Matrix.Rotation(math.radians(90), 4, 'X'))


def column_lamp_part():
    p = Part("column_lamp")
    p.lathe([(0.0, -0.2), (0.09, -0.18), (0.16, -0.12), (0.2, -0.02), (0.19, 0.08), (0.14, 0.15), (0.07, 0.19),
             (0.0, 0.2)], "lamp_warm", segments=16)
    p.lathe([(0.0, -0.28), (0.08, -0.26), (0.11, -0.22), (0.1, -0.19), (0.06, -0.18)], "brass", segments=12,
            cap_bottom=False, cap_top=False)
    pts = [(0.0, 0.0, -0.28), (0.0, 0.04, -0.38), (0.0, 0.16, -0.44), (0.0, 0.32, -0.42), (0.0, 0.46, -0.32),
           (0.0, 0.62, -0.1)]
    p.tube(pts, 0.022, "brass", sides=8)
    p.tube([(0.0, 0.2, -0.43), (0.0, 0.3, -0.24), (0.0, 0.45, -0.1), (0.0, 0.62, -0.02)], 0.013, "brass", sides=6)
    _column_lamp_rose(p)
    return p


def ceiling_lamp():
    p = Part("ceiling_lamp")
    p.lathe([(0.0, -0.12), (0.12, -0.11), (0.24, -0.07), (0.3, 0.0), (0.31, 0.03), (0.0, 0.03)], "lamp_warm",
            segments=16, cap_bottom=False)
    p.lathe([(0.3, -0.005), (0.33, 0.0), (0.34, 0.03), (0.32, 0.06), (0.3, 0.06)], "brass", segments=16,
            cap_bottom=False, cap_top=False)
    for k in range(3):
        a = math.tau * k / 3
        p.tube([(0.31 * math.cos(a), 0.31 * math.sin(a), 0.05), (0.05 * math.cos(a), 0.05 * math.sin(a), 0.3)],
               0.008, "brass", sides=5)
    p.lathe([(0.0, 0.28), (0.06, 0.28), (0.06, 0.33), (0.015, 0.36), (0.015, 0.84), (0.1, 0.86), (0.12, 0.9),
             (0.0, 0.9)], "brass", segments=10, cap_bottom=True)
    return p


def chandelier():
    p = Part("chandelier")
    # central baluster column and bowl
    p.lathe([(0.0, -0.55), (0.05, -0.54), (0.09, -0.46), (0.07, -0.38), (0.12, -0.3), (0.16, -0.18),
             (0.12, -0.1), (0.05, -0.05), (0.06, 0.1), (0.1, 0.2), (0.08, 0.3), (0.04, 0.38), (0.05, 0.5),
             (0.03, 0.56), (0.0, 0.56)], "brass", segments=12)
    # chain up to the ceiling rose (2 m)
    for k in range(12):
        z = 0.6 + k * 0.12
        link = p.box((0.0, 0.0, z), (0.05 if k % 2 else 0.012, 0.012 if k % 2 else 0.05, 0.1), "brass",
                     bevel=0.004)
    p.lathe([(0.0, 2.0), (0.2, 2.0), (0.2, 2.03), (0.12, 2.06), (0.0, 2.07)], "brass", segments=12)
    # two tiers of S-arms with candle cups and candle bulbs
    for tier, (r, z, n) in enumerate(((0.92, -0.05, 10), (0.55, 0.3, 6))):
        for k in range(n):
            a = math.tau * (k + 0.5 * tier) / n
            c, s_ = math.cos(a), math.sin(a)
            pts = []
            for t in np.linspace(0.0, 1.0, 7):
                rr = 0.12 + (r - 0.12) * t
                zz = z - 0.2 * math.sin(t * math.pi) * (1.0 - t * 0.3) + 0.1 * t
                pts.append((rr * c, rr * s_, zz - 0.15))
            p.tube(pts, 0.016, "brass", sides=6)
            cx, cy, cz = r * c, r * s_, z - 0.05
            p.lathe([(0.0, -0.06), (0.05, -0.05), (0.07, -0.01), (0.075, 0.0), (0.03, 0.01)], "brass", segments=8,
                    center=(cx, cy, cz))
            p.lathe([(0.02, 0.0), (0.02, 0.1)], "candle", segments=6, center=(cx, cy, cz), cap_bottom=False)
            p.lathe([(0.0, 0.1), (0.025, 0.12), (0.03, 0.15), (0.015, 0.19), (0.0, 0.2)], "lamp_warm", segments=8,
                    center=(cx, cy, cz))
            # a glass drop under each cup
            p.lathe([(0.0, -0.18), (0.025, -0.14), (0.02, -0.1), (0.0, -0.08)], "crystal_glass", segments=6,
                    center=(cx, cy, cz))
    # crown ring of leaves
    for k in range(8):
        a = math.tau * k / 8
        leaf = p.box((0, 0, 0), (0.06, 0.02, 0.14), "brass", bevel=0.008)
        p.move(leaf, Matrix.Translation((0.13 * math.cos(a), 0.13 * math.sin(a), 0.55)) @ Matrix.Rotation(a, 4, 'Z')
               @ Matrix.Rotation(math.radians(-20), 4, 'X'))
    return p


def tube_lamp():
    p = Part("tube_lamp")
    p.box((0, 0, 0.05), (1.34, 0.2, 0.06), "housing", bevel=0.008)
    p.box((0, 0, 0.012), (1.3, 0.16, 0.024), "diffuser", bevel=0.01)
    for x in (-0.6, 0.6):
        p.lathe([(0.004, 0.0), (0.004, 0.12)], "iron", segments=5, center=(x, 0.0, 0.08), cap_bottom=False)
        p.lathe([(0.0, 0.2), (0.025, 0.2), (0.02, 0.19), (0.0, 0.19)], "iron", segments=8, center=(x, 0.0, 0.0))
    for x in (-0.66, 0.66):
        p.box((x, 0, 0.03), (0.02, 0.18, 0.04), "housing", bevel=0.004)
    return p


def bulb():
    p = Part("bulb")
    p.lathe([(0.0, -0.075), (0.03, -0.068), (0.048, -0.04), (0.05, -0.015), (0.04, 0.01), (0.02, 0.03),
             (0.018, 0.045), (0.0, 0.045)], "bulb_glass", segments=10)
    p.lathe([(0.018, 0.04), (0.02, 0.06), (0.02, 0.1), (0.012, 0.11)], "porcelain", segments=8, cap_bottom=False)
    p.lathe([(0.004, 0.1), (0.004, 0.32)], "leather", segments=4, cap_bottom=False)
    p.lathe([(0.0, 0.3), (0.05, 0.3), (0.05, 0.32), (0.0, 0.33)], "porcelain", segments=10)
    return p


def desk_lamp():
    p = Part("desk_lamp")
    p.lathe([(0.0, -0.37), (0.09, -0.37), (0.09, -0.35), (0.06, -0.33), (0.0, -0.32)], "brass", segments=12,
            center=(0.0, 0.06, 0.0))
    p.lathe([(0.012, -0.33), (0.012, -0.03)], "brass", segments=6, center=(0.0, 0.06, 0.0), cap_bottom=False)
    p.box((0.0, 0.03, -0.03), (0.02, 0.06, 0.02), "brass", bevel=0.004)
    shade = p.lathe([(0.0, -0.18), (0.05, -0.17), (0.07, -0.08), (0.075, 0.08), (0.07, 0.17), (0.0, 0.18)], "shade",
                    segments=12, squash=(1.0, 0.55))
    p.move(shade, Matrix.Rotation(math.radians(90), 4, 'Y'))
    glow = p.lathe([(0.0, -0.1), (0.015, -0.1), (0.015, 0.1), (0.0, 0.1)], "lamp_warm", segments=6)
    p.move(glow, Matrix.Translation((0.0, 0.0, -0.03)) @ Matrix.Rotation(math.radians(90), 4, 'Y'))
    return p


def build():
    out = [kit("exit_sign", [exit_sign()], {"housing": lambda c: A.paint(c, "paint_grey", 5.5, rough=0.4),
                                             "face": _exit_face, "lamp_red": M.lamp_red}, ppm=512, ground=None,
               planes=(("y", -0.12),), ao_dist=0.05),
           kit("emergency_lamp", [emergency_lamp()], {"iron": M.iron, "lamp_red": M.lamp_red}, ppm=256, ground=None,
               planes=(("y", -0.2),), ao_dist=0.08)]
    base = kit("sign_room", [sign_room()], {"brass": M.brass, "field": _room_sign(SIGNS["sign_room"])}, ppm=128,
               ground=None, wall=True, ao_dist=0.05,
               variants={k: {"brass": M.brass, "field": _room_sign(v)} for k, v in SIGNS.items() if k != "sign_room"})
    out.append(base)
    out.append(kit("sign_staff", [sign_staff()], {"plate": _staff_plate}, ppm=512, ground=None, wall=True,
                   ao_rays=0, preview=False))
    out.append(kit("column_lamp", [column_lamp_part()], {"brass": M.brass, "lamp_warm": M.lamp_warm}, ppm=256,
                   ground=None, ao_dist=0.1))
    out.append(kit("ceiling_lamp", [ceiling_lamp()], {"brass": M.brass, "lamp_warm": M.lamp_warm}, ppm=256,
                   ground=None, ao_dist=0.1, preview=False))
    out.append(kit("chandelier", [chandelier()], {"brass": M.brass, "lamp_warm": M.lamp_warm,
                                                   "candle": M.porcelain,
                                                   "crystal_glass": lambda c: A.sign_text(c, [], ground="glass",
                                                                                           ground_center=3.0,
                                                                                           border=False)},
                   ppm=192, ground=None, ao_dist=0.12))
    out.append(kit("tube_lamp", [tube_lamp()], {"housing": lambda c: A.paint(c, "enamel_white", 5.5, rough=0.35),
                                                 "diffuser": lambda c: M.glow(c, "lamp_cool", 4.0, strength=1.0),
                                                 "iron": M.iron}, ppm=256, ground=None, ao_dist=0.08,
                   preview=False))
    out.append(kit("bulb", [bulb()], {"bulb_glass": M.lamp_warm, "porcelain": M.porcelain, "leather": M.leather},
                   ppm=512, ground=None, ao_rays=0, preview=False))
    out.append(kit("desk_lamp", [desk_lamp()], {"brass": M.brass, "shade": lambda c: A.paint(c, "enamel_green", 5.0,
                                                                                            rough=0.15, chip=0.3),
                                                 "lamp_warm": M.lamp_warm}, ppm=256, ground=None, ao_dist=0.08,
                   preview=False))
    return out
