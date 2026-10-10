class_name ArtKit
## The lobby's modular architecture kit: which Blender model (or tile
## material) dresses each greybox piece, per room, and how it is fitted.
## Pure placement logic on top of ArtLibrary; nothing here touches the
## level code. The level (or a kit-swap pass) asks:
##
## - [method field] - the tile material of a shell box face by room and
##   role (wall, wall_upper, floor, ceiling, reveal, threshold, stair, slab),
##   mapped by world position, so boxes of any size just work;
## - [method dress_wall] - the horizontal bands, pilasters and fittings of
##   one wall face (from a face record, see below);
## - [method dress_ceiling], [method dress_floor] - coffers / beams, floor
##   borders and the medallion for a room's ceiling and floor boxes;
## - [method piece] - the model(s) replacing a LevelKit piece (kit id, size,
##   room), in LevelKit's own frame (origin = centre of the base, -Z = front);
## - [method stairs], [method passage], [method leaf], [method fixture] - the
##   grand stairs, door frames and reveals, door leaves and light fittings.
##
## Every result is a plain Node3D tree of ArtLibrary models: add it where the
## greybox "Visual" goes. See docs/art/styl-przewodnik.html, "Zestaw
## modułowy holu", for the tables, pivots and fitting rules.

## Module lengths of the wall runs, longest first.
const RUN := [4.0, 2.0, 1.0, 0.5]
## Suffix of a run module of each length.
const RUN_TAG := {4.0: "4m", 2.0: "2m", 1.0: "1m", 0.5: "05m"}
## Run prefix -> the lengths that exist.
const RUN_SIZES := {
	"hall_plinth_": [4.0, 2.0, 1.0, 0.5], "hall_upper_base_": [4.0, 2.0, 1.0, 0.5],
	"hall_string_": [4.0, 2.0, 1.0, 0.5], "hall_cornice_": [4.0, 2.0, 1.0, 0.5],
	"gallery_base_": [4.0, 2.0, 1.0, 0.5], "gallery_top_": [4.0, 2.0, 1.0, 0.5],
	"skirting_": [4.0, 2.0, 1.0, 0.5], "diorama_base_": [4.0, 2.0, 1.0, 0.5],
	"armory_top_": [4.0, 2.0, 1.0], "diorama_top_": [4.0, 2.0, 1.0], "security_rail_": [4.0, 2.0, 1.0],
	"corridor_pipes_": [4.0, 2.0, 1.0], "balcony_fascia_": [4.0, 2.0, 1.0], "balustrade_": [2.0, 1.0],
	"floor_border_": [4.0, 2.0, 1.0, 0.5],
	# Floor I, Egypt wing
	"egypt_dado_": [4.0, 2.0, 1.0, 0.5], "egypt_frieze_": [4.0, 2.0, 1.0, 0.5], "egypt_cornice_": [4.0, 2.0, 1.0, 0.5],
	"egypt_beam_": [4.0, 2.0, 1.0],
	# Floor I court: the balcony landings' parapets
	"court_parapet_": [2.0, 1.0],
	# Floor I, Enlightenment wing: the library's ceiling cornice, the gallery's fascia
	"lib_cornice_": [4.0, 2.0, 1.0], "lib_walkway_fascia_": [4.0, 2.0, 1.0], "lib_railing_": [2.0, 1.0],
	# Floor I, Americas and Oceania wing
	"americas_dado_": [4.0, 2.0, 1.0, 0.5], "americas_frieze_": [4.0, 2.0, 1.0, 0.5],
	"americas_cornice_": [4.0, 2.0, 1.0, 0.5], "pacific_dado_": [4.0, 2.0, 1.0, 0.5],
	# Floor I, Greek wing (docs/art/kit-pietro1-grecja.md)
	"gr_base_": [4.0, 2.0, 1.0, 0.5], "gr_frieze_": [4.0, 2.0, 1.0, 0.5], "gr_cornice_": [4.0, 2.0, 1.0, 0.5],
	"gr_cornice_doric_": [4.0, 2.0, 1.0], "gr_bassae_": [2.0, 1.0], "gr_floor_border_": [4.0, 2.0, 1.0, 0.5],
	# Floor I, Assyrian wing: relief slabs (2 and 1 m), the painted frieze over them
	"asy_relief_": [2.0, 1.0], "asy_frieze_": [4.0, 2.0, 1.0],
	# Floor I, Asia wing
	"asia_dado_": [4.0, 2.0, 1.0, 0.5], "asia_frieze_": [4.0, 2.0, 1.0, 0.5], "asia_eaves_": [4.0, 2.0, 1.0],
	"asia_wallcap_": [4.0, 2.0, 1.0],
}
## Vertical extent of a band relative to its datum (its origin), for
## deciding which openings cut it.
const BAND_SPAN := {
	"hall_plinth_": Vector2(0.0, 1.0), "hall_upper_base_": Vector2(0.0, 0.35),
	"hall_string_": Vector2(-0.45, 0.0), "hall_cornice_": Vector2(-1.5, 0.0),
	"gallery_base_": Vector2(0.0, 1.21), "gallery_top_": Vector2(-0.94, 0.0),
	"armory_top_": Vector2(-0.32, 0.0), "diorama_base_": Vector2(0.0, 0.45),
	"diorama_top_": Vector2(-0.7, 0.0), "skirting_": Vector2(0.0, 0.15),
	"security_rail_": Vector2(-0.05, 0.05), "corridor_pipes_": Vector2(-0.5, 0.0),
	"egypt_dado_": Vector2(0.0, 1.2), "egypt_frieze_": Vector2(-0.07, 1.07), "egypt_cornice_": Vector2(-1.0, 0.0),
	"lib_cornice_": Vector2(-1.2, 0.0),
	"americas_dado_": Vector2(0.0, 1.28), "americas_frieze_": Vector2(-0.16, 1.16),
	"americas_cornice_": Vector2(-0.9, 0.0), "pacific_dado_": Vector2(0.0, 1.4),
	# Floor I, Greek wing
	"gr_base_": Vector2(0.0, 0.6), "gr_frieze_": Vector2(0.0, 1.19), "gr_cornice_": Vector2(-1.2, 0.0),
	"gr_cornice_doric_": Vector2(-1.6, 0.0), "gr_bassae_": Vector2(0.0, 0.78),
	"asy_relief_": Vector2(0.0, 3.0), "asy_frieze_": Vector2(0.0, 0.62),
	"asia_dado_": Vector2(0.0, 1.1), "asia_frieze_": Vector2(-0.07, 1.07), "asia_eaves_": Vector2(-1.05, 0.0),
	"asia_wallcap_": Vector2(0.0, 0.55),
}
## Runs whose modules take their texture sets (ArtLibrary.KIT_SETS) in turn
## by position, so a long frieze does not repeat one slab (Greek wing).
const VARIED_RUNS := {"gr_frieze_": true, "gr_bassae_": true}
## A remainder shorter than this is absorbed by stretching the last module.
const MIN_MODULE := 0.5
## Stretching a module more than this (either way) is not allowed; a run
## that would need more gets an extra module instead.
const MAX_STRETCH := 0.25

## Room styles. Fields are tile textures (64 px/m) for ArtLibrary.arch_tile;
## "bands" are wall runs: prefix, datum ("floor", "ceiling" or a height in
## metres above the room floor; "top": the datum is the band's top edge) and
## an optional texture-set prefix ("set"). "only" limits a band to the
## face's "balcony" spans, "soffit" lowers its datum under a slab,
## "middle_set" gives the 4 m module nearest the middle of a long wall
## (20 m and more) that texture set (the library's motto).
## Other keys: "stair_rails" (balustrades on a flight that stands free
## outside a hall), "fascia" / "fascia_end" (the run along a balcony slab's
## free edges and its end cap; default the hall's), "stairs_kit" (a flight
## of the floor's own kit: Floor1Art.court_stairs, the library's).
const ROOMS := {
	&"hall": {
		"wall": "limestone_rustic", "wall_upper": "limestone_ashlar", "upper_from": 6.0,
		"well": "plaster", "well_from": 14.0, "well_tint": Color(0.34, 0.36, 0.42),
		"floor": "marble_hall", "floor_offset": Vector3(1.0, 0.0, 1.0), "ceiling": "plaster",
		"reveal": "limestone", "threshold": "limestone", "stair": "limestone_ashlar", "slab": "limestone",
		"coffer": "hall_coffer_2m",
		"bands": [
			{"prefix": "hall_plinth_", "at": "floor"},
			{"prefix": "hall_string_", "at": 6.0, "top": true, "soffit": true},
			{"prefix": "hall_upper_base_", "at": 6.0, "only": "balcony"},
			{"prefix": "hall_cornice_", "at": "ceiling"},
		],
		"pilasters": {"every": 5.5, "from": 6.0, "to": 12.5, "min_height": 12.0},
		"border": "floor_border_", "medallion": "floor_medallion",
		"frame_4": "hall_arch_4m", "reveal_4": "hall_door_reveal_4m",
		"sign": "sign_room_hol",
	},
	&"balcony": {"same_as": &"hall"},
	&"gallery": {
		"wall": "wallpaper", "floor": "marble_floor", "ceiling": "plaster", "reveal": "plaster",
		"threshold": "marble_dark", "coffer_legacy": "ceiling_2m",
		"bands": [{"prefix": "gallery_base_", "at": "floor"}, {"prefix": "gallery_top_", "at": "ceiling"}],
		"frame_4": "doorframe_4x4_5", "frame_2_8": "doorframe_2x2_8", "sign": "sign_room",
	},
	&"armory": {
		"wall": "stone_rubble", "floor": "flagstone", "ceiling": "plaster", "reveal": "stone_rubble",
		"threshold": "flagstone", "beams": "timber_beam_4m", "corbel": "timber_corbel",
		"bands": [{"prefix": "hall_plinth_", "at": "floor", "set": "armory_plinth_"},
			{"prefix": "armory_top_", "at": "ceiling"}],
		"frame_4": "doorframe_4x4_5", "frame_4_set": "doorframe_4x4_5_stone", "frame_2_8": "doorframe_2x2_8",
		"sign": "sign_room_zbrojownia",
	},
	&"diorama": {
		"wall": "backdrop", "floor": "terrazzo", "ceiling": "plaster", "ceiling_tint": Color(0.36, 0.42, 0.52),
		"reveal": "plaster", "threshold": "terrazzo", "grass": "grass_fake",
		"bands": [{"prefix": "diorama_base_", "at": "floor"}, {"prefix": "diorama_top_", "at": "ceiling"}],
		"frame_4": "doorframe_4x4_5", "frame_4_set": "doorframe_4x4_5_paint", "frame_2_8": "doorframe_2x2_8",
		"frame_2_6": "doorframe_2x2_6", "frame_2_6_set": "doorframe_2x2_6_dark", "sign": "sign_room_diorama",
	},
	&"corridor_w": {
		"wall": "plaster", "floor": "concrete", "ceiling": "plaster", "reveal": "plaster", "threshold": "concrete",
		"bands": [{"prefix": "skirting_", "at": "floor"}, {"prefix": "corridor_pipes_", "at": "ceiling"}],
		"frame_2_8": "doorframe_2x2_8",
	},
	&"corridor_e": {"same_as": &"corridor_w"},
	&"staff_corridor": {
		"wall": "paint_wall", "floor": "linoleum", "ceiling": "ceiling_tiles", "reveal": "paint_wall",
		"threshold": "linoleum",
		"bands": [{"prefix": "skirting_", "at": "floor", "set": "skirting_black_"},
			{"prefix": "security_rail_", "at": 1.2}],
		"frame_2_6": "doorframe_2x2_6",
	},
	&"security": {"same_as": &"staff_corridor"},
	&"closet": {
		"wall": "brick", "floor": "boards", "ceiling": "plaster", "reveal": "brick", "threshold": "boards",
		"bands": [{"prefix": "skirting_", "at": "floor", "set": "skirting_pine_"}],
	},
	&"secret_chamber": {"wall": "brick", "floor": "boards", "ceiling": "brick", "reveal": "brick", "threshold": "boards", "bands": []},
	&"shotgun_niche": {"same_as": &"secret_chamber"},
	&"vent": {"wall": "brick", "floor": "concrete", "ceiling": "brick", "reveal": "brick", "threshold": "concrete", "bands": []},
	&"undercroft": {"wall": "stone_rubble", "floor": "flagstone", "ceiling": "stone_rubble", "wall_tint": Color(0.6, 0.6, 0.62),
		"reveal": "stone_rubble", "threshold": "flagstone", "bands": []},
	# Floor I, Egypt wing (docs/art/kit-pietro1-egipt.md): sandstone ashlar over
	# a red granite dado, the hieroglyph frieze (its face bottom on a whole
	# metre: the tile is one band per metre), the cavetto cornice under a
	# starry ceiling, a polished granite floor. Painted beams (egypt_beam_4m)
	# are placed by the level across the gallery every 4 m.
	&"egypt_gallery": {
		"wall": "sandstone_ashlar", "floor": "granite_floor", "ceiling": "star_ceiling", "reveal": "sandstone",
		"threshold": "granite_red",
		"bands": [{"prefix": "egypt_dado_", "at": "floor"}, {"prefix": "egypt_frieze_", "at": 7.0},
			{"prefix": "egypt_cornice_", "at": "ceiling"}],
		"frame_4": "egypt_portal_4m", "frame_2_8": "egypt_doorframe_2x2_8",
	},
	&"egypt_vestibule": {"same_as": &"egypt_gallery"},
	&"egypt_colossus_hall": {
		"wall": "sandstone_ashlar", "floor": "granite_floor", "ceiling": "star_ceiling", "reveal": "sandstone",
		"threshold": "granite_red",
		"bands": [{"prefix": "egypt_dado_", "at": "floor"}, {"prefix": "egypt_frieze_", "at": 10.0},
			{"prefix": "egypt_cornice_", "at": "ceiling"}],
		"frame_4": "egypt_portal_4m", "frame_2_8": "egypt_doorframe_2x2_8",
	},
	&"egypt_tomb": {
		"wall": "tomb_wall", "floor": "granite_floor", "ceiling": "star_ceiling", "reveal": "sandstone",
		"threshold": "sandstone", "bands": [{"prefix": "egypt_cornice_", "at": "ceiling"}],
		"frame_2_8": "egypt_doorframe_2x2_8",
	},
	# Floor I: the Great Court (Portland ashlar, pale limestone slabs), the
	# Reading Room (its wall is the bookcases: carpet and plain fields) and
	# the entrance hall (the lobby hall's stone, 3 m Greek key coffers)
	# (stage P2: the cornice crowns the walls under the glass roof's edge
	# girder, 17.85 m, not under the slab over the glass; pilasters carry
	# the upper storey; the stairs are the court's own limestone kit)
	&"court": {
		"wall": "portland_ashlar", "floor": "limestone_court", "ceiling": "plaster", "reveal": "limestone",
		"threshold": "limestone", "stair": "portland_ashlar", "slab": "limestone_court",
		"ceiling_tint": Color(0.3, 0.32, 0.38),
		"bands": [
			{"prefix": "hall_plinth_", "at": "floor"},
			{"prefix": "hall_string_", "at": 7.0, "top": true},
			{"prefix": "hall_cornice_", "at": 17.85},
		],
		"pilasters": {"every": 6.0, "from": 7.0, "to": 16.35, "min_height": 18.0},
		"frame_4": "hall_arch_4m", "reveal_4": "hall_door_reveal_4m", "stairs_kit": "court",
	},
	&"reading_room": {"wall": "plaster", "floor": "carpet_reading", "ceiling": "plaster", "reveal": "plaster",
		"threshold": "marble_dark", "bands": []},
	&"entrance": {
		"wall": "limestone_rustic", "wall_upper": "limestone_ashlar", "upper_from": 6.0,
		"floor": "marble_hall", "floor_offset": Vector3(1.0, 0.0, 1.0), "ceiling": "plaster",
		"reveal": "limestone", "threshold": "limestone", "stair": "limestone_ashlar", "slab": "limestone",
		"coffer": "entrance_coffer_3m", "coffer_size": 3.0,
		"bands": [
			{"prefix": "hall_plinth_", "at": "floor"},
			{"prefix": "hall_string_", "at": 6.0, "top": true, "soffit": true},
			{"prefix": "hall_cornice_", "at": "ceiling"},
		],
		"frame_4": "hall_arch_4m", "reveal_4": "hall_door_reveal_4m",
	},
	# Floor I hub, stage P2: the north corridor (the lobby hall's stone in a
	# 10 m gallery: rustication below 5 m, pilasters from the layout, 2 m
	# coffers), the crypt under it (rubble, flagstones), the conservator's
	# workroom in the tombs (lime plaster over pine skirting, boards: a
	# haven that feels lived in), the cloakroom (painted panelling)
	&"north_hall": {
		"wall": "limestone_rustic", "wall_upper": "limestone_ashlar", "upper_from": 5.0,
		"floor": "marble_floor", "ceiling": "plaster", "reveal": "limestone", "threshold": "marble_dark",
		"stair": "limestone_ashlar", "slab": "limestone", "coffer": "hall_coffer_2m",
		"bands": [
			{"prefix": "hall_plinth_", "at": "floor"},
			{"prefix": "hall_string_", "at": 5.0, "top": true},
			{"prefix": "hall_cornice_", "at": "ceiling"},
		],
		"frame_4": "hall_arch_4m", "reveal_4": "hall_door_reveal_4m", "frame_2_8": "doorframe_2x2_8",
	},
	&"crypt": {"wall": "stone_rubble", "floor": "flagstone", "ceiling": "stone_rubble", "wall_tint": Color(0.55, 0.55, 0.58),
		"reveal": "stone_rubble", "threshold": "flagstone", "stair": "stone_rubble", "slab": "flagstone", "bands": []},
	&"egypt_conservator": {
		"wall": "plaster", "floor": "boards", "ceiling": "plaster", "wall_tint": Color(0.92, 0.86, 0.74),
		"reveal": "plaster", "threshold": "boards",
		"bands": [{"prefix": "skirting_", "at": "floor", "set": "skirting_pine_"}],
		"frame_2_6": "doorframe_2x2_6",
	},
	&"cloakroom": {
		"wall": "paint_wall", "floor": "linoleum", "ceiling": "ceiling_tiles", "reveal": "paint_wall",
		"threshold": "marble_dark",
		"bands": [{"prefix": "skirting_", "at": "floor", "set": "skirting_black_"}],
		"frame_2_6": "doorframe_2x2_6",
	},
	# Floor I, the basement (stage P3, docs/superpowers/plans/2026-10-03-p3-
	# oprawa-podziemia.md): the service level. Corridors are painted plaster:
	# a dado in the colour of the wing the corridor leads to ("dado_tint" paints
	# the lower layer of the wall split at "upper_from"), pale plaster above, bare
	# concrete under foot and overhead, a bundle of pipes under the ceiling. The
	# boiler room: soot-black brick over flagstones; the cross under the Reading
	# Room: the foundations' rusticated stone; the workshop: warm plaster and
	# boards (the haven); the stores: grey-ochre paint; the secrets: bare
	# concrete, whitewash. Each has "ceiling_skin" and "wall_skin": the slab over a
	# basement room and its outer walls are shared boxes with the look of the hub's
	# rooms above (the court's stone), so the room draws its own ceiling and walls
	# in front of them. ("upper_from" is a world height: the basement's floor is
	# at -6, the dado 1.3 m above it; the pipes' band hangs 0.1 m into the 3.5 m
	# ceiling, clear of the plates over the doors.)
	&"basement_corridor": {
		"wall": "plaster", "dado_tint": Color(0.5, 0.72, 0.62), "wall_upper": "plaster", "wall_tint": Color(0.84, 0.9, 0.95),
		"upper_from": -4.7, "floor": "concrete", "wall_skin": true, "ceiling_skin": true, "ceiling": "concrete", "ceiling_tint": Color(0.82, 0.84, 0.88),
		"reveal": "concrete", "threshold": "concrete",
		"bands": [{"prefix": "skirting_", "at": "floor", "set": "skirting_black_"}, {"prefix": "corridor_pipes_", "at": 3.6}],
		"frame_2_6": "doorframe_2x2_6",
	},
	&"basement_corridor_egypt": {
		"wall": "plaster", "dado_tint": Color(0.86, 0.66, 0.34), "wall_upper": "plaster", "wall_tint": Color(0.9, 0.88, 0.8),
		"upper_from": -4.7, "floor": "concrete", "wall_skin": true, "ceiling_skin": true, "ceiling": "concrete", "ceiling_tint": Color(0.82, 0.84, 0.88),
		"reveal": "concrete", "threshold": "concrete",
		"bands": [{"prefix": "skirting_", "at": "floor", "set": "skirting_black_"}, {"prefix": "corridor_pipes_", "at": 3.6}],
		"frame_2_6": "doorframe_2x2_6",
	},
	&"basement_corridor_north": {
		"wall": "plaster", "dado_tint": Color(0.3, 0.7, 0.68), "wall_upper": "plaster", "wall_tint": Color(0.84, 0.92, 0.94),
		"upper_from": -4.7, "floor": "concrete", "wall_skin": true, "ceiling_skin": true, "ceiling": "concrete", "ceiling_tint": Color(0.82, 0.84, 0.88),
		"reveal": "concrete", "threshold": "concrete",
		"bands": [{"prefix": "skirting_", "at": "floor", "set": "skirting_black_"}, {"prefix": "corridor_pipes_", "at": 3.6}],
		"frame_2_6": "doorframe_2x2_6",
	},
	&"basement_corridor_booth": {
		"wall": "plaster", "dado_tint": Color(0.7, 0.68, 0.46), "wall_upper": "plaster", "wall_tint": Color(0.9, 0.9, 0.84),
		"upper_from": -4.7, "floor": "concrete", "wall_skin": true, "ceiling_skin": true, "ceiling": "concrete", "ceiling_tint": Color(0.82, 0.84, 0.88),
		"reveal": "concrete", "threshold": "concrete",
		"bands": [{"prefix": "skirting_", "at": "floor", "set": "skirting_black_"}, {"prefix": "corridor_pipes_", "at": 3.6}],
		"frame_2_6": "doorframe_2x2_6",
	},
	&"basement_tunnel": {
		"wall": "brick", "wall_tint": Color(0.85, 0.8, 0.78), "floor": "flagstone", "wall_skin": true, "ceiling_skin": true, "ceiling": "brick",
		"ceiling_tint": Color(0.62, 0.6, 0.6), "reveal": "brick", "threshold": "flagstone",
		"bands": [{"prefix": "corridor_pipes_", "at": 3.6}],
		"frame_2_6": "doorframe_2x2_6",
	},
	&"basement_boiler": {
		"wall": "brick", "wall_tint": Color(0.7, 0.66, 0.64), "floor": "flagstone", "wall_skin": true, "ceiling_skin": true, "ceiling": "concrete",
		"ceiling_tint": Color(0.7, 0.72, 0.76), "reveal": "brick", "threshold": "flagstone",
		"bands": [{"prefix": "corridor_pipes_", "at": "ceiling"}],
		"frame_2_6": "doorframe_2x2_6",
	},
	&"basement_crossing": {
		"wall": "limestone_rustic", "wall_tint": Color(0.68, 0.68, 0.72), "floor": "flagstone", "wall_skin": true, "ceiling_skin": true, "ceiling": "concrete",
		"ceiling_tint": Color(0.72, 0.74, 0.78), "reveal": "limestone_rustic", "threshold": "flagstone",
		"bands": [], "frame_2_6": "doorframe_2x2_6",
	},
	&"basement_workshop": {
		"wall": "plaster", "dado_tint": Color(0.62, 0.44, 0.32), "wall_upper": "plaster", "wall_tint": Color(1.0, 0.92, 0.8),
		"upper_from": -4.9, "floor": "boards", "wall_skin": true, "ceiling_skin": true, "ceiling": "plaster", "ceiling_tint": Color(0.9, 0.82, 0.7),
		"reveal": "plaster", "threshold": "boards",
		"bands": [{"prefix": "skirting_", "at": "floor", "set": "skirting_pine_"}],
		"frame_2_6": "doorframe_2x2_6",
	},
	&"basement_store": {
		"wall": "plaster", "dado_tint": Color(0.62, 0.6, 0.55), "wall_upper": "plaster", "wall_tint": Color(0.95, 0.92, 0.84),
		"upper_from": -4.7, "floor": "concrete", "wall_skin": true, "ceiling_skin": true, "ceiling": "plaster", "ceiling_tint": Color(0.7, 0.7, 0.72),
		"reveal": "concrete", "threshold": "concrete",
		"bands": [{"prefix": "skirting_", "at": "floor", "set": "skirting_black_"}],
		"frame_2_6": "doorframe_2x2_6",
	},
	&"basement_switchboard": {
		"wall": "paint_wall", "wall_tint": Color(0.9, 1.0, 1.0), "floor": "concrete", "wall_skin": true, "ceiling_skin": true, "ceiling": "concrete",
		"ceiling_tint": Color(0.8, 0.82, 0.86), "reveal": "paint_wall", "threshold": "concrete",
		"bands": [{"prefix": "skirting_", "at": "floor", "set": "skirting_black_"}, {"prefix": "corridor_pipes_", "at": "ceiling"}],
		"frame_2_6": "doorframe_2x2_6",
	},
	&"basement_vault": {
		"wall": "concrete", "wall_tint": Color(0.9, 0.9, 0.95), "floor": "concrete", "wall_skin": true, "ceiling_skin": true, "ceiling": "concrete",
		"ceiling_tint": Color(0.75, 0.77, 0.8), "reveal": "concrete", "threshold": "concrete", "bands": [],
	},
	&"basement_shelter": {
		"wall": "plaster", "wall_tint": Color(0.85, 0.84, 0.76), "floor": "concrete", "wall_skin": true, "ceiling_skin": true, "ceiling": "concrete",
		"ceiling_tint": Color(0.75, 0.77, 0.8), "reveal": "plaster", "threshold": "concrete",
		"bands": [{"prefix": "skirting_", "at": "floor", "set": "skirting_black_"}],
	},
	# the archive and the guards' store: the booth's painted office, a cellar of the
	# old house: its rubble (their own ceilings: "ceiling_skin")
	&"basement_office": {
		"wall": "paint_wall", "floor": "linoleum", "wall_skin": true, "ceiling_skin": true, "ceiling": "ceiling_tiles", "reveal": "paint_wall",
		"threshold": "linoleum",
		"bands": [{"prefix": "skirting_", "at": "floor", "set": "skirting_black_"},
			{"prefix": "security_rail_", "at": 1.2}],
		"frame_2_6": "doorframe_2x2_6",
	},
	&"basement_cellar": {
		"wall": "stone_rubble", "wall_tint": Color(0.6, 0.6, 0.62), "floor": "flagstone", "wall_skin": true, "ceiling_skin": true,
		"ceiling": "stone_rubble", "reveal": "stone_rubble", "threshold": "flagstone", "bands": [],
	},
	# Floor I, Enlightenment wing (docs/art/kit-pietro1-oswiecenie.md): the
	# King's Library (oak chevron parquet, pale plaster over the bookcases, the
	# Greek-key cornice, 2 m coffers; bookcases, walkway, wells and stairs are
	# placed by the level, see the catalogue), the cabinets in green damask
	# over a walnut dado, the librarian's panelled office, the orrery's
	# rotunda under a starry ceiling
	&"enlightenment_library": {
		"wall": "plaster", "floor": "parquet_chevron", "ceiling": "plaster", "reveal": "enl_mahogany",
		"threshold": "marble_dark", "stair": "enl_oak_boards", "slab": "enl_oak_boards",
		"coffer": "lib_coffer_2m",
		"bands": [{"prefix": "lib_cornice_", "at": "ceiling", "middle_set": "lib_cornice_4m_motto"}],
		"frame_4": "lib_portal_4x4_5", "frame_2_8": "lib_doorframe_2x2_8",
		"fascia": "lib_walkway_fascia_", "fascia_end": "lib_walkway_fascia_end", "stairs_kit": "library",
	},
	&"enlightenment_cabinet": {
		"wall": "wallpaper", "floor": "parquet_chevron", "ceiling": "plaster", "reveal": "enl_mahogany",
		"threshold": "marble_dark",
		"bands": [{"prefix": "gallery_base_", "at": "floor"}, {"prefix": "gallery_top_", "at": "ceiling"}],
		"frame_4": "lib_portal_4x4_5", "frame_2_8": "lib_doorframe_2x2_8",
	},
	&"enlightenment_portraits": {"same_as": &"enlightenment_cabinet"},
	&"enlightenment_clocks": {"same_as": &"enlightenment_cabinet"},
	&"enlightenment_librarian": {
		"wall": "wallpaper", "floor": "parquet_chevron", "ceiling": "plaster", "reveal": "enl_mahogany",
		"threshold": "enl_oak_boards",
		"bands": [{"prefix": "gallery_base_", "at": "floor"}],
		"frame_2_8": "lib_doorframe_2x2_8",
	},
	&"enlightenment_planetarium": {
		"wall": "plaster", "floor": "marble_floor", "ceiling": "star_ceiling", "reveal": "enl_mahogany",
		"threshold": "marble_dark",
		"bands": [{"prefix": "lib_cornice_", "at": "ceiling"}],
		"pilasters": {"every": 4.8, "from": 0.0, "to": 20.8, "min_height": 18.0},
		"frame_4": "lib_portal_4x4_5", "frame_2_8": "lib_doorframe_2x2_8",
	},
	# Floor I, Americas and Oceania wing (docs/art/kit-pietro1-ameryki.md):
	# burnished deep red plaster over a basalt dado inlaid with turquoise frets,
	# the carved stone frieze (its face's bottom on a whole metre), a stepped
	# cornice, polished basalt floors, smoke-dark board ceilings; the Moai room
	# in dark stone; the Pacific gallery in dark boards and plaited mat panels
	# under a bark-cloth ceiling (rafters pacific_beam_4m every 2 m, placed by
	# the level). The temple's terraces and stairs are pieces (temple_*).
	&"americas_temple": {
		"wall": "am_red_wall", "floor": "basalt_americas", "ceiling": "am_ceiling", "reveal": "am_stone_blocks",
		"threshold": "basalt_americas", "stair": "am_stone_blocks", "slab": "am_stone_blocks",
		"bands": [{"prefix": "americas_dado_", "at": "floor"}, {"prefix": "americas_frieze_", "at": 7.0},
			{"prefix": "americas_cornice_", "at": "ceiling"}],
		"frame_4": "americas_portal_4m",
	},
	&"americas_north": {
		"wall": "am_red_wall", "floor": "basalt_americas", "ceiling": "am_ceiling", "reveal": "am_stone_blocks",
		"threshold": "basalt_americas",
		"bands": [{"prefix": "americas_dado_", "at": "floor"}, {"prefix": "americas_frieze_", "at": 4.0},
			{"prefix": "americas_cornice_", "at": "ceiling"}],
		"frame_4": "americas_portal_4m",
	},
	&"americas_totems": {
		"wall": "am_red_wall", "floor": "basalt_americas", "ceiling": "am_ceiling", "reveal": "am_stone_blocks",
		"threshold": "basalt_americas",
		"bands": [{"prefix": "americas_dado_", "at": "floor"}, {"prefix": "americas_cornice_", "at": "ceiling"}],
		"frame_4": "americas_portal_4m",
	},
	&"americas_moai": {
		"wall": "am_stone_blocks", "wall_tint": Color(0.42, 0.4, 0.4), "floor": "basalt_americas",
		"ceiling": "am_ceiling", "reveal": "am_stone_blocks", "threshold": "basalt_americas",
		"bands": [{"prefix": "americas_dado_", "at": "floor"}],
		"frame_4": "americas_portal_4m",
	},
	&"americas_pacific": {
		"wall": "boards_pacific", "floor": "boards_pacific", "ceiling": "am_tapa", "reveal": "boards_pacific",
		"threshold": "boards_pacific",
		"bands": [{"prefix": "pacific_dado_", "at": "floor"}],
	},
	&"americas_pit": {"same_as": &"americas_pacific"},
	&"americas_moai_hideout": {"wall": "am_stone_blocks", "wall_tint": Color(0.5, 0.48, 0.46), "floor": "basalt_americas",
		"ceiling": "am_stone_blocks", "reveal": "am_stone_blocks", "threshold": "am_stone_blocks", "bands": []},
	&"americas_workshop": {"wall": "boards_pacific", "floor": "boards", "ceiling": "am_ceiling",
		"reveal": "boards_pacific", "threshold": "boards", "bands": []},
	# Floor I, Greek wing (docs/art/kit-pietro1-grecja.md): white marble
	# ashlar, the Parthenon frieze at eye level and above (varied slabs), an
	# Ionic crown under a plaster ceiling with blue-and-gold coffers, a cream
	# floor with a meander border; Erechtheion portals.
	&"greece_gallery": {
		"wall": "gr_ashlar", "floor": "marble_greek", "ceiling": "gr_plaster", "reveal": "gr_marble",
		"threshold": "gr_marble", "coffer": "gr_coffer_2m", "border": "gr_floor_border_",
		"bands": [{"prefix": "gr_base_", "at": "floor"}, {"prefix": "gr_frieze_", "at": 1.45},
			{"prefix": "gr_cornice_", "at": "ceiling"}],
		"frame_4": "gr_portal_4m", "frame_2_8": "gr_portal_2m",
	},
	&"greece_nereid": {
		"wall": "gr_ashlar", "floor": "marble_greek", "ceiling": "gr_plaster", "reveal": "gr_marble",
		"threshold": "gr_marble", "border": "gr_floor_border_", "stair_rails": true,
		"bands": [{"prefix": "gr_base_", "at": "floor"}, {"prefix": "gr_cornice_", "at": "ceiling"}],
		"frame_4": "gr_portal_4m", "frame_2_8": "gr_portal_2m",
	},
	&"greece_metopes": {
		"wall": "gr_ashlar", "floor": "marble_greek", "ceiling": "gr_plaster", "reveal": "gr_marble",
		"threshold": "gr_marble",
		"bands": [{"prefix": "gr_base_", "at": "floor"}, {"prefix": "gr_cornice_doric_", "at": "ceiling"}],
		"frame_4": "gr_portal_4m", "frame_2_8": "gr_portal_2m",
	},
	&"greece_vases": {
		"wall": "gr_wall_paint", "floor": "marble_greek", "ceiling": "gr_plaster", "reveal": "gr_marble",
		"threshold": "gr_marble",
		"bands": [{"prefix": "gr_base_", "at": "floor"}, {"prefix": "gr_cornice_", "at": "ceiling"}],
		"frame_4": "gr_portal_4m", "frame_2_8": "gr_portal_2m",
	},
	# (stage P3: the Bassae frieze runs round the room at the mezzanine's eye
	# level, 1.2 m over its floor at 4.5 m - as in the museum, high up)
	&"greece_bassae": {
		"wall": "gr_ashlar", "floor": "marble_greek", "ceiling": "gr_plaster", "reveal": "gr_marble",
		"threshold": "gr_marble", "stair_rails": true,
		"bands": [{"prefix": "gr_base_", "at": "floor"}, {"prefix": "gr_bassae_", "at": 5.7},
			{"prefix": "gr_cornice_doric_", "at": "ceiling"}],
		"frame_2_8": "gr_portal_2m",
	},
	&"greece_casts": {
		"wall": "gr_limewash", "floor": "boards", "ceiling": "gr_plaster", "reveal": "gr_limewash",
		"threshold": "boards", "bands": [{"prefix": "skirting_", "at": "floor", "set": "skirting_pine_"}],
		"frame_2_8": "doorframe_2x2_8",
	},
	# Floor I, Assyrian wing (docs/art/kit-pietro1-asyria.md): carved gypsum slabs
	# from the floor to 3 m (relief runs of 2 / 1 m, a theme per room through the
	# texture-set prefix), the painted frieze over them, lime-washed plaster above,
	# gypsum flagstones, a cedar plank ceiling on cedar beams (every 4 m) and gypsum
	# corbels; the courtyard: sun-dried brick above the slabs, a baked-brick floor.
	&"assyria_nimrud": {
		"wall": "asy_alabaster", "wall_upper": "asy_plaster", "upper_from": 3.0, "floor": "flagstone_asy",
		"ceiling": "asy_cedar", "reveal": "asy_alabaster", "threshold": "flagstone_asy",
		"beams": "asy_beam_4m", "corbel": "asy_corbel",
		"bands": [{"prefix": "asy_relief_", "at": "floor"}, {"prefix": "asy_frieze_", "at": 3.0}],
		"frame_4": "asy_portal_4m", "frame_2_6": "asy_doorframe_2x2_6",
	},
	&"assyria_gate": {
		"wall": "asy_alabaster", "wall_upper": "asy_plaster", "upper_from": 3.0, "floor": "flagstone_asy",
		"ceiling": "asy_cedar", "reveal": "asy_alabaster", "threshold": "flagstone_asy",
		"beams": "asy_beam_4m", "corbel": "asy_corbel",
		"bands": [{"prefix": "asy_relief_", "at": "floor", "set": "asy_relief_hunt_"},
			{"prefix": "asy_frieze_", "at": 3.0}],
		"frame_4": "asy_portal_4m", "frame_2_6": "asy_doorframe_2x2_6",
	},
	&"assyria_lions": {
		"wall": "asy_alabaster", "wall_upper": "asy_plaster", "upper_from": 3.0, "floor": "flagstone_asy",
		"ceiling": "asy_cedar", "reveal": "asy_alabaster", "threshold": "flagstone_asy",
		"beams": "asy_beam_4m", "corbel": "asy_corbel",
		"bands": [{"prefix": "asy_relief_", "at": "floor", "set": "asy_relief_lions_"},
			{"prefix": "asy_frieze_", "at": 3.0}],
		"frame_4": "asy_portal_4m", "frame_2_6": "asy_doorframe_2x2_6",
	},
	&"assyria_balawat": {
		"wall": "asy_alabaster", "wall_upper": "asy_plaster", "upper_from": 3.0, "floor": "flagstone_asy",
		"ceiling": "asy_cedar", "reveal": "asy_alabaster", "threshold": "flagstone_asy",
		"beams": "asy_beam_4m", "corbel": "asy_corbel",
		"bands": [{"prefix": "asy_relief_", "at": "floor", "set": "asy_relief_army_"},
			{"prefix": "asy_frieze_", "at": 3.0}],
		"frame_4": "asy_portal_4m", "frame_2_6": "asy_doorframe_2x2_6",
	},
	&"assyria_courtyard": {
		"wall": "asy_alabaster", "wall_upper": "asy_mudbrick", "upper_from": 3.0, "floor": "tiles_asy_brick",
		"ceiling": "asy_plaster", "reveal": "asy_alabaster", "threshold": "tiles_asy_brick",
		"bands": [{"prefix": "asy_relief_", "at": "floor", "set": "asy_relief_chariot_"},
			{"prefix": "asy_frieze_", "at": 3.0}],
		"frame_4": "asy_portal_4m", "frame_2_6": "asy_doorframe_2x2_6",
	},
	&"assyria_service_stairs": {
		"wall": "asy_plaster", "floor": "flagstone_asy", "ceiling": "asy_plaster", "reveal": "asy_plaster",
		"threshold": "flagstone_asy", "bands": [], "frame_2_6": "asy_doorframe_2x2_6",
	},
	&"assyria_tablets": {
		"wall": "asy_mudbrick", "floor": "tiles_asy_brick", "ceiling": "asy_cedar", "reveal": "asy_mudbrick",
		"threshold": "tiles_asy_brick", "bands": [], "frame_2_6": "asy_doorframe_2x2_6",
	},
	&"assyria_library": {
		"wall": "asy_alabaster", "wall_upper": "asy_plaster", "upper_from": 3.0, "floor": "flagstone_asy",
		"ceiling": "asy_cedar", "reveal": "asy_alabaster", "threshold": "flagstone_asy",
		"beams": "asy_beam_4m", "corbel": "asy_corbel",
		"bands": [{"prefix": "asy_relief_", "at": "floor", "set": "asy_relief_text_"},
			{"prefix": "asy_frieze_", "at": 3.0}],
		"frame_4": "asy_portal_4m", "frame_2_6": "asy_doorframe_2x2_6",
	},
	&"assyria_lions_gallery": {"same_as": &"assyria_lions"},
	&"assyria_freight_stairs": {"same_as": &"assyria_service_stairs"},
	# Floor I, Asia wing (docs/art/kit-pietro1-azja.md): ivory plaster over a
	# lacquered dado, the painted frieze (its bottom on a whole metre), the
	# bracket cornice under a painted coffered ceiling; Korea: board floor,
	# beams across with carved brackets; the armour hall dark; the garden's
	# earthen wall with a tiled coping at 3 m and the museum's stone above,
	# raked gravel; the tea house: clay walls, tatami, a board ceiling.
	&"asia_china": {
		"wall": "asia_plaster", "floor": "tiles_golden", "ceiling": "asia_coffers", "reveal": "asia_lacquer",
		"threshold": "stone_slate",
		"bands": [{"prefix": "asia_dado_", "at": "floor"}, {"prefix": "asia_frieze_", "at": 5.0},
			{"prefix": "asia_eaves_", "at": "ceiling"}],
		"frame_4": "asia_moon_gate_4m", "frame_2_6": "asia_doorframe_2x2_6",
	},
	&"asia_porcelain": {
		"wall": "asia_plaster", "wall_tint": Color(0.62, 0.68, 0.76), "floor": "stone_slate",
		"ceiling": "asia_lacquer_black", "reveal": "asia_lacquer", "threshold": "stone_slate",
		"bands": [{"prefix": "asia_dado_", "at": "floor"}, {"prefix": "asia_eaves_", "at": "ceiling"}],
		"frame_2_6": "asia_doorframe_2x2_6",
	},
	&"asia_korea": {
		"wall": "asia_plaster", "floor": "boards_dark", "ceiling": "asia_plaster", "reveal": "asia_lacquer",
		"threshold": "stone_slate", "beams": "asia_beam_4m", "corbel": "asia_corbel",
		"bands": [{"prefix": "asia_dado_", "at": "floor"}, {"prefix": "asia_frieze_", "at": 4.0},
			{"prefix": "asia_eaves_", "at": "ceiling"}],
		"frame_4": "asia_moon_gate_4m", "frame_2_6": "asia_doorframe_2x2_6",
	},
	&"asia_armor": {
		"wall": "asia_plaster_dark", "floor": "boards_dark", "ceiling": "asia_lacquer_black",
		"reveal": "asia_lacquer_black", "threshold": "boards_dark",
		"bands": [{"prefix": "asia_dado_", "at": "floor"}, {"prefix": "asia_eaves_", "at": "ceiling"}],
		"frame_4": "asia_moon_gate_4m", "frame_2_6": "asia_doorframe_2x2_6",
	},
	&"asia_garden": {
		"wall": "garden_wall", "wall_upper": "portland_ashlar", "upper_from": 3.0, "floor": "gravel_raked",
		"ceiling": "plaster", "reveal": "garden_wall", "threshold": "stone_slate",
		"bands": [{"prefix": "asia_wallcap_", "at": 3.0}],
		"frame_4": "asia_moon_gate_4m",
	},
	&"asia_teahouse": {
		"wall": "garden_wall", "floor": "tatami", "ceiling": "boards_dark", "reveal": "garden_wall",
		"threshold": "boards_dark", "bands": [],
	},
}
## LevelKit fixture kit id -> [model, local transform]: the model placed so
## the light sits at the fixture's origin and its mount runs back along +Z.
const FIXTURES := {
	&"exit_sign": ["exit_sign", Transform3D.IDENTITY],
	&"emergency_lamp": ["emergency_lamp", Transform3D.IDENTITY],
	&"column_lamp": ["column_lamp", Transform3D.IDENTITY],
	&"ceiling_lamp": ["ceiling_lamp", Transform3D.IDENTITY],
	&"tube_lamp": ["tube_lamp", Transform3D.IDENTITY],
	&"bulb": ["bulb", Transform3D.IDENTITY],
	&"desk_lamp": ["desk_lamp", Transform3D.IDENTITY],
	# the stage 1b sconce faces +Z from its wall plate: turn it and put the
	# centre of its tulip shade (0.28 out, 0.2 up) on the light
	&"sconce": ["sconce", Transform3D(Basis(Vector3.UP, PI), Vector3(0.0, -0.2, 0.28))],
	# the light sits among the candles, the crown hangs 5 cm above it
	&"chandelier": ["chandelier", Transform3D(Basis.IDENTITY, Vector3(0.0, 0.05, 0.0))],
}
## Room name signs by kit id -> texture set of "sign_room" ("" = GALERIA
## RZEŹBY).
const SIGNS := {
	&"sign_gallery": "", &"sign_armory": "sign_room_zbrojownia", &"sign_diorama": "sign_room_diorama",
	&"sign_hall": "sign_room_hol", &"sign_staff": "sign_room_personel",
}
## Painting size (x, y) -> frame model; other sizes take the nearest by area.
const FRAMES := {
	Vector2(3.0, 2.0): "frame_3x2", Vector2(3.5, 2.2): "frame_3_5x2_2", Vector2(2.4, 1.8): "frame_2_4x1_8",
	Vector2(1.2, 0.9): "frame_1_2x0_9", Vector2(0.6, 0.8): "frame_0_6x0_8",
}
## Texture sets of the frames (the canvases), for variety by position.
const FRAME_SETS := {
	"frame_3x2": ["", "_sea"], "frame_3_5x2_2": ["", "_land"], "frame_2_4x1_8": ["", "_sea", "_still"],
	"frame_1_2x0_9": ["", "_land"], "frame_0_6x0_8": ["", "_still"],
}
# --- rooms and fields ----------------------------------------------------------

## The style of [param room] (rooms that share a style resolve "same_as";
## Floor I rooms take theirs from Floor1Art.ROOM_STYLES).
static func style(room: StringName) -> Dictionary:
	return ROOMS[style_name(room)]


## The key in ROOMS of [param room]'s style: its own, the one it is
## "same_as", the Floor I room's (Floor1Art.ROOM_STYLES), else corridor_w.
static func style_name(room: StringName) -> StringName:
	var key: StringName = Floor1Art.ROOM_STYLES.get(room, room)
	if not ROOMS.has(key):
		return &"corridor_w"
	var s: Dictionary = ROOMS[key]
	return s["same_as"] if s.has("same_as") else key


## True when [param room] has a style of its own (not the fallback).
static func has_style(room: StringName) -> bool:
	return ROOMS.has(Floor1Art.ROOM_STYLES.get(room, room))


## Tile material of a shell face. Roles: &"wall", &"wall_upper", &"floor",
## &"ceiling", &"reveal" (lintels, passage sides), &"threshold", &"stair",
## &"slab" (the balcony slab). World-mapped: stretch and cut freely.
static func field(room: StringName, role: StringName) -> Material:
	var s := style(room)
	var key := String(role)
	if key == "wall_upper" and not s.has(key):
		key = "wall"
	if not s.has(key):
		key = "reveal" if key in ["stair", "slab", "threshold"] and s.has("reveal") else "wall"
	var tint: Color = Color.WHITE
	if key == "ceiling" and s.has("ceiling_tint"):
		tint = s["ceiling_tint"]
	elif key == "well":
		tint = s.get("well_tint", Color.WHITE)
	elif key == "wall" and s.has("upper_from") and s.has("dado_tint"):
		# the lower layer of a split wall: a painted dado
		tint = s["dado_tint"]
	elif key.begins_with("wall") and s.has("wall_tint"):
		tint = s["wall_tint"]
	var offset: Vector3 = s.get("floor_offset", Vector3.ZERO) if key == "floor" else Vector3.ZERO
	return ArtLibrary.arch_tile(String(s[key]), false, tint, offset)


## The shell kit id of a greybox box -> field role. A lintel (the block
## over a passage) is mostly seen as wall around the doorway, so it takes
## the wall field (split with [method wall_layers] like walls).
static func shell_role(kit: StringName) -> StringName:
	match kit:
		&"floor":
			return &"floor"
		&"threshold":
			return &"threshold"
		&"slab":
			return &"slab"
		&"ceiling":
			return &"ceiling"
	return &"wall"


## Splits a shell wall box of [param room] at the style's storey line
## (the hall: rustication below 6 m, ashlar above). Returns [[AABB,
## Material], ...] covering [param box].
static func wall_layers(room: StringName, box: AABB) -> Array:
	var s := style(room)
	# the lining of a skylight well (all above the ceiling): dark plaster,
	# or the moon turns it into a glowing slab
	if s.has("well_from") and box.position.y >= float(s["well_from"]) - 0.01:
		return [[box, field(room, &"well")]]
	if not s.has("upper_from") or box.end.y <= float(s["upper_from"]) or box.position.y >= float(s["upper_from"]):
		var role := &"wall_upper" if s.has("upper_from") and box.position.y >= float(s["upper_from"]) else &"wall"
		return [[box, field(room, role)]]
	var cut: float = s["upper_from"]
	var low := AABB(box.position, Vector3(box.size.x, cut - box.position.y, box.size.z))
	var high := AABB(Vector3(box.position.x, cut, box.position.z), Vector3(box.size.x, box.end.y - cut, box.size.z))
	return [[low, field(room, &"wall")], [high, field(room, &"wall_upper")]]


# --- models --------------------------------------------------------------------

## A kit model, optionally with another texture set (same mesh).
static func model(id: String, texture_set: String = "") -> Node3D:
	if texture_set == "" or texture_set == id:
		return ArtLibrary.model(id)
	return ArtLibrary.model(id, {id: texture_set})


static var _baked_meshes: Dictionary = {}


## [param view]'s mesh with the materials it shows baked into the surfaces
## of a copy (shared per mesh and material set): what a MultiMesh of many
## such pieces draws.
static func baked_mesh(view: MeshInstance3D) -> Mesh:
	var source := view.mesh
	var key := str(source.get_instance_id())
	for i in source.get_surface_count():
		var mat := view.get_active_material(i)
		key += ":%d" % (mat.get_instance_id() if mat != null else 0)
	if _baked_meshes.has(key):
		return _baked_meshes[key]
	var copy := source.duplicate() as Mesh
	for i in copy.get_surface_count():
		copy.surface_set_material(i, view.get_active_material(i))
	_baked_meshes[key] = copy
	return copy


static func _add(parent: Node3D, id: String, xform: Transform3D, texture_set: String = "") -> Node3D:
	var node := model(id, texture_set)
	node.transform = xform
	parent.add_child(node)
	return node


static func _holder(label: String) -> Node3D:
	var n := Node3D.new()
	n.name = label
	return n


## Splits [param length] into run modules of [param sizes] (longest first):
## returns [[module length, start, stretch], ...]. A length that the sizes
## fill exactly is filled greedily (no stretch: every module keeps its
## rhythm of joints, dentils or balusters); otherwise one size is repeated
## and stretched evenly (by at most MAX_STRETCH), the longest that fits.
static func fill_run(length: float, sizes: Array) -> Array:
	var out: Array = []
	var left := length
	var x := 0.0
	for w: float in sizes:
		while left >= w - 0.001:
			out.append([w, x, 1.0])
			x += w
			left -= w
	if left <= 0.01 and not out.is_empty():
		return out
	out.clear()
	for w: float in sizes:
		var n := maxi(1, int(round(length / w)))
		var stretch := length / (n * w)
		if absf(stretch - 1.0) <= MAX_STRETCH or w == sizes[-1]:
			for i in n:
				out.append([w, i * w * stretch, stretch])
			return out
	return out


## Places a run of [param prefix] modules from x0 to x1 (face frame: +X
## along the wall, -Z into the room) at height [param y].
static func run(parent: Node3D, prefix: String, x0: float, x1: float, y: float, texture_prefix: String = "") -> void:
	var sizes: Array = RUN_SIZES.get(prefix, RUN)
	for m: Array in fill_run(x1 - x0, sizes):
		var w: float = m[0]
		var tag: String = RUN_TAG[w]
		var id := prefix + tag
		var scale: float = m[2]
		var at := Vector3(x0 + float(m[1]) + w * scale * 0.5, y, 0.0)
		var set_id := (texture_prefix + tag) if texture_prefix != "" else ""
		if set_id == "" and VARIED_RUNS.has(prefix):
			set_id = varied_set(id, at.x)
		_add(parent, id, Transform3D(Basis.from_scale(Vector3(scale, 1.0, 1.0)), at), set_id)


## One of the texture sets of [param id] (or "" = its own) chosen by the
## module's position [param x] along the run: neighbours differ.
static func varied_set(id: String, x: float) -> String:
	var sets: Array = [""]
	sets.append_array(ArtLibrary.KIT_SETS.get(StringName(id), []))
	var k := posmod(hash(int(floor(x * 2.0)) + 7919), sets.size())
	return String(sets[k])


## Free spans of [0, length] after removing [param blocked] intervals.
static func free_spans(length: float, blocked: Array) -> Array:
	var spans: Array = [[0.0, length]]
	for b: Array in blocked:
		var next: Array = []
		for s: Array in spans:
			if b[1] <= s[0] or b[0] >= s[1]:
				next.append(s)
				continue
			if b[0] > s[0]:
				next.append([s[0], b[0]])
			if b[1] < s[1]:
				next.append([b[1], s[1]])
		spans = next
	var out: Array = []
	for s: Array in spans:
		if float(s[1]) - float(s[0]) > 0.24:
			out.append(s)
	return out


## Transform of a wall face: origin at its start on the floor, +X along the
## wall, -Z into the room ([param inward] = the room side), +Y up. The ends
## [param a] and [param b] may come in either order.
static func face_transform(a: Vector3, b: Vector3, inward: Vector3) -> Transform3D:
	var z := -Vector3(inward.x, 0.0, inward.z).normalized()
	var x := Vector3.UP.cross(z)
	var start := a if (b - a).dot(x) >= 0.0 else b
	return Transform3D(Basis(x, Vector3.UP, z), start)


## Dresses one wall face. [param face] keys:
##   "room" (StringName), "length", "height" (floor to ceiling),
##   "openings": [[x0, x1, y0, y1], ...] in the face frame (door holes, with
##              the portals' margins), "holes": the same without them (the
##              wall skin's holes, absent: the openings),
##   "xform": the face frame in the world (the skin reads the floor's height),
##   "soffits": [[x0, x1, y], ...] a slab meeting the wall at height y
##              (bands with "soffit" drop under it, bands above y stop),
##   "balcony": [[x0, x1], ...] where a walkway runs along the upper storey.
## Returns the bands, pilasters and cornice in the face frame
## ([method face_transform]).
static func dress_wall(face: Dictionary) -> Node3D:
	var room: StringName = face.get("room", &"")
	var s := style(room)
	var length: float = face["length"]
	var height: float = face["height"]
	var openings: Array = face.get("openings", [])
	var soffits: Array = face.get("soffits", [])
	var root := _holder("WallDressing")
	if s.get("wall_skin", false):
		_wall_skin(root, room, s, face)
	for band: Dictionary in s.get("bands", []):
		var prefix: String = band["prefix"]
		var span: Vector2 = BAND_SPAN.get(prefix, Vector2(0.0, 0.5))
		var at: Variant = band["at"]
		var y := 0.0
		if at is String and at == "ceiling":
			y = height
		elif not (at is String):
			y = float(at)
		# pieces of the face this band may run along, with their datum
		var pieces: Array = []
		if band.get("only", "") == "balcony":
			for b: Array in face.get("balcony", []):
				pieces.append([b[0], b[1], y])
		elif band.get("soffit", false):
			var covered: Array = []
			for sf: Array in soffits:
				covered.append([sf[0], sf[1]])
				pieces.append([sf[0], sf[1], minf(y, float(sf[2]))])
			for fs: Array in free_spans(length, covered):
				pieces.append([fs[0], fs[1], y])
		else:
			pieces.append([0.0, length, y])
		for piece: Array in pieces:
			var datum: float = piece[2]
			var lo: float = datum + span.x
			var hi: float = datum + span.y
			var blocked: Array = []
			for o: Array in openings:
				if float(o[2]) < hi - 0.01 and float(o[3]) > lo + 0.01:
					blocked.append([o[0], o[1]])
			# a slab crossing the band (a balcony against this wall) stops it too
			if not band.get("soffit", false):
				for sf: Array in soffits:
					if float(sf[2]) < hi and float(sf[2]) + 0.4 > lo:
						blocked.append([sf[0], sf[1]])
			var inner: Array = []
			for fs: Array in free_spans(length, blocked):
				var a := maxf(fs[0], piece[0])
				var b := minf(fs[1], piece[1])
				if b - a > 0.24:
					inner.append([a, b])
			for fs: Array in inner:
				var first := root.get_child_count()
				run(root, prefix, fs[0], fs[1], datum, String(band.get("set", "")))
				if band.has("middle_set") and length >= 20.0:
					_middle_module(root, first, prefix + "4m", length * 0.5, String(band["middle_set"]))
	if s.has("pilasters") and height >= float(s["pilasters"]["min_height"]):
		_pilasters(root, s["pilasters"], length, openings)
	return root


## Thickness of a wall skin (m): thinner than the skirting (0.02) and the door
## frames (0.03) that stand on it.
const WALL_SKIN := 0.01


## The room's own wall under its bands: a thin skin over the face (holes
## left open), its dado and its upper wall in the style's fields. A wall box
## shared by stacked rooms (the basement's outer walls run up through the
## hub's stone) has one owner and one look; the skin gives the basement side
## its own.
static func _wall_skin(root: Node3D, room: StringName, s: Dictionary, face: Dictionary) -> void:
	var length: float = face["length"]
	var height: float = face["height"]
	var floor_y := (face["xform"] as Transform3D).origin.y if face.has("xform") else 0.0
	var holes: Array = face.get("holes", face.get("openings", []))
	var spans: Array = [[0.0, length]]
	for h: Array in holes:
		var next: Array = []
		for span: Array in spans:
			if float(h[1]) <= float(span[0]) or float(h[0]) >= float(span[1]):
				next.append(span)
				continue
			if float(h[0]) > float(span[0]) + 0.02:
				next.append([span[0], h[0]])
			if float(h[1]) < float(span[1]) - 0.02:
				next.append([h[1], span[1]])
		spans = next
	var pieces: Array = []
	for span: Array in spans:
		pieces.append([span[0], span[1], 0.0, height])
	for h: Array in holes:
		var hx0 := maxf(float(h[0]), 0.0)
		var hx1 := minf(float(h[1]), length)
		if float(h[3]) < height - 0.01:
			pieces.append([hx0, hx1, h[3], height])
		if float(h[2]) > 0.01:
			pieces.append([hx0, hx1, 0.0, h[2]])
	var cut := float(s["upper_from"]) - floor_y if s.has("upper_from") else INF
	for piece: Array in pieces:
		var x0 := float(piece[0])
		var x1 := float(piece[1])
		var y0 := float(piece[2])
		var y1 := float(piece[3])
		if x1 - x0 < 0.02 or y1 - y0 < 0.02:
			continue
		var layers: Array = [[y0, y1, &"wall"]]
		if cut > y0 + 0.01 and cut < y1 - 0.01:
			layers = [[y0, cut, &"wall"], [cut, y1, &"wall_upper"]]
		elif cut <= y0 + 0.01:
			layers = [[y0, y1, &"wall_upper"]]
		for layer: Array in layers:
			var skin := MeshInstance3D.new()
			var mesh := BoxMesh.new()
			mesh.size = Vector3(x1 - x0, float(layer[1]) - float(layer[0]), WALL_SKIN)
			skin.mesh = mesh
			skin.material_override = field(room, layer[2])
			skin.position = Vector3((x0 + x1) * 0.5, (float(layer[0]) + float(layer[1])) * 0.5, -WALL_SKIN * 0.5)
			skin.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			root.add_child(skin)


## Gives the module [param id] among [param root]'s children from
## [param first] on that lies over [param middle] (face x) the texture set
## [param texture_set].
static func _middle_module(root: Node3D, first: int, id: String, middle: float, texture_set: String) -> void:
	for i in range(first, root.get_child_count()):
		var module := root.get_child(i) as Node3D
		if String(module.scene_file_path).get_file() != id + ".glb":
			continue
		if absf(module.position.x - middle) > 2.0 * module.scale.x:
			continue
		var motto := model(id, texture_set)
		motto.transform = module.transform
		root.add_child(motto)
		root.move_child(motto, i)
		module.free()
		return


static func _pilasters(root: Node3D, spec: Dictionary, length: float, openings: Array) -> void:
	var every: float = spec["every"]
	var y0: float = spec["from"]
	var y1: float = spec["to"]
	var n := maxi(1, int(round(length / every)))
	for k in n:
		var x := (k + 0.5) * length / n
		var clear := true
		for o: Array in openings:
			if float(o[2]) < y1 and float(o[3]) > y0 and x > float(o[0]) - 0.8 and x < float(o[1]) + 0.8:
				clear = false
		if not clear:
			continue
		var shaft_h := y1 - y0 - 0.45 - 0.6
		_add(root, "hall_pilaster_base", Transform3D(Basis.IDENTITY, Vector3(x, y0, 0.0)))
		_add(root, "hall_pilaster_shaft", Transform3D(Basis.from_scale(Vector3(1.0, shaft_h, 1.0)), Vector3(x, y0 + 0.45, 0.0)))
		_add(root, "hall_pilaster_capital", Transform3D(Basis.IDENTITY, Vector3(x, y1 - 0.6, 0.0)))


## Ceiling dressing of a ceiling box of [param size] (x, z) seen from below:
## origin = centre of the box's underside. Hall: 2 m coffers stretched to
## fit; gallery: the stage 1b walnut coffers; armory: oak beams every 4 m
## across X (corbels where [param walls_x] says the box meets walls).
static func dress_ceiling(room: StringName, size: Vector2, walls_x: bool = true) -> Node3D:
	var s := style(room)
	var root := _holder("CeilingDressing")
	if s.get("ceiling_skin", false):
		# a thin skin under the slab (the slab is one box with one look: the room
		# above's)
		var skin := MeshInstance3D.new()
		var skin_mesh := BoxMesh.new()
		skin_mesh.size = Vector3(size.x, 0.04, size.y)
		skin.mesh = skin_mesh
		skin.material_override = field(room, &"ceiling")
		skin.position = Vector3(0.0, -0.02, 0.0)
		root.add_child(skin)
	if s.has("coffer") or s.has("coffer_legacy"):
		var id: String = s.get("coffer", s.get("coffer_legacy", ""))
		var module: float = s.get("coffer_size", 2.0)
		var nx := maxi(1, int(round(size.x / module)))
		var nz := maxi(1, int(round(size.y / module)))
		var sx := size.x / (nx * module)
		var sz := size.y / (nz * module)
		for i in nx:
			for j in nz:
				var c := Vector3(-size.x * 0.5 + (i + 0.5) * module * sx, 0.0, -size.y * 0.5 + (j + 0.5) * module * sz)
				var xf := Transform3D(Basis.from_scale(Vector3(sx, 1.0, sz)), c)
				if s.has("coffer_legacy"):
					# the stage 1b module has its origin on a corner (x 0..2, z -2..0)
					xf = xf * Transform3D(Basis.IDENTITY, Vector3(-1.0, 0.0, 1.0))
				_add(root, id, xf)
	if s.has("beams"):
		var spacing := 4.0
		var n := maxi(1, int(floor(size.y / spacing)))
		for j in n:
			var z := -size.y * 0.5 + (j + 0.5) * size.y / n
			var beams := fill_run(size.x, [4.0])
			for m: Array in beams:
				var at := Vector3(-size.x * 0.5 + float(m[1]) + 2.0 * float(m[2]), 0.0, z)
				_add(root, String(s["beams"]), Transform3D(Basis.from_scale(Vector3(m[2], 1.0, 1.0)), at))
			if walls_x:
				for sx2 in [-1.0, 1.0]:
					var yaw := PI * 0.5 if sx2 < 0.0 else -PI * 0.5
					_add(root, String(s["corbel"]), Transform3D(Basis(Vector3.UP, yaw), Vector3(sx2 * size.x * 0.5, -0.4, z)))
	return root


## Floor dressing of a room floor rectangle [param rect] (x, z, world or
## local, the same frame as the result) at height 0: the hall's inlaid
## border along the walls (1 m wide, corner squares) and the compass
## medallion in the middle. [param medallion_at] overrides the centre.
static func dress_floor(room: StringName, rect: Rect2, medallion_at: Variant = null) -> Node3D:
	var s := style(room)
	var root := _holder("FloorDressing")
	if s.has("border"):
		var prefix: String = s["border"]
		var x0 := rect.position.x
		var x1 := rect.end.x
		var z0 := rect.position.y
		var z1 := rect.end.y
		# each side: the run between the corner squares, strip toward the room
		var sides := [
			[Vector3(x0 + 1.0, 0, z0), Vector3(x1 - 1.0, 0, z0), Vector3(0, 0, 1)],
			[Vector3(x1 - 1.0, 0, z1), Vector3(x0 + 1.0, 0, z1), Vector3(0, 0, -1)],
			[Vector3(x0, 0, z1 - 1.0), Vector3(x0, 0, z0 + 1.0), Vector3(1, 0, 0)],
			[Vector3(x1, 0, z0 + 1.0), Vector3(x1, 0, z1 - 1.0), Vector3(-1, 0, 0)],
		]
		for side: Array in sides:
			var a: Vector3 = side[0]
			var b: Vector3 = side[1]
			var xf := face_transform(a, b, side[2])
			var holder := _holder("Border")
			holder.transform = xf
			run(holder, prefix, 0.0, a.distance_to(b), 0.0)
			root.add_child(holder)
		# corner squares: the model covers x 0..1, z -1..0 from the corner
		var corners := [[Vector3(x0, 0, z0), PI * 0.5], [Vector3(x1, 0, z0), 0.0],
			[Vector3(x1, 0, z1), -PI * 0.5], [Vector3(x0, 0, z1), PI]]
		for c: Array in corners:
			_add(root, prefix + "corner", Transform3D(Basis(Vector3.UP, float(c[1]) + PI), c[0]))
	if s.has("medallion"):
		var centre: Vector3 = medallion_at if medallion_at != null else Vector3(rect.get_center().x, 0.0, rect.get_center().y)
		_add(root, String(s["medallion"]), Transform3D(Basis.IDENTITY, centre))
	return root


# --- pieces --------------------------------------------------------------------

## The art for a LevelKit piece, in its frame (origin = centre of the base,
## -Z = front), fitted to [param size]; null = keep the greybox.
static func piece(kit: StringName, size: Vector3, room: StringName, seed: int = 0) -> Node3D:
	# Floor I rooms answer to their style's name (entrance_hall -> entrance)
	if Floor1Art.ROOM_STYLES.has(room):
		room = Floor1Art.ROOM_STYLES[room]
	var root := _holder("Visual")
	match kit:
		&"column":
			if room == &"entrance":
				_add(root, "entrance_column", Transform3D(Basis.from_scale(size / Vector3(1.72, 12.0, 1.72)), Vector3.ZERO))
			elif room == &"hall" or size.y > 10.0:
				_add(root, "hall_column", Transform3D(Basis.from_scale(Vector3(size.x / 1.6, size.y / 14.0, size.z / 1.6)), Vector3.ZERO))
			else:
				_add(root, "column", Transform3D(Basis.from_scale(Vector3(size.x / 0.7, size.y / 6.0, size.z / 0.7)), Vector3.ZERO))
		&"pedestal":
			if size.x < 6.0:
				root.free()
				return null
			_add(root, "trex_pedestal", Transform3D(Basis.from_scale(Vector3(size.x / 12.0, size.y / 1.2, size.z / 6.0)), Vector3.ZERO))
			# on the raised middle panel of both long faces (0.03 m proud)
			for side in [-1.0, 1.0]:
				var yaw := 0.0 if side < 0.0 else PI
				_add(root, "plaque_trex", Transform3D(Basis(Vector3.UP, yaw), Vector3(0.0, 0.64 * size.y / 1.2, side * (size.z * 0.5 + 0.03))))
		&"balcony_post":
			_add(root, "balcony_pier", Transform3D(Basis.from_scale(Vector3(size.x / 0.6, size.y / 5.6, size.z / 0.6)), Vector3.ZERO))
		&"railing":
			_balustrade(root, size.x)
		&"ticket_booth":
			_add(root, "ticket_booth", Transform3D(Basis.from_scale(size / Vector3(4.5, 2.8, 3.5)), Vector3.ZERO))
		&"info_desk":
			_add(root, "info_desk", Transform3D(Basis.from_scale(size / Vector3(8.0, 1.1, 3.0)), Vector3.ZERO))
		&"bench":
			if room == &"hall" or size.x > 2.6:
				_add(root, "bench_hall", Transform3D(Basis.from_scale(size / Vector3(3.0, 0.5, 0.7)), Vector3.ZERO))
			else:
				_add(root, "bench", Transform3D(Basis(Vector3.UP, PI).scaled(size / Vector3(1.6, 0.5, 0.5)), Vector3.ZERO))
		&"fuse_box":
			_add(root, "fuse_box", Transform3D(Basis.from_scale(size / Vector3(0.7, 0.9, 0.3)), Vector3.ZERO))
		&"lockers":
			var n := maxi(1, int(round(size.x / 0.5)))
			var w := size.x / n
			for i in n:
				_add(root, "locker_05m", Transform3D(Basis.from_scale(Vector3(w / 0.5, size.y / 2.0, size.z / 0.5)), Vector3(-size.x * 0.5 + (i + 0.5) * w, 0, 0)))
		&"painting":
			var id := _frame_for(Vector2(size.x, size.y))
			var sets: Array = FRAME_SETS.get(id, [""])
			var pick: String = sets[posmod(seed, sets.size())]
			var inner := Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, -0.01))
			var node := _add(root, id, inner, (id + pick) if pick != "" else "")
			var native: Vector2 = FRAMES.keys()[FRAMES.values().find(id)]
			node.scale = Vector3(size.x / native.x, size.y / native.y, 1.0)
		&"grate":
			for side in [-1.0, 1.0]:
				_add(root, "grate_leaf_3m", Transform3D(Basis.from_scale(Vector3(size.x / 6.0, size.y / 5.0, 1.0)), Vector3(side * size.x * 0.25, 0, 0)))
		&"false_panel":
			var id2 := "false_panel_armory" if room == &"armory" or room == &"shotgun_niche" else "false_panel_hall"
			var native_h := 2.4 if id2 == "false_panel_armory" else 2.2
			_add(root, id2, Transform3D(Basis.from_scale(Vector3(size.x / 2.0, size.y / native_h, 1.0)), Vector3.ZERO))
		&"painting_panel":
			_add(root, "painting_panel", Transform3D(Basis.from_scale(Vector3(size.x / 2.0, size.y / 2.4, 1.0)), Vector3.ZERO))
		&"vent_grille":
			_add(root, "vent_grille", Transform3D(Basis.from_scale(Vector3(size.x / 1.5, size.y / 2.2, size.z / 0.12)), Vector3.ZERO))
		&"skylight":
			_skylight(root, size)
		&"rock":
			var id3 := "rock_a" if posmod(seed, 2) == 0 else "rock_b"
			var native_r := Vector3(2.4, 1.6, 2.0) if id3 == "rock_a" else Vector3(2.2, 1.3, 2.0)
			_add(root, id3, Transform3D(Basis.from_scale(size / native_r), Vector3.ZERO))
		&"grass":
			root.free()
			return null
		&"fence":
			var runs := fill_run(size.x, [2.0, 1.0])
			for m: Array in runs:
				var id4 := "fence_rail_%dm" % int(m[0])
				_add(root, id4, Transform3D(Basis.from_scale(Vector3(m[2], size.y / 0.7, 1.0)), Vector3(-size.x * 0.5 + float(m[1]) + float(m[0]) * float(m[2]) * 0.5, 0, 0)))
			_add(root, "fence_post", Transform3D(Basis.from_scale(Vector3(1.0, size.y / 0.7, 1.0)), Vector3(size.x * 0.5, 0, 0)))
		&"case":
			if size.x >= 1.8:
				# long table vitrines: 2 m modules side by side
				var n := maxi(1, int(round(size.x / 2.0)))
				var w := size.x / n
				for i in n:
					var at := Vector3(-size.x * 0.5 + (i + 0.5) * w, 0, 0)
					_add(root, "case_table", Transform3D(Basis.from_scale(Vector3(w / 2.0, size.y / 1.4, size.z / 1.4)), at))
			else:
				# the stage 1b vitrine faces +Z: turned
				_add(root, "display_case", Transform3D(Basis(Vector3.UP, PI).scaled(size / Vector3(1.06, 1.56, 0.764)), Vector3.ZERO))
		&"crystal_case":
			var case := _add(root, "case_tall", Transform3D(Basis.from_scale(size / Vector3(1.2, 1.8, 1.2)), Vector3.ZERO))
			_solid_glass(case)
		&"crate":
			_add(root, "crate", Transform3D(Basis.from_scale(size), Vector3.ZERO))
		&"desk":
			if size.z > size.x:
				# a writing desk turned along the wall: its front to -X
				_add(root, "desk", Transform3D(Basis(Vector3.UP, PI * 0.5) * Basis.from_scale(Vector3(size.z / 1.6, size.y / 0.78, size.x / 0.8)), Vector3.ZERO))
			else:
				_add(root, "desk", Transform3D(Basis.from_scale(size / Vector3(1.6, 0.78, 0.8)), Vector3.ZERO))
		&"chair":
			_add(root, "chair", Transform3D(Basis.from_scale(Vector3.ONE * size.y), Vector3.ZERO))
		&"shelf":
			var n2 := maxi(1, int(round(size.x / 1.0)))
			var w2 := size.x / n2
			for i in n2:
				_add(root, "shelf_unit", Transform3D(Basis.from_scale(Vector3(w2, size.y / 1.8, size.z / 0.5)), Vector3(-size.x * 0.5 + (i + 0.5) * w2, 0, 0)))
		&"armor_rack":
			_add(root, "armor_stand", Transform3D(Basis.from_scale(Vector3.ONE * size.y / 2.1), Vector3.ZERO))
		&"bust_plinth":
			# a plinth with a portrait bust (marble or bronze), as the gallery's
			# greybox: the bust takes the top 0.6 m
			var shaft := size.y - 0.6
			_add(root, "pedestal", Transform3D(Basis.from_scale(Vector3(size.x / 0.54, shaft / 1.1, size.z / 0.54)), Vector3.ZERO))
			_add(root, "bust", Transform3D(Basis(Vector3.UP, PI), Vector3(0, shaft, 0)), "bust_bronze" if posmod(seed, 3) == 1 else "")
		&"plinth":
			_add(root, "pedestal", Transform3D(Basis.from_scale(size / Vector3(0.54, 1.1, 0.54)), Vector3.ZERO))
		&"sculpture":
			_add(root, "sculpture", Transform3D(Basis.from_scale(Vector3(size.x / 2.2, size.y / 4.46, size.z / 2.2)), Vector3.ZERO))
		&"plaque":
			# a blank brass plate as thick as the piece (the game engraves it)
			_add(root, "plaque_brass", Transform3D(Basis.from_scale(Vector3(size.x / 0.5, size.y / 0.3, size.z / 0.012)), Vector3.ZERO))
		&"cctv_wall":
			var banks := maxi(1, int(round(size.x / 1.54)))
			var bw := size.x / banks
			for i in banks:
				_add(root, "cctv_bank", Transform3D(Basis(Vector3.UP, PI).scaled(Vector3(bw / 1.54, size.y / 1.78, 1.0)), Vector3(-size.x * 0.5 + (i + 0.5) * bw, 0, size.z * 0.5 - 0.01)))
		&"weapon_rack":
			# against a wall: the piece's back (+Z) touches it, the model's back too
			_add(root, "weapon_rack", Transform3D(Basis.from_scale(Vector3(size.x / 2.1, size.y / 2.62, 1.0)), Vector3(0, 0, size.z * 0.5)))
		&"banner":
			# the model hangs from its rod (origin at the top): the piece's base is its hem
			var sets2: Array = ["", "banner_lion", "banner_chevron"]
			_add(root, "banner", Transform3D(Basis.from_scale(Vector3(size.x / 1.51, size.y / 2.77, 1.0)), Vector3(0, size.y * 0.96, 0)), sets2[posmod(seed, sets2.size())])
		&"dead_tree":
			_add(root, "dead_tree", Transform3D(Basis.from_scale(Vector3.ONE * size.y / 5.9), Vector3.ZERO))
		&"sign_gallery", &"sign_armory", &"sign_diorama", &"sign_hall", &"sign_staff":
			_add(root, "sign_room", Transform3D(Basis.from_scale(Vector3(size.x / 2.0, size.y / 0.32, 1.0)), Vector3(0, size.y * 0.5, 0)), SIGNS[kit])
		_:
			if ArtLibrary.KIT_COURT.has(kit):
				# a Floor I court piece named by its model id: scaled to the size
				var native: Vector3 = ArtLibrary.KIT_COURT[kit][0]
				var k := Vector3(size.x / maxf(native.x, 0.01), size.y / maxf(native.y, 0.01), size.z / maxf(native.z, 0.01))
				_add(root, String(kit), Transform3D(Basis.from_scale(k), Vector3.ZERO))
				return root
			if ArtLibrary.KIT_AMERICAS.has(kit):
				# a Floor I Americas piece named by its model id, scaled to the size
				var native_a: Vector3 = ArtLibrary.KIT_AMERICAS[kit][0]
				var ka := Vector3(size.x / maxf(native_a.x, 0.01), size.y / maxf(native_a.y, 0.01),
					size.z / maxf(native_a.z, 0.01))
				_add(root, String(kit), Transform3D(Basis.from_scale(ka), Vector3.ZERO))
				return root
			if ArtLibrary.KIT_ENLIGHTENMENT.has(kit):
				# a Floor I Enlightenment piece named by its model id, scaled to the size
				var native_e: Vector3 = ArtLibrary.KIT_ENLIGHTENMENT[kit][0]
				var ke := Vector3(size.x / maxf(native_e.x, 0.01), size.y / maxf(native_e.y, 0.01),
					size.z / maxf(native_e.z, 0.01))
				_add(root, String(kit), Transform3D(Basis.from_scale(ke), Vector3.ZERO))
				return root
			root.free()
			if FIXTURES.has(kit):
				return fixture(kit)
			return null
	return root


static var _case_glass: StandardMaterial3D = null


## Glass of a vitrine the game can shatter (the crystal's case): plain
## see-through panes as material overrides, the kind NightObjective finds.
static func case_glass() -> StandardMaterial3D:
	if _case_glass == null:
		_case_glass = StandardMaterial3D.new()
		_case_glass.resource_name = "case_glass"
		_case_glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_case_glass.albedo_color = Color(0.78, 0.9, 0.88, 0.07)
		_case_glass.roughness = 0.04
		_case_glass.metallic_specular = 0.7
		_case_glass.rim_enabled = true
		_case_glass.rim = 0.35
		_case_glass.rim_tint = 0.2
	return _case_glass


static func _solid_glass(model_root: Node3D) -> void:
	for view in model_root.find_children("*", "MeshInstance3D", true, false):
		if String(view.name).ends_with("_glass"):
			(view as MeshInstance3D).material_override = case_glass()
			(view as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


static func _frame_for(sz: Vector2) -> String:
	var best := ""
	var best_d := INF
	for k: Vector2 in FRAMES:
		var d := absf(k.x - sz.x) + absf(k.y - sz.y)
		if d < best_d:
			best_d = d
			best = FRAMES[k]
	return best


## A straight stone balustrade of [param length] along X (symmetric), with a
## pedestal at both ends and every 4 m.
static func _balustrade(root: Node3D, length: float) -> void:
	var inner := length - 0.46
	var n_ped := maxi(1, int(round(inner / 4.0)))
	var bay := inner / n_ped
	for k in n_ped + 1:
		var x := -length * 0.5 + 0.23 + k * bay
		_add(root, "balustrade_pedestal", Transform3D(Basis.IDENTITY, Vector3(x, 0, 0)))
		if k == n_ped:
			break
		var holder := _holder("Bay")
		holder.position = Vector3(x + 0.23, 0, 0)
		root.add_child(holder)
		run(holder, "balustrade_", 0.0, bay - 0.46, 0.0)


## Lantern skylight over a well of [param size] (x, z): bays along the long
## side, glazed gables at both ends.
static func _skylight(root: Node3D, size: Vector3) -> void:
	var along_x := size.x > size.z
	var length := size.x if along_x else size.z
	var width := size.z if along_x else size.x
	var yaw := PI * 0.5 if along_x else 0.0
	var basis := Basis(Vector3.UP, yaw)
	var n := maxi(1, int(round(length / 3.0)))
	var bay := length / n
	for i in n:
		var t := -length * 0.5 + (i + 0.5) * bay
		var at := basis * Vector3(0, 0, t)
		_add(root, "skylight_bay_3m", Transform3D(basis.scaled(Vector3(width / 3.0, 1.0, bay / 3.0)), at))
	for end in [-1.0, 1.0]:
		var at2 := basis * Vector3(0, 0, end * length * 0.5)
		var face := Basis(Vector3.UP, yaw + (0.0 if end < 0.0 else PI))
		_add(root, "skylight_gable_3m", Transform3D(face.scaled(Vector3(width / 3.0, 1.0, 1.0)), at2))


## Light fitting of a LevelKit fixture kit id; origin = the light. Floor I
## rooms may fit another model (Floor1Art.fixture: an Egyptian torch for a
## sconce, an oil lamp in the camp, none where the piece carries its lamp).
static func fixture(kit: StringName, room: StringName = &"") -> Node3D:
	if room != &"" and Floor1Art.ROOM_STYLES.has(room):
		var own: Variant = Floor1Art.fixture(kit, room)
		if own is Node3D:
			return own
	if not FIXTURES.has(kit):
		return null
	var entry: Array = FIXTURES[kit]
	var root := _holder("Visual")
	_add(root, String(entry[0]), entry[1])
	return root


# --- stairs --------------------------------------------------------------------

## A grand flight in the stairs frame (StairsSpec.frame(): origin in the
## middle of the bottom front edge, -Z up the flight): marble steps on a
## stone wedge, moulded stringers and raked balustrades on the open sides,
## a newel with a lamp at the foot of each open side. [param open_left] /
## [param open_right] as StairsSpec.rail_left / rail_right.
static func stairs(width: float, rise: float, run_length: float, steps: int, open_left: bool, open_right: bool, room: StringName = &"hall") -> Node3D:
	var root := _holder("Stairs")
	var r := rise / steps
	var t := run_length / steps
	var step_id := "stair_step_4m" if absf(width - 4.0) < 0.6 else "stair_step_1m"
	var native_w := 4.0 if step_id == "stair_step_4m" else 1.0
	var cols := 1 if step_id == "stair_step_4m" else maxi(1, int(round(width / native_w)))
	var cw := width / cols
	for i in steps:
		for c in cols:
			var x := -width * 0.5 + (c + 0.5) * cw
			var xf := Transform3D(Basis.from_scale(Vector3(cw / native_w, r / 0.15, t / 0.4)), Vector3(x, i * r, -i * t))
			_add(root, step_id, xf)
	# the mass under the steps, in the room's stair field (hall: ashlar)
	var wedge := _add(root, "stair_wedge", Transform3D(Basis.from_scale(Vector3(width, rise, run_length)), Vector3.ZERO))
	for view in wedge.find_children("*", "MeshInstance3D", true, false):
		(view as MeshInstance3D).material_override = field(room, &"stair")
	var modules := maxi(1, int(round(run_length / 4.0)))
	var seg := run_length / modules
	for side in [-1.0, 1.0]:
		if (side < 0.0 and not open_left) or (side > 0.0 and not open_right):
			continue
		var x2: float = side * (width * 0.5 + 0.07)
		for k in modules:
			var xf2 := Transform3D(Basis.from_scale(Vector3(1.0, rise / run_length * seg / 1.5, seg / 4.0)), Vector3(x2, k * rise / modules, -k * seg))
			_add(root, "stair_stringer_4m", xf2)
			_add(root, "stair_balustrade_4m", xf2)
		_add(root, "stair_newel", Transform3D(Basis.IDENTITY, Vector3(x2, 0.0, 0.35)))
	return root


# --- passages --------------------------------------------------------------------

## Frames and linings of a passage in its Door frame (origin = middle of the
## passage floor, -Z from room A to room B; face A at +depth/2). Returns
## null when neither room has a frame for this size. A room &"" has no
## frame on its side (it is still greybox). Floor I openings may have their
## own portals ([param opening_id], Floor1Art.passage).
static func passage(width: float, height: float, depth: float, room_a: StringName, room_b: StringName, opening_id: StringName = &"") -> Node3D:
	if Floor1Art.ROOM_STYLES.has(room_a) or Floor1Art.ROOM_STYLES.has(room_b):
		var own: Variant = Floor1Art.passage(width, height, depth, room_a, room_b, opening_id)
		if own is Node3D:
			return own
	var key := ""
	if absf(width - 4.0) < 0.1 and absf(height - 4.5) < 0.1:
		key = "4"
	elif absf(width - 2.0) < 0.1 and absf(height - 2.8) < 0.1:
		key = "2_8"
	elif absf(width - 2.0) < 0.1 and absf(height - 2.6) < 0.1:
		key = "2_6"
	if key == "":
		return null
	var root := _holder("Passage")
	var any := false
	for face in [1.0, -1.0]:
		var room := room_a if face > 0.0 else room_b
		if room == &"":
			continue
		var s := style(room)
		if not s.has("frame_" + key):
			continue
		var id: String = s["frame_" + key]
		var set_id: String = s.get("frame_%s_set" % key, "")
		var yaw := PI if face > 0.0 else 0.0
		_add(root, id, Transform3D(Basis(Vector3.UP, yaw), Vector3(0, 0, face * depth * 0.5)), set_id)
		any = true
		if key == "4" and s.has("reveal_4"):
			_add(root, String(s["reveal_4"]), Transform3D(Basis.from_scale(Vector3(1.0, 1.0, depth / 2.0)), Vector3.ZERO))
	if not any:
		root.free()
		return null
	return root


## One barred leaf of the grate (Door moves each leaf on its own), fitted to
## [param size]: grate_leaf_3m is 3 x 5 m, its bars at x = -1.35 + 0.18 k.
## A Floor I gate in disguise ([param opening_id], Floor1Art.gate_leaf: a
## bookcase that swings aside) has its own leaf; [param side] = the leaf's
## side of the opening (-1 / +1).
static func grate_leaf(size: Vector3, opening_id: StringName = &"", side: float = 1.0) -> Node3D:
	if opening_id != &"":
		var own: Variant = Floor1Art.gate_leaf(opening_id, size, side)
		if own is Node3D:
			return own
	var root := _holder("Visual")
	_add(root, "grate_leaf_3m", Transform3D(Basis.from_scale(Vector3(size.x / 3.0, size.y / 5.0, 1.0)), Vector3.ZERO))
	return root


## A door leaf visual in Door's leaf frame (origin = centre of the leaf's
## base). [param kit] as Door uses it (door_leaf, false_panel, painting_panel,
## vent_grille, grate); [param side] = the sign of the leaf's offset from
## its hinge along X (+1: hinge at -X), [param style] = OpeningSpec.DoorStyle.
static func leaf(kit: StringName, size: Vector3, style_id: int, side: float, face_room: StringName) -> Node3D:
	if kit != &"door_leaf":
		return piece(kit, size, face_room)
	var root := _holder("Visual")
	match style_id:
		OpeningSpec.DoorStyle.DOUBLE_SWING:
			var id := "door_grand_leaf_l" if side > 0.0 else "door_grand_leaf_r"
			_add(root, id, Transform3D(Basis.from_scale(Vector3(size.x / 2.0, size.y / 4.5, size.z / 0.12)), Vector3.ZERO))
		OpeningSpec.DoorStyle.SLIDE:
			_add(root, "door_slide_leaf", Transform3D(Basis.from_scale(Vector3(size.x / 2.0, size.y / 2.8, size.z / 0.12)), Vector3.ZERO))
		_:
			_add(root, "door_staff_leaf", Transform3D(Basis.from_scale(Vector3(size.x / 2.0, size.y / 2.6, size.z / 0.12)), Vector3.ZERO))
	return root
