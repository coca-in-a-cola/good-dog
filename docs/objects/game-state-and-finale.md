# game-state-and-finale

Original GDD sections: 5,12. Status: F2 IMPLEMENTED for warning/menu/prologue/BARK/failure/pause/restart (`scripts/game_state.gd`, `scenes/warning.tscn`, `scenes/main_menu.tscn`, `scenes/level.tscn`), parent acceptance pending. GRAB/PLACE/pit entry, the fall, finale and credits remain OPEN (F3); `enter_falling`/`enter_finale` only set state. `GameState.FINAL_LINES` preserves `CONGRATULATIONS!` / `YOU WERE A GOOD DOG!`.

## Actual implementation (F2)

- Every scene change calls `Overlay.force_hide()` first, then clears pause, curtain and mute, sets time_scale to 1 and releases held actions. A restart reloads the level, so director, pressure, transform and player are new. Nothing is persisted.
- Esc → OBEY / RUN AWAY (no confirmation). Pause is refused while the overlay owns the world.
- Tests: three menu/restart/failure cycles with connection-leak checks in `tests/test_f2_core.gd`.

## Responsibility and contract

Warning→menu→3s prologue→BARK→GRAB→PLACE→pit-entry transform4→JUMP→4s fall→bright confetti/celebration→credits. BAD DOG black then3s silence→menu. Pause OBEY/RUN AWAY; fresh restart clears timers/connections/transforms. Final exact English strings preserved.

## Acceptance and evidence

Test actual production signals/resources, deterministic failure paths and restart cleanup. Record command, exit, tested source identity and evidence path; add visual/audio evidence where relevant. Source values override this synopsis. No phase accepted by documentation alone.
