extends TestCase
## The uncanny event table (data/night/uncanny.json; plan
## 2026-10-21-eskalacja-nocy, 3) against the real Floor I: every name it
## uses exists, every change of the world has a fair target, the mix is
## the one designed (the curve's pool, hand-made moments, foreshadowing
## of real threats, rooms that change), and the rules read it right.

static var _layout: LevelLayout = null

var catalog: UncannyCatalog


func before_each() -> void:
	catalog = UncannyCatalog.load_default()
	if _layout == null:
		_layout = Floor1Layout.create()


func _texts() -> Dictionary:
	var rows := {}
	var file := FileAccess.open("res://locale/strings.csv", FileAccess.READ)
	while not file.eof_reached():
		var row := file.get_csv_line()
		if row.size() >= 3:
			rows[row[0]] = row
	return rows


func test_every_event_of_the_file_is_sound() -> void:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(UncannyCatalog.PATH))
	assert_true(data is Dictionary, "the file parses")
	var ids := {}
	var off := 0
	for entry: Dictionary in data["events"]:
		var id := str(entry.get("id", "?"))
		for problem in UncannyCatalog.problems_of(entry):
			fail("%s: %s" % [id, problem])
		assert_false(ids.has(id), "%s once" % id)
		ids[id] = true
		if UncannyCatalog.switched_off(entry):
			off += 1   # the owner's switch ("enabled": false; plan 2026-10-22-set-piece)
	assert_eq(catalog.events.size(), (data["events"] as Array).size() - off, "every event loads (but the ones switched off)")


func test_the_mix_is_the_one_designed() -> void:
	var ambient := catalog.by_trigger(&"ambient").size()
	var enter := catalog.by_trigger(&"enter")
	var returns := catalog.by_trigger(&"return").size()
	var nights := catalog.by_trigger(&"night").size()
	assert_gt(catalog.events.size(), 30, "a table worth the name")
	assert_true(ambient >= 10, "the curve's pool: %d" % ambient)
	assert_true(returns >= 5, "rooms that change behind his back: %d" % returns)
	assert_true(nights >= 2, "rooms changed by the next night: %d" % nights)
	var ambushes := enter.filter(func(e: Dictionary) -> bool: return e.has("ambush")).size()
	var guardians := enter.filter(func(e: Dictionary) -> bool: return e.has("guardian")).size()
	assert_true(ambushes >= 6, "ambushes foreshadowed: %d" % ambushes)
	assert_eq(guardians, Floor1Plan.guardians().size(), "every wing guardian gives itself away")
	assert_gt(catalog.events.filter(func(e: Dictionary) -> bool: return e.get("once_per_game", false)).size(), 0, "a moment once per game")
	assert_true(catalog.events.filter(func(e: Dictionary) -> bool: return float(e.get("chance", 1.0)) < 0.55).size() >= 3, "rare ones")
	for phase in NightEscalation.PHASES:
		var pool := catalog.by_trigger(&"ambient").filter(func(e: Dictionary) -> bool: return UncannyRules.weight(e, phase) > 0.0)
		assert_true(pool.size() >= 3, "phase %d has a pool of its own (%d)" % [phase, pool.size()])


func test_the_pool_grows_bolder_with_the_night() -> void:
	# the lamps' outages, sweeps and exit signs belong to the witching hour and after
	for id in [&"lamp_out", &"lamp_sweep", &"exit_signs"]:
		var entry := catalog.event(id)
		assert_eq(UncannyRules.weight(entry, NightEscalation.Phase.CALM), 0.0, "%s: not at the quiet start" % id)
		assert_eq(UncannyRules.weight(entry, NightEscalation.Phase.UNEASY), 0.0, "%s: not before 3:00" % id)
	assert_gt(UncannyRules.weight(catalog.event(&"lamp_blink"), NightEscalation.Phase.CALM), 0.0, "the start: one lamp blinks")
	assert_eq(UncannyRules.weight(catalog.event(&"lamp_blink"), NightEscalation.Phase.PREDAWN), 0.0, "before dawn nothing so small")
	for entry in catalog.by_trigger(&"ambient"):
		if entry.has("noise"):
			assert_eq(UncannyRules.weight(entry, NightEscalation.Phase.CALM), 0.0, "%s: the calm start wakes nobody" % entry["id"])
			assert_eq(entry.get("where", "here"), "near", "%s: a noise next door, never at the guard" % entry["id"])


func test_every_name_it_uses_exists() -> void:
	var rooms := {}
	var zones := {}
	for room in _layout.rooms:
		rooms[room.id] = true
		zones[room.zone] = true
	var guardians := Floor1Plan.guardians().map(func(g: Floor1Plan.GuardianPlan) -> StringName: return g.id)
	var texts := _texts()
	var lines := VoiceCatalog.load_default()
	for entry in catalog.events:
		var id := String(entry["id"])
		for room in UncannyCatalog.names(entry, "rooms"):
			assert_true(rooms.has(room), "%s: room %s" % [id, room])
		for zone in UncannyCatalog.names(entry, "zones"):
			assert_true(zones.has(zone), "%s: zone %s" % [id, zone])
		if entry.has("marker"):
			assert_true(_layout.markers.has(StringName(entry["marker"])), "%s: marker %s" % [id, entry["marker"]])
		if entry.has("ambush"):
			assert_not_null(_layout.ambush(StringName(entry["ambush"])), "%s: ambush %s" % [id, entry["ambush"]])
		if entry.has("guardian"):
			assert_true(guardians.has(StringName(entry["guardian"])), "%s: guardian %s" % [id, entry["guardian"]])
		if entry.has("sound"):
			assert_true(Sfx.SOUNDS.has(StringName(entry["sound"])), "%s: sound %s" % [id, entry["sound"]])
		if entry.has("text"):
			var row: Variant = texts.get(entry["text"])
			assert_true(row != null and String(row[1]) != "" and String(row[2]) != "", "%s: text %s in Polish and English" % [id, entry["text"]])
		if entry.has("voice"):
			assert_false(lines.line(StringName(entry["voice"])).is_empty(), "%s: voice line %s" % [id, entry["voice"]])
		for kind in UncannyCatalog.names(entry, "kinds"):
			assert_true(EnemyRoles.ROLES.has(kind), "%s: kind %s" % [id, kind])


func test_an_ambushs_foreshadowing_comes_before_the_ambush() -> void:
	for entry in catalog.by_trigger(&"enter"):
		if not entry.has("ambush"):
			continue
		var ambush := _layout.ambush(StringName(entry["ambush"]))
		var rooms := UncannyCatalog.names(entry, "rooms")
		assert_false(rooms.is_empty(), "%s: rooms to show itself in" % entry["id"])
		for room in rooms:
			assert_true(room == ambush.room or UncannyRules.neighbours(_layout.graph(), ambush.room).has(room) \
					or UncannyRules.neighbours(_layout.graph(), room).any(func(r: StringName) -> bool: return UncannyRules.neighbours(_layout.graph(), r).has(ambush.room)),
					"%s: %s is on the way to %s" % [entry["id"], room, ambush.room])


func test_every_change_of_the_world_has_a_fair_target() -> void:
	var excluded := UncannyRules.excluded_rooms(_layout)
	for trigger in [&"return", &"night"]:
		for entry in catalog.by_trigger(trigger):
			var id := String(entry["id"])
			match StringName(entry["effect"]):
				&"hide", &"turn":
					var pieces := UncannyRules.fair_pieces(_layout, entry)
					assert_gt(pieces.size(), 0, "%s: a fair piece" % id)
					for index in pieces:
						var piece := _layout.pieces[index]
						assert_false(excluded.has(piece.room), "%s: not in %s" % [id, piece.room])
						assert_true(UncannyRules.piece_is_fair(_layout, piece))
				&"sitter", &"look":
					assert_gt(UncannyRules.painting_spots(_layout, UncannyCatalog.names(entry, "rooms")).size(), 0, "%s: a painting" % id)
				&"dark":
					assert_gt(UncannyRules.dark_rooms(_layout).size(), 5, "%s: rooms to darken" % id)


func test_no_change_touches_a_room_to_fight_or_rest_in() -> void:
	var excluded := UncannyRules.excluded_rooms(_layout)
	for haven in Floor1Plan.havens():
		assert_true(excluded.has(haven.room), "haven %s" % haven.room)
	for room in [&"court", &"egypt_colossus", &"assyria_courtyard", &"greece_parthenon", &"enlightenment_planetarium", &"asia_garden", &"americas_temple"]:
		assert_true(excluded.has(room), "arena %s" % room)
	for room in UncannyRules.dark_rooms(_layout):
		assert_false(excluded.has(room))
		assert_false(_layout.room(room).secret)


func test_a_room_left_dark_is_never_one_to_fall_climb_or_finish_the_night_in() -> void:
	var dark := UncannyRules.dark_rooms(_layout)
	assert_gt(dark.size(), 5, "rooms are left to darken")
	# a drop, stairs, an objective, the T-Rex's court, the wing of the fire bowls
	for id in [&"americas_pit", &"americas_pacific", &"booth_stairs", &"roof_stairs", &"enlightenment_roof_stairs", &"americas_service_stairs",
			&"asia_service_stairs", &"greece_service_stairs", &"enlightenment_service_stairs", &"egypt_service_stairs", &"assyria_freight_stairs",
			&"assyria_lions", &"basement_switchboard", &"basement_boiler", &"court_reading", &"americas_totems", &"americas_north"]:
		assert_not_null(_layout.room(id), "%s exists" % id)
		assert_false(dark.has(id), "%s stays lit" % id)
	var objectives := Floor1Layout.objective_rooms(_layout)
	assert_true(objectives.has(&"basement_switchboard") and objectives.has(&"court_reading"), "the objectives are the ones the night needs")
	var flights: Array[StringName] = []
	for flight in _layout.stairs:
		flights.append(flight.room_low)
		flights.append(flight.room_high)
	var excluded := UncannyRules.excluded_rooms(_layout)
	for id in dark:
		var room := _layout.room(id)
		assert_false(flights.has(id), "%s: no stairs" % id)
		assert_false(objectives.has(id), "%s: no objective" % id)
		assert_false(excluded.has(id), "%s: no arena or haven" % id)
		assert_ne(room.zone, &"americas", "%s: the fire bowls' wing" % id)
		assert_false(String(id).begins_with("americas_"), id)


func test_a_room_with_stairs_a_drop_or_an_arena_inside_it_stays_lit() -> void:
	var layout := LevelLayout.new()
	var rooms := {&"plain": Rect2(0, 0, 10, 10), &"tower": Rect2(20, 0, 6, 6), &"top": Rect2(30, 0, 6, 6), &"arena": Rect2(0, 20, 20, 20),
			&"nook": Rect2(8, 28, 4, 4), &"ledge": Rect2(40, 0, 6, 6), &"pit": Rect2(50, 0, 6, 6)}
	for id: StringName in rooms:
		layout.add_room(id, [rooms[id]] as Array[Rect2], -6.0 if id == &"pit" or id == &"tower" else 0.0, 4.0, Color.GRAY)
		var at: Vector2 = (rooms[id] as Rect2).get_center()
		layout.add_light(LightSpec.MAIN, Vector3(at.x, 3.0, at.y), Color.WHITE, 1.0, 8.0, id)
		layout.add_light(LightSpec.EMERGENCY, Vector3(at.x, 2.5, at.y), Color.RED, 0.5, 4.0, id)
	layout.add_stairs(&"flight", Rect2(20, 0, 4, 6), -6.0, 0.0, Vector2(1, 0), &"tower", &"tower")
	layout.add_opening(&"top_tower", Rect2(26, 2, 4, 2), 0.0, 2.6, &"tower", &"top")   # the way down is a flight
	layout.add_opening(&"ledge_pit", Rect2(46, 2, 4, 2), 0.0, 2.6, &"ledge", &"pit")   # the way down is a fall
	layout.add_marker(&"arena_demo_start", Vector3(10, 1, 30), &"arena")
	assert_eq(UncannyRules.dark_rooms(layout), [&"plain", &"top"] as Array[StringName], "no stairs, no fall on either side, no arena nor room inside one")


func test_a_piece_with_something_of_the_game_near_it_stays() -> void:
	var layout := LevelLayout.new()
	layout.add_room(&"hall", [Rect2(-10, -10, 20, 20)] as Array[Rect2], 0.0, 4.0, Color.GRAY)
	var lonely := layout.add_piece(&"sculpture", Vector3(5, 0, 5), Vector3.ONE, &"hall")
	var noted := layout.add_piece(&"sculpture", Vector3(-5, 0, 5), Vector3.ONE, &"hall")
	layout.add_marker(&"note_x", Vector3(-5.9, 1.0, 5.0), &"hall")
	var looted := layout.add_piece(&"sculpture", Vector3(5, 0, -5), Vector3.ONE, &"hall")
	layout.add_loot(Vector3(5.0, 0.8, -4.0), &"hall", true)
	var posted := layout.add_piece(&"sculpture", Vector3(-5, 0, -5), Vector3.ONE, &"hall")
	layout.add_spawn(Vector3(-5.5, 0, -5.5), &"hall", 0, [&"wax"] as Array[StringName])
	var climbed := layout.add_piece(&"sculpture", Vector3(0, 0, 0), Vector3(1, 2, 1), &"hall")
	layout.add_marker(&"secret_ledge", Vector3(2.0, 3.2, 0.0), &"hall")
	assert_true(UncannyRules.piece_is_fair(layout, lonely))
	assert_false(UncannyRules.piece_is_fair(layout, noted), "a note beside it")
	assert_false(UncannyRules.piece_is_fair(layout, looted), "loot on it")
	assert_false(UncannyRules.piece_is_fair(layout, posted), "an exhibit's post")
	assert_false(UncannyRules.piece_is_fair(layout, climbed), "a ledge reached by climbing it")
	var hides := {"id": "x", "trigger": "return", "effect": "hide", "kit": "sculpture"}
	assert_eq(UncannyRules.fair_pieces(layout, hides), [0] as Array[int])
	var benches := {"id": "x", "trigger": "return", "effect": "hide", "kit": "bench"}
	assert_eq(UncannyRules.fair_pieces(layout, benches).size(), 0, "a bench is never hidden")


func test_the_rules_read_phases_nights_and_limits() -> void:
	var gaze := catalog.event(&"court_eyes")
	assert_true(UncannyRules.in_phase(gaze, NightEscalation.Phase.CALM))
	assert_false(UncannyRules.in_phase(gaze, NightEscalation.Phase.WITCHING), "only early")
	var statue := catalog.event(&"night_statue_gone")
	assert_false(UncannyRules.fits_night(statue, 1, &"none"), "not on night 1")
	assert_true(UncannyRules.fits_night(statue, 2, &"none"))
	assert_false(UncannyRules.fits_night(catalog.event(&"lamp_out"), 3, &"blackout"), "no outage in a blackout")
	var used: Array[StringName] = []
	var seen: Array[StringName] = []
	var brown := catalog.event(&"lamp_brownout")
	for n in 3:
		assert_true(UncannyRules.may_fire(brown, used, seen), "firing %d" % n)
		used.append(UncannyRules.fired_id(&"lamp_brownout", n + 1))
	assert_false(UncannyRules.may_fire(brown, used, seen), "its limit")
	assert_eq(UncannyRules.fired_count(used, &"lamp"), 0, "another id's entries are not counted")
	assert_true(UncannyRules.may_fire(catalog.event(&"lamp_blink"), used, seen), "no limit")
	seen.append(&"court_eyes")
	assert_false(UncannyRules.may_fire(gaze, [] as Array[StringName], seen), "once per game")


func test_changes_are_kept_as_entries_and_read_back() -> void:
	var entry := UncannyRules.change_id(&"gone_statue", "123")
	assert_eq(UncannyRules.parse_change(entry), [&"gone_statue", "123"])
	assert_eq(UncannyRules.parse_change(&"pack_3_1"), [])
	var used: Array[StringName] = [&"clock_300", entry, UncannyRules.change_id(&"sitter_gone", "portrait_court_2")]
	assert_eq(UncannyRules.changes(used).size(), 2)


func test_a_weighted_pick_is_steady_and_follows_the_weights() -> void:
	var pool := catalog.by_trigger(&"ambient")
	var phase := NightEscalation.Phase.WITCHING
	var counts := {}
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in 2000:
		var chosen := UncannyRules.pick(pool, phase, rng.randf())
		assert_gt(UncannyRules.weight(chosen, phase), 0.0, "never one out of its phase")
		counts[chosen["id"]] = int(counts.get(chosen["id"], 0)) + 1
	assert_gt(int(counts.get("lamp_brownout", 0)), int(counts.get("radio_breath", 0)), "weights")
	assert_eq(UncannyRules.pick(pool, phase, 0.3), UncannyRules.pick(pool, phase, 0.3), "the same roll, the same event")
	assert_eq(UncannyRules.pick([] as Array[Dictionary], phase, 0.3), {})
