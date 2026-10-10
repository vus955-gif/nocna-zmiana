"""Composed Cycles previews of the Enlightenment wing (Blender, background mode).

Assembles the built kit (assets/models/lib_*.glb + their baked textures) into
a bay of the King's Library the way the level will use it - two tiers of
bookcases with pilasters, the walkway with its fascia, railing and brackets,
the coffered ceiling with a skylight well, the chevron parquet - and lights
it with the wing's recipe (warm green-shaded lamps, a blue moon shaft), then
renders a few shots to tests/_out/art/enl_scene_<shot>.png. Two vignettes
sit away from the bay: the orrery's rotunda (bookcases round the drum, a
starry dome, a flock of flying books) and the natural-history cabinet (the
rifle cabinet, specimen cases, the diorama with the wolf and the raptor,
clocks, globes, the automata).

    "D:/Program Files/Blender Foundation/Blender 5.1/blender.exe" -b --factory-startup \
        --python tools/art/scene_enlight.py -- [shots...] [--samples=N]

Blender axes: z up, the gallery's long axis along +y; Godot -Z (a kit
piece's front) imports as Blender +y, so a piece facing the room from the
west wall (x < 0) is turned -90 degrees about z.
"""
import math
import sys
from pathlib import Path

import bpy
from mathutils import Euler, Vector

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from artlib import enl_preview, scene  # noqa: E402

ROOT = HERE.parents[1]
MODELS = ROOT / "assets" / "models"
TEX = ROOT / "assets" / "textures"
OUT = ROOT / "tests" / "_out" / "art"

_loaded = {}


def _material(name):
    if name in bpy.data.materials and bpy.data.materials[name].get("_enl_ready"):
        return bpy.data.materials[name]
    if name.startswith("tile:"):
        tex = name[5:]
        from artlib import imageio  # noqa: F401
        size = (2.0, 2.0)
        p = TEX / f"{tex}_albedo.png"
        if p.exists():
            img = bpy.data.images.load(str(p), check_existing=True)
            size = (img.size[0] / 64.0, img.size[1] / 64.0)
        mat = enl_preview.tile_material(name, tex, size)
    elif name == "glass":
        mat = scene.glass_material("glass")
    elif (TEX / f"{name}_albedo.png").exists():
        mat = scene.atlas_material(name, TEX, has_emit=(TEX / f"{name}_emit.png").exists())
    else:
        mat = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    mat["_enl_ready"] = True
    return mat


def load(model, swap=None):
    """Imports a .glb once; returns its mesh objects (hidden templates)."""
    key = (model, tuple(sorted((swap or {}).items())))
    if key in _loaded:
        return _loaded[key]
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(MODELS / f"{model}.glb"))
    objs = [o for o in bpy.data.objects if o not in before]
    for o in objs:
        if o.type == "MESH":
            for slot in o.material_slots:
                if slot.material is None:
                    continue
                name = slot.material.name.split(".")[0]
                name = (swap or {}).get(name, name)
                slot.link = "OBJECT"
                slot.material = _material(name)
    templ = bpy.data.collections.get("_templates") or bpy.data.collections.new("_templates")
    for o in objs:
        for c in list(o.users_collection):
            c.objects.unlink(o)
        templ.objects.link(o)
    _loaded[key] = objs
    return objs


def place(model, loc, rot_deg=0.0, scale=(1.0, 1.0, 1.0), swap=None):
    """An instance of ``model`` at ``loc`` (Blender coords) turned about z."""
    objs = load(model, swap)
    root = bpy.data.objects.new(f"{model}_inst", None)
    bpy.context.scene.collection.objects.link(root)
    root.location = Vector(loc)
    root.rotation_euler = Euler((0.0, 0.0, math.radians(rot_deg)))
    root.scale = scale
    copies = {}
    for o in objs:
        c = o.copy()
        bpy.context.scene.collection.objects.link(c)
        copies[o] = c
    for o, c in copies.items():
        if o.parent in copies:
            c.parent = copies[o.parent]
        else:
            c.parent = root
            c.matrix_parent_inverse.identity()
    return root


def box(name, lo, hi, mat):
    me = bpy.data.meshes.new(name)
    x0, y0, z0 = lo
    x1, y1, z1 = hi
    v = [(x0, y0, z0), (x1, y0, z0), (x1, y1, z0), (x0, y1, z0), (x0, y0, z1), (x1, y0, z1), (x1, y1, z1), (x0, y1, z1)]
    f = [(0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)]
    me.from_pydata(v, [], f)
    me.materials.append(mat)
    o = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(o)
    return o


def light(kind, loc, energy, color, size=0.1, rot=None, spot=None):
    ld = bpy.data.lights.new("L", kind)
    ld.energy = energy
    ld.color = color
    if kind in ("POINT", "SPOT"):
        ld.shadow_soft_size = size
    if kind == "SUN":
        ld.angle = math.radians(size)
    if spot:
        ld.spot_size = math.radians(spot)
        ld.spot_blend = 0.4
    o = bpy.data.objects.new("L", ld)
    o.location = loc
    if rot:
        o.rotation_euler = Euler(tuple(math.radians(a) for a in rot))
    bpy.context.scene.collection.objects.link(o)
    return o


# --------------------------------------------------------------------------
# the bay
# --------------------------------------------------------------------------

HALF = 7.0            # gallery 14 m wide: walls at x = -7 and x = +7
PITCH = 2.22          # bookcase module + pilaster
N_MOD = 6
Y0 = -6.0


def build_bay():
    floor = box("floor", (-HALF, Y0 - 2.0, -0.1), (HALF, Y0 + N_MOD * PITCH + 4.0, 0.0), _material("tile:parquet_chevron"))
    plaster = _material("tile:plaster") if (TEX / "plaster_albedo.png").exists() else None
    for sx in (-1, 1):
        box(f"wall{sx}", (sx * HALF + (0 if sx > 0 else -0.3), Y0 - 2.0, 0.0),
            (sx * HALF + (0.3 if sx > 0 else 0.0), Y0 + N_MOD * PITCH + 4.0, 10.0), plaster)
    rot = {-1: -90.0, 1: 90.0}
    lows = ["lib_bookcase_a_2m", "lib_bookcase_b_2m", "lib_bookcase_c_2m"]
    ups = ["lib_bookcase_up_a_2m", "lib_bookcase_up_b_2m"]
    for sx in (-1, 1):
        r = rot[sx]
        for k in range(N_MOD):
            y = Y0 + k * PITCH + PITCH / 2
            low = lows[(k + (sx > 0)) % 3]
            swap = {low: low + "_v2"} if (k + (sx > 0)) % 2 else None
            place(low, (sx * HALF, y, 0.0), r, swap=swap)
            place(ups[(k + (sx < 0)) % 2], (sx * HALF, y, 4.0), r)
            place("lib_bookcase_pilaster_low", (sx * HALF, Y0 + k * PITCH, 0.0), r)
            place("lib_bookcase_pilaster_up", (sx * HALF, Y0 + k * PITCH, 4.0), r)
            place("lib_walkway_bracket", (sx * (HALF - 0.56), Y0 + k * PITCH, 3.7), r)
        place("lib_bookcase_pilaster_low", (sx * HALF, Y0 + N_MOD * PITCH, 0.0), r)
        place("lib_bookcase_pilaster_up", (sx * HALF, Y0 + N_MOD * PITCH, 4.0), r)
        # walkway slab, its fascia, railing and posts
        edge = sx * (HALF - 1.4)
        box(f"walk{sx}", (min(edge, sx * HALF), Y0 - 0.2, 3.7), (max(edge, sx * HALF), Y0 + N_MOD * PITCH + 0.2, 4.0),
            _material("tile:enl_oak_boards"))
        n4 = int(N_MOD * PITCH // 2)
        for k in range(n4):
            y = Y0 + 1.0 + k * 2.0
            place("lib_walkway_fascia_2m", (edge, y, 4.0), r)
            place("lib_railing_2m", (edge + sx * 0.1, y, 4.0), r)
            if k % 2 == 0:
                place("lib_railing_post", (edge + sx * 0.1, y - 1.0, 4.0), r)
        # ceiling cornice
        for k in range(int(N_MOD * PITCH // 4) + 1):
            y = Y0 + 2.0 + k * 4.0
            place("lib_cornice_4m", (sx * HALF, y, 10.0), r,
                  swap={"lib_cornice_4m": "lib_cornice_4m_motto"} if k == 1 else None)
    # ceiling: coffers on a 2 m grid, a skylight well in the middle
    ceil_mat = _material("tile:plaster") if plaster else None
    well_c = (0.0, Y0 + 3 * PITCH)
    for i in range(-3, 3):
        for j in range(-1, int(N_MOD * PITCH // 2) + 1):
            cx, cy = i * 2.0 + 1.0, Y0 + j * 2.0 + 1.0
            if abs(cx - well_c[0]) < 2.0 and abs(cy - well_c[1]) < 2.0:
                continue
            place("lib_coffer_2m", (cx, cy, 10.0), 0.0)
    place("lib_skylight_well_4m", (well_c[0], well_c[1], 10.0), 0.0)
    wx, wy = well_c
    box("roof_a", (-HALF, Y0 - 2.0, 10.0), (HALF, wy - 2.0, 10.3), ceil_mat)
    box("roof_b", (-HALF, wy + 2.0, 10.0), (HALF, Y0 + N_MOD * PITCH + 4.0, 10.3), ceil_mat)
    box("roof_c", (-HALF, wy - 2.0, 10.0), (wx - 2.0, wy + 2.0, 10.3), ceil_mat)
    box("roof_d", (wx + 2.0, wy - 2.0, 10.0), (HALF, wy + 2.0, 10.3), ceil_mat)
    for extra in EXTRAS:
        extra()


def _furnish():
    """End wall with the titled portal, lamps on the pilasters, cases on the axis."""
    y_end = Y0 + N_MOD * PITCH + 4.0
    plaster = _material("tile:plaster")
    box("end_l", (-HALF, y_end, 0.0), (-2.0, y_end + 0.3, 10.0), plaster)
    box("end_r", (2.0, y_end, 0.0), (HALF, y_end + 0.3, 10.0), plaster)
    box("end_t", (-2.0, y_end, 4.5), (2.0, y_end + 0.3, 10.0), plaster)
    box("beyond", (-3.0, y_end + 3.0, 0.0), (3.0, y_end + 3.3, 6.0), _material("tile:enl_mahogany"))
    place("lib_portal_4x4_5", (0.0, y_end, 0.0), 180.0, swap={"lib_portal_4x4_5": "lib_portal_4x4_5_titled"})
    rot = {-1: -90.0, 1: 90.0}
    for sx in (-1, 1):
        for k in range(N_MOD + 1):
            place("lib_lamp_wall", (sx * (HALF - 1.01), Y0 + k * PITCH, 2.6), rot[sx])
            if k % 2 == 0:
                place("lib_lamp_wall", (sx * (HALF - 0.96), Y0 + k * PITCH, 6.7), rot[sx])
        place("lib_ladder_rail_2m", (sx * HALF, Y0 + 2 * PITCH + PITCH / 2, 0.0), rot[sx])
    place("lib_ladder", (-(HALF - 0.62), Y0 + 2 * PITCH + 0.7, 0.0), -90.0)
    for k, name in enumerate(("lib_case_instruments", "lib_case_shells", "lib_case_minerals", "lib_case_coins")):
        place(name, (0.0, Y0 + 1.0 + k * 3.4, 0.0), 90.0 if k % 2 else -90.0)
        place("lib_lamp_standard", (1.25, Y0 + 2.7 + k * 3.4, 1.45), 0.0)
    place("lib_sign", (0.0, y_end - 0.02, 7.6), 180.0)


EXTRAS = [_furnish]


# --------------------------------------------------------------------------
# the orrery's rotunda and the natural-history cabinet (vignettes away from the bay)
# --------------------------------------------------------------------------

ROT = Vector((100.0, 0.0, 0.0))
CAB = Vector((200.0, 0.0, 0.0))


def mesh(name, verts, faces, mat):
    me = bpy.data.meshes.new(name)
    me.from_pydata(verts, [], faces)
    me.materials.append(mat)
    o = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(o)
    return o


def ring_wall(name, c, r, z0, z1, mat, n=40):
    v, f = [], []
    for k in range(n):
        a = math.tau * k / n
        v += [(c.x + r * math.cos(a), c.y + r * math.sin(a), z0), (c.x + r * math.cos(a), c.y + r * math.sin(a), z1)]
    for k in range(n):
        a, b = 2 * k, 2 * ((k + 1) % n)
        f.append((a, a + 1, b + 1, b))          # faces inward
    return mesh(name, v, f, mat)


def dome(name, c, r, z0, mat, n=40, rings=10, oculus=0.12):
    v, f = [], []
    for j in range(rings + 1):
        lat = (math.pi / 2) * (j / rings) * (1.0 - oculus)
        for k in range(n):
            a = math.tau * k / n
            v.append((c.x + r * math.cos(lat) * math.cos(a), c.y + r * math.cos(lat) * math.sin(a),
                      z0 + r * math.sin(lat) * 0.55))
    for j in range(rings):
        for k in range(n):
            a, b = j * n + k, j * n + (k + 1) % n
            f.append((a, a + n, b + n, b))
    return mesh(name, v, f, mat)


def pose_book(root, spread):
    """Opens or closes a placed flying book's covers about their hinges."""
    for o in root.children_recursive:
        base = o.name.split(".")[0]
        if base == "cover_l":
            o.rotation_euler.z += spread
        elif base == "cover_r":
            o.rotation_euler.z -= spread


def build_rotunda():
    o = ROT
    R = 9.5
    box("rot_floor", (o.x - R, o.y - R, -0.1), (o.x + R, o.y + R, 0.0), _material("tile:marble_floor"))
    ring_wall("rot_wall", o, R, 0.0, 12.0, _material("tile:plaster"))
    dome("rot_dome", o, R, 12.0, _material("tile:star_ceiling"))
    orrery = place("planetarium", (o.x, o.y, 0.0), 0.0)
    # the sun half open over its glowing core (as in the last phase of the fight)
    for ob in orrery.children_recursive:
        base = ob.name.split(".")[0]
        if base.startswith("sun_shell_"):
            k = int(base[-1]) - 1
            az = math.radians(30 + 60 * k)
            ob.rotation_mode = "AXIS_ANGLE"
            ob.rotation_axis_angle = (0.75, -math.sin(az), math.cos(az), 0.0)
    # bookcases round the drum between the four doors, lamps on the pilasters
    for k in range(20):
        a = math.tau * (k + 0.5) / 20
        if k % 5 == 2:
            continue
        x, y = o.x + (R - 0.02) * math.cos(a), o.y + (R - 0.02) * math.sin(a)
        rot = math.degrees(a) + 90.0
        place(("lib_bookcase_a_2m", "lib_bookcase_b_2m", "lib_bookcase_c_2m")[k % 3], (x, y, 0.0), rot,
              swap=None if k % 2 else {"lib_bookcase_a_2m": "lib_bookcase_a_2m_v2"})
        b = math.tau * (k + 1) / 20
        place("lib_bookcase_pilaster_low", (o.x + (R - 0.02) * math.cos(b), o.y + (R - 0.02) * math.sin(b), 0.0),
              math.degrees(b) + 90.0)
        if k % 2 == 0:
            lx, ly = o.x + (R - 1.0) * math.cos(b), o.y + (R - 1.0) * math.sin(b)
            place("lib_lamp_wall", (lx, ly, 2.6), math.degrees(b) + 90.0)
    for k in range(8):
        a = math.tau * k / 8
        place("lib_cornice_4m", (o.x + R * math.cos(a), o.y + R * math.sin(a), 12.0), math.degrees(a) + 90.0,
              swap={"lib_cornice_4m": "lib_cornice_4m_motto"} if k == 2 else None)
    # a flock of books coming in over the low arm
    for k, (x, y, z, yaw, spread) in enumerate(((-3.0, -6.2, 2.4, 20.0, 0.3), (-1.6, -7.0, 2.0, -10.0, -0.4),
                                                (-4.2, -5.4, 3.1, 35.0, 0.55), (-2.4, -5.0, 1.6, 5.0, 0.0))):
        swap = [None, {"flying_book": "flying_book_green"}, {"flying_book": "flying_book_blue"},
                {"flying_book": "flying_book_black"}][k]
        book = place("flying_book", (o.x + x, o.y + y, z), 180.0 + yaw, swap=swap)
        pose_book(book, spread)


def build_cabinet():
    o = CAB
    W, D, H = 12.0, 9.0, 7.0
    box("cab_floor", (o.x - W / 2, o.y - D / 2, -0.1), (o.x + W / 2, o.y + D / 2, 0.0), _material("tile:parquet_chevron"))
    paper = _material("tile:wallpaper")
    box("cab_back", (o.x - W / 2, o.y + D / 2, 0.0), (o.x + W / 2, o.y + D / 2 + 0.3, H), paper)
    box("cab_left", (o.x - W / 2 - 0.3, o.y - D / 2, 0.0), (o.x - W / 2, o.y + D / 2, H), paper)
    box("cab_right", (o.x + W / 2, o.y - D / 2, 0.0), (o.x + W / 2 + 0.3, o.y + D / 2, H), paper)
    box("cab_ceiling", (o.x - W / 2, o.y - D / 2, H), (o.x + W / 2, o.y + D / 2, H + 0.3), _material("tile:plaster"))
    for k in range(3):
        place("gallery_base_4m", (o.x - 4.0 + 4.0 * k, o.y + D / 2, 0.0), 180.0)
    yb = o.y + D / 2
    place("lib_rifle_rack", (o.x, yb - 0.3, 0.0), 180.0)
    place("lib_antlers", (o.x, yb, 3.35), 180.0)
    place("lib_nh_shelf_a", (o.x - 2.6, yb - 0.3, 0.0), 180.0)
    place("lib_nh_shelf_b", (o.x + 2.6, yb - 0.3, 0.0), 180.0)
    place("lib_clock_wall", (o.x - W / 2, o.y + 1.0, 0.0), -90.0)
    place("lib_clock_longcase", (o.x - W / 2 + 0.2, o.y - 1.6, 0.0), -90.0)
    place("lib_bird_cage", (o.x + W / 2 - 0.8, o.y + 2.6, 0.0), 0.0)
    place("lib_automaton_writer", (o.x + W / 2 - 1.2, o.y - 0.4, 0.0), 90.0)
    # the diorama with a stuffed wolf and a fossil raptor at its spots (Godot spot (x, y, z) = Blender (x, -z, y))
    dx, dy = o.x - 0.4, o.y - 0.6
    place("lib_diorama_base", (dx, dy, 0.0), 0.0)
    place("wolf", (dx + 0.9, dy - 0.2, 0.33), 25.0)
    place("raptor", (dx - 0.5, dy + 0.1, 0.33), -30.0)
    place("lib_globe_terrestrial", (o.x + 3.2, o.y - 1.6, 0.0), 30.0)
    place("lib_globe_celestial", (o.x - 3.6, o.y - 2.4, 0.0), -20.0)
    place("lib_lamp_standard", (o.x + 2.0, o.y + 1.4, 1.45), 0.0)
    place("lib_lamp_standard", (o.x - 2.3, o.y - 0.6, 1.45), 0.0)


def lights_vignettes():
    o = ROT
    # the sun's core glows, warm wall lamps round the drum, the moon through the oculus
    light("POINT", (o.x, o.y, 5.0), 900.0, (1.0, 0.62, 0.3), size=0.6)
    for k in range(10):
        b = math.tau * (2 * k + 1) / 20
        light("POINT", (o.x + (9.5 - 1.0) * math.cos(b), o.y + (9.5 - 1.0) * math.sin(b), 2.57), 35.0,
              (1.0, 0.72, 0.45), size=0.03)
    light("SPOT", (o.x + 1.0, o.y - 1.0, 18.0), 4000.0, (0.55, 0.67, 1.0), size=0.3, rot=(8.0, 4.0, 0.0), spot=22.0)
    # three museum spots from the cornice on the brass
    for k in range(3):
        a = math.tau * k / 3 + 0.4
        p_ = Vector((o.x + 8.5 * math.cos(a), o.y + 8.5 * math.sin(a), 11.0))
        d = Vector((o.x, o.y, 2.5)) - p_
        ld = light("SPOT", tuple(p_), 2500.0, (1.0, 0.82, 0.6), size=0.2, spot=38.0)
        ld.rotation_euler = d.to_track_quat('-Z', 'Y').to_euler()
    c = CAB
    # the rifle cabinet's picture lamp (its Light marker: 0.43 m out, 2.14 m up), aimed back and down
    light("SPOT", (c.x, c.y + 4.5 - 0.3 - 0.43, 2.12), 260.0, (1.0, 0.8, 0.55), size=0.04, rot=(35.0, 0.0, 0.0),
          spot=80.0)
    for sx in (-2.6, 2.6):
        light("POINT", (c.x + sx, c.y + 4.5 - 0.3 - 0.3, 2.35), 60.0, (1.0, 0.8, 0.55), size=0.1)
    for (x, y) in ((2.0, 1.4), (-2.3, -0.6)):
        light("POINT", (c.x + x, c.y + y, 1.42), 45.0, (1.0, 0.75, 0.5), size=0.03)
    light("POINT", (c.x - 5.0, c.y + 1.0, 4.0), 60.0, (1.0, 0.72, 0.45), size=0.2)
    light("POINT", (c.x + 4.5, c.y + 1.0, 3.5), 50.0, (1.0, 0.72, 0.45), size=0.2)
    light("SPOT", (c.x + 1.5, c.y - 3.0, 9.0), 1500.0, (0.55, 0.67, 1.0), size=0.3, rot=(25.0, 0.0, 10.0), spot=40.0)
    # ceiling spots on the diorama and the globes
    for tgt, e in (((c.x - 0.4, c.y - 0.6, 0.5), 900.0), ((c.x + 3.2, c.y - 1.6, 1.0), 300.0),
                   ((c.x - 3.6, c.y - 2.4, 1.0), 300.0), ((c.x - 5.9, c.y + 1.0, 2.2), 500.0)):
        p_ = Vector((tgt[0] + 0.8, tgt[1] - 1.5, 6.8))
        ld = light("SPOT", tuple(p_), e, (1.0, 0.8, 0.55), size=0.1, spot=32.0)
        ld.rotation_euler = (Vector(tgt) - p_).to_track_quat('-Z', 'Y').to_euler()


def lights_recipe():
    world = bpy.data.worlds.get("enl") or bpy.data.worlds.new("enl")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.012, 0.016, 0.03, 1.0)
    world.node_tree.nodes["Background"].inputs["Strength"].default_value = 1.0
    bpy.context.scene.world = world
    # moon through the skylight: steep, cold
    light("SUN", (0, 0, 20), 1.6, (0.55, 0.67, 1.0), size=0.6, rot=(18.0, 8.0, 20.0))
    # warm lamp pools: bracket lamps on the pilasters (both tiers), reading lamps on the axis
    for sx in (-1, 1):
        for k in range(N_MOD + 1):
            y = Y0 + k * PITCH
            light("POINT", (sx * (HALF - 1.01), y, 2.57), 40.0, (1.0, 0.72, 0.45), size=0.03)
            if k % 2 == 0:
                light("POINT", (sx * (HALF - 0.96), y, 6.67), 30.0, (1.0, 0.72, 0.45), size=0.03)
    for k in range(4):
        light("POINT", (1.25, Y0 + 2.7 + k * 3.4, 1.42), 30.0, (1.0, 0.75, 0.5), size=0.03)
    light("POINT", (0.0, Y0 + N_MOD * PITCH + 6.0, 3.0), 60.0, (1.0, 0.7, 0.45), size=0.2)


SHOTS = {
    # name: (camera location, look-at target, lens mm)
    "gallery": ((-1.2, Y0 - 1.6, 1.65), (0.6, Y0 + 12.0, 3.2), 18.0),
    "shelves": ((-3.6, Y0 + 3.0, 1.6), (-7.0, Y0 + 5.4, 1.7), 28.0),
    "walkway": ((4.9, Y0 + 0.6, 5.65), (4.0, Y0 + 12.0, 4.6), 20.0),
    "ceiling": ((0.0, Y0 + 1.0, 1.7), (0.0, Y0 + 8.0, 9.5), 16.0),
    # the vignettes
    "orrery": ((ROT.x - 1.5, ROT.y - 8.6, 1.6), (ROT.x, ROT.y, 3.4), 16.0),
    "orrery_close": ((ROT.x - 4.6, ROT.y - 4.8, 2.0), (ROT.x + 0.3, ROT.y, 3.4), 20.0),
    "cabinet": ((CAB.x - 0.6, CAB.y - 4.2, 1.65), (CAB.x + 0.2, CAB.y + 3.0, 1.7), 18.0),
    "rifle": ((CAB.x + 0.3, CAB.y + 1.8, 1.6), (CAB.x, CAB.y + 4.4, 1.55), 24.0),
    "clocks": ((CAB.x - 2.4, CAB.y - 2.6, 1.7), (CAB.x - 6.0, CAB.y + 0.6, 2.1), 20.0),
}
BAY_SHOTS = ("gallery", "shelves", "walkway", "ceiling")


def render(shot, samples):
    loc, target, lens = SHOTS[shot]
    cam_data = bpy.data.cameras.new("cam")
    cam_data.lens = lens
    cam_data.clip_start = 0.05
    cam_data.clip_end = 200.0
    cam = bpy.data.objects.get("cam") or bpy.data.objects.new("cam", cam_data)
    cam.data = cam_data
    if cam.name not in bpy.context.scene.collection.objects:
        bpy.context.scene.collection.objects.link(cam)
    cam.location = Vector(loc)
    d = Vector(target) - Vector(loc)
    cam.rotation_euler = d.to_track_quat('-Z', 'Y').to_euler()
    sc = bpy.context.scene
    sc.camera = cam
    scene._cycles(sc, samples)
    sc.cycles.max_bounces = 6
    sc.render.resolution_x = 1280
    sc.render.resolution_y = 720
    sc.view_settings.view_transform = "AgX"
    sc.view_settings.look = "AgX - Medium High Contrast"
    sc.render.filepath = str(OUT / f"enl_scene_{shot}.png")
    bpy.ops.render.render(write_still=True)


def main(argv):
    samples = 48
    shots = []
    for a in argv:
        if a.startswith("--samples="):
            samples = int(a.split("=")[1])
        elif not a.startswith("-"):
            shots.append(a)
    scene.reset()
    shots = shots or list(SHOTS)
    if any(s in BAY_SHOTS for s in shots):
        build_bay()
        lights_recipe()
    if any(s not in BAY_SHOTS for s in shots):
        build_rotunda()
        build_cabinet()
        lights_vignettes()
        if not any(s in BAY_SHOTS for s in shots):
            world = bpy.data.worlds.get("enl") or bpy.data.worlds.new("enl")
            world.use_nodes = True
            world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.012, 0.016, 0.03, 1.0)
            bpy.context.scene.world = world
    for s in shots:
        render(s, samples)
        print("shot", s)


if __name__ == "__main__":
    main(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else [])
