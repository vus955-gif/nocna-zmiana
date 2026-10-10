class_name ArtifactCatalog
## The six night artifacts (spec 7.4): what they are called, what they do
## and how strongly. An artifact lasts until dawn or death
## (RunState.artifacts); NightDirector decides where they lie each night.
## Texts: ARTIFACT_<ID> (name), _EFFECT, _FLAVOR in locale/strings.csv.

const SCARAB := &"scarab"
const MONOCLE := &"monocle"
const FOUNTAIN_COIN := &"fountain_coin"
const CANDLE_STUB := &"candle_stub"
const WOLF_TOOTH := &"wolf_tooth"
const JANITOR_KEY := &"janitor_key"
## In NightDirector.ARTIFACTS order.
const IDS: Array[StringName] = [SCARAB, MONOCLE, FOUNTAIN_COIN, CANDLE_STUB, WOLF_TOOTH, JANITOR_KEY]

## Scarab: a fist finisher heals this much more (+100%).
const FINISHER_HEAL_BONUS := 1.0
## Fountain coin: Dust multiplier (RunState.multipliers[DUST_SOURCE]).
const DUST_FACTOR := 1.5
const DUST_SOURCE := &"coin"
## Candle stub: stuns last this many times as long.
const STUN_FACTOR := 1.5
## Wolf's tooth: sprint speed factor.
const SPRINT_FACTOR := 1.2

## The colour each artifact glows with (and its icon's accent).
const COLORS := {
	SCARAB: Color(0.3, 0.85, 0.78),
	MONOCLE: Color(1.0, 0.8, 0.45),
	FOUNTAIN_COIN: Color(0.75, 0.9, 0.85),
	CANDLE_STUB: Color(1.0, 0.62, 0.25),
	WOLF_TOOTH: Color(0.92, 0.88, 0.78),
	JANITOR_KEY: Color(0.95, 0.72, 0.38),
}


## True for an artifact id (NightConfig.loot also holds ammo and medkits).
static func is_artifact(item: Variant) -> bool:
	return (item is StringName or item is String) and IDS.has(StringName(item))


static func name_key(id: StringName) -> String:
	return "ARTIFACT_" + String(id).to_upper()


static func effect_key(id: StringName) -> String:
	return name_key(id) + "_EFFECT"


static func flavor_key(id: StringName) -> String:
	return name_key(id) + "_FLAVOR"


static func color(id: StringName) -> Color:
	return COLORS.get(id, Color(1.0, 0.85, 0.6))
