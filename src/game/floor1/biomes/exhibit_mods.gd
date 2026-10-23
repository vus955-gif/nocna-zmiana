class_name ExhibitMods
extends RefCounted
## The biome devices' changes of an exhibit's pace and sight, kept as
## FACTORS on the exhibit itself (plan 2026-10-21-mechaniki-biomow,
## "Poprawki po przeglądzie" 1): each device puts in a factor under its own
## key and takes it out again, and the exhibit's [member Enemy.move_speed] /
## [member Enemy.sight_range] only ever change by the ratio of the effect
## before and after. Nothing is saved and put back as an absolute value, so
## ending one effect never cancels another change of the same number - the
## witching hour's x1.2 pace (NightWatch.boost), another device's factor, a
## sharpening of the eyes - whichever came first or went first.
## - PACE: the factors multiply (stiffened x0.4 and hastened x1.35 at once
##   runs at x0.54).
## - SIGHT: a factor is a cap (the share of its natural sight it may still
##   see by); the sharpest cap rules, so two blinding effects at once never
##   blind it more than the worse of them, and one ending leaves the other.
## The table lives in the exhibit's meta [constant META]: {stat: {key: factor}}.

const META := &"biome_mods"
const PACE := &"pace"
const SIGHT := &"sight"
## No cap blinds it entirely (a factor of 0 could not be taken off again).
const MIN_SIGHT_FACTOR := 0.001


## Puts [param factor] on [param exhibit]'s pace under [param key] (a device's
## instance id; again under the same key it only replaces the factor).
static func scale_pace(exhibit: Enemy, key: Variant, factor: float) -> void:
	if factor <= 0.0:
		return
	var before := pace_factor(exhibit)
	_table(exhibit, PACE)[key] = factor
	exhibit.move_speed *= pace_factor(exhibit) / before


## Takes the factor [param key] put on [param exhibit]'s pace off again.
static func clear_pace(exhibit: Enemy, key: Variant) -> void:
	if not has_key(exhibit, PACE, key):
		return
	var before := pace_factor(exhibit)
	_table(exhibit, PACE).erase(key)
	exhibit.move_speed *= pace_factor(exhibit) / before
	_tidy(exhibit)


## Caps [param exhibit]'s sight at [param limit] m (its natural sight, when
## that is shorter already) under [param key].
static func cap_sight(exhibit: Enemy, key: Variant, limit: float) -> void:
	var before := sight_factor(exhibit)
	var natural := exhibit.sight_range / before
	var factor := minf(limit / natural, 1.0) if natural > 0.0 else 1.0
	_table(exhibit, SIGHT)[key] = maxf(factor, MIN_SIGHT_FACTOR)
	exhibit.sight_range *= sight_factor(exhibit) / before


## Takes the cap [param key] put on [param exhibit]'s sight off again.
static func clear_sight(exhibit: Enemy, key: Variant) -> void:
	if not has_key(exhibit, SIGHT, key):
		return
	var before := sight_factor(exhibit)
	_table(exhibit, SIGHT).erase(key)
	exhibit.sight_range *= sight_factor(exhibit) / before
	_tidy(exhibit)


## The product of the pace factors on [param exhibit] (1 without any).
static func pace_factor(exhibit: Enemy) -> float:
	var total := 1.0
	for factor: float in _table(exhibit, PACE, false).values():
		total *= factor
	return total


## The sharpest sight cap on [param exhibit] (1 without any).
static func sight_factor(exhibit: Enemy) -> float:
	var sharpest := 1.0
	for factor: float in _table(exhibit, SIGHT, false).values():
		sharpest = minf(sharpest, factor)
	return sharpest


static func has_key(exhibit: Enemy, stat: StringName, key: Variant) -> bool:
	return _table(exhibit, stat, false).has(key)


## True while any device holds a factor on [param exhibit].
static func any(exhibit: Enemy) -> bool:
	return exhibit.has_meta(META)


## The table of [param stat] ([param make]: created when it is not there).
static func _table(exhibit: Enemy, stat: StringName, make: bool = true) -> Dictionary:
	if not exhibit.has_meta(META):
		if not make:
			return {}
		exhibit.set_meta(META, {})
	var tables: Dictionary = exhibit.get_meta(META)
	if not tables.has(stat):
		if not make:
			return {}
		tables[stat] = {}
	return tables[stat]


## Nothing held: the meta goes (an exhibit untouched by a device is as new).
static func _tidy(exhibit: Enemy) -> void:
	if not exhibit.has_meta(META):
		return
	for table: Dictionary in (exhibit.get_meta(META) as Dictionary).values():
		if not table.is_empty():
			return
	exhibit.remove_meta(META)
