"""Mood check for the Americas and Oceania wing (headless, Cycles): rooms
assembled from the exported models and tile fields, lit the wing's way -
theatrical, from below, by fire - and the creatures posed only by turning
their jointed parts (a check of the rigs' pivots).

  temple   the Temple of the Serpent: two stepped terraces with their
           stairs and serpent balustrades, the altar house on top in a
           shaft of moon, fire bowls at the corners, the Two-headed
           Serpent coiled round the foot of the platform, the carved disc
           and the mask case along the red walls
  moai     the dark Moai room: one head lit from below
  pacific  the Pacific gallery: the war canoe hanging under the bark-cloth
           ceiling, the whaling display with the harpoon gun's stand
  totems   the totem hall: the decor poles, a Totem with burning eyes and
           a jaguar warrior springing
Not a game scene - an art-director's check of scale, palette and light.
Run from the repo root:
    "D:/Program Files/Blender Foundation/Blender 5.1/blender.exe" -b -t 4 --factory-startup \\
        --python tools/art/americas_vignette.py -- [temple moai pacific totems] [--samples 64]
Writes tests/_out/art/americas_vignette_<scene>.png.
"""
import math
import sys
from pathlib import Path

import bpy
from mathutils import Vector

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import egypt_vignette as EV  # noqa: E402  (place, tile_material, box, render)
from artlib import scene  # noqa: E402

OUT = EV.OUT


# --------------------------------------------------------------------------
# helpers
# --------------------------------------------------------------------------

def gv(x, y, z):
    """Godot (x, y, z) -> Blender (x, -z, y)."""
    return (x, -z, y)


def put(name, at, yaw=0.0, scale=(1.0, 1.0, 1.0)):
    """Places a model at Godot coordinates ``at``; ``yaw`` degrees about the
    vertical (Godot rotation.y)."""
    return EV.place(name, gv(*at), yaw=yaw, scale=scale)


def parts_of(holder):
    out = {}
    for o in holder.children_recursive:
        o.rotation_mode = "XYZ"
        out[o.name.split(".")[0]] = o
    return out


def room(w, d, h, wall, floor, ceil, x0=0.0, z0=0.0, tint=None):
    """A box room in Godot terms: x from x0 - w/2 .. x0 + w/2, z from z0 - d/2
    .. z0 + d/2, floor at 0, ceiling at h."""
    fm = EV.tile_material(floor)
    wm = EV.tile_material(wall)
    cm = EV.tile_material(ceil)
    EV.box("floor", gv(x0, -0.25, z0), (w + 1, d + 1, 0.5), fm)
    EV.box("ceiling", gv(x0, h + 0.25, z0), (w + 1, d + 1, 0.5), cm)
    for sx in (-1, 1):
        EV.box(f"wall_x{sx}", gv(x0 + sx * (w / 2 + 0.3), h / 2, z0), (0.6, d + 1.2, h), wm)
    for sz in (-1, 1):
        EV.box(f"wall_z{sz}", gv(x0, h / 2, z0 + sz * (d / 2 + 0.3)), (w + 1.2, 0.6, h), wm)


def run(prefix, length, at_wall, inward_yaw, datum_y, x_from, x_to, axis="x"):
    """Lays wall-run modules (4 / 2 / 1 m) of ``prefix`` along a wall."""
    total = x_to - x_from
    pos = x_from
    while total > 0.49:
        for L, tag in ((4.0, "4m"), (2.0, "2m"), (1.0, "1m"), (0.5, "05m")):
            if total >= L - 1e-6:
                c = pos + L / 2
                at = (c, datum_y, at_wall) if axis == "x" else (at_wall, datum_y, c)
                put(f"{prefix}{tag}", at, yaw=inward_yaw)
                pos += L
                total -= L
                break


def light(kind, name, at, power, color, target=None, size=40.0, radius=0.1):
    sc = bpy.context.scene
    ld = bpy.data.lights.new(name, kind)
    ld.energy = power
    ld.color = color
    if kind == "SPOT":
        ld.spot_size = math.radians(size)
        ld.spot_blend = 0.6
    ld.shadow_soft_size = radius
    o = bpy.data.objects.new(name, ld)
    o.location = gv(*at)
    if target is not None:
        o.rotation_euler = (Vector(gv(*target)) - Vector(gv(*at))).normalized().to_track_quat('-Z', 'Y').to_euler()
    sc.collection.objects.link(o)
    return o


FIRE = (1.0, 0.5, 0.2)
UP = (1.0, 0.62, 0.36)
MOON = (0.55, 0.67, 1.0)


def world(strength=0.6):
    w = bpy.data.worlds.new("night")
    w.use_nodes = True
    w.node_tree.nodes["Background"].inputs["Color"].default_value = (0.01, 0.012, 0.02, 1.0)
    w.node_tree.nodes["Background"].inputs["Strength"].default_value = strength
    bpy.context.scene.world = w


def haze(center, size, density=0.012):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=gv(*center))
    v = bpy.context.active_object
    v.scale = (size[0], size[2], size[1])
    vm = bpy.data.materials.new("haze")
    vm.use_nodes = True
    nt = vm.node_tree
    nt.nodes.remove(nt.nodes["Principled BSDF"])
    vol = nt.nodes.new("ShaderNodeVolumePrincipled")
    vol.inputs["Density"].default_value = density
    vol.inputs["Anisotropy"].default_value = 0.5
    vol.inputs["Color"].default_value = (0.9, 0.82, 0.75, 1.0)
    nt.links.new(vol.outputs["Volume"], nt.nodes["Material Output"].inputs["Volume"])
    v.data.materials.append(vm)


def fire_bowl(at, power=260.0):
    put("americas_brazier", at)
    light("POINT", "fire", (at[0], at[1] + 1.3, at[2]), power, FIRE, radius=0.25)


def cam(name, at, target, size, samples, lens=18.0):
    EV.render(OUT / f"americas_vignette_{name}.png", gv(*at), gv(*target), size, samples, lens=lens)


def reset():
    scene.reset()
    sc = bpy.context.scene
    scene._cycles(sc, 64)
    sc.view_settings.view_transform = "AgX"
    sc.view_settings.look = "AgX - Medium High Contrast"


# --------------------------------------------------------------------------
# the Temple of the Serpent
# --------------------------------------------------------------------------

def pose_serpent(holder):
    """Coils the serpent: each segment yawed a little (a winding S), head A
    reared and turned to the camera, both jaws opened wider."""
    p = parts_of(holder)
    for k in range(1, 15):
        a = 22.0 * math.sin(k * 0.62 + 0.6)
        p[f"segment_{k}"].rotation_euler = (0.0, 0.0, math.radians(a if k > 1 else 0.0))
    p["skull_a"].rotation_euler = (math.radians(22.0), 0.0, math.radians(-25.0))
    p["jaw_a"].rotation_euler = (math.radians(-26.0), 0.0, 0.0)
    p["skull_b"].rotation_euler = (math.radians(-8.0), 0.0, math.radians(20.0))
    p["jaw_b"].rotation_euler = (math.radians(14.0), 0.0, 0.0)
    bpy.context.view_layer.update()


def temple(size, samples):
    reset()
    W, D, H = 20.0, 27.0, 12.0
    room(W, D, H, "am_red_wall", "basalt_americas", "am_ceiling")
    hw, hd = W / 2, D / 2
    # wall bands on the two long walls and the far wall
    for sx in (-1, 1):
        run("americas_dado_", 0, sx * hw, 90.0 * sx, 0.0, -hd, hd, axis="z")
        run("americas_frieze_", 0, sx * hw, 90.0 * sx, 7.0, -hd, hd, axis="z")
        run("americas_cornice_", 0, sx * hw, 90.0 * sx, H, -hd, hd, axis="z")
    run("americas_dado_", 0, -hd, 180.0, 0.0, -hw, hw)
    run("americas_frieze_", 0, -hd, 180.0, 7.0, -hw, hw)
    run("americas_cornice_", 0, -hd, 180.0, H, -hw, hw)
    # the stepped platform: terrace boxes with carved faces
    stone = EV.tile_material("am_stone_blocks")
    for (tw, td, ty) in ((11.5, 13.5, 1.5), (7.5, 5.5, 3.0)):
        EV.box("terrace", gv(0.0, ty / 2, 0.0), (tw, td, ty), stone)
    for (tw, td, y0) in ((11.5, 13.5, 0.0), (7.5, 5.5, 1.5)):
        for side, (len_, nrm) in enumerate(((tw, (0, -1)), (td, (1, 0)), (tw, (0, 1)), (td, (-1, 0)))):
            # faces looking -Z, +X, +Z, -X; leave 0.5 m at the corners and 3.4 m for the stairs on the z faces
            yaw = {0: 0.0, 1: -90.0, 2: 180.0, 3: 90.0}[side]
            half = len_ / 2 - 0.5
            spans = [(-half, half)]
            if side in (0, 2):
                spans = [(-half, -1.7), (1.7, half)]
            for a, b in spans:
                pos = a
                while b - pos > 0.99:
                    L = 4.0 if b - pos >= 4.0 else (2.0 if b - pos >= 2.0 else 1.0)
                    c = pos + L / 2
                    if side == 0:
                        at = (c, y0, -td / 2)
                    elif side == 2:
                        at = (-c, y0, td / 2)
                    elif side == 1:
                        at = (tw / 2, y0, c)
                    else:
                        at = (-tw / 2, y0, -c)
                    put(f"temple_tier_{'4m' if L == 4 else ('2m' if L == 2 else '1m')}", at, yaw=yaw)
                    pos += L
        for k, (cx, cz) in enumerate(((-tw / 2, -td / 2), (tw / 2, -td / 2), (tw / 2, td / 2), (-tw / 2, td / 2))):
            put("temple_tier_corner", (cx, y0, cz), yaw={0: 90.0, 1: 0.0, 2: -90.0, 3: 180.0}[k])
    # stairs on the south (+Z, toward the camera) faces
    put("temple_stair", (0.0, 0.0, 13.5 / 2 + 4.0), yaw=0.0)
    upper = put("temple_stair", (0.0, 1.5, 5.5 / 2 + 4.0), yaw=0.0)
    parts_of(upper)["serpent_heads"].hide_render = True
    put("temple_shrine", (0.0, 3.0, -0.6))
    for x in (-8.3, 8.3):
        put("temple_altar", (x, 0.0, 2.0))
    for x, z in ((-8.6, -11.8), (8.6, -11.8), (-8.6, 11.8), (8.6, 11.8)):
        fire_bowl((x, 0.0, z), 700.0)
    put("sun_stone", (-hw + 0.7, 0.0, -6.0), yaw=-90.0)
    put("mask_case", (hw - 0.8, 0.0, -6.0), yaw=90.0)
    put("serpent_mosaic", (hw - 0.6, 0.0, 4.5), yaw=90.0)
    for z in (-3.0, 9.0):
        put("americas_torch_lamp", (-hw + 0.34, 3.4, z), yaw=-90.0)
        put("americas_torch_lamp", (hw - 0.34, 3.4, z), yaw=90.0)
        light("POINT", "torch", (-hw + 0.34, 3.4, z), 200.0, FIRE)
        light("POINT", "torch", (hw - 0.34, 3.4, z), 200.0, FIRE)
    snake = put("serpent", (-8.0, 0.0, 0.5), yaw=180.0)
    pose_serpent(snake)
    world(0.5)
    light("SPOT", "moon", (0.0, H - 0.2, -0.6), 2600.0, MOON, target=(0.0, 3.0, -0.6), size=24.0, radius=0.05)
    light("SPOT", "up_n", (2.0, 0.3, 12.8), 9000.0, UP, target=(0.0, 3.0, 0.0), size=50.0)
    light("SPOT", "up_serpent", (-5.0, 0.3, 11.5), 4000.0, UP, target=(-8.0, 1.0, 4.0), size=45.0)
    fire_bowl((-6.6, 0.0, 9.5), 500.0)
    light("SPOT", "up_disc", (-5.0, 0.2, -6.0), 2600.0, UP, target=(-hw + 0.6, 2.4, -6.0), size=50.0)
    light("SPOT", "up_masks", (6.0, 0.2, -6.0), 1500.0, UP, target=(hw - 0.8, 1.4, -6.0), size=40.0)
    light("POINT", "shrine_fire", (0.0, 3.6, -0.85), 150.0, FIRE, radius=0.2)
    haze((0.0, H / 2, 0.0), (W - 0.2, H - 0.2, D - 0.2), 0.008)
    cam("temple", (7.5, 3.4, 12.8), (-2.5, 2.0, -1.0), size, samples, lens=16.0)
    cam("temple_serpent", (-3.4, 1.6, 12.8), (-8.0, 1.0, 3.0), size, samples, lens=18.0)


# --------------------------------------------------------------------------
# the Moai room
# --------------------------------------------------------------------------

def moai(size, samples):
    reset()
    W, D, H = 11.0, 20.0, 9.0
    room(W, D, H, "am_stone_blocks", "basalt_americas", "am_ceiling")
    for sx in (-1, 1):
        run("americas_dado_", 0, sx * W / 2, 90.0 * sx, 0.0, -D / 2, D / 2, axis="z")
    put("moai", (0.0, 0.0, -6.5), yaw=180.0)
    put("pacific_figures", (-4.6, 0.0, -1.0), yaw=-90.0)
    put("pacific_figures", (4.6, 0.0, 2.5), yaw=90.0)
    world(0.35)
    light("SPOT", "up", (0.0, 0.25, -3.8), 1500.0, UP, target=(0.0, 3.3, -6.6), size=34.0, radius=0.08)
    light("SPOT", "rim", (0.0, 8.5, -9.5), 600.0, MOON, target=(0.0, 3.0, -6.4), size=20.0)
    light("POINT", "torch", (-5.1, 2.4, 4.0), 60.0, FIRE)
    haze((0.0, H / 2, 0.0), (W - 0.2, H - 0.2, D - 0.2), 0.01)
    cam("moai", (1.2, 1.65, -0.8), (0.0, 2.8, -6.5), size, samples, lens=22.0)


# --------------------------------------------------------------------------
# the Pacific gallery
# --------------------------------------------------------------------------

def pacific(size, samples):
    reset()
    W, D, H = 15.0, 22.0, 10.0
    room(W, D, H, "boards_pacific", "boards_pacific", "am_tapa")
    for sx in (-1, 1):
        run("pacific_dado_", 0, sx * W / 2, 90.0 * sx, 0.0, -D / 2, D / 2, axis="z")
    run("pacific_dado_", 0, -D / 2, 180.0, 0.0, -W / 2, W / 2)
    for z in range(-10, 11, 2):
        put("pacific_beam_4m", (-4.0, H, float(z)), yaw=0.0)
        put("pacific_beam_4m", (0.0, H, float(z)), yaw=0.0)
        put("pacific_beam_4m", (4.0, H, float(z)), yaw=0.0)
    for z in (-6.0, 0.0, 6.0):
        put("pacific_post", (-W / 2, 0.0, z), yaw=-90.0, scale=(1.0, 1.0, 2.2))
        put("pacific_post", (W / 2, 0.0, z), yaw=90.0, scale=(1.0, 1.0, 2.2))
    canoe = put("war_canoe", (0.0, 4.4, -2.0), yaw=0.0)
    p = parts_of(canoe)
    p["rope_main"].scale = (1.0, 1.0, (H - 4.4 - 2.6) / 2.0)
    put("whaling_rack", (-2.0, 1.2, -D / 2), yaw=180.0)
    put("harpoon_stand", (-2.0, 0.0, -7.5), yaw=0.0)
    put("tapa_hanging", (W / 2, 4.6, -3.0), yaw=90.0)
    put("tapa_hanging", (-W / 2, 4.6, 3.0), yaw=-90.0)
    put("feather_case", (W / 2 - 0.45, 0.0, 4.5), yaw=90.0)
    fire_bowl((3.0, 0.0, 4.0), 360.0)
    world(0.45)
    light("POINT", "lantern", (-2.4, 2.8, -7.2), 160.0, (1.0, 0.74, 0.46), radius=0.1)
    light("SPOT", "up_canoe", (2.5, 0.3, 4.0), 12000.0, FIRE, target=(0.0, 4.8, -2.0), size=55.0)
    light("SPOT", "up_canoe2", (-3.0, 0.3, -5.0), 6000.0, UP, target=(0.0, 4.8, -2.0), size=55.0)
    light("SPOT", "rack", (-2.0, 0.3, -8.0), 900.0, UP, target=(-2.0, 2.0, -D / 2), size=40.0)
    haze((0.0, H / 2, 0.0), (W - 0.2, H - 0.2, D - 0.2), 0.008)
    cam("pacific", (5.5, 1.7, 8.5), (-1.0, 4.3, -3.0), size, samples, lens=16.0)


# --------------------------------------------------------------------------
# the totem hall
# --------------------------------------------------------------------------

def pose_jaguar(holder):
    """Mid-leap: knees drawn up, torso pitched forward, club raised high."""
    p = parts_of(holder)
    p["pelvis"].location.z += 0.55
    p["torso"].rotation_euler = (math.radians(-25.0), 0.0, 0.0)
    p["head"].rotation_euler = (math.radians(15.0), 0.0, 0.0)
    p["arm_r"].rotation_euler = (math.radians(150.0), 0.0, math.radians(-10.0))
    p["forearm_r"].rotation_euler = (math.radians(40.0), 0.0, 0.0)
    p["arm_l"].rotation_euler = (math.radians(60.0), 0.0, math.radians(15.0))
    for s, a in (("l", 75.0), ("r", 40.0)):
        p[f"thigh_{s}"].rotation_euler = (math.radians(a), 0.0, 0.0)
        p[f"shin_{s}"].rotation_euler = (math.radians(-a * 1.4), 0.0, 0.0)
    p["tail_1"].rotation_euler = (math.radians(-40.0), 0.0, 0.0)
    bpy.context.view_layer.update()


def totems(size, samples):
    reset()
    W, D, H = 12.0, 20.0, 12.0
    room(W, D, H, "am_red_wall", "basalt_americas", "am_ceiling")
    for sx in (-1, 1):
        run("americas_dado_", 0, sx * W / 2, 90.0 * sx, 0.0, -D / 2, D / 2, axis="z")
        run("americas_cornice_", 0, sx * W / 2, 90.0 * sx, H, -D / 2, D / 2, axis="z")
    put("totem_pole_house", (0.0, 0.0, -9.3), yaw=180.0)
    put("totem_pole_memorial", (-3.6, 0.0, -4.0), yaw=200.0)
    put("totem_pole_welcome", (3.8, 0.0, -2.0), yaw=155.0)
    put("totem", (-1.6, 0.0, 1.0), yaw=195.0)
    jag = put("jaguar", (1.4, 0.0, 3.4), yaw=200.0)
    pose_jaguar(jag)
    put("jaguar", (-3.8, 0.0, -1.0), yaw=160.0)
    fire_bowl((-1.6, 0.0, 3.0), 280.0)
    fire_bowl((3.0, 0.0, -6.5), 300.0)
    world(0.45)
    light("SPOT", "up_house", (0.0, 0.3, -6.0), 5000.0, UP, target=(0.0, 6.0, -9.3), size=40.0)
    light("SPOT", "up_mem", (-2.6, 0.3, -1.6), 2400.0, UP, target=(-3.6, 7.0, -4.0), size=28.0)
    light("SPOT", "up_totem", (-0.8, 0.2, 3.4), 1600.0, UP, target=(-1.6, 3.0, 1.0), size=40.0)
    haze((0.0, H / 2, 0.0), (W - 0.2, H - 0.2, D - 0.2), 0.01)
    cam("totems", (2.0, 1.6, 9.2), (-0.8, 3.6, -3.0), size, samples, lens=17.0)


def main(argv):
    samples = 64
    size = (1280, 720)
    if "--samples" in argv:
        samples = int(argv[argv.index("--samples") + 1])
    if "--size" in argv:
        w, h = argv[argv.index("--size") + 1].split("x")
        size = (int(w), int(h))
    names = [a for a in argv if not a.startswith("-") and not a.isdigit() and "x" not in a] or \
        ["temple", "moai", "pacific", "totems"]
    for n in names:
        {"temple": temple, "moai": moai, "pacific": pacific, "totems": totems}[n](size, samples)
        print("vignette", n, "done")


if __name__ == "__main__":
    main(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else [])
