"""Model description returned by every tools/art/models/<name>.py build()."""
from dataclasses import dataclass, field


@dataclass
class Model:
    name: str
    parts: list
    fns: dict                      # slot name -> material function (baked into the atlas)
    kinds: dict = field(default_factory=dict)   # slot name -> exported material name (e.g. "glass")
    ppm: int = 128                 # texel density of the atlas, pixels per metre
    pad: int = 4                   # island padding in texels (mipmaps)
    organic: tuple = ()            # part names unwrapped with Smart UV Project + curvature shading
    ao_rays: int = 12
    ao_dist: float = 0.35
    ao_stride: int = 2             # AO computed every n-th texel, spread to neighbours
    ground: float = None           # Z of an implied floor for AO (None = floating)
    ao_planes: tuple = ()          # extra implied planes for AO: ("x" | "y" | "z", value), e.g. the
    #                                wall behind a moulding (("y", 0.0),) or the ceiling above a coffer
    normal_strength: float = 2.0
    seed: int = 0
    front: int = -1                # -1: model faces -Y (props), +1: faces +Y (the wax figure)
    variants: dict = field(default_factory=dict)  # extra texture set name -> fns (same mesh and UVs)
    preview_yaws: tuple = (-35.0, 35.0, 145.0, 215.0)
    preview_elevation: float = 14.0
    preview_closeup: tuple = None  # ((x, y, z), radius): extra close-up render of a detail
    markers: list = field(default_factory=list)  # (name, (x, y, z), parent part or None): empties
    #                                              exported as plain nodes (Muzzle, CrystalSocket, Light)
    preview_kinds: dict = field(default_factory=dict)  # exported material -> tile texture shown
    #                                                    emissive in the preview (screens)
    preview_fp: tuple = None       # ((x, y, z) camera, (x, y, z) look direction): first-person render
    preview_extra: list = field(default_factory=list)  # [(suffix, (x, y, z) target, radius, yaw, elev)]
    textures: dict = field(default_factory=dict)  # extra flat texture sets written next to the atlas:
    #                                               name -> {"albedo", "normal", "orm"[, "emit"]} images
    #                                               (painting canvases fed to a ``kinds`` material)
    sheets: dict = field(default_factory=dict)    # name -> image written to tests/_out/art/<name>.png
    preview: bool = True           # False: no Cycles preview (length variants of a kit run)
