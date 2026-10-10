class_name UpgradeTerminal
extends Interactable
## The upgrade terminal in a haven: an old desk with a glowing CRT. Using it
## (E) emits [signal opened]; the game scene opens the UpgradeMenu. Its
## origin stands on the floor and its screen faces -Z, into the room. An
## upgrade bought (Events.upgrade_bought) flashes its screen gold with an
## anvil ting (the weapon in the guard's hand shows it at once).

signal opened(by: Node)

const SCREEN_COLOR := Color(1.0, 0.72, 0.38)
## A purchase: the screen's light jumps to this and settles back.
const FLASH_ENERGY := 5.0
const FLASH_TIME := 0.6

static var _materials: Dictionary = {}

var _screen: MeshInstance3D
var _glow: OmniLight3D
var _time: float = 0.0
var _flash: float = 0.0


func _init() -> void:
	super()
	prompt_key = "PROMPT_TERMINAL"


func _ready() -> void:
	add_box(Vector3(1.3, 1.5, 1.0), Vector3(0.0, 0.8, 0.0))
	_build_model()
	Events.upgrade_bought.connect(_on_upgrade_bought)


## 0..1: how much of a purchase's flash is left.
func flash_left() -> float:
	return _flash


func interact(by: Node) -> void:
	Sfx.play_ui(&"interact")
	super(by)
	opened.emit(by)


func _process(delta: float) -> void:
	_time += delta
	_flash = maxf(_flash - delta / FLASH_TIME, 0.0)
	# a faint CRT shimmer, and the gold flash of a purchase
	var shimmer := 0.9 + 0.08 * sin(_time * 9.0) + 0.05 * sin(_time * 23.0)
	_glow.light_energy = lerpf(shimmer, FLASH_ENERGY, _flash * _flash)
	_glow.light_color = SCREEN_COLOR.lerp(WeaponLook.MASTER_COLOR.lightened(0.3), _flash)


func _on_upgrade_bought(_id: StringName, _level: int) -> void:
	if not is_inside_tree():
		return
	_flash = 1.0
	Sfx.play_at(&"upgrade_forge", global_position + Vector3.UP, -2.0)


func _build_model() -> void:
	var desk := StaticBody3D.new()
	desk.name = "Desk"
	desk.collision_layer = Layers.WORLD
	desk.collision_mask = 0
	add_child(desk)
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.2, 0.8, 0.7)
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position = Vector3(0.0, 0.4, 0.0)
	desk.add_child(collider)
	var computer := ArtLibrary.try_instance(&"terminal")
	if computer != null:
		# the old PC on its little table; the model faces +Z, the terminal -Z
		computer.rotation.y = PI
		desk.add_child(computer)
		var box := _bounds(computer)
		shape.size = Vector3(box.size.x, 0.8, box.size.z)
		collider.position = Vector3(box.get_center().x, 0.4, box.get_center().z)
		_add_glow()
		return
	var wood := _material(Color(0.28, 0.19, 0.13), 0.7)
	var metal := _material(Color(0.16, 0.16, 0.17), 0.45)
	_part(desk, Vector3(1.2, 0.06, 0.7), Vector3(0.0, 0.77, 0.0), wood)
	_part(desk, Vector3(0.06, 0.74, 0.62), Vector3(-0.56, 0.37, 0.0), wood)
	_part(desk, Vector3(0.06, 0.74, 0.62), Vector3(0.56, 0.37, 0.0), wood)
	_part(desk, Vector3(1.1, 0.5, 0.04), Vector3(0.0, 0.5, 0.3), wood)
	# the monitor, its screen and a keyboard
	_part(desk, Vector3(0.52, 0.44, 0.46), Vector3(0.0, 1.03, 0.08), metal)
	_part(desk, Vector3(0.16, 0.06, 0.16), Vector3(0.0, 0.83, 0.1), metal)
	_part(desk, Vector3(0.46, 0.03, 0.16), Vector3(0.0, 0.815, -0.2), metal)
	var screen_material := StandardMaterial3D.new()
	screen_material.albedo_color = Color(0.05, 0.03, 0.02)
	screen_material.emission_enabled = true
	screen_material.emission = SCREEN_COLOR
	screen_material.emission_energy_multiplier = 2.2
	_screen = _part(desk, Vector3(0.42, 0.32, 0.01), Vector3(0.0, 1.04, -0.155), screen_material)
	_add_glow()


## Box around [param node]'s meshes, in [param node]'s parent space.
static func _bounds(node: Node3D) -> AABB:
	var out := AABB()
	var first := true
	for child in node.find_children("*", "MeshInstance3D", true, false):
		var view := child as MeshInstance3D
		var xform := node.transform
		var walk := view as Node3D
		var chain := Transform3D.IDENTITY
		while walk != node:
			chain = walk.transform * chain
			walk = walk.get_parent() as Node3D
		var box := xform * chain * view.get_aabb()
		out = box if first else out.merge(box)
		first = false
	return out


## The CRT's warm light spilling into the room.
func _add_glow() -> void:
	_glow = OmniLight3D.new()
	_glow.light_color = SCREEN_COLOR
	_glow.light_energy = 0.9
	_glow.omni_range = 3.2
	_glow.light_volumetric_fog_energy = 0.6
	_glow.position = Vector3(0.0, 1.05, -0.45)
	add_child(_glow)


static func _part(parent: Node3D, size: Vector3, at: Vector3, material: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var view := MeshInstance3D.new()
	view.mesh = mesh
	view.material_override = material
	view.position = at
	parent.add_child(view)
	return view


static func _material(color: Color, roughness: float) -> StandardMaterial3D:
	if not _materials.has(color):
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.roughness = roughness
		_materials[color] = material
	return _materials[color]
