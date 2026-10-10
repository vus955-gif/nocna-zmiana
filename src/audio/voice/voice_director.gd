extends Node
## Voice-over (autoload "VoiceDirector"): Heniek on the walkie-talkie and the
## museum's System on the loudspeakers and at the audio-guide stands.
## Listens to Events only. Lines and rules are data (VoiceCatalog), who
## speaks next is VoiceQueue, the acoustics are the buses (VoiceRadio,
## VoiceSystem) and the reverb zones. Time runs through advance(), so tests
## drive it without audio. Spec: docs/superpowers/specs/2026-10-08-glos-projekt.md.

signal line_started(key: StringName, channel: StringName, seconds: float)
signal line_ended(key: StringName)

const STALL_TIME := 360.0        ## s without progress before Heniek nudges
const STALL_GAP := 600.0         ## s between two nudges
const DEATH_DELAY := 3.0         ## s into the next night before the death comment
const DUCK_MUSIC_DB := -6.0
const DUCK_AMBIENCE_DB := -4.0
const DUCK_ATTACK := 0.25
const DUCK_RELEASE := 0.8
const PA_RANGE := 45.0           ## loudspeakers farther than this stay silent
const PA_SPEAKERS := 3
const PA_FALLBACK_DB := -6.0     ## no loudspeaker in range: heard faintly anyway
const GUIDE_RANGE := 12.0
const RADIO_CLICK := 0.14        ## s of the click before Heniek speaks
const SPEED_OF_SOUND := 343.0
const CALM_SAMPLE := 0.25        ## s between looks at the perception world (only while something waits or plays)

## Off in test and scenario runs (AudioContext.automatic()); a test switches it on.
var enabled := false
var catalog: VoiceCatalog
var queue := VoiceQueue.new()
## 0 (quiet) .. 1 (a line on air): how far the music and ambience are ducked.
var duck := 0.0
## Stall nudges asked for so far (tests).
var stall_nudges := 0

var _line: StringName = &""
var _line_left := 0.0
var _radio_wait := 0.0
var _radio: AudioStreamPlayer
var _radio_fx: AudioStreamPlayer
var _pa_fallback: AudioStreamPlayer
var _speakers: Array = []         ## loudspeakers playing the current line
var _guide_stand: Node3D = null
var _night := 0
var _night_clock := -1.0          ## < 0: no night running
var _fired: Dictionary = {}       ## night_time lines fired this night
var _witching := false
var _died := false
var _since_progress := 0.0
var _since_nudge := STALL_GAP
var _goal: StringName = &""
var _calm_cached := true
var _calm_timer := 0.0


func _ready() -> void:
	enabled = AudioContext.automatic()
	catalog = VoiceCatalog.load_default()
	_radio = _player(&"VoiceRadio")
	_radio_fx = _player(&"VoiceRadio")
	_pa_fallback = _player(&"VoiceSystem")
	_pa_fallback.volume_db = PA_FALLBACK_DB
	Events.night_started.connect(_on_night_started)
	Events.power_cut.connect(func() -> void: trigger(&"power_cut", {}))
	Events.witching_hour.connect(_on_witching_hour)
	Events.dawn_broke.connect(_on_dawn_broke)
	Events.room_entered.connect(_on_room_entered)
	Events.guardian_awakened.connect(func(_node: Node, id: StringName) -> void:
		trigger(&"guardian_awakened", {"guardian": id}))
	Events.guardian_defeated.connect(func(id: StringName) -> void:
		_progress()
		trigger(&"guardian_defeated", {"guardian": id}))
	Events.shard_collected.connect(func(_shard: StringName, count: int) -> void:
		_progress()
		trigger(&"shard_collected", {"count": count}))
	Events.seal_collected.connect(func(_seal: StringName) -> void:
		_progress()
		trigger(&"seal_collected", {}))
	Events.gate_opened.connect(func(_gate: StringName) -> void:
		_progress()
		trigger(&"gate_opened", {}))
	Events.goal_changed.connect(func(goal: StringName) -> void:
		_goal = goal
		_progress())
	Events.boss_awakened.connect(func(_boss: Node) -> void: trigger(&"boss_awakened", {}))
	Events.boss_defeated.connect(func(_boss: Node) -> void: trigger(&"boss_defeated", {}))
	Events.player_died.connect(_on_player_died)
	Events.player_damaged.connect(func(_amount: float, _from: Vector3) -> void: queue.calm_time = 0.0)
	Events.enemy_destroyed.connect(_on_enemy_destroyed)
	get_tree().scene_changed.connect(_on_scene_changed)
	add_child(SubtitleBar.new())   # listens to line_started / line_ended


func _player(bus: StringName) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.bus = bus
	add_child(player)
	return player


## Real time: the recordings play on regardless of Engine.time_scale, so a
## hitstop must not slow the subtitles, the ducking or the gaps.
func _process(delta: float) -> void:
	if enabled:
		advance(delta / maxf(Engine.time_scale, 0.01))


## Everything that moves with time; tests call it directly.
func advance(dt: float) -> void:
	_tick_night(dt)
	_tick_stall(dt)
	if _line != &"":
		_tick_line(dt)
	var key := queue.advance(dt, _calm_sampled(dt))
	if key != &"":
		_start(key)
	if duck > 0.0 or _line != &"":
		_tick_duck(dt)


func reset() -> void:
	_silence()
	queue.clear()
	if catalog.modified:
		catalog = VoiceCatalog.load_default()
	_calm_cached = true
	_calm_timer = 0.0
	duck = 0.0
	_set_duck(&"Music", 0.0)
	_set_duck(&"Ambience", 0.0)
	stall_nudges = 0
	_night = 0
	_night_clock = -1.0
	_fired.clear()
	_witching = false
	_died = false
	_since_progress = 0.0
	_since_nudge = STALL_GAP
	_goal = &""


func current_line() -> StringName:
	return _line


func line_left() -> float:
	return _line_left


## Queues every unheard line whose rule fits [param event]. Returns how many.
func trigger(event: StringName, payload: Dictionary) -> int:
	if not enabled:
		return 0
	var fields := payload.duplicate()
	fields["night"] = _night
	var queued := 0
	for key in catalog.keys_for_event(event):
		var rule := catalog.line(key)
		if rule.get("once", true) and GameState.voice_heard.has(key):
			continue
		if not VoiceRules.matches(rule, fields):
			continue
		if queue.push(key, int(rule.get("priority", VoiceQueue.NORMAL)), float(rule.get("delay", 0.0))):
			queued += 1
	return queued


## The player pressed an audio-guide button. Plays the stand's recording (the
## night one once its condition holds); a second press stops it. A line on
## air (Heniek, the System) yields and comes back later from its start.
func play_guide(station: StringName, stand: Node3D) -> StringName:
	if _guide_stand == stand and _line != &"":
		stop_line()
		return &""
	if _line != &"":
		_cut()
	var key := catalog.guide_key(station, _guide_variant(station))
	if key == &"":
		return &""
	queue.hold(key)
	_guide_stand = stand
	var stream := catalog.stream(key)
	if stand.has_method(&"play_voice"):
		stand.play_voice(stream)
	_begin(key, _seconds(key, stream))
	return key


## Stops the line on air (the guide's second press, walking away). It counts as heard.
func stop_line() -> void:
	if _line == &"":
		return
	_stop_players()
	_finish()


func _guide_variant(station: StringName) -> StringName:
	var night := catalog.line(catalog.guide_key(station, &"b"))
	if night.is_empty():
		return &"a"
	if night.has("after_guardian") and GameState.is_guardian_defeated(StringName(night.after_guardian)):
		return &"b"
	if night.get("after_witching", false) and _witching:
		return &"b"
	return &"a"


func _start(key: StringName) -> void:
	var stream := catalog.stream(key)
	var seconds := _seconds(key, stream)
	match catalog.channel_of(key):
		&"radio":
			_radio_fx.stream = Sfx.stream_of(&"radio_click_in")
			if _radio_fx.stream:
				_radio_fx.play()
			_radio.stream = stream
			_radio_wait = RADIO_CLICK
			seconds += RADIO_CLICK
		&"pa":
			_play_pa(stream)
	_begin(key, seconds)


func _begin(key: StringName, seconds: float) -> void:
	_line = key
	_line_left = seconds
	line_started.emit(key, catalog.channel_of(key), seconds)


## Length of the recording, or a reading-speed estimate while a line has none yet.
func _seconds(key: StringName, stream: AudioStream) -> float:
	return stream.get_length() if stream else maxf(1.5, tr(key).length() / 14.0)


func _tick_line(dt: float) -> void:
	if _radio_wait > 0.0:
		_radio_wait -= dt
		if _radio_wait <= 0.0 and _radio.stream:
			_radio.play()
	_line_left -= dt
	if _guide_stand and _listener().distance_to(_guide_stand.global_position) > GUIDE_RANGE:
		stop_line()
	elif _line_left <= 0.0:
		_finish()


## The line ended (played out or stopped): heard, the queue is free.
func _finish() -> void:
	var key := _line
	if catalog.channel_of(key) == &"radio":
		_radio_fx.stream = Sfx.stream_of(&"radio_click_out")
		if _radio_fx.stream:
			_radio_fx.play()
	_line = &""
	_guide_stand = null
	_speakers = []
	queue.finished()
	GameState.mark_voice_heard(key)
	line_ended.emit(key)


## Cut without counting it heard: a Heniek/System line goes back to the queue,
## a guide recording just stops.
func _cut() -> void:
	var key := _line
	_stop_players()
	if catalog.channel_of(key) == &"guide":
		queue.finished()
	else:
		queue.interrupt()
	_line = &""
	_guide_stand = null
	_speakers = []
	line_ended.emit(key)


## Everything quiet, nothing heard (a new night, a death, a reset).
func _silence() -> void:
	if _line != &"":
		_stop_players()
		_line = &""
		_guide_stand = null
		_speakers = []
		queue.finished()
		line_ended.emit(&"")
	_radio_wait = 0.0


func _stop_players() -> void:
	_radio_wait = 0.0
	_radio.stop()
	_radio_fx.stop()
	_pa_fallback.stop()
	for speaker in _speakers:
		if is_instance_valid(speaker):
			speaker.stop_voice()
	if is_instance_valid(_guide_stand) and _guide_stand.has_method(&"stop_voice"):
		_guide_stand.stop_voice()


func _play_pa(stream: AudioStream) -> void:
	var here := _listener()
	var near: Array = get_tree().get_nodes_in_group(&"loudspeakers").filter(
			func(s: Node3D) -> bool: return s.global_position.distance_to(here) <= PA_RANGE)
	near.sort_custom(func(a: Node3D, b: Node3D) -> bool:
		return a.global_position.distance_to(here) < b.global_position.distance_to(here))
	_speakers = near.slice(0, PA_SPEAKERS)
	if _speakers.is_empty():
		_pa_fallback.stream = stream
		_pa_fallback.play()
		return
	var nearest: float = _speakers[0].global_position.distance_to(here)
	for speaker in _speakers:
		speaker.play_voice(stream, (speaker.global_position.distance_to(here) - nearest) / SPEED_OF_SOUND)


func _listener() -> Vector3:
	var camera := get_viewport().get_camera_3d()
	return camera.global_position if camera else Vector3.ZERO


## The perception world's answer, looked up every CALM_SAMPLE s while a line
## waits or plays; idle, the last answer stands (hunters_near scans every
## exhibit, and the first look after a push corrects it anyway).
func _calm_sampled(dt: float) -> bool:
	if queue.is_speaking() or not queue.pending.is_empty():
		_calm_timer -= dt
		if _calm_timer <= 0.0:
			_calm_timer = CALM_SAMPLE
			_calm_cached = _calm()
	else:
		_calm_timer = 0.0
	return _calm_cached


func _calm() -> bool:
	var camera := get_viewport().get_camera_3d()
	return camera == null or PerceptionWorld.hunters_near(camera.global_position) == 0


func _tick_duck(dt: float) -> void:
	var target := 1.0 if _line != &"" else 0.0
	duck = move_toward(duck, target, dt / (DUCK_ATTACK if target > duck else DUCK_RELEASE))
	_set_duck(&"Music", DUCK_MUSIC_DB * duck)
	_set_duck(&"Ambience", DUCK_AMBIENCE_DB * duck)


func _set_duck(bus: StringName, db: float) -> void:
	var effect := duck_effect(bus)
	if effect:
		effect.volume_db = db


## The "VoiceDuck" amplifier on [param bus] (default_bus_layout.tres), or null.
## Bus volumes belong to Settings, so ducking only ever touches this effect.
static func duck_effect(bus: StringName) -> AudioEffectAmplify:
	var index := AudioServer.get_bus_index(bus)
	if index < 0:
		return null
	for i in AudioServer.get_bus_effect_count(index):
		var effect := AudioServer.get_bus_effect(index, i)
		if effect is AudioEffectAmplify and effect.resource_name == "VoiceDuck":
			return effect
	return null


func _tick_night(dt: float) -> void:
	if _night_clock < 0.0:
		return
	_night_clock += dt
	for key in catalog.keys_for_event(&"night_time"):
		var rule := catalog.line(key)
		if _fired.has(key) or float(rule.get("at", 0.0)) > _night_clock:
			continue
		_fired[key] = true
		if rule.get("once", true) and GameState.voice_heard.has(key):
			continue
		if VoiceRules.matches(rule, {"night": _night}):
			queue.push(key, int(rule.get("priority", VoiceQueue.NORMAL)), float(rule.get("delay", 0.0)))


func _tick_stall(dt: float) -> void:
	if _night_clock < 0.0:
		return
	_since_progress += dt
	_since_nudge += dt
	if _since_progress >= STALL_TIME and _since_nudge >= STALL_GAP:
		_since_nudge = 0.0
		stall_nudges += 1
		trigger(&"stall", {"goal": _goal})


func _progress() -> void:
	_since_progress = 0.0


func _on_night_started(night: int, _modifier: StringName) -> void:
	_silence()
	queue.clear()
	_night = night
	_night_clock = 0.0
	_fired.clear()
	_witching = false
	_progress()
	_since_nudge = STALL_GAP
	trigger(&"night_started", {})
	if _died:
		_died = false
		_comment_death()


## The first unheard death line of the speaker whose turn it is; no such
## line = nothing changes (the turn stays).
func _comment_death() -> void:
	var state := GameState.voice_state
	if int(state.get("death_night", -1)) == _night:
		return
	var first := String(state.get("death_turn", "heniek"))
	for speaker in [first, "system" if first == "heniek" else "heniek"]:
		if _queue_death_line(speaker):
			state["death_night"] = _night
			state["death_turn"] = "system" if speaker == "heniek" else "heniek"
			return


## Queues [param speaker]'s first unheard death line that fits this night.
func _queue_death_line(speaker: String) -> bool:
	for key in catalog.keys_for_event(&"death"):
		var rule := catalog.line(key)
		if String(rule.get("speaker", "")) != speaker or GameState.voice_heard.has(key):
			continue
		if VoiceRules.matches(rule, {"night": _night}) and queue.push(key, VoiceQueue.SIDE, DEATH_DELAY):
			return true
	return false


func _on_player_died() -> void:
	_silence()
	_died = true


## Leaving the game (menu, end screen, a dev viewer): quiet, nothing queued,
## no night running — like Music and Ambience.
func _on_scene_changed() -> void:
	if not enabled:
		return
	if AudioContext.scene_kind(get_tree().current_scene) != AudioContext.GAME:
		_silence()
		queue.clear()
		_night_clock = -1.0


func _on_witching_hour() -> void:
	_witching = true
	trigger(&"witching_hour", {})


func _on_dawn_broke() -> void:
	trigger(&"dawn_broke", {})
	_night_clock = -1.0


func _on_room_entered(_room: StringName, zone: StringName, first_visit: bool) -> void:
	if first_visit:
		_progress()
		trigger(&"room_entered", {"zone": zone})


func _on_enemy_destroyed(_enemy: Node, _info: DamageInfo, _finisher: bool) -> void:
	if not enabled:
		return
	var count := int(GameState.voice_state.get("destroyed", 0)) + 1
	GameState.voice_state["destroyed"] = count
	trigger(&"destroyed", {"count": count})
