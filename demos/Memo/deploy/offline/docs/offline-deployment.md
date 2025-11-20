# MCP Box 内网离线部署指南

## 📋 部署架构概览

本项目包含两个主要服务：

- **MCP Box**: 动态 MCP 工具服务器 (端口 47070-47071)
- **Memo**: 备忘录示例应用 (端口 48000-48002)

## 🎯 离线部署准备清单

### 一、外网环境准备工作 (打包阶段)

#### 1.1 Docker 镜像准备

**步骤 1: 构建应用镜像**

```bash
# 构建 MCP Box 镜像
cd /path/to/mcp_box_new
docker build -t mcp-box:latest -f Dockerfile .

# 构建 Memo 应用镜像
cd demos/Memo
docker build -t memo-app:latest -f Dockerfile .
```

**步骤 2: 拉取基础镜像**

```bash
# 拉取 Python 基础镜像 (如果需要重新构建)
docker pull python:3.12-slim
```

**步骤 3: 导出镜像为离线包**

```bash
# 创建镜像导出目录
mkdir -p offline-package/docker-images

# 导出 MCP Box 镜像
docker save mcp-box:latest | gzip > offline-package/docker-images/mcp-box.tar.gz

# 导出 Memo 镜像
docker save memo-app:latest | gzip > offline-package/docker-images/memo-app.tar.gz

# 导出基础镜像 (可选,用于重新构建)
docker save python:3.12-slim | gzip > offline-package/docker-images/python-3.12-slim.tar.gz
```

**预期文件大小**:

- `mcp-box.tar.gz`: ~500MB
- `memo-app.tar.gz`: ~500MB
- `python-3.12-slim.tar.gz`: ~400MB

#### 1.2 Python 依赖离线包

**步骤 1: 下载 Python 依赖**

```bash
# 创建依赖包目录
mkdir -p offline-package/python-packages

# 下载 MCP Box 依赖
cd /path/to/mcp_box_new
pip download -r requirements.txt -d offline-package/python-packages/

# 下载 Memo 应用依赖
cd demos/Memo
pip download -r requirements.txt -d offline-package/python-packages/
```

**注意**:

- 本地 whl 文件 (`lib/*.whl`) 已包含在项目中,无需单独下载
- 下载的依赖包约 100-200MB

#### 1.3 系统依赖准备 (可选)

如果需要在内网重新构建镜像,准备 Debian 系统包:

```bash
# 创建系统包目录
mkdir -p offline-package/debian-packages

# 下载调试工具包 (在 Debian/Ubuntu 环境)
apt-get download \
  vim curl wget netcat-traditional iputils-ping \
  net-tools procps lsof telnet dnsutils htop

mv *.deb offline-package/debian-packages/
```

#### 1.4 配置文件和脚本

**复制必要文件**:

```bash
# 复制部署配置
cp -r demos/Memo/docker-compose.yml offline-package/
cp -r Dockerfile offline-package/
cp -r demos/Memo/Dockerfile offline-package/memo-Dockerfile

# 复制启动脚本
cp demos/Memo/docker-entrypoint.sh offline-package/

# 复制环境变量模板
cat > offline-package/.env.template << 'EOF'
# E2B 沙箱配置
E2B_JUPYTER_HOST=your-e2b-host
E2B_JUPYTER_PORT=49999
E2B_DEBUG=false
E2B_API_KEY=your-api-key

# 数据库配置 (如使用外部 PostgreSQL)
DB_HOST=your-db-host
DB_PORT=5432
DB_NAME=mcpbox
DB_USER=mcpbox
DB_PASSWORD=your-password

# 存储模式 (true=文件, false=数据库)
STORE_IN_FILE=true
EOF
```

#### 1.5 打包所有文件

```bash
# 打包完整离线包
cd offline-package
tar -czf ../mcp-box-offline-$(date +%Y%m%d).tar.gz .

# 验证打包内容
tar -tzf ../mcp-box-offline-$(date +%Y%m%d).tar.gz | head -20
```

**离线包目录结构**:

```
mcp-box-offline-YYYYMMDD.tar.gz
├── docker-images/
│   ├── mcp-box.tar.gz
│   ├── memo-app.tar.gz
│   └── python-3.12-slim.tar.gz
├── python-packages/
│   ├── *.whl
│   └── *.tar.gz
├── debian-packages/ (可选)
│   └── *.deb
├── docker-compose.yml
├── Dockerfile
├── memo-Dockerfile
├── docker-entrypoint.sh
└── .env.template
```

### 二、内网环境部署工作 (安装阶段)

#### 2.1 前置条件检查

**必需软件**:

- Docker Engine >= 20.10
- Docker Compose >= 2.0

**检查命令**:

```bash
docker --version
docker compose version
```

#### 2.2 上传离线包

```bash
# 上传到内网服务器
scp mcp-box-offline-YYYYMMDD.tar.gz user@internal-server:/opt/

# 解压
ssh user@internal-server
cd /opt
tar -xzf mcp-box-offline-YYYYMMDD.tar.gz -C mcp-box-deploy
cd mcp-box-deploy
```

#### 2.3 导入 Docker 镜像

```bash
# 导入镜像
docker load < docker-images/mcp-box.tar.gz
docker load < docker-images/memo-app.tar.gz
# docker load < docker-images/python-3.12-slim.tar.gz  # 如需重新构建

# 验证镜像
docker images | grep -E 'mcp-box|memo-app'
```

**预期输出**:

```
mcp-box      latest    abc123    2 days ago    500MB
memo-app     latest    def456    2 days ago    500MB
```

#### 2.4 配置环境变量

```bash
# 复制并编辑环境变量
cp .env.template .env
vim .env

# 必填配置项说明:
# - E2B_JUPYTER_HOST: E2B 沙箱服务地址
# - E2B_API_KEY: E2B API 密钥
# - STORE_IN_FILE: 建议内网使用 true (文件存储模式)
# - DB_* 配置: 仅当 STORE_IN_FILE=false 时需要
```

#### 2.5 启动服务

**方式 1: 使用 Docker Compose (推荐)**

```bash
# 启动所有服务
docker compose up -d

# 查看服务状态
docker compose ps

# 查看服务日志
docker compose logs -f
```

**方式 2: 手动启动容器**

```bash
# 启动 Memo 应用
docker run -d \
  --name memo-app \
  -p 48000:48000 \
  -p 48001:48001 \
  -p 48002:48002 \
  -v memo-data:/app/data \
  -e MEMO_DB_PATH=/app/data/memo.db \
  memo-app:latest

# 启动 MCP Box
docker run -d \
  --name mcp-box \
  -p 47070:47070 \
  -p 47071:47071 \
  -v mcp-config:/app/mcp-box/config \
  -v mcp-logs:/app/mcp-box/logs \
  --env-file .env \
  mcp-box:latest
```

#### 2.6 验证部署

**健康检查**:

```bash
# Memo API 健康检查
curl http://localhost:48000/health

# MCP Box SSE 端点检查
curl -N http://localhost:47070/sse

# 查看容器日志
docker logs memo-app
docker logs mcp-box
```

**预期响应**:

```json
// Memo API
{"status": "healthy"}

// MCP Box (SSE 连接)
event: endpoint
data: /sse
...
```

### 三、高级配置

#### 3.1 持久化数据备份

```bash
# 备份 Docker 数据卷
docker run --rm \
  -v memo-data:/data \
  -v $(pwd):/backup \
  alpine tar czf /backup/memo-data-backup.tar.gz -C /data .

# 恢复数据
docker run --rm \
  -v memo-data:/data \
  -v $(pwd):/backup \
  alpine tar xzf /backup/memo-data-backup.tar.gz -C /data
```

#### 3.2 日志管理

```bash
# 配置日志轮转 (docker-compose.yml)
services:
  memo:
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
  mcp-box:
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
```

#### 3.3 资源限制

```bash
# 添加资源限制 (docker-compose.yml)
services:
  memo:
    deploy:
      resources:
        limits:
          cpus: '1.0'
          memory: 1G
        reservations:
          cpus: '0.5'
          memory: 512M
```

#### 3.4 网络隔离

```bash
# 使用自定义网络
docker network create --driver bridge mcp-internal-network

# 启动时指定网络
docker run --network mcp-internal-network ...
```

### 四、故障排查

#### 4.1 常见问题

**问题 1: 镜像导入失败**

```bash
# 检查镜像包完整性
gzip -t docker-images/mcp-box.tar.gz

# 重新导入
gunzip -c docker-images/mcp-box.tar.gz | docker load
```

**问题 2: 容器无法启动**

```bash
# 查看详细日志
docker logs --tail 100 mcp-box

# 检查配置
docker inspect mcp-box | grep -A 10 Env
```

**问题 3: 网络连通性问题**

```bash
# 检查容器网络
docker network inspect memo-network

# 测试容器间通信
docker exec memo-app curl http://mcp-box:47070/sse
```

**问题 4: 数据卷权限问题**

```bash
# 检查卷权限
docker run --rm -v memo-data:/data alpine ls -la /data

# 修复权限
docker run --rm -v memo-data:/data alpine chown -R 1000:1000 /data
```

#### 4.2 调试技巧

**进入容器调试**:

```bash
# 进入运行中的容器
docker exec -it mcp-box bash

# 检查进程
ps aux | grep python

# 检查端口监听
netstat -tlnp

# 测试网络连接
curl localhost:47070/sse
```

**查看资源使用**:

```bash
# 容器资源统计
docker stats mcp-box memo-app

# 磁盘使用
docker system df
```

### 五、更新和维护

#### 5.1 服务更新

**准备新镜像**:

```bash
# 外网环境构建新版本
docker build -t mcp-box:v2.0 .
docker save mcp-box:v2.0 | gzip > mcp-box-v2.0.tar.gz

# 传输到内网
scp mcp-box-v2.0.tar.gz user@internal-server:/opt/
```

**内网环境更新**:

```bash
# 导入新镜像
docker load < mcp-box-v2.0.tar.gz

# 停止旧容器
docker compose down

# 修改 docker-compose.yml 中的镜像标签
vim docker-compose.yml  # mcp-box:v2.0

# 启动新容器
docker compose up -d
```

#### 5.2 数据迁移

**从文件模式迁移到数据库模式**:

```bash
# 1. 备份现有数据
docker cp mcp-box:/app/mcp-box/config/mcp-tool.json ./backup/

# 2. 准备数据库环境变量
vim .env  # STORE_IN_FILE=false, 配置 DB_*

# 3. 重启服务
docker compose restart mcp-box

# 4. 手动导入数据到数据库 (需自行编写导入脚本)
```

### 六、安全建议

#### 6.1 最小权限原则

```bash
# 以非 root 用户运行容器
docker run --user 1000:1000 ...
```

#### 6.2 网络安全

```bash
# 仅暴露必要端口
# 使用内部网络隔离服务

# 配置防火墙
ufw allow 48000/tcp  # Memo API
ufw allow 47070/tcp  # MCP SSE
```

#### 6.3 敏感信息管理

```bash
# 使用 Docker secrets (Swarm 模式)
echo "your-db-password" | docker secret create db_password -

# 或使用 .env 文件并设置权限
chmod 600 .env
```

### 七、监控和告警

#### 7.1 健康检查监控

**Cron 任务示例**:

```bash
# 添加到 crontab
*/5 * * * * /opt/mcp-box-deploy/scripts/health-check.sh

# health-check.sh 内容
#!/bin/bash
if ! curl -f http://localhost:48000/health > /dev/null 2>&1; then
  echo "Memo API is down!" | mail -s "Alert" admin@example.com
  docker restart memo-app
fi
```

#### 7.2 日志收集

**集成到日志系统**:

```bash
# 使用 syslog 驱动
docker run --log-driver=syslog --log-opt syslog-address=tcp://log-server:514 ...
```

### 八、性能优化

#### 8.1 容器优化

```bash
# 使用多阶段构建减小镜像体积
# 启用 BuildKit
DOCKER_BUILDKIT=1 docker build -t mcp-box:optimized .
```

#### 8.2 资源调优

```bash
# 调整 Docker 守护进程配置
vim /etc/docker/daemon.json
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "storage-driver": "overlay2"
}
```

## 📊 部署检查清单

- [ ] 外网环境打包完成
  - [ ] Docker 镜像导出
  - [ ] Python 依赖下载
  - [ ] 配置文件准备
- [ ] 内网环境准备
  - [ ] Docker/Compose 安装
  - [ ] 网络环境配置
  - [ ] 存储空间检查 (至少 5GB)
- [ ] 部署执行
  - [ ] 镜像导入成功
  - [ ] 环境变量配置
  - [ ] 服务启动成功
- [ ] 功能验证
  - [ ] 健康检查通过
  - [ ] 端口连通性测试
  - [ ] 业务功能测试
- [ ] 运维配置
  - [ ] 日志轮转配置
  - [ ] 备份策略设置
  - [ ] 监控告警部署

## 🔗 相关文档

- [MCP Box 项目文档](../CLAUDE.md)
- [Memo 应用文档](../demos/Memo/CLAUDE.md)
- [Docker 官方文档](https://docs.docker.com/)
- [Docker Compose 文档](https://docs.docker.com/compose/)

## ⚠️ 注意事项

1. **时区配置**: 容器默认使用 UTC 时区,如需本地时区,添加 `-e TZ=Asia/Shanghai`
2. **文件权限**: 数据卷权限问题可能导致容器无法写入,需确保正确的 UID/GID
3. **端口冲突**: 确保内网环境中端口 47070-47071, 48000-48002 未被占用
4. **镜像版本**: 建议使用明确的版本标签而非 `latest`,便于版本管理
5. **依赖更新**: Python 依赖包可能存在安全漏洞,定期更新并重新打包
6. **E2B 配置**: 沙箱模式需要正确配置 E2B 服务地址和 API 密钥
