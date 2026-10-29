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

## Implemented F4 representative slice (sample accepted; full F4 pending)

`tools/art/source/representative_slice.blend` is an editable metre-scale Blender source, authored through the existing discovered Blender MCP stdio tools. `assets/models/f4/` holds three GLBs: beveled cell/corridor dressing, continuous tapered bent stick with knot/grain/dry-blood faces, and a cyan placement annulus. `scripts/representative_art.gd` integrates visual-only meshes and Noto numbered doors; `level_full.gd` uses the same stick in pickup/carry/placed consumers. Existing cot/toilet rendered CSG is alpha-hidden while its collision is retained. All accepted route coordinates, timers, physics shapes, target body and pit remain unchanged. The old circle fill is hidden rather than permanent amber; its radius remains 1.25m, outlined by the authored annulus.

Sparse enamel bunk/mattress/pillow, abstract cube toilet rim/inset/cistern, twin-diffuser fluorescent housings, door-jamb/latch/number hints, wall-base trim and one restrained floor cable establish the sample. Existing faint GOOD BOY #46/tallies remain. Palette is near-flat white/cyan with blood as the only saturated world accent; no yellow kit was imported. Original MIT geometry is disclosed in THIRD_PARTY.md and exact bytes in `assets/models/f4/provenance.json`.

Not full F4 acceptance: sourced CC0 kit/tile bytes, tracking CCTV, remaining corridor/pit dressing including collar, indirect GI/volumetric fog and final lighting remain open. The three supplied revision2 carry, placed and final-eye native stills pass sample review: a narrow irregular twig, separated dried-blood patches and visible bark replace the rejected fin and straight band. This authorizes only an ART SOURCE checkpoint; software captures do not certify target-GPU performance, exported acceptance or F5–F7. Test receipts and bounded gameplay stills remain private in `evidence/f4/`.

### Accepted-sample repair: revision2

The branch is now one connected 468-triangle mesh with a tapered continuous bend, integrated torn offshoot, warm desaturated ash bark variation and discontinuous matte dried-blood faces, not a grey tool/red sleeve. Carry is 0.48 scale at (0,-0.24,-0.48). Twelve built-in Decals consume the original MIT 512×512 alpha silhouette `blood_pool.png`, authored by `tools/art/stain_texture.py`; no external CC0 acquisition is claimed. The old extruded trail and filled circle are removed/hidden; annulus color is #27899C. Paint #EEF2F2 roughness .78, sealed floor #BFCDD0/.48, ceramic #F4F8F8/.23 and bunk leg metal #67848B/.36/metallic .65 separate clinical surfaces. Shadowed lights and SSAO (.35m radius, 1.4 intensity) ground props without clutter.

The upper-right black carry-view shape was `ObservationWindow`, the original 6×2.3m surveillance pane at (3.98,1.5,-24.6). It is retained with four explicit metal perimeter reveals. Door numerals have corrected inward facing and darker, larger glyphs. Reviewed native stills are in `evidence/f4/revision2/`; the .45m circle view is explicitly an art fixture after authentic transformation, with capture-only leash deactivation/repositioning, not traversal evidence. No production gameplay coordinate, collider or camera specification changed. Original scene/GLB hashes and per-mesh metre/triangle facts remain in `assets/models/f4/`.
