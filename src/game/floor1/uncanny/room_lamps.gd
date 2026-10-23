class_name RoomLamps
extends Node
## A room's lamps playing an uncanny event (plan 2026-10-21-eskalacja-nocy,
## light as a mechanic): the main lamps of the room (LightSpec.MAIN; the
## basement's flickering tubes have their own LampFlicker) or, for the exit
## signs, its emergency lamps. Modes:
## - blink: one lamp drops out twice, a heartbeat,
## - flicker: the lamps stutter in short irregular bursts,
## - brownout: they sag to BROWNOUT_LEVEL, tremble and crawl back,
## - out: they die (their fittings go dark) and come back with a stutter -
##   the emergency lamps stay,
## - sweep: they go out one after another from the farthest to the nearest
##   (from the point given: the guard) and come back in the same order -
##   something walked under them,
## - exit: the emergency lamps (the exit signs) blink.
## Only the lamps' energy and their fittings' glow change - never whether a
## lamp is on: the exhibits' light model (LayoutIllumination), the blackout
## and the power cut read that, and a lamp put out meanwhile stays out (its
## fitting dark). Every mode ends with each lamp at its own energy again;
## one effect per room at a time; freed mid-effect, it puts everything back.
## Photosensitivity (option "reduce_flashing", Flashing): every dip - a
## flicker's drop, a blink, a stutter of the outage's comeback, a lamp of
## the sweep going out, an exit sign's blink - asks its effect's
## Flashing.Gate before it starts, one gate for all the effect's lamps, so
## the room flashes at most three times a second however many lamps it has
## (a room plays one effect at a time, and UncannyDirector.MIN_GAP, 8 s
## between events, outlasts the longest lamp effect, 6 s: two effects never
## follow each other closer than the gate's gap); a dip
## the gate refuses is skipped (the lamp stays lit). A dip goes no deeper
## than Flashing.lamp_level() allows and, with the option on, leaves its
## fittings' glow alone; the brownout's tremble is a Flashing.pulse(). The
## long outage itself (out) and the brownout's slow sag stay: they are no
## flashes but the event, and a fall into the dark over a second or more.

const MODES: Array[StringName] = [&"blink", &"flicker", &"brownout", &"out", &"sweep", &"exit"]
## A fitting within this distance of a lamp is its fitting (m).
const FITTING_REACH := 1.5
## flicker: the drops of a burst (s) and how dark (share of the energy),
## and the steady stretches between them. A lamp never dips more than four
## times a second (the shortest dip and the shortest rest add up to a
## quarter of a second): photosensitive players must be able to play on;
## with "reduce_flashing" the room's gate makes it three, lamps together.
const DIP_TIME := Vector2(0.03, 0.14)
const DIP_LEVEL := Vector2(0.0, 0.45)
const STEADY := Vector2(0.22, 0.4)
## brownout: down to this share in BROWNOUT_FALL s, back up in
## BROWNOUT_RISE s at the end, trembling by BROWNOUT_WOBBLE meanwhile.
const BROWNOUT_LEVEL := 0.3
const BROWNOUT_FALL := 1.0
const BROWNOUT_RISE := 2.0
const BROWNOUT_WOBBLE := 0.05
## out: the stutter it comes back with ([on?, seconds] steps).
const COMEBACK: Array = [[true, 0.08], [false, 0.12], [true, 0.06], [false, 0.18], [true, 0.1], [false, 0.08]]
## sweep: seconds between two lamps going out, and how long each stays out.
const SWEEP_STEP := 0.35
const SWEEP_DARK := 0.9
## exit: a blink every EXIT_BLINK s (half of it dark).
const EXIT_BLINK := 0.25
## blink: [dark?, seconds] steps of the one lamp.
const BLINK: Array = [[true, 0.08], [false, 0.12], [true, 0.11]]

## Room -> its main lamps / emergency lamps (all of them; the ones on now
## are picked when an effect starts).
var mains: Dictionary = {}
var emergencies: Dictionary = {}
## Room -> the fittings of its main lamps (glow switched by an outage).
var fittings: Dictionary = {}
## Room -> the fittings of its emergency lamps (the exit signs).
var red_fittings: Dictionary = {}

## Lamp -> its energy before any effect touched it.
var _base: Dictionary = {}
## Lamp -> its fittings.
var _lamp_fittings: Dictionary = {}
## Room -> Effect playing there.
var _active: Dictionary = {}
var _rng := RandomNumberGenerator.new()


class Effect:
	var mode: StringName
	var room: StringName
	var lamps: Array[Light3D] = []
	var length: float = 0.0
	var time: float = 0.0
	## flicker: lamp -> [[start, end, level], ...]; sweep: lamp -> start.
	var plan: Dictionary = {}
	## Fittings this effect darkened (to light again at its end).
	var darkened: Array[Node] = []
	## The room's photosensitivity gate (Flashing.Gate) and its answers:
	## dip key (Vector2i: lamp index or -1 for all lamps together, step) ->
	## let through.
	var gate := Flashing.Gate.new()
	var answers: Dictionary = {}

	## May the dip [param key] starting at [param start] (effect seconds)
	## play? Asked once per dip, in the order the dips start.
	func dip_allowed(key: Vector2i, start: float) -> bool:
		if not answers.has(key):
			answers[key] = gate.allow(start)
		return answers[key]


## Indexes the lamps and fittings under [param lights_root] (a level's
## [code]lights[/code] node: lamps with meta "room").
func setup(lights_root: Node3D, seed_value: int = 0) -> void:
	name = "RoomLamps"
	_rng.seed = seed_value
	if lights_root == null:
		return
	for node in lights_root.get_children():
		var room: StringName = node.get_meta(&"room", node.get_meta(&"kit_room", &""))
		if room == &"":
			continue
		if node is Light3D and node.is_in_group(LightSpec.MAIN) and not node.is_in_group(LightSpec.FLICKER):
			_add(mains, room, node)
			_base[node] = (node as Light3D).light_energy
		elif node is Light3D and node.is_in_group(LightSpec.EMERGENCY):
			_add(emergencies, room, node)
			_base[node] = (node as Light3D).light_energy
		elif node.is_in_group(StringName("%s_fixtures" % LightSpec.MAIN)) and node is Node3D:
			_add(fittings, room, node)
		elif node.is_in_group(StringName("%s_fixtures" % LightSpec.EMERGENCY)) and node is Node3D:
			_add(red_fittings, room, node)
	for room: StringName in mains:
		for lamp: Light3D in mains[room]:
			_lamp_fittings[lamp] = _fittings_of(lamp, fittings.get(room, []))
	for room: StringName in emergencies:
		for lamp: Light3D in emergencies[room]:
			_lamp_fittings[lamp] = _fittings_of(lamp, red_fittings.get(room, []))
	set_process(false)


## The fittings of [param lamp] among [param candidates]: the ones the
## level made for it (meta "light"), else the ones within FITTING_REACH.
static func _fittings_of(lamp: Light3D, candidates: Array) -> Array[Node]:
	var own: Array[Node] = []
	for fitting: Node3D in candidates:
		if fitting.has_meta(&"light"):
			if fitting.get_meta(&"light") == lamp:
				own.append(fitting)
		elif fitting.position.distance_to(lamp.position) <= FITTING_REACH:
			own.append(fitting)
	return own


static func _add(by_room: Dictionary, room: StringName, node: Node) -> void:
	if not by_room.has(room):
		by_room[room] = []
	(by_room[room] as Array).append(node)


## The main lamps of [param room] that are on now ([param group]: or its
## emergency lamps).
func lit(room: StringName, group: StringName = LightSpec.MAIN) -> Array[Light3D]:
	var found: Array[Light3D] = []
	for lamp: Light3D in (emergencies if group == LightSpec.EMERGENCY else mains).get(room, []):
		if is_instance_valid(lamp) and lamp.visible:
			found.append(lamp)
	return found


## How many of [param room]'s main lamps (or emergency lamps) are on now.
func count(room: StringName, group: StringName = LightSpec.MAIN) -> int:
	return lit(room, group).size()


func busy(room: StringName) -> bool:
	return _active.has(room)


## Seconds the effect in [param room] lasts in all (0 when none plays).
func length_of(room: StringName) -> float:
	var effect: Effect = _active.get(room)
	return effect.length if effect != null else 0.0


## The energy [param lamp] had before any effect.
func base_energy(lamp: Light3D) -> float:
	return float(_base.get(lamp, lamp.light_energy))


## Plays [param mode] in [param room] for [param duration] seconds (sweep
## and blink take their own time; [param from]: where the sweep ends, the
## guard). False when the room is busy, has no lamp on for it, or the mode
## is unknown.
func play(room: StringName, mode: StringName, duration: float, from: Vector3 = Vector3.INF) -> bool:
	if not MODES.has(mode) or busy(room):
		return false
	var effect := Effect.new()
	effect.mode = mode
	effect.room = room
	effect.lamps = lit(room, LightSpec.EMERGENCY if mode == &"exit" else LightSpec.MAIN)
	if effect.lamps.is_empty():
		return false
	match mode:
		&"blink":
			var one: Array[Light3D] = [effect.lamps[_rng.randi_range(0, effect.lamps.size() - 1)]]
			effect.lamps = one
			effect.length = 0.0
			for step: Array in BLINK:
				effect.length += float(step[1])
		&"flicker":
			effect.length = maxf(duration, 0.3)
			for lamp in effect.lamps:
				effect.plan[lamp] = _dips(effect.length)
		&"brownout":
			effect.length = maxf(duration, BROWNOUT_FALL + BROWNOUT_RISE + 0.5)
		&"out":
			effect.length = maxf(duration, 1.0)
			for fitting: Node in fittings.get(room, []):
				if is_instance_valid(fitting) and not is_dark(fitting):
					_set_lit(fitting, false)
					effect.darkened.append(fitting)
		&"sweep":
			var ends := from if from != Vector3.INF else effect.lamps[0].global_position
			effect.lamps.sort_custom(func(a: Light3D, b: Light3D) -> bool:
				return a.global_position.distance_squared_to(ends) > b.global_position.distance_squared_to(ends))
			for i in effect.lamps.size():
				effect.plan[effect.lamps[i]] = i * SWEEP_STEP
			effect.length = effect.lamps.size() * SWEEP_STEP + SWEEP_DARK
		&"exit":
			effect.length = maxf(duration, EXIT_BLINK)
	_active[room] = effect
	set_process(true)
	return true


## Ends the effect in [param room] now: every lamp back.
func stop(room: StringName) -> void:
	var effect: Effect = _active.get(room)
	if effect == null:
		return
	_active.erase(room)
	for lamp in effect.lamps:
		if is_instance_valid(lamp):
			lamp.light_energy = base_energy(lamp)
	for fitting in effect.darkened:
		if is_instance_valid(fitting) and _lamps_on_near(effect.room, fitting):
			_set_lit(fitting, true)
	if effect.mode == &"sweep" or effect.mode == &"exit":
		for lamp in effect.lamps:
			for fitting: Node in _lamp_fittings.get(lamp, []):
				if is_instance_valid(fitting) and is_dark(fitting) and is_instance_valid(lamp) and lamp.visible:
					_set_lit(fitting, true)
	if _active.is_empty():
		set_process(false)


func stop_all() -> void:
	for room: StringName in _active.keys():
		stop(room)


## True when RoomLamps last darkened [param fitting] (and has not lit it
## again).
static func is_dark(fitting: Node) -> bool:
	return fitting.has_meta(&"uncanny_lit") and not bool(fitting.get_meta(&"uncanny_lit"))


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		stop_all()


func _process(delta: float) -> void:
	for room: StringName in _active.keys():
		var effect: Effect = _active[room]
		effect.time += delta
		if effect.time >= effect.length:
			stop(room)
			continue
		_pose(effect)


func _pose(effect: Effect) -> void:
	var t := effect.time
	match effect.mode:
		&"blink":
			var step := _step_index(BLINK, t)
			var dark := _step_dark(BLINK, t)
			_set_energy(effect.lamps[0], _dip(effect, Vector2i(0, step), _step_start(BLINK, step), 0.0) if dark else 1.0)
		&"flicker":
			for i in effect.lamps.size():
				var lamp := effect.lamps[i]
				var level := 1.0
				var dips: Array = effect.plan[lamp]
				for d in dips.size():
					var dip: Vector3 = dips[d]
					if t >= dip.x and t < dip.y:
						level = _dip(effect, Vector2i(i, d), dip.x, dip.z)
						break
				_set_energy(lamp, level)
		&"brownout":
			var level := BROWNOUT_LEVEL + Flashing.pulse(BROWNOUT_WOBBLE) * sin(t * 23.0) * sin(t * 7.3)
			if t < BROWNOUT_FALL:
				level = lerpf(1.0, level, smoothstep(0.0, 1.0, t / BROWNOUT_FALL))
			elif t > effect.length - BROWNOUT_RISE:
				level = lerpf(level, 1.0, smoothstep(0.0, 1.0, (t - (effect.length - BROWNOUT_RISE)) / BROWNOUT_RISE))
			for lamp in effect.lamps:
				_set_energy(lamp, level)
		&"out":
			# out until the comeback; its stutter's dark steps are dips of the lamps together
			var back := effect.length - _comeback_length()
			var level := 0.0
			if t >= back:
				level = 1.0
				effect.dip_allowed(Vector2i(-2, 0), back)   # the comeback itself is a change the gate counts
				if _step_dark(COMEBACK, t - back, true):
					var step := _step_index(COMEBACK, t - back)
					level = _dip(effect, Vector2i(-1, step), back + _step_start(COMEBACK, step), 0.0)
			for lamp in effect.lamps:
				_set_energy(lamp, level)
		&"sweep":
			for i in effect.lamps.size():
				var lamp := effect.lamps[i]
				var start: float = effect.plan[lamp]
				var level := 1.0
				if t >= start and t < start + SWEEP_DARK:
					level = _dip(effect, Vector2i(i, 0), start, 0.0)
				_set_energy(lamp, level)
				var dark := level < 1.0 and not Flashing.on()
				for fitting: Node in _lamp_fittings.get(lamp, []):
					if not is_instance_valid(fitting) or not lamp.visible:
						continue
					if dark and not is_dark(fitting):
						_set_lit(fitting, false)
					elif not dark and is_dark(fitting):
						_set_lit(fitting, true)
		&"exit":
			var level := 1.0
			if fmod(t, EXIT_BLINK) < EXIT_BLINK * 0.5:
				var blink := floori(t / EXIT_BLINK)
				level = _dip(effect, Vector2i(-1, blink), blink * EXIT_BLINK, 0.0)
			var dark := level < 1.0 and not Flashing.on()
			for lamp in effect.lamps:
				_set_energy(lamp, level)
				# the sign's own glow blinks with its lamp (switched on a change only)
				for fitting: Node in _lamp_fittings.get(lamp, []):
					if is_instance_valid(fitting) and lamp.visible and is_dark(fitting) != dark:
						_set_lit(fitting, not dark)


## The level of a dip [param key] of [param effect] down to [param level]
## starting at [param start]: 1.0 (no dip) when the room's gate refuses it,
## else the level as deep as Flashing lets a lamp go.
static func _dip(effect: Effect, key: Vector2i, start: float, level: float) -> float:
	if not effect.dip_allowed(key, start):
		return 1.0
	return Flashing.lamp_level(level)


## [param share] of the lamp's own energy (a lamp switched off meanwhile is
## left as it is).
func _set_energy(lamp: Light3D, share: float) -> void:
	if is_instance_valid(lamp) and lamp.visible:
		lamp.light_energy = base_energy(lamp) * share


func _set_lit(fitting: Node, on: bool) -> void:
	fitting.set_meta(&"uncanny_lit", on)
	LevelKit.set_lit(fitting, on)


## True when [param fitting]'s own lamp (meta "light"), else a main lamp
## of [param room] near it (or, with none near, any of the room's) is on:
## the fitting may glow again.
func _lamps_on_near(room: StringName, fitting: Node) -> bool:
	if fitting.has_meta(&"light"):
		var own: Variant = fitting.get_meta(&"light")
		return is_instance_valid(own) and (own as Light3D).visible
	var any := false
	for lamp: Light3D in mains.get(room, []):
		if not is_instance_valid(lamp) or not lamp.visible:
			continue
		any = true
		if fitting is Node3D and (fitting as Node3D).position.distance_to(lamp.position) <= FITTING_REACH:
			return true
	return any


## The irregular drops of one lamp's flicker over [param length] seconds:
## [start, end, level] each.
func _dips(length: float) -> Array[Vector3]:
	var dips: Array[Vector3] = []
	var t := _rng.randf_range(0.0, STEADY.y)
	while t < length - DIP_TIME.x:
		var drop := _rng.randf_range(DIP_TIME.x, DIP_TIME.y)
		dips.append(Vector3(t, minf(t + drop, length), _rng.randf_range(DIP_LEVEL.x, DIP_LEVEL.y)))
		t += drop + _rng.randf_range(STEADY.x, STEADY.y)
	return dips


static func _comeback_length() -> float:
	var total := 0.0
	for step: Array in COMEBACK:
		total += float(step[1])
	return total


## The index of the step of [param steps] ([flag, seconds] each) at
## [param t] (steps.size() past the end).
static func _step_index(steps: Array, t: float) -> int:
	var at := 0.0
	for i in steps.size():
		at += float(steps[i][1])
		if t < at:
			return i
	return steps.size()


## The time step [param index] of [param steps] starts at.
static func _step_start(steps: Array, index: int) -> float:
	var at := 0.0
	for i in mini(index, steps.size()):
		at += float(steps[i][1])
	return at


## True while [param steps] ([flag, seconds] each) say dark at [param t]
## (the flag means "on" when [param flag_is_on]).
static func _step_dark(steps: Array, t: float, flag_is_on: bool = false) -> bool:
	var at := 0.0
	for step: Array in steps:
		at += float(step[1])
		if t < at:
			return not bool(step[0]) if flag_is_on else bool(step[0])
	return false
