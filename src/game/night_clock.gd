class_name NightClock
extends RefCounted
## The night shift's clock (expansion design 4): 23:00 to 6:00, three
## minutes of play per hour (21 minutes a night). At 3:00 the witching
## hour begins, at 6:00 dawn ends the night. The clock stands while the
## guard rests in a haven, but only HAVEN_ALLOWANCE seconds per visit (a
## haven is a break, not a freezer); a new visit needs HAVEN_REFILL_AFTER
## seconds outside first (stepping out of the door and back in is the same
## visit). Menus stop it by pausing the game.

const START_HOUR := 23
const HOURS := 7
const SECONDS_PER_HOUR := 180.0
## Hours after 23:00: 3:00 and 6:00.
const WITCHING_AFTER := 4
const DAWN_AFTER := HOURS
const HAVEN_ALLOWANCE := 60.0
## Seconds outside a haven before the next visit gets its full break again.
const HAVEN_REFILL_AFTER := 20.0

## Seconds of the night counted so far.
var elapsed: float = 0.0
## Seconds the clock may still stand in the current haven visit.
var haven_left: float = HAVEN_ALLOWANCE

## Seconds since the guard last stood in a haven.
var _outside: float = 0.0


## Moves the clock on by [param delta] seconds ([param in_haven]: the guard
## rests in a haven). Returns what it crossed: &"witching" and/or &"dawn".
func advance(delta: float, in_haven: bool) -> Array[StringName]:
	var crossed: Array[StringName] = []
	if delta <= 0.0 or is_dawn():
		return crossed
	if in_haven:
		_outside = 0.0
		var standing := minf(delta, haven_left)
		haven_left -= standing
		delta -= standing
		if delta <= 0.0:
			return crossed
	else:
		_outside += delta
		if _outside >= HAVEN_REFILL_AFTER:
			haven_left = HAVEN_ALLOWANCE   # a new visit gets a new break
	var was_witching := is_witching()
	elapsed = minf(elapsed + delta, seconds_to_dawn())
	if not was_witching and is_witching():
		crossed.append(&"witching")
	if is_dawn():
		crossed.append(&"dawn")
	return crossed


static func seconds_to_dawn() -> float:
	return DAWN_AFTER * SECONDS_PER_HOUR


static func seconds_to_witching() -> float:
	return WITCHING_AFTER * SECONDS_PER_HOUR


func is_witching() -> bool:
	return elapsed >= seconds_to_witching()


func is_dawn() -> bool:
	return elapsed >= seconds_to_dawn()


## The hour on the clock face (23, 0, 1 ... 6).
func hour() -> int:
	return (START_HOUR + int(elapsed / SECONDS_PER_HOUR)) % 24


func minute() -> int:
	return int(fmod(elapsed, SECONDS_PER_HOUR) / SECONDS_PER_HOUR * 60.0)


## "23:00" ... "6:00".
func text() -> String:
	return "%d:%02d" % [hour(), minute()]


## 0 at 23:00, 1 at dawn.
func fraction() -> float:
	return clampf(elapsed / seconds_to_dawn(), 0.0, 1.0)


## The clock's face at dawn ("6:00").
static func dawn_text() -> String:
	return "%d:00" % ((START_HOUR + HOURS) % 24)
