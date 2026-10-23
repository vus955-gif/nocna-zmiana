class_name ReverbZone
extends Area3D
## Room acoustics for a space. Positional sounds (AudioStreamPlayer3D)
## inside the zone send part of their signal to the preset's reverb bus
## (ReverbHall / ReverbRoom / ReverbCorridor / ReverbVast / ReverbGallery /
## ReverbLibrary / ReverbGarden / ReverbConcrete in default_bus_layout.tres,
## ReverbStore / ReverbSteel / ReverbOpen made by Acoustics.ensure_buses();
## they return into SFXReturn, which follows the SFX slider). While the
## listener stands inside, Ambience also lends the SFX bus a touch of the
## room (LISTENER), so the guard's own shots ring in the hall.
## The zone sits on its own physics layer (Layers.REVERB_ZONE, layer 20
## "reverb_zone"): no body collides with it and no ray looks for it
## (hitscan and use-probes never see it). Ambience adds that layer to every
## Sfx voice's area_mask; Footsteps and ambience players set it themselves.
## Overlapping zones: a sound goes to the first zone Godot finds
## (AudioStreamPlayer3D ignores Area3D.priority), so zones that overlap
## should share a preset; for the listener's room the higher
## Area3D.priority wins.
## Place one per room: ReverbZone.make(ReverbZone.Preset.HALL, aabb) or a
## node in a scene with [member size] (base centred on the node, at floor
## level) or BoxShape3D children of its own.

## Floor I adds VAST (the court under its glass roof: a long, bright,
## late tail), GALLERY (a long stone gallery: flutter between parallel
## walls), LIBRARY (books and wood soak it up), GARDEN (open sky: a few
## walls answer) and CONCRETE (the basement: hard, bright, close); the
## acoustics pass (data/audio/acoustics.json) STORE (storerooms, closets,
## staff rooms: a boxy clap, almost no tail), STEEL (the boiler house, the
## plant room: ringing steel) and OPEN (the roof under the sky: next to no
## reverb, an echo off the buildings across the street). Every preset is an
## acoustic profile of that file, which also sets its bus's reverb at start.
enum Preset { HALL, ROOM, CORRIDOR, VAST, GALLERY, LIBRARY, GARDEN, CONCRETE, STORE, STEEL, OPEN }

const BUSES := {Preset.HALL: &"ReverbHall", Preset.ROOM: &"ReverbRoom", Preset.CORRIDOR: &"ReverbCorridor",
	Preset.VAST: &"ReverbVast", Preset.GALLERY: &"ReverbGallery", Preset.LIBRARY: &"ReverbLibrary",
	Preset.GARDEN: &"ReverbGarden", Preset.CONCRETE: &"ReverbConcrete", Preset.STORE: &"ReverbStore",
	Preset.STEEL: &"ReverbSteel", Preset.OPEN: &"ReverbOpen"}
## Default send level per preset.
const AMOUNTS := {Preset.HALL: 0.45, Preset.ROOM: 0.3, Preset.CORRIDOR: 0.3, Preset.VAST: 0.5, Preset.GALLERY: 0.42,
	Preset.LIBRARY: 0.25, Preset.GARDEN: 0.2, Preset.CONCRETE: 0.35, Preset.STORE: 0.25, Preset.STEEL: 0.38,
	Preset.OPEN: 0.15}
## The listener's room on the SFX bus: [room_size, damping, wet].
const LISTENER := {Preset.HALL: [0.85, 0.35, 0.16], Preset.ROOM: [0.35, 0.55, 0.07],
	Preset.CORRIDOR: [0.28, 0.25, 0.09], Preset.VAST: [0.95, 0.22, 0.18], Preset.GALLERY: [0.8, 0.45, 0.14],
	Preset.LIBRARY: [0.4, 0.85, 0.06], Preset.GARDEN: [0.25, 0.7, 0.05], Preset.CONCRETE: [0.5, 0.15, 0.1],
	Preset.STORE: [0.18, 0.7, 0.05], Preset.STEEL: [0.55, 0.08, 0.1], Preset.OPEN: [0.12, 0.85, 0.02]}

@export var preset: Preset = Preset.HALL
## Box size (m) when the zone has no BoxShape3D child of its own.
@export var size := Vector3(10.0, 4.0, 10.0)
## Send level 0..1; negative = the preset's default.
@export var amount: float = -1.0
## 0 = the send depends on where in the zone the sound is, 1 = even.
@export var uniformity: float = 0.3


## A zone filling [param box] (world space) with [param preset].
static func make(zone_preset: Preset, box: AABB, send: float = -1.0) -> ReverbZone:
	var zone := ReverbZone.new()
	zone.preset = zone_preset
	zone.size = box.size
	zone.amount = send
	zone.position = Vector3(box.position.x + box.size.x * 0.5, box.position.y, box.position.z + box.size.z * 0.5)
	return zone


func _ready() -> void:
	collision_layer = Layers.REVERB_ZONE
	collision_mask = 0
	monitoring = false
	monitorable = true
	reverb_bus_enabled = true
	reverb_bus_name = BUSES[preset]
	reverb_bus_amount = AMOUNTS[preset] if amount < 0.0 else amount
	reverb_bus_uniformity = uniformity
	if not AudioContext.has_box(self):
		add_child(AudioContext.floor_box(size))
	add_to_group(&"reverb_zones")


func contains(point: Vector3) -> bool:
	return AudioContext.box_contains(self, point)


## [room_size, damping, wet] for the listener reverb.
func listener_reverb() -> Array:
	return LISTENER[preset]
