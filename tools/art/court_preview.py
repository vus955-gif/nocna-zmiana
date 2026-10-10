"""The Great Court assembled from its exported models, lit like the game at
night (moon through the glass roof, volumetric fog, a few warm lamps) and
rendered in Cycles, headless:

    "D:/Program Files/Blender Foundation/Blender 5.1/blender.exe" -b --factory-startup \
        --python tools/art/court_preview.py -- [shot names...] [--samples=64] [--size=1280x720]

Reads assets/models/*.glb (whatever exists: missing models are skipped or
stood in by grey blocks), writes tests/_out/art/court_<shot>.png. The
placements below are the ones described in docs/art/kit-pietro1-dziedziniec.md
(Godot coordinates: x east, y up, -z north, court centre = origin); they are
a proposal for the level, not the level itself.
"""
import math
import re
import sys
from pathlib import Path

import bpy
from mathutils import Euler, Vector

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from artlib import scene  # noqa: E402

ROOT = HERE.parents[1]
MODELS = ROOT / "assets" / "models"
TEX = ROOT / "assets" / "textures"
OUT = ROOT / "tests" / "_out" / "art"

# moon of the game's light recipe (Godot direction, colour)
MOON_DIR = Vector((-0.28, -0.9, -0.33))
MOON_COLOR = (0.55, 0.67, 1.0)
SEG = 22.5


def godot_to_blender(p):
    return Vector((p[0], -p[2], p[1]))


# --------------------------------------------------------------------------
# placements (Godot): (model, (x, y, z), yaw degrees)
# --------------------------------------------------------------------------

def placements():
    out = []
    for k in range(4):
        out.append(("court_roof_q", (0, 0, 0), 90.0 * k))
    for k in range(16):
        out.append(("rr_drum_door" if k % 4 == 0 else "rr_drum_wall", (0, 0, 0), SEG * k))
    for k in range(16):
        out.append(("rr_bookcase_door" if k % 4 == 0 else "rr_bookcase", (0, 0, 0), SEG * k))
        out.append(("rr_dome_sector", (0, 0, 0), SEG * k))
    out.append(("rr_oculus", (0, 0, 0), 0.0))
    for k in range(4):
        out.append(("rr_catalogue_arc", (0, 0, 0), 45.0 + 90.0 * k))
    # eight radial desks on the odd lines, the door aisles (k = 0, 4, 8, 12) open
    for k in range(1, 16, 2):
        a = math.radians(SEG * k)
        r = 6.5
        out.append(("rr_desk", (-math.sin(a) * r, 0, -math.cos(a) * r), SEG * k))
    # the exhibition "Wiek pary i stali" in the south-west quarter
    out.append(("steam_engine", (-5.2, 0, 3.6), 30.0))
    out.append(("steam_banner", (-2.6, 0, 7.4), 160.0))
    out.append(("steam_podium", (-7.6, 0, 1.4), 0.0))
    out.append(("knight", (-7.6, 0.32, 1.4), 200.0))
    out.append(("gatling_display", (5.3, 0, 3.4), -30.0))
    out.append(("astrolabe", (0, 0, 0), 0.0))
    # balcony round the north half: k = -4 .. 4, open at both ends where the
    # straight flights land (west k = 4, east k = -4)
    for k in range(-4, 5):
        out.append(("court_balcony_seg_open" if abs(k) == 4 else "court_balcony_seg", (0, 0, 0), SEG * k))
    for sx in (-1, 1):
        x = sx * 18.1
        z0 = 19.4                       # the flight's foot (StairsSpec frame origin)
        out.append(("court_stair_mass", (x, 0, z0), 0.0, (3.0, 7.0, 18.8)))
        for i in range(47):
            out.append(("court_stair_step", (x, i * 7.0 / 47, z0 - i * 0.4), 0.0))
        for k in range(5):
            for side in (-1, 1):
                out.append(("court_stair_parapet_4m", (x + side * 1.66, k * 1.4894, z0 - 4.0 * k), 0.0))
        # landing beside the open balcony face, parapets round it
        out.append(("court_landing", (x, 0, -1.34), 0.0, (3.1, 7.0, 3.9)))
        out.append(("court_parapet_2m", (x + sx * 1.71, 7.0, -0.4), 90.0))
        out.append(("court_parapet_2m", (x + sx * 1.71, 7.0, -2.3), 90.0))
        out.append(("court_parapet_2m", (x, 7.0, -3.3), 0.0))
    out.append(("trex", (0, 1.2, -22.0), -90.0))
    out.append(("trex_pedestal", (0, 0, -22.0), 0.0))
    out.append(("totem_haida", (22.0, 0, -22.0), -135.0))
    for x in (-24.0, -18.0):
        out.append(("court_bench", (x, 0, 20.0), 0.0))
    out.append(("court_info_desk", (0, 0, 21.0), 0.0))
    out.append(("cafe_counter", (-24.0, 0, -27.0), 0.0))
    for i, (x, z) in enumerate(((-25.0, -21.0), (-21.0, -23.0), (-17.5, -20.5), (-24.0, -16.5), (-20.0, -17.0))):
        out.append(("cafe_table", (x, 0, z), 15.0 * i))
    out.append(("shop_front", (24.0, 0, 29.6), 180.0))
    for x, z in ((-16.0, 16.0), (16.0, 16.0), (-16.0, -16.0), (16.0, -16.0)):
        out.append(("court_lamp_post", (x, 0, z), 0.0))
    for name, x, z, yaw in (("sign_wing", -27.0, -6.0, 90.0), ("sign_wing", 27.0, -6.0, -90.0)):
        out.append((name, (x, 0, z), yaw))
    return out


# --------------------------------------------------------------------------
# materials
# --------------------------------------------------------------------------

def tile_material(name, tex_name):
    """World-mapped tile (64 px/m) like the game's arch_tiled shader."""
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    path = TEX / f"{tex_name}_albedo.png"
    if not path.exists():
        bsdf.inputs["Base Color"].default_value = (0.5, 0.5, 0.5, 1)
        return mat
    img = bpy.data.images.load(str(path), check_existing=True)
    size = Vector((img.size[0] / 64.0, img.size[1] / 64.0, img.size[1] / 64.0))
    geo = nt.nodes.new("ShaderNodeNewGeometry")
    mp = nt.nodes.new("ShaderNodeMapping")
    mp.inputs["Scale"].default_value = (1.0 / size.x, 1.0 / size.x, 1.0 / size.y)
    nt.links.new(geo.outputs["Position"], mp.inputs["Vector"])
    tx = nt.nodes.new("ShaderNodeTexImage")
    tx.image = img
    tx.interpolation = "Closest"
    tx.projection = "BOX"
    nt.links.new(mp.outputs["Vector"], tx.inputs["Vector"])
    nt.links.new(tx.outputs["Color"], bsdf.inputs["Base Color"])
    orm_path = TEX / f"{tex_name}_orm.png"
    if orm_path.exists():
        orm = nt.nodes.new("ShaderNodeTexImage")
        orm.image = bpy.data.images.load(str(orm_path), check_existing=True)
        orm.image.colorspace_settings.name = "Non-Color"
        orm.interpolation = "Closest"
        orm.projection = "BOX"
        nt.links.new(mp.outputs["Vector"], orm.inputs["Vector"])
        sep = nt.nodes.new("ShaderNodeSeparateColor")
        nt.links.new(orm.outputs["Color"], sep.inputs["Color"])
        nt.links.new(sep.outputs["Green"], bsdf.inputs["Roughness"])
        nt.links.new(sep.outputs["Blue"], bsdf.inputs["Metallic"])
    return mat


# emission strengths as ArtLibrary.EXTRAS gives them in the game
EMISSIVE = {"court_lamp_post": 4.0, "rr_desk": 3.5, "rr_drum_door": 3.0, "rr_drum_wall": 2.0,
            "rr_dome_sector": 1.2, "court_info_desk": 2.0, "sconce": 4.0}


def dress(obj):
    for slot in obj.material_slots:
        if slot.material is None:
            continue
        name = re.sub(r"\.\d{3}$", "", slot.material.name)
        key = "_prev:" + name
        mat = bpy.data.materials.get(key)
        if mat is None:
            if name == "glass":
                mat = scene.glass_material(key)
            elif name.startswith("tile:") or name.startswith("tilelocal:"):
                mat = tile_material(key, name.split(":", 1)[1])
            elif (TEX / f"{name}_albedo.png").exists():
                emit = (TEX / f"{name}_emit.png").exists()
                mat = scene.atlas_material(name, TEX, has_emit=emit)
                mat.name = key
                if emit:
                    bsdf = mat.node_tree.nodes.get("Principled BSDF")
                    bsdf.inputs["Emission Strength"].default_value = EMISSIVE.get(name, 3.0)
            else:
                mat = bpy.data.materials.new(key)
        slot.material = mat
    if all(re.sub(r"\.\d{3}$", "", s.material.name.replace("_prev:", "")) == "glass"
           for s in obj.material_slots if s.material):
        obj.visible_shadow = False


# --------------------------------------------------------------------------
# scene
# --------------------------------------------------------------------------

def load_model(name, cache):
    if name in cache:
        return cache[name]
    path = MODELS / f"{name}.glb"
    if not path.exists():
        cache[name] = None
        return None
    coll = bpy.data.collections.new("M_" + name)
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(path))
    new = [o for o in bpy.data.objects if o not in before]
    for o in new:
        for c in list(o.users_collection):
            c.objects.unlink(o)
        coll.objects.link(o)
        if o.type == "MESH":
            dress(o)
    cache[name] = coll
    return coll


def place(name, pos, yaw, cache, scale=None):
    if name == "court_landing":
        mat = bpy.data.materials.get("_prev:floor")
        size = Vector(scale)
        b = box("landing", godot_to_blender((pos[0], size.y / 2, pos[2])), (size.x, size.z, size.y), mat)
        return b
    coll = load_model(name, cache)
    if coll is None:
        return None
    inst = bpy.data.objects.new(f"I_{name}", None)
    inst.instance_type = "COLLECTION"
    inst.instance_collection = coll
    inst.location = godot_to_blender(pos)
    inst.rotation_euler = Euler((0.0, 0.0, math.radians(yaw)))
    if scale is not None:
        inst.scale = (scale[0], scale[2], scale[1])
    bpy.context.scene.collection.objects.link(inst)
    return inst


def box(name, center, size, mat):
    me = bpy.data.meshes.new(name)
    obj = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(obj)
    import bmesh
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=Vector(size), verts=bm.verts)
    bmesh.ops.translate(bm, vec=Vector(center), verts=bm.verts)
    bm.to_mesh(me)
    me.materials.append(mat)
    return obj


def shell(cache):
    """Court floor and walls (the level's shell, in the court's tile fields)."""
    floor = tile_material("_prev:floor", "limestone_court")
    wall = tile_material("_prev:wall", "portland_ashlar")
    box("floor", (0, 0, -0.25), (60.0, 60.0, 0.5), floor)
    for sx, sy, w, d in ((0, 1, 61.0, 1.0), (0, -1, 61.0, 1.0), (1, 0, 1.0, 61.0), (-1, 0, 1.0, 61.0)):
        box("wall", (sx * 30.5, sy * 30.5, 9.5), (w, d, 19.0), wall)
    if load_model("rr_drum_wall", cache) is None:
        bpy.ops.mesh.primitive_cylinder_add(vertices=16, radius=12.5, depth=22.4, location=(0, 0, 11.2))
        bpy.context.active_object.data.materials.append(wall)
    # the Reading Room floor
    carpet = tile_material("_prev:carpet", "carpet_reading")
    bpy.ops.mesh.primitive_cylinder_add(vertices=16, radius=11.4, depth=0.02, location=(0, 0, 0.01))
    bpy.context.active_object.data.materials.append(carpet)


def lights():
    sc = bpy.context.scene
    world = bpy.data.worlds.new("night")
    world.use_nodes = True
    bg = world.node_tree.nodes["Background"]
    bg.inputs["Color"].default_value = (0.012, 0.018, 0.04, 1.0)
    bg.inputs["Strength"].default_value = 1.0
    sc.world = world
    moon = bpy.data.lights.new("moon", "SUN")
    moon.energy = 2.0
    moon.color = MOON_COLOR
    moon.angle = math.radians(0.5)
    mo = bpy.data.objects.new("moon", moon)
    d = godot_to_blender(MOON_DIR).normalized()
    mo.rotation_euler = (-d).to_track_quat('Z', 'Y').to_euler()
    sc.collection.objects.link(mo)
    # fog inside the court: forward scattering, so the shafts glow toward the moon
    vol = bpy.data.materials.new("_fog")
    vol.use_nodes = True
    nt = vol.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    pv = nt.nodes.new("ShaderNodeVolumePrincipled")
    pv.inputs["Density"].default_value = 0.016
    pv.inputs["Anisotropy"].default_value = 0.55
    pv.inputs["Color"].default_value = (0.78, 0.83, 0.95, 1.0)
    nt.links.new(pv.outputs["Volume"], out.inputs["Volume"])
    fog = box("fog", (0, 0, 11.5), (59.0, 59.0, 23.0), vol)
    fog.visible_shadow = False
    # warm lamps (lamp posts, the Reading Room desks)
    for x, z in ((-16.0, 16.0), (16.0, 16.0), (-16.0, -16.0), (16.0, -16.0)):
        lamp = bpy.data.lights.new("lamp", "POINT")
        lamp.energy = 1400.0
        lamp.color = (1.0, 0.7, 0.42)
        lamp.shadow_soft_size = 0.2
        lo = bpy.data.objects.new("lamp", lamp)
        lo.location = godot_to_blender((x, 4.2, z))
        sc.collection.objects.link(lo)
    # the Reading Room: an uplight on the cornice of every dome sector (the
    # rr_dome_sector marker Light_Dome) and the glow of the desk lamps
    for k in range(16):
        a = math.radians(SEG * k)
        spot = bpy.data.lights.new("uplight", "SPOT")
        spot.energy = 650.0
        spot.color = (1.0, 0.82, 0.6)
        spot.spot_size = math.radians(70.0)
        spot.spot_blend = 0.6
        spot.shadow_soft_size = 0.1
        so = bpy.data.objects.new("uplight", spot)
        r = 10.58
        so.location = godot_to_blender((-math.sin(a) * r, 10.85, -math.cos(a) * r))
        target = godot_to_blender((-math.sin(a) * 2.0, 18.0, -math.cos(a) * 2.0))
        so.rotation_euler = (target - so.location).to_track_quat('-Z', 'Y').to_euler()
        sc.collection.objects.link(so)
    for k in range(1, 16, 2):
        a = math.radians(SEG * k)
        for r in (5.2, 7.8):
            lamp = bpy.data.lights.new("desk", "POINT")
            lamp.energy = 110.0
            lamp.color = (1.0, 0.75, 0.45)
            lamp.shadow_soft_size = 0.05
            lo = bpy.data.objects.new("desk", lamp)
            lo.location = godot_to_blender((-math.sin(a) * r, 1.25, -math.cos(a) * r))
            sc.collection.objects.link(lo)


SHOTS = {
    # name: (camera Godot position, look-at Godot position, focal length mm)
    "entrance": ((0.0, 1.7, 29.0), (0.0, 9.0, -10.0), 16.0),
    "roof": ((-20.0, 1.6, 20.0), (-4.0, 19.0, 2.0), 14.0),
    "corner": ((26.0, 1.7, 26.0), (0.0, 8.0, 0.0), 18.0),
    "high": ((-27.0, 16.0, 27.0), (0.0, 4.0, 0.0), 18.0),
    "floor": ((10.0, 0.4, 24.0), (-2.0, 1.5, 10.0), 20.0),
    "rr_wide": ((0.0, 1.7, 9.5), (0.0, 8.0, -6.0), 14.0),
    "rr_dome": ((0.0, 1.7, 6.0), (0.0, 20.0, -1.5), 12.0),
    "rr_desks": ((3.5, 2.6, 9.0), (-1.0, 2.0, -1.0), 18.0),
    "balcony": ((-14.0, 8.7, -9.5), (8.0, 6.0, -22.0), 18.0),
}


def camera(name):
    pos, look, lens = SHOTS[name]
    cam_data = bpy.data.cameras.new("cam")
    cam_data.lens = lens
    cam_data.clip_start = 0.05
    cam_data.clip_end = 400.0
    cam = bpy.data.objects.new("cam", cam_data)
    bpy.context.scene.collection.objects.link(cam)
    p = godot_to_blender(pos)
    t = godot_to_blender(look)
    cam.location = p
    cam.rotation_euler = (t - p).to_track_quat('-Z', 'Y').to_euler()
    bpy.context.scene.camera = cam
    return cam


def main(argv):
    names = [a for a in argv if not a.startswith("-")] or ["entrance", "roof", "corner", "high"]
    samples = 64
    w, h = 1280, 720
    for a in argv:
        if a.startswith("--samples="):
            samples = int(a.split("=")[1])
        if a.startswith("--size="):
            w, h = (int(v) for v in a.split("=")[1].split("x"))
    scene.reset()
    sc = bpy.context.scene
    scene._cycles(sc, samples=samples)
    sc.cycles.volume_step_rate = 4.0
    sc.cycles.volume_max_steps = 256
    sc.view_settings.view_transform = "AgX"
    sc.view_settings.look = "AgX - Medium High Contrast"
    sc.render.resolution_x = w
    sc.render.resolution_y = h
    cache = {}
    shell(cache)
    for item in placements():
        place(item[0], item[1], item[2], cache, item[3] if len(item) > 3 else None)
    lights()
    OUT.mkdir(parents=True, exist_ok=True)
    for n in names:
        cam = camera(n)
        sc.render.filepath = str(OUT / f"court_{n}.png")
        bpy.ops.render.render(write_still=True)
        bpy.data.objects.remove(cam)
        print("shot", n, sc.render.filepath)


if __name__ == "__main__":
    main(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else [])
