class_name GatlingDriver
extends Node3D
## What every first-person gatling does whatever it looks like (the
## greybox GatlingView and the Blender model's ViewmodelRig both own one,
## placed at the muzzle): the sounds (the crank as the barrels start, a
## whir loop whose pitch follows their speed, the rattle loop while it
## fires, a wind-down when they stop), the heat of a long burst (glow()),
## the smoke from hot barrels winding down, and the jolt of each round
## (jolt, eased back to zero). The view turns its own barrels and crank by
## [constant BARREL_SPEED] and [constant CRANK_SPEED] times
## WeaponState.barrel_speed().

## Barrel turn at full speed (rad/s): 14 rounds a second from six barrels.
const BARREL_SPEED := TAU * 14.0 / 6.0
## The crank turns the barrels through gears: slower, but you see it.
const CRANK_SPEED := TAU * 1.6
## Heat that shows as glow (0..1, from WeaponState.heat) cools this fast
## once the burst stops (per second).
const COOL_RATE := 0.25

## Recoil offset of the model (m, view space), eased back to zero.
var jolt := Vector3.ZERO
## Rounds fired since the view came into the hand (the belt counts them).
var rounds: int = 0

var _heat: float = 0.0
var _spin_player: AudioStreamPlayer
var _rattle_player: AudioStreamPlayer
var _smoke: GPUParticles3D
var _was_turning := false
var _was_coasting := false
var _rng := RandomNumberGenerator.new()
var _quitting := false


func _ready() -> void:
	name = "GatlingDriver"
	_rng.randomize()
	_spin_player = _loop_player(&"gatling_spin")
	_rattle_player = _loop_player(&"gatling_rattle")
	if Sfx.has_signal(&"quitting"):
		Sfx.connect(&"quitting", _on_quitting)
	_smoke = _make_smoke()
	_smoke.layers = ArtLibrary.VIEWMODEL_LAYER   # first person only, like the gun
	add_child(_smoke)


## The game quits: no loop may still be playing when the engine goes.
func _on_quitting() -> void:
	_quitting = true
	hidden()


## Every frame the gatling is in hand.
func update(state: WeaponState, delta: float) -> void:
	var speed := state.barrel_speed()
	_update_sound(state, speed)
	_heat = maxf(state.heat, _heat - COOL_RATE * delta) if not state.firing() else state.heat
	var smoking := _heat > 0.3 and not state.firing()
	if smoking != _smoke.emitting:
		_smoke.emitting = smoking
	if smoking:
		_smoke.amount_ratio = clampf(_heat, 0.3, 1.0)
	jolt = jolt.lerp(Vector3.ZERO, 1.0 - exp(-30.0 * delta))


## Every round fired.
func fired() -> void:
	rounds += 1
	jolt = Vector3(_rng.randf_range(-0.004, 0.004), _rng.randf_range(-0.003, 0.005), _rng.randf_range(0.006, 0.012))


## The gatling was put away: silence, no smoke.
func hidden() -> void:
	_spin_player.stop()
	_rattle_player.stop()
	_was_turning = false
	_was_coasting = false
	_smoke.emitting = false


## Barrel glow 0..1: only a long burst makes them glow.
func glow() -> float:
	return smoothstep(0.55, 1.0, _heat)


func _update_sound(state: WeaponState, speed: float) -> void:
	if _quitting:
		return
	var turning := speed > 0.01
	if turning and not _was_turning and state.trigger_held():
		Sfx.play(&"gatling_crank", -2.0, 0.03)
	if turning:
		if not _spin_player.playing:
			_spin_player.play()
		_spin_player.pitch_scale = 0.45 + 0.6 * speed
		_spin_player.volume_db = linear_to_db(clampf(0.25 + speed, 0.0, 1.0))
	elif _spin_player.playing:
		_spin_player.stop()
	var coasting := state.coasting()
	if coasting and not _was_coasting:
		Sfx.play(&"gatling_stop", -3.0, 0.03)
	var rattling := state.firing() and state.spun_up()
	if rattling and not _rattle_player.playing:
		_rattle_player.play()
	elif not rattling and _rattle_player.playing:
		_rattle_player.stop()
	_was_turning = turning
	_was_coasting = coasting


func _loop_player(sound: StringName) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.bus = Sfx.BUS
	var path := Sfx.DIR + String(sound) + ".wav"
	player.stream = load(path) if ResourceLoader.exists(path) else null
	add_child(player)
	return player


## A soft round puff (white, alpha falling off to the edge).
static func puff_texture() -> Texture2D:
	var fade := Gradient.new()
	fade.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
	fade.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	fade.add_point(0.5, Color(1.0, 1.0, 1.0, 0.55))
	var texture := GradientTexture2D.new()
	texture.gradient = fade
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(0.5, 0.0)
	texture.width = 32
	texture.height = 32
	return texture


static func _make_smoke() -> GPUParticles3D:
	var smoke := GPUParticles3D.new()
	smoke.name = "Smoke"
	smoke.amount = 24
	smoke.lifetime = 1.1
	smoke.emitting = false
	smoke.local_coords = true
	var process := ParticleProcessMaterial.new()
	process.direction = Vector3.UP
	process.spread = 25.0
	process.initial_velocity_min = 0.05
	process.initial_velocity_max = 0.15
	process.gravity = Vector3(0.0, 0.3, 0.0)
	process.color = Color(0.72, 0.72, 0.74, 0.45)
	process.damping_min = 0.4
	process.damping_max = 0.8
	process.scale_min = 0.6
	process.scale_max = 1.2
	var grow := Curve.new()
	grow.add_point(Vector2(0.0, 0.4))
	grow.add_point(Vector2(1.0, 1.6))
	var grow_texture := CurveTexture.new()
	grow_texture.curve = grow
	process.scale_curve = grow_texture
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 1))
	fade.set_color(1, Color(1, 1, 1, 0))
	var fade_texture := GradientTexture1D.new()
	fade_texture.gradient = fade
	process.color_ramp = fade_texture
	smoke.process_material = process
	var quad := QuadMesh.new()
	quad.size = Vector2(0.07, 0.07)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.vertex_color_use_as_albedo = true
	material.albedo_texture = puff_texture()
	material.use_fov_override = true
	material.fov_override = Viewmodels.FOV
	material.use_z_clip_scale = true
	material.z_clip_scale = 0.25
	quad.material = material
	smoke.draw_pass_1 = quad
	return smoke
