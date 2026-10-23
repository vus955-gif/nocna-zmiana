extends Node
## "Wycieczka" (design 12): the dressed hub and Egypt of Floor I in the real
## game (stage P2), the Greek and Enlightenment wings and the basement
## (stage P3), the Assyrian and Asian wings (stage P4), the Americas and
## the roof (stage P5), viewpoint by viewpoint, at night, in a blackout and during the Colossus and T-Rex
## fights. Not part of the headless suite.
##   bash tools/run_tour.sh shots [--preset=high] [--only=a,b]
##       1920x1080 screenshots -> tests/_out/tour/<view>[_preset].png and
##       metrics_<preset>.json: per shot the mean luminance (Rec. 709 on the
##       sRGB values, 0..1) and the share of near-black pixels (L < 0.04);
##       DARK when the mean is under DARK_MEAN or the near-black share over
##       DARK_SHARE
##   bash tools/run_tour.sh perf [--preset=high]
##       frame rate at the fifteen heaviest views -> perf_<preset>.json
##   bash tools/run_tour.sh dry
##       headless: builds the floor, checks every viewpoint (in a room, not
##       in a wall, its subject in sight), counts the lamps, shadows and
##       motes the room-graph culling leaves on there -> dry.json
## Silent (Dummy audio). The windowed modes only while nobody uses the PC.

const OUT_DIR := "res://tests/_out/tour/"
const WATCHDOG_SECONDS := 600.0
const PRESETS := {"low": GraphicsQuality.Quality.LOW, "medium": GraphicsQuality.Quality.MEDIUM,
	"high": GraphicsQuality.Quality.HIGH, "ultra": GraphicsQuality.Quality.ULTRA}
## A viewpoint nearer than this (m, across) to a sleeping exhibit before it
## has the exhibit filling its frame (dry: a problem).
const SLOT_CLEARANCE := 1.2
## Brightness alarm: a shot darker than this on average, or with more of
## its pixels near black, is reported DARK.
const DARK_MEAN := 0.06
const DARK_SHARE := 0.55
const NEAR_BLACK := 0.04
## Night views: [camera, look-at].
const VIEWS := {
	"court_from_entrance": [Vector3(0.0, 1.7, 34.0), Vector3(0.0, 6.0, 5.0)],
	"court_wide_sw": [Vector3(-26.0, 1.7, 27.0), Vector3(8.0, 9.0, -6.0)],
	"court_roof_up": [Vector3(-14.0, 1.6, 18.0), Vector3(-20.0, 21.0, 24.0)],
	"court_balcony": [Vector3(-14.8, 8.7, -4.4), Vector3(6.0, 5.0, -18.0)],
	"court_trex": [Vector3(9.0, 1.7, -14.0), Vector3(0.0, 3.5, -23.0)],
	"court_totem": [Vector3(12.0, 1.7, -12.0), Vector3(24.0, 6.0, -24.0)],
	"court_cafe": [Vector3(-12.0, 1.7, -12.0), Vector3(-24.0, 1.5, -24.0)],
	"court_shop": [Vector3(11.0, 1.7, 17.0), Vector3(23.0, 2.0, 23.0)],
	"court_north_portal": [Vector3(0.0, 1.7, -27.0), Vector3(0.0, 5.0, -12.0)],
	"court_stairs": [Vector3(-10.0, 1.7, 22.0), Vector3(-16.5, 4.0, 2.0)],
	"reading_door": [Vector3(0.0, 1.7, -9.5), Vector3(0.0, 2.0, 6.0)],
	"reading_dome": [Vector3(3.0, 1.7, 3.0), Vector3(0.0, 18.0, -2.0)],
	"reading_astrolabe": [Vector3(-6.5, 2.0, -3.0), Vector3(0.0, 2.0, 0.0)],
	"entrance_from_staff": [Vector3(14.5, 1.7, 42.0), Vector3(-6.0, 4.0, 40.0)],
	"entrance_from_gallery": [Vector3(4.0, 8.0, 50.2), Vector3(0.0, 2.0, 36.0)],
	"booth_security": [Vector3(36.5, 1.65, 44.2), Vector3(31.0, 1.2, 47.5)],
	"north_hall": [Vector3(-26.0, 1.7, -34.5), Vector3(20.0, 3.0, -34.5)],
	"egypt_vestibule": [Vector3(-33.5, 1.7, 27.5), Vector3(-43.0, 1.5, 25.5)],
	"egypt_gallery_long": [Vector3(-42.0, 1.7, 27.0), Vector3(-42.0, 3.0, -10.0)],
	"egypt_camp": [Vector3(-40.0, 1.7, 7.5), Vector3(-43.5, 1.0, 2.0)],
	"egypt_colossi_row": [Vector3(-38.6, 1.7, 16.0), Vector3(-48.0, 5.0, -6.0)],
	"egypt_well_up": [Vector3(-40.5, 1.6, 9.5), Vector3(-42.0, 11.5, 8.0)],
	"egypt_colossus_hall": [Vector3(-42.5, 1.7, -15.5), Vector3(-42.5, 6.0, -32.0)],
	"egypt_tombs": [Vector3(-52.0, 1.6, 9.0), Vector3(-61.0, 1.0, 11.0)],
	"egypt_tomb_hall": [Vector3(-52.0, 1.6, 28.0), Vector3(-57.0, 0.8, 19.0)],
	"egypt_tomb_passage": [Vector3(-51.8, 1.6, -0.8), Vector3(-54.4, 1.1, -6.6)],
	"egypt_conservator": [Vector3(-57.6, 1.6, 6.4), Vector3(-61.5, 1.0, 1.5)],
	# the basement (stage P3; y = -6, eye 1.7 m over the floor)
	"basement_ring_north": [Vector3(-27.0, -4.3, -36.25), Vector3(27.0, -4.3, -36.25)],
	"basement_wing_door": [Vector3(-27.5, -4.3, -5.5), Vector3(-30.4, -4.0, -11.5)],
	"basement_boiler_fires": [Vector3(2.0, -4.3, -19.5), Vector3(-6.25, -5.2, -25.0)],
	"basement_gantry": [Vector3(-12.5, -1.5, -33.0), Vector3(12.5, -2.0, -33.0)],
	"basement_crossing": [Vector3(0.0, -4.3, -3.5), Vector3(0.0, -2.5, -16.0)],
	"basement_workshop": [Vector3(0.0, -4.3, 8.3), Vector3(-4.0, -4.9, 1.5)],
	"basement_reserve_aisle": [Vector3(-9.0, -4.3, -1.0), Vector3(-24.0, -4.3, -1.0)],
	"basement_switchboard": [Vector3(20.25, -4.3, -22.0), Vector3(20.25, -4.6, -33.5)],
	"basement_tunnel": [Vector3(-33.0, -4.3, -35.0), Vector3(-53.0, -4.5, -35.0)],
	# stage P3: Greece (white marble, the silver moon through the skylights)
	"greece_nereid_entry": [Vector3(-65.5, 1.7, 12.0), Vector3(-82.0, 7.0, 12.0)],
	"greece_nereid_porch": [Vector3(-80.5, 6.2, 0.5), Vector3(-80.0, 6.0, 12.0)],
	"greece_nereid_up": [Vector3(-70.0, 1.6, 6.0), Vector3(-80.0, 11.5, 12.0)],
	"greece_bassae": [Vector3(-89.0, 1.7, 12.0), Vector3(-102.0, 5.5, 0.0)],
	"greece_bassae_frieze": [Vector3(-92.0, 6.2, 0.0), Vector3(-104.0, 6.1, -1.9)],
	"greece_vases": [Vector3(-88.5, 1.7, 18.5), Vector3(-98.0, 1.2, 27.0)],
	"greece_metopes": [Vector3(-70.0, 1.7, 36.0), Vector3(-83.0, 3.5, 27.0)],
	"greece_parthenon_long": [Vector3(-62.5, 1.7, 43.0), Vector3(-26.0, 3.0, 43.0)],
	"greece_parthenon_east": [Vector3(-35.0, 1.7, 40.0), Vector3(-27.5, 2.2, 43.0)],
	"greece_parthenon_frieze": [Vector3(-49.0, 1.7, 36.0), Vector3(-30.0, 2.0, 34.2)],
	"greece_parthenon_up": [Vector3(-49.0, 1.6, 40.0), Vector3(-49.0, 12.0, 43.0)],
	"greece_cast_store": [Vector3(-80.0, 1.6, 47.5), Vector3(-82.0, 1.0, 51.5)],
	# stage P3: the Enlightenment (warm green lamps, long shadows, book dust)
	"library_from_court": [Vector3(32.0, 1.7, 0.0), Vector3(38.0, 3.0, -30.0)],
	"library_axis": [Vector3(38.0, 1.7, -20.5), Vector3(38.0, 3.0, 30.0)],
	"library_gallery_walk": [Vector3(32.6, 5.7, 10.4), Vector3(33.5, 5.5, -25.0)],
	"library_aisle": [Vector3(32.4, 1.7, 22.0), Vector3(32.4, 1.5, -20.0)],
	"library_wall": [Vector3(34.8, 1.7, -15.5), Vector3(31.0, 2.5, -19.0)],
	"library_up": [Vector3(38.0, 1.6, -1.0), Vector3(38.0, 10.0, 0.0)],
	"library_stairs": [Vector3(38.0, 1.7, 15.5), Vector3(38.0, 3.0, 30.0)],
	"library_rifle": [Vector3(56.0, 1.7, 0.0), Vector3(64.5, 1.3, 0.0)],
	"cabinet_dioramas": [Vector3(55.0, 1.7, 1.5), Vector3(51.0, 0.8, 7.0)],
	"clocks": [Vector3(58.0, 1.7, -3.5), Vector3(59.5, 2.5, -12.0)],
	"portraits": [Vector3(58.0, 1.7, 17.5), Vector3(64.9, 2.1, 27.0)],
	"librarian": [Vector3(46.5, 1.6, -3.5), Vector3(50.4, 0.9, -7.0)],
	"planetarium": [Vector3(47.0, 1.7, -19.0), Vector3(55.25, 5.0, -26.5)],
	"planetarium_observers": [Vector3(51.5, 11.77, -17.3), Vector3(55.25, 6.0, -26.5)],
	# stage P4: Assyria (alabaster and torches, the moon over the courtyard)
	"assyria_gate_hall": [Vector3(-55.0, 1.7, -50.0), Vector3(-51.0, 5.0, -40.0)],
	"assyria_gate_lamassu": [Vector3(-50.5, 1.7, -46.0), Vector3(-48.7, 3.5, -41.5)],
	"assyria_axis_obelisk": [Vector3(-51.0, 1.7, -53.0), Vector3(-51.0, 3.0, -76.5)],
	"assyria_balawat_doors": [Vector3(-58.0, 1.7, -66.0), Vector3(-47.0, 2.5, -64.0)],
	"assyria_courtyard_moon": [Vector3(-79.0, 1.7, -56.0), Vector3(-78.75, 3.0, -74.0)],
	"assyria_courtyard_wide": [Vector3(-66.0, 1.7, -56.0), Vector3(-85.0, 6.0, -74.0)],
	"assyria_courtyard_up": [Vector3(-78.0, 1.6, -66.0), Vector3(-82.0, 15.5, -62.0)],
	"assyria_nimrud_long": [Vector3(-65.0, 1.7, -43.5), Vector3(-99.0, 2.5, -44.0)],
	"assyria_nimrud_reliefs": [Vector3(-85.0, 1.7, -43.0), Vector3(-95.0, 1.8, -52.4)],
	"assyria_scaffold": [Vector3(-92.0, 1.7, -45.0), Vector3(-99.0, 1.5, -46.0)],
	"assyria_lions_gallery": [Vector3(-94.5, 1.7, -36.5), Vector3(-84.0, -1.0, -12.0)],
	# (at the pit's south end between the slots: not on a relief warrior's slot)
	"assyria_lions_pit": [Vector3(-88.0, -1.3, -35.2), Vector3(-86.5, -1.5, -12.0)],
	"assyria_library": [Vector3(-77.5, 1.7, -30.5), Vector3(-59.5, 1.4, -30.5)],
	"assyria_freight": [Vector3(-57.0, -4.3, -35.5), Vector3(-76.0, -3.0, -36.25)],
	# stage P4: Asia (lanterns, lacquer, the moon over the garden)
	"asia_china_buddha": [Vector3(13.5, 1.7, -41.0), Vector3(13.5, 6.0, -57.0)],
	"asia_china_columns": [Vector3(6.0, 1.7, -41.0), Vector3(19.5, 7.0, -53.0)],
	"asia_porcelain": [Vector3(25.5, 1.7, -59.5), Vector3(33.0, 1.5, -50.0)],
	"asia_korea_hwacha": [Vector3(38.5, 1.7, -48.0), Vector3(47.4, 1.2, -51.0)],
	"asia_korea_bell": [Vector3(41.0, 1.7, -52.0), Vector3(52.0, 3.0, -57.5)],
	"asia_armor_rows": [Vector3(32.0, 1.7, -65.0), Vector3(45.0, 1.8, -80.0)],
	"asia_armor_shoji": [Vector3(47.0, 1.7, -70.0), Vector3(55.9, 1.5, -69.0)],
	"asia_garden_entry": [Vector3(8.0, 1.7, -64.5), Vector3(17.5, 2.0, -75.0)],
	"asia_garden_teahouse": [Vector3(22.0, 1.7, -70.0), Vector3(12.5, 3.0, -80.0)],
	"asia_garden_cherry": [Vector3(14.0, 1.7, -72.0), Vector3(23.0, 5.0, -76.5)],
	"asia_garden_pond": [Vector3(11.0, 1.7, -67.0), Vector3(8.5, 0.5, -73.0)],
	"asia_garden_up": [Vector3(18.0, 1.6, -74.0), Vector3(18.0, 15.0, -70.0)],
	# the garden's walls: the tsuiji, the court front over it, the pines and the bamboo
	"asia_garden_south": [Vector3(19.0, 1.7, -80.0), Vector3(17.0, 6.0, -62.5)],
	"asia_garden_east": [Vector3(16.0, 1.7, -70.0), Vector3(30.0, 5.5, -72.5)],
	"asia_garden_north": [Vector3(17.0, 1.7, -68.0), Vector3(19.5, 5.0, -86.0)],
	"asia_teahouse": [Vector3(10.5, 1.6, -80.0), Vector3(5.0, 1.2, -83.0)],
	"asia_service": [Vector3(26.0, 1.7, -41.0), Vector3(26.0, 0.0, -51.0)],
	# stage P5: the Americas (fire from below, smoke, the temple's moon)
	"americas_north_shutter": [Vector3(-17.0, 1.7, -40.5), Vector3(-8.0, 3.0, -53.0)],
	"americas_north_bison": [Vector3(-16.5, 1.7, -46.0), Vector3(-13.0, 1.5, -50.0)],
	"americas_totems_long": [Vector3(-26.5, 1.7, -54.5), Vector3(-30.0, 6.0, -71.5)],
	"americas_totems_up": [Vector3(-31.5, 1.6, -60.0), Vector3(-29.75, 10.0, -69.5)],
	"americas_moai_head": [Vector3(-40.5, 1.7, -64.0), Vector3(-40.5, 4.1, -57.0)],
	"americas_moai_mosaic": [Vector3(-38.5, 1.7, -67.5), Vector3(-35.8, 1.4, -70.5)],
	"americas_moai_ring": [Vector3(-44.5, 1.7, -54.0), Vector3(-40.5, 1.9, -55.4)],
	"americas_moai_wide": [Vector3(-40.0, 1.7, -71.0), Vector3(-40.5, 3.0, -56.6)],
	"americas_pacific_whaling": [Vector3(-38.0, 1.7, -76.0), Vector3(-40.5, 1.6, -84.5)],
	"americas_pacific_canoe": [Vector3(-40.0, 1.7, -77.0), Vector3(-27.75, 6.0, -79.0)],
	"americas_pit_floor": [Vector3(-29.5, -4.3, -81.5), Vector3(-27.75, 5.6, -79.0)],
	"americas_temple_entry": [Vector3(-22.5, 1.7, -79.0), Vector3(-14.25, 3.0, -72.25)],
	"americas_temple_disc": [Vector3(-9.0, 1.7, -82.0), Vector3(-4.6, 4.75, -78.0)],
	"americas_temple_shrine": [Vector3(-14.25, 1.7, -85.0), Vector3(-12.0, 4.0, -72.25)],
	"americas_temple_t1": [Vector3(-19.0, 3.2, -77.0), Vector3(-9.5, 2.5, -68.0)],
	"americas_temple_up": [Vector3(-15.7, 4.6, -73.0), Vector3(-14.5, 11.5, -72.25)],
	"americas_temple_wide": [Vector3(-6.0, 1.7, -60.0), Vector3(-16.0, 4.0, -78.0)],
	"americas_tower": [Vector3(-27.5, -4.3, -40.5), Vector3(-25.5, -1.0, -50.0)],
	# stage P5: the roof (the moon on the lead, the court's glow through the glass)
	"roof_tower_top": [Vector3(35.5, 24.2, 48.0), Vector3(35.5, 23.8, 44.0)],
	"roof_plant_deck": [Vector3(33.5, 24.2, 42.0), Vector3(24.0, 25.0, 38.0)],
	"roof_bridge": [Vector3(26.5, 24.2, 34.0), Vector3(8.0, 26.0, 12.0)],
	"roof_dome": [Vector3(0.0, 24.2, -20.0), Vector3(0.0, 27.0, 0.0)],
	"roof_north_glass": [Vector3(-0.8, 24.2, -21.0), Vector3(-8.0, 20.0, -23.0)],
	"roof_gutter_east": [Vector3(28.25, 24.2, 20.0), Vector3(28.25, 23.5, -20.0)],
	"roof_shed": [Vector3(-25.8, 24.1, -25.8), Vector3(-29.0, 23.2, -28.5)],
	"roof_loft": [Vector3(21.0, 24.1, 40.25), Vector3(19.5, 23.2, 36.6)],
	"roof_night_wide": [Vector3(-26.0, 24.2, 26.0), Vector3(10.0, 25.5, -10.0)],
	# the voice (plan 2026-10-19-glos-g2-kwestie): the System's loudspeakers, the audio-guide stands
	"voice_court_south": [Vector3(-14.0, 1.7, 21.0), Vector3(-14.0, 3.6, 29.85)],
	"voice_court_north": [Vector3(14.0, 1.7, -21.0), Vector3(14.0, 3.6, -29.85)],
	"voice_entrance": [Vector3(-8.0, 1.7, 39.0), Vector3(-8.0, 3.6, 31.15)],
	"voice_north_hall": [Vector3(-12.5, 1.7, -36.5), Vector3(-12.5, 3.5, -31.15)],
	"voice_assyria_gate": [Vector3(-60.5, 1.7, -50.0), Vector3(-56.5, 2.2, -40.0)],
	"voice_greece_nereid": [Vector3(-72.0, 1.7, 6.0), Vector3(-64.15, 3.5, 6.0)],
	"voice_library": [Vector3(40.0, 1.7, 0.0), Vector3(31.15, 7.5, 0.0)],
	"voice_asia_shutter": [Vector3(10.0, 1.7, -45.6), Vector3(8.0, 3.5, -39.15)],
	"voice_americas_shutter": [Vector3(-12.0, 1.7, -48.0), Vector3(-10.0, 3.3, -39.15)],
	"voice_stand_rosetta": [Vector3(-37.6, 1.6, 23.0), Vector3(-41.0, 0.8, 24.3)],
	"voice_stand_ramesses": [Vector3(-40.5, 1.6, 17.5), Vector3(-37.5, 0.8, 12.5)],
	"voice_stand_lamassu": [Vector3(-60.0, 1.6, -42.0), Vector3(-55.0, 0.8, -41.0)],
	"voice_stand_flood": [Vector3(-58.8, 1.6, -36.5), Vector3(-58.5, 0.8, -31.5)],
	"voice_stand_metopes": [Vector3(-81.2, 1.6, 30.0), Vector3(-83.0, 1.2, 38.0)],
	"voice_stand_clocks": [Vector3(60.5, 1.6, -2.6), Vector3(61.2, 0.8, -7.5)],
	"voice_stand_buddha": [Vector3(18.8, 1.6, -47.0), Vector3(16.0, 1.5, -55.0)],
	"voice_stand_armour": [Vector3(40.5, 1.6, -66.0), Vector3(40.5, 0.8, -73.0)],
	"voice_stand_totems": [Vector3(-25.0, 1.6, -54.0), Vector3(-26.5, 0.8, -58.8)],
	"voice_stand_moai": [Vector3(-38.5, 1.6, -65.5), Vector3(-39.5, 1.5, -58.0)],
	"voice_stand_astrolabe": [Vector3(0.0, 1.6, -9.0), Vector3(0.0, 0.8, -2.0)],
	"voice_stand_trex": [Vector3(1.2, 8.6, -13.2), Vector3(4.6, 7.6, -14.5)],
}
## Views shot again in a blackout (the guard's flashlight on).
const BLACKOUT_VIEWS := {
	"blackout_court": [Vector3(0.0, 1.7, 25.0), Vector3(0.0, 6.0, 0.0)],
	"blackout_gallery": [Vector3(-42.0, 1.7, 18.0), Vector3(-42.0, 3.0, -8.0)],
	# (from the Metope room through the arena's mouth: in the arena the guard wakes the Centaur)
	"blackout_parthenon": [Vector3(-66.0, 1.7, 43.0), Vector3(-30.0, 3.0, 43.0)],
	"blackout_library": [Vector3(35.0, 1.7, 30.0), Vector3(38.0, 2.0, 0.0)],
	"blackout_courtyard": [Vector3(-66.0, 1.7, -56.0), Vector3(-85.0, 6.0, -74.0)],
	"blackout_china": [Vector3(13.5, 1.7, -41.0), Vector3(13.5, 6.0, -57.0)],
	"blackout_temple": [Vector3(-6.0, 1.7, -60.0), Vector3(-16.0, 4.0, -78.0)],
}
## The heaviest views (perf).
const PERF_VIEWS: Array[String] = ["court_from_entrance", "court_wide_sw", "court_balcony", "reading_door",
	"egypt_gallery_long", "egypt_colossi_row", "egypt_colossus_hall", "entrance_from_staff",
	"greece_parthenon_long", "greece_nereid_entry", "library_from_court", "library_gallery_walk",
	"assyria_nimrud_long", "asia_china_buddha", "asia_garden_entry", "americas_temple_entry", "roof_dome"]

var museum: Museum
var camera: Camera3D
var _mode := "shots"
var _preset := "high"
var _only: PackedStringArray = []
## Views of this run only (--view=label@x,y,z@tx,ty,tz, repeatable): a
## close look at one spot (QA: the collision overlay) without a table entry.
var _extra := {}
var _metrics: Array = []
var _build_ms: int = 0
var _failures: int = 0


func _ready() -> void:
	get_tree().create_timer(WATCHDOG_SECONDS, true, false, true).timeout.connect(_on_watchdog)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--mode="):
			_mode = arg.trim_prefix("--mode=")
		elif arg.begins_with("--preset="):
			_preset = arg.trim_prefix("--preset=")
		elif arg.begins_with("--only="):
			_only = arg.trim_prefix("--only=").split(",", false)
		elif arg.begins_with("--view="):
			var bits := arg.trim_prefix("--view=").split("@")
			if bits.size() == 3:
				var at := bits[1].split_floats(",")
				var to := bits[2].split_floats(",")
				if at.size() == 3 and to.size() == 3:
					_extra[bits[0]] = [Vector3(at[0], at[1], at[2]), Vector3(to[0], to[1], to[2])]
					_only.append(bits[0])
		elif arg == "--washes=off":
			Floor1LightRecipe.washes_enabled = false   # (the light pass's floor washes off: perf before / after)
	Museum.level_id = &"floor1"
	MuseumFloorLevel.dress_default = true
	GameInput.capture_allowed = false
	if _mode != "dry":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(Vector2i(1920, 1080))
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		Engine.max_fps = 0
	Settings.set_value(&"graphics_quality", PRESETS.get(_preset, GraphicsQuality.Quality.HIGH), false)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var ignore := FileAccess.open(ProjectSettings.globalize_path("res://tests/_out/.gdignore"), FileAccess.WRITE)
	if ignore != null:
		ignore.close()
	camera = Camera3D.new()
	camera.fov = 72.0
	camera.near = 0.05
	camera.far = 300.0
	add_child(camera)
	await _open()
	match _mode:
		"perf":
			await _perf()
		"dry":
			_dry()
		_:
			await _shots()
	var file := FileAccess.open(OUT_DIR.path_join("%s_%s.json" % ["dry" if _mode == "dry" else "metrics", _preset]), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"preset": _preset, "build_ms": _build_ms, "shots": _metrics}, "  "))
		file.close()
	Sfx.quit_cleanly(1 if _failures > 0 else 0)


func _on_watchdog() -> void:
	print("MISSED: the tour did not finish in time")
	Sfx.quit_cleanly(1)


func _wanted(label: String) -> bool:
	return _only.is_empty() or _only.has(label)


## A new game on night 1 (no modifier) in Floor I with the art.
func _open() -> void:
	GameState.new_game()
	GameState.night = 1
	RunState.reset()
	var started := Time.get_ticks_msec()
	museum = (load(SceneFlow.MUSEUM) as PackedScene).instantiate() as Museum
	add_child(museum)
	_build_ms = Time.get_ticks_msec() - started
	print("museum built in %d ms (floor I level %d ms, navigation %d ms)" % [_build_ms, museum.floor_level.build_msec, museum.floor_level.bake_msec])
	museum.player.health.max_health = 1000000.0
	museum.player.health.heal(1000000.0)
	await _frames(2)


func _shots() -> void:
	await _seconds(2.5)   # shaders, SDFGI, fog history, probes
	for label: String in VIEWS:
		if _wanted(label):
			await _shot(label, VIEWS[label][0], VIEWS[label][1], 45)
	for label: String in _extra:
		await _shot(label, _extra[label][0], _extra[label][1], 45)
	if _wanted("colossus_awake"):
		await _colossus()
	if _wanted("trex_awake"):
		await _trex()
	var dark := false
	for label: String in BLACKOUT_VIEWS:
		dark = dark or _wanted(label)
	if dark:
		NightModifiers.apply(museum.floor_level, &"blackout", museum.run)
		museum.player.set_flashlight(true)
		await _seconds(1.0)
		for label: String in BLACKOUT_VIEWS:
			if _wanted(label):
				await _guard_shot(label, BLACKOUT_VIEWS[label][0], BLACKOUT_VIEWS[label][1])


## The Colossus wakes as the guard walks into his hall; the shot from
## behind the guard.
func _colossus() -> void:
	var keeper := museum.floor_game.guardians
	var colossus: Guardian = keeper.guardians.get(&"colossus")
	if colossus == null:
		print("tour: no Colossus")
		return
	var at := colossus.global_position - colossus.global_basis.z * 12.0
	museum.player.global_position = at + Vector3.UP * 0.05
	await _seconds(4.0)
	var eye := at + Vector3.UP * 1.7 - (colossus.global_position - at).normalized() * 4.0 + Vector3.UP * 1.5
	await _shot("colossus_awake", eye, colossus.global_position + Vector3.UP * 5.0, 0)
	museum.player.global_position = Vector3(33.0, 0.1, 45.5)   # back to the booth: he calms down
	await _seconds(1.0)


## The T-Rex awake on his pedestal as if the crystal had reached him.
func _trex() -> void:
	var finale := museum.floor_game.finale
	if finale == null or not is_instance_valid(finale.boss):
		print("tour: no T-Rex")
		return
	museum.player.global_position = Vector3(10.0, 0.1, -8.0)
	finale.boss.wake()
	if finale.has_method(&"_on_boss_phase"):
		finale.call(&"_on_boss_phase", 1)
	await _seconds(4.0)
	var subject := finale.boss.global_position + Vector3.UP * 3.0
	await _shot("trex_awake", Vector3(14.0, 2.5, -9.0), subject, 0)


## Frame rates at the heaviest views (camera sweeping a little).
func _perf() -> void:
	await _seconds(2.5)
	var result := {"preset": _preset, "window": str(DisplayServer.window_get_size()), "build_ms": _build_ms,
		"adapter": RenderingServer.get_video_adapter_name(), "views": {}}
	for label in PERF_VIEWS:
		if not _wanted(label):
			continue
		_place(VIEWS[label][0], VIEWS[label][1])
		await _frames(40)
		result["views"][label] = await _measure(4.0, label)
	# the fights: a guardian awake in front of the guard, seen through his eyes
	for id: StringName in [&"colossus", &"general", &"lamassu"]:
		var label := "fight_%s" % id
		if _wanted(label):
			var guardian: Guardian = museum.floor_game.guardians.guardians.get(id) if museum.floor_game != null else null
			if guardian != null:
				result["views"][label] = await _perf_fight(guardian, label)
	if _wanted("fight_trex") and museum.floor_game != null and museum.floor_game.finale != null and is_instance_valid(museum.floor_game.finale.boss):
		var finale := museum.floor_game.finale
		museum.player.global_position = Vector3(10.0, 0.1, -8.0)
		finale.boss.wake()
		if finale.has_method(&"_on_boss_phase"):
			finale.call(&"_on_boss_phase", 1)
		await _seconds(3.0)
		_place(Vector3(14.0, 2.5, -9.0), finale.boss.global_position + Vector3.UP * 3.0)
		await _frames(20)
		result["views"]["fight_trex"] = await _measure(4.0, "fight_trex")
	# the F3 overlay itself over the court (its layout at 1920x1080), numbers then systems
	if _wanted("f3_overlay") and PerfOverlay.allowed():
		museum.player.global_position = Vector3(33.0, 0.1, 45.5)
		_place(VIEWS["court_from_entrance"][0], VIEWS["court_from_entrance"][1])
		PerfOverlay.set_mode(PerfOverlay.Mode.NUMBERS)
		await _seconds(1.5)
		await _capture("f3_numbers_court")
		PerfOverlay.set_mode(PerfOverlay.Mode.SYSTEMS)
		await _seconds(2.5)
		await _capture("f3_systems_court")
		PerfOverlay.set_mode(PerfOverlay.Mode.OFF)
	print("tour perf: ", JSON.stringify(result))
	var file := FileAccess.open(OUT_DIR.path_join("perf_%s.json" % _preset), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(result, "  "))
		file.close()


## [param guardian] woken with the guard 10 m in front of him; measured
## through the guard's eyes (his gun, the HUD and the guardian's bar up),
## then calmed and the guard back in the booth.
func _perf_fight(guardian: Guardian, label: String) -> Dictionary:
	var ahead := -guardian.global_basis.z
	ahead.y = 0.0
	var at := guardian.global_position + ahead.normalized() * 10.0
	museum.player.global_position = Vector3(at.x, guardian.global_position.y + 0.1, at.z)
	var eye := museum.player.global_position + Vector3.UP * museum.player.eye_height
	var aim := guardian.global_position + Vector3.UP * 2.0 - eye
	museum.player.head.rotation = Vector3(atan2(aim.y, Vector2(aim.x, aim.z).length()), atan2(-aim.x, -aim.z), 0.0)
	museum.player.camera.current = true
	if not guardian.is_fighting():
		guardian.wake()
	await _seconds(2.5)
	var out := await _measure_eyes(4.0, label)
	out["fighting"] = guardian.is_fighting()
	museum.player.global_position = Vector3(33.0, 0.1, 45.5)
	if guardian.is_fighting():
		guardian.reset_fight()
	await _seconds(1.0)
	camera.current = true
	return out


## _measure through the guard's own camera (it stays where the fight put it).
func _measure_eyes(seconds: float, label: String) -> Dictionary:
	var swap := camera
	camera = museum.player.camera
	var base := camera.rotation
	var out := await _measure(seconds, label)
	camera.rotation = base
	camera = swap
	return out


func _measure(seconds: float, label: String) -> Dictionary:
	var base := camera.rotation
	var start := Time.get_ticks_usec()
	var last := start
	var frames := 0
	var times: Array[float] = []
	# the renderer's own CPU / GPU time per frame (what the F3 overlay shows)
	var gpu: Array[float] = []
	var render_cpu: Array[float] = []
	PerfStats.measure_render(get_viewport(), true)
	while Time.get_ticks_usec() - start < int(seconds * 1000000.0):
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		times.append((now - last) / 1000.0)
		last = now
		frames += 1
		var rendered := PerfStats.render_times(get_viewport())
		if rendered.y > 0.0:
			gpu.append(rendered.y)
		if rendered.x > 0.0:
			render_cpu.append(rendered.x)
		museum.player.health.heal(1000000.0)
		camera.rotation.y = base.y + sin((now - start) / 1000000.0 * 0.8) * 0.35
	times.sort()
	gpu.sort()
	render_cpu.sort()
	var elapsed := (Time.get_ticks_usec() - start) / 1000000.0
	var lamps := PerfStats.lights(get_tree())
	var out := {
		"average_fps": frames / elapsed,
		"median_frame_ms": times[times.size() / 2] if not times.is_empty() else 0.0,
		"gpu_median_ms": gpu[gpu.size() / 2] if not gpu.is_empty() else 0.0,
		"gpu_p95_ms": gpu[int(gpu.size() * 0.95)] if not gpu.is_empty() else 0.0,
		"render_cpu_median_ms": render_cpu[render_cpu.size() / 2] if not render_cpu.is_empty() else 0.0,
		"lamps_on": lamps.get("lamps_on", 0), "shadows_on": lamps.get("shadows_on", 0), "lamps": lamps.get("lamps", 0),
		"p99_frame_ms": times[int(times.size() * 0.99)] if not times.is_empty() else 0.0,
		"draw_calls": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
		"objects": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME),
		"primitives": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),
	}
	print("%s [%s]: %.0f FPS (median %.1f ms, p99 %.1f ms), GPU %.1f ms (p95 %.1f), render CPU %.1f ms, %d draw calls, %d objects, %d primitives, lamps %d (%d shadows) of %d" % [label, _preset,
			out["average_fps"], out["median_frame_ms"], out["p99_frame_ms"], out["gpu_median_ms"], out["gpu_p95_ms"], out["render_cpu_median_ms"],
			out["draw_calls"], out["objects"], out["primitives"], out["lamps_on"], out["shadows_on"], out["lamps"]])
	return out


## Headless: every viewpoint inside a room and out of the walls, its
## subject in sight, the lamps / shadows / motes the culling keeps there.
func _dry() -> void:
	var level := museum.floor_level
	var space := get_viewport().find_world_3d().direct_space_state
	var all := VIEWS.duplicate()
	all.merge(BLACKOUT_VIEWS)
	for label: String in all:
		if not _wanted(label):
			continue
		var from: Vector3 = all[label][0]
		var at: Vector3 = all[label][1]
		var room := level.room_at(from)
		var problems: Array[String] = []
		if room == &"":
			problems.append("camera outside every room")
		var point := PhysicsPointQueryParameters3D.new()
		point.position = from
		point.collision_mask = Layers.WORLD
		if not space.intersect_point(point).is_empty():
			problems.append("camera inside a wall")
		var ray := PhysicsRayQueryParameters3D.create(from, at, Layers.WORLD)
		var hit := space.intersect_ray(ray)
		var clear := from.distance_to(at) if hit.is_empty() else from.distance_to(hit["position"])
		if clear < minf(3.0, from.distance_to(at) * 0.5):
			problems.append("subject hidden %.1f m ahead" % clear)
		# not right before a sleeping exhibit's slot (any night's: it would
		# fill the frame)
		var ahead := Vector2(at.x - from.x, at.z - from.z).normalized()
		for slot in level.layout.spawn_slots:
			if not slot.dormant or slot.patrol != &"" or slot.room != room:
				continue
			var flat := Vector2(slot.position.x - from.x, slot.position.z - from.z)
			var across := flat.length()
			if across < SLOT_CLEARANCE and flat.dot(ahead) > 0.0 and absf(slot.position.y + 1.0 - from.y) < 2.0:
				problems.append("%.1f m before an exhibit's slot at %s (%s)" % [across, slot.position, slot.kinds])
				break
		# the guard of a blackout view wakes no guardian (Guardian._should_wake)
		if BLACKOUT_VIEWS.has(label):
			for guardian in _guardians():
				if guardian.arena_room != room or guardian.state != Guardian.State.DORMANT:
					continue
				var feet := Vector2(from.x, from.z)
				var post := Vector2(guardian.global_position.x, guardian.global_position.z)
				var line := Vector2(guardian.wake_point.x, guardian.wake_point.z)
				if guardian.wake_point == Vector3.INF or feet.distance_to(line) <= Guardian.WAKE_REACH or feet.distance_to(post) <= line.distance_to(post):
					problems.append("the guard here wakes %s" % guardian.guardian_id)
		var near := level.culler.update_from(from) if level.culler != null else {}
		var lamps := 0
		var shadows := 0
		var motes := 0
		for node in level.lights.get_children():
			var node_room: StringName = node.get_meta(&"room", &"")
			if not near.has(node_room):
				continue
			if node is Light3D and not node is DirectionalLight3D:
				lamps += 1
				if (node as Light3D).shadow_enabled and (node as Node3D).global_position.distance_to(from) < 50.0:
					shadows += 1
			elif node is GPUParticles3D:
				motes += (node as GPUParticles3D).amount
		var entry := {"view": label, "room": room, "near_rooms": near.size(), "lamps_on": lamps, "shadows_near": shadows,
			"motes": motes, "clear_m": snappedf(clear, 0.1), "problems": problems}
		_metrics.append(entry)
		print("%-24s %-22s rooms %2d  lamps %3d  shadows %2d  motes %4d  %s" % [label, room, near.size(), lamps, shadows, motes, "OK" if problems.is_empty() else "; ".join(problems)])
		if not problems.is_empty():
			_failures += 1
	print("tour dry: %d views, %d with problems, museum built in %d ms" % [_metrics.size(), _failures, _build_ms])


func _place(from: Vector3, at: Vector3) -> void:
	camera.global_position = from
	camera.look_at(at, Vector3.UP)
	camera.reset_physics_interpolation()
	camera.current = true


func _shot(label: String, from: Vector3, at: Vector3, settle: int = 30) -> void:
	_place(from, at)
	museum.hud.visible = false
	museum.player.weapons.visible = false   # (his first-person gun would float in this camera's view)
	await _frames(settle)
	await _capture(label)
	museum.hud.visible = true
	museum.player.weapons.visible = true


## The guard's own view (his flashlight on) without the HUD (a guardian
## woken earlier in the tour would hang its bar over every later shot); a
## guardian he woke after all goes back to sleep.
func _guard_shot(label: String, from: Vector3, at: Vector3) -> void:
	museum.player.global_position = from
	var eye := from + Vector3.UP * museum.player.eye_height
	var aim := at - eye
	museum.player.head.rotation = Vector3(atan2(aim.y, Vector2(aim.x, aim.z).length()), atan2(-aim.x, -aim.z), 0.0)
	museum.player.camera.current = true
	museum.hud.visible = false
	await _frames(40)
	await _capture(label)
	museum.hud.visible = true
	for guardian: Guardian in _guardians():
		if guardian.is_fighting():
			guardian.reset_fight()


## The wing guardians standing in the floor.
func _guardians() -> Array[Guardian]:
	var out: Array[Guardian] = []
	if museum.floor_game == null or museum.floor_game.guardians == null:
		return out
	for guardian: Variant in museum.floor_game.guardians.guardians.values():
		if is_instance_valid(guardian):
			out.append(guardian as Guardian)
	return out


func _capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var suffix := "" if _preset == "high" else "_" + _preset
	var path := OUT_DIR.path_join("%s%s.png" % [label, suffix])
	image.save_png(path)
	var metrics := brightness(image)
	metrics["view"] = label
	metrics["dark"] = metrics["mean"] < DARK_MEAN or metrics["near_black"] > DARK_SHARE
	_metrics.append(metrics)
	print("saved %s  mean %.3f  near-black %.0f%%%s" % [ProjectSettings.globalize_path(path), metrics["mean"], float(metrics["near_black"]) * 100.0, "  DARK" if metrics["dark"] else ""])


## Mean luminance (Rec. 709 weights on the sRGB values) and the share of
## near-black pixels of [param image], over a 480 x 270 copy.
static func brightness(image: Image) -> Dictionary:
	var small := image.duplicate() as Image
	small.convert(Image.FORMAT_RGB8)
	small.resize(480, 270, Image.INTERPOLATE_BILINEAR)
	var total := 0.0
	var black := 0
	var count := small.get_width() * small.get_height()
	for y in small.get_height():
		for x in small.get_width():
			var c := small.get_pixel(x, y)
			var l := 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
			total += l
			if l < NEAR_BLACK:
				black += 1
	return {"mean": total / count, "near_black": float(black) / count}


func _seconds(time: float) -> void:
	await get_tree().create_timer(time, false).timeout


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame
