class_name EnvTag
extends Node3D
## The one sign of the museum's tools (plan docs/superpowers/plans/
## 2026-10-21-srodowisko-walka.md, backlog #39): a loose steel bolt in its
## mount with a pulsing red ring round its head, and a conservator's card on
## a string under it - white, a red band, "USTERKA". Only the tools wear it,
## and nothing else in the museum glows red like it, so the guard learns
## one rule: a red tag is a loose mount - shoot it and the thing it holds
## comes down (or goes off). Its hit zone (a sphere a good deal larger than
## the bolt) is the tool's trigger: any hit at all - a round, a pellet, an
## arc, a blast beside it - sets the tool going (EnvTool.tag_hit). Spent (its
## tool gone off) its ring goes dark and the hint no longer points at it.
## Built facing -Z (the side the guard looks from).

## The ring's glow: low and high of the pulse, the pulse's period (s).
const GLOW := Vector2(1.6, 4.2)
const PERIOD := 1.4
const RED := Color(1.0, 0.08, 0.04)
## The bolt's steel, the card and its red band.
const STEEL := Color(0.55, 0.56, 0.58)
const PAPER := Color(0.93, 0.91, 0.84)
const BAND := Color(0.8, 0.07, 0.05)
## The zone's radius at scale 1 (m).
const ZONE := 0.3

static var _ring: StandardMaterial3D = null
static var _dark: StandardMaterial3D = null
static var _plain: Dictionary = {}

## The tool it sets off.
var tool: Node = null
## Spent: the ring is dark, no hint, hits do nothing.
var spent: bool = false
var zone: Hurtbox = null

var _ring_view: MeshInstance3D = null


## A tag for [param owner_tool] at [param scale_] (a far mount wears it
## larger so it reads from the floor).
static func make(owner_tool: Node, scale_: float = 1.0) -> EnvTag:
	var tag := EnvTag.new()
	tag.name = "Tag"
	tag.tool = owner_tool
	tag.scale = Vector3.ONE * scale_
	return tag


## Pulses every tag's ring (one shared material) at [param clock] seconds.
static func pulse(clock: float) -> void:
	if _ring == null:
		return
	var wave := 0.5 + 0.5 * sin(clock * TAU / PERIOD)
	_ring.emission_energy_multiplier = lerpf(GLOW.x, GLOW.y, wave)


static func ring_material() -> StandardMaterial3D:
	if _ring == null:
		_ring = StandardMaterial3D.new()
		_ring.albedo_color = RED
		_ring.emission_enabled = true
		_ring.emission = RED
		_ring.emission_energy_multiplier = GLOW.y
		_ring.roughness = 0.4
	return _ring


## The materials a tag is drawn with (its ring lit and dark, its steel,
## card and band) and the one a broken pane wears (EnvBreak.invisible):
## the night start's warm-up draws them once (ShaderWarmUp).
static func warm_set() -> Array[Material]:
	return [ring_material(), _dark_material(), EnvBreak.invisible(),
		_material(STEEL, 0.35, 0.9), _material(PAPER, 0.9, 0.0), _material(BAND, 0.8, 0.0)]


func _ready() -> void:
	_build()
	var sphere := SphereShape3D.new()
	sphere.radius = ZONE
	zone = Hurtbox.make(self, sphere, Vector3(0.0, -0.05, -0.05))
	zone.name = "TagZone"
	add_child(zone)


## A hit on the tag: the tool goes off (unless spent).
func take_damage(info: DamageInfo) -> void:
	if spent or tool == null or not is_instance_valid(tool):
		return
	Fx.impact(global_position, info.normal if info.normal.length() > 0.1 else global_basis.z, ExhibitMaterial.Kind.METAL, 0.8)
	Events.hit_landed.emit(self, info, false)
	tool.call(&"tag_hit", info)


func set_spent(value: bool) -> void:
	spent = value
	if _ring_view != null:
		_ring_view.material_override = _dark_material() if value else ring_material()


## Off for good (its tool lies broken): no zone, no glow.
func retire() -> void:
	set_spent(true)
	if is_instance_valid(zone):
		zone.collision_layer = 0


func _build() -> void:
	var steel := _material(STEEL, 0.35, 0.9)
	var paper := _material(PAPER, 0.9, 0.0)
	var band := _material(BAND, 0.8, 0.0)
	var bolt := _cylinder(0.022, 0.13, steel, 16)
	bolt.rotation.x = PI * 0.5
	bolt.position = Vector3(0.0, 0.0, -0.02)
	var head := _cylinder(0.045, 0.03, steel, 6)
	head.rotation.x = PI * 0.5
	head.position = Vector3(0.0, 0.0, -0.085)
	var torus := TorusMesh.new()
	torus.inner_radius = 0.05
	torus.outer_radius = 0.078
	torus.rings = 20
	torus.ring_segments = 8
	_ring_view = MeshInstance3D.new()
	_ring_view.name = "Ring"
	_ring_view.mesh = torus
	_ring_view.rotation.x = PI * 0.5
	_ring_view.position = Vector3(0.0, 0.0, -0.08)
	_ring_view.material_override = ring_material()
	_ring_view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ring_view)
	_box(Vector3(0.004, 0.07, 0.004), Vector3(0.0, -0.06, -0.09), steel)   # the string
	_box(Vector3(0.1, 0.15, 0.004), Vector3(0.0, -0.17, -0.092), paper)   # the card
	_box(Vector3(0.1, 0.036, 0.005), Vector3(0.0, -0.125, -0.093), band)   # its red band
	var label := Label3D.new()
	label.text = tr("ENV_TAG_TEXT")
	label.font_size = 40
	label.outline_size = 0
	label.pixel_size = 0.0011
	label.modulate = Color(0.55, 0.05, 0.03)
	label.position = Vector3(0.0, -0.19, -0.095)
	label.rotation.y = PI
	label.width = 85.0
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	add_child(label)


func _cylinder(radius: float, height: float, mat: Material, sides: int) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = sides
	mesh.rings = 1
	var view := MeshInstance3D.new()
	view.mesh = mesh
	view.material_override = mat
	add_child(view)
	return view


func _box(size: Vector3, at: Vector3, mat: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var view := MeshInstance3D.new()
	view.mesh = mesh
	view.material_override = mat
	view.position = at
	view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(view)
	return view


static func _dark_material() -> StandardMaterial3D:
	if _dark == null:
		_dark = StandardMaterial3D.new()
		_dark.albedo_color = Color(0.25, 0.05, 0.04)
		_dark.roughness = 0.6
	return _dark


static func _material(color: Color, roughness: float, metallic: float) -> StandardMaterial3D:
	var key := "%s/%s/%s" % [color, roughness, metallic]
	if not _plain.has(key):
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		mat.roughness = roughness
		mat.metallic = metallic
		_plain[key] = mat
	return _plain[key]
