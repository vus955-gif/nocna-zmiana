class_name Onboarding
extends Node
## First-night tips, each shown once ever (remembered in hints.json next to
## the save), one at a time on the HUD's hint line, when they matter:
## - the flashlight (F) as the guard first steps out of the lit booth,
## - using things (E) the first time something usable is in view,
## - the goal once he is on his way: in the lobby the two fuses (the gallery
##   and the armory); on Floor I a weapon first (the gun locker's key in the
##   entrance hall's till) and where the goal is always shown.
## No tutorial walls: a line, a few seconds, gone.

const FILE := "hints.json"
const FLASHLIGHT := &"flashlight"
const INTERACT := &"interact"
const FUSES := &"fuses"
## Floor I's goal tip (its own: a lobby player still needs it there).
const FLOOR_GOAL := &"floor_goal"
const ORDER: Array[StringName] = [FLASHLIGHT, INTERACT, FUSES]
const FLOOR_ORDER: Array[StringName] = [FLASHLIGHT, INTERACT, FLOOR_GOAL]
## Floor I rooms where the goal's tip comes at once (out of the booth).
const FLOOR_GOAL_ROOMS: Array[StringName] = [&"entrance_hall", &"court"]
## The goal's tip comes this long after leaving the booth at the latest.
const FUSES_AFTER := 14.0
const SHOW_TIME := 7.0

var museum: Museum
## Tips already shown (in any game).
var seen: Array[StringName] = []
var _queue: Array[StringName] = []
var _outside_for: float = 0.0
var _left_booth: bool = false


func setup(for_museum: Museum) -> void:
	museum = for_museum
	name = "Onboarding"
	seen = load_seen()


static func path() -> String:
	return SavePaths.dir().path_join(FILE)


static func load_seen() -> Array[StringName]:
	var found: Array[StringName] = []
	var data: Variant = SaveFile.parse_json_file(path())
	if data is Dictionary and data.get("seen") is Array:
		for id in data["seen"]:
			if (id is String or id is StringName) and not found.has(StringName(id)):
				found.append(StringName(id))
	return found


func _save_seen() -> void:
	var ids: Array = []
	for id in seen:
		ids.append(String(id))
	SaveFile.write_json(path(), {"version": 1, "seen": ids})


## The tips of this level, in order.
func order() -> Array[StringName]:
	return FLOOR_ORDER if _on_floor() else ORDER


func _on_floor() -> bool:
	return museum != null and museum.floor_level != null


## True once every tip has been shown.
func done() -> bool:
	for id in order():
		if not seen.has(id):
			return false
	return true


func _process(delta: float) -> void:
	if museum == null or done() or not is_instance_valid(museum.player) or not museum.player.alive:
		return
	var guard := museum.player
	var sheltered := Haven.shelters(guard.global_position)
	if not sheltered:
		_left_booth = true
		_outside_for += delta
		_want(FLASHLIGHT)
	if guard.interactor.focus != null:
		_want(INTERACT)
	if _on_floor():
		_floor_goal(guard)
	else:
		var fuses_pending := museum.objective == null or museum.objective.stage == NightObjective.Stage.FUSES
		if _left_booth and fuses_pending and (_outside_for >= FUSES_AFTER or museum.lobby.room_at(guard.global_position + Vector3.UP * 0.2) in [&"diorama", &"hall"]):
			_want(FUSES)
		elif not fuses_pending:
			_mark(FUSES)   # already past it (a resumed night)
	if guard.battery.on:
		_mark(FLASHLIGHT)   # he found it himself
		_queue.erase(FLASHLIGHT)
	if not _queue.is_empty() and museum.hud.hint_text() == "":
		_show(_queue.pop_front())


## Floor I: unarmed out of the booth, the way to a weapon (in the entrance
## hall or the court at once, else after FUSES_AFTER s); armed already, no
## need.
func _floor_goal(guard: Player) -> void:
	if museum.game.has_weapon(&"pistol") or museum.game.pistol_key:
		_mark(FLOOR_GOAL)
		_queue.erase(FLOOR_GOAL)
		return
	var room := museum.floor_level.room_at(guard.global_position + Vector3.UP * 0.2)
	if _left_booth and (_outside_for >= FUSES_AFTER or FLOOR_GOAL_ROOMS.has(room)):
		_want(FLOOR_GOAL)


func _want(id: StringName) -> void:
	if not seen.has(id) and not _queue.has(id):
		_queue.append(id)


func _mark(id: StringName) -> void:
	if not seen.has(id):
		seen.append(id)
		_save_seen()


func _show(id: StringName) -> void:
	if seen.has(id):
		return
	match id:
		FLASHLIGHT:
			museum.hud.show_hint(tr("HUD_HINT_FLASHLIGHT") % GameInput.key_label(&"flashlight"), SHOW_TIME)
		INTERACT:
			museum.hud.show_hint(tr("HUD_HINT_INTERACT") % GameInput.key_label(&"interact"), SHOW_TIME)
		FUSES:
			museum.hud.show_hint(tr("HUD_HINT_FUSES"), SHOW_TIME + 2.0)
		FLOOR_GOAL:
			museum.hud.show_hint(tr("HUD_HINT_FLOOR1_GOAL"), SHOW_TIME + 2.0)
	Sfx.play_ui(&"ui_move", -6.0)
	_mark(id)
