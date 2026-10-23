extends TestCase
## CpuSections: the cost of a group of nodes' callbacks, measured between
## two stamps by the engine's own call order.

## A node that spends [member micros] us in every _process and _physics_process.
class Burner extends Node:
	var micros: int = 0

	func _process(_delta: float) -> void:
		_burn()

	func _physics_process(_delta: float) -> void:
		_burn()

	func _burn() -> void:
		var until := Time.get_ticks_usec() + micros
		while Time.get_ticks_usec() < until:
			pass


var sections: CpuSections
var heavy: Array[Burner] = []
var light: Array[Burner] = []
var bystander: Burner


func before_each() -> void:
	sections = CpuSections.new()
	add_child(sections)
	# heavy and light nodes interleaved in the tree, and a bystander between them
	for i in 3:
		var big := _burner(2000)
		heavy.append(big)
		var small := _burner(500)
		light.append(small)
	bystander = _burner(300)
	sections.add_section(&"heavy", func() -> Array: return heavy, false)
	sections.add_section(&"light", func() -> Array: return light, false)


func after_each() -> void:
	sections.uninstall()


func _burner(micros: int) -> Burner:
	var burner := Burner.new()
	burner.micros = micros
	add_child(burner)
	return burner


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame
		await get_tree().physics_frame


func test_each_section_gets_what_its_nodes_cost() -> void:
	sections.install()
	await _frames(3)
	sections.reset()
	await _frames(40)
	var report := sections.report()
	var heavy_ms: float = report[&"heavy"]["idle_ms"]
	var light_ms: float = report[&"light"]["idle_ms"]
	assert_gt(heavy_ms, 5.5, "three nodes of 2 ms")
	assert_lt(heavy_ms, 25.0, "(the machine may be busy: only a loose ceiling)")
	assert_gt(light_ms, 1.4, "three nodes of 0.5 ms")
	assert_lt(light_ms, 12.0)
	assert_gt(heavy_ms, light_ms)
	var heavy_physics: float = report[&"heavy"]["physics_ms"]
	assert_gt(heavy_physics, 5.5, "the physics callbacks too")
	assert_lt(heavy_physics, 25.0)


func test_the_bystander_is_not_counted() -> void:
	sections.install()
	await _frames(3)
	sections.reset()
	await _frames(30)
	var total := 0.0
	for section in sections.names:
		total += sections.report()[section]["idle_ms"]
	assert_gt(total, 7.0, "the two sections")
	assert_eq(sections.claimed_count(), 6)


func test_priorities_are_restored() -> void:
	bystander.process_priority = 5
	heavy[0].process_priority = 7
	heavy[0].process_physics_priority = 9
	sections.install()
	assert_eq(heavy[0].process_priority, sections.priority_of(0))
	assert_eq(light[0].process_priority, sections.priority_of(1))
	assert_eq(bystander.process_priority, 5, "not claimed, not touched")
	sections.uninstall()
	assert_eq(heavy[0].process_priority, 7)
	assert_eq(heavy[0].process_physics_priority, 9)
	assert_eq(light[0].process_priority, 0)
	assert_false(sections.is_installed())
	assert_eq(sections.claimed_count(), 0)
	await get_tree().process_frame
	assert_eq(sections.get_child_count(), 0, "the stamps are gone")


func test_a_node_that_comes_later_joins_at_the_rescan() -> void:
	sections.install()
	var late := _burner(1000)
	heavy.append(late)
	assert_eq(late.process_priority, 0)
	sections.rescan()
	assert_eq(late.process_priority, sections.priority_of(0))
	assert_eq(sections.claimed_count(), 7)
	sections.rescan()
	assert_eq(sections.claimed_count(), 7, "once")


func test_a_whole_subtree_belongs_to_its_section() -> void:
	var branch := Node.new()   # no script: an engine node of the section's tree is claimed all the same
	add_child(branch)
	var leaf := Burner.new()
	branch.add_child(leaf)
	sections.add_section(&"branch", func() -> Array: return [branch], true)
	sections.install()
	assert_eq(leaf.process_priority, sections.priority_of(2))
	assert_eq(branch.process_priority, sections.priority_of(2))
	sections.uninstall()
	assert_eq(leaf.process_priority, 0)
	assert_eq(branch.process_priority, 0)


func test_the_first_section_to_claim_a_node_keeps_it() -> void:
	sections.add_section(&"again", func() -> Array: return heavy, false)
	sections.install()
	assert_eq(heavy[0].process_priority, sections.priority_of(0))


func test_samples_are_kept_per_frame_on_request() -> void:
	sections.keep_samples = true
	sections.install()
	await _frames(12)
	var samples: Dictionary = sections.samples[&"heavy"]
	assert_gt((samples["idle"] as Array).size(), 8.0)
	assert_gt((samples["physics"] as Array).size(), 8.0)
	for ms: float in samples["idle"]:
		assert_gt(ms, 5.0)
	sections.reset()
	assert_eq((sections.samples[&"heavy"]["idle"] as Array).size(), 0)


func test_the_sections_are_ranked_by_cost() -> void:
	sections.install()
	await _frames(10)
	assert_eq(sections.ranked(), [&"heavy", &"light"] as Array[StringName])
