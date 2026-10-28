#!/usr/bin/env python3
"""Parent-owned bounded refresh. Captures evidence, never accepts/publishes F2.
Run from the owning parent session; all descendants are killed on timeout.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import signal
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[2]
DIAGNOSTIC = re.compile(r"(?m)^(?:WARNING:|ERROR:|SCRIPT ERROR:)|leaked at exit|resources still in use")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--preflight-only", action="store_true")
    parser.add_argument("--output", type=Path, required=True, help="NEW directory under evidence/f2-repair")
    args = parser.parse_args()
    out = args.output.resolve()
    if not out.is_relative_to(ROOT / "evidence/f2-repair"):
        parser.error("output must be under evidence/f2-repair")
    for tool in ("godot4", "xvfb-run", "ffmpeg", "ffprobe"):
        if not shutil.which(tool):
            raise RuntimeError("missing " + tool)
    if args.preflight_only:
        print("F2_REPAIR_PREFLIGHT_OK (no renderer launched)")
        return
    out.mkdir(parents=True, exist_ok=False)  # Never overwrite historical evidence.
    deadline = time.monotonic() + 65 * 60
    stills = out / "stills"
    stills.mkdir()
    env = dict(os.environ, F2_STILL_DIR=str(stills))
    # Capture exact current input identity, not a claim that old evidence matches.
    paths = sorted(p for p in ROOT.rglob("*") if p.is_file()
                   and p.relative_to(ROOT).parts[0] in ("scripts", "scenes", "data", "addons", "tools", "tests")
                   and ".godot" not in p.parts)
    paths += [ROOT / p for p in ("project.godot", "export_presets.cfg", "THIRD_PARTY.md")]
    identity = {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest() for p in paths}
    (out / "source-identity.json").write_text(json.dumps(identity, indent=2) + "\n")

    def run(label, command, marker=None, clean=False):
        log = out / (label + ".log")
        remaining = deadline - time.monotonic()
        if remaining <= 0:
            raise TimeoutError("65 minute budget exhausted")
        with log.open("w") as stream:
            child = subprocess.Popen(command, cwd=ROOT, env=env, stdout=stream,
                                     stderr=subprocess.STDOUT, start_new_session=True)
            try:
                code = child.wait(timeout=remaining)
            except BaseException:
                os.killpg(child.pid, signal.SIGKILL)
                child.wait()
                raise
        text = log.read_text(errors="replace")
        print(f"F2_REPAIR_STAGE {label} EXIT={code}", flush=True)
        if code or (marker and marker not in text) or (clean and DIAGNOSTIC.search(text)):
            raise RuntimeError(f"{label} failed; inspect {log}")

    run("full-suite", ["godot4", "--headless", "--path", str(ROOT), "-s", "res://tests/run_tests.gd"],
        "RESULT: 28 passed, 0 failed", True)
    run("headless-route", ["godot4", "--headless", "--path", str(ROOT), "--fixed-fps", "30",
                           "res://tools/capture/f2_capture.tscn"], "[f2-capture] finished, failures=0", True)
    run("rendered-route", ["xvfb-run", "-a", "-s", "-screen 0 1280x720x24", "godot4", "--path", str(ROOT),
                           "--resolution", "1280x720", "--audio-driver", "Dummy", "--rendering-method", "forward_plus",
                           "--rendering-driver", "vulkan", "--write-movie", str(out / "walkthrough.avi"),
                           "--fixed-fps", "30", "res://tools/capture/f2_capture.tscn"],
        "[f2-capture] finished, failures=0", True)
    run("encode", ["ffmpeg", "-nostdin", "-v", "error", "-i", str(out / "walkthrough.avi"),
                   "-c:v", "libx264", "-crf", "18", "-pix_fmt", "yuv420p", "-c:a", "aac",
                   "-b:a", "192k", "-movflags", "+faststart", str(out / "walkthrough.mp4")])
    run("decode", ["ffmpeg", "-nostdin", "-v", "error", "-xerror", "-i", str(out / "walkthrough.mp4"),
                   "-map", "0:v:0", "-map", "0:a:0", "-f", "null", "-"])
    run("probe", ["ffprobe", "-v", "error", "-show_streams", "-show_format", "-of", "json", str(out / "walkthrough.mp4")])
    build = out / "linux"
    build.mkdir()
    run("export", ["godot4", "--headless", "--path", str(ROOT), "--export-release", "Linux",
                   str(build / "good-dog.x86_64")], clean=True)
    run("exported-boot", ["xvfb-run", "-a", str(build / "good-dog.x86_64"), "--audio-driver", "Dummy",
                          "--resolution", "1280x720", "--quit-after", "90"], clean=True)
    if any(hashlib.sha256((ROOT / p).read_bytes()).hexdigest() != digest for p, digest in identity.items()):
        raise RuntimeError("source changed during evidence refresh")
    artifacts = {str(p.relative_to(out)): hashlib.sha256(p.read_bytes()).hexdigest()
                 for p in out.rglob("*") if p.is_file()}
    (out / "artifact-sha256.json").write_text(json.dumps(artifacts, indent=2) + "\n")
    (out / "STATUS.txt").write_text("F2 BLOCKED pending native pixel review and exported warning/menu/START interaction acceptance.\n"
                                   "Boot only is not exported interaction certification. No publication authorized.\n")
    print("F2_REPAIR_REFRESH_EXIT=0", flush=True)
    print("F2_REPAIR_REVIEW_REQUIRED (not accepted; no publication)", flush=True)


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:
        print(f"F2_REPAIR_REFRESH_EXIT=1 {type(exc).__name__}: {exc}", flush=True)
        sys.exit(1)
