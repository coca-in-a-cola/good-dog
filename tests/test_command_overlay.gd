extends Node
## Behaviour tests for addons/command_overlay. Run through tests/run_tests.gd.

const OVERLAY_SCENE := preload("res://addons/command_overlay/overlay.tscn")
const Mode := OverlayLine.Mode
const Dismiss := OverlayLine.Dismiss


class GameProbe:
	extends Node
	var barks := 0
	var polled_barks := 0
	var naive_polled_barks := 0
	var overlay: Node
	var key_events := 0
	var releases := 0
	var scaled_time := 0.0

	func _process(delta: float) -> void:
		scaled_time += delta
		if Input.is_action_just_pressed(&"bark"):
			naive_polled_barks += 1
			if overlay == null or not overlay.is_input_blocked():
				polled_barks += 1

	func _unhandled_input(event: InputEvent) -> void:
		if event.is_action_pressed(&"bark"):
			barks += 1
		if event is InputEventKey:
			if event.pressed:
				key_events += 1
			else:
				releases += 1


var failures: Array[String] = []
var assertions := 0
var ov: CanvasLayer
var probe: GameProbe
var events: Array[String] = []


# --- Fixture ------------------------------------------------------------------

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not InputMap.has_action(&"bark"):
		InputMap.add_action(&"bark")
		var key := InputEventKey.new()
		key.physical_keycode = KEY_B
		InputMap.action_add_event(&"bark", key)


func before_each() -> void:
	failures.clear()
	assertions = 0
	events.clear()
	get_tree().paused = false
	Engine.time_scale = 1.0
	probe = GameProbe.new()
	add_child(probe)
	ov = _new_overlay(self)
	probe.overlay = ov
	await get_tree().process_frame


func after_each() -> void:
	if is_instance_valid(ov):
		ov.force_hide()
		ov.queue_free()
	probe.queue_free()
	for k in [KEY_B, KEY_W, KEY_K]:
		_key(k, false)
	Input.action_release(&"bark")
	get_tree().paused = false
	Engine.time_scale = 1.0
	await get_tree().process_frame


func _new_overlay(parent: Node) -> CanvasLayer:
	var o: CanvasLayer = OVERLAY_SCENE.instantiate()
	o.use_manual_clock = true
	o.shown.connect(func(id: StringName) -> void: events.append("shown:%s" % id))
	o.dismissed.connect(func(id: StringName) -> void: events.append("dismissed:%s" % id))
	o.cancelled.connect(func(id: StringName) -> void: events.append("cancelled:%s" % id))
	o.word_shown.connect(func(id: StringName, i: int, w: String) -> void: events.append("word:%s:%d:%s" % [id, i, w]))
	o.sequence_finished.connect(func() -> void: events.append("sequence_finished"))
	parent.add_child(o)
	return o


func _line(text: String, mode: Mode, id: StringName) -> OverlayLine:
	return OverlayLine.make(text, mode, id)


# --- Input helpers ------------------------------------------------------------

func _key(keycode: Key, pressed := true, echo := false) -> void:
	var e := InputEventKey.new()
	e.keycode = keycode
	e.physical_keycode = keycode
	e.pressed = pressed
	e.echo = echo
	Input.parse_input_event(e)
	Input.flush_buffered_events()


func _tap(keycode: Key) -> void:
	_key(keycode, true)
	_key(keycode, false)


func _mouse(button: MouseButton, pressed := true) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = button
	e.pressed = pressed
	e.position = Vector2(10, 10)
	Input.parse_input_event(e)
	Input.flush_buffered_events()


func _joy(button: JoyButton, pressed := true) -> void:
	var e := InputEventJoypadButton.new()
	e.button_index = button
	e.pressed = pressed
	Input.parse_input_event(e)
	Input.flush_buffered_events()


func _wait_real(seconds: float) -> void:
	var end := Time.get_ticks_usec() + int(seconds * 1000000.0)
	while Time.get_ticks_usec() < end:
		await get_tree().process_frame


# --- Assertions ---------------------------------------------------------------

func check(cond: bool, msg: String) -> void:
	assertions += 1
	if not cond:
		failures.append(msg)


func eq(actual: Variant, expected: Variant, msg: String) -> void:
	check(actual == expected, "%s: expected <%s>, got <%s>" % [msg, expected, actual])


func near(actual: float, expected: float, eps: float, msg: String) -> void:
	check(absf(actual - expected) <= eps, "%s: expected %.4f±%.4f, got %.4f" % [msg, expected, eps, actual])


# --- Tests --------------------------------------------------------------------

func test_api_surface_and_autoload() -> void:
	for s in ["shown", "dismissed"]:
		check(ov.has_signal(s), "signal %s" % s)
	for m in ["show_line", "show_text", "show_sequence", "is_active", "force_hide"]:
		check(ov.has_method(m), "method %s" % m)
	var line := OverlayLine.new()
	for f in ["id", "text", "mode", "per_word", "word_interval", "dismiss", "auto_hide_after", "min_lock_time",
			"text_color", "glow_color", "font_override", "punch_scale", "jitter_px", "sfx_appear",
			"world_time_scale"]:
		check(f in line, "OverlayLine field %s" % f)
	eq(line.mode, Mode.OVER_WORLD, "default mode")
	near(line.min_lock_time, 0.35, 0.0001, "default min_lock_time")
	near(line.world_time_scale, 0.05, 0.0001, "default world_time_scale")
	eq(line.text_color, Color.WHITE, "default text colour")
	eq(line.glow_color.to_html(false), "9ff4ff", "default glow colour")
	check(line.glow_color.a >= 0.5 and line.glow_color.a <= 0.7, "glow alpha 0.5–0.7")
	eq(ov.layer, 100, "canvas layer")
	eq(ov.process_mode, Node.PROCESS_MODE_ALWAYS, "process_mode")
	var auto := get_tree().root.get_node_or_null(^"Overlay")
	check(auto != null, "Overlay autoload registered from project.godot")
	if auto:
		eq(auto.scene_file_path, "res://addons/command_overlay/overlay.tscn", "autoload scene")


func test_black_pauses_world_and_input_still_dismisses() -> void:
	probe.process_mode = Node.PROCESS_MODE_ALWAYS  # proves consumption, not just pause
	ov.show_line(_line("BARK.", Mode.BLACK, &"bark"))
	check(get_tree().paused, "BLACK pauses tree")
	near(Engine.time_scale, 0.05, 0.0001, "BLACK world time scale")
	check(ov._backdrop.visible and not ov._world_tint.visible, "BLACK backdrop only")
	var paused_probe := GameProbe.new()
	paused_probe.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(paused_probe)
	await get_tree().process_frame
	await get_tree().process_frame
	near(paused_probe.scaled_time, 0.0, 0.0, "pausable world does not process under BLACK")
	ov.advance_clock(0.4)
	_tap(KEY_B)
	check(not ov.is_active(), "key dismisses while tree paused")
	eq(probe.barks, 0, "dismissing B consumed (ALWAYS probe saw no bark)")
	check(not get_tree().paused, "pause restored at dismissal")
	ov.advance_clock(0.1)
	check(Engine.time_scale > 0.05 and Engine.time_scale < 1.0, "thaw in progress at 0.1 s (%.3f)" % Engine.time_scale)
	ov.advance_clock(0.16)
	near(Engine.time_scale, 1.0, 0.0001, "time scale restored after 0.25 s thaw")
	eq(events, ["shown:bark", "word:bark:0:BARK.", "dismissed:bark"] as Array[String], "events")
	paused_probe.queue_free()


func test_over_world_real_time_lock_and_thaw() -> void:
	ov.use_manual_clock = false
	ov.show_line(_line("GRAB THE STICK.", Mode.OVER_WORLD, &"grab"))
	near(Engine.time_scale, 0.05, 0.0001, "OVER_WORLD time scale")
	check(not get_tree().paused, "OVER_WORLD does not pause")
	check(ov._world_tint.visible and not ov._backdrop.visible, "OVER_WORLD tint only")
	var start := Time.get_ticks_usec()
	probe.scaled_time = 0.0
	_tap(KEY_K)
	check(ov.is_active(), "immediate press ignored")
	await _wait_real(0.2)
	_tap(KEY_K)
	check(ov.is_active(), "press at ~0.2 s real ignored")
	await _wait_real(0.2)
	_tap(KEY_K)
	var elapsed := (Time.get_ticks_usec() - start) / 1000000.0
	check(not ov.is_active(), "press after 0.35 s REAL time dismisses despite time_scale 0.05 (%.3f s)" % elapsed)
	check(elapsed < 1.0, "lock measured in real time, not scaled time")
	check(probe.scaled_time < 0.05, "world advanced only scaled time while shown (%.4f)" % probe.scaled_time)
	eq(probe.key_events, 0, "all presses during OVER_WORLD consumed")
	await _wait_real(0.1)
	check(Engine.time_scale > 0.05 and Engine.time_scale < 1.0, "thawing at ~0.1 s (%.3f)" % Engine.time_scale)
	await _wait_real(0.25)
	near(Engine.time_scale, 1.0, 0.0001, "time scale restored after thaw")


func test_flash_auto_dismisses_without_pausing_world() -> void:
	ov.show_line(OverlayLine.make("NOW.", Mode.FLASH, &"now"))
	check(not get_tree().paused, "FLASH does not pause")
	near(Engine.time_scale, 1.0, 0.0001, "FLASH keeps time scale")
	check(not ov._backdrop.visible and not ov._world_tint.visible, "FLASH has no backdrop")
	ov.advance_clock(0.4)
	_tap(KEY_B)
	check(ov.is_active(), "FLASH ignores key for dismissal")
	eq(probe.barks, 1, "FLASH does not consume game input")
	ov.advance_clock(0.19)
	check(ov.is_active(), "still visible at 0.59 s")
	ov.advance_clock(0.02)
	check(not ov.is_active(), "auto-dismissed at 0.6 s")
	eq(events, ["shown:now", "word:now:0:NOW.", "dismissed:now"] as Array[String], "events")
	near(Engine.time_scale, 1.0, 0.0001, "time scale untouched after FLASH")


func test_fresh_press_guard_0_35s() -> void:
	ov.show_line(_line("BARK.", Mode.OVER_WORLD, &"bark"))
	ov.advance_clock(0.34)
	_tap(KEY_K)
	check(ov.is_active(), "press at 0.34 s ignored")
	ov.advance_clock(0.01)
	_tap(KEY_K)
	check(not ov.is_active(), "fresh press at 0.35 s dismisses")
	var long := _line("JUMP.", Mode.BLACK, &"jump")
	long.min_lock_time = 1.0
	ov.show_line(long)
	ov.advance_clock(0.9)
	_tap(KEY_K)
	check(ov.is_active(), "custom min_lock_time 1.0 respected")
	ov.advance_clock(0.2)
	_tap(KEY_K)
	check(not ov.is_active(), "dismissed after custom lock")


func test_echo_and_held_input_suppressed() -> void:
	_key(KEY_W, true)  # held before the line appears
	eq(probe.key_events, 1, "pre-line press reaches the game")
	probe.key_events = 0
	ov.show_line(_line("BARK.", Mode.OVER_WORLD, &"bark"))
	ov.advance_clock(0.6)
	for i in 5:
		_key(KEY_W, true, true)
	check(ov.is_active(), "echo of held key never dismisses")
	_mouse(MOUSE_BUTTON_WHEEL_UP)
	check(ov.is_active(), "mouse wheel does not dismiss")
	eq(probe.key_events, 0, "echo presses consumed")
	_key(KEY_W, false)
	eq(probe.releases, 1, "release passes through to the game")
	check(ov.is_active(), "release does not dismiss")
	_mouse(MOUSE_BUTTON_LEFT)
	_mouse(MOUSE_BUTTON_LEFT, false)
	check(not ov.is_active(), "fresh mouse click dismisses")
	ov.show_line(_line("BARK.", Mode.BLACK, &"bark2"))
	ov.advance_clock(0.5)
	_joy(JOY_BUTTON_A)
	_joy(JOY_BUTTON_A, false)
	check(not ov.is_active(), "joypad button dismisses")


func test_dismissing_b_is_not_a_bark() -> void:
	ov.show_line(_line("BARK.", Mode.OVER_WORLD, &"bark"))
	_tap(KEY_B)  # during lock
	ov.advance_clock(0.4)
	_key(KEY_B, true)
	check(not ov.is_active(), "B dismissed the line")
	check(not Input.is_action_pressed(&"bark"), "bark action released in Input singleton")
	check(ov.is_input_blocked(), "is_input_blocked() true in the dismissal frame")
	await get_tree().process_frame
	await get_tree().process_frame
	check(not ov.is_input_blocked(), "is_input_blocked() clears on later frames")
	_key(KEY_B, false)
	eq(probe.barks, 0, "no bark event reached _unhandled_input")
	eq(probe.polled_barks, 0, "no bark seen by a poller that honours is_input_blocked()")
	print("    diagnostic: naive is_action_just_pressed poller saw %d bark(s) in the dismissal frame" %
			probe.naive_polled_barks)
	_tap(KEY_B)
	eq(probe.barks, 1, "control: a later fresh B is a bark")
	await get_tree().process_frame
	eq(probe.polled_barks, 1, "control: guarded poller sees a later fresh B")


func test_per_word_order_and_appear_sfx() -> void:
	var line := _line("good. dog.", Mode.OVER_WORLD, &"good_dog")
	line.per_word = true
	line.word_interval = 0.45
	check(line.sfx_appear == null, "line relies on the bundled default appearance sound")
	var played: Array[AudioStream] = []
	ov.word_shown.connect(func(_id: StringName, _i: int, _w: String) -> void: played.append(ov._sfx.stream))
	ov.show_line(line)
	eq(ov.get_displayed_text(), "GOOD.", "first word")
	check(ov._flash.visible, "white flash frame on appearance")
	ov.advance_clock(0.44)
	eq(ov.get_displayed_text(), "GOOD.", "still first word at 0.44 s")
	_tap(KEY_K)
	check(ov.is_active(), "cannot dismiss before last word")
	ov.advance_clock(0.02)
	eq(ov.get_displayed_text(), "DOG.", "second word at 0.45 s")
	ov.advance_clock(0.2)
	_tap(KEY_K)
	check(ov.is_active(), "lock restarts with last word")
	ov.advance_clock(0.2)
	_tap(KEY_K)
	check(not ov.is_active(), "dismissed after lock on last word")
	eq(events, ["shown:good_dog", "word:good_dog:0:GOOD.", "word:good_dog:1:DOG.", "dismissed:good_dog"] as Array[String],
			"per-word event order")
	eq(ov.appear_sfx_count, 2, "one appearance sound per word, none on hide")
	eq(played.size(), 2, "appearance stream captured per word")
	for s in played:
		check(s != null and s == ov.default_sfx_appear, "per-word sound is the bundled camera flash")


func test_bundled_font_and_camera_flash_defaults() -> void:
	var font: Font = ov.default_font
	check(font is FontFile, "default font is a bundled FontFile")
	if font:
		eq(font.resource_path, "res://addons/command_overlay/assets/fonts/NotoSans-Bold.ttf", "default font path")
		eq(font.get_font_name(), "Noto Sans", "default font family")
		check(font.get_font_style() & TextServer.FONT_BOLD, "default font is bold")
		check(font.get_font_name() != ThemeDB.fallback_font.get_font_name(), "not the ThemeDB fallback")
	ov.show_text("BARK.")
	eq(ov._label_settings.font, font, "label renders with the bundled font")
	var custom := SystemFont.new()
	var over := _line("BARK.", Mode.OVER_WORLD, &"o")
	over.font_override = custom
	ov.show_line(over)
	eq(ov._label_settings.font, custom, "font_override still wins")
	ov.force_hide()

	var wav := ov.default_sfx_appear as AudioStreamWAV
	check(wav != null, "default appearance sound is a bundled AudioStreamWAV")
	if wav:
		eq(wav.resource_path, "res://addons/command_overlay/assets/sfx/camera_flash.wav", "sound path")
		check(wav.get_length() > 0.3 and wav.get_length() < 0.6, "one-shot length 0.3–0.6 s (%.3f)" % wav.get_length())
		eq(wav.format, AudioStreamWAV.FORMAT_16_BITS, "imported as uncompressed PCM")
		eq(wav.loop_mode, AudioStreamWAV.LOOP_DISABLED, "not looped")
		var data := wav.data
		var peak := 0
		for i in range(0, data.size() - 1, 2):
			peak = maxi(peak, absi(data.decode_s16(i)))
		check(peak > 16384, "waveform is not silent (peak %d / 32767)" % peak)
	for path in ["bark", "good_dog_words", "now_flash", "grab_the_stick", "bad_dog", "good_dog_finale"]:
		var demo_line: OverlayLine = load("res://addons/command_overlay/demo/lines/%s.tres" % path)
		check(demo_line.sfx_appear == null, "%s uses the default camera flash" % path)
	var before: int = ov.appear_sfx_count
	ov.show_line(_line("BARK.", Mode.OVER_WORLD, &"h"))
	ov.advance_clock(0.4)
	_tap(KEY_K)
	ov.advance_clock(0.5)
	eq(ov.appear_sfx_count - before, 1, "appearance plays once, hide is silent")


func test_force_hide_and_tree_exit_restore_prior_state() -> void:
	Engine.time_scale = 0.7
	ov.show_line(_line("BARK.", Mode.BLACK, &"a"))
	check(get_tree().paused, "paused while BLACK")
	ov.force_hide()
	check(not get_tree().paused, "force_hide restores pause")
	near(Engine.time_scale, 0.7, 0.0001, "force_hide restores prior time scale immediately")
	check(not ov.is_active() and not ov._root.visible, "hidden")
	eq(events, ["shown:a", "word:a:0:BARK.", "cancelled:a"] as Array[String], "cancelled, not dismissed")

	get_tree().paused = true
	ov.show_line(_line("GOOD DOG.", Mode.OVER_WORLD, &"b"))
	check(get_tree().paused, "OVER_WORLD keeps an already paused tree paused")
	ov.advance_clock(0.4)
	_tap(KEY_K)
	check(get_tree().paused, "prior paused=true restored")
	ov.advance_clock(0.1)
	ov.force_hide()
	near(Engine.time_scale, 0.7, 0.0001, "force_hide during thaw restores immediately")
	get_tree().paused = false

	ov.show_line(_line("JUMP.", Mode.BLACK, &"c"))
	remove_child(ov)
	check(not get_tree().paused, "leaving the tree restores pause")
	near(Engine.time_scale, 0.7, 0.0001, "leaving the tree restores time scale")
	check(events.has("cancelled:c"), "leaving the tree emits cancelled")
	add_child(ov)


func test_scene_change_cancels() -> void:
	if not get_tree().has_signal(&"scene_changed"):
		check(false, "SceneTree.scene_changed signal unavailable in this Godot build")
		return
	ov.show_line(_line("BARK.", Mode.BLACK, &"s"))
	var scene := PackedScene.new()
	# PackedScene.pack copies state; it does not take ownership of the source.
	var source := Node.new()
	var source_id := source.get_instance_id()
	var pack_result := scene.pack(source)
	source.free()
	eq(pack_result, OK, "scene fixture packs successfully")
	check(not is_instance_id_valid(source_id), "packed source fixture freed before scene change")
	get_tree().change_scene_to_packed(scene)
	for i in 4:
		await get_tree().process_frame
	check(not ov.is_active(), "scene change cancels the line")
	check(not get_tree().paused, "scene change restores pause")
	near(Engine.time_scale, 1.0, 0.0001, "scene change restores time scale")
	get_tree().unload_current_scene()


func test_sequence_keeps_world_frozen_between_lines() -> void:
	var a := _line("NOW.", Mode.BLACK, &"a")
	var b := _line("GRAB THE STICK.", Mode.OVER_WORLD, &"b")
	var c := OverlayLine.make("FASTER.", Mode.FLASH, &"c")
	ov.show_sequence([a, b, c] as Array[OverlayLine])
	check(get_tree().paused, "a paused")
	ov.advance_clock(0.4)
	_tap(KEY_K)
	check(ov.is_active(), "b shown right after a")
	check(not get_tree().paused, "b OVER_WORLD unpaused")
	near(Engine.time_scale, 0.05, 0.0001, "no thaw between modal lines")
	ov.advance_clock(0.4)
	_tap(KEY_K)
	eq(ov.get_current_line(), c, "c showing")
	ov.advance_clock(0.3)
	near(Engine.time_scale, 1.0, 0.0001, "thawed while FLASH runs")
	ov.advance_clock(0.31)
	check(not ov.is_active(), "sequence ended")
	eq(events, ["shown:a", "word:a:0:NOW.", "dismissed:a", "shown:b", "word:b:0:GRAB THE STICK.", "dismissed:b",
			"shown:c", "word:c:0:FASTER.", "dismissed:c", "sequence_finished"] as Array[String], "sequence order")


func test_repeated_show_cancel_stress() -> void:
	Engine.time_scale = 0.9
	var rng := RandomNumberGenerator.new()
	rng.seed = 46
	for i in 200:
		match rng.randi_range(0, 5):
			0: ov.show_line(_line("BARK.", rng.randi_range(0, 2) as Mode, &"r"))
			1: ov.show_text("GOOD DOG.", rng.randi_range(0, 2) as Mode)
			2: ov.show_sequence([_line("A.", Mode.BLACK, &"x"), OverlayLine.make("B.", Mode.FLASH, &"y")] as Array[OverlayLine])
			3: ov.force_hide()
			4: _tap(KEY_K)
			5: ov.advance_clock(rng.randf_range(0.0, 0.5))
	ov.show_line(_line("BARK.", Mode.OVER_WORLD, &"r"))
	ov.show_line(_line("JUMP.", Mode.BLACK, &"r2"))
	check(events.slice(-3) == ["cancelled:r", "shown:r2", "word:r2:0:JUMP."], "replacement cancels then shows")
	ov.force_hide()
	ov.advance_clock(1.0)
	check(not ov.is_active(), "inactive at end")
	check(not ov._root.visible, "nothing left on screen")
	check(not get_tree().paused, "pause restored after stress")
	near(Engine.time_scale, 0.9, 0.0001, "time scale restored after stress")


func test_responsive_fit_three_aspect_ratios() -> void:
	var font: Font = ov.default_font  # the font the overlay actually lays out with
	eq(font.get_font_name(), "Noto Sans", "fit measured with bundled Noto Sans")
	print("    font in use: %s (style %d)" % [font.get_font_name(), font.get_font_style()])
	for size: Vector2i in [Vector2i(1920, 1080), Vector2i(1080, 1920), Vector2i(2560, 1080)]:
		var vp := SubViewport.new()
		vp.size = size
		add_child(vp)
		var o := _new_overlay(vp)
		o.show_line(_line("BARK.", Mode.OVER_WORLD, &"fit"))
		var fs: int = o.get_font_size()
		var w := font.get_string_size("BARK.", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x / size.x
		var h := font.get_height(fs) / size.y
		check((w >= 0.85 and w <= 0.90) or (h <= o.MAX_TEXT_HEIGHT + 0.001 and w <= 0.90),
				"%s single word width %.3f (height %.3f)" % [size, w, h])
		print("    %s BARK. -> size %d, width %.3f, height %.3f%s" % [size, fs, w, h,
				"" if w >= 0.85 else " (height-capped)"])
		o.show_text("YOU WERE A GOOD DOG!")
		var lines: PackedStringArray = o.get_displayed_text().split("\n")
		fs = o.get_font_size()
		check(lines.size() <= 3, "%s phrase uses <= 3 lines" % size)
		for l in lines:
			check(font.get_string_size(l, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x <= 0.9 * size.x,
					"%s line '%s' within 90%% width" % [size, l])
		check(font.get_height(fs) * lines.size() <= 0.8 * size.y + 1.0, "%s phrase within height" % size)
		print("    %s phrase -> %d lines, size %d" % [size, lines.size(), fs])
		var before: int = fs
		vp.size = Vector2i(size.y, size.x)
		await get_tree().process_frame
		check(o.get_font_size() != before or size.x == size.y, "%s re-fit on resize" % size)
		o.force_hide()
		vp.queue_free()


func test_reduced_flashes_shake_and_idle_animation() -> void:
	var line := _line("BARK.", Mode.OVER_WORLD, &"j")
	line.jitter_px = 2.0
	ov.show_line(line)
	near(ov._text_root.scale.x, 1.2, 0.0001, "punch starts at 1.2")
	ov.advance_clock(0.04)
	check(ov._text_root.scale.x < 1.2 and ov._text_root.scale.x > 1.0, "punch easing at 0.04 s")
	ov.advance_clock(0.05)
	near(ov._text_root.scale.x, 1.0, 0.0001, "punch settles to 1.0 after 0.08 s")
	var max_j := 0.0
	var gmin := 9.0
	var gmax := -9.0
	for i in 200:
		ov.advance_clock(1.0 / 60.0)
		max_j = maxf(max_j, maxf(absf(ov._text_root.position.x), absf(ov._text_root.position.y)))
		gmin = minf(gmin, ov.get_glow_intensity())
		gmax = maxf(gmax, ov.get_glow_intensity())
	check(max_j <= 2.0 and max_j > 1.0, "jitter within 2 px (%.2f)" % max_j)
	check(gmin >= 0.85 - 0.0001 and gmax <= 1.0001 and gmax - gmin > 0.1, "glow pulse 0.85–1.0 (%.3f–%.3f)" % [gmin, gmax])
	ov.force_hide()
	ov.reduce_flashes = true
	ov.reduce_shake = true
	ov.show_line(line)
	check(not ov._flash.visible, "reduce_flashes: no white frame")
	check(not ov._aberration.visible, "reduce_flashes: no aberration burst")
	max_j = 0.0
	for i in 200:
		ov.advance_clock(1.0 / 60.0)
		max_j = maxf(max_j, maxf(absf(ov._text_root.position.x), absf(ov._text_root.position.y)))
	check(max_j <= 0.6 + 0.0001, "reduce_shake: jitter scaled to 30%% (%.2f)" % max_j)


func test_uppercase_and_colours() -> void:
	ov.show_text("good dog.")
	eq(ov.get_displayed_text().replace("\n", " "), "GOOD DOG.", "upper-cased")
	var bad: OverlayLine = load("res://addons/command_overlay/demo/lines/bad_dog.tres")
	ov.show_line(bad)
	eq(ov._label_settings.font_color.to_html(false), "b3261e", "loss line is dirty red")
	check(ov._label_settings.outline_size >= 8 and ov._label_settings.outline_size <= 16, "outline 8–16 px")
