# Memo MCP Box 集成指南

## 概述

本指南说明如何将 Memo 备忘录应用的 5 个 MCP 工具集成到 MCP Box 动态工具服务器。

## 文件说明

### 1. `backend/mcp_box_server.py`
**作用**: 通过 HTTP API 动态注册 Memo 工具到运行中的 MCP Box

**功能**:
- 定义 5 个 Memo 工具的代码（符合 MCP Box 格式）
- 提供批量注册功能
- 支持命令行参数配置 MCP Box 地址

### 2. `config/mcp-tool.json`
**作用**: MCP Box 启动时自动加载的工具配置文件

**内容**: 包含 6 个工具定义（1 个示例工具 + 5 个 Memo 工具）

## 工具列表

| 工具名称 | 描述 | 主要参数 |
|---------|------|---------|
| **memo.create** | 创建新备忘录 | title, content, tags |
| **memo.get** | 查询单条备忘录 | memo_id |
| **memo.list** | 列表/搜索备忘录 | search, limit, offset |
| **memo.update** | 更新备忘录 | memo_id, title, content, tags |
| **memo.delete** | 删除备忘录 | memo_id |

## 工具代码规范

所有 Memo 工具都遵循以下规范：

### ✅ 使用 @mcp.tool 装饰器
```python
@mcp.tool(
    description='工具描述',
    annotations={
        "parameters": {
            "param_name": {"description": "参数说明"}
        }
    }
)
```

### ✅ 参数定义方式
采用 **annotations 字典方式**（方式二）：
- 不需要 `Annotated` 和 `Field` 导入
- 参数 description 在 annotations 中定义
- 函数签名使用标准 Python 类型注解

### ✅ 依赖声明
```python
"""
<requirements>
httpx>=0.27.0
</requirements>
"""
```

### ✅ 环境变量配置
```python
API_BASE_URL = os.getenv("MEMO_API_URL", "http://127.0.0.1:48000")
```

### ✅ 返回类型
- 使用 `Dict[str, Any]` 而非 Pydantic 模型
- 直接返回 JSON 响应数据

## 使用方式

### 方式一：从配置文件加载（推荐）

**步骤 1**: 启动 Memo API 服务器
```bash
cd demos/Memo
uvicorn backend.api:app --host 127.0.0.1 --port 48000
```

**步骤 2**: 启动 MCP Box（从配置文件加载）
```bash
# 确保环境变量配置
export STORE_IN_FILE=true
export MEMO_API_URL=http://127.0.0.1:48000

# 启动 MCP Box
python src/mcp_box.py --host localhost --port 47070
```

MCP Box 会自动加载 `config/mcp-tool.json` 中的所有工具（包括 5 个 Memo 工具）。

**步骤 3**: 验证工具加载
```bash
# 连接到 SSE 端点并列出工具
curl http://localhost:47070/sse
```

### 方式二：动态注册工具

**步骤 1**: 启动 Memo API 服务器（同上）

**步骤 2**: 启动 MCP Box
```bash
python src/mcp_box.py --host localhost --port 47070
```

**步骤 3**: 运行注册脚本
```bash
cd demos/Memo/backend
python mcp_box_server.py --host localhost --port 47071
```

**输出示例**:
```
======================================================================
Memo MCP 工具注册脚本
======================================================================
目标 MCP Box: http://localhost:47071
准备注册 5 个工具: memo.create, memo.get, memo.list, memo.update, memo.delete
======================================================================

正在注册工具: memo.create...
✅ 成功注册工具: memo.create

正在注册工具: memo.get...
✅ 成功注册工具: memo.get

...

======================================================================
注册结果汇总
======================================================================
成功注册: 5/5 个工具

✅ 成功 - memo.create
✅ 成功 - memo.get
✅ 成功 - memo.list
✅ 成功 - memo.update
✅ 成功 - memo.delete
======================================================================

MCP Box 连接信息:
  SSE URL: http://localhost:47070/sse

测试工具:
  python tests/test_mcp_box.py --host localhost --port 47070
```

## 测试工具

### 使用 MCP 客户端测试

创建测试脚本 `test_memo_tools.py`:

```python
import asyncio
from mcp.client.session import ClientSession
from mcp.client.sse import sse_client

async def test_memo_tools():
    async with sse_client("http://localhost:47070/sse") as streams:
        async with ClientSession(*streams) as session:
            await session.initialize()

            # 1. 创建备忘录
            result = await session.call_tool(
                name="memo.create",
                arguments={
                    "title": "测试备忘录",
                    "content": "这是通过 MCP Box 创建的备忘录",
                    "tags": ["测试", "MCP"]
                }
            )
            print(f"创建结果: {result}")
            memo_id = result.content[0].text['id']

            # 2. 查询备忘录
            result = await session.call_tool(
                name="memo.get",
                arguments={"memo_id": memo_id}
            )
            print(f"查询结果: {result}")

            # 3. 列出所有备忘录
            result = await session.call_tool(
                name="memo.list",
                arguments={"limit": 10}
            )
            print(f"列表结果: {result}")

            # 4. 更新备忘录
            result = await session.call_tool(
                name="memo.update",
                arguments={
                    "memo_id": memo_id,
                    "content": "更新后的内容"
                }
            )
            print(f"更新结果: {result}")

            # 5. 删除备忘录
            result = await session.call_tool(
                name="memo.delete",
                arguments={"memo_id": memo_id}
            )
            print(f"删除结果: {result}")

asyncio.run(test_memo_tools())
```

### 使用 HTTP API 测试

```bash
# 创建备忘录
curl -X POST "http://localhost:47071/call_tool" \
  -H "Content-Type: application/json" \
  -d '{
    "tool": "memo.create",
    "arguments": {
      "title": "API 测试",
      "content": "通过 HTTP API 测试",
      "tags": ["API"]
    }
  }'

# 查询备忘录
curl -X POST "http://localhost:47071/call_tool" \
  -H "Content-Type: application/json" \
  -d '{
    "tool": "memo.get",
    "arguments": {"memo_id": 1}
  }'

# 列出备忘录
curl -X POST "http://localhost:47071/call_tool" \
  -H "Content-Type: application/json" \
  -d '{
    "tool": "memo.list",
    "arguments": {"search": "测试", "limit": 5}
  }'
```

## 环境配置

### 必需环境变量

```bash
# Memo API 服务器地址（工具调用时使用）
MEMO_API_URL=http://127.0.0.1:48000

# MCP Box 存储模式
STORE_IN_FILE=true   # true=配置文件模式, false=数据库模式
```

### 可选环境变量（数据库模式）

如果 `STORE_IN_FILE=false`，需要配置数据库连接：

```bash
DB_HOST=localhost
DB_PORT=5432
DB_NAME=mcpbox
DB_USER=mcpbox
DB_PASSWORD=your_password
```

## 架构说明

### 工具调用流程

```
MCP 客户端
  ↓ SSE 连接 (http://localhost:47070/sse)
MCP Box 服务器
  ↓ 工具调用
MCP Box 内部执行环境（本地或沙箱）
  ↓ HTTP 请求
Memo API 服务器 (http://127.0.0.1:48000)
  ↓ 业务逻辑
Memo 数据库 (SQLite)
```

### 端口架构

- **47070**: MCP Box SSE 端点（MCP 协议通信）
- **47071**: MCP Box HTTP 管理接口（添加/删除工具）
- **48000**: Memo API 服务器（HTTP API）

## 故障排查

### 问题 1: 工具注册失败

**症状**: 注册脚本显示 "❌ 工具解析失败"

**解决方案**:
1. 检查工具代码格式是否正确
2. 验证 `@mcp.tool` 装饰器语法
3. 确认 Python 语法无误

### 问题 2: 工具调用失败 "无法连接到 API 服务器"

**症状**: 调用工具时返回连接错误

**解决方案**:
1. 确认 Memo API 服务器已启动：`curl http://127.0.0.1:48000/health`
2. 检查环境变量 `MEMO_API_URL` 是否正确配置
3. 验证网络连接和防火墙设置

### 问题 3: MCP Box 启动时未加载工具

**症状**: MCP Box 启动成功，但 list_tools 为空

**解决方案**:
1. 确认 `STORE_IN_FILE=true` 环境变量已设置
2. 验证 `config/mcp-tool.json` 文件存在且格式正确
3. 检查 MCP Box 日志：`logs/mcpbox.log`

### 问题 4: 工具已存在错误

**症状**: "⚠️ 工具已存在"

**解决方案**:
1. 先删除已存在的工具：
   ```bash
   curl -X POST "http://localhost:47071/remove_mcp_tool/?mcp_tool_name=memo.create"
   ```
2. 重新注册工具

## 最佳实践

### 1. 环境变量管理
创建 `.env` 文件统一管理配置：
```bash
# .env
MEMO_API_URL=http://127.0.0.1:48000
STORE_IN_FILE=true
```

使用 `python-dotenv` 加载：
```python
from dotenv import load_dotenv
load_dotenv()
```

### 2. 工具版本管理
在工具代码中添加版本信息：
```python
@mcp.tool(
    description='创建备忘录 (v1.0)',
    annotations={...}
)
```

### 3. 错误处理
所有工具都包含完善的错误处理：
- HTTP 状态错误捕获
- 网络连接错误处理
- 详细的错误信息返回

### 4. 日志记录
工具执行时会记录到 MCP Box 日志：
```bash
tail -f logs/mcpbox.log
```

## 扩展开发

### 添加新的 Memo 工具

1. 在 `mcp_box_server.py` 中定义新工具代码
2. 添加到工具列表
3. 更新 `config/mcp-tool.json`
4. 重新注册或重启 MCP Box

### 自定义工具模板

```python
memo_custom_code = """
\"\"\"
<requirements>
httpx>=0.27.0
</requirements>
\"\"\"
import os
from typing import Any, Dict
import httpx

API_BASE_URL = os.getenv("MEMO_API_URL", "http://127.0.0.1:48000")

def _http_request(...):
    # 复用现有的 HTTP 请求函数
    ...

@mcp.tool(
    description='自定义工具描述',
    annotations={
        "parameters": {
            "param1": {"description": "参数1说明"},
            "param2": {"description": "参数2说明"}
        }
    }
)
def custom_tool(param1: str, param2: int) -> Dict[str, Any]:
    \"\"\"工具实现\"\"\"
    # 实现逻辑
    data = _http_request("GET", f"/custom/{param1}")
    return data
"""
```

## 参考文档

- [MCP Box 项目文档](../../CLAUDE.md)
- [Memo 应用文档](./CLAUDE.md)
- [FastMCP 官方文档](https://github.com/jlowin/fastmcp)
- [MCP 协议规范](https://modelcontextprotocol.io)

## 总结

本集成实现了以下目标：

✅ 创建了 `mcp_box_server.py` 动态注册脚本
✅ 更新了 `config/mcp-tool.json` 配置文件
✅ 所有工具符合 MCP Box 规范（annotations 参数定义）
✅ 所有工具包含 `<requirements>` 依赖声明
✅ 所有工具支持环境变量配置
✅ 所有工具返回字典而非 Pydantic 模型

现在 Memo 应用的 5 个核心功能都可以通过 MCP Box 动态工具服务器访问，支持灵活的集成和扩展。
