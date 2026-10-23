class_name FoundWeapon
## Taking a weapon found in the museum (the chained gatling, the flare gun
## in the fire cabinet): it is the guard's for good (GameState.weapons,
## saved at once) and in his hands at once, with its starting ammo.


## Gives weapon [param id] to [param guard]. False when he cannot take it
## (dead, or no guard). [param persistent] false (dev arenas) only hands it
## over: nothing is recorded or saved.
static func give(guard: Player, id: StringName, persistent: bool = true) -> bool:
	if guard == null or not guard.alive:
		return false
	if persistent:
		GameState.add_weapon(id)
	var had := guard.weapons.has_weapon(id)
	var state := Loadout.grant(guard, id, GameState)
	if state != null:
		guard.weapons.select_id(id)
		if not had:
			guard.weapons.found(id)   # new: looked over at the first calm moment
	if persistent:
		NightRules.save_progress(GameState, RunState)
	Sfx.play(&"pickup")
	return true


## A weapon model for display in the world (the greybox exhibits, when
## their Blender models are missing): the greybox first-person model with
## plain (non-viewmodel) materials, [param size] times bigger (never the
## Blender viewmodel: that one carries the guard's hands).
static func display_model(id: StringName, size: float) -> Node3D:
	var holder := Node3D.new()
	holder.scale = Vector3.ONE * size
	var view := Viewmodels.greybox(id)
	view.process_mode = Node.PROCESS_MODE_DISABLED   # a still exhibit
	holder.add_child(view)
	WeaponPickup._world_materials(view)
	for node in view.find_children("*", "GeometryInstance3D", true, false):
		(node as GeometryInstance3D).layers = 1   # a world object, not a first-person one
	return holder
