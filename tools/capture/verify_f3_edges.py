#!/usr/bin/env python3
"""Bounded private edge repair verification; no acceptance or publication."""
import hashlib,json,os,re,shutil,signal,subprocess,tempfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'evidence/f3/edge-repair'
BAD=re.compile(r'(?m)^(?:SCRIPT ERROR:|ERROR:|WARNING:)|leaked at exit|resources still in use|F3_CHECK_FAIL')
def digest(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()
def run(name,cmd,expected=0,marker=None,cwd=ROOT,limit=180):
    with (OUT/(name+'.log')).open('w') as f:
        p=subprocess.Popen(cmd,cwd=cwd,stdout=f,stderr=subprocess.STDOUT,start_new_session=True)
        try: code=p.wait(timeout=limit)
        except BaseException:
            os.killpg(p.pid,signal.SIGKILL); p.wait(); raise
    text=(OUT/(name+'.log')).read_text()
    clean=not bool(BAD.search(text))
    results[name]={'exit':code,'clean':clean,'marker':marker is None or marker in text}
    (OUT/'results.json').write_text(json.dumps(results,indent=2))
    print(name,results[name],flush=True)
    if code!=expected or (expected==0 and not clean) or (marker and marker not in text):
        raise RuntimeError(name+' failed')
results=json.loads((OUT/'results.json').read_text())
# Disposable local project mutations: never alter the repaired live source.
with tempfile.TemporaryDirectory(prefix='f3-edge-mutation-',dir=os.environ['TMPDIR']) as temp:
    fixture=Path(temp)
    for name in ['scripts','scenes','data','tests','tools','addons','assets','.godot']:
        shutil.copytree(ROOT/name,fixture/name)
    shutil.copy2(ROOT/'project.godot',fixture/'project.godot')
    item=fixture/'scripts/interactables/route_item.gd'
    original=item.read_text()
    item.write_text(original.replace('if Vector2(offset.x, offset.z).length_squared() > 1.25 * 1.25:', 'if false:'))
    cmd=['godot4','--headless','--path',str(fixture),'--fixed-fps','60','-s','res://tests/run_tests.gd','--','--f3-fixed-child','res://tests/test_f3_route.gd']
    run('mutation-circle',cmd,1,'FAIL test_f3_route :: test_place_circle_player_origin_boundary',fixture,60)
    item.write_text(original)
    leash=fixture/'scripts/leash_constraint.gd'
    leash.write_text(leash.read_text().replace('if d <= max_d:', 'if d <= max_d or d < EPSILON:'))
    run('mutation-center',cmd,1,'FAIL test_f3_route :: test_leash_exact_center_and_tiny_positive_ratchet',fixture,60)
run('headless-route',['godot4','--headless','--path',str(ROOT),'--fixed-fps','60','res://tools/capture/f3_capture.tscn'],marker='F3_CAPTURE_FINISHED failures=0')
run('native-stills',['xvfb-run','-a','-s','-screen 0 1280x720x24','godot4','--path',str(ROOT),'--resolution','1280x720','--rendering-method','forward_plus','--rendering-driver','vulkan','--audio-driver','Dummy','--disable-render-loop','--fixed-fps','60','res://tools/capture/f3_edge_stills.tscn'],marker='F3_EDGE_STILLS_COMPLETE failures=0',limit=240)
# Resource imports may generate sidecars during first execution; bind final inputs now.
identity={str(p):digest(p) for folder in ['scripts','scenes','data','tests','tools','addons','assets'] for p in (ROOT/folder).rglob('*') if p.is_file()}
for name in ['project.godot','export_presets.cfg']:
    identity[str(ROOT/name)]=digest(ROOT/name)
(OUT/'source-identity.json').write_text(json.dumps(identity,indent=2))
(OUT/'linux').mkdir(exist_ok=False)
run('export',['godot4','--headless','--path',str(ROOT),'--export-release','Linux',str(OUT/'linux/good-dog.x86_64')],limit=180)
assert all(digest(Path(p))==h for p,h in identity.items()),'source changed during export'
old=ROOT/'evidence/f3/parent-rescue-render'
old_identity=json.loads((old/'source-identity.json').read_text())
changed=[p for p,h in old_identity.items() if digest(ROOT/p)!=h]
artifacts={str(p):digest(p) for p in [OUT/'linux/good-dog.x86_64',OUT/'linux/good-dog.pck',old/'walkthrough.mp4',old/'source-identity.json']}
(OUT/'artifact-identity.json').write_text(json.dumps(artifacts,indent=2))
(OUT/'provenance.json').write_text(json.dumps({'fresh_source_manifest':str(OUT/'source-identity.json'),'fresh_build':str(OUT/'linux/good-dog.x86_64'),'historical_movie':str(old/'walkthrough.mp4'),'historical_movie_source_manifest':str(old/'source-identity.json'),'historical_results':json.loads((old/'results.json').read_text()),'changed_historical_inputs':changed,'claim':'Historical movie covers pre-edge normal route ONLY. Fresh source is covered by regression/fullroute logs, targeted native stills and new export. Parent decides sufficiency. Not accepted.'},indent=2))
print('F3_EDGE_REPAIR_VERIFIED_NOT_ACCEPTED',flush=True)
