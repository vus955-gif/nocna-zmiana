class_name Switchboard
extends Interactable
## The switchboard in the basement (design 4.3): with both fuses found (the
## boiler room's and Assyria's, key items for good) E fits them and the
## power comes back to the north corridor's fire shutters ([signal
## powered]: the GateController rolls them up; the flag power_north stays
## set). Without them the line says how many it still lacks. Origin on the
## cabinet's face, -Z into the room.

signal powered

const POWER_FLAG := &"power_north"
const FUSES: Array[StringName] = [&"fuse_basement", &"fuse_assyria"]
const BODY := Vector3(1.1, 1.5, 0.3)
const RED := Color(1.0, 0.12, 0.06)
const GREEN := Color(0.25, 1.0, 0.35)

var game: PersistentState = null

var _lamp: MeshInstance3D


func _ready() -> void:
	if game == null:
		game = GameState
	add_box(Vector3(BODY.x + 0.2, BODY.y + 0.2, 0.8), Vector3(0.0, 0.0, -0.2))
	var cabinet := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = BODY
	cabinet.mesh = mesh
	cabinet.position = Vector3(0.0, 0.0, BODY.z * 0.5)
	var art := LevelArt.enabled and ArtLibrary.models_enabled
	cabinet.material_override = BasementArt.cabinet_paint() if art else GreyLock._material(Color(0.32, 0.36, 0.33))
	add_child(cabinet)
	for i in FUSES.size():
		var socket := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.12, 0.3, 0.06)
		socket.mesh = box
		socket.position = Vector3(-0.2 + i * 0.4, 0.15, -0.02)
		socket.material_override = GreyLock._material(Color(0.12, 0.12, 0.12))
		add_child(socket)
	_lamp = MeshInstance3D.new()
	var bulb := SphereMesh.new()
	bulb.radius = 0.06
	bulb.height = 0.12
	_lamp.mesh = bulb
	_lamp.position = Vector3(0.0, 0.55, -0.04)
	add_child(_lamp)
	if art:
		BasementArt.dress_switchboard(self, BODY)
	_show()


func fuses_held() -> int:
	var held := 0
	for fuse in FUSES:
		if game.has_item(fuse):
			held += 1
	return held


func is_powered() -> bool:
	return game.has_flag(POWER_FLAG)


func prompt() -> String:
	if is_powered():
		return tr("SWITCHBOARD_ON")
	if fuses_held() >= FUSES.size():
		return tr("SWITCHBOARD_FIT")
	return tr("SWITCHBOARD_NEED") % [fuses_held(), FUSES.size()]


func can_interact(_by: Node) -> bool:
	return enabled and not is_powered()


func interact(by: Node) -> void:
	if is_powered():
		return
	if fuses_held() < FUSES.size():
		Sfx.play_at(&"deny", global_position, -4.0)
		if Events.has_signal(&"hint_requested"):
			Events.emit_signal(&"hint_requested", prompt())
		return
	game.set_flag(POWER_FLAG)
	Sfx.play_at(&"lock_power_on", global_position)
	_show()
	super(by)
	powered.emit()


func _show() -> void:
	_lamp.material_override = GreyLock._material(GREEN if is_powered() else RED, true)
