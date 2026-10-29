extends RefCounted
## F4 visual-only consumers: never generates replacement collision geometry.
const STICK := preload("res://assets/models/f4/bent_stick.glb")
const DRESSING := preload("res://assets/models/f4/cell_corridor.glb")
const CIRCLE := preload("res://assets/models/f4/placement_circle.glb")

static func asset(scene: PackedScene, parent: Node3D, at: Vector3, label: String) -> Node3D:
	var node := scene.instantiate() as Node3D
	node.name = label
	parent.add_child(node)
	node.position = at
	return node

static func install(level: Node3D) -> void:
	asset(DRESSING, level, Vector3.ZERO, "RepresentativeDressing")
	# Hide only old rendered shelf/cube. Their accepted CSG collision remains.
	var invisible := StandardMaterial3D.new()
	invisible.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	invisible.albedo_color = Color(1,1,1,0)
	for path in ["Geometry/Cot", "Geometry/ToiletCube"]:
		level.get_node(path).material = invisible
	level.get_node("LampTube").visible = false
	for side in [-1,1]:
		for i in 3:
			var number := Label3D.new()
			number.name = "DoorNumber"
			number.text = "%02d" % (47+i*2+(1 if side>0 else 0))
			number.font = preload("res://addons/command_overlay/assets/fonts/NotoSans-Regular.ttf")
			number.font_size = 64
			number.pixel_size = 0.002
			number.outline_size = 0
			number.modulate = Color("234953")
			number.no_depth_test = false
			level.add_child(number)
			number.position = Vector3(side*1.10,1.82,-4.8-i*3.2)
			number.rotation.y = side*PI/2
	var ring := asset(CIRCLE,level,Vector3(0,0.015,-24.6),"PlacementCircle")
	for child in ring.find_children("*","MeshInstance3D"):
		var material := StandardMaterial3D.new()
		material.albedo_color = Color("27899c")
		material.roughness = 0.75
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		child.material_override = material
	clinical_finish(level)

static func surface(color: String, rough: float, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(color)
	m.roughness = rough
	m.metallic = metal
	return m

static func clinical_finish(level: Node3D) -> void:
	level.get_node("WorldEnvironment").environment.ssao_enabled = true
	level.get_node("WorldEnvironment").environment.ssao_radius = .35
	level.get_node("WorldEnvironment").environment.ssao_intensity = 1.4
	# Keep interactable anchors/colliders fixed; settle only rendered branch meshes.
	for mesh in level.stick.visual.find_children("*","MeshInstance3D"):
		mesh.position.y -= .145
	for mesh in level.place_zone.visual.find_children("*","MeshInstance3D"):
		mesh.position.y -= .085
	for node in level.get_node("Geometry").get_children():
		if node is CSGBox3D and node.name not in ["Cot","ToiletCube"]:
			node.material = surface("eef2f2",.78) if "Floor" not in node.name else surface("bfcdd0",.48)
	for node in level.get_children():
		if node is CSGBox3D and ("Floor" in node.name or "Wall" in node.name or "Ceiling" in node.name or "DoorFrame" in node.name):
			node.material = surface("eef2f2",.78) if "Floor" not in node.name else surface("bfcdd0",.48)
		if node is OmniLight3D:
			node.shadow_enabled = true
			node.shadow_bias = .025
			node.light_color = Color("f4f9ff")
	for mesh in level.get_node("RepresentativeDressing").find_children("*","MeshInstance3D"):
		if "Toilet" in mesh.name or "cistern" in mesh.name:
			if "inset" not in mesh.name: mesh.material_override = surface("f4f8f8",.23)
		elif "Bunk" in mesh.name and "leg" in mesh.name:
			mesh.material_override = surface("67848b",.36,.65)
	for i in 12:
		var decal := Decal.new()
		decal.name = "BloodTrail%d" % i
		decal.texture_albedo = preload("res://assets/models/f4/blood_pool.png")
		decal.size = Vector3(.14+.07*sin(i*1.7),.05,.27+.09*cos(i*.8))
		decal.position = Vector3(sin(i)*.12,.018,-4-i*.4)
		decal.rotation.y = sin(i*2.1)*.8
		decal.albedo_mix = 1.0
		level.add_child(decal)
	# The hard upper-right black wedge was the original observation window.
	# Retain its size/location and describe its perimeter with visible metal reveals.
	for i in 4:
		var frame := MeshInstance3D.new()
		frame.name = "ObservationWindowFrame%d" % i
		var box := BoxMesh.new()
		box.size = Vector3(.10,.08,6.15) if i<2 else Vector3(.10,2.46,.08)
		frame.mesh = box
		frame.material_override = surface("52757e",.34,.55)
		level.add_child(frame)
		frame.position = Vector3(3.92,.31 if i==0 else 2.69,-24.6) if i<2 else Vector3(3.92,1.5,-27.64 if i==2 else -21.56)
