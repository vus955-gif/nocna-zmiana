extends RefCounted
## Floor I zone "roof" (y = 22.5; design 4.4 p. 6, 10.1; plan docs/
## superpowers/plans/2026-10-03-p1-w5b-podziemia-dach.md): an optional walk
## in the moonlight over the Great Court, and a shortcut.
## - roof_stairs: the service stair tower over the security booth, from the
##   entrance hall's landing (y 6; the rope hatch, junction j_entrance_roof)
##   up three flights to the roof;
## - roof_plant: the plant deck over the booth (air handlers, a water tank,
##   a chimney with a red warning lamp) and the gutter bridge down onto the
##   court's roof;
## - roof_catwalks: the walk over the court's glass roof. A gutter walk all
##   round its edge, a ring walk round the dome of the Reading Room (its
##   drum carried up through the roof, the stepped dome and the lantern with
##   a red warning lamp: a landmark from anywhere up here), four radial
##   catwalks between them; four glass fields fenced off between the walks,
##   each with a service gate in its railing. The court's roof is a solid
##   slab today (the glass roof and its truss are stage P2's hero piece):
##   the catwalks stand on y 22.5 and the glass panes lie on it, so nobody
##   can fall into the court. The bolted door of the Enlightenment's stair
##   tower is on the east gutter (junction j_roof_enlightenment);
## - two secrets behind zone gates: the pigeon loft off the plant deck (a
##   hatch held by a rope: a precise shot) and the roofers' shed in the
##   north-west corner (boarded up).
## Only moonlight out here (LightSpec.MOON) and two small red warning lamps;
## the tower is indoors (tubes). Wind (ambience zone "roof").

const ZONE := &"roof"
const Grey := preload("res://src/level/floor1/floor1_greybox.gd")
const Hub := preload("res://src/level/floor1/zones/hub_kit.gd")
const Kit := preload("res://src/level/floor1/zones/west_kit.gd")
const Svc := preload("res://src/level/floor1/zones/service_kit.gd")
const SWING := OpeningSpec.DoorStyle.SWING

const Y := Floor1Plan.ROOF_Y
## The open roof's "ceiling" (the sky; its light wells reach 31.5, inside
## the zone's box) and the secrets' low roofs.
const SKY := Y + 7.5
const HUT := Y + 3.0
## Three flights in two lanes along x from the landing door (east lane,
## starting at the west end) to the top landing at the east end.
const TOWER := Rect2(17, 45, 20, 8)
const FLIGHTS := 3
## The Reading Room's drum (zones/court.gd) carried up through the roof.
const DRUM_OUT := 12.26
const DRUM_IN := 11.2
const SEGMENT := 4.877
## The ring walk: an octagon of railings at this apothem round the drum.
const RING := 15.5
## The gutter walk: railings this far from the court's middle.
const GUTTER := 26.5
## Half the width of a radial catwalk.
const SPOKE := 1.5
## Half the width of a service gate in a glass field's railing.
const GATE := 0.6
## Moon pools: spots aimed down from this high, reaching down to the slab.
const MOON_Y := Y + 5.5
const MOON_REACH := 6.0

const WAX: Array[StringName] = [&"wax"]
const BUST: Array[StringName] = [&"bust"]


static func build(layout: LevelLayout) -> void:
	_rooms(layout)
	_tower(layout)
	_plant_deck(layout)
	_dome(layout)
	_catwalks(layout)
	_glass(layout)
	_secrets(layout)
	_encounters(layout)


static func _rooms(layout: LevelLayout) -> void:
	Grey.tower(layout, &"roof_stairs", TOWER, Floor1Plan.LANDING_Y, Y, FLIGHTS, 1, true, ZONE)
	Grey.room(layout, &"roof_plant", [Grey.r(22.5, 36, 38, 44.5), Grey.r(22.5, 30.5, 30, 36)] as Array[Rect2], Y, SKY, ZONE, &"ROOM_ROOF_PLANT", false)
	var walks := Grey.room(layout, &"roof_catwalks", [Grey.r(-30, -24.5, 30, 30), Grey.r(-24.5, -30, 30, -24.5)] as Array[Rect2], Y, SKY, ZONE, &"ROOM_ROOF_CATWALK", false)
	# the sky over the dome and the gutters (moonlight; "under the sky" for
	# the exhibits' eyes)
	for well in [Grey.r(-10, -10, 10, 10), Grey.r(-22, -29.5, 22, -27), Grey.r(-22, 27, 22, 29.5), Grey.r(-29.5, -20, -27, 22), Grey.r(27, -22, 29.5, 22)]:
		walks.skylights.append(well)
	var deck := layout.room(&"roof_plant")
	deck.skylights.append(Grey.r(25, 37, 33, 43))
	var loft := Grey.box(layout, &"roof_loft", Grey.r(17, 36, 22, 44.5), Y, HUT, ZONE, &"ROOM_ROOF_LOFT", false)
	loft.secret = true
	var shed := Grey.box(layout, &"roof_shed", Grey.r(-30, -30, -25, -25), Y, HUT, ZONE, &"ROOM_ROOF_SHED", false)
	shed.secret = true
	Grey.door(layout, &"roof_stairs_plant", Grey.r(34.5, 44.5, 36.5, 45), Y, Y + 2.5, &"roof_stairs", &"roof_plant", SWING)
	Grey.door(layout, &"roof_plant_catwalks", Grey.r(23, 30, 30, 30.5), Y, Y + 4.0, &"roof_plant", &"roof_catwalks")


## The stair tower: a tube over each landing, a red lamp by the rope hatch
## at the bottom, a camera-free climb.
static func _tower(layout: LevelLayout) -> void:
	var room := &"roof_stairs"
	var low := Floor1Plan.LANDING_Y
	Svc.red(layout, Vector3(17.15, low + 2.9, 49.6), -PI * 0.5, room)
	for spec: Array in [[Vector3(18.3, low + 3.4, 49.0), true], [Vector3(35.7, 11.5 + 2.6, 49.0), false], [Vector3(18.3, 17.0 + 2.6, 49.0), false], [Vector3(35.7, Y + 2.6, 49.0), true]]:
		var lamp := layout.add_light(LightSpec.MAIN, spec[0], Svc.TUBE, 0.9, 6.0, room, &"tube_lamp")
		lamp.fixture_yaw = PI * 0.5 if spec[1] else 0.0
	layout.add_loot(Vector3(18.0, low, 46.5), room)


## The plant deck over the booth and its gutter bridge.
static func _plant_deck(layout: LevelLayout) -> void:
	var room := &"roof_plant"
	layout.add_piece(&"water_tank", Vector3(35.5, Y, 38.2), Vector3(3.0, 3.5, 3.0), room)
	for x in [28.0, 31.5]:
		layout.add_piece(&"plant_unit", Vector3(x, Y, 37.0), Vector3(2.4, 1.6, 1.4), room)
	layout.add_piece(&"chimney", Vector3(24.0, Y, 43.6), Vector3(1.2, 4.5, 1.2), room)
	Svc.red(layout, Vector3(24.0, Y + 4.8, 43.6), 0.0, room)
	layout.add_loot(Vector3(28.0, Y + 1.6, 37.0), room, true)
	layout.add_loot(Vector3(33.0, Y, 42.5), room)
	Hub.wing_sign(layout, &"sign_roof_entrance_1", Vector3(35.5, Y + 2.6, 44.45), 1.6, 0.0, room, &"entrance")
	Hub.look_marker(layout, &"cctv_roof_1", Vector3(23.2, Y + 4.5, 30.9), Vector3(28.25, Y, 0.0), room)
	for at in [Vector3(30.0, MOON_Y, 40.0), Vector3(26.25, MOON_Y, 33.0)]:
		Svc.down(layout, LightSpec.MOON, at, Svc.MOON, 2.5, MOON_REACH, room, &"", 50.0)


## The Reading Room's drum carried up through the roof (16 segments, its
## face on the same 16-gon as the court's), a solid core, the stepped dome
## and the lantern with its red warning lamp; the Lewis chessman left on a
## ledge at its foot, round the back from the shortcut.
static func _dome(layout: LevelLayout) -> void:
	var room := &"roof_catwalks"
	var middle := (DRUM_OUT + DRUM_IN) * 0.5
	for j in 16:
		var bearing := j * 22.5
		layout.add_piece(&"dome_drum", Hub.at_bearing(middle, bearing, Y), Vector3(SEGMENT, 2.5, DRUM_OUT - DRUM_IN), room, Hub.yaw_out(bearing))
	for yaw in [0.0, PI * 0.25]:
		layout.add_piece(&"dome_core", Vector3(0, Y, 0), Vector3(15.8, 2.5, 15.8), room, yaw)
		layout.add_piece(&"dome", Vector3(0, Y + 2.5, 0), Vector3(16.9, 1.5, 16.9), room, yaw, false)
		layout.add_piece(&"dome", Vector3(0, Y + 4.0, 0), Vector3(12.0, 1.3, 12.0), room, yaw, false)
		layout.add_piece(&"dome_lantern", Vector3(0, Y + 5.3, 0), Vector3(3.5, 1.7, 3.5), room, yaw, false)
	Svc.red(layout, Vector3(0, Y + 7.2, 0), 0.0, room, 2.0)
	var ledge := Hub.at_bearing(13.4, 292.5, Y)
	layout.add_piece(&"plinth", ledge, Vector3(0.6, 1.0, 0.6), room)
	layout.add_marker(&"chess_8", ledge + Vector3.UP, room, Hub.yaw_out(292.5))


## The walks: railings along the inner edge of the gutter (a service gate
## into each glass field), along both sides of the four radial catwalks
## and round the dome's ring walk (an octagon, open where the catwalks
## meet it); chimney stacks in the corners; moonlight; the bolted door's
## plate; viewpoints for stage P2 (over the T-Rex, over the hall's arch).
static func _catwalks(layout: LevelLayout) -> void:
	var room := &"roof_catwalks"
	# gutter railings: along each side from corner to catwalk with a gate in
	# the middle of each glass field; the north-west corner turns round the
	# shed
	var stops := [-GUTTER, -14.0 - GATE, -14.0 + GATE, -SPOKE, SPOKE, 14.0 - GATE, 14.0 + GATE, GUTTER]
	for i in range(0, stops.size(), 2):
		var a: float = stops[i]
		var b: float = stops[i + 1]
		var west_a: float = maxf(a, -22.0)
		Svc.rail(layout, Vector3(a, Y, GUTTER), Vector3(b, Y, GUTTER), room)
		Svc.rail(layout, Vector3(GUTTER, Y, a), Vector3(GUTTER, Y, b), room)
		Svc.rail(layout, Vector3(west_a, Y, -GUTTER), Vector3(b, Y, -GUTTER), room)
		Svc.rail(layout, Vector3(-GUTTER, Y, west_a), Vector3(-GUTTER, Y, b), room)
	Svc.rail(layout, Vector3(-22.0, Y, -GUTTER), Vector3(-22.0, Y, -22.0), room)
	Svc.rail(layout, Vector3(-22.0, Y, -22.0), Vector3(-GUTTER, Y, -22.0), room)
	# the radial catwalks
	for side in [-SPOKE, SPOKE]:
		Svc.rail(layout, Vector3(side, Y, -GUTTER), Vector3(side, Y, -RING), room)
		Svc.rail(layout, Vector3(side, Y, RING), Vector3(side, Y, GUTTER), room)
		Svc.rail(layout, Vector3(-GUTTER, Y, side), Vector3(-RING, Y, side), room)
		Svc.rail(layout, Vector3(RING, Y, side), Vector3(GUTTER, Y, side), room)
	# the ring walk's octagon
	var edge := 2.0 * RING * tan(deg_to_rad(22.5))
	for k in 8:
		var bearing := k * 45.0
		var at := Hub.at_bearing(RING, bearing, Y)
		if k % 2 == 1:
			layout.add_piece(&"railing", at, Vector3(edge, Svc.RAIL_HEIGHT, Svc.RAIL_DEPTH), room, Hub.yaw_out(bearing))
			continue
		var half := (edge * 0.5 - SPOKE)
		for side in [-1.0, 1.0]:
			var piece_at: Vector3 = at + Hub.tangent(bearing) * side * (SPOKE + half * 0.5)
			layout.add_piece(&"railing", piece_at, Vector3(half, Svc.RAIL_HEIGHT, Svc.RAIL_DEPTH), room, Hub.yaw_out(bearing))
	for corner in [Vector2(29.25, -29.25), Vector2(29.25, 29.25), Vector2(-29.25, 29.25)]:
		layout.add_piece(&"chimney", Vector3(corner.x, Y, corner.y), Vector3(1.5, 3.0, 1.5), room)
	Hub.wing_sign(layout, &"sign_roof_enlightenment_1", Vector3(29.95, Y + 2.6, -11.25), 1.5, PI * 0.5, room, &"enlightenment")
	layout.add_marker(&"roof_view_1", Vector3(0, Y, -21.0), room)
	layout.add_marker(&"roof_view_2", Vector3(0, Y, 21.0), room, PI)
	# moon pools along the gutters and round the ring
	for at in [Vector2(28.25, 22), Vector2(28.25, 0), Vector2(28.25, -22), Vector2(-28.25, 18), Vector2(-28.25, -4), Vector2(12, -28.25), Vector2(-12, -28.25), Vector2(12, 28.25), Vector2(-12, 28.25)]:
		Svc.down(layout, LightSpec.MOON, Vector3(at.x, MOON_Y, at.y), Svc.MOON, 2.5, MOON_REACH, room, &"", 50.0)
	for bearing in [45.0, 135.0, 225.0, 315.0]:
		Svc.down(layout, LightSpec.MOON, Hub.at_bearing(13.9, bearing, MOON_Y), Svc.MOON, 2.0, MOON_REACH, room, &"", 45.0)
	for at in [Vector2(28.25, 26), Vector2(-28.25, 20), Vector2(14.0, 28.25)]:
		layout.add_loot(Vector3(at.x, Y, at.y), room)
	layout.add_loot(Hub.at_bearing(13.9, 225.0, Y), room)


## Glass fields between the walks (5 cm panes on the court's roof slab:
## stage P2 lays the real glass and truss here), two panes each.
static func _glass(layout: LevelLayout) -> void:
	var room := &"roof_catwalks"
	var inner := SPOKE + 0.1
	var outer := GUTTER - 0.1
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			# along the gutter, then beside the ring walk
			var near_corner := outer if not (sx < 0.0 and sz < 0.0) else 21.9
			_pane(layout, Rect2(minf(sx * inner, sx * near_corner), minf(sz * outer, sz * (RING + 0.1)), absf(near_corner - inner), outer - RING - 0.1), room)
			_pane(layout, Rect2(minf(sx * (RING + 0.1), sx * outer), minf(sz * inner, sz * (RING + 0.1)), outer - RING - 0.1, RING - inner), room)


static func _pane(layout: LevelLayout, rect: Rect2, room: StringName) -> void:
	var middle := rect.get_center()
	var pane := layout.add_piece(&"roof_glass", Vector3(middle.x, Y, middle.y), Vector3(rect.size.x, 0.04, rect.size.y), room)
	pane.tint = Color(0.62, 0.78, 0.86, 0.5)


## The pigeon loft (its hatch on a rope across the deck: a precise shot
## drops it) and the roofers' shed (boarded up: fists, the shotgun).
static func _secrets(layout: LevelLayout) -> void:
	Kit.gate(layout, &"roof_rope_loft", GateSpec.Kind.ROPE, GateSpec.PRECISE, &"GATE_ROPE", &"roof_plant_loft", Grey.r(22, 39, 22.5, 41), Y, 2.4, &"roof_plant", &"roof_loft", OpeningSpec.DoorStyle.GATE)
	var loft := &"roof_loft"
	for z in [36.4, 44.1]:
		layout.add_piece(&"pigeon_cages", Vector3(19.5, Y, z), Vector3(4.2, 1.8, 0.6), loft)
	layout.add_piece(&"crate", Vector3(17.6, Y, 42.0), Vector3(0.8, 0.6, 0.8), loft)
	layout.add_loot(Vector3(17.6, Y + 0.6, 42.0), loft, true)
	layout.add_loot(Vector3(19.5, Y, 38.5), loft)
	layout.add_marker(&"secret_roof_1", Vector3(19.5, Y, 40.25), loft)
	Svc.down(layout, LightSpec.MOON, Vector3(19.5, HUT - 0.3, 40.25), Svc.MOON, 1.0, 2.7, loft, &"", 30.0)
	Kit.gate(layout, &"roof_boards_shed", GateSpec.Kind.BOARDS, GateSpec.HEAVY, &"GATE_BOARDS", &"roof_catwalks_shed", Grey.r(-25, -29, -24.5, -27), Y, 2.4, &"roof_catwalks", &"roof_shed", OpeningSpec.DoorStyle.DOUBLE_SWING)
	var shed := &"roof_shed"
	layout.add_piece(&"shelf", Vector3(-29.65, Y, -27.5), Vector3(3.0, 2.0, 0.5), shed, -PI * 0.5)
	layout.add_piece(&"bench", Vector3(-27.5, Y, -29.6), Vector3(2.2, 0.8, 0.7), shed)
	layout.add_marker(&"note_roof_1", Vector3(-27.5, Y + 0.8, -29.6), shed)
	layout.add_loot(Vector3(-28.4, Y + 0.8, -29.6), shed, true)
	layout.add_loot(Vector3(-27.0, Y, -26.0), shed)
	layout.add_marker(&"secret_roof_2", Vector3(-27.5, Y, -27.5), shed)
	Svc.down(layout, LightSpec.MOON, Vector3(-27.5, HUT - 0.3, -27.5), Svc.MOON, 1.0, 2.7, shed, &"", 30.0)


## Hardly anybody up here: a wax figure that wandered out walks the east
## gutter, or a bust sits on the north catwalk over the T-Rex.
static func _encounters(layout: LevelLayout) -> void:
	var room := &"roof_catwalks"
	Hub.walker(layout, &"roof_gutter_walk", room, 0, WAX.duplicate(), PackedVector3Array([Vector3(28.25, Y, 24), Vector3(28.25, Y, -24)]), false)
	Hub.slots(layout, room, 1, BUST.duplicate(), [Vector2(0, -20.0)], Y, Vector2(0, 0))
