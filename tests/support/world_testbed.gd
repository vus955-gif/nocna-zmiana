class_name WorldTestbed
extends Node3D
## The built lobby with a guard and its world content (LobbyFeatures), for
## the world tests and the world scenario. Stands in for the Museum: it has
## the [member player] the features look for, and optionally the HUD.

var level: LobbyLevel
var player: Player
var hud: Hud
var features: LobbyFeatures


## Builds the lobby for [param config] (night 1 of seed 1 when null), puts
## the guard on the security room chair and installs the world content.
func setup(config: NightConfig = null, with_hud: bool = false) -> void:
	level = LobbyLevel.new()
	level.name = "Lobby"
	level.night = config if config != null else NightDirector.plan(1, 1, LobbyLayout.describe(LobbyLayout.create()))
	add_child(level)
	level.build()
	player = Player.new()
	player.name = "Guard"
	add_child(player)
	var start := level.player_start
	player.respawn(start.origin, start.basis.get_euler().y)
	if with_hud:
		hud = Hud.new()
		hud.player = player
		hud.show_dust = true
		hud.night = config.night if config != null else 1
		add_child(hud)
		hud.hide_help()
	features = LobbyFeatures.install(level, self)


## Stands the guard at [param at] (feet) looking at [param target].
func place_guard(at: Vector3, target: Vector3) -> void:
	var eye := at + Vector3.UP * player.eye_height
	var to := target - eye
	var yaw := atan2(-to.x, -to.z)
	var pitch := atan2(to.y, Vector2(to.x, to.z).length())
	player.respawn(at, yaw)
	player.head.rotation.x = pitch


## Night [param night_number] of the first seed whose draw passes
## [param wanted] (a Callable taking the NightConfig), or null.
static func find_night(night_number: int, wanted: Callable, tries: int = 400) -> NightConfig:
	var description := LobbyLayout.describe(LobbyLayout.create())
	for night_seed in tries:
		var config := NightDirector.plan(night_seed, night_number, description)
		if wanted.call(config):
			return config
	return null
