extends SceneTree
## Deterministic Godot-native test runner.
##   godot4 --headless --path <project> -s res://tests/run_tests.gd
## Optional user arg after `--`: suite script paths (default: SUITES).
## Exit code 0 = all assertions passed, 1 = failures.

const SUITES := ["res://tests/test_command_overlay.gd", "res://tests/test_f2_core.gd", "res://tests/test_f3_route.gd", "res://tests/test_finale_layout.gd", "res://tests/test_f4_art.gd", "res://tests/test_f5_audio.gd", "res://tests/test_f6_camera_post.gd"]
## Route-driven suites run in a bounded fixed-step child process.
const FIXED_STEP_SUITES := ["res://tests/test_f3_route.gd", "res://tests/test_f4_art.gd", "res://tests/test_f5_audio.gd"]
var watchdog_at := 0
var active_test := ""

func _process(_delta: float) -> bool:
	if watchdog_at > 0 and Time.get_ticks_msec() > watchdog_at:
		print("FAIL WATCHDOG :: %s did not complete fixture/test/cleanup" % active_test)
		quit(2)
	return false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var paths: Array = SUITES
	var user_args := OS.get_cmdline_user_args()
	var fixed_child := user_args.has("--f3-fixed-child")
	if fixed_child:
		user_args.remove_at(user_args.find("--f3-fixed-child"))
	if not user_args.is_empty():
		paths = Array(user_args)
	var total_pass := 0
	var total_fail := 0
	for path: String in paths:
		# F1 verifies WALL CLOCK thaw. F3 needs 3600 real physics ticks plus
		# several minutes of manual-clock ladders. Isolate fixed-step execution
		# in a child instead of accelerating the real-time overlay tests.
		if path in FIXED_STEP_SUITES and not fixed_child:
			var output: Array = []
			var code := OS.execute("timeout", ["60", OS.get_executable_path(), "--headless", "--path", ProjectSettings.globalize_path("res://"), "--fixed-fps", "60", "-s", "res://tests/run_tests.gd", "--", "--f3-fixed-child", path], output, true)
			var text := "\n".join(output)
			print(text)
			var result := RegEx.new()
			result.compile("RESULT: ([0-9]+) passed, ([0-9]+) failed")
			var match_result := result.search(text)
			if code != 0 or match_result == null or text.contains("SCRIPT ERROR:") or text.contains("ERROR:") or text.contains("WARNING:"):
				print("FAIL F3 bounded child :: exit=%d; complete clean RESULT required" % code)
				total_fail += 1
			else:
				total_pass += int(match_result.get_string(1))
				total_fail += int(match_result.get_string(2))
			continue
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
			active_test = "%s :: %s" % [suite.name, test_name]
			watchdog_at = Time.get_ticks_msec() + 20000
			print("BEGIN ", active_test)
			await suite.before_each()
			await suite.call(test_name)
			await suite.after_each()
			watchdog_at = 0
			suite.check(suite.assertions > 0, "test returned with nonzero assertions")
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
	# Retire the autoload's audio BEFORE the real-time mixer settle, not only
	# during engine teardown (fast fixed-step routes can leave a WAV playing).
	var overlay := root.get_node_or_null("Overlay")
	if overlay != null:
		overlay.force_hide()
		overlay.queue_free()
		await process_frame
	# Stopped AudioStreamPlayer playbacks are retired asynchronously by the mixer;
	# quitting in the same frame reports them as leaked.
	var settle := Time.get_ticks_msec() + 300
	while Time.get_ticks_msec() < settle:
		await process_frame
	quit(1 if total_fail else 0)
