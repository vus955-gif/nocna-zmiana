class_name FloorPickups
extends Node3D
## The weapons and key items of Floor I on their markers (design 7.1, 4.3;
## "a basic weapon is never a secret"):
## - the gun locker key in the till drawer of the entrance hall
##   (ticket_drawer) and the gun locker with the pistol in the security
##   booth (pistol_locker),
## - the flare gun behind the glass of the entrance hall's fire cabinet
##   (flare_cabinet),
## - the shotgun on the main path in Egypt, the expedition camp
##   (weapon_shotgun), and the new weapons at their markers
##   (weapon_rifle_hunt, weapon_harpoon, weapon_hwacha) - any weapon the
##   build knows (Loadout), a weapon it does not know yet is left out (a
##   warning once),
## - the gatling in its chained case in the Reading Room (gatling_case): the
##   chain is the gate chain_gatling (the GateController records it),
## - the two fuses (fuse_basement, fuse_assyria): key items for good.
## Once the guard owns a weapon or an item it is never there again.
## [signal taken] tells which marker's pickup went (an ambush may wake).

signal taken(marker: StringName)

## Weapons lying loose, by marker (the pistol, the flare gun and the
## gatling have their own furniture).
const LOOSE_WEAPONS := {&"shotgun": &"weapon_shotgun", &"rifle_hunt": &"weapon_rifle_hunt",
		&"harpoon": &"weapon_harpoon", &"hwacha": &"weapon_hwacha"}
const FUSES: Array[StringName] = [&"fuse_basement", &"fuse_assyria"]

var museum: Museum
var floor_game: FloorGame
var game: PersistentState
var run: NightState
var drawer: TicketDrawer = null
var locker: PistolLocker = null
var pistol: WeaponPickup = null
var cabinet: EmergencyCabinet = null
var display: ChainedDisplay = null
## Weapon id -> WeaponPickup lying tonight.
var weapons: Dictionary = {}
## Item id -> ProgressPickup lying tonight.
var items: Dictionary = {}


func setup(for_game: FloorGame) -> void:
	floor_game = for_game
	museum = floor_game.museum
	game = museum.game
	run = museum.run
	name = "Pickups"
	_build_key_and_locker()
	_build_cabinet()
	_build_gatling()
	for id: StringName in LOOSE_WEAPONS:
		_build_weapon(id, LOOSE_WEAPONS[id])
	for id in FUSES:
		_build_item(id)


## True when the build knows weapon [param id] (its data is in Loadout).
static func knows_weapon(id: StringName) -> bool:
	return Loadout.WEAPON_PATHS.has(id)


func _build_key_and_locker() -> void:
	var drawer_at: Variant = floor_game.marker(&"ticket_drawer")
	if drawer_at != null:
		drawer = TicketDrawer.make(drawer_at, not game.pistol_key)
		add_child(drawer)
		drawer.key_taken.connect(_on_key_found)
		drawer.found_empty.connect(func() -> void: museum.hud.show_hint(tr("DRAWER_EMPTY"), 4.0))
	var locker_at: Variant = floor_game.marker(&"pistol_locker")
	if locker_at != null:
		locker = PistolLocker.make(locker_at)
		add_child(locker)
		locker.set_unlocked(game.pistol_key)
		locker.opened_with_key.connect(_place_pistol)
		locker.refused.connect(func() -> void: museum.hud.show_hint(tr("LOCKER_LOCKED_DETAIL"), 4.0))


func _on_key_found() -> void:
	game.pistol_key = true
	WorldSounds.cue(&"keys")
	museum.hud.show_card(tr("KEY_FOUND"), tr("KEY_LOCKER"), tr("KEY_LOCKER_DETAIL"))
	if locker != null:
		locker.set_unlocked(true)
	NightRules.save_progress(game, run)
	taken.emit(&"ticket_drawer")


## The pistol waits in the open locker until taken (once his, never again).
func _place_pistol() -> void:
	if game.has_weapon(&"pistol") or is_instance_valid(pistol) or locker == null:
		return
	var spot := locker.pistol_spot()
	var on_felt := locker.holds_pistol_view()
	pistol = WeaponPickup.make(&"pistol", spot - Vector3.UP * 0.45 if on_felt else spot)
	pistol.game = game
	pistol.run = run
	add_child(pistol)
	pistol.interacted.connect(func(_by: Node) -> void: taken.emit(&"pistol_locker"))
	if on_felt:
		for child in pistol.get_children():
			if child is Node3D and not child is CollisionShape3D:
				(child as Node3D).visible = false
		locker.show_pistol(true)
		pistol.tree_exiting.connect(func() -> void:
			if is_instance_valid(locker):
				locker.show_pistol(false))


func _build_cabinet() -> void:
	var at: Variant = floor_game.marker(&"flare_cabinet")
	if at == null:
		return
	cabinet = EmergencyCabinet.create(at)
	add_child(cabinet)
	cabinet.taken.connect(func(_by: Node) -> void: taken.emit(&"flare_cabinet"))


## The gatling's chained case: its chain is the gate chain_gatling.
func _build_gatling() -> void:
	var at: Variant = floor_game.marker(&"gatling_case")
	if at == null:
		return
	var frame: Transform3D = at
	var room := museum.floor_level.layout.room(museum.floor_level.layout.marker_rooms.get(&"gatling_case", &""))
	if room != null:
		frame.origin.y = room.floor_y   # the display stands on the floor
	if game.is_gate_open(&"chain_gatling"):
		run.mark_used(ChainedDisplay.USED_ID)   # broken on an earlier night
	display = ChainedDisplay.create(frame)
	# its plinth is an obstacle the exhibits walk around: a navigation source
	museum.floor_level.add_walk_source(display)
	if not game.is_gate_open(&"chain_gatling"):
		floor_game.gates.adopt(&"chain_gatling", display, &"chain_broken")
	display.taken.connect(func(_by: Node) -> void: taken.emit(&"gatling_case"))


func _build_weapon(id: StringName, marker_id: StringName) -> void:
	if game.has_weapon(id):
		return
	if not knows_weapon(id):
		FloorGame.warn_once("FloorPickups: weapon %s is not in this build (Loadout); its marker %s stays empty" % [id, marker_id])
		return
	var at: Variant = floor_game.marker(marker_id)
	if at == null:
		return
	var pickup := WeaponPickup.make(id, (at as Transform3D).origin)
	pickup.game = game
	pickup.run = run
	add_child(pickup)
	weapons[id] = pickup
	pickup.interacted.connect(func(_by: Node) -> void:
		weapons.erase(id)
		taken.emit(marker_id))


func _build_item(id: StringName) -> void:
	if game.has_item(id):
		return
	var at: Variant = floor_game.marker(id)
	if at == null:
		return
	var pickup := ProgressPickup.make(ProgressPickup.Kind.ITEM, id, (at as Transform3D).origin - Vector3.UP * ProgressPickup.HOVER * 0.5)
	pickup.game = game
	pickup.run = run
	add_child(pickup)
	items[id] = pickup
	pickup.taken.connect(func(_kind: ProgressPickup.Kind, item: StringName) -> void:
		items.erase(item)
		museum.hud.show_toast(tr("HUD_FUSE_FOUND") % [floor_game.switchboard.fuses_held() if floor_game.switchboard != null else 0, Switchboard.FUSES.size()])
		taken.emit(item))
