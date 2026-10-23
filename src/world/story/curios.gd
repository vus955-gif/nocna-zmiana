class_name Curios
## The exhibits that answer the guard (plan docs/superpowers/plans/
## 2026-10-21-opowiesc-muzeum.md, 2.3): small, fair, never needed to go on.
## - bird: the singing bird automaton in the Hall of Clocks; wound up, it
##   sings six short notes and a long trill toward the Planetarium (the
##   Great Orrery: six planets, then the sun);
## - astrolabe: the founder's travelling astrolabe; turned notch by notch
##   to the Pole Star, it opens the drawer in its stand (Dust, rounds);
## - portrait: the founder's portrait in the north corridor answers once
##   (the porter's lodge on its cord);
## - scale: the scales of Osiris's judgement in the tombs; a hand on the
##   empty pan, and the pan sinks as if a heart lay on it (Dust, a medkit).
## Each is done once per game (GameState.flags "curio_<id>"); what lay in
## a drawer stays the guard's once taken ("curio_<id>_taken_<n>").
## Texts: CURIO_<ID>_TITLE, _TEXT (what it is), _ANSWER (what it does);
## PROMPT_CURIO_<ID>. Pure data.

const PREFIX := "curio_"
const TAKEN := "_taken_"

## id -> [inventory number, Dust in its drawer, loot in its drawer].
const ENTRIES := {
	&"bird": ["OS.1781.4", 0, []],
	&"astrolabe": ["OS.1866.7", 25, [&"hunt_rounds"]],
	&"portrait": ["MZ.1870.2", 0, []],
	&"scale": ["EG.1898.33", 25, [&"medkit"]],
}


static func ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for id: StringName in ENTRIES:
		out.append(id)
	return out


static func has(id: StringName) -> bool:
	return ENTRIES.has(id)


static func id_of_marker(marker: StringName) -> StringName:
	var text := String(marker)
	return StringName(text.trim_prefix(PREFIX)) if text.begins_with(PREFIX) else &""


static func marker_of(id: StringName) -> StringName:
	return StringName(PREFIX + String(id))


## The GameState flag of curio [param id] done.
static func flag(id: StringName) -> StringName:
	return StringName(PREFIX + String(id))


## The GameState flag of the [param index]th thing of its drawer taken.
static func taken_flag(id: StringName, index: int) -> StringName:
	return StringName("%s%s%s%d" % [PREFIX, id, TAKEN, index])


static func number(id: StringName) -> String:
	return ENTRIES[id][0] if ENTRIES.has(id) else ""


static func dust(id: StringName) -> int:
	return int(ENTRIES[id][1]) if ENTRIES.has(id) else 0


static func loot(id: StringName) -> Array[StringName]:
	var out: Array[StringName] = []
	if ENTRIES.has(id):
		out.assign(ENTRIES[id][2])
	return out


static func title_key(id: StringName) -> String:
	return "CURIO_%s_TITLE" % String(id).to_upper()


static func text_key(id: StringName) -> String:
	return "CURIO_%s_TEXT" % String(id).to_upper()


static func answer_key(id: StringName) -> String:
	return "CURIO_%s_ANSWER" % String(id).to_upper()


static func prompt_key(id: StringName) -> String:
	return "PROMPT_CURIO_%s" % String(id).to_upper()
