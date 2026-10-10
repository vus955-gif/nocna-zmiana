class_name Burn
extends Node3D
## A short fire on an exhibit (the hwacha's fire-arrows): [member dps] fire
## damage every TICK for [member seconds], licking flames, no light (a
## volley lights six of them at once). It rides on its host as a child and
## dies with it. A second ignite() on a burning host only tops the fire up
## (the longer time and the stronger flame win). Wax takes fire double
## (Blast.scaled). Ticks are periodic: no hit marker, no shield clank.

const TICK := 0.5
const FLAME_COLOR := Color(1.0, 0.5, 0.16)

var dps: float = 3.0
var seconds: float = 2.0
## Credited with the damage (a non-owning reference: it may be gone).
var source: Node = null

var _left: float = 0.0
var _timer: float = TICK
var _flames: GPUParticles3D


## Sets [param host] on fire (or tops its fire up). Returns the Burn, or
## null when the host cannot burn (no take_damage, not in the tree).
static func ignite(host: Node3D, dps_: float, seconds_: float, by: Node) -> Burn:
	if host == null or not host.is_inside_tree() or not host.has_method(&"take_damage") or seconds_ <= 0.0:
		return null
	for child in host.get_children():
		var burning := child as Burn
		if burning != null and not burning.is_queued_for_deletion():
			burning.dps = maxf(burning.dps, dps_)
			burning._left = maxf(burning._left, seconds_)
			burning.source = by
			burning._flames.emitting = true
			return burning
	var burn := Burn.new()
	burn.name = "Burn"
	burn.dps = dps_
	burn.seconds = seconds_
	burn.source = by
	burn.position = Vector3.UP * 0.9
	host.add_child(burn)
	return burn


## Seconds of fire left.
func time_left() -> float:
	return _left


func _ready() -> void:
	_left = seconds
	_flames = GPUParticles3D.new()
	_flames.amount = 18
	_flames.lifetime = 0.45
	_flames.local_coords = false
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process.emission_sphere_radius = 0.25
	process.direction = Vector3.UP
	process.spread = 25.0
	process.initial_velocity_min = 0.4
	process.initial_velocity_max = 1.2
	process.gravity = Vector3(0.0, 1.5, 0.0)
	process.scale_min = 0.8
	process.scale_max = 1.6
	process.color = FLAME_COLOR
	_flames.process_material = process
	_flames.draw_pass_1 = FlareLight.spark_mesh()
	add_child(_flames)


func _physics_process(delta: float) -> void:
	if _left <= 0.0:
		return
	_left -= delta
	_timer -= delta
	var host := get_parent() as Node3D
	if _timer <= 1e-4:   # (float steps: never lose the last tick)
		_timer += TICK
		if host != null and host.has_method(&"take_damage"):
			var by: Node = source if is_instance_valid(source) else null
			var info := DamageInfo.make(Blast.scaled(dps * TICK, host, DamageInfo.Kind.FIRE), DamageInfo.Kind.FIRE, by)
			info.position = global_position
			info.normal = Vector3.UP
			info.direction = Vector3.DOWN   # fire eats in from where it sits (past any shield)
			info.periodic = true
			host.take_damage(info)
	if _left <= 0.0 and is_inside_tree():
		_flames.emitting = false
		get_tree().create_timer(_flames.lifetime + 0.1, false).timeout.connect(_expire)


## The last flames are gone (unless it was lit again meanwhile).
func _expire() -> void:
	if _left <= 0.0:
		queue_free()
