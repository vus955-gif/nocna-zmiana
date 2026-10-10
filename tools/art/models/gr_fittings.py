"""Greek kit: portals, skylight well, coffer, floor border, plinths (64 px/m).

  gr_portal_4m        door frame of the wing for 4 x 4.5 m openings, after
                      the north door of the Erechtheion: a three-fascia
                      architrave with ears at the top corners, rosettes along
                      the outer band, a frieze with the painted anthemion and
                      a cornice carried on two scrolled consoles. Single face
                      (one per side of a passage): origin = the opening's
                      floor centre on the wall face, trim toward -Z.
  gr_portal_2m        the same for 2 x 2.8 m openings.
  gr_skylight_4m      a 4 x 4 m top-light well, 2 m deep: moulded frame on
                      the ceiling, two stepped tiers (a painted Greek key on
                      the first ledge), an iron laylight grid every 0.5 m at
                      the top with the glass as part gr_skylight_4m_glass
                      (no shadow: the moonlight comes through, the bars cut
                      it into a grid). Origin = centre of the opening on the
                      ceiling plane; the well rises in +Y.
  gr_coffer_2m        2 x 2 m coffer: stepped marble frames with a bead
                      round an Egyptian-blue field with a gold star (the
                      painted ceilings of the temples). Origin = module
                      centre on the ceiling plane, hangs down 0.32 m; each
                      module carries half a beam (tiles edge to edge).
  gr_floor_border_4m/2m/1m/05m   1 m inlaid border: a running meander of
                      grey Hymettian marble on white between grey bands, 4 mm
                      proud. Origin = on the floor at the wall line, module
                      centre; the strip runs along X and extends to -Z.
  gr_floor_border_corner  1 x 1 m corner square with a rosette; origin at
                      the room corner, covers x 0..1, z -1..0 (as the lobby's).
  gr_plinth_low       4.4 x 0.5 x 1.6 m low base of the pediment groups:
                      grey body, white mouldings, a bronze label strip.
  gr_plinth_block     1.0 x 1.1 x 1.0 m pedestal for a vase, a head, a cast.
"""
import math

import numpy as np
from mathutils import Matrix, Vector

from artlib import greek as GK
from artlib import greek_ornament as O
from artlib import materials as M
from artlib.archkit import LENGTHS, facing, kit, plan_sweep
from artlib.geo import Part
from artlib import kit as K

FLOOR_T = 0.004


# --------------------------------------------------------------------------
# portals
# --------------------------------------------------------------------------

def _rosette(p, c, r, slot="rosette"):
    """A carved rosette on the wall-facing plane, facing -Y (pre-turn)."""
    ros = p.lathe([(0.0, 0.0), (r, 0.0), (r, 0.012), (r * 0.72, 0.03), (r * 0.35, 0.045), (0.0, 0.05)], slot,
                  segments=8, cap_bottom=False)
    p.move(ros, Matrix.Translation(c) @ Matrix.Rotation(math.radians(90), 4, 'X'))


def _console(p, x, z_top, h=0.9, w=0.16, d=0.3):
    """A scrolled console (ancon) under the cornice end: a tapering block
    with a big scroll at the top and a small one at the foot."""
    p.box((x, -d / 2 - 0.02, z_top - h / 2), (w, d * 0.75, h), "marble", bevel=0.02)
    for sx in (-1, 1):
        top = p.lathe([(0.0, -0.01), (0.13, -0.01), (0.13, 0.01), (0.0, 0.01)], "scroll", segments=10)
        p.move(top, Matrix.Translation((x + sx * (w / 2 + 0.005), -d * 0.5, z_top - 0.13))
               @ Matrix.Rotation(math.radians(90), 4, 'Y'))
        foot = p.lathe([(0.0, -0.01), (0.07, -0.01), (0.07, 0.01), (0.0, 0.01)], "scroll", segments=8)
        p.move(foot, Matrix.Translation((x + sx * (w / 2 + 0.005), -d * 0.35, z_top - h + 0.08))
               @ Matrix.Rotation(math.radians(90), 4, 'Y'))
    p.box((x, -0.05, z_top - h - 0.04), (w * 0.8, 0.1, 0.08), "marble", bevel=0.01)


def portal(name, hw, H, k=1.0):
    p = Part(name)
    t = 0.6 * k                                    # architrave width
    path = [(-hw, 0.0), (-hw, H), (hw, H), (hw, 0.0)]
    prof = [(0.0, 0.0), (0.04 * k, 0.0), (0.04 * k, 0.17 * k), (0.06 * k, 0.19 * k), (0.06 * k, 0.35 * k),
            (0.085 * k, 0.37 * k), (0.085 * k, 0.5 * k), (0.11 * k, 0.53 * k), (0.12 * k, 0.56 * k),
            (0.12 * k, t), (0.0, t)]
    p.sweep(prof, path, "marble")
    # ears: the outer band runs on past the jambs at the top corners
    for sx in (-1, 1):
        p.box((sx * (hw + t + 0.08 * k), -0.06 * k, H + t - 0.2 * k), (0.16 * k, 0.12 * k, 0.4 * k), "marble",
              bevel=0.01)
    # rosettes on the outer fascia
    r = 0.085 * k
    off = 0.43 * k
    n_side = max(2, int(round(H / (0.7 * k))))
    for sx in (-1, 1):
        for i in range(n_side):
            z = 0.5 * k + (H - 0.6 * k) * i / max(1, n_side - 1)
            _rosette(p, (sx * (hw + off), -0.085 * k, z), r)
    n_top = max(2, int(round(2 * hw / (0.7 * k)))) + 1
    for i in range(n_top):
        x = -hw + 2 * hw * i / (n_top - 1)
        _rosette(p, (x, -0.085 * k, H + off), r)
    # hood: frieze with the painted anthemion, cornice on two consoles
    zf = H + t
    W = 2 * (hw + t + 0.2 * k)
    p.box((0, -0.06 * k, zf + 0.22 * k), (W, 0.12 * k, 0.44 * k), "frieze")
    z_c = zf + 0.44 * k
    p.extrude([(-0.12 * k, z_c), (-0.2 * k, z_c + 0.02 * k), (-0.26 * k, z_c + 0.07 * k), (-0.3 * k, z_c + 0.07 * k),
               (-0.3 * k, z_c + 0.18 * k), (-0.34 * k, z_c + 0.22 * k), (-0.36 * k, z_c + 0.28 * k),
               (-0.36 * k, z_c + 0.31 * k), (0.0, z_c + 0.31 * k)], -W / 2 - 0.15 * k, W / 2 + 0.15 * k, "cornice",
              caps=True)
    for sx in (-1, 1):
        _console(p, sx * (W / 2 - 0.02 * k), z_c + 0.02 * k, h=0.95 * k, w=0.17 * k, d=0.3 * k)
    return p


# --------------------------------------------------------------------------
# skylight, coffer
# --------------------------------------------------------------------------

def _ring(p, half, z0, z1, slot, inward=True):
    """Four vertical walls of a square well (normals toward the centre)."""
    for a in range(4):
        rot = Matrix.Rotation(math.radians(90 * a), 4, 'Z')
        pts = [(-half, -half, z0), (half, -half, z0), (half, -half, z1), (-half, -half, z1)]
        pts = [tuple((rot @ Vector(q).to_4d()).to_3d()) for q in pts]
        mid = rot @ Vector((0, -half, 0)).to_4d()
        want = (-mid.x, -mid.y, 0) if inward else (mid.x, mid.y, 0)
        facing(p, pts, slot, want)


def _ledge(p, h0, h1, z, slot):
    """Flat square ring at height z between half-widths h0 (outer) and h1
    (inner), facing down."""
    for a in range(4):
        rot = Matrix.Rotation(math.radians(90 * a), 4, 'Z')
        pts = [(-h0, -h0, z), (h0, -h0, z), (h1, -h1, z), (-h1, -h1, z)]
        pts = [tuple((rot @ Vector(q).to_4d()).to_3d()) for q in pts]
        facing(p, pts, slot, (0, 0, -1))


def skylight():
    p = Part("gr_skylight_4m")
    g = Part("gr_skylight_4m_glass")
    h = 2.0
    # moulded frame round the opening on the ceiling (hangs 0.12 m)
    path = [(-h, -h), (-h, h), (h, h), (h, -h)]
    plan_sweep(p, [(-0.12, -0.0), (-0.12, 0.05), (-0.09, 0.08), (-0.07, 0.14), (-0.03, 0.2), (0.0, 0.3)], path,
               "frame")
    # tiers: walls up, ledges stepping in
    _ring(p, h, -0.12, 0.9, "well")
    _ledge(p, h, h - 0.18, 0.9, "ledge")
    _ring(p, h - 0.18, 0.9, 1.6, "well_key")
    _ledge(p, h - 0.18, h - 0.32, 1.6, "ledge")
    _ring(p, h - 0.32, 1.6, 2.0, "well")
    # iron laylight grid and the glass
    top = h - 0.32
    n = int(round(2 * top / 0.5))
    for i in range(n + 1):
        c = -top + 2 * top * i / n
        p.box((c, 0.0, 1.96), (0.05, 2 * top, 0.08), "iron")
        p.box((0.0, c, 1.96), (2 * top, 0.05, 0.08), "iron")
    q = g.poly([(-top, -top, 1.99), (top, -top, 1.99), (top, top, 1.99), (-top, top, 1.99)], "glass")[0]
    q.normal_update()
    if q.normal.z > 0:
        q.normal_flip()
    return [p, g]


def coffer():
    p = Part("gr_coffer_2m")
    lo, hi = -0.85, 0.85
    path = [(lo, lo), (lo, hi), (hi, hi), (hi, lo)]
    # beam soffit, first step, bead, second step to the field (all hanging)
    p.sweep([(0.0, 0.15), (0.32, 0.15), (0.32, 0.0)], path, "frame", closed=True)
    p.sweep([(0.32, 0.0), (0.2, 0.0), (0.2, -0.02), (0.185, -0.03), (0.17, -0.02), (0.17, -0.1)], path, "bead",
            closed=True)
    p.sweep([(0.17, -0.1), (0.04, -0.1), (0.04, -0.25)], path, "frame", closed=True)
    f = p.poly([(lo + 0.25, -0.04, lo + 0.25), (hi - 0.25, -0.04, lo + 0.25), (hi - 0.25, -0.04, hi - 0.25),
                (lo + 0.25, -0.04, hi - 0.25)], "field")[0]
    f.normal_update()
    if f.normal.y > 0:
        f.normal_flip()
    # wall-plane build -> ceiling: the viewer side (-Y) turns to face down
    p.move(list(p.bm.faces), Matrix.Rotation(math.radians(90), 4, 'X'))
    return p


# --------------------------------------------------------------------------
# floor, plinths
# --------------------------------------------------------------------------

def border(W, name):
    p = Part(name)
    f = p.poly([(-W / 2, 0.0, FLOOR_T), (W / 2, 0.0, FLOOR_T), (W / 2, 1.0, FLOOR_T), (-W / 2, 1.0, FLOOR_T)],
               "border")[0]
    f.normal_update()
    if f.normal.z < 0:
        f.normal_flip()
    return p


def border_corner():
    p = Part("gr_floor_border_corner")
    f = p.poly([(0.0, 0.0, FLOOR_T), (1.0, 0.0, FLOOR_T), (1.0, 1.0, FLOOR_T), (0.0, 1.0, FLOOR_T)], "corner")[0]
    f.normal_update()
    if f.normal.z < 0:
        f.normal_flip()
    return p


def plinth_low():
    p = Part("gr_plinth_low")
    X, Y = 4.4, 1.6
    hx, hy = X / 2 - 0.08, Y / 2 - 0.08
    path = [(-hx, -hy), (-hx, hy), (hx, hy), (hx, -hy)]
    plan_sweep(p, [(0.0, 0.08), (0.06, 0.08), (0.08, 0.05), (0.1, 0.03), (0.1, 0.0), (0.4, 0.0)], path, "grey")
    plan_sweep(p, [(0.4, 0.0), (0.41, 0.03), (0.44, 0.06), (0.47, 0.08), (0.5, 0.08)], path, "marble")
    top = p.poly([(-hx - 0.08, -hy - 0.08, 0.5), (hx + 0.08, -hy - 0.08, 0.5), (hx + 0.08, hy + 0.08, 0.5),
                  (-hx - 0.08, hy + 0.08, 0.5)], "marble")[0]
    top.normal_update()
    if top.normal.z < 0:
        top.normal_flip()
    p.box((0, -hy - 0.005, 0.24), (0.9, 0.012, 0.12), "bronze", bevel=0.003)
    return p


def plinth_block():
    p = Part("gr_plinth_block")
    S = 1.0
    h = S / 2 - 0.06
    path = [(-h, -h), (-h, h), (h, h), (h, -h)]
    plan_sweep(p, [(0.0, 0.06), (0.08, 0.06), (0.1, 0.03), (0.12, 0.01), (0.12, 0.0), (0.96, 0.0),
                   (0.98, 0.02), (1.01, 0.04), (1.04, 0.06), (1.1, 0.06)], path, "marble")
    top = p.poly([(-h - 0.06, -h - 0.06, 1.1), (h + 0.06, -h - 0.06, 1.1), (h + 0.06, h + 0.06, 1.1),
                  (-h - 0.06, h + 0.06, 1.1)], "marble")[0]
    top.normal_update()
    if top.normal.z < 0:
        top.normal_flip()
    return p


# --------------------------------------------------------------------------
# paint
# --------------------------------------------------------------------------

def _marble(ctx):
    return GK.pentelic(ctx, seed=901, center=7.8, veins=0.5, patina=0.9, ao=3.5, cavity=1.6, grime=False)


def _grey(ctx):
    return GK.grey_marble(ctx, seed=903, center=4.6)


def _rosette_paint(ctx):
    s = GK.pentelic(ctx, seed=905, center=7.6, veins=0.2, patina=0.6, ao=3.0, grime=False)
    # petals by angle round the disc's own axis (it faces the room)
    GK.paint_traces(ctx, s, "gr_red", np.ones(ctx.N, bool), 907, center=3.8, density=0.5, freq=6.0)
    return s


def _frieze(ctx, z0, h):
    u = -ctx.p[:, 0]
    s = GK.marble_body(ctx, 911, center=7.5, vein=0.35, warm=0.8, polish=0.35)
    front = np.abs(ctx.n[:, 1]) > 0.5
    v0 = ctx.p[:, 2] - z0
    palm, lotus, scroll = O.anthemion(u + 0.25, v0 - h * 0.08, h * 0.84, period=h * 1.15)
    GK.paint_traces(ctx, s, "gr_blue", front & ~(palm | lotus | scroll), 913, center=3.4, density=0.7, freq=1.5)
    GK.paint_traces(ctx, s, "gr_red", front & palm, 915, center=4.2, density=0.9, freq=1.5)
    GK.paint_traces(ctx, s, "gr_ochre", front & (lotus | scroll), 917, center=4.6, density=0.9, freq=1.5)
    s.shade -= (1.0 - ctx.ao) * 3.5
    return s


def _cornice(ctx):
    return GK.pentelic(ctx, seed=921, center=7.8, veins=0.4, patina=0.8, ao=3.0)


def _scroll(ctx):
    return GK.pentelic(ctx, seed=923, center=7.4, veins=0.2, patina=0.8, ao=3.0, grime=False)


def _frame(ctx):
    return GK.pentelic(ctx, seed=931, center=7.9, veins=0.4, patina=0.7, ao=3.0, cavity=1.2, grime=False)


def _well(ctx):
    s = GK.gr_plaster_tile(ctx)
    s.shade -= (1.0 - ctx.ao) * 3.0
    return s


def _well_key(ctx):
    """The first tier: plaster with a painted Greek key at its foot."""
    s = GK.gr_plaster_tile(ctx)
    z = ctx.p[:, 2]
    u = ctx.uvm[:, 0]
    band = (z > 0.95) & (z < 1.3)
    cell = 0.0625
    x = np.floor(np.mod(u, 0.5) / cell).astype(int) % 8
    y = np.clip(np.floor((z - 0.98) / cell).astype(int), 0, 6)
    key = np.array([[1, 1, 1, 1, 1, 1, 1, 1], [1, 0, 0, 0, 0, 0, 0, 0], [1, 0, 1, 1, 1, 1, 0, 0],
                    [1, 0, 1, 0, 0, 1, 0, 0], [1, 0, 1, 1, 0, 1, 0, 0], [1, 0, 0, 0, 0, 1, 0, 0],
                    [1, 1, 1, 1, 1, 1, 0, 0]])
    on = band & (key[y, x] == 1) & (z < 0.98 + 7 * cell)
    GK.paint_traces(ctx, s, "gr_blue", band & ~on, 941, center=3.6, density=0.75, freq=2.0)
    GK.paint_traces(ctx, s, "gr_ochre", on, 943, center=5.0, density=0.95, freq=2.0)
    s.shade -= (1.0 - ctx.ao) * 3.0
    return s


def _ledge_paint(ctx):
    u = ctx.uvm[:, 0]
    v = ctx.uvm[:, 1]
    h, egg, shell, dart = O.egg_dart(u, np.mod(v, 0.18), 0.18, period=0.125, depth=0.006)
    s = O.carved_marble(ctx, h, 945, center=7.6)
    return s


def _iron(ctx):
    return M.iron(ctx, seed=951)


def _coffer_frame(ctx):
    return GK.pentelic(ctx, seed=961, center=7.9, veins=0.3, patina=0.7, ao=3.0, cavity=1.2, grime=False)


def _coffer_bead(ctx):
    s = GK.pentelic(ctx, seed=963, center=7.6, veins=0.2, patina=0.5, ao=3.0, grime=False)
    GK.paint_traces(ctx, s, "gr_gold", np.ones(ctx.N, bool), 965, center=4.4, density=0.6, freq=3.0)
    return s


def _coffer_field(ctx):
    """Egyptian blue with a gold eight-point star; the paint worn in places
    to the marble."""
    x, y = ctx.p[:, 0], ctx.p[:, 1]
    s = GK.marble_body(ctx, 967, center=7.2, vein=0.3, warm=0.6)
    st = O.star(x, y, 0.0, 0.0, 0.42, points=8)
    core = np.hypot(x, y) < 0.08
    GK.paint_traces(ctx, s, "gr_blue", ~st, 969, center=3.6, density=0.95, freq=1.2)
    GK.paint_traces(ctx, s, "gr_gold", st & ~core, 971, center=5.0, density=0.95, freq=1.2)
    GK.paint_traces(ctx, s, "gr_red", core, 973, center=4.4, density=1.0, freq=1.2)
    s.shade -= (1.0 - ctx.ao) * 3.0
    s.rough = np.where(st, 0.45, s.rough)
    return s


def _border_paint(ctx, corner=False):
    """Meander of grey marble on white; grey bands at both edges."""
    x, y = ctx.p[:, 0], ctx.p[:, 1]
    across = y if not corner else np.minimum(x, y)
    tx = ctx.texel
    s = GK.marble_body(ctx, 975, center=7.8, vein=0.3, warm=0.7, polish=0.12)
    grey = GK.marble_body(ctx, 977, center=4.8, vein=0.6, warm=0.0, polish=0.1, ramp="gr_grey",
                          vein_ramp="gr_grey_vein", light_veins=True)
    band = (across < 0.12) | (across > 0.88)
    if corner:
        r = np.hypot(x - 0.5, y - 0.5)
        a = np.arctan2(y - 0.5, x - 0.5)
        petal = (r < 0.3 * (0.55 + 0.45 * np.abs(np.cos(a * 4)))) & (r > 0.06)
        sel = petal | (np.abs(r - 0.37) < 0.03)
        sel |= (x < 0.12) | (y < 0.12) | (x > 0.88) | (y > 0.88)
    else:
        cell = 0.0625
        u = -x                                     # turned: the viewer reads along -x
        cx = np.floor(np.mod(u, 0.5) / cell).astype(int) % 8
        cy = np.floor((across - 0.28) / cell).astype(int)
        key = np.array([[1, 1, 1, 1, 1, 1, 1, 1], [1, 0, 0, 0, 0, 0, 0, 0], [1, 0, 1, 1, 1, 1, 0, 0],
                        [1, 0, 1, 0, 0, 1, 0, 0], [1, 0, 1, 1, 0, 1, 0, 0], [1, 0, 0, 0, 0, 1, 0, 0],
                        [1, 1, 1, 1, 1, 1, 0, 0]])
        inside = (cy >= 0) & (cy < 7)
        on = np.zeros(ctx.N, bool)
        on[inside] = key[cy[inside], cx[inside]] == 1
        sel = band | on
    s.merge(GK._select(grey, sel), sel)
    joint = (np.abs(np.mod(x, 1.0)) < tx) | (np.abs(across - 0.12) < tx * 0.6) | (np.abs(across - 0.88) < tx * 0.6)
    s.shade = np.where(joint, 2.2, s.shade)
    s.height = np.where(joint, -0.0015, 0.0)
    s.rough = np.clip(s.rough, 0.08, 0.5)
    return s


def _bronze(ctx):
    return M.bronze(ctx)


def build():
    fns = {"marble": _marble, "grey": _grey, "rosette": _rosette_paint, "cornice": _cornice,
           "scroll": _scroll}
    out = [kit("gr_portal_4m", [portal("gr_portal_4m", 2.0, 4.5)], dict(fns, frieze=lambda c: _frieze(c, 5.1, 0.44)),
               wall=True, ao_dist=0.4, preview_extra=[("front", (0.0, 0.0, 3.0), 3.4, 15.0, 8.0)]),
           kit("gr_portal_2m", [portal("gr_portal_2m", 1.0, 2.8, k=0.7)],
               dict(fns, frieze=lambda c: _frieze(c, 2.8 + 0.42, 0.308)), wall=True, ao_dist=0.3)]
    sky = {"frame": _frame, "well": _well, "well_key": _well_key, "ledge": _ledge_paint, "iron": _iron}
    out.append(kit("gr_skylight_4m", skylight(), sky, kinds={"glass": "glass"}, built_final=True, ground=None,
                   ao_dist=0.5, preview_elevation=-50.0))
    out.append(kit("gr_coffer_2m", [coffer()], {"frame": _coffer_frame, "bead": _coffer_bead, "field": _coffer_field},
                   built_final=True, ground=None, ceiling=0.0, ao_dist=0.4, preview_elevation=-45.0))
    for W, tag in LENGTHS:
        out.append(kit("gr_floor_border_" + tag, [border(W, "gr_floor_border_" + tag)], {"border": _border_paint},
                       built_final=True, ground=None, ao_rays=0, preview=tag == "4m", preview_elevation=60.0))
    out.append(kit("gr_floor_border_corner", [border_corner()], {"corner": lambda c: _border_paint(c, True)},
                   built_final=True, ground=None, ao_rays=0, preview=False))
    plin = {"grey": _grey, "marble": _marble, "bronze": _bronze}
    out.append(kit("gr_plinth_low", [plinth_low()], plin, ao_dist=0.3))
    out.append(kit("gr_plinth_block", [plinth_block()], plin, ao_dist=0.3))
    return out
