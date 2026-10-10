class_name WingGust
extends Node3D
## The Lamassu's wing gust as something seen: a cone of dust streaks and
## grit flung from its chest along its facing (plan decision 5: the gust
## is a cone of wind, not a shot), gone in a moment. World space
## (top_level): place it with make().

const LIFETIME := 1.4
## How long the streaks pour out (s) and how many.
const POUR := 0.45
const STREAKS := 140
const DUST := Color(0.78, 0.72, 0.6)
const GRIT := Color(0.66, 0.6, 0.5)

var origin := Vector3.ZERO
var forward := Vector3.FORWARD
var reach: float = 13.0
var half_angle: float = 0.56
var _time: float = 0.0


static func make(at: Vector3, along: Vector3, reach_: float, half_angle_: float) -> WingGust:
	var gust := WingGust.new()
	gust.origin = at
	gust.forward = Vector3(along.x, 0.0, along.z).normalized() if Vector3(along.x, 0.0, along.z).length() > 0.001 else Vector3.FORWARD
	gust.reach = reach_
	gust.half_angle = half_angle_
	return gust


func _init() -> void:
	top_level = true
	name = "WingGust"


func _ready() -> void:
	global_transform = Transform3D(Basis.looking_at(forward, Vector3.UP), origin)
	var speed := reach / POUR
	# dust streaks fanning out along the cone
	var streaks := Fx.burst_node(DUST, false, STREAKS, speed, POUR + 0.3, rad_to_deg(half_angle), 1.5, 0.05)
	streaks.position = Vector3(0.0, 0.0, -0.4)
	# (a burst sprays along its +Y: turned onto the node's front)
	streaks.rotation = Vector3(-PI * 0.5, 0.0, 0.0)
	add_child(streaks)
	streaks.emitting = true
	# grit skittering along the floor
	for i in 8:
		var bearing := randf_range(-half_angle, half_angle) * 0.9
		var line := Basis(Vector3.UP, bearing) * forward
		Fx.chunk(origin + Vector3(randf_range(-0.3, 0.3), randf_range(-0.6, 0.2), randf_range(-0.3, 0.3)) + line * 0.8,
				GRIT, randf_range(0.04, 0.09), line * randf_range(7.0, 12.0) + Vector3.UP * randf_range(1.0, 3.0))


func _process(delta: float) -> void:
	_time += delta
	if _time >= LIFETIME:
		queue_free()
