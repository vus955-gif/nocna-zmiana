extends TestCase
## The whole first-person review (plan 2026-10-21-animacje-fpp, item 9;
## owner's notes 45 and 46): every weapon taken through everything the
## hands do in one go - drawn, reloaded, a blow, a reach, the first look
## cut short by a blow, a run started and stopped, put away for the next -
## and checked frame by frame: nothing in sight jumps (a step out of
## nowhere) or flies (over about a fist a frame), no elbow of a two-handed
## weapon comes into the frame, every wrist stays within its limits, and
## the near plane cuts nothing inside the frame.

## A move of more than this (m) between two frames, of anything in sight;
## the draw of a switch may be quicker (a boomer shooter's switch is a
## snap: the weapon sweeps up from under the frame in a few frames, eased;
## its times are ViewmodelMotion.HANDLING's, to tune in the window).
const FLIES := 0.11
const DRAW_FLIES := 0.16
## A turn of more than this (rad) between two frames.
const SPINS := 0.3
## The near plane is checked every this many frames (it walks every
## triangle).
const NEAR_EVERY := 3

var guard: Player
var _steps: Array = []
var _widest := 0.0
var _widest_draw := 0.0
var _widest_turn := 0.0
var _where := ""
var _last := {}
var _frame := 0


func before_each() -> void:
	Greybox.box(self, Vector3(0, -0.5, 0), Vector3(60, 1, 160), Color.GRAY)
	guard = Player.new()
	guard.position = Vector3(0, 0.05, 60)
	add_child(guard)


func after_each() -> void:
	Input.action_release(&"move_forward")
	Input.action_release(&"sprint")


func test_every_weapon_through_everything_the_hands_do() -> void:
	var holder := guard.weapons
	for id in WeaponHolder.SLOT_ORDER:
		holder.give(load("res://src/weapons/data/%s.tres" % id))
		holder.select_id(id)
		guard.global_position = Vector3(0, 0.05, 60)
		var view := holder.view_of(id)
		var rig := view as ViewmodelRig
		assert_not_null(rig, "%s: a model rig, not a greybox stand-in" % id)
		_steps = []
		_widest = 0.0
		_widest_draw = 0.0
		_widest_turn = 0.0
		# (a new view takes its framing in its first frame, under the frame)
		await get_tree().process_frame
		_last = FpCheck.snapshot(holder, view)
		_frame = 0
		await _watch(id, view, rig, "draw", 40)
		# a reload from empty (the gatling: its next belt)
		var state := holder.current_state()
		if state.data.belt_feed:
			state.magazine = 0
			state._feed_belt()
			await _watch(id, view, rig, "belt", roundi(state.data.belt_change_time * 60.0) + 25)
		elif state.data.ammo_mode == WeaponData.AmmoMode.MAGAZINE:
			state.magazine = 0
			state.reserve = maxi(state.reserve, state.data.magazine_size * 2)
			if holder.try_reload():
				await _watch(id, view, rig, "reload", roundi(state.data.reload_time * 60.0) + 25)
		holder.fists._cooldown = 0.0
		assert_true(holder.try_punch(), "%s: the blow" % id)
		await _watch(id, view, rig, "blow", 30)
		holder.reach()
		await _watch(id, view, rig, "reach", 60)
		if rig != null:
			rig.look_over()
			await _watch(id, view, rig, "first look", 40)
			holder.fists._cooldown = 0.0
			assert_true(holder.try_punch(), "%s: a blow cuts the look" % id)
			await _watch(id, view, rig, "look cut by a blow", 40)
		Input.action_press(&"move_forward")
		Input.action_press(&"sprint")
		await _watch(id, view, rig, "run", 50)
		assert_true(guard.sprinting, "%s: sprinting" % id)
		Input.action_release(&"sprint")
		Input.action_release(&"move_forward")
		await _watch(id, view, rig, "run stopped", 40)
		var spike := FpCheck.spike(_steps)
		assert_eq(spike, -1, "%s: a jump at frame %d (%.3f m)" % [id, spike, float(_steps[spike]) if spike >= 0 else 0.0])
		assert_lt(_widest, FLIES, "%s: nothing in sight flies (%.3f m, %s)" % [id, _widest, _where])
		assert_lt(_widest_draw, DRAW_FLIES, "%s: the draw is quick, but a motion (%.3f m)" % [id, _widest_draw])
		assert_lt(_widest_turn, SPINS, "%s: nor spins (%.3f rad)" % [id, _widest_turn])


## Steps [param frames] process frames of weapon [param id] in phase
## [param phase], checking each one.
func _watch(id: StringName, view: Node3D, rig: ViewmodelRig, phase: String, frames: int) -> void:
	var holder := guard.weapons
	for i in frames:
		await get_tree().process_frame
		_frame += 1
		var now := FpCheck.snapshot(holder, view)
		var moved := FpCheck.moved_in_sight(_last, now, view)
		_last = now
		_steps.append(moved[0])
		if phase == "draw":
			_widest_draw = maxf(_widest_draw, moved[0])
		elif float(moved[0]) > _widest:
			_widest = moved[0]
			_where = "%s, %s frame %d" % [moved[2], phase, i]
		_widest_turn = maxf(_widest_turn, moved[1])
		if rig != null and view.visible:
			for side in rig.arm_sides():
				assert_false(FpCheck.in_frame(rig, rig.arm_line(side)[1], -0.1), "%s %s frame %d: elbow_%s in the frame" % [id, phase, i, side])
				var angles := rig.wrist_angles(side)
				assert_true(ViewmodelRig.wrist_within_limits(angles), "%s %s frame %d: wrist_%s (flexion %.0f, deviation %.0f)" % [id, phase, i, side, angles.x, angles.y])
		if _frame % NEAR_EVERY == 0 and view.visible:
			var cut := FpCheck.near_cut(holder, view)
			assert_gt(cut, 1.2, "%s %s frame %d: the near plane cuts it inside the frame (%.2f)" % [id, phase, i, cut])
