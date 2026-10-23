class_name CurioBird
extends Curio
## The singing bird automaton in the Hall of Clocks (Curios: bird): a
## gilded cage on a stand (the art's lib_bird_cage, its bird a part of its
## own). E winds the key on the stand's side; the bird turns, bobs and sings
## six short notes and a long trill - the long one toward [member target]
## (the Great Orrery) - and the card says what the curator made of it.
## The first song is recorded (it can be wound again and again).

const MODEL := &"lib_bird_cage"
## The stand's height (the model's: 1.66 m) and where its key sits.
const HEIGHT := 1.66
const KEY_AT := Vector3(0.23, 0.92, 0.0)
const WIND := 1.0
## The song (assets/sfx/automaton_song.wav): six notes from 0.15 s, 0.3 s
## apart, 0.13 s each; the trill from 2.15 s for 1.5 s.
const NOTE_AT := 0.15
const NOTE_GAP := 0.3
const NOTE_LENGTH := 0.13
const TRILL_AT := 2.15
const SONG := 3.75

## Where the long trill is sung to (world).
var target := Vector3.INF
var singing := false
## Seconds since the key was first turned (while singing).
var time := 0.0

var _model: Node3D = null
var _bird: Node3D = null
var _head: Node3D = null
var _key: Node3D = null
var _bird_yaw := 0.0
var _sang := false


func _build() -> void:
	_model = ArtLibrary.try_instance(MODEL)
	if _model == null:
		_model = _greybox()
	_model.name = "Model"
	add_child(_model)
	var parts := ArtLibrary.parts(_model)
	_bird = parts.get("bird") as Node3D
	_head = parts.get("bird_head") as Node3D
	if _bird != null:
		_bird_yaw = _bird.rotation.y
	_key = _winding_key()
	add_child(_key)
	_solid(Vector3(0.42, HEIGHT, 0.42))
	add_box(Vector3(0.8, 0.9, 0.8), Vector3(0.0, 1.15, 0.0))


func _show_done() -> void:
	pass   # it sings again whenever it is wound


func interact(by: Node) -> void:
	if not enabled or singing:
		return
	super(by)
	singing = true
	time = 0.0
	_sang = false
	spoke.emit(id, Curios.text_key(id))


func _process(delta: float) -> void:
	if singing:
		advance(delta)


## Moves the song on by [param delta] s (the key, the bird, the sounds).
func advance(delta: float) -> void:
	if not singing:
		return
	var before := time
	time += delta
	if time < WIND:
		# three quarter-turns of the key, a click at each
		_key.rotation.x = time / WIND * PI * 1.5
		for k in 3:
			var at := WIND * k / 3.0
			if before <= at and time > at:
				Sfx.play_at(&"dial_click", global_position + Vector3.UP, -4.0)
		return
	var song := time - WIND
	if before < WIND:
		Sfx.play_at(&"automaton_song", global_position + Vector3.UP * HEIGHT, -2.0)
	_animate(song)
	if song >= SONG:
		_finish()


func _animate(song: float) -> void:
	if _bird == null:
		return
	var bob := 0.0
	for k in 6:
		var start := NOTE_AT + NOTE_GAP * k
		if song >= start and song < start + NOTE_LENGTH:
			bob = sin((song - start) / NOTE_LENGTH * PI)
	var turn := _bird_yaw + sin(song * 3.0) * 0.5
	if song >= TRILL_AT:
		turn = lerp_angle(turn, _trill_yaw(), clampf((song - TRILL_AT) / 0.3, 0.0, 1.0))
		bob = 0.4 + 0.3 * sin(song * 110.0)
	_bird.rotation.y = turn
	if _head != null:
		_head.rotation.x = -bob * 0.5


## The bird's yaw (in the cage's frame) that faces [member target].
func _trill_yaw() -> float:
	if target == Vector3.INF or not is_inside_tree():
		return _bird_yaw
	var local := global_transform.affine_inverse() * target
	return atan2(-local.x, -local.z)


func _finish() -> void:
	singing = false
	time = 0.0
	if _bird != null:
		_bird.rotation.y = _trill_yaw()
	if _key != null:
		_key.rotation.x = 0.0
	solve()
	spoke.emit(id, Curios.answer_key(id))


## The winding key: a brass shaft out of the stand's side and a butterfly bow.
func _winding_key() -> Node3D:
	var key := Node3D.new()
	key.name = "Key"
	key.position = KEY_AT
	var brass := StoryProps.material(Color(0.78, 0.6, 0.28), 0.35, 0.85)
	StoryProps._cylinder(key, 0.008, 0.06, Vector3(0.03, 0.0, 0.0), brass, Vector3(0.0, 0.0, PI * 0.5))
	StoryProps._box(key, Vector3(0.012, 0.07, 0.035), Vector3(0.065, 0.0, 0.0), brass)
	return key


## Without the model: a turned stand, a dome of wire, a little yellow bird.
func _greybox() -> Node3D:
	var root := Node3D.new()
	var wood := StoryProps.material(Color(0.36, 0.24, 0.14), 0.6)
	var gilt := StoryProps.material(Color(0.8, 0.62, 0.28), 0.35, 0.8)
	StoryProps._cylinder(root, 0.04, 1.0, Vector3(0.0, 0.5, 0.0), wood)
	StoryProps._cylinder(root, 0.2, 0.1, Vector3(0.0, 1.05, 0.0), wood)
	StoryProps._cylinder(root, 0.18, 0.5, Vector3(0.0, 1.35, 0.0), gilt, Vector3.ZERO, 0.05)
	var bird := Node3D.new()
	bird.name = "bird"
	bird.position = Vector3(0.0, 1.22, 0.0)
	root.add_child(bird)
	StoryProps._box(bird, Vector3(0.05, 0.05, 0.1), Vector3.ZERO, StoryProps.material(Color(0.9, 0.75, 0.2)))
	var head := Node3D.new()
	head.name = "bird_head"
	head.position = Vector3(0.0, 0.04, -0.05)
	bird.add_child(head)
	StoryProps._box(head, Vector3(0.04, 0.04, 0.04), Vector3.ZERO, StoryProps.material(Color(0.9, 0.75, 0.2)))
	return root
