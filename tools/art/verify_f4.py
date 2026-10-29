"""Byte-level GLB budget/scale contract; run after Blender export, before import."""
import hashlib,json,struct
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'assets/models/f4'
files=[ROOT/'tools/art/source/representative_slice.blend',*(OUT/n for n in ['bent_stick.glb','cell_corridor.glb','placement_circle.glb'])]
assert files[0].read_bytes()[:7]==b'BLENDER'
report={}
for p in files[1:]:
    b=p.read_bytes(); magic,version,total=struct.unpack_from('<III',b)
    assert magic==0x46546c67 and version==2 and total==len(b)
    length,kind=struct.unpack_from('<II',b,12);assert kind==0x4e4f534a
    d=json.loads(b[20:20+length]);counts=[]
    for m in d['meshes']:
        tris=sum(d['accessors'][prim['indices']]['count']//3 for prim in m['primitives'])
        assert 0<tris<=2000,(p,m['name'],tris)
        counts.append(tris)
    assert not any('KHR_draco_mesh_compression' in x for x in d.get('extensionsRequired',[]))
    for node in d['nodes']:
        assert node.get('scale',[1,1,1])==[1,1,1]
    if p.name=='bent_stick.glb':
        a=d['accessors'][d['meshes'][0]['primitives'][0]['attributes']['POSITION']]
        assert .97<=a['max'][0]-a['min'][0]<=1.01,'stick metre width'
    report[p.name]={'mesh_count':len(counts),'max_triangles':max(counts),'triangles':sum(counts)}
manifest=json.loads((OUT/'mesh_manifest.json').read_text())
assert manifest['units']=='metres'
assert all(o['triangles']<=2000 and all(abs(x-1)<1e-5 for x in o['scale']) and all(abs(x)<1e-5 for x in o['rotation']) for o in manifest['objects'])
files.extend([ROOT/'tools/art/build_f4.py',ROOT/'tools/art/revise_f4.py',ROOT/'tools/art/revision2_mcp.py',ROOT/'tools/art/stain_texture.py',OUT/'blood_pool.png'])
provenance={'author':'ChatGPT artist <chatgpt@agents.mice.zone> (GOOD DOG contributors)','license':'MIT','license_file':'LICENSE','source':'tools/art/build_f4.py + revise_f4.py + revision2_mcp.py; stain_texture.py','revision':'2; representative art source checkpoint, not full F4','external_asset_imports':False,'files':{str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in files}}
(OUT/'provenance.json').write_text(json.dumps(provenance,indent=2))
(ROOT/'evidence/f4/asset-checks.json').write_text(json.dumps(report,indent=2))
print('F4_ASSET_CHECKS_PASS',json.dumps(report))
