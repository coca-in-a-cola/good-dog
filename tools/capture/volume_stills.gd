extends Node
## Capture driver for master volume stills:
## Captures production main_menu and GameState pause UI at 0, 50, and 100 volume.

const OUT_DIR := "res://evidence/owner-ui-zfight/menu-v3"
const VOLUMES: Array[float] = [0.0, 50.0, 100.0]

var orig_master_vol: float = 100.0
var orig_tree_paused: bool = false
var orig_gs_paused: bool = false
var orig_gs_state: StringName = &"boot"
var menu_instance: Control = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()

func _cleanup() -> void:
	print("[volume_stills] Restoring original state...")
	var gs := get_node_or_null(^"/root/GameState")
	if gs != null:
		gs._set_paused(orig_gs_paused)
		gs.state = orig_gs_state
	get_tree().paused = orig_tree_paused
	var am := get_node_or_null(^"/root/AudioMix")
	if am != null:
		am.set_master_volume(orig_master_vol, false)
	if menu_instance != null and is_instance_valid(menu_instance):
		menu_instance.queue_free()

func _run() -> void:
	var am := get_node_or_null(^"/root/AudioMix")
	var gs := get_node_or_null(^"/root/GameState")
	if am == null or gs == null:
		push_error("Missing AudioMix or GameState autoload")
		get_tree().quit(1)
		return

	# Record original memory state
	orig_master_vol = am.master_volume
	orig_tree_paused = get_tree().paused
	orig_gs_paused = gs.paused
	orig_gs_state = gs.state
	print("[volume_stills] Saved original state: volume=", orig_master_vol, " paused=", orig_gs_paused, " state=", orig_gs_state)

	var abs_out_dir := ProjectSettings.globalize_path(OUT_DIR)
	DirAccess.make_dir_recursive_absolute(abs_out_dir)

	var rendering_method: String = ProjectSettings.get_setting("rendering/renderer/rendering_method", "unknown")
	var video_adapter: String = RenderingServer.get_video_adapter_name()
	print("[volume_stills] Renderer method: ", rendering_method, " Adapter: ", video_adapter)

	# Instantiate production main_menu
	var menu_scene: PackedScene = load("res://scenes/main_menu.tscn")
	menu_instance = menu_scene.instantiate()
	add_child(menu_instance)
	menu_instance.visible = true

	# Ensure pause layer is hidden for menu capture
	gs._set_paused(false)

	# Warm up frames
	for f in 5:
		await get_tree().process_frame

	var captured_files: Array[String] = []

	# 1. Main Menu captures at 0, 50, 100
	for vol in VOLUMES:
		var code := "%03d" % int(round(vol))
		print("[volume_stills] Capturing menu at volume ", vol, " (", code, ")...")
		am.set_master_volume(vol, false)
		for f in 4:
			await get_tree().process_frame
		RenderingServer.force_draw()
		var img := get_viewport().get_texture().get_image()
		var filename := "menu-%s.png" % code
		var file_path := abs_out_dir.path_join(filename)
		var err := img.save_png(file_path)
		if err != OK:
			push_error("Failed to save " + file_path + " err=" + str(err))
			_cleanup()
			get_tree().quit(1)
			return
		print("[volume_stills] Saved ", file_path, " size=", img.get_size())
		captured_files.append(file_path)

	# 2. Pause UI captures at 0, 50, 100
	# "Capture pause via GameState state playing then _set_paused(true) (root capture driver process_mode ALWAYS to keep advancing) and hide mainmenu behind it if necessary; production UI do not mock."
	print("[volume_stills] Transitioning to pause UI...")
	menu_instance.visible = false
	gs.state = &"playing"
	gs._set_paused(true)

	for f in 5:
		await get_tree().process_frame

	for vol in VOLUMES:
		var code := "%03d" % int(round(vol))
		print("[volume_stills] Capturing pause at volume ", vol, " (", code, ")...")
		am.set_master_volume(vol, false)
		for f in 4:
			await get_tree().process_frame
		RenderingServer.force_draw()
		var img := get_viewport().get_texture().get_image()
		var filename := "pause-%s.png" % code
		var file_path := abs_out_dir.path_join(filename)
		var err := img.save_png(file_path)
		if err != OK:
			push_error("Failed to save " + file_path + " err=" + str(err))
			_cleanup()
			get_tree().quit(1)
			return
		print("[volume_stills] Saved ", file_path, " size=", img.get_size())
		captured_files.append(file_path)

	_cleanup()
	print("[volume_stills] VOLUME_STILLS_COMPLETE count=", captured_files.size())
	for p in captured_files:
		var f := FileAccess.open(p, FileAccess.READ)
		var sz := f.get_length() if f != null else 0
		print("  IMAGE: ", p, " bytes=", sz)
	get_tree().quit(0)
