extends TestCase


func test_every_game_sound_has_a_generated_file() -> void:
	for sound in Sfx.SOUNDS:
		assert_true(ResourceLoader.exists("res://assets/sfx/%s.wav" % sound), "missing " + str(sound))


func test_stop_all_silences_everything() -> void:
	Sfx.play(&"pistol")
	Sfx.play_at(&"block", Vector3.ZERO)
	assert_gt(Sfx.get_child_count(), 0)
	Sfx.stop_all()
	assert_eq(Sfx.get_child_count(), 0)


func test_material_sounds_are_on_the_list() -> void:
	for kind in ExhibitMaterial.Kind.values():
		assert_true(Sfx.SOUNDS.has(ExhibitMaterial.hit_sound(kind)), str(ExhibitMaterial.hit_sound(kind)))
		assert_true(Sfx.SOUNDS.has(ExhibitMaterial.break_sound(kind)), str(ExhibitMaterial.break_sound(kind)))
