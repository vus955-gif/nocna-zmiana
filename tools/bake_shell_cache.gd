extends Node
## Writes the shell caches shipped with the game (ShellCache.SHIPPED_DIR):
## Floor I and the lobby carved now, the old files removed. Run it after
## changing a floor's rooms or openings (a stale cache only costs the first
## night's carving on the player's machine, never a wrong shell: the files
## are keyed by the volumes). Usage: bash tools/bake_shell_cache.sh


func _ready() -> void:
	var folder := ProjectSettings.globalize_path(ShellCache.SHIPPED_DIR)
	DirAccess.make_dir_recursive_absolute(folder)
	for file in DirAccess.get_files_at(folder):
		if file.ends_with(".res"):
			DirAccess.remove_absolute(folder.path_join(file))
	for entry: Array in [["floor1", Floor1Layout.create()], ["lobby", LobbyLayout.create()]]:
		var volumes := LevelBuilder.new(entry[1], null, null, null).shell_volumes()
		var key := ShellCarver.cache_key(volumes)
		var started := Time.get_ticks_msec()
		var carved := ShellCarver._carve(volumes)
		var written := ShellCache.keep(key, carved, ShellCache.SHIPPED_DIR)
		print("%s: %d boxes carved in %d ms -> %s %s" % [entry[0], carved.size(), Time.get_ticks_msec() - started, ShellCache.file_name(key), "written" if written else "NOT WRITTEN"])
	get_tree().quit()
