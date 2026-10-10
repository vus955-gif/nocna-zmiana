class_name Floor1Plan
extends RefCounted
## The master plan of Floor I, "the Great Court" (design: pietro-1-projekt
## sections 3-5, refined in docs/superpowers/plans/2026-10-02-p1-fundament.md).
## Pure constants and static look-ups, no nodes: the contract every zone
## module, the progress rules, the map and the tests share.
##
## Metres, Y up, -Z = north, origin in the middle of the Great Court. The
## ground floor is y = 0, the basement y = -6, the roof catwalks y = 22.5.
## Rectangles are Rect2(x0, z0, width, depth) on the 0.5 m grid.
##
## - Zones: disjoint 3D boxes (floor-plan rect x height range). A zone
##   module builds only inside its boxes. Neighbouring zones leave a 1 m
##   wall between them; the basement and the roof stack under / over others.
## - Junctions: every doorway where two zones meet. The opening fills the
##   wall gap exactly; each zone puts a room right against its side of it
##   (at the junction's floor height). Floor1Layout adds the openings.
## - Areas: what the progress rules reason about. A zone is an area; a few
##   parts behind internal gates are areas of their own (the reading room,
##   the Planetarium, the Japanese garden, the Serpent temple, the crypt).
## - Gates, havens, guardians and progress pickups (weapons, key items) with
##   the area they lie in and the marker the zone module places for them.

# --- zones --------------------------------------------------------------

const ZONES: Array[StringName] = [
	&"booth", &"entrance", &"court", &"north_hall", &"egypt", &"assyria",
	&"greece", &"enlightenment", &"asia", &"americas", &"basement", &"roof",
]
## The six wings (each has a guardian, a shard and a basement shortcut).
const WINGS: Array[StringName] = [&"egypt", &"assyria", &"greece", &"enlightenment", &"asia", &"americas"]

## Zone -> its boxes: [Rect2 (x, z), y_min, y_max]. Boxes of one zone may
## touch; boxes of different zones never overlap (touching faces are fine).
const ZONE_BOXES := {
	&"court": [[Rect2(-30, -30, 60, 60), -0.5, 22.5]],
	&"entrance": [[Rect2(-16, 31, 32, 22), -0.5, 32.0]],
	&"booth": [[Rect2(17, 36, 21, 12), -6.5, 4.0]],
	&"north_hall": [
		[Rect2(-30, -38, 60, 7), -0.5, 32.0],
		[Rect2(-3, -70, 6, 31), -14.0, 32.0],
	],
	&"egypt": [
		[Rect2(-55, -38, 24, 68), -0.5, 32.0],
		[Rect2(-55, -33, 24, 63), -6.5, -0.5],
		[Rect2(-55, -38, 24, 1), -6.5, -0.5],
		[Rect2(-63, 0, 8, 30), -6.5, 32.0],
	],
	&"assyria": [
		[Rect2(-112, -39, 56, 36), -6.5, 32.0],
		[Rect2(-112, -86, 65, 47), -6.5, 32.0],
	],
	&"greece": [
		[Rect2(-112, -2, 48, 55), -6.5, 32.0],
		[Rect2(-64, 31, 47, 22), -6.5, 32.0],
	],
	&"enlightenment": [[Rect2(31, -38, 34, 72), -6.5, 32.0]],
	&"asia": [[Rect2(4, -86, 52, 47), -6.5, 32.0]],
	&"americas": [[Rect2(-46, -86, 42, 47), -6.5, 32.0]],
	&"basement": [
		[Rect2(-30, -38, 60, 68), -6.5, -0.5],
		[Rect2(-16, 30, 32, 23), -6.5, -0.5],
		[Rect2(-55, -37, 25, 4), -6.5, -0.5],
	],
	&"roof": [
		[Rect2(-30, -30, 60, 60), 22.5, 32.0],
		[Rect2(17, 30, 13, 6), 4.0, 32.0],
		[Rect2(17, 36, 21, 17), 4.0, 32.0],
	],
}
## Main floor height of each zone.
const FLOOR_Y := {
	&"court": 0.0, &"entrance": 0.0, &"booth": 0.0, &"north_hall": 0.0,
	&"egypt": 0.0, &"assyria": 0.0, &"greece": 0.0, &"enlightenment": 0.0,
	&"asia": 0.0, &"americas": 0.0, &"basement": -6.0, &"roof": 22.5,
}
## Basement corridors and the ground floor's stairwells meet here.
const BASEMENT_Y := -6.0
const ROOF_Y := 22.5
## Height of the entrance hall's landing (Greece shortcut, roof hatch).
const LANDING_Y := 6.0
## Rise per run of every walkable flight: 0.15 m risers on 0.40 m treads
## (20.6 degrees; navigation joins slopes up to about 21.8).
const STAIR_SLOPE := 0.375
const STAIR_RISE := 0.15

## Greybox tint and paper-map colour of each zone (design 10.1 palettes).
const ZONE_COLORS := {
	&"court": Color(0.8, 0.78, 0.72),
	&"entrance": Color(0.74, 0.7, 0.62),
	&"booth": Color(0.56, 0.54, 0.44),
	&"north_hall": Color(0.62, 0.6, 0.56),
	&"egypt": Color(0.82, 0.66, 0.4),
	&"assyria": Color(0.56, 0.62, 0.7),
	&"greece": Color(0.9, 0.89, 0.85),
	&"enlightenment": Color(0.48, 0.34, 0.22),
	&"asia": Color(0.7, 0.22, 0.18),
	&"americas": Color(0.22, 0.56, 0.54),
	&"basement": Color(0.42, 0.45, 0.42),
	&"roof": Color(0.52, 0.56, 0.62),
}
const ZONE_NAME_KEYS := {
	&"court": &"ZONE_COURT", &"entrance": &"ZONE_ENTRANCE", &"booth": &"ZONE_BOOTH",
	&"north_hall": &"ZONE_NORTH_HALL", &"egypt": &"ZONE_EGYPT", &"assyria": &"ZONE_ASSYRIA",
	&"greece": &"ZONE_GREECE", &"enlightenment": &"ZONE_ENLIGHTENMENT", &"asia": &"ZONE_ASIA",
	&"americas": &"ZONE_AMERICAS", &"basement": &"ZONE_BASEMENT", &"roof": &"ZONE_ROOF",
}
## Paper-map tab of each zone (design 9.1: ground floor / basement / roof).
const MAP_TABS := {&"basement": &"basement", &"roof": &"roof"}

# --- areas ----------------------------------------------------------------

## Progress areas that are not whole zones -> the zone they lie in.
const SUB_AREAS := {
	&"reading_room": &"court",
	&"planetarium": &"enlightenment",
	&"asia_garden": &"asia",
	&"americas_temple": &"americas",
	&"crypt": &"north_hall",
}

# --- junctions ------------------------------------------------------------

## [id, zone_a, zone_b, Rect2 opening (x, z), floor_y, top_y, door style,
##  gate id (&"" = none), area_a, area_b (&"" = the zone)]
const JUNCTIONS := [
	[&"j_court_entrance", &"court", &"entrance", Rect2(-4, 30, 8, 1), 0.0, 8.0, OpeningSpec.DoorStyle.NONE, &"", &"", &""],
	[&"j_court_egypt", &"court", &"egypt", Rect2(-31, 20, 1, 6), 0.0, 7.0, OpeningSpec.DoorStyle.NONE, &"", &"", &""],
	[&"j_court_enlightenment", &"court", &"enlightenment", Rect2(30, -3, 1, 6), 0.0, 7.0, OpeningSpec.DoorStyle.NONE, &"", &"", &""],
	[&"j_court_north", &"court", &"north_hall", Rect2(-4, -31, 8, 1), 0.0, 8.0, OpeningSpec.DoorStyle.GATE, &"gate_north", &"", &""],
	[&"j_entrance_booth", &"entrance", &"booth", Rect2(16, 41, 1, 2), 0.0, 2.6, OpeningSpec.DoorStyle.SWING, &"", &"", &""],
	[&"j_entrance_greece", &"entrance", &"greece", Rect2(-17, 50, 1, 2), LANDING_Y, LANDING_Y + 2.6, OpeningSpec.DoorStyle.SWING, &"bolt_greece_entrance", &"", &""],
	[&"j_entrance_roof", &"entrance", &"roof", Rect2(16, 50, 1, 2), LANDING_Y, LANDING_Y + 2.6, OpeningSpec.DoorStyle.GATE, &"rope_roof_hatch", &"", &""],
	[&"j_egypt_greece", &"egypt", &"greece", Rect2(-64, 10, 1, 4), 0.0, 3.5, OpeningSpec.DoorStyle.DOUBLE_SWING, &"boards_tomb", &"", &""],
	[&"j_egypt_assyria", &"egypt", &"assyria", Rect2(-54, -39, 6, 1), 0.0, 8.0, OpeningSpec.DoorStyle.GATE, &"seal_khorsabad", &"", &""],
	[&"j_assyria_americas", &"assyria", &"americas", Rect2(-47, -66, 1, 4), 0.0, 5.0, OpeningSpec.DoorStyle.GATE, &"seal_balawat", &"", &""],
	[&"j_assyria_greece", &"assyria", &"greece", Rect2(-90, -3, 3, 1), 0.0, 3.0, OpeningSpec.DoorStyle.SWING, &"bolt_lions_bassae", &"", &""],
	[&"j_north_americas", &"north_hall", &"americas", Rect2(-20, -39, 6, 1), 0.0, 5.0, OpeningSpec.DoorStyle.SLIDE, &"shutter_americas", &"", &""],
	[&"j_north_asia", &"north_hall", &"asia", Rect2(14, -39, 6, 1), 0.0, 5.0, OpeningSpec.DoorStyle.SLIDE, &"shutter_asia", &"", &""],
	[&"j_asia_enlightenment", &"asia", &"enlightenment", Rect2(48, -39, 4, 1), 0.0, 3.0, OpeningSpec.DoorStyle.SWING, &"bolt_asia_planetarium", &"", &"planetarium"],
	[&"j_booth_basement", &"booth", &"basement", Rect2(16, 37, 1, 2), BASEMENT_Y, BASEMENT_Y + 2.6, OpeningSpec.DoorStyle.DOUBLE_SWING, &"boards_staff_stairs", &"", &""],
	[&"j_basement_egypt", &"basement", &"egypt", Rect2(-31, -12.5, 1, 2), BASEMENT_Y, BASEMENT_Y + 2.6, OpeningSpec.DoorStyle.SWING, &"bolt_basement_egypt", &"", &""],
	[&"j_basement_assyria", &"basement", &"assyria", Rect2(-56, -36.5, 1, 2), BASEMENT_Y, BASEMENT_Y + 2.6, OpeningSpec.DoorStyle.SWING, &"bolt_basement_assyria", &"", &""],
	[&"j_basement_greece", &"basement", &"greece", Rect2(-28, 30, 2, 1), BASEMENT_Y, BASEMENT_Y + 2.6, OpeningSpec.DoorStyle.SWING, &"bolt_basement_greece", &"", &""],
	[&"j_basement_enlightenment", &"basement", &"enlightenment", Rect2(30, 28, 1, 2), BASEMENT_Y, BASEMENT_Y + 2.6, OpeningSpec.DoorStyle.SWING, &"bolt_basement_enlightenment", &"", &""],
	[&"j_basement_americas", &"basement", &"americas", Rect2(-28, -39, 2, 1), BASEMENT_Y, BASEMENT_Y + 2.6, OpeningSpec.DoorStyle.SWING, &"bolt_basement_americas", &"", &""],
	[&"j_basement_asia", &"basement", &"asia", Rect2(24, -39, 2, 1), BASEMENT_Y, BASEMENT_Y + 2.6, OpeningSpec.DoorStyle.SWING, &"bolt_basement_asia", &"", &""],
	[&"j_roof_enlightenment", &"roof", &"enlightenment", Rect2(30, -12, 1, 1.5), ROOF_Y, ROOF_Y + 2.5, OpeningSpec.DoorStyle.SWING, &"bolt_roof_enlightenment", &"", &""],
]

# --- gates ----------------------------------------------------------------

## [id, GateSpec.Kind, requirement, label key, area_a, area_b, bolt area
##  (BOLT: the side it opens from), junction id (&"" = inside one zone)]
## Internal gates (no junction) are added by their zone module on the
## opening named in INTERNAL_GATE_OPENINGS.
const GATES := [
	[&"gate_north", GateSpec.Kind.SEAL, &"star_key", &"GATE_STAR_KEY", &"court", &"north_hall", &"", &"j_court_north"],
	[&"bolt_greece_entrance", GateSpec.Kind.BOLT, GateSpec.NONE, &"GATE_BOLT", &"entrance", &"greece", &"greece", &"j_entrance_greece"],
	[&"rope_roof_hatch", GateSpec.Kind.ROPE, GateSpec.PRECISE, &"GATE_ROPE", &"entrance", &"roof", &"", &"j_entrance_roof"],
	[&"boards_tomb", GateSpec.Kind.BOARDS, GateSpec.HEAVY, &"GATE_BOARDS", &"egypt", &"greece", &"", &"j_egypt_greece"],
	[&"seal_khorsabad", GateSpec.Kind.SEAL, &"seal_sun", &"GATE_SEAL_SUN", &"egypt", &"assyria", &"", &"j_egypt_assyria"],
	[&"seal_balawat", GateSpec.Kind.SEAL, &"seal_wing", &"GATE_SEAL_WING", &"assyria", &"americas", &"", &"j_assyria_americas"],
	[&"bolt_lions_bassae", GateSpec.Kind.BOLT, GateSpec.NONE, &"GATE_BOLT", &"assyria", &"greece", &"assyria", &"j_assyria_greece"],
	[&"shutter_americas", GateSpec.Kind.POWER, &"power_north", &"GATE_POWER", &"north_hall", &"americas", &"", &"j_north_americas"],
	[&"shutter_asia", GateSpec.Kind.POWER, &"power_north", &"GATE_POWER", &"north_hall", &"asia", &"", &"j_north_asia"],
	[&"bolt_asia_planetarium", GateSpec.Kind.BOLT, GateSpec.NONE, &"GATE_BOLT", &"asia", &"planetarium", &"asia", &"j_asia_enlightenment"],
	[&"boards_staff_stairs", GateSpec.Kind.BOARDS, GateSpec.HEAVY, &"GATE_BOARDS", &"booth", &"basement", &"", &"j_booth_basement"],
	[&"bolt_basement_egypt", GateSpec.Kind.BOLT, GateSpec.NONE, &"GATE_BOLT", &"basement", &"egypt", &"egypt", &"j_basement_egypt"],
	[&"bolt_basement_assyria", GateSpec.Kind.BOLT, GateSpec.NONE, &"GATE_BOLT", &"basement", &"assyria", &"assyria", &"j_basement_assyria"],
	[&"bolt_basement_greece", GateSpec.Kind.BOLT, GateSpec.NONE, &"GATE_BOLT", &"basement", &"greece", &"greece", &"j_basement_greece"],
	[&"bolt_basement_enlightenment", GateSpec.Kind.BOLT, GateSpec.NONE, &"GATE_BOLT", &"basement", &"enlightenment", &"enlightenment", &"j_basement_enlightenment"],
	[&"bolt_basement_americas", GateSpec.Kind.BOLT, GateSpec.NONE, &"GATE_BOLT", &"basement", &"americas", &"americas", &"j_basement_americas"],
	[&"bolt_basement_asia", GateSpec.Kind.BOLT, GateSpec.NONE, &"GATE_BOLT", &"basement", &"asia", &"asia", &"j_basement_asia"],
	[&"bolt_roof_enlightenment", GateSpec.Kind.BOLT, GateSpec.NONE, &"GATE_BOLT", &"roof", &"enlightenment", &"enlightenment", &"j_roof_enlightenment"],
	# inside one zone
	[&"gate_reading_room", GateSpec.Kind.SEAL, &"seal_owl", &"GATE_SEAL_OWL", &"court", &"reading_room", &"", &""],
	[&"chain_gatling", GateSpec.Kind.CHAIN, GateSpec.HEAVY, &"GATE_CHAIN", &"reading_room", &"reading_room", &"", &""],
	[&"rope_planetarium", GateSpec.Kind.ROPE, &"rifle_hunt", &"GATE_ROPE", &"enlightenment", &"planetarium", &"", &""],
	[&"cracked_garden", GateSpec.Kind.CRACKED, GateSpec.EXPLOSIVE, &"GATE_CRACKED", &"asia", &"asia_garden", &"", &""],
	[&"hook_canoe", GateSpec.Kind.HOOK, &"harpoon", &"GATE_HOOK", &"americas", &"americas_temple", &"", &""],
	[&"grate_crypt", GateSpec.Kind.EVENT, &"trex_defeated", &"GATE_GRATE", &"north_hall", &"crypt", &"", &""],
]
## Internal gate -> what it locks in the greybox: an opening id, or a
## marker id for a lock on an object (the gatling's chained case).
const INTERNAL_GATE_TARGETS := {
	&"gate_reading_room": &"court_reading_door",
	&"chain_gatling": &"gatling_case",
	&"rope_planetarium": &"enlightenment_planetarium_door",
	&"cracked_garden": &"asia_garden_wall",
	&"hook_canoe": &"americas_canoe_bridge",
	&"grate_crypt": &"north_hall_grate",
}

# --- havens, guardians, pickups ----------------------------------------------

## [haven id, zone, room id, name key, area]. Every haven has an upgrade
## terminal (LevelLayout.haven_spots[haven id]); the room is its safe zone.
const HAVENS := [
	[&"security", &"booth", &"booth_security", &"HAVEN_SECURITY_ROOM", &"booth"],
	[&"conservator", &"egypt", &"egypt_conservator", &"HAVEN_CONSERVATOR", &"egypt"],
	[&"librarian", &"enlightenment", &"enlightenment_librarian", &"HAVEN_LIBRARIAN", &"enlightenment"],
	[&"workshop", &"basement", &"basement_workshop", &"HAVEN_WORKSHOP", &"basement"],
	[&"teahouse", &"asia", &"asia_teahouse", &"HAVEN_TEAHOUSE", &"asia_garden"],
	[&"cast_store", &"greece", &"greece_cast_store", &"HAVEN_CAST_STORE", &"greece"],
]
## [id, zone, area, seal (&"" = none), shard, spawn marker, name key, title key]
const GUARDIANS := [
	[&"colossus", &"egypt", &"egypt", &"seal_sun", &"shard_egypt", &"guardian_colossus", &"GUARDIAN_COLOSSUS", &"GUARDIAN_COLOSSUS_TITLE"],
	[&"lamassu", &"assyria", &"assyria", &"seal_wing", &"shard_assyria", &"guardian_lamassu", &"GUARDIAN_LAMASSU", &"GUARDIAN_LAMASSU_TITLE"],
	[&"centaur", &"greece", &"greece", &"seal_owl", &"shard_greece", &"guardian_centaur", &"GUARDIAN_CENTAUR", &"GUARDIAN_CENTAUR_TITLE"],
	[&"planetarium", &"enlightenment", &"planetarium", &"star_key", &"shard_enlightenment", &"guardian_planetarium", &"GUARDIAN_PLANETARIUM", &"GUARDIAN_PLANETARIUM_TITLE"],
	[&"general", &"asia", &"asia_garden", &"", &"shard_asia", &"guardian_general", &"GUARDIAN_GENERAL", &"GUARDIAN_GENERAL_TITLE"],
	[&"serpent", &"americas", &"americas_temple", &"", &"shard_americas", &"guardian_serpent", &"GUARDIAN_SERPENT", &"GUARDIAN_SERPENT_TITLE"],
]
## The finale: the T-Rex wakes when the astrolabe holds all six shards.
const TREX := &"trex"
const TREX_MARKER := &"trex_pedestal"
## Where the guard walks down into the dark (the end of Floor I).
const EXIT_MARKER := &"floor1_exit"
const SHARD_COUNT := 6
## Seal / key id -> name key.
const SEALS := {
	&"seal_sun": &"SEAL_SUN", &"seal_wing": &"SEAL_WING",
	&"seal_owl": &"SEAL_OWL", &"star_key": &"SEAL_STAR_KEY",
}
## Progress pickups: [id, kind (&"weapon" / &"item" / &"flag"), area,
##  requirements (all needed), marker]. Weapons are WeaponData ids.
const PICKUPS := [
	[&"pistol_key", &"item", &"entrance", [], &"ticket_drawer"],
	[&"pistol", &"weapon", &"booth", [&"pistol_key"], &"pistol_locker"],
	[&"flare", &"weapon", &"entrance", [], &"flare_cabinet"],
	[&"shotgun", &"weapon", &"egypt", [], &"weapon_shotgun"],
	[&"rifle_hunt", &"weapon", &"enlightenment", [], &"weapon_rifle_hunt"],
	[&"gatling", &"weapon", &"reading_room", [GateSpec.HEAVY], &"gatling_case"],
	[&"hwacha", &"weapon", &"asia", [], &"weapon_hwacha"],
	[&"harpoon", &"weapon", &"americas", [], &"weapon_harpoon"],
	[&"fuse_basement", &"item", &"basement", [], &"fuse_basement"],
	[&"fuse_assyria", &"item", &"assyria", [], &"fuse_assyria"],
	[&"power_north", &"flag", &"basement", [&"fuse_basement", &"fuse_assyria"], &"switchboard"],
	[&"astrolabe", &"flag", &"reading_room", [&"shards_6"], &"astrolabe"],
]


class Junction:
	extends RefCounted
	var id: StringName
	var zone_a: StringName
	var zone_b: StringName
	## Opening through the wall (x, z); its thin side runs across the wall.
	var rect: Rect2
	var floor_y: float
	var top_y: float
	var style: OpeningSpec.DoorStyle
	var gate: StringName
	var area_a: StringName
	var area_b: StringName

	func center() -> Vector3:
		var middle := rect.get_center()
		return Vector3(middle.x, floor_y, middle.y)

	## True when the passage runs along x (the wall it pierces runs along z).
	func runs_along_x() -> bool:
		return rect.size.x < rect.size.y

	func width() -> float:
		return rect.size.y if runs_along_x() else rect.size.x

	func depth() -> float:
		return rect.size.x if runs_along_x() else rect.size.y

	func height() -> float:
		return top_y - floor_y

	## The two points [param reach] m beyond the wall faces, [param up] m
	## over the floor (one on each side, either order).
	func side_points(reach: float = 0.25, up: float = 1.0) -> Array[Vector3]:
		var axis := Vector3(1, 0, 0) if runs_along_x() else Vector3(0, 0, 1)
		var middle := center() + Vector3.UP * up
		var offset := axis * (depth() * 0.5 + reach)
		return [middle - offset, middle + offset]

	## The point just beyond the wall on [param zone]'s side (null side ->
	## Vector3.INF when neither side lies in the zone).
	func point_in(zone: StringName, reach: float = 0.25, up: float = 1.0) -> Vector3:
		for point in side_points(reach, up):
			if Floor1Plan.zone_at(point) == zone:
				return point
		return Vector3.INF

	func other(zone: StringName) -> StringName:
		return zone_b if zone == zone_a else zone_a

	func area_of(zone: StringName) -> StringName:
		if zone == zone_a:
			return area_a
		return area_b if zone == zone_b else &""


class GatePlan:
	extends RefCounted
	var id: StringName
	var kind: GateSpec.Kind
	var requirement: StringName
	var label_key: StringName
	var area_a: StringName
	var area_b: StringName
	## BOLT: the area it opens from.
	var bolt_area: StringName
	var junction: StringName

	## The zone whose module adds the gate (junction gates: Floor1Layout).
	func zone() -> StringName:
		return Floor1Plan.zone_of_area(area_a) if junction == &"" else &""


class HavenPlan:
	extends RefCounted
	var id: StringName
	var zone: StringName
	var room: StringName
	var name_key: StringName
	var area: StringName


class GuardianPlan:
	extends RefCounted
	var id: StringName
	var zone: StringName
	var area: StringName
	var seal: StringName
	var shard: StringName
	var marker: StringName
	var name_key: StringName
	var title_key: StringName


class PickupPlan:
	extends RefCounted
	var id: StringName
	var kind: StringName
	var area: StringName
	var requires: Array[StringName] = []
	var marker: StringName


static var _junctions: Array[Junction] = []
static var _gates: Array[GatePlan] = []
static var _havens: Array[HavenPlan] = []
static var _guardians: Array[GuardianPlan] = []
static var _pickups: Array[PickupPlan] = []


static func junctions() -> Array[Junction]:
	if _junctions.is_empty():
		for row: Array in JUNCTIONS:
			var j := Junction.new()
			j.id = row[0]
			j.zone_a = row[1]
			j.zone_b = row[2]
			j.rect = row[3]
			j.floor_y = row[4]
			j.top_y = row[5]
			j.style = row[6]
			j.gate = row[7]
			j.area_a = row[8] if row[8] != &"" else row[1]
			j.area_b = row[9] if row[9] != &"" else row[2]
			_junctions.append(j)
	return _junctions


static func junction(junction_id: StringName) -> Junction:
	for j in junctions():
		if j.id == junction_id:
			return j
	return null


## Junctions touching [param zone].
static func junctions_of(zone: StringName) -> Array[Junction]:
	var found: Array[Junction] = []
	for j in junctions():
		if j.zone_a == zone or j.zone_b == zone:
			found.append(j)
	return found


static func gates() -> Array[GatePlan]:
	if _gates.is_empty():
		for row: Array in GATES:
			var g := GatePlan.new()
			g.id = row[0]
			g.kind = row[1]
			g.requirement = row[2]
			g.label_key = row[3]
			g.area_a = row[4]
			g.area_b = row[5]
			g.bolt_area = row[6]
			g.junction = row[7]
			_gates.append(g)
	return _gates


static func gate(gate_id: StringName) -> GatePlan:
	for g in gates():
		if g.id == gate_id:
			return g
	return null


## Gates a zone module adds itself (inside the zone).
static func internal_gates(zone: StringName) -> Array[GatePlan]:
	var found: Array[GatePlan] = []
	for g in gates():
		if g.junction == &"" and zone_of_area(g.area_a) == zone:
			found.append(g)
	return found


static func havens() -> Array[HavenPlan]:
	if _havens.is_empty():
		for row: Array in HAVENS:
			var h := HavenPlan.new()
			h.id = row[0]
			h.zone = row[1]
			h.room = row[2]
			h.name_key = row[3]
			h.area = row[4]
			_havens.append(h)
	return _havens


static func haven(haven_id: StringName) -> HavenPlan:
	for h in havens():
		if h.id == haven_id:
			return h
	return null


static func guardians() -> Array[GuardianPlan]:
	if _guardians.is_empty():
		for row: Array in GUARDIANS:
			var g := GuardianPlan.new()
			g.id = row[0]
			g.zone = row[1]
			g.area = row[2]
			g.seal = row[3]
			g.shard = row[4]
			g.marker = row[5]
			g.name_key = row[6]
			g.title_key = row[7]
			_guardians.append(g)
	return _guardians


static func guardian(guardian_id: StringName) -> GuardianPlan:
	for g in guardians():
		if g.id == guardian_id:
			return g
	return null


static func pickups() -> Array[PickupPlan]:
	if _pickups.is_empty():
		for row: Array in PICKUPS:
			var p := PickupPlan.new()
			p.id = row[0]
			p.kind = row[1]
			p.area = row[2]
			p.requires.assign(row[3])
			p.marker = row[4]
			_pickups.append(p)
	return _pickups


static func pickup(pickup_id: StringName) -> PickupPlan:
	for p in pickups():
		if p.id == pickup_id:
			return p
	return null


## The zone holding weapon [param weapon_id] (&"" = a starting weapon).
static func weapon_zone(weapon_id: StringName) -> StringName:
	var spot := pickup(weapon_id)
	return zone_of_area(spot.area) if spot != null and spot.kind == &"weapon" else &""


# --- geometry -------------------------------------------------------------

## [Rect2, y_min, y_max] boxes of [param zone] as AABBs.
static func zone_boxes(zone: StringName) -> Array[AABB]:
	var boxes: Array[AABB] = []
	for entry: Array in ZONE_BOXES.get(zone, []):
		var rect: Rect2 = entry[0]
		var low: float = entry[1]
		var high: float = entry[2]
		boxes.append(AABB(Vector3(rect.position.x, low, rect.position.y), Vector3(rect.size.x, high - low, rect.size.y)))
	return boxes


## The zone whose box holds [param point] (&"" in a wall or outside). A
## point on a face shared by two boxes goes to the first zone listed.
static func zone_at(point: Vector3) -> StringName:
	for zone in ZONES:
		for box in zone_boxes(zone):
			if _holds(box, point):
				return zone
	return &""


## True when the floor-plan [param rect] (on the 0.5 m grid) between
## heights [param y0] and [param y1] lies inside the boxes of [param zone]
## (one box or several together; touching their faces is fine).
static func contains(zone: StringName, rect: Rect2, y0: float, y1: float) -> bool:
	var boxes := zone_boxes(zone)
	var step := ShellCarver.CELL
	var x := rect.position.x + step * 0.5
	while x < rect.end.x:
		var z := rect.position.y + step * 0.5
		while z < rect.end.y:
			# the heights the zone owns over this cell, merged upwards
			var spans: Array[Vector2] = []
			for box in boxes:
				if x > box.position.x and x < box.end.x and z > box.position.z and z < box.end.z:
					spans.append(Vector2(box.position.y, box.end.y))
			spans.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
			var reached := y0
			for span in spans:
				if span.x <= reached + 0.001:
					reached = maxf(reached, span.y)
			if reached < y1 - 0.001:
				return false
			z += step
		x += step
	return true


## Floor-plan bounds of a zone (all its boxes).
static func zone_rect(zone: StringName) -> Rect2:
	var result := Rect2()
	var first := true
	for box in zone_boxes(zone):
		var flat := Rect2(box.position.x, box.position.z, box.size.x, box.size.z)
		result = flat if first else result.merge(flat)
		first = false
	return result


## Floor-plan bounds of the whole floor.
static func bounds() -> Rect2:
	var result := Rect2()
	for i in ZONES.size():
		result = zone_rect(ZONES[i]) if i == 0 else result.merge(zone_rect(ZONES[i]))
	return result


static func zone_color(zone: StringName) -> Color:
	return ZONE_COLORS.get(zone, Color(0.6, 0.6, 0.6))


static func zone_name_key(zone: StringName) -> StringName:
	return ZONE_NAME_KEYS.get(zone, &"")


# --- areas ----------------------------------------------------------------

## Every progress area: the zones, then the sub-areas.
static func areas() -> Array[StringName]:
	var all: Array[StringName] = ZONES.duplicate()
	for area: StringName in SUB_AREAS:
		all.append(area)
	return all


static func zone_of_area(area: StringName) -> StringName:
	if ZONES.has(area):
		return area
	return SUB_AREAS.get(area, &"")


static func _holds(box: AABB, point: Vector3) -> bool:
	var low := box.position
	var high := box.end
	return point.x >= low.x and point.x <= high.x and point.y >= low.y and point.y <= high.y and point.z >= low.z and point.z <= high.z
