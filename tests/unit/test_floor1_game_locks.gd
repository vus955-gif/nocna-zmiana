extends TestCase
## The gate locks of Floor I without the floor: the factory gives every
## kind a lock with the GateLock contract (the p1-weapons class when the
## build has it, else the greybox GreyLock; SealGate for seals and EVENT
## gates), and the stand-ins open to the right tool only.

var _nodes: Array[Node] = []


func after_each() -> void:
	for node in _nodes:
		if is_instance_valid(node):
			node.free()
	_nodes.clear()


func _keep(node: Node) -> Node:
	_nodes.append(node)
	return node


func _grey(kind: GateSpec.Kind, requirement: StringName = GateSpec.NONE) -> GreyLock:
	var lock := GreyLock.make(kind)
	lock.gate_id = &"test_gate"
	lock.size = Vector2(2.0, 2.6)
	lock.requirement = requirement
	lock.label_key = &"GATE_CHAIN"
	add_child(_keep(lock))
	return lock


func _hit(weapon: StringName, amount: float, kind: DamageInfo.Kind = DamageInfo.Kind.BALLISTIC, from: Vector3 = Vector3(0, 1.5, -3)) -> DamageInfo:
	var shooter := Node3D.new()
	add_child(_keep(shooter))
	shooter.global_position = from
	var info := DamageInfo.make(amount, kind, shooter)
	info.weapon = weapon
	info.position = Vector3(0.0, 1.2, -0.3)
	info.normal = Vector3.BACK
	return info


func test_every_kind_has_a_lock_with_the_gate_lock_contract() -> void:
	for kind: GateSpec.Kind in GateSpec.Kind.values():
		var lock := GateLocks.make(kind)
		_keep(lock)
		assert_true(GateLocks.has_contract(lock), "%s keeps the contract" % GateSpec.kind_name(kind))
		if kind == GateSpec.Kind.SEAL or kind == GateSpec.Kind.EVENT:
			assert_true(lock is SealGate, GateSpec.kind_name(kind))
		elif GateLocks.script_for(kind) != null:
			assert_true(GateLocks.is_real(lock), "the p1-weapons lock for %s" % GateSpec.kind_name(kind))
		else:
			assert_true(lock is GreyLock, "a stand-in for %s" % GateSpec.kind_name(kind))


func test_the_registry_wins_over_the_class_names() -> void:
	GateLocks.registry[GateSpec.Kind.HOOK] = load("res://src/game/floor1/seal_gate.gd")
	var lock := GateLocks.make(GateSpec.Kind.HOOK)
	_keep(lock)
	GateLocks.registry.erase(GateSpec.Kind.HOOK)
	assert_true(lock is SealGate, "the registered script made it")


func test_open_instantly_gives_no_signal() -> void:
	var lock := GreyLock.make(GateSpec.Kind.CHAIN)
	_keep(lock)
	var heard := watch(lock.opened)
	lock.open_instantly()
	add_child(lock)
	assert_true(lock.is_open)
	assert_eq(heard.size(), 0)
	for zone in lock.zones:
		assert_eq(zone.collision_layer, 0, "an open lock takes no hits")


func test_a_chain_gives_to_a_shotgun_blast_or_three_punches() -> void:
	var lock := _grey(GateSpec.Kind.CHAIN)
	var heard := watch(lock.opened)
	lock.take_damage(_hit(&"pistol", 30.0))
	assert_false(lock.is_open, "bullets strike sparks")
	lock.take_damage(_hit(&"shotgun", 9.0))
	lock.take_damage(_hit(&"shotgun", 9.0))
	assert_false(lock.is_open, "18 is not enough")
	lock.take_damage(_hit(&"shotgun", 9.0))
	assert_true(lock.is_open, "the pellets of one blast add up to 25")
	assert_eq(heard.size(), 1)
	var punched := _grey(GateSpec.Kind.CHAIN)
	for i in 2:
		punched.take_damage(_hit(&"fists", 15.0, DamageInfo.Kind.BLUNT))
	assert_false(punched.is_open)
	punched.take_damage(_hit(&"fists", 15.0, DamageInfo.Kind.BLUNT))
	assert_true(punched.is_open, "three punches")


func test_boards_give_to_a_blast_and_five_punches() -> void:
	var lock := _grey(GateSpec.Kind.BOARDS)
	for i in 4:
		lock.take_damage(_hit(&"fists", 15.0, DamageInfo.Kind.BLUNT))
	assert_false(lock.is_open)
	lock.take_damage(_hit(&"fists", 15.0, DamageInfo.Kind.BLUNT))
	assert_true(lock.is_open, "five punches")
	var blasted := _grey(GateSpec.Kind.BOARDS)
	blasted.take_damage(_hit(&"flare", 8.0, DamageInfo.Kind.FIRE))
	assert_true(blasted.is_open, "a flare's blast")


func test_a_cracked_wall_needs_a_blast() -> void:
	var lock := _grey(GateSpec.Kind.CRACKED)
	for i in 6:
		lock.take_damage(_hit(&"fists", 15.0, DamageInfo.Kind.BLUNT))
		lock.take_damage(_hit(&"shotgun", 30.0))
	assert_false(lock.is_open, "fists and shot do nothing")
	lock.take_damage(_hit(&"flare", 10.0, DamageInfo.Kind.FIRE, Vector3(0, 1.5, -12)))
	assert_false(lock.is_open)
	assert_eq(lock.strikes, 0, "a flare from afar does not count")
	for i in 3:
		lock.take_damage(_hit(&"flare", 10.0, DamageInfo.Kind.FIRE, Vector3(0, 1.5, -3)))
	assert_true(lock.is_open, "three flares from close up")


func test_a_rope_needs_a_precise_shot() -> void:
	var near := _grey(GateSpec.Kind.ROPE, GateSpec.PRECISE)
	near.take_damage(_hit(&"pistol", 20.0, DamageInfo.Kind.BALLISTIC, Vector3(0, 1.5, -10)))
	assert_true(near.is_open, "the pistol from 10 m")
	var far := _grey(GateSpec.Kind.ROPE, GateSpec.PRECISE)
	far.take_damage(_hit(&"pistol", 20.0, DamageInfo.Kind.BALLISTIC, Vector3(0, 1.5, -20)))
	assert_false(far.is_open, "not from 20 m")
	far.take_damage(_hit(&"rifle_hunt", 85.0, DamageInfo.Kind.BALLISTIC, Vector3(0, 1.5, -40)))
	assert_true(far.is_open, "the rifle from anywhere")
	var rifle_only := _grey(GateSpec.Kind.ROPE, &"rifle_hunt")
	rifle_only.take_damage(_hit(&"pistol", 20.0, DamageInfo.Kind.BALLISTIC, Vector3(0, 1.5, -3)))
	assert_false(rifle_only.is_open, "the Planetarium's rope takes the rifle")


func test_a_bolt_opens_only_from_its_side() -> void:
	var lock := _grey(GateSpec.Kind.BOLT)
	var front := Node3D.new()
	add_child(_keep(front))
	front.global_position = Vector3(0, 0, -1)
	lock.use(front)
	assert_false(lock.is_open, "bolted from the other side")
	var back := Node3D.new()
	add_child(_keep(back))
	back.global_position = Vector3(0, 0, 1)
	assert_true(lock.on_bolt_side(back))
	lock.use(back)
	assert_true(lock.is_open, "drawn from its side")


func test_a_shutter_opens_on_power_only() -> void:
	var lock := _grey(GateSpec.Kind.POWER)
	lock.take_damage(_hit(&"shotgun", 60.0))
	lock.use(null)
	assert_false(lock.is_open)
	lock.power_on()
	assert_true(lock.is_open)


func test_a_seal_gate_opens_with_its_seal() -> void:
	var gate := SealGate.make(GateSpec.Kind.SEAL)
	gate.gate_id = &"seal_khorsabad"
	gate.requirement = &"seal_sun"
	gate.label_key = &"GATE_SEAL_SUN"
	var holds := [false]
	gate.has_key = func() -> bool: return holds[0]
	add_child(_keep(gate))
	var heard := watch(gate.opened)
	assert_true(gate.replaces_door_look(), "stone leaves instead of the bars")
	assert_eq(gate.prompt_text(), tr("GATE_SEAL_SUN"), "it names what it needs")
	gate.use(null)
	assert_false(gate.is_open)
	holds[0] = true
	assert_eq(gate.prompt_text(), tr("PROMPT_SEAL_PLACE") % tr("SEAL_SUN"))
	gate.use(null)
	assert_true(gate.is_open)
	assert_eq(heard.size(), 1)
	var grate := SealGate.make(GateSpec.Kind.EVENT)
	grate.label_key = &"GATE_GRATE"
	grate.has_key = func() -> bool: return true
	add_child(_keep(grate))
	grate.use(null)
	assert_false(grate.is_open, "the game opens the grate, not E")
	assert_false(grate.replaces_door_look(), "the bars are its look")
	grate.open()
	assert_true(grate.is_open)
