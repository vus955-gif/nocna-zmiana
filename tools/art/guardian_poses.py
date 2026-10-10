"""Filmstrips of a guardian's poses (headless Blender, Workbench): the way to
judge code-driven animation without a game window. The game side writes the
poses (tests/scenarios/centaur_poses.gd -> tests/_out/guardian_centaur/
poses.json: strips of frames, each a transform per model part in body
space, Godot axes); this script imports the model once, lays a posed copy of
it per frame in rows of five (orthographic camera from the strip's view: the
side, from behind, three-quarter), with shadows and a floor so the hooves'
contacts read, and renders tests/_out/guardian_centaur/poses_<strip>.png.

Run from the repo root (bash tools/run_guardian.sh centaur --poses does both):
    "D:/Program Files/Blender Foundation/Blender 5.1/blender.exe" -b --factory-startup \\
        --python tools/art/guardian_poses.py -- [--model centaur] [--only gallop,kick]
"""
import json
import math
import sys
from pathlib import Path

import bpy
from mathutils import Matrix, Vector

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from artlib import scene  # noqa: E402

ROOT = HERE.parents[1]
MODELS = ROOT / "assets" / "models"
TEX = ROOT / "assets" / "textures"

# Godot (x, y, z) -> Blender (x, -z, y)
C = Matrix(((1, 0, 0, 0), (0, 0, -1, 0), (0, 1, 0, 0), (0, 0, 0, 1)))
CI = C.inverted()
PER_ROW = 5
ROW_HEIGHT = 4.9
PX_PER_M = 88
# view -> (direction from the subject to the camera, Godot axes), spacing (m)
VIEWS = {
    "side": (Vector((1.0, 0.25, 0.0)), 3.7),
    "back": (Vector((0.15, 0.3, 1.0)), 2.6),
    "three_quarter": (Vector((0.8, 0.3, -0.8)), 3.3),
    "three_quarter_left": (Vector((-0.8, 0.3, -0.8)), 3.3),
}


def godot_matrix(f):
    bx, by, bz, o = Vector(f[0:3]), Vector(f[3:6]), Vector(f[6:9]), Vector(f[9:12])
    return Matrix(((bx.x, by.x, bz.x, o.x), (bx.y, by.y, bz.y, o.y), (bx.z, by.z, bz.z, o.z), (0, 0, 0, 1)))


def to_blender(v):
    return Vector((v.x, -v.z, v.y))


def import_model(name):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(MODELS / f"{name}.glb"))
    new = [o for o in bpy.data.objects if o not in before]
    mat = scene.atlas_material(name, TEX, has_emit=(TEX / f"{name}_emit.png").exists())
    sources = {}
    for o in new:
        if o.type == "MESH":
            for slot in o.material_slots:
                slot.material = mat
            sources[o.name.split(".")[0]] = o
    for o in new:
        o.hide_render = True
        o.hide_viewport = True
    if "javelin" in sources:
        sources["javelin_left"] = sources["javelin"]
    return sources


def floor(center, size, z, mat):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(center.x, center.y, z - 0.05))
    o = bpy.context.active_object
    o.scale = (size.x, size.y, 0.1)
    o.data.materials.append(mat)
    return o


def label(text, at, facing, mat):
    curve = bpy.data.curves.new("label", type="FONT")
    curve.body = text
    curve.size = 0.32
    curve.align_x = "CENTER"
    o = bpy.data.objects.new("label", curve)
    bpy.context.scene.collection.objects.link(o)
    o.location = at
    o.rotation_euler = facing
    o.data.materials.append(mat)
    return o


def plain(name, color):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = color
    return mat


def render_strip(strip, sources, out):
    view, spacing = VIEWS.get(strip["view"], VIEWS["side"])
    toward = to_blender(view.normalized())
    flat = Vector((toward.x, toward.y, 0.0)).normalized()
    right = Vector((0.0, 0.0, 1.0)).cross(flat).normalized()
    frames = strip["frames"]
    rows = (len(frames) + PER_ROW - 1) // PER_ROW
    made = []
    ground = plain("ground", (0.62, 0.62, 0.6, 1.0))
    ink = plain("ink", (0.08, 0.08, 0.1, 1.0))
    for i, frame in enumerate(frames):
        row, col = divmod(i, PER_ROW)
        offset = right * ((col - (PER_ROW - 1) * 0.5) * spacing) + Vector((0.0, 0.0, -row * ROW_HEIGHT))
        place = Matrix.Translation(offset)
        for part, f in frame["parts"].items():
            src = sources.get(part)
            if src is None:
                continue
            if part in frame.get("shown", {}) and not frame["shown"][part]:
                continue
            o = src.copy()
            o.parent = None
            bpy.context.scene.collection.objects.link(o)
            o.hide_render = False
            o.hide_viewport = False
            o.matrix_world = place @ C @ godot_matrix(f) @ CI
            made.append(o)
        made.append(label(frame["label"], offset + right * 0.0 - flat * 0.0 + Vector((0.0, 0.0, -0.45)) + flat * 1.2,
                          (math.radians(90.0), 0.0, math.atan2(flat.y, flat.x) + math.radians(90.0)), ink))
    for row in range(rows):
        center = Vector((0.0, 0.0, 0.0))
        made.append(floor(center, Vector((40.0, 40.0, 0.1)), -row * ROW_HEIGHT, ground))
        # floors of lower rows would hide the upper ones from a camera looking
        # down: keep each floor a strip under its row
        f = made[-1]
        width = PER_ROW * spacing + 2.0
        f.scale = (abs(right.x) * width + abs(flat.x) * 3.0 + 0.5, abs(right.y) * width + abs(flat.y) * 3.0 + 0.5, 0.1)
    sc = bpy.context.scene
    cam = bpy.data.objects.get("_cam")
    if cam is None:
        cam = bpy.data.objects.new("_cam", bpy.data.cameras.new("_cam"))
        sc.collection.objects.link(cam)
    width = PER_ROW * spacing + 0.6
    height = rows * ROW_HEIGHT
    middle = Vector((0.0, 0.0, 1.45 - (rows - 1) * ROW_HEIGHT * 0.5))
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = max(width, height * width / width)
    cam.location = middle + toward * 40.0
    cam.rotation_euler = (-toward).to_track_quat("-Z", "Y").to_euler()
    cam.data.clip_end = 200.0
    sc.camera = cam
    sc.render.resolution_x = int(width * PX_PER_M)
    sc.render.resolution_y = int(height * PX_PER_M)
    sc.render.filepath = str(out)
    bpy.ops.render.render(write_still=True)
    for o in made:
        bpy.data.objects.remove(o, do_unlink=True)


def main(argv):
    model = "centaur"
    only = None
    if "--model" in argv:
        model = argv[argv.index("--model") + 1]
    if "--only" in argv:
        only = set(argv[argv.index("--only") + 1].split(","))
    out_dir = ROOT / "tests" / "_out" / f"guardian_{model}"
    data = json.loads((out_dir / "poses.json").read_text())
    scene.reset()
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_WORKBENCH"
    shading = sc.display.shading
    shading.light = "STUDIO"
    shading.color_type = "TEXTURE"
    shading.show_shadows = True
    shading.shadow_intensity = 0.6
    shading.show_cavity = True
    sc.display.light_direction = (0.35, -0.4, 0.85)
    sc.render.film_transparent = False
    world = bpy.data.worlds.new("w")
    world.color = (0.9, 0.9, 0.88)
    sc.world = world
    sources = import_model(model)
    for strip in data["strips"]:
        if only is not None and strip["name"] not in only:
            continue
        render_strip(strip, sources, out_dir / f"poses_{strip['name']}.png")
    print("poses rendered")


if __name__ == "__main__":
    main(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else [])
