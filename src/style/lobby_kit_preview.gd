class_name LobbyKitPreview
extends Node3D
## Dev scene: the real lobby (LobbyLevel: LevelBuilder dresses it with the
## kit through LevelArt and ArtKit, LevelLighting lights it with
## LobbyLightRecipe) with nobody in it but, optionally, the guard. Nothing
## here builds anything of its own any more: what this shows is what the
## game shows. tests/scenarios/kit_preview_runner.gd photographs it
## (tools/run_kit_preview.sh).
## [member dressing] false hides the set dressing (room signs, banners,
## weapon racks, trees, the scenic paintings) to compare.

@export var with_player: bool = true
@export var dressing: bool = true

## Kit ids of the set dressing (LobbyLayout._dressing).
const SET_DRESSING: Array[StringName] = [&"sign_gallery", &"sign_armory", &"sign_diorama", &"sign_hall",
	&"sign_staff", &"banner", &"weapon_rack", &"dead_tree", &"chandelier"]

var level: LobbyLevel
var layout: LevelLayout
var env: Environment
var moon: DirectionalLight3D
var main_lights: Array[Light3D] = []
var emergency_lights: Array[Light3D] = []
## Kit ids that kept the greybox (no art).
var greybox_kits: Dictionary = {}
## The stand-in skeleton on the pedestal.
var trex: Node3D


func _ready() -> void:
	level = LobbyLevel.new()
	level.name = "Lobby"
	add_child(level)
	level.build()
	layout = level.layout
	for node in level.lights.get_children():
		if node is WorldEnvironment:
			env = (node as WorldEnvironment).environment
		elif node is DirectionalLight3D:
			moon = node
		elif node is Light3D and node.is_in_group(LightSpec.MAIN):
			main_lights.append(node)
		elif node is Light3D and node.is_in_group(LightSpec.EMERGENCY):
			emergency_lights.append(node)
	for node in get_tree().get_nodes_in_group(&"level_kit"):
		if not level.is_ancestor_of(node):
			continue
		var kit: StringName = node.get_meta(&"kit", &"")
		if node.get_meta(&"kit_greybox", false):
			greybox_kits[kit] = true
		if kit == &"trex":
			trex = node
		if not dressing and SET_DRESSING.has(kit):
			(node as Node3D).visible = false
	if not dressing:
		var scenes := level.structure.get_node_or_null(^"Scenes") as Node3D
		if scenes != null:
			scenes.visible = false
	if with_player:
		get_viewport().anisotropic_filtering_level = Viewport.ANISOTROPY_16X
		var player := Player.new()
		player.transform = layout.player_start
		add_child(player)
		add_child(PauseMenu.new())
		GameInput.set_gameplay_scene(true)


func _exit_tree() -> void:
	if with_player:
		GameInput.set_gameplay_scene(false)


## Blackout: the warm lamps, their fittings and the glowing kit pieces on
## their circuits off (as the blackout night does); moon, exit signs and
## emergency lamps stay.
func set_main_lights(on: bool) -> void:
	for node in level.lights.get_children():
		if node is Light3D and node.is_in_group(LightSpec.MAIN):
			(node as Light3D).visible = on
		elif node.is_in_group(StringName("%s_fixtures" % LightSpec.MAIN)):
			LevelKit.set_lit(node, on)


## Mesh instances (MultiMesh instances counted one by one) and triangles
## under this scene (for the report).
func stats() -> Dictionary:
	var meshes := 0
	var tris := 0
	for child in find_children("*", "GeometryInstance3D", true, false):
		var mesh: Mesh = null
		var copies := 1
		if child is MeshInstance3D:
			mesh = (child as MeshInstance3D).mesh
		elif child is MultiMeshInstance3D and (child as MultiMeshInstance3D).multimesh != null:
			mesh = (child as MultiMeshInstance3D).multimesh.mesh
			copies = (child as MultiMeshInstance3D).multimesh.instance_count
		if mesh == null:
			continue
		meshes += copies
		for i in mesh.get_surface_count():
			var arrays := mesh.surface_get_arrays(i)
			var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			tris += copies * (index.size() / 3 if index.size() > 0 else (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3)
	return {"meshes": meshes, "triangles": tris, "lights": main_lights.size() + emergency_lights.size()}
