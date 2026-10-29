extends Node
## PLACE escalation signage: one extra sign set per actual PLACE ladder line,
## driven through the production route (keyboard E/B/Esc, walking, real ladder).
## Reuses the F3 route fixture by composition so its tests are not re-run here.
const ROUTE := preload("res://tests/test_f3_route.gd")
const SIGNAGE := preload("res://scripts/place_signage.gd")
var failures: Array[String] = []
var assertions := 0
var r: Node
var ov: Node

func check(ok: bool, text: String) -> void:
	assertions += 1
	if not ok:
		failures.append(text)
		print("SIGNAGE_CHECK_FAIL ",text)

func _ready() -> void:
	r = ROUTE.new()
	r.name = "Route"
	add_child(r)

func before_each() -> void:
	failures.clear()
	assertions = 0
	r.before_each()
	ov = r.ov

func after_each() -> void:
	await r.after_each()
	# Fold the fixture's walk/dismiss checks into this suite's verdict.
	failures.append_array(r.failures)
	assertions += r.assertions

func signage() -> Node3D:
	return r.level.signage

func expect(rung: int, text: String) -> void:
	check(signage().rung == rung and signage().visible_count() == SIGNAGE.COUNTS[rung],
			"%s: rung %d shows %d signs (actual rung %d, %d visible)" % [text, rung, SIGNAGE.COUNTS[rung], signage().rung, signage().visible_count()])

func into_observation_room() -> void:
	await r.start()
	await r.grab()
	await r.walk_to(-21.8)
	if ov.is_active():
		await r.dismiss()
	check(r.level.director.command.id == &"place" and r.level.director.state == CommandDirector.State.WAITING,"PLACE order dismissed and waiting")

func test_place_staircase_pause_idempotency_and_walked_placement() -> void:
	await into_observation_room()
	var level: Node = r.level
	# First instruction: the single labelled pedestal target only.
	expect(0,"first PLACE instruction")
	check(level.get_node("PlacementLabel").visible and level.get_node("PlacementArrow").visible,"base label and arrow visible at rung 0")
	check(level.get_node("PlacementLabel").position == Vector3(0,1.8,-24.6),"base label still above pedestal mark")
	# Out of range: inside the room, outside the place area and disk.
	r.key(KEY_E)
	check(not level.place_zone.done and level.place_zone.carrying,"E at z -21.8 rejected, still carrying")
	expect(0,"rejected E does not escalate")
	# Stray QUIET inside PLACE: no pressure, no signs.
	r.key(KEY_B)
	expect(0,"QUIET during PLACE")
	check(level.director.rung == 0,"QUIET did not advance ladder")
	await r.frames(level.director.get_remaining()+0.05)
	check(level.director.rung == 1,"actual PLACE rung 2 message")
	expect(1,"second PLACE message")
	# Staggered pop-in is mid-flight right now; the same tree pause GameState
	# uses must freeze it. (request_pause() is refused while the modal is up.)
	var newest: Node3D = signage()._panels[SIGNAGE.COUNTS[1]-1]
	var before: Vector3 = newest.scale
	check(before.x < SIGNAGE.SIGNS[SIGNAGE.COUNTS[1]-1].s,"newest sign still popping in")
	get_tree().paused = true
	await r.frames(0.5)
	check(newest.scale == before,"paused tree freezes pop-in")
	get_tree().paused = false
	await r.dismiss()
	check(newest.scale.is_equal_approx(Vector3.ONE*SIGNAGE.SIGNS[SIGNAGE.COUNTS[1]-1].s),"pop-in settles to authored scale")
	# Real Esc pause during WAITING (after the overlay thaw): ladder frozen, no further reveals.
	await r.frames(0.8)
	r.key(KEY_ESCAPE)
	check(GameState.paused,"Esc pause during PLACE rung 2")
	var remaining: float = level.director.get_remaining()
	await r.frames(remaining+3.0)
	check(level.director.rung == 1 and is_equal_approx(level.director.get_remaining(),remaining),"pause froze ladder")
	expect(1,"pause does not advance reveals")
	GameState.resume()
	await r.frames(level.director.get_remaining()+0.05)
	expect(2,"third PLACE message")
	# Duplicate and stale emissions of the production signal are idempotent.
	for stale in [2,1,0]:
		level.director.pressure_changed.emit(stale)
		expect(2,"re-emitted pressure %d" % stale)
	await r.dismiss()
	# Walked approach outside the 0.6 m pedestal footprint, fresh E.
	await r.walk_to(-23.8)
	var offset: Vector3 = level.player.global_position - level.place_zone.visual.global_position
	check(Vector2(offset.x,offset.z).length() > 0.3+0.25,"player origin outside pedestal footprint")
	r.key(KEY_E)
	check(level.place_zone.done and level.place_zone.visual.visible,"walked fresh E placed stick on pedestal")
	expect(2,"praise pressure 0 neither resets nor escalates")
	await r.dismiss()
	check(not level.mouth.visible and not level.place_zone.carrying,"placement consumed carry")
	await r.strafe_to(0.6)
	check(level.player.position.x < 1.0,"stopped inside exit doorway width")
	await r.walk_to(-31.1)
	if ov.is_active():
		await r.dismiss()
	check(level.director.command.id == &"jump","JUMP started after walking around pedestal")
	check(signage().rung == -1 and signage().visible_count() == 0,"next command resets signage")
	print("SIGNAGE_STAIRCASE_COMPLETE assertions=",assertions)

func test_full_place_ladder_failure_reset_and_new_run() -> void:
	await into_observation_room()
	expect(0,"rung 0")
	# Same production ladder walk as the F3 failure test, checked per message.
	for rung in 6:
		await r.frames(r.level.director.get_remaining()+0.05)
		if rung < 5:
			check(r.level.director.rung == rung+1,"PLACE ladder at rung %d" % (rung+1))
			expect(rung+1,"PLACE message %d" % (rung+2))
		if rung < 4:
			await r.dismiss()
		elif rung == 4:
			await r.frames(0.65)
	check(GameState.state == &"failed","PLACE ladder failed")
	check(signage().rung == -1 and signage().visible_count() == 0,"failure clears signage")
	var old_id: int = r.level.get_instance_id()
	await r.frames(5.2)
	check(GameState.state == &"menu" and not is_instance_id_valid(old_id),"failure returned to menu")
	await r.start()
	check(r.level.get_instance_id() != old_id,"new run is a new level")
	check(signage().rung == -1 and signage().visible_count() == 0,"new run starts without signage")
	print("SIGNAGE_FAILURE_RESET_COMPLETE assertions=",assertions)

func test_non_place_commands_never_reveal() -> void:
	await r.start()
	await r.walk_to(-4.3)
	if ov.is_active():
		await r.dismiss()
	var level: Node = r.level
	check(level.director.command.id == &"grab","GRAB ladder")
	r.key(KEY_B)
	await r.frames(level.director.get_remaining()+0.05)
	check(level.director.command.id == &"grab" and level.director.rung == 1,"GRAB escalated")
	check(signage().rung == -1 and signage().visible_count() == 0,"GRAB escalation + QUIET show no signs")
	await r.dismiss()
	await r.grab()
	if ov.is_active():
		await r.dismiss()
	expect(0,"PLACE rung 0")
	# Placing on the first instruction never escalates.
	await r.place()
	expect(0,"placed during first instruction")
	await r.walk_to(-31.1)
	if ov.is_active():
		await r.dismiss()
	await r.frames(level.director.get_remaining()+0.05)
	check(level.director.command.id == &"jump" and level.director.rung == 1,"JUMP escalated")
	check(signage().rung == -1 and signage().visible_count() == 0,"JUMP escalation shows no signs")
	print("SIGNAGE_ISOLATION_COMPLETE assertions=",assertions)

func test_layout_clear_of_lane_label_window_exit_and_aimed() -> void:
	await r.start()
	var s := signage()
	check(s.find_children("*","CollisionObject3D",true,false).is_empty(),"signage has no collision")
	check(SIGNAGE.COUNTS[-1] == SIGNAGE.SIGNS.size() and SIGNAGE.SIGNS.size() <= 20,"bounded deterministic count")
	for i in range(1,SIGNAGE.COUNTS.size()):
		check(SIGNAGE.COUNTS[i] > SIGNAGE.COUNTS[i-1],"strictly more signs at rung %d" % i)
	# Layout fixture: reveal everything and let pop-in settle.
	s.reveal(5)
	s.advance(2.0)
	var room := AABB(Vector3(-4.02,-0.01,-28.62),Vector3(8.04,3.03,8.04))
	var lane := AABB(Vector3(-1.3,0.05,-28.6),Vector3(2.6,2.0,8.0))
	var exit := AABB(Vector3(-1.25,0,-28.8),Vector3(2.5,3,0.6))
	var window := AABB(Vector3(3.8,0.3,-27.7),Vector3(0.3,2.4,6.2))
	var cctv := AABB(Vector3(2.45,2.4,-22.45),Vector3(0.7,0.6,0.7))
	var sight := [[Vector3(0,1.5,-21.0),Vector3(0,1.8,-24.6)],[Vector3(0,1.0,-21.0),Vector3(0,0.45,-24.6)],
			[Vector3(0,1.5,-23.8),Vector3(0,1.5,-28.6)],[Vector3(0.75,1.0,-21.0),Vector3(0,0.45,-24.6)]]
	for i in s.signs.size():
		var node: Node3D = s.signs[i]
		var box := AABB()
		var first := true
		for v in node.find_children("*","VisualInstance3D",true,false):
			var b: AABB = v.global_transform * v.get_aabb()
			box = b if first else box.merge(b)
			first = false
		var flat: bool = SIGNAGE.SIGNS[i].kind == &"floor"
		check(room.encloses(box),"sign %d inside room %s" % [i,box])
		check(not box.intersects(exit) and not box.intersects(window) and not box.intersects(cctv),"sign %d clear of exit/window/CCTV" % i)
		if flat:
			check(box.size.y < 0.05,"floor sign %d is flat paint" % i)
			var nearest := Vector2(clampf(0,box.position.x,box.end.x),clampf(-24.6,box.position.z,box.end.z))
			check(nearest.distance_to(Vector2(0,-24.6)) > 1.3,"floor sign %d outside placement ring" % i)
		else:
			check(not box.intersects(lane),"sign %d out of walking/reach lane %s" % [i,box])
		for seg in sight:
			check(box.intersects_segment(seg[0],seg[1]) == null,"sign %d does not block sightline %s" % [i,seg])
		var arrow: Node3D = node.get_node("Panel/Arrow")
		var normal: Vector3 = arrow.global_basis.z.normalized()
		var want: Vector3 = SIGNAGE.TARGET - arrow.global_position
		want = (want - normal*want.dot(normal)).normalized()
		check(arrow.global_basis.x.normalized().dot(want) > 0.999,"sign %d arrow aims at pedestal" % i)
		if SIGNAGE.SIGNS[i].kind == &"hung":
			# Rod hangs from the board's top edge behind the face, never across the print.
			var rod: MeshInstance3D = node.get_node("Rod")
			var panel: Node3D = node.get_node("Panel")
			var to_panel: Transform3D = panel.global_transform.affine_inverse()
			var foot: Vector3 = to_panel * (rod.global_position - Vector3(0,(rod.mesh as BoxMesh).size.y/2,0))
			var climb: Vector3 = to_panel.basis * Vector3.UP
			check(foot.y >= 0.37 and foot.z < 0.0 and absf(foot.x) < 0.05 and climb.y > 0.0,"sign %d rod anchored at top edge behind board (local foot %s)" % [i,foot])
			check(is_equal_approx(rod.global_position.y + (rod.mesh as BoxMesh).size.y/2, SIGNAGE.CEILING_Y),"sign %d rod reaches ceiling" % i)
	print("SIGNAGE_LAYOUT_COMPLETE assertions=",assertions)

## Same camera poses as tools/capture/place_signage_stills.gd (entrance, corner, approach).
const POSES := {
	entrance = [Vector3(0,1.55,-21.0),Vector3(0,1.0,-24.9)],
	corner = [Vector3(3.3,2.3,-21.1),Vector3(-1.2,1.1,-25.6)],
	approach = [Vector3(1.1,1.45,-22.7),Vector3(0,0.45,-24.6)],
}

## Normalised (0..1) on-screen bounds of every visual under node for a camera at
## view, from a 5x5x5 lattice over each local AABB (corners included). Projects
## like the 1280x720 stills (75 deg vertical FOV, 16:9) because the headless test
## viewport is a 64x64 stub. Points behind the camera or off-screen are skipped,
## so a node outside the frame returns an empty rect at -1.
func screen_box(view: Transform3D, node: Node) -> Rect2:
	var proj := Projection.create_perspective(75.0,16.0/9.0,0.05,100.0)
	var to_view := view.affine_inverse()
	var parts: Array = node.find_children("*","VisualInstance3D",true,false)
	if node is VisualInstance3D:
		parts.append(node)
	var rect := Rect2(-1,-1,0,0)
	var first := true
	for v: VisualInstance3D in parts:
		var box: AABB = v.get_aabb()
		for k in 125:
			var c: Vector3 = to_view * v.global_transform * (box.position + box.size * Vector3(k % 5,k / 5 % 5,k / 25) / 4.0)
			if c.z > -0.05:
				continue
			var h: Vector4 = proj * Vector4(c.x,c.y,c.z,1.0)
			var q := Vector2(0.5 + 0.5*h.x/h.w,0.5 - 0.5*h.y/h.w)
			if q.x < 0.0 or q.y < 0.0 or q.x > 1.0 or q.y > 1.0:
				continue
			rect = Rect2(q,Vector2.ZERO) if first else rect.expand(q)
			first = false
	return rect

func test_central_cues_clear_from_entrance_corner_and_approach() -> void:
	await r.start()
	var level: Node = r.level
	var s := signage()
	s.reveal(5)
	s.advance(2.0)
	# Stand-in visuals for the regions that must read clearly (placed stick on pedestal, exit doorway).
	var pedestal := MeshInstance3D.new()
	pedestal.mesh = BoxMesh.new()
	(pedestal.mesh as BoxMesh).size = Vector3(1.05,0.6,0.6)
	pedestal.position = Vector3(0,0.3,-24.6)
	var doorway := MeshInstance3D.new()
	doorway.mesh = BoxMesh.new()
	(doorway.mesh as BoxMesh).size = Vector3(2.5,3.0,0.2)
	doorway.position = Vector3(0,1.5,-28.6)
	for n: Node3D in [pedestal,doorway]:
		n.visible = false
		level.add_child(n)
	var cues := {label = [level.get_node("PlacementLabel"),level.get_node("PlacementArrow")], pedestal = [pedestal], exit = [doorway]}
	for pose: StringName in POSES:
		var view := Transform3D(Basis(),POSES[pose][0]).looking_at(POSES[pose][1],Vector3.UP)
		for cue: String in cues:
			var area := Rect2()
			for c: Node in cues[cue]:
				var b := screen_box(view,c)
				area = b if area.size == Vector2.ZERO else area.merge(b)
			check(area.size.x > 0.02 and area.size.y > 0.02,"%s: %s on screen %s" % [pose,cue,area])
			area = area.grow(0.01)
			for i in s.signs.size():
				var sb := screen_box(view,s.signs[i])
				check(not sb.intersects(area),"%s: sign %d %s clear of %s %s" % [pose,i,sb,cue,area])
	for n: Node in [pedestal,doorway]:
		n.queue_free()
	print("SIGNAGE_SCREEN_CLEARANCE_COMPLETE assertions=",assertions)

func test_pop_in_reduced_shake_and_zero_dt() -> void:
	var s: Node3D = SIGNAGE.new()
	add_child(s)
	var full: float = SIGNAGE.SIGNS[0].s
	for calm in [false,true]:
		ov.reduce_shake = calm
		s.reset()
		s.reveal(1)
		var start: Vector3 = s._panels[0].scale
		s.advance(0.0)
		check(s._panels[0].scale == start,"zero dt does not advance pop-in")
		var peak := 0.0
		for i in 40:
			s.advance(1.0/60)
			peak = maxf(peak,s._panels[0].scale.x)
		check(is_equal_approx(s._panels[0].scale.x,full),"settles to authored scale calm=%s" % calm)
		if calm:
			check(peak <= full+0.0001,"reduced shake: no overshoot")
		else:
			check(peak > full*1.05,"default cartoon overshoot")
	ov.reduce_shake = false
	s.queue_free()
	await get_tree().process_frame
