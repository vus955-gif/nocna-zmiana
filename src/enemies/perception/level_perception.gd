class_name LevelPerception
extends RefCounted
## Wires a level built from a LevelLayout into PerceptionWorld: the light
## model from its LightSpecs (LayoutIllumination) with the power read from
## the real lamps (the blackout, the power cut and the lamps' stutter all
## show in Light3D.visible), its rooms (LevelLayout.room_at), its room graph
## (passage ids = opening and stairs ids) and its doors (Door.is_open;
## passages without a Door, like stairs and arches, are always open).
## Call it once the level is built (lamps and doors exist), before the
## exhibits are placed; PerceptionWorld.reset() when the level goes.

## The museum lobby (LobbyLevel) on a night with [param modifier] (a full
## moon lights the skylights more).
static func configure_lobby(lobby: LobbyLevel, modifier: StringName = &"none") -> LayoutIllumination:
	var moon := LayoutIllumination.FULL_MOON_LEVEL if modifier == &"full_moon" else LayoutIllumination.MOON_LEVEL
	return configure_layout(lobby.layout, lobby.doors, lobby.lights, moon)


## Any level made from [param layout]: [param doors] maps opening ids to
## Door nodes, [param lights_root] holds the Light3D lamps (null = every
## lamp always on).
static func configure_layout(layout: LevelLayout, doors: Dictionary, lights_root: Node, moon_level: float = LayoutIllumination.MOON_LEVEL) -> LayoutIllumination:
	var powered := LayoutIllumination.powered_by_nodes(lights_root) if lights_root != null else Callable()
	var light := LayoutIllumination.from_layout(layout, powered)
	light.moon_level = moon_level
	PerceptionWorld.configure(light.callable(), layout.room_at, layout.graph(), door_checker(doors))
	return light


## (passage id) -> bool: open unless a Door of that id stands closed.
static func door_checker(doors: Dictionary) -> Callable:
	return func(passage: StringName) -> bool:
		var door: Variant = doors.get(passage)
		if door == null or not is_instance_valid(door):
			return true
		return (door as Door).is_open
