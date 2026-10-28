extends Node3D
## F2 greybox BARK cell: 3 s prologue → BARK ladder → GOOD. DOG. → transformation 1.
##
## Integrates the production systems only through their signals; the geometry
## is CSG blockout (GDD §8 cell 4 × 5 × 3 m, bars that slide open on success).
## GRAB/PLACE/JUMP rooms are F3.

const PROLOGUE_SECONDS := 3.0
const BARK_COMMAND := preload("res://data/commands/bark.tres")

@export var bars_open_offset := Vector3(1.6, 0, 0)

var clock: RealClock
var phase: StringName = &"prologue"

var _prologue_elapsed := 0.0
var _last_tick := 0.0
var _bars_open_elapsed := -1.0
var _bars_closed_pos := Vector3.ZERO

@onready var director: CommandDirector = $CommandDirector
@onready var pressure: PressureController = $PressureController
@onready var transform_ctl: TransformController = $TransformController
@onready var player: GoodDogPlayer = $Player
@onready var lamp: OmniLight3D = $Lamp
@onready var bars: Node3D = $Bars
@onready var hint_label: Label = $Hud/Hint
@onready var curtain: ColorRect = $Hud/Curtain
@onready var debug_label: Label = $Hud/Debug


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	clock = GameState.clock
	_bars_closed_pos = bars.position
	director.pressure_changed.connect(pressure.set_pressure_level)
	director.transform_requested.connect(transform_ctl.apply_step_index)
	director.hint_changed.connect(_on_hint)
	director.failed.connect(GameState.fail)
	director.command_completed.connect(_on_command_completed)
	director.bind_source(player, &"barked", &"barked")
	player.controls_enabled = false
	hint_label.visible = false
	debug_label.visible = false
	curtain.visible = true
	_last_tick = clock.now()


## Real-time, frozen by the Esc pause (the root runs ALWAYS; the player is PAUSABLE).
func _process(_delta: float) -> void:
	var now := clock.now()
	var dt := maxf(now - _last_tick, 0.0)
	_last_tick = now
	if get_tree().paused:
		dt = 0.0
	if phase == &"prologue":
		_prologue_elapsed += dt
		var t := _prologue_elapsed
		# lights come on with a flicker during the last second
		curtain.visible = t < PROLOGUE_SECONDS - 1.0 or (t < PROLOGUE_SECONDS and fmod(t * 7.0, 1.0) < 0.4)
		if t >= PROLOGUE_SECONDS:
			curtain.visible = false
			phase = &"order"
			player.controls_enabled = true
			director.run(BARK_COMMAND)
	if _bars_open_elapsed >= 0.0:
		_bars_open_elapsed += dt
		bars.position = _bars_closed_pos + bars_open_offset * clampf(_bars_open_elapsed / 1.5, 0.0, 1.0)
	if debug_label.visible:
		debug_label.text = "state %s  rung %d  remaining %.2f s  pressure %d  step %d" % [
				CommandDirector.State.keys()[director.state], director.rung, director.get_remaining(),
				pressure.level, transform_ctl.current_step]


func _unhandled_input(event: InputEvent) -> void:
	if OS.is_debug_build() and event.is_action_pressed(&"debug_hud") and not event.is_echo():
		debug_label.visible = not debug_label.visible


func _on_hint(text: String) -> void:
	hint_label.text = text
	hint_label.visible = not text.is_empty()


func _on_command_completed(id: StringName) -> void:
	if id == &"bark":
		phase = &"after_bark"
		_bars_open_elapsed = 0.0
