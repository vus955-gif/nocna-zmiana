class_name ColourVision
extends RefCounted
## The colour-blind palettes (option "colour_vision", plan
## 2026-10-21-dostepnosc, section 4): for deuteranopia, protanopia and
## tritanopia another colour for each weapon (the HUD slot in hand, the rim
## of its ammo pickups) and for the HUD's roles (the health and boss bars,
## the stamina bar's states, the fuses, the hit markers). The standard
## palette (NORMAL) is the game's own; WeaponPalette and the HUD ask here for
## the colour of the mode the player picked.
## The palettes are chosen by the numbers, not by taste
## (tools/accessibility: palette_search.py, role_search.py, swatches.py): the
## colours as a dichromat sees them are simulated after Machado, Oliveira &
## Fernandes 2009 (IEEE TVCG 15(6), 1291-1298; their matrices for severity
## 1.0, applied in linear RGB), two colours are as far apart as their CIE76
## distance (dE in CIE Lab, D65) after that simulation, and text and bars
## keep their WCAG contrast seen through it. Every weapon colour of a mode
## stays within 30 degrees of its standard hue and nearer its own standard
## colour than any other, so a box's baked print and its rim still agree.
## Smallest dE of two weapon colours (with the white medkit), seen in the
## mode the palette is for / seen normally:
##   standard 22.0 normally (deuteranopia 14.4, protanopia 2.4, tritanopia 5.2),
##   deuteranopia 30.1 / 38.1, protanopia 28.0 / 35.5, tritanopia 25.1 / 32.7.
## Colour is never the only cue: every weapon has its slot digit and its
## pickup's silhouette (WeaponPalette), the stamina bar hatches its fill
## while exhausted, a fuse carried is striped and one in the box solid with
## a filament, and each hit marker has its own shape (Hud.Crosshair).

const NORMAL := SettingsData.ColourVisionMode.NORMAL
const DEUTERANOPIA := SettingsData.ColourVisionMode.DEUTERANOPIA
const PROTANOPIA := SettingsData.ColourVisionMode.PROTANOPIA
const TRITANOPIA := SettingsData.ColourVisionMode.TRITANOPIA
const MODES: Array[int] = [NORMAL, DEUTERANOPIA, PROTANOPIA, TRITANOPIA]

## Machado et al. 2009, severity 1.0, rows of a 3x3 matrix on linear RGB.
const MATRICES := {
	DEUTERANOPIA: [0.367322, 0.860646, -0.227968, 0.280085, 0.672501, 0.047413, -0.011820, 0.042940, 0.968881],
	PROTANOPIA: [0.152286, 1.052583, -0.204868, 0.114503, 0.786281, 0.099216, -0.003882, -0.048116, 1.051998],
	TRITANOPIA: [1.255528, -0.076749, -0.178779, -0.078411, 0.930809, 0.147602, 0.004733, 0.691367, 0.303900],
}

## Mode -> weapon id -> its colour there (the standard ones are
## WeaponPalette.COLORS). tools/accessibility/palette_search.py --window 30
## --min-s 0.5 --identity 0.7 (--slack 0.05 for tritanopia).
const WEAPONS := {
	DEUTERANOPIA: {
		&"taser": Color("#80d4ff"), &"pistol": Color("#1975ff"), &"shotgun": Color("#f2184b"),
		&"gatling": Color("#ffff4d"), &"flare": Color("#ff6e19"), &"rifle_hunt": Color("#66ff8a"),
		&"harpoon": Color("#4dbfac"), &"hwacha": Color("#b257d9"),
	},
	PROTANOPIA: {
		&"taser": Color("#608fbf"), &"pistol": Color("#808cff"), &"shotgun": Color("#ff584d"),
		&"gatling": Color("#c5d941"), &"flare": Color("#f27e18"), &"rifle_hunt": Color("#57d97e"),
		&"harpoon": Color("#33e4ff"), &"hwacha": Color("#b433ff"),
	},
	TRITANOPIA: {
		&"taser": Color("#4d8abf"), &"pistol": Color("#8d79f2"), &"shotgun": Color("#f2181f"),
		&"gatling": Color("#a3bf13"), &"flare": Color("#ff7519"), &"rifle_hunt": Color("#7ed96c"),
		&"harpoon": Color("#66ffff"), &"hwacha": Color("#ae49f2"),
	},
}

## The HUD's roles in the standard palette.
const STANDARD_ROLES := {
	&"health": UiTheme.EMERGENCY,                       # the health bar's fill
	&"boss": UiTheme.EMERGENCY,                         # the boss's and a guardian's bar
	&"stamina_fill": Color(0.95, 0.8, 0.3),             # stamina, the bar's yellow
	&"stamina_exhausted": Color(1.0, 0.43, 0.33),       # exhausted: red
	&"stamina_caffeine": Color(0.96, 0.89, 0.72),       # caffeinated: the crema cream...
	&"stamina_caffeine_peak": Color(1.0, 0.97, 0.88),   # ...pulsing up to this
	&"fuse_carried": Color(1.0, 0.72, 0.35),            # in the guard's pocket: amber
	&"fuse_inserted": Color(0.35, 1.0, 0.5),            # in the fuse box: green
	&"hit": Color(1.0, 1.0, 1.0),                       # hit markers: a plain hit,
	&"hit_weak_point": Color(1.0, 0.8, 0.2),            # a weak point,
	&"hit_kill": Color(1.0, 0.25, 0.2),                 # a kill,
	&"hit_blocked": Color(0.6, 0.6, 0.6),               # blocked
}
## Mode -> the roles that change there (tools/accessibility/role_search.py:
## every pair of a group at least 40 dE apart seen in the mode, the bars at
## least 3:1 with their channel; the rest keep the standard colour). The
## caffeine's peak is its colour 55 % of the way to white - but for the
## tritanope that paler peak came within 18 dE of the plain fill (both read
## as a pale pink to him), so his caffeine pulses up to a brighter pink
## (role_search.py --peaks: every point of the pulse at least 40 dE from
## the fill and from exhaustion, seen in the mode and normally; the pulse
## itself about 10 dE).
const ROLES := {
	DEUTERANOPIA: {
		&"stamina_fill": Color("#ffd959"), &"stamina_exhausted": Color("#cc4129"),
		&"stamina_caffeine": Color("#e6e2c3"), &"stamina_caffeine_peak": Color("#f4f2e4"),
		&"fuse_carried": Color("#e6a92e"), &"fuse_inserted": Color("#33ff9f"),
		&"hit_kill": Color("#cc2014"),
	},
	PROTANOPIA: {
		&"health": Color("#e6442e"), &"boss": Color("#e6442e"),
		&"stamina_fill": Color("#ffd959"), &"stamina_exhausted": Color("#ff7259"),
		&"stamina_caffeine": Color("#fff8d9"), &"stamina_caffeine_peak": Color("#fffcee"),
		&"fuse_carried": Color("#b27512"), &"fuse_inserted": Color("#59ff7f"),
	},
	TRITANOPIA: {
		&"stamina_fill": Color("#e9ff80"), &"stamina_exhausted": Color("#e6522e"),
		&"stamina_caffeine": Color("#e6aa95"), &"stamina_caffeine_peak": Color("#ff9ea5"),
		&"hit_weak_point": Color("#e6ae2e"), &"hit_kill": Color("#ff4033"),
	},
}
## Role groups whose colours must read apart (role_search.py's groups; the
## two ends of a pulse are one state, PULSES).
const ROLE_GROUPS := {
	&"stamina": [&"stamina_fill", &"stamina_exhausted", &"stamina_caffeine", &"stamina_caffeine_peak"],
	&"fuses": [&"fuse_carried", &"fuse_inserted"],
	&"markers": [&"hit", &"hit_weak_point", &"hit_kill", &"hit_blocked"],
}
## Roles a bar swings between (one state: they need not read apart from
## each other, every point between them must from the rest of the group).
const PULSES: Array = [[&"stamina_caffeine", &"stamina_caffeine_peak"]]
## The roles that are bars filled over the HUD's dark channel.
const BAR_ROLES: Array[StringName] = [&"health", &"boss", &"stamina_fill", &"stamina_exhausted", &"stamina_caffeine", &"stamina_caffeine_peak"]
## D65 white of CIE Lab (XYZ, Y = 1).
const WHITE_XYZ := Vector3(0.95047, 1.0, 1.08883)


## The mode the player picked (SettingsData.ColourVisionMode).
static func current() -> int:
	return Settings.data.colour_vision


## The colour of weapon [param id] in [param mode]; [param standard] is its
## colour in the standard palette (and wherever the mode has none).
static func weapon(id: StringName, standard: Color, mode: int = -1) -> Color:
	if mode < 0:
		mode = current()
	return (WEAPONS.get(mode, {}) as Dictionary).get(id, standard)


## The colour of HUD role [param name] (STANDARD_ROLES) in [param mode]
## (the player's when left out).
static func role(name: StringName, mode: int = -1) -> Color:
	if mode < 0:
		mode = current()
	return (ROLES.get(mode, {}) as Dictionary).get(name, STANDARD_ROLES.get(name, Color.WHITE))


## [param color] as somebody with [param mode] sees it (alpha kept).
static func simulate(color: Color, mode: int) -> Color:
	if not MATRICES.has(mode):
		return color
	var m: Array = MATRICES[mode]
	var lin := Color(clampf(color.r, 0.0, 1.0), clampf(color.g, 0.0, 1.0), clampf(color.b, 0.0, 1.0)).srgb_to_linear()
	var seen := Color(
			clampf(m[0] * lin.r + m[1] * lin.g + m[2] * lin.b, 0.0, 1.0),
			clampf(m[3] * lin.r + m[4] * lin.g + m[5] * lin.b, 0.0, 1.0),
			clampf(m[6] * lin.r + m[7] * lin.g + m[8] * lin.b, 0.0, 1.0)).linear_to_srgb()
	return Color(seen, color.a)


## CIE Lab (D65) of sRGB [param color]: x = L*, y = a*, z = b*.
static func lab(color: Color) -> Vector3:
	var lin := Color(clampf(color.r, 0.0, 1.0), clampf(color.g, 0.0, 1.0), clampf(color.b, 0.0, 1.0)).srgb_to_linear()
	var x := (0.4124564 * lin.r + 0.3575761 * lin.g + 0.1804375 * lin.b) / WHITE_XYZ.x
	var y := (0.2126729 * lin.r + 0.7151522 * lin.g + 0.0721750 * lin.b) / WHITE_XYZ.y
	var z := (0.0193339 * lin.r + 0.1191920 * lin.g + 0.9503041 * lin.b) / WHITE_XYZ.z
	var fx := _lab_f(x)
	var fy := _lab_f(y)
	var fz := _lab_f(z)
	return Vector3(116.0 * fy - 16.0, 500.0 * (fx - fy), 200.0 * (fy - fz))


## CIE76 distance of [param a] and [param b] as seen in [param mode].
static func delta_e(a: Color, b: Color, mode: int = NORMAL) -> float:
	return lab(simulate(a, mode)).distance_to(lab(simulate(b, mode)))


## WCAG relative luminance of sRGB [param color].
static func luminance(color: Color) -> float:
	var lin := Color(clampf(color.r, 0.0, 1.0), clampf(color.g, 0.0, 1.0), clampf(color.b, 0.0, 1.0)).srgb_to_linear()
	return 0.2126 * lin.r + 0.7152 * lin.g + 0.0722 * lin.b


## WCAG contrast ratio (1..21) of [param a] and [param b] as seen in
## [param mode] (alpha ignored: the colours as drawn over each other).
static func contrast_seen(a: Color, b: Color, mode: int = NORMAL) -> float:
	var la := luminance(simulate(a, mode))
	var lb := luminance(simulate(b, mode))
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


static func _lab_f(t: float) -> float:
	if t > 216.0 / 24389.0:
		return pow(t, 1.0 / 3.0)
	return (24389.0 / 27.0 * t + 16.0) / 116.0
