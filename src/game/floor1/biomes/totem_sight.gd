class_name TotemSight
extends BiomeDevice
## The totems see by fire (plan 2026-10-21-mechaniki-biomow, mechanic 6):
## every CHECK s it works out whether the guard stands in firelight - the
## fiery lamps of the room he is in (the fire bowls while they burn, the
## torches), FIRELIGHT_SEEN at his chest - or shows his own torch (the
## flashlight: a light is a light). While he does not, every totem of the
## wing's rooms is blind beyond BLIND_RANGE (its close sense stays); while
## he does, it sees as far as ever. Jaguars and the rest see as always: the
## dark that hides him from the poles hides the flankers from him. A fire
## counts while it burns and has power (a blackout puts the bowls' glow out
## too: SacredFire.glowing()).

const CHECK := 0.2
## Light from fire at the guard's chest that the totems see him by.
const FIRELIGHT_SEEN := 0.2
const BLIND_RANGE := 2.5
const CHEST := 1.0

## [LightSpec, Callable -> bool (lit now)] of every fiery lamp.
var fires: Array = []
## The rooms whose totems and fires it reads (room id -> true; empty: any).
var rooms: Dictionary = {}
## The guard stood in firelight at the last check.
var guard_lit := true

var _check_left: float = 0.0


## The sight of [param bowls] alone (a sandbox).
static func create(bowls: Array) -> TotemSight:
	var sight := TotemSight.new()
	for bowl: SacredFire in bowls:
		if bowl.spec != null:
			sight.fires.append([bowl.spec, func() -> bool: return is_instance_valid(bowl) and bowl.glowing()])
	return sight


## The sight of the wing on [param layout]: its rooms (the arenas left out),
## the [param bowls] and every other fire lamp there (torches: lit while
## their lamp node shows).
static func for_layout(layout: LevelLayout, bowls: Array[SacredFire], host: BiomeMechanics) -> TotemSight:
	var sight := create(bowls)
	for room in layout.rooms:
		if room.zone == &"americas" and host.serves(room.id):
			sight.rooms[room.id] = true
	var taken := {}
	for bowl in bowls:
		if bowl.spec != null:
			taken[bowl.spec] = true
	for lamp in layout.lights:
		if taken.has(lamp) or not sight.rooms.has(lamp.room) or not is_fire(lamp.color):
			continue
		var node := _lamp_node(host.level, lamp)
		sight.fires.append([lamp, func() -> bool: return node == null or not is_instance_valid(node) or node.visible])
	return sight


## A fire's colour: red-orange, nothing like the museum's warm bulbs.
static func is_fire(color: Color) -> bool:
	return color.r >= 0.95 and color.g <= 0.6 and color.b <= 0.3


static func _lamp_node(level: MuseumFloorLevel, lamp: LightSpec) -> Light3D:
	if level == null or level.lights == null:
		return null
	for node in level.lights.get_children():
		if node is Light3D and (node as Node3D).position.distance_to(lamp.position) < 0.05:
			return node as Light3D
	return null


func _physics_process(delta: float) -> void:
	_check_left -= delta
	if _check_left > 0.0:
		return
	_check_left = CHECK
	var player := guard()
	if player == null:
		return
	guard_lit = in_firelight(player)
	for exhibit in PerceptionWorld.exhibits():
		if exhibit is Totem and (rooms.is_empty() or rooms.has(exhibit.current_room())):
			apply(exhibit)


## True when [param player] stands lit by fire or shows his torch.
func in_firelight(player: Player) -> bool:
	if player.battery.on:
		return true
	return firelight_at(player.global_position + Vector3.UP * CHEST) >= FIRELIGHT_SEEN


## How lit by fire [param point] is (the fires of its room).
func firelight_at(point: Vector3) -> float:
	var room := PerceptionWorld.room_at(point)
	var total := 0.0
	for entry: Array in fires:
		var lamp: LightSpec = entry[0]
		if not rooms.is_empty() and lamp.room != room:
			continue
		if not (entry[1] as Callable).call():
			continue
		total += LayoutIllumination.contribution(lamp, point)
	return total


## Gives [param totem] its sight for the guard's light now: capped at
## BLIND_RANGE in the dark, as it was (and as anything else made it) in the
## light (ExhibitMods).
func apply(totem: Enemy) -> void:
	if guard_lit:
		ExhibitMods.clear_sight(totem, get_instance_id())
	else:
		ExhibitMods.cap_sight(totem, get_instance_id(), BLIND_RANGE)


## The device goes (a night's end): the totems see as they did.
func _exit_tree() -> void:
	for exhibit in PerceptionWorld.exhibits():
		if is_instance_valid(exhibit) and exhibit is Totem:
			ExhibitMods.clear_sight(exhibit, get_instance_id())
