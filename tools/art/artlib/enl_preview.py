"""Preview helpers of the Enlightenment wing (Blender side only).

Kit pieces may export big interior surfaces as world-mapped tile fields
("tile:<texture>", no atlas space: the game maps them with
arch_tiled.gdshader). The Cycles preview would show those grey; this makes
a stand-in material of the same name with the tile texture box-projected
in object space, so previews look like the game.
"""
from pathlib import Path

import bpy

TEX = Path(__file__).resolve().parents[3] / "assets" / "textures"


def tile_material(slot_name, texture, size_m):
    """Creates the Blender material ``tile:<texture>`` (used by the exporter
    for slot kinds mapped to it) with the tile box-projected, ``size_m``
    metres per repeat (x, y)."""
    name = "tile:" + texture
    mat = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    coord = nt.nodes.new("ShaderNodeTexCoord")
    mapping = nt.nodes.new("ShaderNodeMapping")
    mapping.inputs["Scale"].default_value = (1.0 / size_m[0], 1.0 / size_m[0], 1.0 / size_m[1])
    nt.links.new(coord.outputs["Object"], mapping.inputs["Vector"])
    for channel, socket, non_color in (("albedo", "Base Color", False), ("orm", None, True)):
        path = TEX / f"{texture}_{channel}.png"
        if not path.exists():
            continue
        img = bpy.data.images.load(str(path), check_existing=True)
        if non_color:
            img.colorspace_settings.name = "Non-Color"
        node = nt.nodes.new("ShaderNodeTexImage")
        node.image = img
        node.interpolation = "Closest"
        node.projection = "BOX"
        nt.links.new(mapping.outputs["Vector"], node.inputs["Vector"])
        if socket:
            nt.links.new(node.outputs["Color"], bsdf.inputs[socket])
        else:
            sep = nt.nodes.new("ShaderNodeSeparateColor")
            nt.links.new(node.outputs["Color"], sep.inputs["Color"])
            nt.links.new(sep.outputs["Green"], bsdf.inputs["Roughness"])
    return mat
