class_name WeaponPalette
extends RefCounted
## One colour per weapon, the same everywhere the player meets it (backlog
## #11, #43): the slot digit lit in the HUD while the weapon is in hand, the
## rim light and the baked print of its ammo pickup (ArtLibrary), the
## greybox fallback (Pickup). Hues at least MIN_HUE_GAP apart, so seven
## kinds of ammo read apart under the moon, the lamps and the red emergency
## light; the shapes (SILHOUETTES) and the slot digits do the same job for
## the colour-blind. The option "colour_vision" swaps COLORS for a palette
## made for deuteranopia, protanopia or tritanopia (ColourVision): the slot
## and the rims follow it, the baked prints keep these. The medkit is the
## one white pickup, in every palette. The Blender side
## reads the same palette from tools/art/models/_pickup_palette.py (a test
## keeps the two in step).

## Weapon id -> its colour (sRGB).
const COLORS := {
	&"taser": Color(0.4, 0.8, 1.0),           # the battery bar's electric blue
	&"pistol": Color(0.3, 0.45, 1.0),         # blued steel; blue cartridge boxes
	&"shotgun": Color(0.92, 0.12, 0.1),       # red hulls
	&"gatling": Color(0.72, 0.85, 0.25),      # the olive crate's stencil, lit
	&"flare": Color(1.0, 0.42, 0.05),         # signal orange (with white bands)
	&"rifle_hunt": Color(0.2, 0.72, 0.36),    # hunter green card
	&"harpoon": Color(0.2, 0.78, 0.85),       # sea: the whalers' painted marks
	&"hwacha": Color(0.68, 0.36, 0.95),       # violet-dyed paper and silk
}
## Ammo type -> the weapon it feeds (the pickup wears that weapon's colour).
const AMMO_WEAPONS := {&"bullets": &"pistol", &"shells": &"shotgun", &"rifle": &"gatling", &"flares": &"flare",
		&"hunt_rounds": &"rifle_hunt", &"harpoons": &"harpoon", &"rockets": &"hwacha"}
## Ammo type -> its silhouette class: a proportion that still reads at
## thirty pixels (not a detail).
const SILHOUETTES := {
	&"bullets": &"box_brick",          # a small, tall box standing like a brick
	&"shells": &"box_flat",            # a wide, low box, shells lying across it
	&"rifle": &"crate_belt",           # the biggest: a wooden crate, the belt hanging down its side
	&"flares": &"tubes_upright",       # four fat tubes standing in a shallow box
	&"hunt_rounds": &"box_clip",       # a small flat box with a stripper clip in front
	&"harpoons": &"bundle_flat",       # a long lying bundle with big heads
	&"rockets": &"sheaf_upright",      # the one tall pickup: a standing sheaf of arrows
}
const MEDKIT_COLOR := Color(1.0, 0.96, 0.9)
const MEDKIT_SILHOUETTE := &"tin_handle"   # the one pickup with an arch on top
## Smallest hue distance (degrees) two kinds of ammo keep.
const MIN_HUE_GAP := 20.0
## Emission energy a pickup's material may carry (the exhibit shader
## multiplies it by 1.2 for an awake pickup): visible in the dark, no lamp.
const MAX_PICKUP_EMISSION := 1.2


## The colour of weapon [param weapon] in the player's colour-vision palette
## (ColourVision; COLORS in the standard one), white for an unknown id.
static func color(weapon: StringName) -> Color:
	return ColourVision.weapon(weapon, COLORS.get(weapon, Color.WHITE))


## The colour of the pickups of [param ammo]; the medkit's for &"medkit".
static func ammo_color(ammo: StringName) -> Color:
	if ammo == &"medkit":
		return MEDKIT_COLOR
	return color(AMMO_WEAPONS.get(ammo, &""))


## The silhouette class of the pickups of [param ammo].
static func silhouette(ammo: StringName) -> StringName:
	if ammo == &"medkit":
		return MEDKIT_SILHOUETTE
	return SILHOUETTES.get(ammo, &"")


## The weapon's slot in the HUD row, 1-based (0 for an unknown id).
static func slot(weapon: StringName) -> int:
	return WeaponHolder.SLOT_ORDER.find(weapon) + 1


## The digit painted on the pickups of [param ammo]: its weapon's slot
## ("" for the medkit).
static func digit(ammo: StringName) -> String:
	var weapon: StringName = AMMO_WEAPONS.get(ammo, &"")
	return str(slot(weapon)) if weapon != &"" else ""


## Hue distance of two colours in degrees, round the wheel (0..180).
static func hue_gap(a: Color, b: Color) -> float:
	var d := absf(a.h - b.h) * 360.0
	return minf(d, 360.0 - d)
