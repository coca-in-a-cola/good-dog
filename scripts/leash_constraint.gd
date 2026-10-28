class_name LeashConstraint
extends Node
## GDD §7 leash: the player may only circle the pit or move toward it.
##
## constrain_velocity() removes the outward radial component (before
## move_and_slide); clamp_position() ratchets max_d = min(max_d, d) and clamps
## the position back onto that circle (after move_and_slide). Horizontal only.
## F3 wires constrain_velocity into the movement step and adds the 60 s
## randomized wall-slide regression; GoodDogPlayer already applies the clamp.

signal leash_pulled(toward_center: Vector3)

const EPSILON := 0.0001

## GDD §7 optional contraction (default off): max_d *= 1 - contraction per rung.
@export var contract_on_rung: bool = false
@export_range(0.0, 0.5, 0.01) var contraction: float = 0.15

var active := false
var center := Vector3.ZERO
var max_d := INF


func activate(p_center: Vector3, start_position: Variant = null) -> void:
	center = p_center
	active = true
	max_d = INF
	if start_position is Vector3:
		max_d = _flat(start_position - center).length()


func deactivate() -> void:
	active = false


func reset() -> void:
	active = false
	center = Vector3.ZERO
	max_d = INF


## Returns velocity without its outward radial part; tangential/inward kept.
func constrain_velocity(position: Vector3, velocity: Vector3) -> Vector3:
	if not active:
		return velocity
	var r := _flat(position - center)
	if r.length() < EPSILON:
		return velocity  # at the centre every direction is "inward"
	r = r.normalized()
	var v_r := velocity.dot(r)
	if v_r <= EPSILON:
		return velocity
	leash_pulled.emit(-r)
	return velocity - r * v_r


## Ratchets and clamps; the horizontal distance to the centre never grows.
func clamp_position(position: Vector3) -> Vector3:
	if not active:
		return position
	var flat := _flat(position - center)
	var d := flat.length()
	max_d = minf(max_d, d)
	if d <= max_d or d < EPSILON:
		return position
	var clamped := flat / d * max_d
	return Vector3(center.x + clamped.x, position.y, center.z + clamped.z)


## Listener for the ladder escalation when contract_on_rung is enabled.
func on_rung(_level: int) -> void:
	if active and contract_on_rung and max_d < INF:
		max_d *= 1.0 - contraction


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)
