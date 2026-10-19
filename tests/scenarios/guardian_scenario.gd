extends Node
## The wing guardians' dev arena (not part of the headless suite): Floor I
## as the game builds it, the guard put in a guardian's real arena, the
## fight staged moment by moment through the guardian's test hooks.
##   bash tools/run_guardian.sh <id>          play it (window; for the
##                                            controller's night sessions)
##   bash tools/run_guardian.sh <id> --shots  silent 1280x720 window,
##                                            screenshots -> tests/_out/guardian_<id>/
##   bash tools/run_guardian.sh <id> --dry    no window (--headless): stages
##                                            every moment, captures nothing,
##                                            checks each one ("MISSED" when
##                                            a moment did not happen)
##   bash tools/run_guardian.sh <id> --bot    no window: a scripted guard
##                                            circles and shoots the weak
##                                            points (pistol, a hit in
##                                            BOT_ACCURACY) without dodging:
##                                            how long the fight takes and
##                                            what it costs (bot.json)
## Each moment logs the guardian's state to tests/_out/guardian_<id>/log.json.
## The Colossus (colossus), the Great Orrery (planetarium) and the Centaur
## (centaur) have their whole fights here; a guardian without moments of
## its own gets the common ones (asleep, awake, fighting, fallen).
## The Lamassu (lamassu) has its whole fight here too.
## The Two-headed Serpent (serpent) has its whole fight in
## tests/scenarios/serpent_moments.gd (SerpentMoments.fight).

const WATCHDOG_SECONDS := 400.0
## The bot: pistol shots a second, share that hit the aimed weak point,
## its circle round the guardian (m) and walking pace (m/s).
const BOT_RATE := 2.5
const BOT_ACCURACY := 0.45
const BOT_RADIUS := 11.0
const BOT_PACE := 3.0
const S := ColossusBrain.State
const A := ColossusBrain.Attack

var museum: Museum
var guardian: Guardian
var camera: Camera3D
var guardian_id: StringName = &"colossus"
var _mode := "dry"
var _dry := true
var _out := ""
var _log: Array = []
var _missed: int = 0


func _ready() -> void:
	get_tree().create_timer(WATCHDOG_SECONDS, true, false, true).timeout.connect(_on_watchdog)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--mode="):
			_mode = arg.trim_prefix("--mode=")
		elif arg.begins_with("--guardian="):
			guardian_id = StringName(arg.trim_prefix("--guardian="))
	_dry = DisplayServer.get_name() == "headless"
	if _dry and _mode != "dry" and _mode != "bot":
		_mode = "dry"
	_out = "res://tests/_out/guardian_%s/" % String(guardian_id)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	var ignore := FileAccess.open(ProjectSettings.globalize_path("res://tests/_out/.gdignore"), FileAccess.WRITE)
	if ignore != null:
		ignore.close()
	if _mode == "shots":
		GameInput.capture_allowed = false
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(Vector2i(1280, 720))
	elif _mode == "dry":
		GameInput.capture_allowed = false
	await _open()
	if guardian == null:
		print("MISSED: no guardian %s on Floor I" % guardian_id)
		Sfx.quit_cleanly(1)
		return
	if _mode == "play":
		_put_guard(_at(15.5, 0.0), _head())
		return   # the controller plays it; F-keys of the dev build as usual
	if _mode == "bot":
		await _bot()
		Sfx.quit_cleanly(0)
		return
	if guardian is Colossus:
		await _colossus_fight(guardian as Colossus)
	elif guardian is Centaur:
		await _centaur_fight(guardian as Centaur)
	elif guardian is Planetarium:
		await _planetarium_fight(guardian as Planetarium)
	elif guardian is Lamassu:
		await _lamassu_fight(guardian as Lamassu)
	elif guardian is General:
		await _general_fight(guardian as General)
	elif guardian is Serpent:
		await SerpentMoments.fight(self, guardian as Serpent)
	else:
		await _common_fight()
	var file := FileAccess.open(_out.path_join("log.json"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(_log, "  "))
		file.close()
	print("%s: %d moments, %d missed" % [guardian_id, _log.size(), _missed])
	Sfx.quit_cleanly(1 if _missed > 0 else 0)


func _on_watchdog() -> void:
	print("MISSED: the guardian scenario did not finish in time")
	Sfx.quit_cleanly(1)


func _open() -> void:
	Museum.level_id = &"floor1"
	GameState.new_game()
	RunState.reset()
	museum = (load(SceneFlow.MUSEUM) as PackedScene).instantiate() as Museum
	add_child(museum)
	# armed for a guardian: pistol, shotgun, flares (a plate breaker), full
	# pockets
	for id in [&"pistol", &"shotgun", &"flare"]:
		var data := load("res://src/weapons/data/%s.tres" % id) as WeaponData
		if data != null:
			museum.player.weapons.give(data)
	for weapon in museum.player.weapons.owned:
		weapon.reserve = weapon.data.max_reserve
	museum.player.weapons.select_id(&"pistol")
	if _mode != "play":
		# the guard only holds the camera: he must not fall
		museum.player.health.max_health = 1000000.0
		museum.player.health.heal(1000000.0)
	camera = Camera3D.new()
	camera.fov = 70.0
	camera.far = 200.0
	add_child(camera)
	await _seconds(1.0)
	guardian = museum.floor_game.guardians.guardians.get(guardian_id) as Guardian


# --- the Colossus ----------------------------------------------------------------

func _colossus_fight(colossus: Colossus) -> void:
	var front := _at(14.0, 4.0, 2.2)
	# 1. the museum piece
	_put_guard(_at(22.0, 0.0), _head())
	await _shot("dormant", front, _head(), colossus.state == Guardian.State.DORMANT)
	# 2. the guard steps in: the eyes ignite, dust, the grind
	_put_guard(_at(15.5, 0.0), _head())
	await _seconds(0.9)
	await _shot("waking", _at(9.0, 3.0, 2.0), _head(), colossus.brain.state == S.WAKING)
	await _until(func() -> bool: return colossus.brain.state == S.IDLE, 4.0)
	# 3. the hand slam: the palm's shadow, the arm over the shoulder, the blow
	_put_guard(_at(8.5, -2.5), _head())
	await _idle(colossus)
	colossus.brain.force_attack(A.SLAM)
	await _seconds(ColossusBrain.stage_length(A.SLAM, ColossusBrain.Stage.TELEGRAPH, 1) * 0.68)
	await _shot("slam_raised", _at(9.0, 9.0, 3.0), _at(4.0, -1.0, 3.5), colossus.brain.attack == A.SLAM and colossus.brain.stage == ColossusBrain.Stage.TELEGRAPH)
	await _until(func() -> bool: return colossus.brain.stage == ColossusBrain.Stage.STRIKE, 2.0)
	await _seconds(0.08)
	await _shot("slam_impact", _at(9.0, 9.0, 3.0), _at(6.0, -2.0, 0.5), colossus.brain.attack == A.SLAM and colossus.brain.stage == ColossusBrain.Stage.STRIKE)
	# 4. the low sweep: drawn back, then across the floor
	_put_guard(_at(6.5, 1.5), _head())
	await _idle(colossus)
	colossus.brain.force_attack(A.SWEEP)
	await _seconds(ColossusBrain.stage_length(A.SWEEP, ColossusBrain.Stage.TELEGRAPH, 1) * 0.9)
	await _shot("sweep_drawn", _at(12.0, -6.0, 4.0), _at(3.0, 0.0, 2.0), colossus.brain.attack == A.SWEEP)
	await _until(func() -> bool: return colossus.moves.sweep_low, 2.0)
	await _shot("sweep_low", _at(12.0, -6.0, 4.0), _at(5.0, 0.0, 0.5), colossus.moves.sweep_low)
	# 5. the beam on a column the guard hides behind
	var column := _nearest_column(colossus, 11.7)
	var eyes := colossus.rig.eyes_point()
	var away := Vector3(column.global_position.x - eyes.x, 0.0, column.global_position.z - eyes.z).normalized()
	var hiding := column.global_position + away * 2.2
	_put_guard(hiding, _head())
	await _idle(colossus)
	colossus.brain.force_attack(A.BEAM)
	await _seconds(ColossusBrain.stage_length(A.BEAM, ColossusBrain.Stage.TELEGRAPH, 1) * 0.8)
	await _shot("beam_charge", _at(10.0, 6.0, 2.5), _head(), colossus.brain.attack == A.BEAM)
	await _until(func() -> bool: return colossus.brain.stage == ColossusBrain.Stage.STRIKE, 2.0)
	await _seconds(0.6)
	await _shot("beam_on_column", _at(8.0, -8.0, 3.0), column.global_position + Vector3.UP * 3.0, colossus.beam.is_burning() and column.hits >= 1)
	# 6. phase 2: the plates burst, the cracks blaze, the swarms pour out
	await _idle(colossus)
	_put_guard(_at(10.0, 0.0), _head())
	_wound(colossus, 0.6)
	await _until(func() -> bool: return colossus.brain.state == S.PHASE_SHIFT, 6.0)
	await _seconds(ColossusBrain.PHASE_SHIFT_TIME * 0.5)
	await _shot("phase_shift", _at(9.0, 2.0, 3.0), _at(0.0, 0.0, 5.0), not colossus.rig.plates_on.has(true))
	await _until(func() -> bool: return colossus.alive_swarms() > 0, 6.0)
	await _seconds(0.5)
	var swarm := colossus.swarms[0] as Node3D if colossus.alive_swarms() > 0 else null
	await _shot("swarm", _at(6.0, -5.0, 1.6), swarm.global_position if swarm != null else _at(2.0, 2.0, 0.5), swarm != null)
	# 7. phase 3: he stands up
	await _idle(colossus)
	_wound(colossus, 0.3)
	await _until(func() -> bool: return colossus.brain.state == S.STAND_UP, 8.0)
	await _seconds(1.7)
	await _shot("stand_up", _at(10.0, 12.0, 2.0), _at(2.5, 0.0, 4.5), colossus.brain.state == S.STAND_UP)
	await _until(func() -> bool: return colossus.standing, 4.0)
	await _shot("standing", _at(14.0, 3.0, 1.7), colossus.global_position + Vector3.UP * 7.0, colossus.standing)
	# 8. he walks to the guard: stomps
	var stomps := [0]
	colossus.struck.connect(func(kind: StringName) -> void:
		if kind == &"stomp":
			stomps[0] += 1)
	for i in 8:
		_put_guard(_at(18.0, 0.0), _head())
		await _seconds(0.5)
	await _shot("walking", _at(18.0, 2.0, 1.7), colossus.global_position + Vector3.UP * 6.0, stomps[0] > 0)
	# 9. the beam sweeps the hall
	await _idle(colossus)
	colossus.brain.force_attack(A.BEAM_SWEEP)
	await _until(func() -> bool: return colossus.brain.stage == ColossusBrain.Stage.STRIKE, 3.0)
	await _seconds(0.7)
	await _shot("beam_sweep", _at(16.0, -9.0, 6.0), colossus.global_position + Vector3.UP * 3.0, colossus.beam.is_burning())
	# 10. his fall
	await _idle(colossus)
	var at := colossus.global_position
	var info := DamageInfo.make(colossus.health.current + 1.0, DamageInfo.Kind.BALLISTIC, museum.player)
	colossus.take_zone_damage(info, &"uraeus")
	await _seconds(0.5)
	await _shot("fall_tremble", at + Vector3(10.0, 3.0, 8.0), at + Vector3.UP * 5.0, not is_instance_valid(colossus))
	await _seconds(ColossusFall.TREMBLE + ColossusFall.TOPPLE)
	var falls := museum.floor_game.guardians.find_children("*", "ColossusFall", false, false)
	var broke := not falls.is_empty() and (falls[0] as ColossusFall).pieces.size() > 20
	await _shot("fallen", at + Vector3(10.0, 4.0, 8.0), at + Vector3.UP, broke and GameState.is_guardian_defeated(&"colossus"))


## The guard hits him through his uraeus down to [param fraction] of his
## health.
func _wound(colossus: Colossus, fraction: float) -> void:
	var amount := colossus.health.current - colossus.max_health * fraction + 1.0
	var info := DamageInfo.make(amount, DamageInfo.Kind.BALLISTIC, museum.player)
	info.position = colossus.rig.part("uraeus").global_position
	colossus.take_zone_damage(info, &"uraeus")


func _idle(colossus: Colossus) -> void:
	await _until(func() -> bool: return colossus.brain.state == S.IDLE, 8.0)


func _nearest_column(colossus: Colossus, distance: float) -> ColossusColumn:
	var best: ColossusColumn = null
	var gap := INF
	for node: ColossusColumn in get_tree().get_nodes_in_group(ColossusColumn.GROUP):
		var off := node.global_position - colossus.global_position
		if -off.dot(colossus.home.basis.z) > 0.0 and absf(off.length() - distance) < gap:
			gap = absf(off.length() - distance)
			best = node
	return best


# --- the Centaur ----------------------------------------------------------------------

func _centaur_fight(centaur: Centaur) -> void:
	const CA := CentaurBrain.Attack
	const CS := CentaurBrain.State
	const TELL := CentaurBrain.Stage.TELEGRAPH
	const HIT := CentaurBrain.Stage.STRIKE
	var post := centaur.home.origin
	var side_view := post + Vector3(-9.0, 2.2, 1.0)
	# 1. the figure in its metope, side on to the gallery's mouth
	_put_guard(post + Vector3(-22.0, 0.0, 0.0), post + Vector3.UP * 2.0)
	await _shot("dormant", side_view, post + Vector3.UP * 1.8, centaur.state == Guardian.State.DORMANT and not centaur.metope.broken)
	# 2. the guard steps in: it strains against the stone, the slab cracks
	_put_guard(post + Vector3(-15.0, 0.0, 0.0), post + Vector3.UP * 2.0)
	await _until(func() -> bool: return centaur.brain.state == CS.WAKING and centaur.brain.state_progress() > 0.3, 3.0)
	await _shot("straining", side_view, post + Vector3.UP * 1.8, centaur.metope.strain_amount > 0.3)
	# 3. it rears and tears free
	await _until(func() -> bool: return centaur.metope.broken, 3.0)
	await _seconds(0.15)
	await _shot("torn_free", side_view + Vector3(0.0, 0.5, 0.0), post + Vector3.UP * 2.2, centaur.metope.broken)
	await _until(func() -> bool: return centaur.brain.state == CS.ROAM, 3.0)
	# 4. the gallop round the guard
	var guard := post + Vector3(-12.0, 0.0, 0.0)
	await _until(func() -> bool:
		_put_guard(guard, centaur.global_position + Vector3.UP * 1.5)
		return centaur.gait.speed > 8.5 and centaur.gait.gait > 2.6, 6.0)
	await _shot("gallop", guard + Vector3(0.0, 1.6, 0.0), centaur.global_position + Vector3.UP * 1.4, centaur.gait.speed > 8.5 and centaur.gait.gait > 2.5)
	# 5. a javelin: the wind-up and its mark, the flight, stuck in the floor
	await _centaur_roaming(centaur, guard)
	centaur.brain.force_attack(CA.THROW)
	await _seconds(CentaurBrain.stage_length(CA.THROW, TELL, 1) * 0.75)
	await _shot("throw_windup", centaur.global_position + Vector3(4.0, 2.5, 4.0), centaur.global_position + Vector3.UP * 2.0,
			centaur.brain.attack == CA.THROW and centaur.brain.stage == TELL)
	await _until(func() -> bool: return centaur.brain.stage != TELL, 1.0)
	await _seconds(0.25)
	var javelin: CentaurJavelin = null
	if not centaur.javelins.is_empty():
		javelin = centaur.javelins.back() as CentaurJavelin
	var flying := javelin != null and is_instance_valid(javelin) and not javelin.stuck
	await _shot("javelin_flight", guard + Vector3(3.0, 1.8, 3.0), javelin.global_position if flying else guard, flying)
	await _until(func() -> bool: return javelin == null or not is_instance_valid(javelin) or javelin.stuck, 2.0)
	var stuck := javelin != null and is_instance_valid(javelin) and javelin.stuck
	await _shot("javelin_stuck", guard + Vector3(2.0, 1.6, 2.0), javelin.tip() if stuck else guard, stuck)
	# 6. up close: the rearing kick, the buck
	await _centaur_roaming(centaur, guard)
	_put_guard(centaur.global_position - centaur.global_basis.z * 3.0, centaur.global_position + Vector3.UP * 2.0)
	centaur.brain.force_attack(CA.KICK)
	await _seconds(CentaurBrain.stage_length(CA.KICK, TELL, 1) * 0.6)
	var flank := centaur.global_basis.x * 7.0
	await _shot("kick_rear", centaur.global_position + flank + Vector3.UP * 2.0, centaur.global_position + Vector3.UP * 2.0,
			-centaur.rig.part("barrel").global_basis.z.y > 0.5)
	await _until(func() -> bool: return centaur.brain.stage == HIT, 1.0)
	await _shot("kick_land", centaur.global_position + flank + Vector3.UP * 1.5, centaur.global_position - centaur.global_basis.z * 1.5,
			centaur.brain.attack == CA.KICK and centaur.brain.stage == HIT)
	await _centaur_roaming(centaur, guard)
	_put_guard(centaur.global_position + centaur.global_basis.z * 3.0, centaur.global_position + Vector3.UP * 1.5)
	centaur.brain.force_attack(CA.BUCK)
	await _until(func() -> bool: return centaur.brain.stage == HIT, 1.0)
	await _seconds(0.1)
	await _shot("buck", centaur.global_position + centaur.global_basis.x * 7.0 + Vector3.UP * 1.5, centaur.global_position + Vector3.UP,
			centaur.brain.attack == CA.BUCK and centaur.brain.stage == HIT)
	# 7. the charge: the scrape and its lane, the run, the crash into a plinth
	await _centaur_roaming(centaur, guard)
	var plinth := Vector3(-35.0, 0.0, 48.5)
	var before := plinth + Vector3(-2.6, 0.0, 0.0)
	var aside := before + Vector3(0.0, 0.0, -4.0)
	centaur.global_position = Vector3(-42.0, 0.0, 48.5)
	centaur.rotation.y = -PI * 0.5
	centaur.speed = 0.0
	centaur.reset_physics_interpolation()
	centaur.gait.place(centaur.global_transform)
	_put_guard(before, centaur.global_position + Vector3.UP * 1.5)
	centaur.brain.force_attack(CA.CHARGE)
	await _seconds(CentaurBrain.stage_length(CA.CHARGE, TELL, 1) * 0.55)
	await _shot("charge_scrape", centaur.global_position + Vector3(2.0, 1.8, -6.0), centaur.global_position + Vector3.UP,
			centaur.brain.attack == CA.CHARGE and centaur.brain.stage == TELL)
	await _until(func() -> bool: return centaur.brain.stage != TELL, 1.0)
	_put_guard(aside, centaur.global_position + Vector3.UP * 1.5)
	await _seconds(0.2)
	await _shot("charge_run", aside + Vector3(0.0, 1.6, 0.0), centaur.global_position + Vector3.UP * 1.4,
			centaur.brain.attack == CA.CHARGE or centaur.brain.state == CS.STUNNED)
	await _until(func() -> bool:
		_put_guard(aside, centaur.global_position + Vector3.UP * 1.5)
		return centaur.brain.state == CS.STUNNED, 3.0)
	await _seconds(0.4)
	await _shot("stunned", centaur.global_position + Vector3(-1.0, 2.0, -5.0), centaur.global_position + Vector3.UP * 1.6, centaur.brain.state == CS.STUNNED)
	# 8. phase 2: it rears and cries, the Lapiths step down from the pediments
	await _centaur_roaming(centaur, guard)
	_centaur_wound(centaur, 0.6)
	await _until(func() -> bool:
		_put_guard(guard, centaur.global_position + Vector3.UP * 1.5)
		return centaur.alive_lapiths() > 0, 8.0)
	var lapith: Node3D = null
	if centaur.alive_lapiths() > 0:
		lapith = centaur.lapiths[0] as Node3D
	await _shot("lapiths", guard + Vector3(0.0, 1.6, 0.0), lapith.global_position + Vector3.UP if lapith != null else guard, lapith != null)
	# 9. phase 3: the slab torn off, two javelins at once
	for node in centaur.lapiths:
		if is_instance_valid(node):
			node.queue_free()
	_centaur_wound(centaur, 0.3)
	await _until(func() -> bool:
		_put_guard(guard, centaur.global_position + Vector3.UP * 1.5)
		return centaur.brain.attack == CA.TEAR and centaur.brain.stage == HIT, 10.0)
	await _shot("tear", centaur.global_position - centaur.global_basis.x * 6.0 + Vector3.UP * 2.0, centaur.global_position + Vector3.UP * 1.5,
			centaur.brain.attack == CA.TEAR)
	await _until(func() -> bool: return centaur.brain.pair, 3.0)
	await _centaur_roaming(centaur, guard)
	var thrown := centaur.javelins.size()
	centaur.brain.force_attack(CA.THROW)
	await _until(func() -> bool:
		_put_guard(guard, centaur.global_position + Vector3.UP * 1.5)
		return centaur.javelins.size() >= thrown + 2, 3.0)
	await _shot("pair_throw", guard + Vector3(3.0, 1.8, 3.0), centaur.global_position + Vector3.UP * 2.0, centaur.javelins.size() >= thrown + 2)
	# 10. its fall
	await _centaur_roaming(centaur, guard)
	var at := centaur.global_position
	var info := DamageInfo.make(centaur.health.current + 1.0, DamageInfo.Kind.BALLISTIC, museum.player)
	centaur.take_zone_damage(info, &"chest")
	await _seconds(0.6)
	await _shot("fall_stumble", at + Vector3(5.0, 1.8, 5.0), at + Vector3.UP, not is_instance_valid(centaur))
	await _seconds(CentaurFall.TREMBLE + CentaurFall.COLLAPSE)
	var falls := museum.floor_game.guardians.find_children("*", "CentaurFall", false, false)
	var broke := not falls.is_empty() and (falls[0] as CentaurFall).pieces.size() > 15
	await _shot("fallen", at + Vector3(5.0, 2.5, 5.0), at, broke and GameState.is_guardian_defeated(&"centaur"))


func _centaur_roaming(centaur: Centaur, guard: Vector3) -> void:
	await _until(func() -> bool:
		_put_guard(guard, centaur.global_position + Vector3.UP * 1.5)
		return centaur.brain.state == CentaurBrain.State.ROAM, 8.0)


## The guard hits it through its chest down to [param fraction] of its health.
func _centaur_wound(centaur: Centaur, fraction: float) -> void:
	var amount := centaur.health.current - centaur.max_health * fraction + 1.0
	var info := DamageInfo.make(amount, DamageInfo.Kind.BALLISTIC, museum.player)
	info.position = centaur.rig.part("chest").global_position
	centaur.take_zone_damage(info, &"chest")


# --- the bot: the fight's length --------------------------------------------------------

## A guard who never dodges circles the guardian and shoots its weak
## points (any Hurtbox with weak_point the ray reaches) BOT_RATE times a
## second, hitting BOT_ACCURACY of them, from the moment it wakes to its
## fall: the fight's length and the damage he took (an upper bound).
func _bot() -> void:
	var pistol := load("res://src/weapons/data/pistol.tres") as WeaponData
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var angle := 0.0
	var clock := 0.0
	var shot := 0.0
	var taken := 0.0
	var hits := 0
	var shots := 0
	var phases := {}
	var guard := museum.player
	var last := guard.health.current
	_put_guard(_at(15.5, 0.0), _head())
	while is_instance_valid(guardian) and clock < 360.0:
		# (a guardian whose node stays on its post says where its fight is)
		var center: Vector3 = guardian.call(&"focus_point") if guardian.has_method(&"focus_point") else guardian.global_position
		angle += BOT_PACE / BOT_RADIUS / Engine.physics_ticks_per_second
		var around := Vector3(sin(angle) * 1.1, 0.0, -absf(cos(angle))).normalized()
		var at := center + guardian.global_basis * (around * BOT_RADIUS)
		at.y = center.y
		if museum.floor_level.room_at(at + Vector3.UP) != guardian.arena_room:
			at = center + (at - center) * 0.7
		# (a guardian close to a wall: closer in still, until he stands in
		# the arena - a hit from a doorway or a wall does not count)
		var closer := 0.7
		while closer > 0.3 and museum.floor_level.room_at(at + Vector3.UP) != guardian.arena_room:
			closer -= 0.15
			at = center + guardian.global_basis * (around * BOT_RADIUS * closer)
			at.y = center.y
		guard.global_position = at + Vector3.UP * 0.05
		guard.velocity = Vector3.ZERO
		taken += maxf(last - guard.health.current, 0.0)
		guard.heal(1000000.0)
		last = guard.health.current
		if guardian.phase > 0 and not phases.has(guardian.phase):
			phases[guardian.phase] = snappedf(clock, 0.1)
		shot -= 1.0 / Engine.physics_ticks_per_second
		if guardian.is_fighting():
			clock += 1.0 / Engine.physics_ticks_per_second
			if shot <= 0.0:
				shot = 1.0 / BOT_RATE
				var zone := _weak_zone_in_view(guard.global_position + Vector3.UP * guard.eye_height)
				if zone != null:
					shots += 1
					if rng.randf() < BOT_ACCURACY:
						hits += 1
						var info := DamageInfo.make(pistol.damage * pistol.weak_point_multiplier, DamageInfo.Kind.BALLISTIC, guard)
						info.weapon = &"pistol"
						info.position = zone.global_position
						info.weak_point = true
						(zone.receiver as Node).call(&"take_damage", info)
		await get_tree().physics_frame
	var result := {"guardian": String(guardian_id), "seconds": snappedf(clock, 0.1), "phases_at": phases,
		"weak_shots": shots, "hits": hits, "damage_taken": snappedf(taken, 1.0), "fallen": GameState.is_guardian_defeated(guardian_id)}
	print("bot: ", result)
	var file := FileAccess.open(_out.path_join("bot.json"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(result, "  "))
		file.close()


## The nearest weak point a ray from [param eye] reaches first, or null.
func _weak_zone_in_view(eye: Vector3) -> Hurtbox:
	var space := get_viewport().find_world_3d().direct_space_state
	for hurtbox: Hurtbox in guardian.find_children("*", "Hurtbox", true, false):
		if not hurtbox.weak_point:
			continue
		var hit := Hitscan.ray(space, eye, eye + (hurtbox.global_position - eye) * 1.2)
		if not hit.is_empty() and hit["hurtbox"] == hurtbox:
			return hurtbox
	return null


# --- the Great Orrery -------------------------------------------------------------

const OS_ := OrreryBrain.State
const OA := OrreryBrain.Attack
const OG := preload("res://src/game/floor1/guardians/orrery_geometry.gd")


func _planetarium_fight(orrery: Planetarium) -> void:
	var hub := orrery.home.origin + Vector3.UP * 2.6
	var wide := _orb(orrery, 12.0, PI - 0.7, 4.5)
	# 1. the museum piece in the moonlight
	_put_guard(Vector3(40.5, 0.0, orrery.home.origin.z), hub)
	await _shot("dormant", wide, hub, orrery.state == Guardian.State.DORMANT)
	# 2. the guard steps in: the gears catch, the sun breathes, the planets light
	var start: Vector3 = (museum.floor_level.markers[&"arena_planetarium_start"] as Transform3D).origin
	_put_guard(start, hub)
	await _seconds(1.2)
	await _shot("waking", _orb(orrery, 9.0, PI + 0.5, 3.0), hub, orrery.brain.state == OS_.WAKING)
	await _orrery_idle(orrery)
	# 3. a surge: the low arm's lamps, its chime, the gears clatter; then it races
	_put_guard(_orb(orrery, 7.5, PI), hub)
	orrery.brain.force_attack(OA.SURGE)
	orrery.brain.surge_tier = OG.LOW
	await _seconds(OrreryBrain.stage_length(OA.SURGE, OrreryBrain.Stage.TELEGRAPH, 0) * 0.6)
	await _shot("surge_warning", _orb(orrery, 8.5, PI - 0.4, 1.4), hub - Vector3.UP * 2.0, orrery.brain.stage == OrreryBrain.Stage.TELEGRAPH and orrery.moves.pose.lamps[OG.LOW] > 0.5)
	await _until(func() -> bool: return orrery.brain.stage == OrreryBrain.Stage.STRIKE, 2.0)
	await _seconds(1.2)
	var racing := absf(orrery.drives[OG.LOW].speed) > absf(float(OrreryBrain.CRUISE[OG.LOW][0])) * 1.5
	await _shot("surge", _orb(orrery, 8.5, PI - 0.4, 1.4), hub - Vector3.UP * 2.0, racing)
	# 4. a planet sent round the hall on its orbit
	await _orrery_idle(orrery)
	orrery.brain.force_attack(OA.LAUNCH)
	var flying := orrery.brain.launch_planet
	await _until(func() -> bool: return orrery.brain.stage == OrreryBrain.Stage.STRIKE, 2.0)
	await _seconds(2.0)
	var out := false
	if flying >= 0:
		var at := orrery.rig.planets[flying].global_position - orrery.home.origin
		out = orrery.rig.flying[flying] and Vector2(at.x, at.z).length() > 5.5
	await _shot("orbit", _orb(orrery, 4.0, PI + 0.3, 2.0), orrery.rig.planets[maxi(flying, 0)].global_position, out)
	# 5. a planet shot off: it drops and rolls
	await _orrery_idle(orrery)
	_put_guard(_orb(orrery, 8.0, PI), hub)
	_shoot_planet(orrery, 0)
	var rolling := orrery.hazards.filter(func(n: Variant) -> bool: return is_instance_valid(n) and n is RollingPlanet)
	await _seconds(0.8)
	var rolled: Node3D = rolling[0] if not rolling.is_empty() and is_instance_valid(rolling[0]) else null
	await _shot("planet_shot", _orb(orrery, 9.0, PI + 0.6, 2.5), rolled.global_position if rolled != null else hub, rolled != null and orrery.rig.gone[0])
	# 6. the second one: phase 2, the gears shift, the sun opens a notch
	_shoot_planet(orrery, 1)
	await _until(func() -> bool: return orrery.brain.state == OS_.SHIFT, 8.0)
	await _seconds(OrreryBrain.SHIFT_TIME * 0.7)
	await _shot("phase_shift", wide, hub + Vector3.UP * 2.0, orrery.brain.state == OS_.SHIFT and orrery.phase == 2)
	# 7. the sun's flare on its mark
	await _orrery_idle(orrery)
	_put_guard(_orb(orrery, 8.0, 0.6), hub)
	orrery.brain.force_attack(OA.FLARE)
	await _until(func() -> bool: return orrery.hazards.any(func(n: Variant) -> bool: return is_instance_valid(n) and n is SolarFlare), 3.0)
	await _seconds(0.5)
	var flare: SolarFlare = null
	for node: Variant in orrery.hazards:
		if is_instance_valid(node) and node is SolarFlare:
			flare = node
	await _shot("flare", _orb(orrery, 10.0, 0.0, 3.0), flare.landing if flare != null else hub, flare != null and is_instance_valid(flare.mark))
	# 8. phase 3: the petals wider
	await _orrery_idle(orrery)
	_shoot_planet(orrery, 2)
	_shoot_planet(orrery, 3)
	await _until(func() -> bool: return orrery.brain.state == OS_.SHIFT, 8.0)
	await _orrery_idle(orrery)
	await _shot("phase_3", _orb(orrery, 7.0, PI - 0.3, 5.5), hub + Vector3.UP * 2.4, orrery.phase == 3 and orrery.moves.pose.petals[0] > 0.4)
	# 9. the last planets: the sun blooms open, its core bared
	_shoot_planet(orrery, 4)
	_shoot_planet(orrery, 5)
	await _until(func() -> bool: return orrery.brain.state == OS_.UNVEIL, 8.0)
	await _seconds(OrreryBrain.UNVEIL_TIME * 0.8)
	await _shot("unveiled", _orb(orrery, 7.0, PI - 0.3, 5.5), hub + Vector3.UP * 2.4, orrery.brain.exposed and orrery.moves.pose.petals[0] > 1.2)
	# 10. its fall: it seizes, the petals break off, the core dies
	await _orrery_idle(orrery)
	var info := DamageInfo.make(orrery.health.current + 1.0, DamageInfo.Kind.BALLISTIC, museum.player)
	info.position = orrery.rig.core_world()
	orrery.take_zone_damage(info, &"core")
	await _seconds(0.9)
	await _shot("seizing", wide, hub + Vector3.UP * 2.0, not is_instance_valid(orrery))
	await _seconds(OrreryFall.DONE)
	var falls := museum.floor_game.guardians.find_children("*", "OrreryFall", false, false)
	var fell := not falls.is_empty() and (falls[0] as OrreryFall).pieces.size() > 10
	await _shot("fallen", wide, hub, fell and GameState.is_guardian_defeated(&"planetarium"))


## A floor point [param radius] m from the orrery's axis at world bearing
## [param angle] (from +X toward +Z), [param up] m up.
func _orb(orrery: Planetarium, radius: float, angle: float, up: float = 0.0) -> Vector3:
	return orrery.home.origin + Vector3(cos(angle) * radius, up, sin(angle) * radius)


func _shoot_planet(orrery: Planetarium, planet: int) -> void:
	var info := DamageInfo.make(orrery.planet_health[planet] + 1.0, DamageInfo.Kind.BALLISTIC, museum.player)
	info.position = orrery.rig.planets[planet].global_position
	info.direction = Vector3.FORWARD
	orrery.take_zone_damage(info, StringName("planet_%d" % (planet + 1)))


func _orrery_idle(orrery: Planetarium) -> void:
	await _until(func() -> bool: return orrery.brain.state == OS_.IDLE, 12.0)


# --- the Samurai General -----------------------------------------------------------

func _general_fight(general: General) -> void:
	const GA := GeneralBrain.Attack
	const GS := GeneralBrain.State
	const GT := GeneralBrain.Stage
	var post := general.home.origin
	var side_view := _at(6.0, 7.0, 2.2)
	# 1. the armour hanging on its stand behind the post
	_put_guard(_at(20.0, 0.0), _head())
	await _shot("dormant", side_view, post + Vector3.UP * 1.6, general.state == Guardian.State.DORMANT and general.rig.part("head").global_position.distance_to(post) > 0.8)
	# 2. the guard crosses the start line: the armour flies together
	var start: Vector3 = (museum.floor_level.markers[&"arena_general_start"] as Transform3D).origin
	_put_guard(start, post + Vector3.UP * 2.0)
	await _until(func() -> bool: return general.brain.state == GS.WAKING and general.brain.assemble_progress() > 0.45, 3.0)
	await _shot("assembling", side_view, post + Vector3.UP * 1.6, general.brain.state == GS.WAKING and general.moves.pose.assembly > 0.3 and general.moves.pose.assembly < 0.95)
	# 3. the draw out of the scabbard
	await _until(func() -> bool: return general.brain.draw_progress() > 0.5, 3.0)
	await _shot("drawing", _at(5.0, 3.0, 1.8), post + Vector3.UP * 1.8, general.brain.draw_progress() > 0.3 and general.brain.draw_progress() < 0.95)
	await _general_guarding(general, _at(7.0, 0.0))
	# 4. chudan: a hit from the front glances off the blade
	var blocks := [0]
	general.blocked_hit.connect(func() -> void: blocks[0] += 1)
	_general_hit(general, &"armour", 20.0, true)
	await _shot("guard_block", _at(4.0, 4.0, 1.7), general.global_position + Vector3.UP * 1.8, blocks[0] == 1 and general.brain.state == GS.GUARD)
	# 5. the dash: jodan and the glint over the lane, the lunge, the stumble
	general.brain.force_attack(GA.DASH)
	await _until(func() -> bool: return general.moves.glint > 0.3, 1.0)
	await _seconds(0.15)
	await _shot("dash_glint", _at(7.0, -4.0, 1.7), general.rig.glint_point(), general.brain.attack == GA.DASH and general.brain.stage == GT.TELEGRAPH and general.dash_lane() != null and general.moves.glint > 0.3)
	await _until(func() -> bool: return general.brain.stage != GT.TELEGRAPH, 1.5)
	_put_guard(_at(7.0, 3.0), post + Vector3.UP * 1.5)   # he stepped aside: a miss
	await _seconds(0.12)
	await _shot("dash_lunge", _at(9.0, -5.0, 1.6), general.global_position + Vector3.UP * 1.2, general.brain.stage == GT.STRIKE and general.kinematic)
	await _until(func() -> bool: return general.brain.stage == GT.RECOVER, 1.0)
	await _seconds(0.35)
	await _shot("dash_stumble", _at(9.0, -5.0, 1.6), general.global_position + Vector3.UP * 1.4, general.brain.back_open())
	# 6. the close cut up close
	await _general_guarding(general, general.global_position - general.global_basis.z * 2.6)
	general.brain.force_attack(GA.CLOSE)
	await _seconds(GeneralBrain.stage_length(GA.CLOSE, GT.TELEGRAPH, 1) * 0.8)
	var flank := general.global_basis.x * 5.0
	await _shot("close_jodan", general.global_position + flank + Vector3.UP * 2.0, general.global_position + Vector3.UP * 2.0, general.brain.attack == GA.CLOSE and general.brain.stage == GT.TELEGRAPH)
	await _until(func() -> bool: return general.brain.stage == GT.STRIKE, 1.0)
	await _seconds(0.1)
	await _shot("close_cut", general.global_position + flank + Vector3.UP * 1.6, general.global_position + Vector3.UP * 1.2, general.brain.attack == GA.CLOSE and general.brain.stage == GT.STRIKE)
	# 7. the taser opens him, the fist finishes the stun
	await _general_guarding(general, general.global_position - general.global_basis.z * 3.0)
	var stuns := [0]
	general.stunned.connect(func() -> void: stuns[0] += 1)
	_general_hit(general, &"armour", 8.0, true, DamageInfo.Kind.ELECTRIC)
	await _seconds(0.4)
	await _shot("stunned", _at(5.0, 4.0, 1.7), general.global_position + Vector3.UP * 1.5, stuns[0] == 1 and general.brain.state == GS.STUNNED)
	var finishes := [0]
	general.finished_off.connect(func() -> void: finishes[0] += 1)
	var before := general.health.current
	_general_hit(general, &"armour", 20.0, true, DamageInfo.Kind.BLUNT, true)
	await _seconds(0.3)
	await _shot("finisher", _at(5.0, 4.0, 1.7), general.global_position + Vector3.UP * 1.5, finishes[0] == 1 and general.health.current < before - 100.0 and general.brain.state == GS.REEL)
	# 8. phase 2: the leap onto the eave, the volley, the leap down
	await _general_guarding(general, _at(8.0, 0.0))
	_general_wound(general, 0.6)
	await _until(func() -> bool:
		_put_guard(_at(8.0, 0.0), general.global_position + Vector3.UP * 1.5)
		return general.brain.attack == GA.LEAP_UP and general.kinematic, 12.0)
	await _seconds(0.3)
	await _shot("leap_up", _at(10.0, 6.0, 2.0), general.global_position + Vector3.UP, general.brain.attack == GA.LEAP_UP and general.global_position.y > 0.5)
	await _until(func() -> bool:
		_put_guard(_at(8.0, 0.0), general.global_position + Vector3.UP * 1.5)
		return general.brain.attack == GA.VOLLEY and general.brain.stage == GT.TELEGRAPH and general.brain.stage_time() > 0.55, 6.0)
	await _shot("volley_draw", _at(8.0, 0.0, 1.6), general.global_position + Vector3.UP * 1.5, general.brain.on_roof and general.moves.pose.bow_drawn > 0.5 and general.volley_spots.size() == GeneralBrain.ARROWS[1])
	await _until(func() -> bool: return general.brain.stage == GT.STRIKE, 1.0)
	await _seconds(0.3)
	var arrow: GeneralArrow = general.arrows.back() as GeneralArrow if not general.arrows.is_empty() else null
	var flying := arrow != null and is_instance_valid(arrow) and not arrow.stuck
	await _shot("arrows_flight", _at(8.0, 4.0, 2.0), arrow.global_position if flying else _at(8.0, 0.0), flying)
	await _until(func() -> bool:
		_put_guard(_at(8.0, 0.0), general.global_position + Vector3.UP * 1.5)
		return general.brain.attack == GA.LEAP_DOWN and general.brain.stage == GT.TELEGRAPH and general.brain.stage_time() > 0.3, 14.0)
	await _shot("leap_down_mark", _at(8.0, 0.0, 1.6), general.landing, general.brain.attack == GA.LEAP_DOWN)
	await _until(func() -> bool: return general.brain.stage == GT.STRIKE, 2.0)
	await _shot("landing", _at(8.0, 4.0, 1.8), general.global_position + Vector3.UP, general.brain.attack == GA.LEAP_DOWN and not general.brain.on_roof)
	# 9. phase 3: the sword planted, the petals; the feint with the double
	await _general_guarding(general, _at(8.0, 0.0))
	general.brain.can_roof = false   # the roof was shown: straight to the petals
	_general_wound(general, 0.3)
	await _until(func() -> bool:
		_put_guard(_at(8.0, 0.0), general.global_position + Vector3.UP * 1.5)
		return general.brain.state == GS.TRANSFORM and general.brain.state_progress() > General.GUST_AT + 0.1, 8.0)
	await _shot("transform", _at(8.0, 4.0, 2.0), general.global_position + Vector3.UP * 1.5, general.storm != null and general.storm.falling and general.rig.tip_point().y < 0.4)
	await _general_guarding(general, _at(8.0, 0.0))
	general.brain.force_attack(GA.FEINT)
	await _until(func() -> bool: return general.brain.stage_time() > GeneralBrain.FEINT_APART + 0.15, 1.0)
	await _shot("feint_figures", _at(8.0, 0.0, 1.6), general.global_position + Vector3.UP * 1.5, general.phantom != null and general.phantom.visible and general.phantom.lane != null and general.dash_lane() != null and general.moves.glint > 0.3)
	await _until(func() -> bool: return general.phantom.burst, 1.5)
	await _shot("phantom_burst", _at(8.0, 0.0, 1.6), general.phantom.global_position + Vector3.UP, general.phantom.burst and not general.phantom.visible)
	# 10. his fall: he kneels, plants the sword, the armour comes apart
	await _general_guarding(general, _at(7.0, 0.0))
	var at := general.global_position
	_general_hit(general, &"back", general.health.current / General.BACK + 1.0, false)
	await _seconds(GeneralFall.TREMBLE + GeneralFall.KNEEL + 0.1)
	var falls := museum.floor_game.guardians.find_children("*", "GeneralFall", false, false)
	var kneeling := not falls.is_empty() and (falls[0] as GeneralFall)._rig.tip_point().y < at.y + 0.3
	await _shot("fall_kneel", at + Vector3(5.0, 1.8, 5.0), at + Vector3.UP, not is_instance_valid(general) and kneeling)
	await _seconds(GeneralFall.SHED_GAP * (GeneralFall.SHED_ORDER.size() + 3))
	var apart := not falls.is_empty() and (falls[0] as GeneralFall).pieces.size() >= 20
	await _shot("fallen", at + Vector3(5.0, 2.5, 5.0), at, apart and GameState.is_guardian_defeated(&"general"))


## Waits until he stands in his guard, the guard at [param at].
func _general_guarding(general: General, at: Vector3) -> void:
	await _until(func() -> bool:
		_put_guard(at, general.global_position + Vector3.UP * 1.5)
		return general.brain.state == GeneralBrain.State.GUARD, 10.0)


## A hit on [param zone] travelling from his front ([param from_front]) or
## from behind him.
func _general_hit(general: General, zone: StringName, amount: float, from_front: bool, kind: DamageInfo.Kind = DamageInfo.Kind.BALLISTIC, finish: bool = false) -> void:
	var info := DamageInfo.make(amount, kind, museum.player)
	info.weapon = &"fists" if finish else &"pistol"
	info.can_finish = finish
	info.direction = general.global_basis.z if from_front else -general.global_basis.z
	info.position = general.global_position + Vector3.UP * 2.0
	general.take_zone_damage(info, zone)


## Hits his back down to [param fraction] of his health.
func _general_wound(general: General, fraction: float) -> void:
	_general_hit(general, &"back", (general.health.current - general.max_health * fraction + 1.0) / General.BACK, false)


# --- any guardian -------------------------------------------------------------------

func _common_fight() -> void:
	_put_guard(_at(20.0, 0.0), _head())
	await _shot("dormant", _at(12.0, 3.0, 2.0), _head(), guardian.state == Guardian.State.DORMANT)
	var start := StringName("arena_%s_start" % String(guardian_id))
	var stand: Vector3 = (museum.floor_level.markers[start] as Transform3D).origin if museum.floor_level.markers.has(start) else _at(5.0, 0.0)
	_put_guard(stand, _head())
	await _seconds(1.0)
	await _shot("awake", _at(10.0, 3.0, 2.0), _head(), guardian.is_fighting())
	await _seconds(6.0)
	await _shot("fighting", _at(10.0, 6.0, 3.0), _head(), guardian.is_fighting())
	var info := DamageInfo.make(guardian.health.current + 1.0, DamageInfo.Kind.BALLISTIC, museum.player)
	guardian.take_damage(info)
	await _seconds(2.0)
	await _shot("fallen", _at(10.0, 6.0, 3.0), _head(), GameState.is_guardian_defeated(guardian_id))


# --- staging --------------------------------------------------------------------------

## A point [param ahead] m in front of the guardian's post, [param aside]
## m to its left, [param up] m up.
func _at(ahead: float, aside: float, up: float = 0.0) -> Vector3:
	var home := guardian.home
	return home.origin - home.basis.z * ahead - home.basis.x * aside + Vector3.UP * up


func _head() -> Vector3:
	return _at(0.0, 0.0, 6.5)


## The guard stands at [param at] looking at [param look].
func _put_guard(at: Vector3, look: Vector3) -> void:
	var guard := museum.player
	guard.global_position = at + Vector3.UP * 0.05
	guard.velocity = Vector3.ZERO
	guard.heal(1000000.0)
	var eye := at + Vector3.UP * guard.eye_height
	var aim := look - eye
	guard.head.rotation = Vector3(atan2(aim.y, Vector2(aim.x, aim.z).length()), atan2(-aim.x, -aim.z), 0.0)


## A moment: logged, checked ([param ok]), and in --shots a screenshot from
## [param from] looking at [param at].
func _shot(label: String, from: Vector3, at: Vector3, ok: bool) -> void:
	var entry := {"moment": label, "ok": ok, "guard_health": museum.player.health.current}
	if is_instance_valid(guardian):
		entry["health"] = guardian.health.current
		entry["phase"] = guardian.phase
		if guardian is Colossus:
			var colossus := guardian as Colossus
			entry["state"] = ColossusBrain.State.keys()[colossus.brain.state]
			entry["attack"] = ColossusBrain.Attack.keys()[colossus.brain.attack]
			entry["standing"] = colossus.standing
		elif guardian is Centaur:
			var centaur := guardian as Centaur
			entry["state"] = CentaurBrain.State.keys()[centaur.brain.state]
			entry["attack"] = CentaurBrain.Attack.keys()[centaur.brain.attack]
			entry["speed"] = snappedf(centaur.gait.speed, 0.1)
		elif guardian is Planetarium:
			var orrery := guardian as Planetarium
			entry["state"] = OrreryBrain.State.keys()[orrery.brain.state]
			entry["attack"] = OrreryBrain.Attack.keys()[orrery.brain.attack]
			entry["planets_left"] = orrery.brain.planets_left()
			entry["exposed"] = orrery.brain.exposed
		elif guardian is Lamassu:
			var lamassu := guardian as Lamassu
			entry["state"] = LamassuBrain.State.keys()[lamassu.brain.state]
			entry["attack"] = LamassuBrain.Attack.keys()[lamassu.brain.attack]
			entry["speed"] = snappedf(lamassu.gait.speed, 0.1)
			entry["cracked"] = lamassu.rig.cracked
		elif guardian is General:
			var general := guardian as General
			entry["state"] = GeneralBrain.State.keys()[general.brain.state]
			entry["attack"] = GeneralBrain.Attack.keys()[general.brain.attack]
			entry["on_roof"] = general.brain.on_roof
		elif guardian is Serpent:
			var serpent := guardian as Serpent
			entry["state"] = SerpentBrain.State.keys()[serpent.brain.state]
			entry["attack"] = SerpentBrain.Attack.keys()[serpent.brain.attack]
			entry["lead"] = SerpentBody.End.keys()[serpent.brain.lead]
			entry["spitter"] = SerpentBody.End.keys()[serpent.brain.spitter]
			entry["plates_left"] = serpent.rig.plates_left()
	_log.append(entry)
	if not ok:
		_missed += 1
		print("MISSED: %s %s" % [label, str(entry)])
	else:
		print("%s: %s %s" % ["dry" if _dry else "shot", label, str(entry)])
	if _dry:
		_check_framing(label, from, at)
		return
	camera.global_position = from
	camera.look_at(at, Vector3.UP)
	camera.reset_physics_interpolation()
	camera.current = true
	museum.hud.visible = false
	museum.player.weapons.visible = false   # (his first-person gun would float in this camera's view)
	await _frames(3)
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	image.save_png(_out.path_join("%s.png" % label))
	museum.hud.visible = true
	museum.player.weapons.visible = true
	museum.player.camera.current = true


## A dry run's look through the moment's camera (the tour's check): inside a
## room, out of the walls, its subject in sight - a FRAMING line otherwise
## (the shot would miss it).
func _check_framing(label: String, from: Vector3, at: Vector3) -> void:
	var problems: Array[String] = []
	if museum.floor_level.room_at(from) == &"":
		problems.append("camera outside every room")
	var space := get_viewport().find_world_3d().direct_space_state
	var point := PhysicsPointQueryParameters3D.new()
	point.position = from
	point.collision_mask = Layers.WORLD
	if not space.intersect_point(point).is_empty():
		problems.append("camera inside a wall")
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, at, Layers.WORLD))
	var clear := from.distance_to(at) if hit.is_empty() else from.distance_to(hit["position"])
	if clear < minf(3.0, from.distance_to(at) * 0.5):
		problems.append("subject hidden %.1f m ahead" % clear)
	if not problems.is_empty():
		print("FRAMING: %s: %s" % [label, "; ".join(problems)])


func _until(condition: Callable, limit: float) -> void:
	var left := limit
	while left > 0.0 and not condition.call():
		museum.player.heal(1000000.0)
		await get_tree().physics_frame
		left -= 1.0 / Engine.physics_ticks_per_second


func _seconds(time: float) -> void:
	for i in roundi(time * Engine.physics_ticks_per_second):
		if is_instance_valid(museum):
			museum.player.heal(1000000.0)
		await get_tree().physics_frame


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


# --- the Lamassu ----------------------------------------------------------------------

const LA := LamassuBrain.Attack
const LS := LamassuBrain.State
const LTELL := LamassuBrain.Stage.TELEGRAPH
const LHIT := LamassuBrain.Stage.STRIKE


func _lamassu_fight(lamassu: Lamassu) -> void:
	var post := lamassu.home.origin
	var face := lamassu.home.origin + Vector3.UP * 3.0
	var side_view := _at(3.0, 9.0, 2.4)
	# 1. the museum piece on its plinth
	_put_guard(_at(20.0, 0.0), face)
	await _shot("dormant", _at(9.0, 4.0, 2.0), face, lamassu.state == Guardian.State.DORMANT and lamassu.global_position.y > 0.3)
	# 2. the guard crosses the start line: dust, the eyes, the wings creak open
	var start: Vector3 = (museum.floor_level.markers[&"arena_lamassu_start"] as Transform3D).origin
	_put_guard(start, face)
	await _until(func() -> bool: return lamassu.brain.state == LS.WAKING and lamassu.brain.state_progress() > 0.22, 3.0)
	await _shot("waking", _at(7.0, 3.0, 2.2), face, lamassu.brain.state == LS.WAKING and lamassu.moves.pose.wing_spread[0] > 0.2)
	# 3. it walks down off the plinth: the first hoof on the court's floor
	await _until(func() -> bool: return lamassu.brain.state != LS.WAKING or _hoof_on_floor(lamassu), 3.0)
	await _shot("stepping_down", side_view, lamassu.global_position + Vector3.UP * 1.5, lamassu.brain.state == LS.WAKING and _hoof_on_floor(lamassu))
	await _until(func() -> bool: return lamassu.brain.state == LS.IDLE, 3.0)
	# 4. it stalks the guard at a walk
	var far := _at(17.0, 0.0)
	await _until(func() -> bool:
		_put_guard(far, lamassu.global_position + Vector3.UP * 2.0)
		return lamassu.gait.speed > 1.0 and lamassu.gait.mode == LamassuGait.Mode.WALK, 6.0)
	await _shot("stalking", far + Vector3(4.0, 1.7, 0.0), lamassu.global_position + Vector3.UP * 1.8, lamassu.gait.speed > 1.0 and lamassu.gait.mode == LamassuGait.Mode.WALK)
	# 5. the charge: the head drops, the hoof paws, the lane; the run
	var open := _at(12.0, 0.0)
	await _lamassu_idle(lamassu, open)
	lamassu.brain.force_attack(LA.CHARGE)
	await _until(func() -> bool: return lamassu.moves.pawing, 1.0)
	await _shot("charge_paw", lamassu.global_position - lamassu.global_basis.z * 5.0 + lamassu.global_basis.x * 3.0 + Vector3.UP * 1.4,
			lamassu.global_position + Vector3.UP * 1.2, lamassu.brain.attack == LA.CHARGE and lamassu.brain.stage == LTELL)
	await _until(func() -> bool: return lamassu.brain.stage == LHIT, 1.5)
	_put_guard(open + Vector3(4.0, 0.0, 0.0), lamassu.global_position + Vector3.UP * 1.5)
	await _until(func() -> bool: return lamassu.gait.speed > 8.0 or lamassu.brain.attack != LA.CHARGE, 1.5)
	await _shot("charge_run", open + Vector3(4.0, 1.6, 0.0), lamassu.global_position + Vector3.UP * 1.4, lamassu.brain.attack == LA.CHARGE and lamassu.gait.speed > 8.0)
	# 6. a charge into a genius's base: the crash, the stun with the face low
	var genius := Vector3(-87.0, 0.0, -71.0)
	var hiding := genius + Vector3(-2.6, 0.0, 0.0)
	await _lamassu_idle(lamassu, hiding)
	_lamassu_place(lamassu, Vector3(-76.0, 0.0, -71.0), PI * 0.5)
	lamassu.brain.force_attack(LA.CHARGE)
	await _until(func() -> bool:
		_put_guard(hiding, lamassu.global_position + Vector3.UP * 1.5)
		return lamassu.brain.state == LS.STUNNED, 4.5)
	await _shot("charge_crash", genius + Vector3(2.0, 2.0, 6.0), genius + Vector3(1.5, 1.5, 0.0), lamassu.brain.state == LS.STUNNED)
	await _seconds(0.5)
	await _shot("stunned", genius + Vector3(3.0, 1.7, 3.5), lamassu.rig.face_point(), lamassu.brain.state == LS.STUNNED and lamassu.rig.face_point().y < 2.4)
	# 7. a charge at a wall: it sees it and skids to a stop short of it
	var wallward := Vector3(-92.5, 0.0, -66.5)
	await _lamassu_idle(lamassu, wallward)
	_lamassu_place(lamassu, Vector3(-70.0, 0.0, -66.5), PI * 0.5)
	lamassu.brain.force_attack(LA.CHARGE)
	await _until(func() -> bool:
		_put_guard(wallward if lamassu.brain.stage == LTELL else wallward + Vector3(0.0, 0.0, 5.0), lamassu.global_position + Vector3.UP * 1.5)
		return lamassu.brain.attack == LA.CHARGE and lamassu.brain.stage == LamassuBrain.Stage.RECOVER, 5.0)
	await _seconds(0.15)
	await _shot("charge_skid", Vector3(-88.0, 1.8, -60.0), lamassu.global_position + Vector3.UP * 1.2,
			lamassu.brain.attack == LA.CHARGE and lamassu.brain.stage == LamassuBrain.Stage.RECOVER and lamassu.gait.speed > 2.0)
	await _until(func() -> bool: return lamassu.brain.attack != LA.CHARGE, 2.0)
	await _shot("stopped_short", Vector3(-88.0, 1.8, -60.0), lamassu.global_position + Vector3.UP * 1.2, lamassu.brain.state != LS.STUNNED and lamassu.global_position.x > -93.7)
	# 8. the wing gust: the wings rise, the cone; the beat throws the guard
	var breeze := Vector3(-78.75, 0.0, -59.5)
	await _lamassu_idle(lamassu, breeze)
	_lamassu_place(lamassu, Vector3(-78.75, 0.0, -66.5), PI)
	lamassu.brain.force_attack(LA.GUST)
	await _seconds(LamassuBrain.stage_length(LA.GUST, LTELL, lamassu.brain.phase) * 0.9)
	await _shot("gust_raise", breeze + Vector3(5.0, 1.8, 2.0), lamassu.global_position + Vector3.UP * 2.6, lamassu.brain.attack == LA.GUST and lamassu.rig.wing_end(0).y > 3.5)
	await _until(func() -> bool: return lamassu.brain.stage == LHIT, 1.0)
	await _seconds(0.35)
	var thrown := Vector2(museum.player.global_position.x - breeze.x, museum.player.global_position.z - breeze.z).length()
	await _shot("gust_blow", breeze + Vector3(6.0, 1.8, 6.0), museum.player.global_position + Vector3.UP, thrown > 2.0)
	# 9. the stomp: it rears, the hooves come down, the ring
	var near := Vector3(-78.75, 0.0, -61.5)
	await _lamassu_idle(lamassu, near)
	_lamassu_place(lamassu, Vector3(-78.75, 0.0, -66.5), PI)
	lamassu.brain.force_attack(LA.STOMP)
	await _seconds(LamassuBrain.stage_length(LA.STOMP, LTELL, lamassu.brain.phase) * 0.6)
	await _shot("stomp_rear", near + Vector3(6.0, 1.8, 0.0), lamassu.global_position + Vector3.UP * 2.0, -lamassu.rig.part("body").global_basis.z.y > 0.4)
	await _until(func() -> bool: return lamassu.brain.stage == LHIT, 1.0)
	await _seconds(0.05)
	var rings := museum.floor_game.guardians.find_children("*", "ShockwaveRing", true, false)
	await _shot("stomp_land", near + Vector3(6.0, 1.5, 0.0), lamassu.global_position - lamassu.global_basis.z * 1.6,
			lamassu.brain.attack == LA.STOMP and lamassu.brain.stage == LHIT and not rings.is_empty())
	# 10. phase 2: it rears and bellows, the cracks blaze, the warriors step off the walls
	await _lamassu_idle(lamassu, open)
	var before := museum.exhibits().size()
	_lamassu_wound(lamassu, 0.6)
	await _until(func() -> bool: return lamassu.brain.state == LS.PHASE_SHIFT and lamassu.brain.state_progress() > 0.5, 6.0)
	await _shot("phase_shift_2", open + Vector3(5.0, 2.0, 4.0), lamassu.global_position + Vector3.UP * 2.5, lamassu.brain.state == LS.PHASE_SHIFT and lamassu.rig.cracked)
	var warriors := museum.exhibits().slice(before)
	var warrior: Node3D = warriors[0] if not warriors.is_empty() else null
	await _shot("relief_warriors", open + Vector3(0.0, 1.7, 0.0), warrior.global_position + Vector3.UP if warrior != null else face, warriors.size() >= 6)
	# 11. phase 3: three wing beats lift it off the floor
	await _lamassu_idle(lamassu, open)
	for node in warriors:
		if is_instance_valid(node):
			node.queue_free()
	_lamassu_wound(lamassu, 0.3)
	await _until(func() -> bool: return lamassu.brain.state == LS.PHASE_SHIFT and lamassu.brain.shift_phase == 3 and lamassu.moves.hover > 0.5, 6.0)
	await _shot("phase_shift_3", open + Vector3(6.0, 1.8, 3.0), lamassu.global_position + Vector3.UP * 2.0, lamassu.brain.state == LS.PHASE_SHIFT and lamassu.global_position.y > 0.3)
	# 12. the hop: the shadow where the guard stands (far enough down the
	# court for a leap), the flight, the landing
	var mark := _at(17.0, 0.0)
	await _lamassu_idle(lamassu, mark)
	lamassu.brain.force_attack(LA.HOP)
	await _seconds(0.1)
	var marks := museum.floor_game.guardians.find_children("*", "GroundMark", true, false)
	await _shot("hop_shadow", mark + Vector3(4.0, 1.7, 4.0), lamassu.hop_to, lamassu.brain.attack == LA.HOP and not marks.is_empty()
			and Vector2(lamassu.hop_to.x - mark.x, lamassu.hop_to.z - mark.z).length() < 1.5)
	await _until(func() -> bool: return lamassu.global_position.y > 1.0 or lamassu.brain.attack != LA.HOP, 1.5)
	await _shot("hop_flight", mark + Vector3(7.0, 2.0, 5.0), lamassu.global_position + Vector3.UP * 1.5, lamassu.brain.attack == LA.HOP and lamassu.global_position.y > 1.0)
	await _until(func() -> bool: return lamassu.brain.stage == LHIT or lamassu.brain.attack != LA.HOP, 1.5)
	await _shot("hop_land", mark + Vector3(6.0, 1.6, 4.0), lamassu.global_position + Vector3.UP,
			lamassu.brain.attack == LA.HOP and Vector2(lamassu.global_position.x - lamassu.hop_to.x, lamassu.global_position.z - lamassu.hop_to.z).length() < 1.0)
	# 13. its fall: it kneels, the wings break off, it breaks into alabaster
	await _lamassu_idle(lamassu, open)
	var at := lamassu.global_position
	var info := DamageInfo.make(lamassu.health.current + 1.0, DamageInfo.Kind.BALLISTIC, museum.player)
	lamassu.take_zone_damage(info, &"face")
	await _seconds(LamassuFall.TREMBLE + LamassuFall.KNEEL * 0.65)
	var falls := museum.floor_game.guardians.find_children("*", "LamassuFall", false, false)
	var kneeling := not falls.is_empty() and (falls[0] as LamassuFall).wings.size() == 4
	await _shot("fall_kneel", at + Vector3(6.0, 1.8, 5.0), at + Vector3.UP * 1.5, not is_instance_valid(lamassu) and kneeling)
	await _seconds(LamassuFall.KNEEL * 0.35 + 0.4)
	var broke := not falls.is_empty() and (falls[0] as LamassuFall).pieces.size() > 15
	await _shot("fallen", at + Vector3(6.0, 2.5, 5.0), at, broke and GameState.is_guardian_defeated(&"lamassu"))


func _hoof_on_floor(lamassu: Lamassu) -> bool:
	for leg in 4:
		if lamassu.gait.planted(leg) and lamassu.rig.contact(leg).y < 0.1:
			return true
	return false


func _lamassu_idle(lamassu: Lamassu, guard: Vector3) -> void:
	await _until(func() -> bool:
		_put_guard(guard, lamassu.global_position + Vector3.UP * 1.5)
		return lamassu.brain.state == LS.IDLE, 10.0)


func _lamassu_place(lamassu: Lamassu, at: Vector3, yaw: float) -> void:
	lamassu.global_position = at
	lamassu.rotation.y = yaw
	lamassu.speed = 0.0
	lamassu.velocity = Vector3.ZERO
	lamassu.reset_physics_interpolation()
	lamassu.gait.place(lamassu.global_transform)


## The guard hits it through its face down to [param fraction] of its health.
func _lamassu_wound(lamassu: Lamassu, fraction: float) -> void:
	var amount := (lamassu.health.current - lamassu.max_health * fraction + 1.0) / Lamassu.FACE
	var info := DamageInfo.make(amount, DamageInfo.Kind.BALLISTIC, museum.player)
	info.position = lamassu.rig.face_point()
	lamassu.take_zone_damage(info, &"face")
