class_name GateLock
extends Node3D
## A gate of the museum floor that a tool opens (design 4.2): a chain, a
## boarded-up doorway, a cracked wall, a rope holding a counterweight, an
## iron hook ring, a door bolted from one side, a powered fire shutter.
## Every lock speaks one language: its look, its sound and its line under
## the crosshair ("[E] Chain - break it with something heavy..."). The
## right tool opens it with a satisfying break (debris through Fx, a sound,
## a camera shake); a wrong one only strikes sparks (or dust, splinters),
## jolts it and shows the hint (Events.hint_requested, at most every
## HINT_COOLDOWN seconds). What breaks what: LockRules.
##
## Contract (the save/progress code wires it):
## - [member gate_id]: the gate's id in the floor's progress;
## - [signal opened]: once, when it opens in play;
## - open_instantly(): it was open in the save: open state at once, no
##   effects, no signal;
## - blocks_passage(): its body still blocks the way.
## Place it with its origin on the floor in the middle of the opening, -Z
## (its front) toward the guard; [member size] = opening width x height.
## Subclasses set [member kind] in _init() and build in _build_body().

signal opened

enum Kind { CHAIN, BOARDS, CRACKED, ROPE, HOOK, BOLT, POWER }

## A wrong tool shows its hint at most this often (s).
const HINT_COOLDOWN := 4.0
## The hit zone and the prompt reach this far out of the body, so shots
## and the use-probe meet them first.
const ZONE_MARGIN := 0.08

@export var gate_id: StringName = &""
## Opening width x height (m).
@export var size := Vector2(2.0, 2.6)

var kind: Kind = Kind.CHAIN
var is_open: bool = false
var tally: LockTally
## The body that blocks the way (null for locks that block nothing).
var blocker: StaticBody3D = null
## Hit zones (shots and blasts land here).
var zones: Array[Hurtbox] = []
## The use-probe's target (the line under the crosshair).
var prompt_area: LockPrompt = null

var _clock: float = 0.0
var _hint_wait: float = 0.0
## 0..1: how hard the lock still shakes from the last hit.
var _jolt: float = 0.0
var _built: bool = false


func _ready() -> void:
	tally = LockRules.tally_for(kind)
	_build_body()
	_built = true
	if is_open:
		_show_open(false)


func _physics_process(delta: float) -> void:
	_clock += delta
	_hint_wait = maxf(_hint_wait - delta, 0.0)


func _process(delta: float) -> void:
	if _jolt > 0.0 and not is_open:   # (an opening animation owns the pieces)
		_jolt = maxf(_jolt - delta * 3.0, 0.0)
		_animate_jolt(_jolt)


## Already open in the save: the open state at once, no effects, no signal.
func open_instantly() -> void:
	is_open = true
	if _built:
		_show_open(false)


## Opens with its break or animation and emits [signal opened] (once).
func open() -> void:
	if is_open:
		return
	is_open = true
	_break()
	if _built:
		_show_open(true)
	opened.emit()


## True while its body still blocks the way.
func blocks_passage() -> bool:
	return not is_open and blocker != null


## A weapon hit one of its zones.
func take_damage(info: DamageInfo) -> void:
	if is_open or info == null:
		return
	match LockRules.verdict(kind, info):
		LockRules.Verdict.OPEN:
			open()
		LockRules.Verdict.SUM:
			if tally.feed(info.amount, _clock):
				open()
			else:
				_on_give(info, 0.6)
		LockRules.Verdict.STRIKE:
			if tally.strike():
				open()
			else:
				_on_give(info, 1.0)
				_hint(tr("LOCK_CREAKS") % [tally.strikes, tally.need_strikes], true)
		_:
			_on_wrong(info)


## The line under the crosshair.
func prompt_text() -> String:
	return tr(LockRules.prompt_key(kind))


func can_use(_by: Node) -> bool:
	return not is_open


## E on the lock: it will not give by hand (a rattle and the hint).
func use(_by: Node) -> void:
	_jolt = maxf(_jolt, 0.7)
	_play_rattle()
	_hint(prompt_text(), true)


## Shows [param text] under the crosshair (not more often than
## HINT_COOLDOWN unless [param force]).
func _hint(text: String, force: bool = false) -> void:
	if _hint_wait > 0.0 and not force:
		return
	_hint_wait = HINT_COOLDOWN
	Events.hint_requested.emit(text)


## A hit that counts but is not enough yet: the lock gives a little.
func _on_give(info: DamageInfo, strength: float) -> void:
	_jolt = maxf(_jolt, strength)
	_wrong_effect(info, true)


## A hit with the wrong tool: sparks (or dust), a jolt, the hint.
func _on_wrong(info: DamageInfo) -> void:
	if info.periodic:
		return
	_jolt = maxf(_jolt, 0.4)
	_wrong_effect(info, false)
	_hint(tr(LockRules.wrong_hint_key(kind, info)))


# --- subclass hooks ---

## Builds the look, the blocking body, the hit zones and the prompt.
func _build_body() -> void:
	pass


## The break (effects only: debris, sound, shake).
func _break() -> void:
	pass


## The open state: pieces hidden or moved aside (moving there with
## [param animated], at once without), the body no longer in the way.
func _show_open(_animated: bool) -> void:
	if blocker != null:
		blocker.collision_layer = 0
	for zone in zones:
		zone.collision_layer = 0
	if prompt_area != null:
		prompt_area.collision_layer = 0


## What a hit that does not open it shows (sparks, dust, splinters) and
## sounds like; [param counts]: it counted toward opening.
func _wrong_effect(info: DamageInfo, _counts: bool) -> void:
	Fx.impact(info.position, info.normal, ExhibitMaterial.Kind.METAL, 0.8)
	Sfx.play_at(&"hit_metal", info.position, -3.0)


func _play_rattle() -> void:
	Sfx.play_at(&"chain_clank", global_position + Vector3.UP, -4.0)


## The lock shaking ([param amount] 0..1, dying down).
func _animate_jolt(_amount: float) -> void:
	pass


# --- building helpers ---

## The blocking body: a box of [param box_size] centred at [param center].
func _add_blocker(box_size: Vector3, center: Vector3) -> StaticBody3D:
	blocker = StaticBody3D.new()
	blocker.name = "Blocker"
	blocker.collision_layer = Layers.WORLD
	blocker.collision_mask = 0
	var shape := BoxShape3D.new()
	shape.size = box_size
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position = center
	blocker.add_child(collider)
	add_child(blocker)
	return blocker


## A hit zone of [param box_size] centred at [param center] (under
## [param parent], this lock by default). Blasts check their line to a
## zone's centre: keep it outside any solid body.
func _add_zone(box_size: Vector3, center: Vector3, parent: Node3D = null) -> Hurtbox:
	var shape := BoxShape3D.new()
	shape.size = box_size
	var zone := Hurtbox.make(self, shape, center)
	zone.name = "Zone%d" % zones.size()
	(parent if parent != null else self).add_child(zone)
	zones.append(zone)
	return zone


## Hit zones as two slabs just in front of and behind a body of
## [param box_size] at [param center] (so a blast's line to them stays
## clear of the body).
func _add_face_zones(box_size: Vector3, center: Vector3) -> void:
	var slab := Vector3(box_size.x + ZONE_MARGIN * 2.0, box_size.y + ZONE_MARGIN * 2.0, 0.12)
	var offset := box_size.z * 0.5 + 0.06
	_add_zone(slab, center + Vector3(0.0, 0.0, -offset))
	_add_zone(slab, center + Vector3(0.0, 0.0, offset))


## The use-probe's target: a box of [param box_size] at [param center].
func _add_prompt(box_size: Vector3, center: Vector3) -> LockPrompt:
	prompt_area = LockPrompt.new()
	prompt_area.name = "Prompt"
	prompt_area.lock = self
	prompt_area.add_box(box_size + Vector3.ONE * ZONE_MARGIN * 2.0, center)
	add_child(prompt_area)
	return prompt_area
