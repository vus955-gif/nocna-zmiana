class_name Guardian
extends CharacterBody3D
## A wing guardian of Floor I (design 7.4), the base every guardian builds
## on (the greybox GuardianStub now, the Colossus, the Lamassu... later).
## It sleeps on its post until the guard walks into its arena (a room of
## the layout), then fights there: phases by health (2 below 66%, 3 below
## 33%), each announced (phase_changed: the music's hi layer, the arena's
## supplies). The guard out of the arena for LEASH_TIME s calms it: back
## on its post with full health ([signal calmed]; a death in the fight
## changes nothing either - a guardian falls only for good). Its fall:
## [signal defeated], Events.guardian_defeated (the keeper records it,
## drops its seal and shard and its Dust).
## The base handles the states, health, phases, the leash, hits (hit
## markers, weak points through the weapons' Hurtbox multiplier), dawn
## (freeze) and the announcements (Events.guardian_awakened(self, id) for
## the HUD's bar and the music). It fights only on its arena: a hit while
## the guard stands outside the arena room (a gallery over it, a doorway)
## does no harm and does not wake it - no sniping from out of reach. Subclasses build the body and fight:
## _build_body(), _fight_process(delta), _on_phase(phase), _on_reset(),
## _on_defeated(info); _should_wake() and _damage_factor(info) may change,
## and _hit_effects(info), _report_hit(info), _on_freeze() and
## reward_point() too.
## Hit zones: weapons merge the pellets of one shot per receiver, so a
## guardian with armour and weak points gives each zone a receiver of its
## own (GuardianZone): its hits arrive through take_zone_damage(info, zone)
## and _damage_factor() reads [member hit_zone].
## The real guardian of a wing is src/game/floor1/guardians/<id>.gd (see
## GuardianKeeper: it may also dress its arena with a static
## dress_arena()).
## Configure (plan, arena_room, room_of, target) before add_child().

signal awakened
signal phase_changed(phase: int)
## The guard fled: back on its post, full health, asleep.
signal calmed
signal defeated

enum State { DORMANT, FIGHT, DEFEATED }

const GRAVITY := 15.0
## The guard out of the arena this long calms the guardian (s).
const LEASH_TIME := 6.0
## A guardian this far (m) under its post has fallen out of the world (a
## physics glitch): it gives the fight up as if the guard had fled - back on
## its post, the arena open - rather than leave him shut in with nothing to
## fight (QA #50).
const LOST_DROP := 8.0
## Every attack is announced at least this long before it lands (design
## 7.4: "każdy atak ma zapowiedź >= 0,6 s").
const MIN_TELEGRAPH := 0.6

@export var max_health: float = 900.0
## Dust of its fall (design 8.3: a wing guardian 60).
@export var dust_value: int = 60
## How hard its attacks hit (the difficulty: DifficultyRules.tune_guardian).
var damage_scale: float = 1.0
## The hit zone (GuardianZone) of the hit being taken, &"" for a hit that
## came straight to take_damage().
var hit_zone: StringName = &""
## Health fractions where phases 2, 3... begin.
var phase_thresholds: Array[float] = [0.66, 0.33]

var guardian_id: StringName = &""
var plan: Floor1Plan.GuardianPlan = null
var health: Health
var state: State = State.DORMANT
## 0 asleep; 1, 2, 3 in the fight.
var phase: int = 0
## The guard.
var target: Node3D = null
## Room id of its arena and (Vector3) -> room id of the level.
var arena_room: StringName = &""
var room_of: Callable = Callable()
## Its post (where it sleeps and goes back to).
var home := Transform3D.IDENTITY
## The arena's start line (arena_<id>_start; Vector3.INF = none): the guard
## wakes it once he is within WAKE_REACH m of it or nearer the guardian
## than it is, not on the arena's threshold.
var wake_point := Vector3.INF

const WAKE_REACH := 3.5
## A hit from outside the arena says so at most this often (s).
const SHRUG_HINT_EVERY := 4.0

## Named points of its arena from its own markers (<id>_<name>_<n>, in
## order): the Lamassu's relief slabs (&"relief"), the Serpent's loop
## (&"path"), the Colossus's columns (&"column")...
var points: Dictionary = {}
## True while the subclass moves the body itself (no gravity, no sliding:
## a serpent gliding over its terraces).
var kinematic: bool = false

var _away: float = 0.0
var _frozen := false
var _shrug_wait: float = 0.0


func _ready() -> void:
	add_to_group(&"guardians")
	collision_layer = Layers.ENEMY
	collision_mask = Layers.WORLD | Layers.PLAYER
	health = Health.new()
	health.max_health = max_health
	add_child(health)
	home = global_transform
	if plan != null and guardian_id == &"":
		guardian_id = plan.id
	_build_body()


func _physics_process(delta: float) -> void:
	if _frozen or state == State.DEFEATED:
		return
	_shrug_wait = maxf(_shrug_wait - delta, 0.0)
	match state:
		State.DORMANT:
			velocity.x = 0.0
			velocity.z = 0.0
			if _should_wake():
				wake()
		State.FIGHT:
			if global_position.y < home.origin.y - LOST_DROP:
				reset_fight()
				return
			if guard_in_arena() or not guard_alive():
				_away = 0.0
			else:
				_away += delta
				if _away >= LEASH_TIME:
					reset_fight()
					return
			if guard_alive():
				_fight_process(delta)
			else:
				velocity.x = 0.0
				velocity.z = 0.0
	if kinematic:
		return
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = maxf(velocity.y, 0.0)
	move_and_slide()


## The guardian's name ("Kolos Ramzesa") and title ("Strażnik Egiptu").
func display_name() -> String:
	return tr(plan.name_key) if plan != null else String(guardian_id)


func title() -> String:
	return tr(plan.title_key) if plan != null else ""


func guard_alive() -> bool:
	if not is_instance_valid(target):
		return false
	var alive: Variant = target.get(&"alive")
	return not (alive is bool) or alive


## True while the guard stands in the arena (anywhere when the guardian
## has no arena room).
func guard_in_arena() -> bool:
	if not is_instance_valid(target):
		return false
	if arena_room == &"" or not room_of.is_valid():
		return true
	return room_of.call(target.global_position + Vector3.UP * 0.5) == arena_room


## The fight begins (the guard walked in, or hit it from afar).
func wake() -> void:
	if state != State.DORMANT or _frozen:
		return
	state = State.FIGHT
	phase = 1
	_away = 0.0
	Sfx.play_at(&"guardian_wake", global_position + Vector3.UP * 2.0)
	awakened.emit()
	Events.guardian_awakened.emit(self, guardian_id)
	_on_phase(1)
	phase_changed.emit(1)


## Back on its post, full health, asleep (the guard fled the arena).
func reset_fight() -> void:
	if state != State.FIGHT:
		return
	state = State.DORMANT
	phase = 0
	_away = 0.0
	health.reset()
	velocity = Vector3.ZERO
	global_transform = home
	reset_physics_interpolation()
	_on_reset()
	calmed.emit()


## A hit through its hit zone [param zone] (a GuardianZone receiver).
func take_zone_damage(info: DamageInfo, zone: StringName) -> void:
	hit_zone = zone
	take_damage(info)
	hit_zone = &""


func take_damage(info: DamageInfo) -> void:
	if state == State.DEFEATED or _frozen or info == null:
		return
	if not hit_counts():
		_shrug(info)
		return
	if state == State.DORMANT:
		wake()
	var amount := info.amount * _damage_factor(info)
	if info.effects and not info.periodic:
		_hit_effects(info)
	health.apply_damage(amount)
	if health.is_dead():
		_die(info)
		return
	var next := phase_for(health.fraction())
	while phase < next:
		phase += 1
		_on_phase(phase)
		phase_changed.emit(phase)
	if not info.periodic:
		_report_hit(info)


## Where its seal and shard fall when it falls (GuardianKeeper; an arena's
## arena_<id>_reward marker comes first).
func reward_point() -> Vector3:
	return global_position


## True when a hit now counts: the guard stands in the arena (or it has
## none). From a gallery over it or a doorway outside it, nothing does.
func hit_counts() -> bool:
	if arena_room == &"" or not room_of.is_valid():
		return true
	return guard_in_arena()


## A hit from outside the arena glances off (sparks, the hint now and then).
func _shrug(info: DamageInfo) -> void:
	if info.effects and not info.periodic:
		Fx.impact(info.position, info.normal, ExhibitMaterial.Kind.METAL, 0.6)
	if _shrug_wait > 0.0:
		return
	_shrug_wait = SHRUG_HINT_EVERY
	Events.hint_requested.emit(tr("HUD_GUARDIAN_OUT_OF_ARENA"))


## The phase a guardian with [param fraction] of its health fights in.
func phase_for(fraction: float) -> int:
	var found := 1
	for threshold in phase_thresholds:
		if fraction < threshold:
			found += 1
	return found


## Dawn: it stops dead and greys over (the night is over).
func freeze() -> void:
	if _frozen:
		return
	_frozen = true
	velocity = Vector3.ZERO
	set_physics_process(false)
	_on_freeze()
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color(0.46, 0.46, 0.47)
	stone.roughness = 0.95
	for node in find_children("*", "GeometryInstance3D", true, false):
		(node as GeometryInstance3D).material_override = stone


func is_frozen() -> bool:
	return _frozen


func is_fighting() -> bool:
	return state == State.FIGHT


func _die(info: DamageInfo) -> void:
	state = State.DEFEATED
	velocity = Vector3.ZERO
	Events.hit_landed.emit(self, info, true)
	Sfx.play_at(&"guardian_crumble", global_position + Vector3.UP * 2.0)
	Events.shake_requested.emit(0.45)
	_on_defeated(info)
	defeated.emit()
	Events.guardian_defeated.emit(guardian_id)
	queue_free()


# --- subclass hooks ----------------------------------------------------------

## Collider, look and hurtboxes (Hurtbox.make(self, ...)).
func _build_body() -> void:
	pass


## One physics step of the fight (set velocity; attack with telegraphs).
func _fight_process(_delta: float) -> void:
	pass


## Phase [param _phase] begins (1 when it wakes).
func _on_phase(_phase: int) -> void:
	pass


## Calmed: back on the post (stop attacks, hide telegraphs).
func _on_reset() -> void:
	pass


## The fall's look (pieces, dust) before it is freed.
func _on_defeated(_info: DamageInfo) -> void:
	pass


## Dawn froze it: hide what must not turn to stone (telegraphs, beams).
func _on_freeze() -> void:
	pass


## The look of a hit landing (sparks, dust, a sound).
func _hit_effects(info: DamageInfo) -> void:
	Fx.impact(info.position, info.normal, ExhibitMaterial.Kind.MARBLE, clampf(info.amount / 15.0, 0.5, 2.5))
	Sfx.play_at(&"hit_marble", info.position, -2.0)


## Tells the HUD a hit landed (its hit marker).
func _report_hit(info: DamageInfo) -> void:
	Events.hit_landed.emit(self, info, false)


## True when it wakes now (default: the guard is in its arena).
func _should_wake() -> bool:
	if not guard_alive() or arena_room == &"" or not guard_in_arena():
		return false
	if wake_point == Vector3.INF:
		return true
	var guard := target.global_position
	return guard.distance_to(wake_point) <= WAKE_REACH or guard.distance_to(global_position) <= wake_point.distance_to(global_position)


## How much of a hit counts (armour, a shield...; weak points are the
## weapons' business through Hurtbox.weak_point).
func _damage_factor(_info: DamageInfo) -> float:
	return 1.0
