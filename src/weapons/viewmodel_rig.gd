class_name ViewmodelRig
extends Node3D
## A first-person weapon model (vm_pistol, vm_taser, vm_shotgun, vm_fists,
## vm_gatling, vm_flare) with the guard's gloved hands, animated in code.
## WeaponHolder moves this node exactly as it moved the greybox (REST, bob,
## kick, switch and reload dips; the punch tween for the fist); the model
## sits inside at a per-weapon framing that makes each one read clearly in
## the lower right. The "Muzzle" marker stays a direct child
## (WeaponHolder._muzzle_position) and follows the model. The rig reads its
## WeaponState from the holder:
## - pistol: the slide kicks back on every shot and locks back when empty;
## - shotgun: the barrels break open on their hinge for a reload (the fore
##   hand goes with them, the gun tips up to show the chambers) and the
##   hammers fall shot by shot, cocked again by the reload;
## - taser: the three battery LEDs show the charges left, the next one
##   blinks while it recharges;
## - fists: the left fist rolls into the jab as it flies out;
## - the actions throw their brass (WeaponHolder.eject: MuzzleFx): the
##   rifle's casing as its bolt runs back after a shot, the shotgun's spent
##   shells as its barrels break open for the reload;
## - gatling (update_view / on_fired / on_hidden from the holder, like the
##   greybox GatlingView): the barrels spin with the spin-up, the crank
##   turns with them and the right hand rides its knob (CrankKnob), the
##   belt is tugged into the hopper round by round and sways, a long burst
##   heats the barrels to a dull glow, each round jolts the gun and flashes
##   at the muzzle; sounds and smoke come from its GatlingDriver;
## - flare gun: the barrel breaks open on its hinge for the reload and the
##   gun tips up to show the chamber;
## - hunting rifle (Floor I): after every shot the bolt lifts, runs back and
##   forward again through the cycle (the right hand rides its knob); it
##   stays open when the rifle is empty; a reload tips the rifle and the
##   left hand does the work (RELOAD_KEYS): it drops out of the frame to the
##   pouch, comes up with a stripper clip hanging from the fist (bullets
##   forward), sets it in the charger guides, presses it in, lifts and
##   flicks the empty clip away, and comes back under the fore-end; then
##   the right hand runs the bolt home;
## - harpoon gun: the loaded harpoon ("head") shows in the muzzle, is gone
##   after the shot and slides back in during the reload (the reel's crank
##   spins with the upgrade);
## - fire-arrow chest: one arrow per tube ("rocket_1".."rocket_9", as many
##   as a volley has), each gone as it leaves (on_volley_rocket) and
##   pushed back into its tube one by one while the chest reloads; the slow
##   match glows.
## Every rig shows the bought upgrades (apply_look(), WeaponLook): upgrade
## parts on or off, replaced base parts hidden, and the master finish once
## all the weapon's upgrades are at the top (the "<model>_master" texture
## set, a warm sheen, the signature part glowing softly). The secrets'
## rewards show the same way: a unique finish (WeaponLook.LOOKS: a tinted,
## re-polished layer over the base or the master materials, the signature
## glowing in the finish's accent) and the mods' parts (WeaponLook.MODS:
## the choke collar, the peep sight, the line spool, built here in code).
## A changed look plays a short inspection when the weapon is next drawn
## (or, for the weapon in hand, as soon as the terminal lets go of the
## input).
##
## Arms (the two-handed weapons; artlib/hands.py arm()): each hand is a
## rigid fist whose sleeve is its own part (sleeve_l / sleeve_r) pivoted at
## the wrist. Every frame the sleeve is turned from the hand's Wrist marker
## toward an elbow: the rest elbow (the Elbow marker) moved ELBOW_FOLLOW of
## however far the wrist moved, or the elbow an animation sets. So a hand
## that moves (the shotgun's fore hand with the barrels, the gatling's hand
## on the crank, the rifle's reloading hand) keeps a forearm that bends at
## the elbow instead of dragging a stiff sleeve about. The Wrist marker's
## basis: X = the back of the hand, Y = distal (the straight-wrist forearm
## runs along -Y), Z = X x Y (the thumb side is sx * Z); wrist_angles()
## reads the posed flexion and deviation off it, and the anatomy test holds
## every pose within human limits. The Grip marker's basis is the hand frame
## (Z = the grip axis, the thumb at +Z): a hand is posed by where its grip
## goes.

## Per model: [position offset from the holder's spot, scale, extra turn
## (degrees)] that frames it in the lower right of a 16:9 view. Big and
## chunky like a boomer shooter's (the owner found the weapons small): a
## handgun fills about an eighth of the frame with the gloved hand in view,
## turned to show its left side; a long gun about a seventh, reaching in
## from the corner. Measured with tools/art/framing_preview.py (it renders
## every weapon as the game frames it and prints its screen coverage).
const FRAMING := {
	&"vm_pistol": [Vector3(-0.045, 0.1, 0.03), 1.95, Vector3(0.0, 10.0, 0.0)],
	&"vm_taser": [Vector3(-0.045, 0.1, 0.03), 1.9, Vector3(0.0, 10.0, 0.0)],
	&"vm_shotgun": [Vector3(-0.03, 0.06, 0.02), 1.4, Vector3(0.0, 4.0, 0.0)],
	&"vm_fists": [Vector3(0.0, 0.0, 0.0), 1.3, Vector3.ZERO],
	&"vm_gatling": [Vector3(-0.03, 0.03, -0.04), 1.6, Vector3(0.0, 3.0, 0.0)],
	&"vm_flare": [Vector3(-0.045, 0.1, 0.03), 1.9, Vector3(0.0, 10.0, 0.0)],
	&"vm_rifle_hunt": [Vector3(-0.035, 0.07, 0.02), 1.5, Vector3(0.0, 5.0, 0.0)],
	&"vm_harpoon": [Vector3(-0.03, 0.06, 0.02), 1.25, Vector3(0.0, 3.0, 0.0)],
	&"vm_hwacha": [Vector3(-0.035, 0.06, 0.02), 1.5, Vector3.ZERO],
}
## Weapons whose rig is animated from WeaponHolder.update_view() (the
## others animate in their own _process()).
const DRIVEN_BY_HOLDER: Array[StringName] = [&"vm_gatling", &"vm_flare"]
## Hunting rifle: the bolt lifts this far (rad, about the bore axis) and
## runs back this far (m) through a cycle; the right hand follows its knob
## this much.
const BOLT_LIFT := 1.1
const BOLT_TRAVEL := 0.075
const BOLT_HAND_FOLLOW := 0.85
## Working the bolt the rifle comes this far off the shoulder (m: out, a
## little left and down), so the fist riding the knob back stays in the frame
## instead of filling its bottom right corner a hand from the eye.
const BOLT_PUSH := Vector3(-0.05, -0.02, -0.17)
## Arms: the elbow follows the wrist by this much of its travel.
const ELBOW_FOLLOW := 0.5
## Wrist limits (degrees) every pose keeps to: flexion / extension, radial
## (toward the thumb) and ulnar deviation. Anatomy allows ~70 / 20 / 30;
## a fist bent 70 degrees reads as broken, so flexion is held tighter.
const WRIST_FLEX_MAX := 45.0
const WRIST_RADIAL_MAX := 20.0
const WRIST_ULNAR_MAX := 30.0
## Hunting rifle reload, as fractions of the reload time: at rest; down at
## the pouch (two keys: a beat there, the clip appears unseen); up at the
## open action with the clip's bottom in the guides (a beat); pressed in (a
## beat); lifted (the clip flies off from here); back at rest.
const RELOAD_KEYS: Array[float] = [0.0, 0.17, 0.27, 0.50, 0.54, 0.62, 0.66, 0.74, 1.0]
## Where the rifle goes for its reload (on top of the holder's dip; the
## view's space) and how it turns (pitch up, a little yaw, the roll that
## shows the action): its action half a metre out and under the eye line, so
## the left fist at the charger guides fills no more than a fifth of the
## height of the frame (lifted back to the eye it came to 0.33 m and hid the
## clip under a fist half the screen high - the night's QA, 19.10).
const RIFLE_RELOAD_SHIFT := Vector3(-0.02, 0.02, -0.25)
const RIFLE_RELOAD_TURN := Vector3(0.22, 0.08, 0.32)
## The fist's grip point at the pouch, from rest (model space); how far the
## clip is pressed in; the lift before the flick.
const POUCH_DROP := Vector3(0.0, -0.40, 0.08)
const PRESS := 0.02
const LIFT := Vector3(0.015, 0.05, 0.0)
## The clip hangs from the little-finger side of the fist with its top this
## deep inside; the fist reaches this far from its grip point along the grip
## axis.
const CLIP_IN_FIST := 0.014
const FIST_REACH := 0.04
## The clip shows between these fractions of the reload, leaves the hand at
## CLIP_FLICK_AT (m/s and rad/s of the flick, model space).
const CLIP_SHOWN := Vector2(0.20, 0.80)
const CLIP_FLICK_AT := 0.74
const FLICK_SPEED := Vector3(0.5, 0.6, -0.4)
const FLICK_SPIN := 10.0
## Where the left elbow is from the wrist (directions, model space) with
## the hand at the pouch and at the action; the hand's thumb at the pouch.
const ELBOW_POUCH := Vector3(-0.35, -0.90, 0.25)
const ELBOW_ACTION := Vector3(-0.78, -0.62, -0.05)
const THUMB_POUCH := Vector3(0.2, 0.3, -0.93)
## Harpoon gun: a reloaded harpoon starts this far out of the muzzle (m)
## and slides in; the reel's crank turns this fast while reloading (rad/s).
const HARPOON_LOAD_OUT := 0.3
const REEL_SPIN := 14.0
## Fire-arrow chest: a returning arrow starts this far back in its tube.
const ROCKET_SINK := 0.06
## The inspection after a new upgrade: seconds, and when the glint shows.
const INSPECT_TIME := 1.3
const GLINT_AT := 0.45
## Master finish: the signature part's glow (energy, breathing).
const MASTER_GLOW := 0.42
const MASTER_GLOW_BREATH := 0.18
## A secret's finish without mastery lights the signature this much.
const LOOK_GLOW := 0.22
## The brass of the mods' parts and the sea-teal thread on the line spool.
## The choke collar (a secret's mod): its band this long, standing this
## proud of the barrels, this far behind the spread choke at the muzzle.
const CHOKE_BAND := 0.022
const CHOKE_PROUD := 0.004
const CHOKE_BEHIND := 0.05
const FITTING_BRASS := Color(0.82, 0.64, 0.3)
const FITTING_STEEL := Color(0.42, 0.43, 0.45)
const FITTING_THREAD := Color(0.2, 0.78, 0.85)
## Fill light that reaches only the first-person layer
## (ArtLibrary.VIEWMODEL_LAYER): up and left of the weapon, between it and
## the eye, so gun and gloves read in any room.
const FILL_AT := Vector3(-0.14, 0.2, 0.32)
const FILL_COLOR := Color(1.0, 0.93, 0.84)
const FILL_ENERGY := 0.65
## How far WeaponHolder dips the weapon while it reloads (its
## _reload_drop); the shotgun lifts itself back up to show the chambers.
const HOLDER_RELOAD_DROP := 0.12
const SLIDE_TRAVEL := 0.035
const BARREL_BREAK := -0.62
## How much of the break the fore hand tips with (the rest is the wrist).
const FORE_HAND_TIP := 0.55
const HAMMER_DOWN := -0.75
## FIST_REST.z and FIST_HIT.z of WeaponHolder: the punch path.
const PUNCH_FROM := -0.3
const PUNCH_TO := -0.62
## Gatling: the dull red of hot barrels, how far each round tugs the belt
## up into the hopper (m), how long a muzzle flash shows (s).
const GATLING_GLOW := Color(1.0, 0.3, 0.08)
const GATLING_GLOW_ENERGY := 4.5
const BELT_TUG := 0.007
const FLASH_TIME := 0.045
## Flare gun: the barrel's break angle (muzzle down) for a reload.
const FLARE_BREAK := -0.6
## Reload poses (plan 2026-10-21-animacje-fpp) follow their keyed targets on
## critically damped springs (ViewmodelMotion.follow) at this rate (1/s):
## close, but a reload cut short eases back from where it was. The lift
## that takes back the holder's reload dip (HOLDER_RELOAD_DROP) follows
## the holder's own spring (WeaponHolder.RELOAD_OMEGA), so the two cancel
## frame by frame.
const RELOAD_OMEGA := 28.0
## Break-actions (shotgun, flare gun), as fractions of the reload: broken
## open by BREAK_OPEN, each round thumbed in at its fraction (a dip),
## snapped shut between BREAK_SHUT's two with a flick of the wrist
## (BREAK_FLICK: the gun jerks up as the barrels meet the breech), then
## levelled back into the aim by the reload's end.
const BREAK_OPEN := 0.22
const BREAK_SHUT := Vector2(0.75, 0.89)
const BREAK_FLICK := Vector2(0.8, 0.94)
const SHOTGUN_SHELLS := [0.42, 0.56]
const FLARE_ROUND := [0.46]
## Pistol reload: tipped in (pitch, yaw, roll) and lifted back over the
## holder's dip by PISTOL_TIP_IN, back from PISTOL_TIP_OUT; the empty
## magazine shaken out and the new one slapped home between their two
## fractions; the slide let go at PISTOL_RELEASE. (Seen in the window:
## pitched up further and lifted, the pistol covered the crosshair - it is
## rolled over to show the magazine well and kept low and to the right.)
const PISTOL_TIP := Vector3(0.12, 0.1, 0.55)
const PISTOL_LIFT := Vector3(-0.03, 0.1, -0.01)
const PISTOL_TIP_IN := 0.18
const PISTOL_TIP_OUT := 0.84
const PISTOL_MAG_OUT := Vector2(0.2, 0.3)
const PISTOL_MAG_IN := Vector2(0.55, 0.65)
const PISTOL_RELEASE := 0.72
## Hunting rifle: brought to its reload and back, and pushed by the bolt's
## work, on springs (1/s).
const RIFLE_OPEN_OMEGA := 16.0
const RIFLE_BACK_OMEGA := 22.0
const RIFLE_PUSH_OMEGA := 28.0
## ... and the right hand following the bolt's knob (1/s). After a reload
## the bolt cycle picks up at x (a share of it; the bolt still open, the
## hand a moment to reach its knob before it runs home), y s for a whole
## cycle.
const RIFLE_KNOB_OMEGA := 40.0
const RIFLE_CYCLE_AFTER_RELOAD := Vector2(0.5, 1.2)
## Harpoon gun: tipped up for its reload and back down on springs (1/s).
const HARPOON_TIP_OMEGA := 14.0
const HARPOON_BACK_OMEGA := 20.0
## Gatling: a new belt is hauled this far up into the hopper (m).
const BELT_HAUL := 0.02
## The first look at a found weapon (FirstLook): seconds, its keyed poses
## per grip class (ViewmodelMotion.Grip) [share of the time, offset, turn] -
## turned to show its left side, a beat, turned the other way to show the
## other, a beat, back in the hands - and how long (s) a look cut short
## takes to let go (eased, never a snap). A handgun is rolled right over in
## the one hand; a two-handed weapon cannot be (rolled the other way, its
## fore arm's elbow would swing up into the frame: measured), so it is
## swung across instead, the heavy pieces more gently still, and both
## take longer over it (FIRST_LOOK_TIMES: a long barrel swung across in a
## third of a second would sweep its muzzle past the eye; measured).
const FIRST_LOOK_TIME := 1.2
const FIRST_LOOK_TIMES := {
	ViewmodelMotion.Grip.ONE_HAND: 1.2,
	ViewmodelMotion.Grip.LONG: 1.4,
	ViewmodelMotion.Grip.HEAVY: 1.4,
}
const FIRST_LOOK := {
	ViewmodelMotion.Grip.ONE_HAND: [
		[0.0, Vector3.ZERO, Vector3.ZERO],
		[0.28, Vector3(-0.05, 0.06, 0.05), Vector3(0.16, 0.7, 0.3)],
		[0.46, Vector3(-0.055, 0.065, 0.055), Vector3(0.2, 0.78, 0.36)],
		[0.72, Vector3(-0.03, 0.05, 0.04), Vector3(0.12, -0.18, -0.5)],
		[0.84, Vector3(-0.03, 0.05, 0.04), Vector3(0.1, -0.22, -0.55)],
		[1.0, Vector3.ZERO, Vector3.ZERO],
	],
	ViewmodelMotion.Grip.LONG: [
		[0.0, Vector3.ZERO, Vector3.ZERO],
		[0.28, Vector3(-0.05, 0.06, 0.05), Vector3(0.16, 0.64, 0.3)],
		[0.46, Vector3(-0.055, 0.065, 0.055), Vector3(0.2, 0.7, 0.36)],
		[0.72, Vector3(-0.02, 0.05, 0.04), Vector3(0.12, -0.22, -0.15)],
		[0.84, Vector3(-0.02, 0.05, 0.04), Vector3(0.12, -0.25, -0.17)],
		[1.0, Vector3.ZERO, Vector3.ZERO],
	],
	ViewmodelMotion.Grip.HEAVY: [
		[0.0, Vector3.ZERO, Vector3.ZERO],
		[0.28, Vector3(-0.04, 0.05, 0.05), Vector3(0.1, 0.55, 0.22)],
		[0.46, Vector3(-0.045, 0.055, 0.055), Vector3(0.12, 0.6, 0.25)],
		[0.72, Vector3(-0.02, 0.05, 0.04), Vector3(0.1, -0.15, 0.12)],
		[0.84, Vector3(-0.02, 0.05, 0.04), Vector3(0.1, -0.18, 0.14)],
		[1.0, Vector3.ZERO, Vector3.ZERO],
	],
}
const LOOK_LET_GO := 0.3
## The guard's hands (and sleeves) keep their own look in the master finish.
const HANDS_NOT_POLISHED: Array[String] = ["hand_r", "hand_l", "sleeve_r", "sleeve_l"]

## Master-finish materials, shared per texture set; the secrets' finishes,
## shared per finish and source material; the mods' fitting materials.
static var _master_cache: Dictionary = {}
static var _look_cache: Dictionary = {}
static var _fitting_cache: Dictionary = {}


## One arm of a two-handed weapon: its parts and markers, its rest in the
## model's root space, and the elbow an animation may set for a frame.
class Arm:
	extends RefCounted
	var side := "l"
	var sx := -1.0
	var hand: Node3D
	var sleeve: Node3D
	var wrist: Node3D
	var grip: Node3D
	var wrist_rest := Vector3.ZERO
	var elbow_rest := Vector3.ZERO
	var sleeve_rest := Transform3D.IDENTITY
	## The sleeve's direction at rest (root space) and in its own space.
	var sleeve_dir := Vector3.DOWN
	var sleeve_dir_local := Vector3.DOWN
	var elbow_set := Vector3.ZERO
	var elbow_is_set := false

var weapon_id: StringName = &""
var model_id: StringName = &""
var model: Node3D
var parts: Dictionary = {}
var rest: Dictionary = {}
var muzzle: Node3D

var _muzzle_local := Transform3D.IDENTITY
var _slide := 0.0
var _open := 0.0
var _hammers := [0.0, 0.0]
var _fired_in_load := 0
var _was_reloading := false
var _time := 0.0
var _driver: GatlingDriver
var _barrel_angle := 0.0
var _crank_angle := 0.0
var _belt_tug := 0.0
var _hot_materials: Array[BaseMaterial3D] = []
var _hot_energy := -1.0
var _flash: MeshInstance3D
var _flash_left := 0.0
## The rest transform of [member model] (its framing).
var _framing_xform := Transform3D.IDENTITY
## Hunting rifle: 0..1 through the bolt cycle (1 = closed, at rest); the
## bolt eased open for a reload; the right hand's eased hold on the knob;
## the reload's keyed grip poses and elbow offsets (RELOAD_KEYS); whether
## the clip rides in the hand now.
var _cycle := 1.0
var _cycle_length := 1.0
var _bolt_sound := false
var _bolt_open := 0.0
var _knob_follow := 0.0
var _bolt_push := 0.0
var _bolt_push_v := 0.0
var _knob_follow_v := 0.0
var _reload_grips: Array[Transform3D] = []
var _reload_elbows: Array[Vector3] = []
var _clip_held := false
## Rifle: a shot's casing waits for the bolt to open; shotgun: this
## reload's spent shells are out.
var _eject_pending := false
var _shells_out := false
## The arms of a two-handed weapon (empty on the others).
var _arms: Array[Arm] = []
## Harpoon gun / fire-arrow chest: the reel's turn, arrows gone this volley.
var _reel_angle := 0.0
## Fire-arrow chest: tubes (index from 0) emptied by the last volley.
var _fired: Dictionary = {}
var _ember: OmniLight3D
## Upgrade look: its signature (WeaponLook.key), an inspection waiting for
## the next draw, the parts that just appeared (they glint).
var _look_key := ""
var _inspect_pending := false
var _inspect_left := 0.0
var _new_parts: PackedStringArray = []
var _glint: MeshInstance3D
## Master finish: on, each mesh's own materials before it, the signature
## parts' glowing materials (and how bright they breathe around).
var _mastered := false
var _base_materials: Dictionary = {}
var _glow_materials: Array[BaseMaterial3D] = []
var _glow_base := MASTER_GLOW
## The secrets' finish on the weapon (WeaponLook.LOOKS id, &"" none) and
## the mods' parts built so far (mod id -> its mesh, under the model).
var _look: StringName = &""
var _mod_parts: Dictionary = {}
## The reload's eased pose on the model (offset, turn) and its velocities;
## the pistol's reload started from an empty magazine (the slide is let go).
var _reload_at := Vector3.ZERO
var _reload_turn := Vector3.ZERO
var _reload_at_v := Vector3.ZERO
var _reload_turn_v := Vector3.ZERO
## The springs' velocity of _open; the lift over the holder's reload dip
## (0..1, HOLDER_RELOAD_DROP) and the model's tilt toward the eye for a
## reload (0..1), with theirs.
var _open_v := 0.0
var _lift := 0.0
var _lift_v := 0.0
var _tilt := 0.0
var _tilt_v := 0.0
## A break-action's hinge: what is left of a jump (a reload cut short),
## its velocity, and whether a reload ran last frame.
var _hinge_off := 0.0
var _hinge_off_v := 0.0
var _hinge_running := false
var _empty_reload := false
## The first look at a found weapon: seconds left, cut short (and how long
## ago: it lets go of the pose over LOOK_LET_GO).
var _first_left := 0.0
var _first_cut := false
var _first_cut_t := 0.0


## The rig for weapon [param id] (&"pistol", &"taser", &"shotgun",
## &"fist"), or null when its model is off or missing.
static func create(id: StringName) -> ViewmodelRig:
	var model_name := StringName("vm_fists" if id == &"fist" else "vm_" + String(id))
	var loaded := ArtLibrary.try_instance(model_name)
	if loaded == null:
		return null
	var rig := ViewmodelRig.new()
	rig.name = String(id)
	rig.weapon_id = id
	rig.model_id = model_name
	rig.model = loaded
	var framing: Array = FRAMING.get(model_name, [Vector3.ZERO, 1.0, Vector3.ZERO])
	loaded.transform = Transform3D(Basis.from_euler((framing[2] as Vector3) * PI / 180.0).scaled(Vector3.ONE * float(framing[1])), framing[0])
	rig.add_child(loaded)
	for node in loaded.find_children("*", "Node3D", true, false):
		rig.parts[String(node.name)] = node
		rig.rest[String(node.name)] = (node as Node3D).transform
	# the muzzle is read straight off the rig: a direct child that follows
	# the model's marker
	var marker := loaded.get_node_or_null(^"Muzzle") as Node3D
	rig.muzzle = Marker3D.new()
	rig.muzzle.name = "Muzzle"
	if marker != null:
		rig._muzzle_local = marker.transform
	rig.add_child(rig.muzzle)
	rig._place_muzzle()
	if model_name == &"vm_fists":
		var right := rig.parts.get("fist_r") as Node3D
		if right != null:
			right.visible = false   # the right hand holds the weapon
	var fill := OmniLight3D.new()
	fill.name = "Fill"
	fill.position = FILL_AT
	fill.light_color = FILL_COLOR
	fill.light_energy = FILL_ENERGY * (0.4 if model_name == &"vm_fists" else 1.0)
	fill.light_specular = 0.6
	fill.omni_range = 1.4
	fill.light_cull_mask = ArtLibrary.VIEWMODEL_LAYER
	fill.shadow_enabled = false
	rig.add_child(fill)
	if model_name == &"vm_gatling":
		rig._setup_gatling()
	elif model_name == &"vm_hwacha":
		rig._setup_hwacha()
	rig._setup_arms()
	if model_name == &"vm_rifle_hunt":
		rig._setup_reload()
	rig._framing_xform = loaded.transform
	return rig


func _ready() -> void:
	Events.weapon_fired.connect(_on_weapon_fired)
	set_process(visible)


## Only the weapon in hand animates (the holder hides the others). Once
## out of sight a weapon drops what it was half-way through (a reload's
## pose, a first look), so it is drawn again at rest; while it goes down
## it keeps its pose.
func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED:
		set_process(visible)
		if not visible:
			_rest_poses()


func _rest_poses() -> void:
	_reload_at = Vector3.ZERO
	_reload_turn = Vector3.ZERO
	_reload_at_v = Vector3.ZERO
	_reload_turn_v = Vector3.ZERO
	_lift = 0.0
	_lift_v = 0.0
	_tilt = 0.0
	_tilt_v = 0.0
	_open = 0.0
	_open_v = 0.0
	_hinge_off = 0.0
	_hinge_off_v = 0.0
	_hinge_running = false
	_bolt_push = 0.0
	_bolt_push_v = 0.0
	_knob_follow = 0.0
	_knob_follow_v = 0.0
	_first_left = 0.0
	_first_cut = false
	_first_cut_t = 0.0
	if model != null:
		model.transform = _framing_xform


## Part [param part_name] of the model (slide, barrels, led_1...), or null.
func part_node(part_name: StringName) -> Node3D:
	return parts.get(String(part_name)) as Node3D


func _process(delta: float) -> void:
	_time += delta
	# drawn (or bought while in hand): looked over once it is up in the hands
	# and the terminal lets go
	if _inspect_pending and weapon_id != &"fist" and GameInput.gameplay_input() and _up_in_hand():
		on_drawn()
	if DRIVEN_BY_HOLDER.has(model_id):
		return
	var state := _state()
	model.transform = _framing_xform
	match model_id:
		&"vm_pistol":
			_animate_pistol(state, delta)
		&"vm_shotgun":
			_animate_shotgun(state, delta)
		&"vm_taser":
			_animate_taser(state)
		&"vm_fists":
			_animate_fist()
		&"vm_rifle_hunt":
			_animate_rifle(state, delta)
		&"vm_harpoon":
			_animate_harpoon(state, delta)
		&"vm_hwacha":
			_animate_hwacha(state, delta)
	_finish_pose(delta)


## Called by WeaponHolder every frame while this weapon is in hand (the
## gatling and the flare gun animate here; the others in _process).
func update_view(state: WeaponState, delta: float) -> void:
	if not DRIVEN_BY_HOLDER.has(model_id):
		return
	model.transform = _framing_xform
	match model_id:
		&"vm_gatling":
			_animate_gatling(state, delta)
		&"vm_flare":
			_animate_flare(state, delta)
	_finish_pose(delta)


## Shows the upgrades of [param levels] (WeaponLook): upgrade parts on or
## off, replaced base parts hidden, the master finish. With
## [param announce] a changed look plays the inspection on the next draw.
func apply_look(levels: Dictionary, announce: bool = false) -> void:
	var shown := WeaponLook.shown_parts(weapon_id, levels)
	var hidden := WeaponLook.hidden_parts(weapon_id, levels)
	_new_parts = PackedStringArray()
	for part in WeaponLook.all_parts(weapon_id):
		var node := part_node(StringName(part))
		if node == null:
			continue
		var show := shown.has(part)
		if show and not node.visible:
			_new_parts.append(part)
		node.visible = show
	for part in WeaponLook.replaceable_parts(weapon_id):
		var node := part_node(StringName(part))
		if node != null:
			node.visible = not hidden.has(part)
	var mods := WeaponLook.mods_of(weapon_id, levels)
	for mod: StringName in WeaponLook.MODS:
		if (WeaponLook.MODS[mod] as Dictionary)["weapon"] != WeaponLook.weapon_of_view(weapon_id):
			continue
		var show_mod := mods.has(mod)
		var fitting := _mod_part(mod) if show_mod or _mod_parts.has(mod) else null
		if fitting == null:
			continue
		if show_mod and not fitting.visible:
			_new_parts.append(String(fitting.name))
		fitting.visible = show_mod
	_set_finish(WeaponLook.mastered(weapon_id, levels), WeaponLook.look_of(weapon_id, levels))
	var look := WeaponLook.key(weapon_id, levels)
	if announce and _look_key != "" and look != _look_key and weapon_id != &"fist":
		_inspect_pending = true
	_look_key = look


## True while the master finish is on.
func mastered() -> bool:
	return _mastered


## The secrets' finish on the weapon (WeaponLook.LOOKS id), &"" for none.
func look() -> StringName:
	return _look


## True while an inspection waits for the next draw.
func inspect_pending() -> bool:
	return _inspect_pending


## Seconds of the running inspection left (0: none).
func inspecting() -> float:
	return _inspect_left


## The first look at a found weapon (WeaponHolder starts it at a calm
## moment, FirstLook): first_look_time() s, its side and then its other
## side turned to the eye. Not on the fists.
func look_over() -> void:
	if weapon_id == &"fist":
		return
	_first_left = first_look_time()
	_first_cut = false
	_first_cut_t = 0.0


## Seconds of the first look left (0: none).
func looking_over() -> float:
	return _first_left


## How long this weapon's first look takes (s, by its grip class).
func first_look_time() -> float:
	return FIRST_LOOK_TIMES.get(ViewmodelMotion.grip_of(weapon_id), FIRST_LOOK_TIME)


## A shot, a blow, a switch or a fight: the first look lets go within
## LOOK_LET_GO s instead of snapping back.
func cut_look() -> void:
	if _first_left > 0.0:
		_first_cut = true


## True when this weapon is up in its holder's hands (WeaponHolder.drawn;
## true outside a holder).
func _up_in_hand() -> bool:
	var holder := get_parent() as WeaponHolder
	return holder == null or holder.drawn(weapon_id)


## Once this weapon is up in the hands: a new look is looked over.
func on_drawn() -> void:
	if not _inspect_pending:
		return
	_inspect_pending = false
	_inspect_left = INSPECT_TIME


## The master finish on or off (the secrets' finish, if any, stays).
func set_mastery(on: bool) -> void:
	_set_finish(on, _look)


## The weapon's finish: every weapon mesh (not the hands) gets the
## "<model>_master" texture set when mastered (with a warm sheen: rim,
## clear coat, a little smoother), the secrets' finish [param look] over
## that (look_material: tinted, re-polished), and the signature parts glow
## softly - gold for mastery, the finish's accent when it has one. The
## mods' fittings keep their own brass.
func _set_finish(on: bool, look: StringName) -> void:
	if on == _mastered and look == _look:
		return
	_mastered = on
	_look = look
	_glow_materials.clear()
	var spec: Dictionary = WeaponLook.LOOKS.get(look, {})
	var signature: Array = WeaponLook.SIGNATURE.get(weapon_id, [])
	_glow_base = MASTER_GLOW if on else LOOK_GLOW
	var glow_color: Color = spec.get("accent", WeaponLook.MASTER_COLOR)
	for child in model.find_children("*", "MeshInstance3D", true, false):
		var view := child as MeshInstance3D
		if (String(view.name) in HANDS_NOT_POLISHED and weapon_id != &"fist") or _mod_parts.values().has(view):
			continue
		if not _base_materials.has(view):
			var base: Array[Material] = []
			for i in view.mesh.get_surface_count():
				base.append(view.get_surface_override_material(i))
			_base_materials[view] = base
		var originals: Array = _base_materials[view]
		for i in view.mesh.get_surface_count():
			var source := originals[i] as BaseMaterial3D
			if source == null:
				continue
			if not on and spec.is_empty():
				view.set_surface_override_material(i, source)
				continue
			var finished := master_material(source) if on else source
			if not spec.is_empty():
				finished = look_material(finished, look)
			if signature.has(String(view.name)):
				finished = finished.duplicate() as BaseMaterial3D
				finished.emission_enabled = true
				finished.emission = glow_color
				finished.emission_texture = finished.albedo_texture
				finished.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
				finished.emission_energy_multiplier = _glow_base
				_glow_materials.append(finished)
			view.set_surface_override_material(i, finished)


## The secrets' finish [param look] (WeaponLook.LOOKS) over a viewmodel
## material (shared per finish and source): the "<set>_<look>" textures
## when the art has them, else the source's textures and colour under the
## finish's tint (multiplied: a part with a colour of its own keeps it),
## re-polished (roughness scaled, a metallic floor, a coloured rim).
static func look_material(source: BaseMaterial3D, look: StringName) -> BaseMaterial3D:
	var key := "look:%s:%s" % [look, source.resource_name]
	if _look_cache.has(key):
		return _look_cache[key]
	var spec: Dictionary = WeaponLook.LOOKS.get(look, {})
	var base_name := source.resource_name.trim_suffix("_master")
	var look_set := base_name + "_" + String(look)
	var finished: BaseMaterial3D
	if ArtLibrary.texture(look_set, "albedo") != null:
		finished = (ArtLibrary.material(look_set) as BaseMaterial3D).duplicate() as BaseMaterial3D
		finished.use_fov_override = true
		finished.fov_override = ArtLibrary.VIEWMODEL_FOV
		finished.use_z_clip_scale = true
		finished.z_clip_scale = ArtLibrary.VIEWMODEL_Z_CLIP
	else:
		finished = source.duplicate() as BaseMaterial3D
		finished.albedo_color = source.albedo_color * (spec.get("tint", Color.WHITE) as Color)
		finished.roughness = source.roughness * float(spec.get("roughness", 1.0))
		finished.metallic = maxf(source.metallic, float(spec.get("metallic", 0.0)))
	finished.resource_name = source.resource_name + "_" + String(look)
	finished.rim_enabled = true
	finished.rim = 0.3
	finished.rim_tint = 0.6
	_look_cache[key] = finished
	return finished


## The master-finish version of a viewmodel material (shared per texture
## set): the "<set>_master" textures when they exist, a warm rim sheen, a
## clear coat, a little smoother.
static func master_material(source: BaseMaterial3D) -> BaseMaterial3D:
	var key := "master:" + source.resource_name
	if _master_cache.has(key):
		return _master_cache[key]
	var master_set := source.resource_name + "_master"
	var base: BaseMaterial3D = source
	if ArtLibrary.texture(master_set, "albedo") != null:
		base = ArtLibrary.material(master_set) as BaseMaterial3D
	var polished := base.duplicate() as BaseMaterial3D
	polished.resource_name = master_set
	polished.use_fov_override = true
	polished.fov_override = ArtLibrary.VIEWMODEL_FOV
	polished.use_z_clip_scale = true
	polished.z_clip_scale = ArtLibrary.VIEWMODEL_Z_CLIP
	polished.rim_enabled = true
	polished.rim = 0.35
	polished.rim_tint = 0.7
	polished.clearcoat_enabled = true
	polished.clearcoat = 0.45
	polished.clearcoat_roughness = 0.18
	polished.roughness = source.roughness * 0.78
	polished.metallic_specular = 0.65
	_master_cache[key] = polished
	return polished


## Called by WeaponHolder for every fire-arrow of a volley as it leaves
## ([param index] from 0): its tube empties.
func on_volley_rocket(index: int) -> void:
	_fired[index] = true
	var rocket := part_node(StringName("rocket_%d" % (index + 1)))
	if rocket != null:
		rocket.visible = false


## Called by WeaponHolder on every round this weapon fires.
func on_fired(_state: WeaponState) -> void:
	if model_id == &"vm_gatling" and _driver != null:
		_driver.fired()
		_belt_tug = 1.0
		_flash_left = FLASH_TIME
		_flash.scale = Vector3.ONE * randf_range(0.75, 1.25)


## Called by WeaponHolder when this weapon is put away.
func on_hidden() -> void:
	if _driver != null:
		_driver.hidden()
	if _flash != null:
		_flash_left = 0.0
		_flash.visible = false


## The gatling's driver (sounds, heat, smoke, jolt); null on other rigs.
func gatling_driver() -> GatlingDriver:
	return _driver


## Energy of the gatling's barrel glow now (0 cold).
func barrel_heat() -> float:
	return maxf(_hot_energy, 0.0)


## The action throws [param count] casings (WeaponHolder's MuzzleFx).
func _eject(count: int) -> void:
	var holder := get_parent() as WeaponHolder
	if holder != null and count > 0:
		holder.eject(weapon_id, count)


func _state() -> WeaponState:
	var holder := get_parent() as WeaponHolder
	if holder == null:
		return null
	if weapon_id == &"fist":
		return holder.fists
	return holder.state_of(weapon_id)


func _on_weapon_fired(id: StringName) -> void:
	if id != weapon_id or not visible:
		return
	match model_id:
		&"vm_pistol":
			_slide = 1.0
		&"vm_shotgun":
			_fired_in_load += 1
		&"vm_rifle_hunt":
			var state := _state()
			_cycle_length = state.data.cooldown if state != null else 1.0
			_cycle = 0.0
			_bolt_sound = false
			_eject_pending = true


## The pistol: the slide kicks back on a shot and locks back when empty.
## Its reload (PISTOL_*, fractions of the reload time; the right hand alone
## shows, the left works under the frame): tipped in and lifted back into
## view to show the grip, a jolt down as the empty magazine is shaken out, a
## jolt up as the new one is slapped home, the slide let go (if it was
## locked) with a snap, back to rest.
func _animate_pistol(state: WeaponState, delta: float) -> void:
	var reloading := state != null and state.is_reloading()
	var p := state.reload_progress() if reloading else 0.0
	if reloading and not _was_reloading:
		_empty_reload = state.magazine == 0
	_was_reloading = reloading
	var locked := state != null and state.magazine == 0 and not (reloading and p >= PISTOL_RELEASE)
	_slide = ExhibitRig.ease_to(_slide, 1.0 if locked else 0.0, 12.0 if locked else 26.0, delta)
	_pose_part(&"slide", Vector3.ZERO, Vector3(0.0, 0.0, SLIDE_TRAVEL * _slide))
	var at := Vector3.ZERO
	var turn := Vector3.ZERO
	if reloading:
		var tip := smoothstep(0.0, PISTOL_TIP_IN, p) * (1.0 - smoothstep(PISTOL_TIP_OUT, 1.0, p))
		var out := ViewmodelMotion.bump(p, PISTOL_MAG_OUT.x, PISTOL_MAG_OUT.y)
		var seat := ViewmodelMotion.bump(p, PISTOL_MAG_IN.x, PISTOL_MAG_IN.y)
		var snap := ViewmodelMotion.bump(p, PISTOL_RELEASE, PISTOL_RELEASE + 0.08) if _empty_reload else 0.0
		at = (PISTOL_LIFT - Vector3(0.0, HOLDER_RELOAD_DROP, 0.0)) * tip + Vector3(0.0, -0.012 * out + 0.016 * seat + 0.008 * snap, 0.0)
		turn = PISTOL_TIP * tip + Vector3(-0.06 * out + 0.09 * seat + 0.05 * snap, 0.0, 0.0)
	_ease_reload_pose(at, turn, delta)
	_follow_lift(reloading, delta)
	model.position = (FRAMING[model_id][0] as Vector3) + Vector3(0.0, HOLDER_RELOAD_DROP, 0.0) * _lift + _reload_at
	model.rotation = _framing_turn() + _reload_turn


## The reload's pose on the model (offset, turn) follows its keyed target
## closely on a spring, so a reload cut short eases back instead of jumping.
func _ease_reload_pose(at: Vector3, turn: Vector3, delta: float) -> void:
	var moved: Array = ViewmodelMotion.follow3(_reload_at, _reload_at_v, at, RELOAD_OMEGA, delta)
	_reload_at = moved[0]
	_reload_at_v = moved[1]
	var turned: Array = ViewmodelMotion.follow3(_reload_turn, _reload_turn_v, turn, RELOAD_OMEGA, delta)
	_reload_turn = turned[0]
	_reload_turn_v = turned[1]


## The lift that takes back the holder's reload dip: on the holder's own
## spring, so the model stays where it was shown.
func _follow_lift(reloading: bool, delta: float) -> void:
	var lift := ViewmodelMotion.follow(_lift, _lift_v, 1.0 if reloading else 0.0, WeaponHolder.RELOAD_OMEGA, delta)
	_lift = lift.x
	_lift_v = lift.y


## _open on a spring toward [param target] at [param omega] (1/s).
func _follow_open(target: float, omega: float, delta: float) -> void:
	var open := ViewmodelMotion.follow(_open, _open_v, target, omega, delta)
	_open = open.x
	_open_v = open.y


## A break-action's hinge (_open): its keys exactly while the reload runs
## (they are smooth: the snap shut stays crisp); when a reload begins or
## ends with the barrels elsewhere (cut short), the difference dies away on
## a spring.
func _follow_hinge(target: float, reloading: bool, delta: float) -> void:
	if reloading != _hinge_running:
		_hinge_running = reloading
		_hinge_off = _open - target
	var off := ViewmodelMotion.follow(_hinge_off, _hinge_off_v, 0.0, RELOAD_OMEGA, delta)
	_hinge_off = off.x
	_hinge_off_v = off.y
	_open = target + _hinge_off


## The model's reload tilt toward the eye on a spring.
func _follow_tilt(target: float, delta: float) -> void:
	var tilt := ViewmodelMotion.follow(_tilt, _tilt_v, target, RELOAD_OMEGA, delta)
	_tilt = tilt.x
	_tilt_v = tilt.y


## How far a break-action is open at reload fraction [param p]: broken
## open by BREAK_OPEN, snapped shut from BREAK_SHUT.x to BREAK_SHUT.y.
static func _keyed_break(p: float) -> float:
	return smoothstep(0.0, BREAK_OPEN, p) * (1.0 - smoothstep(BREAK_SHUT.x, BREAK_SHUT.y, p))


## How far a break-action is tipped toward the eye at reload fraction
## [param p]: as it opens, held while the barrels snap shut, levelled back
## into the aim by the reload's end.
static func _keyed_tilt(p: float) -> float:
	return smoothstep(0.0, BREAK_OPEN, p) * (1.0 - smoothstep(BREAK_SHUT.y, 1.0, p))


## The jolts of a break-action's reload: a dip as each round is thumbed in
## ([param rounds] fractions), the flick of the wrist that snaps it shut.
## [offset, turn].
static func _break_jolts(p: float, rounds: Array) -> Array:
	var press := 0.0
	for at: float in rounds:
		press += ViewmodelMotion.bump(p, at, at + 0.1)
	var flick := ViewmodelMotion.bump(p, BREAK_FLICK.x, BREAK_FLICK.y)
	return [Vector3(0.0, -0.006 * press + 0.018 * flick, 0.0), Vector3(-0.03 * press + 0.16 * flick, 0.0, 0.0)]


func _animate_shotgun(state: WeaponState, delta: float) -> void:
	var reloading := state != null and state.is_reloading()
	if _was_reloading and not reloading:
		_fired_in_load = 0   # both chambers loaded, hammers cocked
	_was_reloading = reloading
	if state != null and state.magazine >= state.data.magazine_size:
		_fired_in_load = 0
	# keyed on the reload: broken open, two shells thumbed in, snapped shut
	# from the wrist before the reload ends
	var p := state.reload_progress() if reloading else 0.0
	_follow_hinge(_keyed_break(p) if reloading else 0.0, reloading, delta)
	_follow_tilt(_keyed_tilt(p) if reloading else 0.0, delta)
	_follow_lift(reloading, delta)
	var jolts: Array = _break_jolts(p, SHOTGUN_SHELLS) if reloading else [Vector3.ZERO, Vector3.ZERO]
	_ease_reload_pose(jolts[0], jolts[1], delta)
	# broken open: the spent shells pop out over the shoulder
	if not reloading:
		_shells_out = false
	elif not _shells_out and _open > 0.6:
		_shells_out = true
		_eject(_fired_in_load)
	var hinge: Transform3D = rest.get("barrels", Transform3D.IDENTITY)
	var turn := Transform3D(Basis(Vector3.RIGHT, BARREL_BREAK * _open), Vector3.ZERO)
	_set_transform(&"barrels", hinge * turn)
	# the fore hand goes down with the barrels but tips only part of the
	# way: the forearm swings at the elbow, the wrist gives the rest
	var hand: Transform3D = rest.get("hand_l", Transform3D.IDENTITY)
	var hand_tip := Basis(Vector3.RIGHT, BARREL_BREAK * _open * FORE_HAND_TIP)
	_set_transform(&"hand_l", Transform3D(hand_tip * hand.basis, (hinge * turn * hinge.affine_inverse() * hand).origin))
	for i in 2:
		var down := 1.0 if _fired_in_load > i else 0.0
		_hammers[i] = ExhibitRig.ease_to(_hammers[i], down, 40.0 if down > 0.0 else 8.0, delta)
	_pose_part(&"hammer_r", Vector3(HAMMER_DOWN * _hammers[0], 0.0, 0.0))
	_pose_part(&"hammer_l", Vector3(HAMMER_DOWN * _hammers[1], 0.0, 0.0))
	# show the chambers: lift the gun back into view (the holder dips it),
	# tip the breech up toward the eye and roll it in
	var framing: Array = FRAMING[model_id]
	model.position = (framing[0] as Vector3) + Vector3(0.0, HOLDER_RELOAD_DROP, 0.0) * _lift + Vector3(-0.04, 0.03, 0.02) * _tilt + _reload_at
	model.rotation = Vector3(0.3, 0.12, 0.42) * _tilt + _framing_turn() + _reload_turn


func _animate_taser(state: WeaponState) -> void:
	if state == null:
		return
	var cost := maxf(state.data.battery_cost, 0.001)
	var charges := int(floor(state.battery / cost + 0.0001))
	for i in 3:
		var led := parts.get("led_%d" % (i + 1)) as Node3D
		if led == null:
			continue
		if i < charges:
			led.visible = true
		elif i == charges and state.battery < state.data.battery_max:
			led.visible = fmod(_time * 3.0, 1.0) < 0.5   # charging
		else:
			led.visible = false


func _animate_gatling(state: WeaponState, delta: float) -> void:
	var speed := state.barrel_speed()
	_barrel_angle = wrapf(_barrel_angle + GatlingDriver.BARREL_SPEED * speed * delta, 0.0, TAU)
	_crank_angle = wrapf(_crank_angle - GatlingDriver.CRANK_SPEED * speed * delta, 0.0, TAU)
	_pose_part(&"barrels", Vector3(0.0, 0.0, _barrel_angle))
	_pose_part(&"crank", Vector3(_crank_angle, 0.0, 0.0))
	# the right hand rides the crank's knob (moved, never turned)
	var crank := part_node(&"crank")
	var knob := part_node(&"CrankKnob")
	if crank != null and knob != null and rest.has("hand_r"):
		var knob_rest: Vector3 = (rest["crank"] as Transform3D) * knob.position
		_pose_part(&"hand_r", Vector3.ZERO, crank.transform * knob.position - knob_rest)
	# the belt: tugged up into the hopper by every round, swaying as it feeds;
	# a new belt is hauled in (a long pull up) and the gun settles with a jolt
	_belt_tug = maxf(_belt_tug - delta / 0.06, 0.0)
	var change := state.reload_progress() if state.is_reloading() else 0.0
	var haul := ViewmodelMotion.bump(change, 0.1, 0.8)
	var settle := ViewmodelMotion.bump(change, 0.7, 1.0)
	var sway := sin(_time * 11.0) * 0.06 * speed + sin(_time * 1.7) * 0.015
	_pose_part(&"belt", Vector3(sway * 0.6, 0.0, sway), Vector3(0.0, BELT_TUG * _belt_tug + BELT_HAUL * haul, 0.0))
	_ease_reload_pose(Vector3(0.0, -0.01 * settle, 0.0), Vector3(-0.04 * settle, 0.0, 0.03 * haul), delta)
	_driver.update(state, delta)
	var glow := _driver.glow()
	_set_heat(glow * glow * GATLING_GLOW_ENERGY)
	var framing: Array = FRAMING[model_id]
	model.position = (framing[0] as Vector3) + _driver.jolt + _reload_at
	model.rotation = _framing_turn() + _reload_turn
	_flash_left = maxf(_flash_left - delta, 0.0)
	_flash.visible = _flash_left > 0.0


func _animate_flare(state: WeaponState, delta: float) -> void:
	var reloading := state.is_reloading()
	# keyed like the shotgun's: broken open, the round thumbed in, snapped shut
	var p := state.reload_progress() if reloading else 0.0
	_follow_hinge(_keyed_break(p) if reloading else 0.0, reloading, delta)
	_follow_tilt(_keyed_tilt(p) if reloading else 0.0, delta)
	_follow_lift(reloading, delta)
	var jolts: Array = _break_jolts(p, FLARE_ROUND) if reloading else [Vector3.ZERO, Vector3.ZERO]
	_ease_reload_pose(jolts[0], jolts[1], delta)
	_pose_part(&"barrel", Vector3(FLARE_BREAK * _open, 0.0, 0.0))
	# lift the gun back into view (the holder dips it) and tip the breech
	# up toward the eye
	var framing: Array = FRAMING[model_id]
	model.position = (framing[0] as Vector3) + Vector3(0.0, HOLDER_RELOAD_DROP, 0.0) * _lift + Vector3(-0.03, 0.02, 0.02) * _tilt + _reload_at
	model.rotation = Vector3(0.28, 0.1, 0.38) * _tilt + _framing_turn() + _reload_turn


## The gatling's own barrel material (it glows alone), its driver at the
## muzzle and the muzzle flash.
func _setup_gatling() -> void:
	var barrels := part_node(&"barrels") as MeshInstance3D
	if barrels != null:
		for i in barrels.mesh.get_surface_count():
			var source := barrels.get_surface_override_material(i) as BaseMaterial3D
			if source == null:
				continue
			# the glow follows the painted steel (dark bluing glows dull,
			# worn edges brighter) instead of flooding the part in one colour
			var hot := source.duplicate() as BaseMaterial3D
			hot.emission_enabled = true
			hot.emission = GATLING_GLOW
			hot.emission_texture = source.albedo_texture
			hot.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
			hot.emission_energy_multiplier = 0.0
			barrels.set_surface_override_material(i, hot)
			_hot_materials.append(hot)
	_hot_energy = 0.0
	_driver = GatlingDriver.new()
	_driver.position = muzzle.position
	add_child(_driver)
	_flash = MeshInstance3D.new()
	_flash.name = "MuzzleFlash"
	_flash.mesh = _flash_mesh()
	_flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_flash.layers = ArtLibrary.VIEWMODEL_LAYER
	_flash.visible = false
	muzzle.add_child(_flash)


func _set_heat(energy: float) -> void:
	if is_equal_approx(energy, _hot_energy):
		return
	_hot_energy = energy
	for hot in _hot_materials:
		hot.emission_energy_multiplier = energy


## A soft star of fire facing the eye (additive, drawn with the viewmodel
## field of view).
static func _flash_mesh() -> QuadMesh:
	var quad := QuadMesh.new()
	quad.size = Vector2(0.17, 0.17)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.billboard_keep_scale = true
	material.albedo_texture = _flash_texture()
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	material.albedo_color = Color(2.0, 1.7, 1.3)
	material.use_fov_override = true
	material.fov_override = ArtLibrary.VIEWMODEL_FOV
	material.use_z_clip_scale = true
	material.z_clip_scale = ArtLibrary.VIEWMODEL_Z_CLIP
	quad.material = material
	return quad


## A pixel star of fire (24 x 24): a hot core, four long rays and four
## short ones, white-yellow fading to orange.
static func _flash_texture() -> ImageTexture:
	var size := 24
	var image := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	var half := (size - 1) * 0.5
	for y in size:
		for x in size:
			var d := Vector2(x - half, y - half) / half
			var core := 1.0 - clampf(d.length() / 0.45, 0.0, 1.0)
			var straight := maxf(1.0 - absf(d.x) / 0.1, 0.0) * (1.0 - absf(d.y)) + maxf(1.0 - absf(d.y) / 0.1, 0.0) * (1.0 - absf(d.x))
			var diagonal := maxf(1.0 - absf(d.x - d.y) / 0.12, 0.0) * (1.0 - d.length() / 0.8) + maxf(1.0 - absf(d.x + d.y) / 0.12, 0.0) * (1.0 - d.length() / 0.8)
			var heat := clampf(core * 1.4 + straight * 0.9 + maxf(diagonal, 0.0) * 0.6, 0.0, 1.0)
			var color := Color(1.0, 0.45, 0.1).lerp(Color(1.0, 0.97, 0.8), heat)
			image.set_pixel(x, y, Color(color.r, color.g, color.b, heat))
	return ImageTexture.create_from_image(image)


## The bolt cycle after a shot: a beat of recoil, the handle lifts, the
## bolt runs back (the hand rides the knob), forward, and the handle comes
## down. Empty: it stays open. Reloading: the rifle tips, the bolt eases
## open, the left hand brings and presses in a clip of five
## (_reload_left_hand); when the clip is in, the bolt runs home through the
## end of its cycle with the right hand on the knob.
func _animate_rifle(state: WeaponState, delta: float) -> void:
	if state == null:
		return
	var reloading := state.is_reloading()
	if _was_reloading and not reloading and state.magazine > 0:
		_cycle = RIFLE_CYCLE_AFTER_RELOAD.x   # the hand reaches the open bolt's knob first
		_cycle_length = RIFLE_CYCLE_AFTER_RELOAD.y
		_bolt_sound = true
	_was_reloading = reloading
	_cycle = minf(_cycle + delta / maxf(_cycle_length, 0.05), 1.0)
	var lift := 0.0
	var back := 0.0
	if reloading or state.magazine == 0:
		_bolt_open = ExhibitRig.ease_to(_bolt_open, 1.0, 14.0, delta)
		lift = _bolt_open
		back = _bolt_open
	else:
		_bolt_open = 0.0
		if _cycle < 1.0:
			lift = clampf(inverse_lerp(0.12, 0.3, _cycle), 0.0, 1.0) * (1.0 - clampf(inverse_lerp(0.78, 0.92, _cycle), 0.0, 1.0))
			back = clampf(inverse_lerp(0.3, 0.5, _cycle), 0.0, 1.0) * (1.0 - clampf(inverse_lerp(0.58, 0.76, _cycle), 0.0, 1.0))
			if not _bolt_sound and _cycle >= 0.3:
				_bolt_sound = true
				Sfx.play(&"rifle_bolt", -4.0)
	_pose_part(&"bolt", Vector3(0.0, 0.0, BOLT_LIFT * _smooth(lift)), Vector3(0.0, 0.0, BOLT_TRAVEL * _smooth(back)))
	if _eject_pending and maxf(back, _bolt_open) > 0.5:
		_eject_pending = false
		_eject(1)   # the bolt runs back: out flies the casing
	var knob := part_node(&"BoltKnob")
	var bolt := part_node(&"bolt")
	if knob != null and bolt != null and rest.has("hand_r") and rest.has("bolt"):
		var knob_rest: Vector3 = (rest["bolt"] as Transform3D) * knob.position
		var want := BOLT_HAND_FOLLOW * maxf(_smooth(lift), _smooth(back)) * (0.0 if reloading else 1.0)
		var follow := ViewmodelMotion.follow(_knob_follow, _knob_follow_v, want, RIFLE_KNOB_OMEGA, delta)
		_knob_follow = follow.x
		_knob_follow_v = follow.y
		_pose_part(&"hand_r", Vector3.ZERO, (bolt.transform * knob.position - knob_rest) * _knob_follow)
	_reload_left_hand(state, reloading, delta)
	# springs: the reload's end hands over to the bolt's run home without a
	# jump (the gun comes back from the reload while the bolt pushes it)
	_follow_open(1.0 if reloading else 0.0, RIFLE_OPEN_OMEGA if reloading else RIFLE_BACK_OMEGA, delta)
	var work := maxf(_smooth(lift), _smooth(back)) * (0.0 if reloading else 1.0)
	var push := ViewmodelMotion.follow(_bolt_push, _bolt_push_v, work, RIFLE_PUSH_OMEGA, delta)
	_bolt_push = push.x
	_bolt_push_v = push.y
	model.position = (FRAMING[model_id][0] as Vector3) + RIFLE_RELOAD_SHIFT * _open + BOLT_PUSH * _bolt_push
	model.rotation = RIFLE_RELOAD_TURN * _open + _framing_turn()


## The rifle's reload by the left hand (RELOAD_KEYS): the hand is posed by
## where its grip goes, between keyed grip poses (origins blended, turns
## slerped, smoothly in and out of every key), its elbow keyed with it. The
## clip rides the fist's grip while held (hanging from the little-finger
## side, bullets forward), then flies off and is gone. A reload cut short
## brings the hand back smoothly.
func _reload_left_hand(state: WeaponState, reloading: bool, delta: float) -> void:
	var arm := _arm("l")
	var clip := part_node(&"clip")
	if arm == null or clip == null or _reload_grips.is_empty():
		return
	var p := state.reload_progress() if reloading else 0.0
	var pose := _reload_pose(p)
	var hand_root: Transform3D = (pose[0] as Transform3D) * arm.grip.transform.affine_inverse()
	var want := _root_transform(arm.hand.get_parent() as Node3D).affine_inverse() * hand_root
	if reloading:
		arm.hand.transform = want
		arm.elbow_set = _root_transform(arm.wrist).origin + (pose[1] as Vector3)
		arm.elbow_is_set = true
	else:
		arm.hand.transform = arm.hand.transform.interpolate_with(want, 1.0 - exp(-14.0 * delta))
	var shown := reloading and p >= CLIP_SHOWN.x and p < CLIP_SHOWN.y
	clip.visible = shown
	_clip_held = shown and p < CLIP_FLICK_AT
	if not shown:
		clip.transform = rest["clip"]
		return
	var grip_root: Transform3D = _root_transform(arm.grip) if _clip_held else (_reload_pose(CLIP_FLICK_AT)[0] as Transform3D)
	var clip_root := grip_root * _clip_in_fist(arm, clip)
	if not _clip_held:
		var t := (p - CLIP_FLICK_AT) * state.data.reload_time
		clip_root = Transform3D(Basis(clip_root.basis.x.normalized(), FLICK_SPIN * t) * clip_root.basis, clip_root.origin + FLICK_SPEED * t)
	clip.transform = _root_transform(clip.get_parent() as Node3D).affine_inverse() * clip_root


## The keyed grip poses and elbow offsets of the rifle's reload (root
## space), from the markers and the clip's rest in the guides.
func _setup_reload() -> void:
	var arm := _arm("l")
	var clip := part_node(&"clip")
	if arm == null or clip == null:
		return
	var at_rest := _root_transform(arm.grip)
	var clip_rest := _root_transform(clip)
	# the clip standing straight in the guides fixes the hand: thumb (grip
	# axis) up along the clip, the bullets out of the fist's front
	var inserted := Basis(-arm.sx * clip_rest.basis.z, -arm.sx * clip_rest.basis.x, clip_rest.basis.y)
	var in_fist := _clip_in_fist(arm, clip)
	var at_action := Transform3D(inserted, clip_rest.origin - inserted * in_fist.origin)
	var reach := (arm.elbow_rest - arm.wrist_rest).length()
	var at_pouch := Transform3D(_grip_basis_for(ELBOW_POUCH.normalized(), THUMB_POUCH.normalized()), at_rest.origin + POUCH_DROP)
	var pressed := at_action.translated(Vector3(0.0, -PRESS, 0.0))
	var lifted := at_action.translated(LIFT)
	_reload_grips.assign([at_rest, at_pouch, at_pouch, at_action, at_action, pressed, pressed, lifted, at_rest])
	var off_rest := arm.elbow_rest - arm.wrist_rest
	var off_pouch := ELBOW_POUCH.normalized() * reach
	var off_action := ELBOW_ACTION.normalized() * reach
	_reload_elbows.assign([off_rest, off_pouch, off_pouch, off_action, off_action, off_action, off_action, off_action, off_rest])


## [the grip's pose (root space), the elbow's offset from the wrist] at
## reload fraction [param p].
func _reload_pose(p: float) -> Array:
	var k := 0
	while k + 1 < RELOAD_KEYS.size() - 1 and RELOAD_KEYS[k + 1] < p:
		k += 1
	var span := RELOAD_KEYS[k + 1] - RELOAD_KEYS[k]
	var t := _smooth(clampf((p - RELOAD_KEYS[k]) / span, 0.0, 1.0)) if span > 0.0 else 1.0
	var a := _reload_grips[k]
	var b := _reload_grips[k + 1]
	var pose := Transform3D(a.basis.slerp(b.basis, t), a.origin.lerp(b.origin, t))
	return [pose, _reload_elbows[k].lerp(_reload_elbows[k + 1], t)]


## Where the held clip sits in the grip marker's space: its axis along the
## thumb's, hanging from the little-finger side with its top CLIP_IN_FIST
## inside the fist, the bullets out of the fist's front (its back for the
## left hand's mirrored frame).
func _clip_in_fist(arm: Arm, clip: Node3D) -> Transform3D:
	var length := 0.066
	var mesh := clip as MeshInstance3D
	if mesh != null and mesh.mesh != null:
		length = mesh.get_aabb().size.y
	var basis := Basis(Vector3(0.0, -arm.sx, 0.0), Vector3(0.0, 0.0, 1.0), Vector3(-arm.sx, 0.0, 0.0))
	return Transform3D(basis, Vector3(0.0, 0.0, -(FIST_REACH - CLIP_IN_FIST + length)))


## The hand frame (the Grip marker's basis) of a fist whose grip axis is
## [param thumb] and whose straight-wrist forearm lies as close to
## [param forearm] as that allows: the knuckles away from the forearm.
static func _grip_basis_for(forearm: Vector3, thumb: Vector3) -> Basis:
	var z := thumb.normalized()
	var y := -(forearm - z * forearm.dot(z)).normalized()
	return Basis(y.cross(z), y, z)


## The harpoon shows in the muzzle while loaded; after the shot it is gone,
## during the reload it slides back in from the front (and the reel spins).
func _animate_harpoon(state: WeaponState, delta: float) -> void:
	if state == null:
		return
	var reloading := state.is_reloading()
	var progress := state.reload_progress() if reloading else 1.0
	var head := part_node(&"head")
	if head != null:
		head.visible = state.magazine > 0 or (reloading and progress > 0.35)
		var out := 1.0 - clampf(inverse_lerp(0.35, 0.9, progress), 0.0, 1.0) if reloading else 0.0
		_pose_part(&"head", Vector3.ZERO, Vector3(0.0, 0.0, -HARPOON_LOAD_OUT * _smooth(out)))
	if reloading:
		_reel_angle = wrapf(_reel_angle + REEL_SPIN * delta, 0.0, TAU)
	_pose_part(&"reel_crank", Vector3(_reel_angle, 0.0, 0.0))
	_follow_open(1.0 if reloading else 0.0, HARPOON_TIP_OMEGA if reloading else HARPOON_BACK_OMEGA, delta)
	_follow_lift(reloading, delta)
	# the harpoon rammed home on its wad: the gun jolts back
	var home := ViewmodelMotion.bump(progress, 0.86, 0.98) if reloading else 0.0
	_ease_reload_pose(Vector3(0.0, 0.006 * home, 0.012 * home), Vector3(0.05 * home, 0.0, 0.0), delta)
	model.position = (FRAMING[model_id][0] as Vector3) + Vector3(0.0, HOLDER_RELOAD_DROP, 0.0) * _lift + Vector3(-0.02, 0.03, 0.03) * _open + _reload_at
	model.rotation = Vector3(0.3 * _open, 0.06 * _open, 0.18 * _open) + _framing_turn() + _reload_turn


## One arrow per tube, as many as a volley has; each one fired is gone
## (the reload runs from the first arrow on, but the tubes are refilled
## only once the volley is over), pushed back in one by one; the match
## glows.
func _animate_hwacha(state: WeaponState, delta: float) -> void:
	if state == null:
		return
	var count := maxi(state.data.volley_count, 1)
	var reloading := state.is_reloading()
	var progress := state.reload_progress() if reloading else 1.0
	if state.magazine > 0 and not reloading:
		_fired.clear()
	for i in 9:
		var rocket := part_node(StringName("rocket_%d" % (i + 1)))
		if rocket == null:
			continue
		var back_at := 0.25 + 0.65 * float(i) / float(count)
		var refilled := reloading and progress >= back_at
		rocket.visible = i < count and (not _fired.has(i) or refilled)
		var sink := 0.0
		if _fired.has(i) and refilled:
			sink = 1.0 - clampf((progress - back_at) / 0.1, 0.0, 1.0)
		_pose_part(StringName("rocket_%d" % (i + 1)), Vector3.ZERO, Vector3(0.0, 0.0, ROCKET_SINK * sink))
	if _ember != null:
		_ember.light_energy = 0.35 + 0.12 * sin(_time * 17.0) + 0.08 * sin(_time * 29.0 + 1.1)
	_open = ExhibitRig.ease_to(_open, 1.0 if reloading else 0.0, 8.0 if reloading else 12.0, delta)
	# every arrow pushed home jolts the chest a little (its weight in the hands)
	var seat := 0.0
	if reloading:
		for i in count:
			var back_at := 0.25 + 0.65 * float(i) / float(count)
			seat += ViewmodelMotion.bump(progress, back_at + 0.02, back_at + 0.1)
	_ease_reload_pose(Vector3(0.0, -0.007 * seat, 0.0), Vector3(-0.035 * seat, 0.0, 0.0), delta)
	model.position = (FRAMING[model_id][0] as Vector3) + Vector3(0.0, HOLDER_RELOAD_DROP * 0.8, 0.02) * _open + _reload_at
	model.rotation = Vector3(-0.25 * _open, 0.0, 0.12 * _open) + _framing_turn() + _reload_turn


## The slow match's ember: a tiny warm light on the first-person layer.
func _setup_hwacha() -> void:
	var ember := part_node(&"Ember")
	_ember = OmniLight3D.new()
	_ember.name = "EmberLight"
	_ember.light_color = Color(1.0, 0.45, 0.15)
	_ember.light_energy = 0.4
	_ember.omni_range = 0.25
	_ember.light_cull_mask = ArtLibrary.VIEWMODEL_LAYER
	_ember.shadow_enabled = false
	if ember != null:
		ember.add_child(_ember)
	else:
		model.add_child(_ember)


## After the weapon's own pose: the inspection (it turns to show its side,
## lifts, a glint on what is new) and the master finish's breathing glow.
func _finish_pose(delta: float) -> void:
	if not _glow_materials.is_empty():
		var energy := _glow_base + MASTER_GLOW_BREATH * (_glow_base / MASTER_GLOW) * sin(_time * 2.1)
		for material in _glow_materials:
			material.emission_energy_multiplier = energy
	if _inspect_left > 0.0:
		var before := _inspect_left
		_inspect_left = maxf(_inspect_left - delta, 0.0)
		var t := 1.0 - _inspect_left / INSPECT_TIME
		var w := sin(PI * _smooth(t))
		var turn := Transform3D(Basis.from_euler(Vector3(0.3 * w, 0.85 * w, 0.28 * w)), Vector3(-0.06 * w, 0.07 * w, 0.06 * w))
		model.transform = turn * model.transform
		var at := INSPECT_TIME - GLINT_AT
		if before > at and _inspect_left <= at:
			_show_glint()
	if _glint != null and _glint.visible:
		_glint.scale = _glint.scale.move_toward(Vector3.ZERO, delta * 3.0)
		_glint.visible = _glint.scale.x > 0.01
	_first_look_pose(delta)
	_aim_arms()
	_place_muzzle()


## The first look at a found weapon, over the weapon's own pose (it waits
## for an upgrade's inspection to end): keyed (FIRST_LOOK), eased from key
## to key; cut short, its weight lets go within a few frames.
func _first_look_pose(delta: float) -> void:
	if _first_left <= 0.0 or _inspect_left > 0.0:
		return
	_first_left = maxf(_first_left - delta, 0.0)
	var weight := 1.0
	if _first_cut:
		_first_cut_t += delta
		weight = 1.0 - smoothstep(0.0, LOOK_LET_GO, _first_cut_t)
		if _first_cut_t >= LOOK_LET_GO:
			_first_left = 0.0
	var keys: Array = FIRST_LOOK[ViewmodelMotion.grip_of(weapon_id)]
	var pose: Array = ViewmodelMotion.keyed(keys, 1.0 - _first_left / first_look_time())
	var turn := Transform3D(Basis.from_euler((pose[1] as Vector3) * weight), (pose[0] as Vector3) * weight)
	model.transform = turn * model.transform


## The arms of a two-handed model: their parts and markers, their rest.
func _setup_arms() -> void:
	for side in ["l", "r"]:
		var arm := Arm.new()
		arm.side = side
		arm.sx = 1.0 if side == "r" else -1.0
		arm.hand = part_node(StringName("hand_" + side))
		arm.sleeve = part_node(StringName("sleeve_" + side))
		arm.wrist = part_node(StringName("Wrist_" + side))
		arm.grip = part_node(StringName("Grip_" + side))
		var elbow := part_node(StringName("Elbow_" + side))
		if arm.hand == null or arm.sleeve == null or arm.wrist == null or arm.grip == null or elbow == null:
			continue
		arm.wrist_rest = _root_transform(arm.wrist).origin
		arm.elbow_rest = _root_transform(elbow).origin
		arm.sleeve_rest = _root_transform(arm.sleeve)
		arm.sleeve_dir = (arm.elbow_rest - arm.wrist_rest).normalized()
		arm.sleeve_dir_local = arm.sleeve_rest.basis.inverse() * arm.sleeve_dir
		_arms.append(arm)


## Every sleeve turned from its wrist toward its elbow (see the class
## notes); an elbow set by an animation counts for this frame only.
func _aim_arms() -> void:
	for arm in _arms:
		var wrist_now := _root_transform(arm.wrist).origin
		var elbow := arm.elbow_set if arm.elbow_is_set else arm.elbow_rest + (wrist_now - arm.wrist_rest) * ELBOW_FOLLOW
		arm.elbow_is_set = false
		var dir := (elbow - wrist_now).normalized()
		var in_root := Transform3D(_turn_between(arm.sleeve_dir, dir) * arm.sleeve_rest.basis, wrist_now)
		arm.sleeve.transform = _root_transform(arm.sleeve.get_parent() as Node3D).affine_inverse() * in_root


## The transform of [param node] in the model's root space (the glb's root
## node, [member model]): the parts' pivots compose up to it.
func _root_transform(node: Node3D) -> Transform3D:
	var out := Transform3D.IDENTITY
	var at: Node = node
	while at != null and at != model:
		out = (at as Node3D).transform * out
		at = at.get_parent()
	return out


## The shortest turn taking unit [param from] onto unit [param to].
static func _turn_between(from: Vector3, to: Vector3) -> Basis:
	var axis := from.cross(to)
	if axis.length_squared() < 1e-10:
		if from.dot(to) > 0.0:
			return Basis.IDENTITY
		var any := Vector3.UP if absf(from.y) < 0.9 else Vector3.RIGHT
		return Basis(from.cross(any).normalized(), PI)
	return Basis(axis.normalized(), from.angle_to(to))


func _arm(side: String) -> Arm:
	for arm in _arms:
		if arm.side == side:
			return arm
	return null


## The sides ("l", "r") of the arms this rig drives (none on a one-handed
## weapon).
func arm_sides() -> PackedStringArray:
	var out := PackedStringArray()
	for arm in _arms:
		out.append(arm.side)
	return out


## (flexion, radial deviation) in degrees of arm [param side]'s wrist as
## posed now: the sleeve's direction read in the Wrist marker's basis.
## Flexion bends toward the back of the hand (extension negative),
## deviation toward the thumb (ulnar negative). Vector2.ZERO without the arm.
func wrist_angles(side: String) -> Vector2:
	var arm := _arm(side)
	if arm == null:
		return Vector2.ZERO
	var dir := _root_transform(arm.sleeve).basis * arm.sleeve_dir_local
	var local := _root_transform(arm.wrist).basis.inverse() * dir
	return Vector2(rad_to_deg(atan2(local.x, -local.y)), rad_to_deg(atan2(arm.sx * local.z, -local.y)))


## True when [param angles] (wrist_angles()) are within the wrist limits.
static func wrist_within_limits(angles: Vector2) -> bool:
	return absf(angles.x) <= WRIST_FLEX_MAX and angles.y <= WRIST_RADIAL_MAX and angles.y >= -WRIST_ULNAR_MAX


## Where arm [param side]'s sleeve points now (root space): the wrist and
## the elbow it is aimed at (the rest forearm's length away).
func arm_line(side: String) -> PackedVector3Array:
	var arm := _arm(side)
	if arm == null:
		return PackedVector3Array()
	var wrist := _root_transform(arm.wrist).origin
	var dir := _root_transform(arm.sleeve).basis * arm.sleeve_dir_local
	return PackedVector3Array([wrist, wrist + dir * (arm.elbow_rest - arm.wrist_rest).length()])


## The Grip marker of arm [param side] in root space (the fist's grip point
## and hand frame).
func grip_transform(side: String) -> Transform3D:
	var arm := _arm(side)
	return _root_transform(arm.grip) if arm != null else Transform3D.IDENTITY


## True while the rifle's clip rides in the left hand.
func clip_held() -> bool:
	return _clip_held


## A gold star of light on the parts that just appeared (or the middle of
## the weapon), with a soft ting.
func _show_glint() -> void:
	if _glint == null:
		_glint = MeshInstance3D.new()
		_glint.name = "Glint"
		_glint.mesh = _flash_mesh()
		var gold := (_glint.mesh as QuadMesh).material.duplicate() as StandardMaterial3D
		gold.albedo_color = Color(1.8, 1.4, 0.7)
		_glint.material_override = gold
		_glint.layers = ArtLibrary.VIEWMODEL_LAYER
		_glint.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_glint)
	var at := Vector3.ZERO
	var found := 0
	for part in _new_parts:
		var node := part_node(StringName(part)) as VisualInstance3D
		if node != null:
			at += to_local(node.global_transform * node.get_aabb().get_center())
			found += 1
	if found > 0:
		at /= found
	else:
		at = model.transform.origin + Vector3(0.0, 0.02, -0.12)
	_glint.position = at
	_glint.scale = Vector3.ONE * 0.9
	_glint.visible = true
	Sfx.play(&"upgrade_forge", -12.0)


static func _smooth(t: float) -> float:
	return smoothstep(0.0, 1.0, t)


# --- the secrets' mods: their fittings on the model ------------------------------

## The fitting of mod [param mod] (WeaponLook.MODS) on this weapon, built
## the first time it is asked for (hidden until apply_look shows it; a mod
## of another weapon gives null): the carver's choke is a knurled brass
## collar round the muzzle end of the barrels, the peep sight a ring on a
## post on the rifle's tang behind the bolt, the return line a spool of
## sea-teal line on the harpoon gun's reel side. Model-root space, so each
## one rides the framing and the animations with the weapon.
func _mod_part(mod: StringName) -> MeshInstance3D:
	if _mod_parts.has(mod):
		return _mod_parts[mod]
	var spec: Dictionary = WeaponLook.MODS.get(mod, {})
	if spec.is_empty() or spec["weapon"] != WeaponLook.weapon_of_view(weapon_id):
		return null
	var fitting := MeshInstance3D.new()
	fitting.name = String(spec["part"])
	match mod:
		&"shotgun_choke":
			# a band round both barrels just behind their muzzle end (the
			# spread upgrade's own choke sits at the very end): oval, the
			# pair's cross-section (the spread choke's) and a few mm proud,
			# on the barrels so it breaks open with them
			var barrels := part_node(&"barrels")
			var end := part_node(&"upg_choke") as MeshInstance3D
			var size := Vector2(0.085, 0.044)
			var at := Vector3(0.0, 0.03, -0.571)
			if end != null:
				var box := end.get_aabb()
				size = Vector2(box.size.x, box.size.y)
				at = end.transform * box.get_center()
			fitting.mesh = _oval_band(size * 0.5, size * 0.5 + Vector2.ONE * CHOKE_PROUD, CHOKE_BAND)
			fitting.position = at + Vector3(0.0, 0.0, CHOKE_BEHIND)
			fitting.material_override = _fitting_material(FITTING_BRASS, 0.9, 0.35)
			_knurl(fitting, size * 0.5 + Vector2.ONE * CHOKE_PROUD, CHOKE_BAND)
			if barrels != null:
				barrels.add_child(fitting)
		&"rifle_peep":
			# a ring on a post, up on the tang behind the bolt's rear end
			var ring := TorusMesh.new()
			ring.inner_radius = 0.0036
			ring.outer_radius = 0.0064
			ring.rings = 16
			ring.ring_segments = 8
			fitting.mesh = ring
			fitting.rotation.x = PI * 0.5   # the ring stands up, facing the eye
			var bolt := part_node(&"bolt")
			var tang_z := (_root_transform(bolt).origin.z + 0.09) if bolt != null else 0.2
			fitting.position = Vector3(0.0, 0.054, tang_z)
			fitting.material_override = _fitting_material(FITTING_STEEL, 0.9, 0.3)
			# the post runs down from the ring to the tang (local +Z is down
			# once the ring stands up)
			var stem := BoxMesh.new()
			stem.size = Vector3(0.0045, 0.0045, 0.03)
			var post := _fitting_piece(stem, fitting.material_override)
			post.position = Vector3(0.0, 0.0, 0.019)
			fitting.add_child(post)
		&"harpoon_line":
			# a spool on the reel's side, ahead of the reel: a brass core and
			# flanges, the sea-teal line wound between them (axis along X)
			var core := CylinderMesh.new()
			core.top_radius = 0.011
			core.bottom_radius = 0.011
			core.height = 0.036
			core.radial_segments = 12
			fitting.mesh = core
			fitting.rotation.z = PI * 0.5
			var reel := part_node(&"upg_reel")
			var side := _root_transform(reel).origin if reel != null else Vector3(0.083, -0.024, 0.0)
			fitting.position = Vector3(maxf(side.x - 0.01, 0.06), side.y + 0.004, side.z - 0.1)
			fitting.material_override = _fitting_material(FITTING_BRASS, 0.9, 0.35)
			var disc := CylinderMesh.new()
			disc.top_radius = 0.017
			disc.bottom_radius = 0.017
			disc.height = 0.003
			disc.radial_segments = 12
			for end in [-1.0, 1.0]:
				var flange := _fitting_piece(disc, fitting.material_override)
				flange.position = Vector3(0.0, end * 0.0165, 0.0)
				fitting.add_child(flange)
			var wound := CylinderMesh.new()
			wound.top_radius = 0.0148
			wound.bottom_radius = 0.0148
			wound.height = 0.03
			wound.radial_segments = 12
			fitting.add_child(_fitting_piece(wound, _fitting_material(FITTING_THREAD, 0.0, 0.85)))
		_:
			return null
	fitting.layers = ArtLibrary.VIEWMODEL_LAYER
	fitting.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	fitting.visible = false
	if fitting.get_parent() == null:
		model.add_child(fitting)
	parts[String(fitting.name)] = fitting
	rest[String(fitting.name)] = fitting.transform
	_mod_parts[mod] = fitting
	return fitting


## Knurling on a band (oval [param radii] across X/Y, [param length]
## along Z): eight small ridges round it.
func _knurl(collar: MeshInstance3D, radii: Vector2, length: float) -> void:
	var box := BoxMesh.new()
	box.size = Vector3(0.005, 0.004, length * 0.7)
	var brass := _fitting_material(FITTING_BRASS.darkened(0.25), 0.9, 0.45)
	for i in 8:
		var ridge := _fitting_piece(box, brass)
		var angle := TAU * i / 8.0
		ridge.position = Vector3(cos(angle) * radii.x, sin(angle) * radii.y, 0.0)
		ridge.rotation.z = angle
		collar.add_child(ridge)


## An oval band along Z: its hole [param inner] (half-axes X/Y), its rim
## [param outer], [param length] long; the outer wall and both faces, each
## triangle both ways round (the fittings' material culls back faces; the
## inside lies on what the band is fitted round).
static func _oval_band(inner: Vector2, outer: Vector2, length: float) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var steps := 24
	var half := Vector3(0.0, 0.0, length * 0.5)
	for i in steps:
		var a := TAU * i / steps
		var b := TAU * (i + 1) / steps
		var oa := Vector3(cos(a) * outer.x, sin(a) * outer.y, 0.0)
		var ob := Vector3(cos(b) * outer.x, sin(b) * outer.y, 0.0)
		var ia := Vector3(cos(a) * inner.x, sin(a) * inner.y, 0.0)
		var ib := Vector3(cos(b) * inner.x, sin(b) * inner.y, 0.0)
		var out_a := Vector3(cos(a) * outer.y, sin(a) * outer.x, 0.0).normalized()
		var out_b := Vector3(cos(b) * outer.y, sin(b) * outer.x, 0.0).normalized()
		# the outer wall
		_both_ways(tool, [oa - half, ob - half, ob + half], [out_a, out_b, out_b])
		_both_ways(tool, [oa - half, ob + half, oa + half], [out_a, out_b, out_a])
		# the faces, front (-Z) and back (+Z)
		for face: float in [-1.0, 1.0]:
			var z := half * face
			var n := Vector3(0.0, 0.0, face)
			_both_ways(tool, [oa + z, ob + z, ib + z], [n, n, n])
			_both_ways(tool, [oa + z, ib + z, ia + z], [n, n, n])
	return tool.commit()


## A triangle both ways round: its normals as given one way, flipped the
## other.
static func _both_ways(tool: SurfaceTool, points: Array, normals: Array) -> void:
	for k in 3:
		tool.set_normal(normals[k])
		tool.add_vertex(points[k])
	for k in [2, 1, 0]:
		tool.set_normal(-(normals[k] as Vector3))
		tool.add_vertex(points[k])


## A piece of a fitting: [param mesh] under [param material], on the
## first-person layer and out of the shadows.
static func _fitting_piece(mesh: Mesh, material: Material) -> MeshInstance3D:
	var piece := MeshInstance3D.new()
	piece.mesh = mesh
	piece.material_override = material
	piece.layers = ArtLibrary.VIEWMODEL_LAYER
	piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return piece


## A plain material for the mods' fittings (shared), drawn like the
## viewmodel (its own FOV, squashed depth).
static func _fitting_material(color: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var key := "%s:%.2f:%.2f" % [color.to_html(), metallic, roughness]
	if _fitting_cache.has(key):
		return _fitting_cache[key]
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	material.metallic_specular = 0.6
	material.use_fov_override = true
	material.fov_override = ArtLibrary.VIEWMODEL_FOV
	material.use_z_clip_scale = true
	material.z_clip_scale = ArtLibrary.VIEWMODEL_Z_CLIP
	_fitting_cache[key] = material
	return material


func _animate_fist() -> void:
	var t := clampf(inverse_lerp(PUNCH_FROM, PUNCH_TO, position.z), 0.0, 1.0)
	model.rotation = Vector3(-0.15 * t, 0.12 * t, -0.45 * t) + _framing_turn()


func _framing_turn() -> Vector3:
	var framing: Array = FRAMING.get(model_id, [Vector3.ZERO, 1.0, Vector3.ZERO])
	return (framing[2] as Vector3) * PI / 180.0


func _pose_part(part_name: StringName, euler: Vector3, shift: Vector3 = Vector3.ZERO) -> void:
	var node := parts.get(String(part_name)) as Node3D
	if node == null:
		return
	var base: Transform3D = rest[String(part_name)]
	node.transform = Transform3D(base.basis * Basis.from_euler(euler), base.origin + shift)


func _set_transform(part_name: StringName, xform: Transform3D) -> void:
	var node := parts.get(String(part_name)) as Node3D
	if node != null:
		node.transform = xform


func _place_muzzle() -> void:
	muzzle.transform = model.transform * _muzzle_local
