"""Blender-side helpers: objects from Parts, smart UV unwrap for organic
shapes, preview materials, glTF export and EEVEE preview renders."""
import math
from pathlib import Path

import bmesh
import bpy
import numpy as np
from mathutils import Vector

from . import imageio


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def to_object(part, collection=None):
    """Creates a mesh object from a Part; mesh verts become relative to part.origin."""
    me = bpy.data.meshes.new(part.name)
    bm = part.bm
    bmesh.ops.translate(bm, vec=-part.origin, verts=bm.verts)
    bm.to_mesh(me)
    bmesh.ops.translate(bm, vec=part.origin, verts=bm.verts)
    for name in part.slots:
        mat = bpy.data.materials.get("slot:" + name) or bpy.data.materials.new("slot:" + name)
        me.materials.append(mat)
    obj = bpy.data.objects.new(part.name, me)
    obj.location = part.origin
    (collection or bpy.context.scene.collection).objects.link(obj)
    return obj


def link_parents(parts, objects):
    """Joint chains: parents each object to its Part.parent, keeping the
    world placement (the child's location becomes relative to the parent's
    pivot). glTF/Godot keep the hierarchy, so turning a parent carries its
    children (neck -> head -> jaw, thigh -> shin -> foot)."""
    by_name = {o.name: o for o in objects}
    origin = {p.name: p.origin for p in parts}
    for part, obj in zip(parts, objects):
        if part.parent is None:
            continue
        obj.parent = by_name[part.parent]
        obj.location = part.origin - origin[part.parent]


def add_markers(markers, by_name, collection=None):
    """Empties exported as plain nodes (Godot Node3D): muzzles, sockets,
    light positions. markers = [(name, (x, y, z) in model space, parent)],
    or with a fourth element, a 3x3 Matrix: the marker's basis in model
    space (its columns = its local axes; the hand markers of
    artlib/hands.py). Parts carry no rotation, so a basis is set as is."""
    out = []
    for marker in markers:
        name, co, parent = marker[:3]
        obj = bpy.data.objects.new(name, None)
        obj.empty_display_type = "PLAIN_AXES"
        obj.empty_display_size = 0.05
        (collection or bpy.context.scene.collection).objects.link(obj)
        if parent is not None:
            par = by_name[parent]
            obj.parent = par
            bpy.context.view_layer.update()
            obj.location = Vector(co) - par.matrix_world.translation
        else:
            obj.location = Vector(co)
        if len(marker) > 3:
            obj.rotation_euler = marker[3].to_euler()
        out.append(obj)
    return out


def smart_unwrap(part, angle=66.0):
    """Organic parts: Blender's Smart UV Project, then rescale UVs to metres
    so the packer can apply the model's texel density."""
    me = bpy.data.meshes.new("_unwrap")
    part.bm.to_mesh(me)
    obj = bpy.data.objects.new("_unwrap", me)
    bpy.context.scene.collection.objects.link(obj)
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.uv.smart_project(angle_limit=math.radians(angle), island_margin=0.0, area_weight=0.0,
                             correct_aspect=True, scale_to_bounds=False)
    bpy.ops.object.mode_set(mode='OBJECT')
    part.bm.free()
    bm = bmesh.new()
    bm.from_mesh(me)
    uv = bm.loops.layers.uv["UVMap"]
    a3 = sum(f.calc_area() for f in bm.faces)
    a2 = 0.0
    for f in bm.faces:
        pts = [l[uv].uv for l in f.loops]
        for i in range(1, len(pts) - 1):
            a2 += abs((pts[i] - pts[0]).cross(pts[i + 1] - pts[0])) * 0.5
    scale = math.sqrt(a3 / max(a2, 1e-12))
    for f in bm.faces:
        for l in f.loops:
            l[uv].uv = l[uv].uv * scale
        f[bm.faces.layers.int["uvlock"]] = 1
    part.bm = bm
    part.uv = uv
    part.lock = bm.faces.layers.int["uvlock"]
    if "UVM" in bm.loops.layers.uv:
        bm.loops.layers.uv.remove(bm.loops.layers.uv["UVM"])
    bpy.data.objects.remove(obj)
    bpy.data.meshes.remove(me)


# --------------------------------------------------------------------------
# materials
# --------------------------------------------------------------------------

def _image(path, non_color=False):
    img = bpy.data.images.load(str(path), check_existing=True)
    if non_color:
        img.colorspace_settings.name = "Non-Color"
    return img


def atlas_material(name, tex_dir, has_emit=False):
    """Principled material wired to the baked maps (Closest filtering for preview)."""
    mat = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    alb = nt.nodes.new("ShaderNodeTexImage")
    alb.image = _image(tex_dir / f"{name}_albedo.png")
    alb.interpolation = "Closest"
    nt.links.new(alb.outputs["Color"], bsdf.inputs["Base Color"])
    orm = nt.nodes.new("ShaderNodeTexImage")
    orm.image = _image(tex_dir / f"{name}_orm.png", True)
    orm.interpolation = "Closest"
    sep = nt.nodes.new("ShaderNodeSeparateColor")
    nt.links.new(orm.outputs["Color"], sep.inputs["Color"])
    nt.links.new(sep.outputs["Green"], bsdf.inputs["Roughness"])
    nt.links.new(sep.outputs["Blue"], bsdf.inputs["Metallic"])
    nrm = nt.nodes.new("ShaderNodeTexImage")
    nrm.image = _image(tex_dir / f"{name}_normal.png", True)
    nrm.interpolation = "Closest"
    nmap = nt.nodes.new("ShaderNodeNormalMap")
    nt.links.new(nrm.outputs["Color"], nmap.inputs["Color"])
    nt.links.new(nmap.outputs["Normal"], bsdf.inputs["Normal"])
    if has_emit:
        em = nt.nodes.new("ShaderNodeTexImage")
        em.image = _image(tex_dir / f"{name}_emit.png")
        em.interpolation = "Closest"
        nt.links.new(em.outputs["Color"], bsdf.inputs["Emission Color"])
        bsdf.inputs["Emission Strength"].default_value = 3.0
    return mat


def glass_material(name="glass"):
    mat = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (0.85, 0.93, 0.92, 1.0)
    bsdf.inputs["Roughness"].default_value = 0.03
    bsdf.inputs["Transmission Weight"].default_value = 1.0
    bsdf.inputs["IOR"].default_value = 1.05      # thin pane: little refraction
    return mat


def screen_material(name, image_path, strength=2.5):
    """Preview stand-in for a screen slot (the game swaps in its own
    texture): the tile image, emissive, crisp."""
    mat = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    img = nt.nodes.new("ShaderNodeTexImage")
    img.image = _image(image_path)
    img.interpolation = "Closest"
    nt.links.new(img.outputs["Color"], bsdf.inputs["Base Color"])
    nt.links.new(img.outputs["Color"], bsdf.inputs["Emission Color"])
    bsdf.inputs["Emission Strength"].default_value = strength
    bsdf.inputs["Roughness"].default_value = 0.08
    return mat


def assign_export_materials(objects, model, kinds):
    """Collapses bake slots into the exported materials: every atlas slot ->
    material named ``model``; other kinds (e.g. glass) keep their own name."""
    for obj in objects:
        me = obj.data
        old = [m.name.split(":", 1)[-1] for m in me.materials]
        new_names = []
        remap = []
        for name in old:
            target = kinds.get(name, model)
            if target not in new_names:
                new_names.append(target)
            remap.append(new_names.index(target))
        idx = np.empty(len(me.polygons), np.int64)
        me.polygons.foreach_get("material_index", idx)
        idx = np.array(remap, np.int64)[idx] if remap else idx
        me.materials.clear()
        for n in new_names:
            me.materials.append(bpy.data.materials.get(n) or bpy.data.materials.new(n))
        me.polygons.foreach_set("material_index", idx)
        me.update()


# --------------------------------------------------------------------------
# export
# --------------------------------------------------------------------------

def triangulate(objects):
    """Triangulates meshes before export with fixed rules (quads split on
    one diagonal, n-gons by ear clipping). Left to itself the glTF exporter
    triangulates n-gons differently from run to run, so the same model gave
    different index buffers."""
    for obj in objects:
        if obj.type != "MESH":
            continue
        bm = bmesh.new()
        bm.from_mesh(obj.data)
        bmesh.ops.triangulate(bm, faces=bm.faces[:], quad_method="FIXED", ngon_method="EAR_CLIP")
        bm.to_mesh(obj.data)
        bm.free()
        obj.data.update()


def export_glb(path, objects):
    bpy.ops.object.select_all(action='DESELECT')
    for o in objects:
        o.select_set(True)
    Path(path).parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=str(path), export_format='GLB', use_selection=True,
                              export_image_format='NONE', export_materials='EXPORT', export_tangents=True,
                              export_yup=True, export_apply=False, export_texcoords=True, export_normals=True,
                              export_vertex_color='NONE', export_extras=False)


# --------------------------------------------------------------------------
# preview renders
# --------------------------------------------------------------------------

def _bounds(objects):
    lo = Vector((1e9, 1e9, 1e9))
    hi = Vector((-1e9, -1e9, -1e9))
    for o in objects:
        for c in o.bound_box:
            w = o.matrix_world @ Vector(c)
            lo = Vector(map(min, lo, w))
            hi = Vector(map(max, hi, w))
    return lo, hi


def _cycles(scene, samples=32):
    """Cycles in background mode: GPU compute (OptiX/CUDA) when available,
    otherwise CPU; low samples + OpenImageDenoise. Needs no window or
    OpenGL/Vulkan context (unlike EEVEE/Workbench)."""
    import addon_utils
    addon_utils.enable("cycles", default_set=True, persistent=False)
    scene.render.engine = "CYCLES"
    prefs = bpy.context.preferences.addons["cycles"].preferences
    gpu = False
    for kind in ("OPTIX", "CUDA", "HIP", "ONEAPI"):
        try:
            prefs.compute_device_type = kind
        except TypeError:
            continue
        prefs.get_devices()
        devices = [d for d in prefs.devices if d.type == kind]
        if devices:
            for d in prefs.devices:
                d.use = d.type == kind
            gpu = True
            break
    scene.cycles.device = "GPU" if gpu else "CPU"
    scene.cycles.samples = samples
    scene.cycles.use_adaptive_sampling = True
    scene.cycles.use_denoising = True
    scene.cycles.denoiser = "OPENIMAGEDENOISE"
    scene.cycles.max_bounces = 4
    scene.cycles.transparent_max_bounces = 8
    return gpu


def _studio(scene, lo, radius, elevation=14.0):
    """Floor, three sun lights and a camera for the extra preview renders."""
    fme = bpy.data.meshes.new("_floor")
    s = radius * 8
    fz = lo.z
    fme.from_pydata([(-s, -s, fz), (s, -s, fz), (s, s, fz), (-s, s, fz)], [], [(0, 1, 2, 3)])
    floor = bpy.data.objects.new("_floor", fme)
    fmat = bpy.data.materials.get("_floor") or bpy.data.materials.new("_floor")
    fmat.use_nodes = True
    fmat.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.09, 0.09, 0.1, 1)
    fmat.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.6
    fme.materials.append(fmat)
    scene.collection.objects.link(floor)
    lights = []
    for name, kind, energy, color, rot in (
            ("_key", "SUN", 3.2, (1.0, 0.86, 0.7), (50.0, 0.0, -35.0)),
            ("_fill", "SUN", 0.9, (0.6, 0.72, 1.0), (60.0, 0.0, 140.0)),
            ("_rim", "SUN", 2.0, (0.75, 0.85, 1.0), (20.0, 0.0, 170.0))):
        ld = bpy.data.lights.new(name, kind)
        ld.energy = energy
        ld.color = color
        ld.angle = math.radians(3.0)
        lo_ = bpy.data.objects.new(name, ld)
        lo_.rotation_euler = tuple(math.radians(a) for a in rot)
        scene.collection.objects.link(lo_)
        lights.append(lo_)
    cam_data = bpy.data.cameras.new("_cam")
    cam_data.lens = 50.0
    cam = bpy.data.objects.new("_cam", cam_data)
    scene.collection.objects.link(cam)
    scene.camera = cam
    return floor, lights, cam


def _world(scene):
    scene.render.film_transparent = False
    scene.view_settings.view_transform = "AgX"
    scene.view_settings.look = "AgX - Medium High Contrast"
    world = bpy.data.worlds.get("preview") or bpy.data.worlds.new("preview")
    world.use_nodes = True
    bg = world.node_tree.nodes.get("Background")
    bg.inputs["Color"].default_value = (0.045, 0.05, 0.065, 1.0)
    bg.inputs["Strength"].default_value = 1.0
    scene.world = world


def _shot(scene, w, h, tmp):
    scene.render.resolution_x = w
    scene.render.resolution_y = h
    scene.render.filepath = str(tmp)
    bpy.ops.render.render(write_still=True)
    img = bpy.data.images.load(str(tmp))
    px = np.array(img.pixels[:]).reshape(h, w, 4)[::-1, :, :3]
    bpy.data.images.remove(img)
    return px


def render_first_person(objects, path, cam_pos, look, fov=55.0, size=(960, 540)):
    """What the player sees: camera at ``cam_pos`` (model space) looking
    along ``look``, vertical field of view ``fov`` degrees (Godot keeps the
    height), lit like the other previews, floor 1.5 m below."""
    scene = bpy.context.scene
    _cycles(scene)
    _world(scene)
    lo, hi = _bounds(objects)
    floor, lights, cam = _studio(scene, Vector((0, 0, cam_pos[2] - 1.55)), 3.0)
    cam.data.sensor_fit = "VERTICAL"
    cam.data.angle = math.radians(fov)
    cam.data.clip_start = 0.01
    cam.data.clip_end = 50.0
    cam.location = Vector(cam_pos)
    cam.rotation_euler = Vector(look).normalized().to_track_quat('-Z', 'Y').to_euler()
    tmp = Path(path).with_suffix(".tmp.png")
    px = _shot(scene, size[0], size[1], tmp)
    imageio.save_png(path, np.clip(px, 0, 1))
    tmp.unlink(missing_ok=True)
    for o in [floor, cam] + lights:
        bpy.data.objects.remove(o)


def render_preview(objects, path, size=512, yaws=(-35.0, 35.0, 145.0, 215.0), elevation=14.0, front=-1,
                   closeup=None, extra=()):
    """2x2 contact sheet of Cycles renders (background mode, no window) from
    four yaw angles. ``extra`` adds single close renders:
    [(suffix, (x, y, z) target, radius, yaw deg, elevation deg)] -> <name>_<suffix>.png"""
    if extra:
        _render_extra(objects, path, extra, front)
    scene = bpy.context.scene
    _cycles(scene)
    scene.render.resolution_x = size
    scene.render.resolution_y = size
    scene.render.film_transparent = False
    scene.view_settings.view_transform = "AgX"
    scene.view_settings.look = "AgX - Medium High Contrast"
    world = bpy.data.worlds.get("preview") or bpy.data.worlds.new("preview")
    world.use_nodes = True
    bg = world.node_tree.nodes.get("Background")
    bg.inputs["Color"].default_value = (0.045, 0.05, 0.065, 1.0)
    bg.inputs["Strength"].default_value = 1.0
    scene.world = world
    lo, hi = _bounds(objects)
    center = (lo + hi) * 0.5
    radius = max((hi - lo).length * 0.5, 0.05)
    # floor
    fme = bpy.data.meshes.new("_floor")
    s = radius * 8
    fz = lo.z if elevation >= 0 else hi.z + radius * 4     # seen from below: a "ceiling" far above
    fme.from_pydata([(-s, -s, fz), (s, -s, fz), (s, s, fz), (-s, s, fz)], [], [(0, 1, 2, 3)])
    floor = bpy.data.objects.new("_floor", fme)
    fmat = bpy.data.materials.new("_floor")
    fmat.use_nodes = True
    fmat.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.09, 0.09, 0.1, 1)
    fmat.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.6
    fme.materials.append(fmat)
    scene.collection.objects.link(floor)
    lights = []
    for name, kind, energy, color, rot in (
            ("_key", "SUN", 3.2, (1.0, 0.86, 0.7), (50.0, 0.0, -35.0)),
            ("_fill", "SUN", 0.9, (0.6, 0.72, 1.0), (60.0, 0.0, 140.0)),
            ("_rim", "SUN", 2.0, (0.75, 0.85, 1.0), (20.0, 0.0, 170.0))):
        ld = bpy.data.lights.new(name, kind)
        ld.energy = energy
        ld.color = color
        ld.angle = math.radians(3.0)
        lo_ = bpy.data.objects.new(name, ld)
        lo_.rotation_euler = tuple(math.radians(a) for a in rot)
        scene.collection.objects.link(lo_)
        lights.append(lo_)
    cam_data = bpy.data.cameras.new("_cam")
    cam_data.lens = 50.0
    cam = bpy.data.objects.new("_cam", cam_data)
    scene.collection.objects.link(cam)
    scene.camera = cam
    fov = 2.0 * math.atan(18.0 / cam_data.lens)
    dist = radius / math.sin(fov * 0.5) * 1.05
    tiles = []
    tmp = Path(path).with_suffix(".tmp.png")
    for yaw in yaws:
        a = math.radians(yaw)
        e = math.radians(elevation)
        d = Vector((math.sin(a) * math.cos(e), front * math.cos(a) * math.cos(e), math.sin(e)))
        cam.location = center + d * dist
        cam.rotation_euler = (-d).to_track_quat('-Z', 'Y').to_euler()
        cam_data.clip_start = 0.01
        cam_data.clip_end = dist * 4
        scene.render.filepath = str(tmp)
        bpy.ops.render.render(write_still=True)
        img = bpy.data.images.load(str(tmp))
        px = np.array(img.pixels[:]).reshape(size, size, 4)[::-1, :, :3]
        bpy.data.images.remove(img)
        tiles.append(px)
    sheet = np.concatenate([np.concatenate(tiles[:2], 1), np.concatenate(tiles[2:4], 1)], 0)
    imageio.save_png(path, np.clip(sheet, 0, 1))
    if closeup is not None:
        # one larger front-quarter view of a detail (faces): <name>_closeup.png
        c, r = Vector(closeup[0]), closeup[1]
        big = size * 2
        scene.render.resolution_x = big
        scene.render.resolution_y = big
        a = math.radians(20.0)
        d = Vector((math.sin(a), front * math.cos(a), 0.12)).normalized()
        cam.location = c + d * (r / math.sin(fov * 0.5))
        cam.rotation_euler = (-d).to_track_quat('-Z', 'Y').to_euler()
        scene.render.filepath = str(tmp)
        bpy.ops.render.render(write_still=True)
        img = bpy.data.images.load(str(tmp))
        px = np.array(img.pixels[:]).reshape(big, big, 4)[::-1, :, :3]
        bpy.data.images.remove(img)
        imageio.save_png(Path(path).with_name(Path(path).stem + "_closeup.png"), np.clip(px, 0, 1))
    tmp.unlink(missing_ok=True)
    for o in [floor, cam] + lights:
        bpy.data.objects.remove(o)


def _render_extra(objects, path, extra, front):
    scene = bpy.context.scene
    _cycles(scene)
    _world(scene)
    lo, hi = _bounds(objects)
    radius = max((hi - lo).length * 0.5, 0.05)
    floor, lights, cam = _studio(scene, lo, radius)
    fov = 2.0 * math.atan(18.0 / cam.data.lens)
    tmp = Path(path).with_suffix(".tmp.png")
    for suffix, target, r, yaw, elev in extra:
        a = math.radians(yaw)
        e = math.radians(elev)
        d = Vector((math.sin(a) * math.cos(e), front * math.cos(a) * math.cos(e), math.sin(e)))
        c = Vector(target)
        dist = r / math.sin(fov * 0.5)
        cam.location = c + d * dist
        cam.rotation_euler = (-d).to_track_quat('-Z', 'Y').to_euler()
        cam.data.clip_start = 0.01
        cam.data.clip_end = dist * 6 + radius * 4
        px = _shot(scene, 768, 768, tmp)
        imageio.save_png(Path(path).with_name(Path(path).stem + f"_{suffix}.png"), np.clip(px, 0, 1))
    tmp.unlink(missing_ok=True)
    for o in [floor, cam] + lights:
        bpy.data.objects.remove(o)
