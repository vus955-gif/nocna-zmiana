class_name LamassuGait
extends RefCounted
## The Lamassu's four hooves as footing in the world (the guardians' pattern:
## docs/superpowers/plans/2026-10-03-straznik-lamassu.md, decision 2). Each
## hoof's contact point is kept in world space: planted, it never moves (the
## body passes over it); it lifts only on its beat, arcs, and comes down
## where its place under the body will be half a stance later (predicted
## from the body's speed and turn). The body does not know where its hooves
## are - it settles onto them (LamassuMoves).
## Modes (the node picks one every frame):
## - STAND: a hoof the body walked or turned away from steps back under;
## - WALK: the heavy four-beat walk, lateral order (left hind, left fore,
##   right hind, right fore), never fewer than three hooves down;
## - GALLOP: the charge - the hind pair lands, the fore pair, then flight;
## - SKID: braking - the hooves drag along the floor with the body;
## - HOLD: the moves own the hooves (a rear, a crouch): nothing steps by
##   itself, only step_to() commands move a hoof (the plinth descent);
## - AIR: the hop - every hoof tucks up under the belly; back on the floor
##   they all land together.
## Legs: 0 fl, 1 fr, 2 bl, 3 br. The body root: origin on the floor under
## the barrel, -Z its front, +X its right.

## A hoof lifted off the floor / came down (dust, a thud).
signal lifted(leg: int)
signal landed(leg: int)

enum Mode { STAND, WALK, GALLOP, SKID, HOLD, AIR }

const LEGS := 4
const NAMES: Array[String] = ["fl", "fr", "bl", "br"]
## Each hoof's resting contact point (body space, on the floor): the model's
## contact_* markers at rest.
const NEUTRAL: Array[Vector3] = [Vector3(-0.41, 0.0, -0.98), Vector3(0.41, 0.0, -0.98),
	Vector3(-0.41, 0.0, 1.03), Vector3(0.41, 0.0, 1.03)]
## Where a hoof tucks up in the air (body space).
const TUCK: Array[Vector3] = [Vector3(-0.41, 0.62, -0.55), Vector3(0.41, 0.62, -0.55),
	Vector3(-0.41, 0.55, 0.62), Vector3(0.41, 0.55, 0.62)]
## Per mode: the landing beat of each hoof [fl, fr, bl, br] (0..1 of the
## cycle) and the share of the cycle it stands. The walk: lateral four
## beats a quarter apart, one hoof in the air at a time. The gallop: the
## hind pair, the fore pair a third later, then flight.
const WALK_OFFSETS: Array[float] = [0.25, 0.75, 0.0, 0.5]
const WALK_DUTY := 0.76
const GALLOP_OFFSETS: Array[float] = [0.3, 0.36, 0.0, 0.06]
const GALLOP_DUTY := 0.3
## Metres one cycle carries the body (frequency = speed / stride), and the
## stride frequency's bounds (Hz).
const WALK_STRIDE := 1.5
const WALK_FREQUENCY := Vector2(0.75, 1.5)
const GALLOP_STRIDE := 5.0
const GALLOP_FREQUENCY := Vector2(1.6, 2.7)
## How high a swinging hoof rises (m).
const WALK_LIFT := 0.22
const GALLOP_LIFT := 0.45
const SETTLE_LIFT := 0.14
## A planted hoof sweeps at most this far under the body (m): the stance
## share shrinks at speed so the legs reach.
const MAX_SWEEP := 1.25
## The shortest swing (s), and the settling step's.
const MIN_SWING := 0.12
const SETTLE_SWING := 0.42
## Standing, a hoof this far off its resting point steps back under.
const SETTLE := 0.2
## A planted hoof lifts at the latest once the body has run this far past
## it (m; well past the longest sweep, with a frame's slack at a gallop) or
## this much past its stance's time (cycles).
const LEFT_BEHIND := 1.0
const OVERDUE := 1.3
## Below this drive the body counts as standing (m/s; a turn counts as
## moving with TURN_ARM m of lever).
const MOVE_MIN := 0.2
const TURN_ARM := 1.0
## How far ahead a landing hoof leads a turn (rad at most).
const TURN_LEAD := 0.5
## How fast the stride's numbers chase their targets (per second).
const DUTY_RATE := 1.6
const FREQUENCY_RATE := 4.0

var mode: Mode = Mode.STAND
## 0..1 through the stride.
var cycle: float = 0.0
var frequency: float = 1.0
var duty: float = WALK_DUTY
var lift: float = WALK_LIFT
## The body's flat speed and turn rate (rad/s, + to its left) last update.
var speed: float = 0.0
var yaw_rate: float = 0.0
## Some hoof is off the floor, or the body moves.
var stepping := false
## The hooves' contact points now (world).
var feet: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO]
## The floor's height under a world point (Callable(Vector3) -> float):
## the plinth's top over its footprint, the court's floor beyond it. Unset,
## the body's own height is the floor.
var floor_of: Callable = Callable()

var _offsets: Array[float] = [0.25, 0.75, 0.0, 0.5]
var _stance: Array[bool] = [true, true, true, true]
var _planted: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO]
var _from: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO]
var _swing_time: Array[float] = [0.3, 0.3, 0.3, 0.3]
var _swing_age: Array[float] = [0.0, 0.0, 0.0, 0.0]
var _swing_lift: Array[float] = [0.2, 0.2, 0.2, 0.2]
var _stance_age: Array[float] = [0.0, 0.0, 0.0, 0.0]
## Commanded steps: leg -> world target (Vector3.INF = none).
var _command: Array[Vector3] = [Vector3.INF, Vector3.INF, Vector3.INF, Vector3.INF]
## A hoof whose beat came while another swung: it lifts as soon as it may.
var _due: Array[bool] = [false, false, false, false]
## Body-space places of the hooves while they skid.
var _skid_local: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO]
var _placed := false
var _settling := -1


## Plants every hoof at its resting point under [param root] (a fresh
## start, a teleport, a landing).
func place(root: Transform3D) -> void:
	_placed = true
	speed = 0.0
	yaw_rate = 0.0
	stepping = false
	_settling = -1
	cycle = 0.0
	for leg in LEGS:
		_stance[leg] = true
		_planted[leg] = _floor_point(root, NEUTRAL[leg])
		feet[leg] = _planted[leg]
		_swing_age[leg] = 0.0
		_stance_age[leg] = 0.0
		_command[leg] = Vector3.INF
		_due[leg] = false


## Advances by [param delta]: the body at [param root] moving at
## [param velocity] (world) and turning [param turn_rate] rad/s, in
## [param wanted] mode.
func update(delta: float, root: Transform3D, velocity: Vector3, turn_rate: float, wanted: Mode) -> void:
	if not _placed:
		place(root)
	if delta <= 0.0:
		return
	_change_mode(wanted, root)
	speed = Vector2(velocity.x, velocity.z).length()
	yaw_rate = turn_rate
	match mode:
		Mode.SKID:
			_skid(root)
		Mode.AIR:
			_air(delta, root)
		Mode.HOLD:
			_commanded(delta)
			stepping = _stance.has(false)
		Mode.STAND:
			_stand(delta, root, velocity)
		_:
			_stride(delta, root, velocity)


## A step on command: [param leg] lifts now and comes down on
## [param world_point] after [param seconds] (the plinth descent).
func step_to(leg: int, world_point: Vector3, seconds: float) -> void:
	_command[leg] = world_point
	if _stance[leg]:
		_stance[leg] = false
		_from[leg] = feet[leg]
		_swing_age[leg] = 0.0
		_stance_age[leg] = 0.0
		lifted.emit(leg)
	else:
		_from[leg] = feet[leg]
		_swing_age[leg] = 0.0
	_swing_time[leg] = maxf(seconds, 0.05)
	_swing_lift[leg] = maxf(WALK_LIFT, 0.25 * _from[leg].distance_to(world_point))
	stepping = true


## True while [param leg]'s hoof stands on the floor.
func planted(leg: int) -> bool:
	return _stance[leg]


## Plants [param leg] at [param world_point] now, no swing (the stomp's
## hooves coming down where the moves put them).
func plant_at(leg: int, world_point: Vector3) -> void:
	_command[leg] = Vector3.INF
	_due[leg] = false
	_land_at(leg, world_point)


## 0 while [param leg] stands, 0..1 through its swing.
func swing(leg: int) -> float:
	if _stance[leg]:
		return 0.0
	return clampf(_swing_age[leg] / maxf(_swing_time[leg], 0.001), 0.0, 1.0)


## How many hooves stand.
func down() -> int:
	var count := 0
	for leg in LEGS:
		if _stance[leg]:
			count += 1
	return count


## Where in its own stance [param leg] is (0 landing .. 1 lifting), or -1
## while it swings.
func stance_progress(leg: int) -> float:
	if not _stance[leg]:
		return -1.0
	return clampf(fposmod(cycle - _offsets[leg], 1.0) / maxf(duty, 0.01), 0.0, 1.0)


# --- modes ---------------------------------------------------------------------

func _change_mode(wanted: Mode, root: Transform3D) -> void:
	if wanted == mode:
		return
	var previous := mode
	mode = wanted
	match mode:
		Mode.SKID:
			# everything down where it is, then it drags
			for leg in LEGS:
				if not _stance[leg]:
					_land_at(leg, _on_floor(root, feet[leg]))
				_skid_local[leg] = root.affine_inverse() * feet[leg]
		Mode.AIR:
			for leg in LEGS:
				if _stance[leg]:
					_stance[leg] = false
					_from[leg] = feet[leg]
					_swing_age[leg] = 0.0
					_swing_time[leg] = 0.25
					lifted.emit(leg)
				_command[leg] = Vector3.INF
		Mode.WALK:
			_offsets = WALK_OFFSETS.duplicate()
			if previous == Mode.GALLOP:
				_phase_from_feet()
		Mode.GALLOP:
			_offsets = GALLOP_OFFSETS.duplicate()
			if previous == Mode.WALK:
				_phase_from_feet()
		_:
			pass
	if previous == Mode.AIR:
		# touchdown: all four under the body at once
		for leg in LEGS:
			_land_at(leg, _floor_point(root, NEUTRAL[leg]))
		_settling = -1
	elif previous == Mode.SKID and mode != Mode.SKID:
		for leg in LEGS:
			_planted[leg] = feet[leg]


## Standing: a hoof off its rest steps back under, one at a time (a hoof
## still in the air from a stride comes down under the body first).
func _stand(delta: float, root: Transform3D, velocity: Vector3) -> void:
	_commanded(delta)
	for leg in LEGS:
		if _stance[leg] or _command[leg] != Vector3.INF:
			continue
		_swing_age[leg] += delta
		if _swing_age[leg] >= _swing_time[leg]:
			_land_at(leg, _floor_point(root, NEUTRAL[leg]))
			if _settling == leg:
				_settling = -1
		else:
			feet[leg] = _arc(leg, _floor_point(root, NEUTRAL[leg]))
	if _settling >= 0 and _stance[_settling]:
		_settling = -1
	if _settling < 0 and not _stance.has(false):
		# the hoof furthest from its place first (in the lateral order on a tie)
		var worst := -1
		var worst_off := SETTLE
		for leg: int in [2, 0, 3, 1]:
			var off := _off_rest(root, leg)
			if off > worst_off + 0.001:
				worst_off = off
				worst = leg
		if worst >= 0:
			_settling = worst
			_stance[worst] = false
			_from[worst] = feet[worst]
			_swing_age[worst] = 0.0
			_swing_time[worst] = SETTLE_SWING
			_swing_lift[worst] = SETTLE_LIFT
			_stance_age[worst] = 0.0
			lifted.emit(worst)
	for leg in LEGS:
		if _stance[leg]:
			_stance_age[leg] += delta
	stepping = _stance.has(false) or Vector2(velocity.x, velocity.z).length() > MOVE_MIN


## The walk and the gallop: the cycle carries each hoof through its stance
## and swing.
func _stride(delta: float, root: Transform3D, velocity: Vector3) -> void:
	var drive := maxf(speed, absf(yaw_rate) * TURN_ARM)
	var gallop := mode == Mode.GALLOP
	var stride := GALLOP_STRIDE if gallop else WALK_STRIDE
	var bounds := GALLOP_FREQUENCY if gallop else WALK_FREQUENCY
	var wanted_frequency := clampf(drive / stride, bounds.x, bounds.y)
	var wanted_duty := GALLOP_DUTY if gallop else WALK_DUTY
	if speed > 0.01:
		wanted_duty = minf(wanted_duty, MAX_SWEEP * wanted_frequency / speed)
	frequency = move_toward(frequency, wanted_frequency, FREQUENCY_RATE * delta)
	duty = move_toward(duty, maxf(wanted_duty, 0.15), DUTY_RATE * delta)
	lift = GALLOP_LIFT if gallop else WALK_LIFT
	var moving := drive > MOVE_MIN
	_commanded(delta)
	if not moving:
		# too slow to stride: it settles like a standing bull
		_stand(delta, root, velocity)
		return
	_settling = -1
	stepping = true
	var before := cycle
	var advanced := frequency * delta
	cycle = fposmod(cycle + advanced, 1.0)
	# a hoof left behind lifts out of turn only when it is the next in the
	# sequence anyway (and lands on its own beat: the rhythm holds)
	var next_up := -1
	var soonest := 2.0
	for leg in LEGS:
		if _stance[leg] and _command[leg] == Vector3.INF and not _due[leg]:
			var wait := fposmod(fposmod(_offsets[leg] + duty, 1.0) - cycle, 1.0)
			if wait < soonest:
				soonest = wait
				next_up = leg
	for leg in LEGS:
		if _command[leg] != Vector3.INF:
			continue
		if _stance[leg]:
			_stance_age[leg] += delta
			var lift_at := fposmod(_offsets[leg] + duty, 1.0)
			if _crossed(before, advanced, lift_at):
				_due[leg] = true
			elif leg == next_up and (_stance_age[leg] > OVERDUE / frequency or _behind(root, leg) > LEFT_BEHIND):
				_due[leg] = true
		else:
			_swing_age[leg] += delta
			if _swing_age[leg] >= _swing_time[leg]:
				_land_at(leg, _target(leg, root, velocity, 0.0))
	# the hooves whose beat has come lift in the order their beats came (a
	# beat that fell while another hoof swung is kept, not dropped)
	var ready: Array[int] = []
	for leg in LEGS:
		if _due[leg] and _stance[leg]:
			ready.append(leg)
	ready.sort_custom(func(a: int, b: int) -> bool:
		return fposmod(cycle - fposmod(_offsets[a] + duty, 1.0), 1.0) > fposmod(cycle - fposmod(_offsets[b] + duty, 1.0), 1.0))
	for leg in ready:
		if _may_lift(leg):
			_due[leg] = false
			_lift(leg)
	for leg in LEGS:
		if not _stance[leg] and _command[leg] == Vector3.INF:
			var left := maxf(_swing_time[leg] - _swing_age[leg], 0.0)
			feet[leg] = _arc(leg, _target(leg, root, velocity, left))


## The walk keeps three hooves down: a hoof waits while another swings.
func _may_lift(leg: int) -> bool:
	if mode == Mode.GALLOP:
		return true
	for other in LEGS:
		if other != leg and not _stance[other]:
			return false
	return true


func _skid(root: Transform3D) -> void:
	for leg in LEGS:
		feet[leg] = root * _skid_local[leg]
		feet[leg].y = root.origin.y
		_planted[leg] = feet[leg]
	stepping = speed > MOVE_MIN


func _air(delta: float, root: Transform3D) -> void:
	for leg in LEGS:
		_swing_age[leg] += delta
		var w := clampf(_swing_age[leg] / 0.25, 0.0, 1.0)
		var tucked := root * TUCK[leg]
		feet[leg] = _from[leg].lerp(tucked, w * w * (3.0 - 2.0 * w)) if w < 1.0 else tucked
	stepping = true


## Steps on command (any mode): the hoof flies to its point in its time.
func _commanded(delta: float) -> void:
	for leg in LEGS:
		var target := _command[leg]
		if target == Vector3.INF:
			continue
		_swing_age[leg] += delta
		if _swing_age[leg] >= _swing_time[leg]:
			_command[leg] = Vector3.INF
			_land_at(leg, target)
		else:
			feet[leg] = _arc(leg, target)


# --- inside ----------------------------------------------------------------------

func _lift(leg: int) -> void:
	_stance[leg] = false
	_from[leg] = _planted[leg]
	_swing_age[leg] = 0.0
	_stance_age[leg] = 0.0
	# a swing is the rest of the cycle after its stance: a hoof that lifted
	# late lands late by as much (the others go on in their turn), never
	# waiting a whole cycle for its beat
	_swing_time[leg] = maxf((1.0 - duty) / maxf(frequency, 0.01), MIN_SWING)
	_swing_lift[leg] = lift
	lifted.emit(leg)


func _land_at(leg: int, point: Vector3) -> void:
	_stance[leg] = true
	_stance_age[leg] = 0.0
	_planted[leg] = point
	feet[leg] = point
	landed.emit(leg)


## Where a swinging [param leg]'s hoof is now on its way to [param to]: an
## arc that lifts early and reaches late.
func _arc(leg: int, to: Vector3) -> Vector3:
	var w := swing(leg)
	var along := w * w * (3.0 - 2.0 * w)
	var point := _from[leg].lerp(to, along)
	point.y += _swing_lift[leg] * sin(PI * pow(w, 0.8))
	return point


## Where [param leg] lands if it lands [param ahead] s from now: under its
## shoulder or hip half a stance after that, the body carried on by its
## velocity and its turn.
func _target(leg: int, root: Transform3D, velocity: Vector3, ahead: float) -> Vector3:
	var flat := Vector3(velocity.x, 0.0, velocity.z)
	var half := minf(duty / maxf(frequency, 0.01) * 0.5, MAX_SWEEP * 0.5 / maxf(flat.length(), 0.1))
	var t := ahead + half
	var turn := clampf(yaw_rate * t, -TURN_LEAD, TURN_LEAD)
	var later := Transform3D(Basis(Vector3.UP, turn) * root.basis.orthonormalized(), root.origin + flat * t)
	return _floor_point(later, NEUTRAL[leg])


## Picks up the cycle where the standing hooves say it is (a change of
## gait without a jump).
func _phase_from_feet() -> void:
	for leg: int in [2, 3, 0, 1]:
		if _stance[leg]:
			cycle = fposmod(_offsets[leg] + duty * 0.5, 1.0)
			return


## True when a cycle that advanced by [param advanced] from [param before]
## passed [param point] (on the circle).
static func _crossed(before: float, advanced: float, point: float) -> bool:
	var ahead := fposmod(point - before, 1.0)
	return ahead > 0.0 and ahead <= advanced


## How far [param leg]'s planted hoof is off its resting point (flat, m).
func _off_rest(root: Transform3D, leg: int) -> float:
	var rest := _floor_point(root, NEUTRAL[leg])
	return Vector2(_planted[leg].x - rest.x, _planted[leg].z - rest.z).length()


## How far the body has run past [param leg]'s planted hoof (m, along the
## body: its distance behind its resting point).
func _behind(root: Transform3D, leg: int) -> float:
	var local := root.affine_inverse() * _planted[leg]
	return local.z - NEUTRAL[leg].z


func _floor_point(root: Transform3D, local: Vector3) -> Vector3:
	var flat := root.basis.orthonormalized()
	var point := root.origin + flat * Vector3(local.x, 0.0, local.z)
	point.y = _floor_height(root, point)
	return point


func _on_floor(root: Transform3D, point: Vector3) -> Vector3:
	return Vector3(point.x, _floor_height(root, point), point.z)


func _floor_height(root: Transform3D, point: Vector3) -> float:
	if floor_of.is_valid():
		return float(floor_of.call(point))
	return root.origin.y
