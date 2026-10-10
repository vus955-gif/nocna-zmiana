class_name Harpoon
extends Node3D
## The harpoon gun's shot: a forged harpoon on a tarred line (design 7.1).
## It flies at 40 m/s with a slight drop; every physics frame a ray from
## the tip along the move finds what it meets first (walls, exhibits' and
## locks' hit zones; never the guard). What a hit does (HarpoonRules):
## - PIN: a light exhibit with a wall within reach behind it is carried
##   along the shaft to the wall, hangs there stunned for PIN_HOLD seconds
##   and breaks apart (a sure kill), the harpoon stays in the wall;
## - PULL: a medium exhibit takes the hit, is stunned and yanked
##   pull_distance metres toward the guard;
## - DAMAGE: a heavy one, a guardian, a lock (a hook ring pulls itself)...
## Stuck in an exhibit or a moving object it rides along; when that one is
## gone it drops. Stuck in a wall it stays STUCK_TIME seconds. Past
## max_range the line runs out: it drops and is gone. The line (HarpoonLine)
## shows from the gun while it flies and LINE_AFTER_HIT seconds after.
## The node's origin is the harpoon's tip; -Z points along its flight.

enum Phase { FLYING, CARRYING, PINNED, STUCK, FALLING }

## The model in flight and stuck (ArtLibrary id; markers "Tip", "Tail").
const MODEL := &"harpoon_bolt"
const SHAFT := 0.85
const STUCK_TIME := 20.0
const FADE := 1.0
const LINE_AFTER_HIT := 0.6
## A pinned exhibit hangs on the wall this long before it breaks.
const PIN_HOLD := 0.35
## How deep the tip sinks into a wall, and how far in front of the wall a
## pinned exhibit's centre stays.
const BURY := 0.14
const PINNED_CLEARANCE := 0.38
const FALL_GRAVITY := 14.0
## The line sags this much per metre of length while it flies.
const SAG_PER_METRE := 0.012
## The plain harpoon pins exhibits up to this max health; above it (the
## barbs upgrade) the model shows its barbs.
const BASE_PIN := 60.0

var velocity := Vector3.ZERO
## The shot's numbers (damage, pin and pull, range).
var shot: WeaponData = null
## Who fired it (credited with the hits).
var shooter: Node3D = null
## The gun's holder: the line runs from its harpoon gun (null: no line).
var holder: WeaponHolder = null
var phase: Phase = Phase.FLYING
## Where it was fired from.
var fired_from := Vector3.INF

var _start := Transform3D.IDENTITY
var _flown: float = 0.0
var _age_in_phase: float = 0.0
var _carried: Enemy = null
var _carry_offset := Vector3.ZERO
var _wall_point := Vector3.ZERO
var _wall_normal := Vector3.ZERO
var _host: Node3D = null
var _host_local := Transform3D.IDENTITY
var _line: HarpoonLine
var _line_left: float = 0.0
var _model: Node3D
var _floor_y: float = -INF
var _fall_speed: float = 0.0
var _lifetime: float = STUCK_TIME


## A harpoon whose tip starts at [param from] flying with
## [param velocity_]. Add it to the tree yourself (any parent).
static func launch(from: Vector3, velocity_: Vector3, data: WeaponData, by: Node3D, gun: WeaponHolder = null) -> Harpoon:
	var harpoon := Harpoon.new()
	harpoon.shot = data
	harpoon.shooter = by
	harpoon.holder = gun
	harpoon.velocity = velocity_
	harpoon.fired_from = from
	harpoon._start = Transform3D(Projectile._facing(velocity_), from)
	harpoon.transform = harpoon._start
	harpoon.name = "Harpoon"
	return harpoon


func _ready() -> void:
	global_transform = _start
	reset_physics_interpolation()
	_build_model()
	_line = HarpoonLine.new()
	_line.name = "Line"
	add_child(_line)
	_line.visible = false


## The exhibit being carried to the wall (null when none).
func carried() -> Enemy:
	return _carried if is_instance_valid(_carried) else null


## What it is stuck in (an exhibit, a lock's object; null: a wall or none).
func host() -> Node3D:
	return _host if is_instance_valid(_host) else null


## True while the line shows.
func line_shown() -> bool:
	return _line != null and _line.visible


func _physics_process(delta: float) -> void:
	_age_in_phase += delta
	match phase:
		Phase.FLYING:
			_fly(delta)
		Phase.CARRYING:
			_carry(delta)
		Phase.PINNED:
			_hold_pinned()
		Phase.STUCK:
			_ride()
			if _age_in_phase >= _lifetime:
				queue_free()
				return
			_fade()
		Phase.FALLING:
			_fall(delta)
	_update_line(delta)


func _fly(delta: float) -> void:
	var data := _data()
	velocity.y -= data.projectile_gravity * delta
	var motion := velocity * delta
	var space := get_world_3d().direct_space_state
	var hit := Hitscan.ray(space, global_position, global_position + motion)
	if hit.is_empty():
		global_position += motion
		global_basis = Projectile._facing(velocity)
		_flown += motion.length()
		if _flown >= data.max_range:
			_drop()   # the line runs out
		return
	var point: Vector3 = hit["position"]
	var normal: Vector3 = hit["normal"]
	if normal.is_zero_approx():
		normal = -velocity.normalized()
	global_position = point
	_impact(hit["hurtbox"] as Hurtbox, point, normal)


func _impact(hurtbox: Hurtbox, point: Vector3, normal: Vector3) -> void:
	var data := _data()
	var direction := velocity.normalized()
	_line_left = LINE_AFTER_HIT
	if hurtbox == null:
		_stick_in_wall(point, normal)
		return
	var receiver := hurtbox.receiver
	var exhibit := receiver as Enemy
	if exhibit != null and not exhibit.is_frozen() and exhibit.brain.state != EnemyBrain.State.DESTROYED:
		var wall := _wall_behind(point, direction, data.pin_reach)
		var distance := point.distance_to(wall["position"]) if not wall.is_empty() else INF
		match HarpoonRules.verdict(exhibit.health.max_health, exhibit.knockback_resist, distance, data):
			HarpoonRules.Verdict.PIN:
				_start_carry(exhibit, point, wall)
				return
			HarpoonRules.Verdict.PULL:
				_hit(receiver, hurtbox, point, normal, direction, data.pull_stun, false)
				if exhibit.brain.state != EnemyBrain.State.DESTROYED:
					var toward := _toward_guard(exhibit.global_position)
					exhibit.shove(toward * HarpoonRules.pull_speed(data.pull_distance))
					Sfx.play_at(&"hook_pull", point, -2.0)
				_stick_into(exhibit, point)
				return
		_hit(receiver, hurtbox, point, normal, direction, 0.0)
		_stick_into(exhibit, point)
		return
	_hit(receiver, hurtbox, point, normal, direction, 0.0)
	# it rides on whatever carries the hit zone (a hook ring's object moves)
	var body := hurtbox.get_parent() as Node3D if is_instance_valid(hurtbox) else null
	if body != null and body.is_inside_tree():
		_stick_into(body, point)
	else:
		_drop()


## One harpoon hit on [param receiver] (weapon = harpoon); [param push]
## false: no knockback away from the guard (the pull follows).
func _hit(receiver: Node, hurtbox: Hurtbox, point: Vector3, normal: Vector3, direction: Vector3, stun: float,
		push: bool = true) -> void:
	if receiver == null or not receiver.has_method(&"take_damage"):
		return
	var data := _data()
	var by: Node = shooter if is_instance_valid(shooter) else null
	var info := DamageInfo.make(data.damage * (data.weak_point_multiplier if hurtbox.weak_point else 1.0), data.damage_kind, by)
	info.position = point
	info.normal = normal
	info.direction = direction
	info.knockback = data.knockback if push else 0.0
	info.weak_point = hurtbox.weak_point
	info.stun_time = stun
	info.weapon = data.id
	info.origin = fired_from
	receiver.take_damage(info)
	Sfx.play_at(&"harpoon_thunk", point, -2.0)


## The nearest wall behind [param point] along [param direction] within
## [param reach] ({} when none): ray hit info.
func _wall_behind(point: Vector3, direction: Vector3, reach: float) -> Dictionary:
	if reach <= 0.0:
		return {}
	var query := PhysicsRayQueryParameters3D.create(point, point + direction * reach, Layers.WORLD)
	return get_world_3d().direct_space_state.intersect_ray(query)


func _start_carry(exhibit: Enemy, point: Vector3, wall: Dictionary) -> void:
	phase = Phase.CARRYING
	_age_in_phase = 0.0
	_carried = exhibit
	_carry_offset = exhibit.global_position - point
	_wall_point = wall["position"]
	_wall_normal = wall["normal"]
	exhibit.brain.stun(2.0)
	Sfx.play_at(&"harpoon_thunk", point, 0.0)
	Fx.impact(point, -velocity.normalized(), exhibit.material_kind, 1.4)


## Pinning: the exhibit rides the shaft to the wall at the harpoon's speed.
func _carry(delta: float) -> void:
	var exhibit := carried()
	var direction := velocity.normalized()
	var stop := _wall_point + direction * BURY
	var step := velocity.length() * delta
	var left := global_position.distance_to(stop)
	if step >= left:
		global_position = stop
		_place_carried(direction)
		_line_left = LINE_AFTER_HIT
		if exhibit == null:
			_settle_in_wall()
			return
		phase = Phase.PINNED
		_age_in_phase = 0.0
		Sfx.play_at(&"harpoon_thunk", _wall_point, 2.0)
		Events.shake_requested.emit(0.15)
		Fx.impact(_wall_point, _wall_normal, -1, 1.2)
		return
	global_position += direction * step
	_place_carried(direction)


## Keeps the carried exhibit on the shaft, never pushed into the wall.
func _place_carried(direction: Vector3) -> void:
	var exhibit := carried()
	if exhibit == null:
		return
	var at := global_position + _carry_offset
	var depth := (at - _wall_point).dot(direction)
	if depth > -PINNED_CLEARANCE:
		at -= direction * (depth + PINNED_CLEARANCE)
	exhibit.global_position = at
	exhibit.velocity = Vector3.ZERO


## The pinned exhibit hangs on the wall, then breaks there.
func _hold_pinned() -> void:
	var exhibit := carried()
	if exhibit == null or exhibit.brain.state == EnemyBrain.State.DESTROYED:
		_settle_in_wall()
		return
	_place_carried(velocity.normalized())
	if _age_in_phase < PIN_HOLD:
		return
	var by: Node = shooter if is_instance_valid(shooter) else null
	var info := DamageInfo.make(exhibit.health.current + exhibit.health.max_health, _data().damage_kind, by)
	info.position = exhibit.global_position + Vector3.UP * exhibit.eye_height * 0.6
	info.normal = _wall_normal
	info.direction = velocity.normalized()
	info.weapon = _data().id
	info.origin = fired_from
	_carried = null
	exhibit.take_damage(info)
	_settle_in_wall()


func _stick_in_wall(point: Vector3, normal: Vector3) -> void:
	global_position = point + velocity.normalized() * BURY
	_wall_point = point
	_wall_normal = normal
	Fx.impact(point, normal, -1, 1.0)
	Sfx.play_at(&"harpoon_thunk", point, 0.0)
	_settle_in_wall()


func _settle_in_wall() -> void:
	phase = Phase.STUCK
	_age_in_phase = 0.0
	_host = null
	_lifetime = STUCK_TIME


## Stuck in an exhibit or a moving object: it rides along until that one
## is gone, then drops.
func _stick_into(body: Node3D, point: Vector3) -> void:
	global_position = point + velocity.normalized() * BURY
	_host = body
	_host_local = body.global_transform.affine_inverse() * global_transform
	phase = Phase.STUCK
	_age_in_phase = 0.0
	_lifetime = STUCK_TIME


func _ride() -> void:
	if _host == null:
		return
	if not is_instance_valid(_host) or not _host.is_inside_tree() or _host_destroyed():
		_drop()
		return
	global_transform = _host.global_transform * _host_local


func _host_destroyed() -> bool:
	var exhibit := _host as Enemy
	return exhibit != null and exhibit.brain.state == EnemyBrain.State.DESTROYED


## The line ran out or what it was stuck in is gone: it falls to the
## floor below and is cleared away a little later.
func _drop() -> void:
	phase = Phase.FALLING
	_age_in_phase = 0.0
	_host = null
	_fall_speed = 0.0
	var from := global_position + Vector3.UP * 0.1
	var query := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 30.0, Layers.WORLD)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	_floor_y = (hit["position"] as Vector3).y + 0.04 if not hit.is_empty() else global_position.y - 30.0


func _fall(delta: float) -> void:
	_fall_speed += FALL_GRAVITY * delta
	var y := global_position.y - _fall_speed * delta
	if y <= _floor_y:
		global_position.y = _floor_y
		global_basis = Basis(Vector3.UP, global_basis.get_euler().y) * Basis(Vector3.RIGHT, -PI * 0.47)
		phase = Phase.STUCK
		_age_in_phase = 0.0
		_lifetime = 4.0
		return
	global_position.y = y


## The last second it sinks a little and shrinks away.
func _fade() -> void:
	if _model == null:
		return
	var left := _lifetime - _age_in_phase
	_model.scale = Vector3.ONE * clampf(left / FADE, 0.0, 1.0)


func _update_line(delta: float) -> void:
	var flying := phase == Phase.FLYING or phase == Phase.CARRYING
	_line_left = maxf(_line_left - delta, 0.0)
	if (not flying and _line_left <= 0.0) or holder == null or not is_instance_valid(holder) or not holder.is_inside_tree():
		_line.visible = false
		return
	var from := holder.line_anchor()
	var tail := global_position + global_basis.z * SHAFT   # the back of the shaft (+Z behind the tip)
	var length := from.distance_to(tail)
	var slack := 1.0 if flying else 2.5
	_line.stretch(from, tail, length * SAG_PER_METRE * slack)


func _toward_guard(from: Vector3) -> Vector3:
	var to := fired_from
	if is_instance_valid(shooter):
		to = shooter.global_position
	var flat := Vector3(to.x - from.x, 0.0, to.z - from.z)
	return flat.normalized() if flat.length() > 0.01 else Vector3.ZERO


func _data() -> WeaponData:
	return shot if shot != null else WeaponData.new()


## The harpoon_bolt model (tip at the origin, flying along -Z), the barbs
## only with the upgrade; else a greybox shaft and head.
func _build_model() -> void:
	var data := _data()
	_model = ArtLibrary.try_instance(MODEL)
	if _model != null:
		var parts := ArtLibrary.parts(_model)
		var tip := parts.get("Tip") as Node3D
		if tip != null:
			_model.position = -tip.position
		var barbs := parts.get("barbs") as Node3D
		if barbs != null:
			barbs.visible = data.pin_max_health > BASE_PIN
	else:
		_model = Node3D.new()
		var shaft := MeshInstance3D.new()
		var tube := CylinderMesh.new()
		tube.top_radius = 0.012
		tube.bottom_radius = 0.012
		tube.height = SHAFT
		tube.radial_segments = 6
		tube.rings = 1
		shaft.mesh = tube
		shaft.rotation_degrees = Vector3(90.0, 0.0, 0.0)
		shaft.position = Vector3(0.0, 0.0, SHAFT * 0.5)
		shaft.material_override = _greybox_material(Color(0.32, 0.3, 0.28))
		_model.add_child(shaft)
		var head := MeshInstance3D.new()
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = 0.035
		cone.height = 0.14
		cone.radial_segments = 4
		cone.rings = 1
		head.mesh = cone
		head.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
		head.position = Vector3(0.0, 0.0, 0.07)
		head.material_override = _greybox_material(Color(0.55, 0.55, 0.57))
		_model.add_child(head)
	_model.name = "Model"
	for view in _model.find_children("*", "GeometryInstance3D", true, false):
		(view as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_model)


static var _materials: Dictionary = {}


static func _greybox_material(color: Color) -> StandardMaterial3D:
	if not _materials.has(color):
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.metallic = 0.5
		material.roughness = 0.5
		_materials[color] = material
	return _materials[color]
