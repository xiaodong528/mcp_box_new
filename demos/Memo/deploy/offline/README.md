# MCP Box + Memo 离线部署方案

本目录包含完整的内网离线部署方案，包括文档和自动化脚本。

## 📂 目录结构

```
deploy/offline/
├── README.md                          # 本文件
├── docs/                              # 📚 详细文档
│   ├── README.md                      # 文档中心导航
│   ├── offline-deployment-quickstart.md  # 快速入门指南 (英文)
│   ├── offline-deployment.md          # 完整部署文档 (英文)
│   └── 离线部署快速开始.md              # 快速开始指南 (中文) ⭐
│
└── scripts/                           # 🛠️ 自动化脚本
    ├── 01-build-package.sh           # 外网打包脚本
    ├── 02-deploy-offline.sh          # 内网部署脚本
    ├── 03-health-check.sh            # 健康检查脚本
    └── 04-backup-data.sh             # 数据备份脚本
```

---

## 🚀 快速开始 (3步完成)

### 第一步：外网环境 - 构建离线包

```bash
cd /path/to/mcp_box_new/demos/Memo/deploy/offline
bash scripts/01-build-package.sh
```

**产物**: `packages/mcp-box-offline-YYYYMMDD.tar.gz` (约 1-1.5 GB)

### 第二步：传输到内网

```bash
# 从 packages 目录传输离线包
cd /path/to/mcp_box_new/demos/Memo/deploy/offline
scp packages/mcp-box-offline-YYYYMMDD.tar.gz user@internal-server:/opt/
```

### 第三步：内网环境 - 一键部署

```bash
# 解压
cd /opt && mkdir mcp-box-deploy
tar -xzf mcp-box-offline-YYYYMMDD.tar.gz -C mcp-box-deploy
cd mcp-box-deploy

# 配置
cp config/.env.template .env && vim .env

# 部署
bash scripts/02-deploy-offline.sh

# 验证
bash scripts/03-health-check.sh
```

---

## 📖 文档指引

### 快速参考 (推荐新手)
- 🇨🇳 **[中文快速开始](docs/离线部署快速开始.md)** - 最简洁的中文指引
- 🇬🇧 **[Quick Start Guide](docs/offline-deployment-quickstart.md)** - 5分钟英文快速入门

### 详细文档 (深入了解)
- 📘 **[完整部署文档](docs/offline-deployment.md)** - 详细步骤、高级配置、故障排查
- 📚 **[文档中心](docs/README.md)** - 所有文档导航和索引

---

## 🛠️ 脚本说明

| 脚本 | 用途 | 运行环境 | 详细说明 |
|------|------|----------|----------|
| `01-build-package.sh` | 构建离线部署包 | 外网环境 | 自动构建镜像、下载依赖、打包 |
| `02-deploy-offline.sh` | 一键部署服务 | 内网环境 | 导入镜像、配置环境、启动服务 |
| `03-health-check.sh` | 健康检查和监控 | 内网环境 | 检查容器状态、端口、服务健康 |
| `04-backup-data.sh` | 数据备份 | 内网环境 | 备份数据卷、配置文件 |

---

## 📦 离线包内容

打包脚本会生成包含以下内容的离线包：

- **Docker 镜像** (~1.4 GB)
  - `mcp-box:latest` - MCP 工具服务器
  - `memo-app:latest` - Memo 应用
  - `python:3.12-slim` - 基础镜像 (可选)

- **Python 依赖** (~100 MB)
  - MCP Box 所需依赖
  - Memo 应用所需依赖
  - E2B 本地依赖包

- **配置文件**
  - `docker-compose.yml`
  - `.env.template`
  - `Dockerfile`
  - `docker-entrypoint.sh`

- **部署脚本**
  - 部署、健康检查、备份脚本

---

## 🔧 服务端口

| 服务 | 端口 | 说明 |
|------|------|------|
| Memo API | 48000 | RESTful API 接口 |
| Memo MCP | 48001 | MCP SSE 服务器 |
| Memo 前端 | 48002 | 静态网页服务 |
| MCP Box SSE | 47070 | MCP 工具服务器 |
| MCP Box 管理 | 47071 | HTTP 管理接口 |

---

## ✅ 验证部署

部署完成后，通过以下方式验证：

```bash
# 健康检查脚本
bash scripts/03-health-check.sh

# 手动验证
curl http://localhost:48000/health  # 应返回 {"status":"healthy"}
curl -N http://localhost:47070/sse  # 应返回 SSE 事件流

# 访问前端
open http://localhost:48002  # 浏览器访问
```

---

## ⚠️ 前置要求

- **Docker**: >= 20.10
- **Docker Compose**: >= 2.0 (推荐)
- **磁盘空间**: >= 5 GB
- **端口可用**: 47070-47071, 48000-48002

**检查命令**:
```bash
docker --version
docker compose version
df -h
netstat -tuln | grep -E '47070|47071|48000|48001|48002'
```

---

## 🔐 必填配置

编辑 `.env` 文件配置以下参数：

```bash
# E2B 沙箱配置 (必填)
E2B_JUPYTER_HOST=your-e2b-host
E2B_API_KEY=your-api-key

# 存储模式 (推荐文件模式)
STORE_IN_FILE=true

# 数据库配置 (仅当 STORE_IN_FILE=false 时需要)
DB_HOST=your-db-host
DB_PORT=5432
DB_NAME=mcpbox
DB_USER=mcpbox
DB_PASSWORD=your-password
```

---

## 🧰 常用运维命令

### 服务管理
```bash
docker compose ps              # 查看状态
docker compose logs -f         # 查看日志
docker compose restart         # 重启服务
docker compose stop            # 停止服务
docker compose start           # 启动服务
```

### 定期维护
```bash
# 健康检查 (建议 cron: */5 * * * *)
bash scripts/03-health-check.sh

# 数据备份 (建议 cron: 0 2 * * *)
bash scripts/04-backup-data.sh
```

---

## 🐛 故障排查

遇到问题时，请参考：

1. **[快速入门 - 故障排查](docs/离线部署快速开始.md)** (中文)
2. **[Quick Start - Troubleshooting](docs/offline-deployment-quickstart.md#-故障排查)** (英文)
3. **[完整文档 - 故障排查](docs/offline-deployment.md#四故障排查)** (详细)

**常见问题速查**:
- 容器启动失败 → `docker logs <container>`
- 健康检查失败 → `docker restart <container>`
- 端口被占用 → 修改 `docker-compose.yml` 端口映射
- 数据丢失 → 从备份恢复 (见文档)

---

## 📊 部署流程图

```
┌─────────────────┐                    ┌─────────────────┐
│   外网环境       │                    │   内网环境       │
├─────────────────┤                    ├─────────────────┤
│ 1. 构建镜像     │                    │ 1. 解压离线包   │
│ 2. 下载依赖     │                    │ 2. 导入镜像     │
│ 3. 打包离线包   │ ─────传输────────► │ 3. 配置环境     │
│                 │                    │ 4. 启动服务     │
└─────────────────┘                    │ 5. 健康检查     │
                                       │ 6. 定期备份     │
                                       └─────────────────┘
```

---

## 💡 最佳实践

1. ✅ **版本管理**: 使用明确的镜像标签,不用 `latest`
2. ✅ **定期备份**: 配置 cron 每天自动备份
3. ✅ **健康监控**: 配置 cron 每5分钟健康检查
4. ✅ **日志轮转**: 启用 Docker 日志轮转,防止磁盘占满
5. ✅ **资源限制**: 设置容器 CPU 和内存限制
6. ✅ **安全加固**: 非 root 用户、网络隔离、敏感信息保护
7. ✅ **文档维护**: 记录自定义配置和变更历史

---

## 📚 相关项目文档

- [MCP Box 项目文档](../../../CLAUDE.md) - MCP Box 核心架构
- [Memo 应用文档](../../CLAUDE.md) - Memo 应用开发指南

---

## 📞 获取帮助

如遇到问题,请提供:
1. Docker 版本: `docker version`
2. 容器日志: `docker logs <container>`
3. 系统信息: `uname -a`, `df -h`
4. 错误截图或完整日志

---

**祝部署顺利! 🎉**
