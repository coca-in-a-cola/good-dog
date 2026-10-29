class_name TraumaCamera
extends Node
## GDD §9 camera layer over the player's Camera3D (FastNoiseLite trauma model).
##
## Owns everything that moves the lens after the player adapter has placed it:
## trauma shake (offset and roll = trauma² × noise), the text-line FOV punch,
## the GOOD DOG roll tilt, the transformation FOV breath and the leash jolt.
## Runs on the shared real clock, so a punch under OVER_WORLD (time_scale 0.05)
## still lasts 0.08 s; every timer freezes with the Esc pause and BLACK lines.
## Reads Overlay.reduce_shake, the single accessibility flag.

const DECAY_PER_S := 0.8
const MAX_OFFSET_M := 0.06
const MAX_ROLL_DEG := 2.5
const NOISE_SPEED := 10.0
## Text line appearance: FOV −4° over 0.08 s, back over 0.25 s.
const PUNCH_FOV_DEG := -4.0
const PUNCH_IN := 0.08
const PUNCH_OUT := 0.25
## GOOD DOG "petting": roll +3° over 0.2 s, relaxing over 0.3 s; FOV opens +2°.
const PRAISE_ROLL_DEG := 3.0
const PRAISE_FOV_DEG := 2.0
const PRAISE_IN := 0.2
const PRAISE_OUT := 0.3
## Transformation step: FOV "breathes" 2.5° and settles, with a light shake (GDD §6).
const BREATH_FOV_DEG := 2.5
const BREATH_IN := 0.25
const BREATH_OUT := 0.6
const TRANSFORM_TRAUMA := 0.3
## Leash tug: 0.1 s jolt toward the pit, then a fast decaying spring back.
const JOLT_M := 0.08
const JOLT_IN := 0.1
const JOLT_SPRING := 0.4
const JOLT_SPRING_HZ := 9.0
## A held outward key pulls every physics frame; one jolt per cooldown.
const JOLT_COOLDOWN := 0.5

var camera: Camera3D
## Transformation FOV (TransformStep row); punches are added on top of it.
var base_fov := 75.0
## Pressure-held minimum trauma (PressureController already applied reduce_shake).
var baseline := 0.0
## Transient trauma, decays linearly at DECAY_PER_S.
var trauma := 0.0
## Defaults to GameState.clock; tests inject a manual clock.
var clock: RealClock

var _noise := FastNoiseLite.new()
var _noise_t := 0.0
var _last_tick := 0.0
var _punch_t := INF
var _praise_t := INF
var _breath_t := INF
var _jolt_t := INF
var _jolt_dir := Vector3.ZERO


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if clock == null:
		var gs := get_node_or_null(^"/root/GameState")
		clock = gs.clock if gs != null else RealClock.new()
	_noise.seed = 46
	_noise.frequency = 2.0
	_last_tick = clock.now()


func _process(_delta: float) -> void:
	tick()


func tick() -> void:
	var now := clock.now()
	var dt := maxf(now - _last_tick, 0.0)
	_last_tick = now
	if is_inside_tree() and get_tree().paused:
		dt = 0.0
	advance(dt)


## Advances every timer by `dt` real seconds and applies the result to the camera.
func advance(dt: float) -> void:
	trauma = maxf(trauma - DECAY_PER_S * dt, 0.0)
	_noise_t += dt
	_punch_t += dt
	_praise_t += dt
	_breath_t += dt
	_jolt_t += dt
	apply()


# --- Events -------------------------------------------------------------------

## Text line appearance (Overlay.word_shown).
func punch() -> void:
	_punch_t = 0.0


## GOOD DOG praise.
func praise() -> void:
	_praise_t = 0.0


## Transformation step: FOV breath and a light shake.
func transform_pulse() -> void:
	_breath_t = 0.0
	add_trauma(TRANSFORM_TRAUMA)


func breath() -> void:
	transform_pulse()


func add_trauma(amount: float) -> void:
	trauma = clampf(trauma + amount, 0.0, 1.0)


## Leash pull toward the pit centre (world direction). Returns false while the
## previous jolt is still within its cooldown.
func jolt(toward: Vector3) -> bool:
	var flat := Vector3(toward.x, 0.0, toward.z)
	if _jolt_t < JOLT_COOLDOWN or flat.length() < 0.0001:
		return false
	_jolt_dir = flat.normalized()
	_jolt_t = 0.0
	return true


## Drops every running event (fresh run); the pressure baseline is kept.
func reset() -> void:
	trauma = 0.0
	_punch_t = INF
	_praise_t = INF
	_breath_t = INF
	_jolt_t = INF
	apply()


# --- Outputs ------------------------------------------------------------------

func shake_factor() -> float:
	var ov := get_node_or_null(^"/root/Overlay")
	return ov.REDUCED_SHAKE_FACTOR if ov != null and ov.reduce_shake else 1.0


## Effective trauma 0..1: max(pressure baseline, transient × reduce_shake factor).
func get_trauma() -> float:
	return clampf(maxf(baseline, trauma * shake_factor()), 0.0, 1.0)


func get_fov_offset() -> float:
	return PUNCH_FOV_DEG * pulse(_punch_t, PUNCH_IN, PUNCH_OUT) \
			+ PRAISE_FOV_DEG * pulse(_praise_t, PRAISE_IN, PRAISE_OUT) \
			+ BREATH_FOV_DEG * pulse(_breath_t, BREATH_IN, BREATH_OUT)


## Praise tilt plus the trauma roll (trauma² × max_roll × noise(t + 100)).
func get_roll_deg() -> float:
	var shake := get_trauma() * get_trauma()
	return PRAISE_ROLL_DEG * pulse(_praise_t, PRAISE_IN, PRAISE_OUT) \
			+ MAX_ROLL_DEG * shake * _noise.get_noise_2d(_noise_t * NOISE_SPEED + 100.0, 0.0)


## World-space leash displacement: toward the pit, then a decaying oscillation.
func get_jolt() -> Vector3:
	if _jolt_t >= JOLT_IN + JOLT_SPRING:
		return Vector3.ZERO
	var k: float
	if _jolt_t < JOLT_IN:
		k = Tween.interpolate_value(0.0, 1.0, _jolt_t, JOLT_IN, Tween.TRANS_QUAD, Tween.EASE_OUT)
	else:
		var s := _jolt_t - JOLT_IN
		k = cos(TAU * JOLT_SPRING_HZ * s) * exp(-s * 10.0) * (1.0 - s / JOLT_SPRING)
	return _jolt_dir * JOLT_M * k * shake_factor()


func apply() -> void:
	if camera == null:
		return
	var shake := get_trauma() * get_trauma()
	camera.h_offset = _noise.get_noise_2d(_noise_t * NOISE_SPEED, 0.0) * MAX_OFFSET_M * shake
	camera.v_offset = _noise.get_noise_2d(0.0, _noise_t * NOISE_SPEED) * MAX_OFFSET_M * shake
	camera.rotation.z = deg_to_rad(get_roll_deg())
	camera.fov = base_fov + get_fov_offset()
	# Head bob owns camera.position.y; the jolt uses the horizontal head axes.
	var local := get_jolt()
	var parent := camera.get_parent() as Node3D
	if parent != null and parent.is_inside_tree():
		local = parent.global_basis.inverse() * local
	camera.position.x = local.x
	camera.position.z = local.z


## 0 → 1 over `attack` (ease-out), back to 0 over `release` (ease-in-out); 0 outside.
static func pulse(t: float, attack: float, release: float) -> float:
	if t < 0.0 or t >= attack + release:
		return 0.0
	if t < attack:
		return Tween.interpolate_value(0.0, 1.0, t, attack, Tween.TRANS_QUAD, Tween.EASE_OUT)
	return Tween.interpolate_value(1.0, -1.0, t - attack, release, Tween.TRANS_SINE, Tween.EASE_IN_OUT)
