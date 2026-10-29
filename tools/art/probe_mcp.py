"""Read-only discovery of the installed sanctioned Blender MCP stdio transport."""
import asyncio,json
from pathlib import Path
from mcp import ClientSession, StdioServerParameters
from mcp.client.stdio import stdio_client
async def main():
    params=StdioServerParameters(command='/opt/agents/mcp/blender-mcp/7a0373e/.venv/bin/mcp-for-blender',args=[])
    async with stdio_client(params) as (r,w):
        async with ClientSession(r,w) as s:
            await s.initialize()
            tools=await s.list_tools()
            result={'tools':[t.name for t in tools.tools], 'schemas': {t.name:t.inputSchema for t in tools.tools if t.name in ['search_assets','execute_blender_code','get_addon_status']}}
            for name in ['get_scene_info','get_polyhaven_status','get_sketchfab_status']:
                if name in result['tools']:
                    result[name]=(await s.call_tool(name,{})).model_dump(mode='json')
            path=Path(__file__).resolve().parents[2]/'evidence/f4/mcp-readonly.json'
            path.parent.mkdir(parents=True,exist_ok=True);path.write_text(json.dumps(result,indent=2))
            print(json.dumps(result,indent=2))
asyncio.run(main())
