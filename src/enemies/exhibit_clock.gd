extends Node
## The clock of the dozing exhibits (autoload "ExhibitClock"; plan
## 2026-10-21-wydajnosc-cpu). Asleep and at rest an exhibit has nothing to
## do between its sight checks and its routine ticks, so it leaves the
## engine's per-frame callbacks (Enemy "doze": its physics step and its
## rig's are switched off) and this clock ticks it only on the physics frame
## its next moment is due, with all the game time since its last tick in
## one step - the same looks, routines and countdowns at the same moments.
## - Runs first in every physics frame (an autoload before the scene, no
##   priority of its own): its time counts up to and including the frame
##   it has run in; a dozing exhibit woken from outside later in the frame
##   catches up through this frame, one woken before it (a physics signal)
##   through the frame before, and the engine ticks it in this one.
## - Lays the guard's trail (PerceptionWorld.track) for the exhibits while
##   any of them dozes - the first exhibit ticked in a frame did that, and
##   a frame where every exhibit dozes has none.
## - Buckets by physics frame; a frame it did not run in (the tree paused)
##   is worked off when it runs again, with only the time it ran counted.

## Game time (s) through the last physics frame this clock ran in.
var now: float = 0.0
## Due ticks run so far (tests, the CPU profile).
var due_ticks: int = 0

var _frame: int = -1
## Physics frame -> Array of the exhibits due then (an entry whose
## exhibit was woken or moved to another frame since is skipped).
var _due: Dictionary = {}
## Instance id -> exhibit, every dozing one.
var _dozers: Dictionary = {}


func _physics_process(delta: float) -> void:
	var frame := Engine.get_physics_frames()
	now += delta
	if _frame < 0:
		_frame = frame - 1
	if not _dozers.is_empty():
		_lay_trail(delta)
	while _frame < frame:
		_frame += 1
		var due: Variant = _due.get(_frame)
		if due == null:
			continue
		_due.erase(_frame)
		for exhibit: Variant in due:
			if is_instance_valid(exhibit) and (exhibit as Enemy).doze_frame() == _frame:
				due_ticks += 1
				(exhibit as Enemy).doze_tick()


## Puts [param exhibit] to doze: due again after [param seconds] of game
## time (at least the next frame). The frame is counted at full speed (a
## hitstop's slow time only brings the tick early: it finds nothing due
## and dozes on). Returns the frame it is due.
func schedule(exhibit: Enemy, seconds: float) -> int:
	var step := maxf(1.0 / Engine.physics_ticks_per_second * maxf(Engine.time_scale, 1.0), 0.0001)
	var frames := maxi(1, ceili(seconds / step - 0.001))
	var frame := Engine.get_physics_frames() + frames
	if _frame >= frame:
		frame = _frame + 1   # (never into a frame already worked off)
	var bucket: Array = _due.get(frame, [])
	if bucket.is_empty():
		_due[frame] = bucket
	bucket.append(exhibit)
	_dozers[exhibit.get_instance_id()] = exhibit
	return frame


## [param exhibit] dozes no more (woken, frozen, gone).
func release(exhibit: Enemy) -> void:
	_dozers.erase(exhibit.get_instance_id())


## How many exhibits doze now.
func dozing() -> int:
	return _dozers.size()


## Forgets everything (a test that throws its exhibits away mid-doze).
func reset() -> void:
	_due.clear()
	_dozers.clear()


## Once per frame with any exhibit dozing: the guard's trail moves on as if
## that exhibit had been ticked (its target, or none while he is down). A
## live exhibit ticked later this frame finds it done.
func _lay_trail(delta: float) -> void:
	for id: int in _dozers:
		var exhibit: Variant = _dozers[id]
		if not is_instance_valid(exhibit):
			continue
		var sleeper := exhibit as Enemy
		PerceptionWorld.track(sleeper.target if sleeper._target_alive() else null, delta)
		return
