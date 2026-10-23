class_name HeliosLamp
extends BiomeDevice
## Greece's mirrors of Helios (plan 2026-10-21-mechaniki-biomow, mechanic 3):
## the arc lamp the photographers of the marbles brought in at night (the
## 1890s), bracketed high on a wall. E on its lever strikes the arc: for
## BURN_TIME s it throws a beam of white "daylight" at its aim; bronze
## mirrors on its way (BronzeMirror) send the beam on to their marks; walls
## and pieces stop it. The last TELL s the carbons sputter (the beam
## flickers); then it is out and must cool COOL s before it strikes again.
## In the beam (within BEAM_RADIUS of it):
## - an exhibit is caught by the dawn that turns the night's exhibits to
##   stone: it stiffens (its pace x SLOW until SLOW_HOLD s after it leaves
##   the beam) and burns, BURN_PER_SECOND (ticks of periodic, silent fire: no
##   hit marker, no shield stops it, and no alarm - it wakes nobody and tells
##   nobody where the guard is);
## - the guard stands as lit as can be (PerceptionWorld.light_sources):
##   every exhibit sees him from afar - the beam's price.
## No collision: the lamp hangs on the wall, the beam is light.

const BURN_TIME := 20.0
const COOL := 12.0
## The carbons' sputter before the arc dies (a telegraph).
const TELL := 2.0
const BURN_PER_SECOND := 14.0
const SLOW := 0.4
const SLOW_HOLD := 0.5
const TICK := 0.1
const BEAM_RADIUS := 0.55
const MAX_LENGTH := 45.0
const MAX_BOUNCES := 4
## The lamp's drum stands this far off the wall.
const OUT := 0.45
const BEAM := Color(1.0, 0.97, 0.88)
const BRASS := Color(0.78, 0.6, 0.28)

## The Nereid hall: the lamp over the balcony's east end at the stair head,
## its beam on the east wall's mirror; that mirror sends it across the hall
## to the Bassae door, to the south wall's mirror or along the podium's
## foot; the south mirror to the vase-room door, along the south wall past
## the Metope door or up to the podium's south end.
const INSTALLATIONS := [
	{"room": &"greece_nereid",
		"lamp": {"id": &"greece_helios_lamp", "at": Vector3(-79.0, 6.1, -1.5), "face": Vector3(0, 0, 1), "aim": &"greece_mirror_east"},
		"mirrors": [
			{"id": &"greece_mirror_east", "at": Vector3(-64.0, 1.5, 6.0), "face": Vector3(-1, 0, 0),
				"marks": [Vector3(-86.0, 1.3, 5.2), &"greece_mirror_south", Vector3(-79.0, 1.3, 12.0)]},
			{"id": &"greece_mirror_south", "at": Vector3(-82.0, 1.5, 25.5), "face": Vector3(0, 0, -1),
				"marks": [Vector3(-86.0, 1.3, 19.75), Vector3(-64.0, 1.3, 25.0), Vector3(-85.0, 1.3, 17.0)]},
		]},
]

## The wall point at the drum's height and the way into the room.
var at := Vector3.ZERO
var face := Vector3.FORWARD
## Where the drum points.
var aim := Vector3.ZERO
var mirrors: Array[BronzeMirror] = []
var lit := false
## Strikes so far.
var strikes: int = 0
## The beam now: the lamp, every mirror it met, its end.
var path := PackedVector3Array()
var lever: LampLever = null

var _burn_left: float = 0.0
var _cool_left: float = 0.0
var _tick_left: float = 0.0
var _time: float = 0.0
## Instance id -> [exhibit, seconds of stiffness left].
var _stiff: Dictionary = {}
var _source: Callable
var _beams: Array[MeshInstance3D] = []
var _glows: Array[OmniLight3D] = []
var _beam_mat: StandardMaterial3D = null
var _lens: StandardMaterial3D = null


class LampLever extends Interactable:
	var lamp: HeliosLamp

	func _init() -> void:
		super()
		prompt_key = "PROMPT_ARC_LAMP"

	func can_interact(by: Node) -> bool:
		return super(by) and lamp != null and lamp.ready_to_strike()

	func interact(by: Node) -> void:
		super(by)
		if lamp != null:
			lamp.strike()


## Every installation of INSTALLATIONS whose room [param host] serves.
static func build_all(host: BiomeMechanics) -> Array[BiomeDevice]:
	var made: Array[BiomeDevice] = []
	for place: Dictionary in INSTALLATIONS:
		if not host.serves(place["room"]):
			continue
		var by_id := {}
		var specs: Array = place["mirrors"]
		for spec: Dictionary in specs:
			by_id[spec["id"]] = BronzeMirror.create(spec)
		# a mark naming a mirror is that mirror's middle
		for spec: Dictionary in specs:
			var mirror: BronzeMirror = by_id[spec["id"]]
			mirror.marks.clear()
			for point: Variant in spec["marks"]:
				mirror.marks.append((by_id[point] as BronzeMirror).center() if point is StringName else point)
			host.adopt(mirror, spec["id"], place["room"])
			made.append(mirror)
		var lamp_spec: Dictionary = (place["lamp"] as Dictionary).duplicate()
		var aimed: Variant = lamp_spec["aim"]
		if aimed is StringName:
			lamp_spec["aim"] = (by_id[aimed] as BronzeMirror).center()
		var round_mirrors: Array = by_id.values()
		var lamp := create(lamp_spec, round_mirrors)
		host.adopt(lamp, lamp_spec["id"], place["room"])
		made.append(lamp)
	return made


## A lamp from [param spec] ("at", "face", "aim") whose beam the
## [param with_mirrors] turn; add it yourself.
static func create(spec: Dictionary, with_mirrors: Array) -> HeliosLamp:
	var lamp := HeliosLamp.new()
	lamp.at = spec["at"]
	var flat: Vector3 = spec["face"]
	lamp.face = Vector3(flat.x, 0.0, flat.z).normalized()
	lamp.aim = spec["aim"]
	for mirror: BronzeMirror in with_mirrors:
		lamp.mirrors.append(mirror)
	return lamp


func _ready() -> void:
	top_level = true
	global_transform = Transform3D.IDENTITY
	_build_looks()
	lever = LampLever.new()
	lever.name = "Lever"
	lever.lamp = self
	lever.position = at + face * 0.25 - Vector3.UP * 0.55
	lever.add_box(Vector3(0.6, 0.7, 0.5))
	add_child(lever)
	_source = light_from_beam
	_register_light()


## Puts the beam's light into the perception world (once: a reset of that
## world clears every source, so a lamp that outlives one registers again).
func _register_light() -> void:
	if _source.is_valid() and not PerceptionWorld.light_sources.has(_source):
		PerceptionWorld.light_sources.append(_source)


func _exit_tree() -> void:
	PerceptionWorld.light_sources.erase(_source)
	_release_all()


## The drum's lens (where the beam starts).
func origin() -> Vector3:
	return at + face * OUT


func ready_to_strike() -> bool:
	return not lit and not frozen and _cool_left <= 0.0


## True while the carbons sputter (the arc is about to die).
func sputtering() -> bool:
	return lit and _burn_left <= TELL


## Strikes the arc. False while it burns, cools or dawn has come.
func strike() -> bool:
	if not ready_to_strike():
		return false
	lit = true
	strikes += 1
	_register_light()
	_burn_left = BURN_TIME
	_tick_left = 0.0
	Sfx.play_at(&"relay", origin(), -2.0, 0.05, 0.8)
	Sfx.play_at(&"lock_power_on", origin(), 0.0, 0.05, 1.2)
	_retrace()
	return true


func _physics_process(delta: float) -> void:
	_time += delta
	_ease_stiffness(delta)
	if not lit:
		_cool_left = maxf(_cool_left - delta, 0.0)
		return
	_burn_left -= delta
	if _burn_left <= 0.0:
		_go_out()
		return
	_tick_left -= delta
	if _tick_left <= 0.0:
		_tick_left = TICK
		_retrace()
		_burn(TICK)
	if _beam_mat != null:
		var flicker := 1.0
		if sputtering():
			flicker = 0.35 + 0.65 * absf(sin(_time * 31.0)) * absf(sin(_time * 7.0))
		_beam_mat.albedo_color.a = 0.32 * flicker


func _go_out() -> void:
	lit = false
	_cool_left = COOL
	path = PackedVector3Array()
	_show_beam()
	Sfx.play_at(&"power_dead", origin(), -6.0, 0.05, 1.3)


func freeze() -> void:
	super()
	lit = false
	path = PackedVector3Array()
	_show_beam()
	_release_all()


# --- the beam ---------------------------------------------------------------------------

## Follows the beam from the lens: to the first wall or mirror; a mirror
## sends it on (at most MAX_BOUNCES times).
func _retrace() -> void:
	path = PackedVector3Array()
	if not lit or not is_inside_tree():
		_show_beam()
		return
	var from := origin()
	var direction := (aim - from).normalized()
	path.append(from)
	var last: BronzeMirror = null
	for bounce in MAX_BOUNCES + 1:
		var end := from + direction * MAX_LENGTH
		var query := PhysicsRayQueryParameters3D.create(from, end, Layers.WORLD)
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty():
			end = hit["position"]
		var met: BronzeMirror = null
		var nearest := INF
		for mirror in mirrors:
			if mirror == last or not is_instance_valid(mirror) or not mirror.meets(from, end):
				continue
			var distance := from.distance_to(mirror.center())
			if distance < nearest:
				nearest = distance
				met = mirror
		for mirror in mirrors:
			if is_instance_valid(mirror):
				mirror.shine(1.0 if mirror == met else 0.0)
		if met == null:
			path.append(end)
			break
		path.append(met.center())
		var out := met.reflect(direction)
		if out == Vector3.ZERO:
			break
		last = met
		from = met.center()
		direction = out
	_show_beam()


## The exhibits in the beam burn and stiffen ([param seconds] of it).
func _burn(seconds: float) -> void:
	if path.size() < 2:
		return
	for exhibit in PerceptionWorld.exhibits():
		if not is_instance_valid(exhibit) or exhibit.is_queued_for_deletion() or exhibit.is_frozen():
			continue
		if exhibit.brain.state == EnemyBrain.State.DESTROYED or not in_beam(exhibit.global_position):
			continue
		_stiffen(exhibit)
		var info := DamageInfo.make(BURN_PER_SECOND * seconds, DamageInfo.Kind.FIRE, null)
		info.periodic = true
		info.silent = true   # a beam burns, it does not tell the exhibit where the guard is
		info.position = exhibit.global_position + Vector3.UP * 1.1
		exhibit.take_damage(info)


## True when a body standing at [param feet] is in the beam.
func in_beam(feet: Vector3) -> bool:
	for height: float in [0.5, 1.1, 1.7]:
		if distance_to_beam(feet + Vector3.UP * height) <= BEAM_RADIUS:
			return true
	return false


## How far [param point] is from the beam (INF when it is dark).
func distance_to_beam(point: Vector3) -> float:
	var best := INF
	for i in range(1, path.size()):
		best = minf(best, to_segment(point, path[i - 1], path[i]))
	return best


## The guard's light from the beam at [param point]: full in it.
func light_from_beam(point: Vector3) -> float:
	if not lit or frozen:
		return 0.0
	return 1.0 if distance_to_beam(point) <= BEAM_RADIUS + 0.15 else 0.0


## Distance from [param point] to the segment [param a]-[param b].
static func to_segment(point: Vector3, a: Vector3, b: Vector3) -> float:
	var along := b - a
	var t := 0.0 if along.length_squared() < 0.000001 else clampf((point - a).dot(along) / along.length_squared(), 0.0, 1.0)
	return point.distance_to(a + along * t)


func _stiffen(exhibit: Enemy) -> void:
	var id := exhibit.get_instance_id()
	if not _stiff.has(id):
		ExhibitMods.scale_pace(exhibit, get_instance_id(), SLOW)
		_stiff[id] = [exhibit, SLOW_HOLD]
		Fx.puff(exhibit.global_position + Vector3.UP * 1.2, BEAM, 10, 0.35)
	else:
		(_stiff[id] as Array)[1] = SLOW_HOLD


func _ease_stiffness(delta: float) -> void:
	for id: int in _stiff.keys():
		var entry: Array = _stiff[id]
		entry[1] = float(entry[1]) - delta
		if float(entry[1]) <= 0.0:
			_release(entry[0])
			_stiff.erase(id)


## Takes its stiffness off [param exhibit] (only the stiffness: any other
## change of its pace stays; ExhibitMods).
func _release(exhibit: Variant) -> void:
	if is_instance_valid(exhibit):
		ExhibitMods.clear_pace(exhibit as Enemy, get_instance_id())


func _release_all() -> void:
	for id: int in _stiff.keys():
		_release((_stiff[id] as Array)[0])
	_stiff.clear()


# --- the looks -----------------------------------------------------------------------------

func _build_looks() -> void:
	var iron := LockArt.metal(LockArt.IRON, 0.55)
	var brass := LockArt.metal(BRASS, 0.3)
	var mount := Node3D.new()
	mount.name = "Lamp"
	mount.transform = Transform3D(Basis.looking_at(face, Vector3.UP), at)
	add_child(mount)
	LockArt.box(mount, Vector3(0.5, 0.6, 0.05), Vector3(0, 0, -0.025), iron)
	LockArt.rod(mount, 0.04, Vector3(0, -0.2, -0.05), Vector3(0, -0.2, -OUT + 0.1), iron, 6)
	# the drum along the aim, its lens at the front, a chimney on top
	var drum := Node3D.new()
	drum.name = "Drum"
	add_child(drum)
	var forward := (aim - origin()).normalized()
	var up := Vector3.UP if absf(forward.dot(Vector3.UP)) < 0.95 else Vector3.BACK
	drum.global_transform = Transform3D(Basis.looking_at(forward, up), origin() - forward * 0.2)
	LockArt.rod(drum, 0.22, Vector3(0, 0, 0.3), Vector3(0, 0, -0.2), brass, 16)
	LockArt.rod(drum, 0.06, Vector3(0, 0.2, 0.05), Vector3(0, 0.45, 0.05), iron, 8)
	_lens = StandardMaterial3D.new()
	_lens.albedo_color = Color(0.85, 0.85, 0.8)
	_lens.emission_enabled = true
	_lens.emission = BEAM
	_lens.emission_energy_multiplier = 0.0
	LockArt.rod(drum, 0.18, Vector3(0, 0, -0.2), Vector3(0, 0, -0.23), _lens, 16)
	# the lever under it, the handle out from the wall
	LockArt.box(mount, Vector3(0.16, 0.3, 0.06), Vector3(0.0, -0.55, -0.06), iron)
	LockArt.rod(mount, 0.025, Vector3(0.0, -0.5, -0.08), Vector3(0.0, -0.62, -0.3), LockArt.matte(Color(0.45, 0.18, 0.12), 0.7), 6)
	_beam_mat = StandardMaterial3D.new()
	_beam_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_beam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_beam_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_beam_mat.albedo_color = Color(BEAM.r, BEAM.g, BEAM.b, 0.32)
	_beam_mat.cull_mode = BaseMaterial3D.CULL_DISABLED


## The beam's segments (glowing shafts) and a glow where it lands.
func _show_beam() -> void:
	if _lens != null:
		_lens.emission_energy_multiplier = 4.0 if lit else 0.0
	var segments := path.size() - 1
	while _beams.size() < segments:
		var view := MeshInstance3D.new()
		view.name = "Beam%d" % _beams.size()
		var shaft := CylinderMesh.new()
		shaft.top_radius = 0.11
		shaft.bottom_radius = 0.11
		shaft.radial_segments = 10
		shaft.rings = 1
		shaft.height = 1.0
		view.mesh = shaft
		view.material_override = _beam_mat
		view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(view)
		_beams.append(view)
		var glow := OmniLight3D.new()
		glow.name = "Glow%d" % _glows.size()
		glow.light_color = BEAM
		glow.light_energy = 1.6
		glow.omni_range = 3.0
		glow.shadow_enabled = false
		add_child(glow)
		_glows.append(glow)
	for i in _beams.size():
		var on := i < segments
		_beams[i].visible = on
		_glows[i].visible = on
		if not on:
			continue
		var a := path[i]
		var b := path[i + 1]
		var length := a.distance_to(b)
		var along := (b - a) / maxf(length, 0.001)
		var side := along.cross(Vector3.UP if absf(along.dot(Vector3.UP)) < 0.95 else Vector3.RIGHT).normalized()
		_beams[i].global_transform = Transform3D(Basis(side, along, side.cross(along)).orthonormalized() * Basis.from_scale(Vector3(1.0, length, 1.0)), (a + b) * 0.5)
		_glows[i].global_position = b - along * 0.3
