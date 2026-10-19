extends TestCase
## The enemy ecology on the real Floor I (review of the branch, 19.10): what
## only shows with the floor's own walls, rooms and night.
## - A door's creak belongs to the two rooms it joins: its middle lies in the
##   wall (79 of Floor I's 80 doors in no room at all), which used to make
##   it a noise "from nowhere" - heard at full strength by everyone within
##   10 m, through the walls.
## - The first night's sleepers on the way out of the booth sleep soundly:
##   a gate opening in the Great Court does not send a court knight walking.

func _seconds(time: float) -> void:
	await physics_frames(roundi(time * Engine.physics_ticks_per_second))


## The nearest spawn slot to [param point] among [param slots] that satisfies
## [param wanted] within [param within] m (null for none).
func _nearest_slot(slots: Array[SpawnSlot], point: Vector3, within: float, wanted: Callable) -> SpawnSlot:
	var best: SpawnSlot = null
	for slot in slots:
		if not wanted.call(slot):
			continue
		var distance := slot.position.distance_to(point)
		if distance <= within and (best == null or distance < best.position.distance_to(point)):
			best = slot
	return best


## A wax figure asleep at [param slot] (rolls drawn for it, nothing else).
func _figure_at(slot: SpawnSlot, target: Node3D, seed_value: int) -> Enemy:
	var figure := WaxFigure.new()
	figure.position = slot.position
	figure.target = target
	figure.brain.rng.seed = seed_value
	add_child(figure)
	return figure


## The Egypt-Greece passage: its middle lies in no room, a side room (the
## serdab) behind the wall within 10 m of it. The creak is heard in the two
## rooms the door joins, not in the serdab.
func test_a_doors_creak_stays_in_the_two_rooms_it_joins() -> void:
	var layout := Floor1Layout.create()
	var description := MuseumFloorLevel.describe_layout(layout)
	var spec := layout.opening(&"j_egypt_greece")
	var middle := spec.center() + Vector3.UP * minf(spec.height() * 0.5, 1.2)
	assert_eq(layout.room_at(middle), &"", "(the middle of the doorway lies in no room)")
	Greybox.box(self, Vector3(0, -0.5, 0), Vector3(400, 1, 400), Color.GRAY)
	var target := TargetDummy.new()
	target.position = Vector3(0, 0, 150)
	add_child(target)
	# only this door open; the arches and the stairs stay shut for the test
	PerceptionWorld.configure(Callable(), layout.room_at, layout.graph(), func(passage: StringName) -> bool: return passage == spec.id)
	var in_pair := _nearest_slot(description.spawn_slots, middle, 10.0, func(slot: SpawnSlot) -> bool:
		return (slot.room == spec.room_a or slot.room == spec.room_b) and absf(slot.position.y - middle.y) < 3.0)
	var behind_the_wall := _nearest_slot(description.spawn_slots, middle, 10.0, func(slot: SpawnSlot) -> bool:
		return slot.room != spec.room_a and slot.room != spec.room_b and absf(slot.position.y - middle.y) < 3.0)
	assert_not_null(in_pair, "a slot in one of the two rooms within 10 m")
	assert_not_null(behind_the_wall, "a slot in a third room within 10 m")
	if in_pair == null or behind_the_wall == null:
		return
	var here := _figure_at(in_pair, target, 1)
	var there := _figure_at(behind_the_wall, target, 2)
	var door := Door.make(spec, Transform3D(Basis.IDENTITY, spec.center()), Color(0.5, 0.45, 0.4))
	add_child(door)
	door.close(true)   # (it starts open)
	await physics_frames(2)
	assert_eq(here.current_room(), in_pair.room)
	assert_eq(there.current_room(), behind_the_wall.room)
	door.open()
	assert_eq(here.brain.state, EnemyBrain.State.SUSPICIOUS, "the figure in %s hears the door" % in_pair.room)
	assert_eq(there.brain.state, EnemyBrain.State.DORMANT, "the one in %s, %.1f m off behind the wall, does not" % [behind_the_wall.room, behind_the_wall.position.distance_to(middle)])


## The Great Court's gate, on night 1 of two drawn nights (seeds 11 and 90210,
## each with court knights asleep 4 m from it): the sleepers on the way out
## of the booth sleep soundly, so neither the creak nor the cap's old free
## pass for the nearest listener sends a court knight walking over.
func test_the_first_nights_court_knights_stay_in_bed_when_the_gate_opens() -> void:
	var layout := Floor1Layout.create()
	var description := MuseumFloorLevel.describe_layout(layout)
	var spec := layout.opening(&"court_reading_door")
	var way := NightDirector.first_way(description)
	assert_true(way.has(&"court"), "(the court lies on the way out of the booth)")
	Greybox.box(self, Vector3(0, -0.5, 0), Vector3(200, 1, 200), Color.GRAY)
	var target := TargetDummy.new()
	target.position = Vector3(0, 0, 150)
	add_child(target)
	for night_seed in [11, 90210]:
		var door := Door.make(spec, Transform3D(Basis.IDENTITY, spec.center()), Color(0.5, 0.45, 0.4))
		add_child(door)
		door.close(true)
		PerceptionWorld.configure(Callable(), layout.room_at, layout.graph(), LevelPerception.door_checker({spec.id: door}))
		var config := NightDirector.plan(night_seed, 1, description)
		# (the court's exhibits only: the basement's would fall through this greybox floor)
		config.spawns = config.spawns.filter(func(entry: NightConfig.Spawn) -> bool: return description.spawn_slots[entry.slot].room == &"court")
		var placed := NightSpawner.spawn(config, description.spawn_slots, self, target)
		for exhibit in placed:   # (what the Museum does for the gentle start)
			if exhibit.brain.state == EnemyBrain.State.DORMANT and way.has(exhibit.home_room):
				exhibit.sound_asleep = NightDirector.GENTLE_TIME
		var knights := placed.filter(func(e: Enemy) -> bool: return e is Knight and e.brain.state == EnemyBrain.State.DORMANT)
		assert_gt(knights.size(), 0, "seed %d: knights sleep in the court" % night_seed)
		await physics_frames(2)
		var in_earshot := knights.filter(func(e: Enemy) -> bool: return e.global_position.distance_to(door.global_position) < PerceptionRules.DOOR_NOISE)
		assert_gt(in_earshot.size(), 0, "seed %d: some within earshot of the gate" % night_seed)
		door.open()
		await _seconds(3.0)
		for knight: Enemy in knights:
			assert_eq(knight.brain.state, EnemyBrain.State.DORMANT, "seed %d: a court knight did not walk over" % night_seed)
		for exhibit in placed:
			exhibit.free()
		door.free()
		await physics_frames(2)
