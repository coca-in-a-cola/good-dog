extends Node3D
## F4 rendering only. No collision, interaction, timers or progression ownership.
const ART = preload("res://scripts/representative_art.gd")
var head: Node3D
var level: Node3D
func _ready() -> void:
	level = get_parent()
	ART.asset(preload("res://assets/models/f4/surveillance_mount.glb"),self,Vector3(2.8,2.98,-22.1),"CCTVMount")
	head = ART.asset(preload("res://assets/models/f4/surveillance_head.glb"),self,Vector3(2.8,2.68,-22.1),"CCTVTrackingHead")
	ART.asset(preload("res://assets/models/f4/pit_lining.glb"),self,level.PIT_CENTER,"OpenPitLining")
	var collar := ART.asset(preload("res://assets/models/f4/collar_hook.glb"),self,Vector3(1.15,.86,-31.7),"EntryCollar")
	collar.rotation.y = -PI/2
	ART.asset(preload("res://assets/models/f4/bowl.glb"),self,Vector3(1.6,0,-32.0),"EntryBowl")
	# Pure black pane/shaft; never receive ambient/fog or appear as grey disks.
	level.get_node("ObservationWindow").material = ART.surface("000000",.8)
	level.get_node("ObservationWindow").material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for mesh in get_node("OpenPitLining").find_children("*","MeshInstance3D"):
		if "shaft" in mesh.name:
			mesh.material_override = ART.surface("000000",.8)
			mesh.material_override.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mesh.material_override.cull_mode = BaseMaterial3D.CULL_DISABLED
		if mesh.name == "Flush pit lip":
			mesh.position.y += .003
	var pit_cap := MeshInstance3D.new()
	pit_cap.name = "PitBottomCap"
	var cap_mesh := CylinderMesh.new()
	cap_mesh.top_radius = 2.0
	cap_mesh.bottom_radius = 2.0
	cap_mesh.height = 0.5
	pit_cap.mesh = cap_mesh
	var cap_mat := ART.surface("000000", 1.0)
	cap_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cap_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	pit_cap.material_override = cap_mat
	pit_cap.position = Vector3(level.PIT_CENTER.x, -18.0, level.PIT_CENTER.z)
	add_child(pit_cap)
	# Suppress only the broad pit flood. Collision and accepted lights elsewhere stay fixed.
	for node in level.get_children():
		if node is OmniLight3D and node.position.distance_to(level.PIT_CENTER+Vector3(0,5,0))<.1:
			node.light_energy = .12
	var spot := SpotLight3D.new()
	spot.name = "NarrowPitLight"
	spot.position = level.PIT_CENTER+Vector3(0,5.8,0)
	spot.rotation.x = -PI/2
	spot.spot_range = 7
	spot.spot_angle = 22
	spot.spot_attenuation = 1.8
	spot.light_energy = 5
	spot.light_color = Color("eefaff")
	spot.shadow_enabled = true
	add_child(spot)
	# Dim cyan threshold pool makes collar and return doorway readable at .45m.
	var cue := OmniLight3D.new()
	cue.name = "EntryCueLight"
	cue.position = Vector3(.7,2.4,-31.8)
	cue.omni_range = 4
	cue.light_energy = .8
	cue.light_color = Color("bfe3ea")
	cue.shadow_enabled = true
	add_child(cue)
	var tiles := ART.surface("bfcdd0",.73)
	const ROUGH_PATH := "res://assets/materials/f4/Tiles004_subtle_roughness.png"
	if ResourceLoader.exists(ROUGH_PATH):
		tiles.roughness_texture = load(ROUGH_PATH)
		tiles.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
		tiles.uv1_triplanar = true
		tiles.uv1_scale = Vector3(1,1,1)
	level.get_node("ObservationFloor").material = tiles
	# Keep accepted sample look unchanged: tile only observation, no global GI/fog switch.
func _process(_delta: float) -> void:
	if is_instance_valid(head) and is_instance_valid(level.player):
		var target: Vector3 = level.player.global_position+Vector3(0,level.player.eye_height_m,0)
		if head.global_position.distance_squared_to(target)>.01:
			head.look_at(target,Vector3.UP)
