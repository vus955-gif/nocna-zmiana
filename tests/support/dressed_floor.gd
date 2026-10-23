class_name DressedFloor
## Floor I dressed, without navigation: the level the Floor I art tests look
## at. Built once per test file by TestCase.shared_fixture() for the tests that only
## look at it; a test that changes it builds its own.


## A dressed Floor I under [param host] (built, no navigation baked).
static func build(host: Node) -> MuseumFloorLevel:
	MuseumFloorLevel.dress_default = true
	var built := MuseumFloorLevel.new()
	built.bake_navigation = false
	host.add_child(built)
	built.build()
	return built
