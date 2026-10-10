class_name Museum
extends Node3D
## The game scene: one night in the museum. The game plays Floor I, the
## Great Court (MuseumFloorLevel; its own game - gates, guardians, the
## goal, the finale - is FloorGame); the lobby of the earlier stages stays
## as the test level ([member level_id], set to &"lobby" by the test
## runner). Draws the night
## (NightDirector: modifier, crystal, locked door, exhibits, loot, fuses),
## builds the lobby for it, the havens and their upgrade terminals, the
## guard with his night-start kit, the exhibits and loot of the draw, the
## lantern of the last death, the HUD and the menus. Handles the haven
## (heal + save), death (lantern, 23:00, next night), leaving (save, back
## to the main menu) and dawn (6:00: the exhibits turn to stone, the night
## ends without a death). A night is restarted by reloading this scene, so
## nothing lingers between nights.
## A night left through the menu is resumed by "Continue": what was
## destroyed or taken stays gone and the guard keeps his health and ammo
## (see PersistentState.night_progress); death clears that. Spawn slot and
## loot spot indices are the night's stable ids: the same seed always draws
## the same night on the same lobby.
## When it is not the running scene (tests) it emits signals instead of
## changing scenes.

signal next_night_requested
signal quit_requested
## The guard walked down into the dark after the boss (when this is not
## the running scene; otherwise the demo's end screen follows).
signal demo_end_requested

## How much each drawn consumable gives.
const LOOT_AMOUNTS := {&"bullets": 12, &"shells": 4, &"medkit": 25, &"rifle": 50, &"flares": 3,
		&"hunt_rounds": 5, &"harpoons": 3, &"rockets": 2}
const LOOT_TYPES := {&"bullets": Pickup.Type.BULLETS, &"shells": Pickup.Type.SHELLS, &"medkit": Pickup.Type.MEDKIT,
		&"rifle": Pickup.Type.RIFLE, &"flares": Pickup.Type.FLARES, &"hunt_rounds": Pickup.Type.HUNT_ROUNDS,
		&"harpoons": Pickup.Type.HARPOONS, &"rockets": Pickup.Type.ROCKETS}
## Ammo for a weapon the guard does not have yet turns into ammo he can use
## (ammo -> [weapon it needs, what it becomes]).
const LOOT_STANDINS := {&"rifle": [&"gatling", &"bullets"], &"flares": [&"flare", &"shells"],
		&"hunt_rounds": [&"rifle_hunt", &"bullets"], &"harpoons": [&"harpoon", &"shells"], &"rockets": [&"hwacha", &"shells"]}
## Ammo -> the gun that fires it (the fight's supplies go to guns he has).
const AMMO_WEAPONS := {&"bullets": &"pistol", &"shells": &"shotgun", &"rifle": &"gatling", &"flares": &"flare",
		&"hunt_rounds": &"rifle_hunt", &"harpoons": &"harpoon", &"rockets": &"hwacha"}
## RunState.used prefix of a raptor pack's losses: "pack_<slot>_<lost>".
const PACK_LOSS_PREFIX := "pack_"
## Meta key on each portrait: its painting spot (marker id).
const PORTRAIT_META := &"portrait_spot"
## Zone used when the level gives none for a haven (m).
const DEFAULT_HAVEN_SIZE := Vector3(6.0, 3.0, 6.0)
## Which level a night is played on: &"floor1" (the game) or &"lobby" (the
## earlier stages' lobby, the test level; tests/test_runner.gd picks it
## before every test, Floor I tests set &"floor1" themselves).
static var level_id: StringName = &"floor1"

## Seconds of falling before the screen starts to fade.
const DEATH_DELAY := 0.6
## Seconds of morning light over the frozen exhibits before the dawn card.
const DAWN_DELAY := 2.6
## Seconds of night time between two rests (heal + save) in the same
## haven: stepping in and out at the door must not make it a healing
## station. Starting the night in a haven counts as a rest just taken.
const REST_COOLDOWN := 30.0
## Meta key on each exhibit: the index of its spawn slot.
const SLOT_META := NightSpawner.SLOT_META

var game: PersistentState
var run: NightState
var level: Level
## The lobby (the same node as [member level]; null on Floor I).
var lobby: LobbyLevel
## Floor I (the same node as [member level]; null in the lobby).
var floor_level: MuseumFloorLevel = null
## Floor I's own game: gates, rooms, the goal, guardians, pickups, the
## finale, the world content (null in the lobby).
var floor_game: FloorGame = null
## Tonight's draw.
var night: NightConfig
var player: Player
var hud: Hud
var pause_menu: PauseMenu
var upgrade_menu: UpgradeMenu
var death_screen: DeathScreen
var dawn_screen: DawnScreen
var enemies_root: Node3D
var pickups_root: Node3D
## The plain paintings of the painting spots (the portraits are exhibits).
var paintings_root: Node3D
var dust_dropper: DustDropper
## Haven id -> Haven.
var havens: Dictionary = {}
var lantern: DroppedLantern = null
## The shotgun, the chained gatling and the flare gun's cabinet (lobby only).
var armory: LobbyArmory = null
## Fuses, the crystal, the boss and the way down (lobby only).
var objective: NightObjective = null
## The night's clock (23:00 to 6:00).
var watch: NightWatch = null
## First-night tips (once ever).
var onboarding: Onboarding = null
## The lobby's world content: secrets, notes, the till key and the gun
## locker with the pistol, tonight's artifacts, the CCTV.
var features: LobbyFeatures = null
var rest_cooldown: float = REST_COOLDOWN

var _dying: bool = false
var _leaving: bool = false
## Night time and haven of the last rest.
var _rested_at: float = -INF
var _rested_in: StringName = &""


func _ready() -> void:
	game = GameState
	run = RunState
	NightRules.start_night(game, run)
	level = build_level()
	level.name = "Level"
	lobby = level as LobbyLevel
	floor_level = level as MuseumFloorLevel
	night = plan_night(game, level)
	if lobby != null:
		lobby.night = night
		lobby.boss_stand_in = false   # the live boss stands on the pedestal
	if floor_level != null:
		# tonight's locked door and the gates opened for good, before the bake
		floor_level.night = night
		floor_level.gates_open = game.gates_open.duplicate()
		# the real locks bring their own bodies (the canoe is the bridge)
		floor_level.skip_kits = GateLocks.replaced_kits()
	add_child(level)
	level.build()
	if lobby != null:
		NightModifiers.apply(lobby, night.modifier, run)
		# exhibits see by the lobby's lamps and hear through its open doors
		LevelPerception.configure_lobby(lobby, night.modifier)
	elif floor_level != null:
		NightModifiers.apply(floor_level, night.modifier, run)
		var moon := LayoutIllumination.FULL_MOON_LEVEL if night.modifier == &"full_moon" else LayoutIllumination.MOON_LEVEL
		LevelPerception.configure_layout(floor_level.layout, floor_level.doors, floor_level.lights, moon)
	else:
		PerceptionWorld.reset()
	PerceptionWorld.set_difficulty(DifficultyRules.index(game.difficulty))
	enemies_root = _group("Exhibits")
	pickups_root = _group("Pickups")
	paintings_root = _group("Paintings")
	_build_havens()
	_spawn_player()
	_build_ui()
	_spawn_exhibits()
	_place_loot()
	_place_lantern()
	if lobby != null:
		armory = LobbyArmory.new()
		add_child(armory)
		armory.setup(self)
		objective = NightObjective.new()
		objective.tune_exhibit = _tune_exhibit
		add_child(objective)
		objective.setup(self)
		objective.demo_finished.connect(_on_demo_finished)
	watch = NightWatch.new()
	add_child(watch)
	watch.setup(self)
	watch.dawn.connect(_on_dawn)
	if lobby != null or floor_level != null:
		onboarding = Onboarding.new()
		add_child(onboarding)
		onboarding.setup(self)
	dust_dropper = DustDropper.new()
	dust_dropper.target = player
	dust_dropper.motes_parent = pickups_root
	add_child(dust_dropper)
	_install_features()
	if floor_level != null:
		floor_game = FloorGame.new()
		add_child(floor_game)
		floor_game.setup(self)
		floor_game.finished.connect(_on_demo_finished)
	# compile every material and cut debris now, while the fade is black
	# (headless test runs have no renderer to warm; they cut debris lazily)
	if DisplayServer.get_name() != "headless":
		Fx.warm_up(self, player.camera)
	_announce_night()
	Events.player_died.connect(_on_player_died)
	Events.upgrade_bought.connect(_on_upgrade_bought)
	Events.dust_collected.connect(_on_dust_collected)
	Events.enemy_destroyed.connect(_on_enemy_destroyed)
	game.saving.connect(_on_game_saving)
	game.save_failed.connect(_on_save_failed)
	GameInput.set_gameplay_scene(true)
	_pause_if_unfocused.call_deferred()


func _exit_tree() -> void:
	GameInput.set_gameplay_scene(false)
	PerceptionWorld.reset()
	# nothing of this night outlives it (SceneFlow does the same before a swap)
	Sfx.stop_gameplay()
	Fx.clear()


## What a night's level needs made before it is built (SceneFlow runs it
## under the loading screen): Floor I's shell.
static func prepare_level() -> void:
	if level_id != &"lobby":
		MuseumFloorLevel.prewarm()


## The level of this game: Floor I, or the lobby ([member level_id]).
func build_level() -> Level:
	if level_id == &"lobby":
		return LobbyLevel.new()
	return MuseumFloorLevel.new()


## Tonight's draw for [param game]'s night on [param on_level] (a level
## without a description gets an empty night; Floor I adds what the save
## knows: FloorNight).
static func plan_night(for_game: PersistentState, on_level: Level) -> NightConfig:
	if on_level is MuseumFloorLevel:
		return FloorNight.plan(for_game, (on_level as MuseumFloorLevel).layout)
	var description: LevelDescription = on_level.call(&"describe") if on_level.has_method(&"describe") else null
	if description == null:
		var empty := NightConfig.new()
		empty.night = for_game.night
		return empty
	return NightDirector.plan(for_game.night_seed(), for_game.night, description)


## Saves (carried Dust and the night in progress included) and goes back to
## the main menu.
func quit_to_menu() -> void:
	if _leaving or SceneFlow.busy:
		return
	_leaving = true
	if not _dying:
		NightRules.save_progress(game, run)
	run.end_night()
	if SceneFlow.is_running(self):
		SceneFlow.goto(SceneFlow.MAIN_MENU)
	else:
		quit_requested.emit()


func quit_game() -> void:
	if _leaving or SceneFlow.busy:
		return
	_leaving = true
	if not _dying:
		NightRules.save_progress(game, run)
	run.end_night()
	if SceneFlow.is_running(self):
		SceneFlow.quit()
	else:
		quit_requested.emit()


func _notification(what: int) -> void:
	# closing the window saves like leaving through the menu
	if what == NOTIFICATION_WM_CLOSE_REQUEST and not _dying and not _leaving:
		_leaving = true
		NightRules.save_progress(game, run)


## True once the night is ending (death, dawn, leaving, the end of the
## demo): nothing that happens in it counts any more.
func night_over() -> bool:
	return _dying or _leaving


## The exhibits of the night still standing (the exhibits' node also holds
## the shards a bust spits).
func exhibits() -> Array[Enemy]:
	var found: Array[Enemy] = []
	for node in enemies_root.get_children():
		var exhibit := node as Enemy
		if exhibit != null and not exhibit.is_queued_for_deletion():
			found.append(exhibit)
	return found


## Loot spot index -> artifact id of tonight's artifacts (their pickups
## belong to the secrets and artifacts feature, I2).
func artifact_spots() -> Dictionary:
	var found := {}
	for spot: int in night.loot:
		if NightDirector.ARTIFACTS.has(night.loot[spot]):
			found[spot] = night.loot[spot]
	return found


func _group(group_name: String) -> Node3D:
	var node := Node3D.new()
	node.name = group_name
	add_child(node)
	return node


func _build_havens() -> void:
	for id in level.haven_spots:
		var spot: Transform3D = level.haven_spots[id]
		var zone: AABB = level.haven_zones.get(id, _default_zone(spot))
		var haven := Haven.make(id, zone)
		haven.guard_entered.connect(_on_haven_entered.bind(id))
		add_child(haven)
		havens[id] = haven
		var terminal := UpgradeTerminal.new()
		terminal.name = "Terminal_" + String(id)
		terminal.transform = spot
		terminal.opened.connect(_on_terminal_opened)
		add_child(terminal)


static func _default_zone(spot: Transform3D) -> AABB:
	var center := spot.origin + (-spot.basis.z).normalized() * (DEFAULT_HAVEN_SIZE.z * 0.5 - 0.5)
	return AABB(center - DEFAULT_HAVEN_SIZE * 0.5 + Vector3(0.0, DEFAULT_HAVEN_SIZE.y * 0.5, 0.0), DEFAULT_HAVEN_SIZE)


## The night starts at the last haven reached (in front of its terminal) or
## at the level's start.
func _start_transform() -> Transform3D:
	var haven := game.start_haven
	if haven != PersistentState.DEFAULT_HAVEN and level.haven_spots.has(haven):
		var spot: Transform3D = level.haven_spots[haven]
		var into_room := (-spot.basis.z).normalized()
		return Transform3D(Basis.looking_at(into_room, Vector3.UP), spot.origin + into_room * 1.6 + Vector3.UP * 0.1)
	return level.player_start


func _spawn_player() -> void:
	player = Player.new()
	player.name = "Guard"
	var start := _start_transform()
	player.position = start.origin
	add_child(player)
	player.respawn(start.origin, start.basis.get_euler().y)
	Loadout.equip_night_start(player, game)
	_restore_guard(game.current_progress().get("guard", {}))
	var haven := Haven.at(start.origin)
	if haven != null:
		_rested_at = run.time
		_rested_in = haven.id


func _build_ui() -> void:
	hud = Hud.new()
	hud.player = player
	hud.show_dust = true
	hud.night = game.night
	add_child(hud)
	hud.hide_help()
	upgrade_menu = UpgradeMenu.new()
	add_child(upgrade_menu)
	pause_menu = PauseMenu.new()
	pause_menu.show_night_info = true
	pause_menu.quit_to_menu_requested.connect(quit_to_menu)
	pause_menu.quit_game_requested.connect(quit_game)
	add_child(pause_menu)
	death_screen = DeathScreen.new()
	add_child(death_screen)
	dawn_screen = DawnScreen.new()
	add_child(dawn_screen)


## Tonight's exhibits on their drawn slots, except those already destroyed
## tonight (a resumed night: a pack comes back without the raptors it lost).
func _spawn_exhibits() -> void:
	var placed := NightSpawner.spawn(night, level.spawn_slots, enemies_root, player, _tune_exhibit, run.killed_slots, pack_losses(run))
	_gentle_start(placed)
	_hang_paintings()


## Night 1 (design pietro-1-projekt 7.2): for its first minutes the
## sleepers on the way out of the first haven (the lobby's booth -> hall;
## Floor I's booth -> entrance hall -> Great Court) sleep soundly (a
## resumed night gets what is left of those minutes).
func _gentle_start(placed: Array[Enemy]) -> void:
	var left := NightDirector.GENTLE_TIME - run.time
	if night.night > 1 or not level.has_method(&"describe") or left <= 0.0:
		return
	var way := NightDirector.first_way(level.call(&"describe"))
	for exhibit in placed:
		if exhibit.brain.state == EnemyBrain.State.DORMANT and way.has(exhibit.home_room):
			exhibit.sound_asleep = left


## Spawn slot -> raptors its pack lost tonight (RunState.used
## "pack_<slot>_<lost>"; a slot whose last raptor fell is in killed_slots).
static func pack_losses(of_run: NightState) -> Dictionary:
	var lost := {}
	for id in of_run.used:
		var text := String(id)
		if not text.begins_with(PACK_LOSS_PREFIX):
			continue
		var parts := text.trim_prefix(PACK_LOSS_PREFIX).split("_")
		if parts.size() != 2 or not parts[0].is_valid_int() or not parts[1].is_valid_int():
			continue
		var slot := parts[0].to_int()
		lost[slot] = maxi(int(lost.get(slot, 0)), parts[1].to_int())
	return lost


## Records one more raptor of [param slot]'s pack lost tonight.
static func mark_pack_loss(of_run: NightState, slot: int) -> void:
	var lost := int(pack_losses(of_run).get(slot, 0))
	of_run.used.erase(StringName("%s%d_%d" % [PACK_LOSS_PREFIX, slot, lost]))
	of_run.mark_used(StringName("%s%d_%d" % [PACK_LOSS_PREFIX, slot, lost + 1]))


## Every painting spot gets its painting (each spot always the same face):
## tonight's portraits (NightDirector) wait among plain paintings, except
## those destroyed earlier tonight (an empty wall).
func _hang_paintings() -> void:
	var markers: Variant = level.get(&"markers")
	if not markers is Dictionary or not level.has_method(&"describe"):
		return
	var spots: Array[StringName] = (level.call(&"describe") as LevelDescription).portrait_spots
	var faces := PaintingArt.ids()
	for i in spots.size():
		var spot := spots[i]
		if not (markers as Dictionary).has(spot):
			continue
		var at: Transform3D = markers[spot]
		var face := faces[i % faces.size()]
		if not night.portraits.has(spot):
			paintings_root.add_child(WallPainting.create(at, face))
			continue
		if run.is_used(portrait_id(spot)):
			continue
		var portrait := Portrait.create_on_wall(at, face)
		portrait.target = player
		portrait.set_meta(PORTRAIT_META, spot)
		_tune_exhibit(portrait)
		enemies_root.add_child(portrait)


## RunState.used id of a portrait destroyed tonight.
static func portrait_id(spot: StringName) -> StringName:
	return StringName("portrait_%s" % String(spot))


## Every exhibit of the night passes here before it enters the tree
## (tonight's stats).
func _tune_exhibit(exhibit: Enemy) -> void:
	NightModifiers.tune(exhibit, night.modifier)
	DifficultyRules.tune(exhibit, game.difficulty)
	if floor_level != null:
		FloorEncounters.tune_from_layout(exhibit, floor_level.layout)
	if watch != null and watch.clock.is_witching():
		NightWatch.boost(exhibit)


## The night's card (number, modifier) and the hook for the music.
func _announce_night() -> void:
	var title := tr("HUD_NIGHT") % game.night
	var name_key := NightModifiers.title_key(night.modifier)
	if name_key == "":
		hud.show_card(title, tr("NIGHT_START_TIME"), tr("NIGHT_START_DETAIL"))
	else:
		hud.show_card(title, tr(name_key), tr(NightModifiers.detail_key(night.modifier)))
	Events.night_started.emit(game.night, night.modifier)


## Tonight's ammo and medkits on their drawn spots, except the spots
## already taken tonight. Artifacts are left to the world content (it puts
## them in their containers).
func _place_loot() -> void:
	for spot: int in night.loot:
		var item := loot_for_guard(night.loot[spot])
		if not LOOT_TYPES.has(item) or run.taken_loot.has(spot) or spot >= level.loot_spots.size():
			continue
		var pickup := Pickup.new()
		pickup.name = "Loot_%d" % spot
		pickup.type = LOOT_TYPES[item]
		pickup.amount = LOOT_AMOUNTS[item]
		pickup.respawn_time = 0.0
		pickup.position = level.loot_spots[spot].position + Vector3.UP * 0.35
		pickup.taken.connect(run.mark_taken.bind(spot))
		pickups_root.add_child(pickup)


## What drawn [param item] becomes for tonight's guard: belts and flares
## only for a guard who has the gun for them, else bullets and shells.
func loot_for_guard(item: StringName) -> StringName:
	if LOOT_STANDINS.has(item):
		var standin: Array = LOOT_STANDINS[item]
		if player.weapons.state_of(standin[0]) == null:
			return standin[1]
	return item


## What the fight's supply [param item] becomes for the guard as he is now:
## ammo only for a gun he has (else ammo for one he has, in the order of
## AMMO_WEAPONS), a medkit when he has no gun at all.
func supply_for_guard(item: StringName) -> StringName:
	var wanted := loot_for_guard(item)
	if not AMMO_WEAPONS.has(wanted) or player.weapons.state_of(AMMO_WEAPONS[wanted]) != null:
		return wanted
	for ammo: StringName in AMMO_WEAPONS:
		if player.weapons.state_of(AMMO_WEAPONS[ammo]) != null:
			return ammo
	return &"medkit"


func _place_lantern() -> void:
	lantern = DroppedLantern.from_save(game)
	if lantern != null:
		lantern.run = run
		pickups_root.add_child(lantern)


## Secrets, notes, the key and the gun locker, artifacts and the CCTV (the
## world content); its monitors show the night's own clock.
func _install_features() -> void:
	if lobby == null:
		return
	features = LobbyFeatures.install(lobby, self)
	if features.cctv != null and watch != null:
		features.cctv.clock_seconds = func() -> float: return watch.clock.elapsed
	# the notes read so far, again from the pause menu; the camera view
	# shut by a lost focus asks for the pause the menu could not give
	pause_menu.note_reader = features.reader
	pause_menu.game = game
	features.pause_requested.connect(pause_menu.open)


## Puts back the guard's health and ammo of a resumed night.
func _restore_guard(saved: Dictionary) -> void:
	var health: float = saved.get("health", 0.0)
	if health > 0.0 and health < player.health.current:
		player.health.apply_damage(player.health.current - health)
	var arms: Dictionary = saved.get("weapons", {})
	for id in arms:
		var state := player.weapons.state_of(StringName(id))
		if state == null:
			continue
		var entry: Dictionary = arms[id]
		state.magazine = clampi(int(entry.get("magazine", 0)), 0, state.data.magazine_size)
		state.reserve = clampi(int(entry.get("reserve", 0)), 0, state.data.max_reserve)
		state.battery = clampf(float(entry.get("battery", 0.0)), 0.0, state.data.battery_max)


## The guard's health and ammo for the save.
func _guard_state() -> Dictionary:
	var arms := {}
	for state in player.weapons.owned:
		arms[String(state.data.id)] = {"magazine": state.magazine, "reserve": state.reserve, "battery": state.battery}
	return {"health": player.health.current, "weapons": arms}


## A night started without the window's focus (alt-tabbed while loading)
## begins paused.
func _pause_if_unfocused() -> void:
	if is_inside_tree() and not _dying and GameInput.should_pause_unfocused() and not get_window().has_focus():
		pause_menu.open()


## Every save while the night runs keeps what "Continue" needs (a save at
## death, after the night ended, keeps nothing).
func _on_game_saving() -> void:
	if run.running and not _dying and is_instance_valid(player):
		if watch != null:
			watch.save_into(run)
		game.night_progress = NightRules.progress_snapshot(game, run, _guard_state())


func _on_save_failed() -> void:
	hud.show_warning(tr("HUD_SAVE_FAILED"))


func _on_enemy_destroyed(enemy: Node, _info: DamageInfo, _finisher: bool) -> void:
	if not is_instance_valid(enemy) or enemy.get_parent() != enemies_root:
		return
	if enemy.has_meta(PORTRAIT_META):
		run.mark_used(portrait_id(enemy.get_meta(PORTRAIT_META)))
	if not enemy.has_meta(SLOT_META):
		return
	var slot := int(enemy.get_meta(SLOT_META))
	# a pack shares its slot: the slot is gone with its last raptor, and
	# until then a resumed night brings back only the raptors still standing
	for other in exhibits():
		if other != enemy and other.has_meta(SLOT_META) and int(other.get_meta(SLOT_META)) == slot:
			mark_pack_loss(run, slot)
			return
	run.mark_killed(slot)


func _on_haven_entered(_player: Player, id: StringName) -> void:
	if night_over() or not player.alive:
		return
	# no catching breath next door to the T-Rex (the broom cupboard opens
	# off the arena's balcony)
	if (objective != null and objective.stage == NightObjective.Stage.BOSS) or (floor_game != null and floor_game.blocks_rest()):
		hud.show_toast(tr("HUD_NO_REST_BOSS"))
		return
	# nor in a haven a guardian still keeps (the tea house until the General falls)
	if floor_game != null and floor_game.haven_guarded(id):
		hud.show_toast(tr("HUD_NO_REST_GUARDIAN"))
		return
	if id == _rested_in and run.time - _rested_at < rest_cooldown:
		return
	_rested_at = run.time
	_rested_in = id
	player.refill()
	var known := game.havens.has(id)
	if NightRules.enter_haven(game, run, id):
		hud.show_toast(tr("HUD_SAVED"))
	if not known and floor_game != null:
		floor_game.haven_discovered(id)


func _on_terminal_opened(_by: Node) -> void:
	if not night_over():
		upgrade_menu.open(game, run)


func _on_upgrade_bought(_id: StringName, _level: int) -> void:
	player.apply_upgrades(game.upgrades)


func _on_dust_collected(amount: int) -> void:
	game.stats["dust_earned"] = int(game.stats["dust_earned"]) + amount


func _on_player_died() -> void:
	if _dying or _leaving:
		return
	_dying = true
	pause_menu.allowed = false
	GameInput.push_ui(self, false)   # no more input from the fallen guard, no cursor
	var dropped := run.dust
	NightRules.on_death(game, run, player.last_floor_position)
	await get_tree().create_timer(DEATH_DELAY, false).timeout
	death_screen.play(game.night, dropped)
	await death_screen.finished
	_next_night()


## 6:00: the exhibits stop dead and grey over, the morning comes in
## through the skylights, the night ends without a death (the carried Dust
## stays with the guard), and after the dawn card the next night begins.
## The guard lets go at once, and the night's goal, its pickups and Dust
## stand still: nothing he could still do would outlive the save below.
func _on_dawn() -> void:
	if _dying or _leaving:
		return
	_leaving = true
	pause_menu.allowed = false
	GameInput.push_ui(self, false)
	pickups_root.process_mode = Node.PROCESS_MODE_DISABLED
	if objective != null:
		objective.process_mode = Node.PROCESS_MODE_DISABLED
	for exhibit in exhibits():
		exhibit.freeze()
	if objective != null and is_instance_valid(objective.boss):
		_freeze_boss(objective.boss)
	if floor_game != null:
		floor_game.freeze()
	_morning_light()
	Sfx.play(&"dawn_chime")
	Events.dawn_broke.emit()
	var survived := game.night
	var carried := run.dust
	NightRules.on_dawn(game, run)
	hud.show_card(tr("NIGHT_DAWN"), NightClock.dawn_text())
	await get_tree().create_timer(DAWN_DELAY, false).timeout
	dawn_screen.play(survived, carried)
	await dawn_screen.finished
	_next_night()


func _freeze_boss(boss: TRex) -> void:
	boss.process_mode = Node.PROCESS_MODE_DISABLED
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color(0.5, 0.49, 0.47)
	stone.roughness = 0.95
	for node in boss.find_children("*", "GeometryInstance3D", true, false):
		(node as GeometryInstance3D).material_override = stone


## A cold pink morning through the skylights and a paler hall.
func _morning_light() -> void:
	if NightModifiers.lights_of(level) == null:
		return
	var tween := create_tween().set_parallel(true)
	for moon in NightModifiers.moons(level):
		tween.tween_property(moon, ^"light_color", Color(1.0, 0.74, 0.58), 2.2)
		tween.tween_property(moon, ^"light_energy", maxf(moon.light_energy * 1.6, 1.5), 2.2)
	var env := NightModifiers.environment(level)
	if env != null:
		tween.tween_property(env, ^"ambient_light_color", Color(0.78, 0.64, 0.58), 2.2)
		tween.tween_property(env, ^"ambient_light_energy", maxf(env.ambient_light_energy, 0.85), 2.2)
		tween.tween_property(env, ^"background_color", Color(0.32, 0.25, 0.3), 2.2)
		tween.tween_property(env, ^"volumetric_fog_albedo", Color(1.0, 0.82, 0.72), 2.2)


## The guard walked down into the dark: the end of the demo.
func _on_demo_finished() -> void:
	if _dying or _leaving:
		return
	_leaving = true
	pause_menu.allowed = false
	GameInput.push_ui(self, false)
	NightRules.save_progress(game, run)
	run.end_night()
	if SceneFlow.is_running(self):
		SceneFlow.goto(SceneFlow.DEMO_END)
	else:
		demo_end_requested.emit()


func _next_night() -> void:
	if SceneFlow.is_running(self):
		SceneFlow.goto(SceneFlow.MUSEUM)
	else:
		next_night_requested.emit()
