extends TestCase
## The night's artifacts in their containers, what each one does, the
## padlocked case (secret 4) and the janitor's key on tonight's locked door.

const HALL_CASE := Vector3(-16.5, 1.0, -8.0)

var bed: WorldTestbed


## Builds the lobby for [param config] (night 1 of seed 1 when null).
func _setup(config: NightConfig = null) -> void:
	bed = WorldTestbed.new()
	add_child(bed)
	bed.setup(config)
	await physics_frames(2)


## Night 1 of seed 1 with [param id] placed in the hall case under the west
## balcony (everything else as drawn).
func _night_with(id: StringName) -> NightConfig:
	var description := LobbyLayout.describe(LobbyLayout.create())
	var config := NightDirector.plan(1, 1, description)
	var spot := _spot_at(description, HALL_CASE)
	config.loot[spot] = id
	if not config.artifacts.has(id):
		config.artifacts.append(id)
	return config


static func _spot_at(description: LevelDescription, point: Vector3) -> int:
	for i in description.loot_spots.size():
		if description.loot_spots[i].position.distance_to(point) < 0.1:
			return i
	return -1


func _use(at: Vector3, target: Vector3) -> String:
	bed.place_guard(at, target)
	await physics_frames(3)
	var focus := bed.player.interactor.focus
	var prompt := focus.prompt() if focus != null else ""
	Input.action_press(&"interact")
	await physics_frames(1)
	Input.action_release(&"interact")
	await physics_frames(1)
	return prompt


## Takes a free (not padlocked) [param id] of tonight.
func _take(id: StringName) -> void:
	for spot: int in bed.features.artifacts:
		var pickup: ArtifactPickup = bed.features.artifacts[spot]
		if pickup.artifact_id == id and not pickup.locked:
			pickup.interact(bed.player)
			return
	fail("no free %s tonight" % id)


func test_the_containers_hold_the_nights_artifacts() -> void:
	var config := NightDirector.plan(2026, 3, LobbyLayout.describe(LobbyLayout.create()))
	await _setup(config)
	var placed := 0
	for spot: int in config.loot:
		if not ArtifactCatalog.is_artifact(config.loot[spot]):
			continue
		placed += 1
		var pickup: ArtifactPickup = bed.features.artifacts.get(spot)
		assert_not_null(pickup, "spot %d" % spot)
		if pickup != null:
			assert_eq(pickup.artifact_id, config.loot[spot])
			assert_lt(pickup.global_position.distance_to(bed.level.loot_spots[spot].position), 0.01)
	assert_eq(placed, config.artifacts.size())
	assert_gt(placed, 1, "two or three a night")


func test_an_artifact_is_taken_from_its_case() -> void:
	await _setup(_night_with(ArtifactCatalog.FOUNTAIN_COIN))
	var taken := watch(bed.features.artifact_taken)
	var prompt := await _use(Vector3(-14.6, 0.05, -8.0), HALL_CASE)
	assert_eq(prompt, "Weź: Moneta z fontanny", "the probe reaches in past the glass")
	assert_true(RunState.has_artifact(ArtifactCatalog.FOUNTAIN_COIN))
	assert_eq(taken.size(), 1)
	var banner := bed.features.hud.current()
	assert_eq(banner[0], "Artefakt nocy")
	assert_eq(banner[1], "Moneta z fontanny")
	assert_true(banner[2].begins_with("Pyłu jest o połowę więcej."))
	await physics_frames(20)
	assert_eq(bed.features.hud.shown_artifacts(), [ArtifactCatalog.FOUNTAIN_COIN] as Array[StringName])


func test_the_fountain_coin_multiplies_dust() -> void:
	await _setup(_night_with(ArtifactCatalog.FOUNTAIN_COIN))
	_take(ArtifactCatalog.FOUNTAIN_COIN)
	assert_almost_eq(RunState.dust_multiplier(), 1.5)
	assert_eq(RunState.add_dust(10), 15)


func test_the_wolf_tooth_speeds_up_the_sprint() -> void:
	await _setup(_night_with(ArtifactCatalog.WOLF_TOOTH))
	var base := bed.player.sprint_speed
	_take(ArtifactCatalog.WOLF_TOOTH)
	assert_almost_eq(bed.player.sprint_speed, base * 1.2)
	RunState.reset()
	await physics_frames(40)
	assert_almost_eq(bed.player.sprint_speed, base, 0.001, "gone at dawn or death")


func test_the_scarab_doubles_finisher_healing() -> void:
	await _setup(_night_with(ArtifactCatalog.SCARAB))
	_take(ArtifactCatalog.SCARAB)
	bed.player.health.current = 40.0
	var info := DamageInfo.make(30.0, DamageInfo.Kind.BLUNT, bed.player)
	var exhibit := TargetDummy.new()
	add_child(exhibit)
	Events.enemy_destroyed.emit(exhibit, info, true)
	assert_almost_eq(bed.player.health.current, 40.0 + bed.player.finisher_heal * 2.0)
	Events.enemy_destroyed.emit(exhibit, info, false)
	assert_almost_eq(bed.player.health.current, 40.0 + bed.player.finisher_heal * 2.0, 0.001, "plain kills do not heal")


func test_the_candle_stub_stretches_stuns() -> void:
	await _setup(_night_with(ArtifactCatalog.CANDLE_STUB))
	var wax := WaxFigure.new()
	wax.position = Vector3(0, 0.05, 50)
	bed.add_child(wax)
	await physics_frames(2)
	var info := DamageInfo.make(1.0, DamageInfo.Kind.ELECTRIC, bed.player)
	info.stun_time = 2.0
	wax.take_damage(info)
	assert_almost_eq(wax.brain._timer, 2.0, 0.01, "without the candle")
	_take(ArtifactCatalog.CANDLE_STUB)
	wax.brain.stun(0.01)
	wax.brain._timer = 0.0
	wax.take_damage(info)
	assert_true(wax.brain.is_stunned())
	assert_almost_eq(wax.brain._timer, 3.0, 0.01, "half as long again")


func test_the_monocle_lights_weak_points() -> void:
	await _setup(_night_with(ArtifactCatalog.MONOCLE))
	var wax := WaxFigure.new()
	wax.position = Vector3(0, 0.05, 50)
	bed.add_child(wax)
	await physics_frames(2)
	assert_eq(get_tree().get_nodes_in_group(&"weak_point_glow").size(), 0)
	_take(ArtifactCatalog.MONOCLE)
	await physics_frames(2)
	var glows := get_tree().get_nodes_in_group(&"weak_point_glow")
	assert_eq(glows.size(), 1, "the wax figure's head")
	if glows.size() == 1:
		var zone := (glows[0] as Node).get_parent() as Hurtbox
		assert_true(zone.weak_point)
		assert_eq(zone.receiver, wax)
	# an exhibit arriving later gets its glow within a scan
	var knight := Knight.new()
	knight.position = Vector3(2, 0.05, 50)
	bed.add_child(knight)
	await physics_frames(40)
	assert_eq(get_tree().get_nodes_in_group(&"weak_point_glow").size(), 2)
	RunState.reset()
	await physics_frames(40)
	assert_eq(get_tree().get_nodes_in_group(&"weak_point_glow").size(), 0, "the glow goes with the monocle")


func test_the_monocle_shows_the_crystal_between_the_t_rexs_ribs() -> void:
	await _setup(_night_with(ArtifactCatalog.MONOCLE))
	var boss := TRex.new()
	boss.position = Vector3(0.0, 1.25, -11.0)
	bed.add_child(boss)
	await physics_frames(2)
	_take(ArtifactCatalog.MONOCLE)
	await physics_frames(30)
	var socket := boss.skeleton.crystal_hurtbox
	var glows := socket.get_children().filter(func(child: Node) -> bool: return child is WeakPointGlow)
	assert_eq(glows.size(), 0, "no crystal yet: nothing to show")
	boss.skeleton.set_crystal_present(true)
	await physics_frames(30)
	glows = socket.get_children().filter(func(child: Node) -> bool: return child is WeakPointGlow)
	assert_eq(glows.size(), 1, "the crystal glows")
	if glows.size() == 1:
		assert_true((glows[0] as WeakPointGlow).visible)
		boss.skeleton.set_crystal_present(false)
		await physics_frames(30)
		assert_false((glows[0] as WeakPointGlow).visible, "knocked out: no glow")


func test_the_locked_door_needs_the_janitors_key() -> void:
	var config := WorldTestbed.find_night(3, func(c: NightConfig) -> bool: return c.locked_door == &"door_hall_gallery")
	assert_not_null(config)
	if config == null:
		return
	await _setup(config)
	var door: Door = bed.level.doors[&"door_hall_gallery"]
	assert_true(door.locked)
	assert_eq(bed.features.latches.size(), 2, "one on each face")
	var refused := watch(door.open_refused)
	var prompt := await _use(Vector3(-16.0, 0.05, 0.0), Vector3(-18.0, 1.5, 0.0))
	assert_eq(prompt, "Szarpnij klamkę")
	assert_true(door.locked)
	assert_eq(refused.size(), 1)
	assert_eq(bed.features.hud.announced.back()[0] if not bed.features.hud.announced.is_empty() else "", "Zamknięte na klucz")
	RunState.artifacts.append(ArtifactCatalog.JANITOR_KEY)
	prompt = await _use(Vector3(-16.0, 0.05, 0.0), Vector3(-18.0, 1.5, 0.0))
	assert_eq(prompt, "Otwórz kluczem woźnego")
	assert_false(door.locked)
	assert_true(door.is_open)
	await physics_frames(2)
	assert_eq(bed.features.latches.size(), 0)


func test_a_shot_breaks_the_padlock() -> void:
	await _setup()
	var padlock := bed.features.padlock
	assert_not_null(padlock)
	var inside := bed.features._artifact_near(Vector3(16.5, 1.0, -14.0))
	assert_not_null(inside, "the locked case always holds an artifact")
	assert_eq(inside.collision_layer, 0, "locked in")
	# the padlock faces the hall: a shot from the west meets it first
	var aim := padlock.hurtbox.global_position
	var hit := Hitscan.ray(bed.get_world_3d().direct_space_state, aim + Vector3(-4, 0.2, 0), aim + Vector3(1, -0.05, 0))
	assert_eq(hit.get("hurtbox"), padlock.hurtbox)
	var info := DamageInfo.make(18.0, DamageInfo.Kind.BALLISTIC, bed.player)
	info.direction = Vector3.RIGHT
	info.normal = Vector3.LEFT
	padlock.hurtbox.receiver.take_damage(info)
	assert_false(padlock.is_locked)
	assert_true(GameState.secrets.has(LobbySecrets.CASE))
	assert_eq(inside.collision_layer, Layers.INTERACT, "now it can be taken")
	assert_eq(padlock.hurtbox.collision_layer, 0)


func test_the_padlock_rattles_without_the_key_and_opens_with_it() -> void:
	await _setup()
	var padlock := bed.features.padlock
	var at := padlock.global_position + (padlock.global_transform.basis * Vector3.FORWARD) * 1.4
	at.y = 0.05
	var prompt := await _use(at, padlock.global_position)
	assert_eq(prompt, "Szarpnij kłódkę")
	assert_true(padlock.is_locked)
	assert_eq(bed.features.hud.current()[1], "Ale to tylko kłódka…")
	RunState.artifacts.append(ArtifactCatalog.JANITOR_KEY)
	prompt = await _use(at, padlock.global_position)
	assert_eq(prompt, "Otwórz kłódkę kluczem woźnego")
	assert_false(padlock.is_locked)
	assert_true(GameState.secrets.has(LobbySecrets.CASE))


func test_a_padlock_broken_before_is_gone() -> void:
	GameState.secrets = [LobbySecrets.CASE] as Array[StringName]
	await _setup()
	assert_false(bed.features.padlock.is_locked)
	var inside := bed.features._artifact_near(Vector3(16.5, 1.0, -14.0))
	assert_eq(inside.collision_layer, Layers.INTERACT)


func test_the_row_of_icons_follows_the_artifacts() -> void:
	await _setup(_night_with(ArtifactCatalog.WOLF_TOOTH))
	var free: Array[StringName] = []
	for spot: int in bed.features.artifacts:
		var pickup: ArtifactPickup = bed.features.artifacts[spot]
		if not pickup.locked:
			free.append(pickup.artifact_id)
	assert_gt(free.size(), 1)
	for id in free:
		_take(id)
	await physics_frames(20)
	assert_eq(bed.features.hud.shown_artifacts(), free)
	assert_eq(RunState.artifacts, free)
	RunState.reset()
	await physics_frames(20)
	assert_eq(bed.features.hud.shown_artifacts().size(), 0)
