class_name TicketDrawer
extends Interactable
## The till drawer of the ticket booth. Heniek's sticky note sends the new
## guard here: the gun locker key lies inside among old tickets. Opened,
## the drawer stays open for the night; on later nights it is shut again
## with nothing in it but the tickets and a button (the key,
## GameState.pistol_key, is the guard's for good) - E still opens it, for
## the joke ([signal found_empty]).
## Origin at the drawer's front on the booth wall, -Z pointing out.

signal key_taken
## Opened, but the key was taken on an earlier night.
signal found_empty

## Far enough out that the key clears the booth's counter ledge above.
const SLIDE := 0.45
const OPEN_TIME := 0.4
const FRONT := Vector3(0.56, 0.16, 0.03)
const BODY := Vector3(0.5, 0.07, 0.38)

static var _materials: Dictionary = {}

var has_key: bool = true
var is_open: bool = false

var _drawer: Node3D
var _key: Node3D


static func make(marker: Transform3D, key_inside: bool) -> TicketDrawer:
	var drawer := TicketDrawer.new()
	drawer.name = "TicketDrawer"
	drawer.transform = marker
	drawer.has_key = key_inside
	return drawer


func _init() -> void:
	super()
	prompt_key = "PROMPT_DRAWER"


func _ready() -> void:
	add_box(Vector3(0.8, 0.34, 0.36), Vector3(0.0, -0.05, -0.18))
	_build()


## Open and empty at once (the key was found on an earlier night).
func set_open() -> void:
	is_open = true
	has_key = false
	_drawer.position.z = -SLIDE
	_key.visible = false
	_retire_zone()


func interact(by: Node) -> void:
	if is_open or not enabled:
		return
	super(by)
	is_open = true
	_retire_zone()
	WorldSounds.cue_at(&"drawer", global_position)
	var tween := create_tween()
	tween.tween_property(_drawer, ^"position:z", -SLIDE, OPEN_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if has_key:
		has_key = false
		# the key catches the light a moment, then the guard pockets it
		tween.tween_interval(0.4)
		tween.tween_callback(func() -> void: _key.visible = false)
		key_taken.emit()
	else:
		found_empty.emit()


func _retire_zone() -> void:
	enabled = false
	collision_layer = 0


func _build() -> void:
	var wood := _material(&"wood", Color(0.5, 0.33, 0.2), 0.6, 0.0)
	var inner := _material(&"inner", Color(0.62, 0.47, 0.32), 0.8, 0.0)
	var brass := _material(&"brass", Color(0.86, 0.67, 0.32), 0.25, 0.85)
	var paper := _material(&"ticket", Color(0.86, 0.72, 0.68), 0.9, 0.0)
	_drawer = Node3D.new()
	_drawer.name = "Drawer"
	add_child(_drawer)
	var y := -0.05
	_box(_drawer, FRONT, Vector3(0.0, y, -FRONT.z * 0.5), wood)
	_box(_drawer, Vector3(0.14, 0.024, 0.03), Vector3(0.0, y - 0.02, -FRONT.z - 0.015), brass)
	_box(_drawer, Vector3(0.1, 0.035, 0.004), Vector3(0.0, y + 0.035, -FRONT.z - 0.002), brass)
	# the drawer's box behind its front, inside the booth
	_box(_drawer, Vector3(BODY.x, 0.012, BODY.z), Vector3(0.0, y - BODY.y * 0.5, BODY.z * 0.5), inner)
	for side in [-1.0, 1.0]:
		_box(_drawer, Vector3(0.012, BODY.y, BODY.z), Vector3(side * BODY.x * 0.5, y, BODY.z * 0.5), inner)
	_box(_drawer, Vector3(BODY.x, BODY.y, 0.012), Vector3(0.0, y, BODY.z), inner)
	# old tickets
	for i in 4:
		var ticket := _box(_drawer, Vector3(0.09, 0.003, 0.05), Vector3(-0.16 + i * 0.075, y - BODY.y * 0.5 + 0.01 + i * 0.003, 0.08 + (i % 2) * 0.04), paper)
		ticket.rotation.y = (i - 1.5) * 0.3
	# the key: a bow, a shaft and a bit
	_key = Node3D.new()
	_key.name = "Key"
	_key.position = Vector3(0.1, y - BODY.y * 0.5 + 0.012, 0.1)
	_key.rotation.y = 0.5
	_drawer.add_child(_key)
	var shine := _material(&"key", Color(0.95, 0.78, 0.4), 0.2, 0.9)
	shine.emission_enabled = true
	shine.emission = Color(1.0, 0.8, 0.45)
	shine.emission_energy_multiplier = 0.6
	_box(_key, Vector3(0.036, 0.006, 0.036), Vector3(-0.05, 0.0, 0.0), shine)
	_box(_key, Vector3(0.08, 0.006, 0.009), Vector3(0.0, 0.0, 0.0), shine)
	_box(_key, Vector3(0.014, 0.006, 0.024), Vector3(0.034, 0.0, 0.011), shine)
	_key.visible = has_key


static func _box(parent: Node3D, size: Vector3, at: Vector3, material: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var view := MeshInstance3D.new()
	view.mesh = mesh
	view.position = at
	view.material_override = material
	parent.add_child(view)
	return view


static func _material(key: StringName, color: Color, roughness: float, metallic: float) -> StandardMaterial3D:
	if not _materials.has(key):
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.roughness = roughness
		material.metallic = metallic
		_materials[key] = material
	return _materials[key]
