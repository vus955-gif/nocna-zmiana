extends Node
## Room tone, distant sounds and room reverb (autoload "Ambience") on the
## Ambience bus. Ogg Vorbis files from tools/music/gen_ambience.py
## (tools/build_audio.sh).
## - Beds: a zone is a mix of looping layers (ZONES, gains in dB); a zone
##   change crossfades them over FADE s. In a blackout the electric layers
##   (tubes, fans, monitors, mains hum) die and the dread layer comes in.
## - Which zone: set_zone() (a manual choice) beats AmbienceZone nodes
##   around the listener (the highest Area3D.priority wins), those beat
##   the Floor I zone of the last Events.room_entered (refined to a
##   sub-zone by its room's name: SUB_ZONES), that beats the level's rooms
##   (a level with room_at(), mapped by ROOM_ZONES), those beat
##   DEFAULT_ZONE. Only scenes with the guard have ambience.
## - Floor I: every zone of Floor1Plan (court, entrance, booth, the six
##   wings, north_hall, basement, roof) and a few sub-zones have their own
##   mix of beds and distant one-shots (ZONES, ZONE_SHOTS); reverb zones
##   built from a level's rooms fall back on the room's zone (ZONE_REVERB).
## - One-shots: every SHOT_GAP s (BLACKOUT_GAP in a blackout) a distant
##   sound of the zone's kinds plays somewhere around the listener, in 3D,
##   SHOT_DISTANCE m away (their space is baked in: no zone reverb).
## - Reverb: ReverbZone areas send positional sounds to the reverb buses;
##   a level describing its rooms (level.layout.rooms, the lobby) gets
##   zones built from ROOM_REVERB when the scene has none of its own. Sfx
##   voices get the zones' physics layer as they start. The zone around
##   the listener lends the SFX bus a little of its reverb. The reverb
##   buses return into RETURN_BUS, not into SFX (a room's tail is not
##   reverbed twice); it follows the SFX bus's volume and mute (the SFX
##   slider) whenever the options change.
## - Blackout: the night's modifier (Events.night_started) or
##   RunState.modifier is &"blackout" (watched every POLL s), or
##   set_blackout() (lasts until the modifier changes or the scene does).
## - The night in the lobby ([member night], a NightMood fed from Events):
##   after the power cut (and all night on a resumed one) the zones of the
##   dark rooms (POWER_CUT_ZONES) lose their electric layers within
##   CUT_FADE s, the dread comes in and the emergency circuit hums
##   (EMERGENCY_LAYERS); from the witching hour on the building stirs more
##   often (WITCHING_GAP); dawn takes the dread and the one-shots away and
##   lets a few far birds in (DAWN_BIRDS, once).
## Beds and one-shots are loaded up front (no file read mid-night). Beds
## pause with the game. Off in test runs (enabled = false).

const DIR := "res://assets/ambience/"
const SHOT_DIR := "res://assets/ambience/oneshots/"
const BUS := &"Ambience"
const SFX_BUS := &"SFX"
## Where the reverb buses return (default_bus_layout.tres).
const RETURN_BUS := &"SFXReturn"
const LAYERS: Array[StringName] = [&"hall_air", &"gallery_room", &"mains_hum", &"fluorescent", &"cctv", &"clock", &"hvac", &"dread",
	# Floor I (tools/music/ambience_floor1.py)
	&"glass_wind", &"city_hum", &"stone_deep", &"sand_trickle", &"crack_wind", &"cedar_creak", &"fire", &"airy_hall",
	&"drips", &"clocks", &"library", &"chimes", &"garden", &"paper_rustle", &"far_drums", &"boiler", &"roof_wind",
	# rain on some nights (tools/music/ambience_story.py; StoryLayer decides)
	&"rain_glass", &"rain_open"]
## Layers that need power (silent in a blackout).
const ELECTRIC: Array[StringName] = [&"mains_hum", &"fluorescent", &"cctv", &"hvac"]
## Zone -> {layer: gain dB}.
const ZONES := {
	&"grand_hall": {&"hall_air": 0.0, &"mains_hum": -6.0},
	&"gallery": {&"gallery_room": 0.0, &"hall_air": -12.0, &"mains_hum": -8.0},
	&"security": {&"gallery_room": -4.0, &"fluorescent": 0.0, &"cctv": 0.0, &"clock": 0.0},
	&"corridor": {&"hvac": 0.0, &"gallery_room": -6.0},
	&"secret": {&"gallery_room": 3.0, &"hall_air": -16.0},
	# --- Floor I (Floor1Plan zone ids, plus sub-zones <zone>_<part>) ---
	&"court": {&"glass_wind": 0.0, &"hall_air": -4.0, &"city_hum": -6.0, &"mains_hum": -12.0},
	&"entrance": {&"gallery_room": -2.0, &"city_hum": -2.0, &"hall_air": -10.0, &"mains_hum": -9.0},
	&"booth": {&"gallery_room": -4.0, &"fluorescent": 0.0, &"cctv": 0.0, &"clock": 0.0},
	&"egypt": {&"stone_deep": 0.0, &"crack_wind": -2.0, &"sand_trickle": -3.0, &"gallery_room": -10.0},
	&"egypt_tomb": {&"stone_deep": 2.0, &"sand_trickle": 0.0, &"gallery_room": -4.0, &"drips": -10.0},
	&"assyria": {&"cedar_creak": 0.0, &"stone_deep": -3.0, &"fire": -7.0, &"gallery_room": -8.0},
	&"greece": {&"airy_hall": 0.0, &"drips": -5.0, &"gallery_room": -12.0},
	&"enlightenment": {&"library": 0.0, &"clocks": -5.0, &"gallery_room": -10.0},
	&"enlightenment_clocks": {&"clocks": 3.0, &"library": -6.0},
	&"asia": {&"paper_rustle": 0.0, &"chimes": -3.0, &"garden": -10.0, &"gallery_room": -8.0},
	&"asia_garden": {&"garden": 0.0, &"chimes": 0.0, &"paper_rustle": -8.0, &"roof_wind": -16.0},
	&"americas": {&"far_drums": 0.0, &"fire": -3.0, &"stone_deep": -8.0, &"gallery_room": -10.0},
	&"north_hall": {&"gallery_room": 0.0, &"hvac": -5.0, &"hall_air": -12.0},
	&"basement": {&"boiler": -2.0, &"fluorescent": -4.0, &"drips": -4.0, &"hvac": -9.0},
	&"basement_boiler": {&"boiler": 3.0, &"drips": -8.0, &"fluorescent": -6.0},
	&"roof": {&"roof_wind": 0.0, &"city_hum": -2.0, &"glass_wind": -6.0},
}
## Floor I sub-zones picked by the room's name (Events.room_entered): zone
## -> {word in the room id: sub-zone}. AmbienceZone nodes can place them too.
const SUB_ZONES := {
	&"egypt": {"tomb": &"egypt_tomb", "burial": &"egypt_tomb"},
	&"enlightenment": {"clock": &"enlightenment_clocks", "automat": &"enlightenment_clocks"},
	&"asia": {"garden": &"asia_garden", "tea": &"asia_garden"},
	&"basement": {"boiler": &"basement_boiler"},
}
## Added in a blackout.
const BLACKOUT_LAYERS := {&"dread": 0.0}
## Zones whose lamps die with the power cut (the rooms of
## NightObjective.DARK_ROOMS, the hall and its balcony).
const POWER_CUT_ZONES: Array[StringName] = [&"grand_hall"]
## Added there once the power is out: the emergency circuit's thin hum
## (not in a blackout night: its hall was dark all along).
const EMERGENCY_LAYERS := {&"mains_hum": -9.0}
## Seconds the lamps' layers take to die at the power cut (and how long
## falling layers fade that fast).
const CUT_FADE := 0.4
const CUT_TIME := 1.5
## Seconds between one-shots from the witching hour on.
const WITCHING_GAP := Vector2(7.0, 17.0)
## Dawn: far birds through the skylights, once (generated by
## tools/sfx/gen_sfx.py), this long after the dawn and this loud.
const DAWN_BIRDS := "res://assets/sfx/dawn_birds.wav"
const DAWN_BIRDS_DELAY := 1.2
const DAWN_BIRDS_DB := -12.0
const DEFAULT_ZONE := &"gallery"
## Rooms of the lobby (LobbyLevel.room_at) -> zone.
const ROOM_ZONES := {
	&"hall": &"grand_hall", &"balcony": &"grand_hall", &"gallery": &"gallery", &"armory": &"gallery",
	&"diorama": &"gallery", &"corridor_w": &"corridor", &"corridor_e": &"corridor", &"staff_corridor": &"corridor",
	&"vent": &"corridor", &"security": &"security", &"closet": &"secret", &"secret_chamber": &"secret",
	&"shotgun_niche": &"secret", &"undercroft": &"secret", &"stairwell": &"secret",
}
## Rooms -> [ReverbZone.Preset, send] for the automatic reverb zones.
const ROOM_REVERB := {
	&"hall": [ReverbZone.Preset.HALL, 0.5], &"balcony": [ReverbZone.Preset.HALL, 0.45],
	&"gallery": [ReverbZone.Preset.HALL, 0.3], &"armory": [ReverbZone.Preset.HALL, 0.3],
	&"diorama": [ReverbZone.Preset.HALL, 0.28], &"corridor_w": [ReverbZone.Preset.CORRIDOR, 0.35],
	&"corridor_e": [ReverbZone.Preset.CORRIDOR, 0.35], &"staff_corridor": [ReverbZone.Preset.CORRIDOR, 0.3],
	&"vent": [ReverbZone.Preset.CORRIDOR, 0.4], &"security": [ReverbZone.Preset.ROOM, 0.25],
	&"stairwell": [ReverbZone.Preset.CORRIDOR, 0.45],
}
const ROOM_REVERB_DEFAULT := [ReverbZone.Preset.ROOM, 0.25]
## A room of Floor I that ROOM_REVERB does not name: a word in its id
## first (ROOM_WORD_REVERB), else its zone (ZONE_REVERB).
const ROOM_WORD_REVERB := {"garden": [ReverbZone.Preset.GARDEN, 0.22], "corridor": [ReverbZone.Preset.CORRIDOR, 0.35],
	"boiler": [ReverbZone.Preset.STEEL, 0.4], "stair": [ReverbZone.Preset.CORRIDOR, 0.4],
	"library": [ReverbZone.Preset.LIBRARY, 0.3], "rotunda": [ReverbZone.Preset.VAST, 0.4],
	"store": [ReverbZone.Preset.STORE, 0.25], "cloak": [ReverbZone.Preset.STORE, 0.25], "cellar": [ReverbZone.Preset.STORE, 0.28],
	"lodge": [ReverbZone.Preset.STORE, 0.25], "closet": [ReverbZone.Preset.STORE, 0.25]}
const ZONE_REVERB := {
	&"court": [ReverbZone.Preset.VAST, 0.5], &"entrance": [ReverbZone.Preset.HALL, 0.42], &"booth": [ReverbZone.Preset.ROOM, 0.25],
	&"egypt": [ReverbZone.Preset.GALLERY, 0.45], &"assyria": [ReverbZone.Preset.GALLERY, 0.4],
	&"greece": [ReverbZone.Preset.HALL, 0.45], &"enlightenment": [ReverbZone.Preset.LIBRARY, 0.3],
	&"asia": [ReverbZone.Preset.ROOM, 0.3], &"americas": [ReverbZone.Preset.GALLERY, 0.38],
	&"north_hall": [ReverbZone.Preset.CORRIDOR, 0.35], &"basement": [ReverbZone.Preset.CONCRETE, 0.38],
	&"roof": [ReverbZone.Preset.OPEN, 0.15],
}
## One-shot kind -> number of takes (shot_<kind>_<n>.ogg).
const SHOTS := {&"thud": 4, &"creak": 5, &"door": 3, &"fall": 4, &"pipe": 2, &"tinkle": 2, &"groan": 2, &"steps": 2,
	&"glass": 3, &"sand": 3, &"stone": 3, &"beam": 2, &"drip": 3, &"page": 3, &"clock_strike": 3, &"chimes": 2,
	&"bamboo": 2, &"bell": 2, &"drum": 3, &"ember": 2, &"steam": 2, &"pane": 2, &"car": 2,
	# the ambient story (StoryLayer, data/audio/ambient_story.json; tools/music/ambience_story.py)
	&"settle": 3, &"vent_knock": 3, &"vent_surge": 2, &"phantom_steps": 2, &"shift_stone": 2, &"shift_wood": 2,
	&"shift_metal": 2, &"shift_soft": 2, &"whisper": 4, &"clock_chime": 2, &"clock_wind": 2, &"siren": 2, &"tram": 2,
	&"radio_chatter": 3, &"thunder": 3}
## Zone -> {kind: weight}.
const ZONE_SHOTS := {
	&"grand_hall": {&"thud": 3, &"door": 2, &"fall": 1, &"creak": 1, &"tinkle": 1},
	&"gallery": {&"creak": 4, &"tinkle": 2, &"fall": 1, &"thud": 1, &"door": 1},
	&"security": {&"door": 2, &"pipe": 2, &"creak": 1, &"thud": 1},
	&"corridor": {&"pipe": 3, &"thud": 2, &"door": 1, &"fall": 1},
	&"secret": {&"creak": 2, &"thud": 1},
	&"court": {&"glass": 3, &"creak": 1, &"thud": 1, &"door": 1, &"car": 1, &"pane": 1},
	&"entrance": {&"car": 3, &"door": 2, &"creak": 1, &"thud": 1},
	&"booth": {&"door": 2, &"pipe": 2, &"creak": 1, &"thud": 1},
	&"egypt": {&"sand": 3, &"stone": 2, &"creak": 1, &"thud": 1, &"fall": 1},
	&"egypt_tomb": {&"sand": 3, &"stone": 3, &"groan": 1},
	&"assyria": {&"beam": 3, &"stone": 2, &"ember": 1, &"thud": 1},
	&"greece": {&"drip": 3, &"tinkle": 1, &"creak": 1, &"stone": 1},
	&"enlightenment": {&"page": 3, &"clock_strike": 2, &"creak": 2, &"fall": 1},
	&"enlightenment_clocks": {&"clock_strike": 4, &"page": 1},
	&"asia": {&"chimes": 2, &"bell": 1, &"bamboo": 1, &"creak": 1},
	&"asia_garden": {&"bamboo": 3, &"chimes": 2, &"bell": 1},
	&"americas": {&"drum": 2, &"ember": 2, &"creak": 1, &"stone": 1},
	&"north_hall": {&"pipe": 2, &"door": 2, &"steps": 1, &"creak": 1},
	&"basement": {&"pipe": 3, &"steam": 2, &"drip": 2, &"groan": 1, &"thud": 1},
	&"basement_boiler": {&"steam": 3, &"pipe": 3, &"groan": 1},
	&"roof": {&"pane": 3, &"car": 2, &"glass": 1},
}
## Extra weights in a blackout.
const BLACKOUT_SHOTS := {&"groan": 3, &"steps": 1, &"thud": 2}
## One-shot level per kind (dB).
const SHOT_DB := {&"thud": -6.0, &"creak": -8.0, &"door": -6.0, &"fall": -7.0, &"pipe": -8.0, &"tinkle": -10.0,
	&"groan": -6.0, &"steps": -8.0, &"glass": -9.0, &"sand": -8.0, &"stone": -7.0, &"beam": -7.0, &"drip": -9.0,
	&"page": -9.0, &"clock_strike": -8.0, &"chimes": -9.0, &"bamboo": -8.0, &"bell": -8.0, &"drum": -8.0, &"ember": -8.0,
	&"steam": -9.0, &"pane": -8.0, &"car": -10.0}
## Seconds between one-shots (random in range).
const SHOT_GAP := Vector2(10.0, 24.0)
const BLACKOUT_GAP := Vector2(6.0, 15.0)
## How far from the listener one-shots sound (m).
const SHOT_DISTANCE := Vector2(10.0, 26.0)
## Distant sounds at once (the zone's far sounds and the ambient story's).
const MAX_SHOTS := 5
## Seconds of a zone crossfade.
const FADE := 2.0
const POLL := 0.25
## How fast the listener reverb follows (wet per second).
const LISTENER_RATE := 0.4
## dB per second the beds dip or come back (a haven, a sleeping guardian,
## dead air: StoryLayer's silences).
const DIP_RATE := 4.0
## Seconds a bed hushed by a story (the clocks stopping) takes to go and to come back.
const LAYER_HUSH_FADE := 0.12

## False in test runs until a test switches it on.
var enabled: bool = true
## The zone playing now (&"" = none).
var zone: StringName = &""
var manual_zone: StringName = &""
## The Floor I zone (or sub-zone) of the last Events.room_entered.
var event_zone: StringName = &""
var blackout: bool = false
## Layer -> AudioStreamPlayer (made at start, silent until needed).
var players: Dictionary = {}
## Layer -> current / target linear gain.
var levels: Dictionary = {}
var targets: Dictionary = {}
## True in a scene with the guard.
var active: bool = false
var rng := RandomNumberGenerator.new()
## The night in the lobby (reset with the scene unless it announced it).
var night := NightMood.new()
## Room acoustics: occlusion of positional sounds, the rooms' tails of shots
## and blasts (a child made in _ready; data/audio/acoustics.json).
var acoustics: Acoustics = null
## The ambient story: rare storytelling sounds, rain, deliberate silences
## (a child made in _ready; data/audio/ambient_story.json).
var story_layer: StoryLayer = null
## Rain tonight (StoryLayer decides; its beds join the rain's zones).
var rain: bool = false
## How far the beds are dipped now (dB; follows the story's silences).
var dip_db: float = 0.0

var _poll: float = 0.0
var _shot_timer: float = 8.0
var _shot_cache: Dictionary = {}
var _modifier_seen: StringName = &""
var _auto_reverb: Array[ReverbZone] = []
var _listener_zone: ReverbZone = null
var _sfx_reverb: AudioEffectReverb = null
var _sfx_wet: float = 0.0
var _quitting: bool = false
## Seconds the power cut's quick fades still last.
var _cut_left: float = 0.0
## Seconds until the dawn's birds (negative: none waiting).
var _birds_in: float = -1.0
## Process frame of the last Events.room_entered (kept over a scene swap
## only when announced while the scene set up).
var _event_frame: int = -100
var _birds: AudioStreamPlayer = null
## Layer -> seconds it stays hushed (a story: the clocks stop).
var _layer_hush: Dictionary = {}
## Layer -> 0..1 how far it is hushed now.
var _layer_mute: Dictionary = {}


func _ready() -> void:
	enabled = AudioContext.automatic()
	rng.randomize()
	Acoustics.ensure_buses()   # the reverb and occlusion buses, also in test runs
	acoustics = Acoustics.new()
	acoustics.name = "Acoustics"
	add_child(acoustics)
	story_layer = StoryLayer.new()
	story_layer.name = "Story"
	add_child(story_layer)
	for layer in LAYERS:
		levels[layer] = 0.0
		targets[layer] = 0.0
		_make_bed(layer)
	for kind: StringName in SHOTS:
		_shot_streams(kind)
	if ResourceLoader.exists(DAWN_BIRDS):
		_birds = AudioStreamPlayer.new()
		_birds.name = "DawnBirds"
		_birds.stream = load(DAWN_BIRDS)
		_birds.bus = BUS
		add_child(_birds)
	follow_sfx_bus()
	Settings.settings_changed.connect(func(_key: StringName) -> void: follow_sfx_bus())
	get_tree().scene_changed.connect(_on_scene_changed)
	Events.night_started.connect(_on_night_started)
	Events.objective_changed.connect(_on_objective_changed)
	Events.power_cut.connect(_on_power_cut)
	Events.witching_hour.connect(_on_witching_hour)
	Events.dawn_broke.connect(_on_dawn_broke)
	Events.room_entered.connect(_on_room_entered)
	Sfx.child_entered_tree.connect(_on_sfx_voice)
	if Sfx.has_signal(&"quitting"):
		Sfx.connect(&"quitting", _on_quitting)
	_on_scene_changed.call_deferred()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		stop_all()


## Plays [param zone_id] from now on, whatever the rooms say (&"" = back
## to automatic).
func set_zone(zone_id: StringName) -> void:
	manual_zone = zone_id
	refresh()


func set_blackout(on: bool) -> void:
	blackout = on
	_apply_zone(zone, true)


## Switches ambience on for a scene with the guard (what a scene swap does
## when automation is on) or off.
func set_active(on: bool) -> void:
	active = on
	refresh()


## Re-evaluates the zone now.
func refresh() -> void:
	_apply_zone(_resolve_zone(), false)


## Stops every bed and one-shot at once.
func stop_all() -> void:
	for layer: StringName in players:
		(players[layer] as AudioStreamPlayer).stop()
	for layer in LAYERS:
		levels[layer] = 0.0
		targets[layer] = 0.0
	zone = &""
	for child in get_children():
		if child is AudioStreamPlayer3D:
			(child as AudioStreamPlayer3D).stop()
			remove_child(child)
			child.queue_free()
	acoustics.stop_all()
	if _birds != null:
		_birds.stop()
	_birds_in = -1.0
	_cut_left = 0.0
	dip_db = 0.0
	_layer_hush.clear()
	_layer_mute.clear()
	_set_listener_wet(0.0)


## Forgets the scene and its night: silence, no zones of its own, no
## listener reverb on the SFX bus, automation state reset.
func reset() -> void:
	night.reset()
	story_layer.reset()
	rain = false
	event_zone = &""
	_event_frame = -100
	_forget_scene()


func _forget_scene() -> void:
	stop_all()
	manual_zone = &""
	if Engine.get_process_frames() - _event_frame > NightMood.SETUP_FRAMES:
		event_zone = &""
	active = false
	blackout = false
	_clear_auto_reverb()
	acoustics.forget()
	if _sfx_reverb != null:
		var bus := AudioServer.get_bus_index(SFX_BUS)
		for i in range(AudioServer.get_bus_effect_count(bus) - 1, -1, -1):
			if AudioServer.get_bus_effect(bus, i) == _sfx_reverb:
				AudioServer.remove_bus_effect(bus, i)
		_sfx_reverb = null
		_sfx_wet = 0.0


## The SFX bus effect that carries the listener's room (null when none).
func listener_reverb() -> AudioEffectReverb:
	return _sfx_reverb


## The reverb zone the listener stands in, as last looked (every POLL s
## while a scene with the guard runs); null when none or not looked.
func listener_zone() -> ReverbZone:
	return _listener_zone if _listener_zone != null and is_instance_valid(_listener_zone) else null


func _process(delta: float) -> void:
	if not enabled or _quitting:
		return
	_poll -= delta
	if _poll <= 0.0:
		_poll = POLL
		if active and RunState.modifier != _modifier_seen:
			_modifier_seen = RunState.modifier
			blackout = _modifier_seen == &"blackout" or night.modifier == &"blackout"
			_apply_zone(zone, true)   # same zone, other layers
		refresh()
		_update_listener_zone()
		if active:
			story_layer.tick(POLL)
		if rain != (active and story_layer.raining):
			rain = active and story_layer.raining
			_apply_zone(zone, true)
	advance(delta)
	if _birds_in >= 0.0:
		_birds_in -= delta
		if _birds_in < 0.0:
			play_dawn_birds()
	if active and not night.dawn:
		tick_shots(delta)


## The zone's far sounds: one every shot_gap() s, unless the story keeps a
## silence (a haven, a sleeping guardian, dead air, the voice): then that
## one is skipped.
func tick_shots(delta: float) -> void:
	_shot_timer -= delta
	if _shot_timer > 0.0:
		return
	var gap := shot_gap()
	_shot_timer = rng.randf_range(gap.x, gap.y)
	var kind := pick_shot_kind()
	if kind != &"" and not story_layer.story.silent():
		play_shot(kind)


## Seconds between one-shots (random in the range) right now.
func shot_gap() -> Vector2:
	if is_dark(zone):
		return BLACKOUT_GAP
	if night.witching:
		return WITCHING_GAP
	return SHOT_GAP


## True when [param zone_id] lost its lamps tonight: a blackout night, or
## the power cut in the hall.
func is_dark(zone_id: StringName) -> bool:
	return blackout or power_cut_in(zone_id)


## True when the power cut (not a blackout night) darkened [param zone_id].
func power_cut_in(zone_id: StringName) -> bool:
	return not blackout and night.power_out() and POWER_CUT_ZONES.has(zone_id)


## Moves every bed toward its target (and the listener reverb). Right after
## the power cut falling layers fade within CUT_FADE s.
func advance(delta: float) -> void:
	acoustics.advance(delta)
	_cut_left = maxf(_cut_left - delta, 0.0)
	dip_db = move_toward(dip_db, story_layer.story.bed_dip_db() if active else 0.0, delta * DIP_RATE)
	for layer: StringName in _layer_hush.keys():
		_layer_hush[layer] = float(_layer_hush[layer]) - delta
		if float(_layer_hush[layer]) <= 0.0:
			_layer_hush.erase(layer)
	for layer: StringName in _layer_mute.keys():
		_layer_mute[layer] = move_toward(float(_layer_mute[layer]), 1.0 if _layer_hush.has(layer) else 0.0, delta / LAYER_HUSH_FADE)
		if float(_layer_mute[layer]) <= 0.0 and not _layer_hush.has(layer):
			_layer_mute.erase(layer)
	for layer in LAYERS:
		var fade := CUT_FADE if _cut_left > 0.0 and targets[layer] < levels[layer] else FADE
		var level: float = move_toward(levels[layer], targets[layer], delta / fade)
		levels[layer] = level
		var player := players.get(layer) as AudioStreamPlayer
		if level > 0.0 and player == null:
			player = _make_bed(layer)
		if player == null:
			continue
		var level_db := -80.0
		if level > 0.0001:
			level_db = maxf(linear_to_db(level) + dip_db - 70.0 * float(_layer_mute.get(layer, 0.0)), -80.0)
		if player.volume_db != level_db:
			player.volume_db = level_db
		if level > 0.0 and not player.playing and player.stream != null:
			player.play(rng.randf() * player.stream.get_length())
		elif level <= 0.0 and targets[layer] <= 0.0 and player.playing:
			player.stop()
	if _sfx_reverb != null:
		var goal := 0.0
		if _listener_zone != null and is_instance_valid(_listener_zone):
			goal = float(_listener_zone.listener_reverb()[2])
		_set_listener_wet(move_toward(_sfx_wet, goal, delta * LISTENER_RATE))


## A one-shot kind for the current zone (weights of ZONE_SHOTS, plus
## BLACKOUT_SHOTS where it is dark); &"" without a zone.
func pick_shot_kind() -> StringName:
	if zone == &"":
		return &""
	var weights: Dictionary = (ZONE_SHOTS.get(zone, ZONE_SHOTS[DEFAULT_ZONE]) as Dictionary).duplicate()
	if is_dark(zone):
		for kind: StringName in BLACKOUT_SHOTS:
			weights[kind] = int(weights.get(kind, 0)) + int(BLACKOUT_SHOTS[kind])
	var total := 0
	for kind: StringName in weights:
		total += int(weights[kind])
	var roll := rng.randi_range(0, total - 1)
	for kind: StringName in weights:
		roll -= int(weights[kind])
		if roll < 0:
			return kind
	return &""


## Plays a distant [param kind] somewhere around the listener (or at
## [param at]). Returns the player, or null.
func play_shot(kind: StringName, at: Variant = null) -> AudioStreamPlayer3D:
	var takes := _shot_streams(kind)
	if takes.is_empty() or _quitting or _shot_count() >= MAX_SHOTS:
		return null
	var where: Variant = at
	if where == null:
		var ears: Variant = AudioContext.listener_position(get_viewport())
		if ears == null:
			return null
		var angle := rng.randf() * TAU
		var distance := rng.randf_range(SHOT_DISTANCE.x, SHOT_DISTANCE.y)
		where = (ears as Vector3) + Vector3(cos(angle) * distance, rng.randf_range(-1.0, 4.0), sin(angle) * distance)
	return _spawn_far(takes[rng.randi_range(0, takes.size() - 1)], where, SHOT_DB.get(kind, -8.0), rng.randf_range(0.92, 1.06), 14.0)


func _shot_count() -> int:
	var count := 0
	for child in get_children():
		if child is AudioStreamPlayer3D and not child.is_queued_for_deletion():
			count += 1
	return count


func _spawn_far(stream: AudioStream, where: Vector3, db: float, pitch: float, unit: float) -> AudioStreamPlayer3D:
	var player := AudioStreamPlayer3D.new()
	player.stream = stream
	player.bus = BUS
	player.volume_db = db
	player.unit_size = unit
	player.max_distance = 120.0
	player.area_mask = 0   # the space is baked into the sound
	player.pitch_scale = pitch
	player.position = where
	add_child(player)
	player.play()
	player.finished.connect(player.queue_free)
	return player


## Builds reverb zones for [param level] from its layout's rooms (one per
## room part, ROOM_REVERB presets). They live under this node, in the same
## world, and go when the scene does.
func build_reverb(level: Node) -> Array[ReverbZone]:
	var made: Array[ReverbZone] = []
	var layout: Variant = level.get(&"layout") if level != null else null
	if layout == null or not (layout is Object) or not ("rooms" in layout):
		return made
	for room: Variant in layout.get(&"rooms"):
		var spec: Array = reverb_for(room.id, room.zone if "zone" in room else &"")
		for part: Rect2 in room.parts:
			var box := AABB(Vector3(part.position.x, room.floor_y, part.position.y),
					Vector3(part.size.x, room.ceiling_y - room.floor_y, part.size.y))
			var reverb := ReverbZone.make(spec[0], box, spec[1])
			reverb.name = "Reverb_%s" % room.id
			# the listener's room: a balcony beats the hall below it (sounds
			# themselves go to the first zone Godot finds; both are HALL here)
			reverb.priority = int(room.floor_y) + 1
			add_child(reverb)
			made.append(reverb)
	_auto_reverb.append_array(made)
	return made


## [preset, send] for a level room: ROOM_REVERB by id, then the room
## table of data/audio/acoustics.json (every room of Floor I), then a word
## of its id (ROOM_WORD_REVERB), then its Floor I zone (ZONE_REVERB).
static func reverb_for(room_id: StringName, room_zone: StringName = &"") -> Array:
	if ROOM_REVERB.has(room_id):
		return ROOM_REVERB[room_id]
	var listed := Acoustics.room_reverb(room_id)
	if not listed.is_empty():
		return listed
	if room_zone != &"":
		for word: String in ROOM_WORD_REVERB:
			if String(room_id).contains(word):
				return ROOM_WORD_REVERB[word]
		var wing := StringName(String(room_zone).get_slice("_", 0))
		if ZONE_REVERB.has(room_zone):
			return ZONE_REVERB[room_zone]
		if ZONE_REVERB.has(wing):
			return ZONE_REVERB[wing]
	return ROOM_REVERB_DEFAULT


## The ambience zone of a Floor I room: the zone's sub-zone when the room's
## id holds one of SUB_ZONES' words, else the zone itself.
static func floor_zone(room_id: StringName, zone_id: StringName) -> StringName:
	var subs: Dictionary = SUB_ZONES.get(zone_id, {})
	for word: String in subs:
		if String(room_id).contains(word):
			return subs[word]
	return zone_id


func _resolve_zone() -> StringName:
	if not active:
		return &""
	var body := AudioContext.guard(get_tree()) as Player
	if body != null and not body.alive:
		return &""   # the world recedes while the guard is down (back on a respawn)
	if manual_zone != &"":
		return manual_zone
	var ears: Variant = AudioContext.listener_position(get_viewport())
	if ears != null:
		var best: AmbienceZone = null
		for node in get_tree().get_nodes_in_group(&"ambience_zones"):
			var area := node as AmbienceZone
			if area != null and area.contains(ears) and (best == null or area.priority > best.priority):
				best = area
		if best != null:
			return best.zone
		if event_zone != &"" and ZONES.has(event_zone):
			return event_zone
		var room := AudioContext.room_at(get_tree(), ears)
		if ROOM_ZONES.has(room):
			return ROOM_ZONES[room]
	return DEFAULT_ZONE


func _apply_zone(next: StringName, force: bool) -> void:
	if next == zone and not force:
		return
	zone = next
	for layer in LAYERS:
		targets[layer] = 0.0
	if zone == &"":
		return
	var mix: Dictionary = ZONES.get(zone, ZONES[DEFAULT_ZONE])
	var dark := is_dark(zone)
	for layer: StringName in mix:
		if dark and ELECTRIC.has(layer):
			continue
		targets[layer] = db_to_linear(float(mix[layer]))
	if power_cut_in(zone):
		for layer: StringName in EMERGENCY_LAYERS:
			targets[layer] = db_to_linear(float(EMERGENCY_LAYERS[layer]))
	if dark and not night.dawn:
		for layer: StringName in BLACKOUT_LAYERS:
			targets[layer] = db_to_linear(float(BLACKOUT_LAYERS[layer]))
	if rain:
		var mix_rain := rain_mix(zone)
		for layer: StringName in mix_rain:
			targets[layer] = db_to_linear(float(mix_rain[layer]))


## {layer: dB} of the rain heard in [param zone_id] (the rain's zones of
## data/audio/ambient_story.json: the zone's own entry, else its parent
## zone's - egypt_tomb takes egypt's).
static func rain_mix(zone_id: StringName) -> Dictionary:
	var zones: Dictionary = AmbientStory.data().get("rain", {}).get("zones", {})
	var found: Variant = zones.get(String(zone_id))
	if found == null:
		found = zones.get(String(zone_id).get_slice("_", 0))
	var mix := {}
	if found is Dictionary:
		for layer: String in found:
			mix[StringName(layer)] = float(found[layer])
	return mix


## Hushes bed [param layer] for [param seconds] (quickly out, quickly back).
func hush_layer(layer: StringName, seconds: float) -> void:
	_layer_hush[layer] = seconds
	if not _layer_mute.has(layer):
		_layer_mute[layer] = 0.0


## Plays a take of story sound [param kind] at [param at] on the Ambience
## bus (distance baked in: no zone reverb), [param db] loud, at
## [param pitch], heard as far as [param unit] makes it. Shares the far
## sounds' MAX_SHOTS. Returns the player, or null.
func play_story(kind: StringName, at: Vector3, db: float, pitch: float = 1.0, unit: float = 12.0) -> AudioStreamPlayer3D:
	var takes := _shot_streams(kind)
	if takes.is_empty() or _quitting or _shot_count() >= MAX_SHOTS:
		return null
	var player := _spawn_far(takes[rng.randi_range(0, takes.size() - 1)], at, db, pitch, unit)
	player.set_meta(&"story", kind)
	return player


func _make_bed(layer: StringName) -> AudioStreamPlayer:
	var path := DIR + "bed_" + String(layer) + ".ogg"
	if not ResourceLoader.exists(path):
		return null
	var player := AudioStreamPlayer.new()
	player.name = "Bed_" + String(layer)
	player.stream = load(path)
	player.bus = BUS
	player.volume_db = -80.0
	add_child(player)
	players[layer] = player
	return player


func _shot_streams(kind: StringName) -> Array[AudioStream]:
	if not _shot_cache.has(kind):
		var takes: Array[AudioStream] = []
		for n in range(1, int(SHOTS.get(kind, 0)) + 1):
			var path := SHOT_DIR + "shot_%s_%d.ogg" % [kind, n]
			if ResourceLoader.exists(path):
				takes.append(load(path))
		_shot_cache[kind] = takes
	return _shot_cache[kind]


func _update_listener_zone() -> void:
	_listener_zone = null
	if not active:
		return
	var ears: Variant = AudioContext.listener_position(get_viewport())
	if ears == null:
		return
	for node in get_tree().get_nodes_in_group(&"reverb_zones"):
		var reverb := node as ReverbZone
		if reverb != null and reverb.contains(ears) and (_listener_zone == null or reverb.priority > _listener_zone.priority):
			_listener_zone = reverb
	if _listener_zone != null:
		_ensure_sfx_reverb()
		if _sfx_reverb == null:
			return
		var params: Array = _listener_zone.listener_reverb()
		if _sfx_reverb.room_size != float(params[0]) or _sfx_reverb.damping != float(params[1]):
			_sfx_reverb.room_size = params[0]
			_sfx_reverb.damping = params[1]


func _ensure_sfx_reverb() -> void:
	if _sfx_reverb != null:
		return
	var bus := AudioServer.get_bus_index(SFX_BUS)
	if bus < 0:
		return
	_sfx_reverb = AudioEffectReverb.new()
	_sfx_reverb.resource_name = "ListenerRoom"
	_sfx_reverb.dry = 1.0
	_sfx_reverb.wet = 0.0
	_sfx_reverb.spread = 0.8
	_sfx_reverb.hipass = 0.2
	_sfx_reverb.predelay_msec = 25.0
	AudioServer.add_bus_effect(bus, _sfx_reverb)
	_set_listener_wet(0.0, true)


## Sets the listener reverb's wet level (the effect is bypassed while dry);
## nothing is touched when it does not change.
func _set_listener_wet(wet: float, force: bool = false) -> void:
	if wet == _sfx_wet and not force:
		return
	var was_on := _sfx_wet > 0.001
	_sfx_wet = wet
	if _sfx_reverb == null:
		return
	_sfx_reverb.wet = wet
	var on := wet > 0.001
	if on == was_on and not force:
		return
	var bus := AudioServer.get_bus_index(SFX_BUS)
	for i in AudioServer.get_bus_effect_count(bus):
		if AudioServer.get_bus_effect(bus, i) == _sfx_reverb:
			AudioServer.set_bus_effect_enabled(bus, i, on)


## Keeps RETURN_BUS at the SFX bus's volume and mute (called when the
## options change and once at start).
func follow_sfx_bus() -> void:
	var sfx := AudioServer.get_bus_index(SFX_BUS)
	var tails := AudioServer.get_bus_index(RETURN_BUS)
	if sfx < 0 or tails < 0:
		return
	AudioServer.set_bus_volume_db(tails, AudioServer.get_bus_volume_db(sfx))
	AudioServer.set_bus_mute(tails, AudioServer.is_bus_mute(sfx))


func _clear_auto_reverb() -> void:
	for reverb in _auto_reverb:
		if is_instance_valid(reverb):
			remove_child(reverb)
			reverb.queue_free()
	_auto_reverb.clear()
	_listener_zone = null


func _on_scene_changed() -> void:
	if not enabled:
		return
	var game := AudioContext.scene_kind(get_tree().current_scene) == AudioContext.GAME
	if not night.claims(game):
		night.reset()   # a scene without a night of its own
		story_layer.reset()
	_forget_scene()
	active = game
	_modifier_seen = RunState.modifier
	blackout = _modifier_seen == &"blackout" or night.modifier == &"blackout"
	_shot_timer = rng.randf_range(4.0, 10.0)
	if active and not _has_own_reverb():
		build_reverb(AudioContext.level(get_tree()))
	refresh()


func _has_own_reverb() -> bool:
	for node in get_tree().get_nodes_in_group(&"reverb_zones"):
		if not _auto_reverb.has(node):
			return true
	return false


## Sfx voices hear the reverb zones (their layer is not in the default
## area_mask).
func _on_sfx_voice(voice: Node) -> void:
	if not enabled:
		return
	if voice is AudioStreamPlayer3D:
		(voice as AudioStreamPlayer3D).area_mask |= Layers.REVERB_ZONE
	acoustics.on_voice(voice)


func _on_quitting() -> void:
	_quitting = true
	stop_all()


## Plays the dawn's far birds (on the Ambience bus, flat: they come in
## through every skylight at once). Returns the player, or null.
func play_dawn_birds() -> AudioStreamPlayer:
	_birds_in = -1.0
	if _quitting or _birds == null:
		return null
	_birds.volume_db = DAWN_BIRDS_DB
	_birds.play()
	return _birds


func _on_night_started(number: int, modifier: StringName) -> void:
	if not enabled:
		return
	night.start_night(number, modifier)
	blackout = RunState.modifier == &"blackout" or night.modifier == &"blackout"
	_apply_zone(zone, true)


func _on_objective_changed(stage: int) -> void:
	if not enabled:
		return
	var was_out := night.power_out()
	night.set_stage(stage)
	if night.power_out() != was_out:
		_apply_zone(zone, true)


## The hall's lamps die: their layers go at once, the dread swells in.
func _on_power_cut() -> void:
	if not enabled:
		return
	night.cut_power()
	_cut_left = CUT_TIME
	_apply_zone(zone, true)


## Events.room_entered: Floor I tells which zone the guard is in.
func _on_room_entered(room: StringName, zone_id: StringName, _first_visit: bool) -> void:
	if not enabled:
		return
	_event_frame = Engine.get_process_frames()
	event_zone = floor_zone(room, zone_id)
	refresh()


func _on_witching_hour() -> void:
	if not enabled:
		return
	night.ring_witching()
	_shot_timer = minf(_shot_timer, rng.randf_range(WITCHING_GAP.x, WITCHING_GAP.y))


func _on_dawn_broke() -> void:
	if not enabled or night.dawn:
		return
	night.break_dawn()
	_apply_zone(zone, true)
	if active:
		_birds_in = DAWN_BIRDS_DELAY
