"""Floor I: wayfinding in the Great Court, in the colours of the wings
(real Polish words, the 5 x 7 pixel font).

  sign_wing          freestanding two-sided direction post (1.0 x 2.6 m):
                     cast-iron frame, enamel panel with the wing's colour
                     band, its name, a pixel pictogram and an arrow
                     (straight on). Texture sets (KIT_SETS): sign_wing =
                     EGIPT (sand), sign_wing_asyria = ASYRIA (slate blue),
                     sign_wing_greece = GRECJA (white and blue),
                     sign_wing_enlight = OŚWIECENIE (green and brass),
                     sign_wing_asia = AZJA (lacquer red),
                     sign_wing_americas = AMERYKI I OCEANIA (turquoise).
  sign_wing_portal   the plaque over a wing's doorway, 3.2 x 0.6 m, on the
                     wall plane (z = 0, projects 0.06 to -Z), origin at the
                     middle of its bottom edge; the same six texture sets
                     (sign_wing_portal, sign_wing_portal_asyria, ...).
  court_map_board    "PLAN MUZEUM · PIĘTRO I": the floor plan on a lectern
                     stand (1.7 x 1.9 m), every zone in its wing colour, the
                     court and the drum in the middle, a red "TU JESTEŚ".
"""
import numpy as np

from artlib import court_materials as CM
from artlib import font
from artlib import materials as M
from artlib.archkit import kit
from artlib.geo import Part
from artlib.painter import Surface

CM.P.setdefault("enamel_white", M.P["enamel_white"])

# name, texture-set suffix, ground ramp + shade, ink ramp + shade, pictogram
WINGS = [
    ("EGIPT", "", ("wing_egypt", 6.5), ("formline_black", 1.5), "pyramid"),
    ("ASYRIA", "_asyria", ("wing_assyria", 4.5), ("enamel_cream", 6.5), "wings"),
    ("GRECJA", "_greece", ("wing_greece", 4.8), ("enamel_white", 7.2), "column"),
    ("OŚWIECENIE", "_enlight", ("wing_enlight", 4.0), ("brass", 7.0), "book"),
    ("AZJA", "_asia", ("wing_asia", 4.2), ("gold", 7.0), "roof"),
    ("AMERYKI I OCEANIA", "_americas", ("wing_americas", 4.6), ("enamel_cream", 6.8), "sun"),
]
SUBTITLES = {"EGIPT": "GALERIA RZEŹBY", "ASYRIA": "PAŁACE NINIWY", "GRECJA": "PARTENON",
             "OŚWIECENIE": "BIBLIOTEKA KRÓLEWSKA", "AZJA": "CHINY KOREA JAPONIA",
             "AMERYKI I OCEANIA": "MEKSYK I PACYFIK"}

ICONS = {
    "pyramid": ["......#.....", ".....###....", "....#####...", "...#######..", "..#########.",
                ".###########", "............"],
    "wings": ["#....##....#", "##..####..##", "###.####.###", ".##########.", "..########..",
              "....####....", ".....##....."],
    "column": ["############", ".##########.", "..#.#.#.#...", "..#.#.#.#...", "..#.#.#.#...",
               ".##########.", "############"],
    "book": ["##........##", "####....####", "#.###..###.#", "#..##..##..#", "#..##..##..#",
             "####.##.####", "....####...."],
    "roof": [".....##.....", "...######...", "#.########.#", ".##########.", "...#....#...",
             "...#....#...", "..########.."],
    "sun": ["....####....", "..##....##..", ".#..#..#..#.", ".#........#.", ".#..####..#.",
            "..##....##..", "....####...."],
}
ARROW = ["....##....", "...####...", "..######..", ".########.", "....##....", "....##....", "....##....",
         "....##...."]


def bitmap_mask(u, v, rows, left, top, px):
    bmp = np.array([[c == "#" for c in r] for r in rows], dtype=bool)
    col = np.floor((u - left) / px + 1e-6).astype(np.int64)
    row = np.floor((top - v) / px + 1e-6).astype(np.int64)
    ok = (col >= 0) & (col < bmp.shape[1]) & (row >= 0) & (row < bmp.shape[0])
    out = np.zeros(len(u), dtype=bool)
    out[ok] = bmp[row[ok], col[ok]]
    return out


# --------------------------------------------------------------------------
# freestanding post
# --------------------------------------------------------------------------

PW, P0, P1 = 1.0, 0.9, 2.5          # panel width, bottom, top


def post():
    p = Part("sign_wing")
    p.box((0, 0, (P0 + P1) / 2), (PW, 0.05, P1 - P0), "panel", bevel=0.006)
    for sx in (-1, 1):
        p.box((sx * (PW / 2 + 0.035), 0, (P1 + 0.12) / 2), (0.07, 0.09, P1 + 0.12), "iron", bevel=0.01)
        p.box((sx * (PW / 2 + 0.035), 0, 0.03), (0.26, 0.4, 0.06), "iron", bevel=0.01)
        p.lathe([(0.0, 0.0), (0.05, 0.0), (0.04, 0.05), (0.0, 0.08)], "iron", segments=8,
                center=(sx * (PW / 2 + 0.035), 0, P1 + 0.12))
    for z in (P0 - 0.03, P1 + 0.03):
        p.box((0, 0, z), (PW + 0.1, 0.08, 0.06), "iron", bevel=0.01)
    return p


def post_face(name, ground, ink, icon):
    lines = name.split(" I ") if len(name) > 11 else [name]
    if len(lines) == 2:
        lines = [lines[0], "I " + lines[1]]

    def fn(ctx):
        u, v = ctx.uvm[:, 0], ctx.uvm[:, 1]
        tx = ctx.texel
        n = ctx.N
        s = Surface(n)
        s.use_ramp(CM.P["enamel_white"], shade=np.full(n, 6.4) + ctx.fbm(8.0, 2, 3) * 0.3 + (ctx.rand(4) - 0.5) * 0.4)
        face = np.abs(ctx.n[:, 1]) > 0.9
        band = face & (v > P1 - 0.62)
        s.use_ramp(CM.P[ground[0]], mask=band, shade=np.full(n, ground[1]) + (ctx.rand(5) - 0.5) * 0.5)
        px = 2 * tx
        ink_m = np.zeros(n, dtype=bool)
        for k, line in enumerate(lines):
            base = P1 - 0.2 - k * 0.17 if len(lines) == 2 else P1 - 0.3
            ink_m |= font.text_mask(u, v, line, 0.0, base, px)
        ink_m &= band
        sub = font.text_mask(u, v, SUBTITLES[name].replace("·", "-"), 0.0, P1 - 0.74, tx) & face
        icon_m = bitmap_mask(u, v, ICONS[icon], -12 * 3 * tx / 2, P1 - 0.8, 3 * tx) & face
        icon_m |= sub
        arrow = bitmap_mask(u, v, ARROW, -10 * 4 * tx / 2, P0 + 0.5, 4 * tx) & face
        rule = face & (np.abs(v - (P1 - 0.62)) < tx) | face & (np.abs(v - (P0 + 0.58)) < tx * 0.6) & (np.abs(u) < 0.4)
        s.use_ramp(CM.P[ink[0]], mask=ink_m, shade=np.full(n, ink[1]))
        dark = CM.P[ground[0]] if ground[0] != "enamel_white" else CM.P[ink[0]]
        s.use_ramp(dark, mask=(icon_m | arrow | rule) & ~band, shade=np.full(n, 3.5 if ground[0] != "enamel_white"
                                                                               else ink[1]))
        chip = face & (ctx.edge_soft(2.0) > 0.3) & (ctx.fbm(20.0, 2, 7) > 0.4)
        s.use_ramp(CM.P["iron"], mask=chip, shade=np.full(n, 2.0))
        s.metal = np.where(ink_m & (ink[0] in ("brass", "gold")), 1.0, 0.0)
        s.rough = np.full(n, 0.22)
        return s
    return fn


# --------------------------------------------------------------------------
# portal plaque
# --------------------------------------------------------------------------

QW, QH = 3.2, 0.6


def plaque():
    p = Part("sign_wing_portal")
    p.box((0, -0.03, QH / 2), (QW, 0.06, QH), "rim", bevel=0.012)
    p.box((0, -0.061, QH / 2), (QW - 0.12, 0.004, QH - 0.12), "field")
    # nothing faces the wall: the backs go
    import bmesh
    p.bm.normal_update()
    bmesh.ops.delete(p.bm, geom=[f for f in p.bm.faces if f.normal.y > 0.9], context='FACES')
    return p


def plaque_face(name, ground, ink, icon):
    def fn(ctx):
        u, v = ctx.uvm[:, 0], ctx.uvm[:, 1]
        tx = ctx.texel
        n = ctx.N
        s = Surface(n)
        s.use_ramp(CM.P[ground[0]], shade=np.full(n, ground[1]) + ctx.fbm(6.0, 2, 3) * 0.3 + (ctx.rand(4) - 0.5) * 0.4)
        px = font.fit_px(name, QW - 1.3, tx, max_px=4 * tx)
        ink_m = font.text_mask(u, v, name, 0.0, QH / 2 - 3.5 * px, px)
        for sx in (-1, 1):
            ink_m |= bitmap_mask(u, v, ICONS[icon], sx * (QW / 2 - 0.4) - 12 * 3 * tx / 2, QH / 2 + 3.5 * 3 * tx, 3 * tx)
        s.use_ramp(CM.P[ink[0]], mask=ink_m, shade=np.full(n, ink[1]))
        s.metal = np.where(ink_m & (ink[0] in ("brass", "gold")), 1.0, 0.0)
        s.rough = np.where(ink_m, 0.3, 0.25)
        return s
    return fn


# --------------------------------------------------------------------------
# museum plan
# --------------------------------------------------------------------------

ZONES = [  # Godot rectangles (x0, z0, x1, z1), wing ramp
    ((-112, -86, -50, -4), "wing_assyria", "ASYRIA"), ((-112, -2, -62, 48), "wing_greece", "GRECJA"),
    ((-48, -36, -32, 30), "wing_egypt", "EGIPT"), ((-62, 0, -48, 30), "wing_egypt", ""),
    ((32, -36, 66, 34), "wing_enlight", "OŚWIECENIE"), ((-46, -86, -4, -38), "wing_americas", "AMERYKI"),
    ((4, -86, 46, -38), "wing_asia", "AZJA"), ((-46, -38, 46, -30), "enamel_cream", ""),
    ((-30, -30, 30, 30), "lime_floor", ""), ((-16, 30, 16, 52), "enamel_cream", "HOL"),
    ((16, 36, 38, 48), "enamel_cream", ""),
]
MX0, MX1, MZ0, MZ1 = -114.0, 68.0, -88.0, 54.0
BW, BH, B0 = 1.6, 1.25, 1.0       # board width, height, bottom edge (before the tilt)


TILT = 25.0


def board():
    """Built facing +Y (the kit front) directly: the board leans back."""
    import math
    from mathutils import Matrix
    p = Part("court_map_board")
    tilt = math.radians(TILT)
    face = p.box((0, 0, 0), (BW, 0.04, BH), "map", bevel=0.005)
    frame = []
    for sx in (-1, 1):
        frame += p.box((sx * (BW / 2 + 0.03), 0, 0), (0.06, 0.07, BH + 0.12), "oak", bevel=0.01)
    for sz in (-1, 1):
        frame += p.box((0, 0, sz * (BH / 2 + 0.03)), (BW + 0.12, 0.07, 0.06), "oak", bevel=0.01)
    p.move(face + frame, Matrix.Translation((0, 0.0, B0 + BH / 2 * math.cos(tilt))) @ Matrix.Rotation(tilt, 4, 'X'))
    for sx in (-1, 1):
        p.box((sx * 0.6, -0.15, B0 / 2 + 0.05), (0.08, 0.08, B0 + 0.1), "iron", bevel=0.01)
        p.box((sx * 0.6, -0.15, 0.03), (0.3, 0.5, 0.06), "iron", bevel=0.01)
    p.box((0, -0.15, 0.4), (1.2, 0.05, 0.05), "iron", bevel=0.008)
    return p


def _map(ctx):
    """The plan on paper, north up, drawn from the texel's place on the
    tilted board: u to the reader's right (-X), w up the board."""
    import math
    tilt = math.radians(TILT)
    cz = B0 + BH / 2 * math.cos(tilt)
    u = -ctx.p[:, 0]
    w = (ctx.p[:, 2] - cz) * math.cos(tilt) - ctx.p[:, 1] * math.sin(tilt)
    n = ctx.N
    tx = ctx.texel
    s = Surface(n)
    s.use_ramp(CM.P["enamel_cream"], shade=np.full(n, 6.8) + ctx.fbm(6.0, 2, 3) * 0.3 + (ctx.rand(4) - 0.5) * 0.4)
    front = ctx.n[:, 1] > 0.3
    sx = (BW - 0.16) / (MX1 - MX0)
    gx = MX0 + (u + (BW - 0.16) / 2) / sx
    gz = MZ0 + ((BH / 2 - 0.18) - w) / sx
    border = np.zeros(n, dtype=bool)
    for (x0, z0, x1, z1), ramp, label in ZONES:
        inside = (gx >= x0) & (gx <= x1) & (gz >= z0) & (gz <= z1) & front
        if not inside.any():
            continue
        s.use_ramp(CM.P[ramp], mask=inside, shade=np.full(n, 5.5 if ramp != "lime_floor" else 7.5))
        edge = inside & ((np.abs(gx - x0) * sx < tx) | (np.abs(gx - x1) * sx < tx) | (np.abs(gz - z0) * sx < tx)
                         | (np.abs(gz - z1) * sx < tx))
        border |= edge
        if label:
            cxu = ((x0 + x1) / 2 - MX0) * sx - (BW - 0.16) / 2
            cwz = (BH / 2 - 0.18) - ((z0 + z1) / 2 - MZ0) * sx
            border |= font.text_mask(u, w, label, cxu, cwz - 3 * tx, tx) & front
    # the drum, the T-Rex, the grate
    du = (0.0 - MX0) * sx - (BW - 0.16) / 2
    dw = (BH / 2 - 0.18) - (0.0 - MZ0) * sx
    r = np.hypot(u - du, w - dw)
    drum = (r < 12.5 * sx) & front
    s.use_ramp(CM.P["wing_greece"], mask=drum, shade=np.full(n, 3.0))
    border |= (np.abs(r - 12.5 * sx) < tx) & front
    you = (np.hypot(u - du, w - (dw - 26.0 * sx)) < 0.018) & front
    s.use_ramp(CM.P["formline_black"], mask=border, shade=np.full(n, 1.5))
    s.use_ramp(CM.P["formline_red"], mask=you, shade=np.full(n, 5.0))
    title = font.text_mask(u, w, "PLAN MUZEUM - PIĘTRO I", 0.0, BH / 2 - 0.12, 2 * tx) & front
    you_t = font.text_mask(u, w, "TU JESTEŚ", du + 0.03, dw - 26.0 * sx - 0.03, 2 * tx, align="left") & front
    s.use_ramp(CM.P["formline_black"], mask=title, shade=np.full(n, 1.0))
    s.use_ramp(CM.P["formline_red"], mask=you_t, shade=np.full(n, 4.5))
    s.rough = np.full(n, 0.5)
    return s


def build():
    out = []
    egypt = WINGS[0]
    base_fns = {"iron": CM.cast_iron, "panel": post_face(egypt[0], egypt[2], egypt[3], egypt[4])}
    variants = {f"sign_wing{suf}": {"iron": CM.cast_iron, "panel": post_face(nm, g, i, ic)}
                for nm, suf, g, i, ic in WINGS[1:]}
    out.append(kit("sign_wing", [post()], base_fns, ppm=128, ao_dist=0.15, variants=variants))
    pfns = {"rim": M.brass, "field": plaque_face(egypt[0], egypt[2], egypt[3], egypt[4])}
    pvariants = {f"sign_wing_portal{suf}": {"rim": M.brass, "field": plaque_face(nm, g, i, ic)}
                 for nm, suf, g, i, ic in WINGS[1:]}
    out.append(kit("sign_wing_portal", [plaque()], pfns, ppm=128, ground=None, wall=True, ao_dist=0.05,
                   variants=pvariants))
    out.append(kit("court_map_board", [board()], {"map": _map, "oak": M.wood_oak, "iron": CM.cast_iron}, ppm=256,
                   ao_dist=0.2, built_final=True, preview_extra=[("plan", (0.0, 0.0, 1.55), 0.9, 0.0, 30.0)]))
    return out
