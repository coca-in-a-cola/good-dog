extends "res://tests/test_finale_layout.gd"
## Bounded production UI capture; does not replay or replace the historical movie.
func _ready() -> void:
	_run.call_deferred()
func shot(view: SubViewport, filename: String) -> void:
	RenderingServer.force_draw()
	check(view.get_texture().get_image().save_png("res://evidence/f3/credits-repair/"+filename+".png") == OK, "native PNG saved "+filename)
func _run() -> void:
	await before_each()
	await test_production_credits_shaped_glyphs_safe_and_centered()
	# Force a short real native render warmup, not a full-route render.
	for view in views:
		view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	for i in 4:
		await get_tree().process_frame
	for i in views.size():
		shot(views[i], ["credits-1920x1080", "credits-720x1280", "credits-2560x1080"][i])
	var finale = views[0].get_child(0)
	finale.stage = 1
	finale.label.text = GameState.FINAL_LINES[1]
	finale._layout_text()
	for i in 45:
		await get_tree().process_frame
	shot(views[0], "finale-1920x1080")
	print("F3_FINALE_STILLS_COMPLETE failures=",failures.size()," assertions=",assertions)
	await after_each()
	get_node("/root/Overlay").queue_free()
	await get_tree().process_frame
	await get_tree().create_timer(0.4).timeout
	get_tree().quit(0 if failures.is_empty() else 1)
