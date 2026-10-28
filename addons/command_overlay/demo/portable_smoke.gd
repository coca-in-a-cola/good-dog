extends SceneTree
## Self-contained smoke check that needs nothing outside addons/command_overlay.
##   godot --headless --path <any project containing the addon> -s res://addons/command_overlay/demo/portable_smoke.gd
## Exit code 0 = pass.

var _failures: Array[String] = []
var _dismissed: Array[StringName] = []


func _initialize() -> void:
	_run.call_deferred()


func _check(cond: bool, msg: String) -> void:
	print(("  ok   " if cond else "  FAIL ") + msg)
	if not cond:
		_failures.append(msg)


func _tap(keycode: Key) -> void:
	for pressed in [true, false]:
		var e := InputEventKey.new()
		e.keycode = keycode
		e.physical_keycode = keycode
		e.pressed = pressed
		Input.parse_input_event(e)
	Input.flush_buffered_events()


func _run() -> void:
	# Runtime load: a -s script is compiled before autoloads, so preload would race an Overlay autoload.
	var scene_path: String = get_script().resource_path.get_base_dir().get_base_dir().path_join("overlay.tscn")
	var ov: Node = load(scene_path).instantiate()
	ov.use_manual_clock = true
	ov.dismissed.connect(func(id: StringName) -> void: _dismissed.append(id))
	root.add_child(ov)
	await process_frame
	_check(root.get_node_or_null(^"Overlay") != null or ov.is_inside_tree(), "overlay instantiated")

	ov.show_line(OverlayLine.make("BARK.", OverlayLine.Mode.BLACK, &"bark"))
	_check(paused, "BLACK pauses")
	ov.advance_clock(0.2)
	_tap(KEY_B)
	_check(ov.is_active(), "locked at 0.2 s")
	ov.advance_clock(0.2)
	_tap(KEY_B)
	_check(not ov.is_active() and not paused, "dismissed and unpaused")
	ov.advance_clock(0.3)
	_check(is_equal_approx(Engine.time_scale, 1.0), "time scale restored")

	var words := OverlayLine.make("GOOD. DOG.", OverlayLine.Mode.OVER_WORLD, &"good_dog")
	words.per_word = true
	ov.show_line(words)
	_check(is_equal_approx(Engine.time_scale, 0.05), "OVER_WORLD time scale")
	ov.advance_clock(0.5)
	_check(ov.get_displayed_text() == "DOG.", "per-word second word")
	ov.force_hide()
	_check(is_equal_approx(Engine.time_scale, 1.0), "force_hide restores")

	ov.show_text("NOW.", OverlayLine.Mode.FLASH)
	ov.advance_clock(0.7)
	_check(not ov.is_active(), "FLASH auto-hides")
	_check(_dismissed == [&"bark", &"NOW."], "dismissed ids %s" % [_dismissed])

	var demo: PackedScene = load("res://addons/command_overlay/demo/demo.tscn")
	_check(demo != null and demo.can_instantiate(), "demo scene loads")
	ov.queue_free()
	await process_frame
	print("portable_smoke: %s" % ("PASS" if _failures.is_empty() else "FAIL %s" % [_failures]))
	quit(0 if _failures.is_empty() else 1)
