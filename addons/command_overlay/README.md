# command_overlay

Full-screen command text for Godot 4.7 (GDScript, built-in nodes only). Giant upper-case words with a blurred glow, on black (`BLACK`), over a frozen and desaturated world (`OVER_WORLD`), or as a short non-blocking hit (`FLASH`). Nothing outside this folder is required.

## Install

1. Copy `addons/command_overlay/` into any Godot 4.7 project.
2. Enable **Command Overlay** under Project Settings → Plugins. This registers the `Overlay` autoload (`overlay.tscn`: `CanvasLayer`, layer 100, `process_mode = ALWAYS`).

Without the autoload you can instantiate `overlay.tscn` yourself; the demo does this when no `/root/Overlay` exists.

## API

```gdscript
signal shown(line_id: StringName)
signal dismissed(line_id: StringName)        # normal end: key press or auto-hide
signal cancelled(line_id: StringName)        # extension: force_hide / replacement / scene change / tree exit
signal word_shown(line_id: StringName, word_index: int, word: String)  # extension: appearance hook
signal sequence_finished                      # extension

func show_line(line: OverlayLine) -> void     # await Overlay.dismissed
func show_text(text: String, mode := OverlayLine.Mode.OVER_WORLD) -> void
func show_sequence(lines: Array[OverlayLine]) -> void
func is_active() -> bool
func force_hide() -> void
func is_input_blocked() -> bool               # extension: guard for code that polls Input
```

Properties: `reduce_flashes` (no white frame or aberration burst), `reduce_shake` (jitter at 30%), `unfreeze_time` (0.25 s), `default_sfx_appear`, `sfx_bus`, `cancel_on_scene_change`, `aberration_strength`, `glow_radius_px`.

`OverlayLine` (`.tres`) fields: `id`, `text`, `mode`, `per_word`, `word_interval`, `dismiss` (`ANY_KEY` / `AUTO` / `BOTH`), `auto_hide_after`, `min_lock_time`, `text_color`, `glow_color`, `font_override`, `punch_scale`, `jitter_px`, `sfx_appear`, `world_time_scale`. Extension field: `hide_fade_time` (0 means an instant cut; 0.12 gives a fade).

## Behaviour

- All timing uses real time, so it is unaffected by `Engine.time_scale` and `SceneTree.paused`.
- `BLACK` pauses the tree. `OVER_WORLD` sets `Engine.time_scale = world_time_scale` (0.05) and keeps the prior pause state. On hide, pause is restored immediately and time scale eases back over 0.25 s. Consecutive modal lines in a sequence keep the world frozen. The prior pause state and time scale are restored on dismissal, `force_hide()` (immediately, with no thaw), scene change and tree exit.
- `FLASH` never pauses, never changes time scale, never consumes input, and always auto-hides after `auto_hide_after` (default 0.6 s).
- Input (modal lines): every press, echo and mouse motion is consumed with `set_input_as_handled()`. Releases pass through, so held-key state is never stuck. A press dismisses only if it is fresh (not an echo; mouse wheel excluded) and arrives `min_lock_time` (0.35 s) after the **last** word appeared. Swallowed presses also `Input.action_release()` their actions.
- **Gameplay contract:** read gameplay actions in `_unhandled_input`, never in `_input`, because autoload `_input` runs after scene nodes' `_input`. Godot keeps `Input.is_action_just_pressed()` true for the whole frame of a press, even after `action_release()`, so code that polls must also check `Overlay.is_input_blocked()`.
- Appearance: a single white flash frame, a punch from `punch_scale` to 1.0 over 0.08 s (ease-out), and a 0.1 s chromatic aberration burst. The `sfx_appear` sound plays once per appearing word. Hiding is silent.
- Per-word: each word replaces the previous one every `word_interval`.
- Fit: a single word fills 87.5% of the viewport width. Phrases use up to 3 balanced lines, each at most 90% of the width. A safety cap holds the block within 80% of the height, which shrinks single words on ultra-wide screens.
- Idle: random jitter of `jitter_px` per frame, and a glow pulse between 0.85 and 1.0 at 1.5 Hz. Glow comes from a `CanvasGroup` copy with a mipmapped Gaussian blur (18 px) plus a `LabelSettings` outline of 8–16 px.

## Demo

Open `demo/demo.tscn`: one button per mode, a sequence, the red `BAD DOG.` line, and toggles for reduced flashes and shake. The status line counts B presses that reached the game. Headless smoke runs:

```
godot4 --headless --path <project> res://addons/command_overlay/demo/demo.tscn -- --overlay-demo-autoplay
godot4 --headless --path <project> -s res://addons/command_overlay/demo/portable_smoke.gd
```

## Known gaps

- No camera-flash sound ships with the addon. `sfx_appear` and `default_sfx_appear` are null until a licensed file is imported, so lines are currently silent.
- Godot 4.7's fallback project font is **Open Sans SemiBold**, not Noto Sans. Use `font_override` for a specific font.
- Visual quality (glow, aberration, desaturation) has not been inspected on a GPU. All verification so far is headless.
