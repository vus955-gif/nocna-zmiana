"""Mood check for the Greek wing (headless, Cycles): rooms assembled from
the exported models and tile fields, lit by the moon through the top-light
wells - not a game scene, an art director's check of scale (a 1.8 m figure
stands in each shot), palette and light before the level is built.

  greece_vignette_gallery.png   the Parthenon Gallery (40 x 18 m, 12 m):
                                marble walls, the frieze at 1.45 m in varied
                                slabs, the Ionic cornice, coffers and wells,
                                pediment groups on low plinths at the far
                                end, the centaur in the arena, two hoplites
  greece_vignette_centaur.png   the guardian close, among the pediments
  greece_vignette_nereid.png    the Nereid Monument: podium, temple, Nereids
                                between the columns, a moon shaft
  greece_vignette_metopes.png   metopes on a wall under the Doric
                                entablature, a hoplite on guard, vase cases

Run from the repo root:
    "D:/Program Files/Blender Foundation/Blender 5.1/blender.exe" -b -t 4 --factory-startup \\
        --python tools/art/greece_vignette.py -- [--samples 64] [--size 1280x720] [--only gallery,nereid]
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


def _mat_for(name, swap=None):
    base = name.split(".")[0]
    if swap and base in swap:
        base = swap[base]
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


def place(name, loc, yaw=0.0, scale=(1.0, 1.0, 1.0), swap=None):
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
                m = _mat_for(slot.material.name, swap)
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


FRIEZE_SETS = ["gr_frieze_4m", "gr_frieze_4m_b", "gr_frieze_4m_c", "gr_frieze_4m_d", "gr_frieze_4m_e",
               "gr_frieze_4m_f"]


def wall_run(x0, y0, length, run, yaw, z_frieze=1.45, ceiling=12.0, frieze=True, cornice="gr_cornice_4m",
             base="gr_base_4m", seed=0):
    """Bands along a wall from (x0, y0) running ``length`` in direction
    ``run`` (degrees), turned ``yaw`` so their fronts face the room."""
    a = math.radians(run)
    d = Vector((math.cos(a), math.sin(a), 0.0))
    n = int(length // 4)
    for k in range(n):
        c = Vector((x0, y0, 0.0)) + d * (2.0 + 4.0 * k)
        place(base, (c.x, c.y, 0.0), yaw=yaw)
        if frieze:
            s = FRIEZE_SETS[(k * 4 + seed) % len(FRIEZE_SETS)]
            place("gr_frieze_4m", (c.x, c.y, z_frieze), yaw=yaw, swap={"gr_frieze_4m": s})
        if cornice:
            place(cornice, (c.x, c.y, ceiling), yaw=yaw)


def gallery():
    L, HW, H = 40.0, 9.0, 12.0
    floor = tile_material("marble_greek")
    wall = tile_material("gr_ashlar")
    ceil = tile_material("gr_plaster")
    box("floor", (0.0, L / 2, -0.25), (2 * HW + 2, L + 2, 0.5), floor)
    for sx in (-1, 1):
        box(f"wall_{sx}", (sx * (HW + 0.3), L / 2, H / 2), (0.6, L + 2, H), wall)
    box("end_n", (0.0, L + 0.3, H / 2), (2 * HW + 2, 0.6, H), wall)
    box("end_s", (0.0, -0.3, H / 2), (2 * HW + 2, 0.6, H), wall)
    # ceiling with four 4 m wells down the middle; coffers elsewhere
    wells = [6.0, 14.0, 22.0, 30.0]
    edges = [-1.0] + [v for y in wells for v in (y - 2.0, y + 2.0)] + [L + 1.0]
    for a, b in zip(edges[0::2], edges[1::2]):
        box(f"ceil_{a}", (0.0, (a + b) / 2, H + 0.25), (2 * HW + 2, b - a, 0.5), ceil)
    for y in wells:
        for sx in (-1, 1):
            box(f"ceil_side_{y}_{sx}", (sx * (HW + 2) / 2 + sx * 1.0, y, H + 0.25), (HW - 1.0, 4.0, 0.5), ceil)
        place("gr_skylight_4m", (0.0, y, H), yaw=0.0)
    for x in (-7.0, -5.0, -3.0, 3.0, 5.0, 7.0):
        for k in range(20):
            place("gr_coffer_2m", (x, 1.0 + 2.0 * k, H))
    # bands round the walls: the frieze at 1.45 m in varied slabs
    wall_run(-HW, 0.0, L, 90.0, -90.0, ceiling=H, seed=0)        # west wall, facing +x
    wall_run(HW, L, L, -90.0, 90.0, ceiling=H, seed=3)          # east wall, facing -x
    wall_run(-HW, 0.0, 2 * HW, 0.0, 0.0, ceiling=H, seed=1)     # south end, facing +y
    wall_run(HW, L, 2 * HW, 180.0, 180.0, ceiling=H, seed=5)    # north end, facing -y
    for k in range(9):
        y = 2.0 + 4.0 * k
        for sx in (-1, 1):
            place("gr_floor_border_4m", (sx * HW, y, 0.0), yaw=90.0 * sx)    # strip runs toward the room
    # pediment groups on low plinths at the north end, the arena
    place("gr_plinth_low", (-4.6, 36.2, 0.0), yaw=180.0)
    place("gr_ped_goddesses", (-4.6, 36.2, 0.5), yaw=180.0)
    place("gr_plinth_low", (4.6, 36.2, 0.0), yaw=180.0)
    place("gr_ped_reclining", (3.8, 36.2, 0.5), yaw=180.0)
    place("gr_plinth_low", (0.0, 37.6, 0.0), yaw=180.0)
    place("gr_ped_horse", (1.5, 37.6, 0.5), yaw=180.0)
    place("gr_ped_seated", (-1.0, 37.6, 0.5), yaw=180.0)
    place("gr_plinth_block", (-7.0, 30.0, 0.0), yaw=90.0)
    place("gr_ped_torso", (-7.0, 30.0, 1.1), yaw=90.0)
    place("gr_drum", (5.5, 24.0, 0.0), yaw=30.0)
    place("gr_capital_doric", (-5.5, 18.0, 0.0), yaw=12.0)
    # the guardian and two hoplites; a 1.8 m figure for scale
    place("centaur", (0.6, 26.0, 0.0), yaw=200.0)
    place("hoplite", (-2.2, 15.5, 0.0), yaw=195.0)
    place("hoplite", (-1.2, 16.1, 0.0), yaw=190.0)
    place("wax_figure", (2.6, 7.0, 0.0), yaw=170.0)


def nereid_room():
    L, HW, H = 24.0, 9.0, 12.5
    off = 60.0                                   # far from the gallery
    floor = tile_material("marble_greek")
    wall = tile_material("gr_ashlar")
    ceil = tile_material("gr_plaster")
    box("n_floor", (off, L / 2, -0.25), (2 * HW + 2, L + 2, 0.5), floor)
    box("n_back", (off, L + 0.3, H / 2), (2 * HW + 2, 0.6, H), wall)
    for sx in (-1, 1):
        box(f"n_wall_{sx}", (off + sx * (HW + 0.3), L / 2, H / 2), (0.6, L + 2, H), wall)
    box("n_ceil_a", (off, 6.0, H + 0.25), (2 * HW + 2, 14.0, 0.5), ceil)
    box("n_ceil_b", (off, L - 1.0, H + 0.25), (2 * HW + 2, 4.0, 0.5), ceil)
    for sx in (-1, 1):
        box(f"n_ceil_{sx}", (off + sx * 6.0, 17.0, H + 0.25), (6.0, 6.0, 0.5), ceil)
    place("gr_skylight_4m", (off, 17.0, H), yaw=0.0)
    wall_run(off - HW, 0.0, L, 90.0, -90.0, ceiling=H, frieze=False)
    wall_run(off + HW, L, L, -90.0, 90.0, ceiling=H, frieze=False)
    y = L - 2.0
    place("nereid_podium", (off, y, 0.0), yaw=180.0)
    place("nereid_temple", (off, y, 4.4), yaw=180.0)
    for x, n in ((-2.07, "nereid_a"), (0.0, "nereid_c"), (2.07, "nereid_b")):
        place(n, (off - x, y - 1.65, 4.7), yaw=180.0, scale=(0.95, 0.95, 0.95))
    place("nereid_d", (off - 6.2, 8.0, 0.0), yaw=120.0)
    place("gr_plinth_block", (off + 6.0, 9.0, 0.0), yaw=-90.0)
    place("vase_volute", (off + 6.0, 9.0, 1.1), yaw=-90.0)
    place("wax_figure", (off - 1.5, 9.0, 0.0), yaw=160.0)


def metopes_room():
    off = 120.0
    L, HW, H = 20.0, 7.0, 7.0
    floor = tile_material("marble_greek")
    wall = tile_material("gr_ashlar")
    red = tile_material("gr_wall_paint")
    ceil = tile_material("gr_plaster")
    box("m_floor", (off, L / 2, -0.25), (2 * HW + 2, L + 2, 0.5), floor)
    box("m_ceil", (off, L / 2, H + 0.25), (2 * HW + 2, L + 2, 0.5), ceil)
    box("m_wall_w", (off - HW - 0.3, L / 2, H / 2), (0.6, L + 2, H), wall)
    box("m_wall_e", (off + HW + 0.3, L / 2, H / 2), (0.6, L + 2, H), red)
    box("m_wall_n", (off, L + 0.3, H / 2), (2 * HW + 2, 0.6, H), wall)
    wall_run(off - HW, 0.0, L, 90.0, -90.0, ceiling=H, frieze=False, cornice="gr_cornice_doric_4m")
    wall_run(off + HW, L, L, -90.0, 90.0, ceiling=H, frieze=False, cornice="gr_cornice_4m")
    for k, name in enumerate(("gr_metope_a", "gr_metope_b", "gr_metope_c", "gr_metope_d")):
        place(name, (off - HW, 3.0 + 3.5 * k, 1.6), yaw=-90.0)
    for k in range(3):
        place("vase_case_wall_2m", (off + HW, 4.0 + 5.0 * k, 0.0), yaw=90.0)
        for j, (v, z) in enumerate((("vase_amphora_bf", 0.91), ("vase_kylix", 1.45), ("vase_lekythos", 1.95),
                                     ("vase_hydria", 0.91), ("vase_krater", 1.45))):
            yy = 4.0 + 5.0 * k - 0.6 + (j % 3) * 0.6
            place(v, (off + HW - 0.3, yy, z), yaw=90.0)
    place("vase_case_tall", (off + 2.0, 15.0, 0.0), yaw=-120.0)
    place("vase_amphora_rf", (off + 2.0, 15.0, 0.96), yaw=-120.0)
    place("hoplite", (off - 2.0, 10.0, 0.0), yaw=-120.0)
    place("gr_portal_4m", (off, L, 0.0), yaw=180.0)
    place("wax_figure", (off + 0.8, 6.0, 0.0), yaw=200.0)


def lights(volumes):
    sc = bpy.context.scene
    moon = bpy.data.lights.new("moon", "SUN")
    moon.energy = 7.0
    moon.color = (0.6, 0.72, 1.0)
    moon.angle = math.radians(0.6)
    mo = bpy.data.objects.new("moon", moon)
    d = Vector((0.25, 0.35, -0.9)).normalized()
    mo.rotation_euler = d.to_track_quat('-Z', 'Y').to_euler()
    sc.collection.objects.link(mo)
    world = bpy.data.worlds.new("night")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.03, 0.035, 0.06, 1.0)
    world.node_tree.nodes["Background"].inputs["Strength"].default_value = 2.0
    sc.world = world

    def area(name, at, size, power, color):
        ld = bpy.data.lights.new(name, "AREA")
        ld.energy = power
        ld.color = color
        ld.size = size
        o = bpy.data.objects.new(name, ld)
        o.location = at
        o.rotation_euler = (0.0, 0.0, 0.0)
        o.rotation_euler = Vector((0, 0, -1)).to_track_quat('-Z', 'Y').to_euler()
        sc.collection.objects.link(o)

    # soft cool skylight from each well (the moonlit sky through the glass)
    for y in (6.0, 14.0, 22.0, 30.0):
        area(f"sky_{y}", (0.0, y, 11.6), 3.4, 900.0, (0.62, 0.72, 1.0))
    area("sky_n", (60.0, 17.0, 12.1), 3.4, 1200.0, (0.62, 0.72, 1.0))
    area("sky_m", (120.0, 10.0, 6.8), 8.0, 900.0, (0.65, 0.74, 1.0))

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

    warm = (1.0, 0.76, 0.5)
    spot("ped_l", (-4.6, 31.0, 6.0), (-4.6, 36.2, 1.0), 3500.0, warm, 40.0)
    spot("ped_r", (4.6, 31.0, 6.0), (4.6, 36.2, 1.0), 3500.0, warm, 40.0)
    spot("nereid_key", (60.0 + 4.0, 10.0, 2.0), (60.0, 22.0, 6.0), 9000.0, warm, 45.0)
    spot("metope_key", (120.0 + 2.0, 8.5, 5.5), (120.0 - 7.0, 8.5, 2.2), 6000.0, warm, 70.0)
    for name, (x0, y0, x1, y1, h) in volumes.items():
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=((x0 + x1) / 2, (y0 + y1) / 2, h / 2))
        v = bpy.context.active_object
        v.scale = (x1 - x0, y1 - y0, h)
        vm = bpy.data.materials.new("dust_" + name)
        vm.use_nodes = True
        nt = vm.node_tree
        nt.nodes.remove(nt.nodes["Principled BSDF"])
        vol = nt.nodes.new("ShaderNodeVolumePrincipled")
        vol.inputs["Density"].default_value = 0.008
        vol.inputs["Anisotropy"].default_value = 0.55
        vol.inputs["Color"].default_value = (0.86, 0.88, 0.92, 1.0)
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


def main(argv):
    samples = 64
    size = (1280, 720)
    only = None
    if "--samples" in argv:
        samples = int(argv[argv.index("--samples") + 1])
    if "--size" in argv:
        w, h = argv[argv.index("--size") + 1].split("x")
        size = (int(w), int(h))
    if "--only" in argv:
        only = set(argv[argv.index("--only") + 1].split(","))
    scene.reset()
    sc = bpy.context.scene
    scene._cycles(sc, samples)
    sc.view_settings.view_transform = "AgX"
    sc.view_settings.look = "AgX - Medium High Contrast"
    want = lambda k: only is None or k in only
    vols = {}
    if want("gallery") or want("centaur"):
        gallery()
        vols["gallery"] = (-9.0, 0.0, 9.0, 40.0, 12.0)
    if want("nereid"):
        nereid_room()
        vols["nereid"] = (51.0, 0.0, 69.0, 24.0, 12.5)
    if want("metopes"):
        metopes_room()
        vols["metopes"] = (113.0, 0.0, 127.0, 20.0, 7.0)
    lights(vols)
    if want("gallery"):
        render(OUT / "greece_vignette_gallery.png", (-1.5, 1.5, 1.65), (0.5, 30.0, 4.2), size, samples, lens=17.0)
    if want("centaur"):
        render(OUT / "greece_vignette_centaur.png", (3.6, 19.0, 1.6), (0.3, 27.0, 2.2), size, samples, lens=20.0)
    if want("nereid"):
        render(OUT / "greece_vignette_nereid.png", (61.5, 3.5, 1.65), (60.0, 21.0, 5.5), size, samples, lens=16.0)
    if want("metopes"):
        render(OUT / "greece_vignette_metopes.png", (122.5, 1.5, 1.65), (117.0, 11.0, 2.0), size, samples, lens=17.0)
    print("vignette done")


if __name__ == "__main__":
    main(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else [])
