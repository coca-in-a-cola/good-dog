extends SceneTree
## Deterministic Godot-native test runner.
##   godot4 --headless --path <project> -s res://tests/run_tests.gd
## Optional user arg after `--`: suite script paths (default: SUITES).
## Exit code 0 = all assertions passed, 1 = failures.

const SUITES := ["res://tests/test_command_overlay.gd", "res://tests/test_f2_core.gd"]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var paths: Array = SUITES
	var user_args := OS.get_cmdline_user_args()
	if not user_args.is_empty():
		paths = Array(user_args)
	var total_pass := 0
	var total_fail := 0
	for path: String in paths:
		var script: GDScript = load(path)
		if script == null or not script.can_instantiate():
			print("FAIL %s :: could not load suite" % path)
			total_fail += 1
			continue
		var suite: Node = script.new()
		suite.name = path.get_file().get_basename()
		root.add_child(suite)
		for method in suite.get_method_list():
			var test_name: String = method.name
			if not test_name.begins_with("test_"):
				continue
			await suite.before_each()
			await suite.call(test_name)
			await suite.after_each()
			var failed: int = suite.failures.size()
			print("%s %s :: %s (%d assertions)" % ["FAIL" if failed else "PASS", suite.name, test_name,
					suite.assertions])
			for f: String in suite.failures:
				print("    - " + f)
			total_pass += 0 if failed else 1
			total_fail += 1 if failed else 0
		suite.queue_free()
		await process_frame
	print("RESULT: %d passed, %d failed" % [total_pass, total_fail])
	# Stopped AudioStreamPlayer playbacks are retired asynchronously by the mixer;
	# quitting in the same frame reports them as leaked.
	var settle := Time.get_ticks_msec() + 300
	while Time.get_ticks_msec() < settle:
		await process_frame
	quit(1 if total_fail else 0)
