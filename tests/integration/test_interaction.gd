extends TestCase
## The guard's use-probe (E), Interactable areas and the HUD prompt.

var player: Player


func before_each() -> void:
	Greybox.box(self, Vector3(0, -0.5, 0), Vector3(20, 1, 20), Color.GRAY)
	player = Player.new()
	player.position = Vector3(0, 0.05, 0)
	add_child(player)


## An interactable box at eye height, [param distance] metres ahead.
func _thing(distance: float) -> Interactable:
	var thing := Interactable.new()
	thing.prompt_key = "PROMPT_USE"
	thing.add_box(Vector3(0.6, 0.6, 0.2))
	thing.position = Vector3(0, 1.65, -distance)
	add_child(thing)
	return thing


func test_interactable_sits_on_the_interact_layer() -> void:
	var thing := _thing(1.5)
	assert_eq(thing.collision_layer, Layers.INTERACT)
	assert_eq(thing.collision_mask, 0)


func test_guard_focuses_an_interactable_within_reach() -> void:
	var thing := _thing(1.8)
	var changes := watch(player.interactor.focus_changed)
	await physics_frames(4)
	assert_eq(player.interactor.focus, thing)
	assert_eq(changes.size(), 1)


func test_the_probe_reuses_one_ray_every_frame() -> void:
	var thing := _thing(1.8)
	await physics_frames(2)
	var query: PhysicsRayQueryParameters3D = player.interactor._query
	assert_not_null(query)
	thing.position.x = 5.0   # out of sight: the same ray finds nothing
	await physics_frames(3)
	assert_eq(player.interactor._query, query, "made once")
	assert_true(player.interactor.focus == null)
	thing.position.x = 0.0
	await physics_frames(3)
	assert_eq(player.interactor.focus, thing, "and still finds things")


func test_nothing_is_focused_beyond_reach() -> void:
	_thing(Interactor.REACH + 0.6)
	await physics_frames(4)
	assert_true(player.interactor.focus == null)


func test_walls_block_interaction() -> void:
	_thing(1.8)
	Greybox.box(self, Vector3(0, 1.5, -1.0), Vector3(3, 3, 0.2), Color.GRAY)
	await physics_frames(4)
	assert_true(player.interactor.focus == null)


func test_interact_key_calls_interact_with_the_guard() -> void:
	var thing := _thing(1.5)
	var used := watch(thing.interacted)
	await physics_frames(4)
	Input.action_press(&"interact")
	await physics_frames(1)
	Input.action_release(&"interact")
	await physics_frames(2)
	assert_eq(used.size(), 1)
	if used.size() == 1:
		assert_eq(used[0][0], player)


func test_disabled_interactable_is_ignored() -> void:
	var thing := _thing(1.5)
	thing.enabled = false
	var used := watch(thing.interacted)
	await physics_frames(4)
	assert_true(player.interactor.focus == null)
	assert_false(player.interactor.try_interact(player))
	assert_eq(used.size(), 0)


func test_dead_guard_cannot_interact() -> void:
	var thing := _thing(1.5)
	var used := watch(thing.interacted)
	await physics_frames(4)
	player.take_damage(DamageInfo.make(500.0, DamageInfo.Kind.BLUNT))
	await physics_frames(2)
	assert_true(player.interactor.focus == null)
	Input.action_press(&"interact")
	await physics_frames(1)
	Input.action_release(&"interact")
	assert_eq(used.size(), 0)


func test_hud_shows_the_prompt_with_the_key() -> void:
	var hud := Hud.new()
	hud.player = player
	add_child(hud)
	await physics_frames(2)
	assert_false(hud._prompt.visible, "nothing in reach yet")
	_thing(1.5)
	await physics_frames(4)
	await get_tree().process_frame
	assert_true(hud._prompt.visible)
	assert_eq(hud._prompt_key.text, "E")
	assert_eq(hud._prompt_label.text, "Użyj")
