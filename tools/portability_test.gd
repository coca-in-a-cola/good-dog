extends SceneTree
## Copies addons/command_overlay into a fresh, empty Godot project and runs it there.
##   godot4 --headless --path <workspace> -s res://tools/portability_test.gd [-- --keep]
##
## The temporary project is <workspace>/.tmp/portability (ignored by git, and by the
## main Godot project via .tmp/.gdignore). It is deleted afterwards unless --keep.
## Two variants: no autoload, and the autoload/plugin entries the plugin writes.
## Steps per variant: editor import, portable_smoke.gd, demo autoplay smoke.
## Exit 0 only if every step exits 0 and prints no ERROR/WARNING lines.

const BASE_PROJECT := """config_version=5

[application]

config/name="command_overlay portability check"
config/features=PackedStringArray("4.7", "Forward Plus")
"""

const AUTOLOAD := """
[autoload]

Overlay="*res://addons/command_overlay/overlay.tscn"

[editor_plugins]

enabled=PackedStringArray("res://addons/command_overlay/plugin.cfg")
"""


func _initialize() -> void:
	var code := _run()
	quit(code)


func _run() -> int:
	var root_dir := ProjectSettings.globalize_path("res://").trim_suffix("/")
	var tmp := root_dir.path_join(".tmp")
	var project := tmp.path_join("portability")
	var godot := OS.get_executable_path()
	DirAccess.make_dir_recursive_absolute(tmp)
	FileAccess.open(tmp.path_join(".gdignore"), FileAccess.WRITE).close()
	var results: Array[String] = []
	var ok := true
	for variant: String in ["no-autoload", "plugin-autoload"]:
		print("== variant: %s" % variant)
		_remove_tree(project)
		DirAccess.make_dir_recursive_absolute(project)
		var f := FileAccess.open(project.path_join("project.godot"), FileAccess.WRITE)
		f.store_string(BASE_PROJECT + (AUTOLOAD if variant == "plugin-autoload" else ""))
		f.close()
		_copy_tree(root_dir.path_join("addons/command_overlay"), project.path_join("addons/command_overlay"))
		var steps := {
			"import": ["--headless", "--path", project, "--editor", "--quit"],
			"portable_smoke": ["--headless", "--path", project, "-s",
					"res://addons/command_overlay/demo/portable_smoke.gd"],
			"demo_autoplay": ["--headless", "--path", project, "res://addons/command_overlay/demo/demo.tscn",
					"--", "--overlay-demo-autoplay"],
		}
		var markers := {portable_smoke = "portable_smoke: PASS", demo_autoplay = "[demo-smoke] finished, failures=0"}
		for step: String in steps:
			var output := []
			var log_path := tmp.path_join("%s_%s.log" % [variant, step])
			DirAccess.remove_absolute(log_path)
			var args: PackedStringArray = steps[step]
			args.insert(0, log_path)
			args.insert(0, "--log-file")
			print("$ %s %s" % [godot, " ".join(args)])
			var code := OS.execute(godot, args, output, true)
			# Read the child's log file: piped stdout of long-running children was observed to arrive empty.
			var text := FileAccess.get_file_as_string(log_path) if FileAccess.file_exists(log_path) else "\n".join(output)
			DirAccess.remove_absolute(log_path)
			var bad := 0
			for line in text.split("\n"):
				if line.begins_with("[ ") or line.begins_with("\u001b") or line.strip_edges().is_empty():
					continue  # progress bars
				print("    " + line)
				if line.begins_with("ERROR") or line.begins_with("SCRIPT ERROR") or line.begins_with("WARNING"):
					bad += 1
			var marker_ok: bool = not markers.has(step) or text.contains(markers[step])
			results.append("%-16s %-15s exit=%d error/warning lines=%d marker=%s" % [variant, step, code, bad,
					"found" if marker_ok else "MISSING"])
			ok = ok and code == 0 and bad == 0 and marker_ok
	if not "--keep" in OS.get_cmdline_user_args():
		_remove_tree(project)
		print("cleaned %s (exists now: %s)" % [project, DirAccess.dir_exists_absolute(project)])
	print("== summary")
	for r in results:
		print(r)
	print("PORTABILITY: %s" % ("PASS" if ok else "FAIL"))
	return 0 if ok else 1


func _copy_tree(from: String, to: String) -> void:
	DirAccess.make_dir_recursive_absolute(to)
	var d := DirAccess.open(from)
	d.include_hidden = false
	for file in d.get_files():  # copied verbatim, as a user copying the folder would
		DirAccess.copy_absolute(from.path_join(file), to.path_join(file))
	for sub in d.get_directories():
		_copy_tree(from.path_join(sub), to.path_join(sub))


func _remove_tree(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	var d := DirAccess.open(path)
	d.include_hidden = true
	for file in d.get_files():
		DirAccess.remove_absolute(path.path_join(file))
	for sub in d.get_directories():
		_remove_tree(path.path_join(sub))
	DirAccess.remove_absolute(path)
