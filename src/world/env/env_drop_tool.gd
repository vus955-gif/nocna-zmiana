class_name EnvDropTool
extends EnvTool
## A load hanging over the floor that the guard can bring down (plan
## docs/superpowers/plans/2026-10-21-srodowisko-walka.md, backlog #23):
## - &"chandelier": the entrance hall's chandelier (the level's own fixture,
##   taken over): its tag on the chain under the ceiling rose; down, its
##   lamp dies as the chain snaps (the hall goes darker - for the exhibits
##   too) and it smashes in glass and brass;
## - &"storm_lamp": the expedition's storm lamp on a long chain from the
##   Egyptian gallery's beam over the camp: it smashes and its oil burns
##   (EnvFire: mummies in their linen go up twice as fast);
## - &"relief_slab": a relief panel the restorers were re-hanging, in its
##   slings under a chain hoist (deep green: red belongs to tags) in the
##   Nimrud hall: the hoist's pawl gives, the slab drops and cracks.
## The warning: the chain ratchets down a hand's breadth twice, dust falls
## from the mount, the load shivers; its disc is marked on the floor. Down,
## it lies wrecked where it fell (no collision: nothing blocks the way).

## A dropped load falls quicker than free fall (a game's reading).
const DROP_GRAVITY := 24.0
const SLIPS: Array[float] = [0.35, 0.7]
const SLIP := 0.07
## The relief slab: width, height, thickness.
const SLAB := Vector3(2.0, 2.2, 0.3)

var build: StringName = &"chandelier"
## The disc it strikes (m).
var radius: float = 2.0
## Where the chain hangs from (world).
var mount := Vector3.ZERO
## A fire where it lands: {radius, seconds, dps, guard} (empty: none).
var fire: Dictionary = {}

## What falls (the fixture taken over, or the tool's own load).
var load_node: Node3D = null
## The lamp that dies with it (the fixture's, or the storm lamp's own).
var lamp: Light3D = null
var _own_lamp: bool = false
var _chain: Node3D = null
var _rest := Transform3D.IDENTITY
var _slipped: int = 0


## The tool of catalog [param data] for [param layer] (null when its room
## or the fixture it takes over is missing).
static func make(data: Dictionary, layer: EnvLayer) -> EnvDropTool:
	var spec := layer.room_spec(data["room"])
	if spec == null:
		return null
	var tool := EnvDropTool.new()
	tool.entry = data
	tool.id = StringName(data["id"])
	tool.room = data["room"]
	tool.build = data.get("build", &"chandelier")
	tool.floor_y = spec.floor_y
	tool.radius = float(data.get("radius", 2.0))
	tool.exhibit_damage = float(data.get("exhibit_damage", 120.0))
	tool.guard_damage = float(data.get("guard_damage", 35.0))
	tool.knockback = float(data.get("knockback", 8.0))
	tool.fire = data.get("fire", {})
	if tool.build == &"chandelier":
		var fixture := _fixture_near(layer, &"chandelier", data["near"])
		if fixture == null:
			tool.free()
			return null
		layer.owned[fixture] = true
		tool.load_node = fixture
		tool.lamp = fixture.get_meta(&"light") as Light3D if fixture.has_meta(&"light") else null
		tool.transform = Transform3D(Basis.IDENTITY, fixture.global_position)
		tool.mount = Vector3(fixture.global_position.x, spec.ceiling_y, fixture.global_position.z)
	else:
		var at: Vector3 = data["at"]
		tool.transform = Transform3D(Basis(Vector3.UP, float(data.get("yaw", 0.0))), at)
		tool.mount = data.get("mount", Vector3(at.x, spec.ceiling_y, at.z))
	return tool


static func _fixture_near(layer: EnvLayer, kit: StringName, near: Vector3) -> Node3D:
	var root := layer.lights_root()
	if root == null:
		return null
	var best: Node3D = null
	var best_d := 1.5
	for node in root.get_children():
		if node.get_meta(&"kit", &"") != kit or not node is Node3D:
			continue
		var d := (node as Node3D).global_position.distance_to(near)
		if d < best_d:
			best = node
			best_d = d
	return best


func _ready() -> void:
	super()
	match build:
		&"chandelier":
			_build_chandelier()
		&"storm_lamp":
			_build_storm_lamp()
		_:
			_build_slab()
	if is_instance_valid(load_node):
		_rest = load_node.global_transform


func _build_chandelier() -> void:
	var hang := global_position.distance_to(mount)
	# on the chain under the ceiling rose, above the crown
	put_tag(Vector3(0.0, minf(hang - 0.3, 1.8), -0.12), Vector3(0.0, -0.55, -1.0), float(entry.get("tag_scale", 2.0)))
	var body := BoxShape3D.new()
	body.size = Vector3(2.0, 1.6, 1.9)
	add_zone(body, Transform3D(Basis.IDENTITY, Vector3(0.0, 0.7, 0.0)))


func _build_storm_lamp() -> void:
	load_node = Node3D.new()
	load_node.name = "Load"
	add_child(load_node)
	var look := EnvLooks.fit(&"camp_lamp", Vector3(0.36, 0.5, 0.36))
	if look != null:
		look.position = Vector3(0.0, -0.25, 0.0)
		load_node.add_child(look)
	else:
		EnvLooks.cylinder(load_node, 0.13, 0.05, Vector3(0.0, -0.22, 0.0), EnvLooks.BRASS, 16, 0.4, 0.8)
		var glass := EnvLooks.cylinder(load_node, 0.11, 0.3, Vector3(0.0, -0.05, 0.0), Color(1.0, 0.85, 0.55))
		glass.material_override = LevelKit.emissive(Color(1.0, 0.75, 0.45), 2.0)
		EnvLooks.cylinder(load_node, 0.14, 0.06, Vector3(0.0, 0.13, 0.0), EnvLooks.BRASS, 16, 0.4, 0.8)
	EnvLooks.rod(load_node, Vector3(0.0, 0.16, 0.0), Vector3(0.0, 0.3, 0.0), 0.012, EnvLooks.IRON)
	lamp = OmniLight3D.new()
	lamp.name = "Flame"
	lamp.light_color = Color(1.0, 0.68, 0.36)
	lamp.light_energy = 1.5
	(lamp as OmniLight3D).omni_range = 6.0
	lamp.distance_fade_enabled = true
	lamp.distance_fade_begin = LevelLighting.FADE_BEGIN
	lamp.distance_fade_length = LevelLighting.FADE_LENGTH
	load_node.add_child(lamp)
	_own_lamp = true
	_chain = Node3D.new()
	_chain.name = "Chain"
	add_child(_chain)
	EnvLooks.rod(_chain, Vector3(0.0, 0.3, 0.0), to_local(mount), 0.014, EnvLooks.IRON, 0.5, 0.6)
	put_tag(Vector3(0.0, 0.36, 0.05), _facing(Vector3(0.0, -0.25, 1.0)), float(entry.get("tag_scale", 1.2)))
	tag.reparent(load_node)   # on the lamp's own hook: it falls with it
	var body := BoxShape3D.new()
	body.size = Vector3(0.45, 0.6, 0.45)
	add_zone(body, Transform3D(Basis.IDENTITY, Vector3(0.0, -0.02, 0.0)))


func _build_slab() -> void:
	var slab := SLAB
	load_node = Node3D.new()
	load_node.name = "Load"
	add_child(load_node)
	var look := EnvLooks.fit(&"asy_relief_2m", slab, false)
	if look != null:
		load_node.add_child(look)
	else:
		EnvLooks.box(load_node, slab, Vector3(0.0, slab.y * 0.5, 0.0), EnvLooks.GYPSUM, 0.9)
	# the slings to the hook block, which falls with it
	var hook := Vector3(0.0, slab.y + 0.55, 0.0)
	for side in [-1.0, 1.0]:
		EnvLooks.rod(load_node, Vector3(side * slab.x * 0.42, slab.y, 0.0), hook, 0.018, EnvLooks.ROPE, 0.9)
	EnvLooks.box(load_node, Vector3(0.16, 0.2, 0.12), hook + Vector3(0.0, 0.08, 0.0), EnvLooks.STEEL, 0.4, 0.8)
	# the hoist and its chains stay up
	_chain = Node3D.new()
	_chain.name = "Chain"
	add_child(_chain)
	var hoist := to_local(mount) + Vector3.DOWN * 1.0
	EnvLooks.box(self, Vector3(0.5, 0.06, 0.5), to_local(mount) + Vector3.DOWN * 0.03, EnvLooks.STEEL, 0.5, 0.7)
	EnvLooks.rod(self, to_local(mount), hoist + Vector3.UP * 0.22, 0.02, EnvLooks.IRON, 0.5, 0.6)
	EnvLooks.box(self, Vector3(0.3, 0.42, 0.22), hoist, EnvLooks.HOIST, 0.6, 0.3)
	EnvLooks.rod(_chain, hoist + Vector3.DOWN * 0.21, hook + Vector3.UP * 0.18, 0.016, EnvLooks.IRON, 0.5, 0.6)
	put_tag(hoist + Vector3(0.0, 0.0, 0.0), _facing(Vector3(1.0, -0.3, 0.0)), float(entry.get("tag_scale", 1.5)))
	tag.position += tag.basis * Vector3(0.0, 0.0, -0.13)   # on the hoist's face
	var body := BoxShape3D.new()
	body.size = slab + Vector3(0.1, 0.1, 0.1)
	add_zone(body, Transform3D(Basis.IDENTITY, Vector3(0.0, slab.y * 0.5, 0.0)))


func carrier() -> Node3D:
	return load_node if is_instance_valid(load_node) else self


## [param world] (a direction in the world) in the tool's frame.
func _facing(world: Vector3) -> Vector3:
	return global_basis.inverse() * world


func _make_mark() -> GroundMark:
	return GroundMark.disc(radius)


func _travel_time() -> float:
	return sqrt(2.0 * maxf(_drop_height(), 0.1) / DROP_GRAVITY)


func _drop_height() -> float:
	return (load_node.global_position.y if is_instance_valid(load_node) else global_position.y) - floor_y


func _warn_start() -> void:
	_slipped = 0
	Sfx.play_at(&"chain_clank", mount, -2.0, 0.08, 0.9)
	Fx.puff(mount + Vector3.DOWN * 0.1, Color(0.78, 0.74, 0.66), 14, 0.5)


func _warn_tick(_delta: float, progress: float) -> void:
	if not is_instance_valid(load_node):
		return
	if _slipped < SLIPS.size() and progress >= SLIPS[_slipped]:
		_slipped += 1
		Sfx.play_at(&"bolt_rattle", mount, -4.0, 0.1)
		Fx.impact(mount, Vector3.DOWN, ExhibitMaterial.Kind.METAL, 0.6)
	var shiver := Basis(Vector3.BACK, sin(progress * 70.0) * 0.025 * progress)
	var origin := _rest.origin + Vector3.DOWN * SLIP * _slipped
	load_node.global_transform = Transform3D(shiver * _rest.basis, origin)


func _strike() -> void:
	if _chain != null:
		_chain.visible = false
	if not _own_lamp:
		_lamp_out()
	Sfx.play_at(&"chain_break", mount, 0.0)
	Fx.impact(mount, Vector3.DOWN, ExhibitMaterial.Kind.METAL, 2.0)
	if not is_instance_valid(load_node):
		_landed()
		return
	var tween := create_tween()
	tween.tween_property(load_node, ^"global_transform", _wreck(), _travel_time()).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(_landed)


func _landed() -> void:
	var at := Vector3(global_position.x, floor_y, global_position.z)
	for receiver in EnvStrike.in_disc(self, at, radius, 2.2, [self, tag]):
		EnvStrike.hit(receiver, exhibit_damage, DamageInfo.Kind.BLUNT, credited(), at, Vector3.ZERO, knockback, stun)
	var player := guard()
	if EnvStrike.guard_in_disc(player, at, radius, 2.2):
		EnvStrike.hurt_guard(player, guard_damage, by_guard(), at, Vector3.ZERO, knockback, DamageInfo.Kind.BLUNT, credited())
	match build:
		&"chandelier":
			EnvBreak.chunks(at + Vector3.UP * 0.4, EnvBreak.GLASS_COLOR, EnvRules.MAX_PIECES_PER_BREAK, 0.07, Vector3.ZERO)
			Fx.impact(at + Vector3.UP * 0.3, Vector3.UP, ExhibitMaterial.Kind.METAL, 3.0)
			Fx.flash(at + Vector3.UP * 0.5, Color(1.0, 0.7, 0.4), 4.0, 8.0, 0.2)
			Sfx.play_at(&"glass_break", at, 4.0, 0.05, 0.85)
			Sfx.play_at(&"weight_thud", at, 2.0)
			_fixture_out()
		&"storm_lamp":
			EnvBreak.chunks(at + Vector3.UP * 0.2, EnvBreak.GLASS_COLOR, 5, 0.05, Vector3.ZERO)
			Sfx.play_at(&"glass_break", at, 0.0)
			_lamp_out()
			if not fire.is_empty():
				var burn := EnvFire.spawn(self, at, float(fire.get("radius", 1.5)), float(fire.get("seconds", 6.0)), credited(), by_guard())
				burn.dps = float(fire.get("dps", 10.0))
				burn.guard_tick = float(fire.get("guard", 4.0))
		_:
			var made := 0
			if is_instance_valid(load_node):
				for view in EnvBreak.views(load_node):
					if made < 6 and view.mesh is ArrayMesh:
						made += EnvBreak.shards(view, 6 - made, Vector3.UP * 1.5)
			if made == 0:
				EnvBreak.chunks(at + Vector3.UP * 0.3, EnvLooks.GYPSUM, 6, 0.16, Vector3.ZERO)
			Sfx.play_at(&"lock_wall_collapse", at, 0.0)
			Sfx.play_at(&"rubble", at, -2.0)
	Fx.puff(at + Vector3.UP * 0.3, Color(0.78, 0.74, 0.66), 28, radius)
	_feel(at, radius * 2.5)
	noise(at, EnvRules.NOISE_CRASH, ReactionRules.SOURCE_BLAST)
	_struck()


## Where the load lies: on the floor under its mount, wrecked.
func _wreck() -> Transform3D:
	var flat := _rest.basis
	var lift := 0.3
	match build:
		&"chandelier":
			flat = Basis(Vector3.RIGHT, 0.22) * _rest.basis.scaled(Vector3(1.0, 0.55, 1.0))
			lift = 0.05
		&"storm_lamp":
			flat = Basis(Vector3.BACK, 1.4) * _rest.basis
			lift = 0.15
		_:
			# on its back, centred on the spot it was hanging over
			flat = Basis(_rest.basis.x.normalized(), -PI * 0.5) * _rest.basis
			var spot := Vector3(_rest.origin.x, floor_y + 0.16, _rest.origin.z)
			return Transform3D(flat, spot - (flat * Vector3.UP).normalized() * SLAB.y * 0.5)
	return Transform3D(flat, Vector3(_rest.origin.x, floor_y + lift, _rest.origin.z))


func _lamp_out() -> void:
	if not is_instance_valid(lamp):
		return
	if _own_lamp:
		lamp.visible = false
	elif layer != null and layer.has_method(&"put_out"):
		layer.call(&"put_out", lamp)
	else:
		lamp.visible = false


## The chandelier's own glow out for the night: no switch of its circuit
## lights the wreck again (NightModifiers.set_lights skips "env_broken").
func _fixture_out() -> void:
	if is_instance_valid(load_node):
		LevelKit.set_lit(load_node, false)
		load_node.set_meta(&"env_broken", true)


func _rest_down() -> void:
	if _chain != null:
		_chain.visible = false
	_lamp_out()
	if is_instance_valid(load_node):
		if _rest == Transform3D.IDENTITY:
			_rest = load_node.global_transform
		load_node.global_transform = _wreck()
		if build == &"chandelier":
			_fixture_out()
