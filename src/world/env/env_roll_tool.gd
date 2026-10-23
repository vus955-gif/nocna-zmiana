class_name EnvRollTool
extends EnvTool
## A stone wheel the guard can send rolling (plan docs/superpowers/plans/
## 2026-10-21-srodowisko-walka.md, backlog #23): a cast of the calendar
## stone the conservators stood on edge between two timber trestles,
## chocked in front by a beam and a stake - the stake wears the tag. Hit it and the stone
## rocks against the chocks for the warning while its path is marked on the
## floor (GroundMark.lane); then the chocks fly out and it rolls
## [member distance] metres, gathering speed, and crushes whatever it rolls
## over - each thing once, the guard too (as his own blast would); at the
## end of its run it topples flat and cracks. The trestles stay; the stone
## lies where it fell, without collision.

const ACCEL := 7.0
const TOP_SPEED := 7.5
const TOPPLE_TIME := 0.45
const TRESTLE := Color(0.4, 0.28, 0.17)

var radius: float = 1.1
var thickness: float = 0.4
## How far it rolls (m).
var distance: float = 10.0

var _disc: Node3D = null
var _chocks: Node3D = null
var _rolled: float = 0.0
var _speed: float = 0.0
var _crushed: Array = []
var _guard_hit := false
var _toppling := false


static func make(data: Dictionary, layer: EnvLayer) -> EnvRollTool:
	var spec := layer.room_spec(data["room"])
	if spec == null:
		return null
	var tool := EnvRollTool.new()
	tool.entry = data
	tool.id = StringName(data["id"])
	tool.room = data["room"]
	tool.floor_y = spec.floor_y
	tool.radius = float(data.get("radius", 1.1))
	tool.thickness = float(data.get("thickness", 0.4))
	tool.distance = float(data.get("distance", 10.0))
	tool.exhibit_damage = float(data.get("exhibit_damage", 160.0))
	tool.guard_damage = float(data.get("guard_damage", 40.0))
	tool.knockback = float(data.get("knockback", 10.0))
	tool.transform = Transform3D(Basis(Vector3.UP, float(data.get("yaw", 0.0))), data["at"])
	return tool


func _ready() -> void:
	super()
	_disc = Node3D.new()
	_disc.name = "Stone"
	_disc.position = Vector3(0.0, radius, 0.0)
	add_child(_disc)
	if not _stone_look():
		var stone := EnvLooks.cylinder(_disc, radius, thickness, Vector3.ZERO, EnvLooks.STONE, 32, 0.9)
		stone.rotation.z = PI * 0.5
	# the trestles either side, the chocks in front
	for side in [-1.0, 1.0]:
		var x: float = side * (thickness * 0.5 + 0.2)
		for z in [-0.55, 0.55]:
			EnvLooks.rod(self, Vector3(x, 0.0, z), Vector3(x, radius * 1.15, 0.0), 0.06, TRESTLE, 0.9)
		EnvLooks.box(self, Vector3(0.12, 0.1, 1.3), Vector3(x, radius * 0.55, 0.0), TRESTLE, 0.9)
	# a chock beam across the stone's foot, held by a stake driven in
	# before it: the stake's bolt wears the tag
	_chocks = Node3D.new()
	_chocks.name = "Chocks"
	add_child(_chocks)
	var front := -sqrt(maxf(radius * radius - (radius - 0.18) * (radius - 0.18), 0.0))
	var beam := EnvLooks.box(_chocks, Vector3(thickness + 0.5, 0.18, 0.3), Vector3(0.0, 0.09, front - 0.1), TRESTLE.darkened(0.2), 0.9)
	beam.rotation.x = 0.25
	var stake := -radius - 0.12
	EnvLooks.rod(_chocks, Vector3(0.0, 0.0, stake), Vector3(0.0, 0.5, stake), 0.05, TRESTLE.darkened(0.35), 0.9)
	EnvLooks.rod(_chocks, Vector3(0.0, 0.12, stake), Vector3(0.0, 0.12, front - 0.2), 0.03, EnvLooks.IRON, 0.5, 0.6)
	put_tag(Vector3(0.0, 0.42, stake - 0.06), Vector3(0.0, -0.2, -1.0), float(entry.get("tag_scale", 1.2)))
	tag.reparent(_chocks)
	# solid as the stone is drawn: a disc on edge (the trestles' poles are
	# thin), an obstacle the exhibits path round until it rolls
	var disc := CylinderShape3D.new()
	disc.radius = radius
	disc.height = thickness
	make_solid(disc, Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(0.0, radius, 0.0)))
	var zone := BoxShape3D.new()
	zone.size = Vector3(thickness + 0.1, radius * 2.0, radius * 2.0)
	add_zone_round(zone, Transform3D(Basis.IDENTITY, Vector3(0.0, radius, 0.0)), AABB(Vector3(-(thickness + 0.6) * 0.5, 0.0, -radius), Vector3(thickness + 0.6, radius * 2.0, radius * 2.0)))


## The calendar stone's disc from the art library, turned to roll about X
## and sized to the wheel (false: no model, greybox).
func _stone_look() -> bool:
	var model := ArtLibrary.try_instance(&"sun_stone")
	if model == null:
		return false
	var part := ArtLibrary.parts(model).get("sun_stone_disc") as MeshInstance3D
	if part == null or part.mesh == null:
		model.free()
		return false
	var view := MeshInstance3D.new()
	view.name = "Disc"
	view.mesh = part.mesh
	for i in part.mesh.get_surface_count():
		view.set_surface_override_material(i, part.get_active_material(i))
	model.free()
	var box := view.mesh.get_aabb()
	var thin := 0
	for axis in [1, 2]:
		if box.size[axis] < box.size[thin]:
			thin = axis
	var across := maxf(box.size[(thin + 1) % 3], box.size[(thin + 2) % 3])
	var k := radius * 2.0 / maxf(across, 0.01)
	var turn := Basis.IDENTITY
	if thin == 1:
		turn = Basis(Vector3.BACK, PI * 0.5)
	elif thin == 2:
		turn = Basis(Vector3.UP, PI * 0.5)
	view.transform = Transform3D(turn.scaled(Vector3.ONE * k), Vector3.ZERO) * Transform3D(Basis.IDENTITY, -box.get_center())
	_disc.add_child(view)
	return true


func carrier() -> Node3D:
	return _disc if is_instance_valid(_disc) else self


func _forward() -> Vector3:
	var ahead := -global_basis.z
	return Vector3(ahead.x, 0.0, ahead.z).normalized()


func _make_mark() -> GroundMark:
	return GroundMark.lane(thickness + 1.2, distance + radius)


func _mark_frame() -> Transform3D:
	return Transform3D(Basis.looking_at(_forward(), Vector3.UP), Vector3(global_position.x, floor_y + 0.02, global_position.z))


func _travel_time() -> float:
	return sqrt(2.0 * distance / ACCEL)


func _warn_start() -> void:
	Sfx.play_at(&"bust_grind", global_position + Vector3.UP * 0.4, 0.0, 0.08, 0.7)


func _warn_tick(_delta: float, progress: float) -> void:
	if _disc == null:
		return
	_disc.rotation.x = sin(progress * 38.0) * 0.035 * (0.4 + progress)
	if int(progress * 8.0) != int((progress - 0.02) * 8.0):
		Fx.puff(global_position + _forward() * 0.6 + Vector3.UP * 0.1, Color(0.72, 0.66, 0.56), 6, 0.3)


func _strike() -> void:
	drop_solids()
	if tag != null:
		tag.retire()
	if _chocks != null:
		var fly := create_tween().set_parallel(true)
		fly.tween_property(_chocks, ^"position", _chocks.position + Vector3(0.0, 0.1, -1.2), 0.3)
		fly.tween_property(_chocks, ^"rotation:x", 2.5, 0.3)
	_disc.rotation.x = 0.0
	_rolled = 0.0
	_speed = 0.0
	_crushed.clear()
	_guard_hit = false
	Sfx.play_at(&"lock_boards_hit", global_position, 0.0)


func _fall_tick(delta: float) -> void:
	if _toppling:
		return
	_speed = minf(_speed + ACCEL * delta, TOP_SPEED)
	_rolled = minf(_rolled + _speed * delta, distance)
	_disc.position = Vector3(0.0, radius, -_rolled)
	_disc.rotation.x = -_rolled / radius
	_crush()
	if _rolled >= distance:
		_toppling = true
		# it tips over sideways (about its run's line), its face as it rolled
		var flat := Transform3D(Basis(Vector3.BACK, PI * 0.5) * _disc.basis, Vector3(0.0, thickness * 0.5, -_rolled))
		var tween := create_tween()
		tween.tween_property(_disc, ^"transform", flat, TOPPLE_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.tween_callback(_landed)


## Whatever the stone rolls over now (each thing once).
func _crush() -> void:
	var center := _disc.global_position
	var frame := Transform3D(Basis.looking_at(_forward(), Vector3.UP), center)
	var size := Vector3(thickness + 0.5, radius * 2.0, radius * 1.6)
	var exclude: Array = [self, tag]
	exclude.append_array(_crushed)
	for receiver in EnvStrike.in_box(self, frame, size, exclude):
		_crushed.append(receiver)
		EnvStrike.hit(receiver, exhibit_damage, DamageInfo.Kind.BLUNT, credited(), center, _forward(), knockback, stun)
	var player := guard()
	if not _guard_hit and EnvStrike.guard_in_box(player, frame, size):
		_guard_hit = true
		var side := player.global_position - center
		side = side - _forward() * side.dot(_forward())
		EnvStrike.hurt_guard(player, guard_damage, by_guard(), center, side + _forward() * 0.5, knockback, DamageInfo.Kind.BLUNT, credited())


func _landed() -> void:
	var at := Vector3(_disc.global_position.x, floor_y, _disc.global_position.z)
	for view in EnvBreak.views(_disc):
		EnvBreak.shards(view, 4, Vector3.UP * 2.0)
	Fx.shatter(at + Vector3.UP * 0.3, ExhibitMaterial.Kind.MARBLE, GibPlanner.plan(ExhibitMaterial.Kind.MARBLE, 0.0, 100.0, false, 0.5), _forward(), false)
	Fx.puff(at + Vector3.UP * 0.2, Color(0.72, 0.66, 0.56), 30, radius * 1.2)
	Sfx.play_at(&"rubble", at, 2.0)
	Sfx.play_at(&"weight_thud", at, 3.0)
	_feel(at, 6.0)
	noise(at, EnvRules.NOISE_CRASH, ReactionRules.SOURCE_BLAST)
	_struck()


func _rest_down() -> void:
	drop_solids()
	if _chocks != null:
		_chocks.visible = false
	if _disc != null:
		_disc.position = Vector3(0.0, thickness * 0.5, -distance)
		_disc.rotation = Vector3(0.0, 0.0, PI * 0.5)
