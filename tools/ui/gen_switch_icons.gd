extends SceneTree

func _init() -> void:
	DirAccess.make_dir_recursive_absolute("res://assets/ui")
	var w := 52
	var h := 26
	
	_make_switch(w, h, Color(0.07, 0.08, 0.10), Color(0.24, 0.28, 0.35), Color(0.55, 0.60, 0.68), 4, "res://assets/ui/switch_off.png")
	_make_switch(w, h, Color(0.04, 0.12, 0.16), Color(0.13, 0.83, 0.93), Color(0.13, 0.83, 0.93), 28, "res://assets/ui/switch_on.png")
	_make_switch(w, h, Color(0.05, 0.06, 0.07), Color(0.16, 0.18, 0.22), Color(0.30, 0.34, 0.38), 4, "res://assets/ui/switch_off_disabled.png")
	_make_switch(w, h, Color(0.03, 0.08, 0.10), Color(0.10, 0.40, 0.46), Color(0.10, 0.40, 0.46), 28, "res://assets/ui/switch_on_disabled.png")
	print("Switch textures generated successfully")
	quit()

func _make_switch(w: int, h: int, bg: Color, border: Color, knob: Color, knob_x: int, path: String) -> void:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in range(h):
		for x in range(w):
			if x == 0 or x == w - 1 or y == 0 or y == h - 1 or x == 1 or x == w - 2 or y == 1 or y == h - 2:
				img.set_pixel(x, y, border)
			else:
				img.set_pixel(x, y, bg)
	# Draw sharp rectangular knob (20x18)
	for y in range(4, h - 4):
		for x in range(knob_x, knob_x + 20):
			img.set_pixel(x, y, knob)
	img.save_png(path)
