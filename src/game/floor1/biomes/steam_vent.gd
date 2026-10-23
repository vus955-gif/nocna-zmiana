class_name SteamVent
extends BiomeDevice
## The basement's steam (plan 2026-10-21-mechaniki-biomow, mechanic 7): a
## cracked valve on a corridor's steam main. Every PERIOD s (quicker as the
## night escalates) the pressure blows it: TELL s of rising hiss and a
## gauge's needle in the red, then BURST s of steam blasting across the
## corridor - a plume from the wall to the far wall, HALF_WIDTH m either side
## of the valve, floor to ceiling. In it:
## - the guard is scalded GUARD_PER_SECOND,
## - an exhibit in a hurry (alarmed) is scalded EXHIBIT_PER_SECOND and is
##   blind while in it and BLIND_HOLD s after; the runaways at rest know the
##   cellar's rhythm and keep out of it.
## The wheel on the wall beside it (E) shuts the main VALVE_TIME s, a burst
## stopping at once. The ring's corridors go round: nothing is ever cut off.
## No collision: the steam is a cloud, the valve and the wheel are on the
## wall.

enum Phase { QUIET, HISSING, VENTING }

const PERIOD := 14.0
## The cycle at the night's height (BiomeMechanics.intensity 1).
const FAST_PERIOD := 10.0
const TELL := 1.0
const BURST := 2.5
const VALVE_TIME := 45.0
const GUARD_PER_SECOND := 10.0
const EXHIBIT_PER_SECOND := 16.0
const HALF_WIDTH := 1.0
const BLIND_RANGE := 1.5
const BLIND_HOLD := 0.5
const TICK := 0.25
## The steam main's height on the wall (basement.gd PIPES: 3.15 over the floor).
const MAIN_Y := 2.95
const IRON := Color(0.26, 0.25, 0.24)
const BRASS := Color(0.78, 0.6, 0.28)
const STEAM := Color(0.88, 0.9, 0.94)

## The ring's and the tunnel's vents: the wall point at the floor, the way
## into the corridor, its width ("across") and height, the wheel's wall
## point, and where in its cycle it starts.
const PLACES := [
	{"id": &"basement_steam_north_west", "room": &"basement_corridor_north", "at": Vector3(-14.5, -6.0, -38.0), "dir": Vector3(0, 0, 1),
		"across": 3.5, "height": 3.5, "valve": Vector3(-17.0, -6.0, -38.0), "offset": 0.0},
	{"id": &"basement_steam_north_east", "room": &"basement_corridor_north", "at": Vector3(12.0, -6.0, -38.0), "dir": Vector3(0, 0, 1),
		"across": 3.5, "height": 3.5, "valve": Vector3(9.5, -6.0, -38.0), "offset": 7.0},
	{"id": &"basement_steam_west", "room": &"basement_corridor_west", "at": Vector3(-30.0, -6.0, -2.0), "dir": Vector3(1, 0, 0),
		"across": 3.5, "height": 3.5, "valve": Vector3(-30.0, -6.0, 0.5), "offset": 3.0},
	{"id": &"basement_steam_east", "room": &"basement_corridor_east", "at": Vector3(30.0, -6.0, 10.0), "dir": Vector3(-1, 0, 0),
		"across": 3.5, "height": 3.5, "valve": Vector3(30.0, -6.0, 12.5), "offset": 10.0},
	{"id": &"basement_steam_south", "room": &"basement_corridor_south", "at": Vector3(-6.0, -6.0, 30.0), "dir": Vector3(0, 0, -1),
		"across": 3.5, "height": 3.5, "valve": Vector3(-8.5, -6.0, 30.0), "offset": 5.0},
	{"id": &"basement_steam_tunnel", "room": &"basement_tunnel", "at": Vector3(-37.0, -6.0, -37.0), "dir": Vector3(0, 0, 1),
		"across": 4.0, "height": 3.5, "valve": Vector3(-34.9, -6.0, -37.0), "offset": 11.0},
]

## The wall point under the valve, the way into the corridor.
var at := Vector3.ZERO
var direction := Vector3.FORWARD
var across: float = 3.5
var height: float = 3.5
## The wheel's wall point (floor height).
var valve_at := Vector3.ZERO
var phase: Phase = Phase.QUIET
var bursts: int = 0
var valve: SteamWheel = null

var _left: float = 0.0
var _shut_left: float = 0.0
var _tick_left: float = 0.0
## Instance id -> [exhibit, seconds of blindness left].
var _blind: Dictionary = {}
var _jets: Array[GPUParticles3D] = []
var _needle: Node3D = null
var _wheel: Node3D = null


class SteamWheel extends Interactable:
	var vent: SteamVent

	func _init() -> void:
		super()
		prompt_key = "PROMPT_STEAM_VALVE"

	func can_interact(by: Node) -> bool:
		return super(by) and vent != null and not vent.frozen and not vent.shut()

	func interact(by: Node) -> void:
		super(by)
		if vent != null:
			vent.close()


## Every vent of PLACES whose room [param host] serves.
static func build_all(host: BiomeMechanics) -> Array[BiomeDevice]:
	var made: Array[BiomeDevice] = []
	for spec: Dictionary in PLACES:
		if not host.serves(spec["room"]):
			continue
		var vent := create(spec)
		host.adopt(vent, spec["id"], spec["room"])
		made.append(vent)
	return made


## A vent from [param spec] (see PLACES); add it yourself.
static func create(spec: Dictionary) -> SteamVent:
	var vent := SteamVent.new()
	vent.at = spec["at"]
	var flat: Vector3 = spec["dir"]
	vent.direction = Vector3(flat.x, 0.0, flat.z).normalized()
	vent.across = float(spec.get("across", 3.5))
	vent.height = float(spec.get("height", 3.5))
	vent.valve_at = spec["valve"]
	vent._left = maxf(vent.quiet_time() - fmod(float(spec.get("offset", 0.0)), vent.quiet_time()), 0.5)
	return vent


func _ready() -> void:
	top_level = true
	global_transform = Transform3D.IDENTITY
	_build_looks()
	valve = SteamWheel.new()
	valve.name = "Wheel"
	valve.vent = self
	valve.position = valve_at + direction * 0.2 + Vector3.UP * 1.3
	valve.add_box(Vector3(0.6, 0.6, 0.5))
	add_child(valve)


## The cycle's length now.
func period() -> float:
	var escalation := clampf(host.intensity, 0.0, 1.0) if host != null else 0.0
	return lerpf(PERIOD, FAST_PERIOD, escalation)


## Seconds of quiet between two bursts.
func quiet_time() -> float:
	return maxf(period() - TELL - BURST, 1.0)


## Seconds until the next burst begins (a shut main's included).
func until_burst() -> float:
	var shut_wait := _shut_left if shut() else 0.0
	match phase:
		Phase.QUIET:
			return shut_wait + _left + TELL
		Phase.HISSING:
			return _left
	return _left + quiet_time() + TELL


func shut() -> bool:
	return _shut_left > 0.0


## The wheel: the main is shut, a burst stops at once.
func close() -> bool:
	if frozen or shut():
		return false
	_shut_left = VALVE_TIME
	phase = Phase.QUIET
	_left = quiet_time()
	_show_jets()
	Sfx.play_at(&"lock_bolt_slide", valve_at + Vector3.UP * 1.3, -4.0, 0.05, 0.7)
	if _wheel != null and is_inside_tree():
		create_tween().tween_property(_wheel, "rotation:z", _wheel.rotation.z + TAU, 0.6)
	return true


func _physics_process(delta: float) -> void:
	_ease_blind(delta)
	if shut():
		_shut_left = maxf(_shut_left - delta, 0.0)
		_show_gauge(0.0)
		return
	_left -= delta
	match phase:
		Phase.QUIET:
			_show_gauge(clampf(1.0 - _left / quiet_time(), 0.0, 1.0) * 0.7)
			if _left <= 0.0:
				phase = Phase.HISSING
				_left += TELL
				_show_jets()
				Sfx.play_at(&"flare_burn", jet_point(), -10.0, 0.05, 0.6)
		Phase.HISSING:
			_show_gauge(0.7 + 0.3 * (1.0 - _left / TELL))
			if _left <= 0.0:
				phase = Phase.VENTING
				_left += BURST
				bursts += 1
				_tick_left = 0.0
				_show_jets()
				Sfx.play_at(&"flare_burn", jet_point(), 2.0, 0.05, 0.45)
				Sfx.play_at(&"lamassu_gust", jet_point(), -8.0, 0.05, 1.6)
		Phase.VENTING:
			_show_gauge(1.0)
			_tick_left -= delta
			if _tick_left <= 0.0:
				_tick_left = TICK
				_scald(TICK)
			if _left <= 0.0:
				phase = Phase.QUIET
				_left += quiet_time()
				_show_jets()


## Where the steam leaves the cracked main.
func jet_point() -> Vector3:
	return at + Vector3.UP * MAIN_Y + direction * 0.25


## True when a body standing at [param feet] is in the plume.
func in_plume(feet: Vector3) -> bool:
	var to := feet - at
	var into := to.x * direction.x + to.z * direction.z
	var along := absf(to.x * direction.z - to.z * direction.x)
	return into >= -0.2 and into <= across + 0.2 and along <= HALF_WIDTH and feet.y >= at.y - 0.5 and feet.y <= at.y + height


func _scald(seconds: float) -> void:
	var player := guard()
	if player != null and in_plume(player.global_position):
		player.take_damage(_heat(GUARD_PER_SECOND * seconds, player.global_position))
	var middle := at + direction * across * 0.5
	for exhibit in BiomeMechanics.exhibits_near(middle, across + HALF_WIDTH + 1.0):
		if not in_plume(exhibit.global_position) or not exhibit.brain.is_alerted():
			continue
		exhibit.take_damage(_heat(EXHIBIT_PER_SECOND * seconds, exhibit.global_position))
		_blind_it(exhibit)


func _heat(amount: float, feet: Vector3) -> DamageInfo:
	var info := DamageInfo.make(amount, DamageInfo.Kind.FIRE, null)
	info.periodic = true
	info.silent = true   # a scald hurts, it does not tell the exhibit where the guard is
	info.position = feet + Vector3.UP * 1.1
	info.direction = direction
	return info


func _blind_it(exhibit: Enemy) -> void:
	var id := exhibit.get_instance_id()
	ExhibitMods.cap_sight(exhibit, get_instance_id(), BLIND_RANGE)
	_blind[id] = [exhibit, BLIND_HOLD + TICK]


func _ease_blind(delta: float) -> void:
	for id: int in _blind.keys():
		var entry: Array = _blind[id]
		entry[1] = float(entry[1]) - delta
		if float(entry[1]) <= 0.0:
			_unblind(entry[0])
			_blind.erase(id)


## Takes the steam's blindness off [param exhibit] (only that cap: any other
## change of its sight stays; ExhibitMods).
func _unblind(exhibit: Variant) -> void:
	if is_instance_valid(exhibit):
		ExhibitMods.clear_sight(exhibit as Enemy, get_instance_id())


func freeze() -> void:
	super()
	phase = Phase.QUIET
	_show_jets()
	for id: int in _blind.keys():
		_unblind((_blind[id] as Array)[0])
	_blind.clear()


func _exit_tree() -> void:
	for id: int in _blind.keys():
		_unblind((_blind[id] as Array)[0])
	_blind.clear()


# --- the looks ---------------------------------------------------------------------

## The cracked flange on the main, the wheel and its gauge, the steam jets.
func _build_looks() -> void:
	var iron := LockArt.metal(IRON, 0.6)
	var brass := LockArt.metal(BRASS, 0.3)
	var flange := Node3D.new()
	flange.name = "Valve"
	flange.transform = Transform3D(Basis.looking_at(direction, Vector3.UP), at + Vector3.UP * MAIN_Y)
	add_child(flange)
	LockArt.rod(flange, 0.14, Vector3(0, 0, -0.02), Vector3(0, 0, -0.32), iron, 12)
	LockArt.ring(flange, 0.17, 0.03, Vector3(0, 0, -0.3), Vector3.BACK, iron)
	LockArt.box(flange, Vector3(0.04, 0.3, 0.02), Vector3(0.05, 0.0, -0.33), LockArt.matte(Color(0.08, 0.07, 0.07), 1.0), Vector3(0, 0, 25))
	var mount := Node3D.new()
	mount.name = "Wheel"
	mount.transform = Transform3D(Basis.looking_at(direction, Vector3.UP), valve_at)
	add_child(mount)
	LockArt.rod(mount, 0.04, Vector3(0, 1.3, 0.0), Vector3(0, 1.3, -0.18), iron, 8)
	_wheel = Node3D.new()
	_wheel.position = Vector3(0, 1.3, -0.2)
	mount.add_child(_wheel)
	LockArt.ring(_wheel, 0.2, 0.025, Vector3.ZERO, Vector3.BACK, LockArt.matte(Color(0.42, 0.12, 0.08), 0.6))
	for angle in [0.0, PI / 3.0, PI * 2.0 / 3.0]:
		LockArt.rod(_wheel, 0.012, Vector3(cos(angle), sin(angle), 0) * -0.2, Vector3(cos(angle), sin(angle), 0) * 0.2, iron, 4)
	# the gauge over the wheel: a brass rim, a white face, the needle
	var face := CylinderMesh.new()
	face.top_radius = 0.12
	face.bottom_radius = 0.12
	face.height = 0.02
	var dial := MeshInstance3D.new()
	dial.mesh = face
	dial.material_override = LockArt.matte(Color(0.92, 0.9, 0.84), 0.6)
	dial.position = Vector3(0, 1.85, -0.06)
	dial.rotation = Vector3(PI * 0.5, 0, 0)
	mount.add_child(dial)
	LockArt.ring(mount, 0.12, 0.015, Vector3(0, 1.85, -0.07), Vector3.BACK, brass)
	_needle = Node3D.new()
	_needle.position = Vector3(0, 1.85, -0.08)
	mount.add_child(_needle)
	LockArt.box(_needle, Vector3(0.012, 0.1, 0.006), Vector3(0, 0.045, 0), LockArt.matte(Color(0.1, 0.1, 0.1), 0.5))
	for height_up: float in [MAIN_Y, 1.2]:
		var jet := _jet()
		jet.position = at + Vector3.UP * height_up + direction * 0.2
		add_child(jet)
		_jets.append(jet)
	_show_jets()


func _jet() -> GPUParticles3D:
	var particles := GPUParticles3D.new()
	particles.name = "Steam"
	particles.amount = 48
	particles.lifetime = 0.9
	particles.local_coords = false
	particles.visibility_aabb = AABB(Vector3(-4, -4, -4), Vector3(8, 8, 8))
	var process := ParticleProcessMaterial.new()
	process.direction = direction + Vector3.DOWN * 0.25
	process.spread = 22.0
	process.initial_velocity_min = 3.5
	process.initial_velocity_max = 5.5
	process.gravity = Vector3(0, 0.6, 0)
	process.damping_min = 2.0
	process.damping_max = 3.0
	process.scale_min = 0.6
	process.scale_max = 1.4
	var grow := Curve.new()
	grow.add_point(Vector2(0.0, 0.3))
	grow.add_point(Vector2(1.0, 1.0))
	var grow_tex := CurveTexture.new()
	grow_tex.curve = grow
	process.scale_curve = grow_tex
	process.color = STEAM
	particles.process_material = process
	var quad := QuadMesh.new()
	quad.size = Vector2(0.9, 0.9)
	quad.material = Floor1LightRecipe.steam_material()
	particles.draw_pass_1 = quad
	return particles


func _show_jets() -> void:
	for i in _jets.size():
		var jet := _jets[i]
		match phase:
			Phase.VENTING:
				jet.amount_ratio = 1.0
				jet.emitting = true
			Phase.HISSING:
				jet.amount_ratio = 0.2 if i == 0 else 0.0
				jet.emitting = i == 0
			_:
				jet.emitting = false


func _show_gauge(pressure: float) -> void:
	if _needle != null:
		_needle.rotation.z = lerpf(1.2, -1.2, clampf(pressure, 0.0, 1.0))
