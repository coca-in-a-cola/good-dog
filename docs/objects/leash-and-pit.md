# leash-and-pit

Original GDD sections: 7. Status: F2 CONTRACT only (`scripts/leash_constraint.gd`; the post-move clamp is wired in `GoodDogPlayer`). Pit room, trigger, fall, pre-move velocity integration and the 60 s randomized physics wall-slide regression remain OPEN (F3).

## Actual contract (F2)

`activate(center, start_pos)`, `deactivate()`, `reset()`, `constrain_velocity(pos, vel)` (removes the outward radial part, guards the zero vector, emits `leash_pulled`), `clamp_position(pos)` (ratchet `max_d = min(max_d, d)` and clamp), `on_rung()` (15% contraction only when `contract_on_rung`, default off). Pure-math unit tests are in `tests/test_f2_core.gd`; they do not replace the F3 physics regression.

## Responsibility and contract

Constrain horizontal radial outward velocity, retain tangential/inward motion, ratchet max_d, clamp after move_and_slide. Zero-vector guard and60s randomized input/wall-slide test. Default contraction flag off; optional15% per rung. Chain feedback without timer reset; pit trigger→controls disabled/20° down/4s fall.

## Acceptance and evidence

Test actual production signals/resources, deterministic failure paths and restart cleanup. Record command, exit, tested source identity and evidence path; add visual/audio evidence where relevant. Source values override this synopsis. No phase accepted by documentation alone.
