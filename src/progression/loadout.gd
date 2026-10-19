class_name Loadout
## The guard's kit when a night starts: fists and the taser (always), every
## weapon found so far (GameState.weapons, stored by id), upgrades applied,
## and the design's starting ammo: a full magazine plus START_RESERVE
## (deep pockets add their share: UpgradeEffects.spare_ammo).

const WEAPON_PATHS := {
	&"taser": "res://src/weapons/data/taser.tres",
	&"pistol": "res://src/weapons/data/pistol.tres",
	&"shotgun": "res://src/weapons/data/shotgun.tres",
	&"gatling": "res://src/weapons/data/gatling.tres",
	&"flare": "res://src/weapons/data/flare.tres",
	&"rifle_hunt": "res://src/weapons/data/rifle_hunt.tres",
	&"harpoon": "res://src/weapons/data/harpoon.tres",
	&"hwacha": "res://src/weapons/data/hwacha.tres",
}
## Carried from the first night on (the fists live in the WeaponHolder).
const ALWAYS: Array[StringName] = [&"taser"]
## Reserve ammo at the start of a night (the magazine starts full).
const START_RESERVE := {&"pistol": 24, &"shotgun": 6, &"gatling": 60, &"flare": 4,
		&"rifle_hunt": 25, &"harpoon": 12, &"hwacha": 6}
## The weapon in hand at the start, best first.
const PREFERRED: Array[StringName] = [&"pistol", &"taser"]


static func equip_night_start(player: Player, game: PersistentState) -> void:
	player.apply_upgrades(SecretRewards.effective_levels(game))
	for id in ALWAYS:
		grant(player, id, game)
	for id in game.weapons:
		grant(player, id, game)
	for id in PREFERRED:
		if player.weapons.has_weapon(id):
			player.weapons.select_id(id)
			break
	player.refill()


## Gives weapon [param id] with starting ammo. Returns its state (null for
## an unknown id).
static func grant(player: Player, id: StringName, _game: PersistentState) -> WeaponState:
	var path: String = WEAPON_PATHS.get(id, "")
	if path == "":
		return null
	var had := player.weapons.has_weapon(id)
	var state := player.weapons.give(load(path))
	if not had and START_RESERVE.has(id):
		state.magazine = state.data.magazine_size
		state.reserve = mini(UpgradeEffects.spare_ammo(START_RESERVE[id], player.weapons.upgrade_levels), state.data.max_reserve)
	return state
