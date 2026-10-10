"""King's Library kit: the two tiers of bookcases (Enlightenment wing).

Wall-run convention of the lobby kit: the wall plane at Godot z = 0, the
case on the room side (-Z), x from -W/2 to W/2, origin on the floor (lower
tier) or on the walkway floor (upper tier, y = 4 in the gallery).

  lib_bookcase_{a,b,c}_2m   lower tier, 2 x 3.6 x 0.5 m (cornice 0.56):
                            a mahogany press with brass-lattice doors over
                            green silk (0-0.92 m), a ledge at 0.96 m, six
                            shelves of folios down to octavos with leather
                            dust fringes, frieze with a gilt bead, cornice.
  lib_bookcase_1m           the same, 1 m (fitting runs, beside doors).
  lib_bookcase_up_{a,b}_2m  upper tier, 2 x 3.3 x 0.45 m: eight shelves of
                            quartos and octavos on a low plinth.
  lib_bookcase_up_1m        the same, 1 m.
  lib_bookcase_pilaster_low / _up
                            fluted mahogany pilaster 0.22 m wide with a
                            gilt capital, put on every joint between cases
                            and at the ends of a run (covers the stiles).

Every volume is real geometry in blocks (a run of 3-12 books of one height
is one box: front, top and the exposed sides) and every spine is painted in
the atlas (artlib/enl_books.py). Texture sets "<id>_v2" restyle the same
volumes (other leathers and labels) for variety along a 70 m gallery.
"""
import os
import random

from artlib import enl_books as B
from artlib import enl_materials as E
from artlib import materials as M
from artlib.archkit import kit, moulding, seed_of
from artlib.geo import Part

LOW_H = 3.6
UP_H = 3.3
LOW_CLEAR = (0.46, 0.40, 0.36, 0.33, 0.30, 0.27)
UP_CLEAR = (0.42, 0.38, 0.35, 0.33, 0.31, 0.29, 0.27, 0.26)
BOARD = 0.025

CORNICE = [(-0.0, 0.0), (-0.47, 0.0), (-0.47, 0.03), (-0.5, 0.05), (-0.5, 0.08), (-0.53, 0.1), (-0.55, 0.13),
           (-0.56, 0.16), (-0.56, 0.18), (-0.0, 0.18)]


def _case(name, W, tier, seed):
    """One bookcase module (built facing -Y, wall at y = 0)."""
    p = Part(name)
    rng = random.Random(seed)
    lower = tier == "low"
    D = 0.5 if lower else 0.45
    hw = W / 2
    inner = hw - 0.04
    if lower:
        # toe plinth and the press with lattice doors
        p.box((0, -0.24, 0.06), (W, 0.46, 0.12), "mahogany_dark", bevel=0.008)
        p.box((0, -D / 2, 0.52), (W, D, 0.8), "mahogany", bevel=0.012)
        n_doors = max(1, int(round(W / 1.0)))
        dw = W / n_doors
        for k in range(n_doors):
            cx = -hw + dw * (k + 0.5)
            fw = dw - 0.08
            z0, z1 = 0.16, 0.88
            for sx in (-1, 1):
                p.box((cx + sx * (fw / 2 - 0.03), -D - 0.008, (z0 + z1) / 2), (0.06, 0.016, z1 - z0), "mahogany",
                      bevel=0.006)
            for zz in (z0 + 0.035, z1 - 0.035):
                p.box((cx, -D - 0.008, zz), (fw - 0.12, 0.016, 0.07), "mahogany", bevel=0.006)
            p.box((cx, -D - 0.003, (z0 + z1) / 2), (fw - 0.1, 0.006, z1 - z0 - 0.12), "lattice")
            # escutcheon on the meeting side
            ex = cx + (fw / 2 - 0.05) * (1 if k % 2 == 0 else -1)
            p.box((ex, -D - 0.018, 0.56), (0.022, 0.006, 0.05), "brass", bevel=0.003)
        p.box((0, -0.28, 0.94), (W, 0.56, 0.04), "mahogany", bevel=0.012)
        z = 0.96
        clears = LOW_CLEAR
        height = LOW_H
    else:
        p.box((0, -D / 2 + 0.01, 0.06), (W, D - 0.02, 0.12), "mahogany_dark", bevel=0.008)
        z = 0.12
        clears = UP_CLEAR
        height = UP_H
    zs = z
    shelves = []
    for c in clears:
        shelves.append(B.Shelf(-inner + 0.005, inner - 0.005, z, c, -D + 0.02, D - 0.06))
        z += c
        board = p.box((0, -D / 2 - 0.005, z + BOARD / 2), (W - 0.06, D - 0.03, BOARD), "mahogany", bevel=0.004)
        # only the board's front edge is baked; its faces and bevels inside go to the
        # world-mapped tile (a bevel ring left in the atlas would waste a 2 x 0.45 m box)
        B.restyle(p, board, lambda c, n: n.y > -0.9, "interior")
        # leather dust fringe under the shelf's front edge
        p.box((0, -D + 0.012, z - 0.016), (W - 0.08, 0.005, 0.032), "fringe")
        z += BOARD
    top = z
    # back panel (seen in the gaps) and the stiles
    p.box((0, -0.02, (zs + top) / 2), (W - 0.04, 0.02, top - zs), "interior")
    for sx in (-1, 1):
        stile = p.box((sx * (hw - 0.02), -D / 2, (zs + top) / 2), (0.04, D, top - zs), "mahogany", bevel=0.006)
        B.restyle(p, stile, lambda c, n: n.y > -0.9, "interior")
    # frieze, gilt bead and cornice
    fz = height - 0.18 - top
    p.box((0, -D / 2 - 0.005, top + fz / 2), (W, D + 0.01, fz), "mahogany", bevel=0.008)
    p.box((0, -D - 0.012, top + 0.02), (W, 0.012, 0.016), "gilt", bevel=0.004)
    prof = [(y + (0.5 - D) * (1.0 if y < -0.01 else 0.0), zz + height - 0.18) for y, zz in CORNICE]
    moulding(p, prof, W, "mahogany")
    # books
    counter = [rng.randint(1, 900) * 10]
    vols = []
    for sh in shelves:
        vols += B.fill_shelf(sh, rng, counter)
    B.add_books(p, vols)
    _cull_case(p, hw, height, lower, top)
    return p, vols, shelves


def _cull_case(p, hw, height, lower, top):
    """Drops faces nobody sees (they would only take atlas space): backs on
    the wall, outer sides (the neighbour case or a pilaster covers them),
    ends of boards and fringes inside the stiles, the press top under the
    ledge, the frieze top under the cornice and the cornice's own top."""
    fz = height - 0.18

    def hidden(c, n):
        if n.y > 0.9 and c.y > -0.035:
            return True
        if abs(n.x) > 0.9 and n.x * c.x > 0 and abs(c.x) > hw - 0.0405:
            return True
        if n.z < -0.9 and c.z < 0.005:
            return True
        if lower and n.z > 0.9 and abs(c.z - 0.92) < 0.002:
            return True
        if abs(n.z) > 0.9 and abs(c.z - fz) < 0.003 and c.y > -0.47:
            return True
        if n.z > 0.9 and c.z > height - 0.003:
            return True
        if n.z < -0.5 and abs(c.z - top) < 0.012 and c.y > -0.5:
            return True                     # the frieze's underside on the top board
        return False
    B.cull(p, hidden)
    # backs and undersides of thin applied pieces and loose books
    thin = {p.slot("lattice"), p.slot("fringe"), p.slot("books_loose"), p.slot("gilt")}
    import bmesh
    bm = p.bm
    bm.normal_update()
    drop = [f for f in bm.faces if f.material_index in thin and (f.normal.y > 0.9 or (
        f.normal.z < -0.9 and p.slots[f.material_index] != "fringe"))]
    bmesh.ops.delete(bm, geom=drop, context='FACES')


def _pilaster(name, tier):
    p = Part(name)
    lower = tier == "low"
    H = LOW_H if lower else UP_H
    D = 0.5 if lower else 0.45
    W = 0.22
    p.box((0, -D / 2 - 0.02, 0.07), (W + 0.04, D + 0.04, 0.14), "mahogany_dark", bevel=0.01)
    p.box((0, -D / 2 - 0.03, 0.2), (W + 0.02, D + 0.06, 0.12), "mahogany", bevel=0.012)
    shaft_top = H - 0.42
    p.box((0, -D / 2 - 0.02, (0.26 + shaft_top) / 2), (W, D + 0.04, shaft_top - 0.26), "mahogany", bevel=0.01)
    # flutes: shallow dark grooves as thin boxes standing proud of the shaft
    for k in range(4):
        x = -W / 2 + 0.03 + k * (W - 0.06) / 3
        p.box((x, -D - 0.045, (0.34 + shaft_top - 0.08) / 2), (0.022, 0.012, shaft_top - 0.42), "mahogany",
              bevel=0.005)
    # gilt capital: astragal, bell, abacus
    p.box((0, -D / 2 - 0.035, shaft_top + 0.02), (W + 0.03, D + 0.07, 0.04), "gilt", bevel=0.008)
    p.box((0, -D / 2 - 0.04, shaft_top + 0.12), (W + 0.05, D + 0.08, 0.16), "capital", bevel=0.02)
    p.box((0, -D / 2 - 0.05, shaft_top + 0.23), (W + 0.1, D + 0.1, 0.06), "gilt", bevel=0.01)
    p.box((0, -D / 2 - 0.03, (shaft_top + 0.26 + H) / 2), (W + 0.06, D + 0.06, H - shaft_top - 0.26), "mahogany",
          bevel=0.01)
    return p


def _capital(ctx):
    """Gilt bell of the pilaster capital with painted acanthus leaves."""
    import numpy as np
    s = M.gold(ctx, seed=611)
    u = ctx.uvm[:, 0]
    v = ctx.uvm[:, 1]
    leaf = np.abs(np.sin(u * 40.0)) * 0.9 + np.sin(v * 60.0) * 0.4
    s.shade += leaf - 0.4
    return s


def _back(ctx):
    s = E.mahogany(ctx, seed=613, center=2.0)
    return s


def _fns(vols, bottoms, style_seed):
    spine = B.spines(vols, seed=style_seed)
    return {"mahogany": E.mahogany, "mahogany_dark": lambda c: E.mahogany(c, seed=617, center=2.6),
            "back": _back, "lattice": E.silk_lattice, "brass": E.worn_brass, "gilt": E.gilt,
            "fringe": E.fringe(bottoms, 0.032), "capital": _capital, "books": spine, "books_loose": spine}


INTERIOR = {"interior": "tile:enl_mahogany", "books_side": "tile:enl_bookside"}


def build():
    from artlib import enl_preview
    enl_preview.tile_material("interior", "enl_mahogany", (2.0, 1.0))
    enl_preview.tile_material("books_side", "enl_bookside", (2.0, 1.0))
    out = []
    specs = [("lib_bookcase_a_2m", 2.0, "low"), ("lib_bookcase_b_2m", 2.0, "low"), ("lib_bookcase_c_2m", 2.0, "low"),
             ("lib_bookcase_1m", 1.0, "low"), ("lib_bookcase_up_a_2m", 2.0, "up"),
             ("lib_bookcase_up_b_2m", 2.0, "up"), ("lib_bookcase_up_1m", 1.0, "up")]
    only = os.environ.get("ENL_ONLY", "").split(",")
    for name, W, tier in specs:
        if only != [""] and name not in only:
            continue
        part, vols, shelves = _case(name, W, tier, seed_of(name))
        # fringes hang under each board: their hem z (pre-turn frame = final z)
        bottoms = [sh.z0 + sh.clear - 0.032 for sh in shelves]
        fns = _fns(vols, bottoms, 0)
        # restyled sets only for the lower 2 m cases (eye level, most of the run)
        variants = {name + "_v2": _fns(vols, bottoms, 1)} if (W >= 2.0 and tier == "low") else {}
        out.append(kit(name, [part], fns, ppm=144, pad=3, wall=True, ground=0.0, ao_dist=0.3, ao_stride=3,
                       variants=variants, kinds=INTERIOR, preview=name in ("lib_bookcase_a_2m", "lib_bookcase_up_a_2m"),
                       preview_yaws=(-25.0, 0.0, 30.0, 60.0), preview_elevation=8.0,
                       preview_extra=[("shelf", (0.0, 0.25, 1.6 if tier == "low" else 1.2), 0.45, -15.0, 5.0)]))
    for name, tier in (("lib_bookcase_pilaster_low", "low"), ("lib_bookcase_pilaster_up", "up")):
        if only != [""] and name not in only:
            continue
        out.append(kit(name, [_pilaster(name, tier)], _fns([], [0.0], 0), ppm=128, wall=True, ground=0.0,
                       ao_dist=0.2, preview=False))
    return out
