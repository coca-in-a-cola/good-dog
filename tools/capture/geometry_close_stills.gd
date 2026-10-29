extends Node
## Geometry close stills capture driver for z-fighting QA.
## Captures 4 native close-angle geometry PNGs:
## 1. Doorway seam at z = -20.6
## 2. Connector threshold at z = -29.6
## 3. Pit lip north close angle looking rim floor (center z = -40.6, r = 1.5)
## 4. Pit lip west close angle looking rim floor (center z = -40.6, r = 1.5)

const OUT_DIR := "res://evidence/owner-ui-zfight/geometry-v2"

var orig_tree_paused: bool = false
var orig_gs_paused: bool = false
var orig_gs_state: StringName = &"boot"
var level: Node3D = null
var cam: Camera3D = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()

func _cleanup() -> void:
	print("[geometry_close_stills] Restoring original state...")
	var gs := get_node_or_null(^"/root/GameState")
	if gs != null:
		if gs.has_method("_set_paused"):
			gs._set_paused(orig_gs_paused)
		gs.state = orig_gs_state
	get_tree().paused = orig_tree_paused
	if level != null and is_instance_valid(level):
		level.queue_free()

func _run() -> void:
	var gs := get_node_or_null(^"/root/GameState")
	if gs == null:
		push_error("Missing GameState autoload")
		get_tree().quit(1)
		return

	# Record original state
	orig_tree_paused = get_tree().paused
	orig_gs_paused = gs.paused if "paused" in gs else false
	orig_gs_state = gs.state
	print("[geometry_close_stills] Saved original state: paused=", orig_gs_paused, " state=", orig_gs_state)

	var abs_out_dir := ProjectSettings.globalize_path(OUT_DIR)
	DirAccess.make_dir_recursive_absolute(abs_out_dir)

	# Production level instantiation
	gs.state = &"playing"
	var level_scene: PackedScene = load("res://scenes/level.tscn")
	if level_scene == null:
		push_error("Failed to load res://scenes/level.tscn")
		_cleanup()
		get_tree().quit(1)
		return

	level = level_scene.instantiate()
	get_tree().root.add_child(level)
	get_tree().current_scene = level

	# Warm up frames
	for f in 3:
		await get_tree().process_frame

	# Suppress overlays and gameplay controllers
	var overlay := get_node_or_null(^"/root/Overlay")
	if overlay != null and overlay.has_method("force_hide"):
		overlay.force_hide()

	if "player" in level and level.player != null:
		level.player.set_physics_process(false)
		level.player.set_process(false)
	level.set_process(false)
	if "transform_ctl" in level and level.transform_ctl != null:
		level.transform_ctl.set_process(false)
	if "leash_ctl" in level and level.leash_ctl != null:
		level.leash_ctl.deactivate()
	if level.has_node("PressureController"):
		level.get_node("PressureController").set_process(false)

	if cam == null:
		cam = Camera3D.new()
		cam.name = "CaptureCam"
		level.add_child(cam)

	cam.current = true
	cam.make_current()

	var views: Array[Dictionary] = [
		{
			"name": "doorway_seam",
			"cam_pos": Vector3(1.0, 1.5, -18.5),
			"target": Vector3(0.0, 0.0, -20.6)
		},
		{
			"name": "connector_threshold",
			"cam_pos": Vector3(1.5, 1.7, -27.5),
			"target": Vector3(0.0, 0.0, -29.6)
		},
		{
			"name": "pit_lip_north",
			# Pit center (0, 0, -40.6), radius 1.5 -> North rim at (0, 0, -42.1)
			# North close angle looking at rim floor
			"cam_pos": Vector3(0.0, 1.4, -43.2),
			"target": Vector3(0.0, 0.0, -42.1)
		},
		{
			"name": "pit_lip_west",
			# Pit center (0, 0, -40.6), radius 1.5 -> West rim at (-1.5, 0, -40.6)
			# West close angle looking at rim floor
			"cam_pos": Vector3(-2.6, 1.4, -40.6),
			"target": Vector3(-1.5, 0.0, -40.6)
		}
	]

	var offsets: Array[Dictionary] = [
		{"name": "view_0", "dx": -0.15},
		{"name": "view_1", "dx": 0.0},
		{"name": "view_2", "dx": 0.15},
	]

	var captured_files: Array[String] = []

	for v in views:
		var view_name: String = v["name"]
		var base_cam_pos: Vector3 = v["cam_pos"]
		var target: Vector3 = v["target"]

		for offset in offsets:
			var offset_name: String = offset["name"]
			var dx: float = offset["dx"]
			var cam_pos := base_cam_pos + Vector3(dx, 0.0, 0.0)

			print("[geometry_close_stills] Setting pose %s %s cam=%s target=%s" % [view_name, offset_name, cam_pos, target])
			cam.global_position = cam_pos
			cam.look_at(target, Vector3.UP)

			for f in 2:
				await get_tree().process_frame

			var vp_cam := get_viewport().get_camera_3d()
			assert(vp_cam == cam, "Viewport current camera is not capture camera!")
			assert(cam.is_current(), "Capture camera is not current!")
			assert(cam.global_position.is_equal_approx(cam_pos), "Camera position shifted during wait frames: expected %s, got %s" % [cam_pos, cam.global_position])
			print("[geometry_close_stills] VERIFIED POSE: view=%s offset=%s global_pos=%s global_rot=%s target=%s" % [view_name, offset_name, cam.global_position, cam.global_rotation, target])

			RenderingServer.force_draw()
			var img := get_viewport().get_texture().get_image()
			var filename := "%s_%s.png" % [view_name, offset_name]
			var file_path := abs_out_dir.path_join(filename)
			var err := img.save_png(file_path)
			if err != OK:
				push_error("Failed to save " + file_path + " err=" + str(err))
				_cleanup()
				get_tree().quit(1)
				return

			print("[geometry_close_stills] Saved ", file_path, " size=", img.get_size(), " pose=", cam.global_position)
			captured_files.append(file_path)

	_cleanup()
	print("[geometry_close_stills] GEOMETRY_CLOSE_STILLS_COMPLETE count=", captured_files.size())
	for p in captured_files:
		var f := FileAccess.open(p, FileAccess.READ)
		var sz := f.get_length() if f != null else 0
		print("  IMAGE: ", p, " bytes=", sz)
	get_tree().quit(0)
