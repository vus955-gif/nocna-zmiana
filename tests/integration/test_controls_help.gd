extends TestCase
## What names keys follows the player's own: the F1 help and its hint, the
## "[E] ..." prompt, the weapon slots, the terminal's closing hint.

var player: Player
var hud: Hud


func before_each() -> void:
	Greybox.box(self, Vector3(0, -0.5, 0), Vector3(20, 1, 20), Color.GRAY)
	player = Player.new()
	player.position = Vector3(0, 0.05, 0)
	add_child(player)
	hud = Hud.new()
	hud.player = player
	add_child(hud)


func test_the_default_help_reads_like_the_old_one() -> void:
	Settings.set_value(&"language", "en", false)
	var text := ControlsHelp.controls()
	assert_true(text.begins_with("CONTROLS\n"), text)
	for entry in ["WASD — move", "Shift — sprint", "Ctrl / Mouse 4 — dash", "Space — jump", "LMB — fire", "V / RMB — punch",
			"R — reload", "1–8, wheel — weapon", "F — flashlight", "E — use", "F1 — help", "F11 — fullscreen", "Esc — pause"]:
		assert_true(text.contains(entry), "%s in\n%s" % [entry, text])
	Settings.set_value(&"language", "pl", false)
	text = ControlsHelp.controls()
	assert_true(text.begins_with("STEROWANIE\n"), text)
	for entry in ["WSAD — ruch", "Spacja — skok", "LPM — strzał", "V / PPM — cios pięścią", "1–8, kółko — broń", "E — użyj", "Esc — pauza"]:
		assert_true(text.contains(entry), "%s in\n%s" % [entry, text])


func test_the_help_panel_shows_the_controls_and_the_map_line_with_real_keys() -> void:
	hud.help_keys = ["HUD_HELP_CONTROLS_P1", MuseumMap.HELP_KEY, "HUD_HELP_TIPS"]
	hud._refresh_texts()
	var text := hud._help_label.text
	assert_true(text.contains("E — użyj"), text)
	assert_true(text.contains("M — plan muzeum"), text)
	Settings.bind(&"map", 0, KEY_N)
	Settings.bind(&"interact", 0, KEY_Q)
	text = hud._help_label.text
	assert_true(text.contains("Q — użyj"), "the help follows at once:\n" + text)
	assert_false(text.contains("E — użyj"))
	assert_true(text.contains("N — plan muzeum"), text)


func test_the_help_names_every_key_of_an_action_and_mouse_buttons() -> void:
	Settings.bind(&"jump", 1, -MOUSE_BUTTON_MIDDLE)
	Settings.bind(&"fire", 0, KEY_G)
	var text := ControlsHelp.controls()
	assert_true(text.contains("Spacja / ŚPM — skok"), text)
	assert_true(text.contains("G / LPM — strzał") or text.contains("G — strzał"), text)


func test_moving_on_the_arrows_is_written_as_arrows() -> void:
	Settings.bind(&"move_forward", 0, KEY_UP)
	Settings.bind(&"move_back", 0, KEY_DOWN)
	Settings.bind(&"move_left", 0, KEY_LEFT)
	Settings.bind(&"move_right", 0, KEY_RIGHT)
	var text := ControlsHelp.controls()
	assert_true(text.contains("↑↓←→ — ruch"), text)
	Settings.bind(&"move_forward", 0, KEY_F2)
	assert_true(ControlsHelp.controls().contains("F2 ↓ ← → — ruch"), "long names are written apart")


func test_other_weapon_keys_are_listed_when_they_are_not_the_digits() -> void:
	Settings.bind(&"weapon_1", 0, KEY_Z)
	Settings.bind(&"weapon_next", 0, KEY_X)
	var text := ControlsHelp.controls()
	assert_true(text.contains("Z 2 3 4 5 6 7 8, X / "), text)


func test_the_help_hint_names_the_help_key() -> void:
	assert_true(hud._help_hint.text.begins_with("F1"), hud._help_hint.text)
	Settings.bind(&"toggle_help", 0, KEY_H)
	assert_true(hud._help_hint.text.begins_with("H"), hud._help_hint.text)


func test_the_weapon_slots_name_their_keys() -> void:
	assert_eq(hud.slots_text(), "(1) (2) (3) (4) (5) (6) (7) (8)")
	Settings.bind(&"weapon_3", 0, KEY_Z)
	assert_eq(hud.slots_text(), "(1) (2) (Z) (4) (5) (6) (7) (8)")


func test_the_prompt_shows_the_current_key() -> void:
	var thing := Interactable.new()
	thing.prompt_key = "PROMPT_USE"
	thing.add_box(Vector3(0.6, 0.6, 0.2))
	thing.position = Vector3(0, 1.65, -1.5)
	add_child(thing)
	await physics_frames(4)
	await get_tree().process_frame
	assert_true(hud._prompt.visible)
	assert_eq(hud._prompt_key.text, "E")
	Settings.bind(&"interact", 0, KEY_Q)
	await get_tree().process_frame
	assert_eq(hud._prompt_key.text, "Q", "the prompt follows without a new focus")
	Settings.bind(&"interact", 0, -MOUSE_BUTTON_MIDDLE)
	await get_tree().process_frame
	assert_eq(hud._prompt_key.text, tr("BIND_MOUSE_MIDDLE"))


func test_the_terminals_closing_hint_names_the_use_key() -> void:
	Settings.bind(&"interact", 0, KEY_Q)
	var menu := UpgradeMenu.new()
	add_child(menu)
	var hints := menu._build_hints()
	var captions: Array[String] = []
	for caption in hints.get_children():
		captions.append((caption as Label).text)
	assert_true(captions.has("ESC / Q  ZAMKNIJ"), str(captions))
	hints.free()
