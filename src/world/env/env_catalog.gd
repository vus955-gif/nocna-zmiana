class_name EnvCatalog
## The museum's tagged tools of environmental combat, one per wing and one
## in the hub (plan docs/superpowers/plans/2026-10-21-srodowisko-walka.md,
## backlog #23), as data: where each stands, what it is and what it does.
## EnvLayer builds them (make_tool()). None stands in a guardian's arena
## (those fights are designed on their own) or in the places the biome
## mechanics use (the tomb rooms' darts, the nets' ropes, the Nereid hall's
## mirrors, the clocks, the bells, the fire bowls, the steam valves); the
## placement tests check each one against its room, the floor's openings and
## markers.
## Kinds: &"drop" (EnvDropTool), &"topple" (EnvToppleTool), &"volley"
## (EnvVolleyTool), &"roll" (EnvRollTool).


## Every tool, in the order EnvLayer builds them.
static func tools() -> Array[Dictionary]:
	return [
		# the hub: the entrance hall's chandelier over its benches
		{"id": &"chandelier_entrance", "kind": &"drop", "build": &"chandelier", "room": &"entrance_hall",
			"near": Vector3(0.0, 10.4, 42.0), "radius": 2.4, "exhibit_damage": 150.0, "guard_damage": 35.0,
			"knockback": 10.0, "tag_scale": 2.0},
		# Egypt: the expedition's storm lamp on a long chain from the beam over the camp
		{"id": &"storm_lamp_egypt", "kind": &"drop", "build": &"storm_lamp", "room": &"egypt_gallery",
			"at": Vector3(-40.5, 4.3, 2.5), "mount": Vector3(-40.5, 10.3, 2.5), "radius": 0.9,
			"exhibit_damage": 40.0, "guard_damage": 15.0, "knockback": 3.0, "tag_scale": 1.3,
			"fire": {"radius": 1.5, "seconds": 6.0, "dps": 10.0, "guard": 4.0}},
		# Greece: a cracked column on the conservators' cradle, by the vase room's west wall
		{"id": &"column_greece", "kind": &"topple", "build": &"column", "room": &"greece_vases",
			"at": Vector3(-105.4, 0.0, 26.25), "yaw": -PI * 0.5, "height": 4.7, "width": 0.9, "depth": 0.9,
			"exhibit_damage": 140.0, "guard_damage": 35.0, "knockback": 8.0, "tag_scale": 1.2},
		# the Enlightenment: a tall wall bookcase of the library, anchored by one loose bolt
		{"id": &"bookcase_library", "kind": &"topple", "build": &"bookcase", "kit": &"shelf", "room": &"enlightenment_library",
			"near": Vector3(31.25, 0.0, -17.0), "exhibit_damage": 110.0, "guard_damage": 30.0, "stun": 1.5,
			"knockback": 6.0, "tag_scale": 1.3},
		# Assyria: a relief on its slings under a chain hoist, by the restorers' scaffold in Nimrud
		{"id": &"hoist_nimrud", "kind": &"drop", "build": &"relief_slab", "room": &"assyria_nimrud",
			"at": Vector3(-94.3, 3.4, -46.0), "mount": Vector3(-94.3, 8.0, -46.0), "radius": 1.4,
			"exhibit_damage": 180.0, "guard_damage": 40.0, "knockback": 9.0, "tag_scale": 1.5},
		# Asia: the hwacha's spare fire-arrows in their crate by the Korea hall's north wall
		{"id": &"rockets_korea", "kind": &"volley", "room": &"asia_korea",
			"at": Vector3(40.0, 0.0, -39.65), "yaw": -0.35, "rockets": 6, "spread_deg": 20.0, "reach": 14.0,
			"tag_scale": 1.2},
		# the Americas: a cast of the calendar stone on edge between trestles, by the north hall's
		# south wall east of the mask cases (between the cases it stood 1.5 m from a jaguar's
		# slot: a standing tool keeps 1.25 m clear of every slot); it rolls past the bison's
		# pedestal and west of the tipi, and lies down short of the jaguar's mat at (-10.5, -47.5)
		{"id": &"wheel_americas", "kind": &"roll", "room": &"americas_north",
			"at": Vector3(-11.1, 0.0, -56.75), "yaw": PI, "radius": 1.1, "thickness": 0.4, "distance": 6.5,
			"exhibit_damage": 160.0, "guard_damage": 40.0, "knockback": 10.0, "tag_scale": 1.2},
	] as Array[Dictionary]


## The tool of [param entry] for [param layer] (placed, not yet in the
## tree), or null when its room or the piece it takes over is missing.
static func make_tool(entry: Dictionary, layer: EnvLayer) -> EnvProp:
	match entry.get("kind", &""):
		&"drop":
			return EnvDropTool.make(entry, layer)
		&"topple":
			return EnvToppleTool.make(entry, layer)
		&"volley":
			return EnvVolleyTool.make(entry, layer)
		&"roll":
			return EnvRollTool.make(entry, layer)
	return null
