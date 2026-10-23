class_name DamageInfo
extends RefCounted
## Everything a hit carries. Created by weapons and enemy attacks and passed
## to take_damage() on the player and on exhibits.

## FIRE: the flare's blast and burning (wax takes it double, see
## ExhibitMaterial.fire_factor()).
enum Kind { BLUNT, ELECTRIC, BALLISTIC, FIRE }

var amount: float = 0.0
var kind: Kind = Kind.BLUNT
var stun_time: float = 0.0
var knockback: float = 0.0
## Direction the hit travels (attacker -> target).
var direction: Vector3 = Vector3.ZERO
var position: Vector3 = Vector3.ZERO
var normal: Vector3 = Vector3.UP
var weak_point: bool = false
## Fist hits may finish off a stunned exhibit.
var can_finish: bool = false
## Set by the target when a shield stopped the hit.
var blocked: bool = false
## Who dealt the hit (the player for weapons, the exhibit for its attacks).
var source: Node = null
## The guard's weapon that dealt it (&"shotgun", &"fists"...; &"" for
## exhibits' attacks). The chained display tells a shotgun blast by it.
var weapon: StringName = &""
## A tick of damage over time (a flare burning on its host): it shows no
## hit marker and no shield clank, only the damage.
var periodic: bool = false
## A hurt that tells the target nothing (a beam of daylight, steam): it
## takes the damage but is not alarmed - no wake, no notion of where the
## guard stands - however often it ticks.
var silent: bool = false
## False for a round fired without its impact effects (a gatling dresses
## only every other round with sparks: fourteen bursts a second would cost
## more than they show).
var effects: bool = true
## A blast's hit (the flare's, a fire-arrow's): boarded doors and cracked
## walls give way to explosions.
var explosive: bool = false
## Where the shot came from (the muzzle when it was fired; INF = unknown):
## a rope lock takes a pistol shot only from close by, a cracked wall
## counts flares fired at point blank.
var origin: Vector3 = Vector3.INF
## A round that snaps a chain link or a board by itself (the rifle with the
## secrets' peep sight: WeaponData.lock_breaker; LockRules).
var lock_breaker: bool = false
## How heavy the hit lands, 0..1 (HitFeel: a flinch, a stagger, a kill that
## crumbles or is blown apart): the guard's weapons set it from their
## FeelProfile (a shotgun's pellets each add their share); 0 = unknown,
## HitFeel.weight() works it out from the weapon or the damage.
var impact: float = 0.0


static func make(amount_: float, kind_: Kind, source_: Node = null) -> DamageInfo:
	var info := DamageInfo.new()
	info.amount = amount_
	info.kind = kind_
	info.source = source_
	return info
