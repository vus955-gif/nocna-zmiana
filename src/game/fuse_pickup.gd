class_name FusePickup
extends Interactable
## One of the night's two fuses: an old ceramic cartridge fuse with brass
## caps lying on a crate, with a warm glint that shows in the dark. E takes
## it ([signal taken]) and it is gone.

signal taken(by: Node, wing: StringName)

const LENGTH := 0.22
const GLOW := Color(1.0, 0.7, 0.35)

## Which wing's fuse (&"A" gallery, &"B" armory).
var wing: StringName = &""

var _model: Node3D
var _light: OmniLight3D
var _time: float = 0.0


func _init() -> void:
	super()
	prompt_key = "PROMPT_TAKE_FUSE"


func _ready() -> void:
	LevelKit.tag(self, &"fuse", Vector3(LENGTH, 0.07, 0.07))
	add_box(Vector3(0.6, 0.45, 0.6), Vector3(0.0, 0.2, 0.0))
	_model = Node3D.new()
	_model.position = Vector3(0.0, 0.05, 0.0)
	_model.rotation.y = 0.4
	add_child(_model)
	build_fuse(_model)
	_light = PropKit.glow_light(self, GLOW, 0.9, 3.2, Vector3(0.0, 0.35, 0.0))
	_time = randf() * TAU


## The fuse itself, lying along X, centred at [param parent]'s origin.
static func build_fuse(parent: Node3D, glow: float = 0.9) -> void:
	var body := PropKit.cylinder(parent, 0.032, LENGTH * 0.7, Vector3.ZERO, Color(0.9, 0.86, 0.76), 0.15)
	body.rotation.z = PI * 0.5
	for side in [-1.0, 1.0]:
		var cap := PropKit.cylinder(parent, 0.036, 0.04, Vector3(side * LENGTH * 0.4, 0.0, 0.0), LevelKit.BRASS, glow)
		cap.rotation.z = PI * 0.5
		var blade := PropKit.box(parent, Vector3(0.03, 0.012, 0.03), Vector3(side * LENGTH * 0.5, 0.0, 0.0), LevelKit.BRASS, glow)
		blade.rotation.x = 0.0
	PropKit.box(parent, Vector3(LENGTH * 0.3, 0.004, 0.045), Vector3(0.0, 0.032, 0.0), Color(0.75, 0.2, 0.12))


func _process(delta: float) -> void:
	_time += delta
	_light.light_energy = 0.75 + 0.25 * sin(_time * 2.2)


func interact(by: Node) -> void:
	var guard := by as Player
	if guard == null or not guard.alive:
		return
	Sfx.play(&"fuse_take")
	taken.emit(by, wing)
	super(by)
	queue_free()
