class_name Interactable
extends Node3D
## Extension contract for completion sources: stick (grabbed), place zone (placed),
## pit (pit_entered). F3 subclasses implement the gameplay test (aim within 2 m,
## carrying + zone, trigger depth) and call complete() once it passes.
##
## Bind with CommandDirector.bind_interactable(); reset() re-arms for a fresh run.

## Emitted exactly once per arm with `completion_signal`.
signal completed(completion: StringName)

## grabbed | placed | pit_entered
@export var completion_signal: StringName = &""

var done := false


## Emits `completed` (and the named signal if the subclass declares it) once.
func complete() -> bool:
	if done:
		return false
	done = true
	if completion_signal != &"" and has_signal(completion_signal):
		emit_signal(completion_signal)
	completed.emit(completion_signal)
	return true


func reset() -> void:
	done = false
