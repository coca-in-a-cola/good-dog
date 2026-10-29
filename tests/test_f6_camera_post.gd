extends Node
var failures: Array[String] = []
var assertions := 0

func check(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures.append(message)

func before_each() -> void:
	failures.clear()
	assertions = 0

func after_each() -> void:
	pass

func test_post_process_controller_and_curves() -> void:
	var pp = preload("res://scenes/camera/post_process.tscn").instantiate()
	add_child(pp)
	check(pp != null, "PostProcess instantiates")
	check(pp.layer == 5, "Layer is 5 under HUD and overlay")
	
	# Test base values
	var base = PostProcessController.BASE
	check(base.glow == 0.8, "Base glow is 0.8")
	check(base.vignette == 0.25, "Base vignette is 0.25")
	check(base.aberration == 0.0, "Base aberration is 0.0")
	check(base.grain == 0.03, "Base grain is 0.03")
	check(base.saturation == 1.0, "Base saturation is 1.0")
	
	# Test TransformController post values
	var t_step0 = TransformStep.new(); t_step0.index = 0
	var t_step4 = TransformStep.new(); t_step4.index = 4
	var v0 = TransformController.values_of(t_step0)
	var v4 = TransformController.values_of(t_step4)
	check(v0.canine_vision_weight == 0.0, "Step 0 canine vision is 0.0")
	check(v4.canine_vision_weight == 0.8, "Step 4 canine vision is 0.8")
	check(v0.barrel_distortion == 0.0, "Step 0 barrel is 0.0")
	check(v4.barrel_distortion == 0.15, "Step 4 barrel is 0.15")
	
	# Test TraumaCamera
	var tc = TraumaCamera.new()
	add_child(tc)
	check(tc.trauma == 0.0, "Initial trauma 0")
	tc.punch()
	check(tc._punch_t == 0.0, "Punch event triggered")
	tc.praise()
	check(tc._praise_t == 0.0, "Praise event triggered")
	tc.breath()
	check(tc._breath_t == 0.0, "Breath event triggered")
	tc.jolt(Vector3.FORWARD)
	check(tc._jolt_t == 0.0, "Jolt event triggered")
	
	tc.queue_free()
	pp.queue_free()
