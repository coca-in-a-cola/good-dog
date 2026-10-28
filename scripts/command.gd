class_name Command
extends Resource
## One order of the escalation ladder (GDD §4). Stored as data/commands/*.tres.

@export var id: StringName = &""
## Rung-1 order (BLACK for BARK, OVER_WORLD otherwise).
@export var order_line: OverlayLine
## Bottom-of-screen tutorial hint, shown while WAITING until completion.
@export var hint_text: String = ""
## Real seconds per rung. Expiry of the last rung is failure (no extra rung).
@export var ladder := PackedFloat32Array([20, 10, 5, 3, 2, 1])
## Re-shown orders for rungs 2..N: index 0 = rung 2. Missing entries reuse order_line.
@export var escalation_lines: Array[OverlayLine] = []
@export var success_line: OverlayLine
## TransformStep index applied after the praise is dismissed; -1 = none.
@export_range(-1, 4) var transform_step: int = -1
## Completion that satisfies this order: barked | grabbed | placed | pit_entered.
@export var completion_signal: StringName = &""


## Line shown when rung `rung` (0-based) begins.
func line_for_rung(rung: int) -> OverlayLine:
	if rung > 0 and rung - 1 < escalation_lines.size() and escalation_lines[rung - 1] != null:
		return escalation_lines[rung - 1]
	return order_line
