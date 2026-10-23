class_name CpuSections
extends Node
## Script time per subsystem without touching the game's code (plan
## 2026-10-21-sterowanie-nakladka). The engine runs the _process and
## _physics_process of the nodes by their process priority, then by their
## place in the tree. A section is a group of nodes (a subsystem); installing
## gives all the nodes of a section one shared priority, with a stamp node
## just before it and one just after: the time between the two stamps of a
## frame is what the callbacks of that group cost, exactly. Used by the dev
## overlay (its "systems" view) and by tools/run_cpu_profile.sh.
## - Every node of a section is claimed, scripted or not: engine nodes
##   process themselves too (animation players, particles, 3D audio). A node
##   that was not there at install() joins at the next rescan() (scanning a
##   big section, the whole scene, takes tens of ms: a section added as
##   [i]live[/i] is cheap to look at again and rescan(true) visits only
##   those).
## - A signal handler runs inside whoever emitted the signal, so its time
##   counts for the emitter's section. The physics server's step, timers and
##   tweens belong to no section (the report's "unattributed").
## - The sections run after everything else (their priorities are high), in
##   the order they were added: measuring changes the order of the callbacks a
##   little. uninstall() puts every priority back.

## Priority of the first section; each next one is STEP higher (the stamps
## stand at +-1).
const FIRST_PRIORITY := 1000
const STEP := 10

## Section names in the order added.
var names: Array[StringName] = []
## Keep every frame's value of every section (the CPU profile wants
## percentiles); off, only the sums are kept.
var keep_samples: bool = false
## Per section: {"idle": Array, "physics": Array} of floats (ms per frame /
## per tick), only with keep_samples.
var samples: Dictionary = {}

var _roots: Array[Callable] = []
var _deep: Array[bool] = []
var _live: Array[bool] = []
## Section -> accumulated microseconds and the number of frames / ticks.
var _idle_us := PackedFloat64Array()
var _physics_us := PackedFloat64Array()
var _idle_frames := PackedInt32Array()
var _physics_ticks := PackedInt32Array()
var _idle_began := PackedInt64Array()
var _physics_began := PackedInt64Array()
## Claimed node id -> [node, old process_priority, old process_physics_priority].
var _claimed: Dictionary = {}
var _stamps: Array[Node] = []
var _installed := false


## A section: [param roots] returns the nodes whose callbacks (and, with
## [param deep], those of everything below them) belong to it. Add sections
## before install(); a node goes to the first section that claims it, so put
## the specific ones first. A [param live] section is one whose nodes come
## and go during play (the exhibits) and are cheap to find.
func add_section(section: StringName, roots: Callable, deep: bool = true, live: bool = false) -> void:
	names.append(section)
	_roots.append(roots)
	_deep.append(deep)
	_live.append(live)
	_idle_us.append(0.0)
	_physics_us.append(0.0)
	_idle_frames.append(0)
	_physics_ticks.append(0)
	_idle_began.append(0)
	_physics_began.append(0)
	samples[section] = {"idle": [], "physics": []}


func is_installed() -> bool:
	return _installed


func priority_of(section_index: int) -> int:
	return FIRST_PRIORITY + STEP * section_index


## Gives the nodes of every section their priority and puts the stamps in.
func install() -> void:
	if _installed:
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	_installed = true
	for i in names.size():
		_stamps.append(_stamp_node(i, false))
		_stamps.append(_stamp_node(i, true))
	rescan()


## Claims the nodes that came after install() (or the last rescan); with
## [param live_only] looks at the live sections only.
func rescan(live_only: bool = false) -> void:
	if not _installed:
		return
	for i in names.size():
		if live_only and not _live[i]:
			continue
		var found: Variant = _roots[i].call()
		for root: Variant in found:
			if not is_instance_valid(root):
				continue
			_claim(root as Node, i)
			if _deep[i]:
				for node in (root as Node).find_children("*", "", true, false):
					_claim(node, i)


## How many nodes the sections hold.
func claimed_count() -> int:
	return _claimed.size()


## Puts every priority back and takes the stamps out.
func uninstall() -> void:
	if not _installed:
		return
	_installed = false
	for id: int in _claimed:
		var entry: Array = _claimed[id]
		if is_instance_valid(entry[0]):
			(entry[0] as Node).process_priority = entry[1]
			(entry[0] as Node).process_physics_priority = entry[2]
	_claimed.clear()
	for stamp in _stamps:
		if is_instance_valid(stamp):
			stamp.queue_free()
	_stamps.clear()


func _exit_tree() -> void:
	uninstall()


## Forgets what was measured so far.
func reset() -> void:
	for i in names.size():
		_idle_us[i] = 0.0
		_physics_us[i] = 0.0
		_idle_frames[i] = 0
		_physics_ticks[i] = 0
		samples[names[i]] = {"idle": [], "physics": []}


## Per section since the last reset(): {"idle_ms": mean ms per frame (the
## _process callbacks), "physics_ms": mean ms per tick, "idle_sum_us",
## "physics_sum_us"}.
func report() -> Dictionary:
	var out := {}
	for i in names.size():
		out[names[i]] = {
			"idle_ms": _idle_us[i] / 1000.0 / maxi(_idle_frames[i], 1),
			"physics_ms": _physics_us[i] / 1000.0 / maxi(_physics_ticks[i], 1),
			"idle_sum_us": _idle_us[i],
			"physics_sum_us": _physics_us[i],
		}
	return out


## Section names by cost (idle + physics ms), dearest first.
func ranked() -> Array[StringName]:
	var order: Array[StringName] = names.duplicate()
	var cost := report()
	order.sort_custom(func(a: StringName, b: StringName) -> bool:
		return float(cost[a]["idle_ms"]) + float(cost[a]["physics_ms"]) > float(cost[b]["idle_ms"]) + float(cost[b]["physics_ms"]))
	return order


func _claim(node: Node, section_index: int) -> void:
	if node == self or node is Stamp or _claimed.has(node.get_instance_id()):
		return
	_claimed[node.get_instance_id()] = [node, node.process_priority, node.process_physics_priority]
	node.process_priority = priority_of(section_index)
	node.process_physics_priority = priority_of(section_index)


func _stamp_node(section_index: int, end: bool) -> Stamp:
	var stamp := Stamp.new()
	stamp.sections = self
	stamp.section = section_index
	stamp.end = end
	stamp.process_mode = Node.PROCESS_MODE_ALWAYS
	var priority := priority_of(section_index) + (1 if end else -1)
	stamp.process_priority = priority
	stamp.process_physics_priority = priority
	add_child(stamp)
	return stamp


func _mark(section_index: int, end: bool, physics: bool) -> void:
	var now := Time.get_ticks_usec()
	if not end:
		if physics:
			_physics_began[section_index] = now
		else:
			_idle_began[section_index] = now
		return
	if physics:
		var spent := float(now - _physics_began[section_index])
		_physics_us[section_index] += spent
		_physics_ticks[section_index] += 1
		if keep_samples:
			(samples[names[section_index]]["physics"] as Array).append(spent / 1000.0)
	else:
		var spent := float(now - _idle_began[section_index])
		_idle_us[section_index] += spent
		_idle_frames[section_index] += 1
		if keep_samples:
			(samples[names[section_index]]["idle"] as Array).append(spent / 1000.0)


## The node standing just before or after a section.
class Stamp extends Node:
	var sections: CpuSections
	var section: int = 0
	var end: bool = false

	func _process(_delta: float) -> void:
		sections._mark(section, end, false)

	func _physics_process(_delta: float) -> void:
		sections._mark(section, end, true)
