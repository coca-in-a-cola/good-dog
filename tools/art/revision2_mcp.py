"""Isolated stick-only revision through the existing Blender MCP pipeline."""
import asyncio, json, os
from pathlib import Path
from mcp import ClientSession, StdioServerParameters
from mcp.client.stdio import stdio_client
ROOT=Path(__file__).resolve().parents[2]
CODE='''import bpy, sys, importlib, json
from pathlib import Path
ROOT=Path('/home/tyler/workspaces/good-dog')
sys.path.insert(0, str(Path(%r)/'good-dog-blender-deps'))
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'tools/art/source/representative_slice.blend'))
old=[o for o in bpy.context.scene.objects if o.type=='MESH' and 'Bent ash branch' in o.name]
assert len(old)==1
wood=old[0].data.materials[0];blood=old[0].data.materials[-1]
for o in old:bpy.data.objects.remove(o,do_unlink=True)
sys.path.insert(0,str(ROOT/'tools/art'))
import revise_f4;importlib.reload(revise_f4)
def export(name,objects):
    bpy.ops.object.select_all(action='DESELECT')
    for o in objects:o.select_set(True)
    bpy.context.scene.view_layers[0].objects.active=objects[0]
    with bpy.context.temp_override(window=bpy.context.window_manager.windows[0],scene=bpy.context.scene,view_layer=bpy.context.scene.view_layers[0],active_object=objects[0],object=objects[0],selected_objects=objects,selected_editable_objects=objects):
        bpy.ops.export_scene.gltf(filepath=str(ROOT/'assets/models/f4'/ (name+'.glb')),export_format='GLB',use_selection=True,export_apply=True)
o=revise_f4.branch(wood,blood,export)
o.data.calc_loop_triangles()
assert len(o.data.loop_triangles)<=2000
adj={v.index:set() for v in o.data.vertices}
for e in o.data.edges:
    a,b=e.vertices;adj[a].add(b);adj[b].add(a)
seen=set();todo=[0]
while todo:
    v=todo.pop()
    if v not in seen:seen.add(v);todo.extend(adj[v]-seen)
assert len(seen)==len(adj)
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'tools/art/source/representative_slice.blend'))
p=ROOT/'assets/models/f4/mesh_manifest.json';d=json.loads(p.read_text())
for item in d['objects']:
    if 'Bent ash branch' in item['name']:item['triangles']=len(o.data.loop_triangles)
p.write_text(json.dumps(d,indent=2))
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'tools/art/source/representative_slice.blend'))
print('REVISION2_STICK_CONNECTED',len(seen),'vertices',len(o.data.loop_triangles) if o.name in bpy.data.objects else 'saved','triangles')
''' % os.environ['TMPDIR']
# The reopened document invalidates old RNA handles: report using the fresh object.
CODE=CODE[:CODE.rfind("print('REVISION2")] + "o=next(o for o in bpy.context.scene.objects if 'Bent ash branch' in o.name);o.data.calc_loop_triangles();print('REVISION2_STICK_CONNECTED',len(seen),'vertices',len(o.data.loop_triangles),'triangles; saved and reopened')\n"
async def main():
    out=ROOT/'evidence/f4/revision2';out.mkdir(parents=True,exist_ok=True)
    async with stdio_client(StdioServerParameters(command='/opt/agents/mcp/blender-mcp/7a0373e/.venv/bin/mcp-for-blender',args=[])) as (r,w):
        async with ClientSession(r,w) as s:
            await s.initialize()
            print('TOOLS',[t.name for t in (await s.list_tools()).tools])
            print((await s.call_tool('get_scene_info',{})).model_dump(mode='json'))
            result=(await s.call_tool('execute_blender_code',{'code':CODE,'user_prompt':'Isolated MIT stick silhouette and discontinuous stain correction; preserve all other assets.'})).model_dump(mode='json')
            (out/'mcp-build.json').write_text(json.dumps(result,indent=2));print(json.dumps(result,indent=2))
            assert not result.get('isError'),result
asyncio.run(main())
