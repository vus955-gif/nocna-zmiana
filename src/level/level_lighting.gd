class_name LevelLighting
## Lights a level from its layout: the environment (night sky colour, dim
## ambient, volumetric fog, tonemapping) and the moon from
## [member LevelLayout.atmosphere], every LightSpec with its fixture, and a
## red emergency lamp with an exit sign over both faces of each marked
## doorway. Groups: &"main_lights" (the blackout modifier switches them
## off), &"emergency_lights" (always on), &"haven_lights"; the Light3D
## nodes are in the group, their fixtures in "<group>_fixtures" (dim those
## too when switching a group off).
## With the lobby recipe (LobbyLightRecipe) the same lamps are tuned per
## room and fitting: one environment with SDFGI sized for the hall, the moon
## aimed down the roof lanterns, a FogVolume per room (the fog lives only
## there), box-projected reflection probes in the marble rooms, the extra
## uplights and washes the kit asks for, and the glowing parts of kit pieces
## (booth lamp, newel globes, case lamps) on their room's circuit.
## Performance: few lights cast shadows (the data decides, each room's
## budget caps it, GraphicsQuality may drop more), every lamp fades out with
## distance.

const DEFAULTS := {
	"background": Color(0.02, 0.025, 0.045),
	"ambient_color": Color(0.32, 0.36, 0.48),
	"ambient_energy": 0.4,
	"fog_density": 0.02,
	"fog_albedo": Color(0.75, 0.8, 1.0),
	"fog_anisotropy": 0.45,
	"fog_length": 80.0,
	"moon_color": Color(0.62, 0.7, 1.0),
	"moon_energy": 0.9,
	"moon_fog_energy": 3.0,
	"moon_rotation": Vector3(-60.0, 160.0, 0.0),
	"moon_shadow_distance": 90.0,
}
## Lamps start fading at this distance (m) and are gone FADE_LENGTH later.
const FADE_BEGIN := 32.0
const FADE_LENGTH := 10.0
const EMERGENCY_FADE_BEGIN := 26.0
const EMERGENCY := Color(1.0, 0.12, 0.08)
## Exit signs hang at least this far under the ceiling of their room.
const EXIT_SIGN_CLEARANCE := 0.25
## Metadata of a lamp whose shadow the design wants (GraphicsQuality keeps
## or drops it): its rank, 0 = the most important (the hall's column lamps).
const SHADOW_RANK := GraphicsQuality.SHADOW_RANK
## Group of every lamp with a designed shadow.
const SHADOWED := GraphicsQuality.SHADOWED
## Lamps that hang upright even when their light is a spot (a wall lamp
## over a picture, a standard lamp throwing long shadows): only a
## spotlight's fitting aims with its beam.
const UPRIGHT_FITTINGS: Array[StringName] = [&"sconce", &"desk_lamp", &"bulb", &"ceiling_lamp", &"tube_lamp", &"chandelier", &"column_lamp"]
## Pieces never put on a room's circuit: the game drives the fuse box's own
## lamps, the CCTV wall is replaced by the monitors.
const OFF_CIRCUIT: Array[StringName] = [&"fuse_box", &"cctv_wall", &"door", &"door_frame", &"furnace_door"]


## Adds environment, moon and all lamps of [param layout] under
## [param parent]. [param builder] provides the doorway frames and which
## rooms wear the art (their fittings come from the kit). [param recipe]:
## true for the lobby's light recipe (LobbyLightRecipe), or a LightRecipe
## (Floor I's) that tunes it all; false: the plain greybox lighting.
static func build(layout: LevelLayout, parent: Node3D, builder: LevelBuilder, recipe: Variant = false) -> void:
	var data: LightRecipe = null
	if recipe is LightRecipe:
		data = recipe
	elif recipe is bool and recipe:
		data = LightRecipe.lobby()
	var settings := DEFAULTS.duplicate()
	settings.merge(layout.atmosphere, true)
	if data != null:
		var world := LobbyLightRecipe.make_environment(data.environment)
		world.add_to_group(GraphicsQuality.ENVIRONMENTS)
		parent.add_child(world)
		var moon := LobbyLightRecipe.make_moon(data.moon)
		moon.add_to_group(&"moon")
		parent.add_child(moon)
		_atmosphere(layout, parent, data)
	else:
		parent.add_child(make_environment(settings))
		parent.add_child(make_moon(settings))
	var shadows := {}
	for spec in layout.lights:
		var tuned := data != null and data.knows(spec.room)
		var light := add_light(parent, spec, builder.tint_of(spec.room), _dressed(builder, spec.room), &"", shadows if tuned else null, data)
		_keep_fog_inside(light, spec, layout.room(spec.room))
		if data != null and not tuned:
			# a room the recipe does not dress has no dust: its lamps stay
			# out of the fog's light lists
			light.light_volumetric_fog_energy = 0.0
	if data != null:
		for entry: Array in _recipe_lights(layout, data):
			var spec: LightSpec = entry[0]
			var light := add_light(parent, spec, Color.WHITE, _dressed(builder, spec.room), entry[1], shadows, data)
			light.set_meta(&"recipe_extra", true)
			if light is SpotLight3D:
				(light as SpotLight3D).spot_attenuation = 0.8
	for passage in layout.openings:
		if passage.exit_signs:
			var frame := builder.passage_frame(passage)
			for face in [1.0, -1.0]:
				var room := layout.room(passage.room_a if face > 0.0 else passage.room_b)
				# over the door, but never into a low ceiling (staff corridor: 3 m)
				var height := passage.height() + 0.45
				if room != null:
					height = minf(height, room.ceiling_y - passage.floor_y - EXIT_SIGN_CLEARANCE)
				var spec := LightSpec.make(LightSpec.EMERGENCY, frame * Vector3(0, height, face * (passage.depth() * 0.5 + 0.12)), EMERGENCY, 0.9, 4.5, room.id if room != null else &"", &"exit_sign")
				# the sign faces the room it hangs in
				spec.fixture_yaw = frame.basis.get_euler().y + (PI if face > 0.0 else 0.0)
				var tuned := data != null and data.knows(spec.room)
				var sign := add_light(parent, spec, Color.WHITE, _dressed(builder, spec.room), &"", shadows if tuned else null, data)
				if not tuned:
					sign.light_volumetric_fog_energy = 0.0
	if data != null:
		add_glow_circuits(parent, [builder.walk_root, builder.haven_root, builder.structure_root], layout)
	LampFlicker.attach(parent)
	GraphicsQuality.apply_level(parent)


## True when [param room]'s fittings come from the kit.
static func _dressed(builder: LevelBuilder, room: StringName) -> bool:
	return builder != null and builder.dresses(room)


static func make_environment(settings: Dictionary) -> WorldEnvironment:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = settings["background"]
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = settings["ambient_color"]
	env.ambient_light_energy = settings["ambient_energy"]
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.ssao_enabled = true
	env.glow_enabled = true
	env.glow_bloom = 0.05
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = settings["fog_density"]
	env.volumetric_fog_albedo = settings["fog_albedo"]
	env.volumetric_fog_anisotropy = settings["fog_anisotropy"]
	env.volumetric_fog_length = settings["fog_length"]
	var world := WorldEnvironment.new()
	world.name = "Environment"
	world.environment = env
	return world


static func make_moon(settings: Dictionary) -> DirectionalLight3D:
	var moon := DirectionalLight3D.new()
	moon.name = "Moon"
	moon.light_color = settings["moon_color"]
	moon.light_energy = settings["moon_energy"]
	moon.light_volumetric_fog_energy = settings["moon_fog_energy"]
	moon.rotation_degrees = settings["moon_rotation"]
	moon.shadow_enabled = true
	moon.directional_shadow_max_distance = settings["moon_shadow_distance"]
	moon.add_to_group(&"moon")
	return moon


## One lamp (omni or spot) plus its visible fixture. [param art]: the
## fixture from the lobby kit (ArtKit.fixture) instead of the greybox.
## [param shadows] (room -> shadows so far) turns on the recipe: the room's
## budget, fog and fade from LobbyLightRecipe, the fitting's rules from
## [param rule] (else the fixture's own, else a ceiling lamp's).
static func add_light(parent: Node3D, spec: LightSpec, tint: Color, art: bool = false, rule: StringName = &"", shadows: Variant = null, recipe: LightRecipe = null) -> Light3D:
	var light: Light3D
	if spec.kind == LightSpec.Kind.SPOT:
		var spot := SpotLight3D.new()
		spot.spot_range = spec.light_range
		spot.spot_angle = spec.spot_angle
		var up := Vector3.UP if absf(spec.direction.normalized().dot(Vector3.UP)) < 0.99 else Vector3.FORWARD
		spot.transform = Transform3D(Basis.looking_at(spec.direction, up), spec.position)
		light = spot
	else:
		var omni := OmniLight3D.new()
		omni.omni_range = spec.light_range
		omni.omni_attenuation = 1.2
		omni.position = spec.position
		light = omni
	light.name = "%s_light" % spec.group
	light.light_color = spec.color
	light.light_energy = spec.energy
	light.shadow_enabled = spec.shadow
	light.distance_fade_enabled = true
	var emergency := spec.group == LightSpec.EMERGENCY
	light.distance_fade_begin = EMERGENCY_FADE_BEGIN if emergency else FADE_BEGIN
	light.distance_fade_length = FADE_LENGTH
	light.distance_fade_shadow = FADE_BEGIN * 0.6
	var rank := 0 if spec.fixture == &"column_lamp" else 1
	if shadows is Dictionary:
		rank = _tune(light, spec, rule, shadows, recipe if recipe != null else _lobby_recipe())
	if light is OmniLight3D and light.shadow_enabled:
		# two paraboloids instead of a cube map: far cheaper, fine at this range
		(light as OmniLight3D).omni_shadow_mode = OmniLight3D.SHADOW_DUAL_PARABOLOID
	if light.shadow_enabled:
		light.add_to_group(SHADOWED)
		light.set_meta(SHADOW_RANK, rank)
	light.add_to_group(spec.group)
	light.set_meta(&"room", spec.room)
	parent.add_child(light)
	if spec.fixture != &"":
		var size: Vector3 = LevelKit.FIXTURE_SIZES.get(spec.fixture, Vector3(0.4, 0.4, 0.4))
		var look := LevelArt.as_visual(ArtKit.fixture(spec.fixture, spec.room)) if art else null
		if look != null:
			# the fitting never shades its own bulb
			for view in look.find_children("*", "GeometryInstance3D", true, false):
				(view as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# a spotlight's fitting aims with its beam; others, the upright
		# fittings (UPRIGHT_FITTINGS) and ceiling lamps aimed straight down
		# (tubes, bulbs) turn about Y only
		var mount := Transform3D(Basis(Vector3.UP, spec.fixture_yaw), spec.position)
		if spec.kind == LightSpec.Kind.SPOT and not UPRIGHT_FITTINGS.has(spec.fixture) and spec.direction.normalized().dot(Vector3.DOWN) < 0.99:
			mount = light.transform
		var fixture := LevelKit.make(spec.fixture, size, mount, tint, false, {}, look)
		fixture.set_meta(&"kit_room", spec.room)
		fixture.add_to_group(StringName("%s_fixtures" % spec.group))
		fixture.set_meta(&"light", light)
		parent.add_child(fixture)
	return light


## The recipe on one lamp: the fitting's fog and energy, the room's fade,
## and a shadow only where the layout wants one and the room's budget
## still allows it (a room may count as another: the balcony as the hall).
## Returns the shadow's rank (0 = the most important to keep).
static func _tune(light: Light3D, spec: LightSpec, rule: StringName, shadows: Dictionary, recipe: LightRecipe) -> int:
	var room := recipe.key(spec.room)
	var fitting := rule if rule != &"" else (spec.fixture if spec.fixture != &"" else _fitting(spec, recipe))
	var used: int = shadows.get(room, 0)
	LobbyLightRecipe.tune(light, fitting, room, used, recipe.rooms, recipe.fixtures)
	var budget := int((recipe.rooms.get(room, {}) as Dictionary).get("shadowed", 0))
	light.shadow_enabled = spec.shadow and used < budget
	if light.shadow_enabled:
		shadows[room] = used + 1
	var rule_data: Dictionary = recipe.fixtures.get(fitting, {})
	return int(rule_data.get("rank", 0 if fitting == &"column_lamp" else 1))


## The fitting rule of a lamp the layout gives no fixture: the recipe's
## rule for its group or kind when it has one (moonlight pools, red
## lamps, bare spotlights), else a ceiling lamp's.
static func _fitting(spec: LightSpec, recipe: LightRecipe) -> StringName:
	var wanted := &""
	if spec.group == LightSpec.MOON:
		# the room may want its moonlight as a shaft (a single beam through an
		# oculus) rather than a pool under a glass roof
		wanted = StringName((recipe.rooms.get(recipe.key(spec.room), {}) as Dictionary).get("moon_rule", &"moon_pool"))
	elif spec.group == LightSpec.EMERGENCY:
		wanted = &"bare_red"
	elif spec.color.b > spec.color.r + 0.2:
		# a cold fill standing in for moonlight in a lit room: no haze (the
		# real moon's shafts are the directional light's)
		wanted = &"cold_fill"
	elif spec.kind == LightSpec.Kind.SPOT:
		wanted = &"bare_spot"
	return wanted if wanted != &"" and recipe.fixtures.has(wanted) else &"ceiling_lamp"


static var _lobby: LightRecipe = null


static func _lobby_recipe() -> LightRecipe:
	if _lobby == null:
		_lobby = LightRecipe.lobby()
	return _lobby


## The recipe's extra lamps (main lights unless the recipe says otherwise,
## no shadows unless it asks): the lobby's uplights behind the balustrade
## and the diorama's backdrop wash, Floor I's (Floor1LightRecipe), and the
## globes on the hall's grand stairs' newels (their glowing models come with
## the stairs).
## Each entry: [LightSpec, fitting rule] (an extra's "rule", else a sconce's).
static func _recipe_lights(layout: LevelLayout, recipe: LightRecipe) -> Array:
	var out: Array = []
	for extra: Dictionary in recipe.extra_lights:
		if layout.room(extra["room"]) == null:
			continue
		var spec := LightSpec.make(extra.get("group", LightSpec.MAIN), extra["position"], extra["color"], extra["energy"], extra["range"], extra["room"], extra.get("fixture", &""), extra.get("shadow", false))
		spec.fixture_yaw = float(extra.get("fixture_yaw", 0.0))
		if extra.has("direction"):
			spec.kind = LightSpec.Kind.SPOT
			spec.direction = extra["direction"]
			spec.spot_angle = extra["angle"]
		out.append([spec, StringName(extra.get("rule", &"sconce"))])
	for flight in layout.stairs:
		if flight.room_low != &"hall" or flight.width() < 3.0:
			continue
		for side in [-1.0, 1.0]:
			if (side < 0.0 and not flight.rail_left) or (side > 0.0 and not flight.rail_right):
				continue
			var at := flight.frame() * Vector3(side * (flight.width() * 0.5 + 0.07), 2.56, 0.35)
			out.append([LightSpec.make(LightSpec.MAIN, at, Color(1.0, 0.74, 0.46), 1.2, 6.0, flight.room_low), &"sconce"])
	return out


## Fog volumes (dust where the air stands) and reflection probes (marble)
## per carved room part the recipe knows (a room of many parts - the
## Reading Room's bands - gets one box over its bounds).
static func _atmosphere(layout: LevelLayout, parent: Node3D, recipe: LightRecipe) -> void:
	for room in layout.rooms:
		var key := recipe.key(room.id)
		if not room.carved or not recipe.rooms.has(key):
			continue
		var r: Dictionary = recipe.rooms[key]
		var boxes: Array[AABB] = []
		if room.parts.size() > 3:
			var b := room.bounds()
			boxes.append(AABB(Vector3(b.position.x, room.floor_y, b.position.y), Vector3(b.size.x, room.height(), b.size.y)))
		else:
			for part in room.parts:
				boxes.append(AABB(Vector3(part.position.x, room.floor_y, part.position.y), Vector3(part.size.x, room.height(), part.size.y)))
		for box in boxes:
			if float(r.get("fog", 0.0)) > 0.0:
				var fog := LobbyLightRecipe.make_fog(key, box, recipe.rooms)
				fog.add_to_group(GraphicsQuality.FOG_VOLUMES)
				fog.set_meta(&"room", room.id)
				parent.add_child(fog)
			var probe := LobbyLightRecipe.make_probe(key, box, recipe.rooms)
			if probe != null:
				probe.add_to_group(GraphicsQuality.PROBES)
				probe.set_meta(&"room", room.id)
				parent.add_child(probe)


## Puts the glowing parts of kit pieces under [param roots] (a booth's lamp,
## the newel globes of the stairs, the lamp strips of display cases) on
## their room's main circuit: one node per room in "main_lights_fixtures"
## whose "lit_targets" are those looks, so the blackout and the power cut
## dim them with the lamps. Havens keep theirs.
static func add_glow_circuits(parent: Node3D, roots: Array, layout: LevelLayout) -> void:
	var by_room := {}
	for root: Variant in roots:
		if not is_instance_valid(root):
			continue
		for piece in (root as Node).get_children():
			var kit: StringName = piece.get_meta(&"kit", &"")
			if kit == &"" or OFF_CIRCUIT.has(kit):
				continue
			var look := piece.get_node_or_null(^"Visual")
			if look == null or not LevelKit.is_lit(look):
				continue
			var room: StringName = piece.get_meta(&"kit_room", &"")
			var spec := layout.room(room)
			if spec == null or spec.haven:
				continue
			if not by_room.has(room):
				by_room[room] = []
			(by_room[room] as Array).append(look)
	for room: StringName in by_room:
		var circuit := Node3D.new()
		circuit.name = "Glow_%s" % room
		circuit.set_meta(&"kit", &"glow_circuit")
		circuit.set_meta(&"kit_room", room)
		circuit.set_meta(&"lit_targets", by_room[room])
		circuit.add_to_group(StringName("%s_fixtures" % LightSpec.MAIN))
		parent.add_child(circuit)


## Volumetric fog is not stopped by walls when a lamp casts no shadow: a
## lamp whose reach leaves its room would glow through the wall into the
## next one (and give away a secret room). Such lamps light the fog not.
static func _keep_fog_inside(light: Light3D, spec: LightSpec, room: RoomSpec) -> void:
	if spec.shadow or room == null:
		return
	var reach := spec.light_range
	var around := Rect2(spec.position.x - reach, spec.position.z - reach, reach * 2.0, reach * 2.0)
	for part in room.parts:
		if part.encloses(around):
			return
	light.light_volumetric_fog_energy = 0.0
