class_name Player # setting a class name makes it easier to pull references of the player from other scripts and nodes
extends CharacterBody3D

# movement variables
@export_group("Movement")
@export var walk_speed: float = 5.0
@export var jump_velocity: float = 4.5
@export var sprint_enabled := true
@export var sprint_speed := 7.5

# sensitivity
@export_group("Sensitivity")
@export var horizontal_mouse_sensitivity: float = 0.003
@export var vertical_mouse_sensitivity: float = 0.003

# extras
@export_group("") # no group
@export var debug := true

@onready var head: Node3D = $Head # direct child so using $ is okay
@onready var camera: Camera3D = %Camera3D # usually use unique name (%) unless the node is a direct child
@onready var info_label: RichTextLabel = %InfoLabel

# a universal gravity value set in settings: Project -> Project Settings -> General -> Physics -> 3D -> Default Gravity
# normally set to 9.8, the realistic value
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

func _ready() -> void:
	# set the mouse to be hidden when opened
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
	# handle mouse states
	if event is InputEventMouseButton:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED # make mouse hidden
	elif event.is_action_pressed("ui_cancel"): # "ui_cancel" is a default input for escape (esc)
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE # show mouse

	# handle look
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED: # ensure that the mouse is hidden
		# rotate entire body horizontally (along the y-axis)
		rotate_y(-event.relative.x * horizontal_mouse_sensitivity) # rotate the entire player and its children, not just the camera
		
		# rotate head vertically (along the x-axis)
		head.rotate_x(-event.relative.y * vertical_mouse_sensitivity)
		# clamp, or limit, head rotation so player cannot look too far up or down
		head.rotation.x = clampf(head.rotation.x, deg_to_rad(-90.0), deg_to_rad(90.0))

func _physics_process(delta: float) -> void:
	# only apply gravity if in the air, or not on the floor
	if not is_on_floor():
		velocity.y -= gravity * delta

	# handle jump (set as space in Input Map, also known as "ui_accept")
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y += jump_velocity

	# get a 2d input vector
	var input_vector := Input.get_vector(
		"move_left",     # set as A in Input Map
		"move_right",    # set as D in Input Map
		"move_forward",  # set as W in Input Map
		"move_backward", # set as S in Input Map
	)

	# take the 2d input vector and turn it into a 3d direction
	var direction := (transform.basis * Vector3(input_vector.x, 0.0, input_vector.y)).normalized()

	# decide the movement speed; walk or sprint
	var current_speed := sprint_speed if sprint_enabled and Input.is_action_pressed("sprint") else walk_speed

	# apply direction * speed to the relevant parts of velocity (x, z) if there is a direction
	# if no direction, stop moving; set horizontal velocity (x, z) to 0
	if direction:
		velocity.x = direction.x * current_speed
		velocity.z = direction.z * current_speed
	else:
		velocity.x = 0.0
		velocity.z = 0.0
		
	# required for velocity to take effect
	move_and_slide()
	
	# update info label
	info_label.visible = debug
	if debug:
		info_label.text = (
			"fps: " + str(Engine.get_frames_per_second()) + "\n"
			+ "grounded: " + str(is_on_floor()) + "\n"
			+ "sprinting: " + str(sprint_enabled and Input.is_action_pressed("sprint")) + "\n"
			+ "speed: " + str(snapped(Vector2(velocity.x, velocity.z).length(), 0.01)) + "\n"
			+ "vel: " + str(velocity.snapped(Vector3(0.01, 0.01, 0.01))) + "\n"
			+ "pos: " + str(global_position.snapped(Vector3(0.01, 0.01, 0.01))) + "\n"
			+ "look: " + str(snapped(rad_to_deg(rotation.y), 0.1)) + ", " + str(snapped(rad_to_deg(head.rotation.x), 0.1)) + "\n"
			+ "input: " + str(input_vector.snapped(Vector2(0.01, 0.01)))
		)
