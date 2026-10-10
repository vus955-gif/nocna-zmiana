class_name MapState
extends RefCounted
## What the paper museum map knows of the guard's progress (a plain
## snapshot, no nodes): the rooms he has been in, the havens he knows, what
## he has opened, defeated and found, and tonight's goal (the step behind
## it gives the goal its place on the plan). Built from the save with
## from_game(); tests build their own.

var rooms_visited: Array[StringName] = []
var havens: Array[StringName] = []
var guardians_defeated: Array[StringName] = []
var gates_open: Array[StringName] = []
var seals: Array[StringName] = []
var shards: Array[StringName] = []
## Key items (&"pistol_key", the fuses).
var items: Array[StringName] = []
var weapons: Array[StringName] = []
## World flags (&"power_north", &"astrolabe", &"floor1_complete").
var flags: Array[StringName] = []
## Notes read, Lewis chess pieces and secrets found (their marker ids).
var notes: Array[StringName] = []
var chess_found: Array[StringName] = []
var secrets: Array[StringName] = []
## The goal's translation key (ProgressRules.goal) and its step (&"" when
## the goal has none: exploring, the epilogue).
var goal_key: StringName = &""
var goal_step: StringName = &""


## The save's progress; the goal as the HUD has it (from the night's start
## haven, tonight's [param closed] junctions shut).
static func from_game(game: PersistentState, closed: Array[StringName] = []) -> MapState:
	var state := MapState.new()
	state.rooms_visited = game.rooms_visited.duplicate()
	state.havens = game.havens.duplicate()
	state.guardians_defeated = game.guardians_defeated.duplicate()
	state.gates_open = game.gates_open.duplicate()
	state.seals = game.seals.duplicate()
	state.shards = game.shards.duplicate()
	state.items = game.items.duplicate()
	if game.pistol_key and not state.items.has(&"pistol_key"):
		state.items.append(&"pistol_key")
	state.weapons = game.weapons.duplicate()
	state.flags = game.flags.duplicate()
	state.notes = game.notes.duplicate()
	state.chess_found = game.chess_found.duplicate()
	state.secrets = game.secrets.duplicate()
	var progress := FloorProgress.from_game(game)
	var start := ProgressRules.start_area(game.start_haven)
	state.goal_key = ProgressRules.goal(progress, start, closed)
	if state.goal_key != ProgressRules.GOAL_EPILOGUE and state.goal_key != ProgressRules.GOAL_EXPLORE:
		state.goal_step = ProgressRules.next_step(progress, start, closed)
	return state
