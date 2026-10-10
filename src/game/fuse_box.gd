class_name FuseBox
extends Interactable
## The fuse box on the hall's north wall by the grate: two empty sockets
## and a lamp (red while a fuse is missing, green once both are in). E puts
## the carried fuses in ([signal fed]) or, empty-handed, only rattles the
## door ([signal refused]). Origin on its front face, -Z = out.

signal fed(by: Node)
signal refused(by: Node)

const SLOT_X := 0.14
const RED := Color(1.0, 0.12, 0.08)
const GREEN := Color(0.3, 1.0, 0.45)

## Fuses in the guard's pocket (the night's RunState when set).
var run: NightState = null

var _slots: Array[Node3D] = []
var _lamp: MeshInstance3D
var _lamp_light: OmniLight3D
var _inserted: int = 0


func _init() -> void:
	super()
	prompt_key = "PROMPT_FUSE_BOX_EMPTY"


func _ready() -> void:
	LevelKit.tag(self, &"fuse_box_front", Vector3(0.7, 0.9, 0.05), &"hall")
	add_box(Vector3(0.9, 1.0, 0.45), Vector3(0.0, 0.45, -0.1))
	var dark := Color(0.12, 0.13, 0.12)
	for side in [-1.0, 1.0]:
		var socket := Node3D.new()
		socket.position = Vector3(side * SLOT_X, 0.45, -0.03)
		add_child(socket)
		PropKit.box(socket, Vector3(0.09, 0.3, 0.03), Vector3.ZERO, dark)
		for end in [-1.0, 1.0]:
			PropKit.box(socket, Vector3(0.05, 0.03, 0.03), Vector3(0.0, end * 0.12, -0.015), LevelKit.BRASS)
		var fuse := Node3D.new()
		fuse.name = "Fuse"
		fuse.rotation.z = PI * 0.5
		fuse.position.z = -0.035
		fuse.visible = false
		socket.add_child(fuse)
		FusePickup.build_fuse(fuse, 1.4)
		_slots.append(socket)
	_lamp = PropKit.box(self, Vector3(0.07, 0.07, 0.03), Vector3(0.24, 0.8, -0.03), RED, 3.0)
	_lamp_light = PropKit.glow_light(self, RED, 0.5, 2.0, Vector3(0.24, 0.8, -0.25))
	_show()


func prompt() -> String:
	return tr("PROMPT_FUSE_BOX" if _carried() > 0 else "PROMPT_FUSE_BOX_EMPTY")


func can_interact(by: Node) -> bool:
	return super(by) and _inserted < 2


func interact(by: Node) -> void:
	if _carried() <= 0:
		Sfx.play(&"deny", -4.0)
		refused.emit(by)
		return
	Sfx.play_at(&"fuse_insert", global_position + Vector3.UP * 0.45)
	fed.emit(by)
	super(by)


## Shows [param count] fuses in their sockets (0-2).
func set_inserted(count: int) -> void:
	_inserted = clampi(count, 0, 2)
	enabled = _inserted < 2
	_show()


func inserted() -> int:
	return _inserted


func _carried() -> int:
	return run.fuses_carried if run != null else 0


func _show() -> void:
	if _lamp == null:
		return
	for i in _slots.size():
		(_slots[i].get_node(^"Fuse") as Node3D).visible = i < _inserted
	var color := GREEN if _inserted >= 2 else RED
	_lamp.material_override = PropKit.material(color, 3.0)
	_lamp_light.light_color = color
