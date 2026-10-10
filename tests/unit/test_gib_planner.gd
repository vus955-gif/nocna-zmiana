extends TestCase


func test_plain_kill_crumbles_into_a_few_pieces() -> void:
	var plan := GibPlanner.plan(ExhibitMaterial.Kind.WAX, 0.0, 60.0, false)
	assert_false(plan.gibbed)
	assert_eq(plan.chunks, 3)


func test_heavy_overkill_tears_it_apart() -> void:
	var plan := GibPlanner.plan(ExhibitMaterial.Kind.WAX, 40.0, 60.0, false)
	assert_true(plan.gibbed)
	assert_true(plan.chunks >= 7, "chunks %d" % plan.chunks)


func test_finisher_always_tears_it_apart() -> void:
	assert_true(GibPlanner.plan(ExhibitMaterial.Kind.TAXIDERMY, 0.0, 35.0, true).gibbed)


func test_more_overkill_means_more_force_up_to_a_cap() -> void:
	var small := GibPlanner.plan(ExhibitMaterial.Kind.WAX, 30.0, 60.0, false)
	var big := GibPlanner.plan(ExhibitMaterial.Kind.WAX, 90.0, 60.0, false)
	var huge := GibPlanner.plan(ExhibitMaterial.Kind.WAX, 6000.0, 60.0, false)
	assert_gt(big.impulse, small.impulse)
	assert_true(huge.impulse <= GibPlanner.MAX_IMPULSE)
	assert_true(huge.chunks <= GibPlanner.MAX_CHUNKS)


func test_armour_sheds_extra_plates() -> void:
	var wax := GibPlanner.plan(ExhibitMaterial.Kind.WAX, 0.0, 60.0, false)
	var metal := GibPlanner.plan(ExhibitMaterial.Kind.METAL, 0.0, 60.0, false)
	assert_eq(metal.chunks, wax.chunks + 2)


func test_linen_comes_apart_in_more_smaller_rags() -> void:
	var wax := GibPlanner.plan(ExhibitMaterial.Kind.WAX, 0.0, 110.0, false)
	var linen := GibPlanner.plan(ExhibitMaterial.Kind.LINEN, 0.0, 110.0, false)
	assert_gt(linen.chunks, wax.chunks)
	assert_lt(linen.chunk_size, wax.chunk_size)


func test_wood_splinters_into_more_smaller_pieces() -> void:
	var wax := GibPlanner.plan(ExhibitMaterial.Kind.WAX, 0.0, 70.0, false)
	var wood := GibPlanner.plan(ExhibitMaterial.Kind.WOOD, 0.0, 70.0, false)
	assert_gt(wood.chunks, wax.chunks)
	assert_lt(wood.chunk_size, wax.chunk_size)
