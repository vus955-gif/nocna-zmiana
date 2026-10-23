class_name Curio
extends Interactable
## An exhibit that answers the guard (Curios): the base of the singing
## bird, the travelling astrolabe, the founder's portrait and the scales of
## judgement. It knows whether it was done this game (GameState flag
## "curio_<id>", saved) and, when it has a drawer, lays its Dust and loot:
## the Dust once (straight into the guard's pouch), the loot as pickups in
## the open drawer every night until each is taken (then never again).
## A subclass builds its look (_build), shows itself done (_show_done) and
## says where its loot lies (_loot_spot); it calls solve() when it gives in.
## MuseumStory shows what it says ([signal spoke]) and announces it.

## Show [param text_key] on the card (what it is, or what it did).
signal spoke(id: StringName, text_key: String)
## Done for the first time this game (saved).
signal solved(id: StringName)

var id: StringName = &""
var game: PersistentState = null
var run: NightState = null
## item -> the loot this guard gets for it (Museum.loot_for_guard); unset:
## the item itself.
var loot_source: Callable = Callable()
## The drawer's pickups lying now.
var pickups: Array[Pickup] = []

var _laid := false


func _ready() -> void:
	if game == null:
		game = GameState
	if run == null:
		run = RunState
	prompt_key = Curios.prompt_key(id)
	_build()
	if is_done():
		_show_done()
		_lay_loot()


func is_done() -> bool:
	return game != null and game.has_flag(Curios.flag(id))


## Records it (once per game), gives its Dust, lays its loot, saves. False
## when it was done before.
func solve() -> bool:
	if not game.set_flag(Curios.flag(id)):
		return false
	var amount := Curios.dust(id)
	if amount > 0:
		run.add_dust(amount, false)
		Events.dust_collected.emit(amount)
	_lay_loot()
	NightRules.save_progress(game, run)
	solved.emit(id)
	return true


## Takes the use-zone away (nothing more to do here).
func retire() -> void:
	enabled = false
	collision_layer = 0


# --- for the curios ----------------------------------------------------------------

## Builds the look (the use box too).
func _build() -> void:
	pass


## Shows it as left done on an earlier night.
func _show_done() -> void:
	retire()


## Where the [param index]th thing of the drawer lies (local).
func _loot_spot(index: int) -> Vector3:
	return Vector3(0.3 * index, 0.5, -0.6)


## A solid box [param size] standing on the origin (what the guard walks into).
func _solid(size: Vector3, offset: Vector3 = Vector3.ZERO) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "Body"
	body.collision_layer = Layers.WORLD
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = Vector3(0.0, size.y * 0.5, 0.0) + offset
	body.add_child(shape)
	add_child(body)
	return body


func _lay_loot() -> void:
	if _laid:
		return
	_laid = true
	var items := Curios.loot(id)
	for i in items.size():
		if game.has_flag(Curios.taken_flag(id, i)):
			continue
		var item: StringName = loot_source.call(items[i]) if loot_source.is_valid() else items[i]
		if not Museum.LOOT_TYPES.has(item):
			continue
		var pickup := Pickup.new()
		pickup.name = "Loot_%d" % i
		pickup.type = Museum.LOOT_TYPES[item]
		pickup.amount = Museum.LOOT_AMOUNTS[item]
		pickup.respawn_time = 0.0
		pickup.position = _loot_spot(i)
		pickup.taken.connect(_on_loot_taken.bind(i))
		add_child(pickup)
		pickups.append(pickup)


func _on_loot_taken(index: int) -> void:
	if game.set_flag(Curios.taken_flag(id, index)):
		NightRules.save_progress(game, run)
