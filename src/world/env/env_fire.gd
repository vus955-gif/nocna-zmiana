class_name EnvFire
extends Node3D
## A pool of burning oil on the floor (the storm lamp's; plan
## docs/superpowers/plans/2026-10-21-srodowisko-walka.md): flames over a
## disc of [member radius] for [member seconds], a flickering light, a
## scorch left behind. Every TICK an exhibit standing in it catches fire
## (Burn: wax and linen burn twice as fast - a mummy walking through it
## goes up), a banner hanging into it burns down, and the guard in it takes [member guard_tick] - by the rules of
## his own blast when he lit it (never below half his health). The flames
## are the warning: they show the whole disc from the first moment.

const TICK := 0.5
const FLAME := Color(1.0, 0.52, 0.16)
const FADE := 0.8

var radius: float = 1.5
var seconds: float = 6.0
## Fire damage a second to an exhibit in it (Burn), and how long a burn
## lasts after it walks out.
var dps: float = 10.0
var burn_after: float = 1.5
var guard_tick: float = 4.0
var source: Node = null
var by_guard: bool = true

var _left: float = 0.0
var _tick: float = 0.0
var _flames: GPUParticles3D
var _light: OmniLight3D


## A fire of [param radius_] for [param seconds_] on the floor at
## [param at], under [param parent].
static func spawn(parent: Node, at: Vector3, radius_: float, seconds_: float, by: Node, guards: bool = true) -> EnvFire:
	var fire := EnvFire.new()
	fire.name = "Fire"
	fire.radius = radius_
	fire.seconds = seconds_
	fire.source = by
	fire.by_guard = guards
	parent.add_child(fire)
	fire.global_position = at
	return fire


func _ready() -> void:
	top_level = true
	_left = seconds
	_tick = 0.0
	_flames = GPUParticles3D.new()
	_flames.amount = 64
	_flames.lifetime = 0.7
	_flames.local_coords = false
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	process.emission_ring_axis = Vector3.UP
	process.emission_ring_radius = radius * 0.8
	process.emission_ring_inner_radius = 0.0
	process.emission_ring_height = 0.05
	process.direction = Vector3.UP
	process.spread = 12.0
	process.initial_velocity_min = 0.6
	process.initial_velocity_max = 1.6
	process.gravity = Vector3(0.0, 0.6, 0.0)
	process.scale_min = 0.6
	process.scale_max = 1.4
	_flames.process_material = process
	var quad := QuadMesh.new()
	quad.size = Vector2(0.28, 0.4)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = FLAME
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	quad.material = mat
	_flames.draw_pass_1 = quad
	_flames.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_flames)
	_light = OmniLight3D.new()
	_light.light_color = FLAME
	_light.light_energy = 2.2
	_light.omni_range = radius * 3.5
	_light.position = Vector3.UP * 0.5
	add_child(_light)
	Fx.mark(global_position + Vector3.UP * 0.02, Vector3.UP, Fx.SCORCH, radius * 1.6)
	Sfx.play_at(&"flare_burn", global_position, -2.0)


## Seconds of fire left.
func time_left() -> float:
	return _left


func _physics_process(delta: float) -> void:
	_left -= delta
	if _light != null:
		_light.light_energy = (2.0 + 0.6 * sin(_left * 23.0) + 0.3 * sin(_left * 41.0)) * clampf(_left / FADE, 0.0, 1.0)
	if _left <= 0.0:
		_flames.emitting = false
		set_physics_process(false)
		get_tree().create_timer(_flames.lifetime + 0.2, false).timeout.connect(queue_free)
		return
	_tick -= delta
	if _tick > 0.0:
		return
	_tick = TICK
	_burn()


## One tick of the fire on everything in it.
func _burn() -> void:
	var by: Node = source if is_instance_valid(source) else null
	for receiver in EnvStrike.in_disc(self, global_position, radius, 1.8):
		if receiver is Enemy:
			Burn.ignite(receiver as Enemy, dps, burn_after, by)
		elif receiver.is_in_group(&"enemies") or receiver is EnvBanner:
			var info := DamageInfo.make(Blast.scaled(dps * TICK, receiver, DamageInfo.Kind.FIRE), DamageInfo.Kind.FIRE, by)
			info.position = (receiver as Node3D).global_position + Vector3.UP * 0.5
			info.direction = Vector3.UP
			info.weapon = &"env"
			info.periodic = receiver.is_in_group(&"enemies")
			receiver.take_damage(info)
	for node in get_tree().get_nodes_in_group(&"player"):
		var guard := node as Player
		if guard != null and EnvStrike.guard_in_disc(guard, global_position, radius, 1.8):
			EnvStrike.hurt_guard(guard, guard_tick, by_guard, global_position, Vector3.ZERO, 0.0, DamageInfo.Kind.FIRE, by)
