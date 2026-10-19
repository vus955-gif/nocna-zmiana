class_name Floor1LightRecipe
extends RefCounted
## Floor I's lighting recipe, stage P2 (design 10.1, 10.3; plan
## docs/superpowers/plans/2026-10-03-p2-oprawa-hol-egipt.md section 4): the
## lobby's recipe (SDFGI, SSR, SSAO, SSIL, AgX, fog only in FogVolumes) for
## a floor of 178 x 138 m, the moon aimed through the court's glass roof and
## Egypt's stone lattices, per dressed room its dust, probe, shadow budget
## and haze, Floor I's fittings, the lamps the art asks for that the layout
## does not have, and the motes that float in the moonbeams and the sand of
## Egypt. Rooms of zones not dressed yet keep the layout's plain lamps.
##
## The rule from the style sample still holds: the moon lights the dust 9x,
## lamps 0.1-0.3x; only moonlight, red lamps and Egypt's spotlights may
## haze.

## The night outside: cold, strong in the dust, high and a little from the
## south-east, so its shafts fall through the court's glass roof onto the
## floor between the drum and the walls (a lower moon put most of it on the
## north and west walls and in the drum's shadow - checked in a clay render),
## the lattice of the truss slanting over the floor, and through Egypt's
## lattices into the nave between the rows of colossi.
const MOON_DIRECTION := Vector3(-0.17, -0.96, -0.22)
## The clerestories in the gallery's east wall: their beams slant west into
## the nave (the windows face the court).
const CLERESTORY_BEAM := Vector3(-0.55, -0.8, -0.18)
const MOON_COLOR := Color(0.55, 0.66, 1.0)
## Sand and dust.
const SAND := Color(0.88, 0.8, 0.64)
const DUST := Color(0.8, 0.84, 0.95)
const PAPER := Color(0.92, 0.85, 0.72)
const WARM := Color(1.0, 0.8, 0.56)
## The basement's air: cold and thin under the tubes, smoky in the boiler hall.
const COLD := Color(0.76, 0.84, 0.92)
const SMOKE := Color(0.7, 0.64, 0.58)
## Stage P3: the Greek wing's clean, silvery air and its warm accents; the
## Enlightenment's book dust.
const MARBLE_AIR := Color(0.84, 0.88, 0.97)
const PLASTER := Color(0.9, 0.88, 0.84)
const BOOK_DUST := Color(0.9, 0.82, 0.68)
## Stage P4: alabaster dust in the Assyrian palaces, the hunting pit's grit,
## incense in the China hall, the armour hall's graphite air.
const ALABASTER := Color(0.8, 0.82, 0.88)
const GRIT := Color(0.78, 0.76, 0.72)
const INCENSE := Color(0.9, 0.84, 0.76)
const GRAPHITE := Color(0.76, 0.76, 0.8)
## The fill lamps' cold grey (bounce off alabaster and plaster).
const FILL := Color(0.7, 0.74, 0.82)
## The light pass's floor washes (FLOOR_WASHES): the bounce of the warm
## lamps off stone, sand and paper; of the cold moon and the graphite air.
const WARM_BOUNCE := Color(0.92, 0.8, 0.64)
const COLD_BOUNCE := Color(0.72, 0.76, 0.84)
## Stage P5: the smoke of the Americas' fire bowls (warm, brownish), the
## Pacific gallery's dry wood air, the night air over the roof.
const FIRE_SMOKE := Color(0.84, 0.76, 0.68)
const DRY_WOOD := Color(0.78, 0.76, 0.7)
const NIGHT := Color(0.7, 0.76, 0.9)

## Per room (the dressed zones; recipe keys are room ids): FogVolume
## density, colour and wisps, the reflection probe (polished stone and
## glass) with its capture point, how many lamps may cast shadows, where
## lamps start to fade, how much lamps light the dust.
const ROOMS := {
	&"court": {"fog": 0.009, "fog_albedo": DUST, "fog_noise": 0.6, "probe": true, "probe_offset": Vector3(0, -8.0, 0),
		"shadowed": 4, "fade_begin": 48.0, "lamp_fog": 0.12},
	&"court_reading": {"fog": 0.012, "fog_albedo": PAPER, "fog_noise": 0.4, "probe": true, "probe_offset": Vector3(0, -6.0, 0),
		"shadowed": 2, "fade_begin": 28.0, "lamp_fog": 0.18, "moon_rule": &"moon_shaft"},
	&"entrance_hall": {"fog": 0.011, "fog_albedo": Color(0.82, 0.84, 0.92), "probe": true, "probe_offset": Vector3(0, -3.0, 0),
		"shadowed": 3, "fade_begin": 40.0, "lamp_fog": 0.15},
	&"entrance_cloakroom": {"fog": 0.016, "fog_albedo": PAPER, "shadowed": 1, "fade_begin": 14.0, "lamp_fog": 0.35},
	&"entrance_coat_store": {"fog": 0.025, "fog_albedo": PAPER, "shadowed": 0, "fade_begin": 12.0, "lamp_fog": 0.4},
	&"booth_corridor": {"fog": 0.008, "fog_albedo": Color(0.8, 0.84, 0.86), "shadowed": 0, "fade_begin": 18.0, "lamp_fog": 0.3},
	&"booth_security": {"fog": 0.006, "fog_albedo": Color(0.82, 0.84, 0.86), "shadowed": 1, "fade_begin": 16.0, "lamp_fog": 0.3},
	&"booth_staff": {"fog": 0.008, "fog_albedo": Color(0.82, 0.84, 0.86), "shadowed": 0, "fade_begin": 16.0, "lamp_fog": 0.3},
	&"booth_stairs": {"fog": 0.01, "fog_albedo": Color(0.8, 0.82, 0.86), "shadowed": 0, "fade_begin": 16.0, "lamp_fog": 0.3},
	&"booth_watch": {"fog": 0.03, "fog_albedo": PAPER, "fog_noise": 0.5, "shadowed": 1, "fade_begin": 12.0, "lamp_fog": 0.5},
	&"north_hall": {"fog": 0.013, "fog_albedo": Color(0.8, 0.82, 0.9), "probe": true, "probe_offset": Vector3(0, -3.0, 0),
		"shadowed": 1, "fade_begin": 36.0, "lamp_fog": 0.15, "lamp_energy": 1.3},
	&"north_hall_lodge": {"fog": 0.02, "fog_albedo": PAPER, "shadowed": 0, "fade_begin": 12.0, "lamp_fog": 0.4},
	&"north_hall_crypt": {"fog": 0.03, "fog_albedo": Color(0.7, 0.74, 0.82), "fog_noise": 0.8, "shadowed": 0,
		"fade_begin": 20.0, "lamp_fog": 0.5},
	&"egypt_vestibule": {"fog": 0.015, "fog_albedo": SAND, "fog_noise": 0.5, "probe": true, "probe_offset": Vector3(0, -2.0, 0),
		"shadowed": 1, "fade_begin": 30.0, "lamp_fog": 0.25, "lamp_energy": 1.3},
	&"egypt_gallery": {"fog": 0.017, "fog_albedo": SAND, "fog_noise": 0.7, "probe": true, "probe_offset": Vector3(0, -4.0, 0),
		"shadowed": 3, "fade_begin": 42.0, "lamp_fog": 0.25, "lamp_energy": 1.3},
	&"egypt_colossus": {"fog": 0.021, "fog_albedo": SAND, "fog_noise": 0.8, "probe": true, "probe_offset": Vector3(0, -5.0, 0),
		"shadowed": 2, "fade_begin": 40.0, "lamp_fog": 0.3, "lamp_energy": 1.25},
	&"egypt_tomb_passage": {"fog": 0.028, "fog_albedo": Color(0.82, 0.72, 0.56), "fog_noise": 0.6, "shadowed": 0,
		"fade_begin": 20.0, "lamp_fog": 0.4, "lamp_energy": 1.35},
	&"egypt_tombs": {"fog": 0.028, "fog_albedo": Color(0.82, 0.72, 0.56), "fog_noise": 0.6, "shadowed": 1,
		"fade_begin": 20.0, "lamp_fog": 0.4, "lamp_energy": 1.35},
	&"egypt_tomb_hall": {"fog": 0.028, "fog_albedo": Color(0.82, 0.72, 0.56), "fog_noise": 0.6, "shadowed": 1,
		"fade_begin": 20.0, "lamp_fog": 0.4, "lamp_energy": 1.35},
	&"egypt_tomb_serdab": {"fog": 0.035, "fog_albedo": Color(0.82, 0.72, 0.56), "shadowed": 0, "fade_begin": 10.0, "lamp_fog": 0.5},
	&"egypt_tomb_priest": {"fog": 0.035, "fog_albedo": Color(0.82, 0.72, 0.56), "shadowed": 0, "fade_begin": 10.0, "lamp_fog": 0.5},
	&"egypt_conservator": {"fog": 0.012, "fog_albedo": PAPER, "shadowed": 1, "fade_begin": 14.0, "lamp_fog": 0.3},
	&"egypt_cache": {"fog": 0.03, "fog_albedo": SAND, "shadowed": 0, "fade_begin": 10.0, "lamp_fog": 0.5},
	&"egypt_service_stairs": {"fog": 0.008, "fog_albedo": Color(0.8, 0.84, 0.86), "shadowed": 0, "fade_begin": 18.0, "lamp_fog": 0.3},
	&"egypt_service_corridor": {"fog": 0.012, "fog_albedo": Color(0.8, 0.84, 0.86), "shadowed": 0, "fade_begin": 14.0, "lamp_fog": 0.3},
	# the basement (stage P3): fluorescent tubes without shadows, a little brighter than
	# the plan's lamps ("lamp_energy": the pools keep the plan's reach, the light
	# model's), thin cold haze, a smoky boiler hall; shadows only where the data asks
	# for one (the gantry's bulbs, the cross's lamp, the restorer's desk lamps), at
	# most two a room; reflection probes only where steel shines (the boiler hall, the
	# cross, the switchboard, the ring: they keep the night sky out of the pipes)
	&"basement_corridor_north": {"fog": 0.007, "fog_albedo": COLD, "probe": true, "probe_offset": Vector3(0, -1.0, 0), "shadowed": 0, "fade_begin": 22.0, "lamp_fog": 0.4, "lamp_energy": 1.6},
	&"basement_corridor_west": {"fog": 0.007, "fog_albedo": COLD, "probe": true, "probe_offset": Vector3(0, -1.0, 0), "shadowed": 0, "fade_begin": 22.0, "lamp_fog": 0.4, "lamp_energy": 1.6},
	&"basement_corridor_east": {"fog": 0.007, "fog_albedo": COLD, "probe": true, "probe_offset": Vector3(0, -1.0, 0), "shadowed": 0, "fade_begin": 22.0, "lamp_fog": 0.4, "lamp_energy": 1.6},
	&"basement_corridor_south": {"fog": 0.007, "fog_albedo": COLD, "probe": true, "probe_offset": Vector3(0, -1.0, 0), "shadowed": 0, "fade_begin": 22.0, "lamp_fog": 0.4, "lamp_energy": 1.6},
	&"basement_tunnel": {"fog": 0.01, "fog_albedo": COLD, "fog_noise": 0.4, "shadowed": 0, "fade_begin": 22.0, "lamp_fog": 0.4, "lamp_energy": 1.6},
	&"basement_corridor_spine_w": {"fog": 0.006, "fog_albedo": COLD, "shadowed": 0, "fade_begin": 18.0, "lamp_fog": 0.4, "lamp_energy": 1.6},
	&"basement_corridor_spine_e": {"fog": 0.006, "fog_albedo": COLD, "shadowed": 0, "fade_begin": 18.0, "lamp_fog": 0.4, "lamp_energy": 1.6},
	&"basement_corridor_workshop": {"fog": 0.006, "fog_albedo": COLD, "shadowed": 0, "fade_begin": 20.0, "lamp_fog": 0.4, "lamp_energy": 1.6},
	&"basement_corridor_staff": {"fog": 0.007, "fog_albedo": COLD, "shadowed": 0, "fade_begin": 20.0, "lamp_fog": 0.4, "lamp_energy": 1.6},
	&"basement_boiler": {"fog": 0.012, "fog_albedo": SMOKE, "fog_noise": 0.6, "probe": true, "probe_offset": Vector3(0, -1.0, 0), "shadowed": 2, "fade_begin": 30.0, "lamp_fog": 0.4, "lamp_energy": 1.45},
	&"basement_crossing": {"fog": 0.01, "fog_albedo": COLD, "fog_noise": 0.3, "probe": true, "probe_offset": Vector3(0, -1.0, 0), "shadowed": 1, "fade_begin": 28.0, "lamp_fog": 0.3, "lamp_energy": 1.45},
	&"basement_workshop": {"fog": 0.012, "fog_albedo": PAPER, "fog_noise": 0.3, "shadowed": 2, "fade_begin": 22.0, "lamp_fog": 0.35, "lamp_energy": 1.35},
	&"basement_store_plinths": {"fog": 0.01, "fog_albedo": PAPER, "shadowed": 0, "fade_begin": 20.0, "lamp_fog": 0.4, "lamp_energy": 1.5},
	&"basement_reserve": {"fog": 0.01, "fog_albedo": PAPER, "fog_noise": 0.4, "shadowed": 0, "fade_begin": 24.0, "lamp_fog": 0.4, "lamp_energy": 1.5},
	&"basement_archive": {"fog": 0.009, "fog_albedo": PAPER, "shadowed": 0, "fade_begin": 24.0, "lamp_fog": 0.4, "lamp_energy": 1.5},
	&"basement_switchboard": {"fog": 0.008, "fog_albedo": COLD, "probe": true, "probe_offset": Vector3(0, -1.0, 0), "shadowed": 0, "fade_begin": 22.0, "lamp_fog": 0.4, "lamp_energy": 1.45},
	&"basement_store_guards": {"fog": 0.009, "fog_albedo": COLD, "shadowed": 0, "fade_begin": 18.0, "lamp_fog": 0.4, "lamp_energy": 1.45},
	&"basement_old_cellar": {"fog": 0.022, "fog_albedo": Color(0.7, 0.72, 0.78), "fog_noise": 0.6, "shadowed": 0, "fade_begin": 12.0, "lamp_fog": 0.5, "lamp_energy": 1.45},
	&"basement_cage": {"fog": 0.02, "fog_albedo": COLD, "shadowed": 0, "fade_begin": 12.0, "lamp_fog": 0.5, "lamp_energy": 1.45},
	&"basement_shelter": {"fog": 0.022, "fog_albedo": PAPER, "fog_noise": 0.5, "shadowed": 0, "fade_begin": 14.0, "lamp_fog": 0.5, "lamp_energy": 1.45},
	# stage P3, Greece (design 10.1: the brightest wing, nearly clean air - the
	# moon's shafts carry it; the lamps hardly haze)
	&"greece_parthenon": {"fog": 0.005, "fog_albedo": MARBLE_AIR, "fog_noise": 0.2, "probe": true, "probe_offset": Vector3(0, -5.0, 0),
		"shadowed": 2, "fade_begin": 48.0, "lamp_fog": 0.05},
	&"greece_nereid": {"fog": 0.006, "fog_albedo": MARBLE_AIR, "fog_noise": 0.2, "probe": true, "probe_offset": Vector3(0, -6.0, 0),
		"shadowed": 1, "fade_begin": 40.0, "lamp_fog": 0.05},
	&"greece_bassae": {"fog": 0.007, "fog_albedo": MARBLE_AIR, "probe": true, "probe_offset": Vector3(0, -4.0, 0),
		"shadowed": 1, "fade_begin": 34.0, "lamp_fog": 0.06},
	&"greece_vases": {"fog": 0.007, "fog_albedo": MARBLE_AIR, "probe": true, "probe_offset": Vector3(0, -2.5, 0),
		"shadowed": 1, "fade_begin": 30.0, "lamp_fog": 0.06},
	&"greece_metopes": {"fog": 0.007, "fog_albedo": MARBLE_AIR, "probe": true, "probe_offset": Vector3(0, -3.5, 0),
		"shadowed": 1, "fade_begin": 34.0, "lamp_fog": 0.06},
	&"greece_cast_store": {"fog": 0.014, "fog_albedo": PLASTER, "shadowed": 1, "fade_begin": 14.0, "lamp_fog": 0.3},
	&"greece_bassae_loft": {"fog": 0.022, "fog_albedo": PLASTER, "fog_noise": 0.5, "shadowed": 0, "fade_begin": 10.0, "lamp_fog": 0.4},
	&"greece_pottery": {"fog": 0.022, "fog_albedo": PLASTER, "fog_noise": 0.5, "shadowed": 0, "fade_begin": 10.0, "lamp_fog": 0.4},
	&"greece_cast_cellar": {"fog": 0.022, "fog_albedo": PLASTER, "fog_noise": 0.5, "shadowed": 0, "fade_begin": 10.0, "lamp_fog": 0.4},
	&"greece_service_stairs": {"fog": 0.008, "fog_albedo": Color(0.8, 0.84, 0.86), "shadowed": 0, "fade_begin": 18.0, "lamp_fog": 0.3},
	&"greece_service_corridor": {"fog": 0.012, "fog_albedo": Color(0.8, 0.84, 0.86), "shadowed": 0, "fade_begin": 14.0, "lamp_fog": 0.3},
	# stage P3, the Enlightenment (warm pools of the green-shaded lamps in book
	# dust, long shadows of the bookcases, the moon's shafts through the roof)
	&"enlightenment_library": {"fog": 0.013, "fog_albedo": BOOK_DUST, "fog_noise": 0.5, "probe": true, "probe_offset": Vector3(0, -3.0, 0),
		"shadowed": 3, "fade_begin": 42.0, "lamp_fog": 0.22, "lamp_energy": 1.25},
	&"enlightenment_planetarium": {"fog": 0.011, "fog_albedo": DUST, "fog_noise": 0.4, "probe": true, "probe_offset": Vector3(0, -9.0, 0),
		"shadowed": 1, "fade_begin": 40.0, "lamp_fog": 0.15, "moon_rule": &"moon_shaft"},
	&"enlightenment_cabinet": {"fog": 0.012, "fog_albedo": BOOK_DUST, "probe": true, "probe_offset": Vector3(0, -2.0, 0),
		"shadowed": 1, "fade_begin": 26.0, "lamp_fog": 0.2, "lamp_energy": 1.3},
	&"enlightenment_clocks": {"fog": 0.012, "fog_albedo": BOOK_DUST, "shadowed": 1, "fade_begin": 22.0, "lamp_fog": 0.2, "lamp_energy": 1.25},
	&"enlightenment_portraits": {"fog": 0.012, "fog_albedo": BOOK_DUST, "shadowed": 0, "fade_begin": 26.0, "lamp_fog": 0.15, "lamp_energy": 1.35},
	&"enlightenment_librarian": {"fog": 0.014, "fog_albedo": PAPER, "shadowed": 1, "fade_begin": 12.0, "lamp_fog": 0.3},
	&"enlightenment_roof_stairs": {"fog": 0.008, "fog_albedo": Color(0.8, 0.84, 0.86), "shadowed": 0, "fade_begin": 18.0, "lamp_fog": 0.3},
	&"enlightenment_service_stairs": {"fog": 0.008, "fog_albedo": Color(0.8, 0.84, 0.86), "shadowed": 0, "fade_begin": 18.0, "lamp_fog": 0.3},
	&"enlightenment_attic": {"fog": 0.03, "fog_albedo": BOOK_DUST, "fog_noise": 0.6, "shadowed": 0, "fade_begin": 12.0, "lamp_fog": 0.5},
	&"enlightenment_stacks": {"fog": 0.02, "fog_albedo": BOOK_DUST, "fog_noise": 0.4, "shadowed": 0, "fade_begin": 14.0, "lamp_fog": 0.4},
	&"enlightenment_archive": {"fog": 0.03, "fog_albedo": BOOK_DUST, "fog_noise": 0.5, "shadowed": 0, "fade_begin": 10.0, "lamp_fog": 0.5},
	&"enlightenment_bindery": {"fog": 0.03, "fog_albedo": BOOK_DUST, "fog_noise": 0.5, "shadowed": 0, "fade_begin": 10.0, "lamp_fog": 0.5},
	&"enlightenment_study": {"fog": 0.03, "fog_albedo": BOOK_DUST, "fog_noise": 0.5, "shadowed": 0, "fade_begin": 10.0, "lamp_fog": 0.5},
	# stage P4, Assyria (design 10.1: low, harsh light and red torches against
	# the cold moon - but not dark: the owner's playtest found ground-floor
	# rooms too dark, so the lamps burn a little brighter than the plan,
	# "lamp_energy", and fill lamps mimic the bounce off the alabaster)
	&"assyria_gate": {"fog": 0.014, "fog_albedo": ALABASTER, "fog_noise": 0.5, "probe": true, "probe_offset": Vector3(0, -3.0, 0),
		"shadowed": 2, "fade_begin": 36.0, "lamp_fog": 0.3, "lamp_energy": 1.3},
	&"assyria_balawat": {"fog": 0.014, "fog_albedo": ALABASTER, "fog_noise": 0.5, "probe": true, "probe_offset": Vector3(0, -2.0, 0),
		"shadowed": 1, "fade_begin": 36.0, "lamp_fog": 0.3, "lamp_energy": 1.3},
	&"assyria_courtyard": {"fog": 0.01, "fog_albedo": DUST, "fog_noise": 0.6, "probe": true, "probe_offset": Vector3(0, -5.0, 0),
		"shadowed": 2, "fade_begin": 48.0, "lamp_fog": 0.2, "lamp_energy": 1.25},
	&"assyria_nimrud": {"fog": 0.013, "fog_albedo": ALABASTER, "fog_noise": 0.5, "probe": true, "probe_offset": Vector3(0, -2.0, 0),
		"shadowed": 2, "fade_begin": 44.0, "lamp_fog": 0.3, "lamp_energy": 1.35},
	&"assyria_lions": {"fog": 0.016, "fog_albedo": GRIT, "fog_noise": 0.6, "probe": true, "probe_offset": Vector3(0, -3.0, 0),
		"shadowed": 2, "fade_begin": 40.0, "lamp_fog": 0.3, "lamp_energy": 1.35},
	&"assyria_library": {"fog": 0.012, "fog_albedo": PAPER, "shadowed": 1, "fade_begin": 30.0, "lamp_fog": 0.3, "lamp_energy": 1.3},
	&"assyria_tablets": {"fog": 0.02, "fog_albedo": GRIT, "fog_noise": 0.5, "shadowed": 0, "fade_begin": 10.0, "lamp_fog": 0.4, "lamp_energy": 1.3},
	&"assyria_lion_cage": {"fog": 0.022, "fog_albedo": GRIT, "fog_noise": 0.5, "shadowed": 0, "fade_begin": 10.0, "lamp_fog": 0.4, "lamp_energy": 1.3},
	&"assyria_freight_lift": {"fog": 0.012, "fog_albedo": COLD, "shadowed": 0, "fade_begin": 12.0, "lamp_fog": 0.3, "lamp_energy": 1.3},
	&"assyria_freight_stairs": {"fog": 0.008, "fog_albedo": Color(0.8, 0.84, 0.86), "shadowed": 0, "fade_begin": 18.0, "lamp_fog": 0.3},
	# stage P4, Asia (warm lanterns, gold on the Buddha, paper glowing behind
	# the shoji, the cold moon over the garden)
	&"asia_china": {"fog": 0.012, "fog_albedo": INCENSE, "fog_noise": 0.5, "probe": true, "probe_offset": Vector3(0, -4.0, 0),
		"shadowed": 2, "fade_begin": 44.0, "lamp_fog": 0.2, "lamp_energy": 1.25},
	&"asia_porcelain": {"fog": 0.01, "fog_albedo": INCENSE, "probe": true, "probe_offset": Vector3(0, -2.0, 0),
		"shadowed": 1, "fade_begin": 30.0, "lamp_fog": 0.18, "lamp_energy": 1.25},
	&"asia_korea": {"fog": 0.012, "fog_albedo": INCENSE, "fog_noise": 0.4, "shadowed": 2, "fade_begin": 40.0, "lamp_fog": 0.2, "lamp_energy": 1.25},
	&"asia_armor": {"fog": 0.016, "fog_albedo": GRAPHITE, "fog_noise": 0.5, "shadowed": 1, "fade_begin": 40.0, "lamp_fog": 0.25, "lamp_energy": 1.3},
	&"asia_garden": {"fog": 0.009, "fog_albedo": DUST, "fog_noise": 0.6, "probe": true, "probe_offset": Vector3(0, -5.0, 0),
		"shadowed": 1, "fade_begin": 48.0, "lamp_fog": 0.15, "lamp_energy": 1.3},
	&"asia_teahouse": {"fog": 0.012, "fog_albedo": PAPER, "shadowed": 1, "fade_begin": 14.0, "lamp_fog": 0.3},
	&"asia_garden_shrine": {"fog": 0.014, "fog_albedo": PAPER, "shadowed": 0, "fade_begin": 10.0, "lamp_fog": 0.3, "lamp_energy": 1.2},
	&"asia_armory_vault": {"fog": 0.02, "fog_albedo": GRAPHITE, "fog_noise": 0.5, "shadowed": 0, "fade_begin": 10.0, "lamp_fog": 0.4, "lamp_energy": 1.2},
	&"asia_crate_store": {"fog": 0.02, "fog_albedo": PAPER, "fog_noise": 0.5, "shadowed": 0, "fade_begin": 10.0, "lamp_fog": 0.4, "lamp_energy": 1.2},
	&"asia_service_stairs": {"fog": 0.008, "fog_albedo": Color(0.8, 0.84, 0.86), "shadowed": 0, "fade_begin": 18.0, "lamp_fog": 0.3},
	# stage P5, the Americas (design 10.1: theatrical, from below, fire - the fire
	# bowls' smoke in the air; not too dark: the lamps burn brighter than the
	# plan and fills mimic the bounce off the red plaster; the Moai room dark by
	# design, one head in its beam, a cold fill so the room still reads)
	&"americas_temple": {"fog": 0.012, "fog_albedo": FIRE_SMOKE, "fog_noise": 0.6, "probe": true, "probe_offset": Vector3(0, -4.0, 0),
		"shadowed": 3, "fade_begin": 44.0, "lamp_fog": 0.3, "lamp_energy": 1.5},
	&"americas_north": {"fog": 0.012, "fog_albedo": FIRE_SMOKE, "fog_noise": 0.5, "probe": true, "probe_offset": Vector3(0, -2.0, 0),
		"shadowed": 2, "fade_begin": 36.0, "lamp_fog": 0.3, "lamp_energy": 1.6},
	&"americas_totems": {"fog": 0.014, "fog_albedo": FIRE_SMOKE, "fog_noise": 0.6, "probe": true, "probe_offset": Vector3(0, -4.0, 0),
		"shadowed": 2, "fade_begin": 40.0, "lamp_fog": 0.3, "lamp_energy": 1.6},
	&"americas_moai": {"fog": 0.016, "fog_albedo": GRIT, "fog_noise": 0.6, "shadowed": 1, "fade_begin": 34.0, "lamp_fog": 0.3, "lamp_energy": 1.5},
	&"americas_pacific": {"fog": 0.012, "fog_albedo": DRY_WOOD, "fog_noise": 0.4, "shadowed": 2, "fade_begin": 36.0, "lamp_fog": 0.25, "lamp_energy": 1.5},
	&"americas_pit": {"fog": 0.02, "fog_albedo": FIRE_SMOKE, "fog_noise": 0.7, "shadowed": 1, "fade_begin": 24.0, "lamp_fog": 0.4, "lamp_energy": 1.6},
	&"americas_service_stairs": {"fog": 0.008, "fog_albedo": COLD, "shadowed": 0, "fade_begin": 18.0, "lamp_fog": 0.3},
	&"americas_undercroft": {"fog": 0.008, "fog_albedo": COLD, "shadowed": 0, "fade_begin": 18.0, "lamp_fog": 0.3},
	&"americas_moai_hideout": {"fog": 0.018, "fog_albedo": FIRE_SMOKE, "fog_noise": 0.5, "shadowed": 0, "fade_begin": 12.0, "lamp_fog": 0.4, "lamp_energy": 1.3},
	&"americas_workshop": {"fog": 0.016, "fog_albedo": DRY_WOOD, "fog_noise": 0.5, "shadowed": 0, "fade_begin": 12.0, "lamp_fog": 0.4, "lamp_energy": 1.3},
	&"americas_store": {"fog": 0.02, "fog_albedo": PAPER, "fog_noise": 0.5, "shadowed": 0, "fade_begin": 10.0, "lamp_fog": 0.4, "lamp_energy": 1.3},
	# the roof: the night outside - the moon (the layout's pools and the
	# directional moon) on the lead, the court's warm glow up through the glass,
	# the city's glow over the gutters; the huts and the tower indoors
	&"roof_catwalks": {"fog": 0.004, "fog_albedo": NIGHT, "fog_noise": 0.3, "shadowed": 1, "fade_begin": 48.0, "lamp_fog": 0.15},
	&"roof_plant": {"fog": 0.005, "fog_albedo": NIGHT, "fog_noise": 0.3, "shadowed": 1, "fade_begin": 40.0, "lamp_fog": 0.15},
	&"roof_stairs": {"fog": 0.008, "fog_albedo": COLD, "shadowed": 0, "fade_begin": 18.0, "lamp_fog": 0.3},
	&"roof_loft": {"fog": 0.012, "fog_albedo": PAPER, "shadowed": 0, "fade_begin": 10.0, "lamp_fog": 0.3, "lamp_energy": 1.2},
	&"roof_shed": {"fog": 0.012, "fog_albedo": PAPER, "shadowed": 0, "fade_begin": 10.0, "lamp_fog": 0.3, "lamp_energy": 1.2},
}
## Rooms that count as another for the recipe (inside it, not carved).
const ROOM_KEYS := {
	&"court_balcony": &"court", &"entrance_gallery": &"entrance_hall", &"north_hall_crypt_vault": &"north_hall_crypt",
	&"basement_boiler_catwalk": &"basement_boiler",
	&"greece_nereid_podium": &"greece_nereid", &"greece_bassae_gallery": &"greece_bassae",
	&"enlightenment_library_gallery": &"enlightenment_library", &"enlightenment_observatory": &"enlightenment_planetarium",
	&"assyria_lions_gallery": &"assyria_lions",
}
## Floor I's fittings on top of the lobby's (LobbyLightRecipe.FIXTURE_LIGHTS):
## Egypt's museum spotlights haze in the sand and keep their shadow first
## (rank 0), the moon's pools and shafts light the dust like the moon, bare
## spots (the T-Rex's, the gatling's), red lamps without a fitting, the
## drum's lanterns, washes up the drum and the dome.
const FIXTURES := {
	&"egypt_spotlight": {"shadow": true, "fog": 0.3, "rank": 0},
	&"moon_pool": {"shadow": false, "fog": 0.2, "uncapped": true},
	&"moon_shaft": {"shadow": false, "fog": 5.0, "uncapped": true},
	&"cold_fill": {"shadow": false, "fog": 0.02, "uncapped": true},
	&"bare_spot": {"shadow": true, "fog": 0.25, "rank": 0},
	&"bare_red": {"shadow": false, "fog": 0.6, "uncapped": true},
	&"lantern": {"shadow": false, "fog": 0.1, "energy": 1.0},
	&"wash": {"shadow": false, "fog": 0.04, "energy": 1.0},
	# stage P4: Assyria's torches and fire tripods glow in the dust; the fill
	# lamps (the bounce off alabaster and plaster) never haze
	&"torch": {"shadow": false, "fog": 0.3, "energy": 1.2},
	&"brazier": {"shadow": false, "fog": 0.35, "energy": 1.0},
	&"fill": {"shadow": false, "fog": 0.0, "energy": 1.0},
	# Asia's paper: the glow behind shoji and lattice windows, the andons
	&"paper": {"shadow": false, "fog": 0.08, "energy": 1.0},
	&"andon": {"shadow": false, "fog": 0.1, "energy": 1.0},
	# stage P5: the embers in the altar house, the uplight on the Sun Disc, the
	# court's glow up through the roof's glass
	&"ember": {"shadow": false, "fog": 0.3, "energy": 1.0},
	&"uplight": {"shadow": false, "fog": 0.25, "energy": 1.0},
	&"court_glow": {"shadow": false, "fog": 0.25, "energy": 1.0},
}
## The light pass of 19.10 (plan
## docs/superpowers/plans/2026-10-19-swiatlo-parteru.md; the owner's
## playtest: "some ground-floor sections are definitely too dark" - the
## lamps lit the walls and the ceilings, the floor stayed black): per room
## soft washes down onto the floor, the bounce of the room's own lamps off
## its walls that the renderer leaves out. Wide spots WASH_HEIGHT over the
## floor (lower under a low ceiling), one over each WASH_TILE of every part
## of the room, rule "fill" (no shadow, no haze; the room's lamp_energy on
## top), no fitting. The lamps' pools stay the brightest, the corners dark.
## Room -> [energy, colour(, height over the floor)].
const FLOOR_WASHES := {
	&"egypt_vestibule": [1.5, WARM_BOUNCE],
	&"egypt_gallery": [1.5, WARM_BOUNCE],
	&"egypt_tomb_passage": [1.2, WARM_BOUNCE],
	&"egypt_tombs": [1.5, WARM_BOUNCE],
	&"egypt_tomb_hall": [1.5, WARM_BOUNCE],
	&"north_hall": [1.2, WARM_BOUNCE],
	&"enlightenment_cabinet": [1.5, WARM_BOUNCE],
	&"enlightenment_portraits": [1.7, WARM_BOUNCE],
	&"assyria_gate": [1.0, WARM_BOUNCE],
	&"assyria_balawat": [1.5, WARM_BOUNCE],
	&"assyria_library": [1.5, WARM_BOUNCE],
	# (over the pit's floor: as high over the gallery round it as elsewhere)
	&"assyria_lions": [1.2, WARM_BOUNCE, WASH_HEIGHT + 3.0],
	&"asia_china": [1.0, WARM_BOUNCE],
	&"asia_porcelain": [1.6, WARM_BOUNCE],
	&"asia_korea": [1.0, WARM_BOUNCE],
	&"asia_armor": [1.5, COLD_BOUNCE],
	&"americas_north": [1.0, WARM_BOUNCE],
	# (high over the stepped platform: the altar house's roof is 5.6 m up)
	&"americas_temple": [0.7, WARM_BOUNCE, 9.0],
}
## A wash hangs this high over the floor (or 0.3 m under a lower ceiling),
## lights a disc about as wide as it is high, and reaches WASH_REACH times
## its height (the light fades out towards its range: the floor round it
## must lie well inside) - but never into a room under the floor (the
## basement keeps its darkness): there it stops short.
const WASH_HEIGHT := 4.5
const WASH_TILE := 10.0
const WASH_REACH := 1.9
const WASH_ANGLE := 70.0
## Over a room under the floor: a wash hangs no lower than this (over the
## guard's head) and, lowered, still reaches this many times its height.
const WASH_LOW := 3.0
const WASH_REACH_MIN := 1.5
## Particle emitters: room, box (world AABB), amount, colour, size (m),
## drift (m/s, mostly down for sand). The motes are lit, not glowing: they
## show where moonbeams and lamps cross the dust.
const MOTES := [
	{"room": &"court", "box": AABB(Vector3(-28, 1, -28), Vector3(26, 16, 26)), "amount": 180, "color": DUST, "size": 0.035, "drift": -0.03},
	{"room": &"court", "box": AABB(Vector3(2, 1, -28), Vector3(26, 16, 26)), "amount": 180, "color": DUST, "size": 0.035, "drift": -0.03},
	{"room": &"court", "box": AABB(Vector3(-28, 1, 2), Vector3(26, 16, 26)), "amount": 180, "color": DUST, "size": 0.035, "drift": -0.03},
	{"room": &"court", "box": AABB(Vector3(2, 1, 2), Vector3(26, 16, 26)), "amount": 180, "color": DUST, "size": 0.035, "drift": -0.03},
	{"room": &"court_reading", "box": AABB(Vector3(-3, 1, -3), Vector3(6, 17, 6)), "amount": 140, "color": PAPER, "size": 0.03, "drift": -0.02},
	{"room": &"egypt_vestibule", "box": AABB(Vector3(-49, 0.5, 20), Vector3(17, 6, 9.5)), "amount": 90, "color": SAND, "size": 0.03, "drift": -0.05},
	{"room": &"egypt_gallery", "box": AABB(Vector3(-50, 0.5, 2), Vector3(16, 10, 17)), "amount": 240, "color": SAND, "size": 0.03, "drift": -0.06},
	{"room": &"egypt_gallery", "box": AABB(Vector3(-50, 0.5, -13.5), Vector3(16, 10, 15.5)), "amount": 240, "color": SAND, "size": 0.03, "drift": -0.06},
	{"room": &"egypt_colossus", "box": AABB(Vector3(-54, 0.5, -37), Vector3(22, 13, 22)), "amount": 300, "color": SAND, "size": 0.035, "drift": -0.05},
	{"room": &"egypt_tomb_hall", "box": AABB(Vector3(-59.5, 0.3, 16), Vector3(8.5, 3.8, 13.5)), "amount": 60, "color": SAND, "size": 0.025, "drift": -0.04},
	# stage P3: Greece's nearly clean air (a few silver specks in the moon's
	# shafts), the library's book dust and loose pages, the rotunda's shaft
	{"room": &"greece_parthenon", "box": AABB(Vector3(-60, 1, 37), Vector3(32, 11, 12)), "amount": 120, "color": MARBLE_AIR, "size": 0.025, "drift": -0.01},
	{"room": &"greece_nereid", "box": AABB(Vector3(-79, 1, 4), Vector3(10, 12, 13)), "amount": 60, "color": MARBLE_AIR, "size": 0.025, "drift": -0.01},
	{"room": &"enlightenment_library", "box": AABB(Vector3(33, 0.5, -35), Vector3(10, 9, 23)), "amount": 150, "color": BOOK_DUST, "size": 0.03, "drift": -0.015},
	{"room": &"enlightenment_library", "box": AABB(Vector3(33, 0.5, -12), Vector3(10, 9, 24)), "amount": 150, "color": BOOK_DUST, "size": 0.03, "drift": -0.015},
	{"room": &"enlightenment_library", "box": AABB(Vector3(33, 0.5, 12), Vector3(10, 9, 21)), "amount": 150, "color": BOOK_DUST, "size": 0.03, "drift": -0.015},
	{"room": &"enlightenment_library", "box": AABB(Vector3(34, 2, -30), Vector3(8, 7, 24)), "amount": 9, "pages": true},
	{"room": &"enlightenment_library", "box": AABB(Vector3(34, 2, 6), Vector3(8, 7, 24)), "amount": 9, "pages": true},
	{"room": &"enlightenment_planetarium", "box": AABB(Vector3(52.5, 1, -29.5), Vector3(5.5, 20, 6)), "amount": 120, "color": DUST, "size": 0.03, "drift": -0.01},
	# stage P4: alabaster dust in the moon over the courtyard and in the
	# torchlight of the palaces, the hunting pit's grit, incense in the China
	# hall, dust in Korea; cherry petals over both arms of the garden (the
	# embers over the fire tripods come with the tripods: Floor1ArtAssyria.BRAZIERS)
	{"room": &"assyria_courtyard", "box": AABB(Vector3(-89, 1, -68.5), Vector3(13, 12, 11.5)), "amount": 200, "color": DUST, "size": 0.035, "drift": -0.03},
	{"room": &"assyria_nimrud", "box": AABB(Vector3(-99, 0.5, -52), Vector3(34, 7, 12)), "amount": 160, "color": ALABASTER, "size": 0.03, "drift": -0.04},
	{"room": &"assyria_gate", "box": AABB(Vector3(-62.5, 0.5, -56.5), Vector3(15, 9, 17)), "amount": 120, "color": ALABASTER, "size": 0.03, "drift": -0.04},
	{"room": &"assyria_lions", "box": AABB(Vector3(-95, -2.5, -38), Vector3(16, 9, 34)), "amount": 140, "color": GRIT, "size": 0.03, "drift": -0.05},
	{"room": &"asia_china", "box": AABB(Vector3(5, 0.5, -61), Vector3(17, 10, 21)), "amount": 160, "color": INCENSE, "size": 0.03, "drift": -0.02},
	{"room": &"asia_korea", "box": AABB(Vector3(38, 0.5, -61), Vector3(17, 7, 21)), "amount": 100, "color": INCENSE, "size": 0.03, "drift": -0.03},
	{"room": &"asia_garden", "box": AABB(Vector3(13, 2, -85), Vector3(10.5, 5, 22)), "amount": 36, "petals": true},
	{"room": &"asia_garden", "box": AABB(Vector3(4.5, 2, -77), Vector3(7.5, 5, 14)), "amount": 24, "petals": true},
	# stage P5: the fire bowls' smoke in the Americas' air - in the moon's shaft
	# down the temple's well and over its arena, in the North America hall, up
	# the totem hall, the Pacific gallery's dry wood dust (the embers and the
	# smoke over each bowl come with the bowls: Floor1ArtAmericas.fire_bowls)
	{"room": &"americas_temple", "box": AABB(Vector3(-17, 3.5, -75), Vector3(5, 8, 5.5)), "amount": 100, "color": FIRE_SMOKE, "size": 0.035, "drift": -0.02},
	{"room": &"americas_temple", "box": AABB(Vector3(-24, 0.5, -85.5), Vector3(19.5, 10, 26.5)), "amount": 100, "color": FIRE_SMOKE, "size": 0.03, "drift": -0.03},
	{"room": &"americas_north", "box": AABB(Vector3(-21.5, 0.5, -57.5), Vector3(17, 6, 18)), "amount": 100, "color": FIRE_SMOKE, "size": 0.03, "drift": -0.03},
	{"room": &"americas_totems", "box": AABB(Vector3(-34, 0.5, -72), Vector3(9, 11, 19)), "amount": 120, "color": FIRE_SMOKE, "size": 0.03, "drift": -0.02},
	{"room": &"americas_pacific", "box": AABB(Vector3(-45.5, 0.5, -85), Vector3(14, 8.5, 11.5)), "amount": 80, "color": DRY_WOOD, "size": 0.03, "drift": -0.04},
]
## The embers over a fire tripod's flame.
const EMBER := Color(1.0, 0.5, 0.18)
const PETAL := Color(0.98, 0.8, 0.86)
## The boiler hall's steam: plumes at the layout's "steam_*" markers (the
## leaking valves behind the boilers, at the fuse, by the north door).
const STEAM_PREFIX := "steam_"
const STEAM_COLOR := Color(0.86, 0.9, 0.95)
## Stage P5: the Americas' fire bowls' smoke - warm grey-brown puffs over
## each flame, thin (it must not hide a fight).
const SMOKE_COLOR := Color(0.42, 0.38, 0.34)
## Glowing parts of hero pieces on a room's mains (dark in a blackout):
## the drum portals' lanterns, the lit windows of the drum; stage P4: the
## lit shoji and lattice windows, the tea house's glowing facades (model id
## -> its room, or &"" = the room of its hero group, meta "kit_room").
const MAINS_MODELS := {"rr_drum_door": &"court", "rr_drum_wall": &"court", "asia_shoji_2m": &"", "asia_lattice_window": &"", "teahouse": &""}

static var _mote_texture: GradientTexture2D = null
## False: no floor washes (frame-rate comparisons: run_tour.sh perf --washes=off).
static var washes_enabled: bool = true


## Floor I's LightRecipe; with [param layout] the extras the wings place
## by its rooms (the Greek skylights' sky).
static func create(layout: LevelLayout = null) -> LightRecipe:
	var recipe := LightRecipe.new()
	var env := LobbyLightRecipe.ENVIRONMENT.duplicate()
	env["ambient_energy"] = 0.09
	# 0.2 m cells: 4 cascades of 25.6 m doubling to 205 m - the whole floor
	env["sdfgi_min_cell_size"] = 0.2
	env["fog_length"] = 48.0
	env["glow_intensity"] = 0.75
	recipe.environment = env
	var moon := LobbyLightRecipe.MOON.duplicate()
	moon["direction"] = MOON_DIRECTION
	moon["color"] = MOON_COLOR
	moon["energy"] = 2.2
	moon["shadow_max_distance"] = 100.0
	recipe.moon = moon
	recipe.rooms = ROOMS
	recipe.room_keys = ROOM_KEYS
	var fixtures := LobbyLightRecipe.FIXTURE_LIGHTS.duplicate()
	fixtures.merge(FIXTURES, true)
	recipe.fixtures = fixtures
	recipe.extra_lights = extra_lights()
	recipe.extra_lights.append_array(Floor1ArtEnlightenment.extra_lights())
	if layout != null:
		recipe.extra_lights.append_array(Floor1ArtGreece.extra_lights(layout))
		recipe.extra_lights.append_array(Floor1ArtAssyria.extra_lights(layout))
		recipe.extra_lights.append_array(Floor1ArtAsia.extra_lights(layout))
		recipe.extra_lights.append_array(Floor1ArtAmericas.extra_lights(layout))
		recipe.extra_lights.append_array(Floor1ArtRoof.extra_lights(layout))
		if washes_enabled:
			recipe.extra_lights.append_array(floor_washes(layout))
	recipe.tune_unknown = false
	return recipe


## The lamps the art asks for (none of them lights a floor the exhibits
## patrol much: washes, lanterns, the moon's shafts through Egypt's
## clerestories):
## - four moonbeams through the clerestory windows of the Great Gallery
##   (moon group: a full moon brightens them, no fuse puts them out), from
##   behind the wall (no shadow: they pass it) so they enter as shafts,
## - lanterns on the drum's four portals, washes up the drum's attic from
##   the balcony and the court's floor, up into the Reading Room's dome.
static func extra_lights() -> Array:
	var out: Array = []
	var dir := CLERESTORY_BEAM.normalized()
	for z in Floor1Art.CLERESTORY_Z:
		var window := Vector3(-34.0 - 0.3, Floor1Art.CLERESTORY_SILL + 1.0, z)
		out.append({"room": &"egypt_gallery", "group": LightSpec.MOON, "position": window - dir * 6.0, "direction": dir,
			"color": MOON_COLOR, "energy": 0.35, "range": 19.0, "angle": 9.0, "rule": &"moon_shaft"})
	for k in 4:
		var turn := Basis(Vector3.UP, deg_to_rad(90.0 * k))
		for side in [-1.0, 1.0]:
			var at: Vector3 = turn * Vector3(side * 2.165, 3.4, -12.9)
			var out_dir: Vector3 = turn * Vector3(0.0, -0.6, -1.0)
			out.append({"room": &"court", "position": at, "direction": out_dir, "color": WARM, "energy": 0.9,
				"range": 5.0, "angle": 70.0, "rule": &"lantern"})
	for bearing in [-67.5, -22.5, 22.5, 67.5]:
		# from the balcony's parapet up the drum's north attic
		var a := deg_to_rad(bearing)
		var from := Vector3(sin(a) * 16.2, 7.35, -cos(a) * 16.2)
		var to := Vector3(sin(a) * 12.3, 16.0, -cos(a) * 12.3)
		out.append({"room": &"court", "position": from, "direction": (to - from).normalized(), "color": WARM,
			"energy": 1.3, "range": 13.0, "angle": 38.0, "rule": &"wash"})
	for bearing in [112.5, 157.5, 202.5, 247.5]:
		# from the court's floor up the drum's south face
		var a2 := deg_to_rad(bearing)
		var from2 := Vector3(sin(a2) * 15.0, 0.3, -cos(a2) * 15.0)
		var to2 := Vector3(sin(a2) * 12.3, 12.0, -cos(a2) * 12.3)
		out.append({"room": &"court", "position": from2, "direction": (to2 - from2).normalized(), "color": WARM,
			"energy": 1.4, "range": 16.0, "angle": 30.0, "rule": &"wash"})
	for bearing in [45.0, 135.0, 225.0, 315.0]:
		# from the bookcases' cornice up into the coffered dome
		var a3 := deg_to_rad(bearing)
		var from3 := Vector3(sin(a3) * 9.4, 10.0, -cos(a3) * 9.4)
		out.append({"room": &"court_reading", "position": from3, "direction": (Vector3(0, 18.0, 0) - from3).normalized(),
			"color": WARM, "energy": 0.9, "range": 12.0, "angle": 50.0, "rule": &"wash"})
	return out


## The floor washes of FLOOR_WASHES by the rooms of [param layout] (recipe
## extras): over every part of each room a grid of wide spots aimed straight
## down, one per WASH_TILE (at least one a part), WASH_HEIGHT over the floor
## (or the room's own height, or just under a lower ceiling). Over a room
## under the floor a wash stops short of it, and hangs lower (down to
## WASH_LOW) so that it still reaches well past the floor.
static func floor_washes(layout: LevelLayout) -> Array:
	var out: Array = []
	for id: StringName in FLOOR_WASHES:
		var room := layout.room(id)
		if room == null:
			continue
		var wash: Array = FLOOR_WASHES[id]
		var high := minf(float(wash[2]) if wash.size() > 2 else WASH_HEIGHT, room.height() - 0.3)
		for part in room.parts:
			# lower washes light smaller discs: closer together over a room below
			# (the lower quartile of the heights over a 3 x 3 grid of the part)
			var hangs: Array[float] = []
			for u in 3:
				for v in 3:
					var spot := part.position + part.size * Vector2(u * 0.5, v * 0.5)
					hangs.append(float(_wash_hang(layout, room, spot, high)[0]))
			hangs.sort()
			var tile := WASH_TILE * hangs[2] / high
			var across := maxi(1, roundi(part.size.x / tile + 0.2))
			var along := maxi(1, roundi(part.size.y / tile + 0.2))
			for i in across:
				for j in along:
					var middle := part.position + part.size * Vector2((i + 0.5) / across, (j + 0.5) / along)
					var hang: Array = _wash_hang(layout, room, middle, high)
					out.append({"room": id, "position": Vector3(middle.x, room.floor_y + float(hang[0]), middle.y), "direction": Vector3.DOWN,
						"color": wash[1], "energy": float(wash[0]), "range": hang[1], "angle": WASH_ANGLE, "rule": &"fill"})
	return out


## [height over the floor, reach] of a wash over [param middle] in
## [param room]: [param high] and WASH_REACH times that, or over a room
## under the floor lower (down to WASH_LOW) and short of it.
static func _wash_hang(layout: LevelLayout, room: RoomSpec, middle: Vector2, high: float) -> Array:
	var hang := high
	var reach := _wash_reach(layout, room, middle, hang)
	while reach < hang * WASH_REACH_MIN and hang > WASH_LOW:
		hang = maxf(WASH_LOW, hang - 0.25)
		reach = _wash_reach(layout, room, middle, hang)
	return [hang, reach]


## How far a wash over [param middle], [param high] over [param room]'s
## floor, may reach: WASH_REACH times its height, but short of every room
## under the floor (no shadow stops its light there) - the distance to the
## nearest point of that room's ceiling.
static func _wash_reach(layout: LevelLayout, room: RoomSpec, middle: Vector2, high: float) -> float:
	var reach := high * WASH_REACH
	var y := room.floor_y + high
	for other in layout.rooms:
		if other.ceiling_y > room.floor_y + 0.01:
			continue
		var depth := y - other.ceiling_y
		if depth >= reach:
			continue
		for part in other.parts:
			var nearest := Vector2(clampf(middle.x, part.position.x, part.end.x), clampf(middle.y, part.position.y, part.end.y))
			reach = minf(reach, Vector2(depth, middle.distance_to(nearest)).length() - 0.05)
	return reach


# --- motes and circuits -------------------------------------------------------------

## Dust in the moonbeams and sand in Egypt (GPU particles, group
## GraphicsQuality.PARTICLES, meta "room") for the dressed rooms in
## [param rooms] (all when empty) under [param parent]; the glowing parts of
## the hero pieces under [param heroes] on their rooms' mains.
static func atmosphere(layout: LevelLayout, parent: Node3D, heroes: Node, rooms: Dictionary = {}) -> void:
	for spec: Dictionary in MOTES:
		var room: StringName = spec["room"]
		if layout.room(room) == null or (not rooms.is_empty() and not rooms.has(room)):
			continue
		var motes: GPUParticles3D
		if spec.get("pages", false):
			motes = make_pages(spec)
		elif spec.get("petals", false):
			motes = make_petals(spec)
		else:
			motes = make_motes(spec)
		motes.set_meta(&"room", room)
		parent.add_child(motes)
	# the embers and smoke over the fires, on their rooms' mains with the flames
	var fires := {}
	for brazier_room: StringName in Floor1ArtAssyria.BRAZIERS:
		if layout.room(brazier_room) == null or (not rooms.is_empty() and not rooms.has(brazier_room)):
			continue
		for flame: Vector3 in Floor1ArtAssyria.BRAZIERS[brazier_room]:
			var embers := make_embers(flame)
			embers.set_meta(&"room", brazier_room)
			parent.add_child(embers)
			_on_the_fire(fires, brazier_room, embers)
	for bowl: Array in Floor1ArtAmericas.fire_bowls(layout):
		var bowl_room: StringName = bowl[0]
		if not rooms.is_empty() and not rooms.has(bowl_room):
			continue
		var flame: Vector3 = bowl[1]
		var sparks := make_embers(flame)
		sparks.set_meta(&"room", bowl_room)
		parent.add_child(sparks)
		_on_the_fire(fires, bowl_room, sparks)
		if bowl[2]:
			var smoke := make_smoke(flame + Vector3.UP * 0.2)
			smoke.set_meta(&"room", bowl_room)
			parent.add_child(smoke)
			_on_the_fire(fires, bowl_room, smoke)
	_fire_circuits(parent, fires)
	for marker: StringName in layout.markers:
		var steam_room: StringName = layout.marker_rooms.get(marker, &"")
		if not String(marker).begins_with(STEAM_PREFIX) or layout.room(steam_room) == null or (not rooms.is_empty() and not rooms.has(steam_room)):
			continue
		var plume := make_steam(marker, (layout.markers[marker] as Transform3D).origin)
		plume.set_meta(&"room", steam_room)
		parent.add_child(plume)
	if heroes != null:
		_hero_circuits(parent, heroes)


static func _on_the_fire(fires: Dictionary, room: StringName, emitter: GPUParticles3D) -> void:
	if not fires.has(room):
		fires[room] = []
	(fires[room] as Array).append(emitter)


## Circuits (like _hero_circuits) for the embers and smoke over the fires:
## one node per room in "main_lights_fixtures" whose "lit_targets" are those
## emitters, so a blackout puts them out with the flames (their lamps and
## flame models are on the same mains) and the power back lights them again.
static func _fire_circuits(parent: Node3D, by_room: Dictionary) -> void:
	for room: StringName in by_room:
		var circuit := Node3D.new()
		circuit.name = "Fire_%s" % room
		circuit.set_meta(&"kit", &"glow_circuit")
		circuit.set_meta(&"kit_room", room)
		circuit.set_meta(&"lit_targets", by_room[room])
		circuit.add_to_group(StringName("%s_fixtures" % LightSpec.MAIN))
		parent.add_child(circuit)


## One emitter of [param spec] (MOTES).
static func make_motes(spec: Dictionary) -> GPUParticles3D:
	var box: AABB = spec["box"]
	var particles := GPUParticles3D.new()
	particles.name = "Motes_%s" % spec["room"]
	particles.amount = spec["amount"]
	particles.lifetime = 12.0
	particles.preprocess = 12.0
	particles.randomness = 0.6
	particles.fixed_fps = 30
	particles.position = box.get_center()
	particles.visibility_aabb = AABB(-box.size * 0.5 - Vector3.ONE, box.size + Vector3.ONE * 2.0)
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = box.size * 0.5
	process.direction = Vector3(0.3, -1.0, 0.2)
	process.spread = 70.0
	process.initial_velocity_min = 0.01
	process.initial_velocity_max = 0.05
	process.gravity = Vector3(0.0, float(spec["drift"]), 0.0)
	process.turbulence_enabled = true
	process.turbulence_noise_strength = 0.6
	process.turbulence_noise_scale = 6.0
	process.turbulence_noise_speed = Vector3(0.02, 0.0, 0.03)
	process.turbulence_influence_min = 0.02
	process.turbulence_influence_max = 0.06
	process.scale_min = 0.5
	process.scale_max = 1.4
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0))
	fade.set_color(1, Color(1, 1, 1, 0))
	fade.add_point(0.15, Color(1, 1, 1, 1))
	fade.add_point(0.85, Color(1, 1, 1, 1))
	var ramp := GradientTexture1D.new()
	ramp.gradient = fade
	process.color_ramp = ramp
	process.color = spec["color"]
	particles.process_material = process
	var quad := QuadMesh.new()
	var size: float = spec["size"]
	quad.size = Vector2(size, size)
	quad.material = mote_material()
	particles.draw_pass_1 = quad
	particles.add_to_group(GraphicsQuality.PARTICLES)
	particles.set_meta(&"base_amount", int(spec["amount"]))
	return particles


static var _steam_material: StandardMaterial3D = null


## A plume of steam rising from [param at] (a leaking valve): soft grey puffs
## that swell and thin out as they climb (GPU particles, group
## GraphicsQuality.PARTICLES, lit: the embers tint them orange).
static func make_steam(marker: StringName, at: Vector3) -> GPUParticles3D:
	var particles := GPUParticles3D.new()
	particles.name = "Steam_%s" % marker
	particles.amount = 40
	particles.lifetime = 3.2
	particles.preprocess = 3.2
	particles.randomness = 0.5
	particles.fixed_fps = 30
	particles.position = at
	particles.visibility_aabb = AABB(Vector3(-3.0, -1.0, -3.0), Vector3(6.0, 6.0, 6.0))
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process.emission_sphere_radius = 0.1
	process.direction = Vector3(0.2, 1.0, 0.15)
	process.spread = 22.0
	process.initial_velocity_min = 0.7
	process.initial_velocity_max = 1.3
	process.gravity = Vector3(0.0, 0.2, 0.0)
	process.damping_min = 0.4
	process.damping_max = 0.7
	process.turbulence_enabled = true
	process.turbulence_noise_strength = 0.5
	process.turbulence_noise_scale = 3.0
	process.turbulence_influence_min = 0.05
	process.turbulence_influence_max = 0.15
	process.scale_min = 0.8
	process.scale_max = 1.4
	var swell := Curve.new()
	swell.add_point(Vector2(0.0, 0.35))
	swell.add_point(Vector2(1.0, 2.4))
	var swell_texture := CurveTexture.new()
	swell_texture.curve = swell
	process.scale_curve = swell_texture
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0))
	fade.set_color(1, Color(1, 1, 1, 0))
	fade.add_point(0.12, Color(1, 1, 1, 0.55))
	fade.add_point(0.6, Color(1, 1, 1, 0.22))
	var ramp := GradientTexture1D.new()
	ramp.gradient = fade
	process.color_ramp = ramp
	process.color = STEAM_COLOR
	particles.process_material = process
	var quad := QuadMesh.new()
	quad.size = Vector2(0.5, 0.5)
	quad.material = steam_material()
	particles.draw_pass_1 = quad
	particles.add_to_group(GraphicsQuality.PARTICLES)
	particles.set_meta(&"base_amount", 40)
	return particles


static var _smoke_material: StandardMaterial3D = null
static var _smoke_process: ParticleProcessMaterial = null
static var _smoke_quad: QuadMesh = null


## Smoke rising off a fire bowl's flame at [param at] (GPU particles, group
## GraphicsQuality.PARTICLES): warm grey puffs that climb, swell and thin
## out, lit by the fire under them (no glow of their own). Every bowl's smoke
## shares its process material and its quad.
static func make_smoke(at: Vector3) -> GPUParticles3D:
	var particles := GPUParticles3D.new()
	particles.name = "Smoke"
	particles.amount = 20
	particles.lifetime = 3.5
	particles.preprocess = 3.5
	particles.randomness = 0.6
	particles.fixed_fps = 30
	particles.position = at
	particles.visibility_aabb = AABB(Vector3(-2.5, -0.5, -2.5), Vector3(5.0, 6.0, 5.0))
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	particles.process_material = smoke_process()
	particles.draw_pass_1 = smoke_quad()
	particles.add_to_group(GraphicsQuality.PARTICLES)
	particles.set_meta(&"base_amount", 20)
	particles.set_meta(&"smoke", true)
	return particles


## The smoke's process material (shared).
static func smoke_process() -> ParticleProcessMaterial:
	if _smoke_process == null:
		var process := ParticleProcessMaterial.new()
		process.resource_name = "smoke_process"
		process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		process.emission_sphere_radius = 0.15
		process.direction = Vector3.UP
		process.spread = 15.0
		process.initial_velocity_min = 0.6
		process.initial_velocity_max = 1.0
		process.gravity = Vector3(0.0, 0.05, 0.0)
		process.damping_min = 0.3
		process.damping_max = 0.6
		process.turbulence_enabled = true
		process.turbulence_noise_strength = 0.6
		process.turbulence_noise_scale = 3.0
		process.turbulence_influence_min = 0.05
		process.turbulence_influence_max = 0.2
		process.scale_min = 0.8
		process.scale_max = 1.3
		var swell := Curve.new()
		swell.add_point(Vector2(0.0, 0.4))
		swell.add_point(Vector2(1.0, 2.2))
		var swell_texture := CurveTexture.new()
		swell_texture.curve = swell
		process.scale_curve = swell_texture
		var fade := Gradient.new()
		fade.set_color(0, Color(1, 1, 1, 0))
		fade.set_color(1, Color(1, 1, 1, 0))
		fade.add_point(0.15, Color(1, 1, 1, 0.35))
		fade.add_point(0.6, Color(1, 1, 1, 0.15))
		var ramp := GradientTexture1D.new()
		ramp.gradient = fade
		process.color_ramp = ramp
		process.color = SMOKE_COLOR
		_smoke_process = process
	return _smoke_process


## The smoke's puff (shared).
static func smoke_quad() -> QuadMesh:
	if _smoke_quad == null:
		_smoke_quad = QuadMesh.new()
		_smoke_quad.size = Vector2(0.6, 0.6)
		_smoke_quad.material = smoke_material()
	return _smoke_quad


## The steam's soft puffs without its backlight (smoke is dull).
static func smoke_material() -> StandardMaterial3D:
	if _smoke_material == null:
		_smoke_material = mote_material().duplicate() as StandardMaterial3D
		_smoke_material.resource_name = "smoke"
		_smoke_material.backlight_enabled = false
	return _smoke_material


## Lit, soft, two-sided billboard puffs.
static func steam_material() -> StandardMaterial3D:
	if _steam_material == null:
		_steam_material = mote_material().duplicate() as StandardMaterial3D
		_steam_material.resource_name = "steam"
		_steam_material.backlight = Color(0.45, 0.45, 0.45)
	return _steam_material


## Loose pages of [param spec] (MOTES with "pages"): a few printed leaves
## drifting down through the library's air, fluttering (each turns along its
## wandering way); lit like the dust.
static func make_pages(spec: Dictionary) -> GPUParticles3D:
	var box: AABB = spec["box"]
	var particles := GPUParticles3D.new()
	particles.name = "Pages_%s" % spec["room"]
	particles.amount = spec["amount"]
	particles.lifetime = 24.0
	particles.preprocess = 24.0
	particles.randomness = 0.8
	particles.fixed_fps = 30
	particles.position = box.get_center()
	particles.visibility_aabb = AABB(-box.size * 0.5 - Vector3.ONE * 2.0, box.size + Vector3.ONE * 4.0)
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = box.size * 0.5
	process.direction = Vector3(0.4, -1.0, 0.3)
	process.spread = 80.0
	process.initial_velocity_min = 0.05
	process.initial_velocity_max = 0.25
	process.gravity = Vector3(0.0, -0.06, 0.0)
	process.damping_min = 0.05
	process.damping_max = 0.15
	process.turbulence_enabled = true
	process.turbulence_noise_strength = 1.2
	process.turbulence_noise_scale = 3.0
	process.turbulence_noise_speed = Vector3(0.05, 0.02, 0.04)
	process.turbulence_influence_min = 0.15
	process.turbulence_influence_max = 0.35
	process.particle_flag_align_y = true
	process.scale_min = 0.8
	process.scale_max = 1.1
	# (a fade-in and a fade-out through the colour ramp: alpha_curve reads
	# only the red channel of its texture, so a white gradient there is a
	# constant 1 and the leaves would pop in and out)
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0))
	fade.set_color(1, Color(1, 1, 1, 0))
	fade.add_point(0.1, Color(1, 1, 1, 1))
	fade.add_point(0.9, Color(1, 1, 1, 1))
	var ramp := GradientTexture1D.new()
	ramp.gradient = fade
	process.color_ramp = ramp
	particles.process_material = process
	particles.draw_pass_1 = page_mesh()
	particles.add_to_group(GraphicsQuality.PARTICLES)
	particles.set_meta(&"base_amount", int(spec["amount"]))
	particles.set_meta(&"pages", true)
	return particles


static var _ember_material: StandardMaterial3D = null
static var _ember_process: ParticleProcessMaterial = null
static var _ember_quad: QuadMesh = null
static var _petal_mesh: QuadMesh = null


## Embers rising off a fire tripod's flame at [param at] (GPU particles,
## group GraphicsQuality.PARTICLES): a few glowing specks drifting up and
## dying out. Every fire's embers share their process material and their quad.
static func make_embers(at: Vector3) -> GPUParticles3D:
	var particles := GPUParticles3D.new()
	particles.name = "Embers"
	particles.amount = 14
	particles.lifetime = 2.4
	particles.preprocess = 2.4
	particles.randomness = 0.7
	particles.fixed_fps = 30
	particles.position = at
	particles.visibility_aabb = AABB(Vector3(-1.5, -0.5, -1.5), Vector3(3.0, 3.5, 3.0))
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	particles.process_material = ember_process()
	particles.draw_pass_1 = ember_quad()
	particles.add_to_group(GraphicsQuality.PARTICLES)
	particles.set_meta(&"base_amount", 14)
	particles.set_meta(&"embers", true)
	return particles


## The embers' process material (shared).
static func ember_process() -> ParticleProcessMaterial:
	if _ember_process == null:
		var process := ParticleProcessMaterial.new()
		process.resource_name = "ember_process"
		process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		process.emission_sphere_radius = 0.12
		process.direction = Vector3.UP
		process.spread = 25.0
		process.initial_velocity_min = 0.4
		process.initial_velocity_max = 0.8
		process.gravity = Vector3(0.0, 0.12, 0.0)
		process.damping_min = 0.2
		process.damping_max = 0.5
		process.turbulence_enabled = true
		process.turbulence_noise_strength = 0.8
		process.turbulence_noise_scale = 2.5
		process.turbulence_influence_min = 0.1
		process.turbulence_influence_max = 0.3
		process.scale_min = 0.6
		process.scale_max = 1.2
		var fade := Gradient.new()
		fade.set_color(0, Color(1, 1, 1, 1))
		fade.set_color(1, Color(1, 1, 1, 0))
		fade.add_point(0.6, Color(1, 0.8, 0.6, 0.8))
		var ramp := GradientTexture1D.new()
		ramp.gradient = fade
		process.color_ramp = ramp
		process.color = EMBER
		_ember_process = process
	return _ember_process


## The embers' speck (shared).
static func ember_quad() -> QuadMesh:
	if _ember_quad == null:
		_ember_quad = QuadMesh.new()
		_ember_quad.size = Vector2(0.02, 0.02)
		_ember_quad.material = ember_material()
	return _ember_quad


## A glowing speck (the mote's billboard with emission).
static func ember_material() -> StandardMaterial3D:
	if _ember_material == null:
		_ember_material = mote_material().duplicate() as StandardMaterial3D
		_ember_material.resource_name = "ember"
		_ember_material.emission_enabled = true
		_ember_material.emission = Color(1.0, 0.45, 0.15)
		_ember_material.emission_energy_multiplier = 2.5
	return _ember_material


## Cherry petals of [param spec] (MOTES with "petals"): small pink leaves
## drifting down through the garden's air and turning on the way (the
## General's storm is PetalStorm's; this is the quiet fall).
static func make_petals(spec: Dictionary) -> GPUParticles3D:
	var box: AABB = spec["box"]
	var particles := GPUParticles3D.new()
	# (not "Petals_*": those are the cherry tree's emitters PetalStorm looks for)
	particles.name = "PetalFall_%s" % spec["room"]
	particles.amount = spec["amount"]
	particles.lifetime = 16.0
	particles.preprocess = 16.0
	particles.randomness = 0.8
	particles.fixed_fps = 30
	particles.position = box.get_center()
	particles.visibility_aabb = AABB(-box.size * 0.5 - Vector3.ONE * 2.0, box.size + Vector3.ONE * 4.0)
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = box.size * 0.5
	process.direction = Vector3(0.3, -1.0, 0.2)
	process.spread = 60.0
	process.initial_velocity_min = 0.05
	process.initial_velocity_max = 0.2
	process.gravity = Vector3(0.0, -0.12, 0.0)
	process.damping_min = 0.05
	process.damping_max = 0.15
	process.turbulence_enabled = true
	process.turbulence_noise_strength = 1.0
	process.turbulence_noise_scale = 2.5
	process.turbulence_noise_speed = Vector3(0.05, 0.02, 0.04)
	process.turbulence_influence_min = 0.15
	process.turbulence_influence_max = 0.35
	process.particle_flag_align_y = true
	process.scale_min = 0.8
	process.scale_max = 1.2
	# (the fade through the colour ramp, as the pages': see make_pages)
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0))
	fade.set_color(1, Color(1, 1, 1, 0))
	fade.add_point(0.1, Color(1, 1, 1, 1))
	fade.add_point(0.9, Color(1, 1, 1, 1))
	var ramp := GradientTexture1D.new()
	ramp.gradient = fade
	process.color_ramp = ramp
	process.color = PETAL
	particles.process_material = process
	particles.draw_pass_1 = petal_mesh()
	particles.add_to_group(GraphicsQuality.PARTICLES)
	particles.set_meta(&"base_amount", int(spec["amount"]))
	particles.set_meta(&"petals", true)
	return particles


## A small lit two-sided petal.
static func petal_mesh() -> QuadMesh:
	if _petal_mesh == null:
		_petal_mesh = QuadMesh.new()
		_petal_mesh.size = Vector2(0.07, 0.09)
		var leaf := StandardMaterial3D.new()
		leaf.resource_name = "petal"
		leaf.albedo_color = PETAL
		leaf.albedo_texture = PetalStorm.petal_texture()   # (a petal, not a square)
		leaf.vertex_color_use_as_albedo = true
		leaf.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA   # (the ramp's fade)
		leaf.roughness = 1.0
		leaf.cull_mode = BaseMaterial3D.CULL_DISABLED
		leaf.backlight_enabled = true
		leaf.backlight = Color(0.5, 0.4, 0.45)
		_petal_mesh.material = leaf
	return _petal_mesh


static var _page_mesh: Mesh = null


## A printed page (the flying books' leaf, its own material baked in), or a
## small quad of paper when the model is missing. Its own copy of the mesh
## and of the paper, blending with the particle's alpha (the fade in and
## out) - the flying books' leaf stays opaque.
static func page_mesh() -> Mesh:
	if _page_mesh != null:
		return _page_mesh
	if ArtLibrary.has_model(&"flying_book_page"):
		var page := ArtKit.model("flying_book_page")
		var views := page.find_children("*", "MeshInstance3D", true, false)
		if not views.is_empty():
			_page_mesh = ArtKit.baked_mesh(views[0] as MeshInstance3D).duplicate() as Mesh
			for i in _page_mesh.get_surface_count():
				var paper := _page_mesh.surface_get_material(i) as BaseMaterial3D
				if paper != null:
					_page_mesh.surface_set_material(i, _fading(paper))
		page.free()
	if _page_mesh == null:
		var quad := QuadMesh.new()
		quad.size = Vector2(0.21, 0.31)
		var paper := StandardMaterial3D.new()
		paper.albedo_color = PAPER
		paper.cull_mode = BaseMaterial3D.CULL_DISABLED
		quad.material = _fading(paper)
		_page_mesh = quad
	return _page_mesh


## A copy of [param paper] that takes the particle's alpha (fading leaves).
static func _fading(paper: BaseMaterial3D) -> BaseMaterial3D:
	var out := paper.duplicate() as BaseMaterial3D
	out.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	out.vertex_color_use_as_albedo = true
	return out


static var _mote_material: StandardMaterial3D = null


## A lit, soft speck facing the camera: bright only where light falls on it.
static func mote_material() -> StandardMaterial3D:
	if _mote_material == null:
		_mote_material = StandardMaterial3D.new()
		_mote_material.resource_name = "mote"
		_mote_material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		_mote_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_mote_material.vertex_color_use_as_albedo = true
		_mote_material.albedo_texture = mote_texture()
		_mote_material.roughness = 1.0
		_mote_material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
		_mote_material.disable_receive_shadows = false
		# lit from any side (a speck has no back)
		_mote_material.cull_mode = BaseMaterial3D.CULL_DISABLED
		_mote_material.backlight_enabled = true
		_mote_material.backlight = Color(0.6, 0.6, 0.6)
	return _mote_material


## A soft round speck (radial gradient, white to clear).
static func mote_texture() -> GradientTexture2D:
	if _mote_texture == null:
		var gradient := Gradient.new()
		gradient.set_color(0, Color(1, 1, 1, 1))
		gradient.set_color(1, Color(1, 1, 1, 0))
		_mote_texture = GradientTexture2D.new()
		_mote_texture.gradient = gradient
		_mote_texture.fill = GradientTexture2D.FILL_RADIAL
		_mote_texture.fill_from = Vector2(0.5, 0.5)
		_mote_texture.fill_to = Vector2(0.5, 0.0)
		_mote_texture.width = 16
		_mote_texture.height = 16
	return _mote_texture


## Circuits (like LevelLighting.add_glow_circuits) for the hero models in
## MAINS_MODELS under [param heroes]: one node per room in
## "main_lights_fixtures" whose "lit_targets" are those models.
static func _hero_circuits(parent: Node3D, heroes: Node) -> void:
	var by_room := {}
	for node in heroes.find_children("*", "Node3D", true, false):
		var id := String(node.scene_file_path).get_file().trim_suffix(".glb")
		if not MAINS_MODELS.has(id):
			continue
		var room: StringName = MAINS_MODELS[id]
		if room == &"":
			room = _room_of(node)
		if room == &"":
			continue
		if not by_room.has(room):
			by_room[room] = []
		(by_room[room] as Array).append(node)
	for room: StringName in by_room:
		var circuit := Node3D.new()
		circuit.name = "Glow_%s_heroes" % room
		circuit.set_meta(&"kit", &"glow_circuit")
		circuit.set_meta(&"kit_room", room)
		circuit.set_meta(&"lit_targets", by_room[room])
		circuit.add_to_group(StringName("%s_fixtures" % LightSpec.MAIN))
		parent.add_child(circuit)


## The room of a hero model: the meta "kit_room" of its nearest ancestor
## that has one (the hero group), &"" when none.
static func _room_of(node: Node) -> StringName:
	var n: Node = node
	while n != null:
		if n.has_meta(&"kit_room"):
			return n.get_meta(&"kit_room")
		n = n.get_parent()
	return &""
