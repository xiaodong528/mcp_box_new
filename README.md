# MCP Box

## 概述

MCP Box 是一个动态 MCP (Model Context Protocol) 工具服务器,允许在运行时动态添加、删除和执行 MCP 工具。支持两种运行模式:

- **本地模式**: 工具直接在服务器进程中执行
- **沙箱模式**: 工具在 E2B 沙箱环境中隔离执行,提供增强的安全性

## 核心特性

- 🔧 **动态工具管理**: 通过 HTTP API 在运行时添加和删除 MCP 工具
- 🔒 **沙箱执行**: 在 E2B Code Interpreter 环境中隔离工具执行
- 💾 **灵活存储**: 支持 PostgreSQL 数据库和 JSON 文件两种存储方式
- 📦 **自动依赖管理**: 自动解析和安装工具依赖
- 🚀 **双传输协议**: 支持 SSE (Server-Sent Events) 和 HTTP 流式传输
- 🔌 **FastMCP 集成**: 基于 FastMCP 框架构建,提供强大的 MCP 协议支持

## 架构设计

### 核心组件

```
┌─────────────────────────────────────────────────────────┐
│                    MCP Box 服务器                         │
├─────────────────────────────────────────────────────────┤
│  端口 N (47070)     │  FastMCP SSE 服务器               │
│                      │  - MCP 协议处理器                 │
│                      │  - 工具注册表                      │
├─────────────────────────────────────────────────────────┤
│  端口 N+1 (47071)   │  HTTP 管理接口                    │
│                      │  - 添加工具端点                    │
│                      │  - 删除工具端点                    │
└─────────────────────────────────────────────────────────┘
           │                            │
           │                            │
           ▼                            ▼
┌──────────────────┐          ┌──────────────────┐
│    存储层        │          │   E2B 沙箱       │
│  - PostgreSQL    │          │  - 代码执行器    │
│  - JSON 文件     │          │  - Pip 管理器    │
└──────────────────┘          └──────────────────┘
```

### 组件说明

1. **McpBox** (`src/mcp_box.py`)
   - 核心服务器类,管理 MCP 工具的生命周期
   - 提供 HTTP API 用于动态工具操作
   - 从数据库或配置文件加载工具定义
   - 在独立线程中运行 FastMCP 服务器

2. **FastMCPBox** (`src/fast_mcp_sandbox.py`)
   - 继承自 FastMCP,增强沙箱执行能力
   - 使用 E2B Code Interpreter 在隔离环境中执行
   - 通过 `<requirements>` 标签自动解析依赖
   - 将 MCP 工具装饰器转换为可执行的 Python 函数

3. **存储层**
   - PostgreSQL 数据库用于持久化工具存储(可选)
   - JSON 配置文件 `config/mcp-tool.json` 用于文件存储

## 安装

### 前置要求

- Python 3.10+
- PostgreSQL (如果使用数据库存储)
- E2B API 访问权限 (用于沙箱模式)

### 安装步骤

1. 克隆仓库:

```bash
git clone <仓库地址>
cd mcp_box_new
```

2. 创建虚拟环境:

```bash
python -m venv .venv
source .venv/bin/activate  # Windows: .venv\Scripts\activate
```

3. 安装依赖:

```bash
pip install -r requirements.txt
```

4. 配置环境变量:

```bash
cp .env.example .env
# 编辑 .env 文件配置您的设置
```

## 配置说明

创建 `.env` 文件并配置以下变量:

```bash
# E2B 沙箱配置
E2B_JUPYTER_HOST=<沙箱主机地址>
E2B_JUPYTER_PORT=49999
E2B_DEBUG=true

# 数据库配置 (如果使用数据库存储)
DB_HOST=<数据库主机>
DB_PORT=5432
DB_NAME=mcpbox
DB_USER=mcpbox
DB_PASSWORD=<密码>

# 存储模式
STORE_IN_FILE=false  # true 使用文件存储, false 使用数据库
```

## 使用方法

### 启动服务器

**本地模式:**

```bash
python src/mcp_box.py --host localhost --port 47070
```

**使用 Docker:**

```bash
bash scripts/docker/start.sh
```

`start.sh` 脚本将:
- 从 Dockerfile 构建 Docker 镜像
- 创建持久化的 Docker 卷用于存储日志和配置
- 停止并删除已存在的容器
- 启动新容器并挂载卷

**Docker 卷管理:**

项目包含卷管理脚本:

```bash
# 停止服务器
bash scripts/docker/stop.sh

# 卷管理(备份、恢复、检查)
bash scripts/docker/manage-volumes.sh list       # 列出所有卷
bash scripts/docker/manage-volumes.sh inspect    # 显示卷详情
bash scripts/docker/manage-volumes.sh backup     # 备份卷到 ./backups/
bash scripts/docker/manage-volumes.sh restore    # 从备份恢复
bash scripts/docker/manage-volumes.sh clean      # 删除所有卷 (警告:数据丢失!)
```

**创建的 Docker 卷:**
- `mcp-box-logs`: 存储应用日志(挂载到 `/app/mcp-box/logs`)
- `mcp-box-config`: 存储配置文件(挂载到 `/app/mcp-box/config`)

**常用 Docker 命令:**

```bash
# 查看日志
docker logs -f mcp-box-server

# 进入容器 Shell
docker exec -it mcp-box-server /bin/bash

# 重启服务器
docker restart mcp-box-server

# 查看卷内容
docker run --rm -v mcp-box-logs:/logs alpine ls -la /logs
```

### 运行测试

```bash
python tests/test_mcp_box.py --host localhost --port 47070
```

## MCP 工具定义

MCP 工具使用装饰器定义,支持两种参数注解方式:

**方式 1: 使用 Pydantic Field 注解**

```python
from typing import Annotated
from pydantic import Field

@mcp.tool(description='工具描述')
def tool_name(
    param1: Annotated[str, Field(description="参数说明")],
    param2: Annotated[int, Field(default=1, description="参数说明")]
):
    # 工具实现
    return result
```

**方式 2: 使用 annotations 字典**

```python
@mcp.tool(
    description='工具描述',
    annotations={
        "parameters": {
            "param1": {"description": "参数说明"},
            "param2": {"description": "参数说明"}
        }
    }
)
def tool_name(param1: str, param2: int = 1):
    # 工具实现
    return result
```

**依赖声明:**

```python
"""
<requirements>
package1>=1.0.0
package2>=2.0.0
</requirements>
"""
```

## HTTP API 参考

### 添加工具

**端点:** `POST http://localhost:47071/add_mcp_tool/?mcp_tool_name=<工具名称>`

**请求头:**

```
Content-Type: text/plain; charset=utf-8
```

**请求体:** Python 工具代码 (纯文本格式)

**响应:**

```json
{
  "result": 0,  // 0=成功, 1=已存在, 2=解析失败
  "error": "",
  "transport": "sse",
  "mcp_box_url": "http://localhost:47070/sse"
}
```

**示例:**

```bash
curl -X POST "http://localhost:47071/add_mcp_tool/?mcp_tool_name=myTool" \
  -H "Content-Type: text/plain; charset=utf-8" \
  --data-binary @tool.py
```

### 删除工具

**端点:** `POST http://localhost:47071/remove_mcp_tool/?mcp_tool_name=<工具名称>`

**响应:**

```json
{
  "result": 0,  // 0=成功, 1=不存在
  "error": ""
}
```

**示例:**

```bash
curl -X POST "http://localhost:47071/remove_mcp_tool/?mcp_tool_name=myTool"
```

## 数据库模式

```sql
CREATE TABLE agents_mcp_box (
    id VARCHAR PRIMARY KEY,
    user_id VARCHAR,
    mcp_tool_name VARCHAR,
    mcp_tool_code TEXT
)
```

## 开发指南

### 项目结构

```
mcp_box_new/
├── src/
│   ├── mcp_box.py           # 主服务器实现
│   ├── fast_mcp_sandbox.py  # 沙箱执行引擎
│   └── utils/
│       └── logging.py        # 日志配置
├── tests/
│   └── test_mcp_box.py      # 集成测试
├── config/
│   └── mcp-tool.json        # 工具定义 (文件存储)
├── logs/                     # 日志文件
├── requirements.txt          # Python 依赖
└── .env                      # 环境配置
```

### 日志系统

- **位置:** `logs/mcpbox.log`
- **轮转:** 每天午夜,保留 5 天
- **级别:** INFO (可在 `src/utils/logging.py` 中配置)

## 重要说明

1. **线程安全**: MCP 服务器在独立线程中运行,确保主线程继续处理 HTTP 请求
2. **资源清理**: 沙箱执行后必须调用 `sandbox.kill()` 释放资源
3. **工具命名**: 工具名称必须唯一,添加前检查是否已存在
4. **错误处理**: 沙箱执行错误会包含详细的错误名称、值和堆栈跟踪
5. **Schema 合并**: `merge_tool_input_schema()` 将 annotations 中的参数描述合并到 inputSchema

## 许可证

[在此添加许可证信息]

## 贡献

[在此添加贡献指南]
