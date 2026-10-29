extends "res://tests/test_f3_route.gd"
## Bounded native-pixel evidence on production cameras; input route, no teleport.
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()

func shot(label: String) -> void:
	var selected := {"carry-circle-1_05":"carry", "placed-0_70":"placed", "final-eye-0_45":"final-eye"}
	if not selected.has(label): return
	RenderingServer.force_draw()
	var image := get_viewport().get_texture().get_image()
	check(image.save_png("res://evidence/f4/revision2/"+selected[label]+".png") == OK,"native PNG "+label)
	print("F4_NATIVE ",label," position=",level.player.position," eye=",level.player.eye_height_m," fov=",level.player.camera.fov)

func _run() -> void:
	var placeholder := Node.new()
	get_tree().root.add_child(placeholder)
	get_tree().current_scene = placeholder
	await before_each()
	GameState.quit_to_menu()
	await frames(.1)
	get_tree().current_scene.start_button.pressed.emit()
	await frames(.1)
	level = get_tree().current_scene
	await frames(3.1)
	await dismiss()
	await look_pitch(-.35)
	shot("cell-standing-1_70")
	# Back toward the cell entrance to include the complete furniture footprint.
	Input.action_press(&"move_backward")
	await frames(.55)
	Input.action_release(&"move_backward")
	# Look backward through genuine mouse input to review bunk/toilet.
	var e := InputEventMouseMotion.new()
	e.relative = Vector2((PI*.025)/level.player.horizontal_mouse_sensitivity,0)
	Input.parse_input_event(e)
	Input.flush_buffered_events()
	await frames(.05)
	shot("cell-furniture-1_70")
	e = InputEventMouseMotion.new()
	e.relative = Vector2((-PI*.025)/level.player.horizontal_mouse_sensitivity,0)
	Input.parse_input_event(e)
	Input.flush_buffered_events()
	await look_pitch(0)
	key(KEY_B)
	await dismiss()
	await frames(2.6)
	await walk_to(-4.3)
	shot("corridor-1_40")
	await grab()
	await look_pitch(-.35)
	await walk_to(-23.3)
	shot("carry-circle-1_05")
	await walk_to(-23.5)
	key(KEY_E)
	await dismiss()
	await frames(2.6)
	await look_pitch(-.40)
	shot("placed-0_70")
	await walk_to(-31.1)
	if ov.is_active(): await dismiss()
	await frames(2.6)
	# Explicit low-eye art fixture after the real route proves the transformation.
	# The closed gate prevents a reverse hall view of the original circle.
	level.leash_ctl.deactivate() # Art fixture only; ratchet otherwise restores hall position.
	level.player.position = Vector3(0,0,-23.3)
	await frames(.1)
	await look_pitch(-.22)
	shot("final-eye-0_45")
	print("F4_NATIVE_COMPLETE assertions=",assertions," failures=",failures)
	await after_each()
	ov.queue_free()
	await get_tree().process_frame
	OS.delay_msec(400)
	get_tree().quit(0 if failures.is_empty() else 1)
