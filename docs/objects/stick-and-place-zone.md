# stick-and-place-zone

Original GDD sections: 4,5. Status: F3 production greybox implemented; visual/export acceptance pending. `scripts/interactables/route_item.gd` extends the existing Interactable contract; `scripts/level_full.gd` builds and binds production items.

## Actual implementation and verification limits

- GRAB uses a 2m camera physics ray, excluding the player; only the first collider may be the stick target. E outside range, aimed away, or occluded does nothing. On success the red box disappears, its collision layer clears, and praise completion reveals a camera-child red box as the carried stick.
- PLACE requires carrying, actual Area3D overlap and a fresh E; it reveals the placed box and removes the camera carry after praise. Phase eligibility and one-shot `done` prevent duplicate completion.
- `tests/test_f3_route.gd` contains a movement/input-only successful route and separate explicitly positioned fixtures for distance, real occluder, eligible-ray dismissal-E consumption and capsule growth. Fixture placement is NOT traversal evidence. Camera-reset motion is sent only after the deferred PLACE modal is dismissed.
- F4 object/material detailing, F5 carry/footstep/breathing sound and F6 effect polish remain outside this greybox. Native rendered readability and exported OS-input acceptance remain pending.

## Responsibility and contract

Grab E only aimed within2m; invalid attempts do nothing while timer runs. Carry stick lower-centre like in teeth; place only carrying+inside marked zone+E. Emit grabbed/placed exactly once; clear carried visual after placement.

## Acceptance and evidence

Test actual production signals/resources, deterministic failure paths and restart cleanup. Record command, exit, tested source identity and evidence path; add visual/audio evidence where relevant. Source values override this synopsis. No phase accepted by documentation alone.
