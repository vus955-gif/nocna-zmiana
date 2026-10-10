class_name ShellCache
extends Resource
## A carved shell kept on disk (carving the whole Floor I takes seconds):
## the boxes of ShellCarver.carve() for one set of volumes, keyed by a hash
## of those volumes and ShellCarver.VERSION. Looked up first among the
## caches shipped with the game (res://data/shell_cache, written by
## tools/bake_shell_cache.sh), then in the run's own cache folder (next to
## the save: SavePaths); a carve that missed both is kept there, so only the
## very first night after a change of the floor pays for it.

const SHIPPED_DIR := "res://data/shell_cache"
const RUN_DIR := "cache"

@export var key_hash: String = ""
@export var kits := PackedStringArray()
@export var owners := PackedStringArray()
@export var walk_owners := PackedStringArray()
@export var above := PackedByteArray()
## Six floats a box: position xyz, size xyz.
@export var boxes := PackedFloat32Array()

## Switched off by tests that must carve.
static var enabled: bool = true


## The file name of the cache for [param key] (ShellCarver's cache key).
static func file_name(key: String) -> String:
	return "shell_%s.res" % hash_of(key).substr(0, 24)


static func hash_of(key: String) -> String:
	return ("%d|%s" % [ShellCarver.VERSION, key]).sha256_text()


## The run's own cache folder.
static func run_dir() -> String:
	return SavePaths.dir().path_join(RUN_DIR)


## The boxes kept for [param key], or null when no cache holds them (or a
## kept file does not match).
static func fetch(key: String) -> Variant:
	if not enabled:
		return null
	var wanted := hash_of(key)
	for folder in [SHIPPED_DIR, run_dir()]:
		var path: String = folder.path_join(file_name(key))
		if not ResourceLoader.exists(path) and not FileAccess.file_exists(path):
			continue
		var kept := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as ShellCache
		if kept != null and kept.key_hash == wanted and kept.is_whole():
			return kept.to_boxes()
	return null


## Keeps [param carved] for [param key] in [param folder] (the run's cache
## folder when empty). False when it could not be written.
static func keep(key: String, carved: Array[ShellCarver.ShellBox], folder: String = "") -> bool:
	if not enabled:
		return false
	var target := folder if folder != "" else run_dir()
	DirAccess.make_dir_recursive_absolute(target if not target.begins_with("res://") else ProjectSettings.globalize_path(target))
	var kept := from_boxes(key, carved)
	return ResourceSaver.save(kept, target.path_join(file_name(key)), ResourceSaver.FLAG_COMPRESS) == OK


static func from_boxes(key: String, carved: Array[ShellCarver.ShellBox]) -> ShellCache:
	var kept := ShellCache.new()
	kept.key_hash = hash_of(key)
	kept.kits.resize(carved.size())
	kept.owners.resize(carved.size())
	kept.walk_owners.resize(carved.size())
	kept.above.resize(carved.size())
	kept.boxes.resize(carved.size() * 6)
	for i in carved.size():
		var box := carved[i]
		kept.kits[i] = String(box.kit)
		kept.owners[i] = String(box.owner)
		kept.walk_owners[i] = String(box.walk_owner)
		kept.above[i] = 1 if box.above_all else 0
		var at := box.aabb.position
		var size := box.aabb.size
		for k in 3:
			kept.boxes[i * 6 + k] = at[k]
			kept.boxes[i * 6 + 3 + k] = size[k]
	return kept


## True when every array holds the same number of boxes.
func is_whole() -> bool:
	var count := kits.size()
	return owners.size() == count and walk_owners.size() == count and above.size() == count and boxes.size() == count * 6


func to_boxes() -> Array[ShellCarver.ShellBox]:
	var carved: Array[ShellCarver.ShellBox] = []
	carved.resize(kits.size())
	for i in kits.size():
		var box := ShellCarver.ShellBox.new()
		box.kit = StringName(kits[i])
		box.owner = StringName(owners[i])
		box.walk_owner = StringName(walk_owners[i])
		box.above_all = above[i] != 0
		box.aabb = AABB(Vector3(boxes[i * 6], boxes[i * 6 + 1], boxes[i * 6 + 2]), Vector3(boxes[i * 6 + 3], boxes[i * 6 + 4], boxes[i * 6 + 5]))
		carved[i] = box
	return carved
