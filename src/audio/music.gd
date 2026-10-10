extends Node
## Adaptive music (autoload "Music") on the Music bus. A MusicDirector
## decides the state from the scene kind and the game's events; this node
## plays it: every layer is an AudioStreamPlayer that fades toward its
## target with an equal-power curve. Stems of one family (explore +
## explore_tension, combat + combat_hi, boss + boss_hi) start together and
## stay in sync; the exploration family resumes where it stopped.
## Tracks and stings: Ogg Vorbis rendered by tools/music/gen_music.py
## (tools/build_audio.sh: render, encode, import, seam check).
## - Scene swaps (SceneTree.scene_changed): main menu and end screen play
##   the menu theme, a scene with the guard plays the night, anything
##   else is silent. The old music crossfades out.
## - Game music pauses with the game (the players are pausable); the menu
##   theme and the logic run while paused, but combat timers freeze.
## - Events: hits, kills and wounds heat the fight; awake exhibits near
##   the listener (polled from group "enemies") mean tension; the T-Rex
##   brings the boss track, its fall the victory sting; the guard's death
##   plays the death sting and silences the night.
## - The night in the lobby (Events.night_started, objective_changed,
##   power_cut, witching_hour, dawn_broke) feeds director.night (a
##   NightMood; see MusicDirector for what it changes). The power cut drops
##   the night music within HUSH_FADE s, dawn fades everything out over
##   DAWN_FADE s. A scene swap keeps the mood only for the museum that has
##   just announced it.
## - Floor I: Events.room_entered moves the walk to the zone's wing (a
##   family per wing, explore_<wing> + explore_<wing>_tension: the old
##   wing crossfades into the new over CROSSFADE s, and every walk resumes
##   where it stopped, so coming back to a zone never restarts it). A wing
##   guardian (Events.guardian_awakened / guardian_defeated) plays the
##   guardians' theme in its wing (guardian_<wing> + guardian_<wing>_hi),
##   its fall the guardian sting. Seals, shards, gates and a newly found
##   wing lay a short sting (OVERLAYS) over the music, which ducks by
##   DUCK_DB under it.
## Automation is off in test runs (enabled = false); set_scene_kind()
## drives it by hand.

signal state_changed(state: MusicDirector.State)

const DIR := "res://assets/music/"
const BUS := &"Music"
## Family -> its tracks (all the same length, started together). The
## wings' families play a logical layer (MusicDirector.LAYERS) in a wing's
## colours: track().
const FAMILIES := {
	&"menu": [&"menu"],
	&"explore": [&"explore", &"explore_tension"],
	&"combat": [&"combat", &"combat_hi"],
	&"boss": [&"boss", &"boss_hi"],
	&"explore_egypt": [&"explore_egypt", &"explore_egypt_tension"],
	&"explore_assyria": [&"explore_assyria", &"explore_assyria_tension"],
	&"explore_greece": [&"explore_greece", &"explore_greece_tension"],
	&"explore_enlightenment": [&"explore_enlightenment", &"explore_enlightenment_tension"],
	&"explore_asia": [&"explore_asia", &"explore_asia_tension"],
	&"explore_americas": [&"explore_americas", &"explore_americas_tension"],
	&"guardian_egypt": [&"guardian_egypt", &"guardian_egypt_hi"],
	&"guardian_assyria": [&"guardian_assyria", &"guardian_assyria_hi"],
	&"guardian_greece": [&"guardian_greece", &"guardian_greece_hi"],
	&"guardian_enlightenment": [&"guardian_enlightenment", &"guardian_enlightenment_hi"],
	&"guardian_asia": [&"guardian_asia", &"guardian_asia_hi"],
	&"guardian_americas": [&"guardian_americas", &"guardian_americas_hi"],
}
## Stings that own the music (a state's), and stings laid over it.
const STINGS: Array[StringName] = [&"victory_sting", &"death_sting", &"guardian_sting", &"seal_sting", &"gate_sting",
	&"wing_sting_egypt", &"wing_sting_assyria", &"wing_sting_greece", &"wing_sting_enlightenment", &"wing_sting_asia",
	&"wing_sting_americas"]
const OVERLAYS: Array[StringName] = [&"seal_sting", &"gate_sting", &"wing_sting_egypt", &"wing_sting_assyria",
	&"wing_sting_greece", &"wing_sting_enlightenment", &"wing_sting_asia", &"wing_sting_americas"]
## Seconds to fade a layer fully in / out (per logical layer).
const FADE_IN := {&"menu": 2.5, &"explore": 3.0, &"explore_tension": 2.5, &"combat": 0.35, &"combat_hi": 1.5,
	&"boss": 0.5, &"boss_hi": 2.0, &"guardian": 0.5, &"guardian_hi": 2.0}
const FADE_OUT := {&"menu": 1.5, &"explore": 1.2, &"explore_tension": 5.0, &"combat": 4.0, &"combat_hi": 3.0,
	&"boss": 3.0, &"boss_hi": 3.0, &"guardian": 3.0, &"guardian_hi": 3.0}
## Seconds one wing's walk takes to hand over to another's (both ways).
const CROSSFADE := 3.5
## Music under an overlay sting: this much quieter, reached in DUCK_ATTACK
## s, back over DUCK_RELEASE s once the sting has DUCK_TAIL s left.
const DUCK_DB := -8.0
const DUCK_ATTACK := 0.25
const DUCK_RELEASE := 1.5
const DUCK_TAIL := 1.2
## The same overlay again within this many seconds is skipped (a seal
## and its shard picked up together).
const OVERLAY_REPEAT := 2.0
## Fade-out when the guard falls (the death sting takes over).
const DEATH_FADE := 1.0
## Fade-out into the power cut's hush, and of everything at dawn.
const HUSH_FADE := 0.5
const DAWN_FADE := 4.0
## Awake exhibits within THREAT_RADIUS m of the listener mean tension;
## within ENGAGE_RADIUS m (or attacking) a fight.
const THREAT_RADIUS := 30.0
const ENGAGE_RADIUS := 9.0
const SCAN_INTERVAL := 0.25
const SILENT_DB := -80.0
## How often the stems of a playing family are checked against each other,
## and how far apart (s) they may drift before they are pulled together.
const SYNC_INTERVAL := 1.0
const SYNC_TOLERANCE := 0.004

var director := MusicDirector.new()
## False in test runs: scene changes and events are ignored until a test
## switches it on or calls set_scene_kind().
var enabled: bool = true
## Layer -> AudioStreamPlayer.
var players: Dictionary = {}
## Sting -> AudioStreamPlayer.
var stings: Dictionary = {}
## Layer -> fade position 0..1 (volume = sin(level * PI / 2)).
var levels: Dictionary = {}
## 0..1: how far the music is ducked under an overlay sting.
var duck: float = 0.0

var _positions: Dictionary = {}
var _scan: float = 0.0
var _sync_timer: float = SYNC_INTERVAL
var _nearby: int = 0
var _engaged: int = 0
var _sheltered: bool = false
var _boss: Node = null
var _guardian: Node = null
var _quitting: bool = false
## Seconds the playing overlay sting still holds the duck.
var _overlay_left: float = 0.0
## Overlays waiting for a state's sting to end.
var _queued: Array[StringName] = []
## Overlay -> Time.get_ticks_msec() when it last started.
var _overlay_started: Dictionary = {}
## Process frame of the last Events.room_entered (a scene swap keeps the
## zone only when it was announced while the scene set up).
var _zone_frame: int = -100


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	enabled = AudioContext.automatic()
	for family: StringName in FAMILIES:
		for layer: StringName in FAMILIES[family]:
			players[layer] = _make_player(String(layer), family == &"menu")
			levels[layer] = 0.0
	for sting in STINGS:
		stings[sting] = _make_player(String(sting), false)
	director.state_changed.connect(_on_state_changed)
	Events.hit_landed.connect(_on_hit_landed)
	Events.enemy_destroyed.connect(_on_enemy_destroyed)
	Events.player_damaged.connect(_on_player_damaged)
	Events.player_died.connect(_on_player_died)
	Events.weapon_fired.connect(_on_weapon_fired)
	Events.boss_awakened.connect(_on_boss_awakened)
	Events.boss_defeated.connect(_on_boss_defeated)
	Events.night_started.connect(_on_night_started)
	Events.objective_changed.connect(_on_objective_changed)
	Events.power_cut.connect(_on_power_cut)
	Events.witching_hour.connect(_on_witching_hour)
	Events.dawn_broke.connect(_on_dawn_broke)
	Events.room_entered.connect(_on_room_entered)
	Events.guardian_awakened.connect(_on_guardian_awakened)
	Events.guardian_defeated.connect(_on_guardian_defeated)
	Events.seal_collected.connect(_on_seal_collected)
	Events.shard_collected.connect(_on_shard_collected)
	Events.gate_opened.connect(_on_gate_opened)
	get_tree().scene_changed.connect(_on_scene_changed)
	if Sfx.has_signal(&"quitting"):
		Sfx.connect(&"quitting", _on_quitting)
	_on_scene_changed.call_deferred()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		stop_all()


func state() -> MusicDirector.State:
	return director.state


## Drives the director with a scene kind (AudioContext.MENU, GAME, END,
## OFF) - what a scene swap does when automation is on.
func set_scene_kind(kind: StringName) -> void:
	for family: StringName in FAMILIES:
		if String(family).begins_with("explore"):
			_positions.erase(family)   # a new night starts its walks from the top
	director.set_mode(kind)


## The track of [param layer] (a MusicDirector.LAYERS name) in
## [param wing]'s colours (&"" = the lobby's own track).
static func track(layer: StringName, wing: StringName) -> StringName:
	if wing == &"":
		return layer
	match layer:
		&"explore":
			return StringName("explore_" + String(wing))
		&"explore_tension":
			return StringName("explore_%s_tension" % wing)
		&"guardian":
			return StringName("guardian_" + String(wing))
		&"guardian_hi":
			return StringName("guardian_%s_hi" % wing)
	return layer


## The logical layer a track plays (&"explore_egypt_tension" ->
## &"explore_tension").
static func layer_of(track_name: StringName) -> StringName:
	var text := String(track_name)
	if text.begins_with("explore"):
		return &"explore_tension" if text.ends_with("_tension") else &"explore"
	if text.begins_with("guardian"):
		return &"guardian_hi" if text.ends_with("_hi") else &"guardian"
	return track_name


## The track that plays [param layer] right now: the walk in the zone's
## wing, the guardians' theme in the guardian's wing (a missing file falls
## back on the lobby's walk, a guardian on the T-Rex's track).
func playing_track(layer: StringName) -> StringName:
	var wing: StringName = &""
	if MusicDirector.WALK_LAYERS.has(layer):
		wing = director.variant
	elif MusicDirector.GUARDIAN_LAYERS.has(layer):
		wing = director.guardian_wing
	var name := track(layer, wing)
	if _has_stream(name):
		return name
	if layer == &"guardian":
		return &"boss"
	if layer == &"guardian_hi":
		return &"boss_hi"
	return layer


## Target level of every track now (the director's logical targets mapped
## onto the tracks that play them).
func track_targets() -> Dictionary:
	var logical := director.layer_targets()
	var targets := {}
	for name: StringName in players:
		targets[name] = 0.0
	for layer: StringName in logical:
		var level: float = logical[layer]
		if level > 0.0:
			var name := playing_track(layer)
			targets[name] = maxf(float(targets.get(name, 0.0)), level)
	return targets


## Lays [param sting] (one of OVERLAYS) over the music, which ducks under
## it; waits while a state's sting (victory, a guardian's fall, death)
## plays. Returns false when it is not played (no game, the guard down,
## the same sting just now, no file).
func play_overlay(sting: StringName) -> bool:
	if not stings.has(sting) or (stings[sting] as AudioStreamPlayer).stream == null or _quitting:
		return false
	if director.mode != AudioContext.GAME or director.dead or director.state == MusicDirector.State.SILENT:
		return false
	var now := Time.get_ticks_msec()
	if now - int(_overlay_started.get(sting, -100000)) < int(OVERLAY_REPEAT * 1000.0) or _queued.has(sting):
		return false
	if _state_sting_playing():
		_queued.append(sting)
		return true
	_start_overlay(sting)
	return true


func _start_overlay(sting: StringName) -> void:
	var player := stings[sting] as AudioStreamPlayer
	_overlay_started[sting] = Time.get_ticks_msec()
	player.volume_db = 0.0
	player.play()
	_overlay_left = maxf(_overlay_left, player.stream.get_length() - DUCK_TAIL)


func _state_sting_playing() -> bool:
	for sting: StringName in stings:
		if not OVERLAYS.has(sting) and (stings[sting] as AudioStreamPlayer).playing:
			return true
	return false


## The duck in dB right now (0 when no overlay plays).
func duck_db() -> float:
	return DUCK_DB * duck


## Forces a state (a cutscene, a scripted scare) until release().
func hold(forced: MusicDirector.State) -> void:
	director.hold(forced)


func release() -> void:
	director.release()


## Stops every player at once (quitting, tests).
func stop_all() -> void:
	for layer: StringName in players:
		(players[layer] as AudioStreamPlayer).stop()
		levels[layer] = 0.0
	for sting: StringName in stings:
		(stings[sting] as AudioStreamPlayer).stop()
	_positions.clear()
	_queued.clear()
	_overlay_left = 0.0
	duck = 0.0


## Sets the silence right away (no fades) and forgets the scene, its
## night, its zone and the wings met.
func reset() -> void:
	stop_all()
	director.release()
	director.night.reset()
	director.forget_zone()
	director.known_wings.clear()
	director.set_mode(AudioContext.OFF)
	_overlay_started.clear()
	_boss = null
	_guardian = null


func _process(delta: float) -> void:
	if _quitting:
		return
	var frozen := get_tree().paused and director.mode == AudioContext.GAME
	if not frozen:
		_scan -= delta
		if _scan <= 0.0:
			_scan = SCAN_INTERVAL
			_look_around()
		director.update(delta, _nearby, _engaged, _sheltered)
		_sync_timer -= delta
		if _sync_timer <= 0.0:
			_sync_timer = SYNC_INTERVAL
			resync()
	advance(delta, frozen)


## Stems start with separate play() calls in one frame; should the audio
## thread mix between two of them, a family would run a buffer apart. This
## pulls every stem of a playing family onto its first one (positions are
## compared around the loop). The mixer runs on its own thread: when the
## lead has moved on while a stem was read, the pair was read across a mix
## and is read again (and left for the next check should that happen
## twice). Returns how many stems were moved.
func resync() -> int:
	var moved := 0
	for family: StringName in FAMILIES:
		var layers: Array = FAMILIES[family]
		var lead := players[layers[0]] as AudioStreamPlayer
		if layers.size() < 2 or not lead.playing or lead.stream_paused or lead.stream == null:
			continue
		var length := lead.stream.get_length()
		for i in range(1, layers.size()):
			var other := players[layers[i]] as AudioStreamPlayer
			if not other.playing:
				continue
			var at := lead.get_playback_position()
			var there := other.get_playback_position()
			if lead.get_playback_position() != at:   # a mix came between the reads: once more
				at = lead.get_playback_position()
				there = other.get_playback_position()
				if lead.get_playback_position() != at:
					continue
			var apart := fposmod(there - at + length * 0.5, length) - length * 0.5
			if absf(apart) > SYNC_TOLERANCE:
				other.seek(at)
				moved += 1
	return moved


## Moves every track toward its target and starts / stops families; a
## logical layer that stays wanted while its wing changes crossfades its
## tracks over CROSSFADE s. Overlay stings duck the music.
## [param frozen]: the game is paused; its (paused) layers keep their level.
func advance(delta: float, frozen: bool = false) -> void:
	var targets := track_targets()
	var logical := director.layer_targets()
	var fade_away := fade_out_time()
	if not frozen:
		_overlay_left = maxf(_overlay_left - delta, 0.0)
		if not _queued.is_empty() and not _state_sting_playing():
			_start_overlay(_queued.pop_front())
		if _overlay_left > 0.0:
			duck = minf(duck + delta / DUCK_ATTACK, 1.0)
		else:
			duck = maxf(duck - delta / DUCK_RELEASE, 0.0)
	var ducked := duck_db()
	# logical layers handing over from one wing's track to another's
	var busy := {}
	for name: StringName in players:
		if float(targets[name]) > 0.0 or float(levels[name]) > 0.0:
			busy[layer_of(name)] = int(busy.get(layer_of(name), 0)) + 1
	for family: StringName in FAMILIES:
		var layers: Array = FAMILIES[family]
		if frozen and family != &"menu":
			continue
		var wanted := false
		var audible := false
		for layer: StringName in layers:
			var kind := layer_of(layer)
			var swap := int(busy.get(kind, 0)) > 1 and float(logical.get(kind, 0.0)) > 0.0
			var target: float = targets[layer]
			var level: float = levels[layer]
			if target > level:
				level = minf(target, level + delta / (CROSSFADE if swap else float(FADE_IN[kind])))
			elif target < level:
				var away := CROSSFADE if swap else float(FADE_OUT[kind])
				level = maxf(target, level - delta / (fade_away if fade_away > 0.0 else away))
			levels[layer] = level
			wanted = wanted or target > 0.0
			audible = audible or level > 0.0
			var player := players[layer] as AudioStreamPlayer
			var level_db := volume_db(level) + (ducked if level > 0.0 and family != &"menu" else 0.0)
			if player.volume_db != level_db:
				player.volume_db = level_db
		var first := players[layers[0]] as AudioStreamPlayer
		if wanted and not first.playing and first.stream != null:
			_start_family(family)
		elif not wanted and not audible and first.playing:
			_stop_family(family)


## Seconds every layer takes to fade out right now, whatever its own
## FADE_OUT: the guard fell (DEATH_FADE), dawn (DAWN_FADE), the power cut's
## hush (HUSH_FADE); 0 = each layer's own.
func fade_out_time() -> float:
	if director.dead:
		return DEATH_FADE
	if director.night.dawn:
		return DAWN_FADE
	if director.hushed():
		return HUSH_FADE
	return 0.0


## Equal-power fade curve in dB (SILENT_DB at 0).
static func volume_db(level: float) -> float:
	if level <= 0.0:
		return SILENT_DB
	return maxf(linear_to_db(sin(clampf(level, 0.0, 1.0) * PI * 0.5)), SILENT_DB)


func is_family_playing(family: StringName) -> bool:
	return (players[FAMILIES[family][0]] as AudioStreamPlayer).playing


func _make_player(file: String, always: bool) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = file
	player.bus = BUS
	player.volume_db = SILENT_DB
	var path := DIR + file + ".ogg"
	if ResourceLoader.exists(path):
		player.stream = load(path)
	# game music pauses with the game; the menu theme plays on
	player.process_mode = Node.PROCESS_MODE_ALWAYS if always else Node.PROCESS_MODE_PAUSABLE
	add_child(player)
	return player


func _start_family(family: StringName) -> void:
	var from: float = _positions.get(family, 0.0)
	for layer: StringName in FAMILIES[family]:
		var player := players[layer] as AudioStreamPlayer
		if player.stream != null:
			player.play(from)


## Families that keep their place when they stop (and resume from it):
## the menu and every walk.
static func resumes(family: StringName) -> bool:
	return family == &"menu" or String(family).begins_with("explore")


func _has_stream(track_name: StringName) -> bool:
	return players.has(track_name) and (players[track_name] as AudioStreamPlayer).stream != null


func _stop_family(family: StringName) -> void:
	var first := players[FAMILIES[family][0]] as AudioStreamPlayer
	if resumes(family) and first.stream != null:
		_positions[family] = fmod(first.get_playback_position(), maxf(first.stream.get_length(), 0.001))
	for layer: StringName in FAMILIES[family]:
		(players[layer] as AudioStreamPlayer).stop()


func _play_sting(sting: StringName) -> void:
	var player := stings[sting] as AudioStreamPlayer
	if player.stream == null or _quitting:
		return
	player.volume_db = 0.0
	player.play()


## Counts awake exhibits near the listener and checks for a haven.
func _look_around() -> void:
	_nearby = 0
	_engaged = 0
	_sheltered = false
	if director.mode != AudioContext.GAME:
		return
	if director.dead:
		var guard := AudioContext.guard(get_tree()) as Player
		if guard != null and guard.alive:
			director.on_player_revived()   # respawned in place (sandbox, dev viewers)
	var ears: Variant = AudioContext.listener_position(get_viewport())
	if ears == null:
		return
	var at: Vector3 = ears
	for node in get_tree().get_nodes_in_group(&"enemies"):
		var enemy := node as Enemy
		if enemy == null or not enemy.is_inside_tree():
			continue
		if not enemy.brain.is_alerted() or enemy.is_frozen():
			continue   # asleep, on a calm patrol, gone, or turned to stone at dawn
		var distance := enemy.global_position.distance_to(at)
		if distance <= THREAT_RADIUS:
			_nearby += 1
		var hunting := enemy.brain.is_hunting() or enemy.brain.is_stunned() or enemy.brain.knows_guard()
		if (hunting and distance <= ENGAGE_RADIUS) or (enemy.brain.state == EnemyBrain.State.ATTACK and distance <= THREAT_RADIUS):
			_engaged += 1
	var body := AudioContext.guard(get_tree())
	_sheltered = body != null and body.is_inside_tree() and Haven.shelters(body.global_position)


func _on_scene_changed() -> void:
	if not enabled:
		return
	_boss = null
	_guardian = null
	if Engine.get_process_frames() - _zone_frame > NightMood.SETUP_FRAMES:
		director.forget_zone()   # no Floor I zone announced by this scene
	var kind := AudioContext.scene_kind(get_tree().current_scene)
	if not director.night.claims(kind == AudioContext.GAME):
		director.night.reset()   # a scene without a night of its own
	set_scene_kind(kind)


func _on_state_changed(from: MusicDirector.State, to: MusicDirector.State) -> void:
	if to == MusicDirector.State.VICTORY:
		_play_sting(director.victory_sting)
	elif to == MusicDirector.State.SILENT and director.dead and from != MusicDirector.State.SILENT:
		_play_sting(&"death_sting")
	state_changed.emit(to)


func _on_hit_landed(_target: Node, _info: DamageInfo, killed: bool) -> void:
	if enabled:
		director.on_combat(MusicDirector.KILL_HEAT * 0.5 if killed else MusicDirector.HIT_HEAT)


func _on_enemy_destroyed(_enemy: Node, info: DamageInfo, _finisher: bool) -> void:
	if enabled and not Enemy.fell_out(info):
		director.on_combat(MusicDirector.KILL_HEAT * 0.5)


func _on_player_damaged(_amount: float, _from: Vector3) -> void:
	if enabled:
		director.on_combat(MusicDirector.HURT_HEAT)


func _on_weapon_fired(_weapon: StringName) -> void:
	if enabled and _nearby > 0:
		director.on_combat(MusicDirector.SHOT_HEAT)


func _on_player_died() -> void:
	if enabled:
		director.on_player_died()


func _on_boss_awakened(boss: Node) -> void:
	if not enabled or (boss != null and boss == _guardian):
		return   # a wing guardian borrowing the boss bar keeps its own theme
	_boss = boss
	if boss != null and boss.has_signal(&"phase_changed") and not boss.is_connected(&"phase_changed", director.on_boss_phase):
		boss.connect(&"phase_changed", director.on_boss_phase)
	if boss != null and not boss.tree_exited.is_connected(director.on_boss_gone):
		boss.tree_exited.connect(director.on_boss_gone, CONNECT_ONE_SHOT)   # removed undefeated: no boss music
	director.on_boss_awakened()


func _on_boss_defeated(boss_node: Node) -> void:
	if enabled and (boss_node == null or boss_node != _guardian):
		director.on_boss_defeated()


func _on_room_entered(_room: StringName, zone: StringName, first_visit: bool) -> void:
	if not enabled:
		return
	_zone_frame = Engine.get_process_frames()
	var sting := director.on_room_entered(zone, first_visit)
	if sting != &"":
		play_overlay(sting)


func _on_guardian_awakened(guardian: Node, guardian_id: StringName) -> void:
	if not enabled:
		return
	if guardian != null and guardian == _boss:
		director.on_boss_gone()   # announced as the boss first: it is a guardian
		_boss = null
	_guardian = guardian
	if guardian != null and guardian.has_signal(&"phase_changed") \
			and not guardian.is_connected(&"phase_changed", director.on_guardian_phase):
		guardian.connect(&"phase_changed", director.on_guardian_phase)
	if guardian != null and not guardian.tree_exited.is_connected(director.on_guardian_gone):
		guardian.tree_exited.connect(director.on_guardian_gone, CONNECT_ONE_SHOT)
	director.on_guardian_awakened(guardian_id)


func _on_guardian_defeated(guardian_id: StringName) -> void:
	if enabled:
		director.on_guardian_defeated(guardian_id)


func _on_seal_collected(_seal: StringName) -> void:
	if enabled:
		play_overlay(&"seal_sting")


func _on_shard_collected(_shard: StringName, _count: int) -> void:
	if enabled:
		play_overlay(&"seal_sting")


func _on_gate_opened(_gate: StringName) -> void:
	if enabled:
		play_overlay(&"gate_sting")


func _on_night_started(night: int, modifier: StringName) -> void:
	if enabled:
		director.on_night_started(night, modifier)


func _on_objective_changed(stage: int) -> void:
	if enabled:
		director.on_objective(stage)


func _on_power_cut() -> void:
	if enabled:
		director.on_power_cut()


func _on_witching_hour() -> void:
	if enabled:
		director.on_witching_hour()


func _on_dawn_broke() -> void:
	if enabled:
		director.on_dawn()


func _on_quitting() -> void:
	_quitting = true
	stop_all()
