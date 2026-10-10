class_name TRexZone
extends Node
## Receives the hits of one hit zone of the T-Rex (the crystal, or all the
## bones) and passes them to the boss. Weapons merge pellets per receiver,
## so the zones need receivers of their own: a shotgun blast that hits both
## ribs and crystal then arrives as two hits, each with its own rule.

var boss: Node = null
var zone: TRexBrain.Zone = TRexBrain.Zone.BONE


static func make(boss_: Node, zone_: TRexBrain.Zone) -> TRexZone:
	var receiver := TRexZone.new()
	receiver.boss = boss_
	receiver.zone = zone_
	receiver.name = "CrystalZone" if zone_ == TRexBrain.Zone.CRYSTAL else "BoneZone"
	return receiver


func take_damage(info: DamageInfo) -> void:
	if is_instance_valid(boss):
		boss.take_zone_damage(info, zone)
