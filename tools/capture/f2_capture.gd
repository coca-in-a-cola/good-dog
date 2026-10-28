extends Node
## Capture-only F2 walkthrough driver (not shipped; tools/ is excluded from export).
##
##   xvfb-run -a godot4 --path <project> --rendering-method forward_plus --rendering-driver vulkan \
##     --write-movie evidence/f2/walkthrough.avi --fixed-fps 30 res://tools/capture/f2_capture.tscn
## Headless logic check (no movie):
##   godot4 --headless --path <project> res://tools/capture/f2_capture.tscn
##
## Drives the production game (GameState, warning, menu, level, director, player)
## only through input events and menu buttons. GameState.clock and the Overlay
## run on manual clocks advanced 1/FPS per rendered frame, so timings land on the
## same frames however slowly llvmpipe renders. Long ladder waits are shown as a
## logged time-lapse (TIMELAPSE seconds of game time per frame).

const FPS := 30.0
const TIMELAPSE := 0.5

var failures := 0
var ov: Node


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()


func _level() -> Node:
	return get_tree().current_scene


func _press(keycode: Key, pressed_only := false) -> void:
	for pressed in ([true] if pressed_only else [true, false]):
		var e := InputEventKey.new()
		e.keycode = keycode
		e.physical_keycode = keycode
		e.pressed = pressed
		Input.parse_input_event(e)
	Input.flush_buffered_events()


func _frames(seconds: float, per_frame := 1.0 / FPS) -> void:
	for i in roundi(seconds / per_frame):
		GameState.clock.advance(per_frame)
		ov.advance_clock(per_frame)
		await get_tree().process_frame


func _expect(cond: bool, what: String) -> void:
	print("[f2-capture] %s %s" % ["OK  " if cond else "FAIL", what])
	failures += 0 if cond else 1


func _walk(action: StringName, seconds: float) -> void:
	Input.action_press(action)
	await _frames(seconds)
	Input.action_release(action)


func _look(dx: float, dy: float, steps: int) -> void:
	for i in steps:
		var m := InputEventMouseMotion.new()
		m.relative = Vector2(dx, dy)
		Input.parse_input_event(m)
		Input.flush_buffered_events()
		await _frames(1.0 / FPS)


func _run() -> void:
	ov = get_node(^"/root/Overlay")
	ov.use_manual_clock = true
	GameState.clock.manual = true
	# Keep this driver alive across GameState scene changes.
	var placeholder := Node.new()
	get_tree().root.add_child(placeholder)
	get_tree().current_scene = placeholder

	print("[f2-capture] warning screen")
	GameState.show_warning()
	await _frames(2.5)
	_expect(GameState.state == &"warning", "warning shown before the menu")
	_press(KEY_K)
	await _frames(1.5)
	_expect(GameState.state == &"menu", "any key -> main menu")
	print("[f2-capture] START")
	_level().start_button.pressed.emit()
	await _frames(0.2)
	var level := _level()
	var d: CommandDirector = level.director
	var p: GoodDogPlayer = level.player
	await _frames(2.6)
	_expect(d.state == CommandDirector.State.IDLE and not p.controls_enabled, "prologue: no control before 3 s")
	await _frames(0.4)
	_expect(ov.get_displayed_text() == "BARK.", "BLACK BARK. after the 3 s prologue")
	_press(KEY_B)  # inside the 0.35 s guard
	await _frames(1.4)
	_press(KEY_B)  # dismisses; must not count as a bark
	await _frames(0.5)
	_expect(d.state == CommandDirector.State.WAITING, "dismissal B started rung 1, not a bark")
	_expect(level.hint_label.visible and level.hint_label.text == "PRESS [B] TO BARK", "hint visible")
	_press(KEY_F3)
	print("[f2-capture] F3 debug HUD on (debug builds only)")
	await _walk(&"move_forward", 1.0)
	await _look(-12.0, 0.0, 20)
	await _walk(&"move_left", 0.8)
	await _look(12.0, -4.0, 20)
	print("[f2-capture] time-lapse x%d: rung 1 expires" % roundi(TIMELAPSE * FPS))
	await _frames(maxf(d.get_remaining() + 0.1, 0.1), TIMELAPSE)
	await _frames(0.2)
	_expect(d.rung == 1 and ov.get_current_line() == load("res://data/lines/bark_r2.tres"), "rung 2 order BARK.")
	await _frames(1.0)
	_press(KEY_K)
	await _frames(1.0)
	print("[f2-capture] time-lapse: rung 2 expires")
	await _frames(maxf(d.get_remaining() + 0.1, 0.1), TIMELAPSE)
	await _frames(1.2)
	_expect(d.rung == 2, "rung 3 order")
	_press(KEY_K)
	await _frames(1.5)
	_press(KEY_B)
	_expect(d.state == CommandDirector.State.SUCCESS, "B bark completes BARK at rung 3")
	await _frames(1.6)
	_expect(ov.get_displayed_text() == "DOG.", "GOOD. DOG. per word")
	_press(KEY_K)
	await _frames(0.4)
	_expect(level.transform_ctl.current_step == 1, "transform step 1 begins")
	_press(KEY_F3)
	# Undo the demonstration's lateral offset using production movement, never a
	# position assignment. Bound the feedback loop so blocked movement fails QA.
	for i in 90:
		if absf(p.position.x) < 0.08:
			break
		await _walk(&"move_right" if p.position.x < 0.0 else &"move_left", 1.0 / FPS)
	_expect(absf(p.position.x) < 0.08, "honest input recenters on the doorway")
	# Restore level pitch through mouse input so the lowered eye sees the corridor.
	await _look(0.0, 4.0, 20)
	await _frames(2.6)
	_expect(is_equal_approx(p.eye_height_m, 1.4), "eye height 1.40 after 2.5 s")
	_expect(level.bars.position.x > 1.5, "bars slid open")
	print("[f2-capture] opened gate view position=%s eye=%.2f" % [p.position, p.eye_height_m])
	await _still("opened-gate")
	await _frames(1.0)
	var before_crossing := p.position
	await _walk(&"move_forward", 1.2)
	_expect(before_crossing.z > -2.6 and p.position.z < -3.2 and absf(p.position.x) < 0.3,
			"actual player crossed opened gate into corridor")
	print("[f2-capture] corridor position=%s eye=%.2f" % [p.position, p.eye_height_m])
	await _still("corridor-eye-1_4")
	await _frames(1.0)
	_press(KEY_B)
	await _frames(0.2)
	_expect(ov.get_displayed_text() == "QUIET.", "off-order bark -> FLASH QUIET.")
	await _frames(1.0)
	print("[f2-capture] pause OBEY / RUN AWAY")
	_press(KEY_ESCAPE)
	await _frames(1.5)
	_expect(GameState.paused, "Esc pause menu")
	_press(KEY_ESCAPE)
	await _frames(0.8)
	_expect(not GameState.paused, "OBEY resumes")
	_press(KEY_ESCAPE)
	await _frames(1.0)
	GameState._run_away.pressed.emit()
	await _frames(1.5)
	_expect(GameState.state == &"menu", "RUN AWAY -> menu")

	print("[f2-capture] restart and fail the full ladder")
	_level().start_button.pressed.emit()
	await _frames(0.2)
	level = _level()
	d = level.director
	p = level.player
	_expect(level.transform_ctl.current_step == 0 and is_equal_approx(p.eye_height_m, 1.7), "fresh run reset")
	await _frames(3.6)
	_press(KEY_K)
	for r in 6:
		print("[f2-capture] time-lapse: rung %d (%.0f s)" % [r + 1, BARK_LADDER[r]])
		await _frames(maxf(d.get_remaining() + 0.05, 0.05), TIMELAPSE if BARK_LADDER[r] > 2.0 else 1.0 / FPS)
		if r < 4:
			await _frames(1.2)
			_press(KEY_K)
		elif r == 4:
			await _frames(0.7)
	await _frames(0.3)
	_expect(d.state == CommandDirector.State.FAIL and GameState.state == &"failed", "1 s rung expired -> BAD DOG")
	_expect(ov.get_displayed_text().replace("\n", " ") == "BAD DOG.", "BLACK BAD DOG.")
	await _frames(5.2)
	_expect(GameState.state == &"menu", "3 s silence then main menu")
	await _frames(1.0)
	print("[f2-capture] appear sounds started: %d" % ov.appear_sfx_count)
	# Exercise the real exit-tree lifecycle before quitting, so the audio mixer
	# can retire stopped WAV playbacks even in a faster-than-real-time headless run.
	get_tree().unload_current_scene()
	ov.queue_free()
	await get_tree().process_frame
	var settle_until := Time.get_ticks_msec() + 350
	while Time.get_ticks_msec() < settle_until:
		OS.delay_msec(10)
		await get_tree().process_frame
	_expect(not is_instance_valid(ov), "overlay exit-tree/audio teardown completed")
	print("[f2-capture] finished, failures=%d" % failures)
	get_tree().quit(1 if failures else 0)


func _still(label: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var out := OS.get_environment("F2_STILL_DIR")
	if not out.is_empty():
		_expect(get_viewport().get_texture().get_image().save_png(out.path_join(label + ".png")) == OK,
				"saved " + label)


const BARK_LADDER := [20.0, 10.0, 5.0, 3.0, 2.0, 1.0]
