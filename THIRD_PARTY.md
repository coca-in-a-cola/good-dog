# Third-party assets and provenance

Imported third-party files are listed in the table below. No third-party addon or shader has been imported. Candidate URLs/licenses in the original GDD are not verified import approvals.

Original GOOD DOG code is MIT (see `LICENSE`, which also lists these exceptions). Fonts stay OFL-1.1 and are not relicensed. The private original GDD is outside every license here.

Before each subsystem: built-in Godot → Asset Library → GitHub/godotshaders → CC0 libraries → primitive Blender MCP → custom code only with reason. Record each search/rejection/choice. No commercial-game rips, NC or unknown licenses.

| Local path | Name | Exact source URL | Author | License/SPDX | Version/commit | SHA-256 | License file | Credits obligation | Verified |
|---|---|---|---|---|---|---|---|---|---|
| `addons/command_overlay/assets/fonts/NotoSans-Bold.ttf` | Noto Sans Bold (hinted TTF), overlay default font | https://raw.githubusercontent.com/notofonts/notofonts.github.io/28b15b4b43b7bed62b5cf6e6b0b5ff5846270535/fonts/NotoSans/hinted/ttf/NotoSans-Bold.ttf | The Noto Project Authors | OFL-1.1 | NotoSans-v2.015 (source tag @ notofonts/latin-greek-cyrillic `c4a321e123e4d4ff315f57f4e0adf294fe3a95be`; binary publish commit `28b15b4b43b7bed62b5cf6e6b0b5ff5846270535`, 2024-11-21) | `1df075a380fc7cb898acf64c1f7b3b4dd780de3caa860178bf929de35817a913` | `addons/command_overlay/assets/fonts/OFL.txt` | Ship OFL.txt with the font (export includes it); do not sell the font alone; Reserved Font Name rules apply to modified versions | 2026-10-29 |
| `addons/command_overlay/assets/fonts/NotoSans-Regular.ttf` | Noto Sans Regular (hinted TTF), bundled for `font_override` use | https://raw.githubusercontent.com/notofonts/notofonts.github.io/28b15b4b43b7bed62b5cf6e6b0b5ff5846270535/fonts/NotoSans/hinted/ttf/NotoSans-Regular.ttf | The Noto Project Authors | OFL-1.1 | same as above | `478c558ea716033cd60c03438f628dfa75694dcf6b5f6d505a2f05fd2b4f3823` | same | same | 2026-10-29 |
| `addons/command_overlay/assets/fonts/OFL.txt` | OFL notice, "Copyright 2022 The Noto Project Authors (https://github.com/notofonts/latin-greek-cyrillic)" | https://raw.githubusercontent.com/notofonts/latin-greek-cyrillic/c4a321e123e4d4ff315f57f4e0adf294fe3a95be/OFL.txt | The Noto Project Authors | OFL-1.1 (text) | `c4a321e123e4d4ff315f57f4e0adf294fe3a95be` | `cee9892f9f0cc8fe882c9e9537ee6a89621d86ee7ceaf70b02e2b2b1c25c061a` | itself, unmodified | — | 2026-10-29 |
| `addons/command_overlay/assets/sfx/source/745481_12979719-hq.ogg` (not imported/exported) | "35mm Film Camera (with flash) - Shutter", Freesound public HQ preview | https://freesound.org/people/artem_uanety/sounds/745481/ (bytes: https://cdn.freesound.org/previews/745/745481_12979719-hq.ogg) | artem_uanety | CC0-1.0 | Freesound sound 745481, uploaded 2024-07-10 | `4d54fdd0e16f1abef54abbe11b4c7e0b8bdd61cef265178a6b806b9f53a5755c` | `addons/command_overlay/assets/sfx/PROVENANCE.md` | None (credit voluntary) | 2026-10-29 |
| `addons/command_overlay/assets/sfx/camera_flash.wav` | Camera-flash appearance sound (shutter click + flash whine), trimmed/mixed from the row above with ffmpeg | as above | artem_uanety (adaptation: GOOD DOG contributors) | CC0-1.0 | derived; exact command in PROVENANCE.md | `4a9fb5ea527c07f53119e9efa1489d7c7eb12c5fa49df5a452c37132c5a4a23a` | `addons/command_overlay/assets/sfx/PROVENANCE.md` | None | 2026-10-29 |
| Godot Engine 4.7.2-stable runtime (export templates `linux_release.x86_64`) | Godot Engine | https://godotengine.org | Godot Engine contributors; Juan Linietsky, Ariel Manzur | MIT (+ bundled third-party components, see Godot `COPYRIGHT.txt` / `Engine.get_license_info()`) | 4.7.2.stable.official.ed1daf0bf | — | Godot LICENSE.txt / COPYRIGHT.txt | Include the Godot MIT notice and third-party notices in release credits; full list from `Engine.get_copyright_info()` (credits screen pending, F7) | 2026-10-29 |

Rejected: Freesound 655045 "Camera Flash Sound.wav" (juanstrydom2002, CC0): its preview clips at 0 dBFS throughout. Original WAVs need a Freesound login and were not downloaded. Public preview bytes of the same CC0 works were used instead.

## Search log

### command_overlay (F1, 2026-10-29)

| Need | Step reached | Decision |
|---|---|---|
| Layer, backdrop, labels, outline | 1 — built-in | `CanvasLayer`, `ColorRect`, `Label`, `LabelSettings` (outline 8–16 px). |
| Animation easing (punch 1.2→1.0, thaw 0.25 s, fade) | 1 — built-in | `Tween.interpolate_value` (Tween's easing math) evaluated against a real-time clock. Node-bound `Tween`s are not used because they follow `Engine.time_scale`/pause and cannot be stepped deterministically in tests. |
| Glow under text (blurred copy, 12–24 px) | 1 — built-in | `CanvasGroup` (mipmapped backbuffer) holding a copy of the label, plus an original 7×7 Gaussian `canvas_item` shader (`shaders/glow_blur.gdshader`). Per GDD §3 godotshaders.com blur shaders were the next option. They were not retrieved because no network retrieval was performed in this run and the built-in route was sufficient. |
| OVER_WORLD desaturate/darken 40% | 1 — built-in | `hint_screen_texture` shader (`shaders/world_tint.gdshader`), original. |
| Chromatic aberration burst 0.1 s | 1 — built-in | `BackBufferCopy` + original screen shader (`shaders/chromatic_burst.gdshader`). The GDD-listed Post Process plugin and Godot Screen Effects (both MIT per the GDD) are **not** imported; deferred to original phase 6 with license verification. |
| Jitter / per-character effects | 1 — built-in | Whole-text jitter by moving the text root 1–2 px per frame (seeded `RandomNumberGenerator`). Built-in `[shake]` deliberately avoided (GDD §3 known issue). Per-character `RichTextEffect` and Text Animator (Febucci, license/price unverified) are not used. |
| Font | 1 → upstream OFL | Godot 4.7's built-in fallback measured as Open Sans SemiBold, not Noto. Per the owner's GDD decision (Noto Sans / Noto Sans Bold), the actual Noto Sans v2.015 files are bundled in the addon. `Overlay.default_font` = Noto Sans Bold; `OverlayLine.font_override` still wins. |
| Camera-flash appearance sound | 4 — CC0 libraries (Freesound, CC0 filter) | Freesound 745481 (CC0), trimmed to a 0.46 s shutter click + flash whine (see PROVENANCE.md). It is `Overlay.default_sfx_appear`, played once per appearing word, with no hide sound. Tests verify a non-silent PCM waveform. |

Original code: MIT (`LICENSE`). Exported builds must ship the Godot MIT/third-party notices and the Noto OFL text (OFL.txt is packed into the PCK by `export_presets.cfg`; an in-game credits screen is later scope). Godot's default Open Sans is still compiled into the engine binary as the UI fallback (demo buttons), and Godot's own notices cover it. Sonniss custom terms require review; prefer CC0 alternatives when uncertain.
