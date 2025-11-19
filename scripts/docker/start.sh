#!/bin/bash

# 获取项目根目录 (脚本位于 scripts/docker/ 下,向上两级)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

echo "📁 Project root: $PROJECT_ROOT"
echo ""

# 创建 Docker 卷(如果不存在)
echo "Creating Docker volumes..."
docker volume create mcp-box-logs 2>/dev/null || true
docker volume create mcp-box-config 2>/dev/null || true

# 停止并删除旧容器(如果存在)
echo "Stopping existing container..."
docker stop mcp-box-server 2>/dev/null || true
docker rm mcp-box-server 2>/dev/null || true

# 构建 Docker 镜像
echo "Building Docker image..."
cd "$PROJECT_ROOT"
docker build -t mcp-box-server:latest .

if [ $? -ne 0 ]; then
  echo ""
  echo "❌ Failed to build Docker image"
  exit 1
fi

echo "✅ Docker image built successfully"
echo ""

# 启动 MCP Box 服务器
echo "Starting MCP Box Server..."
docker run -itd \
  -e TZ=Asia/Shanghai \
  -p 47070:47070 \
  -p 47071:47071 \
  -v mcp-box-logs:/app/mcp-box/logs \
  -v mcp-box-config:/app/mcp-box/config \
  -e E2B_JUPYTER_PORT=49999 \
  -e E2B_DEBUG="false" \
  -e E2B_JUPYTER_HOST="10.1.207.156" \
  -e E2B_API_KEY="e2b_833bb39cd9cb0d20dd4c13638af22864531d652c" \
  -e DB_HOST="10.19.88.9" \
  -e DB_PORT=5432 \
  -e DB_NAME="mcpbox" \
  -e DB_USER="mcpbox" \
  -e DB_PASSWORD="mcpbox" \
  -e STORE_IN_FILE=True \
  --name mcp-box-server \
  mcp-box-server:latest

if [ $? -eq 0 ]; then
  echo ""
  echo "✅ MCP Box Server started successfully!"
  echo ""
  echo "📊 Docker Volumes:"
  echo "  - Logs: mcp-box-logs -> /app/mcp-box/logs"
  echo "  - Config: mcp-box-config -> /app/mcp-box/config"
  echo ""
  echo "🔍 Useful commands:"
  echo "  View logs:    docker logs -f mcp-box-server"
  echo "  Stop server:  docker stop mcp-box-server"
  echo "  Restart:      docker restart mcp-box-server"
  echo "  Remove:       docker rm -f mcp-box-server"
  echo ""
  echo "🌐 Service endpoints:"
  echo "  MCP SSE:      http://localhost:47070/sse"
  echo "  Management:   http://localhost:47071"
else
  echo ""
  echo "❌ Failed to start MCP Box Server"
  exit 1
fi
