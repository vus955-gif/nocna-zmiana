class_name GateController
extends Node3D
## Every gate of Floor I as a lock in the world (design 4.2), wired to the
## save: for each GateSpec of the layout that blocks a passage, the lock of
## its kind (GateLocks) stands on the floor in the middle of the opening
## (or at the gate's marker), its front (-Z) toward room A of the passage -
## a BOLT with its bolt (+Z) toward the room it is drawn from.
## Who holds the passage shut:
## - a lock with a body of its own (a chain's gates, boards, a cracked wall,
##   a bolted door, a shutter, a hook's grate: GateLock.blocker) holds it
##   itself: the passage's Door keeps only its state (shut and locked until
##   the gate opens: MuseumFloorLevel) - no look and no collision, so its
##   leaves, flush with room A's face of the opening, never stand between
##   the guard and the lock's hit zones and prompt (finding W7-1) - and the
##   lock moves among the walkable navigation's changing sources
##   (MuseumFloorLevel.walk_dynamic): its body cuts the navmesh while it is
##   shut, like the door did;
## - every other lock (a rope or a hook far from the opening, a seal gate,
##   the grate the game opens) leaves the Door as the solid part; a seal
##   gate's stone leaves take over its look.
## A gate open in the save is open from the start (the level opened its
## door before the bake; the lock gets open_instantly(): no effects, no
## signal). A lock that opens in play: GameState.open_gate(), the level
## opens the door (the navigation rebakes), Events.gate_opened, a save.
## Locks on objects (the gatling's chained case) belong to whoever builds
## the object; adopt() wires them the same way.
## A HOOK gate with a drop in front of its opening (room A's floor at least
## GAP_DROP m below the opening's: the Americas' collapsed floor) gets the
## canoe: a HookLock in SWING mode standing in the doorway, long enough to
## lie across the gap onto the floor beyond, with a deck wide enough for
## the exhibits' navigation (a source of the walkable region: it is baked
## in once the canoe is down).

signal gate_opened(gate_id: StringName)

## A real rope lock stands this far out in front of its opening (its
## counterweight holds the bars from there).
const ROPE_LEAD := 1.5
## Room A this far below the opening's floor: a gap the hooked object bridges.
const GAP_DROP := 1.0
## The canoe reaches this far onto the floor beyond the gap (m).
const BRIDGE_OVERLAP := 0.75
## Width of the canoe's walkable deck (m).
const BRIDGE_DECK := 2.2

var level: MuseumFloorLevel
var game: PersistentState
var run: NightState
## Gate id -> its lock node.
var locks: Dictionary = {}
## Locks holding their passage themselves (moved to the level's walkable
## sources: they go when this controller goes).
var holding: Array[Node3D] = []

var _builder: LevelBuilder


func setup(for_level: MuseumFloorLevel, for_game: PersistentState, for_run: NightState) -> void:
	level = for_level
	game = for_game
	run = for_run
	name = "Gates"
	_builder = LevelBuilder.new(level.layout, null, null, null)
	for spec in level.layout.gates:
		if spec.opening != &"":
			_place(spec)
	if game.has_flag(Switchboard.POWER_FLAG):
		_settle_power()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		for lock in holding:
			if is_instance_valid(lock):
				lock.free()
		holding.clear()


func lock_of(gate_id: StringName) -> Node3D:
	return locks.get(gate_id) as Node3D


func is_open(gate_id: StringName) -> bool:
	return game.is_gate_open(gate_id)


## Wires a lock that stands on an object (built by its owner) under
## [param gate_id]: [param opened_signal] of [param node] opens the gate.
func adopt(gate_id: StringName, node: Node, opened_signal: StringName = &"opened") -> void:
	locks[gate_id] = node
	if node.has_signal(opened_signal):
		node.connect(opened_signal, _on_lock_opened.bind(gate_id), CONNECT_ONE_SHOT)


## Opens [param gate_id] from the game (an EVENT gate: the grate after the
## T-Rex): its lock opens with its effects and the gate is recorded.
func open_gate(gate_id: StringName) -> void:
	var lock := lock_of(gate_id)
	if lock != null and lock.has_method(&"open") and not bool(lock.get(&"is_open")):
		lock.call(&"open")   # -> opened -> recorded
	elif not game.is_gate_open(gate_id):
		_on_lock_opened(gate_id)


## Power is back (the switchboard): every fire shutter rolls up.
func power_on() -> void:
	for spec in level.layout.gates:
		if spec.kind != GateSpec.Kind.POWER or game.is_gate_open(spec.id):
			continue
		var lock := lock_of(spec.id)
		if lock != null and lock.has_method(&"power_on"):
			lock.call(&"power_on")
		elif lock != null:
			lock.call(&"open")
		else:
			_on_lock_opened(spec.id)


## How long a bridge over the gap in front of [param passage] must be
## (from the lock at [param frame], along its -Z, to BRIDGE_OVERLAP m past
## the gap's far edge); 0 when room A is no gap.
static func gap_span(floor_layout: LevelLayout, passage: OpeningSpec, frame: Transform3D) -> float:
	var room := floor_layout.room(passage.room_a)
	if room == null or room.floor_y > passage.floor_y - GAP_DROP:
		return 0.0
	var inverse := frame.affine_inverse()
	var far := 0.0
	for part in room.parts:
		for corner: Vector2 in [part.position, Vector2(part.end.x, part.position.y), part.end, Vector2(part.position.x, part.end.y)]:
			far = maxf(far, -(inverse * Vector3(corner.x, passage.floor_y, corner.y)).z)
	return far + BRIDGE_OVERLAP if far > 0.0 else 0.0


## Where the lock of [param spec] on [param passage] stands.
func lock_frame(spec: GateSpec, passage: OpeningSpec) -> Transform3D:
	if spec.marker != &"" and level.markers.has(spec.marker):
		return level.markers[spec.marker]
	var frame := _builder.passage_frame(passage)   # -Z from room A to room B
	var turn := true   # front toward room A
	if spec.kind == GateSpec.Kind.BOLT:
		turn = spec.one_way_side == passage.room_b   # the bolt (+Z) toward its room
	if turn:
		frame = Transform3D(frame.basis.rotated(Vector3.UP, PI), frame.origin)
	return frame


func _place(spec: GateSpec) -> void:
	var passage := level.layout.opening(spec.opening)
	if passage == null:
		FloorGame.warn_once("GateController: gate %s blocks no opening %s" % [spec.id, spec.opening])
		return
	var lock := GateLocks.make(spec.kind)
	lock.name = "Gate_" + String(spec.id)
	lock.set(&"gate_id", spec.id)
	lock.set(&"size", Vector2(passage.width(), passage.height()))
	if lock is GreyLock:
		(lock as GreyLock).requirement = spec.requirement
		(lock as GreyLock).label_key = spec.label_key
	elif lock is SealGate:
		var gate := lock as SealGate
		gate.requirement = spec.requirement
		gate.label_key = spec.label_key
		gate.has_key = _has_requirement.bind(spec.requirement)
	elif &"requirement" in lock:
		lock.set(&"requirement", spec.requirement)   # a real lock with a requirement (a rifle-only rope)
	var frame := lock_frame(spec, passage)
	if spec.kind == GateSpec.Kind.ROPE and GateLocks.is_real(lock) and spec.marker == &"":
		frame.origin += -frame.basis.z * ROPE_LEAD
	lock.transform = frame
	var canoe := _as_canoe(lock, spec, passage, frame)
	var open := game.is_gate_open(spec.id) or level.is_gate_open(spec.id)
	if open:
		lock.call(&"open_instantly")
	add_child(lock)
	locks[spec.id] = lock
	if canoe != null and canoe.bridge != null and level.navigation != null:
		# the deck is a walkable source: baked in once the canoe is down
		level.add_walk_source(canoe.bridge)
	lock.connect(&"opened", _on_lock_opened.bind(spec.id), CONNECT_ONE_SHOT)
	var door := level.doors.get(spec.opening) as Door
	if door == null:
		return
	if holds_passage(lock):
		_hand_over(lock, door)
	elif _replaces_door_look(lock):
		door.visible = false


## True when [param lock] has a body that holds its passage shut by itself
## (GateLock.blocker), so the passage's Door may step aside.
static func holds_passage(lock: Node) -> bool:
	if not GateLocks.is_real(lock) or not &"blocker" in lock:
		return false
	var body: Variant = lock.get(&"blocker")
	return is_instance_valid(body) and body is StaticBody3D


## [param lock] holds its passage: the Door keeps its state only (no look,
## no collision: nothing of it stands in front of the lock) and the lock
## joins the walkable navigation's changing sources (its body cuts the
## navmesh at the next bake round it, as the shut door did).
func _hand_over(lock: Node3D, door: Door) -> void:
	door.visible = false
	for body in door.find_children("*", "CollisionObject3D", true, false):
		var solid := body as CollisionObject3D
		solid.collision_layer = 0
		solid.collision_mask = 0
	if level.walk_dynamic != null and is_instance_valid(level.walk_dynamic):
		lock.reparent(level.walk_dynamic)
		holding.append(lock)


## [param lock] as the canoe over a gap (HookLock in SWING mode, its length
## and deck set), or null for every other lock.
func _as_canoe(lock: Node3D, spec: GateSpec, passage: OpeningSpec, frame: Transform3D) -> HookLock:
	if spec.kind != GateSpec.Kind.HOOK or not lock is HookLock:
		return null
	var span := gap_span(level.layout, passage, frame)
	if span <= 0.0:
		return null
	var canoe := lock as HookLock
	canoe.mode = HookLock.Mode.SWING
	canoe.size = Vector2(passage.width(), span)
	canoe.deck_width = BRIDGE_DECK
	return canoe


## A lock with a body (or look) of its own hides the greybox Door's.
static func _replaces_door_look(lock: Node) -> bool:
	if lock.has_method(&"replaces_door_look"):
		return bool(lock.call(&"replaces_door_look"))
	return GateLocks.is_real(lock) and lock.has_method(&"blocks_passage") and bool(lock.call(&"blocks_passage"))


func _has_requirement(token: StringName) -> bool:
	return ProgressRules.has_requirement(FloorProgress.from_game(game), token)


## The switchboard worked on an earlier night: every shutter is up.
func _settle_power() -> void:
	for spec in level.layout.gates:
		if spec.kind != GateSpec.Kind.POWER or game.is_gate_open(spec.id):
			continue
		game.open_gate(spec.id)
		level.open_gate(spec.id, true)
		var lock := lock_of(spec.id)
		if lock != null:
			lock.call(&"open_instantly")


func _on_lock_opened(gate_id: StringName) -> void:
	game.open_gate(gate_id)
	level.open_gate(gate_id)
	Events.gate_opened.emit(gate_id)
	NightRules.save_progress(game, run)
	gate_opened.emit(gate_id)
