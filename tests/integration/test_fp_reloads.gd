extends TestCase
## Reloads in the hands (owner's note 45, plan 2026-10-21-animacje-fpp):
## the pistol tips in, shakes the empty magazine out, slaps the new one home
## and lets the slide go; the break-actions open, take their rounds and are
## snapped shut from the wrist; the fire-arrow chest jolts as each arrow
## seats, the gatling as its belt runs in. Every reload, whole or cut short,
## moves frame by frame without a jump.

var holder: WeaponHolder


func before_each() -> void:
	Greybox.box(self, Vector3(0, -0.5, 0), Vector3(40, 1, 40), Color.GRAY)
	var user := Node3D.new()
	add_child(user)
	holder = WeaponHolder.new()
	holder.user = user
	holder.position = Vector3(0, 1.5, 0)
	user.add_child(holder)


func _rig(id: StringName) -> ViewmodelRig:
	holder.give(load("res://src/weapons/data/%s.tres" % id))
	holder.select_id(id)
	return holder.view_of(id) as ViewmodelRig


## Starts weapon [param id]'s reload from an empty magazine (the gatling:
## its next belt).
func _start_reload(id: StringName) -> WeaponState:
	var state := holder.current_state()
	state.magazine = 0
	state.reserve = maxi(state.reserve, state.data.magazine_size * 2)
	if state.data.belt_feed:
		state._feed_belt()
	else:
		assert_true(holder.try_reload(), "%s reloads" % id)
	return state


## Steps [param frames] process frames; returns [widest move (m), widest
## turn (rad), the mesh that moved most, every frame's widest move] of any
## part of the view between two frames ([param in_sight]: of what shows in
## the frame, FpCheck.moved_in_sight).
func _watch(view: Node3D, frames: int, in_sight: bool = false) -> Array:
	var widest := [0.0, 0.0, "", []]
	var last := FpCheck.snapshot(holder, view)
	for i in frames:
		await get_tree().process_frame
		var now := FpCheck.snapshot(holder, view)
		var moved := FpCheck.moved_in_sight(last, now, view) if in_sight else FpCheck.moved(last, now, view)
		if float(moved[0]) > float(widest[0]):
			widest[0] = moved[0]
			widest[2] = moved[2]
		widest[1] = maxf(widest[1], moved[1])
		(widest[3] as Array).append(moved[0])
		last = now
	return widest


## Every reload, frame by frame, of what shows in the frame (the rifle's
## left arm drops out of the frame to the pouch, its sleeve swinging down by
## the elbow out of sight): no step out of nowhere, and none wider than
## about a fist (the break-actions' barrels snap shut: quick, but eased).
func test_every_reload_moves_without_a_jump() -> void:
	for id in [&"pistol", &"shotgun", &"flare", &"rifle_hunt", &"harpoon", &"hwacha", &"gatling"]:
		var rig := _rig(id)
		assert_not_null(rig, "a model rig, not a greybox stand-in")
		if rig == null:
			continue
		await physics_frames(40)
		var state := _start_reload(id)
		var frames := roundi((state.data.belt_change_time if state.data.belt_feed else state.data.reload_time) * 60.0) + 30
		var widest := await _watch(rig, frames, true)
		var spike := FpCheck.spike(widest[3])
		assert_eq(spike, -1, "%s: a jump at frame %d (%.3f m)" % [id, spike, float((widest[3] as Array)[spike]) if spike >= 0 else 0.0])
		assert_lt(float(widest[0]), 0.1, "%s: no part in sight flies (%.3f m, %s)" % [id, widest[0], widest[2]])
		assert_lt(float(widest[1]), 0.3, "%s: nor turns in a blink (%.3f rad)" % [id, widest[1]])
		assert_false(state.is_reloading(), "%s: reloaded" % id)


func test_a_reload_cut_short_comes_back_without_a_jump() -> void:
	for id in [&"pistol", &"shotgun", &"flare", &"hwacha"]:
		var rig := _rig(id)
		assert_not_null(rig, "a model rig, not a greybox stand-in")
		if rig == null:
			continue
		await physics_frames(40)
		var state := _start_reload(id)
		for i in roundi(state.data.reload_time * 60.0 * 0.45):
			await get_tree().process_frame
		state.cancel_reload()
		var widest := await _watch(rig, 40)
		assert_lt(float(widest[0]), 0.05, "%s: back from a cut reload smoothly (%.3f m, %s)" % [id, widest[0], widest[2]])
		assert_lt(float(widest[1]), 0.3, "%s: (%.3f rad)" % [id, widest[1]])


func test_the_pistol_tips_in_slaps_the_magazine_home_and_lets_the_slide_go() -> void:
	var rig := _rig(&"pistol")
	assert_not_null(rig, "a model rig, not a greybox stand-in")
	if rig == null:
		return
	await physics_frames(40)
	var slide := rig.part_node(&"slide")
	var slide_rest: Transform3D = rig.rest["slide"]
	var state := _start_reload(&"pistol")
	# (emptied by hand here, not by a last shot: the slide eases back first)
	for i in 10:
		await get_tree().process_frame
	assert_lt(state.reload_progress(), ViewmodelRig.PISTOL_RELEASE)
	assert_gt(slide.position.distance_to(slide_rest.origin), 0.02, "empty: the slide is locked back")
	var most_tipped := 0.0
	var seat_rise := 0.0
	var last_y := rig.model.position.y
	var released_at := -1.0
	for i in roundi(state.data.reload_time * 60.0) + 20:
		await get_tree().process_frame
		var p := state.reload_progress() if state.is_reloading() else 1.0
		most_tipped = maxf(most_tipped, rig.model.rotation.z)
		if p > 0.5 and p < 0.7:
			seat_rise = maxf(seat_rise, rig.model.position.y - last_y)
		last_y = rig.model.position.y
		if released_at < 0.0 and slide.position.distance_to(slide_rest.origin) < 0.005:
			released_at = p
	assert_gt(most_tipped, 0.3, "the pistol is tipped in to show its grip (%.2f rad)" % most_tipped)
	assert_gt(seat_rise, 0.0015, "the magazine slapped home jolts it up")
	assert_true(released_at > 0.6 and released_at < 0.95, "the slide goes home before the reload ends (at %.2f)" % released_at)
	assert_lt(rig.model.rotation.z, 0.01, "back at rest")


func test_the_break_actions_open_take_their_rounds_and_snap_shut_from_the_wrist() -> void:
	for id in [&"shotgun", &"flare"]:
		var rig := _rig(id)
		assert_not_null(rig, "a model rig, not a greybox stand-in")
		if rig == null:
			continue
		await physics_frames(40)
		var hinge := rig.part_node(&"barrels" if id == &"shotgun" else &"barrel")
		var state := _start_reload(id)
		var open_by := -1.0
		var shut_by := -1.0
		var flick := 0.0
		var flick_at := 0.0
		var last_pitch := rig.model.rotation.x
		for i in roundi(state.data.reload_time * 60.0):
			await get_tree().process_frame
			if not state.is_reloading():
				break
			var p := state.reload_progress()
			if open_by < 0.0 and hinge.rotation.x < -0.5:
				open_by = p
			if open_by > 0.0 and shut_by < 0.0 and hinge.rotation.x > -0.05:
				shut_by = p
			var lift := rig.model.rotation.x - last_pitch
			if p > 0.7 and lift > flick:
				flick = lift
				flick_at = p
			last_pitch = rig.model.rotation.x
		assert_true(open_by > 0.0 and open_by < 0.3, "%s: broken open early (%.2f)" % [id, open_by])
		assert_true(shut_by > 0.75 and shut_by < 0.95, "%s: snapped shut before the end (%.2f)" % [id, shut_by])
		assert_gt(flick, 0.01, "%s: a flick of the wrist shuts it (%.3f rad in a frame at %.2f)" % [id, flick, flick_at])


func test_the_chest_jolts_as_each_arrow_seats() -> void:
	var rig := _rig(&"hwacha")
	assert_not_null(rig, "a model rig, not a greybox stand-in")
	if rig == null:
		return
	await physics_frames(40)
	var state := _start_reload(&"hwacha")
	var dips := 0
	var going_down := false
	var last_y := rig.model.position.y
	for i in roundi(state.data.reload_time * 60.0):
		await get_tree().process_frame
		var p := state.reload_progress()
		var dy := rig.model.position.y - last_y
		last_y = rig.model.position.y
		if p < 0.3 or p > 0.92:
			continue
		if dy < -0.0004 and not going_down:
			dips += 1
		going_down = dy < -0.0004
	assert_true(dips >= state.data.volley_count - 1, "a jolt for (nearly) every arrow: %d" % dips)
