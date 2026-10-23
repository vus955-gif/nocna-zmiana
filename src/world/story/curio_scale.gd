class_name CurioScale
extends Curio
## The scales of Osiris's judgement in the sarcophagus hall (Curios:
## scale): a bronze balance on a sandstone base, the feather of Maat on its
## right pan, the left one - for the heart of the dead - empty. E (a hand
## on the empty pan): the pan sinks as if the heart that cannot be weighed
## lay on it, and a slab in the base slides aside: a pouch of Dust and a
## medkit. Once in the game; on later nights it stays tipped and open.

const BASE := Vector3(0.5, 0.8, 0.4)
const POST := 0.55
const ARM := 0.32
## The beam's tilt once the empty pan has sunk (radians, its left end down).
const TILT := 0.32
const SINK_TIME := 1.4
const SLAB := Vector3(0.26, 0.2, 0.03)
const SLAB_Y := 0.42
const SLAB_DROP := 0.24

var sinking := false

var _beam: Node3D = null
var _pans: Array[Node3D] = []
var _slab: Node3D = null


func _build() -> void:
	var sandstone := StoryProps.material(Color(0.72, 0.6, 0.42), 0.95)
	var bronze := StoryProps.material(Color(0.48, 0.34, 0.16), 0.45, 0.8)
	var painted := StoryProps.material(Color(0.18, 0.32, 0.5), 0.8)
	StoryProps._box(self, BASE, Vector3(0.0, BASE.y * 0.5, 0.0), sandstone)
	StoryProps._box(self, Vector3(BASE.x + 0.06, 0.05, BASE.z + 0.06), Vector3(0.0, BASE.y, 0.0), sandstone)
	# a painted band round the base's top (the faience blue of the tombs)
	StoryProps._box(self, Vector3(BASE.x + 0.004, 0.05, BASE.z + 0.004), Vector3(0.0, BASE.y - 0.08, 0.0), painted)
	# the compartment's slab in the front face (-Z)
	_slab = Node3D.new()
	_slab.name = "Slab"
	_slab.position = Vector3(0.0, SLAB_Y, -BASE.z * 0.5 - SLAB.z * 0.5)
	add_child(_slab)
	StoryProps._box(_slab, SLAB, Vector3.ZERO, StoryProps.material(Color(0.66, 0.54, 0.37), 0.95))
	StoryProps._box(self, Vector3(SLAB.x - 0.02, SLAB.y - 0.02, 0.02), Vector3(0.0, SLAB_Y, -BASE.z * 0.5 + 0.005), StoryProps.material(Color(0.05, 0.04, 0.03), 1.0))
	# the post, the beam on its pivot, a pan hanging at each end
	var top := BASE.y + 0.025
	StoryProps._cylinder(self, 0.02, POST, Vector3(0.0, top + POST * 0.5, 0.0), bronze)
	_beam = Node3D.new()
	_beam.name = "Beam"
	_beam.position = Vector3(0.0, top + POST, 0.0)
	add_child(_beam)
	StoryProps._box(_beam, Vector3(ARM * 2.0 + 0.04, 0.02, 0.025), Vector3.ZERO, bronze)
	for side: float in [-1.0, 1.0]:
		var pan := Node3D.new()
		pan.name = "Pan_%s" % ("left" if side < 0.0 else "right")
		pan.position = Vector3(side * ARM, 0.0, 0.0)
		_beam.add_child(pan)
		for k in 3:
			var a := TAU * k / 3.0
			StoryProps._cylinder(pan, 0.002, 0.2, Vector3(cos(a) * 0.05, -0.1, sin(a) * 0.05), bronze, Vector3(sin(a) * 0.24, 0.0, -cos(a) * 0.24))
		StoryProps._cylinder(pan, 0.1, 0.018, Vector3(0.0, -0.2, 0.0), bronze, Vector3.ZERO, 0.115)
		_pans.append(pan)
	# the feather of Maat on the right pan
	var feather := StoryProps.material(Color(0.94, 0.93, 0.88), 1.0)
	StoryProps._box(_pans[1], Vector3(0.025, 0.012, 0.16), Vector3(0.0, -0.18, 0.0), feather, Vector3(0.0, 0.5, 0.25))
	_solid(Vector3(BASE.x + 0.06, top + POST, BASE.z + 0.06))
	add_box(Vector3(0.9, 0.7, 0.8), Vector3(0.0, top + POST - 0.15, -0.1))


func _show_done() -> void:
	_tip(1.0)
	_slab.position.y = SLAB_Y - SLAB_DROP
	_slab.position.z = -BASE.z * 0.5 - SLAB.z * 1.5
	retire()


func interact(by: Node) -> void:
	if not enabled or sinking or is_done():
		return
	super(by)
	sinking = true
	retire()
	spoke.emit(id, Curios.text_key(id))
	Sfx.play_at(&"relief_scrape", global_position + Vector3.UP, -3.0)
	var tween := create_tween()
	tween.tween_method(_tip, 0.0, 1.0, SINK_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_callback(_opened)


## The beam [param t] of the way down on its left (the empty pan); the pans
## hang plumb.
func _tip(t: float) -> void:
	_beam.rotation.z = TILT * t
	for pan in _pans:
		pan.rotation.z = -TILT * t


func _opened() -> void:
	sinking = false
	WorldSounds.cue_at(&"drawer", global_transform * Vector3(0.0, SLAB_Y, -0.3))
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_slab, ^"position:z", -BASE.z * 0.5 - SLAB.z * 1.5, 0.2)
	tween.tween_property(_slab, ^"position:y", SLAB_Y - SLAB_DROP, 0.45).set_delay(0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	solve()
	spoke.emit(id, Curios.answer_key(id))


## The medkit lies before the open compartment.
func _loot_spot(index: int) -> Vector3:
	return Vector3(0.35 * index, SLAB_Y + 0.15, -BASE.z * 0.5 - 0.45)
