class_name ThreatIndicator
extends CanvasLayer
## Keen ear (upgrade): when an exhibit OUT OF SIGHT (further round from
## where the guard looks than the edge of his view, plus a margin: see
## [method view_half_angle]; within RANGE) starts an attack, a red wedge
## on a ring round the crosshair points to it for SHOW_TIME seconds (it
## follows the exhibit while it shows) and a soft cue sounds. One warning
## per attack. Its own small UI layer above the HUD; the Player makes it
## when the upgrade is bought (Player.threat_indicator).

const RANGE := 20.0
const SHOW_TIME := 1.1
## Ring radius and wedge size in pixels of the 1920 x 1080 base canvas.
const RING := 190.0
const WEDGE_HALF_ANGLE := 0.3
const WEDGE_DEPTH := 36.0
const COLOR := Color(1.0, 0.18, 0.12)
## Past the edge of the view by this much (rad) an exhibit counts as out
## of sight: one right at the edge is hard to notice.
const VIEW_MARGIN := deg_to_rad(10.0)


## Draws the wedges.
class Marks extends Control:
	var indicator: ThreatIndicator

	func _draw() -> void:
		var center := size * 0.5
		for warning in indicator.warnings():
			var bearing: float = warning["bearing"]
			var alpha: float = clampf(float(warning["time"]) / ThreatIndicator.SHOW_TIME * 1.6, 0.0, 1.0)
			var color := Color(ThreatIndicator.COLOR, 0.85 * alpha)
			var points := PackedVector2Array()
			var steps := 8
			for i in steps + 1:
				var a := bearing - ThreatIndicator.WEDGE_HALF_ANGLE + 2.0 * ThreatIndicator.WEDGE_HALF_ANGLE * i / steps
				points.append(center + Vector2(sin(a), -cos(a)) * ThreatIndicator.RING)
			var tip := center + Vector2(sin(bearing), -cos(bearing)) * (ThreatIndicator.RING + ThreatIndicator.WEDGE_DEPTH)
			var shape := PackedVector2Array(points)
			shape.append(tip)
			draw_colored_polygon(shape, color)
			draw_polyline(points, Color(1.0, 0.85, 0.8, alpha), 2.0, true)


var player: Player = null
var enabled: bool = false

## instance id -> {"target": Enemy, "time": seconds left, "bearing": radians}
var _warnings: Dictionary = {}
## Exhibits whose current attack was already announced.
var _announced: Dictionary = {}
var _marks: Marks


func _ready() -> void:
	layer = 11
	_marks = Marks.new()
	_marks.indicator = self
	_marks.set_anchors_preset(Control.PRESET_FULL_RECT)
	_marks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_marks)


## The warnings showing now: [{target, time, bearing}]. Bearing 0 = ahead,
## +PI/2 = right, PI = straight behind.
func warnings() -> Array:
	return _warnings.values()


func _process(delta: float) -> void:
	if not enabled or not is_instance_valid(player) or not player.alive:
		if not _warnings.is_empty():
			_warnings.clear()
			_marks.queue_redraw()
		_announced.clear()
		return
	_scan()
	for id in _warnings.keys():
		var warning: Dictionary = _warnings[id]
		warning["time"] = float(warning["time"]) - delta
		if float(warning["time"]) <= 0.0 or not is_instance_valid(warning["target"]):
			_warnings.erase(id)   # shown long enough, or the exhibit broke
			continue
		warning["bearing"] = bearing_of((warning["target"] as Node3D).global_position)
	_marks.queue_redraw()


## Angle of [param point] from where the guard looks (0 ahead, clockwise).
func bearing_of(point: Vector3) -> float:
	var look := -player.head.global_transform.basis.z
	var forward := Vector2(look.x, look.z).normalized()
	var to := Vector2(point.x - player.global_position.x, point.z - player.global_position.z)
	if to.length() < 0.01 or forward.length() < 0.01:
		return 0.0
	to = to.normalized()
	var right := Vector2(-forward.y, forward.x)
	return atan2(to.dot(right), to.dot(forward))


## How far round from where the guard looks (rad) he still sees an
## exhibit coming: half the camera's horizontal field of view (the window's
## shape decides it) plus VIEW_MARGIN; 90 degrees without a camera.
func view_half_angle() -> float:
	var camera: Camera3D = player.camera if is_instance_valid(player) else null
	if camera == null or not camera.is_inside_tree():
		return PI * 0.5
	var size := camera.get_viewport().get_visible_rect().size
	return half_view(camera.fov, size.x / maxf(size.y, 1.0), camera.keep_aspect == Camera3D.KEEP_WIDTH)


## The out-of-sight threshold for a camera of [param fov_deg] (vertical,
## or horizontal with [param fov_is_width]) on a view [param aspect] wide.
static func half_view(fov_deg: float, aspect: float, fov_is_width: bool = false) -> float:
	var half := deg_to_rad(fov_deg) * 0.5
	if not fov_is_width:
		half = atan(tan(half) * aspect)
	return minf(half + VIEW_MARGIN, PI)


## New attacks starting out of the guard's sight.
func _scan() -> void:
	var seen := {}
	for node in get_tree().get_nodes_in_group(&"enemies"):
		var exhibit := node as Enemy
		if exhibit == null:
			continue
		var id := exhibit.get_instance_id()
		var winding_up := exhibit.brain.state == EnemyBrain.State.ATTACK and not exhibit.brain.has_struck()
		if not winding_up:
			continue
		seen[id] = true
		if _announced.has(id):
			continue
		_announced[id] = true
		if exhibit.global_position.distance_to(player.global_position) > RANGE:
			continue
		var bearing := bearing_of(exhibit.global_position)
		if absf(bearing) <= view_half_angle():
			continue   # in view: he can see it coming
		_warnings[id] = {"target": exhibit, "time": SHOW_TIME, "bearing": bearing}
		Sfx.play(&"ear_warn", -2.0)
	for id in _announced.keys():
		if not seen.has(id):
			_announced.erase(id)
