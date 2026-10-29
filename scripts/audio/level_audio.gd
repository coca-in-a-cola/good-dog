class_name LevelAudio
extends Node3D
## F5 sound for the production level (GDD §5–§8, §10). Installed by level_full.gd.
##
## Listens only to signals the level already exposes (player, director, pressure,
## transformation, interactables, leash, GameState) and owns every player it
## creates; _exit_tree stops them, so restarts leave no playback behind.
## Diegetic one-shots and the player's own sounds are AudioStreamPlayer3D on SFX
## and pick up room reverb from the Area3D zones below. Ambience (lamp hum, CCTV
## servo, drone) is on Ambience/Drone. Non-diegetic pressure layers (metronome,
## heartbeat, tinnitus) are on Music and praise is on UI, so neither is muffled
## while an order is on screen; the praise bell sounds the same every time.
## Timers use GameState.clock real time and stop during the Esc/BLACK pause.

const CATALOG := {
	bark = [
		preload("res://assets/audio/sfx/bark/bark_step0.wav"),
		preload("res://assets/audio/sfx/bark/bark_step1.wav"),
		preload("res://assets/audio/sfx/bark/bark_step2.wav"),
		preload("res://assets/audio/sfx/bark/bark_step3.wav"),
		preload("res://assets/audio/sfx/bark/bark_step4.wav"),
	],
	praise = preload("res://assets/audio/sfx/praise/good_dog_praise.wav"),
	praise_bell = preload("res://assets/audio/sfx/praise/praise_bell.wav"),
	stick_pickup = preload("res://assets/audio/sfx/stick/stick_pickup.wav"),
	stick_place = preload("res://assets/audio/sfx/stick/stick_place.wav"),
	footsteps = {
		shoes = [
			preload("res://assets/audio/sfx/footsteps/shoes_0.wav"),
			preload("res://assets/audio/sfx/footsteps/shoes_1.wav"),
			preload("res://assets/audio/sfx/footsteps/shoes_2.wav"),
			preload("res://assets/audio/sfx/footsteps/shoes_3.wav"),
		],
		barefoot = [
			preload("res://assets/audio/sfx/footsteps/barefoot_0.wav"),
			preload("res://assets/audio/sfx/footsteps/barefoot_1.wav"),
			preload("res://assets/audio/sfx/footsteps/barefoot_2.wav"),
			preload("res://assets/audio/sfx/footsteps/barefoot_3.wav"),
		],
		shuffle = [
			preload("res://assets/audio/sfx/footsteps/shuffle_0.wav"),
			preload("res://assets/audio/sfx/footsteps/shuffle_1.wav"),
			preload("res://assets/audio/sfx/footsteps/shuffle_2.wav"),
			preload("res://assets/audio/sfx/footsteps/shuffle_3.wav"),
		],
		claws = [
			preload("res://assets/audio/sfx/footsteps/claws_0.wav"),
			preload("res://assets/audio/sfx/footsteps/claws_1.wav"),
			preload("res://assets/audio/sfx/footsteps/claws_2.wav"),
			preload("res://assets/audio/sfx/footsteps/claws_3.wav"),
		],
	},
	leash = preload("res://assets/audio/sfx/leash/leash_pull.wav"),
	fall_wind = preload("res://assets/audio/sfx/fall/fall_wind.wav"),
	hum = preload("res://assets/audio/ambience/fluorescent_hum_loop.wav"),
	servo = preload("res://assets/audio/ambience/cctv_servo_loop.wav"),
	drone = preload("res://assets/audio/ambience/drone_loop.wav"),
	tick = preload("res://assets/audio/sfx/pressure/metronome_tick.wav"),
	heartbeat = preload("res://assets/audio/sfx/pressure/heartbeat.wav"),
	tinnitus = preload("res://assets/audio/sfx/pressure/tinnitus_loop.wav"),
	panting = preload("res://assets/audio/sfx/player/panting_loop.wav"),
	crunch = preload("res://assets/audio/sfx/transform/transform_crunch.wav"),
	door = preload("res://assets/audio/sfx/events/door_clank.wav"),
	bad_dog_cut = preload("res://assets/audio/sfx/events/bad_dog_cut.wav"),
	applause = preload("res://assets/audio/sfx/finale/applause_children.wav"),
}
## TransformStep.footstep_set → CATALOG.footsteps key (GDD §6 "Шаги" column).
const FOOTSTEP_SETS := {
	heavy_shoes = &"shoes", barefoot = &"barefoot", barefoot_shuffle = &"shuffle",
	claws = &"claws", claws_panting = &"claws",
}
## Player volume per cue, dB. Calibrated with tools/audio/mix_capture.gd against
## the GDD §10 target of −16…−18 LUFS integrated on the post-limiter Master.
const MIX := {
	bark = 0.0, praise = -6.0, praise_bell = 2.0, stick = 2.0, footsteps = 7.0, leash = 2.0,
	fall_wind = 2.0, hum = -3.0, servo = -8.0, drone = 2.0, tick = 2.0, heartbeat = -5.0,
	tinnitus = -6.0, panting = -2.0, crunch = 0.0, door = 0.0, bad_dog_cut = 0.0,
	distant = -4.0, applause_mirror = -2.0,
}
## Physics layer 20, used only by reverb zones and the players that query them.
const REVERB_LAYER := 1 << 19
## [node name, bus, centre, box size, send amount, priority]. Observation room and
## connector share the long corridor reverb (three buses per GDD §10).
const ZONES := [
	["CellReverb", &"ReverbCell", Vector3(0, 1.5, 0), Vector3(4.2, 3.4, 5.2), 0.35, 1],
	["CorridorReverb", &"ReverbCorridor", Vector3(0, 1.5, -11.6), Vector3(2.6, 3.4, 18.0), 0.5, 1],
	["ObservationReverb", &"ReverbCorridor", Vector3(0, 1.5, -24.6), Vector3(8.2, 3.4, 8.0), 0.4, 1],
	["ConnectorReverb", &"ReverbCorridor", Vector3(0, 1.5, -29.6), Vector3(2.6, 3.4, 2.2), 0.45, 1],
]
const PIT_ZONE_AMOUNT := 0.7
## GDD §10: in the pit hall the praise bell rings every 6 s until the jump.
const PIT_BELL_INTERVAL := 6.0
const HEARTBEAT_INTERVAL := 0.6
const LEASH_COOLDOWN := 0.6
## The wind's hard cut (the asset is silent after it): GDD §5 bit 13 → 14.
const FALL_CUT_AT := 3.7
const DOOR_AT := 0.3
const CORRIDOR_EVENT_MIN := 9.0
const CORRIDOR_EVENT_MAX := 17.0
const DOOR_SOURCES := [Vector3(-2.4, 1.2, -4.8), Vector3(2.4, 1.2, -8.0), Vector3(-2.4, 1.2, -11.2),
		Vector3(2.4, 1.2, -4.8), Vector3(-2.4, 1.2, -8.0), Vector3(2.4, 1.2, -11.2)]
const MIRROR_SOURCE := Vector3(5.6, 1.4, -24.6)

## Plays per cue (diagnostics and tests).
var cue_counts := {}
## Last stream started per cue.
var last_stream := {}
var level: Node3D
var hums: Array[AudioStreamPlayer3D] = []
var zones: Array[Area3D] = []
var servo: AudioStreamPlayer3D
var drone: AudioStreamPlayer
var tinnitus: AudioStreamPlayer
var panting: AudioStreamPlayer3D
var fall_wind: AudioStreamPlayer
var tick_interval := 0.0
var heartbeat_on := false
var pit_bell_armed := false
var falling := false
var silenced := false

var _rng := RandomNumberGenerator.new()
var _owned: Array[Node] = []
var _bark: AudioStreamPlayer3D
var _steps: Array[AudioStreamPlayer3D] = []
var _step_turn := 0
var _last_step_variant := -1
var _leash: AudioStreamPlayer3D
var _praise: AudioStreamPlayer
var _cut: AudioStreamPlayer
var _tick: AudioStreamPlayer
var _heart: AudioStreamPlayer
var _crunch: AudioStreamPlayer
var _hum_db := 0.0
var _last_tick := 0.0
var _elapsed := 0.0
var _door_done := false
var _tick_left := 0.0
var _heart_left := 0.0
var _bell_left := 0.0
var _fall_elapsed := 0.0
var _last_leash := -INF
var _corridor_left := 0.0
var _servo_level := 0.0
var _servo_forward := Vector3.ZERO


## Builds zones and players, then connects to the level's production signals.
func bind(p_level: Node3D) -> void:
	level = p_level
	_rng.seed = 46
	_corridor_left = _rng.randf_range(CORRIDOR_EVENT_MIN, CORRIDOR_EVENT_MAX)
	_last_tick = GameState.clock.now()
	_build_zones()
	_build_players()
	var player: GoodDogPlayer = level.player
	player.barked.connect(_on_barked)
	player.footstep.connect(_on_footstep)
	level.director.command_started.connect(_on_command_started)
	level.director.command_succeeded.connect(_on_command_succeeded)
	level.director.command_completed.connect(_on_command_completed)
	level.director.failed.connect(_on_failed)
	level.pressure.pressure_applied.connect(_on_pressure)
	level.transform_ctl.transform_step_changed.connect(_on_transform_step)
	level.stick.completed.connect(_on_stick)
	level.place_zone.completed.connect(_on_placed)
	level.leash_ctl.leash_pulled.connect(_on_leash)
	GameState.state_changed.connect(_on_game_state)
	_on_pressure(level.pressure.level, level.pressure.values)


func _exit_tree() -> void:
	if GameState.state_changed.is_connected(_on_game_state):
		GameState.state_changed.disconnect(_on_game_state)
	_stop_all()


func _process(_delta: float) -> void:
	var now := GameState.clock.now()
	var dt := maxf(now - _last_tick, 0.0)
	_last_tick = now
	if silenced:
		return
	if falling:
		_fall_elapsed += dt
		if _fall_elapsed >= FALL_CUT_AT:
			silence()
		return
	_update_servo(dt)
	if get_tree().paused:
		return  # Esc pause and BLACK lines freeze every timed layer, like the ladder.
	_elapsed += dt
	if not _door_done and _elapsed >= DOOR_AT:
		_door_done = true
		_play_3d_at(CATALOG.door, &"door", Vector3(0, 1.5, -2.6))
	if tick_interval > 0.0:
		_tick_left -= dt
		if _tick_left <= 0.0:
			_tick_left += tick_interval
			_play(_tick, CATALOG.tick, &"tick")
	if heartbeat_on:
		_heart_left -= dt
		if _heart_left <= 0.0:
			_heart_left += HEARTBEAT_INTERVAL
			_play(_heart, CATALOG.heartbeat, &"heartbeat")
	if pit_bell_armed:
		_bell_left -= dt
		if _bell_left <= 0.0:
			_bell_left += PIT_BELL_INTERVAL
			_play_3d_at(CATALOG.praise_bell, &"praise_bell", level.PIT_CENTER + Vector3(0, -1.0, 0), 8.0)
	_update_corridor(dt)


## Stops every owned layer immediately (BAD DOG, end of the fall).
func silence() -> void:
	silenced = true
	_stop_all()


func count(cue: StringName) -> int:
	return cue_counts.get(cue, 0)


# --- Signal consumers -----------------------------------------------------------

func _on_barked() -> void:
	var step := clampi(level.transform_ctl.current_step, 0, CATALOG.bark.size() - 1)
	_play(_bark, CATALOG.bark[step], &"bark")


func _on_footstep(footstep_set: StringName) -> void:
	var variants: Array = CATALOG.footsteps[FOOTSTEP_SETS.get(footstep_set, &"shoes")]
	var pick := _rng.randi_range(0, variants.size() - 1)
	if pick == _last_step_variant:
		pick = (pick + 1) % variants.size()
	_last_step_variant = pick
	var p := _steps[_step_turn]
	_step_turn = (_step_turn + 1) % _steps.size()
	p.pitch_scale = _rng.randf_range(0.96, 1.04)
	_play(p, variants[pick], &"footstep")


func _on_command_started(id: StringName) -> void:
	if id == &"jump":
		pit_bell_armed = true
		_bell_left = PIT_BELL_INTERVAL


## Praise sounds the instant the timer stops, with the GOOD DOG line (GDD §4).
func _on_command_succeeded(_id: StringName) -> void:
	var command: Command = level.director.command
	if command != null and command.success_line != null:
		_play(_praise, CATALOG.praise, &"praise")


func _on_command_completed(id: StringName) -> void:
	if id == &"place":
		# Observers light up behind the mirror (level_full reveal): muffled applause.
		var p := _play_3d_at(CATALOG.applause, &"applause_mirror", MIRROR_SOURCE, 1.0)
		p.pitch_scale = 0.8
		p.attenuation_filter_cutoff_hz = 700.0


func _on_failed() -> void:
	silence()
	_cut.play()  # the cut itself is the last sound before 3 s of silence
	_count(&"bad_dog_cut", CATALOG.bad_dog_cut)


func _on_pressure(p_level: int, values: Dictionary) -> void:
	if values.is_empty() or silenced:
		return
	_hum_db = values.hum_db
	for hum in hums:
		hum.volume_db = MIX.hum + _hum_db
	var squeeze := AudioMix.find_effect(&"Drone", "AudioEffectLowPassFilter")
	if squeeze >= 0:
		var fx := AudioServer.get_bus_effect(AudioServer.get_bus_index(&"Drone"), squeeze) as AudioEffectLowPassFilter
		fx.cutoff_hz = 320.0 * pow(110.0 / 320.0, p_level / 5.0)
	drone.volume_db = MIX.drone + p_level * 1.6
	AudioMix.fade_bus(&"Ambience", AudioMix.layout_db(&"Ambience") if values.ambient else -60.0, 0.3)
	var bpm: float = values.metronome_bpm
	var new_interval := 60.0 / bpm if bpm > 0.0 else 0.0
	if new_interval != tick_interval:
		tick_interval = new_interval
		_tick_left = 0.0
	if values.heartbeat and not heartbeat_on:
		_heart_left = 0.0
	heartbeat_on = values.heartbeat
	if values.tinnitus and not tinnitus.playing:
		tinnitus.play()
		_count(&"tinnitus", CATALOG.tinnitus)
	elif not values.tinnitus:
		tinnitus.stop()
	panting.volume_db = MIX.panting + p_level * 1.5


func _on_transform_step(step: int) -> void:
	var data: TransformStep = level.transform_ctl.steps[step]
	if data.transition_sfx != null:
		_play(_crunch, data.transition_sfx, &"crunch")
	if step >= 3:
		panting.pitch_scale = 1.0 if step == 3 else 1.25  # step 4: faster panting
		if not panting.playing:
			panting.play()
			_count(&"panting", CATALOG.panting)


func _on_stick(_completion: StringName) -> void:
	_play_3d_at(CATALOG.stick_pickup, &"stick_pickup", level.stick.target.global_position)


func _on_placed(_completion: StringName) -> void:
	_play_3d_at(CATALOG.stick_place, &"stick_place", level.place_zone.visual.global_position)


func _on_leash(_toward: Vector3) -> void:
	var now := GameState.clock.now()
	if now - _last_leash < LEASH_COOLDOWN:
		return
	_last_leash = now
	_play(_leash, CATALOG.leash, &"leash")


func _on_game_state(state: StringName) -> void:
	if state != &"falling" or falling:
		return
	falling = true
	pit_bell_armed = false
	tick_interval = 0.0
	heartbeat_on = false
	tinnitus.stop()
	AudioMix.fade_bus(&"Ambience", -60.0, 3.0)  # world fades, the breathing stays
	fall_wind.play()
	_count(&"fall_wind", CATALOG.fall_wind)


# --- Construction ---------------------------------------------------------------

func _build_zones() -> void:
	for z: Array in ZONES:
		var box := BoxShape3D.new()
		box.size = z[3]
		zones.append(_zone(z[0], z[1], z[2], box, z[4], z[5]))
	# Hall plus the shaft below it, so the fall keeps the cavern reverb.
	var cylinder := CylinderShape3D.new()
	cylinder.radius = 12.2
	cylinder.height = 30.0
	zones.append(_zone("PitHallReverb", &"ReverbPit", level.PIT_CENTER + Vector3(0, -9.0, 0), cylinder,
			PIT_ZONE_AMOUNT, 0))


func _zone(label: String, bus: StringName, at: Vector3, shape: Shape3D, amount: float, priority: int) -> Area3D:
	var area := Area3D.new()
	area.name = label
	area.collision_layer = REVERB_LAYER
	area.collision_mask = 0
	area.monitoring = false
	area.priority = priority
	area.reverb_bus_enabled = true
	area.reverb_bus_name = bus
	area.reverb_bus_amount = amount
	area.reverb_bus_uniformity = 0.2
	var collision := CollisionShape3D.new()
	collision.shape = shape
	area.add_child(collision)
	add_child(area)
	area.global_position = at
	return area


func _build_players() -> void:
	var player: GoodDogPlayer = level.player
	_bark = _player_3d(player.head, &"bark", Vector3(0, -0.05, -0.15))
	for i in 2:
		_steps.append(_player_3d(player, &"footsteps", Vector3(0, 0.05, 0)))
	_leash = _player_3d(player, &"leash", Vector3(0, 0.4, 0))
	panting = _player_3d(player.head, &"panting", Vector3(0, -0.05, -0.1))
	panting.stream = CATALOG.panting
	# Own-body sounds: no distance gain/air filter (inverse-distance gain at ~1.5 m
	# would hit max_db and flatten the mix); they keep panning and room reverb.
	for p: AudioStreamPlayer3D in [_bark, _leash, panting] + _steps:
		p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_DISABLED
		p.attenuation_filter_db = 0.0
		p.max_db = 12.0
	for light in level.get_children():
		if light is OmniLight3D or light is SpotLight3D:
			var hum := _player_3d(light, &"hum", Vector3.ZERO, &"Ambience")
			hum.stream = CATALOG.hum
			hum.unit_size = 2.5
			hum.max_distance = 16.0
			hum.process_mode = Node.PROCESS_MODE_ALWAYS
			hums.append(hum)
	var head := level.get_node_or_null(^"ObservationPitArt/CCTVTrackingHead") as Node3D
	if head != null:
		servo = _player_3d(head, &"servo", Vector3.ZERO, &"Ambience")
		servo.stream = CATALOG.servo
		servo.unit_size = 3.0
		servo.volume_db = -80.0
		servo.process_mode = Node.PROCESS_MODE_ALWAYS
		_servo_forward = -head.global_basis.z
	drone = _player_2d(&"drone", &"Drone")
	drone.stream = CATALOG.drone
	tinnitus = _player_2d(&"tinnitus", &"Music")
	tinnitus.stream = CATALOG.tinnitus
	_tick = _player_2d(&"tick", &"Music")
	_heart = _player_2d(&"heartbeat", &"Music")
	_praise = _player_2d(&"praise", &"UI")
	_crunch = _player_2d(&"crunch", &"SFX")
	_cut = _player_2d(&"bad_dog_cut", &"UI")
	_cut.stream = CATALOG.bad_dog_cut
	fall_wind = _player_2d(&"fall_wind", &"SFX")
	fall_wind.stream = CATALOG.fall_wind
	# Prologue: the lamps already hum in the dark (GDD §5 bit 0).
	for hum in hums:
		hum.play(_rng.randf() * CATALOG.hum.get_length())
	if servo != null:
		servo.play()
	drone.play()


func _player_3d(parent: Node3D, cue: StringName, at: Vector3, bus := &"SFX") -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.name = "%sAudio" % String(cue).to_pascal_case()
	p.bus = bus
	p.volume_db = MIX[cue]
	p.area_mask = REVERB_LAYER
	p.position = at
	parent.add_child(p)
	_owned.append(p)
	return p


func _player_2d(cue: StringName, bus: StringName) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.name = "%sAudio" % String(cue).to_pascal_case()
	p.bus = bus
	p.volume_db = MIX[cue]
	p.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(p)
	_owned.append(p)
	return p


## One-shot 3D source at a world position (freed when it finishes).
func _play_3d_at(stream: AudioStream, cue: StringName, at: Vector3, unit_size := 3.0) -> AudioStreamPlayer3D:
	var mix_key: StringName = &"stick" if cue in [&"stick_pickup", &"stick_place"] else cue
	var p := AudioStreamPlayer3D.new()
	p.bus = &"SFX"
	p.volume_db = MIX[mix_key]
	p.area_mask = REVERB_LAYER
	p.unit_size = unit_size
	p.stream = stream
	p.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(p)
	p.global_position = at
	_owned.append(p)
	p.finished.connect(func() -> void:
		_owned.erase(p)
		p.queue_free())
	p.play()
	_count(cue, stream)
	return p


func _play(p: Node, stream: AudioStream, cue: StringName) -> void:
	p.stream = stream
	p.play()
	_count(cue, stream)


func _count(cue: StringName, stream: AudioStream) -> void:
	cue_counts[cue] = count(cue) + 1
	last_stream[cue] = stream


func _stop_all() -> void:
	for p in _owned:
		if is_instance_valid(p):
			p.stop()
	tick_interval = 0.0
	heartbeat_on = false
	pit_bell_armed = false


# --- Continuous layers ----------------------------------------------------------

## Servo whine follows the CCTV head's angular speed (GDD §8 tracking camera).
func _update_servo(dt: float) -> void:
	if servo == null or dt <= 0.0:
		return
	var head := servo.get_parent() as Node3D
	var forward := -head.global_basis.z
	var speed := _servo_forward.angle_to(forward) / dt
	_servo_forward = forward
	_servo_level = move_toward(_servo_level, clampf(speed / 0.8, 0.0, 1.0), dt * 6.0)
	servo.volume_db = MIX.servo + linear_to_db(maxf(_servo_level, 0.001))
	servo.pitch_scale = 0.85 + 0.3 * _servo_level


## GDD §10 corridor background: distant barks of other "dogs" and door slams.
func _update_corridor(dt: float) -> void:
	var z: float = level.player.position.z
	if z > -3.5 or z < -29.0:
		return
	_corridor_left -= dt
	if _corridor_left > 0.0:
		return
	_corridor_left = _rng.randf_range(CORRIDOR_EVENT_MIN, CORRIDOR_EVENT_MAX)
	var at: Vector3 = DOOR_SOURCES[_rng.randi_range(0, DOOR_SOURCES.size() - 1)]
	var bark := _rng.randf() < 0.6
	var stream: AudioStream = CATALOG.bark[_rng.randi_range(3, 4)] if bark else CATALOG.door
	var p := _play_3d_at(stream, &"distant", at, 1.0)
	p.pitch_scale = _rng.randf_range(0.85, 1.1)
	p.attenuation_filter_cutoff_hz = 1200.0
