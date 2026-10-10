class_name ExhibitMaterial
## What an exhibit is made of. Drives hit particles, debris colour and
## sounds: wax melts and splashes, taxidermy sheds sawdust, marble cracks,
## armour sparks and loses plates, old bone rattles apart into little bones,
## a portrait's canvas tears and its gilded frame splinters, a mummy's
## linen puffs dust and sheds bandage, carved wood (a totem, a jaguar
## warrior) knocks and throws cedar chips. Wax melts and old linen burns
## twice as fast in fire (fire_factor()).

enum Kind { WAX, TAXIDERMY, MARBLE, METAL, BONE, CANVAS, LINEN, WOOD }


## Colour of debris chunks.
static func color(kind: Kind) -> Color:
	match kind:
		Kind.WAX:
			return Color(0.93, 0.82, 0.62)
		Kind.TAXIDERMY:
			return Color(0.5, 0.38, 0.25)
		Kind.MARBLE:
			return Color(0.88, 0.88, 0.85)
		Kind.METAL:
			return Color(0.6, 0.62, 0.66)
		Kind.BONE:
			return Color(0.86, 0.8, 0.66)
		Kind.CANVAS:
			return Color(0.78, 0.6, 0.26)   # gilded frame splinters
		Kind.LINEN:
			return Color(0.62, 0.55, 0.42)   # resin-stained bandage
		Kind.WOOD:
			return Color(0.52, 0.27, 0.16)   # red cedar
	return Color.WHITE


## Colour of hit particles: wax drops, sawdust, stone dust, sparks.
static func particle_color(kind: Kind) -> Color:
	match kind:
		Kind.WAX:
			return Color(0.96, 0.78, 0.5)
		Kind.TAXIDERMY:
			return Color(0.86, 0.72, 0.48)
		Kind.MARBLE:
			return Color(0.92, 0.92, 0.9)
		Kind.METAL:
			return Color(1.0, 0.72, 0.3)
		Kind.BONE:
			return Color(0.9, 0.86, 0.74)
		Kind.CANVAS:
			return Color(0.84, 0.76, 0.6)   # canvas shreds and gesso dust
		Kind.LINEN:
			return Color(0.72, 0.66, 0.54)   # tomb dust
		Kind.WOOD:
			return Color(0.8, 0.62, 0.42)   # fresh chips
	return Color.WHITE


static func hit_sound(kind: Kind) -> StringName:
	match kind:
		Kind.WAX:
			return &"hit_wax"
		Kind.TAXIDERMY:
			return &"hit_sawdust"
		Kind.MARBLE:
			return &"hit_marble"
		Kind.BONE:
			return &"bone_hit"
		Kind.CANVAS:
			return &"hit_canvas"
		Kind.LINEN:
			return &"hit_linen"
		Kind.WOOD:
			return &"hit_wood"
	return &"hit_metal"


static func break_sound(kind: Kind) -> StringName:
	match kind:
		Kind.WAX:
			return &"break_wax"
		Kind.TAXIDERMY:
			return &"break_sawdust"
		Kind.MARBLE:
			return &"break_marble"
		Kind.BONE:
			return &"bone_rattle"
		Kind.CANVAS:
			return &"break_canvas"
		Kind.LINEN:
			return &"break_linen"
		Kind.WOOD:
			return &"break_wood"
	return &"break_metal"


## Damage multiplier of a hit of [param damage_kind] on [param kind]: wax
## and linen take fire double (the flare melts a wax figure and burns a
## mummy's bandages twice as fast).
static func fire_factor(kind: Kind, damage_kind: DamageInfo.Kind) -> float:
	if damage_kind != DamageInfo.Kind.FIRE:
		return 1.0
	return 2.0 if kind == Kind.WAX or kind == Kind.LINEN else 1.0
