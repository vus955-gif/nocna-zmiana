class_name EnvGlass
extends EnvProp
## A glass display case (every "case" piece with glass in its look; plan
## docs/superpowers/plans/2026-10-21-srodowisko-walka.md): any real hit -
## a round, a pellet, a punch, a blast, a falling tool - breaks its glass
## at once (EnvRules.breaks_glass; a taser's arc only crackles on it): the
## panes vanish and burst into shards, the crash carries NOISE_GLASS metres
## (the exhibits that hear it come to look), and exhibits right beside it
## are cut. Its hit zone is the glass: a shot at an exhibit behind it
## breaks it first (a rifle round goes on through, as through any target).
## The case's body stays as it was (level geometry); broken, its zone goes
## and shots meet the body again. Broken for the night.

const KIT := &"case"
## Exhibits whose hit zones lie this far past the glass's half size are cut.
const CUT_REACH := 0.9
const CUT_DAMAGE := 8.0
const SHARDS := 8

## [view, surface] pairs of the glass (EnvBreak.glass_of).
var panes: Array = []
## The glass's box in the prop's (the piece's) frame.
var box := AABB()


## A glass prop on every case of [param layer]'s level outside the havens.
static func scan(layer: EnvLayer) -> void:
	for root in layer.piece_roots():
		for piece in root.get_children():
			if piece.get_meta(&"kit", &"") != KIT or layer.owned.has(piece):
				continue
			var room_id: StringName = piece.get_meta(&"kit_room", &"")
			if layer.skips(room_id):
				continue
			var glass := make(piece as Node3D, room_id)
			if glass != null:
				layer.add_prop(glass)


## The glass of [param piece] as a prop (placed on the piece), or null when
## its look has no glass.
static func make(piece: Node3D, room_id: StringName) -> EnvGlass:
	var look := piece.get_node_or_null(^"Visual")
	if look == null:
		return null
	var found := EnvBreak.glass_of(look)
	if found.is_empty():
		return null
	var views: Array = []
	for pane: Array in found:
		if not views.has(pane[0]):
			views.append(pane[0])
	var glass := EnvGlass.new()
	glass.name = "Glass"
	glass.id = EnvLayer.make_id(&"glass", room_id, piece.global_position)
	glass.room = room_id
	glass.target = piece
	glass.panes = found
	glass.transform = piece.global_transform
	glass.box = EnvBreak.bounds(views, piece.global_transform)
	# the case's body is solid round the glass (the glass sits inside its
	# box): the zone covers the body's sides at the glass's height, a touch
	# proud of them, and is anchored on its four sides
	var size: Vector3 = piece.get_meta(&"kit_size", glass.box.size)
	var body := AABB(Vector3(-size.x * 0.5, 0.0, -size.z * 0.5), size).merge(glass.box)
	var shape := BoxShape3D.new()
	shape.size = Vector3(body.size.x + 0.06, glass.box.size.y + 0.04, body.size.z + 0.06)
	var middle := Vector3(body.get_center().x, glass.box.get_center().y, body.get_center().z)
	glass.add_zone_round(shape, Transform3D(Basis.IDENTITY, middle), body)
	if piece is CollisionObject3D:
		# a rifle round through the glass goes on past the case (Hitscan.pierce)
		for zone in glass.zones:
			zone.set_meta(&"pierced_bodies", [(piece as CollisionObject3D).get_rid()])
	return glass


func _hit(info: DamageInfo) -> void:
	if not EnvRules.breaks_glass(info):
		if EnvRules.real(info):
			Fx.impact(info.position, info.normal, ExhibitMaterial.Kind.METAL, 0.4)   # an arc crackles on the glass
		return
	shatter(info)


## Breaks the glass: shards, the crash, exhibits beside it cut.
func shatter(info: DamageInfo = null) -> void:
	if is_down:
		return
	var center := global_transform * box.get_center()
	var push := EnvBreak.flat_push(info) if info != null else Vector3.ZERO
	EnvBreak.hide_panes(panes)
	EnvBreak.glass_chunks(center, box, global_transform, push, SHARDS)
	Fx.impact(center, -push if push != Vector3.ZERO else Vector3.UP, ExhibitMaterial.Kind.MARBLE, 1.4)
	Sfx.play_at(&"glass_break", center, 0.0, 0.08)
	noise(center, EnvRules.NOISE_GLASS, &"glass")
	var reach := maxf(box.size.x, box.size.z) * 0.5 + CUT_REACH
	for exhibit in EnvBreak.exhibits_near(self, center, reach):
		var cut := DamageInfo.make(CUT_DAMAGE, DamageInfo.Kind.BLUNT, credited())
		cut.position = (exhibit as Node3D).global_position + Vector3.UP
		cut.direction = ((exhibit as Node3D).global_position - center).normalized()
		cut.weapon = &"env"
		exhibit.take_damage(cut)
	mark_down()


func _finish_down() -> void:
	EnvBreak.hide_panes(panes)
