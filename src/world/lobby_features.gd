class_name LobbyFeatures
extends Node3D
## The lobby's world content, installed by the Museum on a built LobbyLevel
## with one call: [code]LobbyFeatures.install(level, museum)[/code].
## It reads the level's markers, doors and loot spots and tonight's
## NightConfig, and adds the secrets (false panels, the crooked plaque, the
## padlocked case, the notes, the broom closet), the night-shift notes and
## their reader, the till key and the gun locker, tonight's artifacts and
## the CCTV. It writes only GameState (secrets, notes, havens, the key) and
## RunState (artifacts). A secret found once stays open on every later
## night; artifacts and their containers are drawn anew each night.

signal secret_discovered(id: StringName, found: int, total: int)
## A haven became known (the broom closet): the next nights may start there.
signal haven_discovered(id: StringName)
## A note was read for the first time.
signal note_read(id: StringName)
## The gun locker key came out of the till drawer.
signal key_found
## The guard took one of the night's artifacts.
signal artifact_taken(id: StringName)
## The camera view closed because the window lost its focus: the host
## should pause the game (its pause menu would not open over the view).
signal pause_requested

## Depth of a panel switch zone in front of the panel face (m).
const SWITCH_DEPTH := 0.3
## RunState.used ids of a night left and resumed ("Continue"): an artifact
## the guard holds ("artifact_<id>") and the locked door his janitor's key
## opened ("unlocked_<door>"); both stay his until the night ends.
const HELD_PREFIX := "artifact_"
const UNLOCKED_PREFIX := "unlocked_"
## Where Heniek's sticky note lies on the security desk (desk frame).
const KEY_NOTE_SPOT := Vector3(-0.55, 0.0, -0.3)

## False: leave the till drawer, the gun locker (and its pistol) and
## Heniek's sticky note out, for a host that brings its own.
static var include_locker: bool = true

## The level, the scene that hosts it (the Museum) and tonight's draw.
var level: LobbyLevel
var museum: Node
var night: NightConfig
## Persistent and night state (the GameState / RunState autoloads).
var game: PersistentState
var run: NightState
var hud: WorldHud
## Secret id -> its switches still waiting in the world.
var switches: Dictionary = {}
var plaque: CrookedPlaque = null
var reader: NoteReader
## Note id -> NotePaper in the world.
var notes: Dictionary = {}
var drawer: TicketDrawer = null
var locker: PistolLocker = null
var pistol: WeaponPickup = null
var effects: ArtifactEffects
## Loot spot index -> ArtifactPickup still waiting in the world.
var artifacts: Dictionary = {}
var padlock: PadlockedCase = null
## The use-zones on both faces of tonight's locked door.
var latches: Array[LockedDoorLatch] = []
var cctv: Cctv

var _sync_left: float = 0.0


## Builds the world content for [param lobby] (already built) under
## [param host] and returns it. The guard is looked up when needed
## ([code]host.player[/code], else the "player" group), so the call may come
## before or after the guard is spawned.
static func install(lobby: LobbyLevel, host: Node) -> LobbyFeatures:
	var features := LobbyFeatures.new()
	features.name = "LobbyFeatures"
	features.level = lobby
	features.museum = host
	host.add_child(features)
	return features


## The installed world content of the running scene, or null.
static func of(tree: SceneTree) -> LobbyFeatures:
	return tree.get_first_node_in_group(&"lobby_features") as LobbyFeatures


func _ready() -> void:
	top_level = true
	add_to_group(&"lobby_features")
	if game == null:
		game = GameState
	if run == null:
		run = RunState
	if night == null:
		night = level.night if level.night != null else NightDirector.plan(game.night_seed(), game.night, level.describe())
	WorldSounds.warm()
	hud = WorldHud.new()
	hud.name = "WorldHud"
	var host_hud: Variant = museum.get(&"hud") if is_instance_valid(museum) else null
	if host_hud is Hud:
		hud.corner_source = (host_hud as Hud).top_left_bottom
		hud.top_source = (host_hud as Hud).top_middle_bottom
		(host_hud as Hud).below_source = hud.banner_bottom
	add_child(hud)
	reader = NoteReader.new()
	reader.name = "NoteReader"
	reader.game = game
	reader.closed.connect(_on_note_closed)
	add_child(reader)
	_build_secrets()
	_build_notes()
	if include_locker:
		_build_key_and_locker()
	_build_artifacts()
	cctv = Cctv.new()
	cctv.name = "Cctv"
	cctv.level = level
	cctv.game = game
	cctv.run = run
	cctv.guard_source = guard
	add_child(cctv)
	cctv.pause_requested.connect(func() -> void: pause_requested.emit())


func _process(delta: float) -> void:
	# artifacts go at dawn or death (RunState.reset): the row follows
	_sync_left -= delta
	if _sync_left <= 0.0:
		_sync_left = 0.25
		hud.set_artifacts(run.artifacts)


## The guard of the running night (null while there is none).
func guard() -> Player:
	var host_player: Variant = museum.get(&"player") if is_instance_valid(museum) else null
	if is_instance_valid(host_player) and host_player is Player:
		return host_player
	return get_tree().get_first_node_in_group(&"player") as Player


## Records secret [param id]: sound, banner "Sekret odkryty (n/6)", save.
## The broom closet also becomes a known haven. False when it was known.
func discover_secret(id: StringName) -> bool:
	if not LobbySecrets.discover(game, id):
		return false
	var found := LobbySecrets.found(game)
	WorldSounds.cue(&"secret")
	hud.banner(tr("SECRET_FOUND") % [found, LobbySecrets.total()], tr(LobbySecrets.name_key(id)))
	if id == LobbySecrets.CLOSET:
		game.discover_haven(LobbySecrets.CLOSET)
		hud.banner(tr("HAVEN_FOUND"), tr("HAVEN_CLOSET"), tr("HAVEN_FOUND_DETAIL"))
		haven_discovered.emit(LobbySecrets.CLOSET)
	NightRules.save_progress(game, run)
	secret_discovered.emit(id, found, LobbySecrets.total())
	return true


## A frame on the [param room] side of [param door]'s passage: origin in
## the middle of that wall face at floor level, -Z pointing into the
## passage (towards the panel).
static func door_face(door: Door, room: StringName) -> Transform3D:
	var frame := door.global_transform
	# a door's local -Z points from room A to room B: room A is on +Z
	var side := 1.0 if room == door.room_a else -1.0
	var origin := frame * Vector3(0.0, 0.0, side * door.depth * 0.5)
	var into := (frame.basis * Vector3(0.0, 0.0, -side)).normalized()
	return Transform3D(Basis.looking_at(into, Vector3.UP), origin)


# --- secrets in the walls ------------------------------------------------

func _build_secrets() -> void:
	_panel_secret(LobbySecrets.PAINTING, [&"panel_painting"], "PROMPT_SECRET_PAINTING", false, &"wall_slide")
	_panel_secret(LobbySecrets.VENT, [&"panel_vent_in", &"panel_vent_out"], "PROMPT_SECRET_GRILLE", true, &"grille")
	_panel_secret(LobbySecrets.CLOSET, [&"panel_closet"], "PROMPT_SECRET_PANEL", false, &"wall_slide")
	_plaque_secret()


## Secret [param id] behind the false panels [param door_ids]: open at once
## when found on an earlier night, else a switch on the panel's face (both
## faces when [param both_faces]: the vent can be found from either end).
func _panel_secret(id: StringName, door_ids: Array[StringName], prompt: String, both_faces: bool, sound: StringName) -> void:
	var panels: Array[Door] = []
	for door_id in door_ids:
		var door := level.doors.get(door_id) as Door
		if door != null:
			panels.append(door)
	if panels.is_empty():
		return
	if LobbySecrets.is_found(game, id):
		for door in panels:
			door.open(true)
		return
	var made: Array[SecretSwitch] = []
	for door in panels:
		var faces: Array[StringName] = [door.room_a if door.panel_on_a else door.room_b]
		if both_faces:
			faces = [door.room_a, door.room_b]
		for room in faces:
			# from inside a hidden room the panel is pushed out, not found
			var spec := level.layout.room(room)
			var key := prompt + "_OUT" if spec != null and spec.secret and both_faces else prompt
			var switch := SecretSwitch.make(key, door_face(door, room), Vector3(door.width * 0.9, door.height * 0.85, SWITCH_DEPTH))
			switch.name = "Switch_%s_%s" % [door.id, room]
			switch.tag = id
			switch.door_id = door.id
			switch.used.connect(_on_panel_switch.bind(sound))
			add_child(switch)
			made.append(switch)
	switches[id] = made


func _on_panel_switch(switch: SecretSwitch, sound: StringName) -> void:
	var door := level.doors.get(switch.door_id) as Door
	# the panel is open now: its switches on both faces go
	var left: Array[SecretSwitch] = []
	for other: SecretSwitch in switches.get(switch.tag, []):
		if other.door_id == switch.door_id:
			other.retire()
		else:
			left.append(other)
	switches[switch.tag] = left
	if door != null:
		door.open()
		WorldSounds.cue_at(sound, door.global_position + Vector3.UP * door.height * 0.5)
	discover_secret(switch.tag)


## The crooked plaque in the armory: straightening it opens the wall.
func _plaque_secret() -> void:
	var door := level.doors.get(&"panel_plaque") as Door
	var marker: Variant = level.markers.get(&"secret_plaque")
	if door == null or marker == null:
		return
	var anchor: Transform3D = marker
	plaque = CrookedPlaque.make(_nearest_piece(&"plaque", anchor.origin, 4.0), anchor.translated(Vector3(0.0, 1.4, 0.0)))
	plaque.name = "CrookedPlaque"
	add_child(plaque)
	if LobbySecrets.is_found(game, LobbySecrets.PLAQUE):
		plaque.set_straight()
		door.open(true)
		return
	plaque.straightened.connect(func() -> void:
		door.open()
		WorldSounds.cue_at(&"wall_slide", door.global_position + Vector3.UP * door.height * 0.5)
		discover_secret(LobbySecrets.PLAQUE))


## The level piece of [param kit] nearest to [param point] within
## [param reach] metres, or null.
func _nearest_piece(kit: StringName, point: Vector3, reach: float) -> Node3D:
	var best: Node3D = null
	var best_distance := reach
	for node in get_tree().get_nodes_in_group(&"level_kit"):
		var piece := node as Node3D
		if piece == null or piece.get_meta(&"kit", &"") != kit or not level.is_ancestor_of(piece):
			continue
		var distance := piece.global_position.distance_to(point)
		if distance < best_distance:
			best_distance = distance
			best = piece
	return best


## The level piece spec of [param kit] in [param room] (the first), or null.
func _piece_spec(kit: StringName, room: StringName) -> PieceSpec:
	for spec in level.layout.pieces:
		if spec.kit == kit and spec.room == room:
			return spec
	return null


# --- notes -------------------------------------------------------------------

## Opens note [param id] (recorded and saved the first time).
func read_note(id: StringName) -> void:
	if NoteCatalog.read(game, id):
		NightRules.save_progress(game, run)
		note_read.emit(id)
	reader.open_note(id)


func _build_notes() -> void:
	# the night-shift set lies where the level marks it
	var twist: Array[float] = [0.18, -0.22, 0.12]
	for i in NoteCatalog.SET.size():
		var id := NoteCatalog.SET[i]
		var marker: Variant = level.markers.get(id)
		if marker != null:
			var at: Transform3D = marker
			_add_note(id, Transform3D(at.basis.rotated(Vector3.UP, twist[i]), at.origin + Vector3.UP * 0.002), false)
	if include_locker and not game.pistol_key:
		var desk := _piece_spec(&"desk", &"security")
		if desk != null:
			var top := desk.transform() * (KEY_NOTE_SPOT + Vector3(0.0, desk.size.y + 0.002, 0.0))
			_add_note(NoteCatalog.KEY_NOTE, Transform3D(Basis(Vector3.UP, desk.yaw - 0.1), top), false)
	# the hidden rooms: pinned to a wall or left on a crate
	var chamber := level.layout.room(&"secret_chamber")
	if chamber != null:
		var rect := chamber.parts[0]
		_add_note(&"note_chamber", Transform3D(Basis.looking_at(Vector3.RIGHT), Vector3(rect.position.x + 0.01, chamber.floor_y + 1.55, rect.position.y + rect.size.y * 0.72)), true)
	var niche := level.layout.room(&"shotgun_niche")
	if niche != null:
		var rect := niche.parts[0]
		_add_note(&"note_niche", Transform3D(Basis.looking_at(Vector3.BACK), Vector3(rect.position.x + 0.9, niche.floor_y + 1.55, rect.position.y + 0.01)), true)
	var vent := level.layout.room(&"vent")
	if vent != null:
		var rect := vent.parts[0]
		_add_note(&"note_vent", Transform3D(Basis.looking_at(Vector3.BACK), Vector3(rect.position.x + rect.size.x * 0.47, vent.floor_y + 1.55, rect.position.y + 0.01)), true)
	var crate := _piece_spec(&"crate", &"closet")
	if crate != null:
		_add_note(&"note_closet", Transform3D(Basis(Vector3.UP, crate.yaw + 0.35), crate.position + Vector3(0.0, crate.size.y + 0.002, 0.0)), false)


func _add_note(id: StringName, at: Transform3D, pinned: bool) -> void:
	var note := NotePaper.make(id, at, pinned)
	note.read_requested.connect(read_note)
	add_child(note)
	notes[id] = note


## The set is complete once its last note is put down: secret 5.
func _on_note_closed(id: StringName) -> void:
	if NoteCatalog.in_set(id) and NoteCatalog.set_complete(game):
		discover_secret(LobbySecrets.NOTES)


# --- the till key and the gun locker --------------------------------------

## The till drawer and the gun locker. Once the key is the guard's (a
## later night) the drawer is shut again with nothing but old tickets in
## it, and the locker's lamp is green but its door shut until he opens it.
func _build_key_and_locker() -> void:
	var drawer_marker: Variant = level.markers.get(&"ticket_drawer")
	if drawer_marker != null:
		drawer = TicketDrawer.make(drawer_marker, not game.pistol_key)
		add_child(drawer)
		drawer.key_taken.connect(_on_key_found)
		drawer.found_empty.connect(func() -> void: hud.banner(tr("DRAWER_TITLE"), tr("DRAWER_EMPTY")))
	var locker_marker: Variant = level.markers.get(&"pistol_locker")
	if locker_marker != null:
		locker = PistolLocker.make(_locker_frame(locker_marker))
		add_child(locker)
		locker.set_unlocked(game.pistol_key)
		locker.opened_with_key.connect(_place_pistol)
		locker.refused.connect(func() -> void: hud.banner_once(tr("LOCKER_LOCKED"), tr("LOCKER_LOCKED_DETAIL")))


func _on_key_found() -> void:
	game.pistol_key = true
	WorldSounds.cue(&"keys")
	hud.banner(tr("KEY_FOUND"), tr("KEY_LOCKER"), tr("KEY_LOCKER_DETAIL"))
	if locker != null:
		locker.set_unlocked(true)
	NightRules.save_progress(game, run)
	key_found.emit()


## The locker door over the staff lockers' door nearest to the marker (its
## face just in front of theirs), else at the marker itself.
func _locker_frame(marker: Transform3D) -> Transform3D:
	var piece := _nearest_piece(&"lockers", marker.origin, 2.0)
	if piece == null:
		return marker
	var size: Vector3 = piece.get_meta(&"kit_size", Vector3.ONE)
	var local := piece.global_transform.affine_inverse() * marker.origin
	var count := maxi(int(size.x / 0.5), 1)
	var best := 0.0
	for i in count:
		var x := -size.x * 0.5 + (i + 0.5) * size.x / count
		if i == 0 or absf(x - local.x) < absf(best - local.x):
			best = x
	return piece.global_transform * Transform3D(Basis.IDENTITY, Vector3(best, size.y * 0.5, -size.z * 0.5 - 0.035))


## The pistol waits in the open locker until the guard takes it (once his,
## it is never there again): on the art cabinet's felt (its pickup is then
## only the use-zone around it), or floating in front of the greybox door.
func _place_pistol() -> void:
	if game.has_weapon(&"pistol") or is_instance_valid(pistol) or locker == null:
		return
	var spot := locker.pistol_spot()
	var on_felt := locker.holds_pistol_view()
	pistol = WeaponPickup.make(&"pistol", spot - Vector3.UP * 0.45 if on_felt else spot)
	pistol.game = game
	pistol.run = run
	add_child(pistol)
	if on_felt:
		# the pickup's own spinning model and glint would float through the
		# cabinet: the pistol on the felt stands for it
		for child in pistol.get_children():
			if child is Node3D and not child is CollisionShape3D:
				(child as Node3D).visible = false
		locker.show_pistol(true)
		pistol.tree_exiting.connect(func() -> void:
			if is_instance_valid(locker):
				locker.show_pistol(false))


# --- artifacts ------------------------------------------------------------

func has_janitor_key() -> bool:
	return run.has_artifact(ArtifactCatalog.JANITOR_KEY)


## Tonight's artifacts in the containers NightDirector chose, the padlocked
## case and the latches of tonight's locked door.
## A resumed night gives back the artifacts taken in it (their containers
## stay empty).
func _build_artifacts() -> void:
	for spot_index: int in night.loot:
		var held := StringName(str(night.loot[spot_index]))
		if ArtifactCatalog.is_artifact(held) and run.is_used(held_id(held)) and not run.artifacts.has(held):
			run.artifacts.append(held)
	effects = ArtifactEffects.new()
	effects.name = "ArtifactEffects"
	effects.run = run
	effects.guard_source = guard
	add_child(effects)
	for spot_index: int in night.loot:
		var item: Variant = night.loot[spot_index]
		if not ArtifactCatalog.is_artifact(item) or spot_index < 0 or spot_index >= level.loot_spots.size():
			continue
		if run.artifacts.has(StringName(item)):
			continue   # taken earlier tonight
		var pickup := ArtifactPickup.make(StringName(item), level.loot_spots[spot_index].position)
		pickup.taken.connect(_on_artifact_taken)
		add_child(pickup)
		artifacts[spot_index] = pickup
	_build_padlock()
	_build_latches()
	hud.set_artifacts(run.artifacts)


## RunState.used id of artifact [param id] held tonight.
static func held_id(id: StringName) -> StringName:
	return StringName(HELD_PREFIX + String(id))


func _on_artifact_taken(id: StringName) -> void:
	if not run.artifacts.has(id):
		run.artifacts.append(id)
	run.mark_used(held_id(id))
	for spot: int in artifacts.keys():
		if not is_instance_valid(artifacts[spot]) or (artifacts[spot] as ArtifactPickup).artifact_id == id:
			artifacts.erase(spot)
	effects.refresh()
	hud.set_artifacts(run.artifacts)
	WorldSounds.cue(&"artifact")
	hud.banner(tr("ARTIFACT_CAPTION"), tr(ArtifactCatalog.name_key(id)), tr(ArtifactCatalog.effect_key(id)) + "\n" + tr(ArtifactCatalog.flavor_key(id)))
	artifact_taken.emit(id)


## Secret 4: the padlock on the case under the east balcony. What lies
## inside (always an artifact, NightDirector) waits locked behind it.
func _build_padlock() -> void:
	var marker: Variant = level.markers.get(&"secret_case")
	if marker == null:
		return
	var anchor: Transform3D = marker
	var spec := _nearest_spec(&"case", anchor.origin, 1.5)
	var frame := spec.transform() if spec != null else anchor
	var size := spec.size if spec != null else Vector3(1.4, 1.6, 1.0)
	var room := level.layout.room(spec.room if spec != null else level.room_at(anchor.origin))
	var middle := frame.origin
	if room != null:
		var center := room.parts[0].get_center()
		middle = Vector3(center.x, frame.origin.y, center.y)
	# the padlock hangs on the face turned to the room
	var out := (frame.basis * Vector3.FORWARD).normalized()
	if out.dot(middle - frame.origin) < 0.0:
		out = -out
	var lid := 0.9
	var face := Transform3D(Basis.looking_at(out, Vector3.UP), frame.origin + out * (size.z * 0.5 + 0.004) + Vector3.UP * lid)
	padlock = PadlockedCase.make(face, size.x, lid)
	padlock.has_key = has_janitor_key
	add_child(padlock)
	var inside := _artifact_near(anchor.origin)
	if LobbySecrets.is_found(game, LobbySecrets.CASE):
		padlock.set_unlocked()
		return
	if inside != null:
		inside.set_locked(true)
	padlock.rattled.connect(func() -> void: hud.banner_once(tr("CASE_PADLOCK"), tr("CASE_PADLOCK_DETAIL")))
	padlock.unlocked.connect(func(_by_key: bool) -> void:
		if is_instance_valid(inside):
			inside.set_locked(false)
		discover_secret(LobbySecrets.CASE))


## The latches of tonight's locked door (when the level locked one).
func _build_latches() -> void:
	if night.locked_door == &"":
		return
	var door := level.doors.get(night.locked_door) as Door
	if door == null or not door.locked:
		return
	if run.is_used(unlocked_id(door.id)):
		# opened with the janitor's key before the guard left tonight
		door.unlock()
		door.open(true)
		return
	for room: StringName in [door.room_a, door.room_b]:
		var latch := LockedDoorLatch.make(door, door_face(door, room))
		latch.has_key = has_janitor_key
		latch.refused.connect(func() -> void: hud.banner_once(tr("DOOR_LOCKED"), tr("DOOR_LOCKED_DETAIL")))
		latch.unlocked_with_key.connect(_on_door_unlocked)
		add_child(latch)
		latches.append(latch)


## RunState.used id of tonight's locked [param door_id] opened with the key.
static func unlocked_id(door_id: StringName) -> StringName:
	return StringName(UNLOCKED_PREFIX + String(door_id))


func _on_door_unlocked() -> void:
	for latch in latches:
		if is_instance_valid(latch.door):
			run.mark_used(unlocked_id(latch.door.id))
		latch.retire()
	latches.clear()


## Holds the latches on [param door_ids] shut whatever the key (the hall
## sealed for the boss fight), or lets them go again.
func hold_latches(door_ids: Array[StringName], held: bool) -> void:
	for latch in latches:
		if is_instance_valid(latch) and is_instance_valid(latch.door) and door_ids.has(latch.door.id):
			latch.set_held(held)


## The layout's piece spec of [param kit] nearest to [param point] within
## [param reach] metres, or null.
func _nearest_spec(kit: StringName, point: Vector3, reach: float) -> PieceSpec:
	var best: PieceSpec = null
	var best_distance := reach
	for spec in level.layout.pieces:
		if spec.kit != kit:
			continue
		var distance := Vector2(spec.position.x - point.x, spec.position.z - point.z).length()
		if distance < best_distance:
			best_distance = distance
			best = spec
	return best


## The artifact pickup lying within 0.3 m of [param point], or null.
func _artifact_near(point: Vector3) -> ArtifactPickup:
	for spot: int in artifacts:
		var pickup := artifacts[spot] as ArtifactPickup
		if is_instance_valid(pickup) and pickup.global_position.distance_to(point) < 0.3:
			return pickup
	return null
