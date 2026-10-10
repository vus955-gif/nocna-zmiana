class_name BookRig
extends ExhibitRig
## The flying book (model "flying_book": spine "body", covers "cover_l" /
## "cover_r" hinged about the spine's Y axis, a fan of loose "pages"; the
## eyes are painted on the spread). It flies open like a maw:
## - the covers beat as wings round their rest (55 degrees open): faster
##   and wider while it climbs, hard and wide pulling up after a dive;
##   each beat lifts the body a little,
## - the telegraph: the covers spread flat (the eyes on the spread stare
##   at the guard), trembling, the pages riffle hard, it rears back,
## - the dive: covers swept back (streamlined), nose along the dive; they
##   snap shut on the bite,
## - it banks into its turns and noses up when it climbs,
## - asleep: closed, standing on its shelf; woken, the covers burst open
##   as it slides off; settling back, they fold shut,
## - stunned: the covers droop and flap feebly, it rolls onto its side.

## Cover angles (rad, cover_l's; cover_r mirrors): closed, spread flat,
## swept back in a dive, snapped shut on the bite.
const CLOSED := -0.96
const SPREAD := 0.6
const SWEPT := -0.55
const SNAP := -0.9
## A cover beat: amplitude (rad) and rate (Hz) cruising.
const FLAP := 0.3
const FLAP_RATE := 5.5
## Pulling up after a dive.
const PULL_FLAP := 0.45
const PULL_RATE := 8.5
## How far it rears back at the top of the telegraph (rad).
const REAR := 0.45
## Lift of a wing beat (m, before the model's scale).
const BEAT_LIFT := 0.025

var _base: float = 0.0
var _phase: float = 0.0
var _amp: float = 0.0
var _pitch: float = 0.0
var _roll: float = 0.0
var _last_yaw: float = 0.0
var _snapped := false


## The book of [param binding] (a texture set: flying_book, _green, _blue,
## _black) at [param size] times the quarto model.
static func build(owner_enemy: Enemy, binding: String = "flying_book", size: float = 1.0) -> BookRig:
	var swap := {} if binding == "flying_book" else {"flying_book": binding}
	var loaded := ArtLibrary.exhibit(&"flying_book", swap)
	var rig := BookRig.new()
	rig.cycle_length = 1.0
	rig.full_speed = 4.4
	rig.gib_density = 6.0
	return ExhibitRig.attach_model(owner_enemy, rig, loaded, Transform3D(Basis.from_scale(Vector3.ONE * size), Vector3.ZERO)) as BookRig


## The covers' opening now (cover_l's angle off its rest, rad).
func cover_open() -> float:
	var cover := part("cover_l")
	if cover == null:
		return 0.0
	return ((rest["cover_l"] as Transform3D).basis.inverse() * cover.basis).get_euler().y


func _setup() -> void:
	_last_yaw = enemy.global_rotation.y if enemy.is_inside_tree() else 0.0


func _pose(delta: float) -> void:
	var book := enemy as FlyingBook
	var brain := enemy.brain
	var state := brain.state
	var w := brain.windup_progress()
	var stunned := state == EnemyBrain.State.STUNNED
	var climb := enemy.velocity.y
	var flat_speed := Vector2(enemy.velocity.x, enemy.velocity.z).length()
	var launch := book.launching()
	var landing := book.landing()
	var pull := book.pulling()
	# the covers: where they sit, how they beat
	var base := 0.0
	var amp := FLAP + clampf(climb, 0.0, 3.0) * 0.03
	var rate := FLAP_RATE + clampf(climb, 0.0, 3.0) * 0.8 + flat_speed * 0.15
	var settle := 12.0
	if book.perched():
		base = CLOSED
		amp = 0.0
		rate = 0.0
	elif landing > 0.0:
		base = lerpf(CLOSED, 0.0, landing)
		amp *= landing
	elif launch > 0.0:
		base = lerpf(0.3, CLOSED, launch * launch)   # bursting open, a touch past rest
		amp *= 1.0 - launch
		settle = 24.0
	elif w > 0.0:
		base = SPREAD * MotionClip.eased(MotionClip.OUT, minf(w / 0.3, 1.0))
		amp = 0.035
		rate = 17.0
		settle = 20.0
	elif book.diving():
		base = SNAP if book.bit() else SWEPT
		amp = 0.04
		rate = 14.0
		settle = 40.0 if book.bit() else 18.0
	elif pull > 0.0:
		base = 0.05
		amp = PULL_FLAP
		rate = PULL_RATE
	elif stunned:
		base = -0.3 + 0.15 * sin(time * 2.7)
		amp = 0.08
		rate = 2.0
	if not _snapped:
		_snapped = true
		_base = base   # the first pose is the pose (no closing at the night's start)
	_base = ExhibitRig.ease_to(_base, base, settle, delta)
	_amp = ExhibitRig.ease_to(_amp, amp, 10.0, delta)
	_phase = fmod(_phase + TAU * rate * delta, TAU * 64.0)
	var beat := sin(_phase) * _amp
	var open := _base + beat
	pose_part("cover_l", Vector3(0.0, open, 0.0))
	pose_part("cover_r", Vector3(0.0, -open, 0.0))
	# the body: bank into turns, nose up climbing, rear back in the
	# telegraph, along the dive, up pulling out of it
	var yaw := enemy.global_rotation.y
	var yaw_rate := angle_difference(_last_yaw, yaw) / maxf(delta, 0.0001)
	_last_yaw = yaw
	var pitch := clampf(climb * 0.09, -0.35, 0.3)
	var roll := clampf(-yaw_rate * 0.12, -0.6, 0.6)
	if w > 0.0:
		pitch = REAR * MotionClip.eased(MotionClip.IN_OUT, w)
	elif book.diving():
		pitch = asin(clampf(book.dive_direction().y, -1.0, 1.0)) - 0.15
	elif pull > 0.0:
		pitch = 0.5 * pull
	if stunned:
		pitch = 0.5
		roll = 1.25
	if book.perched() or landing > 0.0:
		pitch = 0.0
		roll = 0.0
	_pitch = ExhibitRig.ease_to(_pitch, pitch, 9.0, delta)
	_roll = ExhibitRig.ease_to(_roll, roll, 6.0, delta)
	var lift := 0.0 if book.perched() else BEAT_LIFT * cos(_phase) * (_amp / FLAP)
	pose_part("body", Vector3(_pitch, 0.0, _roll), Vector3(0.0, lift, 0.0))
	# the loose pages tremble with the beat, riffle in the telegraph
	var pages := part("pages")
	if pages != null:
		var riffle := 0.0 if book.perched() else 0.35 + 1.6 * w + 0.6 * pull
		var turn := sin(time * 27.0) * 0.06 * riffle + sin(_phase + 1.0) * 0.08 * (_amp / FLAP)
		var depth := 1.0 + 0.12 * sin(time * 31.0) * riffle
		var base_xform: Transform3D = rest["pages"]
		pages.transform = Transform3D(base_xform.basis * Basis(Vector3.UP, turn) * Basis.from_scale(Vector3(1.0, 1.0, depth)), base_xform.origin)


## The telegraph glows; a diving book keeps a warm glow.
func _glow_amount() -> float:
	var book := enemy as FlyingBook
	return maxf(enemy.brain.windup_progress(), 0.5 if book.diving() else 0.0)
