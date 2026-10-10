"""Procedural models for Nocna Zmiana: geometry, baked pixel atlas, glTF, preview.

Run headless from the repo root (never opens a window):
    "D:/Program Files/Blender Foundation/Blender 5.1/blender.exe" -b --factory-startup \
        --python tools/art/build_models.py -- [model names...] [--fast] [--no-preview]

For each model (tools/art/models/<name>.py) this writes
    assets/models/<name>.glb                  meshes, materials named <name> (+ "glass")
    assets/textures/<name>_albedo/_normal/_orm.png (+ _emit, _sss when used)
    tests/_out/art/<name>.png                 2x2 Cycles preview sheet (+ _closeup, _fp, extras)
--fast skips ambient occlusion rays (quick iteration on shapes).
"""
import importlib
import sys
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

import numpy as np  # noqa: E402

from artlib import bake, imageio, scene  # noqa: E402

ROOT = HERE.parents[1]
TEX = ROOT / "assets" / "textures"
MODELS = ROOT / "assets" / "models"
PREVIEW = ROOT / "tests" / "_out" / "art"

ALL = [
    "pedestal", "bust", "display_case", "column", "wall", "window", "ceiling", "stanchion", "bench",
    "painting", "sconce", "emergency_light", "crystal", "wax_figure",
    # stage 2: enemies, boss, viewmodels, pickups and props
    "wolf", "knight", "bust_enemy", "trex", "vm_fists", "vm_taser", "vm_pistol", "vm_shotgun",
    "ammo_pistol", "ammo_shells", "medkit", "fuse", "lantern", "pistol_locker", "cctv_bank", "terminal",
    "crystal_loose",
    # stage 3 (expansion): weapons 4 and 5, raptor, portraits, pickups
    "vm_gatling", "gatling_display", "vm_flare", "flare_round", "emergency_cabinet", "raptor", "portrait",
    "ammo_rifle", "ammo_flares",
    # stage 2b: the lobby architecture kit (each module builds a family of models; ~15 min in all,
    # the AO rays are cast in Python: several Blender processes in parallel cut that a lot)
    "kit_hall_bands", "kit_hall_orders", "kit_hall_arch", "kit_balcony", "kit_stairs", "kit_hall_ceiling_floor",
    "kit_hall_props", "kit_signs_lamps", "kit_room_bands", "kit_doors", "kit_armory", "kit_diorama", "kit_gallery",
    "kit_lockers", "kit_grate",
    # stage 3: the props the greybox still had (staff furniture, cases, the armour stand, the statue)
    "kit_room_props",
    # Floor I: the three new weapons (viewmodels with upgrade parts and a _master set), their
    # projectiles and ammo pickups
    "vm_rifle_hunt", "vm_harpoon", "vm_hwacha", "harpoon_bolt", "hwacha_rocket",
    "ammo_rifle_hunt", "ammo_harpoon", "ammo_hwacha",
    # Floor I, Egypt wing (docs/art/kit-pietro1-egipt.md): architecture kit, exhibits, camp, enemies, guardian
    "kit_egypt_walls", "kit_egypt_columns", "kit_egypt_portals", "kit_egypt_fixtures",
    "colossus", "pharaoh_statue", "sekhmet", "sarcophagus", "coffin", "rosetta", "exhibits_egypt", "mummy", "scarab",
    "camp_1898",
    # Floor I: the Great Court, the Reading Room and the entrance hall (docs/art/kit-pietro1-dziedziniec.md)
    "court_roof", "court_drum", "court_reading_room", "court_rr_props", "court_props", "totem_haida", "court_signs", "court_stairs", "entrance_kit", "court_grate",
    # Floor I, Enlightenment wing (King's Library kit, cabinets, the Great Orrery, flying books)
    "lib_bookcases", "lib_walkway", "lib_stairs", "lib_ceiling", "lib_portals", "lib_lamps", "lib_cases",
    "planetarium", "flying_book", "lib_natural", "lib_globes", "lib_clocks", "lib_automata",
    "lib_office",
    # Floor I, the Americas and Oceania wing (docs/art/kit-pietro1-ameryki.md): kit, exhibits, enemies, guardian
    "kit_americas_walls", "kit_americas_temple", "kit_americas_fixtures", "americas_exhibits", "sun_stone", "moai",
    "war_canoe", "pacific_exhibits", "totem_poles", "totem", "jaguar", "serpent",
    # Floor I, the Greek wing (Parthenon galleries, Nereid Monument): kit, sculpture, vases, enemies
    "gr_frieze", "gr_bands", "gr_orders", "gr_fittings", "gr_metopes", "gr_bassae", "gr_pediment",
    "nereid", "nereid_statues", "vases", "casts", "hoplite", "centaur",
    # Floor I, the Assyrian wing (palaces of Nineveh and Nimrud): relief slabs, palace kit, Khorsabad gate,
    # the Lamassu guardian, the flat relief enemies and their gypsum debris
    "kit_asy_reliefs", "kit_asy_arch", "kit_asy_props", "relief_warrior", "relief_lion", "lamassu", "khorsabad_gate", "asy_chips",
    # Floor I, Asia wing (docs/art/kit-pietro1-azja.md): kit, exhibits, garden, tea house, enemies, guardian
    "kit_asia_walls", "kit_asia_fixtures", "kit_asia_portals", "buddha", "exhibits_asia", "hwacha_display",
    "samurai_ashigaru", "samurai_general", "samurai_armor_stand", "fu_dog", "garden_kit", "cherry_tree", "teahouse",
    # the voice (docs/superpowers/specs/2026-10-08-glos-projekt.md): the System's wall loudspeaker and
    # the audio-guide stand
    "loudspeaker", "audioguide_stand",
]


def save_maps(name, imgs):
    albedo = imgs["albedo"]
    if "alpha" in imgs:
        albedo = np.concatenate([albedo, imgs["alpha"][..., None]], axis=-1)
    imageio.save_png(TEX / f"{name}_albedo.png", albedo)
    imageio.save_png(TEX / f"{name}_normal.png", imgs["normal"])
    imageio.save_png(TEX / f"{name}_orm.png", imgs["orm"])
    for extra in ("emit", "sss"):
        path = TEX / f"{name}_{extra}.png"
        if extra in imgs:
            imageio.save_png(path, np.clip(imgs[extra], 0, 1))
        elif path.exists():
            path.unlink()


def build_one(module_name, fast=False, preview=True):
    t0 = time.time()
    scene.reset()
    mod = importlib.import_module("models." + module_name)
    variants = mod.build() if hasattr(mod, "build") else None
    if not isinstance(variants, list):
        variants = [variants]
    for m in variants:
        for part in m.parts:
            if part.name in m.organic:
                scene.smart_unwrap(part)
            part.finalize()
        # kit pieces made only of tile materials ("tile:<texture>") have no atlas
        baked = bool(m.fns)
        W, H = bake.pack(m.parts, set(m.fns), m.ppm, m.pad) if baked else (0, 0)
        objs = [scene.to_object(p) for p in m.parts]
        import bpy
        scene.link_parents(m.parts, objs)
        markers = scene.add_markers(m.markers, {o.name: o for o in objs})
        bpy.context.view_layer.update()
        imgs = {}
        if baked:
            imgs = bake.bake(objs, W, H, m.ppm, m.fns, organic=m.organic, ao_rays=0 if fast else m.ao_rays,
                             ao_dist=m.ao_dist, ground=m.ground, pad=m.pad, normal_strength=m.normal_strength,
                             seed=m.seed, ao_stride=m.ao_stride, log=print, planes=m.ao_planes)
            save_maps(m.name, imgs)
        for tname, timgs in m.textures.items():
            save_maps(tname, timgs)
        for sname, simg in m.sheets.items():
            imageio.save_png(PREVIEW / f"{sname}.png", np.clip(simg, 0, 1))
        for vname, vfns in m.variants.items():
            vimgs = bake.bake(objs, W, H, m.ppm, vfns, organic=m.organic, ao_rays=0 if fast else m.ao_rays,
                              ao_dist=m.ao_dist, ground=m.ground, pad=m.pad, normal_strength=m.normal_strength,
                              seed=m.seed, ao_stride=m.ao_stride, log=print, planes=m.ao_planes)
            save_maps(vname, vimgs)
        scene.assign_export_materials(objs, m.name, m.kinds)
        scene.triangulate(objs)
        scene.export_glb(MODELS / f"{m.name}.glb", objs + markers)
        if preview and m.preview:
            if baked:
                scene.atlas_material(m.name, TEX, has_emit="emit" in imgs)
            if "glass" in m.kinds.values():
                scene.glass_material()
            for mat_name, tile in m.preview_kinds.items():
                scene.screen_material(mat_name, TEX / f"{tile}_albedo.png")
            for mat_name in set(m.kinds.values()):
                if mat_name in m.textures:
                    scene.atlas_material(mat_name, TEX, has_emit="emit" in m.textures[mat_name])
            scene.render_preview(objs, PREVIEW / f"{m.name}.png", yaws=m.preview_yaws, elevation=m.preview_elevation,
                                 closeup=m.preview_closeup,
                                 front=m.front, extra=m.preview_extra)
            if m.preview_fp is not None:
                scene.render_first_person(objs, PREVIEW / f"{m.name}_fp.png", *m.preview_fp)
        tris = sum(len(o.data.loop_triangles) for o in objs)
        print(f"model {m.name}: {len(objs)} parts, {tris} tris, atlas {W}x{H} @ {m.ppm} px/m, {time.time() - t0:.1f}s")
        for o in objs:
            print(f"  part {o.name:16s} {len(o.data.loop_triangles):6d} tris  pivot "
                  f"({o.matrix_world.translation.x:.3f}, {o.matrix_world.translation.y:.3f}, "
                  f"{o.matrix_world.translation.z:.3f})" + (f"  parent {o.parent.name}" if o.parent else ""))
        for o in markers:
            w = o.matrix_world.translation
            print(f"  marker {o.name:14s} ({w.x:.3f}, {w.y:.3f}, {w.z:.3f})")
        for o in markers + objs:
            bpy.data.objects.remove(o)


def main(argv):
    fast = "--fast" in argv
    preview = "--no-preview" not in argv
    names = [a for a in argv if not a.startswith("-")] or ALL
    for n in names:
        build_one(n, fast, preview)


if __name__ == "__main__":
    main(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else [])
