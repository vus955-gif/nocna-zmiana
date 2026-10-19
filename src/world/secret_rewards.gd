class_name SecretRewards
## What every secret of Floor I rewards (plan 2026-10-10-nagrody-sekretow,
## the owner's #5 and #29): three tiers of worth, one entry per secret_*
## marker. Pure data and logic; the persistent state is passed in.
## - SMALL ("Schowek"): a pouch of Dust once, and in a secret room a stash
##   of loot restocked every night (WorldFeatures),
## - MEDIUM ("Znalezisko"): one permanent step of a guard bonus - health,
##   stamina, flashlight battery, spare ammo, the Dust magnet,
## - GREAT ("Skarb muzeum"): a unique finish for one weapon (WeaponLook.LOOKS)
##   or a mod that changes how it works (WeaponLook.MODS, UpgradeEffects).
## A claimed reward is kept in GameState.secret_rewards (saved). Everything
## claimed reaches the guard through effective_levels(): his upgrade levels
## plus the keys "bonus_<id>", "look_<weapon>_<id>" and "mod_<id>", the
## dictionary Player.apply_upgrades() already hands to UpgradeEffects and to
## the first-person models (WeaponHolder.upgrade_levels, WeaponLook).
## Texts: REWARD_<SECRET>_NAME / _DESC and REWARD_TIER_<TIER>.

enum Tier { SMALL, MEDIUM, GREAT }
enum Kind { POUCH, BONUS, LOOK, MOD }

## One step of a medium reward (half a catalog level or less; design 2.5).
const HEALTH_STEP := 10.0
const STAMINA_STEP := 10.0
## Seconds of flashlight per step.
const BATTERY_STEP := 20.0
## Spare ammo factor per step (deep pockets: 0.25 per level).
const POCKETS_STEP := 0.10
## Metres of Dust pull per step (the magnet upgrade: 3 per level).
const MAGNET_STEP := 1.5
## A small reward's pouch of Dust (once).
const POUCH_DUST := 20

## The guard bonuses a medium reward may step.
const BONUSES: Array[StringName] = [&"health", &"stamina", &"battery", &"pockets", &"magnet"]
const BONUS_PREFIX := "bonus_"

## Tier -> the light over its display and the accent of its banner.
const COLORS := {
	Tier.SMALL: Color(1.0, 0.78, 0.45),
	Tier.MEDIUM: Color(1.0, 0.88, 0.62),
	Tier.GREAT: Color(0.95, 0.92, 0.8),
}

## Secret marker id -> its reward: tier, kind and, by kind, "bonus" (a
## BONUSES id), "look" + "weapon" (WeaponLook.LOOKS), "mod" + "weapon"
## (WeaponLook.MODS), "stash" (loot ids restocked nightly, SMALL only).
## A secret pays at least what its gate costs (test_secret_rewards: the
## terminal's price of the same step against the gate's cost): the cracked
## walls, which eat the night's flares, hold none of the weakest steps.
const TABLE := {
	# the hub and the service areas
	&"secret_court_1": {"tier": Tier.SMALL, "kind": Kind.POUCH},
	&"secret_north_hall_1": {"tier": Tier.SMALL, "kind": Kind.POUCH, "stash": [&"bullets", &"medkit"]},
	&"secret_entrance_1": {"tier": Tier.MEDIUM, "kind": Kind.BONUS, "bonus": &"pockets"},
	&"secret_booth_1": {"tier": Tier.MEDIUM, "kind": Kind.BONUS, "bonus": &"stamina"},
	&"secret_basement_1": {"tier": Tier.MEDIUM, "kind": Kind.BONUS, "bonus": &"battery"},
	&"secret_basement_2": {"tier": Tier.GREAT, "kind": Kind.LOOK, "look": &"founder", "weapon": &"pistol"},
	&"secret_basement_3": {"tier": Tier.GREAT, "kind": Kind.LOOK, "look": &"warden", "weapon": &"taser"},
	&"secret_roof_1": {"tier": Tier.MEDIUM, "kind": Kind.BONUS, "bonus": &"battery"},
	&"secret_roof_2": {"tier": Tier.GREAT, "kind": Kind.LOOK, "look": &"signal", "weapon": &"flare"},
	# Egypt
	&"secret_egypt_1": {"tier": Tier.SMALL, "kind": Kind.POUCH, "stash": [&"shells", &"medkit"]},
	&"secret_egypt_2": {"tier": Tier.MEDIUM, "kind": Kind.BONUS, "bonus": &"health"},
	&"secret_egypt_3": {"tier": Tier.GREAT, "kind": Kind.LOOK, "look": &"faience", "weapon": &"shotgun"},
	# Assyria
	&"secret_assyria_1": {"tier": Tier.MEDIUM, "kind": Kind.BONUS, "bonus": &"health"},
	&"secret_assyria_2": {"tier": Tier.SMALL, "kind": Kind.POUCH, "stash": [&"shells", &"medkit"]},
	&"secret_assyria_3": {"tier": Tier.GREAT, "kind": Kind.LOOK, "look": &"balawat", "weapon": &"gatling"},
	# Greece
	&"secret_greece_1": {"tier": Tier.SMALL, "kind": Kind.POUCH, "stash": [&"bullets", &"medkit"]},
	&"secret_greece_2": {"tier": Tier.MEDIUM, "kind": Kind.BONUS, "bonus": &"stamina"},
	&"secret_greece_3": {"tier": Tier.GREAT, "kind": Kind.MOD, "mod": &"rifle_peep", "weapon": &"rifle_hunt"},
	# the Enlightenment
	&"secret_enlightenment_1": {"tier": Tier.MEDIUM, "kind": Kind.BONUS, "bonus": &"magnet"},
	&"secret_enlightenment_2": {"tier": Tier.MEDIUM, "kind": Kind.BONUS, "bonus": &"pockets"},
	&"secret_enlightenment_3": {"tier": Tier.GREAT, "kind": Kind.LOOK, "look": &"sloane", "weapon": &"rifle_hunt"},
	# Asia
	&"secret_asia_1": {"tier": Tier.MEDIUM, "kind": Kind.BONUS, "bonus": &"health"},
	&"secret_asia_2": {"tier": Tier.GREAT, "kind": Kind.LOOK, "look": &"lacquer", "weapon": &"hwacha"},
	&"secret_asia_3": {"tier": Tier.MEDIUM, "kind": Kind.BONUS, "bonus": &"stamina"},
	# the Americas
	&"secret_americas_1": {"tier": Tier.GREAT, "kind": Kind.MOD, "mod": &"harpoon_line", "weapon": &"harpoon"},
	&"secret_americas_2": {"tier": Tier.GREAT, "kind": Kind.MOD, "mod": &"shotgun_choke", "weapon": &"shotgun"},
	&"secret_americas_3": {"tier": Tier.GREAT, "kind": Kind.LOOK, "look": &"scrimshaw", "weapon": &"harpoon"},
}


class Entry:
	var id: StringName
	var tier: Tier
	var kind: Kind
	## The bonus id, the look id or the mod id (&"" for a pouch).
	var param: StringName = &""
	## The weapon a look or a mod belongs to.
	var weapon: StringName = &""
	## Loot ids restocked every night next to the display (SMALL).
	var stash: Array[StringName] = []

	func name_key() -> String:
		return "REWARD_%s_NAME" % String(id).to_upper()

	func desc_key() -> String:
		return "REWARD_%s_DESC" % String(id).to_upper()

	## The key of this reward among the guard's upgrade levels (&"" for a pouch).
	func level_key() -> StringName:
		match kind:
			Kind.BONUS:
				return SecretRewards.bonus_key(param)
			Kind.LOOK:
				return SecretRewards.look_key(weapon, param)
			Kind.MOD:
				return SecretRewards.mod_key(param)
		return &""


static var _entries: Array[Entry] = []


## Every reward, by secret id.
static func entries() -> Array[Entry]:
	if _entries.is_empty():
		var ids: Array = TABLE.keys()
		ids.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
		for id: StringName in ids:
			var row: Dictionary = TABLE[id]
			var made := Entry.new()
			made.id = id
			made.tier = row["tier"]
			made.kind = row["kind"]
			made.param = row.get("bonus", row.get("look", row.get("mod", &"")))
			made.weapon = row.get("weapon", &"")
			made.stash.assign(row.get("stash", []))
			_entries.append(made)
	return _entries


static func ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for entry in entries():
		out.append(entry.id)
	return out


## The reward of secret [param id], or null (a secret without one).
static func entry(id: StringName) -> Entry:
	for found in entries():
		if found.id == id:
			return found
	return null


static func total() -> int:
	return entries().size()


## The tier of secret [param id] (-1 for a secret without a reward).
static func tier_of(id: StringName) -> int:
	var found := entry(id)
	return found.tier if found != null else -1


static func tier_key(tier: Tier) -> String:
	return "REWARD_TIER_" + String(Tier.keys()[tier])


static func color(tier: Tier) -> Color:
	return COLORS.get(tier, Color(1.0, 0.85, 0.6))


static func bonus_key(bonus: StringName) -> StringName:
	return StringName(BONUS_PREFIX + String(bonus))


static func look_key(weapon: StringName, look: StringName) -> StringName:
	return WeaponLook.look_key(weapon, look)


static func mod_key(mod: StringName) -> StringName:
	return WeaponLook.mod_key(mod)


static func is_claimed(game: PersistentState, id: StringName) -> bool:
	return game.secret_rewards.has(id)


## How many rewards of the table [param game] has claimed.
static func claimed(game: PersistentState) -> int:
	var count := 0
	for entry_ in entries():
		if game.secret_rewards.has(entry_.id):
			count += 1
	return count


## The steps of every guard bonus claimed so far: bonus key -> count
## (only bonuses with at least one step).
static func bonuses(game: PersistentState) -> Dictionary:
	var out := {}
	for entry_ in entries():
		if entry_.kind == Kind.BONUS and game.secret_rewards.has(entry_.id):
			var key := bonus_key(entry_.param)
			out[key] = int(out.get(key, 0)) + 1
	return out


## The guard's upgrade levels with every claimed reward added: the bonus
## steps, the looks and the mods (each 1). The upgrades themselves are not
## touched.
static func effective_levels(game: PersistentState) -> Dictionary:
	var levels := game.upgrades.duplicate()
	var steps := bonuses(game)
	for key: StringName in steps:
		levels[key] = steps[key]
	for entry_ in entries():
		if (entry_.kind == Kind.LOOK or entry_.kind == Kind.MOD) and game.secret_rewards.has(entry_.id):
			levels[entry_.level_key()] = 1
	return levels
