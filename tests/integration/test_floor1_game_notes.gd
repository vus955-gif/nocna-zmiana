extends TestCase
## Floor I's notes in the game: every one of them reads at a good size on a
## 1080p screen (a long one gets a wider sheet before it shrinks), and the
## pause menu lists every note read, grouped by wing, each with its writer.

## The smallest a sheet may be scaled to on a 1920x1080 screen.
const MIN_SCALE := 0.8

var museum: Museum


func before_each() -> void:
	Museum.level_id = &"floor1"


func after_each() -> void:
	if is_instance_valid(museum):
		museum.free()


## Every note id with a title in the translations (Floor I's and the lobby's).
func _note_ids() -> Array[StringName]:
	var found: Array[StringName] = []
	var pattern := RegEx.create_from_string("^(NOTE_[A-Z_]+_[0-9]+|NOTE_KEY|NOTE_[A-Z]+)_TITLE,")
	for line in FileAccess.get_file_as_string("res://locale/strings.csv").split("\n"):
		var hit := pattern.search(line)
		if hit != null:
			found.append(StringName(hit.get_string(1).to_lower()))
	return found


func test_every_note_reads_at_a_good_size_at_1080p() -> void:
	var reader := NoteReader.new()
	reader.game = PersistentState.new()
	reader.screen_override = Vector2(1920, 1080)
	add_child(reader)
	var smallest := 1.0
	var widest := 0.0
	var ids := _note_ids()
	assert_gt(ids.size(), 20, "the floor's notes are written")
	for id in ids:
		if not NoteCatalog.is_note(id):
			continue
		reader.open_note(id)
		await get_tree().process_frame
		await get_tree().process_frame
		var rect := reader.paper_rect()
		var shown := reader._paper.scale.x
		smallest = minf(smallest, shown)
		widest = maxf(widest, reader._paper.size.x)
		assert_true(shown >= MIN_SCALE, "%s shrinks to %.2f" % [id, shown])
		assert_lt(rect.size.y, 1080.0, "%s fits the screen's height" % id)
		reader.close()
		await get_tree().process_frame
	print("  %d notes: smallest scale %.2f, widest sheet %d px" % [ids.size(), smallest, widest])
	reader.game.free()
	reader.free()


func test_the_pause_menu_lists_every_note_read_by_wing() -> void:
	GameState.new_game()
	for id: StringName in [&"note_egypt_2", &"note_court_1", &"note_key", &"note_egypt_1"]:
		NoteCatalog.read(GameState, id)
	museum = (load(SceneFlow.MUSEUM) as PackedScene).instantiate() as Museum
	add_child(museum)
	await physics_frames(2)
	var menu := museum.pause_menu
	menu.open()
	menu.open_notes()
	assert_true(menu.notes_shown())
	assert_eq(menu.listed_notes(), [NoteCatalog.title(&"note_key"), NoteCatalog.title(&"note_court_1"), NoteCatalog.title(&"note_egypt_1"), NoteCatalog.title(&"note_egypt_2")] as Array[String], "by wing, then by number")
	assert_eq(menu.listed_groups(), [tr("ZONE_BOOTH").to_upper(), tr("ZONE_COURT").to_upper(), tr("ZONE_EGYPT").to_upper()] as Array[String])
	var entry := menu._notes_list.get_node(^"note_egypt_1") as Button
	var writer := entry.get_node_or_null(^"Signature") as Label
	assert_not_null(writer, "each with its writer")
	if writer != null:
		assert_eq(writer.text, tr("NOTE_EGYPT_1_SIGN"))
	assert_true(menu._notes_scroll.custom_minimum_size.y > 0.0, "a scrolling list")
	menu.read_note(&"note_egypt_1")
	assert_true(museum.floor_game.world.reader.is_open)
	museum.floor_game.world.reader.close()
	menu.close()
