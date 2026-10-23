class_name PlaythroughPilot
extends RefCounted
## The playthrough bot's hands on the controls (plan
## docs/superpowers/plans/2026-10-21-przejscie-bota.md): everything it does
## to the guard goes through what a player has - the input actions (walk
## along the head's axes, sprint, jump, dash, fire, punch, use, reload), the
## weapon keys (weapon_N events through Input.parse_input_event) and the
## mouse (Player.look() with pixels, at most TURN_RATE degrees a second).
## Nothing sets his position, health or ammo.
## Call apply(delta) once every physics step BEFORE the guard's own step
## (the bot's node runs with a lower process_physics_priority), then the
## guard's controller reads the keys as if they were pressed.

## How fast the bot turns its view (degrees a second): a quick flick of
## the mouse, not an instant snap.
const TURN_RATE := 540.0
## A tap holds its key this many physics steps, then leaves it up at least
## as long before the same key again (a "just pressed" for the game).
const TAP_HOLD := 2
const TAP_REST := 2
## The keys the pilot may hold (released by release_all()).
const MOVE_KEYS: Array[StringName] = [&"move_forward", &"move_back", &"move_left", &"move_right"]
const TAP_KEYS: Array[StringName] = [&"interact", &"jump", &"punch", &"reload", &"dash"]

var guard: Player
## The world direction he walks (horizontal; length 0..1) and whether he sprints.
var walk := Vector3.ZERO
var sprint := false
## Holding the trigger.
var firing := false
## Degrees a second the view turns at most (TURN_RATE; less for the bot
## that plays like a person - PlaythroughBot.human).
var turn_rate: float = TURN_RATE
## Where the view should point: a point in the world (INF: keep the view).
var aim_point := Vector3.INF
## Keys tapped: action -> steps it is still held (negative: steps of rest).
var _taps: Dictionary = {}
## Weapon key events still to let go of (action names).
var _weapon_up: Array[StringName] = []
## Steps the pilot has run.
var steps: int = 0
## The view already turned this step (turn_now()).
var _turned: bool = false


func _init(player: Player) -> void:
	guard = player


## Walks along [param direction] (world, horizontal; any length, capped at
## 1), sprinting when [param run].
func move(direction: Vector3, run: bool = false) -> void:
	walk = Vector3(direction.x, 0.0, direction.z)
	if walk.length() > 1.0:
		walk = walk.normalized()
	sprint = run


func stop() -> void:
	walk = Vector3.ZERO
	sprint = false


## Points the view at [param point] (turning at turn_rate).
func look_at_point(point: Vector3) -> void:
	aim_point = point


## Taps [param action] (interact, jump, punch, reload, dash): false when the
## key is still down or resting from the last tap.
func tap(action: StringName) -> bool:
	if _taps.has(action):
		return false
	_taps[action] = TAP_HOLD
	Input.action_press(action)
	return true


## True while [param action] is held or resting from a tap.
func tapping(action: StringName) -> bool:
	return _taps.has(action)


## Presses the weapon key of [param id] (WeaponHolder.SLOT_ORDER: 1 the
## taser ... 8 the hwacha). False when he does not have it or it is in hand.
func select_weapon(id: StringName) -> bool:
	var slot := WeaponHolder.SLOT_ORDER.find(id)
	if slot < 0 or not guard.weapons.has_weapon(id):
		return false
	var current := guard.weapons.current_state()
	if current != null and current.data.id == id:
		return false
	var action := StringName("weapon_%d" % (slot + 1))
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	Input.parse_input_event(event)
	_weapon_up.append(action)
	return true


## The weapon in his hands (&"" with none).
func weapon() -> StringName:
	var current := guard.weapons.current_state()
	return current.data.id if current != null else &""


## The view's direction now.
func forward() -> Vector3:
	return -guard.head.global_basis.z


## The angle (degrees) between the view and the way to [param point].
func aim_error(point: Vector3) -> float:
	var to := point - eye()
	if to.length() < 0.001:
		return 0.0
	return rad_to_deg(forward().angle_to(to))


## The guard's eye (the camera).
func eye() -> Vector3:
	return guard.camera.global_position


## One physics step of the controls ([param delta] s): the view turns
## toward the aim, the walking keys press along the head's axes, taps
## count down, the trigger follows [member firing].
func apply(delta: float) -> void:
	steps += 1
	for action in _weapon_up:
		var event := InputEventAction.new()
		event.action = action
		event.pressed = false
		Input.parse_input_event(event)
	_weapon_up.clear()
	if not _turned:
		_turn(delta)
	_turned = false
	_press_walk()
	_press(&"sprint", sprint and walk.length() > 0.1)
	_press(&"fire", firing)
	# a tap: held TAP_HOLD steps (positive count), then up for TAP_REST (negative)
	for action: StringName in _taps.keys():
		var left: int = _taps[action]
		if left > 0:
			left -= 1
			if left == 0:
				Input.action_release(action)
				left = -TAP_REST
			_taps[action] = left
		else:
			left += 1
			if left >= 0:
				_taps.erase(action)
			else:
				_taps[action] = left


## Turns the view toward the aim now (once a step: apply() then leaves
## it), so what the view meets can be judged before the trigger.
func turn_now(delta: float) -> void:
	if not _turned:
		_turn(delta)
		_turned = true


## Lets go of every key the pilot holds.
func release_all() -> void:
	for action in MOVE_KEYS:
		Input.action_release(action)
	for action in TAP_KEYS:
		Input.action_release(action)
	Input.action_release(&"sprint")
	Input.action_release(&"fire")
	_taps.clear()
	walk = Vector3.ZERO
	sprint = false
	firing = false


## The yaw and pitch (radians) that look from the eye at [param point].
func angles_to(point: Vector3) -> Vector2:
	var to := point - eye()
	var flat := Vector2(to.x, to.z).length()
	return Vector2(atan2(-to.x, -to.z), atan2(to.y, flat))


func _turn(delta: float) -> void:
	if aim_point == Vector3.INF or guard.mouse_sensitivity <= 0.0:
		return
	var goal := angles_to(aim_point)
	var yaw := guard.head.rotation.y
	var pitch := guard.head.rotation.x
	var max_turn := deg_to_rad(turn_rate) * delta
	var d_yaw := clampf(wrapf(goal.x - yaw, -PI, PI), -max_turn, max_turn)
	var d_pitch := clampf(goal.y - pitch, -max_turn, max_turn)
	if absf(d_yaw) < 0.00001 and absf(d_pitch) < 0.00001:
		return
	# Player.look: yaw -= x * sensitivity, pitch -= y * sensitivity (unless inverted)
	var y_sign := -1.0 if guard.invert_y else 1.0
	guard.look(Vector2(-d_yaw / guard.mouse_sensitivity, -d_pitch / guard.mouse_sensitivity * y_sign))


func _press_walk() -> void:
	var local := Basis(Vector3.UP, -guard.head.rotation.y) * walk
	_strength(&"move_right", maxf(local.x, 0.0))
	_strength(&"move_left", maxf(-local.x, 0.0))
	_strength(&"move_back", maxf(local.z, 0.0))
	_strength(&"move_forward", maxf(-local.z, 0.0))


func _strength(action: StringName, value: float) -> void:
	if value > 0.01:
		Input.action_press(action, clampf(value, 0.0, 1.0))
	else:
		Input.action_release(action)


func _press(action: StringName, down: bool) -> void:
	if down:
		if not Input.is_action_pressed(action):
			Input.action_press(action)
	elif Input.is_action_pressed(action):
		Input.action_release(action)
