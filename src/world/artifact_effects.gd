class_name ArtifactEffects
extends Node
## What the night's artifacts (RunState.artifacts) do, without hooks in the
## guard, the exhibits or the Dust code:
## - scarab: a fist finisher heals once more (Events.enemy_destroyed),
## - curator's monocle: exhibits' weak points glow (WeakPointGlow), the
##   T-Rex's too (the crystal between its ribs),
## - fountain coin: RunState Dust multiplier &"coin" x1.5,
## - candle stub: a stun that lands is stretched to x1.5 (Events.hit_landed
##   comes right after the exhibit's brain took the stun),
## - wolf's tooth: the guard's sprint speed x1.2,
## - janitor's key: read by the locked door and the padlocked case.
## refresh() applies the current set; it also runs a few times a second, so
## artifacts lost at dawn or death (RunState.reset) take their effects along.

## Seconds between checks for new exhibits (monocle) and a changed set.
const SCAN_INTERVAL := 0.4

var run: NightState = null
## Who the effects are for (returns the guard or null).
var guard_source: Callable

var _sprint_base: float = -1.0
var _sprinter: Player = null
var _scan_left: float = 0.0


func _ready() -> void:
	if run == null:
		run = RunState
	Events.enemy_destroyed.connect(_on_enemy_destroyed)
	Events.hit_landed.connect(_on_hit_landed)
	refresh()


func has(id: StringName) -> bool:
	return run.has_artifact(id)


func guard() -> Player:
	return guard_source.call() as Player if guard_source.is_valid() else null


## Applies the artifacts held right now (and lifts the ones gone).
func refresh() -> void:
	if has(ArtifactCatalog.FOUNTAIN_COIN):
		run.set_multiplier(ArtifactCatalog.DUST_SOURCE, ArtifactCatalog.DUST_FACTOR)
	else:
		run.clear_multiplier(ArtifactCatalog.DUST_SOURCE)
	_apply_sprint()
	if has(ArtifactCatalog.MONOCLE):
		_light_weak_points()
	else:
		for glow in get_tree().get_nodes_in_group(&"weak_point_glow"):
			glow.queue_free()


func _process(delta: float) -> void:
	_scan_left -= delta
	if _scan_left > 0.0:
		return
	_scan_left = SCAN_INTERVAL
	refresh()


func _apply_sprint() -> void:
	var player := guard()
	if player != _sprinter:
		# a new guard (or none): forget the old one's base speed
		_restore_sprint()
		_sprinter = player
		_sprint_base = player.sprint_speed if player != null else -1.0
	if _sprinter == null:
		return
	_sprinter.sprint_speed = _sprint_base * (ArtifactCatalog.SPRINT_FACTOR if has(ArtifactCatalog.WOLF_TOOTH) else 1.0)


func _restore_sprint() -> void:
	if is_instance_valid(_sprinter) and _sprint_base > 0.0:
		_sprinter.sprint_speed = _sprint_base


func _light_weak_points() -> void:
	for node in get_tree().get_nodes_in_group(&"enemies"):
		var enemy := node as Enemy
		if enemy == null or enemy.brain.state == EnemyBrain.State.DESTROYED:
			continue
		for hurtbox in _hurtboxes(enemy):
			if hurtbox.weak_point:
				WeakPointGlow.attach(hurtbox)
	# the T-Rex's weak point is the crystal between its ribs (while it is there)
	for node in get_tree().get_nodes_in_group(&"boss"):
		var boss := node as TRex
		if boss == null or boss.skeleton == null or not is_instance_valid(boss.skeleton.crystal_hurtbox):
			continue
		var socket := boss.skeleton.crystal_hurtbox
		var lit := boss.skeleton.crystal_present and not boss.is_dead()
		if lit:
			WeakPointGlow.attach(socket)
		for child in socket.get_children():
			if child is WeakPointGlow:
				(child as WeakPointGlow).visible = lit


static func _hurtboxes(root: Node) -> Array[Hurtbox]:
	var found: Array[Hurtbox] = []
	for child in root.get_children():
		if child is Hurtbox:
			found.append(child)
		elif child.get_child_count() > 0 and not child is Enemy:
			found.append_array(_hurtboxes(child))
	return found


func _on_enemy_destroyed(_enemy: Node, info: DamageInfo, finisher: bool) -> void:
	if not finisher or info == null or not has(ArtifactCatalog.SCARAB):
		return
	var player := guard()
	if player != null and info.source == player and player.alive:
		player.heal(player.finisher_heal * ArtifactCatalog.FINISHER_HEAL_BONUS)


func _on_hit_landed(target: Node, info: DamageInfo, killed: bool) -> void:
	if killed or info == null or info.stun_time <= 0.0 or not has(ArtifactCatalog.CANDLE_STUB):
		return
	var enemy := target as Enemy
	if enemy != null and enemy.brain.is_stunned():
		enemy.brain.stun(info.stun_time * ArtifactCatalog.STUN_FACTOR)


func _exit_tree() -> void:
	_restore_sprint()
	if run != null and not has(ArtifactCatalog.FOUNTAIN_COIN):
		run.clear_multiplier(ArtifactCatalog.DUST_SOURCE)
