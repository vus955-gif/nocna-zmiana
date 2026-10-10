class_name OrreryRig
extends RefCounted
## The Great Orrery's body: the Blender model "planetarium" (ArtLibrary;
## 17 rigid parts on their pivots, docs/art/kit-pietro1-oswiecenie.md §5)
## driven by a Pose, or a greybox with the same part names and pivots when
## the model is off. apply() turns the parts:
## - the three tiers about the column (their spin, and a little rock of
##   heavy brass on its bearing: roll about the first arm, pitch across);
## - the planets on their rods (each spins about its own axis; a hit jolts
##   it on its rod) - a planet in flight or shot off is the fight's: the rig
##   only spins it (flying) or keeps it hidden (gone);
## - the high tier's ten hanging moons, cut out of its mesh here so each
##   swings on its rod (a pendulum: tangential, outward); Earth's Moon on
##   its crank (cut out of Earth: it circles her) and Saturn's rings (cut
##   out: they rock);
## - the six petals of the sun about their hinges (+1.6 rad = open), the
##   core's glow and a light at the sun's heart;
## - two signal lamps on each tier's arm tips (amber low, red middle, ice
##   blue high: the warning of a surge), each with a small light;
## - the glow of the exhibit shader per mesh: awake (rim), glow (the
##   tiers' heat in a warning, the planets' pulse, the core), flash (hits).
## Model space = the Planetarium node's: origin on the floor on the axis.

const G := preload("res://src/game/floor1/guardians/orrery_geometry.gd")

const LAMP_COLORS: Array[Color] = [Color(1.0, 0.6, 0.18), Color(1.0, 0.22, 0.12), Color(0.55, 0.8, 1.0)]
const SUN_COLOR := Color(1.0, 0.74, 0.38)
## A lamp's bulb.
const LAMP_RADIUS := 0.075
## The sun's light: range, energy at glow 1.
const SUN_RANGE := 15.0
const SUN_ENERGY := 2.4

## Target posture.
class Pose:
	## Spin of each tier (rad, rotation.y) and its rock: x = roll about its
	## first arm, y = pitch across it (rad).
	var tier_yaw: Array[float] = [0.0, 0.0, 0.0]
	var tier_rock: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO]
	## The heat of a tier's warning (0..1) and its lamps (0..1).
	var tier_glow: Array[float] = [0.0, 0.0, 0.0]
	var lamps: Array[float] = [0.0, 0.0, 0.0]
	## Each planet's own spin (rad), its glow, its jolt off the socket (m,
	## its tier's space).
	var planet_spin: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
	var planet_glow: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
	var planet_jolt: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO]
	## Each hanging moon's swing on its rod: x = forward (the tier's turning
	## way at positive spin), y = outward (rad).
	var moon_swing: Array[Vector2] = []
	## Earth's Moon round her (rad, in her tier's space) and the rings' rock.
	var earth_moon: float = 0.0
	var rings: Vector2 = Vector2.ZERO
	## Each petal's opening (rad, 1.6 = open).
	var petals: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
	## The core's glow (0 dark .. 2 blazing), the rim light (0 asleep .. 1).
	var sun: float = 0.0
	var awake: float = 0.0

	func _init() -> void:
		moon_swing.resize(G.moon_count())
		moon_swing.fill(Vector2.ZERO)


var model: Node3D
var parts: Dictionary = {}
var rest: Dictionary = {}
var meshes: Array[MeshInstance3D] = []
var greybox := false
var tiers: Array[Node3D] = []
var planets: Array[Node3D] = []
var petals: Array[Node3D] = []
## The hanging moons' pivots (the tops of their rods) and their views.
var moons: Array[Node3D] = []
var moon_views: Array[MeshInstance3D] = []
## Earth's Moon's pivot (Earth's centre) and Saturn's rings' pivot, with
## their views (null when the model had none to cut).
var earth_moon: Node3D
var earth_moon_view: MeshInstance3D
var saturn_rings: Node3D
var saturn_rings_view: MeshInstance3D
var lamps: Array[MeshInstance3D] = []
var lamp_lights: Array[OmniLight3D] = []
var sun_light: OmniLight3D
## Planets in flight (placed by the fight; the rig spins them only) and
## shot off (hidden).
var flying: Array[bool] = [false, false, false, false, false, false]
var gone: Array[bool] = [false, false, false, false, false, false]

var _lamp_mats: Array[StandardMaterial3D] = []
var _flash := PackedFloat32Array()
var _sent := PackedFloat32Array()
var _planet_index: Array[int] = []
var _time: float = 0.0


## The rig under [param parent] (the model, or the greybox when the model is
## off or missing).
static func create(parent: Node3D) -> OrreryRig:
	var rig := OrreryRig.new()
	rig.model = ArtLibrary.exhibit(&"planetarium")
	if rig.model == null:
		rig.model = _make_greybox()
		rig.greybox = true
	rig.model.name = "Orrery"
	parent.add_child(rig.model)
	for node in rig.model.find_children("*", "Node3D", true, false):
		rig.parts[String(node.name)] = node
		rig.rest[String(node.name)] = (node as Node3D).transform
	rig._setup()
	return rig


func part(part_name: String) -> Node3D:
	return parts.get(part_name) as Node3D


## Planet [param planet]'s (0..5) socket now (world).
func socket_world(planet: int) -> Vector3:
	return part("socket_%d" % (planet + 1)).global_position


## The core's centre (world).
func core_world() -> Vector3:
	return part("sun_core").global_position


## The axis petal [param petal] (0..5) opens about (model space).
static func petal_axis(petal: int) -> Vector3:
	var angle := deg_to_rad(30.0 + 60.0 * petal)
	return Vector3(-sin(angle), 0.0, -cos(angle))


## Poses the model from [param p].
func apply(p: Pose, delta: float = 0.0) -> void:
	_time += delta
	for t in 3:
		var along := G.arm_direction(t, 0)
		var across := Vector3.UP.cross(along)
		var turn := Basis(Vector3.UP, p.tier_yaw[t]) * Basis(along, p.tier_rock[t].x) * Basis(across, p.tier_rock[t].y)
		tiers[t].transform = Transform3D(turn, (rest[G.TIER_NAMES[t]] as Transform3D).origin)
	for k in planets.size():
		var planet := planets[k]
		if gone[k]:
			continue
		var spin := Basis(Vector3.UP, p.planet_spin[k])
		if flying[k]:
			planet.basis = spin
		else:
			planet.transform = Transform3D(spin, (rest[String(planet.name)] as Transform3D).origin + p.planet_jolt[k])
	for m in moons.size():
		var swing: Vector2 = p.moon_swing[m]
		var along := G.arm_direction(G.HIGH, m / G.MOON_RADII.size())
		var forward := Vector3.UP.cross(along)
		moons[m].transform = Transform3D(Basis(along, swing.x) * Basis(forward, -swing.y), G.moon_pivot(m))
	if earth_moon != null:
		earth_moon.rotation = Vector3(0.0, p.earth_moon - p.planet_spin[2], 0.0)
	if saturn_rings != null:
		saturn_rings.basis = Basis(Vector3.UP, -p.planet_spin[5]) * Basis.from_euler(Vector3(p.rings.x, 0.0, p.rings.y))
	for k in petals.size():
		var hinge: Transform3D = rest[String(petals[k].name)]
		petals[k].transform = Transform3D(Basis(petal_axis(k), p.petals[k]) * hinge.basis, hinge.origin)
	for t in 3:
		var lit := clampf(p.lamps[t], 0.0, 1.0)
		_lamp_mats[t].albedo_color.a = 0.18 + 0.82 * lit
		for a in 2:
			var light := lamp_lights[t * 2 + a]
			light.visible = lit > 0.02
			light.light_energy = 1.8 * lit
	sun_light.visible = p.sun > 0.03
	sun_light.light_energy = SUN_ENERGY * p.sun
	_glow(p, delta)


## A short white flash on planet [param planet] (a weak hit) or, with -1,
## on the whole brass (a hit on the armour).
func flash(planet: int = -1, amount: float = 1.0) -> void:
	if _flash.is_empty():
		return
	if planet < 0:
		for i in _flash.size():
			_flash[i] = maxf(_flash[i], amount * 0.35)
	elif planet < _planet_index.size() and _planet_index[planet] >= 0:
		_flash[_planet_index[planet]] = maxf(_flash[_planet_index[planet]], amount)


## Planet [param planet] back on its socket, seen (the guard fled: whole
## again).
func restore_planet(planet: int) -> void:
	var node := planets[planet]
	flying[planet] = false
	gone[planet] = false
	node.top_level = false
	node.transform = rest[String(node.name)]
	node.visible = true


## Planet [param planet] leaves its socket: the fight places it in the
## world from now on.
func release_planet(planet: int) -> void:
	var node := planets[planet]
	var at := node.global_transform
	flying[planet] = true
	node.top_level = true
	node.global_transform = at


## Planet [param planet] is shot off: hidden (its stand-in rolls away).
func lose_planet(planet: int) -> void:
	gone[planet] = true
	flying[planet] = false
	var node := planets[planet]
	node.visible = false
	node.top_level = false
	node.transform = rest[String(node.name)]


## The views a shot-off planet leaves behind (Saturn's rings come off on
## their own: [planet, rings]; Earth with her Moon).
func planet_views(planet: int) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	var view := planets[planet] as MeshInstance3D
	if view != null:
		out.append(view)
	if planet == 2 and earth_moon_view != null:
		out.append(earth_moon_view)
	if planet == 5 and saturn_rings_view != null:
		out.append(saturn_rings_view)
	return out


# --- glow ------------------------------------------------------------------------

func _glow(p: Pose, delta: float) -> void:
	for i in _flash.size():
		_flash[i] = move_toward(_flash[i], 0.0, 5.0 * delta)
	if greybox:
		return
	for index in meshes.size():
		var view := meshes[index]
		var key := String(view.name)
		var glow := 0.0
		if key.begins_with("tier_"):
			glow = p.tier_glow[G.TIER_NAMES.find(key)]
		elif key.begins_with("planet_"):
			glow = p.planet_glow[int(key.trim_prefix("planet_")) - 1]
		elif key == "sun_glow":
			glow = p.sun
		elif key == "earth_moon_view":
			glow = p.planet_glow[2]
		elif key == "saturn_rings_view":
			glow = p.planet_glow[5] * 0.6
		elif key.begins_with("moon_"):
			glow = p.tier_glow[G.HIGH] * 0.7
		_set_uniform(view, index * 3, &"glow", glow)
		_set_uniform(view, index * 3 + 1, &"awake", clampf(p.awake, 0.0, 1.0))
		_set_uniform(view, index * 3 + 2, &"flash", _flash[index])


## Sets an instance uniform only when it changed (cheap while still).
func _set_uniform(view: MeshInstance3D, slot: int, uniform: StringName, value: float) -> void:
	if absf(_sent[slot] - value) < 0.004:
		return
	_sent[slot] = value
	view.set_instance_shader_parameter(uniform, value)


# --- setup -------------------------------------------------------------------------

func _setup() -> void:
	for t in 3:
		tiers.append(part(G.TIER_NAMES[t]))
	for k in 6:
		planets.append(part("planet_%d" % (k + 1)))
	for k in 6:
		petals.append(part("sun_shell_%d" % (k + 1)))
	if greybox:
		for m in G.moon_count():
			moons.append(part("moon_pivot_%d" % m))
			moon_views.append(part("moon_%d" % m) as MeshInstance3D)
		earth_moon = part("earth_moon")
		saturn_rings = part("saturn_rings")
	else:
		_cut_moons()
		_cut_earth_moon()
		_cut_rings()
	for t in 3:
		var bulb := GuardianLooks.glow(LAMP_COLORS[t], 0.18)
		_lamp_mats.append(bulb)
		for a in 2:
			var view := MeshInstance3D.new()
			view.name = "Lamp_%d_%d" % [t, a]
			var sphere := SphereMesh.new()
			sphere.radius = LAMP_RADIUS
			sphere.height = LAMP_RADIUS * 2.0
			sphere.radial_segments = 10
			sphere.rings = 5
			view.mesh = sphere
			view.material_override = bulb
			view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			view.position = lamp_point(t, a)
			tiers[t].add_child(view)
			lamps.append(view)
			var light := OmniLight3D.new()
			light.name = "LampLight_%d_%d" % [t, a]
			light.light_color = LAMP_COLORS[t]
			light.omni_range = 3.5
			light.shadow_enabled = false
			light.visible = false
			view.add_child(light)
			lamp_lights.append(light)
	sun_light = OmniLight3D.new()
	sun_light.name = "SunLight"
	sun_light.light_color = SUN_COLOR
	sun_light.omni_range = SUN_RANGE
	sun_light.omni_attenuation = 1.4
	sun_light.shadow_enabled = false
	sun_light.visible = false
	part("sun_glow").add_child(sun_light)
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var view := node as MeshInstance3D
		if view.name.begins_with("Lamp_"):
			continue
		meshes.append(view)
	_flash.resize(meshes.size())
	_flash.fill(0.0)
	_sent.resize(meshes.size() * 3)
	_sent.fill(-1.0)
	for k in 6:
		_planet_index.append(meshes.find(planets[k] as MeshInstance3D))
	# a planet shot off breaks into pieces in the end: cut them in the
	# background
	if not greybox:
		for k in 6:
			for view in planet_views(k):
				MeshShards.warm_slices(view.mesh, 3)


## Where tier [param tier]'s lamp on arm [param arm] sits (its tier's
## space): on the tip block, over the beam.
static func lamp_point(tier: int, arm: int) -> Vector3:
	return G.arm_direction(tier, arm) * G.REACH[tier] + Vector3.UP * (G.BEAM[tier].y + G.TIP.y + LAMP_RADIUS * 0.6 - G.PIVOT[tier])


## The high tier's moons out of its mesh: each a view on a pivot at the top
## of its rod.
func _cut_moons() -> void:
	var tier := tiers[G.HIGH] as MeshInstance3D
	var classify := func(centroid: Vector3) -> int:
		for m in G.moon_count():
			var center := G.moon_center(m)
			if centroid.distance_to(center) < G.MOON_SIZE + 0.04:
				return m + 1
			var top := G.moon_pivot(m)
			if Vector2(centroid.x - top.x, centroid.z - top.z).length() < 0.035 and centroid.y < top.y - 0.008 and centroid.y > center.y:
				return m + 1
		return 0
	var pieces := MeshShards.partition(tier.mesh, classify, G.moon_count() + 1, "orrery_moons")
	var materials := _materials_of(tier)
	if pieces[0] != null:
		_swap_mesh(tier, (pieces[0] as MeshShards.Piece).mesh, materials)
	for m in G.moon_count():
		var pivot := Node3D.new()
		pivot.name = "moon_pivot_%d" % m
		pivot.position = G.moon_pivot(m)
		tier.add_child(pivot)
		moons.append(pivot)
		var piece := pieces[m + 1] as MeshShards.Piece
		var view := MeshInstance3D.new()
		view.name = "moon_%d" % m
		view.position = -G.moon_pivot(m)
		pivot.add_child(view)
		if piece != null:
			_swap_mesh(view, piece.mesh, materials, piece.surfaces)
		moon_views.append(view)
		parts[String(pivot.name)] = pivot
		parts[String(view.name)] = view


func _cut_earth_moon() -> void:
	var earth := planets[2] as MeshInstance3D
	var crank: Array[Vector3] = [Vector3(0.0, -0.12, 0.0), Vector3(-0.303, -0.08, -0.175), G.EARTH_MOON]
	var classify := func(centroid: Vector3) -> int:
		if centroid.distance_to(G.EARTH_MOON) < G.EARTH_MOON_SIZE + 0.04:
			return 1
		if centroid.length() > 0.41:
			for i in 2:
				if G.segment_distance(centroid, centroid, crank[i], crank[i + 1]) < 0.03:
					return 1
		return 0
	var pieces := MeshShards.partition(earth.mesh, classify, 2, "orrery_earth_moon")
	if pieces[1] == null:
		return
	var materials := _materials_of(earth)
	_swap_mesh(earth, (pieces[0] as MeshShards.Piece).mesh, materials)
	earth_moon = Node3D.new()
	earth_moon.name = "earth_moon"
	earth.add_child(earth_moon)
	earth_moon_view = MeshInstance3D.new()
	earth_moon_view.name = "earth_moon_view"
	earth_moon.add_child(earth_moon_view)
	_swap_mesh(earth_moon_view, (pieces[1] as MeshShards.Piece).mesh, materials, (pieces[1] as MeshShards.Piece).surfaces)
	parts["earth_moon"] = earth_moon
	parts["earth_moon_view"] = earth_moon_view


func _cut_rings() -> void:
	var saturn := planets[5] as MeshInstance3D
	var classify := func(centroid: Vector3) -> int: return 1 if centroid.length() > G.SATURN_RINGS.x - 0.08 else 0
	var pieces := MeshShards.partition(saturn.mesh, classify, 2, "orrery_rings")
	if pieces[1] == null:
		return
	var materials := _materials_of(saturn)
	_swap_mesh(saturn, (pieces[0] as MeshShards.Piece).mesh, materials)
	saturn_rings = Node3D.new()
	saturn_rings.name = "saturn_rings"
	saturn.add_child(saturn_rings)
	saturn_rings_view = MeshInstance3D.new()
	saturn_rings_view.name = "saturn_rings_view"
	saturn_rings.add_child(saturn_rings_view)
	_swap_mesh(saturn_rings_view, (pieces[1] as MeshShards.Piece).mesh, materials, (pieces[1] as MeshShards.Piece).surfaces)
	parts["saturn_rings"] = saturn_rings
	parts["saturn_rings_view"] = saturn_rings_view


static func _materials_of(view: MeshInstance3D) -> Array[Material]:
	var out: Array[Material] = []
	for i in view.mesh.get_surface_count():
		out.append(view.get_active_material(i))
	return out


## Gives [param view] [param mesh] with [param materials] (by source surface
## [param surfaces], or in order).
static func _swap_mesh(view: MeshInstance3D, mesh: Mesh, materials: Array[Material], surfaces: PackedInt32Array = PackedInt32Array()) -> void:
	view.mesh = mesh
	for i in mesh.get_surface_count():
		var source := surfaces[i] if i < surfaces.size() else i
		if source < materials.size():
			view.set_surface_override_material(i, materials[source])


## The greybox orrery: the same part names and pivots, simple shapes.
static func _make_greybox() -> Node3D:
	var root := Node3D.new()
	var brass := StandardMaterial3D.new()
	brass.albedo_color = Color(0.7, 0.55, 0.25)
	brass.metallic = 0.6
	brass.roughness = 0.4
	var enamel := StandardMaterial3D.new()
	enamel.albedo_color = Color(0.1, 0.16, 0.42)
	var core := StandardMaterial3D.new()
	core.albedo_color = Color(1.0, 0.6, 0.2)
	core.emission_enabled = true
	core.emission = Color(1.0, 0.55, 0.15)
	var base := _box_view("planetarium", Vector3(5.4, 0.24, 5.4), Vector3(0.0, 0.12, 0.0), brass)
	root.add_child(base)
	var column := _box_view("column", Vector3(0.6, 4.0, 0.6), Vector3(0.0, 2.2, 0.0), brass)
	base.add_child(column)
	var glow := _sphere_view("sun_glow", G.CORE_RADIUS, core)
	glow.position = Vector3(0.0, G.SUN_HEIGHT, 0.0)
	base.add_child(glow)
	var marker := Node3D.new()
	marker.name = "sun_core"
	glow.add_child(marker)
	for k in 6:
		var angle := deg_to_rad(30.0 + 60.0 * k)
		var petal := _box_view("sun_shell_%d" % (k + 1), Vector3(0.9, 1.6, 0.1), Vector3(0.0, 0.8, 0.0), brass)
		petal.basis = Basis(Vector3.UP, angle + PI * 0.5)
		petal.position = Vector3(cos(angle) * G.PETAL_HINGE.x, G.PETAL_HINGE.y, -sin(angle) * G.PETAL_HINGE.x)
		base.add_child(petal)
	for t in 3:
		var tier := MeshInstance3D.new()
		tier.name = G.TIER_NAMES[t]
		var box := BoxMesh.new()
		var band := G.BEAM[t]
		box.size = Vector3((G.REACH[t] + G.TIP.x) * 2.0, band.y - band.x, G.BEAM_HALF * 2.0)
		tier.mesh = box
		tier.material_override = enamel
		tier.position = Vector3(0.0, G.PIVOT[t], 0.0)
		base.add_child(tier)
		# the box lies along X: turn it to the first arm (its mesh, not the node)
		var arms := box.get_mesh_arrays()
		var verts: PackedVector3Array = arms[Mesh.ARRAY_VERTEX]
		var turn := Basis(Vector3.UP, G.ARM_ANGLE[t])
		for i in verts.size():
			verts[i] = turn * verts[i] + Vector3.UP * ((band.x + band.y) * 0.5 - G.PIVOT[t])
		arms[Mesh.ARRAY_VERTEX] = verts
		var turned := ArrayMesh.new()
		turned.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arms)
		tier.mesh = turned
		for k in G.tier_planets(t):
			var planet := _sphere_view("planet_%d" % (k + 1), G.planet_size(k), brass)
			planet.position = G.socket(k)
			tier.add_child(planet)
			var socket := Node3D.new()
			socket.name = "socket_%d" % (k + 1)
			socket.position = G.socket(k)
			tier.add_child(socket)
			if k == 2:
				var pivot := Node3D.new()
				pivot.name = "earth_moon"
				planet.add_child(pivot)
				var moon := _sphere_view("earth_moon_view", G.EARTH_MOON_SIZE, brass)
				moon.position = G.EARTH_MOON
				pivot.add_child(moon)
			if k == 5:
				var pivot := Node3D.new()
				pivot.name = "saturn_rings"
				planet.add_child(pivot)
				var ring := MeshInstance3D.new()
				ring.name = "saturn_rings_view"
				var torus := TorusMesh.new()
				torus.inner_radius = G.SATURN_RINGS.x
				torus.outer_radius = G.SATURN_RINGS.y
				ring.mesh = torus
				ring.scale = Vector3(1.0, 0.05, 1.0)
				ring.material_override = brass
				pivot.add_child(ring)
		if t == G.HIGH:
			for m in G.moon_count():
				var pivot := Node3D.new()
				pivot.name = "moon_pivot_%d" % m
				pivot.position = G.moon_pivot(m)
				tier.add_child(pivot)
				var moon := _sphere_view("moon_%d" % m, G.MOON_SIZE, brass)
				moon.position = G.moon_center(m) - G.moon_pivot(m)
				pivot.add_child(moon)
	return root


static func _box_view(view_name: String, size: Vector3, center: Vector3, material: Material) -> MeshInstance3D:
	var view := MeshInstance3D.new()
	view.name = view_name
	var box := BoxMesh.new()
	box.size = size
	var arrays := box.get_mesh_arrays()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	for i in verts.size():
		verts[i] += center
	arrays[Mesh.ARRAY_VERTEX] = verts
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	view.mesh = mesh
	view.material_override = material
	return view


static func _sphere_view(view_name: String, radius: float, material: Material) -> MeshInstance3D:
	var view := MeshInstance3D.new()
	view.name = view_name
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	sphere.radial_segments = 12
	sphere.rings = 6
	view.mesh = sphere
	view.material_override = material
	return view
