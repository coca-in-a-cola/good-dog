# rooms-and-gates

Original GDD sections: 5,8. Status: F3 continuous production greybox implemented in `scripts/level_full.gd`, loaded by `scenes/level.tscn`; parent rendered/export acceptance pending.

## Actual geometry and open details

The accepted cell/corridor is extended by removing its temporary end cap. CSG observation room is 8×8m; connector leads to a radius-12m, height-6m pit room. A subtractive CSG hole (radius 1.5m) has no floor collision cap. Cell bars close after z < -4; observation gate opens after GRAB and closes after z < -21.5; pit gate opens after PLACE and closes at hall entry z < -30.6. Input-only route assertions check physical traversal, not just gate transforms.

F4 representative slice adds visual-only Blender-authored enamel bunk/toilet/lamp/door/cable/trim dressing and Noto door numbers in the cell/immediate corridor. Original CSG collision remains; cot/toilet old materials are transparent, not removed. A tapered bent-stick GLB replaces all three red stick boxes; the circular mark gains a cyan outline and loses permanent amber. See `tools/art/source/representative_slice.blend`, `assets/models/f4/provenance.json`, and `tests/test_f4_art.gd`. The revision2 representative sample is visually accepted as an ART SOURCE checkpoint only, not full F4.

The blood trail uses original flat alpha decals; the black window and two simple cyan observer boxes remain greybox placeholders. Observer visibility still lasts one manual/real second after PLACE praise completion. Tracking CCTV, remaining corridor/pit props, sourced tile/decal and final lighting/material/GI/fog fidelity remain F4 work. F5–F7 audio, effects and hardware/export acceptance are not established by these tests.

## Responsibility and contract

One continuous cell→corridor→observation→pit route with one-way gates. Numbered doors, red drag trail, CCTV follows player, observer silhouettes briefly lit after placement; pit-room door closes immediately. Details, measurements, lighting and provenance per source.

## Acceptance and evidence

Test actual production signals/resources, deterministic failure paths and restart cleanup. Record command, exit, tested source identity and evidence path; add visual/audio evidence where relevant. Source values override this synopsis. No phase accepted by documentation alone.
