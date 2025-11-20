#!/bin/bash
# =====================================================
# MCP Box 数据备份脚本
# 用途: 备份 Docker 数据卷, 可配置为 cron 任务
# =====================================================

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# 配置
BACKUP_DIR="${BACKUP_DIR:-/opt/mcp-box-backups}"
BACKUP_RETENTION_DAYS="${BACKUP_RETENTION_DAYS:-7}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# 创建备份目录
mkdir -p "${BACKUP_DIR}"

echo -e "${GREEN}MCP Box 数据备份脚本${NC}"
echo "备份目录: ${BACKUP_DIR}"
echo "时间戳: ${TIMESTAMP}"
echo "保留天数: ${BACKUP_RETENTION_DAYS}"
echo ""

# 备份数据卷函数
backup_volume() {
    local volume_name=$1
    local backup_file="${BACKUP_DIR}/${volume_name}_${TIMESTAMP}.tar.gz"

    echo -e "${YELLOW}备份数据卷: ${volume_name}${NC}"

    # 使用临时容器备份数据卷
    docker run --rm \
        -v ${volume_name}:/data:ro \
        -v ${BACKUP_DIR}:/backup \
        alpine \
        tar czf /backup/$(basename ${backup_file}) -C /data .

    if [ -f "$backup_file" ]; then
        local size=$(du -h "$backup_file" | cut -f1)
        echo -e "${GREEN}✅ 备份成功: ${backup_file} (${size})${NC}"
    else
        echo -e "${RED}❌ 备份失败: ${volume_name}${NC}"
        return 1
    fi
}

# 备份所有数据卷
echo -e "${YELLOW}=== 步骤 1/3: 备份数据卷 ===${NC}"

VOLUMES=("memo-data" "mcp-config" "mcp-logs")
for VOLUME in "${VOLUMES[@]}"; do
    if docker volume ls | grep -q "$VOLUME"; then
        backup_volume "$VOLUME"
    else
        echo -e "${YELLOW}⚠️  数据卷 ${VOLUME} 不存在, 跳过${NC}"
    fi
done

echo ""

# 备份 .env 配置文件 (如果存在)
echo -e "${YELLOW}=== 步骤 2/3: 备份配置文件 ===${NC}"

# 尝试查找 .env 文件位置
ENV_LOCATIONS=(
    "/opt/mcp-box/.env"
    "$(dirname "$0")/../.env"
    "$HOME/mcp-box/.env"
)

for ENV_FILE in "${ENV_LOCATIONS[@]}"; do
    if [ -f "$ENV_FILE" ]; then
        ENV_BACKUP="${BACKUP_DIR}/env_${TIMESTAMP}.txt"
        cp "$ENV_FILE" "$ENV_BACKUP"
        echo -e "${GREEN}✅ 配置文件已备份: ${ENV_BACKUP}${NC}"
        break
    fi
done

echo ""

# 清理旧备份
echo -e "${YELLOW}=== 步骤 3/3: 清理旧备份 ===${NC}"

if [ -d "$BACKUP_DIR" ]; then
    echo "清理 ${BACKUP_RETENTION_DAYS} 天前的备份文件..."

    # 查找并删除旧文件
    OLD_FILES=$(find "$BACKUP_DIR" -name "*.tar.gz" -mtime +${BACKUP_RETENTION_DAYS} 2>/dev/null)
    if [ -n "$OLD_FILES" ]; then
        echo "$OLD_FILES" | while read -r file; do
            echo "删除: $(basename $file)"
            rm -f "$file"
        done
        echo -e "${GREEN}✅ 已清理旧备份${NC}"
    else
        echo -e "${YELLOW}没有需要清理的旧备份${NC}"
    fi
fi

echo ""

# 显示备份摘要
echo -e "${GREEN}=== 备份完成! ===${NC}"
echo "备份位置: ${BACKUP_DIR}"
echo ""
echo -e "${YELLOW}当前备份列表:${NC}"
ls -lh "${BACKUP_DIR}" | grep "${TIMESTAMP}" || echo "没有找到备份文件"

echo ""
echo -e "${YELLOW}恢复备份使用以下命令:${NC}"
echo "  # 恢复 memo-data 卷"
echo "  docker run --rm -v memo-data:/data -v ${BACKUP_DIR}:/backup alpine \\"
echo "    tar xzf /backup/memo-data_${TIMESTAMP}.tar.gz -C /data"
echo ""
echo "  # 恢复 mcp-config 卷"
echo "  docker run --rm -v mcp-config:/data -v ${BACKUP_DIR}:/backup alpine \\"
echo "    tar xzf /backup/mcp-config_${TIMESTAMP}.tar.gz -C /data"

echo -e "${GREEN}✅ 所有任务完成!${NC}"
