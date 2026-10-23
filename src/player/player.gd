class_name Player
extends CharacterBody3D
## The night guard: calm walk, stamina-limited sprint and dash, jump with
## coyote time, mouse look, flashlight, health and the weapon holder.
## The head is a top-level node that follows the interpolated body, so
## mouse look stays instant while movement is smoothed by physics
## interpolation. Movement direction comes from the head's yaw. While a menu
## holds the input (GameInput.gameplay_input() is false) the guard neither
## moves, looks, uses things nor switches the flashlight.
## The view moves a little with him (plan 2026-10-19-gun-feel): a gentle
## bob of the eyes as he walks (up and down with every step, a touch from
## side to side every two, never a roll), a dip that springs back when he
## lands from a fall, and a slightly wider view while he sprints - all
## scaled by the head bob option ([member head_bob_scale]).

const FLASHLIGHT_ENERGY := 3.0
## Head bob: the eyes dip this far (m) with every step at a walk and at a
## sprint, sway this far sideways, and a step covers BOB_STRIDE m at a walk
## (longer when faster, like his footsteps).
const BOB_HEIGHT := 0.011
const BOB_SPRINT_HEIGHT := 0.018
const BOB_SIDE := 0.004
const BOB_STRIDE := 2.4
## Landing: the eyes dip LANDING_DIP m per m/s of the fall (from
## LANDING_DIP_SPEED on), never more than LANDING_DIP_MAX, and spring back.
const LANDING_DIP := 0.007
const LANDING_DIP_SPEED := 2.0
const LANDING_DIP_MAX := 0.07
## A sprint widens the view this much (degrees).
const SPRINT_FOV := 3.0
## RunState.used id of tonight's second wind.
const SECOND_WIND := &"second_wind"
## A tick of damage over time (DamageInfo.periodic: steam, a burn) takes its
## health at every tick but cries out - the hurt sound, the shake of the view,
## the flash event - at most this often (s). The ticks kept quiet are not
## lost to the listeners of Events.player_damaged: their damage goes out with
## the next cry; a tick that would kill always cries at once.
const PERIODIC_CUE_GAP := 1.0
## The level-floor check under the feet (m above and below them).
const FLOOR_PROBE_UP := 0.2
const FLOOR_PROBE_DOWN := 0.35
## Slowing effects together (a gatling firing in hand, paint underfoot)
## never take the guard below this share of his speed. (A dash is never
## slowed: dashing while cranking is allowed.)
const MIN_SPEED_FACTOR := 0.5
## Staggered (a Fu dog's roar): his legs carry him at this share of his
## speed, past MIN_SPEED_FACTOR.
const STAGGER_SPEED := 0.2
## Exhibits hear a sprint (a step every SPRINT_NOISE_INTERVAL seconds) and a
## landing from LANDING_NOISE_SPEED m/s PerceptionRules.STEP_NOISE metres
## away (Events.noise_made).
const SPRINT_NOISE_INTERVAL := 0.4
## A switched sprint (option sprint_toggle) ends when the guard has taken no
## step for this long (seconds; Shift a moment before W still works).
const SPRINT_IDLE_GRACE := 0.4
const LANDING_NOISE_SPEED := 3.5
## A ledge at most this high (a stair's open side, a dais's step, a lip) he
## walks up in his stride instead of stopping at it (QA #49); a higher one
## (a plinth, a bench) still stops him - a jump takes him up.
const STEP_HEIGHT := 0.35
## His eyes catch up with a step at this speed (m/s), so a step never pops
## the view up in one frame.
const STEP_EASE := 2.5
## A step is looked for this far ahead (m): his capsule's round must be
## over the step's top to stand on it.
const STEP_PROBE := 0.45

@export var walk_speed: float = 5.5
@export var sprint_speed: float = 8.5
@export var ground_accel: float = 60.0
@export var air_accel: float = 14.0
@export var jump_velocity: float = 5.0
@export var gravity: float = 15.0
@export var dash_speed: float = 15.0
@export var dash_time: float = 0.16
@export var dash_cooldown: float = 0.45
## Turn per mouse pixel (radians); follows the sensitivity option.
@export var mouse_sensitivity: float = 0.0022
@export var eye_height: float = 1.6
@export var finisher_heal: float = 15.0

var health: Health
var stamina := Stamina.new()
## Tiredness over the night (the clock feeds its fraction; a haven's rest
## and coffee bring it down); it holds the stamina bar down.
var fatigue := Fatigue.new()
var head: Node3D
var camera: ShakeCamera
var weapons: WeaponHolder
var flashlight: SpotLight3D
var battery := FlashlightBattery.new()
## What the guard is looking at and could use (E).
var interactor := Interactor.new()
var alive: bool = true
var sprinting: bool = false
## Sprint is switched on and off by its key (option sprint_toggle) instead of
## held; [member _sprint_latched] is the switch, [member _sprint_idle] the
## seconds the guard has not moved since.
var sprint_toggle: bool = false
var _sprint_latched: bool = false
var _sprint_idle: float = 0.0
## Dust flies to the guard from this far (dust magnet upgrade).
var dust_magnet_radius: float = DustMote.MAGNET_RADIUS
## Second wind is bought (once a night a killing blow leaves 1 health).
var second_wind: bool = false
## The keen ear's direction marker (made once the upgrade is bought).
var threat_indicator: ThreatIndicator = null
## Where the guard last stood on solid floor (the dropped lantern goes here).
var last_floor_position := Vector3.ZERO
## Seconds the guard still reels from a stagger (a Fu dog's roar).
var _stagger_left: float = 0.0
## Mouse up looks down (option).
var invert_y: bool = false
## The head bob option (0..1): bob, landing dip, the sprint's wider view.
var head_bob_scale: float = 1.0
## The bob's phase (pi per step), its eased strength (0 standing .. 1 at a
## walk), the landing dip's spring (m) and the sprint's eased widening.
var _bob_phase: float = 0.0
var _bob_height: float = 0.0
var _landing := Recoil.new(1, 4.0, 0.65)
var _sprint_fov: float = 0.0

var _eye: float = 1.6
var _dash_left: float = 0.0
var _dash_cd: float = 0.0
var _dash_dir := Vector3.ZERO
var _coyote: float = 0.0
var _jump_buffer: float = 0.0
var _death_tween: Tween = null
var _flicker_noise := FastNoiseLite.new()
var _flicker_time: float = 0.0
var _floor_ray: PhysicsRayQueryParameters3D = null
## Walking-speed factor of a slowing effect (paint underfoot) and how long
## it still holds.
var _slow_factor: float = 1.0
var _slow_left: float = 0.0
## Seconds of invulnerability left (second wind).
var _grace: float = 0.0
## Seconds until a tick of damage over time may cry out again.
var _cue_wait: float = 0.0
## Damage of the ticks kept quiet since the last cry (told with the next one).
var _cue_pending: float = 0.0
## A forced move (a mummy's bandage whip pulling him in): horizontal
## velocity and how long it still holds.
var _yank := Vector3.ZERO
var _yank_left: float = 0.0
## The yank just ended: he stops where it left him.
var _yank_halt := false
## Seconds to the next sprint step heard by the exhibits.
var _noise_timer: float = 0.0
## How far (m) his eyes still lag behind the body after a step up, at the
## end of this physics step and of the one before (the view interpolates
## between them as the body's transform does).
var _step_lag: float = 0.0
var _step_lag_before: float = 0.0


func _ready() -> void:
	add_to_group(&"player")
	last_floor_position = global_position
	collision_layer = Layers.PLAYER
	collision_mask = Layers.WORLD | Layers.ENEMY
	floor_snap_length = 0.3
	floor_constant_speed = true
	var shape := CapsuleShape3D.new()
	shape.radius = 0.4
	shape.height = 1.8
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position.y = 0.9
	add_child(collider)
	health = Health.new()
	add_child(health)
	health.depleted.connect(_on_depleted)
	_eye = eye_height
	head = Node3D.new()
	head.top_level = true
	head.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(head)
	head.global_position = global_position + Vector3.UP * _eye
	camera = ShakeCamera.new()
	head.add_child(camera)
	camera.current = true
	flashlight = SpotLight3D.new()
	flashlight.position = Vector3(0.15, -0.1, 0.0)
	flashlight.spot_range = 24.0
	flashlight.spot_angle = 24.0
	flashlight.light_energy = FLASHLIGHT_ENERGY
	flashlight.shadow_enabled = true
	flashlight.visible = false
	camera.add_child(flashlight)
	weapons = WeaponHolder.new()
	weapons.user = self
	camera.add_child(weapons)
	Events.enemy_destroyed.connect(_on_enemy_destroyed)
	Settings.settings_changed.connect(_on_settings_changed)
	_on_settings_changed(&"")


## Turns the view by a mouse movement in screen pixels.
func look(pixels: Vector2) -> void:
	var pitch := pixels.y * mouse_sensitivity * (-1.0 if invert_y else 1.0)
	head.rotation.y = wrapf(head.rotation.y - pixels.x * mouse_sensitivity, -PI, PI)
	head.rotation.x = clampf(head.rotation.x - pitch, deg_to_rad(-88.0), deg_to_rad(88.0))


func _unhandled_input(event: InputEvent) -> void:
	var motion := event as InputEventMouseMotion
	if motion != null and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and GameInput.gameplay_input():
		# screen_relative: the same turn per mouse move at any window size
		# (relative is scaled by the canvas_items stretch).
		look(motion.screen_relative)


func _process(_delta: float) -> void:
	var lag := lerpf(_step_lag_before, _step_lag, Engine.get_physics_interpolation_fraction())
	head.global_position = get_global_transform_interpolated().origin + Vector3.UP * (_eye - lag)
	_update_flashlight_light()
	_update_view_motion(get_process_delta_time())


## The bob, the landing dip and the sprint's view, onto the camera.
func _update_view_motion(delta: float) -> void:
	var speed := Vector2(velocity.x, velocity.z).length() if alive and is_on_floor() else 0.0
	var walking := clampf(speed / walk_speed, 0.0, 1.0)
	var running := clampf((speed - walk_speed) / maxf(sprint_speed - walk_speed, 0.1), 0.0, 1.0)
	var height := BOB_HEIGHT * walking + (BOB_SPRINT_HEIGHT - BOB_HEIGHT) * running
	_bob_height = lerpf(_bob_height, height, 1.0 - exp(-8.0 * delta))
	if speed > 0.1:
		var stride := BOB_STRIDE * sqrt(speed / walk_speed)
		_bob_phase = fmod(_bob_phase + PI * speed / stride * delta, TAU * 64.0)
	_landing.step(delta)
	_sprint_fov = lerpf(_sprint_fov, SPRINT_FOV if sprinting and alive else 0.0, 1.0 - exp(-6.0 * delta))
	var dip := sin(_bob_phase)
	camera.motion = Vector3(BOB_SIDE * (_bob_height / BOB_HEIGHT) * dip, -_bob_height * dip * dip + _landing.value(0), 0.0) \
			* head_bob_scale
	camera.motion_fov = _sprint_fov * head_bob_scale


## The landing dip now (m, negative = down), for the weapon to follow.
func landing_offset() -> float:
	return _landing.value(0) * head_bob_scale


## Does the guard ask for a sprint this frame: the key held, or - with the
## option sprint_toggle - the switch the key flips (it falls when a menu takes
## the input or the guard has stood still for SPRINT_IDLE_GRACE).
func _wants_sprint(controls: bool, input: Vector2, delta: float) -> bool:
	var moving := input.length() > 0.1
	if not sprint_toggle:
		_sprint_latched = false
		return controls and Input.is_action_pressed(&"sprint") and moving
	if not controls:
		_sprint_latched = false
		return false
	if GameInput.fresh_press(&"sprint"):
		_sprint_latched = not _sprint_latched
		_sprint_idle = 0.0
	_sprint_idle = 0.0 if moving else _sprint_idle + delta
	if _sprint_idle > SPRINT_IDLE_GRACE:
		_sprint_latched = false
	return _sprint_latched and moving


## Switches the flashlight (through the battery). False when it stays dark.
func set_flashlight(lit: bool) -> bool:
	var switched := battery.set_on(lit)
	if not switched:
		Sfx.play(&"empty", -10.0)
	_update_flashlight_light()
	return switched


func _physics_process(delta: float) -> void:
	var controls := GameInput.gameplay_input()
	_update_interaction(controls)
	battery.tick(delta)
	if alive and GameInput.fresh_press(&"flashlight"):
		set_flashlight(not battery.on)
	var on_floor := is_on_floor()
	if not on_floor:
		velocity.y -= gravity * delta
	if not alive:
		var still := Vector3(velocity.x, 0.0, velocity.z).move_toward(Vector3.ZERO, ground_accel * delta)
		velocity.x = still.x
		velocity.z = still.z
		move_and_slide()
		_remember_floor()
		return
	var input := Vector2.ZERO
	if controls:
		input = Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back")
	var wish := Basis(Vector3.UP, head.rotation.y) * Vector3(input.x, 0.0, input.y)
	sprinting = _wants_sprint(controls, input, delta) and weapons.allows_sprint() and stamina.spend_sprint(delta)
	if _sprint_latched and not sprinting and input.length() > 0.1:
		_sprint_latched = false   # out of breath or a weapon forbids it: not resumed by itself
	_dash_cd = maxf(_dash_cd - delta, 0.0)
	_dash_left = maxf(_dash_left - delta, 0.0)
	if GameInput.fresh_press(&"dash"):
		dash(wish)
	_update_jump(delta, on_floor, controls)
	if _yank_left > 0.0:
		# the last step only covers what is left of it, then he stops dead
		var share := minf(_yank_left, delta) / delta
		_yank_left = maxf(_yank_left - delta, 0.0)
		velocity.x = _yank.x * share
		velocity.z = _yank.z * share
		_yank_halt = _yank_left <= 0.0
	elif _yank_halt:
		_yank_halt = false
		velocity.x = 0.0
		velocity.z = 0.0
	elif _dash_left > 0.0:
		velocity.x = _dash_dir.x * dash_speed
		velocity.z = _dash_dir.z * dash_speed
	else:
		var target := wish * (sprint_speed if sprinting else walk_speed) * speed_factor()
		var accel := ground_accel if on_floor else air_accel
		var horizontal := Vector3(velocity.x, 0.0, velocity.z).move_toward(target, accel * delta)
		velocity.x = horizontal.x
		velocity.z = horizontal.z
	fatigue.tick(delta, sprinting, Haven.shelters(global_position))
	var tired := fatigue.take_rise()
	if tired > 0:
		Events.fatigue_rose.emit(tired)   # the voice comments it (plan 2026-10-19-glos-g2-kwestie)
	stamina.capacity_factor = fatigue.capacity_factor()
	stamina.regen_factor = fatigue.regen_factor()
	stamina.tick(delta)
	_slow_left = maxf(_slow_left - delta, 0.0)
	_stagger_left = maxf(_stagger_left - delta, 0.0)
	_grace = maxf(_grace - delta, 0.0)
	_cue_wait = maxf(_cue_wait - delta, 0.0)
	var falling := -velocity.y
	var start := global_transform
	var pushing := Vector3(velocity.x, 0.0, velocity.z)
	move_and_slide()
	_step_lag_before = _step_lag
	# just up a step his round feet settle onto its edge: the lag his eyes
	# still have takes that in, so his view does not dip (bob) on the way up
	var settled := start.origin.y - global_position.y
	if settled > 0.0 and _step_lag > 0.0 and on_floor and is_on_floor():
		_step_lag = maxf(_step_lag - settled, 0.0)
	_step_lag = move_toward(_step_lag, 0.0, STEP_EASE * delta)
	if on_floor and is_on_wall() and pushing.length() > 0.1:
		_step_up(start, pushing * delta)
	_remember_floor()
	_make_noise(delta, on_floor, falling)
	if not on_floor and is_on_floor() and falling >= LANDING_DIP_SPEED:
		_landing.kick(0, -minf(falling * LANDING_DIP, LANDING_DIP_MAX))


## He walked from [param start] into something that stopped (or turned) the
## move [param wanted] of this step: when it is a ledge at most STEP_HEIGHT
## high with floor on top, he goes up onto it instead, keeping his speed.
## The step is found by trying the move again raised by STEP_HEIGHT and
## STEP_PROBE m long (far enough for his round feet to come down on the
## step's top, not on its edge) and setting that down on what is there;
## then he takes this step's move at the step's height (the floor snap puts
## him on the edge, the next steps carry him over it). Only the building
## counts (an exhibit is never a step). True when he stepped up.
func _step_up(start: Transform3D, wanted: Vector3) -> bool:
	var slid := Vector3(global_position.x - start.origin.x, 0.0, global_position.z - start.origin.z)
	if slid.length() >= wanted.length() * 0.9:
		return false   # barely held up: no step to take
	var probe := wanted.normalized() * maxf(wanted.length(), STEP_PROBE)
	var mask := collision_mask
	collision_mask = Layers.WORLD
	var hit := KinematicCollision3D.new()
	var lift := Vector3.UP * STEP_HEIGHT
	if test_move(start, lift, hit):
		lift = hit.get_travel()
	var raised := start.translated(lift)
	var free_ahead := not test_move(raised, probe, hit)
	var rise := INF
	if free_ahead and test_move(raised.translated(probe), -lift - Vector3.UP * 0.05, hit) 			and hit.get_normal().angle_to(Vector3.UP) <= floor_max_angle:
		rise = lift.y + hit.get_travel().y
	var lifted := start.translated(Vector3.UP * (rise + 0.002)) if rise != INF else start
	var placed := rise != INF and rise >= -0.05 and rise <= STEP_HEIGHT + 0.01 and not test_move(lifted, wanted, hit)
	collision_mask = mask
	if not placed:
		return false
	global_transform = lifted.translated(wanted)
	velocity.x = wanted.x / get_physics_process_delta_time()
	velocity.z = wanted.z / get_physics_process_delta_time()
	velocity.y = 0.0
	_step_lag = clampf(_step_lag + maxf(rise, 0.0), 0.0, STEP_HEIGHT)
	return true


## Sprint steps and hard landings are noises the exhibits hear.
func _make_noise(delta: float, was_on_floor: bool, fall_speed: float) -> void:
	_noise_timer = maxf(_noise_timer - delta, 0.0)
	var landed := not was_on_floor and is_on_floor() and fall_speed >= LANDING_NOISE_SPEED
	if landed:
		Events.noise_made.emit(global_position, PerceptionRules.STEP_NOISE, &"landing")
	elif sprinting and is_on_floor() and _noise_timer <= 0.0:
		_noise_timer = SPRINT_NOISE_INTERVAL
		Events.noise_made.emit(global_position, PerceptionRules.STEP_NOISE, &"sprint")


## Walking speed multiplier: a gatling firing in hand (WeaponHolder.move_factor())
## times a slowing effect (paint underfoot), never below MIN_SPEED_FACTOR.
func speed_factor() -> float:
	if _stagger_left > 0.0:
		return STAGGER_SPEED
	return maxf(weapons.move_factor() * (_slow_factor if _slow_left > 0.0 else 1.0), MIN_SPEED_FACTOR)


## Staggers the guard for [param seconds] (a Fu dog's roar): he barely
## moves (STAGGER_SPEED), cannot dash, fire nor punch (his weapon dips),
## and his view reels. A longer stagger outlasts a shorter one.
func stagger(seconds: float) -> void:
	if not alive or seconds <= 0.0 or _grace > 0.0:
		return
	_stagger_left = maxf(_stagger_left, seconds)
	_dash_left = 0.0
	weapons.daze(seconds)
	camera.add_trauma(0.55)
	camera.kick_fov(7.0)


## True while a stagger holds him.
func staggered() -> bool:
	return _stagger_left > 0.0


## Slows the guard to [param factor] of his speed for [param seconds]
## (the strongest slow wins while several hold).
func slow(factor: float, seconds: float) -> void:
	_slow_factor = factor if _slow_left <= 0.0 else minf(_slow_factor, factor)
	_slow_left = maxf(_slow_left, seconds)


## Drags the guard along [param velocity_] (horizontal, m/s) for
## [param seconds], whatever he presses (a mummy's bandage whip pulling him
## in); walls still stop him. A newer yank replaces an older one.
func yank(velocity_: Vector3, seconds: float) -> void:
	if not alive or seconds <= 0.0:
		return
	_yank = Vector3(velocity_.x, 0.0, velocity_.z)
	_yank_left = seconds
	_dash_left = 0.0


## True while a yank drags him.
func yanked() -> bool:
	return _yank_left > 0.0


## Dashes along [param direction] (or where the guard looks). Returns false
## while on cooldown, out of stamina or dead.
func dash(direction: Vector3 = Vector3.ZERO) -> bool:
	if not alive or _dash_cd > 0.0 or _stagger_left > 0.0 or not stamina.try_dash():
		return false
	var flat := Vector3(direction.x, 0.0, direction.z)
	if flat.length() < 0.1:
		flat = Basis(Vector3.UP, head.rotation.y) * Vector3.FORWARD
	_dash_dir = flat.normalized()
	_dash_left = dash_time
	_dash_cd = dash_cooldown
	fatigue.add_dash()
	camera.kick_fov(8.0)
	Sfx.play(&"dash", -4.0)
	return true


func take_damage(info: DamageInfo) -> void:
	if not alive or _grace > 0.0:
		return
	if info.amount >= health.current and second_wind_ready():
		_second_wind(info)
		return
	var cries := not info.periodic or _cue_wait <= 0.0 or info.amount >= health.current
	if not cries:
		_cue_pending += info.amount
	else:
		if info.periodic:
			_cue_wait = PERIODIC_CUE_GAP
		Events.player_damaged.emit(info.amount + _cue_pending, info.position)
		_cue_pending = 0.0
		camera.add_trauma(0.25 + info.amount / 60.0)
	var push := Vector3(info.direction.x, 0.0, info.direction.z)
	if info.knockback > 0.0 and push.length() > 0.01:
		velocity += push.normalized() * info.knockback
	if cries:
		Sfx.play(&"hurt")
	health.apply_damage(info.amount)


func heal(amount: float) -> float:
	return health.heal(amount)


## Second wind is bought and not used yet tonight (RunState.used, so a
## resumed night remembers it).
func second_wind_ready() -> bool:
	return second_wind and not RunState.is_used(SECOND_WIND)


## True during the second of grace after a second wind.
func invulnerable() -> bool:
	return _grace > 0.0


## A killing blow with second wind: 1 health left, a second of grace, the
## world greys out to a heartbeat.
func _second_wind(info: DamageInfo) -> void:
	RunState.mark_used(SECOND_WIND)
	Events.player_damaged.emit(info.amount, info.position)
	camera.add_trauma(0.7)
	var push := Vector3(info.direction.x, 0.0, info.direction.z)
	if info.knockback > 0.0 and push.length() > 0.01:
		velocity += push.normalized() * info.knockback
	if health.current > 1.0:
		health.apply_damage(health.current - 1.0)
	_grace = UpgradeEffects.SECOND_WIND_GRACE
	Sfx.play(&"hurt")
	Sfx.play(&"heartbeat")
	SecondWindFx.play(self)


## Applies permanent upgrades (id -> level): health, stamina, flashlight
## battery, finisher healing and every weapon. Extra maximum health is
## granted at once.
func apply_upgrades(levels: Dictionary) -> void:
	var new_max := UpgradeEffects.max_health(levels)
	var gained := new_max - health.max_health
	health.max_health = new_max
	if gained > 0.0:
		health.heal(gained)
	elif health.current > new_max:
		health.current = new_max
	stamina.maximum = UpgradeEffects.stamina_max(levels)
	stamina.regen_per_sec = UpgradeEffects.stamina_regen(levels)
	stamina.current = minf(stamina.current, stamina.maximum)
	battery.set_capacity(UpgradeEffects.battery_capacity(levels))
	finisher_heal = UpgradeEffects.finisher_heal(levels)
	dust_magnet_radius = UpgradeEffects.dust_magnet_radius(levels)
	second_wind = UpgradeEffects.has_second_wind(levels)
	if UpgradeEffects.has_keen_ear(levels) and threat_indicator == null:
		threat_indicator = ThreatIndicator.new()
		threat_indicator.player = self
		add_child(threat_indicator)
	if threat_indicator != null:
		threat_indicator.enabled = UpgradeEffects.has_keen_ear(levels)
	weapons.apply_upgrades(levels)


## Full health, stamina and flashlight (start of a night, a haven). Fatigue
## stays: rest in time and coffee bring that down.
func refill() -> void:
	health.heal(health.max_health)
	stamina.current = stamina.maximum
	stamina.exhausted = false
	battery.charge = battery.capacity


## Brings the guard back at [param at] with nothing left over from before
## death (dash, jump timers, sprint, the death drop of the eyes).
func respawn(at: Vector3, yaw: float = 0.0) -> void:
	if _death_tween != null:
		_death_tween.kill()
		_death_tween = null
	global_position = at
	last_floor_position = at
	velocity = Vector3.ZERO
	head.rotation = Vector3(0.0, yaw, 0.0)
	_eye = eye_height
	_dash_left = 0.0
	_dash_cd = 0.0
	_stagger_left = 0.0
	weapons.daze(0.0)
	_grace = 0.0
	_slow_left = 0.0
	_yank_left = 0.0
	_yank_halt = false
	_jump_buffer = 0.0
	_coyote = 0.0
	_step_lag = 0.0
	_step_lag_before = 0.0
	sprinting = false
	_sprint_latched = false
	_sprint_idle = 0.0
	health.reset()
	stamina.current = stamina.maximum
	stamina.exhausted = false
	fatigue.reset()
	_landing.reset()
	_bob_height = 0.0
	_sprint_fov = 0.0
	alive = true
	weapons.enabled = true
	reset_physics_interpolation()
	head.global_position = at + Vector3.UP * _eye


## Light follows the battery; a weak battery makes it stutter.
func _update_flashlight_light() -> void:
	flashlight.visible = battery.on
	if not battery.on:
		return
	var energy := FLASHLIGHT_ENERGY
	if battery.is_flickering():
		_flicker_time += get_process_delta_time()
		var wobble := _flicker_noise.get_noise_1d(_flicker_time * 30.0) * 0.5 + 0.5
		energy *= Flashing.lamp_level(0.15 + 0.85 * clampf(wobble * 1.6 - 0.3, 0.0, 1.0))
	flashlight.light_energy = energy


## Refreshes the use-probe from the eyes and uses the focus on the key.
func _update_interaction(controls: bool) -> void:
	if not alive:
		interactor.clear()
		return
	var eye := camera.global_transform
	interactor.update(get_world_3d().direct_space_state, eye.origin, -eye.basis.z, self)
	if controls and GameInput.fresh_press(&"interact") and interactor.try_interact(self):
		weapons.reach()   # the left hand goes out to it


## Keeps the spot the dropped lantern would go to: level floor only (not an
## exhibit's head or back) and never inside a haven (the next night starts
## there and would hand the Dust back at once).
func _remember_floor() -> void:
	if not is_on_floor() or Haven.shelters(global_position):
		return
	if _floor_ray == null:
		_floor_ray = PhysicsRayQueryParameters3D.new()
		_floor_ray.collision_mask = Layers.WORLD
	_floor_ray.from = global_position + Vector3.UP * FLOOR_PROBE_UP
	_floor_ray.to = global_position - Vector3.UP * FLOOR_PROBE_DOWN
	if not get_world_3d().direct_space_state.intersect_ray(_floor_ray).is_empty():
		last_floor_position = global_position


func _update_jump(delta: float, on_floor: bool, controls: bool) -> void:
	_coyote = 0.12 if on_floor else maxf(_coyote - delta, 0.0)
	var pressed := controls and GameInput.fresh_press(&"jump")
	_jump_buffer = 0.12 if pressed else maxf(_jump_buffer - delta, 0.0)
	if _jump_buffer > 0.0 and _coyote > 0.0:
		velocity.y = jump_velocity
		_jump_buffer = 0.0
		_coyote = 0.0


func _on_depleted() -> void:
	alive = false
	weapons.enabled = false
	_death_tween = create_tween()
	_death_tween.tween_property(self, "_eye", 0.4, 0.5)
	Events.player_died.emit()


func _on_settings_changed(_key: StringName) -> void:
	mouse_sensitivity = Settings.mouse_turn_per_pixel()
	invert_y = Settings.data.invert_y
	camera.base_fov = Settings.data.fov
	camera.shake_scale = Settings.data.screen_shake
	head_bob_scale = Settings.data.head_bob
	sprint_toggle = Settings.data.sprint_toggle


func _on_enemy_destroyed(_enemy: Node, info: DamageInfo, finisher: bool) -> void:
	if finisher and info != null and info.source == self:
		heal(finisher_heal)
