class_name CrookedPlaque
extends Interactable
## The brass plaque by the armory's false wall hangs a little crooked. A
## guard who straightens it (E) hears a click; the wall beside it then
## slides away (the Museum's LobbyFeatures opens the panel on
## [signal straightened]). The plaque reads like any other in the museum.
## It takes over the look of the level's plaque piece when there is one
## (tilting that piece's greybox visual), else it builds its own.

signal straightened

## How crooked it hangs (radians, about its own centre).
const TILT := 0.15
const SIZE := Vector3(0.5, 0.3, 0.04)
const STRAIGHTEN_TIME := 0.35

## The level's plaque piece (origin at the bottom centre, -Z = its face).
var piece: Node3D = null
var straight: bool = false

var _visual: Node3D
var _tilt: float = TILT
var _engraving: Label3D = null


## A plaque on [param piece_node] (its transform and look), or standing at
## [param fallback] when the level has none.
static func make(piece_node: Node3D, fallback: Transform3D) -> CrookedPlaque:
	var plaque := CrookedPlaque.new()
	plaque.piece = piece_node
	plaque.transform = piece_node.global_transform if piece_node != null else fallback
	return plaque


func _init() -> void:
	super()
	prompt_key = "PROMPT_SECRET_PLAQUE"


func _ready() -> void:
	var size: Vector3 = piece.get_meta(&"kit_size", SIZE) if piece != null else SIZE
	add_box(Vector3(size.x + 0.2, size.y + 0.2, 0.3), Vector3(0.0, size.y * 0.5, -0.15))
	_visual = piece.get_node_or_null(^"Visual") as Node3D if piece != null else null
	if _visual == null:
		_visual = LevelKit.visual(&"plaque", size, LevelKit.BRASS)
		add_child(_visual)
	_engrave(size)
	_apply_tilt()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and _engraving != null:
		_engraving.text = tr("PLAQUE_ARMOR")


## Straightens it at once and takes the use-zone away (a secret found on an
## earlier night).
func set_straight() -> void:
	straight = true
	_tilt = 0.0
	_apply_tilt()
	_retire_zone()


func interact(by: Node) -> void:
	if straight or not enabled:
		return
	super(by)
	straight = true
	_retire_zone()
	Sfx.play(&"interact")
	var tween := create_tween()
	tween.tween_method(_set_tilt, TILT, 0.0, STRAIGHTEN_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_callback(straightened.emit)


func _set_tilt(angle: float) -> void:
	_tilt = angle
	_apply_tilt()


func _retire_zone() -> void:
	enabled = false
	collision_layer = 0


## Turns the visual about the plaque's centre (the axis through its face).
func _apply_tilt() -> void:
	if _visual == null:
		return
	var size: Vector3 = piece.get_meta(&"kit_size", SIZE) if piece != null else SIZE
	var center := Vector3(0.0, size.y * 0.5, 0.0)
	_visual.transform = Transform3D(Basis(Vector3.BACK, _tilt), center) * Transform3D(Basis.IDENTITY, -center)


## The museum's label, engraved on the plaque's face (it tilts with it).
func _engrave(size: Vector3) -> void:
	var text := Label3D.new()
	_engraving = text
	text.name = "Engraving"
	text.text = tr("PLAQUE_ARMOR")
	text.font = UiTheme.title_font()
	text.font_size = 40
	text.pixel_size = 0.0007
	text.outline_size = 0
	text.modulate = Color(0.2, 0.13, 0.06)
	text.width = size.x / text.pixel_size * 0.9
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.shaded = true
	# Label3D reads from +Z; the plaque's face is -Z
	text.transform = Transform3D(Basis(Vector3.UP, PI), Vector3(0.0, size.y * 0.5, -size.z * 0.5 - 0.004))
	_visual.add_child(text)
