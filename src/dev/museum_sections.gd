class_name MuseumSections
extends RefCounted
## The subsystems of the running game as CpuSections (the overlay's
## "systems" view and the CPU profile tool). A node belongs to the first
## section that names it, so the specific ones come first and "world" and
## "autoloads" take what is left of the scene and of the autoloads.

## Section names in order. The first four are engine nodes of one kind
## wherever they stand in the scene (they process themselves: an exhibit's
## path-following agent, a 3D sound source, an animation, particles); they
## are cut out of the subsystems they belong to so that the subsystems show
## the game's own scripts and these show the engine's work.
const NAMES: Array[StringName] = [&"navigation", &"audio_3d", &"animation", &"particles", &"player", &"exhibits", &"guardians",
		&"interface", &"level", &"environment", &"floor_game", &"fx", &"music", &"ambience", &"voice", &"world", &"autoloads"]
## Section -> the engine classes it takes.
const NATIVE := {
	&"navigation": ["NavigationAgent3D"],
	&"audio_3d": ["AudioStreamPlayer3D"],
	&"animation": ["AnimationPlayer", "AnimationTree"],
	&"particles": ["GPUParticles3D", "CPUParticles3D"],
}


## Adds the sections for the game scene [param scene] (the Museum; nothing
## holds on to it: a freed scene just gives empty sections).
static func setup(sections: CpuSections, scene: Node) -> void:
	var tree := scene.get_tree()
	var scene_ref: WeakRef = weakref(scene)
	var root_ref: WeakRef = weakref(tree.root)
	for section: StringName in NATIVE:
		var kinds: Array = NATIVE[section]
		sections.add_section(section, func() -> Array:
			var held := scene_ref.get_ref() as Node
			var found: Array = []
			if held != null:
				for kind: String in kinds:
					found.append_array(held.find_children("*", kind, true, false))
			return found, false)
	sections.add_section(&"player", func() -> Array: return _group(tree, &"player"))
	# (the clock that ticks the dozing exhibits belongs with them)
	sections.add_section(&"exhibits", func() -> Array: return _group(tree, &"enemies") + _autoloads(root_ref, ["ExhibitClock"]), true, true)
	sections.add_section(&"guardians", func() -> Array: return _group(tree, &"guardians"), true, true)
	sections.add_section(&"interface", func() -> Array:
		var out: Array = []
		var held := scene_ref.get_ref() as Node
		if held != null:
			for child in held.get_children():
				if child is CanvasLayer or child is Control:
					out.append(child)
		return out)
	sections.add_section(&"level", func() -> Array:
		var held := scene_ref.get_ref() as Node
		var level := AudioContext.level(tree) if held != null else null
		return [level] if level != null else [])
	sections.add_section(&"environment", func() -> Array: return _group(tree, EnvLayer.GROUP))
	sections.add_section(&"floor_game", func() -> Array:
		var held := scene_ref.get_ref() as Node
		var out: Array = []
		if held != null:
			for child in held.get_children():
				if child is FloorGame:
					out.append(child)
		return out)
	sections.add_section(&"fx", func() -> Array: return _autoloads(root_ref, ["Fx", "Sfx"]))
	sections.add_section(&"music", func() -> Array: return _autoloads(root_ref, ["Music"]))
	sections.add_section(&"ambience", func() -> Array: return _autoloads(root_ref, ["Ambience", "Foley"]))
	sections.add_section(&"voice", func() -> Array: return _autoloads(root_ref, ["VoiceDirector"]))
	sections.add_section(&"world", func() -> Array:
		var held := scene_ref.get_ref() as Node
		return [held] if held != null else [])
	sections.add_section(&"autoloads", func() -> Array:
		var held := root_ref.get_ref() as Node
		return held.get_children() if held != null else [], false)


static func _group(tree: SceneTree, group: StringName) -> Array:
	return tree.get_nodes_in_group(group)


static func _autoloads(root_ref: WeakRef, autoloads: Array) -> Array:
	var out: Array = []
	var root := root_ref.get_ref() as Node
	if root != null:
		for autoload: String in autoloads:
			var node := root.get_node_or_null(autoload)
			if node != null:
				out.append(node)
	return out
