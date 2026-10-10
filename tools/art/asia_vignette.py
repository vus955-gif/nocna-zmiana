"""Mood checks for the Asia wing (headless, Cycles): scenes assembled from
the exported models and tile fields, lit with the wing's recipe (paper
lanterns, gold under spotlights, the moon over the open garden). Not game
scenes - an art director's check of scale, palette, light and rig poses.

Run from the repo root (one Blender process, 4 threads, no window):
    "D:/Program Files/Blender Foundation/Blender 5.1/blender.exe" -b -t 4 --factory-startup \
        --python tools/art/asia_vignette.py -- [shots...] [--samples 64] [--size 1280x720]
Shots: hall (China hall corner: kit, Buddha, bronzes), korea (hwacha
display, bell, celadon), armour (armour hall, ashigaru squad), garden
(Japanese garden, tea house, cherry, General), duel (the General's poses),
fu (the Fu dog pair). Writes tests/_out/art/asia_vignette_<shot>.png.
"""
import math
import sys
from pathlib import Path

import bpy
from mathutils import Euler, Matrix, Vector

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from artlib import scene  # noqa: E402

ROOT = HERE.parents[1]
MODELS = ROOT / "assets" / "models"
TEX = ROOT / "assets" / "textures"
OUT = ROOT / "tests" / "_out" / "art"
TILE_PPM = 64.0
WARM = (1.0, 0.62, 0.34)
LANTERN = (1.0, 0.45, 0.28)
MOON = (0.55, 0.67, 1.0)


# --------------------------------------------------------------------------
# materials and placement
# --------------------------------------------------------------------------

def _mat_for(name):
    base = name.split(".")[0]
    if base == "glass":
        return scene.glass_material()
    if base.startswith("tile:"):
        return tile_material(base[5:])
    if (TEX / f"{base}_albedo.png").exists():
        m = scene.atlas_material(base, TEX, has_emit=(TEX / f"{base}_emit.png").exists())
        _alpha(m, base)
        return m
    return None


def _alpha(mat, base):
    """Alpha-cut atlases (blossom): wire the albedo alpha into the BSDF."""
    if base not in ("cherry_tree", "cherry_petals_ground"):
        return
    nt = mat.node_tree
    tex = next((n for n in nt.nodes if n.type == "TEX_IMAGE" and "albedo" in n.image.name), None)
    bsdf = next((n for n in nt.nodes if n.type == "BSDF_PRINCIPLED"), None)
    if tex is not None and bsdf is not None:
        nt.links.new(tex.outputs["Alpha"], bsdf.inputs["Alpha"])


def tile_material(tex, tint=(1.0, 1.0, 1.0)):
    key = "tile_" + tex
    mat = bpy.data.materials.get(key)
    if mat is not None:
        return mat
    img = bpy.data.images.load(str(TEX / f"{tex}_albedo.png"), check_existing=True)
    w, h = img.size[0] / TILE_PPM, img.size[1] / TILE_PPM
    mat = bpy.data.materials.new(key)
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    geo = nt.nodes.new("ShaderNodeNewGeometry")
    mul = nt.nodes.new("ShaderNodeVectorMath")
    mul.operation = "MULTIPLY"
    mul.inputs[1].default_value = (1.0 / w, 1.0 / w, 1.0 / h)
    nt.links.new(geo.outputs["Position"], mul.inputs[0])
    texs = []
    for chan, non_color in (("albedo", False), ("orm", True), ("normal", True)):
        t = nt.nodes.new("ShaderNodeTexImage")
        t.image = bpy.data.images.load(str(TEX / f"{tex}_{chan}.png"), check_existing=True)
        if non_color:
            t.image.colorspace_settings.name = "Non-Color"
        t.interpolation = "Closest"
        t.projection = "BOX"
        nt.links.new(mul.outputs["Vector"], t.inputs["Vector"])
        texs.append(t)
    nt.links.new(texs[0].outputs["Color"], bsdf.inputs["Base Color"])
    sep = nt.nodes.new("ShaderNodeSeparateColor")
    nt.links.new(texs[1].outputs["Color"], sep.inputs["Color"])
    nt.links.new(sep.outputs["Green"], bsdf.inputs["Roughness"])
    nt.links.new(sep.outputs["Blue"], bsdf.inputs["Metallic"])
    return mat


def place(name, loc, yaw=0.0, scale=(1.0, 1.0, 1.0), swap=None):
    """Imports a model, dresses its materials (``swap`` renames a texture
    set), parents it to an empty at ``loc`` turned ``yaw`` degrees about Z."""
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(MODELS / f"{name}.glb"))
    new = [o for o in bpy.data.objects if o not in before]
    holder = bpy.data.objects.new(f"_{name}", None)
    bpy.context.scene.collection.objects.link(holder)
    for o in new:
        o.rotation_mode = "XYZ"
        if o.parent is None:
            o.parent = holder
        if o.type == "MESH":
            for i, slot in enumerate(o.material_slots):
                if slot.material is None:
                    continue
                nm = slot.material.name.split(".")[0]
                if swap and nm in swap:
                    nm = swap[nm]
                m = _mat_for(nm)
                if m is not None:
                    o.material_slots[i].material = m
    holder.location = loc
    holder.rotation_euler = (0.0, 0.0, math.radians(yaw))
    holder.scale = scale
    return holder


def parts_of(holder):
    out = {}
    for o in holder.children_recursive:
        out[o.name.split(".")[0]] = o
    return out


def pose(holder, rotations, moves=None):
    """Turns parts by Godot-axis Euler degrees (x, y, z): the glTF importer
    keeps Godot's frame inside the model (Y up) under its Z-up root, so a
    part's local rotation is applied in its imported parent space."""
    ps = parts_of(holder)
    for name, (rx, ry, rz) in rotations.items():
        o = ps[name]
        o.rotation_mode = "XYZ"
        o.rotation_euler = Euler((math.radians(rx), math.radians(ry), math.radians(rz)), "XYZ")
    for name, d in (moves or {}).items():
        o = ps[name]
        o.location = (o.location.x + d[0], o.location.y + d[1], o.location.z + d[2])
    bpy.context.view_layer.update()


def box(name, center, size, mat):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=center)
    o = bpy.context.active_object
    o.name = name
    o.scale = size
    bpy.ops.object.transform_apply(scale=True)
    o.data.materials.append(mat)
    return o


def run(prefix, a, b, datum, yaw, along, sizes=(4.0, 2.0, 1.0, 0.5)):
    """Lays wall-run modules from ``a`` to ``b`` (points on the wall plane,
    z ignored) at height ``datum``."""
    tags = {4.0: "4m", 2.0: "2m", 1.0: "1m", 0.5: "05m"}
    A, B = Vector(a), Vector(b)
    L = (B - A).length
    d = (B - A).normalized()
    x = 0.0
    for w in sizes:
        while L - x >= w - 1e-6:
            c = A + d * (x + w / 2)
            place(prefix + tags[w], (c.x, c.y, datum), yaw)
            x += w


# --------------------------------------------------------------------------
# lights
# --------------------------------------------------------------------------

def world(color=(0.02, 0.025, 0.045), strength=1.4):
    sc = bpy.context.scene
    w = bpy.data.worlds.new("night")
    w.use_nodes = True
    w.node_tree.nodes["Background"].inputs["Color"].default_value = (*color, 1.0)
    w.node_tree.nodes["Background"].inputs["Strength"].default_value = strength
    sc.world = w


def sun(name, direction, energy, color, angle=0.6):
    ld = bpy.data.lights.new(name, "SUN")
    ld.energy = energy
    ld.color = color
    ld.angle = math.radians(angle)
    o = bpy.data.objects.new(name, ld)
    o.rotation_euler = Vector(direction).normalized().to_track_quat('-Z', 'Y').to_euler()
    bpy.context.scene.collection.objects.link(o)
    return o


def spot(name, at, target, power, color, size=35.0, blend=0.5, radius=0.2):
    ld = bpy.data.lights.new(name, "SPOT")
    ld.energy = power
    ld.color = color
    ld.spot_size = math.radians(size)
    ld.spot_blend = blend
    ld.shadow_soft_size = radius
    o = bpy.data.objects.new(name, ld)
    o.location = at
    o.rotation_euler = (Vector(target) - Vector(at)).normalized().to_track_quat('-Z', 'Y').to_euler()
    bpy.context.scene.collection.objects.link(o)
    return o


def point(name, at, power, color, radius=0.1):
    ld = bpy.data.lights.new(name, "POINT")
    ld.energy = power
    ld.color = color
    ld.shadow_soft_size = radius
    o = bpy.data.objects.new(name, ld)
    o.location = at
    bpy.context.scene.collection.objects.link(o)
    return o


def dust(center, size, density=0.015):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=center)
    v = bpy.context.active_object
    v.scale = size
    vm = bpy.data.materials.new("dust")
    vm.use_nodes = True
    nt = vm.node_tree
    nt.nodes.remove(nt.nodes["Principled BSDF"])
    vol = nt.nodes.new("ShaderNodeVolumePrincipled")
    vol.inputs["Density"].default_value = density
    vol.inputs["Anisotropy"].default_value = 0.5
    vol.inputs["Color"].default_value = (0.85, 0.82, 0.78, 1.0)
    nt.links.new(vol.outputs["Volume"], nt.nodes["Material Output"].inputs["Volume"])
    v.data.materials.append(vm)


def render(path, cam_pos, target, size, samples, lens=18.0):
    sc = bpy.context.scene
    cam = bpy.data.objects.get("_cam")
    if cam is None:
        cd = bpy.data.cameras.new("_cam")
        cam = bpy.data.objects.new("_cam", cd)
        sc.collection.objects.link(cam)
    cam.data.lens = lens
    cam.data.clip_end = 300.0
    cam.location = cam_pos
    cam.rotation_euler = (Vector(target) - Vector(cam_pos)).normalized().to_track_quat('-Z', 'Y').to_euler()
    sc.camera = cam
    sc.render.resolution_x, sc.render.resolution_y = size
    sc.cycles.samples = samples
    sc.cycles.volume_step_rate = 4.0
    sc.cycles.max_bounces = 6
    sc.render.filepath = str(path)
    bpy.ops.render.render(write_still=True)
    print("rendered", path)


def has(name):
    return (MODELS / f"{name}.glb").exists()


# --------------------------------------------------------------------------
# shots
# --------------------------------------------------------------------------

def shot_hall(size, samples):
    """A corner of the China hall (16 x 14 m, 9 m high): grey tile floor,
    lacquered dado, plaster, the painted frieze, the bracket cornice under
    the coffered ceiling, posts, the seated Buddha, bronzes, lanterns."""
    H = 9.0
    box("floor", (0.0, 7.0, -0.25), (18.0, 16.0, 0.5), tile_material("tiles_golden"))
    box("ceil", (0.0, 7.0, H + 0.25), (18.0, 16.0, 0.5), tile_material("asia_coffers"))
    plaster = tile_material("asia_plaster")
    box("wall_back", (0.0, 14.3, H / 2), (18.0, 0.6, H), plaster)
    box("wall_left", (-8.3, 7.0, H / 2), (0.6, 16.0, H), plaster)
    box("wall_right", (8.3, 7.0, H / 2), (0.6, 16.0, H), plaster)
    # wall runs: back wall (faces -y: yaw 180), left wall (faces +x: yaw -90)
    for prefix, datum in (("asia_dado_", 0.0), ("asia_frieze_", 5.0)):
        run(prefix, (8.0, 14.0, 0), (-8.0, 14.0, 0), datum, 180.0, None)
        run(prefix, (-8.0, 14.0, 0), (-8.0, 0.0, 0), datum, -90.0, None)
    run("asia_eaves_", (8.0, 14.0, 0), (-8.0, 14.0, 0), H, 180.0, None, sizes=(4.0, 2.0, 1.0))
    run("asia_eaves_", (-8.0, 14.0, 0), (-8.0, 0.0, 0), H, -90.0, None, sizes=(4.0, 2.0, 1.0))
    for x, y in ((-4.0, 4.0), (4.0, 4.0), (-4.0, 10.0), (4.0, 10.0)):
        if has("asia_post_base"):
            place("asia_post_base", (x, y, 0.0))
            place("asia_post_shaft", (x, y, 0.4), scale=(1.0, 1.0, H - 1.2 - 0.4))
            place("asia_post_capital", (x, y, H))
    if has("buddha_seated"):
        place("buddha_seated", (0.0, 11.4, 0.0), yaw=180.0)
    for k, (x, y) in enumerate(((-6.4, 9.0), (6.4, 9.0))):
        if has("bronze_ding"):
            place("asia_plinth", (x, y, 0.0), yaw=90.0 if x < 0 else -90.0) if has("asia_plinth") else None
            place("bronze_ding", (x, y, 0.9 if has("asia_plinth") else 0.0), yaw=90.0 if x < 0 else -90.0)
    for x, y in ((-4.0, 7.0), (4.0, 7.0), (-4.0, 1.5), (4.0, 1.5)):
        if has("asia_lantern_red"):
            place("asia_lantern_red", (x, y, 5.8))
        point(f"lantern_{x}_{y}", (x, y, 5.8), 260.0, LANTERN, 0.25)
    world((0.02, 0.022, 0.035), 1.0)
    spot("buddha_key", (-3.0, 4.0, 1.2), (0.0, 11.4, 4.5), 9000.0, WARM, 45.0)
    spot("buddha_rim", (5.0, 13.0, 8.4), (0.0, 11.4, 3.0), 3000.0, (1.0, 0.8, 0.6), 40.0)
    spot("moon_in", (6.0, -4.0, 12.0), (-2.0, 9.0, 0.0), 3000.0, MOON, 30.0, radius=0.5)
    dust((0.0, 7.0, H / 2), (16.0, 14.0, H - 0.2), 0.012)
    render(OUT / "asia_vignette_hall.png", (5.6, 0.6, 1.7), (-1.6, 11.0, 4.2), size, samples, lens=17.0)
    render(OUT / "asia_vignette_hall_eaves.png", (-3.0, 7.5, 6.2), (-7.6, 13.0, 8.4), size, samples, lens=24.0)


def room(W, D, H, floor, wall, ceil=None):
    """A box room x -W/2..W/2, y 0..D, height H (walls 0.6 thick outside)."""
    box("floor", (0.0, D / 2, -0.25), (W + 2, D + 2, 0.5), tile_material(floor))
    if ceil:
        box("ceil", (0.0, D / 2, H + 0.25), (W + 2, D + 2, 0.5), tile_material(ceil))
    w = tile_material(wall)
    box("wall_back", (0.0, D + 0.3, H / 2), (W + 2, 0.6, H), w)
    box("wall_front", (0.0, -0.3, H / 2), (W + 2, 0.6, H), w)
    box("wall_left", (-W / 2 - 0.3, D / 2, H / 2), (0.6, D + 2, H), w)
    box("wall_right", (W / 2 + 0.3, D / 2, H / 2), (0.6, D + 2, H), w)


def bands(W, D, H, specs):
    """Wall runs on the back, left and right walls: specs = [(prefix, datum, sizes)]."""
    for prefix, datum, sizes in specs:
        run(prefix, (W / 2, D, 0), (-W / 2, D, 0), datum, 180.0, None, sizes)
        run(prefix, (-W / 2, D, 0), (-W / 2, 0.0, 0), datum, -90.0, None, sizes)
        run(prefix, (W / 2, 0.0, 0), (W / 2, D, 0), datum, 90.0, None, sizes)


def shot_hall2(size, samples):
    """The China hall: the Buddha under spotlights between lacquered posts,
    red lanterns, the Fu dog pair, bronzes on stands, the dougong cornice."""
    W, D, H = 18.0, 16.0, 9.0
    room(W, D, H, "tiles_golden", "asia_plaster", "asia_coffers")
    bands(W, D, H, (("asia_dado_", 0.0, (4.0, 2.0, 1.0, 0.5)), ("asia_frieze_", 5.0, (4.0, 2.0, 1.0, 0.5)),
                    ("asia_eaves_", H, (4.0, 2.0, 1.0))))
    for x in (-4.5, 4.5):
        for y in (4.0, 9.0, 13.0):
            place("asia_post_base", (x, y, 0.0))
            place("asia_post_shaft", (x, y, 0.4), scale=(1.0, 1.0, H - 1.2 - 0.4))
            place("asia_post_capital", (x, y, H))
    place("buddha_seated", (0.0, 13.2, 0.0), yaw=180.0)
    place("bronze_ding", (0.0, 11.25, 0.4), yaw=180.0)
    for sx in (-1, 1):
        place("fu_dog", (sx * 3.0, 6.2, 0.0), yaw=180.0 + sx * 20.0, scale=(-1.0 if sx > 0 else 1.0, 1.0, 1.0))
        place("asia_plinth", (sx * 7.6, 6.0, 0.0), yaw=-sx * 90.0)
        place("bronze_gu", (sx * 7.6, 6.0, 0.9), yaw=-sx * 90.0)
        place("asia_case_tall", (sx * 7.5, 10.0, 0.0), yaw=-sx * 90.0)
        place("vase_blue_white" if sx < 0 else "vase_celadon", (sx * 7.5, 10.0, 0.89), yaw=-sx * 90.0)
        place("scroll_hanging", (sx * 8.95, 2.5, 3.6), yaw=-sx * 90.0,
              swap={"scroll_hanging": "scroll_hanging_water"} if sx > 0 else None)
    for x in (-4.5, 4.5):
        for y in (2.0, 6.5, 11.0):
            place("asia_lantern_red", (x * 0.55, y, 6.0))
            point(f"lantern_{x}_{y}", (x * 0.55, y, 6.0), 180.0, LANTERN, 0.25)
    world((0.02, 0.022, 0.035), 0.8)
    spot("buddha_key", (-3.0, 5.0, 1.0), (0.0, 13.0, 4.6), 14000.0, WARM, 40.0)
    spot("buddha_top", (2.0, 8.0, 8.6), (0.0, 13.0, 4.0), 6000.0, (1.0, 0.85, 0.65), 35.0)
    spot("fu_key", (0.0, 1.5, 6.0), (0.0, 6.0, 1.2), 5000.0, (0.9, 0.85, 0.8), 50.0)
    dust((0.0, D / 2, H / 2), (W - 0.2, D - 0.2, H - 0.2), 0.01)
    render(OUT / "asia_vignette_hall.png", (1.4, 0.4, 1.7), (0.0, 12.0, 4.2), size, samples, lens=18.0)
    spot("fu_face", (-1.0, 3.2, 2.6), (-3.0, 6.0, 1.9), 3000.0, WARM, 30.0)
    render(OUT / "asia_vignette_fu.png", (-1.2, 2.4, 1.3), (-3.0, 6.5, 1.6), size, samples, lens=24.0)


def shot_korea(size, samples):
    """The Korean room: board floor, painted beams with carved brackets, the
    bell pavilion, the hwacha display under a spotlight, celadon and the
    moon jar in cases."""
    W, D, H = 16.0, 14.0, 8.0
    room(W, D, H, "boards_dark", "asia_plaster", "asia_plaster")
    bands(W, D, H, (("asia_dado_", 0.0, (4.0, 2.0, 1.0, 0.5)), ("asia_frieze_", 4.0, (4.0, 2.0, 1.0, 0.5)),
                    ("asia_eaves_", H, (4.0, 2.0, 1.0))))
    for y in (2.0, 6.0, 10.0):
        for k in range(4):
            place("asia_beam_4m", (-6.0 + 4.0 * k, y, H))
        for sx in (-1, 1):
            place("asia_corbel", (sx * W / 2, y, H - 0.42), yaw=-sx * 90.0)
    place("temple_bell", (-3.5, 9.0, 0.0), yaw=200.0)
    place("hwacha_display", (3.2, 7.5, 0.0), yaw=160.0)
    place("vm_hwacha", (3.2 - 0.3, 7.5 - 0.85, 1.25), yaw=170.0, scale=(2.4, 2.4, 2.4))
    for name, x in (("vase_celadon", -6.5), ("moon_jar", 6.5)):
        place("asia_case_tall", (x, 3.0, 0.0), yaw=-90.0 if x > 0 else 90.0)
        place(name, (x, 3.0, 0.89), yaw=-90.0 if x > 0 else 90.0)
    for x in (-5.5, 5.5):
        place("asia_lantern_red", (x * 0.6, 4.0, 5.2))
        point(f"l{x}", (x * 0.6, 4.0, 5.2), 160.0, LANTERN, 0.25)
    world((0.02, 0.022, 0.035), 0.8)
    spot("hwacha_key", (0.5, 2.5, 6.5), (3.2, 7.2, 1.0), 9000.0, WARM, 30.0)
    spot("bell_key", (-0.5, 3.0, 6.0), (-3.5, 9.0, 2.2), 12000.0, (1.0, 0.8, 0.6), 45.0)
    spot("fill", (0.0, 0.5, 7.5), (0.0, 9.0, 1.0), 9000.0, (0.65, 0.72, 0.9), 70.0, radius=1.0)
    point("bell_in", (-3.5, 9.0, 4.4), 300.0, (1.0, 0.7, 0.45), 0.3)
    dust((0.0, D / 2, H / 2), (W - 0.2, D - 0.2, H - 0.2), 0.01)
    render(OUT / "asia_vignette_korea.png", (-1.0, 0.6, 1.7), (0.5, 9.0, 2.4), size, samples, lens=18.0)


def shot_armour(size, samples):
    """The armour hall: dark plaster, lit shoji, armours on their stands, a
    squad of three ashigaru coming out of the gloom."""
    W, D, H = 16.0, 14.0, 7.0
    room(W, D, H, "boards_dark", "asia_plaster_dark", "asia_lacquer_black")
    bands(W, D, H, (("asia_dado_", 0.0, (4.0, 2.0, 1.0, 0.5)), ("asia_eaves_", H, (4.0, 2.0, 1.0))))
    for x in (-5.0, -1.0, 3.0):
        place("asia_shoji_2m", (x + 1.0, D, 1.2), yaw=180.0, swap={"asia_shoji_2m": "asia_shoji_2m_lit"})
    sets = ["samurai_armor_stand", "samurai_armor_stand_blue", "samurai_armor_stand_white"]
    for k, y in enumerate((3.0, 6.5, 10.0)):
        place("samurai_armor_stand", (-7.0, y, 0.0), yaw=-90.0, swap={"samurai_armor_stand": sets[k % 3]})
        place("samurai_armor_stand", (7.0, y, 0.0), yaw=90.0, swap={"samurai_armor_stand": sets[(k + 1) % 3]})
    for x, y, ph in ((-1.6, 6.0, 1), (1.4, 5.2, -1), (0.0, 8.2, 1)):
        h = place("samurai_ashigaru", (x, y, 0.0), yaw=180.0 + x * -4.0)
        pose(h, {"leg_l": (18 * ph, 0, 0), "leg_r": (-18 * ph, 0, 0), "arm_r": (10, 0, 0)})
    for x in (-3.5, 3.5):
        place("asia_lantern_floor", (x, 11.5, 0.0))
        point(f"andon{x}", (x, 11.5, 0.45), 60.0, (1.0, 0.7, 0.4), 0.15)
    world((0.015, 0.018, 0.03), 0.6)
    spot("squad_key", (4.0, 1.0, 5.5), (0.0, 7.0, 1.4), 5000.0, MOON, 35.0, radius=0.4)
    spot("stands_key", (-2.0, 1.5, 6.0), (-7.0, 6.5, 1.5), 3500.0, WARM, 45.0)
    dust((0.0, D / 2, H / 2), (W - 0.2, D - 0.2, H - 0.2), 0.012)
    render(OUT / "asia_vignette_armour.png", (0.8, 0.6, 1.5), (0.0, 7.5, 1.6), size, samples, lens=20.0)


def shot_garden(size, samples):
    """The Japanese garden at night: raked gravel, rocks, lanterns, the pond
    and its bridge, the cherry in bloom, the tea house glowing - and the
    General on its ridge with the bow."""
    box("floor", (10.0, -5.5, -0.25), (30.0, 26.0, 0.5), tile_material("gravel_raked"))
    wl, wu = tile_material("garden_wall"), tile_material("portland_ashlar")
    for name, c, s in (("n", (10.0, 4.8), (30.0, 0.6)), ("e", (23.8, -5.5), (0.6, 26.0)),
                       ("w", (-3.8, -5.5), (0.6, 26.0)), ("s", (10.0, -16.0), (30.0, 0.6))):
        box(f"wl_{name}", (c[0], c[1], 1.5), (s[0], s[1], 3.0), wl)
        box(f"wu_{name}", (c[0], c[1], 8.5), (s[0], s[1], 11.0), wu)
    run("asia_wallcap_", (23.5, 4.5, 0), (3.5, 4.5, 0), 3.0, 180.0, None, (4.0, 2.0, 1.0))
    run("asia_wallcap_", (23.5, -15.7, 0), (23.5, 4.5, 0), 3.0, 90.0, None, (4.0, 2.0, 1.0))
    clay = tile_material("garden_wall")
    box("th_e", (3.25, 0.0, 1.75), (0.5, 9.0, 3.5), clay)
    box("th_s", (0.0, -4.25, 1.75), (7.0, 0.5, 3.5), clay)
    place("teahouse", (0.0, 0.0, 0.0))
    point("tea_glow", (0.0, 0.0, 2.0), 400.0, (1.0, 0.72, 0.42), 1.0)
    place("cherry_tree", (11.0, -3.5, 0.0), yaw=20.0)
    place("cherry_petals_ground", (11.0, -3.5, 0.0))
    place("garden_pond", (10.0, -10.0, 0.0), yaw=10.0)
    place("garden_bridge", (10.5, -10.0, 0.0), yaw=100.0)
    place("garden_rock_a", (17.0, 0.5, 0.0), yaw=30.0)
    place("garden_rock_b", (18.5, -7.0, 0.0), yaw=-20.0)
    place("garden_rock_c", (6.0, -13.5, 0.0))
    place("garden_rock_d", (15.0, -13.0, 0.0), yaw=60.0)
    place("toro_kasuga", (6.2, 2.6, 0.0), yaw=200.0)
    point("toro1", (6.2, 2.6, 1.36), 40.0, (1.0, 0.65, 0.35), 0.1)
    place("toro_yukimi", (13.2, -12.3, 0.0), yaw=120.0)
    point("toro2", (13.2, -12.3, 0.72), 30.0, (1.0, 0.65, 0.35), 0.1)
    g = place("samurai_general", (0.55, 0.0, 7.05), yaw=-90.0)
    pose_general(g, "bow")
    world((0.02, 0.03, 0.06), 1.2)
    sun("moon", (-0.45, 0.35, -0.82), 2.2, MOON, 0.8)
    spot("general_rim", (8.0, 6.0, 12.0), (0.5, 0.0, 8.0), 6000.0, (0.7, 0.8, 1.0), 20.0)
    render(OUT / "asia_vignette_garden.png", (21.0, -14.0, 2.0), (4.0, -1.0, 4.4), size, samples, lens=19.0)


# General poses, Blender Euler degrees per part (Godot: rot.x = x, rot.y = z, rot.z = -y)
GENERAL_POSES = {
    "chudan": {},
    "jodan": {"upperarm_l": (115, 0, 0), "upperarm_r": (115, 0, 0), "torso": (-4, 0, 0), "head": (-6, 0, 0),
              "thigh_l": (-10, 0, 0), "thigh_r": (14, 0, 0), "shin_r": (-14, 0, 0)},
    "cut": {"upperarm_l": (-55, 0, 0), "upperarm_r": (-55, 0, 0), "torso": (-18, 0, -12), "head": (10, 0, 6),
            "thigh_r": (30, 0, 0), "shin_r": (-30, 0, 0), "thigh_l": (-22, 0, 0), "shin_l": (8, 0, 0)},
    "hasso": {"upperarm_l": (85, 0, -10), "upperarm_r": (85, 0, -10), "torso": (0, 0, 35), "head": (0, 0, -30),
              "thigh_l": (12, 0, 0), "thigh_r": (-12, 0, 0)},
    "bow": {"upperarm_l": (80, 0, 25), "upperarm_r": (78, 0, -25), "forearm_r": (0, 0, -60), "torso": (0, 0, 15),
            "head": (0, 0, 20)},
}


def pose_general(holder, name):
    pose(holder, GENERAL_POSES[name])
    if name == "bow":
        # the bow into the left fist, upright, its grip on the fist
        ps = parts_of(holder)
        bow, hand = ps["bow"], ps["hand_l"]
        bpy.context.view_layer.update()
        grip = ps["bow_grip"]
        target = hand.matrix_world.translation
        rot = holder.matrix_world.to_3x3() @ Euler((0.0, math.radians(-8.0), 0.0)).to_matrix()
        local_grip = bow.matrix_world.inverted() @ grip.matrix_world.translation
        bow.matrix_world = Matrix.Translation(target) @ rot.to_4x4() @ Matrix.Translation(-local_grip)
        bpy.context.view_layer.update()


def shot_duel(size, samples):
    """Key poses of the General side by side (a check of the rig: chudan,
    jodan, the cut, hasso)."""
    box("floor", (0.0, 0.0, -0.25), (30.0, 20.0, 0.5), tile_material("gravel_raked"))
    for k, name in enumerate(("chudan", "jodan", "cut", "hasso")):
        g = place("samurai_general", (-6.0 + 4.0 * k, 0.0, 0.0), yaw=160.0)
        pose_general(g, name)
    world((0.02, 0.03, 0.06), 1.3)
    sun("moon", (-0.4, 0.5, -0.75), 2.6, MOON, 0.8)
    spot("key", (2.0, -12.0, 6.0), (0.0, 0.0, 1.6), 30000.0, (1.0, 0.75, 0.5), 40.0)
    render(OUT / "asia_vignette_duel.png", (0.0, -13.0, 2.2), (0.0, 0.0, 1.6), size, samples, lens=30.0)


SHOTS = {"hall": shot_hall2, "korea": shot_korea, "armour": shot_armour, "garden": shot_garden, "duel": shot_duel}


def main(argv):
    samples = 64
    size = (1280, 720)
    if "--samples" in argv:
        samples = int(argv[argv.index("--samples") + 1])
    if "--size" in argv:
        w, h = argv[argv.index("--size") + 1].split("x")
        size = (int(w), int(h))
    names = [a for a in argv if not a.startswith("-") and a in SHOTS] or list(SHOTS)
    for n in names:
        scene.reset()
        sc = bpy.context.scene
        scene._cycles(sc, samples)
        sc.view_settings.view_transform = "AgX"
        sc.view_settings.look = "AgX - Medium High Contrast"
        SHOTS[n](size, samples)
    print("vignette done")


if __name__ == "__main__":
    main(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else [])
