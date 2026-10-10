class_name ScarabSwarm
extends Enemy
## A swarm of sacred scarabs (Egypt, design 5.1): about thirty iridescent
## beetles whirling over the floor and a dozen scurrying under them - one
## exhibit with one health bar (40), drawn as two MultiMeshes (the flying
## model with its wings out, the crawling one with its wing cases shut).
## It crawls after the guard (the navmesh, like any exhibit) and passes
## through him: while it is on him it bites, BITE_PER_SECOND in small
## ticks - nothing to dodge, a thing to kill or outrun (it is slower than
## his walk). Buckshot and fire tear it apart twice as fast. Dust 2.
## - The cloud flows: it trails behind the way it moves (the beetles at the
##   tail TRAIL seconds behind), skims low while it travels and whirls up
##   round its prey when it stops; a hit blows it apart for a moment and
##   knocks a few dead beetles out of it.
## - Asleep it is a heap of beetles on the floor (the Egyptian wing's
##   swarms in their cracks and by the sarcophagi), silent; woken, the
##   beetles stir and rise into the cloud over EMERGE_TIME and the hum
##   (the scarab_swarm loop) swells in.
## - It dies as a rain of dead beetles and broken wing cases
##   (scarab_debris) in a puff of chitin.
## The Colossus pours them out of his throne awake (summoned: relentless);
## the wing's own swarms are NightSpawner kind &"scarabs".

## The swarm's bite, a second of contact (before the difficulty).
const BITE_PER_SECOND := 6.0
## Ticks of the bite (s).
const BITE_TICK := 0.25
## How close the cloud's centre must be to bite (m, flat).
const CONTACT_RADIUS := 1.0
const COUNT := 30
const CRAWLERS := 12
## The beetles are drawn this much larger than the 6 cm model, to read in
## the dark from across a hall.
const BEETLE_SCALE := 2.4
## The cloud: radius and height range of the beetles' orbits (m).
const CLOUD_RADIUS := 1.0
const CLOUD_HEIGHT := Vector2(0.25, 1.5)
## Rising out of its heap (or pouring out of an opening): seconds the
## cloud takes to spread.
const EMERGE_TIME := 0.7
## Seconds the tail of the cloud lags behind its head on the move.
const TRAIL := 0.35
## The hum when awake (dB) and how fast it swells in (dB per second).
const HUM_DB := -4.0
const HUM_FADE := 60.0
const SHELL := Color(0.12, 0.32, 0.28)
const DEBRIS: Array[String] = ["shell_l", "shell_r", "body"]

## scarab_debris part / "dead" (a whole beetle) -> [Mesh, Array of materials].
static var _pieces: Dictionary = {}

var _cloud: MultiMeshInstance3D
var _crawl: MultiMeshInstance3D
## Per flying beetle: radius, angular speed (signed), phase, height.
var _orbits: Array[Vector4] = []
## Per crawler: radius, angular speed (signed), phase, wobble.
var _paths: Array[Vector4] = []
## Where each crawler lies in the sleeping heap (local).
var _heap: Array[Transform3D] = []
var _bite_timer: float = 0.0
var _hum: AudioStreamPlayer3D
## Seconds since it woke (the Colossus's swarms: since they poured out).
var _age: float = 0.0
var _time: float = 0.0
## 0 a heap on the floor .. 1 the full cloud.
var _rise: float = 0.0
## A hit blows the cloud apart (decays).
var _scatter: float = 0.0
## Smoothed velocity (world) the cloud trails along.
var _flow := Vector3.ZERO
var _last := Vector3.INF
## A hit's white flash (decays) and the shading last set (awake, flash).
var _flash: float = 0.0
var _shading := Vector2(-1.0, -1.0)
## Where the beetles are (local; the MultiMeshes' buffers are not read back).
var _beetles := PackedVector3Array()
var _crawlers := PackedVector3Array()


func _configure() -> void:
	max_health = 40.0
	move_speed = 3.4
	turn_speed = 10.0
	attack_damage = BITE_PER_SECOND
	attack_reach = CONTACT_RADIUS
	eye_height = 0.8
	marker_height = 1.8
	material_kind = ExhibitMaterial.Kind.TAXIDERMY
	dust_value = 2
	notice_sound = &""
	knockback_resist = 0.5
	brain.reaction_time = 0.15
	# it never winds up a blow: it bites while it is on him
	brain.attack_range = 0.0


func _ready() -> void:
	super()
	if brain.state != EnemyBrain.State.DORMANT:
		_rise = 0.0   # poured out awake: it spreads from where it came out
		_start_hum()


func _build_body() -> void:
	add_collider(0.45, 0.9)
	# nothing bumps into a cloud (it flows through the guard and the others)
	collision_layer = 0
	collision_mask = Layers.WORLD | Layers.ENEMY_BLOCK
	add_hurtbox(sphere_shape(0.95), Vector3(0.0, 0.85, 0.0))
	_build_cloud()
	_build_crawlers()
	_hum = AudioStreamPlayer3D.new()
	_hum.name = "Hum"
	_hum.stream = Sfx.stream_of(&"scarab_swarm")
	_hum.bus = Sfx.BUS
	_hum.unit_size = 4.0
	_hum.max_distance = 30.0
	_hum.volume_db = -60.0
	add_child(_hum)


## Dawn: the cloud hangs still, grey, silent.
func freeze() -> void:
	super()
	if _hum != null:
		_hum.stop()


## It takes buckshot and fire double.
func take_damage(info: DamageInfo) -> void:
	if info != null and (info.kind == DamageInfo.Kind.FIRE or info.weapon == &"shotgun"):
		info.amount *= 2.0
	super(info)


## 0 heap .. 1 cloud (tests, the rig of nobody).
func risen() -> float:
	return _rise


## Where flying beetle [param index] is now (local to the swarm).
func beetle(index: int) -> Vector3:
	return _beetles[index]


## Where crawler [param index] is now (local).
func crawler(index: int) -> Vector3:
	return _crawlers[index]


func _physics_process(delta: float) -> void:
	super(delta)
	if brain.state == EnemyBrain.State.DESTROYED or is_frozen():
		return
	if brain.state != EnemyBrain.State.DORMANT:
		_age += delta
	_bite(delta)


func _process(delta: float) -> void:
	if _cloud == null or is_frozen() or brain.state == EnemyBrain.State.DESTROYED:
		return
	_time += delta
	var awake := brain.state != EnemyBrain.State.DORMANT
	_rise = move_toward(_rise, 1.0 if awake else 0.0, delta / EMERGE_TIME)
	_scatter = maxf(_scatter - delta * 2.5, 0.0)
	var at := global_position
	if _last != Vector3.INF and delta > 0.0:
		var speed := ((at - _last) / delta).limit_length(10.0)
		_flow = _flow.lerp(Vector3(speed.x, 0.0, speed.z), 1.0 - exp(-6.0 * delta))
	_last = at
	_flash = maxf(_flash - delta / 0.12, 0.0)
	var shading := Vector2(_rise, _flash)
	if not shading.is_equal_approx(_shading):
		_shading = shading
		for view: MultiMeshInstance3D in [_cloud, _crawl]:
			view.set_instance_shader_parameter(&"awake", shading.x)
			view.set_instance_shader_parameter(&"flash", shading.y)
	_animate_cloud()
	_animate_crawlers()
	if _hum != null and _hum.playing:
		_hum.volume_db = move_toward(_hum.volume_db, HUM_DB, HUM_FADE * delta)


func _on_state_changed(from: EnemyBrain.State, to: EnemyBrain.State) -> void:
	super(from, to)
	if from == EnemyBrain.State.DORMANT and to != EnemyBrain.State.DESTROYED:
		_age = 0.0
		_start_hum()
	elif to == EnemyBrain.State.DORMANT and _hum != null:
		_hum.stop()


## A hit blows the cloud apart for a moment and knocks dead beetles out.
func _on_damaged(info: DamageInfo) -> void:
	if info.periodic:
		return
	_scatter = minf(_scatter + info.amount / 20.0, 1.0)
	_flash = 1.0
	for i in mini(int(info.amount / 6.0), 3):
		var fling := Vector3(randf_range(-1.5, 1.5), randf_range(0.5, 2.0), randf_range(-1.5, 1.5)) + info.direction * 1.5
		_fly("dead", info.position + Vector3(randf_range(-0.2, 0.2), randf_range(-0.2, 0.2), randf_range(-0.2, 0.2)), fling)


func _bite(delta: float) -> void:
	if not _target_alive() or Haven.shelters(target.global_position) or brain.state == EnemyBrain.State.DORMANT:
		_bite_timer = 0.0
		return
	var off := target.global_position - global_position
	if Vector2(off.x, off.z).length() > CONTACT_RADIUS or absf(off.y) > 1.6:
		_bite_timer = 0.0
		return
	_bite_timer += delta
	if _bite_timer < BITE_TICK:
		return
	_bite_timer -= BITE_TICK
	if not target.has_method(&"take_damage"):
		return
	var info := DamageInfo.make(attack_damage * BITE_TICK, DamageInfo.Kind.BLUNT, self)
	info.direction = Vector3(off.x, 0.0, off.z).normalized() if Vector2(off.x, off.z).length() > 0.05 else Vector3.FORWARD
	info.position = target.global_position + Vector3.UP
	target.take_damage(info)


## A rain of dead beetles and broken wing cases in a puff of chitin.
func _destroy(info: DamageInfo, finisher: bool, _overkill: float) -> void:
	brain.destroy()
	var center := global_position + Vector3.UP * 0.8
	var push := Vector3(info.direction.x, 0.0, info.direction.z) * 1.5 if info != null else Vector3.ZERO
	for i in 14:
		var spot := center + Vector3(randf_range(-0.8, 0.8), randf_range(-0.4, 0.5), randf_range(-0.8, 0.8))
		var fling := push + Vector3(randf_range(-1.5, 1.5), randf_range(0.0, 2.0), randf_range(-1.5, 1.5))
		_fly("dead" if i % 2 == 0 else DEBRIS[i % DEBRIS.size()], spot, fling)
	Fx.puff(center, SHELL.lightened(0.15), 26, 1.0)
	Fx.impact(center, Vector3.UP, ExhibitMaterial.Kind.TAXIDERMY, 2.0)
	Sfx.play_at(&"shard_break", center, -4.0)
	if _hum != null:
		_hum.stop()
	Events.hit_landed.emit(self, info, true)
	Events.enemy_destroyed.emit(self, info, finisher)
	queue_free()


func _start_hum() -> void:
	if _hum == null or _hum.stream == null or _hum.playing or not is_inside_tree():
		return
	_hum.volume_db = -30.0
	_hum.play()


# --- the cloud ------------------------------------------------------------------

func _build_cloud() -> void:
	_cloud = _multimesh("Cloud", &"scarab_flying", COUNT)
	_beetles.resize(COUNT)
	for i in COUNT:
		var spin := randf_range(2.2, 4.6) * (1.0 if i % 2 == 0 else -1.0)
		_orbits.append(Vector4(randf_range(0.25, CLOUD_RADIUS), spin, randf() * TAU, randf_range(CLOUD_HEIGHT.x, CLOUD_HEIGHT.y)))
	_animate_cloud()


func _build_crawlers() -> void:
	_crawl = _multimesh("Crawlers", &"scarab", CRAWLERS)
	_crawlers.resize(CRAWLERS)
	for i in CRAWLERS:
		var spin := randf_range(0.8, 2.0) * (1.0 if i % 3 != 0 else -1.0)
		_paths.append(Vector4(randf_range(0.25, 0.9), spin, randf() * TAU, randf_range(4.0, 9.0)))
		# the heap: a loose pile, some on top of others, any which way
		var spot := Vector2.from_angle(randf() * TAU) * randf_range(0.0, 0.35)
		var turn := Basis(Vector3.UP, randf() * TAU) * Basis(Vector3.RIGHT, randf_range(-0.3, 0.3))
		var lift := 0.015 + (0.03 if spot.length() < 0.15 and i % 2 == 0 else 0.0)
		_heap.append(Transform3D(turn, Vector3(spot.x, lift, spot.y)))
	_animate_crawlers()


## A MultiMesh of [param count] beetles of model [param id] under the
## visual (a box of the shell's colour without the model).
func _multimesh(node_name: String, id: StringName, count: int) -> MultiMeshInstance3D:
	var mesh: Mesh = null
	var material: Material = null
	var model := ArtLibrary.exhibit(id) if ArtLibrary.has_model(id) else null
	if model != null:
		var view := model.find_child(String(id), true, false) as MeshInstance3D
		if view != null:
			mesh = view.mesh
			material = view.get_surface_override_material(0)
		model.free()
	if mesh == null:
		var box := BoxMesh.new()
		box.size = Vector3(0.06, 0.02, 0.07)
		mesh = box
		var plain := StandardMaterial3D.new()
		plain.albedo_color = SHELL
		plain.metallic = 0.6
		material = plain
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = count
	var view_node := MultiMeshInstance3D.new()
	view_node.name = node_name
	view_node.multimesh = multimesh
	if material != null:
		view_node.material_override = material
	view_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visual.add_child(view_node)
	return view_node


## The flying beetles: orbits round the swarm's middle, spreading as it
## rises, trailing behind the way it moves (lower, a stream over the
## floor), blown out by hits.
func _animate_cloud() -> void:
	_cloud.visible = _rise > 0.01
	if not _cloud.visible:
		_beetles.fill(Vector3.ZERO)
		return
	var t := _time
	var spread := _rise
	var flow := global_basis.orthonormalized().inverse() * _flow
	var moving := clampf(flow.length() / 3.0, 0.0, 1.0)
	var multimesh := _cloud.multimesh
	for i in COUNT:
		var orbit := _orbits[i]
		var angle := orbit.z + orbit.y * t
		var radius := orbit.x * (0.3 + 0.7 * spread) * (1.0 + 0.15 * sin(t * 3.1 + i)) * (1.0 + 1.2 * _scatter)
		var high := lerpf(orbit.w, 0.3 + 0.35 * orbit.w, moving)
		var height := lerpf(0.05, high, spread) + 0.12 * sin(t * 5.3 + i * 1.7)
		var trail := -flow * TRAIL * (float(i) / COUNT)
		var at := Vector3(cos(angle) * radius, height, sin(angle) * radius) + trail
		# each beetle flies along its orbit (and the stream), wings a blur
		var heading := Vector3(-sin(angle), 0.0, cos(angle)) * signf(orbit.y) + flow * 0.4
		if heading.length_squared() < 0.0001:
			heading = Vector3.FORWARD
		var flutter := Basis.from_scale(Vector3(BEETLE_SCALE * (0.85 + 0.15 * absf(sin(t * 38.0 + i))), BEETLE_SCALE, BEETLE_SCALE))
		multimesh.set_instance_transform(i, Transform3D(Basis.looking_at(heading, Vector3.UP) * flutter, at))
		_beetles[i] = at


## The crawlers: a still heap while it sleeps (a twitch as it wakes), then
## scurrying round under the cloud in jerky arcs, trailing like it.
func _animate_crawlers() -> void:
	var multimesh := _crawl.multimesh
	var flow := global_basis.orthonormalized().inverse() * _flow
	for i in CRAWLERS:
		var rest := _heap[i]
		if _rise <= 0.0:
			multimesh.set_instance_transform(i, Transform3D(rest.basis.scaled_local(Vector3.ONE * BEETLE_SCALE), rest.origin))
			_crawlers[i] = rest.origin
			continue
		var path := _paths[i]
		var angle := path.z + path.y * _time + 0.25 * sin(_time * path.w + i)
		var radius := path.x * (1.0 + 0.6 * _scatter)
		var run := Vector3(cos(angle) * radius, 0.015, sin(angle) * radius) - flow * TRAIL * 0.6 * (float(i) / CRAWLERS)
		var at := rest.origin.lerp(run, _rise)
		var heading := Vector3(-sin(angle), 0.0, cos(angle)) * signf(path.y) + flow * 0.5
		var turn := Basis.looking_at(heading if heading.length_squared() > 0.0001 else Vector3.FORWARD, Vector3.UP)
		var basis := rest.basis.slerp(turn, _rise) if _rise < 1.0 else turn
		multimesh.set_instance_transform(i, Transform3D(basis.scaled_local(Vector3.ONE * BEETLE_SCALE), at))
		_crawlers[i] = at


## One piece of debris: a dead beetle ("dead") or a scarab_debris part,
## at the beetles' size.
func _fly(piece_name: String, at: Vector3, velocity: Vector3) -> void:
	var entry := _piece(piece_name)
	if entry.is_empty():
		Fx.chunk(at, SHELL.lightened(randf() * 0.3), randf_range(0.05, 0.1), velocity)
		return
	var materials: Array[Material] = []
	materials.assign(entry[1])
	var shard := MeshShards.whole(entry[0])
	var turn := Basis.from_euler(Vector3(randf() * TAU, randf() * TAU, randf() * TAU)).scaled(Vector3.ONE * BEETLE_SCALE)
	Fx.piece(shard, MeshShards.materials_for(shard, materials), Transform3D(turn, at - turn * shard.center), velocity, 12.0)


## [Mesh, materials] of a debris piece ([] without the models).
static func _piece(piece_name: String) -> Array:
	if _pieces.is_empty():
		for id: StringName in [&"scarab_debris", &"scarab"]:
			var source := ArtLibrary.exhibit(id) if ArtLibrary.has_model(id) else null
			if source == null:
				continue
			for child in source.find_children("*", "MeshInstance3D", true, false):
				var view := child as MeshInstance3D
				if view.mesh == null:
					continue
				var materials: Array = []
				for i in view.mesh.get_surface_count():
					materials.append(ArtLibrary.debris_material(view.get_active_material(i)))
				_pieces["dead" if id == &"scarab" else String(view.name)] = [view.mesh, materials]
			source.free()
	return _pieces.get(piece_name, [])
