class_name NightModifiers
## The night's modifier (design 9) applied to a built level (the lobby or
## Floor I: any Level with a [code]lights[/code] node holding its lamps,
## environment and moon):
## - blackout: every lamp of the main_lights group dark (lights off, their
##   fixtures unlit) all night, ambient light x0.3; emergency lamps, the
##   havens' lamps and the moon stay - the flashlight and its battery matter,
## - full_moon: the moon x1.6 and bluer, exhibits +25% health and damage
##   (set before they enter the tree), Dust x1.5 (RunState multiplier),
## - calm: fewer exhibits (NightDirector thins the encounters); nothing here.
## Also the switch the fuse box uses to put out the hall's lamps.

const BLACKOUT_AMBIENT := 0.3
const MOON_ENERGY := 1.6
const MOON_COLOR := Color(0.52, 0.66, 1.0)
const FULL_MOON_STATS := 1.25
const FULL_MOON_DUST := 1.5
## RunState multiplier source of the full moon.
const DUST_SOURCE := &"full_moon"
const MODIFIERS: Array[StringName] = [&"none", &"blackout", &"full_moon", &"calm"]


## Applies [param modifier] to [param level] (its lights and environment)
## and to [param run] (Dust).
static func apply(level: Level, modifier: StringName, run: NightState) -> void:
	match modifier:
		&"blackout":
			set_lights(level, LightSpec.MAIN, false)
			var env := environment(level)
			if env != null:
				env.ambient_light_energy *= BLACKOUT_AMBIENT
		&"full_moon":
			for moon in moons(level):
				moon.light_energy *= MOON_ENERGY
				moon.light_color = MOON_COLOR
			for pool in moon_pools(level):
				pool.light_energy *= MOON_ENERGY
			run.set_multiplier(DUST_SOURCE, FULL_MOON_DUST)


## Tonight's exhibit stats: call before the exhibit enters the tree.
static func tune(exhibit: Enemy, modifier: StringName) -> void:
	if modifier == &"full_moon":
		exhibit.max_health *= FULL_MOON_STATS
		exhibit.attack_damage *= FULL_MOON_STATS


## Switches the lamps of [param group] under [param level] (and the glow of
## their fixtures). With [param rooms] only the lamps of those rooms.
## The main group takes the flickering lamps along (they are main lamps on
## a bad circuit).
static func set_lights(level: Level, group: StringName, on: bool, rooms: Array[StringName] = []) -> int:
	var switched := 0
	var groups: Array[StringName] = [group]
	if group == LightSpec.MAIN:
		groups.append(LightSpec.FLICKER)
	var root := lights_of(level)
	if root == null:
		return 0
	for node in root.get_children():
		var room: StringName = node.get_meta(&"room", node.get_meta(&"kit_room", &""))
		if not rooms.is_empty() and not rooms.has(room):
			continue
		for each in groups:
			if node is Light3D and node.is_in_group(each):
				(node as Light3D).visible = on
				switched += 1
			elif node.is_in_group(StringName("%s_fixtures" % each)):
				LevelKit.set_lit(node, on)
	return switched


static func environment(level: Level) -> Environment:
	var root := lights_of(level)
	var world := root.get_node_or_null(^"Environment") as WorldEnvironment if root != null else null
	return world.environment if world != null else null


static func moons(level: Level) -> Array[DirectionalLight3D]:
	var found: Array[DirectionalLight3D] = []
	var root := lights_of(level)
	if root == null:
		return found
	for node in root.get_children():
		if node is DirectionalLight3D and node.is_in_group(&"moon"):
			found.append(node)
	return found


## The moonlight pools of [param level] (LightSpec.MOON: spots through its
## windows and glass roofs; never switched off).
static func moon_pools(level: Level) -> Array[Light3D]:
	var found: Array[Light3D] = []
	var root := lights_of(level)
	if root == null:
		return found
	for node in root.get_children():
		if node is Light3D and node.is_in_group(LightSpec.MOON):
			found.append(node)
	return found


## The node holding [param level]'s lamps, environment and moon (its
## [code]lights[/code]; null before build() or for a level without one).
static func lights_of(level: Level) -> Node3D:
	if level == null:
		return null
	var root: Variant = level.get(&"lights")
	return root as Node3D if root is Node3D else null


## Translation keys of the modifier's name and one-line description ("" for
## a night without one).
static func title_key(modifier: StringName) -> String:
	return "" if modifier == &"none" or modifier == &"" else "NIGHT_MOD_%s" % String(modifier).to_upper()


static func detail_key(modifier: StringName) -> String:
	return "" if modifier == &"none" or modifier == &"" else "NIGHT_MOD_%s_DETAIL" % String(modifier).to_upper()
