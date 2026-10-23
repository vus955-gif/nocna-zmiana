class_name AudioguideStand
extends Interactable
## An audio-guide stand at an exhibit: press E to hear the System's recording
## (day version; the night one once its condition holds — VoiceDirector).
## The marker audioguide_<station> in the zone files places it; its pulpit
## faces the marker's -Z. The stop's number (STOPS, the order of the tour;
## the recordings say "Stop one...") is drawn on the blank enamel plate of
## the model (tools/art/models/audioguide_stand.py).

const MODEL := &"audioguide_stand"
## Every stand of the level (it may live under the level's navigation
## sources, not under WorldFeatures: the navmesh goes round it).
const GROUP := &"audioguide_stands"
## Station -> stop number (plan 2026-10-19-glos-g2-kwestie, 2.6).
const STOPS := {
	&"rosetta": 1, &"ramesses": 2, &"lamassu": 3, &"flood": 4, &"metopes": 5, &"clocks": 6,
	&"buddha": 7, &"armour": 8, &"totems": 9, &"moai": 10, &"astrolabe": 11, &"trex": 12,
}
## The plate on the post: its centre's height and its front face (the model's SIGN_Z, 0.045 + 0.006).
const PLATE_Y := 0.80
const PLATE_FRONT := 0.051

var station: StringName
var player: AudioStreamPlayer3D


static func create(station_id: StringName, at: Transform3D) -> AudioguideStand:
	var stand := AudioguideStand.new()
	stand.station = station_id
	stand.transform = at
	stand.prompt_key = "PROMPT_AUDIOGUIDE"
	stand.add_to_group(GROUP)
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
	if STOPS.has(station):
		add_child(_stop_number(int(STOPS[station])))
	player = AudioStreamPlayer3D.new()
	player.bus = &"VoiceSystem"
	player.unit_size = 4.0
	player.max_distance = VoiceDirector.GUIDE_RANGE + 4.0
	player.area_mask = Layers.REVERB_ZONE
	player.position = Vector3(0.0, 1.0, 0.0)
	add_child(player)


## Black digits on the white plate, readable from the front (-Z).
static func _stop_number(stop: int) -> Label3D:
	var digits := Label3D.new()
	digits.name = "StopNumber"
	digits.text = str(stop)
	digits.font = UiTheme.strong_font()
	digits.font_size = 64
	digits.pixel_size = 0.0011
	digits.outline_size = 0
	digits.modulate = Color(0.06, 0.06, 0.07)
	digits.shaded = true
	digits.double_sided = false
	digits.alpha_cut = Label3D.ALPHA_CUT_DISCARD
	digits.position = Vector3(0.0, PLATE_Y, -PLATE_FRONT - 0.002)
	digits.rotation.y = PI
	return digits


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
