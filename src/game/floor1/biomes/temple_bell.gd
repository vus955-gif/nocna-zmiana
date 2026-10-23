class_name TempleBell
extends BiomeDevice
## Asia's temple bells (plan 2026-10-21-mechaniki-biomow, mechanic 5): a
## bronze bell hangs high in a hall on a chain from the ceiling, a rope
## dropping from its mouth to a wooden grip within the guard's reach - or
## it is the bell of the Korea hall's pavilion, struck with its log. A shot
## into the bell or a pull on the rope (E) rings it:
## - the ring is a loud noise AT THE BELL (LURE_RADIUS m, NOISE_SOURCE):
##   the exhibits that hear it answer as to any noise (some go to look),
##   and the bronze Fu dogs within earshot - the temple's guardians, as
##   noise carries (PerceptionWorld.hears: through open passages, damped by
##   each, never through a shut door or a wall of rooms) - always go to
##   their bell;
## - whoever was awake within RESONANCE m of it (flat) at the moment of the
##   stroke (it had noticed something: BiomeMechanics.stunnable - not one
##   the ring itself wakes) reels DAZE s in its boom (stunned: a fist can
##   finish him); the guard under it only feels it (his view shakes);
## - it swings and hums: REARM s before it rings again (a shot then only
##   knocks dully).
## So the guard draws the hall's guardians away from a door, or gathers
## them under the bell and rings it again. No collision: the rope and the
## bell hang in the air; the pavilion's own stone platform is the room's.

const LURE_RADIUS := 26.0
const NOISE_SOURCE := &"bell"
const RESONANCE := 4.0
const DAZE := 1.8
const REARM := 6.0
## Seconds the bell swings and its waves spread.
const HUM := 4.0
## The kinds that always answer their bell.
const GUARDIANS: Array[StringName] = [&"fu_dog"]
## The bell's swing (rad) right after a ring.
const SWING := 0.16
const BRONZE := Color(0.42, 0.32, 0.18)
const WAVE := Color(1.0, 0.84, 0.5, 0.5)
## The model's bell (temple_bell: the part "bell", 1.236 m wide, 2.136 m
## tall, its crown at 3.12 m over the model's origin).
const MODEL_BELL_TOP := 3.12
const MODEL_BELL_HEIGHT := 2.136
const MODEL_BELL_WIDTH := 1.236
## The rope's grip hangs this high over the floor.
const GRIP_Y := 1.25
## The Korea pavilion's bell (the platform piece at its foot): its middle
## over the foot, the striking log's end in front (north) of it.
const PAVILION_BELL := Vector3(0.0, 2.05, 0.0)
const PAVILION_STRIKER := Vector3(0.0, 2.1, -1.45)

## The wing's bells: hanging ones ("hang": the chain's end over the bell's
## crown, "scale" of the model bell, the room's "ceiling" and "floor"), and
## the pavilion's ("pavilion": the platform's foot).
const PLACES := [
	{"id": &"asia_bell_china", "room": &"asia_china", "hang": Vector3(13.5, 5.6, -44.5), "scale": 0.75, "ceiling": 12.0, "floor": 0.0},
	{"id": &"asia_bell_armor", "room": &"asia_armor", "hang": Vector3(40.5, 5.4, -74.0), "scale": 0.6, "ceiling": 8.0, "floor": 0.0},
	{"id": &"asia_bell_korea", "room": &"asia_korea", "pavilion": Vector3(52.0, 0.0, -58.3), "floor": 0.0},
]

var hang := Vector3.ZERO
var bell_scale: float = 0.6
var ceiling_y: float = 8.0
var floor_y: float = 0.0
## The Korea pavilion's bell (its model is the platform's dressing).
var pavilion := false
var pavilion_at := Vector3.ZERO
## Rings so far.
var rings: int = 0
## E on the rope's grip (the striking log's end at the pavilion).
var rope: BellRope = null

var _rearm: float = 0.0
var _hum: float = 0.0
var _swing: Node3D = null
var _sway_entry: Array = []
var _sway_amplitude: float = 0.0


## The grip of a bell's rope (or the end of the pavilion's striking log).
class BellRope extends Interactable:
	var bell: TempleBell

	func _init() -> void:
		super()
		prompt_key = "PROMPT_BELL"

	func can_interact(by: Node) -> bool:
		return super(by) and bell != null and not bell.frozen

	func interact(by: Node) -> void:
		super(by)
		if bell != null:
			bell.ring()


## Every bell of PLACES whose room [param host] serves.
static func build_all(host: BiomeMechanics) -> Array[BiomeDevice]:
	var made: Array[BiomeDevice] = []
	for spec: Dictionary in PLACES:
		if not host.serves(spec["room"]):
			continue
		var bell := create(spec)
		host.adopt(bell, spec["id"], spec["room"])
		made.append(bell)
	return made


## A bell from [param spec] (see PLACES); add it yourself.
static func create(spec: Dictionary) -> TempleBell:
	var bell := TempleBell.new()
	bell.floor_y = float(spec.get("floor", 0.0))
	if spec.has("pavilion"):
		bell.pavilion = true
		bell.pavilion_at = spec["pavilion"]
	else:
		bell.hang = spec["hang"]
		bell.bell_scale = float(spec.get("scale", 0.6))
		bell.ceiling_y = float(spec.get("ceiling", bell.hang.y + 2.0))
	return bell


func _ready() -> void:
	top_level = true
	global_transform = Transform3D.IDENTITY
	if pavilion:
		_build_pavilion()
	else:
		_build_hanging()


## The bell's middle (where a shot meets it, where the noise starts).
func center() -> Vector3:
	if pavilion:
		return pavilion_at + PAVILION_BELL
	return hang - Vector3.UP * MODEL_BELL_HEIGHT * bell_scale * 0.5


## The floor right under the bell (where its guardians come to).
func under() -> Vector3:
	var middle := center()
	return Vector3(middle.x, floor_y, middle.z)


# --- the ring ------------------------------------------------------------------------

## A hit on the bell rings it (any weapon, the fist too).
func take_damage(_info: DamageInfo) -> void:
	ring()


## Rings the bell: the noise, its guardians, the boom under it. False when
## it is still swinging (a dull knock) or dawn has come.
func ring() -> bool:
	if frozen:
		return false
	var middle := center()
	if _rearm > 0.0:
		Sfx.play_at(&"hit_metal", middle, -8.0, 0.1, 0.6)
		return false
	rings += 1
	_rearm = REARM
	_hum = HUM
	Sfx.play_at(&"witching_bell", middle, 4.0, 0.03, 0.72 if bell_scale >= 0.7 or pavilion else 0.85)
	var calling := under()
	var bell_room := PerceptionWorld.room_at(calling + Vector3.UP * 0.5)
	# who is awake under it is settled BEFORE its noise: that noise wakes
	# sleepers, and a woken one would be dazed into a hunt
	var in_reach := BiomeMechanics.exhibits_near(calling, LURE_RADIUS)
	var dazed: Array[Enemy] = []
	for exhibit in in_reach:
		var flat := Vector2(exhibit.global_position.x - calling.x, exhibit.global_position.z - calling.z).length()
		if flat <= RESONANCE and absf(exhibit.global_position.y - floor_y) < 2.0 and BiomeMechanics.stunnable(exhibit):
			dazed.append(exhibit)
	Events.noise_made.emit(middle, LURE_RADIUS, NOISE_SOURCE)
	for exhibit in in_reach:
		if not is_instance_valid(exhibit):
			continue
		if dazed.has(exhibit):
			exhibit.brain.stun(DAZE)
		elif GUARDIANS.has(exhibit.kind()) and exhibit.brain.state != EnemyBrain.State.HUNT \
				and PerceptionWorld.hears(exhibit, middle, LURE_RADIUS):
			exhibit.react(calling, bell_room, ReactionRules.Reaction.INVESTIGATE, NOISE_SOURCE)
	var player := guard()
	if player != null and Vector2(player.global_position.x - calling.x, player.global_position.z - calling.z).length() <= RESONANCE:
		player.camera.add_trauma(0.25)
	_waves(middle)
	if not _sway_entry.is_empty():
		_sway_entry[2] = SWING
	return true


func _physics_process(delta: float) -> void:
	_rearm = maxf(_rearm - delta, 0.0)
	if _hum <= 0.0:
		return
	_hum = maxf(_hum - delta, 0.0)
	var energy := _hum / HUM
	if _swing != null:
		var t := HUM - _hum
		_swing.rotation = Vector3(SWING * energy * sin(t * TAU / 1.6), 0.0, SWING * 0.3 * energy * sin(t * TAU / 2.3))
	if not _sway_entry.is_empty():
		_sway_entry[2] = lerpf(_sway_amplitude, SWING, energy)


func freeze() -> void:
	super()
	_hum = 0.0


# --- the looks -----------------------------------------------------------------------

## A bell hanging on a chain under the ceiling, the rope to its grip.
func _build_hanging() -> void:
	var iron := LockArt.metal(LockArt.IRON, 0.55)
	LockArt.rod(self, 0.035, Vector3(hang.x, ceiling_y, hang.z), hang + Vector3.UP * 0.05, iron, 6)
	_swing = Node3D.new()
	_swing.name = "Bell"
	_swing.position = hang
	add_child(_swing)
	var height := MODEL_BELL_HEIGHT * bell_scale
	var model := ArtLibrary.try_instance(&"temple_bell")
	if model != null:
		model.transform = Transform3D(Basis.from_scale(Vector3.ONE * bell_scale), Vector3(0.0, -MODEL_BELL_TOP * bell_scale, 0.0))
		_swing.add_child(model)
		# the bell alone: the pavilion's other meshes drawn no more (the bell
		# is a child of the pavilion's mesh: hiding that would hide it too)
		for child in model.find_children("*", "MeshInstance3D", true, false):
			if String(child.name) != "bell":
				(child as MeshInstance3D).mesh = null
	else:
		_greybox_bell(_swing, Vector3(0.0, -height * 0.5, 0.0), bell_scale)
	# the rope from the mouth of the bell to its grip
	var rope_mat := LockArt.matte(LockArt.ROPE, 0.95)
	var mouth := Vector3(0.0, -height + 0.1, 0.0)
	var grip := Vector3(0.0, floor_y + GRIP_Y - hang.y, 0.0)
	LockArt.rod(_swing, 0.02, mouth, grip + Vector3.UP * 0.3, rope_mat, 6)
	LockArt.rod(_swing, 0.045, grip - Vector3.UP * 0.05, grip + Vector3.UP * 0.32, LockArt.matte(Color(0.45, 0.18, 0.12), 0.7), 8)
	_hit_zone(center(), MODEL_BELL_WIDTH * bell_scale * 0.5)
	rope = _rope(Vector3(hang.x, floor_y + GRIP_Y + 0.25, hang.z), Vector3(0.5, 1.1, 0.5))


## The pavilion's bell: its model is the platform's (the dressing sways it
## gently; a ring sways it hard). Without the art, a greybox bell over the
## platform stands in.
func _build_pavilion() -> void:
	var middle := center()
	var platform := _pavilion_piece()
	var model_bell := _find_named(platform, "bell") as Node3D if platform != null else null
	if model_bell != null:
		for node in platform.find_children("*", "DecorSpinner", true, false):
			for entry: Array in (node as DecorSpinner).swings:
				if entry[0] == model_bell:
					_sway_entry = entry
					_sway_amplitude = float(entry[2])
	else:
		_swing = Node3D.new()
		_swing.name = "Bell"
		_swing.position = middle + Vector3.UP * MODEL_BELL_HEIGHT * 0.5
		add_child(_swing)
		_greybox_bell(_swing, Vector3(0.0, -MODEL_BELL_HEIGHT * 0.5, 0.0), 1.0)
	_hit_zone(middle, MODEL_BELL_WIDTH * 0.5)
	rope = _rope(pavilion_at + PAVILION_STRIKER, Vector3(0.6, 1.2, 0.8))


## The Korea hall's platform piece (the pavilion's dressing hangs on it).
func _pavilion_piece() -> Node3D:
	if not is_inside_tree():
		return null
	for node in get_tree().get_nodes_in_group(&"level_kit"):
		var piece := node as Node3D
		if piece != null and piece.get_meta(&"kit", &"") == &"pedestal" and piece.get_meta(&"kit_room", &"") == &"asia_korea" \
				and Vector2(piece.global_position.x - pavilion_at.x, piece.global_position.z - pavilion_at.z).length() < 0.5:
			return piece
	return null


static func _find_named(root: Node, wanted: String) -> Node:
	if root == null:
		return null
	for child in root.find_children("*", "Node3D", true, false):
		if String(child.name) == wanted:
			return child
	return null


## A bronze bell drawn without its model: a waisted cylinder, a lip, a crown.
static func _greybox_bell(parent: Node3D, middle: Vector3, k: float) -> void:
	var bronze := LockArt.metal(BRONZE, 0.4)
	var body := CylinderMesh.new()
	body.top_radius = 0.36 * k
	body.bottom_radius = 0.6 * k
	body.height = MODEL_BELL_HEIGHT * k * 0.85
	var view := MeshInstance3D.new()
	view.name = "bell"
	view.mesh = body
	view.material_override = bronze
	view.position = middle - Vector3.UP * MODEL_BELL_HEIGHT * k * 0.04
	parent.add_child(view)
	LockArt.ring(parent, 0.6 * k, 0.04 * k, middle - Vector3.UP * MODEL_BELL_HEIGHT * k * 0.45, Vector3.UP, bronze)
	LockArt.ring(parent, 0.12 * k, 0.035 * k, middle + Vector3.UP * MODEL_BELL_HEIGHT * k * 0.48, Vector3.BACK, bronze)


func _hit_zone(at: Vector3, radius: float) -> void:
	var sphere := SphereShape3D.new()
	sphere.radius = maxf(radius, 0.35)
	var zone := Hurtbox.make(self, sphere, at)
	zone.name = "HitZone"
	add_child(zone)


func _rope(at: Vector3, size: Vector3) -> BellRope:
	var grip := BellRope.new()
	grip.name = "Rope"
	grip.bell = self
	grip.position = at
	grip.add_box(size)
	add_child(grip)
	return grip


## Two rings of sound spreading from the bell, fading.
func _waves(at: Vector3) -> void:
	if not is_inside_tree():
		return
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = WAVE
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	for i in 2:
		var torus := TorusMesh.new()
		torus.inner_radius = 0.95
		torus.outer_radius = 1.0
		torus.rings = 32
		torus.ring_segments = 4
		var wave := MeshInstance3D.new()
		wave.mesh = torus
		wave.material_override = mat
		wave.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		wave.position = at - Vector3.UP * 0.3 * i
		wave.scale = Vector3.ONE * 0.5
		add_child(wave)
		var tween := wave.create_tween().set_parallel(true)
		var delay := 0.18 * i
		tween.tween_property(wave, "scale", Vector3(RESONANCE, 1.0, RESONANCE), 0.9).set_delay(delay).set_ease(Tween.EASE_OUT)
		tween.tween_property(wave, "transparency", 1.0, 0.9).set_delay(delay)
		tween.chain().tween_callback(wave.queue_free)
