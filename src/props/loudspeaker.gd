class_name Loudspeaker
extends Node3D
## A wall loudspeaker of the museum's System. VoiceDirector plays the System's
## lines through the nearest few, each a little later by its extra distance
## (play_voice(stream, delay)). Its back sits on the wall at the marker
## (loudspeaker_* in the zone files); the grille faces the marker's -Z.

const MODEL := &"loudspeaker"

var player: AudioStreamPlayer3D
var _delay := -1.0


static func create(at: Transform3D) -> Loudspeaker:
	var speaker := Loudspeaker.new()
	speaker.transform = at
	return speaker


func _ready() -> void:
	add_to_group(&"loudspeakers")
	var model := ArtLibrary.try_instance(MODEL)
	if model == null:
		var box := MeshInstance3D.new()
		box.mesh = BoxMesh.new()
		box.mesh.size = Vector3(0.34, 0.24, 0.14)
		box.position = Vector3(0.0, 0.0, -0.07)
		model = box
	add_child(model)
	player = AudioStreamPlayer3D.new()
	player.bus = &"VoiceSystem"
	player.unit_size = 10.0
	player.max_distance = 60.0
	player.area_mask = Layers.REVERB_ZONE
	player.position = Vector3(0.0, 0.0, -0.15)
	add_child(player)


## Plays [param stream] after [param delay] s (0 = now).
func play_voice(stream: AudioStream, delay := 0.0) -> void:
	player.stream = stream
	_delay = delay
	if delay <= 0.0:
		_delay = -1.0
		player.play()


func stop_voice() -> void:
	_delay = -1.0
	player.stop()


func is_speaking() -> bool:
	return player.playing


func _process(delta: float) -> void:
	if _delay >= 0.0:
		advance(delta / maxf(Engine.time_scale, 0.01))   # real time, like the director


## The delay's clock (tests call it directly).
func advance(dt: float) -> void:
	if _delay < 0.0:
		return
	_delay -= dt
	if _delay < 0.0:
		player.play()
