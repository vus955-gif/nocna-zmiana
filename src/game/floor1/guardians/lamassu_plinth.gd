class_name LamassuPlinth
extends StaticBody3D
## The alabaster plinth the Lamassu sleeps on against the courtyard's north
## wall (plan docs/superpowers/plans/2026-10-03-straznik-lamassu.md,
## decision 7): half a metre of stone, as long as the bull. Level geometry
## (layer WORLD): shots and the guard stop at it; the waking bull steps
## down off it hoof by hoof and it stays, empty, every night after its
## fall. Raised by Lamassu.dress_arena() on the guardian_lamassu marker
## (group &"lamassu_plinth"). Origin = the floor under the bull's middle,
## -Z its front (as the lamassu model).

const GROUP := &"lamassu_plinth"
const MODEL := "asy_plinth_low"
## The kit piece is 2.5 x 0.4 x 1.3 m: it is turned along the bull and
## stretched to SIZE.
const MODEL_SIZE := Vector3(2.5, 0.4, 1.3)
const HEIGHT := 0.5
const SIZE := Vector3(2.2, HEIGHT, 4.6)
const ALABASTER := Color(0.84, 0.8, 0.72)

var _visual: Node3D


static func make(at: Transform3D) -> LamassuPlinth:
	var plinth := LamassuPlinth.new()
	plinth.transform = at
	plinth.name = "LamassuPlinth"
	return plinth


func _ready() -> void:
	add_to_group(GROUP)
	collision_layer = Layers.WORLD
	collision_mask = 0
	var shape := BoxShape3D.new()
	shape.size = SIZE
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position = Vector3(0.0, HEIGHT * 0.5, 0.0)
	add_child(collider)
	_visual = ArtLibrary.try_instance(MODEL)
	if _visual != null:
		# the kit piece lies across: turned a quarter, stretched to the bull
		_visual.rotation.y = PI * 0.5
		_visual.scale = Vector3(SIZE.z / MODEL_SIZE.x, SIZE.y / MODEL_SIZE.y, SIZE.x / MODEL_SIZE.z)
	else:
		_visual = _greybox()
	_visual.name = "Visual"
	add_child(_visual)


## Height of its top over its floor.
func top() -> float:
	return HEIGHT


## The floor point in front of it where the bull's fore hooves come down
## (world).
func step_off_point(aside: float = 0.0) -> Vector3:
	return to_global(Vector3(aside, 0.0, -SIZE.z * 0.5 - 0.9))


func _greybox() -> Node3D:
	var root := Node3D.new()
	var material := StandardMaterial3D.new()
	material.albedo_color = ALABASTER
	material.roughness = 0.9
	var mesh := BoxMesh.new()
	mesh.size = SIZE
	var view := MeshInstance3D.new()
	view.mesh = mesh
	view.position = Vector3(0.0, HEIGHT * 0.5, 0.0)
	view.material_override = material
	root.add_child(view)
	return root
