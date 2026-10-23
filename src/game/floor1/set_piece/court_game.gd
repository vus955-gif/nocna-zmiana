class_name CourtGame
extends Node
## The Great Court's set-piece (plan 2026-10-22-set-piece; backlog #36,
## #56): "Grandmother's footsteps" ("Baba Jaga patrzy") over the whole hall.
## The UncannyDirector starts it (effect "set_piece") with the guard on the
## court's floor in a quiet moment and drives it with advance():
## - warn: the System's loudspeakers click on together, the hall's lamps
##   stutter; nothing moves (WARN_TIME),
## - three times dark (the lamps out with their fittings - the moon through
##   the glass roof and the red lamps stay) and light again: in the dark
##   each wax figure asleep on the court's floor that the guard does not
##   watch (Enemy.guard_watching: his picture and its margin) takes a step
##   his way along the walk mesh - never nearer than it could see him asleep
##   in full light (keep_of), so it wakes nobody; a bust only turns his way;
##   the ones he watches stand still,
## - from the WIN_FROM-th dark on, one figure that is as near as it may come
##   and still not watched reaches him: it stands WIN_STAND behind him when
##   the light comes back, sleeping soundly, and WIN_WARN later calls out and
##   comes for him (rouse: quietly, it wakes nobody) - the game ends there;
##   a plain fight with one wax figure follows,
## - end: the light back, the loudspeakers click off; the figures sleep on
##   where they stand (real threats, as a sleeper turned); none came: the
##   guard's thought, once a game.
## It stops at once, every lamp back, when the guard leaves the court's
## floor, shelters, dies, a fight starts (an exhibit hunting near him, a
## wing guardian or the T-Rex awake) or the night ends; stopped before its
## second dark it does not count as seen (it may come another night). No lock; nothing
## kept but the director's "seen once a game": a resumed night places the
## exhibits and lights the lamps afresh, so a game cut short is simply gone.

signal finished(why: StringName)

const ID := &"court_game"
const ROOM := &"court"
## The hall's lamps: the court's and the balcony's sconces on the drum.
const LAMP_ROOMS: Array[StringName] = [&"court", &"court_balcony"]
## Beats (s): the warning, each dark (RoomLamps "out" with its stutter back)
## and each light, DARKS darks.
const WARN_TIME := 1.6
const DARK_TIME := 2.0
const LIGHT_TIME := 2.4
const DARKS := 3
## In a dark the first step comes STEP_AFTER s in, then one every STEP_SPREAD
## s (all done before the lamps start to come back).
const STEP_AFTER := 0.3
const STEP_SPREAD := 0.09
## A figure's step along its way (m), and the figures that play: the
## nearest MAX_WALKERS wax figures and MAX_TURNERS busts within REACH m;
## fewer than MIN_WALKERS: no game.
const STEP := 8.0
const MAX_WALKERS := 6
const MAX_TURNERS := 4
const REACH := 45.0
const MIN_WALKERS := 3
## Nearest a figure comes: its sleeping sight in full light and this much
## beyond Enemy.STIR_SIGHT_MARGIN, never under KEEP_MIN (m).
const KEEP_MARGIN := 0.5
const KEEP_MIN := 6.0
## A step shorter than this is not taken (m); its way is tried every
## STEP_SAMPLE m.
const STEP_SHORTEST := 0.5
const STEP_SAMPLE := 0.5
## From this dark on one figure within WIN_NEAR of its keep and not watched
## reaches him: it stands WIN_STAND (m) from him, and calls out WIN_WARN s
## after the light is back (a telegraph of more than 0.6 s).
const WIN_FROM := 2
const WIN_NEAR := 1.0
const WIN_STAND := 3.0
const WIN_WARN := 0.8
## The winner sleeps soundly this long at most (s): it calls out first.
const WIN_SLEEP := 30.0
## Nothing stands in a doorway of the court or at its stairs (m round
## them), or nearer than SPACING to another exhibit.
const DOOR_CLEAR := 3.0
const STAIRS_CLEAR := 1.0
const SPACING := 1.0
## Sounds (existing Sfx; no noise for the exhibits' ears).
const CLICK_DB := -6.0
const HUM := &"relay"
const HUM_DB := -12.0
const DARK_SOUND := &"power_dead"
const DARK_DB := -8.0
const SCRAPE := &"relief_scrape"
const SCRAPE_DB := -14.0
const SCRAPE_PITCH := 1.2
const GRIND := &"bust_grind"
const GRIND_DB := -16.0
const GRIND_PITCH := 0.8
const WON_TEXT := "SETPIECE_COURT_GAME_WON"
const HINT_TIME := 4.5

var director: UncannyDirector
## Seconds since it started.
var time: float = 0.0
## [beat, seconds] as they came (tests, logs): warn, dark, light, wake, end.
var beats: Array = []
## Why it ended (&"" while it plays): done, or what stopped it (left,
## haven, fight, guard, night).
var reason: StringName = &""
var walkers: Array[Enemy] = []
var turners: Array[Enemy] = []
## The figure that reached him (null: none did).
var winner: Enemy = null
## Steps taken (a turn counts as none).
var steps: int = 0

## [seconds, beat] still to come.
var _schedule: Array = []
## Darks so far.
var _dark: int = 0
## [seconds, exhibit] steps waiting in this dark.
var _queue: Array = []
var _wake_at: float = INF
## With reduce_flashing: when this dark's lamps come back, all at once.
var _calm_back_at: float = INF
## Floor-plan rectangles no figure stops in (the doorways, the stairs).
var _blocked: Array[Rect2] = []
var _on_guardian := Callable()
var _on_boss := Callable()


func setup(for_director: UncannyDirector) -> void:
	name = "CourtGame"
	director = for_director
	var cast := cast_of(director)
	walkers.assign(cast[0])
	turners.assign(cast[1])
	var layout := director.layout
	for passage in layout.openings:
		if passage.room_a == ROOM or passage.room_b == ROOM:
			_blocked.append(passage.rect.grow(DOOR_CLEAR))
	for flight in layout.stairs:
		if flight.room_low == ROOM or flight.room_high == ROOM:
			_blocked.append(flight.rect.grow(STAIRS_CLEAR))
	var at := WARN_TIME
	_schedule.append([0.0, &"warn"])
	for i in DARKS:
		_schedule.append([at, &"dark"])
		at += DARK_TIME
		if i < DARKS - 1:
			_schedule.append([at, &"light"])
			at += LIGHT_TIME
	_schedule.append([at, &"end"])
	# a guardian or the T-Rex wakes: the game is over, every lamp back
	_on_guardian = _finish.bind(&"fight").unbind(2)
	_on_boss = _finish.bind(&"fight").unbind(1)
	Events.guardian_awakened.connect(_on_guardian)
	Events.boss_awakened.connect(_on_boss)
	_beats_due()


## Moves the game on by [param dt] seconds (the director's own time).
func advance(dt: float) -> void:
	if reason != &"":
		return
	time += dt
	var stop := _stop_reason()
	if stop != &"":
		_finish(stop)
		return
	_steps_due()
	if time >= _calm_back_at:
		_calm_back_at = INF
		_lamps_back()
	_beats_due()
	if reason == &"" and time >= _wake_at:
		_wake()


func is_over() -> bool:
	return reason != &""


# --- who plays, and may it start ---------------------------------------------------------

## The court's sleepers that play now: [walkers, turners] - asleep on the
## court's floor (kinds that stir in their sleep), not frozen, not called
## in, not waiting in an ambush, within REACH of the guard, nearest first.
static func cast_of(by: UncannyDirector) -> Array:
	var walking: Array[Enemy] = []
	var turning: Array[Enemy] = []
	var player := by.guard()
	if player == null:
		return [walking, turning]
	var waiting: Array[int] = []
	if by.floor_game != null and by.floor_game.encounters != null:
		for ambush in by.floor_game.encounters.waiting:
			waiting.append_array(ambush.slots)
	var found: Array = []
	for exhibit in by.museum.exhibits():
		if exhibit.brain.state != EnemyBrain.State.DORMANT or exhibit.is_frozen() or exhibit.summoned:
			continue
		var held: Variant = exhibit.get(&"held")   # held by an encounter of its room: it would not hunt
		if held is bool and held:
			continue
		if EnemyRoles.sleep(exhibit.kind()) != EnemyRoles.Sleep.STIR or exhibit.current_room() != ROOM:
			continue
		if exhibit.has_meta(Museum.SLOT_META) and waiting.has(int(exhibit.get_meta(Museum.SLOT_META))):
			continue
		var distance := flat(exhibit.global_position, player.global_position)
		if distance <= REACH:
			found.append([distance, exhibit])
	found.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	for item: Array in found:
		var exhibit: Enemy = item[1]
		if exhibit._stirs_in_place():
			if turning.size() < MAX_TURNERS:
				turning.append(exhibit)
		elif walking.size() < MAX_WALKERS:
			walking.append(exhibit)
	return [walking, turning]


## True when the game may start now (the director's moment aside): the
## guard on the court's floor, its lamps on, the finale untouched (or the
## T-Rex beaten on an earlier night) and at least MIN_WALKERS figures.
static func may_start(by: UncannyDirector) -> bool:
	var player := by.guard()
	if player == null or by.room != ROOM or by.lamps == null or by.lamps.count(ROOM) == 0:
		return false
	var finale := by.floor_game.finale if by.floor_game != null else null
	if finale != null:
		if finale.fighting():
			return false
		var beaten := by.game.is_guardian_defeated(FloorFinale.TREX) and finale.stage == FloorFinale.Stage.DONE
		if finale.stage != FloorFinale.Stage.ASTROLABE and not beaten:
			return false
	return (cast_of(by)[0] as Array).size() >= MIN_WALKERS


## Nearest [param exhibit] comes to the guard (m): beyond what it sees of
## him asleep in full light, the stir's margin and KEEP_MARGIN.
static func keep_of(exhibit: Enemy) -> float:
	var asleep := PerceptionRules.sight_range(1.0, exhibit.sight_range) * PerceptionWorld.sight_scale * PerceptionRules.DORMANT_SCALE
	return maxf(KEEP_MIN, asleep + Enemy.STIR_SIGHT_MARGIN + KEEP_MARGIN)


static func flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


# --- beats -------------------------------------------------------------------------------

func _beats_due() -> void:
	while reason == &"" and not _schedule.is_empty() and time >= float(_schedule[0][0]):
		var beat: StringName = _schedule.pop_front()[1]
		match beat:
			&"warn":
				beats.append([beat, time])
				if not Flashing.on():
					_play_lamps(&"flicker", WARN_TIME)   # (reduce_flashing: steady - the clicks, the hum and the thought warn)
				_clicks(&"radio_click_in")
				_sound(HUM, _guard_head(), HUM_DB)
			&"dark":
				_dark += 1
				beats.append([beat, time])
				_play_lamps(&"out", DARK_TIME)
				if Flashing.on():
					# both rooms back at once, before the outage's stutter: one change, no flashes
					_calm_back_at = time + DARK_TIME - RoomLamps._comeback_length()
				_sound(DARK_SOUND, _guard_head(), DARK_DB)
				_queue.clear()
				var at := time + STEP_AFTER
				for exhibit in walkers + turners:
					_queue.append([at, exhibit])
					at += STEP_SPREAD
			&"light", &"end":
				_queue.clear()
				_lamps_back()
				if winner != null and _wake_at == INF:
					beats.append([&"light", time])
					_wake_at = time + WIN_WARN
					_schedule.clear()   # it reached him: the game ends with its call
				elif beat == &"light":
					beats.append([beat, time])
				else:
					_finish(&"done")


func _steps_due() -> void:
	var next_beat: float = float(_schedule[0][0]) if not _schedule.is_empty() else INF
	while not _queue.is_empty() and time >= float(_queue[0][0]) and float(_queue[0][0]) < next_beat:
		var exhibit: Variant = _queue.pop_front()[1]
		if is_instance_valid(exhibit):
			_take_step(exhibit as Enemy)


## [param exhibit]'s move in this dark: watched, it stands still; a bust
## turns his way; a figure as near as it may comes the whole way (from the
## WIN_FROM-th dark, the first one only); else it steps his way.
func _take_step(exhibit: Enemy) -> void:
	if exhibit.brain.state != EnemyBrain.State.DORMANT or exhibit.is_frozen() or exhibit == winner:
		return
	if exhibit.guard_watching():
		return   # she looks: nobody moves
	var goal := director.guard().global_position
	var keep := keep_of(exhibit)
	var distance := flat(exhibit.global_position, goal)
	if turners.has(exhibit):
		if distance >= keep:
			exhibit.face(goal)
			_sound(GRIND, exhibit.global_position + Vector3.UP * 1.4, GRIND_DB, GRIND_PITCH)
		return
	if winner == null and _dark >= WIN_FROM and distance <= keep + WIN_NEAR:
		var reach := step_spot(exhibit, goal, WIN_STAND, INF)
		if reach != Vector3.INF:
			winner = exhibit
			exhibit.sound_asleep = WIN_SLEEP   # it calls out first: no seeing him meanwhile
			_place(exhibit, reach, goal)
		return
	if distance <= keep + STEP_SHORTEST:
		return   # as near as it may come
	var spot := step_spot(exhibit, goal, keep, STEP)
	if spot != Vector3.INF:
		_place(exhibit, spot, goal)


## Where [param exhibit] stops on its way to [param goal]: along its walk
## path at most [param most] m, never nearer than [param keep] (flat) to
## the goal, on a spot that fits (fits); Vector3.INF when none does or the
## step would be shorter than STEP_SHORTEST.
func step_spot(exhibit: Enemy, goal: Vector3, keep: float, most: float) -> Vector3:
	var path := _path(exhibit, goal)
	var candidates: Array[Vector3] = []
	var travel := STEP_SAMPLE
	var length := _length(path)
	while travel <= minf(most, length) + 0.001:
		var point := along(path, travel)
		if flat(point, goal) < keep:
			break
		candidates.append(point)
		travel += STEP_SAMPLE
	for i in range(candidates.size() - 1, -1, -1):
		if flat(candidates[i], exhibit.global_position) < STEP_SHORTEST:
			break
		var spot := _fit(exhibit, candidates[i], goal, keep)
		if spot != Vector3.INF:
			return spot
	return Vector3.INF


## The point [param travel] m along [param path] (its end when shorter).
static func along(path: PackedVector3Array, travel: float) -> Vector3:
	var left := travel
	for i in range(1, path.size()):
		var leg := path[i] - path[i - 1]
		var size := Vector2(leg.x, leg.z).length()
		if left <= size and size > 0.0:
			return path[i - 1] + leg * (left / size)
		left -= size
	return path[path.size() - 1] if not path.is_empty() else Vector3.ZERO


static func _length(path: PackedVector3Array) -> float:
	var total := 0.0
	for i in range(1, path.size()):
		total += Vector2(path[i].x - path[i - 1].x, path[i].z - path[i - 1].z).length()
	return total


## [param exhibit]'s way to [param goal] over the walk mesh (straight when
## the level has none yet).
func _path(exhibit: Enemy, goal: Vector3) -> PackedVector3Array:
	var path := PackedVector3Array()
	if exhibit.nav != null and exhibit._map_has_regions():
		path = LevelNavigation.find_path(exhibit.nav.get_navigation_map(), exhibit.global_position, goal)
	if path.size() < 2:
		path = PackedVector3Array([exhibit.global_position, goal])
	return path


## [param point] put onto the walk mesh, if it fits a figure: on the court's
## floor, out of the havens, the doorways and the stairs, clear of the other
## exhibits, no nearer the guard than [param keep] (less a little for the
## snap); Vector3.INF when not.
func _fit(exhibit: Enemy, point: Vector3, goal: Vector3, keep: float) -> Vector3:
	var snapped: Variant = exhibit._safe_detour(point)
	if snapped == null:
		return Vector3.INF
	var spot := Vector3((snapped as Vector3).x, exhibit.global_position.y, (snapped as Vector3).z)
	if PerceptionWorld.has_rooms() and PerceptionWorld.room_at(spot) != ROOM:
		return Vector3.INF
	if Haven.shelters(spot) or flat(spot, goal) < keep - 0.3:
		return Vector3.INF
	for rect in _blocked:
		if rect.has_point(Vector2(spot.x, spot.z)):
			return Vector3.INF
	for other in director.museum.exhibits():
		if other != exhibit and flat(other.global_position, spot) < SPACING:
			return Vector3.INF
	return spot


func _place(exhibit: Enemy, spot: Vector3, goal: Vector3) -> void:
	exhibit.end_doze()
	exhibit.global_position = spot
	exhibit.velocity = Vector3.ZERO
	exhibit.face(goal)
	exhibit.reset_physics_interpolation()
	steps += 1
	_sound(SCRAPE, spot + Vector3.UP * 0.2, SCRAPE_DB, SCRAPE_PITCH)


## The winner calls out and comes for him - the game is over.
func _wake() -> void:
	_wake_at = INF
	beats.append([&"wake", time])
	if is_instance_valid(winner) and winner.brain.state == EnemyBrain.State.DORMANT and not winner.is_frozen():
		winner.sound_asleep = 0.0
		winner.face(director.guard().global_position)
		Sfx.play_at(winner.notice_sound, winner.global_position, Enemy.NOTICE_DB)
		winner.rouse(director.guard().global_position)
	_finish(&"done")


## Over (done, or stopped [param why]): every lamp back, the loudspeakers
## off; nothing moves any more.
func _finish(why: StringName) -> void:
	if reason != &"":
		return
	reason = why
	_queue.clear()
	_schedule.clear()
	_wake_at = INF
	beats.append([&"end", time])
	_lamps_back()
	_clicks(&"radio_click_out")
	if why == &"done" and winner == null:
		_won_thought()
	elif why != &"done" and is_instance_valid(winner) and winner.sound_asleep > 0.0:
		winner.sound_asleep = minf(winner.sound_asleep, 5.0)
	if why != &"done" and _dark < WIN_FROM:
		_forget()
	if _on_guardian.is_valid() and Events.guardian_awakened.is_connected(_on_guardian):
		Events.guardian_awakened.disconnect(_on_guardian)
	if _on_boss.is_valid() and Events.boss_awakened.is_connected(_on_boss):
		Events.boss_awakened.disconnect(_on_boss)
	finished.emit(why)


## Cut short before its WIN_FROM-th dark (he walked on through the hall,
## a fight, the dawn): the game is not counted as seen once a game, so it
## may come on a later night (tonight's own limit stays), its thought too.
func _forget() -> void:
	var seen: Array[StringName] = director.game.uncanny_seen
	seen.erase(ID)
	seen.erase(StringName(UncannyRules.TEXT_PREFIX + String(ID)))


## What stops the game now (&"" for nothing).
func _stop_reason() -> StringName:
	var player := director.guard()
	if player == null or not player.alive:
		return &"guard"
	var museum := director.museum
	if museum.night_over() or (museum.watch != null and not museum.watch.running):
		return &"night"
	if director.room != ROOM:
		return &"left"
	if Haven.shelters(player.global_position):
		return &"haven"
	if director.floor_game.blocks_rest() or PerceptionWorld.hunters_near(player.global_position) > 0:
		return &"fight"
	return &""


# --- lamps, sounds, the thought ---------------------------------------------------------

func _play_lamps(mode: StringName, duration: float) -> void:
	for room in LAMP_ROOMS:
		director.lamps.stop(room)
		director.lamps.play(room, mode, duration, _guard_head())


func _lamps_back() -> void:
	if director.lamps == null:
		return
	for room in LAMP_ROOMS:
		director.lamps.stop(room)


## [param sound] from every loudspeaker of the court.
func _clicks(sound: StringName) -> void:
	var layout := director.layout
	for speaker in UncannyRules.loudspeakers(layout, ROOM):
		Sfx.play_at(sound, (layout.markers[speaker] as Transform3D).origin, CLICK_DB)


func _sound(sound: StringName, at: Vector3, volume: float, pitch: float = 1.0) -> void:
	if at != Vector3.INF:
		UncannyEffects.sound(sound, at, volume, pitch)


func _guard_head() -> Vector3:
	var player := director.guard()
	return player.global_position + Vector3.UP * 1.5 if player != null else Vector3.INF


func _won_thought() -> void:
	var hud := director.museum.hud
	if hud != null and director.game.see_uncanny(StringName(UncannyRules.TEXT_PREFIX + String(ID) + "_won")):
		hud.show_hint(tr(WON_TEXT), HINT_TIME)
