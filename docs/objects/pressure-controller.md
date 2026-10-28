# pressure-controller

Original GDD sections: 4,9,10. Status: F2 IMPLEMENTED adapter (`scripts/pressure_controller.gd`), parent acceptance pending. Audio layers (F5) and post-processing (F6) are not implemented.

## Actual implementation (F2)

- `set_pressure_level(0–5)` comes from `CommandDirector.pressure_changed`. Inspector Curves (x = level/5) drive hum dB, vignette 0.25→0.75, aberration (0 until level 3, 0.006 at 5), grain, saturation 1.0→0.7, trauma 0→0.35, light energy and coldness. Per-level arrays hold metronome 0/0/60/90/120/0 BPM, heartbeat (level 4), tinnitus (level 5) and ambient (off at 5). `values.audio_rung = level + 1`.
- The BARK cell consumes lamp energy/colour, environment saturation, a radial vignette and camera trauma. `reduce_shake` scales trauma to 30% and `reduce_flashes` zeroes aberration, both read from Overlay. `nudge()` is the leash micro-step; it does not touch the ladder.
- The overlay 800 Hz bus filter and the sounds are F5.

## Responsibility and contract

Curves map levels0–5 separately from transform0–4 into audio, lighting and camera/post effects. Escalation metronome60/90/120BPM, heartbeat and final tinnitus; hide timer; F3 debug only. Overlay bus filtering800Hz excludes UI flash.

## Acceptance and evidence

Test actual production signals/resources, deterministic failure paths and restart cleanup. Record command, exit, tested source identity and evidence path; add visual/audio evidence where relevant. Source values override this synopsis. No phase accepted by documentation alone.
