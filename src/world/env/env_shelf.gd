class_name EnvShelf
extends EnvProp
## A shelf of books or clay tablets (the "shelf" pieces of the Reading Room,
## the Enlightenment's library and stacks, Ashurbanipal's library; plan
## docs/superpowers/plans/2026-10-21-srodowisko-walka.md): every hit on its
## face throws out pages - more the heavier the hit (EnvRules.pages_for) -
## or chips of baked clay, and leaves its mark in the wood as a wall would.
## Nothing breaks for good (the flying books' shelves stay shelves).

const KIT := &"shelf"
const BOOK_ROOMS: Array[StringName] = [&"court_reading", &"enlightenment_library", &"enlightenment_library_gallery",
	&"enlightenment_stacks", &"enlightenment_archive", &"enlightenment_study", &"enlightenment_bindery"]
const TABLET_ROOMS: Array[StringName] = [&"assyria_library", &"assyria_tablets"]
## A shelf answers at most once in this many physics frames (a gatling's
## stream).
const COOLDOWN_FRAMES := 9
const BINDINGS: Array[Color] = [Color(0.42, 0.12, 0.1), Color(0.18, 0.24, 0.16), Color(0.3, 0.2, 0.12), Color(0.15, 0.17, 0.3)]
const CLAY := Color(0.66, 0.5, 0.32)

## Books (true) or tablets (false).
var books: bool = true
var _ready_at: int = 0


static func scan(layer: EnvLayer) -> void:
	for root in layer.piece_roots():
		for piece in root.get_children():
			if piece.get_meta(&"kit", &"") != KIT or layer.owned.has(piece):
				continue
			var room_id: StringName = piece.get_meta(&"kit_room", &"")
			if not BOOK_ROOMS.has(room_id) and not TABLET_ROOMS.has(room_id):
				continue
			if layer.skips(room_id):
				continue
			layer.add_prop(make(piece as Node3D, room_id))


static func make(piece: Node3D, room_id: StringName) -> EnvShelf:
	var shelf := EnvShelf.new()
	shelf.name = "Shelf"
	shelf.id = EnvLayer.make_id(&"shelf", room_id, piece.global_position)
	shelf.room = room_id
	shelf.target = piece
	shelf.books = not TABLET_ROOMS.has(room_id)
	shelf.transform = piece.global_transform
	var size: Vector3 = piece.get_meta(&"kit_size", Vector3(1.0, 1.8, 0.5))
	var shape := BoxShape3D.new()
	shape.size = Vector3(size.x, size.y * 0.92, 0.08)
	shelf.add_zone(shape, Transform3D(Basis.IDENTITY, Vector3(0.0, size.y * 0.5, -size.z * 0.5 - 0.04)))
	return shelf


func _hit(info: DamageInfo) -> void:
	if not EnvRules.real(info):
		return
	var now := Engine.get_physics_frames()
	if now < _ready_at:
		return
	_ready_at = now + COOLDOWN_FRAMES
	var front := -global_basis.z.normalized()
	var normal := info.normal if info.normal.length() > 0.1 else front
	Fx.surface_impact(info.position, normal, Surface.WOOD, 0.6)
	Fx.mark(info.position, normal, Surface.WOOD, 0.12)
	if books:
		PageFlutter.scatter(info.position + front * 0.1, EnvRules.pages_for(info), front * 1.4 + Vector3.UP * 0.6, info.kind == DamageInfo.Kind.FIRE)
		if EnvRules.weight(info) >= EnvRules.HEAVY:
			for i in 2:
				var size := Vector3(0.05, 0.22, 0.16)
				Fx.chunk(info.position + front * 0.1, BINDINGS[randi() % BINDINGS.size()], size.x * 2.0, front * randf_range(1.5, 3.0) + Vector3(randf_range(-0.8, 0.8), randf_range(0.5, 1.5), randf_range(-0.8, 0.8)))
		Sfx.play_at(&"book_flap", info.position, -10.0, 0.15)
	else:
		EnvBreak.chunks(info.position + front * 0.1, CLAY, 2 + int(EnvRules.weight(info) * 4.0), 0.06, front * 2.0)
		Fx.puff(info.position + front * 0.1, CLAY.lightened(0.3), 8, 0.3)
		Sfx.play_at(&"hit_marble", info.position, -8.0, 0.1, 1.2)
