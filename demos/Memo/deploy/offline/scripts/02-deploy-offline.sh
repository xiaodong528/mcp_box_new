#!/bin/bash
# =====================================================
# MCP Box 内网离线部署脚本 (内网环境使用)
# =====================================================

set -e  # 遇到错误立即退出

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEPLOY_ROOT="$(dirname "${SCRIPT_DIR}")"

echo -e "${GREEN}部署根目录: ${DEPLOY_ROOT}${NC}"

# 检查必需命令
check_command() {
    if ! command -v $1 &> /dev/null; then
        echo -e "${RED}错误: 未找到命令 '$1', 请先安装${NC}"
        exit 1
    fi
}

echo -e "${YELLOW}=== 步骤 1/6: 环境检查 ===${NC}"
check_command docker
check_command tar
check_command gzip

# 检查 Docker 版本
DOCKER_VERSION=$(docker version --format '{{.Server.Version}}' 2>/dev/null || echo "unknown")
echo -e "${GREEN}Docker 版本: ${DOCKER_VERSION}${NC}"

if command -v docker compose &> /dev/null; then
    COMPOSE_CMD="docker compose"
    COMPOSE_VERSION=$(docker compose version --short 2>/dev/null || echo "unknown")
else
    echo -e "${YELLOW}警告: 未找到 docker compose, 将使用手动部署模式${NC}"
    COMPOSE_CMD=""
fi

echo -e "${GREEN}Docker Compose 版本: ${COMPOSE_VERSION:-N/A}${NC}"

# 检查端口占用
check_port() {
    if netstat -tuln 2>/dev/null | grep -q ":$1 "; then
        echo -e "${RED}警告: 端口 $1 已被占用${NC}"
        return 1
    fi
    return 0
}

echo -e "${YELLOW}检查端口占用...${NC}"
PORTS=(47070 47071 48000 48001 48002)
for PORT in "${PORTS[@]}"; do
    if check_port $PORT; then
        echo -e "${GREEN}端口 $PORT 可用${NC}"
    else
        echo -e "${YELLOW}端口 $PORT 被占用, 请检查${NC}"
    fi
done

echo -e "${YELLOW}=== 步骤 2/6: 导入 Docker 镜像 ===${NC}"
cd "${DEPLOY_ROOT}"

if [ ! -d "docker-images" ]; then
    echo -e "${RED}错误: 未找到 docker-images 目录${NC}"
    exit 1
fi

# 导入镜像
for IMAGE_FILE in docker-images/*.tar.gz; do
    if [ -f "$IMAGE_FILE" ]; then
        echo -e "${GREEN}导入镜像: $(basename $IMAGE_FILE)${NC}"
        docker load < "$IMAGE_FILE"
    fi
done

# 验证镜像
echo -e "${YELLOW}验证导入的镜像:${NC}"
docker images | grep -E 'mcp-box|memo-app|python' || echo -e "${YELLOW}警告: 未找到预期的镜像${NC}"

echo -e "${YELLOW}=== 步骤 3/6: 配置环境变量 ===${NC}"
if [ ! -f "${DEPLOY_ROOT}/.env" ]; then
    if [ -f "${DEPLOY_ROOT}/config/.env.template" ]; then
        echo -e "${YELLOW}未找到 .env 文件, 从模板创建...${NC}"
        cp "${DEPLOY_ROOT}/config/.env.template" "${DEPLOY_ROOT}/.env"
        echo -e "${RED}请编辑 ${DEPLOY_ROOT}/.env 文件配置必要的环境变量${NC}"
        echo -e "${YELLOW}按 Enter 键继续编辑配置...${NC}"
        read
        ${EDITOR:-vi} "${DEPLOY_ROOT}/.env"
    else
        echo -e "${RED}错误: 未找到环境变量模板文件${NC}"
        exit 1
    fi
else
    echo -e "${GREEN}找到现有 .env 文件${NC}"
fi

echo -e "${YELLOW}=== 步骤 4/6: 准备配置文件 ===${NC}"
# 复制 docker-compose.yml 到根目录 (如果不存在)
if [ ! -f "${DEPLOY_ROOT}/docker-compose.yml" ] && [ -f "${DEPLOY_ROOT}/config/docker-compose.yml" ]; then
    echo -e "${GREEN}复制 docker-compose.yml${NC}"
    cp "${DEPLOY_ROOT}/config/docker-compose.yml" "${DEPLOY_ROOT}/"
fi

# 复制 docker-entrypoint.sh (如果不存在)
if [ ! -f "${DEPLOY_ROOT}/docker-entrypoint.sh" ] && [ -f "${DEPLOY_ROOT}/config/docker-entrypoint.sh" ]; then
    echo -e "${GREEN}复制 docker-entrypoint.sh${NC}"
    cp "${DEPLOY_ROOT}/config/docker-entrypoint.sh" "${DEPLOY_ROOT}/"
    chmod +x "${DEPLOY_ROOT}/docker-entrypoint.sh"
fi

echo -e "${YELLOW}=== 步骤 5/6: 启动服务 ===${NC}"
cd "${DEPLOY_ROOT}"

if [ -n "$COMPOSE_CMD" ] && [ -f "docker-compose.yml" ]; then
    echo -e "${GREEN}使用 Docker Compose 启动服务...${NC}"
    $COMPOSE_CMD up -d

    # 等待服务启动
    echo -e "${YELLOW}等待服务启动 (15 秒)...${NC}"
    sleep 15

    # 显示服务状态
    echo -e "${YELLOW}服务状态:${NC}"
    $COMPOSE_CMD ps
else
    echo -e "${YELLOW}手动启动容器模式${NC}"

    # 创建网络
    if ! docker network ls | grep -q memo-network; then
        echo -e "${GREEN}创建 Docker 网络...${NC}"
        docker network create memo-network
    fi

    # 创建数据卷
    for VOLUME in memo-data mcp-config mcp-logs; do
        if ! docker volume ls | grep -q $VOLUME; then
            echo -e "${GREEN}创建数据卷: $VOLUME${NC}"
            docker volume create $VOLUME
        fi
    done

    # 启动 Memo 容器
    echo -e "${GREEN}启动 Memo 应用容器...${NC}"
    docker run -d \
      --name memo-app \
      --network memo-network \
      -p 48000:48000 \
      -p 48001:48001 \
      -p 48002:48002 \
      -v memo-data:/app/data \
      -e MEMO_DB_PATH=/app/data/memo.db \
      -e PYTHONUNBUFFERED=1 \
      --restart unless-stopped \
      memo-app:latest

    # 启动 MCP Box 容器
    echo -e "${GREEN}启动 MCP Box 容器...${NC}"
    docker run -d \
      --name mcp-box \
      --network memo-network \
      -p 47070:47070 \
      -p 47071:47071 \
      -v mcp-config:/app/mcp-box/config \
      -v mcp-logs:/app/mcp-box/logs \
      --env-file "${DEPLOY_ROOT}/.env" \
      --restart unless-stopped \
      mcp-box:latest

    # 等待服务启动
    echo -e "${YELLOW}等待服务启动 (15 秒)...${NC}"
    sleep 15

    # 显示容器状态
    echo -e "${YELLOW}容器状态:${NC}"
    docker ps --filter "name=memo-app" --filter "name=mcp-box"
fi

echo -e "${YELLOW}=== 步骤 6/6: 健康检查 ===${NC}"

# Memo API 健康检查
echo -e "${GREEN}检查 Memo API...${NC}"
if curl -f http://localhost:48000/health > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Memo API 运行正常${NC}"
else
    echo -e "${RED}❌ Memo API 健康检查失败${NC}"
    echo -e "${YELLOW}查看日志: docker logs memo-app${NC}"
fi

# MCP Box SSE 检查
echo -e "${GREEN}检查 MCP Box SSE 端点...${NC}"
if timeout 3 curl -N http://localhost:47070/sse > /dev/null 2>&1; then
    echo -e "${GREEN}✅ MCP Box SSE 端点可访问${NC}"
else
    echo -e "${RED}❌ MCP Box SSE 端点检查失败${NC}"
    echo -e "${YELLOW}查看日志: docker logs mcp-box${NC}"
fi

# 显示访问信息
echo ""
echo -e "${GREEN}=== 部署完成! ===${NC}"
echo -e "${YELLOW}服务访问地址:${NC}"
echo "  Memo API:       http://localhost:48000"
echo "  Memo MCP SSE:   http://localhost:48001/sse"
echo "  Memo 前端:      http://localhost:48002"
echo "  MCP Box SSE:    http://localhost:47070/sse"
echo "  MCP Box 管理:   http://localhost:47071"
echo ""
echo -e "${YELLOW}常用命令:${NC}"
if [ -n "$COMPOSE_CMD" ]; then
    echo "  查看日志:    $COMPOSE_CMD logs -f"
    echo "  停止服务:    $COMPOSE_CMD stop"
    echo "  启动服务:    $COMPOSE_CMD start"
    echo "  重启服务:    $COMPOSE_CMD restart"
    echo "  删除服务:    $COMPOSE_CMD down"
else
    echo "  查看日志:    docker logs -f memo-app"
    echo "  停止服务:    docker stop memo-app mcp-box"
    echo "  启动服务:    docker start memo-app mcp-box"
    echo "  重启服务:    docker restart memo-app mcp-box"
    echo "  删除服务:    docker rm -f memo-app mcp-box"
fi
echo ""
echo -e "${YELLOW}健康检查:${NC}"
echo "  bash ${SCRIPT_DIR}/03-health-check.sh"
echo ""
echo -e "${YELLOW}数据备份:${NC}"
echo "  bash ${SCRIPT_DIR}/04-backup-data.sh"

echo -e "${GREEN}✅ 所有任务完成!${NC}"
