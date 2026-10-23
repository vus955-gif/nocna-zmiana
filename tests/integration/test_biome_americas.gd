extends TestCase
## The Americas' sacred fire (plan 2026-10-21-mechaniki-biomow, mechanic 6)
## in a sandbox: a shot puts a fire bowl out (its light, flame and sparks go,
## smoke rises), it rekindles by itself after a while with a flicker of its
## embers first, a fire shot or a flare burning by it lights it at once; the
## totems see the guard only in firelight (or by his own torch), so a guard
## in the dark - or in a room whose bowl is out - is out of their sight. The
## fire keeps out of the power's way: it never switches the lamp itself (a
## blackout or a dark room does that), a power cut does not relight a doused
## bowl and a bowl without power is no light the totems see by.

const BOWL := Vector3(5.0, 0.0, 0.0)

var host: BiomeMechanics
var fire: SacredFire
var sight: TotemSight
var player: Player
var lamp: OmniLight3D
var flame: MeshInstance3D
var sparks: GPUParticles3D


func before_each() -> void:
	GameInput.capture_allowed = false
	Greybox.box(self, Vector3(0, -0.5, 0), Vector3(60, 1, 60), Color.GRAY)
	player = Player.new()
	player.position = Vector3(-10, 0.05, 10)
	add_child(player)
	host = BiomeMechanics.new()
	host.guard_source = func() -> Player: return player
	add_child(host)
	lamp = OmniLight3D.new()
	lamp.position = BOWL + Vector3.UP * 1.3
	add_child(lamp)
	flame = MeshInstance3D.new()
	flame.mesh = BoxMesh.new()
	add_child(flame)
	sparks = GPUParticles3D.new()
	sparks.emitting = true
	add_child(sparks)
	fire = SacredFire.create(BOWL, LightSpec.make(LightSpec.MAIN, BOWL + Vector3.UP * 1.3, NW_FIRE, 1.6, 7.0, &""))
	fire.light = lamp
	fire.flame = flame
	fire.motes.append(sparks)
	host.adopt(fire, &"americas_test_fire", &"")
	sight = TotemSight.create([fire])
	host.adopt(sight, &"americas_test_sight", &"")
	await physics_frames(2)


func after_each() -> void:
	GameInput.capture_allowed = true


## The fire bowls' colour (zones/northwest_kit.gd FIRE).
const NW_FIRE := Color(1.0, 0.5, 0.2)


func _seconds(time: float) -> void:
	await physics_frames(roundi(time * Engine.physics_ticks_per_second))


func _shot(kind: DamageInfo.Kind = DamageInfo.Kind.BALLISTIC) -> void:
	var info := DamageInfo.make(15.0, kind, player)
	info.position = BOWL + Vector3.UP
	fire.take_damage(info)


func _totem() -> Totem:
	var totem := Totem.new()
	totem.faces = 3
	totem.target = player
	totem.position = Vector3(0, 0, -8)
	add_child(totem)
	return totem


func test_a_shot_puts_the_bowl_out() -> void:
	assert_true(fire.burning)
	_shot()
	assert_false(fire.burning, "out")
	assert_almost_eq(lamp.light_energy, 0.0, 0.001, "its light is gone")
	assert_true(lamp.visible, "the lamp's own switch (the power's) is left alone")
	assert_almost_eq(flame.transparency, 1.0, 0.001, "its flame")
	assert_almost_eq(sparks.amount_ratio, 0.0, 0.001, "its sparks")
	assert_eq(fire.douses, 1)
	_shot()
	assert_eq(fire.douses, 1, "nothing more to put out")


func test_it_rekindles_by_itself_after_a_flicker_of_embers() -> void:
	_shot()
	await _seconds(SacredFire.REKINDLE - SacredFire.REKINDLE_TELL - 0.5)
	assert_false(fire.burning)
	assert_false(fire.kindling(), "the embers lie still")
	await _seconds(1.0)
	assert_true(fire.kindling(), "the embers flicker: it is coming back")
	assert_gt(SacredFire.REKINDLE_TELL, 0.6)
	await _seconds(SacredFire.REKINDLE_TELL)
	assert_true(fire.burning, "alight again")
	assert_gt(lamp.light_energy, 0.5)
	assert_almost_eq(flame.transparency, 0.0, 0.001)
	assert_almost_eq(sparks.amount_ratio, 1.0, 0.001)


func test_a_fire_shot_or_a_flare_by_it_lights_it_at_once() -> void:
	_shot()
	_shot(DamageInfo.Kind.FIRE)
	assert_true(fire.burning, "the flare gun's round lit it")
	_shot()
	var flare := FlareLight.new()
	flare.light_time = 10.0
	flare.position = BOWL + Vector3(0.6, 0.1, 0.4)
	add_child(flare)
	await _seconds(0.5)
	assert_true(fire.burning, "a flare burning by the bowl lights it")


func test_totems_see_the_guard_only_in_firelight() -> void:
	var totem := _totem()
	var full := totem.sight_range
	player.global_position = BOWL + Vector3(1.0, 0.05, 1.0)
	await _seconds(0.4)
	assert_true(sight.guard_lit, "by the fire")
	assert_almost_eq(totem.sight_range, full, 0.01, "the totem sees him there")
	player.global_position = Vector3(-10, 0.05, 10)
	await _seconds(0.4)
	assert_false(sight.guard_lit, "in the dark")
	assert_almost_eq(totem.sight_range, TotemSight.BLIND_RANGE, 0.01, "blind but for its close sense")
	player.set_flashlight(true)
	await _seconds(0.4)
	assert_almost_eq(totem.sight_range, full, 0.01, "his torch gives him away")


func test_a_doused_bowl_hides_the_guard_beside_it() -> void:
	var totem := _totem()
	player.global_position = BOWL + Vector3(1.0, 0.05, 1.0)
	_shot()
	await _seconds(0.4)
	assert_false(sight.guard_lit)
	assert_almost_eq(totem.sight_range, TotemSight.BLIND_RANGE, 0.01)


func test_a_blackout_neither_relights_a_doused_bowl_nor_is_fought() -> void:
	var energy := lamp.light_energy
	_shot()
	# the power goes and comes back (a blackout, a dark room): NightModifiers
	# switches the lamps by their visibility
	lamp.visible = false
	await physics_frames(2)
	lamp.visible = true
	await physics_frames(2)
	assert_false(fire.burning)
	assert_almost_eq(lamp.light_energy, 0.0, 0.001, "still out")
	assert_almost_eq(flame.transparency, 1.0, 0.001)
	assert_almost_eq(sparks.amount_ratio, 0.0, 0.001)
	lamp.visible = false
	fire.kindle()
	assert_true(fire.burning)
	assert_false(lamp.visible, "rekindled in a power cut: the lamp stays switched off")
	assert_almost_eq(lamp.light_energy, energy, 0.001, "it glows when the power comes back")


func test_the_totems_see_by_a_bowl_only_while_it_has_fire_and_power() -> void:
	var totem := _totem()
	var full := totem.sight_range
	player.global_position = BOWL + Vector3(1.0, 0.05, 1.0)
	await _seconds(0.4)
	assert_almost_eq(totem.sight_range, full, 0.01, "by the burning bowl")
	lamp.visible = false
	await _seconds(0.4)
	assert_false(sight.guard_lit, "the blackout took the fire's glow")
	assert_almost_eq(totem.sight_range, TotemSight.BLIND_RANGE, 0.01)
	lamp.visible = true
	await _seconds(0.4)
	assert_almost_eq(totem.sight_range, full, 0.01, "the power back, the fire back")


func test_dawn_stops_the_fire_as_it_is() -> void:
	_shot()
	host.freeze()
	await _seconds(SacredFire.REKINDLE + 1.0)
	assert_false(fire.burning, "dawn leaves it cold")
