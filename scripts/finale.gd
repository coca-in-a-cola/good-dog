extends Node2D
## Built-in confetti remains visible behind the finale's exact text.
var stage := 0
var elapsed := 0.0
var last_tick := 0.0
var label: Label
var background: ColorRect
const CREDITS_TEXT := "GOOD DOG\n\nGodot Engine — MIT\nBasic FPS Controller — Arjun Bhumula — MIT\nNoto Sans — The Noto Project Authors — OFL-1.1\nCamera shutter — artem_uanety — CC0\nOther sounds — original synthesis — MIT\n\nPRESS ANY KEY"
## GDD §5 bit 14 / §10: popper, confetti, children's applause, cheerful jingle.
const SOUNDS := [
	[preload("res://assets/audio/sfx/finale/popper_confetti.wav"), &"SFX", 2.0],
	[preload("res://assets/audio/sfx/finale/applause_children.wav"), &"SFX", -2.0],
	[preload("res://assets/audio/music/finale_jingle.wav"), &"Music", -1.0],
]
var players: Array[AudioStreamPlayer] = []

func _layout_text() -> void:
	# Node2D parents do not provide a Control anchor rectangle.
	var viewport_size := get_viewport_rect().size
	background.position = Vector2.ZERO
	background.size = viewport_size
	var margin := Vector2(maxf(24, viewport_size.x * 0.06), maxf(24, viewport_size.y * 0.06))
	label.position = margin
	label.size = viewport_size - margin * 2
	var desired := 32 if stage == 2 else 64
	for font_size in range(desired, 9, -1):
		label.add_theme_font_size_override("font_size", font_size)
		# Reset after minimum-size invalidation when a larger font previously overflowed.
		label.size = viewport_size - margin * 2
		if label.get_minimum_size().y <= label.size.y:
			break
	label.size = viewport_size - margin * 2

func _ready() -> void:
	last_tick = GameState.clock.now()
	var bg := ColorRect.new()
	background = bg
	bg.color = Color("fff4cf")
	bg.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	add_child(bg)
	for x in [0.2,0.8]:
		var particles := CPUParticles2D.new()
		particles.position = get_viewport_rect().size * Vector2(x,0.1)
		particles.amount = 180
		particles.lifetime = 6
		particles.direction = Vector2(0,-1)
		particles.spread = 95
		particles.gravity = Vector2(0,100)
		particles.initial_velocity_min = 80
		particles.initial_velocity_max = 300
		particles.scale_amount_min = 3
		particles.scale_amount_max = 7
		var gradient := Gradient.new()
		gradient.colors = PackedColorArray([Color("c1121f"),Color("25badd"),Color("ffcf20"),Color("e334cc")])
		particles.color_ramp = gradient
		add_child(particles)
	label = Label.new()
	label.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size",64)
	label.add_theme_color_override("font_color",Color("171c24"))
	label.text = GameState.FINAL_LINES[0]
	add_child(label)
	get_viewport().size_changed.connect(_layout_text)
	_layout_text()
	for sound: Array in SOUNDS:
		var player := AudioStreamPlayer.new()
		player.stream = sound[0]
		player.bus = sound[1]
		player.volume_db = sound[2]
		add_child(player)
		player.play()
		players.append(player)

func _exit_tree() -> void:
	for player in players:
		player.stop()

func _process(_delta: float) -> void:
	var now := GameState.clock.now()
	elapsed += maxf(now-last_tick,0)
	last_tick = now
	if stage == 0 and elapsed >= 1.8:
		stage = 1
		label.text = GameState.FINAL_LINES[1]
		_layout_text()

func _unhandled_input(event: InputEvent) -> void:
	if elapsed < 2.15 or not event.is_pressed() or event.is_echo():
		return
	get_viewport().set_input_as_handled()
	if stage == 1:
		stage = 2
		elapsed = 0
		label.text = CREDITS_TEXT
		_layout_text()
	elif stage == 2:
		GameState.quit_to_menu()
