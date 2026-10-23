class_name ShiftLog
## What the night shift has done so far, as the museum keeps count (plan
## docs/superpowers/plans/2026-10-21-opowiesc-muzeum.md, 2.4): each wing
## NO_SIGNAL (never entered), AWAKE (entered, its guardian still standing)
## or AT_REST (its guardian down), and the exhibits returned to rest (the
## exhibits destroyed on every night: GameState.voice_state "destroyed").
## The CCTV's status screen pages through it, the court's plaque counts it,
## the camera feeds of a wing at rest say so. Pure logic over GameState.

enum State { NO_SIGNAL, AWAKE, AT_REST }

const STATE_KEYS := {State.NO_SIGNAL: "SHIFT_NO_SIGNAL", State.AWAKE: "SHIFT_AWAKE", State.AT_REST: "SHIFT_AT_REST"}
## The status screen's columns: the wing's name padded to this many letters.
const NAME_WIDTH := 13


## Exhibits returned to rest on every night so far.
static func rested(game: PersistentState) -> int:
	return maxi(int(game.voice_state.get("destroyed", 0)), 0)


## The guardian of [param wing] (Floor1Plan), or null.
static func guardian_of(wing: StringName) -> Floor1Plan.GuardianPlan:
	for guardian in Floor1Plan.guardians():
		if guardian.zone == wing:
			return guardian
	return null


static func wing_state(game: PersistentState, floor_layout: LevelLayout, wing: StringName) -> State:
	var guardian := guardian_of(wing)
	if guardian != null and game.is_guardian_defeated(guardian.id):
		return State.AT_REST
	for room_id in game.rooms_visited:
		var room := floor_layout.room(room_id) if floor_layout != null else null
		if room != null and room.zone == wing:
			return State.AWAKE
	return State.NO_SIGNAL


## How many of the six wings are at rest.
static func wings_at_rest(game: PersistentState) -> int:
	var count := 0
	for wing in Floor1Plan.WINGS:
		var guardian := guardian_of(wing)
		if guardian != null and game.is_guardian_defeated(guardian.id):
			count += 1
	return count


## True when [param room] lies in a wing at rest.
static func room_at_rest(game: PersistentState, floor_layout: LevelLayout, room_id: StringName) -> bool:
	var room := floor_layout.room(room_id) if floor_layout != null else null
	if room == null or not Floor1Plan.WINGS.has(room.zone):
		return false
	var guardian := guardian_of(room.zone)
	return guardian != null and game.is_guardian_defeated(guardian.id)


## The log page of the CCTV's status screen (translated, in capitals): a
## heading, a line per wing, the exhibits at rest.
static func lines(game: PersistentState, floor_layout: LevelLayout) -> PackedStringArray:
	var out := PackedStringArray([TranslationServer.translate("SHIFT_LOG").to_upper()])
	for wing in Floor1Plan.WINGS:
		var name := TranslationServer.translate("SHIFT_WING_" + String(wing).to_upper()).to_upper()
		var state := TranslationServer.translate(STATE_KEYS[wing_state(game, floor_layout, wing)]).to_upper()
		out.append(name.rpad(NAME_WIDTH) + state)
	out.append((TranslationServer.translate("SHIFT_RESTED") % rested(game)).to_upper())
	return out
