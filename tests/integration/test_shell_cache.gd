extends TestCase
## The carved shell kept on disk (ShellCache): what is kept reads back box
## for box, a kept file of other volumes is not taken, ShellCarver.carve()
## takes a kept carving instead of carving again, and the caches shipped
## with the game are reported current or stale.


func _lobby_volumes() -> Array[ShellCarver.Volume]:
	return LevelBuilder.new(LobbyLayout.create(), null, null, null).shell_volumes()


func test_a_kept_carving_reads_back_box_for_box() -> void:
	var volumes := _lobby_volumes()
	var key := ShellCarver.cache_key(volumes)
	var carved := ShellCarver._carve(volumes)
	var folder := ShellCache.run_dir().path_join("roundtrip")
	assert_true(ShellCache.keep(key, carved, folder))
	var kept := ResourceLoader.load(folder.path_join(ShellCache.file_name(key)), "", ResourceLoader.CACHE_MODE_IGNORE) as ShellCache
	assert_not_null(kept)
	var back := kept.to_boxes()
	assert_eq(back.size(), carved.size())
	for i in carved.size():
		if back[i].kit != carved[i].kit or back[i].owner != carved[i].owner or back[i].walk_owner != carved[i].walk_owner or back[i].above_all != carved[i].above_all or not back[i].aabb.is_equal_approx(carved[i].aabb):
			fail("box %d differs" % i)
			break
	assert_ne(ShellCache.hash_of(key), ShellCache.hash_of(key + "x"), "other volumes, another key")
	DirAccess.remove_absolute(folder.path_join(ShellCache.file_name(key)))


func test_carve_takes_the_kept_carving() -> void:
	var volumes := _lobby_volumes()
	var key := ShellCarver.cache_key(volumes)
	ShellCache.keep(key, ShellCarver._carve(volumes))
	ShellCarver._cache.erase(key)
	var started := Time.get_ticks_msec()
	var boxes := ShellCarver.carve(volumes)
	var msec := Time.get_ticks_msec() - started
	assert_eq(boxes.size(), ShellCarver._carve(volumes).size())
	assert_lt(msec, 200 * time_slack(), "read, not carved (%d ms)" % msec)


func test_the_shipped_caches_are_reported() -> void:
	for entry: Array in [["floor1", Floor1Layout.create()], ["lobby", LobbyLayout.create()]]:
		var key := ShellCarver.cache_key(LevelBuilder.new(entry[1], null, null, null).shell_volumes())
		var shipped := ResourceLoader.exists(ShellCache.SHIPPED_DIR.path_join(ShellCache.file_name(key)))
		print("  shipped shell cache of %s: %s" % [entry[0], "current" if shipped else "STALE (run tools/bake_shell_cache.sh)"])
