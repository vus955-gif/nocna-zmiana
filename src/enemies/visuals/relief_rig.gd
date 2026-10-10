class_name ReliefRig
extends ExhibitRig
## The flat figures of the Assyrian palace reliefs come alive (models
## "relief_warrior" and "relief_lion", docs/art/kit-pietro1-asyria.md 8-9):
## slabs of gypsum a hand thick, carved on their face (-Z, to the guard),
## the fresh break on the back and edges, the drawing in profile walking
## toward -X. Paper-doll motion: every joint turns about the slab's normal
## (Z; +z swings a hanging limb back toward +X, -z forward and up).
## - The warrior (torso, head with the eye, arm_front with the spear,
##   arm_back with the shield, leg_front, leg_back): asleep it holds the
##   carved pose (the slab's figure stands in for it); it walks with
##   scissoring legs and a bob; to attack it PIVOTS edge-on (its drawing's
##   front turned at the guard: a readable telegraph - and its edge takes
##   half): the throw cocks the spear arm back over the helmet with the
##   spear levelled at him and slings it (the spear grows back in the hand
##   while the throw recharges), the stab draws back and drives the
##   levelled spear through; then it swings face-on again; stunned it sags.
## - The lion (the wolf's names: body, head, jaw, tail, leg_fl/fr/bl/br):
##   a bounding gallop in its plane; it turns its head at the guard when it
##   runs at him and for the pounce: a crouch (front down, jaw open, tail
##   lashing), the leap stretched out with the jaw wide, a squash on landing.

enum Kind { WARRIOR, LION }

## Arm angles of the warrior (rad about Z) and the spear's world angle
## (from straight up; PI/2 = level, pointing forward along -X).
const THROW_COCK := 3.0
const THROW_RELEASE := -1.3
const THROW_TIME := 0.14
const STAB_BACK := 0.6
const STAB_DRIVE := -0.9
const SPEAR_LEVEL := PI * 0.5
const SPEAR_THROW := 1.37
## The pivot edge-on (model yaw, rad) and its rate.
const EDGE_ON := -PI * 0.5
const CHIPS: Array[String] = ["chip_1", "chip_2", "chip_3", "chip_4", "chip_5", "chip_6", "chip_7", "chip_8"]

## asy_gypsum_chips part -> [Mesh, Array of materials], shared.
static var _chips: Dictionary = {}

var kind: Kind = Kind.WARRIOR
## The wall bond (the slab's figure stands in, hidden in the wall).
var wall: ReliefWall = null

var _profile := 0.0
var _arm := 0.0
var _spear := 0.0
var _shield := 0.0
var _lean := 0.0
var _sag := 0.0
var _crouch := 0.0
var _leap := 0.0
var _land := 0.0
var _jaw := 0.0
var _airborne := false
var _spear_grown := 1.0
var _spear_node: Node3D = null


## The rig on [param figure]'s model, or null without it (a greybox).
static func build(owner: Enemy, figure: Kind, bond: ReliefWall) -> ReliefRig:
	var rig := ReliefRig.new()
	rig.kind = figure
	rig.wall = bond
	rig.cycle_length = 1.3 if figure == Kind.WARRIOR else 2.4
	rig.full_speed = 3.2 if figure == Kind.WARRIOR else 6.5
	rig.gib_density = 4.5
	return ExhibitRig.attach(owner, rig, &"relief_warrior" if figure == Kind.WARRIOR else &"relief_lion") as ReliefRig


## Which way its carved face looks now (world, flat): the body's front, or
## its side while it is turned edge-on.
func face_normal() -> Vector3:
	var face := -model.global_basis.z
	face.y = 0.0
	return face.normalized() if face.length_squared() > 0.0001 else -enemy.global_basis.z


## 0 face-on .. 1 edge-on (the drawing's front at the guard).
func profile() -> float:
	return _profile


## The warrior's spear has left its hand (it grows back while the throw
## recharges).
func spear_thrown() -> void:
	_spear_grown = 0.0


## A chip of gypsum off [param at], flying with [param fling].
func chip(at: Vector3, fling: Vector3) -> void:
	var entry := _chip_piece(CHIPS[randi() % CHIPS.size()])
	if entry.is_empty():
		Fx.chunk(at, Color(0.62, 0.66, 0.68), 0.07, fling)
		return
	var materials: Array[Material] = []
	materials.assign(entry[1])
	var shard := MeshShards.whole(entry[0])
	var turn := Basis.from_euler(Vector3(randf() * TAU, randf() * TAU, randf() * TAU))
	Fx.piece(shard, MeshShards.materials_for(shard, materials), Transform3D(turn, at - turn * shard.center), fling, 10.0)


## Its parts fly (the base) with a shower of gypsum chips.
func shatter(center: Vector3, plan: GibPlanner.Plan, push: Vector3) -> void:
	super(center, plan, push)
	for i in 6 if plan.gibbed else 3:
		var fling := Vector3(push.x, 0.0, push.z).normalized() * randf_range(1.0, 3.0) \
				+ Vector3(randf_range(-1.5, 1.5), randf_range(1.5, 4.0), randf_range(-1.5, 1.5))
		chip(center + Vector3(randf_range(-0.3, 0.3), randf_range(-0.4, 0.5), randf_range(-0.3, 0.3)), fling)


func _setup() -> void:
	_spear_node = part("spear")


func _pose(delta: float) -> void:
	if kind == Kind.WARRIOR:
		_pose_warrior(delta)
	else:
		_pose_lion(delta)
	# edge-on about the feet; hidden while the slab's figure or the wall stands in
	model.transform = Transform3D(Basis(Vector3.UP, EDGE_ON * _profile), Vector3.ZERO)
	model.visible = wall == null or wall.model_shown()


func _pose_warrior(delta: float) -> void:
	var brain := enemy.brain
	var w := brain.windup_progress()
	var up := w * w * (3.0 - 2.0 * w)
	var stunned := brain.state == EnemyBrain.State.STUNNED
	var attacking := brain.state == EnemyBrain.State.ATTACK
	var throwing := attacking and (enemy as ReliefWarrior).move == ReliefMoves.Move.THROW
	var walk := minf(gait, 1.4)
	var s := sin(walk_phase)
	# legs scissor in the slab's plane (asleep: the carved pose)
	pose_part("leg_front", Vector3(0.0, 0.0, -0.26 * s * walk))
	pose_part("leg_back", Vector3(0.0, 0.0, 0.26 * s * walk))
	var arm := 0.08 * sin(walk_phase + PI) * walk
	var spear := 0.0   # the spear's own turn on the arm (0: as carved, upright)
	var level := 0.0   # how far the spear is levelled at him
	var profile := 0.0
	var lean := -0.05 * walk
	var rate := 10.0
	if attacking and not brain.has_struck():
		profile = clampf(w * 3.0, 0.0, 1.0)
		if throwing:
			arm = lerpf(arm, THROW_COCK, up)
			spear = SPEAR_THROW - arm
		else:
			arm = lerpf(arm, STAB_BACK, up)
			spear = SPEAR_LEVEL - arm
		level = up
		lean = 0.05 * up
		rate = 14.0
	elif attacking and since_strike >= 0.0:
		profile = 1.0 if since_strike < 0.35 else 0.0
		var snap := since_strike < (THROW_TIME if throwing else 0.18) * 2.0
		arm = (THROW_RELEASE if throwing else STAB_DRIVE) if snap else 0.2
		spear = (SPEAR_THROW if throwing else SPEAR_LEVEL) - arm
		level = 1.0 if snap else 0.0
		lean = -0.12 if snap else 0.0
		rate = 40.0 if snap else 4.0
	_profile = ExhibitRig.ease_to(_profile, profile, 9.0, delta)
	_arm = ExhibitRig.ease_to(_arm, arm, rate, delta)
	_spear = ExhibitRig.ease_to(_spear, spear * level, rate, delta)
	_shield = ExhibitRig.ease_to(_shield, -0.35 * level, 10.0, delta)
	_lean = ExhibitRig.ease_to(_lean, lean, 10.0, delta)
	_sag = ExhibitRig.ease_to(_sag, 1.0 if stunned else 0.0, 7.0 if stunned else 3.0, delta)
	pose_part("torso", Vector3(0.0, 0.0, _lean + 0.18 * _sag), Vector3(0.0, -absf(s) * 0.025 * walk - 0.06 * _sag, 0.0))
	pose_part("head", Vector3(0.0, 0.0, 0.25 * _sag))
	pose_part("arm_front", Vector3(0.0, 0.0, _arm + 0.35 * _sag))
	pose_part("arm_back", Vector3(0.0, 0.0, _shield + 0.06 * sin(walk_phase) * walk + 0.3 * _sag))
	pose_part("spear", Vector3(0.0, 0.0, _spear + 0.5 * _sag))
	# the spear: gone after a throw, growing back in the hand
	_spear_grown = minf(_spear_grown + delta / ReliefMoves.THROW_COOLDOWN, 1.0)
	if _spear_node != null:
		_spear_node.scale = Vector3(1.0, maxf(_spear_grown, 0.001), 1.0)
		_spear_node.visible = _spear_grown > 0.02


func _pose_lion(delta: float) -> void:
	var brain := enemy.brain
	var on_floor := enemy.is_on_floor()
	var crouch := brain.windup_progress() if brain.state == EnemyBrain.State.ATTACK and not brain.has_struck() else 0.0
	var leaping := brain.has_struck() and not on_floor
	var stunned := brain.state == EnemyBrain.State.STUNNED
	if _airborne and on_floor:
		_land = 0.25
	_airborne = leaping
	_land = maxf(_land - delta, 0.0)
	var run := minf(gait, 1.3) if on_floor else 0.0
	var p := walk_phase
	# it shows its side while it stalks, turns its head at him to run at
	# him or to pounce
	var toward := 0.0
	if is_instance_valid(enemy.target):
		var flat := Vector3(enemy.velocity.x, 0.0, enemy.velocity.z)
		toward = clampf(flat.dot(-enemy.global_basis.z) / 3.0, 0.0, 1.0)
	var profile := maxf(toward, 1.0 if crouch > 0.0 or leaping or brain.has_struck() else 0.0)
	_profile = ExhibitRig.ease_to(_profile, profile, 8.0, delta)
	_crouch = ExhibitRig.ease_to(_crouch, maxf(crouch, _land / 0.25 * 0.6), 14.0, delta)
	_leap = ExhibitRig.ease_to(_leap, 1.0 if leaping else 0.0, 16.0, delta)
	_jaw = ExhibitRig.ease_to(_jaw, 0.35 if leaping else (0.25 * _crouch if crouch > 0.0 else 0.04), 18.0, delta)
	_sag = ExhibitRig.ease_to(_sag, 1.0 if stunned else 0.0, 7.0 if stunned else 3.0, delta)
	var rock := sin(p * 2.0) * 0.06 * run
	pose_part("body", Vector3(0.0, 0.0, rock + 0.15 * _crouch - 0.4 * _leap + 0.15 * _sag),
			Vector3(0.0, -0.12 * _crouch - 0.15 * _sag + absf(sin(p)) * 0.05 * run, 0.0))
	var fore := sin(p) * 0.55 * run
	var hind := sin(p + PI * 0.7) * 0.55 * run
	pose_part("leg_fl", Vector3(0.0, 0.0, fore - 0.7 * _leap + 0.3 * _crouch))
	pose_part("leg_fr", Vector3(0.0, 0.0, fore * 0.85 - 0.65 * _leap + 0.3 * _crouch))
	pose_part("leg_bl", Vector3(0.0, 0.0, hind + 0.35 * _leap - 0.25 * _crouch))
	pose_part("leg_br", Vector3(0.0, 0.0, hind * 0.85 + 0.35 * _leap - 0.25 * _crouch))
	pose_part("head", Vector3(0.0, 0.0, 0.12 * _crouch - 0.1 * _leap - rock * 0.6 + 0.3 * _sag))
	pose_part("jaw", Vector3(0.0, 0.0, _jaw))
	var lash := sin(time * 11.0) * 0.4 * _crouch + sin(p - 1.0) * 0.2 * run
	pose_part("tail", Vector3(0.0, 0.0, -0.3 * _crouch + lash + 0.4 * _sag))


## [Mesh, materials] of a gypsum chip ([] without the model).
static func _chip_piece(piece_name: String) -> Array:
	if _chips.is_empty():
		var source := ArtLibrary.exhibit(&"asy_gypsum_chips")
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
