class_name VoiceQueue
extends RefCounted
## Who speaks next, and when. Pure logic: the director feeds it time, calm and
## requests; it answers with the line to start. One voice at a time.

const SIDE := 0
const NORMAL := 1
const EVENT := 2
const GUIDE := 3

const CALM_NEEDED := 4.0      ## s with no hunter near and no hit before a line starts
const EVENT_MAX_WAIT := 10.0  ## an event line stops waiting for calm after this long
const SIDE_EXPIRY := 60.0     ## a side remark that waited this long is dropped (stays unheard)
const SIDE_GAP := 180.0       ## s between two side remarks
const LINE_GAP := 20.0        ## s of quiet after any line

var pending: Array[Dictionary] = []   ## {key, priority, delay, waited}
var speaking: Dictionary = {}         ## the request on air; {} when quiet
var calm_time := 0.0
var since_line := LINE_GAP
var since_side := SIDE_GAP


func push(key: StringName, priority: int, delay := 0.0) -> bool:
	if has(key):
		return false
	pending.append({"key": key, "priority": priority, "delay": delay, "waited": 0.0})
	return true


func has(key: StringName) -> bool:
	if speaking.get("key", &"") == key:
		return true
	for request in pending:
		if request.key == key:
			return true
	return false


func is_speaking() -> bool:
	return not speaking.is_empty()


## Ages the queue by [param dt]; returns the key that starts now, or &"".
func advance(dt: float, calm: bool) -> StringName:
	calm_time = calm_time + dt if calm else 0.0
	if speaking.is_empty():
		since_line += dt
	since_side += dt
	var kept: Array[Dictionary] = []
	for request in pending:
		if request.delay > 0.0:
			request.delay = maxf(0.0, request.delay - dt)
		else:
			request.waited += dt
		if not (request.priority == SIDE and request.waited > SIDE_EXPIRY):
			kept.append(request)
	pending = kept
	if not speaking.is_empty() or since_line < LINE_GAP:
		return &""
	var best := _best_ready()
	if best.is_empty():
		return &""
	pending.erase(best)
	speaking = best
	if best.priority == SIDE:
		since_side = 0.0
	return best.key


func _best_ready() -> Dictionary:
	var best: Dictionary = {}
	for request in pending:
		if request.delay > 0.0:
			continue
		if request.priority == SIDE and since_side < SIDE_GAP:
			continue
		var waited_enough: bool = request.priority >= EVENT and request.waited >= EVENT_MAX_WAIT
		if calm_time < CALM_NEEDED and not waited_enough:
			continue
		if best.is_empty() or request.priority > best.priority:
			best = request
	return best


## The line on air ended. Returns its key.
func finished() -> StringName:
	var key: StringName = speaking.get("key", &"")
	speaking = {}
	since_line = 0.0
	return key


## Something more important cut in: the line on air goes back to the front of
## the queue and will be played again from its start.
func interrupt() -> StringName:
	if speaking.is_empty():
		return &""
	var request := speaking
	speaking = {}
	request.waited = 0.0
	pending.push_front(request)
	return request.key


## The audio guide takes the air directly (the player pressed its button).
func hold(key: StringName) -> void:
	speaking = {"key": key, "priority": GUIDE, "delay": 0.0, "waited": 0.0}


func clear() -> void:
	pending.clear()
	speaking = {}
	calm_time = 0.0
	since_line = LINE_GAP
	since_side = SIDE_GAP
