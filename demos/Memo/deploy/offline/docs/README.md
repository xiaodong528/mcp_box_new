# MCP Box 文档中心

## 📚 文档导航

### 快速开始

**如果你需要在内网部署服务**, 请按以下顺序阅读:

1. ⚡ [**快速入门指南**](offline-deployment-quickstart.md) - **推荐首先阅读**
   - 5 分钟快速部署
   - 核心命令参考
   - 常见问题排查

2. 📖 [**完整部署文档**](offline-deployment.md) - 详细参考
   - 分步部署指南
   - 高级配置选项
   - 故障排查详解
   - 运维和监控

### 项目文档

- [MCP Box 项目文档](../../../../CLAUDE.md) - MCP Box 项目架构和开发指南
- [Memo 应用文档](../../../CLAUDE.md) - Memo 应用详细说明

---

## 🛠️ 部署脚本

所有脚本位于 `../scripts/` 目录:

| 脚本 | 用途 | 运行环境 |
|------|------|----------|
| `01-build-package.sh` | 构建离线部署包 | 外网环境 |
| `02-deploy-offline.sh` | 一键部署服务 | 内网环境 |
| `03-health-check.sh` | 健康检查和监控 | 内网环境 |
| `04-backup-data.sh` | 数据备份 | 内网环境 |

**使用方法**:
```bash
# 外网环境: 打包
bash ../scripts/01-build-package.sh

# 内网环境: 部署
bash scripts/02-deploy-offline.sh

# 内网环境: 检查
bash scripts/03-health-check.sh

# 内网环境: 备份
bash scripts/04-backup-data.sh
```

---

## 🚀 快速参考

### 外网环境准备 (一键命令)

```bash
# 构建离线包
cd /path/to/mcp_box_new/demos/Memo/deploy/offline
bash scripts/01-build-package.sh

# 传输到内网 (离线包在 packages 目录)
scp packages/mcp-box-offline-$(date +%Y%m%d).tar.gz user@internal-server:/opt/
```

**产物**: `packages/mcp-box-offline-YYYYMMDD.tar.gz` (约 1-1.5 GB)

---

### 内网环境部署 (一键命令)

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

## 📦 离线包结构

```
mcp-box-offline-YYYYMMDD.tar.gz
├── docker-images/              # Docker 镜像 (~1.4 GB)
├── python-packages/            # Python 依赖 (~100 MB)
├── lib/                        # 本地依赖包
├── config/                     # 配置文件
│   ├── docker-compose.yml
│   ├── .env.template
│   ├── Dockerfile
│   └── docker-entrypoint.sh
├── scripts/                    # 部署脚本
│   ├── 02-deploy-offline.sh
│   ├── 03-health-check.sh
│   └── 04-backup-data.sh
└── README.md                   # 说明文档
```

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

## 🧰 常用运维命令

### 服务管理

```bash
# 查看状态
docker compose ps

# 查看日志
docker compose logs -f

# 重启服务
docker compose restart

# 停止服务
docker compose stop

# 启动服务
docker compose start
```

### 健康检查

```bash
# 手动检查
bash scripts/03-health-check.sh

# 自动检查 (cron)
*/5 * * * * /opt/mcp-box-deploy/scripts/03-health-check.sh
```

### 数据备份

```bash
# 手动备份
bash scripts/04-backup-data.sh

# 定期备份 (cron)
0 2 * * * /opt/mcp-box-deploy/scripts/04-backup-data.sh
```

### 服务访问

```bash
# Memo API 健康检查
curl http://localhost:48000/health

# MCP Box SSE 端点
curl -N http://localhost:47070/sse

# 前端访问
http://localhost:48002
```

---

## ⚠️ 前置要求

- **Docker**: >= 20.10
- **Docker Compose**: >= 2.0 (推荐)
- **磁盘空间**: 至少 5 GB
- **端口**: 47070-47071, 48000-48002 未被占用

**检查命令**:
```bash
docker --version
docker compose version
df -h
netstat -tuln | grep -E '47070|47071|48000|48001|48002'
```

---

## 🔐 必填配置

编辑 `.env` 文件:

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

## 📊 部署流程图

```
外网环境                    内网环境
   │                          │
   ├─ 构建 Docker 镜像        ├─ 解压离线包
   ├─ 下载 Python 依赖        ├─ 导入 Docker 镜像
   ├─ 打包离线部署包          ├─ 配置环境变量
   │                          ├─ 启动服务
   └─ 传输到内网  ─────────►  ├─ 健康检查
                              └─ 定期备份
```

---

## 🐛 故障排查速查表

| 问题 | 检查命令 | 解决方案 |
|------|----------|----------|
| 容器启动失败 | `docker ps -a && docker logs <container>` | 检查配置和日志 |
| 健康检查失败 | `curl http://localhost:48000/health` | 重启容器 |
| 端口被占用 | `netstat -tuln \| grep <port>` | 修改端口映射 |
| 数据丢失 | `docker volume ls` | 从备份恢复 |
| 网络不通 | `docker network inspect memo-network` | 检查网络配置 |

详细排查步骤请参考 [快速入门指南 - 故障排查](offline-deployment-quickstart.md#-故障排查)

---

## 💡 最佳实践

1. ✅ **定期备份**: 每天自动备份数据卷
2. ✅ **监控告警**: 配置健康检查和自动重启
3. ✅ **日志管理**: 启用日志轮转,防止磁盘占满
4. ✅ **版本管理**: 使用明确的镜像标签,避免使用 `latest`
5. ✅ **资源限制**: 设置容器 CPU 和内存限制
6. ✅ **安全加固**: 最小权限、网络隔离、敏感信息保护
7. ✅ **文档记录**: 记录自定义配置和变更历史

---

## 📖 文档版本

| 版本 | 日期 | 说明 |
|------|------|------|
| v1.0 | 2025-01-20 | 初始版本,完整离线部署方案 |

---

## 📞 获取帮助

如遇到问题,请提供:
1. Docker 版本: `docker version`
2. 容器日志: `docker logs <container>`
3. 系统信息: `uname -a`, `df -h`
4. 错误截图或完整日志

---

## 🎯 下一步

- [ ] 阅读 [快速入门指南](offline-deployment-quickstart.md)
- [ ] 准备外网环境打包
- [ ] 配置内网环境
- [ ] 执行部署
- [ ] 配置监控和备份

**祝部署顺利! 🎉**
