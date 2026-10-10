class_name DifficultyRules
## The difficulty option (design 7.5), as numbers: "Spokojna zmiana"
## (calm), "Nocna zmiana" (night, the default), "Podwójna zmiana" (double).
## Sight and the hunter cap live in PerceptionWorld.set_difficulty(index);
## here: the exhibits' damage and health (set before they enter the tree)
## and how much loot a night draws. Pure: the difficulty id is passed in.

const IDS: Array[StringName] = [&"calm", &"night", &"double"]
## Exhibits' attack damage and health, by index.
const DAMAGE: Array[float] = [0.6, 1.0, 1.35]
const HEALTH: Array[float] = [1.0, 1.0, 1.2]
## How much of the loot draw stays (more than all = extra spots filled).
const LOOT: Array[float] = [1.3, 1.0, 0.75]


## 0 calm, 1 night (also for an unknown id), 2 double.
static func index(difficulty: StringName) -> int:
	var found := IDS.find(difficulty)
	return found if found >= 0 else 1


## Tonight's exhibit stats for [param difficulty]: call before the exhibit
## enters the tree (after the night modifier's tuning).
static func tune(exhibit: Enemy, difficulty: StringName) -> void:
	var i := index(difficulty)
	exhibit.attack_damage *= DAMAGE[i]
	exhibit.max_health *= HEALTH[i]


static func loot_scale(difficulty: StringName) -> float:
	return LOOT[index(difficulty)]


## A wing guardian's health and damage (Guardian.damage_scale) for
## [param difficulty] (before it enters the tree).
static func tune_guardian(guardian: Node, difficulty: StringName) -> void:
	var health: Variant = guardian.get(&"max_health")
	if health is float:
		guardian.set(&"max_health", float(health) * HEALTH[index(difficulty)])
	if guardian.get(&"damage_scale") is float:
		guardian.set(&"damage_scale", DAMAGE[index(difficulty)])
