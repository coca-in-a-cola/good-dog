class_name PostProcessController
extends CanvasLayer
## GDD §9 screen stack and sensory bridge (scenes/camera/post_process.tscn).
##
## Combines the pressure axis (PressureController.values, level 0–5) with the
## transformation axis (TransformController.post_values, step 0–4): deltas over
## the base add, saturation multiplies. Camera events arrive through the public
## event methods, which bind() connects to the production signals; camera-side
## motion is forwarded to the player's TraumaCamera. Writes the post_process
## shader and the WorldEnvironment glow. Layer 5 sits under the HUD (10) and the
## overlay (100), so only the world is distorted. Real clock; frozen by the Esc
## pause and BLACK lines. Reads Overlay.reduce_flashes (the single flag).

## Base row of the GDD §9 table (both axes at 0).
const BASE := {glow = 0.8, vignette = 0.25, aberration = 0.0, grain = 0.03, saturation = 1.0}
## OVER_WORLD lines: the world drops to this saturation.
const OVER_WORLD_SATURATION := 0.2
## Text line appearance: +0.008 aberration decaying over 0.1 s, one white frame.
const BURST_ABERRATION := 0.008
const BURST_TIME := 0.1
## reduce_flashes replacement for the white frame: a slow, soft contrast dip.
const DIP := 0.25
const DIP_IN := 0.06
const DIP_OUT := 0.25
## GOOD DOG: warm amber (#FFC879) bloom, 0.5 s in total (GDD §8 "≤ 0.5 s").
const PRAISE_TINT := Color("#ffc879")
const PRAISE_BLOOM := 1.2
const PRAISE_GLOW := 0.4
const PRAISE_IN := 0.05
const PRAISE_OUT := 0.45
## Transformation step: radial blur 0.4 (0.1 s in, 0.3 s out) and a vignette pulse.
const STEP_BLUR := 0.4
const STEP_BLUR_IN := 0.1
const STEP_BLUR_OUT := 0.3
const STEP_VIGNETTE := 0.3
const STEP_VIGNETTE_IN := 0.04
const STEP_VIGNETTE_OUT := 0.5
## Pit fall: monotonic darkening to black and rising radial blur over 4 s.
const FALL_TIME := 4.0
const FALL_BLUR := 1.0

@export var environment: WorldEnvironment
## Player camera layer that receives punch/praise/step/jolt.
var camera: TraumaCamera
## Latest PressureController.values / TransformController.post_values.
var pressure_values: Dictionary = {}
var transform_values: Dictionary = {}
## What reached the shader this frame (diagnostics and tests).
var values: Dictionary = {}
var falling := false
var blackout := false
## Defaults to GameState.clock; tests inject a manual clock.
var clock: RealClock

var _director: CommandDirector
var _overlay: Node
var _last_tick := 0.0
var _burst_t := INF
var _flash_frame := -1
var _dip_t := INF
var _praise_t := INF
var _step_t := INF
var _fall_t := 0.0
@onready var _material: ShaderMaterial = $Screen.material


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if clock == null:
		var gs := get_node_or_null(^"/root/GameState")
		clock = gs.clock if gs != null else RealClock.new()
	if _overlay == null:
		_overlay = get_node_or_null(^"/root/Overlay")
	_material.set_shader_parameter(&"bloom_tint", PRAISE_TINT)
	_last_tick = clock.now()
	_apply()


func _exit_tree() -> void:
	if _overlay != null and is_instance_valid(_overlay) and _overlay.word_shown.is_connected(_on_word_shown):
		_overlay.word_shown.disconnect(_on_word_shown)
	var gs := get_node_or_null(^"/root/GameState")
	if gs != null and gs.state_changed.is_connected(_on_game_state):
		gs.state_changed.disconnect(_on_game_state)


## Connects the production level: pressure, transformation, overlay words,
## praise, leash, fall and BAD DOG. Systems stay unaware of each other.
func bind(level: Node) -> void:
	var player: GoodDogPlayer = level.player
	camera = player.camera_fx
	if environment == null:
		environment = level.get_node_or_null(^"WorldEnvironment")
	_director = level.director
	var pressure: PressureController = level.pressure
	var transform_ctl: TransformController = level.transform_ctl
	pressure.pressure_applied.connect(_on_pressure)
	transform_ctl.post_applied.connect(_on_transform_post)
	transform_ctl.transform_step_changed.connect(transformation_advanced)
	_director.command_succeeded.connect(_on_command_succeeded)
	_director.failed.connect(bad_dog_triggered)
	var leash: LeashConstraint = level.get(&"leash_ctl")
	if leash != null:
		leash.leash_pulled.connect(leash_tugged)
	if _overlay != null:
		_overlay.word_shown.connect(_on_word_shown)
	GameState.state_changed.connect(_on_game_state)
	pressure_values = pressure.values
	transform_values = transform_ctl.post_values
	_apply()


func _process(_delta: float) -> void:
	tick()


func tick() -> void:
	var now := clock.now()
	var dt := maxf(now - _last_tick, 0.0)
	_last_tick = now
	if is_inside_tree() and get_tree().paused:
		dt = 0.0
	advance(dt)


## Advances every event timer by `dt` real seconds and writes the stack.
func advance(dt: float) -> void:
	_burst_t += dt
	_dip_t += dt
	_praise_t += dt
	_step_t += dt
	if falling:
		_fall_t += dt
	_apply()


# --- Camera events (GDD §9 table) ---------------------------------------------

## Every appearing word: FOV punch, aberration burst and one white frame (or,
## with reduce_flashes, a soft contrast dip and no burst).
func text_line_displayed() -> void:
	if _reduce_flashes():
		_dip_t = 0.0
	else:
		_burst_t = 0.0
		_flash_frame = Engine.get_process_frames()
	if camera != null:
		camera.punch()
	_apply()


## GOOD DOG: warm bloom and the camera's "petting" roll.
func praise_received() -> void:
	_praise_t = 0.0
	if camera != null:
		camera.praise()
	_apply()


## Transformation step: radial blur pulse, vignette pulse, FOV breath and shake.
func transformation_advanced(_step: int = 0) -> void:
	_step_t = 0.0
	if camera != null:
		camera.transform_pulse()
	_apply()


## Leash pull: the camera jolts toward the pit centre.
func leash_tugged(toward_center: Vector3) -> void:
	if camera != null:
		camera.jolt(toward_center)


## Pit trigger: 4 s of darkening and rising radial blur.
func pit_fall_started() -> void:
	if falling:
		return
	falling = true
	_fall_t = 0.0
	_apply()


## BAD DOG: hard cut to black in the same frame, no transition.
func bad_dog_triggered() -> void:
	blackout = true
	_apply()


# --- Signal adapters ----------------------------------------------------------

func _on_word_shown(_id: StringName, _index: int, _word: String) -> void:
	text_line_displayed()


func _on_pressure(_level: int, p_values: Dictionary) -> void:
	pressure_values = p_values
	_apply()


func _on_transform_post(p_values: Dictionary) -> void:
	transform_values = p_values
	_apply()


## Commands without a praise line (JUMP) get no GOOD DOG effect.
func _on_command_succeeded(_id: StringName) -> void:
	if _director != null and _director.command != null and _director.command.success_line != null:
		praise_received()


func _on_game_state(state: StringName) -> void:
	if state == &"falling":
		pit_fall_started()


# --- Composition --------------------------------------------------------------

func _apply() -> void:
	var reduce := _reduce_flashes()
	var praise := TraumaCamera.pulse(_praise_t, PRAISE_IN, PRAISE_OUT)
	var fall := clampf(_fall_t / FALL_TIME, 0.0, 1.0) if falling else 0.0
	var burst := 0.0 if reduce or _burst_t >= BURST_TIME else 1.0 - _burst_t / BURST_TIME
	var sat: float = pressure_values.get(&"saturation", 1.0) * transform_values.get(&"saturation", 1.0)
	if _over_world():
		sat = OVER_WORLD_SATURATION
	values = {
		glow = _axes(&"glow") + PRAISE_GLOW * praise,
		vignette = clampf(_axes(&"vignette") + STEP_VIGNETTE * TraumaCamera.pulse(_step_t, STEP_VIGNETTE_IN, STEP_VIGNETTE_OUT), 0.0, 1.0),
		aberration = _axes(&"aberration") + BURST_ABERRATION * burst,
		grain = _axes(&"grain"),
		barrel = transform_values.get(&"barrel", 0.0),
		canine_vision = transform_values.get(&"canine_vision", 0.0),
		saturation = sat,
		bloom_boost = PRAISE_BLOOM * praise,
		radial_blur = maxf(STEP_BLUR * TraumaCamera.pulse(_step_t, STEP_BLUR_IN, STEP_BLUR_OUT), FALL_BLUR * fall),
		flash_white = 1.0 if not reduce and Engine.get_process_frames() == _flash_frame else 0.0,
		contrast_dip = DIP * TraumaCamera.pulse(_dip_t, DIP_IN, DIP_OUT),
		fade_black = 1.0 if blackout else fall,
	}
	if _material != null:
		_material.set_shader_parameter(&"vignette_amount", values.vignette)
		_material.set_shader_parameter(&"chromatic_aberration", values.aberration)
		_material.set_shader_parameter(&"film_grain_intensity", values.grain)
		_material.set_shader_parameter(&"barrel_distortion", values.barrel)
		_material.set_shader_parameter(&"canine_vision_weight", values.canine_vision)
		_material.set_shader_parameter(&"saturation", shader_saturation())
		_material.set_shader_parameter(&"bloom_boost", values.bloom_boost)
		_material.set_shader_parameter(&"radial_blur_intensity", values.radial_blur)
		_material.set_shader_parameter(&"flash_white", values.flash_white)
		_material.set_shader_parameter(&"contrast_dip", values.contrast_dip)
		_material.set_shader_parameter(&"fade_black", values.fade_black)
	if environment != null and environment.environment != null:
		environment.environment.glow_intensity = values.glow


## Base + (pressure − base) + (transformation − base) for one table row.
func _axes(key: StringName) -> float:
	var base: float = BASE[key]
	var p: float = pressure_values.get(key, base)
	var t: float = transform_values.get(key, base)
	return base + (p - base) + (t - base)


## The overlay's own OVER_WORLD tint already desaturates the frame; divide it
## out so the world lands on values.saturation instead of compounding to 0.04.
func shader_saturation() -> float:
	var sat: float = values.get(&"saturation", 1.0)
	if _over_world():
		sat /= maxf(_overlay_tint_saturation(), 0.01)
	return clampf(sat, 0.0, 2.0)


func _over_world() -> bool:
	if _overlay == null or not _overlay.is_active():
		return false
	var line: OverlayLine = _overlay.get_current_line()
	return line != null and line.mode == OverlayLine.Mode.OVER_WORLD


func _overlay_tint_saturation() -> float:
	var tint := _overlay.get_node_or_null(^"Root/WorldTint") as CanvasItem
	if tint == null or not tint.visible or not (tint.material is ShaderMaterial):
		return 1.0
	var mat := tint.material as ShaderMaterial
	var v: Variant = mat.get_shader_parameter(&"saturation")
	if v == null and mat.shader != null:
		v = RenderingServer.shader_get_parameter_default(mat.shader.get_rid(), &"saturation")
	return float(v) if v != null else 1.0


func _reduce_flashes() -> bool:
	return _overlay != null and _overlay.reduce_flashes
