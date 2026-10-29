extends Node
## Compose the accepted route fixture without registering its tests twice.
var failures: Array[String] = []
var assertions := 0
var route: Node
func check(ok: bool, text: String) -> void:
	assertions += 1
	if not ok: failures.append(text)
func before_each() -> void:
	failures.clear()
	assertions = 0
	route = preload("res://tests/test_f3_route.gd").new()
	add_child(route)
	await route.before_each()
func after_each() -> void:
	failures.append_array(route.failures)
	await route.after_each()
	route.queue_free()
	await get_tree().process_frame
func test_blender_imports_and_visual_only_dressing() -> void:
	await route.start()
	var level: Node = route.level
	var art: Node3D = level.get_node("RepresentativeDressing")
	check(art.find_children("*", "MeshInstance3D").size()>50,"real imported dressing meshes")
	check(art.find_children("*", "CollisionObject3D").is_empty(),"no imported collision objects")
	check(level.mouth.find_children("*","MeshInstance3D").size()==1,"carry is connected authored branch GLB")
	check(level.find_children("BloodTrail*","Decal",true,false).size()==12,"flat authored stain decals")
	check(level.find_children("BloodTrail*","CSGBox3D").is_empty(),"no extruded blood tiles")
	check(level.find_children("ObservationWindowFrame*","MeshInstance3D",true,false).size()==4,"observation window retained with explicit frame")
	check(level.stick.target.get_child(0).shape.size == Vector3(1,0.22,0.22),"accepted pickup shape unchanged")
	check(level.get_node("PlacementCircle").position == Vector3(0,0.015,-24.6),"ring exact center")
	check(level.place_zone.area.get_child(0).shape.size == Vector3(2.5,1.4,2.5),"accepted placement broad phase unchanged")
	check(level.get_node("Geometry/Cot").size == Vector3(.9,.12,2),"accepted cot collider dimensions unchanged")
	check(level.stick.visual.position == Vector3(0,.16,-9),"stick original world anchor")
	await route.grab()
	check(level.mouth.visible and not level.stick.visual.visible,"real grab owns authored visibility")
	await route.place()
	check(not level.mouth.visible and level.place_zone.visual.visible,"real place owns authored visibility")
