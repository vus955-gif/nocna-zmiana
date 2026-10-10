class_name FlashlightBattery
extends RefCounted
## The guard's flashlight battery (pure logic, ticked by the player). Lit, it
## drains one second of charge per second; off, it recharges at half that
## speed. Running dry switches the light off, and it only comes on again
## from RELIGHT_AT of a charge. Below FLICKER_BELOW the light flickers.

const BASE_CAPACITY := 120.0
const RECHARGE_RATIO := 0.5
const FLICKER_BELOW := 0.15
const RELIGHT_AT := 0.05

## Seconds of light on a full charge (upgrades raise it).
var capacity: float = BASE_CAPACITY
var charge: float = BASE_CAPACITY
var on: bool = false


func tick(delta: float) -> void:
	if on:
		charge = maxf(charge - delta, 0.0)
		if charge <= 0.0:
			on = false
	else:
		charge = minf(charge + delta * RECHARGE_RATIO, capacity)


## Switches the light. Returns false when it cannot come on (too little charge).
func set_on(value: bool) -> bool:
	if value and not on and fraction() < RELIGHT_AT:
		return false
	on = value
	return true


func toggle() -> bool:
	return set_on(not on)


func fraction() -> float:
	return charge / capacity if capacity > 0.0 else 0.0


func is_low() -> bool:
	return fraction() < FLICKER_BELOW


func is_flickering() -> bool:
	return on and is_low()


## New capacity in seconds; the charge keeps its fraction.
func set_capacity(seconds: float) -> void:
	var kept := fraction()
	capacity = maxf(seconds, 1.0)
	charge = kept * capacity
