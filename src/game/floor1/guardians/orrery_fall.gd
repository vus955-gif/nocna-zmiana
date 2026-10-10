class_name OrreryFall
extends Node3D
## The Great Orrery's fall, after its core's last hit (Planetarium.
## _on_defeated hands its rig over; the guardian itself is freed the same
## frame):
## 1. it seizes: the tiers judder to a stop against their jammed gears,
##    each a little past and back (backlash), sparks spray from the hubs,
##    the core flickers (SEIZE s);
## 2. the petals snap off their hinges one after another and fall as brass,
##    the hanging moons drop off their rods, the core gutters out;
## 3. a last shudder: brass debris and dust off the drum.
## The base stays (solid) for the night; on later nights the keeper's
## dress_arena() stands the still orrery here. The Star Key and the shard
## are the keeper's (on the arena's reward marker).

signal seized

const SEIZE := 1.4
## The petals break off from this moment, one every PETAL_EVERY s.
const PETALS_FROM := 0.55
const PETAL_EVERY := 0.17
## The moons drop between these moments.
const MOONS_FROM := 1.0
const MOONS_TO := 2.3
const CORE_DIES := 2.0
const DONE := 2.9
const GOLD := Color(1.0, 0.78, 0.36)

var rig: OrreryRig
var pieces: Array[RigidBody3D] = []
var remains: StaticBody3D

var _pose: OrreryRig.Pose
var _speed: Array[float] = [0.0, 0.0, 0.0]
var _settle: Array[Spring] = []
var _time: float = 0.0
var _petals: int = 0
var _moons: int = 0
var _sparks: float = 0.0
var _done := false
var _guard: Node3D
var _at := Transform3D.IDENTITY


## The fall of [param orrery] (takes its rig now); [param _info] = its last
## hit.
static func make(orrery: Planetarium, _info: DamageInfo) -> OrreryFall:
	var fall := OrreryFall.new()
	fall.name = "OrreryFall"
	fall.rig = orrery.rig
	fall._guard = orrery.target
	fall._at = orrery.global_transform
	fall._pose = orrery.moves.pose
	for t in 3:
		fall._speed[t] = orrery.drives[t].speed
		fall._settle.append(Spring.new(1.8, 0.25))
	var model := orrery.rig.model
	var keep := model.global_transform if model.is_inside_tree() else orrery.global_transform
	# its hit zones die with it
	for box in model.find_children("*", "Hurtbox", true, false):
		box.get_parent().remove_child(box)
		box.queue_free()
	model.get_parent().remove_child(model)
	fall.add_child(model)
	model.transform = orrery.global_transform.affine_inverse() * keep
	return fall


func _ready() -> void:
	global_transform = _at
	reset_physics_interpolation()
	remains = StaticBody3D.new()
	remains.name = "Remains"
	remains.collision_layer = Layers.WORLD
	for shape in Planetarium._base_shapes():
		remains.add_child(shape)
	add_child(remains)
	for light in rig.lamp_lights:
		light.visible = false
	Sfx.play_at(&"relay", global_position + Vector3.UP * 2.0, 4.0, 0.0)
	Sfx.play_at(&"gate_jam", global_position + Vector3.UP * 1.5, 2.0, 0.0)
	_shake(0.5)


func _physics_process(delta: float) -> void:
	if _done:
		return
	_time += delta
	var p := _pose
	var seizing := clampf(1.0 - _time / SEIZE, 0.0, 1.0)
	for t in 3:
		# the jammed gears bite: the speed dies in jerks
		_speed[t] *= exp(-3.5 * delta) if seizing > 0.0 else 0.0
		var judder := 0.025 * sin(_time * (48.0 + 7.0 * t)) * seizing
		p.tier_yaw[t] = wrapf(p.tier_yaw[t] + _speed[t] * delta, -PI, PI) + judder * delta * 30.0
		p.tier_rock[t] = Vector2(_settle[t].step(0.0, delta), p.tier_rock[t].y * 0.97)
		if _time < 0.05:
			_settle[t].kick(0.4 * (1.0 if t % 2 == 0 else -1.0))
	p.lamps = [0.0, 0.0, 0.0]
	p.tier_glow = [0.0, 0.0, 0.0]
	var dying := clampf(1.0 - _time / CORE_DIES, 0.0, 1.0)
	p.sun = (1.6 + 0.9 * sin(_time * 37.0) * sin(_time * 11.0)) * dying * dying
	p.awake = dying
	for k in 6:
		p.planet_glow[k] = 0.0
	if _time < SEIZE:
		_sparks -= delta
		if _sparks <= 0.0:
			_sparks = 0.08
			for t in 3:
				var angle := randf() * TAU
				var at := rig.tiers[t].global_position + Vector3(cos(angle), 0.0, sin(angle)) * 0.62
				Fx.impact(at, Vector3(cos(angle), 0.5, sin(angle)), ExhibitMaterial.Kind.METAL, 1.2)
	while _petals < rig.petals.size() and _time >= PETALS_FROM + PETAL_EVERY * _petals:
		_break_petal(_petals)
		_petals += 1
	var moon_count := rig.moon_views.size()
	while _moons < moon_count and _time >= MOONS_FROM + (MOONS_TO - MOONS_FROM) * float(_moons) / float(moon_count):
		_drop_moon(_moons)
		_moons += 1
	rig.apply(p, delta)
	if _time >= DONE:
		_finish()


func _break_petal(k: int) -> void:
	var petal := rig.petals[k] as MeshInstance3D
	if petal == null or not petal.visible:
		return
	if petal.mesh != null:
		var out := Vector3(petal.global_position.x - global_position.x, 0.0, petal.global_position.z - global_position.z).normalized()
		var body := _piece(petal, out * randf_range(2.0, 3.5) + Vector3.UP * randf_range(1.0, 2.5))
		if body != null:
			pieces.append(body)
	petal.visible = false
	Sfx.play_at(&"hit_metal", petal.global_position, 2.0, 0.1, 0.55)
	Fx.flash(petal.global_position, GOLD, 2.0, 4.0, 0.12)


func _drop_moon(m: int) -> void:
	var view := rig.moon_views[m]
	if view == null or not view.visible:
		return
	if view.mesh != null:
		var body := _piece(view, Vector3(randf_range(-0.8, 0.8), -0.5, randf_range(-0.8, 0.8)))
		if body != null:
			pieces.append(body)
	view.visible = false
	Sfx.play_at(&"hit_metal", view.global_position, -6.0, 0.15, 0.9)


## [param view] as one physical piece of brass flung with [param push].
func _piece(view: MeshInstance3D, push: Vector3) -> RigidBody3D:
	var materials: Array[Material] = []
	for i in view.mesh.get_surface_count():
		var source := view.get_active_material(i)
		materials.append(ArtLibrary.debris_material(source) if source != null else null)
	return Fx.piece(MeshShards.whole(view.mesh), materials, view.global_transform, push, 4.0)


func _finish() -> void:
	_done = true
	var at := global_position
	for i in 10:
		var angle := TAU * i / 10.0
		var spot := at + Vector3(cos(angle), 0.0, sin(angle)) * 2.6 + Vector3.UP * 0.3
		Fx.impact(spot, Vector3.UP, -1, 3.0)
		Fx.chunk(spot + Vector3.UP * 0.4, Color(0.62, 0.48, 0.22), randf_range(0.06, 0.14), Vector3(cos(angle), 1.2, sin(angle)) * randf_range(2.0, 4.0))
	Sfx.play_at(&"lock_wall_collapse", at + Vector3.UP, 2.0, 0.0)
	Sfx.play_at(&"rubble", at, 2.0, 0.0)
	_shake(0.6)
	rig.sun_light.visible = false
	seized.emit()


func _shake(trauma: float) -> void:
	if is_instance_valid(_guard) and _guard is Player:
		var distance := _guard.global_position.distance_to(global_position)
		if distance < 35.0:
			Events.shake_requested.emit(trauma * (1.0 - distance / 35.0))
