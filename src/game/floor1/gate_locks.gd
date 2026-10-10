class_name GateLocks
extends RefCounted
## Which node stands in a Floor I gate (design 4.2): the real lock of the
## p1-weapons branch for its kind (ChainLock, BoardsLock, CrackedWall,
## RopeLock, HookLock, BoltLock, PowerShutter - found by class name, or
## put into [member registry] by whoever merges the branches), a greybox
## GreyLock with the same contract when that class is not in the build, and
## SealGate for the seals and the gates the game opens itself.
## Every one of them has the GateLock contract: gate_id, size, signal
## opened, open_instantly(), open(), blocks_passage(), is_open.

## GateSpec.Kind -> the lock's class name on the p1-weapons branch.
const CLASS_NAMES := {
	GateSpec.Kind.CHAIN: &"ChainLock",
	GateSpec.Kind.BOARDS: &"BoardsLock",
	GateSpec.Kind.CRACKED: &"CrackedWall",
	GateSpec.Kind.ROPE: &"RopeLock",
	GateSpec.Kind.HOOK: &"HookLock",
	GateSpec.Kind.BOLT: &"BoltLock",
	GateSpec.Kind.POWER: &"PowerShutter",
}

## Greybox pieces of the layouts that stand in for a real lock's body (the
## deck over the Americas' gap is the canoe's): GateSpec.Kind -> kits.
const STAND_INS := {GateSpec.Kind.HOOK: [&"canoe_bridge"]}

## GateSpec.Kind -> Script of its lock (checked before the class names;
## tests and the merge may fill it).
static var registry: Dictionary = {}
## Class name -> script path of every global class (read once).
static var _classes: Dictionary = {}


## A new lock node for [param kind], not in the tree yet.
static func make(kind: GateSpec.Kind) -> Node3D:
	if kind == GateSpec.Kind.SEAL or kind == GateSpec.Kind.EVENT:
		return SealGate.make(kind)
	var script := script_for(kind)
	if script != null:
		var lock: Variant = script.new()
		if lock is Node3D:
			return lock
		push_warning("GateLocks: the lock class for %s is no Node3D" % GateSpec.kind_name(kind))
	return GreyLock.make(kind)


## The real lock's script for [param kind] (null: none in this build).
static func script_for(kind: GateSpec.Kind) -> Script:
	if registry.has(kind):
		return registry[kind]
	var class_id: StringName = CLASS_NAMES.get(kind, &"")
	if class_id == &"":
		return null
	if _classes.is_empty():
		for entry: Dictionary in ProjectSettings.get_global_class_list():
			_classes[StringName(entry["class"])] = String(entry["path"])
	var path: String = _classes.get(class_id, "")
	return load(path) as Script if path != "" else null


## The stand-in kits to leave out of a level whose gates get this build's
## real locks (their bodies take over: the canoe lies across the gap only
## once the harpoon pulls it down).
static func replaced_kits() -> Array[StringName]:
	var kits: Array[StringName] = []
	for kind: GateSpec.Kind in STAND_INS:
		if script_for(kind) != null:
			for kit: StringName in STAND_INS[kind]:
				kits.append(kit)
	return kits


## True when [param lock] is a real lock of the p1-weapons branch (not a
## stand-in of this module).
static func is_real(lock: Node) -> bool:
	return lock != null and not lock is GreyLock and not lock is SealGate


## True when [param lock] keeps the GateLock contract.
static func has_contract(lock: Object) -> bool:
	if lock == null or not lock.has_signal(&"opened"):
		return false
	for method: StringName in [&"open_instantly", &"open", &"blocks_passage"]:
		if not lock.has_method(method):
			return false
	return &"gate_id" in lock and &"size" in lock and &"is_open" in lock
