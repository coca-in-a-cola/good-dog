# camera_flash.wav — provenance

| Field | Value |
|---|---|
| Source | Freesound sound 745481, "35mm Film Camera (with flash) - Shutter" |
| Page | https://freesound.org/people/artem_uanety/sounds/745481/ |
| Author | artem_uanety (Freesound user id 12979719) |
| License | Creative Commons 0 (http://creativecommons.org/publicdomain/zero/1.0/), as shown on the sound page 2026-10-29 |
| Original | WAV, 48 kHz, 16-bit mono, 18.160 s, uploaded 2024-07-10 (login-only download; not retrieved) |
| Retrieved bytes | Freesound public HQ preview `https://cdn.freesound.org/previews/745/745481_12979719-hq.ogg` (Vorbis 48 kHz mono, 18.16 s) |
| Retrieved file | `source/745481_12979719-hq.ogg`, SHA-256 `4d54fdd0e16f1abef54abbe11b4c7e0b8bdd61cef265178a6b806b9f53a5755c`, 221220 bytes |
| Output | `camera_flash.wav`, PCM s16le 48 kHz mono, 0.46 s, peak −1.70 dBFS, RMS −24.03 dBFS, SHA-256 `4a9fb5ea527c07f53119e9efa1489d7c7eb12c5fa49df5a452c37132c5a4a23a` |

The recording repeats a cycle of: shutter click (~2.29 s), shutter/advance burst (~2.3–3.3 s),
rising flash-capacitor whine (~3.4–4.4 s, 9.6 → 19 kHz). The one-shot keeps the first cycle's
shutter click plus the start of the flash whine. No voice, music or synthesis.

Transformation (ffmpeg 5.1.9):

```
ffmpeg -i source/745481_12979719-hq.ogg -filter_complex "\
[0:a]atrim=start=2.25:end=2.70,asetpts=PTS-STARTPTS,afade=t=in:st=0:d=0.004,afade=t=out:st=0.22:d=0.23[click];\
[0:a]atrim=start=3.45:end=3.85,asetpts=PTS-STARTPTS,highpass=f=9000:poles=2,lowpass=f=14000:poles=2,volume=36dB,\
afade=t=in:st=0:d=0.02,afade=t=out:st=0.2:d=0.2,adelay=60[whine];\
[click][whine]amix=inputs=2:normalize=0:duration=longest,alimiter=limit=0.89:level=false,aresample=48000" \
-ac 1 -c:a pcm_s16le camera_flash.wav
```

The whine is only −57…−70 dBFS RMS in the source, hence the band-limited +36 dB boost.
Spectrograms: `evidence/f1/sfx_source_745481_spectrogram.png`, `evidence/f1/sfx_camera_flash_spectrogram.png`.
Imported uncompressed (`compress/mode=0`) so tests can verify the waveform is not silent.
`source/` carries a `.gdignore` so Godot does not import or export the preview.
