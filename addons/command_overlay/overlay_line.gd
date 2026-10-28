@tool
class_name OverlayLine
extends Resource
## One full-screen line shown by the command_overlay addon.
##
## Store lines as .tres files. Text is English-only and rendered upper-case.

enum Mode {
	BLACK,       ## Solid black backdrop; SceneTree is paused.
	OVER_WORLD,  ## World visible, desaturated/darkened; Engine.time_scale = world_time_scale.
	FLASH,       ## World keeps running; auto-hides after auto_hide_after; never consumes input.
}

enum Dismiss {
	ANY_KEY,  ## Any fresh key / mouse button / joypad button press after the lock.
	AUTO,     ## Hides by itself auto_hide_after seconds after the last word appears.
	BOTH,     ## Whichever comes first.
}

@export var id: StringName = &""
@export_multiline var text: String = ""
@export var mode: Mode = Mode.OVER_WORLD
@export var per_word: bool = false
## Real-time seconds between words when per_word is on (design range 0.35–0.6).
@export_range(0.05, 2.0, 0.01, "suffix:s") var word_interval: float = 0.45
@export var dismiss: Dismiss = Dismiss.ANY_KEY
## Real-time seconds after the last word before AUTO/BOTH (and every FLASH) line hides.
@export_range(0.0, 10.0, 0.01, "suffix:s") var auto_hide_after: float = 0.6
## Real-time seconds after the last word during which presses are swallowed but ignored.
@export_range(0.0, 5.0, 0.01, "suffix:s") var min_lock_time: float = 0.35
@export var text_color: Color = Color(1.0, 1.0, 1.0, 1.0)
@export var glow_color: Color = Color(0.6235, 0.9569, 1.0, 0.6)
@export var font_override: Font
@export_range(1.0, 3.0, 0.01) var punch_scale: float = 1.2
@export_range(0.0, 8.0, 0.1, "suffix:px") var jitter_px: float = 1.5
## Appearance sound, played once per appearing word. Null falls back to Overlay.default_sfx_appear.
@export var sfx_appear: AudioStream
@export_range(0.01, 1.0, 0.01) var world_time_scale: float = 0.05
## Extension: 0 = instant cut on hide, otherwise fade duration (design value 0.12).
@export_range(0.0, 1.0, 0.01, "suffix:s") var hide_fade_time: float = 0.0


func get_line_id() -> StringName:
	if id != &"":
		return id
	return StringName(text.strip_edges().to_upper())


func get_words() -> PackedStringArray:
	var upper := text.strip_edges().to_upper().replace("\n", " ")
	if per_word:
		return upper.split(" ", false)
	return PackedStringArray([upper])


## FLASH never waits for a key, regardless of the dismiss field.
func waits_for_key() -> bool:
	return mode != Mode.FLASH and dismiss != Dismiss.AUTO


func hides_automatically() -> bool:
	return mode == Mode.FLASH or dismiss != Dismiss.ANY_KEY


static func make(p_text: String, p_mode: Mode = Mode.OVER_WORLD, p_id: StringName = &"") -> OverlayLine:
	var line := OverlayLine.new()
	line.text = p_text
	line.mode = p_mode
	line.id = p_id
	if p_mode == Mode.FLASH:
		line.dismiss = Dismiss.AUTO
	return line
