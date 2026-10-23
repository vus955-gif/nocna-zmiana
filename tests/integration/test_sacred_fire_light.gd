extends TestCase
## The Americas' sacred fire in the exhibits' light model (plan
## 2026-10-21-srodowisko-walka.md, section 6, fix 8): a doused bowl's
## firelight is gone from the perception's light (LayoutIllumination.put_out),
## and when the bowl burns again - by itself, a fire shot or a flare - it is
## back (put_back). The fire never touches the lamp's group switch: a bowl
## doused and relit follows its circuit's switches like any lamp.

const BOWL := Vector3(5.0, 0.0, 0.0)
const FIRE_COLOR := Color(1.0, 0.5, 0.2)

var host: BiomeMechanics
var fire: SacredFire
var lamp: Light3D
var layout: LevelLayout
var lights: Node3D


func before_each() -> void:
	layout = LevelLayout.new()
	layout.add_room(&"americas_test", [Rect2(-20, -20, 40, 40)] as Array[Rect2], 0.0, 8.0, Color.GRAY)
	var spec := layout.add_light(LightSpec.MAIN, BOWL + Vector3.UP * 1.3, FIRE_COLOR, 1.6, 7.0, &"americas_test")
	lights = Node3D.new()
	lights.name = "Lights"
	add_child(lights)
	lamp = LevelLighting.add_light(lights, spec, Color(0.6, 0.6, 0.6))
	LevelPerception.configure_layout(layout, {}, lights)
	host = BiomeMechanics.new()
	add_child(host)
	fire = SacredFire.create(BOWL, spec)
	fire.light = lamp
	host.adopt(fire, &"americas_test_fire", &"americas_test")
	await physics_frames(2)


func _beside() -> float:
	return PerceptionWorld.light_at(BOWL + Vector3(1.0, 1.0, 0.0))


func test_a_doused_bowl_is_dark_to_the_exhibits_and_lit_again_when_it_burns() -> void:
	var lit := _beside()
	assert_gt(lit, PerceptionRules.LIT_LEVEL, "(control) its firelight")
	assert_true(fire.douse())
	assert_lt(_beside(), PerceptionRules.DIM_LEVEL, "doused: dark beside it")
	assert_true(fire.kindle())
	assert_almost_eq(_beside(), lit, 0.001, "lit again: its light is back")
	# by itself, after a while
	fire.douse()
	await physics_frames(roundi((SacredFire.REKINDLE + 0.5) * Engine.physics_ticks_per_second))
	assert_true(fire.burning, "(control) it rekindled")
	assert_almost_eq(_beside(), lit, 0.001, "rekindled: lit")


func test_a_bowl_relit_is_switched_by_its_circuit_like_any_lamp() -> void:
	fire.douse()
	fire.kindle()
	assert_false(lamp.has_meta(&"env_broken"), "nothing marks it broken for the night (every switch skips such a lamp)")
	lamp.visible = false   # (its circuit switched off: NightModifiers.set_lights)
	assert_lt(_beside(), PerceptionRules.DIM_LEVEL, "the blackout darkens it")
	lamp.visible = true
	assert_gt(_beside(), PerceptionRules.LIT_LEVEL, "and the power back lights it")


func test_a_doused_bowl_stays_dark_to_the_exhibits_when_its_power_comes_back() -> void:
	assert_gt(_beside(), PerceptionRules.LIT_LEVEL, "(control) its firelight")
	fire.douse()
	lamp.visible = false   # (a blackout or a power cut: NightModifiers.set_lights)
	await physics_frames(2)
	assert_lt(_beside(), PerceptionRules.DIM_LEVEL, "doused, without power: dark")
	lamp.visible = true   # (the power back)
	await physics_frames(2)
	assert_false(fire.burning, "(control) the power does not relight a doused bowl")
	assert_lt(_beside(), PerceptionRules.DIM_LEVEL, "nor its light for the exhibits")
	# lit again while the power is off: dark till the power is back
	lamp.visible = false
	assert_true(fire.kindle())
	assert_lt(_beside(), PerceptionRules.DIM_LEVEL, "lit in a blackout: still no light without power")
	lamp.visible = true
	assert_gt(_beside(), PerceptionRules.LIT_LEVEL, "the power back: its firelight")
