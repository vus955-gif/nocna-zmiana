class_name ShaderWarmUp
extends Node3D
## The night start's shader warm-up (Fx.warm_up): under the black fade, a
## small copy of everything a fight draws for the first time stands right
## in front of the camera for FRAMES frames, so the renderer compiles its
## shaders and pipelines then, not in the frame an exhibit first breaks:
## - every material the art library made (ArtLibrary.cached_materials():
##   exhibit shaders and their two-sided debris variants, baked sets,
##   viewmodel copies...), each on a mesh it is really drawn with (a part
##   of a model in the scene; debris and the T-Rex's bones also on a cut
##   piece, MeshShards, which has a vertex layout of its own), else on a
##   small box. Models that may only turn up later (a summoned raptor
##   pack, pickups, the flare round) are made first, so theirs are in too;
## - Fx's own effects (a plain and a glowing particle burst, a debris
##   chunk, a tracer, a bullet hole, a light flash), the weapons' (the
##   flare's sparks and trail, the gatling's smoke, the muzzles' flashes,
##   smoke and casings: MuzzleFx, a speck of Dust) and
##   the wing guardians' (GuardianLooks: beams, sinews of light, marks).
## It removes itself after FRAMES frames. The camera sees it for that long:
## call it only while the screen is black.

const NODE_NAME := &"ShaderWarmUp"
## Frames it stays (particles draw from their second frame on).
const FRAMES := 3
## How far in front of the camera (m), how big each copy is drawn (m) and
## the spacing of the grid they stand in.
const DISTANCE := 1.0
const ITEM_SIZE := 0.04
const SPACING := 0.05
## The grid: COLUMNS wide, centred, rows from below the middle up (about
## 750 copies fit in a 70 degree view).
const COLUMNS := 32
const FIRST_ROW := -12
## Models a night may only show later (summons, loot, a fired flare): made
## once here, so their materials exist and get warmed.
const LATER_MODELS: Array[StringName] = [&"wax_figure", &"wolf", &"knight", &"bust_enemy", &"raptor"]
const LATER_PICKUPS: Array[StringName] = [&"ammo_pistol", &"ammo_shells", &"ammo_rifle", &"ammo_flares", &"medkit",
	&"fuse", &"crystal_loose", &"ammo_rifle_hunt", &"ammo_harpoon", &"ammo_hwacha"]

var _left: int = FRAMES
var _count: int = 0
var _box: BoxMesh


## Puts a warm-up in front of [param camera] (replacing a running one),
## borrowing meshes from [param root]'s models. Returns it.
static func start(root: Node, camera: Camera3D) -> ShaderWarmUp:
	var running := camera.get_node_or_null(NodePath(String(NODE_NAME)))
	if running != null:
		camera.remove_child(running)
		running.queue_free()
	var warm := ShaderWarmUp.new()
	warm.name = NODE_NAME
	warm.position = Vector3(0.0, 0.0, -DISTANCE)
	camera.add_child(warm)
	warm._build(root)
	return warm


## Copies standing in front of the camera now.
func item_count() -> int:
	return _count


func _process(_delta: float) -> void:
	_left -= 1
	if _left <= 0:
		queue_free()


func _build(root: Node) -> void:
	_box = BoxMesh.new()
	_box.size = Vector3.ONE * ITEM_SIZE
	var later := Node3D.new()
	later.name = "Later"
	later.visible = false   # only made for their materials
	add_child(later)
	for id in LATER_MODELS:
		var model := ArtLibrary.exhibit(id)
		if model != null:
			later.add_child(model)
	for id in LATER_PICKUPS:
		var model := ArtLibrary.pickup(id)
		if model != null:
			later.add_child(model)
	var round := ArtLibrary.try_instance(Flare.MODEL)
	if round != null:
		later.add_child(round)
	var carriers := _carriers([root, later])
	for material in ArtLibrary.cached_materials():
		_warm_material(material, carriers)
	_warm_effects()


## Material -> a mesh drawn with it, from every model under [param roots].
func _carriers(roots: Array) -> Dictionary:
	var out := {}
	for root: Node in roots:
		if root == null:
			continue
		for node in root.find_children("*", "MeshInstance3D", true, false):
			var view := node as MeshInstance3D
			if view == null or view.mesh == null:
				continue
			for i in view.mesh.get_surface_count():
				var material := view.get_active_material(i)
				if material != null and not out.has(material):
					out[material] = view.mesh
	return out


func _warm_material(material: Material, carriers: Dictionary) -> void:
	var shader := material as ShaderMaterial
	var debris := shader != null and shader.shader == ArtLibrary.EXHIBIT_DEBRIS_SHADER
	var exhibit := shader != null and shader.shader in [ArtLibrary.EXHIBIT_SHADER, ArtLibrary.EXHIBIT_WAX_SHADER]
	var mesh: Mesh = carriers.get(material)
	if debris:
		# a whole part flies with the model's mesh, a torn one as a cut piece
		mesh = carriers.get(ArtLibrary.exhibit_material(material.resource_name))
	if mesh == null:
		_add(_box, material)
		return
	_add(mesh, material)
	if debris or exhibit:
		var piece := MeshShards.cut_piece(mesh)
		if piece != null:
			_add(piece.mesh, material)


func _warm_effects() -> void:
	var plain := Fx.burst_node(Color(0.62, 0.6, 0.56), false, 6, 2.0, 0.6, 40.0, 9.8, 0.045)
	var glowing := Fx.burst_node(ExhibitMaterial.particle_color(ExhibitMaterial.Kind.METAL), true, 6, 2.0, 0.6, 40.0, 9.8, 0.045)
	for particles: GPUParticles3D in [plain, glowing, FlareLight._particles(6, 0.4, 1.0, 30.0, 9.0, Color(1.0, 0.62, 0.3)),
			Flare._make_trail(), GatlingDriver._make_smoke()]:
		_place(particles)
		particles.emitting = true
	_place(Fx.chunk_view(ExhibitMaterial.color(ExhibitMaterial.Kind.WAX), Vector3.ONE * ITEM_SIZE))
	_place(Fx.tracer_view(Color(1.0, 0.85, 0.55), 0.012, ITEM_SIZE))
	# shots in flight (the flare, a bust's shard, a portrait's gob): core,
	# halo and trail
	for pair: Array in [[Projectile._shard_mesh(), Projectile._core_material(Flare.CORE, Flare.GLOW)],
			[Projectile._halo_mesh(), Projectile._additive_material(Flare.GLOW, 0.35)],
			[Projectile._trail_mesh(), Projectile._additive_material(Flare.GLOW, 1.0)]]:
		_add(pair[0], pair[1])
	for material in GuardianLooks.warm_set():
		_add(_box, material)
	# the weapons' muzzles: a fire star per flash colour, smoke, casings
	for node in MuzzleFx.warm_set():
		_place(node)
	# decals: a bullet hole, a paint puddle, every surface's mark and a
	# scorch (each texture joins the atlas)
	var textures: Array = [null, PaintPuddle._splat_texture(), Fx.mark_texture(Fx.SCORCH)]
	for surface in Surface.ALL:
		textures.append(Fx.mark_texture(surface))
	for texture: Texture2D in textures:
		var decal := Fx.hole_decal()
		if texture != null:
			decal.texture_albedo = texture
		decal.size = Vector3.ONE * ITEM_SIZE
		_place(decal)
	var flash := OmniLight3D.new()
	flash.light_energy = 0.01
	flash.omni_range = 0.2
	_place(flash)
	var mote := DustMote.new()
	mote.lifetime = 0.25
	_place(mote)


## A copy of [param mesh] with every surface in [param material], shrunk
## to ITEM_SIZE, in the next place of the grid.
func _add(mesh: Mesh, material: Material) -> void:
	var view := MeshInstance3D.new()
	view.mesh = mesh
	for i in mesh.get_surface_count():
		view.set_surface_override_material(i, material)
	var size := mesh.get_aabb().size
	var longest := maxf(size.x, maxf(size.y, size.z))
	view.scale = Vector3.ONE * (ITEM_SIZE / longest if longest > 0.0001 else 1.0)
	view.position = -mesh.get_aabb().get_center() * view.scale.x
	var slot := Node3D.new()
	slot.add_child(view)
	_place(slot)


func _place(node: Node3D) -> void:
	var column := _count % COLUMNS
	var row := _count / COLUMNS
	node.position += Vector3((column - COLUMNS * 0.5) * SPACING, (row + FIRST_ROW) * SPACING, 0.0)
	add_child(node)
	_count += 1
