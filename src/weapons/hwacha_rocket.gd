class_name HwachaRocket
extends Node3D
## One fire-arrow of the hwacha's volley (design 7.1): a small rocket
## flying on a shallow arc with a tail of fire. Every physics frame a ray
## from its head along the move finds what it meets first (walls, hit
## zones; never the guard). A hit zone takes the arrow itself
## ([member WeaponData.damage], fire: wax double) and catches fire for a
## moment (Burn); wherever it lands it bursts in a small blast
## (blast_damage within blast_radius, the guard's own blast capped as the
## flare's). Hits are explosive and carry weapon = hwacha (boards and
## cracked walls give way). Past max_range it fizzles out in the air.
## Only every LIGHT_EVERY-th rocket carries a light (a volley is six).
## The node's origin is the arrowhead; -Z points along its flight.

const MODEL := &"hwacha_rocket"
const LIGHT_EVERY := 3
const LENGTH := 0.5
const TRAIL_COLOR := Color(1.0, 0.55, 0.2)

## Rockets launched so far (which ones get a light).
static var _launched: int = 0
static var _materials: Dictionary = {}

var velocity := Vector3.ZERO
var shot: WeaponData = null
var shooter: Node3D = null
var fired_from := Vector3.INF

var _start := Transform3D.IDENTITY
var _flown: float = 0.0
var _done: bool = false
var _trail: GPUParticles3D


## A rocket whose head starts at [param from] flying with
## [param velocity_]. Add it to the tree yourself.
static func launch(from: Vector3, velocity_: Vector3, data: WeaponData, by: Node3D) -> HwachaRocket:
	var rocket := HwachaRocket.new()
	rocket.shot = data
	rocket.shooter = by
	rocket.velocity = velocity_
	rocket.fired_from = from
	rocket._start = Transform3D(Projectile._facing(velocity_), from)
	rocket.transform = rocket._start
	rocket.name = "HwachaRocket"
	return rocket


func _ready() -> void:
	global_transform = _start
	reset_physics_interpolation()
	_build()


func _physics_process(delta: float) -> void:
	if _done:
		return
	var data := _data()
	velocity.y -= data.projectile_gravity * delta
	var motion := velocity * delta
	var hit := Hitscan.ray(get_world_3d().direct_space_state, global_position, global_position + motion)
	if hit.is_empty():
		global_position += motion
		global_basis = Projectile._facing(velocity)
		_flown += motion.length()
		if _flown >= data.max_range:
			_fizzle()
		return
	var point: Vector3 = hit["position"]
	var normal: Vector3 = hit["normal"]
	if normal.is_zero_approx():
		normal = -velocity.normalized()
	_burst(hit["hurtbox"] as Hurtbox, point, normal)


func _burst(hurtbox: Hurtbox, point: Vector3, normal: Vector3) -> void:
	var data := _data()
	var by: Node3D = shooter if is_instance_valid(shooter) else null
	var heading := velocity.normalized()
	if hurtbox != null and hurtbox.receiver != null and hurtbox.receiver != by and hurtbox.receiver.has_method(&"take_damage"):
		var receiver := hurtbox.receiver
		var info := DamageInfo.make(Blast.scaled(data.damage, receiver, data.damage_kind), data.damage_kind, by)
		info.position = point
		info.normal = normal
		info.direction = heading
		info.knockback = data.knockback
		info.weapon = data.id
		info.origin = fired_from
		info.explosive = true
		receiver.take_damage(info)
		var host := receiver as Enemy
		if host != null and host.brain.state != EnemyBrain.State.DESTROYED and data.burn_time > 0.0:
			Burn.ignite(host, data.burn_dps, data.burn_time, by)
	var blast := data.blast_damage if data.blast_damage > 0.0 else data.damage
	if data.blast_radius > 0.0:
		Blast.explode(self, point + normal * 0.05, data.blast_radius, blast, data.knockback, data.damage_kind, by,
				heading, data.id, fired_from, &"hwacha_pop")
	_end()


## Out of fuel: a puff of sparks, no blast.
func _fizzle() -> void:
	Fx.impact(global_position, -velocity.normalized(), ExhibitMaterial.Kind.METAL, 0.6)
	_end()


func _end() -> void:
	_done = true
	visible = false
	# the trail's last sparks fade where they are
	if _trail != null:
		_trail.emitting = false
	if is_inside_tree():
		get_tree().create_timer(0.5, false).timeout.connect(queue_free)
	else:
		queue_free()


func _data() -> WeaponData:
	return shot if shot != null else WeaponData.new()


func _build() -> void:
	var model := ArtLibrary.try_instance(MODEL)
	if model != null:
		var tip := Vector3(0.0, 0.0, -LENGTH * 0.5)
		var mesh := model.find_child(String(MODEL), true, false) as MeshInstance3D
		if mesh != null:
			tip = Vector3(0.0, 0.0, mesh.get_aabb().position.z)
		model.position = -tip
	else:
		model = Node3D.new()
		var shaft := MeshInstance3D.new()
		var tube := CylinderMesh.new()
		tube.top_radius = 0.006
		tube.bottom_radius = 0.006
		tube.height = LENGTH
		tube.radial_segments = 5
		tube.rings = 1
		shaft.mesh = tube
		shaft.rotation_degrees = Vector3(90.0, 0.0, 0.0)
		shaft.position = Vector3(0.0, 0.0, LENGTH * 0.5)
		shaft.material_override = _material(Color(0.45, 0.32, 0.18))
		model.add_child(shaft)
		var powder := MeshInstance3D.new()
		var can := CylinderMesh.new()
		can.top_radius = 0.016
		can.bottom_radius = 0.016
		can.height = 0.12
		can.radial_segments = 6
		can.rings = 1
		powder.mesh = can
		powder.rotation_degrees = Vector3(90.0, 0.0, 0.0)
		powder.position = Vector3(0.0, 0.0, 0.1)
		powder.material_override = _material(Color(0.72, 0.12, 0.08))
		model.add_child(powder)
	model.name = "Model"
	for view in model.find_children("*", "GeometryInstance3D", true, false):
		(view as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(model)
	_trail = GPUParticles3D.new()
	_trail.amount = 26
	_trail.lifetime = 0.35
	_trail.local_coords = false
	_trail.position = Vector3(0.0, 0.0, 0.2)
	var process := ParticleProcessMaterial.new()
	process.direction = Vector3(0.0, 0.0, 1.0)
	process.spread = 18.0
	process.initial_velocity_min = 1.0
	process.initial_velocity_max = 3.0
	process.gravity = Vector3(0.0, 1.0, 0.0)
	process.scale_min = 0.6
	process.scale_max = 1.5
	process.color = TRAIL_COLOR
	_trail.process_material = process
	_trail.draw_pass_1 = FlareLight.spark_mesh()
	add_child(_trail)
	_launched += 1
	if _launched % LIGHT_EVERY == 0:
		var light := OmniLight3D.new()
		light.light_color = TRAIL_COLOR
		light.light_energy = 1.6
		light.omni_range = 4.0
		light.shadow_enabled = false
		light.position = Vector3(0.0, 0.0, 0.2)
		add_child(light)


static func _material(color: Color) -> StandardMaterial3D:
	if not _materials.has(color):
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.roughness = 0.7
		_materials[color] = material
	return _materials[color]
