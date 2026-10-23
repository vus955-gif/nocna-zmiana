class_name HuntingNet
extends BiomeDevice
## Assyria's hunting nets (plan 2026-10-21-mechaniki-biomow, mechanic 2):
## the museum's reconstruction of the nets of Ashurbanipal's hunts - a net
## rolled up and hung under the ceiling on two ropes, its lead weights
## dangling, a pale knot under it. A shot into the bundle (any weapon) cuts
## it loose: it drops DROP_TIME s and spreads over a circle of RADIUS m on
## the floor below:
## - every exhibit under it that is awake to the guard (it has noticed
##   something: BiomeMechanics.stunnable) is entangled ENTANGLE s (stunned:
##   no step, no strike, no sinking into a wall, no leap; a fist can finish
##   it), then tears free - the net lies torn where it fell; a sleeper or
##   one on its calm round is not woken by it;
## - the guard caught under it only stumbles (GUARD_SLOW for GUARD_SLOW_TIME s).
## A net drops once a night (RunState.used "net_<id>": a night resumed finds
## it lying torn). It answers the reliefs' own tricks - the warrior's dodge
## and his wall, the lion's leap - and the Lion Hunt's pit is best netted
## from its gallery. No collision: it hangs in the air, lies flat when down.

const DROP_TIME := 0.45
const RADIUS := 2.6
const ENTANGLE := 4.0
## Only what stands this high over (or under) the net's floor is caught.
const CATCH_HEIGHT := 2.2
## How far outside the landing circle an awake exhibit may stand when the rope
## is cut and still run into the net while it falls (m).
const CUT_REACH := 4.0
const GUARD_SLOW := 0.45
const GUARD_SLOW_TIME := 1.5
const USED_PREFIX := "net_"
const ROPE := Color(0.62, 0.52, 0.36)
const LEAD := Color(0.24, 0.24, 0.26)
## The tent the net makes over the bodies it holds, and flat on the floor.
const TENT := 1.5
const FLAT := 0.06
## Net cells (m) and the mesh's rings and spokes.
const CELL := 0.22
const RINGS := 10
const SPOKES := 28

## The wing's nets: the bundle's middle ("at"), the floor below ("floor"),
## the ceiling its ropes hang from ("ceiling").
const PLACES := [
	# the Lion Hunt's pit: three nets over the hunting ground, cut from the gallery
	{"id": &"assyria_net_pit_north", "room": &"assyria_lions", "at": Vector3(-87.5, 4.0, -29.0), "floor": -3.0, "ceiling": 9.0},
	{"id": &"assyria_net_pit_middle", "room": &"assyria_lions", "at": Vector3(-88.5, 4.0, -21.0), "floor": -3.0, "ceiling": 9.0},
	{"id": &"assyria_net_pit_south", "room": &"assyria_lions", "at": Vector3(-87.5, 4.0, -10.5), "floor": -3.0, "ceiling": 9.0},
	# Nimrud's two aisles either side of the spine of slabs
	{"id": &"assyria_net_nimrud_north", "room": &"assyria_nimrud", "at": Vector3(-75.0, 5.5, -42.5), "floor": 0.0, "ceiling": 8.0},
	{"id": &"assyria_net_nimrud_south", "room": &"assyria_nimrud", "at": Vector3(-85.0, 5.5, -49.5), "floor": 0.0, "ceiling": 8.0},
	# over the Khorsabad Gate's warriors, past the lamassu
	{"id": &"assyria_net_gate", "room": &"assyria_gate", "at": Vector3(-52.0, 6.0, -47.5), "floor": 0.0, "ceiling": 10.0},
	# Balawat, on the way from the gate to the bronze doors
	{"id": &"assyria_net_balawat", "room": &"assyria_balawat", "at": Vector3(-55.0, 5.5, -62.0), "floor": 0.0, "ceiling": 8.0},
	# the library's aisle between the tablet cases
	{"id": &"assyria_net_library", "room": &"assyria_library", "at": Vector3(-67.5, 4.4, -30.5), "floor": 0.0, "ceiling": 6.0},
]

## The bundle's middle under the ceiling.
var at := Vector3.ZERO
var floor_y: float = 0.0
var ceiling_y: float = 8.0
var dropped := false
## Exhibits caught by its drop.
var caught: int = 0
## Drops so far (0 or 1).
var drops: int = 0
## The bundle's hit zone (null once it fell).
var zone: Hurtbox = null

var _bundle: Node3D = null
var _drape: MeshInstance3D = null
var _struggle: float = 0.0
## Seconds until it lands (0: not falling).
var _land_left: float = 0.0
## Exhibits it holds: [exhibit, its offset under the net].
var _held: Array = []
## Instance ids of the exhibits that were awake to the guard when the rope was
## cut (BiomeMechanics.stunnable): only they can be netted, not a sleeper the
## cutting shot's own noise has just made suspicious.
var _awake_at_cut: Dictionary = {}

static var _net_material: StandardMaterial3D = null


## Every net of PLACES whose room [param host] serves.
static func build_all(host: BiomeMechanics) -> Array[BiomeDevice]:
	var made: Array[BiomeDevice] = []
	for spec: Dictionary in PLACES:
		if not host.serves(spec["room"]):
			continue
		var net := create(spec)
		host.adopt(net, spec["id"], spec["room"])
		made.append(net)
	return made


## A net from [param spec] ("at", "floor", "ceiling"); add it yourself.
static func create(spec: Dictionary) -> HuntingNet:
	var net := HuntingNet.new()
	net.at = spec["at"]
	net.floor_y = float(spec.get("floor", 0.0))
	net.ceiling_y = float(spec.get("ceiling", net.at.y + 2.0))
	return net


func _ready() -> void:
	top_level = true
	global_transform = Transform3D.IDENTITY
	_build_drape()
	if _night().is_used(used_id()):
		dropped = true
		drops = 0
		_lie_torn()
		return
	_build_bundle()
	var box := BoxShape3D.new()
	box.size = Vector3(1.5, 0.9, 0.7)
	zone = Hurtbox.make(self, box, at - Vector3.UP * 0.2)
	zone.name = "HitZone"
	add_child(zone)


## RunState.used id of this net's drop.
func used_id() -> StringName:
	return StringName(USED_PREFIX + String(device_id))


## The knot under the bundle (a good place to aim).
func knot() -> Vector3:
	return at - Vector3.UP * 0.55


## Where the net lands (its middle on the floor).
func landing() -> Vector3:
	return Vector3(at.x, floor_y, at.z)


func _night() -> NightState:
	return host.run if host != null and host.run != null else RunState


## Any hit cuts it loose.
func take_damage(_info: DamageInfo) -> void:
	drop()


## Cuts it loose. False when it fell already or dawn has come.
func drop() -> bool:
	if dropped or frozen:
		return false
	dropped = true
	drops += 1
	_night().mark_used(used_id())
	_awake_at_cut.clear()
	for exhibit in BiomeMechanics.exhibits_near(landing(), RADIUS + CUT_REACH):
		if BiomeMechanics.stunnable(exhibit):
			_awake_at_cut[exhibit.get_instance_id()] = true
	if zone != null:
		zone.queue_free()
		zone = null
	Sfx.play_at(&"lock_rope_snap", knot(), 0.0)
	if _bundle != null and is_inside_tree():
		var fall := create_tween()
		fall.tween_property(_bundle, "position:y", floor_y + 0.3, DROP_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_land_left = DROP_TIME
	return true


## It spreads over the floor: everything under it is caught.
func _land() -> void:
	if not is_inside_tree():
		return
	if _bundle != null:
		_bundle.visible = false
	var middle := landing()
	_held.clear()
	for exhibit in BiomeMechanics.exhibits_near(middle, RADIUS + 1.0):
		var offset := exhibit.global_position - middle
		if Vector2(offset.x, offset.z).length() > RADIUS or offset.y < -0.5 or offset.y > CATCH_HEIGHT:
			continue
		if not _awake_at_cut.has(exhibit.get_instance_id()):
			continue   # asleep when the rope was cut (the shot's noise may have stirred it since): the net lies over it
		exhibit.brain.stun(ENTANGLE)
		_held.append([exhibit, offset])
		caught += 1
	var player := guard()
	if player != null:
		var offset := player.global_position - middle
		if Vector2(offset.x, offset.z).length() <= RADIUS and offset.y > -0.5 and offset.y < CATCH_HEIGHT:
			player.slow(GUARD_SLOW, GUARD_SLOW_TIME)
	_drape.visible = true
	_drape.scale = Vector3(0.4, 1.0 if not _held.is_empty() else FLAT / TENT, 0.4)
	var spread := create_tween()
	spread.tween_property(_drape, "scale:x", 1.0, 0.15)
	spread.parallel().tween_property(_drape, "scale:z", 1.0, 0.15)
	_struggle = ENTANGLE if not _held.is_empty() else 0.0
	Sfx.play_at(&"break_linen", middle + Vector3.UP * 0.5, -2.0, 0.1, 0.8)
	Fx.puff(middle + Vector3.UP * 0.2, Color(0.6, 0.55, 0.48), 20, RADIUS * 0.6)
	if _held.is_empty():
		_lie_torn()


func _physics_process(delta: float) -> void:
	if _land_left > 0.0:
		_land_left -= delta
		if _land_left <= 0.0:
			_land_left = 0.0
			_land()
		return
	if _struggle <= 0.0:
		return
	_struggle = maxf(_struggle - delta, 0.0)
	if _drape != null:
		var shake := 0.04 * sin(_struggle * 23.0)
		_drape.rotation = Vector3(shake, 0.0, -shake)
	if _struggle <= 0.0:
		_tear()


## They tear free: the net sinks to the floor, torn.
func _tear() -> void:
	_held.clear()
	Sfx.play_at(&"hit_linen", landing() + Vector3.UP * 0.6, -4.0, 0.1, 0.7)
	if _drape != null and is_inside_tree():
		var sink := create_tween()
		sink.tween_property(_drape, "scale:y", FLAT / TENT, 0.4)
		sink.parallel().tween_property(_drape, "rotation", Vector3.ZERO, 0.4)
	else:
		_lie_torn()


func _lie_torn() -> void:
	if _drape == null:
		return
	_drape.visible = true
	_drape.scale = Vector3(1.0, FLAT / TENT, 1.0)
	_drape.rotation = Vector3(0.0, 0.7, 0.0)


func freeze() -> void:
	super()
	_struggle = 0.0


# --- the looks -------------------------------------------------------------------

## The rolled net under the ceiling: two ropes, the roll, the lead weights,
## the knot.
func _build_bundle() -> void:
	var rope := LockArt.matte(ROPE, 0.95)
	var lead := LockArt.metal(LEAD, 0.6)
	for side in [-0.55, 0.55]:
		LockArt.rod(self, 0.018, Vector3(at.x + side, ceiling_y, at.z), Vector3(at.x + side, at.y + 0.2, at.z), rope, 6)
	_bundle = Node3D.new()
	_bundle.name = "Bundle"
	_bundle.position = at
	add_child(_bundle)
	var roll := CylinderMesh.new()
	roll.top_radius = 0.24
	roll.bottom_radius = 0.24
	roll.height = 1.4
	roll.radial_segments = 12
	var view := MeshInstance3D.new()
	view.name = "Roll"
	view.mesh = roll
	view.material_override = _material()
	view.rotation = Vector3(0, 0, PI * 0.5)
	_bundle.add_child(view)
	var inner := MeshInstance3D.new()
	inner.mesh = roll
	inner.material_override = LockArt.matte(ROPE.darkened(0.35), 1.0)
	inner.rotation = Vector3(0, 0, PI * 0.5)
	inner.scale = Vector3(0.82, 0.98, 0.82)
	_bundle.add_child(inner)
	for x in [-0.5, -0.15, 0.2, 0.55]:
		LockArt.rod(_bundle, 0.008, Vector3(x, -0.2, 0.0), Vector3(x, -0.42, 0.0), rope, 4)
		LockArt.box(_bundle, Vector3(0.07, 0.07, 0.07), Vector3(x, -0.46, 0.0), lead)
	for side in [-0.35, 0.35]:
		LockArt.ring(_bundle, 0.25, 0.02, Vector3(side, 0.0, 0.0), Vector3.RIGHT, rope)
	LockArt.rod(_bundle, 0.02, Vector3(0.0, -0.22, 0.0), Vector3(0.0, -0.55, 0.0), rope, 6)
	LockArt.box(_bundle, Vector3(0.09, 0.09, 0.09), Vector3(0.0, -0.58, 0.0), LockArt.matte(Color(0.82, 0.74, 0.56), 0.9))


## The net spread on the floor: a tent of rope mesh over a circle (hidden
## until it falls).
func _build_drape() -> void:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rows: Array = []
	for i in RINGS + 1:
		var r := RADIUS * float(i) / RINGS
		var row: Array[Vector3] = []
		for j in SPOKES:
			var angle := TAU * float(j) / SPOKES
			var wobble := 1.0 + 0.06 * sin(angle * 5.0 + float(i)) if i == RINGS else 1.0
			var point := Vector3(cos(angle) * r * wobble, TENT * (1.0 - pow(float(i) / RINGS, 1.6)) + 0.03, sin(angle) * r * wobble)
			row.append(point)
		rows.append(row)
	for i in RINGS:
		var inner: Array[Vector3] = rows[i]
		var outer: Array[Vector3] = rows[i + 1]
		for j in SPOKES:
			var k := (j + 1) % SPOKES
			for point: Vector3 in [inner[j], outer[j], outer[k], inner[j], outer[k], inner[k]]:
				tool.set_uv(Vector2(point.x, point.z) / CELL)
				tool.add_vertex(point)
	tool.generate_normals()
	_drape = MeshInstance3D.new()
	_drape.name = "Net"
	_drape.mesh = tool.commit()
	_drape.material_override = _material()
	_drape.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_drape.position = landing()
	_drape.visible = false
	add_child(_drape)


## Rope mesh: knotted cords on a clear ground, one cell a texture repeat.
static func _material() -> StandardMaterial3D:
	if _net_material != null:
		return _net_material
	var size := 32
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var cord := Color(ROPE.r, ROPE.g, ROPE.b, 1.0)
	for i in size:
		for t in 2:
			image.set_pixel(i, t, cord)
			image.set_pixel(t, i, cord)
	for x in 4:
		for y in 4:
			image.set_pixel(x, y, cord.darkened(0.3))
	var texture := ImageTexture.create_from_image(image)
	_net_material = StandardMaterial3D.new()
	_net_material.albedo_texture = texture
	_net_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	_net_material.alpha_scissor_threshold = 0.5
	_net_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_net_material.roughness = 0.95
	_net_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	return _net_material
