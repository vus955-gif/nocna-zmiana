class_name ReliefSpear
extends Projectile
## The spear a relief warrior throws (design pietro-1-projekt 5.2): a flat
## gypsum spear with a bronze tip flying in an arc (gravity), point first,
## a faint warm trail so it reads in the dark; it breaks on what it hits
## and can be shot out of the air like the bust's shard.

const LENGTH := 1.6


## A spear from [param from] with [param velocity_] dealing
## ReliefMoves.THROW_DAMAGE for [param by]. Add it to the tree yourself.
static func throw(from: Vector3, velocity_: Vector3, by: Node3D) -> ReliefSpear:
	var spear := ReliefSpear.new()
	var info := DamageInfo.make(ReliefMoves.THROW_DAMAGE, DamageInfo.Kind.BLUNT, by)
	info.knockback = 3.0
	spear.velocity = velocity_
	spear.damage = info
	spear._start = Transform3D(Projectile._facing(velocity_), from)
	spear._placed = true
	spear.transform = spear._start
	spear.gravity = ReliefMoves.THROW_GRAVITY
	spear.radius = 0.16
	spear.lifetime = 4.0
	spear.light_energy = 0.0
	spear.glow_color = Color(1.0, 0.62, 0.3)
	var body := by as CollisionObject3D
	if body != null:
		spear.exclude = [body.get_rid()]
	return spear


## The warrior's own spear (the model's "spear" part, its point first along
## the flight), or a greybox shaft with a bronze point, instead of the shard.
func _build_visuals() -> void:
	super()
	for child in _spin.get_children():
		(child as Node3D).visible = false
	var mesh := _spear_mesh()
	if mesh.is_empty():
		var shaft := GreyboxArt.part(_spin, "shaft", GreyboxArt.box(Vector3(0.035, 0.05, LENGTH)), Vector3(0.0, 0.0, LENGTH * 0.25), GreyboxArt.material("grey_alabaster"))
		shaft.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var point := GreyboxArt.part(_spin, "point", GreyboxArt.cylinder(0.0, 0.045, 0.22, 6), Vector3(0.0, 0.0, -LENGTH * 0.25 - 0.11), GreyboxArt.material("grey_bronze"), Vector3(-90.0, 0.0, 0.0))
		point.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		return
	var view := MeshInstance3D.new()
	view.name = "spear"
	view.mesh = mesh[0]
	var materials: Array = mesh[1]
	for i in materials.size():
		view.set_surface_override_material(i, materials[i])
	view.rotation_degrees = Vector3(-90.0, 0.0, 0.0)   # its +Y (the point) along the flight
	view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	view.set_instance_shader_parameter(&"awake", 1.0)
	_spin.add_child(view)


## [Mesh, materials] of the relief warrior's spear ([] without the model).
static var _spear: Array = []


static func _spear_mesh() -> Array:
	if _spear.is_empty():
		var source := ArtLibrary.exhibit(&"relief_warrior")
		if source == null:
			return []
		var part := source.find_child("spear", true, false) as MeshInstance3D
		if part != null and part.mesh != null:
			var materials: Array = []
			for i in part.mesh.get_surface_count():
				materials.append(part.get_active_material(i))
			_spear = [part.mesh, materials]
		source.free()
	return _spear
