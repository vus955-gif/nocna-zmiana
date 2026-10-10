"""Mood check for the Egypt wing kit (headless, Cycles): a 40 m stretch of the
Great Gallery assembled from the exported models and tile fields - granite
floor, sandstone walls with dado, frieze and cavetto cornice, painted beams
under a starry ceiling, clerestory windows letting the moon in through
their stone grilles (shafts in a dusty volume), papyrus columns, the avenue
of striding kings, the 1898 camp with its lamp, the seated colossus on his
throne under warm spotlights at the far end.

Not a game scene - an art-director's check of scale, palette and light
before the level is built. Run from the repo root:
    "D:/Program Files/Blender Foundation/Blender 5.1/blender.exe" -b --factory-startup \
        --python tools/art/egypt_vignette.py -- [--samples 96] [--size 1280x720]
Writes tests/_out/art/egypt_vignette_gallery.png and _colossus.png.
"""
import math
import sys
from pathlib import Path

import bpy
import numpy as np
from mathutils import Matrix, Vector

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from artlib import imageio, scene  # noqa: E402

ROOT = HERE.parents[1]
MODELS = ROOT / "assets" / "models"
TEX = ROOT / "assets" / "textures"
OUT = ROOT / "tests" / "_out" / "art"
TILE_PPM = 64.0

L, HW, H = 40.0, 8.0, 11.0          # gallery length, half width, height


def _mat_for(name):
    base = name.split(".")[0]
    if base == "glass":
        return scene.glass_material()
    if base.startswith("tile:"):
        return tile_material(base[5:])
    if (TEX / f"{base}_albedo.png").exists():
        return scene.atlas_material(base, TEX, has_emit=(TEX / f"{base}_emit.png").exists())
    return None


def tile_material(tex):
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
    return mat


def place(name, loc, yaw=0.0, scale=(1.0, 1.0, 1.0)):
    """Imports a model, re-dresses its materials, parents it to an empty at
    ``loc`` turned ``yaw`` degrees about Z."""
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(MODELS / f"{name}.glb"))
    new = [o for o in bpy.data.objects if o not in before]
    holder = bpy.data.objects.new(f"_{name}", None)
    bpy.context.scene.collection.objects.link(holder)
    for o in new:
        if o.parent is None:
            o.parent = holder
        if o.type == "MESH":
            for i, slot in enumerate(o.material_slots):
                if slot.material is None:
                    continue
                m = _mat_for(slot.material.name)
                if m is not None:
                    o.material_slots[i].material = m
    holder.location = loc
    holder.rotation_euler = (0.0, 0.0, math.radians(yaw))
    holder.scale = scale
    return holder


def box(name, center, size, mat):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=center)
    o = bpy.context.active_object
    o.name = name
    o.scale = size
    bpy.ops.object.transform_apply(scale=True)
    o.data.materials.append(mat)
    return o


def build_room():
    floor = tile_material("granite_floor")
    wall = tile_material("sandstone_ashlar")
    ceil = tile_material("star_ceiling")
    box("floor", (0.0, L / 2, -0.25), (2 * HW + 2, L + 2, 0.5), floor)
    box("ceiling", (0.0, L / 2, H + 0.25), (2 * HW + 2, L + 2, 0.5), ceil)
    box("end", (0.0, L + 0.3, H / 2), (2 * HW + 2, 0.6, H), wall)
    box("back", (0.0, -2.3, H / 2), (2 * HW + 2, 0.6, H), wall)
    win_z0, win_z1 = 8.2, 10.2
    for sx in (-1, 1):
        x = sx * (HW + 0.3)
        box(f"wall_low_{sx}", (x, L / 2, win_z0 / 2), (0.6, L + 2, win_z0), wall)
        box(f"wall_top_{sx}", (x, L / 2, (win_z1 + H) / 2), (0.6, L + 2, H - win_z1), wall)
        ys = [4.0 + 8.0 * k for k in range(5)]
        edges = [-1.0] + [v for y in ys for v in (y - 1.5, y + 1.5)] + [L + 1.0]
        for a, b in zip(edges[0::2], edges[1::2]):
            box(f"pier_{sx}_{a}", (x, (a + b) / 2, (win_z0 + win_z1) / 2), (0.6, b - a, win_z1 - win_z0), wall)
        for y in ys:
            place("egypt_clerestory_3m", (sx * HW, y, win_z0), yaw=90.0 * sx)
        # bands along the wall: dado, frieze at 7 m, cornice under the ceiling
        for k in range(int(L / 4)):
            y = 2.0 + 4.0 * k
            place("egypt_dado_4m", (sx * HW, y, 0.0), yaw=90.0 * sx)
            place("egypt_frieze_4m", (sx * HW, y, 7.0), yaw=90.0 * sx)
            place("egypt_cornice_4m", (sx * HW, y, H), yaw=90.0 * sx)
    for k in range(int(L / 4)):
        y = 2.0 + 4.0 * k
        for j in range(4):
            place("egypt_beam_4m", (-6.0 + 4.0 * j, y, H), yaw=0.0)


def dress():
    for k, y in enumerate((4.0, 12.0, 20.0, 28.0)):
        for sx in (-1, 1):
            place("egypt_column", (sx * 4.6, y, 0.0))
    for y in (8.0, 16.0, 24.0):
        for sx in (-1, 1):
            place("pharaoh_statue", (sx * 6.6, y, 0.0), yaw=90.0 * sx)
            place("egypt_torch_lamp", (sx * (HW - 0.32), y + 2.0, 3.6), yaw=90.0 * sx)
    place("colossus_throne", (0.0, 34.5, 0.0), yaw=180.0)
    place("colossus", (0.0, 34.5, 0.0), yaw=180.0)
    for sx in (-1, 1):
        place("obelisk", (sx * 4.2, 30.0, 0.0))
    place("sarcophagus", (2.2, 12.0, 0.0), yaw=90.0)
    # the 1898 camp
    place("camp_tent", (-2.4, 19.5, 0.0), yaw=200.0)
    place("camp_table", (0.4, 17.6, 0.0), yaw=170.0)
    place("camp_chair", (0.3, 18.5, 0.0), yaw=-10.0)
    place("camp_crate", (-3.6, 16.6, 0.0), yaw=188.0)
    place("camp_crate_long", (-2.9, 15.9, 0.0), yaw=165.0)
    place("camp_crate_open", (2.6, 18.6, 0.0), yaw=150.0)
    place("camp_rifle_rack", (1.7, 20.2, 0.0), yaw=155.0)
    place("camp_lamp", (0.75, 17.5, 0.76))
    place("rosetta_case", (-3.2, 1.2, 0.0), yaw=200.0)
    place("rosetta_stone", (-3.2, 1.2, 0.62), yaw=200.0)


def lights():
    sc = bpy.context.scene
    moon = bpy.data.lights.new("moon", "SUN")
    moon.energy = 9.0
    moon.color = (0.55, 0.67, 1.0)
    moon.angle = math.radians(0.6)
    mo = bpy.data.objects.new("moon", moon)
    d = Vector((0.62, 0.25, -0.75)).normalized()
    mo.rotation_euler = d.to_track_quat('-Z', 'Y').to_euler()
    sc.collection.objects.link(mo)
    world = bpy.data.worlds.new("night")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.02, 0.025, 0.045, 1.0)
    world.node_tree.nodes["Background"].inputs["Strength"].default_value = 1.6
    sc.world = world

    def spot(name, at, target, power, color, size=35.0):
        ld = bpy.data.lights.new(name, "SPOT")
        ld.energy = power
        ld.color = color
        ld.spot_size = math.radians(size)
        ld.spot_blend = 0.5
        ld.shadow_soft_size = 0.2
        o = bpy.data.objects.new(name, ld)
        o.location = at
        o.rotation_euler = (Vector(target) - Vector(at)).normalized().to_track_quat('-Z', 'Y').to_euler()
        sc.collection.objects.link(o)

    warm = (1.0, 0.72, 0.42)
    spot("colossus_key", (-3.0, 27.0, 1.0), (0.0, 34.0, 6.5), 9000.0, warm, 40.0)
    spot("colossus_fill", (3.5, 28.0, 0.8), (0.0, 34.0, 4.0), 4000.0, warm, 45.0)
    for y in (8.0, 16.0, 24.0):
        for sx in (-1, 1):
            spot(f"statue_{sx}_{y}", (sx * 3.2, y - 3.5, 0.4), (sx * 6.6, y, 4.2), 6000.0, warm, 30.0)

    def point(name, at, power, color, radius=0.1):
        ld = bpy.data.lights.new(name, "POINT")
        ld.energy = power
        ld.color = color
        ld.shadow_soft_size = radius
        o = bpy.data.objects.new(name, ld)
        o.location = at
        sc.collection.objects.link(o)

    for y in (8.0, 16.0, 24.0):
        for sx in (-1, 1):
            point(f"torch_{sx}_{y}", (sx * (HW - 0.32), y + 2.0, 3.6), 300.0, (1.0, 0.62, 0.32))
    point("camp_lamp", (0.75, 17.5, 0.93), 500.0, (1.0, 0.6, 0.3), 0.05)
    spot("camp_key", (-1.5, 14.0, 4.0), (1.5, 20.0, 0.9), 3000.0, warm, 40.0)
    # dust in the air: a faint volume so the moon draws its shafts
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0.0, L / 2, H / 2))
    v = bpy.context.active_object
    v.scale = (2 * HW - 0.2, L + 3.0, H - 0.1)
    vm = bpy.data.materials.new("dust")
    vm.use_nodes = True
    nt = vm.node_tree
    nt.nodes.remove(nt.nodes["Principled BSDF"])
    vol = nt.nodes.new("ShaderNodeVolumePrincipled")
    vol.inputs["Density"].default_value = 0.02
    vol.inputs["Anisotropy"].default_value = 0.55
    vol.inputs["Color"].default_value = (0.85, 0.82, 0.75, 1.0)
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
    cam.data.clip_end = 200.0
    cam.location = cam_pos
    cam.rotation_euler = (Vector(target) - Vector(cam_pos)).normalized().to_track_quat('-Z', 'Y').to_euler()
    sc.camera = cam
    sc.render.resolution_x, sc.render.resolution_y = size
    sc.cycles.samples = samples
    sc.cycles.volume_step_rate = 4.0
    sc.cycles.max_bounces = 6
    sc.render.filepath = str(path)
    bpy.ops.render.render(write_still=True)


def stand_up(holder_name="_colossus"):
    """Poses the colossus standing in front of its throne (phase 3), only by
    turning and moving its jointed parts - a check of the rig's pivots."""
    holder = bpy.data.objects[holder_name]
    parts = {}
    for o in holder.children_recursive:
        o.rotation_mode = "XYZ"           # the glTF importer leaves quaternions
        parts[o.name.split(".")[0]] = o
    pel = parts["pelvis"]
    pel.location = (pel.location.x, pel.location.y + 4.4, 5.02)
    for side in ("l", "r"):
        parts["thigh_" + side].rotation_euler = (math.radians(-90.0), 0.0, 0.0)
        parts["shin_" + side].rotation_euler = (math.radians(90.0), 0.0, 0.0)
        parts["forearm_" + side].rotation_euler = (math.radians(-70.0), 0.0, 0.0)
        parts["upperarm_" + side].rotation_euler = (math.radians(8.0), 0.0, 0.0)
    parts["head"].rotation_euler = (math.radians(8.0), 0.0, math.radians(12.0))
    bpy.context.view_layer.update()


def main(argv):
    samples = 96
    only_standing = "--standing" in argv
    size = (1280, 720)
    if "--samples" in argv:
        samples = int(argv[argv.index("--samples") + 1])
    if "--size" in argv:
        w, h = argv[argv.index("--size") + 1].split("x")
        size = (int(w), int(h))
    scene.reset()
    sc = bpy.context.scene
    scene._cycles(sc, samples)
    sc.view_settings.view_transform = "AgX"
    sc.view_settings.look = "AgX - Medium High Contrast"
    build_room()
    dress()
    lights()
    if not only_standing:
        render(OUT / "egypt_vignette_gallery.png", (-1.4, -1.2, 1.75), (0.6, 30.0, 3.8), size, samples)
        render(OUT / "egypt_vignette_colossus.png", (-3.2, 25.0, 1.2), (0.0, 34.5, 5.6), size, samples, lens=16.0)
    stand_up()
    render(OUT / "egypt_vignette_standing.png", (2.2, 22.6, 1.7), (0.0, 30.2, 5.6), size, samples, lens=16.0)
    print("vignette done")


if __name__ == "__main__":
    main(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else [])
