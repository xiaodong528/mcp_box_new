# Memo 离线部署完整指南

本文档提供 Memo 应用的完整离线部署说明，适用于内网环境或无法访问互联网的服务器。

## 📋 目录

- [部署概述](#部署概述)
- [系统要求](#系统要求)
- [部署流程](#部署流程)
  - [阶段 1: 准备离线部署包（有网环境）](#阶段-1-准备离线部署包有网环境)
  - [阶段 2: 传输到内网环境](#阶段-2-传输到内网环境)
  - [阶段 3: 内网部署](#阶段-3-内网部署)
- [服务管理](#服务管理)
- [数据管理](#数据管理)
- [故障排查](#故障排查)
- [常见问题](#常见问题)

---

## 部署概述

Memo 是一个前后端分离的备忘录应用，包含以下组件：

- **Memo 应用服务**

  - API Server (FastAPI) - 端口 48000
  - MCP SSE Server (FastMCP) - 端口 48001
  - Frontend Static Server - 端口 48002
- **MCP Box 服务**

  - MCP SSE 服务器 - 端口 47070
  - HTTP 管理接口 - 端口 47071

**离线部署特点**：

- ✅ 无需互联网连接
- ✅ 使用预构建的 Docker 镜像
- ✅ 数据持久化到 Docker volumes
- ✅ 一键部署脚本
- ✅ 完整的健康检查和监控

---

## 系统要求

### 硬件要求

- **CPU**: 2 核或更多
- **内存**: 4GB 或更多
- **磁盘**: 10GB 可用空间（包括镜像和数据）

### 软件要求

- **操作系统**: Linux / macOS / Windows (with WSL2)
- **Docker**: 20.10 或更高版本
- **Docker Compose**: 1.29 或更高版本

### 端口要求

确保以下端口未被占用：

- `48000` - Memo API 服务
- `48001` - Memo MCP SSE 服务
- `48002` - Memo 前端服务
- `47070` - MCP Box SSE 服务
- `47071` - MCP Box 管理接口

---

## 部署流程

### 阶段 1: 准备离线部署包（有网环境）

在可以访问互联网的环境中执行：

#### 1.1 克隆项目（如果还未克隆）

```bash
git clone <项目地址>
cd Memo
```

#### 1.2 运行准备脚本

```bash
bash scripts/prepare-offline-images.sh
```

脚本将自动执行：

- ✅ 构建 Docker 镜像
- ✅ 保存镜像为 tmcptar 包
- ✅ 打包所有必需文件
- ✅ 创建 `memo-offline-deploy.tar.gz` (约 1GB)

#### 1.3 验证生成的文件

```bash
ls -lh images/memo-offline-deploy.tar.gz
```

### 阶段 2: 传输到内网环境

使用 USB 驱动器、网络传输或其他方式将 `memo-offline-deploy.tar.gz` 传输到内网服务器。

```bash
# 示例：使用 scp 传输
scp images/memo-offline-deploy.tar.gz user@internal-server:/path/to/deploy/

# 示例：使用 USB 驱动器
cp images/memo-offline-deploy.tar.gz /mnt/usb/
```

### 阶段 3: 内网部署

在内网服务器上执行：

#### 3.1 解压部署包

```bash
mkdir -p memo-deploy
cd memo-deploy
tar -xzf /path/to/memo-offline-deploy.tar.gz
```

#### 3.2 运行部署脚本

```bash
bash deploy-offline.sh
```

部署脚本将引导您完成：

1. ✅ 环境检查（Docker 安装和运行状态）
2. ✅ 加载 Docker 镜像
3. ✅ 配置环境变量（可选）
4. ✅ 启动服务
5. ✅ 验证部署状态
6. ✅ 显示访问地址和管理命令

#### 3.3 访问服务

部署完成后，通过以下地址访问：

- **前端界面**: http://localhost:48002
- **API 文档**: http://localhost:48000/docs
- **API 健康检查**: http://localhost:48000/health
- **MCP SSE**: http://localhost:47070/sse
- **MCP 管理**: http://localhost:47071

---

## 服务管理

### 查看服务状态

```bash
docker-compose -f docker-compose.prod.yml ps
```

### 查看日志

```bash
# 查看所有服务日志
docker-compose -f docker-compose.prod.yml logs -f

# 查看特定服务日志
docker-compose -f docker-compose.prod.yml logs -f memo
docker-compose -f docker-compose.prod.yml logs -f mcp-box
```

### 重启服务

```bash
# 重启所有服务
docker-compose -f docker-compose.prod.yml restart

# 重启特定服务
docker-compose -f docker-compose.prod.yml restart memo
```

### 停止服务

```bash
docker-compose -f docker-compose.prod.yml stop
```

### 启动服务

```bash
docker-compose -f docker-compose.prod.yml start
```

### 删除服务

```bash
# 停止并删除容器（保留数据）
docker-compose -f docker-compose.prod.yml down

# 停止并删除容器和数据卷（⚠️ 数据将丢失）
docker-compose -f docker-compose.prod.yml down -v
```

---

## 数据管理

### 数据存储位置

Memo 使用 Docker volumes 进行数据持久化：

- `memo-data`: Memo SQLite 数据库
- `mcp-config`: MCP Box 工具配置
- `mcp-logs`: MCP Box 日志

### 查看数据卷

```bash
docker volume ls | grep memo
```

### 备份数据

```bash
# 备份 Memo 数据库
docker run --rm \
  -v memo-data:/data \
  -v $(pwd):/backup \
  ubuntu tar czf /backup/memo-data-backup.tar.gz /data

# 备份 MCP 配置
docker run --rm \
  -v mcp-config:/data \
  -v $(pwd):/backup \
  ubuntu tar czf /backup/mcp-config-backup.tar.gz /data
```

### 恢复数据

```bash
# 恢复 Memo 数据库
docker run --rm \
  -v memo-data:/data \
  -v $(pwd):/backup \
  ubuntu tar xzf /backup/memo-data-backup.tar.gz -C /

# 恢复 MCP 配置
docker run --rm \
  -v mcp-config:/data \
  -v $(pwd):/backup \
  ubuntu tar xzf /backup/mcp-config-backup.tar.gz -C /
```

### 清理旧数据

```bash
# ⚠️ 警告：此操作将删除所有数据，无法恢复！
docker volume rm memo-data mcp-config mcp-logs
```

---

## 故障排查

### 问题 1: 服务无法启动

**症状**: `docker-compose up` 后容器立即退出

**排查步骤**:

1. 查看容器日志

   ```bash
   docker-compose -f docker-compose.prod.yml logs
   ```
2. 检查端口占用

   ```bash
   # Linux/macOS
   lsof -i :48000
   lsof -i :48001
   lsof -i :48002
   lsof -i :47070
   lsof -i :47071

   # 或使用 netstat
   netstat -tuln | grep -E '48000|48001|48002|47070|47071'
   ```
3. 检查 Docker 资源

   ```bash
   docker system df
   docker system prune  # 清理未使用的资源
   ```

### 问题 2: API 服务健康检查失败

**症状**: `/health` 端点无响应

**排查步骤**:

1. 检查容器内部状态

   ```bash
   docker exec -it memo-app curl http://localhost:48000/health
   ```
2. 查看详细日志

   ```bash
   docker-compose -f docker-compose.prod.yml logs memo | tail -100
   ```
3. 检查数据库文件权限

   ```bash
   docker exec -it memo-app ls -la /app/data/
   ```

### 问题 3: 前端页面无法访问

**症状**: 访问 `http://localhost:48002` 显示 404 或无法连接

**排查步骤**:

1. 检查容器是否运行

   ```bash
   docker ps | grep memo-app
   ```
2. 检查前端文件是否存在

   ```bash
   docker exec -it memo-app ls -la /app/frontend/
   ```
3. 测试容器内部访问

   ```bash
   docker exec -it memo-app curl http://localhost:48002
   ```

### 问题 4: MCP 工具无法调用

**症状**: MCP 工具列表为空或调用失败

**排查步骤**:

1. 检查 MCP Box 服务状态

   ```bash
   docker-compose -f docker-compose.prod.yml logs mcp-box
   ```
2. 验证 MCP 配置文件

   ```bash
   docker exec -it mcp-box cat /app/mcp-box/config/mcp-tool.json
   ```
3. 测试 MCP 端点

   ```bash
   curl http://localhost:47070/sse
   ```

### 问题 5: 镜像加载失败

**症状**: `docker load` 时报错

**排查步骤**:

1. 验证 tar 文件完整性

   ```bash
   tar -tzf memo-app.tar > /dev/null
   tar -tzf mcp-box.tar > /dev/null
   tar -tzf python-base.tar > /dev/null
   ```
2. 检查磁盘空间

   ```bash
   df -h
   ```
3. 清理 Docker 缓存后重试

   ```bash
   docker system prune -a
   docker load -i memo-app.tar
   ```

---

## 常见问题

### Q1: 如何更改服务端口？

**A**: 编辑 `docker-compose.prod.yml` 文件，修改 `ports` 配置：

```yaml
services:
  memo:
    ports:
      - "8000:48000"   # 将 API 端口改为 8000
      - "8001:48001"
      - "8002:48002"
```

然后重启服务：

```bash
docker-compose -f docker-compose.prod.yml restart
```

### Q2: 如何配置 E2B 沙箱功能？

**A**: 编辑 `.env` 文件，添加 E2B 配置：

```bash
E2B_API_KEY=your_api_key_here
E2B_JUPYTER_HOST=your_sandbox_host
E2B_JUPYTER_PORT=49999
E2B_DEBUG=false
```

重启 MCP Box 服务：

```bash
docker-compose -f docker-compose.prod.yml restart mcp-box
```

### Q3: 如何升级到新版本？

**A**: 按照以下步骤：

1. 备份当前数据
2. 在有网环境准备新版本的离线部署包
3. 传输到内网环境
4. 停止旧服务：`docker-compose -f docker-compose.prod.yml down`
5. 加载新镜像：`docker load -i memo-app.tar`
6. 启动新服务：`docker-compose -f docker-compose.prod.yml up -d`

### Q4: 如何查看资源使用情况？

**A**: 使用以下命令：

```bash
# 查看容器资源使用
docker stats

# 查看磁盘使用
docker system df

# 查看特定容器资源
docker stats memo-app mcp-box
```

### Q5: 如何配置数据库存储模式？

**A**: 默认使用文件存储（`STORE_IN_FILE=true`）。如需使用 PostgreSQL：

1. 编辑 `.env` 文件，配置数据库连接信息
2. 修改 `docker-compose.prod.yml`，设置 `STORE_IN_FILE=false`
3. 确保 PostgreSQL 数据库可访问
4. 重启服务

### Q6: 如何开启/关闭日志记录？

**A**: 日志配置在 `docker-compose.prod.yml` 中：

```yaml
logging:
  driver: "json-file"
  options:
    max-size: "10m"      # 单个日志文件最大 10MB
    max-file: "3"        # 保留 3 个日志文件
```

查看日志文件位置：

```bash
docker inspect --format='{{.LogPath}}' memo-app
```

### Q7: 如何实现高可用部署？

**A**: 推荐方案：

1. 使用 Docker Swarm 或 Kubernetes 编排
2. 配置多副本部署
3. 使用外部 PostgreSQL 数据库（代替 SQLite）
4. 配置负载均衡器（如 Nginx）
5. 设置健康检查和自动重启策略

### Q8: 如何监控服务状态？

**A**: 几种监控方式：

1. **基础监控**

   ```bash
   # 定期检查健康端点
   watch -n 5 'curl -s http://localhost:48000/health'
   ```
2. **日志监控**

   ```bash
   docker-compose -f docker-compose.prod.yml logs -f --tail=100
   ```
3. **资源监控**

   ```bash
   docker stats memo-app mcp-box
   ```
4. **集成监控工具**

   - Prometheus + Grafana
   - ELK Stack (Elasticsearch, Logstash, Kibana)
   - Docker 自带的 monitoring 功能

---

## 附录

### 文件清单

离线部署包包含以下文件：

```
memo-offline-deploy.tar.gz
├── memo-app.tar              # Memo 应用镜像
├── mcp-box.tar               # MCP Box 镜像
├── python-base.tar           # Python 基础镜像
├── docker-compose.prod.yml   # 生产环境配置
├── .env.prod.example         # 环境变量模板
├── deploy-offline.sh         # 部署脚本
└── README-OFFLINE-DEPLOY.md  # 本文档
```

### 版本信息

- **Memo 版本**: 1.0.0
- **MCP Box 版本**: 1.0.0
- **Python 版本**: 3.12
- **FastAPI 版本**: 0.115.6
- **FastMCP 版本**: 0.2.5
