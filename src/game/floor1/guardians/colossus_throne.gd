class_name ColossusThrone
extends Node3D
## Ramesses's throne (colossus_throne): the granite seat the Colossus sits
## on, its 0.6 m plinth under his feet, sema-tawy reliefs on its sides and
## the two openings (swarm_l, swarm_r) the scarab swarms pour out of.
## Level geometry (layer WORLD): plinth, seat and back block shots, the beam
## and the guard; the seated Colossus is excepted from colliding with it
## (Colossus.add_collision_exception_with(body)). It stays when he stands
## up (cracking under him) and after his fall. Origin = the floor under his
## hip joints, front = -Z (as the colossus model). Raised by
## Colossus.dress_arena() on the guardian_colossus marker (group
## &"colossus_throne").

const GROUP := &"colossus_throne"
const MODEL := &"colossus_throne"
const GRANITE := Color(0.55, 0.3, 0.24)
## Collision boxes: [centre, size] (the model's shape, measured).
const BOXES := [
	[Vector3(0.0, 0.3, -1.1), Vector3(3.9, 0.6, 5.6)],      # plinth
	[Vector3(0.0, 1.78, -0.18), Vector3(3.26, 2.36, 2.96)],  # seat
	[Vector3(0.0, 4.45, 1.22), Vector3(3.2, 3.0, 0.95)],     # back
]
## The openings in its sides (the model's markers).
const OPENINGS := [Vector3(-1.62, 1.0, -0.9), Vector3(1.62, 1.0, -0.9)]
const VENT := Color(1.0, 0.62, 0.2)

var body: StaticBody3D

var _vents: Array[OmniLight3D] = []
var _visual: Node3D


static func make(at: Transform3D) -> ColossusThrone:
	var throne := ColossusThrone.new()
	throne.transform = at
	throne.name = "ColossusThrone"
	return throne


func _ready() -> void:
	add_to_group(GROUP)
	body = StaticBody3D.new()
	body.name = "Body"
	body.collision_layer = Layers.WORLD
	body.collision_mask = 0
	add_child(body)
	for box: Array in BOXES:
		var shape := BoxShape3D.new()
		shape.size = box[1]
		var collider := CollisionShape3D.new()
		collider.shape = shape
		collider.position = box[0]
		body.add_child(collider)
	_visual = ArtLibrary.try_instance(MODEL)
	if _visual == null:
		_visual = _greybox()
	_visual.name = "Visual"
	add_child(_visual)
	for at: Vector3 in OPENINGS:
		var light := OmniLight3D.new()
		light.light_color = VENT
		light.light_energy = 0.0
		light.omni_range = 3.5
		light.position = at + Vector3(signf(at.x) * 0.3, 0.0, 0.0)
		light.visible = false
		add_child(light)
		_vents.append(light)


## World position of opening [param side] (1 = his left, -1 = his right),
## a little outside the stone.
func opening(side: int) -> Vector3:
	var local: Vector3 = OPENINGS[0] if side > 0 else OPENINGS[1]
	return to_global(local + Vector3(signf(local.x) * 0.6, -0.4, 0.0))


## Opening [param side] glows (0..1): something stirs in it.
func vent(side: int, amount: float) -> void:
	if _vents.is_empty():
		return
	var light := _vents[0] if side > 0 else _vents[1]
	light.visible = amount > 0.01
	light.light_energy = 3.0 * amount


## The seat cracks under the rising Colossus: chips and dust off its arms.
func crack(strength: float = 1.0) -> void:
	for i in int(6 * strength):
		var at := to_global(Vector3(randf_range(-1.6, 1.6), randf_range(2.4, 3.0), randf_range(-1.4, 1.0)))
		Fx.chunk(at, GRANITE, randf_range(0.12, 0.35), Vector3(randf_range(-2.0, 2.0), randf_range(0.5, 2.5), randf_range(-2.0, 2.0)))
	Fx.impact(to_global(Vector3(0.0, 3.0, -1.0)), Vector3.UP, ExhibitMaterial.Kind.MARBLE, 3.0 * strength)


func _greybox() -> Node3D:
	var root := Node3D.new()
	var material := StandardMaterial3D.new()
	material.albedo_color = GRANITE
	for box: Array in BOXES:
		var mesh := BoxMesh.new()
		mesh.size = box[1]
		var view := MeshInstance3D.new()
		view.mesh = mesh
		view.position = box[0]
		view.material_override = material
		root.add_child(view)
	return root
