class_name EnvTestbed
extends Level
## A plain hall for the environment tests (plan docs/superpowers/plans/
## 2026-10-21-srodowisko-walka.md): one room ROOM (30 x 30 m, 8 m high, its
## floor at y 0) with a floor and walls, kit pieces and lamps made the way
## LevelBuilder and LevelLighting make them (piece(), lamp()), a guard, the
## night's state of its own ([member run]: no autoload touched) and an
## EnvLayer on demand (install_env()). It stands in for the Museum: the
## layer reads [member player] and [member run] off it.

const ROOM := &"hall"
const HALF := 15.0
const HEIGHT := 8.0

var layout: LevelLayout
var walk_static: Node3D
var structure: Node3D
var lights: Node3D
## The paintings on the walls (the Museum's paintings_root).
var paintings_root: Node3D
var player: Player
var run: NightState
var env: EnvLayer


func setup(with_guard: bool = true) -> void:
	name = "EnvTestbed"
	layout = LevelLayout.new()
	layout.add_room(ROOM, [Rect2(-HALF, -HALF, HALF * 2.0, HALF * 2.0)] as Array[Rect2], 0.0, HEIGHT, Color(0.6, 0.6, 0.6))
	walk_static = _group("Static")
	structure = _group("Structure")
	lights = _group("Lights")
	paintings_root = _group("Paintings")
	_solid(Vector3(HALF * 2.0, 1.0, HALF * 2.0), Vector3(0.0, -0.5, 0.0))
	for side in [-1.0, 1.0]:
		_solid(Vector3(0.4, HEIGHT, HALF * 2.0), Vector3(side * (HALF + 0.2), HEIGHT * 0.5, 0.0))
		_solid(Vector3(HALF * 2.0, HEIGHT, 0.4), Vector3(0.0, HEIGHT * 0.5, side * (HALF + 0.2)))
	_solid(Vector3(HALF * 2.0, 0.4, HALF * 2.0), Vector3(0.0, HEIGHT + 0.2, 0.0))
	run = NightState.new()
	run.name = "Night"
	add_child(run)
	if with_guard:
		player = Player.new()
		player.name = "Guard"
		add_child(player)
		player.respawn(Vector3(0.0, 0.05, 12.0), 0.0)


## A kit piece as the floor's builder makes it (meta kit, kit_size,
## kit_room; a "Visual" greybox look), under the walkable root when it
## collides, else under the structure.
func piece(kit: StringName, at: Vector3, size: Vector3, yaw: float = 0.0, collide: bool = true, room: StringName = ROOM) -> Node3D:
	var spec := PieceSpec.new()
	spec.kit = kit
	spec.position = at
	spec.size = size
	spec.yaw = yaw
	spec.room = room
	spec.collide = collide
	layout.pieces.append(spec)
	var node := LevelKit.make(kit, size, spec.transform(), Color(0.6, 0.6, 0.6), collide)
	node.set_meta(&"kit_room", room)
	(walk_static if collide else structure).add_child(node)
	return node


## A lamp as the floor's lighting makes it (its Light3D, and its fixture
## [param fixture] with meta "light" when given); returns the Light3D.
func lamp(fixture: StringName, at: Vector3, energy: float = 1.5, reach: float = 8.0, room: StringName = ROOM) -> Light3D:
	var spec := layout.add_light(LightSpec.MAIN, at, Color(1.0, 0.8, 0.55), energy, reach, room, fixture)
	return LevelLighting.add_light(lights, spec, Color(0.6, 0.6, 0.6))


## A plain painting (WallPainting) on the wall at [param at] (the middle of
## its canvas on the wall surface), facing the room along [param facing].
func painting(at: Vector3, facing: Vector3 = Vector3.BACK) -> WallPainting:
	var frame := Transform3D(Basis.looking_at(facing, Vector3.UP), at)
	var picture := WallPainting.create(frame, PaintingArt.ids()[0])
	paintings_root.add_child(picture)
	return picture


## The fixture of [param light] (the node with meta "light" = it), or null.
func fixture_of(light: Light3D) -> Node3D:
	for node in lights.get_children():
		if node.has_meta(&"light") and node.get_meta(&"light") == light:
			return node as Node3D
	return null


## The environment layer over what is built so far.
func install_env() -> EnvLayer:
	env = EnvLayer.install(self, self)
	return env


## The tool of catalog-like [param entry] (its room: ROOM) on the layer.
func tool(entry: Dictionary) -> EnvTool:
	var made := EnvCatalog.make_tool(entry, env) as EnvTool
	env.tools.append(made)
	env.add_prop(made)
	return made


## A stand-in exhibit at [param at] (feet): a TargetDummy with a 1.8 m
## hit zone, in the exhibits' group.
func dummy(at: Vector3) -> TargetDummy:
	var target := TargetDummy.new()
	target.name = "Dummy"
	target.add_to_group(&"enemies")
	add_child(target)
	target.global_position = at
	var shape := CapsuleShape3D.new()
	shape.radius = 0.35
	shape.height = 1.8
	target.add_child(Hurtbox.make(target, shape, Vector3(0.0, 0.9, 0.0)))
	return target


## A hit of [param amount] from the guard's [param weapon] (its feel
## profile's weight), landing at [param at] and travelling [param direction].
func hit(amount: float, weapon: StringName, at: Vector3, direction: Vector3 = Vector3.FORWARD, kind: DamageInfo.Kind = DamageInfo.Kind.BALLISTIC) -> DamageInfo:
	var info := DamageInfo.make(amount, kind, player)
	info.weapon = weapon
	info.position = at
	info.direction = direction.normalized()
	info.normal = -info.direction
	if FeelProfile.has(weapon):
		info.impact = FeelProfile.of(weapon).hit_weight
	return info


func _group(label: String) -> Node3D:
	var node := Node3D.new()
	node.name = label
	add_child(node)
	return node


func _solid(size: Vector3, at: Vector3) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = Layers.WORLD
	body.collision_mask = 0
	body.position = at
	var box := BoxShape3D.new()
	box.size = size
	var collider := CollisionShape3D.new()
	collider.shape = box
	body.add_child(collider)
	walk_static.add_child(body)
