class_name EnvVolleyTool
extends EnvTool
## A crate of spare fire-arrows for the hwacha (plan docs/superpowers/plans/
## 2026-10-21-srodowisko-walka.md, backlog #23): the Korea hall, where the
## fire-arrow cart stands, keeps a crate of its rockets by the wall, their
## heads poking out of the straw, the fuse coiled on the lid - the tag's
## bolt holds the lid. Hit it and the fuse catches: it hisses and sparks for
## the warning while the fan of the volley is marked on the floor
## (GroundMark.arc), then the rockets go off one after another across the
## hall, fanned over [member spread_deg], each one the hwacha's own
## fire-arrow (HwachaRocket: it bursts on what it hits and sets it alight;
## the guard's own volley never takes him below half). Spent for the night:
## an empty, scorched crate (it stays where it stood, against the wall).

const ROCKET_GAP := 0.09
const PITCH := deg_to_rad(4.0)
const SPARK_EVERY := 0.1
const HWACHA := "res://src/weapons/data/hwacha.tres"
const CRATE := Vector3(1.1, 0.6, 0.6)

var rockets: int = 6
var spread_deg: float = 22.0
## How far the volley's fan is marked (m).
var reach: float = 14.0

var _left_to_fire: int = 0
var _gap: float = 0.0
var _spark: float = 0.0
var _bundle: Node3D = null
var _crate: Node3D = null
var _data: WeaponData = null


static func make(data: Dictionary, layer: EnvLayer) -> EnvVolleyTool:
	var spec := layer.room_spec(data["room"])
	if spec == null:
		return null
	var tool := EnvVolleyTool.new()
	tool.entry = data
	tool.id = StringName(data["id"])
	tool.room = data["room"]
	tool.floor_y = spec.floor_y
	tool.rockets = int(data.get("rockets", 6))
	tool.spread_deg = float(data.get("spread_deg", 22.0))
	tool.reach = float(data.get("reach", 14.0))
	tool.transform = Transform3D(Basis(Vector3.UP, float(data.get("yaw", 0.0))), data["at"])
	return tool


func _ready() -> void:
	super()
	_data = load(HWACHA) as WeaponData
	_crate = Node3D.new()
	_crate.name = "Crate"
	add_child(_crate)
	var look := EnvLooks.fit(&"camp_crate_open", CRATE, false)
	if look != null:
		_crate.add_child(look)
	else:
		EnvLooks.box(_crate, Vector3(CRATE.x, CRATE.y - 0.05, CRATE.z), Vector3(0.0, (CRATE.y - 0.05) * 0.5, 0.0), EnvLooks.TIMBER, 0.9)
		for x in [-0.45, 0.45]:
			EnvLooks.box(_crate, Vector3(0.06, CRATE.y, CRATE.z + 0.02), Vector3(x, CRATE.y * 0.5, 0.0), EnvLooks.TIMBER.darkened(0.25), 0.9)
	EnvLooks.box(_crate, Vector3(CRATE.x - 0.08, 0.04, CRATE.z - 0.06), Vector3(0.0, CRATE.y - 0.06, 0.0), Color(0.78, 0.66, 0.36), 1.0)   # the straw
	# the rockets: paper tubes on reed shafts, heads out, aimed along -Z
	_bundle = Node3D.new()
	_bundle.name = "Rockets"
	add_child(_bundle)
	for i in rockets:
		var x := lerpf(-0.36, 0.36, float(i) / maxf(rockets - 1, 1))
		var tail := Vector3(x, CRATE.y - 0.08, 0.18)
		var head := tail + Vector3(0.0, 0.18, -0.62)
		EnvLooks.rod(_bundle, tail, head, 0.012, Color(0.6, 0.52, 0.32), 0.9)
		EnvLooks.rod(_bundle, head + (tail - head).normalized() * 0.04, head + (tail - head).normalized() * 0.2, 0.026, Color(0.72, 0.18, 0.12), 0.8)
	put_tag(Vector3(0.36, CRATE.y + 0.02, -CRATE.z * 0.5 - 0.03), Vector3(0.0, -0.3, -1.0), float(entry.get("tag_scale", 1.2)))
	# the crate is solid (against its wall: placement checked by the tests),
	# an obstacle the exhibits path round; it never moves
	var box := BoxShape3D.new()
	box.size = CRATE
	make_solid(box, Transform3D(Basis.IDENTITY, Vector3(0.0, CRATE.y * 0.5, 0.0)))
	var zone := BoxShape3D.new()
	zone.size = CRATE + Vector3(0.06, 0.3, 0.06)
	add_zone_round(zone, Transform3D(Basis.IDENTITY, Vector3(0.0, CRATE.y * 0.5 + 0.1, 0.0)), AABB(Vector3(-CRATE.x * 0.5, 0.0, -CRATE.z * 0.5), CRATE))


func _make_mark() -> GroundMark:
	var half := deg_to_rad(spread_deg)
	return GroundMark.arc(0.6, reach, -half, half)


func _mark_frame() -> Transform3D:
	return Transform3D(global_basis.orthonormalized(), Vector3(global_position.x, floor_y + 0.02, global_position.z))


func _warn_start() -> void:
	_spark = 0.0
	Sfx.play_at(&"flare_burn", global_position + Vector3.UP * CRATE.y, -2.0, 0.05, 1.3)


func _warn_tick(delta: float, _progress: float) -> void:
	_spark -= delta
	if _spark > 0.0:
		return
	_spark = SPARK_EVERY
	var fuse := global_transform * Vector3(0.36, CRATE.y + 0.05, -CRATE.z * 0.5)
	Fx.impact(fuse, Vector3.UP, ExhibitMaterial.Kind.METAL, 0.7)


func _strike() -> void:
	if tag != null:
		tag.retire()   # the first rockets leave right past it
	_left_to_fire = rockets
	_gap = 0.0


func _fall_tick(delta: float) -> void:
	_gap -= delta
	while _left_to_fire > 0 and _gap <= 0.0:
		_fire(rockets - _left_to_fire)
		_left_to_fire -= 1
		_gap += ROCKET_GAP
	if _left_to_fire <= 0 and _gap <= 0.0:
		_spent_look()
		noise(global_position, EnvRules.NOISE_CRASH, ReactionRules.SOURCE_BLAST)
		_struck()


## Rocket [param index] of the volley, fanned from right to left.
func _fire(index: int) -> void:
	var t := float(index) / maxf(rockets - 1, 1)
	var half := deg_to_rad(spread_deg)
	var yaw := lerpf(half, -half, t)
	var ahead := global_basis.orthonormalized() * (Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, PITCH) * Vector3.FORWARD)
	var from := global_transform * Vector3(lerpf(-0.36, 0.36, t), CRATE.y + 0.12, -CRATE.z * 0.5 - 0.15)
	var by := credited() as Node3D
	if _data != null:
		var rocket := HwachaRocket.launch(from, ahead * _data.projectile_speed, _data, by)
		add_child(rocket)
	Fx.flash(from, Color(1.0, 0.6, 0.25), 2.0, 4.0, 0.08)
	Sfx.play_at(&"hwacha_fire", from, -2.0, 0.08)


## The crate emptied and scorched.
func _spent_look() -> void:
	if _bundle != null:
		_bundle.visible = false
	for view in EnvBreak.views(_crate):
		view.material_override = EnvLooks.material(Color(0.16, 0.12, 0.09), 1.0)


func _rest_down() -> void:
	_spent_look()
