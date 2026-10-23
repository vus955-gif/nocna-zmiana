class_name EnvProp
extends Node3D
## One reactive thing of the museum (plan docs/superpowers/plans/
## 2026-10-21-srodowisko-walka.md, backlog #22): a glass case, a hanging
## lamp, a bust on its plinth, a painting, a banner, a shelf of books, a jar
## - and, as EnvTool, the tagged tools of #23. EnvLayer puts one next to
## what it animates ([member target]: a level piece, a lamp's fixture, a
## WallPainting) and gives it a hit zone ([member hurtbox]): every weapon,
## blast and tool finds it like an exhibit's (take_damage()).
## An idle prop costs nothing per frame; a hit wakes it (EnvLayer.activate:
## its _physics_process runs while it swings, tilts, warns or falls) and it
## goes back to sleep when it is still. What breaks stays broken for the
## night: [member is_down] (the world snapshot's state) and RunState.used
## (EnvRules.used_id), so a resumed night rebuilds it broken
## (restore_down(): the end state at once, no effects, no noise). It never
## adds or moves a collider that blocks anyone: a falling thing first turns
## its own collision off.

signal knocked_down(prop: EnvProp)

enum Phase { IDLE, MOVING, WARNING, FALLING, DOWN }

## Stable id (EnvLayer.make_id: kind, room, place).
var id: StringName = &""
var room: StringName = &""
## The node it animates (null for a tool that builds its own).
var target: Node3D = null
## Broken, fallen, torn down: stays so for the night.
var is_down: bool = false
var phase: Phase = Phase.IDLE
## Its first hit zone (and every zone in [member zones]).
var hurtbox: Hurtbox = null
var zones: Array[Hurtbox] = []
## Damage taken so far.
var taken: float = 0.0
## Who set it going (credited with what it crushes; null: the guard).
var culprit: Node = null
## Its EnvLayer (activity budget, the guard, noises); null in a bare test.
var layer: Node = null
## Its piece is not there now (hidden by something else, e.g. the night's
## uncanny turns: EnvLayer.set_present): no zone, no answer.
var absent: bool = false

var _targeted := false


## A hit from any weapon, blast or tool.
func take_damage(info: DamageInfo) -> void:
	if is_down or absent or info == null:
		return
	if _targeted and not is_instance_valid(target):
		# its piece was taken away without a word (freed): it answers no more
		absent = true
		_retire_zone()
		return
	if _targeted and not target.visible:
		return   # its piece is hidden (without set_present()): nothing there to hit
	if info.source != null and is_instance_valid(info.source):
		culprit = info.source
	_hit(info)


## The broken end state at once (a resumed night): no effects, no noise,
## no damage.
func restore_down() -> void:
	if is_down:
		return
	is_down = true
	phase = Phase.DOWN
	_retire_zone()
	_finish_down()


## Marks it broken for the night (RunState.used) and tells the layer.
func mark_down() -> void:
	if is_down:
		return
	is_down = true
	phase = Phase.DOWN
	_retire_zone()
	if layer != null and layer.has_method(&"remember"):
		layer.call(&"remember", self)
	knocked_down.emit(self)


## Snaps any swing or tilt to rest at once (the activity budget).
func settle() -> void:
	pass


## Takes its piece's pose now as its rest (something else turned or moved
## the piece while it stood still: EnvLayer.recapture). Moving or broken, it
## keeps its own.
func recapture() -> void:
	if not is_instance_valid(target) or is_down or phase != Phase.IDLE:
		return
	global_transform = _frame_of(target)


## The node that moves when it swings, tilts or falls (its piece; a tool's
## load): what sticks in it (a harpoon) rides on this one.
func carrier() -> Node3D:
	return target if is_instance_valid(target) else self


## True when its piece was freed under it (no rebind yet).
func lost_target() -> bool:
	return _targeted and not is_instance_valid(target)


## Follows [param fresh], which took its piece's place (a painting swapped
## for another in place: EnvLayer.rebind).
func rebind(fresh: Node3D) -> void:
	settle()
	if phase == Phase.MOVING:
		phase = Phase.IDLE
	target = fresh
	_targeted = fresh != null
	absent = false
	recapture()
	if is_down:
		_finish_down()
	elif fresh != null:
		_revive_zone()


## Its piece is there (true) or not (false: hidden; no zone, no answer).
func set_present(present: bool) -> void:
	absent = not present
	if not present:
		settle()
		_retire_zone()
	elif not is_down:
		_revive_zone()


## The frame the prop stands in for [param piece] (its own by default).
func _frame_of(piece: Node3D) -> Transform3D:
	return piece.global_transform


## The guard, if any.
func guard() -> Player:
	if layer != null and layer.has_method(&"guard"):
		return layer.call(&"guard") as Player
	if is_inside_tree():
		for node in get_tree().get_nodes_in_group(&"player"):
			if node is Player:
				return node
	return null


## The node credited with what this prop does: who set it going, else the
## guard.
func credited() -> Node:
	if culprit != null and is_instance_valid(culprit):
		return culprit
	return guard()


## True when the guard set it going (or nobody else did).
func by_guard() -> bool:
	return culprit == null or not is_instance_valid(culprit) or culprit is Player


## A hit zone for this prop: [param shape] at [param at] (local). The
## zone's origin is [param anchor] (local; at [param at] when INF): a blast
## looks for a zone there through the air (Blast._clear).
func add_zone(shape: Shape3D, at: Transform3D = Transform3D.IDENTITY, anchor: Vector3 = Vector3.INF) -> Hurtbox:
	var origin := at.origin if anchor == Vector3.INF else anchor
	var zone := Hurtbox.make(self, shape, origin)
	zone.name = "EnvZone"
	(zone.get_child(0) as Node3D).transform = Transform3D(at.basis, at.origin - origin)
	add_child(zone)
	zones.append(zone)
	if hurtbox == null:
		hurtbox = zone
	return zone


## The same zone ([param shape] at [param at]) anchored on the four sides of
## [param solid] (local; the box of something solid round it - a case's
## body round its glass, a plinth under its bust), just outside it at the
## zone's height: a blast from any side finds it through the air, and a
## shot finds it as one target.
func add_zone_round(shape: Shape3D, at: Transform3D, solid: AABB) -> void:
	var middle := solid.get_center()
	var y := at.origin.y
	for side: Vector3 in [Vector3.RIGHT, Vector3.LEFT, Vector3.BACK, Vector3.FORWARD]:
		var reach := absf(side.x) * solid.size.x * 0.5 + absf(side.z) * solid.size.z * 0.5 + 0.06
		add_zone(shape, at, Vector3(middle.x, y, middle.z) + side * reach)


## Wakes it: its _physics_process runs (EnvLayer counts it against
## EnvRules.ACTIVE_CAP).
func wake() -> void:
	if layer != null and layer.has_method(&"activate"):
		layer.call(&"activate", self)
	else:
		set_physics_process(true)


## Back to sleep: no processing.
func rest() -> void:
	if layer != null and layer.has_method(&"deactivate"):
		layer.call(&"deactivate", self)
	else:
		set_physics_process(false)


## A noise for the exhibits (Events.noise_made).
func noise(at: Vector3, radius: float, source: StringName) -> void:
	Events.noise_made.emit(at, radius, source)


func _ready() -> void:
	set_physics_process(false)
	_targeted = target != null


func _hit(_info: DamageInfo) -> void:
	pass


## The end state's look (fallen, broken, torn down).
func _finish_down() -> void:
	pass


func _retire_zone() -> void:
	for zone in zones:
		if is_instance_valid(zone):
			zone.collision_layer = 0


func _revive_zone() -> void:
	for zone in zones:
		if is_instance_valid(zone):
			zone.collision_layer = Layers.HURTBOX


## Turns off every collision of [param node] (a piece that starts to fall):
## nothing that moves blocks anyone (the softlock rule).
static func drop_collision(node: Node) -> void:
	if node is CollisionObject3D:
		(node as CollisionObject3D).collision_layer = 0
		(node as CollisionObject3D).collision_mask = 0
	for child in node.find_children("*", "CollisionObject3D", true, false):
		if child is Hurtbox:
			continue
		(child as CollisionObject3D).collision_layer = 0
		(child as CollisionObject3D).collision_mask = 0
