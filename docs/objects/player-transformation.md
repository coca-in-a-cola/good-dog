# player-transformation

Original GDD sections: 6. Status: F2 IMPLEMENTED core (`scripts/good_dog_player.gd` over vendored ar-bh `addons/basic_fps_controller`, `scenes/player.tscn`, `scripts/transform_step.gd`, `scripts/transform_controller.gd`, `data/transform/step_0..4.tres`), parent acceptance pending.

## Actual implementation (F2)

- Controller: ar-bh Basic FPS Controller (MIT, commit 7f50a91, byte-verified; see THIRD_PARTY.md), adapted by inheritance. Jump/sprint are disabled (actions exist with no key, `jump_velocity = 0`); the base has no crouch, wallrun, dash or fly.
- TransformController blends all row values over 2.5 real seconds via the step's Curve. The blend pauses with Esc, control is kept, and the change is irreversible. The capsule height follows the eye height (+0.1 m), and growth is refused if `test_move` collides.
- Values come from data only: eye 1.70/1.40/1.05/0.70/0.45; speed 3.0/3.6/4.4/5.3/6.2; FOV 75/78/82/86/90; look-up 89/70/55/40/30; bob 1.8→3.2 Hz with falling amplitude; sensitivity +10%/step; footstep sets.
- F3 adds a camera-child greybox in-mouth stick and pre/post-move leash integration in the adapter, preserving vendor files. Native low-ceiling collision fixtures verify refused growth leaves both eye and capsule height unchanged, then growth succeeds after removing the blocker.
- Open: no acceleration/inertia hook (velocity is assigned instantly). Footstep audio and breathing remain F5. The transition SFX, vignette pulse and FOV breathing are F6; rendered/export acceptance and hardware performance remain pending.

## Responsibility and contract

Adapt verified licensed FPS controller; disable jump/sprint/crouch/wallrun/dash/fly. Five state rows: eye1.70/1.40/1.05/0.70/0.45m; speed3.0/3.6/4.4/5.3/6.2; FOV75/78/82/86/90; max-up89/70/55/40/30°. Tween2.5s while retaining control; capsule/test_move safe; data/resources and adapter signals.

## Acceptance and evidence

Test actual production signals/resources, deterministic failure paths and restart cleanup. Record command, exit, tested source identity and evidence path; add visual/audio evidence where relevant. Source values override this synopsis. No phase accepted by documentation alone.
