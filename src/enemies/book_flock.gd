class_name BookFlock
extends RefCounted
## A flock of flying books (design pietro-1-projekt 5.4): 4-6 books from
## one spawn slot that live, hunt and sleep together. The flock is the
## controller; its books (FlyingBook) are light members that ask it:
## - who leads (the first book still standing; the flock counts as one
##   hunter, its lead's),
## - where each one circles: a ring round the guard, RING_RADIUS out, at
##   its own height, turning slowly (RING_SPIN), wider while spooked,
## - who may dive: one book at a time, DIVE_GAP after the last dive ended,
##   OWN_COOLDOWN between a book's own dives, none while spooked - a
##   rhythm the guard can read and answer,
## - who wakes when one wakes (one after another, WAKE_STAGGER apart,
##   nearest first),
## - how they scatter when one is shot down (the ones within
##   SCATTER_RADIUS fly off, the flock is spooked for SPOOK_TIME),
## - where they sleep: standing on the nearest shelf (a row of closed
##   books, spines to the room) or, with no shelf near, stacked on the
##   floor (perches()).
## The flock keeps its own clock (tick(), once per physics frame).

const MIN_SIZE := 4
const MAX_SIZE := 6
## Seconds from the end of one dive to the next telegraph.
const DIVE_GAP := 0.5
## Seconds between one book's own dives (from start to start).
const OWN_COOLDOWN := 2.5
const SPOOK_TIME := 0.8
const SCATTER_RADIUS := 4.0
const SCATTER_SPEED := 3.5
## The ring round the guard: radius range (m), turning speed (rad/s), and
## how much wider it gets while the flock is spooked.
const RING_RADIUS := Vector2(4.5, 6.0)
const RING_SPIN := 0.45
const SPOOK_WIDEN := 1.5
## Height of the ring places over the guard's feet (m), by member.
const RING_HEIGHT := Vector2(1.7, 2.6)
## Members wake one after another this far apart (s).
const WAKE_STAGGER := 0.12
## The shelf it sleeps on: looked for this far (m) at this height over the
## slot (m); the books stand this far off its face, this far apart.
const SHELF_REACH := 3.0
const SHELF_HEIGHT := 1.25
const SHELF_OFFSET := 0.1
const SHELF_SPACING := 0.075
## A shelf face is a wall: its normal no steeper than this (|y|).
const SHELF_STEEP := 0.3
## No shelf near: stacked on the floor, a closed book thick (m).
const STACK_BASE := 0.035
const STACK_STEP := 0.062
## Members start in a small circle round the slot (m), this high.
const SPREAD := 0.6
const START_HEIGHT := 1.6

## The books, in flock order (FlyingBook; destroyed ones leave).
var members: Array = []
## Which way the ring turns (+1 / -1).
var spin_sign: float = 1.0
## The flock's clock (s).
var clock: float = 0.0
## The slot it came from (world space).
var center := Vector3.ZERO
## Book instance id -> its place to sleep (world Transform3D), once found.
var perches_found: Dictionary = {}

var _diver: Object = null
var _gap_until: float = -INF
var _last_dive: Dictionary = {}
var _spooked_until: float = -INF
var _frame: int = -1


func _init() -> void:
	spin_sign = 1.0 if randf() < 0.5 else -1.0


## A flock of [param count] books for a slot at [param center] (world
## space; not in the tree yet), facing [param yaw]: in a small circle,
## a little above the floor (a flock that starts awake takes off from
## there; a sleeping one goes to its shelf at once).
static func make_members(at: Vector3, yaw: float, count: int) -> Array[Enemy]:
	var flock := BookFlock.new()
	flock.center = at
	var books: Array[Enemy] = []
	for i in count:
		var book := FlyingBook.new()
		book.flock = flock
		book.flock_index = i
		var angle := TAU * i / float(maxi(count, 1))
		book.position = at + Vector3(cos(angle), 0.0, sin(angle)) * (SPREAD if count > 1 else 0.0) + Vector3.UP * START_HEIGHT
		book.rotation.y = yaw
		flock.members.append(book)
		books.append(book)
	return books


## Advances the flock's clock (once per physics [param frame]; -1 = always).
func tick(delta: float, frame: int = -1) -> void:
	if frame >= 0:
		if frame == _frame:
			return
		_frame = frame
	clock += delta


func join(book: Object) -> void:
	if not members.has(book):
		members.append(book)


## A book is gone (destroyed, fell out): it no longer leads nor dives.
func leave(book: Object) -> void:
	members.erase(book)
	if _diver == book:
		end_dive(book)


## The books still standing, in flock order.
func alive() -> Array:
	var out: Array = []
	for book in members:
		if is_instance_valid(book) and not book.is_queued_for_deletion():
			out.append(book)
	return out


## The lead: the first book still standing (null when none is left).
func lead() -> Object:
	var standing := alive()
	return standing[0] if not standing.is_empty() else null


func is_lead(book: Object) -> bool:
	return lead() == book


## Where [param book] circles round a guard standing at [param guard]
## (world space): its place on the ring, at its own height over his feet.
func ring_slot(book: Object, guard: Vector3) -> Vector3:
	var standing := alive()
	var index := maxi(standing.find(book), 0)
	var n := maxi(standing.size(), 1)
	var angle := clock * RING_SPIN * spin_sign + TAU * index / float(n)
	var shade := fposmod(index * 0.618 + 0.25, 1.0)
	var radius := lerpf(RING_RADIUS.x, RING_RADIUS.y, shade) + (SPOOK_WIDEN if spooked() else 0.0)
	var height := lerpf(RING_HEIGHT.x, RING_HEIGHT.y, fposmod(index * 0.381 + 0.15, 1.0))
	return guard + Vector3(cos(angle) * radius, height, sin(angle) * radius)


## True when [param book] may start a dive's telegraph now.
func can_dive(book: Object) -> bool:
	if _diver != null and is_instance_valid(_diver) and _diver != book:
		return false
	if clock < _gap_until or spooked():
		return false
	var last: float = _last_dive.get(book.get_instance_id(), -INF)
	return clock - last >= OWN_COOLDOWN


## [param book] starts its telegraph: the others wait.
func begin_dive(book: Object) -> void:
	_diver = book
	_last_dive[book.get_instance_id()] = clock


## [param book]'s dive is over (struck and recovered, interrupted, gone).
func end_dive(book: Object) -> void:
	if _diver != book:
		return
	_diver = null
	_gap_until = clock + DIVE_GAP


## The book diving (or winding up) now, else null.
func diver() -> Object:
	return _diver if _diver != null and is_instance_valid(_diver) else null


func spooked() -> bool:
	return clock < _spooked_until


## A fright (a shot close by): the flock widens its ring and dives nobody
## for SPOOK_TIME.
func spook() -> void:
	_spooked_until = clock + SPOOK_TIME


## A book was shot down at [param point]: the flock is spooked, and the
## books within SCATTER_RADIUS fly off from there. Returns book -> push
## (m/s) for the caller to apply.
func scatter_from(point: Vector3, except: Object = null) -> Dictionary:
	_spooked_until = clock + SPOOK_TIME
	var pushes := {}
	for book in alive():
		if book == except:
			continue
		var away: Vector3 = (book as Node3D).global_position - point
		if away.length() > SCATTER_RADIUS:
			continue
		var flat := Vector3(away.x, 0.0, away.z)
		if flat.length() < 0.05:
			flat = Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0))
		pushes[book] = (flat.normalized() + Vector3.UP * 0.45).normalized() * SCATTER_SPEED
	return pushes


## The others' wake-up delays when [param first] woke: book -> seconds,
## nearest first, WAKE_STAGGER apart (only the books given in
## [param sleeping]).
func wake_delays(first: Object, sleeping: Array) -> Dictionary:
	var from: Vector3 = (first as Node3D).global_position
	var order := sleeping.duplicate()
	order.erase(first)
	order.sort_custom(func(a: Object, b: Object) -> bool:
		return (a as Node3D).global_position.distance_squared_to(from) < (b as Node3D).global_position.distance_squared_to(from))
	var delays := {}
	for i in order.size():
		delays[order[i]] = WAKE_STAGGER * (i + 1)
	return delays


## Where [param book] sleeps (world space); finds the flock's shelf (or
## floor) the first time it is asked, with [param cast] (a ray: from, to ->
## {"position", "normal"} or {}).
func perch_of(book: Object, cast: Callable) -> Transform3D:
	if perches_found.is_empty():
		var standing := members.filter(func(b: Object) -> bool: return is_instance_valid(b))
		var spots := perches(center, standing.size(), cast)
		for i in standing.size():
			perches_found[standing[i].get_instance_id()] = spots[i]
	return perches_found.get(book.get_instance_id(), Transform3D(Basis.IDENTITY, center + Vector3.UP * SHELF_HEIGHT))


## [param count] places to sleep round [param at] (a slot on the floor):
## on the nearest wall within SHELF_REACH at SHELF_HEIGHT - closed books
## standing in a row, spines (their +Z) to the room - or, without one, a
## stack on the floor. [param cast]: from, to -> {"position", "normal"}
## or {} (a ray against the level).
static func perches(at: Vector3, count: int, cast: Callable) -> Array[Transform3D]:
	var from := at + Vector3.UP * SHELF_HEIGHT
	var best := {}
	var best_distance := INF
	for k in 8:
		var angle := TAU * k / 8.0
		var hit: Dictionary = cast.call(from, from + Vector3(cos(angle), 0.0, sin(angle)) * SHELF_REACH)
		if hit.is_empty():
			continue
		var normal: Vector3 = hit["normal"]
		if absf(normal.y) > SHELF_STEEP:
			continue
		var distance := from.distance_to(hit["position"])
		if distance < best_distance:
			best_distance = distance
			best = hit
	var spots: Array[Transform3D] = []
	if best.is_empty():
		for i in count:
			var turn := Basis(Vector3.UP, 0.35 * sin(i * 2.3)) * Basis(Vector3.BACK, PI * 0.5)
			spots.append(Transform3D(turn, at + Vector3.UP * (STACK_BASE + STACK_STEP * i)))
		return spots
	var out := Vector3(best["normal"].x, 0.0, best["normal"].z).normalized()
	var along := Vector3.UP.cross(out)
	var face: Vector3 = best["position"]
	var row := Vector3(face.x, from.y, face.z) + out * SHELF_OFFSET
	var facing := Basis.looking_at(-out, Vector3.UP)
	for i in count:
		spots.append(Transform3D(facing, row + along * SHELF_SPACING * (i - (count - 1) * 0.5)))
	return spots
