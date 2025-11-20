from __future__ import annotations

import os
from typing import Any, Dict, List, Optional

import httpx
from mcp.server import FastMCP


# API 服务器地址配置 (可通过环境变量自定义)
API_BASE_URL = os.getenv("MEMO_API_URL", "http://127.0.0.1:48000")


def _http_request(
    method: str,
    path: str,
    json_data: Optional[Dict[str, Any]] = None,
    params: Optional[Dict[str, Any]] = None,
) -> Any:
    """
    封装 HTTP 请求,统一错误处理。

    Args:
        method: HTTP 方法 (GET, POST, PUT, DELETE)
        path: API 路径 (如 /memos)
        json_data: JSON 请求体 (可选)
        params: 查询参数 (可选)

    Returns:
        解析后的 JSON 响应

    Raises:
        ValueError: API 错误或连接失败
    """
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
            # 尝试解析错误详情
            try:
                error_detail = e.response.json().get("detail", e.response.text)
            except Exception:
                error_detail = e.response.text
            raise ValueError(f"API 错误: {e.response.status_code} - {error_detail}")
    except httpx.RequestError as e:
        raise ValueError(f"无法连接到 API 服务器 ({API_BASE_URL}): {str(e)}")


def create_server(api_url: Optional[str] = None) -> FastMCP:
    """
    创建并返回 Memo MCP 服务器,注册 CRUD 工具。

    所有工具通过 HTTP 请求调用 API 服务器,而非直接操作数据库。

    Args:
        api_url: API 服务器地址 (可选,默认使用环境变量或 http://127.0.0.1:48000)
    """
    # 如果提供了 api_url 参数,则覆盖全局配置
    if api_url:
        global API_BASE_URL
        API_BASE_URL = api_url

    server = FastMCP(
        name="Memo MCP",
        instructions=f"通过 HTTP API ({API_BASE_URL}) 操作备忘录数据库",
    )

    # 为了与 mcp_box_server.py 保持一致的命名
    mcp = server

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
        """创建一条新的备忘录,并返回完整记录"""
        payload = {"title": title, "content": content, "tags": tags or []}
        data = _http_request("POST", "/memos", json_data=payload)
        return data

    @mcp.tool(
        description='根据 id 查询备忘录',
        annotations={
            "parameters": {
                "memo_id": {"description": "备忘录 ID"}
            }
        }
    )
    def memo_get(memo_id: int) -> Dict[str, Any]:
        """根据 id 查询备忘录,不存在则抛出错误"""
        data = _http_request("GET", f"/memos/{memo_id}")
        return data

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
        """按更新时间倒序列出备忘录,支持搜索与分页"""
        params = {}
        if search:
            params["search"] = search
        if limit is not None:
            params["limit"] = limit
        if offset:
            params["offset"] = offset
        data = _http_request("GET", "/memos", params=params)
        return data

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
        """更新指定字段并返回更新后的备忘录"""
        payload = {}
        if title is not None:
            payload["title"] = title
        if content is not None:
            payload["content"] = content
        if tags is not None:
            payload["tags"] = tags
        data = _http_request("PUT", f"/memos/{memo_id}", json_data=payload)
        return data

    @mcp.tool(
        description='删除指定 id 的备忘录',
        annotations={
            "parameters": {
                "memo_id": {"description": "备忘录 ID"}
            }
        }
    )
    def memo_delete(memo_id: int) -> Dict[str, Any]:
        """删除指定 id 的备忘录,返回删除结果"""
        data = _http_request("DELETE", f"/memos/{memo_id}")
        return data

    return server
