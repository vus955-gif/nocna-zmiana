class_name CurioPortrait
extends Curio
## The founder's portrait in the north corridor (Curios: portrait): a
## painting like the gallery's (WallPainting; the marker is the middle of
## the canvas on the wall, -Z into the corridor) over a brass plate with his
## name. Asked (E), its eyes light up for a moment and Ksawery Zawilski
## answers - once in the whole game; then it is a painting again.

const PAINTING := &"scholar"
## How long the eyes stay lit after he has spoken.
const AWAKE := 6.0
const EYE_COLOR := Color(1.0, 0.72, 0.36)
## The name plate under the frame (its top edge this far under the canvas's middle).
const PLATE_DROP := 0.72

var painting: WallPainting = null
var awake := false

var _eyes: Array[MeshInstance3D] = []
var _awake_left := 0.0
var _engraving: Label3D = null


func _build() -> void:
	painting = WallPainting.create(Transform3D.IDENTITY, PAINTING)
	add_child(painting)
	var plate := ExhibitLabel._plate(ExhibitLabel.PLATE, Vector3(0.0, -PLATE_DROP - ExhibitLabel.PLATE.y, 0.0))
	plate.name = "NamePlate"
	add_child(plate)
	_engraving = Label3D.new()
	_engraving.name = "Engraving"
	_engraving.text = tr(Curios.title_key(id))
	_engraving.font = UiTheme.title_font()
	_engraving.font_size = 36
	_engraving.pixel_size = 0.0006
	_engraving.outline_size = 0
	_engraving.modulate = ExhibitLabel.ENGRAVING
	_engraving.width = ExhibitLabel.PLATE.x / _engraving.pixel_size * 0.86
	_engraving.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_engraving.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_engraving.shaded = true
	_engraving.double_sided = false
	_engraving.transform = Transform3D(Basis(Vector3.UP, PI), Vector3(0.0, ExhibitLabel.PLATE.y * 0.5, -ExhibitLabel.PLATE.z - 0.003))
	plate.add_child(_engraving)
	for side: float in [-1.0, 1.0]:
		var eye := MeshInstance3D.new()
		eye.name = "Eye_%s" % ("l" if side > 0.0 else "r")
		var ball := SphereMesh.new()
		ball.radius = 0.012
		ball.height = 0.024
		eye.mesh = ball
		eye.material_override = StoryProps.glow(EYE_COLOR, 4.0)
		eye.position = _eye_point(side) + Vector3(0.0, 0.0, -0.006)
		eye.visible = false
		eye.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(eye)
		_eyes.append(eye)
	add_box(Vector3(1.2, 1.5, 0.7), Vector3(0.0, -0.15, -0.35))


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and _engraving != null:
		_engraving.text = tr(Curios.title_key(id))


## Where an eye of the painted face is (the model's, else the greybox's).
func _eye_point(side: float) -> Vector3:
	if PaintingArt.has_model():
		return PaintingArt.model_eye(side)
	var texel := PaintingArt.EYE_TEXEL_L if side > 0.0 else PaintingArt.EYE_TEXEL_R
	var size := PaintingArt.CANVAS_SIZE
	return Vector3((0.5 - texel.x / PaintingArt.TEXELS.x) * size.x, (0.5 - texel.y / PaintingArt.TEXELS.y) * size.y, PaintingArt.CANVAS_Z)


func interact(by: Node) -> void:
	if not enabled or is_done():
		return
	super(by)
	awake = true
	_awake_left = AWAKE
	for eye in _eyes:
		eye.visible = true
	Sfx.play_at(&"portrait_creak", global_position, -2.0)
	retire()
	solve()
	spoke.emit(id, Curios.answer_key(id))


func _process(delta: float) -> void:
	if not awake:
		return
	_awake_left -= delta
	if _awake_left <= 0.0:
		awake = false
		for eye in _eyes:
			eye.visible = false
