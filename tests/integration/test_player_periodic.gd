extends TestCase
## A tick of damage over time (DamageInfo.periodic: steam, a burn) takes its
## health at every tick, but the hurt cry - the flash event, the shake of the
## view, the hurt sound - comes at most once per Player.PERIODIC_CUE_GAP; a
## plain hit always cries out. (Plan 2026-10-21-mechaniki-biomow, "Poprawki
## po przeglądzie" 5: the steam ticked four times a second.)

var player: Player


func before_each() -> void:
	GameInput.capture_allowed = false
	Greybox.box(self, Vector3(0, -0.5, 0), Vector3(20, 1, 20), Color.GRAY)
	player = Player.new()
	player.position = Vector3(0, 0.05, 0)
	add_child(player)
	await physics_frames(2)


func after_each() -> void:
	GameInput.capture_allowed = true


## Physics frames in [param seconds] (whatever the tick rate).
func _frames(seconds: float) -> int:
	return ceili(seconds * Engine.physics_ticks_per_second)


func _tick(amount: float = 2.5) -> void:
	var info := DamageInfo.make(amount, DamageInfo.Kind.FIRE, null)
	info.periodic = true
	player.take_damage(info)


func test_ticks_hurt_each_time_but_cry_out_once_per_gap() -> void:
	var cries := watch(Events.player_damaged)
	var full := player.health.current
	for i in 8:
		_tick()
		await physics_frames(_frames(0.25))
	assert_almost_eq(player.health.current, full - 8 * 2.5, 0.001, "every tick took its health")
	assert_gt(cries.size(), 1, "it cries out again after the gap")
	assert_lt(cries.size(), 4, "two seconds of ticks: two or three cries, not eight")


func test_the_first_tick_cries_out_at_once_and_a_plain_hit_always_does() -> void:
	var cries := watch(Events.player_damaged)
	_tick()
	assert_eq(cries.size(), 1, "the first tick is felt")
	_tick()
	assert_eq(cries.size(), 1, "the next one right after is not announced again")
	player.take_damage(DamageInfo.make(5.0, DamageInfo.Kind.BLUNT, null))
	assert_eq(cries.size(), 2, "a blow always is")
	await physics_frames(_frames(Player.PERIODIC_CUE_GAP) + 3)
	_tick()
	assert_eq(cries.size(), 3, "a second on, the steam is felt again")


func test_the_shake_follows_the_cry_not_the_tick() -> void:
	_tick(6.0)
	var after_first := player.camera.trauma.value
	assert_gt(after_first, 0.2, "the view shakes at the first tick")
	_tick(6.0)
	assert_almost_eq(player.camera.trauma.value, after_first, 0.02, "and does not pile up with the next ones")


func test_what_the_cries_hold_adds_up_to_the_damage_taken() -> void:
	var told := [0.0]
	Events.player_damaged.connect(func(amount: float, _from: Vector3) -> void: told[0] += amount)
	var full := player.health.current
	for i in 8:
		_tick()
		await physics_frames(_frames(0.25))
	player.take_damage(DamageInfo.make(5.0, DamageInfo.Kind.BLUNT, null))
	assert_almost_eq(full - player.health.current, 25.0, 0.001, "eight ticks and a blow")
	assert_almost_eq(float(told[0]), 25.0, 0.001, "the listeners (the playthrough bot sums them) were told every point of it")


func test_a_lethal_tick_cries_out_at_once_with_the_swallowed_damage() -> void:
	player.health.current = 6.0
	var cries := watch(Events.player_damaged)
	_tick()
	_tick()
	assert_eq(cries.size(), 1, "the second tick is swallowed")
	_tick()
	assert_eq(cries.size(), 2, "the tick that kills is never kept quiet")
	assert_almost_eq(float(cries[1][0]), 5.0, 0.001, "it brings the swallowed tick with it")
	assert_false(player.alive)
