extends Node
## Spatial fixtures on native production camera, NOT traversal evidence.
var level: Node3D

func _ready() -> void:
	capture.call_deferred()

func frame(label: String, at: Vector3, target: Vector3, eye: float) -> void:
	level.player.position = at
	level.player.eye_height_m = eye
	level.player.head.position.y = eye
	level.player.head.rotation = Vector3.ZERO
	level.player.rotation = Vector3.ZERO
	var cam: Camera3D = level.player.camera
	cam.position = Vector3.ZERO
	cam.global_position = at + Vector3(0, eye, 0)
	cam.make_current()
	cam.look_at(target, Vector3.UP)
	for i in 5:
		await get_tree().process_frame
		await get_tree().physics_frame
	RenderingServer.force_draw()
	var image := get_viewport().get_texture().get_image()
	image.save_png("res://evidence/f4/remaining/" + label + ".png")
	print("F4_SPATIAL_FIXTURE ", label, " eye=", eye, " at=", at, " target=", target)

func capture() -> void:
	GameState.state = &"playing"
	level = preload("res://scenes/level.tscn").instantiate()
	get_tree().root.add_child(level)
	get_tree().current_scene = level
	for i in 5:
		await get_tree().process_frame
	get_node("/root/Overlay").force_hide()
	level.player.set_physics_process(false)
	level.set_process(false)
	level.transform_ctl.set_process(false)
	level.leash_ctl.deactivate()
	level.get_node("PressureController").set_process(false)
	await frame("observation-standing-1_70", Vector3(-2, 0, -25.8), Vector3(3.9, 1.65, -23.4), 1.7)
	await frame("observation-low-0_45", Vector3(-1.6, 0, -26.8), Vector3(3.6, 1.15, -23.2), 0.45)
	await frame("pit-hall-rim-1_70", Vector3(-2.9, 0, -38.7), Vector3(0, -0.1, -40.6), 1.7)
	await frame("pit-hall-fall-0_45", Vector3(0.25, -2, -40.6), Vector3(0.35, -12, -40.7), 0.45)
	level.queue_free()
	for i in 3:
		await get_tree().process_frame
	get_node("/root/Overlay").queue_free()
	for i in 3:
		await get_tree().process_frame
	OS.delay_msec(400)
	print("F4_SPATIAL_FIXTURES_COMPLETE")
	get_tree().quit()
