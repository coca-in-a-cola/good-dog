extends "res://scripts/level_bark.gd"
## Continuous F3 greybox. Built-in CSG, physics rays, Areas and particles only.
const ITEM := preload("res://scripts/interactables/route_item.gd")
const PIT_CENTER := Vector3(0, 0, -40.6)
var stick: Interactable
var place_zone: Interactable
var pit: Interactable
var leash_ctl: LeashConstraint
var mouth: Node3D
var observation_gate: CSGBox3D
var pit_gate: CSGBox3D
var observer: Node3D
var reveal_left := 0.0
var fall_elapsed := 0.0
var cell_closed := false
var observation_closed := false
var pull_left := 0.0
var audio: LevelAudio

func _ready() -> void:
	super()
	_build_route()
	preload("res://scripts/representative_art.gd").install(self)
	audio = LevelAudio.new()
	audio.name = "LevelAudio"
	add_child(audio)
	audio.bind(self)
	var pp: Node = preload("res://scenes/camera/post_process.tscn").instantiate()
	add_child(pp)
	if pp.has_method(&"bind"):
		pp.bind(self)
	player.interacted.connect(_interact)
	director.bind_interactable(stick)
	director.bind_interactable(place_zone)
	director.bind_interactable(pit)
	director.command_started.connect(_command_started)
	leash_ctl.leash_pulled.connect(func(_toward: Vector3) -> void:
		pressure.nudge()
		pull_left = 0.1)
	director.pressure_changed.connect(leash_ctl.on_rung)

func _command_started(_id: StringName) -> void:
	stick.enabled = director.command.id == &"grab"
	place_zone.enabled = director.command.id == &"place"
	pit.enabled = director.command.id == &"jump"

func _interact() -> void:
	if director.state != CommandDirector.State.WAITING:
		return
	stick.interact()
	place_zone.interact()

func _on_command_completed(id: StringName) -> void:
	super(id)
	# Director emits completed BEFORE transform_requested: defer next order so
	# the old step can never overwrite the new phase's step.
	if id == &"grab":
		mouth.visible = true
		place_zone.carrying = true
		_set_gate(observation_gate, true)
		_next.call_deferred(&"place")
	elif id == &"place":
		mouth.visible = false
		place_zone.carrying = false
		phase = &"after_place"
		observer.visible = true
		reveal_left = 1.0
		_set_gate(pit_gate, true)
	elif id == &"jump":
		phase = &"falling"
		player.controls_enabled = false
		player.leash = null
		leash_ctl.deactivate()
		player.head.rotation.x = deg_to_rad(-20)
		fall_elapsed = 0.0
		GameState.enter_falling()

func _next(id: StringName) -> void:
	if not is_inside_tree() or GameState.state != &"playing":
		return
	phase = id
	director.run(load("res://data/commands/%s.tres" % id))

func _process(delta: float) -> void:
	var before := _last_tick
	super(delta)
	var dt := maxf(_last_tick - before, 0.0) if not get_tree().paused else 0.0
	if phase == &"after_bark" and player.position.z < -3.3:
		_next(&"grab")
	if not cell_closed and player.position.z < -4.0:
		cell_closed = true
		_bars_open_elapsed = -1.0
		bars.position = _bars_closed_pos
	if not observation_closed and player.position.z < -21.5:
		observation_closed = true
		_set_gate(observation_gate, false)
	if phase == &"after_place" and player.position.z < -30.6:
		_set_gate(pit_gate, false)
		transform_ctl.apply_step_index(4)
		leash_ctl.activate(PIT_CENTER, player.global_position)
		_next(&"jump")
	if reveal_left > 0.0:
		reveal_left -= dt
		observer.visible = reveal_left > 0.0
	pull_left = maxf(pull_left - dt, 0.0)
	player.camera.position.z = -pull_left * 0.6
	if phase == &"falling":
		fall_elapsed += dt
		curtain.visible = true
		curtain.color.a = clampf(fall_elapsed / 4.0, 0, 1)
		if fall_elapsed >= 4.0:
			phase = &"finale"
			GameState.enter_finale()

func _material(color: Color, unshaded := false) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	if unshaded:
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return mat

func _box(label: String, at: Vector3, size: Vector3, color := Color("e9eef0"), collision := true) -> CSGBox3D:
	var box := CSGBox3D.new()
	box.name = label
	box.position = at
	box.size = size
	box.material = _material(color)
	box.use_collision = collision
	add_child(box)
	return box

func _area(at: Vector3, size: Vector3) -> Area3D:
	var a := Area3D.new()
	a.position = at
	var c := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	c.shape = shape
	a.add_child(c)
	add_child(a)
	return a

func _set_gate(gate: CSGBox3D, opened: bool) -> void:
	gate.position.y = 5.0 if opened else 1.5

func _item(kind: StringName) -> Interactable:
	var item := ITEM.new()
	item.kind = kind
	item.completion_signal = kind
	item.player = player
	add_child(item)
	return item

func _light(at: Vector3, reach: float) -> void:
	var light := OmniLight3D.new()
	light.position = at
	light.omni_range = reach
	light.light_energy = 2.0
	add_child(light)

func _build_route() -> void:
	# Extend the accepted cell's corridor, removing only its temporary end cap.
	$Geometry/CorridorEnd.free()
	$Geometry/Floor.position.z = -9.0
	$Geometry/Floor.size.z = 23.4
	$Geometry/Ceiling.position.z = -9.0
	$Geometry/Ceiling.size.z = 23.4
	for side in [$Geometry/CorridorLeft, $Geometry/CorridorRight]:
		side.position.z = -11.6
		side.size.z = 18.0
	_box("ObservationFloor", Vector3(0,-0.1,-24.6), Vector3(8,0.2,8))
	_box("ObservationCeiling", Vector3(0,3.1,-24.6), Vector3(8,0.2,8))
	for x in [-4.1,4.1]:
		_box("ObservationWall", Vector3(x,1.5,-24.6), Vector3(0.2,3,8.4))
	for z in [-20.6,-28.6]:
		for x in [-2.65,2.65]:
			_box("DoorFrame", Vector3(x,1.5,z), Vector3(2.7,3,0.2))
	observation_gate = _box("ObservationGate", Vector3(0,1.5,-20.6), Vector3(2.5,3,0.2), Color("555e65"))
	pit_gate = _box("PitGate", Vector3(0,1.5,-28.6), Vector3(2.5,3,0.2), Color("555e65"))
	_box("ConnectorFloor",Vector3(0,-0.1,-29.6),Vector3(2.5,0.2,2.2))
	for x in [-1.35,1.35]:
		_box("ConnectorWall",Vector3(x,1.5,-29.6),Vector3(0.2,3,2.2))
	_box("ConnectorRoof",Vector3(0,3.1,-29.6),Vector3(2.5,0.2,2.2))
	# Annulus assembled as CSG subtraction: no floor collision cap over the hole.
	var floor_root := CSGCombiner3D.new()
	floor_root.name = "PitFloor"
	floor_root.use_collision = true
	add_child(floor_root)
	var disc := CSGCylinder3D.new()
	disc.position = PIT_CENTER + Vector3(0,-0.1,0)
	disc.radius = 12
	disc.height = 0.2
	disc.sides = 96
	disc.material = _material(Color("e9eef0"))
	floor_root.add_child(disc)
	var hole := CSGCylinder3D.new()
	hole.operation = CSGShape3D.OPERATION_SUBTRACTION
	hole.position = PIT_CENTER
	hole.radius = 1.5
	hole.height = 2
	hole.sides = 64
	floor_root.add_child(hole)
	for i in 64:
		var angle := TAU * i / 64.0
		# Leave the north entrance open (connector is a sealed throat).
		if i in [15,16,17]:
			continue
		var wall := _box("PitWall", PIT_CENTER + Vector3(cos(angle)*12,3,sin(angle)*12),Vector3(0.25,6,1.3))
		wall.rotation.y = -angle
	_box("PitRoof", PIT_CENTER + Vector3(0,6.1,0),Vector3(24,0.2,24))
	var black := CSGCylinder3D.new()
	black.position = PIT_CENTER + Vector3(0,-100,0)
	black.radius = 1.5
	black.height = 0.1
	black.material = _material(Color.BLACK,true)
	add_child(black)
	_light(Vector3(0,2.6,-10),12)
	_light(Vector3(0,2.6,-24.6),9)
	_light(PIT_CENTER + Vector3(0,5,0),16)
	stick = _item(&"grabbed")
	var body := StaticBody3D.new()
	body.position = Vector3(0,0.16,-9)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.0,0.22,0.22)
	collision.shape = shape
	body.add_child(collision)
	add_child(body)
	stick.target = body
	stick.visual = preload("res://scripts/representative_art.gd").asset(preload("res://assets/models/f4/bent_stick.glb"),self,body.position,"BloodyStick")

	mouth = preload("res://assets/models/f4/bent_stick.glb").instantiate()
	mouth.name = "MouthStick"
	mouth.scale = Vector3.ONE * 0.48
	mouth.position = Vector3(0,-0.24,-0.48)
	mouth.visible = false
	player.camera.add_child(mouth)
	place_zone = _item(&"placed")
	place_zone.area = _area(Vector3(0,0.7,-24.6),Vector3(2.5,1.4,2.5))
	place_zone.visual = preload("res://scripts/representative_art.gd").asset(preload("res://assets/models/f4/bent_stick.glb"),self,Vector3(0,0.1,-24.6),"PlacedStick")
	place_zone.visual.visible = false
	var circle := CSGCylinder3D.new()
	circle.radius = 1.25
	circle.height = 0.008
	circle.position = Vector3(0,0.009,-24.6)
	circle.material = _material(Color("bfe3ea"),true)
	circle.visible = false # Authored annulus, not the old filled greybox disk.
	add_child(circle)
	var spot := SpotLight3D.new()
	spot.position = Vector3(0,2.9,-24.6)
	spot.rotation.x = -PI/2
	spot.spot_range = 4
	spot.spot_angle = 26
	spot.light_energy = 4
	add_child(spot)
	_box("ObservationWindow",Vector3(3.98,1.5,-24.6),Vector3(0.02,2.3,6),Color.BLACK,false)
	observer = Node3D.new()
	add_child(observer)
	for z in [-23.5,-25.5]:
		var silhouette := _box("Observer",Vector3(3.95,1.35,z),Vector3(0.04,1.7,0.5),Color("7fa9b3"),false)
		silhouette.reparent(observer)
	observer.visible = false
	pit = _item(&"pit_entered")
	pit.area = _area(PIT_CENTER + Vector3(0,-2.5,0),Vector3(2.9,1,2.9))
	pit.area.body_entered.connect(pit.body_entered)
	leash_ctl = LeashConstraint.new()
	add_child(leash_ctl)
	player.leash = leash_ctl
