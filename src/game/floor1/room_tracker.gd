class_name RoomTracker
extends Node
## Which room of Floor I the guard is in (design 9.1-9.2): every INTERVAL s
## the level's room at his chest; a new room is recorded as visited
## (GameState.visit_room: the paper map ticks it) and announced
## (Events.room_entered with its zone and whether it is the first visit
## ever: music, ambience, the room card). check() at night start announces
## the room the night starts in at once (the music and ambience pick their
## zone in the same frame the scene is set up).

## The guard walked into [param room] ([param first_visit]: the first
## time ever).
signal entered(room: StringName, zone: StringName, first_visit: bool)

const INTERVAL := 0.25
## The point checked is this high over the guard's feet.
const CHEST := 0.5

var level: MuseumFloorLevel
var game: PersistentState
## Returns the guard (or null).
var guard_source: Callable
## The room he is in now (&"" before the first check or outside rooms).
var room: StringName = &""

var _left: float = 0.0


func _process(delta: float) -> void:
	_left -= delta
	if _left <= 0.0:
		_left = INTERVAL
		check()


## Looks where the guard is now; a new room is recorded and announced.
func check() -> void:
	var guard := guard_source.call() as Node3D if guard_source.is_valid() else null
	if guard == null or not is_instance_valid(guard) or level == null:
		return
	var here := level.room_at(guard.global_position + Vector3.UP * CHEST)
	if here == &"" or here == room:
		return
	room = here
	var spec := level.layout.room(here)
	var zone := spec.zone if spec != null else &""
	var first := game.visit_room(here)
	Events.room_entered.emit(here, zone, first)
	entered.emit(here, zone, first)
