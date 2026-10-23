extends TestCase
## The light the biome devices add to the perception world
## (PerceptionWorld.light_sources: the Helios beam lights the guard): one
## source per lamp, out again when the lamp goes (a night rebuilt leaves no
## stale one), dark while the lamp is not lit and when dawn puts it out, and
## a reset of the world clears them all - a lamp struck after that registers
## again (plan 2026-10-21-mechaniki-biomow, "Poprawki po przeglądzie" 6).

const LAMP := Vector3(-9.8, 3.0, 0.0)
const MIRROR := Vector3(9.8, 1.5, 0.0)
const MARKS: Array[Vector3] = [Vector3(-9.0, 1.3, 6.0), Vector3(4.0, 1.3, -12.0)]

var host: BiomeMechanics
var lamp: HeliosLamp
var player: Player


func before_each() -> void:
	GameInput.capture_allowed = false
	Greybox.box(self, Vector3(0, -0.5, 0), Vector3(40, 1, 40), Color.GRAY)
	Greybox.box(self, Vector3(10.5, 3.0, 0), Vector3(1, 6, 30), Color.GRAY)
	Greybox.box(self, Vector3(-10.5, 3.0, 0), Vector3(1, 6, 30), Color.GRAY)
	Greybox.box(self, Vector3(0, 3.0, -15.5), Vector3(22, 6, 1), Color.GRAY)
	player = Player.new()
	player.position = Vector3(0, 0.05, 12)
	add_child(player)
	PerceptionWorld.reset()
	_dark_world()
	await _build()


func after_each() -> void:
	GameInput.capture_allowed = true


func _dark_world() -> void:
	PerceptionWorld.configure(func(_p: Vector3) -> float: return 0.0, Callable(), null, Callable())


## A night's devices: the host with the mirror and the lamp.
func _build() -> void:
	host = BiomeMechanics.new()
	host.guard_source = func() -> Player: return player
	add_child(host)
	var mirror := BronzeMirror.create({"at": MIRROR, "face": Vector3(-1, 0, 0), "marks": MARKS})
	host.adopt(mirror, &"light_test_mirror", &"")
	lamp = HeliosLamp.create({"at": LAMP, "face": Vector3(1, 0, 0), "aim": MIRROR}, [mirror])
	host.adopt(lamp, &"light_test_lamp", &"")
	await physics_frames(2)


## A point in the beam's first leg (the guard's chest, were he standing there).
func _in_the_beam() -> Vector3:
	var lane := MIRROR.lerp(MARKS[0], 0.5)
	return Vector3(lane.x, 1.0, lane.z)


func _strike() -> void:
	lamp.lever.interact(player)
	await physics_frames(3)


func test_a_lamp_registers_one_source_and_takes_it_out_when_it_goes() -> void:
	assert_eq(PerceptionWorld.light_sources.size(), 1, "one lamp, one source")
	host.queue_free()
	await physics_frames(2)
	assert_eq(PerceptionWorld.light_sources.size(), 0, "gone with the lamp: no stale source for the next night")


func test_a_night_rebuilt_has_one_source_and_the_old_beam_does_not_linger() -> void:
	await _strike()
	assert_almost_eq(PerceptionWorld.light_at(_in_the_beam()), 1.0, 0.001, "the first night's beam")
	host.queue_free()
	await physics_frames(2)
	await _build()
	assert_eq(PerceptionWorld.light_sources.size(), 1, "the rebuilt night has its own source only")
	assert_false(lamp.lit, "a fresh lamp is not lit")
	assert_almost_eq(PerceptionWorld.light_at(_in_the_beam()), 0.0, 0.001, "and the old beam's light did not outlive it")


func test_an_unlit_lamp_adds_no_light_and_dawn_takes_the_beam_away() -> void:
	assert_almost_eq(PerceptionWorld.light_at(_in_the_beam()), 0.0, 0.001, "dark before it is struck")
	await _strike()
	assert_almost_eq(PerceptionWorld.light_at(_in_the_beam()), 1.0, 0.001, "lit in the beam")
	host.freeze()
	assert_almost_eq(PerceptionWorld.light_at(_in_the_beam()), 0.0, 0.001, "dawn puts the light out")


func test_a_reset_of_the_world_clears_every_source_and_a_struck_lamp_registers_again() -> void:
	var extra := func(_p: Vector3) -> float: return 0.0
	PerceptionWorld.light_sources.append(extra)
	PerceptionWorld.reset()
	assert_eq(PerceptionWorld.light_sources.size(), 0, "a reset clears them all")
	assert_almost_eq(PerceptionWorld.light_at(Vector3.ZERO), 1.0, 0.001, "the default world is lit")
	_dark_world()
	await _strike()
	assert_true(lamp.lit)
	assert_almost_eq(PerceptionWorld.light_at(_in_the_beam()), 1.0, 0.001, "the lamp that outlived the reset lights the guard again")
	assert_eq(PerceptionWorld.light_sources.size(), 1, "and registered once, not once per strike")
