class_name CctvConsole
extends Interactable
## The camera console on the security desk: a sloping steel panel with six
## numbered buttons, a joystick and a small lit strip. E opens the camera
## view ([signal used]). Origin on the desk top, -Z towards the guard.

signal used

static var _materials: Dictionary = {}

var _lamp: MeshInstance3D
var _time: float = 0.0


func _init() -> void:
	super()
	prompt_key = "PROMPT_CCTV"


func _ready() -> void:
	add_box(Vector3(0.8, 0.4, 0.55), Vector3(0.0, 0.14, 0.0))
	_build()


func interact(by: Node) -> void:
	super(by)
	used.emit()


func _process(delta: float) -> void:
	_time += delta
	if _lamp != null:
		_lamp.visible = fmod(_time, 1.6) < 1.2


func _build() -> void:
	var steel := _solid(&"steel", Color(0.24, 0.25, 0.27), 0.5, 0.5)
	var dark := _solid(&"dark", Color(0.06, 0.06, 0.07), 0.8, 0.0)
	var cap := _solid(&"cap", Color(0.78, 0.74, 0.66), 0.5, 0.0)
	var base := _box(self, Vector3(0.62, 0.06, 0.34), Vector3(0.0, 0.03, 0.0), steel)
	base.name = "Base"
	# the sloping face, raised at the back
	var face := Node3D.new()
	face.position = Vector3(0.0, 0.09, 0.0)
	face.rotation.x = -0.35
	add_child(face)
	_box(face, Vector3(0.6, 0.03, 0.3), Vector3.ZERO, steel)
	for i in 6:
		var x := -0.24 + (i % 3) * 0.08
		var z := -0.06 + (i / 3) * 0.08
		_box(face, Vector3(0.05, 0.02, 0.05), Vector3(x, 0.02, z), cap)
	_box(face, Vector3(0.08, 0.012, 0.08), Vector3(0.16, 0.021, 0.0), dark)
	_box(face, Vector3(0.018, 0.09, 0.018), Vector3(0.16, 0.065, 0.0), dark)
	var knob := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.022
	sphere.height = 0.044
	knob.mesh = sphere
	knob.material_override = _solid(&"knob", Color(0.62, 0.1, 0.08), 0.4, 0.0)
	knob.position = Vector3(0.16, 0.115, 0.0)
	face.add_child(knob)
	_lamp = _box(face, Vector3(0.12, 0.012, 0.025), Vector3(-0.16, 0.02, 0.1), _glow(Color(0.35, 1.0, 0.5)))


static func _box(parent: Node3D, size: Vector3, at: Vector3, material: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var view := MeshInstance3D.new()
	view.mesh = mesh
	view.position = at
	view.material_override = material
	parent.add_child(view)
	return view


static func _solid(key: StringName, color: Color, roughness: float, metallic: float) -> StandardMaterial3D:
	if not _materials.has(key):
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.roughness = roughness
		material.metallic = metallic
		_materials[key] = material
	return _materials[key]


static func _glow(color: Color) -> StandardMaterial3D:
	var key := StringName("glow_" + color.to_html())
	if not _materials.has(key):
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = 2.0
		_materials[key] = material
	return _materials[key]
