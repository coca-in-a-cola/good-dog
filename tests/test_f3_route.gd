extends Node
## Production route driven by keyboard, mouse and movement, no teleport/notify.
var failures: Array[String] = []
var assertions := 0
var ov: Node
var level: Node
var old_id := 0

func check(ok: bool, text: String) -> void:
	assertions += 1
	if not ok:
		failures.append(text)
		print("F3_CHECK_FAIL ",text)

func before_each() -> void:
	failures.clear()
	assertions = 0
	ov = get_node("/root/Overlay")
	ov.force_hide()
	ov.use_manual_clock = true
	GameState.clock.manual = true
	get_tree().paused = false
	Engine.time_scale = 1

func after_each() -> void:
	ov.force_hide()
	GameState.quit_to_menu()
	await frames(0.1)
	get_tree().unload_current_scene()
	await get_tree().process_frame
	ov.use_manual_clock = false
	GameState.clock.manual = false
	for action in InputMap.get_actions():
		Input.action_release(action)

func key(code: Key) -> void:
	for pressed in [true,false]:
		var e := InputEventKey.new()
		e.keycode = code
		e.physical_keycode = code
		e.pressed = pressed
		Input.parse_input_event(e)
	Input.flush_buffered_events()

func frames(seconds: float) -> void:
	for i in ceili(seconds*60):
		GameState.clock.advance(1.0/60)
		ov.advance_clock(1.0/60)
		await get_tree().physics_frame

func dismiss(code := KEY_K) -> void:
	await frames(2.0)
	key(code)
	await frames(0.3)

func start() -> void:
	GameState.quit_to_menu()
	await frames(0.1)
	get_tree().current_scene.start_button.pressed.emit()
	await frames(0.1)
	level = get_tree().current_scene
	await frames(3.1)
	await dismiss()
	key(KEY_B)
	await dismiss()
	await frames(2.6)

func walk_to(z: float, action := &"move_forward", limit := 900) -> void:
	Input.action_press(action)
	for i in limit:
		if level.player.position.z <= z:
			break
		if ov.is_active():
			Input.action_release(action)
			await dismiss()
			Input.action_press(action)
		await frames(1.0/60)
	Input.action_release(action)
	check(level.player.position.z <= z,"walk reached %.2f actual %s" % [z,level.player.position])

func look_pitch(pitch: float) -> void:
	# GRAB praise schedules PLACE on the following frame. That modal consumes
	# motion too: dismiss it BEFORE submitting the camera-reset input.
	if ov.is_active():
		await dismiss()
	var p: GoodDogPlayer = level.player
	var e := InputEventMouseMotion.new()
	e.relative = Vector2(0,(p.head.rotation.x-pitch)/p.vertical_mouse_sensitivity)
	Input.parse_input_event(e)
	Input.flush_buffered_events()
	await frames(0.05)
	print("F3_LOOK mode=", Input.mouse_mode," target=",pitch," actual=",p.head.rotation.x)
	check(is_equal_approx(p.head.rotation.x,pitch),"fresh mouse pitch applied after modal dismissal")

func grab() -> void:
	await walk_to(-7.7)
	await look_pitch(-0.78)
	key(KEY_E)
	check(level.stick.done,"raycast fresh E grabbed bloody stick")
	await dismiss()
	await look_pitch(0)

func place() -> void:
	await walk_to(-24.2)
	key(KEY_E)
	check(level.place_zone.done,"fresh E in circle placed stick")
	await dismiss()

func test_full_input_route_finale_credits_and_replay() -> void:
	await start()
	check(level.transform_ctl.current_step == 1,"BARK step1")
	await walk_to(-4.3)
	check(level.cell_closed,"gate closes behind")
	# Dismissal E cannot grab, and a look-away miss cannot grab.
	await walk_to(-7.7)
	key(KEY_E)
	check(not level.stick.done,"look-away ray miss")
	await look_pitch(-0.78)
	key(KEY_E)
	check(level.stick.done,"actual ray picked up stick")
	await dismiss()
	check(level.mouth.visible,"mouth carry visible")
	check(level.transform_ctl.current_step == 2,"GRAB step2 not stale step1")
	key(KEY_E)
	check(not level.place_zone.done,"outside zone cannot place")
	await look_pitch(0)
	await place()
	check(not level.mouth.visible,"carry removed on placement")
	check(level.transform_ctl.current_step == 3,"PLACE step3")
	await walk_to(-31.1)
	check(level.transform_ctl.current_step == 4,"step4 on hall entry, before JUMP")
	check(level.leash_ctl.active,"hall leash active")
	await walk_to(-40.0)
	for i in 360:
		if GameState.state == &"falling":
			break
		await frames(1.0/60)
	check(GameState.state == &"falling","actual uncapped hole triggered falling")
	check(not level.player.controls_enabled,"fall controls locked")
	check(not level.director.is_timer_running(),"pit timer stopped without praise")
	old_id = level.get_instance_id()
	await frames(3.8)
	check(GameState.state == &"falling","four second fall not shortened")
	await frames(0.4)
	check(GameState.state == &"finale","actual finale scene")
	check(not is_instance_id_valid(old_id),"old level freed")
	await frames(2.2)
	check(get_tree().current_scene.label.text == "YOU WERE A GOOD DOG!","finale exact second text")
	key(KEY_K)
	check(get_tree().current_scene.stage == 2,"key enters credits")
	await frames(2.2)
	key(KEY_K)
	await frames(0.1)
	check(GameState.state == &"menu","credits key returns menu")
	await start()
	check(level.get_instance_id() != old_id,"new scene identity on replay")
	check(not level.stick.done and not level.place_zone.done and not level.mouth.visible,"items reset")
	check(not level.leash_ctl.active,"leash reset")
	print("F3_FULL_ROUTE_COMPLETE assertions=",assertions)

func test_later_command_ladders_quiet_pause_and_restart() -> void:
	for command in ["grab","place","jump"]:
		await start()
		await grab()
		if command == "jump":
			await place()
			await walk_to(-31.1)
		elif command == "grab":
			# Separate fresh run to fail GRAB instead of PLACE.
			GameState.quit_to_menu()
			await start()
			await walk_to(-4.3)
		if ov.is_active():
			await dismiss()
		check(level.director.command.id == StringName(command),"expected later command "+command)
		var remaining: float = level.director.get_remaining()
		key(KEY_B)
		check(level.director.rung == 0 and level.director.get_remaining() == remaining,"QUIET no timer penalty "+command)
		await frames(0.8)
		check(GameState.request_pause(),"pause later command "+command)
		remaining = level.director.get_remaining()
		await frames(2)
		check(is_equal_approx(level.director.get_remaining(),remaining),"pause freezes timer")
		GameState.resume()
		for rung in 6:
			await frames(level.director.get_remaining()+0.05)
			if rung < 4:
				await dismiss()
			elif rung == 4:
				await frames(0.65)
		check(GameState.state == &"failed","last 1s failure "+command)
		old_id = level.get_instance_id()
		await frames(5.2)
		check(GameState.state == &"menu" and not is_instance_id_valid(old_id),"failure frees exact scene "+command)
	print("F3_LATER_LADDERS_COMPLETE")

func test_actual_sixty_second_character_wallslide_leash() -> void:
	await start()
	ov.force_hide()
	level.director.stop()
	var p: GoodDogPlayer = level.player
	# Fixture placement only: this is not the full-route acceptance driver.
	p.position = Vector3(0.75,0,-6)
	var center := Vector3(0,0,-12)
	level.leash_ctl.activate(center,p.global_position)
	var rng := RandomNumberGenerator.new()
	rng.seed = 6147
	var worst := 0.0
	var collisions := 0
	var previous := Vector2(p.position.x-center.x,p.position.z-center.z).length()
	for tick in 3600:
		for action in [&"move_left",&"move_right",&"move_forward",&"move_backward"]:
			Input.action_release(action)
		# First 120 ticks slide against the corridor wall; then seeded random.
		Input.action_press(&"move_right" if tick<120 else [&"move_left",&"move_right",&"move_forward",&"move_backward"][rng.randi_range(0,3)])
		await get_tree().physics_frame
		var distance := Vector2(p.position.x-center.x,p.position.z-center.z).length()
		worst = maxf(worst,distance-previous)
		previous = distance
		collisions += p.get_slide_collision_count()
	for action in InputMap.get_actions():
		Input.action_release(action)
	check(worst <= 0.00001,"actual physics radius never grows")
	check(collisions>0,"real wall contacts occurred")
	print("F3_PHYSICS seconds=60 ticks=3600 seed=6147 max_growth=",worst," tolerance=0.00001 contacts=",collisions)

func test_place_circle_player_origin_boundary() -> void:
	await start()
	await grab()
	if ov.is_active():
		await dismiss()
	var mark: Vector3 = level.place_zone.visual.global_position
	# Explicit fixture positions; fresh E still reaches the production consumer.
	for offset in [Vector3(1.2,0,1.2), Vector3(1.2501,0,0)]:
		level.player.position = Vector3(mark.x+offset.x,0,mark.z+offset.z)
		await frames(0.1)
		check(level.place_zone.area.overlaps_body(level.player),"rejection is inside broad-phase overlap")
		var remaining: float = level.director.get_remaining()
		key(KEY_E)
		check(not level.place_zone.done and not level.place_zone.visual.visible,"outside disk rejects fresh E")
		check(level.place_zone.carrying and level.mouth.visible,"rejection preserves carried item")
		check(level.director.is_timer_running() and level.director.get_remaining() == remaining,"rejection does not consume or stop timer")
	level.player.position = Vector3(mark.x+1.25,0,mark.z)
	await frames(0.1)
	key(KEY_E)
	check(level.place_zone.done and level.place_zone.visual.visible,"exact disk boundary allows placement")
	check(level.place_zone.visual.global_position == mark,"placed visual remains at mark center")
	await dismiss()
	check(not level.mouth.visible and not level.place_zone.carrying,"successful placement consumes carry")
	print("F3_EDGE_PLACE_COMPLETE assertions=",assertions)

func test_leash_exact_center_and_tiny_positive_ratchet() -> void:
	var leash := LeashConstraint.new()
	add_child(leash)
	leash.activate(Vector3.ZERO,Vector3.ZERO)
	check(leash.clamp_position(Vector3(0,2,0)) == Vector3(0,2,0),"exact zero safe and vertical preserved")
	check(leash.clamp_position(Vector3(0.00005,2,0)) == Vector3(0,2,0),"tiny positive cannot escape zero ratchet")
	leash.activate(Vector3.ZERO,Vector3(0.00002,0,0))
	var tiny := leash.clamp_position(Vector3(0.00005,3,0))
	check(absf(tiny.x-0.00002)<0.00000001 and tiny.y == 3,"tiny positive radius clamps rather than epsilon bypass")
	leash.activate(Vector3.ZERO,Vector3(2,0,0))
	check(leash.constrain_velocity(Vector3(2,0,0),Vector3(-1,2,3)) == Vector3(-1,2,3),"inward tangential vertical velocity retained")
	check(leash.constrain_velocity(Vector3(2,0,0),Vector3(1,2,3)) == Vector3(0,2,3),"outward removed tangential retained")
	check(leash.clamp_position(Vector3(1,4,0)) == Vector3(1,4,0),"inward position ratchets")
	check(leash.clamp_position(Vector3(0,4,2)) == Vector3(0,4,1),"subsequent tangential displacement cannot grow radius")
	leash.queue_free()
	await get_tree().process_frame
	print("F3_EDGE_LEASH_COMPLETE assertions=",assertions)

func blocker(at: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	level.add_child(body)
	body.global_position = at
	return body

func test_spatial_eligibility_consumed_e_and_growth_collision() -> void:
	await start()
	Input.action_press(&"move_forward")
	for tick in 180:
		if ov.is_active():
			break
		await frames(1.0/60)
	Input.action_release(&"move_forward")
	# Explicit spatial fixture, NOT full-route movement evidence: put the player
	# in actual ray range while the production GRAB order still owns input.
	level.player.position.z = -7.7
	level.player.head.rotation.x = -0.78
	await frames(0.1)
	check(ov.is_active(),"production GRAB modal owns input")
	await dismiss(KEY_E)
	check(not level.stick.done,"dismissal E consumed even with eligible ray")
	# Distance and occlusion use production physics queries and fresh E events.
	level.player.position.z = -6.0
	await frames(0.1)
	var delta: Vector3 = level.stick.target.global_position - level.player.camera.global_position
	await look_pitch(atan2(delta.y,absf(delta.z)))
	key(KEY_E)
	check(not level.stick.done and level.director.is_timer_running(),"aimed target beyond 2m rejected without stopping timer")
	level.player.position.z = -7.7
	await frames(0.1)
	delta = level.stick.target.global_position - level.player.camera.global_position
	await look_pitch(atan2(delta.y,absf(delta.z)))
	var wall := blocker(level.player.camera.global_position + delta*0.5,Vector3(0.5,0.5,0.2))
	await frames(0.1)
	key(KEY_E)
	check(not level.stick.done and level.director.is_timer_running(),"nearby aimed stick occluded by real collider")
	wall.queue_free()
	await frames(0.1)
	key(KEY_E)
	check(level.stick.done,"same ray succeeds after removing blocker")
	await dismiss()
	await look_pitch(0)
	check(not level.place_zone.done,"no automatic placement after GRAB")
	# Separate low-ceiling fixture proves the growth guard, not just data values.
	ov.force_hide()
	level.director.stop()
	level.player.position = Vector3(0,0,-6)
	level.player.set_eye_height(0.45)
	var roof := blocker(Vector3(0,1.1,-6),Vector3(1.5,0.2,1.5))
	await frames(0.1)
	var old_height: float = level.player._shape.shape.height
	level.player.set_eye_height(1.7)
	check(is_equal_approx(level.player.eye_height_m,0.45) and is_equal_approx(level.player._shape.shape.height,old_height),"real low ceiling refuses capsule and eye growth")
	roof.queue_free()
	await frames(0.1)
	level.player.set_eye_height(1.7)
	check(is_equal_approx(level.player.eye_height_m,1.7),"growth succeeds after ceiling removed")

func test_later_phase_run_away_rebuilds_all_route_state() -> void:
	for phase in ["grab","place","jump"]:
		await start()
		await walk_to(-4.3)
		await dismiss()
		if phase != "grab":
			await grab()
		if phase == "jump":
			await place()
			await walk_to(-31.1)
			await dismiss()
		check(level.director.command.id == StringName(phase),"RUN AWAY phase "+phase)
		await frames(0.8)
		key(KEY_ESCAPE)
		check(GameState.paused,"fresh Escape opens later pause "+phase)
		old_id = level.get_instance_id()
		# Production button signal, not OS click acceptance.
		GameState._run_away.pressed.emit()
		await frames(0.1)
		check(GameState.state == &"menu" and not is_instance_id_valid(old_id),"RUN AWAY frees exact later scene "+phase)
		await start()
		check(not level.stick.done and not level.place_zone.done and not level.mouth.visible,"RUN AWAY rebuilds items "+phase)
		check(not level.leash_ctl.active and not level.observation_closed and not level.cell_closed,"RUN AWAY rebuilds gates and leash "+phase)
		check(level.transform_ctl.current_step == 1 and level.director.rung == -1,"RUN AWAY rebuilds transformation and director before next order "+phase)
	print("F3_RUN_AWAY_RESET_COMPLETE")
