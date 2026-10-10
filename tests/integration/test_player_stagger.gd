extends TestCase
## The guard staggered by a Fu dog's roar (Player.stagger): he barely
## moves, cannot dash, fire nor punch for the stagger's length, then all
## comes back.

var player: Player


func before_each() -> void:
	Greybox.box(self, Vector3(0, -0.5, 0), Vector3(60, 1, 60), Color.GRAY)
	player = Player.new()
	player.position = Vector3(0, 0.05, 0)
	add_child(player)


func _walked(frames: int) -> float:
	var from := player.global_position
	Input.action_press(&"move_forward")
	await physics_frames(frames)
	Input.action_release(&"move_forward")
	return Vector2(player.global_position.x - from.x, player.global_position.z - from.z).length()


func test_a_stagger_slows_him_to_a_crawl_and_then_lets_go() -> void:
	await physics_frames(5)
	var free := await _walked(20)
	await physics_frames(20)
	player.stagger(0.5)
	assert_true(player.staggered())
	var reeling := await _walked(20)
	assert_lt(reeling, free * 0.3, "reels: %.2f m against %.2f m" % [reeling, free])
	await physics_frames(20)
	assert_false(player.staggered(), "over after half a second")


func test_no_dash_no_shot_while_staggered() -> void:
	var state := player.weapons.give(load("res://src/weapons/data/pistol.tres"))
	player.weapons.select_id(&"pistol")
	await physics_frames(5)
	var rounds := state.magazine
	player.stagger(0.5)
	assert_false(player.dash(Vector3.FORWARD), "no dash")
	assert_true(player.weapons.dazed())
	Input.action_press(&"fire")
	await physics_frames(10)
	Input.action_release(&"fire")
	assert_eq(state.magazine, rounds, "the trigger does nothing")
	await physics_frames(30)
	assert_false(player.weapons.dazed())
	Input.action_press(&"fire")
	await physics_frames(2)
	Input.action_release(&"fire")
	assert_lt(state.magazine, rounds, "fires again")


func test_respawn_clears_a_stagger() -> void:
	player.stagger(2.0)
	player.respawn(Vector3(0, 0.05, 0))
	assert_false(player.staggered())
