class_name CafeCorner
extends Node
## The court café behind the counter (plan docs/superpowers/plans/
## 2026-10-10-kawiarnia-zmeczenie.md, section 2.3). The barista's aisle
## between the counter and the back bar (LevelKit.cafe_aisle of the
## cafe_counter piece, out to the flap) is a pocket haven: a Haven node of
## its own that is NOT in the level's haven_spots, so exhibits never come
## in, do not chase a guard standing there, the weapon lowers, the music
## calms and the clock stands a while - but nobody heals or saves here (the
## six havens of the wings keep that). The flap (CafeFlap on the cafe_flap
## piece) shuts the aisle's one open end: the guard lifts it with E, it
## drops by itself once he is clear. The T-Rex fight shuts the pocket
## (Haven.set_active), or the counter would be a shelter from the boss.
## Events for the voice: cafe_entered (the first step behind the counter
## tonight; RunState.used keeps it through a resumed night), coffee_drunk
## (by kind) and cafe_haywire (the first step behind it after 3:00).
##
## Coffee (plan 2.2, 2.3): free, rationed by time only. The machine
## (CafeMachine, on the counter top, its levers to the aisle) pours an
## espresso, only for a guard on the barista's side, and heats MACHINE_WARMUP
## s between cups; the urn (CafeUrn, on the back bar) pours a large coffee
## and drips URN_DRIP s; the slate (CafeSlate) shows the night's menu. From
## 3:00 on (Events.witching_hour, or a night resumed past it) the machine
## goes haywire: its lamp flickers, it pours the special under an absurd
## label that changes with every cup, the slate changes its text. The
## guard's Fatigue does the drinking (drink()); this node only serves.

const HAVEN_ID := &"cafe"
const ENTERED := &"cafe_entered"
## RunState.used: the guard has seen the machine gone haywire tonight.
const HAYWIRE_SEEN := &"cafe_haywire"
## Seconds between looks at where the guard stands.
const CHECK := 0.1

var level: MuseumFloorLevel
## -> Player (or null).
var guard_source: Callable
var hud: Hud = null
## -> seconds of the night so far (the NightClock's elapsed), or invalid.
var clock_source: Callable
## The aisle in world space (the haven's zone).
var zone := AABB()
var haven: Haven = null
var flap: CafeFlap = null
var machine: CafeMachine = null
var urn: CafeUrn = null
var slate: CafeSlate = null
## True from 3:00: the machine pours what it likes.
var haywire := false
## Cups poured tonight (the absurd labels follow the count).
var poured := 0

var _inside := false
var _check_left := 0.0


## The flap of the counter: an Interactable on the cafe_flap piece's body.
## E lifts it (the slab turns up about its hinge along the back edge and
## folds back, the panel below swings into the aisle; the body stops
## colliding) and it drops by itself DROP_AFTER s after the guard is clear
## of it. The navmesh keeps it shut: exhibits never find a way through.
class CafeFlap extends Interactable:
	## rad (160 deg): the slab lies back over the aisle, tilted 20 deg above
	## flat - its far edge stays at ~1.3 m, under the eyes (1.6) of a guard
	## walking in (upright at 95 deg it stood across the aisle at eye height).
	const SLAB_UP := 2.793
	const PANEL_OPEN := 1.396   ## rad (80 deg): into the aisle
	## The use box reaches this high (m): a level gaze (eye 1.6) from the
	## court or the aisle finds the flap, not only a look down at its top.
	const USE_TOP := 1.9
	const LIFT_TIME := 0.45
	const DROP_TIME := 0.35
	## The guard this far (m) from the flap's box counts as clear of it.
	const CLEAR := 0.45
	const DROP_AFTER := 3.0

	var body: StaticBody3D
	var guard_source: Callable
	var size := Vector3(1.14, 1.1, 0.5)
	var opened := false
	var _slab: Node3D = null
	var _panel: Node3D = null
	var _look: Node3D = null
	var _clear_for := 0.0
	var _tween: Tween = null

	func _init() -> void:
		super()
		prompt_key = "PROMPT_CAFE_FLAP"

	## Hangs a flap on [param piece] (the cafe_flap StaticBody3D of the level).
	static func attach(piece: StaticBody3D, guard: Callable) -> CafeFlap:
		var flap := CafeFlap.new()
		flap.name = "CafeFlap"
		flap.body = piece
		flap.guard_source = guard
		flap.size = piece.get_meta(&"kit_size", flap.size)
		flap._look = piece.get_node_or_null(^"Visual") as Node3D
		if flap._look != null:
			flap._slab = flap._look.get_node_or_null(^"Slab") as Node3D
			flap._panel = flap._look.get_node_or_null(^"Panel") as Node3D
		piece.add_child(flap)
		return flap

	func _ready() -> void:
		add_box(Vector3(size.x + 0.1, USE_TOP + 0.05, size.z + 0.1), Vector3(0.0, (USE_TOP - 0.05) * 0.5, 0.0))

	func is_open() -> bool:
		return opened

	func interact(by: Node) -> void:
		if opened:
			return
		super(by)
		open()

	func open() -> void:
		if opened:
			return
		opened = true
		enabled = false
		body.collision_layer = 0
		_clear_for = 0.0
		_animate(true)
		Sfx.play_at(&"cafe_flap", body.global_position + Vector3.UP, -6.0)

	func close() -> void:
		if not opened:
			return
		opened = false
		enabled = true
		body.collision_layer = Layers.WORLD
		_animate(false)
		Sfx.play_at(&"cafe_flap", body.global_position + Vector3.UP, -4.0, 0.1, 0.9)

	func _animate(up: bool) -> void:
		if _tween != null:
			_tween.kill()
		_tween = create_tween().set_parallel(true)
		var seconds := LIFT_TIME if up else DROP_TIME
		var trans := Tween.TRANS_QUAD
		var ease_kind := Tween.EASE_OUT if up else Tween.EASE_IN
		if _slab != null:
			_tween.tween_property(_slab, "rotation:x", SLAB_UP if up else 0.0, seconds).set_trans(trans).set_ease(ease_kind)
		if _panel != null:
			_tween.tween_property(_panel, "rotation:y", -PANEL_OPEN if up else 0.0, seconds).set_trans(trans).set_ease(ease_kind)
		if _slab == null and _panel == null and _look != null:
			# the greybox block: it just slides up
			_tween.tween_property(_look, "position:y", size.y * 0.8 if up else 0.0, seconds).set_trans(trans).set_ease(ease_kind)

	## Distance (m, on the floor) of [param at] from the flap's box; 0 inside it.
	func clearance(at: Vector3) -> float:
		var local := body.global_transform.affine_inverse() * at
		var dx := maxf(absf(local.x) - size.x * 0.5, 0.0)
		var dz := maxf(absf(local.z) - size.z * 0.5, 0.0)
		return Vector2(dx, dz).length()

	func _process(delta: float) -> void:
		if not opened:
			return
		var guard: Variant = guard_source.call() if guard_source.is_valid() else null
		if not (guard is Node3D) or not is_instance_valid(guard):
			return
		if clearance((guard as Node3D).global_position) > CLEAR:
			_clear_for += delta
			if _clear_for >= DROP_AFTER:
				close()
		else:
			_clear_for = 0.0


## The espresso machine on the counter top (the boiler of the café model;
## origin at its foot, the levers toward -Z, the barista's side). E pours an
## espresso (a special after 3:00) for a guard on that side; for one in the
## court it only says where the levers are. After a cup the machine heats
## for MACHINE_WARMUP s, and its lamp shows it: warm and steady when ready,
## dim while it heats, flickering once it has gone haywire.
class CafeMachine extends Interactable:
	## The use zone around the boiler (the model's boiler stretched: ~0.5 m).
	const BOX := Vector3(0.7, 0.85, 0.7)
	const LAMP_READY := 0.6
	const LAMP_HEATING := 0.25
	const LAMP_RANGE := 3.0
	const LAMP_COLOR := Color(1.0, 0.72, 0.38)

	var corner: CafeCorner
	## Seconds of game time before the next cup.
	var cooldown_left := 0.0
	var lamp: OmniLight3D = null

	var _glow := LAMP_READY
	var _flicker_time := 0.0

	static func attach(owner_corner: CafeCorner, frame: Transform3D) -> CafeMachine:
		var machine := CafeMachine.new()
		machine.name = "CafeMachine"
		machine.corner = owner_corner
		machine.transform = frame
		owner_corner.add_child(machine)
		return machine

	func _ready() -> void:
		add_box(BOX, Vector3(0.0, BOX.y * 0.5, 0.0))
		lamp = OmniLight3D.new()
		lamp.name = "BoilerLamp"
		lamp.light_color = LAMP_COLOR
		lamp.light_energy = LAMP_READY
		lamp.omni_range = LAMP_RANGE
		lamp.shadow_enabled = false
		# a little in front of the boiler, toward the aisle (-Z)
		lamp.position = Vector3(0.0, 0.4, -0.3)
		add_child(lamp)

	func is_haywire() -> bool:
		return corner.haywire

	func prompt() -> String:
		if is_haywire():
			return tr("PROMPT_COFFEE_HAYWIRE") % Coffee.absurd_label(corner.poured)
		return tr(Coffee.prompt_key(Coffee.machine_kind(false)))

	## True when [param at] is on the side the levers face.
	func on_barista_side(at: Vector3) -> bool:
		var front := -global_transform.basis.z
		var flat := Vector3(at.x - global_position.x, 0.0, at.z - global_position.z)
		return flat.dot(front) > 0.0

	func interact(by: Node) -> void:
		super(by)
		var guard := by as Player
		if guard == null or not guard.alive:
			return
		if not on_barista_side(guard.global_position):
			corner.refuse(global_position, tr("HUD_COFFEE_OTHER_SIDE"))
			return
		if cooldown_left > 0.0:
			corner.refuse(global_position, tr("HUD_COFFEE_WARMING"))
			return
		if corner.serve(guard, Coffee.machine_kind(is_haywire())):
			cooldown_left = Coffee.MACHINE_WARMUP
			Sfx.play_at(&"espresso", global_position + Vector3.UP * 0.4, -3.0)

	## Game time passes by [param delta] seconds (_process does it by itself).
	func advance(delta: float) -> void:
		cooldown_left = maxf(cooldown_left - delta, 0.0)

	func lamp_energy() -> float:
		return lamp.light_energy if lamp != null else 0.0

	func _process(delta: float) -> void:
		advance(delta)
		if lamp == null:
			return
		var target := LAMP_HEATING if cooldown_left > 0.0 else LAMP_READY
		_glow = move_toward(_glow, target, delta * 1.5)
		if is_haywire():
			# slow and uneven (under 3 changes a second): a sick lamp, not a strobe
			_flicker_time += delta
			var wave := 0.5 + 0.25 * sin(_flicker_time * 10.7) + 0.25 * sin(_flicker_time * 6.1 + 1.3)
			lamp.light_energy = _glow * lerpf(0.25, 1.1, clampf(wave, 0.0, 1.0))
		else:
			lamp.light_energy = _glow


## The steel urn on the back bar (a cylinder with a tap, built here; origin
## at its foot, the tap toward -Z, which the marker turns to the aisle). E
## pours a large coffee; the urn then drips URN_DRIP s. After 3:00 its label
## is as absurd as the machine's; the coffee is the same.
class CafeUrn extends Interactable:
	const RADIUS := 0.115
	const HEIGHT := 0.34
	## The use zone reaches well out toward the aisle (-Z) and is wide: the
	## back bar's solid block starts just in front of the urn and would hide
	## it from a slanting look.
	const BOX := Vector3(0.7, 0.55, 0.5)
	const BOX_FORWARD := 0.12

	var corner: CafeCorner
	var cooldown_left := 0.0

	static var _materials: Dictionary = {}

	static func attach(owner_corner: CafeCorner, frame: Transform3D) -> CafeUrn:
		var urn := CafeUrn.new()
		urn.name = "CafeUrn"
		urn.corner = owner_corner
		urn.transform = frame
		owner_corner.add_child(urn)
		return urn

	func _ready() -> void:
		add_box(BOX, Vector3(0.0, BOX.y * 0.5, -BOX_FORWARD))
		_build()

	func prompt() -> String:
		if corner.haywire:
			return tr("PROMPT_COFFEE_URN_HAYWIRE") % Coffee.absurd_label(corner.poured + 2)
		return tr(Coffee.prompt_key(Coffee.LARGE))

	func interact(by: Node) -> void:
		super(by)
		var guard := by as Player
		if guard == null or not guard.alive:
			return
		if cooldown_left > 0.0:
			corner.refuse(global_position, tr("HUD_COFFEE_DRIPPING"))
			return
		if corner.serve(guard, Coffee.LARGE):
			cooldown_left = Coffee.URN_DRIP
			Sfx.play_at(&"espresso", global_position + Vector3.UP * 0.3, -8.0, 0.1, 0.8)

	func advance(delta: float) -> void:
		cooldown_left = maxf(cooldown_left - delta, 0.0)

	func _process(delta: float) -> void:
		advance(delta)

	## A steel drum on a foot, a lid with a knob, a tap (toward the marker's
	## front, -Z) with a black lever, a glass gauge.
	func _build() -> void:
		var steel := _material(&"steel")
		var dark := _material(&"dark")
		_part(CylinderMesh.new(), Vector3(0.0, 0.02, 0.0), Vector3(RADIUS * 0.8, 0.04, RADIUS * 0.8), dark)
		_part(CylinderMesh.new(), Vector3(0.0, 0.04 + (HEIGHT - 0.04) * 0.5, 0.0), Vector3(RADIUS, HEIGHT - 0.04, RADIUS), steel)
		_part(CylinderMesh.new(), Vector3(0.0, HEIGHT + 0.012, 0.0), Vector3(RADIUS * 1.04, 0.024, RADIUS * 1.04), steel)
		_part(SphereMesh.new(), Vector3(0.0, HEIGHT + 0.045, 0.0), Vector3(0.036, 0.036, 0.036), dark)
		# the tap: a short spout out of the front, a lever on top of it
		_part(BoxMesh.new(), Vector3(0.0, 0.1, -RADIUS - 0.03), Vector3(0.03, 0.03, 0.07), steel)
		_part(BoxMesh.new(), Vector3(0.0, 0.135, -RADIUS - 0.045), Vector3(0.016, 0.05, 0.016), dark)

	func _part(mesh: PrimitiveMesh, at: Vector3, size: Vector3, material: Material) -> void:
		if mesh is BoxMesh:
			(mesh as BoxMesh).size = size
		elif mesh is CylinderMesh:
			var cylinder := mesh as CylinderMesh
			cylinder.top_radius = size.x
			cylinder.bottom_radius = size.x
			cylinder.height = size.y
			cylinder.radial_segments = 16
			cylinder.rings = 1
		elif mesh is SphereMesh:
			var sphere := mesh as SphereMesh
			sphere.radius = size.x
			sphere.height = size.x * 2.0
			sphere.radial_segments = 10
			sphere.rings = 5
		var view := MeshInstance3D.new()
		view.mesh = mesh
		view.position = at
		view.material_override = material
		add_child(view)

	static func _material(id: StringName) -> StandardMaterial3D:
		if _materials.has(id):
			return _materials[id]
		var mat := StandardMaterial3D.new()
		if id == &"steel":
			mat.albedo_color = Color(0.62, 0.64, 0.66)
			mat.metallic = 0.85
			mat.roughness = 0.38
		else:
			mat.albedo_color = Color(0.07, 0.07, 0.08)
			mat.roughness = 0.6
		_materials[id] = mat
		return mat


## The chalk slate on the counter top: the night's menu in three lines of
## chalk, turned toward the court. After 3:00 the menu reads differently.
## Origin at the foot of the board; "front" is the marker's -Z.
class CafeSlate extends Node3D:
	const SIZE := Vector3(0.40, 0.30, 0.022)
	## The board leans back (rad).
	const TILT := 0.2
	const FRAME := 0.018
	const FONT_SIZE := 38
	const PIXEL_SIZE := 0.00085
	const CHALK := Color(0.84, 0.82, 0.76)

	var haywire := false
	var _label: Label3D = null

	static func attach(owner_corner: CafeCorner, frame: Transform3D) -> CafeSlate:
		var slate := CafeSlate.new()
		slate.name = "CafeSlate"
		slate.transform = frame
		owner_corner.add_child(slate)
		return slate

	## Width (m) of [param text] in the slate's chalk.
	static func text_width(text: String) -> float:
		return UiTheme.title_font().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x * PIXEL_SIZE

	func _ready() -> void:
		var board := Node3D.new()
		board.name = "Board"
		board.rotation.x = TILT
		add_child(board)
		var slate_mat := StandardMaterial3D.new()
		slate_mat.albedo_color = Color(0.08, 0.09, 0.09)
		slate_mat.roughness = 0.9
		var wood := StandardMaterial3D.new()
		wood.albedo_color = Color(0.3, 0.19, 0.1)
		wood.roughness = 0.75
		_box(board, SIZE, Vector3(0.0, SIZE.y * 0.5, 0.0), slate_mat)
		var frame_z := SIZE.z + 0.006
		_box(board, Vector3(SIZE.x + FRAME * 2.0, FRAME, frame_z), Vector3(0.0, SIZE.y + FRAME * 0.5, 0.0), wood)
		_box(board, Vector3(SIZE.x + FRAME * 2.0, FRAME, frame_z), Vector3(0.0, -FRAME * 0.5, 0.0), wood)
		_box(board, Vector3(FRAME, SIZE.y, frame_z), Vector3(-SIZE.x * 0.5 - FRAME * 0.5, SIZE.y * 0.5, 0.0), wood)
		_box(board, Vector3(FRAME, SIZE.y, frame_z), Vector3(SIZE.x * 0.5 + FRAME * 0.5, SIZE.y * 0.5, 0.0), wood)
		_label = Label3D.new()
		_label.name = "Chalk"
		_label.font = UiTheme.title_font()
		_label.font_size = FONT_SIZE
		_label.pixel_size = PIXEL_SIZE
		_label.outline_size = 0
		_label.modulate = CHALK
		_label.shaded = false
		_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_label.line_spacing = 6.0
		# Label3D reads from +Z; the slate's face is -Z
		_label.transform = Transform3D(Basis(Vector3.UP, PI), Vector3(0.0, SIZE.y * 0.5, -SIZE.z * 0.5 - 0.003))
		board.add_child(_label)
		_show()

	func set_haywire(flag: bool) -> void:
		haywire = flag
		_show()

	## The chalk lines now on the board.
	func lines() -> PackedStringArray:
		var out := PackedStringArray()
		for key in Coffee.slate_keys(haywire):
			out.append(tr(key))
		return out

	func _notification(what: int) -> void:
		if what == NOTIFICATION_TRANSLATION_CHANGED and _label != null:
			_show()

	func _show() -> void:
		if _label != null:
			_label.text = "\n".join(lines())

	static func _box(parent: Node3D, size: Vector3, at: Vector3, material: Material) -> void:
		var mesh := BoxMesh.new()
		mesh.size = size
		var view := MeshInstance3D.new()
		view.mesh = mesh
		view.position = at
		view.material_override = material
		parent.add_child(view)


## Builds the café for [param for_level] (already built): the pocket haven
## over the aisle, the flap on its piece, the machine, the urn and the slate
## on their markers. [param guard] returns the guard; [param clock] the
## seconds of the night so far (a night resumed past 3:00 starts haywire).
func setup(for_level: MuseumFloorLevel, guard: Callable, for_hud: Hud = null, clock: Callable = Callable()) -> void:
	level = for_level
	guard_source = guard
	hud = for_hud
	clock_source = clock
	name = "CafeCorner"
	var counter := _spec(&"cafe_counter")
	if counter == null:
		FloorGame.warn_once("CafeCorner: no cafe_counter in the court")
		return
	zone = aisle_zone(counter, _spec(&"cafe_flap"))
	haven = Haven.make(HAVEN_ID, zone)
	add_child(haven)
	var piece := _piece_node(&"cafe_flap")
	if piece != null:
		flap = CafeFlap.attach(piece, guard)
	else:
		FloorGame.warn_once("CafeCorner: no cafe_flap piece built")
	_serve_counter()
	Events.boss_awakened.connect(func(_boss: Node) -> void: haven.set_active(false))
	Events.boss_defeated.connect(func(_boss: Node) -> void: haven.set_active(true))
	Events.witching_hour.connect(_on_witching_hour)
	if clock.is_valid() and float(clock.call()) >= NightClock.seconds_to_witching():
		set_haywire(true)


## The aisle of [param counter] in world space, out to the far face of
## [param flap_spec] (the flap's volume belongs to the pocket).
static func aisle_zone(counter: PieceSpec, flap_spec: PieceSpec) -> AABB:
	var local := LevelKit.cafe_aisle(counter.size)
	var out := AABB(local.position + counter.position, local.size)
	if flap_spec != null:
		var far := flap_spec.footprint().end.x
		out.size.x = maxf(far - out.position.x, out.size.x)
	return out


## True while [param by] stands in the aisle and the pocket is open.
func sheltering(by: Node3D) -> bool:
	return haven != null and haven.active and by != null and haven.contains(by.global_position)


func _process(delta: float) -> void:
	_check_left -= delta
	if _check_left > 0.0 or haven == null:
		return
	_check_left = CHECK
	var guard: Variant = guard_source.call() if guard_source.is_valid() else null
	if not (guard is Player) or not is_instance_valid(guard) or not (guard as Player).alive:
		return
	var inside := sheltering(guard)
	if inside and not _inside:
		_entered()
	_inside = inside


## The machine goes haywire (or back to normal): its lamp, its cups, the slate.
func set_haywire(flag: bool) -> void:
	haywire = flag
	if slate != null:
		slate.set_haywire(flag)


## Pours [param kind] for [param guard] (Fatigue does the drinking). False
## when he cannot drink (dead, or a drink the café does not serve).
func serve(guard: Player, kind: StringName) -> bool:
	if guard == null or not guard.alive or not guard.fatigue.drink(kind):
		return false
	poured += 1
	Events.coffee_drunk.emit(kind)
	if hud != null:
		hud.show_toast(tr(Coffee.toast_key(kind)))
	return true


## A refusal: [param text] under the crosshair and a dull knock at [param at].
func refuse(at: Vector3, text: String) -> void:
	Sfx.play_at(&"deny", at, -4.0)
	Events.hint_requested.emit(text)


## The guard stepped behind the counter: once a night, the voice hears of it,
## and of the machine gone haywire when it has.
func _entered() -> void:
	if not RunState.is_used(ENTERED):
		RunState.mark_used(ENTERED)
		Events.cafe_entered.emit()
	if haywire and not RunState.is_used(HAYWIRE_SEEN):
		RunState.mark_used(HAYWIRE_SEEN)
		Events.cafe_haywire.emit()


func _on_witching_hour() -> void:
	set_haywire(true)
	# a guard already behind the counter sees it go wild on the spot
	if _inside:
		_entered()


## The machine, the urn and the slate on their markers (what is missing is
## left out with a warning).
func _serve_counter() -> void:
	var markers: Dictionary = level.markers
	if markers.has(&"cafe_machine"):
		machine = CafeMachine.attach(self, markers[&"cafe_machine"])
	if markers.has(&"cafe_urn"):
		urn = CafeUrn.attach(self, markers[&"cafe_urn"])
	if markers.has(&"cafe_slate"):
		slate = CafeSlate.attach(self, markers[&"cafe_slate"])
	if machine == null or urn == null or slate == null:
		FloorGame.warn_once("CafeCorner: a marker of the counter is missing (machine, urn or slate)")


func _exit_tree() -> void:
	# the flap hangs on the level's piece, not on this node
	if flap != null and is_instance_valid(flap) and not flap.is_queued_for_deletion():
		flap.queue_free()


func _spec(kit: StringName) -> PieceSpec:
	for piece in level.layout.pieces:
		if piece.kit == kit and piece.room == &"court":
			return piece
	return null


func _piece_node(kit: StringName) -> StaticBody3D:
	for node in get_tree().get_nodes_in_group(&"level_kit"):
		if node is StaticBody3D and level.is_ancestor_of(node) and node.get_meta(&"kit", &"") == kit:
			return node
	return null
