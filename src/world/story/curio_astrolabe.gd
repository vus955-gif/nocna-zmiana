class_name CurioAstrolabe
extends Curio
## The founder's travelling astrolabe on its stand in the collectors'
## gallery (Curios: astrolabe): a brass disc upright on a mahogany stand,
## its alidade (the pointer across the face) on a pin, a little star on the
## rim at the top - the Pole Star. E turns the alidade one notch (an eighth
## of a turn, clockwise); set on the star, a drawer slides out of the stand:
## a pouch of Dust and rounds for the rifle. The first E tells what it is
## (the card: the founder set it on the Pole Star every evening).

const STEPS := 8
## The notch it is left at (three turns from the star).
const START := 5
const TURN_TIME := 0.25
const STAND := Vector3(0.42, 0.95, 0.42)
const DISC_RADIUS := 0.17
## The disc's middle over the stand (it stands on a short brass fork).
const DISC_AT := Vector3(0.0, 1.2, 0.0)
const DRAWER := Vector3(0.3, 0.11, 0.34)
const DRAWER_Y := 0.72
const DRAWER_OUT := 0.26

var step := START
var turning := false

var _alidade: Node3D = null
var _drawer: Node3D = null
var _star: MeshInstance3D = null
var _told := false


func _build() -> void:
	var mahogany := StoryProps.material(Color(0.32, 0.14, 0.08), 0.5)
	var brass := StoryProps.material(Color(0.8, 0.62, 0.3), 0.32, 0.9)
	var dark_brass := StoryProps.material(Color(0.5, 0.36, 0.16), 0.4, 0.85)
	# the stand: a mahogany pedestal with a moulded top
	StoryProps._box(self, STAND, Vector3(0.0, STAND.y * 0.5, 0.0), mahogany)
	StoryProps._box(self, Vector3(STAND.x + 0.06, 0.04, STAND.z + 0.06), Vector3(0.0, STAND.y, 0.0), mahogany)
	StoryProps._box(self, Vector3(STAND.x + 0.04, 0.05, STAND.z + 0.04), Vector3(0.0, 0.025, 0.0), mahogany)
	# the drawer in its front (-Z): a darker front with a brass knob
	_drawer = Node3D.new()
	_drawer.name = "Drawer"
	_drawer.position = Vector3(0.0, DRAWER_Y, -STAND.z * 0.5 + DRAWER.z * 0.5)
	add_child(_drawer)
	StoryProps._box(_drawer, DRAWER, Vector3.ZERO, StoryProps.material(Color(0.24, 0.1, 0.05), 0.5))
	StoryProps._box(_drawer, Vector3(DRAWER.x + 0.02, DRAWER.y + 0.02, 0.012), Vector3(0.0, 0.0, -DRAWER.z * 0.5 - 0.006), mahogany)
	StoryProps._cylinder(_drawer, 0.015, 0.025, Vector3(0.0, 0.0, -DRAWER.z * 0.5 - 0.02), brass, Vector3(PI * 0.5, 0.0, 0.0))
	# the fork and the disc (the mater) facing the reader (-Z)
	StoryProps._cylinder(self, 0.012, DISC_AT.y - STAND.y - DISC_RADIUS + 0.02, Vector3(0.0, (STAND.y + DISC_AT.y - DISC_RADIUS) * 0.5, 0.0), dark_brass)
	StoryProps._cylinder(self, DISC_RADIUS, 0.014, DISC_AT, brass, Vector3(PI * 0.5, 0.0, 0.0))
	StoryProps._cylinder(self, DISC_RADIUS * 0.82, 0.016, DISC_AT + Vector3(0.0, 0.0, -0.001), dark_brass, Vector3(PI * 0.5, 0.0, 0.0))
	# the throne (the ring it hangs by) and the Pole Star on the rim at the top
	StoryProps._cylinder(self, 0.025, 0.012, DISC_AT + Vector3(0.0, DISC_RADIUS + 0.02, 0.0), brass, Vector3(PI * 0.5, 0.0, 0.0))
	_star = StoryProps._box(self, Vector3(0.026, 0.026, 0.01), DISC_AT + Vector3(0.0, DISC_RADIUS - 0.022, -0.012), StoryProps.glow(Color(1.0, 0.86, 0.5), 2.5), Vector3(0.0, 0.0, PI * 0.25))
	# the alidade: a bar across the face on a pin, a pointer at one end
	_alidade = Node3D.new()
	_alidade.name = "Alidade"
	_alidade.position = DISC_AT + Vector3(0.0, 0.0, -0.014)
	add_child(_alidade)
	StoryProps._box(_alidade, Vector3(0.022, DISC_RADIUS * 1.9, 0.006), Vector3.ZERO, brass)
	StoryProps._box(_alidade, Vector3(0.04, 0.04, 0.007), Vector3(0.0, DISC_RADIUS * 0.8, -0.001), brass, Vector3(0.0, 0.0, PI * 0.25))
	StoryProps._cylinder(_alidade, 0.012, 0.02, Vector3(0.0, 0.0, -0.006), dark_brass, Vector3(PI * 0.5, 0.0, 0.0))
	_set_alidade(step)
	_solid(Vector3(STAND.x + 0.06, DISC_AT.y + DISC_RADIUS, STAND.z + 0.06))
	add_box(Vector3(0.6, 0.6, 0.7), Vector3(0.0, DISC_AT.y - 0.1, -0.1))


func _show_done() -> void:
	step = 0
	_set_alidade(0)
	_drawer.position.z = _drawer_closed_z() - DRAWER_OUT
	retire()


func interact(by: Node) -> void:
	if not enabled or turning or is_done():
		return
	super(by)
	if not _told:
		_told = true
		spoke.emit(id, Curios.text_key(id))
	turning = true
	var from := step
	step = (step + 1) % STEPS
	Sfx.play_at(&"dial_click", global_transform * DISC_AT, -2.0)
	var tween := create_tween()
	tween.tween_method(_turn_between.bind(from), 0.0, 1.0, TURN_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_callback(_turned)


## The alidade's angle at notch [param notch]: clockwise from the top as
## seen from the front (-Z): the pointer at the star at 0.
static func angle_of(notch: int) -> float:
	return float(notch) * TAU / STEPS


func _set_alidade(notch: int) -> void:
	_alidade.rotation.z = angle_of(notch)


func _turn_between(t: float, from: int) -> void:
	_alidade.rotation.z = lerp_angle(angle_of(from), angle_of(from + 1), t)


func _turned() -> void:
	turning = false
	_set_alidade(step)
	if step != 0:
		return
	retire()
	WorldSounds.cue_at(&"drawer", global_transform * Vector3(0.0, DRAWER_Y, -0.3))
	var tween := create_tween()
	tween.tween_property(_drawer, ^"position:z", _drawer_closed_z() - DRAWER_OUT, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	solve()
	spoke.emit(id, Curios.answer_key(id))


func _drawer_closed_z() -> float:
	return -STAND.z * 0.5 + DRAWER.z * 0.5


## Rounds lie in the open drawer's mouth (the pickup floats over it).
func _loot_spot(index: int) -> Vector3:
	return Vector3(0.0, DRAWER_Y + 0.25, -STAND.z * 0.5 - 0.35 - 0.35 * index)
