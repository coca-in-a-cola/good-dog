#!/usr/bin/env python3
"""Parent-owned F3 capture; produces evidence, never an acceptance receipt."""
import argparse, hashlib, json, os, re, signal, subprocess, sys, time
from pathlib import Path
ROOT = Path(__file__).resolve().parents[2]
BAD = re.compile(r'(?m)^(?:SCRIPT ERROR:|ERROR:|WARNING:)|leaked at exit|resources still in use|F3_CHECK_FAIL')
def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--headless-only', action='store_true')
    args = parser.parse_args()
    out = args.output.resolve()
    if not out.is_relative_to(ROOT/'evidence/f3'):
        parser.error('output must be a new directory beneath evidence/f3')
    out.mkdir(parents=True, exist_ok=False)
    deadline = time.monotonic()+70*60
    identity = {str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest()
                for folder in ['scripts','scenes','data','tests','tools','addons']
                for p in (ROOT/folder).rglob('*') if p.is_file()}
    (out/'source-identity.json').write_text(json.dumps(identity,indent=2))
    results = {}
    def run(name, command, marker=None):
        with (out/(name+'.log')).open('w') as log:
            p = subprocess.Popen(command,cwd=ROOT,stdout=log,stderr=subprocess.STDOUT,start_new_session=True)
            try: code = p.wait(timeout=min(deadline-time.monotonic(),3900))
            except BaseException:
                os.killpg(p.pid,signal.SIGKILL); p.wait(); raise
        text = (out/(name+'.log')).read_text()
        results[name] = {'exit':code,'clean':not bool(BAD.search(text)), 'marker': marker is None or marker in text}
        (out/'results.json').write_text(json.dumps(results,indent=2))
        if code or BAD.search(text) or (marker and marker not in text):
            raise RuntimeError(name+' failed: inspect complete log')
        print(name,results[name],flush=True)
    if args.headless_only:
        run('headless-route',['godot4','--headless','--path',str(ROOT),'--fixed-fps','60','res://tools/capture/f3_capture.tscn'],'F3_CAPTURE_FINISHED failures=0')
    else:
        run('rendered-route',['xvfb-run','-a','-s','-screen 0 1280x720x24','godot4','--path',str(ROOT),'--resolution','1280x720','--audio-driver','Dummy','--rendering-method','forward_plus','--rendering-driver','vulkan','--write-movie',str(out/'walkthrough.avi'),'--fixed-fps','30','res://tools/capture/f3_capture.tscn'],'F3_CAPTURE_FINISHED failures=0')
        run('encode',['ffmpeg','-nostdin','-v','error','-i',str(out/'walkthrough.avi'),'-c:v','libx264','-crf','18','-pix_fmt','yuv420p','-c:a','aac',str(out/'walkthrough.mp4')])
        run('decode',['ffmpeg','-nostdin','-v','error','-xerror','-i',str(out/'walkthrough.mp4'),'-f','null','-'])
        run('probe',['ffprobe','-v','error','-show_streams','-show_format','-of','json',str(out/'walkthrough.mp4')])
        # Keep every earlier export untouched, just like the exclusive evidence
        # directory. This run's binary belongs to this run's source manifest.
        build = out/'linux'; build.mkdir(exist_ok=False)
        run('export',['godot4','--headless','--path',str(ROOT),'--export-release','Linux',str(build/'good-dog.x86_64')])
    if any(hashlib.sha256((ROOT/p).read_bytes()).hexdigest()!=h for p,h in identity.items()):
        raise RuntimeError('source changed during capture')
    (out/'STATUS.txt').write_text('PENDING parent native pixel/audio review, exported warning/menu/START interaction and independent acceptance. No publication.\n')
    print('F3_HANDOFF_EXIT=0 (NOT ACCEPTED)')
if __name__ == '__main__':
    try: main()
    except Exception as exc:
        print('F3_HANDOFF_EXIT=1',repr(exc)); sys.exit(1)
