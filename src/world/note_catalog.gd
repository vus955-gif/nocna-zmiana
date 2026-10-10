class_name NoteCatalog
## The notes left around the lobby and Floor I by earlier night guards (and
## curators, scholars, craftsmen): their texts (NOTE_<ID>_TITLE / _BODY /
## _SIGN in locale/strings.csv), the paper each is written on, and the
## record of the ones read (GameState.notes, saved with the game). The
## three notes of the night-shift set make secret 5 once all are read.
## Pure logic: the persistent state is passed in.

## What a note is written on (the reader and the world model follow it).
enum Paper { LINED, STICKY, TYPED, LETTER, FORM }

## The night-shift set (markers note_1..3 of the level).
const SET: Array[StringName] = [&"note_1", &"note_2", &"note_3"]
## Heniek's sticky note on the security desk: where the locker key is.
const KEY_NOTE := &"note_key"
## Every note in reading order (the pause menu may list them like this).
const ALL: Array[StringName] = [&"note_key", &"note_1", &"note_2", &"note_3", &"note_chamber", &"note_niche", &"note_vent", &"note_closet"]
const PAPER := {
	&"note_key": Paper.STICKY,
	&"note_1": Paper.LINED,
	&"note_2": Paper.LINED,
	&"note_3": Paper.LINED,
	&"note_chamber": Paper.LETTER,
	&"note_niche": Paper.TYPED,
	&"note_vent": Paper.FORM,
	&"note_closet": Paper.LINED,
	# Floor I (markers note_<zone>_<n>; a note not listed here is LINED).
	# Lore and authors: docs/fabula-pietro1.md.
	&"note_booth_1": Paper.LETTER,
	&"note_court_2": Paper.TYPED,
	&"note_egypt_1": Paper.LETTER,
	&"note_egypt_2": Paper.FORM,
	&"note_egypt_3": Paper.TYPED,
	&"note_egypt_4": Paper.TYPED,
	&"note_assyria_1": Paper.TYPED,
	&"note_assyria_2": Paper.LETTER,
	&"note_assyria_3": Paper.FORM,
	&"note_greece_1": Paper.LETTER,
	&"note_greece_4": Paper.FORM,
	&"note_enlightenment_1": Paper.TYPED,
	&"note_enlightenment_2": Paper.LETTER,
	&"note_asia_1": Paper.TYPED,
	&"note_asia_2": Paper.LETTER,
	&"note_asia_4": Paper.LETTER,
	&"note_americas_1": Paper.LETTER,
	&"note_americas_2": Paper.TYPED,
	&"note_americas_4": Paper.TYPED,
	&"note_basement_3": Paper.FORM,
}


## A note of the lobby's set, or any id whose title is in the translations
## (the notes the zones of Floor I place: note_<zone>_<n>).
static func is_note(id: StringName) -> bool:
	if PAPER.has(id):
		return true
	var key := title_key(id)
	return id != &"" and TranslationServer.translate(key) != key


static func paper(id: StringName) -> Paper:
	return PAPER.get(id, Paper.LINED)


static func in_set(id: StringName) -> bool:
	return SET.has(id)


static func title_key(id: StringName) -> String:
	return String(id).to_upper() + "_TITLE"


static func body_key(id: StringName) -> String:
	return String(id).to_upper() + "_BODY"


static func sign_key(id: StringName) -> String:
	return String(id).to_upper() + "_SIGN"


## The note's title in the current language.
static func title(id: StringName) -> String:
	return TranslationServer.translate(title_key(id))


## Records note [param id] as read. True the first time only.
static func read(game: PersistentState, id: StringName) -> bool:
	if not is_note(id) or game.notes.has(id):
		return false
	game.notes.append(id)
	return true


static func is_read(game: PersistentState, id: StringName) -> bool:
	return game.notes.has(id)


## How many notes of the night-shift set have been read.
static func set_read(game: PersistentState) -> int:
	var count := 0
	for id in SET:
		if game.notes.has(id):
			count += 1
	return count


static func set_complete(game: PersistentState) -> bool:
	return set_read(game) == SET.size()


## The notes read so far: the lobby's in their reading order (ALL), then
## Floor I's by zone (the floor's order of zones) and number.
static func read_notes(game: PersistentState) -> Array[StringName]:
	var found: Array[StringName] = []
	for id in ALL:
		if game.notes.has(id):
			found.append(id)
	var floor: Array[StringName] = []
	for id in game.notes:
		if not ALL.has(id) and is_note(id):
			floor.append(id)
	floor.sort_custom(_before)
	found.append_array(floor)
	return found


## The zone a note lies in: note_<zone>_<n> on Floor I, &"booth" for
## Heniek's sticky note, &"" for the lobby's.
static func zone_of(id: StringName) -> StringName:
	if id == KEY_NOTE:
		return &"booth"
	var text := String(id).trim_prefix("note_")
	var cut := text.rfind("_")
	var zone := StringName(text.substr(0, cut)) if cut > 0 else &""
	return zone if Floor1Plan.ZONES.has(zone) else &""


static func _before(a: StringName, b: StringName) -> bool:
	var rank_a := Floor1Plan.ZONES.find(zone_of(a))
	var rank_b := Floor1Plan.ZONES.find(zone_of(b))
	if rank_a != rank_b:
		return rank_a < rank_b
	return String(a).naturalnocasecmp_to(String(b)) < 0
