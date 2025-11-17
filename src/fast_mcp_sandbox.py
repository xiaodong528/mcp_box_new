import re
from collections.abc import Sequence
from textwrap import dedent
from typing import Any, List

from e2b_code_interpreter import Sandbox
from e2b_code_interpreter.models import Result
from mcp.server.auth.provider import OAuthAuthorizationServerProvider
from mcp.server.fastmcp import FastMCP
from mcp.server.fastmcp.exceptions import ToolError
from mcp.server.fastmcp.tools import Tool
from mcp.server.streamable_http import EventStore
from mcp.types import (
    Content,
    TextContent,
)
from mcp.types import Tool as MCPTool
from src.utils.logging import verbose_logger

class FastMCPBox(FastMCP):
    def __init__(
        self,
        name: str | None = None,
        instructions: str | None = None,
        auth_server_provider: OAuthAuthorizationServerProvider[Any, Any, Any] | None = None,
        event_store: EventStore | None = None,
        *,
        tools: list[Tool] | None = None,
        sandbox_config: dict[str, Any] | None = None,
        **settings: Any,
    ):
        self.tool_codes = {}
        self.e2b_config = sandbox_config

        super().__init__(
            name=name,
            instructions=instructions,
            auth_server_provider=auth_server_provider,
            event_store=event_store,
            tools=tools,
            **settings
        )

    def store_tool_code(self, tool_name:str, raw_code: str):
        code = self.prepare_sandbox_code(raw_code)
        self.tool_codes[tool_name] = code

    def clear_tool_code(self, tool_name:str):
        self.tool_codes[tool_name] = None

    def parse_requirements(self, code)-> List[str]:
        requirements = []
        requirements_match = re.search(r'<requirements>(.*?)</requirements>', code, re.DOTALL)
        if requirements_match:
            raw_requirements = requirements_match.group(1).strip()
            requirements = [req.strip() for req in raw_requirements.split('\n') if req.strip()]
        return requirements

    async def list_tools(self) -> list[MCPTool]:
        """List all available tools."""
        tools = self._tool_manager.list_tools()

        mcp_tools =  [
            MCPTool(
                name=info.name,
                title=info.title,
                description=info.description,
                inputSchema=info.parameters,
                outputSchema=info.output_schema,
                annotations=info.annotations,
            )
            for info in tools
        ]

        for mcp_tool in mcp_tools:
            self.merge_tool_input_schema(mcp_tool)
        return mcp_tools

    def merge_tool_input_schema(self, tool: MCPTool):
        input_schema = tool.inputSchema
        if tool.annotations and tool.annotations.model_extra:
            para_schemas = input_schema['properties']
            para_descs = tool.annotations.model_extra['parameters']
            if para_descs and para_schemas:
                for para_name in para_schemas:
                    para_ann = para_descs[para_name]
                    if para_ann and para_ann['description']:
                        para_desc = para_ann['description']
                        para_schemas[para_name]['description'] = para_desc

    async def call_tool(self, name: str, arguments: dict[str, Any]) -> Sequence[Content]:
        """Call a tool by name with arguments."""
        #context = self.get_context()
        tool_code = self.tool_codes[name]
        if tool_code is None:
            raise ToolError(f"Unknown tool: {name}")

        requirements = self.parse_requirements(tool_code)
        run_code = self.add_run_code(name, tool_code, arguments)
        # @todo init local sandbox with param
        sandbox = None
        try:
            #sandbox = Sandbox()
            sandbox = Sandbox(**self.e2b_config)
            for requirement in requirements:
                pip_cmd = f"pip install --quiet {requirement}"
                verbose_logger.info(f"call_tool sandbox.commands.run: command=:  {pip_cmd}")
                sandbox.commands.run(pip_cmd)

            execution = sandbox.run_code(run_code)
        except Exception as e:
            verbose_logger.error(f"call_tool: run in sandbox unexpect error: {e}")
            raise ToolError(f"Error executing tool {name} in sandbox : {e}")
        finally:
            if sandbox:
                sandbox.kill()

        if execution.error:
            verbose_logger.error(f"call_tool: run in sandbox error, error.name={execution.error.name}, error.value={execution.error.value}, error.traceback=\n{execution.error.traceback}")
            raise ToolError(f"Error executing tool {name}: error.name={execution.error.name}, error.value={execution.error.value}")

        converted_result = self._convert_to_content(execution.results)
        return converted_result

    def prepare_sandbox_code(self, raw_code:str) -> str:
        code = re.sub(r'@mcp\.tool\(.*?\)\s+def', 'def', raw_code, flags=re.DOTALL)
        code = dedent(code)
        # print("===  prepare_sandbox_code  ===")
        # print(code)
        # print("===  end  ===")
        return code

    def add_run_code(self, tool_name:str, code:str, arguments:dict[str, Any]) -> str:
        params_str = ', '.join(f"{k}={repr(v)}" for k, v in arguments.items())
        tool_exec = f"{tool_name}({params_str})"
        verbose_logger.info(f"prepare_sandbox_run: run_sandbox_tool={tool_exec}")
        code = code + f"\n{tool_exec}"
        code = dedent(code)
        return code

    def _convert_to_content(self, e2b_results: List[Result]) -> Sequence[Content]:
        """Convert a result to a sequence of content objects."""
        results = []
        if e2b_results is None:
            return results

        for e2b_result in e2b_results:
            result = e2b_result.text
            results.append(TextContent(type="text", text=result))

        return results