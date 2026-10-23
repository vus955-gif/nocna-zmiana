class_name TombTrap
extends BiomeDevice
## Egypt's curse plates (plan 2026-10-21-mechaniki-biomow, mechanic 1): a
## raised sandstone plate with a gold cartouche lies in the floor of a tomb,
## on the line of a "mouth" in the wall - a carved frame with three dark
## slits. A weight on the plate (the guard on his feet, or an exhibit that
## walks onto it alarmed - the dead know their tomb while they rest; in a
## hurry they forget it) sinks it with a click and the slits cough dust:
## after TELL seconds a volley of darts flies down the line, a lane
## 2 x HALF_WIDTH wide from the mouth to the first wall in the way, at the
## slits' heights. Whoever is on it then takes the volley: the guard
## GUARD_DAMAGE, an exhibit EXHIBIT_DAMAGE (lure a mummy there). The volley
## is a noise (NOISE m, NOISE_SOURCE): it wakes the sleepers round it. The
## plate rises again RESET s later. Nothing about it is solid: the plate is
## drawn 2 cm proud of the floor, the mouth is on a wall.

enum Phase { ARMED, PRIMED, RESETTING }

## Seconds from the click to the volley (the owner's telegraph >= 0.6 s).
const TELL := 0.7
## Seconds the plate takes to rise again after the volley.
const RESET := 4.0
const GUARD_DAMAGE := 12.0
const EXHIBIT_DAMAGE := 40.0
const KNOCKBACK := 2.5
## Half the width of the lane a body's centre is hit in (m).
const HALF_WIDTH := 0.45
## The plate (m, square) and how far over the floor a foot may be on it.
const PLATE_SIZE := 1.1
const PLATE_REACH_UP := 0.35
## The slits' heights over the mouth's floor; a body is hit by a slit whose
## dart passes between its feet and BODY_TOP over them.
const SLITS: Array[float] = [0.55, 1.05, 1.55]
const BODY_TOP := 1.9
const NOISE := 10.0
const NOISE_SOURCE := &"trap"
## An exhibit on the plate is looked for this often (s), and only while the
## guard is within WATCH_RANGE m (nothing walks far from him).
const EXHIBIT_CHECK := 0.1
const WATCH_RANGE := 35.0
const SAND := Color(0.78, 0.66, 0.46)
const DART := Color(0.95, 0.72, 0.38)

## The tombs' traps: the plate on the floor, the mouth on its wall (floor
## height, the wall's face), the way the darts fly and how far the lane runs.
const PLACES := [
	# the tomb passage: across it, from the east wall south of the gallery door
	{"id": &"egypt_trap_passage", "room": &"egypt_tomb_passage", "plate": Vector3(-52.75, 0.0, -5.0),
		"mouth": Vector3(-50.5, 0.0, -5.0), "dir": Vector3(-1, 0, 0), "length": 4.5},
	# the burial chambers: down the west aisle from the south wall, between
	# the serdab's crack and the hall door, over the way west to Greece
	{"id": &"egypt_trap_tombs", "room": &"egypt_tombs", "plate": Vector3(-59.5, 0.0, 13.4),
		"mouth": Vector3(-59.5, 0.0, 15.0), "dir": Vector3(0, 0, -1), "length": 7.5},
	# the sarcophagus hall: up the east aisle from the south wall (past the
	# vestibule door; the plate by the coffins' north end) ...
	{"id": &"egypt_trap_hall_east", "room": &"egypt_tomb_hall", "plate": Vector3(-51.6, 0.0, 18.0),
		"mouth": Vector3(-51.6, 0.0, 30.0), "dir": Vector3(0, 0, -1), "length": 14.5},
	# ... and across its middle between the coffins, from the west wall
	{"id": &"egypt_trap_hall_middle", "room": &"egypt_tomb_hall", "plate": Vector3(-55.3, 0.0, 22.0),
		"mouth": Vector3(-60.0, 0.0, 22.0), "dir": Vector3(1, 0, 0), "length": 9.5},
]

var plate_at := Vector3.ZERO
var mouth := Vector3.ZERO
## Flat unit vector the darts fly along.
var direction := Vector3.FORWARD
var length: float = 10.0
var phase: Phase = Phase.ARMED
## Volleys fired so far (tests, the tour).
var volleys: int = 0

var _timer: float = 0.0
var _check_left: float = 0.0
var _plate_view: Node3D = null
var _slits: Array[Vector3] = []


## Every trap of PLACES whose room [param host] serves.
static func build_all(host: BiomeMechanics) -> Array[BiomeDevice]:
	var made: Array[BiomeDevice] = []
	for spec: Dictionary in PLACES:
		if not host.serves(spec["room"]):
			continue
		var trap := create(spec)
		host.adopt(trap, spec["id"], spec["room"])
		made.append(trap)
	return made


## A trap from [param spec] ("plate", "mouth", "dir", "length"); add it
## yourself (BiomeMechanics.adopt).
static func create(spec: Dictionary) -> TombTrap:
	var trap := TombTrap.new()
	trap.plate_at = spec["plate"]
	trap.mouth = spec["mouth"]
	var flat := Vector3((spec["dir"] as Vector3).x, 0.0, (spec["dir"] as Vector3).z)
	trap.direction = flat.normalized()
	trap.length = float(spec.get("length", 10.0))
	return trap


func _ready() -> void:
	top_level = true
	global_transform = Transform3D.IDENTITY
	for height in SLITS:
		_slits.append(mouth + Vector3.UP * height)
	_build_looks()


# --- the rules -------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	match phase:
		Phase.ARMED:
			if _pressed(delta):
				_prime()
		Phase.PRIMED:
			_timer -= delta
			if _timer <= 0.0:
				_fire()
		Phase.RESETTING:
			_timer -= delta
			if _timer <= 0.0:
				phase = Phase.ARMED
				_show_plate(false)


## True when a weight is on the plate: the guard on his feet (every frame),
## or an alarmed exhibit walking (every EXHIBIT_CHECK s, near the guard).
func _pressed(delta: float) -> bool:
	var player := guard()
	if player != null and player.is_on_floor() and on_plate(player.global_position):
		return true
	_check_left -= delta
	if _check_left > 0.0:
		return false
	_check_left = EXHIBIT_CHECK
	if player != null and player.global_position.distance_to(plate_at) > WATCH_RANGE:
		return false
	for exhibit in BiomeMechanics.exhibits_near(plate_at, PLATE_SIZE + 0.5):
		if steps_on(exhibit) and on_plate(exhibit.global_position):
			return true
	return false


## True when a foot at [param at] presses the plate.
func on_plate(at: Vector3) -> bool:
	var half := PLATE_SIZE * 0.5
	return absf(at.x - plate_at.x) <= half and absf(at.z - plate_at.z) <= half \
			and at.y >= plate_at.y - 0.2 and at.y <= plate_at.y + PLATE_REACH_UP


## Whether [param exhibit] is heavy and heedless enough to press a plate:
## on its feet and alarmed; the swarm, the books, the busts and the
## paintings never.
static func steps_on(exhibit: Enemy) -> bool:
	if exhibit is ScarabSwarm or exhibit is FlyingBook or exhibit is Bust or exhibit is Portrait:
		return false
	return exhibit.brain.is_alerted() and exhibit.is_on_floor()


func _prime() -> void:
	phase = Phase.PRIMED
	_timer = TELL
	_show_plate(true)
	Sfx.play_at(&"lock_bolt_slide", plate_at + Vector3.UP * 0.1, -3.0, 0.05, 0.6)
	Sfx.play_at(&"rubble", mouth + Vector3.UP * 1.0, -10.0, 0.1, 1.3)
	for slit in _slits:
		Fx.puff(slit + direction * 0.15, SAND, 10, 0.18)


## The volley: every body on the lane of a slit (to that slit's first wall)
## is hit once.
func _fire() -> void:
	phase = Phase.RESETTING
	_timer = RESET
	volleys += 1
	var reaches: Array[float] = []
	for slit in _slits:
		reaches.append(_reach(slit))
	var player := guard()
	if player != null and _on_line(player.global_position, reaches):
		player.take_damage(_dart(GUARD_DAMAGE, player.global_position))
	for exhibit in BiomeMechanics.exhibits_near(mouth + direction * length * 0.5, length * 0.5 + 1.5):
		if _on_line(exhibit.global_position, reaches):
			exhibit.take_damage(_dart(EXHIBIT_DAMAGE, exhibit.global_position))
	for i in _slits.size():
		var end := _slits[i] + direction * reaches[i]
		Fx.tracer(_slits[i] + direction * 0.1, end, DART, 0.02, 0.12)
		if reaches[i] < length - 0.05:
			Fx.impact(end, -direction, -1, 0.8)
	Sfx.play_at(&"shard_fire", mouth + Vector3.UP * 1.0, 0.0, 0.08, 1.35)
	Sfx.play_at(&"harpoon_thunk", mouth + direction * minf(length, 6.0) + Vector3.UP, -6.0, 0.1, 1.5)
	Events.noise_made.emit(plate_at, NOISE, NOISE_SOURCE)


## How far a dart from [param slit] flies before a wall (the lane's length
## at most). Bodies do not stop darts: a volley goes through a line of them.
func _reach(slit: Vector3) -> float:
	if not is_inside_tree():
		return length
	var from := slit + direction * 0.05
	var query := PhysicsRayQueryParameters3D.create(from, slit + direction * length, Layers.WORLD)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return length
	return 0.05 + from.distance_to(hit["position"])


## True when a body standing at [param feet] is on the lane of a slit whose
## dart reaches it.
func _on_line(feet: Vector3, reaches: Array[float]) -> bool:
	var to := feet - mouth
	var along := to.x * direction.x + to.z * direction.z
	var across := absf(to.x * direction.z - to.z * direction.x)
	if along < 0.0 or across > HALF_WIDTH:
		return false
	for i in _slits.size():
		var height := _slits[i].y
		if along <= reaches[i] and height >= feet.y - 0.1 and height <= feet.y + BODY_TOP:
			return true
	return false


func _dart(amount: float, at: Vector3) -> DamageInfo:
	var info := DamageInfo.make(amount, DamageInfo.Kind.BALLISTIC, null)
	info.direction = direction
	info.position = at + Vector3.UP * 1.1
	info.normal = -direction
	info.knockback = KNOCKBACK
	info.origin = mouth + Vector3.UP * 1.05
	info.impact = 0.6
	return info


func freeze() -> void:
	super()
	phase = Phase.ARMED
	_show_plate(false)


# --- the looks ---------------------------------------------------------------------

## The plate (sandstone, a dark gap round it, a gold cartouche) and the
## mouth on the wall (a carved frame, three dark slits, a gold band).
func _build_looks() -> void:
	var stone := LockArt.tile("sandstone", 1.0, SAND)
	var dark := LockArt.matte(Color(0.06, 0.05, 0.04), 1.0)
	var gold := LockArt.metal(Color(0.85, 0.66, 0.3), 0.35)
	var gap := Node3D.new()
	gap.name = "PlateGap"
	gap.position = plate_at
	add_child(gap)
	LockArt.box(gap, Vector3(PLATE_SIZE + 0.08, 0.012, PLATE_SIZE + 0.08), Vector3(0, 0.006, 0), dark)
	_plate_view = Node3D.new()
	_plate_view.name = "Plate"
	_plate_view.position = plate_at
	add_child(_plate_view)
	LockArt.box(_plate_view, Vector3(PLATE_SIZE, 0.04, PLATE_SIZE), Vector3(0, 0.0, 0), stone)
	LockArt.box(_plate_view, Vector3(0.34, 0.012, 0.66), Vector3(0, 0.024, 0), gold, Vector3(0, rad_to_deg(atan2(direction.x, direction.z)), 0))
	LockArt.box(_plate_view, Vector3(0.24, 0.014, 0.05), Vector3(0, 0.026, 0), dark, Vector3(0, rad_to_deg(atan2(direction.x, direction.z)), 0))
	var face := Node3D.new()
	face.name = "Mouth"
	face.transform = Transform3D(Basis.looking_at(direction, Vector3.UP), mouth)
	add_child(face)
	LockArt.box(face, Vector3(0.72, 1.62, 0.1), Vector3(0, 1.08, -0.05), LockArt.tile("sandstone_ashlar", 1.0, SAND))
	LockArt.box(face, Vector3(0.78, 0.14, 0.14), Vector3(0, 1.95, -0.07), gold)
	for height in SLITS:
		LockArt.box(face, Vector3(0.44, 0.07, 0.04), Vector3(0, height, -0.11), dark)
	_show_plate(false)


func _show_plate(sunk: bool) -> void:
	if _plate_view == null:
		return
	var y := plate_at.y + (-0.018 if sunk else 0.0)
	if not is_inside_tree() or not sunk:
		_plate_view.position.y = y
		return
	create_tween().tween_property(_plate_view, "position:y", y, 0.08)
