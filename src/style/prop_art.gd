class_name PropArt
## Small helpers for the night-loop props of ArtLibrary.REGISTRY that
## gameplay places (CCTV, terminal, pistol locker, lantern, fuse, loose
## crystal): the locker's hinged door, the lantern's warm light, a screen's
## own material for a viewport picture. Instance them with
## ArtLibrary.try_instance(id) (null = keep a greybox) or, for things to
## pick up, ArtLibrary.pickup(id) (warm rim in the dark).

## Door angle of a fully open locker (it swings out on its left hinge).
const LOCKER_OPEN_DEG := -105.0
const LANTERN_COLOR := Color(1.0, 0.72, 0.42)


## Opens the pistol locker's door: [param amount] 0 shut .. 1 open.
static func set_locker_open(locker: Node3D, amount: float) -> void:
	var door := locker.find_child("door", true, false) as Node3D
	if door != null:
		door.rotation.y = deg_to_rad(LOCKER_OPEN_DEG) * clampf(amount, 0.0, 1.0)


## Where a weapon lies in the locker (its "Pistol" marker), or null.
static func locker_spot(locker: Node3D) -> Node3D:
	return locker.find_child("Pistol", true, false) as Node3D


## A warm light at the lantern model's "Light" marker (in front of the
## lens); returns it (null without the marker).
static func lantern_light(lantern: Node3D, energy: float = 1.2, light_range: float = 3.5) -> OmniLight3D:
	var spot := lantern.find_child("Light", true, false) as Node3D
	if spot == null:
		return null
	var lamp := OmniLight3D.new()
	lamp.light_color = LANTERN_COLOR
	lamp.light_energy = energy
	lamp.omni_range = light_range
	lamp.shadow_enabled = true
	spot.add_child(lamp)
	return lamp


## This prop's own material of screen [param screen_name]
## ("cctv_screen_1".."6" on the cctv_bank, "terminal_screen" on the
## terminal), copied on first use so that setting its albedo_texture /
## emission_texture to a ViewportTexture changes only this screen of this
## prop. Null when the model has no such slot.
static func screen(prop: Node3D, screen_name: String) -> StandardMaterial3D:
	for child in prop.find_children("*", "MeshInstance3D", true, false):
		var view := child as MeshInstance3D
		for i in view.mesh.get_surface_count():
			var mat := view.get_surface_override_material(i)
			if mat == null or mat.resource_name != screen_name:
				continue
			if not mat.has_meta(&"own"):
				mat = mat.duplicate()
				mat.set_meta(&"own", true)
				view.set_surface_override_material(i, mat)
			return mat as StandardMaterial3D
	return null
