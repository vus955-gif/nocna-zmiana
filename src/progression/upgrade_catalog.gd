class_name UpgradeCatalog
## Permanent upgrades bought with Dust at a haven terminal (design section
## 3, plus section 3 of the 1.10 expansion and 8.1 of Floor I): 24 upgrades
## with 32 levels in all. Pure data; UpgradeEffects turns
## levels into numbers. Texts are translation keys UPG_<ID>_NAME and
## UPG_<ID>_DESC; categories show as CAT_GUARD or the weapon's name.


class Entry:
	var id: StringName
	## &"guard" or a weapon id (&"taser", &"pistol", &"shotgun", &"gatling",
	## &"flare", &"rifle_hunt", &"harpoon", &"hwacha").
	var category: StringName
	## Price of each level, in order.
	var prices: Array[int] = []

	func max_level() -> int:
		return prices.size()

	func name_key() -> String:
		return "UPG_%s_NAME" % String(id).to_upper()

	func desc_key() -> String:
		return "UPG_%s_DESC" % String(id).to_upper()

	## The weapon this upgrade needs (&"" for the guard's own upgrades).
	func weapon() -> StringName:
		return &"" if category == &"guard" else category


const CATEGORIES: Array[StringName] = [&"guard", &"taser", &"pistol", &"shotgun", &"gatling", &"flare",
		&"rifle_hunt", &"harpoon", &"hwacha"]

static var _entries: Array[Entry] = []


static func all() -> Array[Entry]:
	if _entries.is_empty():
		_add(&"health", &"guard", [25, 50, 90])
		_add(&"stamina", &"guard", [20, 45, 80])
		_add(&"battery", &"guard", [20, 45])
		_add(&"fists", &"guard", [25, 55])
		_add(&"taser_charge", &"taser", [40])
		_add(&"taser_chain", &"taser", [70])
		_add(&"pistol_damage", &"pistol", [50])
		_add(&"pistol_mag", &"pistol", [40])
		_add(&"shotgun_spread", &"shotgun", [50])
		_add(&"shotgun_slug", &"shotgun", [80])
		# the expansion (rozbudowa, section 3)
		_add(&"pockets", &"guard", [30, 60])
		_add(&"second_wind", &"guard", [120])
		_add(&"dust_magnet", &"guard", [25, 50])
		_add(&"keen_ear", &"guard", [40])
		_add(&"gatling_spin", &"gatling", [50])
		_add(&"gatling_belt", &"gatling", [45])
		_add(&"flare_burn", &"flare", [45])
		_add(&"flare_twin", &"flare", [70])
		# Floor I (design 8.1): the three new weapons
		_add(&"rifle_bolt", &"rifle_hunt", [60])
		_add(&"rifle_expand", &"rifle_hunt", [80])
		_add(&"harpoon_reel", &"harpoon", [55])
		_add(&"harpoon_barbs", &"harpoon", [75])
		_add(&"hwacha_fuse", &"hwacha", [60])
		_add(&"hwacha_volley", &"hwacha", [90])
	return _entries


static func find(id: StringName) -> Entry:
	for entry in all():
		if entry.id == id:
			return entry
	return null


## 0 for an unknown id.
static func max_level(id: StringName) -> int:
	var entry := find(id)
	return entry.max_level() if entry != null else 0


## Price of the next level after [param current_level]; -1 when maxed or
## unknown.
static func price(id: StringName, current_level: int) -> int:
	var entry := find(id)
	if entry == null or current_level < 0 or current_level >= entry.max_level():
		return -1
	return entry.prices[current_level]


static func category_key(category: StringName) -> String:
	return "CAT_GUARD" if category == &"guard" else "WEAPON_%s" % String(category).to_upper()


static func _add(id: StringName, category: StringName, prices: Array[int]) -> void:
	var entry := Entry.new()
	entry.id = id
	entry.category = category
	entry.prices = prices
	_entries.append(entry)
