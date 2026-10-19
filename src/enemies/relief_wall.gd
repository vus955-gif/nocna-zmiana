class_name ReliefWall
extends RefCounted
## A relief figure's bond with its wall (design pietro-1-projekt 5.2),
## owned by ReliefWarrior and ReliefLion:
## - set up at its post, asleep: it looks for the wall behind it (rays on
##   the level's geometry within ReliefMoves.WALL_REACH; none: its slab
##   stands free, a stele) and puts its awakening slab (ReliefPanel) there
##   with itself as the carved figure; an exhibit set up awake (a patrol)
##   is simply out;
## - woken: the slab's cracks glow up (CRACK_TIME, relief_crack), the
##   figure leaves the pocket and the enemy steps out of it (STEP_TIME,
##   relief_scrape);
## - the warrior may sink into a wall within reach (SINK_TIME: it walks
##   back into an empty pocket there), travel hidden in it (TRAVEL_TIME)
##   and tear out of a slab SLIDE metres along it (a shorter crack);
## - while it is in the wall it is the wall: no attacks, no steering, no
##   hits (hurtable()), its own model hidden while the slab's figure or the
##   wall stands in for it (model_shown());
## - home again and asleep (rest()) it sinks back into its slab, the carved
##   figure whole in its pocket, to crack out of it anew when it wakes.
## It moves the body itself (global_position) while busy.

const W := ReliefMoves.Wall

var enemy: Enemy
var kind: ReliefPanel.Kind = ReliefPanel.Kind.WARRIOR
var state: ReliefMoves.Wall = ReliefMoves.Wall.IN
## The slab it is in (or came out of).
var panel: ReliefPanel = null
## Its wall: a point on the face at the floor, and the way out of it (flat).
var wall_point := Vector3.ZERO
var normal := Vector3.BACK
## Free-standing: no wall was found at its post (it cannot sink there).
var stele := false

var _timer: float = 0.0
var _from := Vector3.ZERO
var _to := Vector3.ZERO
var _next_point := Vector3.ZERO
var _panels: Array[ReliefPanel] = []
var _set_up := false
## Coming out again after sinking (a shorter crack).
var _returning := false
## Sinking into its own slab to rest (no travel, no crack: it stays in).
var _homing := false


func _init(owner: Enemy, panel_kind: ReliefPanel.Kind) -> void:
	enemy = owner
	kind = panel_kind


## Finds its wall and puts up its slab with the figure in it (call once it
## stands at its post, in the tree). Awake already, it is just out.
func setup() -> void:
	if _set_up or not enemy.is_inside_tree():
		return
	_set_up = true
	if enemy.brain.state != EnemyBrain.State.DORMANT:
		state = W.OUT
		return
	var facing := -enemy.global_basis.z
	facing.y = 0.0
	facing = facing.normalized() if facing.length_squared() > 0.0001 else Vector3.FORWARD
	var found := find_wall(enemy.global_position, -facing)
	if found.is_empty():
		stele = true
		normal = facing
		wall_point = enemy.global_position - facing * 0.1
	else:
		wall_point = found["point"]
		normal = found["normal"]
	_place_panel(wall_point, false)
	_put_in(panel)


## The nearest wall within ReliefMoves.WALL_REACH of [param from] (rays at
## knee and chest height, [param first] tried first, then round about), or
## {}: {point (on the face, at from's height), normal (flat, out of it)}.
func find_wall(from: Vector3, first: Vector3) -> Dictionary:
	var space := enemy.get_world_3d().direct_space_state
	var best := {}
	var best_distance := INF
	var directions: Array[Vector3] = [first]
	for i in 8:
		directions.append(Vector3.FORWARD.rotated(Vector3.UP, TAU * i / 8.0))
	var eye := from + Vector3.UP * 1.0
	for direction in directions:
		var query := PhysicsRayQueryParameters3D.create(eye, eye + direction * ReliefMoves.WALL_REACH, Layers.WORLD)
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			continue
		var face: Vector3 = hit["normal"]
		if absf(face.y) > 0.3:
			continue
		var distance := eye.distance_to(hit["position"])
		if distance < best_distance - 0.05:
			best_distance = distance
			var point: Vector3 = hit["position"]
			best = {"point": Vector3(point.x, from.y, point.z), "normal": Vector3(face.x, 0.0, face.z).normalized()}
	return best


## Woken in its slab: the crack, then the step out. (Woken before it was
## set up - a patrol starting - it has no slab: setup() finds it awake.)
func wake() -> void:
	if state != W.IN or panel == null:
		return
	_begin(W.CRACKING, ReliefMoves.CRACK_TIME)
	Sfx.play_at(&"relief_crack", panel.figure_point() + Vector3.UP * 1.0)


## Not out in the room (in the wall, cracking loose, stepping, sinking).
func busy() -> bool:
	return state != W.OUT


## Can be hit now: out, stepping out, or only starting to sink.
func hurtable() -> bool:
	match state:
		W.OUT, W.STEPPING:
			return true
		W.SINKING:
			return _timer > ReliefMoves.SINK_TIME * 0.5
	return false


## Out of sight inside the wall.
func hidden() -> bool:
	return state == W.TRAVELLING


## Its own model shows (not while the slab's carved figure stands in for
## it, nor inside the wall).
func model_shown() -> bool:
	if hidden():
		return false
	if (state == W.IN or state == W.CRACKING) and panel != null and panel.shows_figure():
		return false
	return true


## How far its current crack has gone (0..1).
func crack_level() -> float:
	return panel.crack_level() if panel != null else 0.0


## 0 flush in the wall .. 1 out in the room (the step's progress).
func out_share() -> float:
	match state:
		W.OUT:
			return 1.0
		W.STEPPING:
			return 1.0 - _timer / ReliefMoves.STEP_TIME
		W.SINKING:
			return _timer / ReliefMoves.SINK_TIME
	return 0.0


## Sinks into the wall within reach and comes out SLIDE metres along it,
## on the side away from [param away_from] if it can; false when there is
## no wall, no room along it, or it is busy.
func sink(away_from: Vector3) -> bool:
	if state != W.OUT:
		return false
	var facing := -enemy.global_basis.z
	facing.y = 0.0
	var found := find_wall(enemy.global_position, -facing.normalized() if facing.length_squared() > 0.0001 else Vector3.BACK)
	if found.is_empty():
		return false
	var point: Vector3 = found["point"]
	var face: Vector3 = found["normal"]
	for spot in ReliefMoves.slide_spots(point, face, away_from):
		if _wall_at(spot, face):
			wall_point = point
			normal = face
			_next_point = spot
			_returning = true
			_place_panel(point, true)
			_from = enemy.global_position
			_to = panel.figure_point()
			enemy.face(enemy.global_position + face)
			_begin(W.SINKING, ReliefMoves.SINK_TIME)
			Sfx.play_at(&"relief_scrape", point + Vector3.UP * 1.0)
			return true
	return false


## Asleep at its post again: it sinks back into its slab (a figure with a
## slab on a wall; a stele, or one still busy, stays as it is).
func rest() -> void:
	if state != W.OUT or panel == null or stele or not is_instance_valid(panel):
		return
	_homing = true
	_returning = false
	_from = enemy.global_position
	_to = panel.figure_point()
	enemy.face(enemy.global_position + normal)
	_begin(W.SINKING, ReliefMoves.SINK_TIME)
	Sfx.play_at(&"relief_scrape", panel.figure_point() + Vector3.UP * 1.0, -6.0)


## One step of its wall business, moving the body while busy.
func tick(delta: float) -> void:
	if not _set_up or state == W.OUT or state == W.IN:
		return
	_timer -= delta
	match state:
		W.CRACKING:
			var length := ReliefMoves.RECRACK_TIME if _returning else ReliefMoves.CRACK_TIME
			panel.crack(1.0 - maxf(_timer, 0.0) / length)
			if _timer <= 0.0:
				_from = enemy.global_position
				_to = panel.figure_point() + normal * ReliefMoves.STEP_OUT
				panel.set_empty(true)
				_begin(W.STEPPING, ReliefMoves.STEP_TIME)
				Sfx.play_at(&"relief_scrape", panel.figure_point() + Vector3.UP * 1.0)
		W.STEPPING:
			_glide(1.0 - _timer / ReliefMoves.STEP_TIME)
			if _timer <= 0.0:
				_returning = false
				panel.crack(0.0)
				state = W.OUT
		W.SINKING:
			_glide(1.0 - _timer / ReliefMoves.SINK_TIME)
			if _timer <= 0.0:
				if _homing:
					_homing = false
					_put_in(panel)
					panel.set_empty(false)
					panel.crack(0.0)
					state = W.IN
				else:
					_begin(W.TRAVELLING, ReliefMoves.TRAVEL_TIME)
		W.TRAVELLING:
			if _timer <= 0.0:
				wall_point = _next_point
				_place_panel(wall_point, false)
				_put_in(panel)
				_begin(W.CRACKING, ReliefMoves.RECRACK_TIME)
				Sfx.play_at(&"relief_crack", panel.figure_point() + Vector3.UP * 1.0, -3.0)


func _begin(next: ReliefMoves.Wall, seconds: float) -> void:
	state = next
	_timer = seconds


## Moves the body from _from toward _to by [param share] (eased).
func _glide(share: float) -> void:
	var k := clampf(share, 0.0, 1.0)
	k = k * k * (3.0 - 2.0 * k)
	var at := _from.lerp(_to, k)
	enemy.global_position = Vector3(at.x, enemy.global_position.y, at.z)
	enemy.velocity = Vector3(0.0, enemy.velocity.y, 0.0)


## Stands the body where [param slab]'s figure is, facing out.
func _put_in(slab: ReliefPanel) -> void:
	var at := slab.figure_point()
	enemy.global_position = Vector3(at.x, enemy.global_position.y, at.z)
	enemy.face(enemy.global_position + normal)
	enemy.velocity = Vector3.ZERO
	enemy.reset_physics_interpolation()


## A slab on the wall at [param point] (the figure standing there), its
## pocket [param empty] or holding the figure: the one already there, or a
## new one (at most three per figure, the oldest moved).
func _place_panel(point: Vector3, empty: bool) -> void:
	var turn := Basis.looking_at(normal, Vector3.UP)   # front (-Z) into the room
	var origin := point - turn * Vector3(ReliefPanel.FIGURE_AT[kind].x, 0.0, 0.0)
	var at := Transform3D(turn, origin)
	panel = null
	for existing in _panels:
		if is_instance_valid(existing) and existing.global_position.distance_to(origin) < 0.5:
			panel = existing
	if panel == null and _panels.size() >= 3:
		panel = _panels.pop_front()
		_panels.append(panel)
		panel.global_transform = at
	elif panel == null:
		var holder := enemy.get_parent() as Node3D
		panel = ReliefPanel.build(kind, holder.global_transform.affine_inverse() * at if holder != null else at)
		enemy.get_parent().add_child(panel)
		_panels.append(panel)
	panel.set_empty(empty)
	panel.crack(0.0)


## True when a wall facing [param face] runs at [param spot] with floor
## in front of it (the figure can come out there).
func _wall_at(spot: Vector3, face: Vector3) -> bool:
	var space := enemy.get_world_3d().direct_space_state
	var out := spot + face * 0.8 + Vector3.UP * 1.0
	var query := PhysicsRayQueryParameters3D.create(out, out - face * 1.3, Layers.WORLD)
	var hit := space.intersect_ray(query)
	if hit.is_empty() or (hit["normal"] as Vector3).dot(face) < 0.9:
		return false
	var down := PhysicsRayQueryParameters3D.create(spot + face * 0.8 + Vector3.UP * 0.5, spot + face * 0.8 + Vector3.DOWN * 0.6, Layers.WORLD)
	var floor_hit := space.intersect_ray(down)
	return not floor_hit.is_empty() and absf((floor_hit["position"] as Vector3).y - spot.y) < 0.3
