class_name BronzeMirror
extends BiomeDevice
## A Greek bronze mirror on a swivel bracket (plan 2026-10-21-mechaniki-
## biomow, mechanic 3): it sends the Helios lamp's beam on to one of its
## marks - a doorway, a stair foot, the podium - and E (or a shot on its
## rim) turns it to the next one, swinging TURN_TIME s (the beam stops on
## its face meanwhile). Light only bounces off its face: from behind or
## grazing it is stopped. It hangs on a wall: no collision.

## The disc's radius; a beam passing within CATCH m of its middle meets it.
const RADIUS := 0.45
const CATCH := 0.6
const TURN_TIME := 0.5
## The disc's middle stands this far off the wall.
const OUT := 0.32
const BRONZE := Color(0.72, 0.52, 0.28)
const SHINE := Color(1.0, 0.92, 0.7)

## The wall point at the disc's height and the way into the room.
var at := Vector3.ZERO
var face := Vector3.FORWARD
## The points it can send the beam to (in turn).
var marks: Array[Vector3] = []
## The mark it is set to now.
var mark: int = 0
## Turns so far.
var turns: int = 0
var handle: MirrorHandle = null

var _turn_left: float = 0.0
var _disc: Node3D = null
var _shine: StandardMaterial3D = null


class MirrorHandle extends Interactable:
	var mirror: BronzeMirror

	func _init() -> void:
		super()
		prompt_key = "PROMPT_MIRROR"

	func can_interact(by: Node) -> bool:
		return super(by) and mirror != null and not mirror.frozen

	func interact(by: Node) -> void:
		super(by)
		if mirror != null:
			mirror.turn()


## A mirror from [param spec] ("at", "face", "marks"); add it yourself.
static func create(spec: Dictionary) -> BronzeMirror:
	var mirror := BronzeMirror.new()
	mirror.at = spec["at"]
	var flat: Vector3 = spec["face"]
	mirror.face = Vector3(flat.x, 0.0, flat.z).normalized()
	for point: Variant in spec.get("marks", []):
		if point is Vector3:
			mirror.marks.append(point)
	return mirror


func _ready() -> void:
	top_level = true
	global_transform = Transform3D.IDENTITY
	_build_looks()
	var zone := Hurtbox.make(self, _disc_shape(), center())
	zone.name = "HitZone"
	add_child(zone)
	handle = MirrorHandle.new()
	handle.name = "Handle"
	handle.mirror = self
	handle.position = center()
	handle.add_box(Vector3(1.0, 1.0, 1.0))
	add_child(handle)


static func _disc_shape() -> Shape3D:
	var sphere := SphereShape3D.new()
	sphere.radius = RADIUS
	return sphere


## The disc's middle.
func center() -> Vector3:
	return at + face * OUT


## The point it sends the beam to now.
func target() -> Vector3:
	return marks[mark] if not marks.is_empty() else center() + face * 10.0


## True while it swings to its next mark.
func turning() -> bool:
	return _turn_left > 0.0


## Turns it to its next mark.
func turn() -> void:
	if frozen or marks.size() < 2:
		return
	mark = (mark + 1) % marks.size()
	turns += 1
	_turn_left = TURN_TIME
	Sfx.play_at(&"gate_swing", center(), -10.0, 0.1, 1.4)


## A shot on its rim turns it.
func take_damage(_info: DamageInfo) -> void:
	if not frozen:
		Sfx.play_at(&"hit_metal", center(), -6.0, 0.1, 1.2)
	turn()


## Where a beam coming along [param incoming] (unit) leaves it: toward its
## mark; ZERO when the beam meets its back or grazes it, or while it swings.
func reflect(incoming: Vector3) -> Vector3:
	if turning() or incoming.dot(face) > -0.1:
		return Vector3.ZERO
	var out := (target() - center()).normalized()
	if out.dot(face) < 0.1:
		return Vector3.ZERO
	_point(out - incoming)
	return out


## True when a beam from [param from] to [param to] meets the disc.
func meets(from: Vector3, to: Vector3) -> bool:
	return HeliosLamp.to_segment(center(), from, to) <= CATCH


func _physics_process(delta: float) -> void:
	if _turn_left <= 0.0:
		return
	_turn_left = maxf(_turn_left - delta, 0.0)
	if _disc != null:
		_disc.rotate_object_local(Vector3.UP, delta * TAU * 0.35)


## Turns the disc's face along [param normal].
func _point(normal: Vector3) -> void:
	if _disc == null or normal.length() < 0.001:
		return
	var n := normal.normalized()
	var up := Vector3.UP if absf(n.dot(Vector3.UP)) < 0.95 else Vector3.BACK
	_disc.global_transform = Transform3D(Basis.looking_at(-n, up), center())


## The beam's glint on the disc (0..1).
func shine(amount: float) -> void:
	if _shine != null:
		_shine.emission_energy_multiplier = 2.5 * amount


func _build_looks() -> void:
	var iron := LockArt.metal(LockArt.IRON, 0.55)
	var bronze := LockArt.metal(BRONZE, 0.22)
	# the bracket: a plate on the wall and an arm out to the swivel
	var mount := Node3D.new()
	mount.name = "Mount"
	mount.transform = Transform3D(Basis.looking_at(face, Vector3.UP), at)
	add_child(mount)
	LockArt.box(mount, Vector3(0.36, 0.5, 0.04), Vector3(0, 0, -0.02), iron)
	LockArt.rod(mount, 0.03, Vector3(0, -0.15, -0.04), Vector3(0, -0.15, -OUT + 0.06), iron, 6)
	LockArt.rod(mount, 0.03, Vector3(0, 0.15, -0.04), Vector3(0, 0.15, -OUT + 0.06), iron, 6)
	_disc = Node3D.new()
	_disc.name = "Disc"
	add_child(_disc)
	var disc := CylinderMesh.new()
	disc.top_radius = RADIUS
	disc.bottom_radius = RADIUS
	disc.height = 0.035
	disc.radial_segments = 32
	_shine = StandardMaterial3D.new()
	_shine.albedo_color = BRONZE
	_shine.metallic = 0.95
	_shine.roughness = 0.18
	_shine.emission_enabled = true
	_shine.emission = SHINE
	_shine.emission_energy_multiplier = 0.0
	var view := MeshInstance3D.new()
	view.name = "Face"
	view.mesh = disc
	view.material_override = _shine
	view.rotation = Vector3(PI * 0.5, 0.0, 0.0)
	_disc.add_child(view)
	LockArt.ring(_disc, RADIUS, 0.03, Vector3.ZERO, Vector3.BACK, bronze)
	LockArt.rod(_disc, 0.025, Vector3(0, -RADIUS, 0.02), Vector3(0, -RADIUS - 0.22, 0.02), bronze, 6)
	_point(face)
