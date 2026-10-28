class_name RealClock
extends RefCounted
## Real-time source shared by gameplay systems (GameState.clock).
##
## Unaffected by Engine.time_scale and SceneTree.paused. Consumers that must stop
## during the Esc pause skip their own accumulation while the tree is paused.
## Tests and capture set `manual` and drive time with advance().

var manual := false
var _manual_time := 0.0


func now() -> float:
	if manual:
		return _manual_time
	return Time.get_ticks_usec() / 1000000.0


func advance(seconds: float) -> void:
	_manual_time += seconds
