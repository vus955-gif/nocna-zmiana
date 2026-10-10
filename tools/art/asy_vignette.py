"""Mood check for the Assyrian wing (headless, Cycles): rooms assembled from
the exported models and tile fields, lit the way the wing should be lit -
low, harsh, torch-red, with a cold night fill - to judge scale, palette and
light before the level is built. Not a game scene.

  asy_vignette_gallery.png    the Nimrud palace gallery: relief slabs in
                              several themes, the frieze, cedar beams,
                              torches; a slab cracking open, the relief warrior
                              stepping out of the next one, a relief lion
  asy_vignette_gate.png       the Khorsabad Gate seen from Egypt through the
                              opened seal doors of the junction
  asy_vignette_gate_hall.png  the gate from the hall side: archivolt, doors
  asy_vignette_courtyard.png  the Lamassu in the moonlit palace courtyard

Run from the repo root:
    "D:/Program Files/Blender Foundation/Blender 5.1/blender.exe" -b -t 4 --factory-startup \\
        --python tools/art/asy_vignette.py -- [--samples 64] [--size 1280x720] [--only gallery]
"""
import math
import sys
from pathlib import Path

import bpy
from mathutils import Vector

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from artlib import scene  # noqa: E402

ROOT = HERE.parents[1]
MODELS = ROOT / "assets" / "models"
TEX = ROOT / "assets" / "textures"
OUT = ROOT / "tests" / "_out" / "art"
TILE_PPM = 64.0
TORCH = (1.0, 0.42, 0.16)
MOON = (0.5, 0.62, 1.0)


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
    for chan, non_color in (("albedo", False), ("orm", True)):
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


def _mat_for(name, swap):
    base = name.split(".")[0]
    base = swap.get(base) or base
    if base == "glass":
        return scene.glass_material()
    if base.startswith("tile:"):
        return tile_material(base[5:])
    if (TEX / f"{base}_albedo.png").exists():
        mat = scene.atlas_material(base, TEX, has_emit=(TEX / f"{base}_emit.png").exists())
        return mat
    return None


def place(name, loc, yaw=0.0, scale=(1.0, 1.0, 1.0), swap=None, emit=None):
    """Imports a model (glTF), re-dresses its materials (``swap`` renames a
    texture set), parents it to an empty at ``loc`` turned ``yaw`` degrees."""
    swap = swap or {}
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
                m = _mat_for(slot.material.name, swap)
                if m is not None:
                    if emit is not None and m.node_tree.nodes.get("Principled BSDF") is not None:
                        m.node_tree.nodes["Principled BSDF"].inputs["Emission Strength"].default_value = emit
                    o.material_slots[i].material = m
    holder.location = loc
    holder.rotation_euler = (0.0, 0.0, math.radians(yaw))
    holder.scale = scale
    return holder


def parts(holder):
    return {o.name.split(".")[0]: o for o in holder.children_recursive}


def box(name, center, size, mat):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=center)
    o = bpy.context.active_object
    o.name = name
    o.scale = size
    bpy.ops.object.transform_apply(scale=True)
    o.data.materials.append(mat)
    return o


def point(name, at, power, color, radius=0.08):
    ld = bpy.data.lights.new(name, "POINT")
    ld.energy = power
    ld.color = color
    ld.shadow_soft_size = radius
    o = bpy.data.objects.new(name, ld)
    o.location = at
    bpy.context.scene.collection.objects.link(o)


def spot(name, at, target, power, color, size=40.0):
    ld = bpy.data.lights.new(name, "SPOT")
    ld.energy = power
    ld.color = color
    ld.spot_size = math.radians(size)
    ld.spot_blend = 0.6
    ld.shadow_soft_size = 0.3
    o = bpy.data.objects.new(name, ld)
    o.location = at
    o.rotation_euler = (Vector(target) - Vector(at)).normalized().to_track_quat('-Z', 'Y').to_euler()
    bpy.context.scene.collection.objects.link(o)


def world(strength=1.0, color=(0.02, 0.025, 0.045)):
    w = bpy.data.worlds.new("night")
    w.use_nodes = True
    w.node_tree.nodes["Background"].inputs["Color"].default_value = (*color, 1.0)
    w.node_tree.nodes["Background"].inputs["Strength"].default_value = strength
    bpy.context.scene.world = w


def sun(direction, energy, color):
    ld = bpy.data.lights.new("moon", "SUN")
    ld.energy = energy
    ld.color = color
    ld.angle = math.radians(0.6)
    o = bpy.data.objects.new("moon", ld)
    o.rotation_euler = Vector(direction).normalized().to_track_quat('-Z', 'Y').to_euler()
    bpy.context.scene.collection.objects.link(o)


def dust(center, size, density=0.012):
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


def fresh(samples):
    scene.reset()
    sc = bpy.context.scene
    scene._cycles(sc, samples)
    sc.view_settings.view_transform = "AgX"
    sc.view_settings.look = "AgX - Medium High Contrast"


# --------------------------------------------------------------------------
# the Nimrud gallery
# --------------------------------------------------------------------------

def gallery(size, samples):
    fresh(samples)
    HW, L, H = 5.0, 20.0, 7.0
    floor, wall, upper, ceil = (tile_material(t) for t in ("flagstone_asy", "asy_alabaster", "asy_plaster", "asy_cedar"))
    box("floor", (0, L / 2, -0.25), (2 * HW + 2, L + 2, 0.5), floor)
    box("ceiling", (0, L / 2, H + 0.25), (2 * HW + 2, L + 2, 0.5), ceil)
    for sx in (-1, 1):
        box(f"wall_{sx}", (sx * (HW + 0.3), L / 2, H / 2), (0.6, L + 2, H), upper)
    box("back", (0, -0.3, H / 2), (2 * HW + 2, 0.6, H), upper)
    for sx in (-1.0, 1.0):
        box(f"end_{sx}", (sx * 3.5, L + 0.3, H / 2), (3.0, 0.6, H), upper)
    box("end_top", (0, L + 0.3, (4.5 + H) / 2), (4.0, 0.6, H - 4.5), upper)
    themes = [None, "asy_relief_army_2m", "asy_relief_chariot_2m", "asy_relief_text_2m", "asy_relief_hunt_2m",
              None, "asy_relief_genie_l_2m", "asy_relief_army_2m", "asy_relief_lions_2m", "asy_relief_plain_2m"]
    for k in range(10):
        y = 1.0 + 2.0 * k
        for sx in (-1, 1):
            t = themes[(k + (3 if sx > 0 else 0)) % len(themes)]
            if sx < 0 and k == 4:
                place("asy_relief_wake", (sx * HW, y - 0.5, 0.0), yaw=90.0 * sx, emit=6.0)
                place("asy_relief_1m", (sx * HW, y + 0.5, 0.0), yaw=90.0 * sx)
                continue
            if sx < 0 and k == 6:
                w = place("asy_relief_wake", (sx * HW, y - 0.5, 0.0), yaw=90.0 * sx)
                parts(w)["figure"].hide_render = True
                place("asy_relief_1m", (sx * HW, y + 0.5, 0.0), yaw=90.0 * sx, swap={"asy_relief_1m": "asy_relief_army_1m"})
                continue
            place("asy_relief_2m", (sx * HW, y, 0.0), yaw=90.0 * sx, swap={"asy_relief_2m": t} if t else None)
        for sx in (-1, 1):
            if k % 2 == 0:
                place("asy_frieze_4m", (sx * HW, y + 1.0, 3.0), yaw=90.0 * sx)
    for k in range(5):
        y = 2.0 + 4.0 * k
        for x in (-3.33, 0.0, 3.33):
            place("asy_beam_4m", (x, y, H), scale=(0.84, 1.0, 1.0))
        for sx in (-1, 1):
            place("asy_corbel", (sx * HW, y, H - 0.44), yaw=90.0 * sx)
    for y in (4.0, 8.0, 12.0, 16.0):
        for sx in (-1, 1):
            place("asy_torch", (sx * (HW - 0.36), y, 3.45), yaw=90.0 * sx)
            point(f"torch_{sx}_{y}", (sx * (HW - 0.36), y, 3.5), 140.0, TORCH)
    place("asy_portal_4m", (0.0, L, 0.0), yaw=180.0)
    place("asy_threshold_4m", (0.0, L - 0.2, 0.0), scale=(1.0, 0.35, 1.0))
    # the warrior who stepped out of the slab at y = 12.5, mid-stride, spear raised
    w = place("relief_warrior", (-3.4, 11.6, 0.0), yaw=158.0)
    p = parts(w)
    p["leg_front"].rotation_euler = (0.0, math.radians(14.0), 0.0)
    p["leg_back"].rotation_euler = (0.0, math.radians(-12.0), 0.0)
    p["arm_front"].rotation_euler = (0.0, math.radians(-120.0), 0.0)
    p["head"].rotation_euler = (0.0, math.radians(4.0), 0.0)
    lion = place("relief_lion", (2.2, 8.4, 0.0), yaw=152.0)
    p = parts(lion)
    p["leg_fl"].rotation_euler = (0.0, math.radians(-38.0), 0.0)
    p["leg_fr"].rotation_euler = (0.0, math.radians(-28.0), 0.0)
    p["leg_bl"].rotation_euler = (0.0, math.radians(22.0), 0.0)
    p["leg_br"].rotation_euler = (0.0, math.radians(14.0), 0.0)
    p["body"].rotation_euler = (0.0, math.radians(-10.0), 0.0)
    p["body"].location = (p["body"].location.x, p["body"].location.y, p["body"].location.z + 0.18)
    p["jaw"].rotation_euler = (0.0, math.radians(10.0), 0.0)
    for k in range(6):
        place("asy_gypsum_chips", (-4.2 + 0.1 * k, 12.4 + 0.07 * k, 0.0), yaw=37.0 * k, scale=(0.6, 0.6, 0.6))
    world(1.2)
    spot("cold_end", (0.0, L + 3.0, 5.5), (0.0, 8.0, 0.0), 6000.0, MOON, 60.0)
    point("glow_wake", (-4.4, 8.5, 1.5), 60.0, (1.0, 0.45, 0.15), 0.4)
    dust((0, L / 2, H / 2), (2 * HW - 0.2, L - 0.2, H - 0.1), 0.01)
    bpy.context.view_layer.update()
    render(OUT / "asy_vignette_gallery.png", (0.6, 0.8, 1.65), (-0.4, 14.0, 1.9), size, samples, lens=17.0)


# --------------------------------------------------------------------------
# the Khorsabad Gate
# --------------------------------------------------------------------------

def gate(size, samples):
    fresh(samples)
    floor, wall, upper, ceil = (tile_material(t) for t in ("flagstone_asy", "asy_alabaster", "asy_plaster", "asy_cedar"))
    sand = tile_material("asy_plaster")
    box("floor", (0, 4.0, -0.25), (30, 30, 0.5), floor)
    box("ceiling", (0, 4.0, 10.25), (30, 30, 0.5), ceil)
    # the wall with the 6 x 8 m opening (Egypt at -y)
    box("wall_l", (-10.5, -0.5, 5.0), (15.0, 1.0, 10.0), sand)
    box("wall_r", (10.5, -0.5, 5.0), (15.0, 1.0, 10.0), sand)
    box("wall_top", (0, -0.5, 9.0), (6.0, 1.0, 2.0), sand)
    box("wall_east", (4.3, 6.0, 5.0), (0.6, 13.0, 10.0), upper)
    box("hall_end", (0, 13.0, 5.0), (30, 0.6, 10.0), upper)
    g = place("khorsabad_gate", (0.0, 0.0, 0.0))
    p = parts(g)
    for d in ("door_l", "door_r"):
        p[d].rotation_euler = (0.0, 0.0, math.radians(70.0 if d == "door_l" else -70.0))
    for sx in (-1, 1):
        place("asy_torch", (sx * 3.2, 4.95, 3.8))
        point(f"torch_{sx}", (sx * 3.2, 4.95, 3.85), 160.0, TORCH)
        place("asy_brazier", (sx * 1.0, -2.2, 0.0))
        point(f"brazier_{sx}", (sx * 1.0, -2.2, 1.45), 260.0, TORCH, 0.2)
    world(1.0)
    spot("egypt_key", (-2.0, -9.0, 3.0), (0.0, 1.0, 3.2), 5000.0, (1.0, 0.75, 0.5), 35.0)
    spot("moon_hall", (5.0, 10.0, 9.5), (0.0, 2.0, 2.0), 4000.0, MOON, 50.0)
    dust((0, 0, 5.0), (20, 20, 9.9), 0.008)
    bpy.context.view_layer.update()
    render(OUT / "asy_vignette_gate.png", (-1.4, -9.5, 1.65), (0.2, 2.0, 3.4), size, samples, lens=18.0)
    spot("hall_key", (-3.5, 10.0, 8.5), (0.0, 4.6, 5.0), 5000.0, MOON, 45.0)
    spot("hall_fill", (3.0, 9.0, 1.0), (0.0, 4.6, 6.5), 2500.0, (1.0, 0.6, 0.35), 50.0)
    render(OUT / "asy_vignette_gate_hall.png", (-1.2, 12.2, 2.2), (0.3, 3.0, 4.6), size, samples, lens=16.0)


# --------------------------------------------------------------------------
# the palace courtyard with the Lamassu
# --------------------------------------------------------------------------

def courtyard(size, samples):
    fresh(samples)
    floor, wall, brick = (tile_material(t) for t in ("tiles_asy_brick", "asy_alabaster", "asy_mudbrick"))
    HW, HD, H = 12.0, 11.0, 9.0
    box("floor", (0, 0, -0.25), (2 * HW + 2, 2 * HD + 2, 0.5), floor)
    for sx in (-1, 1):
        box(f"wall_x{sx}", (sx * (HW + 0.3), 0, H / 2), (0.6, 2 * HD + 2, H), brick)
        box(f"wall_y{sx}", (0, sx * (HD + 0.3), H / 2), (2 * HW + 2, 0.6, H), brick)
    for k in range(int(2 * HD / 2)):
        y = -HD + 1.0 + 2.0 * k
        for sx in (-1, 1):
            place("asy_relief_2m", (sx * HW, y, 0.0), yaw=90.0 * sx, swap={"asy_relief_2m": "asy_relief_chariot_2m"})
    for k in range(int(2 * HW / 2)):
        x = -HW + 1.0 + 2.0 * k
        place("asy_relief_2m", (x, HD, 0.0), yaw=180.0, swap={"asy_relief_2m": "asy_relief_army_2m" if k % 2 else None})
        place("asy_parapet_2m", (x, HD + 0.3, H))
        if k % 2 == 0:
            place("asy_frieze_4m", (x + 1.0, HD, 3.0), yaw=180.0)
    for k in range(int(2 * HD / 2)):
        for sx in (-1, 1):
            place("asy_parapet_2m", (sx * (HW + 0.3), -HD + 1.0 + 2.0 * k, H), yaw=90.0)
    lam = place("lamassu", (0.0, 1.5, 0.0), yaw=200.0)
    p = parts(lam)
    p["wing_l"].rotation_euler = (0.0, math.radians(-38.0), 0.0)
    p["wing_r"].rotation_euler = (0.0, math.radians(38.0), 0.0)
    p["wing_l_tip"].rotation_euler = (0.0, math.radians(-18.0), 0.0)
    p["wing_r_tip"].rotation_euler = (0.0, math.radians(18.0), 0.0)
    p["thigh_fr"].rotation_euler = (math.radians(-28.0), 0.0, 0.0)
    p["shin_fr"].rotation_euler = (math.radians(40.0), 0.0, 0.0)
    p["head"].rotation_euler = (math.radians(6.0), 0.0, math.radians(-10.0))
    for x, y in ((-4.0, -3.0), (4.5, -2.0), (-5.0, 5.0)):
        place("asy_brazier", (x, y, 0.0))
        point(f"brazier_{x}", (x, y, 1.45), 320.0, TORCH, 0.2)
    world(1.6, (0.03, 0.04, 0.07))
    sun((0.35, 0.55, -0.6), 3.5, MOON)
    dust((0, 0, H / 2), (2 * HW, 2 * HD, H), 0.006)
    bpy.context.view_layer.update()
    spot("lamassu_key", (-5.0, -4.0, 6.0), (0.0, 1.5, 2.6), 9000.0, (1.0, 0.62, 0.36), 35.0)
    render(OUT / "asy_vignette_courtyard.png", (2.2, -5.2, 1.1), (-0.3, 1.5, 2.9), size, samples, lens=18.0)


def main(argv):
    samples = 64
    size = (1280, 720)
    if "--samples" in argv:
        samples = int(argv[argv.index("--samples") + 1])
    if "--size" in argv:
        w, h = argv[argv.index("--size") + 1].split("x")
        size = (int(w), int(h))
    only = argv[argv.index("--only") + 1] if "--only" in argv else None
    for name, fn in (("gallery", gallery), ("gate", gate), ("courtyard", courtyard)):
        if only is None or only == name:
            fn(size, samples)
    print("vignette done")


if __name__ == "__main__":
    main(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else [])
