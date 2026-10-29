import asyncio,json,sys
from pathlib import Path
from mcp import ClientSession,StdioServerParameters
from mcp.client.stdio import stdio_client
ROOT=Path(__file__).resolve().parents[2]
async def main():
    async with stdio_client(StdioServerParameters(command='/opt/agents/mcp/blender-mcp/7a0373e/.venv/bin/mcp-for-blender',args=[])) as (r,w):
        async with ClientSession(r,w) as s:
            await s.initialize()
            if '--build' not in sys.argv:
                results={}
                for name,args in [('get_addon_status',{}),('search_assets',{'source':'polyhaven','query':'bunk','asset_type':'models','limit':3,'previews':0}),('search_assets',{'source':'sketchfab','query':'bent stick','licence':'CC0','limit':3,'previews':0})]:
                    results[name+str(args)]=(await s.call_tool(name,args)).model_dump(mode='json')
                (ROOT/'evidence/f4/library-query.json').write_text(json.dumps(results,indent=2));print(json.dumps(results,indent=2))
            else:
                p=ROOT/'tools/art/build_f4.py'
                code="import sys; sys.path.insert(0, %r); exec(compile(open(%r).read(), %r, 'exec'), {'__file__': %r})"%(str(Path(__import__('os').environ['TMPDIR'])/'good-dog-blender-deps'),str(p),str(p),str(p))
                result=(await s.call_tool('execute_blender_code',{'code':code,'user_prompt':'Build original MIT GOOD DOG representative cell/corridor and stick meshes; save editable blend and GLBs in assigned project.'})).model_dump(mode='json')
                (ROOT/'evidence/f4/mcp-build.json').write_text(json.dumps(result,indent=2));print(json.dumps(result,indent=2))
asyncio.run(main())
