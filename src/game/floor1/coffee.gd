class_name Coffee
extends RefCounted
## The café's drinks (plan docs/superpowers/plans/2026-10-10-kawiarnia-
## zmeczenie.md, section 2.2). Pure data and texts: what a coffee does to the
## guard is Fatigue.COFFEES (the one place with the numbers), what the counter
## serves by the hour is machine_kind(): the machine pours an espresso, the
## urn a large coffee; after the witching hour the machine "pours what it
## likes" - the special, under an absurd label that changes with every cup.
## Coffee is free; only time rations it (the machine heats for
## MACHINE_WARMUP s after a cup, the urn drips URN_DRIP s).

const ESPRESSO := &"espresso"
const LARGE := &"large"
const SPECIAL := &"special"
const KINDS: Array[StringName] = [ESPRESSO, LARGE, SPECIAL]

## Seconds of game time before the machine pours again / the urn drips again.
const MACHINE_WARMUP := 90.0
const URN_DRIP := 150.0

## How many absurd labels there are (COFFEE_ABSURD_1 .. _5).
const ABSURDS := 5
const SLATE_LINES := 3


## What the machine pours.
static func machine_kind(haywire: bool) -> StringName:
	return SPECIAL if haywire else ESPRESSO


## The action under the crosshair for a plain drink.
static func prompt_key(kind: StringName) -> String:
	return "PROMPT_COFFEE_%s" % String(kind).to_upper()


## The line shown once [param kind] is drunk.
static func toast_key(kind: StringName) -> String:
	return "HUD_COFFEE_DRUNK_%s" % String(kind).to_upper()


## The key of the [param index]-th absurd label (it goes round).
static func absurd_key(index: int) -> String:
	return "COFFEE_ABSURD_%d" % (posmod(index, ABSURDS) + 1)


static func absurd_label(index: int) -> String:
	return TranslationServer.translate(absurd_key(index))


## The keys of the three chalk lines of the slate.
static func slate_keys(haywire: bool) -> Array[String]:
	var keys: Array[String] = []
	for line in SLATE_LINES:
		keys.append("SLATE_%s_%d" % ["HAYWIRE" if haywire else "NORMAL", line + 1])
	return keys


## Every translation key the café builds at run time (the localization test
## checks them: the code never spells them out).
static func all_keys() -> PackedStringArray:
	var keys := PackedStringArray()
	for kind in KINDS:
		keys.append(toast_key(kind))
	for kind in [ESPRESSO, LARGE]:
		keys.append(prompt_key(kind))
	for i in ABSURDS:
		keys.append(absurd_key(i))
	for haywire in [false, true]:
		keys.append_array(slate_keys(haywire))
	return keys
