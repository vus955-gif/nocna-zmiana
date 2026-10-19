class_name WeaponHolder
extends Node3D
## The guard's arsenal: switching, firing (hitscan rays or a melee sweep),
## reloading, ammo pickups and greybox viewmodels. Lives under the camera;
## its -Z axis is the aim direction. Pellets that hit the same target are
## merged into one DamageInfo so overkill (and gibbing) is judged fairly.
## Upgrades reach every owned weapon through apply_upgrades(); an upgraded
## taser arc jumps to a second exhibit, and holding reload switches an
## upgraded shotgun between buckshot and slugs. Inside a haven the weapon
## is lowered: no shots, no punches (switching and reloading still work).
## The gatling spins up while fire is held (WeaponState.pull_trigger()),
## slows the guard while it has rounds to fire (move_factor()), shakes the
## camera only up to a cap and dresses only every other round with sparks,
## holes and a muzzle light (WeaponData.effects_every); the flare gun
## fires a Flare instead of rays. A view with update_view(),
## on_fired() and on_hidden() (GatlingView, FlareView) is driven from here.
## Floor I: the hunting rifle's round pierces up to three targets
## (Hitscan.pierce), the harpoon gun fires a Harpoon on a line (its line
## runs from line_anchor()), the hwacha's shot is a volley of fire-arrows
## (HwachaRocket) launched volley_interval apart in a fan. A punch first
## looks along the crosshair: the zone it points at takes the blow (a
## chain next to an exhibit), else the nearest one in the sweep. Every view
## shows the bought upgrades (WeaponLook through the view's apply_look());
## a changed look plays a short inspection the next time it is drawn.
## How a shot feels comes from the weapon's FeelProfile (plan
## 2026-10-19-gun-feel): the model's kick (a Recoil spring per weapon),
## the camera's kick and shake (ShakeCamera), the muzzle's light, the
## tracer and the shot's sound; a pellet's share of the profile's hit
## weight rides on its DamageInfo (impact). While the guard sprints the
## weapon is carried low and tilted; a shot brings it straight up.

signal weapon_changed(state: WeaponState)
signal load_switched(state: WeaponState)

const SLOT_ORDER: Array[StringName] = [&"taser", &"pistol", &"shotgun", &"gatling", &"flare",
		&"rifle_hunt", &"harpoon", &"hwacha"]
const FISTS: WeaponData = preload("res://src/weapons/data/fists.tres")
const REST := Vector3(0.17, -0.16, -0.55)
## Weapons turn slightly toward the crosshair so their side is visible.
const AIM_YAW := 0.1
const FIST_REST := Vector3(-0.2, -0.32, -0.3)
const FIST_HIT := Vector3(-0.05, -0.14, -0.62)
## A point-blank hit (the ray starts inside the target) shows this far past
## the muzzle.
const POINT_BLANK_OFFSET := 0.1
## Holding reload this long switches loads instead of reloading.
const ALT_HOLD := 0.35
## How far the weapon sinks (m) and tips down (rad per m) while the guard
## is in a haven: lowered, still in sight.
const HAVEN_DROP := 0.1
const HAVEN_TILT := 3.0
## Dazed (a stagger): the weapon dips this far (m) and tilts down.
const DAZE_DROP := 0.14
## Fatigue (Fatigue, plan 2026-10-10-kawiarnia-zmeczenie): tired hands
## drift this far (m) at the worst of the night even at rest, and shake
## this far after the witching special; the walking bob grows with
## Fatigue.sway_factor(). The shaking is noise sampled JITTER_RATE units a
## second at JITTER_FREQUENCY cycles a unit: about 10 tremors a second (a
## default noise would only wander about once a second).
const FATIGUE_DRIFT := 0.004
const JITTER_SHAKE := 0.006
const JITTER_RATE := 40.0
const JITTER_FREQUENCY := 0.25
## The model's kick channels (Recoil): back toward the eye, up, sideways
## (m); muzzle climb, yaw, roll (degrees).
const KICK_BACK := 0
const KICK_RISE := 1
const KICK_SIDE := 2
const KICK_PITCH := 3
const KICK_YAW := 4
const KICK_ROLL := 5
## Sprinting: the weapon is carried this far lower (m), muzzle down and
## rolled in (rad); it comes up again this long (s) after a shot.
const SPRINT_DROP := 0.035
const SPRINT_TILT := 0.2
const SPRINT_ROLL := 0.14
const SPRINT_SHOT_HOLD := 0.35

## The node credited with hits (the player). It is never hit itself.
var user: Node3D = null
var enabled: bool = true
var owned: Array[WeaponState] = []
var current: int = -1
var fists: WeaponState
## Upgrade levels (id -> level) applied to every weapon given.
var upgrade_levels: Dictionary = {}

var _reload_held: float = -1.0

var _views: Dictionary = {}
## Weapon id -> its MuzzleFx (flash, smoke, casings).
var _muzzles: Dictionary = {}
var _fist_view: Node3D
## The model's kick (KICK_* channels), tuned to the weapon that fired last.
var _recoil := Recoil.new(6)
## 0..1: how far the weapon is lowered for a sprint; seconds since a shot.
var _sprint_pose: float = 0.0
var _since_shot: float = INF
## Model kicks given so far (tests: every arrow of a volley kicks).
var kicks_given: int = 0
var _switch_drop: float = 0.0
var _reload_drop: float = 0.0
var _haven_drop: float = 0.0
## Seconds the guard is still dazed: no shot, no punch (Player.stagger).
var _daze_left: float = 0.0
var _daze_drop: float = 0.0
var _bob_time: float = 0.0
var _sway_time: float = 0.0
var _shake_noise := _make_shake_noise()
var _empty_click_cd: float = 0.0
## Rounds fired, for tracers on every n-th round.
var _rounds: int = 0
var _punch_tween: Tween = null
var _rng := RandomNumberGenerator.new()
## The volley in flight: its numbers, rockets still to launch, the next
## one's index and the time to it.
var _volley_data: WeaponData = null
var _volley_left: int = 0
var _volley_index: int = 0
var _volley_timer: float = 0.0


func _ready() -> void:
	_rng.randomize()
	fists = WeaponState.new(FISTS)
	fists.apply_upgrades(upgrade_levels)
	_fist_view = Viewmodels.build(&"fist")
	_fist_view.position = FIST_REST
	_fist_view.visible = false
	add_child(_fist_view)
	_apply_look(_fist_view, false)


## Adds a weapon (no duplicates) keeping slot order; selects it if it is the
## first one. Returns its state.
func give(data: WeaponData) -> WeaponState:
	for state in owned:
		if state.data.id == data.id:
			return state
	var previous := current_state()
	var added := WeaponState.new(data)
	added.apply_upgrades(upgrade_levels)
	added.magazine = added.data.magazine_size
	owned.append(added)
	owned.sort_custom(func(a: WeaponState, b: WeaponState) -> bool:
		return SLOT_ORDER.find(a.data.id) < SLOT_ORDER.find(b.data.id))
	var view := Viewmodels.build(data.id)
	view.position = REST
	view.visible = false
	_muzzles[data.id] = MuzzleFx.attach(self, view, FeelProfile.of(data.id))
	add_child(view)
	_views[data.id] = view
	_apply_look(view, false)
	if previous == null:
		select(owned.find(added))
	else:
		current = owned.find(previous)
	return added


func has_weapon(id: StringName) -> bool:
	return _index_of(id) >= 0


func state_of(id: StringName) -> WeaponState:
	var index := _index_of(id)
	return owned[index] if index >= 0 else null


## New upgrade levels for the fists and every owned weapon (and any given
## later).
func apply_upgrades(levels: Dictionary) -> void:
	upgrade_levels = levels.duplicate()
	if fists != null:
		fists.apply_upgrades(upgrade_levels)
	for state in owned:
		state.apply_upgrades(upgrade_levels)
	if _fist_view != null:
		_apply_look(_fist_view, true)
	for id in _views:
		_apply_look(_views[id], true)


## The first-person view of weapon [param id] (&"fist" or &"fists" for the
## fists), or null.
func view_of(id: StringName) -> Node3D:
	if id == &"fist" or id == &"fists":
		return _fist_view
	return _views.get(id) as Node3D


## The muzzle effects of weapon [param id] (null when it is not owned).
func muzzle_of(id: StringName) -> MuzzleFx:
	return _muzzles.get(id) as MuzzleFx


## Weapon [param id]'s action throws [param count] casings out (a rifle's
## bolt run back, a shotgun broken open: its view calls this).
func eject(id: StringName, count: int) -> void:
	var fx := muzzle_of(id)
	if fx != null:
		fx.eject(count)


## Where the harpoon's line leaves the gun (world space): the harpoon gun's
## LineAnchor (or muzzle) while it is in hand, else just below the eye. The
## gun is drawn with its own narrower field of view, so the point is moved
## to where the world camera shows the gun's muzzle on screen.
func line_anchor() -> Vector3:
	var view := _views.get(&"harpoon") as Node3D
	if view != null and view.visible:
		var anchor := view.find_child("LineAnchor", true, false) as Node3D
		if anchor == null:
			anchor = view.get_node_or_null(^"Muzzle") as Node3D
		if anchor != null:
			return on_screen_like_the_view(anchor.global_position)
	return global_transform * Vector3(0.12, -0.15, -0.5)


## [param point] of a first-person view (drawn with
## ArtLibrary.VIEWMODEL_FOV) moved so the world camera shows it at the same
## spot on screen.
func on_screen_like_the_view(point: Vector3) -> Vector3:
	var camera := get_viewport().get_camera_3d() if is_inside_tree() else null
	if camera == null or camera.projection != Camera3D.PROJECTION_PERSPECTIVE:
		return point
	var eye := camera.global_transform
	var local := eye.affine_inverse() * point
	var k := tan(deg_to_rad(camera.fov) * 0.5) / tan(deg_to_rad(ArtLibrary.VIEWMODEL_FOV) * 0.5)
	return eye * Vector3(local.x * k, local.y * k, local.z)


## Rockets of the running volley still to launch.
func volley_left() -> int:
	return _volley_left


## Shows the bought upgrades on [param view] (a model rig; greybox views
## have no upgrade parts). [param announce]: a changed look plays the
## inspection the next time the weapon is drawn.
func _apply_look(view: Node3D, announce: bool) -> void:
	if view != null and view.has_method(&"apply_look"):
		view.call(&"apply_look", upgrade_levels, announce)


## Switches the current weapon's load (buckshot <-> slugs). False when it
## has only one.
func try_switch_load() -> bool:
	var state := current_state()
	if not enabled or state == null or not state.toggle_alt():
		return false
	Sfx.play(&"reload", -4.0)
	load_switched.emit(state)
	return true


func current_state() -> WeaponState:
	if current < 0 or current >= owned.size():
		return null
	return owned[current]


func select(index: int) -> void:
	if index < 0 or index >= owned.size() or index == current:
		return
	var old := current_state()
	if old != null:
		old.cancel_reload()
		var old_view := _views[old.data.id] as Node3D
		old_view.visible = false
		if old_view.has_method(&"on_hidden"):
			old_view.call(&"on_hidden")
	current = index
	_reload_held = -1.0
	var state := owned[index]
	var view := _views[state.data.id] as Node3D
	view.visible = true
	if view.has_method(&"on_drawn"):
		view.call(&"on_drawn")
	_switch_drop = 0.25
	weapon_changed.emit(state)


func select_id(id: StringName) -> void:
	select(_index_of(id))


func cycle(step: int) -> void:
	if owned.size() > 1:
		select(wrapi(current + step, 0, owned.size()))


func try_fire() -> bool:
	var state := current_state()
	if not enabled or state == null:
		return false
	if state.uses_spin():
		state.pull_trigger()
	if not state.can_fire():
		if not state.has_ammo_for_shot() and not state.is_reloading() and not _start_reload(state):
			_click_empty()
		return false
	state.fire()
	if state.data.belt_feed and state.is_reloading():
		Sfx.play(&"reload", -4.0)   # the box ran dry: the next belt runs in
	_attack(state)
	var view := _views.get(state.data.id) as Node3D
	if view != null and view.has_method(&"on_fired"):
		view.call(&"on_fired", state)
	_kick_view(FeelProfile.of(state.data.id))
	if state.data.ammo_mode == WeaponData.AmmoMode.MAGAZINE and state.magazine == 0:
		_start_reload(state)
	return true


func try_punch() -> bool:
	if not enabled or not fists.can_fire():
		return false
	fists.fire()
	_attack(fists)
	_animate_punch()
	return true


func try_reload() -> bool:
	var state := current_state()
	return enabled and state != null and _start_reload(state)


## Walking speed factor from the weapon in hand: a gatling with its
## trigger held slows the guard while it has rounds left to fire (an empty
## one is just carried; 1 = no penalty).
func move_factor() -> float:
	var state := current_state()
	if not enabled or state == null or not state.trigger_held() or not state.has_ammo_left():
		return 1.0
	return state.data.firing_move_factor


## False while the weapon in hand slows the guard (no sprinting then).
func allows_sprint() -> bool:
	return move_factor() >= 1.0


## Adds reserve ammo to the owned weapon using [param ammo_type].
## Returns how much was taken.
func add_ammo(ammo_type: StringName, amount: int) -> int:
	for state in owned:
		if state.data.ammo_type == ammo_type:
			return state.add_ammo(amount)
	return 0


func _physics_process(delta: float) -> void:
	fists.tick(delta)
	for state in owned:
		state.tick(delta)
	_tick_volley(delta)
	_empty_click_cd = maxf(_empty_click_cd - delta, 0.0)
	_daze_left = maxf(_daze_left - delta, 0.0)
	if not _input_allowed():
		return
	if not sheltered() and _daze_left <= 0.0:
		# just_pressed also catches a click released again within one hitchy frame
		if Input.is_action_pressed(&"fire") or Input.is_action_just_pressed(&"fire"):
			try_fire()
		if Input.is_action_just_pressed(&"punch"):
			try_punch()
	reload_key(Input.is_action_pressed(&"reload"), Input.is_action_just_pressed(&"reload"), delta)


## Dazes the guard for [param seconds] (a stagger): he neither fires nor
## punches, and the weapon in hand dips. 0 ends a daze.
func daze(seconds: float) -> void:
	_daze_left = maxf(_daze_left, seconds) if seconds > 0.0 else 0.0


## True while a daze holds his hands.
func dazed() -> bool:
	return _daze_left > 0.0


## True while the guard stands in a haven: weapons are lowered there (the
## safe room is no firing position; exhibits cannot answer from outside).
func sheltered() -> bool:
	return user != null and Haven.shelters(user.global_position)


## The reload key, once per physics frame. Tap = reload. On a weapon with
## two loads the tap counts on release, and holding it for ALT_HOLD switches
## the load instead.
func reload_key(pressed: bool, just_pressed: bool, delta: float) -> void:
	var state := current_state()
	if just_pressed:
		if state != null and state.has_alt():
			_reload_held = 0.0
		else:
			try_reload()
		return
	if _reload_held < 0.0:
		return
	if state == null or not state.has_alt():
		_reload_held = -1.0
	elif pressed:
		_reload_held += delta
		if _reload_held >= ALT_HOLD:
			_reload_held = -1.0
			try_switch_load()
	else:
		_reload_held = -1.0
		try_reload()


func _unhandled_input(event: InputEvent) -> void:
	if not _input_allowed():
		return
	for slot in SLOT_ORDER.size():
		if event.is_action_pressed(StringName("weapon_%d" % (slot + 1))):
			select_id(SLOT_ORDER[slot])
			return
	if event.is_action_pressed(&"weapon_next"):
		cycle(1)
	elif event.is_action_pressed(&"weapon_prev"):
		cycle(-1)


func _process(delta: float) -> void:
	_recoil.step(delta)
	_since_shot += delta
	_switch_drop = move_toward(_switch_drop, 0.0, 1.5 * delta)
	var state := current_state()
	if state == null:
		return
	_reload_drop = lerpf(_reload_drop, 0.12 if state.is_reloading() else 0.0, 1.0 - exp(-12.0 * delta))
	_haven_drop = lerpf(_haven_drop, HAVEN_DROP if sheltered() else 0.0, 1.0 - exp(-8.0 * delta))
	_daze_drop = lerpf(_daze_drop, DAZE_DROP if _daze_left > 0.0 else 0.0, 1.0 - exp(-(20.0 if _daze_left > 0.0 else 6.0) * delta))
	var speed := 0.0
	var body := user as CharacterBody3D
	if body != null:
		speed = Vector2(body.velocity.x, body.velocity.z).length()
	_bob_time += delta * speed * 1.6
	_sway_time += delta
	var sway := minf(speed / 5.5, 1.5)
	# tired hands: a bigger bob, a slow drift even at rest; shaking after the special
	var tired := 0.0
	var shakes := 0.0
	var sprinting := false
	var landing := 0.0
	var guard := user as Player
	if guard != null:
		tired = guard.fatigue.effect()
		shakes = guard.fatigue.jitter()
		sway *= guard.fatigue.sway_factor()
		sprinting = guard.sprinting
		landing = guard.landing_offset() * 0.6   # the weapon dips a little more than the eyes
	# a sprint carries it low; a shot (or the end of the run) brings it up
	var lowered := sprinting and _since_shot > SPRINT_SHOT_HOLD
	_sprint_pose = lerpf(_sprint_pose, 1.0 if lowered else 0.0, 1.0 - exp(-(7.0 if lowered else 16.0) * delta))
	var bob := Vector3(sin(_bob_time) * 0.012, -absf(cos(_bob_time)) * 0.012, 0.0) * sway
	var drift := Vector3(sin(_sway_time * 0.9), cos(_sway_time * 0.7) * 0.6, 0.0) * (FATIGUE_DRIFT * tired)
	if shakes > 0.0:
		var t := _sway_time * JITTER_RATE
		drift += Vector3(_shake_noise.get_noise_1d(t), _shake_noise.get_noise_1d(t + 100.0), 0.0) * (JITTER_SHAKE * shakes)
	var view: Node3D = _views[state.data.id]
	var kick := Vector3(_recoil.value(KICK_SIDE), _recoil.value(KICK_RISE), _recoil.value(KICK_BACK))
	var drops := _switch_drop + _reload_drop + _haven_drop + _daze_drop + SPRINT_DROP * _sprint_pose
	view.position = REST + bob + drift + kick + Vector3(SPRINT_DROP * 0.4 * _sprint_pose, landing - drops, 0.0)
	view.rotation = Vector3(deg_to_rad(_recoil.value(KICK_PITCH)) - (_haven_drop + _daze_drop) * HAVEN_TILT - SPRINT_TILT * _sprint_pose,
			AIM_YAW + deg_to_rad(_recoil.value(KICK_YAW)),
			_daze_drop * 1.5 + deg_to_rad(_recoil.value(KICK_ROLL)) + SPRINT_ROLL * _sprint_pose)
	if view.has_method(&"update_view"):
		view.call(&"update_view", state, delta)


## The noise of the shaking hands: fast (JITTER_FREQUENCY), seeded the same every run.
static func _make_shake_noise() -> FastNoiseLite:
	var noise := FastNoiseLite.new()
	noise.frequency = JITTER_FREQUENCY
	return noise


func _input_allowed() -> bool:
	return enabled and GameInput.gameplay_input()


func _index_of(id: StringName) -> int:
	for i in owned.size():
		if owned[i].data.id == id:
			return i
	return -1


func _start_reload(state: WeaponState) -> bool:
	if not state.start_reload():
		return false
	Sfx.play(&"reload", -4.0)
	return true


func _click_empty() -> void:
	if _empty_click_cd <= 0.0:
		_empty_click_cd = 0.35
		Sfx.play(&"empty", -6.0)


func _attack(state: WeaponState) -> void:
	var data := state.shot_data()
	var origin := global_position
	var forward := -global_transform.basis.z
	var space := get_world_3d().direct_space_state
	var hits: Dictionary = {}
	var first_hurtbox: Hurtbox = null
	if data.projectile_speed > 0.0:
		if data.volley_count > 1:
			_start_volley(data)
		else:
			_launch(space, data, origin, forward)
	elif data.melee_radius > 0.0:
		# the zone under the crosshair takes the blow (a chain beside an
		# exhibit); else the nearest one in the sweep
		var aimed := Hitscan.ray(space, origin, origin + forward * data.max_range)
		var aimed_zone: Hurtbox = aimed.get("hurtbox") if not aimed.is_empty() else null
		if aimed_zone != null and aimed_zone.receiver != null and aimed_zone.receiver != user:
			_accumulate(hits, aimed_zone, data, aimed["position"], -forward, forward)
		else:
			var center := origin + forward * (data.max_range - data.melee_radius)
			for hurtbox in Hitscan.sphere_hurtboxes(space, center, data.melee_radius):
				if hurtbox.receiver != null and hurtbox.receiver != user and _unobstructed(space, origin, hurtbox):
					_accumulate(hits, hurtbox, data, hurtbox.global_position, -forward, forward)
					break
		if not hits.is_empty():
			Sfx.play(&"punch_hit")
	else:
		var muzzle := _muzzle_position(data.id, origin)
		var spread := state.spread_for(data)
		_rounds += 1
		var traced := data.tracer_every <= 1 or _rounds % data.tracer_every == 0
		var dressed := data.effects_every <= 1 or _rounds % data.effects_every == 0
		for i in data.pellets:
			var dir := Hitscan.spread_direction(forward, spread, _rng)
			var end := origin + dir * data.max_range
			var ray_hits: Array[Dictionary] = []
			if data.pierce_targets > 1:
				ray_hits = Hitscan.pierce(space, origin, end, data.pierce_targets)
			else:
				var single := Hitscan.ray(space, origin, end)
				if not single.is_empty():
					ray_hits.append(single)
			if ray_hits.is_empty():
				if traced:
					_trail(data, muzzle, end)
				continue
			var trail_to := Vector3.INF
			for hit in ray_hits:
				var point: Vector3 = hit["position"]
				var normal: Vector3 = hit["normal"]
				var point_blank := normal.is_zero_approx()
				if point_blank:
					# The ray started inside the target: show the hit just past the
					# muzzle, facing the guard, and draw no trail back to the eye.
					point = muzzle + dir * POINT_BLANK_OFFSET
					normal = -dir
				else:
					trail_to = point
				var hurtbox: Hurtbox = hit["hurtbox"]
				if hurtbox != null:
					_accumulate(hits, hurtbox, data, point, normal, dir)
					if first_hurtbox == null and hits.has(hurtbox.receiver) and chain_target(hurtbox.receiver):
						first_hurtbox = hurtbox
				elif dressed:
					_mark_wall(data, hit, point, normal, point_blank)
			if traced and trail_to != Vector3.INF:
				_trail(data, muzzle, trail_to)
		if data.damage_kind == DamageInfo.Kind.BALLISTIC and dressed:
			var light := FeelProfile.of(data.id)
			Fx.flash(muzzle, light.light_color, light.light_energy, light.light_range, light.light_time)
		if dressed and muzzle_of(data.id) != null:
			muzzle_of(data.id).fire()
		if not dressed:
			for receiver in hits:
				(hits[receiver] as DamageInfo).effects = false   # its sparks: the next round
	if data.chain_range > 0.0 and first_hurtbox != null:
		_chain(space, hits, data, first_hurtbox)
	var landed := false
	for receiver in hits:
		var info: DamageInfo = hits[receiver]
		receiver.take_damage(info)
		landed = landed or (chain_target(receiver) and not info.blocked)
	var profile := FeelProfile.of(data.id)
	if data.sound != &"":
		Sfx.play(data.sound, profile.sound_db, profile.sound_jitter, profile.sound_pitch)
	_feel_shot(profile, landed)
	Events.weapon_fired.emit(data.id)


## Fires the weapon's projectile (a flare, a harpoon, a fire-arrow) from
## just in front of the eye toward whatever the crosshair is on (so it
## lands where the guard aims, arc aside); [param yaw] and [param pitch]
## (radians) turn the aim off the crosshair (a volley's fan).
func _launch(space: PhysicsDirectSpaceState3D, data: WeaponData, origin: Vector3, forward: Vector3,
		yaw: float = 0.0, pitch: float = 0.0) -> Node3D:
	var axes := global_transform.basis
	var aim_dir := forward
	if yaw != 0.0 or pitch != 0.0:
		aim_dir = (Basis(axes.y.normalized(), yaw) * Basis(axes.x.normalized(), pitch) * forward).normalized()
	var aim := origin + aim_dir * data.max_range
	var hit := Hitscan.ray(space, origin, aim)
	if not hit.is_empty() and origin.distance_to(hit["position"]) > 1.0:
		aim = hit["position"]
	var start := origin + forward * 0.35 + axes.x.normalized() * 0.08 - axes.y.normalized() * 0.06
	if not space.intersect_ray(PhysicsRayQueryParameters3D.create(origin, start, Layers.WORLD)).is_empty():
		start = origin + forward * 0.05   # pressed against a wall
	var direction := (aim - start).normalized() if aim.distance_to(start) > 1.0 else aim_dir
	var shot: Node3D
	match data.projectile:
		&"harpoon":
			shot = Harpoon.launch(start, direction * data.projectile_speed, data, user, self)
		&"rocket":
			shot = HwachaRocket.launch(start, direction * data.projectile_speed, data, user)
		_:
			shot = Flare.launch(start, direction * data.projectile_speed, data, user)
	var parent: Node = user.get_parent() if user != null and user.get_parent() != null else get_tree().current_scene
	parent.add_child(shot)
	var light := FeelProfile.of(data.id)
	Fx.flash(_muzzle_position(data.id, start), light.light_color, light.light_energy, light.light_range, light.light_time)
	if muzzle_of(data.id) != null:
		muzzle_of(data.id).fire()
	return shot


## A volley: the first fire-arrow leaves at once, the rest follow
## volley_interval apart (_physics_process), fanned across
## volley_spread_deg from left to right.
func _start_volley(data: WeaponData) -> void:
	_volley_data = data
	_volley_left = data.volley_count
	_volley_index = 0
	_volley_timer = 0.0
	_launch_volley_rocket()


func _launch_volley_rocket() -> void:
	if _volley_left <= 0 or _volley_data == null or not is_inside_tree():
		return
	var data := _volley_data
	var count := maxi(data.volley_count, 1)
	var t := float(_volley_index) / float(count - 1) if count > 1 else 0.5
	var yaw := deg_to_rad(lerpf(data.volley_spread_deg * 0.5, -data.volley_spread_deg * 0.5, t))
	var pitch := deg_to_rad(_rng.randf_range(-0.8, 0.8))
	_launch(get_world_3d().direct_space_state, data, global_position, -global_transform.basis.z, yaw, pitch)
	var view := _views.get(data.id) as Node3D
	if view != null and view.has_method(&"on_volley_rocket"):
		view.call(&"on_volley_rocket", _volley_index)
	if _volley_index > 0:
		# every arrow of the volley kicks a little: the chest ripples
		var profile := FeelProfile.of(data.id)
		Sfx.play(&"hwacha_fire", profile.sound_db - 4.0, profile.sound_jitter, profile.sound_pitch)
		_kick_view(profile)
		_feel_shot(profile, false)
	_volley_index += 1
	_volley_left -= 1
	_volley_timer = data.volley_interval


func _tick_volley(delta: float) -> void:
	if _volley_left <= 0:
		return
	if not enabled:
		_volley_left = 0   # the guard fell: the rest of the chest goes quiet
		return
	_volley_timer -= delta
	while _volley_left > 0 and _volley_timer <= 1e-4:
		var carry := _volley_timer
		_launch_volley_rocket()
		_volley_timer += carry


## The model's kick of one shot of a weapon with [param profile]: its
## spring tuned to the weapon, every channel jolted to its peak (yaw,
## roll and the sideways shove to a random side).
func _kick_view(profile: FeelProfile) -> void:
	_since_shot = 0.0
	kicks_given += 1
	_recoil.tune(profile.kick_frequency, profile.kick_damping)
	_recoil.kick(KICK_BACK, profile.kick_back)
	_recoil.kick(KICK_RISE, profile.kick_rise)
	_recoil.kick(KICK_SIDE, profile.kick_side * _random_side())
	_recoil.kick(KICK_PITCH, profile.kick_pitch)
	_recoil.kick(KICK_YAW, profile.kick_yaw * _random_side())
	_recoil.kick(KICK_ROLL, profile.kick_roll * _random_side())


## What the guard's view feels of one shot: the camera's kick and FOV
## punch, the shot's shake (only up to the weapon's cap: a run of shots
## rumbles at its level instead of piling up) and, when it landed on an
## exhibit ([param landed]), the blow's own shake. The camera is the one
## the holder rides on (the guard's), else the active one; without a
## ShakeCamera the shake goes out as a request.
func _feel_shot(profile: FeelProfile, landed: bool) -> void:
	var shake := profile.shake + (profile.hit_shake if landed else 0.0)
	var camera := get_parent() as ShakeCamera
	if camera == null and is_inside_tree():
		camera = get_viewport().get_camera_3d() as ShakeCamera
	if camera == null:
		if shake > 0.0:
			Events.shake_requested.emit(minf(shake, profile.shake_cap))
		return
	camera.add_trauma(shake, profile.shake_cap)
	camera.kick(profile.camera_pitch, profile.camera_yaw * _random_side(), profile.camera_frequency, profile.camera_damping)
	if profile.fov_punch > 0.0:
		camera.kick_fov(profile.fov_punch)


func _random_side() -> float:
	return _rng.randf_range(0.6, 1.0) * (1.0 if _rng.randf() < 0.5 else -1.0)


## The model's kick now: back, rise, side (m) and pitch, yaw, roll
## (degrees), for tests.
func view_kick() -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for channel in 6:
		out.append(_recoil.value(channel))
	return out


## The taser arc jumps from the first target (its hurtbox, not the hit
## point: a point-blank hit shows at the muzzle) to the nearest other
## exhibit within [member WeaponData.chain_range] that it can reach through
## the air.
func _chain(space: PhysicsDirectSpaceState3D, hits: Dictionary, data: WeaponData, origin: Hurtbox) -> void:
	var first: DamageInfo = hits[origin.receiver]
	var from := origin.global_position
	for hurtbox in Hitscan.sphere_hurtboxes(space, from, data.chain_range):
		var receiver := hurtbox.receiver
		if not chain_target(receiver) or receiver == user or hits.has(receiver) or not receiver.has_method(&"take_damage"):
			continue
		var to := hurtbox.global_position
		if from.distance_to(to) > data.chain_range:
			continue
		if not space.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, Layers.WORLD)).is_empty():
			continue
		Fx.arc(from, to)
		var direction := (to - from).normalized() if from.distance_to(to) > 0.01 else first.direction
		_accumulate(hits, hurtbox, data, to, -direction, direction)
		return


## What the taser arc may jump to: exhibits and the boss's hit zones, never
## a flying shot, a prop or the guard.
static func chain_target(receiver: Node) -> bool:
	return receiver != null and (receiver.is_in_group(&"enemies") or receiver is TRexZone)


## True when no level geometry stands between [param origin] and the
## hurtbox (a melee sweep must not reach through walls).
func _unobstructed(space: PhysicsDirectSpaceState3D, origin: Vector3, hurtbox: Hurtbox) -> bool:
	var query := PhysicsRayQueryParameters3D.create(origin, hurtbox.global_position, Layers.WORLD)
	return space.intersect_ray(query).is_empty()


func _accumulate(hits: Dictionary, hurtbox: Hurtbox, data: WeaponData, point: Vector3, normal: Vector3, dir: Vector3) -> void:
	var receiver := hurtbox.receiver
	if receiver == null or receiver == user or not receiver.has_method(&"take_damage"):
		return
	var info: DamageInfo = hits.get(receiver)
	if info == null:
		info = DamageInfo.make(0.0, data.damage_kind, user)
		info.position = point
		info.normal = normal
		info.direction = dir
		info.stun_time = data.stun_time
		info.can_finish = data.can_finish
		info.weapon = data.id
		info.origin = global_position
		info.lock_breaker = data.lock_breaker
		hits[receiver] = info
	info.amount += data.damage * (data.weak_point_multiplier if hurtbox.weak_point else 1.0)
	info.knockback += data.knockback
	# every pellet carries its share of the shot's weight
	info.impact = minf(info.impact + FeelProfile.of(data.id).hit_weight / maxi(data.pellets, 1), 1.0)
	info.weak_point = info.weak_point or hurtbox.weak_point


## A shot on the level: what it throws off that surface and the mark it
## leaves there (a bullet's hole, a taser's burn), as big as the weapon's
## profile says.
func _mark_wall(data: WeaponData, hit: Dictionary, point: Vector3, normal: Vector3, point_blank: bool) -> void:
	var profile := FeelProfile.of(data.id)
	var surface := Surface.of_hit(hit.get("collider"), point, normal, get_tree() if is_inside_tree() else null)
	Fx.surface_impact(point, normal, surface, 0.4 + 0.6 * profile.hit_weight / maxi(data.pellets, 1))
	if point_blank:
		return
	if data.damage_kind == DamageInfo.Kind.BALLISTIC:
		Fx.mark(point, normal, surface, profile.decal_size)
	elif data.damage_kind == DamageInfo.Kind.ELECTRIC:
		Fx.mark(point, normal, Fx.SCORCH, profile.decal_size)


func _trail(data: WeaponData, from: Vector3, to: Vector3) -> void:
	if data.damage_kind == DamageInfo.Kind.ELECTRIC:
		Fx.arc(from, to)
	else:
		var profile := FeelProfile.of(data.id)
		Fx.tracer(from, to, profile.tracer_color, profile.tracer_width, profile.tracer_time)


func _muzzle_position(id: StringName, fallback: Vector3) -> Vector3:
	var view: Node3D = _views.get(id)
	if view == null:
		return fallback
	var muzzle := view.get_node_or_null(^"Muzzle") as Node3D
	return muzzle.global_position if muzzle != null else fallback


func _animate_punch() -> void:
	if _punch_tween != null:
		_punch_tween.kill()   # an old punch must not hide this one halfway
	_fist_view.visible = true
	_fist_view.position = FIST_REST
	_punch_tween = create_tween()
	_punch_tween.tween_property(_fist_view, "position", FIST_HIT, 0.07)
	_punch_tween.tween_property(_fist_view, "position", FIST_REST, 0.16)
	_punch_tween.tween_callback(func() -> void: _fist_view.visible = false)
