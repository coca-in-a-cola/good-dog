class_name TransformController
extends Node
## Applies GDD §6 TransformStep rows to the player adapter (irreversible).
##
## Blends from the current values to the target row over step.transition_time
## real seconds, shaped by step.transition_curve; control stays with the player.
## The blend pauses with the Esc pause. Never goes back to a lower step.

signal transform_step_changed(step: int)
signal transform_finished(step: int)
signal post_applied(values: Dictionary)

## Rows 0–4 (data/transform/step_N.tres).
@export var steps: Array[TransformStep] = []
## Node implementing apply_transform_values(Dictionary) (GoodDogPlayer).
@export var player: Node

## Defaults to GameState.clock; tests inject a manual clock.
var clock: RealClock
var current_step := 0
var blending := false
var post_values: Dictionary = {}

var _from: Dictionary = {}
var _to: TransformStep
var _blend_elapsed := 0.0
var _last_tick := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if clock == null:
		var gs := get_node_or_null(^"/root/GameState")
		clock = gs.clock if gs != null else RealClock.new()
	_last_tick = clock.now()
	reset()


func _process(_delta: float) -> void:
	tick()


## Snaps to step 0 (fresh run).
func reset() -> void:
	blending = false
	current_step = 0
	if not steps.is_empty():
		post_values = values_of(steps[0])
		_push(values_of(steps[0]))


## Listener for CommandDirector.transform_requested.
func apply_step_index(index: int) -> void:
	if index <= current_step or index >= steps.size():
		return
	apply_step(steps[index])


func apply_step(step: TransformStep) -> void:
	if step == null or step.index <= current_step and not steps.is_empty():
		return
	_from = current_values()
	_to = step
	_blend_elapsed = 0.0
	_last_tick = clock.now()
	current_step = step.index
	blending = step.transition_time > 0.0
	transform_step_changed.emit(step.index)
	if not blending:
		_push(values_of(step))
		transform_finished.emit(step.index)


func current_values() -> Dictionary:
	if player != null and player.has_method(&"get_transform_values"):
		return player.get_transform_values()
	return values_of(steps[current_step]) if current_step < steps.size() else {}


func tick() -> void:
	var now := clock.now()
	var dt := maxf(now - _last_tick, 0.0)
	_last_tick = now
	if not blending or (is_inside_tree() and get_tree().paused):
		return
	_blend_elapsed += dt
	var p := _blend_elapsed / _to.transition_time
	var k := _to.sample_transition(p)
	var target := values_of(_to)
	var mixed := {}
	for key: String in target:
		if target[key] is float:
			mixed[key] = lerpf(_from.get(key, target[key]), target[key], k)
		else:
			mixed[key] = target[key] if k >= 0.5 else _from.get(key, target[key])
	_push(mixed)
	if p >= 1.0:
		blending = false
		_push(target)
		transform_finished.emit(_to.index)


static func values_of(step: TransformStep) -> Dictionary:
	return {
		eye_height_m = step.eye_height_m,
		speed_mps = step.speed_mps,
		fov_deg = step.fov_deg,
		max_look_up_deg = step.max_look_up_deg,
		bob_hz = step.bob_hz,
		bob_amplitude_m = step.bob_amplitude_m,
		mouse_sensitivity_scale = step.mouse_sensitivity_scale,
		footstep_set = step.footstep_set,
		canine_vision_weight = [0.0, 0.1, 0.25, 0.5, 0.8][clampi(step.index, 0, 4)],
		barrel_distortion = [0.0, 0.0, 0.02, 0.06, 0.15][clampi(step.index, 0, 4)],
		vignette = [0.0, 0.02, 0.05, 0.1, 0.15][clampi(step.index, 0, 4)],
		chromatic_aberration = [0.0, 0.0, 0.0, 0.001, 0.002][clampi(step.index, 0, 4)],
		saturation = [1.0, 0.95, 0.9, 0.85, 0.8][clampi(step.index, 0, 4)],
		glow = [0.8, 0.82, 0.86, 0.92, 1.0][clampi(step.index, 0, 4)],
		grain = [0.03, 0.032, 0.035, 0.038, 0.04][clampi(step.index, 0, 4)],
	}


func _push(v: Dictionary) -> void:
	post_values = v
	post_applied.emit(v)
	if player != null and player.has_method(&"apply_transform_values"):
		player.apply_transform_values(v)
