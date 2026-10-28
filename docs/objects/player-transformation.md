# player-transformation

Original GDD sections: 6. Status: OPEN / not implemented.

## Responsibility and contract

Adapt verified licensed FPS controller; disable jump/sprint/crouch/wallrun/dash/fly. Five state rows: eye1.70/1.40/1.05/0.70/0.45m; speed3.0/3.6/4.4/5.3/6.2; FOV75/78/82/86/90; max-up89/70/55/40/30°. Tween2.5s while retaining control; capsule/test_move safe; data/resources and adapter signals.

## Acceptance and evidence

Test actual production signals/resources, deterministic failure paths and restart cleanup. Record command, exit, tested source identity and evidence path; add visual/audio evidence where relevant. Source values override this synopsis. No phase accepted by documentation alone.
