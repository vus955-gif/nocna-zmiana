class_name MenuRail
extends RefCounted
## The camera's rail for the main menu's live scene: a few hand-placed shots
## of the Great Court (world coordinates; -Z is north, the origin is the
## middle of the court). A shot is a cubic path for the eye (Catmull-Rom
## through its control points, run at a steady speed by arc length) and a
## second one for the point it looks at, eased in and out, with a sideways
## bias that turns the view a little so the subject sits in the right of the
## frame (the menu fills the left) and a slow hand-held drift on top.
## Pure data and arithmetic: nothing here touches the scene.

## Samples of the curve per control-point segment (arc-length table).
const SAMPLES := 40
## How much of the smoother-step ease the shots take (0 = a steady run from
## the first frame; the speed at the ends is 1 - EASE of the average).
const EASE := 0.55
## Radius (m) of the drum's wall the gaze of the drum shot rests on.
const DRUM_FACE := 12.0

## Seconds of black between two shots (the cut hides in the middle).
const DIP := 0.9


## One shot: where the eye goes, where it looks, for how long.
class Shot:
	var id: StringName = &""
	var seconds: float = 20.0
	var eye := PackedVector3Array()
	var focus := PackedVector3Array()
	## Vertical field of view (degrees) at the start and at the end.
	var fov_from: float = 64.0
	var fov_to: float = 60.0
	## Degrees the view is turned to the left of the subject (it lands right of the centre).
	var side_bias: float = 12.0

	var _eye_arc := PackedFloat32Array()
	var _focus_arc := PackedFloat32Array()


	## The eye at [param s] (0..1 of the path's length).
	func eye_at(s: float) -> Vector3:
		if _eye_arc.is_empty():
			_eye_arc = MenuRail.arc_table(eye)
		return MenuRail.curve(eye, MenuRail.index_at(_eye_arc, s, eye.size()))


	## The point looked at, at [param s].
	func focus_at(s: float) -> Vector3:
		if _focus_arc.is_empty():
			_focus_arc = MenuRail.arc_table(focus)
		return MenuRail.curve(focus, MenuRail.index_at(_focus_arc, s, focus.size()))


	## Where the camera stands and looks [param seconds] into the shot (before
	## the hand-held drift). The basis looks at the focus, turned by the bias.
	func pose(seconds_in: float) -> Transform3D:
		var s := MenuRail.ease_motion(seconds_in / seconds)
		var from := eye_at(s)
		var at := focus_at(s)
		var basis := Basis.looking_at((at - from).normalized(), Vector3.UP)
		basis = Basis(Vector3.UP, deg_to_rad(side_bias)) * basis
		return Transform3D(basis, from)


	## The field of view [param seconds_in] into the shot.
	func fov_at(seconds_in: float) -> float:
		return lerpf(fov_from, fov_to, MenuRail.ease_motion(seconds_in / seconds))


	## Total length of the eye's path (m).
	func eye_length() -> float:
		if _eye_arc.is_empty():
			_eye_arc = MenuRail.arc_table(eye)
		return _eye_arc[_eye_arc.size() - 1]


## The shots of the menu, in the order of the loop.
static func shots() -> Array[Shot]:
	var out: Array[Shot] = []
	# 1. under the glass roof: a slow rise from the south-west corner, the
	# moonbeams standing in the fog, the lattice's shadows on the floor, the
	# eye ending on the glass
	out.append(_shot(&"lattice", 21.0, [
		Vector3(-26.0, 1.7, 27.0), Vector3(-23.0, 2.6, 23.5), Vector3(-20.5, 3.8, 19.5), Vector3(-19.8, 5.2, 15.5),
	], [
		Vector3(8.0, 8.0, -6.0), Vector3(2.0, 10.5, -2.0), Vector3(-6.0, 14.0, 2.0), Vector3(-13.0, 19.0, 6.0),
	], 68.0, 62.0, 13.0))
	# 2. past the Reading Room's drum: an arc along its lit south face, the
	# bronze portal and its lanterns passing by
	var arc: Array[Vector3] = []
	var gaze: Array[Vector3] = []
	var heights := [1.9, 2.3, 2.7, 3.1, 3.5]
	var aims := [7.0, 8.0, 9.0, 10.0, 11.0]
	for i in 5:
		var bearing := 135.0 + 22.5 * i
		arc.append(ring(17.2, bearing, heights[i]))
		gaze.append(ring(DRUM_FACE, bearing + 28.0, aims[i]))
	out.append(_shot(&"drum", 20.0, arc, gaze, 62.0, 58.0, 12.0))
	# 3. the T-Rex in half-light: from the east, rising a little, coming
	# round to meet its head
	out.append(_shot(&"trex", 21.0, [
		Vector3(18.0, 1.8, -12.5), Vector3(15.5, 2.2, -16.5), Vector3(13.5, 2.7, -20.5), Vector3(12.0, 3.2, -24.5),
	], [
		Vector3(2.0, 3.3, -22.5), Vector3(1.5, 3.8, -22.5), Vector3(1.0, 4.3, -22.5),
	], 60.0, 57.0, 14.0))
	# 4. a glimpse of Egypt: out of the court through the door, along the
	# vestibule, through the arch and down the nave of colossi
	out.append(_shot(&"egypt", 24.0, [
		Vector3(-23.5, 1.7, 24.6), Vector3(-29.0, 1.75, 23.9), Vector3(-34.0, 1.85, 23.2),
		Vector3(-39.0, 1.95, 21.8), Vector3(-41.8, 2.05, 18.6), Vector3(-42.0, 2.15, 13.0),
	], [
		Vector3(-44.0, 1.6, 25.0), Vector3(-44.0, 2.0, 22.0), Vector3(-44.0, 2.5, 12.0),
		Vector3(-42.0, 3.0, -4.0), Vector3(-42.0, 3.5, -10.0),
	], 70.0, 66.0, 10.0))
	return out


## [param radius] m from the court's middle on [param bearing] degrees
## (clockwise from north) at height [param y].
static func ring(radius: float, bearing: float, y: float) -> Vector3:
	var a := deg_to_rad(bearing)
	return Vector3(sin(a) * radius, y, -cos(a) * radius)


static func _shot(shot_id: StringName, length: float, eye_points: Array, focus_points: Array, fov_start: float, fov_end: float, bias: float) -> Shot:
	var shot := Shot.new()
	shot.id = shot_id
	shot.seconds = length
	shot.eye = PackedVector3Array(eye_points)
	shot.focus = PackedVector3Array(focus_points)
	shot.fov_from = fov_start
	shot.fov_to = fov_end
	shot.side_bias = bias
	return shot


# --- the curve ---------------------------------------------------------------

## The Catmull-Rom curve through [param points] at [param u] (0 at the
## first point, n - 1 at the last; the ends continue straight on).
static func curve(points: PackedVector3Array, u: float) -> Vector3:
	var n := points.size()
	if n == 0:
		return Vector3.ZERO
	if n == 1:
		return points[0]
	var seg := clampi(int(floorf(u)), 0, n - 2)
	var w := clampf(u - seg, 0.0, 1.0)
	var p1 := points[seg]
	var p2 := points[seg + 1]
	var p0 := points[seg - 1] if seg > 0 else p1 * 2.0 - p2
	var p3 := points[seg + 2] if seg + 2 < n else p2 * 2.0 - p1
	return p1.cubic_interpolate(p2, p0, p3, w)


## Cumulative lengths of the curve through [param points], one entry per
## sample (SAMPLES a segment, the first is 0).
static func arc_table(points: PackedVector3Array) -> PackedFloat32Array:
	var table := PackedFloat32Array()
	var count := maxi(points.size() - 1, 1) * SAMPLES
	table.resize(count + 1)
	var last := curve(points, 0.0)
	var total := 0.0
	table[0] = 0.0
	for k in range(1, count + 1):
		var at := curve(points, float(k) / SAMPLES)
		total += at.distance_to(last)
		table[k] = total
		last = at
	return table


## The curve parameter (index space, see curve()) at [param s] (0..1) of
## the curve's length, by [param table] (arc_table()).
static func index_at(table: PackedFloat32Array, s: float, point_count: int) -> float:
	if table.size() < 2 or point_count < 2:
		return 0.0
	var total := table[table.size() - 1]
	var want := clampf(s, 0.0, 1.0) * total
	var lo := 0
	var hi := table.size() - 1
	while hi - lo > 1:
		var mid := (lo + hi) >> 1
		if table[mid] <= want:
			lo = mid
		else:
			hi = mid
	var span := table[hi] - table[lo]
	var frac := (want - table[lo]) / span if span > 0.00001 else 0.0
	return (lo + frac) / SAMPLES


## The run along a shot (0..1 in, 0..1 out): steady in the middle, gentle at
## both ends (never standing still; monotone).
static func ease_motion(u: float) -> float:
	var x := clampf(u, 0.0, 1.0)
	var smooth := x * x * x * (x * (x * 6.0 - 15.0) + 10.0)
	return lerpf(x, smooth, EASE)


# --- the hand ------------------------------------------------------------------

## The slow drift of a hand-held camera at [param time] seconds, as an
## offset in the camera's own frame: a few centimetres and a fraction of a
## degree, from sines that never repeat in a minute. [param strength]
## scales it (0 = a locked camera).
static func handheld(time: float, strength: float = 1.0) -> Transform3D:
	var push := Vector3(_wave(time, 0.0), _wave(time, 2.1) * 0.8, _wave(time, 4.3) * 0.6) * (0.03 * strength)
	var turn := Vector3(_wave(time, 1.3), _wave(time, 3.2), _wave(time, 5.5) * 0.6) * (0.0022 * strength)
	return Transform3D(Basis.from_euler(turn), push)


static func _wave(time: float, phase: float) -> float:
	return sin(time * 0.37 + phase) * 0.5 + sin(time * 0.91 + phase * 1.7 + 0.8) * 0.3 + sin(time * 1.63 + phase * 0.6 + 2.0) * 0.2
