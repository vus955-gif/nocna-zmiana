class_name LightRecipe
extends RefCounted
## A level's lighting recipe as data, the way LevelLighting reads it: the
## environment and the moon, per room the dust (FogVolume), the reflection
## probe, the shadow budget and the lamps' fade and haze, the rules of each
## light fitting, and the lamps the art asks for that the layout does not
## have. The lobby's is LobbyLightRecipe's constants ([method lobby]); Floor
## I's is Floor1LightRecipe ([method Floor1LightRecipe.create]).

## Environment settings (see LobbyLightRecipe.ENVIRONMENT).
var environment: Dictionary = {}
## Moon settings (see LobbyLightRecipe.MOON).
var moon: Dictionary = {}
## Room key -> fog, fog_albedo, probe, probe_offset, shadowed, fade_begin,
## lamp_fog (and fog_noise).
var rooms: Dictionary = {}
## Room id -> the room key it counts as (a balcony as its hall).
var room_keys: Dictionary = {}
## Fitting -> shadow, fog, energy, uncapped, rank.
var fixtures: Dictionary = {}
## Lamps the layout does not have: {room, position, direction, color,
## energy, range, angle} (spots; optional "group", "fog", "shadow").
var extra_lights: Array = []
## True: rooms the recipe does not know are tuned as its fallback room
## (the lobby); false: their lamps keep the layout's own shadows and no
## fog or probe of the recipe (Floor I's zones not dressed yet).
var tune_unknown: bool = true


## The lobby's recipe (LobbyLightRecipe), unchanged.
static func lobby() -> LightRecipe:
	var recipe := LightRecipe.new()
	recipe.environment = LobbyLightRecipe.ENVIRONMENT
	recipe.moon = LobbyLightRecipe.MOON
	recipe.rooms = LobbyLightRecipe.ROOMS
	recipe.room_keys = {&"balcony": &"hall"}
	recipe.fixtures = LobbyLightRecipe.FIXTURE_LIGHTS
	recipe.extra_lights = LobbyLightRecipe.EXTRA_LIGHTS
	return recipe


## The recipe's key for [param room] (itself, or the room it counts as).
func key(room: StringName) -> StringName:
	return room_keys.get(room, room)


## True when the recipe tunes [param room]'s lamps.
func knows(room: StringName) -> bool:
	return tune_unknown or rooms.has(key(room))
