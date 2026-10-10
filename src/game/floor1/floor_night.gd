class_name FloorNight
extends RefCounted
## Tonight's draw on Floor I: the floor's description (MuseumFloorLevel)
## with what the save adds, then NightDirector:
## - the start rooms are the havens known so far (the security booth
##   first: night 1's gentle way runs from there to the Great Court),
## - the gates open for good or openable tonight count as open when a
##   locked door is checked, so the night's door is never the only way to
##   any room the guard could reach (LevelDescription.cuts_off),
## - the wings whose guardian fell are weakened (NightDirector.WEAKENED_KEEP),
## - the difficulty scales the loot (DifficultyRules).
## Pure: the save is passed in.


static func plan(game: PersistentState, floor_layout: LevelLayout) -> NightConfig:
	var description := describe_tonight(game, floor_layout)
	return NightDirector.plan(game.night_seed(), game.night, description, weakened_zones(game), DifficultyRules.loot_scale(game.difficulty))


## The floor's description for [param game]'s night.
static func describe_tonight(game: PersistentState, floor_layout: LevelLayout) -> LevelDescription:
	var description := MuseumFloorLevel.describe_layout(floor_layout)
	var starts: Array[StringName] = []
	for haven in Floor1Plan.havens():
		if game.havens.has(haven.id) and floor_layout.room(haven.room) != null:
			starts.append(haven.room)
	if not starts.is_empty():
		description.start_rooms = starts
	var progress := FloorProgress.from_game(game)
	var gates: Array[StringName] = game.gates_open.duplicate()
	for haven_id in game.havens:
		for gate_id in ProgressRules.openable_gates(progress, ProgressRules.start_area(haven_id)):
			if not gates.has(gate_id):
				gates.append(gate_id)
	for gate_id in gates:
		var gate := floor_layout.gate(gate_id)
		if gate != null and gate.opening != &"" and not description.always_open.has(gate.opening):
			description.always_open.append(gate.opening)
	return description


## Zones whose guardian fell for good (the T-Rex weakens nothing).
static func weakened_zones(game: PersistentState) -> Array[StringName]:
	var zones: Array[StringName] = []
	for guardian in Floor1Plan.guardians():
		if game.is_guardian_defeated(guardian.id) and not zones.has(guardian.zone):
			zones.append(guardian.zone)
	return zones
