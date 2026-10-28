# Foundation boundary and ordered execution slices

F1 (command_overlay addon, accepted) and the F2 source increment (shared core + greybox BARK cell, **implemented, not accepted**) exist. F2 still needs independent parent acceptance of its build and walkthrough evidence. GRAB/PLACE/JUMP, rooms, fall, finale and all later phases are not implemented. All final scope remains in ACCEPTANCE.md and the original source inventory. F1+F2 are **not** the complete game.

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

## F2 — shared architectural core + playable BARK cell

**Status: implemented source increment; F2 BLOCKED, not accepted.** The demonstrated menu interaction contrast, capture centering/traversal and headless audio teardown defects have focused repairs, but refreshed full-route pixels and exported warning → menu → START interaction still require parent acceptance. Historical evidence below describes its original source identity, not the repaired source. Private repair evidence is under `evidence/f2-repair/`. It is not self-accepted, and the architectural foundation counts as complete only after parent acceptance. Per-object details are in `docs/objects/*.md`.

### Actual contracts (code is authoritative)

```gdscript
# scripts/command.gd — data/commands/bark.tres
class_name Command extends Resource
@export var id; order_line: OverlayLine; hint_text; ladder := [20,10,5,3,2,1]
@export var escalation_lines: Array[OverlayLine]  # index 0 = rung 2 … index 4 = rung 6
@export var success_line; transform_step := -1; completion_signal  # barked|grabbed|placed|pit_entered
func line_for_rung(rung: int) -> OverlayLine

# scripts/transform_step.gd — data/transform/step_0..4.tres (GDD §6 rows)
class_name TransformStep extends Resource
@export var index, eye_height_m, speed_mps, fov_deg, max_look_up_deg, bob_hz, bob_amplitude_m,
		mouse_sensitivity_scale, footstep_set, transition_time := 2.5, transition_curve: Curve, transition_sfx
func sample_transition(progress) -> float

# scripts/command_director.gd — node on the level scene
enum State { IDLE, ORDER_SHOWN, WAITING, SUCCESS, ESCALATE, FAIL }
signal pressure_changed(level)            # 0–5 = rung index; GDD audio rung = level + 1
signal command_started(id), command_succeeded(id)  # succeeded = timer stopped instantly
signal command_completed(id), transform_requested(step)  # after the praise line is dismissed
signal hint_changed(text), quiet_issued, failed, state_changed(state)
func run(command); notify(completion); bind_source(obj, signal, completion); bind_interactable(item); stop()
func get_remaining() -> float   # debug HUD (F3 key, debug builds) only; no visible countdown

# scripts/game_state.gd — autoload GameState
signal state_changed(state)     # boot, warning, menu, playing, failed (falling/finale reserved for F3)
var clock: RealClock            # shared real-time clock; manual in tests/capture
func show_warning(); quit_to_menu(); start_game(); fail(); request_pause() -> bool; resume(); run_away()
func enter_falling(); enter_finale()   # F3 boundary stubs (state only)

# scripts/pressure_controller.gd   set_pressure_level(level); nudge(); reset(); values; pressure_applied(level, values)
# scripts/transform_controller.gd  apply_step_index(i); apply_step(step); reset(); transform_step_changed / transform_finished
# scripts/good_dog_player.gd       GoodDogPlayer extends Player (vendored ar-bh): barked, interacted, footstep(set);
#                                  apply_transform_values(dict); set_eye_height(h); set_shake_trauma(t); controls_enabled; leash
# scripts/interactables/interactable.gd  Interactable: completed(completion); completion_signal; complete() once; reset()
# scripts/leash_constraint.gd      LeashConstraint: activate(center, start_pos); deactivate(); reset(); leash_pulled(dir);
#                                  constrain_velocity(pos, vel); clamp_position(pos); on_rung(level); contract_on_rung=false
```

### Rules the code enforces
- The rung timer is real time (`GameState.clock`). It starts only on the overlay's `dismissed` for the line the director itself showed. `cancelled`, foreign lines with the same id, replaced lines and stray `dismissed` emissions never start it. An expired rung shows the next order and waits for its dismissal; rung 6 (FLASH) auto-dismisses after 0.6 s. When the 1 s rung expires, the director shows BLACK `BAD DOG.` and emits `failed` once, with no seventh rung.
- The timer does not advance while the tree is paused (Esc), and it is unaffected by `Engine.time_scale` 0.05. Pause is refused while the overlay is active or thawing (`time_scale != 1`), so GameState never writes `paused` while the overlay owns it.
- A valid completion stops the timer immediately (`SUCCESS`). Duplicate or stale completions in ORDER_SHOWN, SUCCESS or FAIL are ignored. An off-order bark in WAITING (or IDLE between orders) shows FLASH `QUIET.` with no penalty or reset. A new `run()` restarts the ladder at 20 s.
- Restart and failure go through `GameState._change()`: `Overlay.force_hide()`, clear pause, curtain and mute, set `time_scale = 1`, release all held actions, then reload the level scene. That gives a new director (generation, timers and Overlay connections are disconnected in `_exit_tree`), new pressure, transform and player state, and no persistence. Failure shows BAD DOG for 2 s, then 3 s of muted black, then the menu.
- Pressure (0–5) and transformation (0–4) are separate nodes and axes. PressureController reads `Overlay.reduce_flashes` and `Overlay.reduce_shake`; there are no duplicate flags. The menu toggles write the Overlay flags.

### BARK cell (scenes/level.tscn)
Warning → menu (START, reduce flashes/shake, QUIT) → 3 s black prologue with lamp flicker → BLACK `BARK.` → `PRESS [B] TO BARK` → ladder (BARK. / BARK. / BARK. larger / BARK. NOW. per word / red-glow BARK. / FLASH BARK.) → B → `GOOD.` `DOG.` → transformation 1 (2.5 s, control kept) and the bars slide open into a corridor stub → later barks get QUIET. Esc gives OBEY / RUN AWAY. CSG + built-in lighting only.

### Evidence produced in this run (not acceptance)
- Native tests: 27 passed / 0 failed (16 F1 + 11 F2), exit 0, no error/warning/leak lines.
- Portability: six steps exit 0, PASS.
- Capture driver `tools/capture/f2_capture.gd` (headless logic run): all assertions OK, failures=0.
- Linux export: `builds/f2/good-dog.x86_64` + `.pck`. Excluded paths: 0 packed. The exported runtime boots under Xvfb (`--quit-after 300`); the only diagnostics are the sandbox's missing ALSA device and the dummy-driver fallback.
- Walkthrough (**PARTIAL, gate still open**): the Movie Maker capture on llvmpipe at 1920×1080 ran about 27 s wall per video second and was stopped by its own 1200 s `timeout` (exit 124) during rung 2 of the second (failure) run. The capture assertions passed up to that point. `evidence/f2/walkthrough_PARTIAL.mp4`, salvaged from the unfinalized AVI, has 1146 frames / 38.2 s, H.264 + AAC; volumedetect gives max −1.7 dB and mean −34.3 dB (signal, not a listening review). It covers warning → menu → prologue → BARK → B dismissal → rungs 1–3 → bark → GOOD. DOG. → transformation 1 + bars → QUIET → pause OBEY / RUN AWAY → fresh restart. It does **not** show the BAD DOG → silence → menu tail; the headless driver and tests cover that tail. A complete capture is parent-owned. Software Vulkan (llvmpipe) is not target-GPU evidence.

### Remaining F2-adjacent limits (owned by later phases)
- No inertia hook in the vendored controller (velocity is instant). Head bob, footstep signal and sensitivity are adapter-level, and there are no footstep sounds yet (F5).
- PressureController's audio layers are data and values only. Metronome, heartbeat, tinnitus and hum sounds are F5; post-processing consumers are F6.
- Leash: the post-move ratchet clamp is wired into GoodDogPlayer. Pre-move `constrain_velocity` integration, the physics wall-slide and the 60 s randomized regression are F3.
- Interactable is a contract only. Stick, place zone and pit gameplay are F3.

## F3 — remaining gameplay (one coherent route)

Original phase 3: GRAB/PLACE/JUMP; room progression/gates, transform values and collision safety, inward/tangential leash + ratchet, 60-second randomized wall-slide regression, fall and confetti/credits. Independent acceptance of F2 first. Implement actual production consumers, not only unused interfaces.

## Later original phases (not removed)

4 licensed environment + Blender MCP primitives; 5 audio layers/events/rooms/mix; 6 pressure/transform post-processing, camera and accessibility; 7 polish, complete 8–15 minute walkthrough, 5+ human playtest, target hardware FPS, Windows/Linux exports and release. Each phase requires build + walkthrough video and acceptance before the next.

## Latest owner routing authorization

Opus 5.5/high is initial preferred. When Opus subscription limits are exhausted, preserve partial work and exact unfinished acceptance manifest, then the parent may switch hard/architectural work to the existing centrally authorized ChatGPT/OpenAI/Codex route. Gemini is authorized for light subtasks. This quota exception supersedes the earlier Opus-only architectural rule. Verify actual model/provider on each execution; no paid-API billing substitution, OAuth copying, or unrelated provider-config changes.

## Publication gates

Public target owner is coca-in-a-cola, not coca-in-a-cola-iaac. Commit/checkpoint only develop after independent acceptance. Original GDD remains a private immutable subdocument until publication rights are clear. Choose an explicit original-code license before public code publication and verify each imported license, credits and exact revision/file checksum in THIRD_PARTY.md.
