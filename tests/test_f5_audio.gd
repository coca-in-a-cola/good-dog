extends Node
## F5 audio: bus layout/effects, overlay muffle, asset catalog/provenance and the
## production LevelAudio bindings driven through the accepted F3 route fixture.
var failures: Array[String] = []
var assertions := 0
var route: Node
var ov: Node

const BUSES := [&"Master", &"SFX", &"Ambience", &"UI", &"Music", &"Drone", &"ReverbCell", &"ReverbCorridor", &"ReverbPit"]
const SENDS := {SFX = &"Master", Ambience = &"Master", UI = &"Master", Music = &"Master", Drone = &"Ambience",
		ReverbCell = &"SFX", ReverbCorridor = &"SFX", ReverbPit = &"SFX"}
## bus → [room_size, damping]: GDD §10 cell short, corridor long, pit hall cavernous.
const REVERBS := {ReverbCell = [0.2, 0.5], ReverbCorridor = [0.6, 0.3], ReverbPit = [0.9, 0.2]}
const LOOPS := ["fluorescent_hum_loop.wav", "cctv_servo_loop.wav", "drone_loop.wav", "tinnitus_loop.wav", "panting_loop.wav"]


func check(ok: bool, text: String) -> void:
	assertions += 1
	if not ok:
		failures.append(text)
		print("F5_CHECK_FAIL ", text)


func before_each() -> void:
	failures.clear()
	assertions = 0
	ov = get_node("/root/Overlay")
	route = preload("res://tests/test_f3_route.gd").new()
	add_child(route)
	await route.before_each()


func after_each() -> void:
	failures.append_array(route.failures)
	await route.after_each()
	route.queue_free()
	AudioMix.reset()
	await get_tree().process_frame


func bus(name: StringName) -> int:
	return AudioServer.get_bus_index(name)


func effect(name: StringName, type: String) -> AudioEffect:
	var i := AudioMix.find_effect(name, type)
	return AudioServer.get_bus_effect(bus(name), i) if i >= 0 else null


func zone_bus(at: Vector3) -> StringName:
	var query := PhysicsPointQueryParameters3D.new()
	query.position = at
	query.collide_with_areas = true
	query.collide_with_bodies = false
	query.collision_mask = LevelAudio.REVERB_LAYER
	var best: Area3D
	for hit in route.level.get_world_3d().direct_space_state.intersect_point(query, 8):
		var area := hit.collider as Area3D
		if area != null and area.reverb_bus_enabled and (best == null or area.priority > best.priority):
			best = area
	return best.reverb_bus_name if best != null else &""


func test_bus_layout_limiter_filters_and_reverbs() -> void:
	for i in BUSES.size():
		check(AudioServer.get_bus_name(i) == BUSES[i], "bus %d is %s" % [i, BUSES[i]])
	for name: StringName in SENDS:
		check(AudioServer.get_bus_send(bus(name)) == SENDS[name], "%s sends to %s" % [name, SENDS[name]])
	# HardLimiter bounds sample peaks; -1.5 dB keeps the measured true peak of the
	# mix (tools/audio/mix_capture.gd, ffmpeg ebur128) at or under -1 dBTP.
	var limiter := effect(&"Master", "AudioEffectHardLimiter") as AudioEffectHardLimiter
	check(limiter != null and is_equal_approx(limiter.ceiling_db, -1.5), "Master hard limiter ceiling -1.5 dB (<= -1 dBTP)")
	check(AudioServer.get_bus_effect_count(bus(&"Master")) == 1, "Master carries only the safety limiter")
	check(AudioServer.is_bus_effect_enabled(bus(&"Master"), AudioMix.find_effect(&"Master", "AudioEffectHardLimiter")), "limiter enabled")
	for name in [&"SFX", &"Ambience"]:
		var lp := effect(name, "AudioEffectLowPassFilter") as AudioEffectLowPassFilter
		check(lp != null and is_equal_approx(lp.cutoff_hz, 800.0), "%s overlay low-pass at 800 Hz" % name)
		check(not AudioServer.is_bus_effect_enabled(bus(name), AudioMix.find_effect(name, "AudioEffectLowPassFilter")), "%s filter idle off" % name)
	check(AudioMix.find_effect(&"SFX", "AudioEffectCompressor") < AudioMix.find_effect(&"SFX", "AudioEffectLowPassFilter"),
			"SFX transient compressor ahead of the muffle")
	for name in [&"UI", &"Music"]:
		check(AudioServer.get_bus_effect_count(bus(name)) == 0, "%s has no filter (flash/score stay crisp)" % name)
	for name: StringName in REVERBS:
		var rv := effect(name, "AudioEffectReverb") as AudioEffectReverb
		check(rv != null and is_equal_approx(rv.room_size, REVERBS[name][0]) and is_equal_approx(rv.damping, REVERBS[name][1]), "%s room/damping" % name)
		check(rv != null and rv.dry == 0.0 and rv.wet == 1.0, "%s is a wet-only return" % name)
	var pit := effect(&"ReverbPit", "AudioEffectReverb") as AudioEffectReverb
	check(pit.predelay_msec >= 200.0 and pit.predelay_feedback >= 0.5, "pit hall late echo (predelay feedback)")
	check(ov.sfx_bus == &"UI", "overlay camera flash routed to UI bus")


func test_overlay_muffles_sfx_ambience_and_thaws_open() -> void:
	ov.use_manual_clock = true
	GameState.clock.manual = true
	var sfx_fx := AudioMix.find_effect(&"SFX", "AudioEffectLowPassFilter")
	var amb_fx := AudioMix.find_effect(&"Ambience", "AudioEffectLowPassFilter")
	for mode in [OverlayLine.Mode.OVER_WORLD, OverlayLine.Mode.BLACK, OverlayLine.Mode.FLASH]:
		ov.show_text("BARK.", mode)
		AudioMix.tick()
		check(AudioMix.is_muffled() and is_equal_approx(AudioMix.get_cutoff_hz(), 800.0), "line on screen muffles at 800 Hz (mode %d)" % mode)
		check(AudioServer.is_bus_effect_enabled(bus(&"SFX"), sfx_fx) and AudioServer.is_bus_effect_enabled(bus(&"Ambience"), amb_fx), "SFX and Ambience filtered")
		check(AudioServer.get_bus_effect_count(bus(&"UI")) == 0, "UI flash path never filtered")
		ov.force_hide()
		AudioMix.tick()  # the per-frame poll that observes the hide
		GameState.clock.advance(ov.unfreeze_time * 0.5)
		AudioMix.tick()
		var mid := AudioMix.get_cutoff_hz()
		check(mid > 1000.0 and mid < 20000.0 and AudioMix.is_muffled(), "cutoff opening during thaw (%.0f Hz)" % mid)
		GameState.clock.advance(ov.unfreeze_time * 0.6)
		AudioMix.tick()
		check(not AudioMix.is_muffled() and not AudioServer.is_bus_effect_enabled(bus(&"SFX"), sfx_fx), "filter released after thaw")
	# A real key dismissal: the overlay's own time_scale thaw is still running
	# (its clock is held) while the audio thaw completes on real time.
	ov.show_text("GOOD.", OverlayLine.Mode.OVER_WORLD)
	AudioMix.tick()
	ov.advance_clock(1.0)
	route.key(KEY_K)
	check(not ov.is_active(), "key dismissed the line")
	AudioMix.tick()
	GameState.clock.advance(ov.unfreeze_time + 0.01)
	AudioMix.tick()
	check(Engine.time_scale < 0.5 and not AudioMix.is_muffled(), "audio thaw is real time, not stretched by time_scale")
	ov.advance_clock(ov.unfreeze_time + 0.01)
	check(is_equal_approx(Engine.time_scale, 1.0), "overlay restored time scale")
	GameState.clock.manual = false
	ov.use_manual_clock = false


func test_catalog_files_formats_loops_and_provenance() -> void:
	var catalog: Array[String] = []
	_collect(LevelAudio.CATALOG, catalog)
	for sound: Array in preload("res://scripts/finale.gd").SOUNDS:
		catalog.append(sound[0].resource_path)
	for i in range(1, 5):
		var step: TransformStep = load("res://data/transform/step_%d.tres" % i)
		check(step.transition_sfx != null, "transform step %d has transition sound" % i)
	var files := _wavs("res://assets/audio")
	check(files.size() == 40, "40 F5 audio files (found %d)" % files.size())
	var third_party := FileAccess.get_file_as_string("res://THIRD_PARTY.md")
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/audio/PROVENANCE.json"))
	var hashes := {}
	for entry: Dictionary in manifest.files:
		hashes[entry.path] = entry.sha256
		check(entry.true_peak_dbtp <= -1.0, "%s true peak <= -1 dBTP" % entry.path)
	for path in files:
		check(path in catalog, "%s is bound by a production consumer" % path)
		check(third_party.contains(path.trim_prefix("res://")), "%s catalogued in THIRD_PARTY.md" % path)
		check(hashes.get(path, "") == FileAccess.get_sha256(path), "%s matches PROVENANCE.json SHA-256" % path)
		var info := _wav_info(path)
		check(info.channels == 1 and info.rate == 48000 and info.bits == 16, "%s mono 48 kHz 16-bit" % path)
		check(info.peak > 0.03 and info.peak < 0.9, "%s non-silent with headroom (peak %.3f)" % [path, info.peak])
		var stream := load(path) as AudioStreamWAV
		var looped: bool = path.get_file() in LOOPS
		check(stream != null and (stream.loop_mode == AudioStreamWAV.LOOP_FORWARD) == looped, "%s loop mode %s" % [path, looped])
	var barks := {}
	for s: AudioStream in LevelAudio.CATALOG.bark:
		barks[FileAccess.get_sha256(s.resource_path)] = true
	check(barks.size() == 5, "five distinct bark tiers")
	check(third_party.contains("addons/command_overlay/assets/sfx/camera_flash.wav"), "camera flash still catalogued")


func test_route_bindings_reverb_zones_and_finale() -> void:
	await route.start()
	var level: Node = route.level
	var audio: LevelAudio = level.audio
	check(audio != null and audio.get_parent() == level, "LevelAudio installed on production level")
	# Prologue + BARK beat (start() barks once and dismisses GOOD. DOG.).
	check(audio.count(&"door") == 1, "prologue door clank")
	check(audio.count(&"bark") == 1 and audio.last_stream[&"bark"] == LevelAudio.CATALOG.bark[0], "step-0 human bark")
	check(audio.count(&"praise") == 1, "GOOD DOG praise on success")
	check(audio.count(&"crunch") == 1 and audio.last_stream[&"crunch"] == LevelAudio.CATALOG.crunch, "transformation 1 sound from TransformStep")
	var lights := 0
	for node in level.get_children():
		if node is OmniLight3D or node is SpotLight3D:
			lights += 1
	check(audio.hums.size() == lights and lights >= 5, "one hum per lamp (%d)" % lights)
	for hum in audio.hums:
		check(hum.playing and hum.bus == &"Ambience" and hum.stream == LevelAudio.CATALOG.hum, "lamp hum looping on Ambience")
	check(audio.servo != null and audio.servo.get_parent().name == &"CCTVTrackingHead" and audio.servo.playing, "servo bound to CCTV head")
	check(audio.drone.playing and audio.drone.bus == &"Drone", "drone on Drone bus")
	check(zone_bus(level.player.global_position + Vector3(0, 0.05, 0)) == &"ReverbCell", "cell reverb zone at spawn")
	# Own-body sounds: no inverse-distance gain, so MIX dB is never flattened by max_db.
	for p: AudioStreamPlayer3D in [audio._bark, audio._leash, audio.panting] + audio._steps:
		check(p.attenuation_model == AudioStreamPlayer3D.ATTENUATION_DISABLED and p.volume_db < p.max_db
				and p.area_mask == LevelAudio.REVERB_LAYER and p.bus == &"SFX", "%s own-body 3D player" % p.name)
	# Footsteps follow movement and the transformation step (step 1 = bare feet).
	var steps := audio.count(&"footstep")
	await route.walk_to(-4.3)
	check(audio.count(&"footstep") > steps, "walking emits footsteps")
	check(audio.last_stream[&"footstep"] in LevelAudio.CATALOG.footsteps.barefoot, "step-1 bare feet")
	check(zone_bus(level.player.global_position + Vector3(0, 0.05, 0)) == &"ReverbCorridor", "corridor reverb zone")
	route.key(KEY_B)  # off-order bark: QUIET., but the sound still follows the body
	check(audio.count(&"bark") == 2 and audio.last_stream[&"bark"] == LevelAudio.CATALOG.bark[1], "step-1 hoarse bark")
	await route.grab()
	check(audio.count(&"stick_pickup") == 1, "wet thud on pickup")
	check(audio.count(&"praise") == 2, "same praise for GRAB")
	await route.place()
	check(audio.count(&"stick_place") == 1, "wet thud on placement")
	check(audio.count(&"applause_mirror") == 1, "muffled applause behind the mirror")
	check(zone_bus(level.player.global_position + Vector3(0, 0.05, 0)) == &"ReverbCorridor", "observation room uses corridor reverb")
	await route.walk_to(-31.1)
	if ov.is_active():
		await route.dismiss()
	check(level.transform_ctl.current_step == 4, "pit hall step 4")
	check(audio.panting.playing and is_equal_approx(audio.panting.pitch_scale, 1.25), "fast panting at step 4")
	await route.walk_to(-32.5)
	check(audio.last_stream[&"footstep"] in LevelAudio.CATALOG.footsteps.claws, "claws at step 4")
	check(zone_bus(level.player.global_position + Vector3(0, 0.05, 0)) == &"ReverbPit", "pit hall cavern reverb")
	Input.action_press(&"move_backward")
	await route.frames(0.3)
	Input.action_release(&"move_backward")
	check(audio.count(&"leash") == 1, "one chain/leather pull per tug (cooldown)")
	check(audio.count(&"praise_bell") == 0, "no bell before 6 s")
	await route.frames(6.1)
	check(audio.count(&"praise_bell") == 1, "praise bell after 6 s in the hall")
	check(audio.last_stream[&"praise_bell"] == LevelAudio.CATALOG.praise_bell, "pit lure is the praise bell")
	await route.walk_to(-40.0)
	for i in 360:
		if GameState.state == &"falling":
			break
		await route.frames(1.0 / 60)
	check(audio.falling and audio.count(&"fall_wind") == 1 and audio.fall_wind.playing, "fall wind starts on the pit trigger")
	check(audio.panting.playing, "breathing remains while the world fades")
	await route.frames(3.0)
	check(AudioServer.get_bus_volume_db(bus(&"Ambience")) < -40.0, "world sounds faded during the fall")
	await route.frames(0.75)
	check(audio.silenced and not audio.panting.playing and not audio.fall_wind.playing, "abrupt cut to silence before the finale")
	await route.frames(0.4)
	check(GameState.state == &"finale", "finale reached")
	var finale: Node = get_tree().current_scene
	check(finale.players.size() == 3, "popper, applause, jingle")
	for p: AudioStreamPlayer in finale.players:
		check(p.playing, "%s playing" % p.stream.resource_path.get_file())
	check(finale.players[2].bus == &"Music" and finale.players[0].bus == &"SFX", "finale buses")
	check(is_equal_approx(AudioServer.get_bus_volume_db(bus(&"Ambience")), 0.0), "finale resets the fall fade")


func test_pressure_layers_failure_cut_and_restart_cleanup() -> void:
	await route.start()
	var level: Node = route.level
	var audio: LevelAudio = level.audio
	# Fixture: production PressureController → pressure_applied → LevelAudio.
	level.pressure.set_pressure_level(2)
	check(is_equal_approx(audio.tick_interval, 1.0), "rung 3: metronome 60 BPM")
	for hum in audio.hums:
		check(is_equal_approx(hum.volume_db, LevelAudio.MIX.hum + level.pressure.values.hum_db), "hum follows pressure dB")
	var ticks := audio.count(&"tick")
	await route.frames(2.05)
	check(audio.count(&"tick") - ticks == 3, "60 BPM ticks in real time (%d)" % (audio.count(&"tick") - ticks))
	check(GameState.request_pause(), "Esc pause")
	ticks = audio.count(&"tick")
	await route.frames(2.0)
	check(audio.count(&"tick") == ticks, "metronome stops with the ladder during pause")
	GameState.resume()
	level.pressure.set_pressure_level(3)
	check(is_equal_approx(audio.tick_interval, 60.0 / 90.0), "rung 4: 90 BPM")
	level.pressure.set_pressure_level(4)
	check(is_equal_approx(audio.tick_interval, 0.5) and audio.heartbeat_on, "rung 5: 120 BPM + heartbeat")
	await route.frames(1.3)
	check(audio.count(&"heartbeat") >= 2, "heartbeat audible")
	var squeeze := effect(&"Drone", "AudioEffectLowPassFilter") as AudioEffectLowPassFilter
	check(squeeze.cutoff_hz < 200.0, "drone squeezed by its filter")
	level.pressure.set_pressure_level(5)
	check(audio.tinnitus.playing and audio.tinnitus.bus == &"Music" and audio.tick_interval == 0.0, "rung 6: tinnitus only")
	await route.frames(0.4)
	check(AudioServer.get_bus_volume_db(bus(&"Ambience")) <= -59.0, "rung 6: ambience silenced")
	level.pressure.set_pressure_level(0)
	await route.frames(0.4)
	check(not audio.tinnitus.playing and not audio.heartbeat_on and is_equal_approx(AudioServer.get_bus_volume_db(bus(&"Ambience")), 0.0), "success clears layers")
	# Real failure: let the GRAB ladder expire through all six rungs.
	await route.walk_to(-4.3)
	if ov.is_active():
		await route.dismiss()
	for rung in 6:
		await route.frames(level.director.get_remaining() + 0.05)
		if rung < 4:
			await route.dismiss()
		elif rung == 4:
			await route.frames(0.65)
	check(GameState.state == &"failed", "ladder failed")
	check(audio.count(&"bad_dog_cut") == 1 and audio.silenced, "BAD DOG cut silences every layer")
	for hum in audio.hums:
		check(not hum.playing, "hum stopped by the cut")
	var old_id := level.get_instance_id()
	await route.frames(2.2)
	check(AudioServer.is_bus_mute(0), "3 s silence: master muted")
	await route.frames(3.0)
	check(GameState.state == &"menu" and not is_instance_id_valid(old_id), "menu after silence, old level freed")
	check(not AudioServer.is_bus_mute(0), "menu unmutes master")
	await route.start()
	var fresh: LevelAudio = route.level.audio
	check(fresh != audio and fresh.count(&"bad_dog_cut") == 0 and not fresh.silenced, "fresh LevelAudio on restart")
	check(fresh.drone.playing and fresh.hums[0].playing, "ambience restarts")


func _collect(value: Variant, out: Array[String]) -> void:
	if value is AudioStream:
		out.append(value.resource_path)
	elif value is Array:
		for v in value:
			_collect(v, out)
	elif value is Dictionary:
		for v in value.values():
			_collect(v, out)


func _wavs(dir: String) -> Array[String]:
	var out: Array[String] = []
	for sub in DirAccess.get_directories_at(dir):
		out.append_array(_wavs(dir.path_join(sub)))
	for file in DirAccess.get_files_at(dir):
		if file.get_extension() == "wav":
			out.append(dir.path_join(file))
	return out


## Reads the source RIFF directly (independent of import compression).
func _wav_info(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	var info := {channels = 0, rate = 0, bits = 0, peak = 0.0}
	f.seek(12)
	while f.get_position() + 8 <= f.get_length():
		var id := f.get_buffer(4).get_string_from_ascii()
		var size := f.get_32()
		var next := f.get_position() + size + (size & 1)
		if id == "fmt ":
			f.get_16()
			info.channels = f.get_16()
			info.rate = f.get_32()
			f.get_32()
			f.get_16()
			info.bits = f.get_16()
		elif id == "data":
			var pcm := f.get_buffer(size)
			var peak := 0
			for i in range(0, pcm.size(), 2):
				peak = maxi(peak, absi(pcm.decode_s16(i)))
			info.peak = peak / 32768.0
		f.seek(next)
	return info
