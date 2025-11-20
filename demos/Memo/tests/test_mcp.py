import os
import sys
import asyncio
from pathlib import Path

# 独立测试数据库文件
TEST_DB = Path(__file__).resolve().parent.parent / "backend" / ".test_mcp.db"
os.environ["MEMO_DB_PATH"] = str(TEST_DB)
if TEST_DB.exists():
    TEST_DB.unlink()

# 可导入项目根
ROOT = Path(__file__).resolve().parent.parent
root_str = str(ROOT)
if root_str not in sys.path:
    sys.path.insert(0, root_str)

from backend.mcp_server import create_server  # noqa: E402


def norm(res):
    """归一化 FastMCP 调用可能返回的结果。
    - dict: 直接返回
    - (unstructured, structured): 返回 structured
    - [TextContent...]: 尝试解析首个文本块为 JSON
    """
    if isinstance(res, dict):
        return res
    if isinstance(res, tuple) and len(res) == 2:
        return res[1]
    if isinstance(res, list) and res:
        first = res[0]
        text = getattr(first, "text", None)
        if isinstance(text, str):
            import json as _json
            try:
                return _json.loads(text)
            except Exception:
                pass
    return res


async def run_async():
    print("Running MCP tools smoke tests...\n")

    server = create_server()

    # 列出工具
    tools = await server.list_tools()
    names = sorted(t.name for t in tools)
    assert names == [
        "memo.create",
        "memo.delete",
        "memo.get",
        "memo.list",
        "memo.update",
    ]
    print("Tools:", names)

    # 创建
    m1 = norm(await server.call_tool(
        "memo.create",
        {
            "title": "MCP 首条记录",
            "content": "通过 MCP 工具创建",
            "tags": ["工作", "进度"],
        },
    ))
    assert m1["id"] > 0 and m1["tags"] == ["工作", "进度"]
    memo_id = m1["id"]
    print("Create:", m1)

    # 查询
    g = norm(await server.call_tool("memo.get", {"memo_id": memo_id}))
    assert g["title"] == "MCP 首条记录"
    print("Get:", g)

    # 列表
    lst = norm(await server.call_tool("memo.list", {}))
    assert isinstance(lst, dict) and "result" in lst and len(lst["result"]) == 1
    print("List:", lst)

    # 更新
    u = norm(await server.call_tool("memo.update", {"memo_id": memo_id, "title": "MCP 更新标题"}))
    assert u["title"] == "MCP 更新标题"
    print("Update:", u)

    # 搜索
    search = norm(await server.call_tool("memo.list", {"search": "MCP"}))
    assert isinstance(search, dict) and "result" in search and len(search["result"]) == 1
    print("Search:", search)

    # 删除
    d = norm(await server.call_tool("memo.delete", {"memo_id": memo_id}))
    assert d == {"deleted": True}
    after = norm(await server.call_tool("memo.list", {}))
    assert isinstance(after, dict) and after.get("result") == []
    print("Delete ok, remaining:", after)

    print("\nAll MCP tools smoke tests passed.")


if __name__ == "__main__":
    asyncio.run(run_async())