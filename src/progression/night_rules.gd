class_name NightRules
## What survives what, in one place (design 2.3): death moves the carried
## Dust into a lantern where the guard fell (an older, unrecovered lantern
## is lost) and starts the next night; a lantern gives its Dust back once;
## a haven becomes the start of the next night and saves; quitting keeps
## the night in progress (destroyed exhibits, taken loot, the guard's
## health and ammo) for "Continue", death clears it. The persistent and the
## night state are passed in, so tests can use their own.


## The guard died at [param drop_at] (last safe floor position).
static func on_death(game: PersistentState, run: NightState, drop_at: Vector3) -> void:
	var carried := run.dust
	game.stats["play_time"] = float(game.stats["play_time"]) + run.take_unsaved_time()
	if carried > 0:
		game.lantern = {"active": true, "position": [drop_at.x, drop_at.y, drop_at.z], "dust": carried}
	else:
		# nothing to leave behind, but the old lantern is gone all the same
		game.lantern = {"active": false, "position": [0.0, 0.0, 0.0], "dust": 0}
	run.spend_dust(carried)
	run.end_night()
	game.run_dust = 0
	game.night_progress = {}   # the next night starts full again
	game.night += 1
	game.stats["deaths"] = int(game.stats["deaths"]) + 1
	game.stats["nights"] = int(game.stats["nights"]) + 1
	game.save_game()


## Dawn (6:00) ended the night without a death (expansion design 4): the
## carried Dust stays with the guard (no lantern; an older one keeps
## waiting), the night's fuses, crystal and progress are gone, the next
## night begins. Saved.
static func on_dawn(game: PersistentState, run: NightState) -> void:
	game.stats["play_time"] = float(game.stats["play_time"]) + run.take_unsaved_time()
	game.run_dust = run.dust
	run.end_night()
	game.night_progress = {}
	game.night += 1
	game.stats["nights"] = int(game.stats["nights"]) + 1
	game.save_game()


## Gives the lantern's Dust back (no multipliers). Returns the amount; 0
## when there is no lantern.
static func recover_lantern(game: PersistentState, run: NightState) -> int:
	if not bool(game.lantern.get("active", false)):
		return 0
	var amount := int(game.lantern["dust"])
	game.lantern = {"active": false, "position": [0.0, 0.0, 0.0], "dust": 0}
	run.add_dust(amount, false)
	return amount


## The guard reached a haven: it is known from now on, the next night starts
## there, and the game is saved (carried Dust included). False when the
## save failed.
static func enter_haven(game: PersistentState, run: NightState, haven_id: StringName) -> bool:
	game.discover_haven(haven_id)
	game.start_haven = haven_id
	return save_progress(game, run)


## A night from the saved state: the night's seed, the Dust that was
## carried at the last save and, when the night was left unfinished
## ("Continue"), what was already destroyed, taken or used in it.
static func start_night(game: PersistentState, run: NightState) -> void:
	run.begin_night(game.night_seed())
	if game.run_dust > 0:
		run.add_dust(game.run_dust, false)
	var progress := game.current_progress()
	if progress.is_empty():
		game.night_progress = {}
	else:
		run.restore_progress(progress)


## What the save keeps of the night in progress: the night state's lists
## plus the guard's [param guard] state ({health, weapons}) and the Dust
## lying uncollected [param dust] (DustDropper.lying(): laid again where it
## lay when the night is continued).
static func progress_snapshot(game: PersistentState, run: NightState, guard: Dictionary = {}, dust: Array = []) -> Dictionary:
	var snapshot := {
		"night": game.night,
		"killed": run.killed_slots.duplicate(),
		"taken": run.taken_loot.duplicate(),
		"used": run.used.map(func(id: StringName) -> String: return String(id)),
	}
	if not guard.is_empty():
		snapshot["guard"] = guard
	if not dust.is_empty():
		snapshot["dust"] = dust
	return PersistentState.clean_progress(snapshot, game.night)


## Saves with the carried Dust and the time played since the last save.
static func save_progress(game: PersistentState, run: NightState) -> bool:
	game.run_dust = run.dust
	game.stats["play_time"] = float(game.stats["play_time"]) + run.take_unsaved_time()
	return game.save_game()
