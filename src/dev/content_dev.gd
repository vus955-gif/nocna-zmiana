class_name ContentDev
extends Sandbox
## Dev arena for the content pass (tools/run_content.sh): the combat
## sandbox plus every weapon (gatling and flare gun included, ammo full),
## the chained gatling display and the fire cabinet (dev mode: nothing is
## saved), a gallery wall on the west side where live portraits hang among
## ordinary paintings, a dormant raptor pack and a crowd of wax figures,
## belt and flare pickups. Keys (on top of the sandbox's F5-F8):
## F9 raptor pack, P new portrait wall, G all weapons + full ammo,
## L lights on / off (try the flares in the dark).

const WEAPONS: Array[StringName] = [&"taser", &"pistol", &"shotgun", &"gatling", &"flare"]
## The gallery wall: the sandbox's west wall (inner face x = -22), facing east.
const GALLERY_X := -22.0
const GALLERY_SPOTS: Array[float] = [-9.0, -4.5, 0.0, 4.5, 9.0]
const GALLERY_HEIGHT := 2.3
const LIVE_PORTRAITS := 2
const DISPLAY_AT := Vector3(19.2, 0.0, 5.0)
const CABINET_AT := Vector3(8.0, 1.4, 22.0)

var display: ChainedDisplay
var cabinet: EmergencyCabinet
var gallery: Node3D
var portraits: Array[Portrait] = []
var lights_on: bool = true

var _environment: Environment
var _lamps: Array[Light3D] = []


func _ready() -> void:
	super()
	for id in WEAPONS:
		player.weapons.give(load("res://src/weapons/data/%s.tres" % id))
	refill_ammo()
	player.weapons.select_id(&"gatling")
	hud.help_keys = ["HUD_HELP_CONTROLS_P1", "HUD_HELP_CONTENT_P1", "HUD_HELP_TIPS"]
	display = ChainedDisplay.create(Transform3D(Basis(Vector3.UP, PI * 0.5), DISPLAY_AT))
	display.persistent = false
	add_child(display)
	cabinet = EmergencyCabinet.create(Transform3D(Basis.IDENTITY, CABINET_AT))
	cabinet.persistent = false
	add_child(cabinet)
	gallery = Node3D.new()
	gallery.name = "Gallery"
	add_child(gallery)
	hang_gallery()
	for child in get_children():
		if child is WorldEnvironment:
			_environment = (child as WorldEnvironment).environment
		elif child is Light3D:
			_lamps.append(child)


## Every magazine and reserve full (key G).
func refill_ammo() -> void:
	for state in player.weapons.owned:
		state.magazine = state.data.magazine_size
		state.reserve = state.data.max_reserve
		state.battery = state.data.battery_max


## A fresh gallery wall: LIVE_PORTRAITS real portraits (awake-able) among
## ordinary paintings, variants drawn at random.
func hang_gallery() -> void:
	for child in gallery.get_children():
		gallery.remove_child(child)
		child.queue_free()
	portraits.clear()
	var ids := PaintingArt.ids()
	var spots := GALLERY_SPOTS.duplicate()
	var live: Array[int] = []
	while live.size() < LIVE_PORTRAITS:
		var pick := _rng.randi_range(0, spots.size() - 1)
		if not live.has(pick):
			live.append(pick)
	for i in spots.size():
		var id: StringName = ids[_rng.randi_range(0, ids.size() - 1)]
		var at := Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(GALLERY_X, GALLERY_HEIGHT, spots[i]))
		if live.has(i):
			var portrait := Portrait.create_on_wall(at, id)
			portrait.target = player
			gallery.add_child(portrait)
			portraits.append(portrait)
		else:
			gallery.add_child(WallPainting.create(at, id))


## A raptor pack, awake, at one of the spawn points.
func spawn_pack() -> Array[Raptor]:
	var at: Vector3 = SPAWN_POINTS[_rng.randi_range(0, SPAWN_POINTS.size() - 1)]
	return RaptorPack.spawn(enemies_root, at, _rng.randi_range(RaptorPack.MIN_SIZE, RaptorPack.MAX_SIZE), player, true, _rng)


## Room lights and ambient off (only the flashlight, flares and glowing
## things are left) or back on.
func set_lights(on: bool) -> void:
	lights_on = on
	for lamp in _lamps:
		lamp.visible = on
	if _environment != null:
		_environment.ambient_light_energy = 0.55 if on else 0.04
		_environment.volumetric_fog_density = 0.012 if on else 0.02


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo:
		match key.physical_keycode:
			KEY_F9:
				spawn_pack()
			KEY_P:
				hang_gallery()
			KEY_G:
				for id in WEAPONS:
					player.weapons.give(load("res://src/weapons/data/%s.tres" % id))
				refill_ammo()
			KEY_L:
				set_lights(not lights_on)
	super(event)


func _spawn_starting_exhibits() -> void:
	# a crowd for the gatling, a pack on display for the flanking
	for i in 6:
		spawn(&"wax", Vector3(-6.0 + (i % 3) * 1.6, 0.1, -7.0 - (i / 3) * 1.8), false)
	RaptorPack.spawn(enemies_root, Vector3(10.0, 0.1, -8.0), 4, player, false)
	spawn(&"knight", Vector3(-10.0, 3.9, -18.0), false)


func _place_pickups() -> void:
	super()
	var extra := [
		[Pickup.Type.RIFLE, 50, Vector3(-10.0, 0.5, 18.0)],
		[Pickup.Type.RIFLE, 50, Vector3(14.0, 0.5, 18.0)],
		[Pickup.Type.FLARES, 3, Vector3(-18.0, 0.5, 6.0)],
		[Pickup.Type.FLARES, 3, Vector3(4.0, 0.5, 12.0)],
	]
	for entry in extra:
		var pickup := Pickup.new()
		pickup.type = entry[0]
		pickup.amount = entry[1]
		pickup.position = entry[2]
		add_child(pickup)
