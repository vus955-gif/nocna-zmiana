extends Node
## Gameplay screenshots for the README (not part of the headless suite): the
## real Floor I museum at night, seen through the guard's own eyes with the
## HUD up and a different weapon in hand each time, the exhibits and the
## guardians caught mid-action.
##   bash tools/run_promo.sh dry [--only=trex,books]
##       no window (--headless --fixed-fps 60): stages every shot, checks
##       its state ("MISSED" when a moment did not happen), captures nothing
##       -> tests/_out/promo/dry.json
##   bash tools/run_promo.sh shots [--only=trex,books] [--lang=pl]
##       silent 1920x1080 window: the same staging, each moment saved as
##       tests/_out/promo/<name>.png with its brightness (mean luminance,
##       near-black share; DARK as in the tour) -> metrics.json
## The guard plays for real: his normal health, healed every tick so the
## HUD never shows a dev value; the night card, the room cards and the tip
## strips are let fade before a shot (the tutorial is off). Every shot's
## subject must stand in his clear sight (a world ray from the eye) or the
## moment is MISSED. The pistol and the gatling carry the master finish
## (every upgrade at the top) for variety. The T-Rex comes last: its bar
## would stay over the other shots (roar on the pedestal, the stalk down
## on the floor, the charge's windup under the spun-up gatling).
## Groups (--only): shotgun, general, lamassu, books, egypt, trex.

const OUT_DIR := "res://tests/_out/promo/"
const WATCHDOG_SECONDS := 480.0
const Tour := preload("res://tests/scenarios/tour_scenario.gd")
const GROUPS: Array[String] = ["shotgun", "general", "lamassu", "books", "egypt", "trex"]
## Weapons with every upgrade bought: the warm sheen and the glowing signature part.
const MASTERED: Array[StringName] = [&"pistol", &"gatling"]
## Heals up to his normal maximum (no health upgrade): what the HUD shows.
const HEAL := 1000000.0
## The security booth: out of every arena (between the guardian shots).
const BOOTH := Vector3(33.0, 0.0, 45.5)
const TS := TRexBrain.State
const LA := LamassuBrain.Attack
const LS := LamassuBrain.State
const GA := GeneralBrain.Attack
const GS := GeneralBrain.State
const GT := GeneralBrain.Stage

var museum: Museum
var _mode := "shots"
var _dry := false
var _lang := "en"
var _only: PackedStringArray = []
var _log: Array = []
var _missed: int = 0
var _build_ms: int = 0


func _ready() -> void:
	get_tree().create_timer(WATCHDOG_SECONDS, true, false, true).timeout.connect(_on_watchdog)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--mode="):
			_mode = arg.trim_prefix("--mode=")
		elif arg.begins_with("--only="):
			_only = arg.trim_prefix("--only=").split(",", false)
		elif arg.begins_with("--lang="):
			_lang = arg.trim_prefix("--lang=")
	_dry = DisplayServer.get_name() == "headless"
	if _dry:
		_mode = "dry"
	GameInput.capture_allowed = false
	if not _dry:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(Vector2i(1920, 1080))
	Settings.set_value(&"graphics_quality", GraphicsQuality.Quality.HIGH, false)
	Settings.set_value(&"language", _lang, false)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var ignore := FileAccess.open(ProjectSettings.globalize_path("res://tests/_out/.gdignore"), FileAccess.WRITE)
	if ignore != null:
		ignore.close()
	await _open()
	if _wanted("shotgun"):
		await _shotgun_wax()
	if _wanted("general"):
		await _general_duel()
	if _wanted("lamassu"):
		await _lamassu()
	if _wanted("books"):
		await _books_firechest()
	if _wanted("egypt"):
		await _egypt_harpoon()
	if _wanted("trex"):
		await _trex_gatling()
	var file := FileAccess.open(OUT_DIR.path_join("dry.json" if _dry else "metrics.json"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"build_ms": _build_ms, "lang": _lang, "shots": _log}, "  "))
		file.close()
	print("promo %s: %d moments, %d missed, museum built in %d ms" % [_mode, _log.size(), _missed, _build_ms])
	Sfx.quit_cleanly(1 if _missed > 0 else 0)


func _on_watchdog() -> void:
	print("MISSED: the promo scenario did not finish in time")
	Sfx.quit_cleanly(1)


func _wanted(group: String) -> bool:
	return _only.is_empty() or _only.has(group)


## A new game on night 1 in Floor I with the art; the guard armed with
## every weapon, pockets full, the mastered ones polished; the night's card
## gone before the first shot.
func _open() -> void:
	Museum.level_id = &"floor1"
	MuseumFloorLevel.dress_default = true
	GameState.new_game()
	GameState.night = 1
	RunState.reset()
	var started := Time.get_ticks_msec()
	museum = (load(SceneFlow.MUSEUM) as PackedScene).instantiate() as Museum
	add_child(museum)
	_build_ms = Time.get_ticks_msec() - started
	print("museum built in %d ms (floor I level %d ms, navigation %d ms)" % [_build_ms, museum.floor_level.build_msec, museum.floor_level.bake_msec])
	var guard := museum.player
	for id in WeaponHolder.SLOT_ORDER:
		var data := load("res://src/weapons/data/%s.tres" % id) as WeaponData
		if data != null:
			guard.weapons.give(data)
	var levels := {}
	for entry in UpgradeCatalog.all():
		if MASTERED.has(entry.category):
			levels[entry.id] = entry.max_level()
	guard.apply_upgrades(levels)
	for state in guard.weapons.owned:
		state.magazine = state.data.magazine_size
		state.reserve = state.data.max_reserve
	guard.weapons.select_id(&"pistol")
	guard.health.heal(HEAL)
	if museum.onboarding != null:
		museum.onboarding.process_mode = Node.PROCESS_MODE_DISABLED   # no tutorial strips over the shots
	await _seconds(2.5)   # shaders, SDFGI, fog history, probes
	await _clear_cards()


# --- 1. the shotgun into wax figures before the Nereid Monument, Greece -----------------
# (not the Parthenon gallery: that is the Centaur's arena, and it would wake)

func _shotgun_wax() -> void:
	var guard := museum.player
	var stand := Vector3(-66.5, 0.0, 12.0)
	_put_guard(stand, Vector3(-82.0, 5.0, 12.0))
	guard.weapons.select_id(&"shotgun")
	await _clear_cards()
	var figures: Array[Enemy] = []
	for at: Vector3 in [Vector3(-71.0, 0.0, 11.0), Vector3(-72.0, 0.0, 13.6), Vector3(-70.2, 0.0, 9.4), Vector3(-73.6, 0.0, 12.4)]:
		figures.append(_exhibit(&"wax", at, true))
	# they come at him: the nearest a few steps away takes the whole load
	await _until(func() -> bool:
		var first := _nearest(figures, guard.global_position)
		return first != null and first.global_position.distance_to(guard.global_position) < 3.6, 2.5)
	var nearest := _nearest(figures, guard.global_position)
	if nearest != null:
		_look_at(nearest.global_position + Vector3.UP * 0.85)
	var fired := await _fire(&"shotgun")
	await _frames(4)
	await _shot("shotgun_wax", fired and _damaged(figures) > 0, {"figures_hit": _damaged(figures), "chunks": Fx.chunk_count()}, _chests(figures, 2))
	await _until(func() -> bool: return guard.weapons.state_of(&"shotgun").can_fire(), 1.5)
	nearest = _nearest(figures, guard.global_position)
	if nearest != null:
		_look_at(nearest.global_position + Vector3.UP * 0.85)
	fired = await _fire(&"shotgun")
	await _frames(5)
	await _shot("shotgun_wax_2", fired and _damaged(figures) > 0, {"figures_hit": _damaged(figures), "chunks": Fx.chunk_count()}, _chests(figures, 1))
	for figure in figures:
		if is_instance_valid(figure):
			figure.queue_free()


# --- 2. the Samurai General: the glint over his dash lane, the pistol -------------------

func _general_duel() -> void:
	var general := _guardian(&"general") as General
	if general == null:
		await _shot("general_duel", false, {"missing": "general"})
		return
	var post := general.home.origin
	var start: Vector3 = (museum.floor_level.markers[&"arena_general_start"] as Transform3D).origin
	museum.player.weapons.select_id(&"pistol")
	await _no_guardian_fighting()
	_put_guard(start, post + Vector3.UP * 2.0)
	var stand := _at(general, 7.0, 0.0)
	await _until(func() -> bool:
		_put_guard(stand, general.global_position + Vector3.UP * 1.5)
		return general.brain.state == GS.GUARD, 14.0)
	await _clear_cards()
	general.brain.force_attack(GA.DASH)
	await _until(func() -> bool: return general.moves.glint > 0.3, 1.0)
	await _seconds(0.15)
	_look_at(general.global_position + Vector3.UP * 1.6)
	var fired := await _fire(&"pistol")
	var ok := general.brain.attack == GA.DASH and general.brain.stage == GT.TELEGRAPH and general.dash_lane() != null and general.moves.glint > 0.3
	await _shot("general_duel", ok and fired, {"glint": snappedf(general.moves.glint, 0.01), "guardian_bar": museum.hud.boss_bar_shown()},
			[general.global_position + Vector3.UP * 1.6, general.rig.glint_point()])
	# out of his lane before the lunge, then out of the garden: he goes back
	# to his stand (his bar fades before the next guardian's comes up)
	_put_guard(_at(general, 9.0, 4.0), general.global_position + Vector3.UP * 1.5)
	await _seconds(0.5)
	await _calm(general)


# --- 3. the Lamassu: the charge's telegraph and run, the wing gust; the rifle -------------

func _lamassu() -> void:
	var lamassu := _guardian(&"lamassu") as Lamassu
	if lamassu == null:
		await _shot("lamassu_rifle", false, {"missing": "lamassu"})
		return
	var face := lamassu.home.origin + Vector3.UP * 3.0
	var start: Vector3 = (museum.floor_level.markers[&"arena_lamassu_start"] as Transform3D).origin
	museum.player.weapons.select_id(&"rifle_hunt")
	await _no_guardian_fighting()
	_put_guard(start, face)
	var stand := _at(lamassu, 11.0, 0.0)
	await _lamassu_idle(lamassu, stand)
	await _clear_cards()
	await _lamassu_idle(lamassu, stand)
	# the charge: placed two steps off its plinth, the guard nine metres
	# down the court; the head drops, the hoof paws, the lane runs to him
	_lamassu_place(lamassu, _at(lamassu, 2.0, 0.0), PI)
	_put_guard(stand, lamassu.global_position + Vector3.UP * 1.6)
	lamassu.brain.force_attack(LA.CHARGE)
	await _until(func() -> bool:
		return lamassu.brain.attack != LA.CHARGE or lamassu.brain.stage != LamassuBrain.Stage.TELEGRAPH or lamassu.brain.stage_time() > 0.72, 1.2)
	_look_at(lamassu.rig.face_point())
	var fired := await _fire(&"rifle_hunt")
	var telegraph := lamassu.brain.attack == LA.CHARGE and lamassu.brain.stage == LamassuBrain.Stage.TELEGRAPH
	await _shot("lamassu_rifle", telegraph and fired, {"pawing": lamassu.moves.pawing, "stage_time": snappedf(lamassu.brain.stage_time(), 0.01), "guardian_bar": museum.hud.boss_bar_shown()},
			[lamassu.rig.face_point(), lamassu.global_position + Vector3.UP * 1.2])
	# the run, from beside the lane
	await _until(func() -> bool: return lamassu.brain.stage == LamassuBrain.Stage.STRIKE or lamassu.brain.attack != LA.CHARGE, 1.5)
	var aside := _at(lamassu, 12.0, 4.0)
	_put_guard(aside, lamassu.global_position + Vector3.UP * 1.4)
	await _until(func() -> bool:
		_look_at(lamassu.global_position + Vector3.UP * 1.4)
		return lamassu.gait.speed > 8.0 or lamassu.brain.attack != LA.CHARGE, 1.5)
	_look_at(lamassu.global_position + Vector3.UP * 1.4)
	fired = await _fire(&"rifle_hunt")
	await _shot("lamassu_charge", lamassu.brain.attack == LA.CHARGE and lamassu.gait.speed > 8.0, {"speed": snappedf(lamassu.gait.speed, 0.1), "fired": fired},
			[lamassu.rig.face_point(), lamassu.global_position + Vector3.UP * 1.2])
	# the gust: the wings rise over the court
	var near := _at(lamassu, 10.0, 0.0)
	await _lamassu_idle(lamassu, near)
	_lamassu_place(lamassu, _at(lamassu, 3.0, 0.0), PI)
	_put_guard(near, lamassu.global_position + Vector3.UP * 2.4)
	lamassu.brain.force_attack(LA.GUST)
	await _until(func() -> bool: return lamassu.rig.wing_end(0).y > 3.5, 1.0)
	_look_at(lamassu.global_position + Vector3.UP * 2.4)
	fired = await _fire(&"rifle_hunt")
	await _shot("lamassu_gust", lamassu.brain.attack == LA.GUST and lamassu.rig.wing_end(0).y > 3.5, {"wing_y": snappedf(lamassu.rig.wing_end(0).y, 0.1), "fired": fired},
			[lamassu.rig.face_point(), lamassu.rig.wing_end(0), lamassu.rig.wing_end(1)])
	_put_guard(_at(lamassu, 20.0, 6.0), lamassu.global_position + Vector3.UP * 1.5)
	await _seconds(0.5)
	await _calm(lamassu)


func _lamassu_idle(lamassu: Lamassu, guard: Vector3) -> void:
	await _until(func() -> bool:
		_put_guard(guard, lamassu.global_position + Vector3.UP * 1.5)
		return lamassu.brain.state == LS.IDLE, 14.0)


func _lamassu_place(lamassu: Lamassu, at: Vector3, yaw: float) -> void:
	lamassu.global_position = at
	lamassu.rotation.y = yaw
	lamassu.speed = 0.0
	lamassu.velocity = Vector3.ZERO
	lamassu.reset_physics_interpolation()
	lamassu.gait.place(lamassu.global_transform)


# --- 4. the fire-arrow chest into a flock of flying books, the King's Library ----------

func _books_firechest() -> void:
	var guard := museum.player
	var stand := Vector3(38.0, 0.0, 12.0)
	_put_guard(stand, Vector3(38.0, 2.0, 2.0))
	guard.weapons.select_id(&"flare")
	await _clear_cards()
	var books := BookFlock.make_members(Vector3(38.0, 0.0, 3.0), PI, 6)
	for book in books:
		book.target = guard
		book.summoned = true
		museum._tune_exhibit(book)
		museum.enemies_root.add_child(book)
		book.brain.wake()
	await _seconds(1.6)   # off the floor, into their ring round him
	# a flare under the flock: the light they are seen by
	_look_at(Vector3(38.0, 0.05, 4.5))
	var lit := await _fire(&"flare")
	await _until(func() -> bool: return not _all("FlareLight").is_empty(), 1.5)
	await _seconds(0.5)
	guard.weapons.select_id(&"hwacha")
	await _seconds(0.45)
	# the volley meets a book diving at him (the ring's books keep their
	# distance; a diver comes straight down the line of fire), else the
	# nearest of the ring
	var flock: BookFlock = (books[0] as FlyingBook).flock
	var diver: Array = [null]
	await _until(func() -> bool:
		var book := flock.diver() as FlyingBook
		if book == null or not book.diving():
			return false
		var eye := guard.global_position + Vector3.UP * guard.eye_height
		if (book.global_position - eye).normalized().dot(-guard.head.global_transform.basis.z) < 0.5:
			return false
		diver[0] = book
		return true, 8.0)
	var target := (diver[0] as Node3D).global_position if diver[0] != null else _flock_target(books, guard)
	_look_at(target)
	var fired := await _fire(&"hwacha")
	await _seconds(0.16)
	var rockets := _all("HwachaRocket").size()
	await _shot("books_firechest", fired and lit and rockets > 0, {"rockets": rockets, "books_hit": _damaged(books), "flare": not _all("FlareLight").is_empty(), "diver": diver[0] != null},
			_chests(books, 2, 0.0))
	await _seconds(0.16)
	await _shot("books_firechest_2", _all("HwachaRocket").size() + _damaged(books) > 0, {"rockets": _all("HwachaRocket").size(), "books_hit": _damaged(books)},
			_chests(books, 2, 0.0))
	await _seconds(0.2)
	await _shot("books_firechest_3", _damaged(books) > 0, {"rockets": _all("HwachaRocket").size(), "books_hit": _damaged(books)}, _chests(books, 1, 0.0))
	for book in books:
		if is_instance_valid(book):
			book.queue_free()


## The nearest book in front of the guard (its body), or the flock's centre.
func _flock_target(books: Array[Enemy], guard: Player) -> Vector3:
	var eye := guard.global_position + Vector3.UP * guard.eye_height
	var forward := -guard.head.global_transform.basis.z
	var best: Node3D = null
	var best_d := INF
	for book in books:
		if not is_instance_valid(book):
			continue
		var to := book.global_position - eye
		if to.dot(forward) > 0.3 and to.length() < best_d:
			best_d = to.length()
			best = book
	if best != null:
		return best.global_position
	return Vector3(38.0, 2.0, 5.0)


# --- 5. the harpoon gun on a mummy of the expedition camp, Egypt ------------------------

func _egypt_harpoon() -> void:
	var guard := museum.player
	var camp := Vector3(-41.6, 0.0, 4.2)
	var mummy: Enemy = null
	for exhibit in museum.exhibits():
		if exhibit is Mummy and exhibit.home_room == &"egypt_gallery":
			if mummy == null or exhibit.global_position.distance_to(camp) < mummy.global_position.distance_to(camp):
				mummy = exhibit
	if mummy == null:
		await _shot("egypt_harpoon", false, {"missing": "mummy"})
		return
	# the camp's other sleepers (its scarabs, the other two mummies) out of
	# the line: the harpoon is for this one
	for exhibit in museum.exhibits():
		if exhibit != mummy and exhibit.home_room == &"egypt_gallery" and exhibit.global_position.distance_to(camp) < 12.0:
			exhibit.queue_free()
	var stand := Vector3(mummy.global_position.x, 0.0, mummy.global_position.z + 7.5)
	_put_guard(stand, mummy.global_position + Vector3.UP * 1.2)
	guard.weapons.select_id(&"harpoon")
	guard.set_flashlight(true)
	await _clear_cards()
	mummy.summoned = true
	mummy.brain.wake()
	var up := mummy as Mummy
	# it climbs out of its sarcophagus and comes at him
	await _until(func() -> bool:
		_look_at(mummy.global_position + Vector3.UP * 1.0)
		return not up.in_tomb() and not up.rising() and mummy.global_position.distance_to(guard.global_position) < 5.2, 8.0)
	_look_at(mummy.global_position + Vector3.UP * 0.9)
	var fired := await _fire(&"harpoon")
	await _frames(4)
	var bolts := _all("Harpoon")
	await _shot("egypt_harpoon", fired and not bolts.is_empty(), {"bolt": _bolt_state(bolts, up), "mummy": _mummy_state(up, guard)}, _chests([mummy], 1))
	await _seconds(0.5)
	var hurt := not is_instance_valid(mummy) or mummy.health.current < mummy.health.max_health
	await _shot("egypt_harpoon_2", fired and (hurt or not bolts.is_empty()), {"bolt": _bolt_state(bolts, up), "mummy": _mummy_state(up, guard), "hurt": hurt}, _chests([mummy], 1))
	guard.set_flashlight(false)
	if is_instance_valid(mummy):
		mummy.queue_free()


# --- 6. the T-Rex in the Great Court, the gatling spun up (last: its bar stays) ----------

func _trex_gatling() -> void:
	var guard := museum.player
	var finale := museum.floor_game.finale
	if finale == null or not is_instance_valid(finale.boss):
		await _shot("trex_gatling", false, {"missing": "trex"})
		return
	var boss := finale.boss
	# the open strip north of the balcony (under it the colonnade stands
	# between the guard and the pedestal), east of the skeleton's head: it
	# roars side on, then comes down off the pedestal straight at him
	var roar_stand := Vector3(13.0, 0.0, -26.0)
	var stand := Vector3(19.0, 0.0, -27.5)
	await _no_guardian_fighting()
	_put_guard(roar_stand, boss.skeleton.crystal_position())
	guard.weapons.select_id(&"gatling")
	await _clear_cards()
	boss.wake()
	boss.brain.charge_cooldown = 99.0   # no charge of its own: the staged one below
	var state := guard.weapons.state_of(&"gatling")
	# the roar on the pedestal, the barrels spun up and the belt running
	await _until(func() -> bool:
		_look_at(boss.skeleton.crystal_position())
		return false, 0.55)
	var traced := await _hold_fire_until_tracer(&"gatling", 1.6)
	await _shot("trex_roar", traced and boss.brain.state == TS.WAKING and museum.hud.boss_bar_shown(),
			_trex_extra(boss, state), [boss.skeleton.crystal_position(), _trex_head(boss)])
	# a few steps back: it comes down off its pedestal onto the floor at
	# him, and eleven metres away it charges
	_put_guard(stand, boss.skeleton.crystal_position())
	await _until(func() -> bool:
		_look_at(boss.skeleton.crystal_position())
		return boss.brain.state == TS.STALK, TRexBrain.WAKE_TIME + 1.5)
	# on the floor, stalking him upright: a burst as it comes
	await _until(func() -> bool:
		_look_at(boss.skeleton.crystal_position())
		return boss.global_position.y < 0.4 and boss.global_position.distance_to(guard.global_position) < 11.5, 9.0)
	traced = await _hold_fire_until_tracer(&"gatling", 1.2)
	await _shot("trex_stalk", traced and boss.brain.state == TS.STALK and museum.hud.boss_bar_shown(),
			_trex_extra(boss, state), [boss.skeleton.crystal_position(), _trex_head(boss)])
	# (its skull swings five metres ahead of its root: nine metres off, it
	# fills the view)
	await _until(func() -> bool:
		_look_at(boss.skeleton.crystal_position())
		return boss.global_position.distance_to(guard.global_position) < 9.2, 4.0)
	# a fight some way in: the crystal has taken a few hits already
	var wear := boss.health.current - boss.health.max_health * 0.78
	if wear > 0.0:
		var worn := DamageInfo.make(wear, DamageInfo.Kind.BALLISTIC, guard)
		worn.position = boss.skeleton.crystal_position()
		worn.direction = Vector3.FORWARD
		boss.take_zone_damage(worn, TRexBrain.Zone.CRYSTAL)
	boss.brain.charge_cooldown = 0.0
	var wound := await _until(func() -> bool:
		_look_at(boss.skeleton.crystal_position())
		return boss.brain.state == TS.CHARGE_WINDUP, 3.0)
	if wound:
		await _until(func() -> bool:
			_look_at(boss.skeleton.crystal_position())
			return false, 0.45)   # the head drops, the glow builds
	_look_at(boss.skeleton.crystal_position())
	# held on this frame of its windup while the barrels spin up and the
	# belt runs: the crystal takes every round
	var mode := boss.process_mode
	boss.process_mode = Node.PROCESS_MODE_DISABLED
	traced = await _hold_fire_until_tracer(&"gatling", 2.5)
	var ok := traced and state.spun_up() and state.magazine < state.data.magazine_size and museum.hud.boss_bar_shown() and not boss.is_dead()
	var sights: Array[Vector3] = [boss.skeleton.crystal_position(), _trex_head(boss)]
	await _shot("trex_gatling", ok, _trex_extra(boss, state), sights)
	# a long burst later: more sparks on the bones, the bar a notch lower
	traced = await _hold_fire_until_tracer(&"gatling", 2.0, 0.7)
	await _shot("trex_gatling_2", traced and museum.hud.boss_bar_shown(), _trex_extra(boss, state), sights)
	boss.process_mode = mode


func _trex_extra(boss: TRex, state: WeaponState) -> Dictionary:
	return {"boss_state": TS.keys()[boss.brain.state], "boss_health": snappedf(boss.health.fraction(), 0.01),
		"distance": snappedf(boss.global_position.distance_to(museum.player.global_position), 0.1), "spun_up": state.spun_up(), "rounds_left": state.magazine}


## About where its skull is (the head collider's place on the root).
func _trex_head(boss: TRex) -> Vector3:
	return boss.to_global(TRex.HEAD_COLLIDER)


# --- staging -------------------------------------------------------------------------

func _guardian(id: StringName) -> Guardian:
	return museum.floor_game.guardians.guardians.get(id) as Guardian


## A point [param ahead] m in front of a guardian's post, [param aside] m
## to its left.
func _at(guardian: Guardian, ahead: float, aside: float) -> Vector3:
	var home := guardian.home
	return home.origin - home.basis.z * ahead - home.basis.x * aside


## A new exhibit of [param kind] at [param at] hunting the guard (awake).
func _exhibit(kind: StringName, at: Vector3, awake: bool) -> Enemy:
	var enemy := NightSpawner.make(kind)
	enemy.position = at + Vector3.UP * 0.05
	enemy.target = museum.player
	enemy.summoned = awake
	museum._tune_exhibit(enemy)
	museum.enemies_root.add_child(enemy)
	enemy.face(museum.player.global_position)
	if awake:
		enemy.brain.wake()
	return enemy


## The chests ([param up] m over the feet; 0 for a flier's body) of the
## [param count] nearest of [param enemies] still standing.
func _chests(enemies: Array[Enemy], count: int, up: float = 0.9) -> Array[Vector3]:
	var standing: Array[Enemy] = []
	for enemy in enemies:
		if is_instance_valid(enemy):
			standing.append(enemy)
	var guard := museum.player.global_position
	standing.sort_custom(func(a: Enemy, b: Enemy) -> bool: return a.global_position.distance_to(guard) < b.global_position.distance_to(guard))
	var points: Array[Vector3] = []
	for enemy in standing.slice(0, count):
		points.append(enemy.global_position + Vector3.UP * up)
	return points


func _nearest(enemies: Array[Enemy], to: Vector3) -> Enemy:
	var best: Enemy = null
	for enemy in enemies:
		if is_instance_valid(enemy) and (best == null or enemy.global_position.distance_to(to) < best.global_position.distance_to(to)):
			best = enemy
	return best


## How many of [param enemies] are hurt or gone.
func _damaged(enemies: Array[Enemy]) -> int:
	var count := 0
	for enemy in enemies:
		if not is_instance_valid(enemy) or enemy.health.current < enemy.health.max_health:
			count += 1
	return count


func _all(type: String) -> Array[Node]:
	return get_tree().root.find_children("*", type, true, false)


## The guard stands at [param at] looking at [param look].
func _put_guard(at: Vector3, look: Vector3) -> void:
	var guard := museum.player
	guard.global_position = at + Vector3.UP * 0.05
	guard.velocity = Vector3.ZERO
	guard.reset_physics_interpolation()
	guard.health.heal(HEAL)
	_look_at(look)
	guard.head.global_position = guard.global_position + Vector3.UP * guard.eye_height


func _look_at(point: Vector3) -> void:
	var guard := museum.player
	var eye := guard.global_position + Vector3.UP * guard.eye_height
	var aim := point - eye
	guard.head.rotation = Vector3(atan2(aim.y, Vector2(aim.x, aim.z).length()), atan2(-aim.x, -aim.z), 0.0)


## One shot of weapon [param id] (selected if it is not in hand, ready at
## once when it is): true when it went off.
func _fire(id: StringName) -> bool:
	var weapons := museum.player.weapons
	if weapons.current_state() == null or weapons.current_state().data.id != id:
		weapons.select_id(id)
		await _seconds(0.3)
	var state := weapons.state_of(id)
	if not state.can_fire():
		await _until(func() -> bool: return state.can_fire(), 1.5)
	return weapons.try_fire()


## The trigger held on weapon [param id] (the gatling: it spins up first)
## for at least [param hold] s, until a traced round leaves the barrel, at
## most [param limit] s: true on that round (the capture that follows
## catches its tracer and flash).
func _hold_fire_until_tracer(id: StringName, limit: float, hold: float = 0.0) -> bool:
	var weapons := museum.player.weapons
	var state := weapons.state_of(id)
	var left := limit
	while left > 0.0:
		museum.player.health.heal(HEAL)
		var fired := weapons.try_fire()
		if fired and limit - left >= hold and weapons._rounds % maxi(state.data.tracer_every, 1) == 0:
			return true
		await get_tree().physics_frame
		left -= 1.0 / Engine.physics_ticks_per_second
	return false


## The guard gone from its arena (to the booth, out of every arena: a reset
## with him still inside would wake it again at once), the guardian back
## on its post, asleep, its bar faded (the HUD hides the bar on any
## guardian's calming: the next one's must not go with it).
func _calm(guardian: Guardian) -> void:
	_put_guard(BOOTH, BOOTH + Vector3(-5.0, 1.5, 0.0))
	await _seconds(0.1)
	guardian.reset_fight()
	await _until(func() -> bool: return not museum.hud.boss_bar_shown() and not guardian.is_fighting(), 2.0)


## No guardian still fighting (one woken in passing calms down on its leash
## a few seconds after the guard left; its calming would hide the next
## bar).
func _no_guardian_fighting() -> void:
	var keeper := museum.floor_game.guardians
	await _until(func() -> bool: return not keeper.fighting() and not museum.hud.boss_bar_shown(), 10.0)


func _bolt_state(bolts: Array[Node], mummy: Mummy) -> String:
	if bolts.is_empty() or not is_instance_valid(bolts[0]):
		return "none"
	var bolt := bolts[0] as Harpoon
	var gap := bolt.global_position.distance_to(mummy.global_position + Vector3.UP * 0.9) if is_instance_valid(mummy) else -1.0
	return "%s at %s, %.1f m from the mummy, flown %.1f" % [Harpoon.Phase.keys()[bolt.phase], str(bolt.global_position.snapped(Vector3.ONE * 0.1)), gap, bolt._flown]


func _mummy_state(mummy: Mummy, guard: Player) -> String:
	if not is_instance_valid(mummy):
		return "gone"
	return "%s health %.0f, %.1f m, %s" % [EnemyBrain.State.keys()[mummy.brain.state], mummy.health.current,
		mummy.global_position.distance_to(guard.global_position), "in tomb" if mummy.in_tomb() else ("rising" if mummy.rising() else "up")]


## Waits for the night's card, the card of the room just entered (the room
## tracker notices a step later) and any hint strip to fade: nothing over
## the view but the HUD.
func _clear_cards() -> void:
	await _seconds(0.6)
	await _until(func() -> bool:
		return museum.hud.card_text() == "" and museum.hud.room_card_text() == "" and museum.hud.hint_text() == "", 11.0)


## A moment: logged, checked ([param ok], and every point of
## [param sights] - the shot's subject - in the guard's clear sight, no
## world geometry between), and in a window a screenshot through the
## guard's eyes with its brightness.
func _shot(label: String, ok: bool, extra: Dictionary = {}, sights: Array[Vector3] = []) -> void:
	var entry := {"shot": label, "ok": ok, "guard_alive": museum.player.alive, "guard_health": museum.player.health.current,
		"weapon": String(museum.player.weapons.current_state().data.id) if museum.player.weapons.current_state() != null else "",
		"room": String(museum.floor_level.room_at(museum.player.global_position + Vector3.UP * 0.5)),
		"card": museum.hud.card_text(), "room_card": museum.hud.room_card_text(), "hint": museum.hud.hint_text()}
	entry.merge(extra)
	if not sights.is_empty():
		var blocked := _blocked_sight(sights)
		entry["sight"] = "clear" if blocked == "" else blocked
		if blocked != "":
			ok = false
	if not museum.player.alive:
		ok = false
	entry["ok"] = ok
	if not ok:
		_missed += 1
		print("MISSED: %s %s" % [label, str(entry)])
	else:
		print("%s: %s %s" % ["dry" if _dry else "shot", label, str(entry)])
	_log.append(entry)
	if _dry:
		return
	museum.player.camera.current = true
	museum.hud._vignette.modulate.a = 0.0   # the hits he took: not a red frame
	if museum.hud.hint_text() != "":
		museum.hud._hint_left = 0.0   # a tip strip raised by the shot itself: not over the picture
		museum.hud._hint.modulate.a = 0.0
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := OUT_DIR.path_join("%s.png" % label)
	image.save_png(path)
	var metrics: Dictionary = Tour.brightness(image)
	entry["mean"] = metrics["mean"]
	entry["near_black"] = metrics["near_black"]
	entry["dark"] = metrics["mean"] < Tour.DARK_MEAN or metrics["near_black"] > Tour.DARK_SHARE
	print("saved %s  mean %.3f  near-black %.0f%%%s" % [ProjectSettings.globalize_path(path), metrics["mean"], float(metrics["near_black"]) * 100.0, "  DARK" if entry["dark"] else ""])


## "" when a ray from the guard's eye reaches every point of [param points]
## without touching the world (walls, columns, plinths), else what stands
## in the way and where.
func _blocked_sight(points: Array[Vector3]) -> String:
	var eye := museum.player.camera.global_position
	var space := get_viewport().find_world_3d().direct_space_state
	for point in points:
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(eye, point, Layers.WORLD))
		if not hit.is_empty():
			var collider: Object = hit["collider"]
			var what := "world"
			if collider is Node:
				what = String((collider as Node).name)
			return "blocked by %s %.1f m out (target %.1f m)" % [what, eye.distance_to(hit["position"]), eye.distance_to(point)]
	return ""


## Physics ticks until [param condition] holds or [param limit] s pass
## (the guard healed every tick): true when it held.
func _until(condition: Callable, limit: float) -> bool:
	var left := limit
	while left > 0.0:
		if condition.call():
			return true
		if is_instance_valid(museum):
			museum.player.health.heal(HEAL)
		await get_tree().physics_frame
		left -= 1.0 / Engine.physics_ticks_per_second
	return condition.call()


func _seconds(time: float) -> void:
	for i in roundi(time * Engine.physics_ticks_per_second):
		if is_instance_valid(museum):
			museum.player.health.heal(HEAL)
		await get_tree().physics_frame


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame
