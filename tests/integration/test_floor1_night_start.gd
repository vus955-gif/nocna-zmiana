extends TestCase
## How long a night on Floor I takes to start (the museum's whole _ready:
## the level read from its shell cache and built, the navigation, the
## exhibits, the floor's game), cold and again; printed for the report
## (tests/_out/floor1_night_start.json). The shell comes from its cache:
## a night start never carves when the cache is current.

const REPORT := "res://tests/_out/floor1_night_start.json"


func before_each() -> void:
	Museum.level_id = &"floor1"


func _start() -> Dictionary:
	var started := Time.get_ticks_msec()
	var museum := (load(SceneFlow.MUSEUM) as PackedScene).instantiate() as Museum
	add_child(museum)
	var result := {"msec": Time.get_ticks_msec() - started, "build_msec": museum.floor_level.build_msec, "bake_msec": museum.floor_level.bake_msec}
	assert_not_null(museum.floor_game)
	museum.free()
	return result


func test_a_night_starts_quickly() -> void:
	GameState.new_game()
	Museum.prepare_level()   # what the loading screen does first
	var first := _start()
	var again := _start()
	assert_lt(int(first["build_msec"]), 2000, "the level is built, not carved (%d ms)" % first["build_msec"])
	var report := {"first": first, "again": again}
	print("Floor I night start: %s" % JSON.stringify(report))
	var file := FileAccess.open(REPORT, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "\t"))
