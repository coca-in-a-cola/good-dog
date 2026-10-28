extends SceneTree
## Rendered regression: actual production CheckButtons, actual input/focus states.
## Run at 1920x1080 under Xvfb; no replacement theme or controls.
var failures := 0
var out := "res://evidence/f2-repair/menu-states"

func _initialize() -> void:
	_run.call_deferred()

func expect(ok: bool, message: String) -> void:
	print("[f2-menu] %s %s" % ["OK" if ok else "FAIL", message])
	if not ok:
		failures += 1

func mouse(pos: Vector2) -> void:
	Input.warp_mouse(pos)
	var event := InputEventMouseMotion.new()
	event.position = pos
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await process_frame
	await process_frame

func click(b: CheckButton) -> void:
	await mouse(b.get_global_rect().get_center())
	for down in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = b.get_global_rect().get_center()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		await process_frame

func luminance(c: Color) -> float:
	var v := c.srgb_to_linear()
	return 0.2126 * v.r + 0.7152 * v.g + 0.0722 * v.b

func shot(b: CheckButton, state: String, key: String, mode: int) -> void:
	await RenderingServer.frame_post_draw
	expect(b.get_draw_mode() == mode, b.name + " actual draw mode " + state)
	var bg: Color = current_scene.get_node("Background").color
	var fg := b.get_theme_color(key)
	var ratio := (luminance(bg) + 0.05) / (luminance(fg) + 0.05)
	expect(ratio >= 4.5, "%s %s theme contrast %.2f:1" % [b.name, state, ratio])
	var image := root.get_texture().get_image()
	# Exclude the right-hand checkbox/icon: inspect the text-only left 220px.
	var rect := Rect2i(b.get_global_rect())
	var ink := 0
	for y in range(rect.position.y + 3, rect.end.y - 3):
		for x in range(rect.position.x + 10, rect.position.x + 220):
			var pixel := image.get_pixel(x, y)
			if (luminance(bg) + 0.05) / (luminance(pixel) + 0.05) >= 4.5:
				ink += 1
	expect(ink > 250, "%s %s rendered text contrast pixels=%d" % [b.name, state, ink])
	expect(image.save_png(out.path_join("%s-%s.png" % [b.name, state])) == OK, "saved native still")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	change_scene_to_file("res://scenes/main_menu.tscn")
	await process_frame
	await process_frame
	for path in ["Box/ReduceFlashes", "Box/ReduceShake"]:
		var b: CheckButton = current_scene.get_node(path)
		current_scene.start_button.grab_focus()
		await mouse(Vector2(10, 10))
		await shot(b, "normal", "font_color", BaseButton.DRAW_NORMAL)
		await mouse(b.get_global_rect().get_center())
		await shot(b, "hover", "font_hover_color", BaseButton.DRAW_HOVER)
		await click(b)
		expect(b.button_pressed, b.name + " toggled by actual click")
		var overlay := root.get_node("Overlay")
		expect(overlay.reduce_flashes if b.name == "ReduceFlashes" else overlay.reduce_shake, "production setting updated")
		await shot(b, "hover-pressed", "font_hover_pressed_color", BaseButton.DRAW_HOVER_PRESSED)
		await mouse(Vector2(10, 10))
		b.release_focus()
		await shot(b, "pressed", "font_pressed_color", BaseButton.DRAW_PRESSED)
		await click(b)
		await mouse(Vector2(10, 10))
		b.grab_focus()
		expect(b.has_focus(), "real focus acquired")
		await shot(b, "focus", "font_focus_color", BaseButton.DRAW_NORMAL)
		b.disabled = true
		await shot(b, "disabled", "font_disabled_color", BaseButton.DRAW_DISABLED)
		b.disabled = false
	unload_current_scene()
	print("[f2-menu] finished, failures=%d" % failures)
	quit(1 if failures else 0)
