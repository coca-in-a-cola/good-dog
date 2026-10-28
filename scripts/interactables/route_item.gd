extends Interactable
## Production completion source. Eligibility is supplied by the level's phase;
## spatial eligibility comes from the physics world, never a driver notification.
var enabled := false
var carrying := false
var kind: StringName
var player: GoodDogPlayer
var area: Area3D
var target: StaticBody3D
var visual: Node3D

func interact() -> void:
	if not enabled or done or player == null:
		return
	if kind == &"grabbed":
		var camera := player.camera
		var origin := camera.global_position
		var query := PhysicsRayQueryParameters3D.create(origin, origin - camera.global_basis.z * 2.0)
		query.exclude = [player.get_rid()]
		var hit := player.get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty() or hit.collider != target:
			print("F3_RAY_MISS origin=", origin, " direction=", -camera.global_basis.z, " hit=", hit)
			return
		visual.visible = false
		target.collision_layer = 0
	elif kind == &"placed":
		if not carrying or area == null or not area.overlaps_body(player):
			return
		# The Area is only broad phase: eligibility uses the player's horizontal
		# origin against the visible mark, not capsule overlap with its square.
		var offset := player.global_position - visual.global_position
		if Vector2(offset.x, offset.z).length_squared() > 1.25 * 1.25:
			return
		visual.visible = true
	else:
		return
	complete()

func body_entered(body: Node3D) -> void:
	if enabled and not done and body == player and kind == &"pit_entered":
		complete()
