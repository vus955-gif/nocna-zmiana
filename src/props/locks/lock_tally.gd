class_name LockTally
extends RefCounted
## What a gate lock has taken so far (pure logic): hits summed over a short
## window (a shotgun's pellets, two barrels, a volley of fire-arrows) and
## blows counted (punches, flares fired up close).

## Hits within this many seconds add up.
var window: float = 0.4
## The summed hits that break the lock (0 = never by sum).
var need_sum: float = 25.0
## Blows that break it (0 = never by blows).
var need_strikes: int = 3
var strikes: int = 0

## [time, amount] of the hits still in the window.
var _hits: Array = []


func _init(window_: float = 0.4, need_sum_: float = 25.0, need_strikes_: int = 3) -> void:
	window = window_
	need_sum = need_sum_
	need_strikes = need_strikes_


## A hit of [param amount] at time [param now] (s). True when the hits
## within the window reach [member need_sum].
func feed(amount: float, now: float) -> bool:
	_hits.append([now, amount])
	_forget_before(now - window)
	return need_sum > 0.0 and total() >= need_sum - 0.001


## The hits still in the window, summed.
func total() -> float:
	var sum := 0.0
	for hit: Array in _hits:
		sum += float(hit[1])
	return sum


## One blow. True when the blows reach [member need_strikes].
func strike() -> bool:
	strikes += 1
	return need_strikes > 0 and strikes >= need_strikes


func reset() -> void:
	strikes = 0
	_hits.clear()


func _forget_before(time: float) -> void:
	while not _hits.is_empty() and float(_hits[0][0]) < time - 0.0001:
		_hits.pop_front()
