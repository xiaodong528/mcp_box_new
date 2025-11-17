import asyncio

import click
import httpx
from mcp.client.session import ClientSession
from mcp.client.sse import sse_client

t1_name = "getHostFaultCause"
t1_code = """
\"\"\"
<requirements>
uvicorn>=0.34.3
</requirements>
\"\"\"
from typing import Annotated, Optional
from pydantic import Field
@mcp.tool(
    description='主机故障解决方案'
)
def getHostFaultCause(
    faultCode: Annotated[str, Field(description="故障代码")],
    severity: Annotated[int, Field(default=2, description="故障严重等级，1-5，默认为1")]
    ):
    print(f"getHostFaultCause: faultCode={faultCode}, severity={severity}")
    faultCause = ""
    if (faultCode == 'F02'):
        faultCause = "主机磁盘故障，需要更换磁盘"
    else:
        faultCause = f"未知故障，故障代码{faultCode}"        
    return faultCause
"""

t2_name = "getMiddleFaultCause"
t2_code = """

@mcp.tool(
    description='中间件故障解决方案',
    annotations={
        "parameters": {
            "faultCode": {"description": "故障代码"},
            "severity": {"description": "故障严重等级，1-5，默认为1"}
        }
    }
)
def getMiddleFaultCause(
    faultCode: str,
    severity: int=1
    ):
    print(f"getMiddleFaultCause: faultCode={faultCode}, severity={severity}")
    faultCause = ""
    if (faultCode == 'F03'):
        faultCause = "中间件redis故障，重启redis"
    else:
        faultCause = f"未知故障，故障代码{faultCode}"        
    return {'result': 0, 'faultCause': faultCause}
"""


async def call_add_mcp_tool(host: str, port: int, mcp_tool_name: str, mcp_tool_code: str) -> str:
    url = f"http://{host}:{port}/add_mcp_tool/"
    params = {"mcp_tool_name": mcp_tool_name}
    mcp_box_url = None

    async with httpx.AsyncClient(timeout=30) as client:
        try:
            response = await client.post(
                url,
                params=params,
                content=mcp_tool_code.encode('utf-8'),
                headers={"Content-Type": "text/plain; charset=utf-8"}
            )
            result = response.json()
            print(f"call_add_mcp_tool result={result}")
            if response.status_code == 200 and result['result'] == 0:
                mcp_box_url = result['mcp_box_url']
        except Exception as e:
            print(f"call_add_mcp_tool: error {e}")

        return mcp_box_url


async def call_remove_mcp_tool(host: str, port: int, mcp_tool_name: str) :
    url = f"http://{host}:{port}/remove_mcp_tool/"
    params = {"mcp_tool_name": mcp_tool_name}

    async with httpx.AsyncClient(timeout=30) as client:
        try:
            response = await client.post(
                url,
                params=params,
                headers={"Content-Type": "text/plain; charset=utf-8"}
            )
            result = response.json()
            print(f"call_remove_mcp_tool result={result}")
        except Exception as e:
            print(f"call_remove_mcp_tool: error {e}")

@click.command()
@click.option("--host", default="localhost", help="Host to listen on for SSE")
@click.option("--port", default=47070, help="Port to listen on for SSE")
def main(host: str, port: int):
    # print("=== remove added mcp tool ===")
    # asyncio.run(call_remove_mcp_tool(host, port + 1, t1_name))
    # asyncio.run(call_remove_mcp_tool(host, port + 1, t2_name))
    #
    # print("=== dyn add mcp tool ===")
    # mcp_box_url = asyncio.run(call_add_mcp_tool(host, port + 1, t1_name, t1_code))
    # if mcp_box_url is None:
    #     print("mcp_box_url is None, start fail !")
    #     return
    #
    # asyncio.run(call_add_mcp_tool(host, port + 1, t2_name, t2_code))
    #
    # print(f"\n=== connect mcp box server url={mcp_box_url} ===")
    async def run_sse(url):
        async with sse_client(url, sse_read_timeout=300) as streams:
            async with ClientSession(*streams) as session:
                await session.initialize()

                print("\n=== list all mcp box tools ===")
                response = await session.list_tools()
                print(response.model_dump_json())
                #for tool in response.tools:
                    # merge_tool_input_schema(tool)
                    # print(f"list_tools: TOOL name={tool.name}, description={tool.description}, "
                    #       f"outputSchema={tool.outputSchema} \ninputSchema=\n{tool.inputSchema}")
                    #print(tool.model_dump_json())

                print("\n=== call mcp box tools ===")
                from datetime import timedelta
                time_out_sec = timedelta(seconds=300)
                result = await session.call_tool(name="getHostFaultCause", arguments={"faultCode": "F02", "severity": 3}, read_timeout_seconds=time_out_sec)
                print(f'call_tool: getHostFaultCause result={result.model_dump_json()}')

                result = await session.call_tool(name="getMiddleFaultCause", arguments={"faultCode": "F03"},  read_timeout_seconds=time_out_sec)
                print(f'call_tool: getMiddleFaultCause result={result.model_dump_json()}')
                #
                # print("\n=== remove mcp box tool ===")
                # await call_remove_mcp_tool(host, port + 1, t1_name)
                #
                # print("\n=== list all mcp box tools after remove ===")
                # response = await session.list_tools()
                # for tool in response.tools:
                #     # merge_tool_input_schema(tool)
                #     print(f"list_tools: TOOL name={tool.name}, description={tool.description}, "
                #           f"outputSchema={tool.outputSchema} \ninputSchema=\n{tool.inputSchema}")
                #
                # print("\n=== call the removed mcp box tool ===")
                # result = await session.call_tool(name="getHostFaultCause", arguments={"faultCode": "F01", "severity": 3},  read_timeout_seconds=time_out_sec)
                # print(f'call_tool: call removed tool getHostFaultCause result={result}')

    asyncio.run(run_sse("http://localhost:47070/sse"))


if __name__ == "__main__":
    main()
