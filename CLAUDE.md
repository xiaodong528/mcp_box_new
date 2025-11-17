# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目概述

MCP Box 是一个动态 MCP (Model Context Protocol) 工具服务器,允许在运行时动态添加、删除和执行 MCP 工具。支持两种运行模式:
- **本地模式**: 工具直接在服务器进程中执行
- **沙箱模式**: 工具在 E2B 沙箱环境中隔离执行

## 核心架构

### 主要组件

1. **McpBox** (`mcp_box.py`)
   - 核心服务器类,管理 MCP 工具的生命周期
   - 提供 HTTP API 用于动态添加/删除工具
   - 支持从数据库或配置文件加载工具定义
   - 运行在独立线程中的 FastMCP 服务器

2. **FastMCPBox** (`fast_mcp_sandbox.py`)
   - 继承自 FastMCP,增强沙箱执行能力
   - 使用 E2B Code Interpreter 在隔离环境中执行工具代码
   - 自动解析和安装工具依赖 (通过 `<requirements>` 标签)
   - 将 MCP 工具装饰器转换为可执行的 Python 函数

3. **存储层**
   - PostgreSQL 数据库存储工具定义 (可选)
   - JSON 配置文件 `config/mcp-tool.json` 作为文件存储选项

### 端口架构

- **Port N** (默认 47070): FastMCP SSE 服务器,处理 MCP 协议通信
- **Port N+1** (默认 47071): HTTP 管理接口,用于添加/删除工具

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

### 运行服务器

```bash
# 本地模式运行
python mcp_box.py --host localhost --port 47070

# 使用 Docker 运行
bash start.sh
```

### 测试

```bash
# 运行测试客户端
python test_mcp_box.py --host localhost --port 47070
```

测试流程:
1. 通过 HTTP API 添加 MCP 工具
2. 连接到 SSE 端点
3. 列出所有可用工具
4. 调用工具并验证结果
5. 可选:删除工具并验证

### 环境配置

需要配置 `.env` 文件中的以下变量:

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

### 沙箱执行流程

1. 工具代码通过 `prepare_sandbox_code()` 处理:移除 `@mcp.tool` 装饰器
2. 解析 `<requirements>` 标签获取依赖
3. 创建 E2B 沙箱实例
4. 安装依赖包
5. 注入工具调用代码 (通过 `add_run_code()`)
6. 执行并收集结果
7. 清理沙箱资源

### 数据库 Schema

```sql
CREATE TABLE agents_mcp_box (
    id VARCHAR PRIMARY KEY,
    user_id VARCHAR,
    mcp_tool_name VARCHAR,
    mcp_tool_code TEXT
)
```

### 日志系统

- 日志文件位置: `logs/mcpbox.log`
- 日志轮转: 每天午夜,保留 5 天
- 日志级别: INFO (可在 `_logging.py` 中调整)

## 注意事项

1. **线程安全**: MCP 服务器在独立线程中运行,确保主线程继续处理 HTTP 管理请求
2. **资源清理**: 沙箱执行后必须调用 `sandbox.kill()` 释放资源
3. **工具命名**: 工具名称必须唯一,添加前检查是否已存在
4. **错误处理**: 沙箱执行错误会包含详细的错误名称、值和堆栈跟踪
5. **参数 Schema 合并**: `merge_tool_input_schema()` 将 annotations 中的参数描述合并到 inputSchema
