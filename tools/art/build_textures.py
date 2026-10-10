"""Tileable pixel textures for Nocna Zmiana.

Run with Blender's bundled Python (numpy is included), from the repo root:
    "D:/Program Files/Blender Foundation/Blender 5.1/blender.exe" -b --python tools/art/build_textures.py -- [names...]
or any Python 3 with numpy:
    python tools/art/build_textures.py [names...]

Writes assets/textures/<name>_albedo.png, _normal.png and _orm.png
(R = ambient occlusion, G = roughness, B = metallic) and a contact sheet
tests/_out/art/textures_sheet.png. Deterministic: same code -> same pixels.
Texel density: architecture 64 px/m, props 128 px/m, figure 256 px/m.
"""
import sys
import time
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
from artlib import arch_materials, court_materials, egypt, imageio, materials, painter, sprites  # noqa: E402
from artlib import asy  # noqa: E402
from artlib import americas  # noqa: E402
from artlib import asia  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets" / "textures"
SHEET = ROOT / "tests" / "_out" / "art" / "textures_sheet.png"

# name, material, width m, height m, px per metre, normal strength
TILES = [
    ("marble_floor", "marble_floor", 4.0, 4.0, 64, 2.0),
    ("parquet", "parquet", 2.0, 2.0, 64, 2.0),
    ("plaster", "plaster", 2.0, 2.0, 64, 2.0),
    ("wallpaper", "wallpaper", 2.0, 1.5, 64, 2.0),
    ("wall_gallery", "wall_gallery", 4.0, 6.0, 64, 2.0),
    ("wood_dark", "wood_dark", 2.0, 1.0, 64, 2.0),
    ("marble_white", "marble_white", 2.0, 2.0, 64, 2.0),
    ("marble_dark", "marble_dark", 2.0, 2.0, 64, 2.0),
    ("stone", "stone", 2.0, 2.0, 64, 2.0),
    ("brass", "brass", 1.0, 1.0, 128, 1.5),
    ("velvet", "velvet", 1.0, 1.0, 128, 1.5),
    ("glass", "glass", 1.0, 1.0, 128, 1.0),
    ("wax_skin", "wax", 0.5, 0.5, 256, 1.5),
    ("costume_coat", "coat", 0.5, 0.5, 256, 1.5),
    # lobby architecture kit: per-room fields, mapped world-triplanar at 64 px/m
    ("limestone_rustic", "limestone_rustic", 6.0, 3.0, 64, 2.5),
    ("limestone_ashlar", "limestone_ashlar", 4.0, 2.0, 64, 2.0),
    ("limestone", "limestone", 2.0, 2.0, 64, 2.0),
    ("marble_hall", "marble_hall", 4.0, 4.0, 64, 2.0),
    ("terrazzo", "terrazzo", 2.0, 2.0, 64, 1.5),
    ("concrete", "concrete", 4.0, 4.0, 64, 2.0),
    ("linoleum", "linoleum", 2.0, 2.0, 64, 1.5),
    ("ceiling_tiles", "ceiling_tiles", 4.0, 4.0, 64, 2.0),
    ("paint_wall", "paint_wall", 2.0, 3.0, 64, 1.5),
    ("stone_rubble", "stone_rubble", 4.0, 2.0, 64, 2.5),
    ("flagstone", "flagstone", 4.0, 4.0, 64, 2.0),
    ("brick", "brick", 4.0, 2.0, 64, 2.0),
    ("boards", "boards", 2.0, 2.0, 64, 2.0),
    ("grass_fake", "grass_fake", 2.0, 2.0, 64, 2.0),
    ("backdrop", "backdrop", 16.0, 8.0, 64, 1.0),
    ("timber", "timber", 2.0, 1.0, 64, 2.0),
    # Floor I, Egypt wing (tools/art/artlib/egypt.py): fields of the gallery, the tomb and the ceilings
    ("sandstone_ashlar", "sandstone_ashlar", 6.0, 3.0, 64, 2.5),
    ("sandstone", "sandstone", 2.0, 2.0, 64, 2.0),
    ("granite_floor", "granite_floor", 4.0, 4.0, 64, 2.0),
    ("granite_red", "granite_red", 2.0, 2.0, 64, 1.5),
    ("star_ceiling", "star_ceiling", 4.0, 4.0, 64, 1.5),
    ("hieroglyph_band", "hieroglyph_band", 8.0, 1.0, 64, 2.5),
    ("tomb_wall", "tomb_wall", 8.0, 4.0, 64, 1.5),
    # Floor I: Great Court, Reading Room (tools/art/artlib/court_materials.py)
    ("limestone_court", "limestone_court", 6.0, 6.0, 64, 1.5),
    ("portland_ashlar", "portland_ashlar", 4.5, 3.0, 64, 2.0),
    ("court_steel", "court_steel", 2.0, 2.0, 64, 1.0),
    ("carpet_reading", "carpet_reading", 2.0, 2.0, 64, 1.0),
    ("cast_iron", "cast_iron", 2.0, 2.0, 64, 1.0),
    # Floor I, Enlightenment wing: interiors of the bookcases, the library's chevron parquet
    ("enl_mahogany", "enl_mahogany", 2.0, 1.0, 64, 2.0),
    ("parquet_chevron", "parquet_chevron", 2.0, 2.0, 64, 2.0),
    ("enl_bookside", "enl_bookside", 2.0, 1.0, 64, 1.5),
    ("enl_oak_boards", "enl_oak_boards", 2.0, 2.0, 64, 2.0),
    # Floor I, Americas and Oceania wing (tools/art/artlib/americas.py, docs/art/kit-pietro1-ameryki.md)
    ("am_red_wall", "am_red_wall", 4.0, 3.0, 64, 1.5),
    ("am_frieze", "am_frieze", 8.0, 1.0, 64, 2.5),
    ("am_stone_blocks", "am_stone_blocks", 4.0, 3.0, 64, 2.0),
    ("basalt_americas", "basalt_americas", 4.0, 4.0, 64, 2.0),
    ("am_woven_mat", "am_woven_mat", 2.0, 2.0, 64, 1.5),
    ("boards_pacific", "boards_pacific", 2.0, 2.0, 64, 2.0),
    ("am_tapa", "am_tapa", 4.0, 4.0, 64, 1.0),
    ("am_ceiling", "am_ceiling", 4.0, 2.0, 64, 2.0),
    # Floor I, Greek wing (artlib/greek.py)
    ("gr_ashlar", "gr_ashlar", 6.0, 3.0, 64, 2.0),
    ("marble_greek", "marble_greek", 8.0, 8.0, 64, 1.5),
    ("gr_marble", "gr_marble", 2.0, 2.0, 64, 1.5),
    ("gr_plaster", "gr_plaster", 2.0, 2.0, 64, 1.5),
    ("gr_limewash", "gr_limewash", 4.0, 2.0, 64, 2.0),
    ("gr_wall_paint", "gr_wall_paint", 2.0, 2.0, 64, 1.5),
    # Floor I, Assyrian wing (tools/art/artlib/asy.py): orthostat facing, upper walls, mud brick, floors, ceiling
    ("asy_alabaster", "asy_alabaster", 4.0, 3.0, 64, 2.0),
    ("asy_plaster", "asy_plaster", 4.0, 2.0, 64, 1.5),
    ("asy_mudbrick", "asy_mudbrick", 4.0, 2.0, 64, 2.5),
    ("flagstone_asy", "flagstone_asy", 4.0, 4.0, 64, 2.0),
    ("tiles_asy_brick", "tiles_asy_brick", 2.0, 2.0, 64, 2.0),
    ("asy_cedar", "asy_cedar", 2.0, 2.0, 64, 2.0),
    # Floor I, Asia wing (tools/art/artlib/asia.py): halls, porcelain gallery, armour hall, garden, tea house
    ("asia_plaster", "asia_plaster", 2.0, 2.0, 64, 2.0),
    ("asia_plaster_dark", "asia_plaster_dark", 2.0, 2.0, 64, 2.0),
    ("asia_band", "asia_band", 4.0, 1.0, 64, 2.0),
    ("tiles_golden", "tiles_golden", 4.0, 4.0, 64, 2.0),
    ("stone_slate", "stone_slate", 4.0, 4.0, 64, 1.5),
    ("asia_coffers", "asia_coffers", 4.0, 4.0, 64, 2.0),
    ("asia_lacquer", "asia_lacquer", 2.0, 2.0, 64, 1.5),
    ("asia_lacquer_black", "asia_lacquer_black", 2.0, 2.0, 64, 1.5),
    ("boards_dark", "boards_dark", 2.0, 2.0, 64, 2.0),
    ("gravel_raked", "gravel_raked", 4.0, 4.0, 64, 2.5),
    ("gravel_plain", "gravel_plain", 2.0, 2.0, 64, 2.5),
    ("garden_wall", "garden_wall", 4.0, 3.0, 64, 2.0),
    ("tatami", "tatami", 4.0, 2.0, 64, 1.5),
    ("cherry_blossom", "cherry_blossom", 2.0, 2.0, 64, 1.5),
    ("thatch", "thatch", 4.0, 4.0, 64, 2.5),
]

MATERIALS = {**materials.MATERIALS, **arch_materials.MATERIALS, **egypt.MATERIALS, **court_materials.MATERIALS,
             **asia.MATERIALS}
MATERIALS.update(americas.MATERIALS)
from artlib import enl_materials  # noqa: E402  (Enlightenment wing tiles)
MATERIALS.update(enl_materials.TILES)
from artlib import greek  # noqa: E402  (Greek wing tiles)
MATERIALS.update(greek.MATERIALS)
MATERIALS.update(asy.MATERIALS)


def save_set(name, imgs):
    albedo = imgs["albedo"]
    if "alpha" in imgs:
        albedo = np.concatenate([albedo, imgs["alpha"][..., None]], axis=-1)
    imageio.save_png(OUT / f"{name}_albedo.png", albedo)
    imageio.save_png(OUT / f"{name}_normal.png", imgs["normal"])
    imageio.save_png(OUT / f"{name}_orm.png", imgs["orm"])
    if "emit" in imgs:
        imageio.save_png(OUT / f"{name}_emit.png", np.clip(imgs["emit"], 0, 1))


def contact_sheet(entries, path, scale=2, pad=8, max_w=1600):
    """Albedo | normal | roughness of each texture, upscaled with nearest filtering."""
    rows = []
    for name, imgs in entries:
        a = imgs["albedo"][..., :3]
        n = imgs["normal"]
        r = np.repeat(imgs["orm"][..., 1:2], 3, axis=-1)
        strip = np.concatenate([a, np.zeros((a.shape[0], 2, 3)), n, np.zeros((a.shape[0], 2, 3)), r], axis=1)
        strip = np.repeat(np.repeat(strip, scale, axis=0), scale, axis=1)
        rows.append(strip)
    # pack rows into columns so the sheet stays viewable
    cols, col, col_h = [], [], 0
    limit = 1400
    for r in rows:
        if col and col_h + r.shape[0] > limit:
            cols.append(col)
            col, col_h = [], 0
        col.append(r)
        col_h += r.shape[0] + pad
    cols.append(col)
    H = max(sum(r.shape[0] + pad for r in c) for c in cols)
    Wc = [max(r.shape[1] for r in c) for c in cols]
    sheet = np.full((H, sum(Wc) + pad * len(cols), 3), 0.12)
    x = 0
    for c, w in zip(cols, Wc):
        y = 0
        for r in c:
            sheet[y:y + r.shape[0], x:x + r.shape[1]] = r
            y += r.shape[0] + pad
        x += w + pad
    imageio.save_png(path, sheet)


def main(argv):
    names = [a for a in argv if not a.startswith("-")]
    entries = []
    for name, mat, w, h, ppm, ns in TILES:
        if names and name not in names:
            continue
        t0 = time.time()
        imgs = painter.paint_tile(MATERIALS[mat], w, h, ppm, normal_strength=ns)
        save_set(name, imgs)
        entries.append((name, imgs))
        print(f"texture {name:14s} {imgs['albedo'].shape[1]}x{imgs['albedo'].shape[0]}  {time.time() - t0:.1f}s")
    if entries:
        contact_sheet(entries, SHEET)
        print("sheet", SHEET)
    write_sprites()


def write_sprites():
    """Billboard sprite sheet and default CRT screen pictures (not tiles)."""
    imageio.save_png(OUT / "dust_mote.png", sprites.dust_mote())
    for kind in ("cctv", "terminal"):
        img = sprites.crt_picture(kind, seed=5 if kind == "cctv" else 9)
        imageio.save_png(OUT / f"crt_{kind}_albedo.png", img)
        imageio.save_png(OUT / f"crt_{kind}_emit.png", img)
    print("sprites dust_mote (4 frames of 16 px), crt_cctv, crt_terminal")


if __name__ == "__main__":
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    main(argv)
