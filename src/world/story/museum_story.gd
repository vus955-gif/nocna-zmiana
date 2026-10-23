class_name MuseumStory
extends Node3D
## Floor I's story told by the museum itself (plan docs/superpowers/plans/
## 2026-10-21-opowiesc-muzeum.md), installed by FloorGame with one call:
## [code]MuseumStory.install(floor_game)[/code]. It reads the story layer's
## markers (src/level/floor1/zones/story.gd) and puts up:
## - the exhibit labels (label_<id>: ExhibitLabel; E shows the card),
## - the staff's trails, one per wing (vignette_<wing>_<kind>: StoryProps;
##   the one thing to look at closely is a StoryExamine),
## - the exhibits that answer the guard (curio_<id>: the singing bird, the
##   travelling astrolabe, the founder's portrait, the scales; Curios),
## - the places the guard comes back to: the court's plaque of exhibits
##   returned to rest (rest_plaque: RestPlaque), the staff's corkboard by the
##   café (cafe_corkboard: StaffCorkboard), the shift's log on the booth's
##   CCTV (ShiftLog: a page of the status screen, AT REST on the feeds of a
##   wing whose guardian is down),
## and the card they share (ExhibitCard).
## Tests make one with make() from a bare layout (no level built).

signal label_read(id: StringName)
signal examined(wing: StringName)
## A curio gave in for the first time this game (announced, saved).
signal curio_solved(id: StringName)

var layout: LevelLayout
var markers: Dictionary = {}
## The level is dressed (the art kit's own plates are there).
var dressed: bool = false
var game: PersistentState = null
var run: NightState = null
## -> the guard (Node3D) or null.
var guard_source: Callable = Callable()
## The world content's HUD for discoveries (WorldFeatures.hud), or null.
var banner: WorldHud = null
var card: ExhibitCard
## Label id -> ExhibitLabel.
var labels: Dictionary = {}
## Vignette marker -> its prop (a StoryExamine for a trail's key thing).
var props: Dictionary = {}
## Wing -> the StoryExamine of its trail.
var examines: Dictionary = {}
## Curio id -> Curio.
var curios: Dictionary = {}
## item -> the loot this guard gets for it (Museum.loot_for_guard); unset:
## the item itself.
var loot_source: Callable = Callable()
## The booth's CCTV (WorldFeatures.cctv), or null.
var cctv: Cctv = null
var plaque: RestPlaque = null
var corkboard: StaffCorkboard = null


static func install(floor_game: FloorGame) -> MuseumStory:
	var story := make(floor_game.level.layout, floor_game.level.markers, func() -> Node3D: return floor_game.museum.player)
	story.dressed = bool(floor_game.level.get(&"art"))
	story.game = floor_game.museum.game
	story.run = floor_game.museum.run
	if floor_game.world != null:
		story.banner = floor_game.world.hud
	story.loot_source = func(item: StringName) -> StringName: return floor_game.museum.loot_for_guard(item)
	if floor_game.world != null:
		story.cctv = floor_game.world.cctv
	floor_game.add_child(story)
	return story


## A story for [param story_layout] and its [param story_markers] (the
## level's), the guard from [param guard].
static func make(story_layout: LevelLayout, story_markers: Dictionary, guard: Callable = Callable()) -> MuseumStory:
	var story := MuseumStory.new()
	story.name = "MuseumStory"
	story.layout = story_layout
	story.markers = story_markers
	story.guard_source = guard
	return story


func _ready() -> void:
	top_level = true
	if game == null:
		game = GameState
	if run == null:
		run = RunState
	card = ExhibitCard.new()
	card.name = "ExhibitCard"
	card.guard_source = guard_source
	add_child(card)
	_build_labels()
	_build_vignettes()
	_build_curios()
	_build_anchors()


func guard() -> Node3D:
	return guard_source.call() as Node3D if guard_source.is_valid() else null


func _marker_ids(prefix: String) -> Array[StringName]:
	var ids: Array[StringName] = []
	for id: StringName in markers:
		if String(id).begins_with(prefix):
			ids.append(id)
	ids.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	return ids


## The zone of the room [param marker] lies in (&"" when unknown).
func zone_of(marker: StringName) -> StringName:
	var room := layout.room(layout.marker_rooms.get(marker, &"")) if layout != null else null
	return room.zone if room != null else &""


# --- labels ----------------------------------------------------------------------

func _build_labels() -> void:
	for marker in _marker_ids(ExhibitLabels.PREFIX):
		var id := ExhibitLabels.id_of_marker(marker)
		if not ExhibitLabels.has(id):
			FloorGame.warn_once("MuseumStory: no label %s in ExhibitLabels" % id)
			continue
		var label := ExhibitLabel.create(id, markers[marker], not dressed)
		label.read.connect(read_label)
		add_child(label)
		labels[id] = label


## Shows label [param id]'s card (or puts it down when it is up).
func read_label(id: StringName) -> void:
	var label := labels.get(id) as ExhibitLabel
	var zone := zone_of(ExhibitLabels.marker_of(id))
	var caption := tr("LABEL_CAPTION") % [ExhibitLabels.number(id), tr(Floor1Plan.zone_name_key(zone))]
	var at := label.global_position if label != null else Vector3.INF
	card.toggle(caption, tr(ExhibitLabels.title_key(id)), tr(ExhibitLabels.text_key(id)), at, Floor1Plan.zone_color(zone))
	label_read.emit(id)


# --- the staff's trails ------------------------------------------------------------

func _build_vignettes() -> void:
	var index := 0
	for marker in _marker_ids(StoryVignettes.PREFIX):
		var parsed := StoryVignettes.parse(marker)
		var wing: StringName = parsed[0]
		var kind: StringName = parsed[1]
		index += 1
		var look := StoryProps.make(kind, index)
		if look == null:
			FloorGame.warn_once("MuseumStory: no prop %s for %s" % [kind, marker])
			continue
		var at: Transform3D = markers[marker]
		if StoryVignettes.is_key(marker):
			var thing := StoryExamine.create(wing, kind, at, look)
			thing.examined.connect(examine)
			add_child(thing)
			props[marker] = thing
			examines[wing] = thing
			continue
		look.name = "Vignette_" + String(marker).trim_prefix(StoryVignettes.PREFIX)
		look.transform = at
		add_child(look)
		props[marker] = look


## Shows what the guard found on [param wing]'s trail (or puts it down).
func examine(wing: StringName) -> void:
	var thing := examines.get(wing) as Node3D
	var at := thing.global_position if thing != null else Vector3.INF
	card.toggle(tr(StoryVignettes.who_key(wing)), tr(StoryVignettes.title_key(wing)), tr(StoryVignettes.text_key(wing)), at, Floor1Plan.zone_color(wing))
	examined.emit(wing)


# --- the exhibits that answer -------------------------------------------------------

func _build_curios() -> void:
	for marker in _marker_ids(Curios.PREFIX):
		var id := Curios.id_of_marker(marker)
		var curio := _make_curio(id)
		if curio == null:
			FloorGame.warn_once("MuseumStory: no curio %s" % id)
			continue
		curio.id = id
		curio.name = "Curio_" + String(id)
		curio.transform = markers[marker]
		curio.game = game
		curio.run = run
		curio.loot_source = loot_source
		curio.spoke.connect(_on_curio_spoke)
		curio.solved.connect(_on_curio_solved)
		add_child(curio)
		curios[id] = curio


func _make_curio(id: StringName) -> Curio:
	match id:
		&"bird":
			var bird := CurioBird.new()
			# it sings its long note to the Great Orrery
			var orrery: Variant = markers.get(&"guardian_planetarium")
			if orrery is Transform3D:
				bird.target = (orrery as Transform3D).origin
			return bird
		&"astrolabe":
			return CurioAstrolabe.new()
		&"portrait":
			return CurioPortrait.new()
		&"scale":
			return CurioScale.new()
	return null


## A curio says what it is or what it did: its card (the inventory number
## and the wing, its name, the text).
func _on_curio_spoke(id: StringName, text_key: String) -> void:
	var curio := curios.get(id) as Curio
	var zone := zone_of(Curios.marker_of(id))
	var caption := tr("LABEL_CAPTION") % [Curios.number(id), tr(Floor1Plan.zone_name_key(zone))]
	var at := curio.global_position if curio != null else Vector3.INF
	card.show_card(caption, tr(Curios.title_key(id)), tr(text_key), at, Floor1Plan.zone_color(zone))


## The first time a curio gives in: the banner (with its pouch of Dust).
func _on_curio_solved(id: StringName) -> void:
	if banner != null:
		var dust := Curios.dust(id)
		banner.banner(tr("CURIO_FOUND"), tr(Curios.title_key(id)), tr("CURIO_DUST") % dust if dust > 0 else "")
	curio_solved.emit(id)


# --- the places the guard comes back to ---------------------------------------------

func _build_anchors() -> void:
	var at: Variant = markers.get(&"rest_plaque")
	if at is Transform3D:
		plaque = RestPlaque.new()
		plaque.name = "RestPlaque"
		plaque.game = game
		plaque.transform = at
		plaque.read.connect(read_plaque)
		add_child(plaque)
	at = markers.get(&"cafe_corkboard")
	if at is Transform3D:
		corkboard = StaffCorkboard.new()
		corkboard.name = "Corkboard"
		corkboard.game = game
		corkboard.transform = at
		corkboard.read.connect(read_corkboard)
		add_child(corkboard)
	if cctv != null:
		cctv.log_source = func() -> PackedStringArray: return ShiftLog.lines(game, layout)
		cctv.calm_source = func(room: StringName) -> bool: return ShiftLog.room_at_rest(game, layout, room)


## The Directorate's small print under the count (the card).
func read_plaque() -> void:
	var at := plaque.global_position if plaque != null else Vector3.INF
	var title := tr("REST_PLAQUE_TITLE") % ShiftLog.rested(game)
	var text := tr("REST_PLAQUE_TEXT") % [ShiftLog.wings_at_rest(game), Floor1Plan.WINGS.size()]
	card.toggle(tr("REST_PLAQUE_CAPTION"), title, text, at, UiTheme.ACCENT)


## The notices pinned on the staff's corkboard tonight (the card).
func read_corkboard() -> void:
	if corkboard == null:
		return
	WorldSounds.cue(&"paper", -6.0)
	card.toggle(tr("CORK_CAPTION"), tr("CORK_TITLE") % game.night, corkboard.board_text(), corkboard.global_position, Floor1Plan.zone_color(&"court"))
