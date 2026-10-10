class_name ReliefPanel
extends Node3D
## The wall slab a relief figure sleeps in and steps out of (design
## pietro-1-projekt 5.2): the awakening slabs "asy_relief_wake" (a life-size
## spearman) and "asy_relief_wake_lion" (a striding lion), origin on the
## floor in the wall's plane, the slab on the room side (front -Z). The
## figure is its own part ("figure") in a pocket of its shape: while the
## figure sleeps it is the slab's; the cracks round it are in the emission
## map, dark at rest - the telegraph lights them (and a warm light from
## within), dust bursts when they open, and once the figure has stepped out
## the empty pocket with its fresh break stays. The enemy stands where the
## carved figure stood (figure_offset). Without the models a greybox slab
## with crack lines and a dark recess stands in.

enum Kind { WARRIOR, LION }

const MODELS := {Kind.WARRIOR: &"asy_relief_wake", Kind.LION: &"asy_relief_wake_lion"}
## Where the enemy stands from the slab's origin (docs/art/kit-pietro1-asyria.md).
const FIGURE_AT := {Kind.WARRIOR: Vector3(0.13, 0.0, -0.1), Kind.LION: Vector3(-0.06, 0.0, -0.1)}
## The greybox's size (width, height).
const GREY_SIZE := {Kind.WARRIOR: Vector2(1.1, 2.2), Kind.LION: Vector2(1.7, 1.25)}
const DEPTH := 0.05
## A slab stands this far proud of the wall, clear of the level's own relief band.
const PROUD := 0.006
## Emission of the cracks at full telegraph.
const CRACK_ENERGY := 6.0
const CRACK_COLOR := Color(1.0, 0.62, 0.3)
## Greybox crack lines (from, to; 0..1 of the slab's width and height).
const CRACKS := [
	[Vector2(0.12, 0.05), Vector2(0.2, 0.42)], [Vector2(0.2, 0.42), Vector2(0.1, 0.8)],
	[Vector2(0.1, 0.8), Vector2(0.45, 0.97)], [Vector2(0.45, 0.97), Vector2(0.88, 0.78)],
	[Vector2(0.88, 0.78), Vector2(0.8, 0.4)], [Vector2(0.8, 0.4), Vector2(0.9, 0.06)],
	[Vector2(0.2, 0.42), Vector2(0.02, 0.5)], [Vector2(0.8, 0.4), Vector2(0.98, 0.32)],
]

var kind: Kind = Kind.WARRIOR
## The carved figure stands in for the enemy while it sleeps here (the
## model's "figure" part; the greybox has none: the enemy shows itself).
var figure: Node3D = null

var _model: Node3D = null
var _glow_materials: Array[BaseMaterial3D] = []
var _cracks: Array[MeshInstance3D] = []
var _crack_material: StandardMaterial3D
var _recess: MeshInstance3D
var _light: OmniLight3D
var _level: float = -1.0
var _empty := false


## A slab of [param kind_] at [param at] (origin on the wall's face at the
## floor, front into the room), not in the tree yet.
static func build(kind_: Kind, at: Transform3D) -> ReliefPanel:
	var panel := ReliefPanel.new()
	panel.name = "ReliefPanel"
	panel.kind = kind_
	panel.transform = at
	return panel


func _ready() -> void:
	_model = ArtLibrary.try_instance(MODELS[kind])
	if _model != null:
		_model.position = Vector3(0.0, 0.0, -PROUD)
		add_child(_model)
		figure = ArtLibrary.parts(_model).get("figure") as Node3D
		for mat in ArtLibrary.own_materials(_model):
			if mat.emission_enabled:
				_glow_materials.append(mat)
	else:
		_build_greybox()
	_light = OmniLight3D.new()
	_light.light_color = CRACK_COLOR
	_light.omni_range = 2.8
	_light.shadow_enabled = false
	_light.position = Vector3(0.0, 1.1 if kind == Kind.WARRIOR else 0.7, -0.45)
	_light.visible = false
	add_child(_light)
	crack(0.0)


## Where the enemy stands when it is the slab's figure (world).
func figure_point() -> Vector3:
	return global_transform * FIGURE_AT[kind]


## How far the cracking has gone (0 whole .. 1 split, glowing hot).
func crack(level: float) -> void:
	level = clampf(level, 0.0, 1.0)
	if is_equal_approx(level, _level):
		return
	if _level < 1.0 and level >= 1.0 and is_inside_tree():
		Fx.puff(figure_point() + Vector3.UP * (1.0 if kind == Kind.WARRIOR else 0.6) - global_basis.z * 0.2,
				Color(0.7, 0.72, 0.72), 30, 0.8)
	_level = level
	for mat in _glow_materials:
		mat.emission_energy_multiplier = CRACK_ENERGY * level * (0.6 + 0.4 * level)
	for i in _cracks.size():
		_cracks[i].visible = level > float(i) / _cracks.size() * 0.85
	if _crack_material != null:
		_crack_material.emission_energy_multiplier = 0.5 + 5.0 * level * level
	_light.visible = level > 0.02
	_light.light_energy = 1.6 * level


## The figure has left it (the empty pocket shows) or is back in it.
func set_empty(empty: bool) -> void:
	_empty = empty
	if figure != null:
		figure.visible = not empty
	if _recess != null:
		_recess.visible = empty


func is_empty() -> bool:
	return _empty


## The carved figure shows (the enemy's own model hides meanwhile).
func shows_figure() -> bool:
	return figure != null and not _empty


func crack_level() -> float:
	return maxf(_level, 0.0)


func _build_greybox() -> void:
	var size: Vector2 = GREY_SIZE[kind]
	var stone := GreyboxArt.material("grey_alabaster")
	var slab := GreyboxArt.part(self, "slab", GreyboxArt.box(Vector3(size.x, size.y, DEPTH)), Vector3(0.0, size.y * 0.5, -DEPTH * 0.5 - PROUD), stone)
	slab.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.16, 0.17, 0.19)
	dark.roughness = 0.95
	_recess = MeshInstance3D.new()
	_recess.name = "recess"
	_recess.mesh = GreyboxArt.box(Vector3(size.x * 0.72, size.y * 0.9, 0.004))
	_recess.position = Vector3(0.0, size.y * 0.47, -DEPTH - PROUD - 0.003)
	_recess.material_override = dark
	_recess.visible = false
	add_child(_recess)
	_crack_material = StandardMaterial3D.new()
	_crack_material.albedo_color = Color(0.1, 0.05, 0.02)
	_crack_material.emission_enabled = true
	_crack_material.emission = CRACK_COLOR
	_crack_material.emission_energy_multiplier = 0.0
	for line: Array in CRACKS:
		var a := _on_slab(line[0], size)
		var b := _on_slab(line[1], size)
		var crack_line := MeshInstance3D.new()
		crack_line.mesh = GreyboxArt.box(Vector3(0.022, a.distance_to(b), 0.006))
		crack_line.position = (a + b) * 0.5
		crack_line.rotation.z = -atan2(b.x - a.x, b.y - a.y)
		crack_line.material_override = _crack_material
		crack_line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		crack_line.visible = false
		add_child(crack_line)
		_cracks.append(crack_line)


func _on_slab(uv: Vector2, size: Vector2) -> Vector3:
	return Vector3((uv.x - 0.5) * size.x, uv.y * size.y, -DEPTH - PROUD - 0.004)
