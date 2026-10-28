extends Control
## Main menu: START, accessibility toggles (write Overlay.reduce_flashes /
## reduce_shake — the single source read by overlay, pressure and camera), QUIT.

@onready var start_button: Button = $Box/Start
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
	start_button.grab_focus()
