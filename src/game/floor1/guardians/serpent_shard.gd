class_name SerpentShard
extends Projectile
## A shard of turquoise the Serpent's glowing head spits (Serpent: three to
## five per spit, in a fan): a Projectile that flies a true ballistic arc
## from the mouth so that it comes down exactly on its mark on the floor
## (GroundMark.disc, made by the Serpent, faded when the shard bursts)
## after its flight time (CentaurJavelin.launch_velocity). It hurts the
## guard once: where it passes through him in flight (the sweep), or, when
## it bursts on the floor, a wall or a plinth, with its splash: SPLASH
## damage to a guard within [member splash_radius] of the burst. Shootable
## in flight like any Projectile (its hurtbox).

const GRAVITY := 16.0
const TURQUOISE := Color(0.2, 0.75, 0.7)
const TURQUOISE_GLOW := Color(0.45, 1.0, 0.9)

## The guard (the splash's target) and the mark it comes down on.
var target: Node3D = null
var mark: GroundMark = null
var splash_damage: float = SerpentBrain.SPLASH_DAMAGE
var splash_radius: float = SerpentBrain.SPLASH_RADIUS
## Where it was aimed (world).
var landing := Vector3.ZERO

var _splashed := false


## A shard leaving [param from] to come down on [param to] in [param
## flight] s, hurting [param damage_] on a hit and [param splash] round its
## burst; thrown by [param source_] at [param target_].
static func make(from: Vector3, to: Vector3, flight: float, damage_: float, splash: float, source_: Node = null, target_: Node3D = null) -> SerpentShard:
	var shard := SerpentShard.new()
	var info := DamageInfo.make(damage_, DamageInfo.Kind.BALLISTIC, source_)
	info.knockback = 3.0
	shard.damage = info
	shard.velocity = CentaurJavelin.launch_velocity(from, to, flight, GRAVITY)
	shard._start = Transform3D(Projectile._facing(shard.velocity), from)
	shard._placed = true
	shard.transform = shard._start
	shard.landing = to
	shard.target = target_
	shard.splash_damage = splash
	shard.gravity = GRAVITY
	shard.radius = 0.16
	shard.lifetime = 5.0
	shard.material_kind = ExhibitMaterial.Kind.METAL
	shard.core_color = TURQUOISE
	shard.glow_color = TURQUOISE_GLOW
	shard.light_energy = 0.9
	shard.break_sound = &"shard_break"
	shard.name = "SerpentShard"
	return shard


## How long a shard flies [param distance] m (flat): longer spits fly
## longer, within SerpentBrain.SHARD_FLIGHT.
static func flight_time(distance: float) -> float:
	return clampf(0.5 + distance / 18.0, SerpentBrain.SHARD_FLIGHT.x, SerpentBrain.SHARD_FLIGHT.y)


func _ready() -> void:
	super()
	finished.connect(_on_finished)


func _exit_tree() -> void:
	_fade_mark(0.2)


## It struck [param collider] (or the floor): the direct hit, then the
## splash round the burst for a guard standing near.
func _impact(collider: Object, point: Vector3, normal: Vector3) -> void:
	var receiver := collider as Node
	var direct := receiver != null and receiver.has_method(&"take_damage")
	if direct:
		receiver.take_damage(_hit_info(point, normal))
	_splash(point, receiver if direct else null)
	_burst(point, normal, 1.0 if direct else 1.2)
	_end(End.HIT if direct else End.WALL)


## The splash: the guard within splash_radius of [param point] (not the one
## the shard already struck).
func _splash(point: Vector3, struck: Node) -> void:
	if _splashed or not is_instance_valid(target) or target == struck:
		return
	_splashed = true
	var alive: Variant = target.get(&"alive")
	if alive is bool and not alive:
		return
	var off := target.global_position - point
	if Vector2(off.x, off.z).length() > splash_radius + ShockwaveRing.GUARD_RADIUS or off.y > 1.8 or off.y < -1.2:
		return
	var template := damage if damage != null else DamageInfo.new()
	var source: Node = template.source if is_instance_valid(template.source) else null
	var info := DamageInfo.make(splash_damage, DamageInfo.Kind.BLUNT, source)
	var push := Vector3(off.x, 0.0, off.z)
	info.direction = push.normalized() if push.length() > 0.05 else Vector3.UP
	info.knockback = 4.0
	info.position = target.global_position + Vector3.UP
	target.call(&"take_damage", info)


## Turquoise splinters and a flash of its glow.
func _burst(point: Vector3, normal: Vector3, strength: float) -> void:
	Fx.impact(point, normal, ExhibitMaterial.Kind.METAL, strength)
	Fx.impact(point, normal, -1, strength * 0.8)
	for i in 4:
		var fling := (normal + Vector3(randf_range(-0.9, 0.9), randf_range(0.3, 1.2), randf_range(-0.9, 0.9))) * 3.0
		Fx.chunk(point + normal * 0.05, TURQUOISE, randf_range(0.04, 0.08), fling)
	Fx.flash(point + normal * 0.2, TURQUOISE_GLOW, 2.2, 3.5, 0.18)
	Sfx.play_at(break_sound, point, -3.0)


func _on_finished(_reason: End) -> void:
	_fade_mark(0.3)


func _fade_mark(seconds: float) -> void:
	if mark != null and is_instance_valid(mark) and mark.is_inside_tree():
		mark.vanish(seconds)
	mark = null
