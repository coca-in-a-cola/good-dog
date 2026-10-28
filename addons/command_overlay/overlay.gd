extends CanvasLayer
## Full-screen command text overlay (autoload name: Overlay).
##
## Portable: depends only on Godot built-ins and files inside addons/command_overlay.
## All timings (word interval, input lock, auto-hide, thaw, punch, fade) use real
## time, so they are unaffected by Engine.time_scale and SceneTree.paused.

signal shown(line_id: StringName)
signal dismissed(line_id: StringName)
## Extension: emitted instead of dismissed when a line is interrupted by
## force_hide(), a replacing show_*() call, scene change or the overlay leaving the tree.
signal cancelled(line_id: StringName)
## Extension: emitted for every appearing word (index 0 for whole-line display).
## Camera/post-process systems hook their appearance punch here.
signal word_shown(line_id: StringName, word_index: int, word: String)
## Extension: emitted after the last line of show_sequence() is dismissed.
signal sequence_finished

const Mode := OverlayLine.Mode
const Dismiss := OverlayLine.Dismiss

const SINGLE_WORD_WIDTH := 0.875  # design: one word fills 85–90% of the width
const MAX_LINE_WIDTH := 0.9       # design: each phrase line at most 90% of the width
const MAX_TEXT_HEIGHT := 0.8      # safety cap for very wide aspect ratios
const MAX_LINES := 3
const MIN_FONT_SIZE := 8
const MAX_FONT_SIZE := 1024
const PUNCH_TIME := 0.08
const ABERRATION_TIME := 0.1
const GLOW_PULSE_HZ := 1.5
const GLOW_PULSE_MIN := 0.85
const REDUCED_SHAKE_FACTOR := 0.3
## Bundled Noto Sans Bold (OFL-1.1, see assets/fonts/OFL.txt). Loaded at runtime,
## relative to this script, so a freshly copied addon parses before its first import.
const DEFAULT_FONT_FILE := "assets/fonts/NotoSans-Bold.ttf"
## Bundled camera flash: shutter click + flash whine (CC0, see assets/sfx/PROVENANCE.md).
const DEFAULT_SFX_FILE := "assets/sfx/camera_flash.wav"

## Real seconds for the world to return to its previous time scale after hiding.
@export var unfreeze_time: float = 0.25
## Font used when a line has no font_override. Null loads DEFAULT_FONT_FILE.
@export var default_font: Font
## Fallback appearance sound when a line has no sfx_appear. Null loads DEFAULT_SFX_FILE.
@export var default_sfx_appear: AudioStream
@export var sfx_bus: StringName = &"Master"
## Accessibility: removes the white appearance frame and the aberration burst.
@export var reduce_flashes: bool = false
## Accessibility: scales jitter to REDUCED_SHAKE_FACTOR (30%).
@export var reduce_shake: bool = false
@export var aberration_strength: float = 0.012
@export var glow_radius_px: float = 18.0
## Cancel (and restore pause/time scale) when SceneTree changes the current scene.
@export var cancel_on_scene_change: bool = true
## Tests: when true, time only advances through advance_clock().
var use_manual_clock: bool = false
## Number of appearance sounds started (diagnostics/tests).
var appear_sfx_count: int = 0

var _line: OverlayLine
var _queue: Array[OverlayLine] = []
var _in_sequence := false
var _active := false
var _generation := 0
var _words := PackedStringArray()
var _word_index := -1
var _line_start := 0.0
var _last_word_at := 0.0

var _frozen := false
var _saved_paused := false
var _saved_time_scale := 1.0
var _thaw_start := -1.0
var _thaw_from := 1.0

var _fade_start := -1.0
var _fade_time := 0.0
var _flash_frame := -1
var _manual_time := 0.0
var _swallow_process_frame := -1
var _swallow_physics_frame := -1
var _glow_intensity := 1.0
var _rng := RandomNumberGenerator.new()

var _root: Control
var _backdrop: ColorRect
var _world_tint: ColorRect
var _text_root: Control
var _glow_group: CanvasGroup
var _glow_label: Label
var _label: Label
var _flash: ColorRect
var _aberration: ColorRect
var _sfx: AudioStreamPlayer
var _label_settings := LabelSettings.new()
var _glow_settings := LabelSettings.new()


func _init() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.seed = 4242
	default_font = _addon_resource(DEFAULT_FONT_FILE)
	default_sfx_appear = _addon_resource(DEFAULT_SFX_FILE)
	_build()
	_set_visuals_visible(false)


func _ready() -> void:
	get_viewport().size_changed.connect(_on_viewport_resized)
	if get_tree().has_signal(&"scene_changed"):
		get_tree().connect(&"scene_changed", _on_scene_changed)


func _exit_tree() -> void:
	if _active:
		_cancel_active()
	_restore_world_now()
	_sfx.stop()  # otherwise AudioServer keeps the playback alive past the overlay


# --- Public API ---------------------------------------------------------------

## Shows one line. Replaces (cancels) any active line. Await `dismissed` to wait.
func show_line(line: OverlayLine) -> void:
	if line == null:
		push_error("Overlay.show_line: line is null")
		return
	_cancel_active()
	_queue.clear()
	_in_sequence = false
	_begin(line)


func show_text(text: String, mode: OverlayLine.Mode = OverlayLine.Mode.OVER_WORLD) -> void:
	show_line(OverlayLine.make(text, mode))


## Shows lines back to back; the world stays frozen between consecutive modal lines.
func show_sequence(lines: Array[OverlayLine]) -> void:
	var valid: Array[OverlayLine] = []
	for line in lines:
		if line != null:
			valid.append(line)
	if valid.is_empty():
		return
	_cancel_active()
	_queue = valid.slice(1)
	_in_sequence = true
	_begin(valid[0])


func is_active() -> bool:
	return _active


## Hides immediately, drops the queue and restores pause/time scale without thaw.
func force_hide() -> void:
	_queue.clear()
	_in_sequence = false
	_cancel_active()
	_fade_start = -1.0
	_set_visuals_visible(false)
	_restore_world_now()


## Guard for gameplay code that POLLS Input: true while a modal line is up and
## for the rest of the frame (process and next physics tick) in which the overlay
## swallowed a press. Godot keeps is_action_just_pressed() true for the whole
## frame of a press even after Input.action_release(), so pollers must check this.
## Event-driven code (_unhandled_input) is protected without it.
func is_input_blocked() -> bool:
	if _active and _line.mode != Mode.FLASH:
		return true
	if Engine.is_in_physics_frame():
		return Engine.get_physics_frames() <= _swallow_physics_frame
	return Engine.get_process_frames() <= _swallow_process_frame


func get_current_line() -> OverlayLine:
	return _line if _active else null


func get_displayed_text() -> String:
	return _label.text


func get_font_size() -> int:
	return _label_settings.font_size


func get_glow_intensity() -> float:
	return _glow_intensity


## Tests: advances the manual clock and runs one update.
func advance_clock(seconds: float) -> void:
	_manual_time += seconds
	_tick()


# --- Lifecycle ----------------------------------------------------------------

func _process(_delta: float) -> void:
	if not use_manual_clock:
		_tick()


func _now() -> float:
	if use_manual_clock:
		return _manual_time
	return Time.get_ticks_usec() / 1000000.0


func _begin(line: OverlayLine) -> void:
	_generation += 1
	var gen := _generation
	_line = line
	_active = true
	_words = line.get_words()
	if _words.is_empty():
		_words = PackedStringArray([""])
	_word_index = -1
	_line_start = _now()
	_fade_start = -1.0
	_root.modulate.a = 1.0
	if line.mode == Mode.FLASH:
		_start_thaw()
	else:
		_freeze(line)
	_backdrop.visible = line.mode == Mode.BLACK
	_world_tint.visible = line.mode == Mode.OVER_WORLD
	_text_root.visible = true
	_root.visible = true
	_apply_colors(line)
	shown.emit(line.get_line_id())
	if gen != _generation:
		return
	_show_word(0)


func _show_word(index: int) -> void:
	_word_index = index
	_last_word_at = _line_start + index * _line.word_interval if index > 0 else _line_start
	var word := _words[index]
	_set_text(word)
	_text_root.scale = Vector2.ONE * _line.punch_scale
	if not reduce_flashes:
		_flash.visible = true
		_flash_frame = Engine.get_process_frames()
		_aberration.visible = true
		_set_aberration(aberration_strength)
	var stream := _line.sfx_appear if _line.sfx_appear != null else default_sfx_appear
	if stream != null:
		_sfx.bus = sfx_bus
		_sfx.stream = stream
		_sfx.play()
		appear_sfx_count += 1
	word_shown.emit(_line.get_line_id(), index, word)


func _tick() -> void:
	var now := _now()
	if _active:
		var gen := _generation
		while _active and gen == _generation and _word_index < _words.size() - 1 \
				and now >= _line_start + (_word_index + 1) * _line.word_interval:
			_show_word(_word_index + 1)
		if _active and gen == _generation and _line.hides_automatically() \
				and _word_index == _words.size() - 1 \
				and now >= _last_word_at + _line.auto_hide_after:
			_dismiss_current()
	_update_visuals(now)
	_update_thaw(now)


func _update_visuals(now: float) -> void:
	if _flash.visible and Engine.get_process_frames() > _flash_frame:
		_flash.visible = false
	if _aberration.visible:
		var k := (now - _last_word_at) / ABERRATION_TIME
		if k >= 1.0 or reduce_flashes:
			_aberration.visible = false
		else:
			_set_aberration(aberration_strength * (1.0 - k))
	if _fade_start >= 0.0:
		var f := (now - _fade_start) / maxf(_fade_time, 0.0001)
		if f >= 1.0:
			_fade_start = -1.0
			_set_visuals_visible(false)
		else:
			_root.modulate.a = 1.0 - f
	if not _active:
		return
	var t := minf(now - _last_word_at, PUNCH_TIME)
	var s: float = Tween.interpolate_value(_line.punch_scale, 1.0 - _line.punch_scale, t, PUNCH_TIME,
			Tween.TRANS_QUAD, Tween.EASE_OUT)
	_text_root.scale = Vector2.ONE * s
	var jitter := _line.jitter_px * (REDUCED_SHAKE_FACTOR if reduce_shake else 1.0)
	_text_root.position = Vector2(_rng.randf_range(-jitter, jitter), _rng.randf_range(-jitter, jitter))
	var pulse := 0.5 + 0.5 * sin(TAU * GLOW_PULSE_HZ * (now - _line_start))
	_glow_intensity = lerpf(GLOW_PULSE_MIN, 1.0, pulse)
	(_glow_group.material as ShaderMaterial).set_shader_parameter(&"intensity", _glow_intensity)


# --- Input --------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if not _active or _line.mode == Mode.FLASH:
		return
	if _is_release(event):
		return  # Releases pass through so held-key state never gets stuck.
	get_viewport().set_input_as_handled()
	if not _is_fresh_press(event):
		return
	_swallow_process_frame = Engine.get_process_frames()
	_swallow_physics_frame = Engine.get_physics_frames() + 1
	_release_matching_actions(event)
	if _line.waits_for_key() and _can_dismiss_by_input():
		_dismiss_current()


func _can_dismiss_by_input() -> bool:
	return _word_index == _words.size() - 1 and _now() - _last_word_at >= _line.min_lock_time


static func _is_fresh_press(event: InputEvent) -> bool:
	if event is InputEventKey:
		return event.pressed and not event.echo
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		return mb.pressed and mb.button_index not in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN,
				MOUSE_BUTTON_WHEEL_LEFT, MOUSE_BUTTON_WHEEL_RIGHT]
	if event is InputEventJoypadButton:
		return event.pressed
	if event is InputEventScreenTouch:
		return event.pressed
	return false


static func _is_release(event: InputEvent) -> bool:
	if event is InputEventKey or event is InputEventMouseButton \
			or event is InputEventJoypadButton or event is InputEventScreenTouch:
		return not event.is_pressed()
	return false


## Clears Input singleton state for actions the swallowed press maps to, so game
## code polling Input.is_action_just_pressed() cannot see it either.
func _release_matching_actions(event: InputEvent) -> void:
	for action in InputMap.get_actions():
		if InputMap.event_is_action(event, action):
			Input.action_release(action)


# --- Dismiss / cancel / world state -------------------------------------------

func _dismiss_current() -> void:
	var id := _line.get_line_id()
	if not _queue.is_empty():
		var next: OverlayLine = _queue.pop_front()
		_end_active()
		var gen := _generation
		dismissed.emit(id)
		if gen == _generation:
			_begin(next)
		return
	var fade := _line.hide_fade_time
	var was_sequence := _in_sequence
	_end_active()
	_in_sequence = false
	if fade > 0.0:
		_fade_start = _now()
		_fade_time = fade
	else:
		_set_visuals_visible(false)
	_start_thaw()
	dismissed.emit(id)
	if was_sequence:
		sequence_finished.emit()


func _cancel_active() -> void:
	if not _active:
		return
	var id := _line.get_line_id()
	_end_active()
	_set_visuals_visible(false)
	cancelled.emit(id)


func _end_active() -> void:
	_active = false
	_generation += 1
	_line = null
	_words = PackedStringArray()
	_word_index = -1


func _freeze(line: OverlayLine) -> void:
	if not _frozen:
		_saved_paused = get_tree().paused
		_saved_time_scale = Engine.time_scale
		_frozen = true
	_thaw_start = -1.0
	Engine.time_scale = line.world_time_scale
	get_tree().paused = true if line.mode == Mode.BLACK else _saved_paused


func _start_thaw() -> void:
	if not _frozen or _thaw_start >= 0.0:
		return
	get_tree().paused = _saved_paused
	if unfreeze_time <= 0.0:
		_restore_world_now()
		return
	_thaw_from = Engine.time_scale
	_thaw_start = _now()


func _update_thaw(now: float) -> void:
	if _thaw_start < 0.0:
		return
	var k := clampf((now - _thaw_start) / unfreeze_time, 0.0, 1.0)
	if k >= 1.0:
		_restore_world_now()
		return
	Engine.time_scale = Tween.interpolate_value(_thaw_from, _saved_time_scale - _thaw_from, k, 1.0,
			Tween.TRANS_SINE, Tween.EASE_IN_OUT)


func _restore_world_now() -> void:
	_thaw_start = -1.0
	if not _frozen:
		return
	_frozen = false
	Engine.time_scale = _saved_time_scale
	if is_inside_tree():
		get_tree().paused = _saved_paused


func _on_scene_changed() -> void:
	if cancel_on_scene_change and (_active or _frozen):
		force_hide()


# --- Layout -------------------------------------------------------------------

func _on_viewport_resized() -> void:
	if _active:
		_set_text(_label.text)


func _viewport_size() -> Vector2:
	if is_inside_tree():
		return get_viewport().get_visible_rect().size
	return Vector2(1920, 1080)


func _font() -> Font:
	if _line != null and _line.font_override != null:
		return _line.font_override
	return default_font if default_font != null else ThemeDB.fallback_font


func _set_text(text: String) -> void:
	var font := _font()
	var size := _viewport_size()
	var layout := fit_text(text, font, size)
	var lines: PackedStringArray = layout.lines
	var font_size: int = layout.font_size
	var joined := "\n".join(lines)
	for settings: LabelSettings in [_label_settings, _glow_settings]:
		settings.font = font
		settings.font_size = font_size
	var outline := clampi(roundi(font_size * 0.04), 8, 16)
	_label_settings.outline_size = outline
	_glow_settings.outline_size = outline * 2
	_label.text = joined
	_glow_label.text = joined
	_text_root.pivot_offset = size * 0.5
	_glow_label.size = size  # child of a CanvasGroup (Node2D), so no anchors apply
	(_glow_group.material as ShaderMaterial).set_shader_parameter(&"radius_px", glow_radius_px)


## Chooses up to MAX_LINES contiguous line breaks and the largest font size such
## that one word fills SINGLE_WORD_WIDTH, each line stays within MAX_LINE_WIDTH
## and the block stays within MAX_TEXT_HEIGHT. Returns {lines, font_size}.
static func fit_text(text: String, font: Font, viewport: Vector2) -> Dictionary:
	var words := text.strip_edges().split(" ", false)
	if words.is_empty():
		return {lines = PackedStringArray([""]), font_size = MIN_FONT_SIZE}
	var best_lines := PackedStringArray([" ".join(words)])
	var best_size := -1
	var target := SINGLE_WORD_WIDTH if words.size() == 1 else MAX_LINE_WIDTH
	for candidate in _line_partitions(words):
		var s := _fit_size(candidate, font, viewport, target)
		if s > best_size:
			best_size = s
			best_lines = candidate
	return {lines = best_lines, font_size = best_size}


static func _line_partitions(words: PackedStringArray) -> Array[PackedStringArray]:
	var n := words.size()
	var out: Array[PackedStringArray] = [PackedStringArray([" ".join(words)])]
	for i in range(1, n):
		out.append(PackedStringArray([" ".join(words.slice(0, i)), " ".join(words.slice(i))]))
		if MAX_LINES >= 3:
			for j in range(i + 1, n):
				out.append(PackedStringArray([" ".join(words.slice(0, i)), " ".join(words.slice(i, j)),
						" ".join(words.slice(j))]))
	return out


static func _widest(lines: PackedStringArray, font: Font, font_size: int) -> float:
	var w := 0.0
	for l in lines:
		w = maxf(w, font.get_string_size(l, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x)
	return w


static func _block_height(lines: PackedStringArray, font: Font, font_size: int) -> float:
	return font.get_height(font_size) * lines.size()


static func _fit_size(lines: PackedStringArray, font: Font, viewport: Vector2, target: float) -> int:
	const REF := 100
	var widest := maxf(_widest(lines, font, REF), 1.0)
	var s := floori(REF * target * viewport.x / widest)
	var h := maxf(_block_height(lines, font, REF), 1.0)
	s = mini(s, floori(REF * MAX_TEXT_HEIGHT * viewport.y / h))
	s = clampi(s, MIN_FONT_SIZE, MAX_FONT_SIZE)
	while s > MIN_FONT_SIZE and (_widest(lines, font, s) > MAX_LINE_WIDTH * viewport.x
			or _block_height(lines, font, s) > MAX_TEXT_HEIGHT * viewport.y):
		s -= 1
	return s


# --- Node construction --------------------------------------------------------

func _apply_colors(line: OverlayLine) -> void:
	_label_settings.font_color = line.text_color
	_label_settings.outline_color = line.glow_color
	var glow_solid := Color(line.glow_color, 1.0)
	_glow_settings.font_color = glow_solid
	_glow_settings.outline_color = glow_solid
	_glow_group.modulate = Color(1, 1, 1, line.glow_color.a)


func _set_aberration(amount: float) -> void:
	(_aberration.material as ShaderMaterial).set_shader_parameter(&"amount", amount)


func _set_visuals_visible(on: bool) -> void:
	_root.visible = on
	_root.modulate.a = 1.0
	if not on:
		_flash.visible = false
		_aberration.visible = false


func _full_rect(c: Control) -> Control:
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


func _addon_resource(relative_path: String) -> Resource:
	return load(get_script().resource_path.get_base_dir().path_join(relative_path))


func _shader_material(file: String) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = _addon_resource("shaders".path_join(file))
	return mat


func _make_label(settings: LabelSettings) -> Label:
	var l := Label.new()
	l.label_settings = settings
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.uppercase = true
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _build() -> void:
	_root = _full_rect(Control.new())
	_root.name = "Root"
	add_child(_root)

	_backdrop = _full_rect(ColorRect.new())
	_backdrop.name = "Backdrop"
	_backdrop.color = Color.BLACK
	_root.add_child(_backdrop)

	_world_tint = _full_rect(ColorRect.new())
	_world_tint.name = "WorldTint"
	_world_tint.material = _shader_material("world_tint.gdshader")
	_root.add_child(_world_tint)

	_text_root = _full_rect(Control.new())
	_text_root.name = "TextRoot"
	_root.add_child(_text_root)

	_glow_group = CanvasGroup.new()
	_glow_group.name = "Glow"
	_glow_group.fit_margin = 48.0
	_glow_group.clear_margin = 48.0
	_glow_group.use_mipmaps = true
	_glow_group.material = _shader_material("glow_blur.gdshader")
	_text_root.add_child(_glow_group)
	_glow_label = _make_label(_glow_settings)
	_glow_label.name = "GlowLabel"
	_glow_group.add_child(_glow_label)

	_label = _full_rect(_make_label(_label_settings))
	_label.name = "TextLabel"
	_text_root.add_child(_label)

	_flash = _full_rect(ColorRect.new())
	_flash.name = "Flash"
	_flash.color = Color.WHITE
	_root.add_child(_flash)

	var copy := BackBufferCopy.new()
	copy.name = "PostCopy"
	copy.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	_root.add_child(copy)

	_aberration = _full_rect(ColorRect.new())
	_aberration.name = "Aberration"
	_aberration.material = _shader_material("chromatic_burst.gdshader")
	_root.add_child(_aberration)

	_sfx = AudioStreamPlayer.new()
	_sfx.name = "AppearSfx"
	_sfx.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_sfx)
