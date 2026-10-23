class_name RestPlaque
extends Interactable
## The brass plaque on the Great Court's south wall by the entrance arch
## (plan docs/superpowers/plans/2026-10-21-opowiesc-muzeum.md, 2.4): the
## Directorate counts the exhibits "returned to rest" (destroyed, on every
## night: ShiftLog.rested) and the wings at rest, engraved large enough to
## read across the court and kept up to date while the guard plays. E reads
## the Directorate's small print (the card). The marker is on the wall, -Z
## into the court.

## The guard read the plaque.
signal read

const SIZE := Vector3(1.0, 0.66, 0.02)
const ENGRAVING := Color(0.2, 0.13, 0.05)
## Seconds between looks at the count.
const CHECK := 0.5

var game: PersistentState = null
var count := -1
var wings := -1

var _number: Label3D
var _heading: Label3D
var _footer: Label3D
var _check_left := 0.0


func _init() -> void:
	super()
	prompt_key = "PROMPT_READ_PLAQUE"


func _ready() -> void:
	if game == null:
		game = GameState
	var plate := ExhibitLabel._plate(SIZE, Vector3(0.0, -SIZE.y * 0.5, 0.0))
	add_child(plate)
	# a darker engraved border inside the brass
	var border := StoryProps.material(Color(0.46, 0.33, 0.14), 0.4, 0.85)
	for edge: Array in [[Vector3(SIZE.x - 0.06, 0.012, 0.004), Vector3(0.0, SIZE.y * 0.5 - 0.04, 0.0)], [Vector3(SIZE.x - 0.06, 0.012, 0.004), Vector3(0.0, -SIZE.y * 0.5 + 0.04, 0.0)]]:
		StoryProps._box(self, edge[0], edge[1] + Vector3(0.0, 0.0, -SIZE.z - 0.002), border)
	_heading = _engrave(UiTheme.title_font(), 40, Vector3(0.0, 0.17, 0.0))
	_number = _engrave(UiTheme.number_font(), 120, Vector3(0.0, 0.0, 0.0))
	_footer = _engrave(UiTheme.title_font(), 30, Vector3(0.0, -0.19, 0.0))
	add_box(Vector3(SIZE.x + 0.2, SIZE.y + 0.2, 0.7), Vector3(0.0, 0.0, -0.35))
	refresh()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and _heading != null:
		count = -1
		refresh()


func _process(delta: float) -> void:
	_check_left -= delta
	if _check_left > 0.0:
		return
	_check_left = CHECK
	refresh()


## Engraves the current count (only when it changed).
func refresh() -> void:
	var now := ShiftLog.rested(game)
	var at_rest := ShiftLog.wings_at_rest(game)
	if now == count and at_rest == wings:
		return
	count = now
	wings = at_rest
	_heading.text = tr("REST_PLAQUE_HEADING").to_upper()
	_number.text = str(count)
	_footer.text = tr("REST_PLAQUE_WINGS") % [wings, Floor1Plan.WINGS.size()]


func interact(by: Node) -> void:
	if not enabled:
		return
	super(by)
	read.emit()


func _engrave(font: Font, size: int, at: Vector3) -> Label3D:
	var text := Label3D.new()
	text.font = font
	text.font_size = size
	text.pixel_size = 0.0008
	text.outline_size = 0
	text.modulate = ENGRAVING
	text.width = SIZE.x / text.pixel_size * 0.9
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.shaded = true
	text.double_sided = false
	# Label3D reads from +Z; the plate's face is -Z
	text.transform = Transform3D(Basis(Vector3.UP, PI), at + Vector3(0.0, 0.0, -SIZE.z - 0.003))
	add_child(text)
	return text
