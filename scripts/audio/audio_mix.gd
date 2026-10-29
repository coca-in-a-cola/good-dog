extends Node
## Game-side mix state (autoload AudioMix), GDD §10 "Техника и сведение".
##
## Buses (res://default_bus_layout.tres): Master [HardLimiter, ceiling −1 dB]
## ← SFX, Ambience, UI, Music; Drone → Ambience; ReverbCell/Corridor/Pit → SFX.
## The command_overlay addon stays portable: it only exposes `sfx_bus`, which this
## node points at UI so the camera flash bypasses the world filter. While
## Overlay.is_active() the SFX and Ambience low-pass sits at 800 Hz ("from behind
## a wall"); afterwards the cutoff opens over Overlay.unfreeze_time, so the world
## thaws out of the filter, then the effect is disabled. Real time only
## (GameState.clock): time_scale 0.05 and the BLACK pause never stretch it.

const UI_BUS := &"UI"
const MUFFLED_BUSES: Array[StringName] = [&"SFX", &"Ambience"]
const MUFFLE_HZ := 800.0
const OPEN_HZ := 20000.0
## Bus volumes restored to their layout values on every fresh scene (fades never
## leak into a restart).
const RESET_BUSES: Array[StringName] = [&"SFX", &"Ambience", &"UI", &"Music"]
const SETTINGS_PATH := "user://settings.cfg"

signal master_volume_changed(volume: float)

var master_volume: float = 100.0:
	set(val):
		var clamped := clampf(val, 0.0, 100.0)
		master_volume = clamped
		_apply_master_volume()

var _layout_db := {}
var _muffled := false
var _thaw_start := -1.0
var _thaw_time := 0.25
var _cutoff := MUFFLE_HZ
## bus name → {from, to, start, time}
var _fades := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var ov := _overlay()
	if ov != null:
		ov.sfx_bus = UI_BUS
	var gs := get_node_or_null(^"/root/GameState")
	if gs != null:
		gs.state_changed.connect(_on_game_state)
	for bus in RESET_BUSES:
		var idx := AudioServer.get_bus_index(bus)
		if idx >= 0:
			_layout_db[bus] = AudioServer.get_bus_volume_db(idx)
	load_settings()
	reset()


func _process(_delta: float) -> void:
	tick()


## Overlay-driven filter state; also advances bus fades.
func tick() -> void:
	var now := _now()
	var ov := _overlay()
	var active: bool = ov != null and ov.is_active()
	if active and (not _muffled or _thaw_start >= 0.0):
		_muffled = true
		_thaw_start = -1.0
		_set_muffle(true, MUFFLE_HZ)
	elif not active and _muffled and _thaw_start < 0.0:
		_thaw_start = now
		_thaw_time = maxf(ov.unfreeze_time if ov != null else 0.25, 0.001)
	if _thaw_start >= 0.0:
		var k := clampf((now - _thaw_start) / _thaw_time, 0.0, 1.0)
		if k >= 1.0:
			_muffled = false
			_thaw_start = -1.0
			_set_muffle(false, MUFFLE_HZ)
		else:
			_set_muffle(true, MUFFLE_HZ * pow(OPEN_HZ / MUFFLE_HZ, k))
	_update_fades(now)


## True while the low-pass is engaged (muffled or thawing open).
func is_muffled() -> bool:
	return _muffled


func get_cutoff_hz() -> float:
	return _cutoff


## Real-time linear-in-dB fade of a bus volume. seconds <= 0 jumps.
func fade_bus(bus: StringName, to_db: float, seconds: float) -> void:
	var idx := AudioServer.get_bus_index(bus)
	if idx < 0:
		return
	if seconds <= 0.0:
		_fades.erase(bus)
		AudioServer.set_bus_volume_db(idx, to_db)
		return
	_fades[bus] = {from = AudioServer.get_bus_volume_db(idx), to = to_db, start = _now(), time = seconds}


func set_master_volume(vol: float, save: bool = true) -> void:
	var clamped := clampf(vol, 0.0, 100.0)
	master_volume = clamped
	_apply_master_volume()
	if save:
		save_settings()
	master_volume_changed.emit(master_volume)


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		if cfg.has_section_key("audio", "master_volume"):
			master_volume = clampf(float(cfg.get_value("audio", "master_volume", 100.0)), 0.0, 100.0)
	_apply_master_volume()


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	cfg.set_value("audio", "master_volume", master_volume)
	cfg.save(SETTINGS_PATH)


func _apply_master_volume() -> void:
	var idx := AudioServer.get_bus_index(&"Master")
	if idx < 0:
		idx = 0
	if master_volume <= 0.0:
		AudioServer.set_bus_mute(idx, true)
		AudioServer.set_bus_volume_db(idx, -80.0)
	else:
		AudioServer.set_bus_mute(idx, false)
		AudioServer.set_bus_volume_db(idx, linear_to_db(master_volume / 100.0))


## Snaps every managed bus back to its neutral state.
func reset() -> void:
	_fades.clear()
	_muffled = false
	_thaw_start = -1.0
	_set_muffle(false, MUFFLE_HZ)
	for bus in RESET_BUSES:
		var idx := AudioServer.get_bus_index(bus)
		if idx >= 0:
			AudioServer.set_bus_volume_db(idx, _layout_db.get(bus, 0.0))


## Layout volume of a managed bus (fade targets are relative to it).
func layout_db(bus: StringName) -> float:
	return _layout_db.get(bus, 0.0)


static func find_effect(bus: StringName, type: String) -> int:
	var idx := AudioServer.get_bus_index(bus)
	if idx < 0:
		return -1
	for i in AudioServer.get_bus_effect_count(idx):
		if AudioServer.get_bus_effect(idx, i).is_class(type):
			return i
	return -1


func _set_muffle(on: bool, cutoff: float) -> void:
	_cutoff = cutoff
	for bus in MUFFLED_BUSES:
		var idx := AudioServer.get_bus_index(bus)
		var fx := find_effect(bus, "AudioEffectLowPassFilter")
		if idx < 0 or fx < 0:
			continue
		(AudioServer.get_bus_effect(idx, fx) as AudioEffectLowPassFilter).cutoff_hz = cutoff
		AudioServer.set_bus_effect_enabled(idx, fx, on)


func _update_fades(now: float) -> void:
	for bus: StringName in _fades.keys():
		var f: Dictionary = _fades[bus]
		var k := clampf((now - f.start) / f.time, 0.0, 1.0)
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index(bus), lerpf(f.from, f.to, k))
		if k >= 1.0:
			_fades.erase(bus)


func _on_game_state(state: StringName) -> void:
	# The fall fade must survive into the finale cut; failure is muted by GameState.
	if state not in [&"falling", &"failed"]:
		reset()


func _now() -> float:
	var gs := get_node_or_null(^"/root/GameState")
	return gs.clock.now() if gs != null else Time.get_ticks_usec() / 1000000.0


func _overlay() -> Node:
	return get_node_or_null(^"/root/Overlay")
