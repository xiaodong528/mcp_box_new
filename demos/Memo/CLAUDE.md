# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目概述

Memo 是一个前后端分离的备忘录应用,同时提供 HTTP API 和 MCP (Model Context Protocol) 工具接口。

**技术栈**:
- 后端: Python + FastAPI + SQLite
- 前端: 原生 HTML/CSS/JavaScript (无框架)
- MCP: FastMCP (SSE 服务器)
- 容器化: Docker + Docker Compose

**架构支持**:
- **目标平台**: x86_64/amd64 (标准生产服务器)
- **构建支持**: 跨架构构建,支持在 ARM 机器上构建 x86 镜像
- **部署模式**: Docker 容器化部署,支持离线部署

## 开发命令

### 环境准备
```bash
# 安装依赖
pip install -r requirements.txt

# 配置数据库路径 (可选)
export MEMO_DB_PATH=/path/to/memo.db
```

### 启动服务

**后端 API 服务** (端口 48000):
```bash
cd Memo
uvicorn backend.api:app --host 127.0.0.1 --port 48000 --reload
```

**MCP SSE 服务器** (端口 48001) - ⚠️ 依赖 API 服务器:
```bash
cd Memo
python -m backend.mcp_sse_server --host 127.0.0.1 --port 48001

# 自定义 API 服务器地址
python -m backend.mcp_sse_server --api-url http://192.168.1.100:48000
```

**前端静态服务器** (端口 48002):
```bash
cd Memo/frontend
python -m http.server 48002
```

**注意**: MCP 服务器通过 HTTP 请求调用 API 服务器,因此必须先启动 API 服务器 (端口 48000)。

### 测试

**运行所有测试**:
```bash
# 后端业务逻辑测试
python -m tests.test_backend

# API 集成测试
python -m tests.test_api

# MCP 工具测试 (需先启动 API 服务器)
# 终端 1: uvicorn backend.api:app --host 127.0.0.1 --port 48000
# 终端 2: python -m tests.test_mcp
python -m tests.test_mcp
```

**单个测试文件**:
```bash
python -m tests.test_backend
```

### API 测试示例
```bash
# 健康检查
curl http://127.0.0.1:48000/health

# 创建备忘录
curl -X POST http://127.0.0.1:48000/memos \
  -H 'Content-Type: application/json' \
  -d '{"title":"测试","content":"内容","tags":["工作"]}'

# 搜索备忘录
curl 'http://127.0.0.1:48000/memos?search=测试'

# 查询单条
curl http://127.0.0.1:48000/memos/1

# 更新备忘录
curl -X PUT http://127.0.0.1:48000/memos/1 \
  -H 'Content-Type: application/json' \
  -d '{"title":"新标题"}'

# 删除备忘录
curl -X DELETE http://127.0.0.1:48000/memos/1
```

## 架构设计

### 三层架构

```
frontend/           # 表示层 (静态网页)
    ├── index.html  # 主页面
    ├── style.css   # 样式
    └── app.js      # 前端逻辑 (调用 HTTP API)

backend/            # 业务逻辑层 + 接口层
    ├── db.py               # 数据访问层 (SQLite 连接和初始化)
    ├── memo_service.py     # 业务逻辑层 (CRUD 核心逻辑)
    ├── api.py              # HTTP API 接口 (FastAPI)
    ├── mcp_server.py       # MCP 工具定义 (FastMCP)
    └── mcp_sse_server.py   # MCP SSE 服务器启动脚本

tests/              # 测试层
    ├── test_backend.py     # 业务逻辑单元测试
    ├── test_api.py         # API 集成测试
    └── test_mcp.py         # MCP 工具测试
```

### 数据流设计

**HTTP API 流程**:
```
frontend (app.js)
  → HTTP request
  → backend/api.py (FastAPI endpoints)
  → backend/memo_service.py (业务逻辑)
  → backend/db.py (SQLite 操作)
```

**MCP 工具流程** (通过 HTTP 调用 API):
```
MCP 客户端
  → SSE 连接 (backend/mcp_sse_server.py)
  → 工具调用 (backend/mcp_server.py)
  → HTTP 请求 (httpx)
  → backend/api.py (FastAPI endpoints)
  → backend/memo_service.py (业务逻辑)
  → backend/db.py (SQLite 操作)
```

### 关键设计原则

1. **业务逻辑复用**: `memo_service.py` 包含所有 CRUD 核心逻辑,被 HTTP API 复用
2. **分层架构**: MCP 工具通过 HTTP 请求调用 API 服务器,而非直接操作数据库
3. **数据库抽象**: `db.py` 提供连接管理和表初始化,使用 `Row` factory 实现类字典访问
4. **标签存储**: tags 以 JSON 字符串形式存储在 SQLite 的 TEXT 列中
5. **时间戳**: 使用 UTC ISO 格式字符串 (`datetime.now(timezone.utc).isoformat()`)
6. **CORS 配置**: API 层启用全域 CORS 支持前端跨域调用
7. **服务解耦**: API 和 MCP 服务器可独立部署,MCP 依赖 API 服务器 (必须先启动)

### MCP 工具接口

**可用工具**:
- `memo.create` - 创建备忘录
- `memo.get` - 查询单条备忘录
- `memo.list` - 列表/搜索备忘录
- `memo.update` - 更新备忘录
- `memo.delete` - 删除备忘录

**SSE 端点**: `http://127.0.0.1:48001/sse`
**消息端点**: `http://127.0.0.1:48001/messages/`

### 数据库模式

```sql
CREATE TABLE memos (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    title TEXT NOT NULL,
    content TEXT NOT NULL,
    tags TEXT DEFAULT '[]',          -- JSON 字符串数组
    created_at TEXT NOT NULL,        -- UTC ISO 格式
    updated_at TEXT NOT NULL         -- UTC ISO 格式
);

CREATE INDEX idx_memos_updated_at ON memos(updated_at);
```

## Docker 部署

### 架构说明

**镜像平台**: 所有 Docker 镜像强制构建为 **linux/amd64** (x86_64) 架构

**配置位置**:
- `docker-compose.yml`: 开发环境配置,包含 `platform: linux/amd64` 和构建平台参数
- `docker-compose.prod.yml`: 生产环境配置,使用预构建镜像,指定 `platform: linux/amd64`
- `scripts/prepare-offline-images.sh`: 离线部署包准备脚本,强制 x86_64 架构构建

**跨架构构建**:
- 在 ARM 机器（如 Mac M1/M2）上构建时,Docker 会自动使用 QEMU 进行跨平台编译
- 构建命令使用 `DOCKER_DEFAULT_PLATFORM=linux/amd64` 环境变量确保架构正确
- Python 基础镜像使用 `docker pull --platform linux/amd64 python:3.12-slim` 拉取

### 离线部署

详见 [README-OFFLINE-DEPLOY.md](README-OFFLINE-DEPLOY.md)

**准备流程**:
```bash
# 在有网环境构建并打包
bash scripts/prepare-offline-images.sh

# 传输到内网环境后部署
bash deploy-offline.sh
```

## 开发注意事项

### 修改业务逻辑
- 核心 CRUD 逻辑在 `backend/memo_service.py`,修改会同时影响 API 和 MCP 工具
- 确保修改后同时运行 `test_backend.py`, `test_api.py`, `test_mcp.py`

### 修改 API 端点
- 修改 `backend/api.py` 时,需同步更新前端 `frontend/app.js` 中的调用
- 记得运行 `test_api.py` 验证 API 行为

### 修改 MCP 工具
- 修改 `backend/mcp_server.py` 后,运行 `test_mcp.py` 验证工具行为
- MCP 工具使用 Pydantic `structured_output=True` 返回结构化数据

### 修改前端
- 前端 `API_BASE` 默认为 `http://127.0.0.1:48000`,修改端口时需同步更新
- 前端不依赖任何构建工具,直接编辑 HTML/CSS/JS 即可

### 数据库路径配置
- 默认路径: `Memo/memo.db` (项目根目录)
- 自定义路径: 设置环境变量 `MEMO_DB_PATH`

### 搜索功能
- 当前只搜索 `title` 和 `content` 字段
- 不包含 tags 搜索 (tags 存储为 JSON 字符串)
- 如需扩展,修改 `backend/memo_service.py` 中的 SQL LIKE 查询

### Python 导入约定
- 使用相对导入: `from . import db`, `from . import memo_service`
- 测试使用绝对导入: `from backend import memo_service`
