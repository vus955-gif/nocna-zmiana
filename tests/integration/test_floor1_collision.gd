extends TestCase
## Floor I's collisions as the guard meets them (QA #49; plan
## docs/superpowers/plans/2026-10-18-qa-kolizje-softlocki-zapis.md): on the
## DRESSED floor the real guard (Floor1Walker: his own controller and
## capsule) walks every doorway both ways and every flight up and down;
## nothing solid stands where nothing is drawn (an invisible corner); every
## flight's drawn steps lie under the ramp he walks on. The walkable floor
## itself (lanes over a lattice, ledges, pits) is swept by
## test_floor1_collision_floor (2 m lattice) and its deep variant (1 m).
## What a walk finds and is so by design is listed in KNOWN with why.

## Doorway walks that end at something meant to be there: opening id ->
## why (every walk of that opening; "<id> off" = only those beside its
## middle).
const KNOWN_DOORWAYS := {
	&"entrance_cloakroom_counter": "a counter across the hatch: the cloakroom's way in is its door",
	&"greece_nereid_metopes off": "a bust on its stand beside the 7 m arch, in plain sight",
}
## Openings and flights with no floor to walk from on one side, by design:
## id -> why.
const KNOWN_SKIPPED := {
	&"north_hall_grate": "the grate opens onto the flight down into the dark",
	&"north_hall_crypt_dark": "the stairs into the dark: the end of Floor I waits at their foot",
}
## Solid shapes that stand at least Floor1Sweep.GAP m proud of what is
## drawn (finding Q7 of the plan): most pieces' collision is drawn from
## their look (CollisionFit, Floor1Art.FIT_COLLISION) - what is left is
## known: "kit@room" -> [the longest such stretch of outline found (m),
## why]. A longer stretch (by more than 0.3 m) or a new kit@room fails.
const KNOWN_UNDRAWN := {
	"crate@egypt_gallery": [1.3, "the camp tent's foot: its outline takes in the guy ropes' pegs"],
	"dome_core@roof_catwalks": [3.7, "the drum's solid core on the roof: its faces stand in the closed space inside the drum, out of reach"],
	"lamassu@assyria_gate": [0.8, "the Khorsabad Gate's bulls: collision drawn from the gate's carving, one convex outline a band round the relief"],
	"pedestal@asia_korea": [0.8, "a display's lacquer pedestal: fitted from its look, a column's outline at its foot stands proud of the display on it"],
	"railing@basement_boiler": [2.2, "an invisible stair rail's end by the boiler gantry's steel stairs (left for the basement's art: plan, Q7)"],
	"railing@greece_bassae_gallery": [0.6, "the end of a balustrade by the gallery's wall"],
	"railing@greece_nereid_podium": [0.7, "the end of a balustrade by the podium's wall"],
	"scaffold@assyria_nimrud": [0.7, "a scaffold of poles: one outline round them, nobody walks through the frame"],
	"shelf@basement_reserve": [1.1, "the reserve's back-to-back racks: the crates on top in the racks' outline"],
	"water_tank@roof_plant": [1.0, "the roof tank's trestle: one outline round its braced legs, the ladder's foot and the feed pipe beyond them, nobody fits under the tank"],
}
## A stair tower's invisible rails (no balustrade drawn: the walls close a
## service flight's sides): the lower flight's inner rail runs on by the
## landing, where the other flight's steps come down to its height, this
## far at most (m).
const STAIR_RAIL_END := 1.0
## A drawn step lies at most this far over the ramp (m), and at most one
## riser and this much under it.
const STEP_OVER := 0.08
const STEP_UNDER := 0.12
## On a flight his view may go against his way by at most this much
## between two steps (a bob), and change by at most EYE_JOLT in one (m).
const EYE_BOB := 0.02
const EYE_JOLT := 0.12

var sweep: Floor1Sweep
var level: MuseumFloorLevel


func after_each() -> void:
	if sweep != null and is_instance_valid(sweep.museum):
		if sweep.walker != null:
			sweep.walker.release()
		sweep.museum.free()
	if is_instance_valid(level):
		level.free()
	MuseumFloorLevel.dress_default = false


func test_every_flights_drawn_steps_lie_under_its_ramp() -> void:
	MuseumFloorLevel.dress_default = true
	level = MuseumFloorLevel.new()
	level.bake_navigation = false
	add_child(level)
	level.build()
	var looks := {}
	for node in level.structure.get_children():
		if node.get_meta(&"kit", &"") == &"stairs":
			looks[(node as Node3D).position.snapped(Vector3.ONE * 0.01)] = node
	var views: Array[MeshInstance3D] = []
	var flights: Array = []
	for flight in level.layout.stairs:
		var frame := flight.frame()
		var look: Node3D = looks.get((frame * Vector3(0, 0, -flight.run() * 0.5)).snapped(Vector3.ONE * 0.01))
		if look == null or not level.layout.room(flight.room_low) or look.get_meta(&"kit_greybox", false):
			continue
		flights.append([flight, look])
		for view in look.find_children("*", "MeshInstance3D", true, false):
			if (view as MeshInstance3D).mesh != null:
				views.append(view)
	assert_gt(flights.size(), 20, "the dressed flights")
	var stand_in := Floor1Sweep.stand_ins(views, level)
	await physics_frames(2)
	var space := level.get_world_3d().direct_space_state
	var ray := PhysicsRayQueryParameters3D.new()
	ray.collision_mask = Floor1Sweep.LOOK_LAYER
	ray.hit_back_faces = true
	for entry: Array in flights:
		var flight: StairsSpec = entry[0]
		var frame := flight.frame()
		var rise := flight.top_y - flight.bottom_y
		var steps := flight.step_count()
		var tread := flight.run() / steps
		var crest := -(steps - 1) * tread
		var riser := rise / steps
		var worst := ""
		# in the middle of treads along the run (a ray down the joint of two
		# drawn steps may slip between them)
		for share: float in [0.1, 0.33, 0.5, 0.67, 0.9]:
			var k := clampi(int(share * steps), 0, steps - 1)
			var f := (k + 0.5) / steps
			var z := -f * flight.run()
			var ramp := clampf((tread - z) / (tread - crest), 0.0, 1.0) * rise
			var at := frame * Vector3(0, 0, z)
			ray.from = Vector3(at.x, flight.top_y + 1.0, at.z)
			ray.to = Vector3(at.x, flight.bottom_y - 0.5, at.z)
			var hit := space.intersect_ray(ray)
			var drawn: float = (hit["position"] as Vector3).y - flight.bottom_y if not hit.is_empty() else -INF
			if drawn > ramp + STEP_OVER or drawn < ramp - riser - STEP_UNDER:
				worst = "at %d%% of the run the ramp is %.2f m up, the drawn step %s" % [roundi(f * 100), ramp, "missing" if drawn == -INF else "%.2f m" % drawn]
				break
		assert_true(worst == "", "%s: drawn steps under the ramp (%s)" % [flight.id, worst])
	stand_in.free()


func test_every_doorway_and_flight_is_walked_and_nothing_solid_stands_undrawn() -> void:
	sweep = Floor1Sweep.build(self)
	await physics_frames(3)
	await sweep.settle()
	var doors := sweep.sweep_doorways()
	assert_gt(doors["walked"], 600, "the doorways walked through")
	for entry: Dictionary in doors["failed"]:
		var opening := String(entry["what"]).get_slice(" ", 0)
		var why: String = KNOWN_DOORWAYS.get(StringName(opening), KNOWN_DOORWAYS.get(StringName(opening + " off"), "") if String(entry["what"]).contains(" off ") else "")
		if why != "":
			print("  known: %s (%s)" % [Floor1Sweep.line(entry), why])
			continue
		fail("the guard is stopped walking through a doorway: " + Floor1Sweep.line(entry))
	var flights := sweep.sweep_stairs()
	assert_gt(flights["walked"], 150, "the flights walked")
	for entry: Dictionary in flights["failed"]:
		fail("the guard is stopped on the stairs: " + Floor1Sweep.line(entry))
	# his view up and down every flight (Q1: the step-up's eased eyes): it
	# never bobs against the way and no step pops it
	assert_gt((flights["eyes"] as Array).size(), 150, "the flights' walks with his view followed")
	for entry: Array in flights["eyes"]:
		assert_true(float(entry[1]) < EYE_BOB and float(entry[2]) < EYE_JOLT, "%s: his view bobs %.3f m against the way, jumps %.3f m in a step" % entry)
	for skipped: Dictionary in [doors["skipped"], flights["skipped"]]:
		for id: String in skipped:
			var key := StringName(id.get_slice(" ", 0))
			if KNOWN_SKIPPED.has(key):
				continue
			fail("%s not walked: %s" % [id, skipped[id]])
	# the astrolabe's dais: up its round steps from every side
	var astrolabe: Vector3 = (sweep.level.markers[&"astrolabe"] as Transform3D).origin
	for k in 8:
		var way := Vector3(cos(TAU * k / 8.0), 0.0, sin(TAU * k / 8.0))
		var from := sweep.walker.standing_spot(Vector3(astrolabe.x, 0.0, astrolabe.z) + way * 3.6)
		if from == Vector3.INF:
			continue   # a desk or a catalogue there
		sweep.walker.place(from)
		var up := sweep.walker.follow(PackedVector3Array([from, Vector3(astrolabe.x, 0.48, astrolabe.z) + way * 0.9]))
		assert_true(up["ok"] and sweep.walker.feet().y > 0.4, "up the astrolabe's steps from bearing %d: %s" % [k * 45, Floor1Sweep.line(sweep.finding("dais", up)) if not up["ok"] else "feet at %.2f m" % sweep.walker.feet().y])
	var undrawn := await sweep.invisible_collision(0.6)
	for entry: Dictionary in undrawn:
		var key := String(entry["what"])
		if KNOWN_UNDRAWN.has(key) and float(entry["run"]) <= float(KNOWN_UNDRAWN[key][0]) + 0.3:
			continue
		if key.begins_with("railing@") and (entry["size"] as Vector3).y > 2.0 and float(entry["run"]) <= STAIR_RAIL_END:
			continue   # a flight's pitched rail (its box stands tall)
		fail("solid %.2f m (or more) proud of what is drawn along %.2f m of its outline: %s in %s at %s (box %s)" % [entry["gap"], entry["run"], entry["what"], entry["room"], entry["at"], entry["size"]])
