class_name HookLock
extends GateLock
## Something heavy with an iron ring on it (design 4.2): a harpoon hit
## hooks the ring and the line pulls the object. Two kinds:
## - GRATE: an iron grate standing in an opening ([member size]); pulled,
##   it tips toward the guard and crashes flat on the floor: the way is
##   open.
## - SWING: a long war canoe stood on its stern end at the far side of a
##   gap, hinged at its foot (the origin), [member size].y metres long;
##   pulled, it swings down toward the guard and lies across the gap as a
##   bridge (walkable from then on, [member bridge]).
## Any other hit only clangs off the iron ("Iron ring - too heavy to pull
## by hand (harpoon)").

enum Mode { GRATE, SWING }

const PULL_TIME := 0.75
const BAR_SPACING := 0.16
## The canoe: its beam and depth (m), and the walkable deck it leaves.
const CANOE_BEAM := 1.0
const CANOE_DEPTH := 0.5
## The deck's top over the floor the canoe lies on: below the navigation's
## climb (0.1 m), so the mesh joins the floors at both ends to it.
const DECK_TOP := 0.08

@export var mode: Mode = Mode.GRATE

## The canoe's walkable body once it lies across the gap (SWING).
var bridge: StaticBody3D = null
## Width of that deck (m): the canoe's own beam unless the floor wants a
## wider one (navigation forms only on a deck wider than an exhibit).
var deck_width: float = CANOE_BEAM * 0.9

## What the line pulls: turns round its foot (the grate's bottom edge, the
## canoe's stern).
var _object: Node3D
var _ring: MeshInstance3D


func _init() -> void:
	kind = Kind.HOOK


func _build_body() -> void:
	_object = Node3D.new()
	_object.name = "Object"
	add_child(_object)
	var iron := LockArt.metal(LockArt.IRON, 0.55)
	if mode == Mode.SWING:
		_build_canoe(iron)
	else:
		_build_grate(iron)


func _build_grate(iron: Material) -> void:
	var w := size.x
	var h := size.y
	for y: float in [0.06, h * 0.5, h - 0.06]:
		LockArt.box(_object, Vector3(w, 0.06, 0.05), Vector3(0.0, y, 0.0), iron)
	for x: float in [-w * 0.5 + 0.03, w * 0.5 - 0.03]:
		LockArt.box(_object, Vector3(0.06, h, 0.05), Vector3(x, h * 0.5, 0.0), iron)
	var bars := maxi(roundi(w / BAR_SPACING) - 1, 2)
	for i in bars:
		var x := -w * 0.5 + w * float(i + 1) / float(bars + 1)
		LockArt.rod(_object, 0.016, Vector3(x, 0.03, 0.0), Vector3(x, h - 0.03, 0.0), iron, 6)
	_ring = LockArt.ring(_object, 0.11, 0.022, Vector3(0.0, h * 0.55, -0.07), Vector3.BACK, iron)
	LockArt.box(_object, Vector3(0.08, 0.1, 0.04), Vector3(0.0, h * 0.55 + 0.1, -0.04), iron)
	_add_blocker(Vector3(w, h, 0.1), Vector3(0.0, h * 0.5, 0.0))
	_add_zone(Vector3(w + 0.1, h + 0.1, 0.16), Vector3(0.0, h * 0.5, -0.1), _object)
	_add_prompt(Vector3(w, h, 0.2), Vector3(0.0, h * 0.5, -0.05))


## The canoe stands on its stern (the origin) pointing up, its keel toward
## the guard (-Z) with the ring near the bow; it lands open side up.
func _build_canoe(iron: Material) -> void:
	var length := size.y
	var hull := MeshInstance3D.new()
	hull.name = "Hull"
	hull.mesh = canoe_mesh(length, CANOE_BEAM, CANOE_DEPTH)
	hull.material_override = LockArt.tile("wood_dark", 1.2, Color(0.3, 0.2, 0.13))
	# the mesh runs along +Z with its open side up: stand it on its stern,
	# keel toward the guard (-Z), so it lands open side up
	hull.transform = Transform3D(Basis(Vector3.UP, PI) * Basis(Vector3.RIGHT, -PI * 0.5), Vector3.ZERO)
	_object.add_child(hull)
	var paint := LockArt.matte(Color(0.55, 0.12, 0.08), 0.7)
	for t: float in [0.25, 0.5, 0.75]:
		LockArt.box(_object, Vector3(CANOE_BEAM * 0.8, 0.06, 0.05), Vector3(0.0, length * t, -CANOE_DEPTH * 0.35), paint)
	_ring = LockArt.ring(_object, 0.12, 0.025, Vector3(0.0, length * 0.92, -CANOE_DEPTH * 0.55), Vector3.BACK, iron)
	_add_zone(Vector3(CANOE_BEAM, length, CANOE_DEPTH + 0.2), Vector3(0.0, length * 0.5, -0.05), _object)
	_add_prompt(Vector3(CANOE_BEAM, length, CANOE_DEPTH), Vector3(0.0, length * 0.5, 0.0))
	bridge = StaticBody3D.new()
	bridge.name = "Bridge"
	bridge.collision_layer = 0
	bridge.collision_mask = 0
	var deck := BoxShape3D.new()
	deck.size = Vector3(deck_width, 0.12, length)
	var collider := CollisionShape3D.new()
	collider.shape = deck
	collider.position = Vector3(0.0, DECK_TOP - 0.06, -length * 0.5)
	bridge.add_child(collider)
	add_child(bridge)


## A grate blocks; a standing canoe does not (the gap does).
func blocks_passage() -> bool:
	return not is_open and mode == Mode.GRATE


func _break() -> void:
	var at := _ring.global_position
	Fx.impact(at, -global_basis.z, ExhibitMaterial.Kind.METAL, 1.5)
	Sfx.play_at(&"lock_hook_pull", at, 2.0)


func _show_open(animated: bool) -> void:
	super(animated)
	# the object turns about its foot's X axis toward the guard (-Z)
	var target := -PI * 0.5
	if bridge != null:
		bridge.collision_layer = Layers.WORLD
	if not animated:
		_object.rotation.x = target
		if mode == Mode.GRATE:
			_object.position.z = -0.4
		return
	var tween := create_tween()
	tween.tween_property(_object, "rotation:x", target, PULL_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	if mode == Mode.GRATE:
		tween.parallel().tween_property(_object, "position:z", -0.4, PULL_TIME)
	tween.tween_callback(_land)
	tween.tween_property(_object, "rotation:x", target + 0.06, 0.08)
	tween.tween_property(_object, "rotation:x", target, 0.12)


func _land() -> void:
	var length := size.y
	var at := global_transform * Vector3(0.0, 0.1, -length * 0.6)
	Fx.impact(at, Vector3.UP, -1, 3.0)
	Sfx.play_at(&"weight_thud", at, 2.0)
	Sfx.play_at(&"rubble", at, -2.0)
	Events.shake_requested.emit(0.3)


func _wrong_effect(info: DamageInfo, _counts: bool) -> void:
	Fx.impact(info.position, info.normal, ExhibitMaterial.Kind.METAL, 0.8)
	Sfx.play_at(&"hit_metal", info.position, -3.0)


func _play_rattle() -> void:
	Sfx.play_at(&"hit_metal", _ring.global_position if _ring != null else global_position, -6.0)


func _animate_jolt(amount: float) -> void:
	_object.rotation.x = sin(amount * 30.0) * 0.006 * amount


## A dugout war canoe along +Z ([param length] long), its open side up
## (+Y): a U-shaped hull narrowing to raised, pointed ends.
static func canoe_mesh(length: float, beam: float, depth: float) -> ArrayMesh:
	var stations := 18
	var around := 9
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings: Array[PackedVector3Array] = []
	for i in stations + 1:
		var t := float(i) / stations
		var taper := pow(sin(PI * t), 0.55)
		var lift := pow(absf(t - 0.5) * 2.0, 3.0) * depth * 0.9   # the ends rise
		var ring := PackedVector3Array()
		for k in around + 1:
			var a := PI * float(k) / around   # 0 = one gunwale, PI = the other, through the keel
			ring.append(Vector3(cos(a) * beam * 0.5 * taper, -sin(a) * depth * maxf(taper, 0.15) + lift, t * length))
		rings.append(ring)
	for i in stations:
		for k in around:
			var a := rings[i][k]
			var b := rings[i][k + 1]
			var c := rings[i + 1][k + 1]
			var d := rings[i + 1][k]
			for p: Vector3 in [a, b, c, a, c, d]:
				st.set_uv(Vector2(p.x, p.z))
				st.add_vertex(p)
	st.generate_normals()
	var mesh := st.commit()
	return mesh
