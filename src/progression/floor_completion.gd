class_name FloorCompletion
## How much of Floor I the guard has done (the end screen's "ukończenie %",
## design 6): the average of the parts the floor has - rooms visited
## (secret rooms left out: they count as secrets), guardians defeated (the
## T-Rex too), weapons found, crystal shards, gates and shortcuts opened,
## secrets and Lewis chess pieces found. Pure: the save and the layout are
## passed in.

const WEAPONS: Array[StringName] = [&"pistol", &"shotgun", &"flare", &"gatling", &"rifle_hunt", &"harpoon", &"hwacha"]
const CHESS := 8


## Part name -> [done, total] (parts with nothing to do are left out).
static func parts(game: PersistentState, layout: LevelLayout) -> Dictionary:
	var rooms := 0
	var visited := 0
	for room in layout.rooms:
		if room.secret:
			continue
		rooms += 1
		if game.rooms_visited.has(room.id):
			visited += 1
	var guardians := 0
	for plan in Floor1Plan.guardians():
		if game.is_guardian_defeated(plan.id):
			guardians += 1
	if game.is_guardian_defeated(&"trex"):
		guardians += 1
	var weapons := WEAPONS.filter(func(id: StringName) -> bool: return game.has_weapon(id)).size()
	var gates := 0
	for gate in layout.gates:
		if game.is_gate_open(gate.id):
			gates += 1
	var secret_ids := layout.markers.keys().filter(func(id: StringName) -> bool: return String(id).begins_with("secret_"))
	var secrets := secret_ids.filter(func(id: StringName) -> bool: return game.secrets.has(id)).size()
	var found := {
		"rooms": [visited, rooms],
		"guardians": [guardians, Floor1Plan.GUARDIANS.size() + 1],
		"weapons": [weapons, WEAPONS.size()],
		"shards": [mini(game.shards.size(), Floor1Plan.SHARD_COUNT), Floor1Plan.SHARD_COUNT],
		"gates": [gates, layout.gates.size()],
		"secrets": [secrets, secret_ids.size()],
		"chess": [mini(game.chess_found.size(), CHESS), CHESS],
	}
	for key: String in found.keys():
		if int(found[key][1]) <= 0:
			found.erase(key)
	return found


## 0-100, the parts weighed alike.
static func percent(game: PersistentState, layout: LevelLayout) -> int:
	var all := parts(game, layout)
	if all.is_empty():
		return 0
	var sum := 0.0
	for key: String in all:
		sum += float(all[key][0]) / float(all[key][1])
	return floori(sum / all.size() * 100.0 + 0.0001)
