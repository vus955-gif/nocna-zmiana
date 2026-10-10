class_name MapView
extends RefCounted
## How the paper map lies on the screen: the zoom (screen px per sheet px)
## and the sheet point at the middle of the screen. Every change sets a
## target; step() glides there (exponential smoothing, the zoom in log
## space), so the wheel, a drag and the pad all feel smooth. The view never
## leaves the sheet: the middle of the screen stays on it (a little desk may
## show round the edges), and a sheet narrower than the screen is centred.

## 1/s: how fast the view glides to its target.
const SMOOTH := 14.0
## Zoom range: from the whole sheet on screen to this many times closer.
const MAX_FACTOR := 5.0
## Opening zoom (times the fit).
const OPEN_FACTOR := 1.6
## Screen px of desk allowed past the sheet's edges.
const EDGE := 70.0
## Below this the glide snaps to its target.
const SNAP_ZOOM := 0.0005
const SNAP_PX := 0.05

var sheet_size := MapStyle.SHEET
var screen_size := Vector2(1920.0, 1080.0)
var zoom: float = 1.0
var center := MapStyle.SHEET * 0.5
var target_zoom: float = 1.0
var target_center := MapStyle.SHEET * 0.5


## The zoom that shows the whole sheet (a margin left for the tabs above and
## the hint line below).
func fit_zoom() -> float:
	return minf(screen_size.x * 0.94 / sheet_size.x, screen_size.y * 0.84 / sheet_size.y)


func min_zoom() -> float:
	return fit_zoom()


func max_zoom() -> float:
	return fit_zoom() * MAX_FACTOR


func open_zoom() -> float:
	return clampf(fit_zoom() * OPEN_FACTOR, min_zoom(), max_zoom())


## The view as it is now.
func sheet_to_screen(point: Vector2) -> Vector2:
	return screen_size * 0.5 + (point - center) * zoom


func screen_to_sheet(point: Vector2) -> Vector2:
	return center + (point - screen_size * 0.5) / zoom


## Zooms by [param factor] about [param screen_point]: the sheet point under
## it stays there (as far as the edges allow).
func zoom_at(screen_point: Vector2, factor: float) -> void:
	var held := target_center + (screen_point - screen_size * 0.5) / target_zoom
	target_zoom = clampf(target_zoom * factor, min_zoom(), max_zoom())
	target_center = clamp_center(held - (screen_point - screen_size * 0.5) / target_zoom, target_zoom)


## Moves the sheet with the cursor: [param delta] screen px.
func pan_screen(delta: Vector2) -> void:
	target_center = clamp_center(target_center - delta / target_zoom, target_zoom)


## Glides to [param point] (sheet px), at [param at_zoom] when given.
func look_at(point: Vector2, at_zoom: float = -1.0) -> void:
	if at_zoom > 0.0:
		target_zoom = clampf(at_zoom, min_zoom(), max_zoom())
	target_center = clamp_center(point, target_zoom)


## Jumps to the target at once.
func snap() -> void:
	zoom = target_zoom
	center = target_center


## A new screen size: the limits move, the view stays valid.
func resize(size: Vector2) -> void:
	screen_size = size
	target_zoom = clampf(target_zoom, min_zoom(), max_zoom())
	target_center = clamp_center(target_center, target_zoom)
	zoom = clampf(zoom, min_zoom(), max_zoom())


## Glides towards the target; true when the view moved.
func step(delta: float) -> bool:
	if is_equal_approx(zoom, target_zoom) and center.is_equal_approx(target_center):
		return false
	var k := 1.0 - exp(-SMOOTH * delta)
	zoom = exp(lerpf(log(zoom), log(target_zoom), k))
	center = center.lerp(target_center, k)
	if absf(zoom - target_zoom) < SNAP_ZOOM * target_zoom and center.distance_to(target_center) < SNAP_PX:
		snap()
	return true


## [param point] kept so that the screen shows only sheet (and a strip of
## desk) at [param at_zoom].
func clamp_center(point: Vector2, at_zoom: float) -> Vector2:
	var half := screen_size * 0.5 / at_zoom
	var edge := EDGE / at_zoom
	var result := point
	for axis in 2:
		if sheet_size[axis] <= half[axis] * 2.0:
			result[axis] = sheet_size[axis] * 0.5
		else:
			result[axis] = clampf(point[axis], half[axis] - edge, sheet_size[axis] - half[axis] + edge)
	return result


## How much of the room names shows at [param at_zoom]: none while their
## type would be under MapStyle.NAME_MIN_SCREEN px on screen, all of it a
## few px later.
static func name_alpha(at_zoom: float) -> float:
	return clampf((at_zoom * MapStyle.ROOM_SIZE - MapStyle.NAME_MIN_SCREEN) / 3.0, 0.0, 1.0)


## How strong the wings' big names are at [param at_zoom]: full when the
## whole floor shows, fading to a watermark close up.
func wing_alpha(at_zoom: float) -> float:
	var t := clampf((at_zoom / fit_zoom() - 1.8) / 1.8, 0.0, 1.0)
	return lerpf(1.0, 0.28, t)


## The sheet's transform on screen (scale, then offset).
func transform() -> Transform2D:
	return Transform2D(0.0, Vector2(zoom, zoom), 0.0, screen_size * 0.5 - center * zoom)
