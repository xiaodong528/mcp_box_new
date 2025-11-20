#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}=======================================${NC}"
echo -e "${BLUE}Memo Application - Docker Stop${NC}"
echo -e "${BLUE}=======================================${NC}"
echo ""

# Navigate to project root
cd "$(dirname "$0")/.."

# Check if containers are running
if ! docker compose ps | grep -q "memo-app"; then
    echo -e "${YELLOW}No running containers found${NC}"
    exit 0
fi

# Ask for confirmation to remove volumes
echo -e "${YELLOW}Do you want to remove data volumes (database will be deleted)?${NC}"
echo "  1) Stop only (keep data)"
echo "  2) Stop and remove volumes (delete all data)"
read -p "Choose option [1/2] (default: 1): " choice
choice=${choice:-1}

if [ "$choice" = "2" ]; then
    echo ""
    echo -e "${RED}WARNING: This will delete all memo data!${NC}"
    read -p "Are you sure? [y/N]: " confirm
    if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
        echo -e "${YELLOW}Stopping containers and removing volumes...${NC}"
        docker compose down -v
        echo -e "${GREEN}✓ Stopped and cleaned up (data deleted)${NC}"
    else
        echo -e "${YELLOW}Cancelled${NC}"
        exit 0
    fi
else
    echo -e "${YELLOW}Stopping containers...${NC}"
    docker compose stop
    echo -e "${GREEN}✓ Stopped (data preserved)${NC}"
    echo ""
    echo -e "${BLUE}To start again:${NC} docker compose up -d"
    echo -e "${BLUE}To remove:${NC}      docker compose down"
fi

echo ""
echo -e "${BLUE}=======================================${NC}"
