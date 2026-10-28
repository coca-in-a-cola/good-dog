class_name CommandDirector
extends Node
## Escalation-ladder state machine (GDD §4, §12). Lives on the level scene.
##
## Signal-driven: completions arrive through bind_source()/notify(); the overlay
## reports dismissals. The rung timer is real time, starts only after the
## matching order line is *dismissed* (never on cancelled), and does not run
## while the tree is paused (Esc pause). Nothing is polled per frame except the
## clock.

enum State { IDLE, ORDER_SHOWN, WAITING, SUCCESS, ESCALATE, FAIL }

signal state_changed(state: State)
## Pressure level 0–5 (= ladder rung index; GDD audio table rungs 1–6).
signal pressure_changed(level: int)
signal command_started(id: StringName)
## Emitted the instant a valid completion stops the timer.
signal command_succeeded(id: StringName)
## Emitted after the praise line is dismissed; the next order may follow.
signal command_completed(id: StringName)
## TransformStep index to apply (from Command.transform_step), with command_completed.
signal transform_requested(step: int)
## Tutorial hint text; "" hides it.
signal hint_changed(text: String)
signal quiet_issued
signal failed

## FLASH "QUIET." for an off-order bark (no timer penalty).
@export var quiet_line: OverlayLine
## BLACK "BAD DOG." after the last rung expires.
@export var bad_dog_line: OverlayLine
## Real seconds after entering WAITING before the hint appears.
@export_range(0.0, 10.0, 0.05, "suffix:s") var hint_delay: float = 0.0
## Off-order barks while no order is pending (IDLE between orders) also get QUIET.
@export var quiet_when_idle: bool = true

## Defaults to the Overlay autoload; tests inject an instance.
var overlay: Node
## Defaults to GameState.clock; tests inject a manual clock.
var clock: RealClock

var state: State = State.IDLE
var command: Command
var rung := -1
var generation := 0

var _elapsed := 0.0
var _last_tick := 0.0
var _hint_pending := false
var _hint_elapsed := 0.0
var _awaiting_id: StringName = &""
var _showing := false
var _own_line := false
var _sources: Array[Dictionary] = []
## Bumped only by stop(): late emissions from unbound sources are ignored.
var _bind_epoch := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if overlay == null:
		overlay = get_node_or_null(^"/root/Overlay")
	if clock == null:
		var gs := get_node_or_null(^"/root/GameState")
		clock = gs.clock if gs != null else RealClock.new()
	if overlay != null:
		overlay.shown.connect(_on_shown)
		overlay.dismissed.connect(_on_dismissed)
		overlay.cancelled.connect(_on_cancelled)
	_last_tick = clock.now()


func _exit_tree() -> void:
	stop()
	if overlay != null and is_instance_valid(overlay):
		for pair in [[overlay.shown, _on_shown], [overlay.dismissed, _on_dismissed],
				[overlay.cancelled, _on_cancelled]]:
			if (pair[0] as Signal).is_connected(pair[1]):
				(pair[0] as Signal).disconnect(pair[1])


func _process(_delta: float) -> void:
	tick()


# --- Public API ---------------------------------------------------------------

## Shows the command's order; the ladder restarts at rung 0 (20 s).
func run(p_command: Command) -> void:
	if p_command == null or p_command.ladder.is_empty():
		push_error("CommandDirector.run: invalid command")
		return
	generation += 1
	command = p_command
	command_started.emit(command.id)
	_enter_rung(0)


## Completion from the player or an interactable (barked, grabbed, placed, pit_entered).
func notify(completion: StringName) -> void:
	if state == State.WAITING and command != null and completion == command.completion_signal:
		_succeed()
	elif completion == &"barked" and (state == State.WAITING or (state == State.IDLE and quiet_when_idle)):
		_quiet()
	# ORDER_SHOWN / ESCALATE / SUCCESS / FAIL: stale or duplicate, ignored.


## Connects `source.signal_name` as completion `completion`. reset()/stop() disconnects.
func bind_source(source: Object, signal_name: StringName, completion: StringName = &"") -> void:
	var c := completion if completion != &"" else signal_name
	var epoch := _bind_epoch
	var callable := func(_a = null, _b = null) -> void:
		if epoch == _bind_epoch:
			notify(c)
	source.connect(signal_name, callable)
	_sources.append({source = weakref(source), signal_name = signal_name, callable = callable})


## Binds an Interactable's `completed` signal.
func bind_interactable(item: Interactable) -> void:
	var epoch := _bind_epoch
	var callable := func(completion: StringName) -> void:
		if epoch == _bind_epoch:
			notify(completion)
	item.completed.connect(callable)
	_sources.append({source = weakref(item), signal_name = &"completed", callable = callable})


## Stops the timer, drops the command and disconnects every bound source.
func stop() -> void:
	generation += 1
	_bind_epoch += 1
	for s in _sources:
		var src: Object = s.source.get_ref()
		if src != null and src.is_connected(s.signal_name, s.callable):
			src.disconnect(s.signal_name, s.callable)
	_sources.clear()
	command = null
	rung = -1
	_elapsed = 0.0
	_hint_pending = false
	_own_line = false
	_awaiting_id = &""
	if state != State.IDLE:
		_set_state(State.IDLE)
	hint_changed.emit("")


func get_remaining() -> float:
	if command == null or rung < 0:
		return 0.0
	return maxf(command.ladder[rung] - _elapsed, 0.0)


func is_timer_running() -> bool:
	return state == State.WAITING and not _clock_paused()


func tick() -> void:
	var now := clock.now()
	var dt := maxf(now - _last_tick, 0.0)
	_last_tick = now
	if state != State.WAITING or _clock_paused():
		return
	if _hint_pending:
		_hint_elapsed += dt
		if _hint_elapsed >= hint_delay:
			_hint_pending = false
			hint_changed.emit(command.hint_text)
	_elapsed += dt
	if _elapsed >= command.ladder[rung]:
		_expire()


# --- Transitions --------------------------------------------------------------

func _enter_rung(r: int) -> void:
	rung = r
	_elapsed = 0.0
	pressure_changed.emit(rung)
	_show_owned(command.line_for_rung(rung))


func _show_owned(line: OverlayLine) -> void:
	_set_state(State.ORDER_SHOWN)
	_awaiting_id = line.get_line_id()
	_own_line = false
	_showing = true
	overlay.show_line(line)
	_showing = false


func _expire() -> void:
	if rung >= command.ladder.size() - 1:
		_fail()
		return
	_set_state(State.ESCALATE)
	_enter_rung(rung + 1)


func _succeed() -> void:
	var done := command
	_set_state(State.SUCCESS)
	_hint_pending = false
	hint_changed.emit("")
	pressure_changed.emit(0)
	command_succeeded.emit(done.id)
	if done.success_line != null:
		_awaiting_id = done.success_line.get_line_id()
		_own_line = false
		_showing = true
		overlay.show_line(done.success_line)
		_showing = false
	else:
		_finish_success()


func _finish_success() -> void:
	var done := command
	command = null
	rung = -1
	_set_state(State.IDLE)
	command_completed.emit(done.id)
	if done.transform_step >= 0:
		transform_requested.emit(done.transform_step)


func _fail() -> void:
	_set_state(State.FAIL)
	_hint_pending = false
	hint_changed.emit("")
	if bad_dog_line != null:
		_own_line = false
		overlay.show_line(bad_dog_line)
	failed.emit()


func _quiet() -> void:
	quiet_issued.emit()
	if quiet_line != null:
		overlay.show_line(quiet_line)


func _set_state(s: State) -> void:
	state = s
	state_changed.emit(s)


func _clock_paused() -> bool:
	return is_inside_tree() and get_tree().paused


# --- Overlay signals ----------------------------------------------------------

func _on_shown(_id: StringName) -> void:
	# Any line shown outside our own show_line() call replaced ours.
	_own_line = _showing


func _on_cancelled(id: StringName) -> void:
	if id == _awaiting_id:
		_own_line = false  # interrupted: never starts the rung timer


func _on_dismissed(id: StringName) -> void:
	if not _own_line or id != _awaiting_id:
		return
	_own_line = false
	if state == State.ORDER_SHOWN:
		_elapsed = 0.0
		_last_tick = clock.now()
		_set_state(State.WAITING)
		if rung == 0:
			_hint_pending = true
			_hint_elapsed = 0.0
			if hint_delay <= 0.0:
				_hint_pending = false
				hint_changed.emit(command.hint_text)
	elif state == State.SUCCESS:
		_finish_success()
