class_name UpgradeEffects
## Turns upgrade levels (GameState.upgrades: id -> level) into the guard's
## numbers and into changes on per-owner WeaponData copies. The shared
## .tres resources are never touched: apply_to_weapon() gets a copy.

const BASE_HEALTH := 100.0
const BASE_STAMINA := 100.0
const BASE_STAMINA_REGEN := 30.0
const BASE_FINISHER_HEAL := 15.0
const TASER_CHARGE_FACTOR := 1.6
const TASER_CHAIN_RANGE := 5.0
const PISTOL_DAMAGE_FACTOR := 1.3
const PISTOL_MAGAZINE := 18
const SHOTGUN_SPREAD_FACTOR := 0.65
const SLUG_DAMAGE := 70.0
const SLUG_WEAK_POINT := 2.0
## A slug pushes like this many pellets.
const SLUG_KNOCKBACK_PELLETS := 6.0


## Deep pockets: every weapon's reserve cap grows by this much per level.
const POCKETS_STEP := 0.25
## Dust magnet: the pull reaches this much further per level.
const DUST_MAGNET_STEP := 3.0
## Second wind: seconds of invulnerability after the saving blow.
const SECOND_WIND_GRACE := 1.0
const GATLING_SPIN_UP := 0.2
const GATLING_BELT := 200
const FLARE_BURN_TIME := 8.0
const FLARE_LIGHT_TIME := 20.0
const FLARE_TWIN_BARREL := 2
## Floor I (design 8.1).
const RIFLE_BOLT_CYCLE := 0.7
const RIFLE_EXPAND_WEAK_POINT := 4.0
const HARPOON_REEL_RELOAD := 0.7
const HARPOON_BARBS_PIN := 90.0
const HWACHA_FUSE_RELOAD := 1.5
const HWACHA_VOLLEY := 9


## Bought level of [param id], kept within the catalog's range.
static func level(levels: Dictionary, id: StringName) -> int:
	return clampi(int(levels.get(id, 0)), 0, UpgradeCatalog.max_level(id))


static func max_health(levels: Dictionary) -> float:
	return BASE_HEALTH + 20.0 * level(levels, &"health")


static func stamina_max(levels: Dictionary) -> float:
	return BASE_STAMINA + 20.0 * level(levels, &"stamina")


static func stamina_regen(levels: Dictionary) -> float:
	return BASE_STAMINA_REGEN * (1.0 + 0.15 * level(levels, &"stamina"))


## Seconds of flashlight on a full battery.
static func battery_capacity(levels: Dictionary) -> float:
	return FlashlightBattery.BASE_CAPACITY * (1.0 + 0.5 * level(levels, &"battery"))


static func fist_damage_multiplier(levels: Dictionary) -> float:
	return 1.0 + 0.4 * level(levels, &"fists")


static func finisher_heal(levels: Dictionary) -> float:
	return BASE_FINISHER_HEAL * (1.0 + 0.25 * level(levels, &"fists"))


## Reserve multiplier of every weapon (deep pockets): its cap, the spare
## ammo it starts a night with and every ammo box picked up.
static func reserve_factor(levels: Dictionary) -> float:
	return 1.0 + POCKETS_STEP * level(levels, &"pockets")


## [param amount] rounds of spare ammo (a night's start, a box picked up)
## as deep pockets make it (rounded).
static func spare_ammo(amount: int, levels: Dictionary) -> int:
	return roundi(amount * reserve_factor(levels))


## How far Dust flies to the guard (6 -> 9 -> 12 m).
static func dust_magnet_radius(levels: Dictionary) -> float:
	return DustMote.MAGNET_RADIUS + DUST_MAGNET_STEP * level(levels, &"dust_magnet")


static func has_second_wind(levels: Dictionary) -> bool:
	return level(levels, &"second_wind") > 0


static func has_keen_ear(levels: Dictionary) -> bool:
	return level(levels, &"keen_ear") > 0


## Applies every upgrade of this weapon to [param data] (a copy).
static func apply_to_weapon(data: WeaponData, levels: Dictionary) -> void:
	if data.max_reserve > 0:
		data.max_reserve = roundi(data.max_reserve * reserve_factor(levels))
	match data.id:
		&"fists":
			data.damage *= fist_damage_multiplier(levels)
		&"taser":
			if level(levels, &"taser_charge") > 0:
				data.battery_recharge_per_sec *= TASER_CHARGE_FACTOR
			if level(levels, &"taser_chain") > 0:
				data.chain_range = TASER_CHAIN_RANGE
		&"pistol":
			if level(levels, &"pistol_damage") > 0:
				data.damage *= PISTOL_DAMAGE_FACTOR
			if level(levels, &"pistol_mag") > 0:
				data.magazine_size = PISTOL_MAGAZINE
		&"shotgun":
			if level(levels, &"shotgun_spread") > 0:
				data.spread_deg *= SHOTGUN_SPREAD_FACTOR
			if level(levels, &"shotgun_slug") > 0:
				data.alt_pellets = 1
				data.alt_damage = SLUG_DAMAGE
				data.alt_spread_deg = 0.0
				data.alt_weak_point_multiplier = SLUG_WEAK_POINT
		&"gatling":
			if level(levels, &"gatling_spin") > 0:
				data.spin_up_time = GATLING_SPIN_UP
			if level(levels, &"gatling_belt") > 0:
				data.magazine_size = GATLING_BELT
				data.belt_change_time = 0.0   # the long belt feeds the next one without a pause
		&"flare":
			if level(levels, &"flare_burn") > 0:
				data.burn_time = FLARE_BURN_TIME
				data.light_time = FLARE_LIGHT_TIME
			if level(levels, &"flare_twin") > 0:
				data.magazine_size = FLARE_TWIN_BARREL
		&"rifle_hunt":
			if level(levels, &"rifle_bolt") > 0:
				data.cooldown = RIFLE_BOLT_CYCLE
			if level(levels, &"rifle_expand") > 0:
				data.weak_point_multiplier = RIFLE_EXPAND_WEAK_POINT
		&"harpoon":
			if level(levels, &"harpoon_reel") > 0:
				data.reload_time = HARPOON_REEL_RELOAD
			if level(levels, &"harpoon_barbs") > 0:
				data.pin_max_health = HARPOON_BARBS_PIN
		&"hwacha":
			if level(levels, &"hwacha_fuse") > 0:
				data.reload_time = HWACHA_FUSE_RELOAD
			if level(levels, &"hwacha_volley") > 0:
				data.volley_count = HWACHA_VOLLEY


## The alternate load (slugs) as its own shot data; null when the weapon has
## none.
static func alt_profile(data: WeaponData) -> WeaponData:
	if data.alt_pellets <= 0:
		return null
	var alt := data.duplicate() as WeaponData
	alt.pellets = data.alt_pellets
	alt.damage = data.alt_damage
	alt.spread_deg = data.alt_spread_deg
	alt.weak_point_multiplier = data.alt_weak_point_multiplier
	alt.knockback = data.knockback * SLUG_KNOCKBACK_PELLETS
	return alt
