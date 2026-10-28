class_name PressureController
extends Node
## Maps pressure level 0–5 (ladder rung index) to world parameters (GDD §4, §9, §10).
##
## Level and transformation step are separate axes: this node never reads the
## transformation. Continuous values come from inspector Curves sampled at
## level / 5; discrete audio layers come from per-level arrays whose index is the
## level (GDD audio-table rung = level + 1). Consumers (F5 audio, F6 post) read
## `values` or listen to pressure_applied; the director knows nothing about them.

signal pressure_applied(level: int, values: Dictionary)

const MAX_LEVEL := 5

@export_group("Curves (x = level / 5)")
## Hum gain offset in dB (+3 dB at rung 2 per GDD §4).
@export var hum_db_curve: Curve
@export var vignette_curve: Curve
## Chromatic aberration: 0 until rung 4, 0.006 at level 5.
@export var aberration_curve: Curve
@export var grain_curve: Curve
@export var saturation_curve: Curve
## Camera trauma, scaled by Overlay.REDUCED_SHAKE_FACTOR when reduce_shake is on.
@export var shake_curve: Curve
## Light energy multiplier and coldness (0 = neutral, 1 = cold cyan).
@export var light_energy_curve: Curve
@export var light_cold_curve: Curve
@export_group("Discrete layers (index = level 0–5)")
@export var metronome_bpm := PackedFloat32Array([0, 0, 60, 90, 120, 0])
@export var heartbeat := PackedByteArray([0, 0, 0, 0, 1, 0])
@export var tinnitus := PackedByteArray([0, 0, 0, 0, 0, 1])
@export var ambient_on := PackedByteArray([1, 1, 1, 1, 1, 0])
@export_group("Targets (optional)")
@export var light: Light3D
@export var environment: WorldEnvironment
@export var vignette: CanvasItem
## Node with set_shake_trauma(float), usually the player.
@export var shake_target: Node
@export_group("Leash")
## Leash micro-step added per pull (GDD §7), decays on the next level change.
@export_range(0.0, 1.0, 0.01) var micro_step: float = 0.1

var level := 0
var micro := 0.0
var values: Dictionary = {}
var _base_light_energy := -1.0
var _base_light_color := Color.WHITE


func _init() -> void:
	hum_db_curve = _curve([0.0, 3.0, 4.5, 6.0, 7.5, 9.0], 0.0, 9.0)
	vignette_curve = _curve([0.25, 0.3, 0.4, 0.5, 0.62, 0.75], 0.0, 1.0)
	aberration_curve = _curve([0.0, 0.0, 0.0, 0.002, 0.004, 0.006], 0.0, 0.01)
	grain_curve = _curve([0.03, 0.04, 0.05, 0.06, 0.07, 0.08], 0.0, 0.2)
	saturation_curve = _curve([1.0, 0.95, 0.9, 0.82, 0.75, 0.7], 0.0, 1.0)
	shake_curve = _curve([0.0, 0.0, 0.0, 0.12, 0.25, 0.35], 0.0, 1.0)
	light_energy_curve = _curve([1.0, 0.95, 0.88, 0.8, 0.72, 0.6], 0.0, 1.0)
	light_cold_curve = _curve([0.0, 0.35, 0.5, 0.65, 0.8, 1.0], 0.0, 1.0)


func _ready() -> void:
	if light != null:
		_base_light_energy = light.light_energy
		_base_light_color = light.light_color
	set_pressure_level(0)


## Listener for CommandDirector.pressure_changed.
func set_pressure_level(p_level: int) -> void:
	level = clampi(p_level, 0, MAX_LEVEL)
	micro = 0.0
	_apply()


## Leash pull: one micro-step of pressure without touching the ladder timer.
func nudge() -> void:
	micro = minf(micro + micro_step, 1.0)
	_apply()


func reset() -> void:
	set_pressure_level(0)


func sample(curve: Curve) -> float:
	var x := clampf((level + micro) / float(MAX_LEVEL), 0.0, 1.0)
	return curve.sample(x) if curve != null else 0.0


func _apply() -> void:
	var ov := get_node_or_null(^"/root/Overlay")
	var shake := sample(shake_curve)
	if ov != null and ov.reduce_shake:
		shake *= ov.REDUCED_SHAKE_FACTOR
	var aberration := sample(aberration_curve)
	if ov != null and ov.reduce_flashes:
		aberration = 0.0
	values = {
		level = level,
		audio_rung = level + 1,
		hum_db = sample(hum_db_curve),
		vignette = sample(vignette_curve),
		aberration = aberration,
		grain = sample(grain_curve),
		saturation = sample(saturation_curve),
		shake_trauma = shake,
		light_energy = sample(light_energy_curve),
		light_cold = sample(light_cold_curve),
		metronome_bpm = metronome_bpm[level] if level < metronome_bpm.size() else 0.0,
		heartbeat = level < heartbeat.size() and heartbeat[level] != 0,
		tinnitus = level < tinnitus.size() and tinnitus[level] != 0,
		ambient = level < ambient_on.size() and ambient_on[level] != 0,
	}
	if light != null and _base_light_energy >= 0.0:
		light.light_energy = _base_light_energy * values.light_energy
		light.light_color = _base_light_color.lerp(Color("#bfe3ea"), values.light_cold)
	if environment != null and environment.environment != null:
		environment.environment.adjustment_enabled = true
		environment.environment.adjustment_saturation = values.saturation
	if vignette != null:
		vignette.modulate.a = values.vignette
	if shake_target != null and shake_target.has_method(&"set_shake_trauma"):
		shake_target.set_shake_trauma(shake)
	pressure_applied.emit(level, values)


static func _curve(points: Array, min_v: float, max_v: float) -> Curve:
	var c := Curve.new()
	c.min_value = min_v
	c.max_value = max_v
	for i in points.size():
		c.add_point(Vector2(i / float(points.size() - 1), points[i]), 0, 0, Curve.TANGENT_LINEAR, Curve.TANGENT_LINEAR)
	return c
