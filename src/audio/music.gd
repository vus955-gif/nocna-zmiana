extends Node
## Adaptive music (autoload "Music") on the Music bus. A MusicDirector
## decides the state from the scene kind and the game's events; this node
## plays it: every layer fades toward its target with an equal-power curve.
## The stems of one family (explore + explore_tension, combat + combat_hi,
## boss + boss_hi, a Floor I zone's four) are one AudioStreamSynchronized on
## one AudioStreamPlayer, so they start, pause and loop sample-locked; each
## stem has its own volume in it (set_sync_stream_volume). Walks resume
## where they stopped.
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
## - Floor I: Events.room_entered moves the music to the zone's music zone
##   (MusicDirector.MUSIC_ZONES). A zone's family (zone_<zone>) is one loop in
##   four synced stems: explore_<zone> (the walk), explore_<zone>_tension,
##   combat_<zone> (the heavy version, played alone in a fight) and
##   combat_<zone>_hi, so walk, tension and fight hand over on the beat. The
##   old zone crossfades into the new over CROSSFADE s (a fight over
##   FIGHT_CROSSFADE s), and every zone resumes where it stopped, so coming
##   back never restarts it. A wing guardian (Events.guardian_awakened /
##   guardian_defeated) plays the guardians' theme in its wing
##   (guardian_<wing>: guardian_<wing> + guardian_<wing>_hi), its fall the
##   guardian sting; it (and the T-Rex) clears the rest in BOSS_FADE s.
##   Seals, shards, gates and a newly found wing lay a short sting
##   (OVERLAYS) over the music, which ducks by DUCK_DB under it.
## - Loading: the menu, the lobby's families (EAGER) and the stings load at
##   boot. Floor I's zone and guardian families load when the floor asks for
##   them (a room entered, a guardian awake) on a loader thread
##   (ResourceLoader.load_threaded_request): no frame waits for them, and what
##   plays goes on (or nothing starts) until a family is there. Only the
##   latest MAX_FLOOR_FAMILIES stay in memory (never one that is audible or
##   around the guard); all of them go when a scene without a zone replaces
##   the floor.
## Automation is off in test runs (enabled = false); set_scene_kind()
## drives it by hand.

signal state_changed(state: MusicDirector.State)

const DIR := "res://assets/music/"
const BUS := &"Music"
## Family -> its tracks (all the same length, one synchronized stream). Floor
## I's families play logical layers (MusicDirector.LAYERS) in a music zone's
## or a wing's colours: track(). A zone's family (zone_<zone>) is its whole
## loop: walk, tension, fight and the fight's hi stem.
const FAMILIES := {
	&"menu": [&"menu"],
	&"explore": [&"explore", &"explore_tension"],
	&"combat": [&"combat", &"combat_hi"],
	&"boss": [&"boss", &"boss_hi"],
	&"zone_court": [&"explore_court", &"explore_court_tension", &"combat_court", &"combat_court_hi"],
	&"zone_egypt": [&"explore_egypt", &"explore_egypt_tension", &"combat_egypt", &"combat_egypt_hi"],
	&"zone_assyria": [&"explore_assyria", &"explore_assyria_tension", &"combat_assyria", &"combat_assyria_hi"],
	&"zone_greece": [&"explore_greece", &"explore_greece_tension", &"combat_greece", &"combat_greece_hi"],
	&"zone_enlightenment": [&"explore_enlightenment", &"explore_enlightenment_tension", &"combat_enlightenment",
		&"combat_enlightenment_hi"],
	&"zone_asia": [&"explore_asia", &"explore_asia_tension", &"combat_asia", &"combat_asia_hi"],
	&"zone_americas": [&"explore_americas", &"explore_americas_tension", &"combat_americas", &"combat_americas_hi"],
	&"zone_basement": [&"explore_basement", &"explore_basement_tension", &"combat_basement", &"combat_basement_hi"],
	&"zone_roof": [&"explore_roof", &"explore_roof_tension", &"combat_roof", &"combat_roof_hi"],
	&"guardian_egypt": [&"guardian_egypt", &"guardian_egypt_hi"],
	&"guardian_assyria": [&"guardian_assyria", &"guardian_assyria_hi"],
	&"guardian_greece": [&"guardian_greece", &"guardian_greece_hi"],
	&"guardian_enlightenment": [&"guardian_enlightenment", &"guardian_enlightenment_hi"],
	&"guardian_asia": [&"guardian_asia", &"guardian_asia_hi"],
	&"guardian_americas": [&"guardian_americas", &"guardian_americas_hi"],
}
## Families loaded at boot: the menu and the lobby's night. The rest of
## FAMILIES (Floor I's zones and guardians) loads on request_family().
const EAGER: Array[StringName] = [&"menu", &"explore", &"combat", &"boss"]
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
## Seconds everything else takes to fade out when the T-Rex or a wing
## guardian takes over (otherwise the zone's fight would linger under its
## theme for up to FADE_OUT s).
const BOSS_FADE := 1.0
## Seconds one zone's walk takes to hand over to another's (both ways), and
## one zone's fight to another's (two heavy mixes in different tempos: short).
const CROSSFADE := 2.5
const FIGHT_CROSSFADE := 1.5
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
## Floor I families (zones and guardians) kept in memory at most, besides
## the audible ones and those around the guard.
const MAX_FLOOR_FAMILIES := 6

var director := MusicDirector.new()
## False in test runs: scene changes and events are ignored until a test
## switches it on or calls set_scene_kind().
var enabled: bool = true
## True: a family loads on the spot (test runs, where no test waits a frame
## for it); false: on a loader thread, polled every frame.
var blocking_loads: bool = false
## Family -> its AudioStreamPlayer (the stream: an AudioStreamSynchronized
## with the family's stems in FAMILIES order). Loaded families only.
var family_players: Dictionary = {}
## Sting -> AudioStreamPlayer.
var stings: Dictionary = {}
## Track -> fade position 0..1 (volume = sin(level * PI / 2)).
var levels: Dictionary = {}
## 0..1: how far the music is ducked under an overlay sting.
var duck: float = 0.0

var _positions: Dictionary = {}
## Track -> [its family, its index in the family's stream].
var _stems: Dictionary = {}
## Family -> {"paths": the files asked for ("" = none), "discard": true when
## nobody wants it any more} while its loader thread works.
var _loading: Dictionary = {}
## Floor I families asked for (loaded or loading), the latest last.
var _recent: Array[StringName] = []
## Layer -> the track that plays it, as of the last track_targets().
var _playing: Dictionary = {}
var _trim_due: bool = false
var _scan: float = 0.0
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
	blocking_loads = not enabled
	for family: StringName in FAMILIES:
		var layers: Array = FAMILIES[family]
		for i in layers.size():
			_stems[layers[i]] = [family, i]
			levels[layers[i]] = 0.0
	for family in EAGER:
		_load_family_now(family)
	for sting in STINGS:
		stings[sting] = _make_player(String(sting))
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
		if is_walk(family):
			_positions.erase(family)   # a new night starts its walks from the top
	director.set_mode(kind)


## The track of [param layer] (a MusicDirector.LAYERS name) in
## [param zone]'s colours (a music zone or a wing; &"" = the lobby's own
## track).
static func track(layer: StringName, zone: StringName) -> StringName:
	if zone == &"":
		return layer
	match layer:
		&"explore":
			return StringName("explore_" + String(zone))
		&"explore_tension":
			return StringName("explore_%s_tension" % zone)
		&"combat":
			return StringName("combat_" + String(zone))
		&"combat_hi":
			return StringName("combat_%s_hi" % zone)
		&"guardian":
			return StringName("guardian_" + String(zone))
		&"guardian_hi":
			return StringName("guardian_%s_hi" % zone)
	return layer


## The logical layer a track plays (&"explore_egypt_tension" ->
## &"explore_tension", &"combat_roof_hi" -> &"combat_hi").
static func layer_of(track_name: StringName) -> StringName:
	var text := String(track_name)
	if text.begins_with("explore"):
		return &"explore_tension" if text.ends_with("_tension") else &"explore"
	if text.begins_with("combat"):
		return &"combat_hi" if text.ends_with("_hi") else &"combat"
	if text.begins_with("guardian"):
		return &"guardian_hi" if text.ends_with("_hi") else &"guardian"
	return track_name


## True for a family that is a walk: the lobby's and every Floor I zone's
## (the zone's loop holds its fight stems too).
static func is_walk(family: StringName) -> bool:
	return family == &"explore" or String(family).begins_with("zone_")


## The family of a Floor I music zone / of a wing's guardian.
static func zone_family(zone: StringName) -> StringName:
	return StringName("zone_" + String(zone))


static func guardian_family(wing: StringName) -> StringName:
	return StringName("guardian_" + String(wing))


## The family a track belongs to (&"" for an unknown track).
func family_of(track_name: StringName) -> StringName:
	return (_stems[track_name] as Array)[0] if _stems.has(track_name) else &""


## The track that plays [param layer] right now: the walk and the fight in
## the music zone's colours, the guardians' theme in the guardian's wing. A
## missing file falls back on the lobby's track (a guardian on the T-Rex's);
## a zone whose family is still loading plays what played before (nothing,
## at the start of a night) rather than the lobby's tune.
func playing_track(layer: StringName) -> StringName:
	var zone: StringName = &""
	if MusicDirector.ZONE_LAYERS.has(layer):
		zone = director.variant
	elif MusicDirector.GUARDIAN_LAYERS.has(layer):
		zone = director.guardian_wing
	var name := track(layer, zone)
	if has_track(name):
		return name
	if zone != &"" and is_family_loading(family_of(name)):
		return _playing.get(layer, &"")
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
	for name: StringName in levels:
		targets[name] = 0.0
	for layer: StringName in logical:
		var level: float = logical[layer]
		if level > 0.0:
			var name := playing_track(layer)
			_playing[layer] = name
			if name != &"":
				targets[name] = maxf(float(targets.get(name, 0.0)), level)
		else:
			_playing.erase(layer)
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
	for family: StringName in family_players:
		(family_players[family] as AudioStreamPlayer).stop()
	for layer: StringName in levels:
		levels[layer] = 0.0
	for sting: StringName in stings:
		(stings[sting] as AudioStreamPlayer).stop()
	_positions.clear()
	_queued.clear()
	_overlay_left = 0.0
	duck = 0.0


## Sets the silence right away (no fades) and forgets the scene, its
## night, its zone and the wings met; Floor I's music leaves the memory.
func reset() -> void:
	stop_all()
	release_floor_music()
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
	_poll_loading()
	var frozen := get_tree().paused and director.mode == AudioContext.GAME
	if not frozen:
		_scan -= delta
		if _scan <= 0.0:
			_scan = SCAN_INTERVAL
			_look_around()
		director.update(delta, _nearby, _engaged, _sheltered)
	advance(delta, frozen)


## Moves every track toward its target and starts / stops families; a
## logical layer that stays wanted while its zone changes crossfades its
## tracks over CROSSFADE s (the fight's over FIGHT_CROSSFADE s). Overlay
## stings duck the music.
## [param frozen]: the game is paused; its (paused) layers keep their level.
func advance(delta: float, frozen: bool = false) -> void:
	_want_floor_families()
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
	for name: StringName in levels:
		if float(targets[name]) > 0.0 or float(levels[name]) > 0.0:
			busy[layer_of(name)] = int(busy.get(layer_of(name), 0)) + 1
	for family: StringName in family_players:
		if frozen and family != &"menu":
			continue
		var layers: Array = FAMILIES[family]
		var player := family_players[family] as AudioStreamPlayer
		var stream := player.stream as AudioStreamSynchronized
		var wanted := false
		var audible := false
		for i in layers.size():
			var layer: StringName = layers[i]
			var kind := layer_of(layer)
			var swap := int(busy.get(kind, 0)) > 1 and float(logical.get(kind, 0.0)) > 0.0
			var handover := FIGHT_CROSSFADE if kind == &"combat" or kind == &"combat_hi" else CROSSFADE
			var target: float = targets[layer]
			var level: float = levels[layer]
			if target > level:
				level = minf(target, level + delta / (handover if swap else float(FADE_IN[kind])))
			elif target < level:
				var away := handover if swap else float(FADE_OUT[kind])
				level = maxf(target, level - delta / (fade_away if fade_away > 0.0 else away))
			levels[layer] = level
			wanted = wanted or target > 0.0
			audible = audible or level > 0.0
			var level_db := volume_db(level)
			if stream.get_sync_stream_volume(i) != level_db:
				stream.set_sync_stream_volume(i, level_db)
		# the overlay's duck is the player's own volume (smoothed by the mixer)
		var family_db := 0.0 if family == &"menu" else ducked
		if player.volume_db != family_db:
			player.volume_db = family_db
		if wanted and not player.playing and stream.get_sync_stream(0) != null:
			_start_family(family)
		elif not wanted and not audible and player.playing:
			_stop_family(family)
	if _trim_due:
		_trim_due = false
		_trim()


## Seconds every layer takes to fade out right now, whatever its own
## FADE_OUT: the guard fell (DEATH_FADE), dawn (DAWN_FADE), the power cut's
## hush (HUSH_FADE), the T-Rex or a wing guardian taking over (BOSS_FADE);
## 0 = each layer's own.
func fade_out_time() -> float:
	if director.dead:
		return DEATH_FADE
	if director.night.dawn:
		return DAWN_FADE
	if director.hushed():
		return HUSH_FADE
	if director.state == MusicDirector.State.BOSS or director.state == MusicDirector.State.GUARDIAN:
		return BOSS_FADE
	return 0.0


## Equal-power fade curve in dB (SILENT_DB at 0).
static func volume_db(level: float) -> float:
	if level <= 0.0:
		return SILENT_DB
	return maxf(linear_to_db(sin(clampf(level, 0.0, 1.0) * PI * 0.5)), SILENT_DB)


func is_family_playing(family: StringName) -> bool:
	return family_players.has(family) and (family_players[family] as AudioStreamPlayer).playing


# --- families in memory ------------------------------------------------------

## True once [param family] is loaded (its player exists).
func is_family_loaded(family: StringName) -> bool:
	return family_players.has(family)


## True while [param family] is on its loader thread and somebody wants it.
func is_family_loading(family: StringName) -> bool:
	return _loading.has(family) and not bool((_loading[family] as Dictionary)["discard"])


## How many loader threads' results are still to be collected (also those
## nobody wants any more).
func loads_pending() -> int:
	return _loading.size()


## The Floor I families (zones, guardians) in memory now.
func loaded_floor_families() -> Array[StringName]:
	var loaded: Array[StringName] = []
	for family: StringName in family_players:
		if not EAGER.has(family):
			loaded.append(family)
	return loaded


## The player carrying [param track_name] (a stem of its family's stream), or
## null while that family is not loaded.
func player_of(track_name: StringName) -> AudioStreamPlayer:
	var family := family_of(track_name)
	return family_players.get(family) as AudioStreamPlayer


## True when [param track_name]'s family is loaded and has its file.
func has_track(track_name: StringName) -> bool:
	var player := player_of(track_name)
	if player == null:
		return false
	return (player.stream as AudioStreamSynchronized).get_sync_stream(int((_stems[track_name] as Array)[1])) != null


## The volume of one stem in dB: its own in the stream plus the player's
## (the overlay duck). SILENT_DB when the track is not loaded.
func stem_db(track_name: StringName) -> float:
	var player := player_of(track_name)
	if player == null:
		return SILENT_DB
	var stream := player.stream as AudioStreamSynchronized
	return stream.get_sync_stream_volume(int((_stems[track_name] as Array)[1])) + player.volume_db


## Asks for [param family] to be in memory: loaded on the spot (blocking
## loads) or on a loader thread (_poll_loading() collects it). A Floor I
## family becomes the newest of the ones kept (MAX_FLOOR_FAMILIES).
func request_family(family: StringName) -> void:
	if not FAMILIES.has(family):
		return
	if not EAGER.has(family):
		_recent.erase(family)
		_recent.append(family)
	if family_players.has(family):
		pass
	elif _loading.has(family):
		(_loading[family] as Dictionary)["discard"] = false
		if blocking_loads:
			_settle(family, true)
	elif blocking_loads or EAGER.has(family):
		_load_family_now(family)
	else:
		_load_family_threaded(family)
	_trim()


## Lets go of [param family]: stops and frees its player (the streams go
## with it). A load still under way is dropped when it ends.
func release_family(family: StringName) -> void:
	_recent.erase(family)
	if _loading.has(family):
		(_loading[family] as Dictionary)["discard"] = true
	if not family_players.has(family):
		return
	var player := family_players[family] as AudioStreamPlayer
	family_players.erase(family)
	player.stop()
	remove_child(player)
	player.free()
	for layer: StringName in FAMILIES[family]:
		levels[layer] = 0.0
		_playing.erase(layer)


## Lets go of all of Floor I's music (zones and guardians): the floor is over.
func release_floor_music() -> void:
	for family: StringName in FAMILIES:
		if not EAGER.has(family):
			release_family(family)
	_recent.clear()


## Asks for the families a Floor I zone needs: its music zone's loop and,
## in a wing, its guardian's theme.
func request_zone(zone: StringName) -> void:
	var music := MusicDirector.music_zone_of(zone)
	if music == &"":
		return
	request_family(zone_family(music))
	if MusicDirector.WINGS.has(music):
		request_family(guardian_family(music))


## Whatever the director's state needs and is not on its way yet.
func _want_floor_families() -> void:
	if director.mode != AudioContext.GAME:
		return
	var wanted: Array[StringName] = []
	if director.variant != &"":
		wanted.append(zone_family(director.variant))
	if director.guardian_active:
		wanted.append(guardian_family(director.guardian_wing))
	for family in wanted:
		if not family_players.has(family) and not is_family_loading(family):
			request_family(family)


## Floor I families around the guard: the music zone he is in and plays,
## and their guardians.
func _current_families() -> Array[StringName]:
	var current: Array[StringName] = []
	for zone: StringName in [director.variant, MusicDirector.music_zone_of(director.zone)]:
		if zone != &"":
			current.append(zone_family(zone))
			if MusicDirector.WINGS.has(zone):
				current.append(guardian_family(zone))
	if director.guardian_active:
		current.append(guardian_family(director.guardian_wing))
	return current


## True while [param family] must stay in memory: it plays, is audible or is
## around the guard.
func _in_use(family: StringName) -> bool:
	if is_family_playing(family) or _current_families().has(family):
		return true
	for layer: StringName in FAMILIES[family]:
		if float(levels[layer]) > 0.0:
			return true
	return false


## Drops the oldest Floor I families beyond MAX_FLOOR_FAMILIES, unless they
## are in use.
func _trim() -> void:
	var i := 0
	while _recent.size() > MAX_FLOOR_FAMILIES and i < _recent.size():
		if _in_use(_recent[i]):
			i += 1
		else:
			release_family(_recent[i])   # leaves _recent


func _load_family_now(family: StringName) -> void:
	var streams: Array = []
	for track_name: StringName in FAMILIES[family]:
		var path := DIR + String(track_name) + ".ogg"
		streams.append(load(path) if ResourceLoader.exists(path) else null)
	_build_family(family, streams)


func _load_family_threaded(family: StringName) -> void:
	var paths: Array[String] = []
	for track_name: StringName in FAMILIES[family]:
		var path := DIR + String(track_name) + ".ogg"
		var asked := ResourceLoader.exists(path) and ResourceLoader.load_threaded_request(path) == OK
		paths.append(path if asked else "")
	_loading[family] = {"paths": paths, "discard": false}


## Collects the loader threads that have finished.
func _poll_loading() -> void:
	for family: StringName in _loading.keys():
		_settle(family, false)


## Takes the result of [param family]'s load once all its files are there (or
## at once, waiting for them, when [param wait]) and builds the family from
## it, unless nobody wants it any more.
func _settle(family: StringName, wait: bool) -> void:
	var entry := _loading[family] as Dictionary
	var paths: Array = entry["paths"]
	if not wait:
		for path: String in paths:
			if path != "" and ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
				return
	var streams: Array = []
	for path: String in paths:
		streams.append(ResourceLoader.load_threaded_get(path) if path != "" else null)
	_loading.erase(family)
	if not bool(entry["discard"]):
		_build_family(family, streams)


## The family's player: one AudioStreamSynchronized of [param streams] (null
## = a missing file), every stem silent. Game music pauses with the game; the
## menu theme plays on.
func _build_family(family: StringName, streams: Array) -> void:
	if streams.all(func(stream: Variant) -> bool: return stream == null):
		return
	var mixed := AudioStreamSynchronized.new()
	mixed.stream_count = streams.size()
	for i in streams.size():
		mixed.set_sync_stream(i, streams[i] as AudioStream)
		mixed.set_sync_stream_volume(i, SILENT_DB)
	var player := AudioStreamPlayer.new()
	player.name = String(family)
	player.bus = BUS
	player.stream = mixed
	player.process_mode = Node.PROCESS_MODE_ALWAYS if family == &"menu" else Node.PROCESS_MODE_PAUSABLE
	add_child(player)
	family_players[family] = player


func _make_player(file: String) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = file
	player.bus = BUS
	player.volume_db = SILENT_DB
	var path := DIR + file + ".ogg"
	if ResourceLoader.exists(path):
		player.stream = load(path)
	player.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(player)
	return player


func _start_family(family: StringName) -> void:
	(family_players[family] as AudioStreamPlayer).play(float(_positions.get(family, 0.0)))


## Families that keep their place when they stop (and resume from it):
## the menu and every walk.
static func resumes(family: StringName) -> bool:
	return family == &"menu" or is_walk(family)


func _stop_family(family: StringName) -> void:
	var player := family_players[family] as AudioStreamPlayer
	if resumes(family) and player.stream != null:
		_positions[family] = fmod(player.get_playback_position(), maxf(player.stream.get_length(), 0.001))
	player.stop()
	_trim_due = _trim_due or not EAGER.has(family)


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
		release_floor_music()
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
	request_zone(zone)   # on its way before the walk (VARIANT_SETTLE s) or the fight (FIGHT_SETTLE s) needs it
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
	if director.guardian_active:
		request_family(guardian_family(director.guardian_wing))


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
