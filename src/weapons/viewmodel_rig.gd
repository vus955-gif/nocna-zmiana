class_name ViewmodelRig
extends Node3D
## A first-person weapon model (vm_pistol, vm_taser, vm_shotgun, vm_fists,
## vm_gatling, vm_flare) with the guard's gloved hands, animated in code.
## WeaponHolder moves this node exactly as it moved the greybox (REST, bob,
## kick, switch and reload dips; the punch tween for the fist); the model
## sits inside at a per-weapon framing that makes each one read clearly in
## the lower right. The "Muzzle" marker stays a direct child
## (WeaponHolder._muzzle_position) and follows the model. The rig reads its
## WeaponState from the holder:
## - pistol: the slide kicks back on every shot and locks back when empty;
## - shotgun: the barrels break open on their hinge for a reload (the fore
##   hand goes with them, the gun tips up to show the chambers) and the
##   hammers fall shot by shot, cocked again by the reload;
## - taser: the three battery LEDs show the charges left, the next one
##   blinks while it recharges;
## - fists: the left fist rolls into the jab as it flies out;
## - gatling (update_view / on_fired / on_hidden from the holder, like the
##   greybox GatlingView): the barrels spin with the spin-up, the crank
##   turns with them and the right hand rides its knob (CrankKnob), the
##   belt is tugged into the hopper round by round and sways, a long burst
##   heats the barrels to a dull glow, each round jolts the gun and flashes
##   at the muzzle; sounds and smoke come from its GatlingDriver;
## - flare gun: the barrel breaks open on its hinge for the reload and the
##   gun tips up to show the chamber;
## - hunting rifle (Floor I): after every shot the bolt lifts, runs back and
##   forward again through the cycle (the right hand rides its knob); it
##   stays open when the rifle is empty; a reload tips the rifle and presses
##   a stripper clip down into the open action;
## - harpoon gun: the loaded harpoon ("head") shows in the muzzle, is gone
##   after the shot and slides back in during the reload (the reel's crank
##   spins with the upgrade);
## - fire-arrow chest: one arrow per tube ("rocket_1".."rocket_9", as many
##   as a volley has), each gone as it leaves (on_volley_rocket) and
##   pushed back into its tube one by one while the chest reloads; the slow
##   match glows.
## Every rig shows the bought upgrades (apply_look(), WeaponLook): upgrade
## parts on or off, replaced base parts hidden, and the master finish once
## all the weapon's upgrades are at the top (the "<model>_master" texture
## set, a warm sheen, the signature part glowing softly). A changed look
## plays a short inspection when the weapon is next drawn (or, for the
## weapon in hand, as soon as the terminal lets go of the input).

## Per model: [position offset from the holder's spot, scale, extra turn
## (degrees)] that frames it in the lower right of a 16:9 view. Big and
## chunky like a boomer shooter's (the owner found the weapons small): a
## handgun fills about an eighth of the frame with the gloved hand in view,
## turned to show its left side; a long gun about a seventh, reaching in
## from the corner. Measured with tools/art/framing_preview.py (it renders
## every weapon as the game frames it and prints its screen coverage).
const FRAMING := {
	&"vm_pistol": [Vector3(-0.045, 0.1, 0.03), 1.95, Vector3(0.0, 10.0, 0.0)],
	&"vm_taser": [Vector3(-0.045, 0.1, 0.03), 1.9, Vector3(0.0, 10.0, 0.0)],
	&"vm_shotgun": [Vector3(-0.03, 0.06, 0.02), 1.4, Vector3(0.0, 4.0, 0.0)],
	&"vm_fists": [Vector3(0.0, 0.0, 0.0), 1.3, Vector3.ZERO],
	&"vm_gatling": [Vector3(-0.03, 0.03, -0.04), 1.6, Vector3(0.0, 3.0, 0.0)],
	&"vm_flare": [Vector3(-0.045, 0.1, 0.03), 1.9, Vector3(0.0, 10.0, 0.0)],
	&"vm_rifle_hunt": [Vector3(-0.035, 0.07, 0.02), 1.5, Vector3(0.0, 5.0, 0.0)],
	&"vm_harpoon": [Vector3(-0.03, 0.06, 0.02), 1.25, Vector3(0.0, 3.0, 0.0)],
	&"vm_hwacha": [Vector3(-0.035, 0.06, 0.02), 1.5, Vector3.ZERO],
}
## Weapons whose rig is animated from WeaponHolder.update_view() (the
## others animate in their own _process()).
const DRIVEN_BY_HOLDER: Array[StringName] = [&"vm_gatling", &"vm_flare"]
## Hunting rifle: the bolt lifts this far (rad, about the bore axis) and
## runs back this far (m) through a cycle; the right hand follows its knob
## this much; the stripper clip slides down this far in the reload.
const BOLT_LIFT := 1.1
const BOLT_TRAVEL := 0.075
const BOLT_HAND_FOLLOW := 0.85
const CLIP_DROP := 0.06
## Harpoon gun: a reloaded harpoon starts this far out of the muzzle (m)
## and slides in; the reel's crank turns this fast while reloading (rad/s).
const HARPOON_LOAD_OUT := 0.3
const REEL_SPIN := 14.0
## Fire-arrow chest: a returning arrow starts this far back in its tube.
const ROCKET_SINK := 0.06
## The inspection after a new upgrade: seconds, and when the glint shows.
const INSPECT_TIME := 1.3
const GLINT_AT := 0.45
## Master finish: the signature part's glow (energy, breathing).
const MASTER_GLOW := 0.42
const MASTER_GLOW_BREATH := 0.18
## Fill light that reaches only the first-person layer
## (ArtLibrary.VIEWMODEL_LAYER): up and left of the weapon, between it and
## the eye, so gun and gloves read in any room.
const FILL_AT := Vector3(-0.14, 0.2, 0.32)
const FILL_COLOR := Color(1.0, 0.93, 0.84)
const FILL_ENERGY := 0.65
## How far WeaponHolder dips the weapon while it reloads (its
## _reload_drop); the shotgun lifts itself back up to show the chambers.
const HOLDER_RELOAD_DROP := 0.12
const SLIDE_TRAVEL := 0.035
const BARREL_BREAK := -0.62
const HAMMER_DOWN := -0.75
## FIST_REST.z and FIST_HIT.z of WeaponHolder: the punch path.
const PUNCH_FROM := -0.3
const PUNCH_TO := -0.62
## Gatling: the dull red of hot barrels, how far each round tugs the belt
## up into the hopper (m), how long a muzzle flash shows (s).
const GATLING_GLOW := Color(1.0, 0.3, 0.08)
const GATLING_GLOW_ENERGY := 4.5
const BELT_TUG := 0.007
const FLASH_TIME := 0.045
## Flare gun: the barrel's break angle (muzzle down) for a reload.
const FLARE_BREAK := -0.6
## The guard's hands keep their own look in the master finish.
const HANDS_NOT_POLISHED: Array[String] = ["hand_r", "hand_l"]

## Master-finish materials, shared per texture set.
static var _master_cache: Dictionary = {}

var weapon_id: StringName = &""
var model_id: StringName = &""
var model: Node3D
var parts: Dictionary = {}
var rest: Dictionary = {}
var muzzle: Node3D

var _muzzle_local := Transform3D.IDENTITY
var _slide := 0.0
var _open := 0.0
var _hammers := [0.0, 0.0]
var _fired_in_load := 0
var _was_reloading := false
var _time := 0.0
var _driver: GatlingDriver
var _barrel_angle := 0.0
var _crank_angle := 0.0
var _belt_tug := 0.0
var _hot_materials: Array[BaseMaterial3D] = []
var _hot_energy := -1.0
var _flash: MeshInstance3D
var _flash_left := 0.0
## The rest transform of [member model] (its framing).
var _framing_xform := Transform3D.IDENTITY
## Hunting rifle: 0..1 through the bolt cycle (1 = closed, at rest).
var _cycle := 1.0
var _cycle_length := 1.0
var _bolt_sound := false
## Harpoon gun / fire-arrow chest: the reel's turn, arrows gone this volley.
var _reel_angle := 0.0
## Fire-arrow chest: tubes (index from 0) emptied by the last volley.
var _fired: Dictionary = {}
var _ember: OmniLight3D
## Upgrade look: its signature (WeaponLook.key), an inspection waiting for
## the next draw, the parts that just appeared (they glint).
var _look_key := ""
var _inspect_pending := false
var _inspect_left := 0.0
var _new_parts: PackedStringArray = []
var _glint: MeshInstance3D
## Master finish: on, each mesh's own materials before it, the signature
## parts' glowing materials.
var _mastered := false
var _base_materials: Dictionary = {}
var _glow_materials: Array[BaseMaterial3D] = []


## The rig for weapon [param id] (&"pistol", &"taser", &"shotgun",
## &"fist"), or null when its model is off or missing.
static func create(id: StringName) -> ViewmodelRig:
	var model_name := StringName("vm_fists" if id == &"fist" else "vm_" + String(id))
	var loaded := ArtLibrary.try_instance(model_name)
	if loaded == null:
		return null
	var rig := ViewmodelRig.new()
	rig.name = String(id)
	rig.weapon_id = id
	rig.model_id = model_name
	rig.model = loaded
	var framing: Array = FRAMING.get(model_name, [Vector3.ZERO, 1.0, Vector3.ZERO])
	loaded.transform = Transform3D(Basis.from_euler((framing[2] as Vector3) * PI / 180.0).scaled(Vector3.ONE * float(framing[1])), framing[0])
	rig.add_child(loaded)
	for node in loaded.find_children("*", "Node3D", true, false):
		rig.parts[String(node.name)] = node
		rig.rest[String(node.name)] = (node as Node3D).transform
	# the muzzle is read straight off the rig: a direct child that follows
	# the model's marker
	var marker := loaded.get_node_or_null(^"Muzzle") as Node3D
	rig.muzzle = Marker3D.new()
	rig.muzzle.name = "Muzzle"
	if marker != null:
		rig._muzzle_local = marker.transform
	rig.add_child(rig.muzzle)
	rig._place_muzzle()
	if model_name == &"vm_fists":
		var right := rig.parts.get("fist_r") as Node3D
		if right != null:
			right.visible = false   # the right hand holds the weapon
	var fill := OmniLight3D.new()
	fill.name = "Fill"
	fill.position = FILL_AT
	fill.light_color = FILL_COLOR
	fill.light_energy = FILL_ENERGY * (0.4 if model_name == &"vm_fists" else 1.0)
	fill.light_specular = 0.6
	fill.omni_range = 1.4
	fill.light_cull_mask = ArtLibrary.VIEWMODEL_LAYER
	fill.shadow_enabled = false
	rig.add_child(fill)
	if model_name == &"vm_gatling":
		rig._setup_gatling()
	elif model_name == &"vm_hwacha":
		rig._setup_hwacha()
	rig._framing_xform = loaded.transform
	return rig


func _ready() -> void:
	Events.weapon_fired.connect(_on_weapon_fired)
	set_process(visible)


## Only the weapon in hand animates (the holder hides the others).
func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED:
		set_process(visible)


## Part [param part_name] of the model (slide, barrels, led_1...), or null.
func part_node(part_name: StringName) -> Node3D:
	return parts.get(String(part_name)) as Node3D


func _process(delta: float) -> void:
	_time += delta
	if _inspect_pending and weapon_id != &"fist" and GameInput.gameplay_input():
		on_drawn()   # bought while in hand: look it over once the terminal lets go
	if DRIVEN_BY_HOLDER.has(model_id):
		return
	var state := _state()
	model.transform = _framing_xform
	match model_id:
		&"vm_pistol":
			_animate_pistol(state, delta)
		&"vm_shotgun":
			_animate_shotgun(state, delta)
		&"vm_taser":
			_animate_taser(state)
		&"vm_fists":
			_animate_fist()
		&"vm_rifle_hunt":
			_animate_rifle(state, delta)
		&"vm_harpoon":
			_animate_harpoon(state, delta)
		&"vm_hwacha":
			_animate_hwacha(state, delta)
	_finish_pose(delta)


## Called by WeaponHolder every frame while this weapon is in hand (the
## gatling and the flare gun animate here; the others in _process).
func update_view(state: WeaponState, delta: float) -> void:
	if not DRIVEN_BY_HOLDER.has(model_id):
		return
	model.transform = _framing_xform
	match model_id:
		&"vm_gatling":
			_animate_gatling(state, delta)
		&"vm_flare":
			_animate_flare(state, delta)
	_finish_pose(delta)


## Shows the upgrades of [param levels] (WeaponLook): upgrade parts on or
## off, replaced base parts hidden, the master finish. With
## [param announce] a changed look plays the inspection on the next draw.
func apply_look(levels: Dictionary, announce: bool = false) -> void:
	var shown := WeaponLook.shown_parts(weapon_id, levels)
	var hidden := WeaponLook.hidden_parts(weapon_id, levels)
	_new_parts = PackedStringArray()
	for part in WeaponLook.all_parts(weapon_id):
		var node := part_node(StringName(part))
		if node == null:
			continue
		var show := shown.has(part)
		if show and not node.visible:
			_new_parts.append(part)
		node.visible = show
	for part in WeaponLook.replaceable_parts(weapon_id):
		var node := part_node(StringName(part))
		if node != null:
			node.visible = not hidden.has(part)
	set_mastery(WeaponLook.mastered(weapon_id, levels))
	var look := WeaponLook.key(weapon_id, levels)
	if announce and _look_key != "" and look != _look_key and weapon_id != &"fist":
		_inspect_pending = true
	_look_key = look


## True while the master finish is on.
func mastered() -> bool:
	return _mastered


## True while an inspection waits for the next draw.
func inspect_pending() -> bool:
	return _inspect_pending


## Seconds of the running inspection left (0: none).
func inspecting() -> float:
	return _inspect_left


## Called by WeaponHolder when this weapon is drawn: a new look is looked
## over.
func on_drawn() -> void:
	if not _inspect_pending:
		return
	_inspect_pending = false
	_inspect_left = INSPECT_TIME


## The master finish on or off: every weapon mesh (not the hands) gets the
## "<model>_master" texture set when there is one, with a warm sheen
## (rim, clear coat, a little smoother); the signature parts glow softly.
func set_mastery(on: bool) -> void:
	if on == _mastered:
		return
	_mastered = on
	_glow_materials.clear()
	var signature: Array = WeaponLook.SIGNATURE.get(weapon_id, [])
	for child in model.find_children("*", "MeshInstance3D", true, false):
		var view := child as MeshInstance3D
		if String(view.name) in HANDS_NOT_POLISHED and weapon_id != &"fist":
			continue
		if not _base_materials.has(view):
			var base: Array[Material] = []
			for i in view.mesh.get_surface_count():
				base.append(view.get_surface_override_material(i))
			_base_materials[view] = base
		var originals: Array = _base_materials[view]
		for i in view.mesh.get_surface_count():
			var source := originals[i] as BaseMaterial3D
			if source == null:
				continue
			if not on:
				view.set_surface_override_material(i, source)
				continue
			var polished := master_material(source)
			if signature.has(String(view.name)):
				polished = polished.duplicate() as BaseMaterial3D
				polished.emission_enabled = true
				polished.emission = WeaponLook.MASTER_COLOR
				polished.emission_texture = polished.albedo_texture
				polished.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
				polished.emission_energy_multiplier = MASTER_GLOW
				_glow_materials.append(polished)
			view.set_surface_override_material(i, polished)


## The master-finish version of a viewmodel material (shared per texture
## set): the "<set>_master" textures when they exist, a warm rim sheen, a
## clear coat, a little smoother.
static func master_material(source: BaseMaterial3D) -> BaseMaterial3D:
	var key := "master:" + source.resource_name
	if _master_cache.has(key):
		return _master_cache[key]
	var master_set := source.resource_name + "_master"
	var base: BaseMaterial3D = source
	if ArtLibrary.texture(master_set, "albedo") != null:
		base = ArtLibrary.material(master_set) as BaseMaterial3D
	var polished := base.duplicate() as BaseMaterial3D
	polished.resource_name = master_set
	polished.use_fov_override = true
	polished.fov_override = ArtLibrary.VIEWMODEL_FOV
	polished.use_z_clip_scale = true
	polished.z_clip_scale = ArtLibrary.VIEWMODEL_Z_CLIP
	polished.rim_enabled = true
	polished.rim = 0.35
	polished.rim_tint = 0.7
	polished.clearcoat_enabled = true
	polished.clearcoat = 0.45
	polished.clearcoat_roughness = 0.18
	polished.roughness = source.roughness * 0.78
	polished.metallic_specular = 0.65
	_master_cache[key] = polished
	return polished


## Called by WeaponHolder for every fire-arrow of a volley as it leaves
## ([param index] from 0): its tube empties.
func on_volley_rocket(index: int) -> void:
	_fired[index] = true
	var rocket := part_node(StringName("rocket_%d" % (index + 1)))
	if rocket != null:
		rocket.visible = false


## Called by WeaponHolder on every round this weapon fires.
func on_fired(_state: WeaponState) -> void:
	if model_id == &"vm_gatling" and _driver != null:
		_driver.fired()
		_belt_tug = 1.0
		_flash_left = FLASH_TIME
		_flash.scale = Vector3.ONE * randf_range(0.75, 1.25)


## Called by WeaponHolder when this weapon is put away.
func on_hidden() -> void:
	if _driver != null:
		_driver.hidden()
	if _flash != null:
		_flash_left = 0.0
		_flash.visible = false
	if model_id == &"vm_flare":
		_open = 0.0


## The gatling's driver (sounds, heat, smoke, jolt); null on other rigs.
func gatling_driver() -> GatlingDriver:
	return _driver


## Energy of the gatling's barrel glow now (0 cold).
func barrel_heat() -> float:
	return maxf(_hot_energy, 0.0)


func _state() -> WeaponState:
	var holder := get_parent() as WeaponHolder
	if holder == null:
		return null
	if weapon_id == &"fist":
		return holder.fists
	return holder.state_of(weapon_id)


func _on_weapon_fired(id: StringName) -> void:
	if id != weapon_id or not visible:
		return
	match model_id:
		&"vm_pistol":
			_slide = 1.0
		&"vm_shotgun":
			_fired_in_load += 1
		&"vm_rifle_hunt":
			var state := _state()
			_cycle_length = state.data.cooldown if state != null else 1.0
			_cycle = 0.0
			_bolt_sound = false


func _animate_pistol(state: WeaponState, delta: float) -> void:
	var locked := state != null and state.magazine == 0
	_slide = ExhibitRig.ease_to(_slide, 1.0 if locked else 0.0, 12.0 if locked else 26.0, delta)
	_pose_part(&"slide", Vector3.ZERO, Vector3(0.0, 0.0, SLIDE_TRAVEL * _slide))


func _animate_shotgun(state: WeaponState, delta: float) -> void:
	var reloading := state != null and state.is_reloading()
	if _was_reloading and not reloading:
		_fired_in_load = 0   # both chambers loaded, hammers cocked
	_was_reloading = reloading
	if state != null and state.magazine >= state.data.magazine_size:
		_fired_in_load = 0
	_open = ExhibitRig.ease_to(_open, 1.0 if reloading else 0.0, 11.0 if reloading else 16.0, delta)
	var hinge: Transform3D = rest.get("barrels", Transform3D.IDENTITY)
	var turn := Transform3D(Basis(Vector3.RIGHT, BARREL_BREAK * _open), Vector3.ZERO)
	_set_transform(&"barrels", hinge * turn)
	var hand: Transform3D = rest.get("hand_l", Transform3D.IDENTITY)
	_set_transform(&"hand_l", hinge * turn * hinge.affine_inverse() * hand)
	for i in 2:
		var down := 1.0 if _fired_in_load > i else 0.0
		_hammers[i] = ExhibitRig.ease_to(_hammers[i], down, 40.0 if down > 0.0 else 8.0, delta)
	_pose_part(&"hammer_r", Vector3(HAMMER_DOWN * _hammers[0], 0.0, 0.0))
	_pose_part(&"hammer_l", Vector3(HAMMER_DOWN * _hammers[1], 0.0, 0.0))
	# show the chambers: lift the gun back into view (the holder dips it),
	# tip the breech up toward the eye and roll it in
	var framing: Array = FRAMING[model_id]
	model.position = (framing[0] as Vector3) + Vector3(-0.04, HOLDER_RELOAD_DROP + 0.03, 0.02) * _open
	model.rotation = Vector3(0.3 * _open, 0.12 * _open, 0.42 * _open) + _framing_turn()


func _animate_taser(state: WeaponState) -> void:
	if state == null:
		return
	var cost := maxf(state.data.battery_cost, 0.001)
	var charges := int(floor(state.battery / cost + 0.0001))
	for i in 3:
		var led := parts.get("led_%d" % (i + 1)) as Node3D
		if led == null:
			continue
		if i < charges:
			led.visible = true
		elif i == charges and state.battery < state.data.battery_max:
			led.visible = fmod(_time * 3.0, 1.0) < 0.5   # charging
		else:
			led.visible = false


func _animate_gatling(state: WeaponState, delta: float) -> void:
	var speed := state.barrel_speed()
	_barrel_angle = wrapf(_barrel_angle + GatlingDriver.BARREL_SPEED * speed * delta, 0.0, TAU)
	_crank_angle = wrapf(_crank_angle - GatlingDriver.CRANK_SPEED * speed * delta, 0.0, TAU)
	_pose_part(&"barrels", Vector3(0.0, 0.0, _barrel_angle))
	_pose_part(&"crank", Vector3(_crank_angle, 0.0, 0.0))
	# the right hand rides the crank's knob (moved, never turned)
	var crank := part_node(&"crank")
	var knob := part_node(&"CrankKnob")
	if crank != null and knob != null and rest.has("hand_r"):
		var knob_rest: Vector3 = (rest["crank"] as Transform3D) * knob.position
		_pose_part(&"hand_r", Vector3.ZERO, crank.transform * knob.position - knob_rest)
	# the belt: tugged up into the hopper by every round, swaying as it feeds
	_belt_tug = maxf(_belt_tug - delta / 0.06, 0.0)
	var sway := sin(_time * 11.0) * 0.06 * speed + sin(_time * 1.7) * 0.015
	_pose_part(&"belt", Vector3(sway * 0.6, 0.0, sway), Vector3(0.0, BELT_TUG * _belt_tug, 0.0))
	_driver.update(state, delta)
	var glow := _driver.glow()
	_set_heat(glow * glow * GATLING_GLOW_ENERGY)
	var framing: Array = FRAMING[model_id]
	model.position = (framing[0] as Vector3) + _driver.jolt
	_flash_left = maxf(_flash_left - delta, 0.0)
	_flash.visible = _flash_left > 0.0


func _animate_flare(state: WeaponState, delta: float) -> void:
	var reloading := state.is_reloading()
	_open = ExhibitRig.ease_to(_open, 1.0 if reloading else 0.0, 11.0 if reloading else 16.0, delta)
	_pose_part(&"barrel", Vector3(FLARE_BREAK * _open, 0.0, 0.0))
	# lift the gun back into view (the holder dips it) and tip the breech
	# up toward the eye
	var framing: Array = FRAMING[model_id]
	model.position = (framing[0] as Vector3) + Vector3(-0.03, HOLDER_RELOAD_DROP + 0.02, 0.02) * _open
	model.rotation = Vector3(0.28 * _open, 0.1 * _open, 0.38 * _open) + _framing_turn()


## The gatling's own barrel material (it glows alone), its driver at the
## muzzle and the muzzle flash.
func _setup_gatling() -> void:
	var barrels := part_node(&"barrels") as MeshInstance3D
	if barrels != null:
		for i in barrels.mesh.get_surface_count():
			var source := barrels.get_surface_override_material(i) as BaseMaterial3D
			if source == null:
				continue
			# the glow follows the painted steel (dark bluing glows dull,
			# worn edges brighter) instead of flooding the part in one colour
			var hot := source.duplicate() as BaseMaterial3D
			hot.emission_enabled = true
			hot.emission = GATLING_GLOW
			hot.emission_texture = source.albedo_texture
			hot.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
			hot.emission_energy_multiplier = 0.0
			barrels.set_surface_override_material(i, hot)
			_hot_materials.append(hot)
	_hot_energy = 0.0
	_driver = GatlingDriver.new()
	_driver.position = muzzle.position
	add_child(_driver)
	_flash = MeshInstance3D.new()
	_flash.name = "MuzzleFlash"
	_flash.mesh = _flash_mesh()
	_flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_flash.layers = ArtLibrary.VIEWMODEL_LAYER
	_flash.visible = false
	muzzle.add_child(_flash)


func _set_heat(energy: float) -> void:
	if is_equal_approx(energy, _hot_energy):
		return
	_hot_energy = energy
	for hot in _hot_materials:
		hot.emission_energy_multiplier = energy


## A soft star of fire facing the eye (additive, drawn with the viewmodel
## field of view).
static func _flash_mesh() -> QuadMesh:
	var quad := QuadMesh.new()
	quad.size = Vector2(0.17, 0.17)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.billboard_keep_scale = true
	material.albedo_texture = _flash_texture()
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	material.albedo_color = Color(2.0, 1.7, 1.3)
	material.use_fov_override = true
	material.fov_override = ArtLibrary.VIEWMODEL_FOV
	material.use_z_clip_scale = true
	material.z_clip_scale = ArtLibrary.VIEWMODEL_Z_CLIP
	quad.material = material
	return quad


## A pixel star of fire (24 x 24): a hot core, four long rays and four
## short ones, white-yellow fading to orange.
static func _flash_texture() -> ImageTexture:
	var size := 24
	var image := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	var half := (size - 1) * 0.5
	for y in size:
		for x in size:
			var d := Vector2(x - half, y - half) / half
			var core := 1.0 - clampf(d.length() / 0.45, 0.0, 1.0)
			var straight := maxf(1.0 - absf(d.x) / 0.1, 0.0) * (1.0 - absf(d.y)) + maxf(1.0 - absf(d.y) / 0.1, 0.0) * (1.0 - absf(d.x))
			var diagonal := maxf(1.0 - absf(d.x - d.y) / 0.12, 0.0) * (1.0 - d.length() / 0.8) + maxf(1.0 - absf(d.x + d.y) / 0.12, 0.0) * (1.0 - d.length() / 0.8)
			var heat := clampf(core * 1.4 + straight * 0.9 + maxf(diagonal, 0.0) * 0.6, 0.0, 1.0)
			var color := Color(1.0, 0.45, 0.1).lerp(Color(1.0, 0.97, 0.8), heat)
			image.set_pixel(x, y, Color(color.r, color.g, color.b, heat))
	return ImageTexture.create_from_image(image)


## The bolt cycle after a shot: a beat of recoil, the handle lifts, the
## bolt runs back (the hand rides the knob), forward, and the handle comes
## down. Empty: it stays open. Reloading: the rifle tips, the action is
## open and a clip of five is pressed down into it.
func _animate_rifle(state: WeaponState, delta: float) -> void:
	if state == null:
		return
	var reloading := state.is_reloading()
	_cycle = minf(_cycle + delta / maxf(_cycle_length, 0.05), 1.0)
	var lift := 0.0
	var back := 0.0
	if reloading or state.magazine == 0:
		lift = 1.0
		back = 1.0
	elif _cycle < 1.0:
		lift = clampf(inverse_lerp(0.12, 0.3, _cycle), 0.0, 1.0) * (1.0 - clampf(inverse_lerp(0.78, 0.92, _cycle), 0.0, 1.0))
		back = clampf(inverse_lerp(0.3, 0.5, _cycle), 0.0, 1.0) * (1.0 - clampf(inverse_lerp(0.58, 0.76, _cycle), 0.0, 1.0))
		if not _bolt_sound and _cycle >= 0.3:
			_bolt_sound = true
			Sfx.play(&"rifle_bolt", -4.0)
	_pose_part(&"bolt", Vector3(0.0, 0.0, BOLT_LIFT * _smooth(lift)), Vector3(0.0, 0.0, BOLT_TRAVEL * _smooth(back)))
	var knob := part_node(&"BoltKnob")
	var bolt := part_node(&"bolt")
	if knob != null and bolt != null and rest.has("hand_r") and rest.has("bolt"):
		var knob_rest: Vector3 = (rest["bolt"] as Transform3D) * knob.position
		var follow := BOLT_HAND_FOLLOW * maxf(_smooth(lift), _smooth(back)) * (0.0 if reloading else 1.0)
		_pose_part(&"hand_r", Vector3.ZERO, (bolt.transform * knob.position - knob_rest) * follow)
	var clip := part_node(&"clip")
	if clip != null:
		var progress := state.reload_progress() if reloading else 0.0
		clip.visible = reloading and progress > 0.2 and progress < 0.8
		_pose_part(&"clip", Vector3.ZERO, Vector3(0.0, CLIP_DROP * (1.0 - clampf(inverse_lerp(0.3, 0.7, progress), 0.0, 1.0)), 0.0))
	_open = ExhibitRig.ease_to(_open, 1.0 if reloading else 0.0, 10.0 if reloading else 14.0, delta)
	model.position = (FRAMING[model_id][0] as Vector3) + Vector3(-0.03, HOLDER_RELOAD_DROP + 0.02, 0.02) * _open
	model.rotation = Vector3(0.22 * _open, 0.08 * _open, 0.32 * _open) + _framing_turn()


## The harpoon shows in the muzzle while loaded; after the shot it is gone,
## during the reload it slides back in from the front (and the reel spins).
func _animate_harpoon(state: WeaponState, delta: float) -> void:
	if state == null:
		return
	var reloading := state.is_reloading()
	var progress := state.reload_progress() if reloading else 1.0
	var head := part_node(&"head")
	if head != null:
		head.visible = state.magazine > 0 or (reloading and progress > 0.35)
		var out := 1.0 - clampf(inverse_lerp(0.35, 0.9, progress), 0.0, 1.0) if reloading else 0.0
		_pose_part(&"head", Vector3.ZERO, Vector3(0.0, 0.0, -HARPOON_LOAD_OUT * _smooth(out)))
	if reloading:
		_reel_angle = wrapf(_reel_angle + REEL_SPIN * delta, 0.0, TAU)
	_pose_part(&"reel_crank", Vector3(_reel_angle, 0.0, 0.0))
	_open = ExhibitRig.ease_to(_open, 1.0 if reloading else 0.0, 9.0 if reloading else 14.0, delta)
	model.position = (FRAMING[model_id][0] as Vector3) + Vector3(-0.02, HOLDER_RELOAD_DROP + 0.03, 0.03) * _open
	model.rotation = Vector3(0.3 * _open, 0.06 * _open, 0.18 * _open) + _framing_turn()


## One arrow per tube, as many as a volley has; each one fired is gone
## (the reload runs from the first arrow on, but the tubes are refilled
## only once the volley is over), pushed back in one by one; the match
## glows.
func _animate_hwacha(state: WeaponState, delta: float) -> void:
	if state == null:
		return
	var count := maxi(state.data.volley_count, 1)
	var reloading := state.is_reloading()
	var progress := state.reload_progress() if reloading else 1.0
	if state.magazine > 0 and not reloading:
		_fired.clear()
	for i in 9:
		var rocket := part_node(StringName("rocket_%d" % (i + 1)))
		if rocket == null:
			continue
		var back_at := 0.25 + 0.65 * float(i) / float(count)
		var refilled := reloading and progress >= back_at
		rocket.visible = i < count and (not _fired.has(i) or refilled)
		var sink := 0.0
		if _fired.has(i) and refilled:
			sink = 1.0 - clampf((progress - back_at) / 0.1, 0.0, 1.0)
		_pose_part(StringName("rocket_%d" % (i + 1)), Vector3.ZERO, Vector3(0.0, 0.0, ROCKET_SINK * sink))
	if _ember != null:
		_ember.light_energy = 0.35 + 0.12 * sin(_time * 17.0) + 0.08 * sin(_time * 29.0 + 1.1)
	_open = ExhibitRig.ease_to(_open, 1.0 if reloading else 0.0, 8.0 if reloading else 12.0, delta)
	model.position = (FRAMING[model_id][0] as Vector3) + Vector3(0.0, HOLDER_RELOAD_DROP * 0.8, 0.02) * _open
	model.rotation = Vector3(-0.25 * _open, 0.0, 0.12 * _open) + _framing_turn()


## The slow match's ember: a tiny warm light on the first-person layer.
func _setup_hwacha() -> void:
	var ember := part_node(&"Ember")
	_ember = OmniLight3D.new()
	_ember.name = "EmberLight"
	_ember.light_color = Color(1.0, 0.45, 0.15)
	_ember.light_energy = 0.4
	_ember.omni_range = 0.25
	_ember.light_cull_mask = ArtLibrary.VIEWMODEL_LAYER
	_ember.shadow_enabled = false
	if ember != null:
		ember.add_child(_ember)
	else:
		model.add_child(_ember)


## After the weapon's own pose: the inspection (it turns to show its side,
## lifts, a glint on what is new) and the master finish's breathing glow.
func _finish_pose(delta: float) -> void:
	if not _glow_materials.is_empty():
		var energy := MASTER_GLOW + MASTER_GLOW_BREATH * sin(_time * 2.1)
		for material in _glow_materials:
			material.emission_energy_multiplier = energy
	if _inspect_left > 0.0:
		var before := _inspect_left
		_inspect_left = maxf(_inspect_left - delta, 0.0)
		var t := 1.0 - _inspect_left / INSPECT_TIME
		var w := sin(PI * _smooth(t))
		var turn := Transform3D(Basis.from_euler(Vector3(0.3 * w, 0.85 * w, 0.28 * w)), Vector3(-0.06 * w, 0.07 * w, 0.06 * w))
		model.transform = turn * model.transform
		var at := INSPECT_TIME - GLINT_AT
		if before > at and _inspect_left <= at:
			_show_glint()
	if _glint != null and _glint.visible:
		_glint.scale = _glint.scale.move_toward(Vector3.ZERO, delta * 3.0)
		_glint.visible = _glint.scale.x > 0.01
	_place_muzzle()


## A gold star of light on the parts that just appeared (or the middle of
## the weapon), with a soft ting.
func _show_glint() -> void:
	if _glint == null:
		_glint = MeshInstance3D.new()
		_glint.name = "Glint"
		_glint.mesh = _flash_mesh()
		var gold := (_glint.mesh as QuadMesh).material.duplicate() as StandardMaterial3D
		gold.albedo_color = Color(1.8, 1.4, 0.7)
		_glint.material_override = gold
		_glint.layers = ArtLibrary.VIEWMODEL_LAYER
		_glint.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_glint)
	var at := Vector3.ZERO
	var found := 0
	for part in _new_parts:
		var node := part_node(StringName(part)) as VisualInstance3D
		if node != null:
			at += to_local(node.global_transform * node.get_aabb().get_center())
			found += 1
	if found > 0:
		at /= found
	else:
		at = model.transform.origin + Vector3(0.0, 0.02, -0.12)
	_glint.position = at
	_glint.scale = Vector3.ONE * 0.9
	_glint.visible = true
	Sfx.play(&"upgrade_forge", -12.0)


static func _smooth(t: float) -> float:
	return smoothstep(0.0, 1.0, t)


func _animate_fist() -> void:
	var t := clampf(inverse_lerp(PUNCH_FROM, PUNCH_TO, position.z), 0.0, 1.0)
	model.rotation = Vector3(-0.15 * t, 0.12 * t, -0.45 * t) + _framing_turn()


func _framing_turn() -> Vector3:
	var framing: Array = FRAMING.get(model_id, [Vector3.ZERO, 1.0, Vector3.ZERO])
	return (framing[2] as Vector3) * PI / 180.0


func _pose_part(part_name: StringName, euler: Vector3, shift: Vector3 = Vector3.ZERO) -> void:
	var node := parts.get(String(part_name)) as Node3D
	if node == null:
		return
	var base: Transform3D = rest[String(part_name)]
	node.transform = Transform3D(base.basis * Basis.from_euler(euler), base.origin + shift)


func _set_transform(part_name: StringName, xform: Transform3D) -> void:
	var node := parts.get(String(part_name)) as Node3D
	if node != null:
		node.transform = xform


func _place_muzzle() -> void:
	muzzle.transform = model.transform * _muzzle_local
