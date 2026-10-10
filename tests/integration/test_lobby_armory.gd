extends TestCase
## The guard's weapons in the game: the world content's till drawer key and
## gun locker give the pistol (installed by the Museum); the shotgun waits
## in the plaque niche - seen and used as the guard would (looking, E).

var museum: Museum


func after_each() -> void:
	if is_instance_valid(museum):
		museum.free()


func _museum() -> Museum:
	museum = (load(SceneFlow.MUSEUM) as PackedScene).instantiate() as Museum
	add_child(museum)
	return museum


## Puts the guard [param distance] m in front of [param target] (along its
## -Z), looking at the point [param height] m above its origin; waits until
## something is in focus (or gives up).
func _look_at(target: Node3D, height: float, distance: float = 1.1) -> Interactable:
	var front := -target.global_transform.basis.z
	front.y = 0.0
	front = front.normalized()
	var stand := target.global_position + front * distance
	var query := PhysicsRayQueryParameters3D.create(stand + Vector3.UP, stand + Vector3.DOWN * 4.0, Layers.WORLD)
	var hit := museum.get_world_3d().direct_space_state.intersect_ray(query)
	stand.y = (hit["position"] as Vector3).y + 0.05 if not hit.is_empty() else stand.y
	museum.player.global_position = stand
	var aim := target.global_position + Vector3.UP * height - (stand + Vector3.UP * museum.player.eye_height)
	museum.player.head.rotation = Vector3(atan2(aim.y, Vector2(aim.x, aim.z).length()), atan2(-aim.x, -aim.z), 0.0)
	for i in 30:
		await physics_frames(1)
		if museum.player.interactor.focus == target:
			break
	return museum.player.interactor.focus


func test_the_world_content_is_installed_with_the_key_and_the_gun_locker() -> void:
	GameState.new_game()
	_museum()
	await physics_frames(3)
	assert_not_null(museum.features)
	assert_eq(LobbyFeatures.of(get_tree()), museum.features)
	assert_not_null(museum.features.drawer, "the till drawer with the key")
	assert_not_null(museum.features.locker, "the gun locker")
	assert_eq(museum.features.night, museum.night, "the same draw as the game")
	assert_false(museum.features.locker.unlocked)


func test_the_shotgun_waits_in_the_niche_until_taken() -> void:
	GameState.new_game()
	_museum()
	await physics_frames(3)
	var shotgun := museum.armory.shotgun
	assert_not_null(shotgun)
	if shotgun == null:
		return
	assert_eq(museum.lobby.room_at(shotgun.global_position), &"shotgun_niche")
	museum.lobby.doors[&"panel_plaque"].open(true)
	await physics_frames(2)
	assert_eq(await _look_at(shotgun, 0.4, 0.6), shotgun)
	museum.player.interactor.try_interact(museum.player)
	assert_true(museum.player.weapons.has_weapon(&"shotgun"))
	assert_true(GameState.has_weapon(&"shotgun"))
	var on_disk := PersistentState.new()
	add_child(on_disk)
	assert_true(on_disk.load_game())
	assert_true(on_disk.has_weapon(&"shotgun"), "saved at once")
	museum.free()
	_museum()
	await physics_frames(3)
	assert_true(museum.armory.shotgun == null, "not laid out again")
	assert_true(museum.player.weapons.has_weapon(&"shotgun"))


func test_the_cctv_shows_the_nights_clock() -> void:
	GameState.new_game()
	_museum()
	await physics_frames(3)
	if museum.features.cctv == null:
		return
	museum.watch.clock.elapsed = NightClock.SECONDS_PER_HOUR * 2.0
	assert_eq(CctvCatalog.clock_text(museum.features.cctv.night_seconds()).substr(0, 5), "01:00")
