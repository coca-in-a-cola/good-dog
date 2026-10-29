extends Control
## Main menu: START, accessibility toggles (write Overlay.reduce_flashes /
## reduce_shake — the single source read by overlay, pressure and camera), QUIT.

@onready var start_button: Button = $Box/Start
@onready var volume_slider: HSlider = $Box/MasterVolume
@onready var volume_label: Label = $Box/MasterVolume/Label
@onready var flashes: CheckButton = $Box/ReduceFlashes
@onready var shake: CheckButton = $Box/ReduceShake
@onready var quit_button: Button = $Box/Quit


func _ready() -> void:
	flashes.button_pressed = Overlay.reduce_flashes
	shake.button_pressed = Overlay.reduce_shake
	start_button.pressed.connect(GameState.start_game)
	flashes.toggled.connect(func(on: bool) -> void: Overlay.reduce_flashes = on)
	shake.toggled.connect(func(on: bool) -> void: Overlay.reduce_shake = on)
	quit_button.pressed.connect(get_tree().quit)

	var am := get_node_or_null(^"/root/AudioMix")
	var initial_vol: float = am.master_volume if am != null else 100.0
	volume_slider.set_value_no_signal(initial_vol)
	_update_volume_label(initial_vol)

	volume_slider.value_changed.connect(func(val: float) -> void:
		var audio := get_node_or_null(^"/root/AudioMix")
		if audio != null:
			audio.set_master_volume(val)
	)
	if am != null:
		am.master_volume_changed.connect(_on_master_volume_changed)

	# Explicit keyboard navigation loop: START -> VOLUME -> TOGGLES -> QUIT
	start_button.focus_neighbor_top = quit_button.get_path()
	start_button.focus_neighbor_bottom = volume_slider.get_path()
	volume_slider.focus_neighbor_top = start_button.get_path()
	volume_slider.focus_neighbor_bottom = flashes.get_path()
	flashes.focus_neighbor_top = volume_slider.get_path()
	flashes.focus_neighbor_bottom = shake.get_path()
	shake.focus_neighbor_top = flashes.get_path()
	shake.focus_neighbor_bottom = quit_button.get_path()
	quit_button.focus_neighbor_top = shake.get_path()
	quit_button.focus_neighbor_bottom = start_button.get_path()

	start_button.grab_focus()


func _on_master_volume_changed(vol: float) -> void:
	if volume_slider != null:
		volume_slider.set_value_no_signal(vol)
		_update_volume_label(vol)


func _update_volume_label(vol: float = -1.0) -> void:
	if volume_slider != null and volume_slider.has_method("_update_visuals"):
		volume_slider._update_visuals()
	elif volume_label != null:
		var v: float = vol if vol >= 0.0 else (volume_slider.value if volume_slider != null else 100.0)
		volume_label.text = "MASTER VOLUME · %d%%" % int(round(v))
