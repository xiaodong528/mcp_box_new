"""
Memo MCP 工具注册脚本
通过 HTTP API 将 Memo 工具动态注册到 MCP Box 服务器
"""
import asyncio
import click
import httpx


# ============================================================================
# 工具1: memo.create - 创建备忘录
# ============================================================================
memo_create_code = """
\"\"\"
<requirements>
httpx>=0.27.0
</requirements>
\"\"\"
import os
from typing import List, Optional, Any, Dict
import httpx

API_BASE_URL = os.getenv("MEMO_API_URL", "http://127.0.0.1:48000")

def _http_request(
    method: str,
    path: str,
    json_data: Optional[Dict[str, Any]] = None,
    params: Optional[Dict[str, Any]] = None,
) -> Any:
    \"\"\"封装 HTTP 请求,统一错误处理\"\"\"
    url = f"{API_BASE_URL}{path}"
    try:
        response = httpx.request(
            method=method,
            url=url,
            json=json_data,
            params=params,
            timeout=10.0,
            headers={"Content-Type": "application/json"},
        )
        response.raise_for_status()
        return response.json()
    except httpx.HTTPStatusError as e:
        if e.response.status_code == 404:
            raise ValueError("Memo 不存在")
        else:
            try:
                error_detail = e.response.json().get("detail", e.response.text)
            except Exception:
                error_detail = e.response.text
            raise ValueError(f"API 错误: {e.response.status_code} - {error_detail}")
    except httpx.RequestError as e:
        raise ValueError(f"无法连接到 API 服务器 ({API_BASE_URL}): {str(e)}")

@mcp.tool(
    description='创建一条新的备忘录',
    annotations={
        "parameters": {
            "title": {"description": "备忘录标题"},
            "content": {"description": "备忘录内容"},
            "tags": {"description": "标签列表，可选，默认为空列表"}
        }
    }
)
def memo_create(title: str, content: str, tags: Optional[List[str]] = None) -> Dict[str, Any]:
    \"\"\"创建一条新的备忘录,并返回完整记录\"\"\"
    payload = {"title": title, "content": content, "tags": tags or []}
    data = _http_request("POST", "/memos", json_data=payload)
    return data
"""


# ============================================================================
# 工具2: memo.get - 查询备忘录
# ============================================================================
memo_get_code = """
\"\"\"
<requirements>
httpx>=0.27.0
</requirements>
\"\"\"
import os
from typing import Any, Dict, Optional
import httpx

API_BASE_URL = os.getenv("MEMO_API_URL", "http://127.0.0.1:48000")

def _http_request(
    method: str,
    path: str,
    json_data: Optional[Dict[str, Any]] = None,
    params: Optional[Dict[str, Any]] = None,
) -> Any:
    \"\"\"封装 HTTP 请求,统一错误处理\"\"\"
    url = f"{API_BASE_URL}{path}"
    try:
        response = httpx.request(
            method=method,
            url=url,
            json=json_data,
            params=params,
            timeout=10.0,
            headers={"Content-Type": "application/json"},
        )
        response.raise_for_status()
        return response.json()
    except httpx.HTTPStatusError as e:
        if e.response.status_code == 404:
            raise ValueError("Memo 不存在")
        else:
            try:
                error_detail = e.response.json().get("detail", e.response.text)
            except Exception:
                error_detail = e.response.text
            raise ValueError(f"API 错误: {e.response.status_code} - {error_detail}")
    except httpx.RequestError as e:
        raise ValueError(f"无法连接到 API 服务器 ({API_BASE_URL}): {str(e)}")

@mcp.tool(
    description='根据 id 查询备忘录',
    annotations={
        "parameters": {
            "memo_id": {"description": "备忘录 ID"}
        }
    }
)
def memo_get(memo_id: int) -> Dict[str, Any]:
    \"\"\"根据 id 查询备忘录,不存在则抛出错误\"\"\"
    data = _http_request("GET", f"/memos/{memo_id}")
    return data
"""


# ============================================================================
# 工具3: memo.list - 列表/搜索备忘录
# ============================================================================
memo_list_code = """
\"\"\"
<requirements>
httpx>=0.27.0
</requirements>
\"\"\"
import os
from typing import Any, Dict, List, Optional
import httpx

API_BASE_URL = os.getenv("MEMO_API_URL", "http://127.0.0.1:48000")

def _http_request(
    method: str,
    path: str,
    json_data: Optional[Dict[str, Any]] = None,
    params: Optional[Dict[str, Any]] = None,
) -> Any:
    \"\"\"封装 HTTP 请求,统一错误处理\"\"\"
    url = f"{API_BASE_URL}{path}"
    try:
        response = httpx.request(
            method=method,
            url=url,
            json=json_data,
            params=params,
            timeout=10.0,
            headers={"Content-Type": "application/json"},
        )
        response.raise_for_status()
        return response.json()
    except httpx.HTTPStatusError as e:
        if e.response.status_code == 404:
            raise ValueError("Memo 不存在")
        else:
            try:
                error_detail = e.response.json().get("detail", e.response.text)
            except Exception:
                error_detail = e.response.text
            raise ValueError(f"API 错误: {e.response.status_code} - {error_detail}")
    except httpx.RequestError as e:
        raise ValueError(f"无法连接到 API 服务器 ({API_BASE_URL}): {str(e)}")

@mcp.tool(
    description='按更新时间倒序列出备忘录,支持搜索与分页',
    annotations={
        "parameters": {
            "search": {"description": "搜索关键词，可选，搜索标题和内容"},
            "limit": {"description": "返回结果数量限制，可选"},
            "offset": {"description": "分页偏移量，默认为 0"}
        }
    }
)
def memo_list(search: Optional[str] = None, limit: Optional[int] = None, offset: int = 0) -> List[Dict[str, Any]]:
    \"\"\"按更新时间倒序列出备忘录,支持搜索与分页\"\"\"
    params = {}
    if search:
        params["search"] = search
    if limit is not None:
        params["limit"] = limit
    if offset:
        params["offset"] = offset
    data = _http_request("GET", "/memos", params=params)
    return data
"""


# ============================================================================
# 工具4: memo.update - 更新备忘录
# ============================================================================
memo_update_code = """
\"\"\"
<requirements>
httpx>=0.27.0
</requirements>
\"\"\"
import os
from typing import Any, Dict, List, Optional
import httpx

API_BASE_URL = os.getenv("MEMO_API_URL", "http://127.0.0.1:48000")

def _http_request(
    method: str,
    path: str,
    json_data: Optional[Dict[str, Any]] = None,
    params: Optional[Dict[str, Any]] = None,
) -> Any:
    \"\"\"封装 HTTP 请求,统一错误处理\"\"\"
    url = f"{API_BASE_URL}{path}"
    try:
        response = httpx.request(
            method=method,
            url=url,
            json=json_data,
            params=params,
            timeout=10.0,
            headers={"Content-Type": "application/json"},
        )
        response.raise_for_status()
        return response.json()
    except httpx.HTTPStatusError as e:
        if e.response.status_code == 404:
            raise ValueError("Memo 不存在")
        else:
            try:
                error_detail = e.response.json().get("detail", e.response.text)
            except Exception:
                error_detail = e.response.text
            raise ValueError(f"API 错误: {e.response.status_code} - {error_detail}")
    except httpx.RequestError as e:
        raise ValueError(f"无法连接到 API 服务器 ({API_BASE_URL}): {str(e)}")

@mcp.tool(
    description='更新指定备忘录的字段',
    annotations={
        "parameters": {
            "memo_id": {"description": "备忘录 ID"},
            "title": {"description": "新标题，可选"},
            "content": {"description": "新内容，可选"},
            "tags": {"description": "新标签列表，可选"}
        }
    }
)
def memo_update(
    memo_id: int,
    title: Optional[str] = None,
    content: Optional[str] = None,
    tags: Optional[List[str]] = None,
) -> Dict[str, Any]:
    \"\"\"更新指定字段并返回更新后的备忘录\"\"\"
    payload = {}
    if title is not None:
        payload["title"] = title
    if content is not None:
        payload["content"] = content
    if tags is not None:
        payload["tags"] = tags
    data = _http_request("PUT", f"/memos/{memo_id}", json_data=payload)
    return data
"""


# ============================================================================
# 工具5: memo.delete - 删除备忘录
# ============================================================================
memo_delete_code = """
\"\"\"
<requirements>
httpx>=0.27.0
</requirements>
\"\"\"
import os
from typing import Any, Dict, Optional
import httpx

API_BASE_URL = os.getenv("MEMO_API_URL", "http://127.0.0.1:48000")

def _http_request(
    method: str,
    path: str,
    json_data: Optional[Dict[str, Any]] = None,
    params: Optional[Dict[str, Any]] = None,
) -> Any:
    \"\"\"封装 HTTP 请求,统一错误处理\"\"\"
    url = f"{API_BASE_URL}{path}"
    try:
        response = httpx.request(
            method=method,
            url=url,
            json=json_data,
            params=params,
            timeout=10.0,
            headers={"Content-Type": "application/json"},
        )
        response.raise_for_status()
        return response.json()
    except httpx.HTTPStatusError as e:
        if e.response.status_code == 404:
            raise ValueError("Memo 不存在")
        else:
            try:
                error_detail = e.response.json().get("detail", e.response.text)
            except Exception:
                error_detail = e.response.text
            raise ValueError(f"API 错误: {e.response.status_code} - {error_detail}")
    except httpx.RequestError as e:
        raise ValueError(f"无法连接到 API 服务器 ({API_BASE_URL}): {str(e)}")

@mcp.tool(
    description='删除指定 id 的备忘录',
    annotations={
        "parameters": {
            "memo_id": {"description": "备忘录 ID"}
        }
    }
)
def memo_delete(memo_id: int) -> Dict[str, Any]:
    \"\"\"删除指定 id 的备忘录,返回删除结果\"\"\"
    data = _http_request("DELETE", f"/memos/{memo_id}")
    return data
"""


# ============================================================================
# 工具注册函数
# ============================================================================

async def call_add_mcp_tool(host: str, port: int, mcp_tool_name: str, mcp_tool_code: str) -> dict:
    """
    通过 HTTP API 添加 MCP 工具到 MCP Box

    Args:
        host: MCP Box 主机地址
        port: MCP Box HTTP 管理端口 (通常是 SSE 端口 + 1)
        mcp_tool_name: 工具名称
        mcp_tool_code: 工具代码字符串

    Returns:
        响应结果字典，包含 result, error, mcp_box_url 等字段
    """
    url = f"http://{host}:{port}/add_mcp_tool/"
    params = {"mcp_tool_name": mcp_tool_name}

    async with httpx.AsyncClient(timeout=30) as client:
        try:
            response = await client.post(
                url,
                params=params,
                content=mcp_tool_code.encode('utf-8'),
                headers={"Content-Type": "text/plain; charset=utf-8"}
            )
            result = response.json()

            if response.status_code == 200:
                if result['result'] == 0:
                    print(f"✅ 成功注册工具: {mcp_tool_name}")
                elif result['result'] == 1:
                    print(f"⚠️  工具已存在: {mcp_tool_name}")
                elif result['result'] == 2:
                    print(f"❌ 工具解析失败: {mcp_tool_name}")
                    print(f"   错误: {result.get('error', '未知错误')}")
            else:
                print(f"❌ HTTP 请求失败: {response.status_code}")
                print(f"   响应: {result}")

            return result
        except Exception as e:
            print(f"❌ 注册工具 {mcp_tool_name} 时出错: {e}")
            return {"result": -1, "error": str(e)}


@click.command()
@click.option("--host", default="localhost", help="MCP Box 主机地址")
@click.option("--port", default=47071, help="MCP Box HTTP 管理端口 (SSE 端口 + 1)")
def main(host: str, port: int):
    """
    Memo MCP 工具注册脚本

    将 5 个 Memo 工具 (create, get, list, update, delete) 注册到 MCP Box 服务器

    使用方法:
        python mcp_box_server.py --host localhost --port 47071

    环境变量:
        MEMO_API_URL: Memo API 服务器地址 (默认: http://127.0.0.1:48000)

    前置条件:
        1. Memo API 服务器已启动 (端口 48000)
        2. MCP Box 服务器已启动 (端口 47070 SSE, 47071 HTTP)
    """
    print("=" * 70)
    print("Memo MCP 工具注册脚本")
    print("=" * 70)
    print(f"目标 MCP Box: http://{host}:{port}")
    print(f"准备注册 5 个工具: memo.create, memo.get, memo.list, memo.update, memo.delete")
    print("=" * 70)
    print()

    # 定义要注册的工具
    tools = [
        ("memo.create", memo_create_code),
        ("memo.get", memo_get_code),
        ("memo.list", memo_list_code),
        ("memo.update", memo_update_code),
        ("memo.delete", memo_delete_code),
    ]

    async def register_all_tools():
        results = []
        for tool_name, tool_code in tools:
            print(f"正在注册工具: {tool_name}...")
            result = await call_add_mcp_tool(host, port, tool_name, tool_code)
            results.append((tool_name, result))
            print()

        # 汇总结果
        print("=" * 70)
        print("注册结果汇总")
        print("=" * 70)
        success_count = sum(1 for _, r in results if r.get('result') == 0)
        print(f"成功注册: {success_count}/{len(tools)} 个工具")
        print()

        for tool_name, result in results:
            status = "✅ 成功" if result.get('result') == 0 else "❌ 失败"
            print(f"{status} - {tool_name}")

        print("=" * 70)

        # 如果有成功注册的工具，显示 MCP Box 连接信息
        if success_count > 0:
            mcp_box_url = results[0][1].get('mcp_box_url')
            if mcp_box_url:
                print()
                print("MCP Box 连接信息:")
                print(f"  SSE URL: {mcp_box_url}")
                print()
                print("测试工具:")
                print(f"  python tests/test_mcp_box.py --host {host} --port {port - 1}")

    # 执行注册
    asyncio.run(register_all_tools())


if __name__ == "__main__":
    main()
