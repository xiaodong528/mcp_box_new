# Memo 项目说明

## 项目概览

- 目标：实现一个前后端分离的备忘录应用，支持添加、删除、修改、查询。
- 后端：SQLite 数据库，FastAPI 封装 HTTP API；同时封装 MCP 工具（SSE）。
- 前端：纯静态网页（HTML/CSS/JS），通过 API 实现功能。

## 目录结构

```
backend/           # 后端代码（数据库、服务函数、API、MCP）
frontend/          # 前端静态资源（页面、样式、脚本）
tests/             # 后端、API 与 MCP 自测脚本
memo.db            # 默认 SQLite 数据库文件（项目根目录）
README.md          # 项目说明文档（本文件）
```

## 环境准备

- 若需安装依赖，可执行：
  - `pip install fastapi uvicorn mcp httpx`
- 可选配置：
  - 数据库文件路径通过环境变量覆盖：`MEMO_DB_PATH=/path/to/memo.db`

## 启动步骤

1) 启动后端 API

- `uvicorn backend.api:app --host 127.0.0.1 --port 48000 --reload`

2) 启动 MCP SSE 服务

- `python -m backend.mcp_sse_server --host 127.0.0.1 --port 48001`
- SSE 端点：`http://127.0.0.1:48001/sse`
- 消息端点：`http://127.0.0.1:48001/messages/`

3) 启动前端静态服务器（在 `frontend/` 目录下）

- `python -m http.server 48002`
- 前端访问地址：`http://127.0.0.1:48002/`

## API 说明（FastAPI）

- `GET /health` 健康检查
- `POST /memos` 创建备忘录
  - 请求体：`{"title": string, "content": string, "tags": string[]?}`
- `GET /memos` 列表与搜索
  - 查询参数：`search?`、`limit?`、`offset=0`
- `GET /memos/{id}` 查询单条
- `PUT /memos/{id}` 更新备忘录
  - 请求体（字段可选）：`{"title"?, "content"?, "tags"?}`
- `DELETE /memos/{id}` 删除备忘录

示例：

- 创建：
  - `curl -X POST http://127.0.0.1:48000/memos -H 'Content-Type: application/json' -d '{"title":"记录","content":"内容","tags":["工作"]}'`
- 搜索：
  - `curl 'http://127.0.0.1:48000/memos?search=内容'`

说明：已为 API 启用 CORS，前端可直接跨域调用。

## MCP 工具说明（SSE）

- 工具列表：`memo.create`、`memo.get`、`memo.list`、`memo.update`、`memo.delete`
- `memo.create`
  - 入参：`{"title": string, "content": string, "tags": string[]?}`
  - 返回：备忘录对象 `{ id, title, content, tags: string[], created_at, updated_at }`
- `memo.get`
  - 入参：`{"memo_id": number}`
  - 返回：备忘录对象
- `memo.list`
  - 入参：`{"search"?: string, "limit"?: number, "offset": number}`（`offset` 默认为 0）
  - 返回：列表（部分客户端显示为 `{"result": [...]}`）
- `memo.update`
  - 入参：`{"memo_id": number, "title"?: string, "content"?: string, "tags"?: string[]}`
  - 返回：更新后的备忘录对象
- `memo.delete`
  - 入参：`{"memo_id": number}`
  - 返回：`{"deleted": true}`

客户端连接配置示例（SSE）：

- SSE URL：`http://127.0.0.1:48001/sse`
- 消息 URL：`http://127.0.0.1:48001/messages/`

## 前端说明

- 页面地址：`http://127.0.0.1:48002/`
- 功能：
  - 新建备忘录（标题、内容、标签（逗号分隔））
  - 搜索（按标题或内容）
  - 列表展示（含编辑、删除）
- `frontend/app.js` 的 `API_BASE` 默认指向 `http://127.0.0.1:48000`，如有变更请修改。

## 测试与自检

- 后端 CRUD 自测：
  - `conda run -n joinai python -m tests.test_backend`
- API 集成测试：
  - `conda run -n joinai python -m tests.test_api`
- MCP 工具测试：
  - `conda run -n joinai python -m tests.test_mcp`

## 常见问题与提示

- 端口占用：如 `48000` 已被占用，调整为其他端口并同步更新前端/客户端配置。
- 搜索范围：当前只对 `title` 与 `content` 搜索，不包含标签；如需扩展，可在后端 SQL 中加入对 `tags` 的匹配（例如 `tags LIKE '%关键词%'`）。
- 数据库路径：通过 `MEMO_DB_PATH` 环境变量覆盖默认路径。

## 🐳 Docker 部署（推荐）

### 架构支持

本项目支持跨架构构建和部署：
- **x86_64/amd64**: 标准生产服务器架构（默认）
- **ARM64**: Apple Silicon Mac 等 ARM 设备

⚠️ **生产部署注意**:
- 镜像已针对 **x86_64 (amd64)** 架构构建，适用于绝大多数生产服务器
- 如需离线部署到内网 x86 服务器，请参阅 [离线部署指南](README-OFFLINE-DEPLOY.md)
- 构建脚本会自动进行跨架构构建，无需手动配置

### 快速启动

```bash
# 方式 1: 使用快速启动脚本
./scripts/docker-start.sh

# 方式 2: 使用 Docker Compose
docker compose up -d

# 访问应用
# 前端: http://localhost:48002
# API 文档: http://localhost:48000/docs
# 健康检查: http://localhost:48000/health
# MCP Box SSE: http://localhost:47070/sse
# MCP Box 管理 API: http://localhost:47071
```

### MCP Box 服务（可选）

Docker Compose 配置中包含了 **MCP Box** 服务,用于动态管理和执行 MCP 工具。

#### 前置配置

MCP Box 需要 E2B 沙箱环境。启动前请配置:

```bash
# 复制环境变量模板
cp .env.example .env

# 编辑 .env 文件,填写 E2B 配置
E2B_JUPYTER_HOST=your-e2b-host-ip  # 必填
E2B_JUPYTER_PORT=49999             # 可选
E2B_DEBUG=false                    # 可选
```

#### 服务访问

- **MCP SSE 端点**: `http://localhost:47070/sse`
- **管理 API**: `http://localhost:47071`

#### 添加 MCP 工具

```bash
# 添加工具示例
curl -X POST "http://localhost:47071/add_mcp_tool/?mcp_tool_name=example_tool" \
  -H "Content-Type: text/plain; charset=utf-8" \
  --data-binary @tool_code.py

# 响应示例
{
  "result": 0,  # 0=成功, 1=已存在, 2=解析失败
  "error": "",
  "transport": "sse",
  "mcp_box_url": "http://localhost:47070/sse"
}
```

#### 删除 MCP 工具

```bash
curl -X POST "http://localhost:47071/remove_mcp_tool/?mcp_tool_name=example_tool"
```

#### MCP Box 与 Memo 服务通信

MCP Box 可以通过内部网络访问 Memo API:

```python
# 在 MCP 工具代码中访问 Memo API
import httpx

# 使用容器内部地址
response = httpx.get("http://memo:48000/memos")
```

#### 工具代码示例

```python
"""
MCP 工具示例:查询 Memo 备忘录
<requirements>
httpx>=0.27.0
</requirements>
"""
from mcp import FastMCP
from typing import Annotated
from pydantic import Field

mcp = FastMCP("memo_tools")

@mcp.tool(description="查询所有备忘录")
def list_memos(
    search: Annotated[str, Field(default="", description="搜索关键词")] = "",
    limit: Annotated[int, Field(default=10, description="返回数量")] = 10
):
    import httpx

    # 通过容器内网络访问 Memo API
    response = httpx.get(
        "http://memo:48000/memos",
        params={"search": search, "limit": limit}
    )
    return response.json()
```

#### 数据持久化

MCP Box 使用 Docker volumes 持久化数据:

- **mcp-config**: 工具配置文件 (`config/mcp-tool.json`)
- **mcp-logs**: 日志文件

查看工具配置:
```bash
docker exec mcp-box cat /app/mcp-box/config/mcp-tool.json
```

### 停止服务

```bash
# 停止容器（保留数据）
docker compose stop

# 停止并删除容器（保留数据）
docker compose down

# 完全清理（删除数据）
docker compose down -v
```

### 数据备份

```bash
# 备份数据库
docker cp memo-app:/app/data/memo.db ./backup-$(date +%Y%m%d).db

# 恢复数据库
docker cp ./backup-20240315.db memo-app:/app/data/memo.db
docker compose restart
```

**详细文档**: 查看 [docs/DOCKER.md](docs/DOCKER.md) 获取完整的 Docker 部署指南。

---

## 💻 本地开发部署

### 快速启动清单

- 启动 API：
  - `uvicorn backend.api:app --host 127.0.0.1 --port 48000 --reload`
- 启动 MCP（SSE）：
  - `python -m backend.mcp_sse_server --host 127.0.0.1 --port 48001`
- 启动前端：
  - `cd frontend && python -m http.server 48002`
- 打开前端：
  - `http://127.0.0.1:48002/`
- 接口测试：
  - `curl` 或浏览器直接调用上述 API
