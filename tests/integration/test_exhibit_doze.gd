extends TestCase
## Dozing (plan 2026-10-21-wydajnosc-cpu): a sleeping exhibit at rest
## leaves the per-frame physics step and ExhibitClock ticks it only when its
## next moment (a look, a routine tick, the end of a sound sleep) is due -
## and nothing it does changes. The same night is played twice, dozing and
## ticked every frame, and must read the same frame by frame: woken by
## sight, by a noise, by a hit, creeping up while unwatched.

var target: TargetDummy


func before_each() -> void:
	Greybox.box(self, Vector3(0, -0.5, 0), Vector3(160, 1, 160), Color.GRAY)
	target = TargetDummy.new()
	target.position = Vector3(0, 0, 60)   # far away, out of sight
	add_child(target)


func after_each() -> void:
	Enemy.doze_enabled = true


func _seconds(time: float) -> void:
	await physics_frames(roundi(time * Engine.physics_ticks_per_second))


func _exhibit(kind: GDScript, at: Vector3, toward: Vector3, seed_value: int = 7) -> Enemy:
	var enemy: Enemy = kind.new()
	enemy.position = at
	enemy.target = target
	enemy.brain.rng.seed = seed_value
	add_child(enemy)
	enemy.face(toward)
	return enemy


## Plays [param event] (called with the exhibit on frame [param at]) on a
## sleeping wax figure at the origin facing -Z, dozing or not, and returns
## what it did every frame: its state, where it stands, which way it looks.
## The global die is seeded the same way for both runs.
func _night(dozing: bool, at: int, frames: int, event: Callable) -> Dictionary:
	await get_tree().process_frame   # (both runs start between two physics frames)
	Enemy.doze_enabled = dozing
	PerceptionWorld.reset()
	target.position = Vector3(0, 0, 60)
	target.rotation = Vector3.ZERO
	seed(4242)
	var figure := _exhibit(WaxFigure, Vector3.ZERO, Vector3(0, 0, -10))
	var states: Array[int] = []
	var places: Array[Vector3] = []
	var dozed_before := false
	for frame in frames:
		if frame == at:
			dozed_before = figure.dozing()
			event.call(figure)
		await get_tree().physics_frame
		states.append(figure.brain.state)
		places.append(Vector3(figure.global_position.x, figure.global_position.z, figure.rotation.y))
	var out := {"states": states, "places": places, "dozed_before": dozed_before, "doze_ticks": figure.doze_ticks, "stirs": figure.stirs, "routine_ticks": figure.routine_ticks}
	figure.queue_free()
	await get_tree().physics_frame
	return out


## The two runs of a night agree frame by frame.
func _same_night(at: int, frames: int, event: Callable, what: String) -> void:
	var ticked := await _night(false, at, frames, event)
	var dozed := await _night(true, at, frames, event)
	assert_true(dozed["dozed_before"], "%s: it was dozing when it happened" % what)
	assert_false(ticked["dozed_before"], "%s: the comparison run never dozes" % what)
	assert_eq(dozed["routine_ticks"], ticked["routine_ticks"], "%s: the same routine ticks" % what)
	assert_eq(dozed["stirs"], ticked["stirs"], "%s: the same stirs" % what)
	var states_a: Array = ticked["states"]
	var states_b: Array = dozed["states"]
	var places_a: Array = ticked["places"]
	var places_b: Array = dozed["places"]
	for frame in frames:
		if states_a[frame] != states_b[frame]:
			fail("%s: frame %d: %s ticked, %s dozing" % [what, frame, EnemyBrain.State.keys()[states_a[frame]], EnemyBrain.State.keys()[states_b[frame]]])
			return
		if not (places_a[frame] as Vector3).is_equal_approx(places_b[frame]):
			fail("%s: frame %d: at %s ticked, %s dozing" % [what, frame, places_a[frame], places_b[frame]])
			return


func test_a_sleeper_at_rest_leaves_the_physics_step() -> void:
	var figure := _exhibit(WaxFigure, Vector3.ZERO, Vector3(0, 0, -10))
	await _seconds(2.0)
	assert_true(figure.dozing(), "asleep at rest it dozes")
	assert_false(figure.is_physics_processing(), "no physics step of its own")
	assert_not_null(figure.rig)
	if figure.rig != null:
		assert_false(figure.rig.is_physics_processing(), "nor of its model")
	var ticks := figure.doze_ticks
	await _seconds(3.0)
	var per_second := (figure.doze_ticks - ticks) / 3.0
	assert_gt(per_second, 1.0, "it still looks and keeps its routine (%.1f ticks/s)" % per_second)
	assert_lt(per_second, 8.0, "but only when one of them is due, not 60 times a second (%.1f)" % per_second)
	assert_eq(figure.brain.state, EnemyBrain.State.DORMANT)


func test_seen_while_dozing_the_same_as_ticked() -> void:
	await _same_night(150, 300, func(_figure: Enemy) -> void:
		target.position = Vector3(0, 0, -4)   # right in front of it
		target.rotation.y = 0.0, "seen")


func test_a_noise_while_dozing_the_same_as_ticked() -> void:
	await _same_night(150, 400, func(_figure: Enemy) -> void:
		PerceptionWorld.noise(Vector3(4, 0, -6), 18.0, &"pistol"), "a noise")


func test_a_hit_while_dozing_the_same_as_ticked() -> void:
	await _same_night(150, 300, func(figure: Enemy) -> void:
		var info := DamageInfo.make(5.0, DamageInfo.Kind.BALLISTIC, target)
		info.direction = Vector3(0, 0, 1)
		info.position = figure.global_position + Vector3.UP
		figure.take_damage(info), "a hit")


func test_creeping_up_while_dozing_the_same_as_ticked() -> void:
	# the guard 16 m behind it (beyond a sleeper's sight), looking away: it
	# stirs his way unwatched
	await _same_night(120, 420, func(_figure: Enemy) -> void:
		target.position = Vector3(0, 0, 16)
		target.rotation.y = PI, "a stir")


func test_a_sound_sleep_ends_on_time_while_dozing() -> void:
	var figure := _exhibit(WaxFigure, Vector3.ZERO, Vector3(0, 0, -10))
	figure.sound_asleep = 3.0
	await _seconds(2.4)
	assert_true(figure.dozing())
	assert_gt(figure.sound_asleep, 0.0, "still soundly asleep")
	PerceptionWorld.noise(Vector3(2, 0, -2), 18.0, &"sprint")
	assert_eq(figure.brain.state, EnemyBrain.State.DORMANT, "a step does not wake a sound sleeper")
	await _seconds(0.8)
	assert_lt(figure.sound_asleep, 0.0001, "its sound sleep ran out while it dozed")
	PerceptionWorld.noise(Vector3(2, 0, -2), 18.0, &"sprint")
	assert_ne(figure.brain.state, EnemyBrain.State.DORMANT, "now a step reaches it")


func test_a_neighbour_rouses_a_dozing_sleeper() -> void:
	var first := _exhibit(WaxFigure, Vector3.ZERO, Vector3(0, 0, -10), 1)
	var second := _exhibit(WaxFigure, Vector3(3, 0, 0), Vector3(3, 0, -10), 2)
	await _seconds(2.0)
	assert_true(second.dozing())
	target.position = Vector3(0, 0, -16)   # in their room, beyond a sleeper's sight
	first.brain.wake()   # (a scripted wake: the call-out rouses its neighbours)
	await _seconds(1.0)
	assert_ne(second.brain.state, EnemyBrain.State.DORMANT, "the neighbour came to look")
	assert_false(second.dozing())
	assert_true(second.is_physics_processing(), "awake it is ticked every frame again")


func test_the_trail_goes_on_while_every_exhibit_dozes() -> void:
	var figure := _exhibit(WaxFigure, Vector3.ZERO, Vector3(0, 0, -10))
	await _seconds(2.0)
	assert_true(figure.dozing())
	PerceptionWorld.clear_trail()
	for i in 60:
		target.position = Vector3(30, 0, 40) + Vector3(0, 0, -0.1 * i)
		await get_tree().physics_frame
	assert_gt(PerceptionWorld.trail().size(), 2, "the guard's crumbs are laid while all sleep")


func test_dawn_freezes_a_dozer_for_good() -> void:
	var figure := _exhibit(WaxFigure, Vector3.ZERO, Vector3(0, 0, -10))
	await _seconds(2.0)
	assert_true(figure.dozing())
	figure.freeze()
	var ticks := figure.doze_ticks
	await _seconds(1.5)
	assert_false(figure.dozing())
	assert_eq(figure.doze_ticks, ticks, "stone is never ticked")
	assert_false(figure.is_physics_processing())


## A flock of books asleep on its shelf; its first book is woken by a
## script: the frame each book of the flock leaves its shelf.
func _flock_wakes(dozing: bool) -> Array[int]:
	await get_tree().process_frame
	Enemy.doze_enabled = dozing
	PerceptionWorld.reset()
	var books := BookFlock.make_members(Vector3(0, 0, -2), 0.0, 4)
	for book in books:
		book.target = target
		add_child(book)
	await _seconds(2.5)
	for book in books:
		assert_eq(book.dozing(), dozing, "%s dozes on its shelf: %s" % [book.name, dozing])
	books[0].brain.wake()
	var woke: Array[int] = [-1, -1, -1, -1]
	for frame in 60:
		await get_tree().physics_frame
		for i in books.size():
			if woke[i] < 0 and books[i].brain.state != EnemyBrain.State.DORMANT:
				woke[i] = frame
	for book in books:
		book.queue_free()
	await get_tree().physics_frame
	return woke


func test_a_dozing_flock_wakes_one_book_after_another_as_ever() -> void:
	var ticked := await _flock_wakes(false)
	var dozed := await _flock_wakes(true)
	assert_true(ticked.min() >= 0, "the whole flock woke: %s" % [ticked])
	assert_eq(dozed, ticked, "on the same frames, staggered")


func test_forty_sleepers_cost_a_few_ticks_a_second() -> void:
	var sleepers: Array[Enemy] = []
	var kinds: Array[GDScript] = [WaxFigure, Knight, Wolf, Bust, Hoplite, Jaguar, Raptor, SamuraiArmor]
	for i in 40:
		var at := Vector3(-30 + (i % 10) * 6.0, 0, -30 + (i / 10) * 6.0)
		sleepers.append(_exhibit(kinds[i % kinds.size()], at, at + Vector3(0, 0, -5), i))
	await _seconds(3.0)
	var dozing := sleepers.filter(func(e: Enemy) -> bool: return e.dozing()).size()
	assert_eq(dozing, sleepers.size(), "every one of them dozes (%d of %d)" % [dozing, sleepers.size()])
	var before := ExhibitClock.due_ticks
	await _seconds(2.0)
	var per_frame := (ExhibitClock.due_ticks - before) / 120.0
	assert_lt(per_frame, 3.0, "%.2f dozing ticks a frame for %d sleepers (ticked: %d)" % [per_frame, sleepers.size(), sleepers.size()])
