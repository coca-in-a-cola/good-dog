# audio-and-accessibility

Original GDD sections: 9,10. Status: F5 audio IMPLEMENTED (source increment, not accepted). Accessibility (reduced flashes/shake) is F2/F6.

## Actual implementation (F5)

- **Buses** (`default_bus_layout.tres`): `Master` [HardLimiter, ceiling −1.5 dB] ← `SFX` [TransientCompressor −14 dB 3:1, OverlayMuffle LPF 800 Hz], `Ambience` [OverlayMuffle], `UI` (−3 dB, no effects), `Music` (no effects); `Drone` [PressureSqueeze LPF] → Ambience; `ReverbCell` (room 0.2/damp 0.5), `ReverbCorridor` (0.6/0.3), `ReverbPit` (0.9/0.2, predelay 280 ms + feedback 0.55 late echo) → SFX, wet-only returns.
- **AudioMix** autoload (`scripts/audio/audio_mix.gd`) points `Overlay.sfx_bus` at UI, so the camera flash bypasses the filter, and the addon stays portable. While `Overlay.is_active()` the SFX and Ambience low-pass is at 800 Hz. It opens exponentially over `Overlay.unfreeze_time` on real time, then disables. It also owns real-time bus fades and resets them on every scene change except falling/failed.
- **LevelAudio** (`scripts/audio/level_audio.gd`, installed by `level_full.gd`) consumes only existing signals. Barks: five tiers by `TransformController.current_step`. Footsteps: `GoodDogPlayer.footstep(set)` mapped shoes/barefoot/shuffle/claws, four round-robin variants each. Praise plays on `command_succeeded` when the command has a success line. Stick thuds come from interactable `completed`. The leash clinks on `leash_pulled` (0.6 s cooldown). The transformation sound comes from `TransformStep.transition_sfx`. Panting starts at step ≥ 3 and runs faster at step 4. The prologue door clanks. Corridor background events (distant barks, door slams) are seeded. Applause plays muffled behind the mirror after PLACE. The praise bell sounds from the pit every 6 s during JUMP. On the fall: wind plays, Ambience fades over 3 s, breathing stays, and everything hard-cuts at 3.7 s. BAD DOG: every layer stops, then the cut sound plays.
- **Reverb zones**: Area3D on physics layer 20 (cell, corridor, observation + connector → corridor bus, pit hall + shaft cylinder). 3D players query only that layer.
- **Pressure layers** (from `PressureController.pressure_applied`): hum +dB curve, drone level and low-pass squeeze, metronome 60/90/120 BPM, heartbeat (level 4), tinnitus (level 5) with Ambience faded out, panting louder per level. The timed layers stop with the Esc/BLACK pause like the ladder timer.
- **Finale** (`finale.gd`): popper + confetti and applause on SFX, jingle on Music.
- **Assets**: 40 original synthesized WAVs (`tools/audio/synth_f5.gd`, deterministic). Catalog in `THIRD_PARTY.md`, manifest in `assets/audio/PROVENANCE.json`.

## Measured mix (fixture, not a walkthrough)

`tools/audio/mix_capture.gd` drives the production level in real time and records Master after the limiter. In the gameplay programme (70 s: prologue → BARK → praise → transformation → corridor → full GRAB ladder → BAD DOG), integrated loudness was **−17.06 LUFS** and true peak **−1.30 dBTP**; the short-term level rises from about −19 to −14 LUFS up the ladder. In the finale programme it was **−17.37 LUFS** and **−2.74 dBTP**. ffmpeg `ebur128` agrees with the GDScript meter to 0.1 LU (cross-checked on an earlier capture: −23.2 vs −23.18). This was measured on the headless Dummy driver at 44.1 kHz, not on a listening device.

## Open

Human listening review (bark morph, praise warmth, loop seams, tinnitus comfort); pit-hall/finale coverage in a full real-time capture; per-effect audio settings; a CC0 recording replacement for tier-4 bark if the listening review rejects the synthesis.

## Acceptance and evidence

Test actual production signals/resources, deterministic failure paths and restart cleanup. Record command, exit, tested source identity and evidence path; add visual/audio evidence where relevant. Source values override this synopsis. No phase accepted by documentation alone.
