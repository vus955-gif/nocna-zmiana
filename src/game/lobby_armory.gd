class_name LobbyArmory
extends Node3D
## The weapons to find in the lobby, except the pistol (the till drawer's
## key and the booth's gun locker are the world content's, LobbyFeatures):
## - the shotgun (design 2b) waits in the niche behind the armory's plaque
##   wall until taken,
## - the gatling stands chained on its plinth in the armory (marker
##   gatling_display): a shotgun blast or three punches break the chain,
## - the flare gun hangs in the fire cabinet on the diorama's wall (marker
##   flare_cabinet): smashing the glass wakes the wolves nearby.
## Once taken a weapon is the guard's for good (GameState, saved at once);
## a broken chain or glass stays broken for the night (RunState.used).

## In front of the niche's display case (its glass box is solid).
const SHOTGUN_OFFSET := 0.75
const SHOTGUN_HEIGHT := 0.7

var museum: Museum
var shotgun: WeaponPickup = null
var display: ChainedDisplay = null
var cabinet: EmergencyCabinet = null


## Places the shotgun on [param for_museum]'s lobby unless it is found.
func setup(for_museum: Museum) -> void:
	museum = for_museum
	name = "Armory"
	var markers := museum.lobby.markers
	if not museum.game.has_weapon(&"shotgun") and markers.has(&"shotgun_case"):
		var case: Transform3D = markers[&"shotgun_case"]
		var front := -case.basis.z
		shotgun = WeaponPickup.make(&"shotgun", Vector3(case.origin.x, SHOTGUN_HEIGHT, case.origin.z) + front * SHOTGUN_OFFSET)
		shotgun.game = museum.game
		shotgun.run = museum.run
		add_child(shotgun)
	if markers.has(&"gatling_display"):
		display = ChainedDisplay.create(markers[&"gatling_display"])
		# its plinth is an obstacle the exhibits walk around: a navigation source
		museum.lobby.walk_region.add_child(display)
		museum.lobby.navigation.request_rebake()
	if markers.has(&"flare_cabinet"):
		cabinet = EmergencyCabinet.create(markers[&"flare_cabinet"])
		add_child(cabinet)
