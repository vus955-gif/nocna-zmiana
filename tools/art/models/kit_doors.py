"""Lobby kit: doors, door frames and false panels.

Leaves and panels use Door's leaf frame (src/level/door.gd): origin = centre
of the leaf's base, X across, Z through (Godot +Z = the room A side, -Z =
room B), both faces finished. Frames are single-face wall pieces: origin =
the opening's floor centre on the wall face, trim on the room side (-Z);
put one on each face of a passage.

  door_grand_leaf_l / _r  one leaf of the 4 m wing doors (2 x 4.5 m):
                          walnut stiles and rails, raised lower panel,
                          glazed upper lights with bars (glass object
                          door_grand_leaf_*_glass), brass kick and push
                          plates, pull handle at the meeting stile. _l = the
                          leaf hinged at -X (handle at +X), _r the mirror.
  door_staff_leaf         2 x 2.6 m flush painted door, wired-glass vision
                          panel, lever handles at +X, steel kick plate, the
                          enamel plate "TYLKO DLA PERSONELU" on the +Z face.
  door_slide_leaf         2 x 2.8 m steel service door: pressed ribs, a
                          round wired porthole, recessed pull, hazard
                          chevrons along the bottom.
  doorframe_4x4_5         wing side of the 4 x 4.5 m doors: architrave with
                          plinth blocks and a cornice head (texture sets
                          doorframe_4x4_5 walnut, _stone armory, _paint
                          diorama).
  doorframe_2x2_8         pressed steel frame of the sliding service doors.
  doorframe_2x2_6         painted timber architrave of the staff doors
                          (sets doorframe_2x2_6 cream, _dark).
  false_panel_hall        2 x 2.2 m panel of the balcony wall: limestone
                          ashlar (tilelocal) with the balcony base course on
                          its +Z face, brick on the closet side.
  false_panel_armory      2 x 2.4 m panel of the armory wall: rubble
                          (tilelocal) with the sandstone plinth, brick behind.
  painting_panel          2 x 2.4 m gallery panel: damask (tilelocal),
                          walnut wainscot and a gilt-framed portrait on +Z,
                          braced boards on the secret side.
  vent_grille             1.5 x 2.2 m louvred steel hatch, both faces.
"""
import math

import numpy as np
from mathutils import Matrix

from artlib import arch_materials as A
from artlib import materials as M
from artlib.archkit import kit, moulding
from artlib.geo import Part
from models import kit_hall_bands, kit_room_bands
from models.kit_signs_lamps import _staff_plate

LEAF = 0.12


def _both(p, fn):
    """Runs ``fn(sy)`` for both faces (sy = -1: Godot +Z / room A, +1: -Z)."""
    for sy in (-1, 1):
        fn(sy)


# --- leaves ---------------------------------------------------------------------

def grand_leaf(side):
    """side = +1: meeting stile at +X (hinged at -X)."""
    name = "door_grand_leaf_l" if side > 0 else "door_grand_leaf_r"
    p = Part(name)
    g = Part(name + "_glass")
    W, H = 2.0, 4.5
    hw = W / 2
    st = 0.18
    for x in (-hw + st / 2, hw - st / 2):
        p.box((x, 0, H / 2), (st, LEAF, H), "wood", bevel=0.012)
    for z0, z1 in ((0.0, 0.32), (1.18, 1.42), (4.2, 4.5)):
        p.box((0, 0, (z0 + z1) / 2), (W - 2 * st + 0.01, LEAF, z1 - z0), "wood", bevel=0.012)
    # lower raised panel, recessed in the frame
    p.box((0, 0, 0.75), (W - 2 * st, 0.07, 0.86), "wood", bevel=0.01)
    p.box((0, 0, 0.75), (W - 2 * st - 0.16, 0.1, 0.7), "wood", bevel=0.03)
    # glazed lights: 2 x 4 with bars
    x0, x1, z0, z1 = -hw + st, hw - st, 1.42, 4.2
    p.box((0, 0, (z0 + z1) / 2), (0.05, 0.07, z1 - z0), "wood", bevel=0.008)
    for k in range(1, 4):
        z = z0 + k * (z1 - z0) / 4
        p.box((0, 0, z), (x1 - x0, 0.07, 0.05), "wood", bevel=0.008)
    for sy in (-1, 1):
        y = sy * 0.012
        pts = [(x0, y, z0), (x1, y, z0), (x1, y, z1), (x0, y, z1)]
        f = g.poly(pts, "glass")[0]
        f.normal_update()
        if f.normal.y * sy < 0:
            f.normal_flip()
    # brass: kick plates, push plates and pull handles near the meeting stile
    for sy in (-1, 1):
        y = sy * (LEAF / 2 + 0.002)
        p.box((0, y, 0.17), (W - 0.1, 0.004, 0.26), "brass", bevel=0.002)
        hx = side * (hw - 0.1)
        p.box((hx, y, 1.3), (0.08, 0.004, 0.4), "brass", bevel=0.002)
        p.box((hx - side * 0.02, sy * (LEAF / 2 + 0.06), 1.3), (0.03, 0.03, 0.34), "brass", bevel=0.008)
        for z in (1.15, 1.45):
            p.box((hx - side * 0.02, sy * (LEAF / 2 + 0.03), z), (0.025, 0.06, 0.025), "brass", bevel=0.005)
    return [p, g]


def staff_leaf():
    p = Part("door_staff_leaf")
    W, H = 2.0, 2.6
    p.box((0, 0, H / 2), (W, LEAF - 0.01, H), "paint", bevel=0.01)
    for sy in (-1, 1):
        y = sy * (LEAF / 2 - 0.004)
        p.box((W / 2 - 0.45, y, 1.55), (0.36, 0.01, 0.62), "trim", bevel=0.004)
        p.box((W / 2 - 0.45, y + sy * 0.002, 1.55), (0.3, 0.01, 0.56), "wired", bevel=0.002)
        p.box((0, y, 0.15), (W - 0.06, 0.006, 0.26), "steel", bevel=0.002)
        # lever handle
        hx = W / 2 - 0.12
        p.box((hx, y + sy * 0.004, 1.05), (0.06, 0.008, 0.22), "steel", bevel=0.003)
        p.box((hx, y + sy * 0.035, 1.1), (0.025, 0.06, 0.025), "steel", bevel=0.006)
        p.box((hx - 0.07, y + sy * 0.06, 1.1), (0.14, 0.025, 0.025), "steel", bevel=0.008)
    # the staff-only plate on the room A face (Godot +Z = Blender -Y)
    p.box((0, -(LEAF / 2 - 0.004) - 0.004, 1.75), (0.5, 0.006, 0.12), "plate", bevel=0.002)
    return p


def slide_leaf():
    p = Part("door_slide_leaf")
    W, H = 2.0, 2.8
    p.box((0, 0, H / 2), (W, 0.06, H), "steel", bevel=0.006)
    for sy in (-1, 1):
        y = sy * 0.03
        for x in np.linspace(-0.8, 0.8, 5):
            p.box((x, y + sy * 0.012, 1.25), (0.06, 0.024, 1.9), "steel", bevel=0.012)
        p.box((0, y + sy * 0.012, 2.55), (W - 0.1, 0.024, 0.08), "steel", bevel=0.01)
        p.box((0, y + sy * 0.004, 0.12), (W - 0.02, 0.008, 0.22), "hazard", bevel=0.002)
        # recessed pull near the leading edge (+X)
        p.box((W / 2 - 0.12, y + sy * 0.006, 1.1), (0.08, 0.012, 0.4), "iron", bevel=0.004)
    # round porthole: a wired glass disc in a steel ring on both faces
    for sy in (-1, 1):
        ring = p.lathe([(0.17, 0.0), (0.2, 0.0), (0.2, 0.02), (0.17, 0.025)], "steel", segments=16,
                       cap_bottom=False, cap_top=False)
        # the lathe axis (+Z) turns to point out of this face
        rot = Matrix.Rotation(math.radians(90 if sy < 0 else -90), 4, 'X')
        p.move(ring, Matrix.Translation((0.0, sy * 0.03, 1.95)) @ rot)
        pts = [(0.17 * math.cos(a), sy * 0.032, 1.95 + 0.17 * math.sin(a)) for a in np.linspace(0, math.tau, 17)[:-1]]
        f = p.poly(pts, "wired")[0]
        f.normal_update()
        if f.normal.y * sy < 0:
            f.normal_flip()
    return p


# --- frames -----------------------------------------------------------------------

def frame_grand():
    p = Part("doorframe_4x4_5")
    hw, H = 2.0, 4.5
    path = [(-hw, 0.3), (-hw, H), (hw, H), (hw, 0.3)]
    prof = [(0.0, 0.0), (0.05, 0.0), (0.05, 0.08), (0.07, 0.1), (0.07, 0.18), (0.09, 0.2), (0.09, 0.24),
            (0.05, 0.27), (0.0, 0.27)]
    p.sweep(prof, path, "trim")
    for sx in (-1, 1):
        p.box((sx * (hw + 0.14), -0.05, 0.16), (0.32, 0.1, 0.32), "trim", bevel=0.015)
    top = H + 0.27
    p.box((0, -0.03, top + 0.17), (2 * hw + 0.54, 0.06, 0.34), "trim", bevel=0.01)
    p.extrude([(0.0, top + 0.34), (-0.08, top + 0.34), (-0.08, top + 0.38), (-0.12, top + 0.41), (-0.18, top + 0.46),
               (-0.18, top + 0.5), (-0.14, top + 0.53), (0.0, top + 0.55)], -hw - 0.35, hw + 0.35, "trim", caps=True)
    p.box((0, -0.07, top + 0.17), (1.2, 0.02, 0.22), "trim", bevel=0.01)
    return p


def frame_steel():
    p = Part("doorframe_2x2_8")
    hw, H = 1.0, 2.8
    path = [(-hw, 0.0), (-hw, H), (hw, H), (hw, 0.0)]
    p.sweep([(0.0, 0.0), (0.03, 0.0), (0.035, 0.01), (0.035, 0.07), (0.03, 0.08), (0.0, 0.08)], path, "steel")
    p.box((0, -0.03, H + 0.18), (0.5, 0.02, 0.14), "hazard", bevel=0.004)
    return p


def frame_staff():
    p = Part("doorframe_2x2_6")
    hw, H = 1.0, 2.6
    path = [(-hw, 0.0), (-hw, H), (hw, H), (hw, 0.0)]
    p.sweep([(0.0, 0.0), (0.02, 0.0), (0.02, 0.05), (0.03, 0.07), (0.03, 0.1), (0.015, 0.12), (0.0, 0.125)], path,
            "trim")
    return p


# --- false panels -------------------------------------------------------------

def _panel_box(p, W, H, face_a, face_b, edge):
    """Box with its +Z (Blender -Y) face, -Z face and edges on separate slots."""
    x0, x1, y0, y1 = -W / 2, W / 2, -LEAF / 2, LEAF / 2
    quads = [
        ([(x0, y0, 0), (x1, y0, 0), (x1, y0, H), (x0, y0, H)], (0, -1, 0), face_a),
        ([(x1, y1, 0), (x0, y1, 0), (x0, y1, H), (x1, y1, H)], (0, 1, 0), face_b),
        ([(x0, y1, 0), (x0, y0, 0), (x0, y0, H), (x0, y1, H)], (-1, 0, 0), edge),
        ([(x1, y0, 0), (x1, y1, 0), (x1, y1, H), (x1, y0, H)], (1, 0, 0), edge),
        ([(x0, y0, H), (x1, y0, H), (x1, y1, H), (x0, y1, H)], (0, 0, 1), edge),
    ]
    for pts, want, mat in quads:
        f = p.poly(pts, mat)[0]
        f.normal_update()
        if f.normal.dot(want) < 0:
            f.normal_flip()


def false_panel_hall():
    p = Part("false_panel_hall")
    _panel_box(p, 2.0, 2.2, "face_a", "face_b", "face_a")
    band = kit_hall_bands.upper_base(2.0)
    return [p, _offset(band, -LEAF / 2)]


def false_panel_armory():
    p = Part("false_panel_armory")
    _panel_box(p, 2.0, 2.4, "face_a", "face_b", "face_a")
    band = kit_hall_bands.plinth(2.0)
    return [p, _offset(band, -LEAF / 2)]


def _offset(part, y):
    part.move(list(part.bm.faces), Matrix.Translation((0.0, y, 0.0)))
    part.name = part.name + "_band"
    return part


def painting_panel():
    p = Part("painting_panel")
    _panel_box(p, 2.0, 2.4, "face_a", "face_b", "face_b")
    band = _offset(kit_room_bands.gallery_base(2.0), -LEAF / 2)
    # gilt frame with a portrait, hung from the picture height
    cw, ch, cz = 1.0, 1.25, 1.75
    y = -LEAF / 2 - 0.035
    f = p.poly([(-cw / 2, y, cz - ch / 2), (cw / 2, y, cz - ch / 2), (cw / 2, y, cz + ch / 2), (-cw / 2, y, cz + ch / 2)],
               "canvas")[0]
    f.normal_update()
    if f.normal.y > 0:
        f.normal_flip()
    path = [(-cw / 2, cz - ch / 2), (-cw / 2, cz + ch / 2), (cw / 2, cz + ch / 2), (cw / 2, cz - ch / 2)]
    prof = [(0.035, -0.005), (0.06, 0.0), (0.07, 0.03), (0.09, 0.05), (0.09, 0.07), (0.075, 0.095), (0.06, 0.11),
            (0.03, 0.13), (0.0, 0.13)]
    p.sweep(prof, path, "gold", closed=True, y0=-LEAF / 2)
    # the back: cross bracing on the boards
    for a in (1, -1):
        b = p.box((0, 0, 0), (0.1, 0.03, 2.8), "wood", bevel=0.01)
        p.move(b, Matrix.Translation((0.0, LEAF / 2 + 0.015, 1.2)) @ Matrix.Rotation(a * math.atan2(1.8, 2.2), 4, 'Y'))
    for z in (0.15, 2.25):
        p.box((0, LEAF / 2 + 0.015, z), (1.9, 0.03, 0.12), "wood", bevel=0.01)
    return [p, band]


def vent_grille():
    p = Part("vent_grille")
    W, H = 1.5, 2.2
    for x in (-W / 2 + 0.05, W / 2 - 0.05):
        p.box((x, 0, H / 2), (0.1, LEAF, H), "paint", bevel=0.01)
    for z in (0.05, H - 0.05):
        p.box((0, 0, z), (W - 0.2, LEAF, 0.1), "paint", bevel=0.01)
    p.box((0, 0, H / 2), (W - 0.2, 0.02, H - 0.2), "dark")
    n = 16
    for k in range(n):
        z = 0.14 + k * (H - 0.28) / (n - 1)
        for sy in (-1, 1):
            b = p.box((0, 0, 0), (W - 0.2, 0.012, 0.09), "paint", bevel=0.003)
            p.move(b, Matrix.Translation((0.0, sy * 0.035, z)) @ Matrix.Rotation(math.radians(sy * 40), 4, 'X'))
    for sy in (-1, 1):
        for x in (-W / 2 + 0.05, W / 2 - 0.05):
            for z in np.linspace(0.12, H - 0.12, 6):
                p.box((x, sy * (LEAF / 2 + 0.004), z), (0.018, 0.008, 0.018), "iron", bevel=0.004)
    return p


def _dark(ctx):
    s = A.Surface(ctx.N)
    s.use_ramp(A.P["iron"], shade=np.full(ctx.N, 0.5))
    s.rough = np.full(ctx.N, 0.9)
    return s


def _wired(ctx):
    s = A.Surface(ctx.N)
    u, v = ctx.uvm[:, 0], ctx.uvm[:, 1]
    wire = (np.mod(u + v, 0.025) < ctx.texel) | (np.mod(u - v, 0.025) < ctx.texel)
    s.use_ramp(A.P["crt_glass"], shade=3.0 + ctx.fbm(6.0, 2, 3) * 0.6)
    s.use_ramp(A.P["iron"], mask=wire, shade=np.full(ctx.N, 5.0))
    s.rough = np.where(wire, 0.5, 0.08)
    return s


def _hazard(ctx):
    s = A.Surface(ctx.N)
    u, v = ctx.uvm[:, 0], ctx.uvm[:, 1]
    band = np.mod(u + v, 0.16) < 0.08
    s.use_ramp(A.P["paint_ochre"], shade=6.0 + ctx.fbm(8.0, 2, 2) * 0.5)
    s.use_ramp(A.P["leather"], mask=band, shade=np.full(ctx.N, 1.5))
    scuff = ctx.fbm(14.0, 3, 4) > 0.35
    s.use_ramp(A.P["iron"], mask=scuff, shade=np.full(ctx.N, 3.5))
    s.rough = np.full(ctx.N, 0.5)
    return s


def _portrait(ctx):
    """A dark old-master portrait: a sitter in black with a lace collar
    against a brown ground, limited palette, craquelure."""
    x, z = ctx.p[:, 0], ctx.p[:, 2]
    u = x / 1.0 + 0.5
    v = (z - 1.75) / 1.25 + 0.5
    n = ctx.N
    from artlib import noise
    col = np.zeros((n, 3))
    col[:] = np.array([0.16, 0.11, 0.07]) + (0.06 * (1 - np.abs(u - 0.4)))[:, None]
    head = ((u - 0.5) / 0.14) ** 2 + ((v - 0.66) / 0.18) ** 2 < 1.0
    body = (v < 0.5 - np.abs(u - 0.5) * 0.35) | ((v < 0.45) & (np.abs(u - 0.5) < 0.42))
    collar = (np.abs(v - 0.49) < 0.035 + 0.01 * np.sin(u * 60)) & (np.abs(u - 0.5) < 0.2)
    col[body] = np.array([0.05, 0.05, 0.06])
    face_l = 0.5 + 0.5 * np.clip((0.55 - u) * 3.0, -1, 1)
    col[head] = (np.array([0.78, 0.58, 0.44]) * (0.55 + 0.45 * face_l[:, None]))[head]
    col[collar] = np.array([0.85, 0.82, 0.74])
    eye = head & (np.abs(v - 0.69) < 0.012) & (np.abs(np.abs(u - 0.5) - 0.05) < 0.018)
    col[eye] = np.array([0.12, 0.08, 0.06])
    hair = ((u - 0.5) / 0.16) ** 2 + ((v - 0.74) / 0.16) ** 2 < 1.0
    col[hair & ~head] = np.array([0.1, 0.07, 0.05])
    col[hair & head & (v > 0.78)] = np.array([0.1, 0.07, 0.05])
    vig = np.clip(1.0 - ((u - 0.5) ** 2 + (v - 0.55) ** 2) * 1.6, 0.4, 1.0)
    col *= vig[:, None] * np.array([1.0, 0.93, 0.78])
    f1, f2, _ = noise.worley(np.stack([u * 30.0, v * 38.0, np.zeros(n)], axis=1), 41)
    crack = (f2 - f1) < 0.06
    col[crack] *= 0.7
    s = A.Surface(n)
    q = np.round(col * 12.0) / 12.0
    s.albedo = q
    s.rough = np.full(n, 0.35) + crack * 0.3
    s.height = crack * -0.0006
    return s


def build():
    wood = {"wood": M.wood_dark, "brass": M.brass}
    out = [kit("door_grand_leaf_l", grand_leaf(1), wood, kinds={"glass": "glass"}, built_final=True, ppm=128,
               ao_dist=0.2),
           kit("door_grand_leaf_r", grand_leaf(-1), wood, kinds={"glass": "glass"}, built_final=True, ppm=128,
               ao_dist=0.2, preview=False)]
    paint_cream = lambda c: A.paint(c, "paint_cream", 5.6, rough=0.4, chip=0.4, under="wood_oak")
    out.append(kit("door_staff_leaf", [staff_leaf()], {"paint": paint_cream, "trim": M.iron, "wired": _wired,
                                                      "steel": lambda c: M.steel(c),
                                                      "plate": lambda c: _staff_plate(c, 1.75)},
                   built_final=True, ppm=128, ao_dist=0.15))
    steel_paint = lambda c: A.paint(c, "paint_grey", 5.0, rough=0.45, chip=0.7)
    out.append(kit("door_slide_leaf", [slide_leaf()], {"steel": steel_paint, "hazard": _hazard, "iron": M.iron,
                                                      "wired": _wired}, built_final=True, ppm=128, ao_dist=0.15))
    out.append(kit("doorframe_4x4_5", [frame_grand()], {"trim": M.wood_dark}, wall=True, ao_dist=0.3,
                   variants={"doorframe_4x4_5_stone": {"trim": M.stone},
                             "doorframe_4x4_5_paint": {"trim": lambda c: A.paint(c, "hide", 1.8, rough=0.55)}}))
    out.append(kit("doorframe_2x2_8", [frame_steel()], {"steel": steel_paint, "hazard": _hazard}, ppm=128, wall=True,
                   ao_dist=0.1, preview=False))
    out.append(kit("doorframe_2x2_6", [frame_staff()], {"trim": paint_cream}, ppm=128, wall=True, ao_dist=0.1,
                   preview=False,
                   variants={"doorframe_2x2_6_dark": {"trim": lambda c: A.paint(c, "hide", 1.8, rough=0.5)}}))
    band_fns = {"marble_dark": M.marble_dark, "limestone": A.limestone}
    out.append(kit("false_panel_hall", false_panel_hall(), band_fns, built_final=True,
                   kinds={"face_a": "tilelocal:limestone_ashlar", "face_b": "tilelocal:brick"}, preview=False))
    out.append(kit("false_panel_armory", false_panel_armory(), {"marble_dark": M.marble_dark,
                                                                "limestone": lambda c: M.stone(c)},
                   built_final=True, kinds={"face_a": "tilelocal:stone_rubble", "face_b": "tilelocal:brick"},
                   preview=False))
    out.append(kit("painting_panel", painting_panel(), {"marble_dark": M.marble_dark, "wood_dark": M.wood_dark,
                                                       "gold": M.gold, "canvas": _portrait, "wood": M.wood_oak},
                   built_final=True, ppm=128, kinds={"face_a": "tilelocal:wallpaper", "face_b": "tilelocal:boards"},
                   ao_dist=0.2))
    out.append(kit("vent_grille", [vent_grille()], {"paint": steel_paint, "dark": _dark, "iron": M.iron},
                   built_final=True, ppm=128, ao_dist=0.12))
    return out
