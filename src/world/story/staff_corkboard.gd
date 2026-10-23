class_name StaffCorkboard
extends Interactable
## The staff's corkboard by the court café (plan docs/superpowers/plans/
## 2026-10-21-opowiesc-muzeum.md, 2.4): the people of the museum in a few
## pinned slips - the rota after Heniek's leg, Gil on the coffee machine,
## the cashier on the milk, Mazur's lost watch, and, as the wings fall
## quiet, what the staff make of it. What is pinned changes with the night
## and with the guardians laid to rest (notices()); E reads the board (the
## card). The marker is on the wall, -Z out of the board.

signal read

## The board (cork in a wooden frame).
const SIZE := Vector3(1.1, 0.75, 0.03)
## At most this many slips (the newest first).
const MOST := 4

## Notice key -> [colour of its slip, first night, last night (0: no
## end), the guardian it waits for (&"": none)]. Text: CORK_<KEY> (the
## notice with its signature).
const NOTICES := {
	&"SCHEDULE": [Color(0.95, 0.93, 0.86), 1, 3, &""],
	&"MILK": [Color(0.96, 0.9, 0.62), 1, 0, &""],
	&"MACHINE": [Color(0.98, 0.8, 0.7), 1, 0, &""],
	&"WATCH": [Color(0.86, 0.92, 0.98), 2, 0, &""],
	&"CURATOR": [Color(0.95, 0.93, 0.86), 3, 0, &""],
	&"HENIEK": [Color(0.98, 0.95, 0.6), 4, 0, &""],
	&"COLOSSUS": [Color(0.96, 0.86, 0.68), 1, 0, &"colossus"],
	&"LAMASSU": [Color(0.95, 0.93, 0.86), 1, 0, &"lamassu"],
	&"CENTAUR": [Color(0.86, 0.92, 0.98), 1, 0, &"centaur"],
	&"PLANETARIUM": [Color(0.95, 0.93, 0.86), 1, 0, &"planetarium"],
	&"GENERAL": [Color(0.96, 0.9, 0.62), 1, 0, &"general"],
	&"SERPENT": [Color(0.98, 0.8, 0.7), 1, 0, &"serpent"],
	&"TREX": [Color(0.95, 0.93, 0.86), 1, 0, &"trex"],
}
## The everyday notices, the newest kind first (after the guardians').
const EVERYDAY: Array[StringName] = [&"HENIEK", &"CURATOR", &"WATCH", &"SCHEDULE", &"MACHINE", &"MILK"]
## Where the slips are pinned on the board (board space, -Z its face) and
## how each sits askew.
const SPOTS: Array[Vector3] = [Vector3(-0.3, 0.14, 0.0), Vector3(0.24, 0.17, 0.0), Vector3(-0.22, -0.17, 0.0), Vector3(0.28, -0.15, 0.0)]
const TILTS: Array[float] = [-0.06, 0.08, 0.05, -0.1]

var game: PersistentState = null
## The notices pinned now.
var pinned: Array[StringName] = []

var _slips: Node3D


func _init() -> void:
	super()
	prompt_key = "PROMPT_READ_BOARD"


## The notices of night [param night] for [param game], newest first: the
## guardians laid to rest (the last two), then the everyday ones of the
## night; MOST at most.
static func notices(game: PersistentState, night: int) -> Array[StringName]:
	var out: Array[StringName] = []
	if game.is_guardian_defeated(&"trex"):
		out.append(&"TREX")
	var fallen: Array[StringName] = []
	for guardian_id in game.guardians_defeated:
		for key: StringName in NOTICES:
			if NOTICES[key][3] == guardian_id and guardian_id != &"trex":
				fallen.append(key)
	fallen.reverse()
	out.append_array(fallen.slice(0, 2))
	for key in EVERYDAY:
		var notice: Array = NOTICES[key]
		if night >= int(notice[1]) and (int(notice[2]) == 0 or night <= int(notice[2])):
			out.append(key)
	return out.slice(0, MOST)


static func text_key(notice: StringName) -> String:
	return "CORK_" + String(notice)


func _ready() -> void:
	if game == null:
		game = GameState
	var cork := StoryProps.material(Color(0.6, 0.44, 0.28), 1.0)
	var frame := StoryProps.material(Color(0.3, 0.2, 0.12), 0.6)
	StoryProps._box(self, Vector3(SIZE.x, SIZE.y, SIZE.z), Vector3(0.0, 0.0, -SIZE.z * 0.5), cork)
	for edge: Array in [
		[Vector3(SIZE.x + 0.06, 0.04, 0.045), Vector3(0.0, SIZE.y * 0.5 + 0.01, -0.0225)],
		[Vector3(SIZE.x + 0.06, 0.04, 0.045), Vector3(0.0, -SIZE.y * 0.5 - 0.01, -0.0225)],
		[Vector3(0.04, SIZE.y, 0.045), Vector3(SIZE.x * 0.5 + 0.01, 0.0, -0.0225)],
		[Vector3(0.04, SIZE.y, 0.045), Vector3(-SIZE.x * 0.5 - 0.01, 0.0, -0.0225)],
	]:
		StoryProps._box(self, edge[0], edge[1], frame)
	_slips = Node3D.new()
	_slips.name = "Slips"
	add_child(_slips)
	add_box(Vector3(SIZE.x + 0.2, SIZE.y + 0.2, 0.7), Vector3(0.0, 0.0, -0.35))
	pin(game.night)


## Pins the notices of night [param night] (the slips on the board follow).
func pin(night: int) -> void:
	pinned = notices(game, night)
	for child in _slips.get_children():
		child.queue_free()
	var red := StoryProps.material(Color(0.75, 0.1, 0.08), 0.4)
	for i in pinned.size():
		var colour: Color = NOTICES[pinned[i]][0]
		var slip := StoryProps._box(_slips, Vector3(0.36, 0.26, 0.002), SPOTS[i] + Vector3(0.0, 0.0, -SIZE.z - 0.002), StoryProps.material(colour, 1.0), Vector3(0.0, 0.0, TILTS[i]))
		slip.name = "Slip_%d" % i
		# a few lines of writing on it and a red pin
		var ink := StoryProps.material(Color(0.2, 0.2, 0.28), 1.0)
		for line in 4:
			StoryProps._box(slip, Vector3(0.26 - 0.04 * (line % 2), 0.008, 0.001), Vector3(-0.02, 0.07 - line * 0.045, -0.0015), ink)
		StoryProps._cylinder(slip, 0.012, 0.016, Vector3(0.0, 0.1, -0.01), red, Vector3(PI * 0.5, 0.0, 0.0))


## The text of the card: every pinned notice, one to a paragraph.
func board_text() -> String:
	var parts := PackedStringArray()
	for notice in pinned:
		parts.append(tr(text_key(notice)))
	return "\n".join(parts)


func interact(by: Node) -> void:
	if not enabled:
		return
	super(by)
	read.emit()
