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
	# Production geometry assertions: corridor bounds, no-overlap cutout, lip offset
	var corridor_floor: CSGBox3D = level.get_node("Geometry/Floor")
	check(is_equal_approx(corridor_floor.position.z, -8.95), "corridor floor position.z is -8.95")
	check(is_equal_approx(corridor_floor.size.z, 23.3), "corridor floor size.z is 23.3")
	check(is_equal_approx(corridor_floor.position.z + corridor_floor.size.z / 2.0, 2.7), "corridor floor near end preserved at 2.7")
	check(is_equal_approx(corridor_floor.position.z - corridor_floor.size.z / 2.0, -20.6), "corridor floor far end meets observation floor at -20.6")
	var pit_floor: CSGCombiner3D = level.get_node("PitFloor")
	var cutout: CSGBox3D = pit_floor.get_node_or_null("ConnectorCutout")
	check(cutout != null, "pit floor connector cutout exists")
	if cutout != null:
		check(cutout.operation == CSGShape3D.OPERATION_SUBTRACTION, "cutout operation is SUBTRACTION")
		check(cutout.position == Vector3(0, -0.1, -29.6), "cutout position matches connector floor")
		check(cutout.size == Vector3(2.5, 0.5, 2.2), "cutout size matches connector floor")
	var lip: MeshInstance3D = level.find_child("Flush pit lip", true, false)
	check(lip != null, "flush pit lip mesh exists")
	if lip != null:
		check(is_equal_approx(lip.position.y, 0.003), "flush pit lip visual offset is +0.003")
		check(lip.find_children("*", "CollisionObject3D").is_empty(), "flush pit lip visual only no colliders")
	var pit_cap: MeshInstance3D = level.find_child("PitBottomCap", true, false)
	check(pit_cap != null, "pit bottom cap preserved")
	check(level.pit.area != null, "pit trigger area preserved")
	await route.grab()
	check(level.mouth.visible and not level.stick.visual.visible,"real grab owns authored visibility")
	await route.place()
	check(not level.mouth.visible and level.place_zone.visual.visible,"real place owns authored visibility")
