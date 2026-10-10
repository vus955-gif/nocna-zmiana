class_name NightMood
extends RefCounted
## What the night in the lobby tells the soundtrack (pure state; Music and
## Ambience each keep one, fed from the Events hooks the Museum, its
## NightObjective and its NightWatch announce):
## - night_started(night, modifier): the night's number and modifier,
## - objective_changed(stage): NightObjective.Stage (PULSING on = the hall's
##   power is out; a resumed night announces its stage the same way),
## - power_cut: both fuses went in just now (the moment, not the state),
## - witching_hour: 3:00 (also announced by a resumed night past 3:00),
## - dawn_broke: 6:00, the night is over.
## A Museum announces its stage (and a resumed witching hour) while it sets
## up, just before night_started, all in one frame: night_started forgets
## whatever an earlier night left, but keeps what came in its own frame.
## A scene swap keeps the mood only for the scene that announced it
## (claims()); any other scene starts from a blank mood.

signal changed(cue: StringName)

const NO_STAGE := -1
## Frames between a night's announcement and its scene swap that still
## count as one set-up (a museum run as the main scene is announced in its
## _ready, and the audio autoloads look at it one frame later).
const SETUP_FRAMES := 1

## The night's number (0 = no night announced: a dev scene, a menu).
var night: int = 0
var modifier: StringName = &"none"
## NightObjective.Stage as int, NO_STAGE without an objective.
var stage: int = NO_STAGE
var witching: bool = false
var dawn: bool = false

var _night_frame: int = -100
var _stage_frame: int = -100
var _witching_frame: int = -100


## Back to a blank mood (no night).
func reset() -> void:
	night = 0
	modifier = &"none"
	stage = NO_STAGE
	witching = false
	dawn = false
	_night_frame = -100
	_stage_frame = -100
	_witching_frame = -100


## Events.night_started: a new night (what its museum announced in the
## same frame, while it set up, stays).
func start_night(number: int, night_modifier: StringName) -> void:
	var frame := Engine.get_process_frames()
	if _stage_frame != frame:
		stage = NO_STAGE
	if _witching_frame != frame:
		witching = false
	dawn = false
	night = number
	modifier = night_modifier if night_modifier != &"" else &"none"
	_night_frame = frame
	changed.emit(&"night")


## Events.objective_changed.
func set_stage(value: int) -> void:
	_stage_frame = Engine.get_process_frames()
	if value == stage:
		return
	stage = value
	changed.emit(&"stage")


## Events.power_cut (the objective has already moved to PULSING).
func cut_power() -> void:
	if stage < NightObjective.Stage.PULSING:
		_stage_frame = Engine.get_process_frames()
		stage = NightObjective.Stage.PULSING
	changed.emit(&"power_cut")


## Events.witching_hour.
func ring_witching() -> void:
	_witching_frame = Engine.get_process_frames()
	if witching:
		return
	witching = true
	changed.emit(&"witching")


## Events.dawn_broke.
func break_dawn() -> void:
	if dawn:
		return
	dawn = true
	changed.emit(&"dawn")


## A scene swap: true when the new scene is the game scene that has just
## announced this night (keep the mood), false otherwise (forget it).
func claims(game_scene: bool) -> bool:
	return game_scene and Engine.get_process_frames() - _night_frame <= SETUP_FRAMES


## The hall's lamps are out (both fuses in), for the rest of the night.
func power_out() -> bool:
	return stage >= NightObjective.Stage.PULSING


## The crystal flies to the T-Rex or already woke it.
func crystal_loose() -> bool:
	return stage == NightObjective.Stage.FLIGHT or stage == NightObjective.Stage.BOSS


## The T-Rex is beaten: the way down is open.
func won() -> bool:
	return stage >= NightObjective.Stage.DESCEND


## A night that wants quieter music: the first one, or a calm one.
func quiet() -> bool:
	return night == 1 or modifier == &"calm"
