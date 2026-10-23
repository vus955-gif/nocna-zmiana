extends RefCounted
## Floor I's story layer (plan docs/superpowers/plans/2026-10-21-opowiesc-
## muzeum.md): where the museum tells its own story - the exhibit labels
## (label_<id>, ExhibitLabels), the exhibits that answer the guard
## (curio_<id>), the staff's trails, one per wing (vignette_<wing>_<prop>),
## the café's staff corkboard and the court's plaque of exhibits returned to
## rest. Floor1Layout.create() runs it after the zones: it only adds
## markers in rooms the zones built (no rooms, openings or pieces: the
## shell, the navigation and the collision stay the zones'). What stands on
## the markers is MuseumStory's (src/world/story).
##
## Marker frames: a plate on a wall or on a pedestal has its origin on the
## face, -Z out of it; a thing standing on the floor has its origin on the
## floor, -Z toward whoever reads or uses it; a prop lying on the floor has
## its origin on the floor, -Z the way it points.

const Hub := preload("res://src/level/floor1/zones/hub_kit.gd")
const PIT_Y := -3.0
const GREEK_UPPER := 4.5

## label id -> [room, position, yaw]: the labels of ExhibitLabels.
const LABELS := {
	# the hub: the T-Rex's own plate on its pedestal (the art kit's), the
	# founders' crypt beside its grate
	&"trex": [&"court", Vector3(0.0, 0.64, -19.47), PI],
	&"crypt": [&"north_hall", Vector3(3.8, 1.5, -37.99), PI],
	# Egypt: the stone, the camp (the shotgun), Ramesses' hall, the false door
	&"rosetta": [&"egypt_vestibule", Vector3(-40.9, 0.0, 26.6), -PI * 0.5],
	&"camp": [&"egypt_gallery", Vector3(-42.6, 0.0, 6.6), PI],
	&"colossus": [&"egypt_gallery", Vector3(-36.0, 1.5, -13.49), PI],
	&"false_door": [&"egypt_tomb_hall", Vector3(-59.99, 1.5, 23.4), -PI * 0.5],
	# Assyria: past the lamassu, the obelisk, the lions' cage, the tablets
	&"lamassu": [&"assyria_gate", Vector3(-55.6, 0.0, -44.6), PI],
	&"obelisk": [&"assyria_balawat", Vector3(-49.2, 0.0, -73.6), PI],
	&"lion_cage": [&"assyria_lions", Vector3(-95.99, PIT_Y + 1.5, -22.4), -PI * 0.5],
	&"tablets": [&"assyria_library", Vector3(-71.2, 1.5, -22.01), 0.0],
	# Greece: the podium's face, under the metopes, the vase room's cracked wall
	&"nereid": [&"greece_nereid", Vector3(-78.99, 1.6, 12.0), -PI * 0.5],
	&"metopes": [&"greece_metopes", Vector3(-82.75, 1.5, 39.49), 0.0],
	&"vases": [&"greece_vases", Vector3(-98.6, 1.5, 35.99), 0.0],
	# the Enlightenment: on the post by the Planetarium's portcullis, the rifle
	&"orrery": [&"enlightenment_library", Vector3(42.51, 1.5, -30.0), -PI * 0.5],
	&"rifle": [&"enlightenment_cabinet", Vector3(61.6, 0.0, 1.7), PI * 0.5],
	# Asia: beside the cracked wall to the garden, the bell shrine's door
	&"general": [&"asia_china", Vector3(11.6, 1.5, -61.99), PI],
	&"shrine": [&"asia_garden", Vector3(23.99, 1.5, -85.2), PI * 0.5],
	# the Americas: the moai's plinth, by the gap to the temple, the totems
	&"moai": [&"americas_moai", Vector3(-40.5, 0.95, -58.21), 0.0],
	&"serpent": [&"americas_pacific", Vector3(-31.01, 1.5, -74.0), PI * 0.5],
	&"totems": [&"americas_totems", Vector3(-25.01, 1.5, -61.0), PI * 0.5],
}


## The court's plaque of exhibits returned to rest, on the south wall east
## of the entrance arch; the staff's corkboard on the west wall by the café,
## south of its counter (out of the café's corner).
const REST_PLAQUE := [&"court", Vector3(6.6, 1.7, 29.99), 0.0]
const CORKBOARD := [&"court", Vector3(-29.99, 1.55, -26.1), -PI * 0.5]
## The exhibits that answer (Curios): id -> [room, position, yaw]. The
## bird and the astrolabe stand on the floor (-Z toward the guard), the
## portrait hangs on the corridor's north wall (the canvas's middle), the
## scales stand in the sarcophagus hall.
const CURIOS := {
	&"bird": [&"enlightenment_clocks", Vector3(57.2, 0.0, -13.4), PI],
	&"astrolabe": [&"enlightenment_portraits", Vector3(58.0, 0.0, 27.0), 0.0],
	&"portrait": [&"north_hall", Vector3(12.0, 2.1, -37.99), PI],
	&"scale": [&"egypt_tomb_hall", Vector3(-51.6, 0.0, 17.0), 0.0],
}
## The staff's trails (StoryVignettes): marker -> [room, position, yaw, or
## the floor point (x, z) the prop points at].
const VIGNETTES := {
	# Egypt: R. Gil listened at the serdab's cracked wall - chalk arrows from
	# his room (the conservator's haven), his open toolbox, his work lamp,
	# the stethoscope on a nail and his tally of knocks on the plaster
	&"vignette_egypt_chalk_arrow_1": [&"egypt_tombs", Vector3(-55.4, 0.0, 5.4), Vector2(-58.5, 10.2)],
	&"vignette_egypt_chalk_arrow_2": [&"egypt_tombs", Vector3(-59.2, 0.0, 11.4), Vector2(-61.75, 15.0)],
	&"vignette_egypt_toolbox": [&"egypt_tombs", Vector3(-60.3, 0.0, 14.05), 0.35],
	&"vignette_egypt_lantern": [&"egypt_tombs", Vector3(-61.2, 0.0, 14.4), 0.0],
	&"vignette_egypt_stethoscope": [&"egypt_tombs", Vector3(-60.6, 1.55, 14.99), 0.0],
	&"vignette_egypt_chalk_tally": [&"egypt_tombs", Vector3(-59.75, 1.2, 14.99), 0.0],
	# Assyria: St. Mazur's night in the lions' pit - his cap by the chariot,
	# his torch still shining at the royal cage, claw marks running there
	&"vignette_assyria_cap": [&"assyria_lions", Vector3(-86.4, PIT_Y, -17.9), 1.1],
	&"vignette_assyria_torch": [&"assyria_lions", Vector3(-88.6, PIT_Y, -20.4), Vector2(-96.0, -20.0)],
	&"vignette_assyria_scratches_1": [&"assyria_lions", Vector3(-89.4, PIT_Y, -22.4), Vector2(-96.0, -20.0)],
	&"vignette_assyria_scratches_2": [&"assyria_lions", Vector3(-92.6, PIT_Y, -21.3), Vector2(-96.0, -20.0)],
	&"vignette_assyria_scratches_3": [&"assyria_lions", Vector3(-95.0, PIT_Y, -20.5), Vector2(-96.0, -20.0)],
	# Greece: E. Turek's pigeons - feathers along the Bassae mezzanine to
	# the loft's hatch on its rope, the empty basket, spilt grain
	&"vignette_greece_feather_1": [&"greece_bassae_gallery", Vector3(-96.4, GREEK_UPPER, 0.1), 0.4],
	&"vignette_greece_feather_2": [&"greece_bassae_gallery", Vector3(-100.8, GREEK_UPPER, 0.5), 2.1],
	&"vignette_greece_feather_3": [&"greece_bassae_gallery", Vector3(-104.2, GREEK_UPPER, 2.1), 1.2],
	&"vignette_greece_feather_4": [&"greece_bassae_gallery", Vector3(-105.4, GREEK_UPPER, 3.6), 2.8],
	&"vignette_greece_basket": [&"greece_bassae_gallery", Vector3(-105.2, GREEK_UPPER, 8.1), -PI * 0.5 + 0.3],
	&"vignette_greece_seed": [&"greece_bassae_gallery", Vector3(-104.1, GREEK_UPPER, 6.6), 0.8],
	# the Enlightenment: the night the raptor broke Heniek's leg - claw marks
	# off the raptors' diorama, a chair knocked over, his torch, his cap by
	# the arch, the ruler and bandage he splinted it with at the door of the
	# librarian's office (the haven that held)
	&"vignette_enlightenment_scratches_1": [&"enlightenment_cabinet", Vector3(58.4, 0.0, 9.1), Vector2(45.5, 0.0)],
	&"vignette_enlightenment_chair": [&"enlightenment_cabinet", Vector3(56.7, 0.0, 3.5), 2.4],
	&"vignette_enlightenment_torch": [&"enlightenment_cabinet", Vector3(52.8, 0.0, 1.5), Vector2(59.0, 6.5)],
	&"vignette_enlightenment_scratches_2": [&"enlightenment_cabinet", Vector3(49.2, 0.0, 0.9), Vector2(45.5, 0.0)],
	&"vignette_enlightenment_cap": [&"enlightenment_cabinet", Vector3(46.7, 0.0, 1.7), -0.6],
	&"vignette_enlightenment_splint": [&"enlightenment_library", Vector3(43.7, 0.0, -3.4), 1.3],
	&"vignette_enlightenment_scratches_3": [&"enlightenment_library", Vector3(44.0, 0.0, -5.5), Vector2(45.5, -5.5)],
	# Asia: W. Kowalik, the armourer - lacquer scales from the armour on
	# the dais to the chained vault, his oil can and rag, his hammer at the
	# vault's door (chained from this side)
	&"vignette_asia_plate_1": [&"asia_armor", Vector3(45.9, 0.0, -77.3), 0.3],
	&"vignette_asia_plate_2": [&"asia_armor", Vector3(47.3, 0.0, -78.9), 1.9],
	&"vignette_asia_plate_3": [&"asia_armor", Vector3(48.7, 0.0, -80.2), 0.9],
	&"vignette_asia_oil_can": [&"asia_armor", Vector3(47.8, 0.0, -77.6), 0.0],
	&"vignette_asia_rag": [&"asia_armor", Vector3(48.3, 0.0, -78.3), 0.7],
	&"vignette_asia_hammer": [&"asia_armor", Vector3(49.25, 0.0, -82.75), 2.2],
	# the Americas: H. Bielecka's rehearsal of the night tour - folding
	# stools round the fire before the totems, one knocked over, her list,
	# her guide's flag, leaflets to the stairs down
	&"vignette_americas_stool_1": [&"americas_totems", Vector3(-33.0, 0.0, -66.9), Vector2(-29.75, -67.6)],
	&"vignette_americas_stool_2": [&"americas_totems", Vector3(-33.4, 0.0, -68.4), Vector2(-29.75, -67.6)],
	&"vignette_americas_stool_3": [&"americas_totems", Vector3(-32.9, 0.0, -69.9), Vector2(-29.75, -67.6)],
	&"vignette_americas_stool_tipped": [&"americas_totems", Vector3(-32.3, 0.0, -65.4), 0.9],
	&"vignette_americas_clipboard": [&"americas_totems", Vector3(-31.6, 0.0, -64.4), 0.4],
	&"vignette_americas_flag": [&"americas_totems", Vector3(-30.9, 0.0, -60.3), Vector2(-22.5, -55.0)],
	&"vignette_americas_leaflet_1": [&"americas_totems", Vector3(-27.5, 0.0, -57.1), 0.7],
	&"vignette_americas_leaflet_2": [&"americas_totems", Vector3(-24.0, 0.0, -55.4), 2.3],
	&"vignette_americas_leaflet_3": [&"americas_north", Vector3(-19.4, 0.0, -53.6), 1.4],
	&"vignette_americas_leaflet_4": [&"americas_north", Vector3(-21.2, 0.0, -45.0), 0.2],
	&"vignette_americas_leaflet_5": [&"americas_north", Vector3(-21.3, 0.0, -42.2), 2.9],
}


static func build(layout: LevelLayout) -> void:
	_labels(layout)
	_curios(layout)
	_vignettes(layout)
	layout.add_marker(&"rest_plaque", REST_PLAQUE[1], REST_PLAQUE[0], REST_PLAQUE[2])
	layout.add_marker(&"cafe_corkboard", CORKBOARD[1], CORKBOARD[0], CORKBOARD[2])


static func _labels(layout: LevelLayout) -> void:
	for id: StringName in LABELS:
		var spec: Array = LABELS[id]
		layout.add_marker(ExhibitLabels.marker_of(id), spec[1], spec[0], spec[2])


static func _curios(layout: LevelLayout) -> void:
	for id: StringName in CURIOS:
		var spec: Array = CURIOS[id]
		layout.add_marker(Curios.marker_of(id), spec[1], spec[0], spec[2])


static func _vignettes(layout: LevelLayout) -> void:
	for marker: StringName in VIGNETTES:
		var spec: Array = VIGNETTES[marker]
		var at: Vector3 = spec[1]
		var yaw: float = Hub.facing(Vector2(at.x, at.z), spec[2]) if spec[2] is Vector2 else float(spec[2])
		layout.add_marker(marker, at, spec[0], yaw)
