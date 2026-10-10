extends TestCase
## Floor I's effects (tools/sfx/floor1_sfx.py): registered, generated, mono,
## the four loops loop, everything else plays once and stays short.

const FLOOR1: Array[StringName] = [
	&"lock_chain_break", &"lock_boards_hit", &"lock_boards_splinter", &"lock_wall_crack", &"lock_wall_collapse",
	&"lock_seal_insert", &"lock_seal_grind", &"lock_shutter_roll", &"lock_power_on", &"lock_bolt_slide",
	&"lock_rope_snap", &"lock_counterweight", &"lock_hook_pull",
	&"mummy_groan", &"mummy_lash", &"scarab_swarm", &"relief_crack", &"relief_scrape", &"book_flap", &"book_flock",
	&"fu_roar", &"totem_spit", &"jaguar_snarl", &"hoplite_shield", &"hoplite_thrust",
	&"colossus_grind", &"colossus_slam", &"colossus_charge", &"colossus_beam", &"lamassu_gust", &"lamassu_stomp",
	&"lamassu_charge", &"centaur_gallop", &"centaur_javelin", &"orrery_gears", &"orrery_sweep", &"samurai_glint",
	&"samurai_slash", &"samurai_volley", &"serpent_hiss", &"serpent_rattle", &"guardian_wake", &"guardian_crumble",
]
const LOOPS: Array[StringName] = [&"scarab_swarm", &"book_flock", &"centaur_gallop", &"orrery_gears"]


func test_every_floor1_sound_is_registered_and_generated() -> void:
	for sound in FLOOR1:
		assert_true(Sfx.SOUNDS.has(sound), "%s in Sfx.SOUNDS" % sound)
		var stream := Sfx.stream_of(sound) as AudioStreamWAV
		assert_not_null(stream, "%s has its file" % sound)
		if stream != null:
			assert_false(stream.stereo, "%s is mono" % sound)
			assert_gt(stream.get_length(), 0.2, String(sound))
			assert_lt(stream.get_length(), 7.0, String(sound) + " stays short")


func test_the_loops_loop_and_the_rest_play_once() -> void:
	for sound in FLOOR1:
		var stream := Sfx.stream_of(sound) as AudioStreamWAV
		if stream == null:
			continue
		if LOOPS.has(sound):
			assert_eq(stream.loop_mode, AudioStreamWAV.LOOP_FORWARD, String(sound) + " loops")
			assert_true(Sfx.LOOPING.has(sound), String(sound) + " is listed as looping")
		else:
			assert_ne(stream.loop_mode, AudioStreamWAV.LOOP_FORWARD, String(sound) + " plays once")

