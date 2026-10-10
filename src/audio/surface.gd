class_name Surface
extends RefCounted
## What a floor is made of, for footsteps. Convention (first match wins):
## 1. metadata "surface" (StringName) on the floor's collider or one of its
##    two parents:  floor_body.set_meta(&"surface", &"wood")
## 2. the collider's physics_material_override named after a surface
##    (PhysicsMaterial.resource_name = "carpet"),
## 3. a group "surface_<name>" on the collider or its parent,
## 4. a level kit piece with a known kit (the balcony is the hall's
##    limestone slab),
## 5. the level room under the point (ROOM_SURFACES, the lobby's rooms),
## 6. STONE.
## Names: stone (marble, limestone, flagstones, terrazzo, concrete, tiles,
## linoleum), wood (parquet, boards), carpet (rugs, runners), metal
## (grates, vents, catwalks). ALIASES maps other words onto them.

const STONE := &"stone"
const WOOD := &"wood"
const CARPET := &"carpet"
const METAL := &"metal"
const ALL: Array[StringName] = [STONE, WOOD, CARPET, METAL]
const ALIASES := {
	&"marble": STONE, &"concrete": STONE, &"tile": STONE, &"tiles": STONE, &"granite": STONE,
	&"limestone": STONE, &"flagstone": STONE, &"terrazzo": STONE, &"linoleum": STONE, &"vinyl": STONE,
	&"parquet": WOOD, &"boards": WOOD, &"planks": WOOD, &"rug": CARPET, &"runner": CARPET, &"fabric": CARPET,
	&"grate": METAL, &"grating": METAL, &"steel": METAL, &"iron": METAL, &"vent": METAL,
	&"basalt": STONE,
	&"gravel": STONE, &"tatami": CARPET,
}
## Kit pieces of LevelKit (meta "kit") with a surface of their own.
const KIT_SURFACES := {&"balcony": STONE, &"stairs": STONE, &"ramp": STONE, &"grate": METAL}
## Rooms whose balcony slabs are not stone (meta "kit_room" of the slab):
## the King's Library's gallery walks on oak boards.
const SLAB_SURFACES := {&"enlightenment_library_gallery": &"boards"}
## Rooms of the lobby -> what their floor is (a name or an alias), as the
## lobby's art kit tiles them (ArtKit.ROOMS "floor"): the marble hall and
## gallery, the balcony's limestone, flagstones in the armory and the
## undercroft, terrazzo before the diorama, concrete in the service
## corridors, the shaft and the stairwell down, worn linoleum in the staff
## corridor and the security room, bare boards in the hidden rooms.
const ROOM_SURFACES := {
	&"hall": &"marble", &"balcony": &"limestone", &"gallery": &"marble", &"armory": &"flagstone",
	&"diorama": &"terrazzo", &"corridor_w": &"concrete", &"corridor_e": &"concrete", &"staff_corridor": &"linoleum",
	&"security": &"linoleum", &"closet": &"boards", &"secret_chamber": &"boards", &"shotgun_niche": &"boards",
	&"vent": &"concrete", &"undercroft": &"flagstone", &"stairwell": &"concrete",
	# Floor I (ArtKit "court", "reading_room", "entrance")
	&"court": &"limestone", &"reading_room": &"carpet", &"entrance": &"marble",
	# Floor I, Enlightenment wing (ArtKit "enlightenment_*"): oak parquet, the rotunda's marble
	&"enlightenment_library": &"parquet", &"enlightenment_cabinet": &"parquet", &"enlightenment_portraits": &"parquet",
	&"enlightenment_clocks": &"parquet", &"enlightenment_librarian": &"parquet", &"enlightenment_planetarium": &"marble",
	# Floor I, Greek wing (ArtKit "greece_*"): marble slabs, bare boards in the cast store
	&"greece_gallery": &"marble", &"greece_nereid": &"marble", &"greece_metopes": &"marble", &"greece_vases": &"marble",
	&"greece_bassae": &"marble", &"greece_casts": &"boards",
	# Floor I, Americas and Oceania wing (ArtKit "americas_*"): polished basalt,
	# dark boards in the Pacific gallery, its pit and the workshop
	&"americas_temple": &"basalt", &"americas_north": &"basalt", &"americas_totems": &"basalt",
	&"americas_moai": &"basalt", &"americas_moai_hideout": &"basalt", &"americas_pacific": &"boards",
	&"americas_pit": &"boards", &"americas_workshop": &"boards",
	# Floor I hub and Egypt, stage P2 (ArtKit styles and the rooms whose
	# floors are not stone): the Reading Room's carpet, the boards of the
	# conservator's room, the old watch room, the lodge and the stores
	&"north_hall": &"marble", &"crypt": &"flagstone", &"egypt_conservator": &"boards", &"cloakroom": &"linoleum",
	&"court_reading": &"carpet", &"booth_watch": &"boards", &"north_hall_lodge": &"boards",
	&"entrance_coat_store": &"boards", &"egypt_cache": &"boards",
	# Floor I, Asia wing (ArtKit "asia_*"): fired tiles, slate, dark boards, raked
	# gravel in the garden, tatami in the tea house
	&"asia_china": &"tiles", &"asia_porcelain": &"stone", &"asia_korea": &"boards", &"asia_armor": &"boards",
	&"asia_garden": &"gravel", &"asia_teahouse": &"tatami",
	# Floor I, Greek and Enlightenment wings, stage P3 (rooms whose id is not
	# their style): the cast store's and the secrets' boards, the cabinets'
	# parquet, the lofts' boards
	&"greece_cast_store": &"boards", &"greece_bassae_loft": &"boards", &"greece_pottery": &"boards",
	&"greece_cast_cellar": &"boards", &"enlightenment_archive": &"parquet", &"enlightenment_study": &"parquet",
	&"enlightenment_attic": &"boards", &"enlightenment_bindery": &"boards", &"enlightenment_observatory": &"marble",
	# Floor I, the basement, stage P3 (ArtKit "basement_*"): concrete, flagstones
	# and linoleum everywhere (stone, the default) but the restorer's boards
	&"basement_workshop": &"boards",
}


## A known surface name for [param word], or &"" (aliases resolved).
static func normalize(word: Variant) -> StringName:
	if word == null:
		return &""
	var key := StringName(str(word).to_lower())
	if ALL.has(key):
		return key
	return ALIASES.get(key, &"")


## The surface of [param collider] (steps land at [param point]).
static func of(collider: Object, point: Vector3, tree: SceneTree = null) -> StringName:
	var node := collider as Node
	var depth := 0
	while node != null and depth < 3:
		if node.has_meta(&"surface"):
			var tagged := normalize(node.get_meta(&"surface"))
			if tagged != &"":
				return tagged
		var body := node as CollisionObject3D
		if body != null and body.get(&"physics_material_override") is PhysicsMaterial:
			var material := body.get(&"physics_material_override") as PhysicsMaterial
			var named := normalize(material.resource_name)
			if named != &"":
				return named
		if depth < 2:
			for surface in ALL:
				if node.is_in_group(StringName("surface_" + String(surface))):
					return surface
		if node.get_meta(&"kit", &"") == &"balcony" and SLAB_SURFACES.has(node.get_meta(&"kit_room", &"")):
			return normalize(SLAB_SURFACES[node.get_meta(&"kit_room")])
		if node.has_meta(&"kit") and KIT_SURFACES.has(node.get_meta(&"kit")):
			return KIT_SURFACES[node.get_meta(&"kit")]
		node = node.get_parent()
		depth += 1
	if tree != null:
		var room := AudioContext.room_at(tree, point)
		if ROOM_SURFACES.has(room):
			return of_room(room)
	return STONE


## The surface of the lobby room [param room] (STONE when unknown).
static func of_room(room: StringName) -> StringName:
	var named := normalize(ROOM_SURFACES.get(room, STONE))
	return named if named != &"" else STONE
