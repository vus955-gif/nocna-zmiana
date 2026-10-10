extends TestCase
## Finding the new weapons: the chained gatling display (shotgun blast or
## three punches) and the fire cabinet with the flare gun (smashing it is
## loud).

var user: Node3D
var holder: WeaponHolder


func before_each() -> void:
	Greybox.box(self, Vector3(0, -0.5, 0), Vector3(80, 1, 80), Color.GRAY)
	user = Node3D.new()
	add_child(user)
	holder = WeaponHolder.new()
	holder.user = user
	holder.position = Vector3(0, 1.5, 0)
	user.add_child(holder)


func _display(z: float) -> ChainedDisplay:
	# the plaque (-Z) faces the guard at the origin
	var display := ChainedDisplay.create(Transform3D(Basis(Vector3.UP, PI), Vector3(0, 0, z)))
	add_child(display)
	return display


func _weapon(id: StringName) -> WeaponData:
	return load("res://src/weapons/data/%s.tres" % id)


func _guard() -> Player:
	var guard := Player.new()
	guard.position = Vector3(0, 0.05, 3)
	add_child(guard)
	return guard


func test_a_shotgun_blast_breaks_the_chain() -> void:
	var display := _display(-2.5)
	var broken := watch(display.chain_broken)
	holder.give(_weapon(&"shotgun"))
	await physics_frames(2)
	holder.try_fire()
	assert_eq(broken.size(), 1)
	assert_eq(display.state, ChainedDisplay.State.OPEN)
	assert_eq(display.prompt(), tr("PROMPT_TAKE_GATLING"))


func test_pistol_shots_only_strike_sparks() -> void:
	var display := _display(-2.5)
	holder.give(_weapon(&"pistol"))
	await physics_frames(2)
	for i in 3:
		holder.try_fire()
		await physics_frames(20)
	assert_eq(display.state, ChainedDisplay.State.LOCKED)


func test_three_punches_break_the_chain_two_do_not() -> void:
	var display := _display(-1.7)
	await physics_frames(2)
	for i in 2:
		assert_true(holder.try_punch())
		await physics_frames(30)
	assert_eq(display.punches, 2)
	assert_eq(display.state, ChainedDisplay.State.LOCKED, "two are not enough")
	holder.try_punch()
	assert_eq(display.state, ChainedDisplay.State.OPEN, "the third one does it")


func test_the_chained_gatling_cannot_be_taken_then_is_taken_for_good() -> void:
	var display := _display(-2.0)
	var guard := _guard()
	await physics_frames(2)
	display.interact(guard)
	assert_false(guard.weapons.has_weapon(&"gatling"), "chained")
	display.break_chain()
	var taken := watch(display.taken)
	display.interact(guard)
	assert_eq(taken.size(), 1)
	assert_true(guard.weapons.has_weapon(&"gatling"))
	assert_eq(guard.weapons.current_state().data.id, &"gatling", "in hand at once")
	assert_true(GameState.has_weapon(&"gatling"), "found for good")
	assert_eq(display.state, ChainedDisplay.State.EMPTY)
	assert_false(display.can_interact(guard))


func test_a_found_gatling_leaves_the_display_empty() -> void:
	GameState.add_weapon(&"gatling")
	var display := _display(-2.0)
	await physics_frames(1)
	assert_eq(display.state, ChainedDisplay.State.EMPTY)
	assert_false(display.can_interact(null))


func test_a_broken_chain_stays_broken_for_the_night() -> void:
	var first := _display(-2.0)
	await physics_frames(1)
	first.break_chain()
	first.queue_free()
	var again := _display(-6.0)
	await physics_frames(1)
	assert_eq(again.state, ChainedDisplay.State.OPEN, "a resumed night keeps it open")


func _cabinet() -> EmergencyCabinet:
	Greybox.box(self, Vector3(0, 2, -4.25), Vector3(8, 4, 0.5), Color.GRAY)
	# on the wall's face, its glass (-Z) toward the guard at the origin
	var cabinet := EmergencyCabinet.create(Transform3D(Basis(Vector3.UP, PI), Vector3(0, 1.4, -4.0)))
	add_child(cabinet)
	return cabinet


func test_smashing_the_cabinet_is_loud_and_wakes_exhibits_nearby() -> void:
	var cabinet := _cabinet()
	# only the noise counts here: neither may simply see the guard (their
	# first sight checks fall at random within 0.2 s), so both are
	# short-sighted
	var near := WaxFigure.new()
	near.position = Vector3(10, 0, 4)   # behind the guard's back, no sight needed
	near.sight_range = 4.0
	add_child(near)
	var far := WaxFigure.new()
	far.position = Vector3(0, 0, 18)
	far.sight_range = 4.0
	add_child(far)
	var guard := _guard()
	await physics_frames(20)
	assert_eq(near.brain.state, EnemyBrain.State.DORMANT, "asleep until the crash")
	assert_eq(cabinet.prompt(), tr("PROMPT_SMASH_GLASS"))
	cabinet.interact(guard)
	assert_eq(cabinet.state, EmergencyCabinet.State.OPEN)
	assert_ne(near.brain.state, EnemyBrain.State.DORMANT, "woken by the crash")
	assert_eq(far.brain.state, EnemyBrain.State.DORMANT, "too far to hear it")
	assert_false(guard.weapons.has_weapon(&"flare"), "smashing does not take it")
	cabinet.interact(guard)
	assert_true(guard.weapons.has_weapon(&"flare"))
	assert_true(GameState.has_weapon(&"flare"))
	assert_eq(cabinet.state, EmergencyCabinet.State.EMPTY)


func test_a_shot_breaks_the_glass_too() -> void:
	var cabinet := _cabinet()
	holder.position = Vector3(0, 1.4, 0)
	holder.give(_weapon(&"pistol"))
	await physics_frames(2)
	holder.try_fire()
	assert_eq(cabinet.state, EmergencyCabinet.State.OPEN)


func test_a_found_flare_gun_leaves_the_cabinet_empty() -> void:
	GameState.add_weapon(&"flare")
	var cabinet := _cabinet()
	await physics_frames(1)
	assert_eq(cabinet.state, EmergencyCabinet.State.EMPTY)
