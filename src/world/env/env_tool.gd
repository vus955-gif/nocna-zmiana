class_name EnvTool
extends EnvProp
## A tool of environmental combat (plan docs/superpowers/plans/
## 2026-10-21-srodowisko-walka.md, backlog #23): something of the museum
## the guard can turn against the exhibits - a chandelier, a storm lamp
## over the camp, a cracked column, a bookcase, a slab on a hoist, a crate
## of fire-arrows, a stone wheel. Every one wears the red tag (EnvTag) on
## its weak mount. Its course:
## - ARMED (IDLE): a hit on the tag, a blast beside it or TOOL_BODY_HP into
##   its body (EnvRules.tool_triggered) sets it going; lighter hits on the
##   body only rock it (_body_hit);
## - WARNING (warning >= EnvRules.MIN_WARNING s): it creaks, its mount
##   sheds dust, it shivers, and the floor where it will strike is marked
##   (GroundMark - the guardians' telegraph: a darkening shadow, a rim
##   growing hot) up to the moment it lands;
## - FALLING: it drops, topples, fires, rolls (_strike(); the kind calls
##   _struck() when the blow has landed);
## - then DOWN for the night (RunState.used; a resumed night rebuilds its
##   end: _finish_down).
## Whatever it strikes takes the blow (EnvStrike: exhibits, the museum's
## other props); the guard in the way takes what his own blast would.
## A standing tool (the column, the crate, the wheel) is solid where it
## stands ([member solids], make_solid()): a source of the level's walkable
## navigation, so the exhibits path round it (EnvLayer.add_obstacle). It
## never adds or moves any other collider that blocks, and it drops its own
## collision the moment it moves (drop_solids(): the navigation is rebaked
## round it - the way is free again).

signal triggered(tool: EnvTool)
signal struck(tool: EnvTool)

var warning: float = EnvRules.TOOL_WARNING
var tag: EnvTag = null
## The floor (world y) it strikes.
var floor_y: float = 0.0
## The blow: exhibits (and the museum's props), the guard, a push, a stun.
var exhibit_damage: float = 120.0
var guard_damage: float = 35.0
var knockback: float = 8.0
var stun: float = 0.0
## Its catalog entry (EnvCatalog).
var entry: Dictionary = {}
## The solid bodies it stands as (make_solid(); empty for a hanging tool or
## a level piece taken over). With the level's navigation they live under
## its walkable sources (MuseumFloorLevel.walk_dynamic), not under the tool.
var solids: Array[StaticBody3D] = []

var _left: float = 0.0
var _mark: GroundMark = null


## A solid body of the tool where it stands: [param shape] at [param at]
## (the tool's frame), blocking like a wall (Layers.WORLD) and an obstacle
## of the walkable navigation (EnvLayer.add_obstacle). Call from _ready().
func make_solid(shape: Shape3D, at: Transform3D) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "Body"
	body.collision_layer = Layers.WORLD
	body.collision_mask = 0
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.transform = at
	body.add_child(collider)
	add_child(body)
	solids.append(body)
	if layer != null and layer.has_method(&"add_obstacle"):
		layer.call(&"add_obstacle", body)
	return body


## It moves (or lies broken): its bodies block nobody any more, and the
## navigation round them is rebaked (EnvLayer.clear_obstacle).
func drop_solids() -> void:
	for body in solids:
		if not is_instance_valid(body) or body.collision_layer == 0:
			continue
		EnvProp.drop_collision(body)
		if layer != null and layer.has_method(&"clear_obstacle"):
			layer.call(&"clear_obstacle", body)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		# (bodies moved among the level's walkable sources go with the tool)
		for body in solids:
			if is_instance_valid(body) and body.get_parent() != self and not body.is_queued_for_deletion():
				body.queue_free()


## The tag was hit.
func tag_hit(info: DamageInfo) -> void:
	if phase != Phase.IDLE or is_down:
		return
	if info != null and info.source != null and is_instance_valid(info.source):
		culprit = info.source
	if EnvRules.tool_triggered(true, taken, info):
		trigger(info)


## Its body was hit (or a blast went off beside it).
func _hit(info: DamageInfo) -> void:
	if phase != Phase.IDLE or not EnvRules.real(info):
		return
	taken += info.amount
	if EnvRules.tool_triggered(false, taken, info):
		trigger(info)
		return
	_body_hit(info)


## Sets it going: the warning, then the strike.
func trigger(_info: DamageInfo = null) -> void:
	if phase != Phase.IDLE or is_down:
		return
	phase = Phase.WARNING
	_left = warning
	if tag != null:
		tag.set_spent(true)
	_mark = _make_mark()
	if _mark != null:
		add_child(_mark)
		_mark.global_transform = _mark_frame()
		_mark.progress = 0.0
	_warn_start()
	triggered.emit(self)
	wake()


## Seconds left of the warning (0 once it strikes).
func warning_left() -> float:
	return _left if phase == Phase.WARNING else 0.0


func _physics_process(delta: float) -> void:
	match phase:
		Phase.WARNING:
			_left -= delta
			var span := warning + _travel_time()
			if is_instance_valid(_mark):
				_mark.progress = clampf((warning - _left) / span, 0.0, 1.0)
			_warn_tick(delta, clampf(1.0 - _left / warning, 0.0, 1.0))
			if _left <= 0.0:
				phase = Phase.FALLING
				_strike()
		Phase.FALLING:
			if is_instance_valid(_mark):
				var span := warning + _travel_time()
				_mark.progress = minf(_mark.progress + delta / maxf(span, 0.01), 1.0)
			_fall_tick(delta)
		_:
			rest()


## The blow has landed: the mark goes, the tool is spent for the night.
func _struck() -> void:
	if is_instance_valid(_mark):
		_mark.vanish(0.35)
		_mark = null
	struck.emit(self)
	if tag != null:
		tag.retire()
	mark_down()
	rest()


## A shake of the guard's view for a blow at [param at] (a crash he feels).
func _feel(at: Vector3, radius: float) -> void:
	var camera := get_viewport().get_camera_3d() as ShakeCamera if is_inside_tree() else null
	if camera != null:
		camera.feel_blast(at, radius)


## Puts the tag on the tool at [param at] (local), facing [param facing]
## (local; the side the guard looks from), at [param size].
func put_tag(at: Vector3, facing: Vector3, size: float = 1.0) -> EnvTag:
	tag = EnvTag.make(self, size)
	var look := facing.normalized() if facing.length() > 0.01 else Vector3.FORWARD
	var up := Vector3.UP if absf(look.dot(Vector3.UP)) < 0.95 else Vector3.BACK
	tag.transform = Transform3D(Basis.looking_at(look, up), at)
	add_child(tag)
	return tag


func _finish_down() -> void:
	if tag != null:
		tag.retire()
	if is_instance_valid(_mark):
		_mark.queue_free()
	_rest_down()


# --- what a kind of tool fills in ------------------------------------------------

## Its mark on the floor (null: none).
func _make_mark() -> GroundMark:
	return null


## Where the mark lies (world).
func _mark_frame() -> Transform3D:
	return Transform3D(Basis.IDENTITY, Vector3(global_position.x, floor_y + 0.02, global_position.z))


## Seconds from the end of the warning to the blow (a drop's fall).
func _travel_time() -> float:
	return 0.0


func _warn_start() -> void:
	pass


## [param progress] 0..1 through the warning.
func _warn_tick(_delta: float, _progress: float) -> void:
	pass


func _strike() -> void:
	_struck()


func _fall_tick(_delta: float) -> void:
	pass


## A hit on the body that does not set it off.
func _body_hit(info: DamageInfo) -> void:
	Fx.impact(info.position, info.normal, ExhibitMaterial.Kind.METAL, 0.5)


## Its end, at once (a resumed night).
func _rest_down() -> void:
	pass
