# game-state-and-finale

Original GDD sections: 5,12. Status: F3 production greybox route and lifecycle implemented, parent rendered/export acceptance pending. `scripts/level_full.gd` drives GRAB/PLACE/pit-entry/JUMP/fall; `GameState.enter_finale()` now changes to `scenes/finale.tscn`, whose `scripts/finale.gd` owns the staged ending and credits. Exact strings remain `CONGRATULATIONS!` / `YOU WERE A GOOD DOG!`.

## F3 verification boundaries

The native full-route test uses movement, mouse and fresh keyboard events without teleporting or notifying completion. It asserts the old level is freed, the four-second fall is not shortened, finale text, credits→menu and fresh replay. Later GRAB/PLACE/JUMP ladders each exercise QUIET without timer penalty, pause freeze, six-rung failure and scene release. RUN AWAY coverage uses fresh Escape then the production button signal (not an OS click) in each later command, and checks fresh item/gate/leash/transform/director state. Separate spatial and wall-slide tests explicitly use fixtures; they are not movie traversal evidence.

Rendered finale readability, celebration/audio fidelity, exported OS-input behavior and F7 acceptance are pending. No headless result constitutes publication or final visual/audio approval.

## Actual implementation (F2)

- Every scene change calls `Overlay.force_hide()` first, then clears pause, curtain and mute, sets time_scale to 1 and releases held actions. A restart reloads the level, so director, pressure, transform and player are new. Nothing is persisted.
- Esc → OBEY / RUN AWAY (no confirmation). Pause is refused while the overlay owns the world.
- Tests: three menu/restart/failure cycles with connection-leak checks in `tests/test_f2_core.gd`.

## Responsibility and contract

Warning→menu→3s prologue→BARK→GRAB→PLACE→pit-entry transform4→JUMP→4s fall→bright confetti/celebration→credits. BAD DOG black then3s silence→menu. Pause OBEY/RUN AWAY; fresh restart clears timers/connections/transforms. Final exact English strings preserved.

## Acceptance and evidence

Test actual production signals/resources, deterministic failure paths and restart cleanup. Record command, exit, tested source identity and evidence path; add visual/audio evidence where relevant. Source values override this synopsis. No phase accepted by documentation alone.
