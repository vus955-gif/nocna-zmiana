class_name ExhibitLabels
## The museum labels by Floor I's key exhibits (plan docs/superpowers/plans/
## 2026-10-21-opowiesc-muzeum.md, 2.1): a brass plate on a wall, on a
## pedestal or on a stand, read with E (ExhibitLabel shows the card). Each
## has an inventory number (data, not translated), a title and two or three
## short lines in the catalogue's voice with a dark turn
## (LABEL_<ID>_TITLE / LABEL_<ID>_TEXT in locale/strings.csv). Some are
## clues (CLUES): they point at a guardian's weak spot, a secret behind a
## gate and the tool that opens it, or the exhibits that wake when something
## is taken; a test checks every one of them points at something the
## layout has. Where each stands: the label_<id> markers of
## src/level/floor1/zones/story.gd. Pure data.

## How a label is put up: a plate on a wall or on the face of a pedestal
## (the marker on the face, -Z out of it), a plate on a slanted museum stand
## on the floor (the marker on the floor, -Z toward the reader), or the art
## kit's own plate (the T-Rex's: only a plain plate in a greybox build).
enum Mount { WALL, STAND, ART }

## What a clue points at.
enum Clue { NONE, WEAKNESS, SECRET, TOOL, WARNING }

const PREFIX := "label_"

## id -> [mount, inventory number, clue kind, clue data]. Clue data:
## WEAKNESS {"marker": the guardian's marker}; SECRET {"secret": its marker,
## "gate": the gate that hides it, "tool": what the gate needs}; TOOL
## {"gate", "tool"}; WARNING {"ambush": the exhibits that wake}.
const ENTRIES := {
	&"trex": [Mount.ART, "PAL.1904.1", Clue.WEAKNESS, {"marker": &"trex_pedestal"}],
	&"crypt": [Mount.WALL, "MZ.1870.1", Clue.NONE, {}],
	&"rosetta": [Mount.STAND, "EG.1871.3", Clue.NONE, {}],
	&"camp": [Mount.STAND, "EG.1898.1", Clue.WARNING, {"ambush": &"egypt_camp"}],
	&"colossus": [Mount.WALL, "EG.1898.40", Clue.WEAKNESS, {"marker": &"guardian_colossus"}],
	&"false_door": [Mount.WALL, "EG.1898.27", Clue.SECRET, {"secret": &"secret_egypt_3", "gate": &"egypt_hook_false_door", "tool": &"harpoon"}],
	&"lamassu": [Mount.STAND, "AS.1882.1", Clue.WEAKNESS, {"marker": &"guardian_lamassu"}],
	&"obelisk": [Mount.STAND, "AS.1882.9", Clue.NONE, {}],
	&"lion_cage": [Mount.WALL, "AS.1882.31", Clue.SECRET, {"secret": &"secret_assyria_2", "gate": &"assyria_rope_cage", "tool": &"precise"}],
	&"tablets": [Mount.WALL, "AS.1882.112", Clue.SECRET, {"secret": &"secret_assyria_1", "gate": &"assyria_cracked_tablets", "tool": &"explosive"}],
	&"nereid": [Mount.WALL, "GR.1888.4", Clue.WARNING, {"ambush": &"greece_podium"}],
	&"metopes": [Mount.WALL, "GR.1923.12", Clue.WEAKNESS, {"marker": &"guardian_centaur"}],
	&"vases": [Mount.WALL, "GR.1923.77", Clue.SECRET, {"secret": &"secret_greece_2", "gate": &"greece_cracked_pottery", "tool": &"explosive"}],
	&"orrery": [Mount.WALL, "OS.1840.1", Clue.TOOL, {"gate": &"rope_planetarium", "tool": &"rifle_hunt"}],
	&"rifle": [Mount.STAND, "OS.1869.2", Clue.WARNING, {"ambush": &"enlightenment_rifle"}],
	&"general": [Mount.WALL, "AZ.1910.18", Clue.WEAKNESS, {"marker": &"guardian_general"}],
	&"shrine": [Mount.WALL, "AZ.1910.40", Clue.SECRET, {"secret": &"secret_asia_3", "gate": &"asia_rope_shrine", "tool": &"precise"}],
	&"moai": [Mount.WALL, "AM.1868.2", Clue.SECRET, {"secret": &"secret_americas_1", "gate": &"americas_hook_moai", "tool": &"harpoon"}],
	&"serpent": [Mount.WALL, "AM.1894.5", Clue.WEAKNESS, {"marker": &"guardian_serpent"}],
	&"totems": [Mount.WALL, "AM.1931.3", Clue.SECRET, {"secret": &"secret_americas_3", "gate": &"americas_boards_store", "tool": &"heavy"}],
}


static func ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for id: StringName in ENTRIES:
		out.append(id)
	return out


static func has(id: StringName) -> bool:
	return ENTRIES.has(id)


## The label of marker [param marker] (label_<id>), &"" for another marker.
static func id_of_marker(marker: StringName) -> StringName:
	var text := String(marker)
	return StringName(text.trim_prefix(PREFIX)) if text.begins_with(PREFIX) else &""


static func marker_of(id: StringName) -> StringName:
	return StringName(PREFIX + String(id))


static func mount(id: StringName) -> Mount:
	return ENTRIES[id][0] if ENTRIES.has(id) else Mount.WALL


static func number(id: StringName) -> String:
	return ENTRIES[id][1] if ENTRIES.has(id) else ""


static func clue(id: StringName) -> Clue:
	return ENTRIES[id][2] if ENTRIES.has(id) else Clue.NONE


static func clue_data(id: StringName) -> Dictionary:
	return ENTRIES[id][3] if ENTRIES.has(id) else {}


static func title_key(id: StringName) -> String:
	return "LABEL_%s_TITLE" % String(id).to_upper()


static func text_key(id: StringName) -> String:
	return "LABEL_%s_TEXT" % String(id).to_upper()
