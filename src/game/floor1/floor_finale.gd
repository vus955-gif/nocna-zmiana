class_name FloorFinale
extends Node3D
## The end of Floor I (design 6), in the Great Court:
## ASTROLABE - the astrolabe in the Reading Room waits for the six crystal
##             shards; E with all six sets them in (flag astrolabe, saved),
## PULSING   - the crystal they make beats on the astrolabe (a later night
##             finds it beating there too),
## FLIGHT    - the guard comes within its reach: it flies out of the
##             Reading Room's door to the T-Rex on its pedestal north of
##             the drum (CrystalRoute, the open gates counted as open),
## BOSS      - it lodges between the ribs: the T-Rex wakes (its fight as
##             in the lobby), grilles drop into the court's doorways
##             (arena_trex_door_<n>), supplies appear on arena_trex_supply_
##             1-4 (5-6 at phase 2, 7-9 at phase 3), the roar calls a raptor
##             pack into a corner (arena_trex_raptor_<n>) or wax figures,
##             no rest in a haven meanwhile,
## DESCEND   - the T-Rex is dust (recorded for good: guardians_defeated has
##             &"trex", saved): the grate to the crypt opens (the gate
##             grate_crypt, saved) and the stairs into the dark wait,
## DONE      - he walked down (flag floor1_complete, saved):
##             [signal finished], the end-of-Floor-I screen.
## After the T-Rex every night is an epilogue: no boss, the grate open,
## the way down waiting.

signal finished
signal stage_changed(stage: Stage)

enum Stage { ASTROLABE, PULSING, FLIGHT, BOSS, DESCEND, DONE }

const TREX := &"trex"
const ASTROLABE_FLAG := &"astrolabe"
## The crystal hovers this high over the astrolabe's marker.
const CRYSTAL_HEIGHT := 1.3
## Seconds between the T-Rex's fall and the grate rolling aside.
const GRATE_DELAY := 2.5
## Summoned wax figures appear at least this far from the guard.
const SUMMON_DISTANCE := 8.0
const SUMMONED_DUST := 1
## The roar calls a raptor pack instead of wax figures this often.
const RAPTOR_CHANCE := 0.5
## Supplies of each phase on the arena_trex_supply_<n> markers: phase ->
## [[marker number, item]...].
const SUPPLY_MARKERS := {
	1: [[1, &"bullets"], [2, &"bullets"], [3, &"shells"], [4, &"medkit"]],
	2: [[5, &"bullets"], [6, &"medkit"]],
	3: [[7, &"bullets"], [8, &"shells"], [9, &"medkit"]],
}

var museum: Museum
var floor_game: FloorGame
var level: MuseumFloorLevel
var game: PersistentState
var run: NightState
var stage: Stage = Stage.ASTROLABE
var astrolabe: Astrolabe = null
var crystal: CrystalRelic = null
var boss: TRex = null
var exit: UndercroftExit = null


## The astrolabe in the Reading Room: E sets the six shards in.
class Astrolabe extends Interactable:
	signal filled
	var game: PersistentState
	## How high over its marker the crystal hovers: the art's ring centre
	## ("Core") when the level is dressed, else CRYSTAL_HEIGHT.
	var core_height: float = CRYSTAL_HEIGHT

	func _ready() -> void:
		add_box(Vector3(1.6, 1.6, 1.6), Vector3(0.0, 0.8, 0.0))
		# the dressed Reading Room has the astrolabe itself (Floor1Art): no
		# greybox rings then, the crystal rises to its rings' centre
		for art in get_tree().get_nodes_in_group(Floor1Art.ASTROLABE_GROUP):
			var core := (art as Node).find_child("Core", true, false) as Node3D
			if core != null:
				core_height = core.global_position.y - global_position.y
			return
		var brass := StandardMaterial3D.new()
		brass.albedo_color = Color(0.72, 0.56, 0.26)
		brass.metallic = 0.8
		brass.roughness = 0.35
		var stand := MeshInstance3D.new()
		var post := CylinderMesh.new()
		post.top_radius = 0.08
		post.bottom_radius = 0.25
		post.height = 1.0
		stand.mesh = post
		stand.position = Vector3(0.0, 0.5, 0.0)
		stand.material_override = brass
		add_child(stand)
		for tilt: float in [0.0, 0.7, -0.7]:
			var ring := MeshInstance3D.new()
			var torus := TorusMesh.new()
			torus.inner_radius = 0.42
			torus.outer_radius = 0.46
			ring.mesh = torus
			ring.position = Vector3(0.0, 1.3, 0.0)
			ring.rotation = Vector3(PI * 0.5, tilt, 0.0)
			ring.material_override = brass
			add_child(ring)

	func shards() -> int:
		return game.shards.size()

	func prompt() -> String:
		if shards() >= Floor1Plan.SHARD_COUNT:
			return tr("ASTROLABE_FILL")
		return tr("ASTROLABE_WAITS") % [shards(), Floor1Plan.SHARD_COUNT]

	func can_interact(_by: Node) -> bool:
		return enabled and not game.has_flag(ASTROLABE_FLAG)

	func interact(by: Node) -> void:
		if game.has_flag(ASTROLABE_FLAG):
			return
		if shards() < Floor1Plan.SHARD_COUNT:
			Sfx.play_at(&"deny", global_position + Vector3.UP, -6.0)
			return
		game.set_flag(ASTROLABE_FLAG)
		super(by)
		filled.emit()


func setup(for_game: FloorGame) -> void:
	floor_game = for_game
	museum = floor_game.museum
	level = museum.floor_level
	game = museum.game
	run = museum.run
	name = "Finale"
	var exit_at: Variant = floor_game.marker(Floor1Plan.EXIT_MARKER)
	if exit_at != null:
		exit = UndercroftExit.new()
		exit.name = "Floor1Exit"
		exit.position = (exit_at as Transform3D).origin
		exit.entered_by_guard.connect(_on_exit_entered)
		add_child(exit)
	if game.is_guardian_defeated(TREX):
		_epilogue()
		return
	var astrolabe_at: Variant = floor_game.marker(&"astrolabe")
	if astrolabe_at != null:
		astrolabe = Astrolabe.new()
		astrolabe.name = "Astrolabe"
		astrolabe.game = game
		astrolabe.transform = astrolabe_at
		astrolabe.filled.connect(_on_astrolabe_filled)
		add_child(astrolabe)
	var pedestal: Variant = floor_game.marker(Floor1Plan.TREX_MARKER)
	if pedestal != null:
		boss = TRex.new()
		boss.name = "TRex"
		var at: Transform3D = pedestal
		boss.position = at.origin + Vector3.UP * 0.05
		boss.rotation.y = at.basis.get_euler().y
		boss.target = museum.player
		boss.summon = summon
		boss.phase_changed.connect(_on_boss_phase)
		boss.defeated.connect(_on_boss_defeated)
		add_child(boss)
	if game.has_flag(ASTROLABE_FLAG):
		_pulse(true)
	else:
		_set_stage(Stage.ASTROLABE)


## True while the T-Rex fights (no rest in a haven).
func fighting() -> bool:
	return stage == Stage.BOSS


## Dawn: the T-Rex stops dead and greys over.
func freeze() -> void:
	if not is_instance_valid(boss):
		return
	boss.process_mode = Node.PROCESS_MODE_DISABLED
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color(0.5, 0.49, 0.47)
	stone.roughness = 0.95
	for node in boss.find_children("*", "GeometryInstance3D", true, false):
		(node as GeometryInstance3D).material_override = stone


func _set_stage(next: Stage) -> void:
	stage = next
	stage_changed.emit(next)


func _on_astrolabe_filled() -> void:
	Sfx.play_at(&"crystal_rise", astrolabe.global_position + Vector3.UP, 0.0)
	Events.shake_requested.emit(0.2)
	museum.hud.show_card(tr("ASTROLABE_TITLE"), tr("ASTROLABE_FILLED"), tr("ASTROLABE_FILLED_DETAIL"))
	NightRules.save_progress(game, run)
	_pulse(false)


## The crystal beats on the astrolabe, waiting for the guard.
func _pulse(_resumed: bool) -> void:
	if astrolabe == null or not is_instance_valid(boss):
		return
	crystal = CrystalRelic.new()
	crystal.name = "Crystal"
	crystal.position = astrolabe.global_position + Vector3.UP * astrolabe.core_height
	crystal.guard = museum.player
	crystal.burst_out.connect(_on_crystal_burst)
	crystal.arrived.connect(_on_crystal_arrived)
	add_child(crystal)
	crystal.start_pulsing()
	run.crystal_phase = NightState.CrystalPhase.PULSING
	_set_stage(Stage.PULSING)


func _on_crystal_burst() -> void:
	var layout := level.layout
	var start_room := layout.room_at(crystal.global_position)
	var closed: Array[StringName] = []
	if museum.night.locked_door != &"":
		closed.append(museum.night.locked_door)
	var opened: Array[StringName] = []
	for gate in layout.gates:
		if gate.opening != &"" and game.is_gate_open(gate.id):
			opened.append(gate.opening)
	var boss_room := layout.room_at(boss.global_position + Vector3.UP)
	var socket := boss.skeleton.crystal_position()
	var path := crystal_path(crystal.global_position, socket)
	if path.is_empty():
		path = CrystalRoute.build(layout, crystal.global_position, start_room, boss_room, socket, closed, opened)
	crystal.fly(path)
	run.crystal_phase = NightState.CrystalPhase.FLYING
	_set_stage(Stage.FLIGHT)


func _on_crystal_arrived() -> void:
	var at := crystal.global_position
	crystal.queue_free()
	crystal = null
	Fx.flash(at, CrystalRelic.RED, 8.0, 14.0, 0.5)
	Events.shake_requested.emit(0.5)
	run.crystal_phase = NightState.CrystalPhase.EMBEDDED
	boss.wake()
	_set_stage(Stage.BOSS)
	if floor_game.guardians.seal_arena(TREX) > 0:
		museum.hud.show_toast(tr("HUD_COURT_SEALED"))
	_on_boss_phase(1)


## The crystal's flight along the court's crystal_path_<n> markers: up out
## of the astrolabe, the markers in order, into the ribs ([] when the
## court has no such markers).
func crystal_path(from: Vector3, socket: Vector3) -> PackedVector3Array:
	var points := PackedVector3Array()
	for i in range(1, 10):
		var id := StringName("crystal_path_%d" % i)
		if not level.markers.has(id):
			break
		points.append((level.markers[id] as Transform3D).origin)
	if points.is_empty():
		return points
	points.insert(0, from + Vector3.UP * CrystalRoute.LIFT)
	points.append(socket)
	return points


func _on_boss_phase(phase: int) -> void:
	var keeper := floor_game.guardians
	var key := GuardianKeeper.supplies_id(TREX, phase)
	if level.markers.has(&"arena_trex_supply_1"):
		if run.is_used(key):
			return
		run.mark_used(key)
		for entry: Array in SUPPLY_MARKERS.get(phase, []):
			var id := StringName("arena_trex_supply_%d" % int(entry[0]))
			if level.markers.has(id):
				keeper._supply(entry[1], (level.markers[id] as Transform3D).origin)
		return
	var court := level.layout.room_at(boss.global_position + Vector3.UP)
	keeper.drop_supplies_at(key, boss.global_position + Vector3(0.0, 0.0, 10.0), phase, court)


## The roar's call: with RAPTOR_CHANCE a raptor pack runs in at a free
## corner away from the guard (arena_trex_raptor_<n>), else wax figures of
## the court wake and new ones step out on its spawn slots.
func summon(count: int) -> Array[Enemy]:
	if count <= 0:
		return []
	if run.rng.randf() < RAPTOR_CHANCE:
		var pack := summon_raptors(count)
		if not pack.is_empty():
			return pack
	return summon_wax(count)


## A pack (awake, summoned) at one of the raptor markers: a free one at
## least SUMMON_DISTANCE m from the guard, else the farthest free one.
func summon_raptors(count: int) -> Array[Enemy]:
	var guard := museum.player.global_position
	var free: Array[Vector3] = []
	for i in range(1, 10):
		var id := StringName("arena_trex_raptor_%d" % i)
		if not level.markers.has(id):
			break
		var spot: Vector3 = (level.markers[id] as Transform3D).origin
		if not _occupied(spot, RaptorPack.SPREAD + 0.8):
			free.append(spot)
	if free.is_empty():
		return []
	var far: Array[Vector3] = []
	var farthest := free[0]
	for spot in free:
		if spot.distance_to(guard) >= SUMMON_DISTANCE:
			far.append(spot)
		if spot.distance_to(guard) > farthest.distance_to(guard):
			farthest = spot
	var at: Vector3 = far[run.rng.randi_range(0, far.size() - 1)] if not far.is_empty() else farthest
	var called: Array[Enemy] = []
	for raptor in NightSpawner.pack(at, 0.0, clampi(count, 1, RaptorPack.MAX_SIZE)):
		raptor.target = museum.player
		raptor.dust_value = SUMMONED_DUST
		raptor.summoned = true
		museum._tune_exhibit(raptor)
		museum.enemies_root.add_child(raptor)
		raptor.brain.wake()
		raptor.face(guard)
		called.append(raptor)
	Fx.impact(at + Vector3.UP, Vector3.UP, ExhibitMaterial.Kind.BONE, 2.0)
	return called


func _occupied(spot: Vector3, radius: float) -> bool:
	for exhibit in museum.exhibits():
		if exhibit.global_position.distance_to(spot) < radius:
			return true
	return false


## Wax figures of the court wake, new ones step out on its spawn slots
## away from the guard.
func summon_wax(count: int) -> Array[Enemy]:
	var called: Array[Enemy] = []
	var court := level.layout.room_at(boss.global_position + Vector3.UP)
	for exhibit in museum.exhibits():
		if called.size() >= count:
			break
		if exhibit is WaxFigure and exhibit.brain.state == EnemyBrain.State.DORMANT and exhibit.home_room == court:
			exhibit.summoned = true
			exhibit.brain.wake()
			called.append(exhibit)
	for slot in level.spawn_slots:
		if called.size() >= count:
			break
		if slot.room != court or slot.position.distance_to(museum.player.global_position) < SUMMON_DISTANCE:
			continue
		var wax := WaxFigure.new()
		wax.position = slot.position + Vector3.UP * 0.05
		wax.target = museum.player
		wax.dust_value = SUMMONED_DUST
		wax.summoned = true
		museum._tune_exhibit(wax)
		museum.enemies_root.add_child(wax)
		wax.brain.wake()
		wax.face(museum.player.global_position)
		Fx.impact(slot.position + Vector3.UP, Vector3.UP, ExhibitMaterial.Kind.WAX, 1.5)
		called.append(wax)
	return called


func _on_boss_defeated() -> void:
	if museum.night_over() or not run.running:
		return   # a fall after dawn or death changes nothing
	game.defeat_guardian(TREX)
	game.stats["bosses"] = int(game.stats["bosses"]) + 1
	run.crystal_phase = NightState.CrystalPhase.BROKEN
	NightRules.save_progress(game, run)
	_set_stage(Stage.DESCEND)
	floor_game.guardians.unseal_arena(TREX)
	if museum.watch != null:
		museum.watch.running = false   # the T-Rex ends the night, not the dawn
	await _wait(GRATE_DELAY)
	floor_game.gates.open_gate(&"grate_crypt")
	museum.hud.show_toast(tr("HUD_GRATE_OPEN"))
	if exit != null:
		exit.armed = true


## A night after the T-Rex: the grate open, the way down waiting.
func _epilogue() -> void:
	run.crystal_phase = NightState.CrystalPhase.BROKEN
	if not game.is_gate_open(&"grate_crypt"):
		floor_game.gates.open_gate(&"grate_crypt")
	if exit != null:
		exit.armed = true
	_set_stage(Stage.DESCEND)


func _on_exit_entered(_player: Player) -> void:
	if stage != Stage.DESCEND:
		return
	_set_stage(Stage.DONE)
	game.set_flag(ProgressRules.COMPLETE_FLAG)
	NightRules.save_progress(game, run)
	finished.emit()


func _wait(seconds: float) -> void:
	var timer := Timer.new()
	timer.one_shot = true
	add_child(timer)
	timer.start(seconds)
	await timer.timeout
	timer.queue_free()
