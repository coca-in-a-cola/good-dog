class_name TransformStep
extends Resource
## One row of the GDD §6 transformation table. Stored as data/transform/step_N.tres.

@export_range(0, 4) var index: int = 0
@export_range(0.2, 2.0, 0.01, "suffix:m") var eye_height_m: float = 1.70
@export_range(0.5, 10.0, 0.1, "suffix:m/s") var speed_mps: float = 3.0
@export_range(40.0, 120.0, 0.5, "suffix:°") var fov_deg: float = 75.0
@export_range(0.0, 89.0, 0.5, "suffix:°") var max_look_up_deg: float = 89.0
## Head-bob frequency while walking (1.8 Hz at step 0 → 3.2 Hz at step 4).
@export_range(0.0, 6.0, 0.05, "suffix:Hz") var bob_hz: float = 1.8
## Vertical bob amplitude; falls each step so the gait becomes a scurry.
@export_range(0.0, 0.2, 0.001, "suffix:m") var bob_amplitude_m: float = 0.05
## Mouse sensitivity multiplier (+10% per step).
@export_range(0.5, 3.0, 0.01) var mouse_sensitivity_scale: float = 1.0
## Footstep sound set consumed by the F5 audio layer.
@export var footstep_set: StringName = &"heavy_shoes"
@export_range(0.0, 10.0, 0.05, "suffix:s") var transition_time: float = 2.5
## Normalised progress (0..1) → blend (0..1); ease-in-out by default.
@export var transition_curve: Curve
@export var transition_sfx: AudioStream


func sample_transition(progress: float) -> float:
	var p := clampf(progress, 0.0, 1.0)
	if transition_curve == null:
		return Tween.interpolate_value(0.0, 1.0, p, 1.0, Tween.TRANS_SINE, Tween.EASE_IN_OUT)
	return transition_curve.sample_baked(p)
