extends TestCase
## The secrets' reward displays (SecretRewardDisplay, put on the floor by
## RewardSpot) in the dressed floor: RewardSpot reads the greybox's colliding
## pieces, but what the wings put on them (models wider than their boxes, a
## cornice, a case's glass, a banner) must not reach into a display either,
## nor into the floor the plaque is read on. Built without navigation, the
## whole floor dressed.

## The display's volume over its floor: a strongbox (and its open lid), a
## plinth with its exhibit (and the glass case).
const SMALL_HEIGHT := 0.8
const PLINTH_HEIGHT := 1.6
## The floor right under the display belongs to the floor's own mesh.
const FLOOR_SKIN := 0.02
## Overlap deeper than this (m) counts, on every axis.
const OVERLAP := 0.01

var level: MuseumFloorLevel


func before_each() -> void:
	MuseumFloorLevel.dress_default = true
	level = MuseumFloorLevel.new()
	level.bake_navigation = false
	add_child(level)
	level.build()


func after_each() -> void:
	MuseumFloorLevel.dress_default = false


## Every mesh the level draws (the shell, the kit pieces' looks, the heroes)
## and its world box.
var _views: Array[MeshInstance3D] = []
var _boxes: Array[AABB] = []


func _collect() -> void:
	for node in level.find_children("*", "MeshInstance3D", true, false):
		var view := node as MeshInstance3D
		if view.mesh != null and view.is_visible_in_tree():
			_views.append(view)
			_boxes.append(view.global_transform * view.get_aabb())


## The world box of the rectangle of [param half] (across, deep) round
## [param centre] turned by [param yaw] on the floor plan, from [param y]
## [param high] up.
func _box(centre: Vector2, half: Vector2, yaw: float, y: float, high: float) -> AABB:
	var turn := Basis(Vector3.UP, yaw)
	var box := AABB(Vector3(centre.x, y, centre.y), Vector3.ZERO)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var corner := turn * Vector3(half.x * sx, 0.0, half.y * sz)
			box = box.expand(Vector3(centre.x + corner.x, y, centre.y + corner.z))
	return box.expand(Vector3(centre.x, y + high, centre.y))


func _reaches(box: AABB) -> Array[String]:
	var found: Array[String] = []
	for i in _boxes.size():
		if not _boxes[i].intersects(box):
			continue
		var overlap := _boxes[i].intersection(box)
		if overlap.size.x > OVERLAP and overlap.size.y > OVERLAP and overlap.size.z > OVERLAP:
			found.append("%s %s" % [_views[i].get_path(), overlap])
	return found


func test_no_dressing_stands_in_a_reward_display_or_on_the_floor_its_plaque_is_read_on() -> void:
	_collect()
	assert_gt(_views.size(), 5000, "the whole floor is dressed")
	var layout: LevelLayout = level.layout
	var checked := 0
	for entry in SecretRewards.entries():
		if not layout.markers.has(entry.id):
			continue
		checked += 1
		var at := RewardSpot.place(layout, entry.id, layout.markers[entry.id], entry.tier)
		var floor_y := at.origin.y
		var flat := Vector2(at.origin.x, at.origin.z)
		var yaw := at.basis.get_euler().y
		var size := SecretRewardDisplay.footprint(entry.tier)
		var tall := SMALL_HEIGHT if entry.tier == SecretRewards.Tier.SMALL else PLINTH_HEIGHT
		var display := _box(flat, size * 0.5, yaw, floor_y + FLOOR_SKIN, tall)
		for hit in _reaches(display):
			fail("%s's display (%s) has dressing in it: %s" % [entry.id, entry.tier, hit])
		# the floor the plaque is read on, in front of it (RewardSpot keeps it
		# clear of the pieces): free of dressing too, up to a reader's chest
		var front := RewardSpot.facing(yaw)
		var strip_at := flat + front * (size.y * 0.5 + RewardSpot.READ_DEPTH * 0.5)
		var strip := _box(strip_at, Vector2(RewardSpot.READ_WIDTH, RewardSpot.READ_DEPTH) * 0.5, yaw, floor_y + 0.1, 1.1)
		for hit in _reaches(strip):
			fail("%s's plaque has dressing in front of it: %s" % [entry.id, hit])
	assert_gt(checked, 20, "a display in every wing (%d)" % checked)
