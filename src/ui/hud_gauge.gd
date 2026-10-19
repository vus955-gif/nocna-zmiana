class_name HudGauge
extends Control
## A HUD bar as a brass instrument: a sunken channel in a brass mount (a dark
## hairline outside it for pale backgrounds), the fill with a glassy sheen
## along its top, an engraved scale; optionally bold notches (a boss's
## phases, with brass finials at the ends), a pale trail that catches up
## with a fall a moment later, and a pulse of the mount while the value is
## low. Hud.StaminaBar draws its mount and channel with the same static
## functions, so every bar of the HUD is one instrument family.

## Seconds a fall's trail holds before it starts to catch up, and its speed.
const TRAIL_HOLD := 0.45
const TRAIL_SPEED := 0.55
## Width of the finials at a boss bar's ends.
const FINIAL := 14.0

## 0..1 (like a ProgressBar with max_value 1).
var value: float = 1.0:
	set(next):
		next = clampf(next, 0.0, 1.0)
		if next == value:
			return
		if trail and next < value:
			_trail_value = maxf(_trail_value, value)
			_trail_hold = TRAIL_HOLD
		value = next
		if not trail or _trail_value < value:
			_trail_value = value
		queue_redraw()

## The fill's colour.
var fill: Color = Color(0.85, 0.2, 0.16)
## Divisions of the engraved scale (0: none).
var divisions: int = 0
## Shares where bold notches stand (a boss's phases).
var marks: Array[float] = []
## A boss bar: finials at the ends, the trail of a fall.
var finials: bool = false
var trail: bool = false
## The mount pulses while the value is above 0 and below this share.
var low_pulse: float = 0.0

var _trail_value: float = 1.0
var _trail_hold: float = 0.0
var _pulse: float = 0.0


static func make(min_size: Vector2, tint: Color, scale_divisions: int = 0) -> HudGauge:
	var gauge := HudGauge.new()
	gauge.custom_minimum_size = min_size
	gauge.fill = tint
	gauge.divisions = scale_divisions
	gauge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return gauge


## The trail's share (equal to the value when nothing trails).
func trail_value() -> float:
	return _trail_value


## 0..1 of the low pulse now (0 when the value is not low).
func pulse() -> float:
	if low_pulse <= 0.0 or value <= 0.0 or value >= low_pulse:
		return 0.0
	return 0.5 + 0.5 * sin(_pulse * TAU * 0.9)


func _process(delta: float) -> void:
	if _trail_value > value:
		_trail_hold -= delta
		if _trail_hold <= 0.0:
			_trail_value = move_toward(_trail_value, value, TRAIL_SPEED * delta)
		queue_redraw()
	if low_pulse > 0.0 and value > 0.0 and value < low_pulse:
		_pulse += delta
		queue_redraw()
	elif _pulse != 0.0:
		_pulse = 0.0
		queue_redraw()


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	if finials:
		_draw_finials(rect)
		rect = rect.grow_individual(-FINIAL, 0.0, -FINIAL, 0.0)
	var channel := draw_mount(self, rect, pulse())
	if _trail_value > value:
		var from := channel.size.x * value
		draw_rect(Rect2(channel.position + Vector2(from, 0.0), Vector2(channel.size.x * _trail_value - from, channel.size.y)), Color(fill.lightened(0.55), 0.85))
	draw_fill(self, Rect2(channel.position, Vector2(channel.size.x * value, channel.size.y)), fill)
	draw_scale(self, channel, divisions)
	for at in marks:
		var x := channel.position.x + channel.size.x * at
		draw_rect(Rect2(x - 1.0, channel.position.y, 2.0, channel.size.y), Color(0.0, 0.0, 0.0, 0.8))
		var brass := UiTheme.BRASS
		for side in [-1.0, 1.0]:
			var edge := channel.position.y if side < 0.0 else channel.end.y
			var tip := Vector2(x, edge + side * 1.0)
			draw_colored_polygon(PackedVector2Array([tip + Vector2(-4.0, side * 5.0), tip + Vector2(4.0, side * 5.0), tip]), brass)


## Brass finials (a lozenge on a short bar) at both ends of [param rect].
func _draw_finials(rect: Rect2) -> void:
	var mid := rect.position.y + rect.size.y * 0.5
	var brass := UiTheme.BRASS
	for side in [0, 1]:
		var x := rect.position.x + FINIAL * 0.5 if side == 0 else rect.end.x - FINIAL * 0.5
		var half := minf(rect.size.y * 0.5 + 2.0, 9.0)
		var lozenge := PackedVector2Array([Vector2(x, mid - half), Vector2(x + 6.0, mid), Vector2(x, mid + half), Vector2(x - 6.0, mid)])
		var shade := PackedVector2Array()
		for point in lozenge:
			shade.append(point + Vector2(0.0, 1.5))
		draw_colored_polygon(shade, Color(0.0, 0.0, 0.0, 0.6))
		draw_colored_polygon(lozenge, brass)
		draw_line(Vector2(x, mid - half + 2.0), Vector2(x - 4.0, mid), brass.lightened(0.4), 1.0)


## The mount of a bar over [param rect] on [param canvas]: a dark hairline,
## the brass rule (brighter by [param glow] 0..1), the sunken channel.
## Returns the channel's rect (where the fill goes).
static func draw_mount(canvas: CanvasItem, rect: Rect2, glow: float = 0.0) -> Rect2:
	var brass := UiTheme.BRASS.lerp(Color(1.0, 0.45, 0.35), glow * 0.7)
	canvas.draw_rect(rect, Color(0.0, 0.0, 0.0, 0.6))
	var rule := rect.grow(-1.0)
	canvas.draw_rect(rule, Color(brass.darkened(0.25), 0.95))
	canvas.draw_rect(Rect2(rule.position, Vector2(rule.size.x, 1.0)), Color(brass.lightened(0.3), 0.95))
	var channel := rule.grow(-1.5)
	canvas.draw_rect(channel, UiTheme.CHANNEL)
	canvas.draw_rect(Rect2(channel.position, Vector2(channel.size.x, 1.0)), Color(0.0, 0.0, 0.0, 0.55))
	return channel


## A fill of [param tint] over [param rect] with a glassy band along its
## top and a darker foot.
static func draw_fill(canvas: CanvasItem, rect: Rect2, tint: Color) -> void:
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	canvas.draw_rect(rect, tint)
	var band := maxf(floorf(rect.size.y * 0.32), 1.0)
	canvas.draw_rect(Rect2(rect.position, Vector2(rect.size.x, band)), Color(tint.lightened(0.35), 0.75 * tint.a))
	if rect.size.y >= 4.0:
		canvas.draw_rect(Rect2(rect.position.x, rect.end.y - 1.0, rect.size.x, 1.0), Color(tint.darkened(0.45), tint.a))


## The engraved scale: [param count] divisions as short dark ticks down
## from the channel's top edge.
static func draw_scale(canvas: CanvasItem, channel: Rect2, count: int) -> void:
	if count < 2:
		return
	var depth := maxf(channel.size.y * 0.45, 2.0)
	for i in range(1, count):
		var x := roundf(channel.position.x + channel.size.x * i / count)
		var major := count % 2 == 0 and i == count / 2
		canvas.draw_rect(Rect2(x, channel.position.y, 1.0, channel.size.y if major else depth), Color(0.0, 0.0, 0.0, 0.42))
