# command-overlay

Original GDD sections: 3 (plus §9 accessibility options, §10 appearance sound). Status: **IMPLEMENTED (F1), awaiting parent acceptance.** This is not the complete foundation or the complete game.

## Responsibility and contract

Portable addon at `addons/command_overlay/`. API and behaviour reference: [addon README](../../addons/command_overlay/README.md). Required API: `shown`, `dismissed`, `show_line`, `show_text`, `show_sequence`, `is_active`, `force_hide`, plus `OverlayLine` with all 15 GDD fields. Extensions: `cancelled`, `word_shown`, `sequence_finished`, `is_input_blocked()`, `reduce_flashes`, `reduce_shake`, and the `hide_fade_time` field.

Decisions taken where the source is silent:
- Input lock counts from the **last** word's appearance, so a per-word line cannot be skipped mid-reveal.
- `FLASH` always auto-hides and never consumes input, whatever its `dismiss` value.
- `BLACK` also applies `world_time_scale` under pause, so both modal modes thaw the same way.
- `force_hide`, replacement, scene change and tree exit emit `cancelled`, not `dismissed`. This keeps a director from starting a timer on a cancelled line.

## Acceptance and evidence

- `godot4 --headless --path . -s res://tests/run_tests.gd` → 15/15 tests, 148 assertions passing on Godot 4.7.2 headless (2026-10-29). Diagnostic: one "ObjectDB instance leaked at exit" warning from the runner is still uninvestigated.
- `godot4 --headless --path . -s res://tools/portability_test.gd` → fresh empty project, two variants, import + smoke + demo autoplay.
- Demo autoplay: `godot4 --headless --path . res://addons/command_overlay/demo/demo.tscn -- --overlay-demo-autoplay`.

Pending (cannot be shown headless): visual check of glow, aberration, desaturation and flash on Forward+ GPU rendering; the camera-flash audio file (missing, see THIRD_PARTY.md); the phase build and walkthrough video; GPU performance of the full-screen glow shader.
