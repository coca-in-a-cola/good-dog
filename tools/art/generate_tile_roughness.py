"""Generate procedural subtle roughness texture for F4 observation tiles.
Standard library only (struct, zlib).
"""
import struct
import zlib
from pathlib import Path

DEST = Path("/home/tyler/workspaces/good-dog/assets/materials/f4/Tiles004_subtle_roughness.png")
DEST.parent.mkdir(parents=True, exist_ok=True)

WIDTH = 128
HEIGHT = 128

raw = bytearray()
for y in range(HEIGHT):
    raw.append(0)  # filter type 0 (None)
    for x in range(WIDTH):
        # Subtle tile pattern with ~0.73 nominal roughness (186 / 255)
        gx = x % 16
        gy = y % 16
        if gx == 0 or gy == 0:
            val = 210  # grout line roughness
        else:
            noise = ((x * 37 + y * 19) % 17) - 8
            val = 186 + noise
        raw.append(max(0, min(255, val)))

def chunk(tag: bytes, data: bytes) -> bytes:
    return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xffffffff)

png_bytes = (
    b"\x89PNG\r\n\x1a\n"
    + chunk(b"IHDR", struct.pack(">IIBBBBB", WIDTH, HEIGHT, 8, 0, 0, 0, 0))
    + chunk(b"IDAT", zlib.compress(bytes(raw)))
    + chunk(b"IEND", b"")
)

DEST.write_bytes(png_bytes)
print(f"Generated {DEST} ({len(png_bytes)} bytes)")
