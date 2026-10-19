extends TestCase
## The gate locks in a scene (design 4.2): the right weapon opens each one
## (once, the way is free), a wrong one only shows the hint; the contract
## for the save (gate_id, opened, open_instantly) and the chain fixes of
## design 1 (a punch at a chain hits the chain even beside an exhibit, the
## gatling's chain follows the same rule and line).

var user: Node3D
var holder: WeaponHolder
var hints: Array


func before_each() -> void:
	Greybox.box(self, Vector3(0, -0.5, 0), Vector3(80, 1, 80), Color.GRAY)
	user = Node3D.new()
	add_child(user)
	holder = WeaponHolder.new()
	holder.user = user
	holder.position = Vector3(0, 1.5, 0)
	user.add_child(holder)
	hints = watch(Events.hint_requested)


func _give(id: StringName) -> WeaponState:
	var state := holder.give(load("res://src/weapons/data/%s.tres" % id))
	holder.select_id(id)
	return state


## [param lock] placed [param z] metres in front of the guard, its front
## (-Z) turned toward him.
func _lock(lock: GateLock, z: float) -> GateLock:
	lock.transform = Transform3D(Basis(Vector3.UP, PI), Vector3(0, 0, z))
	lock.gate_id = &"test_gate"
	add_child(lock)
	return lock


func _shoot(times: int = 1, gap_frames: int = 20) -> void:
	for i in times:
		holder.try_fire()
		await physics_frames(gap_frames)


func test_the_shotgun_breaks_a_chain_and_the_gate_swings_open() -> void:
	var lock := _lock(ChainLock.new(), -3.0)
	var opened := watch(lock.opened)
	holder.position = Vector3(0, 1.05, 0)   # level with the chain
	_give(&"shotgun")
	await physics_frames(3)
	assert_true(lock.blocks_passage())
	holder.try_fire()
	assert_true(lock.is_open)
	assert_eq(opened.size(), 1)
	assert_false(lock.blocks_passage())
	assert_eq(lock.blocker.collision_layer, 0, "the way is free")
	await physics_frames(90)
	assert_eq(opened.size(), 1, "once")


func test_pistol_shots_only_spark_on_a_chain_and_show_the_line() -> void:
	var lock := _lock(ChainLock.new(), -3.0)
	holder.position = Vector3(0, 1.05, 0)
	_give(&"pistol")
	await physics_frames(3)
	await _shoot(3)
	assert_false(lock.is_open)
	assert_gt(hints.size(), 0, "the hint shows")
	if not hints.is_empty():
		assert_eq(hints[0][0], tr("LOCK_CHAIN_PROMPT"))


func test_three_punches_break_a_chain_even_with_an_exhibit_beside_it() -> void:
	var lock := _lock(ChainLock.new(), -1.4)
	var figure := WaxFigure.new()
	figure.max_health = 500.0
	figure.position = Vector3(0.55, 0, -0.95)   # nearer the sweep's centre than the chain
	add_child(figure)
	holder.position = Vector3(0, 1.05, 0)
	await physics_frames(5)
	for i in 2:
		assert_true(holder.try_punch())
		await physics_frames(30)
	assert_eq(lock.tally.strikes, 2, "the chain took the punches")
	assert_eq(figure.health.current, 500.0, "not the figure beside it")
	assert_false(lock.is_open, "two are not enough")
	holder.try_punch()
	assert_true(lock.is_open, "the third one does it")


func test_shotgun_hits_add_up_within_0_4_s() -> void:
	var lock := _lock(ChainLock.new(), -3.0) as ChainLock
	await physics_frames(3)
	var hit := DamageInfo.make(15.0, DamageInfo.Kind.BALLISTIC)
	hit.weapon = &"shotgun"
	lock.take_damage(hit)
	await physics_frames(30)
	assert_false(lock.is_open, "15 is not enough")
	lock.take_damage(hit)
	await physics_frames(60)
	assert_false(lock.is_open, "the first one is long gone")
	lock.take_damage(hit)
	await physics_frames(18)
	lock.take_damage(hit)
	assert_true(lock.is_open, "two barrels from afar")


func test_a_flare_blast_smashes_boards_punches_take_five() -> void:
	var boards := _lock(BoardsLock.new(), -4.0)
	_give(&"flare")
	await physics_frames(3)
	holder.try_fire()
	await physics_frames(30)
	assert_true(boards.is_open, "any blast")
	var again := _lock(BoardsLock.new(), -1.3)
	await physics_frames(3)
	for i in 4:
		holder.try_punch()
		await physics_frames(30)
	assert_false(again.is_open, "four punches")
	holder.try_punch()
	assert_true(again.is_open, "the fifth")


func test_the_pistol_only_knocks_splinters_off_boards() -> void:
	var boards := _lock(BoardsLock.new(), -4.0)
	_give(&"pistol")
	await physics_frames(3)
	await _shoot(4)
	assert_false(boards.is_open)


func test_a_volley_brings_a_cracked_wall_down() -> void:
	var wall := _lock(CrackedWall.new(), -7.0)
	_give(&"hwacha")
	await physics_frames(3)
	holder.try_fire()
	await physics_frames(50)
	assert_true(wall.is_open)
	assert_false(wall.blocks_passage())


func test_a_flare_from_afar_does_not_crack_a_wall_three_up_close_do() -> void:
	var far := _lock(CrackedWall.new(), -10.0)
	_give(&"flare")
	await physics_frames(3)
	assert_true(holder.try_fire())
	await physics_frames(40)
	assert_false(far.is_open, "one flare from 10 m")
	far.queue_free()
	await physics_frames(2)
	var near := _lock(CrackedWall.new(), -3.0)
	await physics_frames(60)   # (the flare gun reloads: 1.4 s)
	for i in 2:
		assert_true(holder.try_fire(), "flare %d" % (i + 1))
		await physics_frames(90)
	assert_false(near.is_open, "two flares")
	assert_eq(near.tally.strikes, 2)
	assert_true(holder.try_fire())
	await physics_frames(20)
	assert_true(near.is_open, "the third flare up close")


func test_the_shotgun_does_nothing_to_a_cracked_wall() -> void:
	var wall := _lock(CrackedWall.new(), -3.0)
	_give(&"shotgun")
	await physics_frames(3)
	await _shoot(2, 30)
	assert_false(wall.is_open)


func _rope(z: float) -> RopeLock:
	var rope := RopeLock.new()
	rope.height = 3.0
	rope.hang = 2.2
	return _lock(rope, z) as RopeLock


func test_the_rifle_cuts_a_rope_from_afar() -> void:
	var rope := _rope(-40.0)
	_give(&"rifle_hunt")
	await physics_frames(3)
	holder.try_fire()
	assert_true(rope.is_open)
	assert_false(rope.blocks_passage(), "a rope blocks nothing itself")


func test_the_pistol_cuts_a_rope_only_up_close() -> void:
	var far := _rope(-20.0)
	_give(&"pistol")
	await physics_frames(3)
	holder.try_fire()
	assert_false(far.is_open, "20 m is too far")
	assert_eq(hints.back()[0] if not hints.is_empty() else "", tr("LOCK_ROPE_FAR"))
	far.queue_free()
	await physics_frames(20)
	var near := _rope(-10.0)
	await physics_frames(3)
	holder.try_fire()
	assert_true(near.is_open, "10 m")


func test_buckshot_does_not_cut_a_rope() -> void:
	var rope := _rope(-6.0)
	_give(&"shotgun")
	await physics_frames(3)
	await _shoot(2, 30)
	assert_false(rope.is_open)


func test_a_harpoon_pulls_a_grate_off() -> void:
	var hook := HookLock.new()
	var grate := _lock(hook, -6.0) as HookLock
	var opened := watch(grate.opened)
	_give(&"harpoon")
	await physics_frames(3)
	holder.try_fire()
	await physics_frames(20)
	assert_true(grate.is_open)
	assert_eq(opened.size(), 1)
	assert_false(grate.blocks_passage())


func test_a_harpoon_swings_the_canoe_down_into_a_bridge() -> void:
	var hook := HookLock.new()
	hook.mode = HookLock.Mode.SWING
	hook.size = Vector2(1.0, 5.0)
	var canoe := _lock(hook, -8.0) as HookLock
	_give(&"harpoon")
	await physics_frames(3)
	assert_eq(canoe.bridge.collision_layer, 0, "no bridge yet")
	holder.try_fire()
	await physics_frames(70)
	assert_true(canoe.is_open)
	assert_eq(canoe.bridge.collision_layer, Layers.WORLD, "walkable now")


func test_bullets_do_not_pull_a_hook() -> void:
	var grate := _lock(HookLock.new(), -6.0)
	_give(&"pistol")
	await physics_frames(3)
	await _shoot(2)
	assert_false(grate.is_open)
	assert_gt(hints.size(), 0)


func test_a_bolt_opens_only_from_its_side() -> void:
	var door := _lock(BoltLock.new(), -2.0) as BoltLock
	await physics_frames(3)
	var front := Node3D.new()
	front.position = Vector3(0, 0, -0.5)   # in front of the door (-Z side of it)
	add_child(front)
	var back := Node3D.new()
	back.position = Vector3(0, 0, -3.5)
	add_child(back)
	door.use(front)
	assert_false(door.is_open, "bolted from the other side")
	assert_eq(hints.back()[0] if not hints.is_empty() else "", tr("LOCK_BOLT_PROMPT"))
	door.use(back)
	assert_true(door.is_open, "drawn from the bolt's side")


func test_no_shot_opens_a_bolted_door() -> void:
	var door := _lock(BoltLock.new(), -3.0)
	_give(&"shotgun")
	await physics_frames(3)
	await _shoot(2, 30)
	assert_false(door.is_open)


func test_the_shutter_waits_for_power() -> void:
	var shutter := _lock(PowerShutter.new(), -4.0) as PowerShutter
	_give(&"hwacha")
	await physics_frames(3)
	holder.try_fire()
	await physics_frames(40)
	assert_false(shutter.is_open, "no weapon moves it")
	shutter.use(user)
	assert_eq(hints.back()[0] if not hints.is_empty() else "", tr("LOCK_POWER_HINT"))
	shutter.power_on()
	assert_true(shutter.is_open)
	assert_false(shutter.blocks_passage())


func test_open_instantly_is_quiet() -> void:
	for lock in [ChainLock.new(), BoardsLock.new(), CrackedWall.new(), RopeLock.new(), HookLock.new(), BoltLock.new(), PowerShutter.new()]:
		var gate := lock as GateLock
		var opened := watch(gate.opened)
		var chunks := Fx.chunk_count()
		_lock(gate, -5.0)
		gate.open_instantly()
		await physics_frames(2)
		assert_true(gate.is_open, gate.get_class())
		assert_false(gate.blocks_passage())
		assert_eq(opened.size(), 0, "no signal")
		assert_eq(Fx.chunk_count(), chunks, "no debris")
		gate.queue_free()
		await physics_frames(1)


func test_open_instantly_before_entering_the_tree() -> void:
	var gate := BoardsLock.new()
	gate.open_instantly()
	_lock(gate, -5.0)
	await physics_frames(2)
	assert_false(gate.blocks_passage())
	assert_eq(gate.blocker.collision_layer, 0)


func test_the_use_prompt_reads_the_lock() -> void:
	var lock := _lock(ChainLock.new(), -1.5)
	await physics_frames(3)
	var probe := Interactor.new()
	var target := probe.probe(user.get_world_3d().direct_space_state, Vector3(0, 1.1, 0), Vector3.FORWARD, user)
	assert_not_null(target, "the use-probe finds it")
	if target != null:
		assert_eq(target.prompt(), tr("LOCK_CHAIN_PROMPT"))
		target.interact(user)
		assert_false(lock.is_open, "E only rattles it")


func test_the_hud_shows_a_locks_hint() -> void:
	var hud := Hud.new()
	add_child(hud)
	await physics_frames(1)
	Events.hint_requested.emit("Łańcuch")
	assert_eq(hud.hint_text(), "Łańcuch")


func test_the_gatling_display_chain_shows_the_same_line() -> void:
	var display := ChainedDisplay.create(Transform3D(Basis(Vector3.UP, PI), Vector3(0, 0, -2.5)))
	display.persistent = false
	add_child(display)
	_give(&"pistol")
	await physics_frames(3)
	holder.try_fire()
	assert_eq(display.state, ChainedDisplay.State.LOCKED)
	assert_eq(hints.back()[0] if not hints.is_empty() else "", tr("LOCK_CHAIN_PROMPT"))
	assert_eq(display.prompt(), tr("LOCK_CHAIN_PROMPT"))


func test_a_rifle_only_rope_turns_the_pistol_away() -> void:
	var rope := RopeLock.new()
	rope.height = 3.0
	rope.hang = 2.2
	rope.requirement = &"rifle_hunt"
	_lock(rope, -8.0)
	_give(&"pistol")
	await physics_frames(3)
	holder.try_fire()
	assert_false(rope.is_open, "the pistol will not do here")
	assert_eq(hints.back()[0] if not hints.is_empty() else "", tr("LOCK_ROPE_RIFLE"))
	_give(&"rifle_hunt")
	await physics_frames(3)
	holder.try_fire()
	assert_true(rope.is_open, "the rifle cuts it")


func test_the_peep_sight_rifle_snaps_a_chain_with_one_round_from_afar() -> void:
	var lock := _lock(ChainLock.new(), -12.0)
	var opened := watch(lock.opened)
	holder.position = Vector3(0, 1.05, 0)
	holder.apply_upgrades({&"mod_rifle_peep": 1})
	_give(&"rifle_hunt")
	await physics_frames(3)
	assert_true(lock.blocks_passage())
	holder.try_fire()
	assert_true(lock.is_open, "one round from twelve metres")
	assert_eq(opened.size(), 1)
	assert_false(lock.blocks_passage())


func test_a_plain_rifle_round_only_strikes_sparks_off_a_chain() -> void:
	var lock := _lock(ChainLock.new(), -12.0)
	holder.position = Vector3(0, 1.05, 0)
	_give(&"rifle_hunt")
	await physics_frames(3)
	holder.try_fire()
	await physics_frames(2)
	assert_false(lock.is_open, "the chain holds")
	assert_eq(hints.size(), 1, "the hint shows")
