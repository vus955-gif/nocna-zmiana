class_name WorldFeatures
extends Node3D
## The world content of a level built from a LevelLayout by its markers
## (Floor I; the lobby keeps its own LobbyFeatures), installed with one
## call: [code]WorldFeatures.install(level, museum)[/code].
## - notes: every note_* marker whose note exists (NoteCatalog: a title in
##   the translations); note_heniek is Heniek's sticky note about the till
##   key (until the key is found),
## - secrets: every secret_* marker. A marker in a secret room (behind a
##   false panel or a zone gate) counts when the guard walks into that room
##   (its false panels open with a knock on their outer face; a gate's lock
##   is the gate's business). A marker in an open room: a false panel within
##   PANEL_REACH m opens and counts with a knock, else a loose stone
##   (SecretCache) gives it away. Found once, for good (GameState.secrets,
##   saved; its panels open on later nights),
## - the secrets' rewards (SecretRewards): a display at every secret marker
##   (SecretRewardDisplay) lit by the secret's discovery; E takes the reward
##   (claim_reward(): a pouch of Dust, a permanent bonus, a finish or a mod
##   applied at once, saved: GameState.secret_rewards) and the display
##   stands empty from then on; a small secret's stash (Pickups by the
##   display) restocks every night (RunState.used "stash_<secret>_<n>"),
## - Lewis chess pieces: every chess_* marker not found yet (ProgressPickup;
##   GameState.chess_found, saved),
## - tonight's artifacts on their drawn loot spots (a resumed night gives
##   back the ones taken in it) and the latches of tonight's locked door,
## - the CCTV (the cctv_<zone>_<n> markers, CctvCatalog.floor_cameras()
##   filling up to six) watched from [member watch_room],
## - the paper maps on the walls (museum_map_* markers) when the build has
##   MuseumMap.poster(layout) (workstream W6).

signal secret_discovered(id: StringName, found: int, total: int)
## The guard took a secret's reward (SecretRewards).
signal reward_claimed(id: StringName)
signal note_read(id: StringName)
signal artifact_taken(id: StringName)
signal pause_requested

const PANEL_REACH := 4.0
const SWITCH_DEPTH := 0.3
const NOTE_PREFIX := "note_"
const SECRET_PREFIX := "secret_"
const CHESS_PREFIX := "chess_"
const MAP_PREFIX := "museum_map_"
const LOUDSPEAKER_PREFIX := "loudspeaker_"
const AUDIOGUIDE_PREFIX := "audioguide_"
## RunState.used id of a stash pickup taken tonight: "stash_<secret>_<n>".
const STASH_PREFIX := "stash_"
## Where a stash lies beside its display (display space: x across, -Z front).
const STASH_SPOTS: Array[Vector3] = [Vector3(0.75, 0.35, 0.1), Vector3(-0.75, 0.35, 0.1)]
## The booth's note marker -> the note it holds.
const NOTE_ALIASES := {&"note_heniek": NoteCatalog.KEY_NOTE}
## Pieces of the Lewis set hidden on Floor I.
const CHESS_TOTAL := 8

var level: Level
var museum: Node
var night: NightConfig
var game: PersistentState
var run: NightState
var hud: WorldHud
var reader: NoteReader
## The room the CCTV's monitor wall is watched from.
var watch_room: StringName = &"booth_security"
## Note id -> NotePaper; secret id -> its switches or cache.
var notes: Dictionary = {}
var secrets: Dictionary = {}
## Secret id -> the secret room whose entry counts it (still to be found).
var secret_rooms: Dictionary = {}
## Secret id -> its reward's display; secret id -> the stash pickups lying
## tonight (small rewards in secret rooms).
var rewards: Dictionary = {}
var stashes: Dictionary = {}
## Secrets discovered tonight (the dawn card).
var found_tonight: int = 0
## Chess piece id -> ProgressPickup still lying.
var chess: Dictionary = {}
var effects: ArtifactEffects
## Loot spot index -> ArtifactPickup still waiting.
var artifacts: Dictionary = {}
var latches: Array[LockedDoorLatch] = []
var cctv: Cctv = null

var _check_left: float = 0.0


## Builds the world content for [param built] (already built) under
## [param host] (the Museum: its hud, player, night) and returns it.
static func install(built: Level, host: Node) -> WorldFeatures:
	var features := WorldFeatures.new()
	features.name = "WorldFeatures"
	features.level = built
	features.museum = host
	host.add_child(features)
	return features


func _ready() -> void:
	top_level = true
	if game == null:
		game = GameState
	if run == null:
		run = RunState
	if night == null:
		var host_night: Variant = museum.get(&"night") if is_instance_valid(museum) else null
		night = host_night if host_night is NightConfig else NightConfig.new()
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
	add_child(reader)
	_build_notes()
	_build_secrets()
	_build_rewards()
	_build_chess()
	_build_artifacts()
	_build_cctv()
	_build_maps()
	_build_voice_props()


func _process(delta: float) -> void:
	_check_left -= delta
	if _check_left > 0.0 or secret_rooms.is_empty():
		return
	_check_left = 0.25
	var player := guard()
	if player == null or not player.alive or not level.has_method(&"room_at"):
		return
	var here: StringName = level.call(&"room_at", player.global_position + Vector3.UP * 0.5)
	for id: StringName in secret_rooms.keys():
		if secret_rooms[id] == here:
			secret_rooms.erase(id)
			discover_secret(id)


func guard() -> Player:
	var host_player: Variant = museum.get(&"player") if is_instance_valid(museum) else null
	if is_instance_valid(host_player) and host_player is Player:
		return host_player
	return get_tree().get_first_node_in_group(&"player") as Player


func _markers() -> Dictionary:
	var found: Variant = level.get(&"markers")
	return found if found is Dictionary else {}


func _layout() -> LevelLayout:
	return level.get(&"layout") as LevelLayout


func _doors() -> Dictionary:
	var found: Variant = level.get(&"doors")
	return found if found is Dictionary else {}


func _marker_ids(prefix: String) -> Array[StringName]:
	var ids: Array[StringName] = []
	for id: StringName in _markers():
		if String(id).begins_with(prefix):
			ids.append(id)
	ids.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	return ids


# --- notes ---------------------------------------------------------------------

## Opens note [param id] (recorded and saved the first time).
func read_note(id: StringName) -> void:
	if NoteCatalog.read(game, id):
		NightRules.save_progress(game, run)
		note_read.emit(id)
	reader.open_note(id)


func _build_notes() -> void:
	for marker in _marker_ids(NOTE_PREFIX):
		var id: StringName = NOTE_ALIASES.get(marker, marker)
		if id == NoteCatalog.KEY_NOTE and game.pistol_key:
			continue   # the key is his: Heniek's note went with it
		if not NoteCatalog.is_note(id):
			FloorGame.warn_once("WorldFeatures: no text for the note %s (%s)" % [marker, NoteCatalog.title_key(id)])
			continue
		var at: Transform3D = _markers()[marker]
		var pinned := at.origin.y - _floor_under(marker) > 1.2
		var note := NotePaper.make(id, Transform3D(at.basis, at.origin + Vector3.UP * 0.002), pinned)
		note.read_requested.connect(read_note)
		add_child(note)
		notes[id] = note


func _floor_under(marker: StringName) -> float:
	var layout := _layout()
	var room := layout.room(layout.marker_rooms.get(marker, &"")) if layout != null else null
	return room.floor_y if room != null else 0.0


# --- secrets -----------------------------------------------------------------

## How many secrets the level hides (its secret_* markers).
func secrets_total() -> int:
	return _marker_ids(SECRET_PREFIX).size()


func secrets_found() -> int:
	var found := 0
	for id in _marker_ids(SECRET_PREFIX):
		if game.secrets.has(id):
			found += 1
	return found


## Records secret [param id]: sound, banner "Sekret odkryty (n/m)" with the
## tier of the reward waiting inside, the reward's display lit, save.
## False when it was known.
func discover_secret(id: StringName) -> bool:
	if game.secrets.has(id):
		return false
	game.secrets.append(id)
	found_tonight += 1
	WorldSounds.cue(&"secret")
	var hint := ""
	var display := rewards.get(id) as SecretRewardDisplay
	if display != null:
		if not display.is_taken:
			hint = tr("SECRET_TIER_HINT") % tr(SecretRewards.tier_key(display.tier))
		display.reveal()
	hud.banner(tr("SECRET_FOUND") % [secrets_found(), secrets_total()], _secret_place(id), hint)
	NightRules.save_progress(game, run)
	secret_discovered.emit(id, secrets_found(), secrets_total())
	Events.secret_found.emit(id, SecretRewards.tier_of(id), secrets_found())
	return true


## The name of the room a secret lies in.
func _secret_place(id: StringName) -> String:
	var layout := _layout()
	var room := layout.room(layout.marker_rooms.get(id, &"")) if layout != null else null
	return tr(room.name_key) if room != null and room.name_key != &"" else ""


func _build_secrets() -> void:
	var layout := _layout()
	for id in _marker_ids(SECRET_PREFIX):
		var at: Vector3 = (_markers()[id] as Transform3D).origin
		var room := layout.room(layout.marker_rooms.get(id, &"")) if layout != null else null
		if room != null and room.secret:
			_secret_room(id, room)
			continue
		var panel := _panel_near(at)
		if game.secrets.has(id):
			if panel != null:
				panel.open(true)
			continue
		if panel != null:
			var made: Array[SecretSwitch] = []
			for face in _panel_faces(panel):
				var switch := SecretSwitch.make("PROMPT_SECRET_PANEL", LobbyFeatures.door_face(panel, face), Vector3(panel.width * 0.9, panel.height * 0.85, SWITCH_DEPTH))
				switch.name = "Switch_%s_%s" % [id, face]
				switch.tag = id
				switch.door_id = panel.id
				switch.used.connect(_on_panel_switch)
				add_child(switch)
				made.append(switch)
			secrets[id] = made
		else:
			var cache := SecretCache.make(_markers()[id])
			cache.name = "Secret_" + String(id)
			cache.found.connect(func() -> void: discover_secret(id))
			add_child(cache)
			secrets[id] = [cache]


## Secret [param id] lies in the secret room [param room]: walking in
## counts it; the room's false panels (not its gates) open with a knock on
## their outer faces (open from the start once it is found).
func _secret_room(id: StringName, room: RoomSpec) -> void:
	var found := game.secrets.has(id)
	if not found:
		secret_rooms[id] = room.id
	var made: Array = []
	for door: Door in _doors().values():
		if not _is_false_panel(door) or (door.room_a != room.id and door.room_b != room.id):
			continue
		if found:
			door.open(true)
			continue
		for face in _panel_faces(door):
			var switch := SecretSwitch.make("PROMPT_SECRET_PANEL", LobbyFeatures.door_face(door, face), Vector3(door.width * 0.9, door.height * 0.85, SWITCH_DEPTH))
			switch.name = "Switch_%s_%s" % [id, face]
			switch.tag = id
			switch.door_id = door.id
			switch.used.connect(_on_room_panel_switch)
			add_child(switch)
			made.append(switch)
	if not made.is_empty():
		secrets[id] = made


## A false panel: a PANEL door that is no gate's (a cracked wall is a gate).
func _is_false_panel(door: Door) -> bool:
	if door.style != OpeningSpec.DoorStyle.PANEL:
		return false
	var layout := _layout()
	return layout == null or layout.gate_of_opening(door.id) == null


## A knock on a secret room's panel: it opens (the room counts the secret).
func _on_room_panel_switch(switch: SecretSwitch) -> void:
	var door := _doors().get(switch.door_id) as Door
	for other in secrets.get(switch.tag, []):
		if is_instance_valid(other) and other is SecretSwitch and (other as SecretSwitch).door_id == switch.door_id:
			(other as SecretSwitch).retire()
	if door != null:
		door.open()
		WorldSounds.cue_at(&"wall_slide", door.global_position + Vector3.UP * door.height * 0.5)


## The false panel within PANEL_REACH m of [param at] (null: none).
func _panel_near(at: Vector3) -> Door:
	var best: Door = null
	var best_distance := PANEL_REACH
	for door: Door in _doors().values():
		if not _is_false_panel(door):
			continue
		var distance := door.global_position.distance_to(at)
		if distance < best_distance:
			best_distance = distance
			best = door
	return best


## The faces of a panel the guard can find it from (not from a secret room).
func _panel_faces(panel: Door) -> Array[StringName]:
	var faces: Array[StringName] = []
	var layout := _layout()
	for room: StringName in [panel.room_a, panel.room_b]:
		var spec := layout.room(room) if layout != null else null
		if spec == null or not spec.secret:
			faces.append(room)
	return faces


func _on_panel_switch(switch: SecretSwitch) -> void:
	var door := _doors().get(switch.door_id) as Door
	for other in secrets.get(switch.tag, []):
		if is_instance_valid(other) and other is SecretSwitch:
			(other as SecretSwitch).retire()
	if door != null:
		door.open()
		WorldSounds.cue_at(&"wall_slide", door.global_position + Vector3.UP * door.height * 0.5)
	discover_secret(switch.tag)


# --- the secrets' rewards ----------------------------------------------------------

## How many of the floor's rewards the guard has claimed, and how many there are.
func rewards_claimed() -> int:
	return SecretRewards.claimed(game)


func rewards_total() -> int:
	return rewards.size()


## A display at every secret marker with a reward, on its room's floor and
## clear of the pieces, its plaque to the room's way in (RewardSpot): empty
## when the reward was claimed before, lit when the secret is known; in an
## open room (a loose stone) it stays out of sight until the stone is out. A
## small reward's stash lies beside it (secret rooms only), restocked every
## night.
func _build_rewards() -> void:
	var layout := _layout()
	for reward in SecretRewards.entries():
		if not _markers().has(reward.id):
			continue
		var at := RewardSpot.place(layout, reward.id, _markers()[reward.id], reward.tier)
		var room := layout.room(layout.marker_rooms.get(reward.id, &"")) if layout != null else null
		var hidden_room := room != null and room.secret
		var display := SecretRewardDisplay.make(reward, at)
		display.taken.connect(_on_reward_taken)
		add_child(display)
		if game.secret_rewards.has(reward.id):
			display.set_taken()
		if game.secrets.has(reward.id):
			display.reveal(true)
		elif not hidden_room:
			display.hide_away()
		rewards[reward.id] = display
		if hidden_room and not reward.stash.is_empty():
			_build_stash(reward, at)


func _build_stash(reward: SecretRewards.Entry, at: Transform3D) -> void:
	var lying: Array = []
	for i in mini(reward.stash.size(), STASH_SPOTS.size()):
		var used_id := StringName("%s%s_%d" % [STASH_PREFIX, reward.id, i])
		if run.is_used(used_id):
			continue
		var item := _loot_for_guard(reward.stash[i])
		if not Museum.LOOT_TYPES.has(item):
			continue
		var pickup := Pickup.new()
		pickup.name = "Stash_%s_%d" % [reward.id, i]
		pickup.type = Museum.LOOT_TYPES[item]
		pickup.amount = Museum.LOOT_AMOUNTS[item]
		pickup.respawn_time = 0.0
		pickup.position = at * STASH_SPOTS[i]
		pickup.taken.connect(run.mark_used.bind(used_id))
		add_child(pickup)
		lying.append(pickup)
	stashes[reward.id] = lying


## Ammo of a gun the guard does not have turns into ammo he can use, as
## every loot does (Museum.loot_for_guard); [param item] itself without a host.
func _loot_for_guard(item: StringName) -> StringName:
	if is_instance_valid(museum) and museum.has_method(&"loot_for_guard"):
		return museum.call(&"loot_for_guard", item)
	return item


func _on_reward_taken(id: StringName) -> void:
	claim_reward(id)


## The reward of secret [param id] is the guard's: a pouch adds its Dust at
## once; a bonus, a finish or a mod is applied to the guard right away
## (Player.apply_upgrades with SecretRewards.effective_levels: the weapon is
## looked over when next drawn); announced, saved. False when it was
## claimed before (or the secret has none).
func claim_reward(id: StringName) -> bool:
	var reward := SecretRewards.entry(id)
	if reward == null or not game.claim_reward(id):
		return false
	var display := rewards.get(id) as SecretRewardDisplay
	if display != null and not display.is_taken:
		display.set_taken()
	if reward.kind == SecretRewards.Kind.POUCH:
		run.add_dust(SecretRewards.POUCH_DUST, false)
		Events.dust_collected.emit(SecretRewards.POUCH_DUST)
	else:
		var player := guard()
		if player != null:
			player.apply_upgrades(SecretRewards.effective_levels(game))
	NightRules.save_progress(game, run)
	WorldSounds.cue(&"artifact")
	hud.banner(tr("REWARD_CAPTION") % tr(SecretRewards.tier_key(reward.tier)), tr(reward.name_key()), tr(reward.desc_key()))
	reward_claimed.emit(id)
	return true


# --- chess -------------------------------------------------------------------

func _build_chess() -> void:
	for id in _marker_ids(CHESS_PREFIX):
		if game.chess_found.has(id):
			continue
		var pickup := ProgressPickup.make(ProgressPickup.Kind.CHESS, id, (_markers()[id] as Transform3D).origin)
		pickup.game = game
		pickup.run = run
		add_child(pickup)
		chess[id] = pickup
		pickup.taken.connect(_on_chess_taken)


func _on_chess_taken(_kind: ProgressPickup.Kind, id: StringName) -> void:
	chess.erase(id)
	WorldSounds.cue(&"secret")
	hud.banner(tr("CHESS_FOUND") % [game.chess_found.size(), CHESS_TOTAL], tr("CHESS_PIECE"), tr("CHESS_DETAIL"))


# --- artifacts ---------------------------------------------------------------

func has_janitor_key() -> bool:
	return run.has_artifact(ArtifactCatalog.JANITOR_KEY)


func _build_artifacts() -> void:
	for spot_index: int in night.loot:
		var held := StringName(str(night.loot[spot_index]))
		if ArtifactCatalog.is_artifact(held) and run.is_used(LobbyFeatures.held_id(held)) and not run.artifacts.has(held):
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
	_build_latches()
	hud.set_artifacts(run.artifacts)


func _on_artifact_taken(id: StringName) -> void:
	if not run.artifacts.has(id):
		run.artifacts.append(id)
	run.mark_used(LobbyFeatures.held_id(id))
	for spot: int in artifacts.keys():
		if not is_instance_valid(artifacts[spot]) or (artifacts[spot] as ArtifactPickup).artifact_id == id:
			artifacts.erase(spot)
	effects.refresh()
	hud.set_artifacts(run.artifacts)
	WorldSounds.cue(&"artifact")
	hud.banner(tr("ARTIFACT_CAPTION"), tr(ArtifactCatalog.name_key(id)), tr(ArtifactCatalog.effect_key(id)) + "\n" + tr(ArtifactCatalog.flavor_key(id)))
	artifact_taken.emit(id)


## The latches of tonight's locked door (the janitor's key opens it).
func _build_latches() -> void:
	if night.locked_door == &"":
		return
	var door := _doors().get(night.locked_door) as Door
	if door == null or not door.locked:
		return
	if run.is_used(LobbyFeatures.unlocked_id(door.id)):
		door.unlock()
		door.open(true)
		return
	for room: StringName in [door.room_a, door.room_b]:
		var latch := LockedDoorLatch.make(door, LobbyFeatures.door_face(door, room))
		latch.has_key = has_janitor_key
		latch.refused.connect(func() -> void: hud.banner_once(tr("DOOR_LOCKED"), tr("DOOR_LOCKED_DETAIL")))
		latch.unlocked_with_key.connect(_on_door_unlocked)
		add_child(latch)
		latches.append(latch)


func _on_door_unlocked() -> void:
	for latch in latches:
		if is_instance_valid(latch.door):
			run.mark_used(LobbyFeatures.unlocked_id(latch.door.id))
		latch.retire()
	latches.clear()


# --- CCTV and the paper maps ----------------------------------------------------

func _build_cctv() -> void:
	var layout := _layout()
	if layout == null or layout.room(watch_room) == null:
		return
	var names := {}
	for room in layout.rooms:
		names[room.id] = String(room.name_key)
	cctv = Cctv.new()
	cctv.name = "Cctv"
	cctv.level = level
	cctv.watch_room = watch_room
	cctv.camera_specs = CctvCatalog.cameras_from(_markers(), layout.marker_rooms, names, CctvCatalog.floor_cameras())
	cctv.game = game
	cctv.run = run
	cctv.guard_source = guard
	add_child(cctv)
	cctv.pause_requested.connect(func() -> void: pause_requested.emit())


## The paper map on the walls of the havens (MuseumMap.poster() of W6).
func _build_maps() -> void:
	var ids := _marker_ids(MAP_PREFIX)
	if ids.is_empty():
		return
	var poster: Variant = _poster()
	if poster == null:
		FloorGame.warn_once("WorldFeatures: no MuseumMap.poster() in this build; the maps on the walls wait for it")
		return
	for id in ids:
		var at: Transform3D = _markers()[id]
		if poster is Texture2D:
			var sheet := Sprite3D.new()
			sheet.name = "Map_" + String(id)
			sheet.texture = poster
			sheet.pixel_size = 1.2 / maxf(float((poster as Texture2D).get_width()), 1.0)
			sheet.transform = Transform3D(at.basis.rotated(Vector3.UP, PI), at.origin)
			add_child(sheet)
		elif poster is PackedScene:
			var node := (poster as PackedScene).instantiate() as Node3D
			if node != null:
				node.transform = at
				add_child(node)


## MuseumMap.poster(layout) when the build has it (a Texture2D or a
## PackedScene), else null.
func _poster() -> Variant:
	for entry: Dictionary in ProjectSettings.get_global_class_list():
		if StringName(entry["class"]) != &"MuseumMap":
			continue
		var script := load(String(entry["path"])) as Script
		if script == null:
			return null
		for method: Dictionary in script.get_script_method_list():
			if StringName(method["name"]) == &"poster":
				return script.call(&"poster", _layout())
	return null


# --- the voice: loudspeakers and audio-guide stands ----------------------------

## The System's wall loudspeakers (loudspeaker_* markers) and the audio-guide
## stands (audioguide_<station> markers) of the level; VoiceDirector plays
## through them.
func _build_voice_props() -> void:
	for id in _marker_ids(LOUDSPEAKER_PREFIX):
		add_child(Loudspeaker.create(_markers()[id]))
	for id in _marker_ids(AUDIOGUIDE_PREFIX):
		var station := StringName(String(id).trim_prefix(AUDIOGUIDE_PREFIX))
		var stand := AudioguideStand.create(station, _markers()[id])
		# a solid thing on the floor the exhibits (and every way planned past
		# it) go round: a navigation source of the level, as the Lamassu's
		# plinth, the mummies' coffins and the Centaur's metope (the voice
		# reaches a stand through its E, the tests through its group)
		if level.has_method(&"add_walk_source") and level.get(&"navigation") != null:
			level.call(&"add_walk_source", stand)
		else:
			add_child(stand)
