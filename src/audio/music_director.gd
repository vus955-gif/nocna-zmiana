class_name MusicDirector
extends RefCounted
## What the music should do (pure logic; the Music autoload plays it).
## Fed with the kind of scene (AudioContext), game events and, every frame,
## how many awake exhibits are near the listener. States:
## - SILENT: nothing (tests, loading, the guard fell, dawn),
## - MENU: the menu theme (main menu and the end screen),
## - EXPLORE: the night walk,
## - TENSION: exploration plus the tension stem (exhibits awake nearby, a
##   fight that just ended, or the night's goal: power out, crystal loose),
## - COMBAT: the combat track; its hi stem follows [member intensity],
## - BOSS: the T-Rex track; its hi stem from phase 2 on,
## - VICTORY: the victory sting, then back to EXPLORE.
## Combat holds COMBAT_HOLD seconds after the last hit, kill or wound (an
## exhibit in melee range counts as a fight too), then TENSION lingers
## TENSION_HOLD seconds or while exhibits hunt nearby. Inside a haven the
## hunters do not count and a fight winds down twice as fast.
## The night's story ([member night], a NightMood the Music autoload feeds
## from the lobby's Events hooks) shapes the walk and the tension stem:
## - the first night and a calm one walk quieter (QUIET_WALK),
## - a full moon keeps a little of the tension stem under the walk
##   (MOON_TENSION); from the witching hour on, more of it (WITCHING_TENSION),
## - the power cut hushes the night music (HUSH_LEVEL) for HUSH_TIME s,
##   then it comes back as TENSION with the stem at POWER_TENSION (the
##   walk at its night's level: TENSION is full only while hunted),
## - the crystal's flight (and a boss stage without a live boss) brings the
##   stem in full,
## - after the T-Rex, the victory sting, then a quiet walk without tension,
## - dawn fades everything out (DAWN_FADE in Music) and stays silent.
## Floor I (the museum floor's zones, Events.room_entered):
## - every music zone (MUSIC_ZONES: the six wings, the hub, the basement,
##   the roof) plays its own loop in four synced stems (ZONE_LAYERS: the
##   walk, its tension, the fight and the fight's hi stem), so a change of
##   intensity lands on the beat; [member variant] is the music zone around
##   the guard (&"" = the lobby's music). A new zone must hold
##   VARIANT_SETTLE s before the walk changes (no flicker on a threshold),
##   FIGHT_SETTLE s in a fight (a fight on a doorway keeps its music), at
##   once while nothing of the zone plays (night start, a guardian),
## - a wing guardian (on_guardian_awakened) brings GUARDIAN: the guardians'
##   theme in its wing's colours (GUARDIAN_WINGS), its hi stem from phase 2
##   or in a hot fight; its fall plays the guardian sting (VICTORY for
##   GUARDIAN_VICTORY_TIME s), then the walk returns. The T-Rex beats a
##   guardian.
## - the first room of a wing not met before in this session, on a first
##   visit, asks for the wing's discovery sting (on_room_entered).

signal state_changed(from: State, to: State)

enum State { SILENT, MENU, EXPLORE, TENSION, COMBAT, BOSS, VICTORY, GUARDIAN }

## Seconds without a combat event before COMBAT gives way.
const COMBAT_HOLD := 8.0
## Seconds TENSION lingers after the last threat (or after the fight).
const TENSION_HOLD := 6.0
## Seconds the victory sting owns the music.
const VICTORY_TIME := 7.0
## Intensity (0..1) added by events.
const HIT_HEAT := 0.06
const KILL_HEAT := 0.14
const HURT_HEAT := 0.12
const SHOT_HEAT := 0.01
## Intensity starts to fall this long after the last event, at DECAY per s.
const INTENSITY_HOLD := 3.0
const INTENSITY_DECAY := 0.08
## Each awake exhibit nearby keeps the intensity at least this high (in
## COMBAT), up to THREAT_FLOOR.
const THREAT_HEAT := 0.1
const THREAT_FLOOR := 0.6
## The combat hi stem fades in between these intensities.
const HI_FROM := 0.3
const HI_TO := 0.6
## The night's story (see above): walk level on a quiet night, the tension
## stem under the walk on a full moon / after 3:00, its level while the
## power is out, the hush after the power cut (level and seconds).
const QUIET_WALK := 0.45
const MOON_TENSION := 0.3
const WITCHING_TENSION := 0.45
const POWER_TENSION := 0.5
const HUSH_LEVEL := 0.05
const HUSH_TIME := 3.0
## Every logical music layer (a file in res://assets/music/, or one per
## music zone / wing: Music.track()).
const LAYERS: Array[StringName] = [&"menu", &"explore", &"explore_tension", &"combat", &"combat_hi", &"boss", &"boss_hi",
	&"guardian", &"guardian_hi"]
## Layers played in the music zone's colours (one synced loop per zone),
## and in the guardian's wing.
const ZONE_LAYERS: Array[StringName] = [&"explore", &"explore_tension", &"combat", &"combat_hi"]
const GUARDIAN_LAYERS: Array[StringName] = [&"guardian", &"guardian_hi"]
## Floor I's wings (Floor1Plan zone ids): a guardian and a discovery sting
## each.
const WINGS: Array[StringName] = [&"egypt", &"assyria", &"greece", &"enlightenment", &"asia", &"americas"]
## Floor I's music zones: the wings, the hub (HUB_ZONES), the basement and
## the roof.
const MUSIC_ZONES: Array[StringName] = [&"court", &"egypt", &"assyria", &"greece", &"enlightenment", &"asia", &"americas",
	&"basement", &"roof"]
## Floor1Plan zones that play the hub's music (&"court").
const HUB_ZONES: Array[StringName] = [&"court", &"entrance", &"booth", &"north_hall"]
## A wing guardian's id (or its prefix) -> its wing.
const GUARDIAN_WINGS := {&"colossus": &"egypt", &"lamassu": &"assyria", &"centaur": &"greece", &"orrery": &"enlightenment",
	&"samurai": &"asia", &"serpent": &"americas",
	# Floor1Plan's ids for the Enlightenment and Asia guardians
	&"planetarium": &"enlightenment", &"general": &"asia"}
## Seconds a new zone must hold before the walk takes its variant (and
## how long a fresh walk may still switch at once).
const VARIANT_SETTLE := 1.0
## Seconds a new zone must hold in a fight before the fight's music moves.
const FIGHT_SETTLE := 4.0
## Seconds the guardian's fall sting owns the music.
const GUARDIAN_VICTORY_TIME := 5.0
## The stings of a fall: the T-Rex's and a guardian's.
const BOSS_STING := &"victory_sting"
const GUARDIAN_STING := &"guardian_sting"

## AudioContext kind: OFF, MENU, END or GAME.
var mode: StringName = AudioContext.OFF
var state: State = State.SILENT
## 0..1, how hot the fight is.
var intensity: float = 0.0
var boss_active: bool = false
var boss_phase: int = 0
var dead: bool = false
## Awake exhibits near the listener (0 inside a haven).
var threats: int = 0
var sheltered: bool = false
## A state forced from outside (hold()), or -1.
var held: int = -1
## The night in the lobby (kept across set_mode(); Music resets it).
var night := NightMood.new()
## Floor I zone of the listener (Floor1Plan id, &"" = none announced) and
## the music zone (MUSIC_ZONES) whose loop plays - the walk and the fights
## alike (&"" = the lobby's music). Kept across set_mode().
var zone: StringName = &""
var variant: StringName = &""
var guardian_active: bool = false
var guardian_id: StringName = &""
var guardian_wing: StringName = &""
var guardian_phase: int = 0
## The sting VICTORY plays (BOSS_STING or GUARDIAN_STING).
var victory_sting: StringName = BOSS_STING
## Wings met in this session (their discovery sting has had its turn).
var known_wings: Dictionary = {}

var _since_combat: float = INF
var _since_threat: float = INF
var _since_heat: float = INF
var _victory_left: float = 0.0
var _hush_left: float = 0.0
var _pending_variant: StringName = &""
var _settle_left: float = 0.0
## Seconds the walk has been playing since set_mode().
var _walked: float = 0.0


## A new scene: gameplay memory is cleared.
func set_mode(kind: StringName) -> void:
	mode = kind
	intensity = 0.0
	boss_active = false
	boss_phase = 0
	dead = false
	threats = 0
	sheltered = false
	_since_combat = INF
	_since_threat = INF
	_since_heat = INF
	_victory_left = 0.0
	_hush_left = 0.0
	guardian_active = false
	guardian_id = &""
	guardian_phase = 0
	victory_sting = BOSS_STING
	_settle_left = 0.0
	_pending_variant = variant
	_walked = 0.0
	_refresh()


## A hit, a kill, a wound or a shot (heat = how much it adds).
func on_combat(heat: float) -> void:
	if mode != AudioContext.GAME or dead:
		return
	_since_combat = 0.0
	if heat > 0.0:
		_since_heat = 0.0
		intensity = minf(1.0, intensity + heat)
	_refresh()


func on_player_died() -> void:
	if mode != AudioContext.GAME:
		return
	dead = true
	_refresh()


## The guard stands again in the same scene (the sandbox and the dev
## viewers respawn him in place): the night music comes back.
func on_player_revived() -> void:
	if not dead:
		return
	dead = false
	intensity = 0.0
	_since_combat = INF
	_since_threat = INF
	_since_heat = INF
	_refresh()


func on_boss_awakened() -> void:
	if mode != AudioContext.GAME or dead:
		return
	boss_active = true
	boss_phase = 1   # a fresh boss (the T-Rex reports later phases itself)
	_refresh()


func on_boss_phase(phase: int) -> void:
	boss_phase = phase


## The boss left without being defeated (a dev reset): no victory.
func on_boss_gone() -> void:
	if not boss_active:
		return
	boss_active = false
	boss_phase = 0
	_refresh()


func on_boss_defeated() -> void:
	if mode != AudioContext.GAME or not boss_active:
		return
	boss_active = false
	boss_phase = 0
	intensity = 0.0
	_since_combat = INF
	_since_threat = INF
	_victory_left = VICTORY_TIME
	victory_sting = BOSS_STING
	_refresh()


# --- Floor I -----------------------------------------------------------------

## The wing a Floor I zone belongs to: the zone itself, or the part before
## its first underscore (sub-zones such as &"asia_garden"); &"" for the
## court, the halls, the basement and the roof.
static func wing_of_zone(zone_id: StringName) -> StringName:
	if WINGS.has(zone_id):
		return zone_id
	var head := StringName(String(zone_id).get_slice("_", 0))
	return head if WINGS.has(head) else &""


## The music zone (MUSIC_ZONES) a Floor I zone plays: its wing, the hub
## for the court and its halls, the basement, the roof (sub-zones such as
## &"basement_boiler" too); &"" for anything else (the lobby's music).
static func music_zone_of(zone_id: StringName) -> StringName:
	var wing := wing_of_zone(zone_id)
	if wing != &"":
		return wing
	var head := StringName(String(zone_id).get_slice("_", 0))
	if HUB_ZONES.has(zone_id) or HUB_ZONES.has(head):
		return &"court"
	if MUSIC_ZONES.has(head):
		return head
	return &""


## The wing of a guardian: GUARDIAN_WINGS by id or by prefix
## (&"colossus_ramesses"), an id naming a wing (&"egypt"), else the wing
## of [param fallback_zone], else the first wing.
static func guardian_wing_of(id: StringName, fallback_zone: StringName = &"") -> StringName:
	if GUARDIAN_WINGS.has(id):
		return GUARDIAN_WINGS[id]
	var own := wing_of_zone(id)
	if own != &"":
		return own
	for key: StringName in GUARDIAN_WINGS:
		if String(id).begins_with(String(key)):
			return GUARDIAN_WINGS[key]
	var here := wing_of_zone(fallback_zone)
	return here if here != &"" else WINGS[0]


## The listener walked into [param zone_id]: the music follows its music
## zone, after VARIANT_SETTLE s while a walk plays, FIGHT_SETTLE s in a
## fight (at once otherwise).
func on_zone(zone_id: StringName) -> void:
	zone = zone_id
	var music := music_zone_of(zone_id)
	if music == variant:
		_pending_variant = music
		_settle_left = 0.0
		return
	var walking := state == State.EXPLORE or state == State.TENSION
	if state == State.COMBAT:
		if music != _pending_variant or _settle_left <= 0.0:
			_settle_left = FIGHT_SETTLE
	elif not walking or _walked < VARIANT_SETTLE:
		variant = music
		_settle_left = 0.0
	else:
		_settle_left = VARIANT_SETTLE
	_pending_variant = music
	_refresh()


## Events.room_entered: follows the zone and returns the discovery sting
## to play (&"wing_sting_<wing>") the first time a wing is met on a first
## visit, outside a fight; &"" otherwise.
func on_room_entered(zone_id: StringName, first_visit: bool) -> StringName:
	on_zone(zone_id)
	var wing := wing_of_zone(zone_id)
	if wing == &"" or known_wings.has(wing):
		return &""
	known_wings[wing] = true
	var calm := state == State.EXPLORE or state == State.TENSION
	if not first_visit or not calm or mode != AudioContext.GAME or dead:
		return &""
	return StringName("wing_sting_" + String(wing))


## Wings already discovered in an earlier session (a save) get no sting.
func remember_wings(wings: Array) -> void:
	for wing: Variant in wings:
		known_wings[StringName(str(wing))] = true


## No zone announced (a scene without Floor I): the lobby's walk.
func forget_zone() -> void:
	zone = &""
	variant = &""
	_pending_variant = &""
	_settle_left = 0.0
	_refresh()


## Events.guardian_awakened: the guardians' theme in [param id]'s wing.
func on_guardian_awakened(id: StringName) -> void:
	if mode != AudioContext.GAME or dead:
		return
	guardian_active = true
	guardian_id = id
	guardian_wing = guardian_wing_of(id, zone)
	guardian_phase = 1
	_refresh()


func on_guardian_phase(phase: int) -> void:
	guardian_phase = phase


## Events.guardian_defeated: the guardian's fall (another guardian's id
## while one fights is ignored).
func on_guardian_defeated(id: StringName) -> void:
	if mode != AudioContext.GAME or not guardian_active:
		return
	if id != &"" and guardian_id != &"" and id != guardian_id:
		return
	guardian_active = false
	guardian_phase = 0
	intensity = 0.0
	_since_combat = INF
	_since_threat = INF
	_victory_left = GUARDIAN_VICTORY_TIME
	victory_sting = GUARDIAN_STING
	_refresh()


## The guardian left without falling (the night ended, a dev reset).
func on_guardian_gone() -> void:
	if not guardian_active:
		return
	guardian_active = false
	guardian_phase = 0
	_refresh()


## Events.night_started: a new night begins (its number and modifier).
func on_night_started(number: int, modifier: StringName) -> void:
	night.start_night(number, modifier)
	_refresh()


## Events.objective_changed (NightObjective.Stage as int).
func on_objective(stage: int) -> void:
	night.set_stage(stage)
	_refresh()


## Events.power_cut: the hall goes dark; the night music holds its breath.
func on_power_cut() -> void:
	night.cut_power()
	if mode == AudioContext.GAME and not dead:
		_hush_left = HUSH_TIME
	_refresh()


## Events.witching_hour.
func on_witching_hour() -> void:
	night.ring_witching()
	_refresh()


## Events.dawn_broke: the night is over, the music fades away.
func on_dawn() -> void:
	night.break_dawn()
	_refresh()


## True while the power cut's hush lasts.
func hushed() -> bool:
	return _hush_left > 0.0


## Level of the exploration stem while walking (EXPLORE).
func walk_level() -> float:
	return QUIET_WALK if night.quiet() or night.won() else 1.0


## Level of the tension stem under a calm walk (the night's own unease).
func tension_bed() -> float:
	if night.won():
		return 0.0
	var level := 0.0
	if night.modifier == &"full_moon":
		level = MOON_TENSION
	if night.witching:
		level = maxf(level, WITCHING_TENSION)
	return level


## Level of the tension stem the objective asks for (0 = none): the power
## is out and the crystal beats, or the crystal is loose.
func alert() -> float:
	if night.crystal_loose():
		return 1.0
	if night.power_out() and not night.won():
		return POWER_TENSION
	return 0.0


## Forces [param forced] until release() (a cutscene, a scripted moment).
func hold(forced: State) -> void:
	held = forced
	_refresh()


func release() -> void:
	held = -1
	_refresh()


## Advances the timers. [param nearby] = awake exhibits near the listener,
## [param engaged] = those fighting him (attacking or in melee range).
func update(delta: float, nearby: int, engaged: int, in_haven: bool) -> void:
	sheltered = in_haven
	threats = 0 if in_haven else nearby
	if engaged > 0 and not in_haven:
		on_combat(0.0)
	_since_combat += delta * (2.0 if in_haven else 1.0)
	_since_heat += delta
	_since_threat = 0.0 if threats > 0 else _since_threat + delta
	_victory_left = maxf(_victory_left - delta, 0.0)
	_hush_left = maxf(_hush_left - delta, 0.0)
	if state == State.EXPLORE or state == State.TENSION:
		_walked += delta
	if _settle_left > 0.0:
		_settle_left -= delta
		if _settle_left <= 0.0:
			_settle_left = 0.0
			variant = _pending_variant
	if _since_heat > INTENSITY_HOLD:
		intensity = maxf(intensity - INTENSITY_DECAY * delta, 0.0)
	if state == State.COMBAT:
		intensity = maxf(intensity, minf(threats * THREAT_HEAT, THREAT_FLOOR))
	_refresh()


## The state the rules ask for right now.
func wanted() -> State:
	if held >= 0:
		return held as State
	match mode:
		AudioContext.MENU, AudioContext.END:
			return State.MENU
		AudioContext.GAME:
			pass
		_:
			return State.SILENT
	if dead or night.dawn:
		return State.SILENT
	if _victory_left > 0.0:
		return State.VICTORY
	if boss_active:
		return State.BOSS
	if guardian_active:
		return State.GUARDIAN
	if _since_combat < COMBAT_HOLD:
		return State.COMBAT
	if hunted() or alert() > 0.0:
		return State.TENSION
	return State.EXPLORE


## Exhibits hunt nearby, or a fight has only just ended.
func hunted() -> bool:
	return threats > 0 or _since_threat < TENSION_HOLD or _since_combat < COMBAT_HOLD + TENSION_HOLD


## Target level (0..1) of every layer in the current state.
func layer_targets() -> Dictionary:
	var targets := {}
	for layer in LAYERS:
		targets[layer] = 0.0
	match state:
		State.MENU:
			targets[&"menu"] = 1.0
		State.EXPLORE:
			targets[&"explore"] = walk_level()
			targets[&"explore_tension"] = tension_bed()
		State.TENSION:
			var hunting := hunted()
			targets[&"explore"] = 1.0 if hunting else walk_level()
			targets[&"explore_tension"] = 1.0 if hunting else maxf(alert(), tension_bed())
		State.COMBAT:
			targets[&"combat"] = 1.0
			targets[&"combat_hi"] = hi_level()
		State.BOSS:
			targets[&"boss"] = 1.0
			targets[&"boss_hi"] = 1.0 if boss_phase >= 2 else smoothstep(0.5, 0.85, intensity)
		State.GUARDIAN:
			targets[&"guardian"] = 1.0
			targets[&"guardian_hi"] = 1.0 if guardian_phase >= 2 else smoothstep(0.5, 0.85, intensity)
	if hushed():
		for layer: StringName in [&"explore", &"explore_tension"]:
			targets[layer] = minf(targets[layer], HUSH_LEVEL)
	return targets


## Level of the combat hi stem for the current intensity.
func hi_level() -> float:
	return smoothstep(HI_FROM, HI_TO, intensity)


## Seconds since the last combat event (INF when none yet).
func since_combat() -> float:
	return _since_combat


func _refresh() -> void:
	var next := wanted()
	if next != state:
		var previous := state
		state = next
		state_changed.emit(previous, next)
