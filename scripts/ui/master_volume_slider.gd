extends HSlider

const FONT_PATH := "res://addons/command_overlay/assets/fonts/NotoSans-Regular.ttf"

var _bg_rect: ColorRect
var _base_label: Label
var _clip_container: Control
var _fill_rect: ColorRect
var _clip_label: Label

var _last_value: float = -INF
var _last_size: Vector2 = Vector2.ZERO


func _init() -> void:
	custom_minimum_size.y = 52.0


func _ready() -> void:
	custom_minimum_size.y = maxf(custom_minimum_size.y, 52.0)
	_setup_theme_overrides()
	_build_overlays()
	value_changed.connect(_on_value_changed)
	resized.connect(_on_resized)
	_update_visuals()


func _process(_delta: float) -> void:
	if not is_equal_approx(value, _last_value) or size != _last_size:
		_update_visuals()


func _setup_theme_overrides() -> void:
	var empty_style := StyleBoxEmpty.new()
	add_theme_stylebox_override("slider", empty_style)
	add_theme_stylebox_override("grabber_area", empty_style)
	add_theme_stylebox_override("grabber_area_highlight", empty_style)

	var empty_img := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	empty_img.fill(Color(0.0, 0.0, 0.0, 0.0))
	var empty_tex := ImageTexture.create_from_image(empty_img)
	add_theme_icon_override("grabber", empty_tex)
	add_theme_icon_override("grabber_highlight", empty_tex)
	add_theme_icon_override("grabber_disabled", empty_tex)


func _build_overlays() -> void:
	if _bg_rect:
		return

	var font: Font = null
	if ResourceLoader.exists(FONT_PATH):
		font = load(FONT_PATH) as Font

	# Full charcoal background
	_bg_rect = ColorRect.new()
	_bg_rect.name = "Background"
	_bg_rect.color = Color(0.12, 0.12, 0.14, 1.0)
	_bg_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_bg_rect)

	# Light centered label
	_base_label = Label.new()
	_base_label.name = "Label"
	_base_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_base_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_base_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_base_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_base_label.add_theme_color_override("font_color", Color(0.92, 0.92, 0.94, 1.0))
	if font:
		_base_label.add_theme_font_override("font", font)
	_base_label.add_theme_font_size_override("font_size", 16)
	add_child(_base_label)

	# Clip container for cyan fill
	_clip_container = Control.new()
	_clip_container.name = "ClipContainer"
	_clip_container.clip_contents = true
	_clip_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_clip_container)

	# Cyan fill rect
	_fill_rect = ColorRect.new()
	_fill_rect.name = "FillRect"
	_fill_rect.color = Color(0.0, 0.85, 0.92, 1.0)
	_fill_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_clip_container.add_child(_fill_rect)

	# Second dark centered label clipped by fill container
	_clip_label = Label.new()
	_clip_label.name = "ClipLabel"
	_clip_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_clip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_clip_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_clip_label.add_theme_color_override("font_color", Color(0.08, 0.08, 0.1, 1.0))
	if font:
		_clip_label.add_theme_font_override("font", font)
	_clip_label.add_theme_font_size_override("font_size", 16)
	_clip_container.add_child(_clip_label)


func _on_value_changed(_val: float) -> void:
	_update_visuals()


func _on_resized() -> void:
	_update_visuals()


func _update_visuals() -> void:
	_last_value = value
	_last_size = size

	if not _clip_container or not _fill_rect or not _base_label or not _clip_label:
		return

	var range_span: float = max_value - min_value
	var norm: float = 0.0
	if range_span > 0.00001:
		norm = clampf((value - min_value) / range_span, 0.0, 1.0)
	else:
		norm = 0.0

	var fill_w: float = size.x * norm
	_clip_container.position = Vector2.ZERO
	_clip_container.size = Vector2(fill_w, size.y)

	_fill_rect.position = Vector2.ZERO
	_fill_rect.size = Vector2(size.x, size.y)

	var pct := int(round(norm * 100.0))
	var label_text := "MASTER VOLUME · %d%%" % pct

	_base_label.text = label_text

	_clip_label.position = Vector2.ZERO
	_clip_label.size = size
	_clip_label.text = label_text
