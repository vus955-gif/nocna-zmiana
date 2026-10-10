class_name Flare
extends Projectile
## The flare gun's shot: a burning flare on a light arc. It flies through
## the guard (never hits him) and cannot be shot down by his own guns; the
## first exhibit or wall it meets gets a small fire blast (Blast) and the
## flare sticks there as a FlareLight: 12 s of warm light, burning the
## exhibit it sticks to. Numbers come from the weapon's (upgraded) data.

const CORE := Color(1.0, 0.92, 0.82)
const GLOW := Color(1.0, 0.36, 0.14)
## The flare in flight and stuck (ArtLibrary id; its "Light" marker sits
## at the burning tip, which flies ahead along -Z).
const MODEL := &"flare_round"

## The shot's numbers (blast, burn, light).
var shot: WeaponData = null
## Who fired it (credited with the hits; his own blast is capped).
var shooter: Node3D = null
## Where it was fired from (a cracked wall counts flares fired up close).
var fired_from := Vector3.INF


## A flare at [param from] flying with [param velocity_]. Add it to the
## tree yourself.
static func launch(from: Vector3, velocity_: Vector3, data: WeaponData, by: Node3D) -> Flare:
	var flare := Flare.new()
	flare.shot = data
	flare.shooter = by
	flare.velocity = velocity_
	flare.damage = DamageInfo.make(data.damage, DamageInfo.Kind.FIRE, by)
	flare._start = Transform3D(Projectile._facing(velocity_), from)
	flare.fired_from = from
	flare._placed = true
	flare.transform = flare._start
	flare.gravity = data.projectile_gravity
	flare.radius = 0.1
	flare.lifetime = 5.0
	flare.hit_mask = Layers.WORLD | Layers.ENEMY
	flare.core_color = CORE
	flare.glow_color = GLOW
	flare.light_energy = 2.2
	flare.break_sound = &"flare_blast"
	var body := by as CollisionObject3D
	if body != null:
		flare.exclude = [body.get_rid()]
	return flare


func _ready() -> void:
	super()
	hurtbox.collision_layer = 0   # the guard's own shots fly past it
	add_child(_make_trail())


## The burning flare_round model instead of the missile's shard (it spins
## along its flight like the shard did), its light moved to the model's
## "Light" marker at the burning tip. Without the model the shard stays.
func _build_visuals() -> void:
	super()
	var shell := ArtLibrary.try_instance(MODEL)
	if shell == null:
		return
	shell.name = "Round"
	for child in _spin.get_children():
		(child as Node3D).visible = false
	for view in shell.find_children("*", "GeometryInstance3D", true, false):
		(view as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_spin.add_child(shell)
	var tip := shell.find_child("Light", true, false) as Node3D
	for child in get_children():
		var light := child as OmniLight3D
		if light != null and tip != null:
			light.position = tip.position


## The first thing it touches: a blast there, and the flare stays burning
## on it (an exhibit) or on the wall.
func _impact(collider: Object, point: Vector3, normal: Vector3) -> void:
	var host := collider as Node3D
	if host != null and not host.has_method(&"take_damage"):
		host = null
	var data := shot if shot != null else WeaponData.new()
	var heading := velocity.normalized()
	var by: Node3D = shooter if is_instance_valid(shooter) else null   # (the guard may be gone by now)
	Blast.explode(self, point + normal * 0.05, data.blast_radius, data.damage, data.knockback,
			DamageInfo.Kind.FIRE, by, heading, &"flare", fired_from)
	FlareLight.stick(get_parent(), point, normal, host, data, by)
	_end(End.HIT if host != null else End.WALL)


## Sparks and smoke streaming behind the flare in flight.
static func _make_trail() -> GPUParticles3D:
	var sparks := GPUParticles3D.new()
	sparks.amount = 40
	sparks.lifetime = 0.45
	sparks.local_coords = false
	var process := ParticleProcessMaterial.new()
	process.direction = Vector3(0.0, 0.0, 1.0)
	process.spread = 30.0
	process.initial_velocity_min = 0.5
	process.initial_velocity_max = 2.0
	process.gravity = Vector3(0.0, -4.0, 0.0)
	process.scale_min = 0.5
	process.scale_max = 1.2
	process.color = Color(1.0, 0.55, 0.25)
	sparks.process_material = process
	sparks.draw_pass_1 = FlareLight.spark_mesh()
	return sparks
