class_name Floor1WorldSnapshot
extends RefCounted
## What a night of Floor I looks like to the guard, as plain data (QA #51;
## plan docs/superpowers/plans/2026-10-18-qa-kolizje-softlocki-zapis.md),
## so a night saved and loaded again can be compared with itself:
## - "save": GameState.to_dict() (the play time left out),
## - "exhibits": the spawn slots whose exhibit stands, and the portraits,
## - "guardians": the guardians standing (and asleep or fighting),
## - "clock": the night's clock (s since 23:00; compared within a second
##   or two by the caller),
## - "things": every object of the world with a state of its own - the
##   gates' locks, the doors, the grilles, the loot still lying, the
##   weapons, fuses, seals, shards and chess pieces lying, the drawer, the
##   locker, the cabinet, the gatling's case, the notes, the secrets'
##   caches and switches, the artifacts, the switchboard, the finale's
##   pieces - by its class and its place (0.25 m), with the state it shows
##   (open, locked, holding its key, taken...).
## - "dust": the Dust lying uncollected (how many motes, what they are
##   worth; their places are checked by the caller where it matters).
## What moves by itself (the guard, the exhibits' places, a fight's
## supplies, shots, effects) is not part of it.

## Properties that tell an object's state (those it has).
const STATE := [&"is_open", &"locked", &"has_key", &"unlocked", &"state", &"active", &"is_down", &"is_jammed"]
## Classes whose subtrees are not the world's: they move or live a moment.
const SKIP := [&"Player", &"Enemy", &"Guardian", &"DustMote", &"Projectile", &"DustDropper"]


static func take(museum: Museum) -> Dictionary:
	var game: Dictionary = _rounded(museum.game.to_dict())
	(game["stats"] as Dictionary).erase("play_time")
	var slots: Array = []
	var portraits: Array = []
	for exhibit in museum.exhibits():
		if exhibit.has_meta(Museum.SLOT_META):
			slots.append(int(exhibit.get_meta(Museum.SLOT_META)))
		elif exhibit.has_meta(Museum.PORTRAIT_META):
			portraits.append(String(exhibit.get_meta(Museum.PORTRAIT_META)))
	slots.sort()
	portraits.sort()
	var guardians := {}
	var keeper := museum.floor_game.guardians
	for id: StringName in keeper.guardians:
		var guardian: Guardian = keeper.guardians[id]
		if is_instance_valid(guardian):
			guardians[String(id)] = "fighting" if guardian.is_fighting() else "asleep"
	var things := {}
	_collect(museum, museum, keeper, things)
	var clock := museum.watch.clock.elapsed if museum.watch != null else 0.0
	return {"save": game, "exhibits": slots, "portraits": portraits, "guardians": guardians, "things": things, "clock": clock, "dust": dust_lying(museum)}


## The Dust lying in [param museum] uncollected: {motes, value}.
static func dust_lying(museum: Museum) -> Dictionary:
	var count := 0
	var value := 0
	for mote in lying_motes(museum):
		count += 1
		value += mote.value
	return {"motes": count, "value": value}


## The motes of Dust in [param museum] not collected (nor blinked out).
static func lying_motes(museum: Museum) -> Array[DustMote]:
	var found: Array[DustMote] = []
	for node in museum.find_children("*", "DustMote", true, false):
		if not node.is_queued_for_deletion():
			found.append(node as DustMote)
	return found


## [param value] with every float rounded to a millionth (a float written
## to JSON and read back may differ in its last digits).
static func _rounded(value: Variant) -> Variant:
	if value is float:
		return snappedf(value, 0.000001)
	if value is Dictionary:
		var out := {}
		for key: Variant in value:
			out[key] = _rounded(value[key])
		return out
	if value is Array:
		return (value as Array).map(func(item: Variant) -> Variant: return _rounded(item))
	return value


static func _collect(node: Node, museum: Museum, keeper: GuardianKeeper, things: Dictionary) -> void:
	for child in node.get_children():
		if _skipped(child):
			continue
		if child == keeper.get_node_or_null(^"Supplies"):
			continue   # a fight's supplies: once a night, gone with it
		var state: Variant = _state(child)
		if state != null:
			var key := "%s@%s" % [_kind(child), (child as Node3D).global_position.snapped(Vector3.ONE * 0.25)]
			while things.has(key):
				key += "+"
			things[key] = state
		_collect(child, museum, keeper, things)


static func _skipped(node: Node) -> bool:
	var script := node.get_script() as Script
	while script != null:
		if SKIP.has(script.get_global_name()):
			return true
		script = script.get_base_script()
	return SKIP.has(StringName(node.get_class()))


## The class of [param node] (its script's name, else the engine's).
static func _kind(node: Node) -> String:
	var script := node.get_script() as Script
	var name := script.get_global_name() if script != null else &""
	if name == &"" and script != null:
		name = StringName(script.resource_path.get_file().get_basename())
	return String(name) if name != &"" else node.get_class()


## The state [param node] shows: its STATE properties (a loot box taken is
## no longer there, and neither is a pickup freed), or null for a node
## without one.
static func _state(node: Node) -> Variant:
	if not node is Node3D or node.is_queued_for_deletion():
		return null
	var found := {}
	for property: StringName in STATE:
		if property in node:
			var value: Variant = node.get(property)
			if typeof(value) in [TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING, TYPE_STRING_NAME]:
				found[String(property)] = value
	if node is Pickup:
		return {"active": true} if (node as Pickup).active else null
	if node is Interactable or node is Door or node is ArenaGrille or not found.is_empty():
		for id: StringName in [&"pickup_id", &"weapon_id", &"note_id", &"artifact_id", &"gate_id", &"id"]:
			if id in node:
				found[String(id)] = str(node.get(id))
		return found if not found.is_empty() else {"present": true}
	return null


## The differences between [param before] and [param after] (one line
## each), leaving out the "things" a rule of [param except] covers: [class
## of the thing, text its state holds (as JSON), why] - the line then is
## left out.
static func differences(before: Dictionary, after: Dictionary, except: Array = []) -> PackedStringArray:
	var out := PackedStringArray()
	for part: String in ["save", "exhibits", "portraits", "guardians", "dust"]:
		if JSON.stringify(before[part]) != JSON.stringify(after[part]):
			out.append("%s: %s -> %s" % [part, _short(before[part]), _short(after[part])])
	var a: Dictionary = before["things"]
	var b: Dictionary = after["things"]
	for key: String in a:
		if _excepted(key, a[key], except) or (b.has(key) and _excepted(key, b[key], except)):
			continue
		if not b.has(key):
			out.append("gone after loading: %s %s" % [key, a[key]])
		elif JSON.stringify(a[key]) != JSON.stringify(b[key]):
			out.append("changed after loading: %s %s -> %s" % [key, a[key], b[key]])
	for key: String in b:
		if _excepted(key, b[key], except):
			continue
		if not a.has(key):
			out.append("new after loading: %s %s" % [key, b[key]])
	return out


static func _excepted(key: String, state: Variant, except: Array) -> bool:
	var text := JSON.stringify(state)
	for rule: Array in except:
		if key.begins_with(String(rule[0]) + "@") and text.contains(String(rule[1])):
			return true
	return false


static func _short(value: Variant) -> String:
	var text := JSON.stringify(value)
	return text if text.length() < 400 else text.substr(0, 400) + "..."
