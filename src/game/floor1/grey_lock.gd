class_name GreyLock
extends Node3D
## A greybox stand-in for a gate lock of Floor I (design 4.2) with the
## GateLock contract of the p1-weapons branch, used for every kind whose
## real lock class is not in the build (GateLocks): [member gate_id],
## [member size], [signal opened] (once, in play), open_instantly() (the
## save's state: no effects, no signal), open(), blocks_passage(),
## [member is_open], power_on(). The Door of the passage stays the solid
## part (and cuts the navigation) - this adds the lock's look on its faces,
## the hit zones and the line under the crosshair.
## What opens it follows the real locks' rules (LockRules on p1-weapons):
## CHAIN - shotgun hits summing 25 within 0.4 s, or 3 punches;
## BOARDS - a blast, shotgun 25 within 0.4 s, or 5 punches;
## CRACKED - blasts summing 40 within 0.3 s, or 3 flares from within 5 m;
## ROPE - the rifle from anywhere, the pistol from within 15 m (when the
## gate asks for the rifle itself, the rifle only);
## HOOK - the harpoon; BOLT - E from the bolt's side (+Z); POWER -
## power_on(). Anything else strikes sparks and shows the gate's line.
## Origin on the floor in the middle of the opening, -Z (its front) toward
## the room the guard comes from; a BOLT's bolt is on its back (+Z).

signal opened

## Hits within this many seconds add up (CHAIN / BOARDS; CRACKED 0.3).
const SUM_WINDOW := 0.4
const CHAIN_SUM := 25.0
const CHAIN_PUNCHES := 3
const BOARDS_PUNCHES := 5
const CRACKED_SUM := 40.0
const CRACKED_WINDOW := 0.3
const CRACKED_FLARES := 3
const FLARE_POINT_BLANK := 5.0
const ROPE_PISTOL_RANGE := 15.0
## The faces' hit zones stand this far out of the middle of the opening.
const FACE_OUT := 0.32
## Seconds between two lines under the crosshair for wrong hits.
const HINT_COOLDOWN := 4.0
const IRON := Color(0.26, 0.25, 0.24)
const BRASS := Color(0.78, 0.6, 0.28)
const WOOD := Color(0.42, 0.29, 0.17)
const STONE := Color(0.55, 0.53, 0.5)
const ROPE_COLOR := Color(0.62, 0.52, 0.34)
const RED := Color(1.0, 0.12, 0.06)
const GREEN := Color(0.25, 1.0, 0.35)

var gate_id: StringName = &""
## Opening width x height (m).
var size := Vector2(2.0, 2.6)
var kind: GateSpec.Kind = GateSpec.Kind.CHAIN
## The gate's requirement (GateSpec tokens; ROPE: &"rifle_hunt" = rifle only).
var requirement: StringName = GateSpec.NONE
## Translation key of the line under the crosshair (GateSpec.label_key).
var label_key: StringName = &""
var is_open: bool = false
## Punches, flares... counted so far, and the hits of the current window.
var strikes: int = 0
var prompt_area: Interactable = null
var zones: Array[Hurtbox] = []

var _look: Node3D
var _hits: Array = []
var _clock: float = 0.0
var _hint_wait: float = 0.0
var _lamps: Array[MeshInstance3D] = []


## The line under the crosshair of a lock (the gate's own words).
class Prompt extends Interactable:
	var lock: GreyLock = null

	func prompt() -> String:
		return lock.prompt_text() if lock != null else ""

	func can_interact(_by: Node) -> bool:
		return enabled and lock != null and not lock.is_open

	func interact(by: Node) -> void:
		if lock != null:
			lock.use(by)
		super(by)


static func make(gate_kind: GateSpec.Kind) -> GreyLock:
	var lock := GreyLock.new()
	lock.kind = gate_kind
	lock.name = "GreyLock"
	return lock


func _ready() -> void:
	_look = Node3D.new()
	_look.name = "Look"
	add_child(_look)
	_build_look()
	_build_zones()
	prompt_area = Prompt.new()
	prompt_area.name = "Prompt"
	prompt_area.lock = self
	prompt_area.add_box(Vector3(size.x, size.y, FACE_OUT * 2.0 + 0.2), Vector3(0.0, size.y * 0.5, 0.0))
	add_child(prompt_area)
	if is_open:
		_show_open()


func _physics_process(delta: float) -> void:
	_clock += delta
	_hint_wait = maxf(_hint_wait - delta, 0.0)


## Open in the save: the open state at once, no effects, no signal.
func open_instantly() -> void:
	is_open = true
	if is_inside_tree():
		_show_open()


## Opens with its break and emits [signal opened] (once).
func open() -> void:
	if is_open:
		return
	is_open = true
	if is_inside_tree():
		_break()
		_show_open()
	opened.emit()


## The Door of the passage is the solid part: the stand-in blocks nothing.
func blocks_passage() -> bool:
	return false


## Power is back (the switchboard): a shutter rolls up.
func power_on() -> void:
	if kind == GateSpec.Kind.POWER:
		open()


func prompt_text() -> String:
	if kind == GateSpec.Kind.BOLT and on_bolt_side(_guard()):
		return tr("PROMPT_DRAW_BOLT")
	return tr(label_key) if label_key != &"" else ""


## E on the lock: a bolt drawn from its side, everything else rattles.
func use(by: Node) -> void:
	if is_open:
		return
	if kind == GateSpec.Kind.BOLT and on_bolt_side(by):
		open()
		return
	Sfx.play_at(&"chain_clank" if kind == GateSpec.Kind.CHAIN else &"hit_metal", global_position + Vector3.UP * 1.2, -6.0)
	_hint(true)


## True when [param by] stands on the bolt's side (+Z) of the door.
func on_bolt_side(by: Node) -> bool:
	var body := by as Node3D
	if body == null or not is_inside_tree():
		return false
	return (body.global_position - global_position).dot(global_basis.z) > 0.0


## A weapon hit one of its zones.
func take_damage(info: DamageInfo) -> void:
	if is_open or info == null or info.periodic:
		return
	match verdict(info):
		&"open":
			open()
		&"sum":
			if _feed(info.amount, CRACKED_WINDOW if kind == GateSpec.Kind.CRACKED else SUM_WINDOW) >= _need_sum():
				open()
			else:
				_give(info)
		&"strike":
			strikes += 1
			if strikes >= _need_strikes():
				open()
			else:
				_give(info)
		_:
			_wrong(info)


## What [param info] does to this lock: &"open", &"sum" (adds up),
## &"strike" (counts as a blow) or &"wrong".
func verdict(info: DamageInfo) -> StringName:
	var blast := is_blast(info)
	match kind:
		GateSpec.Kind.CHAIN:
			if info.weapon == &"shotgun":
				return &"sum"
			if info.weapon == &"fists":
				return &"strike"
		GateSpec.Kind.BOARDS:
			if blast:
				return &"open"
			if info.weapon == &"shotgun":
				return &"sum"
			if info.weapon == &"fists":
				return &"strike"
		GateSpec.Kind.CRACKED:
			if info.weapon == &"flare" and blast:
				return &"strike" if fired_within(info, FLARE_POINT_BLANK) else &"wrong"
			if blast:
				return &"sum"
		GateSpec.Kind.ROPE:
			if info.weapon == &"rifle_hunt":
				return &"open"
			if info.weapon == &"pistol" and requirement != &"rifle_hunt" and fired_within(info, ROPE_PISTOL_RANGE):
				return &"open"
		GateSpec.Kind.HOOK:
			if info.weapon == &"harpoon":
				return &"open"
	return &"wrong"


## A blast: DamageInfo.explosive (the p1-weapons branch) or the flare gun's
## fire.
static func is_blast(info: DamageInfo) -> bool:
	var explosive: Variant = info.get(&"explosive")
	if explosive is bool and explosive:
		return true
	return info.weapon == &"flare" and info.kind == DamageInfo.Kind.FIRE


## True when the shot was fired within [param metres] of where it landed
## (DamageInfo.origin when the build has it, else the shooter's place).
static func fired_within(info: DamageInfo, metres: float) -> bool:
	var origin: Variant = info.get(&"origin")
	var from := Vector3.INF
	if origin is Vector3 and origin != Vector3.INF:
		from = origin
	elif is_instance_valid(info.source) and info.source is Node3D:
		from = (info.source as Node3D).global_position
	return from != Vector3.INF and from.distance_to(info.position) <= metres


func _need_sum() -> float:
	return CRACKED_SUM if kind == GateSpec.Kind.CRACKED else CHAIN_SUM


func _need_strikes() -> int:
	match kind:
		GateSpec.Kind.BOARDS:
			return BOARDS_PUNCHES
		GateSpec.Kind.CRACKED:
			return CRACKED_FLARES
	return CHAIN_PUNCHES


## Adds a hit to the window; the sum of the hits in it.
func _feed(amount: float, window: float) -> float:
	_hits.append([_clock, amount])
	while not _hits.is_empty() and float(_hits[0][0]) < _clock - window - 0.0001:
		_hits.pop_front()
	var total := 0.0
	for hit: Array in _hits:
		total += float(hit[1])
	return total


func _guard() -> Node:
	return get_tree().get_first_node_in_group(&"player") if is_inside_tree() else null


## A hit that counts but is not enough yet.
func _give(info: DamageInfo) -> void:
	match kind:
		GateSpec.Kind.BOARDS:
			Sfx.play_at(&"lock_boards_hit", info.position, -2.0)
		GateSpec.Kind.CRACKED:
			Sfx.play_at(&"lock_wall_crack", info.position, -2.0)
		_:
			Sfx.play_at(&"chain_clank", info.position, -2.0)
	var material: int = -1
	if kind == GateSpec.Kind.CHAIN:
		material = ExhibitMaterial.Kind.METAL
	Fx.impact(info.position, info.normal, material, 0.7)


## A hit with the wrong tool: sparks or dust, and the gate's line.
func _wrong(info: DamageInfo) -> void:
	Fx.impact(info.position, info.normal, ExhibitMaterial.Kind.METAL, 0.6)
	Sfx.play_at(&"hit_metal", info.position, -5.0)
	_hint(false)


## The gate's line as a hint (Events.hint_requested where the build has it).
func _hint(force: bool) -> void:
	if (_hint_wait > 0.0 and not force) or not Events.has_signal(&"hint_requested"):
		return
	_hint_wait = HINT_COOLDOWN
	Events.emit_signal(&"hint_requested", prompt_text())


## The break: its sound and a few pieces.
func _break() -> void:
	var middle := global_position + Vector3.UP * size.y * 0.5
	match kind:
		GateSpec.Kind.CHAIN:
			Sfx.play_at(&"lock_chain_break", middle)
			_debris(IRON, 8)
		GateSpec.Kind.BOARDS:
			Sfx.play_at(&"lock_boards_splinter", middle)
			_debris(WOOD, 10)
		GateSpec.Kind.CRACKED:
			Sfx.play_at(&"lock_wall_collapse", middle)
			_debris(STONE, 14)
			Events.shake_requested.emit(0.25)
		GateSpec.Kind.ROPE:
			Sfx.play_at(&"lock_rope_snap", global_position + Vector3.UP * size.y)
			Sfx.play_at(&"lock_counterweight", middle, -3.0)
		GateSpec.Kind.HOOK:
			Sfx.play_at(&"lock_hook_pull", middle)
		GateSpec.Kind.BOLT:
			Sfx.play_at(&"lock_bolt_slide", middle)
		GateSpec.Kind.POWER:
			Sfx.play_at(&"lock_shutter_roll", global_position + Vector3.UP * size.y)
	for lamp in _lamps:
		lamp.material_override = _material(GREEN, true)


func _debris(color: Color, count: int) -> void:
	var front := -global_basis.z
	for i in count:
		var at := global_position + global_basis * Vector3(randf_range(-0.45, 0.45) * size.x, randf_range(0.2, 0.9) * size.y, -FACE_OUT)
		Fx.chunk(at, color, randf_range(0.05, 0.12), front * randf_range(1.0, 3.0) + Vector3(randf_range(-1.0, 1.0), randf_range(0.5, 2.0), randf_range(-1.0, 1.0)))


## Open: the look and the zones go (a shutter's lamps turn green).
func _show_open() -> void:
	for zone in zones:
		zone.collision_layer = 0
	if prompt_area != null:
		prompt_area.collision_layer = 0
	if _look == null:
		return
	for child in _look.get_children():
		if not _lamps.has(child):
			(child as Node3D).visible = false
	for lamp in _lamps:
		lamp.material_override = _material(GREEN, true)


func _build_zones() -> void:
	var height := size.y
	match kind:
		GateSpec.Kind.ROPE:
			# the rope hangs in front of the opening, over the guard's head
			var zone := Vector3(0.4, height * 0.4, 0.4)
			_zone(zone, Vector3(0.0, height * 0.75, -FACE_OUT - 0.2))
		GateSpec.Kind.HOOK:
			_zone(Vector3(0.7, 0.7, 0.3), Vector3(0.0, minf(1.6, height * 0.6), -FACE_OUT))
		GateSpec.Kind.BOLT, GateSpec.Kind.POWER:
			pass   # no weapon does anything; the prompt takes E
		_:
			for side: float in [-1.0, 1.0]:
				_zone(Vector3(size.x, height, 0.16), Vector3(0.0, height * 0.5, side * FACE_OUT))


func _zone(box: Vector3, at: Vector3) -> void:
	var shape := BoxShape3D.new()
	shape.size = box
	var zone := Hurtbox.make(self, shape, at)
	zone.name = "Zone%d" % zones.size()
	add_child(zone)
	zones.append(zone)


## The greybox look on the faces (the Door between them is the rest).
func _build_look() -> void:
	var w := size.x
	var h := size.y
	match kind:
		GateSpec.Kind.CHAIN:
			for side: float in [-1.0, 1.0]:
				var z := side * (FACE_OUT - 0.08)
				for tilt: float in [-0.6, 0.6]:
					_box(Vector3(minf(w, 2.2), 0.07, 0.07), Vector3(0.0, 1.1, z), IRON, tilt)
				_box(Vector3(0.18, 0.22, 0.09), Vector3(0.0, 0.95, z + side * 0.05), BRASS)
		GateSpec.Kind.BOARDS:
			for side: float in [-1.0, 1.0]:
				var z := side * (FACE_OUT - 0.06)
				for i in 4:
					var y := h * (0.2 + i * 0.2)
					_box(Vector3(w + 0.3, 0.22, 0.05), Vector3(0.0, y, z), WOOD, 0.12 if i % 2 == 0 else -0.1)
		GateSpec.Kind.CRACKED:
			for side: float in [-1.0, 1.0]:
				var z := side * (FACE_OUT - 0.05)
				for i in 5:
					_box(Vector3(0.05, h * 0.35, 0.03), Vector3(-w * 0.3 + i * w * 0.15, h * (0.3 + 0.08 * (i % 3)), z), Color(0.12, 0.11, 0.1), 0.4 - i * 0.2)
		GateSpec.Kind.ROPE:
			var top := h + 1.5
			_box(Vector3(0.04, top - h * 0.55, 0.04), Vector3(0.0, (top + h * 0.55) * 0.5, -FACE_OUT - 0.2), ROPE_COLOR)
			_box(Vector3(0.36, 0.42, 0.36), Vector3(0.0, h * 0.55 - 0.21, -FACE_OUT - 0.2), IRON)
		GateSpec.Kind.HOOK:
			var y := minf(1.6, h * 0.6)
			for i in 4:
				var angle := i * PI * 0.5
				_box(Vector3(0.36, 0.06, 0.06), Vector3(cos(angle) * 0.18, y + sin(angle) * 0.18, -FACE_OUT), IRON, angle + PI * 0.5)
		GateSpec.Kind.BOLT:
			_box(Vector3(0.36, 0.05, 0.05), Vector3(w * 0.25, h * 0.5, FACE_OUT - 0.08), Color(0.6, 0.6, 0.62))
			_box(Vector3(0.08, 0.1, 0.06), Vector3(w * 0.45, h * 0.5, FACE_OUT - 0.08), IRON)
		GateSpec.Kind.POWER:
			for side: float in [-1.0, 1.0]:
				var lamp := _box(Vector3(0.12, 0.12, 0.06), Vector3(w * 0.5 + 0.25, 2.0, side * (FACE_OUT - 0.05)), RED, 0.0, true)
				_lamps.append(lamp)


func _box(box: Vector3, at: Vector3, color: Color, roll: float = 0.0, glow: bool = false) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = box
	var view := MeshInstance3D.new()
	view.mesh = mesh
	view.position = at
	view.rotation.z = roll
	view.material_override = _material(color, glow)
	_look.add_child(view)
	return view


static func _material(color: Color, glow: bool = false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.6
	if glow:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = 2.0
	return material
