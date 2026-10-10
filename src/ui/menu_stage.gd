class_name MenuStage
extends Node3D
## The main menu's live scene: the dressed Floor I (MuseumFloorLevel with
## the art and the real light recipe, no navigation, no exhibits, no guard,
## none of the game's systems; its shell comes from the same cache as the
## game's) with the sleeping T-Rex on its pedestal, and a camera that runs
## MenuRail's shots over the Great Court on a loop, black between them. It
## adds a little life: dust drifting in the moonbeams round the camera, a
## distant lamp that stutters now and then, a thin cloud passing the moon.
##
## Cheap on purpose: the graphics preset applies as in the game, the
## culler keeps lamps, dust, probes and fog on only in MENU_ROOMS, and a
## watchdog gives the scene up when frames come too slowly. The owner
## (MainMenu) shows the stage when [method prepare_view] has returned and
## drops it on [signal failed]: a build that fails, takes longer than
## BUILD_BUDGET_MSEC, or runs slowly leaves the static backdrop.

## The stage gives up (the menu keeps its static backdrop).
signal failed(reason: String)
## The camera moved on to another shot.
signal shot_changed(shot_id: StringName)

## The only rooms that keep their lamps lit: the court (and its Reading
## Room and balcony), the entrance hall and Egypt's vestibule and gallery.
const MENU_ROOMS := {
	&"court": true, &"court_reading": true, &"court_balcony": true,
	&"entrance_hall": true, &"entrance_gallery": true,
	&"egypt_vestibule": true, &"egypt_gallery": true,
}
## The default budget of a build (ms).
const BUILD_BUDGET_MSEC := 8000
## Passages from the camera's room whose lamps stay lit (RoomCuller depth):
## one is enough - Egypt's gallery is one passage from its vestibule, where
## the camera is when it looks down the nave.
const MENU_DEPTH := 1
## Frames the view is drawn behind the cover before it is shown (shaders,
## the lighting's first frames, the fog's history).
const WARM_FRAMES := 40
## The watchdog: over this many seconds of frames (the first SKIP_FRAMES
## left out) the typical one - the median, so a hitch while a shader
## compiles does not count - takes longer than SLOW_FRAME seconds: give up.
const WATCH_SECONDS := 2.0
const SKIP_FRAMES := 30
const SLOW_FRAME := 0.07
## The warm-up draws each shot at these fractions of its run, FRAMES_PER_VIEW
## frames each, so shaders and lights of the whole loop are ready behind the cover.
const WARM_VIEWS: Array[float] = [0.0, 0.5, 1.0]
const FRAMES_PER_VIEW := 2
## Dust round the camera (see MenuStage._add_dust()): the box, the amount.
const DUST_BOX := Vector3(16.0, 8.0, 16.0)
const DUST_AMOUNT := 150
## Seconds between a distant lamp's stutters, how far from the camera it
## must be, the stutter itself (energy fraction, seconds).
const FLICKER_EVERY := Vector2(7.0, 16.0)
const FLICKER_FAR := 14.0
const FLICKER_BEATS: Array[Vector2] = [Vector2(0.1, 0.07), Vector2(1.0, 0.09), Vector2(0.3, 0.05), Vector2(0.9, 0.12), Vector2(0.0, 0.06), Vector2(1.0, 0.0)]
## A cloud thins the moon: how often, how long, how much it takes.
const CLOUD_EVERY := Vector2(30.0, 60.0)
const CLOUD_LENGTH := 10.0
const CLOUD_DEPTH := 0.3

## True: the art kit (false only in tests that need a quick greybox).
var dressed: bool = true
## A build longer than this (ms) is thrown away.
var build_budget_msec: int = BUILD_BUDGET_MSEC
## Watch the frame rate in a headless run too (tests).
var watch_always: bool = false
## Scale of the hand-held drift (0 = a locked camera).
var drift_strength: float = 1.0
var level: MuseumFloorLevel = null
var camera: Camera3D = null
var trex: TRex = null
## The shots in play (MenuRail's, in the order of the loop).
var shots: Array[MenuRail.Shot] = []
var shot_index: int = 0
## Seconds into the shot; negative while the black fades out of the cut.
var shot_time: float = 0.0
var build_msec: int = 0
var fail_reason: String = ""
## Opacity of the black between two shots (0 = clear).
var dip: float = 0.0
var running: bool = false

var _dip_rect: ColorRect = null
var _dust: GPUParticles3D = null
var _moon: DirectionalLight3D = null
var _moon_base := Vector2.ONE
var _lamps: Array[Light3D] = []
var _lamp: Light3D = null
var _lamp_base: float = 1.0
var _beat: int = -1
var _beat_left: float = 0.0
var _flicker_in: float = 6.0
var _cloud_in: float = 20.0
var _cloud_left: float = 0.0
var _elapsed: float = 0.0
var _watch_frames: int = 0
var _watch_time: float = 0.0
var _watch_deltas := PackedFloat32Array()
var _rng := RandomNumberGenerator.new()


## Builds the level and everything round it, synchronously (the lighting
## and the shell take a few seconds); the stage must be in the tree. False
## when it fails (see [member fail_reason]); the stage is then to be freed.
func build() -> bool:
	var started := Time.get_ticks_msec()
	_rng.seed = 20261003
	if dressed and not (LevelArt.enabled and ArtLibrary.models_enabled):
		return _fail("the art kit is off")
	level = MuseumFloorLevel.new()
	level.name = "Level"
	level.art = dressed
	level.bake_navigation = false
	level.skip_kits = GateLocks.replaced_kits()
	add_child(level)
	level.build()
	if level.structure == null or level.structure.get_child_count() == 0:
		return _fail("the level has no structure")
	if dressed and level.culler == null:
		return _fail("the level was built without the art")
	if level.culler != null:
		level.culler.only_rooms = MENU_ROOMS
		level.culler.depth = MENU_DEPTH
	shots = MenuRail.shots()
	_add_trex()
	_add_camera()
	_add_dip()
	_add_dust()
	_find_lights()
	build_msec = Time.get_ticks_msec() - started
	if build_msec > build_budget_msec:
		return _fail("the build took %d ms" % build_msec)
	return true


## Draws every shot at a few moments of its run, then the start of the
## first shot [param frames] times - all behind whatever covers the view - so
## the shaders and lights of the whole loop are ready and the first frame
## shown is a finished one. Then [method start] runs the loop.
func prepare_view(frames: int = WARM_FRAMES) -> void:
	for index in shots.size():
		for fraction in WARM_VIEWS:
			show_shot(index, shots[index].seconds * fraction)
			for i in FRAMES_PER_VIEW:
				await get_tree().process_frame
				if not is_inside_tree():
					return
	show_shot(0, 0.0)
	for i in frames:
		await get_tree().process_frame
		if not is_inside_tree():
			return


func start() -> void:
	running = true
	_watch_frames = 0
	_watch_time = 0.0
	_watch_deltas.clear()


## Puts the camera in shot [param index] [param seconds_in] seconds in, the
## cut clear (no black); the culler follows at once.
func show_shot(index: int, seconds_in: float) -> void:
	if shots.is_empty():
		return
	shot_index = clampi(index, 0, shots.size() - 1)
	shot_time = seconds_in
	dip = 0.0
	if _dip_rect != null:
		_dip_rect.modulate.a = 0.0
	_place()
	_refill_dust()
	if level != null and level.culler != null:
		level.culler.update_from(camera.global_position)


func current_shot() -> MenuRail.Shot:
	return shots[shot_index] if not shots.is_empty() else null


## The camera pose the loop gives [param seconds_in] into shot [param index]
## (without the drift).
func pose_at(index: int, seconds_in: float) -> Transform3D:
	return shots[clampi(index, 0, shots.size() - 1)].pose(seconds_in)


func _process(delta: float) -> void:
	if not running or camera == null:
		return
	_elapsed += delta
	_advance(delta)
	_place()
	_live(delta)
	_watch(delta)


## Moves the loop on by [param delta] seconds: the black falls over the end
## of a shot, the cut hides in it, the next shot fades in out of it.
func _advance(delta: float) -> void:
	var shot := current_shot()
	shot_time += delta
	var half := MenuRail.DIP * 0.5
	if shot_time >= shot.seconds + half:
		_cut()
		shot = current_shot()
	if shot_time < 0.0:
		dip = smoothstep(0.0, 1.0, -shot_time / half)
	elif shot_time > shot.seconds:
		dip = smoothstep(0.0, 1.0, (shot_time - shot.seconds) / half)
	else:
		dip = 0.0
	_dip_rect.modulate.a = dip


## To the next shot, the camera there before the black lifts.
func _cut() -> void:
	shot_index = (shot_index + 1) % shots.size()
	shot_time = -MenuRail.DIP * 0.5
	_place()
	_refill_dust()
	if level != null and level.culler != null:
		level.culler.update_from(camera.global_position)
	shot_changed.emit(shots[shot_index].id)


func _place() -> void:
	var shot := current_shot()
	var at := clampf(shot_time, 0.0, shot.seconds)
	camera.global_transform = shot.pose(at) * MenuRail.handheld(_elapsed, drift_strength)
	camera.fov = shot.fov_at(at)
	if _dust != null:
		_dust.global_position = camera.global_position - camera.global_basis.z * 6.0


## The dust round the camera starts over where the camera now is (the
## emitter restarts with its pre-process: a full box at once, not a trickle).
func _refill_dust() -> void:
	if _dust != null:
		_dust.restart()


# --- the stage's parts ----------------------------------------------------------

## The T-Rex asleep on its pedestal (as the finale places it), with nobody to hunt.
func _add_trex() -> void:
	var marker: Variant = level.markers.get(Floor1Plan.TREX_MARKER)
	if marker == null:
		return
	var at: Transform3D = marker
	trex = TRex.new()
	trex.name = "TRex"
	trex.position = at.origin + Vector3.UP * 0.05
	trex.rotation.y = at.basis.get_euler().y
	add_child(trex)


func _add_camera() -> void:
	camera = Camera3D.new()
	camera.name = "Camera"
	camera.near = 0.05
	camera.far = 220.0
	camera.fov = 64.0
	# moved every frame by this node, not by the physics steps
	camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(camera)
	camera.make_current()


## The black of the cuts: above the 3D view, below the menu's own canvas.
func _add_dip() -> void:
	var layer := CanvasLayer.new()
	layer.name = "Dip"
	layer.layer = -1
	add_child(layer)
	_dip_rect = ColorRect.new()
	_dip_rect.color = Color(0.0, 0.0, 0.0)
	_dip_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dip_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dip_rect.modulate.a = 0.0
	layer.add_child(_dip_rect)


## A box of dust that travels with the camera, a few metres ahead of it:
## lit specks wherever a moonbeam or a lamp crosses it (the level's own
## motes stand still in their rooms; these give the parallax).
func _add_dust() -> void:
	var share := float(GraphicsQuality.preset().get("particles", 1.0))
	if share <= 0.0:
		return
	var box := AABB(-DUST_BOX * 0.5, DUST_BOX)
	_dust = Floor1LightRecipe.make_motes({"room": &"menu", "box": box, "amount": DUST_AMOUNT,
		"color": Floor1LightRecipe.DUST, "size": 0.04, "drift": -0.02})
	_dust.name = "MenuDust"
	_dust.amount_ratio = clampf(share, 0.0, 1.0)
	# where the first shot looks, so the dust it starts with is round the camera
	var first := shots[0].pose(0.0)
	_dust.position = first.origin - first.basis.z * 6.0
	add_child(_dust)


func _find_lights() -> void:
	if level.lights == null:
		return
	for node in level.lights.get_children():
		if node is DirectionalLight3D and _moon == null:
			_moon = node
			_moon_base = Vector2(_moon.light_energy, _moon.light_volumetric_fog_energy)
		elif node is Light3D and node.is_in_group(LightSpec.MAIN) and node.get_meta(&"room", &"") == &"court":
			_lamps.append(node)


# --- life ---------------------------------------------------------------------------

func _live(delta: float) -> void:
	_flicker_in -= delta
	if _beat >= 0:
		_beat_left -= delta
		if _beat_left <= 0.0:
			_next_beat()
	elif _flicker_in <= 0.0:
		_flicker_in = _rng.randf_range(FLICKER_EVERY.x, FLICKER_EVERY.y)
		stutter()
	_cloud_in -= delta
	if _cloud_left > 0.0:
		_cloud_left = maxf(_cloud_left - delta, 0.0)
		_set_moon(1.0 - CLOUD_DEPTH * pow(sin(PI * (1.0 - _cloud_left / CLOUD_LENGTH)), 2.0))
	elif _cloud_in <= 0.0:
		_cloud_in = _rng.randf_range(CLOUD_EVERY.x, CLOUD_EVERY.y)
		_cloud_left = CLOUD_LENGTH


## A court lamp far from the camera dips and drops out for a moment.
func stutter() -> void:
	if _lamps.is_empty() or camera == null:
		return
	var far: Array[Light3D] = []
	for lamp in _lamps:
		if is_instance_valid(lamp) and lamp.global_position.distance_to(camera.global_position) >= FLICKER_FAR:
			far.append(lamp)
	if far.is_empty():
		return
	_lamp = far[_rng.randi_range(0, far.size() - 1)]
	_lamp_base = _lamp.light_energy
	_beat = -1
	_next_beat()


func _next_beat() -> void:
	_beat += 1
	if _beat >= FLICKER_BEATS.size() or not is_instance_valid(_lamp):
		if is_instance_valid(_lamp):
			_lamp.light_energy = _lamp_base
		_beat = -1
		_lamp = null
		return
	var beat := FLICKER_BEATS[_beat]
	_lamp.light_energy = _lamp_base * beat.x
	_beat_left = beat.y


func _set_moon(fraction: float) -> void:
	if is_instance_valid(_moon):
		_moon.light_energy = _moon_base.x * fraction
		_moon.light_volumetric_fog_energy = _moon_base.y * fraction


## True while a lamp is in the middle of a stutter (tests).
func is_stuttering() -> bool:
	return _beat >= 0


# --- the watchdog ---------------------------------------------------------------------

func _watch(delta: float) -> void:
	if DisplayServer.get_name() == "headless" and not watch_always:
		return
	_watch_frames += 1
	if _watch_frames <= SKIP_FRAMES:
		return
	_watch_time += delta
	_watch_deltas.append(delta)
	if _watch_time < WATCH_SECONDS:
		return
	_watch_deltas.sort()
	var typical := _watch_deltas[_watch_deltas.size() >> 1]
	_watch_time = 0.0
	_watch_deltas.clear()
	if typical > SLOW_FRAME:
		_fail("frames take %.0f ms" % (typical * 1000.0))


func _fail(reason: String) -> bool:
	fail_reason = reason
	running = false
	push_warning("MenuStage: %s - the menu keeps its static backdrop" % reason)
	failed.emit(reason)
	return false
