extends TestCase
## The Two-headed Serpent's fall (SerpentFall) in the real Temple of the
## Serpent: after the last hit the body trembles, the mosaic cascades off
## segment by segment from the end that was hit, the skulls break off and
## tumble down the steps, the light dies and the bared wooden body stays
## lying for the night. A killing blow mid-motion - the body arched on its
## ring with both heads raised at the gate, or a head shot out in a lunge -
## still leaves the fall on the ground: the arches settle, the necks come
## down, the skulls roll off the flight.

const A := SerpentBrain.Attack
const S := SerpentBrain.State
const END := SerpentBody.End
const START := Vector3(-22.5, 0.0, -79.0)
## The north flight up to the altar's terrace (under the gate).
const N2_FLIGHT := Rect2(-15.75, -79.4, 3.0, 4.4)
## A skull breaking off this close to the flight's top (m) sits on the edge.
const TOP_EDGE := 0.5
const SEED := 7

var museum: Museum


func before_each() -> void:
	Museum.level_id = &"floor1"


func after_each() -> void:
	if is_instance_valid(museum):
		museum.free()


func _museum() -> Museum:
	museum = (load(SceneFlow.MUSEUM) as PackedScene).instantiate() as Museum
	add_child(museum)
	return museum


## The Serpent, its dice (the attack under way at a blow, the next pick) and
## the skulls' spin seeded: the same fall every run.
func _serpent() -> Serpent:
	var serpent := museum.floor_game.guardians.guardians.get(&"serpent") as Serpent
	if serpent != null:
		serpent.brain.seed_with(SEED)
	seed(SEED)
	return serpent


func _seconds(time: float) -> void:
	await physics_frames(roundi(time * Engine.physics_ticks_per_second))


func _put_guard(at: Vector3) -> void:
	var guard := museum.player
	if guard.health.max_health < 10000.0:
		guard.health.max_health = 100000.0
		guard.health.reset()
	guard.global_position = at + Vector3.UP * 0.05
	guard.velocity = Vector3.ZERO


func _awake(serpent: Serpent) -> void:
	_put_guard(START)
	await _seconds(0.3)
	assert_true(serpent.is_fighting(), "awake")
	await _seconds(SerpentBrain.WAKE_TIME + 0.1)


func _roaming(serpent: Serpent, at: Vector3) -> void:
	for i in 60 * 8:
		if serpent.brain.state == S.ROAM:
			return
		_put_guard(at)
		museum.player.heal(100000.0)
		await get_tree().physics_frame


func _hit_zone(serpent: Serpent, zone: StringName, amount: float, at: Vector3) -> void:
	var info := DamageInfo.make(amount, DamageInfo.Kind.BALLISTIC, museum.player)
	info.weapon = &"pistol"
	info.position = at
	serpent.take_zone_damage(info, zone)


## The killing blow on head [param end]; the fall it leaves (or null).
func _kill(serpent: Serpent, end: END) -> SerpentFall:
	var keeper := museum.floor_game.guardians
	_hit_zone(serpent, &"head_a" if end == END.A else &"head_b", serpent.health.current + 1.0, serpent.body.head_point(end))
	await physics_frames(2)
	assert_false(is_instance_valid(serpent) and serpent.is_inside_tree(), "the guardian is gone")
	var falls := keeper.find_children("*", "SerpentFall", false, false)
	assert_eq(falls.size(), 1, "its fall plays out")
	return falls[0] as SerpentFall if falls.size() == 1 else null


## The floor under [param at] (an independent ray through the level's
## world; a flight's invisible railing is not floor).
func _floor_under(at: Vector3) -> float:
	var space := museum.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 3.0, at + Vector3.DOWN * 6.0, Layers.WORLD)
	for i in 4:
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			return at.y
		var collider := hit["collider"] as Node
		if collider == null or collider.get_meta(&"kit", &"") != &"railing":
			return (hit["position"] as Vector3).y
		var exclude := query.exclude
		exclude.append(hit["rid"])
		query.exclude = exclude
	return at.y


## The highest the lying body stands over the ground it lies on (m, over
## its own radius): the arches gone.
func _arched(fall: SerpentFall) -> float:
	var body := fall._body
	var ground := body.ground_joints()
	var arch := 0.0
	for j in range(ground.x, ground.y + 1):
		arch = maxf(arch, body.joints[j].y - body.ground_of(j) - body.radii[j])
	return arch


## Every head lies on the ground under it (the steps, the floor) and no
## neck joint is under the ground on its way there (over a flight's side a
## neck arches; it never passes through the stone).
func _necks_down(fall: SerpentFall) -> void:
	var body := fall._body
	for end in 2:
		var head := body.head_point(end as END)
		var over := head.y - _floor_under(head)
		assert_lt(over, SerpentFall.HEAD_LOW + 0.45, "head %d lies on the ground under it (%.2f over)" % [end, over])
		assert_gt(over, -0.2, "head %d not under the ground (%.2f)" % [end, over])
		var root := SerpentBody.NECK if end == 0 else body.count - SerpentBody.NECK
		for i in range(1, SerpentBody.NECK):
			var j := root - i if end == 0 else root + i
			var under := _floor_under(body.joints[j]) - body.joints[j].y
			assert_lt(under, 0.1, "neck %d's joint %d over the ground, not in it (%.2f under)" % [end, i, under])


## Every light in the fall (the two mouths', wherever the skulls carry them,
## and the fall's own).
func _lights(fall: SerpentFall) -> Array[OmniLight3D]:
	var found: Array[OmniLight3D] = []
	for node in fall.find_children("*", "OmniLight3D", true, false):
		found.append(node as OmniLight3D)
	return found


func test_the_mosaic_cascades_from_the_end_that_was_hit_and_the_skulls_break_off() -> void:
	GameState.new_game()
	_museum()
	await physics_frames(3)
	var serpent := _serpent()
	await _awake(serpent)
	for i in 60 * 3:
		_put_guard(START)
		await get_tree().physics_frame
	var count := serpent.rig.count
	assert_eq(serpent._lights.size(), 2, "a light in each mouth")
	var fall := await _kill(serpent, END.B)
	if fall == null:
		return
	var shattered := watch(fall.shattered)
	assert_eq(_lights(fall).size(), 3, "the two mouths' lights went with the model, and the fall's own")
	# the tremble: the eyes flare, nothing comes off yet
	await _seconds(SerpentFall.TREMBLE * 0.7)
	assert_eq(fall._rig.plates_left(), count, "whole through the tremble")
	assert_gt(fall._light.light_energy, 0.5, "the cracks' light swells")
	for light in _lights(fall):
		assert_gt(light.light_energy, 0.5, "the mouths' lights swell with the glow (%s)" % light.get_path())
	# the cascade runs from end B (hit) toward end A
	await _seconds(SerpentFall.TREMBLE * 0.3 + SerpentFall.CASCADE_STEP * 8.5)
	for k in range(count - 6, count):
		assert_false(fall._rig.plate_on(k), "plate %d (the hit end) came off first" % k)
	for k in 6:
		assert_true(fall._rig.plate_on(k), "plate %d (the far end) still on" % k)
	assert_eq(fall.pieces.size(), 0, "the skulls still on their necks")
	# halfway: the skulls break off as heavy pieces
	await _seconds(SerpentFall.CASCADE_STEP * count * 0.5)
	assert_eq(fall.pieces.size(), 2, "both skulls broke off")
	var broke_at: Array[float] = []
	for piece in fall.pieces:
		broke_at.append(piece.global_position.y)
		assert_eq(piece.collision_layer, Layers.DEBRIS)
	# done: every plate off, the light dies, the remains stay for the night
	await _seconds(SerpentFall.CASCADE_STEP * count * 0.5 + SerpentFall.FADE + 0.3)
	assert_eq(fall._rig.plates_left(), 0, "every plate cascaded off")
	assert_eq(shattered.size(), 1, "shattered")
	assert_lt(fall._light.light_energy, 0.01, "the light died")
	for light in _lights(fall):
		assert_lt(light.light_energy, 0.01, "no light left lit on the remains (%s: %.2f)" % [light.get_path(), light.light_energy])
	assert_true(fall._rig.model.is_inside_tree(), "the bared body lies where it fell")
	assert_eq(fall._rig.model.find_children("*", "Hurtbox", true, false).size(), 0, "nothing to shoot")
	assert_eq(fall._rig.model.find_children("*", "AnimatableBody3D", true, false).size(), 0, "nothing solid")
	for i in fall.pieces.size():
		var piece := fall.pieces[i]
		assert_lt(piece.global_position.y, broke_at[i] + 0.3, "skull %d came down, never up (%.2f -> %.2f)" % [i, broke_at[i], piece.global_position.y])
		assert_lt(piece.global_position.y - fall._body.ground_of(SerpentBody.NECK if i == 0 else fall._body.count - SerpentBody.NECK), 1.2, "skull %d lies low" % i)


func test_a_killing_blow_in_the_ring_with_the_heads_at_the_gate_leaves_the_fall_on_the_ground() -> void:
	GameState.new_game()
	_museum()
	await physics_frames(3)
	var serpent := _serpent()
	await _awake(serpent)
	for i in 60 * 5:
		_put_guard(START)
		await get_tree().physics_frame
	var floor_spot := Vector3(-22.0, 0.0, -72.0)
	var circled := watch(serpent.encircled)
	_hit_zone(serpent, &"head_a", serpent.health.current - serpent.max_health * 0.3 + 1.0, serpent.body.head_point(END.A))
	for i in 60 * 40:
		if circled.size() > 0:
			break
		_put_guard(floor_spot)
		museum.player.heal(100000.0)
		await get_tree().physics_frame
	assert_eq(circled.size(), 1, "on its ring")
	for i in 60 * 3:
		_put_guard(floor_spot)
		museum.player.heal(100000.0)
		await get_tree().physics_frame
	# arched and reared: the body stands high in places, the heads over the gate
	var ground := serpent.body.ground_joints()
	var arched := 0.0
	for j in range(ground.x, ground.y + 1):
		arched = maxf(arched, serpent.body.joints[j].y - serpent.body.ground_of(j) - serpent.body.radii[j])
	assert_gt(arched, 0.9, "an arch stands (%.2f)" % arched)
	var reared := 0.0
	for end in 2:
		reared = maxf(reared, serpent.body.head_point(end as END).y - serpent.body.joints[serpent._neck_root(end as END)].y)
	assert_gt(reared, 0.8, "the heads are raised (%.2f)" % reared)
	var fall := await _kill(serpent, END.A)
	if fall == null:
		return
	# it settles: by the time the skulls break off the body lies flat and
	# the necks are down, the heads on the ground under them - the leading
	# head's on the steps under the gate (the trailing root may have crept
	# along the ring while the arches stood: its head lies where it is)
	await _seconds(SerpentFall.SINK + 0.1)
	var left_arched := _arched(fall)
	assert_lt(left_arched, 0.15, "no arch stands over the ring (%.2f)" % left_arched)
	_necks_down(fall)
	var over_flight := 0
	for end in 2:
		var head := fall._body.head_point(end as END)
		if N2_FLIGHT.has_point(Vector2(head.x, head.z)):
			over_flight += 1
	assert_gt(over_flight, 0, "a head came down onto the north flight's steps")
	# the skulls break off; the one on the flight tumbles down it (the other
	# lies at the upper terrace's edge)
	await _seconds(SerpentFall.TREMBLE + SerpentFall.CASCADE_STEP * SerpentBody.SEGMENTS * 0.5 + 0.2 - SerpentFall.SINK - 0.1)
	assert_eq(fall.pieces.size(), 2, "both skulls broke off")
	var broke_at: Array[Vector3] = []
	var on_flight := 0
	for piece in fall.pieces:
		broke_at.append(piece.global_position)
		if N2_FLIGHT.has_point(Vector2(piece.global_position.x, piece.global_position.z)):
			on_flight += 1
	assert_gt(on_flight, 0, "a skull broke off over the flight")
	await _seconds(5.0)
	for i in fall.pieces.size():
		var piece := fall.pieces[i]
		# (a skull that breaks off at the very top of the flight, on the
		# terrace's edge, may stay there: only those further down the steps roll)
		if N2_FLIGHT.has_point(Vector2(broke_at[i].x, broke_at[i].z)) and broke_at[i].z < N2_FLIGHT.end.y - TOP_EDGE:
			assert_lt(piece.global_position.y, broke_at[i].y - 0.3, "skull %d rolled down the flight (%.2f -> %.2f)" % [i, broke_at[i].y, piece.global_position.y])
		else:
			assert_lt(piece.global_position.y, broke_at[i].y + 0.3, "skull %d came down, never up (%.2f -> %.2f)" % [i, broke_at[i].y, piece.global_position.y])
		assert_lt(piece.linear_velocity.length(), 2.0, "skull %d (nearly) came to rest" % i)


func test_a_killing_blow_mid_lunge_lays_the_shot_out_head_down() -> void:
	GameState.new_game()
	_museum()
	await physics_frames(3)
	var serpent := _serpent()
	await _awake(serpent)
	await _roaming(serpent, START)
	var biter := serpent.brain.biter()
	var frame := serpent.body.root_frame(biter)
	var in_lane := frame * Vector3(0.0, 0.0, -3.6)
	in_lane.y = serpent._ground_at(in_lane)
	_put_guard(in_lane)
	serpent.brain.force_attack(A.LUNGE)
	# (the strike eases the head out to its reach at its end: it hangs out
	# spent as the recovery begins)
	for i in 120:
		if serpent.brain.stage == SerpentBrain.Stage.RECOVER:
			break
		_put_guard(in_lane)
		await get_tree().physics_frame
	assert_eq(serpent.brain.stage, SerpentBrain.Stage.RECOVER)
	var root := serpent.body.joints[serpent._neck_root(biter)]
	assert_gt(serpent.body.head_point(biter).distance_to(root), 2.3, "the head is shot out")
	var fall := await _kill(serpent, biter)
	if fall == null:
		return
	await _seconds(SerpentFall.SINK + 0.1)
	_necks_down(fall)
