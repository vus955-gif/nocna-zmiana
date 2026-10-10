"""King's Library kit: the stairs up to the gallery walkway (y = 4).

Pitch as everywhere in the museum: 0.15 m risers on 0.40 m treads (20.6
degrees). The straight pieces use the stairs frame of StairsSpec.frame()
like kit_stairs.py (origin in the middle of the bottom front edge of the
flight, Godot -Z = up the flight, X across), modelled in that frame (not
turned):

  lib_stair_step_1m      oak tread with a brass nosing on a dark mahogany
                         riser; origin = bottom of the riser, centre. Step i
                         at (0, i * rise, -i * tread); scale X to the width.
  lib_stair_stringer_4m  mahogany stringer with a gilt bead, 4 m of run and
                         1.5 m of rise (10 steps); centre it 0.07 m outside
                         an open side, one per 10 steps at (x, 1.5k, -4k).
  lib_stair_railing_4m   raked railing on the stringer: a black iron rod per
                         tread with a brass collar, mahogany handrail on a
                         brass bar. Same frame and placement as the stringer.
  lib_stair_newel        mahogany newel at the foot with a brass urn.

  lib_stair_spiral       the hero: a cast-iron and oak spiral stair 3.4 m
                         across, 27 steps of 0.148 m = 4.0 m. Origin = the
                         column's foot. The walking line has a radius of
                         1.15 m and 0.40 m treads (19.9 degrees per step).
                         The first step's leading edge points along Godot
                         +X; the flight turns counter-clockwise seen from
                         above (538 degrees): you set off walking toward
                         Godot -Z and arrive on the top step (y 4.0)
                         walking toward +Z, back the way you came in.
                         Markers "stair_bottom" (walking line at the foot)
                         and "stair_top" (walking line on the top step).
                         Treads and their undersides are world-mapped
                         ("tile:enl_oak_boards"), so the atlas holds only
                         the ironwork and the nosings.
"""
import math
import os

from mathutils import Matrix

from artlib import enl_materials as E
from artlib.archkit import kit, orient_out
from artlib.geo import Part

RISE, TREAD = 0.15, 0.40
SLOPE = RISE / TREAD
TOP = 0.27
BOTTOM = -0.2


def step(W):
    p = Part("lib_stair_step")
    p.extrude([(0.0, 0.0), (0.0, 0.12)], -W / 2, W / 2, "riser", caps=False)
    p.extrude([(0.0, 0.12), (-0.012, 0.124), (-0.03, 0.132), (-0.036, 0.142), (-0.03, 0.149), (-0.012, 0.15),
               (0.035, 0.15)], -W / 2, W / 2, "brass", caps=True)
    p.extrude([(0.035, 0.15), (TREAD, 0.15)], -W / 2, W / 2, "oak", caps=False)
    for sx in (-1, 1):
        f = p.poly([(sx * W / 2, 0.0, 0.0), (sx * W / 2, TREAD, 0.0), (sx * W / 2, TREAD, 0.15),
                    (sx * W / 2, 0.035, 0.15), (sx * W / 2, 0.0, 0.12)], "riser")[0]
        f.normal_update()
        if f.normal.x * sx < 0:
            f.normal_flip()
    return p


def _sheared(faces, p=None):
    """Rakes a flat run (z += SLOPE * y). With ``p`` the faces first get
    their box-projected metre UVs locked, so the slanted faces keep compact
    atlas islands (projected after the shear, a 4 m side would need a
    4 x 1.6 m box)."""
    if p is not None:
        from artlib.geo import box_project
        for f in faces:
            f.normal_update()
            if not f[p.lock]:
                box_project(f, p.uv)
                f[p.lock] = 1
    for v in {v for f in faces for v in f.verts}:
        v.co.z += SLOPE * v.co.y


def stringer(L=4.0):
    p = Part("lib_stair_stringer")
    prof = [(-0.06, BOTTOM), (-0.06, TOP - 0.1), (-0.08, TOP - 0.08), (-0.08, TOP - 0.04), (-0.05, TOP),
            (0.05, TOP), (0.08, TOP - 0.04), (0.08, TOP - 0.08), (0.06, TOP - 0.1), (0.06, BOTTOM),
            (-0.06, BOTTOM)]
    faces = p.extrude(prof, 0.0, L, "mahogany", caps=False)
    orient_out(faces, (L / 2, 0.0, (TOP + BOTTOM) / 2))
    for sx in (-1, 1):
        faces += p.box((L / 2, sx * 0.062, TOP - 0.13), (L, 0.01, 0.014), "gilt")
    p.move(faces, Matrix.Rotation(math.radians(90), 4, 'Z'))
    _sheared(faces, p)
    return p


def railing(L=4.0):
    p = Part("lib_stair_railing")
    base = p.box((0.0, L / 2, TOP + 0.03), (0.07, L, 0.06), "mahogany", bevel=0.01)
    _sheared(base, p)
    hand_z = TOP + 0.9
    bar = p.box((0.0, L / 2, hand_z - 0.03), (0.03, L, 0.024), "brass")
    _sheared(bar, p)
    hand = p.box((0.0, L / 2, hand_z + 0.01), (0.075, L, 0.06), "mahogany", bevel=0.022)
    _sheared(hand, p)
    n = int(round(L / TREAD))
    for k in range(n):
        y = (k + 0.5) * TREAD
        z0 = TOP + 0.06 + SLOPE * y
        p.lathe([(0.009, 0.0), (0.009, hand_z - 0.04 - (TOP + 0.06))], "iron", segments=6, center=(0.0, y, z0),
                cap_bottom=False, cap_top=False)
        p.box((0.0, y, z0 + 0.4), (0.026, 0.026, 0.03), "brass")
    return p


def newel():
    p = Part("lib_stair_newel")
    p.box((0, 0, 0.07), (0.26, 0.26, 0.14), "mahogany", bevel=0.015)
    p.box((0, 0, 0.6), (0.19, 0.19, 0.92), "mahogany", bevel=0.012)
    for a in range(4):
        f = p.box((0, -0.097, 0.6), (0.12, 0.008, 0.7), "panel", bevel=0.004)
        p.move(f, Matrix.Rotation(math.radians(90 * a), 4, 'Z'))
    p.box((0, 0, 1.09), (0.25, 0.25, 0.06), "mahogany", bevel=0.018)
    p.box((0, 0, 1.135), (0.2, 0.2, 0.03), "brass", bevel=0.008)
    p.lathe([(0.0, 1.15), (0.05, 1.15), (0.035, 1.17), (0.04, 1.19), (0.075, 1.24), (0.08, 1.29), (0.06, 1.34),
             (0.03, 1.36), (0.04, 1.39), (0.02, 1.43), (0.0, 1.44)], "brass", segments=12, cap_bottom=False)
    return p


# --- the spiral -----------------------------------------------------------------------

N_STEPS = 27
SP_RISE = 4.0 / N_STEPS
WALK_R = 1.15
SP_ANGLE = TREAD / WALK_R                      # radians per step
R_COL, R_OUT = 0.13, 1.68


def spiral():
    p = Part("lib_stair_spiral")
    th = 0.05
    for i in range(N_STEPS):
        a0 = i * SP_ANGLE
        a1 = a0 + SP_ANGLE * 1.06               # a little overlap under the next nosing
        ztop = (i + 1) * SP_RISE
        # tread: a wedge from the column to the outer edge (outer arc in 3 pieces)
        ring = [(R_COL * math.cos(a0), R_COL * math.sin(a0))]
        for k in range(4):
            a = a0 + (a1 - a0) * k / 3
            ring.append((R_OUT * math.cos(a), R_OUT * math.sin(a)))
        ring.append((R_COL * math.cos(a1), R_COL * math.sin(a1)))
        faces = p.ngon_prism(ring, ztop - th, ztop, "tread")
        # the leading edge: a brass nosing strip, the outer edge's iron band
        for f in faces:
            f.normal_update()
        nx, ny = -math.sin(a0), math.cos(a0)     # leading-edge outward normal is -(tangent)
        for f in faces:
            c = f.calc_center_median()
            n = f.normal
            if abs(n.z) < 0.5:
                rad = math.hypot(c.x, c.y)
                if rad > R_OUT * 0.96:
                    f.material_index = p.slot("iron")
                elif (n.x * nx + n.y * ny) < -0.8:
                    f.material_index = p.slot("brass")
        # cast-iron bracket under the tread
        mid = a0 + SP_ANGLE * 0.5
        br = p.box((0.0, 0.0, 0.0), (R_OUT - R_COL - 0.1, 0.025, 0.05), "iron")
        p.move(br, Matrix.Rotation(mid, 4, 'Z') @ Matrix.Translation(((R_OUT + R_COL) / 2, 0.0, ztop - th - 0.025)))
        # baluster at the outer edge, rising to the handrail
        ab = a0 + SP_ANGLE * 0.5
        bx, by = (R_OUT - 0.06) * math.cos(ab), (R_OUT - 0.06) * math.sin(ab)
        p.lathe([(0.01, 0.0), (0.01, 0.9)], "iron", segments=6, center=(bx, by, ztop), cap_bottom=False,
                cap_top=False)
        p.box((bx, by, ztop + 0.45), (0.028, 0.028, 0.035), "brass")
        if i % 3 == 2:
            # a brass collar on the column every third step
            p.lathe([(R_COL + 0.02, 0.0), (R_COL + 0.02, 0.025)], "brass", segments=10,
                    center=(0.0, 0.0, ztop - 0.04), cap_bottom=False, cap_top=True)
    # the handrail: a helix over the balusters, mahogany on a brass bar
    hand = []
    hb = []
    for k in range(N_STEPS * 2 + 1):
        a = k * SP_ANGLE / 2 + SP_ANGLE * 0.5
        z = SP_RISE * (k / 2 + 1) + 0.92
        hand.append(((R_OUT - 0.06) * math.cos(a), (R_OUT - 0.06) * math.sin(a), z))
        hb.append(((R_OUT - 0.06) * math.cos(a), (R_OUT - 0.06) * math.sin(a), z - 0.035))
    # in short pieces: one 15 m helix would be a 15 m atlas island
    for k in range(0, len(hand) - 1, 6):
        p.tube(hand[k:k + 7], 0.032, "mahogany", sides=6, caps=False)
        p.tube(hb[k:k + 7], 0.012, "brass", sides=4, caps=False)
    # column foot, shaft and the finial above the top step
    top = N_STEPS * SP_RISE
    p.lathe([(0.0, 0.0), (0.26, 0.0), (0.26, 0.06), (0.2, 0.1), (R_COL, 0.14), (R_COL, top)], "column",
            segments=10, cap_bottom=False, cap_top=False)
    p.lathe([(R_COL, top), (R_COL, top + 0.9), (0.16, 0.94), (0.16, 0.98), (0.1, 1.02), (0.12, 1.07), (0.09, 1.12),
             (0.0, 1.14)], "iron", segments=10, center=(0.0, 0.0, 0.0), cap_bottom=False)
    p.lathe([(0.0, top + 1.14), (0.06, top + 1.16), (0.07, top + 1.22), (0.04, top + 1.27), (0.0, top + 1.29)],
            "brass", segments=10, cap_bottom=False)
    return p


def build():
    only = os.environ.get("ENL_ONLY", "").split(",")

    def want(n):
        return only == [""] or n in only

    from artlib import enl_preview
    enl_preview.tile_material("tread", "enl_oak_boards", (2.0, 2.0))
    fns = {"oak": E.oak_dark, "riser": lambda c: E.mahogany(c, seed=641, center=3.0), "brass": E.worn_brass,
           "mahogany": E.mahogany, "gilt": E.gilt, "iron": E.iron_black, "panel": lambda c: E.mahogany(c, 643, 3.2),
           "column": E.iron_black}
    out = []
    if want("lib_stair_step_1m"):
        out.append(kit("lib_stair_step_1m", [step(1.0)], fns, built_final=True, ppm=128, ao_dist=0.2, preview=False))
    if want("lib_stair_stringer_4m"):
        out.append(kit("lib_stair_stringer_4m", [stringer()], fns, built_final=True, ppm=96, ground=None,
                       preview=False))
    if want("lib_stair_railing_4m"):
        out.append(kit("lib_stair_railing_4m", [railing()], fns, built_final=True, ppm=128, ground=None,
                       ao_dist=0.15, preview=False))
    if want("lib_stair_newel"):
        out.append(kit("lib_stair_newel", [newel()], fns, built_final=True, ppm=160, ao_dist=0.15, preview=False))
    if want("lib_stair_spiral"):
        top = N_STEPS * SP_RISE
        a_top = (N_STEPS - 0.5) * SP_ANGLE
        # modelled in Godot-aligned axes: Blender +X = Godot +X, Blender +Y = Godot -Z
        out.append(kit("lib_stair_spiral", [spiral()], fns, built_final=True, ppm=128, ao_dist=0.25,
                       kinds={"tread": "tile:enl_oak_boards"},
                       markers=[("stair_bottom", (WALK_R * math.cos(SP_ANGLE * 0.5), WALK_R * math.sin(SP_ANGLE * 0.5),
                                                  SP_RISE), None),
                                ("stair_top", (WALK_R * math.cos(a_top), WALK_R * math.sin(a_top), top), None)],
                       preview_yaws=(-30.0, 60.0, 150.0, 240.0), preview_elevation=20.0))
    return out
