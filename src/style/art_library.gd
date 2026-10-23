class_name ArtLibrary
## Loads the Blender-made models (assets/models/<name>.glb) and dresses them
## with the baked pixel textures (assets/textures/<material>_*.png). The .glb
## files carry only geometry and material NAMES; all shading is decided here,
## so every texture gets the same crisp filtering (nearest texels, mipmaps,
## anisotropic) and the per-material extras (glass, wax subsurface, lamps).

const MODEL_PATH := "res://assets/models/%s.glb"
const TEXTURE_PATH := "res://assets/textures/%s_%s.png"
## Nearest texels up close, mipmaps + anisotropy at grazing angles.
const FILTER := BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS_ANISOTROPIC
const GLASS_SHADER := preload("res://src/style/glass.gdshader")
## Architecture fields (walls, floors, reveals): tile textures mapped by
## position, one crisp axis per face. See [method arch_tile].
const ARCH_TILE_SHADER := preload("res://src/style/arch_tiled.gdshader")
## Material-name prefixes in kit models: "tile:<texture>" = world-mapped
## tile (stretch the piece freely), "tilelocal:<texture>" = mapped in the
## piece's own space (moving false panels keep their pattern).
const TILE_PREFIX := "tile:"
const TILE_LOCAL_PREFIX := "tilelocal:"

## Per-material extras: emission energy, subsurface strength, normal strength.
const EXTRAS := {
	"sconce": {"emission": 4.0},
	"emergency_light": {"emission": 6.0},
	"crystal": {"emission": 1.5},
	"crystal_loose": {"emission": 1.5},
	"wax_figure": {"sss": 0.35},
	"display_case": {"emission": 3.0},
	"wolf": {"emission": 1.2},
	"bison": {"emission": 1.2},
	"knight": {"emission": 2.5},
	"bust_enemy": {"emission": 1.0},
	"lantern": {"emission": 5.0},
	"vm_taser": {"emission": 3.0},
	"vm_taser_master": {"emission": 3.0},
	"vm_hwacha": {"emission": 3.0},
	"vm_hwacha_master": {"emission": 3.0},
	"hwacha_rocket": {"emission": 4.0},
	"cctv_bank": {"emission": 2.0},
	"terminal": {"emission": 2.0},
	"flare_round": {"emission": 6.0},
	# lobby kit fixtures and lit signs
	"exit_sign": {"emission": 2.2},
	"emergency_lamp": {"emission": 6.0},
	"column_lamp": {"emission": 4.0},
	"ceiling_lamp": {"emission": 4.0},
	"chandelier": {"emission": 4.5},
	"tube_lamp": {"emission": 3.0},
	"bulb": {"emission": 5.0},
	"desk_lamp": {"emission": 3.0},
	"stair_newel": {"emission": 4.0},
	"ticket_booth": {"emission": 3.0},
	"info_desk": {"emission": 3.0},
	"fuse_box": {"emission": 3.0},
	# crossed-quad foliage: alpha-cut, two-sided
	"grass_tuft": {"alpha_scissor": 0.5},
	# Floor I, Egypt wing (docs/art/kit-pietro1-egipt.md): the colossus's eyes
	# and chest cracks, the mummy's eyes, lamps and spotlights
	"colossus": {"emission": 3.0},
	"mummy": {"emission": 2.2},
	"egypt_torch_lamp": {"emission": 4.5},
	"egypt_spotlight": {"emission": 5.0},
	"camp_lamp": {"emission": 5.0},
	# Floor I court kit: lanterns, lit windows, desk lamps, signs, globes
	"rr_drum_door": {"emission": 3.0},
	"rr_drum_wall": {"emission": 2.0},
	"rr_dome_sector": {"emission": 1.2},
	"rr_desk": {"emission": 3.5},
	"court_info_desk": {"emission": 2.0},
	"court_lamp_post": {"emission": 4.0},
	# Floor I, Enlightenment wing (docs/art/kit-pietro1-oswiecenie.md): the
	# orrery's sun core, the flying books' eyes, green-shaded lamps, cabinet
	# lamp strips, the rifle cabinet's picture lamp, the celestial globe's stars
	"planetarium": {"emission": 4.0},
	"flying_book": {"emission": 2.2},
	"flying_book_green": {"emission": 2.2},
	"flying_book_blue": {"emission": 2.2},
	"flying_book_black": {"emission": 2.2},
	"lib_lamp_reading": {"emission": 3.5},
	"lib_lamp_wall": {"emission": 3.5},
	"lib_lamp_pendant": {"emission": 3.5},
	"lib_lamp_standard": {"emission": 3.5},
	"lib_nh_shelf_a": {"emission": 2.5},
	"lib_nh_shelf_b": {"emission": 2.5},
	"lib_rifle_rack": {"emission": 3.0},
	"lib_globe_celestial": {"emission": 1.2},
	# Floor I, Americas and Oceania wing (docs/art/kit-pietro1-ameryki.md):
	# fire fixtures, the shrine's embers, the enemies' eyes, the serpent's cracks
	"americas_brazier": {"emission": 4.0},
	"americas_torch_lamp": {"emission": 4.0},
	"temple_shrine": {"emission": 3.0},
	"totem": {"emission": 2.5},
	"jaguar": {"emission": 2.4},
	"serpent": {"emission": 2.2},
	# Floor I, Greek wing: embers in the hoplite's helmet, the centaur's
	# cracked chest and eyes, the lamp strip of the wall case
	"hoplite": {"emission": 2.5},
	"centaur": {"emission": 3.0},
	"vase_case_wall_2m": {"emission": 3.0},
	# Floor I, Assyrian wing (docs/art/kit-pietro1-asyria.md): torch lamps and the
	# brazier; the awakening slabs' cracks are dark at rest (raise the emission on
	# own_materials to telegraph); the Lamassu's cracks in its phase-2/3 set
	"asy_torch": {"emission": 4.5},
	"asy_brazier": {"emission": 4.5},
	"asy_relief_wake": {"emission": 0.0},
	"asy_relief_wake_lion": {"emission": 0.0},
	"lamassu_cracked": {"emission": 2.5},
	# Floor I, Asia wing (docs/art/kit-pietro1-azja.md): silk and paper lanterns, lit
	# lattice and shoji paper
	"asia_lantern_red": {"emission": 3.0},
	"asia_lantern_floor": {"emission": 2.6},
	"asia_lattice_window_lit": {"emission": 1.6},
	"asia_shoji_2m_lit": {"emission": 1.6},
	# Asia wing enemies, guardian, lanterns, the tea house's paper (lit from
	# inside), the cherry's blossom cards and fallen petals (alpha cut)
	"fu_dog": {"emission": 2.5},
	"samurai_ashigaru": {"emission": 2.5},
	"samurai_general": {"emission": 3.0},
	"toro_kasuga": {"emission": 3.5},
	"toro_yukimi": {"emission": 3.5},
	"teahouse": {"emission": 1.6},
	"teahouse_interior": {"emission": 2.0},
	"cherry_tree": {"alpha_scissor": 0.5},
	"pine_fringe": {"alpha_scissor": 0.5},
	"bamboo_leaves": {"alpha_scissor": 0.5},
	"pigeon_door": {"alpha_scissor": 0.5},
	"rr_dome_lantern": {"emission": 1.0},
	"cherry_petals_ground": {"alpha_scissor": 0.5},
	"loudspeaker": {"emission": 3.0},
	# pickups (backlog #11, #43): the print, the stencil and the slot digit
	# glow faintly in the kind's colour, so a box is seen in the dark without
	# shining like a lamp (the shader gives an awake pickup x1.2 of this;
	# WeaponPalette.MAX_PICKUP_EMISSION)
	"ammo_pistol": {"emission": 1.0},
	"ammo_shells": {"emission": 1.0},
	"ammo_rifle": {"emission": 1.0},
	"ammo_flares": {"emission": 1.0},
	"ammo_rifle_hunt": {"emission": 1.0},
	"ammo_harpoon": {"emission": 1.0},
	"ammo_hwacha": {"emission": 1.0},
	"medkit": {"emission": 1.0},
}

## Stage 2 models by id, with the node names the game animates, knocks off
## or reads (all found with [code]find_child(name, true, false)[/code] or
## [method parts]). Chains are nested: a child turns with its parent.
## Markers (plain Node3D) are listed after the meshes. See
## docs/art/styl-przewodnik.html for pivots and budgets.
const REGISTRY := {
	&"wolf": ["body", "head", "jaw", "leg_fl", "leg_fr", "leg_bl", "leg_br", "tail"],
	&"knight": ["torso", "head", "arm_l", "arm_r", "shield", "weapon", "leg_l", "leg_r",
		"plate_pauldron_l", "plate_pauldron_r", "plate_tasset_l", "plate_tasset_r",
		"plate_poleyn_l", "plate_poleyn_r"],
	&"bust_enemy": ["bust", "plinth"],
	&"trex": ["pelvis", "spine_1", "spine_2", "spine_3", "ribs", "neck_1", "neck_2", "neck_3", "skull",
		"jaw", "arm_l", "arm_r", "thigh_l", "shin_l", "foot_l", "thigh_r", "shin_r", "foot_r",
		"tail_1", "tail_2", "tail_3", "tail_4", "tail_5", "tail_6", "tail_7", "tail_8", "CrystalSocket"],
	&"vm_fists": ["fist_l", "fist_r", "upg_wraps_l", "upg_wraps_r", "upg_knuckles_l", "upg_knuckles_r"],
	&"vm_taser": ["taser", "led_1", "led_2", "led_3", "hand_r", "Muzzle", "upg_coil", "upg_prongs"],
	&"vm_pistol": ["pistol", "slide", "hand_r", "Muzzle", "upg_inlay", "upg_mag"],
	&"vm_shotgun": ["shotgun", "barrels", "hammer_l", "hammer_r", "hand_r", "hand_l", "Muzzle", "upg_choke",
		"upg_slug_holder", "sleeve_r", "sleeve_l", "Wrist_r", "Wrist_l", "Grip_r", "Grip_l", "Elbow_r", "Elbow_l"],
	&"ammo_pistol": ["ammo_pistol"],
	&"ammo_shells": ["ammo_shells"],
	&"medkit": ["medkit"],
	&"fuse": ["fuse"],
	&"lantern": ["lantern", "Light"],
	&"pistol_locker": ["locker", "door", "Pistol"],
	&"cctv_bank": ["cctv_bank"],
	&"terminal": ["terminal"],
	&"crystal_loose": ["crystal_loose"],
	# stage 3 (expansion): Gatling and flare pistol, raptor, portraits, pickups
	&"vm_gatling": ["gatling", "barrels", "crank", "belt", "hand_r", "hand_l", "Muzzle", "CrankKnob", "upg_crank",
		"upg_drum", "sleeve_r", "sleeve_l", "Wrist_r", "Wrist_l", "Grip_r", "Grip_l", "Elbow_r", "Elbow_l"],
	&"gatling_display": ["gatling_display", "gun", "chain"],
	&"vm_flare": ["flare", "barrel", "hand_r", "Muzzle", "upg_shroud", "upg_barrel2"],
	&"flare_round": ["flare_round", "Light"],
	&"emergency_cabinet": ["emergency_cabinet", "glass", "flare_gun"],
	&"raptor": ["pelvis", "spine_1", "spine_2", "ribs", "neck_1", "neck_2", "skull", "jaw", "arm_l", "arm_r",
		"thigh_l", "shin_l", "foot_l", "thigh_r", "shin_r", "foot_r",
		"tail_1", "tail_2", "tail_3", "tail_4", "tail_5", "tail_6", "WeakPoint"],
	&"portrait": ["frame", "canvas", "eyes", "WeakPoint"],
	&"ammo_rifle": ["ammo_rifle"],
	&"ammo_flares": ["ammo_flares"],
	# Floor I: the three new weapons (upgrade parts upg_*: WeaponLook), projectiles, ammo
	&"vm_rifle_hunt": ["rifle", "bolt", "bolt_knob", "upg_bolt_ball", "upg_fittings", "clip", "hand_r", "hand_l",
		"Muzzle", "BoltKnob", "sleeve_r", "sleeve_l", "Wrist_r", "Wrist_l", "Grip_r", "Grip_l", "Elbow_r", "Elbow_l"],
	&"vm_harpoon": ["harpoon", "head", "upg_barbs", "rope", "upg_reel", "reel_crank", "hand_r", "hand_l", "Muzzle",
		"LineAnchor", "sleeve_r", "sleeve_l", "Wrist_r", "Wrist_l", "Grip_r", "Grip_l", "Elbow_r", "Elbow_l"],
	&"vm_hwacha": ["hwacha", "rocket_1", "rocket_2", "rocket_3", "rocket_4", "rocket_5", "rocket_6", "upg_box9",
		"rocket_7", "rocket_8", "rocket_9", "upg_fuses", "fuse", "hand_r", "hand_l", "Muzzle", "Tube_1", "Tube_2",
		"Tube_3", "Tube_4", "Tube_5", "Tube_6", "Tube_7", "Tube_8", "Tube_9", "Ember",
		"sleeve_r", "sleeve_l", "Wrist_r", "Wrist_l", "Grip_r", "Grip_l", "Elbow_r", "Elbow_l"],
	&"harpoon_bolt": ["harpoon_bolt", "barbs", "Tail", "Tip"],
	&"hwacha_rocket": ["hwacha_rocket", "Exhaust"],
	&"ammo_rifle_hunt": ["ammo_rifle_hunt"],
	&"ammo_harpoon": ["ammo_harpoon"],
	&"ammo_hwacha": ["ammo_hwacha"],
	# Floor I, Egypt wing (docs/art/kit-pietro1-egipt.md). The guardian: the
	# body chain (stands up off its throne in phase 3) and the static throne.
	&"colossus": ["pelvis", "thigh_l", "thigh_r", "shin_l", "shin_r", "foot_l", "foot_r", "torso", "head", "eyes",
		"uraeus", "upperarm_l", "upperarm_r", "forearm_l", "forearm_r", "palm_l", "palm_r",
		"chest_plate_1", "chest_plate_2", "chest_plate_3", "crack_1", "crack_2", "crack_3",
		"eye_l", "eye_r", "hand_l", "hand_r"],
	&"colossus_throne": ["colossus_throne", "swarm_l", "swarm_r"],
	&"mummy": ["torso", "head", "arm_l", "arm_r", "forearm_l", "forearm_r", "leg_l", "leg_r",
		"whip_1", "whip_2", "whip_3", "whip_4", "strip_1", "strip_2", "strip_3", "strip_4", "EyeGlow", "WeakPoint"],
	&"mummy_debris": ["scrap_1", "scrap_2", "scrap_3", "bone_1", "bone_2"],
	&"scarab": ["scarab"],
	&"scarab_flying": ["scarab_flying"],
	&"scarab_debris": ["shell_l", "shell_r", "body"],
	&"sarcophagus": ["sarcophagus", "lid", "MummySpawn"],
	&"coffin": ["coffin", "lid", "MummySpawn"],
	&"pharaoh_statue": ["pharaoh_statue", "pharaoh_figure"],
	&"sekhmet": ["sekhmet", "head"],
	&"amenhotep_head": ["amenhotep_head", "amenhotep_face"],
	&"obelisk": ["obelisk"],
	&"rosetta_stone": ["rosetta_stone"],
	&"rosetta_case": ["rosetta_case", "rosetta_case_glass", "StoneSpot"],
	&"canopic_jars": ["canopic_jars", "jar_imsety", "jar_hapy", "jar_duamutef", "jar_qebehsenuef"],
	&"shabti_case": ["shabti_case", "shabti_case_glass"],
	&"camp_tent": ["camp_tent", "LampHook"],
	&"camp_crate": ["camp_crate"],
	&"camp_crate_long": ["camp_crate_long"],
	&"camp_crate_open": ["camp_crate_open"],
	&"camp_lamp": ["camp_lamp", "camp_lamp_glass", "Light"],
	&"camp_table": ["camp_table"],
	&"camp_rifle_rack": ["camp_rifle_rack", "weapon_spot"],
	&"camp_chair": ["camp_chair"],
	# Floor I, Enlightenment wing (docs/art/kit-pietro1-oswiecenie.md): the
	# guardian (three spinning tiers, six detachable planets, the opening sun)
	# and the flying books (hinged covers, fluttering leaves, glowing eyes)
	&"planetarium": ["planetarium", "sun_glow", "sun_core", "sun_shell_1", "sun_shell_2", "sun_shell_3",
		"sun_shell_4", "sun_shell_5", "sun_shell_6", "tier_high", "planet_5", "planet_6", "socket_5", "socket_6",
		"tier_low", "planet_1", "planet_2", "socket_1", "socket_2", "tier_mid", "planet_3", "planet_4", "socket_3",
		"socket_4"],
	&"flying_book": ["body", "cover_l", "cover_r", "pages", "eye_l", "eye_r"],
	&"flying_book_page": ["flying_book_page"],
	# Floor I, Americas and Oceania wing (docs/art/kit-pietro1-ameryki.md): the
	# Totem (five stacked faces, shot off from the top), the jaguar warrior, the
	# Two-headed Serpent (14 segments with mosaic plating, two hinged heads), the
	# moai on its turntable, the war canoe that swings down into a bridge, the
	# whaling display with the harpoon gun's places
	&"totem": ["totem", "block_1", "block_2", "block_3", "block_4", "block_5", "eyes_1", "eyes_2", "eyes_3",
		"eyes_4", "eyes_5", "cap", "face_1", "face_2", "face_3", "face_4", "face_5", "mouth_1", "mouth_2",
		"mouth_3", "mouth_4", "mouth_5"],
	&"jaguar": ["pelvis", "torso", "head", "arm_l", "arm_r", "forearm_l", "forearm_r", "club", "shield",
		"thigh_l", "thigh_r", "shin_l", "shin_r", "foot_l", "foot_r", "tail_1", "tail_2", "face", "club_tip"],
	&"serpent": ["segment_1", "segment_2", "segment_3", "segment_4", "segment_5", "segment_6", "segment_7",
		"segment_8", "segment_9", "segment_10", "segment_11", "segment_12", "segment_13", "segment_14",
		"tiles_1", "tiles_2", "tiles_3", "tiles_4", "tiles_5", "tiles_6", "tiles_7", "tiles_8", "tiles_9",
		"tiles_10", "tiles_11", "tiles_12", "tiles_13", "tiles_14", "skull_a", "jaw_a", "skull_b", "jaw_b",
		"seg_1", "seg_2", "seg_3", "seg_4", "seg_5", "seg_6", "seg_7", "seg_8", "seg_9", "seg_10", "seg_11",
		"seg_12", "seg_13", "seg_14", "head_a", "head_b", "mouth_a", "mouth_b"],
	&"moai": ["moai_plinth", "moai", "hook_ring", "face"],
	&"war_canoe": ["war_canoe", "prow", "sling", "rope_main", "hook_ring", "hook_ring_stern", "deck", "bridge_bow",
		"bridge_stern", "rope_top"],
	&"whaling_rack": ["whaling_rack", "weapon_spot"],
	&"harpoon_stand": ["harpoon_stand", "weapon_spot"],
	# Floor I, Greek wing (docs/art/kit-pietro1-grecja.md): the hoplite (KnightRig's
	# part names + forearms, shins, the crest and greaves to knock off), its
	# marble chips, the guardian centaur (three joints per leg) and his javelin
	&"hoplite": ["torso", "head", "plate_crest", "arm_l", "forearm_l", "shield", "arm_r", "forearm_r", "spear",
		"leg_l", "shin_l", "plate_greave_l", "leg_r", "shin_r", "plate_greave_r", "face", "spear_tip"],
	&"marble_chips": ["chip_1", "chip_2", "chip_3", "chip_4", "chip_5", "chip_6"],
	&"centaur": ["barrel", "leg_fl", "knee_fl", "hoof_fl", "leg_fr", "knee_fr", "hoof_fr", "leg_bl", "knee_bl",
		"hoof_bl", "leg_br", "knee_br", "hoof_br", "tail_1", "tail_2", "slab", "torso", "neck", "arm_l", "forearm_l",
		"wrist_l", "arm_r", "forearm_r", "wrist_r", "javelin", "chest", "head", "hand_r"],
	&"javelin": ["javelin", "tip"],
	# Floor I, Assyrian wing (docs/art/kit-pietro1-asyria.md): the guardian
	# Lamassu (legs in three joints, two-part wings, breakable crown), the flat
	# relief warrior and lion (slabs layered front to back, joints turn about
	# the slab normal), gypsum debris
	&"lamassu": ["body", "head", "headdress", "wing_l", "wing_l_tip", "wing_r", "wing_r_tip", "tail",
		"thigh_fl", "shin_fl", "hoof_fl", "thigh_fr", "shin_fr", "hoof_fr",
		"thigh_bl", "shin_bl", "hoof_bl", "thigh_br", "shin_br", "hoof_br",
		"face", "crown", "contact_fl", "contact_fr", "contact_bl", "contact_br"],
	&"relief_warrior": ["torso", "head", "arm_front", "spear", "arm_back", "shield", "leg_front", "leg_back", "eye"],
	&"relief_lion": ["body", "head", "jaw", "tail", "leg_fl", "leg_fr", "leg_bl", "leg_br", "eye"],
	&"asy_gypsum_chips": ["chip_1", "chip_2", "chip_3", "chip_4", "chip_5", "chip_6", "chip_7", "chip_8"],
	# Floor I, Asia wing (docs/art/kit-pietro1-azja.md): exhibits, the garden and
	# the tea house, the two enemies and the guardian
	&"buddha_seated": ["buddha_seated", "buddha_mandorla", "buddha_figure", "buddha_head", "Halo", "Offering"],
	&"bronze_ding": ["bronze_ding"],
	&"bronze_gu": ["bronze_gu"],
	&"vase_blue_white": ["vase_blue_white"],
	&"vase_celadon": ["vase_celadon"],
	&"moon_jar": ["moon_jar"],
	&"scroll_hanging": ["scroll_hanging"],
	&"temple_bell": ["temple_bell", "bell", "striker"],
	&"hwacha_display": ["hwacha_display", "weapon_spot"],
	&"samurai_armor_stand": ["samurai_armor_stand"],
	&"garden_rock_a": ["garden_rock_a"],
	&"garden_rock_b": ["garden_rock_b"],
	&"garden_rock_c": ["garden_rock_c"],
	&"garden_rock_d": ["garden_rock_d"],
	&"toro_kasuga": ["toro_kasuga", "Light"],
	&"toro_yukimi": ["toro_yukimi", "Light"],
	&"garden_bridge": ["garden_bridge"],
	&"garden_pond": ["garden_pond", "garden_pond_water"],
	&"cherry_petals_ground": ["cherry_petals_ground"],
	&"teahouse_interior": ["teahouse_interior", "terminal_spot", "Light"],
	&"fu_dog": ["body", "head", "jaw", "pearl", "leg_fl", "leg_fr", "shin_fl", "shin_fr", "leg_bl", "leg_br",
		"shin_bl", "shin_br", "tail", "ball", "mouth_ball", "roar"],
	&"samurai_ashigaru": ["torso", "head", "arm_l", "arm_r", "shield", "weapon", "leg_l", "leg_r",
		"plate_pauldron_r", "plate_tasset_l", "plate_tasset_r", "plate_poleyn_l", "plate_poleyn_r", "face",
		"spear_tip"],
	&"samurai_general": ["pelvis", "torso", "head", "upperarm_l", "upperarm_r", "sode_l", "sode_r", "forearm_l",
		"forearm_r", "hand_l", "hand_r", "sword", "saya", "bow", "quiver", "arrow", "thigh_l", "thigh_r", "shin_l",
		"shin_r", "foot_l", "foot_r", "kusazuri_f", "kusazuri_b", "kusazuri_l", "kusazuri_r", "face", "back",
		"blade_tip", "glint", "bow_grip", "arrow_nock", "saya_mouth"],
	# the voice (VoiceDirector): the System's wall loudspeaker, the audio-guide stand with its button
	&"loudspeaker": ["loudspeaker"],
	&"audioguide_stand": ["audioguide_stand", "button"],
}
## Extra texture sets of Asia-wing models in REGISTRY (same mesh and UVs):
## [code]instance(&"scroll_hanging", {"scroll_hanging": "scroll_hanging_enso"})[/code].
const ASIA_SETS := {
	&"scroll_hanging": ["scroll_hanging_water", "scroll_hanging_moon", "scroll_hanging_enso"],
	&"samurai_armor_stand": ["samurai_armor_stand_blue", "samurai_armor_stand_white"],
}
## Extra texture sets of Egypt-wing models in REGISTRY (same mesh and UVs):
## [code]instance(&"sarcophagus", {"sarcophagus": "sarcophagus_red"})[/code].
const EGYPT_SETS := {
	&"sarcophagus": ["sarcophagus_red"],
	&"coffin": ["coffin_black"],
	&"camp_crate": ["camp_crate_b"],
}
## Extra texture sets of Assyrian-wing models in REGISTRY: the Lamassu with
## glowing cracks (phases 2-3):
## [code]exhibit(&"lamassu", {"lamassu": "lamassu_cracked"})[/code].
const ASSYRIA_SETS := {
	&"lamassu": ["lamassu_cracked"],
}

## Painted canvases for the "portrait" model (texture sets; swap the
## default "canvas_aristocrat" material:
## [code]instance(&"portrait", {"canvas_aristocrat": "canvas_bishop"})[/code]).
## PORTRAIT_FACES have eyes under the model's "eyes" part (a portrait enemy
## can wake up in any of them); on PORTRAIT_SCENES hide "eyes".
const PORTRAIT_FACES: Array[String] = ["canvas_aristocrat", "canvas_lady_fan", "canvas_general",
	"canvas_child_dog", "canvas_bishop", "canvas_merchant"]
const PORTRAIT_SCENES: Array[String] = ["canvas_landscape", "canvas_seascape", "canvas_still_life",
	"canvas_flowers"]
## The portrait eyes follow the guard by sliding this material's uv1_offset
## on the instance's own copy (own_materials): x -0.2 .. 0.2 = irises to the
## viewer's right .. left, y -0.08 .. 0.08 = down .. up.
const PORTRAIT_EYES_MATERIAL := "portrait_eyes"
const PORTRAIT_EYES_REACH := Vector2(0.2, 0.08)

## The lobby's modular architecture kit (tools/art/models/kit_*.py): model id
## -> named nodes (parts and markers) the game may look up; [] = one mesh
## named after the model or its part. Kit convention: origin = centre of the
## base, front = -Z, as LevelKit. How each greybox piece maps onto these, and
## how runs are fitted, lives in ArtKit (src/style/art_kit.gd).
const KIT := {
	&"hall_plinth_4m": [],
	&"hall_plinth_2m": [],
	&"hall_plinth_1m": [],
	&"hall_plinth_05m": [],
	&"hall_upper_base_4m": [],
	&"hall_upper_base_2m": [],
	&"hall_upper_base_1m": [],
	&"hall_upper_base_05m": [],
	&"hall_string_4m": [],
	&"hall_string_2m": [],
	&"hall_string_1m": [],
	&"hall_string_05m": [],
	&"hall_cornice_4m": [],
	&"hall_cornice_2m": [],
	&"hall_cornice_1m": [],
	&"hall_cornice_05m": [],
	&"hall_column": ["hall_column"],
	&"hall_pilaster_base": [],
	&"hall_pilaster_shaft": [],
	&"hall_pilaster_capital": [],
	&"hall_arch_4m": [],
	&"hall_door_reveal_4m": [],
	&"balcony_fascia_4m": [],
	&"balcony_fascia_2m": [],
	&"balcony_fascia_1m": [],
	&"balcony_fascia_end": [],
	&"balustrade_2m": [],
	&"balustrade_1m": [],
	&"balustrade_pedestal": [],
	&"balcony_pier": [],
	&"stair_step_4m": [],
	&"stair_step_1m": [],
	&"stair_wedge": [],
	&"stair_stringer_4m": [],
	&"stair_balustrade_4m": [],
	&"stair_newel": ["stair_newel", "Light"],
	&"hall_coffer_2m": [],
	&"skylight_bay_3m": ["skylight_bay_3m", "skylight_bay_3m_glass"],
	&"skylight_gable_3m": ["skylight_gable_3m", "skylight_gable_3m_glass"],
	&"floor_border_4m": [],
	&"floor_border_2m": [],
	&"floor_border_1m": [],
	&"floor_border_05m": [],
	&"floor_border_corner": [],
	&"floor_medallion": [],
	&"trex_pedestal": [],
	&"plaque_trex": [],
	&"ticket_booth": ["ticket_booth", "ticket_booth_glass", "drawer", "Light"],
	&"info_desk": [],
	&"bench_hall": [],
	&"fuse_box": ["fuse_box", "lever", "lamp_red", "lamp_green", "Fuse_A", "Fuse_B"],
	&"exit_sign": [],
	&"emergency_lamp": [],
	&"sign_room": [],
	&"sign_staff": [],
	&"column_lamp": [],
	&"ceiling_lamp": [],
	&"chandelier": [],
	&"tube_lamp": [],
	&"bulb": [],
	&"desk_lamp": [],
	&"gallery_base_4m": [],
	&"gallery_base_2m": [],
	&"gallery_base_1m": [],
	&"gallery_base_05m": [],
	&"gallery_top_4m": [],
	&"gallery_top_2m": [],
	&"gallery_top_1m": [],
	&"gallery_top_05m": [],
	&"skirting_4m": [],
	&"skirting_2m": [],
	&"skirting_1m": [],
	&"skirting_05m": [],
	&"diorama_base_4m": [],
	&"diorama_base_2m": [],
	&"diorama_base_1m": [],
	&"diorama_base_05m": [],
	&"armory_top_4m": [],
	&"armory_top_2m": [],
	&"armory_top_1m": [],
	&"diorama_top_4m": [],
	&"diorama_top_2m": [],
	&"diorama_top_1m": [],
	&"security_rail_4m": [],
	&"security_rail_2m": [],
	&"security_rail_1m": [],
	&"corridor_pipes_4m": [],
	&"corridor_pipes_2m": [],
	&"corridor_pipes_1m": [],
	&"door_grand_leaf_l": ["door_grand_leaf_l", "door_grand_leaf_l_glass"],
	&"door_grand_leaf_r": ["door_grand_leaf_r", "door_grand_leaf_r_glass"],
	&"door_staff_leaf": [],
	&"door_slide_leaf": [],
	&"doorframe_4x4_5": [],
	&"doorframe_2x2_8": [],
	&"doorframe_2x2_6": [],
	&"false_panel_hall": ["false_panel_hall", "hall_upper_base_band"],
	&"false_panel_armory": ["false_panel_armory", "hall_plinth_band"],
	&"painting_panel": ["painting_panel", "gallery_base_band"],
	&"vent_grille": [],
	&"grate_leaf_3m": [],
	&"grate_frame_6m": [],
	&"timber_beam_4m": [],
	&"timber_corbel": [],
	&"weapon_rack": [],
	&"banner": [],
	&"rock_a": [],
	&"rock_b": [],
	&"dead_tree": [],
	&"grass_tuft": [],
	&"fence_rail_2m": [],
	&"fence_rail_1m": [],
	&"fence_post": [],
	&"frame_3x2": [],
	&"frame_3_5x2_2": [],
	&"frame_2_4x1_8": [],
	&"frame_1_2x0_9": [],
	&"frame_0_6x0_8": [],
	&"locker_05m": ["locker", "door"],
	# Floor I, Egypt wing (docs/art/kit-pietro1-egipt.md)
	&"egypt_dado_4m": [],
	&"egypt_dado_2m": [],
	&"egypt_dado_1m": [],
	&"egypt_dado_05m": [],
	&"egypt_frieze_4m": [],
	&"egypt_frieze_2m": [],
	&"egypt_frieze_1m": [],
	&"egypt_frieze_05m": [],
	&"egypt_cornice_4m": [],
	&"egypt_cornice_2m": [],
	&"egypt_cornice_1m": [],
	&"egypt_cornice_05m": [],
	&"egypt_beam_4m": [],
	&"egypt_beam_2m": [],
	&"egypt_beam_1m": [],
	&"egypt_column": ["egypt_column"],
	&"egypt_column_open": ["egypt_column_open"],
	&"egypt_column_stump": [],
	&"egypt_column_open_stump": [],
	&"egypt_column_drums": ["drum_a", "drum_b", "chunk_a", "chunk_b", "chunk_c"],
	&"egypt_portal_4m": [],
	&"egypt_doorframe_2x2_8": [],
	&"egypt_portal_great": [],
	&"egypt_seal_door_l": ["egypt_seal_door_l", "SealSocket"],
	&"egypt_seal_door_r": [],
	&"egypt_boarded_doorway": ["egypt_boarded_doorway", "plank_1", "plank_2", "plank_3", "plank_4", "plank_5",
		"plank_6", "plank_7", "plank_8", "sign"],
	&"egypt_clerestory_3m": ["egypt_clerestory_3m", "egypt_clerestory_3m_glass"],
	&"egypt_plinth": [],
	&"egypt_torch_lamp": ["egypt_torch_lamp", "Light"],
	&"egypt_spotlight": ["egypt_spotlight", "Light"],
	# Floor I: the Great Court, the Reading Room and the entrance hall
	# (tools/art/models/court_*.py, entrance_kit.py, totem_haida.py; sizes,
	# pivots and placement in KIT_COURT and docs/art/kit-pietro1-dziedziniec.md)
	&"court_roof_q": ["court_roof_q", "court_roof_q_glass"],
	&"rr_drum_wall": [],
	&"rr_drum_door": ["rr_drum_door", "Light_L", "Light_R"],
	&"rr_bookcase": [],
	&"rr_bookcase_door": [],
	&"rr_dome_sector": ["rr_dome_sector", "Light_Dome"],
	&"rr_oculus": ["rr_oculus", "rr_oculus_glass"],
	&"rr_dome_outer": [],
	&"rr_desk": ["rr_desk", "Light_1", "Light_2", "Light_3"],
	&"rr_catalogue_arc": [],
	&"astrolabe": ["astrolabe", "ring_outer", "ring_middle", "ring_inner", "Shard_1", "Shard_2", "Shard_3",
		"Shard_4", "Shard_5", "Shard_6", "Core"],
	&"steam_banner": [],
	&"steam_podium": [],
	&"steam_engine": ["steam_engine", "flywheel", "governor"],
	&"court_bench": [],
	&"court_info_desk": ["court_info_desk", "Light"],
	&"cafe_counter": ["cafe_counter", "cafe_counter_glass"],
	&"cafe_table": [],
	&"cafe_chair": [],
	&"shop_front": ["shop_front", "grille"],
	&"court_plinth": [],
	&"court_lamp_post": ["court_lamp_post", "Light", "Light_L", "Light_R"],
	&"totem_haida": [],
	&"sign_wing": [],
	&"sign_wing_portal": [],
	&"court_map_board": [],
	&"court_balcony_seg": [],
	&"court_balcony_seg_open": [],
	&"court_parapet_2m": [],
	&"court_parapet_1m": [],
	&"court_stair_step": [],
	&"court_stair_parapet_4m": [],
	&"court_stair_mass": [],
	&"entrance_column": [],
	&"entrance_coffer_3m": [],
	&"entrance_door_l": [],
	&"entrance_door_r": [],
	&"entrance_door_sign": [],
	&"cloakroom_counter": [],
	&"entrance_mosaic": [],
	&"grate_leaf_4m": [],
	&"grate_frame_8m": [],
	# Floor I, Enlightenment wing (docs/art/kit-pietro1-oswiecenie.md): King's
	# Library kit, cabinets of curiosities, clocks and automata, the office
	&"lib_antlers": [],
	&"lib_automaton_writer": ["lib_automaton_writer", "arm_r", "head"],
	&"lib_bird_cage": ["lib_bird_cage", "bird", "bird_head"],
	&"lib_bookcase_1m": [],
	&"lib_bookcase_a_2m": [],
	&"lib_bookcase_b_2m": [],
	&"lib_bookcase_c_2m": [],
	&"lib_bookcase_pilaster_low": [],
	&"lib_bookcase_pilaster_up": [],
	&"lib_bookcase_up_1m": [],
	&"lib_bookcase_up_a_2m": [],
	&"lib_bookcase_up_b_2m": [],
	&"lib_bust_bracket": ["lib_bust_bracket", "bust_spot"],
	&"lib_card_catalogue": [],
	&"lib_case_coins": ["lib_case_coins", "lib_case_coins_glass"],
	&"lib_case_instruments": ["lib_case_instruments", "lib_case_instruments_glass"],
	&"lib_case_minerals": ["lib_case_minerals", "lib_case_minerals_glass"],
	&"lib_case_shells": ["lib_case_shells", "lib_case_shells_glass"],
	&"lib_clock_longcase": ["lib_clock_longcase", "hand_hour", "hand_minute", "pendulum", "lib_clock_longcase_glass"],
	&"lib_clock_wall": ["lib_clock_wall", "hour_1", "hour_2", "hour_3", "hour_4", "hour_5", "hour_6", "hour_7",
		"minute_1", "minute_2", "minute_3", "minute_4", "minute_5", "minute_6", "minute_7", "pendulum_1", "pendulum_2"],
	&"lib_coffer_2m": [],
	&"lib_cornice_1m": [],
	&"lib_cornice_2m": [],
	&"lib_cornice_4m": [],
	&"lib_diorama_base": ["lib_diorama_base", "animal_spot_1", "animal_spot_2"],
	&"lib_doorframe_2x2_8": [],
	&"lib_filing_cabinet": [],
	&"lib_globe_celestial": ["lib_globe_celestial", "globe"],
	&"lib_globe_terrestrial": ["lib_globe_terrestrial", "globe"],
	&"lib_ladder": [],
	&"lib_ladder_rail_2m": [],
	&"lib_lamp_pendant": ["lib_lamp_pendant", "Light"],
	&"lib_lamp_reading": ["lib_lamp_reading", "Light"],
	&"lib_lamp_rod_1m": [],
	&"lib_lamp_standard": ["lib_lamp_standard", "Light"],
	&"lib_lamp_wall": ["lib_lamp_wall", "Light"],
	&"lib_nh_shelf_a": ["lib_nh_shelf_a", "lib_nh_shelf_a_glass", "Light"],
	&"lib_nh_shelf_b": ["lib_nh_shelf_b", "lib_nh_shelf_b_glass", "Light"],
	&"lib_office_chair": [],
	&"lib_office_desk": ["lib_office_desk", "terminal_spot"],
	&"lib_portal_4x4_5": [],
	&"lib_railing_1m": [],
	&"lib_railing_2m": [],
	&"lib_railing_post": [],
	&"lib_rifle_rack": ["lib_rifle_rack", "weapon_spot", "Light"],
	&"lib_sign": [],
	&"lib_skylight_well_4m": ["lib_skylight_well", "lib_skylight_well_glass"],
	&"lib_stair_newel": [],
	&"lib_stair_railing_4m": [],
	&"lib_stair_spiral": ["lib_stair_spiral", "stair_bottom", "stair_top"],
	&"lib_stair_step_1m": [],
	&"lib_stair_stringer_4m": [],
	&"lib_walkway_bracket": [],
	&"lib_walkway_fascia_1m": [],
	&"lib_walkway_fascia_2m": [],
	&"lib_walkway_fascia_4m": [],
	&"lib_walkway_fascia_end": [],
	# Floor I, Americas and Oceania wing (tools/art/models/kit_americas_*.py,
	# americas_exhibits.py, sun_stone.py, pacific_exhibits.py, totem_poles.py;
	# sizes, pivots and placement in KIT_AMERICAS and docs/art/kit-pietro1-ameryki.md)
	&"americas_dado_4m": [],
	&"americas_dado_2m": [],
	&"americas_dado_1m": [],
	&"americas_dado_05m": [],
	&"americas_frieze_4m": [],
	&"americas_frieze_2m": [],
	&"americas_frieze_1m": [],
	&"americas_frieze_05m": [],
	&"americas_cornice_4m": [],
	&"americas_cornice_2m": [],
	&"americas_cornice_1m": [],
	&"americas_cornice_05m": [],
	&"pacific_dado_4m": [],
	&"pacific_dado_2m": [],
	&"pacific_dado_1m": [],
	&"pacific_dado_05m": [],
	&"pacific_beam_4m": [],
	&"pacific_beam_2m": [],
	&"pacific_beam_1m": [],
	&"pacific_post": ["pacific_post", "pacific_post_figure"],
	&"temple_tier_4m": [],
	&"temple_tier_2m": [],
	&"temple_tier_1m": [],
	&"temple_tier_corner": [],
	&"temple_stair": ["temple_stair", "serpent_heads"],
	&"temple_shrine": ["temple_shrine", "Light"],
	&"temple_altar": [],
	&"americas_brazier": ["americas_brazier", "flame", "Light"],
	&"americas_torch_lamp": ["americas_torch_lamp", "flame", "Light"],
	&"americas_portal_4m": [],
	&"mask_case": ["mask_case", "mask_case_glass", "mask_1", "mask_2", "mask_3"],
	&"turquoise_mask": ["turquoise_mask", "turquoise_mask_stand"],
	&"serpent_mosaic": ["serpent_mosaic", "serpent_body", "serpent_mosaic_glass"],
	&"sun_stone": ["sun_stone", "sun_stone_disc"],
	&"clay_figures": ["clay_figures", "clay_figures_pieces"],
	&"feather_case": ["feather_case", "feather_case_glass", "feather_pieces"],
	&"tapa_hanging": [],
	&"pacific_figures": ["pacific_figures", "pacific_figures_glass", "pacific_figures_pieces"],
	&"totem_pole_memorial": [],
	&"totem_pole_house": [],
	&"totem_pole_welcome": [],
	&"totem_log": [],
	# Floor I props modelled in Blender in place of procedural solids (plan
	# docs/superpowers/plans/2026-10-21-modele-blender.md; sizes and budgets in KIT_PROPS)
	&"bison": ["bison"],
	&"asy_chariot": ["asy_chariot"],
	&"asy_cage": ["asy_cage"],
	&"kayak": ["kayak"],
	&"kayak_stand": ["kayak_stand"],
	&"whaleboat": ["whaleboat"],
	&"tipi": ["tipi"],
	&"garden_pine": ["garden_pine"],
	&"garden_bamboo": ["garden_bamboo"],
	&"roof_water_tank": ["roof_water_tank"],
	&"roof_air_handler": ["roof_air_handler"],
	&"roof_chimney_tall": ["roof_chimney_tall"],
	&"roof_chimney_short": ["roof_chimney_short"],
	&"roof_pigeon_loft": ["roof_pigeon_loft"],
	&"asy_scaffold": ["asy_scaffold"],
	&"rr_dome_lantern": ["rr_dome_lantern", "rr_dome_lantern_glass"],
	# Floor I, Greek wing (tools/art/models/gr_*.py; catalog docs/art/kit-pietro1-grecja.md)
	&"gr_frieze_4m": [],
	&"gr_frieze_2m": [],
	&"gr_frieze_1m": [],
	&"gr_frieze_05m": [],
	&"gr_base_4m": [],
	&"gr_base_2m": [],
	&"gr_base_1m": [],
	&"gr_base_05m": [],
	&"gr_cornice_4m": [],
	&"gr_cornice_2m": [],
	&"gr_cornice_1m": [],
	&"gr_cornice_05m": [],
	&"gr_cornice_doric_4m": [],
	&"gr_cornice_doric_2m": [],
	&"gr_cornice_doric_1m": [],
	&"gr_column_doric": [],
	&"gr_column_ionic": [],
	&"gr_drum": [],
	&"gr_capital_doric": [],
	&"gr_portal_4m": [],
	&"gr_portal_2m": [],
	&"gr_skylight_4m": ["gr_skylight_4m", "gr_skylight_4m_glass"],
	&"gr_coffer_2m": [],
	&"gr_floor_border_4m": [],
	&"gr_floor_border_2m": [],
	&"gr_floor_border_1m": [],
	&"gr_floor_border_05m": [],
	&"gr_floor_border_corner": [],
	&"gr_plinth_low": [],
	&"gr_plinth_block": [],
	&"gr_metope_a": [],
	&"gr_metope_b": [],
	&"gr_metope_c": [],
	&"gr_metope_d": [],
	&"gr_bassae_2m": [],
	&"gr_bassae_1m": [],
	&"gr_ped_reclining": [],
	&"gr_ped_goddesses": [],
	&"gr_ped_seated": [],
	&"gr_ped_horse": [],
	&"gr_ped_torso": [],
	&"nereid_podium": [],
	&"nereid_temple": ["nereid_temple", "nereid_column_1", "nereid_column_2", "nereid_column_3", "nereid_column_4", "nereid_column_5", "nereid_column_6"],
	&"nereid_a": [],
	&"nereid_b": [],
	&"nereid_c": [],
	&"nereid_d": [],
	&"vase_amphora_bf": [],
	&"vase_amphora_rf": [],
	&"vase_krater": [],
	&"vase_volute": [],
	&"vase_hydria": [],
	&"vase_kylix": [],
	&"vase_lekythos": [],
	&"vase_case_tall": ["vase_case_tall", "vase_case_tall_glass", "VaseSpot"],
	&"vase_case_wall_2m": ["vase_case_wall_2m", "vase_case_wall_2m_glass", "Shelf_0", "Shelf_1", "Shelf_2"],
	&"cast_frieze_slab": [],
	&"cast_head": [],
	&"cast_torso": [],
	&"cast_shelf": [],
	&"cast_crate": [],
	# Floor I, Assyrian wing (docs/art/kit-pietro1-asyria.md): relief slabs (wall
	# runs of 2 and 1 m, ArtKit band "asy_relief_"), the awakening slabs, the
	# palace kit, the Balawat leaves (the Wing Seal gate), the tablet store and
	# the Khorsabad Gate with its five-legged lamassu
	&"asy_relief_2m": [],
	&"asy_relief_1m": [],
	&"asy_relief_wake": ["asy_relief_wake", "figure"],
	&"asy_relief_wake_lion": ["asy_relief_wake_lion", "figure"],
	&"asy_frieze_4m": [],
	&"asy_frieze_2m": [],
	&"asy_frieze_1m": [],
	&"asy_beam_4m": [],
	&"asy_corbel": [],
	&"asy_parapet_2m": [],
	&"asy_portal_4m": [],
	&"asy_doorframe_2x2_6": [],
	&"asy_threshold_4m": [],
	&"asy_plinth": [],
	&"asy_plinth_low": [],
	&"asy_torch": ["asy_torch", "Light"],
	&"asy_brazier": ["asy_brazier", "Light"],
	&"asy_balawat_leaf_l": ["asy_balawat_leaf_l", "SealSocket", "seal_socket"],
	&"asy_balawat_leaf_r": [],
	&"asy_tablet_shelf": [],
	&"asy_tablet_crate": [],
	&"asy_prism": [],
	&"khorsabad_gate": ["khorsabad_gate", "lamassu_l", "lamassu_l_body", "lamassu_r", "lamassu_r_body",
		"door_l", "door_r", "seal_socket", "SealSocket", "Light_l", "Light_r"],
	# Floor I, Asia wing (tools/art/models/kit_asia_*.py; sizes, pivots, placement in
	# docs/art/kit-pietro1-azja.md)
	&"asia_dado_4m": [],
	&"asia_dado_2m": [],
	&"asia_dado_1m": [],
	&"asia_dado_05m": [],
	&"asia_frieze_4m": [],
	&"asia_frieze_2m": [],
	&"asia_frieze_1m": [],
	&"asia_frieze_05m": [],
	&"asia_eaves_4m": [],
	&"asia_eaves_2m": [],
	&"asia_eaves_1m": [],
	&"asia_beam_4m": [],
	&"asia_corbel": [],
	&"asia_post_base": [],
	&"asia_post_shaft": [],
	&"asia_post_capital": [],
	&"asia_moon_gate_4m": [],
	&"asia_doorframe_2x2_6": [],
	&"asia_lattice_window": [],
	&"asia_shoji_2m": [],
	&"asia_wallcap_4m": [],
	&"asia_wallcap_2m": [],
	&"asia_wallcap_1m": [],
	&"asia_lantern_red": ["asia_lantern_red", "Light"],
	&"asia_lantern_floor": ["asia_lantern_floor", "Light"],
	&"asia_case_tall": ["asia_case_tall", "asia_case_tall_glass", "ItemSpot"],
	&"asia_case_low": ["asia_case_low", "asia_case_low_glass", "ItemSpot_1", "ItemSpot_2", "ItemSpot_3"],
	&"asia_plinth": ["asia_plinth", "ItemSpot"],
	# the garden's two pieces with world-mapped fields (blossom clouds, thatch)
	&"cherry_tree": ["cherry_tree", "cherry_blossom", "Petals_1", "Petals_2", "Petals_3", "Petals_4", "Petals_5",
		"Petals_6", "Petals_7", "Petals_8", "Petals_9", "Petals_10"],
	&"teahouse": ["teahouse", "basin", "roof_perch", "roof_perch_eave", "basin_water"],
}
## Extra texture sets of kit models (same mesh and UVs): pass
## {"<model>": "<set>"} as the swap of [method model] (ArtKit.model does).
const KIT_SETS := {
	&"hall_column": ["hall_column_grey"],
	&"hall_plinth_4m": ["armory_plinth_4m"],
	&"hall_plinth_2m": ["armory_plinth_2m"],
	&"hall_plinth_1m": ["armory_plinth_1m"],
	&"hall_plinth_05m": ["armory_plinth_05m"],
	&"skirting_4m": ["skirting_black_4m", "skirting_pine_4m"],
	&"skirting_2m": ["skirting_black_2m", "skirting_pine_2m"],
	&"skirting_1m": ["skirting_black_1m", "skirting_pine_1m"],
	&"skirting_05m": ["skirting_black_05m", "skirting_pine_05m"],
	&"sign_room": ["sign_room_zbrojownia", "sign_room_diorama", "sign_room_hol", "sign_room_personel"],
	&"doorframe_4x4_5": ["doorframe_4x4_5_stone", "doorframe_4x4_5_paint"],
	&"doorframe_2x2_6": ["doorframe_2x2_6_dark"],
	&"banner": ["banner_lion", "banner_chevron"],
	&"frame_3x2": ["frame_3x2_sea"],
	&"frame_3_5x2_2": ["frame_3_5x2_2_land"],
	&"frame_2_4x1_8": ["frame_2_4x1_8_sea", "frame_2_4x1_8_still"],
	&"frame_1_2x0_9": ["frame_1_2x0_9_land"],
	&"frame_0_6x0_8": ["frame_0_6x0_8_still"],
	&"egypt_column": ["egypt_column_cracked"],
	&"egypt_column_open": ["egypt_column_open_cracked"],
	# Floor I: wayfinding in the wing colours (sign_wing = EGIPT)
	&"sign_wing": ["sign_wing_asyria", "sign_wing_greece", "sign_wing_enlight", "sign_wing_asia",
		"sign_wing_americas"],
	&"sign_wing_portal": ["sign_wing_portal_asyria", "sign_wing_portal_greece", "sign_wing_portal_enlight",
		"sign_wing_portal_asia", "sign_wing_portal_americas"],
	# Floor I, Enlightenment wing: restyled book sets, the motto frieze, the
	# titled portal, the room plaques
	&"lib_bookcase_a_2m": ["lib_bookcase_a_2m_v2"],
	&"lib_bookcase_b_2m": ["lib_bookcase_b_2m_v2"],
	&"lib_bookcase_c_2m": ["lib_bookcase_c_2m_v2"],
	&"lib_cornice_4m": ["lib_cornice_4m_motto"],
	&"lib_portal_4x4_5": ["lib_portal_4x4_5_titled"],
	&"lib_sign": ["lib_sign_natural", "lib_sign_collectors", "lib_sign_clocks", "lib_sign_orrery",
		"lib_sign_librarian"],
	# Floor I, Americas wing: the bark-cloth hanging in two more prints
	&"tapa_hanging": ["tapa_hanging_b", "tapa_hanging_c"],
	# Floor I, Greek wing
	&"gr_frieze_4m": ["gr_frieze_4m_b", "gr_frieze_4m_c", "gr_frieze_4m_d", "gr_frieze_4m_e", "gr_frieze_4m_f"],
	&"gr_frieze_2m": ["gr_frieze_2m_b", "gr_frieze_2m_c"],
	&"gr_bassae_2m": ["gr_bassae_2m_b", "gr_bassae_2m_c"],
	# Floor I, Assyrian wing: relief themes (<prefix><theme>_<module>, see
	# ArtKit "assyria_*" bands)
	&"asy_relief_2m": ["asy_relief_genie_l_2m", "asy_relief_army_2m", "asy_relief_chariot_2m",
		"asy_relief_hunt_2m", "asy_relief_lions_2m", "asy_relief_text_2m", "asy_relief_plain_2m"],
	&"asy_relief_1m": ["asy_relief_genie_l_1m", "asy_relief_army_1m", "asy_relief_chariot_1m",
		"asy_relief_hunt_1m", "asy_relief_lions_1m", "asy_relief_text_1m", "asy_relief_plain_1m"],
	# Floor I, Asia wing: the paper lit from behind (a lamp in the next room)
	&"asia_lattice_window": ["asia_lattice_window_lit"],
	&"asia_shoji_2m": ["asia_shoji_2m_lit"],
}

## Floor I court kit: model id -> [native size (its AABB in metres, Godot
## axes), triangle budget]. Drum pieces (rr_*, court_balcony_seg*) have their
## origin at the drum centre on the floor and are placed by rotation.y =
## k * 22.5 degrees there; court_roof_q at the court centre, four copies at
## 0 / 90 / 180 / 270 degrees; everything else is centre of the base, front
## -Z (scale a piece by size / native size). See
## docs/art/kit-pietro1-dziedziniec.md for the frames and the layout.
const KIT_COURT := {
	&"court_roof_q": [Vector3(60.07, 4.57, 21.34), 11500],
	&"rr_drum_wall": [Vector3(5.29, 21.65, 2.11), 2000],
	&"rr_drum_door": [Vector3(5.29, 21.65, 2.11), 3300],
	&"rr_bookcase": [Vector3(4.46, 9.80, 1.56), 2100],
	&"rr_bookcase_door": [Vector3(4.46, 9.80, 1.65), 2200],
	&"rr_dome_sector": [Vector3(4.46, 10.07, 9.44), 2400],
	&"rr_oculus": [Vector3(6.70, 7.14, 6.70), 2100],
	&"rr_dome_outer": [Vector3(23.40, 2.05, 23.40), 3500],
	&"rr_desk": [Vector3(2.70, 1.67, 4.00), 3200],
	&"rr_catalogue_arc": [Vector3(4.31, 1.20, 1.59), 700],
	&"astrolabe": [Vector3(4.40, 3.61, 4.40), 7000],
	&"steam_banner": [Vector3(2.78, 3.13, 0.60), 500],
	&"steam_podium": [Vector3(1.64, 0.32, 1.64), 1200],
	&"steam_engine": [Vector3(1.37, 2.07, 3.72), 2000],
	&"court_bench": [Vector3(3.00, 0.47, 0.56), 700],
	&"court_info_desk": [Vector3(4.15, 3.34, 4.08), 1300],
	&"cafe_counter": [Vector3(4.06, 2.90, 2.28), 2900],
	&"cafe_table": [Vector3(0.74, 0.75, 0.74), 400],
	&"cafe_chair": [Vector3(0.44, 0.93, 0.44), 600],
	&"shop_front": [Vector3(8.20, 4.66, 0.40), 900],
	&"court_plinth": [Vector3(1.24, 1.00, 1.24), 300],
	&"court_lamp_post": [Vector3(1.58, 4.62, 0.68), 1300],
	&"totem_haida": [Vector3(5.44, 12.57, 2.50), 4800],
	&"sign_wing": [Vector3(1.33, 2.70, 0.40), 500],
	&"sign_wing_portal": [Vector3(3.20, 0.60, 0.06), 100],
	&"court_map_board": [Vector3(1.72, 2.20, 0.72), 600],
	&"court_balcony_seg": [Vector3(6.64, 1.96, 4.42), 700],
	&"court_balcony_seg_open": [Vector3(6.64, 0.86, 4.42), 600],
	&"court_parapet_2m": [Vector3(2.00, 1.10, 0.53), 200],
	&"court_parapet_1m": [Vector3(1.00, 1.10, 0.53), 200],
	&"court_stair_step": [Vector3(3.00, 0.15, 0.43), 50],
	&"court_stair_parapet_4m": [Vector3(0.53, 3.04, 4.02), 200],
	&"court_stair_mass": [Vector3(1.00, 1.00, 1.00), 20],
	&"entrance_column": [Vector3(1.72, 12.00, 1.72), 2400],
	&"entrance_coffer_3m": [Vector3(3.00, 0.48, 3.00), 300],
	&"entrance_door_l": [Vector3(2.20, 5.00, 0.37), 3400],
	&"entrance_door_r": [Vector3(2.20, 5.00, 0.37), 3400],
	&"entrance_door_sign": [Vector3(0.82, 0.42, 0.02), 100],
	&"cloakroom_counter": [Vector3(6.03, 2.65, 3.94), 3100],
	&"entrance_mosaic": [Vector3(8.00, 0.004, 6.00), 10],
	&"grate_leaf_4m": [Vector3(4.00, 5.00, 0.17), 4000],
	&"grate_frame_8m": [Vector3(8.80, 5.55, 0.52), 4000],
}

## Floor I Enlightenment wing kit: model id -> [native size (its AABB in
## metres, Godot axes), triangle budget]. Wall pieces sit on the wall plane
## z = 0 and reach toward -Z, free-standing ones stand on their base centre,
## front -Z; see docs/art/kit-pietro1-oswiecenie.md for every frame, pivot
## and marker, and where each piece goes.
const KIT_ENLIGHTENMENT := {
	&"lib_antlers": [Vector3(0.99, 1.17, 0.36), 900],
	&"lib_automaton_writer": [Vector3(0.72, 1.06, 0.69), 3500],
	&"lib_bird_cage": [Vector3(0.45, 1.66, 0.43), 2000],
	&"lib_bookcase_1m": [Vector3(1.00, 3.60, 0.56), 1400],
	&"lib_bookcase_a_2m": [Vector3(2.00, 3.60, 0.56), 2300],
	&"lib_bookcase_b_2m": [Vector3(2.00, 3.60, 0.56), 2100],
	&"lib_bookcase_c_2m": [Vector3(2.00, 3.60, 0.56), 2400],
	&"lib_bookcase_pilaster_low": [Vector3(0.32, 3.60, 0.60), 600],
	&"lib_bookcase_pilaster_up": [Vector3(0.32, 3.30, 0.55), 600],
	&"lib_bookcase_up_1m": [Vector3(1.00, 3.30, 0.51), 1300],
	&"lib_bookcase_up_a_2m": [Vector3(2.00, 3.30, 0.51), 2200],
	&"lib_bookcase_up_b_2m": [Vector3(2.00, 3.30, 0.51), 2000],
	&"lib_bust_bracket": [Vector3(0.56, 0.62, 0.48), 600],
	&"lib_card_catalogue": [Vector3(1.24, 1.46, 0.71), 2800],
	&"lib_case_coins": [Vector3(1.83, 0.98, 0.83), 3800],
	&"lib_case_instruments": [Vector3(1.83, 0.98, 0.83), 2400],
	&"lib_case_minerals": [Vector3(1.83, 0.99, 0.83), 2900],
	&"lib_case_shells": [Vector3(1.83, 1.06, 0.83), 3200],
	&"lib_clock_longcase": [Vector3(0.58, 2.59, 0.33), 1400],
	&"lib_clock_wall": [Vector3(2.76, 2.19, 0.16), 3800],
	&"lib_coffer_2m": [Vector3(2.20, 0.23, 2.20), 300],
	&"lib_cornice_1m": [Vector3(1.00, 1.20, 0.67), 400],
	&"lib_cornice_2m": [Vector3(2.00, 1.20, 0.67), 700],
	&"lib_cornice_4m": [Vector3(4.00, 1.20, 0.67), 1400],
	&"lib_diorama_base": [Vector3(3.20, 0.62, 1.84), 2300],
	&"lib_doorframe_2x2_8": [Vector3(2.48, 3.45, 0.14), 400],
	&"lib_filing_cabinet": [Vector3(0.52, 1.38, 0.69), 1000],
	&"lib_globe_celestial": [Vector3(1.18, 1.45, 1.18), 3100],
	&"lib_globe_terrestrial": [Vector3(1.18, 1.45, 1.18), 3100],
	&"lib_ladder": [Vector3(0.57, 3.23, 0.95), 1200],
	&"lib_ladder_rail_2m": [Vector3(2.00, 0.09, 0.13), 300],
	&"lib_lamp_pendant": [Vector3(0.48, 1.31, 0.48), 1000],
	&"lib_lamp_reading": [Vector3(0.27, 0.40, 0.21), 500],
	&"lib_lamp_rod_1m": [Vector3(0.04, 1.00, 0.04), 100],
	&"lib_lamp_standard": [Vector3(0.53, 1.63, 0.53), 1100],
	&"lib_lamp_wall": [Vector3(0.28, 0.43, 0.54), 700],
	&"lib_nh_shelf_a": [Vector3(2.06, 2.60, 0.64), 5200],
	&"lib_nh_shelf_b": [Vector3(2.06, 2.60, 0.64), 5200],
	&"lib_office_chair": [Vector3(0.56, 0.81, 0.52), 900],
	&"lib_office_desk": [Vector3(1.70, 1.06, 0.79), 1900],
	&"lib_portal_4x4_5": [Vector3(6.10, 6.62, 0.34), 2700],
	&"lib_railing_1m": [Vector3(1.00, 0.99, 0.12), 1000],
	&"lib_railing_2m": [Vector3(2.00, 0.99, 0.12), 1600],
	&"lib_railing_post": [Vector3(0.20, 1.15, 0.20), 600],
	&"lib_rifle_rack": [Vector3(1.74, 2.39, 0.73), 2100],
	&"lib_sign": [Vector3(1.50, 0.34, 0.06), 200],
	&"lib_skylight_well_4m": [Vector3(4.64, 1.47, 4.64), 1900],
	&"lib_stair_newel": [Vector3(0.26, 1.44, 0.26), 700],
	&"lib_stair_railing_4m": [Vector3(0.08, 2.43, 4.00), 400],
	&"lib_stair_spiral": [Vector3(3.36, 5.29, 3.36), 3600],
	&"lib_stair_step_1m": [Vector3(1.00, 0.15, 0.44), 100],
	&"lib_stair_stringer_4m": [Vector3(0.16, 1.97, 4.00), 100],
	&"lib_walkway_bracket": [Vector3(0.11, 0.76, 0.88), 1000],
	&"lib_walkway_fascia_1m": [Vector3(1.00, 0.42, 0.25), 100],
	&"lib_walkway_fascia_2m": [Vector3(2.00, 0.42, 0.25), 100],
	&"lib_walkway_fascia_4m": [Vector3(4.00, 0.42, 0.25), 100],
	&"lib_walkway_fascia_end": [Vector3(0.25, 0.42, 0.25), 200],
}

## Floor I Americas and Oceania wing kit: model id -> [native size (its AABB
## in metres, Godot axes), triangle budget]. Wall runs sit on the wall plane
## z = 0 and reach toward -Z (dado on the floor, frieze from its face's
## bottom edge, cornice and beams from the ceiling); free-standing pieces
## stand on their base centre, front -Z; temple_stair is in the frame of
## StairsSpec.frame(); see docs/art/kit-pietro1-ameryki.md for every frame,
## pivot and marker, and where each piece goes.
const KIT_AMERICAS := {
	&"americas_dado_4m": [Vector3(4.00, 1.28, 0.17), 100],
	&"americas_dado_2m": [Vector3(2.00, 1.28, 0.17), 100],
	&"americas_dado_1m": [Vector3(1.00, 1.28, 0.17), 100],
	&"americas_dado_05m": [Vector3(0.50, 1.28, 0.17), 100],
	&"americas_frieze_4m": [Vector3(4.00, 1.32, 0.10), 100],
	&"americas_frieze_2m": [Vector3(2.00, 1.32, 0.10), 100],
	&"americas_frieze_1m": [Vector3(1.00, 1.32, 0.10), 100],
	&"americas_frieze_05m": [Vector3(0.50, 1.32, 0.10), 100],
	&"americas_cornice_4m": [Vector3(4.00, 0.90, 0.46), 1600],
	&"americas_cornice_2m": [Vector3(2.00, 0.90, 0.46), 900],
	&"americas_cornice_1m": [Vector3(1.00, 0.90, 0.46), 500],
	&"americas_cornice_05m": [Vector3(0.50, 0.90, 0.46), 300],
	&"pacific_dado_4m": [Vector3(4.00, 1.40, 0.13), 900],
	&"pacific_dado_2m": [Vector3(2.00, 1.40, 0.13), 500],
	&"pacific_dado_1m": [Vector3(1.00, 1.40, 0.13), 300],
	&"pacific_dado_05m": [Vector3(0.50, 1.40, 0.12), 200],
	&"pacific_beam_4m": [Vector3(4.00, 0.45, 0.35), 200],
	&"pacific_beam_2m": [Vector3(2.00, 0.45, 0.35), 200],
	&"pacific_beam_1m": [Vector3(1.00, 0.45, 0.35), 200],
	&"pacific_post": [Vector3(0.72, 4.00, 0.40), 3200],
	&"temple_tier_4m": [Vector3(4.00, 1.50, 0.50), 100],
	&"temple_tier_2m": [Vector3(2.00, 1.50, 0.50), 100],
	&"temple_tier_1m": [Vector3(1.00, 1.50, 0.50), 100],
	&"temple_tier_corner": [Vector3(1.00, 1.50, 1.00), 100],
	&"temple_stair": [Vector3(4.34, 2.16, 4.73), 5000],
	&"temple_shrine": [Vector3(2.40, 2.48, 2.40), 1400],
	&"temple_altar": [Vector3(1.60, 1.24, 1.60), 400],
	&"americas_brazier": [Vector3(0.87, 1.47, 0.91), 1600],
	&"americas_torch_lamp": [Vector3(0.34, 0.52, 0.52), 800],
	&"americas_portal_4m": [Vector3(5.82, 6.22, 0.90), 800],
	&"mask_case": [Vector3(2.42, 1.60, 1.02), 9600],
	&"turquoise_mask": [Vector3(0.26, 0.44, 0.17), 3000],
	&"serpent_mosaic": [Vector3(1.31, 1.76, 0.60), 5200],
	&"sun_stone": [Vector3(3.60, 4.05, 1.10), 2800],
	&"clay_figures": [Vector3(1.60, 1.41, 1.00), 4400],
	&"feather_case": [Vector3(2.22, 1.80, 0.82), 2400],
	&"tapa_hanging": [Vector3(2.40, 3.84, 0.17), 1800],
	&"pacific_figures": [Vector3(1.02, 1.80, 1.02), 4400],
	&"totem_pole_memorial": [Vector3(1.20, 8.71, 1.40), 6000],
	&"totem_pole_house": [Vector3(1.70, 9.05, 1.10), 7500],
	&"totem_pole_welcome": [Vector3(2.39, 4.10, 1.12), 4600],
	&"totem_log": [Vector3(6.00, 1.50, 1.48), 2800],
}
## Floor I props modelled in Blender in place of the art modules' procedural
## solids (tools/art/models/bison.py ...; plan
## docs/superpowers/plans/2026-10-21-modele-blender.md): model id -> [native
## size (its AABB in metres, Godot axes), triangle budget]. Origin = the
## middle of the footprint on the floor, front -Z; the art modules fit each
## into its greybox box (Floor1Art.fit_model).
const KIT_PROPS := {
	&"bison": [Vector3(0.95, 1.79, 2.94), 5000],
	&"asy_chariot": [Vector3(1.74, 1.56, 3.09), 4600],
	&"asy_cage": [Vector3(1.74, 1.73, 1.78), 2000],
	&"kayak": [Vector3(0.62, 0.36, 5.0), 2200],
	&"kayak_stand": [Vector3(1.01, 0.92, 5.4), 1200],
	&"whaleboat": [Vector3(1.77, 1.3, 6.96), 6600],
	&"tipi": [Vector3(4.15, 5.44, 4.02), 1600],
	&"garden_pine": [Vector3(3.59, 4.17, 3.52), 1600],
	&"garden_bamboo": [Vector3(2.37, 6.98, 3.35), 2000],
	&"roof_water_tank": [Vector3(2.92, 3.5, 2.87), 3000],
	&"roof_air_handler": [Vector3(2.36, 1.6, 1.38), 2000],
	&"roof_chimney_tall": [Vector3(1.2, 4.5, 1.2), 800],
	&"roof_chimney_short": [Vector3(1.5, 3.0, 1.5), 1100],
	&"roof_pigeon_loft": [Vector3(4.2, 1.8, 0.58), 1300],
	&"asy_scaffold": [Vector3(1.19, 3.2, 3.96), 2200],
	# (the dome's lantern is stood on the crown under its greybox box, not fitted into it)
	&"rr_dome_lantern": [Vector3(3.6, 2.5, 3.6), 2400],
}
## Extra texture sets of the Enlightenment wing's REGISTRY models (same mesh):
## [code]exhibit(&"flying_book", {"flying_book": "flying_book_green"})[/code];
## scale the node 0.8-1.3 for the size variants.
const ENLIGHTENMENT_SETS := {
	&"flying_book": ["flying_book_green", "flying_book_blue", "flying_book_black"],
}

## Screen material slots and the picture they show until the game gives
## them a viewport texture.
const SCREENS := {
	"cctv_screen": "crt_cctv",
	"terminal_screen": "crt_terminal",
}
## First-person weapons: own field of view (as the greybox viewmodels) and
## squashed depth so they never poke into walls.
const VIEWMODEL_FOV := 55.0
const VIEWMODEL_Z_CLIP := 0.25
## Render layer of first-person models (layer 20, and only it): the
## guard's camera shows them, other cameras (the CCTV) leave them out, and
## a fill light that only reaches this layer keeps the weapon and the hands
## readable in a dark room (see ViewmodelRig; Viewmodels.first_person_layer).
const VIEWMODEL_LAYER := 1 << 19
## Exhibit shaders (see exhibit.gdshaderinc): awake rim, telegraph glow and
## hit flash as per-instance uniforms; wax with subsurface scattering;
## two-sided pieces for debris.
const EXHIBIT_SHADER := preload("res://src/style/exhibit.gdshader")
const EXHIBIT_WAX_SHADER := preload("res://src/style/exhibit_wax.gdshader")
const EXHIBIT_DEBRIS_SHADER := preload("res://src/style/exhibit_debris.gdshader")
## Per texture set: rim strength of the exhibit shader (how much the
## silhouette of an awake exhibit lights up in the dark).
const EXHIBIT_RIM := {
	"wax_figure": 0.4,
	"wolf": 0.5,
	"knight": 0.34,
	"bust_enemy": 0.4,
	"trex": 0.24,
	"raptor": 0.55,
	"portrait": 0.3,
	"colossus": 0.22,
	"mummy": 0.45,
	"scarab": 0.6,
	"scarab_flying": 0.6,
	"planetarium": 0.2,
	"flying_book": 0.5,
	"flying_book_green": 0.5,
	"flying_book_blue": 0.5,
	"flying_book_black": 0.5,
	"totem": 0.35,
	"jaguar": 0.5,
	"serpent": 0.24,
	"hoplite": 0.34,
	"centaur": 0.28,
	"lamassu": 0.24,
	"lamassu_cracked": 0.24,
	"relief_warrior": 0.4,
	"relief_lion": 0.45,
	"fu_dog": 0.4,
	"samurai_ashigaru": 0.34,
	"samurai_general": 0.3,
}
## Pickups use the exhibit shader too, with a rim that starts close by (a
## box of shells in a dark corner): strength per texture set. Ammo and the
## medkit wear the rim in their kind's colour (WeaponPalette: the HUD slot's
## colour, white for health), the fuse and the loose crystal the warm one.
const PICKUP_RIM := {
	"ammo_pistol": 1.0,
	"ammo_shells": 1.0,
	"medkit": 0.9,
	"fuse": 0.9,
	"crystal_loose": 0.5,
	"ammo_rifle": 1.0,
	"ammo_flares": 1.0,
	"ammo_rifle_hunt": 1.0,
	"ammo_harpoon": 1.0,
	"ammo_hwacha": 1.0,
}
const PICKUP_RIM_COLOR := Color(1.0, 0.78, 0.45)
const PICKUP_RIM_FADE := Vector2(0.8, 4.0)
## Read from afar (the light pass of 19.10; visual QA e1: at 15 m in the
## shade or a dark room only coloured dots, the medkit lost among them):
## from PICKUP_FAR_FADE.x on (full at .y) the rim grows by PICKUP_FAR_RIM,
## the body takes on a faint glow of the kind's colour (PICKUP_FAR_BODY),
## and the medkit's red cross (its emission map) brightens by
## PICKUP_FAR_EMIT; nearer nothing changes.
const PICKUP_FAR_FADE := Vector2(9.0, 15.0)
const PICKUP_FAR_RIM := 2.2
const PICKUP_FAR_BODY := 0.16
const PICKUP_FAR_EMIT := {"medkit": 3.0}
## Pickup texture set -> the ammo it holds (its rim and accent colour).
const PICKUP_AMMO := {"ammo_pistol": &"bullets", "ammo_shells": &"shells", "ammo_rifle": &"rifle",
		"ammo_flares": &"flares", "ammo_rifle_hunt": &"hunt_rounds", "ammo_harpoon": &"harpoons",
		"ammo_hwacha": &"rockets", "medkit": &"medkit"}


## The rim colour of pickup texture set [param tex_name]: its ammo's
## (WeaponPalette), the medkit's white, else the warm one.
static func pickup_rim_color(tex_name: String) -> Color:
	if PICKUP_AMMO.has(tex_name):
		return WeaponPalette.ammo_color(PICKUP_AMMO[tex_name])
	return PICKUP_RIM_COLOR


## The colour-vision palette changed (Settings, "colour_vision"): the rims
## of the pickup materials made so far (whole and broken) take their kind's
## colour of the new palette, on every pickup already in the world. The
## baked prints keep their colours.
static func refresh_pickup_rims() -> void:
	for tex_name: String in PICKUP_AMMO:
		for key in ["exhibit:%s" % tex_name, "exhibit_debris:%s" % tex_name]:
			var mat := _materials.get(key) as ShaderMaterial
			if mat != null:
				mat.set_shader_parameter(&"rim_color", pickup_rim_color(tex_name))

## False = every caller falls back to its greybox (a missing model does
## the same). Used to compare frame rates with the greybox.
static var models_enabled: bool = true

static var _materials: Dictionary = {}
static var _scenes: Dictionary = {}
## Texture sets made in code (greybox bodies waiting for their Blender
## model): set name -> channel -> Texture2D. See [method register_generated].
static var _generated: Dictionary = {}


## Instances a registered model by id (see [constant REGISTRY]), dressed.
## Viewmodels (ids starting with "vm_") get viewmodel materials and cast no
## shadows.
static func instance(id: StringName, swap: Dictionary = {}) -> Node3D:
	var root := model(String(id), swap)
	if String(id).begins_with("vm_"):
		_make_viewmodel(root)
	return root


## [method instance], or null when models are off or the file is missing
## (callers keep their greybox then).
static func try_instance(id: StringName) -> Node3D:
	if not has_model(id):
		return null
	return instance(id)


## True when model [param id] can be instanced.
static func has_model(id: StringName) -> bool:
	if not models_enabled:
		return false
	if _scenes.get(String(id)) != null:
		return true
	return ResourceLoader.exists(MODEL_PATH % id)


## An enemy model (wolf, knight, wax_figure, bust_enemy, trex, raptor,
## portrait) dressed with the exhibit shader, or null (greybox). Drive it
## with GeometryInstance3D.set_instance_shader_parameter(): &"awake",
## &"glow", &"flash" (0..1). [param swap] renames materials as in
## [method model] (a portrait's canvas).
static func exhibit(id: StringName, swap: Dictionary = {}) -> Node3D:
	if not has_model(id):
		return null
	# dressed straight with the exhibit materials (the baked ORM set of the
	# same name is never needed); the two-sided debris variant is made now
	# too, so it exists (and is warmed up, Fx.warm_up) before the first
	# exhibit breaks
	var root := _instantiate(String(id))
	for child in root.find_children("*", "MeshInstance3D", true, false):
		var view := child as MeshInstance3D
		for i in view.mesh.get_surface_count():
			var tex_name := _surface_name(view.mesh, i, swap)
			view.set_surface_override_material(i, exhibit_material(tex_name))
			exhibit_material(tex_name, true)
	return root


## The exhibit shader material of texture set [param tex_name]; with
## [param debris] the two-sided variant for broken pieces.
static func exhibit_material(tex_name: String, debris: bool = false) -> ShaderMaterial:
	var key := "exhibit%s:%s" % ["_debris" if debris else "", tex_name]
	if _materials.has(key):
		return _materials[key]
	var mat := ShaderMaterial.new()
	mat.resource_name = tex_name
	var sss := texture(tex_name, "sss")
	if debris:
		mat.shader = EXHIBIT_DEBRIS_SHADER
	elif sss != null:
		mat.shader = EXHIBIT_WAX_SHADER
		mat.set_shader_parameter(&"sss_tex", sss)
		mat.set_shader_parameter(&"sss_strength", EXTRAS.get(tex_name, {}).get("sss", 0.3))
	else:
		mat.shader = EXHIBIT_SHADER
	mat.set_shader_parameter(&"albedo_tex", texture(tex_name, "albedo"))
	mat.set_shader_parameter(&"orm_tex", texture(tex_name, "orm"))
	var normal := texture(tex_name, "normal")
	mat.set_shader_parameter(&"normal_tex", normal)
	mat.set_shader_parameter(&"normal_scale", 1.0 if normal != null else 0.0)
	var emit := texture(tex_name, "emit")
	if emit != null:
		mat.set_shader_parameter(&"emit_tex", emit)
	mat.set_shader_parameter(&"emit_energy", EXTRAS.get(tex_name, {}).get("emission", 2.0))
	mat.set_shader_parameter(&"rim_strength", EXHIBIT_RIM.get(tex_name, 0.3))
	if PICKUP_RIM.has(tex_name):
		mat.set_shader_parameter(&"rim_strength", PICKUP_RIM[tex_name])
		mat.set_shader_parameter(&"rim_color", pickup_rim_color(tex_name))
		mat.set_shader_parameter(&"rim_fade", PICKUP_RIM_FADE)
		mat.set_shader_parameter(&"far_fade", PICKUP_FAR_FADE)
		mat.set_shader_parameter(&"far_rim", PICKUP_FAR_RIM)
		mat.set_shader_parameter(&"far_body", PICKUP_FAR_BODY)
		mat.set_shader_parameter(&"far_emit", float(PICKUP_FAR_EMIT.get(tex_name, 0.0)))
	_materials[key] = mat
	return mat


## A pickup model (ammo_*, medkit, fuse, crystal_loose) with a rim light in
## its kind's colour that makes it easy to spot in the dark, or null.
static func pickup(id: StringName) -> Node3D:
	var root := exhibit(id)
	if root == null:
		return null
	for child in root.find_children("*", "GeometryInstance3D", true, false):
		(child as GeometryInstance3D).set_instance_shader_parameter(&"awake", 1.0)
	return root


## The material a broken piece of a mesh with [param source] shows: the
## two-sided exhibit variant, or the source itself for other materials.
static func debris_material(source: Material) -> Material:
	var shader_mat := source as ShaderMaterial
	if shader_mat != null and shader_mat.shader in [EXHIBIT_SHADER, EXHIBIT_WAX_SHADER]:
		return exhibit_material(source.resource_name, true)
	return source


## Every named node under [param root] (meshes and markers), by name.
static func parts(root: Node) -> Dictionary:
	var out := {}
	for child in root.find_children("*", "Node3D", true, false):
		out[String(child.name)] = child
	return out


## Gives [param node]'s meshes their own copies of their materials and
## returns them, so one enemy can glow (attack telegraph, visor, cracks)
## without lighting up every other instance that shares the texture set.
static func own_materials(node: Node) -> Array[BaseMaterial3D]:
	var out: Array[BaseMaterial3D] = []
	var copies := {}
	for child in node.find_children("*", "MeshInstance3D", true, false):
		var view := child as MeshInstance3D
		for i in view.mesh.get_surface_count():
			var mat := view.get_surface_override_material(i) as BaseMaterial3D
			if mat == null:
				continue
			if not copies.has(mat):
				var copy := mat.duplicate() as BaseMaterial3D
				copies[mat] = copy
				out.append(copy)
			view.set_surface_override_material(i, copies[mat] as BaseMaterial3D)
	return out


## Unshaded, additive billboard for a sprite sheet of [param frames] frames
## side by side (the dust mote: "dust_mote", 4 frames). Use it on
## particles with particles_anim_h_frames = [param frames].
static func billboard(sprite: String, frames: int = 1) -> StandardMaterial3D:
	var key := "billboard:%s" % sprite
	if _materials.has(key):
		return _materials[key]
	var mat := StandardMaterial3D.new()
	mat.resource_name = sprite
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.particles_anim_h_frames = frames
	mat.particles_anim_v_frames = 1
	mat.particles_anim_loop = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.albedo_texture = load("res://assets/textures/%s.png" % sprite) as Texture2D
	mat.vertex_color_use_as_albedo = true
	_materials[key] = mat
	return mat


## Instances a model with its materials. [param swap] renames materials,
## e.g. {"bust": "bust_bronze"} to use another baked texture set.
static func model(model_name: String, swap: Dictionary = {}) -> Node3D:
	var root := _instantiate(model_name)
	dress(root, swap)
	return root


## Every material made so far (baked sets, exhibit shaders and their
## debris variants, viewmodel copies...), for the shader warm-up.
static func cached_materials() -> Array[Material]:
	var out: Array[Material] = []
	for mat: Variant in _materials.values():
		if mat is Material:
			out.append(mat as Material)
	return out


## The model's scene instanced as it was imported (no materials set).
static func _instantiate(model_name: String) -> Node3D:
	var scene: PackedScene = _scenes.get(model_name)
	if scene == null:
		scene = load(MODEL_PATH % model_name) as PackedScene
		_scenes[model_name] = scene
	return scene.instantiate() as Node3D


## The material name of surface [param surface] of [param mesh] (the
## texture set), renamed by [param swap].
static func _surface_name(mesh: Mesh, surface: int, swap: Dictionary) -> String:
	var source := mesh.surface_get_material(surface)
	var mat_name: String = source.resource_name if source != null else ""
	return swap.get(mat_name, mat_name)


## Replaces every imported material under [param node] by the library one of
## the same name.
static func dress(node: Node, swap: Dictionary = {}) -> void:
	var meshes: Array[Node] = node.find_children("*", "MeshInstance3D", true, false)
	if node is MeshInstance3D:
		meshes.append(node)
	for child in meshes:
		var view := child as MeshInstance3D
		var only_glass := true
		for i in view.mesh.get_surface_count():
			var mat_name := _surface_name(view.mesh, i, swap)
			view.set_surface_override_material(i, material(mat_name))
			only_glass = only_glass and mat_name == "glass"
		if only_glass:
			# panes let light (moon shafts, lamps) through
			view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## The shared material for a baked texture set (or "glass").
static func material(mat_name: String) -> Material:
	if _materials.has(mat_name):
		return _materials[mat_name]
	var mat: Material
	if mat_name.begins_with(TILE_PREFIX):
		return arch_tile(mat_name.substr(TILE_PREFIX.length()))
	if mat_name.begins_with(TILE_LOCAL_PREFIX):
		return arch_tile(mat_name.substr(TILE_LOCAL_PREFIX.length()), true)
	if mat_name == "glass":
		mat = _glass()
	elif _screen_picture(mat_name) != "":
		mat = _screen(mat_name, _screen_picture(mat_name))
	else:
		mat = _baked(mat_name)
	_materials[mat_name] = mat
	return mat


## A tileable texture set mapped in world space: [param size] is how many
## metres one texture repeat covers (keeps texel density exact on any box).
static func tiled(tex_name: String, size: Vector2) -> ORMMaterial3D:
	var key := "%s@%s" % [tex_name, size]
	if _materials.has(key):
		return _materials[key]
	var mat := _baked(tex_name)
	mat.uv1_triplanar = true
	mat.uv1_world_triplanar = true
	mat.uv1_triplanar_sharpness = 40.0
	mat.uv1_scale = Vector3(1.0 / size.x, 1.0 / size.y, 1.0 / size.x)
	_materials[key] = mat
	return mat


## A lobby-kit field material: tile texture set [param tex_name] (64 px/m,
## e.g. "limestone_rustic", "marble_hall", "wallpaper") mapped by position,
## world space by default or the object's own space with [param local].
## [param tint] multiplies the albedo (a room variant of a shared texture),
## [param offset] shifts the pattern (metres; e.g. Vector3(1, 0, 1) puts a
## 2 m checker square on the room centre). Shared per argument set.
static func arch_tile(tex_name: String, local: bool = false, tint: Color = Color.WHITE, offset: Vector3 = Vector3.ZERO) -> ShaderMaterial:
	var key := "arch:%s:%s:%s:%s" % [tex_name, local, tint.to_html(), offset]
	if _materials.has(key):
		return _materials[key]
	var mat := ShaderMaterial.new()
	mat.resource_name = tex_name
	mat.shader = ARCH_TILE_SHADER
	mat.set_shader_parameter(&"albedo_tex", texture(tex_name, "albedo"))
	mat.set_shader_parameter(&"normal_tex", texture(tex_name, "normal"))
	mat.set_shader_parameter(&"orm_tex", texture(tex_name, "orm"))
	mat.set_shader_parameter(&"local_space", local)
	mat.set_shader_parameter(&"tint", tint)
	mat.set_shader_parameter(&"tile_offset", offset)
	_materials[key] = mat
	return mat


## Registers a texture set made in code ([param channels]: "albedo", "orm",
## "emit"... -> Texture2D) under [param tex_name]: texture() and
## exhibit_material() (and its debris variant) then use it like a baked set.
static func register_generated(tex_name: String, channels: Dictionary) -> void:
	_generated[tex_name] = channels


static func texture(tex_name: String, channel: String) -> Texture2D:
	if _generated.has(tex_name):
		return (_generated[tex_name] as Dictionary).get(channel) as Texture2D
	var path := TEXTURE_PATH % [tex_name, channel]
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D


static func _baked(tex_name: String) -> ORMMaterial3D:
	var mat := ORMMaterial3D.new()
	mat.resource_name = tex_name
	mat.texture_filter = FILTER
	mat.albedo_texture = texture(tex_name, "albedo")
	mat.orm_texture = texture(tex_name, "orm")
	var normal := texture(tex_name, "normal")
	if normal != null:
		mat.normal_enabled = true
		mat.normal_texture = normal
		mat.normal_scale = 1.0
	var extras: Dictionary = EXTRAS.get(tex_name, {})
	var emit := texture(tex_name, "emit")
	if emit != null:
		mat.emission_enabled = true
		mat.emission_texture = emit
		mat.emission = Color.BLACK
		mat.emission_energy_multiplier = extras.get("emission", 2.0)
	if extras.has("alpha_scissor"):
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		mat.alpha_scissor_threshold = extras["alpha_scissor"]
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var sss := texture(tex_name, "sss")
	if sss != null:
		mat.subsurf_scatter_enabled = true
		mat.subsurf_scatter_strength = extras.get("sss", 0.3)
		mat.subsurf_scatter_skin_mode = true
		mat.subsurf_scatter_texture = sss
	return mat


static func _glass() -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.resource_name = "glass"
	mat.shader = GLASS_SHADER
	mat.set_shader_parameter(&"albedo_tex", texture("glass", "albedo"))
	mat.set_shader_parameter(&"orm_tex", texture("glass", "orm"))
	mat.render_priority = 1
	return mat


static func _screen_picture(mat_name: String) -> String:
	for prefix in SCREENS:
		if mat_name.begins_with(prefix):
			return SCREENS[prefix]
	return ""


## A CRT screen: glossy, self-lit picture. Each screen slot has its own
## material, so the game can swap one screen's texture for a viewport.
static func _screen(mat_name: String, picture: String) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.resource_name = mat_name
	mat.texture_filter = FILTER
	mat.albedo_texture = texture(picture, "albedo")
	mat.roughness = 0.12
	mat.emission_enabled = true
	mat.emission_texture = texture(picture, "emit")
	mat.emission = Color.BLACK
	mat.emission_energy_multiplier = 1.6
	return mat


static func _make_viewmodel(root: Node3D) -> void:
	for child in root.find_children("*", "MeshInstance3D", true, false):
		var view := child as MeshInstance3D
		view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		view.layers = VIEWMODEL_LAYER
		for i in view.mesh.get_surface_count():
			var source := view.get_surface_override_material(i) as BaseMaterial3D
			if source == null:
				continue
			var key := "viewmodel:%s" % source.resource_name
			var mat: BaseMaterial3D = _materials.get(key)
			if mat == null:
				mat = source.duplicate() as BaseMaterial3D
				mat.use_fov_override = true
				mat.fov_override = VIEWMODEL_FOV
				mat.use_z_clip_scale = true
				mat.z_clip_scale = VIEWMODEL_Z_CLIP
				_materials[key] = mat
			view.set_surface_override_material(i, mat)
