class_name SerpentFall
extends Node3D
## The Serpent's fall, after its last hit (Serpent._on_defeated hands over
## its rig, body and model; the guardian itself is freed the same frame):
## 1. the eyes flare, the mouths glow, every plate rattles, the heads sag
##    (TREMBLE s);
## 2. the mosaic cascades off the body segment by segment from the end that
##    was hit (CASCADE_STEP s each): the plates fly as debris, the cracks
##    beneath blaze, and the skulls break off their necks and tumble (heavy
##    pieces that roll down the steps when they fall over them);
## 3. the light dies in the cracks, the eyes go out; the bared wooden body
##    stays lying where it fell for the night (no longer solid).
## Through 1 and into 2 the body comes down: a killing blow mid-motion (the
## body arched on its ring, the heads reared at the gate, a head shot out
## in a lunge) leaves the fall on the ground - the arches flatten, the tail
## straightens, each head sinks along its neck's line to the floor under it
## (over the flight's steps at the gate), so the skulls break off low and
## tumble down the steps.
## The shard is the keeper's (on the arena's reward marker on the summit).

signal shattered

const TREMBLE := 0.6
const CASCADE_STEP := 0.045
## The cracks fade over this long once the cascade is done.
const FADE := 2.5
## The body settles onto the ground over this long from the last hit.
const SINK := 1.2
## Where a fallen head may lie, tried in turn: [out along its neck's line,
## aside to its right] (m) - far out with the neck all but straight first,
## nearer with the neck arched last. A pose is taken when the ground there
## is the root's (no drop over an edge, no wall), the neck stays over the
## ground all the way (over a flight's side wall it arches, as it did
## reared), and its skull lies clear of the other's (the two heads reared
## at the gate's posts, 4.1 m apart and facing each other, come down one
## up the flight and one down it).
const HEAD_RESTS: Array = [[2.6, 1.4], [2.6, -1.4], [2.0, 1.0], [2.0, -1.0], [1.7, 0.8], [1.7, -0.8], [1.4, 0.0], [1.0, 0.0]]
## A fallen head's pivot lies this high over the ground; its skull's centre
## is this far ahead of the pivot; two skulls keep their centres this far apart.
const HEAD_LOW := 0.32
const SKULL_AHEAD := 0.95
const SKULLS_APART := 2.1
## The skulls' friction: they slide and tumble down the flight's ramp (the
## engine combines frictions geometrically: with the ramp's 1.0 this makes
## 0.28, under the ramp's slope of 0.375), not stick to it.
const SKULL_FRICTION := 0.08
## The mouths' lights swell to this as the tremble ends (the glow's 1.5 x
## the Serpent's 2.2 an energy), then die over MOUTH_FADE s.
const MOUTH_LIGHT := 3.3
const MOUTH_FADE := 0.6

var remains: Node3D
var pieces: Array[RigidBody3D] = []

var _rig: SerpentRig
var _body: SerpentBody
var _pose := SerpentRig.Pose.new()
var _order := PackedInt32Array()
var _next: int = 0
var _time: float = 0.0
var _done := false
var _push := Vector3.ZERO
var _guard: Node3D
var _light: OmniLight3D
## The two mouths' lights (they go with the skulls) and what they shone with
## at the last hit.
var _mouths: Array[OmniLight3D] = []
var _mouths_from: Array[float] = []
var _skulls_off := false
var _sunk := false
var _looks: Array[Vector3] = [Vector3.FORWARD, Vector3.BACK]
var _look_to: Array[Vector3] = [Vector3.FORWARD, Vector3.BACK]
var _look_now: Array[Vector3] = [Vector3.FORWARD, Vector3.BACK]
var _head_from: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
var _head_to: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
var _arches_from: Array = []
var _sweep_from: float = 0.0
var _rails: Array[PhysicsBody3D] = []


## The fall of [param serpent] (takes its model now), [param info] = its
## last hit (the cascade starts at the end it struck).
static func make(serpent: Serpent, info: DamageInfo) -> SerpentFall:
	var fall := SerpentFall.new()
	fall.name = "SerpentFall"
	fall._rig = serpent.rig
	fall._body = serpent.body
	fall._guard = serpent.target
	fall._push = info.direction if info != null else Vector3.ZERO
	for light in serpent._lights:
		fall._mouths.append(light)
		fall._mouths_from.append(light.light_energy)
	for end in 2:
		var e := end as SerpentBody.End
		fall._looks[end] = serpent.body.head_look(e)
		fall._look_now[end] = fall._looks[end]
		fall._head_from[end] = serpent.body.head_point(e)
	# where the heads come to lie: out along their lines, on the ground
	# there (the steps under the gate, 1.24 m over the terrace; the root's
	# own ground if a wall stands there) - from the body as it will lie: the
	# arches give their slack back to the trailing end as they flatten, so
	# a root moves along the ring (up to 1.5 m) before the head is down
	var body := serpent.body
	fall._arches_from = body.arches.duplicate(true)
	fall._sweep_from = body.sweep
	fall._rails = serpent._rail_bodies
	body.arches = []
	body.sweep = 0.0
	body.update()
	var centres: Array[Vector3] = []
	for end in 2:
		var e := end as SerpentBody.End
		var frame := body.root_frame(e)
		var root := SerpentBody.NECK if e == SerpentBody.End.A else body.count - SerpentBody.NECK
		var root_ground := body.ground_of(root)
		var chosen := false
		for pose: Array in HEAD_RESTS:
			var rest := frame * Vector3(float(pose[1]), 0.0, -float(pose[0]))
			var floor_y := serpent._ground_at(rest)
			if floor_y < root_ground - 0.6 or floor_y > root_ground + 1.6:
				continue
			var to := Vector3(rest.x, floor_y + HEAD_LOW, rest.z)
			var along := Vector3(to.x - frame.origin.x, 0.0, to.z - frame.origin.z).normalized()
			var look := (along + Vector3.DOWN * 0.35).normalized()
			var centre := to + along * SKULL_AHEAD
			var clear := true
			for other in centres:
				if other.distance_to(centre) < SKULLS_APART:
					clear = false
			if not clear:
				continue
			body.set_head(e, to, look)
			body.update()
			for i in range(1, SerpentBody.NECK):
				var j := root - i if e == SerpentBody.End.A else root + i
				if body.joints[j].y < serpent._ground_at(body.joints[j]) + 0.2:
					clear = false
			if not clear:
				continue
			fall._head_to[end] = to
			fall._look_to[end] = look
			centres.append(centre)
			chosen = true
			break
		if not chosen:
			# nowhere good: close in along the line, on the root's own ground
			var rest := frame * Vector3(0.0, 0.0, -1.0)
			fall._head_to[end] = Vector3(rest.x, root_ground + HEAD_LOW, rest.z)
			fall._look_to[end] = (frame.basis * Vector3(0.0, -0.35, -1.0)).normalized()
	# the body as it was: the fall animates from there
	for end in 2:
		body.set_head(end as SerpentBody.End, fall._head_from[end], fall._looks[end])
	body.arches = fall._arches_from.duplicate(true)
	body.sweep = fall._sweep_from
	body.update()
	# from the end the last hit was nearer to
	var at := info.position if info != null and info.position != Vector3.ZERO else serpent.body.head_point(SerpentBody.End.A)
	var from_a := at.distance_to(serpent.body.head_point(SerpentBody.End.A)) <= at.distance_to(serpent.body.head_point(SerpentBody.End.B))
	for k in serpent.rig.count:
		fall._order.append(k if from_a else serpent.rig.count - 1 - k)
	var model := serpent.rig.model
	# its hit zones and solid boxes go: the remains are neither hit nor walked into
	for hurtbox in model.find_children("*", "Hurtbox", true, false):
		hurtbox.get_parent().remove_child(hurtbox)
		hurtbox.queue_free()
	for solid in model.find_children("*", "AnimatableBody3D", true, false):
		solid.get_parent().remove_child(solid)
		solid.queue_free()
	model.get_parent().remove_child(model)
	fall.add_child(model)
	return fall


func _ready() -> void:
	_rig.model.global_transform = Transform3D.IDENTITY
	remains = Node3D.new()
	remains.name = "SerpentRemains"
	add_child(remains)
	_light = OmniLight3D.new()
	_light.light_color = SerpentShard.TURQUOISE_GLOW
	_light.omni_range = 9.0
	_light.light_energy = 0.0
	add_child(_light)
	_light.global_position = _body.joints[_body.count >> 1] + Vector3.UP * 1.5
	_pose.eyes = 1.0
	_pose.cracks = 1.0


func _physics_process(delta: float) -> void:
	if _done:
		return
	_time += delta
	if not _sunk:
		_settle()
		_sunk = _time >= SINK
	var p := _pose
	for end in 2:
		p.head_look[end] = _look_now[end]
	if _time < TREMBLE:
		var k := _time / TREMBLE
		p.eyes = 1.0 + k
		p.cracks = 1.0 + 1.5 * k
		p.rattle = 1.0
		p.rattle_end = SerpentBody.End.A
		p.head_glow = [1.5 * k, 1.5 * k]
		_light.light_energy = 3.0 * k
		_swell_mouths(k)
		for end in 2:
			p.jaw[end] = 0.8 * k
		_rig.apply(_body, p, delta)
		# the whole body shivers
		_rig.model.position = Vector3(randf_range(-0.012, 0.012), 0.0, randf_range(-0.012, 0.012)) * k
		return
	_rig.model.position = Vector3.ZERO
	_dim_mouths(1.0 - clampf((_time - TREMBLE) / MOUTH_FADE, 0.0, 1.0))
	var cascade := _time - TREMBLE
	var due := mini(int(cascade / CASCADE_STEP), _rig.count)
	while _next < due:
		_cascade(_order[_next])
		_next += 1
	var total := CASCADE_STEP * float(_rig.count)
	if not _skulls_off and cascade >= total * 0.5:
		_skulls_off = true
		_break_skulls()
	var after := cascade - total
	var fade := clampf(after / FADE, 0.0, 1.0) if after > 0.0 else 0.0
	p.eyes = 1.0 - fade
	p.cracks = 2.5 * (1.0 - fade)
	p.rattle = maxf(0.0, 1.0 - cascade / total)
	p.head_glow = [0.0, 0.0]
	_light.light_energy = 3.0 * (1.0 - fade)
	# the plates' rattle also shakes the segments still plated
	_rig.apply(_body, p, delta)
	if after >= FADE:
		_done = true
		_light.light_energy = 0.0
		_dim_mouths(0.0)
		shattered.emit()


## The mouths' lights swell from what they shone with at the last hit to
## MOUTH_LIGHT through the tremble ([param k] 0..1) ...
func _swell_mouths(k: float) -> void:
	for i in _mouths.size():
		if is_instance_valid(_mouths[i]):
			_mouths[i].light_energy = lerpf(_mouths_from[i], MOUTH_LIGHT, k)


## ... and die after it ([param amount]: 1 = MOUTH_LIGHT .. 0 = out).
func _dim_mouths(amount: float) -> void:
	for light in _mouths:
		if is_instance_valid(light):
			light.light_energy = MOUTH_LIGHT * amount


## The body comes down (eased over SINK): the arches flatten, the tail
## straightens, each head sinks along its line to the ground under it.
func _settle() -> void:
	var k := smoothstep(0.0, SINK, _time)
	var arches := []
	for arch: Array in _arches_from:
		arches.append([arch[0], float(arch[1]) * (1.0 - k), arch[2]])
	_body.arches = arches
	_body.sweep = _sweep_from * (1.0 - k)
	for end in 2:
		_look_now[end] = _looks[end].lerp(_look_to[end], k).normalized()
		_body.set_head(end as SerpentBody.End, _head_from[end].lerp(_head_to[end], k), _look_now[end])
	_body.update()


## Segment [param k]'s plate flies off, its crack blazing.
func _cascade(k: int) -> void:
	var push := Vector3.UP + _push * 0.4 + Vector3(randf_range(-0.6, 0.6), 0.0, randf_range(-0.6, 0.6))
	var at := _rig.segments[k].global_transform * Vector3(0.0, _body.radii[k] * 0.6, SerpentBody.SPACING * 0.5)
	_rig.drop_plate(k, push.normalized())
	Fx.impact(at, Vector3.UP, ExhibitMaterial.Kind.METAL, 1.2)
	Fx.impact(at, Vector3.UP, -1, 0.9)
	if k % 6 == 0:
		Sfx.play_at(&"shard_break", at, 0.0, 0.15)
		Fx.flash(at, SerpentShard.TURQUOISE_GLOW, 2.5, 4.0, 0.2)
	if is_instance_valid(_guard) and _guard is Player and k % 9 == 0:
		var distance := _guard.global_position.distance_to(at)
		if distance < 20.0:
			Events.shake_requested.emit(0.15 * (1.0 - distance / 20.0))


## The skulls break off their necks: heavy pieces that tumble (down the
## steps, where they lie over them).
func _break_skulls() -> void:
	for end in 2:
		var skull := _rig.skulls[end]
		var xform := skull.global_transform
		var jaw := _rig.jaws[end]
		var views: Array = [skull] if skull is MeshInstance3D else []
		if jaw is MeshInstance3D:
			views.append(jaw)
		if views.is_empty():
			continue
		var body := RigidBody3D.new()
		body.collision_layer = Layers.DEBRIS
		body.collision_mask = Layers.WORLD | Layers.DEBRIS
		body.mass = 60.0
		var surface := PhysicsMaterial.new()
		surface.friction = SKULL_FRICTION
		surface.bounce = 0.1
		body.physics_material_override = surface
		# (the flights' invisible railings: no more a wall to a skull than
		# to the body)
		for rail in _rails:
			if is_instance_valid(rail):
				body.add_collision_exception_with(rail)
		var shape := BoxShape3D.new()
		shape.size = Vector3(0.9, 0.8, 1.9)
		var collider := CollisionShape3D.new()
		collider.shape = shape
		collider.position = Vector3(0.0, 0.0, -0.75 if end == 0 else 0.75)
		body.add_child(collider)
		remains.add_child(body)
		body.global_transform = Transform3D(xform.basis.orthonormalized(), xform.origin)
		body.reset_physics_interpolation()
		for view: MeshInstance3D in views:
			var view_xform := view.global_transform
			view.get_parent().remove_child(view)
			body.add_child(view)
			view.global_transform = view_xform
			view.set_instance_shader_parameter(&"glow", 0.0)
			view.set_instance_shader_parameter(&"awake", 0.0)
		var out := _rig.head_forward(end as SerpentBody.End)
		body.linear_velocity = out * 1.5 + Vector3.UP * 1.5 + _push * 0.5
		body.angular_velocity = Vector3(randf_range(-2.0, 2.0), randf_range(-1.0, 1.0), randf_range(-2.0, 2.0))
		pieces.append(body)
		Fx.impact(xform.origin, Vector3.UP, ExhibitMaterial.Kind.WOOD, 2.5)
		Fx.impact(xform.origin, Vector3.UP, -1, 2.0)
		Sfx.play_at(&"break_wood", xform.origin, 2.0, 0.1)
	Sfx.play_at(&"rubble", _body.joints[_body.count >> 1], 0.0, 0.0)
	if is_instance_valid(_guard) and _guard is Player:
		var distance := _guard.global_position.distance_to(_body.joints[_body.count >> 1])
		if distance < 30.0:
			Events.shake_requested.emit(0.5 * (1.0 - distance / 30.0))
