# MCP Box 内网离线部署 - 快速入门

## 🚀 5 分钟快速部署指南

### 外网环境 (打包阶段)

**一键打包**:
```bash
cd /path/to/mcp_box_new
bash scripts/01-build-package.sh
```

**打包产物**:
- `mcp-box-offline-YYYYMMDD.tar.gz` (约 1-1.5 GB)

**传输到内网**:
```bash
scp mcp-box-offline-YYYYMMDD.tar.gz user@internal-server:/opt/
```

---

### 内网环境 (部署阶段)

**步骤 1: 解压离线包**
```bash
cd /opt
mkdir mcp-box-deploy
tar -xzf mcp-box-offline-YYYYMMDD.tar.gz -C mcp-box-deploy
cd mcp-box-deploy
```

**步骤 2: 配置环境变量**
```bash
cp config/.env.template .env
vim .env

# 必填项:
# - E2B_JUPYTER_HOST=your-e2b-host
# - E2B_API_KEY=your-api-key
# - STORE_IN_FILE=true  (推荐)
```

**步骤 3: 一键部署**
```bash
bash scripts/02-deploy-offline.sh
```

**步骤 4: 验证服务**
```bash
bash scripts/03-health-check.sh
```

---

## 📦 离线包内容

```
mcp-box-offline-YYYYMMDD.tar.gz
├── docker-images/           # Docker 镜像 (约 1.4 GB)
│   ├── mcp-box.tar.gz
│   ├── memo-app.tar.gz
│   └── python-3.12-slim.tar.gz
│
├── python-packages/         # Python 依赖 (约 100 MB)
│   └── *.whl, *.tar.gz
│
├── lib/                     # 本地依赖
│   ├── e2b-*.whl
│   └── e2b_code_interpreter-*.whl
│
├── config/                  # 配置文件
│   ├── docker-compose.yml
│   ├── .env.template
│   ├── Dockerfile
│   └── docker-entrypoint.sh
│
└── scripts/                 # 部署脚本
    ├── 02-deploy-offline.sh
    ├── 03-health-check.sh
    └── 04-backup-data.sh
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

## ✅ 验证清单

- [ ] **环境检查**
  ```bash
  docker --version  # >= 20.10
  docker compose version  # >= 2.0
  ```

- [ ] **端口检查**
  ```bash
  netstat -tuln | grep -E '47070|47071|48000|48001|48002'
  # 确保端口未被占用
  ```

- [ ] **镜像导入**
  ```bash
  docker images | grep -E 'mcp-box|memo-app'
  # 应看到两个镜像
  ```

- [ ] **服务启动**
  ```bash
  docker ps --filter "name=memo-app" --filter "name=mcp-box"
  # 两个容器都应该在运行
  ```

- [ ] **健康检查**
  ```bash
  curl http://localhost:48000/health  # 返回 {"status":"healthy"}
  curl -N http://localhost:47070/sse  # 返回 SSE 事件流
  ```

---

## 🛠️ 常用运维命令

### 查看服务状态
```bash
docker compose ps              # Docker Compose 模式
docker ps | grep -E 'memo|mcp' # 手动部署模式
```

### 查看日志
```bash
docker compose logs -f         # 所有服务日志
docker logs -f memo-app        # Memo 应用日志
docker logs -f mcp-box         # MCP Box 日志
```

### 重启服务
```bash
docker compose restart         # 重启所有服务
docker restart memo-app        # 重启 Memo
docker restart mcp-box         # 重启 MCP Box
```

### 停止/启动服务
```bash
docker compose stop            # 停止所有服务
docker compose start           # 启动所有服务
docker compose down            # 停止并删除容器
```

### 数据备份
```bash
bash scripts/04-backup-data.sh
# 备份文件保存在: /opt/mcp-box-backups/
```

### 恢复数据
```bash
# 示例: 恢复 memo-data 卷
BACKUP_FILE=/opt/mcp-box-backups/memo-data_20250120_120000.tar.gz
docker run --rm -v memo-data:/data -v /opt/mcp-box-backups:/backup alpine \
  tar xzf /backup/$(basename $BACKUP_FILE) -C /data
```

---

## ⚠️ 故障排查

### 问题 1: 容器启动失败

**症状**: `docker ps` 看不到运行中的容器

**排查**:
```bash
# 查看退出的容器
docker ps -a

# 查看容器日志
docker logs memo-app
docker logs mcp-box

# 检查配置
docker inspect memo-app | grep -A 20 Env
```

**常见原因**:
- `.env` 文件配置错误
- 端口被占用
- 数据卷权限问题

### 问题 2: 健康检查失败

**症状**: `curl http://localhost:48000/health` 无响应

**排查**:
```bash
# 检查容器是否运行
docker ps --filter "name=memo-app"

# 检查端口监听
docker exec memo-app netstat -tlnp | grep 48000

# 查看应用日志
docker logs --tail 50 memo-app
```

**解决**:
```bash
# 重启容器
docker restart memo-app

# 如果端口冲突,修改 docker-compose.yml
vim docker-compose.yml  # 修改端口映射
docker compose up -d
```

### 问题 3: 容器间网络不通

**症状**: MCP Box 无法访问 Memo API

**排查**:
```bash
# 检查网络
docker network inspect memo-network

# 测试容器间通信
docker exec mcp-box curl http://memo:48000/health
```

**解决**:
```bash
# 确保容器在同一网络
docker network connect memo-network mcp-box
```

### 问题 4: 数据丢失

**症状**: 重启后数据消失

**排查**:
```bash
# 检查数据卷
docker volume ls | grep -E 'memo-data|mcp-config'

# 检查卷挂载
docker inspect memo-app | grep -A 10 Mounts
```

**解决**:
```bash
# 从备份恢复
bash scripts/04-backup-data.sh  # 先备份现有数据
# 然后从之前的备份恢复 (见上方"恢复数据"命令)
```

---

## 📊 监控和维护

### 定期健康检查 (Cron 任务)

```bash
# 编辑 crontab
crontab -e

# 每 5 分钟检查一次
*/5 * * * * /opt/mcp-box-deploy/scripts/03-health-check.sh >> /var/log/mcp-health.log 2>&1

# 启用自动重启
*/5 * * * * AUTO_RESTART=true /opt/mcp-box-deploy/scripts/03-health-check.sh >> /var/log/mcp-health.log 2>&1
```

### 定期数据备份 (Cron 任务)

```bash
# 每天凌晨 2 点备份
0 2 * * * /opt/mcp-box-deploy/scripts/04-backup-data.sh >> /var/log/mcp-backup.log 2>&1

# 自定义备份保留天数
0 2 * * * BACKUP_RETENTION_DAYS=30 /opt/mcp-box-deploy/scripts/04-backup-data.sh >> /var/log/mcp-backup.log 2>&1
```

### 查看资源使用

```bash
# 实时资源监控
docker stats memo-app mcp-box

# 容器日志大小
docker ps -a --format 'table {{.Names}}\t{{.Size}}'

# 磁盘使用
docker system df
df -h /var/lib/docker
```

### 日志轮转

**方法 1: Docker 日志驱动配置**
```yaml
# docker-compose.yml
services:
  memo:
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
```

**方法 2: 系统 logrotate**
```bash
# /etc/logrotate.d/docker-containers
/var/lib/docker/containers/*/*.log {
    daily
    rotate 7
    compress
    missingok
    notifempty
    copytruncate
}
```

---

## 🔐 安全加固

### 1. 限制容器权限
```bash
# 以非 root 用户运行
docker run --user 1000:1000 ...
```

### 2. 网络隔离
```bash
# 仅暴露必要端口
# 内部服务不对外暴露
```

### 3. 敏感信息保护
```bash
# .env 文件权限
chmod 600 .env

# 定期轮换 API 密钥
vim .env  # 更新 E2B_API_KEY
docker compose restart
```

### 4. 防火墙配置
```bash
# UFW 示例
ufw allow 48000/tcp  # Memo API
ufw allow 47070/tcp  # MCP Box SSE
ufw enable
```

---

## 📚 更多文档

- [完整部署文档](offline-deployment.md) - 详细步骤和高级配置
- [MCP Box 项目文档](../CLAUDE.md) - 项目架构和开发指南
- [Memo 应用文档](../demos/Memo/CLAUDE.md) - Memo 应用详细说明

---

## 💡 最佳实践

1. **定期备份**: 每天自动备份数据卷
2. **监控告警**: 配置健康检查和自动重启
3. **日志管理**: 启用日志轮转,防止磁盘占满
4. **版本管理**: 使用明确的镜像标签,不用 `latest`
5. **资源限制**: 设置容器 CPU 和内存限制
6. **安全更新**: 定期更新基础镜像和依赖包
7. **文档维护**: 记录自定义配置和变更历史

---

## ❓ 常见问题 (FAQ)

**Q: 如何更换存储模式 (文件 → 数据库)?**

A: 修改 `.env` 文件中的 `STORE_IN_FILE=false` 并配置数据库连接,然后重启服务。

**Q: 如何更新到新版本?**

A: 在外网重新构建镜像,导出并传输到内网,使用新镜像标签重新部署。

**Q: 数据存储在哪里?**

A: 数据存储在 Docker 数据卷中,使用 `docker volume inspect memo-data` 查看物理路径。

**Q: 如何自定义端口?**

A: 修改 `docker-compose.yml` 中的端口映射,例如 `"8000:48000"` 将外部端口改为 8000。

**Q: 如何扩容或迁移?**

A: 备份数据卷,在新服务器上部署服务,然后恢复数据卷。

---

## 📞 获取帮助

如遇到问题,请提供以下信息:
1. Docker 版本: `docker version`
2. 容器日志: `docker logs mcp-box`
3. 系统信息: `uname -a`, `df -h`
4. 错误截图或完整日志

---

**祝部署顺利! 🎉**
