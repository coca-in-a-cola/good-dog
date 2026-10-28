extends "res://tests/test_f3_route.gd"
## Bounded normal-route native stills: no full-movie rerender, no acceptance.
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()

func shot(label: String) -> void:
	RenderingServer.force_draw()
	var image := get_viewport().get_texture().get_image()
	check(image.save_png("res://evidence/f3/edge-repair/"+label+".png") == OK,"native PNG saved "+label)
	print("F3_EDGE_NATIVE_FRAME ",label," player=",level.player.global_position)

func _run() -> void:
	# Keep this driver outside current_scene before production scene changes.
	var placeholder := Node.new()
	get_tree().root.add_child(placeholder)
	get_tree().current_scene = placeholder
	await before_each()
	await start()
	await grab()
	await look_pitch(-0.6)
	await walk_to(-24.2)
	shot("normal-carry-circle")
	key(KEY_E)
	check(level.place_zone.done,"normal-route fresh E places")
	await dismiss()
	shot("normal-placed-center")
	await walk_to(-31.1)
	if ov.is_active():
		await dismiss()
	check(level.leash_ctl.active,"normal-route hall leash active")
	shot("normal-leash-hall")
	print("F3_EDGE_STILLS_COMPLETE failures=",failures.size()," assertions=",assertions)
	await after_each()
	ov.queue_free()
	await get_tree().process_frame
	var until := Time.get_ticks_msec()+400
	while Time.get_ticks_msec()<until:
		await get_tree().process_frame
	get_tree().quit(0 if failures.is_empty() else 1)
