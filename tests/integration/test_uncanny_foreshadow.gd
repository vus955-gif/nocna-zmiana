extends TestCase
## Foreshadowing (plan 2026-10-21-eskalacja-nocy, task 8; backlog #28): an
## ambush still waiting gives itself away before it springs (a lid ajar,
## dust, a glint, a sound), never after; a wing guardian not beaten is heard
## from afar, a beaten one never; a lid left ajar stays ajar in a resumed
## night.

const SEED := 7   # nights 2-4 without a modifier (no blackout: the lamps are on)

var museum: Museum
var director: UncannyDirector


func before_each() -> void:
	Museum.level_id = &"floor1"


func after_each() -> void:
	if is_instance_valid(museum):
		museum.free()


func _build() -> void:
	museum = (load(SceneFlow.MUSEUM) as PackedScene).instantiate() as Museum
	add_child(museum)
	await physics_frames(2)
	director = museum.floor_game.uncanny
	director.chance_scale = 0.0


func _start(night: int = 2) -> void:
	GameState.new_game()
	GameState.seed_base = SEED
	GameState.night = night
	await _build()


func _go(room: StringName) -> void:
	var at := UncannyRules.room_point(museum.floor_level.layout, room)
	museum.player.global_position = Vector3(at.x, at.y - 1.1, at.z)
	museum.floor_game.rooms.check()


func _run(seconds: float) -> void:
	var t := 0.0
	while t < seconds:
		director.advance(UncannyDirector.TICK)
		t += UncannyDirector.TICK


## The foreshadowing events whose ambush has sleepers tonight.
func _waiting() -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for entry in director.catalog.by_trigger(&"enter"):
		if entry.has("ambush") and not director._ambush_sleepers(StringName(entry["ambush"])).is_empty():
			found.append(entry)
	return found


func test_an_ambush_waiting_gives_itself_away_once() -> void:
	await _start()
	var waiting := _waiting()
	assert_gt(waiting.size(), 2, "tonight's ambushes sleep")
	for entry in waiting:
		var id := UncannyCatalog.id_of(entry)
		var rooms := UncannyCatalog.names(entry, "rooms")
		_go(&"booth_corridor")
		_go(rooms[0])
		_run(UncannyDirector.MIN_GAP + float(entry.get("delay", 0.0)) + 2.0)
		assert_true(director.fired.has(id), "%s before its ambush" % id)
		var ambush := museum.floor_level.layout.ambush(StringName(entry["ambush"]))
		assert_true(museum.floor_game.encounters.waiting.has(ambush) or museum.floor_game.scenarios.ambush_waits(ambush.id),
				"%s: it only told, it did not spring" % id)
		_go(&"booth_corridor")
		_go(rooms[0])
		_run(UncannyDirector.MIN_GAP + float(entry.get("delay", 0.0)) + 2.0)
		assert_eq(director.fired.count(id), 1, "%s once a night" % id)


func test_a_sprung_ambush_tells_nothing() -> void:
	await _start()
	var waiting := _waiting()
	assert_false(waiting.is_empty())
	var entry := waiting[0]
	var ambush := museum.floor_level.layout.ambush(StringName(entry["ambush"]))
	museum.floor_game.encounters.spring(ambush)
	_go(&"booth_corridor")
	_go(UncannyCatalog.names(entry, "rooms")[0])
	_run(20.0)
	assert_false(director.fired.has(UncannyCatalog.id_of(entry)), "too late to warn")


func test_the_sarcophagus_lid_stands_ajar_and_stays_so_in_a_resumed_night() -> void:
	await _start()
	GameState.save_game()
	var sleepers := director._ambush_sleepers(&"egypt_sarcophagi")
	var tombs := sleepers.filter(func(e: Enemy) -> bool: return e is Mummy and (e as Mummy).tomb != null)
	if tombs.is_empty():
		return   # no mummy in a sarcophagus tonight (the seed's draw)
	_go(&"egypt_tomb_passage")
	_run(12.0)
	assert_true(director.fired.has(&"fs_sarcophagi"))
	var ajar := tombs.filter(func(m: Mummy) -> bool: return UncannyEffects.is_ajar(m.tomb))
	assert_eq(ajar.size(), 1, "one lid ajar")
	var slot := int((ajar[0] as Mummy).get_meta(Museum.SLOT_META))
	museum.quit_to_menu()
	museum.free()
	RunState.reset()
	GameState.reset()
	assert_true(GameState.load_game())
	await _build()
	await physics_frames(3)
	var again := museum.exhibits().filter(func(e: Enemy) -> bool: return e is Mummy and int(e.get_meta(Museum.SLOT_META, -1)) == slot)
	assert_eq(again.size(), 1)
	assert_true(UncannyEffects.is_ajar((again[0] as Mummy).tomb), "still ajar")


func test_a_wing_guardian_is_heard_until_it_is_beaten() -> void:
	GameState.new_game()
	GameState.seed_base = SEED
	GameState.night = 2
	GameState.defeat_guardian(&"colossus")
	await _build()
	for exhibit in museum.exhibits():
		exhibit.free()
	_go(&"booth_corridor")
	_go(&"egypt_vestibule")
	_run(10.0)
	_go(&"egypt_gallery")
	_run(10.0)
	assert_false(director.fired.has(&"fs_guardian_colossus"), "the Colossus fell: silence")
	_go(&"greece_nereid")
	_run(10.0)
	assert_true(director.fired.has(&"fs_guardian_centaur"), "the Centaur still stands: hooves on marble")
	_go(&"greece_vases")
	_run(10.0)
	assert_eq(director.fired.count(&"fs_guardian_centaur"), 1, "once a night")
