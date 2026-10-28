# command-director

Original GDD sections: 4,12. Status: F2 IMPLEMENTED for BARK (`scripts/command_director.gd`, `scripts/command.gd`, `data/commands/bark.tres`, `data/lines/*.tres`, `scripts/game_state.gd`), parent acceptance pending. GRAB/PLACE/JUMP commands are F3.

## Actual implementation (F2)

- States IDLE/ORDER_SHOWN/WAITING/SUCCESS/ESCALATE/FAIL. The real-time rung timer (`GameState.clock`) starts only on `Overlay.dismissed` of the director's own line. Cancelled or replaced lines and stray signals are ignored. The timer stops while the tree is paused and is unaffected by time_scale.
- Every rung shows `Command.line_for_rung()`. Rung 6 is FLASH. When the 1 s rung expires: BLACK `BAD DOG.`, `failed` once, GameState holds 2 s, then 3 s muted, then the menu.
- `command_succeeded` fires at the instant of completion. `command_completed` + `transform_requested(step)` fire after the praise dismissal. Off-order bark → FLASH `QUIET.` without penalty.
- `bind_source`/`bind_interactable` connections are disconnected by `stop()` (also called from `_exit_tree`).
- Tests: `tests/test_f2_core.gd` (every rung, matching dismissal, B dismissal, QUIET, Esc pause, ladder reset, restart cycles).

## Responsibility and contract

Signal-driven IDLE→ORDER_SHOWN→WAITING→SUCCESS|ESCALATE|FAIL. Command resources own ladder20/10/5/3/2/1; start after dismissal, reset to20 each new task. Reject stale/duplicate completion, stop timer instantly, QUIET outside bark task does not penalize. Esc pauses, failure resets menu/no progress save.

## Acceptance and evidence

Test actual production signals/resources, deterministic failure paths and restart cleanup. Record command, exit, tested source identity and evidence path; add visual/audio evidence where relevant. Source values override this synopsis. No phase accepted by documentation alone.
