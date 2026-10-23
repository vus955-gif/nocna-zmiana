class_name PerfGraph
extends Control
## The last frames of the dev overlay as thin bars (height = frame time),
## the 60 fps line (16.7 ms) and the 30 fps line (33.3 ms) across them.

## The top of the graph (ms).
const SCALE_MS := 40.0
const FRAME_60 := 16.7
const FRAME_30 := 33.3

## Frame times (ms), newest at [member head] - 1 (a ring).
var frames := PackedFloat32Array()
var head: int = 0


func _draw() -> void:
	if frames.is_empty():
		return
	var count := frames.size()
	var step := size.x / count
	for i in count:
		var ms := frames[(head + i) % count]
		if ms <= 0.0:
			continue
		var height := clampf(ms / SCALE_MS, 0.02, 1.0) * size.y
		var color := UiTheme.GOOD
		if ms > FRAME_30:
			color = UiTheme.DANGER
		elif ms > FRAME_60:
			color = UiTheme.ACCENT
		draw_rect(Rect2(i * step, size.y - height, maxf(step - 0.5, 1.0), height), color)
	for line: float in [FRAME_60, FRAME_30]:
		var y := size.y - line / SCALE_MS * size.y
		draw_line(Vector2(0.0, y), Vector2(size.x, y), Color(UiTheme.TEXT, 0.35), 1.0)
