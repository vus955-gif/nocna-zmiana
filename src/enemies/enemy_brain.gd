class_name EnemyBrain
extends RefCounted
## Exhibit state machine (pure logic; design pietro-1-projekt 7.2). The
## Enemy node fills the context fields and calls update() every physics
## frame, then moves the body as the state says.
## - DORMANT (asleep as an exhibit) or PATROL (awake on its route) ->
##   SUSPICIOUS (turns to what it noticed, eyes flare; reaction_time) ->
##   HUNT when it saw the guard, INVESTIGATE when it only heard something.
## - HUNT knows where the guard is while it sees him and MEMORY seconds
##   after (following him at most EXTRAPOLATE metres past where it last saw
##   him); then SEARCH: it walks to that point, looks around SEARCH_TIME,
##   and RETURNs home (to sleep, or back to its patrol).
## - HUNT -> ATTACK (windup, strike, recovery) -> HUNT.
## - Leaving its bounds (territory, leash) sends it RETURNing; a guard in a
##   haven gets HAVEN_SEARCH seconds at the door, then it goes home.
## - The hunter cap (may_hunt) turns a would-be hunter into one waiting at
##   WAIT_EDGE metres (INVESTIGATE).
## - STUNNED interrupts anything and ends in a hunt; DESTROYED is final.
## - relentless (summoned by the boss): always knows where the guard is,
##   never searches, never goes home.
## - Calm routines (backlog #8): a PATROL with posts (patrol_dwell /
##   patrol_yaw: it holds each point for its dwell, facing the post's way)
##   or, without a route, a wander round its post (roam_radius, each place
##   passed through roam_filter). FLEE (a blast): it runs FLEE_DISTANCE from
##   the point, deaf to everything, then goes home.

signal state_changed(from: State, to: State)
## The damage moment of an attack (end of the windup).
signal strike

enum State { DORMANT, SUSPICIOUS, INVESTIGATE, HUNT, SEARCH, RETURN, PATROL, ATTACK, STUNNED, DESTROYED, FLEE }

## Seconds the guard's position stays known after losing sight of him...
const MEMORY := 1.5
## ...and how far past the point where it last saw him it follows (m).
const EXTRAPOLATE := 5.0
## Seconds of looking around at the search point (random in this range).
const SEARCH_TIME := Vector2(6.0, 10.0)
## Seconds of searching at a haven's door before going home.
const HAVEN_SEARCH := 8.0
## Longest walks (s) before it settles for where it got to.
const INVESTIGATE_TRAVEL := 15.0
const SEARCH_TRAVEL := 10.0
const RETURN_TRAVEL := 40.0
const PATROL_TRAVEL := 20.0
## Arrived at a point this close (m, floor plan).
const ARRIVE := 1.2
## Stalled: less than STALL_DISTANCE metres of headway in STALL_TIME
## seconds counts as arrived (a wall, a ledge, a crowd in the way).
const STALL_TIME := 2.0
const STALL_DISTANCE := 0.5
## Looking around: a new spot this often (s), this far from the point (m).
const LOOK_INTERVAL := 2.5
const LOOK_RADIUS := 3.0
## Pause at each patrol point (s); turning to its post at home (s).
const PATROL_PAUSE := 1.5
const SETTLE_TIME := 0.8
## A hunter over the cap waits this far from the guard (m).
const WAIT_EDGE := 10.0
## Fleeing: how far from the point it runs (m) and how long at most (s).
const FLEE_DISTANCE := 8.0
const FLEE_TRAVEL := 4.0
## Wandering: a new place no nearer than this share of the roam radius,
## held for a pause in this range (s).
const ROAM_NEAR := 0.3
const ROAM_PAUSE := Vector2(2.0, 5.0)
## Walking pace per state, as a share of the exhibit's speed.
const PACE := {State.INVESTIGATE: 0.7, State.SEARCH: 0.55, State.RETURN: 0.6, State.PATROL: 0.45, State.FLEE: 1.0}

var state: State = State.DORMANT
## Seconds of suspicion before it acts (design: 0.6-1.0 s).
var reaction_time: float = 0.8
var attack_range: float = 1.6
var windup: float = 0.6
var recovery: float = 0.7

# --- context: the Enemy sets these before every update() ---
## Where the exhibit stands.
var position := Vector3.ZERO
## Where the guard is (used only while the brain may know it).
var guard := Vector3.ZERO
## The guard is inside a haven.
var guard_sheltered := false
## The exhibit stands outside its territory or beyond its leash.
var out_of_bounds := false
## The guard stands where the exhibit may follow him.
var guard_in_bounds := true
## The hunter cap leaves room for this exhibit to hunt.
var may_hunt := true
## Summoned: always knows the guard, no search, no way home.
var relentless := false

# --- memory ---
## Its post (where it sleeps or starts its patrol).
var home := Vector3.ZERO
## Patrol route (a loop); fewer than two points = it keeps its post.
var patrol := PackedVector3Array()
## How long it holds each point of its route (s; missing = PATROL_PAUSE)...
var patrol_dwell := PackedFloat32Array()
## ...and which way it faces there (world yaw; missing or NAN = none).
var patrol_yaw := PackedFloat32Array()
## Without a route: it wanders this far round its post (m; 0 = it stays).
var roam_radius: float = 0.0
## (point) -> the point to walk to (moved onto the floor), or null to
## reject it; invalid = every point is fine.
var roam_filter: Callable = Callable()
## Where it believes the guard is (or what it heard).
var last_known := Vector3.ZERO
## Where it last saw the guard.
var last_seen := Vector3.ZERO
## Where it walks now (INVESTIGATE, SEARCH, RETURN, PATROL).
var goal := Vector3.ZERO
## DORMANT or PATROL: what it goes back to.
var rest_state: State = State.DORMANT
## Woken by a neighbour: no call-out, wakes nobody (until it rests again).
var quiet := false
var rng := RandomNumberGenerator.new()
## Called first by every event from outside (wake, alarm, hear, flee, stun,
## destroy, interrupt, cut_recovery, a new route, start_patrol), before
## anything changes: a dozing exhibit catches up its sleep first
## (Enemy.end_doze).
var before_event: Callable = Callable()

var _timer: float = 0.0
var _struck: bool = false
var _memory: float = 0.0
## Saw the guard (or knows where he is): the suspicion ends in a hunt.
var _spotted := false
## After a suspicion without sight: go and look (false: only turn).
var _follow := true
## Over the hunter cap: waiting at the edge.
var _waiting := false
## Searching at a haven's door.
var _haven := false
## Searching: arrived, looking around.
var _looking := false
var _look_timer: float = 0.0
var _travel_time: float = 0.0
var _stall_from := Vector3.ZERO
var _stall_time: float = 0.0
var _patrol_index: int = 0
var _pause: float = 0.0
## The route point it holds now (-1 while walking).
var _at_point: int = -1
## Wandering: a place is chosen.
var _roaming := false
var _settling := false


func _init() -> void:
	rng.randomize()


# --- events ------------------------------------------------------------------

## The full alarm (a scripted wake, a summoned exhibit, an arena wave): it
## knows where the guard is and hunts after its suspicion.
func wake() -> void:
	_event()
	match state:
		State.DORMANT, State.PATROL, State.RETURN:
			_saw()
			_spotted = true
			_follow = true
			_enter(State.SUSPICIOUS)
		State.SUSPICIOUS:
			_saw()
			_spotted = true
			_follow = true
		State.INVESTIGATE, State.SEARCH:
			_saw()
			_enter_hunt()
		State.HUNT:
			_saw()
			_memory = MEMORY


## A hit (not a stun) from [param point]: it knows where it came from.
func alarm(point: Vector3) -> void:
	_event()
	match state:
		State.DORMANT, State.PATROL, State.RETURN, State.SUSPICIOUS:
			last_known = point
			last_seen = point
			_spotted = true
			_follow = true
			if state != State.SUSPICIOUS:
				_enter(State.SUSPICIOUS)
		State.INVESTIGATE, State.SEARCH:
			last_known = point
			last_seen = point
			_hunt_or_wait()
		State.HUNT:
			_memory = MEMORY


## A noise at [param point] (or a neighbour waking it). [param follow]:
## it may go and look; false when the point lies outside its bounds (it
## only turns its head).
func hear(point: Vector3, follow: bool = true) -> void:
	_event()
	match state:
		State.DORMANT, State.PATROL:
			last_known = point
			_spotted = false
			_follow = follow
			_pause = 0.0
			_at_point = -1
			_roaming = false
			_enter(State.SUSPICIOUS)
		State.SUSPICIOUS:
			if not _spotted:
				last_known = point
				_follow = _follow or follow
		State.RETURN:
			if follow:
				_investigate(point)
		State.INVESTIGATE:
			if follow and not _waiting:
				_investigate(point)
		State.SEARCH:
			if follow and not _haven:
				_investigate(point)


## Calls off an attack still winding up (a mummy whose bandages caught
## fire): back to the hunt. A struck attack runs its recovery on; other
## states are left alone.
func interrupt() -> void:
	_event()
	if state == State.ATTACK and not _struck:
		_enter_hunt()


## Shortens a struck attack's recovery to at most [param remaining]
## seconds (a charge that ended early: the run is over, only the skid and
## the turn-round are left). Other states are left alone.
func cut_recovery(remaining: float) -> void:
	_event()
	if state == State.ATTACK and _struck:
		_timer = minf(_timer, maxf(remaining, 0.0))


## A fright (a blast at [param from]): it runs FLEE_DISTANCE away from the
## point and then goes home. Not while attacking, stunned or destroyed;
## a hunter keeps hunting, and a relentless one (summoned into a fight:
## no home to go to) never runs.
func flee(from: Vector3) -> void:
	_event()
	if relentless:
		return
	match state:
		State.ATTACK, State.STUNNED, State.DESTROYED, State.HUNT, State.FLEE:
			return
	var away := Vector3(position.x - from.x, 0.0, position.z - from.z)
	away = away.normalized() if away.length() > 0.01 else Vector3.BACK
	_waiting = false
	_haven = false
	_settling = false
	_begin_walk(position + away * FLEE_DISTANCE)
	_enter(State.FLEE)


func stun(duration: float) -> void:
	_event()
	if state == State.DESTROYED or duration <= 0.0:
		return
	if state == State.STUNNED:
		_timer = maxf(_timer, duration)
		return
	_enter(State.STUNNED)
	_timer = duration


func destroy() -> void:
	_event()
	if state != State.DESTROYED:
		_enter(State.DESTROYED)


## A (new) route to patrol: from its first point, now if it patrols already.
func set_route(route: PackedVector3Array) -> void:
	_event()
	patrol = route
	patrol_dwell.clear()
	patrol_yaw.clear()
	_patrol_index = 0
	_pause = 0.0
	_at_point = -1
	_roaming = false
	if state == State.PATROL and route.size() >= 2:
		_begin_walk(route[0])


## Awake on its post: it rests by patrolling (its route, or standing guard).
func start_patrol() -> void:
	_event()
	rest_state = State.PATROL
	if state == State.DORMANT:
		_patrol_index = 0
		_pause = 0.0
		_at_point = -1
		_roaming = false
		_begin_walk(patrol[0] if not patrol.is_empty() else home)
		_enter(State.PATROL)


func _event() -> void:
	if before_event.is_valid():
		before_event.call()


# --- questions -----------------------------------------------------------------

func is_stunned() -> bool:
	return state == State.STUNNED


func has_struck() -> bool:
	return state == State.ATTACK and _struck


## Neither asleep nor destroyed.
func is_awake() -> bool:
	return state != State.DORMANT and state != State.DESTROYED


## On to the guard: hunting or attacking.
func is_hunting() -> bool:
	return state == State.HUNT or state == State.ATTACK


## Something is up: suspicious, investigating, hunting, searching (not a
## calm patrol or the walk home).
func is_alerted() -> bool:
	match state:
		State.SUSPICIOUS, State.INVESTIGATE, State.HUNT, State.SEARCH, State.ATTACK, State.STUNNED, State.FLEE:
			return true
	return false


## Up and about on its feet: hunting, attacking, investigating, searching,
## going home, patrolling or fleeing (the crowd keeps these apart).
func is_active() -> bool:
	match state:
		State.HUNT, State.ATTACK, State.INVESTIGATE, State.SEARCH, State.RETURN, State.PATROL, State.FLEE:
			return true
	return false


## Calm and awake on its post or its round (its routine runs).
func is_calm() -> bool:
	return state == State.PATROL


## True while it may use the guard's real position: hunting within its
## memory (or relentless), or suspicious of what it saw.
func knows_guard() -> bool:
	match state:
		State.HUNT, State.ATTACK:
			return relentless or _memory > 0.0
		State.SUSPICIOUS:
			return _spotted
	return false


## It saw the guard (or was alarmed): its suspicion ends in a hunt.
func spotted() -> bool:
	return _spotted


## Over the hunter cap: it has seen the guard and waits at the edge.
func waiting() -> bool:
	return _waiting


## Walking toward [member goal] (else standing: looking, pausing, settling).
func walking() -> bool:
	match state:
		State.INVESTIGATE:
			return not _waiting or _flat(position, goal) > ARRIVE
		State.SEARCH, State.FLEE:
			return true
		State.RETURN:
			return not _settling
		State.PATROL:
			if patrol.size() < 2:
				if roam_radius > 0.0:
					return _roaming and _pause <= 0.0
				return _flat(position, home) > ARRIVE
			return _pause <= 0.0
	return false


## Holding a post of its route: the world yaw to face there (NAN while
## walking, or when the post has no facing).
func post_yaw() -> float:
	if state != State.PATROL or _pause <= 0.0 or _at_point < 0 or _at_point >= patrol_yaw.size():
		return NAN
	return patrol_yaw[_at_point]


## Searching: arrived and looking around (turning to [member goal]).
func looking_around() -> bool:
	return state == State.SEARCH and _looking


## Back at its post, turning to face where it stood.
func settling() -> bool:
	return state == State.RETURN and _settling


## Walking pace as a share of the exhibit's speed.
func pace() -> float:
	return PACE.get(state, 1.0)


## 0..1 while winding up an attack (drives the telegraph), else 0.
func windup_progress() -> float:
	if state != State.ATTACK or _struck or windup <= 0.0:
		return 0.0
	return clampf(1.0 - _timer / windup, 0.0, 1.0)


# --- the step ------------------------------------------------------------------

func update(delta: float, sees_target: bool, distance: float) -> void:
	match state:
		State.DORMANT:
			if sees_target:
				_notice()
		State.PATROL:
			if sees_target:
				_notice()
			else:
				_patrol(delta)
		State.SUSPICIOUS:
			_suspect(delta, sees_target)
		State.INVESTIGATE:
			_investigating(delta, sees_target)
		State.HUNT:
			_hunt(delta, sees_target, distance)
		State.SEARCH:
			_searching(delta, sees_target)
		State.RETURN:
			_returning(delta, sees_target)
		State.FLEE:
			if _walk(delta, FLEE_TRAVEL):
				_go_home()
		State.ATTACK:
			_timer -= delta
			if not _struck and _timer <= 0.0:
				_struck = true
				_timer = recovery
				strike.emit()
			elif _struck and _timer <= 0.0:
				_enter_hunt()
		State.STUNNED:
			_timer -= delta
			if _timer <= 0.0:
				_enter_hunt()


func _notice() -> void:
	_saw()
	_spotted = true
	_follow = true
	_enter(State.SUSPICIOUS)


func _suspect(delta: float, sees_target: bool) -> void:
	_timer -= delta
	if sees_target:
		_spotted = true
		_saw()
	elif _spotted:
		last_known = _followed()   # its eyes follow what it saw
	if _spotted and guard_sheltered and not relentless:
		_search_haven()
	elif _timer <= 0.0:
		if _spotted:
			_hunt_or_wait()
		elif _follow:
			_investigate(last_known)
		else:
			_rest()


func _investigating(delta: float, sees_target: bool) -> void:
	if out_of_bounds and not relentless:
		_go_home()
	elif sees_target and guard_in_bounds and not guard_sheltered:
		_saw()
		_hunt_or_wait()
	elif _waiting:
		# lost sight of him while waiting: go and look where he was
		_investigate(last_known)
	elif _walk(delta, INVESTIGATE_TRAVEL):
		_search(last_known)


func _hunt(delta: float, sees_target: bool, distance: float) -> void:
	if sees_target:
		_memory = MEMORY
		_saw()
	elif relentless:
		_memory = MEMORY
		last_known = guard
	else:
		_memory -= delta
		if _memory > 0.0:
			last_known = _followed()
	if relentless:
		if distance <= attack_range:
			_enter(State.ATTACK)
	elif guard_sheltered:
		_search_haven()
	elif out_of_bounds:
		_go_home()
	elif _memory <= 0.0:
		_search(last_known)
	elif distance <= attack_range:
		_enter(State.ATTACK)


func _searching(delta: float, sees_target: bool) -> void:
	if out_of_bounds and not _haven:
		_go_home()
		return
	if sees_target and guard_in_bounds and not guard_sheltered:
		_saw()
		_hunt_or_wait()
		return
	if _haven:
		_timer -= delta
		if _timer <= 0.0:
			_go_home()
		return
	if not _looking:
		if _walk(delta, SEARCH_TRAVEL):
			_looking = true
			_timer = rng.randf_range(SEARCH_TIME.x, SEARCH_TIME.y)
			_look_timer = 0.0
		return
	_timer -= delta
	_look_timer -= delta
	if _timer <= 0.0:
		_go_home()
	elif _look_timer <= 0.0:
		_look_timer = LOOK_INTERVAL
		var angle := rng.randf() * TAU
		goal = last_known + Vector3(cos(angle), 0.0, sin(angle)) * rng.randf_range(1.0, LOOK_RADIUS)


func _returning(delta: float, sees_target: bool) -> void:
	if sees_target and guard_in_bounds and not out_of_bounds and not guard_sheltered:
		_saw()
		_hunt_or_wait()
		return
	if _settling:
		_timer -= delta
		if _timer <= 0.0:
			_rest()
	elif _walk(delta, RETURN_TRAVEL, false):
		_settling = true
		_timer = SETTLE_TIME


func _patrol(delta: float) -> void:
	if patrol.size() < 2:
		if roam_radius > 0.0:
			_roam(delta)
		else:
			goal = home
		return
	if _pause > 0.0:
		_pause -= delta
		if _pause <= 0.0:
			_at_point = -1
			_begin_walk(patrol[_patrol_index])
		return
	goal = patrol[_patrol_index]
	if _walk(delta, PATROL_TRAVEL):
		_at_point = _patrol_index
		_patrol_index = (_patrol_index + 1) % patrol.size()
		_pause = _dwell_of(_at_point)


## How long it holds route point [param index].
func _dwell_of(index: int) -> float:
	if index >= 0 and index < patrol_dwell.size():
		return maxf(patrol_dwell[index], 0.05)
	return PATROL_PAUSE


## Without a route: walks to a place round its post, pauses, picks another.
func _roam(delta: float) -> void:
	if _pause > 0.0:
		_pause -= delta
		if _pause <= 0.0:
			_roaming = false
		return
	if not _roaming:
		var place := _roam_place()
		if place == Vector3.INF:
			_pause = ROAM_PAUSE.x   # nowhere to go just now: wait and try again
			return
		_roaming = true
		_begin_walk(place)
		return
	if _walk(delta, PATROL_TRAVEL):
		_pause = rng.randf_range(ROAM_PAUSE.x, ROAM_PAUSE.y)


## A place within roam_radius of home (not too near it) that the filter
## accepts; Vector3.INF when none was found in a few tries.
func _roam_place() -> Vector3:
	for attempt in 6:
		var angle := rng.randf() * TAU
		var reach := rng.randf_range(roam_radius * ROAM_NEAR, roam_radius)
		var place := home + Vector3(cos(angle), 0.0, sin(angle)) * reach
		if not roam_filter.is_valid():
			return place
		var accepted: Variant = roam_filter.call(place)
		if accepted is Vector3:
			return accepted
	return Vector3.INF


# --- transitions ---------------------------------------------------------------

## It sees the guard (or knows exactly where he is) now.
func _saw() -> void:
	last_seen = guard
	last_known = guard


## Where it believes the guard went since it last saw him: toward where he
## is, at most EXTRAPOLATE metres from the last sighting.
func _followed() -> Vector3:
	return last_seen + (guard - last_seen).limit_length(EXTRAPOLATE)


func _hunt_or_wait() -> void:
	if may_hunt or relentless:
		_enter_hunt()
		return
	_waiting = true
	var away := Vector3(position.x - guard.x, 0.0, position.z - guard.z)
	away = away.normalized() if away.length() > 0.01 else Vector3.BACK
	goal = guard + away * WAIT_EDGE
	if state != State.INVESTIGATE:
		_begin_walk(goal)
		_enter(State.INVESTIGATE)


func _enter_hunt() -> void:
	_memory = MEMORY
	_waiting = false
	_haven = false
	_spotted = true
	_enter(State.HUNT)


func _investigate(point: Vector3) -> void:
	last_known = point
	_waiting = false
	_begin_walk(point)
	_enter(State.INVESTIGATE)


func _search(point: Vector3) -> void:
	last_known = point
	_haven = false
	_looking = false
	_begin_walk(point)
	_enter(State.SEARCH)


func _search_haven() -> void:
	_haven = true
	_looking = false
	_begin_walk(last_known)
	_enter(State.SEARCH)
	_timer = HAVEN_SEARCH


func _go_home() -> void:
	_settling = false
	_waiting = false
	_haven = false
	_begin_walk(_post())
	_enter(State.RETURN)


func _rest() -> void:
	_spotted = false
	_waiting = false
	_haven = false
	_settling = false
	quiet = false
	if rest_state == State.PATROL:
		_patrol_index = _nearest_patrol_point()
		_pause = 0.0
		_at_point = -1
		_roaming = false
		_begin_walk(patrol[_patrol_index] if not patrol.is_empty() else home)
		_enter(State.PATROL)
	else:
		_enter(State.DORMANT)


## Where it goes back to: its post, or the nearest point of its patrol.
func _post() -> Vector3:
	if rest_state == State.PATROL and patrol.size() >= 2:
		return patrol[_nearest_patrol_point()]
	return home


func _nearest_patrol_point() -> int:
	var best := 0
	for i in patrol.size():
		if _flat(position, patrol[i]) < _flat(position, patrol[best]):
			best = i
	return best


## Starts a walk to [param point] (resets the travel clock and the stall check).
func _begin_walk(point: Vector3) -> void:
	goal = point
	_travel_time = 0.0
	_stall_time = 0.0
	_stall_from = position


## One step of a walk to [member goal]: true once it arrived, ran out of
## [param limit] seconds, or (with [param stall_ends]) stalled.
func _walk(delta: float, limit: float, stall_ends: bool = true) -> bool:
	_travel_time += delta
	if _flat(position, goal) <= ARRIVE or _travel_time >= limit:
		return true
	if not stall_ends:
		return false
	_stall_time += delta
	if _stall_time >= STALL_TIME:
		var headway := _flat(position, _stall_from)
		_stall_from = position
		_stall_time = 0.0
		if headway < STALL_DISTANCE:
			return true
	return false


func _enter(next: State) -> void:
	var previous := state
	state = next
	_struck = false
	match next:
		State.SUSPICIOUS:
			_timer = reaction_time
		State.ATTACK:
			_timer = windup
		_:
			_timer = 0.0
	if previous != next:
		state_changed.emit(previous, next)


static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
