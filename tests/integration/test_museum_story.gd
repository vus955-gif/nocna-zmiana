extends TestCase
## The museum's story in the world (plan docs/superpowers/plans/
## 2026-10-21-opowiesc-muzeum.md): the exhibit labels and their card. Built
## from the bare Floor I layout (MuseumStory.make): no level, no museum.

var layout: LevelLayout
var story: MuseumStory
var guard: Node3D


func _story() -> MuseumStory:
	layout = Floor1Layout.create()
	guard = Node3D.new()
	add_child(guard)
	story = MuseumStory.make(layout, layout.markers, func() -> Node3D: return guard)
	add_child(story)
	return story


func after_each() -> void:
	Settings.set_value(&"language", "pl", false)


func test_a_label_stands_on_every_label_marker() -> void:
	_story()
	assert_eq(story.labels.size(), ExhibitLabels.ids().size())
	for id: StringName in story.labels:
		var label: ExhibitLabel = story.labels[id]
		var at: Transform3D = layout.markers[ExhibitLabels.marker_of(id)]
		assert_lt(label.global_position.distance_to(at.origin), 0.01, "%s on its marker" % id)
		assert_eq(label.collision_layer, Layers.INTERACT, "%s can be read" % id)
		assert_eq(label.prompt(), "Przeczytaj tabliczkę")


func test_reading_a_label_shows_its_card_and_reading_again_puts_it_down() -> void:
	_story()
	var read := watch(story.label_read)
	var label: ExhibitLabel = story.labels[&"colossus"]
	guard.global_position = label.global_position + Vector3(0, 0, 1.5)
	label.interact(null)
	await physics_frames(2)
	assert_eq(read.size(), 1)
	assert_true(story.card.is_open())
	assert_eq(story.card.shown[1], tr("LABEL_COLOSSUS_TITLE"))
	assert_eq(story.card.shown[2], tr("LABEL_COLOSSUS_TEXT"))
	assert_true(story.card.shown[0].contains("EG.1898.40"), "the inventory number")
	assert_true(story.card.shown[0].contains(tr("ZONE_EGYPT")), "and the wing")
	assert_false(get_tree().paused, "reading a label does not stop the night")
	label.interact(null)
	for i in 20:
		await get_tree().process_frame
	assert_false(story.card.is_open(), "the second E puts it down")


func test_the_card_goes_when_the_guard_walks_away_or_has_had_time_to_read() -> void:
	_story()
	var label: ExhibitLabel = story.labels[&"lamassu"]
	guard.global_position = label.global_position + Vector3(0, 0, 1.0)
	label.interact(null)
	await physics_frames(2)
	assert_true(story.card.is_open())
	guard.global_position = label.global_position + Vector3(0, 0, 6.0)
	for i in 40:
		await get_tree().process_frame
	assert_false(story.card.is_open(), "walking away puts it down")
	guard.global_position = label.global_position + Vector3(0, 0, 1.0)
	label.interact(null)
	await physics_frames(2)
	var hold := story.card.hold_time()
	assert_gt(hold, 5.0, "time to read two or three lines")
	assert_lt(hold, 20.0, "but not forever")
	story.card._process(hold + 0.1)
	story.card._process(0.5)
	assert_false(story.card.is_open(), "and it goes by itself")


func test_a_stand_is_solid_a_plate_on_the_wall_is_not() -> void:
	_story()
	var stand: ExhibitLabel = story.labels[&"rosetta"]
	var plate: ExhibitLabel = story.labels[&"colossus"]
	assert_eq(ExhibitLabels.mount(&"rosetta"), ExhibitLabels.Mount.STAND)
	assert_not_null(stand.get_node_or_null(^"Body"), "the stand's post stops the guard")
	assert_true(plate.get_node_or_null(^"Body") == null, "a wall plate stops nothing")
	assert_not_null(plate.get_node_or_null(^"Plate"), "the brass plate")


func test_the_trex_label_leaves_the_plate_to_the_dressed_pedestal() -> void:
	layout = Floor1Layout.create()
	var dressed := MuseumStory.make(layout, layout.markers)
	dressed.dressed = true
	add_child(dressed)
	assert_true((dressed.labels[&"trex"] as ExhibitLabel).get_node_or_null(^"Plate") == null, "the art kit's plate is there")
	assert_not_null((dressed.labels[&"colossus"] as ExhibitLabel).get_node_or_null(^"Plate"), "other labels bring their own")
	var greybox := MuseumStory.make(layout, layout.markers)
	add_child(greybox)
	assert_not_null((greybox.labels[&"trex"] as ExhibitLabel).get_node_or_null(^"Plate"), "a plain plate in a greybox build")


## Canvases of the game's windows (canvas_items, expand, 1920 x 1080
## base): 16:9, 5:4 (taller), 21:9 (wider).
const CANVASES: Array[Vector2i] = [Vector2i(1920, 1080), Vector2i(1920, 1536), Vector2i(2560, 1080)]


## A card on its own canvas of [param size] units.
func _card_on_canvas(size: Vector2i) -> ExhibitCard:
	var view := SubViewport.new()
	view.size = size
	add_child(view)
	var card := ExhibitCard.new()
	view.add_child(card)
	return card


## [param card] showing [param caption], [param title], [param text] fits its
## canvas: on the right half, under the top edge, above the subtitles.
func _check_fits(card: ExhibitCard, caption: String, title: String, text: String, what: String) -> void:
	card.show_card(caption, title, text)
	await get_tree().process_frame
	card._place()
	var canvas := card.get_viewport().get_visible_rect().size
	var size := card.card_size()
	assert_lt(size.x, 700.0, "%s: the card's width %.0f" % [what, size.x])
	assert_lt(size.y, 420.0, "%s: the card's height %.0f" % [what, size.y])
	var rect := card.card_rect()
	assert_gt(rect.position.x, canvas.x * 0.5, "%s: on the right side" % what)
	assert_lt(rect.end.x, canvas.x, "%s: inside the right edge" % what)
	assert_gt(rect.position.y, 80.0, "%s: under the top edge" % what)
	assert_lt(rect.end.y, canvas.y - 260.0, "%s: above the subtitles" % what)
	card.close()
	card._process(1.0)


## Every label has its title and text in both languages, and its card fits
## the right side of the screen.
func test_every_label_card_reads_and_fits_in_both_languages() -> void:
	for language in ["pl", "en"]:
		Settings.set_value(&"language", language, false)
		for canvas in CANVASES:
			var card := _card_on_canvas(canvas)
			for id in ExhibitLabels.ids():
				for key in [ExhibitLabels.title_key(id), ExhibitLabels.text_key(id)]:
					assert_ne(tr(key), key, "%s in %s" % [key, language])
				var text := tr(ExhibitLabels.text_key(id))
				assert_true(text.length() >= 80 and text.length() <= 260, "%s %s: two or three short lines (%d letters)" % [language, id, text.length()])
				var caption := tr("LABEL_CAPTION") % [ExhibitLabels.number(id), tr("ZONE_AMERICAS")]
				await _check_fits(card, caption, tr(ExhibitLabels.title_key(id)), text, "%s %s %s" % [language, id, canvas])
		assert_eq(tr("PROMPT_READ_LABEL"), "Przeczytaj tabliczkę" if language == "pl" else "Read the label")


# --- the staff's trails --------------------------------------------------------------

func test_every_trail_is_built_and_its_one_thing_can_be_examined() -> void:
	_story()
	var count := 0
	for id: StringName in layout.markers:
		if String(id).begins_with(StoryVignettes.PREFIX):
			count += 1
			assert_true(story.props.has(id), "%s has its prop" % id)
	assert_eq(story.props.size(), count)
	var seen := watch(story.examined)
	for wing in Floor1Plan.WINGS:
		var thing: StoryExamine = story.examines.get(wing)
		assert_not_null(thing, "%s: the thing to look at" % wing)
		if thing == null:
			continue
		assert_eq(thing.prompt(), "Obejrzyj")
		assert_eq(thing.collision_layer, Layers.INTERACT)
		guard.global_position = thing.global_position + Vector3(0, 0, 1.0)
		thing.interact(null)
		await get_tree().process_frame
		assert_eq(story.card.shown[0].to_lower(), tr(StoryVignettes.who_key(wing)).to_lower(), "%s: who left it" % wing)
		assert_eq(story.card.shown[1], tr(StoryVignettes.title_key(wing)))
		assert_eq(story.card.shown[2], tr(StoryVignettes.text_key(wing)))
	assert_eq(seen.size(), Floor1Plan.WINGS.size())


## Nothing of a trail stops the guard or an exhibit: no solid body.
func test_trail_props_are_not_solid() -> void:
	_story()
	for id: StringName in story.props:
		var prop: Node = story.props[id]
		for node in prop.find_children("*", "CollisionObject3D", true, false):
			assert_true(node is Area3D, "%s: nothing solid (%s)" % [id, node.name])


func test_every_trail_text_reads_short_and_fits_in_both_languages() -> void:
	for language in ["pl", "en"]:
		Settings.set_value(&"language", language, false)
		var card := _card_on_canvas(Vector2i(1920, 1080))
		for wing in Floor1Plan.WINGS:
			for key in [StoryVignettes.who_key(wing), StoryVignettes.title_key(wing), StoryVignettes.text_key(wing)]:
				assert_ne(tr(key), key, "%s in %s" % [key, language])
			var text := tr(StoryVignettes.text_key(wing))
			assert_lt(text.length(), 175, "%s %s: two short sentences, no note (%d letters)" % [language, wing, text.length()])
			await _check_fits(card, tr(StoryVignettes.who_key(wing)), tr(StoryVignettes.title_key(wing)), text, "%s %s" % [language, wing])
		assert_eq(tr("PROMPT_EXAMINE"), "Obejrzyj" if language == "pl" else "Examine")


# --- the exhibits that answer ----------------------------------------------------------

func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


func test_every_curio_stands_on_its_marker() -> void:
	_story()
	assert_eq(story.curios.size(), Curios.ids().size())
	for id in Curios.ids():
		var curio: Curio = story.curios.get(id)
		assert_not_null(curio, "%s is there" % id)
		if curio == null:
			continue
		assert_lt(curio.global_position.distance_to((layout.markers[Curios.marker_of(id)] as Transform3D).origin), 0.01)
		assert_eq(curio.prompt(), tr(Curios.prompt_key(id)))
		assert_ne(curio.prompt(), Curios.prompt_key(id), "%s's prompt has a text" % id)
		assert_eq(curio.collision_layer, Layers.INTERACT, "%s can be used" % id)
	assert_eq((story.curios[&"astrolabe"] as Curio).get_node_or_null(^"Body") != null, true, "the stand is solid")


func test_the_bird_sings_toward_the_orrery_and_tells_the_hint_once_per_game() -> void:
	_story()
	var bird: CurioBird = story.curios[&"bird"]
	var solved := watch(story.curio_solved)
	guard.global_position = bird.global_position + Vector3(0, 0, 1.2)
	bird.interact(null)
	assert_true(bird.singing)
	assert_eq(story.card.shown[2], tr("CURIO_BIRD_TEXT"), "first what it is")
	bird.interact(null)
	assert_true(bird.singing, "a second E does not start it over")
	for i in 60:
		bird.advance(0.1)
	assert_false(bird.singing, "the song ends")
	assert_eq(story.card.shown[2], tr("CURIO_BIRD_ANSWER"), "then what the curator made of it")
	assert_true(GameState.has_flag(&"curio_bird"), "recorded")
	assert_eq(solved.size(), 1)
	# the long trill went to the Great Orrery
	var orrery: Vector3 = (layout.markers[&"guardian_planetarium"] as Transform3D).origin
	var bird_part := bird.get_node(^"Model").find_child("bird", true, false) as Node3D
	if bird_part != null:
		var look := -bird_part.global_transform.basis.z
		var want := (orrery - bird_part.global_position)
		look.y = 0.0
		want.y = 0.0
		assert_gt(look.normalized().dot(want.normalized()), 0.9, "it sang toward the Planetarium")
	# wound again: it sings again, but it is not news any more
	bird.interact(null)
	for i in 60:
		bird.advance(0.1)
	assert_eq(solved.size(), 1, "announced once")
	assert_true(bird.enabled, "and it can always be wound")


func test_the_astrolabe_turned_to_the_pole_star_opens_its_drawer_once_per_game() -> void:
	_story()
	var astrolabe: CurioAstrolabe = story.curios[&"astrolabe"]
	var dust_before := RunState.dust
	guard.global_position = astrolabe.global_position + Vector3(0, 0, -1.2)
	var turns := 0
	while not GameState.has_flag(&"curio_astrolabe") and turns < CurioAstrolabe.STEPS:
		astrolabe.interact(null)
		turns += 1
		if turns == 1:
			assert_eq(story.card.shown[2], tr("CURIO_ASTROLABE_TEXT"), "the first turn tells what it is")
		await _frames(30)
	assert_eq(turns, CurioAstrolabe.STEPS - CurioAstrolabe.START, "a few notches to the star")
	assert_eq(astrolabe.step, 0)
	assert_eq(story.card.shown[2], tr("CURIO_ASTROLABE_ANSWER"))
	assert_eq(RunState.dust - dust_before, Curios.dust(&"astrolabe"), "a pouch of Dust")
	assert_eq(astrolabe.pickups.size(), 1, "rounds in the drawer")
	assert_false(astrolabe.enabled, "nothing more to turn")
	astrolabe.interact(null)
	assert_eq(RunState.dust - dust_before, Curios.dust(&"astrolabe"), "the pouch is given once")
	# the next night (the save keeps the flags): open and set, the rounds still there
	GameState.from_dict(GameState.to_dict())
	var next := MuseumStory.make(layout, layout.markers)
	add_child(next)
	var again: CurioAstrolabe = next.curios[&"astrolabe"]
	assert_eq(again.step, 0, "still on the star")
	assert_false(again.enabled)
	assert_eq(again.pickups.size(), 1, "what was not taken still lies there")
	again.pickups[0].taken.emit()
	assert_true(GameState.has_flag(Curios.taken_flag(&"astrolabe", 0)))
	var third := MuseumStory.make(layout, layout.markers)
	add_child(third)
	assert_eq((third.curios[&"astrolabe"] as Curio).pickups.size(), 0, "taken once, gone for good")


func test_the_portrait_answers_once_in_the_game() -> void:
	_story()
	var portrait: CurioPortrait = story.curios[&"portrait"]
	guard.global_position = portrait.global_position + Vector3(0, -1.5, 1.5)
	portrait.interact(null)
	assert_eq(story.card.shown[2], tr("CURIO_PORTRAIT_ANSWER"))
	assert_true(portrait.awake, "its eyes light up")
	assert_true(GameState.has_flag(&"curio_portrait"))
	assert_false(portrait.enabled, "then it is a painting again")
	assert_eq(portrait.collision_layer, 0)
	portrait._process(CurioPortrait.AWAKE + 0.1)
	assert_false(portrait.awake)
	var next := MuseumStory.make(layout, layout.markers)
	add_child(next)
	assert_false((next.curios[&"portrait"] as Curio).enabled, "it never answers again")


func test_the_scales_sink_and_open_once_per_game() -> void:
	_story()
	var scale: CurioScale = story.curios[&"scale"]
	var dust_before := RunState.dust
	guard.global_position = scale.global_position + Vector3(0, 0, -1.2)
	scale.interact(null)
	assert_eq(story.card.shown[2], tr("CURIO_SCALE_TEXT"))
	assert_false(scale.enabled)
	await _frames(int((CurioScale.SINK_TIME + 0.3) * 60.0))
	assert_eq(story.card.shown[2], tr("CURIO_SCALE_ANSWER"))
	assert_true(GameState.has_flag(&"curio_scale"))
	assert_eq(RunState.dust - dust_before, Curios.dust(&"scale"))
	assert_eq(scale.pickups.size(), 1, "a medkit by the open compartment")
	assert_eq(scale.pickups[0].type, Pickup.Type.MEDKIT)
	var next := MuseumStory.make(layout, layout.markers)
	add_child(next)
	assert_false((next.curios[&"scale"] as Curio).enabled, "tipped and open on later nights")


## A guard without the rifle finds what he can use in the astrolabe's
## drawer (the loot rule of the floor).
func test_the_drawer_holds_what_the_guard_can_use() -> void:
	layout = Floor1Layout.create()
	GameState.set_flag(&"curio_astrolabe")
	var mapped := MuseumStory.make(layout, layout.markers)
	mapped.loot_source = func(item: StringName) -> StringName: return &"bullets" if item == &"hunt_rounds" else item
	add_child(mapped)
	assert_eq((mapped.curios[&"astrolabe"] as Curio).pickups[0].type, Pickup.Type.BULLETS)


func test_every_curio_text_reads_and_fits_in_both_languages() -> void:
	for language in ["pl", "en"]:
		Settings.set_value(&"language", language, false)
		var card := _card_on_canvas(Vector2i(1920, 1080))
		for id in Curios.ids():
			var keys := [Curios.title_key(id), Curios.answer_key(id), Curios.prompt_key(id)]
			if id != &"portrait":
				keys.append(Curios.text_key(id))
			for key in keys:
				assert_ne(tr(key), key, "%s in %s" % [key, language])
			var caption := tr("LABEL_CAPTION") % [Curios.number(id), tr("ZONE_ENLIGHTENMENT")]
			for key in keys.slice(1, 2) + keys.slice(3):
				assert_lt(tr(key).length(), 200, "%s %s: short" % [language, key])
				await _check_fits(card, caption, tr(Curios.title_key(id)), tr(key), "%s %s" % [language, key])
		for key in ["CURIO_FOUND", "CURIO_DUST"]:
			assert_ne(tr(key), key)
		assert_true((tr("CURIO_DUST") % 25).contains("25"))


# --- the places the guard comes back to ------------------------------------------------

func test_the_plaque_counts_the_exhibits_returned_to_rest() -> void:
	GameState.voice_state["destroyed"] = 12
	GameState.defeat_guardian(&"colossus")
	_story()
	var plaque := story.plaque
	assert_not_null(plaque)
	assert_eq(plaque.count, 12)
	assert_eq(plaque.wings, 1)
	assert_eq(plaque._number.text, "12")
	assert_eq(plaque.prompt(), "Przeczytaj tablicę")
	GameState.voice_state["destroyed"] = 13
	GameState.defeat_guardian(&"lamassu")
	plaque._process(1.0)
	assert_eq(plaque._number.text, "13", "it keeps count while the guard plays")
	assert_eq(plaque._footer.text, tr("REST_PLAQUE_WINGS") % [2, 6])
	plaque.interact(null)
	assert_eq(story.card.shown[1], tr("REST_PLAQUE_TITLE") % 13)


func test_the_corkboard_pins_the_nights_and_the_wings_notices() -> void:
	var game := PersistentState.new()
	assert_eq(StaffCorkboard.notices(game, 1), [&"SCHEDULE", &"MACHINE", &"MILK"] as Array[StringName], "night 1: the rota after Heniek's leg")
	assert_eq(StaffCorkboard.notices(game, 2), [&"WATCH", &"SCHEDULE", &"MACHINE", &"MILK"] as Array[StringName])
	game.defeat_guardian(&"colossus")
	game.defeat_guardian(&"lamassu")
	game.defeat_guardian(&"centaur")
	assert_eq(StaffCorkboard.notices(game, 5), [&"CENTAUR", &"LAMASSU", &"HENIEK", &"CURATOR"] as Array[StringName], "the last two wings laid to rest first")
	game.defeat_guardian(&"trex")
	assert_eq(StaffCorkboard.notices(game, 5)[0], &"TREX")
	game.free()
	GameState.night = 2
	_story()
	var board := story.corkboard
	assert_not_null(board)
	assert_eq(board.pinned.size(), 4)
	assert_eq(board.get_node(^"Slips").get_child_count(), 4, "a slip for each notice")
	assert_eq(board.prompt(), "Przeczytaj ogłoszenia")
	board.interact(null)
	assert_eq(story.card.shown[1], tr("CORK_TITLE") % 2)
	for notice in board.pinned:
		assert_true(story.card.shown[2].contains(tr(StaffCorkboard.text_key(notice))), "%s on the card" % notice)


func test_every_notice_reads_short_and_a_full_board_fits() -> void:
	for language in ["pl", "en"]:
		Settings.set_value(&"language", language, false)
		var longest: Array[String] = []
		for notice: StringName in StaffCorkboard.NOTICES:
			var text := tr(StaffCorkboard.text_key(notice))
			assert_ne(text, StaffCorkboard.text_key(notice), "%s in %s" % [notice, language])
			assert_lt(text.length(), 105, "%s %s: a slip, not a letter (%d)" % [language, notice, text.length()])
			assert_true(text.contains("— "), "%s %s: signed" % [language, notice])
			longest.append(text)
		longest.sort_custom(func(a: String, b: String) -> bool: return a.length() > b.length())
		var card := _card_on_canvas(Vector2i(1920, 1080))
		await _check_fits(card, tr("CORK_CAPTION"), tr("CORK_TITLE") % 9, "\n".join(longest.slice(0, StaffCorkboard.MOST)), "%s: the fullest board" % language)
		for key in ["REST_PLAQUE_HEADING", "REST_PLAQUE_WINGS", "REST_PLAQUE_CAPTION", "REST_PLAQUE_TITLE", "REST_PLAQUE_TEXT", "PROMPT_READ_PLAQUE", "PROMPT_READ_BOARD"]:
			assert_ne(tr(key), key, "%s in %s" % [key, language])
		await _check_fits(card, tr("REST_PLAQUE_CAPTION"), tr("REST_PLAQUE_TITLE") % 1234, tr("REST_PLAQUE_TEXT") % [6, 6], "%s: the plaque" % language)


## The CCTV's log page: a line per wing in its state, the exhibits at rest;
## every line fits the status screen.
func test_the_shift_log_tells_each_wing_and_fits_the_status_screen() -> void:
	layout = Floor1Layout.create()
	var game := PersistentState.new()
	assert_eq(ShiftLog.wing_state(game, layout, &"egypt"), ShiftLog.State.NO_SIGNAL)
	game.visit_room(&"egypt_gallery")
	assert_eq(ShiftLog.wing_state(game, layout, &"egypt"), ShiftLog.State.AWAKE)
	game.defeat_guardian(&"colossus")
	assert_eq(ShiftLog.wing_state(game, layout, &"egypt"), ShiftLog.State.AT_REST)
	assert_true(ShiftLog.room_at_rest(game, layout, &"egypt_tombs"))
	assert_false(ShiftLog.room_at_rest(game, layout, &"assyria_gate"))
	assert_false(ShiftLog.room_at_rest(game, layout, &"court"), "the hub is never at rest")
	game.voice_state["destroyed"] = 1234
	for language in ["pl", "en"]:
		Settings.set_value(&"language", language, false)
		var lines := ShiftLog.lines(game, layout)
		assert_eq(lines.size(), 8, "a heading, six wings, the count")
		assert_true(lines[-1].contains("1234"))
		var font := UiTheme.device_font()
		for wing_state in ShiftLog.State.values():
			for wing in Floor1Plan.WINGS:
				var line := tr("SHIFT_WING_" + String(wing).to_upper()).to_upper().rpad(ShiftLog.NAME_WIDTH) + tr(ShiftLog.STATE_KEYS[wing_state]).to_upper()
				assert_lt(font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x, float(Cctv.STATUS_SIZE.x) - 28.0, "%s: %s fits" % [language, line])
		for line in lines:
			assert_lt(font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x, float(Cctv.STATUS_SIZE.x) - 28.0, "%s: %s fits" % [language, line])
		assert_lt(lines.size() * font.get_height(15) + 8.0, float(Cctv.STATUS_SIZE.y) - 16.0, "eight lines fit the screen")
	game.free()


## A camera in a wing at rest says so on its picture (when nothing moves).
func test_a_feed_of_a_wing_at_rest_says_so() -> void:
	var spec: CctvCatalog.Camera = CctvCatalog.cameras()[0]
	var feed := CctvFeed.make(spec, Cctv.make_environment())
	add_child(feed)
	feed.set_calm(true)
	feed.render_once("00:00:00")
	assert_true(feed._calm_label.visible)
	assert_eq(feed._calm_label.text, "● " + tr("CCTV_CALM").to_upper())
	feed.set_motion(true)
	feed.render_once("00:00:01")
	assert_false(feed._calm_label.visible, "motion first")
	assert_true(feed._motion_label.visible)


# --- in the game ----------------------------------------------------------------------

## Floor I's game puts the story up: labels, trails, curios, the plaque, the
## corkboard, and the shift's log on the booth's CCTV.
func test_the_floor_game_tells_the_museums_story() -> void:
	Museum.level_id = &"floor1"
	GameState.new_game()
	var museum := (load(SceneFlow.MUSEUM) as PackedScene).instantiate() as Museum
	add_child(museum)
	await physics_frames(2)
	var told := museum.floor_game.story
	assert_not_null(told)
	if told != null:
		assert_eq(told.labels.size(), ExhibitLabels.ids().size())
		assert_eq(told.curios.size(), Curios.ids().size())
		assert_eq(told.examines.size(), Floor1Plan.WINGS.size())
		assert_not_null(told.plaque)
		assert_not_null(told.corkboard)
		assert_eq(told.banner, museum.floor_game.world.hud)
		assert_eq(told.guard(), museum.player)
	var cctv := museum.floor_game.world.cctv
	assert_true(cctv.log_source.is_valid(), "the CCTV keeps the shift's log")
	assert_true(cctv.calm_source.is_valid())
	cctv._page_time = Cctv.STATUS_PAGE + 0.1
	cctv._update_status()
	assert_true(cctv.status_text().begins_with(tr("SHIFT_LOG").to_upper()), "its second page")
	cctv._page_time = 0.0
	cctv._update_status()
	assert_false(cctv.status_text().begins_with(tr("SHIFT_LOG").to_upper()), "then motion again")
	museum.free()


## Jolt's body limit must leave room for this many Floor I's worth of bodies
## (the next test says why).
const BODY_HEADROOM := 5


## A museum freed and built again within one physics frame - what a test
## does, and what a scene swap does (Godot takes the old scene out and puts
## the new one in during the same frame, no physics step between). Jolt
## keeps the old bodies' broadphase nodes until its next update and the new
## floor's few thousand bodies come in one at a time; with too small a body
## limit (physics/jolt_physics_3d/limits/max_bodies, which sizes the node
## pool) the first query after the rebuild runs the pool dry and Jolt aborts
## the process ("QuadTree: Out of nodes!": exit code 3, nothing printed).
## The story layer comes back whole, and the limit keeps its headroom over
## the floor's bodies.
func test_the_story_survives_the_museum_freed_and_built_again_in_one_frame() -> void:
	Museum.level_id = &"floor1"
	GameState.new_game()
	var museum := (load(SceneFlow.MUSEUM) as PackedScene).instantiate() as Museum
	add_child(museum)
	await physics_frames(2)
	var bodies := museum.find_children("*", "CollisionObject3D", true, false).size()
	var limit := int(ProjectSettings.get_setting("physics/jolt_physics_3d/limits/max_bodies", 10240))
	assert_gt(limit, bodies * BODY_HEADROOM, "the body limit (%d) leaves room for %d x the floor's %d bodies" % [limit, BODY_HEADROOM, bodies])
	if limit <= bodies * BODY_HEADROOM:
		museum.free()
		return   # the swaps below could abort the whole run: this failure says why
	for i in 2:
		museum.free()
		museum = (load(SceneFlow.MUSEUM) as PackedScene).instantiate() as Museum
		add_child(museum)
	await physics_frames(3)
	var told := museum.floor_game.story
	assert_not_null(told)
	if told != null:
		assert_eq(told.labels.size(), ExhibitLabels.ids().size(), "every label is back")
		assert_eq(told.curios.size(), Curios.ids().size())
		assert_eq(told.examines.size(), Floor1Plan.WINGS.size())
		assert_not_null(told.plaque)
		assert_not_null(told.corkboard)
		assert_true(museum.floor_game.world.cctv.log_source.is_valid(), "the CCTV's shift log is wired to the new floor")
	museum.free()
