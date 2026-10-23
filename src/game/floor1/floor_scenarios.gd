class_name FloorScenarios
extends Node
## Plays tonight's room scenarios (plan 2026-10-22-projekt-starc, backlog
## #20): ScenarioCatalog says what, ScenarioCast who. Every CHECK seconds:
## - a scenario not begun begins (its first beat) when the guard stands on
##   its start (or in one of its rooms),
## - a begun one plays its next beat when the first of the beat's triggers
##   holds: "after" seconds since the beat before (the clock runs only while
##   the guard is in its rooms or next door), "down" of the earlier beats'
##   cast fallen, the guard on its "area"; a "pickup" beat (and every beat
##   before it, in order) plays the moment the item is taken,
## - a beat: its cast stops waiting (Enemy.held off), the cue sounds and
##   dust rises at each of them (a bell may toll on its own: "ring"), and
##   "lead" seconds later (>= ScenarioCatalog.MIN_LEAD) they wake
##   (EnemyBrain.wake: they know where the guard is and hunt after their
##   suspicion).
## Nothing plays while a guardian or the T-Rex fights (the clocks stand
## too), once the night is over, or while the guard is dead. Each beat
## plays once a night (RunState.used "scn_<scenario>_<beat>"): a resumed
## night goes on from the first beat not played; the cast of the beats
## played sleeps as any exhibit (as a resumed ambush's).
## The cast of a beat still to come waits from the night's start: tune()
## puts it on the beat's waiting point (if any) and keeps it held
## (Enemy.held: deaf to noise and rousing neighbours, blind beyond the close
## sense), so the first shot does not fold the beats into one wave. A hit
## wakes it as ever.

signal beat_played(scenario: StringName, beat: StringName)

const CHECK := 0.2
const USED_PREFIX := "scn_"
const CUE_DB := -2.0
## No beat follows the one before sooner than this (s; a pickup the guard
## takes plays its beats at once): never two beats in one wave.
const MIN_GAP := 2.0
## Nearer than this a place in the guard's view counts as seen (a cast
## moved there unseen would show).
const UNSEEN := 30.0
const DUST := Color(0.62, 0.58, 0.5)


## One scenario playing tonight.
class Play:
	extends RefCounted
	var spec: Dictionary
	var id: StringName
	## Index of the next beat to play.
	var next: int = 0
	## Seconds since the last beat played (while the guard is near).
	var since: float = 0.0
	## Its rooms and the rooms next door.
	var near: Array[StringName] = []
	## Items taken that a beat waits for (or owned already: none lies tonight).
	var picked: Array[StringName] = []
	## Of the earlier beats' cast, how many had fallen when the last beat
	## played ("down" counts the falls since).
	var down_base: int = 0


var game: FloorGame
var museum: Museum
var layout: LevelLayout
var run: NightState
var cast: ScenarioCast
var plays: Array[Play] = []
## True while nothing may play (a guardian's or the T-Rex's fight); tests
## put their own.
var fight_check: Callable
## [seconds left, slots] of beats cued and not yet woken.
var _wakes: Array = []
var _left: float = 0.0


func setup(floor_game: FloorGame) -> void:
	game = floor_game
	museum = floor_game.museum
	layout = floor_game.level.layout
	run = museum.run
	name = "Scenarios"
	fight_check = game.blocks_rest
	if museum.night == null:
		cast = ScenarioCast.new()
		return
	cast = ScenarioCast.of(museum.night, layout)
	var catalog := ScenarioCatalog.active()
	for id in cast.playing:
		var play := Play.new()
		play.spec = catalog.find(id)
		if play.spec.is_empty():
			continue
		play.id = id
		play.near = ScenarioCatalog.neighbourhood(layout, play.spec["rooms"])
		var beats: Array = play.spec["beats"]
		while play.next < beats.size() and run.is_used(used_id(id, (beats[play.next] as Dictionary)["id"])):
			play.next += 1
		# an item the guard owns already lies nowhere tonight (a key item is
		# his for good): its beat plays as soon as the one before allows
		for beat: Dictionary in beats:
			if beat["pickup"] != &"" and not _pickup_lies(beat["pickup"]):
				play.picked.append(beat["pickup"])
		plays.append(play)
	if game.pickups != null:
		game.pickups.taken.connect(_on_pickup_taken)


## True while the pickup at [param marker] lies on the floor tonight.
func _pickup_lies(marker: StringName) -> bool:
	if museum.game.has_item(marker):
		return false
	if game.pickups == null:
		return false
	return game.pickups.items.has(marker) or game.pickups.weapons.has(marker) 			or game.pickups.weapons.has(StringName(String(marker).trim_prefix("weapon_")))


## True while ambush [param ambush_id], taken over by a scenario playing
## tonight, still waits for its beat (its sleepers may give themselves away:
## UncannyDirector's foreshadowing).
func ambush_waits(ambush_id: StringName) -> bool:
	for play in plays:
		var beats: Array = play.spec["beats"]
		for b in range(play.next, beats.size()):
			if (beats[b] as Dictionary)["ambush"] == ambush_id:
				return true
	return false


static func used_id(scenario: StringName, beat: StringName) -> StringName:
	return StringName("%s%s_%s" % [USED_PREFIX, String(scenario), String(beat)])


## Puts [param exhibit] where its beat wants it and holds it until then
## (before it enters the tree: Museum._tune_exhibit). A beat played earlier
## tonight leaves its cast as it is.
static func tune(exhibit: Enemy, night: NightConfig, floor_layout: LevelLayout, night_run: NightState) -> void:
	if not exhibit.has_meta(NightSpawner.SLOT_META):
		return
	var found := ScenarioCast.of(night, floor_layout)
	var slot := int(exhibit.get_meta(NightSpawner.SLOT_META))
	if not found.beat_of.has(slot):
		return
	var role: Array = found.beat_of[slot]
	var spec := ScenarioCatalog.active().find(role[0])
	if spec.is_empty():
		return
	var beat: Dictionary = (spec["beats"] as Array)[int(role[1])]
	if night_run != null and night_run.is_used(used_id(role[0], beat["id"])):
		return
	if found.staged.has(slot):
		exhibit.position = (found.staged[slot][0] as Vector3) + Vector3.UP * 0.05
		exhibit.rotation.y = float(found.staged[slot][1])
	if int(role[1]) > 0:
		exhibit.held = true


func _process(delta: float) -> void:
	_left -= delta
	if _left > 0.0:
		return
	advance(CHECK - _left)
	_left = CHECK


## False while nothing may play: the night is over, a guardian or the
## T-Rex fights, the guard is dead.
func clear() -> bool:
	if museum.night_over() or (fight_check.is_valid() and fight_check.call()):
		return false
	var guard := museum.player
	return is_instance_valid(guard) and guard.alive


## Plays what is due after [param delta] seconds.
func advance(delta: float) -> void:
	if not clear():
		return
	var guard := museum.player
	_wake_due(delta)
	var at := guard.global_position
	var here := layout.room_at(at + Vector3.UP * 0.5)
	for play in plays:
		var beats: Array = play.spec["beats"]
		if play.next >= beats.size():
			continue
		if play.next == 0:
			if _on_start(play, at, here):
				_play(play)
			continue
		if not play.near.has(here):
			continue
		play.since += delta
		var beat: Dictionary = beats[play.next]
		if _due(play, beat, at):
			_play(play)


## True once the guard stands where [param play] begins.
func _on_start(play: Play, at: Vector3, here: StringName) -> bool:
	var start: Rect2 = play.spec["start"]
	if start.size != Vector2.ZERO:
		return ScenarioCatalog.holds(start, play.spec["start_y"], at)
	return (play.spec["rooms"] as Array).has(here)


func _due(play: Play, beat: Dictionary, at: Vector3) -> bool:
	if play.since < MIN_GAP:
		return false
	if beat["pickup"] != &"" and play.picked.has(beat["pickup"]):
		return true
	if float(beat["after"]) >= 0.0 and play.since >= float(beat["after"]):
		return true
	if int(beat["down"]) >= 0 and fallen(cast.earlier(play.id, play.next)) - play.down_base >= int(beat["down"]):
		return true
	return ScenarioCatalog.holds(beat["area"], beat["area_y"], at)


## How many of [param slots] have no exhibit standing any more.
func fallen(slots: Array[int]) -> int:
	var standing := {}
	for exhibit in museum.exhibits():
		if exhibit.has_meta(NightSpawner.SLOT_META) and exhibit.brain.state != EnemyBrain.State.DESTROYED:
			standing[int(exhibit.get_meta(NightSpawner.SLOT_META))] = true
	var count := 0
	for slot in slots:
		if not standing.has(slot):
			count += 1
	return count


## The exhibits standing tonight on [param slots] (a pack: every member).
func cast_of(slots: Array[int]) -> Array[Enemy]:
	var found: Array[Enemy] = []
	for exhibit in museum.exhibits():
		if exhibit.has_meta(NightSpawner.SLOT_META) and slots.has(int(exhibit.get_meta(NightSpawner.SLOT_META))) \
				and exhibit.brain.state != EnemyBrain.State.DESTROYED:
			found.append(exhibit)
	return found


## Plays [param play]'s next beat.
func _play(play: Play) -> void:
	var beats: Array = play.spec["beats"]
	var index := play.next
	var beat: Dictionary = beats[index]
	play.next += 1
	play.since = 0.0
	# whoever of the cast so far fell before this beat does not count for the next one's "down"
	play.down_base = fallen(cast.earlier(play.id, play.next))
	run.mark_used(used_id(play.id, beat["id"]))
	if index == 0:
		_restage(play)
	var slots := cast.slots_of(play.id, index)
	for exhibit in cast_of(slots):
		exhibit.held = false
		if beat["cue"] != &"":
			Sfx.play_at(beat["cue"], exhibit.global_position + Vector3.UP * exhibit.eye_height, CUE_DB)
		Fx.puff(exhibit.global_position + Vector3.UP * 0.8, DUST, 18, 0.7)
	if beat["ring"] != &"":
		_ring(beat["ring"])
	if not slots.is_empty():
		_wakes.append([maxf(float(beat["lead"]), ScenarioCatalog.MIN_LEAD), slots])
	beat_played.emit(play.id, beat["id"])


## The scenario begins: the cast of a beat with other waiting points
## (also_from) moves to the one farthest from the guard - unseen: only
## while it still sleeps held, and neither where it stands nor where it
## goes lies in his view closer than UNSEEN.
func _restage(play: Play) -> void:
	var guard := museum.player
	var beats: Array = play.spec["beats"]
	for b in range(1, beats.size()):
		var beat: Dictionary = beats[b]
		if (beat["also_from"] as Array).is_empty():
			continue
		var best: StringName = beat["from"]
		var best_distance := -1.0
		for point_name: StringName in [beat["from"]] + (beat["also_from"] as Array):
			var at: Vector3 = (play.spec["points"][point_name] as Array)[0]
			var distance := at.distance_to(guard.global_position)
			if distance > best_distance:
				best = point_name
				best_distance = distance
		var point: Array = play.spec["points"][best]
		var exhibits := cast_of(cast.slots_of(play.id, b))
		for i in exhibits.size():
			var exhibit := exhibits[i]
			var side := Vector3(cos(float(point[1])), 0.0, -sin(float(point[1])))
			var to: Vector3 = (point[0] as Vector3) + side * 1.2 * i + Vector3.UP * 0.05
			if not exhibit.held or exhibit.brain.state != EnemyBrain.State.DORMANT or to.distance_to(exhibit.global_position) < 0.5:
				continue
			if _in_view(exhibit.global_position) or _in_view(to):
				continue
			exhibit.global_position = to
			exhibit.rotation.y = float(point[1])
			exhibit.home = to
			exhibit.home_yaw = float(point[1])
			exhibit.brain.home = to
			exhibit.reset_physics_interpolation()


## True when the guard could see [param point] (a body's middle over it):
## near enough, in his camera's frustum and nothing solid between.
func _in_view(point: Vector3) -> bool:
	var camera := museum.player.camera
	var middle := point + Vector3.UP
	if camera == null or middle.distance_to(camera.global_position) > UNSEEN or not camera.is_position_in_frustum(middle):
		return false
	var query := PhysicsRayQueryParameters3D.create(camera.global_position, middle, Layers.WORLD)
	return museum.get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _wake_due(delta: float) -> void:
	for entry: Array in _wakes.duplicate():
		entry[0] = float(entry[0]) - delta
		if float(entry[0]) > 0.0:
			continue
		_wakes.erase(entry)
		for exhibit in cast_of(entry[1]):
			if not exhibit.is_frozen():
				exhibit.held = false
				exhibit.brain.wake()


## Beats cued whose cast is still to wake.
func waking() -> int:
	return _wakes.size()


func _ring(bell_id: StringName) -> void:
	if game.biomes == null:
		return
	for device in game.biomes.devices:
		if device.device_id == bell_id and device is TempleBell:
			(device as TempleBell).ring()
			return


func _on_pickup_taken(marker: StringName) -> void:
	for play in plays:
		var beats: Array = play.spec["beats"]
		var target := -1
		for b in range(play.next, beats.size()):
			if (beats[b] as Dictionary)["pickup"] == marker:
				target = b
				break
		if target < 0:
			continue
		play.picked.append(marker)
		# the item is the scenario's own moment: every beat up to it plays now,
		# in order - unless nothing may play now (a fight, the night over):
		# then its beats follow one by one once it may (_due)
		if not clear():
			continue
		while play.next <= target:
			_play(play)
