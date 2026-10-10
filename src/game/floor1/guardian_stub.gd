class_name GuardianStub
extends Guardian
## The greybox guardian of stage P1 (design 13: "strażnicy jako tymczasowe
## manekiny z paskiem zdrowia"): a 4.5 m plaster mannequin in its wing's
## colour standing on the guardian's marker, until the real guardian of the
## wing replaces it. It fights with two readable attacks:
## - SLAM (the guard close by): a red ring grows on the floor where he
##   stands for the telegraph, then both fists come down there (SLAM_DAMAGE
##   within SLAM_RADIUS); step out of the ring,
## - VOLLEY (the guard farther off): its hands glow for the telegraph, then
##   it throws VOLLEY_COUNT slow plaster shards at him (shootable).
## From phase 2 it strides after the guard (never out of its arena) - or,
## with a path of its arena (points[&"path"]: the Serpent's loop), glides
## round that loop over floors and terraces alike - and its telegraphs and
## pauses shorten with each phase (never under Guardian.MIN_TELEGRAPH). The
## head is its weak point.

## Announced (the telegraph starts) and landed: for tests and sounds.
signal telegraphed(attack: StringName)
signal struck(attack: StringName)

const HEIGHT := 4.5
const RADIUS := 0.9
const SLAM_RANGE := 6.0
const SLAM_RADIUS := 3.0
const SLAM_DAMAGE := 28.0
const SLAM_KNOCKBACK := 9.0
const VOLLEY_COUNT := 3
const VOLLEY_SPREAD := 0.18
const VOLLEY_SPEED := 9.0
const VOLLEY_DAMAGE := 12.0
## Per phase (1, 2, 3): telegraph of each attack, pause between attacks,
## stride speed.
const SLAM_TELEGRAPH: Array[float] = [0.9, 0.8, 0.65]
const VOLLEY_TELEGRAPH: Array[float] = [1.0, 0.85, 0.7]
const PAUSE: Array[float] = [2.2, 1.7, 1.3]
const SPEED: Array[float] = [0.0, 1.6, 2.2]
const TURN_SPEED := 2.2
## It keeps this far from the guard while striding.
const KEEP := 3.5
const PLASTER := Color(0.86, 0.84, 0.78)
const RING_COLOR := Color(1.0, 0.16, 0.08)

## &"" between attacks, &"slam" or &"volley" while one is announced.
var attack: StringName = &""
## Seconds left of the telegraph, or of the pause before the next attack.
var attack_left: float = 0.0
var pause_left: float = 1.0
## Where the slam comes down (fixed when it is announced).
var slam_at := Vector3.ZERO

## The leg of the path it glides toward (-1: not gliding yet).
var path_leg: int = -1

var _look: Node3D
var _ring: MeshInstance3D
var _hands: Array[MeshInstance3D] = []
var _tint := PLASTER


func _build_body() -> void:
	var shape := CapsuleShape3D.new()
	shape.radius = RADIUS
	shape.height = HEIGHT
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position = Vector3(0.0, HEIGHT * 0.5, 0.0)
	add_child(collider)
	if plan != null:
		_tint = PLASTER.lerp(Floor1Plan.zone_color(plan.zone), 0.35)
	_look = Node3D.new()
	_look.name = "Look"
	add_child(_look)
	_part(Vector3(1.6, 1.7, 0.9), Vector3(0.0, 2.75, 0.0), _tint)   # torso
	_part(Vector3(1.2, 0.5, 0.8), Vector3(0.0, 1.75, 0.0), _tint.darkened(0.15))   # hips
	for x: float in [-0.35, 0.35]:
		_part(Vector3(0.45, 1.5, 0.5), Vector3(x, 0.75, 0.0), _tint.darkened(0.1))   # legs
	for x: float in [-1.05, 1.05]:
		_part(Vector3(0.4, 1.6, 0.45), Vector3(x, 2.65, 0.0), _tint)   # arms
		_hands.append(_part(Vector3(0.5, 0.5, 0.5), Vector3(x, 1.7, -0.1), _tint.darkened(0.2)))
	_part(Vector3(0.7, 0.8, 0.7), Vector3(0.0, 4.0, 0.0), _tint.lightened(0.1))   # head
	_part(Vector3(0.5, 0.08, 0.05), Vector3(0.0, 4.05, -0.36), Color(0.15, 0.1, 0.08))   # the eyes' slit
	var body := BoxShape3D.new()
	body.size = Vector3(1.8, 3.6, 1.1)
	add_child(Hurtbox.make(self, body, Vector3(0.0, 1.8, 0.0)))
	var head := SphereShape3D.new()
	head.radius = 0.5
	add_child(Hurtbox.make(self, head, Vector3(0.0, 4.0, 0.0), true))
	_ring = MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = SLAM_RADIUS
	disc.bottom_radius = SLAM_RADIUS
	disc.height = 0.03
	_ring.mesh = disc
	_ring.top_level = true
	_ring.visible = false
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color(RING_COLOR, 0.45)
	glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow.emission_enabled = true
	glow.emission = RING_COLOR
	glow.emission_energy_multiplier = 1.5
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ring.material_override = glow
	add_child(_ring)


func _fight_process(delta: float) -> void:
	var to := target.global_position - global_position
	var flat := Vector3(to.x, 0.0, to.z)
	var distance := flat.length()
	if flat.length() > 0.05:
		var wanted := atan2(-flat.x, -flat.z)
		rotation.y = rotate_toward(rotation.y, wanted, TURN_SPEED * delta)
	velocity.x = 0.0
	velocity.z = 0.0
	if attack != &"":
		attack_left -= delta
		if attack == &"slam":
			var grown := clampf(1.0 - attack_left / _telegraph(&"slam"), 0.15, 1.0)
			_ring.scale = Vector3(grown, 1.0, grown)
		else:
			_glow_hands(1.0 - attack_left / _telegraph(&"volley"))
		if attack_left <= 0.0:
			_land()
		return
	if points.has(&"path"):
		_glide(delta)
	else:
		_stride(flat, distance)
	pause_left -= delta
	if pause_left <= 0.0:
		_announce(&"slam" if distance <= SLAM_RANGE else &"volley")


## Telegraph of [param kind] in the current phase (never under the
## minimum).
func _telegraph(kind: StringName) -> float:
	var table := SLAM_TELEGRAPH if kind == &"slam" else VOLLEY_TELEGRAPH
	return maxf(table[clampi(phase - 1, 0, table.size() - 1)], Guardian.MIN_TELEGRAPH)


func _announce(kind: StringName) -> void:
	attack = kind
	attack_left = _telegraph(kind)
	if kind == &"slam":
		slam_at = target.global_position
		slam_at.y = global_position.y
		_ring.global_position = slam_at + Vector3.UP * 0.03
		_ring.scale = Vector3(0.15, 1.0, 0.15)
		_ring.visible = true
		Sfx.play_at(&"colossus_grind", global_position + Vector3.UP * 3.0, -4.0)
	else:
		Sfx.play_at(&"colossus_charge", global_position + Vector3.UP * 2.0, -4.0)
	telegraphed.emit(kind)


func _land() -> void:
	var kind := attack
	attack = &""
	pause_left = PAUSE[clampi(phase - 1, 0, PAUSE.size() - 1)]
	if kind == &"slam":
		_ring.visible = false
		Sfx.play_at(&"colossus_slam", slam_at + Vector3.UP, 0.0)
		Events.shake_requested.emit(0.3)
		Fx.impact(slam_at + Vector3.UP * 0.1, Vector3.UP, ExhibitMaterial.Kind.MARBLE, 2.5)
		var off := target.global_position - slam_at
		if Vector2(off.x, off.z).length() <= SLAM_RADIUS and absf(off.y) < 1.5 and target.has_method(&"take_damage"):
			var info := DamageInfo.make(SLAM_DAMAGE, DamageInfo.Kind.BLUNT, self)
			info.direction = Vector3(off.x, 0.0, off.z).normalized() if Vector2(off.x, off.z).length() > 0.1 else -global_basis.z
			info.knockback = SLAM_KNOCKBACK
			info.position = target.global_position
			target.call(&"take_damage", info)
	else:
		_glow_hands(0.0)
		_throw()
	struck.emit(kind)


func _throw() -> void:
	var from := global_position + Vector3.UP * 3.2 - global_basis.z * (RADIUS + 0.4)
	var aim := target.global_position + Vector3.UP * 1.2 - from
	for i in VOLLEY_COUNT:
		var turn := (i - (VOLLEY_COUNT - 1) * 0.5) * VOLLEY_SPREAD
		var velocity_ := aim.normalized().rotated(Vector3.UP, turn) * VOLLEY_SPEED
		var info := DamageInfo.make(VOLLEY_DAMAGE, DamageInfo.Kind.BLUNT, self)
		var shot := Projectile.create(from, velocity_, info)
		shot.exclude = [get_rid()]
		shot.core_color = _tint
		get_parent().add_child(shot)
	Sfx.play_at(&"shard_fire", from, -2.0)


## Strides after the guard from phase 2, keeping KEEP m and its arena.
func _stride(flat: Vector3, distance: float) -> void:
	var speed: float = SPEED[clampi(phase - 1, 0, SPEED.size() - 1)]
	if speed <= 0.0 or distance <= KEEP:
		return
	var step := flat.normalized() * speed
	var ahead := global_position + step * 0.6 + Vector3.UP * 0.5
	if arena_room != &"" and room_of.is_valid() and room_of.call(ahead) != arena_room:
		return
	velocity.x = step.x
	velocity.z = step.z


## Glides round its arena's path from phase 2 (from the nearest point on).
func _glide(delta: float) -> void:
	var speed: float = SPEED[clampi(phase - 1, 0, SPEED.size() - 1)]
	var path: Array = points[&"path"]
	if speed <= 0.0 or path.size() < 2:
		return
	if path_leg < 0:
		path_leg = 0
		for i in path.size():
			if (path[i] as Transform3D).origin.distance_to(global_position) < (path[path_leg] as Transform3D).origin.distance_to(global_position):
				path_leg = i
	kinematic = true
	velocity = Vector3.ZERO
	var goal: Vector3 = (path[path_leg] as Transform3D).origin
	var to := goal - global_position
	var step := speed * delta
	if to.length() <= step:
		global_position = goal
		path_leg = (path_leg + 1) % path.size()
	else:
		global_position += to.normalized() * step


func _glow_hands(amount: float) -> void:
	for hand in _hands:
		var material := hand.material_override as StandardMaterial3D
		material.emission_enabled = amount > 0.0
		material.emission = Color(1.0, 0.55, 0.2)
		material.emission_energy_multiplier = 3.0 * clampf(amount, 0.0, 1.0)


func _on_phase(next: int) -> void:
	if next > 1:
		Sfx.play_at(&"guardian_wake", global_position + Vector3.UP * 3.0, -6.0)
		pause_left = minf(pause_left, 0.8)


func _on_reset() -> void:
	attack = &""
	pause_left = 1.0
	kinematic = false
	path_leg = -1
	_ring.visible = false
	_glow_hands(0.0)


func _on_defeated(info: DamageInfo) -> void:
	_ring.visible = false
	var center := global_position + Vector3.UP * HEIGHT * 0.5
	for i in 18:
		var at := center + Vector3(randf_range(-0.9, 0.9), randf_range(-1.8, 1.8), randf_range(-0.6, 0.6))
		Fx.chunk(at, _tint, randf_range(0.12, 0.3), info.direction * 2.0 + Vector3(randf_range(-2.5, 2.5), randf_range(1.0, 4.0), randf_range(-2.5, 2.5)))
	Fx.impact(center, Vector3.UP, ExhibitMaterial.Kind.MARBLE, 3.0)


func _part(size: Vector3, at: Vector3, color: Color) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var view := MeshInstance3D.new()
	view.mesh = mesh
	view.position = at
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.85
	view.material_override = material
	_look.add_child(view)
	return view
