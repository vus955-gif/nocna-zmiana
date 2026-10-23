class_name UncannyEffects
extends RefCounted
## What the uncanny events do to the museum (plan
## 2026-10-21-eskalacja-nocy), each on the game's own objects and each
## fair (2.4):
## - level pieces (LevelKit pieces: meta "kit", "kit_room"): hidden (its
##   collision goes with its looks - no invisible walls) or turned about its
##   own base by half a turn, or a quarter on a square base: the footprint
##   stays, so its collision and the navmesh stay true,
## - plain paintings (WallPainting): another picture in the same frame, or
##   the eyes looking aside (PaintingGaze),
## - a sleeping exhibit turned to face a point (it sleeps on),
## - a tomb's lid ajar by a finger (MummyTomb: open() still plays from its
##   rest pose),
## - the clocks' hands running backwards with their pendulums stopped
##   (DecorSpinner "Clockwork" of a room),
## - an open door slamming shut and swinging open again,
## Whatever the reactive environment (EnvLayer) answers for is told what
## happened to it: a hidden piece's hit zones go with it (set_present), a
## turned piece is its props' new rest pose (recapture), a swapped
## painting's prop follows the fresh one (rebind).
## - a sound at a point, and a noise the exhibits hear (Events.noise_made:
##   the perception's own bus and limits), a cold glint, a puff of dust.

## A piece whose position is this close to its PieceSpec's is that piece (m).
const PIECE_MATCH := 0.3
## Square base: its sides differ by at most this much (m).
const SQUARE := 0.05
## Clocks running backwards: the hands this many times their speed.
const CLOCK_REVERSE := 90.0
const CLOCK_SPINNER := "Clockwork"
## A coffin's lid tips this far forward (rad) / a sarcophagus's lid slides
## this far back (m) when ajar.
const COFFIN_AJAR := -0.06
const SARCOPHAGUS_AJAR := 0.07
## A door slams shut and stays shut this long before it swings open again (s).
const SLAM_HOLD := 0.6
const GLINT_COLOR := Color(0.78, 0.88, 1.0)
const DUST_COLOR := Color(0.62, 0.56, 0.46)

const META_HIDDEN := &"uncanny_hidden"
const META_TURNED := &"uncanny_turned"
const META_AJAR := &"uncanny_ajar"
const META_CLOCK := &"uncanny_clock"


# --- pieces ---------------------------------------------------------------------------

## The built piece of [param spec] under [param root] (null when none).
static func find_piece(root: Node, spec: PieceSpec) -> Node3D:
	if root == null or not root.is_inside_tree():
		return null
	for node in root.get_tree().get_nodes_in_group(&"level_kit"):
		var piece := node as Node3D
		if piece == null or not root.is_ancestor_of(piece):
			continue
		if piece.get_meta(&"kit", &"") != spec.kit or piece.get_meta(&"kit_room", &"") != spec.room:
			continue
		if piece.global_position.distance_to(spec.position) <= PIECE_MATCH:
			return piece
	return null


## The reactive environment of the running level (null when there is none,
## or [param node] is not in the tree).
static func _env(node: Node) -> EnvLayer:
	return EnvLayer.of(node.get_tree()) if node != null and node.is_inside_tree() else null


## Hides [param piece] with its collision (the space it stood on is free)
## and its environment props' hit zones.
static func hide_piece(piece: Node3D) -> void:
	if piece == null or piece.get_meta(META_HIDDEN, false):
		return
	piece.set_meta(META_HIDDEN, true)
	piece.visible = false
	for shape in piece.find_children("*", "CollisionShape3D", true, false):
		(shape as CollisionShape3D).set_deferred(&"disabled", true)
	for shape in piece.find_children("*", "CollisionPolygon3D", true, false):
		(shape as CollisionPolygon3D).set_deferred(&"disabled", true)
	var env := _env(piece)
	if env != null:
		env.set_present(piece, false)


static func is_hidden(piece: Node3D) -> bool:
	return piece != null and bool(piece.get_meta(META_HIDDEN, false))


## Turns [param piece] by [param angle] (rad) about its own base (once).
static func turn_piece(piece: Node3D, angle: float) -> void:
	if piece == null or piece.has_meta(META_TURNED):
		return
	piece.set_meta(META_TURNED, angle)
	piece.global_basis = Basis(Vector3.UP, angle) * piece.global_basis
	piece.reset_physics_interpolation()
	var env := _env(piece)
	if env != null:
		env.recapture(piece)


## How far [param piece] was turned (0 when it was not).
static func turned_by(piece: Node3D) -> float:
	return float(piece.get_meta(META_TURNED, 0.0)) if piece != null else 0.0


## The turn that keeps [param spec]'s footprint: half a turn, or on a
## square base the quarter turns that bring its front (-Z) nearest to
## facing [param toward] (INF: half a turn).
static func turn_angle(spec: PieceSpec, toward: Vector3 = Vector3.INF) -> float:
	if toward == Vector3.INF or absf(spec.size.x - spec.size.z) > SQUARE:
		return PI
	var to := toward - spec.position
	if Vector2(to.x, to.z).length() < 0.01:
		return PI
	var wanted := atan2(-to.x, -to.z)
	var best := PI
	var best_off := INF
	for quarter: int in [1, 2, 3]:
		var angle := PI * 0.5 * quarter
		var off := absf(angle_difference(spec.yaw + angle, wanted))
		if off < best_off - 0.0001:
			best_off = off
			best = angle
	return best


## [param spec]'s floor footprint after a turn by [param angle].
static func turned_footprint(spec: PieceSpec, angle: float) -> Rect2:
	var turned := PieceSpec.make(spec.kit, spec.position, spec.size, spec.room, spec.yaw + angle, spec.collide)
	return turned.footprint()


# --- paintings ------------------------------------------------------------------------

## The plain painting hanging at [param at] under [param root] (null when
## none: a portrait hangs there tonight, or none at all).
static func painting_at(root: Node, at: Vector3) -> WallPainting:
	if root == null:
		return null
	for child in root.get_children():
		var painting := child as WallPainting
		if painting != null and not painting.is_queued_for_deletion() and painting.global_position.distance_to(at) < 0.05:
			return painting
	return null


## Hangs [param id] in [param old]'s frame instead (the new painting,
## or [param old] when it already shows [param id]).
static func swap_painting(old: WallPainting, id: StringName) -> WallPainting:
	if old == null or old.painting_id == id:
		return old
	var parent := old.get_parent()
	var fresh := WallPainting.create(old.transform, id)
	fresh.set_meta(&"uncanny_swapped_from", old.painting_id)
	parent.add_child(fresh)
	var env := _env(old)
	if env != null:
		env.rebind(old, fresh)   # before the old one goes: its props follow the fresh one
	old.queue_free()
	return fresh


## The picture left in the frame at [param spot] when its sitter walks out
## (a landscape or a still life: the same one for the same spot, always).
static func empty_picture(spot: StringName) -> StringName:
	var scenes := PaintingArt.SCENE_IDS
	return scenes[absi(String(spot).hash()) % scenes.size()]


## Another sitter for [param id]'s frame: the next face (from three on) that
## the model paints differently.
static func other_sitter(id: StringName) -> StringName:
	var faces := PaintingArt.ids()
	var at := maxi(faces.find(id), 0)
	for step in range(3, faces.size() + 3):
		var candidate := faces[(at + step) % faces.size()]
		if candidate != id and PaintingArt.canvas_for(candidate) != PaintingArt.canvas_for(id):
			return candidate
	return faces[(at + 1) % faces.size()]


## Which way a painting at [param spot] looks when it looks away: to one
## side, the same side for the same spot.
static func aside(spot: StringName) -> Vector2:
	return Vector2(PaintingGaze.LOOK_LIMIT.x if absi(String(spot).hash()) % 2 == 0 else -PaintingGaze.LOOK_LIMIT.x, -0.15)


# --- exhibits, tombs, clocks, doors ---------------------------------------------------

## A sleeping [param exhibit] now faces [param toward] - and sleeps on.
static func turn_sleeper(exhibit: Enemy, toward: Vector3) -> bool:
	if exhibit == null or not is_instance_valid(exhibit) or exhibit.brain.state != EnemyBrain.State.DORMANT or exhibit.is_frozen():
		return false
	exhibit.face(toward)
	return true


## [param tomb]'s lid ajar by a finger (once; a tomb opened already stays).
static func set_ajar(tomb: MummyTomb) -> bool:
	if tomb == null or tomb.lid == null or tomb.is_open() or tomb.has_meta(META_AJAR):
		return false
	tomb.set_meta(META_AJAR, true)
	var rest := tomb.lid.transform
	if tomb.style == MummyMoves.Tomb.COFFIN:
		tomb.lid.transform = Transform3D(rest.basis * Basis(Vector3.RIGHT, COFFIN_AJAR), rest.origin)
	else:
		tomb.lid.transform = Transform3D(rest.basis, rest.origin + Vector3(0.0, 0.0, SARCOPHAGUS_AJAR))
	return true


static func is_ajar(tomb: MummyTomb) -> bool:
	return tomb != null and bool(tomb.get_meta(META_AJAR, false))


## The clockworks of [param room] under [param root] (DecorSpinner nodes
## named CLOCK_SPINNER with meta kit_room).
static func clockworks(root: Node, room: StringName) -> Array[DecorSpinner]:
	var found: Array[DecorSpinner] = []
	if root == null:
		return found
	for node in root.find_children(CLOCK_SPINNER + "*", "Node", true, false):
		if node is DecorSpinner and node.get_meta(&"kit_room", &"") == room:
			found.append(node as DecorSpinner)
	return found


## Runs [param spinner]'s hands backwards and stops its pendulums (on), or
## puts them back as they were (off).
static func reverse_clock(spinner: DecorSpinner, on: bool) -> void:
	if on == spinner.has_meta(META_CLOCK):
		return
	if on:
		var kept := []
		for entry: Array in spinner.targets:
			kept.append(entry[2])
			entry[2] = -absf(float(entry[2])) * CLOCK_REVERSE
		var swings := []
		for entry: Array in spinner.swings:
			swings.append(entry[2])
			entry[2] = 0.0
		spinner.set_meta(META_CLOCK, [kept, swings])
		return
	var saved: Array = spinner.get_meta(META_CLOCK)
	spinner.remove_meta(META_CLOCK)
	for i in mini(spinner.targets.size(), (saved[0] as Array).size()):
		spinner.targets[i][2] = saved[0][i]
	for i in mini(spinner.swings.size(), (saved[1] as Array).size()):
		spinner.swings[i][2] = saved[1][i]


static func clock_reversed(spinner: DecorSpinner) -> bool:
	return spinner.has_meta(META_CLOCK)


## An open, unlocked, resting [param door] slams shut and swings open again
## SLAM_HOLD later (it waits, as doors do, for a doorway someone stands in).
## False when it is no such door.
static func slam(door: Door) -> bool:
	if door == null or not is_instance_valid(door) or not door.is_inside_tree() or not door.is_open or door.locked or door.is_moving():
		return false
	door.close()
	Sfx.play_at(&"door_slam", door.global_position + Vector3.UP * 1.5, -4.0)
	var back := float(Door.TIMES.get(door.style, 0.8)) + SLAM_HOLD
	# bound to the door itself: a door freed meanwhile (the night ended) drops it
	door.get_tree().create_timer(back, false, true).timeout.connect(door.open.bind(false))
	return true


# --- sounds and sights ----------------------------------------------------------------

## [param sound] at [param at]; with [param noise] > 0 the exhibits within
## that many metres may hear something fall there (and go to look: the
## perception decides, at most its INVESTIGATE_CAP).
static func sound(sound_id: StringName, at: Vector3, volume_db: float = 0.0, pitch: float = 1.0, noise: float = 0.0) -> void:
	if sound_id != &"":
		Sfx.play_at(sound_id, at, volume_db, 0.06, pitch)
	if noise > 0.0:
		Events.noise_made.emit(at, noise, ReactionRules.SOURCE_FALL)


## A cold glint (a blade, a helmet) at [param at].
static func glint(at: Vector3) -> void:
	Fx.flash(at, GLINT_COLOR, 2.2, 2.5, 0.22)


## A puff of old dust at [param at].
static func dust(at: Vector3) -> void:
	Fx.puff(at, DUST_COLOR, 18, 0.45)
