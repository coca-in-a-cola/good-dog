#!/usr/bin/env python3
"""Bounded credits-only evidence refresh. Never publishes or grants acceptance."""
import hashlib, json, re, subprocess
from pathlib import Path
ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT/'evidence/f3/credits-repair'
def digest(path): return hashlib.sha256(path.read_bytes()).hexdigest()
def main():
    def run(name, command, marker=None, timeout=180, allow_vsync=False):
        p = subprocess.run(command,cwd=ROOT,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=timeout)
        text=p.stdout.decode(errors='replace')
        (OUT/(name+'.log')).write_text(text)
        bad=text
        if allow_vsync:
            bad=bad.replace('WARNING: Could not set V-Sync mode, as changing V-Sync mode is not supported by the graphics driver.','')
        assert p.returncode==0 and not re.search(r'SCRIPT ERROR:|ERROR:|WARNING:',bad), (name,p.returncode,text[-3000:])
        assert marker is None or marker in text, name
        print(name,'exit=0',flush=True)
    run('full-suite',['godot4','--headless','--path',str(ROOT),'-s','res://tests/run_tests.gd'],'RESULT: 36 passed, 0 failed')
    run('headless-route',['godot4','--headless','--path',str(ROOT),'--fixed-fps','60','res://tools/capture/f3_capture.tscn'],'F3_CAPTURE_FINISHED failures=0')
    run('native-stills',['xvfb-run','-a','-s','-screen 0 1920x1080x24','godot4','--path',str(ROOT),'--resolution','1920x1080','--audio-driver','Dummy','--rendering-method','gl_compatibility','res://tools/capture/f3_finale_stills.tscn'],'F3_FINALE_STILLS_COMPLETE failures=0',allow_vsync=True)
    run('native-glyph-pixels',['python3','tools/capture/verify_finale_pixels.py'])
    run('export',['godot4','--headless','--path',str(ROOT),'--export-release','Linux',str(OUT/'linux/good-dog.x86_64')])
    sources={str(p):digest(p) for directory in ['scripts','scenes','data','tests','tools','addons'] for p in (ROOT/directory).rglob('*') if p.is_file()}
    sources.update({str(ROOT/name):digest(ROOT/name) for name in ['project.godot','export_presets.cfg','THIRD_PARTY.md']})
    (OUT/'source-identity.json').write_text(json.dumps(sources,indent=2))
    movie=ROOT/'evidence/f3/parent-rescue-render/walkthrough.mp4'
    historical=[movie,ROOT/'evidence/f3/parent-rescue-render/source-identity.json']
    historical += sorted((ROOT/'evidence/f3/edge-repair').glob('normal-*.png'))
    artifacts={str(p):digest(p) for p in sorted(OUT.glob('*.png'))+sorted((OUT/'linux').glob('*'))}
    (OUT/'provenance.json').write_text(json.dumps({'current_artifacts':artifacts,'historical_unchanged':{str(p):digest(p) for p in historical},'movie_scope':'Historical 113.567s PRE-EDGE movie; not rerendered and does not certify credits-repaired source.','decision':'PENDING parent native pixel review; no F3 acceptance or publication.'},indent=2))
    command=['timeout','--signal=TERM','--kill-after=10s','180s','xvfb-run','-a','-s','-screen 0 1920x1080x24','python3','/home/tyler/good-dog-ledger/independent-f3-qa/export_os_input_gate.py']
    for name,path in [('build',OUT/'linux/good-dog.x86_64'),('pck',OUT/'linux/good-dog.pck'),('movie',movie)]:
        command += ['--'+name,str(path),'--'+name+'-sha256',digest(path)]
    command += ['--source-manifest',str(OUT/'source-identity.json'),'--capture-exit','/home/tyler/good-dog-ledger/f3-parent-capture.exit','--output',str(OUT/'os-input'),'--run']
    (OUT/'os-input-command.json').write_text(json.dumps(command,indent=2))
    run('export-os-input',command,timeout=200)
    assert all(digest(Path(p))==h for p,h in sources.items()), 'source changed'
    receipt=json.loads((OUT/'os-input/f3-probe.json').read_text())
    assert receipt['decision']=='OS_INPUT_PROBE_PASSED_NATIVE_REVIEW_PENDING'
    print('CREDITS_REPAIR_VERIFIED; native parent review pending; no publication',flush=True)
if __name__=='__main__': main()
