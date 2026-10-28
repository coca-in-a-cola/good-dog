extends Node
## Capture-only driver for F1 evidence (not shipped; tools/ is excluded from export).
##
## Walkthrough (Movie Maker, deterministic):
##   xvfb-run -a godot4 --path <project> --audio-driver Dummy --rendering-method forward_plus \
##     --rendering-driver vulkan --write-movie evidence/f1/walkthrough.avi --fixed-fps 30 \
##     res://tools/capture/f1_capture.tscn
## Stills (1920x1080, 1080x1920, 2560x1080 SubViewports):
##   xvfb-run -a godot4 --path <project> --audio-driver Dummy --rendering-method forward_plus \
##     --rendering-driver vulkan res://tools/capture/f1_capture.tscn -- --stills=<abs dir>
##
## The overlay runs on its manual clock and is advanced exactly 1/FPS per rendered
## frame, so word intervals, the 0.35 s guard and the 0.25 s thaw land on the same
## frames regardless of how slowly the software renderer draws.

const FPS := 30.0
const DEMO_SCENE := preload("res://addons/command_overlay/demo/demo.tscn")
const OVERLAY_SCENE := preload("res://addons/command_overlay/overlay.tscn")
const LINE_DIR := "res://addons/command_overlay/demo/lines/"

var demo: Node
var ov: CanvasLayer
var failures := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var stills_dir := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--stills="):
			stills_dir = arg.trim_prefix("--stills=")
	if stills_dir.is_empty():
		_walkthrough.call_deferred()
	else:
		_stills.call_deferred(stills_dir)


func _line(file: String) -> OverlayLine:
	return load(LINE_DIR + file + ".tres")


func _press(keycode: Key) -> void:
	for pressed in [true, false]:
		var e := InputEventKey.new()
		e.keycode = keycode
		e.physical_keycode = keycode
		e.pressed = pressed
		Input.parse_input_event(e)
	Input.flush_buffered_events()


## Advances the overlay clock by one frame per rendered frame.
func _frames(seconds: float) -> void:
	for i in roundi(seconds * FPS):
		ov.advance_clock(1.0 / FPS)
		await get_tree().process_frame


func _expect(cond: bool, what: String) -> void:
	print("[capture] %s %s" % ["OK  " if cond else "FAIL", what])
	failures += 0 if cond else 1


func _world_restored(what: String) -> void:
	_expect(not ov.is_active() and not get_tree().paused and is_equal_approx(Engine.time_scale, 1.0),
			"%s: hidden, unpaused, time_scale %.3f" % [what, Engine.time_scale])


func _modal(line: OverlayLine, hold: float, what: String, key := KEY_K) -> void:
	ov.show_line(line)
	await _frames(hold)
	_press(key)
	await _frames(0.5 + line.hide_fade_time)
	_world_restored(what)


# --- Walkthrough --------------------------------------------------------------

func _walkthrough() -> void:
	demo = DEMO_SCENE.instantiate()
	add_child(demo)
	await get_tree().process_frame
	ov = demo.overlay
	ov.use_manual_clock = true
	await _frames(1.0)

	print("[capture] t=BLACK BARK.")
	await _modal(_line("bark"), 1.2, "BLACK BARK.", KEY_B)
	print("[capture] OVER_WORLD per-word GOOD. DOG.")
	var words := _line("good_dog_words")
	ov.show_line(words)
	await _frames(0.3)
	_expect(ov.get_displayed_text() == "GOOD.", "first word GOOD. at 0.3 s")
	await _frames(0.3)
	_expect(ov.get_displayed_text() == "DOG.", "second word DOG. at 0.6 s")
	await _frames(0.9)
	_press(KEY_K)
	await _frames(0.5)
	_world_restored("per-word GOOD. DOG.")
	print("[capture] FLASH NOW.")
	ov.show_line(_line("now_flash"))
	_expect(not get_tree().paused and is_equal_approx(Engine.time_scale, 1.0), "FLASH keeps world running")
	await _frames(1.2)
	_world_restored("FLASH NOW.")
	print("[capture] OVER_WORLD GRAB THE STICK.")
	await _modal(_line("grab_the_stick"), 1.4, "OVER_WORLD GRAB THE STICK.")
	print("[capture] long phrase")
	await _modal(OverlayLine.make("PLACE THE STICK HERE.", OverlayLine.Mode.OVER_WORLD, &"place"), 1.4,
			"long phrase PLACE THE STICK HERE.")
	print("[capture] BLACK red BAD DOG.")
	await _modal(_line("bad_dog"), 1.4, "BAD DOG.")
	print("[capture] finale")
	await _modal(_line("good_dog_finale"), 1.8, "finale YOU WERE A GOOD DOG!")
	print("[capture] sequence")
	demo._show_sequence()
	await _frames(1.0)
	_press(KEY_K)
	await _frames(1.0)
	_press(KEY_K)
	await _frames(1.5)
	_world_restored("sequence NOW. / GRAB THE STICK. / FLASH NOW.")

	print("[capture] dismissal-B probe")
	var barks_before: int = demo.barks_reaching_game
	ov.show_line(_line("bark"))
	await _frames(0.1)
	_press(KEY_B)  # inside the 0.35 s guard: swallowed, line stays
	_expect(ov.is_active(), "B at 0.1 s swallowed by the guard")
	await _frames(0.4)
	_press(KEY_B)  # dismisses; must not count as a bark
	await _frames(0.5)
	_expect(demo.barks_reaching_game == barks_before, "dismissal B did not reach the game")
	_press(KEY_B)  # control: a fresh B with no line up is a bark
	await _frames(0.3)
	_expect(demo.barks_reaching_game == barks_before + 1, "control B reaches the game")

	print("[capture] reduced flashes + reduced shake")
	ov.reduce_flashes = true
	ov.reduce_shake = true
	ov.show_line(_line("bark"))
	_expect(not ov._flash.visible and not ov._aberration.visible, "reduce_flashes: no white frame/aberration")
	await _frames(1.2)
	_press(KEY_K)
	await _frames(0.5)
	_world_restored("reduced flashes BARK.")
	ov.reduce_flashes = false
	ov.reduce_shake = false

	print("[capture] appear sounds started: %d" % ov.appear_sfx_count)
	print("[capture] finished, failures=%d" % failures)
	await _frames(0.5)
	get_tree().quit(1 if failures else 0)


# --- Stills -------------------------------------------------------------------

func _stills(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	var plan := {
		Vector2i(1920, 1080): ["bark", "good_dog_words", "now_flash", "grab_the_stick", "bad_dog",
				"good_dog_finale", "appear", "appear_reduced"],
		Vector2i(1080, 1920): ["bark", "grab_the_stick", "good_dog_finale"],
		Vector2i(2560, 1080): ["bark", "grab_the_stick", "good_dog_finale"],
	}
	for size: Vector2i in plan:
		var vp := SubViewport.new()
		vp.size = size
		vp.own_world_3d = true
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		add_child(vp)
		var world := DEMO_SCENE.instantiate()
		vp.add_child(world)
		var o: CanvasLayer = OVERLAY_SCENE.instantiate()
		o.use_manual_clock = true
		vp.add_child(o)
		await RenderingServer.frame_post_draw
		for shot: String in plan[size]:
			var line: OverlayLine
			var settle := 0.5
			o.reduce_flashes = shot == "appear_reduced"
			if shot.begins_with("appear"):
				line = _line("bark")
				settle = 0.03  # mid punch + aberration burst (white frame already shown)
			else:
				line = _line(shot)
				if line.per_word:
					settle = line.word_interval * (line.get_words().size() - 1) + 0.3
			o.show_line(line)
			# The white frame lasts exactly one process frame; let it pass before settling.
			await get_tree().process_frame
			o.advance_clock(settle)
			await RenderingServer.frame_post_draw
			await RenderingServer.frame_post_draw
			var path := dir.path_join("%dx%d_%s.png" % [size.x, size.y, shot])
			var err := vp.get_texture().get_image().save_png(path)
			print("[stills] %s -> %s (err %d, font %d, text %s)" % [shot, path, err, o.get_font_size(),
					o.get_displayed_text().c_escape()])
			failures += 0 if err == OK else 1
			o.force_hide()
		vp.queue_free()
		await get_tree().process_frame
	print("[stills] finished, failures=%d" % failures)
	await get_tree().create_timer(0.3, true, false, true).timeout
	get_tree().quit(1 if failures else 0)
