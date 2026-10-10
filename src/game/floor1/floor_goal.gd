class_name FloorGoal
extends Node
## The goal on the HUD on Floor I (design 3.3): the nearest sensible step
## worked out from the progress (ProgressRules.goal, from the area of the
## haven the night started in, tonight's locked door shut when it is a
## junction), and the crystal shards under it once the first is found.
## Worked out again whenever the progress may have moved (a gate, a
## guardian, a seal, a shard, any save) and every REFRESH s anyway; a new
## goal is announced (Events.goal_changed: the paper map pencils it in).

const REFRESH := 1.0

var game: PersistentState
var hud: Hud
## Tonight's draw (its locked door).
var night: NightConfig = null
## The goal's translation key now.
var key: StringName = &""

var _left: float = 0.0


func _ready() -> void:
	Events.gate_opened.connect(_on_progress.unbind(1))
	Events.guardian_defeated.connect(_on_progress.unbind(1))
	Events.seal_collected.connect(_on_progress.unbind(1))
	Events.shard_collected.connect(_on_progress.unbind(2))
	game.saved.connect(_on_progress)
	refresh()


func _process(delta: float) -> void:
	_left -= delta
	if _left <= 0.0:
		refresh()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and hud != null and key != &"":
		hud.set_objective(tr(key))
		_show_shards()


## The goal for [param for_game] (pure; tonight's [param closed] junctions).
static func goal_of(for_game: PersistentState, closed: Array[StringName] = []) -> StringName:
	var progress := FloorProgress.from_game(for_game)
	return ProgressRules.goal(progress, ProgressRules.start_area(for_game.start_haven), closed)


## Works the goal out now; a new one goes on the HUD and is announced.
func refresh() -> void:
	_left = REFRESH
	var closed: Array[StringName] = []
	if night != null and Floor1Plan.junction(night.locked_door) != null:
		closed.append(night.locked_door)
	var now := goal_of(game, closed)
	_show_shards()
	if now == key:
		return
	key = now
	hud.set_objective(tr(key))
	Events.goal_changed.emit(key)


func _show_shards() -> void:
	hud.set_shards(game.shards.size(), Floor1Plan.SHARD_COUNT)


func _on_progress() -> void:
	refresh.call_deferred()
