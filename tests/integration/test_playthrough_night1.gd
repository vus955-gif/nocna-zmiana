extends TestCase
## The playthrough bot's small run for the suite (plan
## docs/superpowers/plans/2026-10-21-przejscie-bota.md, task 7): night 1
## from a fresh save, Floor I as greybox, the bot playing only through the
## input actions - the till key, the pistol from the booth's locker, the
## flare gun from the fire cabinet, the shotgun in Egypt, then into the
## Colossus's hall until it wakes (or falls). No death, no task given up,
## within the time. The full run is tools/run_playthrough.sh.

## Game seconds the run may take (the walk is ~1 min, the fights more).
const LIMIT := 300.0
## A step of physics is this many 1/60 s of game time (the playthrough's
## fast mode; the runner puts the scale back after each test).
const TIME_SCALE := 4.0
const SEED := 20261021

var museum: Museum
var bot: PlaythroughBot
var events: Array = []


func before_each() -> void:
	Museum.level_id = &"floor1"
	GameState.new_game()
	GameState.seed_base = SEED
	GameState.save_game()
	seed(SEED)


func after_each() -> void:
	Engine.time_scale = 1.0
	if is_instance_valid(museum):
		museum.free()


func test_night_one_to_the_colossus_by_the_keys_alone() -> void:
	museum = (load(SceneFlow.MUSEUM) as PackedScene).instantiate() as Museum
	add_child(museum)
	bot = PlaythroughBot.new()
	bot.setup(museum, SEED)
	museum.add_child(bot)
	bot.event.connect(func(kind: StringName, data: Dictionary) -> void: events.append([kind, data]))
	var died := [false]
	Events.player_died.connect(func() -> void: died[0] = true)
	Engine.time_scale = TIME_SCALE
	var colossus: Guardian = museum.floor_game.guardians.guardians.get(&"colossus")
	var woke := [false]
	if colossus != null:
		colossus.awakened.connect(func() -> void: woke[0] = true)
	var order: Array[StringName] = []
	var game_time := 0.0
	while game_time < LIMIT and not died[0] and not woke[0] and not GameState.is_guardian_defeated(&"colossus"):
		await physics_frames(1)
		game_time += 1.0 / 60.0 * TIME_SCALE
		for step: StringName in [&"pistol", &"flare", &"shotgun"]:
			if GameState.has_weapon(step) and not order.has(step):
				order.append(step)
		if GameState.pistol_key and not order.has(&"pistol_key"):
			order.append(&"pistol_key")
	Engine.time_scale = 1.0
	var failed := events.filter(func(e: Array) -> bool: return e[0] == &"task_failed")
	print("  night 1 to the Colossus: %.0f s of game time, %d kills, %d shots, %d stuck, %d tasks given up, health %d" % [
		game_time, int(bot.stats["kills"]), int(bot.stats["shots"]), int(bot.stats["stuck"]), failed.size(), int(museum.player.health.current)])
	assert_false(died[0], "the guard died on the way (%s)" % [bot.last_damage()])
	assert_eq(order.slice(0, 4), [&"pistol_key", &"pistol", &"flare", &"shotgun"] as Array[StringName], "the goals in the HUD's order")
	assert_true(woke[0] or GameState.is_guardian_defeated(&"colossus"), "the Colossus woke within %d s of game time" % int(LIMIT))
	assert_eq(failed.size(), 0, "no task given up: %s" % [failed])
	assert_lt(game_time, LIMIT)
