class_name UncannyDirector
extends Node
## The night's escalation on Floor I (plan 2026-10-21-eskalacja-nocy;
## backlog #34, #35, #28), installed by FloorGame. Plays the uncanny events
## of the table (UncannyCatalog) on the museum's own objects
## (UncannyEffects, RoomLamps, PaintingGaze):
## - ambient: the night's curve (NightEscalation) sets when the next one
##   comes and its phase which ones may (weights); played in the guard's
##   room or next door - only in a quiet moment: the guard alive, out of the
##   havens, nobody hunting near him, no fight with a wing guardian or the
##   T-Rex, a while after the last event (MIN_GAP); the lamps never play in
##   a room to fight in, and every lamp is put back the moment a guardian
##   or the T-Rex wakes,
## - enter: the guard walks into one of its rooms (the first that fits, in
##   the table's order; its delay later, in a quiet moment) - the
##   hand-made moments and the foreshadowing of real threats (an ambush
##   still waiting tonight, a wing guardian not beaten, the T-Rex),
## - return: a room the guard leaves may change behind his back (its
##   chance times the phase's), "away" seconds later, while he is elsewhere
##   and not looking, nobody hunting him, no fight on (the moments are
##   never part of a fight); he comes back first - it does not happen,
## - night: by nightfall a room visited on an earlier night has changed.
## Kept with the night (RunState.used, 2.3): the events with a limit fired
## tonight ("unc_<id>_<n>"), the changes of the world ("chg_<id>@<target>",
## made again at once when a night is resumed) and the night's changes
## drawn ("unc_drawn"); the moments once per game in GameState.uncanny_seen.
## The phase is announced (Events.night_phase_changed) when it changes and
## when the night starts or resumes; every event is announced
## (Events.uncanny_event: the voice director's hook for G3).

const TICK := 0.25
## Seconds of a resumed night before anything happens.
const RESUME_QUIET := 20.0
## Seconds between any two events.
const MIN_GAP := 8.0
## Seconds before an ambient event due in a wrong moment is tried again,
## and before trying when none fits where the guard is.
const RETRY := 3.0
const NOTHING_HERE := 5.0
## An "enter" event waits at most this long for a quiet moment.
const ENTER_PATIENCE := 12.0
## A change waits at most this long for the guard to look away.
const CHANGE_PATIENCE := 90.0
## A door slams only this far from the guard (m): never on him.
const SLAM_CLEARANCE := 4.0
const SLAM_REACH := 25.0
## Paintings within this far may look at the guard (m).
const GAZE_REACH := 16.0
## A far foreshadowing sound comes no further than this from the guard (m).
const EARSHOT := 30.0
## The guard sees a change being made within this far (m) in his view.
const VIEW_REACH := 45.0
const HINT_TIME := 4.5
## Room moments only for the guard standing in that room (the paintings'
## eyes, the clocks, its lamps); the foreshadowing carries further.
const HERE_EFFECTS: Array[StringName] = [&"gaze", &"clocks", &"lamps", &"set_piece"]
const TOMB_DUST := Vector3(0.0, 1.2, 0.0)

var museum: Museum
var floor_game: FloorGame
var layout: LevelLayout
var game: PersistentState
var run: NightState
var catalog: UncannyCatalog
var lamps: RoomLamps
## Seconds since 23:00 (the night's clock).
var clock: Callable = Callable()
var night: int = 1
var modifier: StringName = &"none"
## NightEscalation.Phase now (-1 before setup).
var phase: int = -1
## Every event fired so far tonight, in order (ids; tests and logs).
var fired: Array[StringName] = []
## The room the guard is in (as RoomTracker last said).
var room: StringName = &""
## Scales the chance of a room changing behind the guard's back (tests set
## 0 to have only the changes they ask for).
var chance_scale: float = 1.0
## The set-piece playing now (effect "set_piece"; plan 2026-10-22-set-piece),
## and the ones played tonight: {id, reason, beats, winner} (tests, logs).
var set_piece: CourtGame = null
var pieces: Array[Dictionary] = []

## Game seconds since setup (the night's own time: pauses with the game).
var _time: float = 0.0
var _left: float = 0.0
var _next_ambient: float = INF
var _last_event: float = -INF
var _quiet_until: float = 0.0
## "enter" events waiting their delay: [entry, room, at, since].
var _scheduled: Array = []
## Room -> {entry, target, due, toward, since}: a change waiting for the
## guard to be away long enough.
var _pending: Dictionary = {}
var _restored := false
var _rng := RandomNumberGenerator.new()
var _fair_cache: Dictionary = {}
var _dark_rooms: Array[StringName] = []
## Havens and the rooms of an arena: no lamp effect plays there.
var _no_lamp_rooms: Array[StringName] = []

static var _catalog_cache: UncannyCatalog = null


## The default table, read once per run of the game.
static func default_catalog() -> UncannyCatalog:
	if _catalog_cache == null:
		_catalog_cache = UncannyCatalog.load_default()
	return _catalog_cache


func setup(for_floor: FloorGame) -> void:
	name = "Uncanny"
	floor_game = for_floor
	museum = for_floor.museum
	layout = for_floor.level.layout
	game = museum.game
	run = museum.run
	catalog = default_catalog()
	night = game.night
	modifier = museum.night.modifier if museum.night != null else &"none"
	var seed_value := game.night_seed()
	_rng.seed = seed_value * 97 + 13
	clock = func() -> float: return museum.watch.clock.elapsed if museum.watch != null else 0.0
	lamps = RoomLamps.new()
	add_child(lamps)
	lamps.setup(for_floor.level.lights, seed_value)
	_dark_rooms = UncannyRules.dark_rooms(layout)
	_no_lamp_rooms = UncannyRules.excluded_rooms(layout)
	# a guardian or the T-Rex wakes: nothing of the lamps' play goes on into the fight
	Events.guardian_awakened.connect(_stop_lamps.unbind(2))
	Events.boss_awakened.connect(_stop_lamps.unbind(1))
	var resumed := run.is_used(UncannyRules.DRAWN)
	if not resumed:
		_draw_night_changes(seed_value)
		run.mark_used(UncannyRules.DRAWN)
	if resumed or run.time > 1.0:
		_quiet_until = RESUME_QUIET
		_next_ambient = RESUME_QUIET + NightEscalation.gap(NightEscalation.phase_at(float(clock.call())), night, modifier, _rng.randf())
	else:
		_next_ambient = NightEscalation.first_wait(night, modifier)
	phase = NightEscalation.phase_at(float(clock.call()))
	Events.night_phase_changed.emit(phase)
	if for_floor.rooms != null:
		room = for_floor.rooms.room
		for_floor.rooms.entered.connect(_on_room_entered)


func _process(delta: float) -> void:
	advance(delta)


## Moves the director's time on by [param dt] seconds (tests call it).
func advance(dt: float) -> void:
	_time += dt
	if set_piece != null:
		_advance_piece(dt)
	_left -= dt
	if _left > 0.0:
		return
	_left = TICK
	_tick()


func _tick() -> void:
	if not _restored:
		_restored = true
		_restore_changes()
	var now := NightEscalation.phase_at(float(clock.call()))
	if now != phase:
		phase = now
		Events.night_phase_changed.emit(phase)
	# the wings' mechanics follow the same curve (plan 2026-10-21-mechaniki-biomow)
	var biomes: Variant = floor_game.get("biomes") if floor_game != null else null
	if biomes != null:
		biomes.intensity = NightEscalation.intensity(float(clock.call()))
	if not _night_running():
		return
	_run_scheduled()
	_run_pending()
	if _time >= _next_ambient:
		_try_ambient()


# --- the moment ------------------------------------------------------------------------

func guard() -> Player:
	return museum.player if is_instance_valid(museum.player) else null


func _night_running() -> bool:
	var player := guard()
	if player == null or not player.alive or museum.night_over():
		return false
	return museum.watch == null or museum.watch.running


## A quiet moment for an event: out of the havens, nobody hunting the
## guard, no fight on, no set-piece playing, a while after the last event.
func is_quiet() -> bool:
	var player := guard()
	if player == null or set_piece != null or _time < _quiet_until or _time - _last_event < MIN_GAP:
		return false
	return not Haven.shelters(player.global_position) and not _fight_on(player)


## A fight is on: a wing guardian or the T-Rex fights, or an exhibit hunts
## the guard near.
func _fight_on(player: Player) -> bool:
	return floor_game.blocks_rest() or PerceptionWorld.hunters_near(player.global_position) > 0


func _stop_lamps() -> void:
	if lamps != null:
		lamps.stop_all()


func _try_ambient() -> void:
	if not is_quiet():
		_next_ambient = _time + RETRY
		return
	var candidates: Array[Dictionary] = []
	var targets := {}
	for entry in catalog.by_trigger(&"ambient"):
		if not _may(entry):
			continue
		var target := _target(entry, room)
		if not target.is_empty():
			candidates.append(entry)
			targets[entry["id"]] = target
	var chosen := UncannyRules.pick(candidates, phase, _rng.randf())
	if chosen.is_empty():
		_next_ambient = _time + NOTHING_HERE
		return
	_next_ambient = _time + NightEscalation.gap(phase, night, modifier, _rng.randf())
	if _rng.randf() < float(chosen.get("chance", 1.0)):
		_fire(chosen, targets[chosen["id"]])


## True when [param entry] may happen now: its phase, the night, its
## limits, the voice free when it wants it (VoiceDirector.is_free).
func _may(entry: Dictionary) -> bool:
	if not UncannyRules.in_phase(entry, phase) or not UncannyRules.fits_night(entry, night, modifier):
		return false
	if not UncannyRules.may_fire(entry, run.used, game.uncanny_seen):
		return false
	if bool(entry.get("quiet_voice", false)) and not VoiceDirector.is_free():
		return false
	return true


# --- enter -----------------------------------------------------------------------------

func _on_room_entered(entered: StringName, zone: StringName, _first_visit: bool) -> void:
	var from := room
	room = entered
	if _pending.has(entered):
		_pending.erase(entered)   # he came back before it could change
	if from != &"" and from != entered:
		_left_room(from, entered)
	for entry in catalog.by_trigger(&"enter"):
		var rooms := UncannyCatalog.names(entry, "rooms")
		var zones := UncannyCatalog.names(entry, "zones")
		if (not rooms.is_empty() and not rooms.has(entered)) or (not zones.is_empty() and not zones.has(zone)):
			continue
		if not _may(entry) or not _threat_waits(entry) or _is_scheduled(entry):
			continue
		if StringName(entry["effect"]) == &"set_piece" and not CourtGame.may_start(self):
			continue   # no game to play here now: the next moment of the room gets its turn
		if _rng.randf() >= float(entry.get("chance", 1.0)):
			continue
		_scheduled.append([entry, entered, _time + float(entry.get("delay", 0.0)), _time])
		return


func _is_scheduled(entry: Dictionary) -> bool:
	for item: Array in _scheduled:
		if item[0] == entry:
			return true
	return false


## The real threat [param entry] foreshadows is still to come (or it names
## none): its ambush waits tonight with sleepers, its guardian is not
## beaten nor awake, the T-Rex not beaten nor fighting.
func _threat_waits(entry: Dictionary) -> bool:
	if entry.has("ambush") and _ambush_sleepers(StringName(entry["ambush"])).is_empty():
		return false
	if entry.has("guardian"):
		var id := StringName(entry["guardian"])
		if game.is_guardian_defeated(id):
			return false
		var keeper := floor_game.guardians
		var standing: Variant = keeper.guardians.get(id) if keeper != null else null
		if standing != null and is_instance_valid(standing) and (standing as Guardian).is_fighting():
			return false
	if bool(entry.get("boss", false)):
		if game.is_guardian_defeated(FloorFinale.TREX):
			return false
		if floor_game.finale != null and floor_game.finale.stage >= FloorFinale.Stage.BOSS:
			return false
	return true


## The exhibits of [param ambush_id] still asleep tonight (none when it has
## sprung, or is no ambush), by slot.
func _ambush_sleepers(ambush_id: StringName) -> Array[Enemy]:
	var found: Array[Enemy] = []
	var ambush := layout.ambush(ambush_id)
	if ambush == null or floor_game.encounters == null:
		return found
	# (an ambush a room's scenario took over waits for its beat instead)
	if not floor_game.encounters.waiting.has(ambush) and not (floor_game.scenarios != null and floor_game.scenarios.ambush_waits(ambush_id)):
		return found
	for exhibit in museum.exhibits():
		if exhibit.has_meta(Museum.SLOT_META) and ambush.slots.has(int(exhibit.get_meta(Museum.SLOT_META))) \
				and exhibit.brain.state == EnemyBrain.State.DORMANT and not exhibit.is_frozen():
			found.append(exhibit)
	found.sort_custom(func(a: Enemy, b: Enemy) -> bool: return int(a.get_meta(Museum.SLOT_META)) < int(b.get_meta(Museum.SLOT_META)))
	return found


func _run_scheduled() -> void:
	for item: Array in _scheduled.duplicate():
		if _time < float(item[2]):
			continue
		if not is_quiet() or not _threat_waits(item[0]):
			if _time - float(item[3]) > ENTER_PATIENCE or not _threat_waits(item[0]):
				_scheduled.erase(item)
			continue
		_scheduled.erase(item)
		if HERE_EFFECTS.has(StringName(item[0]["effect"])) and room != item[1]:
			continue   # a moment of the room he has already left
		var target := _target(item[0], item[1])
		if not target.is_empty():
			_fire(item[0], target)


# --- targets ---------------------------------------------------------------------------

## Where and on what [param entry] would happen with the guard in
## [param in_room] ({} when it cannot: nothing there for it).
func _target(entry: Dictionary, in_room: StringName) -> Dictionary:
	var player := guard()
	if player == null or in_room == &"":
		return {}
	var here: StringName = in_room
	if StringName(entry.get("where", "here")) == &"near":
		var near := _near_rooms(in_room)
		if near.is_empty():
			return {}
		here = near[_rng.randi_range(0, near.size() - 1)]
	var target := {"room": here, "point": UncannyRules.room_point(layout, here)}
	if entry.has("marker") and layout.markers.has(StringName(entry["marker"])):
		target["point"] = (layout.markers[StringName(entry["marker"])] as Transform3D).origin + Vector3.UP * 1.2
	if entry.has("guardian"):
		var marker := StringName("guardian_%s" % entry["guardian"])
		if layout.markers.has(marker):
			target["point"] = (layout.markers[marker] as Transform3D).origin + Vector3.UP * 1.5
	if entry.has("ambush"):
		var ambush := layout.ambush(StringName(entry["ambush"]))
		if ambush != null:
			target["point"] = UncannyRules.ambush_point(layout, ambush)
	match StringName(entry["effect"]):
		&"lamps":
			if _no_lamp_rooms.has(here):
				return {}   # a room to fight in: its lamps are the fight's
			var mode := StringName(entry["mode"])
			var group := LightSpec.EMERGENCY if mode == &"exit" else LightSpec.MAIN
			if lamps.busy(here) or lamps.count(here, group) < maxi(1, int(entry.get("min_lamps", 1))):
				return {}
			if bool(entry.get("needs_emergency", false)) and lamps.count(here, LightSpec.EMERGENCY) == 0:
				return {}
		&"door_slam":
			var door := _door_to_slam(here)
			if door == null:
				return {}
			target["door"] = door
			target["point"] = door.global_position + Vector3.UP * 1.5
		&"pa_click":
			var speakers := UncannyRules.loudspeakers(layout, here)
			if speakers.is_empty():
				return {}
			target["point"] = (layout.markers[speakers[0]] as Transform3D).origin
		&"gaze":
			var paintings := _paintings_to_gaze(here, StringName(entry["trigger"]) == &"ambient")
			if paintings.is_empty():
				return {}
			target["paintings"] = paintings
		&"clocks":
			target["clocks"] = UncannyEffects.clockworks(floor_game.level, here)
		&"set_piece":
			if set_piece != null or here != room or not CourtGame.may_start(self):
				return {}
			target["point"] = player.global_position + Vector3.UP * 1.5
		&"tomb", &"dust", &"glint":
			var sleepers := _ambush_sleepers(StringName(entry.get("ambush", "")))
			if entry.has("ambush") and sleepers.is_empty():
				return {}
			if StringName(entry["effect"]) == &"tomb":
				for sleeper in sleepers:
					var mummy := sleeper as Mummy
					if mummy != null and mummy.tomb != null and mummy.in_tomb() and not mummy.tomb.is_open():
						target["tomb"] = mummy.tomb
						target["slot"] = int(mummy.get_meta(Museum.SLOT_META))
						target["point"] = mummy.tomb.global_transform * TOMB_DUST
						break
				if not target.has("tomb") and not entry.has("sound"):
					return {}   # no lid to lift and nothing to hear
			elif not sleepers.is_empty():
				target["point"] = sleepers[0].global_position + Vector3.UP * (1.75 if StringName(entry["effect"]) == &"glint" else 1.4)
	return target


## Rooms next to [param of] where something may sound: no haven, no secret.
func _near_rooms(of: StringName) -> Array[StringName]:
	var found: Array[StringName] = []
	for other in UncannyRules.neighbours(layout.graph(), of):
		var spec := layout.room(other)
		if spec != null and not spec.haven and not spec.secret:
			found.append(other)
	return found


## An open plain door of a room next to [param of] (the next room's: never
## one of the guard's own room), far enough from the guard, near enough to
## be heard and out of his sight - never one he walks toward (the nearest
## such).
func _door_to_slam(of: StringName) -> Door:
	var player := guard()
	var level := floor_game.level
	var best: Door = null
	var best_distance := INF
	var rooms := _near_rooms(of)
	for door: Door in level.doors.values():
		if not is_instance_valid(door) or door.link != RoomGraph.Kind.OPEN or layout.gate_of_opening(door.id) != null:
			continue
		if door.style != OpeningSpec.DoorStyle.SWING and door.style != OpeningSpec.DoorStyle.DOUBLE_SWING:
			continue
		if not door.is_open or door.locked or door.is_moving() or not (rooms.has(door.room_a) or rooms.has(door.room_b)):
			continue
		if door.room_a == of or door.room_b == of or door.room_a == room or door.room_b == room:
			continue
		var distance := door.global_position.distance_to(player.global_position)
		if distance < SLAM_CLEARANCE or distance > SLAM_REACH or distance >= best_distance:
			continue
		if _guard_sees(door.global_position + Vector3.UP * 1.2):
			continue   # behind his back: he hears it, turns, and it swings open again
		best = door
		best_distance = distance
	return best


## The plain paintings of [param of] with eyes to look ([param in_front]:
## only those the guard stands in front of, within GAZE_REACH), not the ones
## changed tonight.
func _paintings_to_gaze(of: StringName, in_front: bool) -> Array[WallPainting]:
	var player := guard()
	var found: Array[WallPainting] = []
	for spot in UncannyRules.painting_spots(layout, [of] as Array[StringName]):
		var painting := UncannyEffects.painting_at(museum.paintings_root, (layout.markers[spot] as Transform3D).origin)
		if painting == null or painting.has_meta(&"uncanny_changed") or not PaintingGaze.has_eyes(painting):
			continue
		var head := player.global_position + Vector3.UP * 1.5
		if in_front and (painting.global_position.distance_to(head) > GAZE_REACH or not PaintingGaze.in_front(painting, head)):
			continue
		found.append(painting)
	return found


# --- fire ------------------------------------------------------------------------------

func _fire(entry: Dictionary, target: Dictionary) -> void:
	var id := UncannyCatalog.id_of(entry)
	var where: StringName = target.get("room", room)
	var point: Vector3 = target.get("point", Vector3.INF)
	var player := guard()
	if point == Vector3.INF and player != null:
		point = player.global_position + Vector3.UP * 1.5
	var limit := UncannyCatalog.limit_of(entry)
	if limit > 0:
		run.mark_used(UncannyRules.fired_id(id, UncannyRules.fired_count(run.used, id) + 1))
	if bool(entry.get("once_per_game", false)):
		game.see_uncanny(id)
	fired.append(id)
	_last_event = _time
	var duration := float(entry.get("duration", 2.0))
	var volume := float(entry.get("volume", -8.0))
	var pitch := float(entry.get("pitch", 1.0))
	var sound_id := StringName(entry.get("sound", ""))
	var noise := float(entry.get("noise", 0.0)) * NightEscalation.noise_scale(phase)
	if (entry.has("ambush") or entry.has("guardian") or entry.has("marker")) and player != null:
		point = UncannyRules.within_earshot(point, player.global_position + Vector3.UP * 1.5, EARSHOT)
	match StringName(entry["effect"]):
		&"lamps":
			lamps.play(where, StringName(entry["mode"]), duration, player.global_position if player != null else Vector3.INF)
		&"door_slam":
			UncannyEffects.slam(target["door"])
		&"pa_click":
			Sfx.play_at(&"radio_click_in", point, -4.0)
			get_tree().create_timer(duration, false).timeout.connect(func() -> void: Sfx.play_at(&"radio_click_out", point, -4.0))
		&"radio":
			Sfx.play(&"radio_click_in", -6.0)
			get_tree().create_timer(duration, false).timeout.connect(func() -> void: Sfx.play(&"radio_click_out", -6.0))
		&"gaze":
			for painting: WallPainting in target["paintings"]:
				PaintingGaze.follow(painting, player, duration)
		&"clocks":
			var clocks: Array = target.get("clocks", [])
			for spinner: DecorSpinner in clocks:
				UncannyEffects.reverse_clock(spinner, true)
			get_tree().create_timer(duration, false).timeout.connect(func() -> void:
				for spinner: DecorSpinner in clocks:
					if is_instance_valid(spinner):
						UncannyEffects.reverse_clock(spinner, false))
		&"tomb":
			var tomb: MummyTomb = target.get("tomb")
			if tomb != null and UncannyEffects.set_ajar(tomb):
				run.mark_used(UncannyRules.change_id(id, str(target["slot"])))
				var grind := &"portrait_creak" if tomb.style == MummyMoves.Tomb.COFFIN else &"lock_seal_grind"
				UncannyEffects.sound(grind, point, -14.0, 0.8)
				UncannyEffects.dust(point)
		&"dust":
			UncannyEffects.dust(point)
		&"glint":
			UncannyEffects.glint(point)
		&"set_piece":
			_start_piece()
	if entry.has("lamps"):
		lamps.play(where, StringName(entry["lamps"]), duration, player.global_position if player != null else Vector3.INF)
	if sound_id != &"" or noise > 0.0:
		UncannyEffects.sound(sound_id, point, volume, pitch, noise)
	_show_text(entry)
	Events.uncanny_event.emit(id, where)


## The guard's rare thought (once per game for each event).
func _show_text(entry: Dictionary) -> void:
	if not entry.has("text") or museum.hud == null:
		return
	if game.see_uncanny(StringName(UncannyRules.TEXT_PREFIX + String(entry["id"]))):
		museum.hud.show_hint(tr(String(entry["text"])), HINT_TIME)


# --- set-pieces (plan 2026-10-22-set-piece) -----------------------------------------------

## The Great Court's game starts (its own node under the director: it goes
## with the director, the night or the museum freed).
func _start_piece() -> void:
	set_piece = CourtGame.new()
	add_child(set_piece)
	set_piece.setup(self)


func _advance_piece(dt: float) -> void:
	set_piece.advance(dt)
	if not set_piece.is_over():
		return
	pieces.append({"id": CourtGame.ID, "reason": set_piece.reason, "beats": set_piece.beats.duplicate(), "winner": set_piece.winner})
	_last_event = _time   # the next uncanny moment a while after its end
	set_piece.queue_free()
	set_piece = null


# --- changes of the world --------------------------------------------------------------

## The guard left [param from] for [param to]: a change may wait for him
## to be away long enough.
func _left_room(from: StringName, to: StringName) -> void:
	if _pending.has(from):
		return
	var toward := _passage_point(from, to)
	var options: Array = []
	for entry in catalog.by_trigger(&"return"):
		if not _may(entry):
			continue
		var target := _change_target(entry, from, toward)
		if not target.is_empty():
			options.append([entry, target])
	if options.is_empty():
		return
	var chosen: Array = options[_rng.randi_range(0, options.size() - 1)]
	var entry: Dictionary = chosen[0]
	if _rng.randf() >= float(entry.get("chance", 1.0)) * NightEscalation.change_scale(phase) * chance_scale:
		return
	_pending[from] = {"entry": entry, "target": chosen[1], "due": _time + float(entry.get("away", 45.0)), "toward": toward, "since": _time}


## What [param entry] would change in [param in_room] ({} for nothing).
func _change_target(entry: Dictionary, in_room: StringName, toward: Vector3) -> Dictionary:
	var rooms := UncannyCatalog.names(entry, "rooms")
	if not rooms.is_empty() and not rooms.has(in_room):
		return {}
	var id := UncannyCatalog.id_of(entry)
	match StringName(entry["effect"]):
		&"hide", &"turn":
			var free: Array[int] = []
			for index in _fair_pieces(entry):
				if layout.pieces[index].room == in_room and not _piece_changed(index):
					free.append(index)
			if free.is_empty():
				return {}
			var index: int = free[_rng.randi_range(0, free.size() - 1)]
			var quarters := 2
			if StringName(entry["effect"]) == &"turn":
				quarters = roundi(UncannyEffects.turn_angle(layout.pieces[index], toward) / (PI * 0.5))
			return {"target": "%d:%d" % [index, quarters], "point": layout.pieces[index].position + Vector3.UP}
		&"sitter", &"look":
			var spots: Array[StringName] = []
			for spot in UncannyRules.painting_spots(layout, [in_room] as Array[StringName]):
				var painting := UncannyEffects.painting_at(museum.paintings_root, (layout.markers[spot] as Transform3D).origin)
				if painting != null and not painting.has_meta(&"uncanny_changed") and (StringName(entry["effect"]) == &"sitter" or PaintingGaze.has_eyes(painting)):
					spots.append(spot)
			if spots.is_empty():
				return {}
			var spot := spots[_rng.randi_range(0, spots.size() - 1)]
			return {"target": String(spot), "point": (layout.markers[spot] as Transform3D).origin}
		&"sleeper":
			if run.is_used(UncannyRules.change_id(id, String(in_room))):
				return {}   # once a room, a resumed night too
			var kinds := UncannyCatalog.names(entry, "kinds")
			var sleepers: Array[Enemy] = []
			for exhibit in museum.exhibits():
				if exhibit.brain.state == EnemyBrain.State.DORMANT and not exhibit.is_frozen() and exhibit.home_room == in_room \
						and kinds.has(EnemyRoles.kind_of(exhibit)):
					sleepers.append(exhibit)
			if sleepers.is_empty():
				return {}
			var chosen := sleepers[_rng.randi_range(0, sleepers.size() - 1)]
			return {"exhibit": chosen, "target": in_room, "point": chosen.global_position + Vector3.UP}
		&"dark":
			if not _dark_rooms.has(in_room) or lamps.count(in_room) == 0 or run.is_used(UncannyRules.change_id(id, String(in_room))):
				return {}
			return {"target": String(in_room), "point": UncannyRules.room_point(layout, in_room)}
	return {}


func _fair_pieces(entry: Dictionary) -> Array[int]:
	var id := String(entry["id"])
	if not _fair_cache.has(id):
		_fair_cache[id] = UncannyRules.fair_pieces(layout, entry)
	return _fair_cache[id]


func _piece_changed(index: int) -> bool:
	for change: Array in UncannyRules.changes(run.used):
		if String(change[1]).get_slice(":", 0) == str(index):
			return true
	return false


## The middle of the passage (or flight) between [param a] and [param b],
## else [param b]'s middle.
func _passage_point(a: StringName, b: StringName) -> Vector3:
	for passage in layout.openings:
		if (passage.room_a == a and passage.room_b == b) or (passage.room_a == b and passage.room_b == a):
			var middle := passage.rect.get_center()
			return Vector3(middle.x, passage.floor_y + 1.2, middle.y)
	for flight in layout.stairs:
		if (flight.room_low == a and flight.room_high == b) or (flight.room_low == b and flight.room_high == a):
			var middle := flight.rect.get_center()
			return Vector3(middle.x, layout.room(a).floor_y + 1.2 if layout.room(a) != null else 0.0, middle.y)
	return UncannyRules.room_point(layout, b)


func _run_pending() -> void:
	for at: StringName in _pending.keys():
		var waiting: Dictionary = _pending[at]
		if _time < float(waiting["due"]):
			continue
		if at == room:
			_pending.erase(at)
			continue
		var target: Dictionary = waiting["target"]
		var hidden := not _guard_sees(target.get("point", Vector3.INF))
		if StringName(waiting["entry"]["effect"]) == &"dark":
			hidden = hidden and not _near_rooms(at).has(room)
		if not hidden or _fight_on(guard()):
			if _time - float(waiting["due"]) > CHANGE_PATIENCE:
				_pending.erase(at)
			continue
		_pending.erase(at)
		_make_change(waiting["entry"], target, waiting["toward"], at)


## True when the guard could see [param point] now: near enough and within
## his camera's arc (walls aside: nothing changes in his view).
func _guard_sees(point: Vector3) -> bool:
	var player := guard()
	if player == null or point == Vector3.INF:
		return false
	var camera := player.camera
	var eye := camera.global_position if camera != null else player.global_position + Vector3.UP * 1.6
	if eye.distance_to(point) > VIEW_REACH:
		return false
	var view := -camera.global_basis.z if camera != null else -player.global_basis.z
	var arc := Enemy.watch_half_arc(camera) if camera != null else Enemy.WATCH_HALF_ARC
	return PerceptionRules.in_view(eye, view, point, arc)


## Makes the change [param entry] on [param target] and keeps it with the
## night (a sleeper's turn is not kept: exhibits are placed afresh).
func _make_change(entry: Dictionary, target: Dictionary, toward: Vector3, in_room: StringName) -> void:
	var id := UncannyCatalog.id_of(entry)
	if StringName(entry["effect"]) == &"sleeper":
		var found: Variant = target.get("exhibit")
		if not is_instance_valid(found) or not UncannyEffects.turn_sleeper(found as Enemy, toward):
			return   # destroyed meanwhile, or awake
		run.mark_used(UncannyRules.change_id(id, String(in_room)))
	elif not apply_change(id, String(target["target"])):
		return
	else:
		run.mark_used(UncannyRules.change_id(id, String(target["target"])))
	if UncannyCatalog.limit_of(entry) > 0:
		run.mark_used(UncannyRules.fired_id(id, UncannyRules.fired_count(run.used, id) + 1))
	fired.append(id)
	Events.uncanny_event.emit(id, in_room)


## Makes the change of event [param id] on [param target] (its entry
## text: "<piece>:<quarter turns>", a painting spot, a room). False when
## the target is gone (a piece not built, a portrait hangs there).
func apply_change(id: StringName, target: String) -> bool:
	var entry := catalog.event(id)
	if entry.is_empty():
		return false
	var level := floor_game.level
	match StringName(entry["effect"]):
		&"hide", &"turn":
			var index := target.get_slice(":", 0).to_int()
			if index < 0 or index >= layout.pieces.size():
				return false
			var piece := UncannyEffects.find_piece(level, layout.pieces[index])
			if piece == null:
				return false
			if StringName(entry["effect"]) == &"hide":
				UncannyEffects.hide_piece(piece)
			else:
				UncannyEffects.turn_piece(piece, PI * 0.5 * target.get_slice(":", 1).to_int())
			return true
		&"sitter", &"look":
			var spot := StringName(target)
			if not layout.markers.has(spot):
				return false
			var painting := UncannyEffects.painting_at(museum.paintings_root, (layout.markers[spot] as Transform3D).origin)
			if painting == null:
				return false
			if StringName(entry["effect"]) == &"sitter":
				painting = UncannyEffects.swap_painting(painting, UncannyEffects.empty_picture(spot))
			elif not PaintingGaze.set_look(painting, UncannyEffects.aside(spot)):
				return false
			painting.set_meta(&"uncanny_changed", true)
			return true
		&"dark":
			return NightModifiers.set_lights(level, LightSpec.MAIN, false, [StringName(target)] as Array[StringName]) > 0
	return false


## Tonight's changes kept with the night, made again (a resumed night) -
## and the tombs left ajar.
func _restore_changes() -> void:
	for change: Array in UncannyRules.changes(run.used):
		var entry := catalog.event(change[0])
		if entry.is_empty():
			continue
		if StringName(entry["effect"]) == &"tomb":
			for exhibit in museum.exhibits():
				var mummy := exhibit as Mummy
				if mummy != null and str(int(mummy.get_meta(Museum.SLOT_META, -1))) == String(change[1]) and mummy.tomb != null and mummy.in_tomb():
					UncannyEffects.set_ajar(mummy.tomb)
			continue
		apply_change(change[0], String(change[1]))


## By nightfall the rooms visited on earlier nights have changed (the
## "night" events; their own generator, so the rest is as it was).
func _draw_night_changes(seed_value: int) -> void:
	for change in night_changes(catalog, layout, game, museum.night.portraits if museum.night != null else [] as Array[StringName], seed_value, modifier):
		run.mark_used(change)


## The night's changes (RunState.used entries) for [param of_game]'s night
## drawn from [param seed_value]: each "night" event that fits the night
## rolls its chance; its targets lie in rooms visited before tonight (one
## of them, or all with "all"). Pure: the same save and seed, the same
## changes.
static func night_changes(table: UncannyCatalog, on: LevelLayout, of_game: PersistentState, portraits: Array[StringName], seed_value: int, night_modifier: StringName = &"none") -> Array[StringName]:
	var out: Array[StringName] = []
	var dice := RandomNumberGenerator.new()
	dice.seed = seed_value * 31 + 7
	for entry in table.by_trigger(&"night"):
		var roll := dice.randf()
		if not UncannyRules.fits_night(entry, of_game.night, night_modifier) or roll >= float(entry.get("chance", 1.0)):
			continue
		var targets: Array[String] = []
		var fair := UncannyRules.fair_pieces(on, entry)
		for visited in UncannyCatalog.names(entry, "rooms"):
			if not of_game.rooms_visited.has(visited):
				continue
			match StringName(entry["effect"]):
				&"hide", &"turn":
					for index in fair:
						if on.pieces[index].room == visited:
							targets.append("%d:%d" % [index, 2])
				&"sitter", &"look":
					for spot in UncannyRules.painting_spots(on, [visited] as Array[StringName]):
						if not portraits.has(spot):
							targets.append(String(spot))
		if targets.is_empty():
			continue
		if not bool(entry.get("all", false)):
			var one: Array[String] = [targets[dice.randi_range(0, targets.size() - 1)]]
			targets = one
		for target in targets:
			out.append(UncannyRules.change_id(UncannyCatalog.id_of(entry), target))
	return out


# --- for tests and the developer's tools -------------------------------------------------

## Seconds until the next ambient event is due.
func next_in() -> float:
	return _next_ambient - _time


## Plans change [param id] for [param in_room] as if the guard had just
## left it toward [param toward] (no chance roll): it happens once he has
## been away long enough. False when nothing in the room fits it.
func force_change(in_room: StringName, id: StringName, toward: Vector3 = Vector3.INF) -> bool:
	var entry := catalog.event(id)
	if entry.is_empty():
		return false
	var point := toward if toward != Vector3.INF else UncannyRules.room_point(layout, in_room)
	var target := _change_target(entry, in_room, point)
	if target.is_empty():
		return false
	_pending[in_room] = {"entry": entry, "target": target, "due": _time + float(entry.get("away", 45.0)), "toward": point, "since": _time}
	return true


func pending_in(in_room: StringName) -> StringName:
	return UncannyCatalog.id_of(_pending[in_room]["entry"]) if _pending.has(in_room) else &""


## Fires [param id] now where the guard is, past the quiet moment and the
## dice (not past its limits or its target). False when it cannot.
func fire_now(id: StringName) -> bool:
	var entry := catalog.event(id)
	if entry.is_empty() or not UncannyRules.may_fire(entry, run.used, game.uncanny_seen):
		return false
	var target := _target(entry, room)
	if target.is_empty():
		return false
	_fire(entry, target)
	return true
