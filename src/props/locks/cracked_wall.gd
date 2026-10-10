class_name CrackedWall
extends GateLock
## A bricked-up opening gone cracked (design 4.2): rubble at its foot, a
## web of cracks over its face. Only blasts break it: 40 blast damage
## summed within 0.3 s (two arrows of one hwacha volley) or three flares
## fired from within 5 m. Each close flare widens the cracks. Other hits
## only knock dust off. Broken, the wall caves in as big pieces of itself
## in a cloud of dust.

const DEPTH := 0.4
const PIECES := 12
## How much the cracks grow per close flare.
const CRACK_GROWTH := 0.22

var _slab: MeshInstance3D
var _cracks: Decal
var _rubble: Node3D


func _init() -> void:
	kind = Kind.CRACKED


func _build_body() -> void:
	var brick := LockArt.tile("brick", 1.0, Color(0.5, 0.33, 0.27), Color(0.92, 0.88, 0.84))
	var mesh := BoxMesh.new()
	mesh.size = Vector3(size.x, size.y, DEPTH)
	_slab = MeshInstance3D.new()
	_slab.name = "Slab"
	_slab.mesh = mesh
	_slab.material_override = brick
	_slab.position = Vector3(0.0, size.y * 0.5, 0.0)
	add_child(_slab)
	MeshShards.warm_slices(mesh, PIECES)
	_cracks = Decal.new()
	_cracks.name = "Cracks"
	_cracks.texture_albedo = LockArt.crack_texture()
	_cracks.size = Vector3(size.x * 0.9, 0.3, size.y * 0.75)
	# a decal paints surfaces facing its +Y: turn that to the wall's front (-Z)
	_cracks.transform = Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(0.0, size.y * 0.45, -DEPTH * 0.5))
	_cracks.cull_mask = 1
	add_child(_cracks)
	_rubble = Node3D.new()
	_rubble.name = "Rubble"
	add_child(_rubble)
	var stone := LockArt.tile("stone_rubble", 0.6, Color(0.5, 0.47, 0.42))
	var rng := RandomNumberGenerator.new()
	rng.seed = 9031
	for i in 9:
		var s := rng.randf_range(0.08, 0.2)
		LockArt.box(_rubble, Vector3(s, s * 0.7, s * 0.9), Vector3(rng.randf_range(-size.x * 0.45, size.x * 0.45), s * 0.3,
				-DEPTH * 0.5 - rng.randf_range(0.05, 0.35)), stone, Vector3(rng.randf_range(-20, 20), rng.randf_range(0, 90), rng.randf_range(-20, 20)))
	_add_blocker(Vector3(size.x, size.y, DEPTH), Vector3(0.0, size.y * 0.5, 0.0))
	_add_face_zones(Vector3(size.x, size.y, DEPTH), Vector3(0.0, size.y * 0.5, 0.0))
	_add_prompt(Vector3(size.x, size.y, DEPTH), Vector3(0.0, size.y * 0.5, 0.0))


func _break() -> void:
	var xform := _slab.global_transform
	var materials: Array = [_slab.material_override]
	var center := xform.origin
	var away := global_basis.z
	for shard: MeshShards.Piece in MeshShards.slices(_slab.mesh, PIECES):
		var at := xform * shard.center
		var out := (at - center)
		out = Vector3(out.x, maxf(out.y, 0.0), 0.0) * 0.8
		var fling := away * randf_range(1.0, 3.5) + out + Vector3(0.0, randf_range(0.3, 1.5), 0.0)
		Fx.piece(shard, MeshShards.materials_for(shard, materials), xform, fling, 4.0)
	for i in 6:
		var at := center + global_basis * Vector3(randf_range(-size.x * 0.4, size.x * 0.4), randf_range(-size.y * 0.4, size.y * 0.3), -DEPTH * 0.5)
		Fx.impact(at, -away, -1, 3.0)
	Fx.flash(center, Color(1.0, 0.75, 0.5), 2.0, 6.0, 0.15)
	Sfx.play_at(&"lock_wall_collapse", center, 3.0)
	Events.shake_requested.emit(0.5)


func _show_open(animated: bool) -> void:
	super(animated)
	_slab.visible = false
	_cracks.visible = false


## A close flare that counts: the cracks spread (wider and darker).
func _on_give(info: DamageInfo, strength: float) -> void:
	super(info, strength)
	if LockRules.verdict(kind, info) == LockRules.Verdict.STRIKE:
		var grow := 1.0 + CRACK_GROWTH * tally.strikes
		_cracks.size = Vector3(size.x * 0.9 * minf(grow, 1.1), 0.3, size.y * 0.75 * grow)
		Sfx.play_at(&"lock_wall_crack", info.position, 0.0)


func _wrong_effect(info: DamageInfo, counts: bool) -> void:
	Fx.impact(info.position, info.normal, -1, 1.4 if counts else 0.8)
	Sfx.play_at(&"wall_hit", info.position, -1.0 if counts else -4.0)


func _play_rattle() -> void:
	Sfx.play_at(&"wall_hit", global_position + Vector3.UP * 1.2, -4.0)


## A cracked wall does not move: a hit only trickles grit.
func _animate_jolt(_amount: float) -> void:
	pass
