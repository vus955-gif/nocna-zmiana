"""Copies the latest screenshots and previews into docs/art/img/ as small JPEGs
for the style guide (docs/art/styl-przewodnik.html). Background Blender only:
    "D:/Program Files/Blender Foundation/Blender 5.1/blender.exe" -b --factory-startup \
        --python tools/art/guide_images.py [-- names...]
Sources: tests/_out/style/<shot>.png (Godot style runner, 1920x1080) and
tests/_out/art/<model>.png (Cycles model previews). Missing files are skipped.
With names after "--", only those previews are converted (e.g. -- wolf wolf_closeup);
the name "lineup" converts the lit-room shots of tests/_out/art_lineup/ (tools/run_art_lineup.sh),
the name "kit" the lobby kit: tests/_out/kit/<shot>.png (tools/run_kit_preview.sh) as
kit_<shot>.jpg plus the kit's model previews.
"""
import sys
from pathlib import Path

import bpy

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "docs" / "art" / "img"
SHOTS = ["wide", "case", "marble", "figure", "flashlight", "painting", "bust", "wide_voxel_high", "wide_none_high"]
MODELS = ["wax_figure", "wax_figure_closeup", "bust", "bust_closeup", "display_case", "wall_window_4m",
          "window", "column", "painting", "stanchion", "bench", "sconce", "crystal", "pedestal", "ceiling_2m",
          "emergency_light", "textures_sheet",
          # stage 2
          "wolf", "wolf_closeup", "knight", "knight_closeup", "knight_shield", "bust_enemy", "bust_enemy_closeup",
          "trex", "trex_closeup", "trex_skull_side", "trex_ribs", "vm_fists", "vm_fists_fp", "vm_taser",
          "vm_taser_fp", "vm_pistol", "vm_pistol_fp", "vm_shotgun", "vm_shotgun_fp", "ammo_pistol", "ammo_shells",
          "medkit", "fuse", "lantern", "pistol_locker", "cctv_bank", "terminal", "crystal_loose", "material_sheet",
          "sprites",
          # stage 3
          "vm_gatling", "vm_gatling_fp", "gatling_display", "gatling_display_plaque", "gatling_display_chain",
          "vm_flare", "vm_flare_fp", "flare_round", "emergency_cabinet", "emergency_cabinet_front", "raptor",
          "raptor_side", "raptor_closeup", "raptor_skull_side", "raptor_foot_side", "portrait", "portrait_face",
          "portrait_corner", "portrait_canvases", "ammo_rifle", "ammo_flares"]
WIDE = {"textures_sheet": 1400, "material_sheet": 1200, "sprites": 720, "portrait_canvases": 1400}
LINEUP = ["enemies", "enemies_dark", "knight_close", "trex", "props", "vm_shotgun", "vm_shotgun_dark",
          # stage 3
          "raptors", "raptors_flare", "raptor_close", "portraits", "portrait_close", "armoury", "cabinet_close",
          "vm_gatling", "vm_gatling_crank", "vm_flare"]
# lobby architecture kit (tools/run_kit_preview.sh and tools/art/models/kit_*.py)
KIT_SHOTS = ["wide", "hall_north", "balcony", "signs", "stair", "stair_east", "doorway", "trex", "booth", "gallery",
             "security", "diorama", "armory", "blackout"]
KIT_MODELS = ["hall_column", "hall_arch_4m", "hall_door_reveal_4m", "hall_cornice_4m", "hall_plinth_4m",
              "hall_pilaster_capital", "balustrade_2m", "balcony_pier", "balcony_fascia_4m", "stair_balustrade_4m",
              "stair_newel", "hall_coffer_2m", "skylight_bay_3m", "floor_border_4m", "floor_medallion",
              "trex_pedestal", "plaque_trex", "ticket_booth", "info_desk", "bench_hall", "fuse_box", "exit_sign",
              "sign_room", "column_lamp", "chandelier", "gallery_base_4m", "gallery_top_4m", "armory_top_4m",
              "corridor_pipes_4m", "door_grand_leaf_l", "door_staff_leaf", "door_slide_leaf", "doorframe_4x4_5",
              "painting_panel", "vent_grille", "grate_leaf_3m", "grate_frame_6m", "timber_beam_4m", "weapon_rack",
              "banner", "rock_a", "dead_tree", "grass_tuft", "fence_rail_2m", "frame_3x2", "frame_0_6x0_8",
              "locker_05m", "emergency_lamp"]


def convert(src, dst, width):
    img = bpy.data.images.load(str(src))
    w, h = img.size
    if w > width:
        img.scale(width, max(1, round(h * width / w)))
    scene = bpy.context.scene
    scene.render.image_settings.file_format = "JPEG"
    scene.render.image_settings.quality = 88
    img.save_render(str(dst), scene=scene)
    bpy.data.images.remove(img)
    print("wrote", dst.relative_to(ROOT))


def main(names):
    OUT.mkdir(parents=True, exist_ok=True)
    if not names:
        for shot in SHOTS:
            src = ROOT / "tests" / "_out" / "style" / f"{shot}.png"
            if src.exists():
                convert(src, OUT / f"{shot}.jpg", 1280)
    if not names or "lineup" in names:
        # stage 2 models in the lit room (tools/run_art_lineup.sh)
        for shot in LINEUP:
            src = ROOT / "tests" / "_out" / "art_lineup" / f"{shot}.png"
            if src.exists():
                convert(src, OUT / f"lineup_{shot}.jpg", 1280)
    if not names or "kit" in names:
        for shot in KIT_SHOTS:
            src = ROOT / "tests" / "_out" / "kit" / f"{shot}.png"
            if src.exists():
                convert(src, OUT / f"kit_{shot}.jpg", 1280)
        for name in KIT_MODELS:
            src = ROOT / "tests" / "_out" / "art" / f"{name}.png"
            if src.exists():
                convert(src, OUT / f"model_{name}.jpg", 720)
        backdrop = ROOT / "assets" / "textures" / "backdrop_albedo.png"
        if backdrop.exists():
            convert(backdrop, OUT / "kit_backdrop.jpg", 1024)
    for name in MODELS:
        if names and name not in names:
            continue
        src = ROOT / "tests" / "_out" / "art" / f"{name}.png"
        if src.exists():
            convert(src, OUT / f"model_{name}.jpg", WIDE.get(name, 720))


main(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else [])
