class_name Planetarium
extends Guardian
## Wielkie Planetarium - the Great Orrery, the Enlightenment wing's guardian
## (design 7.4; plan docs/superpowers/plans/2026-10-03-straznik-planetarium.md):
## a brass and blue-enamel orrery 10 m across in the middle of the
## Planetarium rotunda. For many guards the first guardian: it never moves
## from its post and teaches the weak points, slower and plainer than the
## Colossus. It wakes when the guard steps in - the gears catch, the loop
## of the works starts, the tiers start turning, the sun breathes light,
## the planets light up one by one - and fights with its arena:
## - its three tiers sweep the floor at three heights (OrreryGeometry): the
##   LOW arm is jumped, under the HIGH arm the guard stands in the gap
##   between the hanging moons, the MIDDLE arm is kept away from; a tier
##   about to SURGE (speed up, or from phase 2 turn round) lights its arm
##   lamps, rings its own chime and the gears clatter, at least 0.6 s ahead;
## - it sends a planet out on half an ORBIT round the hall at chest height,
##   centred on the guard (step in, step out, or shoot it), and back;
## - (phase 2+) the sun opens a notch and throws FLARES that arc onto marked
##   spots of the floor.
## Damage counts only through the weak points: the PLANETS (each its own
## share of the health, shot off one by one - two take it to phase 2, four
## to phase 3) and, once the sixth is gone, the bared SUN CORE; the brass
## sparks (x0.1, off the core's share, never more than 40 % of it). A planet
## shot off drops and rolls round the hall (RollingPlanet; Saturn's rings
## roll off on their own, Earth's Moon too).
## Its fall: it seizes - the tiers judder to a stop, sparks fly, the petals
## break off, the core dies (OrreryFall); the keeper drops the Star Key and
## the shard. On later nights dress_arena() stands it in the rotunda still
## and dark.
## Model space = this node's: origin on the floor on the axis.

## Announced (the warning starts) and landed (its active part starts):
## surge, launch, flare.
signal telegraphed(attack: StringName)
signal struck(attack: StringName)
## Tier [param tier]'s arm hit the guard.
signal swept(tier: int)
## Planet [param planet] (0..5) was shot off.
signal planet_shot(planet: int)

const A := OrreryBrain.Attack
const S := OrreryBrain.State
const G := preload("res://src/game/floor1/guardians/orrery_geometry.gd")
const NAMES := {OrreryBrain.Attack.SURGE: &"surge", OrreryBrain.Attack.LAUNCH: &"launch", OrreryBrain.Attack.FLARE: &"flare"}
## Hits outside the weak points count this much.
const ARMOUR := 0.1
## Each planet's share of the health, and the core's (they add up to 1).
const PLANET_SHARE: Array[float] = [0.08, 0.10, 0.12, 0.10, 0.14, 0.12]
const CORE_SHARE := 0.34
## The brass may wear the core's share down to this much of it.
const CORE_FLOOR := 0.6
## An arm running into the guard: damage per tier at ARM_SPEED (m/s, its
## speed where he stands), the factor's range, the knockback, the pause
## before the same arm hurts again; slower than ARM_PUSH_ONLY it shoves.
const ARM_DAMAGE: Array[float] = [14.0, 18.0, 14.0]
const ARM_SPEED := 2.5
const ARM_FACTOR := Vector2(0.6, 1.5)
const ARM_KNOCKBACK := 10.0
const ARM_COOLDOWN := 1.0
const ARM_PUSH_ONLY := 0.35
## The orbit: contact, height, the lane left at the walls, the shares of
## the flight swinging out and back, the arc it sweeps (rad).
const ORBIT_DAMAGE := 16.0
const ORBIT_KNOCKBACK := 9.0
const ORBIT_HEIGHT := 1.25
const ORBIT_LANE := 2.3
const ORBIT_OUT := 0.16
const ORBIT_BACK := 0.2
const ORBIT_ARC := PI
## Flares: flight time per level, a volley's spread (m), the beat between.
const FLARE_FLIGHT: Array[float] = [1.5, 1.5, 1.35, 1.3]
const FLARE_SPREAD := 3.2
const FLARE_STAGGER := 0.22
## The rolling planets' push off their rods (outward, up; m/s).
const SHOT_OFF_PUSH := Vector2(1.6, 1.8)
## Each tier's chime (hit_metal's pitch): the guard learns which arm.
const CHIME: Array[float] = [0.62, 0.8, 1.0]
const GOLD := Color(1.0, 0.78, 0.36)
## The guard's capsule when his own cannot be read.
const GUARD_RADIUS := 0.4
const GUARD_HEIGHT := 1.8

var brain := OrreryBrain.new()
var drives: Array[OrreryDrive] = []
var rig: OrreryRig
var moves: OrreryMoves
## Each planet's share left, and the core's.
var planet_health: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
var core_health: float = 0.0
var core_max: float = 0.0
## Loose in the hall: rolling planets and flares in the air.
var hazards: Array[Node] = []
## The orbits' ellipse: half-axes along the world's X and Z (from the
## hall's walls).
var ellipse := Vector2(7.0, 7.0)

var _look: Node3D
var _zones := {}
var _planet_boxes: Array[Hurtbox] = []
var _petal_boxes: Array[Hurtbox] = []
var _core_box: Hurtbox
var _weak_amount: float = -1.0
var _gold_frame: int = -1
var _arm_cooldown: Array[float] = [0.0, 0.0, 0.0]
var _whoosh_cooldown: Array[float] = [0.0, 0.0, 0.0]
var _guard_radius := GUARD_RADIUS
var _guard_height := GUARD_HEIGHT
## The launch under way: its planet (-1 none), arc ends (rad on the
## ellipse), where it left, its last place and speed, whether it hit.
var _orbit_planet: int = -1
var _orbit_from: float = 0.0
var _orbit_to: float = 0.0
var _orbit_start := Vector3.ZERO
var _orbit_last := Vector3.ZERO
var _orbit_velocity := Vector3.ZERO
var _orbit_hit := false
## Flares still to throw: [seconds into the strike, landing].
var _flare_queue: Array = []
## Chimes to ring: [seconds left, tier].
var _chimes: Array = []
var _gears: AudioStreamPlayer3D
var _spark_timer: float = 0.0
var _settled := false
var _shift_clunk := false


func _init() -> void:
	max_health = 1350.0


## The Great Orrery after its fall (the keeper, every night): still and
## dark on its post, its planets and petals gone.
static func dress_arena(level: MuseumFloorLevel, parent: Node3D) -> Array[Node3D]:
	var props: Array[Node3D] = []
	if level.markers.has(&"guardian_planetarium") and GameState.is_guardian_defeated(&"planetarium"):
		var still := silent_orrery(level.markers[&"guardian_planetarium"])
		parent.add_child(still)
		props.append(still)
	return props


## The seized orrery as a prop at [param at]: tiers where they stopped, no
## planets, no petals, the core dark; its base and column solid.
static func silent_orrery(at: Transform3D) -> Node3D:
	var root := StaticBody3D.new()
	root.name = "SilentOrrery"
	root.collision_layer = Layers.WORLD
	root.transform = at
	var rig := OrreryRig.create(root)
	var pose := OrreryRig.Pose.new()
	pose.tier_yaw = [0.35, -0.45, 2.05]
	pose.tier_rock = [Vector2(0.0, 0.012), Vector2(-0.01, 0.0), Vector2(0.008, -0.01)]
	for k in 6:
		rig.lose_planet(k)
		rig.petals[k].visible = false
	for view in rig.moon_views:
		view.visible = false
	rig.apply(pose)
	for light in rig.lamp_lights:
		light.visible = false
	rig.sun_light.visible = false
	for shape in _base_shapes():
		root.add_child(shape)
	return root


# --- body ----------------------------------------------------------------------------

func _build_body() -> void:
	_look = Node3D.new()
	_look.name = "Look"
	add_child(_look)
	rig = OrreryRig.create(_look)
	for t in 3:
		drives.append(OrreryDrive.new(OrreryBrain.RATE[t]))
	moves = OrreryMoves.new(rig, drives)
	for shape in _base_shapes():
		add_child(shape)
	_build_zones()
	_build_sound()
	_fill_pools()
	brain.telegraphed.connect(_on_telegraphed)
	brain.struck.connect(_on_struck)
	brain.finished.connect(_on_finished)
	brain.state_changed.connect(_on_state_changed)
	rig.apply(moves.compose(brain, 0.0))


## The still base's collision: the stepped drum and the column (the tiers
## have none: their arms are tested against the guard, OrreryGeometry).
static func _base_shapes() -> Array[CollisionShape3D]:
	var out: Array[CollisionShape3D] = []
	var bottom := 0.0
	for ring in G.DRUM:
		var drum := CylinderShape3D.new()
		drum.radius = ring.x
		drum.height = ring.y
		var collider := CollisionShape3D.new()
		collider.shape = drum
		collider.position = Vector3(0.0, ring.y * 0.5, 0.0)
		out.append(collider)
		bottom = ring.y
	var column := CylinderShape3D.new()
	column.radius = G.COLUMN_RADIUS
	column.height = G.SUN_HEIGHT - G.SUN_RADIUS - bottom
	var pillar := CollisionShape3D.new()
	pillar.shape = column
	pillar.position = Vector3(0.0, bottom + column.height * 0.5, 0.0)
	out.append(pillar)
	return out


## Hit zones on the parts (they turn with them): the brass (armour), each
## planet (weak), the core (armour until bared).
func _build_zones() -> void:
	var brass := _zone(&"brass")
	var base := rig.part("planetarium")
	var drum := CylinderShape3D.new()
	drum.radius = G.DRUM[0].x
	drum.height = 0.3
	base.add_child(Hurtbox.make(brass, drum, Vector3(0.0, 0.15, 0.0)))
	var column := CylinderShape3D.new()
	column.radius = G.COLUMN_RADIUS + 0.2
	column.height = G.SUN_HEIGHT - G.SUN_RADIUS - 0.3
	base.add_child(Hurtbox.make(brass, column, Vector3(0.0, 0.3 + column.height * 0.5, 0.0)))
	for t in 3:
		var band := G.BEAM[t]
		for arm in 2:
			var beam := BoxShape3D.new()
			beam.size = Vector3(G.REACH[t] + G.TIP.x - G.HUB, band.y - band.x + G.TIP.y * 2.0, G.TIP_HALF * 2.0)
			var along := G.arm_direction(t, arm)
			var box := Hurtbox.make(brass, beam, along * (G.HUB + G.REACH[t] + G.TIP.x) * 0.5 + Vector3.UP * ((band.x + band.y) * 0.5 - G.PIVOT[t]))
			box.basis = Basis(Vector3.UP, G.ARM_ANGLE[t] + PI * arm)
			rig.tiers[t].add_child(box)
	for m in rig.moons.size():
		var ball := SphereShape3D.new()
		ball.radius = G.MOON_SIZE + 0.03
		rig.moons[m].add_child(Hurtbox.make(brass, ball, G.moon_center(m) - G.moon_pivot(m)))
	for k in 6:
		var petal := rig.petals[k] as MeshInstance3D
		var shell := BoxShape3D.new()
		var box := petal.mesh.get_aabb() if petal != null and petal.mesh != null else AABB(Vector3(-0.5, 0.0, -0.1), Vector3(1.0, 1.6, 0.2))
		shell.size = box.size.max(Vector3.ONE * 0.15) * 0.9
		var guard := Hurtbox.make(brass, shell, box.get_center())
		rig.petals[k].add_child(guard)
		_petal_boxes.append(guard)
	for k in 6:
		var ball := SphereShape3D.new()
		ball.radius = G.planet_size(k) + 0.05
		var box := Hurtbox.make(_zone(StringName("planet_%d" % (k + 1))), ball, Vector3.ZERO, true)
		rig.planets[k].add_child(box)
		_planet_boxes.append(box)
	var core := SphereShape3D.new()
	core.radius = G.CORE_RADIUS + 0.05
	_core_box = Hurtbox.make(_zone(&"core"), core, Vector3.ZERO)
	rig.part("sun_glow").add_child(_core_box)


func _zone(zone_name: StringName) -> GuardianZone:
	var zone := GuardianZone.make(self, zone_name)
	add_child(zone)
	_zones[zone_name] = zone
	return zone


func _build_sound() -> void:
	_gears = AudioStreamPlayer3D.new()
	_gears.name = "Gears"
	_gears.stream = Sfx.stream_of(&"orrery_gears")
	_gears.bus = Sfx.BUS
	_gears.unit_size = 6.0
	_gears.max_distance = 45.0
	_gears.volume_db = -8.0
	_gears.position = Vector3(0.0, 1.5, 0.0)
	add_child(_gears)


## Every planet's share and the core's from the health (after difficulty).
func _fill_pools() -> void:
	for k in 6:
		planet_health[k] = max_health * PLANET_SHARE[k]
	core_max = max_health * CORE_SHARE
	core_health = core_max


# --- damage ----------------------------------------------------------------------------

func take_zone_damage(info: DamageInfo, zone: StringName) -> void:
	if info == null or state == State.DEFEATED or is_frozen():
		return
	if not hit_counts():
		super(info, zone)   # from outside its arena: it glances off
		return
	var planet := _planet_of(zone)
	var weak := false
	var amount := 0.0
	if planet >= 0 and planet_health[planet] > 0.0:
		weak = true
		amount = minf(info.amount, planet_health[planet])
		planet_health[planet] -= amount
	elif zone == &"core" and brain.exposed:
		weak = true
		amount = minf(info.amount, core_health)
		core_health -= amount
		if core_health <= 0.001:
			core_health = 0.0
			amount = health.current   # whatever is left: the core was all of it
	else:
		# the brass: a tenth, off the core's share down to its floor
		amount = minf(info.amount * ARMOUR, maxf(core_health - core_max * CORE_FLOOR, 0.0))
		core_health -= amount
	info.weak_point = weak
	info.blocked = not weak
	if planet >= 0 and weak and planet_health[planet] <= 0.0:
		planet_health[planet] = 0.0
		_shoot_off(planet, info)
	_weak_amount = amount
	super(info, zone)
	_weak_amount = -1.0


func _damage_factor(info: DamageInfo) -> float:
	if _weak_amount < 0.0 or info.amount <= 0.0:
		return ARMOUR
	return _weak_amount / info.amount


## The phases count the planets shot off (OrreryBrain), not the health.
func phase_for(_fraction: float) -> int:
	return brain.phase


func _hit_effects(info: DamageInfo) -> void:
	var planet := _planet_of(hit_zone)
	if info.weak_point:
		Fx.impact(info.position, info.normal, ExhibitMaterial.Kind.METAL, clampf(info.amount / 15.0, 0.8, 2.5))
		Fx.flash(info.position, GOLD, 2.5, 3.0, 0.08)
		Sfx.play_at(&"hit_metal", info.position, 1.0, 0.08, 1.35)
		rig.flash(planet if planet >= 0 else -1, 1.0)
		if planet >= 0:
			var tier_space := rig.tiers[G.planet_tier(planet)].global_basis.inverse()
			moves.hit_planet(planet, tier_space * info.direction, info.amount / 20.0)
	else:
		# the brass shrugs it off: sparks, a dull ring
		Fx.impact(info.position, info.normal, ExhibitMaterial.Kind.METAL, 0.7)
		Sfx.play_at(&"hit_metal", info.position, -7.0, 0.2, 0.7)
		rig.flash(-1, 0.6)


## One blast can strike brass and a planet at once: the grey marker must
## not paint over the gold one.
func _report_hit(info: DamageInfo) -> void:
	var frame := Engine.get_physics_frames()
	if info.weak_point:
		_gold_frame = frame
	elif _gold_frame == frame:
		return
	Events.hit_landed.emit(self, info, false)


## The planet (0..5) of hit zone [param zone], or -1.
static func _planet_of(zone: StringName) -> int:
	var text := String(zone)
	return int(text.trim_prefix("planet_")) - 1 if text.begins_with("planet_") else -1


## Planet [param planet] is shot off its rod: it drops and rolls (Earth's
## Moon and Saturn's rings come off on their own); the brain counts it.
func _shoot_off(planet: int, info: DamageInfo) -> void:
	var node := rig.planets[planet]
	var at := node.global_transform
	var velocity := _planet_velocity(planet)
	var out := Vector3(at.origin.x - global_position.x, 0.0, at.origin.z - global_position.z)
	out = out.normalized() if out.length() > 0.1 else -global_basis.z
	var push := velocity + out * SHOT_OFF_PUSH.x + Vector3.UP * SHOT_OFF_PUSH.y + info.direction * 1.5
	var size := G.planet_size(planet)
	var ball: Array[MeshInstance3D] = [node as MeshInstance3D]
	_roll(RollingPlanet.make(ball, at, push, size))
	if planet == 2 and rig.earth_moon_view != null:
		var moon: Array[MeshInstance3D] = [rig.earth_moon_view]
		_roll(RollingPlanet.make(moon, Transform3D(Basis.IDENTITY, rig.earth_moon_view.global_transform * rig.earth_moon_view.mesh.get_aabb().get_center()), push * 1.2 + Vector3(randf_range(-1.0, 1.0), 0.5, randf_range(-1.0, 1.0)), G.EARTH_MOON_SIZE))
	if planet == 5 and rig.saturn_rings_view != null:
		var rings: Array[MeshInstance3D] = [rig.saturn_rings_view]
		_roll(RollingPlanet.make(rings, at, push * 0.8 + out * 1.5, G.SATURN_RINGS.y, rig.saturn_rings_view.global_basis.y))
	_planet_boxes[planet].collision_layer = 0
	if _orbit_planet == planet:
		_orbit_planet = -1
	rig.lose_planet(planet)
	moves.recoil(G.planet_tier(planet), 1.6)
	var socket := rig.socket_world(planet)
	Fx.impact(socket, Vector3.UP, ExhibitMaterial.Kind.METAL, 3.0)
	Fx.flash(at.origin, GOLD, 4.0, 6.0, 0.3)
	Sfx.play_at(&"lock_chain_break", at.origin, -2.0, 0.1)
	Sfx.play_at(&"hit_metal", at.origin, 3.0, 0.05, 0.5)
	_shake_near(0.25, 20.0)
	brain.planet_lost(planet)
	planet_shot.emit(planet)


func _roll(body: RollingPlanet) -> void:
	body.target = target
	body.source = self
	body.damage_scale = damage_scale
	get_parent().add_child(body)
	hazards.append(body)


## Where planet [param planet] is heading now (world, m/s).
func _planet_velocity(planet: int) -> Vector3:
	if rig.flying[planet]:
		return _orbit_velocity
	var tier := G.planet_tier(planet)
	var at := rig.planets[planet].global_position - global_position
	return Vector3.UP.cross(Vector3(at.x, 0.0, at.z)) * drives[tier].speed


func reward_point() -> Vector3:
	return to_global(Vector3(0.0, 0.0, -4.2))


# --- the fight ---------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	super(delta)
	if is_frozen() or state == State.DEFEATED or not is_inside_tree():
		return
	_animate(delta)


func _on_phase(next: int) -> void:
	if next == 1:
		brain.wake()
		_measure_hall()
		_read_guard()


func _fight_process(delta: float) -> void:
	var local := to_local(target.global_position)
	brain.update(delta, Vector2(local.x, local.z).length())
	velocity.x = 0.0
	velocity.z = 0.0
	_attack_frame(delta)
	_hazards(delta)


## The tiers turn, the body follows its moves, the works sound.
func _animate(delta: float) -> void:
	var still := brain.state == S.DORMANT
	if not hazards.is_empty():
		_prune_hazards()
	if still and _settled:
		return
	for t in 3:
		drives[t].target = brain.tier_target(t)
		drives[t].step(delta)
	moves.flying = rig.flying
	rig.apply(moves.compose(brain, delta), delta)
	_settled = still
	_works(delta)
	_ring_chimes(delta)


## The gears' loop (pitch with the tiers' speed, louder in a warning) and
## sparks where the brass grinds.
func _works(delta: float) -> void:
	if brain.state == S.DORMANT or brain.state == S.DEAD:
		if _gears.playing:
			_gears.stop()
		return
	if not _gears.playing and _gears.stream != null:
		_gears.play()
	var spin := 0.0
	var grind := 0.0
	for t in 3:
		spin += absf(drives[t].speed)
		grind = maxf(grind, absf(drives[t].acceleration))
	var warning := brain.state == S.ATTACK and brain.stage == OrreryBrain.Stage.TELEGRAPH
	warning = warning or ((brain.state == S.SHIFT or brain.state == S.UNVEIL) and brain.state_progress() < OrreryBrain.SHIFT_BRAKE)
	var waking := brain.state_progress() if brain.state == S.WAKING else 1.0
	_gears.pitch_scale = clampf(0.55 + 0.32 * spin / 3.0 + (0.25 if warning else 0.0), 0.4, 1.8) * lerpf(0.6, 1.0, waking)
	_gears.volume_db = lerpf(-20.0, -6.0 if warning else -9.0, waking)
	_spark_timer -= delta
	if grind > 0.4 and _spark_timer <= 0.0:
		_spark_timer = 0.12
		for t in 3:
			if absf(drives[t].acceleration) > 0.4:
				var angle := randf() * TAU
				var at := rig.tiers[t].global_position + Vector3(cos(angle), 0.0, sin(angle)) * 0.62
				Fx.impact(at, Vector3(cos(angle), 0.4, sin(angle)), ExhibitMaterial.Kind.METAL, 0.5)


## The warnings, the strikes and the ends of attacks.
func _on_telegraphed(attack: A) -> void:
	match attack:
		A.SURGE:
			_chime(brain.surge_tier)
			_chimes.append([0.3, brain.surge_tier])
			Sfx.play_at(&"gate_jam", rig.tiers[brain.surge_tier].global_position, -10.0, 0.1)
		A.LAUNCH:
			moves.charging_planet = brain.launch_planet
			moves.charge = 0.0
			var tier := G.planet_tier(brain.launch_planet)
			Sfx.play_at(&"hit_metal", rig.planets[brain.launch_planet].global_position, -1.0, 0.05, CHIME[tier] * 1.25)
			_chimes.append([0.25, tier])
		A.FLARE:
			Sfx.play_at(&"colossus_charge", rig.core_world(), 1.0, 0.02, 1.2)
	telegraphed.emit(NAMES[attack])


func _on_struck(attack: A) -> void:
	match attack:
		A.SURGE:
			var tier := brain.surge_tier
			moves.recoil(tier, 1.2)
			Sfx.play_at(&"lock_bolt_slide", rig.tiers[tier].global_position, 0.0, 0.1)
			Sfx.play_at(&"orrery_sweep", rig.tiers[tier].global_position + Vector3.UP, -2.0, 0.1)
			_shake_near(0.15, 18.0)
		A.LAUNCH:
			_launch(brain.launch_planet)
		A.FLARE:
			_plan_flares()
			moves.flare_burst()
			Sfx.play_at(&"flare_fire", rig.core_world(), 2.0, 0.05, 0.6)
	struck.emit(NAMES[attack])


func _on_finished(_attack: A) -> void:
	moves.charging_planet = -1
	_seat_planet()


func _on_state_changed(_from: S, to: S) -> void:
	match to:
		S.WAKING:
			Sfx.play_at(&"lock_bolt_slide", global_position + Vector3.UP * 1.5, 2.0, 0.05)
			for t in 3:
				_chimes.append([0.35 + 0.2 * t, t])
			_shake_near(0.2, 25.0)
		S.SHIFT, S.UNVEIL:
			_shift_clunk = false
			Sfx.play_at(&"relay", global_position + Vector3.UP * 2.0, 2.0, 0.05)
			for t in 3:
				_chimes.append([0.12 * t, t])
			moves.clunk(0.7)
			_shake_near(0.3, 25.0)
			if to == S.UNVEIL:
				# bloomed open, the petals no longer shield the core
				_core_box.weak_point = true
				(_core_box.get_child(0) as CollisionShape3D).shape.set(&"radius", G.CORE_RADIUS + 0.25)
				for box in _petal_boxes:
					box.collision_layer = 0
				Sfx.play_at(&"colossus_charge", rig.core_world(), 4.0, 0.0, 0.9)
				Fx.flash(rig.core_world(), GOLD, 8.0, 14.0, 0.6)


func _attack_frame(delta: float) -> void:
	if brain.state == S.SHIFT or brain.state == S.UNVEIL:
		var brake := OrreryBrain.SHIFT_BRAKE if brain.state == S.SHIFT else OrreryBrain.UNVEIL_BRAKE
		if not _shift_clunk and brain.state_progress() >= brake:
			_shift_clunk = true
			moves.clunk(1.0)
			Sfx.play_at(&"lock_bolt_slide", global_position + Vector3.UP * 2.0, 3.0, 0.05)
			if brain.state == S.UNVEIL:
				Sfx.play_at(&"lock_wall_crack", rig.core_world(), 2.0, 0.05)
				Fx.flash(rig.core_world(), GOLD, 10.0, 16.0, 0.5)
				_shake_near(0.4, 25.0)
	if brain.state != S.ATTACK:
		return
	match brain.attack:
		A.LAUNCH:
			if brain.stage == OrreryBrain.Stage.TELEGRAPH:
				moves.charge = clampf(brain.clip_time(), 0.0, 1.0)
			elif brain.stage == OrreryBrain.Stage.STRIKE:
				_orbit_frame(delta)
			else:
				_seat_planet()
		A.FLARE:
			if brain.stage == OrreryBrain.Stage.STRIKE:
				_throw_flares()


func _chime(tier: int) -> void:
	for arm in 2:
		var lamp := rig.lamps[tier * 2 + arm]
		Sfx.play_at(&"hit_metal", lamp.global_position, -2.0 + 2.0 * arm, 0.02, CHIME[tier] * (1.0 if arm == 0 else 1.5))


func _ring_chimes(delta: float) -> void:
	var left: Array = []
	for entry: Array in _chimes:
		entry[0] = float(entry[0]) - delta
		if float(entry[0]) <= 0.0:
			_chime(int(entry[1]))
		else:
			left.append(entry)
	_chimes = left


# --- the arms ------------------------------------------------------------------------------

## True when a guard standing on [param feet] (world) with a capsule of
## [param radius] and [param height] touches tier [param tier] now: its
## beams, the rods and planets still on it, its hanging moons where they
## swing.
func tier_touches(tier: int, feet: Vector3, radius: float, height: float) -> bool:
	var to_model := rig.model.global_transform.affine_inverse()
	var local := to_model * feet
	var rest := Basis(Vector3.UP, -rig.tiers[tier].rotation.y) * local
	var riding: Array[bool] = []
	for k in 6:
		riding.append(brain.planets_on[k] and not rig.flying[k] and not rig.gone[k])
	if G.beams_hit(tier, rest, radius, height, riding):
		return true
	for k in G.tier_planets(tier):
		if not riding[k]:
			continue
		if G.capsule_sphere(local, radius, height, to_model * rig.planets[k].global_position, G.planet_size(k)):
			return true
		if k == 2 and rig.earth_moon_view != null:
			var moon := rig.earth_moon_view.global_transform * rig.earth_moon_view.mesh.get_aabb().get_center()
			if G.capsule_sphere(local, radius, height, to_model * moon, G.EARTH_MOON_SIZE):
				return true
	if tier == G.HIGH:
		for m in rig.moons.size():
			var pivot := rig.moons[m]
			var ball := to_model * (pivot.global_transform * (G.moon_center(m) - G.moon_pivot(m)))
			if G.capsule_sphere(local, radius, height, ball, G.MOON_SIZE):
				return true
			if G.capsule_segment(local, radius, height, to_model * pivot.global_position, ball, G.MOON_ROD):
				return true
	return false


func _hazards(delta: float) -> void:
	if not guard_alive():
		return
	var feet := target.global_position
	var local := to_local(feet)
	var reach := Vector2(local.x, local.z).length()
	for t in 3:
		_arm_cooldown[t] -= delta
		_whoosh_cooldown[t] -= delta
		if reach > G.REACH[t] + 1.5:
			continue
		var speed := absf(drives[t].speed) * reach
		if _whoosh_cooldown[t] <= 0.0 and speed > 2.5:
			# an arm sweeping past close by
			_whoosh_cooldown[t] = 1.2
			var near := false
			for arm in 2:
				var along := rig.tiers[t].global_basis * G.arm_direction(t, arm)
				var flat := Vector3(local.x, 0.0, local.z).normalized()
				if (global_basis * flat).angle_to(along) < 0.45:
					near = true
			if near:
				Sfx.play_at(&"orrery_sweep", feet + Vector3.UP, -3.0, 0.1, clampf(speed / 5.0, 0.7, 1.3))
			else:
				_whoosh_cooldown[t] = 0.1
		if _arm_cooldown[t] <= 0.0 and tier_touches(t, feet, _guard_radius, _guard_height):
			_arm_hit(t, local)
	if _orbit_planet >= 0 and not _orbit_hit:
		var ball := rig.planets[_orbit_planet].global_position
		if G.capsule_sphere(feet, _guard_radius, _guard_height, ball, G.planet_size(_orbit_planet)):
			_orbit_hit = true
			var info := DamageInfo.make(ORBIT_DAMAGE * damage_scale, DamageInfo.Kind.BLUNT, self)
			info.direction = _orbit_velocity.normalized() if _orbit_velocity.length() > 0.1 else (feet - global_position).normalized()
			info.knockback = ORBIT_KNOCKBACK
			info.position = feet + Vector3.UP
			target.call(&"take_damage", info)
			Sfx.play_at(&"punch_hit", feet + Vector3.UP, 2.0)
			Sfx.play_at(&"hit_metal", ball, 0.0, 0.1, 0.7)
			_shake_near(0.35, 4.0)


## Tier [param tier]'s arm runs into the guard (at [param local], body
## space): hurt by its speed where he stands, flung along and out of its
## path; a slow arm only shoves him aside.
func _arm_hit(tier: int, local: Vector3) -> void:
	_arm_cooldown[tier] = ARM_COOLDOWN
	var flat := Vector3(local.x, 0.0, local.z)
	var out := global_basis * (flat.normalized() if flat.length() > 0.05 else Vector3.FORWARD)
	var omega := drives[tier].speed
	var speed := absf(omega) * flat.length()
	if speed < ARM_PUSH_ONLY:
		if target is CharacterBody3D:
			(target as CharacterBody3D).velocity += out * 3.0
		_arm_cooldown[tier] = 0.25
		return
	var forward := (global_basis * Vector3.UP.cross(flat.normalized())) * signf(omega)
	var factor := clampf(speed / ARM_SPEED, ARM_FACTOR.x, ARM_FACTOR.y)
	var info := DamageInfo.make(ARM_DAMAGE[tier] * factor * damage_scale, DamageInfo.Kind.BLUNT, self)
	info.direction = (forward * 0.75 + out * 0.65 + Vector3.UP * 0.2).normalized()
	info.knockback = ARM_KNOCKBACK * (0.7 + 0.3 * factor)
	info.position = target.global_position + Vector3.UP
	target.call(&"take_damage", info)
	moves.recoil(tier, 0.5)
	Sfx.play_at(&"punch_hit", target.global_position + Vector3.UP, 2.0)
	Sfx.play_at(&"hit_metal", target.global_position + Vector3.UP, 0.0, 0.1, CHIME[tier] * 0.8)
	_shake_near(0.35, 3.0)
	swept.emit(tier)


# --- the orbit -------------------------------------------------------------------------------

## Planet [param planet] leaves its socket for half an orbit round the
## hall, centred on the guard.
func _launch(planet: int) -> void:
	if planet < 0 or not brain.planets_on[planet]:
		return
	rig.release_planet(planet)
	_orbit_planet = planet
	_orbit_hit = false
	_orbit_start = rig.planets[planet].global_position
	_orbit_last = _orbit_start
	_orbit_velocity = Vector3.ZERO
	var guard := target.global_position if guard_alive() else to_global(Vector3(0.0, 0.0, -8.0))
	var off := guard - global_position
	var center := atan2(off.z / ellipse.y, off.x / ellipse.x)
	# along the tier's turning (a positive spin carries +X toward -Z)
	var way := -signf(drives[G.planet_tier(planet)].speed) if absf(drives[G.planet_tier(planet)].speed) > 0.01 else 1.0
	_orbit_from = center - way * ORBIT_ARC * 0.5
	_orbit_to = center + way * ORBIT_ARC * 0.5
	moves.charging_planet = -1
	moves.recoil(G.planet_tier(planet), 1.4)
	Sfx.play_at(&"orrery_sweep", _orbit_start, 2.0, 0.05, 0.85)


## A point of the orbit at [param angle] (world).
func orbit_point(angle: float) -> Vector3:
	return global_position + Vector3(cos(angle) * ellipse.x, ORBIT_HEIGHT, sin(angle) * ellipse.y)


func _orbit_frame(delta: float) -> void:
	if _orbit_planet < 0:
		return
	var length := OrreryBrain.stage_length(A.LAUNCH, OrreryBrain.Stage.STRIKE, brain.level())
	var s := clampf(brain.stage_time() / length, 0.0, 1.0)
	var at: Vector3
	if s < ORBIT_OUT:
		var k := MotionClip.eased(MotionClip.IN_OUT, s / ORBIT_OUT)
		var to := orbit_point(_orbit_from)
		var lift := _orbit_start.lerp(to, 0.5) + Vector3.UP * 1.2
		at = _bezier(_orbit_start, lift, to, k)
	elif s > 1.0 - ORBIT_BACK:
		var k := MotionClip.eased(MotionClip.IN_OUT, (s - (1.0 - ORBIT_BACK)) / ORBIT_BACK)
		var from := orbit_point(_orbit_to)
		var home := rig.socket_world(_orbit_planet)
		at = _bezier(from, from.lerp(home, 0.5) + Vector3.UP * 1.4, home, k)
	else:
		var k := (s - ORBIT_OUT) / (1.0 - ORBIT_OUT - ORBIT_BACK)
		at = orbit_point(lerpf(_orbit_from, _orbit_to, k)) + Vector3.UP * 0.12 * sin(k * TAU * 2.0)
	var node := rig.planets[_orbit_planet]
	node.global_position = at
	if delta > 0.0:
		_orbit_velocity = (at - _orbit_last) / delta
	_orbit_last = at


## The planet in flight clicks back into its socket.
func _seat_planet() -> void:
	if _orbit_planet < 0:
		return
	var planet := _orbit_planet
	_orbit_planet = -1
	if not brain.planets_on[planet] or rig.gone[planet]:
		return
	rig.restore_planet(planet)
	moves.recoil(G.planet_tier(planet), 1.0)
	moves.hit_planet(planet, Vector3.DOWN, 1.5)
	Sfx.play_at(&"hit_metal", rig.socket_world(planet), 0.0, 0.05, CHIME[G.planet_tier(planet)])


static func _bezier(a: Vector3, control: Vector3, b: Vector3, t: float) -> Vector3:
	return a.lerp(control, t).lerp(control.lerp(b, t), t)


# --- the flares ---------------------------------------------------------------------------------

## The volley's landings: on the guard (where he is heading), and across
## the line from the sun to him.
func _plan_flares() -> void:
	_flare_queue.clear()
	var guard := target.global_position if guard_alive() else to_global(Vector3(0.0, 0.0, -7.0))
	var lead := Vector3.ZERO
	if target is CharacterBody3D:
		var moving := (target as CharacterBody3D).velocity
		lead = Vector3(moving.x, 0.0, moving.z) * 0.35
		lead = lead.limit_length(2.0)
	var aim := Vector3(guard.x, global_position.y, guard.z) + lead
	var line := Vector3(aim.x - global_position.x, 0.0, aim.z - global_position.z)
	line = line.normalized() if line.length() > 0.1 else -global_basis.z
	var across := Vector3.UP.cross(line)
	var spots: Array[Vector3] = [aim]
	var count := brain.flare_count()
	if count >= 3:
		spots.append(aim + across * FLARE_SPREAD)
		spots.append(aim - across * FLARE_SPREAD)
	if count >= 4:
		spots.append(aim + line * 2.6)
	for i in spots.size():
		_flare_queue.append([FLARE_STAGGER * i, _inside(spots[i])])


## [param point] pulled toward the axis until it lies in the hall (and off
## the orrery's drum).
func _inside(point: Vector3) -> Vector3:
	var flat := Vector3(point.x - global_position.x, 0.0, point.z - global_position.z)
	if flat.length() < G.DRUM[0].x + 0.6:
		flat = flat.normalized() * (G.DRUM[0].x + 0.6) if flat.length() > 0.1 else -global_basis.z * (G.DRUM[0].x + 0.6)
	var at := global_position + flat
	if arena_room != &"" and room_of.is_valid():
		for i in 12:
			if room_of.call(at + Vector3.UP * 0.5) == arena_room:
				break
			flat *= 0.88
			at = global_position + flat
	return at


func _throw_flares() -> void:
	var seconds := brain.stage_time()
	while not _flare_queue.is_empty() and float(_flare_queue[0][0]) <= seconds:
		var entry: Array = _flare_queue.pop_front()
		var landing: Vector3 = entry[1]
		var core := rig.core_world()
		var toward := Vector3(landing.x - core.x, 0.0, landing.z - core.z).normalized()
		var from := core + toward * 0.9 + Vector3.UP * 0.5
		var info := DamageInfo.make(SolarFlare.DAMAGE * damage_scale, DamageInfo.Kind.FIRE, self)
		var flare := SolarFlare.launch(from, landing, FLARE_FLIGHT[brain.level()], info, target)
		get_parent().add_child(flare)
		hazards.append(flare)
		Fx.flash(from, GOLD, 3.0, 5.0, 0.15)


# --- calm, freeze, fall ------------------------------------------------------------------------

func _on_reset() -> void:
	brain.reset()
	for drive in drives:
		drive.reset()
	moves.reset()
	_orbit_planet = -1
	_flare_queue.clear()
	_chimes.clear()
	for k in 6:
		rig.restore_planet(k)
		_planet_boxes[k].collision_layer = Layers.HURTBOX
	_core_box.weak_point = false
	(_core_box.get_child(0) as CollisionShape3D).shape.set(&"radius", G.CORE_RADIUS + 0.05)
	for box in _petal_boxes:
		box.collision_layer = Layers.HURTBOX
	_fill_pools()
	_clear_hazards()
	_gears.stop()
	_settled = false
	rig.apply(moves.compose(brain, 0.0))


func _on_freeze() -> void:
	_gears.stop()
	_clear_hazards(true)
	for light in rig.lamp_lights:
		light.visible = false
	rig.sun_light.visible = false


func _on_defeated(info: DamageInfo) -> void:
	brain.die()
	_gears.stop()
	_clear_hazards(true)
	var fall := OrreryFall.make(self, info)
	get_parent().add_child(fall)


## Forgets the hazards that are gone (broken, landed).
func _prune_hazards() -> void:
	var alive: Array[Node] = []
	for node: Variant in hazards:
		if is_instance_valid(node) and not (node as Node).is_queued_for_deletion():
			alive.append(node)
	hazards = alive


## The hazards loose in the hall go ([param flares_only]: the rolling
## planets stay where they are).
func _clear_hazards(flares_only: bool = false) -> void:
	var kept: Array[Node] = []
	for item: Variant in hazards:
		if not is_instance_valid(item) or (item as Node).is_queued_for_deletion():
			continue
		var node := item as Node
		if flares_only and node is RollingPlanet:
			kept.append(node)
			continue
		if node is SolarFlare and is_instance_valid((node as SolarFlare).mark):
			(node as SolarFlare).mark.queue_free()
		node.queue_free()
	hazards = kept


# --- helpers --------------------------------------------------------------------------------------

## The orbit's ellipse from the hall's walls (probed along the world's axes).
func _measure_hall() -> void:
	if arena_room == &"" or not room_of.is_valid():
		ellipse = Vector2(7.0, 7.0)
		return
	var reach := Vector2.ZERO
	for axis in 2:
		var shortest := INF
		for way: float in [1.0, -1.0]:
			var step := Vector3(way, 0.0, 0.0) if axis == 0 else Vector3(0.0, 0.0, way)
			var distance := 0.0
			while distance < 20.0 and room_of.call(global_position + step * (distance + 0.5) + Vector3.UP * 0.5) == arena_room:
				distance += 0.5
			shortest = minf(shortest, distance)
		reach[axis] = shortest
	ellipse = Vector2(clampf(reach.x - ORBIT_LANE, 5.8, 12.0), clampf(reach.y - ORBIT_LANE, 5.8, 12.0))


## The guard's capsule (his own, when he has one).
func _read_guard() -> void:
	if not is_instance_valid(target):
		return
	for node in target.find_children("*", "CollisionShape3D", false, false):
		var capsule := (node as CollisionShape3D).shape as CapsuleShape3D
		if capsule != null:
			_guard_radius = capsule.radius
			_guard_height = capsule.height
			return


## Camera shake for a guard within [param reach] m, fading with distance.
func _shake_near(trauma: float, reach: float) -> void:
	if not guard_alive() or not target is Player:
		return
	var distance := target.global_position.distance_to(global_position)
	if distance < reach:
		Events.shake_requested.emit(trauma * (1.0 - distance / reach))
