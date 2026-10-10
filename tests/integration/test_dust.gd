extends TestCase
## Dust motes: dropped by destroyed exhibits, magnet to the guard, expiry,
## and the HUD counter.

var player: Player
var dropper: DustDropper


func before_each() -> void:
	Greybox.box(self, Vector3(0, -0.5, 0), Vector3(40, 1, 40), Color.GRAY)
	player = Player.new()
	player.position = Vector3(0, 0.05, 0)
	add_child(player)
	dropper = DustDropper.new()
	dropper.target = player
	add_child(dropper)


func _motes() -> Array[DustMote]:
	var found: Array[DustMote] = []
	for child in get_children():
		var mote := child as DustMote
		if mote != null and not mote.is_queued_for_deletion():
			found.append(mote)
	return found


func _sum(motes: Array[DustMote]) -> int:
	var total := 0
	for mote in motes:
		total += mote.value
	return total


func _seconds(time: float) -> void:
	await physics_frames(roundi(time * Engine.physics_ticks_per_second))


func test_destroyed_exhibit_drops_its_dust_as_motes() -> void:
	var wax := WaxFigure.new()
	wax.position = Vector3(0, 0.05, -12)
	add_child(wax)
	await physics_frames(2)
	wax.take_damage(DamageInfo.make(500.0, DamageInfo.Kind.BALLISTIC, player))
	var motes := _motes()
	assert_eq(motes.size(), 1)
	assert_eq(_sum(motes), 3)


func test_finisher_kill_drops_more_dust() -> void:
	var knight := Knight.new()
	knight.position = Vector3(0, 0.05, -12)
	add_child(knight)
	Events.enemy_destroyed.emit(knight, DamageInfo.make(15.0, DamageInfo.Kind.BLUNT, player), true)
	assert_eq(_sum(_motes()), 12)
	assert_eq(_motes().size(), 4)


func test_motes_wait_before_flying() -> void:
	dropper.drop(Vector3(0, 1.2, -2.0), 3)
	await _seconds(0.3)
	assert_eq(RunState.dust, 0)
	assert_eq(_motes().size(), 1)


func test_motes_fly_to_a_guard_within_six_metres() -> void:
	var collected := watch(Events.dust_collected)
	dropper.drop(Vector3(0, 1.2, -4.0), 8)
	await _seconds(1.6)
	assert_eq(RunState.dust, 8)
	assert_eq(_motes().size(), 0)
	var sum := 0
	for call in collected:
		sum += call[0]
	assert_eq(sum, 8)


func test_motes_ignore_a_distant_guard() -> void:
	dropper.drop(Vector3(0, 1.2, -10.0), 3)
	await _seconds(1.6)
	assert_eq(RunState.dust, 0)
	assert_eq(_motes().size(), 1)


func test_dead_guard_collects_nothing() -> void:
	player.take_damage(DamageInfo.make(500.0, DamageInfo.Kind.BLUNT))
	dropper.drop(Vector3(0, 1.2, -2.0), 3)
	await _seconds(1.2)
	assert_eq(RunState.dust, 0)


func test_motes_expire() -> void:
	for mote in dropper.drop(Vector3(0, 1.2, -10.0), 6):
		mote.lifetime = 0.4
	await _seconds(0.6)
	assert_eq(_motes().size(), 0)


func test_night_multiplier_is_already_in_the_motes() -> void:
	RunState.set_multiplier(&"full_moon", 1.5)
	var wax := WaxFigure.new()
	wax.position = Vector3(0, 0.05, -12)
	add_child(wax)
	Events.enemy_destroyed.emit(wax, DamageInfo.make(15.0, DamageInfo.Kind.BLUNT, player), false)
	assert_eq(_sum(_motes()), 5)


## Stands in for the T-Rex: not an exhibit, only a dust_value.
class FakeBoss extends Node3D:
	var dust_value: int = 100


func test_boss_defeat_showers_its_dust() -> void:
	var boss := FakeBoss.new()
	boss.position = Vector3(0, 0, -3)
	add_child(boss)
	Events.boss_defeated.emit(boss)
	var motes := _motes()
	assert_eq(motes.size(), DustRules.BOSS_MOTES)
	assert_eq(_sum(motes), 100)
	await _seconds(2.0)
	assert_eq(RunState.dust, 100, "the guard nearby gets it all")


func test_bust_drops_five() -> void:
	var bust := Bust.new()
	bust.position = Vector3(0, 0.05, -12)
	add_child(bust)
	Events.enemy_destroyed.emit(bust, DamageInfo.make(45.0, DamageInfo.Kind.BALLISTIC, player), false)
	assert_eq(_sum(_motes()), 5)


func test_hud_shows_the_total_and_a_gain_pop() -> void:
	var hud := Hud.new()
	hud.player = player
	hud.show_dust = true
	add_child(hud)
	RunState.add_dust(12)
	await get_tree().process_frame
	assert_eq(hud._dust_label.text, "12")
	assert_eq(hud._dust_gain.text, "+12")
	assert_gt(hud._dust_gain.modulate.a, 0.5)
	RunState.add_dust(3)
	await get_tree().process_frame
	assert_eq(hud._dust_gain.text, "+15", "close gains add up")
	await get_tree().create_timer(Hud.GAIN_TIME + 0.2).timeout
	assert_eq(hud._dust_gain.modulate.a, 0.0)
