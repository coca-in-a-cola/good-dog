class_name GoodDogPlayer
extends Player
## GOOD DOG adapter over the vendored ar-bh Basic FPS Controller (MIT, unmodified).
##
## Inherits instead of patching (GDD §6). Jump and sprint are disabled (the
## `jump`/`sprint` actions exist with no key, jump_velocity = 0). Gameplay input
## is event-driven: bark/interact come from _unhandled_input (key echo ignored),
## so the overlay's dismissal press never reaches them. The base movement poll
## runs only while `not Overlay.is_input_blocked()`.

signal barked
signal interacted
## Footstep every half bob cycle; F5 audio picks sounds by footstep_set.
signal footstep(footstep_set: StringName)

const MIN_LOOK_DOWN_DEG := -89.0
const CAPSULE_RADIUS := 0.3
const HEAD_CLEARANCE := 0.1

@export var controls_enabled: bool = true
@export var base_mouse_sensitivity: float = 0.003

var eye_height_m := 1.70
var max_look_up_deg := 89.0
var bob_hz := 1.8
var bob_amplitude_m := 0.05
var mouse_sensitivity_scale := 1.0
var footstep_set: StringName = &"heavy_shoes"
## Optional F3 leash: post-move ratchet clamp (LeashConstraint.clamp_position).
var leash: LeashConstraint

var _bob_phase := 0.0
var _trauma := 0.0
var _noise := FastNoiseLite.new()
var _noise_t := 0.0
@onready var _shape: CollisionShape3D = $CollisionShape3D


func _ready() -> void:
	super()
	debug = false
	sprint_enabled = false
	jump_velocity = 0.0
	_noise.seed = 46
	_noise.frequency = 2.0


func _unhandled_input(event: InputEvent) -> void:
	if not controls_enabled:
		return
	if event.is_action_pressed(&"bark") and not event.is_echo():
		barked.emit()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(&"interact") and not event.is_echo():
		interacted.emit()
		get_viewport().set_input_as_handled()
		return
	super(event)
	head.rotation.x = clampf(head.rotation.x, deg_to_rad(MIN_LOOK_DOWN_DEG), deg_to_rad(max_look_up_deg))


func _physics_process(delta: float) -> void:
	var ov := get_node_or_null(^"/root/Overlay")
	if controls_enabled and (ov == null or not ov.is_input_blocked()):
		super(delta)
	else:
		if not is_on_floor():
			velocity.y -= gravity * delta
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
	if leash != null and leash.active:
		var p := leash.clamp_position(global_position)
		if not p.is_equal_approx(global_position):
			global_position = p
	_update_bob(delta)


func _process(delta: float) -> void:
	_noise_t += delta
	var t := _trauma * _trauma
	camera.h_offset = _noise.get_noise_2d(_noise_t * 10.0, 0.0) * 0.06 * t
	camera.v_offset = _noise.get_noise_2d(0.0, _noise_t * 10.0) * 0.06 * t


## Pressure-driven camera trauma (already scaled for reduce_shake by the caller).
func set_shake_trauma(trauma: float) -> void:
	_trauma = clampf(trauma, 0.0, 1.0)


func get_transform_values() -> Dictionary:
	return {
		eye_height_m = eye_height_m,
		speed_mps = walk_speed,
		fov_deg = camera.fov,
		max_look_up_deg = max_look_up_deg,
		bob_hz = bob_hz,
		bob_amplitude_m = bob_amplitude_m,
		mouse_sensitivity_scale = mouse_sensitivity_scale,
		footstep_set = footstep_set,
	}


## Shared adapter used by TransformController (values from TransformStep).
func apply_transform_values(v: Dictionary) -> void:
	walk_speed = v.get(&"speed_mps", walk_speed)
	camera.fov = v.get(&"fov_deg", camera.fov)
	max_look_up_deg = v.get(&"max_look_up_deg", max_look_up_deg)
	bob_hz = v.get(&"bob_hz", bob_hz)
	bob_amplitude_m = v.get(&"bob_amplitude_m", bob_amplitude_m)
	mouse_sensitivity_scale = v.get(&"mouse_sensitivity_scale", mouse_sensitivity_scale)
	footstep_set = v.get(&"footstep_set", footstep_set)
	horizontal_mouse_sensitivity = base_mouse_sensitivity * mouse_sensitivity_scale
	vertical_mouse_sensitivity = base_mouse_sensitivity * mouse_sensitivity_scale
	head.rotation.x = minf(head.rotation.x, deg_to_rad(max_look_up_deg))
	set_eye_height(v.get(&"eye_height_m", eye_height_m))


## Moves the head and resizes the capsule; growing is refused if test_move collides.
func set_eye_height(h: float) -> void:
	var capsule := _shape.shape as CapsuleShape3D
	var new_height := maxf(h + HEAD_CLEARANCE, CAPSULE_RADIUS * 2.0)
	if capsule != null and new_height > capsule.height + 0.001 and is_inside_tree():
		if test_move(global_transform, Vector3.UP * (new_height - capsule.height)):
			return
	eye_height_m = h
	head.position.y = h
	if capsule != null:
		capsule.height = new_height
		_shape.position.y = new_height * 0.5


func _update_bob(delta: float) -> void:
	var moving := Vector2(velocity.x, velocity.z).length() > 0.1 and is_on_floor()
	if moving:
		var half_cycle := floori(_bob_phase / PI)
		_bob_phase += TAU * bob_hz * delta
		if floori(_bob_phase / PI) != half_cycle:
			footstep.emit(footstep_set)
		camera.position.y = sin(_bob_phase) * bob_amplitude_m
	else:
		camera.position.y = lerpf(camera.position.y, 0.0, minf(delta * 10.0, 1.0))
