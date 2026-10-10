class_name WeaponState
extends RefCounted
## Runtime state of one owned weapon: magazine and reserve, battery,
## cooldown and reload. Pure logic, ticked by the WeaponHolder. Works on its
## own copy of the WeaponData (upgrades are applied to that copy), so the
## shared .tres never changes. An upgraded shotgun also carries a second
## load (slugs) that toggle_alt() switches to. A cranked gun (the gatling)
## spins up while the trigger is held (pull_trigger()), coasts after it is
## let go, opens its spread in a long burst (heat) and feeds its belt from
## the reserve by itself: never a reload, but the next belt takes
## belt_change_time to run in (counted as a reload, is_reloading()).

## A cooldown this close to zero counts as over (float rounding would
## otherwise cost a whole extra frame).
const COOLDOWN_EPSILON := 1e-4

## The shared resource this weapon was made from (never modified).
var base: WeaponData
## This owner's copy, upgrades included.
var data: WeaponData
## Shot numbers of the alternate load (null when the weapon has none).
var alt_data: WeaponData = null
var use_alt: bool = false
var magazine: int = 0
var reserve: int = 0
var battery: float = 0.0
## Barrel spin of a cranked weapon (WeaponData.spin_up_time > 0): 0 at
## rest, 1 = up to speed (it fires only then).
var spin: float = 0.0
## 0..1: how far a long burst has opened the spread (spread_max_deg).
var heat: float = 0.0
var _cooldown: float = 0.0
var _reload_left: float = 0.0
## Length of the running reload (a belt change is shorter than a reload).
var _reload_total: float = 0.0
var _recharge_wait: float = 0.0
## The trigger was pulled since the last tick / during the last tick.
var _pulled: bool = false
var _held: bool = false
## Seconds the barrels still turn after letting go (ready to fire at once).
var _coast: float = 0.0
var _since_shot: float = INF


func _init(weapon: WeaponData) -> void:
	base = weapon
	data = weapon.duplicate()
	magazine = weapon.magazine_size
	reserve = weapon.start_reserve
	battery = weapon.battery_max


## Rebuilds the copy from the base with these upgrade levels (id -> level).
## Ammo in hand stays; a bigger magazine fills on the next reload.
func apply_upgrades(levels: Dictionary) -> void:
	data = base.duplicate()
	UpgradeEffects.apply_to_weapon(data, levels)
	alt_data = UpgradeEffects.alt_profile(data)
	if alt_data == null:
		use_alt = false
	battery = minf(battery, data.battery_max)


func has_alt() -> bool:
	return alt_data != null


## Numbers of the next shot (the alternate load when it is chosen).
func shot_data() -> WeaponData:
	return alt_data if use_alt and alt_data != null else data


## Switches between the two loads: the rounds in the magazine go back to the
## reserve and a reload with the other load starts. False without a second
## load.
func toggle_alt() -> bool:
	if alt_data == null or data.ammo_mode != WeaponData.AmmoMode.MAGAZINE:
		return false
	use_alt = not use_alt
	cancel_reload()
	reserve += magazine
	magazine = 0
	start_reload()
	return true


func tick(delta: float) -> void:
	if uses_spin():
		# a cranked gun keeps up to one frame of overshoot, so at 60 physics
		# frames a second it still fires 14 rounds a second, not 12
		_cooldown = maxf(_cooldown - delta, -delta)
		_tick_spin(delta)
	else:
		_cooldown = maxf(_cooldown - delta, 0.0)
	_since_shot += delta
	if heat > 0.0 and _since_shot > data.cooldown * 2.0:
		heat = maxf(heat - delta * 2.0 / maxf(data.spread_growth_time, 0.01), 0.0)
	if data.belt_feed and magazine == 0 and reserve > 0 and not is_reloading():
		_feed_belt()   # ammo picked up while the box was empty
	if _reload_left > 0.0:
		_reload_left -= delta
		if _reload_left <= 0.0:
			_finish_reload()
	if data.ammo_mode == WeaponData.AmmoMode.BATTERY:
		var charge_time := delta
		if _recharge_wait > 0.0:
			charge_time = maxf(delta - _recharge_wait, 0.0)
			_recharge_wait = maxf(_recharge_wait - delta, 0.0)
		battery = minf(battery + data.battery_recharge_per_sec * charge_time, data.battery_max)


func is_reloading() -> bool:
	return _reload_left > 0.0


## 0..1 through the running reload (0 when none runs).
func reload_progress() -> float:
	if _reload_left <= 0.0 or _reload_total <= 0.0:
		return 0.0
	return clampf(1.0 - _reload_left / _reload_total, 0.0, 1.0)


## Ammo in the magazine or in reserve (a battery weapon always has some).
func has_ammo_left() -> bool:
	if data.ammo_mode == WeaponData.AmmoMode.MAGAZINE:
		return magazine > 0 or reserve > 0
	return true


func has_ammo_for_shot() -> bool:
	match data.ammo_mode:
		WeaponData.AmmoMode.BATTERY:
			return battery >= data.battery_cost
		WeaponData.AmmoMode.MAGAZINE:
			return magazine > 0
	return true


func can_fire() -> bool:
	return _cooldown <= COOLDOWN_EPSILON and not is_reloading() and has_ammo_for_shot() and spun_up()


## Uses ammo and starts the cooldown. Call only after can_fire().
func fire() -> void:
	_cooldown = data.cooldown + (minf(_cooldown, 0.0) if uses_spin() else 0.0)
	_since_shot = 0.0
	if data.spread_max_deg > data.spread_deg:
		heat = minf(heat + data.cooldown / maxf(data.spread_growth_time, 0.01), 1.0)
	match data.ammo_mode:
		WeaponData.AmmoMode.BATTERY:
			battery -= data.battery_cost
			_recharge_wait = data.battery_recharge_delay
		WeaponData.AmmoMode.MAGAZINE:
			magazine -= 1
			if data.belt_feed and magazine == 0:
				_feed_belt()   # the next belt runs in


## The trigger is held this frame (a cranked gun spins up while it is).
## WeaponHolder.try_fire() calls it on every frame the guard holds fire.
func pull_trigger() -> void:
	_pulled = true


## True for a gun that has to spin up before it fires.
func uses_spin() -> bool:
	return data.spin_up_time > 0.0


## Up to speed (always true for a gun without a crank).
func spun_up() -> bool:
	return not uses_spin() or spin >= 1.0


## The trigger is held (during the last tick, or pulled since).
func trigger_held() -> bool:
	return _held or _pulled


## A shot went off within the last cooldown and a half (a burst is on).
func firing() -> bool:
	return _since_shot <= data.cooldown * 1.5


## Letting go: the barrels still turn and a new pull fires at once.
func coasting() -> bool:
	return not _held and _coast > 0.0


## 0..1 speed of the barrels for the view: rising while spinning up,
## winding down while coasting.
func barrel_speed() -> float:
	if coasting():
		return _coast / maxf(data.spin_down_time, 0.01)
	return spin


## Spread half-angle of the next [param shot] (a long burst opens it).
func spread_for(shot: WeaponData) -> float:
	if shot.spread_max_deg > shot.spread_deg:
		return lerpf(shot.spread_deg, shot.spread_max_deg, heat)
	return shot.spread_deg


func can_reload() -> bool:
	return data.ammo_mode == WeaponData.AmmoMode.MAGAZINE and not data.belt_feed and not is_reloading() \
			and magazine < data.magazine_size and reserve > 0


func start_reload() -> bool:
	if not can_reload():
		return false
	_reload_left = data.reload_time
	_reload_total = data.reload_time
	if _reload_left <= 0.0:
		_finish_reload()
	return true


func cancel_reload() -> void:
	_reload_left = 0.0


## Adds reserve ammo up to the cap. Returns how much was taken.
func add_ammo(amount: int) -> int:
	if data.ammo_mode != WeaponData.AmmoMode.MAGAZINE:
		return 0
	var taken := clampi(amount, 0, maxi(data.max_reserve - reserve, 0))
	reserve += taken
	return taken


## Held: the barrels speed up. Let go at full speed: they coast for
## spin_down_time (ready), then stop. Let go earlier: they slow down again.
func _tick_spin(delta: float) -> void:
	_held = _pulled
	_pulled = false
	if _held:
		spin = minf(spin + delta / data.spin_up_time, 1.0)
		_coast = data.spin_down_time if spin >= 1.0 else 0.0
	elif _coast > 0.0:
		_coast = maxf(_coast - delta, 0.0)
		if _coast <= 0.0:
			spin = 0.0
	else:
		spin = maxf(spin - delta / data.spin_up_time, 0.0)


## The empty box takes the next belt from the reserve: at once, or after
## belt_change_time (no shots meanwhile; the longer belt's upgrade feeds it
## without a pause).
func _feed_belt() -> void:
	if reserve <= 0:
		return
	if data.belt_change_time <= 0.0:
		_finish_reload()
		return
	_reload_left = data.belt_change_time
	_reload_total = data.belt_change_time


func _finish_reload() -> void:
	_reload_left = 0.0
	var moved := mini(data.magazine_size - magazine, reserve)
	magazine += moved
	reserve -= moved
