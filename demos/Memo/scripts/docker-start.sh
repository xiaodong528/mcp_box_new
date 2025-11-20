#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}=======================================${NC}"
echo -e "${BLUE}Memo Application - Docker Quick Start${NC}"
echo -e "${BLUE}=======================================${NC}"
echo ""

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo -e "${RED}ERROR: Docker is not installed${NC}"
    echo "Please install Docker from https://www.docker.com/"
    exit 1
fi

# Check if Docker Compose is available
if ! docker compose version &> /dev/null; then
    echo -e "${RED}ERROR: Docker Compose is not available${NC}"
    echo "Please install Docker Compose or update Docker Desktop"
    exit 1
fi

# Navigate to project root
cd "$(dirname "$0")/.."

# Check for port conflicts
echo -e "${YELLOW}Checking for port conflicts...${NC}"
for port in 48000 48001 48002 47070 47071; do
    if lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1; then
        echo -e "${RED}ERROR: Port $port is already in use${NC}"
        echo "Please stop the service using this port or change the port in docker-compose.yml"
        exit 1
    fi
done
echo -e "${GREEN}✓ All ports are available${NC}"
echo ""

# Build Docker image
echo -e "${YELLOW}Building Docker image...${NC}"
docker compose build
echo -e "${GREEN}✓ Build completed${NC}"
echo ""

# Start containers
echo -e "${YELLOW}Starting containers...${NC}"
docker compose up -d
echo -e "${GREEN}✓ Containers started${NC}"
echo ""

# Wait for services to be ready
echo -e "${YELLOW}Waiting for services to be ready...${NC}"
sleep 5

# Check health
if curl -s http://localhost:48000/health > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Memo API Server is healthy${NC}"
else
    echo -e "${RED}✗ Memo API Server is not responding${NC}"
    echo "Check logs with: docker compose logs memo"
fi

# Check MCP Box health (may not have health endpoint initially)
if curl -s http://localhost:47071/ > /dev/null 2>&1; then
    echo -e "${GREEN}✓ MCP Box is responding${NC}"
else
    echo -e "${YELLOW}⚠ MCP Box may still be starting${NC}"
    echo "Check logs with: docker compose logs mcp-box"
fi
echo ""

# Display access URLs
echo -e "${BLUE}=======================================${NC}"
echo -e "${GREEN}✓ Memo Application is running!${NC}"
echo -e "${BLUE}=======================================${NC}"
echo ""
echo -e "${BLUE}Memo Services:${NC}"
echo -e "  Frontend:        http://localhost:48002"
echo -e "  API Docs:        http://localhost:48000/docs"
echo -e "  Health Check:    http://localhost:48000/health"
echo -e "  MCP SSE:         http://localhost:48001/sse"
echo ""
echo -e "${BLUE}MCP Box Services:${NC}"
echo -e "  SSE Endpoint:    http://localhost:47070/sse"
echo -e "  Management API:  http://localhost:47071"
echo ""
echo -e "${YELLOW}Useful commands:${NC}"
echo "  View logs:       docker compose logs -f"
echo "  Stop:            docker compose stop"
echo "  Restart:         docker compose restart"
echo "  Full cleanup:    docker compose down -v"
echo ""
echo -e "${BLUE}=======================================${NC}"
