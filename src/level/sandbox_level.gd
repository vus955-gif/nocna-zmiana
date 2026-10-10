class_name SandboxLevel
extends Level
## The stand-in level of stage 2a: the grey hall of the 1a combat sandbox
## plus a security booth ("kanciapa", the first haven) in its south-west
## corner, with the upgrade terminal, a monitor desk, lockers and a warm
## ceiling lamp. The booth's only door faces the hall. Exhibits, loot and
## the two weapons are laid out by hand; stage 2b replaces all of this with
## LobbyLevel.

## Inside of the booth (west and south walls are the hall's own).
const BOOTH_MIN := Vector2(-22.0, 13.0)
const BOOTH_MAX := Vector2(-13.0, 22.0)
const BOOTH_HEIGHT := 3.0
## The door in the east wall: z range and height.
const DOOR_Z := Vector2(16.4, 18.6)
const DOOR_HEIGHT := 2.4
const WALL := 0.3
const BOOTH_WALL := Color(0.5, 0.47, 0.42)
const BOOTH_FLOOR := Color(0.33, 0.27, 0.22)
const TERMINAL_SPOT := Vector3(-17.5, 0.0, 13.55)

var region: NavigationRegion3D
## The game whose found weapons are not laid out again (the Museum passes
## its own; GameState when not set).
var game: PersistentState = null


func build() -> void:
	region = NavigationRegion3D.new()
	region.name = "Navigation"
	add_child(region)
	SandboxArena.build(region)
	_build_booth(region)
	SandboxArena.add_lighting(self)
	_light_booth()
	region.bake_navigation_mesh(false)
	player_start = Transform3D(Basis.IDENTITY, Vector3(-17.5, 0.1, 19.0))
	# the terminal stands against the north wall, its screen facing south
	haven_spots = {&"security": Transform3D(Basis(Vector3.UP, PI), TERMINAL_SPOT)}
	haven_zones = {&"security": AABB(
		Vector3(BOOTH_MIN.x + 0.05, -0.1, BOOTH_MIN.y + 0.2),
		Vector3(BOOTH_MAX.x - BOOTH_MIN.x - 0.25, BOOTH_HEIGHT + 0.2, BOOTH_MAX.y - BOOTH_MIN.y - 0.25))}
	spawn_slots = _spawn_slots()
	loot_spots = _loot_spots()
	_place_weapons()


func _build_booth(parent: Node) -> void:
	var mid_x := (BOOTH_MIN.x + BOOTH_MAX.x) * 0.5
	var mid_z := (BOOTH_MIN.y + BOOTH_MAX.y) * 0.5
	var width := BOOTH_MAX.x - BOOTH_MIN.x
	var depth := BOOTH_MAX.y - BOOTH_MIN.y
	var h := BOOTH_HEIGHT
	# north wall, east wall with the door, roof
	Greybox.box(parent, Vector3(mid_x, h * 0.5, BOOTH_MIN.y), Vector3(width + WALL, h, WALL), BOOTH_WALL)
	var south_part := DOOR_Z.x - BOOTH_MIN.y
	var north_part := BOOTH_MAX.y - DOOR_Z.y
	Greybox.box(parent, Vector3(BOOTH_MAX.x, h * 0.5, BOOTH_MIN.y + south_part * 0.5), Vector3(WALL, h, south_part), BOOTH_WALL)
	Greybox.box(parent, Vector3(BOOTH_MAX.x, h * 0.5, DOOR_Z.y + north_part * 0.5), Vector3(WALL, h, north_part), BOOTH_WALL)
	Greybox.box(parent, Vector3(BOOTH_MAX.x, (DOOR_HEIGHT + h) * 0.5, (DOOR_Z.x + DOOR_Z.y) * 0.5), Vector3(WALL, h - DOOR_HEIGHT, DOOR_Z.y - DOOR_Z.x), BOOTH_WALL)
	Greybox.box(parent, Vector3(mid_x, h + WALL * 0.5, mid_z), Vector3(width + WALL, WALL, depth + WALL), BOOTH_WALL)
	# worn linoleum (looks only)
	var floor_mesh := BoxMesh.new()
	floor_mesh.size = Vector3(width - 0.1, 0.01, depth - 0.1)
	var linoleum := MeshInstance3D.new()
	linoleum.mesh = floor_mesh
	linoleum.material_override = Greybox.material(BOOTH_FLOOR)
	linoleum.position = Vector3(mid_x, 0.006, mid_z)
	parent.add_child(linoleum)
	# monitor desk along the west wall, lockers by the south wall
	Greybox.box(parent, Vector3(BOOTH_MIN.x + 0.45, 0.4, mid_z + 1.0), Vector3(0.9, 0.8, 3.2), Color(0.3, 0.22, 0.16))
	for i in 3:
		_monitor(parent, Vector3(BOOTH_MIN.x + 0.3, 0.98, mid_z - 0.1 + i * 1.1))
	for i in 3:
		Greybox.box(parent, Vector3(BOOTH_MIN.x + 1.6 + i * 0.62, 0.95, BOOTH_MAX.y - 0.3), Vector3(0.58, 1.9, 0.5), Color(0.36, 0.4, 0.42))
	var sign := Label3D.new()
	sign.text = tr("HAVEN_SIGN_SECURITY")
	sign.font_size = 72
	sign.pixel_size = 0.004
	sign.modulate = Color(0.95, 0.85, 0.6)
	sign.outline_size = 0
	sign.position = Vector3(BOOTH_MAX.x + WALL * 0.5 + 0.02, DOOR_HEIGHT + 0.3, (DOOR_Z.x + DOOR_Z.y) * 0.5)
	sign.rotation_degrees = Vector3(0.0, 90.0, 0.0)
	parent.add_child(sign)


## A dim CCTV monitor on the desk.
static func _monitor(parent: Node, at: Vector3) -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.4, 0.36, 0.5)
	var body := MeshInstance3D.new()
	body.mesh = mesh
	body.material_override = Greybox.material(Color(0.14, 0.14, 0.15))
	body.position = at
	parent.add_child(body)
	var screen_mesh := BoxMesh.new()
	screen_mesh.size = Vector3(0.01, 0.28, 0.4)
	var screen := MeshInstance3D.new()
	screen.mesh = screen_mesh
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color(0.05, 0.07, 0.08)
	glow.emission_enabled = true
	glow.emission = Color(0.45, 0.7, 0.8)
	glow.emission_energy_multiplier = 0.8
	screen.material_override = glow
	screen.position = at + Vector3(0.205, 0.0, 0.0)
	parent.add_child(screen)


func _light_booth() -> void:
	var lamp := OmniLight3D.new()
	lamp.name = "BoothLamp"
	lamp.light_color = Color(1.0, 0.8, 0.55)
	lamp.light_energy = 1.5
	lamp.omni_range = 9.0
	lamp.shadow_enabled = true
	lamp.position = Vector3((BOOTH_MIN.x + BOOTH_MAX.x) * 0.5, BOOTH_HEIGHT - 0.35, (BOOTH_MIN.y + BOOTH_MAX.y) * 0.5 + 1.0)
	add_child(lamp)
	var shade_mesh := CylinderMesh.new()
	shade_mesh.top_radius = 0.18
	shade_mesh.bottom_radius = 0.3
	shade_mesh.height = 0.18
	var shade := MeshInstance3D.new()
	shade.mesh = shade_mesh
	var bulb := StandardMaterial3D.new()
	bulb.albedo_color = Color(0.2, 0.18, 0.15)
	bulb.emission_enabled = true
	bulb.emission = Color(1.0, 0.8, 0.55)
	bulb.emission_energy_multiplier = 1.5
	shade.material_override = bulb
	shade.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shade.position = lamp.position + Vector3(0.0, 0.2, 0.0)
	add_child(shade)


## The 1a starting exhibits (dormant) plus two groups that are awake from
## the start. All in encounter set 0 (2b's NightDirector picks sets).
static func _spawn_slots() -> Array[SpawnSlot]:
	var wax: Array[StringName] = [&"wax"]
	var wolf: Array[StringName] = [&"wolf"]
	var knight: Array[StringName] = [&"knight"]
	return [
		SpawnSlot.make(Vector3(-6.0, 0.1, -6.0), &"hall", 0, wax),
		SpawnSlot.make(Vector3(-4.5, 0.1, -7.5), &"hall", 0, wax),
		SpawnSlot.make(Vector3(-7.5, 0.1, -8.5), &"hall", 0, wax),
		SpawnSlot.make(Vector3(11.0, 0.1, -10.0), &"hall", 0, wolf),
		SpawnSlot.make(Vector3(12.5, 0.1, -9.0), &"hall", 0, wolf),
		SpawnSlot.make(Vector3(-10.0, 3.9, -18.0), &"mezzanine", 0, knight),
		SpawnSlot.make(Vector3(16.0, 0.1, 6.0), &"hall", 0, wax, false),
		SpawnSlot.make(Vector3(17.2, 0.1, 7.3), &"hall", 0, wax, false),
		SpawnSlot.make(Vector3(-16.0, 0.1, 4.0), &"hall", 0, wolf, false),
	]


static func _loot_spots() -> Array[LootSpot]:
	return [
		LootSpot.make(Vector3(18.0, 0.5, 18.0), &"hall"),
		LootSpot.make(Vector3(-18.0, 0.5, -10.0), &"hall"),
		LootSpot.make(Vector3(-12.0, 0.5, 4.0), &"hall"),
		LootSpot.make(Vector3(18.0, 0.5, -18.0), &"hall"),
		LootSpot.make(Vector3(0.0, 4.25, -20.0), &"mezzanine"),
		LootSpot.make(Vector3(8.0, 4.25, -20.0), &"mezzanine"),
	]


## The pistol on the dais, the shotgun at the far end of the mezzanine; a
## weapon already found is not laid out again.
func _place_weapons() -> void:
	var spots := {&"pistol": Vector3(0.0, 0.6, 0.0), &"shotgun": Vector3(19.5, SandboxArena.MEZZANINE_Y, -20.0)}
	var owner_state: PersistentState = game if game != null else GameState
	for id in spots:
		if not owner_state.has_weapon(id):
			var pickup := WeaponPickup.make(id, spots[id])
			pickup.game = game
			add_child(pickup)
