# Foundation boundary and ordered execution slices

Only F1 (the command_overlay addon) is implemented. There is no game core: no CommandDirector, player, levels or gameplay. All final scope remains in ACCEPTANCE.md and the original source inventory. F1 alone is **not** the complete foundation and **not** the complete game.

## F1 — portable command-overlay (first launch, 75-minute bound)

Godot project, standalone addon/resource/API and demo. Three background modes, resize fit, per-word timing, input lock/consumption, time/pause restoration, cancellation, reduced-flash interface. Godot-native tests and independent empty-project copy test. Parent must inspect actual demo and build/video evidence before accepting original phase 1. Headless checks alone do not accept it.

**Status: parent ACCEPTED as an F1 addon-phase source checkpoint, not the complete foundation or game.** Independent machine QA and delegated native pixel review support this decision. Evidence remains private rather than part of the source checkpoint.
- Assets: actual Noto Sans v2.015 (OFL-1.1, bundled under `addons/command_overlay/assets/fonts/`) is the addon default font, and `font_override` still wins. The CC0 camera-flash one-shot (Freesound 745481, shutter click + flash whine, `assets/sfx/camera_flash.wav`) is `Overlay.default_sfx_appear`, played once per appearing word, with no hide sound. Provenance is in `THIRD_PARTY.md` and `assets/sfx/PROVENANCE.md`.
- Tests: independent native suite 16 passed / 0 failed; portability: both variants × import/portable_smoke/demo_autoplay, all six steps exit 0, with no diagnostics.
- Visuals: independent reviewers inspected all 14 Forward+ stills (llvmpipe software Vulkan) at 1920×1080, 1080×1920 and 2560×1080: 13 PASS. `1920x1080_good_dog_words.png` is an intentional all-white flash frame, preserved as non-evidence for text readability, not a UI defect. A supplemental actual walkthrough frame at 3.3 s shows DOG. in white/cyan over the dim world without clipping; the sampled 16 s GRAB/THE STICK frame also passes. Review scope is 14 stills + 2 sampled walkthrough frames, not full playback.
- Build: Linux x86_64 export and actual exported-runtime autoplay independently pass under Xvfb; software Vulkan execution is not target-GPU acceptance. No binary release is published with this source checkpoint.
- Walkthrough: deterministic Movie Maker capture produced 632 frames / 21.07 s at 1920×1080 with passing capture assertions. H.264 + AAC fully decodes; encoded audio analysis finds 12 signal bursts (peak approximately −0.82 dBFS). This is signal/decode evidence, not subjective audio listening or full visual playback.
- **Still open for later acceptance:** complete foundation/game scope, target-GPU performance, Windows export/runtime, and fullgame walkthrough/playtesting. F2 remains parent-owned and requires a separate authorized launch.
- Input contract unchanged: production code must use `_unhandled_input`, or poll behind `not Overlay.is_input_blocked()`. A naive `Input.is_action_just_pressed` poller still sees the dismissal B in its frame (diagnostic prints 1). Raw polling is not globally prevented.

### Stable contracts F2+ may rely on (from F1)

- `Overlay.show_line(line)`; `await Overlay.dismissed` for normal completion. `Overlay.cancelled(id)` means the line was interrupted. A director must **not** start a rung timer on `cancelled`.
- `Overlay.word_shown(id, index, word)` is the appearance hook for the section 9 camera event (FOV −4° over 0.08 s, aberration). Consumers must honour the same `reduce_flashes` flag.
- Accessibility flags: `Overlay.reduce_flashes: bool` and `Overlay.reduce_shake: bool`. The shake factor is `Overlay.REDUCED_SHAKE_FACTOR` (0.3, the GDD's "trauma to 30%"). The F2/F6 settings menu must write these flags, and the camera-shake and post-processing systems must read the same values.
- Input: gameplay actions (`bark`, `interact`) are read in `_unhandled_input`, or polled only behind `not Overlay.is_input_blocked()`. Dismissal B is then provably not a bark (`test_dismissing_b_is_not_a_bark`).
- Time: the overlay owns `Engine.time_scale` / `SceneTree.paused` only while active or thawing, and restores the values it captured. Other systems must not write either value while `Overlay.is_active()`. Systems that need real-time timers (the escalation ladder) use `create_timer(t, true, false, true)` or tick-based real time.
- Audio: `Overlay.sfx_bus` selects the bus for the appearance sound. F5 sets it to a bus that bypasses the `Ambience`/`SFX` low-pass.

### Concrete F2 extension contracts (to implement after F1 acceptance; not implemented now)

```gdscript
# data/commands/*.tres
class_name Command extends Resource
@export var id: StringName
@export var order_line: OverlayLine
@export var hint_text: String                    # e.g. "PRESS [B] TO BARK"
@export var ladder := PackedFloat32Array([20, 10, 5, 3, 2, 1])
@export var escalation_lines: Array[OverlayLine] # index = rung 1..5 (rung 0 uses order_line)
@export var success_line: OverlayLine
@export var transform_step: int = -1             # TransformStep index applied on success, -1 none
@export var completion_signal: StringName        # barked | grabbed | placed | pit_entered

# data/transform/*.tres (GDD §6 table, one per step 0–4)
class_name TransformStep extends Resource
@export var eye_height_m: float; @export var speed_mps: float; @export var fov_deg: float
@export var max_look_up_deg: float; @export var bob_hz: float; @export var footstep_set: StringName
@export var transition_time := 2.5; @export var transition_curve: Curve; @export var transition_sfx: AudioStream

# scripts/command_director.gd — node on the level scene
enum State { IDLE, ORDER_SHOWN, WAITING, SUCCESS, ESCALATE, FAIL }
signal pressure_changed(level: int)        # 0–5 (GDD audio table rungs 1–6 map to levels 0–5)
signal command_completed(id: StringName)
signal failed
func run(command: Command) -> void         # show order -> await Overlay.dismissed -> real-time rung timer
func notify(completion: StringName) -> void  # from player/interactables signals; no per-frame polling
# Rung timer starts only after dismissed; a completion while ORDER_SHOWN is ignored (overlay blocks input).
# Off-order bark during WAITING of a non-bark command -> FLASH "QUIET." with no timer penalty.
# Last-rung (1 s) expiry -> FAIL: BLACK "BAD DOG." -> GameState.fail().

# scripts/game_state.gd — autoload
signal state_changed(state: StringName)    # warning, menu, playing, failed, falling, finale
func start_game() -> void; func fail() -> void; func enter_finale() -> void; func quit_to_menu() -> void
# Always calls Overlay.force_hide() before scene changes; no progress persistence (GDD §4/§13).

# PressureController / TransformController (adapters, Curve-driven, inspector-tunable)
func set_pressure_level(level: int) -> void         # listens to pressure_changed
func apply_step(step: TransformStep) -> void        # listens to command_completed; emits transform_step_changed(step)

# Interactables: stick.gd emits grabbed; place_zone.gd emits placed; pit.gd emits pit_entered.
# LeashConstraint: activate(center: Vector3); emits leash_pulled; ratchet max_d per GDD §7.
```

## F2 — shared architectural foundation and BARK greybox (next Opus increment)

After F1 acceptance: Command/TransformStep resources; signal-driven CommandDirector ladder and completions; GameState/menu/failure/restart lifecycle; player controller adapter (verified upstream license/revision, custom-code fallback only with recorded search); PressureController/TransformController contracts and data-driven adapters; interactable and leash extension boundaries. A playable BARK cell proves integration, including dismissal-B not counting as bark, each rung, pause and repeat restart. All shared-state/core contracts must be accepted before calling the architectural foundation complete.

## F3 — remaining gameplay (one coherent route)

Original phase 3: GRAB/PLACE/JUMP; room progression/gates, transform values and collision safety, inward/tangential leash + ratchet, 60-second randomized wall-slide regression, fall and confetti/credits. Independent acceptance of F2 first. Implement actual production consumers, not only unused interfaces.

## Later original phases (not removed)

4 licensed environment + Blender MCP primitives; 5 audio layers/events/rooms/mix; 6 pressure/transform post-processing, camera and accessibility; 7 polish, complete 8–15 minute walkthrough, 5+ human playtest, target hardware FPS, Windows/Linux exports and release. Each phase requires build + walkthrough video and acceptance before the next.

## Latest owner routing authorization

Opus 5.5/high is initial preferred. When Opus subscription limits are exhausted, preserve partial work and exact unfinished acceptance manifest, then the parent may switch hard/architectural work to the existing centrally authorized ChatGPT/OpenAI/Codex route. Gemini is authorized for light subtasks. This quota exception supersedes the earlier Opus-only architectural rule. Verify actual model/provider on each execution; no paid-API billing substitution, OAuth copying, or unrelated provider-config changes.

## Publication gates

Public target owner is coca-in-a-cola, not coca-in-a-cola-iaac. Commit/checkpoint only develop after independent acceptance. Original GDD remains a private immutable subdocument until publication rights are clear. Choose an explicit original-code license before public code publication and verify each imported license, credits and exact revision/file checksum in THIRD_PARTY.md.
