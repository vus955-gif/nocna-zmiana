class_name LobbyLevel
extends Level
## The museum lobby (stage 2b): hall with balcony and stairs, sculpture
## gallery, armory, nature diorama, technical corridors, staff corridor,
## security room, hidden broom closet and the secret rooms. Built from
## LobbyLayout by LevelBuilder. Besides the Level contract it exposes named
## markers for later stages, the doors, the room graph and a description
## for NightDirector.

var layout: LevelLayout
## Marker id -> Transform3D (origin on the object / floor, -Z = its front):
## fuse points, crystal candidate cases, pistol locker, ticket drawer,
## notes, secrets, CCTV wall, grate, fuse box, shotgun case.
var markers: Dictionary = {}
## Opening id -> Door.
var doors: Dictionary = {}
## Navigation source of the walkable level (layer 1).
var walk_region: NavigationRegion3D
## Navigation source of the havens (layer 2; exhibits never use it).
var haven_region: NavigationRegion3D
## Roofs, wall above doorways, decoration: not a navigation source.
var structure: Node3D
## Environment, moon, lamps.
var lights: Node3D
## Bakes the regions; rebakes when a door opens or shuts.
var navigation: LevelNavigation
var _builder: LevelBuilder = null
## Tonight's draw. Set it before build() and the locked door is shut before
## the first bake; or call apply_night() later.
var night: NightConfig = null
## True: the museum's T-Rex skeleton stands on its pedestal as a static
## prop (dev viewer, screenshots). The game sets false before build() and
## puts the live boss there instead.
var boss_stand_in: bool = true

## The lowest floor is the undercroft stairwell (-5 m).
const KILL_PLANE := -15.0


func _init() -> void:
	layout = LobbyLayout.create()
	player_start = layout.player_start
	haven_spots = layout.haven_spots
	# the whole room is the safe zone: the Museum's Haven puts its
	# exhibit-only walls on the zone faces, i.e. across the doorway
	for room in layout.rooms:
		if room.haven and haven_spots.has(room.id):
			var part := room.parts[0]
			haven_zones[room.id] = AABB(Vector3(part.position.x, room.floor_y, part.position.y), Vector3(part.size.x, room.height(), part.size.y))
	spawn_slots = layout.spawn_slots
	loot_spots = layout.loot_spots
	markers = layout.markers
	kill_plane_y = KILL_PLANE


func build() -> void:
	walk_region = NavigationRegion3D.new()
	walk_region.name = "Walkable"
	add_child(walk_region)
	haven_region = NavigationRegion3D.new()
	haven_region.name = "Havens"
	add_child(haven_region)
	structure = Node3D.new()
	structure.name = "Structure"
	add_child(structure)
	var builder := LevelBuilder.new(layout, walk_region, haven_region, structure)
	if not boss_stand_in:
		builder.skip_kits.append(&"trex")
	builder.build()
	_builder = builder
	_hang_scenes()
	doors = builder.doors
	if night != null:
		_reset_doors(night.locked_door)
	lights = Node3D.new()
	lights.name = "Lights"
	add_child(lights)
	# the lobby's light recipe (SDFGI, fog volumes, probes) goes with the kit;
	# the greybox keeps the plain lighting
	LevelLighting.build(layout, lights, builder, builder.art)
	navigation = LevelNavigation.new()
	navigation.name = "Navigation"
	add_child(navigation)
	navigation.setup(walk_region, haven_region)
	navigation.bake_now()
	navigation.watch_doors(doors)


## The scenic paintings on their wall spots (LobbyLayout.SCENE_SPOTS):
## landscapes, seas and still lifes that never wake, so the walls get
## variety without giving the live portraits away.
func _hang_scenes() -> void:
	var holder := Node3D.new()
	holder.name = "Scenes"
	structure.add_child(holder)
	for i in LobbyLayout.SCENE_SPOTS.size():
		var spot: StringName = LobbyLayout.SCENE_SPOTS[i]
		if markers.has(spot):
			holder.add_child(WallPainting.create(markers[spot], PaintingArt.SCENE_IDS[i % PaintingArt.SCENE_IDS.size()]))


## Everything NightDirector needs; works before build().
func describe() -> LevelDescription:
	return LobbyLayout.describe(layout)


## Applies a night drawn after build(): every door back to its start (open
## doors open and unlocked, false panels and the grate shut), then tonight's
## door locked. The navigation rebakes by itself. (The game builds a fresh
## level each night; this keeps a reused level just as clean.)
func apply_night(config: NightConfig) -> void:
	night = config
	_reset_doors(config.locked_door)


func _reset_doors(locked: StringName) -> void:
	for door: Door in doors.values():
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


## Every wall face seen from inside a room, for stage-3 wall modules
## (computed on the first call, then cached).
func wall_faces() -> Array[ShellCarver.WallFace]:
	return _builder.wall_faces() if _builder != null else LevelBuilder.new(layout, null, null, null).wall_faces()


func room_at(point: Vector3) -> StringName:
	return layout.room_at(point)


## Hides roofs, ceilings and skylights (the top-down dev view).
func set_roof_visible(on: bool) -> void:
	for child in structure.get_children():
		var kit: StringName = child.get_meta(&"kit", &"")
		if kit in [&"ceiling", &"lintel", &"wall", &"skylight"]:
			(child as Node3D).visible = on
	# the kit's coffers and beams go with the ceilings
	var coffers := structure.get_node_or_null(^"Dressing/Ceilings") as Node3D
	if coffers != null:
		coffers.visible = on
