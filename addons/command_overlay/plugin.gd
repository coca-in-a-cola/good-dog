@tool
extends EditorPlugin

const AUTOLOAD_NAME := "Overlay"


func _enable_plugin() -> void:
	add_autoload_singleton(AUTOLOAD_NAME, get_script().resource_path.get_base_dir().path_join("overlay.tscn"))


func _disable_plugin() -> void:
	remove_autoload_singleton(AUTOLOAD_NAME)
