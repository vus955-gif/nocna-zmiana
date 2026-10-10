extends TestCase
## Flying books (design pietro-1-projekt 5.4) in a sandbox: a flock asleep
## on a shelf wakes together; dives are telegraphed, one at a time, bite a
## guard who stands still and miss one who steps aside; a shot-down book
## bursts into pages and scatters the rest; fire burns them double; the
## flock counts as one hunter; a slot of books spawns a whole flock.

var target: TargetDummy


func before_each() -> void:
	Greybox.box(self, Vector3(0, -0.5, 0), Vector3(60, 1, 60), Color.GRAY)
	target = TargetDummy.new()
	add_child(target)


## A flock of [param count] round [param at], awake (hovering) or asleep.
func _flock(at: Vector3, count: int, awake: bool) -> Array[FlyingBook]:
	var books: Array[FlyingBook] = []
	for member in BookFlock.make_members(at, 0.0, count):
		var book := member as FlyingBook
		book.target = target
		book.starts_awake = awake
		add_child(book)
		books.append(book)
	return books


func _wake(books: Array[FlyingBook]) -> void:
	for book in books:
		book.brain.wake()


func test_a_flock_sleeps_on_its_shelf_and_wakes_together() -> void:
	# a bookcase face at z = -2 looking at the room (+Z); the guard out of
	# sight behind it
	Greybox.box(self, Vector3(0, 1.5, -2.25), Vector3(6, 3, 0.5), Color.GRAY)
	target.position = Vector3(0, 0, -12)
	var books := _flock(Vector3(0, 0, -0.8), 5, false)
	await physics_frames(3)
	for book in books:
		assert_true(book.perched(), "asleep on the shelf")
		assert_almost_eq(book.global_position.y, BookFlock.SHELF_HEIGHT, 0.05)
		assert_almost_eq(book.global_position.z, -2.0 + BookFlock.SHELF_OFFSET, 0.05)
		assert_eq(book.brain.state, EnemyBrain.State.DORMANT)
		if book.rig != null:
			assert_lt((book.rig as BookRig).cover_open(), -0.8, "closed")
	target.position = Vector3(0, 0, 6)
	books[2].hear(Vector3(0, 0, 4))
	await physics_frames(90)
	for book in books:
		assert_ne(book.brain.state, EnemyBrain.State.DORMANT, "the whole flock is up")
		assert_false(book.perched())
		assert_gt(book.global_position.z, -2.0 + BookFlock.SHELF_OFFSET + 0.3, "off the shelf")


func test_a_dive_is_telegraphed_then_bites_a_guard_who_stands_still() -> void:
	var books := _flock(Vector3(0, 0, -6), 1, true)
	var book := books[0]
	var strikes := watch(book.brain.strike)
	await physics_frames(2)
	_wake(books)
	var telegraph_start := -1
	var widest := -10.0
	for frame in 240:
		await get_tree().physics_frame
		if book.brain.state == EnemyBrain.State.ATTACK and telegraph_start < 0:
			telegraph_start = frame
		if telegraph_start >= 0 and strikes.is_empty() and book.rig != null:
			widest = maxf(widest, (book.rig as BookRig).cover_open())
		if not strikes.is_empty() and telegraph_start >= 0 and frame - telegraph_start < 36:
			fail("struck %d frames into the telegraph" % (frame - telegraph_start))
			return
		if not target.hits.is_empty():
			break
	assert_gt(telegraph_start, -1, "it dived")
	assert_eq(strikes.size(), 1)
	if book.rig != null:
		assert_gt(widest, 0.45, "covers spread flat in the telegraph")
	assert_eq(target.hits.size(), 1, "one bite")
	if not target.hits.is_empty():
		assert_eq(target.hits[0].amount, FlyingBook.DIVE_DAMAGE)


func test_a_step_aside_dodges_the_dive() -> void:
	var books := _flock(Vector3(0, 0, -6), 1, true)
	var book := books[0]
	var strikes := watch(book.brain.strike)
	await physics_frames(2)
	_wake(books)
	for frame in 180:
		await get_tree().physics_frame
		if not strikes.is_empty():
			break
	assert_eq(strikes.size(), 1, "the dive came")
	target.position = Vector3(3.0, 0, 0)   # sidesteps as it leaves
	for frame in 90:
		await get_tree().physics_frame
		if book.brain.state != EnemyBrain.State.ATTACK:
			break
	assert_eq(target.hits.size(), 0, "the dive flew past")


func test_one_book_dives_at_a_time() -> void:
	var books := _flock(Vector3(0, 0, -6), 5, true)
	await physics_frames(2)
	_wake(books)
	var most := 0
	var dives := 0
	var was := false
	for frame in 480:
		await get_tree().physics_frame
		var at_once := 0
		for book in books:
			if is_instance_valid(book) and book.brain.state == EnemyBrain.State.ATTACK:
				at_once += 1
		most = maxi(most, at_once)
		if at_once > 0 and not was:
			dives += 1
		was = at_once > 0
	assert_eq(most, 1, "never two at once")
	assert_gt(dives, 2, "a rhythm of dives (%d)" % dives)


func test_a_shot_down_book_bursts_into_pages_and_scatters_the_flock() -> void:
	var books := _flock(Vector3(0, 0, -6), 4, true)
	await physics_frames(10)
	var destroyed := watch(Events.enemy_destroyed)
	var pages_before := PageFlutter.count()
	var shot := DamageInfo.make(20.0, DamageInfo.Kind.BALLISTIC, target)
	shot.direction = Vector3(0, 0, -1)
	shot.position = books[0].global_position
	books[0].take_damage(shot)
	assert_eq(destroyed.size(), 1, "one pistol shot (18 HP)")
	assert_gt(PageFlutter.count() - pages_before, FlyingBook.PAGES_DEATH.x - 1, "pages fly")
	var flock := books[1].flock
	assert_true(flock.spooked(), "the flock is spooked")
	var scattered := 0
	for book in books.slice(1):
		if book._external.length() > 1.0:
			scattered += 1
	assert_gt(scattered, 0, "the near ones fly off")
	assert_eq(flock.alive().size(), 3)
	assert_eq(books[1].dust_value, 2)


func test_fire_burns_a_book_twice_as_fast() -> void:
	var books := _flock(Vector3(0, 0, -6), 1, true)
	await physics_frames(2)
	var burn := DamageInfo.make(5.0, DamageInfo.Kind.FIRE, target)
	burn.position = books[0].global_position
	books[0].take_damage(burn)
	assert_eq(books[0].health.current, 8.0)


func test_a_hit_in_the_telegraph_calls_the_dive_off() -> void:
	var books := _flock(Vector3(0, 0, -6), 1, true)
	var book := books[0]
	var strikes := watch(book.brain.strike)
	book.max_health = 100.0
	await physics_frames(2)
	_wake(books)
	for frame in 120:
		await get_tree().physics_frame
		if book.brain.state == EnemyBrain.State.ATTACK:
			break
	assert_eq(book.brain.state, EnemyBrain.State.ATTACK)
	var hit := DamageInfo.make(5.0, DamageInfo.Kind.BALLISTIC, target)
	hit.position = book.global_position
	book.take_damage(hit)
	assert_ne(book.brain.state, EnemyBrain.State.ATTACK, "called off")
	await physics_frames(30)
	assert_eq(strikes.size(), 0)


func test_the_flock_counts_as_one_hunter() -> void:
	var books := _flock(Vector3(0, 0, -6), 5, true)
	await physics_frames(2)
	var hunters := books.filter(func(b: FlyingBook) -> bool: return b.counts_as_hunter())
	assert_eq(hunters.size(), 1)
	assert_eq(hunters[0], books[0])


func test_a_slot_of_books_spawns_a_whole_flock() -> void:
	var slot := SpawnSlot.new()
	slot.position = Vector3(0, 0, -6)
	slot.room = &""
	var slots: Array[SpawnSlot] = [slot]
	var config := NightConfig.new()
	config.night_seed = 12345
	config.night = 2
	config.spawns.append(NightConfig.Spawn.new(0, &"books", true))
	var size := NightSpawner.flock_size(config, 0)
	assert_true(size >= BookFlock.MIN_SIZE and size <= BookFlock.MAX_SIZE)
	assert_eq(NightSpawner.flock_size(config, 0), size, "the same night, the same flock")
	assert_eq(NightSpawner.exhibit_count(config), size)
	var placed := NightSpawner.spawn(config, slots, self, target)
	assert_eq(placed.size(), size)
	var flock := (placed[0] as FlyingBook).flock
	for exhibit in placed:
		assert_true(exhibit is FlyingBook)
		assert_eq((exhibit as FlyingBook).flock, flock)
		assert_eq(int(exhibit.get_meta(NightSpawner.SLOT_META)), 0)
	var thinned := NightSpawner.spawn(config, slots, self, target, Callable(), [], {0: 2})
	assert_eq(thinned.size(), size - 2, "a resumed night brings back the books still flying")
	assert_eq(NightSpawner.preferred([&"wax", &"books"] as Array[StringName], &"wax"), &"books")


func test_an_awake_flock_circles_the_guard_on_the_wing() -> void:
	var books := _flock(Vector3(0, 0, -8), 5, true)
	await physics_frames(2)
	for book in books:
		book.flock.tick(0.0)
		# no dives: watch the circling only
		book.brain.attack_range = -1.0
	_wake(books)
	await physics_frames(240)
	var moved := false
	var before: Array[Vector3] = []
	for book in books:
		before.append(book.global_position)
	await physics_frames(60)
	for i in books.size():
		var book := books[i]
		var flat := Vector2(book.global_position.x, book.global_position.z).length()
		assert_true(flat > 3.0 and flat < 8.0, "on the ring (%.1f m out)" % flat)
		assert_true(book.global_position.y > 1.2 and book.global_position.y < 3.3, "on the wing (%.1f m up)" % book.global_position.y)
		if book.global_position.distance_to(before[i]) > 0.5:
			moved = true
	assert_true(moved, "the ring turns")
