class_name MuseumFloorLevel
extends Level
## Floor I, "the Great Court" (stage P1): the whole museum floor built from
## Floor1Layout by LevelBuilder, so far as a greybox in the zones' colours
## (art = false). Fulfils the Level contract (the guard starts in the
## security booth; six havens with their rooms as safe zones; spawn slots;
## loot spots) and adds what the floor's game needs: markers, doors, gates
## (closed and locked until opened; open_gate() opens one for good), the
## room graph and a description for NightDirector, and the zone of a point.
##
## Navigation: one walkable region per tile (LevelNavigation zoned:
## the static colliders under [member walk_static] parsed once, the doors
## and other changing sources under [member walk_dynamic] at each bake; a
## door rebakes only the boxes round it) and one haven region.

var layout: LevelLayout
## Marker id -> Transform3D (origin on the object / floor, -Z = its front).
var markers: Dictionary = {}
## Opening id -> Door (every junction and internal door with a style).
var doors: Dictionary = {}
## Holds the walkable sources and the zones' regions (no mesh of its own).
var walk_region: NavigationRegion3D
## The walkable sources: built once (shell, pieces, ramps) and changing
## (doors, the canoe's deck, a display's plinth: add_walk_source()).
var walk_static: Node3D
var walk_dynamic: Node3D
var haven_region: NavigationRegion3D
var structure: Node3D
var lights: Node3D
## With the art: switches off the lamps, motes, probes and decor of rooms
## far from the camera in the room graph (null for the greybox).
var culler: RoomCuller = null
var navigation: LevelNavigation
## Tonight's draw (its locked door shut before the first bake).
var night: NightConfig = null
## Gates open from the start (PersistentState.gates_open). Set before
## build(); their doors are open for the first bake.
var gates_open: Array[StringName] = []
## Greybox (false) or the art kit (stage P2: the zones of ART_ZONES wear
## it, the rest stays greybox until stage P3 dresses it). Set before
## build(); its default is [member dress_default].
var art: bool = MuseumFloorLevel.dress_default
## False: build() leaves the navigation out (art checks and the tour's dry
## run need only the looks).
var bake_navigation: bool = true
## Piece kits left out of the build (set before build(): the game leaves
## out the greybox stand-ins of the real locks' bodies, GateLocks).
var skip_kits: Array[StringName] = []
## Milliseconds of the last build() (geometry and lights, without the
## navigation bake) and of the navigation bake.
var build_msec: int = 0
var bake_msec: int = 0
var _builder: LevelBuilder = null

## The crypt stairs reach -6 m; deeper stairs into the dark come later.
const KILL_PLANE := -25.0
## The zones dressed with the art kit (stage P2: the hub and Egypt; stage
## P3 adds the other wings, the basement and the roof as they are dressed:
## Greece, the Enlightenment and the basement).
const ART_ZONES: Array[StringName] = [&"court", &"entrance", &"booth", &"north_hall", &"egypt", &"greece", &"enlightenment", &"basement"]
## Rooms open to the night sky (the roof): with the art their ceilings and
## light wells have no look and cast no shadow, so the moon falls through
## the court's glass roof beneath them.
const SKY_ROOMS: Array[StringName] = [&"roof_catwalks", &"roof_plant"]

## Whether a new Floor I level wears the art (the game: true; the headless
## test suite sets false before every test - the greybox builds fast - and
## the art tests switch it on).
static var dress_default: bool = true
## Each zone's pace (design 7.2): about this many exhibits per 100 m2 of
## a room's floor at most (NightDirector trims a bigger drawn set; the set
## pieces of ALWAYS_SET come on top). Tuned so that a
## night on the whole floor (every wing open) holds about 126 exhibits, down
## from about 176 (design 4.6: 90-120; the owner's aim about 129) - the
## wings 0.45-0.6, fewer in the hub, the tight basement and on the roof.
const ZONE_DENSITY := {
	&"court": 0.3, &"entrance": 0.4, &"booth": 0.3, &"north_hall": 0.4,
	&"egypt": 0.6, &"assyria": 0.45, &"greece": 0.45, &"enlightenment": 0.45,
	&"asia": 0.45, &"americas": 0.5, &"basement": 0.2, &"roof": 0.25,
}
## Navigation tiles (m; on the 0.25 m cells) and their height span.
const NAV_TILE := 32.0
const NAV_BOTTOM := -20.0
const NAV_TOP := 40.0
## Markers of the painting spots start with this (portrait_<zone>_<n>).
const PORTRAIT_PREFIX := "portrait_"


func _init() -> void:
	layout = Floor1Layout.create()
	player_start = layout.player_start
	haven_spots = layout.haven_spots
	for haven in Floor1Plan.havens():
		var room := layout.room(haven.room)
		if room == null or not haven_spots.has(haven.id):
			continue
		var part := room.parts[0]
		haven_zones[haven.id] = AABB(Vector3(part.position.x, room.floor_y, part.position.y), Vector3(part.size.x, room.height(), part.size.y))
	spawn_slots = layout.spawn_slots
	loot_spots = layout.loot_spots
	markers = layout.markers
	kill_plane_y = KILL_PLANE


func build() -> void:
	var started := Time.get_ticks_msec()
	walk_region = NavigationRegion3D.new()
	walk_region.name = "Walkable"
	add_child(walk_region)
	walk_static = Node3D.new()
	walk_static.name = "Static"
	walk_region.add_child(walk_static)
	walk_dynamic = Node3D.new()
	walk_dynamic.name = "Dynamic"
	walk_region.add_child(walk_dynamic)
	haven_region = NavigationRegion3D.new()
	haven_region.name = "Havens"
	add_child(haven_region)
	structure = Node3D.new()
	structure.name = "Structure"
	add_child(structure)
	_builder = LevelBuilder.new(layout, walk_static, haven_region, structure)
	_builder.door_root = walk_dynamic
	_builder.skip_kits = skip_kits
	_builder.art = art and LevelArt.enabled and ArtLibrary.models_enabled
	if _builder.art:
		Floor1Art.prepare(layout)
		_builder.art_rooms = art_rooms(layout)
		for room_id in SKY_ROOMS:
			_builder.sky_rooms[room_id] = &"court"
	_builder.build()
	doors = _builder.doors
	_reset_doors()
	lights = Node3D.new()
	lights.name = "Lights"
	add_child(lights)
	if _builder.art:
		# stage P2: the floor's light recipe, the dust in the moonbeams, the
		# rooms far in the graph switched off, the shell's occluders
		LevelLighting.build(layout, lights, _builder, Floor1LightRecipe.create(layout))
		Floor1LightRecipe.atmosphere(layout, lights, _builder.dressing, _builder.art_rooms)
		GraphicsQuality.apply_level(lights)
		culler = RoomCuller.new()
		culler.name = "RoomCuller"
		add_child(culler)
		# (decor processes live in the pieces' looks too: the clocks' pendulums)
		culler.setup(layout, [lights, structure, walk_static, haven_region])
		var occluders := LevelOccluders.build([walk_static, haven_region, structure])
		if occluders != null:
			add_child(occluders)
	else:
		LevelLighting.build(layout, lights, _builder, false)
	build_msec = Time.get_ticks_msec() - started
	if not bake_navigation:
		return
	started = Time.get_ticks_msec()
	navigation = LevelNavigation.new()
	navigation.name = "Navigation"
	add_child(navigation)
	navigation.setup_zones(walk_region, walk_static, walk_dynamic, haven_region, baking_boxes())
	navigation.bake_now()
	navigation.watch_doors(doors)
	bake_msec = Time.get_ticks_msec() - started


## The rooms of [param floor_layout] that wear the art (room id -> true):
## every room of the zones in ART_ZONES.
static func art_rooms(floor_layout: LevelLayout) -> Dictionary:
	var rooms := {}
	for room in floor_layout.rooms:
		if ART_ZONES.has(room.zone):
			rooms[room.id] = true
	return rooms


## Carves the floor's shell into ShellCarver's cache (read from the disk
## cache when it holds it; pure data): the loading screen runs it before
## the museum is built.
static func prewarm() -> void:
	ShellCarver.carve(LevelBuilder.new(Floor1Layout.create(), null, null, null).shell_volumes())


## The navigation's baking boxes: square tiles of NAV_TILE m over the
## floor (the zones' own boxes leave the walls between zones, junctions
## included, outside every box), full height, those over a zone only.
static func baking_boxes(tile: float = NAV_TILE) -> Array[AABB]:
	var bounds := Floor1Plan.bounds().grow(1.0)
	var x0 := floorf(bounds.position.x / tile) * tile
	var z0 := floorf(bounds.position.y / tile) * tile
	var flat: Array[Rect2] = []
	for zone in Floor1Plan.ZONES:
		for box in Floor1Plan.zone_boxes(zone):
			flat.append(Rect2(box.position.x, box.position.z, box.size.x, box.size.z).grow(1.0))
	var found: Array[AABB] = []
	var x := x0
	while x < bounds.end.x:
		var z := z0
		while z < bounds.end.y:
			var cell := Rect2(x, z, tile, tile)
			if flat.any(func(area: Rect2) -> bool: return area.intersects(cell)):
				found.append(AABB(Vector3(x, NAV_BOTTOM, z), Vector3(tile, NAV_TOP - NAV_BOTTOM, tile)))
			z += tile
		x += tile
	return found


## Adds [param node] (a collider exhibits walk on or round) to the walkable
## sources and rebakes round it.
func add_walk_source(node: Node3D) -> void:
	navigation.add_source(node)


## Everything NightDirector needs; works before build().
func describe() -> LevelDescription:
	return describe_layout(layout)


## Floor1Layout's description of [param floor_layout] plus what the night
## needs of Floor I: every room's area and zone with the zones' densities,
## the painting spots (portrait_* markers, in the layout's order) and the
## havens among the rooms that must stay reachable.
static func describe_layout(floor_layout: LevelLayout) -> LevelDescription:
	var description := Floor1Layout.describe(floor_layout)
	for room in floor_layout.rooms:
		description.room_areas[room.id] = room.area()
		description.room_zones[room.id] = room.zone
		if room.haven and not description.objective_rooms.has(room.id):
			description.objective_rooms.append(room.id)
	description.zone_density = ZONE_DENSITY.duplicate()
	for marker: StringName in floor_layout.markers:
		if String(marker).begins_with(PORTRAIT_PREFIX):
			description.portrait_spots.append(marker)
	return description


func room_at(point: Vector3) -> StringName:
	return layout.room_at(point)


## The zone of the room at [param point] (&"" outside every room).
func zone_at(point: Vector3) -> StringName:
	var room := layout.room(layout.room_at(point))
	return room.zone if room != null else &""


func is_gate_open(gate_id: StringName) -> bool:
	return gates_open.has(gate_id)


## Opens [param gate_id] for good: its door unlocks and opens (the
## navigation rebakes by itself). The caller records it in the save.
func open_gate(gate_id: StringName, instant: bool = false) -> void:
	if not gates_open.has(gate_id):
		gates_open.append(gate_id)
	var gate := layout.gate(gate_id)
	if gate == null or not doors.has(gate.opening):
		return
	var door: Door = doors[gate.opening]
	door.unlock()
	door.open(instant)


## Applies a night drawn after build(): doors back to their start, gates as
## they are, tonight's door locked.
func apply_night(config: NightConfig) -> void:
	night = config
	_reset_doors()


## Every gate's door closed and locked unless the gate is open; panels
## shut; the night's lockable door locked; every other door open.
func _reset_doors() -> void:
	var locked: StringName = night.locked_door if night != null else &""
	for door: Door in doors.values():
		var gate := layout.gate_of_opening(door.id)
		if gate != null:
			if gates_open.has(gate.id):
				door.unlock()
				door.open(true)
			else:
				door.lock(true)
			continue
		match door.style:
			OpeningSpec.DoorStyle.PANEL, OpeningSpec.DoorStyle.GATE:
				door.unlock()
				door.close(true)
			_:
				if door.id == locked and door.link == RoomGraph.Kind.LOCKABLE:
					door.lock(true)
				else:
					door.unlock()
					door.open(true)


## Every wall face seen from inside a room (for the art stages).
func wall_faces() -> Array[ShellCarver.WallFace]:
	return _builder.wall_faces() if _builder != null else LevelBuilder.new(layout, null, null, null).wall_faces()
