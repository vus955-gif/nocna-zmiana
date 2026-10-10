class_name NightState
extends Node
## State of one night (autoload "RunState"): carried Dust, the night's
## artifacts, modifier, fuses and crystal, and the night's random generator.
## Nothing here survives death; NightRules moves the carried Dust into the
## dropped lantern. Stages 2b/2c fill in modifiers, artifacts, fuses and the
## crystal; their Dust effects go through [member multipliers].

signal dust_changed(total: int, delta: int)

enum CrystalPhase { DORMANT, PULSING, FLYING, EMBEDDED, BROKEN }

var dust: int = 0
var artifacts: Array[StringName] = []
var modifier: StringName = &"none"
## Fuses already in the fuse box (0-2) and fuses in the guard's pockets.
var fuses: int = 0
var fuses_carried: int = 0
var crystal_phase: CrystalPhase = CrystalPhase.DORMANT
## Every random choice of the night comes from here (same seed = same night).
var rng := RandomNumberGenerator.new()
## Seconds played this night (the clock stops while the game is paused).
var time: float = 0.0
var running: bool = false
## Dust multipliers by source (&"full_moon", &"coin", ...); they multiply.
var multipliers: Dictionary = {}
## Tonight's spawn slots (indices into the level's spawn_slots) whose
## exhibit is gone, loot spots (indices into loot_spots) already taken and
## interactables used (ids). Saved with the game, so "Continue" resumes the
## night instead of refilling it (PersistentState.night_progress).
var killed_slots: Array[int] = []
var taken_loot: Array[int] = []
var used: Array[StringName] = []

var _unsaved_time: float = 0.0


func _process(delta: float) -> void:
	if running:
		time += delta
		_unsaved_time += delta


## Starts a fresh night whose random choices all follow [param night_seed].
func begin_night(night_seed: int) -> void:
	reset()
	rng.seed = night_seed
	running = true


func end_night() -> void:
	running = false


## Back to an empty night (nothing carried, no night running).
func reset() -> void:
	var had := dust
	dust = 0
	artifacts.clear()
	modifier = &"none"
	fuses = 0
	fuses_carried = 0
	crystal_phase = CrystalPhase.DORMANT
	rng = RandomNumberGenerator.new()
	time = 0.0
	_unsaved_time = 0.0
	running = false
	multipliers.clear()
	killed_slots.clear()
	taken_loot.clear()
	used.clear()
	if had != 0:
		dust_changed.emit(0, -had)


func dust_multiplier() -> float:
	var total := 1.0
	for source in multipliers:
		total *= float(multipliers[source])
	return total


## [param amount] after the night's multipliers, rounded up.
func scaled_dust(amount: int) -> int:
	return ceili(snappedf(amount * dust_multiplier(), 0.0001))


## Adds Dust (through the multipliers unless [param multiplied] is false,
## e.g. for Dust that was scaled already or comes back from a lantern).
## Returns how much was added.
func add_dust(amount: int, multiplied: bool = true) -> int:
	if amount <= 0:
		return 0
	var added := scaled_dust(amount) if multiplied else amount
	dust += added
	dust_changed.emit(dust, added)
	return added


## Takes [param amount] of the carried Dust. False (nothing taken) when short.
func spend_dust(amount: int) -> bool:
	if amount < 0 or amount > dust:
		return false
	dust -= amount
	if amount > 0:
		dust_changed.emit(dust, -amount)
	return true


func has_artifact(id: StringName) -> bool:
	return artifacts.has(id)


func set_multiplier(source: StringName, factor: float) -> void:
	multipliers[source] = factor


func clear_multiplier(source: StringName) -> void:
	multipliers.erase(source)


func mark_killed(slot: int) -> void:
	if slot >= 0 and not killed_slots.has(slot):
		killed_slots.append(slot)


func mark_taken(spot: int) -> void:
	if spot >= 0 and not taken_loot.has(spot):
		taken_loot.append(spot)


func mark_used(id: StringName) -> void:
	if not used.has(id):
		used.append(id)


func is_used(id: StringName) -> bool:
	return used.has(id)


## Takes over what a saved progress of this night says is gone already.
func restore_progress(progress: Dictionary) -> void:
	for slot in progress.get("killed", []):
		mark_killed(int(slot))
	for spot in progress.get("taken", []):
		mark_taken(int(spot))
	for id in progress.get("used", []):
		mark_used(StringName(str(id)))


## Seconds played since the last call (added to the saved play time).
func take_unsaved_time() -> float:
	var seconds := _unsaved_time
	_unsaved_time = 0.0
	return seconds
