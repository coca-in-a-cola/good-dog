# GOOD DOG style guide — derived, not a replacement GDD

First-person sterile white/cyan liminal complex; submission, emptiness and surveillance, not action combat. English-only game text; no voice-over. References are mood references, never asset sources.

- World #E9EEF0; shadows/fog #BFE3EA → #7FA9B3; blood only #C1121F matte; pit/mirror #000000; praise-only amber #FFC879 ≤0.5s.
- Commands uppercase Noto Sans (built-in); one word 85–90% screen width, phrases ≤3 lines / 90% each. White #FFFFFF, cyan glow #9FF4FF alpha 0.5–0.7; failure #B3261E. Preserve original exact punctuation in resource text.
- Hard cuts, not soft exposition: appear punch 1.2→1.0 /0.08s; per-word 0.35–0.6s; disappear instant or0.12s; camera-flash sound only on appearance, never voice or dismissal sound.
- BLACK pauses; OVER_WORLD time_scale0.05, saturation0.2, dim40%; FLASH0.4–0.8s without pause. Fresh press after0.35s; consume close input; thaw0.25s.
- CSG greybox before licensed models; real metre scale, custom low-poly objects ≤2000 triangles, transforms applied, glTF2 .glb. Roughness0.6–0.8; reject yellow backrooms palette.
- Spaces: cell4×5×3m; corridor2.5×18m; observation8×8m; pit room radius12m /height6m, pit radius1.5m, trigger2m below edge.
- Sound is primary timer feedback, no visible countdown except F3 debug. No overseer voice. Master/SFX/Ambience/UI/Music, limiter−1dBTP; target−16…−18 LUFS. Praise has a recurring bell; no speech synthesized as a shortcut.
- Exposure warning before menu; reduced flashes and reduced shake (30% trauma); each effect individually disabled. GPU target60FPS1080p GTX1060/RX580 requires real hardware evidence.

Exact source tables and values remain authoritative; each object article links the relevant source section.

## Implemented F3 greybox versus target style

`scripts/level_full.gd` currently builds CSG white rooms, red box stick/drag marks, a pale emissive place circle, black observation window, simple cyan observer boxes and a subtractive pit floor. The carried stick is a camera-child box, not finished teeth/hand art. These are production collision/interaction placeholders, not final asset/style acceptance. The Noto Sans overlay font is bundled, not an engine fallback.

F4 dressing/CCTV/numbered doors and material/lighting fidelity remain open; F5 soundscape/mixing, F6 effect polish and F7 exported interaction/performance acceptance are not certified by native headless tests. No new art or sound is introduced by the verification rescue. Parent-owned rendered capture and native pixel/audio review must establish what is actually visible/audible before acceptance.
