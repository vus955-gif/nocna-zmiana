class_name NightWatch
extends Node
## Runs the night's clock (NightClock) in the game: shows it on the HUD,
## stands it still in a haven (up to a minute a visit) and while any menu
## pauses the game, rings the witching hour at 3:00 (exhibits +20% speed
## and damage from then on, Events.witching_hour for the music) and calls
## dawn at 6:00 ([signal dawn]). It stops for good once the boss is beaten
## (that ends the demo whatever the hour). A resumed night keeps its time
## (a "clock_<seconds>" entry in RunState.used, saved with the night).

signal witching
signal dawn

const WITCHING_BOOST := 1.2
const SAVE_PREFIX := "clock_"

var museum: Museum
var clock := NightClock.new()
var running: bool = true


func setup(for_museum: Museum) -> void:
	museum = for_museum
	name = "NightWatch"
	clock.elapsed = restored_time(museum.run)
	museum.hud.set_clock(clock.text())
	if clock.is_witching():
		for exhibit in museum.exhibits():
			boost(exhibit)
		Events.witching_hour.emit()   # resumed past 3:00: the music keeps its witching layer


## Seconds of the night a resumed night had counted (0 for a fresh one).
static func restored_time(run: NightState) -> float:
	for id in run.used:
		var text := String(id)
		if text.begins_with(SAVE_PREFIX) and text.trim_prefix(SAVE_PREFIX).is_valid_int():
			return clampf(float(text.trim_prefix(SAVE_PREFIX).to_int()), 0.0, NightClock.seconds_to_dawn() - 1.0)
	return 0.0


## Puts the clock into [param run] for the save (one entry, replaced).
func save_into(run: NightState) -> void:
	for id in run.used.duplicate():
		if String(id).begins_with(SAVE_PREFIX):
			run.used.erase(id)
	run.mark_used(StringName("%s%d" % [SAVE_PREFIX, int(clock.elapsed)]))


## The witching hour's strength for one exhibit (once).
static func boost(exhibit: Enemy) -> void:
	if exhibit.has_meta(&"witching"):
		return
	exhibit.set_meta(&"witching", true)
	exhibit.move_speed *= WITCHING_BOOST
	exhibit.attack_damage *= WITCHING_BOOST


func _process(delta: float) -> void:
	if not running or museum == null or not is_instance_valid(museum.player):
		return
	if museum.objective != null and museum.objective.stage >= NightObjective.Stage.DESCEND:
		running = false   # the boss is beaten: that ends the night, not dawn
		return
	if not museum.player.alive:
		return
	var crossed := clock.advance(delta, Haven.shelters(museum.player.global_position))
	museum.hud.set_clock(clock.text())
	if crossed.has(&"witching"):
		_ring_the_witching_hour()
	if crossed.has(&"dawn"):
		running = false
		dawn.emit()


func _ring_the_witching_hour() -> void:
	for exhibit in museum.exhibits():
		boost(exhibit)
	Sfx.play(&"witching_bell")
	museum.hud.show_card(clock.text(), tr("NIGHT_WITCHING"), tr("NIGHT_WITCHING_DETAIL"))
	witching.emit()
	Events.witching_hour.emit()
