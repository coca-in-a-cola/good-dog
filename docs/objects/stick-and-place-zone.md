# stick-and-place-zone

Original GDD sections: 4,5. Status: F3 production greybox implemented; visual/export acceptance pending. `scripts/interactables/route_item.gd` extends the existing Interactable contract; `scripts/level_full.gd` builds and binds production items.

## Actual implementation and verification limits

- GRAB uses a 2m camera physics ray, excluding the player; only the first collider may be the stick target. E outside range, aimed away, or occluded does nothing. On success the connected authored branch GLB disappears, its unchanged target collision layer clears, and praise completion reveals the same GLB camera-child lower-center at (0,-0.24,-0.48), visual scale 0.48. World anchors/collision remain fixed; mesh-only offsets settle pickup/placed wood onto the floor.
- PLACE requires carrying, actual Area3D overlap, player horizontal origin within radius1.25m and a fresh E; it reveals the authored placed stick and removes the camera carry after praise. Only the thin cyan annulus is visible (old filled disk hidden); phase eligibility and one-shot `done` prevent duplicate completion.
- `tests/test_f3_route.gd` contains a movement/input-only successful route and separate explicitly positioned fixtures for distance, real occluder, eligible-ray dismissal-E consumption and capsule growth. Fixture placement is NOT traversal evidence. Camera-reset motion is sent only after the deferred PLACE modal is dismissed.
- Revision2 stick/carry/placement native pixels pass representative-sample review only. Remaining F4 object/material detailing, F5 carry/footstep/breathing sound, F6 effect polish and exported OS-input acceptance remain pending; this is not full F4 acceptance.

## Responsibility and contract

Grab E only aimed within2m; invalid attempts do nothing while timer runs. Carry stick lower-centre like in teeth; place only carrying+inside marked zone+E. Emit grabbed/placed exactly once; clear carried visual after placement.

## Acceptance and evidence

Test actual production signals/resources, deterministic failure paths and restart cleanup. Record command, exit, tested source identity and evidence path; add visual/audio evidence where relevant. Source values override this synopsis. No phase accepted by documentation alone.
