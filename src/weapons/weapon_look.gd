class_name WeaponLook
## The owner's idea (design 7.1a): every level of every weapon upgrade
## shows on the first-person model, and a weapon with all its upgrades at
## the top level gets the master finish. Pure data and logic: which named
## parts of a vm_* model (Blender parts "upg_*" and the base parts they
## replace) are shown for given upgrade levels (GameState.upgrades: id ->
## level), and when a weapon counts as mastered. ViewmodelRig.apply_look()
## turns this into visible parts and materials.
##
## Rule for every future weapon upgrade: give it a row here, one entry per
## level, each switching on at least one part (tests enforce it).

## Upgrade id -> one entry per level (level 1 first): parts it shows and
## base parts it hides (a lighter bolt knob replaces the plain one).
const UPGRADES := {
	&"fists": [{"show": ["upg_wraps_l", "upg_wraps_r"]}, {"show": ["upg_knuckles_l", "upg_knuckles_r"]}],
	&"taser_charge": [{"show": ["upg_coil"]}],
	&"taser_chain": [{"show": ["upg_prongs"]}],
	&"pistol_damage": [{"show": ["upg_inlay"]}],
	&"pistol_mag": [{"show": ["upg_mag"]}],
	&"shotgun_spread": [{"show": ["upg_choke"]}],
	&"shotgun_slug": [{"show": ["upg_slug_holder"]}],
	&"gatling_spin": [{"show": ["upg_crank"]}],
	&"gatling_belt": [{"show": ["upg_drum"]}],
	&"flare_burn": [{"show": ["upg_shroud"]}],
	&"flare_twin": [{"show": ["upg_barrel2"]}],
	&"rifle_bolt": [{"show": ["upg_bolt_ball"], "hide": ["bolt_knob"]}],
	&"rifle_expand": [{"show": ["upg_fittings"]}],
	&"harpoon_reel": [{"show": ["upg_reel"]}],
	&"harpoon_barbs": [{"show": ["upg_barbs"]}],
	&"hwacha_fuse": [{"show": ["upg_fuses"]}],
	&"hwacha_volley": [{"show": ["upg_box9"]}],
}

## Weapon id (the fists' view is &"fist") -> the parts that glow softly in
## the master finish (its signature).
const SIGNATURE := {
	&"fist": ["upg_knuckles_l", "upg_knuckles_r"],
	&"taser": ["upg_coil"],
	&"pistol": ["upg_inlay"],
	&"shotgun": ["upg_choke"],
	&"gatling": ["upg_crank"],
	&"flare": ["upg_shroud"],
	&"rifle_hunt": ["upg_bolt_ball"],
	&"harpoon": ["head"],
	&"hwacha": ["upg_fuses"],
}

## Prefix of every upgrade part in the models.
const PART_PREFIX := "upg_"
## Keys of a secret's finish ("look_<weapon>_<id>") and mod ("mod_<id>")
## among the guard's upgrade levels (SecretRewards.effective_levels).
const LOOK_PREFIX := "look_"
const MOD_PREFIX := "mod_"
## The warm gold of the master finish (sheen and signature glow).
const MASTER_COLOR := Color(1.0, 0.74, 0.38)

## The secrets' unique finishes (SecretRewards, GREAT tier): one per weapon.
## A finish is a material layer over the model (ViewmodelRig.look_material):
## "tint" multiplies the albedo, "roughness" scales it, "metallic" is a
## floor, "accent" lights the signature part and tints the rim. A baked
## texture set "<model>_<look>" takes over when the art has one.
const LOOKS := {
	&"faience": {"weapon": &"shotgun", "tint": Color(0.55, 0.85, 0.85), "roughness": 0.6, "metallic": 0.1, "accent": Color(1.0, 0.8, 0.35)},
	&"founder": {"weapon": &"pistol", "tint": Color(0.5, 0.47, 0.47), "roughness": 0.7, "metallic": 0.2, "accent": Color(0.9, 0.93, 1.0)},
	&"warden": {"weapon": &"taser", "tint": Color(0.75, 0.72, 0.5), "roughness": 1.0, "metallic": 0.0, "accent": Color(0.6, 1.0, 0.5)},
	&"signal": {"weapon": &"flare", "tint": Color(1.0, 0.62, 0.3), "roughness": 0.6, "metallic": 0.0, "accent": Color(0.95, 0.75, 0.35)},
	&"balawat": {"weapon": &"gatling", "tint": Color(0.85, 0.65, 0.4), "roughness": 0.8, "metallic": 0.2, "accent": Color(0.3, 0.45, 1.0)},
	&"sloane": {"weapon": &"rifle_hunt", "tint": Color(0.8, 0.55, 0.45), "roughness": 0.7, "metallic": 0.0, "accent": Color(0.95, 0.75, 0.35)},
	&"lacquer": {"weapon": &"hwacha", "tint": Color(0.85, 0.3, 0.25), "roughness": 0.5, "metallic": 0.0, "accent": Color(1.0, 0.8, 0.35)},
	&"scrimshaw": {"weapon": &"harpoon", "tint": Color(0.95, 0.92, 0.82), "roughness": 0.9, "metallic": 0.0, "accent": Color(0.2, 0.78, 0.85)},
}

## The secrets' mods (SecretRewards, GREAT tier; their numbers:
## UpgradeEffects.apply_to_weapon): the part each puts on the first-person
## model (built by ViewmodelRig, named "mod_<id>").
const MODS := {
	&"shotgun_choke": {"weapon": &"shotgun", "part": "mod_shotgun_choke"},
	&"rifle_peep": {"weapon": &"rifle_hunt", "part": "mod_rifle_peep"},
	&"harpoon_line": {"weapon": &"harpoon", "part": "mod_harpoon_line"},
}


## The upgrades of weapon [param weapon] (its catalog category; the fists
## are the guard's "fists" upgrade). [param weapon] may be the view's id
## (&"fist") or the weapon's (&"fists").
static func upgrades_of(weapon: StringName) -> Array[StringName]:
	var out: Array[StringName] = []
	if weapon == &"fist" or weapon == &"fists":
		out.append(&"fists")
		return out
	for entry in UpgradeCatalog.all():
		if entry.category == weapon:
			out.append(entry.id)
	return out


## Every upgrade part of [param weapon]'s model (all levels).
static func all_parts(weapon: StringName) -> PackedStringArray:
	var out := PackedStringArray()
	for id in upgrades_of(weapon):
		for step: Dictionary in UPGRADES.get(id, []):
			for part: String in step.get("show", []):
				if not out.has(part):
					out.append(part)
	return out


## The upgrade parts shown at [param levels] (every level up to the bought
## one keeps its parts: brass knuckles go over the wraps).
static func shown_parts(weapon: StringName, levels: Dictionary) -> PackedStringArray:
	var out := PackedStringArray()
	for id in upgrades_of(weapon):
		var steps: Array = UPGRADES.get(id, [])
		for i in mini(UpgradeEffects.level(levels, id), steps.size()):
			for part: String in (steps[i] as Dictionary).get("show", []):
				if not out.has(part):
					out.append(part)
	return out


## The parts hidden at [param levels]: upgrade parts not bought yet and
## base parts an upgrade replaced.
static func hidden_parts(weapon: StringName, levels: Dictionary) -> PackedStringArray:
	var shown := shown_parts(weapon, levels)
	var out := PackedStringArray()
	for part in all_parts(weapon):
		if not shown.has(part):
			out.append(part)
	for id in upgrades_of(weapon):
		var steps: Array = UPGRADES.get(id, [])
		for i in mini(UpgradeEffects.level(levels, id), steps.size()):
			for part: String in (steps[i] as Dictionary).get("hide", []):
				if not out.has(part):
					out.append(part)
	return out


## Base parts some upgrade may hide (shown again when it is not bought).
static func replaceable_parts(weapon: StringName) -> PackedStringArray:
	var out := PackedStringArray()
	for id in upgrades_of(weapon):
		for step: Dictionary in UPGRADES.get(id, []):
			for part: String in step.get("hide", []):
				if not out.has(part):
					out.append(part)
	return out


## True when every upgrade of [param weapon] is at its top level.
static func mastered(weapon: StringName, levels: Dictionary) -> bool:
	var ids := upgrades_of(weapon)
	if ids.is_empty():
		return false
	for id in ids:
		if UpgradeEffects.level(levels, id) < UpgradeCatalog.max_level(id):
			return false
	return true


## A short signature of the look (the levels of the weapon's upgrades, its
## finish and its mods): when it changes the guard gets to look his weapon
## over.
static func key(weapon: StringName, levels: Dictionary) -> String:
	var parts := PackedStringArray()
	for id in upgrades_of(weapon):
		parts.append("%s=%d" % [id, UpgradeEffects.level(levels, id)])
	var look := look_of(weapon, levels)
	if look != &"":
		parts.append("look=" + String(look))
	for mod in mods_of(weapon, levels):
		parts.append("mod=" + String(mod))
	return ",".join(parts)


## The weapon id of a view id (the fists' view is &"fist").
static func weapon_of_view(weapon: StringName) -> StringName:
	return &"fists" if weapon == &"fist" else weapon


static func look_key(weapon: StringName, look: StringName) -> StringName:
	return StringName(LOOK_PREFIX + String(weapon) + "_" + String(look))


static func mod_key(mod: StringName) -> StringName:
	return StringName(MOD_PREFIX + String(mod))


## The finish of [param weapon] among [param levels] (a LOOKS id), or &"".
static func look_of(weapon: StringName, levels: Dictionary) -> StringName:
	var owner := weapon_of_view(weapon)
	for look: StringName in LOOKS:
		if (LOOKS[look] as Dictionary)["weapon"] == owner and int(levels.get(look_key(owner, look), 0)) > 0:
			return look
	return &""


## The mods of [param weapon] among [param levels] (MODS ids, table order).
static func mods_of(weapon: StringName, levels: Dictionary) -> Array[StringName]:
	var owner := weapon_of_view(weapon)
	var out: Array[StringName] = []
	for mod: StringName in MODS:
		if (MODS[mod] as Dictionary)["weapon"] == owner and int(levels.get(mod_key(mod), 0)) > 0:
			out.append(mod)
	return out
