extends TestCase
## The reactive environment and the save (plan docs/superpowers/plans/
## 2026-10-21-srodowisko-walka.md, QA #51): what broke tonight - glass, a
## bust, a lamp shot down, a tool gone off - is broken again when the night
## is left through the menu and continued from the file (the world snapshot
## the same), and a new night starts with the museum whole again.

var museum: Museum


func before_each() -> void:
	Museum.level_id = &"floor1"


func after_each() -> void:
	if is_instance_valid(museum):
		museum.free()


func _museum() -> Museum:
	museum = (load(SceneFlow.MUSEUM) as PackedScene).instantiate() as Museum
	add_child(museum)
	return museum


func _first(env: EnvLayer, type: Variant, wanted: Callable = Callable()) -> EnvProp:
	for each in env.props:
		if is_instance_of(each, type) and (not wanted.is_valid() or wanted.call(each)):
			return each
	return null


## Breaks a case, a bust, a pendant and the library's bookcase; returns
## their ids.
func _break_things(env: EnvLayer) -> Array[StringName]:
	var glass := _first(env, EnvGlass) as EnvGlass
	var bust := _first(env, EnvBust) as EnvBust
	var lamp := _first(env, EnvLamp, func(p: EnvProp) -> bool: return (p as EnvLamp).kind == &"ceiling_lamp") as EnvLamp
	var bookcase: EnvTool = null
	for each in env.tools:
		if each.id == &"bookcase_library":
			bookcase = each
	glass.shatter()
	bust.topple()
	lamp.come_down()
	bookcase.trigger()
	await physics_frames(roundi(3.0 * Engine.physics_ticks_per_second))
	return [glass.id, bust.id, lamp.id, bookcase.id] as Array[StringName]


func test_what_broke_tonight_is_broken_again_when_the_night_is_continued() -> void:
	GameState.new_game()
	GameState.save_game()
	_museum()
	await physics_frames(3)
	var broken := await _break_things(museum.floor_game.env)
	for id in broken:
		assert_true(museum.floor_game.env.prop(id).is_down, "%s is down" % id)
	museum.quit_to_menu()
	await physics_frames(1)
	var before := Floor1WorldSnapshot.take(museum)
	museum.free()
	RunState.reset()
	GameState.reset()
	assert_true(GameState.load_game(), "the save loads")
	_museum()
	await physics_frames(3)
	var after := Floor1WorldSnapshot.take(museum)
	var env := museum.floor_game.env
	for id in broken:
		assert_true(env.prop(id).is_down, "%s is down again" % id)
	var compared := 0
	for key: String in (before["things"] as Dictionary):
		if not key.begins_with("Env"):
			continue
		compared += 1
		assert_true((after["things"] as Dictionary).has(key), "%s is there again" % key)
		if (after["things"] as Dictionary).has(key):
			assert_eq(JSON.stringify(after["things"][key]), JSON.stringify(before["things"][key]), "%s as it was left" % key)
	assert_gt(float(compared), 200.0, "the snapshot holds the floor's props")
	var bookcase := env.prop(&"bookcase_library") as EnvToppleTool
	assert_eq((bookcase.load_node as StaticBody3D).collision_layer, 0, "the bookcase lies where it fell, blocking nobody")
	assert_lt(bookcase.load_node.global_basis.y.normalized().dot(Vector3.UP), 0.2)


func test_a_new_night_finds_the_museum_whole() -> void:
	GameState.new_game()
	GameState.save_game()
	_museum()
	await physics_frames(3)
	var broken := await _break_things(museum.floor_game.env)
	museum.free()
	RunState.reset()
	GameState.night += 1
	GameState.night_progress = {}
	GameState.save_game()
	_museum()
	await physics_frames(3)
	var env := museum.floor_game.env
	for id in broken:
		assert_false(env.prop(id).is_down, "%s is whole again the next night" % id)
	for each in env.props:
		assert_false(each.is_down, "%s whole" % each.id)
