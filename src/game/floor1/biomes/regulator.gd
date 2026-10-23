class_name Regulator
extends BiomeDevice
## The Enlightenment's regulator (plan 2026-10-21-mechaniki-biomow,
## mechanic 4): the master clock on the clocks room's wall that keeps the
## wing's time - a mahogany case, a white dial, a brass pendulum behind
## glass, a chime on top. Every BEAT s (quicker as the night escalates) it
## strikes:
## - TELL s before, the works whir (heard through the wing) and the
##   exhibits it holds glint brass;
## - "tick": every exhibit of the wing's rooms fighting the guard (hunting
##   or striking, within RANGE m of him) stops dead TICK s (stunned: a fist
##   can finish it);
## - "tock": then it runs HASTE times faster for HASTE_TIME s.
## Sleepers, the curious and the searching are left alone. A shot through
## its glass stops the pendulum: no beat for STOP_TIME s, the last REWIND s
## of them it winds itself up again, whirring. It hangs on a wall: no
## collision. The Great Orrery's rotunda keeps its own time (an arena).

const BEAT := 18.0
## The beat at the night's height (BiomeMechanics.intensity 1).
const FAST_BEAT := 12.0
const TELL := 1.0
const TICK := 1.0
const HASTE := 1.35
const HASTE_TIME := 2.5
const STOP_TIME := 60.0
const REWIND := 2.0
const RANGE := 40.0
const MAHOGANY := Color(0.32, 0.14, 0.08)
const BRASS := Color(0.86, 0.68, 0.32)
const DIAL := Color(0.93, 0.9, 0.82)
## The case: its foot this high off the floor, this tall, wide and deep.
const CASE_BASE := 0.9
const CASE_SIZE := Vector3(0.72, 2.3, 0.26)

## The regulator on the clocks room's west wall, between the archive's
## grille and the writer's desk, facing the room.
const PLACES := [
	{"id": &"enlightenment_regulator", "room": &"enlightenment_clocks", "at": Vector3(53.0, 0.0, -7.0), "face": Vector3(1, 0, 0)},
]

## The wall point at the floor and the way into the room.
var at := Vector3.ZERO
var face := Vector3.FORWARD
## The rooms whose exhibits keep its time (room id -> true; empty: any).
var rooms: Dictionary = {}
var strikes: int = 0
var glass_broken := false

var _next: float = BEAT
var _stop_left: float = 0.0
var _whirred := false
## Instance id -> [exhibit, seconds left, hastened].
var _held: Dictionary = {}
var _time: float = 0.0
var _pendulum: Node3D = null
var _hammer: Node3D = null
var _glass: MeshInstance3D = null


## The regulator of PLACES (its room served) keeping the wing's time.
static func build_all(host: BiomeMechanics) -> Array[BiomeDevice]:
	var made: Array[BiomeDevice] = []
	var layout := host.layout()
	for spec: Dictionary in PLACES:
		if not host.serves(spec["room"]):
			continue
		var regulator := create(spec)
		for room in layout.rooms:
			if room.zone == &"enlightenment" and host.serves(room.id):
				regulator.rooms[room.id] = true
		host.adopt(regulator, spec["id"], spec["room"])
		made.append(regulator)
	return made


## A regulator from [param spec] ("at", "face"); add it yourself.
static func create(spec: Dictionary) -> Regulator:
	var regulator := Regulator.new()
	regulator.at = spec["at"]
	var flat: Vector3 = spec["face"]
	regulator.face = Vector3(flat.x, 0.0, flat.z).normalized()
	return regulator


func _ready() -> void:
	top_level = true
	global_transform = Transform3D.IDENTITY
	_next = beat()
	_build_looks()
	var box := BoxShape3D.new()
	box.size = Vector3(CASE_SIZE.x, CASE_SIZE.y, 0.3)
	var zone := Hurtbox.make(self, box, at + face * 0.15 + Vector3.UP * (CASE_BASE + CASE_SIZE.y * 0.5))
	zone.name = "HitZone"
	zone.basis = Basis.looking_at(face, Vector3.UP)
	add_child(zone)


## Seconds between strikes now.
func beat() -> float:
	var escalation := clampf(host.intensity, 0.0, 1.0) if host != null else 0.0
	return lerpf(BEAT, FAST_BEAT, escalation)


## Seconds to its next strike (a stopped clock's included).
func until_strike() -> float:
	return _stop_left + beat() if stopped() else _next


func tolling() -> bool:
	return not frozen and not stopped() and _next <= TELL


func stopped() -> bool:
	return _stop_left > 0.0


func rewinding() -> bool:
	return stopped() and _stop_left <= REWIND


## Where the pendulum's bob swings behind the glass.
func pendulum_point() -> Vector3:
	return at + face * 0.16 + Vector3.UP * (CASE_BASE + 0.75)


# --- the clock ------------------------------------------------------------------------

## A shot through the glass stops the pendulum.
func take_damage(info: DamageInfo) -> void:
	if frozen or stopped():
		return
	_stop_left = STOP_TIME
	_whirred = false
	var point := info.position if info != null and info.position != Vector3.ZERO else pendulum_point()
	if not glass_broken:
		glass_broken = true
		if _glass != null:
			_glass.visible = false
		Sfx.play_at(&"glass_break", point, -2.0)
		Fx.impact(point, face, -1, 1.0)
	Sfx.play_at(&"gatling_stop", pendulum_point(), -6.0, 0.05, 1.4)
	if _pendulum != null:
		_pendulum.rotation = Vector3.ZERO


func _physics_process(delta: float) -> void:
	_time += delta
	_ease_held(delta)
	if stopped():
		_stop_left = maxf(_stop_left - delta, 0.0)
		if rewinding() and not _whirred:
			_whirred = true
			Sfx.play_at(&"orrery_gears", pendulum_point(), -4.0, 0.05, 1.6)
		if _stop_left <= 0.0:
			_next = beat()
		return
	if _pendulum != null:
		_pendulum.rotation = Vector3(0.0, 0.0, 0.16 * sin(_time * TAU * 0.5))
	var before := _next
	_next -= delta
	if before > TELL and _next <= TELL:
		_toll()
	if _hammer != null:
		_hammer.rotation.x = -0.9 * clampf(1.0 - _next / TELL, 0.0, 1.0) if _next <= TELL else 0.0
	if _next <= 0.0:
		_strike()
		_next += beat()


## The exhibits it holds now: fighting the guard, in its rooms, near him.
func held() -> Array[Enemy]:
	var found: Array[Enemy] = []
	var player := guard()
	if player == null:
		return found
	for exhibit in BiomeMechanics.exhibits_near(player.global_position, RANGE):
		if not (exhibit.brain.state == EnemyBrain.State.HUNT or exhibit.brain.state == EnemyBrain.State.ATTACK):
			continue
		if rooms.is_empty() or rooms.has(exhibit.current_room()):
			found.append(exhibit)
	return found


func _guard_hears() -> bool:
	var player := guard()
	return player != null and (rooms.is_empty() or rooms.has(PerceptionWorld.room_at(player.global_position + Vector3.UP * 0.5)))


func _toll() -> void:
	Sfx.play_at(&"orrery_gears", pendulum_point(), -2.0, 0.05, 1.8)
	if _guard_hears():
		Sfx.play(&"orrery_gears", -14.0, 0.05, 1.8)
	for exhibit in held():
		Fx.puff(exhibit.global_position + Vector3.UP * 1.3, BRASS, 8, 0.3)


func _strike() -> void:
	strikes += 1
	Sfx.play_at(&"witching_bell", at + face * 0.2 + Vector3.UP * (CASE_BASE + CASE_SIZE.y + 0.2), 0.0, 0.02, 1.6)
	if _guard_hears():
		Sfx.play(&"witching_bell", -10.0, 0.02, 1.6)
	for exhibit in held():
		exhibit.brain.stun(TICK)
		_held[exhibit.get_instance_id()] = [exhibit, TICK + HASTE_TIME, false]


## Ticks the held: the tock's haste after the tick, then their own pace.
func _ease_held(delta: float) -> void:
	for id: int in _held.keys():
		var entry: Array = _held[id]
		var exhibit: Variant = entry[0]
		entry[1] = float(entry[1]) - delta
		if not is_instance_valid(exhibit):
			_held.erase(id)
			continue
		if not entry[2] and float(entry[1]) <= HASTE_TIME:
			entry[2] = true
			ExhibitMods.scale_pace(exhibit as Enemy, get_instance_id(), HASTE)
		if float(entry[1]) <= 0.0:
			_restore(exhibit)
			_held.erase(id)


## Takes its haste off [param exhibit] (only the haste: any other change of
## its pace stays; ExhibitMods).
func _restore(exhibit: Variant) -> void:
	if is_instance_valid(exhibit):
		ExhibitMods.clear_pace(exhibit as Enemy, get_instance_id())


func freeze() -> void:
	super()
	for id: int in _held.keys():
		_restore((_held[id] as Array)[0])
	_held.clear()


func _exit_tree() -> void:
	for id: int in _held.keys():
		_restore((_held[id] as Array)[0])
	_held.clear()


# --- the looks -----------------------------------------------------------------------

## The case on the wall: the dial with its hands, the pendulum behind
## glass, the chime and its hammer on top.
func _build_looks() -> void:
	var wood := LockArt.matte(MAHOGANY, 0.55)
	var brass := LockArt.metal(BRASS, 0.3)
	var case := Node3D.new()
	case.name = "Case"
	case.transform = Transform3D(Basis.looking_at(face, Vector3.UP), at)
	add_child(case)
	var depth := CASE_SIZE.z
	LockArt.box(case, Vector3(CASE_SIZE.x, CASE_SIZE.y, 0.04), Vector3(0, CASE_BASE + CASE_SIZE.y * 0.5, -0.02), wood)
	for side in [-1.0, 1.0]:
		LockArt.box(case, Vector3(0.05, CASE_SIZE.y, depth), Vector3(side * (CASE_SIZE.x - 0.05) * 0.5, CASE_BASE + CASE_SIZE.y * 0.5, -depth * 0.5), wood)
	LockArt.box(case, Vector3(CASE_SIZE.x + 0.08, 0.12, depth + 0.04), Vector3(0, CASE_BASE + CASE_SIZE.y + 0.06, -depth * 0.5), wood)
	LockArt.box(case, Vector3(CASE_SIZE.x + 0.06, 0.1, depth + 0.02), Vector3(0, CASE_BASE - 0.05, -depth * 0.5), wood)
	LockArt.box(case, Vector3(CASE_SIZE.x - 0.1, 0.04, depth), Vector3(0, CASE_BASE + 1.55, -depth * 0.5), wood)
	# the dial and its hands
	var dial_y := CASE_BASE + 1.9
	var dial := CylinderMesh.new()
	dial.top_radius = 0.26
	dial.bottom_radius = 0.26
	dial.height = 0.02
	dial.radial_segments = 32
	var face_view := MeshInstance3D.new()
	face_view.mesh = dial
	face_view.material_override = LockArt.matte(DIAL, 0.6)
	face_view.position = Vector3(0, dial_y, -depth - 0.01)
	face_view.rotation = Vector3(PI * 0.5, 0, 0)
	case.add_child(face_view)
	LockArt.ring(case, 0.26, 0.018, Vector3(0, dial_y, -depth - 0.02), Vector3.BACK, brass)
	var dark := LockArt.matte(Color(0.05, 0.05, 0.05), 0.5)
	LockArt.box(case, Vector3(0.012, 0.2, 0.01), Vector3(0, dial_y + 0.08, -depth - 0.035), dark)
	LockArt.box(case, Vector3(0.016, 0.14, 0.01), Vector3(0.05, dial_y - 0.03, -depth - 0.035), dark, Vector3(0, 0, -60))
	# the pendulum: a rod and a brass bob, swinging behind the glass
	_pendulum = Node3D.new()
	_pendulum.name = "Pendulum"
	_pendulum.position = Vector3(0, CASE_BASE + 1.5, -depth * 0.5)
	case.add_child(_pendulum)
	LockArt.rod(_pendulum, 0.01, Vector3.ZERO, Vector3(0, -0.8, 0), brass, 6)
	var bob := CylinderMesh.new()
	bob.top_radius = 0.09
	bob.bottom_radius = 0.09
	bob.height = 0.03
	var bob_view := MeshInstance3D.new()
	bob_view.mesh = bob
	bob_view.material_override = brass
	bob_view.position = Vector3(0, -0.8, 0)
	bob_view.rotation = Vector3(PI * 0.5, 0, 0)
	_pendulum.add_child(bob_view)
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.8, 0.88, 0.9, 0.18)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.metallic = 0.3
	glass.roughness = 0.05
	_glass = LockArt.box(case, Vector3(CASE_SIZE.x - 0.1, 1.45, 0.01), Vector3(0, CASE_BASE + 0.8, -depth), glass)
	# the chime on top and its hammer
	var chime := CylinderMesh.new()
	chime.top_radius = 0.06
	chime.bottom_radius = 0.13
	chime.height = 0.14
	var chime_view := MeshInstance3D.new()
	chime_view.mesh = chime
	chime_view.material_override = brass
	chime_view.position = Vector3(0, CASE_BASE + CASE_SIZE.y + 0.22, -depth * 0.5)
	case.add_child(chime_view)
	_hammer = Node3D.new()
	_hammer.name = "Hammer"
	_hammer.position = Vector3(0.18, CASE_BASE + CASE_SIZE.y + 0.14, -depth * 0.5)
	case.add_child(_hammer)
	LockArt.rod(_hammer, 0.008, Vector3.ZERO, Vector3(-0.14, 0.12, 0), brass, 6)
	LockArt.box(_hammer, Vector3(0.05, 0.03, 0.03), Vector3(-0.14, 0.12, 0), brass)
