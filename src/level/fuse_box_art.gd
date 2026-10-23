class_name FuseBoxArt
extends Node3D
## The look of the hall's fuse cabinet (ArtKit "fuse_box": a wired window
## onto two porcelain sockets, a red and a green lamp, a knife switch on the
## side) driven by the night from the level side, read-only: its lamps
## follow the game's fuse box (the level_kit piece "fuse_box_front" in
## front of it: red until both fuses are in, then green) and the switch
## drops when the power is cut (Events.power_cut). It is the piece's
## "Visual".

## The switch's turn about its axle: up (mains on) and down (cut).
const LEVER_ON := deg_to_rad(40.0)
const LEVER_OFF := deg_to_rad(-40.0)
const LEVER_TIME := 0.18
## How often (s) the lamps look at the game's fuse box.
const POLL := 0.25
## Group of the game's fuse boxes (FuseBox joins it): a cabinet with none in
## front of it (three of Floor I's four) looks for one every 2 s, among
## these only - the whole "level_kit" group, thousands of pieces, was 6-14 ms
## every 2 s for the four cabinets together (plan 2026-10-21-wydajnosc-cpu).
const BOX_GROUP := &"fuse_boxes"

## Smoked, unlit copies of the lamp materials (shared).
static var _dark: Dictionary = {}

var power_on: bool = true
var fuses: int = 0

var _lever: Node3D = null
var _lever_rest := Transform3D.IDENTITY
var _red: Node3D = null
var _green: Node3D = null
var _box: Node3D = null
var _wait: float = 0.0


func _ready() -> void:
	_lever = find_child("lever", true, false) as Node3D
	_red = find_child("lamp_red", true, false) as Node3D
	_green = find_child("lamp_green", true, false) as Node3D
	if _lever != null:
		_lever_rest = _lever.transform
	Events.power_cut.connect(_on_power_cut)
	_show()


func _process(delta: float) -> void:
	_wait -= delta
	if _wait > 0.0:
		return
	_wait = POLL
	if not is_instance_valid(_box):
		_box = _find_box()
		if _box == null:
			_wait = POLL * 8.0   # no game here (the dev lobby): look again later
			return
	if _box != null and _box.has_method(&"inserted"):
		var count: int = _box.call(&"inserted")
		if count != fuses:
			fuses = count
			# both fuses in means the relay has tripped (also on a night that
			# resumes after the cut, which raises no event)
			var cut := fuses >= 2 and power_on
			if cut:
				power_on = false
			_show(cut)


## Sets the look at once (a night that resumes after the cut).
func set_state(inserted: int, mains: bool) -> void:
	fuses = inserted
	power_on = mains
	_show()


func _on_power_cut() -> void:
	power_on = false
	fuses = maxi(fuses, 2)
	_show(true)


func _show(animate: bool = false) -> void:
	_lamp(_red, fuses < 2)
	_lamp(_green, fuses >= 2)
	if _lever == null:
		return
	var pose := _lever_rest * Transform3D(Basis(Vector3.RIGHT, LEVER_ON if power_on else LEVER_OFF), Vector3.ZERO)
	if animate and is_inside_tree():
		create_tween().tween_property(_lever, ^"transform", pose, LEVER_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	else:
		_lever.transform = pose


## A lamp dome lit (its own paint and glow) or dark (a smoked, unlit copy:
## a red or green glass reads as lit even without its glow).
func _lamp(part: Node3D, lit: bool) -> void:
	if part == null:
		return
	for node in part.find_children("*", "MeshInstance3D", true, false) + ([part] if part is MeshInstance3D else []):
		var view := node as MeshInstance3D
		if lit:
			view.material_override = null
			continue
		if view.material_override != null:
			continue
		var source := view.get_active_material(0) as BaseMaterial3D
		if source == null:
			continue
		if not _dark.has(source):
			var dark := source.duplicate() as BaseMaterial3D
			dark.emission_energy_multiplier = 0.0
			dark.albedo_color = Color(0.22, 0.22, 0.22)
			_dark[source] = dark
		view.material_override = _dark[source]


## The game's fuse box in front of this cabinet (within a metre and a half),
## or null.
func _find_box() -> Node3D:
	if not is_inside_tree():
		return null
	for node in get_tree().get_nodes_in_group(BOX_GROUP):
		var piece := node as Node3D
		if piece != null and piece.get_meta(&"kit", &"") == &"fuse_box_front" and piece.global_position.distance_to(global_position) < 1.5:
			return piece
	return null
