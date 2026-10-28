extends Node
## F2 shared-core tests: production Command/TransformStep data, CommandDirector,
## GameState lifecycle, player adapter, pressure/transform adapters, leash and
## interactable contracts. Uses the real Overlay and GameState autoloads with
## their manual clocks; no parallel game mock.

const BARK := preload("res://data/commands/bark.tres")
const QUIET := preload("res://data/lines/quiet.tres")
const BAD_DOG := preload("res://data/lines/bad_dog.tres")
const PLAYER_SCENE := preload("res://scenes/player.tscn")
const STEP_PATHS := ["res://data/transform/step_0.tres", "res://data/transform/step_1.tres",
		"res://data/transform/step_2.tres", "res://data/transform/step_3.tres", "res://data/transform/step_4.tres"]
const State := CommandDirector.State


class Probe:
	extends Interactable
	signal grabbed


var failures: Array[String] = []
var assertions := 0
var director: CommandDirector
var events: Array[String] = []
var ov: Node
var nodes: Array[Node] = []


# --- Fixture ------------------------------------------------------------------

func before_each() -> void:
	failures.clear()
	assertions = 0
	events.clear()
	nodes.clear()
	get_tree().paused = false
	Engine.time_scale = 1.0
	ov = get_node(^"/root/Overlay")
	ov.use_manual_clock = true
	ov.force_hide()
	GameState.clock.manual = true
	director = _new_director()
	await get_tree().process_frame


func after_each() -> void:
	for n in nodes:
		if is_instance_valid(n):
			n.queue_free()
	if is_instance_valid(director):
		director.queue_free()
	ov.force_hide()
	ov.reduce_flashes = false
	ov.reduce_shake = false
	if GameState.paused:
		GameState.resume()
	GameState.state = &"boot"
	for k in [KEY_B, KEY_K, KEY_ESCAPE]:
		_key(k, false)
	get_tree().paused = false
	Engine.time_scale = 1.0
	await get_tree().process_frame
	ov.use_manual_clock = false
	GameState.clock.manual = false


func _new_director() -> CommandDirector:
	var d := CommandDirector.new()
	d.quiet_line = QUIET
	d.bad_dog_line = BAD_DOG
	d.state_changed.connect(func(s: State) -> void: events.append("state:%s" % State.keys()[s]))
	d.pressure_changed.connect(func(l: int) -> void: events.append("pressure:%d" % l))
	d.command_succeeded.connect(func(id: StringName) -> void: events.append("succeeded:%s" % id))
	d.command_completed.connect(func(id: StringName) -> void: events.append("completed:%s" % id))
	d.transform_requested.connect(func(s: int) -> void: events.append("transform:%d" % s))
	d.quiet_issued.connect(func() -> void: events.append("quiet"))
	d.failed.connect(func() -> void: events.append("failed"))
	d.hint_changed.connect(func(t: String) -> void: events.append("hint:%s" % t))
	add_child(d)
	return d


func _player() -> GoodDogPlayer:
	var p: GoodDogPlayer = PLAYER_SCENE.instantiate()
	add_child(p)
	nodes.append(p)
	return p


## Advances both real clocks in deterministic slices, ticking the director.
func _step(seconds: float, dt := 0.05) -> void:
	var left := seconds
	while left > 0.000001:
		var s := minf(dt, left)
		left -= s
		GameState.clock.advance(s)
		ov.advance_clock(s)
		if is_instance_valid(director):
			director.tick()


## Same, but lets every _process run (level, GameState, transform).
func _frames(seconds: float, dt := 0.1) -> void:
	var left := seconds
	while left > 0.000001:
		var s := minf(dt, left)
		left -= s
		GameState.clock.advance(s)
		ov.advance_clock(s)
		await get_tree().process_frame


func _key(keycode: Key, pressed := true, echo := false) -> void:
	var e := InputEventKey.new()
	e.keycode = keycode
	e.physical_keycode = keycode
	e.pressed = pressed
	e.echo = echo
	Input.parse_input_event(e)
	Input.flush_buffered_events()


func _tap(keycode: Key) -> void:
	_key(keycode, true)
	_key(keycode, false)


## Dismisses the current modal order (after per-word display and the 0.35 s lock).
func _dismiss() -> void:
	_step(1.0)
	_tap(KEY_K)


func _count(prefix: String) -> int:
	return events.filter(func(e: String) -> bool: return e.begins_with(prefix)).size()


# --- Assertions ---------------------------------------------------------------

func check(cond: bool, msg: String) -> void:
	assertions += 1
	if not cond:
		failures.append(msg)


func eq(actual: Variant, expected: Variant, msg: String) -> void:
	check(actual == expected, "%s: expected <%s>, got <%s>" % [msg, expected, actual])


func near(actual: float, expected: float, eps: float, msg: String) -> void:
	check(absf(actual - expected) <= eps, "%s: expected %.4f±%.4f, got %.4f" % [msg, expected, eps, actual])


# --- Data ---------------------------------------------------------------------

func test_production_menu_all_toggle_state_colors_are_legible() -> void:
	var menu := load("res://scenes/main_menu.tscn").instantiate() as Control
	add_child(menu)
	nodes.append(menu)
	var bg: Color = menu.get_node("Background").color
	var bg_linear := bg.srgb_to_linear()
	var bg_lum := 0.2126 * bg_linear.r + 0.7152 * bg_linear.g + 0.0722 * bg_linear.b
	for path in ["Box/ReduceFlashes", "Box/ReduceShake"]:
		var toggle: CheckButton = menu.get_node(path)
		for key in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color",
				"font_focus_color", "font_disabled_color"]:
			check(toggle.has_theme_color_override(key), path + " explicit " + key)
			var linear := toggle.get_theme_color(key).srgb_to_linear()
			var lum := 0.2126 * linear.r + 0.7152 * linear.g + 0.0722 * linear.b
			check((bg_lum + 0.05) / (lum + 0.05) >= 4.5, path + " contrast " + key)

func test_command_transform_and_pressure_data() -> void:
	eq(BARK.id, &"bark", "command id")
	eq(BARK.ladder, PackedFloat32Array([20, 10, 5, 3, 2, 1]), "ladder")
	eq(BARK.completion_signal, &"barked", "completion signal")
	eq(BARK.hint_text, "PRESS [B] TO BARK", "hint")
	eq(BARK.transform_step, 1, "transform step after BARK")
	eq(BARK.order_line.mode, OverlayLine.Mode.BLACK, "rung 1 BLACK")
	eq(BARK.order_line.text, "BARK.", "exact order text")
	eq(BARK.escalation_lines.size(), 5, "escalation lines for rungs 2–6")
	eq(BARK.line_for_rung(1).mode, OverlayLine.Mode.OVER_WORLD, "rung 2 OVER_WORLD")
	eq(BARK.line_for_rung(3).get_words(), PackedStringArray(["BARK.", "NOW."]), "rung 4 per-word BARK. NOW.")
	check(BARK.line_for_rung(3).punch_scale > BARK.order_line.punch_scale, "rung 4 larger")
	check(BARK.line_for_rung(4).glow_color.r > BARK.line_for_rung(4).glow_color.b, "rung 5 reddish glow")
	eq(BARK.line_for_rung(5).mode, OverlayLine.Mode.FLASH, "rung 6 FLASH, world keeps running")
	eq(BARK.success_line.get_words(), PackedStringArray(["GOOD.", "DOG."]), "per-word praise")
	eq(QUIET.mode, OverlayLine.Mode.FLASH, "QUIET. is FLASH")
	eq(QUIET.text, "QUIET.", "exact QUIET text")
	eq(BAD_DOG.mode, OverlayLine.Mode.BLACK, "BAD DOG. BLACK")
	eq(BAD_DOG.text, "BAD DOG.", "exact BAD DOG text")
	eq(GameState.FINAL_LINES, ["CONGRATULATIONS!", "YOU WERE A GOOD DOG!"], "final strings preserved")
	var rows := [[1.70, 3.0, 75.0, 89.0], [1.40, 3.6, 78.0, 70.0], [1.05, 4.4, 82.0, 55.0],
			[0.70, 5.3, 86.0, 40.0], [0.45, 6.2, 90.0, 30.0]]
	for i in 5:
		var s: TransformStep = load(STEP_PATHS[i])
		eq(s.index, i, "step %d index" % i)
		near(s.eye_height_m, rows[i][0], 0.0001, "step %d eye height" % i)
		near(s.speed_mps, rows[i][1], 0.0001, "step %d speed" % i)
		near(s.fov_deg, rows[i][2], 0.0001, "step %d fov" % i)
		near(s.max_look_up_deg, rows[i][3], 0.0001, "step %d look up" % i)
		near(s.transition_time, 2.5, 0.0001, "step %d transition 2.5 s" % i)
		check(s.transition_curve != null, "step %d has a transition Curve" % i)
		near(s.sample_transition(0.5), 0.5, 0.05, "step %d curve ease-in-out midpoint" % i)
		check(s.sample_transition(0.1) < 0.1, "step %d curve eases in" % i)
	near((load(STEP_PATHS[0]) as TransformStep).bob_hz, 1.8, 0.0001, "bob 1.8 Hz at step 0")
	near((load(STEP_PATHS[4]) as TransformStep).bob_hz, 3.2, 0.0001, "bob 3.2 Hz at step 4")
	var pc := PressureController.new()
	add_child(pc)
	nodes.append(pc)
	var bpm := []
	for level in 6:
		pc.set_pressure_level(level)
		eq(pc.values.audio_rung, level + 1, "level %d maps to audio rung %d" % [level, level + 1])
		bpm.append(pc.values.metronome_bpm)
		eq(pc.values.heartbeat, level == 4, "heartbeat only at audio rung 5")
		eq(pc.values.tinnitus, level == 5, "tinnitus only at audio rung 6")
	eq(bpm, [0.0, 0.0, 60.0, 90.0, 120.0, 0.0], "metronome 60/90/120 on audio rungs 3–5")
	pc.set_pressure_level(0)
	near(pc.values.vignette, 0.25, 0.001, "vignette base 0.25")
	pc.set_pressure_level(5)
	near(pc.values.vignette, 0.75, 0.001, "vignette at pressure 5")
	near(pc.values.aberration, 0.006, 0.0001, "aberration 0.006 at pressure 5")
	near(pc.values.shake_trauma, 0.35, 0.001, "trauma 0.35 at pressure 5")
	pc.set_pressure_level(9)
	eq(pc.level, 5, "level clamped to 0–5")


# --- Director ladder ----------------------------------------------------------

func test_every_rung_then_bad_dog_without_seventh_rung() -> void:
	director.run(BARK)
	eq(director.state, State.ORDER_SHOWN, "order shown")
	eq(ov.get_current_line(), BARK.order_line, "BLACK BARK. displayed")
	_step(30.0)
	eq(director.state, State.ORDER_SHOWN, "timer does not run before dismissal (30 s)")
	_tap(KEY_K)
	eq(director.state, State.WAITING, "dismissal starts rung 1")
	near(director.get_remaining(), 20.0, 0.0001, "rung 1 = 20 s")
	for r in 6:
		var length: float = BARK.ladder[r]
		_step(length - 0.1)
		eq(director.state, State.WAITING, "rung %d still waiting at %.1f s" % [r + 1, length - 0.1])
		eq(director.rung, r, "rung index %d" % r)
		_step(0.15)
		if r == 5:
			break
		eq(director.state, State.ORDER_SHOWN, "rung %d expired -> next order shown" % (r + 1))
		eq(director.rung, r + 1, "now rung %d" % (r + 2))
		eq(ov.get_current_line(), BARK.line_for_rung(r + 1), "rung %d line displayed" % (r + 2))
		check(events.has("pressure:%d" % (r + 1)), "pressure level %d emitted" % (r + 1))
		if r + 1 < 5:
			_step(4.0)
			eq(director.state, State.ORDER_SHOWN, "rung %d timer waits for dismissal" % (r + 2))
			_tap(KEY_K)
		else:
			_step(0.65)  # rung 6 is FLASH: auto-hides after 0.6 s, that dismissal starts the 1 s rung
		eq(director.state, State.WAITING, "rung %d running after its dismissal" % (r + 2))
		near(director.get_remaining(), BARK.ladder[r + 1], 0.06, "rung %d starts full" % (r + 2))
	eq(director.state, State.FAIL, "last 1 s rung expired -> FAIL")
	eq(director.rung, 5, "no seventh rung")
	eq(ov.get_current_line(), BAD_DOG, "BLACK BAD DOG. shown")
	check(get_tree().paused, "BAD DOG pauses the world")
	eq(_count("failed"), 1, "failed emitted once")
	_step(30.0)
	eq(_count("failed"), 1, "no further rungs/failures")
	eq(_count("pressure:"), 6, "pressure levels 0..5 emitted once each")


func test_timer_starts_only_on_matching_dismissal() -> void:
	director.run(BARK)
	ov.force_hide()  # cancelled, not dismissed
	_step(25.0)
	eq(director.state, State.ORDER_SHOWN, "cancellation never starts the timer")
	ov.show_line(BARK.order_line)  # same id, shown by someone else
	_dismiss()
	eq(director.state, State.ORDER_SHOWN, "foreign line with same id does not start the timer")
	ov.dismissed.emit(&"bark_r1")
	eq(director.state, State.ORDER_SHOWN, "stray dismissed signal ignored")
	director.run(BARK)
	ov.show_text("SOMETHING ELSE.")  # replaces our order
	_dismiss()
	eq(director.state, State.ORDER_SHOWN, "dismissal of the replacing line ignored")
	director.run(BARK)
	_dismiss()
	eq(director.state, State.WAITING, "matching dismissal starts rung 1")
	eq(_count("hint:PRESS [B] TO BARK"), 1, "hint appears once WAITING")


func test_dismissal_b_is_not_a_bark_and_later_bark_completes() -> void:
	var p := _player()
	director.bind_source(p, &"barked")
	var barks := [0]
	p.barked.connect(func() -> void: barks[0] += 1)
	director.run(BARK)
	_tap(KEY_B)  # inside the 0.35 s lock
	_step(0.4)
	_tap(KEY_B)  # dismisses
	eq(director.state, State.WAITING, "B dismissed the order")
	eq(barks[0], 0, "dismissal B never reached the player")
	eq(_count("succeeded"), 0, "no completion from the dismissal B")
	_step(5.0)
	_key(KEY_B, true, true)  # echo
	eq(barks[0], 0, "echo is not a bark")
	_key(KEY_B, false)
	var remaining := director.get_remaining()
	_tap(KEY_B)
	eq(barks[0], 1, "later fresh B is a bark")
	eq(director.state, State.SUCCESS, "bark completes immediately")
	check(not director.is_timer_running(), "timer stopped")
	_step(30.0)
	eq(director.state, State.SUCCESS, "no expiry after success")
	near(director.get_remaining(), remaining, 0.0001, "remaining frozen at completion")
	director.notify(&"barked")  # duplicate completion while praising
	eq(_count("succeeded"), 1, "duplicate completion ignored")
	check(events.has("hint:"), "hint hidden on success")
	eq(ov.get_displayed_text(), "DOG.", "GOOD. DOG. per word")
	_tap(KEY_K)
	eq(_count("completed:bark"), 1, "command_completed after praise dismissal")
	eq(_count("transform:1"), 1, "transform step 1 requested")
	eq(director.state, State.IDLE, "idle after praise")


func test_off_order_bark_quiet_without_penalty() -> void:
	var grab: Command = BARK.duplicate()
	grab.id = &"grab"
	grab.completion_signal = &"grabbed"
	var stick := Probe.new()
	stick.completion_signal = &"grabbed"
	add_child(stick)
	nodes.append(stick)
	director.bind_interactable(stick)
	director.run(grab)
	_dismiss()
	_step(7.0)
	near(director.get_remaining(), 13.0, 0.06, "13 s left")
	director.notify(&"barked")
	eq(_count("quiet"), 1, "QUIET issued")
	eq(ov.get_current_line(), QUIET, "FLASH QUIET. shown")
	check(not get_tree().paused and is_equal_approx(Engine.time_scale, 1.0), "QUIET does not stop the world")
	eq(director.state, State.WAITING, "still waiting")
	eq(director.rung, 0, "no rung penalty")
	near(director.get_remaining(), 13.0, 0.06, "no time penalty or reset")
	_step(12.9)
	eq(director.rung, 0, "rung 1 runs its normal 20 s")
	_step(0.15)
	eq(director.rung, 1, "escalates exactly at 20 s")
	_dismiss()
	check(stick.complete(), "interactable completes once")
	check(not stick.complete(), "second complete() refused")
	eq(_count("succeeded:grab"), 1, "grabbed completion through Interactable contract")
	stick.reset()
	director.stop()
	stick.complete()
	eq(_count("succeeded"), 1, "stop() disconnected the interactable")


func test_new_command_resets_ladder() -> void:
	var p := _player()
	director.bind_source(p, &"barked")
	director.run(BARK)
	_dismiss()
	_step(20.1)
	_dismiss()
	_step(10.1)
	_dismiss()
	eq(director.rung, 2, "at rung 3")
	p.barked.emit()
	_dismiss()
	eq(_count("completed:bark"), 1, "completed at rung 3")
	director.run(BARK)
	eq(director.rung, 0, "new command restarts at rung 1")
	var pressures := events.filter(func(e: String) -> bool: return e.begins_with("pressure:"))
	eq(pressures.back(), "pressure:0", "pressure back to 0")
	_dismiss()
	near(director.get_remaining(), 20.0, 0.0001, "full 20 s again")


func test_esc_pause_and_time_scale_keep_real_time() -> void:
	GameState.state = &"playing"
	director.run(BARK)
	check(not GameState.request_pause(), "pause refused while the overlay owns the world")
	_dismiss()
	_step(0.3)  # thaw
	_step(4.0)
	near(director.get_remaining(), 15.7, 0.06, "4.3 s elapsed")
	_tap(KEY_ESCAPE)
	check(GameState.paused and get_tree().paused, "Esc pauses")
	check(not director.is_timer_running(), "timer stopped while paused")
	_step(60.0)
	near(director.get_remaining(), 15.7, 0.06, "no time lost while paused")
	_tap(KEY_ESCAPE)
	check(not GameState.paused and not get_tree().paused, "Esc again = OBEY")
	_step(1.0)
	near(director.get_remaining(), 14.7, 0.06, "timer resumes")
	GameState.request_pause()
	GameState.resume()
	check(not get_tree().paused, "OBEY resumes")
	Engine.time_scale = 0.05
	_step(2.0)
	near(director.get_remaining(), 12.7, 0.06, "real time at time_scale 0.05")
	Engine.time_scale = 1.0


# --- Player / transform / pressure --------------------------------------------

func test_transform_blend_real_time_irreversible_and_paused() -> void:
	var p := _player()
	var tc := TransformController.new()
	for path in STEP_PATHS:
		tc.steps.append(load(path))
	tc.player = p
	add_child(tc)
	nodes.append(tc)
	near(p.eye_height_m, 1.70, 0.0001, "reset to step 0 eye height")
	near(p.camera.fov, 75.0, 0.0001, "step 0 fov")
	eq(p.sprint_enabled, false, "sprint disabled")
	near(p.jump_velocity, 0.0, 0.0001, "jump disabled")
	check(InputMap.action_get_events(&"jump").is_empty() and InputMap.action_get_events(&"sprint").is_empty(),
			"jump/sprint have no keys")
	p.head.rotation.x = deg_to_rad(85.0)
	tc.apply_step_index(1)
	eq(tc.current_step, 1, "step 1 started")
	for i in 25:
		GameState.clock.advance(0.05)
		tc.tick()
	check(p.eye_height_m < 1.70 and p.eye_height_m > 1.40, "mid-blend eye height (%.3f)" % p.eye_height_m)
	near(p.eye_height_m, 1.55, 0.03, "ease-in-out midpoint at 1.25 s")
	get_tree().paused = true
	var frozen := p.eye_height_m
	GameState.clock.advance(5.0)
	tc.tick()
	near(p.eye_height_m, frozen, 0.0001, "blend frozen by pause")
	get_tree().paused = false
	Engine.time_scale = 0.05
	for i in 26:
		GameState.clock.advance(0.05)
		tc.tick()
	Engine.time_scale = 1.0
	check(not tc.blending, "blend finished after 2.5 real seconds")
	near(p.eye_height_m, 1.40, 0.0001, "step 1 eye height")
	near(p.walk_speed, 3.6, 0.0001, "step 1 speed")
	near(p.camera.fov, 78.0, 0.0001, "step 1 fov")
	near(p.max_look_up_deg, 70.0, 0.0001, "step 1 look-up limit")
	check(p.head.rotation.x <= deg_to_rad(70.0) + 0.0001, "head pitch clamped to the new limit")
	near(p.head.position.y, 1.40, 0.0001, "camera head at eye height")
	near((p.get_node(^"CollisionShape3D").shape as CapsuleShape3D).height, 1.50, 0.0001, "capsule shrinks with eyes")
	tc.apply_step_index(0)
	eq(tc.current_step, 1, "irreversible: no step back")
	for i in [2, 3, 4]:
		tc.apply_step_index(i)
		for k in 60:
			GameState.clock.advance(0.05)
			tc.tick()
		var s: TransformStep = tc.steps[i]
		for pair in [[p.eye_height_m, s.eye_height_m], [p.walk_speed, s.speed_mps], [p.camera.fov, s.fov_deg],
				[p.max_look_up_deg, s.max_look_up_deg]]:
			check(absf(pair[0] - pair[1]) <= absf(pair[1]) * 0.05, "step %d within ±5%% (%s vs %s)" % [i, pair[0], pair[1]])
	tc.reset()
	near(p.eye_height_m, 1.70, 0.0001, "reset restores step 0 for a fresh run")


func test_pressure_reads_overlay_accessibility_flags() -> void:
	var p := _player()
	var pc := PressureController.new()
	pc.shake_target = p
	add_child(pc)
	nodes.append(pc)
	pc.set_pressure_level(5)
	near(p._trauma, 0.35, 0.001, "trauma reaches the camera")
	ov.reduce_shake = true
	ov.reduce_flashes = true
	pc.set_pressure_level(5)
	near(p._trauma, 0.35 * ov.REDUCED_SHAKE_FACTOR, 0.001, "reduce_shake scales trauma to 30%")
	near(pc.values.aberration, 0.0, 0.0, "reduce_flashes removes aberration")
	pc.nudge()
	eq(pc.level, 5, "leash nudge does not change the ladder level")
	check(pc.micro > 0.0, "micro-step pressure")
	pc.reset()
	eq(pc.level, 0, "reset to level 0")


func test_leash_contract() -> void:
	var leash := LeashConstraint.new()
	add_child(leash)
	nodes.append(leash)
	var pulls := [0]
	leash.leash_pulled.connect(func(_d: Vector3) -> void: pulls[0] += 1)
	eq(leash.constrain_velocity(Vector3(5, 0, 0), Vector3(3, 0, 0)), Vector3(3, 0, 0), "inactive: untouched")
	leash.activate(Vector3.ZERO, Vector3(10, 0, 0))
	near(leash.max_d, 10.0, 0.0001, "starts at entry distance")
	eq(leash.constrain_velocity(Vector3(10, 0, 0), Vector3(3, -1, 2)), Vector3(0, -1, 2), "outward removed, tangential/vertical kept")
	eq(pulls[0], 1, "leash_pulled on outward attempt")
	eq(leash.constrain_velocity(Vector3(10, 0, 0), Vector3(-3, 0, 0)), Vector3(-3, 0, 0), "inward kept")
	eq(leash.constrain_velocity(Vector3(0, 1, 0), Vector3(3, 0, 0)), Vector3(3, 0, 0), "zero-vector guard at centre")
	eq(pulls[0], 1, "no pull for inward/centre")
	leash.clamp_position(Vector3(8, 0, 0))
	near(leash.max_d, 8.0, 0.0001, "ratchet")
	var back := leash.clamp_position(Vector3(0, 0.5, 9))
	near(Vector2(back.x, back.z).length(), 8.0, 0.0001, "clamped back onto the ratchet circle")
	near(back.y, 0.5, 0.0001, "height untouched")
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var pos := leash.clamp_position(Vector3(6, 0, 0))  # continuous walk starts here
	var worst := 0.0
	for i in 5000:
		var v := Vector3(rng.randf_range(-6, 6), 0, rng.randf_range(-6, 6))
		var before := Vector2(pos.x, pos.z).length()
		pos = leash.clamp_position(pos + leash.constrain_velocity(pos, v) * (1.0 / 60.0) + Vector3(rng.randf_range(-0.05, 0.05), 0, rng.randf_range(-0.05, 0.05)))
		worst = maxf(worst, Vector2(pos.x, pos.z).length() - before)
	check(worst <= 0.00001, "distance never grows under random input + push noise (worst %.6f)" % worst)
	check(not leash.contract_on_rung, "contraction flag off by default")
	var d := leash.max_d
	leash.on_rung(1)
	near(leash.max_d, d, 0.0, "no contraction when off")
	leash.contract_on_rung = true
	leash.on_rung(2)
	near(leash.max_d, d * 0.85, 0.0001, "15% contraction when enabled")
	leash.reset()
	check(not leash.active and leash.max_d == INF, "reset")


# --- GameState lifecycle ------------------------------------------------------

func _level() -> Node:
	return get_tree().current_scene


func test_menu_restart_failure_cycles_reset_everything() -> void:
	var baseline := -1
	for cycle in 3:
		GameState.start_game()
		await get_tree().process_frame
		await get_tree().process_frame
		var level := _level()
		check(level != null and level.scene_file_path == "res://scenes/level.tscn", "cycle %d level loaded" % cycle)
		if level == null:
			return
		eq(GameState.state, &"playing", "cycle %d playing" % cycle)
		var d: CommandDirector = level.director
		var p: GoodDogPlayer = level.player
		eq(d.state, State.IDLE, "cycle %d director fresh" % cycle)
		eq(level.transform_ctl.current_step, 0, "cycle %d transform reset" % cycle)
		near(p.eye_height_m, 1.70, 0.0001, "cycle %d eye height reset" % cycle)
		eq(level.pressure.level, 0, "cycle %d pressure reset" % cycle)
		check(not p.controls_enabled, "cycle %d no control during prologue" % cycle)
		var conns: int = ov.dismissed.get_connections().size()
		if baseline < 0:
			baseline = conns
		eq(conns, baseline, "cycle %d no leaked Overlay connections" % cycle)
		await _frames(2.9)
		eq(d.state, State.IDLE, "cycle %d still prologue at 2.9 s" % cycle)
		await _frames(0.2)
		eq(d.state, State.ORDER_SHOWN, "cycle %d BARK after 3 s prologue" % cycle)
		check(p.controls_enabled, "cycle %d control given" % cycle)
		if cycle == 1:
			# succeed first, then quit via pause RUN AWAY
			await _frames(1.0)
			_tap(KEY_K)
			await _frames(0.5)
			_tap(KEY_B)
			eq(d.state, State.SUCCESS, "cycle 1 bark accepted in the level")
			await _frames(1.0)
			_tap(KEY_K)
			await _frames(0.5)
			eq(level.transform_ctl.current_step, 1, "cycle 1 transform 1 started")
			await _frames(3.0)
			near(p.eye_height_m, 1.40, 0.0001, "cycle 1 transformed")
			check(level.bars.position.x > 1.0, "cycle 1 bars slid open")
			_tap(KEY_ESCAPE)
			check(GameState.paused, "cycle 1 paused")
			GameState.run_away()
			await get_tree().process_frame
			await get_tree().process_frame
			eq(GameState.state, &"menu", "RUN AWAY -> menu without confirmation")
			check(not get_tree().paused and not GameState.paused, "pause cleared")
			continue
		# fail through all rungs
		var lengths := BARK.ladder
		await _frames(1.0)
		_tap(KEY_K)
		for r in 6:
			await _frames(lengths[r] + 0.2, 0.5)
			if r < 4:
				await _frames(1.0)
				_tap(KEY_K)
			elif r == 4:
				await _frames(0.7)  # FLASH rung 6 auto-dismiss
		eq(d.state, State.FAIL, "cycle %d failed after the ladder" % cycle)
		eq(GameState.state, &"failed", "cycle %d GameState failed" % cycle)
		eq(ov.get_current_line(), BAD_DOG, "cycle %d BAD DOG shown" % cycle)
		await _frames(2.2)
		check(not ov.is_active(), "cycle %d BAD DOG hidden before the silence" % cycle)
		check(AudioServer.is_bus_mute(0), "cycle %d silence" % cycle)
		await _frames(3.0)
		await get_tree().process_frame
		eq(GameState.state, &"menu", "cycle %d back to menu after 3 s silence" % cycle)
		check(not AudioServer.is_bus_mute(0), "cycle %d audio restored" % cycle)
		check(not get_tree().paused and is_equal_approx(Engine.time_scale, 1.0), "cycle %d world restored" % cycle)
		check(not is_instance_valid(d) or d.is_queued_for_deletion(), "cycle %d old director released" % cycle)
		await get_tree().process_frame
		eq(_level().scene_file_path, "res://scenes/main_menu.tscn", "cycle %d menu scene" % cycle)
	ov.dismissed.emit(&"bark_r1")  # stale signal after all restarts: nothing listens any more
	eq(ov.dismissed.get_connections().size(), baseline - 1, "only menu-time connections remain")
	get_tree().unload_current_scene()
