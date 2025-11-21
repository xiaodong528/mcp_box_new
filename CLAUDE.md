# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目概述

MCP Box 是一个动态 MCP (Model Context Protocol) 工具服务器,允许在运行时动态添加、删除和执行 MCP 工具。支持两种运行模式:
- **本地模式**: 工具直接在服务器进程中执行
- **沙箱模式**: 工具在 E2B Code Interpreter 沙箱环境中隔离执行

## 核心架构

### 主要组件

1. **McpBox** (`src/mcp_box.py`)
   - 核心服务器类,管理 MCP 工具的生命周期
   - 提供 HTTP API 用于动态添加/删除工具
   - 支持从数据库或配置文件加载工具定义
   - 在独立线程中运行 FastMCP 服务器 (守护线程)
   - 使用 Starlette 提供 HTTP 管理接口

2. **FastMCPBox** (`src/fast_mcp_sandbox.py`)
   - 继承自 FastMCP,重写 `call_tool()` 实现沙箱执行
   - 使用 E2B Code Interpreter 在隔离环境中执行工具代码
   - 自动解析和安装工具依赖 (通过 `<requirements>` 标签)
   - 将 MCP 工具装饰器转换为可执行的 Python 函数
   - 执行后自动清理沙箱资源 (`sandbox.kill()`)

3. **存储层**
   - PostgreSQL 数据库存储工具定义 (可选,通过 `STORE_IN_FILE` 环境变量控制)
   - JSON 配置文件 `config/mcp-tool.json` 作为文件存储选项

### 双端口架构

- **Port N** (默认 47070): FastMCP SSE 服务器,处理 MCP 协议通信
- **Port N+1** (默认 47071): HTTP 管理接口,用于添加/删除工具

**关键实现**: `mcp_box.py:114-119` 启动 FastMCP 服务器在守护线程中,主线程运行 HTTP 管理接口

### 工具定义格式

MCP 工具使用装饰器定义,支持两种参数注解方式:

```python
# 方式1: 使用 Pydantic Field 注解
@mcp.tool(description='工具描述')
def tool_name(
    param1: Annotated[str, Field(description="参数说明")],
    param2: Annotated[int, Field(default=1, description="参数说明")]
):
    # 工具实现
    return result

# 方式2: 使用 annotations 字典
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

工具代码可包含依赖声明:
```python
"""
<requirements>
package1>=1.0.0
package2>=2.0.0
</requirements>
"""
```

## 开发命令

### 环境准备

```bash
# 创建虚拟环境
python -m venv .venv
source .venv/bin/activate  # Windows: .venv\Scripts\activate

# 安装依赖
pip install -r requirements.txt

# 配置环境变量
cp .env.example .env
# 编辑 .env 文件配置必要参数
```

### 运行服务器

**本地模式** (工具直接在进程中执行):
```bash
# 在项目根目录
python src/mcp_box.py --host localhost --port 47070

# 或使用 -m 方式
python -m src.mcp_box --host localhost --port 47070
```

**沙箱模式** (需配置 E2B):
```bash
# 确保 .env 中配置了 E2B_JUPYTER_HOST
# STORE_IN_FILE=false 使用数据库存储
# STORE_IN_FILE=true 使用 JSON 文件存储
python src/mcp_box.py --host localhost --port 47070
```

### 测试

**集成测试** (测试完整流程):
```bash
# 确保服务器已启动
# 终端 1: python src/mcp_box.py --host localhost --port 47070
# 终端 2:
python tests/test_mcp_box.py --host localhost --port 47070
```

**测试流程说明** (`tests/test_mcp_box.py`):
1. 通过 HTTP API (端口 47071) 添加 MCP 工具
2. 连接到 SSE 端点 (端口 47070)
3. 列出所有可用工具
4. 调用工具并验证结果
5. 可选:删除工具并验证

**工具示例** (`tests/test_mcp_box.py:8-56`):
- `getHostFaultCause`: 使用 Pydantic Field 注解的工具示例
- `getMiddleFaultCause`: 使用 annotations 字典的工具示例

### 环境配置

需要配置 `.env` 文件中的以下变量:

```bash
# E2B 沙箱配置 (沙箱模式必需)
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

## HTTP API

### 添加工具

```http
POST http://localhost:47071/add_mcp_tool/?mcp_tool_name=<工具名称>
Content-Type: text/plain; charset=utf-8

<工具Python代码>
```

响应:
```json
{
  "result": 0,  // 0=成功, 1=已存在, 2=解析失败
  "error": "",
  "transport": "sse",
  "mcp_box_url": "http://localhost:47070/sse"
}
```

### 删除工具

```http
POST http://localhost:47071/remove_mcp_tool/?mcp_tool_name=<工具名称>
```

响应:
```json
{
  "result": 0,  // 0=成功, 1=不存在
  "error": ""
}
```

## 关键实现细节

### 动态工具加载流程

**启动时加载** (`mcp_box.py:59-67`):
1. 根据 `STORE_IN_FILE` 环境变量选择存储方式
2. 从数据库或 JSON 文件加载工具定义
3. 通过 `store_code_to_sandbox()` 注册工具

**运行时添加** (`mcp_box.py:226-256`):
1. HTTP POST 请求到 `/add_mcp_tool/` 端点
2. 解析请求体中的 Python 代码
3. 检查工具名称是否已存在
4. 使用 `exec()` 动态执行工具定义代码
5. 如果是沙箱模式,存储工具代码到 `tool_codes` 字典
6. 可选:保存到数据库或 JSON 文件

### 沙箱执行流程

**核心实现** (`fast_mcp_sandbox.py:101-133`):

1. 获取工具代码: `self.tool_codes[name]`
2. 解析依赖: `parse_requirements()` 提取 `<requirements>` 标签
3. 准备代码: `prepare_sandbox_code()` 移除 `@mcp.tool` 装饰器
4. 注入调用: `add_run_code()` 添加工具调用代码
5. 创建沙箱: `Sandbox(**self.e2b_config)`
6. 安装依赖: `sandbox.commands.run(f"pip install --quiet {requirement}")`
7. 执行代码: `sandbox.run_code(run_code)`
8. 转换结果: `_convert_to_content(execution.results)`
9. 清理资源: `sandbox.kill()` (在 finally 块中)

**代码处理示例** (`fast_mcp_sandbox.py:135-149`):
- `prepare_sandbox_code()`: 移除装饰器,保留纯函数定义
- `add_run_code()`: 添加函数调用代码,如 `tool_name(param1='value', param2=2)`

### Schema 合并机制

**问题**: MCP 工具的参数描述可能在 Pydantic Field 或 annotations 字典中

**解决** (`fast_mcp_sandbox.py:89-99`):
- `merge_tool_input_schema()` 将 annotations 中的参数描述合并到 inputSchema
- 确保 MCP 客户端能正确显示参数说明

### 数据库 Schema

```sql
CREATE TABLE agents_mcp_box (
    id VARCHAR PRIMARY KEY,
    user_id VARCHAR,
    mcp_tool_name VARCHAR,
    mcp_tool_code TEXT
)
```

**表初始化**: `mcp_box.py:88-105` 自动创建表 (如果不存在)

### 日志系统

- **日志文件**: `logs/mcpbox.log`
- **轮转配置**: 每天午夜,保留 5 天
- **日志级别**: INFO (可在 `src/utils/logging.py` 中调整)
- **关键日志点**:
  - 服务器启动/停止
  - 工具添加/删除操作
  - 沙箱执行错误 (包含完整堆栈跟踪)
  - 数据库操作

## 示例项目: Memo 备忘录应用

**位置**: `demos/Memo/`

**说明**: 展示如何将 MCP Box 与实际应用集成

**架构**:
- 后端 API 服务 (端口 48000): FastAPI + SQLite
- MCP SSE 服务 (端口 48001): 提供 MCP 工具接口
- 前端应用 (端口 48002): 静态 HTML/CSS/JS
- MCP Box 服务 (端口 47070/47071): 动态工具管理

**MCP 工具集成方式**:
- MCP 工具通过 HTTP 请求调用后端 API
- 工具可访问容器内网络地址 (如 `http://memo:48000`)
- 工具代码示例见 `demos/Memo/README.md`

**启动方式**:
```bash
cd demos/Memo
# Docker 方式
docker compose up -d
# 本地开发方式见 demos/Memo/README.md
```

## 注意事项

### 开发规范

1. **线程安全**: MCP 服务器在独立守护线程中运行,确保主线程继续处理 HTTP 管理请求
2. **资源清理**: 沙箱执行后必须调用 `sandbox.kill()` 释放资源 (已在 finally 块中实现)
3. **工具命名**: 工具名称必须唯一,添加前检查 `_tool_manager.get_tool(name)`
4. **错误处理**: 沙箱执行错误包含 `error.name`、`error.value` 和 `error.traceback`
5. **参数传递**: 使用 `repr()` 序列化参数值,避免引号问题

### 导入方式支持

**项目支持两种导入方式** (`mcp_box.py:21-34`, `fast_mcp_sandbox.py:19-28`):
- 作为模块导入: `from src.mcp_box import McpBox`
- 直接运行: `python src/mcp_box.py`

**实现原理**: 使用 try-except 处理相对导入失败,动态调整 `sys.path`

### 常见问题

**Q: 工具代码中的 `mcp` 对象从哪里来?**
A: 动态添加工具时,通过 `exec(code, namespace)` 注入,`namespace = {"mcp": self.mcp}`

**Q: 沙箱模式和本地模式如何选择?**
A: `mcp_box.py:38-47` 根据 `sandbox_config` 参数选择:
- `sandbox_config=None`: 本地模式,`FastMCP`
- `sandbox_config={}`: 沙箱模式,`FastMCPBox`

**Q: 如何调试工具执行?**
A: 
1. 查看日志: `tail -f logs/mcpbox.log`
2. 启用 E2B 调试: `E2B_DEBUG=true`
3. 使用测试脚本单步调试: `tests/test_mcp_box.py`

**Q: 如何处理工具依赖冲突?**
A: 沙箱模式下每次调用创建新的 E2B 实例,依赖隔离;本地模式需注意全局环境污染