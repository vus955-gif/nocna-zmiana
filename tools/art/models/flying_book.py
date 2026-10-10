"""Latające księgi (flying books), the Enlightenment wing's signature enemy
(spec 5.4): a quarto of 0.33 m that flies open toward the guard like a
mouth, its covers flapping as wings and jaws, loose leaves fluttering in
its throat and two illuminated eyes on the spread that glow when it wakes.

Faces +Y in Blender = -Z in Godot (the Enemy forward direction). The spine
stands upright at the back; origin = the middle of the spine. Parts (Godot
node names) and pivots in Godot axes:

  body     (0, 0, 0)              the spine: rounded leather back with
                                  raised bands, a title label, headbands.
  cover_l  (-0.026, 0, 0.02)      left board + left half of the text block,
                                  hinged on the spine (axis = Godot +Y).
  cover_r  (0.026, 0, 0.02)       right board + right half (mirror).
           Rest pose: each cover 55 degrees open from closed (a 110 degree
           "V" opening forward). cover_l.rotation.y > 0 opens it wider,
           cover_r.rotation.y < 0 opens it wider; -0.96 / +0.96 rad from
           rest closes the book. Telegraph of the dive: spread both to
           about +/-0.6 rad (nearly flat) for 0.6 s.
  pages    (0, 0, 0.02)           four loose leaves fanned in the middle:
                                  flutter = small rotation.y / scale.z.
  eye_l, eye_r                    markers on the two painted eyes (children
                                  of the covers): the irises glow from the
                                  emission map (EXTRAS); brighten with
                                  own_materials when it wakes or dives.

Texture sets on the same mesh: flying_book (red morocco), flying_book_green,
flying_book_blue, flying_book_black; size variants by scaling the node
(0.8-1.3). Debris: flying_book_page, a loose curled leaf (paper gore).
"""
import math

import numpy as np
from mathutils import Matrix

from artlib import enl_materials as E
from artlib.enl_materials import P
from artlib.geo import Part, box_project
from artlib.materials import _dither, text_marks
from artlib.model import Model
from artlib.painter import Surface

H = 0.33
WB = 0.235
TB = 0.006
HINGE_X, HINGE_Y = 0.026, -0.02
OPEN = math.radians(55.0)
BLOCK_T = 0.02
EYE_U, EYE_V = 0.125, 0.035          # eye centre on each page: from the hinge, above the middle

STYLES = {
    "flying_book": "enl_morocco_red",
    "flying_book_green": "enl_morocco_green",
    "flying_book_blue": "enl_morocco_blue",
    "flying_book_black": "enl_black",
}


def _lock(p, faces):
    for f in faces:
        f.normal_update()
        if not f[p.lock]:
            box_project(f, p.uv)
            f[p.lock] = 1


def _slot_by_normal(p, faces, rules):
    for f in faces:
        f.normal_update()
        for test, slot in rules:
            if test(f.normal):
                f.material_index = p.slot(slot)
                break


def cover(side):
    """side -1 = left. Modelled closed (board along +Y), then opened."""
    hx = side * HINGE_X
    name = "cover_l" if side < 0 else "cover_r"
    p = Part(name, origin=(hx, HINGE_Y, 0.0), parent="body")
    tag = "l" if side < 0 else "r"
    board = p.box((hx + side * TB / 2, HINGE_Y + WB / 2, 0.0), (TB, WB, H), "board_" + tag, bevel=0.0015)
    block = p.box((side * (HINGE_X - BLOCK_T / 2 - 0.001), HINGE_Y + 0.003 + 0.111, 0.0), (BLOCK_T, 0.222, H - 0.012),
                  "edge")
    # the block's inner face is the printed page (the spread); its outer face lies on the board
    _slot_by_normal(p, block, [(lambda n: n.x * side < -0.9, "spread_" + tag)])
    _lock(p, board + block)
    rot = Matrix.Translation((hx, HINGE_Y, 0.0)) @ Matrix.Rotation(-side * OPEN, 4, 'Z') @ \
        Matrix.Translation((-hx, -HINGE_Y, 0.0))
    p.move(board + block, rot)
    eye = rot @ Matrix.Translation((side * (HINGE_X - BLOCK_T - 0.0012), HINGE_Y + EYE_U, EYE_V))
    return p, (f"eye_{tag}", tuple(eye.to_translation()), name)


def spine():
    p = Part("body")
    r = 0.03
    ring = []
    for k in range(9):
        a = math.radians(180 + 180 * k / 8)          # the back half (y < hinge)
        ring.append((r * math.cos(a), HINGE_Y + 0.004 + r * 0.75 * math.sin(a)))
    faces = []
    for k in range(len(ring) - 1):
        (x0, y0), (x1, y1) = ring[k], ring[k + 1]
        f = p.poly([(x0, y0, -H / 2), (x1, y1, -H / 2), (x1, y1, H / 2), (x0, y0, H / 2)], "spine", smooth=True)[0]
        f.normal_update()
        if f.normal.y > 0:
            f.normal_flip()
        faces.append(f)
    # raised bands, and the headbands at head and tail
    for z in (-0.1, -0.035, 0.03, 0.095):
        pts = [(r * 1.03 * math.cos(math.radians(a)), HINGE_Y + 0.004 + r * 0.78 * math.sin(math.radians(a)), z)
               for a in range(190, 351, 32)]
        p.tube(pts, 0.004, "band", sides=4)
    for z in (-H / 2 + 0.004, H / 2 - 0.004):
        p.tube([(-0.02, HINGE_Y + 0.004, z), (0.0, HINGE_Y - 0.004, z), (0.02, HINGE_Y + 0.004, z)], 0.004,
               "headband", sides=4)
    return p


def leaves():
    p = Part("pages", origin=(0.0, HINGE_Y, 0.0), parent="body")
    for k, ang in enumerate((-14.0, -5.0, 6.0, 15.0)):
        curl = (0.03, -0.02, 0.025, -0.03)[k]
        lift = (0.01, 0.025, 0.0, 0.015)[k]
        nu, nv = 4, 2
        grid = []
        for j in range(nv + 1):
            row = []
            for i in range(nu + 1):
                t = i / nu
                y = HINGE_Y + 0.004 + 0.16 * t
                z = (-0.15 + 0.3 * j / nv) * (1.0 - 0.06 * t) + lift * t
                x = curl * t * t
                row.append((x, y, z))
            grid.append(row)
        faces = []
        for side in (1, -1):
            off = 0.0005 * side
            vs = [[p.bm.verts.new((x + off, y, z)) for (x, y, z) in row] for row in grid]
            for j in range(nv):
                for i in range(nu):
                    f = p._face([vs[j][i], vs[j][i + 1], vs[j + 1][i + 1], vs[j + 1][i]], "leaf")
                    f.normal_update()
                    if f.normal.x * side < 0:
                        f.normal_flip()
                    faces.append(f)
        _lock(p, faces)
        p.move(faces, Matrix.Translation((0.0, HINGE_Y, 0.0)) @ Matrix.Rotation(math.radians(ang), 4, 'Z')
               @ Matrix.Translation((0.0, -HINGE_Y, 0.0)))
    return p


# --- painters -------------------------------------------------------------------------

def small_print(ctx, u, v, seed=0):
    """Greeked small print at pixel scale: a 1-texel line of 'words' every
    third texel row, ragged right; reads as text from a step away."""
    from artlib import noise
    tx = ctx.texel
    row = np.floor(v / tx + 1e-6).astype(np.int64)
    col = np.floor(u / tx + 1e-6).astype(np.int64)
    on_row = np.mod(row, 3) == 0
    word = np.floor((col + noise.hash_float(row, row * 3, row * 7, seed) * 7).astype(np.int64) / 6.0).astype(np.int64)
    keep = noise.hash_float(word, row, np.zeros_like(row), seed + 1) > 0.18
    gap = np.mod(col + (noise.hash_float(row, word, row, seed + 2) * 6).astype(np.int64), 6) == 0
    letter = noise.hash_float(col, row, np.ones_like(row), seed + 3) > 0.12
    return on_row & keep & ~gap & letter


def _closed(ctx, side):
    """Texel positions and normals back in the closed frame of one cover,
    mirrored so both sides read like the left one: u = from the hinge,
    v = up, nx = normal across the board."""
    hx = side * HINGE_X
    a = side * OPEN                       # undo the opening
    c, s = math.cos(a), math.sin(a)
    x = ctx.p[:, 0] - hx
    y = ctx.p[:, 1] - HINGE_Y
    xc = c * x - s * y
    yc = s * x + c * y
    nxc = c * ctx.n[:, 0] - s * ctx.n[:, 1]
    return xc * side * -1, yc, ctx.p[:, 2], nxc * side * -1


def board(ramp, side):
    def fn(ctx):
        s = Surface(ctx.N)
        xc, u, v, nx = _closed(ctx, side)
        base = 4.4 + ctx.fbm(7.0, 3, 701) * 0.7 + _dither(ctx, 0.6, 702)
        base += ctx.edge(1.0) * 1.8 - ctx.cavity(3.0) * 1.2 - (1.0 - ctx.ao) * 3.0
        if ramp == "enl_black":
            base -= 1.2
        s.use_ramp(P[ramp], shade=base)
        outer = nx < -0.5
        tx = ctx.texel
        du = np.minimum(u - 0.004, WB - u)
        dv = H / 2 - np.abs(v)
        d = np.minimum(du, dv)
        rule = outer & (((d > 0.012) & (d < 0.012 + tx)) | ((d > 0.018) & (d < 0.018 + tx)))
        # corner fleurons: a small diamond on the diagonal inside the frame
        cu = np.where(u < WB / 2, u - 0.03, WB - u - 0.03)
        cv = H / 2 - np.abs(v) - 0.03
        fleur = outer & (np.abs(cu) + np.abs(cv) < 0.008)
        # central lozenge outline and a sun-burst of dots
        lu, lv = np.abs(u - WB / 2 - 0.004), np.abs(v)
        loz = outer & (np.abs(lu / 0.055 + lv / 0.085 - 1.0) < tx / 0.06)
        burst = outer & (np.hypot(lu, lv) < 0.016) & (ctx.rand(703) > 0.35)
        gilt = rule | fleur | loz | burst
        s.use_ramp(P["gold"], mask=gilt, shade=np.full(ctx.N, 6.8) + _dither(ctx, 1.2, 704) - (1.0 - ctx.ao) * 2.0)
        # scuffed corners and the hinge joint
        scuff = (d < 0.01) & (ctx.fbm(30.0, 2, 705) > 0.15)
        s.shade[scuff & ~gilt] += 1.2
        s.shade[(u < 0.012) & ~gilt] -= 1.0
        s.metal = np.where(gilt, 0.85, 0.0)
        s.rough = np.where(gilt, 0.3, 0.5)
        s.height = gilt * -0.0004
        return s
    return fn


def spread(side, glow=1.0):
    """A printed page with an illuminated eye that looks at the guard."""
    def fn(ctx):
        s = E.paper(ctx, seed=711, center=6.6)
        s.shade = np.round(s.shade * 0.5 + 6.6 * 0.5)
        xc, u, v, nx = _closed(ctx, side)
        tx = ctx.texel
        du, dv = u - EYE_U, v - EYE_V
        # text in two blocks round the eye, a red rubric line at the top
        ink = small_print(ctx, u, v, 712)
        margin = (u > 0.02) & (u < 0.205) & (np.abs(v) < 0.135)
        eye_zone = (np.abs(du) < 0.1) & (np.abs(dv) < 0.07)
        s.use_ramp(P["enl_ink"], mask=ink & margin & ~eye_zone, shade=np.full(ctx.N, 2.6))
        rubric = margin & (np.abs(v - 0.122) < tx) & ~eye_zone
        s.use_ramp(P["enl_morocco_red"], mask=rubric, shade=np.full(ctx.N, 6.0))
        # the almond, its outline and lashes
        w = 0.082
        half = 0.042 * np.clip(1.0 - (du / w) ** 2, 0.0, 1.0)
        white = (np.abs(du) < w) & (np.abs(dv) < half)
        outline = (np.abs(du) < w + tx) & (np.abs(np.abs(dv) - half) < tx * 1.1) & ~white
        outline |= white & (np.abs(np.abs(dv) - half) < tx * 0.9)
        lash = (dv > half) & (dv < half + 0.012) & (np.abs(du) < w * 0.85) & \
            (np.mod(np.floor((du + 0.2) / (tx * 3.0)), 2) == 0) & (np.abs(du) > 0.01)
        # the iris looks at you (centred), a slit pupil
        r = np.hypot(du, dv)
        iris = white & (r < 0.031)
        ring = white & (np.abs(r - 0.031) < tx * 0.9)
        pupil = iris & (np.abs(du) < 0.0055 * (1.0 - (dv / 0.032) ** 2).clip(0, 1) + tx * 0.5)
        veins = white & ~iris & (np.abs(ctx.fbm(60.0, 2, 713)) < 0.04) & (r > 0.03)
        s.use_ramp(P["enl_paper"], mask=white & ~iris, shade=np.full(ctx.N, 8.0) - (r > 0.05) * 0.8)
        s.use_ramp(P["enl_morocco_red"], mask=veins, shade=np.full(ctx.N, 6.5))
        sh_iris = 3.5 + (1.0 - r / 0.031) * 3.0 + _dither(ctx, 0.8, 714)
        s.use_ramp(P["eye_amber"], mask=iris & ~pupil, shade=sh_iris)
        dark = outline | lash | pupil | ring
        s.use_ramp(P["enl_ink"], mask=dark, shade=np.full(ctx.N, 0.6))
        emit = np.zeros((ctx.N, 3))
        col = s.colors()
        emit[iris & ~pupil] = col[iris & ~pupil] * glow
        emit[white & ~iris] = col[white & ~iris] * 0.12 * glow
        s.emit = emit
        s.rough = np.where(iris, 0.25, s.rough)
        return s
    return fn


def _edge(ctx):
    """Page edges: fine lines along the leaves, red-sprinkled fore-edge."""
    s = E.paper(ctx, seed=721, center=5.6)
    s.shade -= np.mod(np.floor(ctx.p[:, 0] / ctx.texel), 2) * 0.6
    sprinkle = ctx.rand(722) > 0.82
    s.use_ramp(P["enl_morocco_red"], mask=sprinkle, shade=np.full(ctx.N, 5.0))
    return s


def _leaf(ctx):
    s = E.paper(ctx, seed=731, center=6.6)
    s.shade = np.round(s.shade * 0.5 + 6.6 * 0.5) - (1.0 - ctx.ao) * 1.5
    u, v = ctx.uvm[:, 0], ctx.uvm[:, 1]
    ink = small_print(ctx, u, v, 732)
    s.use_ramp(P["enl_ink"], mask=ink, shade=np.full(ctx.N, 2.6))
    return s


def spine_paint(ramp):
    def fn(ctx):
        s = Surface(ctx.N)
        z = ctx.p[:, 2]
        base = 4.6 + ctx.fbm(9.0, 2, 741) * 0.6 + _dither(ctx, 0.6, 742) - (1.0 - ctx.ao) * 2.5
        if ramp == "enl_black":
            base -= 1.2
        s.use_ramp(P[ramp], shade=base)
        tx = ctx.texel
        rules = np.zeros(ctx.N, dtype=bool)
        for zb in (-0.1, -0.035, 0.03, 0.095):
            rules |= (np.abs(z - zb - 0.009) < tx * 0.6) | (np.abs(z - zb + 0.009) < tx * 0.6)
        label = (z > 0.039) & (z < 0.086)
        lab_ramp = "enl_black" if ramp != "enl_black" else "enl_morocco_red"
        s.use_ramp(P[lab_ramp], mask=label, shade=np.full(ctx.N, 3.0))
        letters = label & (np.abs(z - 0.0625) < tx * 1.6) & (ctx.rand(743) > 0.4)
        gilt = rules | letters
        s.use_ramp(P["gold"], mask=gilt, shade=np.full(ctx.N, 6.8))
        s.metal = np.where(gilt, 0.85, 0.0)
        s.rough = np.where(gilt, 0.3, 0.45)
        return s
    return fn


def fns_for(ramp):
    return {"board_l": board(ramp, -1), "board_r": board(ramp, 1), "spread_l": spread(-1), "spread_r": spread(1),
            "edge": _edge, "leaf": _leaf, "spine": spine_paint(ramp), "band": spine_paint(ramp),
            "headband": lambda c: E.glass_tint(c, ramp="enl_morocco_red", center=5.0)}


def page():
    """A loose leaf (debris): 0.21 x 0.31 m, curled, printed both sides."""
    p = Part("flying_book_page")
    nu, nv = 5, 3
    grid = []
    for j in range(nv + 1):
        row = []
        for i in range(nu + 1):
            u = -0.105 + 0.21 * i / nu
            v = -0.155 + 0.31 * j / nv
            y = 0.035 * (u / 0.105) ** 2 - 0.02 * (v / 0.155) ** 2 + 0.012 * (u / 0.105) * (v / 0.155)
            row.append((u, y, v))
        grid.append(row)
    for side in (1, -1):
        vs = [[p.bm.verts.new((x, y + 0.0004 * side, z)) for (x, y, z) in row] for row in grid]
        faces = []
        for j in range(nv):
            for i in range(nu):
                f = p._face([vs[j][i], vs[j][i + 1], vs[j + 1][i + 1], vs[j + 1][i]], "leaf")
                f.normal_update()
                if f.normal.y * side < 0:
                    f.normal_flip()
                faces.append(f)
        _lock(p, faces)
    return p


def build():
    body = spine()
    cl, eye_l = cover(-1)
    cr, eye_r = cover(1)
    pg = leaves()
    variants = {name: fns_for(ramp) for name, ramp in STYLES.items() if name != "flying_book"}
    book = Model("flying_book", [body, cl, cr, pg], fns_for(STYLES["flying_book"]), ppm=256, ground=None,
                 ao_dist=0.06, ao_rays=12, ao_stride=1, front=1, markers=[eye_l, eye_r], variants=variants,
                 preview_yaws=(-25.0, 20.0, 160.0, 90.0), preview_elevation=12.0,
                 preview_extra=[("eyes", (0.0, 0.08, 0.02), 0.2, 0.0, 6.0)])
    leaf = Model("flying_book_page", [page()], {"leaf": _leaf}, ppm=256, ground=None, ao_rays=0,
                 preview_yaws=(-30.0, 30.0, 150.0, 210.0))
    return [book, leaf]
