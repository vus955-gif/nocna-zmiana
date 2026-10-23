class_name Flashing
extends RefCounted
## The photosensitivity guard (option "reduce_flashing", plan
## 2026-10-21-dostepnosc). One place that says how hard the game may flash
## and flicker once the player asks for less: every system that makes light
## or the screen flash asks here for its numbers instead of keeping its own.
## The limits follow the general flash threshold of WCAG 2.3.1 (and the
## Harding test the broadcasters use): no more than MAX_PER_SECOND flashes
## in any one second, and a flash is made shallower - a lamp that dips never
## goes below DIP_FLOOR of its light, a flash of light is LIGHT_SHARE of the
## usual, a hit's white flash stops at HIT_FLASH_CAP, the red edges of a hit
## at VIGNETTE_CAP, a slow pulse swings PULSE_SHARE as far. With the option
## off every function returns its argument unchanged.
##
## The contract for systems that flash (add yours the same way):
##  - a light that dips or blinks: [method lamp_level] for the dip's depth and
##    a [Gate] for when a dip may start (the room lamps of the night
##    escalation, RoomLamps, do both, with one gate for all the lamps of a
##    room: a lamp alone dips at most 4 times a second, the room with the
##    option on at most 3; LampFlicker's tubes likewise);
##  - a point light that flashes (muzzle, zap, blast): [method light_energy],
##    and a [Gate] when it can repeat quickly (Fx.flash does);
##  - a white flash on a model (the exhibit shader's "flash"): [method hit_flash];
##  - a full-screen or HUD pulse: [method vignette] or [method pulse];
##  - a blink that carries no information (an eye, a lamp's warning): steady
##    while [method on].

## Flashes in any one second, at most (WCAG 2.3.1: "three flashes or below").
const MAX_PER_SECOND := 3
## Seconds between two flashes that keeps to it (a hair over a third).
const MIN_GAP := 0.34
## A lamp dips to this share of its light at the least.
const DIP_FLOOR := 0.5
## A flash of light (muzzle, zap, blast) shines at this share of its energy.
const LIGHT_SHARE := 0.5
## A model's white hit flash (0..1) stops here.
const HIT_FLASH_CAP := 0.4
## The red edges of a hit (alpha) stop here.
const VIGNETTE_CAP := 0.5
## A pulse (the low-health mount, the muzzle star's brightness) swings this
## share of the usual.
const PULSE_SHARE := 0.5


## Is the option on.
static func on() -> bool:
	return Settings.data.reduce_flashing


## The energy of a flash of light, [param energy] normally.
static func light_energy(energy: float) -> float:
	return energy * LIGHT_SHARE if on() else energy


## A lamp that dips to [param level] (a share of its light, 0 = out) dips to
## this.
static func lamp_level(level: float) -> float:
	return maxf(level, DIP_FLOOR) if on() else level


## A model's hit flash of [param amount] (0..1).
static func hit_flash(amount: float) -> float:
	return minf(amount, HIT_FLASH_CAP) if on() else amount


## The alpha of a full-screen flash (the red edges of a hit).
static func vignette(alpha: float) -> float:
	return minf(alpha, VIGNETTE_CAP) if on() else alpha


## The swing (0..1) of a pulse.
static func pulse(amplitude: float) -> float:
	return amplitude * PULSE_SHARE if on() else amplitude


## The gap (seconds) to keep between two flashes of one source that would
## otherwise come after [param requested].
static func gap(requested: float) -> float:
	return maxf(requested, MIN_GAP) if on() else requested


## Lets flashes through at most MAX_PER_SECOND times a second while the
## option is on, and every one while it is off. Time is the caller's own
## (seconds of game time), so it runs the same in a fast test.
class Gate extends RefCounted:
	var _last: float = -INF

	## May a flash start at [param now]? (A yes is remembered.)
	func allow(now: float) -> bool:
		if Flashing.on() and now - _last < Flashing.MIN_GAP:
			return false
		_last = now
		return true

	## Forget the last flash.
	func reset() -> void:
		_last = -INF
