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
## Horizontal acceleration/braking; sharpens each step (GDD §6 "inertia drops").
var acceleration_mps2 := 20.0
var footstep_set: StringName = &"heavy_shoes"
## Optional F3 leash: post-move ratchet clamp (LeashConstraint.clamp_position).
var leash: LeashConstraint
## F6 camera layer: trauma shake, FOV punches, roll tilt, leash jolt.
var camera_fx := TraumaCamera.new()

var _bob_phase := 0.0
var _trauma := 0.0
@onready var _shape: CollisionShape3D = $CollisionShape3D


func _ready() -> void:
	super()
	debug = false
	sprint_enabled = false
	jump_velocity = 0.0
	_shape.shape = _shape.shape.duplicate()
	camera_fx.name = "TraumaCamera"
	camera_fx.camera = camera
	camera_fx.base_fov = camera.fov
	add_child(camera_fx)


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
	# Headless DisplayServer cannot capture the cursor. Accept the same motion
	# events there so native physics QA exercises look + raycasts, not teleports.
	if event is InputEventMouseMotion and DisplayServer.get_name() == "headless":
		rotate_y(-event.relative.x * horizontal_mouse_sensitivity)
		head.rotate_x(-event.relative.y * vertical_mouse_sensitivity)
	else:
		super(event)
	head.rotation.x = clampf(head.rotation.x, deg_to_rad(MIN_LOOK_DOWN_DEG), deg_to_rad(max_look_up_deg))


func _physics_process(delta: float) -> void:
	var ov := get_node_or_null(^"/root/Overlay")
	# Narrow movement adapter: vendor computes AND moves internally, so calling
	# super here would overwrite a pre-constrained velocity. Keep vendor untouched.
	if not is_on_floor():
		velocity.y -= gravity * delta
	var input_dir := Vector2.ZERO
	if controls_enabled and (ov == null or not ov.is_input_blocked()):
		input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	var accel: float = 80.0 if direction.is_zero_approx() else acceleration_mps2
	var flat := Vector2(velocity.x, velocity.z).move_toward(Vector2(direction.x, direction.z) * walk_speed, accel * delta)
	velocity.x = flat.x
	velocity.z = flat.y
	if leash != null and leash.active:
		velocity = leash.constrain_velocity(global_position, velocity)
	move_and_slide()
	if leash != null and leash.active:
		var p := leash.clamp_position(global_position)
		if not p.is_equal_approx(global_position):
			global_position = p
	_update_bob(delta)


## Pressure-driven camera trauma (already scaled for reduce_shake by the caller).
## TraumaCamera holds it as the minimum under transient trauma.
func set_shake_trauma(trauma: float) -> void:
	_trauma = clampf(trauma, 0.0, 1.0)
	camera_fx.baseline = _trauma


func get_transform_values() -> Dictionary:
	return {
		eye_height_m = eye_height_m,
		speed_mps = walk_speed,
		acceleration_mps2 = acceleration_mps2,
		fov_deg = camera_fx.base_fov,
		max_look_up_deg = max_look_up_deg,
		bob_hz = bob_hz,
		bob_amplitude_m = bob_amplitude_m,
		mouse_sensitivity_scale = mouse_sensitivity_scale,
		footstep_set = footstep_set,
	}


## Shared adapter used by TransformController (values from TransformStep).
func apply_transform_values(v: Dictionary) -> void:
	walk_speed = v.get(&"speed_mps", walk_speed)
	acceleration_mps2 = v.get(&"acceleration_mps2", acceleration_mps2)
	camera_fx.base_fov = v.get(&"fov_deg", camera_fx.base_fov)
	camera.fov = camera_fx.base_fov + camera_fx.get_fov_offset()
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
