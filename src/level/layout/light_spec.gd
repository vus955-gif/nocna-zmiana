class_name LightSpec
extends RefCounted
## One placed light. [member group] decides who may switch it: the blackout
## modifier turns off &"main_lights"; &"emergency_lights" always stay on;
## &"haven_lights" belong to the havens; &"moon_lights" are moonlight pools
## through windows and glass roofs (no fuse: never switched off; a full moon
## brightens them); &"flicker_lights" are main lamps on a bad circuit (the
## basement's tubes): they stutter (LampFlicker) and go out with the main
## lamps in a blackout or a power cut.

enum Kind { OMNI, SPOT }

const MAIN := &"main_lights"
const EMERGENCY := &"emergency_lights"
const HAVEN := &"haven_lights"
const MOON := &"moon_lights"
const FLICKER := &"flicker_lights"

var kind: Kind = Kind.OMNI
var group: StringName = MAIN
var position := Vector3.ZERO
## SPOT only: where the cone points.
var direction := Vector3.DOWN
var color := Color(1.0, 0.8, 0.55)
var energy: float = 1.0
var light_range: float = 8.0
var spot_angle: float = 40.0
var shadow: bool = false
var room: StringName = &""
## Kit id of the visible fixture (&"" = none), placed at the light.
var fixture: StringName = &""
## Yaw of the fixture (e.g. a sconce facing away from its wall).
var fixture_yaw: float = 0.0


static func make(group_name: StringName, at: Vector3, tint: Color, strength: float, reach: float, room_id: StringName, fixture_kit: StringName = &"", casts_shadow: bool = false) -> LightSpec:
	var light := LightSpec.new()
	light.group = group_name
	light.position = at
	light.color = tint
	light.energy = strength
	light.light_range = reach
	light.room = room_id
	light.fixture = fixture_kit
	light.shadow = casts_shadow
	return light
