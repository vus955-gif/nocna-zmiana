class_name GateSpec
extends RefCounted
## A lock of the museum floor (design: pietro-1-projekt section 4.2): a
## passage or an object that stays shut until its requirement is met, then
## stays open for good (PersistentState.gates_open). Each kind has one
## readable language: look, sound and the label at the crosshair.
## A gate blocks [member opening] (an OpeningSpec id: the Door there stays
## closed and locked) or, with no opening, guards whatever stands at
## [member marker] (the gatling's chained case). The lock prop that shows
## the kind (chain, boards, cracked wall, rope, hook ring) carries the same
## gate id.

enum Kind {
	## heavy chain with a padlock: shotgun (25+ damage within 0.4 s) or 3 punches
	CHAIN,
	## boarded-up passage "REMONT": shotgun, 5 punches or a blast
	BOARDS,
	## stone / bronze doors with a symbol-shaped hollow: a guardian's seal
	SEAL,
	## steel fire shutter with a red lamp: power from the switchboard
	POWER,
	## cracked wall: a blast (hwacha volley, flares from close up)
	CRACKED,
	## rope and counterweight out of reach: a precise shot
	ROPE,
	## iron ring on an object: the harpoon pulls it
	HOOK,
	## service door bolted on one side: opened from [member one_way_side]
	BOLT,
	## opened by the game itself when its requirement comes true (the grate
	## to the crypt after the T-Rex)
	EVENT,
}

## Requirement tokens (see ProgressRules.has_requirement): a weapon id
## (&"rifle_hunt", &"harpoon"...), a seal or key (&"seal_sun", &"star_key"), a
## key item (&"pistol_key", &"fuse_assyria"), a flag (&"power_north"), or one
## of these:
## anything heavy: fists always qualify
const HEAVY := &"heavy"
## a precise shot: pistol or rifle
const PRECISE := &"precise"
## a blast: hwacha or flare gun
const EXPLOSIVE := &"explosive"
## nothing (a bolt only needs its side)
const NONE := &""

var id: StringName = &""
var kind: Kind = Kind.CHAIN
## OpeningSpec id of the passage it blocks (&"" = a lock on an object).
var opening: StringName = &""
## Marker id of the lock prop (&"" = in the middle of the opening).
var marker: StringName = &""
var requirement: StringName = NONE
## Translation key of the label at the crosshair ("Łańcuch — rozbij...").
var label_key: StringName = &""
## BOLT: the room it is opened from (the other side only sees a bolted door).
var one_way_side: StringName = &""


static func make(gate_id: StringName, gate_kind: Kind, blocks: StringName, needs: StringName = NONE, label: StringName = &"", bolt_side: StringName = &"") -> GateSpec:
	var gate := GateSpec.new()
	gate.id = gate_id
	gate.kind = gate_kind
	gate.opening = blocks
	gate.requirement = needs
	gate.label_key = label
	gate.one_way_side = bolt_side
	return gate


## A BOLT opens only from its side; every other kind from both sides.
func opens_from(room: StringName) -> bool:
	return kind != Kind.BOLT or room == one_way_side


## The kind's name in the data tables (&"chain", &"seal"...).
static func kind_name(gate_kind: Kind) -> StringName:
	return StringName(String(Kind.keys()[gate_kind]).to_lower())
