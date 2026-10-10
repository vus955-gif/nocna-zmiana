class_name LobbySecrets
## The lobby's six secrets (design 2, section 5) and their record in the
## persistent state (GameState.secrets, saved with the game). Pure logic:
## the persistent state is passed in, so tests can use their own.
## 1 the passage behind the painting, 2 the ventilation shaft, 3 the wall
## behind the crooked plaque, 4 the padlocked case, 5 the three night-shift
## notes, 6 the broom closet (haven 2).

const PAINTING := &"painting"
const VENT := &"vent"
const PLAQUE := &"plaque"
const CASE := &"case"
const NOTES := &"notes"
const CLOSET := &"closet"
const ALL: Array[StringName] = [PAINTING, VENT, PLAQUE, CASE, NOTES, CLOSET]


static func total() -> int:
	return ALL.size()


static func is_found(game: PersistentState, id: StringName) -> bool:
	return game.secrets.has(id)


## How many of the lobby's secrets [param game] has found.
static func found(game: PersistentState) -> int:
	var count := 0
	for id in ALL:
		if game.secrets.has(id):
			count += 1
	return count


## Records secret [param id]. True only the first time (an unknown id or a
## secret found before changes nothing).
static func discover(game: PersistentState, id: StringName) -> bool:
	if not ALL.has(id) or game.secrets.has(id):
		return false
	game.secrets.append(id)
	return true


## Translation key of the secret's name ("Przejście za obrazem").
static func name_key(id: StringName) -> String:
	return "SECRET_" + String(id).to_upper()
