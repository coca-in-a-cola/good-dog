extends SceneTree
## F5 mix calibration capture. A fixture, not a walkthrough: drives the
## production level in real time with injected input, records the Master bus
## after its limiter through AudioEffectCapture, and reports BS.1770 integrated
## loudness and true peak for two programmes.
##   godot4 --headless --path . -s res://tools/audio/mix_capture.gd -- <out_dir>
##
## Gameplay: prologue → BARK (dismiss) → walking → bark → GOOD. DOG. →
## transformation → corridor → GRAB order → full ladder with pacing → BAD DOG.
## Finale: the finale scene for 6 s (popper, applause, jingle).
## Writes <out_dir>/mix_gameplay.wav and mix_finale.wav (s16 stereo at the mix
## rate) so ffmpeg's ebur128 can cross-check the GDScript meter. Also prints
## pre-fader loudness per bus and a 3 s short-term timeline for diagnosis.
## Headless uses the Dummy driver (mixes in real time at 44.1 kHz).

const Loudness := preload("res://tools/audio/loudness.gd")
const AUTO_DISMISS_AFTER := 1.4

## Diagnostic per-bus captures (end of each bus chain, before its fader).
const DIAGNOSTIC_BUSES: Array[StringName] = [&"SFX", &"Ambience", &"UI", &"Music"]

var capture: AudioEffectCapture
var left := PackedFloat32Array()
var right := PackedFloat32Array()
var out_dir := "res://evidence/f5"
var bus_captures := {}
var bus_audio := {}
var _active_since := -1.0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		out_dir = args[0]
	capture = AudioEffectCapture.new()
	capture.buffer_length = 4.0
	AudioServer.add_bus_effect(0, capture, -1)  # after the HardLimiter
	for bus in DIAGNOSTIC_BUSES:
		var c := AudioEffectCapture.new()
		c.buffer_length = 4.0
		AudioServer.add_bus_effect(AudioServer.get_bus_index(bus), c, -1)
		bus_captures[bus] = c
		bus_audio[bus] = [PackedFloat32Array(), PackedFloat32Array()]
	_run.call_deferred()


func _process(_delta: float) -> bool:
	_drain()
	return false


func _run() -> void:
	var rate := AudioServer.get_mix_rate()
	print("MIX_CAPTURE rate=", rate, " driver=", AudioServer.get_driver_name() if AudioServer.has_method(&"get_driver_name") else "?")
	var gs := game_state()
	gs.start_game()
	await wait(4.4)
	var level: Node = current_scene
	await walk(&"move_backward", 1.2)
	await walk(&"move_forward", 1.2)
	await wait(0.8)
	key(KEY_B)
	await wait(4.5)
	await walk(&"move_forward", 2.6)
	await wait(1.6)
	var pace := [&"move_forward", &"move_backward"]
	var i := 0
	while gs.state == &"playing" and i < 60:
		await walk(pace[i % 2], 1.0)
		i += 1
	print("MIX_CAPTURE ladder_state=", gs.state, " cues=", level.audio.cue_counts if is_instance_valid(level) else {})
	await wait(5.6)
	_drain()
	var gameplay_end := left.size()
	var bus_end := {}
	for bus: StringName in DIAGNOSTIC_BUSES:
		bus_end[bus] = bus_audio[bus][0].size()
	change_scene_to_file("res://scenes/finale.tscn")
	await wait(6.0)
	_drain()
	# Analysis blocks the main thread, so it runs only after capturing ends.
	for bus: StringName in DIAGNOSTIC_BUSES:
		var ch: Array = bus_audio[bus]
		var m: Dictionary = Loudness.measure_channels([ch[0].slice(0, bus_end[bus]), ch[1].slice(0, bus_end[bus])], rate)
		print("MIX_BUS %s gameplay_pre_fader_integrated_lufs=%.2f" % [bus, m.integrated])
	_timeline(left.slice(0, gameplay_end), right.slice(0, gameplay_end), rate)
	_report("gameplay", left.slice(0, gameplay_end), right.slice(0, gameplay_end), rate)
	_report("finale", left.slice(gameplay_end), right.slice(gameplay_end), rate)
	AudioServer.remove_bus_effect(0, AudioServer.get_bus_effect_count(0) - 1)
	for bus in DIAGNOSTIC_BUSES:
		var idx := AudioServer.get_bus_index(bus)
		AudioServer.remove_bus_effect(idx, AudioServer.get_bus_effect_count(idx) - 1)
	var ov := root.get_node_or_null("Overlay")
	if ov != null:
		ov.force_hide()
	change_scene_to_file("res://scenes/main_menu.tscn")
	await wait(0.5)
	quit(0)


## Autoload names are not compile-time identifiers in a -s main-loop script.
func game_state() -> Node:
	return root.get_node("GameState")


func wait(seconds: float) -> void:
	var end := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < end:
		_auto_dismiss()
		await process_frame


func walk(action: StringName, seconds: float) -> void:
	Input.action_press(action)
	await wait(seconds)
	Input.action_release(action)


func key(code: Key) -> void:
	for pressed in [true, false]:
		var e := InputEventKey.new()
		e.keycode = code
		e.physical_keycode = code
		e.pressed = pressed
		Input.parse_input_event(e)
	Input.flush_buffered_events()


## Modal lines are dismissed after a human-ish read time; FLASH lines auto-hide.
func _auto_dismiss() -> void:
	var ov := root.get_node_or_null("Overlay")
	var line: OverlayLine = ov.get_current_line() if ov != null else null
	if line == null or line.mode == OverlayLine.Mode.FLASH or game_state().state != &"playing":
		_active_since = -1.0
		return
	var now := Time.get_ticks_msec() / 1000.0
	if _active_since < 0.0:
		_active_since = now
	elif now - _active_since >= AUTO_DISMISS_AFTER + line.get_words().size() * line.word_interval:
		_active_since = -1.0
		var held: Array[StringName] = []
		for action in [&"move_forward", &"move_backward"]:
			if Input.is_action_pressed(action):
				held.append(action)
		key(KEY_K)
		for action in held:
			Input.action_press(action)


func _drain() -> void:
	if capture == null:
		return
	_pull(capture, left, right)
	for bus: StringName in bus_captures:
		var ch: Array = bus_audio[bus]
		_pull(bus_captures[bus], ch[0], ch[1])


func _pull(c: AudioEffectCapture, l: PackedFloat32Array, r: PackedFloat32Array) -> void:
	var n := c.get_frames_available()
	if n <= 0:
		return
	for v in c.get_buffer(n):
		l.append(v.x)
		r.append(v.y)


## Short-term (3 s) loudness every 3 s of the Master capture.
func _timeline(l: PackedFloat32Array, r: PackedFloat32Array, rate: float) -> void:
	var window := int(3.0 * rate)
	var line := "MIX_TIMELINE"
	var start := 0
	while start + window <= l.size():
		var m: Dictionary = Loudness.measure_channels([l.slice(start, start + window), r.slice(start, start + window)], rate)
		line += " %d:%.1f" % [roundi(start / rate), m.integrated]
		start += window
	print(line)


func _report(label: String, l: PackedFloat32Array, r: PackedFloat32Array, rate: float) -> void:
	var m: Dictionary = Loudness.measure_channels([l, r], rate)
	var tp := maxf(Loudness.true_peak(l), Loudness.true_peak(r))
	print("MIX_RESULT %s seconds=%.2f integrated_lufs=%.2f max_momentary=%.2f true_peak_dbtp=%.2f" % [
			label, l.size() / rate, m.integrated, m.max_momentary, Loudness.db(tp)])
	var path := out_dir.path_join("mix_%s.wav" % label)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.stereo = true
	wav.mix_rate = int(rate)
	var pcm := PackedByteArray()
	pcm.resize(l.size() * 4)
	for i in l.size():
		pcm.encode_s16(i * 4, clampi(roundi(l[i] * 32767.0), -32768, 32767))
		pcm.encode_s16(i * 4 + 2, clampi(roundi(r[i] * 32767.0), -32768, 32767))
	wav.data = pcm
	wav.save_to_wav(path)
