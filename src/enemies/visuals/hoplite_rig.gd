class_name HopliteRig
extends ExhibitRig
## The marble hoplite (model "hoplite", docs/art/kit-pietro1-grecja.md 5):
## the knight's part names plus forearms and shins; its rest pose is the
## ready stance (the aspis on the left forearm in front of the body, the
## spear level forward in the right hand at waist height).
## - asleep: a statue at rest, the spear upright beside it (butt by the
##   foot), the shield lowered against the leg; woken, the spear comes
##   down level and the shield up;
## - the walk: a heavy, measured step with knees, the shield steady, the
##   crest swinging a beat behind the head (a spring);
## - the telegraph (0.7 s): it sinks into a stance (left foot forward,
##   knees bent), the shield rises to the eyes, the torso and the spear arm
##   draw back with the spear level and the bronze tip glinting (a small
##   light at spear_tip);
## - the thrust: the arm drives the spear forward through the grip, the
##   torso twists into it (the body lunges: Hoplite), then it comes back
##   slowly (the opening);
## - stunned: the shield arm drops, the spear tips down, the head hangs,
##   the knees give;
## - in a phalanx the shield turns a little toward the neighbour it covers.
## Hard hits knock off the crest (a blow to the head) and the greaves (low
## blows) as debris; marble chips (model "marble_chips") fly off hits.

## Angles (rad on the rest pose; +x lifts an arm or a thigh forward, -x
## bends a knee; spear shifts are along the forearm's axes, m).
const DRAW_ARM := -0.35
const DRAW_FORE := 0.35
const DRAW_SLIDE := 0.25
const DRIVE_ARM := 0.45
const DRIVE_FORE := -0.12
const DRIVE_SLIDE := -0.6
const THRUST_TIME := 0.16
const SHIELD_RAISE := 0.18
const STATUE_SPEAR := 1.45
const TIP_LIGHT := 1.8
const PLATES: Array[String] = ["plate_crest", "plate_greave_l", "plate_greave_r"]
const CHIPS: Array[String] = ["chip_1", "chip_2", "chip_3", "chip_4", "chip_5", "chip_6"]

## marble_chips part -> [Mesh, Array of materials], shared.
static var _chips: Dictionary = {}

var hoplite: Hoplite

var _draw := 0.0
var _drive := 0.0
var _guard := 0.0
var _statue := 1.0
var _stun := 0.0
var _stance := 0.0
var _twist := 0.0
var _lean := 0.0
var _turn_in := 0.0
var _crest := Vector2.ZERO
var _crest_v := Vector2.ZERO
var _crest_from := Vector3.INF
var _crest_speed := Vector3.ZERO
var _tip_light: OmniLight3D


## The rig on the model, or null without it (the hoplite keeps a greybox).
static func build(owner: Hoplite) -> HopliteRig:
	var rig := HopliteRig.new()
	rig.hoplite = owner
	rig.cycle_length = 1.8
	rig.full_speed = 2.1
	rig.gib_density = 4.5
	return ExhibitRig.attach(owner, rig, &"hoplite") as HopliteRig


## Where the spear's tip is now (enemy space).
func spear_tip() -> Vector3:
	return part_transform("spear_tip").origin


## Knocks off [param plate_name] (the crest, a greave) flying away along
## [param from_direction]; false when it is gone already.
func shed(plate_name: String, from_direction: Vector3) -> bool:
	var plate := parts.get(plate_name) as MeshInstance3D
	if plate == null or not plate.visible:
		return false
	var materials: Array = []
	for i in plate.mesh.get_surface_count():
		materials.append(ArtLibrary.debris_material(plate.get_active_material(i)))
	var shard := MeshShards.whole(plate.mesh)
	var away := Vector3(from_direction.x, 0.0, from_direction.z)
	away = away.normalized() if away.length_squared() > 0.0001 else -enemy.global_basis.z
	var fling := away * randf_range(1.5, 3.0) + Vector3(randf_range(-1.0, 1.0), randf_range(2.5, 4.0), randf_range(-1.0, 1.0))
	Fx.piece(shard, MeshShards.materials_for(shard, materials), plate.global_transform, fling, 9.0)
	plate.visible = false
	meshes.erase(plate)
	return true


## The plate [param plate_name] is still on.
func has_plate(plate_name: String) -> bool:
	var plate := parts.get(plate_name) as Node3D
	return plate != null and plate.visible


## A chip of marble off [param at], flying with [param fling].
func chip(at: Vector3, fling: Vector3) -> void:
	var entry := _chip_piece(CHIPS[randi() % CHIPS.size()])
	if entry.is_empty():
		Fx.chunk(at, ExhibitMaterial.color(ExhibitMaterial.Kind.MARBLE), 0.08, fling)
		return
	var materials: Array[Material] = []
	materials.assign(entry[1])
	var shard := MeshShards.whole(entry[0])
	var turn := Basis.from_euler(Vector3(randf() * TAU, randf() * TAU, randf() * TAU)).scaled(Vector3.ONE * randf_range(0.5, 0.9))
	Fx.piece(shard, MeshShards.materials_for(shard, materials), Transform3D(turn, at - turn * shard.center), fling, 10.0)


## Its parts fly (the base) with a shower of chips.
func shatter(center: Vector3, plan: GibPlanner.Plan, push: Vector3) -> void:
	super(center, plan, push)
	for i in 6 if plan.gibbed else 3:
		var fling := Vector3(push.x, 0.0, push.z).normalized() * randf_range(1.0, 3.0) \
				+ Vector3(randf_range(-1.5, 1.5), randf_range(1.5, 4.0), randf_range(-1.5, 1.5))
		chip(center + Vector3(randf_range(-0.3, 0.3), randf_range(-0.5, 0.6), randf_range(-0.3, 0.3)), fling)


func _setup() -> void:
	var tip := part("spear_tip")
	_tip_light = OmniLight3D.new()
	_tip_light.name = "TipGlint"
	_tip_light.light_color = Color(1.0, 0.86, 0.6)
	_tip_light.omni_range = 1.2
	_tip_light.light_energy = 0.0
	_tip_light.shadow_enabled = false
	_tip_light.visible = false
	if tip != null:
		tip.add_child(_tip_light)


func _pose(delta: float) -> void:
	var brain := enemy.brain
	var state := brain.state
	var w := brain.windup_progress()
	var up := w * w * (3.0 - 2.0 * w)
	var stunned := state == EnemyBrain.State.STUNNED
	var dormant := state == EnemyBrain.State.DORMANT
	var walk := minf(gait, 1.2)
	var p := walk_phase
	var draw := 0.0
	var drive := 0.0
	var stance := 0.15 if brain.is_alerted() else 0.0
	var twist := sin(p) * 0.05 * walk
	var lean := -0.05 * walk
	var rate := 9.0
	if w > 0.0:
		draw = up
		stance = maxf(stance, up)
		twist = -0.3 * up
		lean = 0.04 * up
		rate = 14.0
	elif since_strike >= 0.0:
		if since_strike < THRUST_TIME * 2.0:
			drive = 1.0
			stance = 1.0
			twist = 0.35
			lean = -0.14
			rate = 42.0
		else:
			stance = 0.6
			rate = 3.5   # the spear comes back slowly: the opening
	_draw = ExhibitRig.ease_to(_draw, draw, rate, delta)
	_drive = ExhibitRig.ease_to(_drive, drive, rate, delta)
	_stance = ExhibitRig.ease_to(_stance, stance, 10.0, delta)
	_twist = ExhibitRig.ease_to(_twist, twist, rate * 0.7, delta)
	_lean = ExhibitRig.ease_to(_lean, lean, 8.0, delta)
	_guard = ExhibitRig.ease_to(_guard, up if w > 0.0 else 0.0, 12.0, delta)
	_statue = ExhibitRig.ease_to(_statue, 1.0 if dormant else 0.0, 6.0 if dormant else 3.0, delta)
	_stun = ExhibitRig.ease_to(_stun, 1.0 if stunned else 0.0, 9.0 if stunned else 4.0, delta)
	var pack := hoplite.phalanx()
	var turn_in := 1.0 if pack != null and pack.neighbours(hoplite).x > 0 else 0.0
	_turn_in = ExhibitRig.ease_to(_turn_in, turn_in, 4.0, delta)
	_pose_legs(p, walk)
	var sink := 0.05 * _stance + 0.08 * _stun
	pose_part("torso", Vector3(_lean - 0.15 * _stun, _twist, sin(p) * 0.02 * walk),
			Vector3(0.0, -absf(sin(p)) * 0.03 * walk - sink, 0.0))
	# the spear arm: drawn back / driven through, the spear kept level
	var arm_r := DRAW_ARM * _draw + DRIVE_ARM * _drive
	var fore_r := DRAW_FORE * _draw + DRIVE_FORE * _drive - 0.6 * _stun
	var slide := DRAW_SLIDE * _draw + DRIVE_SLIDE * _drive
	# (the arm turns against the torso's twist: the spear stays on its line
	# and the twist only draws it back or drives it through)
	pose_part("arm_r", Vector3(arm_r * (1.0 - _statue) - 0.1 * _stun, -_twist, 0.05 * _stun))
	pose_part("forearm_r", Vector3(fore_r * (1.0 - _statue), 0.0, 0.0))
	pose_part("spear", Vector3(STATUE_SPEAR * _statue, 0.0, 0.0), Vector3(0.0, 0.1 * _statue, slide * (1.0 - _statue)))
	# the shield arm: raised in the telegraph, lowered asleep or stunned
	var low := maxf(_statue, _stun)
	pose_part("arm_l", Vector3(SHIELD_RAISE * _guard - 0.5 * low, 0.18 * _turn_in, -0.15 * _stun))
	pose_part("forearm_l", Vector3(-0.35 * low, 0.0, 0.0))
	pose_part("head", Vector3(-0.08 * _guard - 0.35 * _stun, -_twist * 0.5, 0.0))
	_pose_crest(delta)
	if _tip_light != null:
		var glint := w * w * TIP_LIGHT
		_tip_light.light_energy = glint
		_tip_light.visible = glint > 0.02


## Thighs swing and knees fold in the swing; the stance puts the left foot
## forward on bent knees.
func _pose_legs(phase: float, walk: float) -> void:
	for side in ["l", "r"]:
		var p := phase if side == "l" else phase + PI
		var swing := sin(p)
		var lift := maxf(cos(p), 0.0)
		var stance := 0.22 * _stance if side == "l" else -0.16 * _stance
		var thigh := 0.3 * swing * walk + stance + 0.12 * _stun
		var knee := -0.55 * lift * walk - 0.22 * _stance - 0.3 * _stun
		pose_part("leg_" + side, Vector3(thigh, 0.0, 0.0))
		pose_part("shin_" + side, Vector3(knee, 0.0, 0.0))


## The crest swings on a spring, pushed by how its base accelerates.
func _pose_crest(delta: float) -> void:
	var crest := part("plate_crest")
	if crest == null or not crest.visible:
		return
	var at := crest.global_position
	if _crest_from == Vector3.INF or at.distance_to(_crest_from) > 1.0:
		_crest_from = at
		_crest_speed = Vector3.ZERO
		return
	var speed := (at - _crest_from) / maxf(delta, 0.0001)
	var accel := (speed - _crest_speed) / maxf(delta, 0.0001)
	_crest_from = at
	_crest_speed = speed
	var local := (crest.get_parent() as Node3D).global_basis.orthonormalized().inverse() * accel
	var push := Vector2(local.z, -local.x) * 0.012
	_crest_v += (push - _crest * 90.0 - _crest_v * 8.0) * delta
	_crest += _crest_v * delta
	_crest = _crest.clamp(Vector2(-0.5, -0.5), Vector2(0.5, 0.5))
	pose_part("plate_crest", Vector3(_crest.x, 0.0, _crest.y))


## [Mesh, materials] of a marble_chips part ([] without the model).
static func _chip_piece(piece_name: String) -> Array:
	if _chips.is_empty():
		var source := ArtLibrary.exhibit(&"marble_chips")
		if source == null:
			return []
		for child in source.find_children("*", "MeshInstance3D", true, false):
			var view := child as MeshInstance3D
			if view.mesh == null:
				continue
			var materials: Array = []
			for i in view.mesh.get_surface_count():
				materials.append(ArtLibrary.debris_material(view.get_active_material(i)))
			_chips[String(view.name)] = [view.mesh, materials]
		source.free()
	return _chips.get(piece_name, [])
