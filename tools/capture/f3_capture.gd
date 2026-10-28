extends "res://tests/test_f3_route.gd"
## Parent-owned actual input route. No fixture-placement physics test in capture.
var watchdog_at := 0
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	watchdog_at = Time.get_ticks_msec() + 3900000
	_run.call_deferred()
func _process(_delta: float) -> void:
	if Time.get_ticks_msec() > watchdog_at:
		print("F3_CAPTURE_WATCHDOG")
		get_tree().quit(2)
func _run() -> void:
	var placeholder := Node.new()
	get_tree().root.add_child(placeholder)
	get_tree().current_scene = placeholder
	await before_each()
	GameState.show_warning()
	await frames(2.5)
	key(KEY_K)
	await frames(1)
	check(GameState.state == &"menu","warning to menu")
	var started := Engine.get_process_frames()
	await test_full_input_route_finale_credits_and_replay()
	print("F3_CAPTURE_SUCCESS_ROUTE_FRAMES=",Engine.get_process_frames()-started)
	await walk_to(-4.3)
	if ov.is_active():
		await dismiss(KEY_E)
	for rung in 6:
		await frames(level.director.get_remaining()+0.05)
		if rung < 4:
			await dismiss()
		elif rung == 4:
			await frames(0.65)
	check(GameState.state == &"failed","capture GRAB failure")
	await frames(5.2)
	check(GameState.state == &"menu","capture failure returned menu")
	await after_each()
	ov.queue_free()
	await get_tree().process_frame
	var until := Time.get_ticks_msec()+350
	while Time.get_ticks_msec()<until:
		OS.delay_msec(10)
		await get_tree().process_frame
	print("F3_CAPTURE_FINISHED failures=",failures.size()," rendered_frames=",Engine.get_process_frames())
	get_tree().quit(0 if failures.is_empty() else 1)
