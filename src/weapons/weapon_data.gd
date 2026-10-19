class_name WeaponData
extends Resource
## Tunable numbers for one weapon. Upgrades change per-owner copies (see
## WeaponState and UpgradeEffects); the .tres files never change in play.

enum AmmoMode { NONE, BATTERY, MAGAZINE }

@export var id: StringName = &""
@export var display_name: String = ""
@export var damage: float = 10.0
@export var damage_kind: DamageInfo.Kind = DamageInfo.Kind.BALLISTIC
## Rays per shot (shotgun pellets).
@export var pellets: int = 1
## Half-angle of the random cone, in degrees.
@export var spread_deg: float = 0.0
@export var max_range: float = 100.0
## Seconds between shots.
@export var cooldown: float = 0.3
@export var stun_time: float = 0.0
## Push per ray that hits (pellets add up).
@export var knockback: float = 0.0
@export var weak_point_multiplier: float = 1.0
@export var can_finish: bool = false
## > 0 turns the attack into a sphere sweep of this radius (fists).
@export var melee_radius: float = 0.0
## > 0: an electric hit jumps on to the nearest other target within this
## many metres (taser upgrade).
@export var chain_range: float = 0.0

@export_group("Ammo")
@export var ammo_mode: AmmoMode = AmmoMode.NONE
## Pickups with this type refill the reserve.
@export var ammo_type: StringName = &""
@export var magazine_size: int = 0
@export var reload_time: float = 0.0
@export var start_reserve: int = 0
@export var max_reserve: int = 0
@export var battery_max: float = 0.0
@export var battery_cost: float = 0.0
@export var battery_recharge_per_sec: float = 0.0
@export var battery_recharge_delay: float = 0.0

@export_group("Feel")
## The shot's sound. How the weapon kicks, shakes, flashes and lands is its
## FeelProfile (res://src/weapons/feel/<id>.tres).
@export var sound: StringName = &""
## Draw a tracer for every n-th round only (a gatling burst would read as
## a solid beam otherwise).
@export var tracer_every: int = 1
## Dress only every n-th round with its impact sparks, bullet hole and
## muzzle light (fourteen bursts a second would cost more than they show).
@export var effects_every: int = 1

@export_group("Crank and belt")
## > 0: barrels must spin up this long (s) before the first shot (gatling).
@export var spin_up_time: float = 0.0
## After letting go the barrels keep turning this long (s); a new pull in
## that time fires at once, after it they stop.
@export var spin_down_time: float = 0.0
## > spread_deg: a long burst opens the cone up to this half-angle...
@export var spread_max_deg: float = 0.0
## ... after this many seconds of continuous fire.
@export var spread_growth_time: float = 1.0
## The magazine is a belt fed from the reserve: no reload (R does
## nothing), an empty box pulls the next belt in by itself...
@export var belt_feed: bool = false
## ... which takes this long (s; 0 = at once), no shots meanwhile.
@export var belt_change_time: float = 0.0
## Walking speed while the trigger is held (1 = no penalty); below 1 the
## guard cannot sprint either.
@export var firing_move_factor: float = 1.0

@export_group("Projectile")
## > 0 fires a flare instead of rays (m/s).
@export var projectile_speed: float = 0.0
@export var projectile_gravity: float = 0.0
## Blast around the impact (damage = [member damage]).
@export var blast_radius: float = 0.0
## Burning on the exhibit it sticks to.
@export var burn_dps: float = 0.0
@export var burn_time: float = 0.0
## Seconds the stuck flare lights its surroundings.
@export var light_time: float = 0.0

@export_group("Alternate load")
## > 0 enables a second load (shotgun slugs): rays per shot.
@export var alt_pellets: int = 0
@export var alt_damage: float = 0.0
@export var alt_spread_deg: float = 0.0
@export var alt_weak_point_multiplier: float = 1.0

@export_group("Pierce")
## A ray goes on through this many targets (1 = it stops at the first);
## each target is hit once, by the first of its zones the ray crosses.
@export var pierce_targets: int = 1
## A round that snaps a chain link or a board on its own (the rifle with
## the secrets' peep sight; DamageInfo.lock_breaker, LockRules).
@export var lock_breaker: bool = false

@export_group("Projectile kind")
## Which projectile a projectile weapon (projectile_speed > 0) fires:
## &"flare", &"harpoon" or &"rocket".
@export var projectile: StringName = &"flare"
## Damage of the blast round the impact when it differs from the direct
## hit (0 = the blast deals [member damage]).
@export var blast_damage: float = 0.0

@export_group("Volley")
## > 1: one shot launches this many projectiles, volley_interval seconds
## apart, fanned out evenly across volley_spread_deg (the whole fan).
@export var volley_count: int = 0
@export var volley_spread_deg: float = 0.0
@export var volley_interval: float = 0.0

@export_group("Harpoon")
## A light exhibit (max health at most this) with a wall within pin_reach
## metres behind it is pinned to that wall (and breaks there).
@export var pin_max_health: float = 0.0
@export var pin_reach: float = 0.0
## A medium exhibit is pulled this many metres toward the guard and
## stunned for pull_stun seconds.
@export var pull_distance: float = 0.0
@export var pull_stun: float = 0.0
## Above this max health (or with a knockback resistance of at least
## HarpoonRules.HEAVY_RESIST) an exhibit is heavy: damage only.
@export var heavy_health: float = 150.0
## A harpoon stuck in a wall (a miss) is reeled back to the reserve (the
## secrets' return line; Harpoon.RETURN_TIME).
@export var line_return: bool = false
