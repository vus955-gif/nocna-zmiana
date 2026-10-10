extends GuardianStub
## A greybox guardian whose script dresses its arena (GuardianKeeper calls
## the static dress_arena() of a guardian's script, even after its fall),
## and records the hit zone of every hit it takes.

var zones_hit: Array[StringName] = []


static func dress_arena(level: MuseumFloorLevel, parent: Node3D) -> Array[Node3D]:
	var prop := Node3D.new()
	prop.name = "ArenaProp"
	parent.add_child(prop)
	prop.global_transform = level.markers[&"guardian_colossus"]
	return [prop]


func _damage_factor(_info: DamageInfo) -> float:
	zones_hit.append(hit_zone)
	return 1.0
