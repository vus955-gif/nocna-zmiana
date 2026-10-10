extends TestCase
## The six night artifacts: the same ids as NightDirector draws, texts in
## both languages, and the effect strengths of spec 7.4.


func after_each() -> void:
	Settings.reset_to_defaults(false)


func test_the_catalog_matches_the_director() -> void:
	assert_eq(ArtifactCatalog.IDS, NightDirector.ARTIFACTS)
	assert_eq(ArtifactCatalog.JANITOR_KEY, NightDirector.JANITOR_KEY)


func test_loot_items_are_told_apart() -> void:
	for id in ArtifactCatalog.IDS:
		assert_true(ArtifactCatalog.is_artifact(id))
		assert_true(ArtifactCatalog.is_artifact(String(id)))
	for item in [&"bullets", &"shells", &"medkit", null, 3]:
		assert_false(ArtifactCatalog.is_artifact(item), str(item))


func test_every_artifact_has_a_name_an_effect_and_a_story() -> void:
	for language in ["pl", "en"]:
		Settings.set_value(&"language", language, false)
		for id in ArtifactCatalog.IDS:
			for key in [ArtifactCatalog.name_key(id), ArtifactCatalog.effect_key(id), ArtifactCatalog.flavor_key(id)]:
				assert_ne(tr(key), key, "%s in %s" % [key, language])
	Settings.set_value(&"language", "pl", false)
	assert_eq(tr(ArtifactCatalog.name_key(ArtifactCatalog.MONOCLE)), "Monokl kustosza")
	assert_eq(tr("PROMPT_TAKE_ARTIFACT") % tr(ArtifactCatalog.name_key(ArtifactCatalog.SCARAB)), "Weź: Skarabeusz")


func test_effect_strengths_follow_the_design() -> void:
	assert_almost_eq(ArtifactCatalog.FINISHER_HEAL_BONUS, 1.0)
	assert_almost_eq(ArtifactCatalog.DUST_FACTOR, 1.5)
	assert_almost_eq(ArtifactCatalog.STUN_FACTOR, 1.5)
	assert_almost_eq(ArtifactCatalog.SPRINT_FACTOR, 1.2)
	for id in ArtifactCatalog.IDS:
		assert_true(ArtifactCatalog.COLORS.has(id))
