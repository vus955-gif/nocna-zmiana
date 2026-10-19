extends TestCase
## Floor I's walkable floor walked by the real guard (QA #49; plan
## docs/superpowers/plans/2026-10-18-qa-kolizje-softlocki-zapis.md): on the
## DRESSED floor with everything open (Floor1Sweep) the navmesh's floor as
## a lattice of points where he stands squarely; every lane of it walked
## both ways along x and z with his own controller - nothing stops him and
## his speed never collapses (a lip, a seam, a piece the navmesh forgets);
## every ledge where a lane breaks with floor beyond (between two floors, or
## a low piece on one) at most a step high is walked over; no pit he can
## drop into keeps him. Lattice every SPACING m (the deep variant walks
## every metre: bash tools/run_tests.sh --filter=deep).

## What stops him and is known: collider ("kit@room" or "Class:name") ->
## why. Printed, not failed.
const KNOWN := {}

## A ledge between two floors up to this high (m) is jumped onto
## (test_player_steps: his jump reaches 0.8 m).
const JUMP_LEDGE := 0.8

var sweep: Floor1Sweep


func spacing() -> float:
	return 2.0


func after_each() -> void:
	if sweep != null and is_instance_valid(sweep.museum):
		if sweep.walker != null:
			sweep.walker.release()
		sweep.museum.free()
	MuseumFloorLevel.dress_default = false


func _known(entry: Dictionary) -> String:
	for kit: String in entry["kits"]:
		if KNOWN.has(kit):
			return KNOWN[kit]
	if String(entry.get("no_step", "")).begins_with("railing@"):
		return "the side of a flight where its rail begins: the rail stands over the step"
	return ""


func test_the_walkable_floor_has_no_snag_low_ledge_nor_pit() -> void:
	sweep = Floor1Sweep.build(self)
	await physics_frames(3)
	await sweep.settle()
	sweep.build_lattice(spacing())
	var points := 0
	for cell in sweep.lattice:
		points += (sweep.lattice[cell] as Array).size()
	assert_gt(points, 20000.0 / (spacing() * spacing()), "the lattice covers the floor")
	var lanes := sweep.sweep_lanes()
	print("  %d lattice points, %d lanes, %d steps of the guard" % [points, lanes["lanes"], lanes["steps"]])
	for entry: Dictionary in lanes["snags"]:
		var why := _known(entry)
		if why != "":
			print("  known: %s (%s)" % [Floor1Sweep.line(entry), why])
			continue
		fail("the guard is stopped on the open floor: " + Floor1Sweep.line(entry))
	for slow: Array in lanes["slow"]:
		var at: Vector3 = slow[0]
		if Array(lanes["snags"]).any(func(e: Dictionary) -> bool: return (e["at"] as Vector3).distance_to(at) < 0.6 and _known(e) != ""):
			continue
		fail("his speed collapses to %.1f m/s on the open floor in %s at %s" % [slow[1], sweep.room_at(at), at.snapped(Vector3.ONE * 0.1)])
	var ledges := sweep.sweep_ledges(lanes["crossings"])
	var knee := 0
	for entry: Dictionary in ledges:
		if entry["kind"] == "low":
			var why := _known(entry)
			if why != "":
				print("  known: %s (%s)" % [Floor1Sweep.line(entry), why])
				continue
			fail("a ledge at most a step high stops him: %s (jumping over: %s)" % [Floor1Sweep.line(entry), entry["jump"]])
		elif entry["kind"] == "knee":
			knee += 1
			print("  knee-high: %s (jumping over: %s)" % [Floor1Sweep.line(entry), entry["jump"]])
			# a ledge between two floors within a jump is jumped onto
			if String(entry["what"]).begins_with("ledge up") and float(entry["rise"]) <= JUMP_LEDGE and _known(entry) == "":
				assert_true(entry["jump"], "a ledge within a jump (%.2f m) is jumped onto: %s" % [entry["rise"], Floor1Sweep.line(entry)])
	print("  %d crossings; %d knee-high ledges (a plinth's side, a flight's side: jump)" % [(lanes["crossings"] as Array).size(), knee])
	var pits := sweep.traps()
	print("  pits he drops into and leaves: %d" % pits["pits"])
	for entry: Dictionary in pits["traps"]:
		fail("he drops into %s at %s (%.1f m down) and cannot get out" % [entry["room"], entry["at"], entry["drop"]])
