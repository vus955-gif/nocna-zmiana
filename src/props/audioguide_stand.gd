class_name AudioguideStand
extends Interactable
## An audio-guide stand at an exhibit: press E to hear the System's recording
## (day version; the night one once its condition holds — VoiceDirector).
## The marker audioguide_<station> in the zone files places it; its pulpit
## faces the marker's -Z.

const MODEL := &"audioguide_stand"

var station: StringName
var player: AudioStreamPlayer3D


static func create(station_id: StringName, at: Transform3D) -> AudioguideStand:
	var stand := AudioguideStand.new()
	stand.station = station_id
	stand.transform = at
	stand.prompt_key = "PROMPT_AUDIOGUIDE"
	return stand


func _ready() -> void:
	add_box(Vector3(0.5, 1.1, 0.4), Vector3(0.0, 0.55, 0.0))
	# solid to walk into (a little inside the interact box, so the probe meets that first)
	var body := StaticBody3D.new()
	body.collision_layer = Layers.WORLD
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.46, 1.08, 0.36)
	shape.shape = box
	shape.position = Vector3(0.0, 0.54, 0.0)
	body.add_child(shape)
	add_child(body)
	var model := ArtLibrary.try_instance(MODEL)
	if model == null:
		var post := MeshInstance3D.new()
		post.mesh = BoxMesh.new()
		post.mesh.size = Vector3(0.3, 1.05, 0.3)
		post.position = Vector3(0.0, 0.525, 0.0)
		model = post
	add_child(model)
	player = AudioStreamPlayer3D.new()
	player.bus = &"VoiceSystem"
	player.unit_size = 4.0
	player.max_distance = VoiceDirector.GUIDE_RANGE + 4.0
	player.area_mask = Layers.REVERB_ZONE
	player.position = Vector3(0.0, 1.0, 0.0)
	add_child(player)


func interact(by: Node) -> void:
	if not enabled:
		return
	super(by)
	VoiceDirector.play_guide(station, self)


func play_voice(stream: AudioStream, _delay := 0.0) -> void:
	player.stream = stream
	player.play()


func stop_voice() -> void:
	player.stop()


func is_speaking() -> bool:
	return player.playing
