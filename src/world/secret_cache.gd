class_name SecretCache
extends Interactable
## A secret without a false panel (Floor I greybox): a loose stone in the
## wall or the floor at a secret_* marker, a shade darker than the rest. E
## pulls it out ([signal found]); the hollow behind it stays open. The
## world content records the secret (WorldFeatures).
## Origin on the surface, -Z out of it.

signal found

const STONE := Vector3(0.36, 0.24, 0.12)

var _stone: MeshInstance3D


static func make(at: Transform3D) -> SecretCache:
	var cache := SecretCache.new()
	cache.transform = at
	return cache


func _init() -> void:
	super()
	prompt_key = "SECRET_CACHE_PROMPT"


func _ready() -> void:
	add_box(Vector3(STONE.x + 0.5, STONE.y + 0.5, 0.6), Vector3(0.0, 0.0, -0.2))
	_stone = MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = STONE
	_stone.mesh = mesh
	_stone.position = Vector3(0.0, 0.0, -STONE.z * 0.3)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.42, 0.4, 0.37)
	material.roughness = 0.95
	_stone.material_override = material
	add_child(_stone)


func interact(by: Node) -> void:
	if not enabled:
		return
	enabled = false
	collision_layer = 0
	super(by)
	var tween := create_tween()
	tween.tween_property(_stone, ^"position:z", -0.5, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_callback(_stone.hide)
	found.emit()
