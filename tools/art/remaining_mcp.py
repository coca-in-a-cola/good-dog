"""Use the already deployed MCP; no services/configuration changes."""
import asyncio,json,os
from pathlib import Path
from mcp import ClientSession,StdioServerParameters
from mcp.client.stdio import stdio_client
ROOT=Path(__file__).resolve().parents[2]
async def main():
    out=ROOT/'evidence/f4/remaining';out.mkdir(parents=True,exist_ok=True)
    async with stdio_client(StdioServerParameters(command='/opt/agents/mcp/blender-mcp/7a0373e/.venv/bin/mcp-for-blender',args=[])) as (r,w):
        async with ClientSession(r,w) as s:
            await s.initialize()
            print('TOOLS',[t.name for t in (await s.list_tools()).tools])
            print((await s.call_tool('get_scene_info',{})).model_dump(mode='json'))
            p=ROOT/'tools/art/build_f4_remaining.py'
            code="import sys;sys.path.insert(0,%r);exec(compile(open(%r).read(),%r,'exec'))"%(str(Path(os.environ['TMPDIR'])/'good-dog-blender-deps'),str(p),str(p))
            result=(await s.call_tool('execute_blender_code',{'code':code,'user_prompt':'Original MIT surveillance, collar bowl and open shaft meshes, preserve existing accepted exports.'})).model_dump(mode='json')
            (out/'mcp-build.json').write_text(json.dumps(result,indent=2));print(result)
            assert 'F4_REMAINING_BUILD_OK' in json.dumps(result)
asyncio.run(main())
