extends Node
## Global signal bus (autoload "Events"). Modules announce facts here instead
## of holding references to each other.

## A hit reached an exhibit. [param killed] is true when it destroyed it.
signal hit_landed(target: Node, info: DamageInfo, killed: bool)
## An exhibit was destroyed. [param finisher] = fist finisher on a stunned one.
signal enemy_destroyed(enemy: Node, info: DamageInfo, finisher: bool)
signal player_damaged(amount: float, from_position: Vector3)
signal player_died
signal weapon_fired(weapon_id: StringName)
## Asks the active camera to shake (trauma 0..1).
signal shake_requested(trauma: float)
## The guard picked up Dust motes worth [param amount].
signal dust_collected(amount: int)
## A permanent upgrade reached [param level].
signal upgrade_bought(id: StringName, level: int)
## The guard picked up his dropped flashlight and the Dust in it.
signal lantern_recovered(amount: int)
## The boss woke up (the HUD binds its health bar to boss.health).
signal boss_awakened(boss: Node)
## The boss fell (the grate opens, the demo can end).
signal boss_defeated(boss: Node)

# --- the night in the lobby (music and ambience hooks) ---
## A night began: its number and modifier (&"none", &"blackout",
## &"full_moon", &"calm"; a calm night wants quieter music).
signal night_started(night: int, modifier: StringName)
## The night's goal moved on (NightObjective.Stage as int).
signal objective_changed(stage: int)
## The fuse box has both fuses: the hall's lights die, the crystal wakes.
signal power_cut
## 3:00, the witching hour: exhibits grow faster and fiercer.
signal witching_hour
## 6:00: dawn ends the night without a fight.
signal dawn_broke

# --- Floor I: the museum floor (exploration, progress, perception) ---
## The guard walked into [param room] of [param zone] (Floor1Plan zone id);
## [param first_visit] is true the first time ever (the paper map ticks it).
signal room_entered(room: StringName, zone: StringName, first_visit: bool)
## Something made a noise at [param position] that carries [param radius]
## metres (glass, cabinets, sprint landings...). Weapon shots are heard
## through [signal weapon_fired]; the perception module maps them to radii.
signal noise_made(position: Vector3, radius: float, source: StringName)
## A door began to open at [param position] (its middle, in the wall): the
## creak carries [param radius] metres from the two rooms it joins
## ([param room_a], [param room_b]) - a point in the wall belongs to neither.
signal door_creaked(position: Vector3, radius: float, room_a: StringName, room_b: StringName)
## A gate of the floor opened for good (GateSpec id).
signal gate_opened(gate: StringName)
## A wing guardian woke up: the HUD shows its bar with its title.
signal guardian_awakened(guardian: Node, guardian_id: StringName)
## A wing guardian fell for good (it never comes back).
signal guardian_defeated(guardian_id: StringName)
## The guard picked up a guardian's seal / key (permanent).
signal seal_collected(seal: StringName)
## The guard picked up a crystal shard; [param count] = shards held now.
signal shard_collected(shard: StringName, count: int)
## The goal shown on the HUD and the map changed (a translation key).
signal goal_changed(goal_key: StringName)

# --- Floor I: weapons and gate locks ---
## A line under the crosshair for the guard (a lock hit with the wrong
## tool: "Chain - break it with something heavy"); already translated.
signal hint_requested(text: String)

# --- Floor I: the court café (plan 2026-10-10-kawiarnia-zmeczenie) ---
## The guard stepped behind the café's counter (the first time tonight).
signal cafe_entered
## He drank a coffee of [param kind] (Fatigue.COFFEES: espresso, large, special).
signal coffee_drunk(kind: StringName)
## He came behind the counter after 3:00 and found the machine gone haywire
## (the first time tonight).
signal cafe_haywire

# --- the voice: what Heniek and the System comment (plan 2026-10-19-glos-g2-kwestie) ---
## A secret of the floor was found: [param tier] of its reward
## (SecretRewards.Tier, -1 for none), [param found] secrets found so far.
signal secret_found(secret: StringName, tier: int, found: int)
## The guard's tiredness reached a new stage (Fatigue.stage(): 1 tired, 2 worn out).
signal fatigue_rose(stage: int)
## The night's clock reached a full hour: [param hour] on its face (0 = midnight ... 6).
signal hour_struck(hour: int)
