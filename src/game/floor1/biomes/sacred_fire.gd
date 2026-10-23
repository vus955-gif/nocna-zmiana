class_name SacredFire
extends BiomeDevice
## The Americas' sacred fire (plan 2026-10-21-mechaniki-biomow, mechanic 6):
## a fire bowl of the wing (a "brazier" piece of the layout and its lamp,
## the bowl's flame model, the sparks and smoke over it) that a shot puts
## out: its light, flame and sparks go, a puff of smoke and a hiss, a few
## embers glow on. It rekindles by itself REKINDLE s later - its embers
## flicker REKINDLE_TELL s first - or at once from a fire shot (the flare
## gun's round) or a flare burning within FLARE_REACH m of it. The bowls
## are the totems' eyes (TotemSight): out of their firelight the guard is
## out of the totems' sight. No collision of its own (the bowl's piece is
## the level's); a hit zone over the bowl takes the shots.
## The fire keeps out of the power's way: a blackout, a power cut or a dark
## room switch the bowl's lamp, flame and sparks by their visibility, so the
## fire never touches that - it puts out the lamp's energy, the flame's
## opacity and the sparks' amount instead. A power cut does not relight a
## doused bowl, a bowl lit again in one stays dark till the power is back,
## and a bowl without power gives the totems no light (powered()).

const REKINDLE := 40.0
const REKINDLE_TELL := 2.0
const FLARE_REACH := 1.5
## The bowl's hit zone (the piece is 0.8 x 1.0 x 0.8 with its flame over it).
const ZONE := Vector3(0.95, 1.5, 0.95)
## The flame's middle over the bowl's foot (Floor1ArtAmericas.BOWL_FLAME-ish).
const FLAME_Y := 1.2
const EMBERS := Color(1.0, 0.32, 0.12)
const SMOKE := Color(0.3, 0.28, 0.26)
const CHECK := 0.25

## The bowl's foot (the brazier piece's position).
var bowl_at := Vector3.ZERO
## The layout's lamp of the bowl (its firelight).
var spec: LightSpec = null
var burning := true
## Times it was put out.
var douses: int = 0
## The bowl's own lamp, flame model and sparks/smoke (found on the built
## level; tests hand them in).
var light: Light3D = null
var flame: Node3D = null
var motes: Array[GPUParticles3D] = []

var _left: float = 0.0
var _check_left: float = 0.0
## The lamp's energy while it burns (-1: not read yet).
var _energy: float = -1.0
var _embers: OmniLight3D = null
var _flicker: float = 0.0


## Every fire bowl of the Americas' rooms [param host] serves (the
## Serpent's temple is an arena) and the totems' sight that reads them.
static func build_all(host: BiomeMechanics) -> Array[BiomeDevice]:
	var made: Array[BiomeDevice] = []
	var layout := host.layout()
	if layout == null:
		return made
	var bowls: Array[SacredFire] = []
	for piece in layout.pieces:
		if piece.kit != &"brazier" or not String(piece.room).begins_with("americas_") or not host.serves(piece.room):
			continue
		var fire := create(piece.position, _lamp_of(layout, piece))
		host.adopt(fire, StringName("americas_fire_%d" % bowls.size()), piece.room)
		bowls.append(fire)
		made.append(fire)
	if not bowls.is_empty():
		var sight := TotemSight.for_layout(layout, bowls, host)
		host.adopt(sight, &"americas_totem_sight", &"")
		made.append(sight)
	return made


## The layout's lamp over [param piece]'s flame (NW.fire puts it 1.3 m up).
static func _lamp_of(layout: LevelLayout, piece: PieceSpec) -> LightSpec:
	var best: LightSpec = null
	for lamp in layout.lights:
		if lamp.room == piece.room and Vector2(lamp.position.x - piece.position.x, lamp.position.z - piece.position.z).length() < 0.3:
			best = lamp
	return best


## A bowl at [param at] lit by [param lamp] (its firelight); add it yourself.
static func create(at: Vector3, lamp: LightSpec) -> SacredFire:
	var fire := SacredFire.new()
	fire.bowl_at = at
	fire.spec = lamp
	return fire


func _ready() -> void:
	top_level = true
	global_transform = Transform3D.IDENTITY
	if host != null and host.level != null:
		_find_parts(host.level)
	var sphere := BoxShape3D.new()
	sphere.size = ZONE
	var zone := Hurtbox.make(self, sphere, bowl_at + Vector3.UP * ZONE.y * 0.5)
	zone.name = "HitZone"
	add_child(zone)
	_embers = OmniLight3D.new()
	_embers.name = "Embers"
	_embers.light_color = EMBERS
	_embers.light_energy = 0.0
	_embers.omni_range = 1.6
	_embers.shadow_enabled = false
	_embers.visible = false
	_embers.position = bowl_at + Vector3.UP * 1.0
	add_child(_embers)


## True while the bowl's lamp has power (its circuit's switch, the power's
## business; a bowl without a lamp node always has).
func powered() -> bool:
	return light == null or not is_instance_valid(light) or light.is_visible_in_tree()


## True while it gives light: burning, with power.
func glowing() -> bool:
	return burning and powered()


## True while its embers flicker before it lights again.
func kindling() -> bool:
	return not burning and not frozen and _left <= REKINDLE_TELL


# --- the fire --------------------------------------------------------------------------

## A hit: a fire round lights it, anything else puts it out.
func take_damage(info: DamageInfo) -> void:
	if frozen:
		return
	if info != null and info.kind == DamageInfo.Kind.FIRE:
		kindle()
	else:
		douse()


## Puts the fire out. False when it was out.
func douse() -> bool:
	if not burning or frozen:
		return false
	burning = false
	douses += 1
	_left = REKINDLE
	_show(false)
	_tell_light_model(false)
	var top := bowl_at + Vector3.UP * FLAME_Y
	Fx.puff(top, SMOKE, 28, 0.5)
	Sfx.play_at(&"flare_burn", top, -2.0, 0.08, 0.55)
	return true


## Lights the fire again. False when it was burning.
func kindle() -> bool:
	if burning or frozen:
		return false
	burning = true
	_show(true)
	_tell_light_model(true)
	Fx.puff(bowl_at + Vector3.UP * FLAME_Y, EMBERS, 14, 0.35)
	Sfx.play_at(&"flare_fire", bowl_at + Vector3.UP * FLAME_Y, -6.0, 0.1, 0.8)
	return true


func _physics_process(delta: float) -> void:
	if burning:
		return
	# out stays out, whatever switched its lamp meanwhile
	if light != null and is_instance_valid(light) and light.light_energy != 0.0:
		light.light_energy = 0.0
	_left -= delta
	_flicker += delta
	if _embers != null:
		var glow := 0.25
		if _left <= REKINDLE_TELL:
			glow = 0.4 + 0.6 * absf(sin(_flicker * 13.0)) * (1.0 - _left / REKINDLE_TELL)
		_embers.light_energy = glow
	if _left <= 0.0:
		kindle()
		return
	_check_left -= delta
	if _check_left > 0.0:
		return
	_check_left = CHECK
	for at in FlareLight.lit_positions():
		if at.distance_to(bowl_at + Vector3.UP * 0.8) <= FLARE_REACH:
			kindle()
			return


func freeze() -> void:
	super()
	if _embers != null and not burning:
		_embers.light_energy = 0.25


## Shows the fire burning or out - by the lamp's energy, the flame's
## opacity and the sparks' amount, never by their visibility (the power's).
func _show(lit: bool) -> void:
	if light != null and is_instance_valid(light):
		if _energy < 0.0:
			_energy = light.light_energy
		light.light_energy = _energy if lit else 0.0
	if flame != null and is_instance_valid(flame):
		if flame is GeometryInstance3D:
			(flame as GeometryInstance3D).transparency = 0.0 if lit else 1.0
		else:
			flame.scale = Vector3.ONE if lit else Vector3.ONE * 0.001
	for particles in motes:
		if is_instance_valid(particles):
			particles.amount_ratio = 1.0 if lit else 0.0
	if _embers != null:
		_embers.visible = not lit
		_embers.light_energy = 0.25


## The bowl's lamp (under the level's lights), its flame model (under the
## brazier piece) and the sparks and smoke over it.
func _find_parts(level: MuseumFloorLevel) -> void:
	var top := bowl_at + Vector3.UP * FLAME_Y
	if level.lights != null:
		for node in level.lights.find_children("*", "Node3D", true, false):
			if node is Light3D and light == null and spec != null and (node as Node3D).global_position.distance_to(spec.position) < 0.3:
				light = node as Light3D
			elif node is GPUParticles3D and (node as Node3D).global_position.distance_to(top) < 1.0:
				motes.append(node as GPUParticles3D)
	if not is_inside_tree():
		return
	for node in get_tree().get_nodes_in_group(&"level_kit"):
		var piece := node as Node3D
		if piece == null or piece.get_meta(&"kit", &"") != &"brazier" or not level.is_ancestor_of(piece):
			continue
		if Vector2(piece.global_position.x - bowl_at.x, piece.global_position.z - bowl_at.z).length() < 0.3:
			for part in piece.find_children("*", "Node3D", true, false):
				if String(part.name) == "flame":
					flame = part as Node3D


## The exhibits' light model (PerceptionWorld.light_model: a
## LayoutIllumination) loses the bowl's firelight while it is out and has it
## back when it burns again (put_out / put_back; not the lamp's group switch,
## which stays the power's).
func _tell_light_model(lit: bool) -> void:
	var model := PerceptionWorld.light_model()
	if spec == null or model == null:
		return
	var change := &"put_back" if lit else &"put_out"
	if model.has_method(change):
		model.call(change, spec.position)
