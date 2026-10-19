class_name EnemyRoles
extends RefCounted
## The combat role and the temperament of every exhibit kind (backlog #25,
## #24): data the night director, the perception's reactions and the
## routines read. A kind's profile says
## - role: what it does in a fight (melee pressure, a tank at the door, a
##   flanker, ranged harassment, support that calls others, a swarm, a
##   turret),
## - curiosity (0..1): how readily it goes to look at a noise (0 = it only
##   turns its head: the totem, the portrait),
## - skittish (0..1): how readily it runs from a blast,
## - door (0..1): how readily it answers a door opening (the guards),
## - gathers: it comes to a fallen exhibit,
## - sleep: its routine asleep; roam: how far it wanders from its post (m;
##   0 = it keeps its post or its route).
## kind_of() names an exhibit's kind from its class (subclasses first: a
## samurai armour is not a knight, a relief lion not a wolf).

enum Role { MELEE_PRESSURE, TANK, FLANKER, RANGED, SUPPORT, SWARM, TURRET }
## Asleep: a still exhibit, one that stirs when nobody looks, one that
## rests in its tomb, in its slab, on its shelf.
enum Sleep { NONE, STIR, TOMB, SLAB, SHELF }

const DEFAULT := {"role": Role.MELEE_PRESSURE, "curiosity": 0.5, "skittish": 0.0, "door": 0.0, "gathers": false, "sleep": Sleep.NONE, "roam": 0.0}

const ROLES := {
	&"wax": {"role": Role.MELEE_PRESSURE, "curiosity": 0.6, "skittish": 0.0, "door": 0.0, "gathers": true,
			"sleep": Sleep.STIR, "roam": 0.0},
	&"wolf": {"role": Role.FLANKER, "curiosity": 0.9, "skittish": 0.5, "door": 0.0, "gathers": false,
			"sleep": Sleep.NONE, "roam": 5.0},
	&"knight": {"role": Role.TANK, "curiosity": 0.5, "skittish": 0.0, "door": 0.6, "gathers": true,
			"sleep": Sleep.NONE, "roam": 0.0},
	&"bust": {"role": Role.SUPPORT, "curiosity": 0.3, "skittish": 0.0, "door": 0.0, "gathers": false,
			"sleep": Sleep.STIR, "roam": 0.0},
	&"raptor": {"role": Role.FLANKER, "curiosity": 0.8, "skittish": 0.2, "door": 0.0, "gathers": false,
			"sleep": Sleep.NONE, "roam": 2.5},
	&"portrait": {"role": Role.RANGED, "curiosity": 0.0, "skittish": 0.0, "door": 0.0, "gathers": false,
			"sleep": Sleep.NONE, "roam": 0.0},
	&"mummy": {"role": Role.MELEE_PRESSURE, "curiosity": 0.3, "skittish": 0.0, "door": 0.0, "gathers": false,
			"sleep": Sleep.TOMB, "roam": 0.0},
	&"scarabs": {"role": Role.SWARM, "curiosity": 0.5, "skittish": 0.8, "door": 0.0, "gathers": true,
			"sleep": Sleep.NONE, "roam": 0.0},
	&"hoplite": {"role": Role.TANK, "curiosity": 0.6, "skittish": 0.0, "door": 0.4, "gathers": true,
			"sleep": Sleep.NONE, "roam": 0.0},
	&"relief_warrior": {"role": Role.RANGED, "curiosity": 0.5, "skittish": 0.0, "door": 0.0, "gathers": false,
			"sleep": Sleep.SLAB, "roam": 0.0},
	&"relief_lion": {"role": Role.FLANKER, "curiosity": 0.8, "skittish": 0.3, "door": 0.0, "gathers": false,
			"sleep": Sleep.SLAB, "roam": 0.0},
	&"books": {"role": Role.SWARM, "curiosity": 0.4, "skittish": 0.7, "door": 0.0, "gathers": false,
			"sleep": Sleep.SHELF, "roam": 0.0},
	&"totem": {"role": Role.TURRET, "curiosity": 0.0, "skittish": 0.0, "door": 0.0, "gathers": false,
			"sleep": Sleep.NONE, "roam": 0.0},
	&"jaguar": {"role": Role.FLANKER, "curiosity": 0.8, "skittish": 0.0, "door": 0.0, "gathers": false,
			"sleep": Sleep.NONE, "roam": 3.0},
	&"fu_dog": {"role": Role.TANK, "curiosity": 0.4, "skittish": 0.0, "door": 0.5, "gathers": false,
			"sleep": Sleep.NONE, "roam": 0.0},
	&"samurai_armor": {"role": Role.TANK, "curiosity": 0.5, "skittish": 0.0, "door": 0.6, "gathers": true,
			"sleep": Sleep.NONE, "roam": 0.0},
}

## Class name -> kind (subclasses are found before their bases: kind_of()
## walks up the script's inheritance).
const CLASS_KIND := {
	"WaxFigure": &"wax", "Wolf": &"wolf", "Knight": &"knight", "Bust": &"bust", "Raptor": &"raptor",
	"Portrait": &"portrait", "Mummy": &"mummy", "ScarabSwarm": &"scarabs", "Hoplite": &"hoplite",
	"ReliefWarrior": &"relief_warrior", "ReliefLion": &"relief_lion", "FlyingBook": &"books", "Totem": &"totem",
	"Jaguar": &"jaguar", "FuDog": &"fu_dog", "SamuraiArmor": &"samurai_armor",
}


## The kind of [param exhibit] by its class (or its nearest base class
## that is a kind); &"" for none.
static func kind_of(exhibit: Object) -> StringName:
	if exhibit == null:
		return &""
	var script := exhibit.get_script() as Script
	while script != null:
		var found: Variant = CLASS_KIND.get(String(script.get_global_name()))
		if found != null:
			return found
		script = script.get_base_script()
	return &""


## [param kind]'s profile (DEFAULT for an unknown kind).
static func profile(kind: StringName) -> Dictionary:
	return ROLES.get(kind, DEFAULT)


static func role(kind: StringName) -> Role:
	return profile(kind)["role"]


static func curiosity(kind: StringName) -> float:
	return profile(kind)["curiosity"]


static func skittish(kind: StringName) -> float:
	return profile(kind)["skittish"]


static func door_guard(kind: StringName) -> float:
	return profile(kind)["door"]


static func gathers(kind: StringName) -> bool:
	return profile(kind)["gathers"]


static func sleep(kind: StringName) -> Sleep:
	return profile(kind)["sleep"]


static func roam(kind: StringName) -> float:
	return profile(kind)["roam"]
