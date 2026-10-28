extends Control
## GDD §9: flashes / heavy themes warning before the main menu. Any key continues.

const MIN_SHOW_SECONDS := 1.0

var _shown_at := 0.0


func _ready() -> void:
	_shown_at = GameState.clock.now()
	$Text.text = "WARNING\n\nThis game contains flashing images, camera shake\nand themes of coercion and humiliation.\n\nHeadphones recommended.\n\nPress any key"


func _unhandled_input(event: InputEvent) -> void:
	var press: bool = (event is InputEventKey and event.pressed and not event.echo) \
			or (event is InputEventMouseButton and event.pressed) \
			or (event is InputEventJoypadButton and event.pressed)
	if press and GameState.clock.now() - _shown_at >= MIN_SHOW_SECONDS:
		get_viewport().set_input_as_handled()
		GameState.quit_to_menu()
