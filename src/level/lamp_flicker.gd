class_name LampFlicker
extends Node
## The lamps of the flicker_lights group under the same parent (main lamps
## on a bad circuit: the basement's tubes) stutter: steady for a while, then
## a short burst of dips and drop-outs, irregular for each lamp. Only the
## energy changes (cheap; the light model counts a flickering lamp as lit);
## a lamp switched off (blackout, power cut: NightModifiers.set_lights) is
## left dark.

## Steady between bursts (s), and the blinks of a burst.
const STEADY := Vector2(0.4, 3.5)
const BLINKS := Vector2i(1, 4)
## One blink: how long (s) and how dark (fraction of the lamp's energy).
const BLINK_TIME := Vector2(0.03, 0.14)
const BLINK_LEVEL := Vector2(0.0, 0.45)

var lamps: Array[Light3D] = []
## Lamp -> its full energy.
var _base: Dictionary = {}
## Lamp -> seconds left of the current state.
var _left: Dictionary = {}
## Lamp -> blinks left in its burst (0: steady).
var _blinks: Dictionary = {}
var _rng := RandomNumberGenerator.new()


## Adds a flicker to [param parent] when it holds flicker lamps (null when
## none).
static func attach(parent: Node) -> LampFlicker:
	var found: Array[Light3D] = []
	for node in parent.get_children():
		if node is Light3D and node.is_in_group(LightSpec.FLICKER):
			found.append(node)
	if found.is_empty():
		return null
	var flicker := LampFlicker.new()
	flicker.name = "LampFlicker"
	flicker.lamps = found
	parent.add_child(flicker)
	return flicker


func _ready() -> void:
	_rng.seed = hash(get_path())
	for lamp in lamps:
		_base[lamp] = lamp.light_energy
		_left[lamp] = _rng.randf_range(STEADY.x, STEADY.y)
		_blinks[lamp] = 0


func _process(delta: float) -> void:
	for lamp in lamps:
		if not is_instance_valid(lamp) or not lamp.visible:
			continue
		var left: float = _left[lamp] - delta
		if left > 0.0:
			_left[lamp] = left
			continue
		var blinks: int = _blinks[lamp]
		if blinks <= 0:
			# a burst begins: the first drop
			_blinks[lamp] = _rng.randi_range(BLINKS.x, BLINKS.y) * 2 - 1
			_dip(lamp)
		elif blinks % 2 == 1:
			# back up between two drops (or the burst ends)
			_blinks[lamp] = blinks - 1
			lamp.light_energy = _base[lamp]
			_left[lamp] = _rng.randf_range(BLINK_TIME.x, BLINK_TIME.y) if blinks > 1 else _rng.randf_range(STEADY.x, STEADY.y)
		else:
			_blinks[lamp] = blinks - 1
			_dip(lamp)


## The lamp's full energy.
func base_energy(lamp: Light3D) -> float:
	return _base.get(lamp, lamp.light_energy)


func _dip(lamp: Light3D) -> void:
	lamp.light_energy = float(_base[lamp]) * _rng.randf_range(BLINK_LEVEL.x, BLINK_LEVEL.y)
	_left[lamp] = _rng.randf_range(BLINK_TIME.x, BLINK_TIME.y)
