#!/bin/bash
# =====================================================
# MCP Box 健康检查脚本
# 用途: 监控服务状态, 可配置为 cron 任务
# =====================================================

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# 配置
MEMO_API_URL="${MEMO_API_URL:-http://localhost:48000}"
MEMO_MCP_URL="${MEMO_MCP_URL:-http://localhost:48001}"
MCP_BOX_SSE_URL="${MCP_BOX_SSE_URL:-http://localhost:47070}"
MCP_BOX_MGMT_URL="${MCP_BOX_MGMT_URL:-http://localhost:47071}"

# 告警邮箱 (可选)
ALERT_EMAIL="${ALERT_EMAIL:-}"

# 告警函数
send_alert() {
    local service=$1
    local message=$2

    echo -e "${RED}[ALERT] ${service}: ${message}${NC}" >&2

    if [ -n "$ALERT_EMAIL" ]; then
        echo "$message" | mail -s "[MCP Box Alert] $service Down" "$ALERT_EMAIL"
    fi
}

# 重启服务函数
restart_service() {
    local container=$1
    echo -e "${YELLOW}尝试重启容器: ${container}${NC}"

    if docker restart "$container" > /dev/null 2>&1; then
        echo -e "${GREEN}容器 ${container} 重启成功${NC}"
        return 0
    else
        echo -e "${RED}容器 ${container} 重启失败${NC}"
        return 1
    fi
}

# 初始化检查结果
ALL_PASSED=true

echo "========================================="
echo "MCP Box 健康检查报告"
echo "时间: $(date '+%Y-%m-%d %H:%M:%S')"
echo "========================================="
echo ""

# 1. 检查 Docker 容器状态
echo -e "${YELLOW}[1/5] 检查 Docker 容器状态${NC}"

CONTAINERS=("memo-app" "mcp-box")
for CONTAINER in "${CONTAINERS[@]}"; do
    if docker ps --filter "name=${CONTAINER}" --filter "status=running" | grep -q "${CONTAINER}"; then
        echo -e "${GREEN}✅ 容器 ${CONTAINER} 运行中${NC}"
    else
        echo -e "${RED}❌ 容器 ${CONTAINER} 未运行${NC}"
        ALL_PASSED=false
        send_alert "$CONTAINER" "Container is not running"

        # 自动重启 (可选)
        if [ "${AUTO_RESTART:-false}" = "true" ]; then
            restart_service "$CONTAINER"
        fi
    fi
done
echo ""

# 2. 检查 Memo API 健康端点
echo -e "${YELLOW}[2/5] 检查 Memo API 健康端点${NC}"

HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "${MEMO_API_URL}/health" 2>/dev/null)
if [ "$HTTP_CODE" = "200" ]; then
    RESPONSE=$(curl -s "${MEMO_API_URL}/health" 2>/dev/null)
    echo -e "${GREEN}✅ Memo API 健康检查通过${NC}"
    echo "   响应: $RESPONSE"
else
    echo -e "${RED}❌ Memo API 健康检查失败 (HTTP $HTTP_CODE)${NC}"
    ALL_PASSED=false
    send_alert "Memo API" "Health check failed with HTTP $HTTP_CODE"

    if [ "${AUTO_RESTART:-false}" = "true" ]; then
        restart_service "memo-app"
    fi
fi
echo ""

# 3. 检查 MCP Box SSE 端点
echo -e "${YELLOW}[3/5] 检查 MCP Box SSE 端点${NC}"

if timeout 3 curl -N "${MCP_BOX_SSE_URL}/sse" 2>/dev/null | head -1 | grep -q "event"; then
    echo -e "${GREEN}✅ MCP Box SSE 端点可访问${NC}"
else
    echo -e "${RED}❌ MCP Box SSE 端点检查失败${NC}"
    ALL_PASSED=false
    send_alert "MCP Box SSE" "SSE endpoint is not accessible"

    if [ "${AUTO_RESTART:-false}" = "true" ]; then
        restart_service "mcp-box"
    fi
fi
echo ""

# 4. 检查端口监听
echo -e "${YELLOW}[4/5] 检查端口监听状态${NC}"

PORTS=(
    "48000:Memo API"
    "48001:Memo MCP"
    "48002:Memo Frontend"
    "47070:MCP Box SSE"
    "47071:MCP Box MGMT"
)

for PORT_INFO in "${PORTS[@]}"; do
    PORT=$(echo "$PORT_INFO" | cut -d: -f1)
    NAME=$(echo "$PORT_INFO" | cut -d: -f2)

    if netstat -tuln 2>/dev/null | grep -q ":${PORT} " || ss -tuln 2>/dev/null | grep -q ":${PORT} "; then
        echo -e "${GREEN}✅ 端口 ${PORT} (${NAME}) 正在监听${NC}"
    else
        echo -e "${RED}❌ 端口 ${PORT} (${NAME}) 未监听${NC}"
        ALL_PASSED=false
    fi
done
echo ""

# 5. 检查数据卷和磁盘空间
echo -e "${YELLOW}[5/5] 检查数据卷和磁盘空间${NC}"

VOLUMES=("memo-data" "mcp-config" "mcp-logs")
for VOLUME in "${VOLUMES[@]}"; do
    if docker volume ls | grep -q "$VOLUME"; then
        echo -e "${GREEN}✅ 数据卷 ${VOLUME} 存在${NC}"

        # 检查卷大小
        SIZE=$(docker run --rm -v ${VOLUME}:/data alpine du -sh /data 2>/dev/null | cut -f1)
        echo "   大小: ${SIZE:-N/A}"
    else
        echo -e "${RED}❌ 数据卷 ${VOLUME} 不存在${NC}"
        ALL_PASSED=false
    fi
done

# 检查宿主机磁盘空间
DISK_USAGE=$(df -h / | tail -1 | awk '{print $5}' | sed 's/%//')
if [ "$DISK_USAGE" -lt 90 ]; then
    echo -e "${GREEN}✅ 磁盘使用率: ${DISK_USAGE}%${NC}"
else
    echo -e "${RED}❌ 磁盘使用率过高: ${DISK_USAGE}%${NC}"
    ALL_PASSED=false
    send_alert "Disk Space" "Disk usage is at ${DISK_USAGE}%"
fi
echo ""

# 6. 容器资源使用 (可选)
if [ "${CHECK_RESOURCES:-false}" = "true" ]; then
    echo -e "${YELLOW}[额外] 容器资源使用情况${NC}"
    docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}" memo-app mcp-box 2>/dev/null
    echo ""
fi

# 总结报告
echo "========================================="
if [ "$ALL_PASSED" = true ]; then
    echo -e "${GREEN}✅ 所有检查通过!${NC}"
    exit 0
else
    echo -e "${RED}❌ 部分检查失败, 请查看上述日志${NC}"
    echo ""
    echo "常用排查命令:"
    echo "  docker logs memo-app"
    echo "  docker logs mcp-box"
    echo "  docker ps -a"
    echo "  docker inspect memo-app"
    exit 1
fi
