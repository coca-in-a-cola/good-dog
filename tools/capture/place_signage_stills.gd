extends Node
## PLACE escalation signage stills (native renderer, independent Camera3D).
##   xvfb-run -a -s '-screen 0 1280x720x24' godot4 --path <project> --resolution 1280x720 \
##     --rendering-method forward_plus --rendering-driver vulkan --audio-driver Dummy \
##     res://tools/capture/place_signage_stills.tscn
## Rungs advance through the director's own run()/_expire() transitions (the same
## pressure_changed emission the ladder timer triggers); the overlay line is
## force-hidden so the world is visible. Ladder timing itself is covered by
## tests/test_place_signage.gd, not by these images.
## The level's prologue curtain (Hud/Curtain, opaque black) is only lowered by
## level._process, which this harness freezes, so it is hidden here (capture-only).
## Each still waits for frame_post_draw and is rejected unless it is 1280x720 and
## its sampled luma is finite, inside 0..1, spread (max-min > 0.05) and neither
## near-black nor blown out (mean 0.08..0.92). Poses match the screen-clearance
## test in tests/test_place_signage.gd. The placed shot also writes a 4x crop of
## the stick to INSPECT_DIR (outside the five stills) for close inspection.

const OUT_DIR := "res://evidence/place_signage/stills-v3"
const INSPECT_DIR := "res://evidence/place_signage/inspect-v3"

var level: Node3D
var cam: Camera3D
var failures := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()

func _run() -> void:
	var out := ProjectSettings.globalize_path(OUT_DIR)
	DirAccess.make_dir_recursive_absolute(out)
	GameState.state = &"playing"
	level = load("res://scenes/level.tscn").instantiate()
	get_tree().root.add_child(level)
	get_tree().current_scene = level
	for f in 3:
		await get_tree().process_frame
	Overlay.force_hide()
	level.player.set_physics_process(false)
	level.player.set_process(false)
	level.set_process(false)
	level.transform_ctl.set_process(false)
	level.get_node("PressureController").set_process(false)
	# Prologue never finishes with level._process frozen; lower its curtain here.
	level.curtain.visible = false
	# Observation gate stays as the route leaves it after GRAB; close the cell bars path.
	level._set_gate(level.observation_gate, true)
	cam = Camera3D.new()
	cam.name = "SignageCaptureCam"
	cam.fov = 75
	level.add_child(cam)
	cam.make_current()
	var director: CommandDirector = level.director
	director.run(load("res://data/commands/place.tres"))
	Overlay.force_hide()
	var entrance := [Vector3(0, 1.55, -21.0), Vector3(0, 1.0, -24.9)]
	var corner := [Vector3(3.3, 2.3, -21.1), Vector3(-1.2, 1.1, -25.6)]
	await _shot("rung0_first_instruction", entrance, 0)
	for i in 2:
		director._expire()
	Overlay.force_hide()
	await _shot("rung2_mid_escalation", entrance, 2)
	for i in 3:
		director._expire()
	Overlay.force_hide()
	await _shot("rung5_final_escalation", entrance, 5)
	await _shot("rung5_final_escalation_corner", corner, 5)
	# Placed: production eligibility path with the player at the walked spot.
	# Capture skips GRAB, so set the carry it would leave (walked E is in the tests).
	level.place_zone.carrying = true
	level.player.global_position = Vector3(0, 0, -23.8)
	for f in 6:
		await get_tree().physics_frame
	level.place_zone.interact()
	if not level.place_zone.visual.visible:
		failures += 1
		print("PLACE_SIGNAGE_STILL_FAIL placement did not show stick enabled=%s done=%s carrying=%s overlap=%s player=%s" % [level.place_zone.enabled, level.place_zone.done, level.place_zone.carrying, level.place_zone.area.overlaps_body(level.player), level.player.global_position])
	Overlay.force_hide()
	var img := await _shot("stick_placed_pedestal", [Vector3(1.1, 1.45, -22.7), Vector3(0, 0.45, -24.6)], 5)
	var crop := img.get_region(Rect2i(540, 320, 220, 100))
	crop.resize(880, 400, Image.INTERPOLATE_NEAREST)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(INSPECT_DIR))
	var crop_path := ProjectSettings.globalize_path(INSPECT_DIR).path_join("stick_placed_zoom4x.png")
	var crop_err := crop.save_png(crop_path)
	if crop_err != OK:
		failures += 1
	print("PLACE_SIGNAGE_INSPECT stick_placed_zoom4x err=%d region=(540,320,220,100) path=%s" % [crop_err, crop_path])
	print("PLACE_SIGNAGE_STILLS_COMPLETE failures=", failures)
	await _teardown(director)
	img = null
	crop = null
	director = null
	get_tree().quit(1 if failures else 0)

## Same retirement as tests/run_tests.gd: drop every retained ref to the level,
## free it while it is not current_scene, retire the Overlay autoload's audio,
## then give the mixer real time to release stopped playbacks before quitting.
func _teardown(director: CommandDirector) -> void:
	director.stop()
	Overlay.force_hide()
	AudioMix.reset()
	GameState.state = &"menu"
	get_tree().current_scene = self
	var gone: WeakRef = weakref(level)
	level.queue_free()
	level = null
	cam = null
	for f in 3:
		await get_tree().process_frame
	await get_tree().physics_frame
	var overlay := get_tree().root.get_node_or_null("Overlay")
	if overlay != null:
		overlay.force_hide()
		overlay.queue_free()
		await get_tree().process_frame
	var settle := Time.get_ticks_msec() + 300
	while Time.get_ticks_msec() < settle:
		await get_tree().process_frame
	print("PLACE_SIGNAGE_TEARDOWN level_freed=%s scene=%s" % [gone.get_ref() == null, get_tree().current_scene.name])

func _shot(label: String, pose: Array, rung: int) -> Image:
	level.signage.advance(2.0)
	cam.global_position = pose[0]
	cam.look_at(pose[1], Vector3.UP)
	for f in 3:
		await get_tree().process_frame
	var ok: bool = get_viewport().get_camera_3d() == cam and cam.global_position.is_equal_approx(pose[0])
	var count: int = level.signage.visible_count()
	ok = ok and level.signage.rung == rung and count == level.signage.COUNTS[rung]
	var pp: PostProcessController = level.get_node("PostProcess")
	var clear: bool = not level.curtain.visible and not Overlay.is_active() and not pp.blackout and pp.values.fade_black == 0.0
	ok = ok and clear
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var luma := _luma_stats(img)
	var ranged: bool = img.get_size() == Vector2i(1280, 720) and luma.is_finite() and luma.x >= 0.0 and luma.y <= 1.0
	ranged = ranged and luma.y - luma.x > 0.05 and luma.z > 0.08 and luma.z < 0.92
	ok = ok and ranged
	if not ok:
		failures += 1
	var path := ProjectSettings.globalize_path(OUT_DIR).path_join(label + ".png")
	var err := img.save_png(path)
	if err != OK:
		failures += 1
	print("PLACE_SIGNAGE_STILL %s ok=%s clear=%s ranged=%s luma_min_max_mean=%s rung=%d signs=%d size=%s cam=%s current=%s err=%d path=%s" % [label, ok, clear, ranged, luma, level.signage.rung, count, img.get_size(), cam.global_position, get_viewport().get_camera_3d().name, err, path])
	return img

## Min, max and mean luma over a 64x36 sample grid.
func _luma_stats(img: Image) -> Vector3:
	var lo := 1.0
	var hi := 0.0
	var sum := 0.0
	for y in 36:
		for x in 64:
			var l := img.get_pixel(x * img.get_width() / 64, y * img.get_height() / 36).get_luminance()
			lo = minf(lo, l)
			hi = maxf(hi, l)
			sum += l
	return Vector3(lo, hi, sum / (64 * 36))
