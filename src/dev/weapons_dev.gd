class_name WeaponsDev
extends ContentDev
## Dev arena of Floor I's weapons and gate locks (tools/run_weapons.sh): the
## content arena plus the three new weapons (all eight, ammo full), their
## ammo boxes, a gallery of every gate lock under the mezzanine (each in a
## doorway with its name above), dormant wolves before the west wall (try
## pinning them with the harpoon) and heavier wax figures in the open (the
## harpoon pulls them). Keys on top of the content arena's: 6-8 the new
## weapons, G all weapons and full ammo, K fresh locks and exhibits, U every
## upgrade at the top (the master finish on every weapon), J no upgrades.
## Nothing is saved.

const NEW_WEAPONS: Array[StringName] = [&"rifle_hunt", &"harpoon", &"hwacha"]
## The lock gallery: under the mezzanine (its underside at 3.25 m), fronts
## facing south into the hall, clear of the crate at x -4 and the ramp.
const GALLERY_Z := -14.6
const GALLERY_XS: Array[float] = [-18.0, -13.6, -9.2, -0.4, 4.0, 8.4, 12.4]
## The canoe needs room to fall: it stands out in the hall.
const CANOE_AT := Vector3(-17.0, 0.0, 6.0)
const WOLF_SPOTS: Array[Vector3] = [Vector3(-20.6, 0.1, 10.0), Vector3(-20.6, 0.1, 12.5), Vector3(-20.6, 0.1, 15.0)]
const PULL_SPOTS: Array[Vector3] = [Vector3(-4.0, 0.1, 2.0), Vector3(4.0, 0.1, 2.5)]

var locks: Array[GateLock] = []
var locks_root: Node3D


func _ready() -> void:
	super()
	for id in NEW_WEAPONS:
		player.weapons.give(load("res://src/weapons/data/%s.tres" % id))
	refill_ammo()
	player.weapons.select_id(&"rifle_hunt")
	hud.help_keys = ["HUD_HELP_CONTROLS_P1", "HUD_HELP_WEAPONS_DEV", "HUD_HELP_TIPS"]
	locks_root = Node3D.new()
	locks_root.name = "Locks"
	add_child(locks_root)
	build_locks()
	_place_targets()


## A fresh gallery of every gate lock (and the canoe out in the hall).
func build_locks() -> void:
	for child in locks_root.get_children():
		locks_root.remove_child(child)
		child.queue_free()
	locks.clear()
	var rope := RopeLock.new()
	rope.height = 3.1
	rope.hang = 1.8
	var canoe := HookLock.new()
	canoe.mode = HookLock.Mode.SWING
	canoe.size = Vector2(1.0, 5.0)
	var gallery: Array[GateLock] = [ChainLock.new(), BoardsLock.new(), CrackedWall.new(), rope, HookLock.new(),
		BoltLock.new(), PowerShutter.new()]
	for i in gallery.size():
		var lock := gallery[i]
		lock.gate_id = StringName("dev_%d" % i)
		lock.transform = Transform3D(Basis(Vector3.UP, PI), Vector3(GALLERY_XS[i], 0.0, GALLERY_Z))
		locks_root.add_child(lock)
		locks.append(lock)
		if not lock is RopeLock:
			_doorway(lock)
		_name_plate(lock)
	canoe.gate_id = &"dev_canoe"
	canoe.transform = Transform3D(Basis(Vector3.UP, -PI * 0.5), CANOE_AT)
	locks_root.add_child(canoe)
	locks.append(canoe)


## Every upgrade at its top level (the master finish on every weapon), or
## none.
func set_all_upgrades(top: bool) -> void:
	var levels := {}
	if top:
		for entry in UpgradeCatalog.all():
			levels[entry.id] = entry.max_level()
	player.apply_upgrades(levels)


func refill_ammo() -> void:
	super()
	for state in player.weapons.owned:
		state.magazine = state.data.magazine_size
		state.reserve = state.data.max_reserve


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo:
		match key.physical_keycode:
			KEY_G:
				for id in NEW_WEAPONS:
					player.weapons.give(load("res://src/weapons/data/%s.tres" % id))
			KEY_K:
				build_locks()
				_place_targets()
			KEY_U:
				set_all_upgrades(true)
			KEY_J:
				set_all_upgrades(false)
	super(event)


func _place_pickups() -> void:
	super()
	var extra := [
		[Pickup.Type.HUNT_ROUNDS, 10, Vector3(-2.0, 0.5, 14.0)],
		[Pickup.Type.HARPOONS, 6, Vector3(0.0, 0.5, 14.0)],
		[Pickup.Type.ROCKETS, 3, Vector3(2.0, 0.5, 14.0)],
	]
	for entry in extra:
		var pickup := Pickup.new()
		pickup.type = entry[0]
		pickup.amount = entry[1]
		pickup.position = entry[2]
		add_child(pickup)


## Dormant wolves with the wall at their backs, heavier wax figures out in
## the open.
func _place_targets() -> void:
	for at in WOLF_SPOTS:
		var wolf := spawn(&"wolf", at, false)
		if wolf != null:
			wolf.face(at + Vector3.RIGHT)
	for at in PULL_SPOTS:
		var figure := WaxFigure.new()
		figure.max_health = 120.0
		figure.position = at
		figure.target = player
		enemies_root.add_child(figure)


## Stone jambs and a lintel round a lock, so it reads as a doorway.
func _doorway(lock: GateLock) -> void:
	var frame := Node3D.new()
	frame.name = "Doorway"
	lock.add_child(frame)
	var stone := LockArt.tile("limestone", 1.0, Color(0.7, 0.68, 0.62))
	var w := lock.size.x
	var h := lock.size.y
	for side: float in [-1.0, 1.0]:
		LockArt.box(frame, Vector3(0.4, h + 0.4, 0.6), Vector3(side * (w * 0.5 + 0.2), (h + 0.4) * 0.5, 0.0), stone)
	LockArt.box(frame, Vector3(w + 0.8, 0.4, 0.6), Vector3(0.0, h + 0.2, 0.0), stone)


func _name_plate(lock: GateLock) -> void:
	var plate := Label3D.new()
	plate.text = lock.prompt_text().get_slice(" — ", 0).to_upper()
	plate.font_size = 48
	plate.pixel_size = 0.004
	plate.modulate = Color(0.95, 0.85, 0.6)
	plate.outline_size = 8
	# on the lintel's face (the rope has no doorway: under its pulley)
	plate.position = Vector3(0.0, lock.size.y + 0.2, -0.32) if not lock is RopeLock else Vector3(0.0, 0.5, -0.35)
	plate.rotation.y = PI   # reads from the lock's front (-Z)
	lock.add_child(plate)
