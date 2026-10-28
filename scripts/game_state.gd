extends Node
## Game lifecycle autoload (GameState): warning → menu → playing → failed → menu.
##
## Owns the shared real-time clock, the Esc pause menu (OBEY / RUN AWAY) and the
## failure curtain. Every scene change calls Overlay.force_hide() first and a
## fresh start rebuilds the level, so director, pressure, transformation, player
## and connections never survive a restart. No progress is persisted (GDD §4/§13).
## Later states `falling` and `finale` are reserved for F3.

signal state_changed(state: StringName)

const WARNING_SCENE := "res://scenes/warning.tscn"
const MENU_SCENE := "res://scenes/main_menu.tscn"
const LEVEL_SCENE := "res://scenes/level.tscn"
const FINAL_LINES := ["CONGRATULATIONS!", "YOU WERE A GOOD DOG!"]

## BAD DOG stays on black this long before the silence starts.
@export_range(0.0, 10.0, 0.1, "suffix:s") var bad_dog_hold: float = 2.0
## GDD §4/§10: 3 s of full silence after BAD DOG, then the main menu.
@export_range(0.0, 10.0, 0.1, "suffix:s") var failure_silence: float = 3.0

var clock := RealClock.new()
var state: StringName = &"boot"
var paused := false
var starts := 0

var _fail_at := -1.0
var _pause_layer: CanvasLayer
var _curtain_layer: CanvasLayer
var _obey: Button
var _run_away: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	_adopt_boot_scene.call_deferred()


func _process(_delta: float) -> void:
	if state == &"failed" and _fail_at >= 0.0:
		var t := clock.now() - _fail_at
		if t >= bad_dog_hold:
			_overlay_hide()  # BAD DOG disappears; black silence remains
			AudioServer.set_bus_mute(0, true)
		if t >= bad_dog_hold + failure_silence:
			quit_to_menu()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause") and not event.is_echo():
		if paused:
			resume()
			get_viewport().set_input_as_handled()
		elif request_pause():
			get_viewport().set_input_as_handled()


# --- Lifecycle ----------------------------------------------------------------

func show_warning() -> void:
	_change(WARNING_SCENE, &"warning")


func quit_to_menu() -> void:
	_change(MENU_SCENE, &"menu")


## Fresh run from the beginning (also the restart path).
func start_game() -> void:
	starts += 1
	_change(LEVEL_SCENE, &"playing")


## BAD DOG. Director has already shown the BLACK line; hold, silence, menu.
func fail() -> void:
	if state != &"playing":
		return
	if paused:
		_set_paused(false)
	_curtain_layer.visible = true
	_fail_at = clock.now()
	_set_state(&"failed")


## F3 boundary: pit trigger → 4 s fall → finale scene.
func enter_falling() -> void:
	_set_state(&"falling")


func enter_finale() -> void:
	_set_state(&"finale")


# --- Pause (OBEY / RUN AWAY) --------------------------------------------------

## Refused while the overlay owns pause/time scale (active line or thaw).
func request_pause() -> bool:
	if state != &"playing" or paused:
		return false
	var ov := _overlay()
	if ov != null and ov.is_active():
		return false
	if not is_equal_approx(Engine.time_scale, 1.0):
		return false  # overlay thaw in progress
	_set_paused(true)
	return true


func resume() -> void:
	if paused:
		_set_paused(false)
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func run_away() -> void:
	quit_to_menu()


# --- Internals ----------------------------------------------------------------

func _change(path: String, new_state: StringName) -> void:
	_overlay_hide()
	_set_paused(false)
	_fail_at = -1.0
	_curtain_layer.visible = false
	AudioServer.set_bus_mute(0, false)
	Engine.time_scale = 1.0
	for action in InputMap.get_actions():
		Input.action_release(action)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if new_state == &"playing" else Input.MOUSE_MODE_VISIBLE
	var err := get_tree().change_scene_to_file(path)
	if err != OK:
		push_error("GameState: cannot change scene to %s (%d)" % [path, err])
	_set_state(new_state)


func _adopt_boot_scene() -> void:
	var scene := get_tree().current_scene
	if state == &"boot" and scene != null and scene.scene_file_path == WARNING_SCENE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_set_state(&"warning")


func _set_paused(on: bool) -> void:
	paused = on
	_pause_layer.visible = on
	get_tree().paused = on
	if on:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_obey.grab_focus()


func _set_state(s: StringName) -> void:
	state = s
	state_changed.emit(s)


func _overlay() -> Node:
	return get_node_or_null(^"/root/Overlay")


func _overlay_hide() -> void:
	var ov := _overlay()
	if ov != null:
		ov.force_hide()


func _build_ui() -> void:
	_curtain_layer = CanvasLayer.new()
	_curtain_layer.name = "FailureCurtain"
	_curtain_layer.layer = 99  # under the overlay (100)
	_curtain_layer.visible = false
	var black := ColorRect.new()
	black.color = Color.BLACK
	black.set_anchors_preset(Control.PRESET_FULL_RECT)
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_curtain_layer.add_child(black)
	add_child(_curtain_layer)

	_pause_layer = CanvasLayer.new()
	_pause_layer.name = "PauseMenu"
	_pause_layer.layer = 90
	_pause_layer.visible = false
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.75)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause_layer.add_child(dim)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override(&"separation", 24)
	dim.add_child(box)
	_obey = _menu_button("OBEY", resume)
	_run_away = _menu_button("RUN AWAY", run_away)
	box.add_child(_obey)
	box.add_child(_run_away)
	add_child(_pause_layer)


func _menu_button(text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(360, 72)
	b.add_theme_font_size_override(&"font_size", 40)
	b.pressed.connect(action)
	return b
