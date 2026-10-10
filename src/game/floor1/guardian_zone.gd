class_name GuardianZone
extends Node
## Receives the hits of one hit zone of a guardian (its weak point, its
## armour, a plate...) and passes them on with the zone's name
## (Guardian.take_zone_damage). Weapons merge the pellets of a shot per
## receiver, so each zone needs a receiver of its own: a shotgun blast that
## hits both the Colossus's crown and its uraeus arrives as two hits, each
## with its own rule. Hurtboxes of the zone point here
## (Hurtbox.make(zone, ...)); the zone node lives under the guardian.

var guardian: Guardian = null
var zone: StringName = &""


static func make(guardian_: Guardian, zone_: StringName) -> GuardianZone:
	var receiver := GuardianZone.new()
	receiver.guardian = guardian_
	receiver.zone = zone_
	receiver.name = "Zone_" + String(zone_)
	return receiver


func take_damage(info: DamageInfo) -> void:
	if is_instance_valid(guardian):
		guardian.take_zone_damage(info, zone)
