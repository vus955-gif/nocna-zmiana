extends TestCase
## The gates of Floor I in the game: a lock on every gated passage, its
## door shut and locked; a lock opened in play is saved, announced and
## opens the door; the next night it is open from the start without a
## sound or a signal; the switchboard rolls the shutters up; a seal gate
## takes its seal.

var museum: Museum


func before_each() -> void:
	Museum.level_id = &"floor1"


func after_each() -> void:
	if is_instance_valid(museum):
		museum.free()


func _museum() -> Museum:
	museum = (load(SceneFlow.MUSEUM) as PackedScene).instantiate() as Museum
	add_child(museum)
	return museum


func _door_of(gate_id: StringName) -> Door:
	var gate := museum.floor_level.layout.gate(gate_id)
	return museum.floor_level.doors.get(gate.opening) as Door


func _punch(lock: Node, times: int) -> void:
	for i in times:
		var info := DamageInfo.make(15.0, DamageInfo.Kind.BLUNT, museum.player)
		info.weapon = &"fists"
		info.position = (lock as Node3D).global_position + Vector3.UP
		lock.call(&"take_damage", info)


func test_every_gated_passage_has_a_lock_and_a_locked_door() -> void:
	GameState.new_game()
	_museum()
	await physics_frames(2)
	var gates := museum.floor_game.gates
	var on_passages := museum.floor_level.layout.gates.filter(func(g: GateSpec) -> bool: return g.opening != &"")
	assert_eq(on_passages.size(), museum.floor_level.layout.gates.size() - 1, "every gate but the gatling's chain blocks a passage")
	assert_gt(on_passages.size(), 23, "the zones' own gates (the secrets) too")
	for spec: GateSpec in on_passages:
		var lock := gates.lock_of(spec.id)
		assert_not_null(lock, spec.id)
		if lock == null:
			continue
		assert_true(GateLocks.has_contract(lock), spec.id)
		assert_eq(lock.get(&"gate_id"), spec.id)
		assert_false(bool(lock.get(&"is_open")), "%s shut in a new game" % spec.id)
		var door := _door_of(spec.id)
		assert_not_null(door, "%s has its door" % spec.id)
		if door != null:
			assert_true(door.locked and not door.is_open, "%s: its door shut and locked" % spec.id)
	assert_false(_door_of(&"seal_khorsabad").visible, "the seal gate's stone leaves stand for the bars")
	assert_true(_door_of(&"grate_crypt").visible, "the grate's bars are its look")
	# the BOLT's bolt faces the room it is drawn from
	var bolt := gates.lock_of(&"bolt_basement_egypt") as Node3D
	var spec := museum.floor_level.layout.gate(&"bolt_basement_egypt")
	var room := museum.floor_level.layout.room(spec.one_way_side)
	var into := Vector2(room.bounds().get_center().x - bolt.global_position.x, room.bounds().get_center().y - bolt.global_position.z)
	var back := bolt.global_basis.z
	assert_gt(Vector2(back.x, back.z).dot(into), 0.0, "the bolt on the Egypt side")


## Where a ray from room [param from_room]'s side of [param gate_id]'s
## opening (1.5 m out of the wall, at chest height) toward its middle first
## hits the world (the collider's owner), or null.
func _first_solid(gate_id: StringName, from_room: StringName) -> Object:
	var spec := museum.floor_level.layout.gate(gate_id)
	var passage := museum.floor_level.layout.opening(spec.opening)
	var frame := LevelBuilder.new(museum.floor_level.layout, null, null, null).passage_frame(passage)   # +Z toward room A
	var out := frame.basis.z if from_room == passage.room_a else -frame.basis.z
	var middle := frame.origin + Vector3.UP * 1.3
	var query := PhysicsRayQueryParameters3D.create(middle + out * (passage.depth() * 0.5 + 1.5), middle, Layers.WORLD)
	var hit := museum.get_world_3d().direct_space_state.intersect_ray(query)
	return hit["collider"] if not hit.is_empty() else null


## Finding W7-1: a lock with a body of its own holds its passage - the
## door's leaves (flush with room A's face) no longer stand in front of it.
func test_a_lock_with_a_body_holds_its_passage_and_nothing_hides_it() -> void:
	GameState.new_game()
	_museum()
	await physics_frames(2)
	var gates := museum.floor_game.gates
	for gate_id: StringName in [&"boards_tomb", &"bolt_lions_bassae", &"bolt_asia_planetarium", &"boards_staff_stairs"]:
		var lock := gates.lock_of(gate_id)
		assert_true(GateController.holds_passage(lock), gate_id)
		assert_eq(lock.get_parent(), museum.floor_level.walk_dynamic, "%s: its body cuts the navmesh" % gate_id)
		var door := _door_of(gate_id)
		assert_true(door.locked, "%s: the door keeps the state" % gate_id)
		assert_false(door.visible)
		for body in door.find_children("*", "CollisionObject3D", true, false):
			assert_eq((body as CollisionObject3D).collision_layer, 0, "%s: nothing of the door is solid" % gate_id)
		var passage := museum.floor_level.layout.opening(museum.floor_level.layout.gate(gate_id).opening)
		for room_id in [passage.room_a, passage.room_b]:
			var first := _first_solid(gate_id, room_id)
			var solid := first as Node
			assert_true(solid != null and lock.is_ancestor_of(solid), "%s from %s: the lock's own body comes first (%s)" % [gate_id, room_id, solid])
	# a seal gate leaves the door the solid part
	var seal := gates.lock_of(&"seal_khorsabad")
	assert_false(GateController.holds_passage(seal))
	assert_ne(seal.get_parent(), museum.floor_level.walk_dynamic)
	var leaves := _door_of(&"seal_khorsabad").find_children("*", "CollisionObject3D", true, false)
	assert_true(leaves.any(func(b: Node) -> bool: return (b as CollisionObject3D).collision_layer == Layers.WORLD), "the seal gate's door still holds")


func test_a_gate_opened_in_play_is_saved_and_open_the_next_night() -> void:
	GameState.new_game()
	_museum()
	await physics_frames(2)
	var announced := watch(Events.gate_opened)
	var lock := museum.floor_game.gates.lock_of(&"boards_staff_stairs")
	_punch(lock, 4)
	assert_false(GameState.is_gate_open(&"boards_staff_stairs"), "four punches are not enough")
	_punch(lock, 1)
	assert_true(GameState.is_gate_open(&"boards_staff_stairs"), "five punches: open for good")
	assert_eq(announced.size(), 1)
	assert_eq(announced[0][0], &"boards_staff_stairs")
	var door := _door_of(&"boards_staff_stairs")
	assert_false(door.locked, "the door is free")
	await physics_frames(90)
	assert_true(door.is_open, "and swung open")
	var on_disk := PersistentState.new()
	add_child(on_disk)
	assert_true(on_disk.load_game())
	assert_true(on_disk.is_gate_open(&"boards_staff_stairs"), "saved at once")
	on_disk.free()
	# the next night: open from the start, no effects, no signal
	museum.free()
	RunState.reset()
	GameState.night += 1
	var again := watch(Events.gate_opened)
	_museum()
	await physics_frames(2)
	var lock_again := museum.floor_game.gates.lock_of(&"boards_staff_stairs")
	assert_true(bool(lock_again.get(&"is_open")))
	assert_true(_door_of(&"boards_staff_stairs").is_open)
	assert_eq(again.size(), 0, "nothing announced at night start")


func test_the_switchboard_rolls_the_shutters_up() -> void:
	GameState.new_game()
	_museum()
	await physics_frames(2)
	var board := museum.floor_game.switchboard
	assert_not_null(board)
	board.interact(museum.player)
	assert_false(GameState.has_flag(&"power_north"), "no fuses, no power")
	assert_eq(board.prompt(), tr("SWITCHBOARD_NEED") % [0, 2])
	GameState.add_item(&"fuse_basement")
	GameState.add_item(&"fuse_assyria")
	board.interact(museum.player)
	assert_true(GameState.has_flag(&"power_north"))
	for gate_id: StringName in [&"shutter_americas", &"shutter_asia"]:
		assert_true(GameState.is_gate_open(gate_id), gate_id)
		assert_false(_door_of(gate_id).locked, gate_id)
	assert_false(board.can_interact(museum.player), "once is enough")


func test_a_seal_gate_takes_its_seal() -> void:
	GameState.new_game()
	_museum()
	await physics_frames(2)
	var gate := museum.floor_game.gates.lock_of(&"seal_khorsabad") as SealGate
	assert_not_null(gate)
	gate.use(museum.player)
	assert_false(gate.is_open, "no Seal of the Sun yet")
	assert_eq(gate.prompt_text(), tr("GATE_SEAL_SUN"))
	GameState.add_seal(&"seal_sun")
	gate.use(museum.player)
	assert_true(gate.is_open)
	assert_true(GameState.is_gate_open(&"seal_khorsabad"))
	assert_false(_door_of(&"seal_khorsabad").locked)
