# leash-and-pit

Original GDD sections: 7. Status: F3 production greybox implemented, parent rendered/export acceptance pending. `GoodDogPlayer` constrains velocity before `move_and_slide` and ratchets/clamps position afterward, without changing vendor files. Hall entry applies transformation step 4 and activates the leash around (0,0,-40.6).

## F3 verification and remaining work

`test_actual_sixty_second_character_wallslide_leash` executes 3600 native physics-frame ticks at 60Hz with seed 6147, actual CharacterBody3D movement, corridor contacts and radius-growth tolerance 0.00001. It explicitly positions a fixture; it is not traversal evidence. The standard runner isolates F3 with fixed-fps 60 in a bounded child, leaving F1 wall-clock overlay tests unaccelerated. This is 60 simulated physics seconds, not a claim of 60 wall-clock seconds.

The input-only route crosses the real hole trigger below the uncapped floor, stops the timer, disables controls and waits four clock seconds before finale. RUN AWAY regressions rebuild later-phase scenes, gates, items, transformation and leash. Chain audio/visual fidelity, final fall presentation and rendered/export input acceptance remain pending F5–F7 work.

## Actual contract (F2)

`activate(center, start_pos)`, `deactivate()`, `reset()`, `constrain_velocity(pos, vel)` (removes the outward radial part, guards the zero vector, emits `leash_pulled`), `clamp_position(pos)` (ratchet `max_d = min(max_d, d)` and clamp), `on_rung()` (15% contraction only when `contract_on_rung`, default off). Pure-math unit tests are in `tests/test_f2_core.gd`; they do not replace the F3 physics regression.

## Responsibility and contract

Constrain horizontal radial outward velocity, retain tangential/inward motion, ratchet max_d, clamp after move_and_slide. Zero-vector guard and60s randomized input/wall-slide test. Default contraction flag off; optional15% per rung. Chain feedback without timer reset; pit trigger→controls disabled/20° down/4s fall.

## Acceptance and evidence

Test actual production signals/resources, deterministic failure paths and restart cleanup. Record command, exit, tested source identity and evidence path; add visual/audio evidence where relevant. Source values override this synopsis. No phase accepted by documentation alone.
