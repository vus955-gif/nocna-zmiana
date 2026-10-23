class_name FloorGame
extends Node3D
## Floor I's own game (stage P1, workstream W1), installed by the Museum
## with one call when it plays MuseumFloorLevel: [code]setup(museum)[/code].
## It builds and wires the floor's modules - the gates (GateController),
## the room visits and room cards (RoomTracker), the goal on the HUD
## (FloorGoal), the guardians (GuardianKeeper), the weapons and key items
## on their markers (FloorPickups), ambushes and the gentle first minutes
## (FloorEncounters), the world content (WorldFeatures) and the finale
## (FloorFinale) - and answers the Museum's questions about them (may the
## guard rest now, what freezes at dawn). Everything permanent goes through
## GameState; the modules talk through Events.

## The guard walked down into the dark after the T-Rex: the end of Floor I.
signal finished

var museum: Museum
var level: MuseumFloorLevel
var gates: GateController
var rooms: RoomTracker
var goal: FloorGoal
var guardians: GuardianKeeper
var pickups: FloorPickups
var encounters: FloorEncounters
## Notes, secrets, chess pieces, artifacts, the CCTV, the maps.
var world: WorldFeatures
## The court café behind the counter (plan 2026-10-10-kawiarnia-zmeczenie).
var cafe: CafeCorner = null
## The reactive environment and the tagged tools (plan 2026-10-21-srodowisko-walka).
var env: EnvLayer = null
## The museum's own story: labels, curios, the staff's trails, the
## corkboard, the plaque in the court (plan 2026-10-21-opowiesc-muzeum).
var story: MuseumStory = null
var finale: FloorFinale
## The switchboard in the basement (null when its marker is missing).
var switchboard: Switchboard = null
## The paper museum map (M; W6).
var map: MuseumMap = null
## Each wing's own mechanic (plan 2026-10-21-mechaniki-biomow).
var biomes: BiomeMechanics = null
## The night's escalation: uncanny events, foreshadowing, rooms that change
## (plan 2026-10-21-eskalacja-nocy).
var uncanny: UncannyDirector = null
## The rooms' fight scenarios (plan 2026-10-22-projekt-starc).
var scenarios: FloorScenarios = null

## Warnings given so far (each once per run of the game: a marker the
## zone builders have not placed yet must not flood the log every night).
static var _warned: PackedStringArray = []


## push_warning(), once per run for the same text.
static func warn_once(text: String) -> void:
	if not _warned.has(text):
		_warned.append(text)
		push_warning(text)


func setup(for_museum: Museum) -> void:
	museum = for_museum
	level = museum.floor_level
	name = "FloorGame"
	gates = GateController.new()
	add_child(gates)
	gates.setup(level, museum.game, museum.run)
	_build_switchboard()
	guardians = GuardianKeeper.new()
	add_child(guardians)
	guardians.setup(museum)
	pickups = FloorPickups.new()
	add_child(pickups)
	pickups.setup(self)
	encounters = FloorEncounters.new()
	add_child(encounters)
	encounters.setup(museum, pickups)
	world = WorldFeatures.install(level, museum)
	env = EnvLayer.install(level, museum, self)
	cafe = CafeCorner.new()
	add_child(cafe)
	cafe.setup(level, func() -> Player: return museum.player, museum.hud, func() -> float: return museum.watch.clock.elapsed if museum.watch != null else 0.0)
	story = MuseumStory.install(self)
	if world.cctv != null and museum.watch != null:
		world.cctv.clock_seconds = func() -> float: return museum.watch.clock.elapsed
	# the notes read so far, again from the pause menu; the camera view shut
	# by a lost focus asks for the pause the menu could not give
	museum.pause_menu.note_reader = world.reader
	museum.pause_menu.game = museum.game
	world.pause_requested.connect(museum.pause_menu.open)
	map = MuseumMap.install(self)
	biomes = BiomeMechanics.install(self)
	finale = FloorFinale.new()
	add_child(finale)
	finale.setup(self)
	finale.finished.connect(func() -> void: finished.emit())
	museum.hud.enable_floor()
	goal = FloorGoal.new()
	goal.name = "Goal"
	goal.game = museum.game
	goal.hud = museum.hud
	goal.night = museum.night
	add_child(goal)
	# the wings met on earlier nights: no discovery sting for them
	Music.director.remember_wings(known_wings(museum.game, level.layout))
	rooms = RoomTracker.new()
	rooms.name = "Rooms"
	rooms.level = level
	rooms.game = museum.game
	rooms.guard_source = func() -> Node3D: return museum.player
	add_child(rooms)
	rooms.check()   # the night's first room, announced at once (no card)
	rooms.entered.connect(_on_room_entered)
	uncanny = UncannyDirector.new()
	add_child(uncanny)
	uncanny.setup(self)
	scenarios = FloorScenarios.new()
	add_child(scenarios)
	scenarios.setup(self)


## The marker's transform, or null (a warning once) when the layout has no
## such marker yet.
func marker(id: StringName) -> Variant:
	if level.markers.has(id):
		return level.markers[id]
	warn_once("FloorGame: no marker %s in the layout" % id)
	return null


## The wings (Floor1Plan.WINGS) of the rooms visited so far.
static func known_wings(game: PersistentState, floor_layout: LevelLayout) -> Array[StringName]:
	var wings: Array[StringName] = []
	for room_id in game.rooms_visited:
		var room := floor_layout.room(room_id)
		if room != null and Floor1Plan.WINGS.has(room.zone) and not wings.has(room.zone):
			wings.append(room.zone)
	return wings


## True while the guard may not rest in a haven (a fight is on).
func blocks_rest() -> bool:
	return (guardians != null and guardians.fighting()) or (finale != null and finale.fighting())


## True while haven [param haven_id] is kept shut by a guardian still
## standing (GuardianKeeper.HAVEN_GUARDS: the tea house until the General
## falls).
func haven_guarded(haven_id: StringName) -> bool:
	return guardians != null and guardians.haven_guarded(haven_id)


## Dawn: whatever of the floor still moves turns to stone.
func freeze() -> void:
	if guardians != null:
		guardians.freeze()
	if finale != null:
		finale.freeze()


## The guard reached haven [param id] for the first time: its card.
func haven_discovered(id: StringName) -> void:
	var plan := Floor1Plan.haven(id)
	if plan != null:
		museum.hud.show_card(tr("HAVEN_FOUND"), tr(plan.name_key), tr("HAVEN_FOUND_FLOOR_DETAIL"))


## A room's card on the first visit (its name, its wing's name and colour).
func _on_room_entered(room_id: StringName, zone: StringName, first_visit: bool) -> void:
	if not first_visit:
		return
	var room := level.layout.room(room_id)
	if room == null or room.name_key == &"" or room.secret:
		return
	museum.hud.show_room_card(tr(room.name_key), tr(Floor1Plan.zone_name_key(zone)), Floor1Plan.zone_color(zone))


func _build_switchboard() -> void:
	var at: Variant = marker(&"switchboard")
	if at == null:
		return
	switchboard = Switchboard.new()
	switchboard.name = "Switchboard"
	switchboard.game = museum.game
	switchboard.transform = at
	add_child(switchboard)
	switchboard.powered.connect(_on_powered)


func _on_powered() -> void:
	museum.hud.show_toast(tr("HUD_POWER_ON"))
	gates.power_on()
	NightRules.save_progress(museum.game, museum.run)
