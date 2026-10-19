class_name SecretRewardDisplay
extends Interactable
## A secret's reward on show in its room (SecretRewards; plan
## 2026-10-10-nagrody-sekretow): a small exhibit of its own, built in code
## at the secret_* marker, facing the room (-Z).
## - SMALL: an iron strongbox on the floor, its lid shut until the secret is
##   found; the pouch of Dust inside,
## - MEDIUM: a plinth with a velvet cushion, the find on it, a brass plaque
##   with its name,
## - GREAT: the same plinth under a glass case with brass trim.
## A narrow reflector hangs over it, dark until reveal() (the secret's
## discovery: the lid opens, the light comes on, the exhibit turns slowly).
## E takes the reward ([signal taken]); the exhibit is gone, the plinth,
## the plaque and the light stay - the museum's own record that something
## was here (set_taken() for a reward claimed on an earlier night).

signal taken(secret_id: StringName)

const PLINTH := Vector3(0.5, 0.9, 0.5)
const CASE_HEIGHT := 0.6
const BOX := Vector3(0.46, 0.3, 0.36)
const CUSHION := Vector3(0.32, 0.04, 0.32)
const LIGHT_HEIGHT := 2.6
const LIGHT_ENERGY := 1.5
const REVEAL_TIME := 0.9
## The lid's free edge swings up and a little past upright (+X turns -Z up).
const LID_OPEN := 1.75
const SPIN := 0.5
## The use-zone: the whole exhibit, a little wider than the case.
const ZONE := Vector3(1.1, 2.0, 1.1)

static var _materials: Dictionary = {}

var secret_id: StringName = &""
var entry: SecretRewards.Entry = null
var tier: SecretRewards.Tier = SecretRewards.Tier.SMALL
## The reward was taken (tonight or on an earlier night).
var is_taken: bool = false
## The secret is found: the reflector is on.
var lit: bool = false

var _exhibit: Node3D
var _light: SpotLight3D
var _label: Label3D = null
var _lid: Node3D = null
var _exhibit_rest: float = 0.0
var _time: float = 0.0


## The floor a display of [param tier] covers (x across, y deep; the
## plinth's base is wider than its shaft, the strongbox is the box).
static func footprint(tier: SecretRewards.Tier) -> Vector2:
	if tier == SecretRewards.Tier.SMALL:
		return Vector2(BOX.x, BOX.z)
	return Vector2(PLINTH.x + 0.08, PLINTH.z + 0.08)


static func make(reward: SecretRewards.Entry, at: Transform3D) -> SecretRewardDisplay:
	var display := SecretRewardDisplay.new()
	display.secret_id = reward.id
	display.entry = reward
	display.tier = reward.tier
	display.transform = at
	display.name = "Reward_" + String(reward.id)
	return display


func _init() -> void:
	super()
	prompt_key = "PROMPT_TAKE_ITEM"


func prompt() -> String:
	return tr(prompt_key) % tr(entry.name_key())


func can_interact(by: Node) -> bool:
	return super(by) and not is_taken


func _ready() -> void:
	add_box(ZONE, Vector3(0.0, ZONE.y * 0.5, 0.0))
	_exhibit = Node3D.new()
	_exhibit.name = "Exhibit"
	add_child(_exhibit)
	match tier:
		SecretRewards.Tier.SMALL:
			_build_strongbox()
		SecretRewards.Tier.MEDIUM:
			_build_plinth(false)
		SecretRewards.Tier.GREAT:
			_build_plinth(true)
	_build_exhibit()
	_light = SpotLight3D.new()
	_light.name = "Reflector"
	_light.position = Vector3(0.0, LIGHT_HEIGHT, 0.0)
	_light.rotation.x = -PI * 0.5
	_light.light_color = SecretRewards.color(tier)
	_light.light_energy = 0.0
	_light.spot_range = LIGHT_HEIGHT + 0.6
	_light.spot_angle = 26.0
	_light.spot_attenuation = 1.2
	_light.shadow_enabled = false
	_light.visible = false
	add_child(_light)
	_time = randf() * TAU
	set_process(lit and not is_taken)   # nothing to animate until the secret is found


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and _label != null and entry != null:
		_label.text = tr(entry.name_key())


func _process(delta: float) -> void:
	_time += delta
	_exhibit.rotation.y = _time * SPIN
	_exhibit.position.y = _exhibit_rest + (sin(_time * 1.6) * 0.5 + 0.5) * 0.015
	_light.light_energy = LIGHT_ENERGY * (0.96 + 0.04 * sin(_time * 2.3))


## Out of sight and out of reach until the secret is found (a reward in an
## open room: the hollow behind a loose stone, the drawer under a counter).
func hide_away() -> void:
	visible = false
	collision_layer = 0


## The secret is found: the display shows, the reflector comes on (at once
## with [param instant]: a secret found on an earlier night), the lid opens.
func reveal(instant: bool = false) -> void:
	if lit:
		return
	lit = true
	visible = true
	if not is_taken:
		collision_layer = Layers.INTERACT
		set_process(true)
	_light.visible = true
	if instant:
		_light.light_energy = LIGHT_ENERGY
		if _lid != null:
			_lid.rotation.x = LID_OPEN
		return
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_light, ^"light_energy", LIGHT_ENERGY, REVEAL_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if _lid != null:
		tween.tween_property(_lid, ^"rotation:x", LID_OPEN, REVEAL_TIME * 0.7).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## The reward is the guard's: the exhibit is gone, the use-zone with it.
func set_taken() -> void:
	is_taken = true
	set_process(false)
	_exhibit.visible = false
	enabled = false
	collision_layer = 0
	if _light != null and lit:
		_light.light_energy = LIGHT_ENERGY * 0.6


func interact(by: Node) -> void:
	if is_taken or not enabled:
		return
	super(by)
	set_taken()
	taken.emit(secret_id)


# --- the furniture -------------------------------------------------------------

## An iron strongbox on the floor, its lid hinged at the back.
func _build_strongbox() -> void:
	var iron := _mat(&"iron", Color(0.2, 0.2, 0.22), 0.55, 0.8)
	var wall := 0.02
	_box(self, Vector3(BOX.x, wall, BOX.z), Vector3(0.0, wall * 0.5, 0.0), iron)
	_box(self, Vector3(BOX.x, BOX.y - wall, wall), Vector3(0.0, BOX.y * 0.5, BOX.z * 0.5 - wall * 0.5), iron)
	_box(self, Vector3(BOX.x, BOX.y - wall, wall), Vector3(0.0, BOX.y * 0.5, -BOX.z * 0.5 + wall * 0.5), iron)
	for side in [-1.0, 1.0]:
		_box(self, Vector3(wall, BOX.y - wall, BOX.z), Vector3(side * (BOX.x * 0.5 - wall * 0.5), BOX.y * 0.5, 0.0), iron)
	_lid = Node3D.new()
	_lid.name = "Lid"
	_lid.position = Vector3(0.0, BOX.y, BOX.z * 0.5)
	add_child(_lid)
	_box(_lid, Vector3(BOX.x + 0.02, wall, BOX.z + 0.01), Vector3(0.0, wall * 0.5, -BOX.z * 0.5), iron)
	_box(_lid, Vector3(0.06, 0.015, 0.03), Vector3(0.0, wall, -BOX.z + 0.03), _mat(&"brass", Color(0.78, 0.62, 0.3), 0.3, 0.9))   # the catch
	_plaque(Vector3(0.0, BOX.y * 0.55, -BOX.z * 0.5 - 0.006), 0.3, 0.06)
	_exhibit_rest = 0.06
	_exhibit.position.y = _exhibit_rest


## A plinth with a velvet cushion and a brass plaque; a glass case with
## brass trim over it for a treasure.
func _build_plinth(cased: bool) -> void:
	var stone := _mat(&"stone", Color(0.5, 0.49, 0.47), 0.85, 0.0)
	_box(self, PLINTH, Vector3(0.0, PLINTH.y * 0.5, 0.0), stone)
	_box(self, Vector3(PLINTH.x + 0.08, 0.05, PLINTH.z + 0.08), Vector3(0.0, 0.025, 0.0), stone)
	_box(self, Vector3(PLINTH.x + 0.04, 0.03, PLINTH.z + 0.04), Vector3(0.0, PLINTH.y - 0.015, 0.0), _mat(&"marble", Color(0.86, 0.85, 0.81), 0.4, 0.0))
	_box(self, CUSHION, Vector3(0.0, PLINTH.y + CUSHION.y * 0.5, 0.0), _mat(&"velvet", Color(0.34, 0.06, 0.08), 0.95, 0.0))
	_plaque(Vector3(0.0, PLINTH.y * 0.62, -PLINTH.z * 0.5 - 0.006), 0.36, 0.08)
	if cased:
		var glass := _box(self, Vector3(PLINTH.x - 0.02, CASE_HEIGHT, PLINTH.z - 0.02), Vector3(0.0, PLINTH.y + CASE_HEIGHT * 0.5, 0.0), LevelKit.glass())
		glass.name = "Glass"
		var brass := _mat(&"brass", Color(0.78, 0.62, 0.3), 0.3, 0.9)
		_box(self, Vector3(PLINTH.x, 0.03, PLINTH.z), Vector3(0.0, PLINTH.y + CASE_HEIGHT + 0.015, 0.0), brass)
		for x in [-1.0, 1.0]:
			for z in [-1.0, 1.0]:
				_box(self, Vector3(0.025, CASE_HEIGHT, 0.025), Vector3(x * (PLINTH.x * 0.5 - 0.0125), PLINTH.y + CASE_HEIGHT * 0.5, z * (PLINTH.z * 0.5 - 0.0125)), brass)
	_exhibit_rest = PLINTH.y + CUSHION.y
	_exhibit.position.y = _exhibit_rest


## The brass plaque on the front face with the reward's name engraved.
func _plaque(at: Vector3, width: float, height: float) -> void:
	var plate := _box(self, Vector3(width, height, 0.01), at, _mat(&"brass", Color(0.78, 0.62, 0.3), 0.3, 0.9))
	plate.name = "Plaque"
	_label = Label3D.new()
	_label.name = "Engraving"
	_label.text = tr(entry.name_key())
	_label.font = UiTheme.title_font()
	_label.font_size = 36
	_label.pixel_size = 0.00055
	_label.outline_size = 0
	_label.modulate = Color(0.2, 0.13, 0.06)
	_label.width = width / _label.pixel_size * 0.92
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.shaded = true
	# Label3D reads from +Z; the plaque faces -Z
	_label.transform = Transform3D(Basis(Vector3.UP, PI), Vector3(0.0, 0.0, -0.0055))
	plate.add_child(_label)


# --- the exhibit: the reward itself --------------------------------------------

## The reward on the cushion (or in the box): by secret for the finds, the
## pouch for a stash, a presentation case with a finished barrel section
## for a weapon's finish, the fitting itself for a mod.
func _build_exhibit() -> void:
	match entry.kind:
		SecretRewards.Kind.POUCH:
			_pouch()
		SecretRewards.Kind.LOOK:
			_finish_sample()
		SecretRewards.Kind.MOD:
			_fitting()
		_:
			_find()


## A leather pouch with Dust spilling from its neck.
func _pouch() -> void:
	var leather := _mat(&"leather", Color(0.42, 0.28, 0.16), 0.85, 0.0)
	_oval(Vector3(0.075, 0.08, 0.07), Vector3(0.0, 0.08, 0.0), leather)
	_oval(Vector3(0.035, 0.03, 0.035), Vector3(0.0, 0.16, 0.0), leather)
	var cord := TorusMesh.new()
	cord.inner_radius = 0.028
	cord.outer_radius = 0.034
	cord.rings = 16
	cord.ring_segments = 6
	_shape(cord, Vector3(0.0, 0.145, 0.0), _mat(&"cord", Color(0.25, 0.17, 0.1), 0.9, 0.0))
	var gold := _glow(Color(1.0, 0.84, 0.45), 2.2)
	for i in 5:
		var angle := TAU * i / 5.0 + 0.4
		_oval(Vector3(0.008, 0.008, 0.008), Vector3(cos(angle) * 0.02, 0.182 + (i % 2) * 0.006, sin(angle) * 0.02), gold)


## The finds, each its own small exhibit.
func _find() -> void:
	var brass := _mat(&"brass", Color(0.78, 0.62, 0.3), 0.3, 0.9)
	var steel := _mat(&"steel", Color(0.55, 0.57, 0.6), 0.45, 0.9)
	var leather := _mat(&"leather", Color(0.42, 0.28, 0.16), 0.85, 0.0)
	match secret_id:
		&"secret_egypt_2":   # the scarab amulet: faience and gold
			var faience := _mat(&"faience", Color(0.16, 0.55, 0.55), 0.35, 0.1)
			var gold := _mat(&"gold", Color(0.85, 0.66, 0.28), 0.3, 0.9)
			_oval(Vector3(0.07, 0.035, 0.09), Vector3(0.0, 0.035, 0.01), faience)
			_oval(Vector3(0.035, 0.024, 0.028), Vector3(0.0, 0.028, -0.09), gold)
			_shape(_cube(Vector3(0.008, 0.008, 0.16)), Vector3(0.0, 0.07, 0.01), gold)
			for side in [-1.0, 1.0]:
				for z in [-0.04, 0.01, 0.06]:
					_shape(_cube(Vector3(0.045, 0.008, 0.008)), Vector3(side * 0.08, 0.012, z), gold).rotation.y = side * z * 4.0
		&"secret_assyria_1":   # a clay tablet with rows of wedges
			var clay := _mat(&"clay", Color(0.76, 0.62, 0.45), 0.9, 0.0)
			var tablet := _shape(_cube(Vector3(0.14, 0.03, 0.19)), Vector3(0.0, 0.03, 0.0), clay)
			tablet.rotation.x = -0.35
			var mark := _mat(&"wedge", Color(0.5, 0.38, 0.26), 0.9, 0.0)
			for row in 5:
				for col in 6:
					var wedge := _shape(_cube(Vector3(0.012, 0.004, 0.005)), Vector3(-0.05 + col * 0.02, 0.046 + 0.03 * (row - 2) * 0.343, -0.07 + row * 0.033), mark)
					wedge.rotation.x = -0.35
					wedge.rotation.y = 0.3 * ((row + col) % 3 - 1)
		&"secret_asia_1":   # the armourer's mail shirt, folded on the cushion
			var mail := _mat(&"mail", Color(0.5, 0.52, 0.56), 0.55, 0.9)
			_shape(_cube(Vector3(0.24, 0.05, 0.2)), Vector3(0.0, 0.025, 0.0), mail)
			_shape(_cube(Vector3(0.2, 0.04, 0.16)), Vector3(0.01, 0.07, -0.01), mail)
			_oval(Vector3(0.06, 0.02, 0.06), Vector3(0.0, 0.1, 0.0), mail)
			_shape(_cube(Vector3(0.1, 0.012, 0.03)), Vector3(0.0, 0.1, -0.06), _mat(&"collar", Color(0.3, 0.2, 0.12), 0.9, 0.0))
		&"secret_booth_1":   # the watchman's tin canteen
			var tin := _mat(&"tin", Color(0.6, 0.6, 0.62), 0.5, 0.8)
			var body := _oval(Vector3(0.08, 0.1, 0.035), Vector3(0.0, 0.1, 0.0), tin)
			body.rotation.y = 0.3
			_shape(_cylinder(0.018, 0.03), Vector3(0.0, 0.215, 0.0), brass)
			_shape(_cube(Vector3(0.02, 0.09, 0.07)), Vector3(0.0, 0.1, 0.0), _mat(&"canvas", Color(0.5, 0.48, 0.36), 0.95, 0.0)).rotation.y = 0.3
		&"secret_greece_2":   # a black-glazed lekythos
			var glaze := _mat(&"glaze", Color(0.12, 0.1, 0.09), 0.25, 0.1)
			_shape(_cylinder(0.04, 0.012), Vector3(0.0, 0.006, 0.0), glaze)
			_oval(Vector3(0.055, 0.085, 0.055), Vector3(0.0, 0.1, 0.0), glaze)
			_shape(_cylinder(0.018, 0.08), Vector3(0.0, 0.21, 0.0), glaze)
			_shape(_cylinder(0.03, 0.015), Vector3(0.0, 0.255, 0.0), glaze)
			var band := TorusMesh.new()
			band.inner_radius = 0.052
			band.outer_radius = 0.058
			band.rings = 24
			band.ring_segments = 6
			_shape(band, Vector3(0.0, 0.1, 0.0), _mat(&"ochre", Color(0.72, 0.36, 0.18), 0.6, 0.0))
			_shape(_cube(Vector3(0.012, 0.09, 0.012)), Vector3(0.045, 0.19, 0.0), glaze)   # the handle
		&"secret_asia_3":   # a bronze temple bell with its striker
			var bronze := _mat(&"bronze", Color(0.6, 0.45, 0.25), 0.45, 0.85)
			var bell := CylinderMesh.new()
			bell.top_radius = 0.03
			bell.bottom_radius = 0.055
			bell.height = 0.1
			bell.radial_segments = 16
			_shape(bell, Vector3(0.0, 0.07, 0.0), bronze)
			var loop := TorusMesh.new()
			loop.inner_radius = 0.008
			loop.outer_radius = 0.014
			loop.rings = 12
			loop.ring_segments = 6
			_shape(loop, Vector3(0.0, 0.132, 0.0), bronze).rotation.x = PI * 0.5
			_shape(_cube(Vector3(0.014, 0.014, 0.12)), Vector3(0.085, 0.012, 0.0), _mat(&"wood", Color(0.36, 0.25, 0.17), 0.8, 0.0)).rotation.y = 0.5
		&"secret_basement_1", &"secret_roof_1":   # spare cells from the deposit; the carbide lamp
			if secret_id == &"secret_basement_1":
				var zinc := _mat(&"zinc", Color(0.6, 0.62, 0.6), 0.55, 0.7)
				for x in [-0.045, 0.0, 0.045]:
					_shape(_cylinder(0.028, 0.11), Vector3(x, 0.055, 0.0), zinc)
					_shape(_cylinder(0.01, 0.012), Vector3(x, 0.116, 0.0), brass)
					_shape(_cube(Vector3(0.056, 0.03, 0.001)), Vector3(x, 0.05, -0.0285), _mat(&"paper", Color(0.85, 0.3, 0.2), 0.9, 0.0))
			else:
				_shape(_cylinder(0.04, 0.1), Vector3(0.0, 0.05, 0.0), brass)
				_shape(_cylinder(0.022, 0.05), Vector3(0.0, 0.125, 0.0), brass)
				var reflector := _shape(_cylinder(0.055, 0.012), Vector3(0.0, 0.135, -0.05), _mat(&"reflector", Color(0.9, 0.9, 0.88), 0.15, 1.0))
				reflector.rotation.x = PI * 0.5
				_oval(Vector3(0.012, 0.012, 0.012), Vector3(0.0, 0.135, -0.045), _glow(Color(1.0, 0.85, 0.6), 2.5))
		&"secret_entrance_1":   # a cartridge belt left at the cloakroom, coiled
			var belt := TorusMesh.new()
			belt.inner_radius = 0.075
			belt.outer_radius = 0.1
			belt.rings = 24
			belt.ring_segments = 8
			var coil := _shape(belt, Vector3(0.0, 0.015, 0.0), leather)
			coil.scale = Vector3(1.0, 0.45, 1.0)
			for i in 10:
				var angle := TAU * i / 10.0
				_shape(_cylinder(0.006, 0.03), Vector3(cos(angle) * 0.088, 0.03, sin(angle) * 0.088), brass)
		&"secret_enlightenment_1":   # a lodestone with iron filings clinging to it
			var stone := _shape(_cube(Vector3(0.1, 0.08, 0.09)), Vector3(0.0, 0.045, 0.0), _mat(&"lodestone", Color(0.2, 0.2, 0.22), 0.95, 0.3))
			stone.rotation = Vector3(0.2, 0.5, 0.15)
			for i in 14:
				var angle := TAU * i / 14.0
				var filing := _shape(_cube(Vector3(0.003, 0.014, 0.003)), Vector3(cos(angle) * 0.06, 0.03 + (i % 3) * 0.02, sin(angle) * 0.055), steel)
				filing.rotation = Vector3(cos(angle) * 0.9, 0.0, -sin(angle) * 0.9)
		&"secret_enlightenment_2":   # the bookbinder's apron, folded, its buckle on top
			_shape(_cube(Vector3(0.22, 0.03, 0.18)), Vector3(0.0, 0.015, 0.0), leather)
			_shape(_cube(Vector3(0.18, 0.03, 0.15)), Vector3(0.01, 0.045, -0.01), leather)
			_shape(_cube(Vector3(0.04, 0.008, 0.03)), Vector3(0.03, 0.064, 0.02), brass)
			_shape(_cube(Vector3(0.12, 0.012, 0.012)), Vector3(-0.03, 0.065, -0.04), _mat(&"strap", Color(0.3, 0.2, 0.12), 0.9, 0.0))
		_:
			_oval(Vector3(0.05, 0.05, 0.05), Vector3(0.0, 0.05, 0.0), _glow(SecretRewards.color(tier), 1.5))


## A finish on show: an open presentation case lined with velvet and a
## barrel section in the finish, its accent on a thin band.
func _finish_sample() -> void:
	var spec: Dictionary = WeaponLook.LOOKS.get(entry.param, {})
	var wood := _mat(&"wood", Color(0.36, 0.25, 0.17), 0.8, 0.0)
	var velvet := _mat(&"velvet_dark", Color(0.18, 0.04, 0.05), 0.95, 0.0)
	_shape(_cube(Vector3(0.22, 0.02, 0.13)), Vector3(0.0, 0.01, 0.0), wood)
	_shape(_cube(Vector3(0.2, 0.012, 0.11)), Vector3(0.0, 0.026, 0.0), velvet)
	for side in [-1.0, 1.0]:
		_shape(_cube(Vector3(0.012, 0.05, 0.13)), Vector3(side * 0.104, 0.025, 0.0), wood)
		_shape(_cube(Vector3(0.22, 0.05, 0.012)), Vector3(0.0, 0.025, side * 0.059), wood)
	var lid := _shape(_cube(Vector3(0.22, 0.012, 0.13)), Vector3(0.0, 0.075, 0.085), wood)
	lid.rotation.x = -1.9
	var tint: Color = spec.get("tint", Color.WHITE)
	var sample := _mat(StringName("finish_" + String(entry.param)), tint.darkened(0.15), 0.35 * float(spec.get("roughness", 1.0)) + 0.2, maxf(float(spec.get("metallic", 0.0)), 0.3))
	var section := _shape(_cylinder(0.013, 0.17), Vector3(0.0, 0.045, 0.0), sample)
	section.rotation.z = PI * 0.5
	var band := TorusMesh.new()
	band.inner_radius = 0.012
	band.outer_radius = 0.016
	band.rings = 16
	band.ring_segments = 6
	_shape(band, Vector3(0.04, 0.045, 0.0), _glow(spec.get("accent", Color(1.0, 0.85, 0.6)), 1.4)).rotation.z = PI * 0.5
	_shape(band, Vector3(-0.04, 0.045, 0.0), _glow(spec.get("accent", Color(1.0, 0.85, 0.6)), 1.4)).rotation.z = PI * 0.5


## A mod on show: the fitting itself, as it will sit on the weapon.
func _fitting() -> void:
	var brass := _mat(&"brass", Color(0.78, 0.62, 0.3), 0.3, 0.9)
	var steel := _mat(&"steel", Color(0.55, 0.57, 0.6), 0.45, 0.9)
	match entry.param:
		&"shotgun_choke":
			var collar := _shape(_cylinder(0.05, 0.03), Vector3(0.0, 0.05, 0.0), brass)
			collar.rotation.x = PI * 0.5
			for i in 8:
				var angle := TAU * i / 8.0
				var ridge := _shape(_cube(Vector3(0.007, 0.004, 0.022)), Vector3(cos(angle) * 0.05, 0.05 + sin(angle) * 0.05, 0.0), _mat(&"brass_dark", Color(0.55, 0.42, 0.2), 0.45, 0.9))
				ridge.rotation.z = angle
		&"rifle_peep":
			var ring := TorusMesh.new()
			ring.inner_radius = 0.009
			ring.outer_radius = 0.016
			ring.rings = 20
			ring.ring_segments = 8
			_shape(ring, Vector3(0.0, 0.085, 0.0), steel).rotation.x = PI * 0.5
			_shape(_cube(Vector3(0.011, 0.07, 0.011)), Vector3(0.0, 0.035, 0.0), steel)
			_shape(_cube(Vector3(0.06, 0.008, 0.03)), Vector3(0.0, 0.004, 0.0), steel)
		&"harpoon_line":
			var core := _shape(_cylinder(0.025, 0.09), Vector3(0.0, 0.045, 0.0), brass)
			core.rotation.z = PI * 0.5
			for end in [-1.0, 1.0]:
				_shape(_cylinder(0.042, 0.008), Vector3(end * 0.041, 0.045, 0.0), brass).rotation.z = PI * 0.5
			_shape(_cylinder(0.036, 0.074), Vector3(0.0, 0.045, 0.0), _mat(&"line", Color(0.2, 0.78, 0.85), 0.85, 0.0)).rotation.z = PI * 0.5
		_:
			_oval(Vector3(0.05, 0.05, 0.05), Vector3(0.0, 0.05, 0.0), _glow(SecretRewards.color(tier), 1.5))


# --- helpers -------------------------------------------------------------------

func _shape(mesh: Mesh, at: Vector3, material: Material) -> MeshInstance3D:
	var view := MeshInstance3D.new()
	view.mesh = mesh
	view.position = at
	view.material_override = material
	_exhibit.add_child(view)
	return view


## An ellipsoid with the given radii on the exhibit.
func _oval(radii: Vector3, at: Vector3, material: Material) -> MeshInstance3D:
	var view := _shape(_unit_sphere(), at, material)
	view.scale = radii
	return view


static func _box(parent: Node3D, size: Vector3, at: Vector3, material: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var view := MeshInstance3D.new()
	view.mesh = mesh
	view.position = at
	view.material_override = material
	parent.add_child(view)
	return view


static func _cube(size: Vector3) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	return mesh


static func _cylinder(radius: float, height: float) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 16
	return mesh


static func _unit_sphere() -> SphereMesh:
	if not _materials.has(&"unit_sphere_mesh"):
		var mesh := SphereMesh.new()
		mesh.radius = 1.0
		mesh.height = 2.0
		mesh.radial_segments = 16
		mesh.rings = 8
		_materials[&"unit_sphere_mesh"] = mesh
	return _materials[&"unit_sphere_mesh"]


static func _mat(key: StringName, color: Color, roughness: float, metallic: float) -> StandardMaterial3D:
	if not _materials.has(key):
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.roughness = roughness
		material.metallic = metallic
		_materials[key] = material
	return _materials[key]


static func _glow(color: Color, energy: float) -> StandardMaterial3D:
	var key := StringName("glow_%s_%.1f" % [color.to_html(), energy])
	if not _materials.has(key):
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = energy
		_materials[key] = material
	return _materials[key]
