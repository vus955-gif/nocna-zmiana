"""How big every first-person weapon sits on screen, as the game frames it.

Run headless from the repo root (never opens a window):
    "D:/Program Files/Blender Foundation/Blender 5.1/blender.exe" -b --factory-startup \
        --python tools/art/framing_preview.py -- [vm_name=scale,dx,dy,dz[,rx,ry,rz] ...] [--samples=N]

For every viewmodel it places the model exactly like the game: the holder's
REST spot and AIM_YAW turn (WeaponHolder), then the model's FRAMING
(position offset, scale, extra turn) read from src/weapons/viewmodel_rig.gd,
the camera at the eye with the viewmodel's own 55 degree field of view. The
fists are shown at the punch's far point (FIST_HIT). Upgrade parts are hidden
(the plain weapon). An argument vm_name=scale,dx,dy,dz[,rx,ry,rz] (turn in
degrees) tries another framing without editing the game.

Writes tests/_out/art/framing_<name>.png and a 3x3 sheet framing_sheet.png,
and prints each weapon's screen coverage (share of the frame) and the box it
fills (left, top, right, bottom as 0..1 of the frame).
"""
import math
import re
import sys
from pathlib import Path

import bpy
import numpy as np
from mathutils import Euler, Matrix, Vector

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

from artlib import imageio, scene  # noqa: E402

ROOT = HERE.parents[1]
MODELS = ROOT / "assets" / "models"
TEX = ROOT / "assets" / "textures"
OUT = ROOT / "tests" / "_out" / "art"
RIG = ROOT / "src" / "weapons" / "viewmodel_rig.gd"

WEAPONS = ["vm_fists", "vm_taser", "vm_pistol", "vm_shotgun", "vm_gatling", "vm_flare",
           "vm_rifle_hunt", "vm_harpoon", "vm_hwacha"]
REST = Vector((0.17, -0.16, -0.55))         # WeaponHolder.REST
AIM_YAW = 0.1                              # WeaponHolder.AIM_YAW
FIST_HIT = Vector((-0.05, -0.14, -0.62))   # WeaponHolder.FIST_HIT
FIST_TURN = (-0.15, 0.12, -0.45)           # ViewmodelRig._animate_fist at the far point
FOV = 55.0
SIZE = (640, 360)
# Godot (x, y, z) -> Blender (x, -z, y)
G2B = Matrix(((1, 0, 0, 0), (0, 0, -1, 0), (0, 1, 0, 0), (0, 0, 0, 1)))


def read_framing():
    text = RIG.read_text(encoding="utf-8")
    out = {}
    vec = r"Vector3(?:\(([-\d.]+),\s*([-\d.]+),\s*([-\d.]+)\)|\.ZERO)"
    for m in re.finditer(r'&"(vm_\w+)":\s*\[' + vec + r",\s*([-\d.]+),\s*" + vec + r"\]", text):
        off = Vector([float(m.group(i)) for i in (2, 3, 4)]) if m.group(2) else Vector()
        turn = Vector([float(m.group(i)) for i in (6, 7, 8)]) if m.group(6) else Vector()
        out[m.group(1)] = (off, float(m.group(5)), turn)
    return out


def godot_matrix(pos, euler_rad, scale=1.0):
    """Godot Transform3D(Basis.from_euler(e) scaled, pos) as a 4x4 (YXZ order)."""
    rot = Euler((euler_rad[0], euler_rad[1], euler_rad[2]), "YXZ").to_matrix().to_4x4()
    return Matrix.Translation(Vector(pos)) @ rot @ Matrix.Scale(scale, 4)


def view_matrix(name, framing):
    off, scale, turn_deg = framing.get(name, (Vector(), 1.0, Vector()))
    turn = [math.radians(a) for a in turn_deg]
    if name == "vm_fists":
        holder = godot_matrix(FIST_HIT, (0.0, 0.0, 0.0))
        turn = [turn[i] + FIST_TURN[i] for i in range(3)]
    else:
        holder = godot_matrix(REST, (0.0, AIM_YAW, 0.0))
    model = godot_matrix(off, turn, scale)
    return G2B @ holder @ model @ G2B.inverted()


def load(name):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(MODELS / f"{name}.glb"))
    objs = [o for o in bpy.data.objects if o not in before]
    for mat_name in {s.material.name for o in objs if o.type == "MESH" for s in o.material_slots if s.material}:
        base = mat_name.split(".")[0]
        if (TEX / f"{base}_albedo.png").exists():
            scene.atlas_material(base, TEX, has_emit=(TEX / f"{base}_emit.png").exists())
            for o in objs:
                for s in getattr(o, "material_slots", []):
                    if s.material and s.material.name == mat_name:
                        s.material = bpy.data.materials[base]
    return objs


def render(name, framing, samples):
    scene.reset()
    sc = bpy.context.scene
    scene._cycles(sc, samples=samples)
    scene._world(sc)
    sc.render.film_transparent = True
    objs = load(name)
    world = view_matrix(name, framing)
    for o in objs:
        if o.parent is None:
            o.matrix_world = world @ o.matrix_world
        if o.name.startswith("upg_") or o.name in ("clip",):
            o.hide_render = True   # the plain weapon (the rifle's clip shows only in a reload)
    sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
    sun.data.energy = 3.0
    sun.rotation_euler = (math.radians(50), math.radians(-20), math.radians(30))
    sc.collection.objects.link(sun)
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    cam.data.sensor_fit = "VERTICAL"
    cam.data.angle = math.radians(FOV)
    cam.data.clip_start = 0.01
    cam.rotation_euler = (math.radians(90), 0, 0)   # looks along Blender +Y (Godot -Z), up +Z
    sc.collection.objects.link(cam)
    sc.camera = cam
    sc.render.resolution_x, sc.render.resolution_y = SIZE
    tmp = OUT / f"framing_{name}.tmp.png"
    sc.render.filepath = str(tmp)
    bpy.ops.render.render(write_still=True)
    img = bpy.data.images.load(str(tmp))
    px = np.array(img.pixels[:]).reshape(SIZE[1], SIZE[0], 4)[::-1]
    bpy.data.images.remove(img)
    tmp.unlink(missing_ok=True)
    alpha = px[..., 3] > 0.5
    bg = np.array([0.09, 0.1, 0.12])
    rgb = px[..., :3] * px[..., 3:4] + bg * (1.0 - px[..., 3:4])
    imageio.save_png(OUT / f"framing_{name}.png", np.clip(rgb, 0, 1))
    ys, xs = np.nonzero(alpha)
    box = (xs.min() / SIZE[0], ys.min() / SIZE[1], (xs.max() + 1) / SIZE[0], (ys.max() + 1) / SIZE[1]) if len(xs) else (0, 0, 0, 0)
    return rgb, alpha.mean(), box


def main(argv):
    samples = 12
    framing = read_framing()
    for arg in argv:
        if arg.startswith("--samples="):
            samples = int(arg.split("=")[1])
        elif "=" in arg:
            name, values = arg.split("=", 1)
            v = [float(x) for x in values.split(",")]
            turn = Vector(v[4:7]) if len(v) >= 7 else framing.get(name, (None, None, Vector()))[2]
            framing[name] = (Vector(v[1:4]), v[0], turn)
    OUT.mkdir(parents=True, exist_ok=True)
    tiles = []
    for name in WEAPONS:
        rgb, cover, box = render(name, framing, samples)
        off, scale, _turn = framing.get(name, (Vector(), 1.0, Vector()))
        print(f"framing {name:14s} scale {scale:.2f} offset ({off.x:+.3f}, {off.y:+.3f}, {off.z:+.3f})  "
              f"covers {cover * 100:5.1f}%  box ({box[0]:.2f}, {box[1]:.2f}) - ({box[2]:.2f}, {box[3]:.2f})")
        tiles.append(rgb)
    rows = [np.concatenate(tiles[i:i + 3], axis=1) for i in range(0, 9, 3)]
    imageio.save_png(OUT / "framing_sheet.png", np.clip(np.concatenate(rows, axis=0), 0, 1))


if __name__ == "__main__":
    main(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else [])
