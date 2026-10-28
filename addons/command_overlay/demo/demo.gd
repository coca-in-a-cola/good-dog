extends Node3D
## command_overlay demo: one button per mode plus a "game" probe that counts B
## presses reaching the world. Works with or without the Overlay autoload.
##
## Bounded smoke: godot --path <project> res://addons/command_overlay/demo/demo.tscn -- --overlay-demo-autoplay

const OVERLAY_SCENE := preload("../overlay.tscn")
const LINES := {
	"BLACK  — BARK.": preload("lines/bark.tres"),
	"OVER_WORLD per-word — GOOD. DOG.": preload("lines/good_dog_words.tres"),
	"FLASH — NOW.": preload("lines/now_flash.tres"),
	"OVER_WORLD — GRAB THE STICK.": preload("lines/grab_the_stick.tres"),
	"BLACK red — BAD DOG.": preload("lines/bad_dog.tres"),
	"BLACK fade — YOU WERE A GOOD DOG!": preload("lines/good_dog_finale.tres"),
}

var overlay: Node
var barks_reaching_game := 0
var _cube: MeshInstance3D
var _status: Label


func _ready() -> void:
	if not InputMap.has_action(&"bark"):
		InputMap.add_action(&"bark")
		var key := InputEventKey.new()
		key.physical_keycode = KEY_B
		InputMap.action_add_event(&"bark", key)
	overlay = get_node_or_null(^"/root/Overlay")
	if overlay == null:
		overlay = OVERLAY_SCENE.instantiate()
		add_child(overlay)
	_build_world()
	_build_ui()
	if "--overlay-demo-autoplay" in OS.get_cmdline_user_args():
		_autoplay.call_deferred()


func _process(delta: float) -> void:
	_cube.rotate_y(delta * 1.5)
	_status.text = "time_scale %.3f | paused %s | overlay active %s | barks reaching game %d" % [
			Engine.time_scale, get_tree().paused, overlay.is_active(), barks_reaching_game]


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"bark"):
		barks_reaching_game += 1


func _build_world() -> void:
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("E9EEF0")
	env.environment.glow_enabled = true
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	add_child(sun)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 1.2, 4)
	add_child(cam)
	cam.look_at(Vector3.ZERO)
	_cube = MeshInstance3D.new()
	_cube.mesh = BoxMesh.new()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("C1121F")
	_cube.material_override = mat
	add_child(_cube)


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var box := VBoxContainer.new()
	box.position = Vector2(24, 24)
	layer.add_child(box)
	for title: String in LINES:
		var b := Button.new()
		b.text = title
		b.pressed.connect(func() -> void: overlay.show_line(LINES[title]))
		box.add_child(b)
	var seq := Button.new()
	seq.text = "Sequence — NOW. / GRAB THE STICK. / FLASH NOW."
	seq.pressed.connect(_show_sequence)
	box.add_child(seq)
	var txt := Button.new()
	txt.text = "show_text(\"PLACE THE STICK HERE.\")"
	txt.pressed.connect(func() -> void: overlay.show_text("PLACE THE STICK HERE."))
	box.add_child(txt)
	for flag: String in ["reduce_flashes", "reduce_shake"]:
		var c := CheckBox.new()
		c.text = flag
		c.toggled.connect(func(on: bool) -> void: overlay.set(flag, on))
		box.add_child(c)
	_status = Label.new()
	box.add_child(_status)


func _show_sequence() -> void:
	var now := OverlayLine.make("NOW.", OverlayLine.Mode.OVER_WORLD, &"seq_now")
	var lines: Array[OverlayLine] = [now, LINES["OVER_WORLD — GRAB THE STICK."], LINES["FLASH — NOW."]]
	overlay.show_sequence(lines)


# --- Bounded automatic smoke run ---------------------------------------------

func _wait_real(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout


func _press_key(keycode: Key) -> void:
	for pressed in [true, false]:
		var e := InputEventKey.new()
		e.keycode = keycode
		e.physical_keycode = keycode
		e.pressed = pressed
		Input.parse_input_event(e)
	Input.flush_buffered_events()


func _autoplay() -> void:
	var failures := 0
	var start_scale := Engine.time_scale
	for title: String in LINES:
		var line: OverlayLine = LINES[title]
		overlay.show_line(line)
		await _wait_real(line.word_interval * (line.get_words().size() - 1) + line.min_lock_time + 0.1)
		if line.waits_for_key():
			_press_key(KEY_B)
		await _wait_real(line.auto_hide_after + line.hide_fade_time + 0.35)
		var ok: bool = not overlay.is_active() and not get_tree().paused \
				and is_equal_approx(Engine.time_scale, start_scale)
		print("[demo-smoke] %s -> %s (font %d, text %s)" % [title, "OK" if ok else "FAIL",
				overlay.get_font_size(), overlay.get_displayed_text().c_escape()])
		failures += 0 if ok else 1
	if barks_reaching_game != 0:
		print("[demo-smoke] FAIL: %d dismissal B presses reached the game" % barks_reaching_game)
		failures += 1
	print("[demo-smoke] finished, failures=%d" % failures)
	get_tree().quit(1 if failures else 0)
