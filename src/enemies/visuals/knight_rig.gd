class_name KnightRig
extends ExhibitRig
## The empty suit of armour: a heavy, dipping walk with a counter-swinging
## sword arm; the shield (on the left arm) held up in front while it hunts,
## dropped to its side when stunned (the guard is open); the sword raised
## overhead in the windup and brought down in a twisting cut. Woken
## (suspicious) the empty suit comes to the ready: the shield lifts before
## it, the sword is drawn back, the helm lifts, and the whole suit shivers
## for RATTLE_TIME as if something just got into it. Hard hits knock its
## six plates off as physical debris (shed_plate()).

const PLATES: Array[String] = ["plate_pauldron_l", "plate_pauldron_r", "plate_tasset_l",
		"plate_tasset_r", "plate_poleyn_l", "plate_poleyn_r"]
## Sword arm angles (rad): raised overhead, end of the cut.
const RAISED := 2.3
const CUT := -0.75
const CUT_TIME := 0.14
## Suspicious: the ready stance (sword arm, shield arm, helm, rad) and the
## shiver of the waking suit (s, rad of torso twist, rad/s).
const READY_SWORD := 0.55
const READY_GUARD := 0.32
const READY_HEAD := -0.08
const RATTLE_TIME := 0.5
const RATTLE := 0.05
const RATTLE_SPEED := 44.0

var _sword := 0.0
var _sword_out := 0.0
var _twist := 0.0
var _lean := 0.0
var _guard := 0.0
var _drop := 0.0
var _head := 0.0
## Seconds it has been suspicious (0 otherwise).
var _alert_for := 0.0


static func build(owner_enemy: Enemy) -> KnightRig:
	var rig := KnightRig.new()
	rig.cycle_length = 1.9
	rig.full_speed = 2.0
	rig.gib_density = 3.0
	return ExhibitRig.attach(owner_enemy, rig, &"knight") as KnightRig


## Knocks off the attached plate nearest to the hit (flying away from it).
## False when every plate is gone already.
func shed_plate(info: DamageInfo) -> bool:
	var best: MeshInstance3D = null
	var best_distance := INF
	for plate_name in PLATES:
		var plate := parts.get(plate_name) as MeshInstance3D
		if plate == null or not plate.visible:
			continue
		var d := plate.global_position.distance_squared_to(info.position)
		if d < best_distance:
			best_distance = d
			best = plate
	if best == null:
		return false
	var materials: Array = []
	for i in best.mesh.get_surface_count():
		materials.append(ArtLibrary.debris_material(best.get_active_material(i)))
	var shard := MeshShards.whole(best.mesh)
	var away := info.direction if not info.direction.is_zero_approx() else -enemy.global_basis.z
	var fling := Vector3(away.x, 0.0, away.z).normalized() * randf_range(1.5, 3.0) + Vector3(randf_range(-1.2, 1.2), randf_range(2.5, 4.0), randf_range(-1.2, 1.2))
	Fx.piece(shard, MeshShards.materials_for(shard, materials), best.global_transform, fling, 9.0)
	best.visible = false
	meshes.erase(best)
	return true


## Plates still on the armour.
func plates_left() -> int:
	var count := 0
	for plate_name in PLATES:
		var plate := parts.get(plate_name) as Node3D
		if plate != null and plate.visible:
			count += 1
	return count


func _pose(delta: float) -> void:
	var brain := enemy.brain
	var state := brain.state
	var w := brain.windup_progress()
	var stunned := state == EnemyBrain.State.STUNNED
	var dormant := state == EnemyBrain.State.DORMANT
	var suspicious := state == EnemyBrain.State.SUSPICIOUS
	_alert_for = _alert_for + delta if suspicious else 0.0
	var walk := minf(gait, 1.2)
	var s := sin(walk_phase)
	var leg := s * 0.36 * walk
	pose_part("leg_l", Vector3(leg, 0.0, 0.0))
	pose_part("leg_r", Vector3(-leg, 0.0, 0.0))
	var sword := leg * 0.35
	var sword_out := 0.0
	var twist := s * 0.07 * walk
	var lean := -0.04 * walk
	var guard := 0.0 if dormant else 0.14
	var drop := 0.0
	var head := 0.0
	var rate := 10.0
	if w > 0.0:
		var up := w * w * (3.0 - 2.0 * w)
		sword = RAISED * up
		sword_out = 0.22 * up
		twist = -0.38 * up
		lean = 0.08 * up
		head = 0.08 * up
	elif since_strike >= 0.0:
		if since_strike < CUT_TIME * 2.0:
			sword = CUT
			sword_out = -0.1
			twist = 0.36
			lean = -0.1
			rate = 38.0
		else:
			rate = 3.5   # heavy: the blade comes back slowly (the opening)
	if suspicious:
		sword = READY_SWORD
		sword_out = 0.12
		guard = READY_GUARD
		head = READY_HEAD
	if stunned:
		sword = -0.45
		sword_out = 0.2
		twist = sin(time * 2.3) * 0.06
		lean = -0.14
		guard = 0.0
		drop = 1.0
		head = -0.35
	if dormant:
		sword = 0.0
		twist = 0.0
		lean = 0.0
	_sword = ExhibitRig.ease_to(_sword, sword, rate, delta)
	_sword_out = ExhibitRig.ease_to(_sword_out, sword_out, rate, delta)
	_twist = ExhibitRig.ease_to(_twist, twist, rate * 0.7, delta)
	_lean = ExhibitRig.ease_to(_lean, lean, 8.0, delta)
	_guard = ExhibitRig.ease_to(_guard, guard, 6.0, delta)
	_drop = ExhibitRig.ease_to(_drop, drop, 9.0 if drop > _drop else 4.0, delta)
	_head = ExhibitRig.ease_to(_head, head, 6.0, delta)
	var bob := -absf(s) * 0.035 * walk
	var roll := s * 0.035 * walk
	var rattle := 0.0
	if suspicious and _alert_for < RATTLE_TIME:
		rattle = sin(_alert_for * RATTLE_SPEED) * RATTLE * (1.0 - _alert_for / RATTLE_TIME)
	pose_part("torso", Vector3(_lean, _twist + rattle, roll), Vector3(0.0, bob - 0.06 * _drop, 0.0))
	pose_part("arm_r", Vector3(_sword, 0.0, _sword_out))
	# shield arm: up in front while it hunts, swung down and out when stunned
	pose_part("arm_l", Vector3(_guard - 1.05 * _drop, 0.0, -0.3 * _drop), Vector3(0.0, -0.02 * absf(s) * walk, 0.0))
	pose_part("shield", Vector3(0.0, 0.0, 0.35 * _drop))
	pose_part("head", Vector3(_head, -_twist * 0.5, 0.0))
