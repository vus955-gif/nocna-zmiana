class_name Layers
## Physics layer bits (names in [layer_names] of project.godot).

const WORLD := 1
const PLAYER := 2
const ENEMY := 4
const HURTBOX := 8
const DEBRIS := 16
const PICKUP := 32
## Things the guard can use with E (Interactable).
const INTERACT := 64
## Invisible walls only exhibits collide with (haven entrances).
const ENEMY_BLOCK := 128
## Audio only (layer 20): ReverbZone areas. Nothing collides with it and no
## ray looks for it; AudioStreamPlayer3D voices add it to their area_mask.
const REVERB_ZONE := 1 << 19
