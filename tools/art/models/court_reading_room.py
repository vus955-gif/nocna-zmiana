"""Floor I: inside the Reading Room (the drum, r = 11.2 inside).

All pieces: origin = drum centre on the floor, built round the north axis
(Godot -Z) and facing the centre; place 16 copies at rotation.y = k * 22.5
degrees like the drum segments (the door variants at k = 0, 4, 8, 12).

  rr_bookcase       one 22.5 degree face of the wall of books: oak cases in
                    three bays, 12 + 11 shelves of gilt-tooled spines, a
                    lettered frieze, the gallery walk (y 4.8 - 5.0, 1 m deep)
                    on cast-iron consoles with an iron railing and an oak
                    handrail, the upper cases to 9.4 and their cornice (9.8).
                    The spines come from one shared book-wall texture (rr_books,
                    16 shelves x 4 m at 128 px/m): every shelf picks a stretch.
  rr_bookcase_door  the same over a doorway 3 x 4.5 m (oak lining through the
                    case depth, architrave, a clock at three o'clock on the
                    gallery fascia above).
  rr_dome_sector    1/16 of the vault: the cream-and-gold interior cornice
                    (9.8 - 10.8, an uplight on it: marker Light_Dome), the
                    lunette band with an arched window (10.8 - 13.2), and the
                    dome itself (13.2 -> the oculus at 19.9): six rows of
                    azure coffers with gilded steps and rosettes between
                    gilded main ribs, then a starry band up to the oculus.
  rr_oculus         the gilded ring of the oculus, the splayed light well
                    and the glazed lantern on top (parts rr_oculus and
                    rr_oculus_glass): the moon comes in here.
  rr_dome_outer     the lead-covered outer dome on the drum (from the
                    coping, y 21.65, to the lantern curb at y 23.6), ribbed:
                    seen from the roof walks and through the glass roof.
"""
import math

import numpy as np
from mathutils import Matrix, Vector

from artlib import court as C
from artlib import court_materials as CM
from artlib import font, noise, painter
from artlib import materials as M
from artlib.archkit import kit
from artlib.geo import Part
from artlib.painter import Surface

HI = C.HALF_IN
D1, D2 = 0.55, 0.45               # depth of the lower / upper cases
PLINTH = 0.18
LOW_TOP = 4.55                    # the lower cases' frieze 4.55 .. GALLERY
UP0, UP1 = C.GALLERY + 0.2 + 0.12, C.SHELF_TOP
N_LOW, N_UP = 12, 11
OW, OH = 3.0, 4.5

CM.P.update({
    "book_red": CM.hexramp("#1d0605", "#320b09", "#4a110d", "#621a14", "#7a241c", "#913126"),
    "book_green": CM.hexramp("#06120b", "#0b1f13", "#112d1c", "#183c26", "#204c31", "#2a5c3c"),
    "book_blue": CM.hexramp("#060a16", "#0b1225", "#111b36", "#192648", "#22325a", "#2d3f6c"),
    "book_brown": CM.hexramp("#140b06", "#22140b", "#331e11", "#452918", "#583520", "#6b4229"),
    "book_tan": CM.hexramp("#2c1e10", "#432f19", "#5b4224", "#745631", "#8d6a3f", "#a57f4f"),
    "book_black": CM.hexramp("#060606", "#0d0d0e", "#151517", "#1e1e21", "#28282c", "#33333a"),
})
BOOK_RAMPS = ["book_red", "book_green", "book_blue", "book_brown", "book_tan", "book_black", "book_red",
              "book_brown"]


def shelf_levels():
    """Shelf board tops of both tiers (metres) and the board under each."""
    low = list(np.linspace(PLINTH, LOW_TOP, N_LOW + 1)[:-1])
    up = list(np.linspace(UP0, UP1, N_UP + 1)[:-1])
    return low, up


# --------------------------------------------------------------------------
# bookcases (flat frame: wall at y = 0, room toward -Y, x in -HI .. HI)
# --------------------------------------------------------------------------

def case_tier(p, z0, z1, depth, n, x_spans, book_slot):
    """Bays between uprights over x_spans [(x0, x1), ...]; each span has its
    uprights at both ends (half width on the segment joints)."""
    pitch = (z1 - z0) / n
    posts = sorted({round(x, 5) for span in x_spans for x in span})
    c = 0.012
    for x in posts:
        joint = abs(abs(x) - HI) < 1e-4
        if joint:
            sg = 1.0 if x > 0 else -1.0
            w = 0.045
            sec = [(x, -depth), (x - sg * (w - c), -depth), (x - sg * w, -depth + c), (x - sg * w, 0.0)]
            C.prism_z(p, sec, z0, z1, "oak", inside=(x, -depth / 2))
        else:
            w = 0.045
            sec = [(x - w, 0.0), (x - w, -depth + c), (x - w + c, -depth), (x + w - c, -depth), (x + w, -depth + c),
                   (x + w, 0.0)]
            C.prism_z(p, sec, z0, z1, "oak", inside=(x, -depth / 2))
    for xa, xb in x_spans:
        inner_a, inner_b = xa + 0.045, xb - 0.045
        for k in range(n):
            zb = z0 + k * pitch
            # the board: underside, front edge, top strip as one strip
            if k > 0:
                prof = [(-depth + 0.12, zb - 0.03), (-depth, zb - 0.03), (-depth, zb), (-depth + 0.1, zb)]
                p.extrude(prof, inner_a, inner_b, "oak", caps=False)
            # the books: one face per shelf, set back 0.1
            book_face(p, inner_a, inner_b, zb, zb + pitch - 0.03, -depth + 0.1,
                      int(abs(inner_a) * 1000) * 31 + int(zb * 100) + (7 if depth == D2 else 0))


def bookcase(door):
    p = Part("rr_bookcase_door" if door else "rr_bookcase")
    hw = OW / 2
    spans_low = [(-HI, -hw - 0.24), (hw + 0.24, HI)] if door else \
        [(-HI, -HI / 3), (-HI / 3, HI / 3), (HI / 3, HI)]
    spans_up = [(-HI, -HI / 3), (-HI / 3, HI / 3), (HI / 3, HI)]
    # plinth and lower cases
    for xa, xb in spans_low:
        p.box(((xa + xb) / 2, -D1 / 2 - 0.02, PLINTH / 2), (xb - xa, D1 + 0.04, PLINTH), "oak_dark", bevel=0.008)
    case_tier(p, PLINTH, LOW_TOP, D1, N_LOW, spans_low, "books")
    # frieze of the lower cases with lettered shelf marks, under the gallery
    for xa, xb in spans_low:
        p.box(((xa + xb) / 2, -D1 / 2 - 0.01, (LOW_TOP + C.GALLERY) / 2), (xb - xa, D1 + 0.02, C.GALLERY - LOW_TOP),
              "frieze", bevel=0.01)
    # gallery walk: oak deck, iron fascia, consoles, railing
    G = C.GALLERY
    deck_y0, deck_y1 = -D1 - 1.0, -D1
    p.box((0.0, (deck_y0 + deck_y1) / 2, G + 0.17), (2 * HI, deck_y1 - deck_y0, 0.06), "deck")
    p.box((0.0, (deck_y0 + deck_y1) / 2, G + 0.07), (2 * HI, deck_y1 - deck_y0 - 0.02, 0.14), "rail")
    p.box((0.0, deck_y0 + 0.02, G + 0.1), (2 * HI, 0.06, 0.24), "fascia")
    for x in (-HI / 3, HI / 3):
        p.box((x, -D1 - 0.5, G - 0.05), (0.08, 1.0, 0.1), "rail", bevel=0.01)
        if not door:
            strut = p.box((0.0, 0.0, 0.0), (0.06, 1.05, 0.06), "rail", bevel=0.008)
            p.move(strut, Matrix.Translation((x, -D1 - 0.38, G - 0.38)) @ Matrix.Rotation(math.radians(-38), 4, 'X'))
        p.lathe([(0.0, -0.05), (0.06, -0.04), (0.07, 0.0), (0.0, 0.03)], "rail", segments=6,
                center=(x, -D1 - 0.95, G - 0.12))
    ry = deck_y0 + 0.05
    p.box((0.0, ry, G + 0.26), (2 * HI, 0.05, 0.05), "rail")
    p.box((0.0, ry, G + 1.18), (2 * HI, 0.05, 0.04), "rail")
    p.box((0.0, ry, G + 1.24), (2 * HI, 0.09, 0.07), "handrail", bevel=0.02)
    n = int(round(2 * HI / 0.14))
    for k in range(n):
        x = -HI + (k + 0.5) * 2 * HI / n
        heavy = k % 4 == 2
        s = 0.035 if heavy else 0.018
        p.box((x, ry, G + 0.72), (s, s, 0.9), "rail")
        if heavy:
            p.lathe([(0.0, 0.0), (0.04, 0.02), (0.03, 0.06), (0.0, 0.08)], "rail", segments=6,
                    center=(x, ry, G + 0.31))
    # upper cases
    case_tier(p, UP0, UP1, D2, N_UP, spans_up, "books")
    p.box((0.0, -D2 / 2, (G + 0.2 + UP0) / 2), (2 * HI, D2, UP0 - G - 0.2), "oak_dark", bevel=0.006)
    # cornice of the cases
    prof = [(0.0, UP1), (-D2 - 0.02, UP1), (-D2 - 0.02, UP1 + 0.12), (-D2 - 0.06, UP1 + 0.16), (-D2 - 0.06, UP1 + 0.24),
            (-D2 - 0.14, UP1 + 0.3), (-D2 - 0.16, UP1 + 0.36), (-D2 - 0.16, UP1 + 0.4), (0.0, UP1 + 0.4)]
    p.extrude(prof, -HI, HI, "oak", caps=False)
    markers = []
    if door:
        # oak lining through the case depth, architrave and head
        for sx in (-1, 1):
            C.quad(p, [(sx * hw, 0.0, 0.0), (sx * hw, -D1, 0.0), (sx * hw, -D1, OH), (sx * hw, 0.0, OH)], "oak",
                   (-sx, 0, 0))
            p.box((sx * (hw + 0.12), -D1 - 0.03, OH / 2), (0.24, 0.06, OH), "oak", bevel=0.01)
            p.box((sx * (hw + 0.12), -D1 - 0.05, 0.15), (0.28, 0.1, 0.3), "oak_dark", bevel=0.01)
        C.quad(p, [(-hw, 0.0, OH), (hw, 0.0, OH), (hw, -D1, OH), (-hw, -D1, OH)], "oak", (0, 0, -1))
        p.box((0.0, -D1 / 2 - 0.02, (OH + C.GALLERY) / 2), (OW + 0.48, D1 + 0.04, C.GALLERY - OH), "oak_dark",
              bevel=0.01)
        # the clock on the gallery fascia, stopped at three
        clock = p.lathe([(0.0, 0.0), (0.34, 0.0), (0.36, 0.03), (0.34, 0.07), (0.3, 0.08), (0.0, 0.08)], "brass",
                        segments=20)
        p.move(clock, Matrix.Translation((0.0, deck_y0 - 0.02, G + 0.12)) @ Matrix.Rotation(math.radians(90), 4, 'X'))
        face = p.lathe([(0.0, 0.0), (0.29, 0.0)], "clock", segments=20, cap_top=False)
        p.move(face, Matrix.Translation((0.0, deck_y0 - 0.102, G + 0.12)) @ Matrix.Rotation(math.radians(90), 4, 'X'))
    C.drop_end_faces(p, half=HI)
    C.drop_back_faces(p)
    C.wedge_in(p)
    return p, markers


# --- the painted books ------------------------------------------------------------

BOOK_ROWS, BOOK_ROW_H, BOOK_W = 16, 0.34, 4.0      # the shared book-wall texture: 16 shelves of 4 m


def _book_rows(seed):
    """Per texture row: book boundaries along its 4 m (cumulative widths)."""
    rng = np.random.default_rng(seed)
    rows = []
    for _ in range(BOOK_ROWS):
        w = rng.choice([0.022, 0.028, 0.03, 0.035, 0.04, 0.045, 0.055, 0.07], size=220,
                       p=[0.12, 0.18, 0.18, 0.18, 0.14, 0.1, 0.06, 0.04])
        rows.append(np.cumsum(w))
    return rows


def books(seed):
    """Painter of the book wall (a flat 4 x 5.44 m texture, 128 px/m): spines
    of six leather colours, runs of matching sets, gilt bands and labels,
    the dark shelf back above the shorter books."""
    rows = _book_rows(seed)

    def fn(ctx):
        u, v = ctx.uvm[:, 0], ctx.uvm[:, 1]
        tx = ctx.texel
        s = Surface(ctx.N)
        n = ctx.N
        shelf = np.clip(np.floor(v / BOOK_ROW_H).astype(np.int64), 0, BOOK_ROWS - 1)
        local = v - shelf * BOOK_ROW_H
        room = BOOK_ROW_H
        bid = np.zeros(n, np.int64)
        left = np.zeros(n)
        for sh in range(BOOK_ROWS):
            m = shelf == sh
            b = np.concatenate([[0.0], rows[sh]])
            i = np.clip(np.searchsorted(b, u[m], side="right"), 1, len(b) - 1)
            bid[m] = i + sh * 1000
            left[m] = u[m] - b[i - 1]
        h = 0.62 + noise.rand_cells(bid, seed + 1) * 0.36
        top = room * h
        kind = np.floor(noise.rand_cells(bid, seed + 2) * len(BOOK_RAMPS)).astype(np.int64)
        # runs of a matching set (encyclopaedias): neighbours share a colour
        run = noise.rand_cells(bid // 7, seed + 3) > 0.7
        kind = np.where(run, np.floor(noise.rand_cells(bid // 7, seed + 4) * len(BOOK_RAMPS)).astype(np.int64), kind)
        top = np.where(run, room * (0.8 + noise.rand_cells(bid // 7, seed + 5) * 0.15), top)
        gap = noise.rand_cells(bid, seed + 6) > 0.975
        above = (local > top) | gap
        tone = noise.rand_cells(bid, seed + 7)
        shade = 2.6 + tone * 2.0 + (local / np.maximum(top, 0.05)) * 0.8 + (ctx.rand(seed + 8) - 0.5) * 0.7
        # shadow of the board above on the tallest books
        shade -= np.clip((local - (room - 0.05)) / 0.05, 0.0, 1.0) * 1.5
        edge = left < tx
        shade = np.where(edge, shade - 1.6, shade)
        s.use_ramp(CM.P["wood_dark"], shade=np.full(n, 0.4) + local * 1.5)
        for kk, ramp in enumerate(BOOK_RAMPS):
            m = (kind == kk) & ~above
            if m.any():
                s.use_ramp(CM.P[ramp], mask=m, shade=shade)
        # gilt bands near the head and the tail, a label on some
        gilt = ~above & ~edge & ((np.abs(local - (top - 0.025)) < tx) | (np.abs(local - (top - 0.045)) < tx * 0.6)
                                 | (np.abs(local - 0.03) < tx))
        gilt &= noise.rand_cells(bid, seed + 9) > 0.25
        label = ~above & ~edge & (np.abs(local - top * 0.62) < 1.6 * tx) & (noise.rand_cells(bid, seed + 10) > 0.82)
        s.use_ramp(CM.P["gold"], mask=gilt, shade=np.full(n, 5.5) + (ctx.rand(seed + 11) - 0.5))
        s.use_ramp(CM.P["enamel_cream"], mask=label & ~gilt, shade=np.full(n, 2.5) + (ctx.rand(seed + 12) - 0.5) * 1.5)
        s.rough = np.where(gilt, 0.35, np.where(above, 0.9, 0.6))
        s.metal = np.where(gilt, 1.0, 0.0)
        s.height = np.where(above, -0.004, 0.0) - edge * 0.002
        return s
    return fn


def book_face(p, x0, x1, z0, z1, y, key):
    """A shelf of books: one quad whose UVs pick a row and a stretch of the
    shared book-wall texture (rr_books), chosen from ``key``."""
    f = C.front(p, x0, x1, z0, z1, "books", y=y)
    rng = np.random.default_rng(key)
    row = int(rng.integers(0, BOOK_ROWS))
    off = float(rng.uniform(0.0, BOOK_W - (x1 - x0) - 0.01))
    H = BOOK_ROWS * BOOK_ROW_H
    for loop in f.loops:
        x, z = loop.vert.co.x, loop.vert.co.z
        u = (off + (x - x0)) / BOOK_W
        v = (row * BOOK_ROW_H + (z - z0) / (z1 - z0) * BOOK_ROW_H) / H
        loop[p.uv].uv = (u, v)
    f[p.lock] = 1
    return f


def _frieze(ctx):
    """Oak frieze with gilt shelf marks (a letter per bay)."""
    s = M.wood_oak(ctx)
    u, v = ctx.uvm[:, 0], ctx.uvm[:, 1]
    px = 2 * ctx.texel
    ink = np.zeros(ctx.N, dtype=bool)
    for k, ch in enumerate("ABC"):
        x = -HI * 2 / 3 + k * HI * 2 / 3
        ink |= font.text_mask(u, v, ch, x, (LOW_TOP + C.GALLERY) / 2 - 4 * px, px)
    s.use_ramp(CM.P["gold"], mask=ink, shade=np.full(ctx.N, 6.5))
    s.metal = np.where(ink, 1.0, 0.0)
    return s


def _deck(ctx):
    s = M.parquet(ctx, block=0.5, planks=4)
    return s


def _fascia(ctx):
    s = CM.cast_iron(ctx)
    u = ctx.uvm[:, 0]
    rib = np.abs(np.mod(u, 0.35) - 0.175) < ctx.texel * 1.5
    s.use_ramp(CM.P["gold"], mask=rib & (np.abs(ctx.uvm[:, 1] - (C.GALLERY + 0.1)) < 0.06), shade=np.full(ctx.N, 4.5))
    return s


def _clock(ctx):
    """White enamel dial, roman-ish ticks, hands at three o'clock."""
    p = ctx.p
    # the dial lies in a plane facing -Y in the drum frame of segment 0
    x, z = p[:, 0], p[:, 2] - (C.GALLERY + 0.12)
    r = np.hypot(x, z)
    a = np.arctan2(x, z)                       # 0 = twelve, clockwise
    s = Surface(ctx.N)
    s.use_ramp(CM.P["enamel_white"], shade=np.full(ctx.N, 6.2) + (ctx.rand(3) - 0.5) * 0.5)
    tick = (r > 0.22) & (r < 0.27) & (np.abs(np.mod(a + math.pi / 12, math.pi / 6) - math.pi / 12) < 0.05)
    hour = (np.abs(z) < 0.012) & (x > 0) & (x < 0.15)
    minute = (np.abs(x) < 0.01) & (z > 0) & (z < 0.22)
    ink = tick | hour | minute | (r < 0.02)
    s.use_ramp(CM.P["book_black"], mask=ink, shade=np.full(ctx.N, 1.0))
    s.rough = np.full(ctx.N, 0.2)
    return s


BOOK_FNS = {"oak": M.wood_oak, "oak_dark": M.wood_dark, "frieze": _frieze,
            "fascia": _fascia, "handrail": M.wood_dark, "brass": M.brass, "clock": _clock}
BOOK_KINDS = {"rail": "tile:cast_iron", "deck": "tile:parquet", "books": "rr_books"}


# --------------------------------------------------------------------------
# the dome
# --------------------------------------------------------------------------

rev_strip = C.rev_strip


def _orient_to(f, target):
    f.normal_update()
    if f.normal.dot(Vector(target) - f.calc_center_median()) < 0:
        f.normal_flip()


def coffer_rows():
    phi = math.asin(C.DOME_BASE_R / C.DOME_R)
    rows = [phi]
    cell = 2 * C.ALPHA / 2
    for _ in range(6):
        phi -= cell * math.sin(phi) * 1.02
        rows.append(phi)
    return rows


def dome_cell(p, th0, th1, ph0, ph1, rib_l, rib_r, rib_b, rib_t, edge_mats):
    """One coffer in the cell th0..th1 x ph0..ph1 (ph0 lower = larger phi).
    rib_* = rib half widths (m) on each side; edge_mats = (left, right)
    material of the rib strips on the theta edges."""
    R = C.DOME_R
    centre = Vector((0.0, 0.0, C.DOME_ZC))

    def P(th, ph, r=R):
        return C.dome_point(th, ph, r)

    def inset(k, d_l, d_r, d_b, d_t):
        phm = (ph0 + ph1) / 2
        sl = R * math.sin(phm)
        return (th0 + d_l / sl, th1 - d_r / sl, ph0 - d_b / R, ph1 + d_t / R)

    steps = [  # (inset beyond the rib, radius offset, material of the ring face, of the wall below it)
        (0.0, 0.0),
        (0.06, 0.07),
        (0.16, 0.14),
    ]
    rects = []
    for ins, dr in steps:
        rects.append((inset(0, rib_l + ins, rib_r + ins, rib_b + ins, rib_t + ins), R + dr))
    outer = (th0, th1, ph0, ph1)

    def corners(rect, r):
        a, b, c, d = rect
        return [P(a, c, r), P(b, c, r), P(b, d, r), P(a, d, r)]       # bl, br, tr, tl

    # rib strips: cell boundary -> first rect (at R)
    cb = corners(outer, R)
    c0 = corners(rects[0][0], R)
    strip_mats = [edge_mats[0] if False else "cream", edge_mats[1], "cream", edge_mats[0]]
    # sides: bottom (bl-br), right (br-tr), top (tr-tl), left (tl-bl)
    sides = [(0, 1, "cream"), (1, 2, edge_mats[1]), (2, 3, "cream"), (3, 0, edge_mats[0])]
    for a, b, mat in sides:
        f = p.poly([cb[a], cb[b], c0[b], c0[a]], mat)[0]
        _orient_to(f, centre)
    # steps: wall from rect k (at r_k) to rect k+1 outline at r_{k+1}, ledge
    mats = [("gold", "gold"), ("cream", "cream")]
    for k in range(len(rects) - 1):
        (ra, rr_a), (rb, rr_b) = rects[k], rects[k + 1]
        ca = corners(ra, rr_a)
        cw = corners(ra, rr_b)          # the same outline pushed out
        cn = corners(rb, rr_b)
        mid = (sum(cw, Vector()) / 4.0)
        for a, b, _ in sides:
            f = p.poly([ca[a], ca[b], cw[b], cw[a]], mats[k][0])[0]
            _orient_to(f, mid)
            f = p.poly([cw[a], cw[b], cn[b], cn[a]], mats[k][1])[0]
            _orient_to(f, centre)
    last, rl = rects[-1]
    f = p.poly(corners(last, rl), "blue")[0]
    _orient_to(f, centre)
    # rosette at the panel centre
    thm, phm = (last[0] + last[1]) / 2, (last[2] + last[3]) / 2
    size = min(R * math.sin(phm) * (last[1] - last[0]), R * (last[2] - last[3]))
    rad = size * 0.22
    ros = p.lathe([(0.0, 0.0), (rad, 0.0), (rad * 0.8, rad * 0.25), (rad * 0.45, rad * 0.45), (0.0, rad * 0.5)],
                  "gold", segments=8, cap_bottom=False)
    n = (centre - P(thm, phm, rl)).normalized()
    rot = n.to_track_quat('Z', 'Y').to_matrix().to_4x4()
    p.move(ros, Matrix.Translation(P(thm, phm, rl) + n * 0.005) @ rot)


def dome_sector():
    p = Part("rr_dome_sector")
    # --- cornice and lunette band, built flat and mapped like the cases
    z = C.CORNICE
    prof = [(0.0, z), (-0.08, z), (-0.08, z + 0.2), (-0.12, z + 0.24), (-0.12, z + 0.4), (-0.06, z + 0.42),
            (-0.06, z + 0.66), (-0.14, z + 0.7), (-0.2, z + 0.74), (-0.2, z + 0.8), (-0.62, z + 0.84),
            (-0.7, z + 0.9), (-0.7, z + 0.96), (-0.51, z + 1.0)]
    p.extrude(prof, -HI, HI, "cream", caps=False)
    n = int(round(2 * HI / 0.4))
    for k in range(n):
        x = -HI + (k + 0.5) * 2 * HI / n
        p.box((x, -0.42, z + 0.77), (0.12, 0.42, 0.1), "gold", bevel=0.01)
    # a gilt fillet on the frieze
    p.box((0.0, -0.065, z + 0.55), (2 * HI, 0.01, 0.05), "gold")
    band_y = -(C.A_IN - C.BAND_A)
    zb0, zb1 = C.SPRING, C.LUNETTE_TOP
    lw, sill, spring = 1.15, 11.0, 11.85
    arc = C.arch_pts(0.0, spring, lw, 12)
    hb = HI * (C.A_IN + band_y) / C.A_IN         # band half width before mapping (in flat x)
    hb = HI
    C.front(p, -hb, -lw, zb0, zb1, "cream", y=band_y)
    C.front(p, lw, hb, zb0, zb1, "cream", y=band_y)
    C.front(p, -lw, lw, zb0, sill, "cream", y=band_y)
    head = [(lw, spring)] + arc[1:-1] + [(-lw, spring), (-lw, zb1), (lw, zb1)]
    C.quad(p, [(x, band_y, zz) for x, zz in head], "cream", (0, -1, 0))
    D = 0.22
    for sx in (-1, 1):
        C.quad(p, [(sx * lw, band_y, sill), (sx * lw, band_y + D, sill), (sx * lw, band_y + D, spring),
                   (sx * lw, band_y, spring)], "cream", (-sx, 0, 0))
    C.quad(p, [(-lw, band_y, sill), (lw, band_y, sill), (lw, band_y + D, sill), (-lw, band_y + D, sill)], "cream",
           (0, 0, 1))
    for i in range(len(arc) - 1):
        (xa, za), (xb, zb) = arc[i], arc[i + 1]
        C.quad(p, [(xa, band_y, za), (xb, band_y, zb), (xb, band_y + D, zb), (xa, band_y + D, za)], "cream",
               (-(xa + xb), 0, -(za + zb - 2 * spring)))
    back = [(-lw, sill), (lw, sill)] + arc
    C.quad(p, [(x, band_y + D, zz) for x, zz in back], "lunette", (0, -1, 0))
    path = [(-lw, sill)] + list(reversed(arc)) + [(lw, sill)]
    p.sweep([(0.0, 0.0), (0.05, 0.0), (0.05, 0.03), (0.08, 0.06), (0.08, 0.14), (0.0, 0.16)], path, "gold",
            y0=band_y)
    # gilded pilaster strips on the band corners (they carry the main ribs)
    for sx in (-1, 1):
        a, b = (hb - 0.22, hb) if sx > 0 else (-hb, -hb + 0.22)
        p.box(((a + b) / 2, band_y - 0.04, (zb0 + zb1) / 2), (b - a, 0.08, zb1 - zb0), "gold_rib", bevel=0.01)
    C.drop_end_faces(p, half=HI)
    C.wedge_in(p)
    # --- the dome base ring (round), the dome cells and the starry band
    th0, th1 = -C.ALPHA, C.ALPHA
    ring = [(C.BAND_A - 0.05, C.LUNETTE_TOP - 0.25), (C.BAND_A - 0.25, C.LUNETTE_TOP - 0.2),
            (C.BAND_A - 0.32, C.LUNETTE_TOP - 0.1), (C.BAND_A - 0.25, C.LUNETTE_TOP - 0.02),
            (C.DOME_BASE_R - 0.02, C.LUNETTE_TOP + 0.02)]
    faces, _ = rev_strip(p, ring, th0, th1, 8, "gold")
    for f in faces:
        _orient_to(f, (0.0, 0.0, C.LUNETTE_TOP - 1.0))
    rows = coffer_rows()
    rib = 0.11
    for r in range(len(rows) - 1):
        ph0, ph1 = rows[r], rows[r + 1]
        for c in range(2):
            a = th0 + c * (th1 - th0) / 2
            b = a + (th1 - th0) / 2
            left = "gold_rib" if c == 0 else "cream"
            right = "gold_rib" if c == 1 else "cream"
            dome_cell(p, a, b, ph0, ph1, rib if c == 0 else rib * 0.6, rib if c == 1 else rib * 0.6,
                      rib * 0.8, rib * 0.8, (left, right))
    # starry band from the last row to the oculus, main ribs continuing
    ph_top = math.asin(C.OCULUS_R / C.DOME_R)
    centre = (0.0, 0.0, C.DOME_ZC)
    nb = 5
    phs = [rows[-1] + (ph_top - rows[-1]) * k / nb for k in range(nb + 1)]
    for k in range(nb):
        for c in range(4):
            a = th0 + c * (th1 - th0) / 4
            b = a + (th1 - th0) / 4
            q = [C.dome_point(a, phs[k]), C.dome_point(b, phs[k]), C.dome_point(b, phs[k + 1]),
                 C.dome_point(a, phs[k + 1])]
            f = p.poly(q, "stars")[0]
            _orient_to(f, centre)
    w = 0.09
    rr = C.DOME_R - 0.04
    for th, sgn in ((th0, 1.0), (th1, -1.0)):
        for k in range(nb):
            s0 = sgn * w / (C.DOME_R * math.sin(phs[k]))
            s1 = sgn * w / (C.DOME_R * math.sin(phs[k + 1]))
            q = [C.dome_point(th, phs[k], rr), C.dome_point(th + s0, phs[k], rr),
                 C.dome_point(th + s1, phs[k + 1], rr), C.dome_point(th, phs[k + 1], rr)]
            f = p.poly(q, "gold_rib")[0]
            _orient_to(f, centre)
    # a gilded ring halfway up the starry band
    phr = phs[2]
    ringp = [(C.DOME_R * math.sin(phr) - 0.0, C.DOME_ZC + C.DOME_R * math.cos(phr)),
             (C.DOME_R * math.sin(phr - 0.012) - 0.06, C.DOME_ZC + C.DOME_R * math.cos(phr - 0.012) - 0.04)]
    faces, _ = rev_strip(p, ringp, th0, th1, 4, "gold")
    for f in faces:
        _orient_to(f, centre)
    marker = ("Light_Dome", (0.0, C.A_IN - 0.62, C.CORNICE + 1.05), None)
    return p, [marker]


def _stars(ctx):
    """Azure ground with small gilded eight-point stars on a jittered grid."""
    s = CM.dome_blue(ctx, center=6.6)
    q = ctx.p
    f1, _, cid = ctx.worley(2.2, 77, p=q)
    star = (f1 < 0.07) & (cid > 0.35)
    big = (f1 < 0.11) & (cid > 0.9)
    s.use_ramp(CM.P["gold"], mask=star | big, shade=np.full(ctx.N, 7.0) + (ctx.rand(5) - 0.5))
    s.metal = np.where(star | big, 1.0, 0.0)
    s.rough = np.where(star | big, 0.3, s.rough)
    return s


def _lunette(ctx):
    """Dark glazing of a lunette, fan of iron bars from the springing."""
    u, v = ctx.uvm[:, 0], ctx.uvm[:, 1]
    tx = ctx.texel
    s = Surface(ctx.N)
    # moonlit from outside: brighter toward the top of the fan
    s.use_ramp(CM.P["night_glass"], shade=3.2 + np.clip((v - 11.0) / 2.0, 0, 1) * 2.5 + ctx.fbm(1.5, 2, 4) * 1.0
               + (ctx.rand(5) - 0.5) * 0.6)
    ang = np.arctan2(v - 11.85, u)
    r = np.hypot(u, v - 11.85)
    bars = (np.abs(np.mod(ang, math.pi / 6)) < 1.2 * tx / np.maximum(r, 0.1)) & (v > 11.85)
    bars |= (np.abs(r - 0.55) < tx) & (v > 11.85)
    bars |= (np.abs(np.mod(u + 0.2875, 0.575) - 0.2875) < tx) & (v <= 11.85)
    bars |= np.abs(v - 11.85) < tx
    s.use_ramp(CM.P["cast_iron"], mask=bars, shade=np.full(ctx.N, 3.0))
    s.rough = np.where(bars, 0.5, 0.06)
    emit = s.colors() * 0.6
    emit[bars] = 0.0
    s.emit = emit
    return s


CM.P.setdefault("night_glass", CM.hexramp("#04060b", "#070b14", "#0b111e", "#101828", "#162135", "#1e2b44",
                                           "#283856"))


def _gold_rib(ctx):
    s = M.gold(ctx)
    s.shade -= 0.4
    return s


DOME_FNS = {"cream": CM.dome_cream, "gold": M.gold, "gold_rib": _gold_rib, "blue": CM.dome_blue, "stars": _stars,
            "lunette": _lunette}


# --------------------------------------------------------------------------
# oculus, lantern, outer dome
# --------------------------------------------------------------------------

def oculus():
    p = Part("rr_oculus")
    g = Part("rr_oculus_glass")
    ph = math.asin(C.OCULUS_R / C.DOME_R)
    z0 = C.DOME_ZC + C.DOME_R * math.cos(ph)
    centre = Vector((0.0, 0.0, z0 - 6.0))
    # gilded ring moulding where the dome stops
    ring = [(C.OCULUS_R + 0.45, z0 - 0.08), (C.OCULUS_R + 0.3, z0 - 0.16), (C.OCULUS_R + 0.12, z0 - 0.16),
            (C.OCULUS_R + 0.04, z0 - 0.08), (C.OCULUS_R, z0 + 0.05)]
    faces, _ = rev_strip(p, ring, 0.0, math.tau, 32, "gold")
    for f in faces:
        _orient_to(f, centre)
    # the splayed well: cream with gilded ribs
    well = [(C.OCULUS_R, z0 + 0.05), (C.OCULUS_R + 0.15, z0 + 0.6), (C.WELL_TOP_R - 0.2, C.WELL_TOP - 0.6),
            (C.WELL_TOP_R, C.WELL_TOP)]
    faces, _ = rev_strip(p, well, 0.0, math.tau, 32, "well")
    for f in faces:
        f.normal_update()
        c = f.calc_center_median()
        if f.normal.dot(Vector((-c.x, -c.y, 0.0))) < 0:
            f.normal_flip()
    for k in range(16):
        a = math.tau * k / 16
        pts = [((r - 0.03) * math.sin(a), (r - 0.03) * math.cos(a), z) for r, z in well]
        p.tube(pts, 0.035, "gold", sides=4, caps=False)
    # lantern: iron curb, mullions, glass drum and glass cone, finial
    zc0, zc1 = C.WELL_TOP, C.WELL_TOP + 0.3
    curb = [(C.WELL_TOP_R, zc0), (C.WELL_TOP_R + 0.35, zc0), (C.WELL_TOP_R + 0.35, zc1), (C.WELL_TOP_R - 0.05, zc1)]
    faces, _ = rev_strip(p, curb, 0.0, math.tau, 32, "iron")
    for f in faces:
        f.normal_update()
        c = f.calc_center_median()
        if f.normal.dot(Vector((c.x, c.y, (c.z - (zc0 + zc1) / 2) * 4.0))) < 0:
            f.normal_flip()
    zg0, zg1, zt = zc1, zc1 + 1.1, zc1 + 2.1
    R = C.WELL_TOP_R
    n = 16
    for k in range(n):
        a = math.tau * k / n
        x, y = R * math.sin(a), R * math.cos(a)
        p.box((x, y, (zg0 + zg1) / 2), (0.07, 0.07, zg1 - zg0), "iron")
        p.tube([(x, y, zg1), (0.35 * math.sin(a), 0.35 * math.cos(a), zt)], 0.035, "iron", sides=4, caps=False)
    rr = [(R, zg1), (R + 0.06, zg1 + 0.06), (R + 0.06, zg1 + 0.14), (R, zg1 + 0.16)]
    faces, _ = rev_strip(p, rr, 0.0, math.tau, 32, "iron")
    for f in faces:
        f.normal_update()
        c = f.calc_center_median()
        if f.normal.dot(Vector((c.x, c.y, 0.0))) < 0:
            f.normal_flip()
    p.lathe([(0.0, zt - 0.05), (0.4, zt - 0.05), (0.3, zt + 0.1), (0.1, zt + 0.25), (0.06, zt + 0.6), (0.12, zt + 0.7),
             (0.0, zt + 0.85)], "iron", segments=12)
    # glass: drum and cone, both faces (from the room and from the roof)
    for prof in ([(R - 0.01, zg0), (R - 0.01, zg1)], [(R - 0.01, zg1 + 0.02), (0.38, zt - 0.02)]):
        for inward in (True, False):
            faces, _ = rev_strip(g, prof, 0.0, math.tau, 16, "glass")
            for f in faces:
                f.normal_update()
                c = f.calc_center_median()
                out = Vector((c.x, c.y, 0.5 if prof[1][1] > zg1 + 0.5 else 0.0))
                if (f.normal.dot(out) < 0) != inward:
                    f.normal_flip()
    return [p, g]


def outer_dome():
    p = Part("rr_dome_outer")
    r0, z0 = C.A_IN + 0.3, C.TOP
    r1, z1 = C.WELL_TOP_R + 0.35, C.WELL_TOP
    prof = []
    for k in range(9):
        t = k / 8
        r = r0 + (r1 - r0) * t
        z = z0 + (z1 - z0) * math.sin(t * math.pi / 2)
        prof.append((r, z))
    faces, _ = rev_strip(p, prof, 0.0, math.tau, 48, "lead", smooth=True)
    for f in faces:
        f.normal_update()
        if f.normal.z < 0:
            f.normal_flip()
    # standing-seam ribs and a stone curb at the foot
    for k in range(32):
        a = math.tau * k / 32
        pts = [(r * math.sin(a), r * math.cos(a), z + 0.04) for r, z in prof]
        p.tube(pts, 0.05, "lead_rib", sides=4, caps=False)
    curb = [(r0 + 0.2, z0), (r0 + 0.2, z0 + 0.25), (r0 - 0.1, z0 + 0.3)]
    faces, _ = rev_strip(p, curb, 0.0, math.tau, 48, "portland")
    for f in faces:
        f.normal_update()
        c = f.calc_center_median()
        if f.normal.dot(Vector((c.x, c.y, 2.0))) < 0:
            f.normal_flip()
    return p


def _lead_rib(ctx):
    s = CM.lead(ctx)
    s.shade += 1.0
    return s


def build():
    out = []
    book_wall = painter.paint_tile(books(601), BOOK_W, BOOK_ROWS * BOOK_ROW_H, 128, normal_strength=1.5)
    for door in (False, True):
        part, markers = bookcase(door)
        out.append(kit(part.name, [part], BOOK_FNS, kinds=BOOK_KINDS, built_final=True, ppm=96, ground=0.0,
                       ao_dist=0.35, textures={"rr_books": book_wall} if not door else {},
                       preview_yaws=(160.0, 200.0, 135.0, 225.0), preview_elevation=8.0,
                       preview_extra=[("books", (0.0, C.A_IN - 0.6, 2.0), 1.3, 165.0, 5.0),
                                      ("gallery", (0.0, C.A_IN - 1.2, 5.0), 2.2, 150.0, -10.0)] if not door else
                       [("door", (0.0, C.A_IN - 0.6, 3.0), 2.6, 170.0, 5.0)]))
    sector, markers = dome_sector()
    out.append(kit("rr_dome_sector", [sector], DOME_FNS, built_final=True, ppm=64, ground=None, ao_dist=0.5,
                   markers=markers, preview_elevation=-30.0, preview_yaws=(160.0, 180.0, 200.0, 0.0),
                   preview_extra=[("coffers", (0.0, 6.0, 17.0), 3.0, 180.0, -50.0)]))
    out.append(kit("rr_oculus", oculus(), {"gold": M.gold, "well": CM.dome_cream, "iron": CM.cast_iron},
                   kinds={"glass": "glass"}, built_final=True, ppm=64, ground=None, ao_dist=0.3,
                   preview_elevation=20.0))
    out.append(kit("rr_dome_outer", [outer_dome()], {"lead": CM.lead, "lead_rib": _lead_rib, "portland": CM.portland},
                   built_final=True, ppm=32, ground=None, ao_rays=0, preview_elevation=25.0))
    return out
