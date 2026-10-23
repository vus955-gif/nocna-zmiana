class_name EnvCeramic
extends EnvProp
## A small ceramic on a plinth (plan docs/superpowers/plans/
## 2026-10-21-srodowisko-walka.md; the backlog's "porcelain in Asia, vases
## in Greece"): every "sculpture" piece no taller than MAX_HEIGHT that
## stands on something (no collision of its own) - the moon jar, the
## celadon, a vase. Any real hit breaks it at once into shards of its own
## mesh: a ring of breaking pottery heard NOISE_CERAMIC metres away. The
## plinth stays empty for the night.

const KIT := &"sculpture"
const MAX_HEIGHT := 1.0
const SHARDS := 6
const DUST := Color(0.86, 0.82, 0.74)


static func scan(layer: EnvLayer) -> void:
	for root in layer.piece_roots():
		for piece in root.get_children():
			if piece.get_meta(&"kit", &"") != KIT or layer.owned.has(piece) or piece is CollisionObject3D:
				continue
			var size: Vector3 = piece.get_meta(&"kit_size", Vector3.ONE)
			var room_id: StringName = piece.get_meta(&"kit_room", &"")
			if size.y > MAX_HEIGHT or layer.skips(room_id):
				continue
			layer.add_prop(make(piece as Node3D, room_id, size))


static func make(piece: Node3D, room_id: StringName, size: Vector3) -> EnvCeramic:
	var jar := EnvCeramic.new()
	jar.name = "Ceramic"
	jar.id = EnvLayer.make_id(&"ceramic", room_id, piece.global_position)
	jar.room = room_id
	jar.target = piece
	jar.transform = piece.global_transform
	var shape := BoxShape3D.new()
	shape.size = size + Vector3.ONE * 0.04
	jar.add_zone(shape, Transform3D(Basis.IDENTITY, Vector3(0.0, size.y * 0.5, 0.0)))
	return jar


func _hit(info: DamageInfo) -> void:
	if EnvRules.breaks_glass(info):
		smash(info)


func smash(info: DamageInfo = null) -> void:
	if is_down:
		return
	var size: Vector3 = target.get_meta(&"kit_size", Vector3.ONE) if is_instance_valid(target) else Vector3.ONE
	var center := global_transform * Vector3(0.0, size.y * 0.5, 0.0)
	var push := EnvBreak.flat_push(info) * 1.5 if info != null else Vector3.ZERO
	var made := 0
	if is_instance_valid(target):
		for view in EnvBreak.views(target):
			if made >= SHARDS:
				break
			made += EnvBreak.shards(view, SHARDS - made, push)
		target.visible = false
	if made == 0:
		EnvBreak.chunks(center, DUST, 5, 0.07, push)
	Fx.puff(center, DUST, 10, 0.35)
	Sfx.play_at(&"break_marble", center, -4.0, 0.1, 1.25)
	noise(center, EnvRules.NOISE_CERAMIC, &"glass")
	mark_down()


func _finish_down() -> void:
	if is_instance_valid(target):
		target.visible = false
